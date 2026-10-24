-- Baut die ganze Welt per Code: Kolosseum, Spawn-Platz, Heilquelle, Wildnis-Zonen, Licht.
-- Stil: antike Arena aus hellem Sandstein bei Sonnenuntergang, Purpur und Gold als Akzente.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = { Services = nil :: any }

local STONE = Color3.fromRGB(226, 204, 166)
local STONE_DARK = Color3.fromRGB(190, 162, 122)
local CRIMSON = Color3.fromRGB(150, 28, 40)
local GOLD = Color3.fromRGB(230, 180, 70)
local CREAM = Color3.fromRGB(250, 238, 215)

local random = Random.new(7)
local world: Folder
local arenaSlots = {}

WorldService.SpringPosition = nil :: Vector3?
WorldService.Boards = {} :: { [string]: BasePart }

function WorldService:Init(services)
	self.Services = services
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or world
	return p
end

-- Flache Scheibe (Zylinder liegt entlang X, darum drehen)
local function disc(position: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material, parent: Instance?): Part
	return part({
		Name = "Disc",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
		Parent = parent,
	})
end

local function surfaceText(target: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = target
	return label
end

local function torch(position: Vector3, parent: Instance?)
	part({ Name = "TorchPole", Size = Vector3.new(0.6, 6, 0.6), CFrame = CFrame.new(position + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(80, 55, 35), Material = Enum.Material.Wood, Parent = parent })
	local bowl = part({ Name = "TorchBowl", Size = Vector3.new(1.6, 0.8, 1.6), CFrame = CFrame.new(position + Vector3.new(0, 6.3, 0)), Color = GOLD, Material = Enum.Material.Metal, Parent = parent })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 160, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 22
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = bowl
end

local function prompt(parent: BasePart, action: string, object: string, name: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = parent
	CollectionService:AddTag(p, "WorldPrompt") -- Client oeffnet das passende Fenster
	return p
end

---------------------------------------------------------------- Licht

local function buildLighting()
	Lighting.ClockTime = 17.3
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(90, 70, 70)
	Lighting.OutdoorAmbient = Color3.fromRGB(160, 130, 120)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(255, 200, 160)
	atmosphere.Decay = Color3.fromRGB(150, 90, 110)
	atmosphere.Glare = 0.35
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 26
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Brightness = 0.02
	color.Contrast = 0.1
	color.Saturation = 0.08
	color.TintColor = Color3.fromRGB(255, 244, 232)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.05
	rays.Spread = 0.6
	rays.Parent = Lighting
end

---------------------------------------------------------------- Kolosseum

local function ringSegments(count: number, skip: (number) -> boolean, build: (CFrame, number, number) -> ())
	for i = 0, count - 1 do
		if not skip(i) then
			local angle = (i + 0.5) / count * math.pi * 2
			build(CFrame.Angles(0, -angle, 0), angle, i)
		end
	end
end

local function buildColosseum()
	local folder = Instance.new("Folder")
	folder.Name = "Colosseum"
	folder.Parent = world
	local R = Config.ColosseumRadius
	local N = 40
	-- Eingang zeigt nach Sueden (+Z) zum Spawn-Platz
	local function isEntrance(i: number): boolean
		local angle = (i + 0.5) / N * math.pi * 2
		return math.abs(angle - math.pi / 2) < 0.2
	end
	local segmentWidth = 2 * math.pi * R / N + 0.4

	-- Sandboden und Emblem
	disc(Vector3.new(0, -0.15, 0), (R - 8) * 2, 0.6, Color3.fromRGB(222, 190, 135), Enum.Material.Sand, folder)
	disc(Vector3.new(0, 0.18, 0), 34, 0.1, GOLD, Enum.Material.Neon, folder).Transparency = 0.35
	disc(Vector3.new(0, 0.2, 0), 31, 0.12, Color3.fromRGB(205, 170, 115), Enum.Material.Sand, folder)
	disc(Vector3.new(0, 0.22, 0), 14, 0.12, CRIMSON, Enum.Material.Fabric, folder)

	-- Aussenmauer: zwei Bogen-Reihen und ein Attika-Abschluss
	ringSegments(N, isEntrance, function(rotation, angle)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = CFrame.new(outward * R) * rotation
		for tier = 0, 1 do
			local y = tier * 12
			part({ Name = "Pillar", Size = Vector3.new(2.6, 10, 2.6), CFrame = base * CFrame.new(0, y + 5, -segmentWidth / 2 + 1.3), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
			part({ Name = "Lintel", Size = Vector3.new(3, 2, segmentWidth), CFrame = base * CFrame.new(0, y + 11, 0), Color = STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
		end
		part({ Name = "Attic", Size = Vector3.new(3, 6, segmentWidth), CFrame = base * CFrame.new(0, 27, 0), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
		part({ Name = "Cornice", Size = Vector3.new(3.8, 0.8, segmentWidth), CFrame = base * CFrame.new(0, 30.4, 0), Color = STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
	end)
	-- Ringstrasse um das Kolosseum (von hier fuehren die Wege in die Zonen)
	ringSegments(48, function()
		return false
	end, function(rotation, angle)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local width = 2 * math.pi * (R + 12) / 48 + 0.6
		part({ Name = "Road", Size = Vector3.new(12, 0.5, width), CFrame = CFrame.new(outward * (R + 12) + Vector3.new(0, -0.2, 0)) * rotation, Color = Color3.fromRGB(200, 185, 160), Material = Enum.Material.Cobblestone, Parent = folder })
	end)

	-- Banner an jeder fuenften Saeule, Fackeln innen
	ringSegments(N, isEntrance, function(rotation, angle, i)
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if i % 5 == 0 then
			local banner = part({ Name = "Banner", Size = Vector3.new(0.3, 9, 4.5), CFrame = CFrame.new(outward * (R + 1.8)) * rotation * CFrame.new(0, 19, 0), Color = CRIMSON, Material = Enum.Material.Fabric, Parent = folder })
			banner.CanCollide = false
			part({ Name = "BannerTrim", Size = Vector3.new(0.35, 0.6, 4.6), CFrame = banner.CFrame * CFrame.new(0, -4.5, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = folder }).CanCollide = false
			local emblem = part({ Name = "BannerEmblem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.4, 2.4), CFrame = banner.CFrame * CFrame.new(0, 1, 0), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
			emblem.CanCollide = false
		end
		if i % 4 == 2 then
			torch(outward * (R - 10.5), folder)
		end
	end)

	-- Zuschauerraenge (Stufen) innen
	for step = 0, 3 do
		local radius = R - 9 + step * 2
		ringSegments(N, isEntrance, function(rotation, angle)
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local width = 2 * math.pi * radius / N + 0.3
			part({ Name = "Seat", Size = Vector3.new(2, 1.5 + step * 1.5, width), CFrame = CFrame.new(outward * radius) * rotation * CFrame.new(0, (1.5 + step * 1.5) / 2, 0), Color = if step % 2 == 0 then STONE else STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
		end)
	end

	-- Torbogen am Eingang mit Schild
	local gateZ = R
	for _, x in { -9, 9 } do
		part({ Name = "GatePillar", Size = Vector3.new(4, 24, 4), CFrame = CFrame.new(x, 12, gateZ), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
	end
	local sign = part({ Name = "GateSign", Size = Vector3.new(22, 5, 2), CFrame = CFrame.new(0, 26, gateZ), Color = CRIMSON, Material = Enum.Material.Fabric, Parent = folder })
	surfaceText(sign, Enum.NormalId.Back, "THE COLOSSEUM", GOLD)
	surfaceText(sign, Enum.NormalId.Front, "THE COLOSSEUM", GOLD)
	part({ Name = "GateTrim", Size = Vector3.new(22.4, 0.6, 2.2), CFrame = CFrame.new(0, 23.5, gateZ), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
	part({ Name = "GateTrim", Size = Vector3.new(22.4, 0.6, 2.2), CFrame = CFrame.new(0, 28.5, gateZ), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })

	-- Arena-Meister in der Mitte (Gladiator aus Parts) auf einem Podest
	local podium = disc(Vector3.new(0, 1, 0), 10, 2, STONE, Enum.Material.Limestone, folder)
	disc(Vector3.new(0, 2.05, 0), 10.4, 0.2, GOLD, Enum.Material.Metal, folder)
	local npc = Instance.new("Model")
	npc.Name = "ArenaMaster"
	local function npcPart(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
		return part({ Name = name, Size = size, CFrame = CFrame.new(Vector3.new(0, 2.1, 0) + offset) * CFrame.Angles(0, math.pi, 0), Color = color, Material = material or Enum.Material.SmoothPlastic, Parent = npc })
	end
	local skin = Color3.fromRGB(214, 160, 120)
	npcPart("LegL", Vector3.new(0.9, 2.2, 0.9), Vector3.new(-0.55, 1.1, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Leather)
	npcPart("LegR", Vector3.new(0.9, 2.2, 0.9), Vector3.new(0.55, 1.1, 0), Color3.fromRGB(120, 80, 50), Enum.Material.Leather)
	npcPart("Skirt", Vector3.new(2.3, 0.9, 1.3), Vector3.new(0, 2.3, 0), CRIMSON, Enum.Material.Fabric)
	npcPart("Torso", Vector3.new(2.2, 2.2, 1.1), Vector3.new(0, 3.7, 0), GOLD, Enum.Material.Metal)
	npcPart("ArmL", Vector3.new(0.8, 2.1, 0.8), Vector3.new(-1.55, 3.6, 0), skin)
	npcPart("ArmR", Vector3.new(0.8, 2.1, 0.8), Vector3.new(1.55, 3.6, 0), skin)
	npcPart("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 5.5, 0), skin)
	npcPart("Helmet", Vector3.new(1.45, 0.9, 1.45), Vector3.new(0, 6, 0), GOLD, Enum.Material.Metal)
	npcPart("Plume", Vector3.new(0.35, 1.1, 1.8), Vector3.new(0, 6.9, 0), CRIMSON, Enum.Material.Fabric)
	npcPart("Cape", Vector3.new(2.2, 3.4, 0.2), Vector3.new(0, 3.3, 0.65), CRIMSON, Enum.Material.Fabric)
	local spear = npcPart("Spear", Vector3.new(0.25, 7, 0.25), Vector3.new(2.1, 3.6, -0.3), Color3.fromRGB(110, 80, 50), Enum.Material.Wood)
	npcPart("SpearTip", Vector3.new(0.5, 1, 0.5), Vector3.new(2.1, 7.4, -0.3), GOLD, Enum.Material.Metal)
	npc.Parent = folder
	local head = npc:FindFirstChild("Head") :: BasePart
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(220, 60)
	tag.StudsOffset = Vector3.new(0, 3.2, 0)
	tag.LightInfluence = 0
	tag.MaxDistance = 120
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.Text = "ARENA MASTER"
	title.TextColor3 = GOLD
	title.TextStrokeTransparency = 0.2
	title.Parent = tag
	local sub = title:Clone()
	sub.Position = UDim2.fromScale(0, 0.6)
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Font = Enum.Font.BuilderSansBold
	sub.Text = "Champions & Gauntlet"
	sub.TextColor3 = CREAM
	sub.Parent = tag
	tag.Parent = head
	prompt(podium, "Enter Arena", "Arena Master", "Arena")
	spear.CanCollide = false

	-- Kampfplaetze: 6 Linien von aussen nach innen
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2 + math.pi / 6
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local playerPos = outward * 46
		local allyPos = outward * 40
		local enemyPos = outward * 20
		table.insert(arenaSlots, {
			Player = CFrame.lookAt(playerPos + Vector3.new(0, 3.5, 0), enemyPos + Vector3.new(0, 3.5, 0)),
			Ally = CFrame.lookAt(allyPos, enemyPos),
			Enemy = CFrame.lookAt(enemyPos, allyPos),
			Busy = false,
		})
		-- Markierung auf dem Sand
		disc(allyPos + Vector3.new(0, 0.2, 0), 7, 0.1, Color3.fromRGB(70, 120, 200), Enum.Material.Neon, folder).Transparency = 0.6
		disc(enemyPos + Vector3.new(0, 0.2, 0), 9, 0.1, CRIMSON, Enum.Material.Neon, folder).Transparency = 0.6
	end
end

function WorldService:ClaimArenaSlot(_player: Player)
	for _, slot in arenaSlots do
		if not slot.Busy then
			slot.Busy = true
			return slot
		end
	end
	return nil
end

function WorldService:ReleaseArenaSlot(slot)
	slot.Busy = false
end

---------------------------------------------------------------- Spawn-Platz

local function board(position: Vector3, title: string, key: string)
	local frame = part({ Name = "Board", Size = Vector3.new(14, 18, 1), CFrame = CFrame.lookAt(position + Vector3.new(0, 10, 0), Vector3.new(0, 10, 100)), Color = Color3.fromRGB(40, 30, 40), Material = Enum.Material.Wood })
	part({ Name = "BoardTop", Size = Vector3.new(15, 1.2, 1.4), CFrame = frame.CFrame * CFrame.new(0, 9.4, 0), Color = GOLD, Material = Enum.Material.Metal })
	frame:SetAttribute("Title", title)
	WorldService.Boards[key] = frame
end

local function buildPlaza()
	local folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = world
	local center = Vector3.new(0, 0, 128)
	disc(center + Vector3.new(0, -0.15, 0), 72, 0.6, Color3.fromRGB(200, 185, 160), Enum.Material.Cobblestone, folder)
	disc(center + Vector3.new(0, 0.18, 0), 20, 0.1, GOLD, Enum.Material.Metal, folder)
	-- Weg zum Kolosseum
	part({ Name = "Path", Size = Vector3.new(16, 0.6, 40), CFrame = CFrame.new(0, -0.15, 80), Color = Color3.fromRGB(200, 185, 160), Material = Enum.Material.Cobblestone, Parent = folder })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(center + Vector3.new(0, 0.6, 6))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	-- Heilquelle
	local springPos = center + Vector3.new(-20, 0, -6)
	WorldService.SpringPosition = springPos
	disc(springPos + Vector3.new(0, 1, 0), 16, 2, STONE, Enum.Material.Limestone, folder)
	local water = disc(springPos + Vector3.new(0, 2.05, 0), 13.5, 0.3, Color3.fromRGB(110, 230, 210), Enum.Material.Glass, folder)
	water.Transparency = 0.25
	local spout = part({ Name = "Spout", Size = Vector3.new(2, 6, 2), CFrame = CFrame.new(springPos + Vector3.new(0, 4, 0)), Color = STONE_DARK, Material = Enum.Material.Limestone, Parent = folder })
	local orb = part({ Name = "SpringOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.4, CFrame = CFrame.new(springPos + Vector3.new(0, 8, 0)), Color = Color3.fromRGB(120, 255, 200), Material = Enum.Material.Neon, Parent = folder })
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(Color3.fromRGB(150, 255, 220))
	sparkle.LightEmission = 0.8
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.Lifetime = NumberRange.new(1, 2)
	sparkle.Rate = 12
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = orb
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(120, 255, 200)
	glow.Range = 18
	glow.Parent = orb
	prompt(spout, "Heal Team", "Healing Spring", "Heal")

	-- Laden (Zelt mit Marktstand)
	local shopPos = center + Vector3.new(20, 0, -6)
	local counter = part({ Name = "Counter", Size = Vector3.new(12, 3.5, 4), CFrame = CFrame.new(shopPos + Vector3.new(0, 1.75, 0)), Color = Color3.fromRGB(140, 95, 60), Material = Enum.Material.Wood, Parent = folder })
	for _, x in { -5.5, 5.5 } do
		part({ Name = "Post", Size = Vector3.new(0.8, 10, 0.8), CFrame = CFrame.new(shopPos + Vector3.new(x, 5, 1.5)), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood, Parent = folder })
	end
	for i = 0, 5 do
		part({ Name = "Awning", Size = Vector3.new(2, 0.4, 6), CFrame = CFrame.new(shopPos + Vector3.new(-5 + i * 2, 10, 0)) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then CRIMSON else CREAM, Material = Enum.Material.Fabric, Parent = folder })
	end
	for i, item in { Config.Items.Orb, Config.Items.GreatOrb, Config.Items.MasterOrb } do
		part({ Name = "DisplayOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = CFrame.new(shopPos + Vector3.new(-3 + (i - 1) * 3, 4.2, 0)), Color = item.Color, Material = Enum.Material.Glass, Parent = folder })
	end
	local shopSign = part({ Name = "ShopSign", Size = Vector3.new(10, 2.5, 0.5), CFrame = CFrame.new(shopPos + Vector3.new(0, 11.8, -2.6)), Color = Color3.fromRGB(50, 35, 45), Material = Enum.Material.Wood, Parent = folder })
	surfaceText(shopSign, Enum.NormalId.Back, "ORB SHOP", GOLD)
	surfaceText(shopSign, Enum.NormalId.Front, "ORB SHOP", GOLD)
	prompt(counter, "Shop", "Orbs & Potions", "Shop")

	-- Tagesbelohnung (Truhe)
	local chestPos = center + Vector3.new(0, 0, 20)
	local chest = part({ Name = "DailyChest", Size = Vector3.new(5, 3, 3.5), CFrame = CFrame.new(chestPos + Vector3.new(0, 1.5, 0)), Color = Color3.fromRGB(150, 90, 50), Material = Enum.Material.Wood, Parent = folder })
	part({ Name = "ChestLid", Size = Vector3.new(5.2, 1.2, 3.7), CFrame = CFrame.new(chestPos + Vector3.new(0, 3.6, 0)), Color = GOLD, Material = Enum.Material.Metal, Parent = folder })
	prompt(chest, "Daily Reward", "Treasure Chest", "Daily")

	torch(center + Vector3.new(-12, 0, -30), folder)
	torch(center + Vector3.new(12, 0, -30), folder)
	torch(center + Vector3.new(-30, 0, 14), folder)
	torch(center + Vector3.new(30, 0, 14), folder)

	board(center + Vector3.new(-26, 0, 26), "GAUNTLET LEGENDS", "BestWave")
	board(center + Vector3.new(26, 0, 26), "DUEL CHAMPIONS", "Trophies")

	-- Werbeflaechen (Immersive Ads von Roblox, bringen Geld pro Ansicht)
	for _, x in { -12, 12 } do
		local panel = part({ Name = "AdPanel", Size = Vector3.new(16, 9, 0.5), CFrame = CFrame.lookAt(center + Vector3.new(x * 3.4, 7, 34), center + Vector3.new(x * 2, 7, 0)), Color = Color3.fromRGB(30, 25, 30), Material = Enum.Material.SmoothPlastic, Parent = folder })
		pcall(function()
			local ad = Instance.new("AdGui" :: any)
			ad.Face = Enum.NormalId.Front
			ad.Parent = panel
		end)
	end
end

---------------------------------------------------------------- Wildnis

local function tree(position: Vector3, parent: Instance)
	local height = random:NextNumber(8, 13)
	part({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, 1.8, 1.8), CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood, Parent = parent })
	for i = 1, 3 do
		local offset = Vector3.new(random:NextNumber(-2, 2), height + random:NextNumber(-1, 2), random:NextNumber(-2, 2))
		part({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * random:NextNumber(6, 9) / (if i == 3 then 1.3 else 1), CFrame = CFrame.new(position + offset), Color = Color3.fromRGB(80, 160, 70):Lerp(Color3.fromRGB(150, 200, 80), random:NextNumber()), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
end

local function palm(position: Vector3, parent: Instance)
	local lean = random:NextNumber(-0.25, 0.25)
	local top = position
	for i = 0, 5 do
		top = position + Vector3.new(lean * i * 2, i * 2 + 1, 0)
		part({ Name = "PalmTrunk", Size = Vector3.new(1.3, 2.1, 1.3), CFrame = CFrame.new(top) * CFrame.Angles(0, i * 0.4, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood, Parent = parent })
	end
	for i = 0, 5 do
		local angle = i / 6 * math.pi * 2
		part({ Name = "Frond", Size = Vector3.new(1.6, 0.25, 7), CFrame = CFrame.new(top + Vector3.new(0, 1, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.8, -3) * CFrame.Angles(math.rad(-20), 0, 0), Color = Color3.fromRGB(70, 160, 70), Material = Enum.Material.Grass, CanCollide = false, Parent = parent })
	end
end

local function rock(position: Vector3, color: Color3, parent: Instance, size: number?)
	local s = size or random:NextNumber(3, 7)
	part({ Name = "Rock", Size = Vector3.new(s, s * 0.7, s * 0.9), CFrame = CFrame.new(position + Vector3.new(0, s * 0.25, 0)) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6), random:NextNumber(-0.3, 0.3)), Color = color, Material = Enum.Material.Slate, Parent = parent })
end

local function crystal(position: Vector3, color: Color3, parent: Instance)
	local h = random:NextNumber(3, 8)
	local c = part({ Name = "Crystal", Size = Vector3.new(1.4, h, 1.4), CFrame = CFrame.new(position + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(random:NextNumber(-0.3, 0.3), random:NextNumber(0, 6), random:NextNumber(-0.3, 0.3)), Color = color, Material = Enum.Material.Neon, Parent = parent })
	c.Transparency = 0.15
end

local function brokenPillar(position: Vector3, parent: Instance)
	local h = random:NextNumber(4, 14)
	part({ Name = "Ruin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 3, 3), CFrame = CFrame.new(position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 110, 125), Material = Enum.Material.Limestone, Parent = parent })
end

local function decorate(zoneIndex: number, zone, parent: Instance, gateDir: Vector3)
	for _ = 1, 26 do
		local angle = random:NextNumber() * math.pi * 2
		local distance = random:NextNumber(14, zone.Radius - 8)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- Weg vom Tor zur Mitte frei lassen
		if dir:Dot(gateDir) < 0.85 then
			local position = zone.Center + dir * distance
			if zoneIndex == 1 then
				if random:NextNumber() < 0.6 then
					tree(position, parent)
				else
					part({ Name = "Flower", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0)), Color = ({ Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(180, 140, 255) })[random:NextInteger(1, 3)], Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = parent })
				end
			elseif zoneIndex == 2 then
				if random:NextNumber() < 0.6 then
					rock(position, Color3.fromRGB(70, 50, 45), parent)
				else
					local pool = disc(position + Vector3.new(0, 0.25, 0), random:NextNumber(5, 10), 0.3, Color3.fromRGB(255, 100, 30), Enum.Material.Neon, parent)
					pool.CanCollide = false
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 120, 40)
					light.Range = 14
					light.Parent = pool
				end
			elseif zoneIndex == 3 then
				if random:NextNumber() < 0.55 then
					palm(position, parent)
				else
					local pool = disc(position + Vector3.new(0, 0.22, 0), random:NextNumber(6, 12), 0.25, Color3.fromRGB(70, 170, 230), Enum.Material.Glass, parent)
					pool.Transparency = 0.2
					pool.CanCollide = false
				end
			else
				if random:NextNumber() < 0.5 then
					brokenPillar(position, parent)
				else
					crystal(position, Color3.fromRGB(170, 90, 255), parent)
				end
			end
		end
	end
	if zoneIndex == 2 then
		-- Vulkankegel in der Mitte
		for i = 0, 3 do
			local d = 26 - i * 6
			disc(zone.Center + Vector3.new(0, 1 + i * 2, 0), d, 2, Color3.fromRGB(80, 55, 50), Enum.Material.Basalt, parent)
		end
		local lava = disc(zone.Center + Vector3.new(0, 8.1, 0), 7, 0.4, Color3.fromRGB(255, 90, 20), Enum.Material.Neon, parent)
		local fire = Instance.new("Fire")
		fire.Size = 10
		fire.Heat = 15
		fire.Parent = lava
	end
end

local function buildZone(index: number, zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.Name
	folder.Parent = world
	local ground = disc(zone.Center + Vector3.new(0, -0.2, 0), zone.Radius * 2, 0.6, zone.Ground, zone.Material, folder)
	ground.Name = "ZoneGround"

	-- Tor zeigt zur Weltmitte (Richtung Kolosseum)
	local toCenter = Vector3.new(-zone.Center.X, 0, -zone.Center.Z).Unit
	local gateAngle = math.atan2(toCenter.Z, toCenter.X)
	local N = 36
	local wallColor = if index == 1 then Color3.fromRGB(150, 110, 70) else zone.Ground:Lerp(Color3.fromRGB(200, 190, 170), 0.35)
	for i = 0, N - 1 do
		local angle = (i + 0.5) / N * math.pi * 2
		local diff = math.abs((angle - gateAngle + math.pi) % (math.pi * 2) - math.pi)
		if diff > 0.2 then
			local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local width = 2 * math.pi * zone.Radius / N + 0.6
			local wall = part({ Name = "Wall", Size = Vector3.new(3, 14, width), CFrame = CFrame.new(zone.Center + outward * zone.Radius) * CFrame.Angles(0, -angle, 0) * CFrame.new(0, 7, 0), Color = wallColor, Material = if index == 1 then Enum.Material.WoodPlanks else Enum.Material.Limestone, Parent = folder })
			if i % 3 == 0 then
				part({ Name = "WallCap", Size = Vector3.new(3.6, 1.2, 3.6), CFrame = wall.CFrame * CFrame.new(0, 7.4, -width / 2), Color = zone.Accent, Material = Enum.Material.Neon, Parent = folder }).Transparency = 0.2
			end
		end
	end

	-- Torbogen mit Schild
	local gatePos = zone.Center + toCenter * zone.Radius
	local side = Vector3.new(-toCenter.Z, 0, toCenter.X)
	local gateCF = CFrame.lookAt(gatePos, gatePos + toCenter)
	for _, s in { -1, 1 } do
		part({ Name = "GatePillar", Size = Vector3.new(4, 20, 4), CFrame = CFrame.new(gatePos + side * s * 9 + Vector3.new(0, 10, 0)), Color = STONE, Material = Enum.Material.Limestone, Parent = folder })
		torch(gatePos + side * s * 9 + toCenter * 3, folder)
	end
	local sign = part({ Name = "GateSign", Size = Vector3.new(22, 5, 1.5), CFrame = gateCF + Vector3.new(0, 20, 0), Color = Color3.fromRGB(45, 30, 40), Material = Enum.Material.Wood, Parent = folder })
	local text = if zone.Crests > 0 then `{zone.Name:upper()}\nLv {zone.Levels[1]}-{zone.Levels[2]} · {zone.Crests} CRESTS` else `{zone.Name:upper()}\nLv {zone.Levels[1]}-{zone.Levels[2]}`
	surfaceText(sign, Enum.NormalId.Front, text, zone.Accent)
	surfaceText(sign, Enum.NormalId.Back, text, zone.Accent)
	if zone.Crests > 0 then
		local barrier = part({ Name = "ZoneGate", Size = Vector3.new(15, 18, 1), CFrame = gateCF + Vector3.new(0, 9, 0), Color = zone.Accent, Material = Enum.Material.ForceField, Transparency = 0.1, Parent = folder })
		barrier:SetAttribute("Crests", zone.Crests)
		CollectionService:AddTag(barrier, "ZoneGate") -- Client macht es durchlaessig, sobald genug Wappen da sind
	end

	-- Weg von der Ringstrasse zum Tor
	local from = -toCenter * (Config.ColosseumRadius + 12)
	local outside = gatePos + toCenter * 6
	local delta = outside - from
	part({ Name = "Path", Size = Vector3.new(12, 0.5, delta.Magnitude), CFrame = CFrame.lookAt(from + delta / 2 + Vector3.new(0, 0.05, 0), outside + Vector3.new(0, 0.05, 0)), Color = Color3.fromRGB(200, 185, 160), Material = Enum.Material.Cobblestone, Parent = folder })

	decorate(index, zone, folder, toCenter)
end

---------------------------------------------------------------- Aufbau

function WorldService:Build()
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	buildLighting()
	workspace.Terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(2400, 8, 2400), Enum.Material.Water)
	workspace.Terrain.WaterColor = Color3.fromRGB(60, 140, 170)
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterWaveSize = 0.15
	local ground = part({ Name = "Ground", Size = Vector3.new(1000, 6, 1000), CFrame = CFrame.new(0, -3, -20), Color = Color3.fromRGB(150, 175, 95), Material = Enum.Material.Grass })
	ground.CastShadow = false
	-- Sandstrand-Rand
	part({ Name = "Beach", Size = Vector3.new(1040, 5, 1040), CFrame = CFrame.new(0, -3.4, -20), Color = Color3.fromRGB(230, 210, 160), Material = Enum.Material.Sand })

	buildColosseum()
	buildPlaza()
	for index, zone in Config.Zones do
		buildZone(index, zone)
	end
end

return WorldService
