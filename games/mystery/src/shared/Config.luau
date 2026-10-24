-- Alle Spielwerte an einem Ort: Runden, Rollen, Waffen, Faehigkeiten, Skins, Kisten, Battle Pass, Produkte.
-- Texte fuer Spieler sind Englisch (groesseres Publikum), Kommentare Deutsch.
local ProductIds = require(script.Parent:WaitForChild("ProductIds"))

local Config = {}

Config.GameName = "Midnight Mystery"
Config.DataStoreName = "MidnightMystery_v1"
Config.StudioFakePurchases = true
Config.OwnerUserId = 2979321382

Config.Colors = {
	Night = Color3.fromRGB(14, 16, 38),
	Panel = Color3.fromRGB(26, 29, 64),
	Panel2 = Color3.fromRGB(38, 42, 88),
	Edge = Color3.fromRGB(92, 102, 190),
	Moon = Color3.fromRGB(255, 214, 102),
	Pink = Color3.fromRGB(255, 92, 170),
	Cyan = Color3.fromRGB(80, 220, 255),
	White = Color3.fromRGB(245, 246, 255),
	Muted = Color3.fromRGB(160, 168, 220),
	Red = Color3.fromRGB(255, 72, 88),
	Green = Color3.fromRGB(90, 230, 120),
	Blue = Color3.fromRGB(70, 150, 255),
	Gold = Color3.fromRGB(255, 200, 40),
	Orange = Color3.fromRGB(255, 150, 50),
	Purple = Color3.fromRGB(170, 100, 255),
}

---------------------------------------------------------------- Runden

Config.Round = {
	Intermission = 20, -- Lobby-Zeit inkl. Map-Abstimmung
	RevealTime = 5, -- Rollenkarte, Waffen kommen danach
	Duration = 180, -- Unschuldige gewinnen, wenn die Zeit ablaeuft
	ResultsTime = 9,
	MinActors = 5, -- mit Bots aufgefuellt, damit man sofort spielen kann
	MaxBots = 5,
	BotsUntilHumans = 7, -- ab so vielen echten Spielern keine Bots mehr
	DuoAt = 12, -- ab so vielen Teilnehmern: 2 Murderer + 2 Sheriffs
	MapVotes = 3,
	ModifierChance = 0.35,
}

Config.Roles = {
	Murderer = { Name = "Murderer", Color = Color3.fromRGB(255, 72, 88), Goal = "KO everyone without getting caught!" },
	Sheriff = { Name = "Sheriff", Color = Color3.fromRGB(70, 150, 255), Goal = "Find the Murderer and stop them!" },
	Innocent = { Name = "Innocent", Color = Color3.fromRGB(90, 230, 120), Goal = "Hide, collect coins and survive!" },
	Hero = { Name = "Hero", Color = Color3.fromRGB(255, 200, 40), Goal = "You picked up the blaster. Stop the Murderer!" },
}

-- Rollenchancen: jede Runde ohne Rolle erhoeht die Chance (Werte = Lose)
Config.RoleTickets = { Base = 10, PerRound = 10, VIPBonus = 0 }

Config.Coins = {
	Bag = 40, -- Muenzen pro Runde (wie MM2)
	VIPBag = 10,
	BigBag = 20,
	SpawnEvery = 1.2,
	MaxOnMap = 30,
	WinBonus = 10,
	SurviveBonus = 5,
	FriendBoost = 0.1, -- pro Freund im Server
	FriendBoostMax = 0.3,
}

Config.XP = {
	Round = 20,
	Survive = 40,
	Win = 60,
	KO = 20, -- Murderer pro K.O.
	StopMurderer = 80, -- Sheriff/Hero trifft den Murderer
	PerCoin = 2,
	BoostMultiplier = 2,
}

function Config.XPForLevel(level: number): number
	return 120 + level * 30
end

Config.PrestigeLevel = 50

---------------------------------------------------------------- Waffen

Config.Knife = {
	Range = 7,
	Cooldown = 0.8,
	ThrowCooldown = 4,
	ThrowSpeed = 120,
	ThrowRange = 220,
	GraceAfterReveal = 5, -- Murderer bekommt das Messer erst nach der Rollenkarte
}

Config.Gun = {
	Cooldown = 2.2,
	Range = 320,
	DropPickupDelay = 1.5,
}

Config.WalkSpeed = 16
Config.SprintSpeed = 22
Config.SprintStamina = 4 -- Sekunden
Config.SprintRegen = 0.5 -- pro Sekunde

---------------------------------------------------------------- Faehigkeiten (Extras gegenueber MM2)

Config.Abilities = {
	Dash = { Role = "Murderer", Name = "Dash", Key = "Q", Cooldown = 12, Text = "Burst forward" },
	Cloak = { Role = "Murderer", Name = "Shadow", Key = "F", Cooldown = 45, Duration = 3.5, Text = "Turn almost invisible" },
	Trap = { Role = "Murderer", Name = "Glue Trap", Key = "R", Cooldown = 30, Duration = 3, Text = "Sticky trap slows victims" },
	Scan = { Role = "Sheriff", Name = "Scanner", Key = "Q", Cooldown = 30, Duration = 5, Text = "Reveal the Murderer's footprints" },
	Sprint = { Role = "Innocent", Name = "Sprint", Key = "Shift", Cooldown = 0, Text = "Run faster (stamina)" },
}

Config.Hide = { MaxTime = 15, Cooldown = 18 }
Config.Vent = { Cooldown = 8 }
Config.Door = { LockTime = 5, Cooldown = 15 }

-- Power-Up-Kisten auf der Karte (kostenlos, zufaellig)
Config.PowerUps = {
	SpawnEvery = 22,
	Max = 3,
	List = {
		{ Id = "Speed", Name = "Speed Soda", Duration = 6, Color = Color3.fromRGB(80, 220, 255) },
		{ Id = "Shield", Name = "Bubble Shield", Duration = 15, Color = Color3.fromRGB(170, 100, 255) },
		{ Id = "Magnet", Name = "Coin Magnet", Duration = 8, Color = Color3.fromRGB(255, 200, 40) },
		{ Id = "Ghost", Name = "Ghost Mode", Duration = 4, Color = Color3.fromRGB(230, 230, 255) },
	},
}

---------------------------------------------------------------- Runden-Modifikatoren

Config.Modifiers = {
	{ Id = "Blackout", Name = "BLACKOUT", Text = "The lights are out - use your flashlight!", Color = Color3.fromRGB(120, 120, 200) },
	{ Id = "DoubleCoins", Name = "DOUBLE COINS", Text = "Every coin counts twice!", Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "LowGravity", Name = "MOON GRAVITY", Text = "Jump higher than ever!", Color = Color3.fromRGB(200, 220, 255) },
	{ Id = "Speedy", Name = "SPEED RUSH", Text = "Everyone runs faster!", Color = Color3.fromRGB(80, 220, 255) },
	{ Id = "Fog", Name = "MIDNIGHT FOG", Text = "Thick fog - trust no one!", Color = Color3.fromRGB(150, 160, 190) },
	{ Id = "GoldRush", Name = "GOLD RUSH", Text = "Coins rain down twice as fast!", Color = Color3.fromRGB(255, 170, 40) },
}

---------------------------------------------------------------- Karten

Config.Maps = {
	{ Id = "Manor", Name = "Moonlight Manor", Cols = 3, Rows = 3, Theme = "Manor" },
	{ Id = "Arcade", Name = "Neon Arcade", Cols = 4, Rows = 2, Theme = "Arcade" },
	{ Id = "Lodge", Name = "Frosty Lodge", Cols = 3, Rows = 3, Theme = "Lodge" },
	{ Id = "School", Name = "Spooky School", Cols = 4, Rows = 3, Theme = "School" },
	{ Id = "Lab", Name = "Starlight Lab", Cols = 3, Rows = 3, Theme = "Lab" },
}
Config.RoomSize = 42
Config.WallHeight = 16
Config.MapOrigin = Vector3.new(0, 0, 900)

---------------------------------------------------------------- Seltenheiten, Skins, Kisten

Config.Rarities = {
	{ Id = "Common", Color = Color3.fromRGB(190, 196, 220), Weight = 55, Price = 300 },
	{ Id = "Uncommon", Color = Color3.fromRGB(90, 230, 120), Weight = 26, Price = 800 },
	{ Id = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 13, Price = 2000 },
	{ Id = "Legendary", Color = Color3.fromRGB(255, 92, 170), Weight = 5, Price = 6000 },
	{ Id = "Godly", Color = Color3.fromRGB(255, 200, 40), Weight = 1, Price = 18000 },
	{ Id = "Midnight", Color = Color3.fromRGB(170, 100, 255), Weight = 0, Price = 0 }, -- nur Battle Pass / Bundles
}
Config.RarityIndex = {}
for i, rarity in Config.Rarities do
	Config.RarityIndex[rarity.Id] = i
end
Config.ForgeCost = 5 -- 5 Duplikate einer Seltenheit -> 1 Skin der naechsten (frei waehlbar)

-- Messer: Klinge (Farbe, Material, Form), Griff, Glanz
Config.Knives = {
	{ Id = "Default", Name = "Classic Knife", Rarity = "Common", Blade = Color3.fromRGB(200, 205, 215), Handle = Color3.fromRGB(70, 50, 40), Style = "Classic" },
	{ Id = "Butter", Name = "Butter Knife", Rarity = "Common", Blade = Color3.fromRGB(235, 225, 190), Handle = Color3.fromRGB(240, 240, 240), Style = "Round" },
	{ Id = "Camo", Name = "Camo Blade", Rarity = "Common", Blade = Color3.fromRGB(110, 130, 80), Handle = Color3.fromRGB(60, 70, 40), Style = "Classic" },
	{ Id = "Ruby", Name = "Ruby Edge", Rarity = "Uncommon", Blade = Color3.fromRGB(230, 50, 80), Handle = Color3.fromRGB(40, 30, 40), Style = "Classic", Material = "Glass" },
	{ Id = "Mint", Name = "Mint Chip", Rarity = "Uncommon", Blade = Color3.fromRGB(150, 240, 200), Handle = Color3.fromRGB(110, 70, 50), Style = "Round" },
	{ Id = "Cleaver", Name = "Chef Cleaver", Rarity = "Uncommon", Blade = Color3.fromRGB(190, 200, 210), Handle = Color3.fromRGB(30, 30, 30), Style = "Cleaver" },
	{ Id = "Frost", Name = "Frost Fang", Rarity = "Rare", Blade = Color3.fromRGB(150, 220, 255), Handle = Color3.fromRGB(40, 60, 120), Style = "Fang", Material = "Ice", Glow = Color3.fromRGB(120, 200, 255) },
	{ Id = "Katana", Name = "Night Katana", Rarity = "Rare", Blade = Color3.fromRGB(220, 225, 240), Handle = Color3.fromRGB(150, 20, 40), Style = "Katana" },
	{ Id = "Candy", Name = "Candy Cane", Rarity = "Rare", Blade = Color3.fromRGB(255, 255, 255), Handle = Color3.fromRGB(230, 40, 60), Style = "Candy" },
	{ Id = "Toxic", Name = "Toxic Slime", Rarity = "Legendary", Blade = Color3.fromRGB(120, 255, 60), Handle = Color3.fromRGB(40, 40, 50), Style = "Fang", Neon = true, Glow = Color3.fromRGB(120, 255, 60) },
	{ Id = "Lava", Name = "Lava Shard", Rarity = "Legendary", Blade = Color3.fromRGB(255, 110, 30), Handle = Color3.fromRGB(50, 20, 10), Style = "Classic", Neon = true, Glow = Color3.fromRGB(255, 120, 30), Particles = "Fire" },
	{ Id = "Galaxy", Name = "Galaxy Edge", Rarity = "Godly", Blade = Color3.fromRGB(120, 60, 255), Handle = Color3.fromRGB(20, 10, 40), Style = "Katana", Neon = true, Glow = Color3.fromRGB(170, 100, 255), Particles = "Stars" },
	{ Id = "Sunburst", Name = "Sunburst", Rarity = "Godly", Blade = Color3.fromRGB(255, 210, 60), Handle = Color3.fromRGB(120, 60, 10), Style = "Fang", Neon = true, Glow = Color3.fromRGB(255, 210, 60), Particles = "Sparkles" },
	{ Id = "Eclipse", Name = "Eclipse", Rarity = "Midnight", Blade = Color3.fromRGB(30, 20, 60), Handle = Color3.fromRGB(255, 214, 102), Style = "Moon", Neon = false, Glow = Color3.fromRGB(255, 214, 102), Particles = "Stars" },
	{ Id = "Starlight", Name = "Starlight", Rarity = "Rare", Blade = Color3.fromRGB(255, 240, 180), Handle = Color3.fromRGB(40, 40, 90), Style = "Moon", Glow = Color3.fromRGB(255, 240, 180), Exclusive = true },
	{ Id = "CodeCutter", Name = "Code Cutter", Rarity = "Uncommon", Blade = Color3.fromRGB(80, 220, 255), Handle = Color3.fromRGB(20, 20, 30), Style = "Classic", Neon = true, Exclusive = true },
	{ Id = "Moonfang", Name = "Moonfang", Rarity = "Midnight", Blade = Color3.fromRGB(200, 220, 255), Handle = Color3.fromRGB(60, 40, 120), Style = "Moon", Neon = true, Glow = Color3.fromRGB(170, 200, 255), Particles = "Sparkles", Exclusive = true },
	{ Id = "Lollipop", Name = "Lollipop Swirl", Rarity = "Legendary", Blade = Color3.fromRGB(255, 120, 200), Handle = Color3.fromRGB(255, 255, 255), Style = "Candy", Neon = true, Glow = Color3.fromRGB(255, 120, 200), Exclusive = true },
}

-- Blaster (Sheriff): Form, Farben, Strahlfarbe
Config.Guns = {
	{ Id = "Default", Name = "Classic Blaster", Rarity = "Common", Body = Color3.fromRGB(60, 64, 80), Accent = Color3.fromRGB(200, 205, 215), Beam = Color3.fromRGB(255, 240, 160), Style = "Revolver" },
	{ Id = "Water", Name = "Water Pistol", Rarity = "Common", Body = Color3.fromRGB(60, 160, 255), Accent = Color3.fromRGB(255, 200, 40), Beam = Color3.fromRGB(120, 200, 255), Style = "Toy" },
	{ Id = "Wood", Name = "Old Timer", Rarity = "Common", Body = Color3.fromRGB(120, 80, 50), Accent = Color3.fromRGB(180, 180, 180), Beam = Color3.fromRGB(255, 220, 160), Style = "Revolver" },
	{ Id = "Bubble", Name = "Bubble Blaster", Rarity = "Uncommon", Body = Color3.fromRGB(255, 140, 200), Accent = Color3.fromRGB(255, 255, 255), Beam = Color3.fromRGB(255, 180, 230), Style = "Toy" },
	{ Id = "Lime", Name = "Lime Laser", Rarity = "Uncommon", Body = Color3.fromRGB(40, 40, 50), Accent = Color3.fromRGB(150, 255, 60), Beam = Color3.fromRGB(150, 255, 60), Style = "Laser" },
	{ Id = "Gold", Name = "Gold Six", Rarity = "Rare", Body = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(60, 40, 20), Beam = Color3.fromRGB(255, 220, 80), Style = "Revolver", Material = "Foil" },
	{ Id = "Ice", Name = "Ice Ray", Rarity = "Rare", Body = Color3.fromRGB(180, 230, 255), Accent = Color3.fromRGB(60, 120, 200), Beam = Color3.fromRGB(150, 220, 255), Style = "Laser", Material = "Ice" },
	{ Id = "Plasma", Name = "Plasma Cannon", Rarity = "Legendary", Body = Color3.fromRGB(30, 30, 40), Accent = Color3.fromRGB(255, 92, 170), Beam = Color3.fromRGB(255, 92, 170), Style = "Laser", Neon = true },
	{ Id = "Comet", Name = "Comet", Rarity = "Godly", Body = Color3.fromRGB(20, 20, 50), Accent = Color3.fromRGB(80, 220, 255), Beam = Color3.fromRGB(80, 220, 255), Style = "Laser", Neon = true, Particles = "Stars" },
	{ Id = "Lunar", Name = "Lunar Ray", Rarity = "Midnight", Body = Color3.fromRGB(40, 30, 90), Accent = Color3.fromRGB(255, 214, 102), Beam = Color3.fromRGB(255, 214, 102), Style = "Laser", Neon = true, Particles = "Sparkles", Exclusive = true },
	{ Id = "Starshot", Name = "Starshot", Rarity = "Rare", Body = Color3.fromRGB(40, 40, 90), Accent = Color3.fromRGB(255, 240, 180), Beam = Color3.fromRGB(255, 240, 180), Style = "Revolver", Exclusive = true },
	{ Id = "Sprinkle", Name = "Sprinkle Shot", Rarity = "Legendary", Body = Color3.fromRGB(255, 180, 220), Accent = Color3.fromRGB(120, 220, 255), Beam = Color3.fromRGB(255, 120, 200), Style = "Toy", Neon = true, Exclusive = true },
}

-- Haustiere folgen ihrem Besitzer (rein kosmetisch, vom Client gebaut)
Config.Pets = {
	{ Id = "Bat", Name = "Batty", Rarity = "Common", Color = Color3.fromRGB(70, 60, 90), Shape = "Bat" },
	{ Id = "Slime", Name = "Slimy", Rarity = "Common", Color = Color3.fromRGB(110, 230, 120), Shape = "Blob" },
	{ Id = "Pumpkin", Name = "Pumpkin", Rarity = "Uncommon", Color = Color3.fromRGB(255, 140, 40), Shape = "Pumpkin" },
	{ Id = "Owl", Name = "Night Owl", Rarity = "Uncommon", Color = Color3.fromRGB(150, 110, 70), Shape = "Owl" },
	{ Id = "Ghost", Name = "Boo", Rarity = "Rare", Color = Color3.fromRGB(240, 240, 255), Shape = "Ghost" },
	{ Id = "Fox", Name = "Moon Fox", Rarity = "Legendary", Color = Color3.fromRGB(255, 160, 80), Shape = "Fox", Glow = true },
	{ Id = "Dragon", Name = "Star Dragon", Rarity = "Godly", Color = Color3.fromRGB(120, 80, 255), Shape = "Dragon", Glow = true },
	{ Id = "Moonling", Name = "Moonling", Rarity = "Midnight", Color = Color3.fromRGB(255, 214, 102), Shape = "Moon", Glow = true, Exclusive = true },
	{ Id = "Cat", Name = "Midnight Cat", Rarity = "Rare", Color = Color3.fromRGB(40, 40, 60), Shape = "Fox", Exclusive = true },
}

-- Cartoon-K.O.-Effekte (kein Blut)
Config.Effects = {
	{ Id = "Poof", Name = "Poof", Rarity = "Common", Color = Color3.fromRGB(230, 230, 240) },
	{ Id = "Stars", Name = "Dizzy Stars", Rarity = "Uncommon", Color = Color3.fromRGB(255, 220, 80) },
	{ Id = "Confetti", Name = "Confetti", Rarity = "Rare", Color = Color3.fromRGB(255, 92, 170) },
	{ Id = "Hearts", Name = "Hearts", Rarity = "Rare", Color = Color3.fromRGB(255, 90, 130) },
	{ Id = "Bubbles", Name = "Bubbles", Rarity = "Legendary", Color = Color3.fromRGB(120, 210, 255) },
	{ Id = "Lightning", Name = "Zap", Rarity = "Godly", Color = Color3.fromRGB(150, 220, 255) },
	{ Id = "Moonbeam", Name = "Moonbeam", Rarity = "Midnight", Color = Color3.fromRGB(255, 214, 102), Exclusive = true },
}

Config.ItemKinds = { "Knife", "Gun", "Pet", "Effect" }
Config.ItemLists = { Knife = Config.Knives, Gun = Config.Guns, Pet = Config.Pets, Effect = Config.Effects }

function Config.GetItem(kind: string, id: string)
	local list = Config.ItemLists[kind]
	if not list then
		return nil
	end
	for _, item in list do
		if item.Id == id then
			return item
		end
	end
	return nil
end

-- Kisten kosten nur Spiel-Muenzen. Quoten werden immer angezeigt; bei PolicyService-Sperre gibt es nur den Direkt-Shop.
Config.Crates = {
	{ Id = "KnifeCrate", Name = "Knife Crate", Kind = "Knife", Price = 1000, Color = Color3.fromRGB(255, 72, 88) },
	{ Id = "GunCrate", Name = "Blaster Crate", Kind = "Gun", Price = 1000, Color = Color3.fromRGB(70, 150, 255) },
	{ Id = "PetCrate", Name = "Pet Egg", Kind = "Pet", Price = 1500, Color = Color3.fromRGB(90, 230, 120) },
	{ Id = "EffectCrate", Name = "Effect Box", Kind = "Effect", Price = 800, Color = Color3.fromRGB(255, 200, 40) },
}

-- Gewinnchancen einer Kiste: Seltenheitsgewicht / Anzahl Skins dieser Seltenheit
function Config.CrateOdds(crateId: string): { { Kind: string, Id: string, Chance: number } }
	local crate
	for _, c in Config.Crates do
		if c.Id == crateId then
			crate = c
		end
	end
	if not crate then
		return {}
	end
	local byRarity = {}
	for _, item in Config.ItemLists[crate.Kind] do
		if not item.Exclusive and item.Id ~= "Default" and item.Rarity ~= "Midnight" then
			byRarity[item.Rarity] = byRarity[item.Rarity] or {}
			table.insert(byRarity[item.Rarity], item)
		end
	end
	local total = 0
	for rarityId, items in byRarity do
		total += Config.Rarities[Config.RarityIndex[rarityId]].Weight
	end
	local odds = {}
	for rarityId, items in byRarity do
		local weight = Config.Rarities[Config.RarityIndex[rarityId]].Weight
		for _, item in items do
			table.insert(odds, { Kind = crate.Kind, Id = item.Id, Chance = weight / total / #items })
		end
	end
	table.sort(odds, function(a, b)
		return a.Chance > b.Chance
	end)
	return odds
end

Config.Emotes = {
	{ Id = "wave", Name = "Wave", Free = true },
	{ Id = "point", Name = "Point", Free = true },
	{ Id = "cheer", Name = "Cheer", Free = true },
	{ Id = "laugh", Name = "Laugh", Free = true },
	{ Id = "dance", Name = "Dance", Free = false },
	{ Id = "dance2", Name = "Groove", Free = false },
	{ Id = "dance3", Name = "Party", Free = false },
}

---------------------------------------------------------------- Fortschritt

Config.BattlePass = {
	Season = 1,
	Name = "Season 1: Midnight",
	Tiers = 30,
	XPPerTier = 300,
	-- Belohnungen pro Stufe: Free fuer alle, Premium nur mit Pass
	Free = {
		[1] = { Coins = 100 }, [3] = { Coins = 150 }, [5] = { Item = { "Knife", "Camo" } }, [7] = { Coins = 200 },
		[10] = { Item = { "Pet", "Bat" } }, [13] = { Coins = 300 }, [15] = { Item = { "Effect", "Stars" } }, [18] = { Coins = 400 },
		[20] = { Item = { "Gun", "Lime" } }, [23] = { Coins = 500 }, [25] = { Coins = 750 }, [28] = { Coins = 1000 },
		[30] = { Item = { "Knife", "Frost" } },
	},
	Premium = {
		[1] = { Item = { "Knife", "Lollipop" } }, [2] = { Coins = 300 }, [4] = { Item = { "Effect", "Hearts" } }, [6] = { Coins = 400 },
		[8] = { Item = { "Gun", "Sprinkle" } }, [9] = { Coins = 500 }, [11] = { Item = { "Pet", "Cat" } }, [12] = { Coins = 600 },
		[14] = { Item = { "Effect", "Bubbles" } }, [16] = { Coins = 800 }, [17] = { Item = { "Pet", "Fox" } }, [19] = { Coins = 1000 },
		[21] = { Item = { "Knife", "Lava" } }, [22] = { Coins = 1200 }, [24] = { Item = { "Gun", "Plasma" } }, [26] = { Coins = 1500 },
		[27] = { Item = { "Effect", "Moonbeam" } }, [29] = { Coins = 2500 }, [30] = { Item = { "Knife", "Moonfang" } },
	},
}

Config.Quests = {
	{ Id = "Coins", Text = "Collect %d coins", Stat = "Coins", Goal = 60, Reward = 120 },
	{ Id = "Survive", Text = "Survive %d rounds", Stat = "Survive", Goal = 3, Reward = 150 },
	{ Id = "Win", Text = "Win %d rounds", Stat = "Win", Goal = 3, Reward = 150 },
	{ Id = "Play", Text = "Play %d rounds", Stat = "Play", Goal = 5, Reward = 100 },
	{ Id = "KO", Text = "Knock out %d players as Murderer", Stat = "KO", Goal = 4, Reward = 180 },
	{ Id = "Ability", Text = "Use abilities %d times", Stat = "Ability", Goal = 6, Reward = 100 },
	{ Id = "Hide", Text = "Hide in a closet %d times", Stat = "Hide", Goal = 3, Reward = 100 },
	{ Id = "PowerUp", Text = "Grab %d power-ups", Stat = "PowerUp", Goal = 4, Reward = 120 },
	{ Id = "Crate", Text = "Open %d crates", Stat = "Crate", Goal = 1, Reward = 150 },
}
Config.QuestsPerDay = 3
Config.QuestXP = 150 -- Battle-Pass-XP pro erledigter Quest

Config.Achievements = {
	{ Id = "FirstWin", Name = "First Win", Stat = "Wins", Goal = 1, Title = "Rookie" },
	{ Id = "Wins50", Name = "Winner", Stat = "Wins", Goal = 50, Title = "Champion" },
	{ Id = "Wins250", Name = "Legend", Stat = "Wins", Goal = 250, Title = "Legend" },
	{ Id = "FirstKO", Name = "Sneaky", Stat = "KOs", Goal = 1, Title = "Sneaky" },
	{ Id = "KO100", Name = "Shadow", Stat = "KOs", Goal = 100, Title = "Shadow" },
	{ Id = "Stops", Name = "Detective", Stat = "Stops", Goal = 10, Title = "Detective" },
	{ Id = "Hero", Name = "True Hero", Stat = "HeroStops", Goal = 1, Title = "Hero" },
	{ Id = "Survivor", Name = "Survivor", Stat = "Survived", Goal = 25, Title = "Survivor" },
	{ Id = "Coins1k", Name = "Collector", Stat = "CoinsCollected", Goal = 1000, Title = "Collector" },
	{ Id = "Coins10k", Name = "Tycoon", Stat = "CoinsCollected", Goal = 10000, Title = "Tycoon" },
	{ Id = "Level10", Name = "Level 10", Stat = "Level", Goal = 10, Title = "Sleuth" },
	{ Id = "Level30", Name = "Level 30", Stat = "Level", Goal = 30, Title = "Mastermind" },
	{ Id = "Forge", Name = "Forge Master", Stat = "Forged", Goal = 3, Title = "Smith" },
	{ Id = "Hider", Name = "Hide and Seek", Stat = "Hides", Goal = 20, Title = "Hidden" },
}

Config.DailyRewards = { 100, 150, 200, 250, 300, 400, 750 } -- Login-Serie, Tag 7 wiederholt sich

-- Kostenloses Gluecksrad alle 20 Stunden (Quoten sichtbar)
Config.Spin = {
	Cooldown = 20 * 3600,
	Prizes = {
		{ Text = "50 Coins", Coins = 50, Weight = 34 },
		{ Text = "100 Coins", Coins = 100, Weight = 26 },
		{ Text = "250 Coins", Coins = 250, Weight = 15 },
		{ Text = "500 Coins", Coins = 500, Weight = 6 },
		{ Text = "300 XP", XP = 300, Weight = 12 },
		{ Text = "Rare Skin", Skin = "Rare", Weight = 6 },
		{ Text = "Legendary Skin", Skin = "Legendary", Weight = 1 },
	},
}

Config.Codes = {
	MIDNIGHT = { Coins = 500 },
	MYSTERY = { Item = { "Knife", "CodeCutter" } },
	BIGBABA = { Coins = 1000 },
	SLEUTH = { XP = 500 },
}

Config.Obby = { Reward = 75, Cooldown = 600 }
Config.GhostGuessReward = 25
Config.AdCooldown = 300
Config.StarterPackDelay = 120

---------------------------------------------------------------- Robux

-- "Passes" werden als dauerhafte Developer Products verkauft (wie in den anderen Spielen)
Config.GamePasses = {
	VIP = { ProductName = "VIP", Name = "VIP", Price = 299, Text = "x1.5 coins, +10 coin bag, VIP tag, gold name" },
	DoubleCoins = { ProductName = "Double Coins", Name = "Double Coins", Price = 249, Text = "2x coins forever" },
	DoubleXP = { ProductName = "Double XP", Name = "Double XP", Price = 199, Text = "2x XP and Battle Pass XP forever" },
	BigBag = { ProductName = "Big Coin Bag", Name = "Big Coin Bag", Price = 149, Text = "+20 coins per round bag" },
	Emotes = { ProductName = "Emote Pack", Name = "Emote Pack", Price = 99, Text = "3 dance emotes" },
	PetSlot = { ProductName = "Extra Pet Slot", Name = "Extra Pet Slot", Price = 149, Text = "Equip 2 pets at once" },
}

Config.DevProducts = {
	Coins1 = { ProductName = "1,000 Coins", Kind = "Coins", Coins = 1000, Price = 49 },
	Coins2 = { ProductName = "3,500 Coins", Kind = "Coins", Coins = 3500, Price = 149 },
	Coins3 = { ProductName = "10,000 Coins", Kind = "Coins", Coins = 10000, Price = 399 },
	Coins4 = { ProductName = "30,000 Coins", Kind = "Coins", Coins = 30000, Price = 999 },
	MurdererTicket = { ProductName = "Murderer Ticket", Kind = "Ticket", Role = "Murderer", Price = 49 },
	SheriffTicket = { ProductName = "Sheriff Ticket", Kind = "Ticket", Role = "Sheriff", Price = 39 },
	BattlePass = { ProductName = "Premium Pass S1", Kind = "BattlePass", Price = 399 },
	TierSkip1 = { ProductName = "Skip 1 Tier", Kind = "TierSkip", Tiers = 1, Price = 49 },
	TierSkip10 = { ProductName = "Skip 10 Tiers", Kind = "TierSkip", Tiers = 10, Price = 349 },
	StarterPack = { ProductName = "Starter Pack", Kind = "StarterPack", Coins = 2500, Price = 79 },
	MoonBundle = { ProductName = "Moonlight Bundle", Kind = "Bundle", Items = { { "Knife", "Eclipse" }, { "Gun", "Lunar" }, { "Pet", "Moonling" } }, Price = 499 },
	StarBundle = { ProductName = "Starlight Bundle", Kind = "Bundle", Items = { { "Knife", "Starlight" }, { "Gun", "Starshot" }, { "Pet", "Cat" } }, Price = 199 },
	XPBoost = { ProductName = "2x XP 30 min", Kind = "XPBoost", Minutes = 30, Price = 39 },
	Blackout = { ProductName = "Server Blackout", Kind = "Blackout", Price = 29 },
	AdCoins = { ProductName = "Free Coins (Video Ad)", Kind = "AdCoins", Coins = 100, Price = 5 },
}

-- IDs aus ProductIds.json (vom Workflow geschrieben). Fehlt eine, sucht der Server per Name.
for key, pass in Config.GamePasses do
	pass.ProductId = ProductIds["Pass_" .. key] or 0
end
for key, product in Config.DevProducts do
	product.Id = ProductIds[key] or 0
end

return Config
