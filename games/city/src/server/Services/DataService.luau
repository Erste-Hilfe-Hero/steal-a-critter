-- Laden/Speichern der Spielerdaten mit Retries, Autosave und BindToClose.
-- Ausserdem: Geld gutschreiben mit allen Multiplikatoren (VIP, 2x Cash, Premium, Freunde, Cash Party).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = { Services = nil :: any }

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles = {} -- [Player] = { Data = table, CanSave = boolean }
local MAX_RECEIPTS = 100

local function defaultData()
	return {
		Cash = Config.StartCash,
		TotalEarned = 0,
		Cars = { bubble = true }, -- [CarId] = true
		Car = "bubble", -- zuletzt gewaehltes Auto
		Paint = "stock",
		House = 1, -- Stufe in Config.Houses
		Passes = {}, -- [PassKey] = true
		Receipts = {},
		ReceiptOrder = {},
		PlayTime = 0,
		ActiveDays = 0,
		LastActiveDay = 0,
		RankRevoked = false,
		RobuxSpent = 0,
		DailyDay = 0,
		DailyStreak = 0,
		LastOnline = 0,
		Codes = {}, -- [Code] = true
		Missions = { Day = 0, List = {} }, -- List = { { Id, Progress, Done } }
		Stats = { Deliveries = 0, Arrests = 0, Robberies = 0, Races = 0, BestRace = 0, Jailed = 0, Trucks = 0, TopSpeed = 0, Chores = 0, Sprays = 0 },
		StarterPack = false,
		-- Update 2: Stufen, Erfolge, Titel, Gluecksrad, Tuning, Token, Einstellungen, Tutorial
		XP = 0,
		Level = 1,
		Achievements = {}, -- [AchievementId] = true
		Title = "",
		SpinDay = 0,
		Tune = {}, -- [CarId] = Stufe
		Tokens = {}, -- [TokenId als Text] = true
		Settings = table.clone(Config.DefaultSettings),
		Tutorial = 0, -- erledigte Schritte; > #Config.Tutorial = fertig
	}
end

local function reconcile(data)
	local defaults = defaultData()
	for key, value in defaults do
		if data[key] == nil then
			data[key] = value
		end
	end
	-- verschachtelte Tabellen ebenfalls ergaenzen
	for _, nested in { "Stats", "Settings" } do
		if typeof(data[nested]) ~= "table" then
			data[nested] = defaults[nested]
		end
		for key, value in defaults[nested] do
			if data[nested][key] == nil then
				data[nested][key] = value
			end
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
		-- Wer schon vor dem Tutorial gespielt hat, bekommt es nicht mehr
		local veteran = stored ~= nil and stored.Tutorial == nil and (stored.TotalEarned or 0) > 0
		profile = { Data = reconcile(stored or defaultData()), CanSave = true }
		if veteran then
			profile.Data.Tutorial = #Config.Tutorial + 1
		end
	else
		profile = { Data = defaultData(), CanSave = false }
		self.Services.Net.SendNotify(player, "Could not load your data. Progress this session will NOT be saved.", Config.Colors.Robber)
	end
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Parent = leaderstats
	local bounty = Instance.new("IntValue")
	bounty.Name = "Wanted"
	bounty.Parent = leaderstats
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
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("House", data.House)
	local nextHouse = Config.Houses[data.House + 1]
	player:SetAttribute("NextHouseCost", if nextHouse and nextHouse.Price then nextHouse.Price else nil)
	player:SetAttribute("Car", data.Car)
	player:SetAttribute("Paint", data.Paint)
	local owned = {}
	for id in data.Cars do
		table.insert(owned, id)
	end
	player:SetAttribute("OwnedCars", table.concat(owned, ","))
	player:SetAttribute("BestRace", data.Stats.BestRace)
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("XPNext", Config.XpForLevel(data.Level))
	local tune = {}
	for id, level in data.Tune do
		table.insert(tune, `{id}:{level}`)
	end
	table.sort(tune)
	player:SetAttribute("Tune", table.concat(tune, ","))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Cash.Value = math.floor(math.min(data.Cash, 2 ^ 53))
	end
end

-- Gesamt-Multiplikator fuer verdientes Geld
function DataService:GetMultiplier(player: Player): number
	local multiplier = 1
	if player:GetAttribute("Pass_VIP") then
		multiplier *= Config.VipMultiplier
	end
	if player:GetAttribute("Pass_DoubleCash") then
		multiplier *= Config.DoubleCashMultiplier
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumMultiplier
	end
	multiplier *= 1 + Config.FriendBonusPer * math.min(player:GetAttribute("FriendsHere") or 0, Config.MaxFriendBonus)
	if (workspace:GetAttribute("PartyUntil") or 0) > os.time() then
		multiplier *= Config.PartyMultiplier
	end
	return multiplier
end

-- Verdientes Geld (mit Multiplikator). Gibt den gutgeschriebenen Betrag zurueck.
function DataService:Earn(player: Player, base: number): number
	local amount = math.floor(base * self:GetMultiplier(player))
	self:AddCash(player, amount)
	local rewards = self.Services.RewardService
	if rewards then
		rewards:Progress(player, "Earn", amount)
	end
	return amount
end

-- Direkte Gutschrift/Abbuchung ohne Multiplikator (Kaeufe, Robux-Pakete)
function DataService:AddCash(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.Cash = math.max(0, data.Cash + amount)
	if amount > 0 then
		data.TotalEarned += amount
	end
	self:UpdateAttributes(player)
end

function DataService:Spend(player: Player, amount: number): boolean
	local data = self:Get(player)
	if not data or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	self:UpdateAttributes(player)
	return true
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
	profile.Data.LastOnline = os.time()
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

	-- Freunde im selben Server zaehlen (Freunde-Bonus)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local count = 0
				for _, other in Players:GetPlayers() do
					if other ~= player then
						local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
						if ok and isFriend then
							count += 1
						end
					end
				end
				player:SetAttribute("FriendsHere", count)
			end
			task.wait(30)
		end
	end)
end

return DataService
