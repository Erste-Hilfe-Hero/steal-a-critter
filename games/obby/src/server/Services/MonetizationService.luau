-- Dauerhafte Vorteile und Developer Products (ProcessReceipt).
-- Produkt-IDs werden beim Start ueber den Namen gefunden und dem Client als Attribute
-- an ReplicatedStorage gegeben (ProductId_<Key>, Price_<Key>).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MonetizationService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local RED = Color3.fromRGB(255, 80, 80)

local passKeyByProductId = {}
local productKeyById = {}

function MonetizationService:Init(services)
	self.Services = services
end

local function register()
	table.clear(passKeyByProductId)
	table.clear(productKeyById)
	for key, pass in Config.GamePasses do
		if pass.ProductId ~= 0 then
			passKeyByProductId[pass.ProductId] = key
			ReplicatedStorage:SetAttribute("ProductId_" .. key, pass.ProductId)
		end
	end
	for key, product in Config.DevProducts do
		if product.Id ~= 0 then
			productKeyById[product.Id] = key
			ReplicatedStorage:SetAttribute("ProductId_" .. key, product.Id)
		end
	end
end

-- Fehlende IDs ueber den Produktnamen nachschlagen (vom Workflow per API angelegt)
local function resolveProductIds()
	local ok, pages = pcall(MarketplaceService.GetDeveloperProductsAsync, MarketplaceService)
	if not ok then
		warn("[Monetization] Produkte konnten nicht geladen werden:", pages)
		return
	end
	local byName = {}
	while true do
		for _, item in pages:GetCurrentPage() do
			byName[item.Name] = item
		end
		if pages.IsFinished then
			break
		end
		local advanced = pcall(pages.AdvanceToNextPageAsync, pages)
		if not advanced then
			break
		end
	end
	local function apply(key: string, entry, idField: string)
		local item = byName[entry.ProductName]
		if item then
			if entry[idField] == 0 then
				entry[idField] = item.ProductId
			end
			if item.PriceInRobux then
				ReplicatedStorage:SetAttribute("Price_" .. key, item.PriceInRobux)
			end
		end
	end
	for key, pass in Config.GamePasses do
		apply(key, pass, "ProductId")
	end
	for key, product in Config.DevProducts do
		apply(key, product, "Id")
	end
	register()
end

---------------------------------------------------------------- Vorteile

function MonetizationService:HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	MonetizationService.Services.CosmeticService:Refresh(player)
	MonetizationService.Services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked forever!`, GOLD)
end

function MonetizationService:LoadPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	for key in (data and data.Passes or {}) do
		player:SetAttribute("Pass_" .. key, true)
	end
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	if product.Kind == "Skip" then
		return services.StageService:Skip(player, product.Stages)
	elseif product.Kind == "KillAll" then
		for _, other in Players:GetPlayers() do
			if other ~= player then
				services.StageService:Kill(other)
			end
		end
		if services.RunnerService then
			services.RunnerService:KillAll()
		end
		services.Net.SendAnnounce(`💀 {player.DisplayName} used KILL EVERYONE! 💀`, RED)
		return true
	elseif product.Kind == "Coins" then
		local amount = services.RewardService:AddCoins(player, product.Amount, false, true)
		services.Net.SendNotify(player, `Thanks! +{amount} coins 🪙`, GOLD)
		return amount > 0
	end
	warn("[Monetization] Unbekannter Produkttyp", product.Kind)
	return false
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
	local productKey = productKeyById[info.ProductId]
	if passKey then
		data.Passes[passKey] = true
		grantPass(player, passKey)
	elseif productKey then
		local ok, granted = pcall(grantProduct, player, productKey)
		if not ok or not granted then
			warn("[Monetization] Vergabe fehlgeschlagen", productKey, granted)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	else
		warn("[Monetization] Unbekannte Produkt-ID", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
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
	local services = self.Services
	register()
	MarketplaceService.ProcessReceipt = processReceipt
	task.spawn(resolveProductIds)

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	services.Net.FakePurchase.OnServerEvent:Connect(function(player, kind, key)
		if not (RunService:IsStudio() and Config.StudioFakePurchases) or typeof(key) ~= "string" then
			return
		end
		if kind == "Pass" and Config.GamePasses[key] and Config.GamePasses[key].ProductId == 0 then
			local data = services.DataService:Get(player)
			if data then
				data.Passes[key] = true
			end
			grantPass(player, key)
		elseif kind == "Product" and Config.DevProducts[key] and Config.DevProducts[key].Id == 0 then
			grantProduct(player, key)
		end
	end)
end

return MonetizationService
