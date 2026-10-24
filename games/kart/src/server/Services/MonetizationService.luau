-- Dauerhafte Vorteile ("Passes", als Developer Products verkauft), Developer Products (ProcessReceipt),
-- Premium-/Freundes-Bonus, Coin Party, Angebote nach dem Rennen und freiwillige Video-Werbung.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Tracks = require(ReplicatedStorage.Shared.Tracks)

local MonetizationService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local RED = Color3.fromRGB(255, 90, 90)

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

local wantedTrack: { [Player]: string } = {}
local lastOffer: { [Player]: number } = {}
local lastAd: { [Player]: number } = {}

local function canFake(): boolean
	return RunService:IsStudio() and Config.StudioFakePurchases
end

function MonetizationService:Init(services)
	self.Services = services
end

function MonetizationService:CoinMultiplier(player: Player): number
	local m = 1
	if player:GetAttribute("Pass_VIP") then
		m *= Config.VipCoinMultiplier
	end
	if player:GetAttribute("Pass_DoubleCoins") then
		m *= Config.DoubleCoinsMultiplier
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		m *= Config.PremiumCoinMultiplier
	end
	m *= 1 + Config.FriendBonusPer * math.min(Config.MaxFriendBonus, (player:GetAttribute("FriendCount") :: number?) or 0)
	if (workspace:GetAttribute("CoinPartyUntil") or 0) > workspace:GetServerTimeNow() then
		m *= Config.CoinPartyMultiplier
	end
	return math.floor(m * 100 + 0.5) / 100
end

---------------------------------------------------------------- Passes

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	local services = MonetizationService.Services
	local data = services.DataService:Get(player)
	if data then
		data.Passes[key] = true
		if key == "InfernoKart" then
			data.Kart = "Inferno"
		elseif key == "VIP" then
			data.Flame = "Gold"
		end
		services.DataService:UpdateAttributes(player)
	end
	services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked forever!`, GOLD)
	services.Net.SendAnnounce(`{player.DisplayName} unlocked {Config.GamePasses[key].Name}!`, GOLD)
end

function MonetizationService:LoadPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	for key in (data and data.Passes or {}) do
		player:SetAttribute("Pass_" .. key, true)
	end
	self.Services.DataService:UpdateAttributes(player)
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
		self.Services.Net.SendNotify(player, `{pass.Name} is coming soon!`, GOLD)
	end
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local data = services.DataService:Get(player)
	local kind = product.Kind

	if kind == "Coins" or kind == "AdCoins" then
		services.DataService:AddCoins(player, product.Coins)
		services.Net.SendNotify(player, `+{Format.Number(product.Coins)} coins! Thanks for your support!`, GOLD)
	elseif kind == "SuperItem" then
		data.SuperItems += product.Amount
		services.DataService:UpdateAttributes(player)
		services.Net.SendNotify(player, `+{product.Amount} Inferno items! Tap INFERNO during a race.`, GOLD)
	elseif kind == "StarterPack" then
		if data.StarterPack then
			services.DataService:AddCoins(player, product.Coins)
		else
			data.StarterPack = true
			data.Flames.Blue = true
			data.SuperItems += product.Items
			services.DataService:AddCoins(player, product.Coins)
		end
		services.Net.SendNotify(player, "Starter Pack unlocked! Have fun racing!", GOLD)
	elseif kind == "CoinParty" then
		local t = workspace:GetServerTimeNow()
		workspace:SetAttribute("CoinPartyUntil", math.max(workspace:GetAttribute("CoinPartyUntil") or 0, t) + product.Seconds)
		services.Net.SendAnnounce(`{player.DisplayName} started a COIN PARTY: 2x coins for everyone!`, GOLD)
	elseif kind == "ChooseTrack" then
		local trackId = wantedTrack[player]
		if not trackId or not Tracks.ById[trackId] then
			trackId = Tracks.List[math.random(1, #Tracks.List)].Id
		end
		services.RaceService.ForcedTrack = trackId
		services.RaceService.ForcedBy = player.DisplayName
		services.Net.SendNotify(player, `Next track: {Tracks.ById[trackId].Name}!`, GOLD)
	elseif kind == "StartNow" then
		services.RaceService.SkipWait = true
		services.Net.SendAnnounce(`{player.DisplayName} started the race NOW!`, GOLD)
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

function MonetizationService:PromptProduct(player: Player, key: string)
	local product = Config.DevProducts[key]
	if not product then
		return
	end
	if product.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	elseif canFake() then
		grantProduct(player, key)
	else
		self.Services.Net.SendNotify(player, `{product.Name} is coming soon!`, GOLD)
	end
end

---------------------------------------------------------------- Angebote

-- Ein passendes Angebot nach dem Rennen (hoechstens alle 3 Minuten, mit "No thanks")
function MonetizationService:AfterRace(player: Player, place: number)
	if not player.Parent then
		return
	end
	local t = os.clock()
	if t - (lastOffer[player] or -math.huge) < 180 then
		return
	end
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local offer
	if not data.StarterPack then
		offer = { Kind = "Product", Key = "StarterPack" }
	elseif place >= 4 and data.SuperItems == 0 then
		offer = { Kind = "Product", Key = "SuperItem" }
	elseif not data.Passes.DoubleCoins then
		offer = { Kind = "Pass", Key = "DoubleCoins" }
	elseif not data.Passes.RocketStart then
		offer = { Kind = "Pass", Key = "RocketStart" }
	elseif not data.Passes.InfernoKart then
		offer = { Kind = "Pass", Key = "InfernoKart" }
	end
	if offer then
		lastOffer[player] = t
		self.Services.Net.Offer:FireClient(player, offer.Kind, offer.Key)
	end
end

---------------------------------------------------------------- Start

function MonetizationService:Start()
	local services = self.Services
	MarketplaceService.ProcessReceipt = processReceipt

	services.Net.Purchase.OnServerEvent:Connect(function(player, kind, key)
		if typeof(key) ~= "string" then
			return
		end
		if kind == "Pass" then
			self:PromptPass(player, key)
		elseif kind == "Product" and Config.DevProducts[key] and key ~= "AdCoins" then
			self:PromptProduct(player, key)
		end
	end)
	services.Net.WantTrack.OnServerEvent:Connect(function(player, trackId)
		if typeof(trackId) == "string" and Tracks.ById[trackId] then
			wantedTrack[player] = trackId
			self:PromptProduct(player, "ChooseTrack")
		end
	end)

	-- Rewarded Video Ads: die Belohnung kommt ueber ProcessReceipt (Produkt AdCoins)
	services.Net.WatchAd.OnServerEvent:Connect(function(player)
		local t = os.clock()
		if t - (lastAd[player] or -math.huge) < Config.AdCooldown then
			services.Net.SendNotify(player, "Next free coins in a few minutes!", RED)
			return
		end
		lastAd[player] = t
		if Config.DevProducts.AdCoins.Id == 0 then
			if canFake() then
				grantProduct(player, "AdCoins")
			end
			return
		end
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
		wantedTrack[player] = nil
		lastOffer[player] = nil
		lastAd[player] = nil
	end)
end

return MonetizationService
