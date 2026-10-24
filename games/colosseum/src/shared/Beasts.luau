-- Alle Bestien, Elemente und Attacken von Colosseum Catcher (eigene Erfindungen).
-- Regeln angelehnt an klassische Monster-Rollenspiele: Typtabelle, Attacken mit AP,
-- Statusprobleme, Statuswerte-Stufen, Lernlisten nach Level und Entwicklungen.

local Beasts = {}

---------------------------------------------------------------- Elemente

Beasts.TypeOrder = { "Normal", "Fire", "Water", "Leaf", "Spark", "Stone", "Wind", "Frost", "Shadow", "Light" }

-- Strong = doppelter Schaden, Weak = halber Schaden, Immune = kein Schaden (Angreifer -> Verteidiger)
Beasts.Types = {
	Normal = { Color = Color3.fromRGB(205, 195, 175), Strong = {}, Weak = { Stone = true, Shadow = true } },
	Fire = { Color = Color3.fromRGB(255, 110, 50), Strong = { Leaf = true, Frost = true }, Weak = { Fire = true, Water = true, Stone = true } },
	Water = { Color = Color3.fromRGB(60, 150, 255), Strong = { Fire = true, Stone = true }, Weak = { Water = true, Leaf = true } },
	Leaf = { Color = Color3.fromRGB(90, 200, 90), Strong = { Water = true, Stone = true }, Weak = { Fire = true, Leaf = true, Wind = true } },
	Spark = { Color = Color3.fromRGB(255, 215, 50), Strong = { Water = true, Wind = true }, Weak = { Spark = true, Leaf = true }, Immune = { Stone = true } },
	Stone = { Color = Color3.fromRGB(180, 140, 95), Strong = { Fire = true, Spark = true, Wind = true, Frost = true }, Weak = { Leaf = true, Stone = true } },
	Wind = { Color = Color3.fromRGB(150, 205, 245), Strong = { Leaf = true }, Weak = { Spark = true, Stone = true } },
	Frost = { Color = Color3.fromRGB(150, 235, 255), Strong = { Leaf = true, Wind = true }, Weak = { Fire = true, Water = true, Frost = true } },
	Shadow = { Color = Color3.fromRGB(150, 80, 220), Strong = { Light = true }, Weak = { Shadow = true } },
	Light = { Color = Color3.fromRGB(255, 235, 140), Strong = { Shadow = true }, Weak = { Light = true, Fire = true } },
}

function Beasts.TypeMultiplier(attackType: string, defendType: string?): number
	if not defendType then
		return 1
	end
	local attack = Beasts.Types[attackType]
	if not attack then
		return 1
	end
	if attack.Immune and attack.Immune[defendType] then
		return 0
	end
	if attack.Strong[defendType] then
		return 2
	end
	if attack.Weak[defendType] then
		return 0.5
	end
	return 1
end

---------------------------------------------------------------- Attacken

-- Power = Staerke (0 = Statusattacke), Acc = Genauigkeit (nil = trifft immer), PP = Einsaetze.
-- Effect: Status = "Burn"/"Poison"/"Para"/"Sleep"/"Freeze" mit Chance; Stat/Stages/Self fuer Werte-Stufen;
-- Heal = Anteil der KP fuer den Anwender; Drain = Anteil des Schadens als Heilung; Recoil = Rueckstoss.
local function move(name: string, moveType: string, power: number, acc: number?, pp: number, extra: any?)
	local m = { Name = name, Type = moveType, Power = power, Acc = acc, PP = pp, Priority = 0 }
	for key, value in extra or {} do
		m[key] = value
	end
	return m
end

Beasts.Moves = {
	-- Normal
	Tackle = move("Tackle", "Normal", 40, 1, 35),
	QuickStrike = move("Quick Strike", "Normal", 40, 1, 30, { Priority = 1 }),
	Headbutt = move("Headbutt", "Normal", 70, 1, 15),
	BodySlam = move("Body Slam", "Normal", 85, 1, 15, { Effect = { Status = "Para", Chance = 0.3 } }),
	HyperBlast = move("Hyper Blast", "Normal", 120, 0.9, 5),
	Growl = move("Growl", "Normal", 0, 1, 40, { Effect = { Stat = "Atk", Stages = -1 } }),
	Harden = move("Harden", "Normal", 0, nil, 30, { Effect = { Stat = "Def", Stages = 1, Self = true } }),
	FocusUp = move("Focus Up", "Normal", 0, nil, 20, { Effect = { Stat = "Atk", Stages = 2, Self = true } }),
	Struggle = move("Struggle", "Normal", 50, nil, 1, { Recoil = 0.25 }),
	-- Feuer
	Ember = move("Ember", "Fire", 40, 1, 25, { Effect = { Status = "Burn", Chance = 0.1 } }),
	FlameFang = move("Flame Fang", "Fire", 65, 0.95, 15, { Effect = { Status = "Burn", Chance = 0.1 } }),
	FlameBurst = move("Flame Burst", "Fire", 90, 1, 15, { Effect = { Status = "Burn", Chance = 0.1 } }),
	Inferno = move("Inferno", "Fire", 120, 0.85, 5, { Effect = { Status = "Burn", Chance = 0.3 } }),
	ScaldHaze = move("Scald Haze", "Fire", 0, 0.85, 15, { Effect = { Status = "Burn", Chance = 1 } }),
	-- Wasser
	Bubble = move("Bubble", "Water", 40, 1, 30),
	WaterPulse = move("Water Pulse", "Water", 60, 1, 20),
	AquaTail = move("Aqua Tail", "Water", 90, 0.9, 10),
	HydroCannon = move("Hydro Cannon", "Water", 120, 0.8, 5),
	AquaVeil = move("Aqua Veil", "Water", 0, nil, 20, { Effect = { Stat = "Def", Stages = 2, Self = true } }),
	-- Blatt
	VineWhip = move("Vine Whip", "Leaf", 45, 1, 25),
	RazorLeaf = move("Razor Leaf", "Leaf", 60, 0.95, 25, { HighCrit = true }),
	GigaDrain = move("Giga Drain", "Leaf", 80, 1, 10, { Drain = 0.5 }),
	SolarBeam = move("Solar Beam", "Leaf", 120, 0.9, 10),
	SleepSpore = move("Sleep Spore", "Leaf", 0, 0.75, 15, { Effect = { Status = "Sleep", Chance = 1 } }),
	-- Blitz
	Spark = move("Spark", "Spark", 40, 1, 30, { Effect = { Status = "Para", Chance = 0.1 } }),
	ThunderFang = move("Thunder Fang", "Spark", 65, 0.95, 15, { Effect = { Status = "Para", Chance = 0.1 } }),
	Thunderbolt = move("Thunderbolt", "Spark", 90, 1, 15, { Effect = { Status = "Para", Chance = 0.1 } }),
	VoltCrash = move("Volt Crash", "Spark", 120, 0.85, 5, { Effect = { Status = "Para", Chance = 0.2 } }),
	StaticField = move("Static Field", "Spark", 0, 0.9, 20, { Effect = { Status = "Para", Chance = 1 } }),
	-- Stein
	PebbleToss = move("Pebble Toss", "Stone", 45, 1, 25),
	RockSlide = move("Rock Slide", "Stone", 75, 0.9, 10),
	Quake = move("Quake", "Stone", 95, 1, 10),
	StoneEdge = move("Stone Edge", "Stone", 110, 0.8, 5, { HighCrit = true }),
	IronShell = move("Iron Shell", "Stone", 0, nil, 15, { Effect = { Stat = "Def", Stages = 2, Self = true } }),
	-- Wind
	Gust = move("Gust", "Wind", 40, 1, 35),
	WingSlash = move("Wing Slash", "Wind", 60, 1, 25),
	AirBlade = move("Air Blade", "Wind", 80, 0.95, 15, { HighCrit = true }),
	Hurricane = move("Hurricane", "Wind", 115, 0.75, 10),
	Tailwind = move("Tailwind", "Wind", 0, nil, 20, { Effect = { Stat = "Spd", Stages = 2, Self = true } }),
	-- Frost
	IceShard = move("Ice Shard", "Frost", 40, 1, 30, { Priority = 1 }),
	IceFang = move("Ice Fang", "Frost", 65, 0.95, 15, { Effect = { Status = "Freeze", Chance = 0.1 } }),
	IceBeam = move("Ice Beam", "Frost", 90, 1, 10, { Effect = { Status = "Freeze", Chance = 0.1 } }),
	Blizzard = move("Blizzard", "Frost", 115, 0.75, 5, { Effect = { Status = "Freeze", Chance = 0.15 } }),
	FrostMist = move("Frost Mist", "Frost", 0, 0.95, 20, { Effect = { Stat = "Spd", Stages = -2 } }),
	-- Schatten
	ShadeBite = move("Shade Bite", "Shadow", 45, 1, 25),
	NightSlash = move("Night Slash", "Shadow", 70, 1, 15, { HighCrit = true }),
	DarkPulse = move("Dark Pulse", "Shadow", 85, 1, 15),
	VoidStrike = move("Void Strike", "Shadow", 115, 0.85, 5),
	ToxicMist = move("Toxic Mist", "Shadow", 0, 0.9, 15, { Effect = { Status = "Poison", Chance = 1 } }),
	-- Licht
	Glimmer = move("Glimmer", "Light", 40, 1, 30),
	FlashRay = move("Flash Ray", "Light", 65, 1, 20),
	HolyBeam = move("Holy Beam", "Light", 90, 1, 10),
	RadiantBurst = move("Radiant Burst", "Light", 120, 0.85, 5),
	SoothingLight = move("Soothing Light", "Light", 0, nil, 10, { Effect = { Heal = 0.5 } }),
}

-- Staerke-Stufen je Element und die Unterstuetzungsattacke
Beasts.TypeMoves = {
	Normal = { Tiers = { "Tackle", "Headbutt", "BodySlam", "HyperBlast" }, Util = "Growl" },
	Fire = { Tiers = { "Ember", "FlameFang", "FlameBurst", "Inferno" }, Util = "ScaldHaze" },
	Water = { Tiers = { "Bubble", "WaterPulse", "AquaTail", "HydroCannon" }, Util = "AquaVeil" },
	Leaf = { Tiers = { "VineWhip", "RazorLeaf", "GigaDrain", "SolarBeam" }, Util = "SleepSpore" },
	Spark = { Tiers = { "Spark", "ThunderFang", "Thunderbolt", "VoltCrash" }, Util = "StaticField" },
	Stone = { Tiers = { "PebbleToss", "RockSlide", "Quake", "StoneEdge" }, Util = "IronShell" },
	Wind = { Tiers = { "Gust", "WingSlash", "AirBlade", "Hurricane" }, Util = "Tailwind" },
	Frost = { Tiers = { "IceShard", "IceFang", "IceBeam", "Blizzard" }, Util = "FrostMist" },
	Shadow = { Tiers = { "ShadeBite", "NightSlash", "DarkPulse", "VoidStrike" }, Util = "ToxicMist" },
	Light = { Tiers = { "Glimmer", "FlashRay", "HolyBeam", "RadiantBurst" }, Util = "SoothingLight" },
}

Beasts.Statuses = {
	Burn = { Name = "BRN", Color = Color3.fromRGB(255, 120, 60), Text = "was burned" },
	Poison = { Name = "PSN", Color = Color3.fromRGB(170, 90, 220), Text = "was poisoned" },
	Para = { Name = "PAR", Color = Color3.fromRGB(240, 200, 40), Text = "is paralyzed! It may be unable to move" },
	Sleep = { Name = "SLP", Color = Color3.fromRGB(150, 150, 170), Text = "fell asleep" },
	Freeze = { Name = "FRZ", Color = Color3.fromRGB(140, 220, 255), Text = "was frozen solid" },
}

---------------------------------------------------------------- Seltenheit

-- CatchRate wie im Klassiker (0-255), Yield = Grund-EP beim Besiegen
Beasts.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), CatchRate = 190, Yield = 64 },
	{ Name = "Rare", Color = Color3.fromRGB(80, 160, 255), CatchRate = 120, Yield = 142 },
	{ Name = "Epic", Color = Color3.fromRGB(190, 90, 255), CatchRate = 45, Yield = 220, Glow = true },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 195, 50), CatchRate = 12, Yield = 270, Glow = true, Crown = true, Announce = true },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 70, 110), CatchRate = 5, Yield = 300, Glow = true, Crown = true, Announce = true },
}

---------------------------------------------------------------- Bestien

local function stats(hp: number, atk: number, def: number, spd: number, scale: number)
	return { Hp = math.floor(hp * scale), Atk = math.floor(atk * scale), Def = math.floor(def * scale), Spd = math.floor(spd * scale) }
end

-- Body: Quad, Biped, Bird, Blob, Lizard, Frog, Ghost, Dragon. Extras: zusaetzliche Merkmale fuer das Modell.
-- Coverage: zweites Element fuer Attacken, falls die Bestie nur ein Element hat.
-- Dex: kurzer Eintrag fuer das Bestiarium.
Beasts.List = {
	-- Starter Feuer
	{ Id = "cindercub", Name = "Cindercub", Type = "Fire", Rarity = "Common", Body = "Quad", Color = Color3.fromRGB(255, 130, 60), Extras = { "Ears", "Tail" }, Base = stats(44, 52, 40, 55, 1), Evolve = { To = "blazehound", Level = 16 }, Coverage = "Stone", Dex = "Its tail flame flickers brighter when it is happy." },
	{ Id = "blazehound", Name = "Blazehound", Type = "Fire", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(235, 90, 40), Extras = { "Ears", "Tail", "Spikes" }, Base = stats(44, 52, 40, 55, 1.35), Evolve = { To = "infernox", Level = 36 }, Coverage = "Stone", Dex = "It runs circles around foes, leaving rings of fire." },
	{ Id = "infernox", Name = "Infernox", Type = "Fire", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(200, 50, 30), Extras = { "Horns", "Tail", "Spikes", "Mane" }, Base = stats(44, 52, 40, 55, 1.75), Coverage = "Stone", Dex = "Its roar can melt the snow off a whole mountain." },
	-- Starter Wasser
	{ Id = "puddlit", Name = "Puddlit", Type = "Water", Rarity = "Common", Body = "Frog", Color = Color3.fromRGB(80, 170, 255), Extras = {}, Base = stats(50, 45, 50, 45, 1), Evolve = { To = "tidefin", Level = 16 }, Coverage = "Frost", Dex = "It hops between puddles and sings when it rains." },
	{ Id = "tidefin", Name = "Tidefin", Type = "Water", Rarity = "Rare", Body = "Lizard", Color = Color3.fromRGB(50, 130, 230), Extras = { "Fin", "Tail" }, Base = stats(50, 45, 50, 45, 1.35), Evolve = { To = "abyssaur", Level = 36 }, Coverage = "Frost", Dex = "It surfs on its own waves to cross rivers." },
	{ Id = "abyssaur", Name = "Abyssaur", Type = "Water", Type2 = "Frost", Rarity = "Epic", Body = "Dragon", Color = Color3.fromRGB(30, 80, 190), Extras = { "Fin", "Tail", "Horns" }, Base = stats(50, 45, 50, 45, 1.75), Dex = "Ancient sailors called it the guardian of the deep." },
	-- Starter Blatt
	{ Id = "sproutling", Name = "Sproutling", Type = "Leaf", Rarity = "Common", Body = "Blob", Color = Color3.fromRGB(120, 210, 90), Extras = { "Sprout" }, Base = stats(48, 47, 52, 43, 1), Evolve = { To = "thornback", Level = 16 }, Coverage = "Stone", Dex = "The sprout on its head turns toward the sun." },
	{ Id = "thornback", Name = "Thornback", Type = "Leaf", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(80, 170, 70), Extras = { "Shell", "Sprout" }, Base = stats(48, 47, 52, 43, 1.35), Evolve = { To = "verdantusk", Level = 36 }, Coverage = "Stone", Dex = "Its thorny shell grows harder every season." },
	{ Id = "verdantusk", Name = "Verdantusk", Type = "Leaf", Type2 = "Stone", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(50, 130, 60), Extras = { "Shell", "Horns", "Flower" }, Base = stats(48, 47, 52, 43, 1.75), Dex = "Forests grow wherever it rests for a night." },
	-- Blitz
	{ Id = "zapkit", Name = "Zapkit", Type = "Spark", Rarity = "Common", Body = "Quad", Color = Color3.fromRGB(255, 220, 70), Extras = { "BigEars", "Tail" }, Base = stats(40, 50, 38, 62, 1), Evolve = { To = "voltlynx", Level = 22 }, Coverage = "Wind", Dex = "Rubbing its ears makes sparks jump out." },
	{ Id = "voltlynx", Name = "Voltlynx", Type = "Spark", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(245, 195, 40), Extras = { "Ears", "Tail", "Bolt" }, Base = stats(40, 50, 38, 62, 1.35), Evolve = { To = "thundermane", Level = 38 }, Coverage = "Wind", Dex = "It stalks its prey from the clouds of a storm." },
	{ Id = "thundermane", Name = "Thundermane", Type = "Spark", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(230, 170, 20), Extras = { "Ears", "Tail", "Bolt", "Mane" }, Base = stats(40, 50, 38, 62, 1.75), Coverage = "Wind", Dex = "Lightning strikes wherever its mane is pointing." },
	-- Stein
	{ Id = "pebblit", Name = "Pebblit", Type = "Stone", Rarity = "Common", Body = "Blob", Color = Color3.fromRGB(170, 150, 125), Extras = { "Rocky" }, Base = stats(52, 48, 60, 30, 1), Evolve = { To = "bouldergrub", Level = 20 }, Coverage = "Normal", Dex = "Hikers often trip over it because it looks like a rock." },
	{ Id = "bouldergrub", Name = "Bouldergrub", Type = "Stone", Rarity = "Rare", Body = "Lizard", Color = Color3.fromRGB(150, 120, 90), Extras = { "Rocky", "Spikes" }, Base = stats(52, 48, 60, 30, 1.35), Evolve = { To = "titanshell", Level = 38 }, Coverage = "Normal", Dex = "It digs tunnels through solid rock by eating it." },
	{ Id = "titanshell", Name = "Titanshell", Type = "Stone", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(120, 95, 70), Extras = { "Rocky", "Shell", "Horns" }, Base = stats(52, 48, 60, 30, 1.75), Coverage = "Normal", Dex = "Mountains shake when a herd of them migrates." },
	-- Schatten
	{ Id = "shadewisp", Name = "Shadewisp", Type = "Shadow", Rarity = "Common", Body = "Ghost", Color = Color3.fromRGB(120, 80, 190), Extras = {}, Base = stats(40, 55, 38, 57, 1), Evolve = { To = "duskmaw", Level = 25 }, Coverage = "Normal", Dex = "It hides in the shadows of travelers to tickle them." },
	{ Id = "duskmaw", Name = "Duskmaw", Type = "Shadow", Rarity = "Rare", Body = "Biped", Color = Color3.fromRGB(90, 55, 150), Extras = { "Horns", "Tail" }, Base = stats(40, 55, 38, 57, 1.35), Evolve = { To = "nightreign", Level = 40 }, Coverage = "Normal", Dex = "Its grin is the last thing you see at sunset." },
	{ Id = "nightreign", Name = "Nightreign", Type = "Shadow", Type2 = "Wind", Rarity = "Epic", Body = "Dragon", Color = Color3.fromRGB(60, 35, 110), Extras = { "Horns", "Tail", "BatWings" }, Base = stats(40, 55, 38, 57, 1.75), Dex = "It rules the night sky above the old ruins." },
	-- Licht
	{ Id = "glimmoth", Name = "Glimmoth", Type = "Light", Type2 = "Wind", Rarity = "Common", Body = "Bird", Color = Color3.fromRGB(255, 240, 180), Extras = { "Antenna" }, Base = stats(42, 48, 42, 56, 1), Evolve = { To = "lumiwing", Level = 22 }, Dex = "At night its wings glow like lanterns." },
	{ Id = "lumiwing", Name = "Lumiwing", Type = "Light", Type2 = "Wind", Rarity = "Rare", Body = "Bird", Color = Color3.fromRGB(255, 225, 130), Extras = { "Antenna", "Comb" }, Base = stats(42, 48, 42, 56, 1.35), Evolve = { To = "solarion", Level = 38 }, Dex = "It guides lost travelers home with its light." },
	{ Id = "solarion", Name = "Solarion", Type = "Light", Type2 = "Wind", Rarity = "Epic", Body = "Bird", Color = Color3.fromRGB(255, 200, 60), Extras = { "Comb", "Halo", "LongNeck" }, Base = stats(42, 48, 42, 56, 1.75), Dex = "Legends say it carries the morning sun on its back." },
	-- Normal
	{ Id = "nibbit", Name = "Nibbit", Type = "Normal", Rarity = "Common", Body = "Quad", Color = Color3.fromRGB(190, 150, 110), Extras = { "BigEars", "Tail" }, Base = stats(35, 48, 35, 62, 1), Evolve = { To = "burrowbun", Level = 18 }, Coverage = "Stone", Dex = "It nibbles on anything, even fence posts." },
	{ Id = "burrowbun", Name = "Burrowbun", Type = "Normal", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(160, 120, 85), Extras = { "BigEars", "Tail", "Spikes" }, Base = stats(35, 48, 35, 62, 1.45), Coverage = "Stone", Dex = "Its burrows are so big that whole families live in them." },
	{ Id = "pipwing", Name = "Pipwing", Type = "Normal", Type2 = "Wind", Rarity = "Common", Body = "Bird", Color = Color3.fromRGB(200, 170, 120), Extras = {}, Base = stats(40, 45, 40, 56, 1), Evolve = { To = "skyhawk", Level = 18 }, Dex = "Its chirping wakes up the whole village each morning." },
	{ Id = "skyhawk", Name = "Skyhawk", Type = "Normal", Type2 = "Wind", Rarity = "Rare", Body = "Bird", Color = Color3.fromRGB(170, 130, 90), Extras = { "Comb" }, Base = stats(40, 45, 40, 56, 1.35), Evolve = { To = "tempestrix", Level = 36 }, Dex = "It dives from the clouds faster than a falling star." },
	{ Id = "tempestrix", Name = "Tempestrix", Type = "Normal", Type2 = "Wind", Rarity = "Epic", Body = "Bird", Color = Color3.fromRGB(140, 100, 70), Extras = { "Comb", "LongNeck" }, Base = stats(40, 45, 40, 56, 1.75), Dex = "A flap of its wings can bend whole trees." },
	-- Wind
	{ Id = "breezlet", Name = "Breezlet", Type = "Wind", Rarity = "Common", Body = "Bird", Color = Color3.fromRGB(170, 220, 250), Extras = { "Antenna" }, Base = stats(42, 48, 38, 60, 1), Evolve = { To = "galewing", Level = 30 }, Coverage = "Normal", Dex = "It rides warm winds and never seems to land." },
	{ Id = "galewing", Name = "Galewing", Type = "Wind", Rarity = "Rare", Body = "Bird", Color = Color3.fromRGB(110, 180, 235), Extras = { "Comb", "LongNeck" }, Base = stats(42, 48, 38, 60, 1.5), Coverage = "Normal", Dex = "Whirlwinds follow it wherever it flies." },
	-- Wasser
	{ Id = "finnow", Name = "Finnow", Type = "Water", Rarity = "Common", Body = "Lizard", Color = Color3.fromRGB(90, 200, 220), Extras = { "Fin" }, Base = stats(45, 50, 45, 50, 1), Evolve = { To = "torrentail", Level = 28 }, Coverage = "Normal", Dex = "It slides along wet grass as fast as it swims." },
	{ Id = "torrentail", Name = "Torrentail", Type = "Water", Rarity = "Rare", Body = "Dragon", Color = Color3.fromRGB(40, 160, 200), Extras = { "Fin", "Tail" }, Base = stats(45, 50, 45, 50, 1.5), Coverage = "Normal", Dex = "One swing of its tail can stop a waterfall." },
	-- Blitz
	{ Id = "voltbug", Name = "Voltbug", Type = "Spark", Rarity = "Common", Body = "Blob", Color = Color3.fromRGB(240, 230, 90), Extras = { "Antenna" }, Base = stats(40, 45, 50, 40, 1), Evolve = { To = "joltbeetle", Level = 26 }, Coverage = "Leaf", Dex = "Groups of them light up the forest at night." },
	{ Id = "joltbeetle", Name = "Joltbeetle", Type = "Spark", Type2 = "Leaf", Rarity = "Rare", Body = "Biped", Color = Color3.fromRGB(220, 200, 40), Extras = { "Antenna", "Shell" }, Base = stats(40, 45, 50, 40, 1.5), Dex = "Its shell stores enough power to light a house." },
	-- Stein
	{ Id = "cragmole", Name = "Cragmole", Type = "Stone", Rarity = "Common", Body = "Biped", Color = Color3.fromRGB(150, 130, 110), Extras = { "Rocky" }, Base = stats(48, 55, 55, 30, 1), Evolve = { To = "quarrok", Level = 30 }, Coverage = "Normal", Dex = "It polishes stones it finds and gifts them to friends." },
	{ Id = "quarrok", Name = "Quarrok", Type = "Stone", Rarity = "Rare", Body = "Biped", Color = Color3.fromRGB(120, 100, 85), Extras = { "Rocky", "Spikes", "Horns" }, Base = stats(48, 55, 55, 30, 1.5), Coverage = "Normal", Dex = "Miners say it can smell gold through the rock." },
	-- Schatten / Wind
	{ Id = "hexbat", Name = "Hexbat", Type = "Shadow", Type2 = "Wind", Rarity = "Common", Body = "Bird", Color = Color3.fromRGB(110, 80, 160), Extras = { "BatWings" }, Base = stats(40, 48, 38, 60, 1), Evolve = { To = "gloomwing", Level = 26 }, Dex = "It sleeps upside down in old towers." },
	{ Id = "gloomwing", Name = "Gloomwing", Type = "Shadow", Type2 = "Wind", Rarity = "Rare", Body = "Bird", Color = Color3.fromRGB(80, 50, 130), Extras = { "BatWings", "Horns" }, Base = stats(40, 48, 38, 60, 1.5), Dex = "Its shriek can be heard three valleys away." },
	-- Licht
	{ Id = "sunnybun", Name = "Sunnybun", Type = "Light", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(255, 225, 150), Extras = { "BigEars", "Halo" }, Base = stats(60, 60, 60, 60, 1.25), Coverage = "Normal", Dex = "Seeing one is said to bring a week of good luck." },
	-- Feuer
	{ Id = "scorchling", Name = "Scorchling", Type = "Fire", Rarity = "Common", Body = "Lizard", Color = Color3.fromRGB(240, 120, 70), Extras = { "Tail" }, Base = stats(42, 52, 40, 52, 1), Evolve = { To = "magmarok", Level = 34 }, Coverage = "Stone", Dex = "It sunbathes on hot rocks near volcanoes." },
	{ Id = "magmarok", Name = "Magmarok", Type = "Fire", Type2 = "Stone", Rarity = "Rare", Body = "Dragon", Color = Color3.fromRGB(190, 70, 40), Extras = { "Rocky", "Horns", "Tail" }, Base = stats(42, 52, 40, 52, 1.55), Dex = "Lava flows through the cracks in its rocky skin." },
	-- Frost
	{ Id = "frostkit", Name = "Frostkit", Type = "Frost", Rarity = "Common", Body = "Quad", Color = Color3.fromRGB(190, 235, 255), Extras = { "Ears", "Tail" }, Base = stats(44, 50, 42, 54, 1), Evolve = { To = "glaciat", Level = 24 }, Coverage = "Water", Dex = "Its breath leaves tiny snowflakes in the air." },
	{ Id = "glaciat", Name = "Glaciat", Type = "Frost", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(140, 210, 245), Extras = { "Ears", "Tail", "IceSpikes" }, Base = stats(44, 50, 42, 54, 1.35), Evolve = { To = "blizzaurus", Level = 40 }, Coverage = "Water", Dex = "It sharpens its icy spikes on frozen trees." },
	{ Id = "blizzaurus", Name = "Blizzaurus", Type = "Frost", Type2 = "Stone", Rarity = "Epic", Body = "Dragon", Color = Color3.fromRGB(100, 170, 225), Extras = { "Horns", "Tail", "IceSpikes" }, Base = stats(44, 50, 42, 54, 1.75), Dex = "Each step it takes freezes the ground solid." },
	{ Id = "snowpuff", Name = "Snowpuff", Type = "Frost", Rarity = "Rare", Body = "Ghost", Color = Color3.fromRGB(235, 245, 255), Extras = { "IceSpikes" }, Base = stats(55, 50, 60, 45, 1.3), Coverage = "Light", Dex = "It drifts down with the first snow of winter." },
	-- Blatt
	{ Id = "mossbun", Name = "Mossbun", Type = "Leaf", Rarity = "Common", Body = "Quad", Color = Color3.fromRGB(140, 200, 110), Extras = { "BigEars", "Sprout" }, Base = stats(45, 48, 48, 52, 1), Evolve = { To = "verdibun", Level = 24 }, Coverage = "Normal", Dex = "Moss grows on its fur, so it hides easily in fields." },
	{ Id = "verdibun", Name = "Verdibun", Type = "Leaf", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(90, 170, 80), Extras = { "BigEars", "Flower" }, Base = stats(45, 48, 48, 52, 1.5), Coverage = "Normal", Dex = "The flower on its back smells sweeter than honey." },
	-- Legenden
	{ Id = "aurelion", Name = "Aurelion", Type = "Light", Rarity = "Legendary", Body = "Quad", Color = Color3.fromRGB(255, 235, 200), Extras = { "Mane", "Halo", "Tail" }, Base = stats(50, 56, 50, 58, 1.95), Coverage = "Fire", Dex = "The sun shines a little warmer when it awakens." },
	{ Id = "colossix", Name = "Colossix", Type = "Stone", Rarity = "Legendary", Body = "Biped", Color = Color3.fromRGB(205, 175, 120), Extras = { "Rocky", "Helmet", "Horns" }, Base = stats(55, 56, 55, 40, 1.95), Coverage = "Fire", Dex = "It is said the first colosseum was built in its honor." },
	{ Id = "glacirion", Name = "Glacirion", Type = "Frost", Rarity = "Legendary", Body = "Quad", Color = Color3.fromRGB(200, 240, 255), Extras = { "Mane", "IceSpikes", "Tail" }, Base = stats(55, 55, 55, 50, 1.95), Coverage = "Water", Dex = "Endless winter falls over the land it walks on." },
	{ Id = "zephyros", Name = "Zephyros", Type = "Wind", Type2 = "Spark", Rarity = "Legendary", Body = "Bird", Color = Color3.fromRGB(150, 210, 255), Extras = { "Comb", "LongNeck", "Halo" }, Base = stats(50, 58, 48, 62, 1.95), Dex = "Storms are born when it spreads its wings." },
	{ Id = "voidrake", Name = "Voidrake", Type = "Shadow", Type2 = "Fire", Rarity = "Mythic", Body = "Dragon", Color = Color3.fromRGB(35, 20, 60), Extras = { "Horns", "Tail", "BatWings", "Halo" }, Base = stats(55, 62, 52, 60, 2.2), Dex = "A beast from beyond the stars. Team Eclipse wants its power." },
}

Beasts.ById = {}
for index, beast in Beasts.List do
	beast.Number = index
	Beasts.ById[beast.Id] = beast
end
for _, beast in Beasts.List do
	if beast.Evolve then
		Beasts.ById[beast.Evolve.To].From = beast.Id
	end
end

Beasts.RaritiesByName = {}
for index, rarity in Beasts.Rarities do
	rarity.Index = index
	Beasts.RaritiesByName[rarity.Name] = rarity
end

---------------------------------------------------------------- Lernlisten

-- Erzeugt die Lernliste aus den Elementen der Bestie: { { Level, MoveKey }, ... } nach Level sortiert.
local learnsets = {}
function Beasts.Learnset(beastId: string): { { any } }
	if learnsets[beastId] then
		return learnsets[beastId]
	end
	local def = Beasts.ById[beastId]
	local list = {}
	local function add(level: number, key: string)
		for _, entry in list do
			if entry[2] == key then
				return
			end
		end
		table.insert(list, { level, key })
	end
	local base = def.Base
	local style = if base.Spd >= base.Atk and base.Spd >= base.Def then "Spd" elseif base.Def > base.Atk then "Def" else "Atk"
	local primary = Beasts.TypeMoves[def.Type]
	add(1, "Tackle")
	add(1, "Growl")
	if def.Type == "Normal" then
		add(6, "QuickStrike")
		add(11, if style == "Def" then "Harden" else "FocusUp")
		add(17, "Headbutt")
		add(29, "BodySlam")
		add(43, "HyperBlast")
	else
		add(6, primary.Tiers[1])
		add(11, primary.Util)
		add(17, primary.Tiers[2])
		add(29, primary.Tiers[3])
		add(43, primary.Tiers[4])
	end
	add(if style == "Spd" then 14 else 24, if style == "Spd" then "QuickStrike" elseif style == "Def" then "Harden" else "FocusUp")
	local second = def.Type2 or def.Coverage
	if second and second ~= def.Type then
		local secondary = Beasts.TypeMoves[second]
		add(21, secondary.Tiers[1])
		add(34, secondary.Tiers[2])
		if def.Type2 then
			add(47, secondary.Tiers[3])
		end
	end
	if def.Type ~= "Normal" then
		add(38, "BodySlam")
	end
	table.sort(list, function(a, b)
		return a[1] < b[1]
	end)
	learnsets[beastId] = list
	return list
end

-- Die (bis zu) vier neuesten Attacken, die eine Bestie auf diesem Level kann (wie bei wilden Bestien)
function Beasts.DefaultMoves(beastId: string, level: number): { string }
	local known = {}
	for _, entry in Beasts.Learnset(beastId) do
		if entry[1] <= level then
			table.insert(known, entry[2])
		end
	end
	local result = {}
	for i = #known, 1, -1 do
		if #result >= 4 then
			break
		end
		table.insert(result, 1, known[i])
	end
	return result
end

-- Kann die Bestie diese Attacke auf diesem Level (fuer das Umlernen im Team-Menue)?
function Beasts.CanLearn(beastId: string, moveKey: string, level: number): boolean
	for _, entry in Beasts.Learnset(beastId) do
		if entry[2] == moveKey and entry[1] <= level then
			return true
		end
	end
	return false
end

-- Neue Attacken genau auf diesem Level
function Beasts.MovesAtLevel(beastId: string, level: number): { string }
	local list = {}
	for _, entry in Beasts.Learnset(beastId) do
		if entry[1] == level then
			table.insert(list, entry[2])
		end
	end
	return list
end

---------------------------------------------------------------- Werte und Regeln

Beasts.MaxLevel = 100
Beasts.ShinyStatMultiplier = 1.15

-- Statuswerte auf einem Level (Formel wie im Klassiker, ohne Zufallswerte)
function Beasts.Stats(beastId: string, level: number, shiny: boolean?)
	local base = Beasts.ById[beastId].Base
	local bonus = if shiny then Beasts.ShinyStatMultiplier else 1
	local function stat(value: number): number
		return math.floor((math.floor(2 * value * level / 100) + 5) * bonus)
	end
	return {
		MaxHp = math.floor((math.floor(2 * base.Hp * level / 100) + level + 10) * bonus),
		Atk = stat(base.Atk),
		Def = stat(base.Def),
		Spd = stat(base.Spd),
	}
end

-- Kampfkraft fuer Anzeige und Sortierung
function Beasts.Power(beastId: string, level: number, shiny: boolean?): number
	local s = Beasts.Stats(beastId, level, shiny)
	return math.floor(s.MaxHp / 2 + s.Atk + s.Def + s.Spd)
end

-- EP vom aktuellen zum naechsten Level ("mittel-schnell": Level^3 insgesamt)
function Beasts.XpToNext(level: number): number
	return (level + 1) ^ 3 - level ^ 3
end

-- EP fuer das Besiegen einer Bestie
function Beasts.XpYield(beastId: string, level: number, trainer: boolean): number
	local rarity = Beasts.RaritiesByName[Beasts.ById[beastId].Rarity]
	return math.floor(rarity.Yield * level / 7 * (if trainer then 1.5 else 1))
end

function Beasts.StageMultiplier(stage: number): number
	if stage >= 0 then
		return (2 + stage) / 2
	end
	return 2 / (2 - stage)
end

-- Wirkung einer Attacke auf eine Bestie (beide Elemente zaehlen)
function Beasts.Effectiveness(moveType: string, beastId: string): number
	local def = Beasts.ById[beastId]
	return Beasts.TypeMultiplier(moveType, def.Type) * Beasts.TypeMultiplier(moveType, def.Type2)
end

-- Fangchance (0..1) nach der Formel des Klassikers. orb = Ball-Bonus, luck = Pass-Bonus
function Beasts.CatchChance(beastId: string, hp: number, maxHp: number, status: string?, orb: number, luck: number): number
	if orb == math.huge then
		return 1
	end
	local rarity = Beasts.RaritiesByName[Beasts.ById[beastId].Rarity]
	local statusBonus = if status == "Sleep" or status == "Freeze" then 2 elseif status then 1.5 else 1
	local a = (3 * maxHp - 2 * hp) * rarity.CatchRate * orb / (3 * maxHp) * statusBonus * luck
	return math.clamp(a / 255, 0.01, 1)
end

return Beasts
