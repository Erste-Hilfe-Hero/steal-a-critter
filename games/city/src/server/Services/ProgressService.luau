-- Update 2: langfristiger Fortschritt.
--   Karriere-Stufen (XP), Erfolge mit Titeln, taegliches Gluecksrad (nur Spielgeld),
--   versteckte Turbo-Token, Einstellungen pro Spieler und das Tutorial fuer neue Spieler.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local ProgressService = { Services = nil :: any }

local C = Config.Colors
local TOKEN_RADIUS = 9

local tutorialDrive = {} -- [Player] = gefahrene Studs waehrend des Tutorials
local spinRng = Random.new()

local function today(): number
	return os.time() // 86400
end

local function notify(player: Player, text: string, color: Color3?)
	ProgressService.Services.Net.SendNotify(player, text, color)
end

local function celebrate(player: Player, title: string, subtitle: string, kind: string)
	ProgressService.Services.Net.Celebrate:FireClient(player, title, subtitle, kind)
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

---------------------------------------------------------------- Attribute fuer den Client

function ProgressService:Sync(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local unlocked = {}
	for id in data.Achievements do
		table.insert(unlocked, id)
	end
	table.sort(unlocked)
	player:SetAttribute("Achievements", table.concat(unlocked, ","))
	local tokens = {}
	for id in data.Tokens do
		table.insert(tokens, id)
	end
	table.sort(tokens)
	player:SetAttribute("Tokens", table.concat(tokens, ","))
	player:SetAttribute("Settings", HttpService:JSONEncode(data.Settings))
	player:SetAttribute("SpinReady", data.SpinDay ~= today())
	local step = Config.Tutorial[data.Tutorial + 1]
	player:SetAttribute("TutorialStep", if step then data.Tutorial + 1 else nil)
	player:SetAttribute("Title", if data.Title ~= "" then data.Title else nil)
	player:SetAttribute("TopSpeed", data.Stats.TopSpeed)
	local stats = data.Stats
	player:SetAttribute("StatsText", HttpService:JSONEncode({
		Deliveries = stats.Deliveries,
		Arrests = stats.Arrests,
		Robberies = stats.Robberies,
		Races = stats.Races,
		Jailed = stats.Jailed,
		Trucks = stats.Trucks,
		Chores = stats.Chores,
		Sprays = stats.Sprays,
		TotalEarned = data.TotalEarned,
		PlayTime = data.PlayTime,
		Level = data.Level,
		Tokens = count(data.Tokens),
		Cars = count(data.Cars),
		House = data.House,
		TopSpeed = stats.TopSpeed,
	}))
end

---------------------------------------------------------------- Stufen

function ProgressService:AddXP(player: Player, amount: number)
	local data = self.Services.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	data.XP += math.floor(amount)
	local leveled = false
	while data.Level < Config.MaxLevel and data.XP >= Config.XpForLevel(data.Level) do
		data.XP -= Config.XpForLevel(data.Level)
		data.Level += 1
		leveled = true
		local reward = Config.LevelReward(data.Level)
		self.Services.DataService:AddCash(player, reward)
		celebrate(player, `LEVEL {data.Level}!`, `Level-up bonus +{Format.Cash(reward)}`, "Level")
		if data.Level % 5 == 0 then
			self.Services.Net.SendAnnounce(`{player.DisplayName} reached level {data.Level}!`, C.Lemon)
		end
	end
	if data.Level >= Config.MaxLevel then
		data.XP = math.min(data.XP, Config.XpForLevel(data.Level))
	end
	self.Services.DataService:UpdateAttributes(player)
	if leveled then
		self:Check(player)
	end
end

---------------------------------------------------------------- Erfolge und Titel

local function statValue(data, stat: string): number
	if stat == "Level" then
		return data.Level
	elseif stat == "TotalEarned" then
		return data.TotalEarned
	elseif stat == "Tokens" then
		return count(data.Tokens)
	elseif stat == "Cars" then
		return count(data.Cars)
	elseif stat == "House" then
		return data.House
	end
	return data.Stats[stat] or 0
end
ProgressService.StatValue = statValue

-- Prueft alle Erfolge und vergibt neue
function ProgressService:Check(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	for _, achievement in Config.Achievements do
		if not data.Achievements[achievement.Id] and statValue(data, achievement.Stat) >= achievement.Goal then
			data.Achievements[achievement.Id] = true
			self.Services.DataService:AddCash(player, achievement.Reward)
			celebrate(player, "TROPHY UNLOCKED!", `{achievement.Name}  +{Format.Cash(achievement.Reward)}  Title: {achievement.Title}`, "Trophy")
		end
	end
	-- Immer synchronisieren: die Statistik fuer das Trophaeen-Fenster aendert sich auch ohne neuen Erfolg
	self:Sync(player)
end

function ProgressService:EquipTitle(player: Player, title: string): (boolean, string?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return false, nil
	end
	if title == "" then
		data.Title = ""
	else
		local allowed = false
		for _, achievement in Config.Achievements do
			if achievement.Title == title and data.Achievements[achievement.Id] then
				allowed = true
				break
			end
		end
		if not allowed then
			return false, "Unlock this title with a trophy first!"
		end
		data.Title = title
	end
	self:Sync(player)
	self.Services.CommunityService:RefreshNameplate(player)
	return true, if title == "" then "Title removed" else `Title equipped: {title}`
end

---------------------------------------------------------------- Tutorial

-- Meldet eine Aktion an das Tutorial ("Spawn", "Drive", "Job", "Spin")
function ProgressService:Event(player: Player, id: string, amount: number?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local step = Config.Tutorial[data.Tutorial + 1]
	if not step or step.Id ~= id then
		return
	end
	if id == "Drive" then
		tutorialDrive[player] = (tutorialDrive[player] or 0) + (amount or 0)
		if tutorialDrive[player] < 400 then
			return
		end
	end
	data.Tutorial += 1
	self.Services.DataService:AddCash(player, step.Reward)
	notify(player, `Tutorial step done! +{Format.Cash(step.Reward)}`, C.Green)
	if data.Tutorial >= #Config.Tutorial then
		celebrate(player, "TUTORIAL COMPLETE!", "You're ready for Turbo City. Have fun!", "Trophy")
		self:AddXP(player, 100)
	end
	self:Sync(player)
end

---------------------------------------------------------------- Gluecksrad

-- Gibt (Index des Gewinns, Meldung) zurueck
function ProgressService:Spin(player: Player): (number?, string?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return nil, nil
	end
	if data.SpinDay == today() then
		return nil, "Come back tomorrow for another free spin!"
	end
	data.SpinDay = today()
	local total = 0
	for _, prize in Config.SpinPrizes do
		total += prize.Weight
	end
	local roll = spinRng:NextNumber(0, total)
	local index = #Config.SpinPrizes
	for i, prize in Config.SpinPrizes do
		roll -= prize.Weight
		if roll <= 0 then
			index = i
			break
		end
	end
	local prize = Config.SpinPrizes[index]
	local text
	if prize.Xp then
		self:AddXP(player, prize.Xp)
		text = `Lucky Wheel: +{prize.Xp} XP!`
	else
		local amount = prize.Cash * self.Services.HouseService:GetTier(player)
		self.Services.DataService:AddCash(player, amount)
		text = `Lucky Wheel: +{Format.Cash(amount)}!`
	end
	self:Sync(player)
	-- Tutorial erst nach der Animation melden
	task.delay(4, function()
		if player.Parent then
			self:Event(player, "Spin")
		end
	end)
	return index, text
end

---------------------------------------------------------------- Einstellungen

function ProgressService:SetSetting(player: Player, key: string, value: boolean): (boolean, string?)
	local data = self.Services.DataService:Get(player)
	if not data or Config.DefaultSettings[key] == nil then
		return false, nil
	end
	data.Settings[key] = value
	self:Sync(player)
	return true, nil
end

---------------------------------------------------------------- Turbo-Token

local function collectToken(player: Player, data, token)
	local key = tostring(token.Id)
	data.Tokens[key] = true
	local services = ProgressService.Services
	services.DataService:AddCash(player, Config.TokenReward)
	local found = count(data.Tokens)
	local total = #services.WorldService.Tokens
	notify(player, `Turbo Token found! {found}/{total}  +{Format.Cash(Config.TokenReward)}`, C.Lemon)
	if found >= total then
		celebrate(player, "ALL TOKENS FOUND!", "You found every hidden Turbo Token!", "Trophy")
	end
	ProgressService:AddXP(player, Config.Xp.Token)
	ProgressService:Sync(player)
	ProgressService:Check(player)
end

---------------------------------------------------------------- Ablauf

function ProgressService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if data then
		-- Stufe absichern (alte oder kaputte Spielstaende)
		data.Level = math.clamp(math.floor(tonumber(data.Level) or 1), 1, Config.MaxLevel)
	end
	self:Sync(player)
	self.Services.DataService:UpdateAttributes(player)
	task.delay(8, function()
		if player.Parent then
			self:Check(player)
		end
	end)
end

function ProgressService:OnPlayerRemoving(player: Player)
	tutorialDrive[player] = nil
end

function ProgressService:Start()
	local net = self.Services.Net
	net.Handle("Spin", function(player)
		return self:Spin(player)
	end)
	net.Handle("EquipTitle", function(player, title)
		if typeof(title) ~= "string" or #title > 40 then
			return false, "Invalid"
		end
		return self:EquipTitle(player, title)
	end)
	net.Handle("SetSetting", function(player, key, value)
		if typeof(key) ~= "string" or typeof(value) ~= "boolean" then
			return false, "Invalid"
		end
		return self:SetSetting(player, key, value)
	end)

	-- Token einsammeln (Server prueft die Entfernung)
	task.spawn(function()
		while true do
			task.wait(0.4)
			local tokens = self.Services.WorldService.Tokens
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local data = root and self.Services.DataService:Get(player)
				if root and data then
					for _, token in tokens do
						if not data.Tokens[tostring(token.Id)] and (token.Position - root.Position).Magnitude < TOKEN_RADIUS then
							collectToken(player, data, token)
						end
					end
				end
			end
		end
	end)

	-- Tageswechsel: Gluecksrad wieder freigeben
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = self.Services.DataService:Get(player)
				if data and player:GetAttribute("SpinReady") ~= (data.SpinDay ~= today()) then
					self:Sync(player)
				end
			end
		end
	end)
end

return ProgressService
