-- Einnahmen: Developer Products (Passes dauerhaft gespeichert), Helden und Skins mit Kristallen,
-- Tagesbelohnung, freiwillige Video-Werbung und dezente Angebote nach der Runde.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local MonetizationService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local RED = Color3.fromRGB(255, 90, 90)
local OFFER_COOLDOWN = 180

local productKeyById = {}
for key, product in Config.Products do
	if product.Id ~= 0 then
		productKeyById[product.Id] = key
	end
end

local lastOffer = {} -- [Player] = os.clock()
local lastAd = {}

function MonetizationService:Init(services)
	self.Services = services
end

function MonetizationService:ApplyPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	player:SetAttribute("VIP", data.Passes.Pass_VIP == true)
	player:SetAttribute("DoubleCrystals", data.Passes.Pass_DoubleCrystals == true)
end

---------------------------------------------------------------- Kaeufe vergeben

local function grant(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local dataService = services.DataService
	local data = dataService:Get(player)
	local product = Config.Products[key]
	if not data or not product then
		return false
	end
	local net = services.Net
	local kind = product.Kind
	if kind == "Pass" then
		data.Passes[key] = true
		MonetizationService:ApplyPasses(player)
		net.SendNotify(player, `Thanks! {product.Name} unlocked forever!`, GOLD)
	elseif kind == "AllHeroes" then
		data.AllHeroes = true
		net.SendNotify(player, "Every hero is yours! Thanks for your support!", GOLD)
	elseif kind == "Hero" then
		data.Heroes[product.Hero] = true
		net.SendNotify(player, `{product.Hero} unlocked! Pick them in the next match.`, GOLD)
	elseif kind == "Skin" then
		data.Skins[product.Skin] = true
		data.Skin = product.Skin
		net.SendNotify(player, `{Config.SkinsById[product.Skin].Name} skin unlocked and equipped!`, GOLD)
	elseif kind == "Crystals" then
		data.Crystals += product.Amount
		net.SendNotify(player, `+{product.Amount} crystals!`, GOLD)
	elseif kind == "StarterPack" then
		data.StarterPack = true
		data.Heroes.Volt = true
		data.Skins.Inferno = true
		data.Crystals += 500
		net.SendNotify(player, "Starter Pack: Volt, Inferno skin and 500 crystals!", GOLD)
	elseif kind == "Respawn" then
		local hero = services.HeroService:GetByPlayer(player)
		if hero and hero.Dead then
			services.HeroService:RespawnNow(hero)
		else
			data.Crystals += 50
			net.SendNotify(player, "You were already alive - here are 50 crystals instead!", GOLD)
		end
	else
		warn("[Monetization] Unbekannter Produkttyp", kind)
		return false
	end
	dataService:UpdateAttributes(player)
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
	local key = productKeyById[info.ProductId]
	if not key then
		warn("[Monetization] Unbekannte Produkt-ID", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grant, player, key)
	if not ok or not granted then
		warn("[Monetization] Vergabe fehlgeschlagen", key, granted)
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

function MonetizationService:Offer(player: Player, key: string, text: string)
	local t = os.clock()
	if t - (lastOffer[player] or -math.huge) < OFFER_COOLDOWN then
		return
	end
	lastOffer[player] = t
	self.Services.Net.Offer:FireClient(player, key, text)
end

function MonetizationService:AfterMatch(player: Player, won: boolean)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if not data.StarterPack and data.Matches >= 1 then
		self:Offer(player, "StarterPack", "Starter Pack: Volt + Inferno skin + 500 crystals for just 79 R$ - one time only!")
		return
	end
	if not won and not data.AllHeroes then
		for _, hero in Config.Heroes do
			if not self.Services.DataService:OwnsHero(player, hero.Id) and Config.Products["Hero_" .. hero.Id] then
				self:Offer(player, "Hero_" .. hero.Id, `Try {hero.Name}, the {hero.Title}! Unlock now or save {hero.Crystals} crystals.`)
				return
			end
		end
	end
end

function MonetizationService:OnHeroDeath(_player: Player)
	-- Der Sofort-Respawn-Knopf steht im Todesbildschirm; hier bewusst keine zusaetzliche Werbung
end

---------------------------------------------------------------- Kristall-Kaeufe, Skins, Tagesbelohnung

function MonetizationService:UnlockHero(player: Player, heroId: string)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	local hero = Config.HeroesById[heroId]
	if not data or not hero or dataService:OwnsHero(player, heroId) then
		return
	end
	if data.Crystals < hero.Crystals then
		self.Services.Net.SendNotify(player, `You need {hero.Crystals} crystals. Play matches to earn more!`, RED)
		return
	end
	data.Crystals -= hero.Crystals
	data.Heroes[heroId] = true
	dataService:UpdateAttributes(player)
	self.Services.Net.SendNotify(player, `{hero.Name} unlocked!`, GOLD)
	task.spawn(dataService.Save, dataService, player)
end

function MonetizationService:BuySkin(player: Player, skinId: string)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	local skin = Config.SkinsById[skinId]
	if not data or not skin or not skin.Crystals or dataService:OwnsSkin(player, skinId) then
		return
	end
	if data.Crystals < skin.Crystals then
		self.Services.Net.SendNotify(player, `You need {skin.Crystals} crystals.`, RED)
		return
	end
	data.Crystals -= skin.Crystals
	data.Skins[skinId] = true
	data.Skin = skinId
	dataService:UpdateAttributes(player)
	self.Services.Net.SendNotify(player, `{skin.Name} skin unlocked and equipped!`, GOLD)
	task.spawn(dataService.Save, dataService, player)
end

function MonetizationService:EquipSkin(player: Player, skinId: string)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data or not dataService:OwnsSkin(player, skinId) then
		return
	end
	data.Skin = skinId
	dataService:UpdateAttributes(player)
	-- Sofort sichtbar, wenn der Held gerade lebt
	local hero = self.Services.HeroService:GetByPlayer(player)
	if hero then
		hero.Skin = skinId
		if hero.Model and not hero.Dead then
			self.Services.WorldService:DressHero(hero.Model, hero.HeroId, hero.Team, skinId)
		end
	end
end

function MonetizationService:ClaimDaily(player: Player)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data then
		return
	end
	local today = dataService.Today()
	if data.DailyDay >= today then
		return
	end
	data.DailyStreak = if data.DailyDay == today - 1 then data.DailyStreak + 1 else 1
	data.DailyDay = today
	local amount = Config.DailyRewards[((data.DailyStreak - 1) % #Config.DailyRewards) + 1]
	data.Crystals += amount
	dataService:UpdateAttributes(player)
	self.Services.Net.SendNotify(player, `Day {data.DailyStreak} reward: +{amount} crystals!`, GOLD)
	task.spawn(dataService.Save, dataService, player)
end

---------------------------------------------------------------- Start

function MonetizationService:OnPlayerReady(player: Player)
	self:ApplyPasses(player)
end

function MonetizationService:OnPlayerRemoving(player: Player)
	lastOffer[player] = nil
	lastAd[player] = nil
end

function MonetizationService:Start()
	local net = self.Services.Net
	MarketplaceService.ProcessReceipt = processReceipt

	net.UnlockHero.OnServerEvent:Connect(function(player, heroId)
		if typeof(heroId) == "string" then
			self:UnlockHero(player, heroId)
		end
	end)
	net.BuySkin.OnServerEvent:Connect(function(player, skinId)
		if typeof(skinId) == "string" then
			self:BuySkin(player, skinId)
		end
	end)
	net.EquipSkin.OnServerEvent:Connect(function(player, skinId)
		if typeof(skinId) == "string" then
			self:EquipSkin(player, skinId)
		end
	end)
	net.ClaimDaily.OnServerEvent:Connect(function(player)
		self:ClaimDaily(player)
	end)

	-- Rewarded Video Ads: die Belohnung kommt ueber ProcessReceipt (Produkt AdReward)
	net.WatchAd.OnServerEvent:Connect(function(player)
		local t = os.clock()
		if t - (lastAd[player] or -math.huge) < Config.AdCooldown then
			net.SendNotify(player, "Next free crystals in a few minutes!", RED)
			return
		end
		if Config.Products.AdReward.Id == 0 then
			return
		end
		lastAd[player] = t
		local ok, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(Config.Products.AdReward.Id)
			return AdService:ShowRewardedVideoAdAsync(player, reward)
		end)
		if not ok or result ~= Enum.ShowAdResult.ShowCompleted then
			lastAd[player] = nil
			if not ok then
				warn("[Ads]", result)
			end
		end
	end)

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	net.FakePurchase.OnServerEvent:Connect(function(player, key)
		if not (RunService:IsStudio() and Config.StudioFakePurchases) or typeof(key) ~= "string" then
			return
		end
		local product = Config.Products[key]
		if product and product.Id == 0 then
			grant(player, key)
		end
	end)
end

MonetizationService.Grant = grant

return MonetizationService
