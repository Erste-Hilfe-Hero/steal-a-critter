-- Dauerhafte Vorteile ("Passes", als Developer Products verkauft), Developer Products (ProcessReceipt),
-- passende Angebote im richtigen Moment und freiwillige Video-Werbung.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MonetizationService = { Services = nil :: any }

local C = Config.Colors

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

local lastOffer = {} -- [Player] = os.clock()
local rides = {} -- [Player] = Anzahl Fahrten (fuer das Nitro-Angebot)

local function canFake(): boolean
	return RunService:IsStudio() and Config.StudioFakePurchases
end

function MonetizationService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Passes

local function applyPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	local services = MonetizationService.Services
	if key == "Diamond" then
		services.HouseService:GrantDiamond(player)
	elseif key == "BigBag" then
		player:SetAttribute("BagMax", services.JobService:BagMax(player))
	end
end

local function grantPass(player: Player, key: string)
	local data = MonetizationService.Services.DataService:Get(player)
	if data then
		data.Passes[key] = true
	end
	applyPass(player, key)
	MonetizationService.Services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked forever!`, C.Lemon)
	MonetizationService.Services.Net.SendAnnounce(`{player.DisplayName} unlocked {Config.GamePasses[key].Name}!`, C.Lemon)
end

function MonetizationService:LoadPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	for key in (data and data.Passes or {}) do
		if Config.GamePasses[key] then
			player:SetAttribute("Pass_" .. key, true)
		end
	end
end

function MonetizationService:PromptPass(player: Player, key: string)
	local pass = Config.GamePasses[key]
	if not pass or player:GetAttribute("Pass_" .. key) then
		return
	end
	if pass.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, pass.ProductId)
	elseif canFake() then
		grantPass(player, key)
	else
		self.Services.Net.SendNotify(player, `{pass.Name} is coming soon!`, C.Lemon)
	end
end

---------------------------------------------------------------- Developer Products

local function cashFor(player: Player, base: number): number
	local tier = MonetizationService.Services.HouseService:GetTier(player)
	return math.floor(base * (1 + (tier - 1) * 0.75))
end

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local kind = product.Kind
	local data = services.DataService:Get(player)
	if not data then
		return false
	end
	if kind == "Cash" or kind == "AdCash" then
		local amount = cashFor(player, product.Base)
		services.DataService:AddCash(player, amount)
		services.Net.SendNotify(player, `+{Format.Cash(amount)}! Thanks for your support!`, C.Green)
	elseif kind == "JailBreak" then
		if player:GetAttribute("JailUntil") then
			services.JobService:Release(player, true)
		else
			-- Schon frei (z. B. Strafe waehrend des Kaufs abgelaufen): Ersatz in Cash, mit Meldung
			local amount = cashFor(player, 5_000)
			services.DataService:AddCash(player, amount)
			services.Net.SendNotify(player, `You were already free, so you got {Format.Cash(amount)} instead!`, C.Green)
		end
	elseif kind == "ClearWanted" then
		services.JobService:ClearWanted(player)
		services.Net.SendNotify(player, "Wanted level cleared! The cops lost your trail.", C.Green)
	elseif kind == "Party" then
		local untilTime = math.max(os.time(), workspace:GetAttribute("PartyUntil") or 0) + product.Seconds
		workspace:SetAttribute("PartyUntil", untilTime)
		services.Net.SendAnnounce(`{player.DisplayName} started a CASH PARTY! 2x cash for everyone!`, C.Pink)
	elseif kind == "Rain" then
		services.RewardService:MoneyRain(player)
	elseif kind == "MissionSkip" then
		if not services.RewardService:SkipMission(player) then
			local amount = cashFor(player, 6_000)
			services.DataService:AddCash(player, amount)
			services.Net.SendNotify(player, `All missions are done already, so you got {Format.Cash(amount)} instead!`, C.Green)
		end
	elseif kind == "MaxTune" then
		local carName = services.VehicleService:MaxTune(player)
		if carName then
			services.Net.SendNotify(player, `{carName} is now fully tuned! Spawn it and feel the power.`, C.Lemon)
		else
			local amount = cashFor(player, 15_000)
			services.DataService:AddCash(player, amount)
			services.Net.SendNotify(player, `All your cars are fully tuned, so you got {Format.Cash(amount)} instead!`, C.Green)
		end
	elseif kind == "Starter" then
		if data.StarterPack then
			services.DataService:AddCash(player, product.Cash)
			services.Net.SendNotify(player, `+{Format.Cash(product.Cash)}! (You already own the starter car.)`, C.Green)
		else
			data.StarterPack = true
			services.DataService:AddCash(player, product.Cash)
			services.VehicleService:GiveCar(player, product.Car)
			services.Net.SendNotify(player, `Starter Pack: +{Format.Cash(product.Cash)} and a {Config.CarsById[product.Car].Name}!`, C.Lemon)
		end
		player:SetAttribute("StarterPackOwned", true)
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

---------------------------------------------------------------- Angebote

-- key = Produkt-Schluessel oder "Pass_Name"
function MonetizationService:Offer(player: Player, key: string, reason: string)
	local passKey = key:match("^Pass_(.+)$")
	if passKey and player:GetAttribute(key) then
		return
	end
	if key == "StarterPack" and player:GetAttribute("StarterPackOwned") then
		return
	end
	local t = os.clock()
	if t - (lastOffer[player] or -math.huge) < Config.OfferCooldown then
		return
	end
	lastOffer[player] = t
	self.Services.Net.Offer:FireClient(player, key, reason)
end

-- Passendes Geldpaket, wenn fuer einen Kauf Geld fehlt
function MonetizationService:OfferCash(player: Player, missing: number)
	local key = "CashSmall"
	if missing > cashFor(player, Config.DevProducts.CashMedium.Base) then
		key = "CashLarge"
	elseif missing > cashFor(player, Config.DevProducts.CashSmall.Base) then
		key = "CashMedium"
	end
	self:Offer(player, key, `You need {Format.Cash(missing)} more!`)
end

function MonetizationService:OnStartDriving(player: Player)
	rides[player] = (rides[player] or 0) + 1
	if rides[player] == 3 and not player:GetAttribute("Pass_Nitro") then
		self:Offer(player, "Pass_Nitro", "Go faster with NITRO on every car!")
	end
end

function MonetizationService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if data and data.StarterPack then
		player:SetAttribute("StarterPackOwned", true)
	end
	-- Neue Spieler sehen einmal (nach kurzer Spielzeit) das Starter Pack
	task.delay(240, function()
		if player.Parent and not player:GetAttribute("StarterPackOwned") then
			self:Offer(player, "StarterPack", "One-time welcome deal!")
		end
	end)
end

function MonetizationService:OnPlayerRemoving(player: Player)
	lastOffer[player] = nil
	rides[player] = nil
end

---------------------------------------------------------------- Start

function MonetizationService:Start()
	MarketplaceService.ProcessReceipt = processReceipt
	local services = self.Services

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	services.Net.FakePurchase.OnServerEvent:Connect(function(player, kind, key)
		if not canFake() or typeof(key) ~= "string" then
			return
		end
		if kind == "Pass" and Config.GamePasses[key] and Config.GamePasses[key].ProductId == 0 then
			grantPass(player, key)
		elseif kind == "Product" and Config.DevProducts[key] and Config.DevProducts[key].Id == 0 then
			grantProduct(player, key)
		end
	end)

	-- Rewarded Video Ads: die Belohnung kommt ueber ProcessReceipt (Produkt AdCash)
	local lastAd = {}
	services.Net.WatchAd.OnServerEvent:Connect(function(player)
		local t = os.clock()
		if t - (lastAd[player] or -math.huge) < Config.AdCooldown then
			services.Net.SendNotify(player, "Next free cash in a few minutes!", C.Robber)
			return
		end
		if Config.DevProducts.AdCash.Id == 0 then
			if canFake() then
				grantProduct(player, "AdCash")
			end
			return
		end
		lastAd[player] = t
		local ok, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(Config.DevProducts.AdCash.Id)
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
	end)
end

return MonetizationService
