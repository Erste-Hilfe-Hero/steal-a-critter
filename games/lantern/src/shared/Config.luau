-- Alle Spielwerte an einem Ort: Klassen, Dungeons, Monster, Beute, Preise.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.DataStoreName = "LanternData_v1"
Config.LeaderboardStore = "LanternLevel_v1"

---------------------------------------------------------------- Fortschritt

Config.MaxLevel = 60
Config.MaxItemLevel = 64
Config.StartGold = 50
Config.BaseInventory = 50
Config.BackpackBonus = 100 -- mit Pass

function Config.XPToLevel(level: number): number
	return math.floor(80 + 45 * level ^ 1.6)
end

Config.VipBonus = 0.25 -- +25 % Gold und XP
Config.DoubleXPMultiplier = 2
Config.PremiumBonus = 0.1 -- Premium-Spieler: +10 % Gold und XP (mehr Premium Payouts)
Config.FriendBonusPer = 0.1 -- +10 % pro Freund im Server
Config.MaxFriendBonus = 3
Config.LuckMultiplier = 1.5 -- Lucky Lantern: Chance auf Rare und besser

Config.PotionCooldown = 15
Config.PotionHeal = 0.35
Config.ReviveSeconds = 10 -- so lange darf man nach dem Tod waehlen
Config.TownRespawn = 3

function Config.DailyGold(streak: number, level: number): number
	return math.floor(150 * streak * (1 + level / 5))
end

---------------------------------------------------------------- Klassen

-- Skills: Kind bestimmt die Logik im CombatService, die restlichen Felder sind Parameter.
Config.Classes = {
	Knight = {
		Order = 1,
		Name = "Knight",
		Color = Color3.fromRGB(90, 160, 255),
		Description = "Tough frontline fighter. Cleaves groups and stuns them with his shield.",
		Health = 140,
		Armor = 12,
		Range = 9,
		Attack = { Kind = "Cleave", Cooldown = 0.5, Radius = 8, Mult = 1 },
		Skills = {
			{ Key = "ShieldSlam", Name = "Shield Slam", Kind = "Nova", Cooldown = 6, Radius = 14, Mult = 1.8, Stun = 1.5 },
			{ Key = "Whirlwind", Name = "Whirlwind", Kind = "Spin", Cooldown = 10, Radius = 12, Mult = 0.7, Ticks = 6, Interval = 0.35 },
		},
		Nouns = { Weapon = "Blade", Helmet = "Helm", Armor = "Plate", Boots = "Greaves" },
	},
	Ranger = {
		Order = 2,
		Name = "Ranger",
		Color = Color3.fromRGB(90, 220, 120),
		Description = "Fast archer. Shoots from far away and rains arrows on whole packs.",
		Health = 110,
		Armor = 6,
		Range = 46,
		Attack = { Kind = "Shot", Cooldown = 0.5, Mult = 1.05 },
		Skills = {
			{ Key = "Volley", Name = "Volley", Kind = "Volley", Cooldown = 6, Count = 5, Mult = 1.2 },
			{ Key = "ArrowRain", Name = "Arrow Rain", Kind = "Rain", Cooldown = 11, Radius = 14, Mult = 0.65, Ticks = 6, Interval = 0.45 },
		},
		Nouns = { Weapon = "Bow", Helmet = "Hood", Armor = "Tunic", Boots = "Boots" },
	},
	Mage = {
		Order = 3,
		Name = "Mage",
		Color = Color3.fromRGB(190, 110, 255),
		Description = "Master of frost and fire. Huge area damage, but fragile.",
		Health = 100,
		Armor = 4,
		Range = 40,
		Attack = { Kind = "Bolt", Cooldown = 0.62, Mult = 1.15, Splash = 6, SplashMult = 0.4 },
		Skills = {
			{ Key = "FrostNova", Name = "Frost Nova", Kind = "Nova", Cooldown = 7, Radius = 16, Mult = 1.3, Slow = 3 },
			{ Key = "Meteor", Name = "Meteor", Kind = "Meteor", Cooldown = 10, Radius = 16, Mult = 3.6, Delay = 0.8 },
		},
		Nouns = { Weapon = "Staff", Helmet = "Hat", Armor = "Robe", Boots = "Slippers" },
	},
	Lightbringer = {
		Order = 4,
		Name = "Lightbringer",
		Color = Color3.fromRGB(255, 205, 80),
		Description = "Holy support. Heals the whole party and shields allies from harm.",
		Health = 125,
		Armor = 9,
		Range = 36,
		Attack = { Kind = "Bolt", Cooldown = 0.58, Mult = 1, Heal = 0.15 },
		Skills = {
			{ Key = "Radiance", Name = "Radiance", Kind = "Nova", Cooldown = 8, Radius = 15, Mult = 1.4, HealParty = 0.2 },
			{ Key = "Sanctuary", Name = "Sanctuary", Kind = "Aura", Cooldown = 14, Radius = 13, Mult = 0.55, Ticks = 8, Interval = 0.5, Shield = 4 },
		},
		Nouns = { Weapon = "Scepter", Helmet = "Circlet", Armor = "Vestments", Boots = "Sandals" },
		UnlockLevel = 20, -- oder Pass "Lightbringer"
	},
}
Config.ClassOrder = { "Knight", "Ranger", "Mage", "Lightbringer" }

Config.BaseCrit = 5 -- %
Config.BaseCritDamage = 50 -- %

function Config.BaseDamage(level: number): number
	return 6 + 1.5 * level
end

function Config.BaseHealth(classHealth: number, level: number): number
	return classHealth + 14 * level
end

-- Schadensreduktion durch Ruestung, abhaengig von der Monsterstufe
function Config.ArmorReduction(armor: number, monsterLevel: number): number
	return math.min(0.6, armor / (armor + 40 + 12 * monsterLevel))
end

---------------------------------------------------------------- Dungeons

Config.Difficulties = {
	{ Name = "Normal", Hp = 1, Dmg = 1, LevelBonus = 0, Loot = 1, Color = Color3.fromRGB(120, 220, 140) },
	{ Name = "Hard", Hp = 1.6, Dmg = 1.35, LevelBonus = 6, Loot = 1.6, Color = Color3.fromRGB(255, 170, 60) },
	{ Name = "Nightmare", Hp = 2.6, Dmg = 1.8, LevelBonus = 14, Loot = 2.4, Mythic = true, Color = Color3.fromRGB(255, 80, 110) },
}

-- Farben: Floor/Wall = Boden und Waende, Accent = Kristalle/Leuchten, Light = Laternen
Config.Dungeons = {
	{
		Id = "burrows",
		Name = "Mossy Burrows",
		Level = 1,
		Monsters = { "Slime", "Mushroom", "Bat" },
		Elite = "Mushroom",
		Boss = "KingGloop",
		Floor = Color3.fromRGB(86, 120, 70),
		Wall = Color3.fromRGB(96, 78, 60),
		Accent = Color3.fromRGB(150, 255, 120),
		Light = Color3.fromRGB(255, 200, 120),
		Props = "Mushrooms",
	},
	{
		Id = "mines",
		Name = "Goblin Mines",
		Level = 6,
		Monsters = { "Goblin", "Bat", "GoblinThrower" },
		Elite = "Goblin",
		Boss = "Foreman",
		Floor = Color3.fromRGB(120, 100, 80),
		Wall = Color3.fromRGB(80, 66, 56),
		Accent = Color3.fromRGB(255, 190, 70),
		Light = Color3.fromRGB(255, 170, 90),
		Props = "Mine",
	},
	{
		Id = "frost",
		Name = "Frostfang Caverns",
		Level = 12,
		Monsters = { "SnowWolf", "IceWisp", "Yeti" },
		Elite = "Yeti",
		Boss = "GlacierGolem",
		Floor = Color3.fromRGB(190, 215, 235),
		Wall = Color3.fromRGB(120, 150, 185),
		Accent = Color3.fromRGB(120, 230, 255),
		Light = Color3.fromRGB(200, 230, 255),
		Props = "Ice",
	},
	{
		Id = "forge",
		Name = "Ember Forge",
		Level = 19,
		Monsters = { "MagmaSlime", "EmberBat", "Golem" },
		Elite = "Golem",
		Boss = "ForgeTitan",
		Floor = Color3.fromRGB(70, 56, 54),
		Wall = Color3.fromRGB(56, 44, 44),
		Accent = Color3.fromRGB(255, 120, 40),
		Light = Color3.fromRGB(255, 140, 70),
		Props = "Forge",
	},
	{
		Id = "temple",
		Name = "Sunken Temple",
		Level = 27,
		Monsters = { "Crab", "TideWisp", "Turtle" },
		Elite = "Turtle",
		Boss = "Tidecaller",
		Floor = Color3.fromRGB(70, 130, 130),
		Wall = Color3.fromRGB(60, 96, 110),
		Accent = Color3.fromRGB(90, 255, 220),
		Light = Color3.fromRGB(150, 255, 230),
		Props = "Temple",
	},
	{
		Id = "citadel",
		Name = "Starfall Citadel",
		Level = 36,
		Monsters = { "StarWisp", "Sentinel", "CrystalSpider" },
		Elite = "Sentinel",
		Boss = "AstralDragon",
		Floor = Color3.fromRGB(70, 66, 120),
		Wall = Color3.fromRGB(50, 46, 92),
		Accent = Color3.fromRGB(255, 120, 255),
		Light = Color3.fromRGB(220, 180, 255),
		Props = "Stars",
	},
}

Config.RoomsPerRun = 4 -- danach kommt der Bossraum
Config.WavesPerRoom = 2
Config.MaxPartySize = 4
Config.LobbyCountdown = 10
Config.EliteChance = 0.08
Config.MaxRuns = 6 -- gleichzeitige Dungeons pro Server

function Config.WaveSize(room: number, partySize: number): number
	return 3 + room + (partySize - 1) * 2
end

function Config.MonsterHealth(level: number): number
	return 60 + 26 * level
end

function Config.MonsterDamage(level: number): number
	return 8 + 4 * level
end

Config.BossHealthMult = 22
Config.BossPartyHealth = 0.75 -- +75 % Bossleben pro weiterem Spieler
Config.EliteHealthMult = 3.2
Config.EliteDamageMult = 1.4

function Config.KillGold(level: number): number
	return 2 + level * 1.2
end

function Config.KillXP(level: number): number
	return 6 + level * 2.5
end

-- Body = Bauplan im MonsterFactory; AI: Melee, Ranged, Brute
Config.Monsters = {
	Slime = { Name = "Slime", Body = "Slime", Color = Color3.fromRGB(110, 220, 90), Size = 1, Hp = 0.8, Dmg = 0.8, Speed = 11, AI = "Melee" },
	Mushroom = { Name = "Mushroom Brute", Body = "Mushroom", Color = Color3.fromRGB(230, 70, 70), Size = 1.3, Hp = 1.5, Dmg = 1.3, Speed = 8, AI = "Brute" },
	Bat = { Name = "Cave Bat", Body = "Bat", Color = Color3.fromRGB(120, 90, 160), Size = 0.9, Hp = 0.6, Dmg = 0.7, Speed = 16, AI = "Melee", Fly = true },
	Goblin = { Name = "Goblin", Body = "Goblin", Color = Color3.fromRGB(120, 190, 80), Size = 1, Hp = 1, Dmg = 1, Speed = 14, AI = "Melee" },
	GoblinThrower = { Name = "Goblin Bomber", Body = "Goblin", Color = Color3.fromRGB(200, 170, 70), Size = 0.95, Hp = 0.8, Dmg = 1.1, Speed = 12, AI = "Ranged" },
	SnowWolf = { Name = "Snow Wolf", Body = "Wolf", Color = Color3.fromRGB(230, 240, 255), Size = 1.1, Hp = 0.9, Dmg = 1, Speed = 18, AI = "Melee" },
	IceWisp = { Name = "Ice Wisp", Body = "Wisp", Color = Color3.fromRGB(120, 220, 255), Size = 1, Hp = 0.7, Dmg = 1.1, Speed = 10, AI = "Ranged", Fly = true },
	Yeti = { Name = "Yeti", Body = "Golem", Color = Color3.fromRGB(240, 245, 255), Size = 1.3, Hp = 1.7, Dmg = 1.4, Speed = 9, AI = "Brute" },
	MagmaSlime = { Name = "Magma Slime", Body = "Slime", Color = Color3.fromRGB(255, 110, 40), Size = 1.1, Hp = 0.9, Dmg = 1, Speed = 11, AI = "Melee" },
	EmberBat = { Name = "Ember Bat", Body = "Bat", Color = Color3.fromRGB(255, 150, 60), Size = 1, Hp = 0.6, Dmg = 1, Speed = 17, AI = "Ranged", Fly = true },
	Golem = { Name = "Forge Golem", Body = "Golem", Color = Color3.fromRGB(110, 96, 90), Size = 1.35, Hp = 1.8, Dmg = 1.4, Speed = 8, AI = "Brute" },
	Crab = { Name = "Reef Crab", Body = "Crab", Color = Color3.fromRGB(255, 120, 90), Size = 1.1, Hp = 1, Dmg = 1, Speed = 13, AI = "Melee" },
	TideWisp = { Name = "Tide Wisp", Body = "Wisp", Color = Color3.fromRGB(90, 255, 220), Size = 1, Hp = 0.7, Dmg = 1.1, Speed = 10, AI = "Ranged", Fly = true },
	Turtle = { Name = "Shell Guard", Body = "Turtle", Color = Color3.fromRGB(80, 170, 110), Size = 1.3, Hp = 1.9, Dmg = 1.3, Speed = 7, AI = "Brute" },
	StarWisp = { Name = "Star Wisp", Body = "Wisp", Color = Color3.fromRGB(255, 220, 120), Size = 1, Hp = 0.8, Dmg = 1.2, Speed = 11, AI = "Ranged", Fly = true },
	Sentinel = { Name = "Star Sentinel", Body = "Golem", Color = Color3.fromRGB(150, 130, 255), Size = 1.3, Hp = 1.8, Dmg = 1.5, Speed = 9, AI = "Brute" },
	CrystalSpider = { Name = "Crystal Crawler", Body = "Spider", Color = Color3.fromRGB(255, 120, 255), Size = 1, Hp = 0.9, Dmg = 1.1, Speed = 16, AI = "Melee" },
	-- Seltener Schatz-Kobold: greift nie an, rennt weg und verschwindet nach Config.ImpEscape Sekunden
	TreasureImp = { Name = "Treasure Imp", Body = "Imp", Color = Color3.fromRGB(255, 205, 60), Size = 0.9, Hp = 2.4, Dmg = 0, Speed = 19, AI = "Flee", Treasure = true },
}

-- Bosse: Abilities in Reihenfolge abwechselnd, Summon = welche Monster gerufen werden
Config.Bosses = {
	KingGloop = { Name = "King Gloop", Body = "Slime", Color = Color3.fromRGB(90, 230, 110), Size = 3.4, Speed = 9, Abilities = { "Slam", "Summon", "Barrage" }, Summon = "Slime", Crown = true },
	Foreman = { Name = "Foreman Grubb", Body = "Goblin", Color = Color3.fromRGB(150, 200, 80), Size = 2.8, Speed = 11, Abilities = { "Barrage", "Slam", "Summon" }, Summon = "Goblin", Crown = true },
	GlacierGolem = { Name = "Glacier Golem", Body = "Golem", Color = Color3.fromRGB(170, 230, 255), Size = 2.6, Speed = 8, Abilities = { "Slam", "Barrage", "Summon" }, Summon = "IceWisp" },
	ForgeTitan = { Name = "The Forge Titan", Body = "Golem", Color = Color3.fromRGB(255, 120, 50), Size = 2.9, Speed = 8, Abilities = { "Barrage", "Slam", "Summon", "Barrage" }, Summon = "MagmaSlime" },
	Tidecaller = { Name = "Tidecaller Crab", Body = "Crab", Color = Color3.fromRGB(80, 220, 210), Size = 3, Speed = 10, Abilities = { "Slam", "Barrage", "Summon" }, Summon = "Crab", Crown = true },
	AstralDragon = { Name = "Astral Dragon", Body = "Dragon", Color = Color3.fromRGB(170, 120, 255), Size = 2.6, Speed = 10, Abilities = { "Barrage", "Slam", "Barrage", "Summon" }, Summon = "StarWisp" },
}

---------------------------------------------------------------- Beute

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(205, 205, 205), Weight = 60, Mult = 1, Affixes = 0, Shards = 1 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 220, 110), Weight = 26, Mult = 1.12, Affixes = 1, Shards = 2 },
	{ Name = "Rare", Color = Color3.fromRGB(80, 160, 255), Weight = 10, Mult = 1.28, Affixes = 2, Shards = 5 },
	{ Name = "Epic", Color = Color3.fromRGB(190, 90, 255), Weight = 3.2, Mult = 1.48, Affixes = 3, Shards = 12 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 160, 40), Weight = 0.75, Mult = 1.75, Affixes = 4, Shards = 30, Power = true, Announce = true },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 70, 120), Weight = 0.06, Mult = 2.1, Affixes = 5, Shards = 80, Power = true, Announce = true, NightmareOnly = true },
}

Config.Slots = { "Weapon", "Helmet", "Armor", "Boots", "Amulet", "Ring" }
Config.SlotNouns = { Amulet = "Amulet", Ring = "Ring" }

Config.DropChance = 0.16 -- normale Monster
Config.EliteDrops = { 1, 2 }
Config.BossDrops = 3 -- plus 1 pro Schwierigkeitsstufe ueber Normal

-- Werte pro Affix: Min/Max bei Gegenstandsstufe 1, PerLevel kommt pro Stufe dazu
Config.Affixes = {
	{ Key = "Health", Name = "Health", Min = 6, Max = 12, PerLevel = 3 },
	{ Key = "Armor", Name = "Armor", Min = 1, Max = 3, PerLevel = 0.8 },
	{ Key = "Damage", Name = "Damage", Min = 1, Max = 2, PerLevel = 0.6 },
	{ Key = "Crit", Name = "% Crit Chance", Min = 2, Max = 6, PerLevel = 0 },
	{ Key = "CritDamage", Name = "% Crit Damage", Min = 10, Max = 30, PerLevel = 0 },
	{ Key = "AttackSpeed", Name = "% Attack Speed", Min = 3, Max = 10, PerLevel = 0 },
	{ Key = "MoveSpeed", Name = "% Move Speed", Min = 3, Max = 8, PerLevel = 0 },
	{ Key = "GoldFind", Name = "% Gold Find", Min = 5, Max = 20, PerLevel = 0 },
	{ Key = "LifeOnKill", Name = "Life on Kill", Min = 2, Max = 5, PerLevel = 0.5 },
	{ Key = "Cooldown", Name = "% Cooldown Reduction", Min = 3, Max = 10, PerLevel = 0 },
}
Config.StatCaps = { Crit = 60, AttackSpeed = 60, MoveSpeed = 30, Cooldown = 40 }

-- Legendaere Kraefte (Legendary und Mythic haben genau eine)
Config.Powers = {
	ChainSpark = { Title = "Stormcaller", Text = "20% chance on hit to zap 2 nearby enemies for 50% damage" },
	Vampiric = { Title = "Lifebloom", Text = "Heal 4% of max health on every kill" },
	TwinStrike = { Title = "Twinfang", Text = "15% chance to strike twice" },
	EmberBurst = { Title = "Emberheart", Text = "Enemies explode on death for 40% damage" },
	Giantslayer = { Title = "Giantslayer", Text = "+40% damage to bosses and elites" },
	Swiftness = { Title = "Windrunner", Text = "+15% attack and move speed" },
}
Config.PowerOrder = { "ChainSpark", "Vampiric", "TwinStrike", "EmberBurst", "Giantslayer", "Swiftness" }

Config.Prefixes = {
	{ "Worn", "Rusty", "Plain", "Simple" },
	{ "Sturdy", "Polished", "Keen", "Trusty" },
	{ "Gleaming", "Runed", "Moonlit", "Frosted" },
	{ "Ember", "Phantom", "Thunder", "Royal" },
	{}, -- Legendary: Titel der Kraft
	{}, -- Mythic: "Celestial " + Titel
}

-- Schmiede: Aufwerten +1 bis +10 (immer erfolgreich)
Config.MaxPlus = 10
Config.PlusBonus = 0.08 -- +8 % Grundwerte pro Stufe

function Config.EnhanceCost(itemLevel: number, plus: number, rarity: number): (number, number)
	local gold = math.floor(40 * (itemLevel + 5) * (plus + 1) ^ 1.5)
	local shards = math.floor(4 * (plus + 1) * rarity)
	return gold, shards
end

function Config.SalvageValue(itemLevel: number, rarity: number): (number, number)
	local shards = math.floor(Config.Rarities[rarity].Shards * (1 + itemLevel / 12))
	local gold = math.floor((3 + itemLevel) * rarity)
	return shards, gold
end

---------------------------------------------------------------- Shop

-- "Passes" werden als Developer Products verkauft und dauerhaft gespeichert.
-- AffectsRandom: veraendert Zufallsergebnisse -> in Laendern mit Lootbox-Regeln (PolicyService) ausgeblendet.
Config.GamePasses = {
	VIP = { Name = "VIP", Description = "+25% gold and XP forever, golden name and VIP chat tag", PriceHint = 299, Order = 1 },
	DoubleXP = { Name = "2x XP", Description = "Level up twice as fast forever", PriceHint = 249, Order = 2 },
	Luck = { Name = "Lucky Lantern", Description = "+50% chance for Rare, Epic and Legendary loot forever", PriceHint = 349, Order = 3, AffectsRandom = true },
	Sprite = { Name = "Lantern Sprite", Description = "A loyal light sprite fights by your side forever", PriceHint = 249, Order = 4 },
	Backpack = { Name = "Big Backpack", Description = "+100 inventory slots forever", PriceHint = 149, Order = 5 },
	Lightbringer = { Name = "Lightbringer Class", Description = "Unlock the healing Lightbringer now (free at level 20)", PriceHint = 199, Order = 6 },
}

Config.DevProducts = {
	Revive = { Kind = "Revive", Name = "Revive", Description = "Get back up right where you fell with full health", PriceHint = 25, Order = 0, Hidden = true },
	GoldSmall = { Kind = "Gold", Runs = 1, MinGold = 500, Name = "Gold Pouch", Description = "Gold worth about one dungeon run", PriceHint = 49, Order = 1 },
	GoldMedium = { Kind = "Gold", Runs = 5, MinGold = 3_000, Name = "Gold Chest", Description = "Gold worth about five dungeon runs", PriceHint = 149, Order = 2 },
	GoldLarge = { Kind = "Gold", Runs = 20, MinGold = 15_000, Name = "Gold Vault", Description = "Gold worth about twenty dungeon runs", PriceHint = 449, Order = 3 },
	Shards = { Kind = "Shards", Amount = 400, Name = "Shard Bundle", Description = "400 forge shards to enhance your gear", PriceHint = 99, Order = 4 },
	XPBoost = { Kind = "XPBoost", Seconds = 1800, Name = "XP Boost", Description = "30 minutes of double XP", PriceHint = 79, Order = 5 },
	BossBlessing = { Kind = "Blessing", Name = "Boss Blessing", Description = "The next boss drops a Legendary for EVERYONE in your party", PriceHint = 149, Order = 6, AffectsRandom = true },
	StarterPack = { Kind = "Starter", Name = "Starter Pack", Description = "One time only: Epic Lantern weapon, 2,500 gold, 300 shards, 30 min 2x XP", PriceHint = 79, Order = 7, OneTime = true },
	AdRevive = { Kind = "Revive", Name = "Free Revive (Video Ad)", Description = "Reward for watching a video ad: revive", PriceHint = 5, Hidden = true },
	AdGold = { Kind = "Gold", Runs = 0.5, MinGold = 200, Name = "Free Gold (Video Ad)", Description = "Reward for watching a video ad: gold", PriceHint = 5, Hidden = true },
	-- Kosmetik: wird im STYLE-Fenster angeboten (nicht im Shop, damit man es nicht doppelt kauft)
	RoyalAura = { Kind = "Aura", Aura = "Royal", Name = "Royal Aura", Description = "An exclusive golden aura that sparkles around your hero", PriceHint = 149, Order = 8, Hidden = true },
}
Config.AdCooldown = 240
Config.OfferCooldown = 240

Config.SpriteDamage = 0.3 -- Anteil des eigenen Schadens pro Sekunde
Config.SpriteRange = 32

---------------------------------------------------------------- Community (wie in den anderen Spielen)

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

Config.StudioFakePurchases = true

---------------------------------------------------------------- Update: Quests, Erfolge, Titel, Auren, Codes, Einstellungen

-- Taegliche Quests: jeden Tag 3 zufaellige aus dieser Liste. Max = Fortschritt ist ein Hoechstwert (z. B. Kombo).
Config.QuestCount = 3
Config.Quests = {
	{ Key = "Slayer", Text = "Defeat %d monsters", Event = "Kill", Goal = 60 },
	{ Key = "Champions", Text = "Defeat %d champions", Event = "EliteKill", Goal = 3 },
	{ Key = "Bosses", Text = "Defeat %d bosses", Event = "BossKill", Goal = 2 },
	{ Key = "Runs", Text = "Clear %d dungeons", Event = "Clear", Goal = 2 },
	{ Key = "Salvager", Text = "Salvage %d items", Event = "Salvage", Goal = 15 },
	{ Key = "Smith", Text = "Enhance your gear %d times", Event = "Enhance", Goal = 2 },
	{ Key = "Chests", Text = "Open %d hidden chests", Event = "Chest", Goal = 3 },
	{ Key = "Shrines", Text = "Use %d dungeon shrines", Event = "Shrine", Goal = 2 },
	{ Key = "Treasure", Text = "Find %d Rare or better items", Event = "FindRare", Goal = 5 },
	{ Key = "Combo", Text = "Reach a %d kill combo", Event = "Combo", Goal = 25, Max = true },
}
Config.QuestShards = 40

function Config.QuestGold(level: number): number
	return math.floor(250 * (1 + level / 4))
end

-- Erfolge: Stat = Feld in den Spielerdaten (DungeonsCleared wird gezaehlt), jeder Erfolg schaltet einen Titel frei
Config.Achievements = {
	{ Key = "FirstClear", Name = "First Steps", Text = "Clear your first dungeon", Stat = "Runs", Goal = 1, Title = "Adventurer", Gold = 500 },
	{ Key = "Kills500", Name = "Monster Masher", Text = "Defeat 500 monsters", Stat = "Kills", Goal = 500, Title = "Monster Masher", Gold = 2_000 },
	{ Key = "Kills5000", Name = "Lantern Warden", Text = "Defeat 5,000 monsters", Stat = "Kills", Goal = 5_000, Title = "Lantern Warden", Gold = 15_000 },
	{ Key = "Bosses10", Name = "Boss Hunter", Text = "Defeat 10 bosses", Stat = "BossKills", Goal = 10, Title = "Boss Hunter", Gold = 3_000 },
	{ Key = "Bosses100", Name = "Giant Toppler", Text = "Defeat 100 bosses", Stat = "BossKills", Goal = 100, Title = "Giant Toppler", Gold = 25_000 },
	{ Key = "Imps5", Name = "Imp Catcher", Text = "Catch 5 Treasure Imps", Stat = "ImpKills", Goal = 5, Title = "Imp Catcher", Gold = 4_000 },
	{ Key = "Legendary", Name = "Treasure Seeker", Text = "Find a Legendary item", Stat = "LegendaryFound", Goal = 1, Title = "Treasure Seeker", Gold = 2_500 },
	{ Key = "Mythic", Name = "Starborn", Text = "Find a Mythic item", Stat = "MythicFound", Goal = 1, Title = "Starborn", Gold = 20_000 },
	{ Key = "Nightmare", Name = "Nightmare Walker", Text = "Clear any dungeon on Nightmare", Stat = "NightmareClears", Goal = 1, Title = "Nightmare Walker", Gold = 10_000 },
	{ Key = "AllDungeons", Name = "Lantern Hero", Text = "Clear all 6 dungeons", Stat = "DungeonsCleared", Goal = 6, Title = "Lantern Hero", Gold = 8_000 },
	{ Key = "Plus10", Name = "Master Smith", Text = "Enhance an item to +10", Stat = "BestPlus", Goal = 10, Title = "Master Smith", Gold = 6_000 },
	{ Key = "Combo100", Name = "Unstoppable", Text = "Reach a 100 kill combo", Stat = "BestCombo", Goal = 100, Title = "Unstoppable", Gold = 5_000 },
	{ Key = "Level30", Name = "Veteran Hero", Text = "Reach level 30", Stat = "Level", Goal = 30, Title = "Veteran Hero", Gold = 8_000 },
	{ Key = "Level60", Name = "Lantern Legend", Text = "Reach level 60", Stat = "Level", Goal = 60, Title = "Lantern Legend", Gold = 30_000 },
}

-- Auren: leuchtende Kosmetik um den Helden. Gold = mit Gold kaufen, Product = Robux, Achievement = freigespielt
Config.Auras = {
	{ Key = "Ember", Name = "Ember Aura", Color = Color3.fromRGB(255, 130, 50), Gold = 5_000 },
	{ Key = "Frost", Name = "Frost Aura", Color = Color3.fromRGB(120, 220, 255), Gold = 15_000 },
	{ Key = "Verdant", Name = "Verdant Aura", Color = Color3.fromRGB(110, 240, 120), Gold = 30_000 },
	{ Key = "Starlight", Name = "Starlight Aura", Color = Color3.fromRGB(220, 160, 255), Gold = 75_000 },
	{ Key = "Royal", Name = "Royal Aura", Color = Color3.fromRGB(255, 205, 60), Product = "RoyalAura" },
	{ Key = "Legend", Name = "Legend Aura", Color = Color3.fromRGB(255, 70, 120), Achievement = "Level60" },
}

-- Codes (Grossschreibung egal). Neue Codes einfach hier eintragen.
Config.Codes = {
	LANTERN = { Gold = 1_000, Shards = 50 },
	LOOT = { Item = 3 },
	LIGHTUP = { Shards = 150 },
	HEROES = { Gold = 2_500 },
}

-- Einstellungen (dauerhaft gespeichert); Standardwerte
Config.Settings = {
	{ Key = "Sound", Name = "Sound effects", Default = true },
	{ Key = "Numbers", Name = "Damage numbers", Default = true },
	{ Key = "Shake", Name = "Screen shake", Default = true },
	{ Key = "AutoEquip", Name = "Auto-equip upgrades", Default = false },
}

-- Trank-Meisterschaft (Gold-Upgrade): mehr Heilung, kuerzere Abklingzeit
Config.PotionMaxLevel = 5

function Config.PotionUpgradeCost(level: number): number
	return 1_500 * (level + 1) ^ 2
end

function Config.PotionHealFor(level: number): number
	return Config.PotionHeal + 0.05 * level
end

function Config.PotionCooldownFor(level: number): number
	return Config.PotionCooldown - level
end

-- Kill-Kombo: Kills in kurzer Folge, Bonusgold an den Meilensteinen
Config.ComboWindow = 4
Config.ComboMilestones = { 10, 25, 50, 100 }

-- Dungeon des Tages: +50 % Gold und XP
Config.FeaturedBonus = 0.5

function Config.FeaturedDungeon(day: number): number
	return day % #Config.Dungeons + 1
end

-- Schreine (Gruppen-Buff fuer Seconds) und versteckte Truhen in den Kampfraeumen
Config.Shrines = {
	Power = { Name = "Shrine of Power", Text = "+30% damage", Color = Color3.fromRGB(255, 110, 80), Seconds = 30 },
	Fortune = { Name = "Shrine of Fortune", Text = "+50% gold", Color = Color3.fromRGB(255, 205, 60), Seconds = 30 },
	Warding = { Name = "Shrine of Warding", Text = "-40% damage taken", Color = Color3.fromRGB(120, 200, 255), Seconds = 30 },
}
Config.ShrineOrder = { "Power", "Fortune", "Warding" }
Config.ShrineChance = 0.5
Config.ChestChance = 0.6
Config.ImpChance = 0.07 -- pro Welle, hoechstens ein Kobold pro Lauf
Config.ImpEscape = 20

-- Kurze Gruppen-Signale (feste Texte, deshalb kein Filter noetig)
Config.Pings = { "Help!", "Attack!", "Wait!", "Nice!" }
Config.PingCooldown = 2

-- Einsteiger-Anleitung: Schritt fuer Schritt mit kleiner Belohnung
Config.Tutorial = {
	{ Event = "SetClass", Text = "Pick a class: tap CLASS or visit the Class Shrine", Gold = 100 },
	{ Event = "RunStart", Text = "Walk into the glowing Mossy Burrows portal", Gold = 150 },
	{ Event = "Clear", Text = "Defeat the boss at the end of the dungeon", Gold = 300 },
	{ Event = "Equip", Text = "Open your BAG and equip an item", Gold = 200 },
	{ Event = "Enhance", Text = "Enhance an item at the FORGE", Gold = 300 },
	{ Event = "QuestClaim", Text = "Claim a daily quest reward (QUESTS)", Gold = 400 },
}

---------------------------------------------------------------- Ableitungen

local idsModule = ReplicatedStorage.Shared:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

Config.RaritiesByName = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RaritiesByName[rarity.Name] = rarity
end

Config.AffixesByKey = {}
for _, affix in Config.Affixes do
	Config.AffixesByKey[affix.Key] = affix
end

for index, dungeon in Config.Dungeons do
	dungeon.Index = index
end

Config.QuestsByKey = {}
for _, quest in Config.Quests do
	Config.QuestsByKey[quest.Key] = quest
end

Config.AchievementsByKey = {}
for _, achievement in Config.Achievements do
	Config.AchievementsByKey[achievement.Key] = achievement
end

Config.AurasByKey = {}
for _, aura in Config.Auras do
	Config.AurasByKey[aura.Key] = aura
end

return Config
