-- Baut die Arena per Code: schwebende Insel, drei Lanes, Fluss, Dschungel, Basen, Licht.
-- Liefert ausserdem die Modelle fuer Tuerme, Kerne, Minions, Monster und die Heldenwaffen.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = { Services = nil :: any }

local MAP = Config.Map
local GRASS = Color3.fromRGB(104, 168, 86)
local GRASS_DARK = Color3.fromRGB(70, 130, 72)
local PATH = Color3.fromRGB(222, 196, 150)
local STONE = Color3.fromRGB(196, 186, 170)
local STONE_DARK = Color3.fromRGB(110, 104, 118)
local WATER = Color3.fromRGB(90, 200, 230)

local world: Folder
local arenaFolder: Folder

local function part(props): BasePart
	local className = props.ClassName or "Part"
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Shape" then
			(p :: any)[key] = value
		end
	end
	if props.Shape then
		(p :: any).Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end

-- Zylinder liegen in Roblox auf der Seite: so stehen sie aufrecht
local function disc(position: Vector3, radius: number, height: number, color: Color3, material: Enum.Material?, parent: Instance)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function mirror(position: Vector3, team: number): Vector3
	if team == 2 then
		return Vector3.new(-position.X, position.Y, position.Z)
	end
	return position
end
WorldService.Mirror = mirror

---------------------------------------------------------------- Licht

local function setupLighting()
	Lighting.ClockTime = 16.4
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(90, 80, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(255, 214, 180)
	atmosphere.Decay = Color3.fromRGB(120, 100, 160)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.06
	color.TintColor = Color3.fromRGB(255, 246, 236)
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Parent = Lighting
end

---------------------------------------------------------------- Insel

local function laneSegments()
	local segments = {}
	for _, name in MAP.LaneOrder do
		local points = MAP.Lanes[name]
		for i = 1, #points - 1 do
			table.insert(segments, { points[i], points[i + 1] })
		end
	end
	return segments
end

local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function buildIsland(parent: Instance)
	local w, d = MAP.HalfX * 2 + 24, MAP.HalfZ * 2 + 24
	part({ Name = "Ground", Size = Vector3.new(w, 8, d), Position = Vector3.new(0, -4, 0), Color = GRASS, Material = Enum.Material.Grass, Parent = parent })
	-- Felsiger Rand nach unten (schwebende Insel)
	local rng = Random.new(11)
	for layer = 1, 3 do
		local inset = layer * 9
		part({
			Size = Vector3.new(w - inset * 2, 10, d - inset * 2),
			Position = Vector3.new(0, -8 - layer * 9, 0),
			Color = Color3.fromRGB(150 - layer * 18, 120 - layer * 14, 110 - layer * 8),
			Material = Enum.Material.Rock,
			Parent = parent,
		})
	end
	for _ = 1, 26 do
		local x = rng:NextNumber(-w / 2, w / 2)
		local z = if rng:NextNumber() < 0.5 then -d / 2 - 2 else d / 2 + 2
		if rng:NextNumber() < 0.4 then
			x, z = if rng:NextNumber() < 0.5 then -w / 2 - 2 else w / 2 + 2, rng:NextNumber(-d / 2, d / 2)
		end
		local size = rng:NextNumber(8, 18)
		part({
			Size = Vector3.new(size, size * 1.6, size),
			CFrame = CFrame.new(x, -size * 0.6, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
			Color = Color3.fromRGB(140, 112, 104),
			Material = Enum.Material.Rock,
			CanCollide = false,
			Parent = parent,
		})
	end
	-- Wolken unter der Insel
	for _ = 1, 22 do
		local cloud = part({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * rng:NextNumber(30, 70),
			Position = Vector3.new(rng:NextNumber(-330, 330), rng:NextNumber(-70, -40), rng:NextNumber(-260, 260)),
			Color = Color3.fromRGB(255, 236, 230),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.25,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = parent,
		})
		cloud.Name = "Cloud"
	end
	-- Unsichtbare Waende am Rand
	local wallHeight = 60
	for _, info in {
		{ Vector3.new(0, wallHeight / 2, -d / 2 - 1), Vector3.new(w + 4, wallHeight, 2) },
		{ Vector3.new(0, wallHeight / 2, d / 2 + 1), Vector3.new(w + 4, wallHeight, 2) },
		{ Vector3.new(-w / 2 - 1, wallHeight / 2, 0), Vector3.new(2, wallHeight, d + 4) },
		{ Vector3.new(w / 2 + 1, wallHeight / 2, 0), Vector3.new(2, wallHeight, d + 4) },
	} do
		part({ Name = "Wall", Size = info[2], Position = info[1], Transparency = 1, CanQuery = false, Parent = parent })
	end
end

local function buildLanes(parent: Instance)
	for _, segment in laneSegments() do
		local a, b = segment[1], segment[2]
		local length = (b - a).Magnitude
		local mid = (a + b) / 2
		part({
			Name = "Lane",
			Size = Vector3.new(22, 0.3, length),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.05, 0), b + Vector3.new(0, 0.05, 0)),
			Color = PATH,
			Material = Enum.Material.Cobblestone,
			CanCollide = false,
			Parent = parent,
		})
		disc(b + Vector3.new(0, 0.05, 0), 11, 0.3, PATH, Enum.Material.Cobblestone, parent).CanCollide = false
		-- Kleine Laternen am Rand
		local side = (b - a).Unit:Cross(Vector3.yAxis)
		for t = 0.25, 0.75, 0.5 do
			for _, s in { -1, 1 } do
				local base = a:Lerp(b, t) + side * 13 * s
				part({ Size = Vector3.new(0.6, 5, 0.6), Position = base + Vector3.new(0, 2.5, 0), Color = Color3.fromRGB(80, 64, 54), CanCollide = false, Parent = parent })
				local lamp = part({ Size = Vector3.new(1.2, 1.2, 1.2), Position = base + Vector3.new(0, 5.4, 0), Color = Color3.fromRGB(255, 214, 140), Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
				local light = Instance.new("PointLight")
				light.Range = 12
				light.Brightness = 0.8
				light.Color = Color3.fromRGB(255, 200, 140)
				light.Parent = lamp
			end
		end
	end
end

local function buildRiver(parent: Instance)
	part({ Name = "River", Size = Vector3.new(16, 0.4, MAP.HalfZ * 2 + 20), Position = Vector3.new(0, 0.02, 0), Color = WATER, Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, Reflectance = 0.1, Parent = parent })
	for _, sx in { -1, 1 } do
		part({ Size = Vector3.new(1.4, 0.8, MAP.HalfZ * 2 + 20), Position = Vector3.new(sx * 8.5, 0.2, 0), Color = Color3.fromRGB(200, 196, 180), Material = Enum.Material.Pebble, CanCollide = false, Parent = parent })
	end
	-- Bruecken, wo die Lanes den Fluss kreuzen
	for _, z in { -112, 0, 112 } do
		part({ Size = Vector3.new(20, 0.6, 22), Position = Vector3.new(0, 0.3, z), Color = Color3.fromRGB(150, 104, 70), Material = Enum.Material.WoodPlanks, CanCollide = false, Parent = parent })
	end
end

local function tree(position: Vector3, rng: Random, parent: Instance)
	local height = rng:NextNumber(7, 12)
	part({ Size = Vector3.new(1.6, height, 1.6), Position = position + Vector3.new(0, height / 2, 0), Color = Color3.fromRGB(110, 76, 52), Material = Enum.Material.Wood, Parent = parent })
	local tint = rng:NextNumber()
	local leaves = if tint < 0.6 then GRASS_DARK elseif tint < 0.85 then Color3.fromRGB(230, 150, 90) else Color3.fromRGB(240, 170, 200)
	for i = 0, 2 do
		local size = (3 - i) * 2.6 + rng:NextNumber(0, 1.5)
		part({
			Size = Vector3.new(size, size * 0.75, size),
			CFrame = CFrame.new(position + Vector3.new(0, height + i * 2.4 - 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color = leaves,
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = parent,
		})
	end
end

local function buildJungle(parent: Instance)
	local rng = Random.new(5)
	local avoid = {}
	for _, camp in MAP.Camps do
		table.insert(avoid, camp.Position)
		table.insert(avoid, mirror(camp.Position, 2))
	end
	for _, boss in MAP.Bosses do
		table.insert(avoid, boss.Position)
	end
	local segments = laneSegments()
	for x = -200, 200, 17 do
		for z = -140, 140, 17 do
			local p = Vector3.new(x + rng:NextNumber(-6, 6), 0, z + rng:NextNumber(-6, 6))
			local ok = math.abs(p.X) > 14 and math.abs(p.X) < 150
			for _, segment in segments do
				if ok and distanceToSegment(p, segment[1], segment[2]) < 19 then
					ok = false
				end
			end
			for _, point in avoid do
				if ok and (p - point).Magnitude < 20 then
					ok = false
				end
			end
			if ok and rng:NextNumber() < 0.55 then
				if rng:NextNumber() < 0.75 then
					tree(p, rng, parent)
				else
					local size = rng:NextNumber(3, 6)
					part({
						Size = Vector3.new(size * 1.3, size, size),
						CFrame = CFrame.new(p + Vector3.new(0, size * 0.35, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), 0),
						Color = Color3.fromRGB(150, 146, 140),
						Material = Enum.Material.Rock,
						Parent = parent,
					})
				end
			elseif ok and rng:NextNumber() < 0.5 then
				-- Blumen
				local color = ({ Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 230, 90), Color3.fromRGB(170, 140, 255) })[rng:NextInteger(1, 3)]
				for _ = 1, 3 do
					part({ Size = Vector3.new(0.8, 0.8, 0.8), Position = p + Vector3.new(rng:NextNumber(-3, 3), 0.4, rng:NextNumber(-3, 3)), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
				end
			end
		end
	end
	-- Lager-Plaetze
	for _, point in avoid do
		disc(point + Vector3.new(0, 0.05, 0), 12, 0.3, Color3.fromRGB(150, 130, 100), Enum.Material.Ground, parent).CanCollide = false
	end
end

local function buildBase(team: number, parent: Instance)
	local info = Config.Teams[team]
	local floor = if team == 1 then Color3.fromRGB(232, 206, 160) else Color3.fromRGB(96, 86, 130)
	local trim = info.Color
	local core = MAP.Core[team]
	local fountain = MAP.Fountain[team]
	-- Platz um Kern und Brunnen
	part({ Size = Vector3.new(60, 0.6, 90), Position = Vector3.new(core.X + info.Sign * 14, 0.1, 0), Color = floor, Material = Enum.Material.Sandstone, CanCollide = false, Parent = parent })
	disc(fountain + Vector3.new(0, 0.2, 0), MAP.FountainRadius, 0.6, floor:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Marble, parent).CanCollide = false
	local ring = disc(fountain + Vector3.new(0, 0.3, 0), MAP.FountainRadius + 0.6, 0.4, trim, Enum.Material.Neon, parent)
	ring.CanCollide = false
	ring.Transparency = 0.3
	disc(fountain + Vector3.new(0, 0.35, 0), MAP.FountainRadius - 0.6, 0.45, floor:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Marble, parent).CanCollide = false
	-- Brunnen in der Mitte mit Kristall
	disc(fountain + Vector3.new(0, 1.2, 0), 5, 2.4, STONE, Enum.Material.Marble, parent)
	disc(fountain + Vector3.new(0, 2.3, 0), 4.2, 0.4, WATER, Enum.Material.Glass, parent)
	local crystal = part({ Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(fountain + Vector3.new(0, 6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = trim, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	CollectionService:AddTag(crystal, "Spin")
	-- Fahnen
	for _, z in { -30, -15, 15, 30 } do
		local pole = Vector3.new(fountain.X + info.Sign * 8, 0, z)
		part({ Size = Vector3.new(0.8, 14, 0.8), Position = pole + Vector3.new(0, 7, 0), Color = Color3.fromRGB(70, 60, 60), Parent = parent })
		part({ Size = Vector3.new(0.2, 6, 4), Position = pole + Vector3.new(0, 10.5, -2.2), Color = trim, Material = Enum.Material.Fabric, CanCollide = false, Parent = parent })
	end
	-- Name des Teams auf dem Boden
	local sign = part({ Size = Vector3.new(30, 0.2, 8), CFrame = CFrame.new(fountain + Vector3.new(-info.Sign * 2, 0.5, 26)), Transparency = 1, CanCollide = false, Parent = parent })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = string.upper(info.Name)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = trim
	label.TextTransparency = 0.2
	label.Rotation = if team == 1 then 90 else -90
	label.Parent = gui
end

local function buildDecor(parent: Instance)
	-- Grosse schwebende Kristalle am Himmel als Kulisse
	local rng = Random.new(9)
	for _ = 1, 10 do
		local team = rng:NextInteger(1, 2)
		local x = (if team == 1 then -1 else 1) * rng:NextNumber(150, 300)
		local p = Vector3.new(x, rng:NextNumber(40, 90), rng:NextNumber(-260, 260))
		if math.abs(p.Z) > 170 or math.abs(p.X) > 240 then
			local size = rng:NextNumber(6, 14)
			local crystal = part({
				Size = Vector3.new(size, size * 2, size),
				CFrame = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(45)),
				Color = Config.Teams[team].Color,
				Material = Enum.Material.Glass,
				Transparency = 0.2,
				CanCollide = false,
				CanQuery = false,
				Parent = parent,
			})
			CollectionService:AddTag(crystal, "Float")
		end
	end
end

function WorldService:Init(services)
	self.Services = services
end

function WorldService:Build()
	setupLighting()
	world = Instance.new("Folder")
	world.Name = "Arena"
	world.Parent = workspace
	buildIsland(world)
	buildLanes(world)
	buildRiver(world)
	buildJungle(world)
	buildBase(1, world)
	buildBase(2, world)
	buildDecor(world)
	for _, name in { "Units", "Effects" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
	end
	arenaFolder = world
	-- Spawn-Punkt, damit Roblox nicht am Ursprung spawnt
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Size = Vector3.new(4, 1, 4)
	spawnLocation.Position = MAP.Fountain[1] + Vector3.new(0, 0.5, 10)
	spawnLocation.Neutral = true
	local decal = spawnLocation:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawnLocation.Parent = world
end

function WorldService:UnitsFolder(): Folder
	return workspace:FindFirstChild("Units") :: Folder
end

---------------------------------------------------------------- Modelle

local function newModel(name: string, root: BasePart): Model
	local model = Instance.new("Model")
	model.Name = name
	root.Name = "Root"
	root.Parent = model
	model.PrimaryPart = root
	return model
end

local function attach(model: Model, root: BasePart, props): BasePart
	props.Parent = model
	props.CanCollide = false
	local welded = props.Weld
	props.Weld = nil
	local p = part(props)
	if not root.Anchored or welded then
		p.Anchored = false
		p.Massless = true
		weld(root, p)
	end
	return p
end

function WorldService:MakeTower(team: number, tier: number, position: Vector3): Model
	local info = Config.Teams[team]
	local root = disc(position + Vector3.new(0, 1.5, 0), 5, 3, STONE, Enum.Material.Slate, nil :: any)
	local model = newModel(info.Name .. "Tower" .. tier, root)
	local height = if tier == 1 then 14 else 17
	attach(model, root, { Size = Vector3.new(5, height, 5), Position = position + Vector3.new(0, 3 + height / 2, 0), Color = if team == 1 then Color3.fromRGB(236, 220, 190) else Color3.fromRGB(120, 110, 150), Material = Enum.Material.Slate })
	for _, y in { 5, 3 + height - 1.5 } do
		attach(model, root, { Size = Vector3.new(5.6, 0.8, 5.6), Position = position + Vector3.new(0, y, 0), Color = info.Color, Material = Enum.Material.Neon })
	end
	attach(model, root, { Size = Vector3.new(7, 1.2, 7), Position = position + Vector3.new(0, 3 + height + 0.6, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
	local crystal = attach(model, root, {
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 3 + height + 4.5, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = info.Color,
		Material = Enum.Material.Neon,
	})
	crystal.Name = "Crystal"
	CollectionService:AddTag(crystal, "Spin")
	local light = Instance.new("PointLight")
	light.Color = info.Color
	light.Range = 18
	light.Brightness = 1.5
	light.Parent = crystal
	model:SetAttribute("ShotHeight", 3 + height + 4.5)
	model.Parent = self:UnitsFolder()
	return model
end

function WorldService:MakeCore(team: number, position: Vector3): Model
	local info = Config.Teams[team]
	local root = disc(position + Vector3.new(0, 1.5, 0), 9, 3, STONE, Enum.Material.Marble, nil :: any)
	local model = newModel(info.Name .. "Core", root)
	attach(model, root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 15, 15), CFrame = CFrame.new(position + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = info.Color, Material = Enum.Material.Neon })
	local crystal = attach(model, root, {
		Size = Vector3.new(7, 7, 7),
		CFrame = CFrame.new(position + Vector3.new(0, 11, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = info.Color,
		Material = Enum.Material.Glass,
		Transparency = 0.1,
	})
	crystal.Name = "Crystal"
	CollectionService:AddTag(crystal, "Spin")
	attach(model, root, { Size = Vector3.new(3.4, 3.4, 3.4), CFrame = crystal.CFrame, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	local barrier = attach(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 24, Position = position + Vector3.new(0, 7, 0), Color = info.Color, Material = Enum.Material.ForceField, Transparency = 0 })
	barrier.Name = "Barrier"
	barrier.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = info.Color
	light.Range = 30
	light.Brightness = 2
	light.Parent = crystal
	model:SetAttribute("ShotHeight", 11)
	model.Parent = self:UnitsFolder()
	return model
end

-- Minions: kleine Kristall-Kobolde. Nur der Root ist verankert, der Rest haengt per Weld daran
function WorldService:MakeMinion(team: number, kind: string, position: Vector3): Model
	local info = Config.Teams[team]
	local size = if kind == "Siege" then 4.2 elseif kind == "Caster" then 2.2 else 2.6
	local body = if team == 1 then Color3.fromRGB(246, 226, 190) else Color3.fromRGB(70, 60, 110)
	local root = part({ Size = Vector3.new(size, size, size), Position = position + Vector3.new(0, size / 2 + 0.2, 0), Color = body, CanCollide = false, CanQuery = true, CastShadow = true })
	local model = newModel(info.Name .. kind, root)
	attach(model, root, { Size = Vector3.new(size * 0.8, size * 0.3, 0.2), CFrame = root.CFrame * CFrame.new(0, size * 0.15, -size / 2 - 0.05), Color = info.Color, Material = Enum.Material.Neon, Weld = true })
	attach(model, root, { Size = Vector3.new(size * 1.04, size * 0.18, size * 1.04), CFrame = root.CFrame * CFrame.new(0, -size * 0.3, 0), Color = info.Dark, Weld = true })
	if kind == "Caster" then
		local orb = attach(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = root.CFrame * CFrame.new(size * 0.8, size * 0.5, 0), Color = info.Color, Material = Enum.Material.Neon, Weld = true })
		orb.Name = "Orb"
	elseif kind == "Siege" then
		attach(model, root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.4, 1.4), CFrame = root.CFrame * CFrame.new(0, size * 0.55, -0.6) * CFrame.Angles(0, math.rad(90), 0), Color = STONE_DARK, Material = Enum.Material.Metal, Weld = true })
	else
		attach(model, root, { Size = Vector3.new(0.5, 2.2, 0.5), CFrame = root.CFrame * CFrame.new(size * 0.65, 0.3, -0.4) * CFrame.Angles(math.rad(-20), 0, 0), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Weld = true })
	end
	model.Parent = self:UnitsFolder()
	return model
end

function WorldService:MakeMonster(id: string, position: Vector3): Model
	local info = Config.Monsters[id]
	local color = info.Color
	local size = if info.Boss then 9 else 4.5
	local root = part({ Size = Vector3.new(size, size * 0.8, size), Position = position + Vector3.new(0, size * 0.4 + 0.2, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	local model = newModel(info.Name, root)
	if id == "Wisp" then
		root.Shape = Enum.PartType.Ball
		root.Size = Vector3.one * size
		root.Material = Enum.Material.Neon
		root.Transparency = 0.2
		root.Position = position + Vector3.new(0, size, 0)
		attach(model, root, { Weld = true, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, size * 1.8, size * 1.8), CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(80)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.4 })
	elseif id == "Beetles" then
		attach(model, root, { Weld = true, Size = Vector3.new(size * 1.05, size * 0.3, size * 1.1), Position = root.Position + Vector3.new(0, size * 0.45, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Foil })
		for _, sx in { -1, 1 } do
			attach(model, root, { Weld = true, Size = Vector3.new(0.5, 0.5, 2.6), CFrame = CFrame.new(root.Position + Vector3.new(sx * 1.2, 1, -size / 2 - 1)) * CFrame.Angles(math.rad(25), 0, 0), Color = Color3.fromRGB(60, 40, 20) })
		end
	else
		-- Bosse: Steinkoerper mit Armen und leuchtenden Augen
		attach(model, root, { Weld = true, Size = Vector3.new(size * 0.6, size * 0.5, size * 0.6), Position = root.Position + Vector3.new(0, size * 0.65, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Rock })
		for _, sx in { -1, 1 } do
			attach(model, root, { Weld = true, Size = Vector3.new(size * 0.3, size * 0.9, size * 0.3), Position = root.Position + Vector3.new(sx * size * 0.65, -size * 0.05, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Rock })
			attach(model, root, { Weld = true, Size = Vector3.new(0.8, 0.8, 0.3), Position = root.Position + Vector3.new(sx * 1.1, size * 0.7, -size * 0.31), Color = Color3.new(1, 1, 0.8), Material = Enum.Material.Neon })
		end
	end
	model.Parent = self:UnitsFolder()
	return model
end

---------------------------------------------------------------- Heldenwaffen und Skins

local WEAPONS = {
	Gauntlet = { { Size = Vector3.new(1.6, 1.4, 1.6), Offset = CFrame.new(0, -0.5, 0) }, { Size = Vector3.new(1.8, 0.4, 1.8), Offset = CFrame.new(0, 0.1, 0), Accent = true } },
	Staff = { { Size = Vector3.new(0.3, 6, 0.3), Offset = CFrame.new(0, 0.6, -0.4) }, { Size = Vector3.new(1, 1, 1), Offset = CFrame.new(0, 3.8, -0.4) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Accent = true, Glow = true } },
	Bow = { { Size = Vector3.new(0.25, 4.4, 0.25), Offset = CFrame.new(0, -0.4, -0.6) * CFrame.Angles(math.rad(10), 0, 0) }, { Size = Vector3.new(0.1, 4.2, 0.1), Offset = CFrame.new(0, -0.4, -0.15), Accent = true, Glow = true } },
	Daggers = { { Size = Vector3.new(0.25, 0.3, 2.2), Offset = CFrame.new(0, -1, -0.9), Accent = true, Glow = true }, { Size = Vector3.new(0.4, 0.5, 0.6), Offset = CFrame.new(0, -1, 0.2) } },
	Shield = { { Size = Vector3.new(0.4, 3.2, 2.6), Offset = CFrame.new(-0.5, -0.4, 0) }, { Size = Vector3.new(0.5, 1, 1), Offset = CFrame.new(-0.55, -0.4, 0) * CFrame.Angles(math.rad(45), 0, 0), Accent = true, Glow = true } },
	LeafStaff = { { Size = Vector3.new(0.35, 5.6, 0.35), Offset = CFrame.new(0, 0.4, -0.4) }, { Size = Vector3.new(0.3, 1.6, 1), Offset = CFrame.new(0, 3.4, -0.4), Accent = true, Glow = true }, { Size = Vector3.new(0.3, 1, 1.6), Offset = CFrame.new(0, 3.2, -0.4) * CFrame.Angles(math.rad(30), 0, 0), Accent = true } },
	Spear = { { Size = Vector3.new(0.3, 7, 0.3), Offset = CFrame.new(0, 0.8, -0.4) }, { Size = Vector3.new(0.6, 1.6, 0.2), Offset = CFrame.new(0, 4.9, -0.4), Accent = true, Glow = true } },
}

local PARTICLES = {
	Fire = { Texture = "rbxasset://textures/particles/fire_main.dds", Rate = 18, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(1, 3) },
	Snow = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 10, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5) },
	Sparkle = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 14, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(0.5, 2) },
	Stars = { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 20, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.2, 1) },
}

-- Waffe an die rechte Hand, farbiger Ring unter den Fuessen, Skin-Effekte
function WorldService:DressHero(model: Model, heroId: string, team: number, skinId: string?)
	local hero = Config.HeroesById[heroId]
	local skin = Config.SkinsById[skinId or "Default"] or Config.SkinsById.Default
	local hand = (model:FindFirstChild("RightHand") or model:FindFirstChild("Right Arm")) :: any
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hand or not root then
		return
	end
	local old = model:FindFirstChild("HeroGear")
	if old then
		old:Destroy()
	end
	local gear = Instance.new("Folder")
	gear.Name = "HeroGear"
	gear.Parent = model
	local main = if skin.Color then skin.Color else Color3.fromRGB(70, 66, 80)
	local accent = if skin.Color then skin.Color:Lerp(Color3.new(1, 1, 1), 0.35) else hero.Color
	for _, piece in WEAPONS[hero.Weapon] or {} do
		local p = Instance.new("Part")
		p.Size = piece.Size
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Color = if piece.Accent then accent else main
		p.Material = if piece.Glow then Enum.Material.Neon elseif skin.Material then skin.Material else Enum.Material.Metal
		p.CFrame = hand.CFrame * piece.Offset
		p.Parent = gear
		weld(hand, p)
		if piece.Glow and skin.Particles and PARTICLES[skin.Particles] then
			local info = PARTICLES[skin.Particles]
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = info.Texture
			emitter.Rate = info.Rate
			emitter.Lifetime = info.Lifetime
			emitter.Speed = info.Speed
			emitter.Size = NumberSequence.new(0.6, 0)
			emitter.Color = ColorSequence.new(skin.Color)
			emitter.LightEmission = 0.8
			emitter.Parent = p
		end
	end
	-- Teamring am Boden
	local ring = Instance.new("Part")
	ring.Name = "TeamRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 5, 5)
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.Material = Enum.Material.Neon
	ring.Color = if skinId and skinId ~= "Default" and skin.Color then skin.Color else Config.Teams[team].Color
	ring.Transparency = 0.35
	ring.CastShadow = false
	ring.CFrame = root.CFrame * CFrame.new(0, -2.9, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = gear
	weld(root, ring)
end

function WorldService:Arena(): Folder
	return arenaFolder
end

return WorldService
