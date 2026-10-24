-- Dauerhafte Vorteile ("Passes", als Developer Products verkauft), Developer Products (ProcessReceipt) und Premium-Bonus.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MonetizationService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)

local passKeyByProductId = {}
local productKeyById = {}
for key, pass in Config.GamePasses do
	if pass.ProductId ~= 0 then
		passKeyByProductId[pass.ProductId] = key
	end
end
for key, product in Config.DevProducts do
	if product.Id ~= 0 then
		productKeyById[product.Id] = key
	end
end

local function canFake(): boolean
	return RunService:IsStudio() and Config.StudioFakePurchases
end

function MonetizationService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Passes

function MonetizationService:ApplyPassEffects(player: Player)
	player:SetAttribute("BaseWalkSpeed", Config.DefaultWalkSpeed)
	local garden = self.Services.GardenService
	garden:RefreshStats(player)
	garden:RefreshAllTiles(player)
end

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	MonetizationService:ApplyPassEffects(player)
	MonetizationService.Services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked forever!`, GOLD)
end

function MonetizationService:LoadPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	for key in (data and data.Passes or {}) do
		player:SetAttribute("Pass_" .. key, true)
	end
	self:ApplyPassEffects(player)
end

-- Vom Spiel ausgeloest, z. B. beim Tippen auf ein gesperrtes Big-Garden-Feld
function MonetizationService:PromptPass(player: Player, key: string)
	local pass = Config.GamePasses[key]
	if not pass or player:GetAttribute("Pass_" .. key) then
		return
	end
	if pass.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, pass.ProductId)
	elseif canFake() then
		grantPass(player, key)
		local data = self.Services.DataService:Get(player)
		if data then
			data.Passes[key] = true
		end
	else
		self.Services.Net.SendNotify(player, `{pass.Name} is coming soon!`, GOLD)
	end
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local kind = product.Kind

	if kind == "Coins" then
		local rate = services.GardenService:GetEarnRate(player)
		local amount = math.floor(math.max(product.MinCoins, rate * 60 * product.Minutes))
		services.DataService:AddCoins(player, amount)
		services.Net.SendNotify(player, `+{Format.Cash(amount)}! Thanks for your support!`, GOLD)
	elseif kind == "GrowAll" then
		services.GardenService:GrowAll(player)
		services.Net.SendNotify(player, "Your whole garden is ripe! Harvest now!", GOLD)
	elseif kind == "Weather" then
		services.EventService:StartWeather(product.Weather, player)
	elseif kind == "GoldenHour" then
		services.EventService:StartGoldenHour(product.Seconds, player)
	elseif kind == "Seed" then
		local data = services.DataService:Get(player)
		local seed = Config.SeedsById[product.Seed]
		data.Seeds[seed.Id] = (data.Seeds[seed.Id] or 0) + product.Amount
		player:SetAttribute("SelectedSeed", seed.Id)
		services.DataService:UpdateAttributes(player)
		services.Net.SendAnnounce(`{player.DisplayName} got a {seed.Rarity} {seed.Name} seed!`, Config.RaritiesByName[seed.Rarity].Color)
	else
		warn("[Monetization] Unbekannter Produkttyp", kind)
		return false
	end
	return true
end

local function processReceipt(info)
	local services = MonetizationService.Services
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = services.DataService:Get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if services.DataService:HasReceipt(player, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local passKey = passKeyByProductId[info.ProductId]
	if passKey then
		data.Passes[passKey] = true
		grantPass(player, passKey)
	else
		local key = productKeyById[info.ProductId]
		if not key then
			warn("[Monetization] Unbekannte Produkt-ID", info.ProductId)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(grantProduct, player, key)
		if not ok or not granted then
			warn("[Monetization] Vergabe fehlgeschlagen", key, granted)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	services.DataService:RecordReceipt(player, info.PurchaseId)
	data.RobuxSpent += info.CurrencySpent or 0
	if not services.DataService:Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------- Start

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = processReceipt

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	self.Services.Net.FakePurchase.OnServerEvent:Connect(function(player, kind, key)
		if not canFake() or typeof(key) ~= "string" then
			return
		end
		if kind == "Pass" and Config.GamePasses[key] and Config.GamePasses[key].ProductId == 0 then
			self:PromptPass(player, key)
		elseif kind == "Product" and Config.DevProducts[key] and Config.DevProducts[key].Id == 0 then
			grantProduct(player, key)
		end
	end)
end

function MonetizationService:OnPlayerRemoving(_player: Player) end

return MonetizationService
