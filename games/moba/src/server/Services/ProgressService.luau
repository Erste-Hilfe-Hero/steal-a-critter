-- Fortschritt neben dem Kampf: Konto-Stufe, Helden-Meisterschaft, Siegesserie, Tages-Quests, Erfolge mit Titeln,
-- Codes, Einstellungen, Anleitung, Emotes, Pings und die Bestenliste (Siege). Alles wird am Rundenende verrechnet
-- und ueber das Spieler-Attribut "Profile" (JSON) an die UI gegeben.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ProgressService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(110, 231, 160)
local LEADERBOARD_SIZE = 20
local LEADERBOARD_REFRESH = 120

local lastCode = {} -- [Player] = os.clock()
local lastEmote = {} -- [Player] = os.clock()
local pingTimes = {} -- [Player] = { os.clock() }
local lastPostedWins = {} -- [UserId] = Siege
local nameCache = {} -- [UserId] = Name
local leaderFolder: Folder
local orderedStore: OrderedDataStore? = nil

function ProgressService:Init(services)
	self.Services = services
	local existing = ReplicatedStorage:FindFirstChild("Leaderboard")
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = "Leaderboard"
		existing.Parent = ReplicatedStorage
	end
	leaderFolder = existing :: Folder
end

local function today(): number
	return ProgressService.Services.DataService.Today()
end

local function notify(player: Player, text: string, color: Color3?)
	ProgressService.Services.Net.SendNotify(player, text, color)
end

---------------------------------------------------------------- Hilfen

local function bestMastery(data): number
	local best = 0
	for _, points in data.Mastery do
		best = math.max(best, (Config.MasteryLevel(tonumber(points) or 0)))
	end
	return best
end

local function statValue(data, stat: string): number
	if stat == "BestMastery" then
		return bestMastery(data)
	end
	return tonumber(data[stat]) or 0
end

-- Titel-Text des ausgeruesteten Erfolgs ("" = kein Titel)
function ProgressService:TitleText(data): string
	local achievement = data and Config.AchievementsById[data.Title or ""]
	if achievement and data.Achievements[achievement.Id] then
		return achievement.Title
	end
	return ""
end

-- Tages-Quests auswuerfeln, wenn ein neuer Tag begonnen hat. Gibt true zurueck, wenn sich etwas geaendert hat.
function ProgressService:EnsureQuests(data): boolean
	local day = today()
	if typeof(data.Quests) == "table" and data.Quests.Day == day and typeof(data.Quests.List) == "table" then
		return false
	end
	local pool = {}
	for _, quest in Config.Quests do
		table.insert(pool, quest.Id)
	end
	local list = {}
	for _ = 1, math.min(Config.QuestsPerDay, #pool) do
		local id = table.remove(pool, math.random(1, #pool))
		table.insert(list, { Id = id, Progress = 0, Claimed = false })
	end
	data.Quests = { Day = day, List = list }
	return true
end

-- Alles, was die Menues brauchen, als Attribute (Profil als JSON)
function ProgressService:Publish(player: Player, data)
	if not data then
		return
	end
	local claimable = 0
	local quests = {}
	if typeof(data.Quests) == "table" and typeof(data.Quests.List) == "table" then
		for _, quest in data.Quests.List do
			local def = Config.QuestsById[quest.Id]
			if def then
				table.insert(quests, { Id = quest.Id, Progress = quest.Progress, Claimed = quest.Claimed == true })
				if not quest.Claimed and quest.Progress >= def.Goal then
					claimable += 1
				end
			end
		end
	end
	local achievements = {}
	for id in data.Achievements do
		table.insert(achievements, id)
	end
	local profile = {
		Level = data.AccountLevel,
		XP = data.AccountXP,
		Need = Config.AccountXPToLevel(data.AccountLevel),
		Wins = data.Wins,
		Matches = data.Matches,
		Kills = data.Kills,
		Deaths = data.Deaths,
		Assists = data.Assists,
		CS = data.CS,
		Towers = data.Towers,
		Epics = data.Epics,
		Wards = data.Wards,
		MVPs = data.MVPs,
		Pentas = data.Pentas,
		WinStreak = data.WinStreak,
		BestStreak = data.BestStreak,
		Mastery = data.Mastery,
		Quests = quests,
		Achievements = achievements,
		Title = data.Title,
	}
	local ok, json = pcall(HttpService.JSONEncode, HttpService, profile)
	if ok then
		player:SetAttribute("Profile", json)
	end
	player:SetAttribute("AccountLevel", data.AccountLevel)
	player:SetAttribute("Title", self:TitleText(data))
	player:SetAttribute("QuestsReady", claimable)
	player:SetAttribute("TutorialDone", data.Tutorial == true)
	local settings = data.Settings
	player:SetAttribute("Setting_Sound", settings.Sound ~= false)
	player:SetAttribute("Setting_Numbers", settings.Numbers ~= false)
	player:SetAttribute("Setting_Zoom", math.clamp(tonumber(settings.Zoom) or 1, 0.7, 1.4))
end

function ProgressService:CheckAchievements(player: Player, data): { string }
	local unlocked = {}
	for _, achievement in Config.Achievements do
		if not data.Achievements[achievement.Id] and statValue(data, achievement.Stat) >= achievement.Goal then
			data.Achievements[achievement.Id] = true
			data.Crystals += achievement.Reward
			table.insert(unlocked, achievement.Name)
			notify(player, `🏆 {achievement.Name}! Title "{achievement.Title}" unlocked, +{achievement.Reward} crystals`, GOLD)
		end
	end
	return unlocked
end

---------------------------------------------------------------- Rundenende

-- Siegesserie: ab dem 2. Sieg in Folge Bonus-Kristalle
function ProgressService:UpdateStreak(data, won: boolean): number
	if not won then
		data.WinStreak = 0
		return 0
	end
	data.WinStreak += 1
	data.BestStreak = math.max(data.BestStreak, data.WinStreak)
	return math.min(Config.WinStreak.Max, (data.WinStreak - 1) * Config.WinStreak.PerWin)
end

-- Statistik, Konto-Stufe, Meisterschaft, Quests und Erfolge. Kristalle aus Stufen und Erfolgen landen direkt in data.
function ProgressService:AfterMatch(player: Player, data, hero, won: boolean, mvp: boolean, minutes: number)
	local info = {}
	local extra = 0
	local takedowns = (hero.Kills or 0) + (hero.Assists or 0)
	-- Lebenszeit-Statistik
	data.CS += hero.CreepScore or 0
	data.Towers += hero.TowerTakedowns or 0
	data.Wards += hero.WardsPlaced or 0
	data.Epics += hero.EpicTakedowns or 0
	data.Monsters += hero.MonsterKills or 0
	data.Pentas += hero.Pentas or 0
	if mvp then
		data.MVPs += 1
	end

	-- Konto-Stufe
	local xp = (if won then Config.AccountXP.Win else Config.AccountXP.Loss) + Config.AccountXP.PerMinute * math.max(0, minutes)
	data.AccountXP += xp
	local levels = 0
	while data.AccountXP >= Config.AccountXPToLevel(data.AccountLevel) and levels < 50 do
		data.AccountXP -= Config.AccountXPToLevel(data.AccountLevel)
		data.AccountLevel += 1
		levels += 1
		local reward = Config.AccountLevelReward(data.AccountLevel)
		data.Crystals += reward
		extra += reward
	end
	if levels > 0 then
		notify(player, `⭐ Account level {data.AccountLevel}!`, GOLD)
	end
	info.AccountXP = xp
	info.AccountLevel = data.AccountLevel
	info.AccountUp = levels > 0

	-- Meisterschaft des gespielten Helden
	local mastery = Config.Mastery
	local before = tonumber(data.Mastery[hero.HeroId]) or 0
	local gained = (if won then mastery.Win else mastery.Loss) + math.min(mastery.MaxTakedownBonus, takedowns * mastery.PerTakedown)
	local oldLevel = Config.MasteryLevel(before)
	data.Mastery[hero.HeroId] = before + gained
	local newLevel = Config.MasteryLevel(before + gained)
	for level = oldLevel + 1, newLevel do
		local reward = level * mastery.RewardPerLevel
		data.Crystals += reward
		extra += reward
	end
	if newLevel > oldLevel then
		local def = Config.HeroesById[hero.HeroId]
		notify(player, `🎖 {if def then def.Name else hero.HeroId} mastery {newLevel}!`, GOLD)
	end
	info.MasteryHero = hero.HeroId
	info.MasteryGained = gained
	info.MasteryLevel = newLevel
	info.MasteryUp = newLevel > oldLevel

	-- Tages-Quests
	self:EnsureQuests(data)
	local values = {
		Matches = 1,
		Wins = if won then 1 else 0,
		Takedowns = takedowns,
		CS = hero.CreepScore or 0,
		Towers = hero.TowerTakedowns or 0,
		Wards = hero.WardsPlaced or 0,
		Epics = hero.EpicTakedowns or 0,
		Monsters = hero.MonsterKills or 0,
	}
	local done = 0
	for _, quest in data.Quests.List do
		local def = Config.QuestsById[quest.Id]
		if def and not quest.Claimed then
			local was = quest.Progress
			quest.Progress = math.min(def.Goal, was + (values[def.Stat] or 0))
			if was < def.Goal and quest.Progress >= def.Goal then
				done += 1
			end
		end
	end
	if done > 0 then
		notify(player, `📜 {done} daily quest{if done > 1 then "s" else ""} complete! Claim your crystals.`, GREEN)
	end
	info.QuestsDone = done

	info.Achievements = self:CheckAchievements(player, data)
	info.Extra = extra
	return info
end

---------------------------------------------------------------- Aktionen der Spieler

function ProgressService:ClaimQuest(player: Player, index: number)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data then
		return
	end
	if self:EnsureQuests(data) then
		-- Neuer Tag: die alte Liste gibt es nicht mehr
		dataService:UpdateAttributes(player)
		return
	end
	local quest = data.Quests.List[index]
	local def = quest and Config.QuestsById[quest.Id]
	if not quest or not def or quest.Claimed or quest.Progress < def.Goal then
		return
	end
	quest.Claimed = true
	data.Crystals += def.Reward
	dataService:UpdateAttributes(player)
	notify(player, `Quest done: +{def.Reward} crystals!`, GOLD)
	task.spawn(dataService.Save, dataService, player)
end

function ProgressService:EquipTitle(player: Player, id: string)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data then
		return
	end
	if id ~= "" and not (Config.AchievementsById[id] and data.Achievements[id]) then
		return
	end
	data.Title = id
	dataService:UpdateAttributes(player)
	-- Sofort am Helden sichtbar
	local hero = self.Services.HeroService:GetByPlayer(player)
	if hero then
		hero.Title = self:TitleText(data)
		if hero.Entry then
			hero.Entry:SetAttribute("Title", hero.Title)
		end
		if hero.Model then
			hero.Model:SetAttribute("Title", hero.Title)
		end
	end
end

function ProgressService:RedeemCode(player: Player, text: string)
	local t = os.clock()
	if t - (lastCode[player] or -math.huge) < 2 then
		return
	end
	lastCode[player] = t
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data then
		return
	end
	local code = string.upper((string.gsub(text, "%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		notify(player, "That code does not exist.", RED)
		return
	end
	if data.Codes[code] then
		notify(player, "You already used this code.", RED)
		return
	end
	data.Codes[code] = true
	data.Crystals += reward
	dataService:UpdateAttributes(player)
	notify(player, `Code redeemed: +{reward} crystals!`, GOLD)
	task.spawn(dataService.Save, dataService, player)
end

function ProgressService:SetSetting(player: Player, key: string, value: any)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data then
		return
	end
	if (key == "Sound" or key == "Numbers") and typeof(value) == "boolean" then
		data.Settings[key] = value
	elseif key == "Zoom" and typeof(value) == "number" and value == value and value > -math.huge and value < math.huge then
		data.Settings.Zoom = math.clamp(math.floor(value * 10 + 0.5) / 10, 0.7, 1.4)
	else
		return
	end
	dataService:UpdateAttributes(player)
end

function ProgressService:FinishTutorial(player: Player)
	local data = self.Services.DataService:Get(player)
	if data and not data.Tutorial then
		data.Tutorial = true
		self.Services.DataService:UpdateAttributes(player)
	end
end

---------------------------------------------------------------- Bestenliste (Siege)

function ProgressService:PostWins(player: Player, data)
	local store = orderedStore
	if not store or not data or data.Wins <= 0 or lastPostedWins[player.UserId] == data.Wins then
		return
	end
	-- Ersatzdaten nach einem Ladefehler wuerden den echten Eintrag ueberschreiben
	if not self.Services.DataService:CanSave(player) then
		return
	end
	lastPostedWins[player.UserId] = data.Wins
	local wins = data.Wins
	task.spawn(function()
		local ok, err = pcall(function()
			store:SetAsync(tostring(player.UserId), wins)
		end)
		if not ok then
			lastPostedWins[player.UserId] = nil
			warn("[Leaderboard]", err)
		end
	end)
end

function ProgressService:RefreshLeaderboard()
	local store = orderedStore
	if not store then
		return
	end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, LEADERBOARD_SIZE):GetCurrentPage()
	end)
	if not ok or typeof(page) ~= "table" then
		return
	end
	local list = {}
	for rank, entry in page do
		local userId = tonumber(entry.key)
		if userId then
			local name = nameCache[userId]
			if not name then
				local live = Players:GetPlayerByUserId(userId)
				if live then
					name = live.DisplayName
				else
					local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
					name = if okName and typeof(result) == "string" then result else "Player"
				end
				nameCache[userId] = name
			end
			table.insert(list, { Rank = rank, Name = name, Wins = tonumber(entry.value) or 0, UserId = userId })
		end
	end
	local okJson, json = pcall(HttpService.JSONEncode, HttpService, list)
	if okJson then
		leaderFolder:SetAttribute("Top", json)
		leaderFolder:SetAttribute("UpdatedAt", os.time())
	end
end

---------------------------------------------------------------- Start

function ProgressService:OnPlayerReady(player: Player)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data then
		return
	end
	self:EnsureQuests(data)
	dataService:UpdateAttributes(player)
	self:PostWins(player, data)
end

function ProgressService:OnPlayerRemoving(player: Player)
	lastCode[player] = nil
	lastEmote[player] = nil
	pingTimes[player] = nil
end

function ProgressService:Start()
	local net = self.Services.Net
	local dataService = self.Services.DataService
	local heroService = self.Services.HeroService
	local combat = self.Services.CombatService

	local okStore, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, Config.LeaderboardStore)
	if okStore then
		orderedStore = store
	end

	net.ClaimQuest.OnServerEvent:Connect(function(player, index)
		if typeof(index) == "number" and index == math.floor(index) and index >= 1 and index <= Config.QuestsPerDay then
			self:ClaimQuest(player, index)
		end
	end)
	net.EquipTitle.OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" and #id <= 40 then
			self:EquipTitle(player, id)
		end
	end)
	net.RedeemCode.OnServerEvent:Connect(function(player, text)
		if typeof(text) == "string" and #text > 0 and #text <= 30 then
			self:RedeemCode(player, text)
		end
	end)
	net.SetSetting.OnServerEvent:Connect(function(player, key, value)
		if typeof(key) == "string" then
			self:SetSetting(player, key, value)
		end
	end)
	net.TutorialDone.OnServerEvent:Connect(function(player)
		self:FinishTutorial(player)
	end)

	-- Emotes: fuer alle sichtbar ueber dem eigenen Helden
	net.Emote.OnServerEvent:Connect(function(player, id)
		local emote = typeof(id) == "string" and Config.EmotesById[id]
		if not emote then
			return
		end
		local t = os.clock()
		if t - (lastEmote[player] or -math.huge) < Config.EmoteCooldown then
			return
		end
		local hero = heroService:GetByPlayer(player)
		if not hero or not combat.Alive(hero) or not hero.Model then
			return
		end
		lastEmote[player] = t
		net.SendFx("Emote", { Model = hero.Model, Icon = emote.Icon, Text = emote.Text })
	end)

	-- Pings: nur fuer das eigene Team (Karte und Welt)
	net.Ping.OnServerEvent:Connect(function(player, id)
		local ping = typeof(id) == "string" and Config.PingsById[id]
		if not ping or not self.Services.MatchService:IsPlaying() then
			return
		end
		local hero = heroService:GetByPlayer(player)
		if not hero then
			return
		end
		local t = os.clock()
		local times = pingTimes[player] or {}
		for i = #times, 1, -1 do
			if t - times[i] > Config.PingLimit.Window then
				table.remove(times, i)
			end
		end
		if #times >= Config.PingLimit.Count then
			notify(player, "Too many pings - wait a moment.", RED)
			return
		end
		table.insert(times, t)
		pingTimes[player] = times
		local at = combat.Position(hero)
		local focus = hero.Focus
		if ping.Id == "Attack" and focus and combat:Targetable(focus, hero.Team) then
			at = combat.Position(focus)
		end
		for _, other in Players:GetPlayers() do
			if other:GetAttribute("Team") == hero.Team then
				net.Ping:FireClient(other, { Id = ping.Id, At = at, Name = player.DisplayName, UserId = player.UserId })
			end
		end
	end)

	-- Jede Minute: neuer Tag (Quests, Tagesbelohnung) und alle 2 Minuten die Bestenliste
	task.spawn(function()
		local sinceBoard = LEADERBOARD_REFRESH - 10
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = dataService:Get(player)
				if data then
					local changed = self:EnsureQuests(data)
					if changed or player:GetAttribute("DailyReady") ~= (data.DailyDay < today()) then
						dataService:UpdateAttributes(player)
					end
				end
			end
			sinceBoard += 60
			if sinceBoard >= LEADERBOARD_REFRESH then
				sinceBoard = 0
				task.spawn(self.RefreshLeaderboard, self)
			end
		end
	end)
	task.delay(8, function()
		self:RefreshLeaderboard()
	end)
end

return ProgressService
