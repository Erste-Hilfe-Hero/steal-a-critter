-- Laden/Speichern der Spielerdaten mit Retries, Autosave und BindToClose.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = { Services = nil :: any }

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles = {} -- [Player] = { Data = table, CanSave = boolean }
local MAX_RECEIPTS = 100

local function defaultData()
	return {
		Level = 1,
		XP = 0,
		Prestige = 0,
		Coins = 0,
		-- Statistiken (auch fuer Erfolge)
		Wins = 0,
		Rounds = 0,
		KOs = 0,
		Stops = 0, -- Murderer als Sheriff/Hero gestoppt
		HeroStops = 0,
		Survived = 0,
		CoinsCollected = 0,
		MurdererRounds = 0,
		SheriffRounds = 0,
		Forged = 0,
		Hides = 0,
		-- Inventar: [Art][Id] = Anzahl
		Inventory = { Knife = { Default = 1 }, Gun = { Default = 1 }, Pet = {}, Effect = { Poof = 1 } },
		Equipped = { Knife = "Default", Gun = "Default", Pet = "", Pet2 = "", Effect = "Poof", Title = "" },
		Titles = {},
		Achievements = {},
		Passes = {}, -- [PassKey] = true (dauerhaft gekaufte Vorteile)
		Tickets = { Murderer = 0, Sheriff = 0 },
		BP = { Season = 1, XP = 0, Premium = false, Free = {}, Paid = {} },
		Quests = { Day = 0, List = {} },
		DailyStreak = 0,
		LastDaily = 0,
		LastSpin = 0,
		LastObby = 0,
		Codes = {},
		BoostUntil = 0,
		Tutorial = false,
		StarterOffered = false,
		Receipts = {},
		ReceiptOrder = {},
		RobuxSpent = 0,
	}
end

local function reconcile(data)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			for subKey, subValue in value do
				if data[key][subKey] == nil then
					data[key][subKey] = subValue
				end
			end
		end
	end
	return data
end

-- In Studio ohne API-Zugriff nicht lange wiederholen
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
		profile = { Data = reconcile(stored or defaultData()), CanSave = true, IsNew = stored == nil }
	else
		-- Nicht speichern, sonst wuerden echte Daten mit Startwerten ueberschrieben
		profile = { Data = defaultData(), CanSave = false, IsNew = false }
		self.Services.Net.SendNotify(player, "Could not load your data. Progress this session will NOT be saved.", Config.Colors.Red)
	end
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Level", "Wins" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player

	return profile.Data
end

function DataService:Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:IsNew(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.IsNew
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
