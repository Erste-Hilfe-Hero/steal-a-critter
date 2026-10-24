-- Gamepasses, Developer Products (ProcessReceipt), Premium-Bonus und Server-Glueck.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MonetizationService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)

local luckUntil = 0
local pendingInstant = {} -- [Player] = { Model, TypeId, Rarity }
local passKeyById = {}
local productKeyById = {}

for key, pass in Config.GamePasses do
	if pass.Id ~= 0 then
		passKeyById[pass.Id] = key
	end
end
local passKeyByProductId = {}
for key, pass in Config.GamePasses do
	if pass.ProductId then
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

function MonetizationService:GetMultiplier(player: Player): number
	local data = self.Services.DataService:Get(player)
	local multiplier = 1 + (if data then data.Rebirths else 0) * Config.RebirthMultiplierPer
	if self:HasPass(player, "VIP") then
		multiplier *= Config.VipMultiplier
	end
	if self:HasPass(player, "DoubleCash") then
		multiplier *= Config.DoubleCashMultiplier
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumMultiplier
	end
	return math.floor(multiplier * 100 + 0.5) / 100
end

function MonetizationService:GetLuck(): number
	return if workspace:GetServerTimeNow() < luckUntil then Config.ServerLuckMultiplier else 1
end

---------------------------------------------------------------- Gamepasses

function MonetizationService:ApplyPassEffects(player: Player)
	local speed = if self:HasPass(player, "SpeedCoil") then Config.SpeedCoilWalkSpeed else Config.DefaultWalkSpeed
	player:SetAttribute("BaseWalkSpeed", speed)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.WalkSpeed > 0 then
		humanoid.WalkSpeed = speed
	end
	self.Services.PlotService:RefreshPads(player)
	self.Services.UnitService:UpdateIncome(player)
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
	self:ApplyPassEffects(player)
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local kind = product.Kind

	if kind == "Cash" then
		local income = player:GetAttribute("IncomePerSec") or 0
		local amount = math.max(product.MinCash, income * 60 * product.Minutes)
		services.DataService:AddCash(player, amount)
		services.Net.SendNotify(player, `+{Format.Cash(amount)}! Thanks for your support!`, GOLD)
	elseif kind == "Lock" then
		if not services.PlotService:Lock(player, product.Seconds, true) then
			return false
		end
	elseif kind == "ServerLuck" then
		local now = workspace:GetServerTimeNow()
		luckUntil = math.max(now, luckUntil) + product.Seconds
		workspace:SetAttribute("LuckUntil", luckUntil)
		services.Net.SendAnnounce(`{player.DisplayName} activated SERVER LUCK x{Config.ServerLuckMultiplier} for everyone!`, GREEN)
	elseif kind == "InstantBuy" then
		local pending = pendingInstant[player]
		pendingInstant[player] = nil
		local typeId
		local model
		if pending and pending.Rarity == product.Rarity then
			typeId = pending.TypeId
			model = services.UnitService:TakeFromBelt(pending.Model, typeId)
		else
			-- Fallback: der Kauf muss immer geliefert werden
			for _, def in Config.Units do
				if def.Rarity == product.Rarity then
					typeId = def.Id
					break
				end
			end
		end
		local slot = services.UnitService:FindFreeSlot(player)
		if not slot then
			-- Basis voll: grosszuegig in Cash erstatten statt den Kauf zu verlieren
			if model then
				model:Destroy()
			end
			local refund = Config.UnitsById[typeId].Price * 2
			services.DataService:AddCash(player, refund)
			services.Net.SendNotify(player, `Base full! You got {Format.Cash(refund)} instead.`, GOLD)
		else
			task.spawn(services.UnitService.GiveUnit, services.UnitService, player, typeId, slot, model)
			services.Net.SendAnnounce(`{player.DisplayName} bought a {product.Rarity} {Config.UnitsById[typeId].Name}!`, Config.RaritiesByName[product.Rarity].Color)
		end
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
		services.DataService:RecordReceipt(player, info.PurchaseId)
		data.RobuxSpent += info.CurrencySpent or 0
		if not services.DataService:Save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
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
	services.DataService:RecordReceipt(player, info.PurchaseId)
	data.RobuxSpent += info.CurrencySpent or 0
	if not services.DataService:Save(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Vom Laufband ausgeloest (Taste F bei Epic und hoeher)
function MonetizationService:PromptInstantBuy(player: Player, model: Model, def)
	if not self.Services.UnitService:FindFreeSlot(player) then
		self.Services.Net.SendNotify(player, "Your base is full!", RED)
		return
	end
	local key = "Instant" .. def.Rarity
	local product = Config.DevProducts[key]
	if not product then
		return
	end
	pendingInstant[player] = { Model = model, TypeId = def.Id, Rarity = def.Rarity }
	if product.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	elseif RunService:IsStudio() and Config.StudioFakePurchases then
		grantProduct(player, key)
	else
		self.Services.Net.SendNotify(player, "This product is not set up yet.", RED)
	end
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

	Players.PlayerMembershipChanged:Connect(function(player)
		services.UnitService:UpdateIncome(player)
	end)

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	-- Rewarded Video Ads: die Belohnung kommt ueber ProcessReceipt (Produkt AdCash)
	local lastAd = {}
	services.Net.WatchAd.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastAd[player] or -math.huge) < Config.AdCooldown then
			services.Net.SendNotify(player, "Next free cash in a few minutes!", RED)
			return
		end
		lastAd[player] = now
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

	services.Net.FakePurchase.OnServerEvent:Connect(function(player, kind, key)
		if not (RunService:IsStudio() and Config.StudioFakePurchases) or typeof(key) ~= "string" then
			return
		end
		if kind == "Pass" and Config.GamePasses[key] and Config.GamePasses[key].Id == 0 then
			grantPass(player, key)
		elseif kind == "Product" and Config.DevProducts[key] and Config.DevProducts[key].Id == 0 then
			grantProduct(player, key)
		end
	end)
end

function MonetizationService:OnPlayerRemoving(player: Player)
	pendingInstant[player] = nil
end

return MonetizationService
