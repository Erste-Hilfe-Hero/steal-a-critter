-- Fortschritt neben der Geschichte: Tagesaufgaben, Erfolge mit Titeln, Bestiarium-Belohnungen, Gluecksrad (gratis),
-- Spielzeit-Geschenke, Bestien-Hort, Favoriten, Einstellungen und die Trainerkarte.
-- Kampfergebnisse werden ueber die gespeicherten Zaehler (Wins, Caught, TotalEarned, PlayTime) erkannt,
-- damit der Kampf-Code dafuer nicht angefasst werden muss.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Progress = require(ReplicatedStorage.Shared.Progress)

local ProgressService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(110, 230, 130)
local RED = Color3.fromRGB(255, 90, 90)

local sessionStart = {} -- [Player] = os.clock() beim Beitritt
local giftsClaimed = {} -- [Player] = { [GiftKey] = true } (gilt nur fuer diesen Besuch)
local snapshots = {} -- [Player] = { Wins, Caught, Earned, Minutes } fuer die Aufgaben
local lastAction = {} -- [Player] = os.clock() (gegen zu viele Anfragen)
local lastProfile = {} -- [Player] = os.clock()

local function today(): number
	return os.time() // 86400
end

local function count(t): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function ProgressService:Init(services)
	self.Services = services
end

local function dataOf(player: Player)
	return ProgressService.Services.DataService:Get(player)
end

local function notify(player: Player, text: string, color: Color3?)
	ProgressService.Services.Net.SendNotify(player, text, color)
end

local function grant(player: Player, bundle)
	ProgressService.Services.BeastService:GrantBundle(player, bundle)
end

local function bundleText(bundle): string
	return ProgressService.Services.BeastService:BundleText(bundle)
end

-- Alte Spielstaende und kaputte Werte reparieren
local function ensure(data)
	if typeof(data.Quests) ~= "table" or typeof(data.Quests.List) ~= "table" then
		data.Quests = { Day = 0, List = {}, Bonus = false }
	end
	for _, key in { "Achievements", "DexClaimed", "Daycare", "Favorites", "Settings" } do
		if typeof(data[key]) ~= "table" then
			data[key] = {}
		end
	end
	if typeof(data.Title) ~= "string" then
		data.Title = ""
	end
	if typeof(data.LastSpin) ~= "number" then
		data.LastSpin = 0
	end
	if typeof(data.QuestsDone) ~= "number" then
		data.QuestsDone = 0
	end
	for key, value in Progress.DefaultSettings do
		if typeof(data.Settings[key]) ~= "boolean" then
			data.Settings[key] = value
		end
	end
end

-- Neue Aufgaben, sobald ein neuer Tag (UTC) beginnt. Gibt true zurueck, wenn sie neu sind.
local function refreshDay(player: Player, data): boolean
	local day = today()
	if data.Quests.Day ~= day then
		data.Quests = Progress.MakeQuests(day, player.UserId)
		return true
	end
	return false
end

local function titleText(data): string
	local achievement = Progress.AchievementsById[data.Title]
	return if achievement and data.Achievements[achievement.Id] then achievement.Title else ""
end

local function applyAttributes(player: Player, data)
	player:SetAttribute("Title", titleText(data))
	for key in Progress.DefaultSettings do
		player:SetAttribute("Set_" .. key, data.Settings[key] == true)
	end
end

local function snapshot(data)
	return { Wins = data.Wins, Caught = data.Caught, Earned = data.TotalEarned, Minutes = data.PlayTime // 60 }
end

---------------------------------------------------------------- Zustand an den Client

function ProgressService:Push(player: Player)
	local data = dataOf(player)
	if not data or not sessionStart[player] then
		return
	end
	local quests = {}
	for index, quest in data.Quests.List do
		quests[index] = {
			Kind = quest.K,
			Text = Progress.QuestText(quest.K, quest.G),
			Progress = quest.P,
			Goal = quest.G,
			Claimed = quest.C,
			Reward = bundleText(Progress.QuestReward(quest.T)),
		}
	end
	local daycare = nil
	local uid = data.Daycare.Uid
	local entry = uid and data.Beasts[uid]
	if entry then
		local minutes = math.clamp((os.time() - (data.Daycare.Since or os.time())) // 60, 0, Progress.DaycareMaxMinutes)
		daycare = { Uid = uid, S = entry.S, L = entry.L, Sh = entry.Sh == true, Minutes = minutes, Xp = Progress.DaycareXp(entry.L, minutes) }
	end
	self.Services.Net.Progress:FireClient(player, "State", {
		Quests = quests,
		Bonus = data.Quests.Bonus,
		QuestReset = 86400 - os.time() % 86400,
		QuestsDone = data.QuestsDone,
		Achievements = data.Achievements,
		Title = data.Title,
		DexClaimed = data.DexClaimed,
		DexCount = count(data.Dex),
		SpinIn = math.max(0, Progress.SpinCooldown - (os.time() - data.LastSpin)),
		Session = os.clock() - sessionStart[player],
		Gifts = giftsClaimed[player] or {},
		Daycare = daycare,
		Settings = data.Settings,
		Context = Progress.Context(data),
		-- Werte fuer die Fortschrittsbalken der Erfolge
		Stats = {
			Caught = data.Caught,
			Crests = data.Crests,
			Wins = data.Wins,
			BestWave = data.BestWave,
			Trophies = data.Trophies,
			QuestsDone = data.QuestsDone,
			Flags = { champion = data.Flags.champion == true },
		},
	})
end

---------------------------------------------------------------- Tagesaufgaben

-- Fortschritt fuer eine Aufgabenart (z. B. "Encounter"), von anderen Services aufgerufen
function ProgressService:Bump(player: Player, kind: string, amount: number)
	local data = dataOf(player)
	if not data or not data.Started or not sessionStart[player] or not (amount > 0) then
		return
	end
	local fresh = refreshDay(player, data)
	local changed = fresh
	for _, quest in data.Quests.List do
		if quest.K == kind and not quest.C and quest.P < quest.G then
			quest.P = math.min(quest.G, quest.P + amount)
			changed = true
			if quest.P >= quest.G then
				notify(player, `Quest complete: {Progress.QuestText(quest.K, quest.G)}! Claim it in QUESTS.`, GOLD)
				self.Services.Net.Progress:FireClient(player, "QuestDone", quest.K)
			end
		end
	end
	if changed then
		self:Push(player)
	end
end

local function claimQuest(player: Player, data, index: any)
	local quest = typeof(index) == "number" and data.Quests.List[index]
	if not quest or quest.C or quest.P < quest.G then
		return
	end
	quest.C = true
	data.QuestsDone += 1
	local reward = Progress.QuestReward(quest.T)
	grant(player, reward)
	notify(player, `Quest reward: {bundleText(reward)}!`, GOLD)
end

local function claimBonus(player: Player, data)
	if data.Quests.Bonus or #data.Quests.List == 0 then
		return
	end
	for _, quest in data.Quests.List do
		if not quest.C then
			notify(player, "Claim all three quests first!", RED)
			return
		end
	end
	data.Quests.Bonus = true
	grant(player, Progress.QuestBonus)
	notify(player, `All quests done! Bonus: {bundleText(Progress.QuestBonus)}!`, GOLD)
end

-- Produkt "Quest Finisher": alle offenen Aufgaben sofort erfuellen
function ProgressService:FinishQuests(player: Player): boolean
	local data = dataOf(player)
	if not data then
		return false
	end
	ensure(data)
	refreshDay(player, data)
	local open = 0
	for _, quest in data.Quests.List do
		if not quest.C and quest.P < quest.G then
			quest.P = quest.G
			open += 1
		end
	end
	if open == 0 then
		self.Services.DataService:AddCoins(player, Progress.QuestFinishFallbackCoins)
		notify(player, `All quests were already done - +{Progress.QuestFinishFallbackCoins} coins instead!`, GOLD)
	else
		notify(player, "All daily quests completed! Claim your rewards in QUESTS.", GOLD)
	end
	self:Push(player)
	return true
end

---------------------------------------------------------------- Erfolge

-- quiet = beim Beitritt: bereits erreichte Erfolge alter Spielstaende gesammelt melden statt 17 Banner
local function checkAchievements(player: Player, data, quiet: boolean?)
	local context = Progress.Context(data)
	local unlocked, coins = 0, 0
	for _, achievement in Progress.Achievements do
		if not data.Achievements[achievement.Id] and Progress.AchievementDone(achievement, data, context) then
			data.Achievements[achievement.Id] = true
			unlocked += 1
			coins += achievement.Coins
			ProgressService.Services.DataService:AddCoins(player, achievement.Coins)
			if not quiet then
				-- Der Client zeigt dazu ein eigenes Banner mit Titel und Muenzen
				ProgressService.Services.Net.Progress:FireClient(player, "Achievement", achievement.Id)
			end
		end
	end
	if unlocked > 0 and quiet then
		task.delay(8, function()
			if player.Parent then
				notify(player, `You earned {unlocked} achievements on your journey so far: +{coins} coins and new titles (MORE > AWARDS)!`, GOLD)
			end
		end)
	end
	if unlocked > 0 then
		ProgressService:Push(player)
	end
end

local function setTitle(player: Player, data, id: any)
	if id == "" then
		data.Title = ""
	elseif typeof(id) == "string" and Progress.AchievementsById[id] and data.Achievements[id] then
		data.Title = id
	else
		return
	end
	applyAttributes(player, data)
	notify(player, if data.Title == "" then "Title removed." else `Title set: "{titleText(data)}"`, GREEN)
end

---------------------------------------------------------------- Bestiarium, Rad, Geschenke

local function claimDex(player: Player, data, key: any)
	for _, milestone in Progress.DexMilestones do
		if milestone.Key == key then
			if data.DexClaimed[key] then
				return
			end
			if count(data.Dex) < milestone.Need then
				notify(player, `Catch {milestone.Need} different beasts first!`, RED)
				return
			end
			data.DexClaimed[key] = true
			grant(player, milestone.Reward)
			notify(player, `Bestiary reward: {bundleText(milestone.Reward)}!`, GOLD)
			return
		end
	end
end

local random = Random.new()

local function spin(player: Player, data)
	local wait = Progress.SpinCooldown - (os.time() - data.LastSpin)
	if wait > 0 then
		notify(player, `The wheel recharges in {math.ceil(wait / 60)} minutes.`, RED)
		return
	end
	data.LastSpin = os.time()
	local index = Progress.RollWheel(random:NextNumber())
	local slot = Progress.Wheel[index]
	grant(player, slot.Reward)
	ProgressService.Services.Net.Progress:FireClient(player, "Wheel", index)
	if slot.Reward.Items and slot.Reward.Items.MasterOrb then
		ProgressService.Services.Net.SendAnnounce(`{player.DisplayName} won a MASTER ORB on the Lucky Wheel!`, GOLD)
	end
end

local function claimGift(player: Player, key: any)
	local claimed = giftsClaimed[player]
	if not claimed or typeof(key) ~= "string" or claimed[key] then
		return
	end
	for _, gift in Progress.Gifts do
		if gift.Key == key then
			if os.clock() - sessionStart[player] < gift.Minutes * 60 - 1 then
				return
			end
			claimed[key] = true
			grant(player, gift.Reward)
			notify(player, `Playtime gift: {bundleText(gift.Reward)}!`, GOLD)
			return
		end
	end
end

---------------------------------------------------------------- Bestien-Hort

function ProgressService:InDaycare(player: Player, uid: string): boolean
	local data = dataOf(player)
	return data ~= nil and typeof(data.Daycare) == "table" and data.Daycare.Uid == uid
end

local function deposit(player: Player, data, uid: any)
	local services = ProgressService.Services
	if typeof(uid) ~= "string" or not data.Beasts[uid] or services.BattleService:InBattle(player) then
		return
	end
	if data.Daycare.Uid then
		notify(player, "The daycare already has a beast. Pick it up first.", RED)
		return
	end
	local index = table.find(data.Team, uid)
	if index and #data.Team <= 1 then
		notify(player, "You need at least one beast in your team.", RED)
		return
	end
	if index then
		table.remove(data.Team, index)
	end
	data.Daycare = { Uid = uid, Since = os.time() }
	services.BeastService:Sync(player)
	notify(player, `{Config.BeastsById[data.Beasts[uid].S].Name} is training at the daycare!`, GREEN)
end

local function collect(player: Player, data)
	local services = ProgressService.Services
	local uid = data.Daycare.Uid
	if not uid or services.BattleService:InBattle(player) then
		return
	end
	local entry = data.Beasts[uid]
	local since = data.Daycare.Since or os.time()
	data.Daycare = {}
	if not entry then
		services.BeastService:Sync(player)
		return
	end
	local minutes = math.clamp((os.time() - since) // 60, 0, Progress.DaycareMaxMinutes)
	local before = entry.L
	local events = services.BeastService:GiveXp(player, uid, Progress.DaycareXp(entry.L, minutes))
	-- Entwicklung wie nach einem Kampf
	local def = Config.BeastsById[entry.S]
	local from = entry.S
	if def.Evolve and entry.L >= def.Evolve.Level and services.BeastService:Evolve(player, uid) then
		table.insert(events, { T = "Evolve", Uid = uid, From = from, To = entry.S })
	end
	if #data.Team < Config.TeamSize then
		table.insert(data.Team, uid)
	end
	services.BeastService:Sync(player)
	local name = Config.BeastsById[entry.S].Name
	notify(player, if entry.L > before then `{name} trained for {minutes} min and grew {entry.L - before} levels!` else `{name} trained for {minutes} min.`, GREEN)
	services.Net.Progress:FireClient(player, "PostEvents", events)
end

---------------------------------------------------------------- Trainerkarte

local function profile(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsA("Player") or not target.Parent then
		return
	end
	if os.clock() - (lastProfile[player] or -10) < 1 then
		return
	end
	lastProfile[player] = os.clock()
	local data = dataOf(target)
	if not data then
		return
	end
	local team = {}
	for _, item in ProgressService.Services.BeastService:TeamEntries(target) do
		table.insert(team, { S = item.Entry.S, L = item.Entry.L, Sh = item.Entry.Sh == true })
	end
	local context = Progress.Context(data)
	ProgressService.Services.Net.Progress:FireClient(player, "Profile", {
		UserId = target.UserId,
		Name = target.DisplayName,
		User = target.Name,
		Title = titleText(data),
		Rank = target:GetAttribute("Rank") or "Newbie",
		Badges = data.Crests,
		Champion = data.Flags.champion == true,
		Caught = context.Dex,
		Seen = count(data.Seen),
		Wins = data.Wins,
		BestWave = data.BestWave,
		Trophies = data.Trophies,
		Hours = math.floor(data.PlayTime / 360) / 10,
		Achievements = count(data.Achievements),
		Starter = data.Starter,
		Team = team,
	})
end

---------------------------------------------------------------- Lebenszyklus

function ProgressService:OnPlayerReady(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	ensure(data)
	refreshDay(player, data)
	-- Bestie im Hort darf nicht im Team stehen; verschwundene Bestien austragen
	local uid = data.Daycare.Uid
	if uid then
		local index = table.find(data.Team, uid)
		if not data.Beasts[uid] or (index and #data.Team <= 1) then
			data.Daycare = {}
		elseif index then
			table.remove(data.Team, index)
		end
	end
	sessionStart[player] = os.clock()
	giftsClaimed[player] = {}
	if data.Started then
		checkAchievements(player, data, true)
	end
	snapshots[player] = snapshot(data)
	applyAttributes(player, data)
	self.Services.BeastService:Sync(player)
	self:Push(player)
end

function ProgressService:OnPlayerRemoving(player: Player)
	sessionStart[player] = nil
	giftsClaimed[player] = nil
	snapshots[player] = nil
	lastAction[player] = nil
	lastProfile[player] = nil
end

function ProgressService:Start()
	local services = self.Services

	services.Net.ProgressAction.OnServerEvent:Connect(function(player, kind, arg, value)
		local data = dataOf(player)
		if not data or not sessionStart[player] or typeof(kind) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (lastAction[player] or -10) < 0.25 then
			return
		end
		lastAction[player] = now
		refreshDay(player, data)
		if kind == "Setting" then
			if typeof(arg) == "string" and Progress.DefaultSettings[arg] ~= nil and typeof(value) == "boolean" then
				data.Settings[arg] = value
				applyAttributes(player, data)
			end
		elseif kind == "Profile" then
			profile(player, arg)
			return
		elseif kind == "Favorite" then
			if typeof(arg) == "string" and data.Beasts[arg] then
				data.Favorites[arg] = if data.Favorites[arg] then nil else true
				services.BeastService:Sync(player)
			end
		elseif kind == "SetTitle" then
			setTitle(player, data, arg)
		elseif not data.Started then
			notify(player, "Choose your first beast at Professor Sol's lab first!", RED)
			return
		elseif kind == "ClaimQuest" then
			claimQuest(player, data, arg)
		elseif kind == "ClaimBonus" then
			claimBonus(player, data)
		elseif kind == "ClaimDex" then
			claimDex(player, data, arg)
		elseif kind == "Spin" then
			spin(player, data)
		elseif kind == "ClaimGift" then
			claimGift(player, arg)
		elseif kind == "Deposit" then
			deposit(player, data, arg)
		elseif kind == "Collect" then
			collect(player, data)
		else
			return
		end
		self:Push(player)
	end)

	-- Jede Sekunde: Zaehler vergleichen (Siege, Faenge, Muenzen, Minuten), alle 5 Sekunden Erfolge pruefen
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for player, last in snapshots do
				local data = dataOf(player)
				if data and player.Parent then
					if refreshDay(player, data) then
						self:Push(player)
					end
					local now = snapshot(data)
					snapshots[player] = now
					self:Bump(player, "Win", now.Wins - last.Wins)
					self:Bump(player, "Catch", now.Caught - last.Caught)
					self:Bump(player, "Coins", now.Earned - last.Earned)
					self:Bump(player, "Minutes", now.Minutes - last.Minutes)
					if now.Wins ~= last.Wins or now.Caught ~= last.Caught then
						self:Push(player)
					end
					if tick % 5 == 0 and data.Started then
						checkAchievements(player, data)
					end
				end
			end
		end
	end)
end

return ProgressService
