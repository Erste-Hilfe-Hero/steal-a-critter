-- Dauerhafte Vorteile ("Passes"), Developer Products (ProcessReceipt), Video-Werbung und Angebote.
-- Produkt-IDs kommen aus ProductIds.json; fehlende werden beim Start ueber den Namen gesucht.
-- Der Client bekommt sie als Attribute an ReplicatedStorage (ProductId_<Key>, Price_<Key>).
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MonetizationService = { Services = nil :: any }

local C = Config.Colors

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

-- Fehlende IDs ueber den Produktnamen nachschlagen und echte Preise an den Client geben
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
		if not pcall(pages.AdvanceToNextPageAsync, pages) then
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

local function grantPass(player: Player, key: string, silent: boolean?)
	local services = MonetizationService.Services
	player:SetAttribute("Pass_" .. key, true)
	services.ProgressService:UpdateNameplate(player)
	services.ProgressService:Refresh(player)
	if not silent then
		services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked forever!`, C.Moon)
		services.Net.SendAnnounce(`{player.DisplayName} got {Config.GamePasses[key].Name}!`, C.Moon)
	end
end

function MonetizationService:LoadPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	for key in (data and data.Passes or {}) do
		if Config.GamePasses[key] then
			grantPass(player, key, true)
		end
	end
	if data and data.Passes.StarterPack then
		player:SetAttribute("Pass_StarterPack", true)
	end
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local data = services.DataService:Get(player)
	if not data then
		return false
	end
	local kind = product.Kind
	if kind == "Coins" or kind == "AdCoins" then
		local coins = product.Coins + (if kind == "AdCoins" then (data.Level or 1) * 5 else 0)
		services.ProgressService:AddCoins(player, coins, true)
		services.Net.SendNotify(player, `+{coins} coins!`, C.Moon)
		return true
	elseif kind == "Ticket" then
		data.Tickets[product.Role] = (data.Tickets[product.Role] or 0) + 1
		services.Net.SendNotify(player, `{product.Role} Ticket ready! You'll be the {product.Role} in your next round.`, C.Moon)
		services.ProgressService:Refresh(player)
		services.RoundService:SendOdds()
		return true
	elseif kind == "BattlePass" then
		data.BP.Premium = true
		services.ProgressService:GrantBattlePass(player)
		services.ProgressService:Refresh(player)
		services.Net.SendAnnounce(`{player.DisplayName} unlocked the Premium Battle Pass!`, C.Purple)
		return true
	elseif kind == "TierSkip" then
		local BP = Config.BattlePass
		data.BP.XP = math.min(BP.Tiers * BP.XPPerTier, (services.ProgressService:Tier(data) + product.Tiers) * BP.XPPerTier)
		services.ProgressService:GrantBattlePass(player)
		services.ProgressService:Refresh(player)
		services.Net.SendNotify(player, `Skipped {product.Tiers} tier(s)!`, C.Purple)
		return true
	elseif kind == "StarterPack" then
		data.Passes.StarterPack = true
		player:SetAttribute("Pass_StarterPack", true)
		services.ProgressService:AddCoins(player, product.Coins, true)
		services.InventoryService:Grant(player, "Knife", "Starlight", 1)
		services.InventoryService:Grant(player, "Gun", "Starshot", 1)
		services.Net.SendNotify(player, "Starter Pack: 2,500 coins + Starlight knife + Starshot blaster!", C.Moon)
		return true
	elseif kind == "Bundle" then
		for _, entry in product.Items do
			services.InventoryService:Grant(player, entry[1], entry[2], 1)
		end
		services.Net.SendAnnounce(`{player.DisplayName} got the {product.ProductName}!`, C.Purple)
		return true
	elseif kind == "XPBoost" then
		data.BoostUntil = math.max(os.time(), data.BoostUntil) + product.Minutes * 60
		services.ProgressService:Refresh(player)
		services.Net.SendNotify(player, `2x XP active for {product.Minutes} minutes!`, C.Green)
		return true
	elseif kind == "Blackout" then
		services.RoundService.ForceModifier = "Blackout"
		services.Net.SendAnnounce(`{player.DisplayName} bought a BLACKOUT for the next round!`, C.Purple)
		return true
	elseif kind == "MidnightHour" then
		-- Fuer den ganzen Server: doppelte Muenzen und 1,5x XP
		services.RoundService:BoostEvent(Config.MidnightHour.BoughtMinutes)
		services.Net.SendAnnounce(`{player.DisplayName} started a MIDNIGHT HOUR! 2x coins for everyone!`, C.Purple)
		return true
	end
	warn("[Monetization] Unbekannter Produkttyp", kind)
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

---------------------------------------------------------------- Angebote

-- Neue Spieler sehen nach kurzer Spielzeit einmal das Starter Pack (mit "No thanks")
function MonetizationService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or data.StarterOffered or data.Passes.StarterPack then
		return
	end
	task.delay(Config.StarterPackDelay, function()
		if player.Parent and not data.StarterOffered then
			data.StarterOffered = true
			self.Services.Net.Offer:FireClient(player, "StarterPack")
		end
	end)
end

-- Passende Angebote nach einer Runde (hoechstens jede dritte Runde eins)
local roundsSinceOffer = {}
function MonetizationService:AfterRound(player: Player, result)
	roundsSinceOffer[player] = (roundsSinceOffer[player] or 0) + 1
	if roundsSinceOffer[player] < 3 then
		return
	end
	local offer
	if result.Role == "Innocent" and not result.Survived then
		offer = "MurdererTicket"
	elseif result.Coins >= 40 and not self:HasPass(player, "BigBag") then
		offer = "Pass_BigBag"
	elseif not self:HasPass(player, "DoubleXP") then
		offer = "XPBoost"
	end
	if offer then
		roundsSinceOffer[player] = 0
		task.delay(Config.Round.ResultsTime - 2, function()
			if player.Parent then
				self.Services.Net.Offer:FireClient(player, offer)
			end
		end)
	end
end

---------------------------------------------------------------- Start

function MonetizationService:Start()
	local services = self.Services
	register()
	MarketplaceService.ProcessReceipt = processReceipt
	task.spawn(resolveProductIds)

	-- Freiwillige Video-Werbung: die Belohnung kommt ueber ProcessReceipt (Produkt AdCoins)
	local lastAd = {}
	services.Net.WatchAd.OnServerEvent:Connect(function(player)
		local t = os.clock()
		if t - (lastAd[player] or -math.huge) < Config.AdCooldown then
			services.Net.SendNotify(player, "Next free coins in a few minutes!", C.Orange)
			return
		end
		if Config.DevProducts.AdCoins.Id == 0 then
			return
		end
		lastAd[player] = t
		local ok, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(Config.DevProducts.AdCoins.Id)
			return AdService:ShowRewardedVideoAdAsync(player, reward)
		end)
		if not ok or result ~= Enum.ShowAdResult.ShowCompleted then
			lastAd[player] = nil
			if not ok then
				warn("[Ads]", result)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastAd[player] = nil
		roundsSinceOffer[player] = nil
	end)

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
