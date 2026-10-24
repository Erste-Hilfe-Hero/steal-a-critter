-- Alle Zahlen des Spiels an einem Ort: Helden, Faehigkeiten, Items, Karte, Belohnungen, Produkte.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.GameName = "Lanebreakers"
Config.DataStoreName = "Lanebreakers_v1"
Config.StudioFakePurchases = true

---------------------------------------------------------------- Teams

Config.TeamSize = 5
Config.Teams = {
	[1] = { Name = "Dawn", Color = Color3.fromRGB(255, 184, 64), Dark = Color3.fromRGB(150, 86, 20), Hex = "#FFB840", Sign = -1 },
	[2] = { Name = "Dusk", Color = Color3.fromRGB(150, 110, 255), Dark = Color3.fromRGB(64, 38, 140), Hex = "#966EFF", Sign = 1 },
}
Config.NeutralColor = Color3.fromRGB(120, 220, 140)

---------------------------------------------------------------- Ablauf

Config.PickSeconds = 20
Config.EndSeconds = 14
Config.FirstWaveDelay = 12
Config.WaveInterval = 30
Config.OvertimeAt = 12 * 60 -- danach werden Minions staerker, damit Runden enden
Config.MaxMatchSeconds = 20 * 60

---------------------------------------------------------------- Karte (Dawn links bei -X, Dusk rechts bei +X)

Config.Map = {
	HalfX = 222,
	HalfZ = 150,
	Fountain = { [1] = Vector3.new(-205, 0, 0), [2] = Vector3.new(205, 0, 0) },
	FountainRadius = 20,
	Core = { [1] = Vector3.new(-178, 0, 0), [2] = Vector3.new(178, 0, 0) },
	-- Wegpunkte jeder Lane von Dawn nach Dusk
	Lanes = {
		Top = { Vector3.new(-170, 0, -8), Vector3.new(-160, 0, -60), Vector3.new(-140, 0, -105), Vector3.new(-60, 0, -112), Vector3.new(60, 0, -112), Vector3.new(140, 0, -105), Vector3.new(160, 0, -60), Vector3.new(170, 0, -8) },
		Mid = { Vector3.new(-165, 0, 0), Vector3.new(-80, 0, 0), Vector3.new(0, 0, 0), Vector3.new(80, 0, 0), Vector3.new(165, 0, 0) },
		Bot = { Vector3.new(-170, 0, 8), Vector3.new(-160, 0, 60), Vector3.new(-140, 0, 105), Vector3.new(-60, 0, 112), Vector3.new(60, 0, 112), Vector3.new(140, 0, 105), Vector3.new(160, 0, 60), Vector3.new(170, 0, 8) },
	},
	LaneOrder = { "Top", "Mid", "Bot" },
	-- Tuerme fuer Dawn; Dusk ist gespiegelt (X negiert)
	Towers = {
		{ Lane = "Top", Tier = 1, Position = Vector3.new(-70, 0, -112) },
		{ Lane = "Top", Tier = 2, Position = Vector3.new(-158, 0, -70) },
		{ Lane = "Mid", Tier = 1, Position = Vector3.new(-62, 0, 0) },
		{ Lane = "Mid", Tier = 2, Position = Vector3.new(-122, 0, 0) },
		{ Lane = "Bot", Tier = 1, Position = Vector3.new(-70, 0, 112) },
		{ Lane = "Bot", Tier = 2, Position = Vector3.new(-158, 0, 70) },
	},
	-- Monster im Dschungel (Dawn-Seite, gespiegelt fuer Dusk) und zwei neutrale Bosse in der Mitte
	Camps = {
		{ Id = "Beetles", Position = Vector3.new(-82, 0, -52) },
		{ Id = "Wisp", Position = Vector3.new(-82, 0, 52) },
	},
	Bosses = {
		{ Id = "Titan", Position = Vector3.new(0, 0, -62) },
		{ Id = "Golem", Position = Vector3.new(0, 0, 62) },
	},
}

---------------------------------------------------------------- Einheiten

Config.Structures = {
	Tower1 = { HP = 2600, Armor = 40, Damage = 110, Range = 26, AttackSpeed = 0.9, Gold = 150 },
	Tower2 = { HP = 3200, Armor = 50, Damage = 140, Range = 26, AttackSpeed = 0.9, Gold = 150 },
	Core = { HP = 4500, Armor = 40, Damage = 160, Range = 24, AttackSpeed = 1.0, Gold = 0 },
}
Config.TowerMinionDamage = 0.55 -- Anteil vom Turmschaden gegen Minions

Config.Minions = {
	Melee = { HP = 330, Damage = 14, Range = 5, AttackSpeed = 0.9, Speed = 14, Armor = 6, Gold = 22, XP = 32, Aggro = 14 },
	Caster = { HP = 230, Damage = 20, Range = 18, AttackSpeed = 0.75, Speed = 14, Armor = 0, Gold = 28, XP = 28, Aggro = 20 },
	Siege = { HP = 800, Damage = 36, Range = 20, AttackSpeed = 0.6, Speed = 13, Armor = 20, Gold = 55, XP = 60, Aggro = 22 },
}
Config.MinionGrowthPerWave = 0.035 -- HP/Schaden pro Welle
Config.Wave = { "Melee", "Melee", "Caster" }
Config.SiegeEvery = 3

Config.Monsters = {
	Beetles = { Name = "Gold Beetle", HP = 900, Damage = 28, Range = 7, AttackSpeed = 0.8, Armor = 10, Gold = 90, XP = 90, Respawn = 60, Color = Color3.fromRGB(255, 200, 60) },
	Wisp = { Name = "Crystal Wisp", HP = 750, Damage = 34, Range = 14, AttackSpeed = 0.8, Armor = 6, Gold = 70, XP = 120, Respawn = 60, Color = Color3.fromRGB(110, 220, 255) },
	Titan = { Name = "Sky Titan", HP = 4200, Damage = 70, Range = 11, AttackSpeed = 0.6, Armor = 35, Gold = 120, XP = 200, Respawn = 180, FirstSpawn = 150, Boss = true, Buff = "Might", Color = Color3.fromRGB(255, 110, 90) },
	Golem = { Name = "Treasure Golem", HP = 3200, Damage = 55, Range = 10, AttackSpeed = 0.6, Armor = 30, Gold = 250, XP = 150, Respawn = 150, FirstSpawn = 90, Boss = true, Color = Color3.fromRGB(255, 220, 90) },
}
Config.MightBuff = { Seconds = 90, Power = 0.25 } -- Titan-Segen fuer das ganze Team
Config.LeashRange = 28

---------------------------------------------------------------- Helden

Config.MaxLevel = 12
function Config.XPToLevel(level: number): number
	return 120 + level * 70
end
Config.StartGold = 500
Config.PassiveGold = 2.2 -- pro Sekunde
Config.KillGold = 300
Config.AssistGold = 120
Config.KillXP = 160
Config.ShareRange = 38 -- XP fuer Helden in der Naehe
Config.RespawnBase = 6
Config.RespawnPerLevel = 1.6
Config.RecallSeconds = 4
Config.FountainHeal = 0.12 -- Anteil der Max-HP pro Sekunde
Config.FountainDamage = 600
Config.AssistWindow = 10

-- Faehigkeiten: Type bestimmt die Logik in HeroService
--   Circle (um den Helden), Point (am Zielpunkt, mit Verzoegerung), Line (Skillshot), Dash, Target,
--   Chain, Shield, Heal, Buff, Zone (Flaeche, die mehrmals trifft)
Config.Heroes = {
	{
		Id = "Brakka",
		Name = "Brakka",
		Title = "The Mountain Fist",
		Role = "Tank",
		Icon = "✊",
		Free = true,
		Crystals = 0,
		Color = Color3.fromRGB(196, 140, 90),
		Weapon = "Gauntlet",
		Stats = { HP = 690, HPPerLevel = 96, Power = 32, PowerPerLevel = 4, Armor = 16, ArmorPerLevel = 2.6, AttackSpeed = 0.85, Range = 8, Speed = 17 },
		Abilities = {
			Q = { Name = "Boulder Smash", Type = "Circle", Cooldown = 6, Damage = 70, PerLevel = 24, Ratio = 0.6, Radius = 13, Slow = 0.3, SlowTime = 1.5, Desc = "Smash the ground and slow nearby enemies." },
			E = { Name = "Stone Skin", Type = "Shield", Cooldown = 12, Shield = 120, PerLevel = 32, Ratio = 0, Duration = 3.5, Desc = "Gain a rock shield." },
			R = { Name = "Earthquake", Type = "Circle", Cooldown = 48, Damage = 150, PerLevel = 40, Ratio = 0.8, Radius = 19, Stun = 1.2, Desc = "Stun every enemy around you." },
		},
	},
	{
		Id = "Lumi",
		Name = "Lumi",
		Title = "Starlight Mage",
		Role = "Mage",
		Icon = "✨",
		Free = true,
		Crystals = 0,
		Color = Color3.fromRGB(120, 210, 255),
		Weapon = "Staff",
		Stats = { HP = 480, HPPerLevel = 70, Power = 34, PowerPerLevel = 5, Armor = 8, ArmorPerLevel = 1.6, AttackSpeed = 0.72, Range = 24, Speed = 17 },
		Abilities = {
			Q = { Name = "Star Bolt", Type = "Line", Cooldown = 4, Damage = 85, PerLevel = 28, Ratio = 0.9, Length = 40, Width = 5, Desc = "Fire a bolt that hits everything in a line." },
			E = { Name = "Glimmer", Type = "Heal", Cooldown = 12, Heal = 60, PerLevel = 20, Ratio = 0.4, Radius = 18, Desc = "Heal yourself and nearby allies." },
			R = { Name = "Supernova", Type = "Point", Cooldown = 45, Damage = 220, PerLevel = 55, Ratio = 1.2, Range = 36, Radius = 14, Delay = 0.8, Desc = "A star crashes down after a short delay." },
		},
	},
	{
		Id = "Pip",
		Name = "Pip",
		Title = "Ember Archer",
		Role = "Marksman",
		Icon = "🏹",
		Free = true,
		Crystals = 0,
		Color = Color3.fromRGB(255, 120, 60),
		Weapon = "Bow",
		Stats = { HP = 500, HPPerLevel = 72, Power = 34, PowerPerLevel = 5, Armor = 8, ArmorPerLevel = 1.8, AttackSpeed = 1.0, Range = 26, Speed = 18 },
		Abilities = {
			Q = { Name = "Fire Volley", Type = "Line", Cooldown = 5, Damage = 60, PerLevel = 20, Ratio = 0.7, Length = 30, Width = 10, Desc = "A wide volley of burning arrows." },
			E = { Name = "Hot Feet", Type = "Buff", Cooldown = 12, Speed = 0.4, AttackSpeed = 0.3, Duration = 3, Desc = "Run and shoot faster for a moment." },
			R = { Name = "Meteor Rain", Type = "Point", Cooldown = 50, Damage = 200, PerLevel = 50, Ratio = 1.0, Range = 40, Radius = 16, Delay = 1.0, Slow = 0.4, SlowTime = 2, Desc = "Call meteors on an area and slow enemies." },
		},
	},
	{
		Id = "Vexa",
		Name = "Vexa",
		Title = "Shadow Blade",
		Role = "Assassin",
		Icon = "🗡️",
		Crystals = 450,
		Color = Color3.fromRGB(170, 80, 220),
		Weapon = "Daggers",
		Stats = { HP = 540, HPPerLevel = 80, Power = 38, PowerPerLevel = 5.5, Armor = 10, ArmorPerLevel = 2, AttackSpeed = 1.0, Range = 8, Speed = 19 },
		Abilities = {
			Q = { Name = "Shadow Step", Type = "Dash", Cooldown = 6, Damage = 80, PerLevel = 25, Ratio = 0.8, Range = 20, Radius = 6, ToTarget = true, Desc = "Blink to an enemy and strike." },
			E = { Name = "Fade", Type = "Buff", Cooldown = 12, Speed = 0.5, Reduction = 0.3, Duration = 2.5, Desc = "Move faster and take less damage." },
			R = { Name = "Final Cut", Type = "Target", Cooldown = 40, Damage = 150, PerLevel = 40, Ratio = 1.0, Range = 12, Execute = 0.25, Desc = "Huge damage, more against hurt enemies." },
		},
	},
	{
		Id = "Tundra",
		Name = "Tundra",
		Title = "Frost Warden",
		Role = "Tank",
		Icon = "❄️",
		Crystals = 450,
		Color = Color3.fromRGB(150, 230, 255),
		Weapon = "Shield",
		Stats = { HP = 720, HPPerLevel = 100, Power = 28, PowerPerLevel = 3.6, Armor = 18, ArmorPerLevel = 2.8, AttackSpeed = 0.8, Range = 8, Speed = 17 },
		Abilities = {
			Q = { Name = "Ice Shard", Type = "Line", Cooldown = 6, Damage = 70, PerLevel = 20, Ratio = 0.6, Length = 30, Width = 6, Slow = 0.4, SlowTime = 2, Desc = "Throw a shard that slows enemies." },
			E = { Name = "Glacier Armor", Type = "Shield", Cooldown = 14, Shield = 150, PerLevel = 36, Ratio = 0, Duration = 4, Desc = "Gain a thick ice shield." },
			R = { Name = "Blizzard", Type = "Zone", Cooldown = 52, Damage = 32, PerLevel = 10, Ratio = 0.2, Range = 30, Radius = 16, Duration = 3, Tick = 0.5, Slow = 0.5, SlowTime = 0.8, Desc = "A freezing storm that hurts and slows." },
		},
	},
	{
		Id = "Thorne",
		Name = "Thorne",
		Title = "Grove Keeper",
		Role = "Support",
		Icon = "🌿",
		Crystals = 550,
		Color = Color3.fromRGB(110, 210, 110),
		Weapon = "LeafStaff",
		Stats = { HP = 560, HPPerLevel = 80, Power = 28, PowerPerLevel = 4, Armor = 12, ArmorPerLevel = 2, AttackSpeed = 0.8, Range = 22, Speed = 17 },
		Abilities = {
			Q = { Name = "Vine Snare", Type = "Line", Cooldown = 8, Damage = 60, PerLevel = 20, Ratio = 0.5, Length = 34, Width = 5, Stun = 1.2, Desc = "Vines hold enemies in place." },
			E = { Name = "Bloom", Type = "Heal", Cooldown = 11, Heal = 80, PerLevel = 25, Ratio = 0.5, Radius = 20, Desc = "Heal yourself and allies around you." },
			R = { Name = "Ancient Grove", Type = "Heal", Cooldown = 60, Heal = 150, PerLevel = 40, Ratio = 0.6, Radius = 32, Speed = 0.3, Duration = 3, Desc = "Big team heal and a speed boost." },
		},
	},
	{
		Id = "Zephyr",
		Name = "Zephyr",
		Title = "Wind Ranger",
		Role = "Marksman",
		Icon = "🌪️",
		Crystals = 650,
		Color = Color3.fromRGB(170, 255, 220),
		Weapon = "Bow",
		Stats = { HP = 500, HPPerLevel = 72, Power = 33, PowerPerLevel = 5, Armor = 8, ArmorPerLevel = 1.8, AttackSpeed = 1.1, Range = 26, Speed = 18 },
		Abilities = {
			Q = { Name = "Gale Arrow", Type = "Line", Cooldown = 6, Damage = 80, PerLevel = 25, Ratio = 0.8, Length = 45, Width = 4, Knockback = 10, Desc = "A long shot that pushes enemies back." },
			E = { Name = "Tailwind", Type = "Dash", Cooldown = 9, Damage = 0, Range = 18, Desc = "Dash where you aim." },
			R = { Name = "Cyclone", Type = "Zone", Cooldown = 45, Damage = 40, PerLevel = 12, Ratio = 0.3, Range = 34, Radius = 14, Duration = 3, Tick = 0.5, Slow = 0.3, SlowTime = 0.8, Desc = "A cyclone that shreds an area." },
		},
	},
	{
		Id = "Volt",
		Name = "Volt",
		Title = "Storm Duelist",
		Role = "Fighter",
		Icon = "⚡",
		Crystals = 800,
		Color = Color3.fromRGB(255, 230, 80),
		Weapon = "Spear",
		Stats = { HP = 620, HPPerLevel = 88, Power = 36, PowerPerLevel = 5, Armor = 13, ArmorPerLevel = 2.2, AttackSpeed = 1.0, Range = 9, Speed = 18 },
		Abilities = {
			Q = { Name = "Chain Spark", Type = "Chain", Cooldown = 5, Damage = 70, PerLevel = 22, Ratio = 0.7, Range = 22, Bounce = 14, Bounces = 3, Desc = "Lightning that jumps between enemies." },
			E = { Name = "Overcharge", Type = "Buff", Cooldown = 12, AttackSpeed = 0.6, Duration = 4, Desc = "Attack much faster." },
			R = { Name = "Thunder Dive", Type = "Dash", Cooldown = 45, Damage = 180, PerLevel = 45, Ratio = 1.0, Range = 26, Radius = 14, Stun = 1, Desc = "Leap in and stun everyone where you land." },
		},
	},
}
Config.HeroesById = {}
for index, hero in Config.Heroes do
	hero.Order = index
	Config.HeroesById[hero.Id] = hero
end
Config.AbilityKeys = { "Q", "E", "R" }
Config.RoleBuilds = {
	Tank = { "GuardPlate", "SwiftBoots", "GolemHeart", "IronBlade", "TitanHammer", "PhoenixCharm" },
	Mage = { "ArcaneOrb", "SwiftBoots", "SageCrown", "GolemHeart", "PhoenixCharm", "TitanHammer" },
	Support = { "ArcaneOrb", "SwiftBoots", "GuardPlate", "SageCrown", "GolemHeart", "PhoenixCharm" },
	Marksman = { "IronBlade", "StormBoots", "EmberSword", "VampireFang", "TitanHammer", "GolemHeart" },
	Assassin = { "IronBlade", "SwiftBoots", "VampireFang", "EmberSword", "TitanHammer", "GuardPlate" },
	Fighter = { "IronBlade", "StormBoots", "VampireFang", "GolemHeart", "TitanHammer", "EmberSword" },
}

---------------------------------------------------------------- Items (nur in der Runde, mit Gold)

Config.MaxItems = 6
Config.SellRefund = 0.6
Config.Items = {
	{ Id = "IronBlade", Name = "Iron Blade", Icon = "🗡", Cost = 350, Stats = { Power = 12 } },
	{ Id = "GuardPlate", Name = "Guard Plate", Icon = "🛡", Cost = 400, Stats = { Armor = 16 } },
	{ Id = "ArcaneOrb", Name = "Arcane Orb", Icon = "🔮", Cost = 450, Stats = { Power = 14, Haste = 0.1 } },
	{ Id = "SwiftBoots", Name = "Swift Boots", Icon = "👟", Cost = 300, Boots = true, Stats = { Speed = 3 } },
	{ Id = "StormBoots", Name = "Storm Boots", Icon = "⚡", Cost = 900, Boots = true, Stats = { Speed = 4, AttackSpeed = 0.2 } },
	{ Id = "EmberSword", Name = "Ember Sword", Icon = "🔥", Cost = 1100, Stats = { Power = 28, AttackSpeed = 0.18 } },
	{ Id = "VampireFang", Name = "Vampire Fang", Icon = "🦷", Cost = 1300, Stats = { Power = 24, Lifesteal = 0.15 } },
	{ Id = "SageCrown", Name = "Sage Crown", Icon = "👑", Cost = 1500, Stats = { Power = 40, Haste = 0.25 } },
	{ Id = "GolemHeart", Name = "Golem Heart", Icon = "💎", Cost = 1600, Stats = { HP = 420, Armor = 24 } },
	{ Id = "PhoenixCharm", Name = "Phoenix Charm", Icon = "🪶", Cost = 2200, Stats = { HP = 300, Power = 30, Regen = 9 } },
	{ Id = "TitanHammer", Name = "Titan Hammer", Icon = "🔨", Cost = 2400, Stats = { Power = 55, HP = 220 } },
}
Config.ItemsById = {}
for index, item in Config.Items do
	item.Order = index
	Config.ItemsById[item.Id] = item
end
Config.MaxHaste = 0.45

---------------------------------------------------------------- Skins (fuer alle Helden)

Config.Skins = {
	{ Id = "Default", Name = "Classic", Free = true },
	{ Id = "Crimson", Name = "Crimson", Crystals = 1500, Color = Color3.fromRGB(220, 40, 60), Material = Enum.Material.SmoothPlastic },
	{ Id = "Inferno", Name = "Inferno", Product = "Skin_Inferno", Color = Color3.fromRGB(255, 110, 30), Material = Enum.Material.Neon, Particles = "Fire" },
	{ Id = "Frost", Name = "Frost Crystal", Product = "Skin_Frost", Color = Color3.fromRGB(160, 230, 255), Material = Enum.Material.Glass, Particles = "Snow" },
	{ Id = "Gold", Name = "Royal Gold", Product = "Skin_Gold", Color = Color3.fromRGB(255, 200, 50), Material = Enum.Material.Foil, Particles = "Sparkle" },
	{ Id = "Galaxy", Name = "Galaxy", Product = "Skin_Galaxy", Color = Color3.fromRGB(120, 70, 255), Material = Enum.Material.Neon, Particles = "Stars" },
}
Config.SkinsById = {}
for index, skin in Config.Skins do
	skin.Order = index
	Config.SkinsById[skin.Id] = skin
end

---------------------------------------------------------------- Belohnungen (Kristalle bleiben gespeichert)

Config.Rewards = { Win = 50, Loss = 20, PerKill = 4, PerAssist = 2, MaxKillBonus = 30, FirstWinBonus = 60 }
Config.DailyRewards = { 40, 60, 80, 100, 120, 150, 300 }
Config.AdCooldown = 300

---------------------------------------------------------------- Developer Products (IDs kommen beim Veroeffentlichen in ProductIds.json)

local ids = {}
local ok, decoded = pcall(function()
	local module = ReplicatedStorage:FindFirstChild("Shared")
	local file = module and module:FindFirstChild("ProductIds")
	if file and file:IsA("ModuleScript") then
		return require(file)
	end
	return {}
end)
if ok and typeof(decoded) == "table" then
	ids = decoded
end

-- "Pass" = dauerhaft (gespeichert), sonst einmaliger Kauf
Config.Products = {
	Pass_VIP = { Name = "VIP", Kind = "Pass", Price = 299, Description = "+50% crystals, golden name and VIP chat tag forever", Order = 1 },
	Pass_DoubleCrystals = { Name = "2x Crystals", Kind = "Pass", Price = 249, Description = "Double crystals from every match forever", Order = 2 },
	AllHeroes = { Name = "All Heroes", Kind = "AllHeroes", Price = 399, Description = "Unlock every hero now and every future hero", Order = 3 },
	StarterPack = { Name = "Starter Pack", Kind = "StarterPack", Price = 79, Description = "One time: Volt + Inferno skin + 500 crystals", Order = 0, OneTime = true },
	Hero_Vexa = { Name = "Vexa", Kind = "Hero", Hero = "Vexa", Price = 99, Description = "Unlock Vexa, the Shadow Blade" },
	Hero_Tundra = { Name = "Tundra", Kind = "Hero", Hero = "Tundra", Price = 99, Description = "Unlock Tundra, the Frost Warden" },
	Hero_Thorne = { Name = "Thorne", Kind = "Hero", Hero = "Thorne", Price = 99, Description = "Unlock Thorne, the Grove Keeper" },
	Hero_Zephyr = { Name = "Zephyr", Kind = "Hero", Hero = "Zephyr", Price = 149, Description = "Unlock Zephyr, the Wind Ranger" },
	Hero_Volt = { Name = "Volt", Kind = "Hero", Hero = "Volt", Price = 149, Description = "Unlock Volt, the Storm Duelist" },
	Skin_Inferno = { Name = "Inferno Skin", Kind = "Skin", Skin = "Inferno", Price = 149, Description = "Burning weapon and aura for all heroes" },
	Skin_Frost = { Name = "Frost Crystal Skin", Kind = "Skin", Skin = "Frost", Price = 149, Description = "Icy weapon and aura for all heroes" },
	Skin_Gold = { Name = "Royal Gold Skin", Kind = "Skin", Skin = "Gold", Price = 249, Description = "Shining gold weapon and aura for all heroes" },
	Skin_Galaxy = { Name = "Galaxy Skin", Kind = "Skin", Skin = "Galaxy", Price = 349, Description = "Starry weapon and aura for all heroes" },
	Crystals_S = { Name = "Crystal Pouch", Kind = "Crystals", Amount = 250, Price = 49, Description = "250 crystals", Order = 10 },
	Crystals_M = { Name = "Crystal Chest", Kind = "Crystals", Amount = 900, Price = 149, Description = "900 crystals", Order = 11 },
	Crystals_L = { Name = "Crystal Vault", Kind = "Crystals", Amount = 2800, Price = 399, Description = "2800 crystals", Order = 12 },
	Respawn = { Name = "Instant Respawn", Kind = "Respawn", Price = 15, Description = "Respawn right now" },
	AdReward = { Name = "Free Crystals (Video Ad)", Kind = "Crystals", Amount = 40, Price = 5, Description = "Reward for watching a video ad", Hidden = true },
}
for key, product in Config.Products do
	product.Key = key
	product.Id = tonumber(ids[key]) or 0
end

return Config
