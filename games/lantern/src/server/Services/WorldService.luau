-- Baut die Stadt Lanternhold (Spawn, Laternenturm, Dungeon-Portale, Klassenschrein, Schmiede, Bestenliste)
-- und setzt das Daemmerungs-Licht, das den Stil des Spiels praegt: tiefes Blau + warmes Laternenlicht.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = { Services = nil :: any, Portals = {}, SpawnPosition = Vector3.new(0, 3, 34) }

local STONE = Color3.fromRGB(96, 98, 118)
local DARK_STONE = Color3.fromRGB(62, 62, 82)
local WOOD = Color3.fromRGB(110, 76, 52)
local AMBER = Color3.fromRGB(255, 184, 74)
local GRASS = Color3.fromRGB(58, 92, 70)

local world: Folder

function WorldService:Init(services)
	self.Services = services
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	if not props.Parent then
		p.Parent = world
	end
	return p
end
WorldService.Part = part

local function light(parent: Instance, color: Color3, range: number, brightness: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end
WorldService.Light = light

-- Gluehwuermchen: kleine warme Lichtpunkte, die langsam schweben (Markenzeichen der Stadt)
local function fireflies(parent: BasePart, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Rate = rate
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, 0.3, 0)
	emitter.Parent = parent
end
WorldService.Fireflies = fireflies

local function label(parent: BasePart, text: string, color: Color3, size: UDim2, offset: Vector3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.LuckiestGuy
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.TextStrokeColor3 = Color3.fromRGB(14, 16, 34)
	textLabel.TextStrokeTransparency = 0
	textLabel.Text = text
	textLabel.Parent = gui
	return gui
end
WorldService.Label = label

local function prompt(parent: BasePart, name: string, action: string, object: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Parent = parent
end

---------------------------------------------------------------- Licht

local function setupLighting()
	Lighting.ClockTime = 19.6
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(70, 76, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(96, 100, 150)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 200, 150)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(110, 110, 170)
	atmosphere.Decay = Color3.fromRGB(70, 56, 110)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.7
	bloom.Size = 26
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.12
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(255, 246, 236)
	color.Parent = Lighting
end

---------------------------------------------------------------- Bausteine

local function lanternPost(position: Vector3, height: number?)
	local h = height or 9
	part({ Name = "Post", Size = Vector3.new(0.8, h, 0.8), Position = position + Vector3.new(0, h / 2, 0), Color = DARK_STONE, Material = Enum.Material.Slate })
	part({ Name = "Arm", Size = Vector3.new(0.4, 0.4, 2.4), Position = position + Vector3.new(0, h - 0.3, 1), Color = DARK_STONE })
	local glass = part({
		Name = "Lantern",
		Size = Vector3.new(1.4, 1.8, 1.4),
		Position = position + Vector3.new(0, h - 1.5, 2),
		Color = AMBER,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	part({ Name = "Cap", Size = Vector3.new(1.8, 0.4, 1.8), Position = glass.Position + Vector3.new(0, 1.1, 0), Color = DARK_STONE, CanCollide = false })
	light(glass, AMBER, 22, 1.6)
	glass:AddTag("Flicker")
end
WorldService.LanternPost = lanternPost

local function tree(position: Vector3, scale: number)
	part({ Name = "Trunk", Size = Vector3.new(1.4, 5, 1.4) * scale, Position = position + Vector3.new(0, 2.5 * scale, 0), Color = WOOD, Material = Enum.Material.Wood })
	for i = 1, 3 do
		local s = (7 - i * 1.6) * scale
		local cone = part({
			Name = "Leaves",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s * 0.9, s),
			Position = position + Vector3.new(0, (4 + i * 2.6) * scale, 0),
			Color = Color3.fromRGB(40 + i * 8, 92 + i * 10, 78 + i * 6),
			Material = Enum.Material.Grass,
		})
		cone.CastShadow = true
	end
end

local function cottage(position: Vector3, facing: number, roofColor: Color3)
	local cf = CFrame.new(position) * CFrame.Angles(0, math.rad(facing), 0)
	local w, d, h = 16, 12, 9
	local body = part({ Name = "House", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = Color3.fromRGB(214, 196, 168), Material = Enum.Material.Plaster })
	for _, side in { -1, 1 } do
		part({
			Name = "Roof",
			Size = Vector3.new(w + 2, 1, d * 0.62),
			CFrame = cf * CFrame.new(0, h + 2.6, side * d * 0.27) * CFrame.Angles(math.rad(side * 33), 0, 0),
			Color = roofColor,
			Material = Enum.Material.Slate,
		})
	end
	part({ Name = "Gable", Size = Vector3.new(w - 0.5, 4.6, 0.6), CFrame = cf * CFrame.new(0, h + 1.8, 0), Color = Color3.fromRGB(190, 170, 140), Material = Enum.Material.Plaster })
	part({ Name = "Door", Size = Vector3.new(3, 5.5, 0.4), CFrame = cf * CFrame.new(0, 2.75, -d / 2 - 0.1), Color = WOOD, Material = Enum.Material.Wood })
	for _, x in { -5, 5 } do
		local window = part({ Name = "Window", Size = Vector3.new(2.6, 2.6, 0.3), CFrame = cf * CFrame.new(x, 5, -d / 2 - 0.1), Color = AMBER, Material = Enum.Material.Neon })
		if x > 0 then
			light(window, AMBER, 14, 1.2)
		end
	end
	part({ Name = "Chimney", Size = Vector3.new(2, 5, 2), CFrame = cf * CFrame.new(w * 0.3, h + 3.5, d * 0.2), Color = DARK_STONE, Material = Enum.Material.Brick })
	return body
end

---------------------------------------------------------------- Stadt

local function buildTown()
	part({ Name = "Ground", Size = Vector3.new(640, 2, 640), Position = Vector3.new(0, -1, 0), Color = GRASS, Material = Enum.Material.Grass })
	local plaza = part({
		Name = "Plaza",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 150, 150),
		CFrame = CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(120, 116, 128),
		Material = Enum.Material.Cobblestone,
	})
	plaza.Name = "Plaza"
	part({
		Name = "PlazaRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 154, 154),
		CFrame = CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = DARK_STONE,
		Material = Enum.Material.Slate,
	})

	-- Laternenturm in der Mitte: das Wahrzeichen und Logo-Motiv
	part({ Name = "TowerBase", Size = Vector3.new(14, 3, 14), Position = Vector3.new(0, 1.5, 0), Color = DARK_STONE, Material = Enum.Material.Slate })
	part({ Name = "Tower", Size = Vector3.new(6, 26, 6), Position = Vector3.new(0, 16, 0), Color = STONE, Material = Enum.Material.Slate })
	for _, corner in { Vector3.new(-3.6, 0, -3.6), Vector3.new(3.6, 0, -3.6), Vector3.new(-3.6, 0, 3.6), Vector3.new(3.6, 0, 3.6) } do
		part({ Name = "Frame", Size = Vector3.new(1, 9, 1), Position = Vector3.new(0, 33.5, 0) + corner, Color = Color3.fromRGB(70, 56, 40), Material = Enum.Material.Metal })
	end
	local core = part({ Name = "GreatLantern", Size = Vector3.new(6, 8, 6), Position = Vector3.new(0, 33.5, 0), Color = AMBER, Material = Enum.Material.Neon, Transparency = 0.05 })
	core:AddTag("Flicker")
	light(core, AMBER, 60, 2.2, true)
	fireflies(core, 6)
	part({ Name = "Roof", Size = Vector3.new(9, 1.2, 9), Position = Vector3.new(0, 38.6, 0), Color = Color3.fromRGB(70, 56, 40), Material = Enum.Material.Metal })
	part({ Name = "Spire", Size = Vector3.new(2, 4, 2), Position = Vector3.new(0, 41, 0), Color = AMBER, Material = Enum.Material.Neon })
	label(core, "LANTERNHOLD", AMBER, UDim2.fromOffset(320, 60), Vector3.new(0, 10, 0))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TownSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 34)
	spawn.Color = DARK_STONE
	spawn.Material = Enum.Material.Slate
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = world
	WorldService.SpawnPosition = spawn.Position + Vector3.new(0, 3, 0)

	for i = 1, 14 do
		local angle = (i / 14) * math.pi * 2
		lanternPost(Vector3.new(math.cos(angle) * 68, 0, math.sin(angle) * 68))
	end

	-- Dungeon-Portale im Halbkreis im Norden
	local count = #Config.Dungeons
	for index, dungeon in Config.Dungeons do
		local angle = math.rad(-150 + (index - 1) * (120 / (count - 1)))
		local position = Vector3.new(math.cos(angle) * 96, 0, math.sin(angle) * 96)
		local cf = CFrame.lookAt(position, Vector3.new(0, 0, 0))
		local portal = Instance.new("Model")
		portal.Name = "Portal_" .. dungeon.Id
		portal.Parent = world
		for _, side in { -1, 1 } do
			part({ Name = "Pillar", Size = Vector3.new(3, 18, 3), CFrame = cf * CFrame.new(side * 8, 9, 0), Color = STONE, Material = Enum.Material.Slate, Parent = portal })
			local crystal = part({ Name = "Crystal", Size = Vector3.new(1.6, 3, 1.6), CFrame = cf * CFrame.new(side * 8, 19.8, 0) * CFrame.Angles(0, math.rad(45), 0), Color = dungeon.Accent, Material = Enum.Material.Neon, Parent = portal })
			crystal:AddTag("Spin")
		end
		part({ Name = "Arch", Size = Vector3.new(19, 3, 3.4), CFrame = cf * CFrame.new(0, 17.5, 0), Color = DARK_STONE, Material = Enum.Material.Slate, Parent = portal })
		local gate = part({
			Name = "Gate",
			Size = Vector3.new(13, 16, 0.6),
			CFrame = cf * CFrame.new(0, 8, 0),
			Color = dungeon.Accent,
			Material = Enum.Material.Neon,
			Transparency = 0.45,
			CanCollide = false,
			Parent = portal,
		})
		light(gate, dungeon.Accent, 24, 2)
		fireflies(gate, 3)
		local pad = part({
			Name = "Pad",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, 13, 13),
			CFrame = cf * CFrame.new(0, 0.3, -9) * CFrame.Angles(0, 0, math.rad(90)),
			Color = dungeon.Accent,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			CanCollide = false,
			Parent = portal,
		})
		pad:SetAttribute("Dungeon", index)
		local sign = label(gate, dungeon.Name:upper(), Color3.new(1, 1, 1), UDim2.fromOffset(260, 46), Vector3.new(0, 12.5, 0))
		sign.Name = "Sign"
		local level = label(gate, `LEVEL {dungeon.Level}+`, dungeon.Accent, UDim2.fromOffset(180, 30), Vector3.new(0, 10, 0))
		level.Name = "LevelSign"
		-- Dungeon des Tages: Schild wird vom ProgressService eingeschaltet
		local featuredSign = label(gate, "FEATURED: +50% GOLD & XP", Color3.fromRGB(255, 220, 90), UDim2.fromOffset(260, 30), Vector3.new(0, 15, 0))
		featuredSign.Name = "FeaturedSign"
		featuredSign.Enabled = false
		WorldService.Portals[index] = { Pad = pad, Position = pad.Position, Model = portal, Featured = featuredSign }
	end

	-- Klassenschrein im Westen
	local shrine = part({ Name = "ClassShrine", Size = Vector3.new(8, 3, 8), Position = Vector3.new(-56, 1.5, 26), Color = DARK_STONE, Material = Enum.Material.Slate })
	for i, key in Config.ClassOrder do
		local class = Config.Classes[key]
		local angle = (i / #Config.ClassOrder) * math.pi * 2
		local crystal = part({
			Name = "ClassCrystal",
			Size = Vector3.new(1.4, 4, 1.4),
			CFrame = CFrame.new(shrine.Position + Vector3.new(math.cos(angle) * 2.4, 4, math.sin(angle) * 2.4)) * CFrame.Angles(0, angle, math.rad(12)),
			Color = class.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		crystal:AddTag("Bob")
	end
	light(shrine, Color3.fromRGB(200, 170, 255), 18, 1.5)
	prompt(shrine, "ClassShrine", "Change Class", "Class Shrine")
	label(shrine, "CLASSES", Color3.fromRGB(220, 200, 255), UDim2.fromOffset(160, 36), Vector3.new(0, 8, 0))

	-- Schmiede im Osten
	local forge = part({ Name = "Forge", Size = Vector3.new(10, 6, 7), Position = Vector3.new(56, 3, 26), Color = Color3.fromRGB(80, 66, 60), Material = Enum.Material.Brick })
	local fire = part({ Name = "ForgeFire", Size = Vector3.new(5, 2.5, 3), Position = forge.Position + Vector3.new(0, 1, -3.4), Color = Color3.fromRGB(255, 120, 40), Material = Enum.Material.Neon, CanCollide = false })
	fire:AddTag("Flicker")
	light(fire, Color3.fromRGB(255, 130, 60), 24, 2.4)
	local flames = Instance.new("Fire")
	flames.Size = 4
	flames.Heat = 6
	flames.Color = Color3.fromRGB(255, 140, 50)
	flames.SecondaryColor = Color3.fromRGB(255, 220, 90)
	flames.Parent = fire
	local anvil = part({ Name = "Anvil", Size = Vector3.new(4, 2.4, 2), Position = forge.Position + Vector3.new(0, -1.8, -7.5), Color = Color3.fromRGB(50, 52, 60), Material = Enum.Material.Metal })
	prompt(anvil, "Forge", "Enhance Gear", "Forge")
	label(forge, "FORGE", Color3.fromRGB(255, 170, 90), UDim2.fromOffset(140, 36), Vector3.new(0, 7, 0))

	-- Bestenliste im Sueden
	local board = part({ Name = "Leaderboard", Size = Vector3.new(16, 20, 1), CFrame = CFrame.lookAt(Vector3.new(-30, 10, 60), Vector3.new(0, 10, 20)), Color = DARK_STONE, Material = Enum.Material.Slate })
	part({ Name = "BoardTrim", Size = Vector3.new(17, 1, 1.4), CFrame = board.CFrame * CFrame.new(0, 10.3, 0), Color = AMBER, Material = Enum.Material.Neon })
	WorldService.Leaderboard = board

	-- Haeuser, Baeume und Zaun-Laternen rund um den Platz
	local roofs = { Color3.fromRGB(70, 90, 150), Color3.fromRGB(150, 70, 70), Color3.fromRGB(70, 120, 100) }
	local houseSpots = { { 120, 40, -110 }, { 120, 110, -150 }, { -120, 40, 110 }, { -125, 110, 150 }, { 40, 135, 180 }, { -40, 135, 180 }, { 150, -40, -60 }, { -150, -40, 60 } }
	for i, spot in houseSpots do
		cottage(Vector3.new(spot[1], 0, spot[2]), spot[3], roofs[(i % #roofs) + 1])
	end
	local rng = Random.new(11)
	for _ = 1, 70 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(150, 300)
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		tree(position, rng:NextNumber(1.6, 2.8))
	end
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2 + 0.2
		local spot = part({ Name = "Fireflies", Size = Vector3.new(30, 6, 30), Position = Vector3.new(math.cos(angle) * 130, 4, math.sin(angle) * 130), Transparency = 1, CanCollide = false })
		fireflies(spot, 4)
	end

	-- Unsichtbare Grenze
	for _, wall in { { 0, 300, 640, 2 }, { 0, -300, 640, 2 }, { 300, 0, 2, 640 }, { -300, 0, 2, 640 } } do
		part({ Name = "Boundary", Size = Vector3.new(wall[3], 60, wall[4]), Position = Vector3.new(wall[1], 30, wall[2]), Transparency = 1 })
	end
end

function WorldService:SetFeatured(index: number)
	for i, portal in self.Portals do
		portal.Featured.Enabled = i == index
	end
end

function WorldService:Build()
	world = Instance.new("Folder")
	world.Name = "Town"
	world.Parent = workspace
	setupLighting()
	buildTown()
	local dungeons = Instance.new("Folder")
	dungeons.Name = "Dungeons"
	dungeons.Parent = workspace
	local monsters = Instance.new("Folder")
	monsters.Name = "Monsters"
	monsters.Parent = workspace
	self.DungeonFolder = dungeons
	self.MonsterFolder = monsters
end

return WorldService
