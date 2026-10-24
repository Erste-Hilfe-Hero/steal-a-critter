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
	if key == "VIP" then
		services.ProgressService:UnlockTrail(player, "gold")
	elseif key == "EffectsPack" then
		for _, id in { "rainbow", "galaxy", "lightning" } do
			services.ProgressService:UnlockTrail(player, id)
		end
	end
	services.ProgressService:Refresh(player)
	if not silent then
		services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked forever!`, C.Gold)
		services.Net.SendAnnounce(`{player.DisplayName} got {Config.GamePasses[key].Name}!`, C.Gold)
	end
end

function MonetizationService:LoadPasses(player: Player)
	local data = self.Services.DataService:Get(player)
	for key in (data and data.Passes or {}) do
		grantPass(player, key, true)
	end
	if data and data.Trails.turbo then
		player:SetAttribute("Pass_StarterPack", true)
	end
end

---------------------------------------------------------------- Developer Products

local function fireworks(player: Player)
	local arena = workspace:FindFirstChild("Arena")
	local services = MonetizationService.Services
	services.Net.SendAnnounce(`{player.DisplayName} launched STADIUM FIREWORKS!`, C.Lime)
	task.spawn(function()
		for _ = 1, 12 do
			local attachment = Instance.new("Attachment")
			attachment.WorldPosition = Vector3.new(math.random(-100, 100), math.random(45, 75), math.random(-60, 60))
			attachment.Parent = workspace.Terrain
			local emitter = Instance.new("ParticleEmitter")
			local color = Color3.fromHSV(math.random(), 0.8, 1)
			emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
			emitter.LightEmission = 1
			emitter.Size = NumberSequence.new(1.4, 0)
			emitter.Speed = NumberRange.new(40, 70)
			emitter.SpreadAngle = Vector2.new(180, 180)
			emitter.Lifetime = NumberRange.new(1, 1.8)
			emitter.Acceleration = Vector3.new(0, -30, 0)
			emitter.Drag = 2
			emitter.Rate = 0
			emitter.Parent = attachment
			emitter:Emit(140)
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 60
			light.Brightness = 4
			light.Parent = attachment
			task.delay(2.5, function()
				attachment:Destroy()
			end)
			task.wait(0.35)
		end
	end)
	if arena then
		services.Net.MatchEvent:FireAllClients("Fireworks", { Name = player.DisplayName })
	end
end

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local data = services.DataService:Get(player)
	if not data then
		return false
	end
	if product.Kind == "Coins" or product.Kind == "AdCoins" then
		local coins = product.Coins + (if product.Kind == "AdCoins" then (player:GetAttribute("Level") or 1) * 10 else 0)
		services.ProgressService:AddCoins(player, coins, true)
		services.Net.SendNotify(player, `+{coins} coins!`, C.Gold)
		return true
	elseif product.Kind == "MatchEXP" then
		services.ProgressService:AddEXP(player, product.EXP, true)
		services.Net.SendNotify(player, `+{product.EXP} EXP! Spend it in UPGRADES`, C.Lime)
		return true
	elseif product.Kind == "MaxUpgrades" then
		services.ProgressService:MaxUpgrades(player)
		services.Net.SendAnnounce(`{player.DisplayName} maxed ALL upgrades!`, C.Gold)
		return true
	elseif product.Kind == "XPBoost" then
		data.BoostUntil = math.max(os.time(), data.BoostUntil) + Config.XPBoostMinutes * 60
		services.ProgressService:Refresh(player)
		services.Net.SendNotify(player, `2x XP active for {Config.XPBoostMinutes} minutes!`, C.Lime)
		return true
	elseif product.Kind == "Fireworks" then
		fireworks(player)
		return true
	elseif product.Kind == "Shield" or product.Kind == "Rage" then
		local attribute = product.Kind .. "Until"
		local now = workspace:GetServerTimeNow()
		player:SetAttribute(attribute, math.max(now, player:GetAttribute(attribute) or 0) + product.Seconds)
		if product.Kind == "Shield" and player.Character then
			local field = Instance.new("ForceField")
			field.Parent = player.Character
			task.delay(product.Seconds, function()
				field:Destroy()
			end)
		end
		services.Net.SendAnnounce(`{player.DisplayName} activated {string.upper(product.Name)}!`, if product.Kind == "Rage" then C.Red else C.Cyan)
		return true
	elseif product.Kind == "StarterPack" then
		services.ProgressService:AddCoins(player, product.Coins, true)
		services.ProgressService:AddEXP(player, product.EXP, true)
		data.Trails.turbo = true
		data.Trail = "turbo"
		player:SetAttribute("Pass_StarterPack", true)
		services.ProgressService:Refresh(player)
		services.Net.SendNotify(player, "Starter Pack: +2,500 coins, +1,000 EXP, Starter Flame trail!", C.Gold)
		return true
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

---------------------------------------------------------------- Angebote

-- Neue Spieler sehen nach kurzer Spielzeit einmal das Starter Pack (mit "No thanks")
function MonetizationService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or data.StarterOffered or data.Trails.turbo then
		return
	end
	task.delay(Config.StarterPackDelay, function()
		if player.Parent and not data.StarterOffered then
			data.StarterOffered = true
			self.Services.Net.Offer:FireClient(player, "StarterPack")
		end
	end)
end

-- Nach einer Niederlage den XP-Boost anbieten (hoechstens jedes zweite Mal)
local lossOffers = {}
function MonetizationService:AfterMatch(player: Player, result: string)
	if result ~= "Loss" then
		return
	end
	lossOffers[player] = (lossOffers[player] or 0) + 1
	if lossOffers[player] % 2 == 1 and not self:HasPass(player, "DoubleXP") then
		task.delay(Config.ResultsSeconds - 3, function()
			if player.Parent then
				self.Services.Net.Offer:FireClient(player, "XPBoost")
			end
		end)
	end
end

-- Wer oft umgehauen wird, bekommt (hoechstens alle 4 K.O.s) Iron Body oder Golden Knife angeboten
local knockouts = {}
function MonetizationService:AfterKnockout(player: Player)
	knockouts[player] = (knockouts[player] or 0) + 1
	if knockouts[player] % 4 ~= 3 then
		return
	end
	local choices = {}
	for _, key in { "IronBody", "GoldenKnife" } do
		if not self:HasPass(player, key) then
			table.insert(choices, key)
		end
	end
	if #choices > 0 then
		local key = choices[(knockouts[player] // 4) % #choices + 1]
		task.delay(Config.KOSeconds + 0.5, function()
			if player.Parent then
				self.Services.Net.Offer:FireClient(player, key)
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
		lossOffers[player] = nil
		knockouts[player] = nil
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
