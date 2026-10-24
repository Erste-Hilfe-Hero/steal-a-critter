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
	local items = {}
	for key in Config.Items do
		items[key] = Config.StartItems[key] or 0
	end
	return {
		Coins = Config.StartCoins,
		Beasts = {}, -- [uid] = { S = Art, L = Level, X = XP, Sh = prismatisch?, Hp = aktuelle HP }
		Team = {}, -- { uid, ... } Reihenfolge im Kampf
		NextId = 1,
		Items = items, -- [ItemKey] = Anzahl
		Started = false, -- Starter-Bestie gewaehlt?
		Crests = 0, -- besiegte Champions (in Reihenfolge)
		BestWave = 0, -- Gauntlet-Rekord
		Trophies = 0, -- aus Duellen
		Wins = 0,
		Caught = 0,
		Dex = {}, -- [beastId] = true (je gefangen)
		ExtraStorage = 0,
		BoostUntil = 0, -- os.time() bis 2x-Boost endet
		LastDaily = 0, -- Tag des letzten Geschenks
		Streak = 0,
		Codes = {}, -- [Code] = true
		GotStarter = false, -- Starter Pack gekauft
		Passes = {}, -- [PassKey] = true (dauerhaft gekaufte Vorteile)
		Receipts = {}, -- [PurchaseId] = true
		ReceiptOrder = {},
		TotalEarned = 0,
		PlayTime = 0, -- aktive Sekunden
		ActiveDays = 0,
		LastActiveDay = 0,
		RankRevoked = false, -- vom Owner entzogen: maximal Regular
		RobuxSpent = 0,
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
	for _, stat in { "Crests", "Caught", "Trophies" } do
		local value = Instance.new("IntValue")
		value.Name = stat
		value.Value = profile.Data[stat]
		value.Parent = leaderstats
	end
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
	player:SetAttribute("Crests", data.Crests)
	player:SetAttribute("BestWave", data.BestWave)
	player:SetAttribute("Trophies", data.Trophies)
	player:SetAttribute("BoostUntil", data.BoostUntil)
	player:SetAttribute("DailyReady", data.LastDaily ~= os.time() // 86400)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		for _, stat in { "Crests", "Caught", "Trophies" } do
			(leaderstats :: any)[stat].Value = data[stat]
		end
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
