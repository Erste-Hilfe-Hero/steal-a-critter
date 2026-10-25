-- Laden/Speichern der Spielerdaten mit Retries, Autosave und BindToClose.
-- Fuer ein grosses Live-Spiel spaeter auf ProfileStore (Session-Locking) umsteigen.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)

local DataService = { Services = nil :: any }

local store = DataStoreService:GetDataStore(Config.DataStoreName)
local profiles = {} -- [Player] = { Data = table, CanSave = boolean }
local MAX_RECEIPTS = 100

local function defaultData()
	return {
		Flakes = 0, -- Schneeflocken (Waehrung fuer Kosmetik)
		BestTime = 0, -- beste ganze Map in Sekunden (0 = noch nie geschafft)
		StageBest = {}, -- [tostring(Stage)] = Sekunden
		MaxStage = 1, -- hoechste freigeschaltete Stage
		Cleared = {}, -- [tostring(Stage)] = true (fuer die Erstbelohnung)
		Clears = 0, -- Stage-Abschluesse insgesamt (fuer den Rang)
		MapClears = 0,
		Falls = 0,
		Trails = { frost = true, none = true }, -- [TrailId] = true
		Skis = { classic = true },
		Trail = "frost",
		Ski = "classic",
		Passes = {}, -- [PassKey] = true (dauerhaft gekaufte Vorteile)
		Receipts = {}, -- [PurchaseId] = true
		ReceiptOrder = {},
		PlayTime = 0, -- aktive Sekunden
		RobuxSpent = 0,
		DailyDay = 0, -- letzter Tag mit Tagesbelohnung
		DailyStreak = 0,
		StarterOffered = false,
		-- Update 2
		Achievements = {}, -- [AchievementId] = true
		Title = "", -- angelegter Titel (AchievementId)
		Quest = { Day = 0, Ids = {}, Progress = {}, Claimed = {} }, -- Tagesaufgaben
		QuestsDone = 0,
		Medals = {}, -- [tostring(Stage)] = 1 Bronze, 2 Silber, 3 Gold
		TopSpeed = 0, -- u/s, vom Server gemessen
		PBSplits = {}, -- [Stage] = Zwischenzeit im Bestzeit-Lauf
		Codes = {}, -- [CODE] = true
		SpinDay = 0, -- letzter Tag mit Gluecks-Schneeball
		Buddies = { none = true },
		Buddy = "none",
		BoostSeconds = 0, -- Rest-Sekunden Flake Booster
		Settings = {},
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
	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Parent = leaderstats
	local stage = Instance.new("IntValue")
	stage.Name = "Stage"
	stage.Parent = leaderstats
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
	player:SetAttribute("Flakes", data.Flakes)
	player:SetAttribute("BestTime", data.BestTime)
	player:SetAttribute("MaxStage", data.MaxStage)
	player:SetAttribute("Clears", data.Clears)
	player:SetAttribute("Trail", data.Trail)
	player:SetAttribute("Ski", data.Ski)
	player:SetAttribute("Buddy", data.Buddy)
	player:SetAttribute("TopSpeed", data.TopSpeed)
	player:SetAttribute("MapClears", data.MapClears)
	for stage = 1, #Config.Stages do
		player:SetAttribute("StageBest_" .. stage, data.StageBest[tostring(stage)])
	end
	for _, trail in Config.Trails do
		player:SetAttribute("OwnsTrail_" .. trail.Id, data.Trails[trail.Id] == true or (trail.Pass ~= nil and data.Passes[trail.Pass] == true))
	end
	for _, ski in Config.Skis do
		player:SetAttribute("OwnsSki_" .. ski.Id, data.Skis[ski.Id] == true or (ski.Pass ~= nil and data.Passes[ski.Pass] == true))
	end
	for _, buddy in Progression.Buddies do
		player:SetAttribute("OwnsBuddy_" .. buddy.Id, data.Buddies[buddy.Id] == true or (buddy.Price == 0 and not buddy.Spin))
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local values = leaderstats :: any
		values.Best.Value = if data.BestTime > 0 then Format.Run(data.BestTime) else "-"
		values.Stage.Value = player:GetAttribute("Stage") or 0
	end
end

-- Schneeflocken mit allen Multiplikatoren (VIP, 2x, Premium). Gibt den echten Betrag zurueck.
function DataService:AddFlakes(player: Player, amount: number, boosted: boolean?): number
	local data = self:Get(player)
	if not data then
		return 0
	end
	if boosted ~= false and amount > 0 then
		local multiplier = 1
		if data.Passes.VIP then
			multiplier *= Config.VipMultiplier
		end
		if data.Passes.DoubleFlakes then
			multiplier *= Config.DoubleFlakesMultiplier
		end
		if player.MembershipType == Enum.MembershipType.Premium then
			multiplier *= Config.PremiumMultiplier
		end
		-- Update 2: Flake Booster, Schneesturm-Event und Freundes-Bonus
		if (data.BoostSeconds or 0) > 0 then
			multiplier *= Progression.BoostMultiplier
		end
		if (workspace:GetAttribute("StormUntil") or 0) > os.time() then
			multiplier *= Progression.StormMultiplier
		end
		local friendBonus = player:GetAttribute("FriendBonus")
		if typeof(friendBonus) == "number" then
			multiplier *= 1 + math.clamp(friendBonus, 0, Progression.FriendBonusMax)
		end
		amount = math.floor(amount * multiplier)
	end
	data.Flakes = math.max(0, data.Flakes + amount)
	self:UpdateAttributes(player)
	return amount
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
