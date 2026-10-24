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

	for _, side in { -1, 1 } do
		attach(makePart({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.32, Color = Color3.new(1, 1, 1) }), CFrame.new(side * s * 0.2, s * 0.15, -s * 0.4))
		attach(makePart({ Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.one * s * 0.15, Color = Color3.new(0, 0, 0) }), CFrame.new(side * s * 0.2, s * 0.15, -s * 0.54))
		attach(makePart({ Name = "Foot", Size = Vector3.new(s * 0.25, s * 0.2, s * 0.35), Color = def.Color:Lerp(Color3.new(0, 0, 0), 0.3) }), CFrame.new(side * s * 0.22, -s * 0.5, -s * 0.05))
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
