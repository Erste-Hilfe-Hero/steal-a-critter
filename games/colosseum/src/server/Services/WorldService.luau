-- Baut die Region Valoria per Code: 9 Staedte, 9 Routen mit hohem Gras, Arenen, Heilzentren, Laeden,
-- Haeuser, Labor, Tore mit Waechtern, legendaere Schreine und das Kolosseum der Liga.
-- Stil: helle Bilderbuch-Welt, jede Stadt mit eigener Farbe und eigenem Material.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)

local WorldService = { Services = nil :: any }

local STONE = Color3.fromRGB(226, 204, 166)
local STONE_DARK = Color3.fromRGB(190, 162, 122)
local CRIMSON = Color3.fromRGB(150, 28, 40)
local GOLD = Color3.fromRGB(230, 180, 70)
local CREAM = Color3.fromRGB(250, 238, 215)
local WOOD = Color3.fromRGB(120, 82, 50)
local INK = Color3.fromRGB(25, 20, 30)

local GATE_WIDTH = 26 -- Breite der Durchgaenge zwischen Stadt und Route
local ROAD = 16

local random = Random.new(11)
local world: Folder
local npcFolder: Folder

-- Wichtige Punkte fuer StoryService und Spieler-Teleports: Spots[areaId] = { ... }
WorldService.Spots = {} :: { [string]: any }
WorldService.Boards = {} :: { [string]: BasePart }
WorldService.SpawnCFrame = CFrame.new(0, 4, 0)

function WorldService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Bausteine

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or world
	return p
end

local function wedge(props): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent or world
	return p
end

-- Flache Scheibe (Zylinder liegt entlang X, darum drehen)
local function disc(position: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material, parent: Instance?): Part
	return part({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = target
	return label
end

local function torch(position: Vector3, parent: Instance?)
	part({ Name = "TorchPole", Size = Vector3.new(0.6, 6, 0.6), CFrame = CFrame.new(position + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(80, 55, 35), Material = Enum.Material.Wood, Parent = parent })
	local bowl = part({ Name = "TorchBowl", Size = Vector3.new(1.6, 0.8, 1.6), CFrame = CFrame.new(position + Vector3.new(0, 6.3, 0)), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 160, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 22
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = bowl
end

local function lamp(position: Vector3, color: Color3, parent: Instance?)
	part({ Name = "LampPole", Size = Vector3.new(0.5, 9, 0.5), CFrame = CFrame.new(position + Vector3.new(0, 4.5, 0)), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal, Parent = parent })
	local bulb = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(position + Vector3.new(0, 9.4, 0)), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = bulb
end

local function prompt(parent: BasePart, action: string, object: string, promptName: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = promptName
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = parent
	CollectionService:AddTag(p, "WorldPrompt") -- Client oeffnet das passende Fenster
	return p
end
WorldService.Prompt = prompt

local function billboard(adornee: BasePart, title: string?, text: string, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(200, if title then 52 else 30)
	gui.StudsOffset = Vector3.new(0, height, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 60
	if title then
		local top = Instance.new("TextLabel")
		top.Size = UDim2.new(1, 0, 0, 20)
		top.BackgroundTransparency = 1
		top.Font = Enum.Font.BuilderSansBold
		top.TextSize = 15
		top.Text = title
		top.TextColor3 = CREAM
		top.TextStrokeTransparency = 0.3
		top.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.Position = UDim2.fromOffset(0, if title then 20 else 0)
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextSize = 24
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = adornee
	return gui
end

---------------------------------------------------------------- Personen

-- Einfache Figur aus Parts (keine fremden Assets). cf = Fusspunkt mit Blickrichtung.
function WorldService:MakeNpc(lookKey: string, displayName: string, title: string?, cf: CFrame, parent: Instance?): Model
	local look = Story.Looks[lookKey] or Story.Looks.Villager
	local model = Instance.new("Model")
	model.Name = displayName
	local root = part({ Name = "Root", Size = Vector3.new(2.6, 6, 1.6), CFrame = cf * CFrame.new(0, 3, 0), Transparency = 1, CanCollide = true, Parent = model })
	local function limb(partName: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?)
		return part({ Name = partName, Size = size, CFrame = cf * CFrame.new(offset), Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = model })
	end
	limb("LegL", Vector3.new(0.9, 2.2, 0.9), Vector3.new(-0.5, 1.1, 0), look.Pants)
	limb("LegR", Vector3.new(0.9, 2.2, 0.9), Vector3.new(0.5, 1.1, 0), look.Pants)
	limb("Torso", Vector3.new(2, 2.2, 1.05), Vector3.new(0, 3.3, 0), look.Shirt)
	limb("ArmL", Vector3.new(0.8, 2.1, 0.8), Vector3.new(-1.42, 3.3, 0), look.Shirt)
	limb("ArmR", Vector3.new(0.8, 2.1, 0.8), Vector3.new(1.42, 3.3, 0), look.Shirt)
	limb("HandL", Vector3.new(0.7, 0.5, 0.7), Vector3.new(-1.42, 2.1, 0), look.Skin)
	limb("HandR", Vector3.new(0.7, 0.5, 0.7), Vector3.new(1.42, 2.1, 0), look.Skin)
	local head = limb("Head", Vector3.new(1.35, 1.35, 1.35), Vector3.new(0, 5.1, 0), look.Skin)
	limb("Hair", Vector3.new(1.45, 0.55, 1.45), Vector3.new(0, 5.7, 0.08), look.Hair)
	limb("HairBack", Vector3.new(1.45, 1, 0.3), Vector3.new(0, 5.25, 0.62), look.Hair)
	limb("EyeL", Vector3.new(0.2, 0.3, 0.05), Vector3.new(-0.3, 5.2, -0.68), INK)
	limb("EyeR", Vector3.new(0.2, 0.3, 0.05), Vector3.new(0.3, 5.2, -0.68), INK)
	limb("Smile", Vector3.new(0.5, 0.08, 0.05), Vector3.new(0, 4.78, -0.68), INK)
	if look.Hat then
		limb("Hat", Vector3.new(1.55, 0.5, 1.55), Vector3.new(0, 6.1, 0), look.Hat)
		limb("Brim", Vector3.new(1.5, 0.15, 0.7), Vector3.new(0, 5.9, -0.95), look.Hat)
	end
	if look.Cape then
		limb("Cape", Vector3.new(2, 3.6, 0.15), Vector3.new(0, 3, 0.62), look.Cape, Enum.Material.Fabric)
	end
	model.PrimaryPart = root
	billboard(head, title, displayName, if title then GOLD else CREAM, 2.2)
	model.Parent = parent or npcFolder
	return model
end

---------------------------------------------------------------- Licht

local function buildLighting()
	Lighting.ClockTime = 14.2
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 2.8
	Lighting.Ambient = Color3.fromRGB(110, 100, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 145, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(215, 230, 255)
	atmosphere.Decay = Color3.fromRGB(140, 160, 200)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.45
	bloom.Size = 24
	bloom.Threshold = 1.7
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Brightness = 0.03
	color.Contrast = 0.08
	color.Saturation = 0.18
	color.TintColor = Color3.fromRGB(255, 250, 244)
	color.Parent = Lighting
end

---------------------------------------------------------------- Pflanzen und Deko

local function oak(position: Vector3, parent: Instance, scale: number?, leafColor: Color3?)
	local s = scale or random:NextNumber(0.9, 1.3)
	local height = 7 * s
	part({ Name = "Trunk", Size = Vector3.new(1.6 * s, height, 1.6 * s), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = parent })
	local base = leafColor or Color3.fromRGB(70, 150, 60)
	for i = 1, 3 do
		local offset = Vector3.new(random:NextNumber(-1.6, 1.6) * s, height + random:NextNumber(-0.5, 2) * s, random:NextNumber(-1.6, 1.6) * s)
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * random:NextNumber(6, 8) * s / (if i == 3 then 1.3 else 1), CFrame = CFrame.new(position + offset), Color = base:Lerp(Color3.fromRGB(150, 200, 80), random:NextNumber() * 0.5), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
end

local function pine(position: Vector3, parent: Instance, snowy: boolean?, scale: number?)
	local s = scale or random:NextNumber(0.9, 1.4)
	part({ Name = "Trunk", Size = Vector3.new(1.2 * s, 4 * s, 1.2 * s), CFrame = CFrame.new(position + Vector3.new(0, 2 * s, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = parent })
	for i = 0, 2 do
		local w = (7 - i * 2) * s
		local y = (4 + i * 3) * s
		local color = if snowy then Color3.fromRGB(235, 245, 250) else Color3.fromRGB(40, 110, 60):Lerp(Color3.fromRGB(70, 140, 70), i / 2)
		local cone = part({ Name = "Needles", Size = Vector3.new(w, 3.4 * s, w), CFrame = CFrame.new(position + Vector3.new(0, y, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), Color = color, Material = if snowy then Enum.Material.Snow else Enum.Material.Grass, CanCollide = false, Parent = parent })
		cone.Shape = Enum.PartType.Block
	end
end

local function palm(position: Vector3, parent: Instance)
	local lean = random:NextNumber(-0.25, 0.25)
	local top = position
	for i = 0, 5 do
		top = position + Vector3.new(lean * i * 2, i * 2 + 1, 0)
		part({ Name = "PalmTrunk", Size = Vector3.new(1.3, 2.1, 1.3), CFrame = CFrame.new(top) * CFrame.Angles(0, i * 0.4, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood, Parent = parent })
	end
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		part({ Name = "Frond", Size = Vector3.new(1.6, 0.25, 7), CFrame = CFrame.new(top + Vector3.new(0, 1, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.8, -3) * CFrame.Angles(math.rad(-20), 0, 0), Color = Color3.fromRGB(70, 160, 70), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
end

local function deadTree(position: Vector3, parent: Instance)
	local h = random:NextNumber(6, 10)
	part({ Name = "DeadTrunk", Size = Vector3.new(1.3, h, 1.3), CFrame = CFrame.new(position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, random:NextNumber(0, 6), random:NextNumber(-0.1, 0.1)), Color = Color3.fromRGB(70, 55, 50), Material = Enum.Material.Wood, Parent = parent })
	for _ = 1, 2 do
		part({ Name = "Branch", Size = Vector3.new(0.6, 4, 0.6), CFrame = CFrame.new(position + Vector3.new(0, h * 0.75, 0)) * CFrame.Angles(0, random:NextNumber(0, 6), random:NextNumber(0.6, 1)) * CFrame.new(0, 2, 0), Color = Color3.fromRGB(70, 55, 50), Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	end
end

local function rock(position: Vector3, color: Color3, parent: Instance, size: number?)
	local s = size or random:NextNumber(3, 7)
	part({ Name = "Rock", Size = Vector3.new(s, s * 0.7, s * 0.9), CFrame = CFrame.new(position + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6), random:NextNumber(-0.3, 0.3)), Color = color, Material = Enum.Material.Slate, Parent = parent })
end

local function crystal(position: Vector3, color: Color3, parent: Instance)
	local h = random:NextNumber(3, 8)
	local c = part({ Name = "Crystal", Size = Vector3.new(1.4, h, 1.4), CFrame = CFrame.new(position + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6), random:NextNumber(-0.3, 0.3)), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	c.Transparency = 0.15
end

local FLOWERS = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(180, 140, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 80) }
local function flower(position: Vector3, parent: Instance)
	part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.1, CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)), Color = FLOWERS[random:NextInteger(1, #FLOWERS)], Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = parent })
end

-- Baum passend zum Ort
local function themedTree(theme, position: Vector3, parent: Instance, scale: number?)
	local kind = theme.Trees
	if kind == "Pine" then
		pine(position, parent, false, scale)
	elseif kind == "Snow" then
		pine(position, parent, true, scale)
	elseif kind == "Palm" then
		palm(position, parent)
	elseif kind == "Blossom" then
		oak(position, parent, scale, Color3.fromRGB(255, 160, 200))
	elseif kind == "Dead" then
		if random:NextNumber() < 0.6 then
			deadTree(position, parent)
		else
			rock(position, Color3.fromRGB(80, 65, 60), parent)
		end
	elseif kind == "Lamp" then
		oak(position, parent, scale, Color3.fromRGB(90, 140, 70))
	else
		oak(position, parent, scale)
	end
end

---------------------------------------------------------------- Raender und Durchgaenge

local EDGES = {
	N = { Normal = Vector3.new(0, 0, -1), Along = Vector3.new(1, 0, 0) },
	S = { Normal = Vector3.new(0, 0, 1), Along = Vector3.new(1, 0, 0) },
	E = { Normal = Vector3.new(1, 0, 0), Along = Vector3.new(0, 0, 1) },
	W = { Normal = Vector3.new(-1, 0, 0), Along = Vector3.new(0, 0, 1) },
}

local function edgeFor(dir: Vector3): string
	if math.abs(dir.X) > math.abs(dir.Z) then
		return if dir.X > 0 then "E" else "W"
	end
	return if dir.Z > 0 then "S" else "N"
end

-- Unsichtbare Mauer plus sichtbare Hecke entlang einer Kante, mit Luecken (Offsets entlang der Kante)
local function edgeWall(rect, edgeName: string, gaps: { number }, theme, parent: Instance, hedge: boolean)
	local edge = EDGES[edgeName]
	local half = if edgeName == "N" or edgeName == "S" then rect.SizeZ / 2 else rect.SizeX / 2
	local length = if edgeName == "N" or edgeName == "S" then rect.SizeX else rect.SizeZ
	local mid = rect.Center + edge.Normal * half
	-- Abschnitte zwischen den Luecken
	local cuts = { -length / 2 }
	table.sort(gaps)
	for _, g in gaps do
		table.insert(cuts, g - GATE_WIDTH / 2)
		table.insert(cuts, g + GATE_WIDTH / 2)
	end
	table.insert(cuts, length / 2)
	for i = 1, #cuts - 1, 2 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a > 0.5 then
			local center = mid + edge.Along * ((a + b) / 2)
			local size = if edge.Along.X ~= 0 then Vector3.new(b - a, 40, 2) else Vector3.new(2, 40, b - a)
			part({ Name = "Boundary", Size = size, CFrame = CFrame.new(center + Vector3.new(0, 20, 0)), Transparency = 1, CanCollide = true, Parent = parent })
			if hedge then
				local hedgeSize = if edge.Along.X ~= 0 then Vector3.new(b - a, 5, 3) else Vector3.new(3, 5, b - a)
				local color = if theme.Trees == "Snow" then Color3.fromRGB(220, 235, 245) elseif theme.Trees == "Dead" then Color3.fromRGB(90, 75, 70) elseif theme.Trees == "Lamp" then Color3.fromRGB(150, 150, 160) else Color3.fromRGB(60, 130, 60)
				local material = if theme.Trees == "Snow" then Enum.Material.Snow elseif theme.Trees == "Dead" or theme.Trees == "Lamp" then Enum.Material.Slate else Enum.Material.Grass
				part({ Name = "Hedge", Size = hedgeSize, CFrame = CFrame.new(center + Vector3.new(0, 2.5, 0) + edge.Normal * 1.5), Color = color, Material = material, Parent = parent })
				-- Baeume ausserhalb der Kante
				local steps = math.floor((b - a) / 13)
				for s = 0, steps - 1 do
					local along = a + 6.5 + s * 13 + random:NextNumber(-2, 2)
					themedTree(theme, mid + edge.Along * along + edge.Normal * random:NextNumber(6, 10), parent)
				end
			end
		end
	end
end

---------------------------------------------------------------- Gebaeude

-- Gebaeude mit Satteldach, Tuer, Vordach und Schild. cf = Mitte am Boden, LookVector = Vorderseite.
local function building(cf: CFrame, w: number, d: number, h: number, wall: Color3, roof: Color3, sign: string?, signColor: Color3?, parent: Instance)
	part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, h / 2, 0), Color = wall, Material = Enum.Material.SmoothPlastic, Parent = parent })
	part({ Name = "Base", Size = Vector3.new(w + 1, 1, d + 1), CFrame = cf * CFrame.new(0, 0.5, 0), Color = STONE_DARK, Material = Enum.Material.Cobblestone, Parent = parent })
	-- Dach: zwei Keile
	local roofH = math.min(w, d) * 0.3
	wedge({ Name = "Roof", Size = Vector3.new(d + 2, roofH, w / 2 + 1), CFrame = cf * CFrame.new(-w / 4 - 0.5, h + roofH / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = roof, Material = Enum.Material.Slate, Parent = parent })
	wedge({ Name = "Roof", Size = Vector3.new(d + 2, roofH, w / 2 + 1), CFrame = cf * CFrame.new(w / 4 + 0.5, h + roofH / 2, 0) * CFrame.Angles(0, math.rad(90), 0), Color = roof, Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "Trim", Size = Vector3.new(w + 0.4, 0.6, d + 0.4), CFrame = cf * CFrame.new(0, h, 0), Color = roof:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.SmoothPlastic, Parent = parent })
	-- Tuer und Fenster vorne
	part({ Name = "Door", Size = Vector3.new(4.4, 7, 0.3), CFrame = cf * CFrame.new(0, 3.5, -d / 2 - 0.1), Color = Color3.fromRGB(70, 50, 40), Material = Enum.Material.Wood, Parent = parent })
	for _, x in { -w / 2 + 4, w / 2 - 4 } do
		local window = part({ Name = "Window", Size = Vector3.new(3.4, 3, 0.3), CFrame = cf * CFrame.new(x, h * 0.55, -d / 2 - 0.1), Color = Color3.fromRGB(150, 210, 240), Material = Enum.Material.Glass, Parent = parent })
		window.Transparency = 0.2
	end
	if sign then
		local board = part({ Name = "Sign", Size = Vector3.new(math.min(w - 2, 18), 2.6, 0.5), CFrame = cf * CFrame.new(0, h - 1.4, -d / 2 - 0.35), Color = Color3.fromRGB(40, 32, 45), Material = Enum.Material.Wood, Parent = parent })
		surfaceText(board, Enum.NormalId.Front, sign, signColor or GOLD)
		-- Vordach
		part({ Name = "Awning", Size = Vector3.new(8, 0.4, 3), CFrame = cf * CFrame.new(0, 7.6, -d / 2 - 1.5) * CFrame.Angles(math.rad(12), 0, 0), Color = roof, Material = Enum.Material.Fabric, Parent = parent })
	end
end

-- Theke vor einem Gebaeude, Person dahinter. Gibt CFrames (Person, Theke) zurueck.
local function counter(cf: CFrame, d: number, color: Color3, parent: Instance): (CFrame, BasePart)
	local front = cf * CFrame.new(0, 0, -d / 2 - 3)
	local top = part({ Name = "Counter", Size = Vector3.new(7, 3.2, 1.6), CFrame = front * CFrame.new(0, 1.6, -3), Color = color, Material = Enum.Material.Wood, Parent = parent })
	part({ Name = "CounterTop", Size = Vector3.new(7.4, 0.3, 2), CFrame = top.CFrame * CFrame.new(0, 1.7, 0), Color = CREAM, Material = Enum.Material.Marble, Parent = parent })
	return front, top
end

local function boardAt(cf: CFrame, title: string, key: string, parent: Instance)
	local frame = part({ Name = "Board", Size = Vector3.new(14, 18, 1), CFrame = cf * CFrame.new(0, 10, 0), Color = Color3.fromRGB(40, 30, 40), Material = Enum.Material.Wood, Parent = parent })
	part({ Name = "BoardTop", Size = Vector3.new(15, 1.2, 1.4), CFrame = frame.CFrame * CFrame.new(0, 9.4, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
	frame:SetAttribute("Title", title)
	WorldService.Boards[key] = frame
end

-- Werbeflaeche (Immersive Ads von Roblox, bringen Geld pro Ansicht)
local function adPanel(cf: CFrame, parent: Instance)
	local panel = part({ Name = "AdPanel", Size = Vector3.new(16, 9, 0.5), CFrame = cf * CFrame.new(0, 7, 0), Color = Color3.fromRGB(30, 25, 30), Material = Enum.Material.SmoothPlastic, Parent = parent })
	part({ Name = "AdPost", Size = Vector3.new(0.8, 3, 0.8), CFrame = cf * CFrame.new(-6, 1.5, 0.4), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, Parent = parent })
	part({ Name = "AdPost", Size = Vector3.new(0.8, 3, 0.8), CFrame = cf * CFrame.new(6, 1.5, 0.4), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal, Parent = parent })
	pcall(function()
		local ad = Instance.new("AdGui" :: any)
		ad.Face = Enum.NormalId.Front
		ad.Parent = panel
	end)
end

---------------------------------------------------------------- Arena

local function buildArena(town, leader, spots, parent: Instance)
	local typeColor = Config.Types[leader.Type].Color
	local C = town.Center
	local center = C + Vector3.new(40, 0, -40)
	local S = 50
	local folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = parent
	-- Boden mit Kampffeld
	part({ Name = "ArenaFloor", Size = Vector3.new(S, 0.4, S), CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)), Color = typeColor:Lerp(Color3.fromRGB(60, 55, 60), 0.6), Material = Enum.Material.Slate, Parent = folder })
	part({ Name = "Court", Size = Vector3.new(S - 14, 0.1, 18), CFrame = CFrame.new(center + Vector3.new(0, 0.45, 0)), Color = typeColor, Material = Enum.Material.SmoothPlastic, Parent = folder }).Transparency = 0.35
	disc(center + Vector3.new(0, 0.5, 0), 10, 0.1, CREAM, Enum.Material.SmoothPlastic, folder)
	-- Mauern, Tuer im Westen (-X)
	local h = 14
	local wallColor = typeColor:Lerp(STONE, 0.55)
	part({ Name = "ArenaWall", Size = Vector3.new(S, h, 2), CFrame = CFrame.new(center + Vector3.new(0, h / 2, -S / 2)), Color = wallColor, Material = Enum.Material.Limestone, Parent = folder })
	part({ Name = "ArenaWall", Size = Vector3.new(S, h, 2), CFrame = CFrame.new(center + Vector3.new(0, h / 2, S / 2)), Color = wallColor, Material = Enum.Material.Limestone, Parent = folder })
	part({ Name = "ArenaWall", Size = Vector3.new(2, h, S), CFrame = CFrame.new(center + Vector3.new(S / 2, h / 2, 0)), Color = wallColor, Material = Enum.Material.Limestone, Parent = folder })
	local doorW = 10
	local side = (S - doorW) / 2
	for _, s in { -1, 1 } do
		part({ Name = "ArenaWall", Size = Vector3.new(2, h, side), CFrame = CFrame.new(center + Vector3.new(-S / 2, h / 2, s * (doorW / 2 + side / 2))), Color = wallColor, Material = Enum.Material.Limestone, Parent = folder })
		local pillar = part({ Name = "DoorPillar", Size = Vector3.new(3, h + 4, 3), CFrame = CFrame.new(center + Vector3.new(-S / 2, (h + 4) / 2, s * (doorW / 2 + 1.5))), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
		local gem = part({ Name = "DoorGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.6, CFrame = pillar.CFrame * CFrame.new(0, (h + 4) / 2 + 1.2, 0), Color = typeColor, Material = Enum.Material.Neon, Parent = folder })
		local light = Instance.new("PointLight")
		light.Color = typeColor
		light.Range = 16
		light.Parent = gem
	end
	-- Ecken mit leuchtenden Kronen
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local tower = part({ Name = "Tower", Size = Vector3.new(4, h + 3, 4), CFrame = CFrame.new(center + Vector3.new(x * S / 2, (h + 3) / 2, z * S / 2)), Color = STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
			part({ Name = "TowerCap", Size = Vector3.new(4.6, 1, 4.6), CFrame = tower.CFrame * CFrame.new(0, (h + 3) / 2 + 0.5, 0), Color = typeColor, Material = Enum.Material.Neon, Parent = folder })
		end
	end
	local sign = part({ Name = "ArenaSign", Size = Vector3.new(16, 4, 1), CFrame = CFrame.lookAt(center + Vector3.new(-S / 2 - 1.2, h + 1, 0), center + Vector3.new(-S, h + 1, 0)), Color = Color3.fromRGB(35, 28, 40), Material = Enum.Material.Wood, Parent = folder })
	surfaceText(sign, Enum.NormalId.Front, `{town.Name:upper()} ARENA`, typeColor)
	local banner = part({ Name = "ArenaType", Size = Vector3.new(10, 1.6, 1), CFrame = sign.CFrame * CFrame.new(0, -2.8, 0), Color = typeColor, Material = Enum.Material.Fabric, Parent = folder })
	surfaceText(banner, Enum.NormalId.Front, `{leader.Type:upper()} TYPE · LEADER {leader.Name:upper()}`, CREAM, Enum.Font.BuilderSansBold)
	-- Podest des Leiters
	local podium = disc(center + Vector3.new(S / 2 - 6, 0.8, 0), 7, 1.6, STONE, Enum.Material.Marble, folder)
	podium.Name = "LeaderPodium"
	for i = 0, 3 do
		torch(center + Vector3.new(-S / 2 + 8 + i * 11, 0, (if i % 2 == 0 then -1 else 1) * (S / 2 - 3)), folder)
	end
	spots.Leader = CFrame.lookAt(center + Vector3.new(S / 2 - 6, 1.6, 0), center + Vector3.new(-S, 1.6, 0))
	spots.GymTrainers = {
		CFrame.lookAt(center + Vector3.new(-10, 0.4, -8), center + Vector3.new(-10, 0.4, 10)),
		CFrame.lookAt(center + Vector3.new(6, 0.4, 8), center + Vector3.new(6, 0.4, -10)),
	}
	spots.ArenaDoor = CFrame.lookAt(center + Vector3.new(-S / 2 - 3, 0, 0), center + Vector3.new(-S, 0, 0))
end

---------------------------------------------------------------- Staedte

local function townRoads(area, folder: Instance)
	local C = area.Center
	local size = area.Rect.SizeX
	local color = if area.Theme.Trees == "Lamp" then Color3.fromRGB(90, 90, 100) elseif area.Theme.Trees == "Snow" then Color3.fromRGB(200, 210, 220) else Color3.fromRGB(205, 185, 150)
	local material = if area.Theme.Trees == "Lamp" then Enum.Material.Asphalt else Enum.Material.Cobblestone
	part({ Name = "Road", Size = Vector3.new(size, 0.3, ROAD), CFrame = CFrame.new(C + Vector3.new(0, 0.15, 0)), Color = color, Material = material, Parent = folder })
	part({ Name = "Road", Size = Vector3.new(ROAD, 0.3, size), CFrame = CFrame.new(C + Vector3.new(0, 0.16, 0)), Color = color, Material = material, Parent = folder })
	-- Brunnen in der Mitte
	disc(C + Vector3.new(0, 0.8, 0), 12, 1.6, STONE, Enum.Material.Limestone, folder)
	local water = disc(C + Vector3.new(0, 1.65, 0), 10, 0.2, Color3.fromRGB(110, 200, 240), Enum.Material.Glass, folder)
	water.Transparency = 0.25
	local statue = part({ Name = "Statue", Size = Vector3.new(1.6, 5, 1.6), CFrame = CFrame.new(C + Vector3.new(0, 4, 0)), Color = STONE_DARK, Material = Enum.Material.Marble, Parent = folder })
	part({ Name = "StatueOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = statue.CFrame * CFrame.new(0, 3.4, 0), Color = area.Theme.Accent, Material = Enum.Material.Neon, Parent = folder })
	-- Laternen an den Strassen
	for _, d in { -50, -26, 26, 50 } do
		lamp(C + Vector3.new(d, 0, ROAD / 2 + 2), Color3.fromRGB(255, 225, 160), folder)
		lamp(C + Vector3.new(-ROAD / 2 - 2, 0, d), Color3.fromRGB(255, 225, 160), folder)
	end
end

local function townDecor(area, folder: Instance)
	local C = area.Center
	local theme = area.Theme
	local half = area.Rect.SizeX / 2
	-- Blumen und Baeume in freien Ecken (nicht auf Strassen und Gebaeuden)
	for _ = 1, 40 do
		local x = random:NextNumber(-half + 6, half - 6)
		local z = random:NextNumber(-half + 6, half - 6)
		local free = math.abs(x) > ROAD / 2 + 3 and math.abs(z) > ROAD / 2 + 3
		-- Gebaeude-Flaechen grob freihalten
		local nearBuilding = (math.abs(math.abs(x) - 44) < 16 and math.abs(math.abs(z) - 44) < 16) or (x > 10 and z < -10 and not area.League) or (x < -14 and z < -14)
		if free and not nearBuilding then
			local pos = C + Vector3.new(x, 0, z)
			if theme.Trees == "Lamp" then
				part({ Name = "Planter", Size = Vector3.new(4, 1.2, 4), CFrame = CFrame.new(pos + Vector3.new(0, 0.6, 0)), Color = STONE_DARK, Material = Enum.Material.Concrete, Parent = folder })
				flower(pos + Vector3.new(0, 1, 0), folder)
			elseif theme.Trees == "Dead" then
				if area.Id == "duskhollow" then
					crystal(pos, Color3.fromRGB(170, 90, 255), folder)
				else
					local pool = disc(pos + Vector3.new(0, 0.2, 0), random:NextNumber(4, 7), 0.25, Color3.fromRGB(255, 100, 30), Enum.Material.Neon, folder)
					pool.CanCollide = false
				end
			elseif theme.Trees == "Snow" then
				if random:NextNumber() < 0.5 then
					crystal(pos, Color3.fromRGB(160, 225, 255), folder)
				else
					rock(pos, Color3.fromRGB(220, 230, 240), folder, random:NextNumber(2, 4))
				end
			else
				flower(pos, folder)
			end
		end
	end
end

local function townSign(area, pos: Vector3, facing: Vector3, folder: Instance)
	part({ Name = "SignPost", Size = Vector3.new(0.6, 5, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
	local board = part({ Name = "TownSign", Size = Vector3.new(9, 3, 0.4), CFrame = CFrame.lookAt(pos + Vector3.new(0, 5.4, 0), pos + Vector3.new(0, 5.4, 0) + facing), Color = Color3.fromRGB(240, 225, 190), Material = Enum.Material.Wood, Parent = folder })
	surfaceText(board, Enum.NormalId.Front, area.Name:upper(), area.Theme.Accent:Lerp(INK, 0.35))
end

local function buildTown(area)
	local folder = Instance.new("Folder")
	folder.Name = area.Name
	folder.Parent = world
	local C = area.Center
	local theme = area.Theme
	local size = area.Rect.SizeX
	local spots = WorldService.Spots[area.Id] or {}
	WorldService.Spots[area.Id] = spots

	part({ Name = "TownGround", Size = Vector3.new(size, 1, size), CFrame = CFrame.new(C + Vector3.new(0, -0.45, 0)), Color = theme.Ground, Material = theme.Material, Parent = folder })
	if not area.League then
		townRoads(area, folder)
	end

	-- Raender mit Durchgaengen zu den Routen
	local gaps = { N = {}, S = {}, E = {}, W = {} }
	for _, route in Story.Areas do
		if route.Kind == "Route" and (route.From == area.Id or route.To == area.Id) then
			local dir = if route.From == area.Id then route.Dir else -route.Dir
			local edgeName = edgeFor(dir)
			table.insert(gaps[edgeName], 0)
			local edge = EDGES[edgeName]
			local opening = C + edge.Normal * (size / 2)
			townSign(area, opening - edge.Normal * 6 + edge.Along * (GATE_WIDTH / 2 + 3), -edge.Normal, folder)
			-- Tor zur naechsten Route (Bedingung aus Story.Gates)
			local gate = Story.Gates[area.Id]
			if route.From == area.Id and gate then
				local barrierCF = CFrame.lookAt(opening - edge.Normal * 2 + Vector3.new(0, 7, 0), opening + edge.Normal * 10 + Vector3.new(0, 7, 0))
				local barrier = part({ Name = "StoryGate", Size = Vector3.new(GATE_WIDTH, 14, 1), CFrame = barrierCF, Color = theme.Accent, Material = Enum.Material.ForceField, Transparency = 0.05, CanCollide = true, Parent = folder })
				barrier:SetAttribute("Area", area.Id)
				barrier:SetAttribute("Badges", gate.Badges or 0)
				if gate.Flag then
					barrier:SetAttribute("Flag", gate.Flag)
				end
				barrier:SetAttribute("Text", gate.Text)
				CollectionService:AddTag(barrier, "StoryGate") -- Client oeffnet es, wenn die Bedingung erfuellt ist
				for _, s in { -1, 1 } do
					local post = part({ Name = "GatePost", Size = Vector3.new(3, 16, 3), CFrame = CFrame.new(opening - edge.Normal * 2 + edge.Along * s * (GATE_WIDTH / 2 + 1.5) + Vector3.new(0, 8, 0)), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
					part({ Name = "GateGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = post.CFrame * CFrame.new(0, 9, 0), Color = theme.Accent, Material = Enum.Material.Neon, Parent = folder })
				end
				local guardCF = CFrame.lookAt(opening - edge.Normal * 6 - edge.Along * (GATE_WIDTH / 2 + 4), opening - edge.Normal * 20)
				local guard = WorldService:MakeNpc("Guard", "Gate Guard", nil, guardCF, folder)
				guard:SetAttribute("GateText", gate.Text)
				spots.Gate = { CFrame = barrierCF, Guard = guard, Normal = edge.Normal }
			end
		end
	end
	for edgeName, list in gaps do
		edgeWall(area.Rect, edgeName, list, theme, folder, true)
	end

	-- Heilzentrum und Laden
	if not area.League then
		local centerCF = CFrame.lookAt(C + Vector3.new(-44, 0, 44), C + Vector3.new(0, 0, 44))
		building(centerCF, 24, 20, 12, Color3.fromRGB(250, 245, 245), Color3.fromRGB(40, 175, 165), "HEAL CENTER", Color3.fromRGB(255, 120, 150), folder)
		local nurseCF, nurseCounter = counter(centerCF, 20, Color3.fromRGB(255, 200, 215), folder)
		spots.Nurse = nurseCF
		spots.NurseCounter = nurseCounter
		spots.Landing = nurseCF * CFrame.new(0, 3, -8) * CFrame.Angles(0, math.pi, 0)
		local martCF = CFrame.lookAt(C + Vector3.new(44, 0, 44), C + Vector3.new(0, 0, 44))
		building(martCF, 24, 20, 12, Color3.fromRGB(235, 240, 250), Color3.fromRGB(60, 110, 220), "BEAST MART", Color3.fromRGB(120, 190, 255), folder)
		local clerkCF, clerkCounter = counter(martCF, 20, Color3.fromRGB(150, 190, 240), folder)
		spots.Clerk = clerkCF
		spots.ClerkCounter = clerkCounter
		-- Haeuser
		building(CFrame.lookAt(C + Vector3.new(-52, 0, -24), C + Vector3.new(-52, 0, 0)), 14, 12, 9, CREAM, theme.Roof, nil, nil, folder)
		building(CFrame.lookAt(C + Vector3.new(-24, 0, -52), C + Vector3.new(0, 0, -52)), 14, 12, 9, Color3.fromRGB(240, 230, 210), theme.Roof:Lerp(CRIMSON, 0.3), nil, nil, folder)
	end

	local leader
	for _, l in Story.Leaders do
		if l.Town == area.Id then
			leader = l
		end
	end
	if leader then
		buildArena(area, leader, spots, folder)
	end
	if area.Lab then
		local labCF = CFrame.lookAt(C + Vector3.new(42, 0, -40), C + Vector3.new(0, 0, -40))
		building(labCF, 30, 22, 13, Color3.fromRGB(245, 248, 250), Color3.fromRGB(120, 130, 150), "SOL LAB", Color3.fromRGB(120, 200, 255), folder)
		spots.Professor = labCF * CFrame.new(-3, 0, -16)
		spots.Rival = labCF * CFrame.new(5, 0, -17)
		-- Drei Starter-Sockel vor dem Labor
		for i, id in Config.Starters do
			local pos = (labCF * CFrame.new((i - 2) * 6, 0, -24)).Position
			disc(pos + Vector3.new(0, 0.6, 0), 4, 1.2, CREAM, Enum.Material.Marble, folder)
			part({ Name = "StarterOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Color = Config.Types[Config.BeastsById[id].Type].Color, Material = Enum.Material.Neon, Parent = folder })
		end
		-- Haus des Spielers und Startpunkt
		WorldService.SpawnCFrame = CFrame.lookAt(C + Vector3.new(-30, 4, -14), C + Vector3.new(0, 4, -14))
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn"
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 0.4, 8)
		spawn.CFrame = CFrame.new(C + Vector3.new(-30, 0.2, -14))
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Neutral = true
		spawn.Duration = 0
		spawn.Parent = folder
		-- Bestenlisten und Werbung am Dorfplatz
		boardAt(CFrame.lookAt(C + Vector3.new(-14, 0, 30), C + Vector3.new(-14, 0, 60)), "GAUNTLET LEGENDS", "BestWave", folder)
		boardAt(CFrame.lookAt(C + Vector3.new(14, 0, 30), C + Vector3.new(14, 0, 60)), "DUEL CHAMPIONS", "Trophies", folder)
		adPanel(CFrame.lookAt(C + Vector3.new(-14, 0, 60), C + Vector3.new(-14, 0, 30)), folder)
		boardAt(CFrame.lookAt(C + Vector3.new(14, 0, 60), C + Vector3.new(14, 0, 30)), "TOP COLLECTORS", "DexCount", folder)
	end
	if area.Id == "voltara" then
		-- Grossstadt: Hochhaeuser im Hintergrund und Werbetafel
		for i = 0, 5 do
			local h = random:NextNumber(30, 60)
			local x = -60 + i * 24
			part({ Name = "Tower", Size = Vector3.new(16, h, 16), CFrame = CFrame.new(C + Vector3.new(x, h / 2, -size / 2 - 18)), Color = Color3.fromRGB(120, 125, 140):Lerp(Color3.fromRGB(250, 210, 40), (i % 3) * 0.1), Material = Enum.Material.Glass, Parent = folder })
		end
		adPanel(CFrame.lookAt(C + Vector3.new(14, 0, 26), C + Vector3.new(14, 0, 60)), folder)
	elseif area.Id == "coralport" then
		-- Hafen mit Steg
		for i = 0, 6 do
			part({ Name = "Pier", Size = Vector3.new(6, 0.6, 6), CFrame = CFrame.new(C + Vector3.new(-size / 2 - 3 - i * 6, -0.2, 50)), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
		end
	end
	if not area.League then
		townDecor(area, folder)
	end

	-- Legenden-Schrein
	for _, legend in Story.Legends do
		if legend.Area == area.Id and legend.Pos then
			local pos = C + legend.Pos
			local beast = Config.BeastsById[legend.Beast]
			local color = Config.Types[beast.Type].Color
			disc(pos + Vector3.new(0, 0.5, 0), 14, 1, STONE_DARK, Enum.Material.Marble, folder)
			disc(pos + Vector3.new(0, 1.05, 0), 10, 0.1, color, Enum.Material.Neon, folder).Transparency = 0.4
			for i = 0, 3 do
				local angle = i / 4 * math.pi * 2 + math.pi / 4
				local pillar = part({ Name = "ShrinePillar", Size = Vector3.new(1.6, 9, 1.6), CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * 6, 4.5, math.sin(angle) * 6)), Color = STONE, Material = Enum.Material.Marble, Parent = folder })
				part({ Name = "ShrineFlame", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, CFrame = pillar.CFrame * CFrame.new(0, 5.2, 0), Color = color, Material = Enum.Material.Neon, Parent = folder })
			end
			spots.Shrines = spots.Shrines or {}
			spots.Shrines[legend.Beast] = CFrame.lookAt(pos + Vector3.new(0, 1, 0), C + Vector3.new(0, 1, 0))
		end
	end
	return folder
end

---------------------------------------------------------------- Liga

local function ringSegments(count: number, skip: (number) -> boolean, build: (CFrame, number, number) -> ())
	for i = 0, count - 1 do
		if not skip(i) then
			local angle = (i + 0.5) / count * math.pi * 2
			build(CFrame.Angles(0, -angle, 0), angle, i)
		end
	end
end

local function buildLeague(area, folder: Instance)
	local spots = WorldService.Spots[area.Id]
	local origin = area.Center + Vector3.new(20, 0, 0)
	local R = 62
	local N = 40
	-- Eingang zeigt nach Westen (-X), dorthin fuehrt die Siegesstrasse
	local function isEntrance(i: number): boolean
		local angle = (i + 0.5) / N * math.pi * 2
		return math.abs(angle - math.pi) < 0.2
	end
	local segmentWidth = 2 * math.pi * R / N + 0.4
	disc(origin + Vector3.new(0, 0.05, 0), (R - 6) * 2, 0.4, Color3.fromRGB(222, 190, 135), Enum.Material.Sand, folder)
	disc(origin + Vector3.new(0, 0.3, 0), 34, 0.1, GOLD, Enum.Material.Neon, folder).Transparency = 0.35
	disc(origin + Vector3.new(0, 0.32, 0), 31, 0.12, Color3.fromRGB(205, 170, 115), Enum.Material.Sand, folder)
	ringSegments(N, isEntrance, function(rotation, angle)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = CFrame.new(origin + outward * R) * rotation
		for tier = 0, 1 do
			local y = tier * 12
			part({ Name = "Pillar", Size = Vector3.new(2.6, 10, 2.6), CFrame = base * CFrame.new(0, y + 5, -segmentWidth / 2 + 1.3), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
			part({ Name = "Lintel", Size = Vector3.new(3, 2, segmentWidth), CFrame = base * CFrame.new(0, y + 11, 0), Color = STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
		end
		part({ Name = "Attic", Size = Vector3.new(3, 6, segmentWidth), CFrame = base * CFrame.new(0, 27, 0), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
		part({ Name = "Cornice", Size = Vector3.new(3.8, 0.8, segmentWidth), CFrame = base * CFrame.new(0, 30.4, 0), Color = STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
		-- Mauer, damit man nur durch das Tor hinein kommt
		part({ Name = "RingWall", Size = Vector3.new(1, 22, segmentWidth), CFrame = base * CFrame.new(0, 11, 0), Transparency = 1, Parent = folder })
	end)
	ringSegments(N, isEntrance, function(rotation, angle, i)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if i % 5 == 0 then
			local banner = part({ Name = "Banner", Size = Vector3.new(0.3, 9, 4.5), CFrame = CFrame.new(origin + outward * (R + 1.8)) * rotation * CFrame.new(0, 19, 0), Color = CRIMSON, Material = Enum.Material.Fabric, CanCollide = false, Parent = folder })
			part({ Name = "BannerTrim", Size = Vector3.new(0.35, 0.6, 4.6), CFrame = banner.CFrame * CFrame.new(0, -4.5, 0), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false, Parent = folder })
		end
		if i % 4 == 2 then
			torch(origin + outward * (R - 9), folder)
		end
	end)
	for step = 0, 3 do
		local radius = R - 7 + step * 2
		ringSegments(N, isEntrance, function(rotation, angle)
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local width = 2 * math.pi * radius / N + 0.3
			part({ Name = "Seat", Size = Vector3.new(2, 1.5 + step * 1.5, width), CFrame = CFrame.new(origin + outward * radius) * rotation * CFrame.new(0, (1.5 + step * 1.5) / 2, 0), Color = if step % 2 == 0 then STONE else STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
		end)
	end
	-- Torbogen
	local gateX = origin.X - R
	for _, z in { -9, 9 } do
		part({ Name = "GatePillar", Size = Vector3.new(4, 24, 4), CFrame = CFrame.new(gateX, 12, origin.Z + z), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
	end
	local sign = part({ Name = "GateSign", Size = Vector3.new(2, 5, 22), CFrame = CFrame.new(gateX, 26, origin.Z), Color = CRIMSON, Material = Enum.Material.Fabric, Parent = folder })
	surfaceText(sign, Enum.NormalId.Left, "COLOSSEUM LEAGUE", GOLD)
	surfaceText(sign, Enum.NormalId.Right, "COLOSSEUM LEAGUE", GOLD)

	-- Top Vier an vier Stationen, Champion in der Mitte
	spots.Elite = {}
	local angles = { 150, 210, 270, 90 }
	for i, deg in angles do
		local angle = math.rad(deg)
		local pos = origin + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 36
		local elite = Story.Elite[i]
		local look = Story.Looks[elite.Look]
		disc(pos + Vector3.new(0, 0.7, 0), 9, 1.4, STONE, Enum.Material.Marble, folder)
		disc(pos + Vector3.new(0, 1.45, 0), 9.4, 0.15, look.Shirt, Enum.Material.Neon, folder).Transparency = 0.3
		spots.Elite[i] = CFrame.lookAt(pos + Vector3.new(0, 1.4, 0), origin + Vector3.new(0, 1.4, 0))
	end
	disc(origin + Vector3.new(0, 1.2, 0), 12, 2.4, STONE, Enum.Material.Marble, folder)
	disc(origin + Vector3.new(0, 2.45, 0), 12.4, 0.2, GOLD, Enum.Material.Metal, folder)
	spots.Champion = CFrame.lookAt(origin + Vector3.new(0, 2.5, 0), origin + Vector3.new(-40, 2.5, 0))

	-- Heilzentrum und Laden am Eingang
	local C = area.Center
	local centerCF = CFrame.lookAt(C + Vector3.new(-84, 0, 62), C + Vector3.new(-84, 0, 0))
	building(centerCF, 24, 20, 12, Color3.fromRGB(250, 245, 245), Color3.fromRGB(40, 175, 165), "HEAL CENTER", Color3.fromRGB(255, 120, 150), folder)
	local nurseCF, nurseCounter = counter(centerCF, 20, Color3.fromRGB(255, 200, 215), folder)
	spots.Nurse = nurseCF
	spots.NurseCounter = nurseCounter
	spots.Landing = nurseCF * CFrame.new(0, 3, -8) * CFrame.Angles(0, math.pi, 0)
	local martCF = CFrame.lookAt(C + Vector3.new(-84, 0, -62), C + Vector3.new(-84, 0, 0))
	building(martCF, 24, 20, 12, Color3.fromRGB(235, 240, 250), Color3.fromRGB(60, 110, 220), "BEAST MART", Color3.fromRGB(120, 190, 255), folder)
	local clerkCF, clerkCounter = counter(martCF, 20, Color3.fromRGB(150, 190, 240), folder)
	spots.Clerk = clerkCF
	spots.ClerkCounter = clerkCounter
	part({ Name = "Road", Size = Vector3.new(70, 0.3, 18), CFrame = CFrame.new(C + Vector3.new(-75, 0.15, 0)), Color = Color3.fromRGB(205, 185, 150), Material = Enum.Material.Cobblestone, Parent = folder })
	adPanel(CFrame.lookAt(C + Vector3.new(-60, 0, 30), C + Vector3.new(-90, 0, 0)), folder)
	adPanel(CFrame.lookAt(C + Vector3.new(-60, 0, -30), C + Vector3.new(-90, 0, 0)), folder)

	-- Riss in die Leere (Voidrake)
	for _, legend in Story.Legends do
		if legend.Area == area.Id and legend.Pos then
			local pos = C + legend.Pos
			disc(pos + Vector3.new(0, 0.3, 0), 16, 0.6, Color3.fromRGB(30, 20, 40), Enum.Material.Basalt, folder)
			local rift = part({ Name = "VoidRift", Size = Vector3.new(1, 12, 6), CFrame = CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(140, 40, 220), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
			rift.Transparency = 0.2
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(160, 60, 255)
			light.Range = 24
			light.Brightness = 2
			light.Parent = rift
			for _ = 1, 6 do
				crystal(pos + Vector3.new(random:NextNumber(-8, 8), 0, random:NextNumber(-8, 8)), Color3.fromRGB(120, 40, 200), folder)
			end
			spots.Shrines = spots.Shrines or {}
			spots.Shrines[legend.Beast] = CFrame.lookAt(pos + Vector3.new(0, 1, 0), C)
		end
	end
end

---------------------------------------------------------------- Routen

local function buildRoute(area)
	local folder = Instance.new("Folder")
	folder.Name = area.Name
	folder.Parent = world
	local theme = area.Theme
	local rect = area.Rect
	part({ Name = "RouteGround", Size = Vector3.new(rect.SizeX, 1, rect.SizeZ), CFrame = CFrame.new(rect.Center + Vector3.new(0, -0.48, 0)), Color = theme.Ground, Material = theme.Material, Parent = folder })
	-- Weg in der Mitte
	local pathColor = if theme.Material == Enum.Material.Snow then Color3.fromRGB(205, 215, 225) else Color3.fromRGB(190, 160, 115)
	local pathSize = if math.abs(area.Dir.X) > 0.5 then Vector3.new(area.Length, 0.2, 14) else Vector3.new(14, 0.2, area.Length)
	part({ Name = "Path", Size = pathSize, CFrame = CFrame.new(rect.Center + Vector3.new(0, 0.1, 0)), Color = pathColor, Material = Enum.Material.Ground, Parent = folder })

	-- Lange Seiten geschlossen, Enden offen (die Stadtmauern haben dort die Durchgaenge)
	local alongX = math.abs(area.Dir.X) > 0.5
	if alongX then
		edgeWall(rect, "N", {}, theme, folder, true)
		edgeWall(rect, "S", {}, theme, folder, true)
	else
		edgeWall(rect, "E", {}, theme, folder, true)
		edgeWall(rect, "W", {}, theme, folder, true)
	end

	-- Hohes Gras (nur Optik; ob man im Gras steht, rechnet Story.InGrass)
	local grassColor = if theme.Material == Enum.Material.Snow then Color3.fromRGB(170, 210, 190) elseif theme.Trees == "Dead" then Color3.fromRGB(110, 120, 70) else Color3.fromRGB(50, 140, 55)
	for _, patch in Story.GrassPatches(area) do
		local center = Story.RoutePoint(area, patch.A, patch.C)
		local size = if alongX then Vector3.new(patch.Along, 2.6, patch.Across) else Vector3.new(patch.Across, 2.6, patch.Along)
		local grass = part({ Name = "TallGrass", Size = size, CFrame = CFrame.new(center + Vector3.new(0, 1.3, 0)), Color = grassColor, Material = Enum.Material.Grass, CanCollide = false, CanQuery = false, CastShadow = false, Parent = folder })
		grass:SetAttribute("Area", area.Id)
		CollectionService:AddTag(grass, "TallGrass")
		-- Grashalme obendrauf
		for _ = 1, math.floor(size.X * size.Z / 70) do
			local offset = Vector3.new(random:NextNumber(-size.X / 2 + 1, size.X / 2 - 1), 2.6, random:NextNumber(-size.Z / 2 + 1, size.Z / 2 - 1))
			wedge({ Name = "Blade", Size = Vector3.new(0.6, random:NextNumber(1.2, 2.2), 1.2), CFrame = CFrame.new(center + offset) * CFrame.Angles(0, random:NextNumber(0, 6), 0), Color = grassColor:Lerp(Color3.fromRGB(120, 200, 90), random:NextNumber() * 0.5), Material = Enum.Material.Grass, CanCollide = false, CanQuery = false, CastShadow = false, Parent = folder })
		end
	end

	-- Deko am Rand der Route (nicht auf dem Weg und nicht im Gras)
	for _ = 1, math.floor(area.Length / 12) do
		local a = random:NextNumber(0.04, 0.96)
		local c = (if random:NextNumber() < 0.5 then -1 else 1) * random:NextNumber(30, 37)
		local pos = Story.RoutePoint(area, a, c)
		if not Story.InGrass(area, pos) then
			if random:NextNumber() < 0.5 then
				themedTree(theme, pos, folder, random:NextNumber(0.7, 1))
			elseif theme.Trees == "Snow" then
				rock(pos, Color3.fromRGB(225, 235, 245), folder, random:NextNumber(2, 4))
			elseif theme.Trees == "Dead" then
				rock(pos, Color3.fromRGB(80, 65, 60), folder)
			else
				flower(pos, folder)
			end
		end
	end

	-- Schild am Anfang
	local signPos = Story.RoutePoint(area, 0.03, 12)
	part({ Name = "SignPost", Size = Vector3.new(0.6, 5, 0.6), CFrame = CFrame.new(signPos + Vector3.new(0, 2.5, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
	local board = part({ Name = "RouteSign", Size = Vector3.new(9, 3.4, 0.4), CFrame = CFrame.lookAt(signPos + Vector3.new(0, 5.4, 0), signPos + Vector3.new(0, 5.4, 0) - area.Dir), Color = Color3.fromRGB(240, 225, 190), Material = Enum.Material.Wood, Parent = folder })
	local to = Story.AreasById[area.To]
	surfaceText(board, Enum.NormalId.Front, `{area.Name:upper()}\n→ {to.Name}`, INK)

	-- Legende auf der Route (Zephyros)
	for _, legend in Story.Legends do
		if legend.Area == area.Id and legend.A then
			local pos = Story.RoutePoint(area, legend.A, legend.C)
			disc(pos + Vector3.new(0, 0.5, 0), 12, 1, STONE_DARK, Enum.Material.Marble, folder)
			for i = 0, 2 do
				local angle = i / 3 * math.pi * 2
				local spire = part({ Name = "Spire", Size = Vector3.new(1.4, 10, 1.4), CFrame = CFrame.new(pos + Vector3.new(math.cos(angle) * 5, 5, math.sin(angle) * 5)), Color = STONE, Material = Enum.Material.Marble, Parent = folder })
				part({ Name = "SpireGem", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = spire.CFrame * CFrame.new(0, 5.6, 0), Color = Config.Types.Spark.Color, Material = Enum.Material.Neon, Parent = folder })
			end
			local spots = WorldService.Spots[area.Id] or {}
			WorldService.Spots[area.Id] = spots
			spots.Shrines = spots.Shrines or {}
			spots.Shrines[legend.Beast] = CFrame.lookAt(pos + Vector3.new(0, 1, 0), Story.RoutePoint(area, legend.A, 0) + Vector3.new(0, 1, 0))
		end
	end
	return folder
end

---------------------------------------------------------------- Landschaft zwischen den Orten

local function inAnyArea(position: Vector3, margin: number): boolean
	for _, area in Story.Areas do
		local rect = area.Rect
		local d = position - rect.Center
		if math.abs(d.X) <= rect.SizeX / 2 + margin and math.abs(d.Z) <= rect.SizeZ / 2 + margin then
			return true
		end
	end
	return false
end

local function nearestArea(position: Vector3)
	local best, bestDist = Story.Areas[1], math.huge
	for _, area in Story.Areas do
		local dist = (area.Rect.Center - position).Magnitude
		if dist < bestDist then
			best, bestDist = area, dist
		end
	end
	return best
end

local function buildWilds()
	local folder = Instance.new("Folder")
	folder.Name = "Wilds"
	folder.Parent = world
	local minX, maxX, minZ, maxZ = -110, 1360, -950, 110
	part({ Name = "Ground", Size = Vector3.new(maxX - minX, 4, maxZ - minZ), CFrame = CFrame.new((minX + maxX) / 2, -2.6, (minZ + maxZ) / 2), Color = Color3.fromRGB(105, 160, 80), Material = Enum.Material.Grass, Parent = folder }).CastShadow = false
	for x = minX + 15, maxX - 15, 34 do
		for z = minZ + 15, maxZ - 15, 34 do
			local pos = Vector3.new(x + random:NextNumber(-10, 10), -0.6, z + random:NextNumber(-10, 10))
			if not inAnyArea(pos, 12) and random:NextNumber() < 0.55 then
				themedTree(nearestArea(pos).Theme, pos, folder, random:NextNumber(1.2, 1.8))
			end
		end
	end
	-- Vulkan hinter Cinderpeak und Berge hinter Skyreach als Landmarken
	local volcano = Vector3.new(960, -1, 40)
	for i = 0, 6 do
		disc(volcano + Vector3.new(0, i * 6 + 3, 0), 120 - i * 15, 6, Color3.fromRGB(85, 65, 60):Lerp(Color3.fromRGB(60, 45, 45), i / 6), Enum.Material.Basalt, folder)
	end
	local lava = disc(volcano + Vector3.new(0, 42.2, 0), 22, 0.6, Color3.fromRGB(255, 90, 20), Enum.Material.Neon, folder)
	local fire = Instance.new("Fire")
	fire.Size = 20
	fire.Heat = 25
	fire.Parent = lava
	for i = 0, 2 do
		local base = Vector3.new(300 + i * 60, -1, 70)
		for step = 0, 4 do
			disc(base + Vector3.new(0, step * 7 + 3.5, 0), 70 - step * 13, 7, if step == 4 then Color3.fromRGB(240, 245, 250) else Color3.fromRGB(130, 135, 140), if step == 4 then Enum.Material.Snow else Enum.Material.Rock, folder)
		end
	end
end

---------------------------------------------------------------- Aufbau

function WorldService:Build()
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "Npcs"
	npcFolder.Parent = workspace

	buildLighting()
	workspace.Terrain:FillBlock(CFrame.new(600, -8, -400), Vector3.new(3000, 10, 2400), Enum.Material.Water)
	workspace.Terrain.WaterColor = Color3.fromRGB(60, 150, 190)
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterWaveSize = 0.15

	buildWilds()
	for _, area in Story.Areas do
		if area.Kind == "Town" then
			local folder = buildTown(area)
			if area.League then
				buildLeague(area, folder)
			end
		end
	end
	for _, area in Story.Areas do
		if area.Kind == "Route" then
			buildRoute(area)
		end
	end
end

-- Landepunkt in einer Stadt (vor dem Heilzentrum)
function WorldService:LandingFor(areaId: string): CFrame
	local spots = self.Spots[areaId]
	return if spots and spots.Landing then spots.Landing else self.SpawnCFrame
end

return WorldService
