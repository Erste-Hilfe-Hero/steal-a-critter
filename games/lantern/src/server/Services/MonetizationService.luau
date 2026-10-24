-- Dauerhafte Vorteile ("Passes", als Developer Products verkauft), Developer Products (ProcessReceipt),
-- freiwillige Video-Werbung (Wiederbeleben, Gold) und passende Angebote mit "No thanks".
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)

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

local lastOffer = {} -- [Player] = os.clock()
local lastAd = {} -- [Player] = { [Art] = os.clock() }
local rng = Random.new()

local function canFake(): boolean
	return RunService:IsStudio() and Config.StudioFakePurchases
end

function MonetizationService:Init(services)
	self.Services = services
end

function MonetizationService:IsRestricted(player: Player): boolean
	return player:GetAttribute("RandomRestricted") == true
end

---------------------------------------------------------------- Passes

function MonetizationService:ApplyPassEffects(player: Player)
	self.Services.HeroService:RefreshStats(player)
	self.Services.LootService:SendInventory(player)
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
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	-- Wenn die Abfrage scheitert, vorsichtshalber einschraenken
	player:SetAttribute("RandomRestricted", not ok or policy.ArePaidRandomItemsRestricted == true)
	self:ApplyPassEffects(player)
end

function MonetizationService:PromptPass(player: Player, key: string)
	local pass = Config.GamePasses[key]
	if not pass or player:GetAttribute("Pass_" .. key) then
		return
	end
	if pass.AffectsRandom and self:IsRestricted(player) then
		return
	end
	if pass.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, pass.ProductId)
	elseif canFake() then
		local data = self.Services.DataService:Get(player)
		if data then
			data.Passes[key] = true
		end
		grantPass(player, key)
	else
		self.Services.Net.SendNotify(player, `{pass.Name} is coming soon!`, GOLD)
	end
end

function MonetizationService:PromptProduct(player: Player, key: string)
	local product = Config.DevProducts[key]
	if not product then
		return
	end
	if product.AffectsRandom and self:IsRestricted(player) then
		return
	end
	if product.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	elseif canFake() then
		self:Grant(player, key)
	end
end

---------------------------------------------------------------- Developer Products

-- Gold, das ungefaehr "runs" Dungeon-Laeufen auf der eigenen Stufe entspricht
local function goldFor(player: Player, runs: number, minimum: number): number
	local level = player:GetAttribute("Level") or 1
	return math.floor(math.max(minimum, Config.KillGold(level) * 120 * runs))
end

function MonetizationService:Grant(player: Player, key: string): boolean
	local services = self.Services
	local product = Config.DevProducts[key]
	local data = services.DataService:Get(player)
	if not product or not data then
		return false
	end
	local kind = product.Kind
	if kind == "Gold" then
		local amount = goldFor(player, product.Runs, product.MinGold)
		services.DataService:AddGold(player, amount)
		services.Net.SendNotify(player, `+{Format.Number(amount)} gold! Thanks for your support!`, GOLD)
	elseif kind == "Shards" then
		services.DataService:AddShards(player, product.Amount)
		services.Net.SendNotify(player, `+{product.Amount} shards!`, GOLD)
	elseif kind == "XPBoost" then
		data.XPBoostUntil = math.max(data.XPBoostUntil, os.time()) + product.Seconds
		services.DataService:UpdateAttributes(player)
		services.Net.SendNotify(player, "Double XP active!", GOLD)
	elseif kind == "Revive" then
		if not services.DungeonService:Revive(player) then
			-- Nicht mehr tot (z. B. Gruppe hat weitergespielt): als Gold gutschreiben, damit nichts verloren geht
			services.DataService:AddGold(player, goldFor(player, 0.5, 200))
		end
	elseif kind == "Blessing" then
		data.Blessing += 1
		services.DataService:UpdateAttributes(player)
		services.Net.SendAnnounce(`{player.DisplayName} blessed their party: the next boss drops a Legendary for everyone!`, GOLD)
	elseif kind == "Starter" then
		if data.StarterBought then
			services.DataService:AddGold(player, 2500)
			return true
		end
		data.StarterBought = true
		local weapon = Items.Generate(rng, { Slot = "Weapon", Rarity = 4, Level = math.max(5, data.Level + 3), Unique = "Lantern" })
		services.LootService:GiveItem(player, weapon, nil)
		services.DataService:AddGold(player, 2500)
		services.DataService:AddShards(player, 300)
		data.XPBoostUntil = math.max(data.XPBoostUntil, os.time()) + 1800
		services.LootService:EquipBest(player)
		services.Net.SendNotify(player, "Starter Pack unlocked! Your Lantern weapon is equipped.", GOLD)
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
		local ok, granted = pcall(MonetizationService.Grant, MonetizationService, player, key)
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

-- key: "Pass_X" oder Produkt-Schluessel. Hoechstens ein Angebot alle paar Minuten.
function MonetizationService:Offer(player: Player, key: string, text: string)
	local now = os.clock()
	if now - (lastOffer[player] or -math.huge) < Config.OfferCooldown then
		return
	end
	local passKey = key:match("^Pass_(.+)$")
	local entry = if passKey then Config.GamePasses[passKey] else Config.DevProducts[key]
	if not entry or (passKey and player:GetAttribute("Pass_" .. passKey)) then
		return
	end
	if entry.AffectsRandom and self:IsRestricted(player) then
		return
	end
	lastOffer[player] = now
	self.Services.Net.Offer:FireClient(player, key, text)
end

-- Nach einem Bosssieg: der beste Moment fuer ein Angebot
function MonetizationService:AfterBoss(players: { Player })
	for _, player in players do
		if not player:GetAttribute("Pass_VIP") then
			self:Offer(player, "Pass_VIP", "Boss down! VIP gives +25% gold and XP on every run, forever.")
		elseif not player:GetAttribute("Pass_DoubleXP") then
			self:Offer(player, "Pass_DoubleXP", "Level up twice as fast forever with 2x XP!")
		end
	end
end

---------------------------------------------------------------- Start

function MonetizationService:Start()
	local services = self.Services
	local Net = services.Net
	MarketplaceService.ProcessReceipt = processReceipt

	Net.Handle("BuyPass", function(player, key)
		if typeof(key) == "string" then
			self:PromptPass(player, key)
		end
		return true
	end)
	Net.Handle("BuyProduct", function(player, key)
		if typeof(key) == "string" and key:sub(1, 2) ~= "Ad" then
			if key == "Revive" then
				-- Kaufdialog braucht Zeit: Frist verlaengern, damit man nicht vorher zurueckgesetzt wird
				services.DungeonService:ExtendDeath(player, 25)
			end
			self:PromptProduct(player, key)
		end
		return true
	end)

	-- Rewarded Video Ads: die Belohnung kommt ueber ProcessReceipt (Produkt AdRevive / AdGold)
	Net.Handle("WatchAd", function(player, kind)
		local key = if kind == "Revive" then "AdRevive" elseif kind == "Gold" then "AdGold" else nil
		if not key then
			return false
		end
		local timers = lastAd[player] or {}
		lastAd[player] = timers
		local now = os.clock()
		if key == "AdGold" and now - (timers[key] or -math.huge) < Config.AdCooldown then
			Net.SendNotify(player, "More free gold in a few minutes!", RED)
			return false
		end
		if key == "AdRevive" and not (services.DungeonService:GetRun(player) and services.DungeonService:GetRun(player).Dead[player]) then
			return false
		end
		timers[key] = now
		if key == "AdRevive" then
			services.DungeonService:ExtendDeath(player, 45)
		end
		local product = Config.DevProducts[key]
		if product.Id == 0 then
			if canFake() then
				self:Grant(player, key)
				return true
			end
			return false
		end
		local ok, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(product.Id)
			return AdService:ShowRewardedVideoAdAsync(player, reward)
		end)
		if not ok or result ~= Enum.ShowAdResult.ShowCompleted then
			timers[key] = nil
			if not ok then
				warn("[Ads]", result)
			end
			return false
		end
		return true
	end)

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	Net.FakePurchase.OnServerEvent:Connect(function(player, kind, key)
		if not canFake() or typeof(key) ~= "string" then
			return
		end
		if kind == "Pass" and Config.GamePasses[key] and Config.GamePasses[key].ProductId == 0 then
			self:PromptPass(player, key)
		elseif kind == "Product" and Config.DevProducts[key] and Config.DevProducts[key].Id == 0 then
			self:Grant(player, key)
		end
	end)
end

-- Neue Spieler sehen nach ein paar Minuten einmal das Starter Pack (mit "No thanks")
function MonetizationService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or data.StarterBought or data.StarterOffered then
		return
	end
	task.delay(180, function()
		if player.Parent and not data.StarterOffered then
			data.StarterOffered = true
			lastOffer[player] = nil
			self:Offer(player, "StarterPack", "Welcome, hero! One-time Starter Pack: an Epic Lantern weapon, gold, shards and 2x XP.")
		end
	end)
end

function MonetizationService:OnPlayerRemoving(player: Player)
	lastOffer[player] = nil
	lastAd[player] = nil
end

return MonetizationService
