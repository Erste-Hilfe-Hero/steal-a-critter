-- Dauerhafte Vorteile ("Passes", als Developer Products verkauft), Developer Products (ProcessReceipt),
-- freiwillige Video-Werbung (Rewarded Ads) und das einmalige Starter-Pack-Angebot.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MonetizationService = { Services = nil :: any }

local THEME = Config.Theme

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

local function applyPasses(player: Player)
	local data = MonetizationService.Services.DataService:Get(player)
	for key in Config.GamePasses do
		player:SetAttribute("Pass_" .. key, data and data.Passes[key] == true or nil)
	end
	MonetizationService.Services.DataService:UpdateAttributes(player)
	MonetizationService.Services.CosmeticService:Refresh(player)
end

local function grantPass(player: Player, key: string)
	local data = MonetizationService.Services.DataService:Get(player)
	if data then
		data.Passes[key] = true
	end
	applyPasses(player)
	MonetizationService.Services.Net.SendNotify(player, `Thanks! {Config.GamePasses[key].Name} unlocked forever!`, THEME.Gold)
	MonetizationService.Services.Net.SendAnnounce(`{player.DisplayName} got {Config.GamePasses[key].Name}!`, THEME.Gold)
end

function MonetizationService:LoadPasses(player: Player)
	applyPasses(player)
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local kind = product.Kind
	local data = services.DataService:Get(player)

	if kind == "Flakes" then
		-- Gekaufte Schneeflocken ohne Multiplikator: man bekommt genau die angezeigte Menge
		local amount = services.DataService:AddFlakes(player, product.Amount, false)
		services.Net.SendNotify(player, `+{Format.Number(amount)} Snowflakes!`, THEME.Ice)
	elseif kind == "SkipStage" then
		services.TimerService:Skip(player)
	elseif kind == "LowGravity" then
		local untilTime = math.max(os.time(), workspace:GetAttribute("LowGravityUntil") or 0) + product.Seconds
		workspace:SetAttribute("LowGravityUntil", untilTime)
		workspace:SetAttribute("GravityScale", Config.LowGravityScale)
		services.TimerService:InvalidateAll()
		services.Net.SendAnnounce(`{player.DisplayName} started a MOON GRAVITY PARTY! 3 minutes of low gravity for everyone!`, THEME.Aurora)
		task.delay(product.Seconds + 1, function()
			if (workspace:GetAttribute("LowGravityUntil") or 0) <= os.time() then
				workspace:SetAttribute("GravityScale", 1)
			end
		end)
	elseif kind == "StarterPack" then
		data.Trails.ice = true
		data.Trail = "ice"
		data.StarterPack = true
		player:SetAttribute("StarterPack", true)
		services.DataService:AddFlakes(player, product.Amount, false)
		services.CosmeticService:Refresh(player)
		services.Net.SendNotify(player, "Starter Pack unlocked: 3,000 Snowflakes + Ice Crystal trail!", THEME.Gold)
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

-- Kauf starten (vom Shop oder von gesperrten Knoepfen wie "Checkpoint")
function MonetizationService:Prompt(player: Player, kind: string, key: string)
	if kind == "Pass" then
		local pass = Config.GamePasses[key]
		if not pass or player:GetAttribute("Pass_" .. key) then
			return
		end
		if pass.ProductId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, pass.ProductId)
		elseif canFake() then
			grantPass(player, key)
		else
			self.Services.Net.SendNotify(player, `{pass.Name} is coming soon!`, THEME.Gold)
		end
	elseif kind == "Product" then
		local product = Config.DevProducts[key]
		if not product or key == "AdReward" then
			return
		end
		if key == "StarterPack" and player:GetAttribute("StarterPack") then
			return
		end
		if product.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.Id)
		elseif canFake() then
			grantProduct(player, key)
		else
			self.Services.Net.SendNotify(player, `{product.Name} is coming soon!`, THEME.Gold)
		end
	end
end

---------------------------------------------------------------- Start

function MonetizationService:Start()
	local services = self.Services
	MarketplaceService.ProcessReceipt = processReceipt

	services.Net.Purchase.OnServerEvent:Connect(function(player, kind, key)
		if typeof(kind) == "string" and typeof(key) == "string" then
			self:Prompt(player, kind, key)
		end
	end)

	-- Rewarded Video Ads: die Belohnung kommt ueber ProcessReceipt (Produkt AdReward)
	local lastAd = {}
	services.Net.WatchAd.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastAd[player] or -math.huge) < Config.AdCooldown then
			services.Net.SendNotify(player, "More free Snowflakes in a few minutes!", THEME.Red)
			return
		end
		local product = Config.DevProducts.AdReward
		if product.Id == 0 then
			if canFake() then
				grantProduct(player, "AdReward")
			end
			return
		end
		lastAd[player] = now
		local ok, result = pcall(function()
			local reward = AdService:CreateAdRewardFromDevProductId(product.Id)
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

	-- Mondschwerkraft nach einem Server-Neustart nicht haengen lassen
	workspace:SetAttribute("GravityScale", 1)
end

-- Neue Spieler sehen einmal (nach ein paar Minuten Spielzeit) das Starter Pack, mit "No thanks"
function MonetizationService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	player:SetAttribute("StarterPack", data.StarterPack == true or nil)
	if data.StarterPack or data.StarterOffered then
		return
	end
	task.delay(150, function()
		if player.Parent and not data.StarterPack then
			data.StarterOffered = true
			player:SetAttribute("ShowOffer", "StarterPack")
		end
	end)
end

function MonetizationService:OnPlayerRemoving(_player: Player) end

return MonetizationService
