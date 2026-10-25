-- Eigene Kampf-Szene wie im Klassiker: Jeder Kampf bekommt weit weg von der Welt einen eigenen Platz mit
-- zwei runden Podesten, Hintergrund passend zum Gebiet (Wiese, Arena, Liga, Schrein) und den Trainern hinter ihren Bestien.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Story = require(ReplicatedStorage.Shared.Story)

local BattleStage = {}

local ORIGIN = Vector3.new(8000, 600, 8000)
local SPACING = 420
local PAD_DISTANCE = 17 -- Abstand der beiden Podeste

local used: { [number]: boolean } = {}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = false
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Flache Scheibe (Zylinder liegt auf der Seite)
local function disc(parent: Instance, center: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material?)
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function shade(color: Color3, amount: number): Color3
	return if amount >= 0 then color:Lerp(Color3.new(1, 1, 1), amount) else color:Lerp(Color3.new(0, 0, 0), -amount)
end

local function pad(parent: Instance, center: Vector3, top: Color3, rim: Color3)
	disc(parent, center - Vector3.new(0, 0.6, 0), 13.5, 1, rim, Enum.Material.SmoothPlastic)
	disc(parent, center - Vector3.new(0, 0.2, 0), 12, 0.6, top, Enum.Material.Grass)
	disc(parent, center + Vector3.new(0, 0.12, 0), 8, 0.1, shade(top, 0.15), Enum.Material.SmoothPlastic).Transparency = 0.4
end

local function tree(parent: Instance, base: Vector3, kind: string?, rng: Random)
	local height = rng:NextNumber(9, 16)
	local trunkColor = if kind == "Dead" then Color3.fromRGB(85, 65, 55) else Color3.fromRGB(110, 75, 45)
	part({ Size = Vector3.new(1.6, height, 1.6), CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)), Color = trunkColor, Material = Enum.Material.Wood, Parent = parent })
	if kind == "Dead" then
		return
	end
	local crown = if kind == "Snow" then Color3.fromRGB(235, 245, 250) elseif kind == "Pine" then Color3.fromRGB(45, 110, 60) else Color3.fromRGB(70, 150, 60)
	if kind == "Pine" or kind == "Snow" then
		for i = 0, 2 do
			local size = 9 - i * 2.5
			part({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.8, size), CFrame = CFrame.new(base + Vector3.new(0, height * 0.55 + i * 3, 0)), Color = shade(crown, i * 0.06), Material = Enum.Material.Grass, Parent = parent })
		end
	else
		local size = rng:NextNumber(9, 13)
		part({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.85, size), CFrame = CFrame.new(base + Vector3.new(0, height, 0)), Color = shade(crown, rng:NextNumber(-0.1, 0.1)), Material = Enum.Material.Grass, Parent = parent })
	end
end

-- Natur: Wiese mit Huegeln, Baeumen und Blumen im Stil des Gebiets
local function buildNature(parent: Instance, center: Vector3, theme, rng: Random)
	local ground = theme and theme.Ground or Color3.fromRGB(120, 185, 90)
	local material = theme and theme.Material or Enum.Material.Grass
	disc(parent, center - Vector3.new(0, 1.5, 0), 260, 2, ground, material)
	for i = 1, 26 do
		local angle = (i / 26) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local radius = rng:NextNumber(70, 95)
		local size = rng:NextNumber(30, 55)
		part({ Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.6, size), CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, -size * 0.12, math.sin(angle) * radius)), Color = shade(ground, rng:NextNumber(-0.18, 0.05)), Material = material, Parent = parent })
	end
	for i = 1, 22 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(38, 62)
		tree(parent, center + Vector3.new(math.cos(angle) * radius, -0.5, math.sin(angle) * radius), theme and theme.Trees, rng)
	end
	local accent = theme and theme.Accent or Color3.fromRGB(240, 120, 150)
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(14, 36)
		part({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, -0.2, math.sin(angle) * radius)), Color = if rng:NextNumber() < 0.5 then accent else Color3.fromRGB(255, 240, 150), CanCollide = false, Parent = parent })
	end
end

-- Arena / Liga / Kolosseum: Steinboden, Saeulen, Banner und Tribuene in der Farbe des Leiters
local function buildArena(parent: Instance, center: Vector3, color: Color3, style: string)
	local floor = if style == "League" then Color3.fromRGB(60, 50, 75) elseif style == "Shrine" then Color3.fromRGB(45, 35, 60) else Color3.fromRGB(175, 160, 140)
	disc(parent, center - Vector3.new(0, 1.5, 0), 200, 2, floor, Enum.Material.Slate)
	disc(parent, center - Vector3.new(0, 0.45, 0), 44, 0.3, shade(color, -0.25), Enum.Material.SmoothPlastic)
	disc(parent, center - Vector3.new(0, 0.4, 0), 40, 0.3, floor, Enum.Material.Slate)
	-- Mittellinie wie auf einem Kampffeld
	part({ Size = Vector3.new(40, 0.32, 0.8), CFrame = CFrame.new(center - Vector3.new(0, 0.3, 0)), Color = shade(color, -0.25), Parent = parent })
	local pillars = 16
	for i = 1, pillars do
		local angle = (i / pillars) * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle) * 46, 0, math.sin(angle) * 46)
		local height = if style == "Shrine" then 14 else 22
		part({ Size = Vector3.new(4, height, 4), CFrame = CFrame.new(pos + Vector3.new(0, height / 2 - 0.5, 0)), Color = if style == "League" then Color3.fromRGB(90, 80, 110) else Color3.fromRGB(225, 215, 195), Material = Enum.Material.Marble, Parent = parent })
		local bulb = part({ Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, height + 1, 0)), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
		if i % 4 == 0 then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Range = 40
			light.Brightness = 1.5
			light.Parent = bulb
		end
		if style ~= "Shrine" and i % 2 == 0 then
			local banner = part({ Size = Vector3.new(0.3, 9, 4), CFrame = CFrame.lookAt(pos + Vector3.new(0, height - 6, 0), center) * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = Enum.Material.Fabric, CanCollide = false, Parent = parent })
			banner.Name = "Banner"
		end
	end
	if style ~= "Shrine" then
		-- Tribuene rundherum
		for row = 1, 4 do
			local radius = 56 + row * 7
			for i = 1, 24 do
				local angle = (i / 24) * math.pi * 2
				local pos = center + Vector3.new(math.cos(angle) * radius, row * 3.5 - 1, math.sin(angle) * radius)
				part({ Size = Vector3.new(16, 3.5, 7), CFrame = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), Color = shade(floor, -0.08 * row), Material = Enum.Material.Concrete, Parent = parent })
			end
		end
	else
		-- Dunkle Kristalle fuer Legenden
		local rng = Random.new(7)
		for _ = 1, 18 do
			local angle = rng:NextNumber(0, math.pi * 2)
			local radius = rng:NextNumber(26, 60)
			local height = rng:NextNumber(6, 18)
			part({ Size = Vector3.new(3, height, 3), CFrame = CFrame.new(center + Vector3.new(math.cos(angle) * radius, height / 2 - 1, math.sin(angle) * radius)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), Color = color, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false, Parent = parent })
		end
	end
end

-- Spielerfigur als Statue hinter der eigenen Bestie (wie der Trainer im Klassiker)
local function trainerClone(player: Player, cf: CFrame, parent: Instance)
	local character = player.Character
	if not character then
		return
	end
	local ok, copy = pcall(function()
		local old = character.Archivable
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = old
		return clone
	end)
	if not ok or not copy then
		return
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
		elseif item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ProximityPrompt") or item:IsA("BillboardGui") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	copy.Name = "Trainer"
	pcall(function()
		local _, size = copy:GetBoundingBox()
		copy:PivotTo(cf * CFrame.new(0, size.Y / 2, 0))
	end)
	copy.Parent = parent
end

-- Baut die Szene und gibt die Podest-Positionen zurueck (eigene Seite, Gegner).
-- style: "Nature" | "Arena" | "League" | "Shrine" | "Colosseum"; theme: Story-Gebietsthema
function BattleStage.Build(parent: Instance, opts): (number, CFrame, CFrame, CFrame)
	local slot = 1
	while used[slot] do
		slot += 1
	end
	used[slot] = true
	local center = ORIGIN + Vector3.new((slot - 1) % 10 * SPACING, 0, (slot - 1) // 10 * SPACING)
	local stage = Instance.new("Folder")
	stage.Name = "Stage"
	stage.Parent = parent
	local rng = Random.new(slot * 31 + os.time() % 97)
	local style = opts.Style or "Nature"
	local theme = opts.Theme
	local color = opts.Color or Color3.fromRGB(240, 190, 60)
	if style == "Nature" then
		buildNature(stage, center, theme, rng)
	else
		buildArena(stage, center, color, style)
	end
	local allyPos = center + Vector3.new(0, 0, PAD_DISTANCE / 2)
	local enemyPos = center - Vector3.new(0, 0, PAD_DISTANCE / 2)
	local padTop = if style == "Nature" and theme then shade(theme.Ground, 0.12) else Color3.fromRGB(150, 200, 110)
	local rim = if style == "Nature" then Color3.fromRGB(205, 190, 150) else color
	pad(stage, allyPos, padTop, rim)
	pad(stage, enemyPos, padTop, rim)
	local ally = CFrame.lookAt(allyPos, enemyPos)
	local enemy = CFrame.lookAt(enemyPos, allyPos)
	return slot, ally, enemy, CFrame.new(center)
end

function BattleStage.Release(slot: number?)
	if slot then
		used[slot] = nil
	end
end

-- Trainer auf die Buehne stellen: Spieler als Figur, Computer-Trainer als NPC
function BattleStage.PlaceTrainers(battle, world)
	local folder = battle.Folder:FindFirstChild("Stage")
	if not folder then
		return
	end
	for index, side in battle.Sides do
		local other = battle.Sides[3 - index]
		local dir = (other.Anchor.Position - side.Anchor.Position) * Vector3.new(1, 0, 1)
		dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
		local right = dir:Cross(Vector3.yAxis).Unit
		local spot = side.Anchor.Position - dir * 6.5 - right * 4.5
		local cf = CFrame.lookAt(spot, spot + dir)
		if side.Player then
			trainerClone(side.Player, cf, folder)
		elseif side.Look and world then
			pcall(function()
				world:MakeNpc(side.Look, side.Name, side.Title, cf, folder)
			end)
		end
	end
end

-- Hintergrund passend zum Ort des Spielers
function BattleStage.ThemeAt(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local area = root and Story.AreaAt(root.Position)
	return area and area.Theme
end

return BattleStage
