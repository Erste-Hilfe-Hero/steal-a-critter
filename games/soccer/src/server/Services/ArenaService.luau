-- Baut das Stadion per Code im dreckigen CS-1.6-Look der soccerjam-Map: abgenutzter Rasen mit
-- Erdflecken, verblasste Linien, hohe Betonmauern mit Dreck, Rost und Graffiti, Maschendraht,
-- Holzkisten und Faesser, Alien-Maskottchen vor den Toren, gelbes Natriumlicht. Keine fremden Assets.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ArenaService = { Services = nil :: any, Scoreboard = {} :: any, Goals = {} :: any, Mascots = {} :: any }

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

local LINE = Color3.fromRGB(214, 210, 190) -- verblasste Kreide

local function line(cf: CFrame, length: number, width: number, parent: Instance)
	part({ Name = "Line", Size = Vector3.new(length, 0.1, width), CFrame = cf * CFrame.new(0, 0.06, 0), Color = LINE, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = parent })
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

local DIRT = Color3.fromRGB(112, 92, 62)
local CONCRETE = Color3.fromRGB(128, 124, 112)
local GRIME = Color3.fromRGB(70, 66, 56)
local RUST = Color3.fromRGB(122, 70, 38)
local WOOD = Color3.fromRGB(150, 112, 62)

-- flacher Fleck auf dem Boden (Erde, Oel, Pfuetze)
local function patch(x: number, z: number, sx: number, sz: number, color: Color3, material: Enum.Material, angle: number, parent: Instance, y: number?)
	part({ Name = "Patch", Size = Vector3.new(sx, 0.1, sz), CFrame = CFrame.new(x, (y or 0) + 0.03, z) * CFrame.Angles(0, angle, 0), Color = color, Material = material, CanCollide = false, CanQuery = false, CastShadow = false, Parent = parent })
end

local function buildPitch()
	local pitch = Instance.new("Folder")
	pitch.Name = "Pitch"
	pitch.Parent = folder
	local random = Random.new(1337)

	-- Rasen in matten Streifen, wie eine alte, platt gespielte Textur
	local stripes = 12
	local total = WALL_X * 2
	local width = total / stripes
	for i = 0, stripes - 1 do
		local x = -WALL_X + width * (i + 0.5)
		part({
			Name = "Grass",
			Size = Vector3.new(width, 4, WALL_Z * 2),
			CFrame = CFrame.new(x, Config.GroundY - 2, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(88, 116, 56) else Color3.fromRGB(78, 104, 50),
			Material = Enum.Material.Grass,
			Parent = pitch,
		})
	end
	-- Boden rund ums Stadion: rissiger Asphalt
	part({ Name = "Concourse", Size = Vector3.new(760, 4, 600), CFrame = CFrame.new(0, -2.2, 0), Color = Color3.fromRGB(62, 60, 56), Material = Enum.Material.Asphalt, Parent = pitch })

	-- Abgelaufene Erde: Torraeume, Mittelkreis, Laufwege an den Seiten, dazu zufaellige Flecken
	local wear = Instance.new("Folder")
	wear.Name = "Wear"
	wear.Parent = pitch
	for _, side in { -1, 1 } do
		for _ = 1, 9 do
			local x = side * (HALF_L - random:NextNumber(0, 22))
			patch(x, random:NextNumber(-22, 22), random:NextNumber(6, 16), random:NextNumber(5, 14), DIRT, Enum.Material.Ground, random:NextNumber(0, math.pi), wear)
		end
		-- Fuenfmeterraum fast nur noch Erde
		patch(side * (HALF_L - 6), 0, 12, 34, DIRT:Lerp(Color3.fromRGB(90, 110, 55), 0.25), Enum.Material.Ground, 0, wear)
		-- Laufweg entlang der Seitenlinie
		for _ = 1, 6 do
			patch(random:NextNumber(-HALF_L, HALF_L), side * (HALF_W - random:NextNumber(0, 4)), random:NextNumber(12, 30), random:NextNumber(3, 6), DIRT, Enum.Material.Ground, random:NextNumber(-0.15, 0.15), wear)
		end
	end
	for _ = 1, 6 do
		patch(random:NextNumber(-14, 14), random:NextNumber(-14, 14), random:NextNumber(6, 14), random:NextNumber(6, 12), DIRT, Enum.Material.Ground, random:NextNumber(0, math.pi), wear)
	end
	for _ = 1, 36 do
		local color = if random:NextNumber() < 0.7 then DIRT else Color3.fromRGB(96, 92, 60)
		patch(random:NextNumber(-HALF_L, HALF_L), random:NextNumber(-HALF_W, HALF_W), random:NextNumber(2, 9), random:NextNumber(2, 7), color, Enum.Material.Ground, random:NextNumber(0, math.pi), wear)
	end
	-- Pfuetzen und Oelflecken am Rand
	for _ = 1, 8 do
		local z = (if random:NextNumber() < 0.5 then -1 else 1) * (HALF_W + random:NextNumber(1, 5))
		patch(random:NextNumber(-WALL_X + 5, WALL_X - 5), z, random:NextNumber(3, 8), random:NextNumber(2, 4), Color3.fromRGB(40, 44, 46), Enum.Material.Glass, random:NextNumber(0, math.pi), wear)
	end

	local lines = Instance.new("Folder")
	lines.Name = "Lines"
	lines.Parent = pitch
	rect(0, 0, Config.FieldLength, Config.FieldWidth, lines)
	line(CFrame.new(0, 0, 0), 0.7, Config.FieldWidth, lines)
	circle(0, 0, 18, lines)
	part({ Name = "Spot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2, 2), CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = LINE, CanCollide = false, Parent = lines })
	for _, side in { -1, 1 } do
		rect(side * (HALF_L - 17), 0, 34, 70, lines)
		rect(side * (HALF_L - 6), 0, 12, 40, lines)
		part({ Name = "Spot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.4, 1.4), CFrame = CFrame.new(side * (HALF_L - 24), 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = LINE, CanCollide = false, Parent = lines })
	end
	-- Kreidelinien sind abgelaufen: hier und da fehlt ein Stueck
	for _, l in lines:GetChildren() do
		if l:IsA("BasePart") then
			l.Transparency = random:NextNumber(0.1, 0.35)
		end
	end
end

local function buildGoal(teamName: string)
	local team = Config.Teams[teamName]
	local side = team.Side -- Blue verteidigt -X
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
			Material = Enum.Material.Metal,
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

	-- Netz: halb durchsichtige Flaechen (halten den Ball) mit Schnuer-Gitter darauf
	local function net(size: Vector3, cf: CFrame)
		part({ Name = "Net", Size = size, CFrame = cf, Color = Color3.fromRGB(225, 225, 215), Material = Enum.Material.Fabric, Transparency = 0.85, CastShadow = false, Parent = goal })
		-- Schnuere alle 2.5 Studs entlang der beiden grossen Seiten der Flaeche
		local dims = { Vector3.xAxis * size.X, Vector3.yAxis * size.Y, Vector3.zAxis * size.Z }
		table.sort(dims, function(p, q)
			return p.Magnitude > q.Magnitude
		end)
		for k = 1, 2 do
			local along, across = dims[k], dims[3 - k]
			local count = math.floor(across.Magnitude / 2.5)
			for i = 1, count - 1 do
				local offset = across.Unit * (-across.Magnitude / 2 + i * across.Magnitude / count)
				local rope = Vector3.new(0.12, 0.12, 0.12) + Vector3.new(math.abs(along.X), math.abs(along.Y), math.abs(along.Z))
				part({ Name = "Rope", Size = rope, CFrame = cf * CFrame.new(offset), Color = Color3.fromRGB(220, 220, 205), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false, CastShadow = false, Parent = goal })
			end
		end
	end
	net(Vector3.new(0.4, h, Config.GoalWidth), CFrame.new(back + side * 0.2, h / 2, 0))
	net(Vector3.new(Config.GoalDepth, 0.4, Config.GoalWidth), CFrame.new((gx + back) / 2, h + 0.2, 0))
	for _, z in { -halfW, halfW } do
		net(Vector3.new(Config.GoalDepth, h, 0.4), CFrame.new((gx + back) / 2, h / 2, z + math.sign(z) * 0.2))
	end
	part({ Name = "GoalFloor", Size = Vector3.new(Config.GoalDepth, 0.1, Config.GoalWidth), CFrame = CFrame.new((gx + back) / 2, 0.05, 0), Color = DIRT, Material = Enum.Material.Ground, CanCollide = false, Parent = goal })

	local burst = Instance.new("Attachment")
	burst.Name = "Burst"
	burst.WorldPosition = Vector3.new(gx, h * 0.6, 0)
	burst.Parent = workspace.Terrain
	ArenaService.Goals[teamName] = { Model = goal, Burst = burst, Side = side }
end

-- Alien-Maskottchen neben jedem Tor wie im Original: grauer Ausserirdischer mit riesigem Kopf und
-- schwarzen Augen, im Trikot seines Teams. Er beschiesst Gegner in seiner Zone.
local function buildMascot(teamName: string)
	local team = Config.Teams[teamName]
	local side = team.Side
	local model = Instance.new("Model")
	model.Name = teamName .. "Mascot"
	local base = Vector3.new(side * (HALF_L + 4), 0, -(Config.GoalWidth / 2 + 16))
	local facing = CFrame.lookAt(base, Vector3.new(0, 0, 0))
	local skin = Color3.fromRGB(150, 168, 140)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		local p = part({ Name = name, Size = size, CFrame = facing * offset, Color = color, Material = material or Enum.Material.SmoothPlastic, CanCollide = false, Parent = model })
		if shape then
			p.Shape = shape
		end
		return p
	end
	-- Sockel: rostige Kiste, auf der er steht
	piece("Crate", Vector3.new(8, 3, 8), CFrame.new(0, 1.5, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -1.4, 1.4 } do
		piece("Leg", Vector3.new(1.4, 6, 1.4), CFrame.new(x, 6, 0), skin)
		piece("Foot", Vector3.new(2, 1, 3), CFrame.new(x, 3.5, -0.5), Color3.fromRGB(40, 40, 40))
	end
	local body = piece("Body", Vector3.new(5.5, 6, 3.5), CFrame.new(0, 12, 0), team.Color, Enum.Material.Fabric)
	piece("Number", Vector3.new(2.4, 2.6, 0.2), CFrame.new(0, 12.4, -1.8), C.White)
	for _, x in { -1, 1 } do
		piece("Arm", Vector3.new(1.2, 6.5, 1.2), CFrame.new(x * 3.4, 11.5, -0.6) * CFrame.Angles(math.rad(-25), 0, math.rad(x * 12)), skin)
	end
	piece("Neck", Vector3.new(1.4, 1.6, 1.4), CFrame.new(0, 15.6, 0), skin)
	local head = piece("Head", Vector3.new(6.5, 7.5, 6), CFrame.new(0, 19.5, 0), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	head.Size = Vector3.new(7, 7, 7)
	piece("Chin", Vector3.new(3.4, 3, 3.4), CFrame.new(0, 16.8, -0.8), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for _, x in { -1, 1 } do
		piece("Eye", Vector3.new(2.6, 1.3, 0.6), CFrame.new(x * 1.6, 19.6, -3.1) * CFrame.Angles(0, 0, math.rad(x * -28)), Color3.fromRGB(10, 10, 12), Enum.Material.Glass)
		piece("Antenna", Vector3.new(0.3, 3, 0.3), CFrame.new(x * 1.6, 23.8, 0) * CFrame.Angles(0, 0, math.rad(x * -20)), skin)
		piece("AntennaTip", Vector3.new(0.9, 0.9, 0.9), CFrame.new(x * 2.1, 25.3, 0), team.Color, Enum.Material.Neon, Enum.PartType.Ball)
	end
	piece("Mouth", Vector3.new(1.4, 0.2, 0.2), CFrame.new(0, 17, -2.45), Color3.fromRGB(60, 50, 50))
	model.PrimaryPart = body
	model.Parent = folder
	local eye = Instance.new("Attachment")
	eye.Name = "Eye"
	eye.Position = Vector3.new(0, 7.6, -3.2)
	eye.Parent = body
	ArenaService.Mascots[teamName] = { Model = model, Body = body, Eye = eye }
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

	-- Hohe Betonmauern wie in der CS-Map, mit Dreck, Rost, Rohren und Graffiti
	local random = Random.new(77)
	local WALL_H = 22
	local tags = { "SOCCERJAM", "sj_", "GOAL", "de_dust", "KNIFE ME", "GG", "OneEyed", "1.6", "BLUE SUX", "RED SUX", "TURBO" }
	local tagColors = { Color3.fromRGB(220, 60, 40), Color3.fromRGB(60, 140, 230), Color3.fromRGB(240, 220, 60), Color3.fromRGB(240, 240, 240), Color3.fromRGB(90, 200, 80) }
	local function wall(cf: CFrame, length: number)
		-- cf: Mitte am Boden, -Z zeigt ins Feld
		local segments = math.max(1, math.floor(length / 24))
		local segLength = length / segments
		for i = 0, segments - 1 do
			local offset = -length / 2 + segLength * (i + 0.5)
			local shade = random:NextNumber(-12, 12)
			part({ Name = "WallSlab", Size = Vector3.new(segLength, WALL_H, 2), CFrame = cf * CFrame.new(offset, WALL_H / 2, 1), Color = CONCRETE:Lerp(if shade > 0 then Color3.new(1, 1, 1) else GRIME, math.abs(shade) / 40), Material = Enum.Material.Concrete, Parent = walls })
			-- Fuge zwischen den Platten
			part({ Name = "Seam", Size = Vector3.new(0.5, WALL_H, 0.3), CFrame = cf * CFrame.new(offset - segLength / 2, WALL_H / 2, -0.05), Color = GRIME, Material = Enum.Material.Concrete, CanCollide = false, CanQuery = false, Parent = walls })
			-- Sockel mit Dreckrand
			part({ Name = "Grime", Size = Vector3.new(segLength, random:NextNumber(2, 4.5), 0.2), CFrame = cf * CFrame.new(offset, 1.4, -0.1), Color = GRIME, Material = Enum.Material.Slate, Transparency = 0.15, CanCollide = false, CanQuery = false, CastShadow = false, Parent = walls })
			-- Wasserflecken / Rostlaeufer von oben
			for _ = 1, random:NextInteger(1, 3) do
				local h = random:NextNumber(4, 12)
				part({ Name = "Stain", Size = Vector3.new(random:NextNumber(0.6, 2.5), h, 0.15), CFrame = cf * CFrame.new(offset + random:NextNumber(-segLength / 2 + 2, segLength / 2 - 2), WALL_H - h / 2 - 1, -0.1), Color = if random:NextNumber() < 0.5 then RUST else GRIME, Material = Enum.Material.Slate, Transparency = random:NextNumber(0.3, 0.55), CanCollide = false, CanQuery = false, CastShadow = false, Parent = walls })
			end
			-- Graffiti
			if random:NextNumber() < 0.45 then
				local board = part({ Name = "Graffiti", Size = Vector3.new(random:NextNumber(8, 16), random:NextNumber(3, 5), 0.1), CFrame = cf * CFrame.new(offset + random:NextNumber(-3, 3), random:NextNumber(4, 9), -0.08) * CFrame.Angles(0, 0, math.rad(random:NextNumber(-8, 8))), Transparency = 1, CanCollide = false, CanQuery = false, Parent = walls })
				local text = surfaceText(board, Enum.NormalId.Front, tags[random:NextInteger(1, #tags)], tagColors[random:NextInteger(1, #tagColors)])
				text.Font = Enum.Font.PermanentMarker
				text.TextTransparency = 0.15
			end
		end
		-- Rostiges Rohr oben entlang und Maschendraht bis unter das Dach
		part({ Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, 1.4, 1.4), CFrame = cf * CFrame.new(0, WALL_H - 2.5, -0.9), Color = RUST, Material = Enum.Material.CorrodedMetal, CanCollide = false, Parent = walls })
		part({ Name = "Cap", Size = Vector3.new(length, 1, 3), CFrame = cf * CFrame.new(0, WALL_H + 0.5, 1), Color = Color3.fromRGB(90, 88, 82), Material = Enum.Material.Concrete, Parent = walls })
		part({ Name = "Fence", Size = Vector3.new(length, 14, 0.2), CFrame = cf * CFrame.new(0, WALL_H + 8, 1), Color = Color3.fromRGB(150, 150, 140), Material = Enum.Material.DiamondPlate, Transparency = 0.75, CanCollide = false, CastShadow = false, Parent = walls })
		for x = -length / 2, length / 2, 20 do
			part({ Name = "FencePost", Size = Vector3.new(0.6, 15, 0.6), CFrame = cf * CFrame.new(x, WALL_H + 8.5, 1), Color = RUST, Material = Enum.Material.CorrodedMetal, CanCollide = false, Parent = walls })
		end
	end
	wall(CFrame.new(0, 0, -WALL_Z) * CFrame.Angles(0, math.pi, 0), WALL_X * 2 + 4)
	wall(CFrame.new(0, 0, WALL_Z), WALL_X * 2 + 4)
	for _, sx in { -1, 1 } do
		wall(CFrame.new(sx * WALL_X, 0, 0) * CFrame.Angles(0, sx * math.pi / 2, 0), WALL_Z * 2)
	end
end

-- Kisten, Faesser und Paletten in den Ecken und hinter den Toren, wie in jeder CS-Map
local function buildClutter()
	local clutter = Instance.new("Folder")
	clutter.Name = "Clutter"
	clutter.Parent = folder
	local random = Random.new(9)
	local function crate(position: Vector3, size: number, angle: number)
		local c = part({ Name = "Crate", Size = Vector3.new(size, size, size), CFrame = CFrame.new(position + Vector3.new(0, size / 2, 0)) * CFrame.Angles(0, angle, 0), Color = WOOD:Lerp(GRIME, random:NextNumber(0, 0.35)), Material = Enum.Material.WoodPlanks, Parent = clutter })
		-- dunkle Kanten wie bei der klassischen CS-Kiste
		for _, axis in { Vector3.new(1, 0, 0), Vector3.new(0, 0, 1) } do
			for _, s in { -1, 1 } do
				local offset = axis * s * (size / 2 - 0.2)
				part({ Name = "Trim", Size = Vector3.new(if axis.X ~= 0 then 0.5 else size + 0.1, size + 0.1, if axis.Z ~= 0 then 0.5 else size + 0.1), CFrame = c.CFrame * CFrame.new(offset), Color = Color3.fromRGB(92, 66, 36), Material = Enum.Material.Wood, CanCollide = false, CanQuery = false, Parent = clutter })
			end
		end
		return c
	end
	local function barrel(position: Vector3, color: Color3, tipped: boolean)
		local cf = if tipped then CFrame.new(position + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, random:NextNumber(0, math.pi), 0) else CFrame.new(position + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		part({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.4, 3.2, 3.2), CFrame = cf, Color = color, Material = Enum.Material.CorrodedMetal, Parent = clutter })
	end
	-- Ecken im Feld (ausserhalb der Linien, vor der Mauer): klein, damit der Ball nicht haengen bleibt
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = Vector3.new(sx * (WALL_X - 3.5), 0, sz * (WALL_Z - 3.5))
			crate(corner, 5, random:NextNumber(-0.2, 0.2))
			crate(corner + Vector3.new(0, 5, 0), 4, random:NextNumber(0, 1))
			barrel(corner - Vector3.new(sx * 7, 0, 0), RUST, false)
		end
	end
	-- Hinter den Mauern: Kistenstapel, Faesser, ein alter Container
	for _, sx in { -1, 1 } do
		local x = sx * (WALL_X + 8)
		for i = -3, 3 do
			local z = i * 14 + random:NextNumber(-3, 3)
			local size = random:NextInteger(5, 8)
			crate(Vector3.new(x + random:NextNumber(-2, 2), 0, z), size, random:NextNumber(-0.3, 0.3))
			if random:NextNumber() < 0.5 then
				crate(Vector3.new(x + random:NextNumber(-1, 1), size, z), size - 2, random:NextNumber(0, 1))
			end
			if random:NextNumber() < 0.5 then
				barrel(Vector3.new(x + sx * 6, 0, z + 5), if random:NextNumber() < 0.5 then Color3.fromRGB(60, 90, 60) else RUST, random:NextNumber() < 0.3)
			end
		end
		part({ Name = "Container", Size = Vector3.new(10, 10, 32), CFrame = CFrame.new(sx * (WALL_X + 26), 5, sx * 70), Color = if sx < 0 then Color3.fromRGB(120, 50, 40) else Color3.fromRGB(40, 70, 110), Material = Enum.Material.CorrodedMetal, Parent = clutter })
	end
end

local CROWD_COLORS = {
	Color3.fromRGB(60, 90, 160), Color3.fromRGB(170, 60, 50), Color3.fromRGB(190, 185, 170),
	Color3.fromRGB(70, 80, 60), Color3.fromRGB(150, 130, 70), Color3.fromRGB(50, 50, 55),
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
			local y = 20 + row * 3.2
			part({ Name = "Step", Size = Vector3.new(WALL_X * 2 + 20, y * 2, 5), CFrame = CFrame.new(0, 0, z), Color = if row % 2 == 0 then Color3.fromRGB(96, 94, 88) else Color3.fromRGB(84, 82, 76), Material = Enum.Material.Concrete, Parent = stands })
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
		local screen = part({ Name = "Screen", Size = Vector3.new(2, 14, 70), CFrame = CFrame.new(sx * (WALL_X + 40), 30, 0), Color = Color3.fromRGB(40, 40, 38), Material = Enum.Material.Metal, Parent = stands })
		local sign = surfaceText(screen, if sx < 0 then Enum.NormalId.Right else Enum.NormalId.Left, "SOCCERJAM", Color3.fromRGB(230, 200, 90), Color3.fromRGB(40, 40, 38))
		sign.Font = Enum.Font.Arcade
	end
end

local function buildLights()
	local lights = Instance.new("Folder")
	lights.Name = "Floodlights"
	lights.Parent = folder
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local base = Vector3.new(sx * (WALL_X + 16), 0, sz * (WALL_Z + 44))
			part({ Name = "Mast", Size = Vector3.new(3, 70, 3), CFrame = CFrame.new(base + Vector3.new(0, 35, 0)), Color = RUST, Material = Enum.Material.CorrodedMetal, Parent = lights })
			local head = part({
				Name = "Lamp",
				Size = Vector3.new(16, 8, 2),
				CFrame = CFrame.lookAt(base + Vector3.new(0, 72, 0), Vector3.new(0, 0, 0)),
				Color = Color3.fromRGB(255, 196, 110),
				Material = Enum.Material.Neon,
				Parent = lights,
			})
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Range = 60
			spot.Angle = 70
			spot.Brightness = 3
			spot.Color = Color3.fromRGB(255, 200, 130)
			spot.Parent = head
		end
	end
end

local function buildScoreboard()
	local position = Vector3.new(0, 58, WALL_Z + 44)
	local board = part({ Name = "Scoreboard", Size = Vector3.new(70, 24, 2), CFrame = CFrame.lookAt(position, Vector3.new(0, 58, 0)), Color = C.Navy, Parent = folder })
	part({ Name = "ScoreboardLeg", Size = Vector3.new(3, 46, 3), CFrame = CFrame.new(position - Vector3.new(0, 35, 0)), Color = Color3.fromRGB(70, 75, 100), Material = Enum.Material.Metal, Parent = folder })
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
	text("Title", UDim2.fromScale(0.05, 0.03), UDim2.fromScale(0.9, 0.18), C.Lime, "SOCCER JAM")
	ArenaService.Scoreboard.Blue = text("Blue", UDim2.fromScale(0.04, 0.25), UDim2.fromScale(0.3, 0.5), Config.Teams.Blue.Color, "0")
	ArenaService.Scoreboard.Red = text("Red", UDim2.fromScale(0.66, 0.25), UDim2.fromScale(0.3, 0.5), Config.Teams.Red.Color, "0")
	ArenaService.Scoreboard.Time = text("Time", UDim2.fromScale(0.35, 0.3), UDim2.fromScale(0.3, 0.3), C.White, "4:00")
	ArenaService.Scoreboard.Status = text("Status", UDim2.fromScale(0.05, 0.78), UDim2.fromScale(0.9, 0.18), C.Orange, "WARM UP")
	text("BlueName", UDim2.fromScale(0.04, 0.72), UDim2.fromScale(0.3, 0.08), Config.Teams.Blue.Color, "BLUE")
	text("RedName", UDim2.fromScale(0.66, 0.72), UDim2.fromScale(0.3, 0.08), Config.Teams.Red.Color, "RED")
end

-- Truebe Daemmerung mit Dunst, wie die alte HL1-Engine: wenig Farbe, warmes Licht
local function buildLighting()
	Lighting.ClockTime = 17.6
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(80, 76, 68)
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 112, 98)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.36
	atmosphere.Color = Color3.fromRGB(190, 170, 140)
	atmosphere.Decay = Color3.fromRGB(110, 100, 90)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.8
	bloom.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = -0.18
	grade.Contrast = 0.12
	grade.TintColor = Color3.fromRGB(255, 244, 225)
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
	for _, teamName in Config.TeamOrder do
		buildMascot(teamName)
	end
	buildClutter()
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

-- Maskottchen schleudert einen Camper weg: kurzer Energiestrahl
function ArenaService:MascotStomp(teamName: string, target: Vector3)
	local mascot = self.Mascots[teamName]
	if not mascot then
		return
	end
	local from = mascot.Eye.WorldPosition
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Config.Teams[teamName].Color
	beam.Size = Vector3.new(0.8, 0.8, (target - from).Magnitude)
	beam.CFrame = CFrame.lookAt((from + target) / 2, target)
	beam.Parent = folder
	task.delay(0.25, function()
		beam:Destroy()
	end)
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
