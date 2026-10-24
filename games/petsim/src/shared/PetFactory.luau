-- Baut die Haustiere aus einfachen Parts (keine fremden Assets noetig).
-- Wird vom Client benutzt: fuer folgende Haustiere, das Inventar und die Schluepf-Animation.
local Config = require(script.Parent.Config)

local PetFactory = {}

local GOLD = Color3.fromRGB(255, 205, 40)

local function weld(a: BasePart, b: BasePart)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = a
	constraint.Part1 = b
	constraint.Parent = a
end

local function makePart(props): Part
	local part = Instance.new("Part")
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Anchored = false
	part.Massless = true
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Liefert ein Model, dessen PrimaryPart "Body" verankert ist; alle anderen Teile sind angeschweisst.
-- Vorne ist -Z (wie bei Roblox ueblich).
function PetFactory.Build(typeId: string, golden: boolean?): Model
	local def = Config.PetsById[typeId]
	local rarity = Config.RaritiesByName[def.Rarity]
	local s = rarity.Scale
	local color = if golden then GOLD else def.Color
	local accent = color:Lerp(Color3.new(0, 0, 0), 0.3)
	local material = if golden then Enum.Material.Neon else rarity.Material

	local model = Instance.new("Model")
	model.Name = def.Name

	local body = makePart({
		Name = "Body",
		Shape = if def.Shape == "Block" then Enum.PartType.Block else Enum.PartType.Ball,
		Size = if def.Shape == "Block" then Vector3.new(s, s * 0.85, s) else Vector3.one * s,
		Color = color,
		Material = material,
		Anchored = true,
		Massless = false,
	})
	body.Parent = model
	model.PrimaryPart = body

	local function attach(part: BasePart, offset: CFrame)
		part.CFrame = body.CFrame * offset
		part.Parent = model
		weld(body, part)
	end

	for _, side in { -1, 1 } do
		attach(makePart({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.3, Color = Color3.new(1, 1, 1) }), CFrame.new(side * s * 0.2, s * 0.12, -s * 0.4))
		attach(makePart({ Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.15, Color = Color3.new(0, 0, 0) }), CFrame.new(side * s * 0.2, s * 0.12, -s * 0.53))
		attach(makePart({ Name = "Cheek", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.14, Color = Color3.fromRGB(255, 140, 160) }), CFrame.new(side * s * 0.33, -s * 0.06, -s * 0.38))
		attach(makePart({ Name = "Foot", Size = Vector3.new(s * 0.25, s * 0.18, s * 0.32), Color = accent }), CFrame.new(side * s * 0.22, -s * 0.48, -s * 0.05))
		if def.Ears then
			attach(makePart({ Name = "Ear", Size = Vector3.new(s * 0.18, s * 0.32, s * 0.12), Color = accent }), CFrame.new(side * s * 0.25, s * 0.52, -s * 0.05) * CFrame.Angles(0, 0, side * -0.3))
		end
		if def.Wings then
			attach(makePart({ Name = "Wing", Size = Vector3.new(s * 0.55, s * 0.08, s * 0.35), Color = Color3.new(1, 1, 1), Transparency = 0.15 }), CFrame.new(side * s * 0.6, s * 0.15, s * 0.1) * CFrame.Angles(0, 0, side * 0.45))
		end
	end
	if def.Tail then
		attach(makePart({ Name = "Tail", Size = Vector3.new(s * 0.14, s * 0.14, s * 0.45), Color = accent }), CFrame.new(0, -s * 0.1, s * 0.6) * CFrame.Angles(0.5, 0, 0))
	end
	if def.Horn then
		attach(makePart({ Name = "Horn", Size = Vector3.new(s * 0.12, s * 0.4, s * 0.12), Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.Neon }), CFrame.new(0, s * 0.55, -s * 0.2) * CFrame.Angles(-0.4, 0, 0))
	end
	if rarity.Crown then
		attach(makePart({ Name = "Crown", Size = Vector3.new(s * 0.45, s * 0.2, s * 0.45), Color = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Neon }), CFrame.new(0, s * 0.62, 0.05))
	end
	if rarity.Sparkles or golden then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = if golden then GOLD else rarity.Color
		sparkles.Parent = body
	end

	return model
end

return PetFactory
