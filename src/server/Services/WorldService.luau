-- Baut die Map per Code: Boden, Laufband, Spawn und eine Basis pro moeglichem Spieler.
-- So funktioniert das Projekt auch in einem leeren Place. Die Optik kann man spaeter
-- in Studio durch gebaute Modelle ersetzen, solange die Namen gleich bleiben.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = { Services = nil :: any }
WorldService.Plots = {}

local PLOT_SIZE = 44
local PLOT_SPACING = 52
local MIN_PLOTS = 8
local MAX_PLOTS = 24
local PLOT_Z = 40
local MAX_PADS = Config.BaseSlots + Config.ExtraSlotsAmount

-- Jede Basis bekommt eine eigene Neonfarbe
local ACCENTS = {
	Color3.fromRGB(90, 170, 220),
	Color3.fromRGB(220, 170, 90),
	Color3.fromRGB(120, 190, 150),
	Color3.fromRGB(190, 130, 170),
}
local LAMP_COLOR = Color3.fromRGB(255, 214, 160)

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function makeBillboard(parent: BasePart, offset: Vector3, size: UDim2): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.AlwaysOnTop = false
	gui.MaxDistance = 150
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	return label
end

function WorldService:Init(services)
	self.Services = services
end

-- Abendstimmung mit Neon-Glow: hebt sich klar vom hellen Tageslicht der Konkurrenz ab
local function setupLighting()
	Lighting.ClockTime = 17.2
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(80, 75, 95)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Atmosphere") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(220, 200, 190)
	atmosphere.Decay = Color3.fromRGB(110, 100, 130)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 20
	bloom.Threshold = 2
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.05
	color.Contrast = 0.08
	color.Brightness = 0.03
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.8
	rays.Parent = Lighting
end

local function lampPost(position: Vector3, color: Color3, parent: Instance)
	makePart({ Name = "LampPole", Size = Vector3.new(0.6, 10, 0.6), Position = position + Vector3.new(0, 5, 0), Color = Color3.fromRGB(35, 30, 50), Material = Enum.Material.Metal, Parent = parent })
	local bulb = makePart({ Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.8, Position = position + Vector3.new(0, 10.6, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 1.6
	light.Parent = bulb
end

-- Schwebender Kristall zur Deko (der Client dreht alles mit dem Tag "Spin")
local function crystal(position: Vector3, color: Color3, size: number, parent: Instance)
	local part = makePart({
		Name = "Crystal",
		Size = Vector3.new(size * 0.6, size, size * 0.6),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(45)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
		CastShadow = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = size * 3
	light.Brightness = 1.2
	light.Parent = part
	CollectionService:AddTag(part, "Spin")
end

-- Position des Slots in Plot-Koordinaten (vorne = -Z, Richtung Laufband)
function WorldService.PadOffset(index: number): Vector3
	local col = (index - 1) % 4
	local row = (index - 1) // 4
	return Vector3.new(-15 + col * 10, 0, -6 + row * 10)
end

function WorldService:Build()
	local world = Instance.new("Folder")
	world.Name = "World"
	setupLighting()

	-- So viele Basen wie die Servergroesse erlaubt (in den Spieleinstellungen festgelegt)
	local plotsPerSide = math.ceil(math.clamp(Players.MaxPlayers, MIN_PLOTS, MAX_PLOTS) / 2)
	local plotCentersX = {}
	for index = 1, plotsPerSide do
		table.insert(plotCentersX, (index - (plotsPerSide + 1) / 2) * PLOT_SPACING)
	end
	local halfLength = plotsPerSide * PLOT_SPACING / 2 + 16
	Config.Conveyor.StartX = -halfLength
	Config.Conveyor.EndX = halfLength
	local groundSize = math.max(340, halfLength * 2 + 100)

	makePart({
		Name = "Ground",
		Size = Vector3.new(groundSize, 2, 340),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(85, 130, 80),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	-- Leuchtender Weg entlang des Laufbands
	makePart({
		Name = "Plaza",
		Size = Vector3.new(groundSize - 40, 0.2, 28),
		Position = Vector3.new(0, 0.05, 0),
		Color = Color3.fromRGB(40, 35, 60),
		Material = Enum.Material.Slate,
		Parent = world,
	})

	local conveyor = Config.Conveyor
	local length = conveyor.EndX - conveyor.StartX
	makePart({
		Name = "Conveyor",
		Size = Vector3.new(length, 1, conveyor.Width),
		Position = Vector3.new((conveyor.StartX + conveyor.EndX) / 2, 0.5, conveyor.Z),
		Color = Color3.fromRGB(30, 28, 40),
		Material = Enum.Material.DiamondPlate,
		Parent = world,
	})
	-- Pfeile auf dem Laufband; der Client laesst sie als Lauflicht pulsieren (Tag "BeltArrow")
	local arrowCount = math.floor(length / 6)
	for index = 0, arrowCount - 1 do
		local x = conveyor.StartX + 3 + index * 6
		for _, side in { -1, 1 } do
			local arrow = makePart({
				Name = "BeltArrow",
				Size = Vector3.new(0.5, 0.1, 2.6),
				CFrame = CFrame.new(x, 1.02, conveyor.Z + side * 1.1) * CFrame.Angles(0, math.rad(side * 35), 0),
				Color = Color3.fromRGB(150, 200, 230),
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = world,
			})
			arrow:SetAttribute("Phase", index)
			CollectionService:AddTag(arrow, "BeltArrow")
		end
	end
	-- Laternen links und rechts vom Laufband
	local lampIndex = 0
	for x = conveyor.StartX + 8, conveyor.EndX - 8, 26 do
		lampIndex += 1
		for _, side in { -1, 1 } do
			lampPost(Vector3.new(x, 0, conveyor.Z + side * 12), LAMP_COLOR, world)
		end
	end
	for _, side in { -1, 1 } do
		makePart({
			Name = "Rail",
			Size = Vector3.new(length, 1.5, 0.6),
			Position = Vector3.new((conveyor.StartX + conveyor.EndX) / 2, 1.25, conveyor.Z + side * (conveyor.Width / 2 + 0.3)),
			Color = Color3.fromRGB(255, 200, 40),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = world,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.Position = Vector3.new(conveyor.StartX - 20, 0.5, 0)
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(90, 170, 220)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = world

	-- Grosses Neon-Schild ueber dem Eingang
	local gate = Vector3.new(conveyor.StartX - 20, 0, 0)
	for _, side in { -1, 1 } do
		makePart({ Name = "GatePillar", Size = Vector3.new(2, 22, 2), Position = gate + Vector3.new(6, 11, side * 13), Color = Color3.fromRGB(60, 55, 75), Material = Enum.Material.Slate, Parent = world })
	end
	local banner = makePart({ Name = "GateSign", Size = Vector3.new(1, 6, 28), Position = gate + Vector3.new(6, 20, 0), Color = Color3.fromRGB(25, 20, 40), Parent = world })
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.CanvasSize = Vector2.new(700, 150)
		gui.Parent = banner
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = "STEAL A CRITTER"
		text.TextColor3 = Color3.fromRGB(255, 225, 120)
		text.TextStrokeColor3 = Color3.fromRGB(30, 25, 45)
		text.TextStrokeTransparency = 0
		text.Parent = gui
	end

	-- Schwebende Kristalle am Rand der Karte
	local rng = Random.new(7)
	for _ = 1, 8 do
		local x = rng:NextNumber(-groundSize / 2 + 10, groundSize / 2 - 10)
		local z = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(PLOT_Z + PLOT_SIZE / 2 + 12, 160)
		crystal(Vector3.new(x, rng:NextNumber(10, 22), z), Color3.fromRGB(150, 200, 230), rng:NextNumber(4, 8), world)
	end

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world

	local half = PLOT_SIZE / 2
	for _, zSign in { -1, 1 } do
		for _, x in plotCentersX do
			local center = Vector3.new(x, 1, zSign * PLOT_Z)
			local plotCF = CFrame.lookAt(center, Vector3.new(x, 1, conveyor.Z))
			local model = Instance.new("Model")
			model.Name = "Plot" .. (#self.Plots + 1)
			local accent = ACCENTS[(#self.Plots % #ACCENTS) + 1]

			local floor = makePart({
				Name = "Floor",
				Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
				CFrame = plotCF * CFrame.new(0, -0.5, 0),
				Color = Color3.fromRGB(150, 140, 125),
				Material = Enum.Material.WoodPlanks,
				Parent = model,
			})
			model.PrimaryPart = floor

			-- Getoente Glaswaende mit Neon-Oberkante in der Farbe der Basis
			local wallColor = accent:Lerp(Color3.fromRGB(200, 200, 210), 0.6)
			local walls = {
				{ "WallBack", Vector3.new(PLOT_SIZE, 8, 1), CFrame.new(0, 4, half) },
				{ "WallLeft", Vector3.new(1, 8, PLOT_SIZE), CFrame.new(-half, 4, 0) },
				{ "WallRight", Vector3.new(1, 8, PLOT_SIZE), CFrame.new(half, 4, 0) },
			}
			for _, wall in walls do
				makePart({ Name = wall[1], Size = wall[2], CFrame = plotCF * wall[3], Color = wallColor, Material = Enum.Material.Glass, Transparency = 0.25, Parent = model })
				makePart({ Name = "Trim", Size = wall[2] * Vector3.new(1, 0, 1) + Vector3.new(0.4, 0.5, 0.4), CFrame = plotCF * wall[3] * CFrame.new(0, 4.2, 0), Color = accent, Material = Enum.Material.Neon, CanCollide = false, Parent = model })
			end
			-- Neon-Linie am offenen Eingang
			makePart({ Name = "EntryLine", Size = Vector3.new(PLOT_SIZE, 0.15, 0.6), CFrame = plotCF * CFrame.new(0, 0.05, -half), Color = accent, Material = Enum.Material.Neon, CanCollide = false, Parent = model })

			local barrier = makePart({
				Name = "Barrier",
				Size = Vector3.new(PLOT_SIZE, 8, 0.5),
				CFrame = plotCF * CFrame.new(0, 4, -half),
				Color = Color3.fromRGB(255, 40, 40),
				Material = Enum.Material.ForceField,
				Transparency = 1,
				CanCollide = false,
				CanQuery = false,
				Parent = model,
			})

			local signPart = makePart({
				Name = "Sign",
				Size = Vector3.new(1, 1, 1),
				CFrame = plotCF * CFrame.new(0, 10, half),
				Transparency = 1,
				CanCollide = false,
				Parent = model,
			})
			local signLabel = makeBillboard(signPart, Vector3.zero, UDim2.fromScale(16, 3))
			signLabel.Text = "Empty Base"

			local lockButton = makePart({
				Name = "LockButton",
				Size = Vector3.new(4, 1, 4),
				CFrame = plotCF * CFrame.new(-17, 0.5, -17),
				Color = Color3.fromRGB(255, 70, 70),
				Material = Enum.Material.Neon,
				Parent = model,
			})
			local lockLabel = makeBillboard(lockButton, Vector3.new(0, 3.5, 0), UDim2.fromScale(7, 1.6))
			lockLabel.Text = "LOCK BASE"
			local lockPrompt = Instance.new("ProximityPrompt")
			lockPrompt.Name = "LockPrompt"
			lockPrompt.ActionText = "Lock Base"
			lockPrompt.ObjectText = "Free"
			lockPrompt.HoldDuration = 0.3
			lockPrompt.MaxActivationDistance = 10
			lockPrompt.RequiresLineOfSight = false
			lockPrompt.Parent = lockButton

			local pads = {}
			for index = 1, MAX_PADS do
				local pad = makePart({
					Name = "Pad" .. index,
					Size = Vector3.new(6, 0.2, 6),
					CFrame = plotCF * CFrame.new(WorldService.PadOffset(index) + Vector3.new(0, 0.1, 0)),
					Color = Color3.fromRGB(110, 105, 100),
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0,
					CanCollide = false,
					Parent = model,
				})
				pads[index] = pad
			end

			model.Parent = plotsFolder
			table.insert(self.Plots, {
				Index = #self.Plots + 1,
				Model = model,
				Accent = accent,
				DefaultAccent = accent, -- nach dem Verlassen zuruecksetzen (eigene Basis-Farbe gehoert dem Spieler)
				CFrame = plotCF,
				HalfSize = half,
				Pads = pads,
				Barrier = barrier,
				SignLabel = signLabel,
				LockButton = lockButton,
				LockLabel = lockLabel,
				LockPrompt = lockPrompt,
				SpawnCFrame = plotCF * CFrame.new(0, 4, -14),
				Owner = nil,
				LockedUntil = 0,
				LockCooldownUntil = 0,
			})
		end
	end

	world.Parent = workspace
end

-- Ist die Position innerhalb der Basis (inklusive Hoehe bis 25 Studs)?
function WorldService.IsInside(plot, position: Vector3): boolean
	local localPos = plot.CFrame:PointToObjectSpace(position)
	return math.abs(localPos.X) <= plot.HalfSize and math.abs(localPos.Z) <= plot.HalfSize and localPos.Y < 25 and localPos.Y > -5
end

return WorldService
