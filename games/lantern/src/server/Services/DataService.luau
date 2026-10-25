-- Laden/Speichern der Spielerdaten (Held, Inventar, Fortschritt) mit Retries, Autosave und BindToClose.
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
		Level = 1,
		XP = 0,
		Gold = Config.StartGold,
		Shards = 0,
		Class = "Knight",
		ClassChosen = false,
		Inventory = {}, -- { Item } (siehe Shared/Items)
		Equipped = {}, -- [Slot] = Item-Id
		Cleared = {}, -- [DungeonId] = hoechste geschaffte Schwierigkeit (1-3)
		Passes = {}, -- [PassKey] = true (dauerhaft gekaufte Vorteile)
		Receipts = {}, -- [PurchaseId] = true
		ReceiptOrder = {},
		TotalEarned = 0,
		Kills = 0,
		BossKills = 0,
		Runs = 0,
		PlayTime = 0, -- aktive Sekunden
		ActiveDays = 0,
		LastActiveDay = 0,
		RankRevoked = false, -- vom Owner entzogen: maximal Regular
		RobuxSpent = 0,
		DailyDay = 0,
		DailyStreak = 0,
		XPBoostUntil = 0, -- os.time()
		StarterBought = false,
		StarterOffered = false,
		AutoSalvage = 0, -- Seltenheiten bis einschliesslich dieser Stufe automatisch zerlegen
		Blessing = 0, -- offene Boss Blessings
		-- Update: Quests, Erfolge, Kosmetik, Einstellungen, Statistik
		QuestDay = 0,
		Quests = {}, -- { { Key, Progress, Claimed } }
		QuestBonus = false, -- Bonus fuer alle 3 Quests abgeholt
		Achievements = {}, -- [Key] = true
		Title = "",
		Auras = {}, -- [Key] = true
		Aura = "",
		Codes = {}, -- [CODE] = true
		Settings = {}, -- [Key] = boolean (fehlt = Standard)
		PotionLevel = 0,
		Tutorial = 1, -- naechster Schritt (groesser als die Liste = fertig)
		Records = {}, -- ["dungeonId_schwierigkeit"] = Sekunden
		EliteKills = 0,
		ImpKills = 0,
		LegendaryFound = 0,
		MythicFound = 0,
		NightmareClears = 0,
		BestPlus = 0,
		BestCombo = 0,
		ChestsOpened = 0,
		ShrinesUsed = 0,
		Salvaged = 0,
	}
end

local function reconcile(data)
	for key, value in defaultData() do
		if data[key] == nil then
			data[key] = value
		end
	end
	-- Bestehende Helden (vor dem Update) brauchen keine Einsteiger-Anleitung mehr
	if data.Tutorial == 1 and (data.Runs or 0) > 0 then
		data.Tutorial = #Config.Tutorial + 1
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
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Parent = leaderstats
	local power = Instance.new("IntValue")
	power.Name = "Power"
	power.Parent = leaderstats
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
	player:SetAttribute("Gold", data.Gold)
	player:SetAttribute("Shards", data.Shards)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNeed", Config.XPToLevel(data.Level))
	player:SetAttribute("Class", data.Class)
	player:SetAttribute("ClassChosen", data.ClassChosen)
	player:SetAttribute("XPBoostUntil", data.XPBoostUntil)
	player:SetAttribute("AutoSalvage", data.AutoSalvage)
	player:SetAttribute("Blessing", data.Blessing)
	player:SetAttribute("PotionLevel", data.PotionLevel)
	player:SetAttribute("TutorialStep", data.Tutorial)
	player:SetAttribute("Title", data.Title)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Level.Value = data.Level;
		(leaderstats :: any).Power.Value = player:GetAttribute("GearScore") or 0
	end
end

function DataService:AddGold(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	amount = math.floor(amount)
	data.Gold = math.max(0, data.Gold + amount)
	if amount > 0 then
		data.TotalEarned += amount
	end
	self:UpdateAttributes(player)
end

function DataService:AddShards(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.Shards = math.max(0, data.Shards + math.floor(amount))
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
