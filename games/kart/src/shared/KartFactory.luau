-- Baut ein Kart-Modell aus Parts (Server: Rennen und Showroom, Client: Vorschau in der Garage).
-- Vorne ist -Z (LookVector), der unsichtbare "Chassis"-Part ist die PrimaryPart und traegt die Physik.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local KartFactory = {}

local TIRE = Color3.fromRGB(28, 26, 32)
local METAL = Color3.fromRGB(170, 170, 180)

local function part(model: Model, root: BasePart?, props: { [string]: any }): BasePart
	local p: BasePart
	if props.ClassName then
		p = Instance.new(props.ClassName) :: BasePart
	else
		p = Instance.new("Part")
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		if key ~= "ClassName" and key ~= "Offset" then
			(p :: any)[key] = value
		end
	end
	if root then
		p.CFrame = root.CFrame * (props.Offset or CFrame.identity)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = model
	return p
end

local function wheel(model: Model, root: BasePart, x: number, z: number, size: number, hub: Color3)
	local w = part(model, root, {
		Name = "Wheel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.1, size, size),
		Color = TIRE,
		Offset = CFrame.new(x, -0.55 + (size - 2) / 2, z),
	})
	part(model, root, {
		Name = "Hub",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.16, size * 0.5, size * 0.5),
		Color = hub,
		Material = Enum.Material.Metal,
		Offset = CFrame.new(x, -0.55 + (size - 2) / 2, z),
	})
	return w
end

local function flameEmitter(attachment: Attachment, colors: { Color3 }, rainbow: boolean?)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "BoostFlame"
	emitter.Texture = "rbxasset://textures/particles/fire_main.dds"
	emitter.LightEmission = 1
	emitter.Color = if rainbow
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
		})
		else ColorSequence.new(colors[1], colors[2])
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0.2) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.15, 0.3)
	emitter.Rate = 90
	emitter.Speed = NumberRange.new(14, 20)
	emitter.SpreadAngle = Vector2.new(8, 8)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Enabled = false
	emitter.Parent = attachment
end

local function sparkEmitter(attachment: Attachment)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "DriftSpark"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.15, 0.35)
	emitter.Rate = 60
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Enabled = false
	emitter.Parent = attachment
end

-- Einfache CPU-Fahrerfigur mit Helm
local function dummy(model: Model, root: BasePart, color: Color3)
	part(model, root, { Name = "Torso", Size = Vector3.new(1.8, 1.8, 1.1), Color = color, Offset = CFrame.new(0, 1.2, 1.1) })
	part(model, root, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(1.9, 1.9, 1.9), Color = color, Offset = CFrame.new(0, 2.7, 1.1) })
	part(model, root, { Name = "Visor", Size = Vector3.new(1.4, 0.55, 0.3), Color = Color3.fromRGB(20, 20, 30), Material = Enum.Material.Glass, Reflectance = 0.4, Offset = CFrame.new(0, 2.75, 0.2) })
	for _, x in { -1.05, 1.05 } do
		part(model, root, { Name = "Arm", Size = Vector3.new(0.5, 0.5, 1.8), Color = color, Offset = CFrame.new(x, 1.3, 0.1) })
	end
end

export type BuildOptions = { Bot: boolean?, DriverColor: Color3?, Paint: string? }

function KartFactory.Build(kartId: string, flameId: string?, options: BuildOptions?): Model
	local kart = Config.KartsById[kartId] or Config.Karts[1]
	local flame = Config.FlamesById[flameId or "Orange"] or Config.Flames[1]
	local opts = options or {}
	local model = Instance.new("Model")
	model.Name = "Kart"

	local root = part(model, nil, {
		Name = "Chassis",
		Size = Vector3.new(5, 1.4, 8),
		Transparency = 1,
		CanCollide = true,
		CanQuery = false,
		Massless = false,
		CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100),
	})
	model.PrimaryPart = root

	local color, accent = kart.Color, kart.Accent
	local style = kart.Style
	-- Lackierung ueberschreibt die Werksfarben
	local paint = opts.Paint and Config.PaintsById[opts.Paint]
	if paint and paint.Color then
		color, accent = paint.Color, paint.Accent
	end

	if style == "Buggy" then
		part(model, root, { Name = "Floor", Size = Vector3.new(4.4, 0.5, 7), Color = accent, Offset = CFrame.new(0, -0.3, 0) })
		part(model, root, { Name = "Nose", Size = Vector3.new(3.6, 0.9, 1.8), Color = color, Offset = CFrame.new(0, 0.2, -3.1) })
		part(model, root, { Name = "Bumper", Size = Vector3.new(4.8, 0.5, 0.5), Color = METAL, Material = Enum.Material.Metal, Offset = CFrame.new(0, -0.1, -4.1) })
		part(model, root, { Name = "Engine", Size = Vector3.new(3.2, 1.4, 2), Color = color, Offset = CFrame.new(0, 0.5, 3) })
		for _, x in { -1.9, 1.9 } do
			part(model, root, { Name = "Bar", Size = Vector3.new(0.3, 3, 0.3), Color = METAL, Material = Enum.Material.Metal, Offset = CFrame.new(x, 1.7, 1.8) })
		end
		part(model, root, { Name = "Bar", Size = Vector3.new(4.1, 0.3, 0.3), Color = METAL, Material = Enum.Material.Metal, Offset = CFrame.new(0, 3.2, 1.8) })
	elseif style == "Racer" then
		part(model, root, { Name = "Body", Size = Vector3.new(3.8, 0.9, 7.4), Color = color, Offset = CFrame.new(0, 0, 0.1) })
		part(model, root, { ClassName = "WedgePart", Name = "Nose", Size = Vector3.new(3.4, 0.8, 2.4), Color = color, Offset = CFrame.new(0, 0.05, -4.4) })
		part(model, root, { Name = "Stripe", Size = Vector3.new(0.9, 0.95, 7.5), Color = accent, Offset = CFrame.new(0, 0.02, 0.1) })
		for _, x in { -2.2, 2.2 } do
			part(model, root, { Name = "Pod", Size = Vector3.new(0.9, 0.8, 3.2), Color = accent, Offset = CFrame.new(x, -0.1, 0.4) })
		end
		part(model, root, { Name = "Spoiler", Size = Vector3.new(4.6, 0.25, 1.2), Color = accent, Offset = CFrame.new(0, 1.7, 3.7) })
		for _, x in { -1.4, 1.4 } do
			part(model, root, { Name = "Strut", Size = Vector3.new(0.25, 1.4, 0.4), Color = accent, Offset = CFrame.new(x, 1, 3.7) })
		end
	elseif style == "Muscle" then
		part(model, root, { Name = "Body", Size = Vector3.new(4.6, 1.3, 7.6), Color = color, Offset = CFrame.new(0, 0.2, 0) })
		part(model, root, { Name = "Scoop", Size = Vector3.new(1.6, 0.6, 2), Color = accent, Offset = CFrame.new(0, 1.1, -2.2) })
		part(model, root, { Name = "Grill", Size = Vector3.new(3.6, 0.7, 0.2), Color = METAL, Material = Enum.Material.DiamondPlate, Offset = CFrame.new(0, 0.2, -3.85) })
		for _, x in { -1.3, 1.3 } do
			part(model, root, { Name = "Light", Size = Vector3.new(0.8, 0.4, 0.2), Color = Color3.fromRGB(255, 250, 200), Material = Enum.Material.Neon, Offset = CFrame.new(x, 0.5, -3.9) })
			part(model, root, { Name = "Stripe", Size = Vector3.new(0.5, 1.35, 7.7), Color = accent, Offset = CFrame.new(x * 0.4, 0.22, 0) })
		end
	else -- Rocket
		part(model, root, { Name = "Fuselage", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7.6, 2.4, 2.4), Color = color, Offset = CFrame.new(0, 0.3, 0.2) * CFrame.Angles(0, math.pi / 2, 0) })
		part(model, root, { Name = "Nose", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Color = accent, Offset = CFrame.new(0, 0.3, -3.6) })
		for _, x in { -1, 1 } do
			part(model, root, { ClassName = "WedgePart", Name = "Fin", Size = Vector3.new(0.3, 1.8, 2.2), Color = accent, Offset = CFrame.new(x * 1.6, 1.2, 3.2) * CFrame.Angles(0, 0, x * 0.5) })
			part(model, root, { Name = "Wing", Size = Vector3.new(1.8, 0.25, 2.6), Color = accent, Offset = CFrame.new(x * 2, -0.1, 0.8) })
		end
	end

	-- Sitz (Spieler) bzw. CPU-Figur
	if opts.Bot then
		dummy(model, root, opts.DriverColor or color)
	else
		local seat = part(model, root, {
			ClassName = "Seat",
			Name = "DriverSeat",
			Size = Vector3.new(2, 0.4, 2),
			Transparency = 1,
			CanTouch = false,
			Offset = CFrame.new(0, 0.1, 0.9),
		}) :: Seat
		seat.Disabled = false
	end
	part(model, root, { Name = "SeatBack", Size = Vector3.new(2.2, 1.8, 0.4), Color = accent, Offset = CFrame.new(0, 1, 2.1) })
	part(model, root, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.5, 1.5), Color = TIRE, Offset = CFrame.new(0, 1.3, -0.5) * CFrame.Angles(math.rad(-25), 0, 0) * CFrame.Angles(0, math.pi / 2, 0) })

	local big = if style == "Muscle" then 2.4 else 2
	wheel(model, root, -2.55, -2.7, 2, accent)
	wheel(model, root, 2.55, -2.7, 2, accent)
	wheel(model, root, -2.6, 2.7, big, accent)
	wheel(model, root, 2.6, 2.7, big, accent)

	-- Auspuffe mit Boost-Flammen
	for _, x in { -0.9, 0.9 } do
		local pipe = part(model, root, {
			Name = "Exhaust",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 0.6, 0.6),
			Color = METAL,
			Material = Enum.Material.Metal,
			Offset = CFrame.new(x, 0.35, 4.1) * CFrame.Angles(0, math.pi / 2, 0),
		})
		local attachment = Instance.new("Attachment")
		attachment.Name = "FlameAttachment"
		attachment.WorldCFrame = root.CFrame * CFrame.new(x, 0.35, 4.6)
		attachment.Parent = pipe
		flameEmitter(attachment, flame.Colors, flame.Rainbow)
	end
	local light = Instance.new("PointLight")
	light.Name = "BoostLight"
	light.Color = flame.Colors[2]
	light.Range = 14
	light.Brightness = 3
	light.Enabled = false
	light.Parent = root

	-- Drift-Funken an den Hinterraedern
	for _, x in { -2.6, 2.6 } do
		local attachment = Instance.new("Attachment")
		attachment.Name = "SparkAttachment"
		attachment.Position = Vector3.new(x, -1.2, 3.4)
		attachment.Parent = root
		sparkEmitter(attachment)
	end

	if paint and paint.Metal then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") and d.Color == color and d.Transparency < 1 then
				d.Material = Enum.Material.Metal
				d.Reflectance = 0.2
			end
		end
	end

	return model
end

return KartFactory
