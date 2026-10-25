-- Baut die ganze Stadt aus Parts: Strassen, Hochhaeuser, Bank, Juwelier, Tankstelle, Polizei, Gefaengnis,
-- Versteck, Autohaus, Lieferdepot, Stunt-Park, Vororte, Strand. Dazu Licht, Tag/Nacht und Team-Spawns.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)
local Build = require(script.Parent.Build)

local WorldService = {
	Services = nil :: any,
	Lots = {} :: { CFrame },
	RobPoints = {} :: { [string]: BasePart },
	DeliveryPoints = {} :: { Vector3 },
	RaceCheckpoints = {} :: { Vector3 },
	RaceStart = nil :: BasePart?,
	Depot = nil :: BasePart?,
	Hideout = nil :: BasePart?,
	JailCenter = Vector3.zero,
	JailHalf = 0,
	JailCells = {} :: { Vector3 },
	JailExit = Vector3.zero,
	Spawns = {} :: { [string]: Vector3 },
	Showroom = {} :: { CFrame },
	TeamObjects = {} :: { [string]: Team },
	-- Update 2
	SprayPad = nil :: BasePart?,
	SpeedCams = {} :: { { Position: Vector3, Name: string } },
	Tokens = {} :: { { Id: number, Position: Vector3 } },
}

local C = Config.Colors
local INK = C.Ink
local ASPHALT = Color3.fromRGB(58, 58, 72)
local SIDEWALK = Color3.fromRGB(214, 208, 200)
local GRASS = Color3.fromRGB(120, 200, 95)
local PASTELS = {
	Color3.fromRGB(255, 183, 178),
	Color3.fromRGB(255, 218, 170),
	Color3.fromRGB(181, 234, 215),
	Color3.fromRGB(199, 206, 234),
	Color3.fromRGB(255, 240, 180),
	Color3.fromRGB(205, 180, 219),
	Color3.fromRGB(170, 215, 255),
	Color3.fromRGB(255, 200, 225),
}

local rng = Random.new(20261024)
local world: Model

local function pastel(): Color3
	return PASTELS[rng:NextInteger(1, #PASTELS)]
end

local function folder(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = world
	return model
end

-- Halle mit Tuer vorn (lokal -Z), Boden, Dach. cf = Mitte am Boden, LookVector = Vorderseite.
local function hall(parent: Instance, cf: CFrame, w: number, h: number, d: number, color: Color3, door: number, glass: boolean?)
	local model = Instance.new("Model")
	model.Name = "Hall"
	model.Parent = parent
	local t = 1.5
	local wallMaterial = if glass then Enum.Material.Glass else Enum.Material.SmoothPlastic
	local wallColor = if glass then Color3.fromRGB(190, 230, 255) else color
	local transparency = if glass then 0.45 else 0
	Build.Box(model, cf * CFrame.new(0, 0, 0), Vector3.new(w, 0.4, d), Color3.fromRGB(240, 235, 225))
	Build.Box(model, cf * CFrame.new(0, 0, d / 2 - t / 2), Vector3.new(w, h, t), color)
	Build.Box(model, cf * CFrame.new(-w / 2 + t / 2, 0, 0), Vector3.new(t, h, d), wallColor, wallMaterial, { Transparency = transparency })
	Build.Box(model, cf * CFrame.new(w / 2 - t / 2, 0, 0), Vector3.new(t, h, d), wallColor, wallMaterial, { Transparency = transparency })
	local side = (w - door) / 2
	for _, s in { -1, 1 } do
		Build.Box(model, cf * CFrame.new(s * (door / 2 + side / 2), 0, -d / 2 + t / 2), Vector3.new(side, h, t), wallColor, wallMaterial, { Transparency = transparency })
	end
	Build.Box(model, cf * CFrame.new(0, h - 4, -d / 2 + t / 2), Vector3.new(door, 4, t), color)
	Build.Box(model, cf * CFrame.new(0, h, 0), Vector3.new(w + 2, 1.5, d + 2), INK)
	return model
end

local function sign(parent: Instance, cf: CFrame, size: Vector3, text: string, bg: Color3, fg: Color3)
	local part = Build.Part(parent, { Size = size, CFrame = cf, Color = bg, CanCollide = false })
	Build.Sign(part, text, bg, fg, Enum.NormalId.Front)
	Build.Sign(part, text, bg, fg, Enum.NormalId.Back)
	return part
end

local function robPoint(parent: Instance, position: Vector3, key: string)
	local info = Config.Robberies[key]
	local part = Build.Part(parent, {
		Name = "RobPoint",
		Size = Vector3.new(4, 4, 4),
		CFrame = CFrame.new(position + Vector3.new(0, 2, 0)),
		Transparency = 1,
		CanCollide = false,
	})
	part:SetAttribute("Robbery", key)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RobPrompt"
	prompt.ActionText = "Grab Loot"
	prompt.ObjectText = info.Name
	prompt.HoldDuration = info.Hold
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("Team", "Robbers")
	prompt.Parent = part
	WorldService.RobPoints[key] = part
	return part
end

local function prompt(part: BasePart, action: string, object: string, attributes: { [string]: any }?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	if attributes then
		for key, value in attributes do
			p:SetAttribute(key, value)
		end
	end
	p.Parent = part
	return p
end

local function facingCF(center: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(center, center + direction)
end

local SOUTH = Vector3.new(0, 0, 1)
local NORTH = Vector3.new(0, 0, -1)
local WEST = Vector3.new(-1, 0, 0)

---------------------------------------------------------------- Blocktypen

local function towers(c: Vector3, minH: number, maxH: number)
	local model = folder("Towers")
	for _, dx in { -40, 40 } do
		for _, dz in { -40, 40 } do
			local w = rng:NextNumber(46, 62)
			local d = rng:NextNumber(46, 62)
			local h = rng:NextNumber(minH, maxH)
			Build.Tower(model, CFrame.new(c + Vector3.new(dx, 0, dz)) * CFrame.Angles(0, math.rad(rng:NextInteger(0, 3) * 90), 0), Vector3.new(w, h, d), pastel(), Color3.fromRGB(120, 190, 255), rng)
		end
	end
end

local SHOP_NAMES = { "PIZZA", "TOYS", "BURGERS", "ARCADE", "COMICS", "ICE CREAM", "PETS", "SNEAKERS", "TACOS", "CANDY", "GAMES", "BIKES" }

local function shopRow(parent: Instance, cf: CFrame, count: number, width: number)
	for i = 1, count do
		local x = (i - (count + 1) / 2) * width
		local shopCF = cf * CFrame.new(x, 0, 0)
		local color = pastel()
		local h = rng:NextNumber(18, 28)
		Build.Box(parent, shopCF, Vector3.new(width - 2, h, 36), color)
		-- Schaufenster und Markise
		Build.Box(parent, shopCF * CFrame.new(0, 2, -18.2), Vector3.new(width - 8, 8, 0.4), Color3.fromRGB(170, 220, 255), Enum.Material.Glass, { Reflectance = 0.2 })
		local awning = Build.Wedge(parent, shopCF * CFrame.new(0, 12, -20.5), Vector3.new(width - 4, 2, 5), if i % 2 == 0 then C.Pink else C.Teal)
		awning.CanCollide = false
		local name = SHOP_NAMES[rng:NextInteger(1, #SHOP_NAMES)]
		sign(parent, shopCF * CFrame.new(0, h - 4, -18.6), Vector3.new(width - 8, 5, 0.6), name, C.Cream, C.Orange)
	end
end

local function shops(c: Vector3)
	local model = folder("Shops")
	shopRow(model, facingCF(c + Vector3.new(0, 0, 50), SOUTH), 4, 38)
	shopRow(model, facingCF(c + Vector3.new(0, 0, -50), NORTH), 4, 38)
end

local function park(c: Vector3)
	local model = folder("Park")
	Build.Box(model, CFrame.new(c + Vector3.new(0, -0.05, 0)), Vector3.new(156, 0.2, 156), GRASS, Enum.Material.Grass)
	Build.Box(model, CFrame.new(c), Vector3.new(156, 0.25, 10), SIDEWALK)
	Build.Box(model, CFrame.new(c), Vector3.new(10, 0.25, 156), SIDEWALK)
	Build.Part(model, {
		Size = Vector3.new(1, 36, 36),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(c + Vector3.new(40, 0.2, 40)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(90, 190, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	for _ = 1, 14 do
		local p = c + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))
		if math.abs(p.X - c.X) > 10 and math.abs(p.Z - c.Z) > 10 and (p - (c + Vector3.new(40, 0, 40))).Magnitude > 24 then
			Build.Tree(model, p, rng)
		end
	end
end

local function plaza(c: Vector3)
	local model = folder("Plaza")
	Build.Box(model, CFrame.new(c), Vector3.new(156, 0.2, 156), Color3.fromRGB(245, 225, 200))
	-- Pflastermuster
	for i = -3, 3 do
		Build.Box(model, CFrame.new(c + Vector3.new(i * 22, 0, 0)), Vector3.new(2, 0.25, 156), Color3.fromRGB(230, 200, 170))
	end
	-- Rathaus hinten (Norden)
	local hallCF = facingCF(c + Vector3.new(0, 0, -50), SOUTH)
	Build.Box(model, hallCF, Vector3.new(110, 34, 40), Color3.fromRGB(255, 248, 231))
	for i = -4, 4 do
		Build.Part(model, {
			Size = Vector3.new(26, 2.6, 2.6),
			Shape = Enum.PartType.Cylinder,
			CFrame = hallCF * CFrame.new(i * 11, 13, -22) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(240, 235, 225),
		})
	end
	Build.Box(model, hallCF * CFrame.new(0, 26, -22), Vector3.new(104, 3, 4), C.Orange)
	sign(model, hallCF * CFrame.new(0, 40, -18), Vector3.new(80, 12, 1), "TURBO CITY", C.Lemon, C.Pink)
	-- Brunnen
	Build.Part(model, {
		Size = Vector3.new(2, 30, 30),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(c + Vector3.new(0, 1, 15)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = C.Teal,
	})
	Build.Part(model, {
		Size = Vector3.new(2.2, 26, 26),
		Shape = Enum.PartType.Cylinder,
		CFrame = CFrame.new(c + Vector3.new(0, 1.2, 15)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 210, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	})
	local spout = Build.Part(model, {
		Size = Vector3.new(3, 10, 3),
		CFrame = CFrame.new(c + Vector3.new(0, 5, 15)),
		Color = C.Lemon,
	})
	local water = Instance.new("ParticleEmitter")
	water.Color = ColorSequence.new(Color3.fromRGB(170, 230, 255))
	water.Size = NumberSequence.new(0.8, 0.2)
	water.Speed = NumberRange.new(18, 24)
	water.SpreadAngle = Vector2.new(20, 20)
	water.Acceleration = Vector3.new(0, -40, 0)
	water.Lifetime = NumberRange.new(1, 1.4)
	water.Rate = 40
	water.LightEmission = 0.4
	water.EmissionDirection = Enum.NormalId.Top
	water.Parent = spout
	-- Team-Kioske
	local kiosks = {
		{ Team = "Police", Text = "POLICE", Color = C.Police, X = -45 },
		{ Team = "Citizens", Text = "CITIZEN", Color = C.Citizen, X = 0 },
		{ Team = "Robbers", Text = "ROBBERS", Color = C.Robber, X = 45 },
	}
	for _, kiosk in kiosks do
		local cf = facingCF(c + Vector3.new(kiosk.X, 0, 55), NORTH)
		local base = Build.Box(model, cf, Vector3.new(14, 8, 6), kiosk.Color)
		sign(model, cf * CFrame.new(0, 11, 0), Vector3.new(16, 5, 0.6), kiosk.Text, kiosk.Color, Color3.new(1, 1, 1))
		prompt(base, "Join Team", kiosk.Text, { SetTeam = kiosk.Team })
	end
	-- Rangliste
	local board = Build.Part(world, {
		Name = "Leaderboard",
		Size = Vector3.new(24, 30, 1),
		CFrame = facingCF(c + Vector3.new(-62, 16, -6), Vector3.new(1, 0, 0.3).Unit),
		Color = INK,
	})
	board:SetAttribute("Title", "RICHEST IN TURBO CITY")
	Build.Box(model, CFrame.new(c + Vector3.new(-62, 0, -6)), Vector3.new(2, 2, 2), INK)
	-- Ranglisten fuer Polizei und Raeuber (Update 2)
	for _, info in {
		{ Name = "TopCopsBoard", Title = "TOP COPS (ARRESTS)", Z = -18, Color = C.Police },
		{ Name = "TopRobbersBoard", Title = "MOST WANTED (LOOT GRABS)", Z = 18, Color = C.Robber },
	} do
		local extra = Build.Part(world, {
			Name = info.Name,
			Size = Vector3.new(24, 30, 1),
			CFrame = facingCF(c + Vector3.new(64, 16, info.Z), Vector3.new(-1, 0, 0)),
			Color = INK,
		})
		extra:SetAttribute("Title", info.Title)
		Build.Box(model, CFrame.new(c + Vector3.new(64.8, 0, info.Z)), Vector3.new(1, 31, 25), info.Color)
	end
	WorldService.Spawns.Citizens = c + Vector3.new(0, 0, 40)
end

local function bank(c: Vector3)
	local model = folder("Bank")
	local cf = facingCF(c + Vector3.new(0, 0, 10), SOUTH)
	Build.Box(model, cf * CFrame.new(0, 0, -6), Vector3.new(120, 1.2, 100), Color3.fromRGB(235, 230, 220))
	hall(model, cf * CFrame.new(0, 1.2, 0), 100, 36, 80, Color3.fromRGB(250, 245, 235), 24)
	for i = -4, 4 do
		if math.abs(i) > 1 then
			Build.Part(model, {
				Size = Vector3.new(30, 3.2, 3.2),
				Shape = Enum.PartType.Cylinder,
				CFrame = cf * CFrame.new(i * 11, 16.2, -46) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(245, 240, 230),
			})
		end
	end
	Build.Box(model, cf * CFrame.new(0, 31, -46), Vector3.new(104, 6, 4), Color3.fromRGB(245, 240, 230))
	sign(model, cf * CFrame.new(0, 34, -48.5), Vector3.new(40, 9, 1), "$ BANK $", C.Lemon, C.Green)
	-- Tresor hinten
	local door = Build.Part(model, {
		Size = Vector3.new(2, 26, 26),
		Shape = Enum.PartType.Cylinder,
		CFrame = cf * CFrame.new(0, 15, 37) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(170, 175, 190),
		Material = Enum.Material.DiamondPlate,
	})
	door.CanCollide = false
	for i = 1, 4 do
		Build.Box(model, cf * CFrame.new(-30 + i * 2.2, 1.6, 30 - i * 0.5), Vector3.new(2, i * 1.2, 4), Color3.fromRGB(255, 200, 40), Enum.Material.Foil)
		Build.Box(model, cf * CFrame.new(30 - i * 2.2, 1.6, 30 - i * 0.5), Vector3.new(2, i * 1.2, 4), Color3.fromRGB(255, 200, 40), Enum.Material.Foil)
	end
	robPoint(model, (cf * CFrame.new(0, 1.2, 30)).Position, "Bank")
end

local function gemStore(c: Vector3)
	local model = folder("GemStore")
	local cf = facingCF(c + Vector3.new(0, 0, 40), SOUTH)
	hall(model, cf, 70, 22, 50, Color3.fromRGB(205, 180, 219), 16, true)
	sign(model, cf * CFrame.new(0, 26, -25), Vector3.new(44, 7, 1), "GEM STORE", C.Pink, Color3.new(1, 1, 1))
	local gemColors = { Color3.fromRGB(255, 80, 160), Color3.fromRGB(80, 220, 255), Color3.fromRGB(120, 255, 140), Color3.fromRGB(255, 220, 60) }
	for i = 1, 6 do
		local x = (i - 3.5) * 9
		Build.Box(model, cf * CFrame.new(x, 0.4, 6), Vector3.new(5, 3.5, 5), Color3.fromRGB(250, 250, 255))
		local gem = Build.Part(model, {
			Size = Vector3.new(2, 2, 2),
			CFrame = cf * CFrame.new(x, 5.5, 6) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Color = gemColors[(i % #gemColors) + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		gem:AddTag("Spin")
	end
	robPoint(model, (cf * CFrame.new(0, 0.4, 14)).Position, "Gems")
	for _, dx in { -40, 40 } do
		Build.Tower(model, CFrame.new(c + Vector3.new(dx, 0, -40)), Vector3.new(56, rng:NextNumber(60, 120), 56), pastel(), Color3.fromRGB(120, 190, 255), rng)
	end
end

local function gasStation(c: Vector3, key: string, label: string)
	local model = folder("GasStation")
	local cf = facingCF(c + Vector3.new(0, 0, 0), WEST)
	-- Dach ueber den Zapfsaeulen
	Build.Box(model, cf * CFrame.new(0, 16, -30), Vector3.new(60, 2, 36), C.Orange)
	Build.Box(model, cf * CFrame.new(0, 18, -30), Vector3.new(60, 0.6, 36), INK)
	for _, x in { -26, 26 } do
		for _, z in { -44, -16 } do
			Build.Box(model, cf * CFrame.new(x, 0, z), Vector3.new(2, 16, 2), Color3.fromRGB(245, 245, 250))
		end
	end
	for _, x in { -14, 0, 14 } do
		Build.Box(model, cf * CFrame.new(x, 0, -30), Vector3.new(3, 6, 2), C.Pink)
		Build.Box(model, cf * CFrame.new(x, 6, -30), Vector3.new(3.2, 1, 2.2), INK)
	end
	sign(model, cf * CFrame.new(0, 21, -47), Vector3.new(40, 5, 0.6), label, C.Lemon, C.Orange)
	hall(model, cf * CFrame.new(0, 0, 28), 50, 16, 30, Color3.fromRGB(255, 240, 220), 10)
	robPoint(model, (cf * CFrame.new(0, 0.4, 32)).Position, key)
end

local function donutPalace(c: Vector3)
	local model = folder("DonutPalace")
	local cf = facingCF(c + Vector3.new(0, 0, 40), SOUTH)
	hall(model, cf, 60, 18, 46, Color3.fromRGB(255, 200, 225), 14)
	sign(model, cf * CFrame.new(0, 14, -23.6), Vector3.new(40, 5, 0.6), "DONUT PALACE", Color3.fromRGB(255, 120, 170), Color3.new(1, 1, 1))
	-- Riesen-Donut auf dem Dach
	local center = cf * CFrame.new(0, 34, 0)
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local ball = Build.Part(model, {
			Size = Vector3.one * 9,
			Shape = Enum.PartType.Ball,
			CFrame = center * CFrame.new(math.cos(angle) * 11, math.sin(angle) * 11, 0),
			Color = if i % 2 == 0 then Color3.fromRGB(255, 120, 190) else Color3.fromRGB(255, 140, 200),
			CanCollide = false,
		})
		ball.Name = "Donut"
	end
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		Build.Part(model, {
			Size = Vector3.new(0.6, 0.6, 2.2),
			CFrame = center * CFrame.new(math.cos(angle) * 11, math.sin(angle) * 11, -4.6) * CFrame.Angles(0, 0, angle),
			Color = PASTELS[(i % #PASTELS) + 1],
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	Build.Box(model, cf * CFrame.new(0, 19.5, 0), Vector3.new(3, 8, 3), INK)
	robPoint(model, (cf * CFrame.new(0, 0.4, 14)).Position, "Donut")
	shopRow(model, facingCF(c + Vector3.new(0, 0, -50), NORTH), 4, 38)
end

local function policeStation(c: Vector3)
	local model = folder("Police")
	local cf = facingCF(c + Vector3.new(0, 0, -20), SOUTH)
	hall(model, cf, 90, 26, 60, Color3.fromRGB(235, 242, 255), 20)
	Build.Box(model, cf * CFrame.new(0, 22, -30.5), Vector3.new(90, 4, 1), C.Police)
	sign(model, cf * CFrame.new(0, 31, -26), Vector3.new(40, 8, 1), "POLICE", C.Police, Color3.new(1, 1, 1))
	for i, color in { Color3.fromRGB(255, 50, 50), Color3.fromRGB(50, 120, 255) } do
		local light = Build.Part(model, {
			Size = Vector3.new(4, 2, 4),
			CFrame = cf * CFrame.new((i - 1.5) * 10, 28, -20),
			Color = color,
			Material = Enum.Material.Neon,
		})
		light:AddTag("Siren")
	end
	-- Parkplatz
	for i = -3, 3 do
		Build.Box(model, cf * CFrame.new(i * 12, 0, -52), Vector3.new(0.6, 0.12, 14), Color3.new(1, 1, 1))
	end
	WorldService.Spawns.Police = (cf * CFrame.new(0, 0.4, 0)).Position
end

local function jail(c: Vector3)
	local model = folder("Jail")
	local half = 72
	local wallH = 34
	for _, s in { -1, 1 } do
		Build.Box(model, CFrame.new(c + Vector3.new(s * half, 0, 0)), Vector3.new(4, wallH, half * 2 + 4), Color3.fromRGB(150, 150, 165), Enum.Material.Concrete)
		Build.Box(model, CFrame.new(c + Vector3.new(0, 0, s * half)), Vector3.new(half * 2 + 4, wallH, 4), Color3.fromRGB(150, 150, 165), Enum.Material.Concrete)
		Build.Box(model, CFrame.new(c + Vector3.new(s * half, wallH, 0)), Vector3.new(5, 1.4, half * 2 + 6), C.Orange)
		Build.Box(model, CFrame.new(c + Vector3.new(0, wallH, s * half)), Vector3.new(half * 2 + 6, 1.4, 5), C.Orange)
	end
	-- unsichtbare Decke, damit niemand herausspringt
	Build.Part(model, { Size = Vector3.new(half * 2, 1, half * 2), CFrame = CFrame.new(c + Vector3.new(0, wallH + 4, 0)), Transparency = 1 })
	Build.Box(model, CFrame.new(c), Vector3.new(half * 2, 0.2, half * 2), Color3.fromRGB(190, 190, 200), Enum.Material.Concrete)
	sign(model, CFrame.new(c + Vector3.new(0, wallH - 8, half + 2.4)), Vector3.new(50, 10, 1), "CITY JAIL", C.Orange, Color3.new(1, 1, 1))
	-- Zellen an der Nordwand
	local cells = {}
	for i = -3, 3 do
		local x = c.X + i * 18
		local cellCF = CFrame.new(x, 0, c.Z - half + 14)
		Build.Box(model, cellCF * CFrame.new(-8.5, 0, 0), Vector3.new(1, 14, 22), Color3.fromRGB(170, 170, 185))
		for b = -3, 3 do
			Build.Part(model, {
				Size = Vector3.new(14, 0.7, 0.7),
				Shape = Enum.PartType.Cylinder,
				CFrame = CFrame.new(x + b * 2.2, 7, c.Z - half + 25) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(80, 80, 95),
				Material = Enum.Material.Metal,
			})
		end
		table.insert(cells, Vector3.new(x, 3, c.Z - half + 14))
	end
	Build.Box(model, CFrame.new(c.X + 3 * 18 + 9.5, 0, c.Z - half + 14), Vector3.new(1, 14, 22), Color3.fromRGB(170, 170, 185))
	-- Basketballkorb im Hof
	Build.Box(model, CFrame.new(c + Vector3.new(0, 0, 50)), Vector3.new(1.2, 14, 1.2), INK)
	Build.Box(model, CFrame.new(c + Vector3.new(0, 14, 50)), Vector3.new(10, 6, 0.6), Color3.new(1, 1, 1))
	WorldService.JailCenter = c
	WorldService.JailHalf = half - 3
	WorldService.JailCells = cells
	WorldService.JailExit = c + Vector3.new(0, 3, half + 14)
end

local function hideout(c: Vector3)
	local model = folder("Hideout")
	local cf = facingCF(c + Vector3.new(0, 0, -15), SOUTH)
	hall(model, cf, 90, 26, 70, Color3.fromRGB(70, 60, 90), 30)
	sign(model, cf * CFrame.new(0, 31, -32), Vector3.new(46, 9, 1), "HIDEOUT", C.Pink, C.Lemon)
	for i = -2, 2 do
		Build.Box(model, cf * CFrame.new(i * 16, 0.4, 20), Vector3.new(8, 6, 8), Color3.fromRGB(140, 100, 60), Enum.Material.WoodPlanks)
	end
	local pad = Build.Part(world, {
		Name = "CashInPad",
		Size = Vector3.new(30, 0.3, 24),
		CFrame = cf * CFrame.new(0, 0.55, -10),
		Color = C.Green,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.3,
	})
	Build.Billboard(pad, "CASH IN LOOT HERE", C.Green, 8, 120)
	WorldService.Hideout = pad
	WorldService.Spawns.Robbers = (cf * CFrame.new(0, 0.4, 12)).Position
end

-- Spray-Werkstatt: reinfahren und die Fahndungssterne verlieren (Update 2)
local function sprayShop(c: Vector3)
	local model = folder("SprayShop")
	local cf = facingCF(c + Vector3.new(0, 0, -10), SOUTH)
	hall(model, cf, 70, 24, 60, Color3.fromRGB(90, 80, 120), 30)
	sign(model, cf * CFrame.new(0, 27.5, -30.5), Vector3.new(46, 8, 1), "TURBO SPRAY", C.Teal, C.Lemon)
	for _, x in { -26, 26 } do
		Build.Box(model, cf * CFrame.new(x, 0.4, 2), Vector3.new(3, 14, 3), C.Pink)
		Build.Part(model, { Size = Vector3.new(2, 2, 2), CFrame = cf * CFrame.new(x * 0.88, 13, 2), Color = C.Lemon, Material = Enum.Material.Neon, CanCollide = false })
	end
	local pad = Build.Part(world, {
		Name = "SprayPad",
		Size = Vector3.new(30, 0.3, 34),
		CFrame = cf * CFrame.new(0, 0.6, 2),
		Color = C.Teal,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.4,
	})
	Build.Billboard(pad, "DRIVE IN: LOSE YOUR STARS", C.Teal, 12, 140)
	WorldService.SprayPad = pad
	local containerColors = { C.Orange, C.Teal, C.Pink, C.Lemon }
	for i = 0, 3 do
		Build.Box(model, CFrame.new(c + Vector3.new(-66 + i * 44, 0, 58)), Vector3.new(18, 9, 30), containerColors[i + 1], Enum.Material.DiamondPlate)
	end
end

local function industrial(c: Vector3)
	local model = folder("Industrial")
	local cf = facingCF(c + Vector3.new(0, 0, -30), SOUTH)
	Build.Box(model, cf, Vector3.new(110, 30, 70), Color3.fromRGB(180, 190, 200), Enum.Material.CorrodedMetal)
	for i = -1, 1 do
		Build.Box(model, cf * CFrame.new(i * 34, 0, -35.3), Vector3.new(20, 18, 0.6), C.Orange)
		for s = 1, 6 do
			Build.Box(model, cf * CFrame.new(i * 34, s * 3, -35.7), Vector3.new(20, 0.3, 0.3), INK)
		end
	end
	local containerColors = { C.Orange, C.Teal, C.Pink, Color3.fromRGB(90, 140, 255), C.Lemon }
	for i = 0, 5 do
		for level = 0, rng:NextInteger(0, 2) do
			Build.Box(model, CFrame.new(c + Vector3.new(-60 + i * 22, level * 9, 48)), Vector3.new(18, 9, 36), containerColors[rng:NextInteger(1, #containerColors)], Enum.Material.DiamondPlate)
		end
	end
end

local function dealership(c: Vector3)
	local model = folder("Dealership")
	local cf = facingCF(c + Vector3.new(0, 0, -10), NORTH)
	hall(model, cf, 120, 24, 80, Color3.fromRGB(255, 248, 231), 30, true)
	sign(model, cf * CFrame.new(0, 29, -40), Vector3.new(60, 9, 1), "TURBO MOTORS", C.Teal, C.Lemon)
	for i = -1, 1 do
		for _, z in { -10, 18 } do
			local podium = Build.Part(model, {
				Size = Vector3.new(1.2, 24, 24),
				Shape = Enum.PartType.Cylinder,
				CFrame = cf * CFrame.new(i * 36, 0.9, z) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(240, 240, 250),
			})
			podium:AddTag("SlowSpin")
			table.insert(WorldService.Showroom, cf * CFrame.new(i * 36, 1.5, z))
		end
	end
	local desk = Build.Box(model, cf * CFrame.new(0, 0.4, -30), Vector3.new(16, 4, 4), C.Orange)
	prompt(desk, "Browse Cars", "Turbo Motors", { OpenUI = "Garage" })
end

local function depot(c: Vector3)
	local model = folder("Depot")
	local cf = facingCF(c + Vector3.new(0, 0, -20), NORTH)
	hall(model, cf, 100, 28, 70, Color3.fromRGB(255, 225, 160), 36)
	sign(model, cf * CFrame.new(0, 33, -35), Vector3.new(56, 9, 1), "TURBO DELIVERY", C.Orange, Color3.new(1, 1, 1))
	for i = 1, 14 do
		Build.Box(model, cf * CFrame.new(rng:NextNumber(-40, 40), 0.4, rng:NextNumber(5, 30)), Vector3.new(5, 5, 5) * rng:NextNumber(0.7, 1.3), Color3.fromRGB(205, 160, 105), Enum.Material.Cardboard)
	end
	local desk = Build.Box(model, cf * CFrame.new(0, 0, -44), Vector3.new(14, 4, 4), C.Teal)
	sign(model, cf * CFrame.new(0, 7, -44), Vector3.new(14, 3, 0.4), "JOBS", C.Teal, Color3.new(1, 1, 1))
	prompt(desk, "Start Job", "Delivery Driver", { Job = "Delivery" })
	WorldService.Depot = desk
end

local function stuntPark(c: Vector3)
	local model = folder("StuntPark")
	Build.Box(model, CFrame.new(c), Vector3.new(156, 0.15, 156), Color3.fromRGB(70, 70, 90))
	for i = 1, 10 do
		Build.Box(model, CFrame.new(c + Vector3.new(rng:NextNumber(-70, 70), 0, rng:NextNumber(-70, 70))) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Vector3.new(rng:NextNumber(6, 20), 0.2, 2), PASTELS[(i % #PASTELS) + 1])
	end
	sign(model, CFrame.new(c + Vector3.new(0, 30, 74)), Vector3.new(60, 10, 1), "STUNT PARK", C.Pink, C.Lemon)
	for _, x in { -32, 32 } do
		Build.Box(model, CFrame.new(c + Vector3.new(x, 0, 74)), Vector3.new(2, 25, 2), INK)
	end
	for i, offset in { Vector3.new(-45, 0, 30), Vector3.new(0, 0, -20), Vector3.new(45, 0, 30) } do
		local pad = Build.Part(model, {
			Name = "JumpPad",
			Size = Vector3.new(16, 0.4, 16),
			CFrame = CFrame.new(c + offset + Vector3.new(0, 0.3, 0)),
			Color = if i == 2 then C.Pink else C.Lemon,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		pad:AddTag("JumpPad")
	end
end

local function suburbs(c: Vector3)
	local model = folder("Suburb")
	Build.Box(model, CFrame.new(c + Vector3.new(0, -0.05, 0)), Vector3.new(156, 0.2, 156), GRASS, Enum.Material.Grass)
	Build.Box(model, CFrame.new(c), Vector3.new(156, 0.25, 4), SIDEWALK)
	Build.Box(model, CFrame.new(c), Vector3.new(4, 0.25, 156), SIDEWALK)
	for _, dx in { -40, 40 } do
		for _, dz in { -40, 40 } do
			local center = c + Vector3.new(dx, 0, dz)
			local facing = if dz < 0 then NORTH else SOUTH
			table.insert(WorldService.Lots, facingCF(center, facing))
		end
	end
end

---------------------------------------------------------------- Stadtplan

local MAP = {
	{ "Jail", "Police", "Industrial", "Industrial", "Spray", "Hideout" },
	{ "Towers", "Towers", "Bank", "Towers", "Gems", "Towers" },
	{ "Towers", "Shops", "Plaza", "Towers", "Shops", "Gas" },
	{ "Towers", "Dealership", "Shops", "Depot", "Stunt", "Donut" },
	{ "Park", "Shops", "LowTowers", "Shops", "Park", "Shops" },
	{ "Suburbs", "Suburbs", "Suburbs", "Suburbs", "Suburbs", "Suburbs" },
}

local BUILDERS = {
	Jail = jail,
	Police = policeStation,
	Industrial = industrial,
	Hideout = hideout,
	Spray = sprayShop,
	Towers = function(c)
		towers(c, 50, 170)
	end,
	LowTowers = function(c)
		towers(c, 30, 70)
	end,
	Bank = bank,
	Gems = function(c)
		gemStore(c)
	end,
	Shops = shops,
	Plaza = plaza,
	Gas = function(c)
		gasStation(c, "Gas", "GAS 'N' GO")
	end,
	Dealership = dealership,
	Depot = depot,
	Stunt = stuntPark,
	Donut = donutPalace,
	Park = park,
	Suburbs = suburbs,
}

local function buildGround()
	local half = Config.CityHalf()
	local size = half * 2
	local ground = folder("Ground")
	-- Wiese ausserhalb der Stadt
	Build.Part(ground, { Name = "Grass", Size = Vector3.new(2400, 2, 2000), CFrame = CFrame.new(0, -1.6, -200), Color = GRASS, Material = Enum.Material.Grass })
	-- Strassen
	for k = 0, Config.Grid do
		local line = Config.RoadLine(k)
		Build.Part(ground, { Name = "Road", Size = Vector3.new(size, 1, Config.Road), CFrame = CFrame.new(0, -0.5, line), Color = ASPHALT, Material = Enum.Material.Asphalt })
		Build.Part(ground, { Name = "Road", Size = Vector3.new(Config.Road, 1, size), CFrame = CFrame.new(line, -0.5, 0), Color = ASPHALT, Material = Enum.Material.Asphalt })
	end
	-- Mittelstreifen (gestrichelt, nicht auf Kreuzungen)
	local markings = folder("Markings")
	for k = 0, Config.Grid do
		local line = Config.RoadLine(k)
		for b = 0, Config.Grid - 1 do
			local mid = Config.BlockCenter(b, 0).X
			for d = -60, 60, 24 do
				Build.Part(markings, { Size = Vector3.new(10, 0.1, 0.8), CFrame = CFrame.new(mid + d, 0.03, line), Color = C.Lemon, CanCollide = false, CanQuery = false })
				Build.Part(markings, { Size = Vector3.new(0.8, 0.1, 10), CFrame = CFrame.new(line, 0.03, mid + d), Color = C.Lemon, CanCollide = false, CanQuery = false })
			end
		end
	end
	-- Bloecke (Gehweg-Platten)
	for bx = 0, Config.Grid - 1 do
		for bz = 0, Config.Grid - 1 do
			local c = Config.BlockCenter(bx, bz)
			Build.Part(ground, { Name = "Block", Size = Vector3.new(Config.Block, 1, Config.Block), CFrame = CFrame.new(c.X, -0.5, c.Z), Color = SIDEWALK, Material = Enum.Material.Concrete })
		end
	end
	-- Strand und Meer im Sueden
	Build.Part(ground, { Name = "Beach", Size = Vector3.new(2400, 1, 200), CFrame = CFrame.new(0, -0.5, half + 100), Color = Color3.fromRGB(250, 225, 160), Material = Enum.Material.Sand })
	workspace.Terrain:FillBlock(CFrame.new(0, -12, half + 200 + 400), Vector3.new(2400, 20, 800), Enum.Material.Water)
	workspace.Terrain.WaterColor = Color3.fromRGB(40, 190, 210)
	workspace.Terrain.WaterTransparency = 0.6
	workspace.Terrain.WaterWaveSize = 0.15
	for x = -1100, 1100, 70 do
		local p = Vector3.new(x + rng:NextNumber(-15, 15), 0, half + 40 + rng:NextNumber(0, 60))
		local trunk = rng:NextNumber(16, 22)
		Build.Part(ground, {
			Size = Vector3.new(trunk, 1.4, 1.4),
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(p + Vector3.new(0, trunk / 2, 0)) * CFrame.Angles(0, 0, math.rad(84)),
			Color = Color3.fromRGB(160, 120, 80),
		})
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			Build.Part(ground, {
				Size = Vector3.new(9, 0.6, 2.6),
				CFrame = CFrame.new(p + Vector3.new(0, trunk, 0)) * CFrame.Angles(0, a, math.rad(-20)) * CFrame.new(4, 0, 0),
				Color = Color3.fromRGB(70, 180, 90),
				CanCollide = false,
			})
		end
	end
	-- Baeume rund um die Stadt
	for _ = 1, 90 do
		local side = rng:NextInteger(1, 3)
		local p
		if side == 1 then
			p = Vector3.new(rng:NextNumber(-1150, -half - 30), 0, rng:NextNumber(-1100, half))
		elseif side == 2 then
			p = Vector3.new(rng:NextNumber(half + 30, 1150), 0, rng:NextNumber(-1100, half))
		else
			p = Vector3.new(rng:NextNumber(-1150, 1150), 0, rng:NextNumber(-1150, -half - 30))
		end
		Build.Tree(ground, p + Vector3.new(0, -0.6, 0), rng)
	end
	-- Unsichtbare Grenzen
	for _, wall in {
		{ Vector3.new(4, 400, 2400), Vector3.new(-1180, 200, 0) },
		{ Vector3.new(4, 400, 2400), Vector3.new(1180, 200, 0) },
		{ Vector3.new(2400, 400, 4), Vector3.new(0, 200, -1180) },
		{ Vector3.new(2400, 400, 4), Vector3.new(0, 200, half + 260) },
	} do
		Build.Part(ground, { Name = "Boundary", Size = wall[1], CFrame = CFrame.new(wall[2]), Transparency = 1 })
	end
end

local function buildStreetDetails()
	local details = folder("Street")
	-- Laternen an den Blockecken
	for bx = 0, Config.Grid - 1 do
		for bz = 0, Config.Grid - 1 do
			local c = Config.BlockCenter(bx, bz)
			for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
				local p = c + corner * (Config.Block / 2 - 3)
				local outward = Vector3.new(corner.X, 0, 0)
				Build.Lamp(details, p, outward)
			end
			-- Lieferpunkte an allen vier Seiten
			if MAP[bz + 1][bx + 1] ~= "Jail" then
				for _, side in { NORTH, SOUTH, WEST, Vector3.new(1, 0, 0) } do
					table.insert(WorldService.DeliveryPoints, c + side * (Config.Block / 2 + 7))
				end
			end
		end
	end
	-- Boost-Streifen in der Mitte langer Strassenabschnitte
	local boosts = { { 0, 2, "z" }, { 6, 3, "z" }, { 2, 1, "x" }, { 4, 4, "x" }, { 6, 0, "x" }, { 0, 4, "x" }, { 3, 2, "z" }, { 1, 5, "z" } }
	for _, b in boosts do
		local line = Config.RoadLine(b[1])
		local mid = Config.BlockCenter(b[2], b[2]).X
		local position = if b[3] == "z" then Vector3.new(line, 0.08, mid) else Vector3.new(mid, 0.08, line)
		local alongZ = b[3] == "z"
		local pad = Build.Part(details, {
			Name = "BoostPad",
			Size = if alongZ then Vector3.new(20, 0.12, 26) else Vector3.new(26, 0.12, 20),
			CFrame = CFrame.new(position),
			Color = C.Teal,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
			CanCollide = false,
			CanQuery = false,
		})
		pad:AddTag("BoostPad")
	end
	-- Rennstrecke
	for _, point in Config.RaceRoute do
		table.insert(WorldService.RaceCheckpoints, Vector3.new(Config.RoadLine(point[1]), 0, Config.RoadLine(point[2])))
	end
	local start = Vector3.new(Config.RoadLine(Config.RaceStart[1]) + 30, 0, Config.RoadLine(Config.RaceStart[2]) + 30)
	local post = Build.Box(details, CFrame.new(start), Vector3.new(10, 6, 4), INK)
	sign(details, CFrame.new(start + Vector3.new(0, 12, 0)), Vector3.new(26, 7, 0.6), "CITY RACE", C.Lemon, C.Pink)
	prompt(post, "Start Race", "City Race", { Race = true })
	WorldService.RaceStart = post
	-- Start/Ziel-Bogen
	local gate = Vector3.new(Config.RoadLine(Config.RaceStart[1]), 0, Config.RoadLine(Config.RaceStart[2]))
	for _, s in { -1, 1 } do
		Build.Box(details, CFrame.new(gate + Vector3.new(s * 22, 0, 0)), Vector3.new(2, 24, 2), INK)
	end
	local banner = Build.Part(details, { Size = Vector3.new(46, 5, 1), CFrame = CFrame.new(gate + Vector3.new(0, 24, 0)), Color = Color3.new(1, 1, 1), CanCollide = false })
	Build.Sign(banner, "START / FINISH", Color3.new(1, 1, 1), INK, Enum.NormalId.Front)
	Build.Sign(banner, "START / FINISH", Color3.new(1, 1, 1), INK, Enum.NormalId.Back)
end

-- Blitzer an langen Geraden (Update 2)
local function buildSpeedCams()
	local cams = folder("SpeedCams")
	local spots = {
		{ Position = Vector3.new(Config.RoadLine(3), 0, Config.BlockCenter(0, 1).Z), Side = Vector3.new(1, 0, 0), Name = "Downtown" },
		{ Position = Vector3.new(Config.BlockCenter(4, 0).X, 0, Config.RoadLine(3)), Side = Vector3.new(0, 0, 1), Name = "Midtown" },
		{ Position = Vector3.new(Config.BlockCenter(1, 0).X, 0, Config.RoadLine(6)), Side = Vector3.new(0, 0, -1), Name = "Beach Road" },
		{ Position = Vector3.new(Config.RoadLine(6), 0, Config.BlockCenter(0, 4).Z), Side = Vector3.new(-1, 0, 0), Name = "East Side" },
	}
	for _, spot in spots do
		local base = spot.Position + spot.Side * (Config.Road / 2 + 3)
		Build.Box(cams, CFrame.new(base), Vector3.new(1, 14, 1), INK)
		local box = Build.Part(cams, {
			Size = Vector3.new(3, 2.4, 3),
			CFrame = CFrame.lookAt(base + Vector3.new(0, 14, 0), spot.Position + Vector3.new(0, 14, 0)),
			Color = C.Lemon,
		})
		Build.Part(cams, {
			Size = Vector3.new(1.2, 1.2, 0.4),
			CFrame = box.CFrame * CFrame.new(0, 0, -1.6),
			Color = C.Robber,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}):AddTag("Blink")
		Build.Billboard(box, "SPEED CAM", C.Lemon, 3, 160)
		table.insert(WorldService.SpeedCams, { Position = spot.Position, Name = spot.Name })
	end
end

-- Versteckte Turbo-Token (Update 2)
local function buildTokens()
	local tokens = folder("Tokens")
	local half = Config.CityHalf()
	local spots = {
		Config.BlockCenter(0, 4) + Vector3.new(-50, 3, -50), -- Park West
		Config.BlockCenter(4, 4) + Vector3.new(55, 3, 55), -- Park Ost
		Config.BlockCenter(4, 3) + Vector3.new(0, 20, -20), -- ueber der pinken Sprungschanze (nur mit dem Auto erreichbar)
		Config.BlockCenter(2, 2) + Vector3.new(13, 4, 15), -- Brunnen
		Vector3.new(-700, 3, half + 80), -- Strand
		Vector3.new(30, 3, half + 120),
		Vector3.new(650, 3, half + 70),
		Config.BlockCenter(5, 0) + Vector3.new(0, 3, -64), -- hinter dem Versteck
		Config.BlockCenter(0, 0) + Vector3.new(0, 3, -77), -- hinter dem Gefaengnis
		Config.BlockCenter(1, 3) + Vector3.new(70, 3, 70), -- Autohaus
		Config.BlockCenter(2, 0) + Vector3.new(0, 3, 17), -- Industrie
		Config.BlockCenter(5, 2) + Vector3.new(-30, 3, 7), -- Tankstelle
		Config.BlockCenter(2, 1) + Vector3.new(-70, 3, 70), -- Bank
		Config.BlockCenter(5, 3) + Vector3.new(72, 3, -76), -- Donut-Laden
		Vector3.new(0, 3, -half - 120), -- Wiese im Norden
	}
	for i, position in spots do
		local coin = Build.Part(tokens, {
			Name = "TurboToken",
			Size = Vector3.new(0.7, 4, 4),
			Shape = Enum.PartType.Cylinder,
			CFrame = CFrame.new(position),
			Color = Color3.fromRGB(255, 200, 40),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		})
		coin:SetAttribute("TokenId", i)
		coin:AddTag("Spin")
		coin:AddTag("TurboToken")
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(C.Lemon)
		sparkle.Size = NumberSequence.new(0.8, 0)
		sparkle.Rate = 6
		sparkle.Lifetime = NumberRange.new(0.8, 1.2)
		sparkle.Speed = NumberRange.new(2)
		sparkle.LightEmission = 1
		sparkle.Parent = coin
		table.insert(WorldService.Tokens, { Id = i, Position = position })
	end
end

local function setupLighting()
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 100, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 170)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(255, 210, 190)
	atmosphere.Decay = Color3.fromRGB(255, 140, 160)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 30
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(255, 248, 240)
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Parent = Lighting
end

local function setupTeams()
	local definitions = {
		{ Name = "Citizens", Color = BrickColor.new("Bright yellow") },
		{ Name = "Police", Color = BrickColor.new("Bright blue") },
		{ Name = "Robbers", Color = BrickColor.new("Bright red") },
	}
	for _, def in definitions do
		local team = Instance.new("Team")
		team.Name = def.Name
		team.TeamColor = def.Color
		team.AutoAssignable = def.Name == "Citizens"
		team.Parent = Teams
		WorldService.TeamObjects[def.Name] = team
		local spawnPosition = WorldService.Spawns[def.Name]
		if spawnPosition then
			local spawn = Instance.new("SpawnLocation")
			spawn.Name = def.Name .. "Spawn"
			spawn.Anchored = true
			spawn.Size = Vector3.new(14, 1, 14)
			spawn.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 0.5, 0))
			spawn.TeamColor = def.Color
			spawn.Neutral = false
			spawn.AllowTeamChangeOnTouch = false
			spawn.Duration = 0
			spawn.Color = def.Color.Color
			spawn.Material = Enum.Material.Neon
			spawn.Transparency = 0.5
			spawn.CanCollide = false
			spawn.TopSurface = Enum.SurfaceType.Smooth
			spawn.Parent = world
		end
	end
end

function WorldService:Init(services)
	self.Services = services
end

function WorldService:Build()
	world = Instance.new("Model")
	world.Name = "City"
	world.Parent = workspace
	setupLighting()
	buildGround()
	for bz = 0, Config.Grid - 1 do
		for bx = 0, Config.Grid - 1 do
			local kind = MAP[bz + 1][bx + 1]
			BUILDERS[kind](Config.BlockCenter(bx, bz))
		end
	end
	buildStreetDetails()
	buildSpeedCams()
	buildTokens()
	setupTeams()
end

function WorldService.IsInJail(position: Vector3): boolean
	local offset = position - WorldService.JailCenter
	return math.abs(offset.X) < WorldService.JailHalf and math.abs(offset.Z) < WorldService.JailHalf and offset.Y < 40
end

function WorldService.NearestRoadPoint(position: Vector3): (Vector3, Vector3)
	local half = Config.CityHalf()
	local x = math.clamp(position.X, -half + 10, half - 10)
	local z = math.clamp(position.Z, -half + 10, half - 10)
	local step = Config.Block + Config.Road
	local kx = math.clamp(math.round((x - Config.RoadLine(0)) / step), 0, Config.Grid)
	local kz = math.clamp(math.round((z - Config.RoadLine(0)) / step), 0, Config.Grid)
	local roadX = Config.RoadLine(kx)
	local roadZ = Config.RoadLine(kz)
	-- Naeher an einer Nord-Sued-Strasse oder einer Ost-West-Strasse?
	if math.abs(x - roadX) < math.abs(z - roadZ) then
		return Vector3.new(roadX + 9 * (if x >= roadX then 1 else -1), 0, z), Vector3.new(0, 0, if z >= 0 then -1 else 1)
	end
	return Vector3.new(x, 0, roadZ + 9 * (if z >= roadZ then 1 else -1)), Vector3.new(if x >= 0 then -1 else 1, 0, 0)
end

function WorldService:Start()
	-- Tag-Nacht-Zyklus: ein Tag = 16 Minuten
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			Lighting.ClockTime = (Lighting.ClockTime + (now - last) * 24 / 960) % 24
			last = now
		end
	end)
end

return WorldService
