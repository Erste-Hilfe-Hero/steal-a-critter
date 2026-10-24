-- Muenzen erscheinen waehrend der Runde auf der Karte. Jeder Teilnehmer hat einen Beutel (40, mehr mit VIP/Big Bag).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CoinService = { Services = nil :: any }

local CC = Config.Coins

local folder: Folder
local running = false
local spots = {}
local friendCount = {} -- [Player] = Anzahl Freunde im Server

function CoinService:BagSize(actor): number
	local size = CC.Bag
	if actor.Player then
		local monetization = self.Services.MonetizationService
		if monetization:HasPass(actor.Player, "VIP") then
			size += CC.VIPBag
		end
		if monetization:HasPass(actor.Player, "BigBag") then
			size += CC.BigBag
		end
	end
	return size
end

-- Muenz-Multiplikator eines Spielers (Passes, Freunde, Runden-Modifikator)
function CoinService:Multiplier(player: Player): number
	local monetization = self.Services.MonetizationService
	local m = 1
	if monetization:HasPass(player, "VIP") then
		m *= 1.5
	end
	if monetization:HasPass(player, "DoubleCoins") then
		m *= 2
	end
	m *= 1 + math.min((friendCount[player] or 0) * CC.FriendBoost, CC.FriendBoostMax)
	m *= self.Services.RoundService:CoinMultiplier()
	return m
end

function CoinService:Collect(actor, coin: BasePart)
	if not running or not actor.Alive or coin:GetAttribute("Taken") then
		return
	end
	local bag = self:BagSize(actor)
	if actor.Coins >= bag then
		return
	end
	coin:SetAttribute("Taken", true)
	coin:Destroy()
	actor.Coins += 1
	actor.Model:SetAttribute("BagCoins", actor.Coins)
	if actor.Player then
		local player = actor.Player
		actor.CoinValue += self:Multiplier(player)
		local pay = math.floor(actor.CoinValue) - actor.CoinPaid
		if pay > 0 then
			actor.CoinPaid += pay
			self.Services.ProgressService:AddCoins(player, pay, false, true)
		end
		self.Services.ProgressService:Track(player, "Coins", 1)
		self.Services.ProgressService:AddStat(player, "CoinsCollected", 1)
		self.Services.Net.Fx:FireClient(player, "Coin", { Bag = actor.Coins, Max = bag })
		if actor.Coins == bag then
			self.Services.Net.SendNotify(player, "Your coin bag is full!", Config.Colors.Moon)
		end
	end
end

local function makeCoin(position: Vector3)
	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.35, 2, 2)
	coin.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	coin.Color = Config.Colors.Moon
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CastShadow = false
	coin:AddTag("Coin")
	coin.Touched:Connect(function(hit)
		local actor = CoinService.Services.RoundService:ActorFromPart(hit)
		if actor then
			CoinService:Collect(actor, coin)
		end
	end)
	coin.Parent = folder
	return coin
end

-- Freien Platz finden: von oben nach unten auf die Karte zielen
local function spawnCoin(map)
	local base = spots[math.random(1, #spots)]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.Model }
	local origin = base + Vector3.new(math.random(-20, 20) / 10, Config.WallHeight - 2, math.random(-20, 20) / 10)
	local hit = workspace:Raycast(origin, Vector3.new(0, -Config.WallHeight, 0), params)
	if not hit or hit.Position.Y > base.Y + 5 then
		return
	end
	for _, other in folder:GetChildren() do
		if (other.Position - hit.Position).Magnitude < 3 then
			return
		end
	end
	makeCoin(hit.Position + Vector3.new(0, 1.8, 0))
end

function CoinService:SpawnOne(map)
	spawnCoin(map)
end

function CoinService:StartRound(map)
	running = true
	spots = map.CoinSpots
	folder:ClearAllChildren()
	task.spawn(function()
		-- Ein paar Muenzen sofort
		for _ = 1, 10 do
			spawnCoin(map)
		end
		while running do
			local mod = self.Services.RoundService.Modifier
			local rush = mod and mod.Id == "GoldRush"
			task.wait(if rush then CC.SpawnEvery / 2 else CC.SpawnEvery)
			if running and #folder:GetChildren() < (if rush then CC.MaxOnMap * 1.5 else CC.MaxOnMap) then
				spawnCoin(map)
			end
		end
	end)
end

function CoinService:StopRound()
	running = false
	folder:ClearAllChildren()
end

-- Muenz-Magnet: Muenzen in der Naehe einsammeln
function CoinService:Magnet(actor, radius: number)
	for _, coin in folder:GetChildren() do
		if coin:IsA("BasePart") and (coin.Position - actor.Root.Position).Magnitude < radius then
			self:Collect(actor, coin)
		end
	end
end

function CoinService:Count(): number
	return #folder:GetChildren()
end

function CoinService:Nearest(position: Vector3): BasePart?
	local best, bestDist = nil, math.huge
	for _, coin in folder:GetChildren() do
		if coin:IsA("BasePart") then
			local d = (coin.Position - position).Magnitude
			if d < bestDist then
				best, bestDist = coin, d
			end
		end
	end
	return best
end

local function countFriends(player: Player)
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return (player :: any):IsFriendsWithAsync(other.UserId)
			end)
			if ok and isFriend then
				count += 1
			end
		end
	end
	friendCount[player] = count
	player:SetAttribute("Friends", count)
end

function CoinService:Init(services)
	self.Services = services
	folder = Instance.new("Folder")
	folder.Name = "Coins"
	folder.Parent = workspace
end

function CoinService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.wait(3)
		for _, p in Players:GetPlayers() do
			task.spawn(countFriends, p)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		friendCount[player] = nil
		task.defer(function()
			for _, p in Players:GetPlayers() do
				task.spawn(countFriends, p)
			end
		end)
	end)
end

return CoinService
