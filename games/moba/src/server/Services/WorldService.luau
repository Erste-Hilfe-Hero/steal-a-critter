-- Baut die Arena per Code: quadratische Kluft mit drei Lanes, diagonalem Fluss, vier Dschungel-Vierteln
-- mit Felswaenden und Pfaden, Bueschen, Drachen- und Baron-Grube und zwei Basen.
-- Liefert ausserdem die Modelle fuer Tuerme, Inhibitoren, Nexus, Minions, Monster, Wards und die Heldenwaffen.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = { Services = nil :: any }

local MAP = Config.Map
local HALF = MAP.Half
local GRASS = Color3.fromRGB(88, 150, 76)
local GRASS_DARK = Color3.fromRGB(54, 110, 60)
local PATH = Color3.fromRGB(196, 170, 122)
local STONE = Color3.fromRGB(190, 182, 168)
local STONE_DARK = Color3.fromRGB(96, 92, 104)
local ROCK = Color3.fromRGB(118, 110, 100)
local WATER = Color3.fromRGB(70, 170, 210)
local BRUSH = Color3.fromRGB(60, 140, 70)

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
local function disc(position: Vector3, radius: number, height: number, color: Color3, material: Enum.Material?, parent: Instance?)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

---------------------------------------------------------------- Raster der Hindernisse (Sichtlinien und Bot-Wege)

local CELL = 3
local blocked: { [number]: boolean } = {}

local function cellKey(x: number, z: number): number
	return math.floor(x / CELL) * 4096 + math.floor(z / CELL)
end

-- Grundflaeche eines Teils als Hindernis eintragen
local function markBlocked(p: BasePart)
	local frame, size = p.CFrame, p.Size
	local hx, hz = size.X / 2, size.Z / 2
	for lx = -hx, hx + 0.01, 1.5 do
		for lz = -hz, hz + 0.01, 1.5 do
			local world = frame:PointToWorldSpace(Vector3.new(math.min(lx, hx), 0, math.min(lz, hz)))
			blocked[cellKey(world.X, world.Z)] = true
		end
	end
end

function WorldService.Blocked(position: Vector3): boolean
	return blocked[cellKey(position.X, position.Z)] == true
end

-- Freie Linie zwischen zwei Punkten (keine Waende dazwischen)
function WorldService.LineClear(a: Vector3, b: Vector3): boolean
	local offset = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local length = offset.Magnitude
	if length < 0.01 then
		return true
	end
	local steps = math.ceil(length / 1.5)
	for i = 1, steps - 1 do
		local p = a + offset * (i / steps)
		if blocked[cellKey(p.X, p.Z)] then
			return false
		end
	end
	return true
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

WorldService.Mirror = Config.Mirror

local function flat(p: Vector3): Vector3
	return Vector3.new(p.X, 0, p.Z)
end

local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local length = ab:Dot(ab)
	if length < 0.001 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / length, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

local function strip(a: Vector3, b: Vector3, width: number, height: number, y: number, color: Color3, material: Enum.Material, parent: Instance)
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	return part({
		Size = Vector3.new(width, height, length),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0)),
		Color = color,
		Material = material,
		CanCollide = false,
		Parent = parent,
	})
end

---------------------------------------------------------------- Licht

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(80, 90, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.22
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(210, 230, 220)
	atmosphere.Decay = Color3.fromRGB(80, 110, 120)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 0.8
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 1.7
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(250, 255, 245)
	color.Parent = Lighting
end

---------------------------------------------------------------- Boden, Rand, Lanes, Fluss

local function buildGround(parent: Instance)
	local size = HALF * 2 + 40
	part({ Name = "Ground", Size = Vector3.new(size, 8, size), Position = Vector3.new(0, -4, 0), Color = GRASS, Material = Enum.Material.Grass, Parent = parent })
	-- Klippen rundherum
	local rng = Random.new(3)
	for side = 1, 4 do
		for i = -10, 10 do
			local along = i * 19 + rng:NextNumber(-4, 4)
			local out = HALF + 14 + rng:NextNumber(-3, 5)
			local position = if side == 1 then Vector3.new(along, 0, -out) elseif side == 2 then Vector3.new(along, 0, out) elseif side == 3 then Vector3.new(-out, 0, along) else Vector3.new(out, 0, along)
			local height = rng:NextNumber(14, 26)
			local width = rng:NextNumber(18, 28)
			part({
				Size = Vector3.new(width, height, width),
				CFrame = CFrame.new(position + Vector3.new(0, height / 2 - 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6), rng:NextNumber(-0.15, 0.15)),
				Color = ROCK:Lerp(Color3.fromRGB(80, 74, 70), rng:NextNumber()),
				Material = Enum.Material.Slate,
				Parent = parent,
			})
		end
	end
	-- Unsichtbare Waende am Rand
	local wallHeight = 60
	for _, info in {
		{ Vector3.new(0, wallHeight / 2, -HALF - 3), Vector3.new(size, wallHeight, 2) },
		{ Vector3.new(0, wallHeight / 2, HALF + 3), Vector3.new(size, wallHeight, 2) },
		{ Vector3.new(-HALF - 3, wallHeight / 2, 0), Vector3.new(2, wallHeight, size) },
		{ Vector3.new(HALF + 3, wallHeight / 2, 0), Vector3.new(2, wallHeight, size) },
	} do
		part({ Name = "Wall", Size = info[2], Position = info[1], Transparency = 1, CanQuery = false, Parent = parent })
	end
end

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
WorldService.LaneSegments = laneSegments

local function buildLanes(parent: Instance)
	for _, segment in laneSegments() do
		local a, b = segment[1], segment[2]
		strip(a, b, MAP.LaneWidth, 0.3, 0.06, PATH, Enum.Material.Ground, parent)
		disc(b + Vector3.new(0, 0.06, 0), MAP.LaneWidth / 2, 0.3, PATH, Enum.Material.Ground, parent).CanCollide = false
		-- Steinkante
		local side = (b - a).Unit:Cross(Vector3.yAxis)
		for _, s in { -1, 1 } do
			strip(a + side * (MAP.LaneWidth / 2 + 0.6) * s, b + side * (MAP.LaneWidth / 2 + 0.6) * s, 1.2, 0.5, 0.15, Color3.fromRGB(160, 150, 130), Enum.Material.Cobblestone, parent)
		end
	end
end

-- Fluss von oben links nach unten rechts (Linie x = z)
local RIVER_A, RIVER_B = Vector3.new(-HALF - 10, 0, -HALF - 10), Vector3.new(HALF + 10, 0, HALF + 10)
local RIVER_WIDTH = 30

local function riverDistance(p: Vector3): number
	return distanceToSegment(flat(p), RIVER_A, RIVER_B)
end
WorldService.RiverDistance = riverDistance

local function buildRiver(parent: Instance)
	strip(RIVER_A, RIVER_B, RIVER_WIDTH + 6, 0.3, 0.04, Color3.fromRGB(150, 140, 110), Enum.Material.Sand, parent)
	local water = strip(RIVER_A, RIVER_B, RIVER_WIDTH, 0.4, 0.12, WATER, Enum.Material.Glass, parent)
	water.Transparency = 0.3
	water.Reflectance = 0.1
	water.Name = "River"
	-- Steine und Seerosen
	local rng = Random.new(21)
	for _ = 1, 40 do
		local t = rng:NextNumber(0, 1)
		local p = RIVER_A:Lerp(RIVER_B, t) + Vector3.new(1, 0, -1).Unit * rng:NextNumber(-RIVER_WIDTH / 2, RIVER_WIDTH / 2)
		if rng:NextNumber() < 0.5 then
			disc(p + Vector3.new(0, 0.35, 0), rng:NextNumber(0.8, 1.6), 0.1, Color3.fromRGB(90, 170, 90), Enum.Material.SmoothPlastic, parent).CanCollide = false
		else
			part({ Size = Vector3.new(2, 1, 2) * rng:NextNumber(0.6, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color = Color3.fromRGB(140, 140, 130), Material = Enum.Material.Pebble, CanCollide = false, Parent = parent })
		end
	end
end

local function buildPit(center: Vector3, color: Color3, parent: Instance)
	disc(center + Vector3.new(0, 0.2, 0), 24, 0.3, Color3.fromRGB(120, 104, 84), Enum.Material.Ground, parent).CanCollide = false
	disc(center + Vector3.new(0, 0.25, 0), 18, 0.3, color:Lerp(Color3.fromRGB(80, 70, 60), 0.6), Enum.Material.Slate, parent).CanCollide = false
	-- Felsring mit Eingang zum Fluss
	local toRiver = (Vector3.zero - center)
	local riverDir = Vector3.new(toRiver.X, 0, toRiver.Z).Unit
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local perpendicular = Vector3.new(-1, 0, 1).Unit
		local openRiver = math.abs(direction:Dot(perpendicular)) > 0.8
		if math.abs(direction:Dot(riverDir)) > 0.85 or openRiver then
			continue
		end
		local p = center + direction * 27
		markBlocked(part({ Size = Vector3.new(8, 9, 6), CFrame = CFrame.lookAt(p + Vector3.new(0, 4, 0), center + Vector3.new(0, 4, 0)), Color = ROCK, Material = Enum.Material.Slate, Parent = parent }))
	end
end

---------------------------------------------------------------- Dschungel: Waende mit Pfaden

local function campPositions()
	local list = {}
	for team = 1, 2 do
		for _, camp in MAP.Camps do
			table.insert(list, Config.Mirror(camp.Position, team))
		end
	end
	for _, camp in MAP.River do
		table.insert(list, camp.Position)
	end
	table.insert(list, MAP.DragonPit)
	table.insert(list, MAP.BaronPit)
	return list
end

-- Freie Pfade durch den Dschungel (fuer Dawn, Dusk gespiegelt)
local JUNGLE_PATHS = {
	{ Vector3.new(-150, 0, -22), Vector3.new(-124, 0, -22), Vector3.new(-98, 0, 4), Vector3.new(-84, 0, 36), Vector3.new(-50, 0, 50) },
	{ Vector3.new(-98, 0, 4), Vector3.new(-62, 0, -18), Vector3.new(-40, 0, -40) },
	{ Vector3.new(-124, 0, -22), Vector3.new(-100, 0, -60), Vector3.new(-76, 0, -76) },
	{ Vector3.new(-84, 0, 36), Vector3.new(-118, 0, 70), Vector3.new(-128, 0, 100) },
	{ Vector3.new(40, 0, 150), Vector3.new(40, 0, 124), Vector3.new(4, 0, 100), Vector3.new(-26, 0, 74), Vector3.new(-50, 0, 50) },
	{ Vector3.new(4, 0, 100), Vector3.new(18, 0, 62), Vector3.new(40, 0, 40) },
	{ Vector3.new(40, 0, 124), Vector3.new(60, 0, 100), Vector3.new(76, 0, 76) },
	{ Vector3.new(-26, 0, 74), Vector3.new(-70, 0, 118), Vector3.new(-100, 0, 128) },
	{ Vector3.new(-40, 0, -40), Vector3.new(-76, 0, -76), Vector3.new(-110, 0, -132) },
	{ Vector3.new(40, 0, 40), Vector3.new(76, 0, 76), Vector3.new(132, 0, 110) },
}

local function pathSegments()
	local segments = {}
	for team = 1, 2 do
		for _, path in JUNGLE_PATHS do
			for i = 1, #path - 1 do
				table.insert(segments, { Config.Mirror(path[i], team), Config.Mirror(path[i + 1], team) })
			end
		end
	end
	return segments
end

local function tree(position: Vector3, rng: Random, parent: Instance, scale: number)
	local height = rng:NextNumber(8, 13) * scale
	part({ Size = Vector3.new(1.8, height, 1.8) * Vector3.new(scale, 1, scale), Position = position + Vector3.new(0, height / 2, 0), Color = Color3.fromRGB(96, 70, 50), Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	local tint = rng:NextNumber()
	local leaves = if tint < 0.7 then GRASS_DARK elseif tint < 0.9 then Color3.fromRGB(70, 128, 70) else Color3.fromRGB(200, 150, 80)
	for i = 0, 2 do
		local size = ((3 - i) * 3 + rng:NextNumber(0, 1.5)) * scale
		part({
			Size = Vector3.new(size, size * 0.7, size),
			CFrame = CFrame.new(position + Vector3.new(0, height + i * 2.6 * scale - 1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
			Color = leaves,
			Material = Enum.Material.Grass,
			CanCollide = false,
			CastShadow = i == 0,
			Parent = parent,
		})
	end
end

local function inBase(p: Vector3): boolean
	return (p - Vector3.new(-HALF, 0, HALF)).Magnitude < 92 or (p - Vector3.new(HALF, 0, -HALF)).Magnitude < 92
end

local function buildJungle(parent: Instance)
	local rng = Random.new(5)
	local camps = campPositions()
	local paths = pathSegments()
	local lanes = laneSegments()
	local walls = Instance.new("Folder")
	walls.Name = "JungleWalls"
	walls.Parent = parent
	local step = 9
	for x = -HALF + 4, HALF - 4, step do
		for z = -HALF + 4, HALF - 4, step do
			local p = Vector3.new(x + rng:NextNumber(-2, 2), 0, z + rng:NextNumber(-2, 2))
			local ok = not inBase(p) and riverDistance(p) > RIVER_WIDTH / 2 + 7
			if ok then
				for _, segment in lanes do
					if distanceToSegment(p, segment[1], segment[2]) < MAP.LaneWidth / 2 + 8 then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, segment in paths do
					if distanceToSegment(p, segment[1], segment[2]) < 10 then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, camp in camps do
					if (p - camp).Magnitude < 22 then
						ok = false
						break
					end
				end
			end
			if ok and Config.BrushAt(p) then
				ok = false
			end
			if ok and math.noise(x / 40, z / 40, 0.3) > -0.25 then
				-- Unsichtbarer Block fuer Kollision und Wegfindung, darauf Baeume und Felsen
				markBlocked(part({ Name = "Block", Size = Vector3.new(step + 0.5, 10, step + 0.5), Position = p + Vector3.new(0, 5, 0), Transparency = 1, Parent = walls }))
				if rng:NextNumber() < 0.65 then
					tree(p, rng, parent, rng:NextNumber(0.9, 1.3))
				else
					local size = rng:NextNumber(5, 9)
					part({
						Size = Vector3.new(size * 1.3, size, size),
						CFrame = CFrame.new(p + Vector3.new(0, size * 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), 0),
						Color = ROCK:Lerp(Color3.fromRGB(150, 140, 120), rng:NextNumber()),
						Material = Enum.Material.Slate,
						CanCollide = false,
						Parent = parent,
					})
				end
			end
		end
	end
	-- Lagerplaetze
	for _, camp in camps do
		disc(camp + Vector3.new(0, 0.07, 0), 10, 0.3, Color3.fromRGB(130, 116, 90), Enum.Material.Ground, parent).CanCollide = false
	end
end

local function buildBrush(parent: Instance)
	local rng = Random.new(8)
	for _, brush in MAP.Brush do
		local center, size, angle = brush[1], brush[2], brush[3]
		local frame = CFrame.new(center) * CFrame.Angles(0, math.rad(angle), 0)
		part({ Name = "BrushFloor", Size = Vector3.new(size.X, 0.3, size.Z), CFrame = frame * CFrame.new(0, 0.1, 0), Color = Color3.fromRGB(46, 104, 52), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
		local count = math.floor(size.X * size.Z / 9)
		for _ = 1, count do
			local local_ = Vector3.new(rng:NextNumber(-size.X / 2, size.X / 2), 0, rng:NextNumber(-size.Z / 2, size.Z / 2))
			local height = rng:NextNumber(3.2, 4.6)
			local blade = part({
				Name = "Grass",
				Size = Vector3.new(0.5, height, rng:NextNumber(1.6, 2.6)),
				CFrame = frame * CFrame.new(local_ + Vector3.new(0, height / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6), rng:NextNumber(-0.25, 0.25)),
				Color = BRUSH:Lerp(Color3.fromRGB(110, 170, 80), rng:NextNumber()),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = parent,
			})
			CollectionService:AddTag(blade, "Brush")
		end
	end
end

---------------------------------------------------------------- Basen

local function buildBase(team: number, parent: Instance)
	local info = Config.Teams[team]
	local floor = if team == 1 then Color3.fromRGB(190, 200, 214) else Color3.fromRGB(200, 170, 160)
	local trim = info.Color
	local corner = Config.Mirror(Vector3.new(-HALF, 0, HALF), team)
	local fountain = MAP.Fountain[team]
	-- Steinboden der Basis
	disc(corner + Vector3.new(0, 0.05, 0), 84, 0.3, floor, Enum.Material.Slate, parent).CanCollide = false
	disc(corner + Vector3.new(0, 0.08, 0), 80, 0.3, floor:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Cobblestone, parent).CanCollide = false
	-- Mauer mit drei Ausgaengen (Top, Mid, Bot)
	local exits = { -71, -45, -19 }
	for degrees = -88, -2, 4 do
		local open = false
		for _, exit in exits do
			if math.abs(degrees - exit) <= 10 then
				open = true
			end
		end
		if not open then
			local angle = math.rad(degrees)
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			if team == 2 then
				direction = -direction
			end
			local p = corner + direction * 86
			markBlocked(part({ Size = Vector3.new(7, 7, 3), CFrame = CFrame.lookAt(p + Vector3.new(0, 3.5, 0), corner + Vector3.new(0, 3.5, 0)), Color = STONE, Material = Enum.Material.Cobblestone, Parent = parent }))
			part({ Size = Vector3.new(7.4, 0.8, 3.4), CFrame = CFrame.lookAt(p + Vector3.new(0, 7.2, 0), corner + Vector3.new(0, 7.2, 0)), Color = trim, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		end
	end
	-- Brunnen-Plattform mit Laden
	disc(fountain + Vector3.new(0, 0.2, 0), MAP.FountainRadius, 0.6, floor:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Marble, parent).CanCollide = false
	local ring = disc(fountain + Vector3.new(0, 0.3, 0), MAP.FountainRadius + 0.6, 0.4, trim, Enum.Material.Neon, parent)
	ring.CanCollide = false
	ring.Transparency = 0.3
	disc(fountain + Vector3.new(0, 0.35, 0), MAP.FountainRadius - 0.6, 0.45, floor:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Marble, parent).CanCollide = false
	disc(fountain + Vector3.new(0, 1.2, 0), 4.5, 2.4, STONE, Enum.Material.Marble, parent)
	disc(fountain + Vector3.new(0, 2.3, 0), 3.8, 0.4, WATER, Enum.Material.Glass, parent)
	local crystal = part({ Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(fountain + Vector3.new(0, 6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = trim, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	CollectionService:AddTag(crystal, "Spin")
	-- Laden-Stand
	local shop = fountain + Config.Mirror(Vector3.new(-6, 0, -10), team)
	part({ Size = Vector3.new(6, 3, 4), Position = shop + Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(130, 90, 60), Material = Enum.Material.WoodPlanks, Parent = parent })
	part({ Size = Vector3.new(7, 0.4, 5), Position = shop + Vector3.new(0, 5.2, 0), Color = trim, Material = Enum.Material.Fabric, CanCollide = false, Parent = parent })
	for _, sx in { -3, 3 } do
		part({ Size = Vector3.new(0.4, 5, 0.4), Position = shop + Vector3.new(sx, 2.5, 2), Color = Color3.fromRGB(90, 60, 40), CanCollide = false, Parent = parent })
	end
	local coin = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), CFrame = CFrame.new(shop + Vector3.new(0, 7, 0)), Color = Color3.fromRGB(255, 210, 70), Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	CollectionService:AddTag(coin, "Spin")
	-- Fahnen
	for i = 1, 4 do
		local pole = corner + Config.Mirror(Vector3.new(12 + i * 9, 0, -12 - (5 - i) * 9), team)
		part({ Size = Vector3.new(0.8, 14, 0.8), Position = pole + Vector3.new(0, 7, 0), Color = Color3.fromRGB(70, 60, 60), Parent = parent })
		part({ Size = Vector3.new(0.2, 6, 4), Position = pole + Vector3.new(0, 10.5, -2.2), Color = trim, Material = Enum.Material.Fabric, CanCollide = false, Parent = parent })
	end
end

function WorldService:Init(services)
	self.Services = services
end

function WorldService:Build()
	setupLighting()
	local old = workspace:FindFirstChild("Arena")
	if old then
		old:Destroy()
	end
	table.clear(blocked)
	world = Instance.new("Folder")
	world.Name = "Arena"
	world.Parent = workspace
	buildGround(world)
	buildLanes(world)
	buildRiver(world)
	buildPit(MAP.DragonPit, Color3.fromRGB(255, 120, 60), world)
	buildPit(MAP.BaronPit, Color3.fromRGB(150, 60, 220), world)
	buildBrush(world)
	buildJungle(world)
	buildBase(1, world)
	buildBase(2, world)
	for _, name in { "Units", "Effects" } do
		if not workspace:FindFirstChild(name) then
			local folder = Instance.new("Folder")
			folder.Name = name
			folder.Parent = workspace
		end
	end
	arenaFolder = world
	-- Spawn-Punkt, damit Roblox nicht am Ursprung spawnt
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Size = Vector3.new(4, 1, 4)
	spawnLocation.Position = MAP.Fountain[1] + Vector3.new(0, 0.5, -6)
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

-- Teil an ein Model haengen. Bewegliche Modelle (Minions, Monster) schweissen alles an den Root.
local function attach(model: Model, root: BasePart, props, welded: boolean?): BasePart
	props.Parent = model
	props.CanCollide = false
	local p = part(props)
	if welded then
		p.Anchored = false
		p.Massless = true
		weld(root, p)
	end
	return p
end

function WorldService:MakeTower(team: number, tier: number, position: Vector3): Model
	local info = Config.Teams[team]
	local root = disc(position + Vector3.new(0, 1.5, 0), 5.5, 3, STONE, Enum.Material.Slate, nil)
	local model = newModel(info.Name .. "Tower" .. tier, root)
	local height = 13 + math.min(tier, 3) * 1.5
	local body = if team == 1 then Color3.fromRGB(200, 210, 225) else Color3.fromRGB(150, 110, 110)
	attach(model, root, { Size = Vector3.new(4.5, height, 4.5), Position = position + Vector3.new(0, 3 + height / 2, 0), Color = body, Material = Enum.Material.Slate })
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		attach(model, root, { Size = Vector3.new(1.2, height * 0.6, 1.2), Position = position + corner * 2.8 + Vector3.new(0, 3 + height * 0.3, 0), Color = STONE_DARK, Material = Enum.Material.Metal })
	end
	for _, y in { 5, 3 + height - 1.5 } do
		attach(model, root, { Size = Vector3.new(5.2, 0.8, 5.2), Position = position + Vector3.new(0, y, 0), Color = info.Color, Material = Enum.Material.Neon })
	end
	attach(model, root, { Size = Vector3.new(7, 1.2, 7), Position = position + Vector3.new(0, 3 + height + 0.6, 0), Color = STONE_DARK, Material = Enum.Material.Slate })
	local crystal = attach(model, root, {
		Size = Vector3.new(3, 4, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 3 + height + 4.5, 0)) * CFrame.Angles(0, math.rad(45), 0),
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
	-- Reichweite des Turms am Boden
	local range = disc(position + Vector3.new(0, 0.12, 0), Config.Structures.Tower1.Range, 0.1, info.Color, Enum.Material.Neon, model)
	range.Name = "RangeRing"
	range.Transparency = 0.93
	range.CanQuery = false
	model:SetAttribute("ShotHeight", 3 + height + 4.5)
	model.Parent = self:UnitsFolder()
	return model
end

function WorldService:MakeInhibitor(team: number, position: Vector3): Model
	local info = Config.Teams[team]
	local root = disc(position + Vector3.new(0, 1, 0), 6, 2, STONE, Enum.Material.Marble, nil)
	local model = newModel(info.Name .. "Inhibitor", root)
	attach(model, root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = CFrame.new(position + Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = info.Dark, Material = Enum.Material.Slate })
	local crystal = attach(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 5, Position = position + Vector3.new(0, 6, 0), Color = info.Color, Material = Enum.Material.Neon, Transparency = 0.1 })
	crystal.Name = "Crystal"
	local ring = attach(model, root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 8, 8), CFrame = CFrame.new(position + Vector3.new(0, 6, 0)) * CFrame.Angles(math.rad(70), 0, math.rad(90)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.5 })
	CollectionService:AddTag(ring, "Spin")
	local light = Instance.new("PointLight")
	light.Color = info.Color
	light.Range = 20
	light.Brightness = 2
	light.Parent = crystal
	model:SetAttribute("ShotHeight", 6)
	model.Parent = self:UnitsFolder()
	return model
end

function WorldService:MakeNexus(team: number, position: Vector3): Model
	local info = Config.Teams[team]
	local root = disc(position + Vector3.new(0, 1.5, 0), 10, 3, STONE, Enum.Material.Marble, nil)
	local model = newModel(info.Name .. "Nexus", root)
	attach(model, root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 16, 16), CFrame = CFrame.new(position + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = info.Dark, Material = Enum.Material.Slate })
	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local p = position + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6)
		attach(model, root, { Size = Vector3.new(1.4, 9, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 7, 0)) * CFrame.Angles(math.rad(12) * math.cos(angle), 0, math.rad(12) * math.sin(angle)), Color = STONE_DARK, Material = Enum.Material.Metal })
	end
	local crystal = attach(model, root, {
		Size = Vector3.new(7, 10, 7),
		CFrame = CFrame.new(position + Vector3.new(0, 13, 0)) * CFrame.Angles(0, math.rad(45), 0),
		Color = info.Color,
		Material = Enum.Material.Glass,
		Transparency = 0.1,
	})
	crystal.Name = "Crystal"
	CollectionService:AddTag(crystal, "Spin")
	attach(model, root, { Size = Vector3.new(3.4, 5, 3.4), CFrame = crystal.CFrame, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	local barrier = attach(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 26, Position = position + Vector3.new(0, 8, 0), Color = info.Color, Material = Enum.Material.ForceField, Transparency = 0 })
	barrier.Name = "Barrier"
	barrier.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = info.Color
	light.Range = 30
	light.Brightness = 2
	light.Parent = crystal
	model:SetAttribute("ShotHeight", 13)
	model.Parent = self:UnitsFolder()
	return model
end

-- Minions: kleine Kristall-Soldaten. Nur der Root ist verankert, der Rest haengt per Weld daran
function WorldService:MakeMinion(team: number, kind: string, position: Vector3): Model
	local info = Config.Teams[team]
	local size = if kind == "Super" then 4.6 elseif kind == "Siege" then 4.2 elseif kind == "Caster" then 2.2 elseif kind == "Herald" then 7 else 2.6
	local body = if team == 1 then Color3.fromRGB(200, 220, 255) else Color3.fromRGB(255, 200, 200)
	if kind == "Herald" then
		body = Color3.fromRGB(170, 90, 255)
	end
	local root = part({ Size = Vector3.new(size, size, size), Position = position + Vector3.new(0, size / 2 + 0.2, 0), Color = body, CanCollide = false, CanQuery = true, CastShadow = true })
	local model = newModel(info.Name .. kind, root)
	attach(model, root, { Size = Vector3.new(size * 0.8, size * 0.3, 0.2), CFrame = root.CFrame * CFrame.new(0, size * 0.15, -size / 2 - 0.05), Color = info.Color, Material = Enum.Material.Neon }, true)
	attach(model, root, { Size = Vector3.new(size * 1.04, size * 0.18, size * 1.04), CFrame = root.CFrame * CFrame.new(0, -size * 0.3, 0), Color = info.Dark }, true)
	if kind == "Caster" then
		local orb = attach(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1, CFrame = root.CFrame * CFrame.new(size * 0.8, size * 0.5, 0), Color = info.Color, Material = Enum.Material.Neon }, true)
		orb.Name = "Orb"
	elseif kind == "Siege" then
		attach(model, root, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1.4, 1.4), CFrame = root.CFrame * CFrame.new(0, size * 0.55, -0.6) * CFrame.Angles(0, math.rad(90), 0), Color = STONE_DARK, Material = Enum.Material.Metal }, true)
	elseif kind == "Super" then
		for _, sx in { -1, 1 } do
			attach(model, root, { Size = Vector3.new(1.2, 2.4, 1.2), CFrame = root.CFrame * CFrame.new(sx * size * 0.6, size * 0.4, 0) * CFrame.Angles(0, 0, sx * math.rad(-30)), Color = info.Color, Material = Enum.Material.Neon }, true)
		end
		attach(model, root, { Size = Vector3.new(0.6, 3.6, 0.6), CFrame = root.CFrame * CFrame.new(size * 0.7, 0, -0.8) * CFrame.Angles(math.rad(-25), 0, 0), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Metal }, true)
	elseif kind == "Herald" then
		local eye = attach(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = root.CFrame * CFrame.new(0, size * 0.2, -size / 2), Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.Neon }, true)
		eye.Name = "Eye"
	else
		attach(model, root, { Size = Vector3.new(0.5, 2.2, 0.5), CFrame = root.CFrame * CFrame.new(size * 0.65, 0.3, -0.4) * CFrame.Angles(math.rad(-20), 0, 0), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal }, true)
	end
	model.Parent = self:UnitsFolder()
	return model
end

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function WorldService:MakeMonster(id: string, position: Vector3, colorOverride: Color3?): Model
	local info = Config.Monsters[id]
	local color = colorOverride or info.Color
	local size = info.Size or 4
	local shape = info.Shape or "Blob"
	local root = part({ Size = Vector3.new(size, size * 0.8, size), Position = position + Vector3.new(0, size * 0.4 + 0.2, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	local model = newModel(info.Name, root)
	local function add(props)
		return attach(model, root, props, true)
	end
	local function eyes(y: number, z: number, spread: number, eyeSize: number, glow: Color3?)
		for _, sx in { -1, 1 } do
			add({ Size = Vector3.one * eyeSize, Position = root.Position + Vector3.new(sx * spread, y, -z), Color = glow or Color3.fromRGB(255, 250, 200), Material = Enum.Material.Neon })
		end
	end
	if shape == "Golem" then
		add({ Size = Vector3.new(size * 0.7, size * 0.6, size * 0.7), Position = root.Position + Vector3.new(0, size * 0.65, 0), Color = darker(color, 0.25), Material = Enum.Material.Slate })
		for _, sx in { -1, 1 } do
			add({ Size = Vector3.new(size * 0.32, size, size * 0.32), Position = root.Position + Vector3.new(sx * size * 0.68, 0, 0), Color = darker(color, 0.15), Material = Enum.Material.Slate })
		end
		eyes(size * 0.75, size * 0.36, 0.9, 0.7)
		local crown = add({ Size = Vector3.new(1.6, 2.4, 1.6), CFrame = CFrame.new(root.Position + Vector3.new(0, size * 1.2, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = color, Material = Enum.Material.Neon })
		crown.Name = "Crown"
	elseif shape == "Blob" then
		root.Shape = Enum.PartType.Ball
		root.Size = Vector3.one * size
		root.Material = Enum.Material.SmoothPlastic
		eyes(size * 0.25, size * 0.42, 1.1, 1)
		add({ Size = Vector3.new(size * 0.6, 0.4, 0.4), Position = root.Position + Vector3.new(0, -size * 0.05, -size * 0.48), Color = darker(color, 0.5) })
	elseif shape == "Beast" then
		root.Size = Vector3.new(size * 0.7, size * 0.6, size * 1.2)
		add({ Size = Vector3.new(size * 0.55, size * 0.5, size * 0.55), Position = root.Position + Vector3.new(0, size * 0.25, -size * 0.7), Color = darker(color, 0.1) })
		for _, sx in { -1, 1 } do
			add({ Size = Vector3.new(0.3, 0.8, 0.4), Position = root.Position + Vector3.new(sx * size * 0.18, size * 0.6, -size * 0.7), Color = darker(color, 0.3) })
		end
		eyes(size * 0.32, size * 0.98, size * 0.14, 0.35, Color3.fromRGB(120, 230, 255))
	elseif shape == "Bird" then
		root.Size = Vector3.new(size * 0.7, size * 0.7, size)
		add({ Size = Vector3.new(size * 0.4, size * 0.4, size * 0.5), Position = root.Position + Vector3.new(0, size * 0.45, -size * 0.5), Color = color })
		add({ Size = Vector3.new(0.3, 0.3, size * 0.4), Position = root.Position + Vector3.new(0, size * 0.42, -size * 0.85), Color = Color3.fromRGB(255, 200, 80) })
		for _, sx in { -1, 1 } do
			add({ Size = Vector3.new(0.2, size * 0.5, size * 0.6), CFrame = CFrame.new(root.Position + Vector3.new(sx * size * 0.4, size * 0.1, 0)) * CFrame.Angles(0, 0, sx * 0.5), Color = darker(color, 0.2) })
		end
	elseif shape == "Rock" then
		root.Material = Enum.Material.Rock
		add({ Size = Vector3.new(size * 0.8, size * 0.5, size * 0.8), CFrame = CFrame.new(root.Position + Vector3.new(0, size * 0.5, 0)) * CFrame.Angles(0.2, 0.6, 0.1), Color = darker(color, 0.15), Material = Enum.Material.Rock })
		eyes(size * 0.3, size * 0.42, 0.7, 0.5, Color3.fromRGB(255, 160, 60))
	elseif shape == "Crab" then
		root.Size = Vector3.new(size, size * 0.4, size * 0.8)
		add({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size) * 0.8, Position = root.Position + Vector3.new(0, size * 0.2, 0), Color = darker(color, 0.1), Material = Enum.Material.SmoothPlastic })
		for _, sx in { -1, 1 } do
			add({ Size = Vector3.new(1.2, 0.6, 0.8), Position = root.Position + Vector3.new(sx * size * 0.7, 0, -size * 0.3), Color = color })
		end
		eyes(size * 0.55, size * 0.25, 0.5, 0.4)
	elseif shape == "Dragon" then
		root.Size = Vector3.new(size * 0.7, size * 0.6, size * 1.2)
		add({ Size = Vector3.new(size * 0.4, size * 0.4, size * 0.6), Position = root.Position + Vector3.new(0, size * 0.4, -size * 0.75), Color = darker(color, 0.1) })
		for _, sx in { -1, 1 } do
			local wing = add({ Size = Vector3.new(size * 0.9, 0.3, size * 0.6), CFrame = CFrame.new(root.Position + Vector3.new(sx * size * 0.75, size * 0.35, 0)) * CFrame.Angles(0, 0, sx * 0.4), Color = darker(color, 0.3), Material = Enum.Material.Fabric })
			wing.Name = "Wing"
			add({ Size = Vector3.new(0.4, size * 0.4, 0.4), CFrame = CFrame.new(root.Position + Vector3.new(sx * size * 0.15, size * 0.65, -size * 0.85)) * CFrame.Angles(0.5, 0, 0), Color = Color3.fromRGB(240, 230, 210) })
		end
		add({ Size = Vector3.new(size * 0.2, size * 0.2, size * 0.9), Position = root.Position + Vector3.new(0, 0, size * 0.95), Color = color })
		eyes(size * 0.5, size * 1.05, size * 0.12, 0.6)
	elseif shape == "Herald" then
		root.Shape = Enum.PartType.Ball
		root.Size = Vector3.one * size
		root.Material = Enum.Material.Slate
		local eye = add({ Shape = Enum.PartType.Ball, Size = Vector3.one * size * 0.45, Position = root.Position + Vector3.new(0, size * 0.1, -size * 0.32), Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.Neon })
		eye.Name = "Eye"
		for i = 0, 5 do
			local angle = i / 6 * math.pi * 2
			add({ Size = Vector3.new(0.8, size * 0.6, 0.8), CFrame = CFrame.new(root.Position + Vector3.new(math.cos(angle) * size * 0.45, size * 0.35, math.sin(angle) * size * 0.45)) * CFrame.Angles(math.sin(angle) * 0.6, 0, -math.cos(angle) * 0.6), Color = darker(color, 0.2), Material = Enum.Material.Neon })
		end
	elseif shape == "Baron" then
		root.Size = Vector3.new(size, size * 0.8, size)
		root.Material = Enum.Material.Slate
		add({ Size = Vector3.new(size * 0.55, size * 0.9, size * 0.5), CFrame = CFrame.new(root.Position + Vector3.new(0, size * 0.75, -size * 0.25)) * CFrame.Angles(-0.3, 0, 0), Color = darker(color, 0.15), Material = Enum.Material.Slate })
		add({ Size = Vector3.new(size * 0.5, size * 0.35, size * 0.6), Position = root.Position + Vector3.new(0, size * 1.25, -size * 0.55), Color = color })
		eyes(size * 1.3, size * 0.86, size * 0.12, 1, Color3.fromRGB(255, 120, 255))
		for i = 0, 4 do
			add({ Size = Vector3.new(0.9, size * 0.5, 0.9), CFrame = CFrame.new(root.Position + Vector3.new((i - 2) * size * 0.2, size * 0.75, size * 0.2)) * CFrame.Angles(0.4, 0, 0), Color = Color3.fromRGB(230, 120, 255), Material = Enum.Material.Neon })
		end
		for _, sx in { -1, 1 } do
			add({ Size = Vector3.new(size * 0.25, size * 0.25, size * 1.1), CFrame = CFrame.new(root.Position + Vector3.new(sx * size * 0.75, 0, -size * 0.3)) * CFrame.Angles(0, sx * 0.4, 0), Color = darker(color, 0.3), Material = Enum.Material.Slate })
		end
	end
	model.Parent = self:UnitsFolder()
	return model
end

function WorldService:MakeWard(team: number, position: Vector3): Model
	local info = Config.Teams[team]
	local root = part({ Size = Vector3.new(1, 3.2, 1), Position = position + Vector3.new(0, 1.6, 0), Color = Color3.fromRGB(90, 80, 70), Material = Enum.Material.Wood, CanCollide = false })
	local model = newModel(info.Name .. "Ward", root)
	local eye = attach(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, Position = position + Vector3.new(0, 3.6, 0), Color = Color3.fromRGB(255, 230, 110), Material = Enum.Material.Neon })
	eye.Name = "Eye"
	local light = Instance.new("PointLight")
	light.Color = info.Color
	light.Range = 10
	light.Brightness = 1
	light.Parent = eye
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
	Axe = { { Size = Vector3.new(0.35, 6, 0.35), Offset = CFrame.new(0, 0.8, -0.4) }, { Size = Vector3.new(0.3, 2.2, 2.4), Offset = CFrame.new(0, 3.4, -1.2), Accent = true }, { Size = Vector3.new(0.32, 0.4, 2.6), Offset = CFrame.new(0, 2.3, -1.3), Accent = true, Glow = true } },
	Lantern = { { Size = Vector3.new(0.2, 2.2, 0.2), Offset = CFrame.new(0, -1.4, -0.2) }, { Size = Vector3.new(1.3, 1.6, 1.3), Offset = CFrame.new(0, -2.8, -0.2), Accent = true, Glow = true } },
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
