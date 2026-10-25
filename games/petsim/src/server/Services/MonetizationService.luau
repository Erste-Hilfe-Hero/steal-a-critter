-- Gamepasses, Developer Products (ProcessReceipt), Premium-Bonus, Server-Glueck und Lootbox-Regeln je Land.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local MonetizationService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)

local luckUntil = 0
local passKeyById = {}
local passKeyByProductId = {}
local productKeyById = {}

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

function MonetizationService:GetMultiplier(player: Player): number
	local data = self.Services.DataService:Get(player)
	local multiplier = 1 + (if data then data.Rebirths else 0) * Config.RebirthMultiplierPer
	if self:HasPass(player, "VIP") then
		multiplier *= Config.VipMultiplier
	end
	if self:HasPass(player, "DoubleCoins") then
		multiplier *= Config.DoubleCoinsMultiplier
	end
	if data and data.BoostUntil > os.time() then
		multiplier *= Config.BoostMultiplier
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumMultiplier
	end
	-- Sammel-Index: +5 % pro komplett entdecktem Ei
	if data then
		multiplier *= 1 + Config.CompletedEggs(data.Discovered) * Config.IndexBonusPerEgg
	end
	-- Happy Hour (kostenloses Server-Event fuer alle)
	if Config.HappyHourState(os.time()) then
		multiplier *= Config.HappyHourMultiplier
	end
	return math.floor(multiplier * 100 + 0.5) / 100
end

function MonetizationService:GetServerLuck(): number
	return if workspace:GetServerTimeNow() < luckUntil then Config.ServerLuckMultiplier else 1
end

-- In manchen Laendern (z. B. Belgien, Niederlande) sind bezahlte Zufallsinhalte verboten.
-- Dort werden alle Produkte ausgeblendet, die Zufallsergebnisse beeinflussen.
function MonetizationService:IsRestricted(player: Player): boolean
	return player:GetAttribute("RandomRestricted") == true
end

---------------------------------------------------------------- Gamepasses

function MonetizationService:ApplyPassEffects(player: Player)
	local speed = if self:HasPass(player, "Speed") then Config.SpeedWalkSpeed else Config.DefaultWalkSpeed
	player:SetAttribute("BaseWalkSpeed", speed)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
	self.Services.PetService:Refresh(player)
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
	self:ApplyPassEffects(player)
end

-- Kaufdialog fuer einen Vorteil oeffnen (z. B. wenn jemand "Hatch x3" ohne Pass drueckt)
function MonetizationService:PromptPass(player: Player, key: string)
	local pass = Config.GamePasses[key]
	if not pass or self:HasPass(player, key) then
		return
	end
	if pass.AffectsRandom and self:IsRestricted(player) then
		return
	end
	if pass.Id ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
	elseif pass.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, pass.ProductId)
	elseif RunService:IsStudio() and Config.StudioFakePurchases then
		self.Services.Net.SendNotify(player, `[Studio] {pass.Name} needs a pass - buy it in the shop.`, GOLD)
	end
end

---------------------------------------------------------------- Developer Products

local function grantProduct(player: Player, key: string): boolean
	local services = MonetizationService.Services
	local product = Config.DevProducts[key]
	local data = services.DataService:Get(player)
	local kind = product.Kind

	if kind == "Coins" then
		local amount = services.PetService:EggValue(player, product.Eggs)
		services.DataService:AddCoins(player, amount)
		services.Net.SendNotify(player, `+{Format.Coins(amount)}! Thanks for your support!`, GOLD)
	elseif kind == "Boost" then
		data.BoostUntil = math.max(os.time(), data.BoostUntil) + product.Seconds
		services.DataService:UpdateAttributes(player)
		services.Net.SendNotify(player, "2x Coins boost active!", GOLD)
	elseif kind == "ServerLuck" then
		local now = workspace:GetServerTimeNow()
		luckUntil = math.max(now, luckUntil) + product.Seconds
		workspace:SetAttribute("LuckUntil", luckUntil)
		services.Net.SendAnnounce(`{player.DisplayName} activated SERVER LUCK x{Config.ServerLuckMultiplier} for everyone!`, GREEN)
	elseif kind == "Storage" then
		data.ExtraStorage += product.Amount
		services.PetService:Refresh(player)
		services.Net.SendNotify(player, `+{product.Amount} pet storage!`, GOLD)
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
		-- Schon vergeben (z. B. Speichern beim ersten Versuch fehlgeschlagen): erst bestaetigen, wenn es gespeichert ist
		if not services.DataService:Save(player) then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
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

	Players.PlayerMembershipChanged:Connect(function(player)
		player:SetAttribute("Multiplier", self:GetMultiplier(player))
	end)

	-- Multiplikator fuer die Anzeige aktuell halten (Boost laeuft ab)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				if services.DataService:Get(player) then
					player:SetAttribute("Multiplier", self:GetMultiplier(player))
					player:SetAttribute("Luck", services.PetService:GetLuck(player))
				end
			end
		end
	end)

	-- Nur in Studio: Kaeufe von noch nicht angelegten Produkten simulieren
	services.Net.FakePurchase.OnServerEvent:Connect(function(player, kind, key)
		if not (RunService:IsStudio() and Config.StudioFakePurchases) or typeof(key) ~= "string" then
			return
		end
		local pass = Config.GamePasses[key]
		local product = Config.DevProducts[key]
		if kind == "Pass" and pass and pass.Id == 0 and pass.ProductId == 0 then
			grantPass(player, key)
		elseif kind == "Product" and product and product.Id == 0 then
			grantProduct(player, key)
		end
	end)
end

return MonetizationService
