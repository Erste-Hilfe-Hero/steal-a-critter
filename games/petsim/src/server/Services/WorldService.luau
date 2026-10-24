-- Baut die Map per Code: Zonen hintereinander, Tore, Eier, Spawn und das taegliche Geschenk.
-- So funktioniert das Projekt auch in einem leeren Place. Die Optik kann man spaeter
-- in Studio durch gebaute Modelle ersetzen, solange die Namen gleich bleiben.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local WorldService = { Services = nil :: any }
WorldService.Zones = {}

local W = Config.ZoneWidth
local HALF = W / 2

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

local function makeBillboard(parent: BasePart, offset: Vector3, size: UDim2, maxDistance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = maxDistance or 150
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return label
end

local function makePrompt(parent: Instance, name: string, action: string, object: string, key: Enum.KeyCode?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = Config.EggRange
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = key or Enum.KeyCode.E
	prompt.Parent = parent
	return prompt
end

function WorldService:Init(services)
	self.Services = services
end

-- Zone, in der eine X-Position liegt (1 bis Anzahl Zonen)
function WorldService.ZoneAt(x: number): number
	return math.clamp(math.floor(x / W) + 1, 1, #Config.Zones)
end

function WorldService.ZoneCenter(index: number): Vector3
	return Vector3.new((index - 0.5) * W, 0, 0)
end

function WorldService.SpawnCFrame(index: number): CFrame
	return CFrame.new((index - 1) * W + 12, 4, 0)
end

local function decorate(folder: Folder, zoneIndex: number, zone)
	local rng = Random.new(zoneIndex * 101)
	local minX = (zoneIndex - 1) * W
	local trunkColor = zone.Ground:Lerp(Color3.fromRGB(90, 60, 30), 0.7)
	local leafColor = zone.Ground:Lerp(Color3.fromRGB(40, 140, 50), 0.5)
	for _ = 1, 14 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = minX + rng:NextNumber(8, W - 8)
		local z = side * rng:NextNumber(HALF - 9, HALF - 3)
		local height = rng:NextNumber(6, 12)
		makePart({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.6, 1.6), CFrame = CFrame.new(x, height / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color = trunkColor, Material = Enum.Material.Wood, Parent = folder })
		makePart({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(6, 9), Position = Vector3.new(x, height + 1.5, z), Color = leafColor, Material = zone.Material, Parent = folder })
	end
end

function WorldService:Build()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 160)

	local world = Instance.new("Folder")
	world.Name = "World"
	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = world

	local total = #Config.Zones * W
	-- Aussenwaende: niedrig sichtbar, hoch unsichtbar
	for _, z in { -HALF, HALF } do
		makePart({ Name = "Fence", Size = Vector3.new(total, 5, 1.5), Position = Vector3.new(total / 2, 2.5, z), Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.WoodPlanks, Parent = world })
		makePart({ Name = "Barrier", Size = Vector3.new(total, 80, 1), Position = Vector3.new(total / 2, 40, z), Transparency = 1, Parent = world })
	end
	for _, x in { 0, total } do
		makePart({ Name = "Fence", Size = Vector3.new(1.5, 5, W), Position = Vector3.new(x, 2.5, 0), Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.WoodPlanks, Parent = world })
		makePart({ Name = "Barrier", Size = Vector3.new(1, 80, W), Position = Vector3.new(x, 40, 0), Transparency = 1, Parent = world })
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(12, 0.5, 0)
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 220, 120)
	spawn.Parent = world

	-- Taegliches Geschenk
	local gift = makePart({ Name = "DailyGift", Size = Vector3.new(5, 5, 5), Position = Vector3.new(14, 2.5, 30), Color = Color3.fromRGB(255, 80, 120), Material = Enum.Material.SmoothPlastic, Parent = world })
	makePart({ Name = "Ribbon", Size = Vector3.new(5.2, 5.2, 1), Position = gift.Position, Color = Color3.fromRGB(255, 220, 60), Parent = gift })
	makePart({ Name = "Ribbon", Size = Vector3.new(1, 5.2, 5.2), Position = gift.Position, Color = Color3.fromRGB(255, 220, 60), Parent = gift })
	makeBillboard(gift, Vector3.new(0, 5, 0), UDim2.fromScale(10, 2)).Text = "DAILY GIFT"
	local giftPrompt = makePrompt(gift, "DailyPrompt", "Claim", "Daily Gift")
	giftPrompt.MaxActivationDistance = 10
	self.DailyPrompt = giftPrompt

	for index, zone in Config.Zones do
		local folder = Instance.new("Folder")
		folder.Name = "Zone" .. index
		local minX = (index - 1) * W

		makePart({
			Name = "Ground",
			Size = Vector3.new(W, 2, W),
			Position = Vector3.new(minX + HALF, -1, 0),
			Color = zone.Ground,
			Material = zone.Material,
			Parent = folder,
		})
		decorate(folder, index, zone)

		local entry = { Index = index, MinX = minX, MaxX = minX + W, Folder = folder }

		if index > 1 then
			local gate = makePart({
				Name = "Gate",
				Size = Vector3.new(2, 40, W),
				Position = Vector3.new(minX, 20, 0),
				Color = Color3.fromRGB(80, 200, 255),
				Material = Enum.Material.ForceField,
				Transparency = 0.3,
				Parent = folder,
			})
			gate:SetAttribute("Zone", index)
			local sign = makePart({ Name = "GateSign", Size = Vector3.new(1, 1, 1), Position = Vector3.new(minX - 3, 3, 0), Transparency = 1, CanCollide = false, Parent = folder })
			local label = makeBillboard(sign, Vector3.new(0, 5, 0), UDim2.fromScale(18, 4), 120)
			label.Text = `{zone.Name}\nUnlock: {Format.Coins(zone.GateCost)}`
			local prompt = makePrompt(sign, "GatePrompt", "Unlock", `{zone.Name} - {Format.Coins(zone.GateCost)}`)
			prompt.HoldDuration = 0.5
			prompt:SetAttribute("Zone", index)
			entry.Gate = gate
			entry.GatePrompt = prompt
		end

		local egg = Config.EggByZone[index]
		if egg then
			local base = Vector3.new(minX + 24, 0, -40)
			makePart({ Name = "Pedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 14, 14), CFrame = CFrame.new(base + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(240, 240, 250), Material = Enum.Material.Marble, Parent = folder })
			local eggPart = makePart({
				Name = "Egg",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(7, 7, 7),
				Position = base + Vector3.new(0, 6, 0),
				Color = egg.Color,
				Material = Enum.Material.SmoothPlastic,
				Parent = folder,
			})
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Scale = Vector3.new(1, 1.3, 1)
			mesh.Parent = eggPart
			eggPart:SetAttribute("EggId", egg.Id)
			makeBillboard(eggPart, Vector3.new(0, 7.5, 0), UDim2.fromScale(14, 2.2), 100).Text = `{egg.Name} - {Format.Coins(egg.Price)}`
			-- Chancen-Anzeige (der Client schreibt die Werte mit dem eigenen Glueck hinein)
			local odds = makeBillboard(eggPart, Vector3.new(0, -1, 0), UDim2.fromOffset(260, 150), 60)
			odds.Parent.Name = "Odds"
			odds.Parent.StudsOffsetWorldSpace = Vector3.new(0, 0, 9)
			odds.TextScaled = false
			odds.TextSize = 16
			odds.RichText = true
			odds.Text = ""
			entry.Egg = egg
			entry.EggPart = eggPart
			entry.HatchPrompt = makePrompt(eggPart, "HatchPrompt", "Hatch", `{egg.Name} - {Format.Coins(egg.Price)}`, Enum.KeyCode.E)
			local triple = makePrompt(eggPart, "Hatch3Prompt", "Hatch x3", `{egg.Name} - {Format.Coins(egg.Price * 3)}`, Enum.KeyCode.R)
			triple.UIOffset = Vector2.new(0, 80)
			entry.Hatch3Prompt = triple
		end

		folder.Parent = zonesFolder
		self.Zones[index] = entry
	end

	local breakables = Instance.new("Folder")
	breakables.Name = "Breakables"
	breakables.Parent = world
	self.BreakablesFolder = breakables

	world.Parent = workspace
end

-- Zufaellige Position fuer Sachen zum Zerstoeren (nicht am Ei und nicht am Tor)
function WorldService:RandomSpot(index: number, rng: Random): Vector3
	local minX = (index - 1) * W
	local x = minX + rng:NextNumber(40, W - 12)
	local z = rng:NextNumber(-HALF + 14, HALF - 14)
	return Vector3.new(x, 0, z)
end

return WorldService
