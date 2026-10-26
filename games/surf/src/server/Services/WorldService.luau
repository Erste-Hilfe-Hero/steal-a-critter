-- Baut die ganze Map aus Code: Lobby (Skihuette), 10 Surf-Stages aus abfallenden Dach-Rampen,
-- verschneites Tal mit Bergen und Tageslicht, angelehnt an die klassische CS-Map surf_ski. Keine fremden Assets.
-- Zonen (Start, Ziel, Lobby-Portal) liegen unsichtbar in workspace.Zones; der Client prueft sie selbst,
-- weil er seine Bewegung selbst rechnet (SurfPhysics).
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundIds = require(ReplicatedStorage.Shared.Sounds)
local StageLayout = require(ReplicatedStorage.Shared.StageLayout)

local WorldService = { Services = nil :: any }

local THEME = Config.Theme
local map: Folder
local zones: Folder
local stageInfo = {} -- [Stage] = { Spawn = CFrame, Finish = BasePart, KillY = number }
local lobbySpawn: CFrame
local wedgeFacesNegZ = true
local WOOD = Color3.fromRGB(122, 84, 54)
local WOOD_DARK = Color3.fromRGB(86, 58, 38)
local TRIM = Color3.fromRGB(150, 170, 195) -- graublaue Rampenkante wie bei den alten Source-Maps

function WorldService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Bausteine

local function part(props): BasePart
	local className = props.ClassName or "Part"
	props.ClassName = nil
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function deco(props): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = if props.CastShadow == nil then false else props.CastShadow
	return part(props)
end

-- Welche Seite ist bei einem WedgePart die Schraege? Einmal mit einem Strahl nachmessen statt raten.
local function measureWedge()
	local probe = part({ ClassName = "WedgePart", Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(0, 5000, 0), Parent = workspace })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { probe }
	local hit = workspace:Raycast(Vector3.new(0, 5010, 0), Vector3.new(0, -20, 0), params)
	probe:Destroy()
	if hit then
		wedgeFacesNegZ = hit.Normal.Z < 0
	end
end

-- Keil, dessen Schraege zur Seite "side" (-1 = -Z, 1 = +Z im lokalen Rahmen) zeigt
local function wedgeRotation(side: number): CFrame
	local flip = (side > 0) == wedgeFacesNegZ
	return if flip then CFrame.Angles(0, math.pi, 0) else CFrame.identity
end

local function label(parent: BasePart, face: Enum.NormalId, text: string, color: Color3, props)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = (props and props.PixelsPerStud) or 20
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = parent
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextScaled = true
	textLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	textLabel.TextColor3 = color
	textLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Navy
	stroke.Thickness = 3
	stroke.Parent = textLabel
	return gui, textLabel
end

local function zone(kind: string, cframe: CFrame, size: Vector3, stage: number?): BasePart
	local z = part({
		Name = kind .. (stage or ""),
		CFrame = cframe,
		Size = size,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = zones,
	})
	z:SetAttribute("Kind", kind)
	if stage then
		z:SetAttribute("Stage", stage)
	end
	return z
end

-- Stilisierte Tanne aus gestapelten Zylindern (Low-Poly-Look)
local function tree(position: Vector3, scale: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Pine"
	deco({ Size = Vector3.new(2, 4, 2) * scale, CFrame = CFrame.new(position + Vector3.new(0, 2 * scale, 0)), Color = Color3.fromRGB(110, 70, 50), Material = Enum.Material.Wood, Parent = model })
	local tiers = { { 12, 4 }, { 9, 9 }, { 6, 13.5 }, { 3, 17 } }
	for i, tier in tiers do
		local diameter, height = tier[1] * scale, tier[2] * scale
		deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.2 * scale, diameter, diameter),
			CFrame = CFrame.new(position + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = if i % 2 == 0 then Color3.fromRGB(40, 110, 85) else Color3.fromRGB(30, 92, 74),
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
		-- Schnee auf jeder Stufe
		deco({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6 * scale, diameter * 0.8, diameter * 0.8),
			CFrame = CFrame.new(position + Vector3.new(0, height + 1.7 * scale, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			Color = THEME.Snow,
			Material = Enum.Material.Snow,
			Parent = model,
		})
	end
	model.Parent = parent
end

-- Berg als grosses Dach-Prisma mit Schneekappe
local function mountain(center: Vector3, length: number, width: number, height: number, parent: Instance)
	local cf = CFrame.new(center)
	for _, side in { -1, 1 } do
		deco({
			ClassName = "WedgePart",
			Size = Vector3.new(length, height, width / 2),
			CFrame = cf * CFrame.new(0, height / 2, side * width / 4) * wedgeRotation(side),
			Color = Color3.fromRGB(128, 132, 140),
			Material = Enum.Material.Rock,
			Parent = parent,
		})
		deco({
			ClassName = "WedgePart",
			Size = Vector3.new(length * 0.96, height * 0.35, width / 2 * 0.35),
			CFrame = cf * CFrame.new(0, height - height * 0.35 / 2 + 0.6, side * width / 2 * 0.35 / 2) * wedgeRotation(side),
			Color = THEME.Snow,
			Material = Enum.Material.Snow,
			Parent = parent,
		})
	end
end

---------------------------------------------------------------- Surf-Rampe

-- Dach-Rampe: Grat beginnt bei ridgeStart und faellt in +X mit "pitch" Grad ab. Beide Seiten sind surfbar.
-- Gibt das Grat-Ende zurueck.
local function ramp(ridgeStart: Vector3, length: number, width: number, height: number, pitch: number, color: Color3, accent: Color3, parent: Instance): Vector3
	local model = Instance.new("Model")
	model.Name = "Ramp"
	local cf = CFrame.new(ridgeStart) * CFrame.Angles(0, 0, -math.rad(pitch))
	local half = width / 2
	for _, side in { -1, 1 } do
		part({
			ClassName = "WedgePart",
			Name = "Face",
			Size = Vector3.new(length, height, half),
			CFrame = cf * CFrame.new(length / 2, -height / 2, side * half / 2) * wedgeRotation(side),
			Color = color,
			Material = Enum.Material.Snow,
			Parent = model,
		})
		-- Schmale Kante unten: zeigt, wo die Rampe endet
		deco({
			Size = Vector3.new(length, 0.6, 0.6),
			CFrame = cf * CFrame.new(length / 2, -height + 0.3, side * (half - 0.25)),
			Color = TRIM,
			Material = Enum.Material.Concrete,
			Parent = model,
		})
	end
	-- Grat leicht abgesetzt, damit man die Mitte erkennt
	deco({
		Size = Vector3.new(length, 0.35, 0.5),
		CFrame = cf * CFrame.new(length / 2, 0.05, 0),
		Color = TRIM,
		Material = Enum.Material.Concrete,
		Parent = model,
	})
	model.Parent = parent
	return (cf * CFrame.new(length, 0, 0)).Position
end

---------------------------------------------------------------- Stages

local function platform(center: Vector3, size: Vector3, color: Color3, parent: Instance): BasePart
	return part({
		Name = "Platform",
		Size = size,
		CFrame = CFrame.new(center - Vector3.new(0, size.Y / 2, 0)),
		Color = color,
		Material = Enum.Material.Snow,
		Parent = parent,
	})
end

local cabin
local function arch(center: Vector3, width: number, height: number, color: Color3, text: string, parent: Instance)
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(3, height, 3), CFrame = CFrame.new(center + Vector3.new(0, height / 2, side * width / 2)), Color = WOOD, Material = Enum.Material.Wood, Parent = parent })
	end
	local beam = deco({ Size = Vector3.new(3, 8, width + 3), CFrame = CFrame.new(center + Vector3.new(0, height + 4, 0)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = parent })
	label(beam, Enum.NormalId.Left, text, THEME.Snow)
	label(beam, Enum.NormalId.Right, text, THEME.Snow)
end

-- Kleine Skihuette als Kulisse am Ziel
cabin = function(base: Vector3, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "Cabin"
	deco({ Size = Vector3.new(24, 12, 18), CFrame = CFrame.new(base + Vector3.new(0, 6, 0)), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = model })
	for _, side in { -1, 1 } do
		deco({ Size = Vector3.new(27, 1, 12), CFrame = CFrame.new(base + Vector3.new(0, 15, side * 5)) * CFrame.Angles(side * math.rad(32), 0, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = model })
		deco({ Size = Vector3.new(27, 0.8, 12), CFrame = CFrame.new(base + Vector3.new(0, 15.8, side * 5)) * CFrame.Angles(side * math.rad(32), 0, 0), Color = THEME.Snow, Material = Enum.Material.Snow, Parent = model })
	end
	deco({ Size = Vector3.new(0.4, 6, 4), CFrame = CFrame.new(base + Vector3.new(-12.1, 3, 0)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = model })
	for _, z in { -5, 5 } do
		deco({ Size = Vector3.new(0.4, 3, 3), CFrame = CFrame.new(base + Vector3.new(-12.1, 7, z)), Color = Color3.fromRGB(255, 220, 140), Material = Enum.Material.Neon, Parent = model })
	end
	deco({ Size = Vector3.new(3, 8, 3), CFrame = CFrame.new(base + Vector3.new(6, 19, 4)), Color = Color3.fromRGB(120, 120, 125), Material = Enum.Material.Brick, Parent = model })
	model.Parent = parent
end

local function buildStage(index: number, def)
	local folder = Instance.new("Folder")
	folder.Name = "Stage" .. index
	local layout = StageLayout.Build(index, def, Config.StageSpacing, Config.StageHeight)
	local random = layout.Random
	local laneZ = layout.LaneZ

	-- Startplattform (schmal, damit man sicher auf der ersten Rampe landet)
	local startCenter = layout.StartCenter
	-- Start in einer Holzhuette, vorne offen zur ersten Rampe
	platform(startCenter, layout.StartSize, WOOD, folder).Material = Enum.Material.WoodPlanks
	for _, side in { -1, 1 } do
		part({ Size = Vector3.new(40, 10, 1), CFrame = CFrame.new(startCenter + Vector3.new(0, 5, side * 12.5)), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
		deco({ Size = Vector3.new(42, 1, 15), CFrame = CFrame.new(startCenter + Vector3.new(0, 13.2, side * 6.2)) * CFrame.Angles(side * math.rad(28), 0, 0), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = folder })
		deco({ Size = Vector3.new(42, 0.6, 15), CFrame = CFrame.new(startCenter + Vector3.new(0, 13.9, side * 6.2)) * CFrame.Angles(side * math.rad(28), 0, 0), Color = THEME.Snow, Material = Enum.Material.Snow, Parent = folder })
	end
	part({ Size = Vector3.new(1, 10, 26), CFrame = CFrame.new(startCenter + Vector3.new(-20.5, 5, 0)), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
	deco({ Size = Vector3.new(1, 3.6, 26), CFrame = CFrame.new(startCenter + Vector3.new(-20.5, 11.8, 0)), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
	-- Pfeil nach vorn
	for i = 0, 2 do
		for _, angle in { 35, -35 } do
			deco({ Size = Vector3.new(2, 0.2, 6), CFrame = CFrame.new(startCenter + Vector3.new(-6 + i * 6, 0.11, 0)) * CFrame.Angles(0, math.rad(angle), 0), Color = Color3.fromRGB(220, 60, 50), Material = Enum.Material.SmoothPlastic, Parent = folder })
		end
	end
	local sign = deco({ Size = Vector3.new(0.4, 6, 20), CFrame = CFrame.new(startCenter + Vector3.new(-19.8, 6.5, 0)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = folder })
	label(sign, Enum.NormalId.Right, `STAGE {index}\n{string.upper(def.Name)}`, THEME.Snow)

	local spawn = CFrame.lookAt(layout.Spawn, layout.Spawn + Vector3.new(100, 0, 0))
	local startZone = zone("Start", CFrame.new(startCenter + Vector3.new(0, 8, 0)), Vector3.new(40, 16, 24), index)
	startZone:SetAttribute("Spawn", spawn)

	for _, r in layout.Ramps do
		ramp(r.Ridge, r.Length, r.Width, r.Height, r.Pitch, def.Color, def.Accent, folder)
	end

	-- Zielplattform mit Torbogen
	local finishCenter = layout.FinishCenter
	platform(finishCenter, layout.FinishSize, Color3.fromRGB(240, 245, 252), folder)
	deco({ Size = Vector3.new(layout.FinishSize.X, 0.3, 4), CFrame = CFrame.new(finishCenter + Vector3.new(0, 0.12, 0)), Color = Color3.fromRGB(220, 60, 50), Material = Enum.Material.SmoothPlastic, Parent = folder })
	arch(finishCenter + Vector3.new(20, 0, 0), 60, 26, def.Accent, if index == #Config.Stages then "MAP COMPLETE" else "STAGE CLEAR", folder)
	cabin(finishCenter + Vector3.new(layout.FinishSize.X / 2 - 22, 0, -layout.FinishSize.Z / 2 + 26), folder)
	local finish = zone("Finish", CFrame.new(finishCenter + Vector3.new(0, 30, 0)), Vector3.new(layout.FinishSize.X, 60, layout.FinishSize.Z), index)
	for i = 1, 6 do
		local angle = i / 6 * math.pi * 2
		tree(finishCenter + Vector3.new(math.cos(angle) * 58, 0, math.sin(angle) * 72), random(0.8, 1.2), folder)
	end

	local killY = layout.KillY
	startZone:SetAttribute("KillY", killY)

	-- Verschneiter Talboden unter der Bahn und Berge links und rechts (Tal-Gefuehl)
	local lakeY = killY - 20
	local lakeLength = math.min(2048, finishCenter.X + 300)
	deco({ Size = Vector3.new(lakeLength, 4, Config.StageSpacing), CFrame = CFrame.new(lakeLength / 2 - 200, lakeY, laneZ), Color = Color3.fromRGB(236, 242, 250), Material = Enum.Material.Snow, Parent = folder })
	-- Berge zwischen zwei Bahnen nur einmal bauen
	for _, side in (if index == 1 then { -1, 1 } else { 1 }) do
		local x = -150
		while x < lakeLength - 200 do
			local length = random(220, 380)
			local height = random(380, 640) + (Config.StageHeight - lakeY) * 0.4
			mountain(Vector3.new(x + length / 2, lakeY, laneZ + side * Config.StageSpacing * 0.5), length, random(220, 320), height, folder)
			x += length * 0.8
		end
	end

	folder.Parent = map
	stageInfo[index] = { Spawn = spawn, Finish = finish, KillY = killY, Start = startZone }
end

---------------------------------------------------------------- Lobby

local function buildLobby()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local c = Config.LobbyCenter

	platform(c, Vector3.new(260, 12, 260), THEME.Snow, folder)
	-- Rand aus Eis, damit man nicht aus Versehen herunterfaellt
	for _, d in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local size = if d.X ~= 0 then Vector3.new(2, 5, 260) else Vector3.new(260, 5, 2)
		part({ Size = size, CFrame = CFrame.new(c + d * 129 + Vector3.new(0, 2.5, 0)), Color = THEME.Ice, Material = Enum.Material.Glass, Transparency = 0.5, Parent = folder })
	end

	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Duration = 0
	spawnPad.Size = Vector3.new(14, 1, 14)
	spawnPad.CFrame = CFrame.new(c + Vector3.new(-60, 0.5, 0))
	spawnPad.Color = THEME.Ice
	spawnPad.Material = Enum.Material.Neon
	spawnPad.Transparency = 0.4
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Parent = folder
	lobbySpawn = CFrame.lookAt(c + Vector3.new(-60, 3.2, 0), c + Vector3.new(100, 3.2, 0))

	-- Start-Portal
	local portalCenter = c + Vector3.new(90, 0, 0)
	arch(portalCenter, 36, 28, THEME.Ice, "DROP IN", folder)
	local glow = deco({ Size = Vector3.new(1, 26, 34), CFrame = CFrame.new(portalCenter + Vector3.new(0, 13, 0)), Color = THEME.Ice, Material = Enum.Material.ForceField, Transparency = 0.2, Parent = folder })
	glow.Name = "PortalGlow"
	zone("StartPortal", CFrame.new(portalCenter + Vector3.new(0, 13, 0)), Vector3.new(6, 26, 34))

	-- Riesiges Logo ueber dem Portal
	local logo = deco({ Size = Vector3.new(1, 24, 96), CFrame = CFrame.new(portalCenter + Vector3.new(22, 52, 0)), Transparency = 1, Parent = folder })
	local _, logoText = label(logo, Enum.NormalId.Left, "surf_ski", THEME.Snow, { PixelsPerStud = 12 })
	logoText.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, THEME.Ice), ColorSequenceKeypoint.new(0.55, THEME.Snow), ColorSequenceKeypoint.new(1, THEME.Aurora) })
	gradient.Parent = logoText

	-- Bestenliste (LeaderboardService schreibt hinein)
	local board = part({ Name = "Leaderboard", Size = Vector3.new(2, 48, 44), CFrame = CFrame.new(c + Vector3.new(-20, 24, -100)) * CFrame.Angles(0, math.rad(-90), 0), Color = THEME.Navy, Parent = folder })
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "BoardGui"
	boardGui.Face = Enum.NormalId.Right
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	boardGui.PixelsPerStud = 18
	boardGui.LightInfluence = 0
	boardGui.Parent = board
	WorldService.Board = board

	-- Skihuette (Shop) mit Holzwaenden und Dach
	local hut = c + Vector3.new(-10, 0, 95)
	for _, wall in {
		{ Vector3.new(0, 8, -12), Vector3.new(30, 16, 1) },
		{ Vector3.new(-15, 8, 0), Vector3.new(1, 16, 24) },
		{ Vector3.new(15, 8, 0), Vector3.new(1, 16, 24) },
	} do
		part({ Size = wall[2], CFrame = CFrame.new(hut + wall[1]), Color = Color3.fromRGB(140, 90, 60), Material = Enum.Material.WoodPlanks, Parent = folder })
	end
	for _, side in { -1, 1 } do
		part({
			ClassName = "WedgePart",
			Size = Vector3.new(34, 8, 15),
			CFrame = CFrame.new(hut + Vector3.new(0, 20, side * 7.5)) * wedgeRotation(side),
			Color = THEME.Snow,
			Material = Enum.Material.Snow,
			Parent = folder,
		})
	end
	local counter = part({ Name = "ShopCounter", Size = Vector3.new(20, 4, 4), CFrame = CFrame.new(hut + Vector3.new(0, 2, -4)), Color = Color3.fromRGB(110, 70, 45), Material = Enum.Material.Wood, Parent = folder })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Shop"
	prompt.ObjectText = "Ski Shop"
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Opens", "Shop")
	prompt.Parent = counter
	local shopSign = deco({ Size = Vector3.new(24, 6, 1), CFrame = CFrame.new(hut + Vector3.new(0, 17, 12.6)), Color = THEME.Navy, Parent = folder })
	label(shopSign, Enum.NormalId.Front, "SKI SHOP", THEME.Gold)
	label(shopSign, Enum.NormalId.Back, "SKI SHOP", THEME.Gold)
	deco({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(hut + Vector3.new(0, 12, 0)), Transparency = 1, Parent = folder })

	-- Update 3: Tor zu "Snowball Wars" (Team-Modus)
	local warsCenter = c + Vector3.new(70, 0, -70)
	arch(warsCenter, 30, 24, THEME.Aurora, "SNOWBALL WARS", folder)
	local warsGlow = deco({ Size = Vector3.new(1, 22, 28), CFrame = CFrame.new(warsCenter + Vector3.new(0, 11, 0)), Color = THEME.Aurora, Material = Enum.Material.ForceField, Transparency = 0.2, Parent = folder })
	warsGlow.Name = "WarsGlow"
	zone("WarsPortal", CFrame.new(warsCenter + Vector3.new(0, 12, 0)), Vector3.new(6, 24, 28))
	local warsSign = deco({ Size = Vector3.new(1, 5, 26), CFrame = CFrame.new(warsCenter + Vector3.new(-6, 3, 0)), Color = THEME.Navy, Parent = folder })
	label(warsSign, Enum.NormalId.Left, "2 TEAMS - GRAB WEAPONS", THEME.Gold)

	-- Update 3: Lagerfeuer mit Baenken und Laternen (gemuetliche Apres-Ski-Ecke)
	local fire = c + Vector3.new(25, 0, 45)
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2
		deco({ Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(fire + Vector3.new(math.cos(angle) * 3.2, 0.6, math.sin(angle) * 3.2)), Color = Color3.fromRGB(120, 125, 135), Material = Enum.Material.Slate, Parent = folder })
	end
	for _, angle in { 0, 60, 120 } do
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, 0.8, 0.8), CFrame = CFrame.new(fire + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(angle), math.rad(18)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = folder })
	end
	local flame = deco({ Name = "Campfire", Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(fire + Vector3.new(0, 1.2, 0)), Transparency = 1, Parent = folder })
	local fireEffect = Instance.new("Fire")
	fireEffect.Size = 6
	fireEffect.Heat = 12
	fireEffect.Color = Color3.fromRGB(255, 150, 50)
	fireEffect.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fireEffect.Parent = flame
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 170, 90)
	fireLight.Range = 24
	fireLight.Brightness = 3
	fireLight.Shadows = true
	fireLight.Parent = flame
	local crackle = Instance.new("Sound")
	crackle.Name = "Crackle"
	crackle.SoundId = SoundIds.Id("sfx_fire")
	crackle.Looped = true
	crackle.Volume = 0.7
	crackle.RollOffMinDistance = 6
	crackle.RollOffMaxDistance = 60
	crackle.Parent = flame
	crackle:Play()
	for i = 1, 3 do
		local angle = math.rad(i * 120 + 30)
		local pos = fire + Vector3.new(math.cos(angle) * 9, 0, math.sin(angle) * 9)
		deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, 1.8, 1.8), CFrame = CFrame.lookAt(pos + Vector3.new(0, 0.9, 0), fire + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, math.rad(90), 0), Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
	end
	-- Laternen am Weg zu den Toren
	for i = 0, 5 do
		local pos = c + Vector3.new(-40 + i * 24, 0, -24)
		deco({ Size = Vector3.new(0.6, 9, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)), Color = WOOD_DARK, Material = Enum.Material.Wood, Parent = folder })
		local lamp = deco({ Size = Vector3.new(1.4, 1.8, 1.4), CFrame = CFrame.new(pos + Vector3.new(0, 9.6, 0)), Color = Color3.fromRGB(255, 214, 140), Material = Enum.Material.Neon, Parent = folder })
		local lampLight = Instance.new("PointLight")
		lampLight.Color = Color3.fromRGB(255, 200, 130)
		lampLight.Range = 16
		lampLight.Brightness = 1.5
		lampLight.Parent = lamp
	end

	-- Tannen und Berge rund um die Lobby
	local rng = Random.new(7)
	for _ = 1, 22 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(70, 120)
		local pos = c + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if (pos - portalCenter).Magnitude > 30 and (pos - hut).Magnitude > 26 and (pos - (c + Vector3.new(-60, 0, 0))).Magnitude > 20 and (pos - (c + Vector3.new(-20, 0, -100))).Magnitude > 30 and (pos - warsCenter).Magnitude > 26 and (pos - fire).Magnitude > 18 then
			tree(pos, rng:NextNumber(0.7, 1.3), folder)
		end
	end
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local pos = c + Vector3.new(math.cos(angle) * 600, -400, math.sin(angle) * 600)
		local m = Instance.new("Model")
		mountain(pos, rng:NextNumber(300, 450), rng:NextNumber(260, 360), rng:NextNumber(600, 800), m)
		m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, -angle + math.pi / 2, 0) * CFrame.new(-pos) * m:GetPivot())
		m.Parent = folder
	end

	folder.Parent = map
end

---------------------------------------------------------------- Licht

local function setupLighting()
	-- Heller Wintertag mit blauem Himmel wie auf der alten Map
	Lighting.ClockTime = 13.5
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(110, 120, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(170, 180, 200)
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(205, 225, 250)
	atmosphere.Decay = Color3.fromRGB(110, 150, 210)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 11
	sky.StarCount = 0
	sky.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.08
	color.Contrast = 0.05
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(245, 248, 255)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.5
	rays.Parent = Lighting
end

---------------------------------------------------------------- Bausteine fuer andere Services (Arena, Update 3)

WorldService.Kit = {
	part = part,
	deco = deco,
	ramp = ramp,
	platform = platform,
	tree = tree,
	label = label,
	arch = arch,
	zone = function(kind: string, cframe: CFrame, size: Vector3, stage: number?)
		return zone(kind, cframe, size, stage)
	end,
	mountain = mountain,
	THEME = THEME,
	WOOD = WOOD,
	WOOD_DARK = WOOD_DARK,
	TRIM = TRIM,
}

function WorldService:GetMap(): Folder
	return map
end

---------------------------------------------------------------- Oeffentlich

function WorldService:Build()
	map = Instance.new("Folder")
	map.Name = "Map"
	zones = Instance.new("Folder")
	zones.Name = "Zones"
	measureWedge()
	buildLobby()
	for index, def in Config.Stages do
		buildStage(index, def)
	end
	map.Parent = workspace
	zones.Parent = workspace
	setupLighting()

	-- Spieler-Koerper kollidieren mit nichts: die Bewegung rechnet SurfPhysics auf dem Client
	PhysicsService:RegisterCollisionGroup("Surfers")
	PhysicsService:CollisionGroupSetCollidable("Surfers", "Default", false)
	PhysicsService:CollisionGroupSetCollidable("Surfers", "Surfers", false)
	workspace.FallenPartsDestroyHeight = -2000
	workspace:SetAttribute("StageCount", #Config.Stages)
	workspace:SetAttribute("LobbySpawn", lobbySpawn)
	workspace:SetAttribute("LobbyKillY", Config.LobbyCenter.Y - 80)
end

function WorldService:GetSpawn(stage: number): CFrame
	local info = stageInfo[stage]
	return if info then info.Spawn else lobbySpawn
end

function WorldService:GetLobbySpawn(): CFrame
	return lobbySpawn
end

function WorldService:GetStageInfo(stage: number)
	return stageInfo[stage]
end

return WorldService
