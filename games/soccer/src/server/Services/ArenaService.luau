-- Baut das Stadion per Code: gestreifter Rasen, Linien, Tore mit Netz, Banden, Tribuenen mit
-- Publikum, Flutlicht und eine grosse Anzeigetafel. Keine fremden Assets.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ArenaService = { Services = nil :: any, Scoreboard = {} :: any, Goals = {} :: any }

local C = Config.Colors
local HALF_L = Config.FieldLength / 2
local HALF_W = Config.FieldWidth / 2
local WALL_X = HALF_L + Config.GoalDepth + 5
local WALL_Z = HALF_W + 7

local folder: Folder

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
	p.Parent = props.Parent or folder
	return p
end

local function line(cf: CFrame, length: number, width: number, parent: Instance)
	part({ Name = "Line", Size = Vector3.new(length, 0.1, width), CFrame = cf * CFrame.new(0, 0.05, 0), Color = C.White, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = parent })
end

local function rect(cx: number, cz: number, sx: number, sz: number, parent: Instance)
	local w = 0.7
	line(CFrame.new(cx, 0, cz - sz / 2), sx + w, w, parent)
	line(CFrame.new(cx, 0, cz + sz / 2), sx + w, w, parent)
	line(CFrame.new(cx - sx / 2, 0, cz), w, sz, parent)
	line(CFrame.new(cx + sx / 2, 0, cz), w, sz, parent)
end

local function circle(cx: number, cz: number, radius: number, parent: Instance)
	local segments = 32
	local length = 2 * math.pi * radius / segments + 0.3
	for i = 1, segments do
		local angle = (i / segments) * math.pi * 2
		local cf = CFrame.new(cx + math.cos(angle) * radius, 0, cz + math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0)
		line(cf, 0.7, length, parent)
	end
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, background: Color3?): TextLabel
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = if background then 0 else 1
	label.BackgroundColor3 = background or Color3.new()
	label.Font = Config.Font
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

---------------------------------------------------------------- Teile des Stadions

local function buildPitch()
	local pitch = Instance.new("Folder")
	pitch.Name = "Pitch"
	pitch.Parent = folder

	-- Rasen in Streifen
	local stripes = 12
	local total = WALL_X * 2
	local width = total / stripes
	for i = 0, stripes - 1 do
		local x = -WALL_X + width * (i + 0.5)
		part({
			Name = "Grass",
			Size = Vector3.new(width, 4, WALL_Z * 2),
			CFrame = CFrame.new(x, Config.GroundY - 2, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(70, 170, 70) else Color3.fromRGB(58, 150, 60),
			Material = Enum.Material.Grass,
			Parent = pitch,
		})
	end
	-- Boden rund ums Stadion
	part({ Name = "Concourse", Size = Vector3.new(560, 4, 420), CFrame = CFrame.new(0, -2.2, 0), Color = Color3.fromRGB(40, 44, 70), Material = Enum.Material.Concrete, Parent = pitch })

	local lines = Instance.new("Folder")
	lines.Name = "Lines"
	lines.Parent = pitch
	rect(0, 0, Config.FieldLength, Config.FieldWidth, lines)
	line(CFrame.new(0, 0, 0), 0.7, Config.FieldWidth, lines)
	circle(0, 0, 18, lines)
	part({ Name = "Spot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2, 2), CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C.White, CanCollide = false, Parent = lines })
	for _, side in { -1, 1 } do
		rect(side * (HALF_L - 17), 0, 34, 70, lines)
		rect(side * (HALF_L - 6), 0, 12, 40, lines)
		part({ Name = "Spot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.4, 1.4), CFrame = CFrame.new(side * (HALF_L - 24), 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C.White, CanCollide = false, Parent = lines })
	end
end

local function buildGoal(teamName: string)
	local team = Config.Teams[teamName]
	local side = team.Side -- Bolt verteidigt -X
	local goal = Instance.new("Model")
	goal.Name = teamName .. "Goal"
	goal.Parent = folder
	local gx = side * HALF_L
	local back = side * (HALF_L + Config.GoalDepth)
	local halfW = Config.GoalWidth / 2
	local h = Config.GoalHeight

	local function post(a: Vector3, b: Vector3)
		local length = (b - a).Magnitude
		local vertical = math.abs(a.X - b.X) < 0.01 and math.abs(a.Z - b.Z) < 0.01
		part({
			Name = "Post",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(length, 1.3, 1.3),
			CFrame = if vertical
				then CFrame.new((a + b) / 2) * CFrame.Angles(0, 0, math.rad(90))
				else CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0),
			Color = team.Color,
			Material = Enum.Material.Neon,
			Parent = goal,
		})
	end
	for _, z in { -halfW, halfW } do
		post(Vector3.new(gx, 0, z), Vector3.new(gx, h, z))
		post(Vector3.new(back, 0, z), Vector3.new(back, h, z))
		post(Vector3.new(gx, h, z), Vector3.new(back, h, z))
	end
	post(Vector3.new(gx, h, -halfW), Vector3.new(gx, h, halfW))
	post(Vector3.new(back, h, -halfW), Vector3.new(back, h, halfW))

	-- Netz als Kraftfeld-Flaechen (Ball bleibt drin)
	local function net(size: Vector3, cf: CFrame)
		part({ Name = "Net", Size = size, CFrame = cf, Color = team.Color, Material = Enum.Material.ForceField, Transparency = 0.15, Parent = goal })
	end
	net(Vector3.new(0.4, h, Config.GoalWidth), CFrame.new(back + side * 0.2, h / 2, 0))
	net(Vector3.new(Config.GoalDepth, 0.4, Config.GoalWidth), CFrame.new((gx + back) / 2, h + 0.2, 0))
	for _, z in { -halfW, halfW } do
		net(Vector3.new(Config.GoalDepth, h, 0.4), CFrame.new((gx + back) / 2, h / 2, z + math.sign(z) * 0.2))
	end
	part({ Name = "GoalFloor", Size = Vector3.new(Config.GoalDepth, 0.1, Config.GoalWidth), CFrame = CFrame.new((gx + back) / 2, 0.05, 0), Color = team.Dark, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false, Parent = goal })

	local burst = Instance.new("Attachment")
	burst.Name = "Burst"
	burst.WorldPosition = Vector3.new(gx, h * 0.6, 0)
	burst.Parent = workspace.Terrain
	ArenaService.Goals[teamName] = { Model = goal, Burst = burst, Side = side }
end

local function buildWalls()
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder
	-- Unsichtbare hohe Waende + Decke, damit der Ball im Feld bleibt
	local height = 80
	for _, sx in { -1, 1 } do
		part({ Name = "Wall", Size = Vector3.new(2, height, WALL_Z * 2 + 4), CFrame = CFrame.new(sx * (WALL_X + 1), height / 2, 0), Transparency = 1, Parent = walls })
	end
	for _, sz in { -1, 1 } do
		part({ Name = "Wall", Size = Vector3.new(WALL_X * 2 + 4, height, 2), CFrame = CFrame.new(0, height / 2, sz * (WALL_Z + 1)), Transparency = 1, Parent = walls })
	end
	part({ Name = "Ceiling", Size = Vector3.new(WALL_X * 2 + 4, 2, WALL_Z * 2 + 4), CFrame = CFrame.new(0, height, 0), Transparency = 1, Parent = walls })

	-- Sichtbare Banden mit Werbetexten im Spielstil
	local slogans = { "TURBO SOCCER", "KICK HARD", "LEVEL UP", "GOAL!", "TURBO SOCCER", "PLAY FAIR" }
	local index = 0
	local function board(cf: CFrame, length: number)
		local segments = math.max(1, math.floor(length / 40))
		local segLength = length / segments
		for i = 0, segments - 1 do
			index += 1
			local offset = -length / 2 + segLength * (i + 0.5)
			local b = part({ Name = "Board", Size = Vector3.new(segLength, 3.5, 1), CFrame = cf * CFrame.new(offset, 1.75, 0), Color = C.Navy, Parent = walls })
			local color = if index % 2 == 0 then C.Lime else C.Orange
			surfaceText(b, Enum.NormalId.Front, slogans[(index % #slogans) + 1], color, C.Navy)
			surfaceText(b, Enum.NormalId.Back, slogans[(index % #slogans) + 1], color, C.Navy)
		end
	end
	board(CFrame.new(0, 0, -WALL_Z + 0.5), WALL_X * 2)
	board(CFrame.new(0, 0, WALL_Z - 0.5) * CFrame.Angles(0, math.pi, 0), WALL_X * 2)
	for _, sx in { -1, 1 } do
		-- Banden an den Torseiten, mit Luecke nicht noetig: das Tor steht davor
		board(CFrame.new(sx * (WALL_X - 0.5), 0, 0) * CFrame.Angles(0, sx * math.pi / 2, 0), WALL_Z * 2)
	end
end

local CROWD_COLORS = {
	Color3.fromRGB(40, 200, 255), Color3.fromRGB(255, 110, 30), Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(190, 255, 60), Color3.fromRGB(255, 205, 50), Color3.fromRGB(230, 60, 120),
}

local function buildStands()
	local stands = Instance.new("Folder")
	stands.Name = "Stands"
	stands.Parent = folder
	local rows = 7
	local random = Random.new(42)
	for _, sz in { -1, 1 } do
		for row = 0, rows - 1 do
			local z = sz * (WALL_Z + 6 + row * 5)
			local y = 2 + row * 3.2
			part({ Name = "Step", Size = Vector3.new(WALL_X * 2 + 20, y * 2, 5), CFrame = CFrame.new(0, 0, z), Color = if row % 2 == 0 then C.Navy else C.NavyLight, Material = Enum.Material.Concrete, Parent = stands })
			-- Zuschauer: farbige Bloecke, abwechselnd Teamfarben je Seite
			for x = -WALL_X, WALL_X, 5 do
				if random:NextNumber() < 0.8 then
					local color = CROWD_COLORS[random:NextInteger(1, #CROWD_COLORS)]
					part({ Name = "Fan", Size = Vector3.new(2, 3, 1.6), CFrame = CFrame.new(x + random:NextNumber(-1, 1), y + 1.5, z), Color = color, CanCollide = false, CanQuery = false, CastShadow = false, Parent = stands })
				end
			end
		end
	end
	-- Hinter den Toren: LED-Waende mit Logo
	for _, sx in { -1, 1 } do
		local screen = part({ Name = "Screen", Size = Vector3.new(2, 18, 90), CFrame = CFrame.new(sx * (WALL_X + 14), 14, 0), Color = C.Navy, Parent = stands })
		surfaceText(screen, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left, "TURBO SOCCER", C.Lime, C.Navy)
	end
end

local function buildLights()
	local lights = Instance.new("Folder")
	lights.Name = "Floodlights"
	lights.Parent = folder
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local base = Vector3.new(sx * (WALL_X + 16), 0, sz * (WALL_Z + 44))
			part({ Name = "Mast", Size = Vector3.new(3, 70, 3), CFrame = CFrame.new(base + Vector3.new(0, 35, 0)), Color = Color3.fromRGB(70, 75, 100), Material = Enum.Material.Metal, Parent = lights })
			local head = part({
				Name = "Lamp",
				Size = Vector3.new(16, 8, 2),
				CFrame = CFrame.lookAt(base + Vector3.new(0, 72, 0), Vector3.new(0, 0, 0)),
				Color = Color3.fromRGB(255, 250, 230),
				Material = Enum.Material.Neon,
				Parent = lights,
			})
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Range = 60
			spot.Angle = 70
			spot.Brightness = 3
			spot.Parent = head
		end
	end
end

local function buildScoreboard()
	local position = Vector3.new(0, 42, WALL_Z + 44)
	local board = part({ Name = "Scoreboard", Size = Vector3.new(70, 24, 2), CFrame = CFrame.lookAt(position, Vector3.new(0, 42, 0)), Color = C.Navy, Parent = folder })
	part({ Name = "ScoreboardLeg", Size = Vector3.new(3, 30, 3), CFrame = CFrame.new(position - Vector3.new(0, 27, 0)), Color = Color3.fromRGB(70, 75, 100), Material = Enum.Material.Metal, Parent = folder })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 15
	gui.LightInfluence = 0
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = C.Navy
	frame.Parent = gui
	local function text(name: string, pos: UDim2, size: UDim2, color: Color3, initial: string): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = pos
		label.Size = size
		label.BackgroundTransparency = 1
		label.Font = Config.Font
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = initial
		label.Parent = frame
		return label
	end
	text("Title", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.18), C.Lime, "TURBO SOCCER")
	ArenaService.Scoreboard.Bolt = text("Bolt", UDim2.fromScale(0.04, 0.25), UDim2.fromScale(0.3, 0.5), Config.Teams.Bolt.Color, "0")
	ArenaService.Scoreboard.Blaze = text("Blaze", UDim2.fromScale(0.66, 0.25), UDim2.fromScale(0.3, 0.5), Config.Teams.Blaze.Color, "0")
	ArenaService.Scoreboard.Time = text("Time", UDim2.fromScale(0.35, 0.3), UDim2.fromScale(0.3, 0.3), C.White, "4:00")
	ArenaService.Scoreboard.Status = text("Status", UDim2.fromScale(0.05, 0.78), UDim2.fromScale(0.9, 0.18), C.Orange, "WARM UP")
	text("BoltName", UDim2.fromScale(0.04, 0.72), UDim2.fromScale(0.3, 0.08), Config.Teams.Bolt.Color, "BOLT")
	text("BlazeName", UDim2.fromScale(0.66, 0.72), UDim2.fromScale(0.3, 0.08), Config.Teams.Blaze.Color, "BLAZE")
end

local function buildLighting()
	Lighting.ClockTime = 18.2
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(90, 90, 120)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 170)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Color = Color3.fromRGB(255, 190, 150)
	atmosphere.Decay = Color3.fromRGB(110, 90, 160)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.15
	grade.Contrast = 0.08
	grade.Parent = Lighting
end

---------------------------------------------------------------- API

function ArenaService:Init(services)
	self.Services = services
end

function ArenaService:Build()
	folder = Instance.new("Folder")
	folder.Name = "Arena"
	folder.Parent = workspace
	buildPitch()
	for _, teamName in Config.TeamOrder do
		buildGoal(teamName)
	end
	buildWalls()
	buildStands()
	buildLights()
	buildScoreboard()
	buildLighting()

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, -0.45, -HALF_W + 8)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder
end

-- Weltposition einer Aufstellungs-Position (Anteil der eigenen Haelfte)
function ArenaService:FormationPosition(teamName: string, slot: number): Vector3
	local spot = Config.Formation[((slot - 1) % #Config.Formation) + 1]
	local side = Config.Teams[teamName].Side
	return Vector3.new(side * spot.x * (HALF_L - 6), Config.GroundY + 3, spot.z * (HALF_W - 8))
end

-- Torlinien-Mitte des Tores, das dieses Team verteidigt
function ArenaService:GoalCenter(teamName: string): Vector3
	return Vector3.new(Config.Teams[teamName].Side * HALF_L, Config.GroundY, 0)
end

function ArenaService:Burst(teamName: string, colors: { Color3 })
	local goal = self.Goals[teamName]
	if not goal then
		return
	end
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new(if #colors == 1 then 0 else (i - 1) / (#colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(keypoints)
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(0.8, 0.2)
	emitter.Speed = NumberRange.new(30, 60)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = goal.Burst
	emitter:Emit(160)
	task.delay(3, function()
		emitter:Destroy()
	end)
end

return ArenaService
