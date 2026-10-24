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

local INK = Color3.fromRGB(25, 20, 30)

-- Liefert ein Model, dessen PrimaryPart "Body" verankert ist; alle anderen Teile sind angeschweisst.
-- info kommt aus Units.Info (enthaelt Def, Mutation und Fusionsstufe).
-- Jede Art hat eine Bauform (Def.Body) und Merkmale (Def.Extras), damit sie wie ein echtes Tier aussieht.
function UnitFactory.Build(info): Model
	local def = info.Def
	local mutation = info.Mutation
	local rarity = Config.RaritiesByName[def.Rarity]
	local s = info.Scale
	local model = Instance.new("Model")
	model.Name = info.Name

	local extras = {}
	for _, extra in def.Extras or {} do
		extras[extra] = true
	end
	local skin = if mutation then mutation.Color else def.Color
	local skinMaterial = if mutation then mutation.Material
		elseif extras.Metal then Enum.Material.Metal
		elseif extras.Rocky then Enum.Material.Slate
		else Enum.Material.SmoothPlastic
	local dark = skin:Lerp(Color3.new(0, 0, 0), 0.3)
	local light = skin:Lerp(Color3.new(1, 1, 1), 0.35)
	local kind = def.Body or "Blob"

	-- Rumpf (verankert, Mittelpunkt des Modells)
	local bodySize, bodyShape
	if kind == "Quad" then
		bodySize, bodyShape = Vector3.new(0.7, 0.5, 0.95) * s, Enum.PartType.Block
	elseif kind == "Lizard" then
		bodySize, bodyShape = Vector3.new(0.5, 0.32, 1.05) * s, Enum.PartType.Block
	elseif kind == "Frog" then
		bodySize, bodyShape = Vector3.new(0.85, 0.5, 0.75) * s, Enum.PartType.Block
	elseif kind == "Biped" then
		bodySize, bodyShape = Vector3.new(0.6, 0.55, 0.42) * s, Enum.PartType.Block
	elseif kind == "Bird" then
		bodySize, bodyShape = Vector3.one * 0.62 * s, Enum.PartType.Ball
	else -- Blob, Ghost, Dragon
		bodySize, bodyShape = Vector3.one * 0.8 * s, Enum.PartType.Ball
	end
	local body = makePart({
		Name = "Body",
		Shape = bodyShape,
		Size = bodySize,
		Color = skin,
		Material = if kind == "Blob" and not mutation then Enum.Material.Glass else skinMaterial,
		Transparency = if kind == "Ghost" then 0.25 elseif kind == "Blob" and not mutation then 0.15 else 0,
		Anchored = true,
		Massless = false,
	})
	body.Parent = model
	model.PrimaryPart = body

	local function attach(part: BasePart, offset: CFrame): BasePart
		part.CFrame = body.CFrame * offset
		part.Parent = model
		weld(body, part)
		return part
	end
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3?, props: any?): BasePart
		local data = { Name = name, Size = size, Color = color or skin, Material = skinMaterial }
		for key, value in props or {} do
			data[key] = value
		end
		return attach(makePart(data), offset)
	end
	local function ball(name: string, diameter: number, offset: CFrame, color: Color3?, props: any?): BasePart
		local data = props or {}
		data.Shape = Enum.PartType.Ball
		return piece(name, Vector3.one * diameter, offset, color, data)
	end

	-- Kopf: Position und Groesse je Bauform (vorne = -Z)
	local headSize, headPos
	if kind == "Quad" then
		local neck = if extras.LongNeck then 0.35 else 0
		headSize, headPos = 0.48 * s, Vector3.new(0, (0.28 + neck) * s, -0.52 * s)
		if neck > 0 then
			piece("Neck", Vector3.new(0.22, 0.5, 0.22) * s, CFrame.new(0, 0.32 * s, -0.42 * s))
		end
	elseif kind == "Lizard" then
		headSize, headPos = 0.38 * s, Vector3.new(0, 0.05 * s, -0.62 * s)
	elseif kind == "Frog" then
		headSize, headPos = 0, Vector3.new(0, 0.1 * s, -0.3 * s)
	elseif kind == "Biped" then
		headSize, headPos = 0.5 * s, Vector3.new(0, 0.5 * s, 0)
	elseif kind == "Bird" then
		local neck = if extras.LongNeck then 0.3 else 0
		headSize, headPos = 0.38 * s, Vector3.new(0, (0.38 + neck) * s, -0.18 * s)
		if neck > 0 then
			piece("Neck", Vector3.new(0.16, 0.45, 0.16) * s, CFrame.new(0, 0.3 * s, -0.16 * s))
		end
	elseif kind == "Dragon" then
		headSize, headPos = 0.45 * s, Vector3.new(0, 0.42 * s, -0.25 * s)
	else -- Blob, Ghost: Gesicht direkt auf dem Koerper
		headSize, headPos = 0, Vector3.new(0, 0.05 * s, 0)
	end
	local headRadius = if headSize > 0 then headSize / 2 else bodySize.Z / 2
	if headSize > 0 then
		if kind == "Biped" and def.Shape == "Block" then
			piece("Head", Vector3.one * headSize, CFrame.new(headPos))
		else
			ball("Head", headSize, CFrame.new(headPos))
		end
	end

	-- Gesicht
	local eyeSize = if kind == "Frog" then 0.3 * s else math.max(headRadius * 0.55, 0.12 * s)
	for _, side in { -1, 1 } do
		local eyePos
		if kind == "Frog" then
			eyePos = Vector3.new(side * 0.25 * s, 0.3 * s, -0.22 * s)
		else
			eyePos = headPos + Vector3.new(side * headRadius * 0.42, headRadius * 0.18, -headRadius * 0.82)
		end
		ball("Eye", eyeSize, CFrame.new(eyePos), Color3.new(1, 1, 1), { Material = Enum.Material.SmoothPlastic })
		ball("Pupil", eyeSize * 0.5, CFrame.new(eyePos + Vector3.new(0, 0, -eyeSize * 0.35)), INK, { Material = Enum.Material.SmoothPlastic })
	end
	local front = headPos + Vector3.new(0, 0, -headRadius)
	if extras.Beak then
		piece("Beak", Vector3.new(0.18, 0.1, 0.22) * s, CFrame.new(front + Vector3.new(0, -0.02 * s, -0.08 * s)), Color3.fromRGB(240, 160, 50), { Material = Enum.Material.SmoothPlastic })
	elseif extras.Snout then
		piece("Snout", Vector3.new(0.26, 0.18, 0.14) * s, CFrame.new(front + Vector3.new(0, -0.1 * s, -0.02 * s)), dark)
	elseif kind ~= "Frog" then
		-- Auf Kugeln liegt der Mund etwas weiter hinten als die Vorderkante
		local blockHead = kind == "Biped" and def.Shape == "Block"
		local depth = if blockHead then 0 else headRadius * 0.06
		piece("Mouth", Vector3.new(0.16, 0.035, 0.04) * s, CFrame.new(front + Vector3.new(0, -headRadius * 0.35, depth - 0.015 * s)), INK, { Material = Enum.Material.SmoothPlastic })
	else
		piece("Mouth", Vector3.new(0.5, 0.04, 0.03) * s, CFrame.new(0, 0.02 * s, -0.38 * s), INK, { Material = Enum.Material.SmoothPlastic })
	end

	-- Beine je Bauform
	local footColor = if kind == "Bird" then Color3.fromRGB(240, 160, 50) else dark
	if kind == "Quad" or kind == "Lizard" then
		local legHeight = if kind == "Lizard" then 0.18 else 0.3
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				piece("Leg", Vector3.new(0.15, legHeight, 0.15) * s, CFrame.new(x * bodySize.X * 0.35, -bodySize.Y / 2 - legHeight * s / 2 + 0.02 * s, z * bodySize.Z * 0.35), dark)
			end
		end
	elseif kind == "Biped" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.18, 0.25, 0.2) * s, CFrame.new(side * 0.15 * s, -0.4 * s, 0), dark)
			piece("Arm", Vector3.new(0.14, 0.4, 0.14) * s, CFrame.new(side * 0.38 * s, -0.02 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 12)))
		end
	elseif kind == "Bird" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.06, 0.22, 0.06) * s, CFrame.new(side * 0.12 * s, -0.38 * s, 0), footColor, { Material = Enum.Material.SmoothPlastic })
			piece("Wing", Vector3.new(0.08, 0.32, 0.42) * s, CFrame.new(side * 0.32 * s, 0, 0.02 * s) * CFrame.Angles(0, 0, math.rad(side * -10)), dark)
		end
		piece("TailFeather", Vector3.new(0.3, 0.06, 0.25) * s, CFrame.new(0, 0.12 * s, 0.35 * s) * CFrame.Angles(math.rad(30), 0, 0), dark)
	elseif kind == "Frog" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.25, 0.15, 0.4) * s, CFrame.new(side * 0.42 * s, -0.22 * s, 0.1 * s), dark)
		end
	elseif kind == "Ghost" then
		for i = -1, 1 do
			ball("Wisp", 0.28 * s, CFrame.new(i * 0.22 * s, -0.42 * s, 0), skin, { Transparency = 0.35 })
		end
	elseif kind == "Blob" and extras.Cone then
		-- Waffel-Eistuete aus immer schmaleren Scheiben
		for i = 0, 3 do
			local width = (0.55 - i * 0.12) * s
			piece("Cone", Vector3.new(0.14 * s, width, width), CFrame.new(0, -0.38 * s - i * 0.13 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(215, 160, 90), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic })
		end
	elseif kind == "Blob" then
		for _, side in { -1, 1 } do
			ball("Drop", 0.2 * s, CFrame.new(side * 0.3 * s, -0.36 * s, -0.1 * s), light, { Transparency = 0.2 })
		end
	elseif kind == "Dragon" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.18, 0.2, 0.2) * s, CFrame.new(side * 0.22 * s, -0.42 * s, 0), dark)
		end
	end

	-- Merkmale
	local top = headPos + Vector3.new(0, headRadius, 0)
	for _, side in { -1, 1 } do
		if extras.CatEars or extras.Ears then
			piece("Ear", Vector3.new(0.12, 0.16, 0.06) * s, CFrame.new(top + Vector3.new(side * headRadius * 0.55, 0, 0)) * CFrame.Angles(0, 0, math.rad(side * -15)), dark)
		end
		if extras.BigEars then
			piece("Ear", Vector3.new(0.35, 0.12, 0.05) * s, CFrame.new(headPos + Vector3.new(side * headRadius * 1.15, headRadius * 0.2, 0)) * CFrame.Angles(0, 0, math.rad(side * 20)), dark)
		end
		if extras.Horns then
			piece("Horn", Vector3.new(0.07, 0.25, 0.07) * s, CFrame.new(top + Vector3.new(side * headRadius * 0.45, 0.05 * s, 0.05 * s)) * CFrame.Angles(math.rad(-20), 0, math.rad(side * -20)), Color3.fromRGB(245, 235, 210), { Material = Enum.Material.SmoothPlastic })
		end
	end
	if extras.Tail then
		local back = if kind == "Lizard" then 0.75 else 0.55
		piece("Tail", Vector3.new(0.1, 0.1, 0.5) * s, CFrame.new(0, 0.05 * s, back * s) * CFrame.Angles(math.rad(20), 0, 0), dark)
	end
	if extras.Spikes then
		for i = -1, 1 do
			piece("Spike", Vector3.new(0.05, 0.14, 0.05) * s, CFrame.new(i * 0.2 * s, bodySize.Y / 2 + 0.05 * s, i * 0.15 * s), Color3.fromRGB(240, 240, 200), { Material = Enum.Material.SmoothPlastic })
		end
	end
	if extras.Shell then
		piece("Shell", Vector3.new(0.85, 0.35, 1.0) * s, CFrame.new(0, bodySize.Y / 2 + 0.08 * s, 0.05 * s), Color3.fromRGB(70, 120, 60), { Material = Enum.Material.Slate })
	end
	if extras.Comb then
		piece("Comb", Vector3.new(0.05, 0.14, 0.22) * s, CFrame.new(top + Vector3.new(0, 0.04 * s, 0)), Color3.fromRGB(220, 50, 50), { Material = Enum.Material.SmoothPlastic })
	end
	if extras.Helmet then
		piece("Helmet", Vector3.new(0.56, 0.3, 0.56) * s, CFrame.new(headPos + Vector3.new(0, 0.14 * s, 0)), Color3.fromRGB(170, 175, 185), { Material = Enum.Material.Metal })
	end
	if extras.Headband then
		piece("Headband", Vector3.new(0.54, 0.08, 0.54) * s, CFrame.new(headPos + Vector3.new(0, 0.1 * s, 0)), Color3.fromRGB(200, 40, 50), { Material = Enum.Material.Fabric })
	end
	if extras.PirateHat then
		piece("Hat", Vector3.new(0.6, 0.12, 0.35) * s, CFrame.new(top + Vector3.new(0, 0.02 * s, 0)), INK, { Material = Enum.Material.Fabric })
		piece("HatTop", Vector3.new(0.35, 0.18, 0.3) * s, CFrame.new(top + Vector3.new(0, 0.15 * s, 0)), INK, { Material = Enum.Material.Fabric })
	end
	if extras.EyePatch then
		piece("EyePatch", Vector3.new(0.16, 0.16, 0.03) * s, CFrame.new(headPos + Vector3.new(headRadius * 0.42, headRadius * 0.18, -headRadius - 0.04 * s)), INK, { Material = Enum.Material.Fabric })
	end
	if extras.Cherry then
		ball("Cherry", 0.18 * s, CFrame.new(top + Vector3.new(0, 0.06 * s, 0)), Color3.fromRGB(210, 40, 60), { Material = Enum.Material.SmoothPlastic })
	end
	if extras.DiscoBall then
		ball("DiscoBall", 0.18 * s, CFrame.new(top + Vector3.new(0, 0.15 * s, 0)), Color3.fromRGB(220, 220, 230), { Material = Enum.Material.Foil })
	end

	-- Ab Legendary: goldene Krone und sanfte Fluegel
	if rarity.Crown then
		piece("Crown", Vector3.new(0.3, 0.14, 0.3) * s, CFrame.new(top + Vector3.new(0, 0.05 * s, 0)), Color3.fromRGB(240, 195, 60), { Material = Enum.Material.Foil })
		if kind ~= "Bird" then
			for _, side in { -1, 1 } do
				piece("Wing", Vector3.new(0.32, 0.22, 0.03) * s, CFrame.new(side * (bodySize.X / 2 + 0.1 * s), 0.12 * s, 0.25 * s) * CFrame.Angles(0, math.rad(side * -35), math.rad(side * 25)), Color3.fromRGB(245, 240, 255), { Material = Enum.Material.SmoothPlastic, Transparency = 0.15 })
			end
		end
	end
	if rarity.Name == "Mythic" then
		local glow = Instance.new("PointLight")
		glow.Color = rarity.Color
		glow.Range = s * 3
		glow.Brightness = 0.8
		glow.Parent = body
	end
	-- Ab Legendary: dezentes Glitzern in der Farbe der Seltenheit
	if rarity.Crown or (mutation and mutation.Multiplier >= 4) then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Color = ColorSequence.new(if mutation then mutation.Color else rarity.Color)
		aura.LightEmission = 0.5
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.1), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new(0.3, 1)
		aura.Lifetime = NumberRange.new(0.8, 1.2)
		aura.Rate = 4
		aura.Speed = NumberRange.new(s * 0.2, s * 0.4)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = body
	end
	if mutation and mutation.Name == "Rainbow" then
		CollectionService:AddTag(body, "RainbowCritter") -- Client laesst die Farbe durchlaufen
		local head = model:FindFirstChild("Head")
		if head then
			CollectionService:AddTag(head, "RainbowCritter")
		end
	end
	if info.Fusion > 0 then
		local fire = Instance.new("Fire")
		fire.Size = s * 0.4
		fire.Heat = 0
		fire.Color = Color3.fromRGB(150, 100, 220)
		fire.SecondaryColor = Color3.fromRGB(120, 180, 230)
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
