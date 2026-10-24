-- Garage (Karts und Flammen mit Muenzen kaufen/auswaehlen), taegliche Belohnung, Spielzeit-Geschenk und Freundes-Bonus.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local ShopService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local RED = Color3.fromRGB(255, 90, 90)

local joinedAt: { [Player]: number } = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

function ShopService:Init(services)
	self.Services = services
end

function ShopService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	joinedAt[player] = os.clock()
	player:SetAttribute("GiftAt", workspace:GetServerTimeNow() + Config.PlaytimeGift.Minutes * 60)
	player:SetAttribute("DailyReady", data.DailyDay < today())
	player:SetAttribute("DailyStreak", data.DailyStreak)
	-- Freunde im Server zaehlen (fuer den Muenz-Bonus)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(function()
				local ok, friends = pcall(player.IsFriendsWithAsync, player, other.UserId)
				if ok and friends then
					player:SetAttribute("FriendCount", ((player:GetAttribute("FriendCount") :: number?) or 0) + 1)
					other:SetAttribute("FriendCount", ((other:GetAttribute("FriendCount") :: number?) or 0) + 1)
				end
			end)
		end
	end
end

function ShopService:OnPlayerRemoving(player: Player)
	joinedAt[player] = nil
	for _, other in Players:GetPlayers() do
		if other ~= player and ((other:GetAttribute("FriendCount") :: number?) or 0) > 0 then
			task.spawn(function()
				local ok, friends = pcall(other.IsFriendsWithAsync, other, player.UserId)
				if ok and friends then
					other:SetAttribute("FriendCount", math.max(0, ((other:GetAttribute("FriendCount") :: number?) or 1) - 1))
				end
			end)
		end
	end
end

local function handleShop(player: Player, action: string, id: string)
	local services = ShopService.Services
	local data = services.DataService:Get(player)
	if not data or typeof(action) ~= "string" or typeof(id) ~= "string" then
		return
	end
	if action == "BuyKart" or action == "SelectKart" then
		local kart = Config.KartsById[id]
		if not kart then
			return
		end
		if not player:GetAttribute("Kart_" .. id) then
			if kart.Pass then
				services.MonetizationService:PromptPass(player, kart.Pass)
				return
			end
			if data.Coins < kart.Price then
				services.Net.SendNotify(player, `You need {Format.Number(kart.Price - data.Coins)} more coins.`, RED)
				services.Net.Offer:FireClient(player, "Coins", id)
				return
			end
			data.Coins -= kart.Price
			data.Karts[id] = true
			services.Net.SendNotify(player, `{kart.Name} unlocked!`, GOLD)
		end
		data.Kart = id
		services.DataService:UpdateAttributes(player)
	elseif action == "BuyFlame" or action == "SelectFlame" then
		local flame = Config.FlamesById[id]
		if not flame then
			return
		end
		if not player:GetAttribute("Flame_" .. id) then
			if flame.Pass then
				services.MonetizationService:PromptPass(player, flame.Pass)
				return
			end
			if data.Coins < flame.Price then
				services.Net.SendNotify(player, `You need {Format.Number(flame.Price - data.Coins)} more coins.`, RED)
				services.Net.Offer:FireClient(player, "Coins", id)
				return
			end
			data.Coins -= flame.Price
			data.Flames[id] = true
			services.Net.SendNotify(player, `{flame.Name} flames unlocked!`, GOLD)
		end
		data.Flame = id
		services.DataService:UpdateAttributes(player)
	end
end

local function handleClaim(player: Player, what: string)
	local services = ShopService.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	if what == "Daily" then
		local day = today()
		if data.DailyDay >= day then
			return
		end
		data.DailyStreak = if data.DailyDay == day - 1 then data.DailyStreak % 7 + 1 else 1
		data.DailyDay = day
		local reward = Config.DailyReward(data.DailyStreak)
		services.DataService:AddCoins(player, reward)
		player:SetAttribute("DailyReady", false)
		player:SetAttribute("DailyStreak", data.DailyStreak)
		services.Net.SendNotify(player, `Day {data.DailyStreak} reward: +{Format.Number(reward)} coins!`, GOLD)
	elseif what == "Gift" then
		local t = workspace:GetServerTimeNow()
		if t < (player:GetAttribute("GiftAt") or math.huge) then
			return
		end
		player:SetAttribute("GiftAt", t + Config.PlaytimeGift.Minutes * 60)
		services.DataService:AddCoins(player, Config.PlaytimeGift.Coins)
		services.Net.SendNotify(player, `Playtime gift: +{Config.PlaytimeGift.Coins} coins!`, GOLD)
	end
end

function ShopService:Start()
	self.Services.Net.Shop.OnServerEvent:Connect(handleShop)
	self.Services.Net.Claim.OnServerEvent:Connect(handleClaim)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in joinedAt do
				local data = self.Services.DataService:Get(player)
				if data then
					data.PlayTime += 60
				end
			end
		end
	end)
end

return ShopService
