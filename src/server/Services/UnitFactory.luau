-- Baut die Kreaturen aus einfachen Parts (keine fremden Assets noetig).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local UnitFactory = {}

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
	part.Anchored = false
	part.Massless = true
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Liefert ein Model, dessen PrimaryPart "Body" verankert ist; alle anderen Teile sind angeschweisst.
-- info kommt aus Units.Info (enthaelt Def, Mutation und Fusionsstufe).
function UnitFactory.Build(info): Model
	local def = info.Def
	local mutation = info.Mutation
	local rarity = Config.RaritiesByName[def.Rarity]
	local s = info.Scale
	local model = Instance.new("Model")
	model.Name = info.Name

	local body = makePart({
		Name = "Body",
		Shape = if def.Shape == "Block" then Enum.PartType.Block else Enum.PartType.Ball,
		Size = Vector3.one * s,
		Color = if mutation then mutation.Color else def.Color,
		Material = if mutation then mutation.Material else rarity.Material,
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

	local baseColor = if mutation then mutation.Color else def.Color
	local dark = baseColor:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, side in { -1, 1 } do
		attach(makePart({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.34, Color = Color3.new(1, 1, 1) }), CFrame.new(side * s * 0.2, s * 0.15, -s * 0.4))
		attach(makePart({ Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.17, Color = Color3.fromRGB(20, 15, 30) }), CFrame.new(side * s * 0.2, s * 0.15, -s * 0.55))
		attach(makePart({ Name = "Shine", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.06, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon }), CFrame.new(side * s * 0.2 - s * 0.04, s * 0.2, -s * 0.62))
		attach(makePart({ Name = "Cheek", Shape = Enum.PartType.Ball, Size = Vector3.new(s * 0.16, s * 0.1, s * 0.05), Color = Color3.fromRGB(255, 120, 160) }), CFrame.new(side * s * 0.32, -s * 0.05, -s * 0.47))
		attach(makePart({ Name = "Foot", Size = Vector3.new(s * 0.25, s * 0.2, s * 0.35), Color = dark }), CFrame.new(side * s * 0.22, -s * 0.5, -s * 0.05))
	end
	attach(makePart({ Name = "Mouth", Size = Vector3.new(s * 0.2, s * 0.05, s * 0.05), Color = Color3.fromRGB(20, 15, 30) }), CFrame.new(0, -s * 0.1, -s * 0.5))

	-- Jede Art bekommt feste Kopf-Deko (aus der Id abgeleitet): Ohren, Hoerner, Antenne oder Hasenohren
	local hash = 0
	for index = 1, #def.Id do
		hash += string.byte(def.Id, index) * index
	end
	local style = hash % 4
	for _, side in { -1, 1 } do
		if style == 0 then
			attach(makePart({ Name = "Ear", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.3, Color = dark }), CFrame.new(side * s * 0.35, s * 0.42, 0))
		elseif style == 1 then
			attach(makePart({ Name = "Horn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(s * 0.4, s * 0.1, s * 0.1), Color = Color3.fromRGB(255, 240, 210) }), CFrame.new(side * s * 0.28, s * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90 - side * 25)))
		elseif style == 2 and side == 1 then
			attach(makePart({ Name = "Antenna", Size = Vector3.new(s * 0.05, s * 0.4, s * 0.05), Color = dark }), CFrame.new(0, s * 0.65, 0))
			attach(makePart({ Name = "AntennaTip", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.16, Color = rarity.Color, Material = Enum.Material.Neon }), CFrame.new(0, s * 0.88, 0))
		elseif style == 3 then
			attach(makePart({ Name = "BunnyEar", Size = Vector3.new(s * 0.14, s * 0.5, s * 0.08), Color = baseColor }), CFrame.new(side * s * 0.18, s * 0.68, 0) * CFrame.Angles(0, 0, math.rad(-side * 12)))
		end
	end

	-- Ab Legendary: leuchtende Fluegel
	if rarity.Crown then
		for _, side in { -1, 1 } do
			attach(makePart({ Name = "Wing", Size = Vector3.new(s * 0.7, s * 0.45, s * 0.05), Color = rarity.Color, Material = Enum.Material.Neon, Transparency = 0.35 }), CFrame.new(side * s * 0.62, s * 0.15, s * 0.25) * CFrame.Angles(0, math.rad(side * 30), math.rad(side * 20)))
		end
	end

	-- Ab Rare: Glitzer-Aura in der Farbe der Seltenheit
	if rarity.Lucky then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Color = ColorSequence.new(if mutation then mutation.Color else rarity.Color)
		aura.LightEmission = 1
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.18), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new(0.2, 1)
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Rate = if rarity.Crown then 14 else 6
		aura.Speed = NumberRange.new(s * 0.4, s * 0.8)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = body
	end

	if rarity.Crown then
		attach(makePart({ Name = "Crown", Size = Vector3.new(s * 0.5, s * 0.25, s * 0.5), Color = Color3.fromRGB(255, 215, 0), Material = Enum.Material.Neon }), CFrame.new(0, s * 0.6, 0))
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Range = s * 4
		light.Brightness = 2
		light.Parent = body
	end
	if rarity.Sparkles or (mutation and mutation.Multiplier >= 4) then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = if mutation then mutation.Color else rarity.Color
		sparkles.Parent = body
	end
	if mutation and mutation.Name == "Rainbow" then
		CollectionService:AddTag(body, "RainbowCritter") -- Client laesst die Farbe durchlaufen
	end
	if info.Fusion > 0 then
		local fire = Instance.new("Fire")
		fire.Size = s * 0.6
		fire.Heat = 0
		fire.Color = Color3.fromRGB(180, 80, 255)
		fire.SecondaryColor = Color3.fromRGB(80, 200, 255)
		fire.Parent = body
	end

	return model
end

-- Namensschild ueber der Kreatur. Gibt das Label der dritten Zeile zurueck (Preis oder Einkommen).
function UnitFactory.AddLabel(model: Model, info, infoText: string): TextLabel
	local def = info.Def
	local rarity = Config.RaritiesByName[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(180, 66)
	gui.StudsOffset = Vector3.new(0, info.Scale * 0.5 + 2.2, 0)
	gui.MaxDistance = 80
	gui.Parent = model.PrimaryPart

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui

	local function line(text: string, color: Color3, height: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.1
		label.Parent = gui
		return label
	end

	line(info.Name, if info.Mutation then info.Mutation.Color else Color3.new(1, 1, 1), 24)
	line(def.Rarity, rarity.Color, 18)
	return line(infoText, Color3.fromRGB(120, 255, 120), 22)
end

function UnitFactory.SetTransparency(model: Model, transparency: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Transparency = transparency
		end
	end
end

return UnitFactory
