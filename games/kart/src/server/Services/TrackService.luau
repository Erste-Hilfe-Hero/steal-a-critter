-- Baut die aktuelle Rennstrecke (Fahrbahn, Curbs, Waende, Start-Tor, Boost-Pads, Item-Boxen, Muenzen,
-- Deko und Licht je Thema) aus den gemeinsamen Streckenpunkten. Immer nur eine Strecke steht gleichzeitig.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tracks = require(ReplicatedStorage.Shared.Tracks)

local TrackService = { Services = nil :: any, Current = nil :: any }

local FLAME = Color3.fromRGB(255, 110, 20)
local GOLD = Color3.fromRGB(255, 200, 40)

local function make(parent: Instance, props: { [string]: any }): BasePart
	local p: BasePart = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- Quader zwischen zwei Punkten (Oberkante auf Hoehe der Linie)
local function span(parent: Instance, a: Vector3, b: Vector3, width: number, height: number, props: { [string]: any }): BasePart
	local dir = b - a
	local length = dir.Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + dir)
	props.Size = Vector3.new(width, height, length)
	props.CFrame = cf * CFrame.new(0, -height / 2, 0)
	return make(parent, props)
end

local function heading(v: Vector3): number
	return math.atan2(v.X, v.Z)
end

local function turnAngle(a: Vector3, b: Vector3): number
	local d = heading(b) - heading(a)
	return math.abs((d + math.pi) % (2 * math.pi) - math.pi)
end

local function label(parent: BasePart, face: Enum.NormalId, text: string, color: Color3, stroke: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.LightInfluence = 0
	gui.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	t.TextColor3 = color
	t.Parent = gui
	local s = Instance.new("UIStroke")
	s.Color = stroke
	s.Thickness = 4
	s.Parent = t
	return t
end

---------------------------------------------------------------- Deko

local Props = {}

function Props.Tree(f, cf, s, rng)
	make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(10, 2.4, 2.4) * s, CFrame = cf * CFrame.new(0, 5 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood })
	local green = Color3.fromHSV(0.27 + rng:NextNumber() * 0.08, 0.6, 0.55 + rng:NextNumber() * 0.15)
	make(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * 11 * s, CFrame = cf * CFrame.new(0, 12 * s, 0), Color = green, Material = Enum.Material.Grass })
	make(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * 7 * s, CFrame = cf * CFrame.new(2.5 * s, 16 * s, 1 * s), Color = green, Material = Enum.Material.Grass })
end

function Props.Pine(f, cf, s, rng)
	make(f, { Size = Vector3.new(1.6, 6, 1.6) * s, CFrame = cf * CFrame.new(0, 3 * s, 0), Color = Color3.fromRGB(100, 70, 50), Material = Enum.Material.Wood })
	for tier = 0, 2 do
		local w = (9 - tier * 2.6) * s
		local y = (6 + tier * 4) * s
		make(f, { Size = Vector3.new(w, 4 * s, w), CFrame = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, math.rad(45 * tier), 0), Color = Color3.fromRGB(40, 100, 70), Material = Enum.Material.Grass })
		make(f, { Size = Vector3.new(w * 0.8, 0.8 * s, w * 0.8), CFrame = cf * CFrame.new(0, y + 2 * s, 0) * CFrame.Angles(0, math.rad(45 * tier), 0), Color = Color3.fromRGB(245, 250, 255), Material = Enum.Material.Snow })
	end
end

function Props.Palm(f, cf, s, rng)
	local lean = CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	local base = cf * lean
	local top = base
	for i = 0, 3 do
		local seg = base * CFrame.new(0, (2 + i * 3.6) * s, i * i * 0.35 * s) * CFrame.Angles(math.rad(8 * i), 0, 0)
		make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.8, 1.5, 1.5) * s, CFrame = seg * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood })
		top = seg
	end
	for k = 0, 5 do
		local leaf = top * CFrame.new(0, 2 * s, 0) * CFrame.Angles(0, k * math.pi / 3, 0) * CFrame.new(0, 0, -3.5 * s) * CFrame.Angles(math.rad(-20), 0, 0)
		make(f, { Size = Vector3.new(2.2, 0.4, 7) * s, CFrame = leaf, Color = Color3.fromRGB(60, 160, 70), Material = Enum.Material.Grass })
	end
end

function Props.Rock(f, cf, s, rng)
	for _ = 1, 3 do
		local size = Vector3.new(4 + rng:NextNumber() * 5, 3 + rng:NextNumber() * 4, 4 + rng:NextNumber() * 5) * s
		make(f, { Size = size, CFrame = cf * CFrame.new(rng:NextNumber(-3, 3) * s, size.Y * 0.35, rng:NextNumber(-3, 3) * s) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), Color = Color3.fromRGB(90, 80, 85), Material = Enum.Material.Slate })
	end
end

function Props.LavaPool(f, cf, s, rng)
	make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 18 * s, 18 * s), CFrame = cf * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 90, 10), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = FLAME
	light.Range = 30
	light.Brightness = 2
	light.Parent = f:GetChildren()[#f:GetChildren()]
	Props.Rock(f, cf * CFrame.new(9 * s, 0, 0), s * 0.6, rng)
end

function Props.Volcano(f, cf, s, rng)
	s *= 3
	for i = 0, 4 do
		local d = (40 - i * 7) * s
		make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(8 * s, d, d), CFrame = cf * CFrame.new(0, (4 + i * 8) * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60 - i * 4, 40, 40), Material = Enum.Material.Basalt })
	end
	local top = make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10 * s, 10 * s), CFrame = cf * CFrame.new(0, 44 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 80, 10), Material = Enum.Material.Neon })
	local fire = Instance.new("Fire")
	fire.Size = 25
	fire.Heat = 25
	fire.Parent = top
	local smoke = Instance.new("Smoke")
	smoke.Size = 30
	smoke.RiseVelocity = 20
	smoke.Color = Color3.fromRGB(60, 50, 50)
	smoke.Opacity = 0.2
	smoke.Parent = top
end

function Props.Stand(f, cf, s, rng)
	for row = 0, 4 do
		make(f, { Size = Vector3.new(40, 2, 4), CFrame = cf * CFrame.new(0, 1 + row * 2, row * 4), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Concrete })
		for seat = -9, 9, 2 do
			if rng:NextNumber() < 0.75 then
				make(f, { Size = Vector3.new(1.4, 2.2, 1.2), CFrame = cf * CFrame.new(seat * 2, 3 + row * 2, row * 4), Color = Color3.fromHSV(rng:NextNumber(), 0.7, 0.95) })
			end
		end
	end
	make(f, { Size = Vector3.new(42, 1, 22), CFrame = cf * CFrame.new(0, 16, 9) * CFrame.Angles(math.rad(-8), 0, 0), Color = Color3.fromRGB(255, 120, 30) })
end

function Props.Flag(f, cf, s, rng)
	make(f, { Size = Vector3.new(0.6, 16, 0.6), CFrame = cf * CFrame.new(0, 8, 0), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Metal })
	make(f, { Size = Vector3.new(0.2, 4, 6), CFrame = cf * CFrame.new(0, 14, 3), Color = if rng:NextNumber() < 0.5 then FLAME else GOLD })
end

function Props.Lollipop(f, cf, s, rng)
	make(f, { Size = Vector3.new(0.8, 14, 0.8) * s, CFrame = cf * CFrame.new(0, 7 * s, 0), Color = Color3.new(1, 1, 1) })
	make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 10, 10) * s, CFrame = cf * CFrame.new(0, 17 * s, 0) * CFrame.Angles(0, rng:NextNumber() * 6, 0), Color = Color3.fromHSV(rng:NextNumber(), 0.55, 1) })
	make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 5, 5) * s, CFrame = cf * CFrame.new(0, 17 * s, 0), Color = Color3.new(1, 1, 1) })
end

function Props.Candy(f, cf, s, rng)
	local color = Color3.fromHSV(rng:NextNumber(), 0.6, 1)
	local base = cf * CFrame.new(0, 3 * s, 0) * CFrame.Angles(0, rng:NextNumber() * 6, 0)
	make(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * 6 * s, CFrame = base, Color = color })
	for _, x in { -1, 1 } do
		make(f, { ClassName = "WedgePart", Size = Vector3.new(4, 4, 3) * s, CFrame = base * CFrame.new(x * 4 * s, 0, 0) * CFrame.Angles(0, x * math.pi / 2, 0), Color = color })
	end
end

function Props.Cupcake(f, cf, s, rng)
	make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 8, 8) * s, CFrame = cf * CFrame.new(0, 2.5 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(240, 170, 90) })
	make(f, { Shape = Enum.PartType.Ball, Size = Vector3.new(9, 6, 9) * s, CFrame = cf * CFrame.new(0, 6 * s, 0), Color = Color3.fromHSV(rng:NextNumber(), 0.35, 1) })
	make(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * 2 * s, CFrame = cf * CFrame.new(0, 9.5 * s, 0), Color = Color3.fromRGB(230, 30, 50) })
end

function Props.Crystal(f, cf, s, rng)
	for _ = 1, 3 do
		local h = rng:NextNumber(6, 14) * s
		make(f, { Size = Vector3.new(2.5 * s, h, 2.5 * s), CFrame = cf * CFrame.new(rng:NextNumber(-2, 2) * s, h * 0.4, rng:NextNumber(-2, 2) * s) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), Color = Color3.fromRGB(140, 210, 255), Material = Enum.Material.Ice, Transparency = 0.2 })
	end
end

function Props.Snowman(f, cf, s, rng)
	local snow = { Color = Color3.fromRGB(250, 252, 255), Material = Enum.Material.Snow }
	for i, d in { 6, 4.5, 3.2 } do
		local props = table.clone(snow)
		props.Shape = Enum.PartType.Ball
		props.Size = Vector3.one * d * s
		props.CFrame = cf * CFrame.new(0, ({ 3, 7.5, 11 })[i] * s, 0)
		make(f, props)
	end
	make(f, { Size = Vector3.new(0.5, 0.5, 2) * s, CFrame = cf * CFrame.new(0, 11 * s, -1.8 * s), Color = FLAME })
end

function Props.Tower(f, cf, s, rng)
	local h = rng:NextNumber(40, 110)
	local w = rng:NextNumber(14, 24)
	make(f, { Size = Vector3.new(w, h, w), CFrame = cf * CFrame.new(0, h / 2, 0), Color = Color3.fromRGB(25, 25, 38), Material = Enum.Material.Glass, Reflectance = 0.15 })
	local neon = Color3.fromHSV(({ 0.52, 0.85, 0.12, 0.75 })[rng:NextInteger(1, 4)], 0.8, 1)
	for y = 8, h - 4, 12 do
		make(f, { Size = Vector3.new(w + 0.4, 0.6, w + 0.4), CFrame = cf * CFrame.new(0, y, 0), Color = neon, Material = Enum.Material.Neon })
	end
end

function Props.Lamp(f, cf, s, rng)
	make(f, { Size = Vector3.new(0.8, 18, 0.8), CFrame = cf * CFrame.new(0, 9, 0), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
	local bulb = make(f, { Size = Vector3.new(3, 1, 3), CFrame = cf * CFrame.new(0, 18, 0), Color = Color3.fromRGB(0, 230, 255), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Color = bulb.Color
	light.Range = 35
	light.Brightness = 2
	light.Parent = bulb
end

function Props.Ruin(f, cf, s, rng)
	for i = 0, rng:NextInteger(2, 4) do
		local h = rng:NextNumber(5, 16)
		make(f, { Size = Vector3.new(3.5, h, 3.5), CFrame = cf * CFrame.new(i * 6 - 6, h / 2, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)), Color = Color3.fromRGB(150, 145, 125), Material = Enum.Material.Cobblestone })
	end
	make(f, { Size = Vector3.new(20, 2, 4), CFrame = cf * CFrame.new(0, 1, 5) * CFrame.Angles(0, 0.3, 0), Color = Color3.fromRGB(120, 140, 90), Material = Enum.Material.Cobblestone })
end

function Props.Cactus(f, cf, s, rng)
	local green = { Color = Color3.fromRGB(70, 150, 70), Material = Enum.Material.Grass }
	local function piece(size, at)
		local props = table.clone(green)
		props.Size = size * s
		props.CFrame = cf * at
		make(f, props)
	end
	piece(Vector3.new(2.4, 12, 2.4), CFrame.new(0, 6 * s, 0))
	piece(Vector3.new(4, 1.6, 1.6), CFrame.new(2 * s, 5 * s, 0))
	piece(Vector3.new(1.6, 4, 1.6), CFrame.new(3.4 * s, 7 * s, 0))
	piece(Vector3.new(4, 1.6, 1.6), CFrame.new(-2 * s, 8 * s, 0))
	piece(Vector3.new(1.6, 3, 1.6), CFrame.new(-3.4 * s, 9.5 * s, 0))
end

function Props.Pyramid(f, cf, s, rng)
	s *= 2
	for i = 0, 6 do
		local w = (40 - i * 5.5) * s
		make(f, { Size = Vector3.new(w, 4 * s, w), CFrame = cf * CFrame.new(0, (2 + i * 4) * s, 0), Color = Color3.fromRGB(220, 185, 120), Material = Enum.Material.Sandstone })
	end
end

function Props.Asteroid(f, cf, s, rng)
	local d = rng:NextNumber(8, 26)
	make(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * d, CFrame = cf * CFrame.new(0, rng:NextNumber(-60, 90), 0), Color = Color3.fromRGB(110, 100, 130), Material = Enum.Material.Slate })
end

function Props.Planet(f, cf, s, rng)
	local d = rng:NextNumber(60, 140)
	local at = cf * CFrame.new(0, rng:NextNumber(60, 200), 0)
	make(f, { Shape = Enum.PartType.Ball, Size = Vector3.one * d, CFrame = at, Color = Color3.fromHSV(rng:NextNumber(), 0.6, 0.9), Material = Enum.Material.SmoothPlastic })
	make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, d * 1.7, d * 1.7), CFrame = at * CFrame.Angles(0.4, 0, math.pi / 2 + 0.3), Color = Color3.fromRGB(230, 200, 255), Material = Enum.Material.Neon, Transparency = 0.5 })
end

function Props.Umbrella(f, cf, s, rng)
	make(f, { Size = Vector3.new(0.5, 9, 0.5), CFrame = cf * CFrame.new(0, 4.5, 0), Color = Color3.new(1, 1, 1) })
	make(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 10, 10), CFrame = cf * CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHSV(rng:NextNumber(), 0.7, 1) })
	make(f, { Size = Vector3.new(3, 0.4, 6), CFrame = cf * CFrame.new(4, 0.3, 0), Color = Color3.fromHSV(rng:NextNumber(), 0.5, 1) })
end

function Props.DeadTree(f, cf, s, rng)
	local bark = Color3.fromRGB(45, 38, 40)
	make(f, { Size = Vector3.new(2, 14, 2) * s, CFrame = cf * CFrame.new(0, 7 * s, 0), Color = bark, Material = Enum.Material.Wood })
	for k = 0, 3 do
		make(f, { Size = Vector3.new(0.8, 6, 0.8) * s, CFrame = cf * CFrame.new(0, (9 + k * 1.3) * s, 0) * CFrame.Angles(0, k * 1.7, 0.8) * CFrame.new(0, 3 * s, 0), Color = bark, Material = Enum.Material.Wood })
	end
end

function Props.Pumpkin(f, cf, s, rng)
	local p = make(f, { Shape = Enum.PartType.Ball, Size = Vector3.new(6, 4.5, 6) * s, CFrame = cf * CFrame.new(0, 2.2 * s, 0), Color = Color3.fromRGB(255, 130, 20) })
	make(f, { Size = Vector3.new(0.6, 1.5, 0.6) * s, CFrame = cf * CFrame.new(0, 5 * s, 0), Color = Color3.fromRGB(60, 110, 40) })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 40)
	light.Range = 16
	light.Parent = p
end

function Props.Grave(f, cf, s, rng)
	make(f, { Size = Vector3.new(3, 4.5, 0.8), CFrame = cf * CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)), Color = Color3.fromRGB(120, 120, 130), Material = Enum.Material.Slate })
end

---------------------------------------------------------------- Licht

local function applyLighting(theme)
	Lighting.ClockTime = theme.ClockTime
	Lighting.Ambient = theme.Ambient
	Lighting.OutdoorAmbient = theme.Ambient
	Lighting.Brightness = if theme.ClockTime > 6 and theme.ClockTime < 18.5 then 2.2 else 1.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = if theme.Void then 0.05 else 0.28
	atmosphere.Color = theme.Fog
	atmosphere.Decay = theme.Fog:Lerp(Color3.new(0, 0, 0), 0.4)
	atmosphere.Haze = theme.Haze
	atmosphere.Glare = 0.2
	atmosphere.Parent = Lighting
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.12
	grade.Contrast = 0.08
	grade.Parent = Lighting
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = if theme.Void then 6000 else 3000
	sky.Parent = Lighting
end

---------------------------------------------------------------- Strecke

function TrackService:Init(services)
	self.Services = services
end

local function itemBox(parent: Instance, cf: CFrame): BasePart
	local box = make(parent, {
		Name = "ItemBox",
		Size = Vector3.new(3.6, 3.6, 3.6),
		CFrame = cf,
		Color = Color3.fromRGB(255, 160, 40),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
	})
	local core = make(box, { Name = "Core", Size = Vector3.new(1.7, 1.7, 1.7), CFrame = cf, Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false })
	core.Parent = box
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(3, 3)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = box
	local q = Instance.new("TextLabel")
	q.BackgroundTransparency = 1
	q.Size = UDim2.fromScale(1, 1)
	q.Text = "?"
	q.TextScaled = true
	q.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy)
	q.TextColor3 = Color3.new(1, 1, 1)
	q.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(200, 60, 0)
	stroke.Parent = q
	CollectionService:AddTag(box, "Spin")
	CollectionService:AddTag(box, "Rainbow")
	return box
end

local function coin(parent: Instance, cf: CFrame): BasePart
	local c = make(parent, {
		Name = "Coin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 2.6, 2.6),
		CFrame = cf * CFrame.Angles(0, math.pi / 2, 0),
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
	})
	CollectionService:AddTag(c, "Spin")
	return c
end

function TrackService:Load(trackId: string)
	if self.Current then
		self.Current.Folder:Destroy()
		self.Current = nil
	end
	local def = Tracks.ById[trackId]
	local theme = Tracks.Themes[def.Theme]
	local geo = Tracks.Geometry(trackId)
	local n = geo.Count
	local P, R, T = geo.Points, geo.Rights, geo.Tangents
	local W = def.Width
	local rng = Random.new(#trackId * 7919 + def.Order)

	local folder = Instance.new("Folder")
	folder.Name = "Track"
	local road = Instance.new("Folder")
	road.Name = "Road"
	road.Parent = folder
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = folder
	local deco = Instance.new("Folder")
	deco.Name = "Deco"
	deco.Parent = folder
	local boxesFolder = Instance.new("Folder")
	boxesFolder.Name = "Boxes"
	boxesFolder.Parent = folder
	local coinsFolder = Instance.new("Folder")
	coinsFolder.Name = "Coins"
	coinsFolder.Parent = folder

	-- Fahrbahn: ein Quader pro Abschnitt, an den Enden um den Kurvenwinkel verlaengert (keine Luecken aussen)
	for i = 1, n do
		local j = i % n + 1
		local prev = (i - 2) % n + 1
		local nxt = j % n + 1
		local a, b = P[i], P[j]
		local dir = (b - a).Unit
		local extA = W / 2 * math.tan(turnAngle(a - P[prev], b - a) / 2) + 0.3
		local extB = W / 2 * math.tan(turnAngle(b - a, P[nxt] - b) / 2) + 0.3
		span(road, a - dir * extA, b + dir * extB, W, 1.2, {
			Name = "Road",
			Color = theme.Road,
			Material = theme.RoadMaterial,
			CanCollide = true, -- Sicherheitsnetz: das Kart schwebt per Raycast, faellt aber nie durch
		})
		-- Curbs und Waende entlang der Seiten
		for _, side in { -1, 1 } do
			local ca = a + R[i] * side * (W / 2 - 1)
			local cb = b + R[j] * side * (W / 2 - 1)
			local curbColor = if i % 2 == 0 then theme.CurbA else theme.CurbB
			span(road, ca + Vector3.new(0, 0.12, 0), cb + Vector3.new(0, 0.12, 0), 2.2, 1.3, {
				Name = "Curb",
				Color = curbColor,
				Material = if theme.NeonCurbs and i % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
				CanCollide = true,
			})
			local wa = a + R[i] * side * (W / 2 + 0.8)
			local wb = b + R[j] * side * (W / 2 + 0.8)
			local wall = span(walls, wa + Vector3.new(0, 3.2, 0), wb + Vector3.new(0, 3.2, 0), 1.6, 4.4, {
				Name = "Wall",
				Color = if theme.Void then theme.Wall elseif i % 8 < 4 then theme.Wall else theme.Wall:Lerp(theme.Accent, 0.5),
				Material = theme.WallMaterial,
				Transparency = if theme.Void then 0.35 else 0,
				CanCollide = true,
			})
			wall.Size += Vector3.new(0, 0, 0.6)
			-- Stuetzen unter erhoehten Abschnitten
			if i % 6 == 0 and not theme.Void and a.Y > 8 then
				local base = a + R[i] * side * (W / 2 - 3)
				make(deco, { Size = Vector3.new(3, base.Y, 3), CFrame = CFrame.new(base.X, base.Y / 2 - 0.6, base.Z), Color = theme.Wall, Material = theme.WallMaterial })
			end
		end
		if theme.Void and i % 4 == 0 then
			-- Leuchtende Unterseite fuer den Sternen-Highway
			span(deco, a - Vector3.new(0, 1.1, 0), b - Vector3.new(0, 1.1, 0), W * 0.6, 0.3, { Color = theme.Accent, Material = Enum.Material.Neon, CanQuery = false, CanCollide = false })
		end
	end

	-- Boden
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, p in P do
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local center = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2)
	local sizeX, sizeZ = maxX - minX + 500, maxZ - minZ + 500
	if not theme.Void then
		make(deco, { Name = "Ground", Size = Vector3.new(sizeX, 4, sizeZ), CFrame = CFrame.new(center - Vector3.new(0, 2, 0)), Color = theme.Ground, Material = theme.GroundMaterial, CanCollide = true })
		if theme.Water then
			make(deco, { Name = "Sea", Size = Vector3.new(sizeX + 3000, 1, sizeZ + 3000), CFrame = CFrame.new(center - Vector3.new(0, 1.6, 0)), Color = theme.Water, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.2, CanCollide = true })
		end
	end

	-- Start: Schachbrett-Linie und Tor mit Startampel
	local startCf = CFrame.lookAt(P[1], P[1] + T[1])
	for x = 0, 9 do
		for z = 0, 1 do
			make(road, {
				Name = "StartLine",
				Size = Vector3.new(W / 10, 0.1, 2),
				CFrame = startCf * CFrame.new(-W / 2 + W / 20 + x * W / 10, 0.06, -1 + z * 2),
				Color = if (x + z) % 2 == 0 then Color3.new(1, 1, 1) else Color3.fromRGB(20, 20, 25),
				CanCollide = false,
			})
		end
	end
	local gate = Instance.new("Model")
	gate.Name = "StartGate"
	gate.Parent = folder
	for _, side in { -1, 1 } do
		make(gate, { Size = Vector3.new(3, 22, 3), CFrame = startCf * CFrame.new(side * (W / 2 + 3), 11, 0), Color = Color3.fromRGB(30, 28, 36), Material = Enum.Material.Metal })
	end
	local beam = make(gate, { Name = "Banner", Size = Vector3.new(W + 9, 5, 2), CFrame = startCf * CFrame.new(0, 21, 0), Color = Color3.fromRGB(25, 22, 30), Material = Enum.Material.Metal })
	label(beam, Enum.NormalId.Front, "FIRE BLASTER RACE", Color3.fromRGB(255, 200, 60), Color3.fromRGB(200, 40, 0))
	label(beam, Enum.NormalId.Back, def.Name:upper(), Color3.fromRGB(255, 200, 60), Color3.fromRGB(200, 40, 0))
	make(gate, { Size = Vector3.new(W + 9, 0.4, 2.2), CFrame = startCf * CFrame.new(0, 18.4, 0), Color = FLAME, Material = Enum.Material.Neon })
	local lights = {}
	for k = 1, 4 do
		lights[k] = make(gate, { Name = "Light", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = startCf * CFrame.new((k - 2.5) * 4, 16, 1.3), Color = Color3.fromRGB(40, 20, 20), Material = Enum.Material.Neon })
	end

	-- Boost-Pads
	for k, f in def.Boosts do
		local i = math.floor(f * n) + 1
		local side = if k % 2 == 0 then 0.35 else -0.35
		local pos = P[i] + R[i] * side * W / 2
		local pad = make(road, {
			Name = "BoostPad",
			Size = Vector3.new(9, 0.3, 12),
			CFrame = CFrame.lookAt(pos, pos + T[i]) * CFrame.new(0, 0.1, 0),
			Color = FLAME,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		pad:SetAttribute("BoostPad", true)
		label(pad, Enum.NormalId.Top, ">>", Color3.fromRGB(255, 250, 220), Color3.fromRGB(255, 60, 0)).Rotation = -90
		CollectionService:AddTag(pad, "Pulse")
	end

	-- Item-Boxen und Muenzen
	local boxes = {}
	for _, f in def.Items do
		local i = math.floor(f * n) + 1
		for _, lat in { -0.6, -0.2, 0.2, 0.6 } do
			local pos = P[i] + R[i] * lat * W / 2 + Vector3.new(0, 2.8, 0)
			table.insert(boxes, { Part = itemBox(boxesFolder, CFrame.new(pos)), Position = pos, ReadyAt = 0 })
		end
	end
	local coins = {}
	for _, f in def.Coins do
		local i0 = math.floor(f * n) + 1
		local lat = rng:NextNumber(-0.55, 0.55)
		for k = 0, 4 do
			local i = (i0 - 1 + k) % n + 1
			local pos = P[i] + R[i] * lat * W / 2 + Vector3.new(0, 2, 0)
			table.insert(coins, { Part = coin(coinsFolder, CFrame.lookAt(pos, pos + T[i])), Position = pos, ReadyAt = 0 })
		end
	end

	-- Deko neben der Strecke
	local kinds = theme.Props
	local placed = 0
	local tries = 0
	while placed < 110 and tries < 900 do
		tries += 1
		local x = rng:NextNumber(minX - 180, maxX + 180)
		local z = rng:NextNumber(minZ - 180, maxZ + 180)
		local kind = kinds[rng:NextInteger(1, #kinds)]
		local big = kind == "Volcano" or kind == "Pyramid" or kind == "Stand" or kind == "Tower" or kind == "Planet"
		local clearance = W / 2 + (if big then 70 else 14)
		local ok = true
		for k = 1, n, 2 do
			local p = P[k]
			if (Vector2.new(p.X - x, p.Z - z)).Magnitude < clearance then
				ok = false
				break
			end
		end
		if ok and (kind ~= "Volcano" and kind ~= "Pyramid" or rng:NextNumber() < 0.08) then
			local cf = CFrame.new(x, if theme.Void then rng:NextNumber(-40, 20) else 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			if kind == "Stand" then
				-- Tribuenen schauen zur Strecke
				local nearest = Tracks.Nearest(geo, Vector3.new(x, 2, z))
				cf = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(P[nearest].X, 0, P[nearest].Z)) * CFrame.Angles(0, math.pi, 0)
			end
			local model = Instance.new("Model")
			model.Name = kind
			Props[kind](model, cf, rng:NextNumber(0.8, 1.4), rng)
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					d.CanQuery = false
				end
			end
			model.Parent = deco
			placed += 1
		end
	end

	applyLighting(theme)
	folder.Parent = workspace

	self.Current = {
		Id = trackId,
		Def = def,
		Theme = theme,
		Geometry = geo,
		Folder = folder,
		Boxes = boxes,
		Coins = coins,
		Lights = lights,
		RoadFolder = road,
	}
	workspace:SetAttribute("TrackId", trackId)
	return self.Current
end

-- Startplatz k (1 = vorne): zwei Reihen versetzt hinter der Startlinie
function TrackService:GridCFrame(slot: number): CFrame
	local current = self.Current
	local geo = current.Geometry
	local row = (slot - 1) // 2
	local col = (slot - 1) % 2
	local i = (geo.Count - 2 - row * 2 - 1) % geo.Count + 1
	local lateral = (if col == 0 then -0.32 else 0.32) * geo.Width
	local pos = geo.Points[i] + geo.Rights[i] * lateral + Vector3.new(0, 4, 0)
	return CFrame.lookAt(pos, pos + Vector3.new(geo.Tangents[i].X, 0, geo.Tangents[i].Z))
end

function TrackService:SetLights(count: number, go: boolean)
	local current = self.Current
	if not current then
		return
	end
	for k, light in current.Lights do
		if go then
			light.Color = Color3.fromRGB(60, 255, 90)
		elseif k <= count then
			light.Color = Color3.fromRGB(255, 50, 30)
		else
			light.Color = Color3.fromRGB(40, 20, 20)
		end
	end
end

return TrackService
