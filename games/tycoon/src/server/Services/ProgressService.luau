-- Fortschritt neben dem Geld: Statistiken, Tagesaufgaben, Erfolge mit Titeln, Pflanzen-Index,
-- Gaertner-Level, Gluecksrad (kostenlos), Codes, Einstellungen und die Einfuehrung fuer neue Spieler.
-- Listen (Aufgaben, Erfolge, Index, Pets, Designs) gehen per "Sync" an den Client, Einzelwerte als Attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local ProgressService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)
local PURPLE = Color3.fromRGB(200, 140, 255)

local TUTORIAL_DONE = 99
local TUTORIAL_STEPS = {
	{ Stat = "Plant", Text = "Tap the brown soil in your garden to plant a seed!" },
	{ Stat = "Harvest", Text = "Wait until your plant says READY, then tap it to harvest!" },
	{ Stat = "Sell", Text = "Go to the SELL stand (or tap SELL) to sell your fruits!" },
	{ Stat = "BuySeed", Text = "Buy more seeds at the SEEDS stand to grow your garden!" },
}
local TUTORIAL_REWARD = 100
local SETTING_KEYS = { Sfx = true, Announce = true, Pets = true }

local dirty = {} -- [Player] = true: Sync muss gesendet werden
local lastAction = {} -- [Player] = { [Aktion] = os.clock() } gegen Remote-Spam

function ProgressService:Init(services)
	self.Services = services
end

local function getData(player: Player)
	return ProgressService.Services.DataService:Get(player)
end

local function notify(player: Player, text: string, color: Color3?)
	ProgressService.Services.Net.SendNotify(player, text, color)
end

local function effect(player: Player, kind: string, text: string, color: Color3)
	local remote = ProgressService.Services.Net.Effect
	if remote then
		remote:FireClient(player, kind, nil, text, color)
	end
end

local function throttled(player: Player, action: string, seconds: number): boolean
	local actions = lastAction[player]
	if not actions then
		actions = {}
		lastAction[player] = actions
	end
	if os.clock() - (actions[action] or 0) < seconds then
		return true
	end
	actions[action] = os.clock()
	return false
end

local function today(): number
	return os.time() // 86400
end

-- Fehlende Felder (alte Spielstaende, Smoke-Test) auffuellen
local function ensure(data)
	data.Stats = data.Stats or {}
	data.Level = data.Level or 1
	data.Xp = data.Xp or 0
	data.Quests = data.Quests or { Day = 0, List = {} }
	data.Achievements = data.Achievements or {}
	data.Title = data.Title or ""
	data.Index = data.Index or {}
	data.MutationIndex = data.MutationIndex or {}
	data.Codes = data.Codes or {}
	data.Settings = data.Settings or {}
	for key in SETTING_KEYS do
		if data.Settings[key] == nil then
			data.Settings[key] = true
		end
	end
	data.LastSpin = data.LastSpin or 0
	data.BoostUntil = data.BoostUntil or 0
	data.Pets = data.Pets or {}
	data.Pet = data.Pet or ""
	data.Skins = data.Skins or { classic = true }
	data.Skin = data.Skin or "classic"
	data.Tutorial = data.Tutorial or 0
	return data
end
ProgressService.Ensure = ensure

function ProgressService:MarkDirty(player: Player)
	dirty[player] = true
end

-- Verdienst-abhaengige Belohnung (wie bei den Muenzpaketen, damit sie nie wertlos wird)
local function scaledCoins(player: Player, minutes: number, minCoins: number): number
	local rate = ProgressService.Services.GardenService:GetEarnRate(player)
	return math.floor(math.max(minCoins, rate * 60 * minutes))
end

---------------------------------------------------------------- Werte

local function indexCount(data): number
	local count = 0
	for _ in data.Index do
		count += 1
	end
	for _ in data.MutationIndex do
		count += 1
	end
	return count
end

-- Zusatz-Multiplikator fuer den Fruchtwert: Index, Level und 2x-Boost
function ProgressService:GetValueBonus(player: Player): number
	local data = getData(player)
	if not data then
		return 1
	end
	ensure(data)
	local bonus = 1 + indexCount(data) * Config.IndexBonusPer
	bonus *= 1 + math.min(data.Level - 1, Config.MaxLevelBonus) * Config.LevelBonusPer
	if os.time() < data.BoostUntil then
		bonus *= Config.BoostMultiplier
	end
	return bonus
end

local function statValue(data, stat: string): number
	if stat == "TotalEarned" then
		return data.TotalEarned or 0
	elseif stat == "Rebirths" then
		return data.Rebirths or 0
	elseif stat == "Level" then
		return data.Level
	elseif stat == "Index" then
		local count = 0
		for _ in data.Index do
			count += 1
		end
		return count
	end
	return data.Stats[stat] or 0
end

local function updateAttributes(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("Xp", math.floor(data.Xp))
	player:SetAttribute("XpNeed", Config.XpNeeded(data.Level))
	local achievement = Config.AchievementsById[data.Title]
	player:SetAttribute("Title", if achievement and data.Achievements[data.Title] then achievement.Title else nil)
	player:SetAttribute("SpinReadyAt", data.LastSpin + Config.SpinCooldown)
	player:SetAttribute("BoostUntil", data.BoostUntil)
	player:SetAttribute("IndexBonus", indexCount(data) * Config.IndexBonusPer)
	for key in SETTING_KEYS do
		player:SetAttribute("Set_" .. key, data.Settings[key] ~= false)
	end
	local claimable = 0
	for _, quest in data.Quests.List do
		if quest.Progress >= quest.Target and not quest.Claimed then
			claimable += 1
		end
	end
	player:SetAttribute("QuestsReady", claimable)
end

---------------------------------------------------------------- Einfuehrung

local function updateTutorial(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local step = TUTORIAL_STEPS[data.Tutorial + 1]
	if not step then
		player:SetAttribute("TutorialText", nil)
		player:SetAttribute("TutorialTarget", nil)
		return
	end
	player:SetAttribute("TutorialText", `Step {data.Tutorial + 1}/{#TUTORIAL_STEPS}: {step.Text}`)
	local world = ProgressService.Services.WorldService
	local plot = ProgressService.Services.GardenService:GetPlot(player)
	local target: Vector3? = nil
	if step.Stat == "Plant" and plot then
		target = plot.Tiles[1].Part.Position
	elseif step.Stat == "Harvest" and plot then
		-- Das Feld mit der reifsten Pflanze zeigen
		local best, bestIndex = -1, 1
		for key, plant in data.Plants do
			local index = tonumber(key)
			local ratio = plant.Grown / plant.Need
			if index and plot.Tiles[index] and ratio > best then
				best, bestIndex = ratio, index
			end
		end
		target = plot.Tiles[bestIndex].Part.Position
	elseif step.Stat == "Sell" and world.SellCFrame then
		target = world.SellCFrame.Position
	elseif step.Stat == "BuySeed" and world.ShopCFrame then
		target = world.ShopCFrame.Position
	end
	player:SetAttribute("TutorialTarget", target)
end

local function advanceTutorial(player: Player, data, stat: string)
	local step = TUTORIAL_STEPS[data.Tutorial + 1]
	if not step or step.Stat ~= stat then
		return
	end
	data.Tutorial += 1
	if data.Tutorial >= #TUTORIAL_STEPS then
		data.Tutorial = TUTORIAL_DONE
		ProgressService.Services.DataService:AddCoins(player, TUTORIAL_REWARD)
		notify(player, `Tutorial complete! +{Format.Cash(TUTORIAL_REWARD)}. Check QUESTS and the free WHEEL!`, GOLD)
		effect(player, "Reward", "Tutorial complete!", GOLD)
	end
	updateTutorial(player)
end

---------------------------------------------------------------- Level und Erfolge

function ProgressService:AddXp(player: Player, amount: number)
	local data = getData(player)
	if not data or amount <= 0 then
		return
	end
	ensure(data)
	data.Xp += amount
	local leveled = false
	while data.Xp >= Config.XpNeeded(data.Level) do
		data.Xp -= Config.XpNeeded(data.Level)
		data.Level += 1
		leveled = true
		local reward = Config.LevelReward(data.Level, data.Rebirths)
		self.Services.DataService:AddCoins(player, reward)
		notify(player, `LEVEL UP! You are now level {data.Level}: +{Format.Cash(reward)} and +1% fruit value.`, GOLD)
		if data.Level % 10 == 0 then
			self.Services.Net.SendAnnounce(`{player.DisplayName} reached gardener level {data.Level}!`, GOLD)
		end
	end
	if leveled then
		effect(player, "LevelUp", `Level {data.Level}!`, GOLD)
		self:CheckAchievements(player)
		self.Services.DataService:UpdateAttributes(player)
		self.Services.GardenService:RefreshStats(player)
	end
	updateAttributes(player)
end

function ProgressService:CheckAchievements(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	local changed = false
	for _, achievement in Config.Achievements do
		if not data.Achievements[achievement.Id] and statValue(data, achievement.Stat) >= achievement.Goal then
			data.Achievements[achievement.Id] = true
			changed = true
			notify(player, `Achievement: {achievement.Text}! Title "{achievement.Title}" unlocked (BOOK).`, PURPLE)
			effect(player, "Reward", achievement.Title, PURPLE)
			-- Der erste Titel wird gleich angezeigt
			if data.Title == "" then
				data.Title = achievement.Id
			end
		end
	end
	if changed then
		updateAttributes(player)
		self:MarkDirty(player)
	end
end

---------------------------------------------------------------- Tagesaufgaben

local function rollQuests(player: Player, data)
	local day = today()
	if data.Quests.Day == day then
		return
	end
	local rng = Random.new(day * 7919 + player.UserId % 1_000_003)
	local pool = table.clone(Config.QuestPool)
	local list = {}
	for tier = 1, Config.QuestCount do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { Id = quest.Id, Tier = tier, Target = quest.Targets[tier], Progress = 0, Claimed = false })
	end
	data.Quests = { Day = day, List = list }
end

function ProgressService:AddStat(player: Player, stat: string, amount: number)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	rollQuests(player, data)
	data.Stats[stat] = (data.Stats[stat] or 0) + amount
	for _, quest in data.Quests.List do
		local def = Config.QuestsById[quest.Id]
		if def and def.Stat == stat and quest.Progress < quest.Target then
			quest.Progress = math.min(quest.Target, quest.Progress + amount)
			if quest.Progress >= quest.Target then
				notify(player, `Quest complete: {string.format(def.Text, quest.Target)}! Claim it in QUESTS.`, GREEN)
				effect(player, "Reward", "Quest complete!", GREEN)
			end
		end
	end
	advanceTutorial(player, data, stat)
	self:CheckAchievements(player)
	updateAttributes(player)
	self:MarkDirty(player)
end

function ProgressService:ClaimQuest(player: Player, index: number)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	rollQuests(player, data)
	local quest = data.Quests.List[index]
	if not quest or quest.Claimed or quest.Progress < quest.Target then
		return
	end
	quest.Claimed = true
	local reward = Config.QuestRewards[quest.Tier] or Config.QuestRewards[1]
	local coins = scaledCoins(player, reward.Minutes, reward.MinCoins)
	self.Services.DataService:AddCoins(player, coins)
	notify(player, `Quest reward: +{Format.Cash(coins)} and +{reward.Xp} XP!`, GOLD)
	effect(player, "Reward", "+" .. Format.Cash(coins), GOLD)
	self:AddXp(player, reward.Xp)
	local allDone = true
	for _, other in data.Quests.List do
		if not other.Claimed then
			allDone = false
		end
	end
	if allDone then
		notify(player, "All daily quests done! New quests tomorrow.", GREEN)
	end
	updateAttributes(player)
	self:MarkDirty(player)
end

---------------------------------------------------------------- Ernten (Index, Statistiken, XP)

function ProgressService:OnHarvest(player: Player, seed, mutationName: string?)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	local rarity = Config.RaritiesByName[seed.Rarity]
	if not data.Index[seed.Id] then
		data.Index[seed.Id] = true
		notify(player, `New plant in your Index: {seed.Name}! +{math.floor(Config.IndexBonusPer * 100)}% fruit value forever.`, rarity.Color)
	end
	if mutationName and not data.MutationIndex[mutationName] then
		data.MutationIndex[mutationName] = true
		notify(player, `New mutation discovered: {mutationName}! +{math.floor(Config.IndexBonusPer * 100)}% fruit value forever.`, PURPLE)
	end
	local stats = data.Stats
	if seed.Rarity == "Mythic" then
		stats.Mythic = (stats.Mythic or 0) + 1
	end
	if mutationName then
		stats[mutationName] = (stats[mutationName] or 0) + 1
		self:AddStat(player, "Mutation", 1)
	end
	if rarity.Index >= 3 then
		self:AddStat(player, "RareHarvest", 1)
	end
	self:AddStat(player, "Harvest", 1)
	self:AddXp(player, rarity.Index + (if mutationName then 5 else 0))
	self.Services.GardenService:RefreshStats(player)
end

---------------------------------------------------------------- Gluecksrad

local function pickWheelReward(): number
	local total = 0
	for _, reward in Config.WheelRewards do
		total += reward.Weight
	end
	local roll = math.random() * total
	for index, reward in Config.WheelRewards do
		roll -= reward.Weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

local function giveSeeds(player: Player, data, seedId: string, amount: number)
	data.Seeds[seedId] = (data.Seeds[seedId] or 0) + amount
	player:SetAttribute("SelectedSeed", seedId)
	ProgressService.Services.DataService:UpdateAttributes(player)
end

local function giveBoost(player: Player, data, seconds: number)
	data.BoostUntil = math.max(os.time(), data.BoostUntil) + seconds
	ProgressService.Services.GardenService:RefreshStats(player)
end

function ProgressService:Spin(player: Player): number?
	local data = getData(player)
	if not data then
		return nil
	end
	ensure(data)
	local readyAt = data.LastSpin + Config.SpinCooldown
	if os.time() < readyAt then
		notify(player, `Next free spin in {Format.Time(readyAt - os.time())}.`, RED)
		return nil
	end
	data.LastSpin = os.time()
	local index = pickWheelReward()
	local reward = Config.WheelRewards[index]
	local text = reward.Name
	if reward.Kind == "Coins" then
		local coins = scaledCoins(player, reward.Minutes, reward.MinCoins)
		self.Services.DataService:AddCoins(player, coins)
		text = `{reward.Name}: +{Format.Cash(coins)}`
	elseif reward.Kind == "Seed" then
		giveSeeds(player, data, reward.Seed, reward.Amount)
		local seed = Config.SeedsById[reward.Seed]
		if Config.RaritiesByName[seed.Rarity].Announce then
			self.Services.Net.SendAnnounce(`{player.DisplayName} won a {seed.Rarity} {seed.Name} seed on the Lucky Wheel!`, Config.RaritiesByName[seed.Rarity].Color)
		end
	elseif reward.Kind == "Boost" then
		giveBoost(player, data, reward.Seconds)
	end
	self:AddStat(player, "Spins", 1)
	updateAttributes(player)
	local remote = self.Services.Net.SpinResult
	if remote then
		remote:FireClient(player, index, text)
	end
	return index
end

---------------------------------------------------------------- Codes und Einstellungen

function ProgressService:RedeemCode(player: Player, text: string): boolean
	local data = getData(player)
	if not data then
		return false
	end
	ensure(data)
	local code = text:upper():gsub("%s", "")
	local def = Config.Codes[code]
	if not def then
		notify(player, "That code does not exist.", RED)
		return false
	end
	if data.Codes[code] then
		notify(player, "You already redeemed this code.", RED)
		return false
	end
	data.Codes[code] = true
	if def.Coins then
		self.Services.DataService:AddCoins(player, def.Coins)
	end
	if def.Seed and Config.SeedsById[def.Seed] then
		giveSeeds(player, data, def.Seed, def.Amount or 1)
	end
	if def.Boost then
		giveBoost(player, data, def.Boost)
	end
	notify(player, `Code redeemed: {def.Text}!`, GREEN)
	effect(player, "Reward", def.Text, GREEN)
	updateAttributes(player)
	return true
end

function ProgressService:SetSetting(player: Player, key: string, value: boolean)
	local data = getData(player)
	if not data or not SETTING_KEYS[key] then
		return
	end
	ensure(data)
	data.Settings[key] = value
	player:SetAttribute("Set_" .. key, value)
end

function ProgressService:EquipTitle(player: Player, id: string)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	if id ~= "" and not data.Achievements[id] then
		return
	end
	data.Title = id
	updateAttributes(player)
	self:MarkDirty(player)
end

---------------------------------------------------------------- Sync an den Client

function ProgressService:BuildSync(player: Player)
	local data = getData(player)
	if not data then
		return nil
	end
	ensure(data)
	rollQuests(player, data)
	local quests = {}
	for _, quest in data.Quests.List do
		local def = Config.QuestsById[quest.Id]
		local reward = Config.QuestRewards[quest.Tier] or Config.QuestRewards[1]
		table.insert(quests, {
			Text = if def then string.format(def.Text, quest.Target) else quest.Id,
			Progress = quest.Progress,
			Target = quest.Target,
			Claimed = quest.Claimed,
			Reward = `{Format.Cash(scaledCoins(player, reward.Minutes, reward.MinCoins))} + {reward.Xp} XP`,
		})
	end
	local pets = table.clone(data.Pets)
	for _, pet in Config.Pets do
		if pet.Pass and player:GetAttribute("Pass_" .. pet.Pass) then
			pets[pet.Id] = true
		end
	end
	return {
		Quests = quests,
		QuestDay = data.Quests.Day,
		Achievements = table.clone(data.Achievements),
		Title = data.Title,
		Index = table.clone(data.Index),
		MutationIndex = table.clone(data.MutationIndex),
		Pets = pets,
		Pet = data.Pet,
		Skins = table.clone(data.Skins),
		Skin = data.Skin,
		Stats = table.clone(data.Stats),
		TotalEarned = data.TotalEarned or 0,
	}
end

local function sendSync(player: Player)
	local remote = ProgressService.Services.Net.Sync
	local payload = ProgressService:BuildSync(player)
	if remote and payload and player.Parent then
		remote:FireClient(player, payload)
	end
end

---------------------------------------------------------------- Lebenszyklus

function ProgressService:OnPlayerReady(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	ensure(data)
	-- Wer schon gespielt hat (aktive Spielzeit oder Rebirth), braucht keine Einfuehrung mehr.
	-- Nicht TotalEarned nehmen: die Tagesbelohnung zaehlt dort schon beim ersten Beitritt mit.
	if data.Tutorial == 0 and ((data.PlayTime or 0) > 300 or (data.Rebirths or 0) > 0) then
		data.Tutorial = TUTORIAL_DONE
	end
	rollQuests(player, data)
	self:CheckAchievements(player)
	updateAttributes(player)
	updateTutorial(player)
	self:MarkDirty(player)
end

function ProgressService:OnPlayerRemoving(player: Player)
	dirty[player] = nil
	lastAction[player] = nil
end

function ProgressService:Start()
	local net = self.Services.Net

	net.ClaimQuest.OnServerEvent:Connect(function(player, index)
		if type(index) == "number" and index == index and index >= 1 and index <= Config.QuestCount and not throttled(player, "Claim", 0.3) then
			self:ClaimQuest(player, math.floor(index))
		end
	end)

	net.EquipTitle.OnServerEvent:Connect(function(player, id)
		if type(id) == "string" and #id <= 32 and not throttled(player, "Title", 0.5) then
			self:EquipTitle(player, id)
		end
	end)

	net.Spin.OnServerEvent:Connect(function(player)
		if not throttled(player, "Spin", 1) then
			self:Spin(player)
		end
	end)

	net.RedeemCode.OnServerEvent:Connect(function(player, text)
		if type(text) == "string" and #text <= 32 and not throttled(player, "Code", 2) then
			self:RedeemCode(player, text)
		end
	end)

	net.SetSetting.OnServerEvent:Connect(function(player, key, value)
		if type(key) == "string" and type(value) == "boolean" and not throttled(player, "Setting" .. key, 0.2) then
			self:SetSetting(player, key, value)
		end
	end)

	net.RequestSync.OnServerEvent:Connect(function(player)
		if not throttled(player, "Sync", 1) then
			self:MarkDirty(player)
		end
	end)

	-- Gesammelte Aenderungen zweimal pro Sekunde senden; Einfuehrungs-Ziel und neuer Tag nachziehen
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.5)
			tick += 1
			for player in dirty do
				dirty[player] = nil
				sendSync(player)
			end
			if tick % 4 == 0 then
				for _, player in Players:GetPlayers() do
					local data = getData(player)
					if data then
						ensure(data)
						if data.Quests.Day ~= today() then
							rollQuests(player, data)
							updateAttributes(player)
							self:MarkDirty(player)
							notify(player, "New daily quests are here! Open QUESTS.", GREEN)
						end
						if data.Tutorial < TUTORIAL_DONE then
							updateTutorial(player)
						end
					end
				end
			end
		end
	end)
end

return ProgressService
