-- Fahrer-Level (XP), taegliche Aufgaben, Erfolge mit Titeln, Bestzeiten, Siegesserie, Codes,
-- Einstellungen, Tutorial-Belohnung, Profil-Abfrage und das Namensschild ueber dem Kopf in der Lobby.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Tracks = require(ReplicatedStorage.Shared.Tracks)

local ProgressService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 225, 120)
local RED = Color3.fromRGB(255, 90, 90)
local TITLE_FONT = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)

-- Codes (Grossschreibung egal). Jeder Code nur einmal pro Spieler.
local CODES = {
	FIRE = { Coins = 500 },
	DRIFTKING = { Coins = 750 },
	BLASTOFF = { Coins = 1_000 },
	INFERNO = { SuperItems = 1 },
}

local lastCodeTry: { [Player]: number } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

function ProgressService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Namensschild ueber dem Kopf

local function refreshOverhead(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("RacerTag") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "RacerTag"
		g.Size = UDim2.fromOffset(180, 26)
		g.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		g.MaxDistance = 80
		g.Parent = head
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.FontFace = TITLE_FONT
		label.TextColor3 = Color3.fromRGB(255, 200, 80)
		label.Parent = g
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(30, 15, 10)
		stroke.Parent = label
		gui = g
	end
	-- Im Rennen traegt das Kart schon ein Namensschild
	(gui :: BillboardGui).Enabled = player:GetAttribute("Racing") ~= true
	local level = player:GetAttribute("Level") or 1
	local title = player:GetAttribute("Title") or ""
	local label = (gui :: BillboardGui):FindFirstChild("Label") :: TextLabel
	label.Text = if title ~= "" then `LV {level}  -  {string.upper(title)}` else `LV {level}`
end
ProgressService.RefreshOverhead = refreshOverhead

---------------------------------------------------------------- Aufgaben

local function syncQuests(player: Player, data)
	player:SetAttribute("Quests", HttpService:JSONEncode(data.Quests.List))
	local ready = 0
	for _, entry in data.Quests.List do
		local quest = Progression.QuestsById[entry.Id]
		if quest and not entry.Claimed and entry.Progress >= quest.Goal then
			ready += 1
		end
	end
	player:SetAttribute("QuestsReady", ready)
end

local function ensureQuests(player: Player, data)
	local day = today()
	if data.Quests.Day == day and #data.Quests.List > 0 then
		return
	end
	data.Quests.Day = day
	data.Quests.List = {}
	for _, id in Progression.QuestsForDay(day, player.UserId) do
		table.insert(data.Quests.List, { Id = id, Progress = 0, Claimed = false })
	end
	syncQuests(player, data)
end

---------------------------------------------------------------- Erfolge

function ProgressService:CheckAchievements(player: Player)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	for _, achievement in Progression.Achievements do
		if not data.Achievements[achievement.Id] then
			local ok, reached = pcall(achievement.Check, data)
			if ok and reached then
				data.Achievements[achievement.Id] = true
				services.DataService:AddCoins(player, achievement.Coins)
				services.Net.SendNotify(player, `Achievement: {achievement.Text}! Title "{achievement.Title}" + {Format.Number(achievement.Coins)} coins`, GOLD)
				services.Net.Effect:FireClient(player, "Achievement", achievement.Id)
				if data.Title == "" then
					data.Title = achievement.Title
					services.DataService:UpdateAttributes(player)
					refreshOverhead(player)
				end
			end
		end
	end
end

---------------------------------------------------------------- XP und Level

function ProgressService:AddXp(player: Player, amount: number)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	local before = Progression.LevelFromXp(data.XP)
	data.XP += math.floor(amount)
	local after = Progression.LevelFromXp(data.XP)
	if after > before then
		local reward = 0
		for level = before + 1, after do
			reward += Progression.LevelReward(level)
		end
		services.DataService:AddCoins(player, reward)
		services.Net.SendNotify(player, `LEVEL UP! You are now level {after}: +{Format.Number(reward)} coins`, GOLD)
		services.Net.Effect:FireClient(player, "LevelUp", after)
		if after >= 10 and after % 5 == 0 then
			services.Net.SendAnnounce(`{player.DisplayName} reached racer level {after}!`, GOLD)
		end
	end
	services.DataService:UpdateAttributes(player)
	if after > before then
		refreshOverhead(player)
		self:CheckAchievements(player)
	end
end

-- Zaehler erhoehen (Statistik + passende Tagesaufgaben). Stat: Races, Podiums, Wins, Hits, ItemsUsed, Boxes, TrackCoins
function ProgressService:Add(player: Player, stat: string, amount: number?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local n = amount or 1
	if data.Stats[stat] ~= nil then
		data.Stats[stat] += n
	end
	ensureQuests(player, data)
	local changed = false
	for _, entry in data.Quests.List do
		local quest = Progression.QuestsById[entry.Id]
		if quest and quest.Stat == stat and not entry.Claimed and entry.Progress < quest.Goal then
			entry.Progress = math.min(quest.Goal, entry.Progress + n)
			changed = true
			if entry.Progress >= quest.Goal then
				self.Services.Net.SendNotify(player, `Quest complete: {quest.Text}! Claim it in QUESTS.`, GREEN)
				self.Services.Net.Effect:FireClient(player, "Quest", quest.Id)
			end
		end
	end
	if changed then
		syncQuests(player, data)
	end
	if stat == "Hits" or stat == "TrackCoins" then
		self:CheckAchievements(player)
	end
end

---------------------------------------------------------------- Nach dem Rennen

-- Wird fuer jeden Menschen aufgerufen, der das Rennen regulaer beendet hat. Gibt Zusatzinfos fuer das Ergebnisfenster zurueck.
function ProgressService:AfterRace(player: Player, trackId: string, place: number, racers: number, time: number?)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return {}
	end
	local info = {}
	-- Siegesserie
	if place == 1 then
		data.WinStreak += 1
		data.BestStreak = math.max(data.BestStreak, data.WinStreak)
		local bonus = Progression.StreakBonus(data.WinStreak)
		if bonus > 0 then
			services.DataService:AddCoins(player, bonus)
			info.StreakBonus = bonus
		end
		if data.WinStreak >= 3 then
			services.Net.SendAnnounce(`{player.DisplayName} is ON FIRE: {data.WinStreak} wins in a row!`, Color3.fromRGB(255, 110, 20))
		end
	else
		data.WinStreak = 0
	end
	info.Streak = data.WinStreak
	-- Persoenliche Bestzeit (nur plausible Zeiten)
	local geo = Tracks.Geometry(trackId)
	local minTime = Config.Laps * geo.Length / 150
	if time and time >= minTime then
		local best = data.Best[trackId]
		if not best or time < best then
			data.Best[trackId] = time
			info.NewBest = best ~= nil
			services.LobbyService:SubmitTime(player, trackId, time)
		end
		info.Best = data.Best[trackId]
	end
	-- XP und Aufgaben
	local xp = Progression.RaceXp(place, racers)
	info.Xp = xp
	self:Add(player, "Races", 1)
	if place <= 3 then
		self:Add(player, "Podiums", 1)
	end
	if place == 1 then
		self:Add(player, "Wins", 1)
	end
	self:AddXp(player, xp)
	services.DataService:UpdateAttributes(player)
	self:CheckAchievements(player)
	return info
end

---------------------------------------------------------------- Remotes

local function handleClaim(player: Player, what: any, arg: any)
	local services = ProgressService.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	if what == "Quest" then
		if typeof(arg) ~= "number" or arg ~= arg then
			return
		end
		ensureQuests(player, data)
		local entry = data.Quests.List[math.floor(arg)]
		local quest = entry and Progression.QuestsById[entry.Id]
		if not quest or entry.Claimed or entry.Progress < quest.Goal then
			return
		end
		entry.Claimed = true
		services.DataService:AddCoins(player, quest.Coins)
		services.Net.SendNotify(player, `Quest reward: +{Format.Number(quest.Coins)} coins, +{Progression.QuestXp} XP!`, GOLD)
		syncQuests(player, data)
		ProgressService:AddXp(player, Progression.QuestXp)
	elseif what == "Tutorial" then
		if data.TutorialDone then
			return
		end
		data.TutorialDone = true
		services.DataService:AddCoins(player, Progression.TutorialCoins)
		services.Net.SendNotify(player, `Ready to race! +{Progression.TutorialCoins} coins`, GOLD)
	end
end

local function handleTitle(player: Player, id: any)
	local services = ProgressService.Services
	local data = services.DataService:Get(player)
	if not data or typeof(id) ~= "string" then
		return
	end
	if id == "" then
		data.Title = ""
	else
		local achievement = Progression.AchievementsById[id]
		if not achievement or not data.Achievements[id] then
			return
		end
		data.Title = achievement.Title
	end
	services.DataService:UpdateAttributes(player)
	refreshOverhead(player)
end

local function handleSetting(player: Player, key: any, value: any)
	local services = ProgressService.Services
	local data = services.DataService:Get(player)
	if not data or typeof(key) ~= "string" or typeof(value) ~= "boolean" or not Progression.SettingsByKey[key] then
		return
	end
	data.Settings[key] = value
	player:SetAttribute("Set_" .. key, value)
end

local function handleCode(player: Player, code: any)
	local services = ProgressService.Services
	local data = services.DataService:Get(player)
	if not data or typeof(code) ~= "string" or #code > 24 then
		return
	end
	local t = os.clock()
	if t - (lastCodeTry[player] or -math.huge) < 2 then
		services.Net.SendNotify(player, "Slow down! Try again in a moment.", RED)
		return
	end
	lastCodeTry[player] = t
	local key = string.upper((code:gsub("%s", "")))
	local reward = CODES[key]
	if not reward then
		services.Net.SendNotify(player, "That code does not exist.", RED)
		return
	end
	if data.Codes[key] then
		services.Net.SendNotify(player, "You already used this code.", RED)
		return
	end
	data.Codes[key] = true
	if reward.Coins then
		services.DataService:AddCoins(player, reward.Coins)
		services.Net.SendNotify(player, `Code redeemed: +{Format.Number(reward.Coins)} coins!`, GOLD)
	end
	if reward.SuperItems then
		data.SuperItems += reward.SuperItems
		services.DataService:UpdateAttributes(player)
		services.Net.SendNotify(player, `Code redeemed: +{reward.SuperItems} Inferno item!`, GOLD)
	end
end

-- Profil fuer das Profil-Fenster (Statistik, Erfolge, Bestzeiten)
local function getProfile(player: Player)
	local data = ProgressService.Services.DataService:Get(player)
	if not data then
		return nil
	end
	local level, into, need = Progression.LevelFromXp(data.XP)
	return {
		Level = level,
		XpInto = into,
		XpNeed = need,
		Wins = data.Wins,
		Races = data.Races,
		Podiums = data.Podiums,
		BestStreak = data.BestStreak,
		Hits = data.Stats.Hits,
		TrackCoins = data.Stats.TrackCoins,
		TotalCoins = data.TotalCoins,
		PlayTime = data.PlayTime,
		Achievements = table.clone(data.Achievements),
		Title = data.Title,
		Best = table.clone(data.Best),
	}
end

---------------------------------------------------------------- Start

function ProgressService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	syncQuests(player, data)
	self:CheckAchievements(player)
	if player.Character then
		refreshOverhead(player)
	end
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		refreshOverhead(player)
	end)
	player:GetAttributeChangedSignal("Racing"):Connect(function()
		refreshOverhead(player)
	end)
end

function ProgressService:Start()
	local net = self.Services.Net
	net.Claim.OnServerEvent:Connect(handleClaim)
	net.SetTitle.OnServerEvent:Connect(handleTitle)
	net.Setting.OnServerEvent:Connect(handleSetting)
	net.RedeemCode.OnServerEvent:Connect(handleCode)
	net.GetProfile.OnServerInvoke = getProfile
	Players.PlayerRemoving:Connect(function(player)
		lastCodeTry[player] = nil
	end)
	-- Neuer Tag waehrend man spielt: neue Aufgaben
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = self.Services.DataService:Get(player)
				if data then
					ensureQuests(player, data)
				end
			end
		end
	end)
end

return ProgressService
