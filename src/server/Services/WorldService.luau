-- Baut die Map per Code: Boden, Laufband, Spawn und 8 Basen.
-- So funktioniert das Projekt auch in einem leeren Place. Die Optik kann man spaeter
-- in Studio durch gebaute Modelle ersetzen, solange die Namen gleich bleiben.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WorldService = { Services = nil :: any }
WorldService.Plots = {}

local PLOT_SIZE = 44
local PLOT_CENTERS_X = { -78, -26, 26, 78 }
local PLOT_Z = 40
local MAX_PADS = Config.BaseSlots + Config.ExtraSlotsAmount

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

-- Position des Slots in Plot-Koordinaten (vorne = -Z, Richtung Laufband)
function WorldService.PadOffset(index: number): Vector3
	local col = (index - 1) % 4
	local row = (index - 1) // 4
	return Vector3.new(-15 + col * 10, 0, -6 + row * 10)
end

function WorldService:Build()
	local world = Instance.new("Folder")
	world.Name = "World"

	makePart({
		Name = "Ground",
		Size = Vector3.new(340, 2, 340),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(90, 170, 80),
		Material = Enum.Material.Grass,
		Parent = world,
	})

	local conveyor = Config.Conveyor
	local length = conveyor.EndX - conveyor.StartX
	makePart({
		Name = "Conveyor",
		Size = Vector3.new(length, 1, conveyor.Width),
		Position = Vector3.new((conveyor.StartX + conveyor.EndX) / 2, 0.5, conveyor.Z),
		Color = Color3.fromRGB(45, 45, 55),
		Material = Enum.Material.DiamondPlate,
		Parent = world,
	})
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
	spawn.Parent = world

	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world

	local half = PLOT_SIZE / 2
	for _, zSign in { -1, 1 } do
		for _, x in PLOT_CENTERS_X do
			local center = Vector3.new(x, 1, zSign * PLOT_Z)
			local plotCF = CFrame.lookAt(center, Vector3.new(x, 1, conveyor.Z))
			local model = Instance.new("Model")
			model.Name = "Plot" .. (#self.Plots + 1)

			local floor = makePart({
				Name = "Floor",
				Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
				CFrame = plotCF * CFrame.new(0, -0.5, 0),
				Color = Color3.fromRGB(230, 225, 210),
				Material = Enum.Material.WoodPlanks,
				Parent = model,
			})
			model.PrimaryPart = floor

			local wallColor = Color3.fromRGB(120, 90, 200)
			makePart({ Name = "WallBack", Size = Vector3.new(PLOT_SIZE, 8, 1), CFrame = plotCF * CFrame.new(0, 4, half), Color = wallColor, Parent = model })
			makePart({ Name = "WallLeft", Size = Vector3.new(1, 8, PLOT_SIZE), CFrame = plotCF * CFrame.new(-half, 4, 0), Color = wallColor, Parent = model })
			makePart({ Name = "WallRight", Size = Vector3.new(1, 8, PLOT_SIZE), CFrame = plotCF * CFrame.new(half, 4, 0), Color = wallColor, Parent = model })

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
					Color = Color3.fromRGB(80, 80, 90),
					Material = Enum.Material.SmoothPlastic,
					CanCollide = false,
					Parent = model,
				})
				pads[index] = pad
			end

			model.Parent = plotsFolder
			table.insert(self.Plots, {
				Index = #self.Plots + 1,
				Model = model,
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
