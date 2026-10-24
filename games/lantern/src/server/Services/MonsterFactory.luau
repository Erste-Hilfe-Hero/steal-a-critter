-- Baut die Monster als niedliche Cartoon-Modelle aus Parts (keine fremden Assets, kein Blut).
-- Jeder Bauplan liefert Teile relativ zum Boden unter dem Monster; die Teile werden an einen
-- unsichtbaren HumanoidRootPart geschweisst, damit ein Humanoid sie mit MoveTo bewegen kann.
local CollectionService = game:GetService("CollectionService")

local MonsterFactory = {}

type PartSpec = {
	Size: Vector3,
	CFrame: CFrame,
	Color: Color3?,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Transparency: number?,
	Name: string?,
	Glow: boolean?,
}

local WHITE = Color3.fromRGB(255, 255, 255)
local INK = Color3.fromRGB(24, 22, 36)

local function shade(color: Color3, f: number): Color3
	return Color3.new(math.clamp(color.R * f, 0, 1), math.clamp(color.G * f, 0, 1), math.clamp(color.B * f, 0, 1))
end

local function ball(list, size: Vector3, position: Vector3, color: Color3, extra: { [string]: any }?)
	local spec: any = { Size = size, CFrame = CFrame.new(position), Color = color, Shape = Enum.PartType.Ball }
	for key, value in (extra or {}) :: { [string]: any } do
		spec[key] = value
	end
	table.insert(list, spec)
	return spec
end

local function block(list, size: Vector3, cf: CFrame, color: Color3, extra: { [string]: any }?)
	local spec: any = { Size = size, CFrame = cf, Color = color }
	for key, value in (extra or {}) :: { [string]: any } do
		spec[key] = value
	end
	table.insert(list, spec)
	return spec
end

-- Zwei grosse Cartoon-Augen; z ist die Vorderseite (negativ = vorne)
local function eyes(list, s: number, y: number, z: number, spread: number, size: number, pupil: Color3?)
	for _, side in { -1, 1 } do
		ball(list, Vector3.one * size * s, Vector3.new(side * spread * s, y * s, z * s), WHITE)
		ball(list, Vector3.one * size * 0.5 * s, Vector3.new(side * spread * s, y * s, (z - size * 0.35) * s), pupil or INK)
	end
end

local Bodies = {}

function Bodies.Slime(s: number, c: Color3)
	local list = {}
	ball(list, Vector3.new(4, 3.2, 4) * s, Vector3.new(0, 1.6, 0) * s, c, { Transparency = 0.12, Material = Enum.Material.Glass })
	ball(list, Vector3.new(3, 2.2, 3) * s, Vector3.new(0, 1.4, 0) * s, shade(c, 0.75))
	ball(list, Vector3.new(0.9, 0.6, 0.9) * s, Vector3.new(-0.9, 2.6, -1.1) * s, WHITE, { Transparency = 0.3 })
	eyes(list, s, 2.1, -1.75, 0.75, 0.8)
	return list, 3.2 * s
end

function Bodies.Mushroom(s: number, c: Color3)
	local list = {}
	block(list, Vector3.new(2, 2.8, 2) * s, CFrame.new(0, 1.4 * s, 0), Color3.fromRGB(240, 226, 196))
	ball(list, Vector3.new(4.8, 2.4, 4.8) * s, Vector3.new(0, 3.3, 0) * s, c)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		ball(list, Vector3.one * 0.7 * s, Vector3.new(math.cos(a) * 1.6, 3.9, math.sin(a) * 1.6) * s, WHITE)
	end
	eyes(list, s, 1.9, -1.05, 0.45, 0.6)
	for _, side in { -1, 1 } do
		block(list, Vector3.new(0.5, 1.4, 0.5) * s, CFrame.new(side * 1.3 * s, 1.4 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 25)), Color3.fromRGB(240, 226, 196))
	end
	return list, 4.5 * s
end

function Bodies.Bat(s: number, c: Color3)
	local list = {}
	ball(list, Vector3.new(1.8, 1.8, 1.8) * s, Vector3.new(0, 1, 0) * s, c)
	for _, side in { -1, 1 } do
		block(list, Vector3.new(2.6, 0.2, 1.4) * s, CFrame.new(side * 2 * s, 1.2 * s, 0) * CFrame.Angles(0, 0, math.rad(side * -20)), shade(c, 0.7), { Name = "Wing" })
		block(list, Vector3.new(0.4, 0.8, 0.4) * s, CFrame.new(side * 0.5 * s, 2 * s, 0) * CFrame.Angles(0, 0, math.rad(side * -15)), shade(c, 0.8))
	end
	eyes(list, s, 1.2, -0.75, 0.35, 0.5, Color3.fromRGB(80, 40, 20))
	return list, 2.4 * s
end

function Bodies.Goblin(s: number, c: Color3)
	local list = {}
	local cloth = Color3.fromRGB(120, 86, 60)
	block(list, Vector3.new(1.8, 1.8, 1.2) * s, CFrame.new(0, 2 * s, 0), cloth)
	ball(list, Vector3.new(2, 1.9, 1.9) * s, Vector3.new(0, 3.7, 0) * s, c)
	for _, side in { -1, 1 } do
		block(list, Vector3.new(1.4, 0.3, 0.5) * s, CFrame.new(side * 1.3 * s, 4 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 20)), c)
		block(list, Vector3.new(0.6, 1.2, 0.6) * s, CFrame.new(side * 0.5 * s, 0.6 * s, 0), shade(cloth, 0.7))
		block(list, Vector3.new(0.5, 1.4, 0.5) * s, CFrame.new(side * 1.2 * s, 2.1 * s, 0), c)
	end
	block(list, Vector3.new(0.35, 1.8, 0.35) * s, CFrame.new(1.3 * s, 2.4 * s, -0.6 * s) * CFrame.Angles(math.rad(-40), 0, 0), Color3.fromRGB(130, 90, 50), { Name = "Club" })
	eyes(list, s, 3.9, -0.85, 0.4, 0.55)
	return list, 4.7 * s
end

function Bodies.Wolf(s: number, c: Color3)
	local list = {}
	block(list, Vector3.new(1.8, 1.6, 3.4) * s, CFrame.new(0, 2 * s, 0), c)
	block(list, Vector3.new(1.7, 1.5, 1.6) * s, CFrame.new(0, 2.7 * s, -2.1 * s), c)
	block(list, Vector3.new(0.9, 0.7, 1) * s, CFrame.new(0, 2.4 * s, -3.1 * s), shade(c, 0.9))
	ball(list, Vector3.one * 0.4 * s, Vector3.new(0, 2.6, -3.6) * s, INK)
	for _, side in { -1, 1 } do
		block(list, Vector3.new(0.4, 0.8, 0.3) * s, CFrame.new(side * 0.55 * s, 3.7 * s, -2 * s), shade(c, 0.85))
		for _, z in { -1.2, 1.2 } do
			block(list, Vector3.new(0.5, 1.4, 0.5) * s, CFrame.new(side * 0.6 * s, 0.7 * s, z * s), shade(c, 0.85))
		end
	end
	block(list, Vector3.new(0.5, 0.5, 1.6) * s, CFrame.new(0, 2.6 * s, 2.2 * s) * CFrame.Angles(math.rad(30), 0, 0), c)
	eyes(list, s, 3, -2.9, 0.45, 0.45, Color3.fromRGB(40, 90, 160))
	return list, 3.8 * s
end

function Bodies.Wisp(s: number, c: Color3)
	local list = {}
	ball(list, Vector3.one * 1.8 * s, Vector3.new(0, 1.2, 0) * s, c, { Material = Enum.Material.Neon, Glow = true })
	ball(list, Vector3.one * 2.8 * s, Vector3.new(0, 1.2, 0) * s, c, { Transparency = 0.65, Material = Enum.Material.Glass })
	block(list, Vector3.new(0.8, 1.6, 0.8) * s, CFrame.new(0, 0, 0.3 * s) * CFrame.Angles(math.rad(30), 0, 0), c, { Material = Enum.Material.Neon, Transparency = 0.3 })
	eyes(list, s, 1.4, -1.3, 0.38, 0.5)
	return list, 2.6 * s
end

function Bodies.Golem(s: number, c: Color3)
	local list = {}
	local glow = Color3.fromRGB(255, 200, 90)
	block(list, Vector3.new(3.4, 3, 2.4) * s, CFrame.new(0, 3.3 * s, 0), c, { Material = Enum.Material.Slate })
	block(list, Vector3.new(1.9, 1.5, 1.7) * s, CFrame.new(0, 5.5 * s, -0.2 * s), shade(c, 1.1), { Material = Enum.Material.Slate })
	for _, side in { -1, 1 } do
		block(list, Vector3.new(1.3, 3.2, 1.3) * s, CFrame.new(side * 2.5 * s, 3 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 8)), shade(c, 0.9), { Material = Enum.Material.Slate, Name = "Arm" })
		block(list, Vector3.new(1.3, 1.9, 1.3) * s, CFrame.new(side * 0.9 * s, 0.95 * s, 0), shade(c, 0.85), { Material = Enum.Material.Slate })
		block(list, Vector3.new(0.5, 0.3, 0.2) * s, CFrame.new(side * 0.45 * s, 5.6 * s, -1.08 * s), glow, { Material = Enum.Material.Neon })
	end
	block(list, Vector3.new(1.2, 1.2, 0.2) * s, CFrame.new(0, 3.6 * s, -1.25 * s) * CFrame.Angles(0, 0, math.rad(45)), glow, { Material = Enum.Material.Neon, Glow = true })
	return list, 6.3 * s
end

function Bodies.Crab(s: number, c: Color3)
	local list = {}
	ball(list, Vector3.new(3.6, 1.6, 2.8) * s, Vector3.new(0, 1.5, 0) * s, c)
	for _, side in { -1, 1 } do
		ball(list, Vector3.new(1.5, 1.1, 1.5) * s, Vector3.new(side * 2.3, 1.7, -1.4) * s, shade(c, 1.1), { Name = "Claw" })
		block(list, Vector3.new(0.25, 1, 0.25) * s, CFrame.new(side * 0.5 * s, 2.6 * s, -0.8 * s), shade(c, 0.9))
		ball(list, Vector3.one * 0.6 * s, Vector3.new(side * 0.5, 3.2, -0.8) * s, WHITE)
		ball(list, Vector3.one * 0.3 * s, Vector3.new(side * 0.5, 3.2, -1.05) * s, INK)
		for i = -1, 1 do
			block(list, Vector3.new(1.4, 0.25, 0.25) * s, CFrame.new(side * 1.9 * s, 0.6 * s, i * 0.8 * s) * CFrame.Angles(0, 0, math.rad(side * -35)), shade(c, 0.8))
		end
	end
	return list, 3.4 * s
end

function Bodies.Turtle(s: number, c: Color3)
	local list = {}
	ball(list, Vector3.new(4, 2.6, 4.2) * s, Vector3.new(0, 2, 0) * s, shade(c, 0.7), { Material = Enum.Material.Slate })
	block(list, Vector3.new(3.8, 0.4, 4) * s, CFrame.new(0, 1.1 * s, 0), Color3.fromRGB(220, 200, 140))
	ball(list, Vector3.new(1.5, 1.4, 1.6) * s, Vector3.new(0, 1.9, -2.4) * s, c)
	for _, x in { -1.4, 1.4 } do
		for _, z in { -1.4, 1.4 } do
			block(list, Vector3.new(0.9, 1, 0.9) * s, CFrame.new(x * s, 0.5 * s, z * s), c)
		end
	end
	eyes(list, s, 2.1, -3.05, 0.35, 0.45)
	return list, 3.4 * s
end

function Bodies.Spider(s: number, c: Color3)
	local list = {}
	ball(list, Vector3.new(2.6, 2, 3) * s, Vector3.new(0, 1.8, 0.6) * s, c, { Material = Enum.Material.Glass, Transparency = 0.1 })
	ball(list, Vector3.one * 1.5 * s, Vector3.new(0, 1.7, -1.3) * s, shade(c, 0.85))
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local z = -0.9 + i * 0.7
			block(list, Vector3.new(2, 0.25, 0.25) * s, CFrame.new(side * 1.5 * s, 1.4 * s, z * s) * CFrame.Angles(0, math.rad(side * (i - 1.5) * 18), math.rad(side * -30)), shade(c, 0.7))
		end
	end
	eyes(list, s, 1.9, -1.95, 0.32, 0.45)
	return list, 2.8 * s
end

function Bodies.Dragon(s: number, c: Color3)
	local list = {}
	local belly = Color3.fromRGB(255, 220, 160)
	block(list, Vector3.new(3, 2.6, 5) * s, CFrame.new(0, 3.4 * s, 0), c)
	block(list, Vector3.new(2.4, 0.6, 4) * s, CFrame.new(0, 2.2 * s, -0.2 * s), belly)
	block(list, Vector3.new(1.4, 1.4, 2.4) * s, CFrame.new(0, 5 * s, -2.6 * s) * CFrame.Angles(math.rad(35), 0, 0), c)
	block(list, Vector3.new(2, 1.6, 2.2) * s, CFrame.new(0, 6.2 * s, -3.6 * s), c)
	block(list, Vector3.new(1.4, 0.8, 1.2) * s, CFrame.new(0, 5.8 * s, -4.9 * s), shade(c, 1.1))
	for _, side in { -1, 1 } do
		block(list, Vector3.new(0.4, 1.2, 0.4) * s, CFrame.new(side * 0.6 * s, 7.3 * s, -3.4 * s) * CFrame.Angles(math.rad(-25), 0, 0), belly)
		block(list, Vector3.new(4.5, 0.25, 3) * s, CFrame.new(side * 3.6 * s, 4.6 * s, 0.2 * s) * CFrame.Angles(0, 0, math.rad(side * -18)), shade(c, 0.75), { Name = "Wing" })
		for _, z in { -1.5, 1.5 } do
			block(list, Vector3.new(0.9, 2.2, 0.9) * s, CFrame.new(side * 1.1 * s, 1.1 * s, z * s), shade(c, 0.85))
		end
	end
	block(list, Vector3.new(0.9, 0.9, 4) * s, CFrame.new(0, 3 * s, 4.2 * s) * CFrame.Angles(math.rad(15), 0, 0), c)
	eyes(list, s, 6.5, -4.7, 0.55, 0.55, Color3.fromRGB(120, 60, 200))
	return list, 7.6 * s
end

MonsterFactory.Bodies = Bodies

local function crown(list, s: number, top: number)
	local gold = Color3.fromRGB(255, 205, 60)
	block(list, Vector3.new(2.2, 0.6, 2.2) * (s / 2.6) * 1.6, CFrame.new(0, top + 0.3 * s / 2.6, 0), gold, { Material = Enum.Material.Metal })
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		block(list, Vector3.new(0.5, 1, 0.5) * (s / 2.6) * 1.6, CFrame.new(math.cos(a) * 1.4 * s / 2.6, top + 1 * s / 2.6, math.sin(a) * 1.4 * s / 2.6), gold, { Material = Enum.Material.Neon })
	end
end

-- Erstellt das Modell. def = Eintrag aus Config.Monsters oder Config.Bosses.
function MonsterFactory.Build(def, scale: number, buildOptions: { Elite: boolean?, Boss: boolean? }?): Model
	local options = buildOptions or {}
	local s = def.Size * scale
	local builder = Bodies[def.Body] or Bodies.Slime
	local list, top = builder(s, def.Color)
	if options.Boss and def.Crown then
		crown(list, s, top)
	end
	local float = if def.Fly then 2.5 * scale else 0

	local model = Instance.new("Model")
	model.Name = def.Name
	local rootHalf = s
	local hip = 0.3 * s + float
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2) * s
	root.Transparency = 1
	root.CanCollide = true
	root.CanTouch = false
	root.CFrame = CFrame.new(0, hip + rootHalf, 0)
	root.Parent = model
	model.PrimaryPart = root

	local ground = CFrame.new(0, float, 0)
	for _, spec in list do
		local p = Instance.new("Part")
		p.Name = spec.Name or "Body"
		p.Size = spec.Size
		p.CFrame = ground * spec.CFrame
		p.Color = spec.Color or def.Color
		p.Material = spec.Material or Enum.Material.SmoothPlastic
		if spec.Shape then
			p.Shape = spec.Shape
		end
		p.Transparency = spec.Transparency or 0
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		if spec.Glow then
			local l = Instance.new("PointLight")
			l.Color = p.Color
			l.Range = 10 * s
			l.Brightness = 1.4
			l.Parent = p
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end

	if options.Elite then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 210, 80)
		l.Range = 14
		l.Brightness = 2
		l.Parent = root
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = hip
	humanoid.WalkSpeed = def.Speed or 10
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.AutoJumpEnabled = false
	for _, state in { Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.Climbing, Enum.HumanoidStateType.Swimming, Enum.HumanoidStateType.Seated } do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	model:SetAttribute("Top", top + float)
	CollectionService:AddTag(model, "Monster")
	return model
end

return MonsterFactory
