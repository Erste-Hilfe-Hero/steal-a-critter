-- Paesse, Developer Products (ProcessReceipt), Premium-Bonus, Kaufangebote, Video-Werbung und Lootbox-Regeln je Land.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MonetizationService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local RED = Color3.fromRGB(255, 90, 90)
local PRISM = Color3.fromRGB(150, 255, 245)

local shinyUntil = 0
local passKeyById = {}
local passKeyByProductId = {}
local productKeyById = {}
local lastOffer = {} -- [Player] = os.clock()
local lastAd = {} -- [Player] = os.clock()

for key, pass in Config.GamePasses do
	if pass.Id ~= 0 then
		passKeyById[pass.Id] = key
	end
	if pass.ProductId ~= 0 then
		passKeyByProductId[pass.ProductId] = key
	end
end
for key, product in Config.DevProducts do
	if product.Id ~= 0 then
		productKeyById[product.Id] = key
	end
end

function MonetizationService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Abfragen

function MonetizationService:HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

local function boosted(player: Player): boolean
	local data = MonetizationService.Services.DataService:Get(player)
	return data ~= nil and data.BoostUntil > os.time()
end

function MonetizationService:CoinMultiplier(player: Player): number
	local multiplier = 1
	if self:HasPass(player, "VIP") then
		multiplier *= Config.VipCoins
	end
	if self:HasPass(player, "DoubleCoins") then
		multiplier *= Config.DoubleCoins
	end
	if boosted(player) then
		multiplier *= Config.BoostMultiplier
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumMultiplier
	end
	return multiplier
end

function MonetizationService:XpMultiplier(player: Player): number
	local multiplier = 1
	if self:HasPass(player, "VIP") then
		multiplier *= Config.VipXp
	end
	if self:HasPass(player, "DoubleXp") then
		multiplier *= Config.DoubleXp
	end
	if boosted(player) then
		multiplier *= Config.BoostMultiplier
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumMultiplier
	end
	return multiplier
end

function MonetizationService:CatchLuck(player: Player): number
	return if self:HasPass(player, "LuckyCatch") and not self:IsRestricted(player) then Config.LuckyCatchMultiplier else 1
end

function MonetizationService:PlayerShinyMultiplier(player: Player): number
	return if self:HasPass(player, "ShinyHunter") and not self:IsRestricted(player) then Config.ShinyHunterMultiplier else 1
end

function MonetizationService:ServerShinyMultiplier(): number
	return if workspace:GetServerTimeNow() < shinyUntil then Config.ServerShinyMultiplier else 1
end

-- In manchen Laendern (z. B. Belgien, Niederlande) sind bezahlte Zufallsinhalte verboten.
-- Dort werden alle Produkte ausgeblendet, die Zufallsergebnisse beeinflussen.
function MonetizationService:IsRestricted(player: Player): boolean
	return player:GetAttribute("RandomRestricted") == true
end

---------------------------------------------------------------- Paesse

function MonetizationService:ApplyPassEffects(player: Player)
	local speed = if self:HasPass(player, "Speed") then Config.SpeedWalkSpeed else Config.DefaultWalkSpeed
	player:SetAttribute("BaseWalkSpeed", speed)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
	-- Big Team: freie Plaetze sofort mit Bestien aus dem Lager fuellen
	local data = self.Services.DataService:Get(player)
	if data then
		local size = self.Services.BeastService:TeamSize(player)
		for uid in data.Beasts do
			if #data.Team >= size then
				break
			end
			if not table.find(data.Team, uid) then
				table.insert(data.Team, uid)
			end
		end
	end
	self.Services.BeastService:Sync(player)
end

local function grantPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	MonetizationService:ApplyPassEffects(player)
	MonetizationService.Services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked!`, GOLD)
end

function MonetizationService:LoadPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	for key in (data and data.Passes or {}) do
		player:SetAttribute("Pass_" .. key, true)
	end
	for key, pass in Config.GamePasses do
		if pass.Id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				player:SetAttribute("Pass_" .. key, true)
			end
		end
	end
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	-- Wenn die Abfrage scheitert, vorsichtshalber einschraenken
	player:SetAttribute("RandomRestricted", not ok or policy.ArePaidRandomItemsRestricted == true)
	player:SetAttribute("GotStarter", data ~= nil and data.GotStarter)
	self:ApplyPassEffects(player)
end

function MonetizationService:PromptPass(player: Player, key: string)
	local pass = Config.GamePasses[key]
	if not pass or self:HasPass(player, key) or (pass.AffectsRandom and self:IsRestricted(player)) then
		return
	end
	if pass.Id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	elseif pass.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, pass.ProductId)
	end
end

function MonetizationService:PromptProduct(player: Player, key: string)
	local product = Config.DevProducts[key]
	if not product or (product.AffectsRandom and self:IsRestricted(player)) then
		return
	end
	if product.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	end
end

-- Kaufangebot als Karte im Client (hoechstens alle OfferCooldown Sekunden, force = wichtiger Moment)
function MonetizationService:Offer(player: Player, key: string, text: string, force: boolean?)
	local product = Config.DevProducts[key]
	if not product or (product.AffectsRandom and self:IsRestricted(player)) then
		return
	end
	local data = self.Services.DataService:Get(player)
	if product.OneTime and data and data.GotStarter then
		return
	end
	local now = os.clock()
	if not force and now - (lastOffer[player] or -math.huge) < Config.OfferCooldown then
		return
	end
	lastOffer[player] = now
	self.Services.Net.Offer:FireClient(player, key, text)
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local data = services.DataService:Get(player)
	local kind = product.Kind
	local beasts = services.BeastService

	if kind == "Item" then
		beasts:AddItem(player, product.Item, product.Amount)
		services.Net.SendNotify(player, `+{product.Amount} {Config.Items[product.Item].Name}!`, GOLD)
	elseif kind == "Starter" then
		data.GotStarter = true
		player:SetAttribute("GotStarter", true)
		beasts:AddItem(player, "MasterOrb", 3)
		beasts:AddItem(player, "GreatOrb", 10)
		services.DataService:AddCoins(player, 10_000)
		data.BoostUntil = math.max(os.time(), data.BoostUntil) + 1800
		services.DataService:UpdateAttributes(player)
		services.Net.SendNotify(player, "Starter Pack unlocked! Good luck on your journey!", GOLD)
	elseif kind == "Coins" then
		local amount = math.floor(product.Battles * (6 + beasts:LeadLevel(player) * 4) * 1.5)
		services.DataService:AddCoins(player, amount)
		services.Net.SendNotify(player, `+{Format.Coins(amount)}! Thanks for your support!`, GOLD)
	elseif kind == "Boost" then
		data.BoostUntil = math.max(os.time(), data.BoostUntil) + product.Seconds
		services.DataService:UpdateAttributes(player)
		services.Net.SendNotify(player, "2x coins + XP boost active!", GOLD)
	elseif kind == "Levels" then
		local uid = beasts:LeadUid(player)
		if not uid then
			return false
		end
		beasts:AddLevels(player, uid, product.Amount)
		services.Net.SendNotify(player, `Your lead beast gained {product.Amount} levels!`, GOLD)
	elseif kind == "Evolve" then
		-- Fuehrende Bestie aufsteigen lassen; kann sie nicht mehr aufsteigen, die erste im Team, die es kann
		local done = false
		for _, item in beasts:TeamEntries(player) do
			if beasts:Evolve(player, item.Uid, true) then
				done = true
				break
			end
		end
		if not done then
			beasts:AddLevels(player, beasts:LeadUid(player), 5)
			services.Net.SendNotify(player, "No beast in your team can ascend - you got +5 levels instead!", GOLD)
		end
		beasts:Sync(player)
	elseif kind == "Skip" then
		-- Naechster Arena-Orden sofort (nach allen 8: Muenzen)
		if not services.StoryService:GrantBadge(player, data.Crests + 1, true) then
			services.DataService:AddCoins(player, 30_000)
			services.Net.SendNotify(player, "You already have every badge! +30,000 coins instead.", GOLD)
		end
	elseif kind == "Heal" then
		beasts:HealAll(player)
		services.Net.SendNotify(player, "Your whole team is healed and revived!", GOLD)
	elseif kind == "Continue" then
		if not services.BattleService:ContinueGauntlet(player) then
			services.Net.SendNotify(player, "Your team is healed!", GOLD)
		end
	elseif kind == "ServerShiny" then
		local now = workspace:GetServerTimeNow()
		shinyUntil = math.max(now, shinyUntil) + product.Seconds
		workspace:SetAttribute("ShinyUntil", shinyUntil)
		services.Net.SendAnnounce(`{player.DisplayName} started a PRISMATIC STORM! Prismatic beasts x2 for everyone!`, PRISM)
	elseif kind == "Storage" then
		data.ExtraStorage += product.Amount
		beasts:Sync(player)
		services.Net.SendNotify(player, `+{product.Amount} beast storage!`, GOLD)
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
	local services = self.Services
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passKeyById[passId]
		if purchased and key then
			grantPass(player, key)
		end
	end)

	-- Multiplikatoren fuer die Anzeige aktuell halten (Boost laeuft ab)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				if services.DataService:Get(player) then
					player:SetAttribute("CoinMultiplier", math.floor(self:CoinMultiplier(player) * 100 + 0.5) / 100)
					player:SetAttribute("XpMultiplier", math.floor(self:XpMultiplier(player) * 100 + 0.5) / 100)
				end
			end
		end
	end)

	-- Starter Pack: einmalig kurz nach dem ersten Kampf anbieten
	task.spawn(function()
		while true do
			task.wait(20)
			for _, player in Players:GetPlayers() do
				local data = services.DataService:Get(player)
				if data and data.Started and not data.GotStarter and not player:GetAttribute("StarterOffered") and data.PlayTime > 90 then
					player:SetAttribute("StarterOffered", true)
					self:Offer(player, "StarterPack", "WELCOME OFFER: 3 Master Orbs, 10 Great Orbs, 10K coins and a 2x boost!", true)
				end
			end
		end
	end)

	-- Rewarded Video Ads: die Belohnung kommt ueber ProcessReceipt (Produkt AdReward)
	services.Net.WatchAd.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastAd[player] or -math.huge) < Config.AdCooldown then
			services.Net.SendNotify(player, "Next free orbs in a few minutes!", RED)
			return
		end
		lastAd[player] = now
		local ok, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(Config.DevProducts.AdReward.Id)
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
		lastOffer[player] = nil
		lastAd[player] = nil
	end)

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	services.Net.FakePurchase.OnServerEvent:Connect(function(player, kind, key)
		if not (RunService:IsStudio() and Config.StudioFakePurchases) or typeof(key) ~= "string" then
			return
		end
		local pass = Config.GamePasses[key]
		local product = Config.DevProducts[key]
		local data = services.DataService:Get(player)
		if kind == "Pass" and pass and pass.Id == 0 and pass.ProductId == 0 then
			data.Passes[key] = true
			grantPass(player, key)
		elseif kind == "Product" and product and product.Id == 0 then
			grantProduct(player, key)
		end
	end)
end

return MonetizationService
