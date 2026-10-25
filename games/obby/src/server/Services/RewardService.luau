-- Coins, taegliche Belohnung (Streak), taegliche Quests, Erfolge/Titel, Codes, Einstellungen,
-- Coin-Trails und der Zustandsabgleich mit dem Client (Sync).
-- Alles, was der Client schickt, wird hier geprueft (Typen, Grenzen, Cooldowns).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local RewardService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)

local lastRequest = {} -- [Player] = { [RemoteName] = os.clock() }
local lastPlayTime = {} -- [Player] = zuletzt gesehene PlayTime (fuer die Spielzeit-Quest)
local syncQueued = {} -- [Player] = true, solange ein Sync ansteht

function RewardService:Init(services)
	self.Services = services
end

local function today(): number
	return os.time() // 86400
end

-- Einfacher Cooldown pro Spieler und Remote
local function allowed(player: Player, name: string, cooldown: number): boolean
	local entry = lastRequest[player]
	if not entry then
		entry = {}
		lastRequest[player] = entry
	end
	local now = os.clock()
	if now - (entry[name] or -math.huge) < cooldown then
		return false
	end
	entry[name] = now
	return true
end

local function notify(player: Player, text: string, color: Color3?)
	RewardService.Services.Net.SendNotify(player, text, color)
end

---------------------------------------------------------------- Coins

-- Gibt Coins (boosted: VIP bekommt mehr). Gekaufte Coins zaehlen nicht fuer den Erfolg "Coin Collector".
-- Gibt den tatsaechlichen Betrag zurueck.
function RewardService:AddCoins(player: Player, amount: number, boosted: boolean, purchased: boolean?): number
	local data = self.Services.DataService:Get(player)
	if not data or amount <= 0 then
		return 0
	end
	if boosted and player:GetAttribute("Pass_VIP") then
		amount = math.floor(amount * Config.VipCoinMultiplier)
	end
	data.Coins += amount
	if not purchased then
		data.CoinsEarned += amount
	end
	player:SetAttribute("Coins", data.Coins)
	self:CheckAchievements(player)
	self:QueueSync(player)
	return amount
end

function RewardService:SpendCoins(player: Player, amount: number): boolean
	local data = self.Services.DataService:Get(player)
	if not data or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	player:SetAttribute("Coins", data.Coins)
	self:QueueSync(player)
	return true
end

---------------------------------------------------------------- Taegliche Belohnung

local function dailyReady(data): boolean
	return data.LastDailyDay ~= today()
end

-- Welcher Streak-Tag waere die naechste Belohnung?
local function nextStreak(data): number
	if data.LastDailyDay == today() - 1 then
		return data.DailyStreak + 1
	end
	return 1
end

local function dailyReward(streak: number): number
	return Config.DailyRewards[(streak - 1) % #Config.DailyRewards + 1]
end

function RewardService:ClaimDaily(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if not dailyReady(data) then
		notify(player, "You already claimed today's reward. Come back tomorrow!", RED)
		return
	end
	local streak = nextStreak(data)
	data.DailyStreak = streak
	data.LastDailyDay = today()
	local amount = self:AddCoins(player, dailyReward(streak), false)
	notify(player, `Day {streak} reward: +{amount} coins! 🪙`, GOLD)
	self:CheckAchievements(player)
	self:QueueSync(player)
end

---------------------------------------------------------------- Quests

-- Jeden Tag neue Quests (pro Spieler und Tag fest, damit ein Rejoin nichts aendert)
local function ensureQuests(player: Player, data)
	local day = today()
	if data.Quests.Day == day and #data.Quests.List == #Config.QuestTypes then
		return
	end
	local rng = Random.new(day * 31 + player.UserId % 100000)
	local list = {}
	for _, questType in Config.QuestTypes do
		local tier = rng:NextInteger(1, #questType.Targets)
		table.insert(list, { Type = questType.Type, Target = questType.Targets[tier], Reward = questType.Rewards[tier], Progress = 0, Claimed = false })
	end
	data.Quests = { Day = day, List = list }
end

function RewardService:AddQuestProgress(player: Player, questType: string, amount: number)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	local changed = false
	for _, quest in data.Quests.List do
		if quest.Type == questType and not quest.Claimed and quest.Progress < quest.Target then
			quest.Progress = math.min(quest.Target, quest.Progress + amount)
			changed = true
			if quest.Progress >= quest.Target then
				notify(player, "Quest complete! Open Quests to claim your coins.", GREEN)
			end
		end
	end
	if changed then
		self:QueueSync(player)
	end
end

function RewardService:ClaimQuest(player: Player, index: number)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	local quest = data.Quests.List[index]
	if not quest or quest.Claimed or quest.Progress < quest.Target then
		return
	end
	quest.Claimed = true
	local amount = self:AddCoins(player, quest.Reward, true)
	notify(player, `Quest reward: +{amount} coins! 🪙`, GOLD)
	self:QueueSync(player)
end

---------------------------------------------------------------- Erfolge und Titel

local function statValue(data, stat: string): number
	if stat == "GemCount" then
		return Config.CountGems(data.GemMask)
	end
	return tonumber(data[stat]) or 0
end

function RewardService:CheckAchievements(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	-- "Coin Collector" steht als letzter Eintrag in der Liste und sieht so auch die Coins der anderen Erfolge
	for _, achievement in Config.Achievements do
		if not data.Achievements[achievement.Id] and statValue(data, achievement.Stat) >= achievement.Goal then
			data.Achievements[achievement.Id] = true
			-- direkt gutschreiben (nicht ueber AddCoins, sonst Rekursion)
			data.Coins += achievement.Reward
			data.CoinsEarned += achievement.Reward
			player:SetAttribute("Coins", data.Coins)
			notify(player, `🏅 Achievement: {achievement.Title}! +{achievement.Reward} coins. Equip the title in Titles.`, GOLD)
			if achievement.Reward >= 250 then
				self.Services.Net.SendAnnounce(`{player.DisplayName} earned the title "{achievement.Title}"!`, GOLD)
			end
			self:QueueSync(player)
		end
	end
end

function RewardService:EquipTitle(player: Player, id: string)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if id ~= "" and not (Config.AchievementsById[id] and data.Achievements[id]) then
		notify(player, "Unlock this title first.", RED)
		return
	end
	data.Title = id
	player:SetAttribute("Title", id)
	self.Services.CosmeticService:UpdateNameTag(player)
	notify(player, if id == "" then "Title removed." else `Title "{Config.AchievementsById[id].Title}" equipped!`, GREEN)
	self:QueueSync(player)
end

---------------------------------------------------------------- Codes

function RewardService:RedeemCode(player: Player, raw: string)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local code = string.upper((raw:gsub("%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		notify(player, "That code doesn't exist.", RED)
		return
	end
	if data.Codes[code] then
		notify(player, "You already used this code.", RED)
		return
	end
	data.Codes[code] = true
	local amount = self:AddCoins(player, reward, false)
	notify(player, `Code redeemed: +{amount} coins! 🪙`, GOLD)
end

---------------------------------------------------------------- Coin-Trails

function RewardService:BuyTrail(player: Player, trailId: string)
	local data = self.Services.DataService:Get(player)
	local trail = Config.TrailsById[trailId]
	if not data or not trail or not trail.Unlock.Coins then
		return
	end
	if data.OwnedTrails[trail.Id] then
		return
	end
	if not self:SpendCoins(player, trail.Unlock.Coins) then
		notify(player, `You need {Format.Number(trail.Unlock.Coins)} coins for this trail.`, RED)
		return
	end
	data.OwnedTrails[trail.Id] = true
	data.Trail = trail.Id
	self.Services.DataService:UpdateAttributes(player)
	self.Services.CosmeticService:Refresh(player)
	notify(player, `{trail.Name} trail unlocked and equipped!`, GOLD)
	self:QueueSync(player)
end

---------------------------------------------------------------- Regenbogen-Edelsteine

function RewardService:CollectGem(player: Player, worldIndex: number)
	local data = self.Services.DataService:Get(player)
	if not data or Config.HasGem(data.GemMask, worldIndex) then
		return
	end
	-- Plausibel? Die Stage des Edelsteins muss schon erreicht sein
	local stage = (worldIndex - 1) * Config.StagesPerWorld + Config.GemStageInWorld
	if data.BestStage < stage then
		return
	end
	data.GemMask = bit32.bor(data.GemMask, bit32.lshift(1, worldIndex - 1))
	player:SetAttribute("GemMask", data.GemMask)
	local count = Config.CountGems(data.GemMask)
	local amount = self:AddCoins(player, Config.GemReward, true)
	notify(player, `💎 Rainbow gem found! ({count}/{#Config.Worlds}) +{amount} coins`, GOLD)
	self:CheckAchievements(player)
end

---------------------------------------------------------------- Einstellungen

function RewardService:GetSetting(player: Player, key: string): boolean
	local data = self.Services.DataService:Get(player)
	local setting = Config.SettingsByKey[key]
	if not setting then
		return false
	end
	local value = data and data.Settings[key]
	if value == nil then
		return setting.Default
	end
	return value
end

---------------------------------------------------------------- Sync

function RewardService:BuildState(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return nil
	end
	ensureQuests(player, data)
	local quests = {}
	for _, quest in data.Quests.List do
		table.insert(quests, { Type = quest.Type, Target = quest.Target, Reward = quest.Reward, Progress = quest.Progress, Claimed = quest.Claimed })
	end
	local settings = {}
	for _, setting in Config.Settings do
		settings[setting.Key] = self:GetSetting(player, setting.Key)
	end
	local owned = {}
	for id in data.OwnedTrails do
		owned[id] = true
	end
	local achievements = {}
	for id in data.Achievements do
		achievements[id] = true
	end
	local streak = nextStreak(data)
	return {
		Quests = quests,
		Settings = settings,
		OwnedTrails = owned,
		Achievements = achievements,
		Daily = {
			Ready = dailyReady(data),
			Streak = if dailyReady(data) then streak else data.DailyStreak,
			Reward = dailyReward(if dailyReady(data) then streak else data.DailyStreak + 1),
		},
		Stats = {
			Deaths = data.Deaths,
			PlayTime = data.PlayTime,
			Wins = data.Wins,
			BestStage = data.BestStage,
			BestTime = data.BestTime,
			Gems = Config.CountGems(data.GemMask),
			CoinsEarned = data.CoinsEarned,
			Streak = data.DailyStreak,
		},
	}
end

function RewardService:SendState(player: Player)
	local state = self:BuildState(player)
	if state then
		self.Services.Net.Sync:FireClient(player, state)
	end
end

-- Mehrere Aenderungen in einem Frame zu einem Sync zusammenfassen
function RewardService:QueueSync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		if player.Parent then
			self:SendState(player)
		end
	end)
end

---------------------------------------------------------------- Lebenszyklus

function RewardService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	lastPlayTime[player] = data.PlayTime
	self:CheckAchievements(player)
	self:QueueSync(player)
end

function RewardService:OnPlayerRemoving(player: Player)
	lastRequest[player] = nil
	lastPlayTime[player] = nil
	syncQueued[player] = nil
end

function RewardService:Start()
	local net = self.Services.Net

	net.Sync.OnServerEvent:Connect(function(player)
		if allowed(player, "Sync", 1) then
			self:SendState(player)
		end
	end)
	net.ClaimDaily.OnServerEvent:Connect(function(player)
		if allowed(player, "ClaimDaily", 1) then
			self:ClaimDaily(player)
		end
	end)
	net.ClaimQuest.OnServerEvent:Connect(function(player, index)
		if typeof(index) == "number" and index == index and index % 1 == 0 and allowed(player, "ClaimQuest", 0.3) then
			self:ClaimQuest(player, index)
		end
	end)
	net.EquipTitle.OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" and #id <= 32 and allowed(player, "EquipTitle", 0.5) then
			self:EquipTitle(player, id)
		end
	end)
	net.RedeemCode.OnServerEvent:Connect(function(player, code)
		if typeof(code) == "string" and #code > 0 and #code <= 30 and allowed(player, "RedeemCode", 2) then
			self:RedeemCode(player, code)
		end
	end)
	net.BuyTrail.OnServerEvent:Connect(function(player, trailId)
		if typeof(trailId) == "string" and #trailId <= 32 and allowed(player, "BuyTrail", 0.5) then
			self:BuyTrail(player, trailId)
		end
	end)
	net.SetSetting.OnServerEvent:Connect(function(player, key, value)
		local data = self.Services.DataService:Get(player)
		if not data or typeof(key) ~= "string" or typeof(value) ~= "boolean" or not Config.SettingsByKey[key] then
			return
		end
		if not allowed(player, "SetSetting_" .. key, 0.2) then
			return
		end
		data.Settings[key] = value
		self:QueueSync(player)
	end)

	for worldIndex, gem in self.Services.WorldService.Gems do
		gem.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if player and humanoid and humanoid.Health > 0 then
				self:CollectGem(player, worldIndex)
			end
		end)
	end

	-- Spielzeit-Quest: nur aktive Zeit zaehlt (PlayTime wird von CommunityService gezaehlt)
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local data = self.Services.DataService:Get(player)
				local previous = lastPlayTime[player]
				if data and previous then
					local delta = data.PlayTime - previous
					lastPlayTime[player] = data.PlayTime
					if delta > 0 then
						self:AddQuestProgress(player, "Play", delta)
					end
				end
			end
		end
	end)
end

return RewardService
