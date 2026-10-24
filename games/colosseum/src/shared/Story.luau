-- Die Welt Valoria und ihre Geschichte: Orte, Routen, Trainer, Arenaleiter, Top Vier, Rivale,
-- Team Eclipse und legendaere Bestien. Wird von Server (Aufbau, Kaempfe) und Client (Karte, Ziele) genutzt.

local Story = {}

---------------------------------------------------------------- Aussehen von Personen

-- Skin, Shirt, Pants, Hair (Farben), Hat = Farbe oder nil, Cape = Farbe oder nil
local function look(skin: Color3, shirt: Color3, pants: Color3, hair: Color3, hat: Color3?, cape: Color3?)
	return { Skin = skin, Shirt = shirt, Pants = pants, Hair = hair, Hat = hat, Cape = cape }
end
local LIGHT = Color3.fromRGB(240, 200, 170)
local TAN = Color3.fromRGB(214, 160, 120)
local DARK = Color3.fromRGB(140, 95, 65)
local ECLIPSE = Color3.fromRGB(40, 30, 55)
local ECLIPSE_TRIM = Color3.fromRGB(150, 60, 200)

Story.Looks = {
	Professor = look(LIGHT, Color3.fromRGB(245, 245, 240), Color3.fromRGB(80, 90, 110), Color3.fromRGB(200, 200, 205), nil, Color3.fromRGB(245, 245, 240)),
	Rival = look(TAN, Color3.fromRGB(40, 110, 200), Color3.fromRGB(40, 40, 50), Color3.fromRGB(230, 110, 40), Color3.fromRGB(230, 60, 60)),
	Nurse = look(LIGHT, Color3.fromRGB(255, 190, 210), Color3.fromRGB(255, 255, 255), Color3.fromRGB(240, 120, 150), Color3.fromRGB(255, 255, 255)),
	Clerk = look(TAN, Color3.fromRGB(60, 120, 210), Color3.fromRGB(50, 50, 60), Color3.fromRGB(60, 40, 30), Color3.fromRGB(60, 120, 210)),
	Guard = look(DARK, Color3.fromRGB(60, 80, 140), Color3.fromRGB(40, 50, 80), Color3.fromRGB(30, 25, 20), Color3.fromRGB(40, 50, 90)),
	Villager = look(LIGHT, Color3.fromRGB(120, 180, 90), Color3.fromRGB(90, 70, 50), Color3.fromRGB(120, 80, 40)),
	Villager2 = look(DARK, Color3.fromRGB(230, 170, 60), Color3.fromRGB(70, 70, 90), Color3.fromRGB(30, 25, 20)),
	Kid = look(TAN, Color3.fromRGB(240, 90, 90), Color3.fromRGB(60, 90, 160), Color3.fromRGB(50, 35, 25), Color3.fromRGB(240, 200, 60)),
	Lass = look(LIGHT, Color3.fromRGB(250, 150, 190), Color3.fromRGB(250, 250, 250), Color3.fromRGB(240, 210, 120)),
	Hiker = look(DARK, Color3.fromRGB(150, 110, 70), Color3.fromRGB(90, 80, 60), Color3.fromRGB(60, 40, 30), Color3.fromRGB(110, 140, 70)),
	Fisher = look(TAN, Color3.fromRGB(80, 160, 200), Color3.fromRGB(60, 70, 90), Color3.fromRGB(80, 60, 40), Color3.fromRGB(240, 220, 120)),
	Scientist = look(LIGHT, Color3.fromRGB(240, 240, 245), Color3.fromRGB(70, 70, 80), Color3.fromRGB(90, 60, 120)),
	Ace = look(TAN, Color3.fromRGB(200, 40, 50), Color3.fromRGB(30, 30, 40), Color3.fromRGB(30, 25, 20), nil, Color3.fromRGB(240, 190, 60)),
	Skier = look(LIGHT, Color3.fromRGB(80, 200, 230), Color3.fromRGB(60, 60, 140), Color3.fromRGB(250, 240, 200), Color3.fromRGB(240, 80, 80)),
	Mystic = look(LIGHT, Color3.fromRGB(110, 60, 160), Color3.fromRGB(60, 40, 80), Color3.fromRGB(30, 20, 40), Color3.fromRGB(110, 60, 160)),
	Firebreather = look(DARK, Color3.fromRGB(240, 100, 40), Color3.fromRGB(80, 40, 30), Color3.fromRGB(20, 20, 20)),
	Grunt = look(TAN, ECLIPSE, ECLIPSE, Color3.fromRGB(30, 25, 30), ECLIPSE_TRIM),
	Admin = look(LIGHT, ECLIPSE, ECLIPSE, Color3.fromRGB(180, 60, 200), nil, ECLIPSE_TRIM),
	Boss = look(LIGHT, Color3.fromRGB(20, 15, 30), Color3.fromRGB(20, 15, 30), Color3.fromRGB(230, 230, 240), nil, Color3.fromRGB(120, 40, 170)),
	Rocco = look(DARK, Color3.fromRGB(160, 130, 90), Color3.fromRGB(80, 70, 60), Color3.fromRGB(30, 25, 20), nil, Color3.fromRGB(120, 100, 70)),
	Marina = look(LIGHT, Color3.fromRGB(60, 150, 230), Color3.fromRGB(240, 240, 250), Color3.fromRGB(40, 60, 120), nil, Color3.fromRGB(60, 150, 230)),
	Fern = look(TAN, Color3.fromRGB(90, 190, 90), Color3.fromRGB(110, 80, 50), Color3.fromRGB(200, 120, 60), Color3.fromRGB(255, 140, 180)),
	Vera = look(LIGHT, Color3.fromRGB(250, 210, 40), Color3.fromRGB(40, 40, 50), Color3.fromRGB(250, 250, 250), nil, Color3.fromRGB(250, 210, 40)),
	Aria = look(LIGHT, Color3.fromRGB(170, 220, 250), Color3.fromRGB(240, 240, 250), Color3.fromRGB(120, 160, 230), nil, Color3.fromRGB(170, 220, 250)),
	Ignis = look(DARK, Color3.fromRGB(220, 60, 30), Color3.fromRGB(60, 30, 25), Color3.fromRGB(240, 120, 30), nil, Color3.fromRGB(255, 140, 40)),
	Garrick = look(LIGHT, Color3.fromRGB(70, 40, 110), Color3.fromRGB(30, 20, 40), Color3.fromRGB(20, 15, 25), nil, Color3.fromRGB(40, 20, 60)),
	Glacia = look(LIGHT, Color3.fromRGB(200, 240, 255), Color3.fromRGB(150, 200, 240), Color3.fromRGB(240, 250, 255), nil, Color3.fromRGB(150, 220, 255)),
	Lumen = look(LIGHT, Color3.fromRGB(255, 240, 180), Color3.fromRGB(255, 250, 230), Color3.fromRGB(255, 220, 120), nil, Color3.fromRGB(255, 220, 100)),
	Bea = look(TAN, Color3.fromRGB(200, 80, 60), Color3.fromRGB(70, 60, 50), Color3.fromRGB(90, 50, 30), Color3.fromRGB(240, 190, 60)),
	Coral = look(TAN, Color3.fromRGB(30, 90, 170), Color3.fromRGB(240, 240, 240), Color3.fromRGB(240, 240, 240), Color3.fromRGB(30, 50, 100), Color3.fromRGB(30, 90, 170)),
	Draven = look(DARK, Color3.fromRGB(50, 40, 60), Color3.fromRGB(30, 25, 35), Color3.fromRGB(180, 40, 40), nil, Color3.fromRGB(180, 40, 40)),
	Maximus = look(TAN, Color3.fromRGB(230, 180, 70), Color3.fromRGB(150, 28, 40), Color3.fromRGB(40, 30, 20), Color3.fromRGB(230, 180, 70), Color3.fromRGB(150, 28, 40)),
}

---------------------------------------------------------------- Orte

-- Kind: Town oder Route. Staedte haben feste Mittelpunkte, Routen verbinden zwei Staedte.
-- Theme: Ground/Material (Boden), Accent (Schilder, Daecher), Trees (Baumart)
local function theme(ground: Color3, material: Enum.Material, accent: Color3, trees: string, roof: Color3?)
	return { Ground = ground, Material = material, Accent = accent, Trees = trees, Roof = roof or accent }
end

Story.TownSize = 140
Story.RouteWidth = 80

Story.Areas = {
	{ Id = "dawnvale", Name = "Dawnvale Town", Kind = "Town", Center = Vector3.new(0, 0, 0), Theme = theme(Color3.fromRGB(120, 185, 90), Enum.Material.Grass, Color3.fromRGB(230, 120, 70), "Oak"), Lab = true },
	{ Id = "route1", Name = "Route 1", Kind = "Route", From = "dawnvale", To = "pebbleton", Levels = { 2, 5 }, Theme = theme(Color3.fromRGB(110, 180, 85), Enum.Material.Grass, Color3.fromRGB(230, 120, 70), "Oak"), Wild = {
		{ "nibbit", 40 }, { "pipwing", 35 }, { "glimmoth", 15 }, { "zapkit", 10 },
	} },
	{ Id = "pebbleton", Name = "Pebbleton", Kind = "Town", Center = Vector3.new(0, 0, -400), Theme = theme(Color3.fromRGB(165, 150, 115), Enum.Material.Ground, Color3.fromRGB(150, 110, 70), "Pine") },
	{ Id = "route2", Name = "Route 2", Kind = "Route", From = "pebbleton", To = "coralport", Levels = { 5, 9 }, Theme = theme(Color3.fromRGB(125, 175, 95), Enum.Material.Grass, Color3.fromRGB(80, 160, 220), "Oak"), Wild = {
		{ "nibbit", 18 }, { "pipwing", 18 }, { "pebblit", 18 }, { "finnow", 18 }, { "voltbug", 14 }, { "mossbun", 10 }, { "zapkit", 4 },
	} },
	{ Id = "coralport", Name = "Coralport", Kind = "Town", Center = Vector3.new(0, 0, -800), Theme = theme(Color3.fromRGB(235, 215, 160), Enum.Material.Sand, Color3.fromRGB(60, 150, 230), "Palm") },
	{ Id = "route3", Name = "Route 3", Kind = "Route", From = "coralport", To = "bloomfield", Levels = { 10, 15 }, Theme = theme(Color3.fromRGB(130, 190, 90), Enum.Material.Grass, Color3.fromRGB(90, 190, 90), "Oak"), Wild = {
		{ "finnow", 18 }, { "pebblit", 12 }, { "cragmole", 16 }, { "glimmoth", 14 }, { "hexbat", 16 }, { "mossbun", 16 }, { "puddlit", 4 }, { "sproutling", 4 },
	} },
	{ Id = "bloomfield", Name = "Bloomfield", Kind = "Town", Center = Vector3.new(400, 0, -800), Theme = theme(Color3.fromRGB(120, 200, 95), Enum.Material.Grass, Color3.fromRGB(240, 120, 170), "Blossom") },
	{ Id = "route4", Name = "Route 4", Kind = "Route", From = "bloomfield", To = "voltara", Levels = { 15, 20 }, Theme = theme(Color3.fromRGB(140, 175, 100), Enum.Material.Grass, Color3.fromRGB(250, 210, 40), "Oak"), Wild = {
		{ "voltbug", 20 }, { "zapkit", 14 }, { "breezlet", 16 }, { "hexbat", 14 }, { "cragmole", 14 }, { "mossbun", 12 }, { "skyhawk", 6 }, { "cindercub", 4 },
	} },
	{ Id = "voltara", Name = "Voltara City", Kind = "Town", Center = Vector3.new(400, 0, -400), Theme = theme(Color3.fromRGB(170, 170, 175), Enum.Material.Concrete, Color3.fromRGB(250, 210, 40), "Lamp") },
	{ Id = "route5", Name = "Route 5", Kind = "Route", From = "voltara", To = "skyreach", Levels = { 20, 25 }, Theme = theme(Color3.fromRGB(150, 200, 120), Enum.Material.Grass, Color3.fromRGB(150, 205, 245), "Pine"), Wild = {
		{ "breezlet", 22 }, { "scorchling", 12 }, { "voltlynx", 8 }, { "bouldergrub", 12 }, { "sunnybun", 8 }, { "finnow", 12 }, { "lumiwing", 10 }, { "skyhawk", 12 }, { "puddlit", 4 },
	} },
	{ Id = "skyreach", Name = "Skyreach", Kind = "Town", Center = Vector3.new(400, 0, 0), Theme = theme(Color3.fromRGB(200, 225, 200), Enum.Material.Grass, Color3.fromRGB(110, 180, 235), "Pine") },
	{ Id = "route6", Name = "Route 6", Kind = "Route", From = "skyreach", To = "cinderpeak", Levels = { 25, 30 }, Theme = theme(Color3.fromRGB(150, 140, 100), Enum.Material.Ground, Color3.fromRGB(240, 110, 50), "Dead"), Wild = {
		{ "scorchling", 22 }, { "bouldergrub", 14 }, { "galewing", 10 }, { "quarrok", 10 }, { "shadewisp", 14 }, { "sunnybun", 8 }, { "cragmole", 14 }, { "cindercub", 4 }, { "zapkit", 4 },
	} },
	{ Id = "cinderpeak", Name = "Cinderpeak", Kind = "Town", Center = Vector3.new(800, 0, 0), Theme = theme(Color3.fromRGB(95, 70, 60), Enum.Material.Basalt, Color3.fromRGB(255, 100, 40), "Dead") },
	{ Id = "route7", Name = "Route 7", Kind = "Route", From = "cinderpeak", To = "duskhollow", Levels = { 30, 35 }, Theme = theme(Color3.fromRGB(100, 110, 90), Enum.Material.Grass, Color3.fromRGB(150, 80, 220), "Dead"), Wild = {
		{ "shadewisp", 18 }, { "duskmaw", 8 }, { "gloomwing", 12 }, { "frostkit", 12 }, { "snowpuff", 8 }, { "galewing", 10 }, { "tidefin", 10 }, { "magmarok", 6 }, { "thornback", 10 }, { "sproutling", 3 }, { "puddlit", 3 },
	} },
	{ Id = "duskhollow", Name = "Duskhollow", Kind = "Town", Center = Vector3.new(800, 0, -400), Theme = theme(Color3.fromRGB(80, 70, 95), Enum.Material.Slate, Color3.fromRGB(160, 90, 255), "Dead") },
	{ Id = "route8", Name = "Route 8", Kind = "Route", From = "duskhollow", To = "frostholm", Levels = { 35, 40 }, Theme = theme(Color3.fromRGB(225, 235, 240), Enum.Material.Snow, Color3.fromRGB(140, 210, 255), "Snow"), Wild = {
		{ "frostkit", 18 }, { "snowpuff", 14 }, { "glaciat", 10 }, { "gloomwing", 10 }, { "torrentail", 10 }, { "voltlynx", 10 }, { "duskmaw", 10 }, { "quarrok", 10 }, { "lumiwing", 8 },
	} },
	{ Id = "frostholm", Name = "Frostholm", Kind = "Town", Center = Vector3.new(800, 0, -800), Theme = theme(Color3.fromRGB(235, 240, 245), Enum.Material.Snow, Color3.fromRGB(110, 190, 240), "Snow") },
	{ Id = "victory", Name = "Champion Road", Kind = "Route", From = "frostholm", To = "league", Levels = { 40, 48 }, Theme = theme(Color3.fromRGB(150, 135, 110), Enum.Material.Ground, Color3.fromRGB(240, 190, 60), "Pine"), Wild = {
		{ "glaciat", 12 }, { "quarrok", 12 }, { "duskmaw", 12 }, { "thundermane", 5 }, { "galewing", 12 }, { "magmarok", 10 }, { "torrentail", 10 }, { "titanshell", 5 }, { "nightreign", 4 }, { "solarion", 4 }, { "tempestrix", 6 }, { "joltbeetle", 8 },
	} },
	{ Id = "league", Name = "Colosseum League", Kind = "Town", Center = Vector3.new(1220, 0, -800), Size = 220, Theme = theme(Color3.fromRGB(200, 185, 155), Enum.Material.Cobblestone, Color3.fromRGB(230, 180, 70), "Pine"), League = true },
}

Story.AreasById = {}
for index, area in Story.Areas do
	area.Index = index
	Story.AreasById[area.Id] = area
end

-- Geometrie: Mittelpunkt und Groesse (X, Z) jedes Ortes, Richtung der Routen
for _, area in Story.Areas do
	if area.Kind == "Town" then
		local size = area.Size or Story.TownSize
		area.Rect = { Center = area.Center, SizeX = size, SizeZ = size }
	end
end
for _, area in Story.Areas do
	if area.Kind == "Route" then
		local from = Story.AreasById[area.From]
		local to = Story.AreasById[area.To]
		local delta = to.Center - from.Center
		local dir = delta.Unit
		local startEdge = from.Center + dir * (from.Rect.SizeX / 2)
		local endEdge = to.Center - dir * (to.Rect.SizeX / 2)
		local length = (endEdge - startEdge).Magnitude
		local alongX = math.abs(dir.X) > 0.5
		area.Dir = dir
		area.Side = Vector3.new(-dir.Z, 0, dir.X)
		area.Start = startEdge
		area.Length = length
		local center = (startEdge + endEdge) / 2
		area.Rect = { Center = center, SizeX = if alongX then length else Story.RouteWidth, SizeZ = if alongX then Story.RouteWidth else length }
		area.Center = center
	end
end

-- Punkt auf einer Route: a = Anteil der Laenge (0..1), c = seitlicher Versatz in Studs
function Story.RoutePoint(area, a: number, c: number): Vector3
	return area.Start + area.Dir * (area.Length * a) + area.Side * c
end

-- Hohes Gras einer Route: Rechtecke in Routen-Koordinaten { A (0..1), C, Along, Across }
function Story.GrassPatches(area)
	local patches = {}
	if area.Kind ~= "Route" then
		return patches
	end
	local count = math.max(3, math.floor(area.Length / 55))
	for i = 1, count do
		local a = (i - 0.5) / count
		if i == math.ceil(count / 2) then
			-- quer ueber den ganzen Weg: hier muss jeder durch das Gras
			table.insert(patches, { A = a, C = 0, Along = 26, Across = Story.RouteWidth - 12 })
		else
			local side = if i % 2 == 0 then 1 else -1
			table.insert(patches, { A = a, C = side * 20, Along = 36, Across = 30 })
		end
	end
	return patches
end

-- In welchem Ort liegt eine Position?
function Story.AreaAt(position: Vector3)
	for _, area in Story.Areas do
		local rect = area.Rect
		local d = position - rect.Center
		if math.abs(d.X) <= rect.SizeX / 2 and math.abs(d.Z) <= rect.SizeZ / 2 then
			return area
		end
	end
	return nil
end

-- Liegt die Position im hohen Gras dieser Route?
function Story.InGrass(area, position: Vector3): boolean
	if not area or area.Kind ~= "Route" then
		return false
	end
	local rel = position - area.Start
	local along = rel:Dot(area.Dir)
	local across = rel:Dot(area.Side)
	for _, patch in Story.GrassPatches(area) do
		if math.abs(along - patch.A * area.Length) <= patch.Along / 2 and math.abs(across - patch.C) <= patch.Across / 2 then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- Staedte: Gebaeude

-- Gebaeude liegen in den vier Vierteln einer Stadt (Kreuzung der Strassen in der Mitte bleibt frei).
-- Quadrant: { X = -1/1, Z = -1/1 }
Story.TownLayout = {
	Arena = { X = 1, Z = -1 },
	Center = { X = -1, Z = 1 },
	Mart = { X = 1, Z = 1 },
	Houses = { X = -1, Z = -1 },
}

---------------------------------------------------------------- Arenaleiter

-- Requires: Flag, das vorher noetig ist (Team Eclipse blockiert manche Arenen)
Story.Leaders = {
	{ Id = "leader1", Town = "pebbleton", Name = "Rocco", Type = "Stone", Badge = "Pebble Badge", Look = "Rocco", Coins = 1_800, Items = { GreatOrb = 3 },
		Team = { { "pebblit", 12 }, { "cragmole", 12 }, { "bouldergrub", 14 } },
		Lines = { "So you want to challenge me? My Stone beasts are as solid as a mountain!", "Show me how hard you can hit!" },
		Defeat = { "Hah! You cracked my rock-hard defense!", "Take the Pebble Badge. Coralport is waiting south of here." } },
	{ Id = "leader2", Town = "coralport", Name = "Marina", Type = "Water", Badge = "Wave Badge", Look = "Marina", Coins = 2_600, Items = { SuperPotion = 2 },
		Team = { { "finnow", 17 }, { "puddlit", 18 }, { "tidefin", 20 } },
		Lines = { "The tide waits for no one! Let's make a splash!" },
		Defeat = { "You swept me away like a wave!", "The Wave Badge is yours. Head east to Bloomfield." } },
	{ Id = "leader3", Town = "bloomfield", Name = "Fern", Type = "Leaf", Badge = "Bloom Badge", Look = "Fern", Coins = 3_400, Items = { Revive = 1 },
		Team = { { "mossbun", 22 }, { "sproutling", 23 }, { "verdibun", 25 } },
		Lines = { "Welcome to my garden! Every flower here has thorns..." },
		Defeat = { "Your team has bloomed beautifully!", "Here is the Bloom Badge. Something strange is happening in Voltara City..." } },
	{ Id = "leader4", Town = "voltara", Name = "Vera", Type = "Spark", Badge = "Volt Badge", Look = "Vera", Coins = 4_200, Items = { RoyalOrb = 2 }, Requires = "eclipse1",
		Team = { { "voltbug", 27 }, { "zapkit", 28 }, { "joltbeetle", 28 }, { "voltlynx", 30 } },
		Lines = { "Thanks for chasing Team Eclipse out of my city!", "But in here, I won't hold back. Feel the shock!" },
		Defeat = { "Zzzap! What a shocking finish!", "The Volt Badge is yours. Skyreach is up north." } },
	{ Id = "leader5", Town = "skyreach", Name = "Aria", Type = "Wind", Badge = "Gale Badge", Look = "Aria", Coins = 5_000, Items = { HyperPotion = 2 },
		Team = { { "skyhawk", 32 }, { "breezlet", 33 }, { "gloomwing", 33 }, { "galewing", 35 } },
		Lines = { "Up here the wind decides who wins. Let's see if it likes you!" },
		Defeat = { "You flew higher than me!", "Take the Gale Badge. Cinderpeak lies to the east." } },
	{ Id = "leader6", Town = "cinderpeak", Name = "Ignis", Type = "Fire", Badge = "Ember Badge", Look = "Ignis", Coins = 6_000, Items = { RoyalOrb = 3 },
		Team = { { "scorchling", 37 }, { "blazehound", 38 }, { "cindercub", 37 }, { "magmarok", 40 } },
		Lines = { "My fire has burned for 40 years. Can your spirit burn brighter?" },
		Defeat = { "Your flame outshines mine!", "The Ember Badge is yours. Be careful in Duskhollow, I hear rumors of Team Eclipse." } },
	{ Id = "leader7", Town = "duskhollow", Name = "Garrick", Type = "Shadow", Badge = "Shade Badge", Look = "Garrick", Coins = 7_000, Items = { HyperPotion = 3 }, Requires = "eclipse2",
		Team = { { "shadewisp", 42 }, { "gloomwing", 43 }, { "duskmaw", 43 }, { "nightreign", 45 } },
		Lines = { "You stopped Nyx. I am impressed.", "Now face the shadows themselves!" },
		Defeat = { "The night bows to you.", "The Shade Badge is yours. Only Frostholm remains." } },
	{ Id = "leader8", Town = "frostholm", Name = "Glacia", Type = "Frost", Badge = "Glacier Badge", Look = "Glacia", Coins = 8_000, Items = { RoyalOrb = 5 },
		Team = { { "snowpuff", 47 }, { "glaciat", 48 }, { "abyssaur", 48 }, { "blizzaurus", 50 } },
		Lines = { "Seven badges... Then you are ready to freeze!" },
		Defeat = { "My ice... melted.", "The Glacier Badge is yours. Champion Road leads to the Colosseum League!" } },
}

-- Die Top Vier und der Champion im Kolosseum (nacheinander)
Story.Elite = {
	{ Id = "elite1", Name = "Lumen", Title = "Grand Four", Look = "Lumen", Coins = 9_000,
		Team = { { "lumiwing", 52 }, { "sunnybun", 53 }, { "snowpuff", 53 }, { "solarion", 55 } },
		Lines = { "Welcome to the Colosseum League. I am Lumen of the Grand Four.", "Let the light judge you!" },
		Defeat = { "Your light is brighter than mine. Go on." } },
	{ Id = "elite2", Name = "Bea", Title = "Grand Four", Look = "Bea", Coins = 9_500,
		Team = { { "burrowbun", 53 }, { "tempestrix", 54 }, { "quarrok", 54 }, { "titanshell", 56 } },
		Lines = { "I'm Bea! I fought my way up from the sand pits.", "Show me your guts!" },
		Defeat = { "What a brawl! You earned it." } },
	{ Id = "elite3", Name = "Coral", Title = "Grand Four", Look = "Coral", Coins = 10_000,
		Team = { { "torrentail", 55 }, { "tidefin", 55 }, { "blizzaurus", 56 }, { "abyssaur", 57 } },
		Lines = { "Captain Coral, at your service. The sea is calm today... for now." },
		Defeat = { "You sank my whole fleet!" } },
	{ Id = "elite4", Name = "Draven", Title = "Grand Four", Look = "Draven", Coins = 11_000,
		Team = { { "magmarok", 56 }, { "galewing", 56 }, { "nightreign", 57 }, { "infernox", 58 } },
		Lines = { "I am Draven, the last of the Grand Four. My beasts are the fiercest in Valoria!" },
		Defeat = { "Impossible... Go. The Champion awaits." } },
	{ Id = "champion", Name = "Maximus", Title = "Champion", Look = "Maximus", Coins = 30_000,
		Team = { { "tempestrix", 60 }, { "thundermane", 60 }, { "verdantusk", 61 }, { "titanshell", 61 }, { "abyssaur", 61 }, { "infernox", 63 } },
		Lines = { "So you are the one everyone is talking about.", "I am Emperor Maximus, Champion of the Colosseum!", "The crowd is roaring. Let's give them a battle they will never forget!" },
		Defeat = { "...Incredible. The crowd chants your name.", "From today, YOU are the Champion of Valoria!" } },
}

---------------------------------------------------------------- Rivale Kai

-- Kai waehlt immer den Starter mit Element-Vorteil gegen deinen
Story.RivalStarter = { cindercub = "puddlit", puddlit = "sproutling", sproutling = "cindercub" }
local STAGES = {
	cindercub = { "cindercub", "blazehound", "infernox" },
	puddlit = { "puddlit", "tidefin", "abyssaur" },
	sproutling = { "sproutling", "thornback", "verdantusk" },
}

function Story.RivalTeam(stage: number, playerStarter: string?): { { any } }
	local starter = Story.RivalStarter[playerStarter or "cindercub"] or "puddlit"
	local line = STAGES[starter]
	if stage == 1 then
		return { { line[1], 5 } }
	elseif stage == 2 then
		return { { "pipwing", 10 }, { line[1], 12 } }
	elseif stage == 3 then
		return { { "skyhawk", 24 }, { "zapkit", 23 }, { "finnow", 24 }, { line[2], 27 } }
	end
	return { { "tempestrix", 50 }, { "thundermane", 50 }, { "torrentail", 50 }, { "quarrok", 51 }, { line[3], 54 } }
end

Story.RivalLines = {
	{ Before = { "Hey! Wait up! I'm Kai, your neighbor. Remember me?", "We both got our first beast today... so let's battle right now!" }, After = { "Okay, okay! Next time I'll win for sure!" } },
	{ Before = { "There you are! I've been training nonstop.", "Let's see who got stronger!" }, After = { "Argh! I'll catch up, just wait!" } },
	{ Before = { "I beat the Voltara Arena too, you know!", "My team is unstoppable now!" }, After = { "You're really good... but I'm not giving up!" } },
	{ Before = { "This is it. Champion Road. Only one of us goes to the League today!", "Give it everything you've got!" }, After = { "...You won. Fair and square.", "Go win the League. You're the best tamer I know." } },
}

---------------------------------------------------------------- Trainer

-- Route-Trainer: A = Anteil der Route, Side = Seite (-1/1). Gegner starten den Kampf, wenn sie dich sehen.
-- Area kann auch eine Stadt sein (Pos = Versatz zur Stadtmitte, Face = Blickrichtung).
local function trainer(id: string, area: string, a: number, side: number, class: string, name: string, lookKey: string, team, lines, defeat, extra: any?)
	local t = { Id = id, Area = area, A = a, Side = side, Class = class, Name = name, Look = lookKey, Team = team, Lines = lines, Defeat = defeat, Sight = 22 }
	for key, value in extra or {} do
		t[key] = value
	end
	return t
end

Story.Trainers = {
	trainer("r1a", "route1", 0.3, 1, "Rookie", "Tim", "Kid", { { "nibbit", 3 } }, { "I just got my first beast! Let's battle!" }, { "Aww, I lost..." }),
	trainer("r1b", "route1", 0.75, -1, "Lass", "Mia", "Lass", { { "pipwing", 3 }, { "nibbit", 4 } }, { "You looked at me! That means we battle!" }, { "My hair is ruined..." }),

	trainer("r2a", "route2", 0.2, 1, "Camper", "Leo", "Villager", { { "pebblit", 7 }, { "nibbit", 7 } }, { "Camping teaches you patience. Battling teaches you courage!" }, { "Time to pack up my tent." }),
	trainer("r2b", "route2", 0.45, -1, "Fisher", "Dan", "Fisher", { { "finnow", 8 }, { "finnow", 8 } }, { "No fish today, but I caught you!" }, { "The big one got away... again." }),
	trainer("rival2", "route2", 0.7, 1, "Rival", "Kai", "Rival", nil, nil, nil, { Rival = 2, Flag = "rival2" }),
	trainer("r2c", "route2", 0.88, -1, "Bug Kid", "Ollie", "Kid", { { "voltbug", 8 }, { "voltbug", 9 } }, { "My Voltbugs glow when they're excited!" }, { "They glow less now..." }),

	trainer("r3a", "route3", 0.25, 1, "Hiker", "Gus", "Hiker", { { "pebblit", 13 }, { "cragmole", 14 } }, { "Rocks are my best friends!" }, { "Crushed like gravel!" }),
	trainer("r3b", "route3", 0.6, -1, "Lass", "Nora", "Lass", { { "glimmoth", 13 }, { "mossbun", 14 } }, { "Do you like cute beasts? Mine are the cutest!" }, { "Cute AND strong... you, I mean." }),
	trainer("r3c", "route3", 0.85, 1, "Bird Keeper", "Ola", "Villager2", { { "pipwing", 14 }, { "hexbat", 15 } }, { "My birds will blow you away!" }, { "Grounded..." }),

	trainer("r4a", "route4", 0.2, -1, "Eclipse Grunt", "", "Grunt", { { "hexbat", 18 }, { "shadewisp", 19 } }, { "Team Eclipse is busy here. Get lost, kid!" }, { "Ugh! The admin won't be happy..." }),
	trainer("r4b", "route4", 0.5, 1, "Scientist", "Ivy", "Scientist", { { "voltbug", 19 }, { "zapkit", 20 } }, { "Team Eclipse stole my research notes! Show me you can stop them!" }, { "You might actually beat them." }),
	trainer("r4c", "route4", 0.8, -1, "Eclipse Grunt", "", "Grunt", { { "voltbug", 19 }, { "hexbat", 19 } }, { "Our admin Vex is taking over Voltara's power plant!" }, { "Whatever! You'll never beat Vex!" }),

	trainer("rival3", "route5", 0.15, -1, "Rival", "Kai", "Rival", nil, nil, nil, { Rival = 3, Flag = "rival3" }),
	trainer("r5a", "route5", 0.4, 1, "Bird Keeper", "Sam", "Villager2", { { "pipwing", 22 }, { "breezlet", 23 } }, { "The wind is perfect for battling!" }, { "Blown off course!" }),
	trainer("r5b", "route5", 0.65, -1, "Picnicker", "Joy", "Lass", { { "mossbun", 22 }, { "sunnybun", 23 } }, { "A battle before lunch? Sure!" }, { "I'm hungry now." }),
	trainer("r5c", "route5", 0.88, 1, "Swimmer", "Rio", "Fisher", { { "finnow", 23 }, { "puddlit", 23 } }, { "I'm drying off between swims. Battle?" }, { "Back into the water I go..." }),

	trainer("r6a", "route6", 0.25, -1, "Hiker", "Ben", "Hiker", { { "cragmole", 27 }, { "bouldergrub", 28 } }, { "The volcano is close. Feel the heat?" }, { "I need a break." }),
	trainer("r6b", "route6", 0.55, 1, "Firebreather", "Tom", "Firebreather", { { "scorchling", 27 }, { "cindercub", 28 } }, { "Fwoosh! Watch my fire tricks!" }, { "My flames went out..." }),
	trainer("r6c", "route6", 0.85, -1, "Mystic", "Luna", "Mystic", { { "shadewisp", 28 }, { "glimmoth", 28 } }, { "I saw you in my crystal ball. You lose... I think." }, { "The crystal ball was wrong." }),

	trainer("r7a", "route7", 0.2, 1, "Eclipse Grunt", "", "Grunt", { { "hexbat", 32 }, { "duskmaw", 32 } }, { "Boss Nyx is almost ready to wake Voidrake! You're too late!" }, { "Nyx will handle you..." }),
	trainer("r7b", "route7", 0.5, -1, "Ace Tamer", "Rex", "Ace", { { "galewing", 33 }, { "voltlynx", 33 } }, { "Only ace tamers make it this far. Prove you're one!" }, { "You're the real ace." }),
	trainer("r7c", "route7", 0.8, 1, "Skier", "Nils", "Skier", { { "frostkit", 32 }, { "snowpuff", 33 } }, { "It's getting cold! Let's warm up with a battle!" }, { "Brr... cold AND beaten." }),

	trainer("r8a", "route8", 0.25, -1, "Skier", "Elsa", "Skier", { { "frostkit", 37 }, { "glaciat", 38 } }, { "Snow is my favorite battlefield!" }, { "Snowed under..." }),
	trainer("r8b", "route8", 0.55, 1, "Ace Tamer", "Mira", "Ace", { { "torrentail", 38 }, { "thornback", 38 } }, { "Frostholm's arena is tough. Let me test you first." }, { "You're ready." }),
	trainer("r8c", "route8", 0.82, -1, "Hiker", "Olaf", "Hiker", { { "quarrok", 38 }, { "bouldergrub", 38 } }, { "Even ice can't stop a hiker!" }, { "Slipped on the ice..." }),

	trainer("v1", "victory", 0.2, 1, "Ace Tamer", "Zane", "Ace", { { "quarrok", 45 }, { "glaciat", 45 }, { "gloomwing", 46 } }, { "Champion Road is where dreams end. Turn back!" }, { "Your dream continues." }),
	trainer("v2", "victory", 0.45, -1, "Veteran", "Hilda", "Villager2", { { "thundermane", 46 }, { "torrentail", 46 } }, { "I've battled for 60 years. Show me something new!" }, { "That was something new indeed!" }),
	trainer("rival4", "victory", 0.75, 1, "Rival", "Kai", "Rival", nil, nil, nil, { Rival = 4, Flag = "rival4" }),

	-- Team Eclipse in den Staedten (blockieren die Arena)
	trainer("vex", "voltara", 0, 0, "Eclipse Admin", "Vex", "Admin", { { "shadewisp", 24 }, { "hexbat", 25 }, { "duskmaw", 27 } },
		{ "Well, well. A little tamer wants to play hero?", "Team Eclipse needs Voltara's power to wake the mighty Voidrake!", "Nobody enters this arena until we're done!" },
		{ "No! The plan... Fine, we're leaving!", "But Boss Nyx will finish what we started!" }, { Flag = "eclipse1", Blocker = true, Sight = 0 }),
	trainer("dg", "duskhollow", 0, 0, "Eclipse Grunt", "", "Grunt", { { "hexbat", 38 }, { "shadewisp", 39 } }, { "Halt! Boss Nyx is busy!" }, { "Sorry boss..." }, { Sight = 18 }),
	trainer("nyx", "duskhollow", 0, 0, "Eclipse Boss", "Nyx", "Boss", { { "gloomwing", 40 }, { "duskmaw", 41 }, { "magmarok", 41 }, { "nightreign", 43 } },
		{ "So you're the brat who ruined our plans in Voltara.", "Voidrake will rise and Team Eclipse will rule Valoria!", "You'll have to defeat me first. Ha!" },
		{ "Impossible! Defeated by a child...", "Team Eclipse... retreat! But Voidrake still sleeps in the Void Rift. Someday..." }, { Flag = "eclipse2", Blocker = true, Sight = 0 }),
}

-- Arena-Trainer: zwei pro Arena, Element der Arena
Story.ArenaTrainers = {
	pebbleton = { { "pebblit", 10 }, { "cragmole", 11 } },
	coralport = { { "finnow", 15 }, { "puddlit", 16 } },
	bloomfield = { { "mossbun", 20 }, { "sproutling", 21 } },
	voltara = { { "voltbug", 25 }, { "zapkit", 26 } },
	skyreach = { { "pipwing", 30 }, { "breezlet", 31 } },
	cinderpeak = { { "scorchling", 35 }, { "cindercub", 36 } },
	duskhollow = { { "shadewisp", 40 }, { "hexbat", 41 } },
	frostholm = { { "frostkit", 45 }, { "snowpuff", 46 } },
}
for index, leader in Story.Leaders do
	local mons = Story.ArenaTrainers[leader.Town]
	for slot = 1, 2 do
		table.insert(Story.Trainers, trainer(`gym{index}_{slot}`, leader.Town, 0, 0, "Arena Trainer", ({ "Alex", "Sky", "Robin", "Jamie", "Casey", "Drew", "Sam", "Max", "Jo", "Kim", "Lee", "Pat", "Ash", "Bo", "Cal", "Dee" })[(index - 1) * 2 + slot],
			if slot == 1 then "Villager" else "Villager2", { mons[slot], { mons[3 - slot][1], mons[slot][2] + 1 } },
			{ `You want to battle {leader.Name}? Get through me first!` }, { `{leader.Name} is way stronger than me!` }, { ArenaSlot = slot, Sight = 16 }))
	end
end

Story.TrainersById = {}
for _, t in Story.Trainers do
	Story.TrainersById[t.Id] = t
end

---------------------------------------------------------------- Personen zum Reden

-- Pos = Versatz zur Stadtmitte. Gift = einmaliges Geschenk.
Story.Npcs = {
	{ Id = "mom", Area = "dawnvale", Pos = Vector3.new(-28, 0, -22), Name = "Mom", Look = "Villager", Lines = { "Good luck on your journey, sweetie!", "Here, take these Potions. Call me if you need anything!" }, Gift = { Item = "Potion", Amount = 3, Flag = "gift_mom" } },
	{ Id = "dv1", Area = "dawnvale", Pos = Vector3.new(24, 0, 30), Name = "Old Man", Look = "Hiker", Lines = { "Tall grass is full of wild beasts.", "Weaken them first, then throw an orb. Sleeping or paralyzed beasts are easier to catch!" } },
	{ Id = "pb1", Area = "pebbleton", Pos = Vector3.new(-24, 0, 26), Name = "Miner", Look = "Hiker", Lines = { "Rocco's Stone beasts hate Water and Leaf attacks.", "Fire? That won't do much against rock!" } },
	{ Id = "pb2", Area = "pebbleton", Pos = Vector3.new(26, 0, 28), Name = "Lass", Look = "Lass", Lines = { "You look like a promising tamer! Take these!" }, Gift = { Item = "GreatOrb", Amount = 2, Flag = "gift_pb2" } },
	{ Id = "cp1", Area = "coralport", Pos = Vector3.new(-26, 0, 26), Name = "Sailor", Look = "Fisher", Lines = { "Marina's Water beasts get zapped by Spark and tangled by Leaf!" } },
	{ Id = "bf1", Area = "bloomfield", Pos = Vector3.new(-24, 0, 26), Name = "Gardener", Look = "Villager", Lines = { "Fire burns Leaf beasts. Wind and Frost work great too!", "Here, a Revive. It brings a fainted beast back!" }, Gift = { Item = "Revive", Amount = 1, Flag = "gift_bf1" } },
	{ Id = "vt1", Area = "voltara", Pos = Vector3.new(-26, 0, 26), Name = "Engineer", Look = "Scientist", Lines = { "Team Eclipse is draining our power plant!", "Their admin is standing right in front of the arena!" } },
	{ Id = "sr1", Area = "skyreach", Pos = Vector3.new(-26, 0, 26), Name = "Pilot", Look = "Skier", Lines = { "Spark, Stone and Frost attacks bring Wind beasts down to earth." } },
	{ Id = "ci1", Area = "cinderpeak", Pos = Vector3.new(-26, 0, 26), Name = "Volcanologist", Look = "Scientist", Lines = { "They say a legendary stone giant sleeps in the crater nearby...", "Only tamers with six badges dare to go near it." } },
	{ Id = "dh1", Area = "duskhollow", Pos = Vector3.new(-26, 0, 26), Name = "Mystic", Look = "Mystic", Lines = { "Light attacks scare away the shadows.", "Team Eclipse has taken over our arena! Their boss Nyx is waiting there." } },
	{ Id = "fh1", Area = "frostholm", Pos = Vector3.new(-26, 0, 26), Name = "Skier", Look = "Skier", Lines = { "Fire and Stone shatter ice!", "Here, these will help you on Champion Road." }, Gift = { Item = "HyperPotion", Amount = 3, Flag = "gift_fh1" } },
	{ Id = "lg1", Area = "league", Pos = Vector3.new(-60, 0, 60), Name = "Guide", Look = "Guard", Lines = { "Welcome to the Colosseum League!", "Beat the Grand Four one after another, then face the Champion in the center of the arena." } },
}

---------------------------------------------------------------- Legendaere Bestien

-- Feste Begegnungen an besonderen Orten. Pos = Versatz zur Ortsmitte.
Story.Legends = {
	{ Beast = "colossix", Level = 45, Area = "cinderpeak", Pos = Vector3.new(-52, 0, -52), Badges = 6, Text = "The ground trembles. A giant made of stone opens its eyes!" },
	{ Beast = "aurelion", Level = 50, Area = "skyreach", Pos = Vector3.new(-52, 0, -52), Badges = 7, Text = "A golden light shines from the Sun Shrine... Aurelion appears!" },
	{ Beast = "glacirion", Level = 55, Area = "frostholm", Pos = Vector3.new(-52, 0, -52), Badges = 8, Text = "The air turns ice cold. Glacirion steps out of the blizzard!" },
	{ Beast = "zephyros", Level = 55, Area = "victory", A = 0.92, C = -26, Badges = 8, Text = "Thunder rolls across the sky. Zephyros swoops down!" },
	{ Beast = "voidrake", Level = 70, Area = "league", Pos = Vector3.new(80, 0, -80), Flag = "champion", Text = "The Void Rift tears open... VOIDRAKE emerges!" },
}

---------------------------------------------------------------- Tore

-- Ausgang einer Stadt zur naechsten Route: Bedingung. Badges = noetige Orden, Flag = noetiges Ereignis.
Story.Gates = {
	dawnvale = { Flag = "starter", Text = "It's dangerous to go into the tall grass without a beast! Visit Professor Sol's lab first." },
	pebbleton = { Badges = 1, Text = "Only tamers with the Pebble Badge may pass. Leader Rocco is in the arena!" },
	coralport = { Badges = 2, Text = "You need the Wave Badge to continue. Challenge Leader Marina first!" },
	bloomfield = { Badges = 3, Text = "Leader Fern wants to see you before you leave. Get the Bloom Badge!" },
	voltara = { Badges = 4, Text = "The road north is closed until you earn the Volt Badge." },
	skyreach = { Badges = 5, Text = "Only tamers with the Gale Badge can cross the mountain pass." },
	cinderpeak = { Badges = 6, Text = "The volcano path is too dangerous without the Ember Badge." },
	duskhollow = { Badges = 7, Text = "The snowy pass is only for tamers with the Shade Badge." },
	frostholm = { Badges = 8, Text = "Champion Road! Only tamers with all 8 badges may enter." },
}

---------------------------------------------------------------- Ziel-Anzeige

-- Was soll der Spieler als Naechstes tun? flags = gesetzte Ereignisse, badges = Anzahl Orden
function Story.Objective(flags, badges: number): string
	flags = flags or {}
	if not flags.starter then
		return "Visit Professor Sol's lab in Dawnvale Town"
	end
	if badges < 8 then
		local leader = Story.Leaders[badges + 1]
		local town = Story.AreasById[leader.Town].Name
		if leader.Requires == "eclipse1" and not flags.eclipse1 then
			return "Stop Team Eclipse in Voltara City!"
		elseif leader.Requires == "eclipse2" and not flags.eclipse2 then
			return "Defeat Team Eclipse boss Nyx in Duskhollow!"
		end
		return `Earn the {leader.Badge} from Leader {leader.Name} in {town}`
	end
	if not flags.champion then
		for index, elite in Story.Elite do
			if not flags[elite.Id] then
				if elite.Id == "champion" then
					return "Defeat Champion Maximus in the Colosseum!"
				end
				return `Beat the Grand Four at the Colosseum League ({index - 1}/4)`
			end
		end
	end
	return "You are the Champion! Find Voidrake at the Void Rift and fill your Bestiary"
end

-- Ort, zu dem das aktuelle Ziel fuehrt (fuer den Pfeil/die Karte)
function Story.ObjectiveArea(flags, badges: number): string
	flags = flags or {}
	if not flags.starter then
		return "dawnvale"
	end
	if badges < 8 then
		return Story.Leaders[badges + 1].Town
	end
	return "league"
end

return Story
