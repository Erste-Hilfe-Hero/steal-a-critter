-- Sachen zum Zerstoeren (Muenzhaufen, Truhen, Tresore): Spawnen, Antippen, Schaden durch Haustiere, Belohnung.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local BreakableService = { Services = nil :: any }

local breakables = {} -- [id] = { Id, Model, Zone, Health, MaxHealth, Reward, Fill, HpLabel, Damage = { [Player] = number } }
local targets = {} -- [Player] = id
local lastTap = {} -- [Player] = os.clock()
local nextId = 0
local rng = Random.new()

local totalWeight = 0
for _, def in Config.Breakables do
	totalWeight += def.Weight
end

function BreakableService:Init(services)
	self.Services = services
end

local function pickKind()
	local roll = rng:NextNumber() * totalWeight
	for _, def in Config.Breakables do
		roll -= def.Weight
		if roll <= 0 then
			return def
		end
	end
	return Config.Breakables[1]
end

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function buildModel(def, position: Vector3): (Model, Frame, TextLabel)
	local model = Instance.new("Model")
	local s = def.Size
	local body
	if def.Id == "pile" then
		body = makePart({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.5, s, s), CFrame = CFrame.new(position + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = def.Color, Material = Enum.Material.Metal, Parent = model })
		for i = 1, 3 do
			local angle = i * 2.1
			makePart({ Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, s * 0.4, s * 0.4), CFrame = CFrame.new(position + Vector3.new(math.cos(angle) * s * 0.2, s * 0.55 + i * 0.15, math.sin(angle) * s * 0.2)) * CFrame.Angles(0, 0, math.pi / 2 + 0.3), Color = Color3.fromRGB(255, 225, 90), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
		end
	else
		body = makePart({ Name = "Body", Size = Vector3.new(s, s * 0.75, s * 0.7), Position = position + Vector3.new(0, s * 0.375, 0), Color = def.Color, Material = if def.Id == "vault" then Enum.Material.DiamondPlate else Enum.Material.WoodPlanks, Parent = model })
		makePart({ Name = "Band", Size = Vector3.new(s * 1.02, s * 0.12, s * 0.72), Position = body.Position + Vector3.new(0, s * 0.1, 0), Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
		makePart({ Name = "Lock", Size = Vector3.new(s * 0.2, s * 0.22, 0.3), Position = body.Position + Vector3.new(0, s * 0.05, -s * 0.36), Color = Color3.fromRGB(255, 205, 50), Material = Enum.Material.Neon, CanCollide = false, Parent = model })
	end
	model.PrimaryPart = body

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = Config.TapRange
	click.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "Health"
	gui.Size = UDim2.fromOffset(110, 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, s + 1.5, 0)
	gui.MaxDistance = 70
	gui.Parent = body
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	back.Parent = gui
	Instance.new("UICorner", back).CornerRadius = UDim.new(0, 8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(90, 220, 120)
	fill.Parent = back
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 8)
	local hp = Instance.new("TextLabel")
	hp.Size = UDim2.fromScale(1, 1)
	hp.BackgroundTransparency = 1
	hp.Font = Enum.Font.FredokaOne
	hp.TextScaled = true
	hp.TextColor3 = Color3.new(1, 1, 1)
	hp.TextStrokeTransparency = 0.2
	hp.ZIndex = 2
	hp.Parent = back
	return model, fill, hp
end

local function updateBar(entry)
	local ratio = math.clamp(entry.Health / entry.MaxHealth, 0, 1)
	entry.Fill.Size = UDim2.fromScale(ratio, 1)
	entry.HpLabel.Text = Format.Number(math.ceil(entry.Health))
end

function BreakableService:Spawn(zoneIndex: number)
	local zone = Config.Zones[zoneIndex]
	local def = pickKind()
	nextId += 1
	local id = tostring(nextId)
	local position = self.Services.WorldService:RandomSpot(zoneIndex, rng)
	local model, fill, hpLabel = buildModel(def, position)
	model.Name = id
	model:SetAttribute("Zone", zoneIndex)
	model:SetAttribute("Kind", def.Id)

	local entry = {
		Id = id,
		Kind = def.Id,
		Model = model,
		Zone = zoneIndex,
		Position = position,
		MaxHealth = def.Hp * zone.HpScale,
		Health = def.Hp * zone.HpScale,
		Reward = def.Reward * zone.RewardScale,
		Fill = fill,
		HpLabel = hpLabel,
		Damage = {},
	}
	updateBar(entry)
	breakables[id] = entry

	local click = model:FindFirstChildOfClass("ClickDetector") :: ClickDetector
	click.MouseClick:Connect(function(player: Player)
		self:Tap(player, id)
	end)
	model.Parent = self.Services.WorldService.BreakablesFolder
end

local function canReach(player: Player, entry): boolean
	local data = BreakableService.Services.DataService:Get(player)
	if not data or data.Zone < entry.Zone then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - entry.Position).Magnitude <= Config.TapRange
end

function BreakableService:SetTarget(player: Player, id: string?)
	local entry = id and breakables[id]
	if entry and not canReach(player, entry) then
		return
	end
	targets[player] = if entry then id else nil
	player:SetAttribute("Target", if entry then id else "")
end

local function findNearest(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local data = BreakableService.Services.DataService:Get(player)
	if not root or not data then
		return nil
	end
	local best, bestDistance = nil, Config.AutoTargetRange
	for _, entry in breakables do
		if entry.Zone <= data.Zone then
			local distance = (entry.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = entry, distance
			end
		end
	end
	return best
end

local function breakEntry(entry)
	local services = BreakableService.Services
	breakables[entry.Id] = nil
	local total = 0
	for _, amount in entry.Damage do
		total += amount
	end
	for player, amount in entry.Damage do
		if player.Parent and total > 0 then
			local coins = entry.Reward * (amount / total) * services.MonetizationService:GetMultiplier(player)
			coins = math.max(1, math.floor(coins))
			services.DataService:AddCoins(player, coins)
			services.Net.CoinPop:FireClient(player, coins, entry.Position + Vector3.new(0, 4, 0))
			services.ProgressService:Track(player, "Break", 1)
			if entry.Kind ~= "pile" then
				services.ProgressService:Track(player, "Chest", 1)
			end
		end
	end
	for player, id in targets do
		if id == entry.Id then
			targets[player] = nil
			player:SetAttribute("Target", "")
		end
	end
	entry.Model:Destroy()
	task.delay(Config.RespawnTime, function()
		BreakableService:Spawn(entry.Zone)
	end)
end

-- Schaden eintragen; zerstoert die Sache, wenn keine Lebenspunkte mehr uebrig sind
local function dealDamage(player: Player, entry, damage: number)
	entry.Damage[player] = (entry.Damage[player] or 0) + damage
	entry.Health -= damage
	if entry.Health <= 0 then
		breakEntry(entry)
	else
		updateBar(entry)
	end
end

-- Antippen: Ziel waehlen und sofort Extra-Schaden machen (mit Abklingzeit gegen Autoklicker)
function BreakableService:Tap(player: Player, id: string)
	local entry = breakables[id]
	if not entry or not canReach(player, entry) then
		return
	end
	self:SetTarget(player, id)
	local now = os.clock()
	if now - (lastTap[player] or 0) < Config.TapCooldown then
		return
	end
	local power = player:GetAttribute("Power") or 0
	if power <= 0 then
		return
	end
	lastTap[player] = now
	local damage = math.max(1, power * Config.TapDamageShare)
	local position = entry.Position + Vector3.new(0, entry.Model.PrimaryPart.Size.Y + 2, 0)
	dealDamage(player, entry, damage)
	self.Services.Net.TapHit:FireClient(player, damage, position)
	self.Services.ProgressService:Track(player, "Tap", 1)
end

function BreakableService:Start()
	for index in Config.Zones do
		for _ = 1, Config.BreakablesPerZone do
			self:Spawn(index)
		end
	end

	task.spawn(function()
		while true do
			task.wait(Config.DamageTick)
			for _, player in Players:GetPlayers() do
				local power = player:GetAttribute("Power") or 0
				if power <= 0 then
					continue
				end
				local id = targets[player]
				local entry = id and breakables[id]
				if entry and not canReach(player, entry) then
					entry = nil
				end
				if not entry then
					entry = findNearest(player)
					targets[player] = entry and entry.Id
					player:SetAttribute("Target", if entry then entry.Id else "")
				end
				if entry then
					dealDamage(player, entry, power * Config.DamageTick)
				end
			end
		end
	end)
end

function BreakableService:OnPlayerRemoving(player: Player)
	targets[player] = nil
	lastTap[player] = nil
	for _, entry in breakables do
		entry.Damage[player] = nil
	end
end

return BreakableService
