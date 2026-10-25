-- Laden/Speichern der Spielerdaten mit Retries, Autosave und BindToClose.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Progression = require(ReplicatedStorage.Shared.Progression)

local DataService = { Services = nil :: any }

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles = {} -- [Player] = { Data = table, CanSave = boolean }
local MAX_RECEIPTS = 100

local function defaultData()
	return {
		Coins = 250,
		TotalCoins = 0,
		Wins = 0,
		Races = 0,
		Podiums = 0,
		Karts = { Ember = true },
		Kart = "Ember",
		Flames = { Orange = true },
		Flame = "Orange",
		SuperItems = 0,
		Passes = {}, -- [PassKey] = true
		StarterPack = false,
		Receipts = {},
		ReceiptOrder = {},
		RobuxSpent = 0,
		DailyDay = 0,
		DailyStreak = 0,
		PlayTime = 0,
		-- Fortschritt (Update 2)
		XP = 0,
		Stats = { Hits = 0, ItemsUsed = 0, Boxes = 0, TrackCoins = 0 },
		Quests = { Day = 0, List = {} }, -- List = { { Id, Progress, Claimed } }
		Achievements = {}, -- [Id] = true
		Title = "",
		Best = {}, -- [TrackId] = beste Rennzeit in Sekunden
		Codes = {}, -- [CODE] = true
		Settings = {}, -- [Key] = boolean
		Paints = { Factory = true },
		Paint = "Factory",
		WinStreak = 0,
		BestStreak = 0,
		TutorialDone = false,
	}
end

-- Fehlende Felder ergaenzen, auch in verschachtelten Tabellen (z. B. neue Statistik-Zaehler)
local function reconcile(data, defaults)
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
	return data
end

local MAX_ATTEMPTS = if RunService:IsStudio() then 1 else 4

local function withRetries(fn)
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(`[DataService] Versuch {attempt} fehlgeschlagen: {result}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(attempt * 2)
		end
	end
	return false, nil
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

function DataService:Init(services)
	self.Services = services
end

function DataService:Load(player: Player)
	local ok, stored = withRetries(function()
		return store:GetAsync(keyFor(player))
	end)
	if not player.Parent then
		return nil
	end
	local profile
	if ok then
		profile = { Data = reconcile(if type(stored) == "table" then stored else defaultData(), defaultData()), CanSave = true }
	else
		profile = { Data = defaultData(), CanSave = false }
		self.Services.Net.SendNotify(player, "Could not load your data. Progress this session will NOT be saved.", Color3.fromRGB(255, 80, 80))
	end
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = leaderstats
	leaderstats.Parent = player

	self:UpdateAttributes(player)
	return profile.Data
end

function DataService:Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:UpdateAttributes(player: Player)
	local data = self:Get(player)
	if not data then
		return
	end
	player:SetAttribute("Coins", data.Coins)
	player:SetAttribute("Wins", data.Wins)
	player:SetAttribute("Races", data.Races)
	player:SetAttribute("SuperItems", data.SuperItems)
	player:SetAttribute("Kart", data.Kart)
	player:SetAttribute("Flame", data.Flame)
	player:SetAttribute("StarterPack", data.StarterPack)
	player:SetAttribute("Paint", data.Paint)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("Level", (Progression.LevelFromXp(data.XP)))
	player:SetAttribute("Title", data.Title)
	player:SetAttribute("WinStreak", data.WinStreak)
	player:SetAttribute("TutorialDone", data.TutorialDone)
	for _, paint in Config.Paints do
		player:SetAttribute("Paint_" .. paint.Id, data.Paints[paint.Id] == true or nil)
	end
	for _, setting in Progression.Settings do
		local value = data.Settings[setting.Key]
		player:SetAttribute("Set_" .. setting.Key, if value == nil then setting.Default else value)
	end
	for _, kart in Config.Karts do
		local owned = data.Karts[kart.Id] == true or (kart.Pass ~= nil and data.Passes[kart.Pass] == true)
		player:SetAttribute("Kart_" .. kart.Id, owned or nil)
	end
	for _, flame in Config.Flames do
		local owned = data.Flames[flame.Id] == true or (flame.Pass ~= nil and data.Passes[flame.Pass] == true)
		player:SetAttribute("Flame_" .. flame.Id, owned or nil)
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Wins.Value = data.Wins;
		(leaderstats :: any).Coins.Value = math.floor(data.Coins)
	end
end

function DataService:AddCoins(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.Coins = math.max(0, math.floor(data.Coins + amount))
	if amount > 0 then
		data.TotalCoins += amount
	end
	self:UpdateAttributes(player)
end

function DataService:HasReceipt(player: Player, purchaseId: string): boolean
	local data = self:Get(player)
	return data ~= nil and data.Receipts[purchaseId] == true
end

function DataService:RecordReceipt(player: Player, purchaseId: string)
	local data = self:Get(player)
	if not data then
		return
	end
	data.Receipts[purchaseId] = true
	table.insert(data.ReceiptOrder, purchaseId)
	while #data.ReceiptOrder > MAX_RECEIPTS do
		local old = table.remove(data.ReceiptOrder, 1)
		data.Receipts[old] = nil
	end
end

function DataService:Save(player: Player): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if not profile.CanSave then
		return RunService:IsStudio()
	end
	local ok = withRetries(function()
		store:UpdateAsync(keyFor(player), function()
			return profile.Data
		end)
	end)
	return ok
end

function DataService:Release(player: Player)
	self:Save(player)
	profiles[player] = nil
end

function DataService:Start()
	task.spawn(function()
		while true do
			task.wait(90)
			for player in profiles do
				task.spawn(self.Save, self, player)
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				self:Save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
