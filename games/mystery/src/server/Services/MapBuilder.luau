-- Baut Lobby und Runden-Karten per Code: Raster aus Raeumen mit Tueren, Moebeln, Lampen,
-- Verstecken (Schraenke), Lueftungsschaechten (nur Murderer), Muenz- und Power-Up-Punkten.
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local S = Config.RoomSize
local H = Config.WallHeight
local DOOR = 11

---------------------------------------------------------------- Helfer

local function new(parent: Instance, props): BasePart
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function deco(parent: Instance, props): BasePart
	local p = new(parent, props)
	p.CanCollide = props.CanCollide == true
	p.CastShadow = false
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function sign(parent: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.fromRGB(10, 10, 30)
	stroke.Parent = label
	return label
end

-- Einfacher deterministischer Zufall pro Karte
local function rng(seed: number)
	local r = Random.new(seed)
	return function(a: number?, b: number?)
		if a and b then
			return r:NextInteger(a, b)
		end
		return r:NextNumber()
	end
end

---------------------------------------------------------------- Themen

local THEMES = {
	Manor = {
		Floor = { Color3.fromRGB(110, 70, 45), Enum.Material.WoodPlanks },
		Floor2 = { Color3.fromRGB(140, 40, 50), Enum.Material.Fabric },
		Wall = Color3.fromRGB(70, 60, 100),
		Wall2 = Color3.fromRGB(120, 90, 70),
		Trim = Color3.fromRGB(60, 40, 30),
		Lamp = Color3.fromRGB(255, 200, 130),
		Rooms = { "Lounge", "Library", "Bedroom", "Kitchen", "Dining", "Bedroom", "Library", "Lounge", "Bath" },
		Ambient = Color3.fromRGB(60, 55, 90),
	},
	Arcade = {
		Floor = { Color3.fromRGB(30, 26, 50), Enum.Material.Carpet },
		Floor2 = { Color3.fromRGB(40, 40, 60), Enum.Material.SmoothPlastic },
		Wall = Color3.fromRGB(35, 30, 70),
		Wall2 = Color3.fromRGB(60, 20, 70),
		Trim = Color3.fromRGB(255, 80, 200),
		Lamp = Color3.fromRGB(150, 120, 255),
		Neon = true,
		Rooms = { "Arcade", "Food", "Arcade", "Prize", "Arcade", "Food", "Bowling", "Arcade" },
		Ambient = Color3.fromRGB(70, 50, 110),
	},
	Lodge = {
		Floor = { Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks },
		Floor2 = { Color3.fromRGB(230, 235, 245), Enum.Material.Snow },
		Wall = Color3.fromRGB(130, 90, 55),
		Wall2 = Color3.fromRGB(110, 75, 45),
		Trim = Color3.fromRGB(70, 45, 25),
		Lamp = Color3.fromRGB(255, 180, 110),
		Log = true,
		Rooms = { "Lounge", "Kitchen", "Bedroom", "Bedroom", "Storage", "Dining", "Lounge", "Bath", "Storage" },
		Ambient = Color3.fromRGB(70, 75, 110),
	},
	School = {
		Floor = { Color3.fromRGB(170, 170, 160), Enum.Material.Marble },
		Floor2 = { Color3.fromRGB(110, 120, 100), Enum.Material.SmoothPlastic },
		Wall = Color3.fromRGB(110, 140, 120),
		Wall2 = Color3.fromRGB(150, 140, 110),
		Trim = Color3.fromRGB(60, 70, 60),
		Lamp = Color3.fromRGB(210, 230, 255),
		Rooms = { "Classroom", "Classroom", "Lockers", "Classroom", "Library", "Lockers", "Cafeteria", "Classroom", "Gym", "Classroom", "Lockers", "Classroom" },
		Ambient = Color3.fromRGB(60, 70, 80),
	},
	Lab = {
		Floor = { Color3.fromRGB(200, 205, 215), Enum.Material.DiamondPlate },
		Floor2 = { Color3.fromRGB(60, 70, 90), Enum.Material.Metal },
		Wall = Color3.fromRGB(190, 200, 215),
		Wall2 = Color3.fromRGB(70, 80, 110),
		Trim = Color3.fromRGB(80, 220, 255),
		Lamp = Color3.fromRGB(170, 230, 255),
		Neon = true,
		Rooms = { "Lab", "Server", "Lab", "Storage", "Reactor", "Lab", "Server", "Lab", "Storage" },
		Ambient = Color3.fromRGB(60, 80, 110),
	},
	-- Update: Mitternachts-Museum (Gemaelde, Fossilien, Edelsteine, Statuen)
	Museum = {
		Floor = { Color3.fromRGB(200, 190, 175), Enum.Material.Marble },
		Floor2 = { Color3.fromRGB(120, 40, 50), Enum.Material.Carpet },
		Wall = Color3.fromRGB(215, 205, 190),
		Wall2 = Color3.fromRGB(80, 60, 90),
		Trim = Color3.fromRGB(190, 150, 60),
		Lamp = Color3.fromRGB(255, 230, 180),
		Rooms = { "Gallery", "Fossil", "Gems", "Gallery", "Statue", "Gallery", "Storage", "Gems" },
		Ambient = Color3.fromRGB(70, 65, 95),
	},
}
MapBuilder.Themes = THEMES

---------------------------------------------------------------- Moebel (relativ zur Raummitte, CFrame cf)

local Furniture = {}

local function wood(r: any): Color3
	return Color3.fromRGB(110 + math.floor(r() * 40), 70 + math.floor(r() * 25), 40)
end

function Furniture.Table(m: Model, cf: CFrame, color: Color3, w: number, d: number)
	new(m, { Name = "Top", Size = Vector3.new(w, 0.5, d), CFrame = cf * CFrame.new(0, 3, 0), Color = color, Material = Enum.Material.Wood })
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			new(m, { Name = "Leg", Size = Vector3.new(0.5, 2.8, 0.5), CFrame = cf * CFrame.new(x * (w / 2 - 0.5), 1.4, z * (d / 2 - 0.5)), Color = color:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Wood })
		end
	end
end

function Furniture.Chair(m: Model, cf: CFrame, color: Color3)
	new(m, { Name = "Seat", Size = Vector3.new(2, 0.4, 2), CFrame = cf * CFrame.new(0, 1.8, 0), Color = color, Material = Enum.Material.Wood })
	new(m, { Name = "Back", Size = Vector3.new(2, 2.4, 0.3), CFrame = cf * CFrame.new(0, 3.1, 0.85), Color = color, Material = Enum.Material.Wood })
	new(m, { Name = "Base", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = cf * CFrame.new(0, 0.8, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.Wood, Transparency = 0 })
end

function Furniture.Sofa(m: Model, cf: CFrame, color: Color3)
	new(m, { Name = "Seat", Size = Vector3.new(8, 1.6, 3.4), CFrame = cf * CFrame.new(0, 1, 0), Color = color, Material = Enum.Material.Fabric })
	new(m, { Name = "Back", Size = Vector3.new(8, 2.6, 1), CFrame = cf * CFrame.new(0, 2.6, 1.3), Color = color, Material = Enum.Material.Fabric })
	for x = -1, 1, 2 do
		new(m, { Name = "Arm", Size = Vector3.new(1, 2.4, 3.4), CFrame = cf * CFrame.new(x * 4, 1.6, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Fabric })
	end
end

function Furniture.Bed(m: Model, cf: CFrame, color: Color3)
	new(m, { Name = "Frame", Size = Vector3.new(6, 1.6, 9), CFrame = cf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood })
	new(m, { Name = "Mattress", Size = Vector3.new(5.6, 0.9, 8.4), CFrame = cf * CFrame.new(0, 2, 0), Color = Color3.fromRGB(240, 240, 245), Material = Enum.Material.Fabric })
	new(m, { Name = "Blanket", Size = Vector3.new(5.8, 0.4, 5.5), CFrame = cf * CFrame.new(0, 2.5, -1.4), Color = color, Material = Enum.Material.Fabric })
	new(m, { Name = "Pillow", Size = Vector3.new(3.4, 0.7, 1.6), CFrame = cf * CFrame.new(0, 2.7, 3.2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Fabric })
	new(m, { Name = "Head", Size = Vector3.new(6, 4.4, 0.6), CFrame = cf * CFrame.new(0, 2.2, 4.4), Color = Color3.fromRGB(90, 60, 40), Material = Enum.Material.Wood })
end

function Furniture.Shelf(m: Model, cf: CFrame, color: Color3, r: any)
	new(m, { Name = "Shelf", Size = Vector3.new(8, 9, 2), CFrame = cf * CFrame.new(0, 4.5, 0), Color = color, Material = Enum.Material.Wood })
	for row = 0, 3 do
		local x = -3.4
		while x < 3.4 do
			local w = 0.4 + r() * 0.5
			local h = 1.2 + r() * 0.6
			deco(m, { Name = "Book", Size = Vector3.new(w, h, 1.4), CFrame = cf * CFrame.new(x + w / 2, 1 + row * 2.1 + h / 2, -0.4), Color = Color3.fromHSV(r(), 0.55, 0.75) })
			x += w + 0.05
		end
	end
end

function Furniture.Counter(m: Model, cf: CFrame, length: number, color: Color3)
	new(m, { Name = "Counter", Size = Vector3.new(length, 3.6, 3), CFrame = cf * CFrame.new(0, 1.8, 0), Color = color, Material = Enum.Material.Wood })
	new(m, { Name = "CounterTop", Size = Vector3.new(length + 0.2, 0.3, 3.2), CFrame = cf * CFrame.new(0, 3.75, 0), Color = Color3.fromRGB(230, 230, 235), Material = Enum.Material.Marble })
end

function Furniture.Plant(m: Model, cf: CFrame)
	new(m, { Name = "Pot", Size = Vector3.new(1.8, 1.8, 1.8), CFrame = cf * CFrame.new(0, 0.9, 0), Color = Color3.fromRGB(170, 90, 60), Material = Enum.Material.Slate })
	deco(m, { Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3.4, 3), CFrame = cf * CFrame.new(0, 3.2, 0), Color = Color3.fromRGB(50, 130, 60), Material = Enum.Material.Grass, CanCollide = true })
end

function Furniture.Lamp(m: Model, cf: CFrame, color: Color3)
	new(m, { Name = "Pole", Size = Vector3.new(0.4, 6, 0.4), CFrame = cf * CFrame.new(0, 3, 0), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal })
	local shade = deco(m, { Name = "Shade", Size = Vector3.new(1.8, 1.4, 1.8), CFrame = cf * CFrame.new(0, 6.4, 0), Color = color, Material = Enum.Material.Neon })
	light(shade, color, 14, 1.2)
	shade:AddTag("Lamp")
end

function Furniture.Rug(m: Model, cf: CFrame, color: Color3, w: number, d: number)
	deco(m, { Name = "Rug", Size = Vector3.new(w, 0.1, d), CFrame = cf * CFrame.new(0, 0.05, 0), Color = color, Material = Enum.Material.Fabric })
	deco(m, { Name = "RugInner", Size = Vector3.new(w - 1.6, 0.12, d - 1.6), CFrame = cf * CFrame.new(0, 0.06, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.25), Material = Enum.Material.Fabric })
end

function Furniture.Crate(m: Model, cf: CFrame, size: number)
	new(m, { Name = "Crate", Size = Vector3.new(size, size, size), CFrame = cf * CFrame.new(0, size / 2, 0), Color = Color3.fromRGB(160, 120, 70), Material = Enum.Material.WoodPlanks })
end

function Furniture.Cabinet(m: Model, cf: CFrame, color: Color3)
	new(m, { Name = "Cabinet", Size = Vector3.new(3.4, 7, 3), CFrame = cf * CFrame.new(0, 3.5, 0), Color = Color3.fromRGB(30, 30, 40) })
	local screen = deco(m, { Name = "Screen", Size = Vector3.new(2.6, 2.2, 0.2), CFrame = cf * CFrame.new(0, 5, -1.55), Color = color, Material = Enum.Material.Neon })
	light(screen, color, 8, 1)
	deco(m, { Name = "Panel", Size = Vector3.new(3, 0.4, 1.2), CFrame = cf * CFrame.new(0, 3.4, -1.9) * CFrame.Angles(math.rad(20), 0, 0), Color = Color3.fromRGB(60, 60, 70), CanCollide = true })
	for i = -1, 1 do
		deco(m, { Name = "Button", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), CFrame = cf * CFrame.new(i * 0.7, 3.7, -2), Color = Color3.fromHSV((i + 1) / 3, 0.8, 1), Material = Enum.Material.Neon })
	end
end

function Furniture.Desk(m: Model, cf: CFrame, color: Color3)
	new(m, { Name = "Desk", Size = Vector3.new(4, 0.4, 2.6), CFrame = cf * CFrame.new(0, 2.6, 0), Color = color, Material = Enum.Material.Wood })
	new(m, { Name = "DeskLegs", Size = Vector3.new(3.6, 2.4, 0.3), CFrame = cf * CFrame.new(0, 1.2, 1), Color = Color3.fromRGB(60, 60, 70), Material = Enum.Material.Metal })
	Furniture.Chair(m, cf * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, 0) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(70, 90, 160))
end

function Furniture.Bench(m: Model, cf: CFrame, r: any)
	new(m, { Name = "Bench", Size = Vector3.new(10, 3.6, 3.4), CFrame = cf * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(230, 235, 240), Material = Enum.Material.SmoothPlastic })
	for i = -1, 1 do
		local c = Color3.fromHSV(r(), 0.7, 1)
		local tube = deco(m, { Name = "Flask", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 0.8, 0.8), CFrame = cf * CFrame.new(i * 3, 4.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = c, Material = Enum.Material.Neon, Transparency = 0.2 })
		light(tube, c, 6, 0.8)
	end
end

function Furniture.Tank(m: Model, cf: CFrame, color: Color3)
	new(m, { Name = "TankBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 5, 5), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 70, 90), Material = Enum.Material.Metal })
	local glass = new(m, { Name = "Tank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 4.4, 4.4), CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.Glass, Transparency = 0.45 })
	light(glass, color, 14, 1.2)
	glass:AddTag("Lamp")
end

-- Versteck: Schrank mit "Hide"-Prompt; die Spiellogik haengt am Tag "Closet"
function Furniture.Closet(m: Model, cf: CFrame, color: Color3, locker: boolean)
	local closet = Instance.new("Model")
	closet.Name = "Closet"
	local w = if locker then 3.4 else 5
	new(closet, { Name = "Back", Size = Vector3.new(w, 8, 0.4), CFrame = cf * CFrame.new(0, 4, 1.6), Color = color, Material = if locker then Enum.Material.Metal else Enum.Material.Wood })
	for x = -1, 1, 2 do
		new(closet, { Name = "Side", Size = Vector3.new(0.4, 8, 3.6), CFrame = cf * CFrame.new(x * (w / 2 - 0.2), 4, 0), Color = color, Material = if locker then Enum.Material.Metal else Enum.Material.Wood })
	end
	new(closet, { Name = "Top", Size = Vector3.new(w, 0.4, 3.6), CFrame = cf * CFrame.new(0, 8.2, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Wood })
	local door = new(closet, { Name = "Door", Size = Vector3.new(w - 0.4, 7.8, 0.3), CFrame = cf * CFrame.new(0, 4, -1.65), Color = color:Lerp(Color3.new(1, 1, 1), 0.1), Material = if locker then Enum.Material.Metal else Enum.Material.Wood })
	if locker then
		for i = 0, 2 do
			deco(closet, { Name = "Slot", Size = Vector3.new(w - 1.4, 0.15, 0.1), CFrame = cf * CFrame.new(0, 6.5 + i * 0.4, -1.85), Color = Color3.fromRGB(30, 30, 30) })
		end
	else
		deco(closet, { Name = "Knob", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), CFrame = cf * CFrame.new(w / 2 - 0.9, 4, -1.9), Color = Config.Colors.Moon, Material = Enum.Material.Metal })
	end
	local inside = Instance.new("Attachment")
	inside.Name = "Inside"
	inside.CFrame = door.CFrame:ToObjectSpace(cf * CFrame.new(0, 3, 0.2))
	inside.Parent = door
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Hide"
	prompt.ObjectText = "Closet"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0.2
	prompt.RequiresLineOfSight = false
	prompt.Parent = door
	closet:AddTag("Closet")
	closet.PrimaryPart = door
	closet.Parent = m
	return closet
end

---------------------------------------------------------------- Raeume

local function furnish(m: Model, kind: string, cf: CFrame, theme, r: any, extras)
	local half = S / 2 - 3
	local function wallSpot(side: number, offset: number): CFrame
		-- side 0..3: Nord/Ost/Sued/West, Moebel schauen zur Raummitte
		local angle = side * math.pi / 2
		return cf * CFrame.Angles(0, angle, 0) * CFrame.new(offset, 0, half)
	end
	local woodColor = wood(r)
	local accent = Color3.fromHSV(r(), 0.5, 0.75)
	local closetSide = r(0, 3)

	if kind == "Lounge" then
		Furniture.Rug(m, cf, accent, 18, 14)
		Furniture.Sofa(m, wallSpot((closetSide + 1) % 4, 0), accent)
		Furniture.Sofa(m, cf * CFrame.new(0, 0, -6) * CFrame.Angles(0, math.pi, 0), accent)
		Furniture.Table(m, cf, woodColor, 6, 3.5)
		Furniture.Lamp(m, wallSpot((closetSide + 2) % 4, 10), theme.Lamp)
		Furniture.Plant(m, wallSpot((closetSide + 3) % 4, -12))
		-- Kamin
		local fp = wallSpot((closetSide + 3) % 4, 4)
		new(m, { Name = "Fireplace", Size = Vector3.new(8, 7, 2.5), CFrame = fp * CFrame.new(0, 3.5, 0.6), Color = Color3.fromRGB(110, 100, 100), Material = Enum.Material.Brick })
		local fire = deco(m, { Name = "Fire", Size = Vector3.new(4, 2, 0.6), CFrame = fp * CFrame.new(0, 1.4, -0.75), Color = Color3.fromRGB(255, 140, 40), Material = Enum.Material.Neon })
		light(fire, Color3.fromRGB(255, 140, 60), 16, 1.5)
		fire:AddTag("Lamp")
	elseif kind == "Library" then
		for i = -1, 1 do
			Furniture.Shelf(m, wallSpot((closetSide + 1) % 4, i * 10), woodColor, r)
			Furniture.Shelf(m, wallSpot((closetSide + 3) % 4, i * 10), woodColor, r)
		end
		Furniture.Table(m, cf, woodColor, 8, 4)
		Furniture.Chair(m, cf * CFrame.new(-2, 0, 3), woodColor)
		Furniture.Chair(m, cf * CFrame.new(2, 0, -3) * CFrame.Angles(0, math.pi, 0), woodColor)
		Furniture.Lamp(m, wallSpot((closetSide + 2) % 4, 12), theme.Lamp)
	elseif kind == "Bedroom" then
		Furniture.Bed(m, wallSpot((closetSide + 2) % 4, 0) * CFrame.new(0, 0, -2.5) * CFrame.Angles(0, math.pi, 0), accent)
		Furniture.Rug(m, cf * CFrame.new(0, 0, 0), accent:Lerp(Color3.new(1, 1, 1), 0.2), 10, 8)
		Furniture.Lamp(m, wallSpot((closetSide + 2) % 4, 7), theme.Lamp)
		Furniture.Plant(m, wallSpot((closetSide + 1) % 4, 12))
		Furniture.Desk(m, wallSpot((closetSide + 3) % 4, 6) * CFrame.new(0, 0, -1), woodColor)
	elseif kind == "Kitchen" or kind == "Food" or kind == "Cafeteria" then
		Furniture.Counter(m, wallSpot((closetSide + 1) % 4, 0), 24, woodColor)
		Furniture.Counter(m, wallSpot((closetSide + 2) % 4, 6), 14, woodColor)
		local tables = if kind == "Cafeteria" or kind == "Food" then { -7, 7 } else { 0 }
		for _, x in tables do
			Furniture.Table(m, cf * CFrame.new(x, 0, 0), accent, 7, 4)
			Furniture.Chair(m, cf * CFrame.new(x - 2, 0, 3.2), accent)
			Furniture.Chair(m, cf * CFrame.new(x + 2, 0, -3.2) * CFrame.Angles(0, math.pi, 0), accent)
		end
		Furniture.Plant(m, wallSpot((closetSide + 3) % 4, 13))
	elseif kind == "Dining" then
		Furniture.Rug(m, cf, accent, 20, 10)
		Furniture.Table(m, cf, woodColor, 16, 5)
		for i = -2, 2 do
			Furniture.Chair(m, cf * CFrame.new(i * 3, 0, 3.6), woodColor)
			Furniture.Chair(m, cf * CFrame.new(i * 3, 0, -3.6) * CFrame.Angles(0, math.pi, 0), woodColor)
		end
		local chandelier = deco(m, { Name = "Chandelier", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = cf * CFrame.new(0, H - 3, 0), Color = theme.Lamp, Material = Enum.Material.Neon })
		light(chandelier, theme.Lamp, 22, 1.4)
		chandelier:AddTag("Lamp")
	elseif kind == "Bath" then
		local wall = wallSpot((closetSide + 2) % 4, 0)
		new(m, { Name = "Tub", Size = Vector3.new(10, 3, 5), CFrame = wall * CFrame.new(0, 1.5, -1), Color = Color3.fromRGB(240, 245, 250), Material = Enum.Material.Marble })
		deco(m, { Name = "Water", Size = Vector3.new(9, 0.2, 4), CFrame = wall * CFrame.new(0, 2.9, -1), Color = Color3.fromRGB(120, 200, 255), Material = Enum.Material.Glass, Transparency = 0.3 })
		Furniture.Counter(m, wallSpot((closetSide + 1) % 4, 4), 10, Color3.fromRGB(230, 230, 240))
		Furniture.Plant(m, wallSpot((closetSide + 3) % 4, 10))
	elseif kind == "Arcade" or kind == "Prize" then
		for i = -1, 1 do
			Furniture.Cabinet(m, wallSpot((closetSide + 1) % 4, i * 8), Color3.fromHSV(r(), 0.8, 1))
			Furniture.Cabinet(m, wallSpot((closetSide + 3) % 4, i * 8), Color3.fromHSV(r(), 0.8, 1))
		end
		if kind == "Prize" then
			Furniture.Counter(m, wallSpot((closetSide + 2) % 4, 0), 18, Color3.fromRGB(80, 40, 120))
			for i = 1, 6 do
				deco(m, { Name = "Plush", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = wallSpot((closetSide + 2) % 4, -8 + i * 2.6) * CFrame.new(0, 4.6, 0), Color = Color3.fromHSV(r(), 0.6, 1), CanCollide = true })
			end
		else
			Furniture.Cabinet(m, cf * CFrame.new(-4, 0, 0), Color3.fromHSV(r(), 0.8, 1))
			Furniture.Cabinet(m, cf * CFrame.new(4, 0, 0) * CFrame.Angles(0, math.pi, 0), Color3.fromHSV(r(), 0.8, 1))
		end
	elseif kind == "Bowling" then
		for i = -2, 2 do
			deco(m, { Name = "Lane", Size = Vector3.new(4, 0.15, 30), CFrame = cf * CFrame.new(i * 6, 0.08, 0), Color = Color3.fromRGB(220, 180, 120), Material = Enum.Material.Wood })
			for p = 0, 2 do
				deco(m, { Name = "Pin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 0.6, 0.6), CFrame = cf * CFrame.new(i * 6 + (p - 1) * 0.8, 0.8, 13 - p * 0.6) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1), CanCollide = true })
			end
		end
	elseif kind == "Classroom" then
		new(m, { Name = "Board", Size = Vector3.new(16, 6, 0.4), CFrame = wallSpot((closetSide + 2) % 4, 0) * CFrame.new(0, 6, 1.6), Color = Color3.fromRGB(40, 70, 50) })
		for x = -1, 1 do
			for z = 0, 1 do
				Furniture.Desk(m, cf * CFrame.new(x * 7, 0, z * 7 - 3), woodColor)
			end
		end
	elseif kind == "Lockers" or kind == "Gym" then
		if kind == "Gym" then
			deco(m, { Name = "Court", Size = Vector3.new(S - 8, 0.12, S - 8), CFrame = cf * CFrame.new(0, 0.06, 0), Color = Color3.fromRGB(220, 160, 90), Material = Enum.Material.Wood })
			for z = -1, 1, 2 do
				new(m, { Name = "Hoop", Size = Vector3.new(0.4, 10, 0.4), CFrame = cf * CFrame.new(0, 5, z * 17), Color = Color3.fromRGB(80, 80, 90) })
				new(m, { Name = "Backboard", Size = Vector3.new(6, 4, 0.3), CFrame = cf * CFrame.new(0, 10, z * 16.6), Color = Color3.new(1, 1, 1) })
			end
		else
			for i = -2, 2 do
				if i ~= 0 then
					Furniture.Closet(m, wallSpot((closetSide + 1) % 4, i * 3.6), Color3.fromRGB(60, 110, 180), true)
				end
			end
			new(m, { Name = "Bench", Size = Vector3.new(14, 1.6, 2.4), CFrame = cf * CFrame.new(0, 0.8, 0), Color = woodColor, Material = Enum.Material.Wood })
		end
	elseif kind == "Storage" then
		for i = 1, 7 do
			Furniture.Crate(m, cf * CFrame.new(r(-14, 14), 0, r(-14, 14)) * CFrame.Angles(0, r() * 6, 0), 3 + r() * 2.5)
		end
		Furniture.Shelf(m, wallSpot((closetSide + 2) % 4, 0), woodColor, r)
	elseif kind == "Lab" then
		Furniture.Bench(m, wallSpot((closetSide + 1) % 4, 0) * CFrame.new(0, 0, -1), r)
		Furniture.Bench(m, cf * CFrame.new(0, 0, -4), r)
		Furniture.Tank(m, wallSpot((closetSide + 3) % 4, 8) * CFrame.new(0, 0, -2), Color3.fromHSV(0.45 + r() * 0.2, 0.7, 1))
	elseif kind == "Server" then
		for i = -2, 2 do
			local rack = new(m, { Name = "Rack", Size = Vector3.new(3, 9, 3), CFrame = cf * CFrame.new(i * 6, 4.5, 6), Color = Color3.fromRGB(30, 34, 44), Material = Enum.Material.Metal })
			for y = 0, 6 do
				deco(m, { Name = "Led", Size = Vector3.new(2.4, 0.15, 0.1), CFrame = rack.CFrame * CFrame.new(0, -3.6 + y, -1.55), Color = if r() < 0.5 then Color3.fromRGB(80, 220, 255) else Color3.fromRGB(90, 230, 120), Material = Enum.Material.Neon })
			end
		end
	elseif kind == "Gallery" then
		-- Bilderrahmen an zwei Waenden, Bank in der Mitte, Absperrkordel
		for _, side in { (closetSide + 1) % 4, (closetSide + 3) % 4 } do
			for i = -1, 1 do
				local spot = wallSpot(side, i * 11) * CFrame.new(0, 7, 1.6)
				new(m, { Name = "Frame", Size = Vector3.new(7, 5, 0.4), CFrame = spot, Color = theme.Trim, Material = Enum.Material.Foil })
				deco(m, { Name = "Painting", Size = Vector3.new(6, 4, 0.2), CFrame = spot * CFrame.new(0, 0, -0.25), Color = Color3.fromHSV(r(), 0.55, 0.8), Material = Enum.Material.SmoothPlastic })
				deco(m, { Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 0.3), CFrame = spot * CFrame.new(r(-2, 2), 0.8, -0.35), Color = Config.Colors.Moon, Material = Enum.Material.Neon })
			end
		end
		new(m, { Name = "Bench", Size = Vector3.new(8, 1.6, 2.6), CFrame = cf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(80, 50, 40), Material = Enum.Material.Wood })
		Furniture.Rug(m, cf, Color3.fromRGB(140, 30, 40), 14, 8)
	elseif kind == "Fossil" then
		-- Cartoon-Dino aus Knochen-Teilen auf einem Podest
		new(m, { Name = "Stage", Size = Vector3.new(20, 1, 10), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(110, 90, 70), Material = Enum.Material.Slate })
		local bone = Color3.fromRGB(240, 230, 205)
		for i = -3, 3 do
			deco(m, { Name = "Rib", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4 - math.abs(i) * 0.4, 4 - math.abs(i) * 0.4), CFrame = cf * CFrame.new(i * 1.4, 5, 0), Color = bone, CanCollide = true })
		end
		new(m, { Name = "Spine", Size = Vector3.new(14, 0.7, 0.7), CFrame = cf * CFrame.new(0, 6.6, 0), Color = bone })
		new(m, { Name = "Skull", Size = Vector3.new(3, 2.2, 2), CFrame = cf * CFrame.new(8.4, 7.6, 0), Color = bone })
		for x = -1, 1, 2 do
			new(m, { Name = "Leg", Size = Vector3.new(0.7, 5, 0.7), CFrame = cf * CFrame.new(x * 3.5, 3.5, 0), Color = bone })
		end
		Furniture.Plant(m, wallSpot((closetSide + 2) % 4, 12))
	elseif kind == "Gems" then
		-- Edelsteine in Glasvitrinen
		for i = -1, 1 do
			for z = -1, 1, 2 do
				local base = cf * CFrame.new(i * 8, 0, z * 6)
				new(m, { Name = "Pedestal", Size = Vector3.new(3, 3.4, 3), CFrame = base * CFrame.new(0, 1.7, 0), Color = Color3.fromRGB(230, 225, 215), Material = Enum.Material.Marble })
				local c = Color3.fromHSV(r(), 0.75, 1)
				local gem = deco(m, { Name = "Gem", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = base * CFrame.new(0, 4.4, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = c, Material = Enum.Material.Neon })
				gem:AddTag("Spin")
				light(gem, c, 8, 1)
				deco(m, { Name = "Case", Size = Vector3.new(2.6, 2.6, 2.6), CFrame = base * CFrame.new(0, 4.7, 0), Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Glass, Transparency = 0.75, CanCollide = true })
			end
		end
	elseif kind == "Statue" then
		-- Mond-Statue auf Sockel, Saeulen in den Ecken
		new(m, { Name = "Plinth", Size = Vector3.new(6, 3, 6), CFrame = cf * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(200, 195, 185), Material = Enum.Material.Marble })
		new(m, { Name = "StatueBody", Size = Vector3.new(2.4, 5, 1.6), CFrame = cf * CFrame.new(0, 5.5, 0), Color = Color3.fromRGB(220, 220, 225), Material = Enum.Material.Marble })
		new(m, { Name = "StatueHead", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = cf * CFrame.new(0, 9, 0), Color = Color3.fromRGB(220, 220, 225), Material = Enum.Material.Marble })
		local orb = deco(m, { Name = "StatueMoon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = cf * CFrame.new(1.8, 8.4, 0), Color = Config.Colors.Moon, Material = Enum.Material.Neon })
		light(orb, Config.Colors.Moon, 14, 1.2)
		orb:AddTag("Lamp")
		for x = -1, 1, 2 do
			for z = -1, 1, 2 do
				new(m, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(H - 1, 2.4, 2.4), CFrame = cf * CFrame.new(x * 14, (H - 1) / 2, z * 14) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(225, 220, 210), Material = Enum.Material.Marble })
			end
		end
	elseif kind == "Reactor" then
		local core = new(m, { Name = "Core", Shape = Enum.PartType.Cylinder, Size = Vector3.new(H - 2, 7, 7), CFrame = cf * CFrame.new(0, (H - 2) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 220, 255), Material = Enum.Material.Neon, Transparency = 0.25 })
		light(core, Color3.fromRGB(80, 220, 255), 30, 2)
		core:AddTag("Lamp")
		core:AddTag("Spin")
	end

	-- Fast jeder Raum bekommt einen Schrank zum Verstecken
	if kind ~= "Lockers" and kind ~= "Gym" and kind ~= "Bowling" and r() < 0.75 then
		Furniture.Closet(m, wallSpot(closetSide, r(-12, 12)), if theme.Neon then Color3.fromRGB(70, 60, 110) else woodColor, kind == "Lab" or kind == "Server" or kind == "Classroom")
	end
end

---------------------------------------------------------------- Karte

export type BuiltMap = {
	Model: Model,
	Spawns: { CFrame },
	CoinSpots: { Vector3 },
	PowerSpots: { Vector3 },
	Bounds: { Min: Vector3, Max: Vector3 },
}

function MapBuilder.Build(def, origin: Vector3, seed: number?): BuiltMap
	local theme = THEMES[def.Theme]
	local r = rng(seed or (#def.Id * 7919 + string.byte(def.Id, 1)))
	local model = Instance.new("Model")
	model.Name = "Map_" .. def.Id
	local cols, rows = def.Cols, def.Rows
	local function center(c: number, row: number): Vector3
		return origin + Vector3.new((c - (cols + 1) / 2) * S, 0, (row - (rows + 1) / 2) * S)
	end

	-- Verbindungen: zufaelliger Spannbaum plus ein paar Extra-Tueren, damit es Schleifen gibt
	local open = {} -- ["c,r,dir"] = true, dir "E" oder "S"
	local visited = {}
	local function key(c, row)
		return c .. "," .. row
	end
	local stack = { { 1, 1 } }
	visited[key(1, 1)] = true
	while #stack > 0 do
		local cur = stack[#stack]
		local options = {}
		for _, d in { { 1, 0, "E" }, { -1, 0, "W" }, { 0, 1, "S" }, { 0, -1, "N" } } do
			local nc, nr = cur[1] + d[1], cur[2] + d[2]
			if nc >= 1 and nc <= cols and nr >= 1 and nr <= rows and not visited[key(nc, nr)] then
				table.insert(options, { nc, nr, d[3] })
			end
		end
		if #options == 0 then
			table.remove(stack)
		else
			local pick = options[r(1, #options)]
			visited[key(pick[1], pick[2])] = true
			if pick[3] == "E" then
				open[cur[1] .. "," .. cur[2] .. ",E"] = true
			elseif pick[3] == "W" then
				open[pick[1] .. "," .. pick[2] .. ",E"] = true
			elseif pick[3] == "S" then
				open[cur[1] .. "," .. cur[2] .. ",S"] = true
			else
				open[pick[1] .. "," .. pick[2] .. ",S"] = true
			end
			table.insert(stack, { pick[1], pick[2] })
		end
	end
	for c = 1, cols do
		for row = 1, rows do
			if c < cols and r() < 0.45 then
				open[c .. "," .. row .. ",E"] = true
			end
			if row < rows and r() < 0.45 then
				open[c .. "," .. row .. ",S"] = true
			end
		end
	end

	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = model
	local furniture = Instance.new("Model")
	furniture.Name = "Furniture"
	furniture.Parent = model

	local function wallSegment(a: Vector3, b: Vector3, color: Color3, thick: number)
		local length = (b - a).Magnitude
		if length < 0.5 then
			return
		end
		local mid = (a + b) / 2
		local cf = CFrame.lookAt(mid + Vector3.new(0, H / 2, 0), mid + Vector3.new(0, H / 2, 0) + (b - a).Unit)
		local wall = new(walls, { Name = "Wall", Size = Vector3.new(thick, H, length), CFrame = cf, Color = color, Material = if theme.Log then Enum.Material.Wood else Enum.Material.SmoothPlastic })
		-- Sockelleiste
		deco(walls, { Name = "Trim", Size = Vector3.new(thick + 0.3, 1, length), CFrame = cf * CFrame.new(0, -H / 2 + 0.5, 0), Color = theme.Trim, Material = if theme.Neon then Enum.Material.Neon else Enum.Material.Wood })
		if theme.Log then
			for y = 1, 4 do
				deco(walls, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = Vector3.new(length, 1.2, 1.2), CFrame = cf * CFrame.new(0, -H / 2 + y * 3.2, 0) * CFrame.Angles(0, math.rad(90), 0), Color = theme.Wall2, Material = Enum.Material.Wood })
			end
		end
		return wall
	end

	-- Innenwand zwischen zwei Raeumen, optional mit Tuer in der Mitte
	local doorways = {}
	local function innerWall(a: Vector3, b: Vector3, withDoor: boolean, color: Color3)
		if not withDoor then
			wallSegment(a, b, color, 1)
			return
		end
		local dir = (b - a).Unit
		local mid = (a + b) / 2
		wallSegment(a, mid - dir * DOOR / 2, color, 1)
		wallSegment(mid + dir * DOOR / 2, b, color, 1)
		-- Sturz ueber der Tuer
		local lintel = new(walls, { Name = "Lintel", Size = Vector3.new(1, H - 10, DOOR), CFrame = CFrame.lookAt(mid + Vector3.new(0, 10 + (H - 10) / 2, 0), mid + Vector3.new(0, 10 + (H - 10) / 2, 0) + dir), Color = color })
		table.insert(doorways, { Mid = mid, Dir = dir, Lintel = lintel })
	end

	for c = 1, cols do
		for row = 1, rows do
			local cpos = center(c, row)
			-- Boden (Schachbrett aus zwei Materialien)
			local alt = (c + row) % 2 == 0
			local floor = new(model, { Name = "Floor", Size = Vector3.new(S, 1, S), CFrame = CFrame.new(cpos - Vector3.new(0, 0.5, 0)), Color = if alt then theme.Floor[1] else theme.Floor2[1], Material = if alt then theme.Floor[2] else theme.Floor2[2] })
			floor:AddTag("MapFloor")
			-- Waende nach Osten und Sueden (innen) bzw. aussen
			local half = S / 2
			local wallColor = if alt then theme.Wall else theme.Wall2
			if c < cols then
				innerWall(cpos + Vector3.new(half, 0, -half), cpos + Vector3.new(half, 0, half), open[c .. "," .. row .. ",E"] == true, wallColor)
			end
			if row < rows then
				innerWall(cpos + Vector3.new(-half, 0, half), cpos + Vector3.new(half, 0, half), open[c .. "," .. row .. ",S"] == true, wallColor)
			end
			-- Deckenlampe
			local lamp = deco(model, { Name = "CeilingLamp", Size = Vector3.new(4, 0.4, 4), CFrame = CFrame.new(cpos + Vector3.new(0, H - 0.3, 0)), Color = theme.Lamp, Material = Enum.Material.Neon })
			light(lamp, theme.Lamp, 34, 1.1)
			lamp:AddTag("Lamp")
			-- Moebel
			local kind = theme.Rooms[((c - 1) * rows + row - 1) % #theme.Rooms + 1]
			if r() < 0.25 then
				kind = theme.Rooms[r(1, #theme.Rooms)]
			end
			local roomCf = CFrame.new(cpos)
			furnish(furniture, kind, roomCf, theme, r, nil)
		end
	end

	-- Aussenwaende mit Fenstern (Mondlicht)
	local minC, maxC = center(1, 1) - Vector3.new(S / 2, 0, S / 2), center(cols, rows) + Vector3.new(S / 2, 0, S / 2)
	local corners = { Vector3.new(minC.X, 0, minC.Z), Vector3.new(maxC.X, 0, minC.Z), Vector3.new(maxC.X, 0, maxC.Z), Vector3.new(minC.X, 0, maxC.Z) }
	for i = 1, 4 do
		local a, b = corners[i] + Vector3.new(0, origin.Y, 0), corners[i % 4 + 1] + Vector3.new(0, origin.Y, 0)
		local outer = wallSegment(a, b, theme.Wall2, 2)
		local dir = (b - a).Unit
		local length = (b - a).Magnitude
		for t = S / 2, length - S / 2 + 1, S do
			local p = a + dir * t
			local window = deco(walls, { Name = "Window", Size = Vector3.new(2.3, 6, 8), CFrame = CFrame.lookAt(p + Vector3.new(0, 8, 0), p + Vector3.new(0, 8, 0) + dir), Color = Color3.fromRGB(110, 150, 255), Material = Enum.Material.Neon, Transparency = 0.35 })
			light(window, Color3.fromRGB(120, 150, 255), 14, 0.6)
		end
		if outer then
			outer.Name = "OuterWall"
		end
	end

	-- Decke
	local size = maxC - minC
	local ceiling = new(model, { Name = "Ceiling", Size = Vector3.new(size.X + 4, 1, size.Z + 4), CFrame = CFrame.new((minC + maxC) / 2 + Vector3.new(0, origin.Y + H + 0.5, 0)), Color = theme.Wall2:Lerp(Color3.new(0, 0, 0), 0.4) })
	ceiling.CastShadow = false

	-- Tueren zum Zuschlagen (Tag "Door")
	for _, way in doorways do
		if r() < 0.6 then
			local hinge = CFrame.lookAt(way.Mid - way.Dir * (DOOR / 2 - 0.2), way.Mid - way.Dir * (DOOR / 2 - 0.2) + way.Dir) * CFrame.new(0, 5, 0)
			local closed = hinge * CFrame.new(0, 0, -(DOOR - 0.6) / 2)
			local opened = hinge * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(0, 0, -(DOOR - 0.6) / 2) * CFrame.new(0.8, 0, 0)
			local door = new(model, { Name = "Door", Size = Vector3.new(0.6, 10, DOOR - 0.6), CFrame = opened, Color = theme.Trim, Material = Enum.Material.Wood, CanCollide = false })
			door:SetAttribute("Closed", closed)
			door:SetAttribute("Opened", opened)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Slam Door"
			prompt.ObjectText = "Door"
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.Parent = door
			door:AddTag("Door")
		end
	end

	-- Lueftungsschaechte: zwei Paare in weit entfernten Raeumen (nur Murderer)
	local ventIndex = 0
	local function vent(c: number, row: number)
		local cpos = center(c, row)
		local angle = r(0, 3) * math.pi / 2
		local pos = (CFrame.new(cpos) * CFrame.Angles(0, angle, 0) * CFrame.new(r(-8, 8), 0, S / 2 - 3)).Position
		local grate = deco(model, { Name = "Vent", Size = Vector3.new(4, 0.3, 4), CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)), Color = Color3.fromRGB(70, 75, 85), Material = Enum.Material.DiamondPlate, CanCollide = true })
		for i = -1, 1 do
			deco(model, { Name = "Slat", Size = Vector3.new(3.4, 0.35, 0.3), CFrame = grate.CFrame * CFrame.new(0, 0.05, i * 1.1), Color = Color3.fromRGB(30, 30, 35) })
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Use Vent"
		prompt.ObjectText = "Murderer only"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 7
		prompt.RequiresLineOfSight = false
		prompt.Enabled = true
		prompt.Parent = grate
		grate:AddTag("Vent")
		ventIndex += 1
		return grate
	end
	local pairs_ = { { { 1, 1 }, { cols, rows } }, { { cols, 1 }, { 1, rows } } }
	for i, pair in pairs_ do
		local a = vent(pair[1][1], pair[1][2])
		local b = vent(pair[2][1], pair[2][2])
		a:SetAttribute("Pair", i)
		b:SetAttribute("Pair", i)
		a.Name = "Vent" .. i .. "A"
		b.Name = "Vent" .. i .. "B"
	end

	-- Spawn-, Muenz- und Power-Up-Punkte
	local spawns, coinSpots, powerSpots = {}, {}, {}
	for c = 1, cols do
		for row = 1, rows do
			local cpos = center(c, row)
			for _ = 1, 3 do
				table.insert(spawns, CFrame.new(cpos + Vector3.new(r(-12, 12), 3, r(-12, 12))))
			end
			for _ = 1, 7 do
				table.insert(coinSpots, cpos + Vector3.new(r(-17, 17), 0, r(-17, 17)))
			end
			table.insert(powerSpots, cpos + Vector3.new(r(-10, 10), 0, r(-10, 10)))
		end
	end

	model.Parent = workspace
	return {
		Model = model,
		Spawns = spawns,
		CoinSpots = coinSpots,
		PowerSpots = powerSpots,
		Bounds = { Min = minC + Vector3.new(0, origin.Y, 0), Max = maxC + Vector3.new(0, origin.Y + H, 0) },
	}
end

---------------------------------------------------------------- Lobby

function MapBuilder.BuildLobby(): Model
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	local C = Config.Colors

	local floor = new(lobby, { Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 150, 150), CFrame = CFrame.new(0, -1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(46, 48, 82), Material = Enum.Material.Slate })
	floor:AddTag("LobbyFloor")
	deco(lobby, { Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 152, 152), CFrame = CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = C.Moon, Material = Enum.Material.Neon })
	deco(lobby, { Name = "Inner", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 60, 60), CFrame = CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 62, 110), Material = Enum.Material.Marble })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 0.5, 22)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = lobby

	-- Brunnen mit Mond-Statue in der Mitte
	new(lobby, { Name = "Fountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.5, 22, 22), CFrame = CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 95, 140), Material = Enum.Material.Marble })
	deco(lobby, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 19, 19), CFrame = CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 140, 255), Material = Enum.Material.Glass, Transparency = 0.25 })
	new(lobby, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 3, 3), CFrame = CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 125, 170), Material = Enum.Material.Marble })
	local moon = deco(lobby, { Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7), CFrame = CFrame.new(0, 13.5, 0), Color = C.Moon, Material = Enum.Material.Neon })
	light(moon, C.Moon, 40, 1.5)
	moon:AddTag("Bob")
	-- Schatten-Kugel macht eine Sichel
	deco(lobby, { Name = "MoonShade", Shape = Enum.PartType.Ball, Size = Vector3.new(6.2, 6.2, 6.2), CFrame = CFrame.new(1.6, 14.2, -1.2), Color = Color3.fromRGB(30, 32, 70), Material = Enum.Material.SmoothPlastic }):AddTag("Bob")

	-- Grosses Logo-Schild
	local board = new(lobby, { Name = "LogoBoard", Size = Vector3.new(44, 14, 1), CFrame = CFrame.new(0, 14, -52), Color = C.Panel })
	sign(board, Enum.NormalId.Back, "MIDNIGHT MYSTERY", C.Moon, Enum.Font.LuckiestGuy)
	deco(lobby, { Name = "BoardEdge", Size = Vector3.new(45, 15, 0.6), CFrame = CFrame.new(0, 14, -51.9), Color = C.Pink, Material = Enum.Material.Neon })
	for x = -1, 1, 2 do
		new(lobby, { Name = "BoardPost", Size = Vector3.new(1.5, 8, 1.5), CFrame = CFrame.new(x * 18, 3.5, -52), Color = Color3.fromRGB(40, 40, 70) })
	end

	-- Stationen: oeffnen Menues (der Client zeigt sie)
	local function booth(name: string, text: string, color: Color3, cf: CFrame)
		local base = new(lobby, { Name = name, Size = Vector3.new(12, 1, 8), CFrame = cf * CFrame.new(0, 0.5, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.5) })
		new(lobby, { Name = "Counter", Size = Vector3.new(10, 4, 2), CFrame = cf * CFrame.new(0, 3, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.Wood })
		local roof = deco(lobby, { Name = "Roof", Size = Vector3.new(13, 0.8, 9), CFrame = cf * CFrame.new(0, 10.5, 0), Color = color, Material = Enum.Material.Neon, CanCollide = true })
		light(roof, color, 18, 1.2)
		for x = -1, 1, 2 do
			new(lobby, { Name = "Post", Size = Vector3.new(0.8, 10, 0.8), CFrame = cf * CFrame.new(x * 5.6, 5.5, 3.6), Color = Color3.fromRGB(40, 40, 60) })
		end
		local signPart = deco(lobby, { Name = "Sign", Size = Vector3.new(12, 3, 0.4), CFrame = cf * CFrame.new(0, 12.5, 0), Color = C.Panel, CanCollide = true })
		sign(signPart, Enum.NormalId.Front, text, color)
		sign(signPart, Enum.NormalId.Back, text, color)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = text
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = base
		base:SetAttribute("Menu", name)
		base:AddTag("Booth")
	end
	local function ring(angle: number, radius: number): CFrame
		local pos = Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
		return CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	end
	booth("Crates", "CRATES", C.Red, ring(math.rad(-140), 46))
	booth("Shop", "SHOP", C.Moon, ring(math.rad(140), 46))
	booth("Pass", "BATTLE PASS", C.Purple, ring(math.rad(-90), 50))
	booth("Inventory", "INVENTORY", C.Cyan, ring(math.rad(90), 50))

	-- Bestenlisten
	for i, stat in { "Wins", "KOs" } do
		local angle = math.rad(if i == 1 then -30 else 30)
		local pos = Vector3.new(math.sin(angle) * 58, 0, -math.cos(angle) * 58)
		local panel = new(lobby, { Name = "Board_" .. stat, Size = Vector3.new(16, 20, 1), CFrame = CFrame.lookAt(pos + Vector3.new(0, 11, 0), Vector3.new(0, 11, 0)), Color = C.Panel })
		panel:AddTag("Leaderboard")
		panel:SetAttribute("Stat", stat)
		deco(lobby, { Name = "BoardGlow", Size = Vector3.new(16.6, 20.6, 0.5), CFrame = panel.CFrame * CFrame.new(0, 0, 0.4), Color = if i == 1 then C.Moon else C.Red, Material = Enum.Material.Neon })
	end

	-- Laternen rund um den Platz
	for i = 0, 11 do
		local angle = i / 12 * math.pi * 2 + 0.26
		local pos = Vector3.new(math.sin(angle) * 70, 0, math.cos(angle) * 70)
		new(lobby, { Name = "LampPost", Size = Vector3.new(0.8, 12, 0.8), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(30, 30, 50), Material = Enum.Material.Metal })
		local bulb = deco(lobby, { Name = "Bulb", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(pos + Vector3.new(0, 12.5, 0)), Color = C.Moon, Material = Enum.Material.Neon })
		light(bulb, Color3.fromRGB(255, 210, 150), 24, 1)
	end

	-- Unsichtbarer Rand, damit niemand runterfaellt (ausser beim Obby)
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local pos = Vector3.new(math.sin(angle) * 75, 6, math.cos(angle) * 75)
		local barrier = new(lobby, { Name = "Barrier", Size = Vector3.new(20, 12, 1), CFrame = CFrame.lookAt(pos, Vector3.new(0, 6, 0)), Transparency = 1 })
		barrier.CanQuery = false
		if i == 6 then
			barrier:Destroy() -- Durchgang zum Obby (Osten)
		end
	end

	-- Obby: schwebende Plattformen im Osten, Belohnung am Ende
	local obby = Instance.new("Model")
	obby.Name = "Obby"
	local startPad = deco(obby, { Name = "ObbyStart", Size = Vector3.new(8, 1, 8), CFrame = CFrame.new(80, -0.5, 0), Color = C.Green, Material = Enum.Material.Neon, CanCollide = true })
	startPad:AddTag("ObbyStart")
	sign(deco(obby, { Name = "ObbySign", Size = Vector3.new(10, 3, 0.4), CFrame = CFrame.new(80, 5, -4.5) * CFrame.Angles(0, math.pi, 0) }), Enum.NormalId.Front, "MOON OBBY", C.Green)
	local p = Vector3.new(80, 0, 0)
	for i = 1, 14 do
		local step = Vector3.new(9 + (i % 3), if i % 4 == 0 then 0 else 2.2, (i % 2 == 0 and 4 or -4))
		p += step
		local color = Color3.fromHSV((i / 14) * 0.8, 0.6, 1)
		local plat = new(obby, { Name = "Step" .. i, Size = Vector3.new(5, 1, 5), CFrame = CFrame.new(p), Color = color, Material = Enum.Material.SmoothPlastic })
		if i % 5 == 0 then
			plat:AddTag("Spin")
			plat.Size = Vector3.new(9, 1, 3)
		end
	end
	local goal = new(obby, { Name = "ObbyGoal", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(p + Vector3.new(10, 0, 0)), Color = C.Moon, Material = Enum.Material.Neon })
	goal:AddTag("ObbyGoal")
	local chest = new(obby, { Name = "Chest", Size = Vector3.new(4, 3, 3), CFrame = CFrame.new(p + Vector3.new(10, 2, 0)), Color = Color3.fromRGB(160, 100, 40), Material = Enum.Material.Wood })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Claim"
	prompt.ObjectText = "Obby Reward"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest
	chest:AddTag("ObbyChest")
	-- Unter dem Obby ein Fangnetz zurueck zum Start
	local net = new(obby, { Name = "ObbyNet", Size = Vector3.new(220, 1, 80), CFrame = CFrame.new(160, -14, 0), Transparency = 1, CanCollide = false })
	net:AddTag("ObbyReset")
	obby.Parent = lobby

	lobby.Parent = workspace
	return lobby
end

-- Tuer zuschlagen (fuer DoorService), gibt die Tween-Dauer zurueck
function MapBuilder.SetDoor(door: BasePart, closed: boolean)
	local target = door:GetAttribute(if closed then "Closed" else "Opened")
	if typeof(target) ~= "CFrame" then
		return
	end
	door.CanCollide = closed
	TweenService:Create(door, TweenInfo.new(0.25, Enum.EasingStyle.Back), { CFrame = target }):Play()
end

return MapBuilder
