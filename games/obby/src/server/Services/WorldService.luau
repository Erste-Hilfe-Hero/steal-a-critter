-- Baut die komplette Strecke per Code: 100 Stages in 10 Welten, Checkpoints, Ziel und Startbereich.
-- Bewegte und verschwindende Hindernisse werden nur markiert (Tags/Attribute) und vom Client animiert,
-- damit sie fluessig laufen und das Netzwerk nicht belasten.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = {
	Services = nil :: any,
	Checkpoints = {} :: { [number]: BasePart },
	Finish = nil :: BasePart?,
	Gems = {} :: { [number]: BasePart }, -- [Welt] = Edelstein
	Boards = {} :: { [string]: BasePart }, -- Bestenlisten in der Lobby ("Wins", "Time")
}

local root: Folder
local killFolder: Folder
local checkpointFolder: Folder
local bounceFolder: Folder
local gemFolder: Folder

local BOUNCE_COLOR = Color3.fromRGB(120, 255, 90)
local BOUNCE_RISE = 9 -- Hoehe pro Sprungpad (Sprungpad-Gipfel ca. 16 Studs, normaler Sprung nur ca. 7)

function WorldService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Bausteine

type Ctx = {
	Folder: Folder,
	World: any,
	WorldIndex: number,
	Stage: number,
	D: number, -- Schwierigkeit 0..1
	Rng: Random,
}

local function part(ctx: Ctx, size: Vector3, position: Vector3, color: Color3?, props: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = CFrame.new(position)
	p.Color = color or ctx.World.Floor
	p.Material = ctx.World.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in (props or {}) :: { [string]: any } do
		(p :: any)[key] = value
	end
	if ctx.World.Rainbow and not props then
		p.Color = Color3.fromHSV((ctx.Rng:NextNumber()), 0.65, 1)
	end
	p.Parent = ctx.Folder
	return p
end

-- Plattform, auf der man stehen kann (Oberkante = y)
local function platform(ctx: Ctx, sizeX: number, sizeZ: number, x: number, y: number, z: number, color: Color3?): BasePart
	return part(ctx, Vector3.new(sizeX, 1, sizeZ), Vector3.new(x, y - 0.5, z), color)
end

-- Todesteil: kollidiert nicht, der Client erkennt die Beruehrung
local function kill(ctx: Ctx, size: Vector3, cframe: CFrame): BasePart
	local p = part(ctx, size, cframe.Position, Config.KillColor, {
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	p.CFrame = cframe
	p.Parent = killFolder
	return p
end

local function spin(p: BasePart, degreesPerSecond: number)
	p:SetAttribute("BaseCFrame", p.CFrame)
	p:SetAttribute("Speed", degreesPerSecond)
	CollectionService:AddTag(p, "Spin")
end

local function slide(p: BasePart, offset: Vector3, period: number, phase: number)
	p:SetAttribute("BaseCFrame", p.CFrame)
	p:SetAttribute("Offset", offset)
	p:SetAttribute("Period", period)
	p:SetAttribute("Phase", phase)
	CollectionService:AddTag(p, "Slide")
end

local function fade(p: BasePart, period: number, phase: number)
	p:SetAttribute("Period", period)
	p:SetAttribute("Phase", phase)
	CollectionService:AddTag(p, "Fade")
end

---------------------------------------------------------------- Hindernis-Muster
-- Jedes Muster startet an der Vorderkante des Checkpoints (from) und gibt die Mitte
-- des naechsten Checkpoints zurueck (Oberkante).

local PAD_HALF = Config.PadSize.Z / 2

local Patterns = {}

-- Einfache Spruenge zwischen kleiner werdenden Plattformen
function Patterns.Jumps(ctx: Ctx, from: Vector3): Vector3
	local count = 4 + math.round(ctx.D * 3)
	local size = 6 - ctx.D * 2.8
	local z, y = from.Z, from.Y
	for _ = 1, count do
		local gap = 3.5 + ctx.D * 2.5 + ctx.Rng:NextNumber(0, 0.8)
		z += gap + size / 2
		y += ctx.Rng:NextNumber(-0.5, 1.2)
		platform(ctx, size, size, ctx.Rng:NextNumber(-3, 3) * ctx.D, y, z)
		z += size / 2
	end
	return Vector3.new(0, y + Config.RisePerStage, z + 4 + PAD_HALF)
end

-- Boden mit Lava-Streifen, die man ueberspringen muss
function Patterns.Lava(ctx: Ctx, from: Vector3): Vector3
	local length = 36 + ctx.D * 16
	local y = from.Y
	platform(ctx, 12, length, 0, y, from.Z + length / 2)
	-- Hoechstens 5 Streifen mit max. 4,5 Studs: zwischen zwei Streifen bleiben immer >= 4 Studs zum Landen,
	-- so klappt auch ein voller Sprung (ca. 8,7 Studs weit) ohne im naechsten Streifen zu landen
	local strips = 3 + math.round(ctx.D * 2)
	local width = 2 + ctx.D * 2.5
	for i = 1, strips do
		local z = from.Z + i * length / (strips + 1)
		kill(ctx, Vector3.new(12, 0.4, width), CFrame.new(0, y + 0.2, z))
	end
	return Vector3.new(0, y + Config.RisePerStage, from.Z + length + 3 + PAD_HALF)
end

-- Hoch klettern an einer Leiter
function Patterns.Truss(ctx: Ctx, from: Vector3): Vector3
	local y = from.Y
	local z = from.Z + 6
	platform(ctx, 8, 8, 0, y, z + 4)
	-- TrussParts gibt es nur in 2-Stud-Schritten: Hoehe gerade runden, sonst endet die Leiter unter der Plattform
	local height = 2 * math.round((12 + ctx.D * 10) / 2)
	local truss = Instance.new("TrussPart")
	truss.Anchored = true
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = CFrame.new(0, y + height / 2, z + 9)
	truss.Color = ctx.World.Accent
	truss.Parent = ctx.Folder
	-- Ab mittlerer Schwierigkeit fliegen Kill-Balken an der Leiter vorbei
	if ctx.D > 0.35 then
		local bar = kill(ctx, Vector3.new(10, 0.8, 0.8), CFrame.new(0, y + height * 0.55, z + 8))
		slide(bar, Vector3.new(0, height * 0.3, 0), 3.2 - ctx.D, ctx.Rng:NextNumber())
	end
	local top = y + height
	platform(ctx, 8, 6, 0, top, z + 13)
	return Vector3.new(0, top + 0.5, z + 16 + 5 + PAD_HALF)
end

-- Runde Plattform mit drehendem Kill-Balken (drueberspringen)
function Patterns.Spinner(ctx: Ctx, from: Vector3): Vector3
	local y = from.Y
	local radius = 12
	local center = Vector3.new(0, y, from.Z + 3 + radius)
	local disc = part(ctx, Vector3.new(1, radius * 2, radius * 2), center - Vector3.new(0, 0.5, 0), nil, { Shape = Enum.PartType.Cylinder })
	disc.CFrame = CFrame.new(center - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	disc.Color = ctx.World.Floor
	part(ctx, Vector3.new(2, 4, 2), center + Vector3.new(0, 2, 0), ctx.World.Accent)
	local bars = if ctx.D > 0.5 then 2 else 1
	for i = 1, bars do
		local bar = kill(ctx, Vector3.new(radius * 2 - 1, 1, 1), CFrame.new(center + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(90 * (i - 1)), 0))
		spin(bar, 70 + ctx.D * 110)
	end
	return Vector3.new(0, y + Config.RisePerStage, center.Z + radius + 4 + PAD_HALF)
end

-- Plattformen, die verschwinden und wieder auftauchen
function Patterns.Fade(ctx: Ctx, from: Vector3): Vector3
	local count = 4 + math.round(ctx.D * 2)
	local size = 7 - ctx.D * 2
	local period = 4 - ctx.D * 1.5
	local z, y = from.Z, from.Y
	for i = 1, count do
		z += 3.5 + size / 2
		local p = platform(ctx, size, size, 0, y, z, ctx.World.Accent)
		p.Material = Enum.Material.Glass
		p.Transparency = 0.15
		fade(p, period, (i - 1) * 0.18)
		z += size / 2
	end
	return Vector3.new(0, y + Config.RisePerStage, z + 4 + PAD_HALF)
end

-- Schmaler Balken, ab mittlerer Schwierigkeit mit seitlichen Kill-Wuerfeln
function Patterns.Tightrope(ctx: Ctx, from: Vector3): Vector3
	local length = 30 + ctx.D * 10
	local width = 2.2 - ctx.D * 1.2
	local y = from.Y
	platform(ctx, width, length, 0, y, from.Z + length / 2, ctx.World.Accent)
	if ctx.D > 0.3 then
		for i = 1, 2 + math.round(ctx.D * 2) do
			local z = from.Z + i * length / (3 + math.round(ctx.D * 2))
			local cube = kill(ctx, Vector3.new(2, 2, 2), CFrame.new(-5, y + 1.5, z))
			slide(cube, Vector3.new(10, 0, 0), 3.5 - ctx.D * 1.5, ctx.Rng:NextNumber())
		end
	end
	return Vector3.new(0, y + Config.RisePerStage, from.Z + length + 3 + PAD_HALF)
end

-- Treppe aus kleinen Bloecken nach oben
function Patterns.Stairs(ctx: Ctx, from: Vector3): Vector3
	local steps = 6 + math.round(ctx.D * 3)
	local size = 4.5 - ctx.D * 1.5
	local z, y = from.Z, from.Y
	local side = 1
	for _ = 1, steps do
		z += 3 + ctx.D * 1.5 + size / 2
		y += 2.2
		side = -side
		platform(ctx, size, size, side * (1.5 + ctx.D * 2), y, z)
		z += size / 2
	end
	return Vector3.new(0, y + 0.5, z + 4 + PAD_HALF)
end

-- Links-rechts-Spruenge
function Patterns.ZigZag(ctx: Ctx, from: Vector3): Vector3
	local count = 5 + math.round(ctx.D * 2)
	local size = 5.5 - ctx.D * 2
	local z, y = from.Z, from.Y
	for i = 1, count do
		z += 2 + ctx.D * 1.5 + size / 2
		y += 0.6
		platform(ctx, size, size, (if i % 2 == 0 then 1 else -1) * (3 + ctx.D * 1.5), y, z)
		z += size / 2
	end
	return Vector3.new(0, y + Config.RisePerStage, z + 4 + PAD_HALF)
end

-- Gang mit Kill-Waenden, die hin und her fahren
function Patterns.Sliders(ctx: Ctx, from: Vector3): Vector3
	local length = 40 + ctx.D * 12
	local y = from.Y
	platform(ctx, 14, length, 0, y, from.Z + length / 2)
	local walls = 3 + math.round(ctx.D * 3)
	for i = 1, walls do
		local z = from.Z + i * length / (walls + 1)
		local wall = kill(ctx, Vector3.new(6, 6, 1), CFrame.new(0, y + 3, z))
		slide(wall, Vector3.new(4.5, 0, 0), 2.8 - ctx.D * 1.2, i * 0.37)
	end
	return Vector3.new(0, y + Config.RisePerStage, from.Z + length + 3 + PAD_HALF)
end

-- Runde Saeulen, deren Oberseite immer kleiner wird
function Patterns.Pillars(ctx: Ctx, from: Vector3): Vector3
	local count = 5 + math.round(ctx.D * 2)
	local diameter = 5 - ctx.D * 2.2
	local z, y = from.Z, from.Y
	for _ = 1, count do
		z += 3.5 + ctx.D * 2.5 + diameter / 2
		y += ctx.Rng:NextNumber(0, 1)
		local height = 20
		local pillar = part(ctx, Vector3.new(height, diameter, diameter), Vector3.zero, nil, { Shape = Enum.PartType.Cylinder })
		pillar.Color = ctx.World.Accent
		pillar.CFrame = CFrame.new(ctx.Rng:NextNumber(-2, 2) * ctx.D, y - height / 2, z) * CFrame.Angles(0, 0, math.rad(90))
		z += diameter / 2
	end
	return Vector3.new(0, y + Config.RisePerStage, z + 4 + PAD_HALF)
end

-- Bruecke, auf der Kill-Kugeln entlang rollen (seitlich ausweichen)
function Patterns.Gauntlet(ctx: Ctx, from: Vector3): Vector3
	local length = 34 + ctx.D * 10
	local y = from.Y
	platform(ctx, 10, length, 0, y, from.Z + length / 2)
	local count = 2 + math.round(ctx.D * 3)
	for i = 1, count do
		local ball = kill(ctx, Vector3.new(3.5, 3.5, 3.5), CFrame.new((if i % 2 == 0 then 2.5 else -2.5), y + 1.75, from.Z + length / 2))
		ball.Shape = Enum.PartType.Ball
		slide(ball, Vector3.new(0, 0, length / 2 - 2), 3 - ctx.D, i / count)
	end
	return Vector3.new(0, y + Config.RisePerStage, from.Z + length + 3 + PAD_HALF)
end

-- Sprungpads: Wer darauf landet, wird hoch geschleudert (der Client gibt den Schwung).
-- Jedes Pad liegt 9 Studs hoeher als das vorige - ohne Pad unerreichbar, mit Pad (Gipfel ~16) sicher.
-- Abstand + Groesse <= 9 Studs: auch vom vorderen Rand aus erreicht man das naechste Pad (Flugweite ~10,9).
function Patterns.Bounce(ctx: Ctx, from: Vector3): Vector3
	local count = 3 + math.round(ctx.D * 2)
	local size = 6 - ctx.D * 1.5
	local gap = 3 + ctx.D * 1.5
	local z, y = from.Z, from.Y
	for _ = 1, count do
		z += gap + size / 2
		local pad = platform(ctx, size, size, 0, y, z)
		pad.Color = BOUNCE_COLOR
		pad.Material = Enum.Material.Neon
		pad.Parent = bounceFolder
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Top
		surface.LightInfluence = 0
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 20
		local arrow = Instance.new("TextLabel")
		arrow.BackgroundTransparency = 1
		arrow.Size = UDim2.fromScale(1, 1)
		arrow.Font = Enum.Font.FredokaOne
		arrow.TextScaled = true
		arrow.Text = "▲"
		arrow.TextColor3 = Color3.fromRGB(30, 90, 20)
		arrow.TextTransparency = 0.3
		arrow.Parent = surface
		surface.Parent = pad
		y += BOUNCE_RISE
		z += size / 2
	end
	-- Normale Landeplattform oben
	z += gap + 4
	platform(ctx, 8, 8, 0, y, z)
	z += 4
	return Vector3.new(0, y + Config.RisePerStage, z + 4 + PAD_HALF)
end

local ORDER = { "Jumps", "Lava", "ZigZag", "Spinner", "Fade", "Stairs", "Bounce", "Tightrope", "Sliders", "Pillars", "Gauntlet", "Truss" }

---------------------------------------------------------------- Checkpoints und Schilder

local function sign(parent: Instance, text: string, color: Color3, size: Vector2, offset: Vector3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(size.X, size.Y)
	gui.StudsOffset = offset
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = parent
	return gui
end

local function makeCheckpoint(stage: number, position: Vector3): BasePart
	local world = Config.WorldForStage(stage)
	local pad: BasePart
	if stage == 1 then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Neutral = true
		spawnLocation.Duration = 0
		pad = spawnLocation
	else
		pad = Instance.new("Part")
	end
	pad.Name = tostring(stage)
	pad.Anchored = true
	pad.Size = Config.PadSize
	pad.CFrame = CFrame.new(position - Vector3.new(0, Config.PadSize.Y / 2, 0))
	pad.Color = world.Accent
	pad.Material = Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad:SetAttribute("Stage", stage)

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.LightInfluence = 0
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 30
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = tostring(stage)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.25
	label.Parent = surface
	surface.Parent = pad
	pad.Parent = checkpointFolder

	-- Leuchtender Rand und kleine Fahne, damit man Checkpoints von weitem sieht
	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Anchored = true
	trim.CanCollide = false
	trim.CanQuery = false
	trim.CanTouch = false
	trim.Size = Vector3.new(Config.PadSize.X + 0.4, 0.3, Config.PadSize.Z + 0.4)
	trim.CFrame = pad.CFrame * CFrame.new(0, -Config.PadSize.Y / 2 + 0.1, 0)
	trim.Color = Color3.new(1, 1, 1)
	trim.Material = Enum.Material.Neon
	trim.Parent = pad
	local pole = trim:Clone()
	pole.Name = "Pole"
	pole.Size = Vector3.new(0.4, 6, 0.4)
	pole.Material = Enum.Material.SmoothPlastic
	pole.CFrame = pad.CFrame * CFrame.new(Config.PadSize.X / 2 - 1, 3.6, Config.PadSize.Z / 2 - 1)
	pole.Parent = pad
	local flag = trim:Clone()
	flag.Name = "Flag"
	flag.Size = Vector3.new(0.15, 1.6, 2.4)
	flag.Color = world.Accent
	flag.CFrame = pole.CFrame * CFrame.new(0, 2.1, -1.2)
	flag.Parent = pad
	return pad
end

-- Grosser Bogen am Anfang jeder Welt
local function makeGate(worldIndex: number, position: Vector3)
	local world = Config.Worlds[worldIndex]
	local gate = Instance.new("Model")
	gate.Name = "Gate" .. worldIndex
	for _, x in { -9, 9 } do
		local pillar = Instance.new("Part")
		pillar.Anchored = true
		pillar.Size = Vector3.new(2, 16, 2)
		pillar.CFrame = CFrame.new(position + Vector3.new(x, 8, -PAD_HALF + 1))
		pillar.Color = world.Accent
		pillar.Material = Enum.Material.Neon
		pillar.Parent = gate
	end
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.Size = Vector3.new(20, 2, 2)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 17, -PAD_HALF + 1))
	beam.Color = world.Accent
	beam.Material = Enum.Material.Neon
	beam.Parent = gate
	sign(beam, `World {worldIndex}: {world.Name}`, Color3.new(1, 1, 1), Vector2.new(24, 5), Vector3.new(0, 4, 0))
	gate.Parent = root
end

local function makeFinish(position: Vector3): BasePart
	local finish = Instance.new("Part")
	finish.Name = "Finish"
	finish.Anchored = true
	finish.Size = Vector3.new(24, 1.2, 24)
	finish.CFrame = CFrame.new(position - Vector3.new(0, 0.6, 0))
	finish.Color = Color3.fromRGB(255, 200, 40)
	finish.Material = Enum.Material.Neon
	sign(finish, "FINISH! +1 WIN", Color3.fromRGB(255, 220, 60), Vector2.new(30, 7), Vector3.new(0, 12, 0))
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = Color3.fromRGB(255, 220, 60)
	sparkles.Parent = finish
	finish.Parent = root
	return finish
end

-- Versteckter Regenbogen-Edelstein auf einer kleinen Insel neben einem Checkpoint (normaler Sprung, 4,5 Studs)
local function makeGem(worldIndex: number, pad: BasePart)
	local world = Config.Worlds[worldIndex]
	local side = if worldIndex % 2 == 0 then 1 else -1
	local top = pad.Position.Y + pad.Size.Y / 2
	local x = side * (Config.PadSize.X / 2 + 4.5 + 2)
	local ctx = { Folder = gemFolder, World = world, WorldIndex = worldIndex, Stage = 0, D = 0, Rng = Random.new(worldIndex) } :: Ctx
	local island = platform(ctx, 4, 4, x, top, pad.Position.Z, world.Accent)
	island.Name = "GemIsland" .. worldIndex
	local gem = Instance.new("Part")
	gem.Name = "Gem" .. worldIndex
	gem.Anchored = true
	gem.CanCollide = false
	gem.CanQuery = false
	gem.Size = Vector3.new(1.6, 1.6, 1.6)
	gem.CFrame = CFrame.new(x, top + 2.5, pad.Position.Z) * CFrame.Angles(math.rad(45), 0, math.rad(45))
	gem.Color = Color3.fromHSV((worldIndex - 1) / #Config.Worlds, 0.7, 1)
	gem.Material = Enum.Material.Neon
	gem:SetAttribute("GemWorld", worldIndex)
	local sparkles = Instance.new("Sparkles")
	sparkles.SparkleColor = gem.Color
	sparkles.Parent = gem
	gem.Parent = gemFolder
	spin(gem, 90)
	return gem
end

-- Bestenliste als Tafel in der Lobby (Inhalt fuellt der LeaderboardService)
local function makeBoard(name: string, position: Vector3, facing: Vector3): BasePart
	local board = Instance.new("Part")
	board.Name = name .. "Board"
	board.Anchored = true
	board.Size = Vector3.new(12, 14, 1)
	board.CFrame = CFrame.lookAt(position, position + facing)
	board.Color = Color3.fromRGB(40, 36, 64)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = root
	return board
end

local function makeLobby(start: Vector3)
	local ctx = { Folder = root, World = Config.Worlds[1], WorldIndex = 1, Stage = 0, D = 0, Rng = Random.new(1) } :: Ctx
	-- Grosse Startinsel hinter dem ersten Checkpoint
	platform(ctx, 60, 40, 0, start.Y - Config.PadSize.Y + 0.01, start.Z - PAD_HALF - 20, Color3.fromRGB(120, 220, 120))
	local board = part(ctx, Vector3.new(40, 14, 1), start + Vector3.new(0, 10, -38), Color3.fromRGB(40, 40, 60))
	local gui = sign(board, "MEGA RAINBOW OBBY", Color3.fromRGB(255, 255, 255), Vector2.new(40, 8), Vector3.new(0, 2, 0))
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Rainbow"
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 110)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
	})
	gradient.Parent = gui:FindFirstChildOfClass("TextLabel")
	sign(board, `{Config.StageCount} stages - 10 worlds - can you beat them all?`, Color3.fromRGB(255, 230, 120), Vector2.new(36, 3), Vector3.new(0, -3, 0))
	-- Zwei Bestenlisten links und rechts, zur Mitte gedreht
	local floorTop = start.Y - Config.PadSize.Y + 0.01
	local z = start.Z - PAD_HALF - 20
	WorldService.Boards.Wins = makeBoard("Wins", Vector3.new(-24, floorTop + 7, z), Vector3.new(1, 0, 0))
	WorldService.Boards.Time = makeBoard("Time", Vector3.new(24, floorTop + 7, z), Vector3.new(-1, 0, 0))
end

---------------------------------------------------------------- Aufbau

function WorldService:Build()
	root = Instance.new("Folder")
	root.Name = "Obby"
	killFolder = Instance.new("Folder")
	killFolder.Name = "Kill"
	killFolder.Parent = root
	checkpointFolder = Instance.new("Folder")
	checkpointFolder.Name = "Checkpoints"
	checkpointFolder.Parent = root
	bounceFolder = Instance.new("Folder")
	bounceFolder.Name = "Bounce"
	bounceFolder.Parent = root
	gemFolder = Instance.new("Folder")
	gemFolder.Name = "Gems"
	gemFolder.Parent = root

	local position = Vector3.new(0, 20, 0)
	for stage = 1, Config.StageCount do
		local world, worldIndex = Config.WorldForStage(stage)
		self.Checkpoints[stage] = makeCheckpoint(stage, position)
		if (stage - 1) % Config.StagesPerWorld == 0 then
			makeGate(worldIndex, position)
		end
		local folder = Instance.new("Folder")
		folder.Name = "Stage" .. stage
		folder.Parent = root
		local rng = Random.new(stage * 7919)
		local ctx: Ctx = {
			Folder = folder,
			World = world,
			WorldIndex = worldIndex,
			Stage = stage,
			D = (stage - 1) / (Config.StageCount - 1),
			Rng = rng,
		}
		-- Pro Welt eine andere Reihenfolge, damit sich nichts wiederholt anfuehlt
		local pattern = if stage == 1 then "Jumps" elseif stage == 2 then "Lava" else ORDER[(stage + worldIndex * 3) % #ORDER + 1]
		local from = Vector3.new(0, position.Y, position.Z + PAD_HALF)
		position = Patterns[pattern](ctx, from)
	end
	self.Finish = makeFinish(position + Vector3.new(0, 0, 6))
	for worldIndex = 1, #Config.Worlds do
		local stage = (worldIndex - 1) * Config.StagesPerWorld + Config.GemStageInWorld
		self.Gems[worldIndex] = makeGem(worldIndex, self.Checkpoints[stage])
	end
	makeLobby(self.Checkpoints[1].Position + Vector3.new(0, Config.PadSize.Y / 2, 0))

	root.Parent = workspace

	-- Himmel/Nebel: der Client faerbt sie passend zur aktuellen Welt
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Haze = 1
	atmosphere.Color = Config.Worlds[1].Sky
	atmosphere.Parent = Lighting
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 170)
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.06
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Parent = Lighting
	workspace.FallenPartsDestroyHeight = -200
end

-- Ort zum Erscheinen auf einem Checkpoint (Blick in Laufrichtung)
function WorldService:SpawnCFrame(stage: number): CFrame
	local pad = self.Checkpoints[math.clamp(stage, 1, Config.StageCount)]
	local position = pad.Position + Vector3.new(0, pad.Size.Y / 2 + 3.5, 0)
	return CFrame.new(position) * CFrame.Angles(0, math.pi, 0)
end

return WorldService
