-- Fortschritt, der zum Wiederkommen motiviert: taegliche Quests, Erfolge, Critter-Index und Statistiken.
-- Der Client bekommt den kompletten Stand ueber Net.Sync (gebuendelt, hoechstens zweimal pro Sekunde).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local ProgressService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)

local questsById = {}
for _, quest in Config.Quests do
	questsById[quest.Id] = quest
end
local achievementsById = {}
for _, achievement in Config.Achievements do
	achievementsById[achievement.Id] = achievement
end

local dirty = {} -- [Player] = true: Stand muss neu gesendet werden
local extraState = {} -- [Player] = { [Key] = Wert } von anderen Services (z.B. RewardService)

function ProgressService:Init(services)
	self.Services = services
end

local function today(): number
	return os.time() // 86400
end

local function income(player: Player): number
	return tonumber(player:GetAttribute("IncomePerSec")) or 0
end

-- Cash-Belohnung, die mit dem Einkommen mitwaechst
function ProgressService.IncomeReward(player: Player, minutes: number, minCash: number): number
	return math.floor(math.max(minCash, income(player) * 60 * minutes))
end

function ProgressService:MarkDirty(player: Player)
	dirty[player] = true
end

-- Andere Services haengen eigene Werte an den gesendeten Stand
function ProgressService:SetExtra(player: Player, key: string, value: any)
	extraState[player] = extraState[player] or {}
	extraState[player][key] = value
	dirty[player] = true
end

---------------------------------------------------------------- Statistiken

local function indexCount(data): number
	local count = 0
	for id in data.Index do
		if Config.UnitsById[id] then
			count += 1
		end
	end
	return count
end
ProgressService.IndexCount = indexCount

local function statValue(player: Player, data, stat: string): number
	if stat == "Rebirths" then
		return data.Rebirths
	elseif stat == "Index" then
		return indexCount(data)
	elseif stat == "TotalEarned" then
		return data.TotalEarned
	elseif stat == "Streak" then
		return data.RewardStreak or 0
	end
	return data.Stats[stat] or 0
end

---------------------------------------------------------------- Quests

-- Neue Quests fuer heute (immer verschiedene Arten)
local function rollQuests(data)
	local pool = table.clone(Config.Quests)
	local list = {}
	for _ = 1, math.min(Config.QuestsPerDay, #pool) do
		local quest = table.remove(pool, math.random(1, #pool))
		table.insert(list, { Id = quest.Id, Goal = quest.Goals[math.random(1, #quest.Goals)], Progress = 0, Claimed = false })
	end
	data.Quests = { Day = today(), List = list, BonusClaimed = false }
end

local function ensureQuests(data)
	if type(data.Quests) ~= "table" or data.Quests.Day ~= today() or type(data.Quests.List) ~= "table" then
		rollQuests(data)
		return true
	end
	return false
end

local function questReward(player: Player, entry): number
	local quest = questsById[entry.Id]
	local scale = entry.Goal / quest.Goals[1]
	return ProgressService.IncomeReward(player, quest.Minutes * math.sqrt(scale), Config.QuestMinCash * scale)
end

---------------------------------------------------------------- Zaehlen

function ProgressService:Track(player: Player, stat: string, amount: number?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	amount = amount or 1
	data.Stats[stat] = (data.Stats[stat] or 0) + (amount :: number)
	ensureQuests(data)
	for _, entry in data.Quests.List do
		local quest = questsById[entry.Id]
		if quest and quest.Stat == stat and entry.Progress < entry.Goal then
			entry.Progress = math.min(entry.Goal, entry.Progress + (amount :: number))
			if entry.Progress >= entry.Goal then
				self.Services.Net.SendNotify(player, "Quest complete! Open QUESTS to claim your reward.", GOLD)
			end
		end
	end
	self:CheckAchievements(player)
	dirty[player] = true
	-- Critter Pass XP (Update 3)
	if self.Services.FeatureService then
		self.Services.FeatureService:OnStat(player, stat, amount :: number)
	end
end

-- Meldet neu erreichte Erfolge (abholen im Fenster AWARDS)
local announced = {} -- [Player] = { [Id] = true }
function ProgressService:CheckAchievements(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	announced[player] = announced[player] or {}
	for _, achievement in Config.Achievements do
		if not data.Achievements[achievement.Id] and not announced[player][achievement.Id] and statValue(player, data, achievement.Stat) >= achievement.Goal then
			announced[player][achievement.Id] = true
			self.Services.Net.SendNotify(player, `🏆 Achievement unlocked: {achievement.Name}! Claim it in AWARDS.`, GOLD)
		end
	end
	dirty[player] = true
end

---------------------------------------------------------------- Index

-- Neue Art entdeckt: dauerhaft mehr Einkommen
function ProgressService:Discover(player: Player, unitId: string)
	local data = self.Services.DataService:Get(player)
	if not data or not Config.UnitsById[unitId] or data.Index[unitId] then
		return
	end
	data.Index[unitId] = true
	local def = Config.UnitsById[unitId]
	self.Services.Net.SendNotify(player, `📖 NEW in your Index: {def.Name}! +{math.floor(Config.IndexBonusPer * 100)}% income forever`, Config.RaritiesByName[def.Rarity].Color)
	self.Services.UnitService:UpdateIncome(player)
	self:CheckAchievements(player)
end

function ProgressService:GetIndexBonus(player: Player): number
	local data = self.Services.DataService:Get(player)
	return if data then indexCount(data) * Config.IndexBonusPer else 0
end

---------------------------------------------------------------- Abholen

local function claimQuest(player: Player, index: any)
	local data = ProgressService.Services.DataService:Get(player)
	if not data or type(index) ~= "number" then
		return false, "Not ready"
	end
	ensureQuests(data)
	local entry = data.Quests.List[index]
	if not entry or entry.Claimed or entry.Progress < entry.Goal then
		return false, "Not completed yet"
	end
	entry.Claimed = true
	local reward = questReward(player, entry)
	ProgressService.Services.DataService:AddCash(player, reward)
	data.Stats.QuestsDone = (data.Stats.QuestsDone or 0) + 1
	local text = `Quest reward: +{Format.Cash(reward)}!`
	local allDone = true
	for _, other in data.Quests.List do
		if not other.Claimed then
			allDone = false
		end
	end
	if allDone and not data.Quests.BonusClaimed then
		data.Quests.BonusClaimed = true
		local bonus = ProgressService.IncomeReward(player, Config.AllQuestsBonusMinutes, 10_000)
		ProgressService.Services.DataService:AddCash(player, bonus)
		text ..= ` ALL QUESTS DONE: +{Format.Cash(bonus)} bonus! New quests tomorrow.`
	end
	ProgressService.Services.Net.SendNotify(player, text, GOLD)
	ProgressService:CheckAchievements(player)
	return true, text
end

local function claimAchievement(player: Player, id: any)
	local data = ProgressService.Services.DataService:Get(player)
	local achievement = type(id) == "string" and achievementsById[id]
	if not data or not achievement or data.Achievements[id] then
		return false, "Not available"
	end
	if statValue(player, data, achievement.Stat) < achievement.Goal then
		return false, "Not reached yet"
	end
	data.Achievements[id] = true
	ProgressService.Services.DataService:AddCash(player, achievement.Cash)
	ProgressService.Services.Net.SendNotify(player, `🏆 {achievement.Name}: +{Format.Cash(achievement.Cash)}!`, GOLD)
	dirty[player] = true
	return true
end

local function claimIndex(player: Player)
	local data = ProgressService.Services.DataService:Get(player)
	local milestone = data and Config.IndexMilestones[(data.IndexClaimed or 0) + 1]
	if not data or not milestone then
		return false, "Nothing to claim"
	end
	if indexCount(data) < milestone.Count then
		return false, `Discover {milestone.Count - indexCount(data)} more critters`
	end
	data.IndexClaimed = (data.IndexClaimed or 0) + 1
	ProgressService.Services.DataService:AddCash(player, milestone.Cash)
	ProgressService.Services.Net.SendNotify(player, `📖 Index milestone {milestone.Count}: +{Format.Cash(milestone.Cash)}!`, GOLD)
	dirty[player] = true
	return true
end

-- Quest Skip (Robux): erste offene Quest sofort erledigen. Gibt false zurueck, wenn keine offen ist.
function ProgressService:SkipQuest(player: Player): boolean
	local data = self.Services.DataService:Get(player)
	if not data then
		return false
	end
	ensureQuests(data)
	for _, entry in data.Quests.List do
		if entry.Progress < entry.Goal then
			entry.Progress = entry.Goal
			dirty[player] = true
			self.Services.Net.SendNotify(player, "Quest skipped! Open QUESTS to claim your reward.", GOLD)
			return true
		end
	end
	return false
end

---------------------------------------------------------------- Stand senden

local function buildState(player: Player)
	local data = ProgressService.Services.DataService:Get(player)
	if not data then
		return nil
	end
	ensureQuests(data)
	local quests = {}
	for _, entry in data.Quests.List do
		local quest = questsById[entry.Id]
		if quest then
			table.insert(quests, {
				Text = string.format(quest.Text, entry.Goal),
				Goal = entry.Goal,
				Progress = entry.Progress,
				Claimed = entry.Claimed,
				Reward = questReward(player, entry),
			})
		end
	end
	local achievements = {}
	for _, achievement in Config.Achievements do
		table.insert(achievements, {
			Id = achievement.Id,
			Name = achievement.Name,
			Goal = achievement.Goal,
			Stat = achievement.Stat,
			Progress = math.min(statValue(player, data, achievement.Stat), achievement.Goal),
			Reward = achievement.Cash,
			Claimed = data.Achievements[achievement.Id] == true,
		})
	end
	local state = {
		Quests = quests,
		QuestsReset = (today() + 1) * 86400,
		QuestBonus = ProgressService.IncomeReward(player, Config.AllQuestsBonusMinutes, 10_000),
		QuestBonusClaimed = data.Quests.BonusClaimed == true,
		Achievements = achievements,
		Index = table.clone(data.Index),
		IndexCount = indexCount(data),
		IndexNext = Config.IndexMilestones[(data.IndexClaimed or 0) + 1],
		Stats = table.clone(data.Stats),
	}
	for key, value in extraState[player] or {} do
		state[key] = value
	end
	return state
end

function ProgressService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	ensureQuests(data)
	-- Alte Spielstaende: vorhandene Kreaturen zaehlen schon fuer den Index
	for _, code in data.Units do
		local id = type(code) == "string" and code:match("^([^:]+)")
		if id and Config.UnitsById[id] then
			data.Index[id] = true
		end
	end
	self:CheckAchievements(player)
	dirty[player] = true
end

function ProgressService:OnPlayerRemoving(player: Player)
	dirty[player] = nil
	extraState[player] = nil
	announced[player] = nil
end

function ProgressService:Start()
	local net = self.Services.Net
	net.Handle("ClaimQuest", claimQuest)
	net.Handle("ClaimAchievement", claimAchievement)
	net.Handle("ClaimIndex", claimIndex)
	net.Handle("GetState", function(player)
		dirty[player] = true
		return true
	end)
	net.Handle("SkipQuest", function(player)
		local product = Config.DevProducts.QuestSkip
		self.Services.MonetizationService:PromptProduct(player, "QuestSkip", product)
		return true
	end)

	-- Gebuendelt senden
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player in dirty do
				dirty[player] = nil
				if player.Parent then
					local state = buildState(player)
					if state then
						net.Sync:FireClient(player, state)
					end
				end
			end
		end
	end)

	-- Jede Minute: Spielzeit-Quest zaehlen, neuer Tag = neue Quests; alle 10 Sekunden Belohnungen aktualisieren
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(10)
			tick += 1
			for _, player in Players:GetPlayers() do
				if self.Services.DataService:Get(player) then
					if tick % 6 == 0 then
						self:Track(player, "Minutes", 1)
					end
					self:CheckAchievements(player)
				end
			end
		end
	end)
end

return ProgressService
