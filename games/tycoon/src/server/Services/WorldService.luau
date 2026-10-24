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
	Lighting.GlobalShadows = true
	-- Warmer, satter Look
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Haze = 1
	atmosphere.Color = Color3.fromRGB(200, 230, 255)
	atmosphere.Decay = Color3.fromRGB(120, 170, 220)
	atmosphere.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.15
	color.Contrast = 0.05
	color.TintColor = Color3.fromRGB(255, 250, 240)
	color.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.4
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local sunRays = Instance.new("SunRaysEffect")
	sunRays.Intensity = 0.06
	sunRays.Parent = Lighting

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

	self:Decorate(world, groundX)
	world.Parent = workspace
end

-- Baeume am Rand, Blumen am Weg, Laternen und ein Brunnen in der Mitte
function WorldService:Decorate(world: Instance, groundX: number)
	local deco = Instance.new("Folder")
	deco.Name = "Decoration"
	deco.Parent = world
	local rng = Random.new(42)

	local function tree(position: Vector3, scale: number)
		makePart({ Name = "Trunk", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8 * scale, 2 * scale, 2 * scale), CFrame = CFrame.new(position + Vector3.new(0, 4 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.Wood, Parent = deco })
		for _, offset in { Vector3.new(0, 10, 0), Vector3.new(2.5, 8.5, 1), Vector3.new(-2.5, 8.5, -1) } do
			makePart({ Name = "Leaves", Shape = Enum.PartType.Ball, Size = Vector3.one * 7 * scale, Position = position + offset * scale, Color = Color3.fromRGB(60 + rng:NextInteger(0, 30), 160 + rng:NextInteger(0, 40), 60), Material = Enum.Material.Grass, CastShadow = true, Parent = deco })
		end
	end

	-- Baumreihe hinter den Gaerten und an den Seiten
	local half = groundX / 2
	for x = -half + 12, half - 12, 18 do
		for _, z in { 138, -138 } do
			tree(Vector3.new(x + rng:NextNumber(-4, 4), 0, z + rng:NextNumber(-4, 4)), rng:NextNumber(0.9, 1.3))
		end
	end
	for z = -110, 110, 22 do
		for _, x in { half - 10, -half + 10 } do
			tree(Vector3.new(x, 0, z + rng:NextNumber(-4, 4)), rng:NextNumber(0.9, 1.3))
		end
	end

	-- Blumen entlang des Weges
	local flowerColors = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 220, 60), Color3.fromRGB(180, 110, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 40) }
	for x = -half + 14, half - 14, 5 do
		for _, z in { 10.5, -10.5 } do
			if math.abs(x) > 34 then
				local base = Vector3.new(x + rng:NextNumber(-1.5, 1.5), 0, z + rng:NextNumber(-0.8, 0.8))
				makePart({ Name = "Stem", Size = Vector3.new(0.2, 1.4, 0.2), Position = base + Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(60, 150, 60), CanCollide = false, Parent = deco })
				makePart({ Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = base + Vector3.new(0, 1.5, 0), Color = flowerColors[rng:NextInteger(1, #flowerColors)], CanCollide = false, Parent = deco })
			end
		end
	end

	-- Laternen mit warmem Licht
	for x = -half + 30, half - 30, 60 do
		for _, z in { 12.5, -12.5 } do
			makePart({ Name = "LampPost", Size = Vector3.new(0.6, 9, 0.6), Position = Vector3.new(x, 4.5, z), Color = Color3.fromRGB(50, 55, 60), Material = Enum.Material.Metal, Parent = deco })
			local lamp = makePart({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Position = Vector3.new(x, 9.4, z), Color = Color3.fromRGB(255, 230, 160), Material = Enum.Material.Neon, CanCollide = false, Parent = deco })
			local light = Instance.new("PointLight")
			light.Range = 18
			light.Brightness = 1.2
			light.Color = Color3.fromRGB(255, 220, 160)
			light.Parent = lamp
		end
	end

	-- Brunnen in der Mitte des Marktplatzes (hinter dem Spawn)
	local center = Vector3.new(0, 0, 14)
	makePart({ Name = "FountainBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 12, 12), CFrame = CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble, Parent = deco })
	makePart({ Name = "FountainWater", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 10.4, 10.4), CFrame = CFrame.new(center + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(80, 170, 255), Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Parent = deco })
	local spout = makePart({ Name = "FountainSpout", Size = Vector3.new(1.4, 5, 1.4), Position = center + Vector3.new(0, 4, 0), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Marble, Parent = deco })
	local water = Instance.new("ParticleEmitter")
	water.Rate = 60
	water.Lifetime = NumberRange.new(1, 1.4)
	water.Speed = NumberRange.new(10, 12)
	water.SpreadAngle = Vector2.new(18, 18)
	water.Acceleration = Vector3.new(0, -25, 0)
	water.Size = NumberSequence.new(0.35, 0.1)
	water.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255))
	water.Transparency = NumberSequence.new(0.2, 0.8)
	water.EmissionDirection = Enum.NormalId.Top
	water.Parent = spout
end

return WorldService
