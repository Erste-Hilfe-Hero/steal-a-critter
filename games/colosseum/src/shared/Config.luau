-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Colosseum Catcher.
-- Alle Bestien, Namen und Modelle sind eigene Erfindungen (keine fremden Marken oder Assets).
-- Produkt-IDs kommen automatisch aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Solange eine ID 0 ist, kann man den Kauf in Studio ueber den Shop simulieren.

local Config = {}

Config.DataStoreName = "ColosseumData_v1"

---------------------------------------------------------------- Wirtschaft

Config.StartCoins = 150
Config.StartItems = { Orb = 5, Potion = 3 }
Config.Starters = { "cindercub", "puddlit", "sproutling" }
Config.TeamSize = 3
Config.BigTeamSize = 5
Config.MaxStorage = 60
Config.MaxLevel = 60

-- Multiplikatoren
Config.VipCoins = 1.5
Config.VipXp = 1.25
Config.DoubleCoins = 2
Config.DoubleXp = 2
Config.BoostMultiplier = 2 -- 30-Minuten-Boost: Muenzen und XP
Config.PremiumMultiplier = 1.2 -- belohnt Premium-Spieler, erhoeht die Premium Payouts
Config.LuckyCatchMultiplier = 1.3
Config.ShinyChance = 1 / 250
Config.ShinyHunterMultiplier = 3
Config.ServerShinyMultiplier = 2
Config.ShinyStatMultiplier = 1.2
Config.DefaultWalkSpeed = 18
Config.SpeedWalkSpeed = 28

-- Gegenstaende fuer Muenzen (im Laden am Spawn und im Kampf nutzbar)
Config.Items = {
	Orb = { Name = "Catch Orb", Price = 40, Catch = 1, Color = Color3.fromRGB(230, 70, 60), Order = 1, Description = "Throw it at a weakened wild beast" },
	GreatOrb = { Name = "Great Orb", Price = 200, Catch = 1.7, Color = Color3.fromRGB(70, 140, 255), Order = 2, Description = "1.7x catch chance" },
	MasterOrb = { Name = "Master Orb", Price = 0, Catch = math.huge, Color = Color3.fromRGB(190, 90, 255), Order = 3, Description = "Always catches. Robux only" },
	Potion = { Name = "Potion", Price = 30, Heal = 0.5, Color = Color3.fromRGB(90, 220, 120), Order = 4, Description = "Heals 50% HP in battle" },
	SuperPotion = { Name = "Super Potion", Price = 120, Heal = 1, Color = Color3.fromRGB(255, 200, 60), Order = 5, Description = "Heals 100% HP in battle" },
}

function Config.XpToNext(level: number): number
	return math.floor(18 * level ^ 1.55)
end

---------------------------------------------------------------- Elemente

Config.Types = {
	Normal = { Color = Color3.fromRGB(200, 195, 185), Strong = {} },
	Fire = { Color = Color3.fromRGB(255, 110, 50), Strong = { Leaf = true } },
	Water = { Color = Color3.fromRGB(60, 150, 255), Strong = { Fire = true, Stone = true } },
	Leaf = { Color = Color3.fromRGB(90, 200, 90), Strong = { Water = true, Stone = true } },
	Spark = { Color = Color3.fromRGB(255, 215, 50), Strong = { Water = true } },
	Stone = { Color = Color3.fromRGB(180, 140, 95), Strong = { Fire = true, Spark = true } },
	Shadow = { Color = Color3.fromRGB(150, 80, 220), Strong = { Light = true, Spark = true } },
	Light = { Color = Color3.fromRGB(255, 240, 160), Strong = { Shadow = true } },
}
Config.SuperEffective = 1.6
Config.NotEffective = 0.6

-- Wirkung eines Angriffs von attackType auf defendType
function Config.TypeMultiplier(attackType: string, defendType: string): number
	local attack = Config.Types[attackType]
	local defend = Config.Types[defendType]
	if not attack or not defend then
		return 1
	end
	if attack.Strong[defendType] then
		return Config.SuperEffective
	end
	if defend.Strong[attackType] then
		return Config.NotEffective
	end
	return 1
end

-- Jede Bestie kennt: Strike (Normal), Elementangriff und ab Stufe 3 bzw. Level 25 den Ultimativen Angriff.
-- Power = Staerke, Accuracy = Trefferchance, Uses = Anzahl pro Kampf (nil = unbegrenzt).
Config.Moves = {
	Strike = { Name = "Strike", Type = "Normal", Power = 40, Accuracy = 1 },
	Fire = { Name = "Ember Burst", Type = "Fire", Power = 70, Accuracy = 0.9, Ultimate = "Inferno Roar" },
	Water = { Name = "Tide Splash", Type = "Water", Power = 70, Accuracy = 0.9, Ultimate = "Tsunami Crash" },
	Leaf = { Name = "Vine Lash", Type = "Leaf", Power = 70, Accuracy = 0.9, Ultimate = "Bloom Storm" },
	Spark = { Name = "Zap Bolt", Type = "Spark", Power = 70, Accuracy = 0.9, Ultimate = "Thunder Fang" },
	Stone = { Name = "Rock Slam", Type = "Stone", Power = 70, Accuracy = 0.9, Ultimate = "Quake Smash" },
	Shadow = { Name = "Night Claw", Type = "Shadow", Power = 70, Accuracy = 0.9, Ultimate = "Void Eclipse" },
	Light = { Name = "Glow Beam", Type = "Light", Power = 70, Accuracy = 0.9, Ultimate = "Solar Flare" },
}
Config.UltimatePower = 120
Config.UltimateAccuracy = 0.85
Config.UltimateUses = 2
Config.UltimateLevel = 25
Config.CritChance = 0.07
Config.CritMultiplier = 1.5
Config.TurnTimeout = 20 -- Sekunden, danach greift die Bestie automatisch an

---------------------------------------------------------------- Seltenheit

-- Catch = Grundchance bei voller Gesundheit ist Catch * 0.45, bei fast leerer bis Catch * 1.25
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Catch = 0.75, Xp = 1 },
	{ Name = "Rare", Color = Color3.fromRGB(80, 160, 255), Catch = 0.5, Xp = 1.4 },
	{ Name = "Epic", Color = Color3.fromRGB(190, 90, 255), Catch = 0.3, Xp = 1.8, Glow = true },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 195, 50), Catch = 0.12, Xp = 2.5, Glow = true, Crown = true, Announce = true },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 70, 110), Catch = 0.06, Xp = 3.5, Glow = true, Crown = true, Announce = true },
}

---------------------------------------------------------------- Bestien

-- Werte-Profile: Hp, Atk, Def, Spd (Level 1). Spaetere Stufen sind staerker.
local function stats(hp: number, atk: number, def: number, spd: number, scale: number)
	return { Hp = math.floor(hp * scale), Atk = math.floor(atk * scale), Def = math.floor(def * scale), Spd = math.floor(spd * scale) }
end

-- Body: Quad, Biped, Bird, Blob, Lizard, Frog, Ghost, Dragon. Extras: zusaetzliche Merkmale fuer das Modell.
Config.Beasts = {
	-- Feuer
	{ Id = "cindercub", Name = "Cindercub", Type = "Fire", Rarity = "Common", Body = "Quad", Color = Color3.fromRGB(255, 130, 60), Extras = { "Ears", "Tail" }, Base = stats(44, 52, 40, 55, 1), Evolve = { To = "blazehound", Level = 16 } },
	{ Id = "blazehound", Name = "Blazehound", Type = "Fire", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(235, 90, 40), Extras = { "Ears", "Tail", "Spikes" }, Base = stats(44, 52, 40, 55, 1.35), Evolve = { To = "infernox", Level = 34 } },
	{ Id = "infernox", Name = "Infernox", Type = "Fire", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(200, 50, 30), Extras = { "Horns", "Tail", "Spikes", "Mane" }, Base = stats(44, 52, 40, 55, 1.75) },
	-- Wasser
	{ Id = "puddlit", Name = "Puddlit", Type = "Water", Rarity = "Common", Body = "Frog", Color = Color3.fromRGB(80, 170, 255), Extras = {}, Base = stats(50, 45, 50, 45, 1), Evolve = { To = "tidefin", Level = 16 } },
	{ Id = "tidefin", Name = "Tidefin", Type = "Water", Rarity = "Rare", Body = "Lizard", Color = Color3.fromRGB(50, 130, 230), Extras = { "Fin", "Tail" }, Base = stats(50, 45, 50, 45, 1.35), Evolve = { To = "abyssaur", Level = 34 } },
	{ Id = "abyssaur", Name = "Abyssaur", Type = "Water", Rarity = "Epic", Body = "Dragon", Color = Color3.fromRGB(30, 80, 190), Extras = { "Fin", "Tail", "Horns" }, Base = stats(50, 45, 50, 45, 1.75) },
	-- Blatt
	{ Id = "sproutling", Name = "Sproutling", Type = "Leaf", Rarity = "Common", Body = "Blob", Color = Color3.fromRGB(120, 210, 90), Extras = { "Sprout" }, Base = stats(48, 47, 52, 43, 1), Evolve = { To = "thornback", Level = 16 } },
	{ Id = "thornback", Name = "Thornback", Type = "Leaf", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(80, 170, 70), Extras = { "Shell", "Sprout" }, Base = stats(48, 47, 52, 43, 1.35), Evolve = { To = "verdantusk", Level = 34 } },
	{ Id = "verdantusk", Name = "Verdantusk", Type = "Leaf", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(50, 130, 60), Extras = { "Shell", "Horns", "Flower" }, Base = stats(48, 47, 52, 43, 1.75) },
	-- Blitz
	{ Id = "zapkit", Name = "Zapkit", Type = "Spark", Rarity = "Common", Body = "Quad", Color = Color3.fromRGB(255, 220, 70), Extras = { "BigEars", "Tail" }, Base = stats(40, 50, 38, 62, 1), Evolve = { To = "voltlynx", Level = 18 } },
	{ Id = "voltlynx", Name = "Voltlynx", Type = "Spark", Rarity = "Rare", Body = "Quad", Color = Color3.fromRGB(245, 195, 40), Extras = { "Ears", "Tail", "Bolt" }, Base = stats(40, 50, 38, 62, 1.35), Evolve = { To = "thundermane", Level = 36 } },
	{ Id = "thundermane", Name = "Thundermane", Type = "Spark", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(230, 170, 20), Extras = { "Ears", "Tail", "Bolt", "Mane" }, Base = stats(40, 50, 38, 62, 1.75) },
	-- Stein
	{ Id = "pebblit", Name = "Pebblit", Type = "Stone", Rarity = "Common", Body = "Blob", Color = Color3.fromRGB(170, 150, 125), Extras = { "Rocky" }, Base = stats(52, 48, 60, 30, 1), Evolve = { To = "bouldergrub", Level = 18 } },
	{ Id = "bouldergrub", Name = "Bouldergrub", Type = "Stone", Rarity = "Rare", Body = "Lizard", Color = Color3.fromRGB(150, 120, 90), Extras = { "Rocky", "Spikes" }, Base = stats(52, 48, 60, 30, 1.35), Evolve = { To = "titanshell", Level = 36 } },
	{ Id = "titanshell", Name = "Titanshell", Type = "Stone", Rarity = "Epic", Body = "Quad", Color = Color3.fromRGB(120, 95, 70), Extras = { "Rocky", "Shell", "Horns" }, Base = stats(52, 48, 60, 30, 1.75) },
	-- Schatten
	{ Id = "shadewisp", Name = "Shadewisp", Type = "Shadow", Rarity = "Common", Body = "Ghost", Color = Color3.fromRGB(120, 80, 190), Extras = {}, Base = stats(40, 55, 38, 57, 1), Evolve = { To = "duskmaw", Level = 20 } },
	{ Id = "duskmaw", Name = "Duskmaw", Type = "Shadow", Rarity = "Rare", Body = "Biped", Color = Color3.fromRGB(90, 55, 150), Extras = { "Horns", "Tail" }, Base = stats(40, 55, 38, 57, 1.35), Evolve = { To = "nightreign", Level = 38 } },
	{ Id = "nightreign", Name = "Nightreign", Type = "Shadow", Rarity = "Epic", Body = "Dragon", Color = Color3.fromRGB(60, 35, 110), Extras = { "Horns", "Tail", "BatWings" }, Base = stats(40, 55, 38, 57, 1.75) },
	-- Licht
	{ Id = "glimmoth", Name = "Glimmoth", Type = "Light", Rarity = "Common", Body = "Bird", Color = Color3.fromRGB(255, 240, 180), Extras = { "Antenna" }, Base = stats(42, 48, 42, 56, 1), Evolve = { To = "lumiwing", Level = 20 } },
	{ Id = "lumiwing", Name = "Lumiwing", Type = "Light", Rarity = "Rare", Body = "Bird", Color = Color3.fromRGB(255, 225, 130), Extras = { "Antenna", "Comb" }, Base = stats(42, 48, 42, 56, 1.35), Evolve = { To = "solarion", Level = 38 } },
	{ Id = "solarion", Name = "Solarion", Type = "Light", Rarity = "Epic", Body = "Bird", Color = Color3.fromRGB(255, 200, 60), Extras = { "Comb", "Halo", "LongNeck" }, Base = stats(42, 48, 42, 56, 1.75) },
	-- Legenden (nur in spaeten Zonen, sehr selten)
	{ Id = "aurelion", Name = "Aurelion", Type = "Light", Rarity = "Legendary", Body = "Quad", Color = Color3.fromRGB(255, 235, 200), Extras = { "Mane", "Halo", "Tail" }, Base = stats(50, 56, 50, 58, 1.95) },
	{ Id = "colossix", Name = "Colossix", Type = "Stone", Rarity = "Legendary", Body = "Biped", Color = Color3.fromRGB(205, 175, 120), Extras = { "Rocky", "Helmet", "Horns" }, Base = stats(55, 56, 55, 40, 1.95) },
	{ Id = "voidrake", Name = "Voidrake", Type = "Shadow", Rarity = "Mythic", Body = "Dragon", Color = Color3.fromRGB(35, 20, 60), Extras = { "Horns", "Tail", "BatWings", "Halo" }, Base = stats(55, 62, 52, 60, 2.2) },
}

---------------------------------------------------------------- Welt

-- Wildnis-Zonen rund um das Kolosseum. Crests = noetige Wappen aus der Arena, um das Tor zu oeffnen.
-- Spawns: Gewicht = relative Haeufigkeit. Levels = Spanne der wilden Bestien.
Config.Zones = {
	{ Name = "Sunny Meadow", Crests = 0, Center = Vector3.new(-170, 0, 150), Radius = 75, Levels = { 2, 9 }, Ground = Color3.fromRGB(110, 175, 80), Material = Enum.Material.Grass, Accent = Color3.fromRGB(255, 220, 120), Spawns = {
		{ Beast = "cindercub", Weight = 20 }, { Beast = "puddlit", Weight = 20 }, { Beast = "sproutling", Weight = 20 }, { Beast = "zapkit", Weight = 16 }, { Beast = "glimmoth", Weight = 16 }, { Beast = "pebblit", Weight = 8 },
	} },
	{ Name = "Ember Crater", Crests = 1, Center = Vector3.new(210, 0, 40), Radius = 75, Levels = { 10, 19 }, Ground = Color3.fromRGB(95, 60, 50), Material = Enum.Material.Basalt, Accent = Color3.fromRGB(255, 110, 40), Spawns = {
		{ Beast = "cindercub", Weight = 18 }, { Beast = "pebblit", Weight = 22 }, { Beast = "zapkit", Weight = 14 }, { Beast = "blazehound", Weight = 8 }, { Beast = "bouldergrub", Weight = 8 }, { Beast = "shadewisp", Weight = 10 }, { Beast = "colossix", Weight = 0.15 },
	} },
	{ Name = "Storm Coast", Crests = 3, Center = Vector3.new(30, 0, -220), Radius = 75, Levels = { 20, 31 }, Ground = Color3.fromRGB(215, 200, 150), Material = Enum.Material.Sand, Accent = Color3.fromRGB(80, 200, 255), Spawns = {
		{ Beast = "puddlit", Weight = 12 }, { Beast = "tidefin", Weight = 16 }, { Beast = "voltlynx", Weight = 14 }, { Beast = "lumiwing", Weight = 12 }, { Beast = "thornback", Weight = 12 }, { Beast = "abyssaur", Weight = 1.5 }, { Beast = "aurelion", Weight = 0.15 },
	} },
	{ Name = "Shadow Ruins", Crests = 5, Center = Vector3.new(-230, 0, -110), Radius = 75, Levels = { 32, 45 }, Ground = Color3.fromRGB(60, 50, 75), Material = Enum.Material.Slate, Accent = Color3.fromRGB(170, 90, 255), Spawns = {
		{ Beast = "duskmaw", Weight = 18 }, { Beast = "shadewisp", Weight = 10 }, { Beast = "bouldergrub", Weight = 10 }, { Beast = "voltlynx", Weight = 10 }, { Beast = "nightreign", Weight = 2 }, { Beast = "infernox", Weight = 1.5 }, { Beast = "titanshell", Weight = 1.5 }, { Beast = "voidrake", Weight = 0.06 },
	} },
}
Config.WildPerZone = 10
Config.WildRespawn = 6
Config.SpawnCFrame = CFrame.new(0, 3, 120)
Config.ColosseumRadius = 62

-- Arena: 8 Champions. Wer gewinnt, bekommt ihr Wappen (oeffnet neue Zonen) und Muenzen.
Config.Champions = {
	{ Name = "Rookie Rufus", Title = "Gate Keeper", Coins = 300, Team = { { "zapkit", 6 }, { "cindercub", 7 } } },
	{ Name = "Brawler Bea", Title = "Sand Fighter", Coins = 800, Team = { { "pebblit", 10 }, { "sproutling", 11 }, { "puddlit", 12 } } },
	{ Name = "Captain Coral", Title = "Tide Master", Coins = 1_800, Team = { { "puddlit", 16 }, { "tidefin", 18 }, { "zapkit", 17 } } },
	{ Name = "Ignis the Red", Title = "Flame Lord", Coins = 3_500, Team = { { "blazehound", 22 }, { "cindercub", 21 }, { "bouldergrub", 23 } } },
	{ Name = "Volt Vera", Title = "Storm Queen", Coins = 6_000, Team = { { "voltlynx", 27 }, { "lumiwing", 27 }, { "tidefin", 28 } } },
	{ Name = "Grim Garrick", Title = "Night Warden", Coins = 10_000, Team = { { "duskmaw", 31 }, { "thornback", 30 }, { "bouldergrub", 31 } } },
	{ Name = "Lady Lumen", Title = "Sun Oracle", Coins = 16_000, Team = { { "solarion", 38 }, { "verdantusk", 38 }, { "thundermane", 39 } } },
	{ Name = "Emperor Maximus", Title = "Grand Champion", Coins = 30_000, Team = { { "infernox", 42 }, { "abyssaur", 42 }, { "colossix", 40 } } },
}
Config.ChampionRematch = 0.25 -- Anteil der Muenzen bei Wiederholung

-- Endlose Gauntlet-Wellen: Gegner werden immer staerker, Muenzen pro Welle, Bestenliste
Config.GauntletCoinsPerWave = 60
function Config.GauntletLevel(wave: number): number
	return math.min(Config.MaxLevel, 3 + math.floor(wave * 1.6))
end

-- Duelle zwischen Spielern
Config.DuelTrophies = 10
Config.DuelInviteSeconds = 20

---------------------------------------------------------------- Monetarisierung

-- Pässe werden als Developer Products verkauft und dauerhaft gespeichert (lassen sich per API anlegen).
-- AffectsRandom: veraendert Zufallsergebnisse -> in Laendern mit Lootbox-Verbot (PolicyService) ausgeblendet.
Config.GamePasses = {
	VIP = { Id = 0, ProductId = 0, Name = "VIP", Description = "x1.5 coins, x1.25 XP, golden name + VIP tag", PriceHint = 249, Order = 1 },
	DoubleCoins = { Id = 0, ProductId = 0, Name = "2x Coins", Description = "Double coins from every battle forever", PriceHint = 299, Order = 2 },
	DoubleXp = { Id = 0, ProductId = 0, Name = "2x XP", Description = "Your beasts level up twice as fast", PriceHint = 249, Order = 3 },
	BigTeam = { Id = 0, ProductId = 0, Name = "Big Team", Description = "Bring 5 beasts into battle instead of 3", PriceHint = 299, Order = 4 },
	ShinyHunter = { Id = 0, ProductId = 0, Name = "Prismatic Hunter", Description = "3x chance to meet PRISMATIC beasts", PriceHint = 349, Order = 5, AffectsRandom = true },
	LuckyCatch = { Id = 0, ProductId = 0, Name = "Lucky Catcher", Description = "x1.3 catch chance with every orb", PriceHint = 199, Order = 6, AffectsRandom = true },
	AutoBattle = { Id = 0, ProductId = 0, Name = "Auto Battle", Description = "Your beasts pick the best move by themselves", PriceHint = 149, Order = 7 },
	Speed = { Id = 0, ProductId = 0, Name = "Speed", Description = "Run faster forever", PriceHint = 99, Order = 8 },
}

-- Developer Products: beliebig oft kaufbar (ausser OneTime).
Config.DevProducts = {
	MasterOrb1 = { Id = 0, Kind = "Item", Item = "MasterOrb", Amount = 1, Name = "Master Orb", Description = "Always catches - even legends!", PriceHint = 49, Order = 1 },
	MasterOrb5 = { Id = 0, Kind = "Item", Item = "MasterOrb", Amount = 5, Name = "5 Master Orbs", Description = "5 orbs that always catch (save 20%)", PriceHint = 199, Order = 2 },
	StarterPack = { Id = 0, Kind = "Starter", Name = "Starter Pack", Description = "One time only: 3 Master Orbs, 10 Great Orbs, 5,000 coins, 30 min 2x boost", PriceHint = 79, Order = 3, OneTime = true },
	CoinsSmall = { Id = 0, Kind = "Coins", Battles = 10, Name = "Coin Pouch", Description = "Coins for about 10 battles at your level", PriceHint = 49, Order = 4, AffectsRandom = true },
	CoinsMedium = { Id = 0, Kind = "Coins", Battles = 50, Name = "Coin Chest", Description = "Coins for about 50 battles at your level", PriceHint = 199, Order = 5, AffectsRandom = true },
	CoinsLarge = { Id = 0, Kind = "Coins", Battles = 200, Name = "Coin Treasury", Description = "Coins for about 200 battles at your level", PriceHint = 699, Order = 6, AffectsRandom = true },
	Boost = { Id = 0, Kind = "Boost", Seconds = 1800, Name = "2x Coins + XP (30 min)", Description = "Double coins and XP for 30 minutes", PriceHint = 99, Order = 7 },
	PowerSnack = { Id = 0, Kind = "Levels", Amount = 5, Name = "Power Snack", Description = "+5 levels for your lead beast", PriceHint = 49, Order = 8 },
	EvoCrystal = { Id = 0, Kind = "Evolve", Name = "Ascension Crystal", Description = "Your lead beast ascends to its next form NOW", PriceHint = 99, Order = 9 },
	SkipChampion = { Id = 0, Kind = "Skip", Name = "Champion Pass", Description = "Instantly earn the next champion crest", PriceHint = 149, Order = 10 },
	FullHeal = { Id = 0, Kind = "Heal", Name = "Full Heal", Description = "Heal your whole team anywhere", PriceHint = 15, Order = 11 },
	GauntletContinue = { Id = 0, Kind = "Continue", Name = "Gauntlet Second Chance", Description = "Revive your team and keep your gauntlet streak", PriceHint = 29, Order = 12, Hidden = true },
	ServerShiny = { Id = 0, Kind = "ServerShiny", Seconds = 900, Name = "Prismatic Storm", Description = "15 min: PRISMATIC beasts x2 for EVERYONE", PriceHint = 199, Order = 13, AffectsRandom = true },
	Storage = { Id = 0, Kind = "Storage", Amount = 50, Name = "+50 Beast Storage", Description = "Keep 50 more beasts", PriceHint = 99, Order = 14 },
	AdReward = { Id = 0, Kind = "Item", Item = "GreatOrb", Amount = 3, Name = "Free Great Orbs (Video Ad)", Description = "Reward for watching a video ad: 3 Great Orbs", PriceHint = 5, Order = 99, Hidden = true },
}
Config.AdCooldown = 300
Config.OfferCooldown = 150 -- Sekunden zwischen zwei Kaufangeboten

-- Taegliche Belohnung (waechst mit der Serie, max. 7 Tage)
Config.DailyRewards = {
	{ Coins = 200, Items = { Orb = 3 } },
	{ Coins = 300, Items = { Potion = 3 } },
	{ Coins = 500, Items = { GreatOrb = 2 } },
	{ Coins = 700, Items = { SuperPotion = 2 } },
	{ Coins = 1_000, Items = { GreatOrb = 4 } },
	{ Coins = 1_500, Items = { SuperPotion = 3 } },
	{ Coins = 2_500, Items = { MasterOrb = 1 } },
}

Config.Codes = {
	COLOSSEUM = { Coins = 500, Items = { Orb = 5 } },
	CATCHEMALL = { Items = { GreatOrb = 5 } },
	BIGBABA = { Coins = 1_000, Items = { Potion = 5 } },
}

-- Community-Raenge: nur aktive Spielzeit zaehlt (wer 2 Minuten nichts tut, gilt als AFK).
Config.OwnerUserIds = { 2979321382 } -- BigBabaAli
Config.AfkTimeout = 120
Config.Ranks = {
	{ Name = "Newbie", Hours = 0, Days = 0, Color = "#C8C8C8", Rights = {} },
	{ Name = "Member", Hours = 1, Days = 1, Color = "#78DCFF", Rights = { Vote = true } },
	{ Name = "Regular", Hours = 5, Days = 3, Color = "#55DC6E", Rights = { VoteKick = true } },
	{ Name = "Veteran", Hours = 20, Days = 7, Color = "#B450FF", Rights = { Announce = true } },
	{ Name = "Guardian", Hours = 50, Days = 14, Color = "#FFBE28", Rights = { Kick = true } },
}
Config.VoteKickDuration = 30
Config.VoteKickMinVotes = 3
Config.AnnounceCooldown = 600
Config.GuardianKickCooldown = 60

-- In Studio Kaeufe mit ID 0 simulieren, damit alles testbar ist
Config.StudioFakePurchases = true

---------------------------------------------------------------- Abgeleitete Tabellen

-- Produkt-IDs eintragen (Schluessel = "key" in products.json, z. B. "Pass_VIP" oder "MasterOrb1")
local idsModule = script.Parent:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

Config.BeastsById = {}
for _, beast in Config.Beasts do
	Config.BeastsById[beast.Id] = beast
end
-- Vorstufen merken (fuer die Anzeige "ascends from")
for _, beast in Config.Beasts do
	if beast.Evolve then
		Config.BeastsById[beast.Evolve.To].From = beast.Id
	end
end

Config.RaritiesByName = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RaritiesByName[rarity.Name] = rarity
end

-- Werte einer Bestie auf einem Level
function Config.Stats(beastId: string, level: number, shiny: boolean?)
	local def = Config.BeastsById[beastId]
	local factor = 1 + (level - 1) * 0.09
	local bonus = if shiny then Config.ShinyStatMultiplier else 1
	return {
		MaxHp = math.floor((def.Base.Hp * 1.6 * factor + 12) * bonus),
		Atk = math.floor(def.Base.Atk * factor * bonus),
		Def = math.floor(def.Base.Def * factor * bonus),
		Spd = math.floor(def.Base.Spd * factor * bonus),
	}
end

-- Kampfkraft fuer Anzeige und Sortierung
function Config.Power(beastId: string, level: number, shiny: boolean?): number
	local s = Config.Stats(beastId, level, shiny)
	return math.floor((s.MaxHp / 2 + s.Atk + s.Def + s.Spd) / 2)
end

-- Liste der Angriffe einer Bestie (Schluessel fuer den Kampf)
function Config.MovesFor(beastId: string, level: number): { string }
	local def = Config.BeastsById[beastId]
	local list = { "Strike", def.Type }
	local rarity = Config.RaritiesByName[def.Rarity]
	if level >= Config.UltimateLevel or rarity.Index >= 3 then
		table.insert(list, "Ultimate")
	end
	return list
end

function Config.MoveInfo(beastId: string, moveKey: string)
	local def = Config.BeastsById[beastId]
	if moveKey == "Ultimate" then
		local base = Config.Moves[def.Type]
		return { Name = base.Ultimate, Type = def.Type, Power = Config.UltimatePower, Accuracy = Config.UltimateAccuracy, Uses = Config.UltimateUses }
	end
	return Config.Moves[moveKey]
end

-- Fangchance (0..1). hpFraction = verbleibende Gesundheit des Gegners.
function Config.CatchChance(beastId: string, hpFraction: number, orbMultiplier: number, luck: number): number
	if orbMultiplier == math.huge then
		return 1
	end
	local rarity = Config.RaritiesByName[Config.BeastsById[beastId].Rarity]
	local chance = rarity.Catch * (1.25 - 0.8 * math.clamp(hpFraction, 0, 1)) * orbMultiplier * luck
	return math.clamp(chance, 0.01, 0.97)
end

return Config
