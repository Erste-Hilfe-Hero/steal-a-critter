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
local BONE = Color3.fromRGB(245, 235, 215)
local WHITE = Color3.new(1, 1, 1)
local AMBER = Color3.fromRGB(255, 185, 40)

-- Liefert ein Model, dessen PrimaryPart "Body" verankert ist; alle anderen Teile sind angeschweisst.
-- info kommt aus Units.Info (enthaelt Def, Mutation und Fusionsstufe).
-- Stil "freche Monster": grosse Augen mit Glanzpunkt, boese Augenbrauen, Grinsen mit Reisszaehnen,
-- heller Bauch, Krallen. Je seltener, desto mehr Leuchten (Neon-Augen, Flecken, Krone, Heiligenschein).
-- Jede Art behaelt ihre Bauform (Def.Body) und Merkmale (Def.Extras).
function UnitFactory.Build(info): Model
	local def = info.Def
	local mutation = info.Mutation
	local rarity = Config.RaritiesByName[def.Rarity]
	local tier = rarity.Index or 1 -- 1 Common ... 7 Secret
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
	local dark = skin:Lerp(Color3.new(0, 0, 0), 0.35)
	local belly = skin:Lerp(WHITE, 0.5)
	local glow = if mutation then mutation.Color else rarity.Color
	-- Ab Epic leuchten Augen und Akzente in der Farbe der Seltenheit
	local glowing = tier >= 4 or (mutation ~= nil and mutation.Multiplier >= 4)
	local accent = if glowing then glow else BONE
	local accentMaterial = if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local kind = def.Body or "Blob"
	local blocky = def.Shape == "Block"

	local body: BasePart
	local function attach(part: BasePart, cf: CFrame): BasePart
		part.CFrame = body.CFrame * cf
		part.Parent = model
		weld(body, part)
		return part
	end
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3?, props: any?): BasePart
		local data = { Name = name, Size = size, Color = color or skin, Material = skinMaterial }
		for key, value in props or {} do
			data[key] = value
		end
		return attach(makePart(data), cf)
	end
	local function ball(name: string, diameter: number, pos: Vector3, color: Color3?, props: any?): BasePart
		local data = props or {}
		data.Shape = Enum.PartType.Ball
		return piece(name, Vector3.one * diameter, CFrame.new(pos), color, data)
	end
	-- Raute (45 Grad gedreht): halb versenkt ergibt sie Zaehne, Krallen, Stacheln
	local function spike(name: string, size: number, pos: Vector3, color: Color3, axis: string?, props: any?)
		local rot = if axis == "X" then CFrame.Angles(math.rad(45), 0, 0) else CFrame.Angles(0, 0, math.rad(45))
		local data = { Material = Enum.Material.SmoothPlastic }
		for key, value in props or {} do
			data[key] = value
		end
		return piece(name, Vector3.new(size, size, size * 0.5), CFrame.new(pos) * rot, color, data)
	end

	---------------------------------------------------------------- Rumpf je Bauform
	-- head: Mittelpunkt und Radius des Kopfes (Gesicht zeigt nach -Z)
	local bodyRadius = 0.4 * s
	local bodyY = 0
	local head = { Pos = Vector3.zero, R = 0.3 * s, Block = false }
	local legs = {} -- Fusspunkte (Unterkante)
	local tailStart: Vector3? = nil
	local hover = false

	local function makeBody(size: Vector3, shape, y: number, props: any?)
		local data = { Name = "Body", Shape = shape, Size = size, Color = skin, Material = skinMaterial, Anchored = true, Massless = false }
		for key, value in props or {} do
			data[key] = value
		end
		body = makePart(data)
		body.Parent = model
		model.PrimaryPart = body
		bodyY = y
	end

	if kind == "Blob" then
		bodyRadius = 0.5 * s
		makeBody(Vector3.one * 1.0 * s, Enum.PartType.Ball, 0, {
			Material = if mutation then skinMaterial else Enum.Material.Glass,
			Transparency = if mutation then 0 else 0.12,
		})
		head = { Pos = Vector3.new(0, 0.08 * s, 0), R = 0.5 * s, Block = false }
	elseif kind == "Ghost" then
		hover = true
		bodyRadius = 0.45 * s
		makeBody(Vector3.one * 0.9 * s, Enum.PartType.Ball, 0, { Transparency = 0.2 })
		head = { Pos = Vector3.new(0, 0.05 * s, 0), R = 0.45 * s, Block = false }
	elseif kind == "Frog" then
		bodyRadius = 0.42 * s
		makeBody(Vector3.one * 0.84 * s, Enum.PartType.Ball, 0)
		for _, side in { -1, 1 } do
			ball("Cheek", 0.62 * s, Vector3.new(side * 0.22 * s, -0.08 * s, -0.06 * s))
		end
		head = { Pos = Vector3.new(0, 0.02 * s, -0.02 * s), R = 0.42 * s, Block = false }
		for _, side in { -1, 1 } do
			table.insert(legs, Vector3.new(side * 0.34 * s, -0.56 * s, -0.22 * s))
			piece("HindLeg", Vector3.new(0.26, 0.2, 0.42) * s, CFrame.new(side * 0.42 * s, -0.42 * s, 0.12 * s), dark)
		end
	elseif kind == "Biped" then
		bodyRadius = 0.34 * s
		if blocky then
			makeBody(Vector3.new(0.66, 0.6, 0.5) * s, Enum.PartType.Block, 0)
		else
			makeBody(Vector3.one * 0.7 * s, Enum.PartType.Ball, 0)
		end
		head = { Pos = Vector3.new(0, 0.5 * s, 0), R = 0.32 * s, Block = blocky }
		if blocky then
			piece("Head", Vector3.one * 0.62 * s, CFrame.new(head.Pos))
		else
			ball("Head", 0.64 * s, head.Pos)
		end
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.2, 0.26, 0.22) * s, CFrame.new(side * 0.16 * s, -0.42 * s, 0), dark)
			table.insert(legs, Vector3.new(side * 0.16 * s, -0.55 * s, -0.1 * s))
			piece("Arm", Vector3.new(0.14, 0.36, 0.14) * s, CFrame.new(side * 0.4 * s, -0.02 * s, -0.02 * s) * CFrame.Angles(0, 0, math.rad(side * 18)))
			ball("Fist", 0.22 * s, Vector3.new(side * 0.47 * s, -0.2 * s, -0.04 * s), dark)
			for i = -1, 1, 2 do
				spike("Claw", 0.07 * s, Vector3.new(side * 0.47 * s + i * 0.05 * s, -0.3 * s, -0.08 * s), accent, nil, { Material = accentMaterial })
			end
		end
	elseif kind == "Bird" then
		bodyRadius = 0.36 * s
		makeBody(Vector3.one * 0.72 * s, Enum.PartType.Ball, 0)
		local neck = if extras.LongNeck then 0.28 * s else 0
		head = { Pos = Vector3.new(0, 0.4 * s + neck, -0.16 * s), R = 0.25 * s, Block = false }
		if neck > 0 then
			piece("Neck", Vector3.new(0.18 * s, 0.4 * s, 0.18 * s), CFrame.new(0, 0.3 * s, -0.14 * s))
		end
		ball("Head", 0.5 * s, head.Pos)
		for _, side in { -1, 1 } do
			piece("Leg", Vector3.new(0.06, 0.24, 0.06) * s, CFrame.new(side * 0.12 * s, -0.42 * s, 0), Color3.fromRGB(240, 160, 50), { Material = Enum.Material.SmoothPlastic })
			table.insert(legs, Vector3.new(side * 0.12 * s, -0.55 * s, -0.04 * s))
			-- Fluegel aus drei Federn
			for i = 0, 2 do
				piece("Wing", Vector3.new(0.06, 0.34 - i * 0.07, 0.16) * s, CFrame.new(side * 0.36 * s, 0.02 * s - i * 0.04 * s, (0.02 + i * 0.12) * s) * CFrame.Angles(math.rad(-15 - i * 12), 0, math.rad(side * -12)), dark)
			end
		end
		for i = -1, 1 do
			piece("TailFeather", Vector3.new(0.1, 0.05, 0.34) * s, CFrame.new(i * 0.1 * s, 0.1 * s, 0.38 * s) * CFrame.Angles(math.rad(35), math.rad(i * 20), 0), if i == 0 then accent else dark, if i == 0 then { Material = accentMaterial } else nil)
		end
	elseif kind == "Lizard" then
		bodyRadius = 0.3 * s
		makeBody(Vector3.one * 0.6 * s, Enum.PartType.Ball, -0.12 * s)
		ball("Hips", 0.52 * s, Vector3.new(0, -0.02 * s, 0.34 * s))
		head = { Pos = Vector3.new(0, 0.12 * s, -0.5 * s), R = 0.26 * s, Block = false }
		ball("Head", 0.52 * s, head.Pos)
		piece("Jaw", Vector3.new(0.34, 0.14, 0.26) * s, CFrame.new(0, 0.02 * s, -0.66 * s), skin)
		for _, x in { -1, 1 } do
			for _, z in { -0.15, 0.4 } do
				piece("Leg", Vector3.new(0.14, 0.24, 0.14) * s, CFrame.new(x * 0.3 * s, -0.36 * s, z * s) * CFrame.Angles(0, 0, math.rad(x * 25)), dark)
				table.insert(legs, Vector3.new(x * 0.36 * s, -0.55 * s, (z - 0.08) * s))
			end
		end
		tailStart = Vector3.new(0, 0, 0.6 * s)
	elseif kind == "Dragon" then
		bodyRadius = 0.4 * s
		makeBody(Vector3.one * 0.8 * s, Enum.PartType.Ball, 0)
		head = { Pos = Vector3.new(0, 0.48 * s, -0.3 * s), R = 0.28 * s, Block = false }
		ball("Head", 0.56 * s, head.Pos)
		piece("Snout", Vector3.new(0.34, 0.2, 0.26) * s, CFrame.new(head.Pos + Vector3.new(0, -0.08 * s, -0.24 * s)), skin)
		for _, side in { -1, 1 } do
			ball("Nostril", 0.05 * s, head.Pos + Vector3.new(side * 0.08 * s, -0.02 * s, -0.37 * s), INK)
			piece("Leg", Vector3.new(0.2, 0.26, 0.22) * s, CFrame.new(side * 0.22 * s, -0.42 * s, 0.02 * s), dark)
			table.insert(legs, Vector3.new(side * 0.22 * s, -0.55 * s, -0.1 * s))
			-- Fledermaus-Fluegel: drei Knochen mit Haut dazwischen
			for i = 0, 2 do
				piece("WingBone", Vector3.new(0.05, 0.05, 0.6 - i * 0.12) * s, CFrame.new(side * (0.42 + i * 0.12) * s, (0.32 - i * 0.1) * s, (0.2 + i * 0.05) * s) * CFrame.Angles(math.rad(-20 + i * 25), math.rad(side * 70), 0), dark)
			end
			piece("Wing", Vector3.new(0.5, 0.36, 0.03) * s, CFrame.new(side * 0.55 * s, 0.22 * s, 0.24 * s) * CFrame.Angles(0, math.rad(side * -20), math.rad(side * 20)), skin:Lerp(glow, 0.35), { Transparency = 0.1 })
		end
		tailStart = Vector3.new(0, -0.1 * s, 0.38 * s)
	else -- Quad
		bodyRadius = 0.38 * s
		if blocky then
			makeBody(Vector3.new(0.66, 0.54, 0.86) * s, Enum.PartType.Block, 0)
		else
			makeBody(Vector3.one * 0.76 * s, Enum.PartType.Ball, 0)
			ball("Hips", 0.66 * s, Vector3.new(0, -0.02 * s, 0.3 * s))
		end
		local neck = if extras.LongNeck then 0.34 * s else 0
		head = { Pos = Vector3.new(0, 0.3 * s + neck, -0.46 * s), R = 0.29 * s, Block = false }
		if neck > 0 then
			piece("Neck", Vector3.new(0.24 * s, 0.5 * s, 0.24 * s), CFrame.new(0, 0.34 * s, -0.4 * s))
		end
		ball("Head", 0.58 * s, head.Pos)
		for _, x in { -1, 1 } do
			for _, z in { -0.24, 0.32 } do
				piece("Leg", Vector3.new(0.2, 0.3, 0.2) * s, CFrame.new(x * 0.24 * s, -0.4 * s, z * s), dark)
				table.insert(legs, Vector3.new(x * 0.24 * s, -0.55 * s, (z - 0.1) * s))
			end
		end
		tailStart = Vector3.new(0, 0.08 * s, 0.6 * s)
	end
	if hover then
		-- Geister schweben: Schweif aus kleiner werdenden Kugeln
		for i = 1, 3 do
			ball("Wisp", (0.5 - i * 0.11) * s, Vector3.new(0, (-0.32 - i * 0.08) * s, (0.12 + i * 0.14) * s), skin, { Transparency = 0.3 })
		end
	end

	---------------------------------------------------------------- Gesicht

	local hp, hr = head.Pos, head.R
	local front = hp + Vector3.new(0, 0, -hr)
	-- Heller Bauch vorne am Rumpf (nicht bei Blob/Geist, dort ist das Gesicht)
	if kind ~= "Blob" and kind ~= "Ghost" and kind ~= "Frog" and not blocky then
		ball("Belly", bodyRadius * 1.15, Vector3.new(0, -0.08 * s, -bodyRadius * 0.5), belly, { Material = Enum.Material.SmoothPlastic })
	end

	local eyeD = math.max(hr * 0.62, 0.14 * s)
	local iris = if glowing then glow elseif tier >= 3 then rarity.Color else AMBER
	local frog = kind == "Frog"
	for _, side in { -1, 1 } do
		local eyePos
		if frog then
			-- Froschaugen sitzen oben auf dem Kopf
			eyePos = hp + Vector3.new(side * hr * 0.5, hr * 0.85, -hr * 0.35)
			ball("EyeBump", eyeD * 1.25, eyePos + Vector3.new(0, -eyeD * 0.1, eyeD * 0.1))
		elseif head.Block then
			eyePos = hp + Vector3.new(side * hr * 0.42, hr * 0.15, -hr - eyeD * 0.1)
		else
			eyePos = hp + Vector3.new(side * hr * 0.4, hr * 0.2, -hr * 0.8)
		end
		local fwd = Vector3.new(0, 0, -1)
		ball("Eye", eyeD, eyePos, WHITE, { Material = Enum.Material.SmoothPlastic })
		ball("Iris", eyeD * 0.64, eyePos + fwd * (eyeD * 0.26) + Vector3.new(-side * eyeD * 0.04, 0, 0), iris, { Material = if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		ball("Pupil", eyeD * 0.34, eyePos + fwd * (eyeD * 0.4) + Vector3.new(-side * eyeD * 0.05, 0, 0), INK, { Material = Enum.Material.SmoothPlastic })
		ball("Shine", eyeD * 0.17, eyePos + fwd * (eyeD * 0.47) + Vector3.new(eyeD * 0.1, eyeD * 0.12, 0), WHITE, { Material = Enum.Material.Neon })
		-- Freche Augenbraue: innen tiefer
		if not extras.EyePatch or side < 0 then
			piece("Brow", Vector3.new(eyeD * 0.95, eyeD * 0.18, eyeD * 0.2), CFrame.new(eyePos + Vector3.new(0, eyeD * 0.58, -eyeD * 0.32)) * CFrame.Angles(0, 0, math.rad(side * 22)), dark:Lerp(INK, 0.5), { Material = Enum.Material.SmoothPlastic })
		end
	end

	-- Mund: breites Grinsen mit zwei Reisszaehnen (Vogel: Schnabel)
	if extras.Beak or kind == "Bird" then
		local beak = Color3.fromRGB(245, 165, 50)
		piece("Beak", Vector3.new(0.2, 0.08, 0.24) * s, CFrame.new(front + Vector3.new(0, -0.04 * s, -0.08 * s)), beak, { Material = Enum.Material.SmoothPlastic })
		piece("BeakLow", Vector3.new(0.16, 0.06, 0.18) * s, CFrame.new(front + Vector3.new(0, -0.1 * s, -0.05 * s)) * CFrame.Angles(math.rad(-12), 0, 0), beak:Lerp(INK, 0.2), { Material = Enum.Material.SmoothPlastic })
	else
		local mouthW = if frog then hr * 1.3 else hr * 0.8
		local mouthPos
		if frog then
			mouthPos = hp + Vector3.new(0, -hr * 0.1, -hr * 0.96)
		elseif kind == "Dragon" then
			mouthPos = hp + Vector3.new(0, -0.17 * s, -0.36 * s)
		elseif kind == "Lizard" then
			mouthPos = Vector3.new(0, 0.04 * s, -0.78 * s)
		elseif head.Block then
			mouthPos = hp + Vector3.new(0, -hr * 0.4, -hr - 0.01 * s)
		else
			mouthPos = hp + Vector3.new(0, -hr * 0.38, -hr * 0.9)
		end
		piece("Mouth", Vector3.new(mouthW, hr * 0.16, hr * 0.14), CFrame.new(mouthPos), INK, { Material = Enum.Material.SmoothPlastic })
		for _, side in { -1, 1 } do
			spike("Fang", hr * 0.16, mouthPos + Vector3.new(side * mouthW * 0.28, -hr * 0.08, 0), WHITE)
		end
		if extras.Snout then
			piece("Snout", Vector3.new(0.28, 0.18, 0.12) * s, CFrame.new(front + Vector3.new(0, -0.02 * s, -0.04 * s)), dark)
			for _, side in { -1, 1 } do
				ball("Nostril", 0.05 * s, front + Vector3.new(side * 0.06 * s, 0, -0.1 * s), INK)
			end
		end
	end

	---------------------------------------------------------------- Krallen, Schwanz, Stacheln

	for _, foot in legs do
		for i = -1, 1, 2 do
			spike("Claw", 0.07 * s, foot + Vector3.new(i * 0.05 * s, 0.03 * s, -0.02 * s), accent, nil, { Material = accentMaterial })
		end
	end

	if tailStart or extras.Tail then
		local start = tailStart or Vector3.new(0, 0, bodyRadius * 1.1)
		for i = 1, 3 do
			ball("Tail", (0.26 - i * 0.05) * s, start + Vector3.new(0, i * 0.08 * s, i * 0.12 * s), dark)
		end
		if kind == "Dragon" or kind == "Lizard" or tier >= 5 then
			spike("TailTip", 0.2 * s, start + Vector3.new(0, 0.34 * s, 0.46 * s), accent, "X", { Material = accentMaterial })
		end
	end

	-- Ruecken-Stacheln (Drache, Echse, Kaktus) - halb im Koerper versenkt
	if extras.Spikes or kind == "Dragon" or kind == "Lizard" then
		local count = if kind == "Lizard" then 4 else 3
		for i = 1, count do
			local z = (-0.2 + (i - 1) * 0.22) * s
			local y = bodyY + bodyRadius * 0.95 - math.abs(z) * 0.2
			spike("Spike", (0.18 - i * 0.015) * s, Vector3.new(0, y, z), accent, "X", { Material = accentMaterial })
		end
	end

	---------------------------------------------------------------- Merkmale

	local top = hp + Vector3.new(0, hr, 0)
	for _, side in { -1, 1 } do
		if extras.CatEars or extras.Ears then
			spike("Ear", 0.2 * s, top + Vector3.new(side * hr * 0.6, -0.02 * s, 0.02 * s), dark)
			spike("EarInner", 0.12 * s, top + Vector3.new(side * hr * 0.6, -0.02 * s, -0.04 * s), belly)
		end
		if extras.BigEars then
			piece("Ear", Vector3.new(0.36, 0.14, 0.05) * s, CFrame.new(hp + Vector3.new(side * hr * 1.15, hr * 0.25, 0)) * CFrame.Angles(0, 0, math.rad(side * 25)), dark)
		end
		if extras.Horns or kind == "Dragon" then
			-- Gebogenes Horn aus zwei Teilen
			local base = top + Vector3.new(side * hr * 0.5, -0.02 * s, 0.04 * s)
			piece("Horn", Vector3.new(0.1, 0.2, 0.1) * s, CFrame.new(base) * CFrame.Angles(math.rad(-15), 0, math.rad(side * -25)), accent, { Material = accentMaterial })
			piece("HornTip", Vector3.new(0.07, 0.16, 0.07) * s, CFrame.new(base + Vector3.new(side * 0.06 * s, 0.15 * s, 0.05 * s)) * CFrame.Angles(math.rad(-35), 0, math.rad(side * -45)), accent, { Material = accentMaterial })
		elseif tier == 3 and not extras.CatEars and not extras.Ears and not extras.Helmet and not extras.PirateHat then
			-- Rare: kleine Hoerner-Stummel
			spike("Nub", 0.1 * s, top + Vector3.new(side * hr * 0.45, -0.01 * s, 0), BONE)
		end
	end
	if extras.Shell then
		piece("Shell", Vector3.new(0.86, 0.36, 1.0) * s, CFrame.new(0, bodyRadius * 0.7, 0.05 * s), Color3.fromRGB(60, 110, 60), { Material = Enum.Material.Slate })
		for i = -1, 1 do
			spike("ShellSpike", 0.16 * s, Vector3.new(0, bodyRadius * 0.7 + 0.18 * s, i * 0.28 * s), accent, "X", { Material = accentMaterial })
		end
	end
	if extras.Comb then
		for i = -1, 1 do
			ball("Comb", 0.12 * s, top + Vector3.new(0, 0.04 * s, i * 0.07 * s), Color3.fromRGB(225, 50, 50), { Material = Enum.Material.SmoothPlastic })
		end
	end
	if extras.Helmet then
		piece("Helmet", Vector3.new(hr * 2.1, hr * 0.9, hr * 2.1), CFrame.new(hp + Vector3.new(0, hr * 0.55, 0)), Color3.fromRGB(170, 175, 185), { Material = Enum.Material.Metal })
		piece("Plume", Vector3.new(0.06, 0.2, 0.36) * s, CFrame.new(hp + Vector3.new(0, hr * 1.1, 0.02 * s)), Color3.fromRGB(210, 50, 60), { Material = Enum.Material.Fabric })
	end
	if extras.Headband then
		piece("Headband", Vector3.new(hr * 2.05, 0.08 * s, hr * 2.05), CFrame.new(hp + Vector3.new(0, hr * 0.5, 0)), Color3.fromRGB(200, 40, 50), { Material = Enum.Material.Fabric })
		piece("BandTail", Vector3.new(0.05, 0.06, 0.3) * s, CFrame.new(hp + Vector3.new(0.06 * s, hr * 0.45, hr + 0.1 * s)) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(200, 40, 50), { Material = Enum.Material.Fabric })
	end
	if extras.PirateHat then
		piece("Hat", Vector3.new(hr * 2.3, 0.1 * s, hr * 1.4), CFrame.new(top + Vector3.new(0, 0.01 * s, 0)), INK, { Material = Enum.Material.Fabric })
		piece("HatTop", Vector3.new(hr * 1.4, 0.2 * s, hr * 1.2), CFrame.new(top + Vector3.new(0, 0.14 * s, 0)), INK, { Material = Enum.Material.Fabric })
		ball("Skull", 0.08 * s, top + Vector3.new(0, 0.14 * s, -hr * 0.62), WHITE, { Material = Enum.Material.SmoothPlastic })
	end
	if extras.EyePatch then
		local patchPos = if head.Block then hp + Vector3.new(hr * 0.42, hr * 0.15, -hr - eyeD * 0.35) else hp + Vector3.new(hr * 0.4, hr * 0.2, -hr * 0.8 - eyeD * 0.45)
		piece("EyePatch", Vector3.new(eyeD * 1.1, eyeD * 1.1, 0.04 * s), CFrame.new(patchPos), INK, { Material = Enum.Material.Fabric })
	end
	if extras.Cherry then
		ball("Cherry", 0.2 * s, top + Vector3.new(0, 0.08 * s, 0), Color3.fromRGB(210, 40, 60), { Material = Enum.Material.SmoothPlastic })
	end
	if extras.DiscoBall then
		ball("DiscoBall", 0.2 * s, top + Vector3.new(0, 0.16 * s, 0), Color3.fromRGB(220, 220, 230), { Material = Enum.Material.Foil })
	end
	if extras.Cone then
		-- Waffel-Eistuete aus immer schmaleren Scheiben
		for i = 0, 3 do
			local width = (0.6 - i * 0.13) * s
			piece("Cone", Vector3.new(0.14 * s, width, width), CFrame.new(0, -0.42 * s - i * 0.12 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(215, 160, 90), { Shape = Enum.PartType.Cylinder, Material = Enum.Material.SmoothPlastic })
		end
	elseif kind == "Blob" then
		for _, side in { -1, 1 } do
			ball("Drop", 0.22 * s, Vector3.new(side * 0.32 * s, -0.4 * s, -0.1 * s), belly, { Transparency = 0.2 })
		end
	end

	---------------------------------------------------------------- Seltenheit: Leuchten, Krone, Heiligenschein

	if tier >= 4 then
		-- Leuchtende Flecken auf dem Ruecken
		for i, offset in { Vector3.new(-0.5, 0.75, 0.2), Vector3.new(0.45, 0.7, 0.35), Vector3.new(0.05, 0.9, 0.5) } do
			if not extras.Shell and (i <= 2 or tier >= 5) then
				ball("Spot", 0.13 * s, Vector3.new(offset.X * bodyRadius, bodyY + offset.Y * bodyRadius, offset.Z * bodyRadius), glow, { Material = Enum.Material.Neon })
			end
		end
	end
	if rarity.Crown then
		local crownY = top.Y + (if extras.Helmet or extras.PirateHat then 0.3 * s else 0.06 * s)
		piece("Crown", Vector3.new(0.32, 0.1, 0.32) * s, CFrame.new(hp.X, crownY, hp.Z), Color3.fromRGB(245, 200, 60), { Material = Enum.Material.Foil })
		for i = -1, 1 do
			spike("CrownTip", 0.1 * s, Vector3.new(hp.X + i * 0.1 * s, crownY + 0.08 * s, hp.Z - 0.12 * s), Color3.fromRGB(245, 200, 60), nil, { Material = Enum.Material.Foil })
		end
		ball("CrownGem", 0.07 * s, Vector3.new(hp.X, crownY + 0.02 * s, hp.Z - 0.17 * s), glow, { Material = Enum.Material.Neon })
	end
	if tier >= 6 then
		-- Mythic/Secret: leuchtender Ring ueber dem Kopf
		local haloCenter = top + Vector3.new(0, 0.42 * s, 0)
		for i = 0, 9 do
			local angle = i / 10 * math.pi * 2
			ball("Halo", 0.08 * s, haloCenter + Vector3.new(math.cos(angle) * 0.24 * s, 0, math.sin(angle) * 0.24 * s), glow, { Material = Enum.Material.Neon })
		end
	end
	if rarity.Glow then
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = s * 3
		light.Brightness = 0.9
		light.Parent = body
	end
	-- Ab Legendary oder starker Mutation: Glitzern in der Farbe der Seltenheit
	if rarity.Crown or (mutation and mutation.Multiplier >= 4) then
		local aura = Instance.new("ParticleEmitter")
		aura.Name = "Aura"
		aura.Color = ColorSequence.new(glow)
		aura.LightEmission = 0.6
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.1), NumberSequenceKeypoint.new(1, 0) })
		aura.Transparency = NumberSequence.new(0.3, 1)
		aura.Lifetime = NumberRange.new(0.8, 1.2)
		aura.Rate = if tier >= 6 then 8 else 4
		aura.Speed = NumberRange.new(s * 0.2, s * 0.4)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Parent = body
	end
	if tier >= 7 then
		-- Secret: dunkler Rauch
		local smoke = Instance.new("ParticleEmitter")
		smoke.Name = "VoidSmoke"
		smoke.Color = ColorSequence.new(Color3.fromRGB(40, 20, 70))
		smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.3), NumberSequenceKeypoint.new(1, s * 0.6) })
		smoke.Transparency = NumberSequence.new(0.5, 1)
		smoke.Lifetime = NumberRange.new(1, 1.6)
		smoke.Rate = 5
		smoke.Speed = NumberRange.new(0.5, 1)
		smoke.Parent = body
	end
	if mutation and mutation.Name == "Rainbow" then
		CollectionService:AddTag(body, "RainbowCritter") -- Client laesst die Farbe durchlaufen
		local headPart = model:FindFirstChild("Head")
		if headPart then
			CollectionService:AddTag(headPart, "RainbowCritter")
		end
	end
	if info.Fusion > 0 then
		local fire = Instance.new("Fire")
		fire.Size = s * 0.4
		fire.Heat = 0
		fire.Color = Color3.fromRGB(150, 100, 220)
		fire.SecondaryColor = Color3.fromRGB(120, 180, 230)
		fire.Parent = body
		-- Sterne fuer die Fusionsstufe
		for i = 1, info.Fusion do
			spike("FusionStar", 0.12 * s, Vector3.new((i - (info.Fusion + 1) / 2) * 0.16 * s, top.Y + (if tier >= 6 then 0.62 else 0.36) * s, hp.Z), Color3.fromRGB(255, 220, 60), nil, { Material = Enum.Material.Neon })
		end
	end

	return model
end

-- Namensschild ueber der Kreatur: zwei kurze Zeilen, Groesse in Studs (wird mit der Entfernung kleiner,
-- statt als feste Pixel-Flaeche alles zu verdecken). Gibt das Label der zweiten Zeile zurueck (Preis oder Einkommen).
-- Der Client kann die Schilder in den Einstellungen ausblenden (Attribut OwnerUserId am Model).
function UnitFactory.AddLabel(model: Model, info, infoText: string): TextLabel
	local def = info.Def
	local rarity = Config.RaritiesByName[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Info"
	gui.Size = UDim2.new(3.2 + info.Scale * 0.5, 0, 1.1 + info.Scale * 0.12, 0)
	gui.StudsOffset = Vector3.new(0, info.Scale * 0.62 + 1.1, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.Parent = model.PrimaryPart

	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = gui

	local function line(text: string, color: Color3, height: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.2
		label.Parent = gui
		return label
	end

	-- Name in der Farbe der Seltenheit (Mutation hat Vorrang), darunter Preis/Einkommen
	line(info.Name, if info.Mutation then info.Mutation.Color else rarity.Color, 0.55)
	return line(infoText, Color3.fromRGB(140, 255, 140), 0.45)
end

-- Unsichtbarer Punkt vorne an den Fuessen: Prompts erscheinen dort statt mitten auf der Kreatur
function UnitFactory.PromptAnchor(model: Model, info): Attachment
	local body = model.PrimaryPart :: BasePart
	local anchor = body:FindFirstChild("PromptAnchor") :: Attachment?
	if anchor then
		return anchor
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "PromptAnchor"
	attachment.Position = Vector3.new(0, -info.Scale * 0.55, -info.Scale * 0.45)
	attachment.Parent = body
	return attachment
end

-- transparency 0 stellt den Originalzustand wieder her (Geister, Glas-Blobs und Fluegel sind von Haus aus
-- leicht durchsichtig; frueher wurden sie nach einem gescheiterten Diebstahl voll undurchsichtig)
function UnitFactory.SetTransparency(model: Model, transparency: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local base = part:GetAttribute("BaseTransparency")
			if base == nil then
				base = part.Transparency
				part:SetAttribute("BaseTransparency", base)
			end
			part.Transparency = math.max(base, transparency)
		end
	end
end

return UnitFactory
