-- Laden/Speichern der Spielerdaten mit Retries, Autosave und BindToClose.
-- Fuer ein grosses Live-Spiel spaeter auf ProfileStore (Session-Locking) umsteigen.
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
		Coins = Config.StartCoins,
		Rebirths = 0,
		Seeds = table.clone(Config.StartSeeds), -- [SeedId] = Anzahl
		Plants = {}, -- ["Feld"] = { Id, Start (os.time), Need (Sekunden bei Tempo 1) }
		Fruits = {}, -- { { Id, Value, Mutation } }
		Tiles = Config.StartTiles,
		Upgrades = { Sprinkler = 0, Fertilizer = 0, Backpack = 0 },
		Passes = {}, -- [PassKey] = true (dauerhaft gekaufte Vorteile)
		Receipts = {}, -- [PurchaseId] = true
		ReceiptOrder = {},
		TotalEarned = 0,
		PlayTime = 0, -- aktive Sekunden
		ActiveDays = 0,
		LastActiveDay = 0,
		RankRevoked = false, -- vom Owner entzogen: maximal Regular
		RobuxSpent = 0,
		DailyDay = 0, -- letzter Tag mit Tagesbelohnung
		DailyStreak = 0,
		LastTick = 0, -- os.time() des letzten Wachstums (fuer Offline-Wachstum)
		-- Update 2
		Stats = {}, -- [Stat] = Zaehler (Harvest, Plant, Sell, Mutation, Golden, ...)
		Level = 1,
		Xp = 0,
		Quests = { Day = 0, List = {} }, -- Tagesaufgaben
		Achievements = {}, -- [Id] = true
		Title = "", -- ausgeruestete Erfolgs-Id
		Index = {}, -- [SeedId] = true (entdeckte Pflanzen)
		MutationIndex = {}, -- [Mutation] = true
		Codes = {}, -- [Code] = true
		Settings = { Sfx = true, Announce = true, Pets = true },
		LastSpin = 0, -- os.time() der letzten Gluecksrad-Drehung
		BoostUntil = 0, -- os.time(): bis dahin 2x Verkaufswert
		Pets = {}, -- [PetId] = true
		Pet = "", -- ausgeruesteter Begleiter
		Skins = { classic = true },
		Skin = "classic",
		Tutorial = 0, -- Schritt der Einfuehrung (99 = fertig)
	}
end

local function reconcile(data)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	return data
end

-- In Studio ohne API-Zugriff nicht 12 Sekunden lang wiederholen
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
		profile = { Data = reconcile(stored or defaultData()), CanSave = true }
	else
		-- Nicht speichern, sonst wuerden echte Daten mit Startwerten ueberschrieben
		profile = { Data = defaultData(), CanSave = false }
		self.Services.Net.SendNotify(player, "Could not load your data. Progress this session will NOT be saved.", Color3.fromRGB(255, 80, 80))
	end
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = math.floor(profile.Data.Coins)
	coins.Parent = leaderstats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = profile.Data.Rebirths
	rebirths.Parent = leaderstats
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = profile.Data.Level
	level.Parent = leaderstats
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
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("RebirthCost", Config.RebirthCost(data.Rebirths))
	player:SetAttribute("Tiles", data.Tiles)
	player:SetAttribute("TileCost", Config.TileCost(data.Tiles))
	for key in Config.Upgrades do
		local level = data.Upgrades[key] or 0
		player:SetAttribute("Upgrade_" .. key, level)
		player:SetAttribute("UpgradeCost_" .. key, Config.UpgradeCost(key, level))
	end
	for _, seed in Config.Seeds do
		local count = data.Seeds[seed.Id] or 0
		player:SetAttribute("Seed_" .. seed.Id, if count > 0 then count else nil)
	end
	local fruitValue = 0
	for _, fruit in data.Fruits do
		fruitValue += fruit.Value
	end
	player:SetAttribute("FruitCount", #data.Fruits)
	player:SetAttribute("FruitValue", fruitValue)
	local plantCount = 0
	for _ in data.Plants do
		plantCount += 1
	end
	player:SetAttribute("PlantCount", plantCount)
	local garden = self.Services and self.Services.GardenService
	if garden then
		player:SetAttribute("BackpackSize", garden:BackpackSize(player))
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Coins.Value = math.floor(data.Coins);
		(leaderstats :: any).Rebirths.Value = data.Rebirths;
		(leaderstats :: any).Level.Value = data.Level or 1
	end
end

function DataService:AddCoins(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.Coins = math.max(0, data.Coins + amount)
	if amount > 0 then
		data.TotalEarned += amount
	end
	self:UpdateAttributes(player)
end

-- false, wenn das Laden fehlgeschlagen ist (dann wird in dieser Sitzung nichts gespeichert)
function DataService:CanSave(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and (profile.CanSave or RunService:IsStudio())
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
