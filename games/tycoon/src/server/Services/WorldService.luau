-- Baut die Map per Code: Wiese, Marktplatz mit Samenladen und Verkaufsstand, ein Garten pro Spieler.
-- So funktioniert das Projekt auch in einem leeren Place.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local WorldService = { Services = nil :: any }
WorldService.Plots = {}

local GRID = 6 -- 6 x 6 Felder pro Garten
local TILE = 7
local TILE_GAP = 1
local PLOT_WIDTH = 60
local PLOT_DEPTH = 58
local PLOT_SPACING = 70
local PLOT_Z = 64
local MIN_PLOTS = 4
local MAX_PLOTS = 12

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
WorldService.MakePart = makePart

local function makeBillboard(parent: BasePart, offset: Vector3, size: UDim2, maxDistance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.MaxDistance = maxDistance or 150
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
WorldService.MakeBillboard = makeBillboard

local function makePrompt(parent: Instance, name: string, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = name
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Kleiner Marktstand mit Dach und Schild
local function makeStall(parent: Instance, position: Vector3, color: Color3, title: string): Part
	local counter = makePart({
		Name = title .. "Counter",
		Size = Vector3.new(14, 4, 5),
		Position = position + Vector3.new(0, 2, 0),
		Color = Color3.fromRGB(150, 100, 60),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for _, x in { -6.5, 6.5 } do
		makePart({ Size = Vector3.new(1, 10, 1), Position = position + Vector3.new(x, 5, 2), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, Parent = parent })
	end
	makePart({ Size = Vector3.new(16, 1, 8), Position = position + Vector3.new(0, 10.5, 1), Color = color, Material = Enum.Material.Fabric, Parent = parent })
	makeBillboard(counter, Vector3.new(0, 11, 0), UDim2.fromScale(14, 3)).Text = title
	return counter
end

function WorldService:Init(services)
	self.Services = services
end

-- Position eines Feldes in Garten-Koordinaten. Feld 1 liegt vorne links (Richtung Marktplatz = -Z).
function WorldService.TileOffset(index: number): Vector3
	local col = (index - 1) % GRID
	local row = (index - 1) // GRID
	local step = TILE + TILE_GAP
	return Vector3.new((col - (GRID - 1) / 2) * step, 0, -18 + row * step)
end

WorldService.TileCount = GRID * GRID

function WorldService:Build()
	local world = Instance.new("Folder")
	world.Name = "World"

	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)

	-- So viele Gaerten wie die Servergroesse erlaubt (in den Spieleinstellungen festgelegt)
	local plotsPerSide = math.ceil(math.clamp(Players.MaxPlayers, MIN_PLOTS, MAX_PLOTS) / 2)
	local halfLength = plotsPerSide * PLOT_SPACING / 2
	local groundX = math.max(320, halfLength * 2 + 80)

	makePart({
		Name = "Ground",
		Size = Vector3.new(groundX, 2, 300),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(100, 185, 80),
		Material = Enum.Material.Grass,
		Parent = world,
	})
	makePart({
		Name = "Path",
		Size = Vector3.new(groundX - 20, 0.2, 18),
		Position = Vector3.new(0, 0.1, 0),
		Color = Color3.fromRGB(215, 190, 140),
		Material = Enum.Material.Sand,
		Parent = world,
	})

	-- Unsichtbare Wand am Kartenrand
	for _, data in {
		{ Vector3.new(groundX, 40, 2), Vector3.new(0, 20, 150) },
		{ Vector3.new(groundX, 40, 2), Vector3.new(0, 20, -150) },
		{ Vector3.new(2, 40, 300), Vector3.new(groundX / 2, 20, 0) },
		{ Vector3.new(2, 40, 300), Vector3.new(-groundX / 2, 20, 0) },
	} do
		makePart({ Name = "Border", Size = data[1], Position = data[2], Transparency = 1, Parent = world })
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Color = Color3.fromRGB(255, 220, 120)
	spawn.Duration = 0
	spawn.Parent = world

	-- Marktplatz
	local market = Instance.new("Folder")
	market.Name = "Market"
	market.Parent = world
	local seedCounter = makeStall(market, Vector3.new(-22, 0, 0), Color3.fromRGB(80, 200, 90), "SEEDS")
	makePrompt(seedCounter, "OpenSeedShop", "Buy Seeds", "Seed Shop")
	local sellCounter = makeStall(market, Vector3.new(22, 0, 0), Color3.fromRGB(255, 190, 40), "SELL")
	self.SellPrompt = makePrompt(sellCounter, "SellPrompt", "Sell All Fruits", "Fruit Buyer")
	self.SellCFrame = CFrame.new(22, 3, -7)
	self.ShopCFrame = CFrame.new(-22, 3, -7)

	local restockPart = makePart({ Name = "RestockBoard", Size = Vector3.new(1, 1, 1), Position = Vector3.new(-22, 15, 0), Transparency = 1, CanCollide = false, Parent = market })
	self.RestockLabel = makeBillboard(restockPart, Vector3.zero, UDim2.fromScale(14, 2))
	self.RestockLabel.TextColor3 = Color3.fromRGB(180, 255, 180)

	local weatherPart = makePart({ Name = "WeatherCloud", Size = Vector3.new(groundX, 1, 300), Position = Vector3.new(0, 80, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = world })
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Enabled = false
	rain.Rate = 600
	rain.Lifetime = NumberRange.new(2.5)
	rain.Speed = NumberRange.new(40)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Size = NumberSequence.new(0.15)
	rain.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255))
	rain.Transparency = NumberSequence.new(0.3)
	rain.Parent = weatherPart
	self.RainEmitter = rain

	-- Gaerten: eine Reihe auf jeder Seite des Weges, Vorderseite zum Weg
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Gardens"
	plotsFolder.Parent = world

	for _, zSign in { -1, 1 } do
		for index = 1, plotsPerSide do
			local x = (index - (plotsPerSide + 1) / 2) * PLOT_SPACING
			local center = Vector3.new(x, 0, zSign * PLOT_Z)
			local plotCF = CFrame.lookAt(center, Vector3.new(x, 0, 0))
			local model = Instance.new("Model")
			model.Name = "Garden" .. (#self.Plots + 1)

			local floor = makePart({
				Name = "Floor",
				Size = Vector3.new(PLOT_WIDTH, 0.4, PLOT_DEPTH),
				CFrame = plotCF * CFrame.new(0, 0.2, 0),
				Color = Color3.fromRGB(80, 160, 70),
				Material = Enum.Material.Grass,
				Parent = model,
			})
			model.PrimaryPart = floor

			-- Holzzaun mit Eingang vorne
			local fence = Color3.fromRGB(240, 235, 220)
			local halfW, halfD = PLOT_WIDTH / 2, PLOT_DEPTH / 2
			makePart({ Name = "FenceBack", Size = Vector3.new(PLOT_WIDTH, 3, 0.6), CFrame = plotCF * CFrame.new(0, 1.5, halfD), Color = fence, Material = Enum.Material.WoodPlanks, Parent = model })
			makePart({ Name = "FenceLeft", Size = Vector3.new(0.6, 3, PLOT_DEPTH), CFrame = plotCF * CFrame.new(-halfW, 1.5, 0), Color = fence, Material = Enum.Material.WoodPlanks, Parent = model })
			makePart({ Name = "FenceRight", Size = Vector3.new(0.6, 3, PLOT_DEPTH), CFrame = plotCF * CFrame.new(halfW, 1.5, 0), Color = fence, Material = Enum.Material.WoodPlanks, Parent = model })
			for _, side in { -1, 1 } do
				makePart({ Name = "FenceFront", Size = Vector3.new(halfW - 6, 3, 0.6), CFrame = plotCF * CFrame.new(side * (halfW + 6) / 2, 1.5, -halfD), Color = fence, Material = Enum.Material.WoodPlanks, Parent = model })
			end

			local signPart = makePart({ Name = "Sign", Size = Vector3.new(1, 1, 1), CFrame = plotCF * CFrame.new(0, 9, -halfD), Transparency = 1, CanCollide = false, Parent = model })
			local signLabel = makeBillboard(signPart, Vector3.zero, UDim2.fromScale(18, 3.5))
			signLabel.Text = "Free Garden"

			local tiles = {}
			for tileIndex = 1, WorldService.TileCount do
				local tile = makePart({
					Name = "Tile" .. tileIndex,
					Size = Vector3.new(TILE, 0.6, TILE),
					CFrame = plotCF * CFrame.new(WorldService.TileOffset(tileIndex) + Vector3.new(0, 0.5, 0)),
					Color = Color3.fromRGB(70, 140, 60),
					Material = Enum.Material.Grass,
					Parent = model,
				})
				tile:SetAttribute("TileIndex", tileIndex)
				local click = Instance.new("ClickDetector")
				click.MaxActivationDistance = 40
				click.Parent = tile
				local label = makeBillboard(tile, Vector3.new(0, 4.5, 0), UDim2.fromScale(6, 1.6), 45)
				label.Text = ""
				tiles[tileIndex] = { Part = tile, Click = click, Label = label, Model = nil :: Model?, Stage = -1, PlantId = nil :: string? }
			end

			model.Parent = plotsFolder
			table.insert(self.Plots, {
				Index = #self.Plots + 1,
				Model = model,
				CFrame = plotCF,
				Tiles = tiles,
				SignLabel = signLabel,
				SpawnCFrame = plotCF * CFrame.new(0, 3, -halfD + 4),
				Owner = nil :: Player?,
			})
		end
	end

	world.Parent = workspace
end

return WorldService
