-- Laden/Speichern der Spielerdaten (Kristalle, Helden, Skins, Passes, Statistik) mit Retries und Autosave.
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
		Crystals = 0,
		Heroes = {}, -- [HeroId] = true (gekauft; freie Helden sind immer da)
		Skins = { Default = true },
		Skin = "Default",
		LastHero = "Brakka",
		Passes = {}, -- [ProductKey] = true
		AllHeroes = false,
		StarterPack = false,
		AutoBuy = true,
		Wins = 0,
		Matches = 0,
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		LastWinDay = 0,
		DailyDay = 0,
		DailyStreak = 0,
		Receipts = {},
		ReceiptOrder = {},
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

function DataService.Today(): number
	return os.time() // 86400
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
		profile = { Data = defaultData(), CanSave = false }
		self.Services.Net.SendNotify(player, "Could not load your data. Progress this session will NOT be saved.", Color3.fromRGB(255, 80, 80))
	end
	profiles[player] = profile

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
	local crystals = Instance.new("IntValue")
	crystals.Name = "Crystals"
	crystals.Parent = leaderstats
	leaderstats.Parent = player

	self:UpdateAttributes(player)
	return profile.Data
end

function DataService:Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function DataService:OwnsHero(player: Player, heroId: string): boolean
	local data = self:Get(player)
	local hero = Config.HeroesById[heroId]
	if not data or not hero then
		return false
	end
	return hero.Free == true or data.AllHeroes or data.Heroes[heroId] == true
end

function DataService:OwnsSkin(player: Player, skinId: string): boolean
	local data = self:Get(player)
	local skin = Config.SkinsById[skinId]
	return data ~= nil and skin ~= nil and (skin.Free == true or data.Skins[skinId] == true)
end

-- Besitz als Attribute, damit die UI ohne eigene Abfragen zeichnen kann
function DataService:UpdateAttributes(player: Player)
	local data = self:Get(player)
	if not data then
		return
	end
	player:SetAttribute("Crystals", data.Crystals)
	player:SetAttribute("Wins", data.Wins)
	player:SetAttribute("Matches", data.Matches)
	player:SetAttribute("Skin", data.Skin)
	player:SetAttribute("AutoBuy", data.AutoBuy)
	player:SetAttribute("StarterPackOwned", data.StarterPack)
	local owned = {}
	for _, hero in Config.Heroes do
		if self:OwnsHero(player, hero.Id) then
			table.insert(owned, hero.Id)
		end
	end
	player:SetAttribute("OwnedHeroes", table.concat(owned, ","))
	local skins = {}
	for _, skin in Config.Skins do
		if self:OwnsSkin(player, skin.Id) then
			table.insert(skins, skin.Id)
		end
	end
	player:SetAttribute("OwnedSkins", table.concat(skins, ","))
	player:SetAttribute("DailyReady", data.DailyDay < DataService.Today())
	player:SetAttribute("DailyStreak", data.DailyStreak)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Wins.Value = data.Wins;
		(leaderstats :: any).Crystals.Value = data.Crystals
	end
end

function DataService:AddCrystals(player: Player, amount: number)
	local data = self:Get(player)
	if not data then
		return
	end
	data.Crystals = math.max(0, math.floor(data.Crystals + amount))
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
