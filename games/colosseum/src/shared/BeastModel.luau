-- Baut die Bestien aus einfachen Parts (keine fremden Assets noetig).
-- Das Model hat einen verankerten PrimaryPart "Body", alle anderen Teile sind angeschweisst,
-- so kann man es mit PivotTo/Tween bewegen.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BeastModel = {}

local INK = Color3.fromRGB(25, 20, 30)
local PRISM = Color3.fromRGB(150, 255, 245)

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
	part.Anchored = false
	part.Massless = true
	part.CastShadow = false
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Groesse nach Seltenheit und Level (spaetere Stufen sind groesser)
function BeastModel.Scale(beastId: string, level: number): number
	local def = Config.BeastsById[beastId]
	local rarity = Config.RaritiesByName[def.Rarity]
	return 2.6 + rarity.Index * 0.55 + math.min(level, 60) * 0.012
end

-- Hoehe vom Boden bis zur Koerpermitte
function BeastModel.Hover(beastId: string, scale: number): number
	local kind = Config.BeastsById[beastId].Body
	if kind == "Ghost" or kind == "Bird" then
		return scale * 0.75
	end
	return scale * 0.55
end

function BeastModel.Build(beastId: string, level: number, shiny: boolean?): Model
	local def = Config.BeastsById[beastId]
	local rarity = Config.RaritiesByName[def.Rarity]
	local s = BeastModel.Scale(beastId, level)
	local model = Instance.new("Model")
	model.Name = def.Name

	local extras = {}
	for _, extra in def.Extras or {} do
		extras[extra] = true
	end
	-- Prismatisch (shiny): eigene, schillernde Farbe
	local skin = if shiny then def.Color:Lerp(PRISM, 0.55) else def.Color
	local material = if extras.Rocky then Enum.Material.Slate else Enum.Material.SmoothPlastic
	local dark = skin:Lerp(Color3.new(0, 0, 0), 0.3)
	local light = skin:Lerp(Color3.new(1, 1, 1), 0.4)
	local typeColor = Config.Types[def.Type].Color
	local kind = def.Body

	local bodySize, bodyShape
	if kind == "Quad" then
		bodySize, bodyShape = Vector3.new(0.7, 0.5, 0.95) * s, Enum.PartType.Block
	elseif kind == "Lizard" then
		bodySize, bodyShape = Vector3.new(0.55, 0.34, 1.05) * s, Enum.PartType.Block
	elseif kind == "Frog" then
		bodySize, bodyShape = Vector3.new(0.85, 0.5, 0.75) * s, Enum.PartType.Block
	elseif kind == "Biped" then
		bodySize, bodyShape = Vector3.new(0.62, 0.6, 0.45) * s, Enum.PartType.Block
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
		Material = if shiny then Enum.Material.Glass elseif kind == "Ghost" then Enum.Material.Glass else material,
		Transparency = if kind == "Ghost" then 0.2 else 0,
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
		local data = { Name = name, Size = size, Color = color or skin, Material = material }
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

	-- Kopf (vorne = -Z)
	local headSize, headPos
	if kind == "Quad" then
		local neck = if extras.LongNeck then 0.35 else 0
		headSize, headPos = 0.5 * s, Vector3.new(0, (0.3 + neck) * s, -0.52 * s)
	elseif kind == "Lizard" then
		headSize, headPos = 0.4 * s, Vector3.new(0, 0.06 * s, -0.62 * s)
	elseif kind == "Frog" then
		headSize, headPos = 0, Vector3.new(0, 0.1 * s, -0.3 * s)
	elseif kind == "Biped" then
		headSize, headPos = 0.52 * s, Vector3.new(0, 0.55 * s, 0)
	elseif kind == "Bird" then
		local neck = if extras.LongNeck then 0.3 else 0
		headSize, headPos = 0.4 * s, Vector3.new(0, (0.38 + neck) * s, -0.18 * s)
		if neck > 0 then
			piece("Neck", Vector3.new(0.16, 0.45, 0.16) * s, CFrame.new(0, 0.3 * s, -0.16 * s))
		end
	elseif kind == "Dragon" then
		headSize, headPos = 0.48 * s, Vector3.new(0, 0.44 * s, -0.28 * s)
	else
		headSize, headPos = 0, Vector3.new(0, 0.05 * s, 0)
	end
	local headRadius = if headSize > 0 then headSize / 2 else bodySize.Z / 2
	if headSize > 0 then
		ball("Head", headSize, CFrame.new(headPos))
	end

	-- Gesicht: grosse Augen mit Glanzpunkt, entschlossene Augenbrauen (Kampf-Look)
	local eyeSize = if kind == "Frog" then 0.3 * s else math.max(headRadius * 0.55, 0.12 * s)
	for _, side in { -1, 1 } do
		local eyePos
		if kind == "Frog" then
			eyePos = Vector3.new(side * 0.25 * s, 0.3 * s, -0.22 * s)
		else
			eyePos = headPos + Vector3.new(side * headRadius * 0.42, headRadius * 0.18, -headRadius * 0.82)
		end
		ball("Eye", eyeSize, CFrame.new(eyePos), Color3.new(1, 1, 1), { Material = Enum.Material.SmoothPlastic })
		ball("Pupil", eyeSize * 0.55, CFrame.new(eyePos + Vector3.new(0, 0, -eyeSize * 0.32)), if shiny then Color3.fromRGB(40, 110, 140) else INK, { Material = Enum.Material.SmoothPlastic })
		ball("Shine", eyeSize * 0.18, CFrame.new(eyePos + Vector3.new(side * -eyeSize * 0.12, eyeSize * 0.15, -eyeSize * 0.5)), Color3.new(1, 1, 1), { Material = Enum.Material.Neon })
		piece("Brow", Vector3.new(eyeSize * 0.9, eyeSize * 0.16, eyeSize * 0.2), CFrame.new(eyePos + Vector3.new(0, eyeSize * 0.55, -eyeSize * 0.3)) * CFrame.Angles(0, 0, math.rad(side * 18)), INK, { Material = Enum.Material.SmoothPlastic })
	end
	local front = headPos + Vector3.new(0, 0, -headRadius)
	if kind == "Bird" then
		piece("Beak", Vector3.new(0.18, 0.1, 0.22) * s, CFrame.new(front + Vector3.new(0, -0.02 * s, -0.08 * s)), Color3.fromRGB(240, 160, 50), { Material = Enum.Material.SmoothPlastic })
	elseif kind == "Quad" or kind == "Lizard" or kind == "Dragon" then
		piece("Snout", Vector3.new(0.26, 0.18, 0.16) * s, CFrame.new(front + Vector3.new(0, -0.1 * s, -0.02 * s)), light)
		piece("Nose", Vector3.new(0.08, 0.05, 0.04) * s, CFrame.new(front + Vector3.new(0, -0.04 * s, -0.11 * s)), INK, { Material = Enum.Material.SmoothPlastic })
	elseif kind == "Frog" then
		piece("Mouth", Vector3.new(0.5, 0.04, 0.03) * s, CFrame.new(0, 0.02 * s, -0.38 * s), INK, { Material = Enum.Material.SmoothPlastic })
	else
		piece("Mouth", Vector3.new(0.16, 0.035, 0.04) * s, CFrame.new(front + Vector3.new(0, -headRadius * 0.35, headRadius * 0.06)), INK, { Material = Enum.Material.SmoothPlastic })
	end

	-- Beine je Bauform
	if kind == "Quad" or kind == "Lizard" then
		local legHeight = if kind == "Lizard" then 0.18 else 0.3
		for _, x in { -1, 1 } do
			for _, z in { -1, 1 } do
				piece("Leg", Vector3.new(0.16, legHeight, 0.16) * s, CFrame.new(x * bodySize.X * 0.35, -bodySize.Y / 2 - legHeight * s / 2 + 0.02 * s, z * bodySize.Z * 0.35), dark)
			end
		end
	elseif kind == "Biped" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.2, 0.28, 0.22) * s, CFrame.new(side * 0.16 * s, -0.42 * s, 0), dark)
			piece("Arm", Vector3.new(0.16, 0.42, 0.16) * s, CFrame.new(side * 0.4 * s, -0.02 * s, 0) * CFrame.Angles(0, 0, math.rad(side * 12)))
			piece("Fist", Vector3.new(0.2, 0.18, 0.2) * s, CFrame.new(side * 0.44 * s, -0.24 * s, 0), dark)
		end
	elseif kind == "Bird" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.06, 0.22, 0.06) * s, CFrame.new(side * 0.12 * s, -0.38 * s, 0), Color3.fromRGB(240, 160, 50), { Material = Enum.Material.SmoothPlastic })
			piece("Wing", Vector3.new(0.06, 0.4, 0.5) * s, CFrame.new(side * 0.34 * s, 0.05 * s, 0.02 * s) * CFrame.Angles(0, 0, math.rad(side * -25)), light, { Transparency = 0.1 })
		end
		piece("TailFeather", Vector3.new(0.3, 0.06, 0.28) * s, CFrame.new(0, 0.12 * s, 0.35 * s) * CFrame.Angles(math.rad(30), 0, 0), dark)
	elseif kind == "Frog" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.25, 0.15, 0.4) * s, CFrame.new(side * 0.42 * s, -0.22 * s, 0.1 * s), dark)
		end
	elseif kind == "Ghost" then
		for i = -1, 1 do
			ball("Wisp", 0.28 * s, CFrame.new(i * 0.22 * s, -0.42 * s, 0), skin, { Transparency = 0.35, Material = Enum.Material.Glass })
		end
	elseif kind == "Blob" then
		for _, side in { -1, 1 } do
			ball("Foot", 0.24 * s, CFrame.new(side * 0.24 * s, -0.36 * s, -0.08 * s), dark)
		end
	elseif kind == "Dragon" then
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.2, 0.22, 0.22) * s, CFrame.new(side * 0.24 * s, -0.42 * s, 0), dark)
		end
	end

	-- Merkmale
	local top = headPos + Vector3.new(0, headRadius, 0)
	for _, side in { -1, 1 } do
		if extras.Ears then
			piece("Ear", Vector3.new(0.12, 0.18, 0.06) * s, CFrame.new(top + Vector3.new(side * headRadius * 0.55, 0, 0)) * CFrame.Angles(0, 0, math.rad(side * -15)), dark)
		end
		if extras.BigEars then
			piece("Ear", Vector3.new(0.14, 0.42, 0.06) * s, CFrame.new(top + Vector3.new(side * headRadius * 0.55, 0.12 * s, 0)) * CFrame.Angles(0, 0, math.rad(side * -22)), skin)
			piece("EarTip", Vector3.new(0.145, 0.12, 0.065) * s, CFrame.new(top + Vector3.new(side * (headRadius * 0.55 + 0.09 * s), 0.3 * s, 0)) * CFrame.Angles(0, 0, math.rad(side * -22)), INK, { Material = Enum.Material.SmoothPlastic })
		end
		if extras.Horns then
			piece("Horn", Vector3.new(0.08, 0.28, 0.08) * s, CFrame.new(top + Vector3.new(side * headRadius * 0.45, 0.05 * s, 0.05 * s)) * CFrame.Angles(math.rad(-20), 0, math.rad(side * -20)), Color3.fromRGB(245, 235, 210), { Material = Enum.Material.SmoothPlastic })
		end
		if extras.Antenna then
			piece("Antenna", Vector3.new(0.03, 0.3, 0.03) * s, CFrame.new(top + Vector3.new(side * headRadius * 0.35, 0.12 * s, 0)) * CFrame.Angles(0, 0, math.rad(side * -25)), INK, { Material = Enum.Material.SmoothPlastic })
			ball("AntennaTip", 0.09 * s, CFrame.new(top + Vector3.new(side * (headRadius * 0.35 + 0.08 * s), 0.27 * s, 0)), typeColor, { Material = Enum.Material.Neon })
		end
		if extras.BatWings then
			piece("Wing", Vector3.new(0.7, 0.04, 0.45) * s, CFrame.new(side * (bodySize.X / 2 + 0.3 * s), 0.25 * s, 0.1 * s) * CFrame.Angles(0, 0, math.rad(side * 25)), dark, { Material = Enum.Material.SmoothPlastic })
		end
		if extras.Fin and kind ~= "Dragon" then
			piece("SideFin", Vector3.new(0.3, 0.04, 0.25) * s, CFrame.new(side * (bodySize.X / 2 + 0.1 * s), 0, -0.1 * s) * CFrame.Angles(0, 0, math.rad(side * -20)), light)
		end
	end
	if extras.Tail then
		local back = if kind == "Lizard" then 0.75 elseif kind == "Biped" then 0.3 else 0.55
		local tail = piece("Tail", Vector3.new(0.12, 0.12, 0.55) * s, CFrame.new(0, 0.05 * s, back * s) * CFrame.Angles(math.rad(25), 0, 0), dark)
		if def.Type == "Fire" then
			local fire = Instance.new("Fire")
			fire.Size = s * 0.5
			fire.Heat = 2
			fire.Color = Color3.fromRGB(255, 150, 40)
			fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
			fire.Parent = tail
		end
	end
	if extras.Spikes then
		for i = -1, 1 do
			piece("Spike", Vector3.new(0.06, 0.16, 0.06) * s, CFrame.new(0, bodySize.Y / 2 + 0.06 * s, i * 0.22 * s), Color3.fromRGB(245, 235, 210), { Material = Enum.Material.SmoothPlastic })
		end
	end
	if extras.Mane then
		local maneColor = if def.Type == "Spark" then Color3.fromRGB(255, 250, 200) elseif def.Type == "Light" then Color3.fromRGB(255, 210, 90) else typeColor
		ball("Mane", headSize * 1.35, CFrame.new(headPos + Vector3.new(0, 0, headRadius * 0.35)), maneColor, { Material = Enum.Material.SmoothPlastic })
	end
	if extras.Fin then
		piece("Fin", Vector3.new(0.05, 0.35, 0.45) * s, CFrame.new(0, bodySize.Y / 2 + 0.12 * s, 0.05 * s) * CFrame.Angles(math.rad(-15), 0, 0), light)
	end
	if extras.Shell then
		piece("Shell", Vector3.new(0.85, 0.35, 1.0) * s, CFrame.new(0, bodySize.Y / 2 + 0.08 * s, 0.05 * s), if def.Type == "Leaf" then Color3.fromRGB(110, 80, 50) else Color3.fromRGB(90, 85, 80), { Material = Enum.Material.Slate })
	end
	if extras.Sprout then
		local sproutBase = if headSize > 0 then top else Vector3.new(0, bodySize.Y / 2, 0)
		piece("Stem", Vector3.new(0.04, 0.2, 0.04) * s, CFrame.new(sproutBase + Vector3.new(0, 0.08 * s, 0)), Color3.fromRGB(60, 140, 50), { Material = Enum.Material.SmoothPlastic })
		for _, side in { -1, 1 } do
			piece("Leaf", Vector3.new(0.22, 0.03, 0.12) * s, CFrame.new(sproutBase + Vector3.new(side * 0.1 * s, 0.18 * s, 0)) * CFrame.Angles(0, 0, math.rad(side * 25)), Color3.fromRGB(110, 220, 80), { Material = Enum.Material.SmoothPlastic })
		end
	end
	if extras.Flower then
		ball("Flower", 0.3 * s, CFrame.new(0, bodySize.Y / 2 + 0.32 * s, 0.05 * s), Color3.fromRGB(255, 120, 170), { Material = Enum.Material.SmoothPlastic })
		ball("FlowerCore", 0.14 * s, CFrame.new(0, bodySize.Y / 2 + 0.42 * s, 0.05 * s), Color3.fromRGB(255, 230, 80), { Material = Enum.Material.Neon })
	end
	if extras.Bolt then
		for i, z in { -0.2, 0.15 } do
			piece("Bolt", Vector3.new(0.05, 0.12, 0.25) * s, CFrame.new(0, bodySize.Y / 2 + 0.05 * s, z * s) * CFrame.Angles(0, math.rad(if i == 1 then 25 else -25), 0), Color3.fromRGB(40, 40, 50), { Material = Enum.Material.SmoothPlastic })
		end
	end
	if extras.Rocky then
		for i = 1, 3 do
			local angle = i * 2.1
			ball("Rock", 0.22 * s, CFrame.new(math.cos(angle) * bodySize.X * 0.4, bodySize.Y * 0.3, math.sin(angle) * bodySize.Z * 0.35), dark, { Material = Enum.Material.Slate })
		end
	end
	if extras.Comb then
		piece("Comb", Vector3.new(0.05, 0.18, 0.25) * s, CFrame.new(top + Vector3.new(0, 0.05 * s, 0)), Color3.fromRGB(255, 120, 60), { Material = Enum.Material.SmoothPlastic })
	end
	if extras.Helmet then
		piece("Helmet", Vector3.new(0.58, 0.3, 0.58) * s, CFrame.new(headPos + Vector3.new(0, 0.15 * s, 0)), Color3.fromRGB(215, 175, 70), { Material = Enum.Material.Metal })
		piece("Plume", Vector3.new(0.06, 0.25, 0.45) * s, CFrame.new(headPos + Vector3.new(0, 0.38 * s, 0.05 * s)), Color3.fromRGB(190, 30, 40), { Material = Enum.Material.Fabric })
	end
	if extras.Halo then
		piece("Halo", Vector3.new(0.05, 0.5, 0.5) * s, CFrame.new(top + Vector3.new(0, 0.3 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 230, 120), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Transparency = 0.3 })
	end

	if rarity.Crown then
		piece("Crown", Vector3.new(0.3, 0.14, 0.3) * s, CFrame.new(top + Vector3.new(0, 0.06 * s, 0)), Color3.fromRGB(240, 195, 60), { Material = Enum.Material.Foil })
	end
	if rarity.Glow then
		local glow = Instance.new("PointLight")
		glow.Color = rarity.Color
		glow.Range = s * 2.5
		glow.Brightness = 0.7
		glow.Parent = body
	end
	if rarity.Glow or shiny then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Color = if shiny then ColorSequence.new(Color3.fromRGB(120, 255, 240), Color3.fromRGB(255, 140, 255)) else ColorSequence.new(rarity.Color)
		aura.LightEmission = 0.6
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.1), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new(0.2, 1)
		aura.Lifetime = NumberRange.new(0.8, 1.3)
		aura.Rate = if shiny then 10 else 4
		aura.Speed = NumberRange.new(s * 0.2, s * 0.5)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = body
	end
	if shiny then
		CollectionService:AddTag(body, "Prismatic") -- Client laesst die Farbe schimmern
	end
	return model
end

-- Namensschild ueber der Bestie: Name, Level, Element (und Text fuer wilde Bestien)
function BeastModel.AddLabel(model: Model, beastId: string, level: number, shiny: boolean?, owner: string?)
	local def = Config.BeastsById[beastId]
	local rarity = Config.RaritiesByName[def.Rarity]
	local s = BeastModel.Scale(beastId, level)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.fromOffset(170, 50)
	gui.StudsOffset = Vector3.new(0, s * 0.6 + 1.6, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = model.PrimaryPart

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 26)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.LuckiestGuy
	name.TextSize = 22
	name.Text = (if shiny then "✦ " else "") .. def.Name
	name.TextColor3 = if shiny then Color3.fromRGB(150, 255, 245) else Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.2
	name.Parent = gui

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromOffset(0, 26)
	sub.Size = UDim2.new(1, 0, 0, 20)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.BuilderSansBold
	sub.TextSize = 15
	sub.RichText = true
	local typeHex = Config.Types[def.Type].Color:ToHex()
	sub.Text = `Lv {level}  <font color="#{typeHex}">{def.Type:upper()}</font>  <font color="#{rarity.Color:ToHex()}">{def.Rarity}</font>` .. (if owner then `  · {owner}` else "")
	sub.TextColor3 = Color3.fromRGB(235, 230, 220)
	sub.TextStrokeTransparency = 0.3
	sub.Parent = gui
	return gui
end

return BeastModel
