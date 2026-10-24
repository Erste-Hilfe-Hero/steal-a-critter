-- Alle Zahlen des Spiels an einem Ort: Karte, Gebaeude, Minions, Dschungel, Helden mit Q/W/E/R,
-- Beschwoererzauber, Items mit Bauteilen, Belohnungen und Produkte.
-- Aufbau und Werte orientieren sich an klassischen 5v5-MOBAs; Zeiten sind etwa halbiert, damit eine Runde 15-25 Minuten dauert.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.GameName = "Lanebreakers"
Config.DataStoreName = "Lanebreakers_v1"
Config.StudioFakePurchases = true

---------------------------------------------------------------- Teams

Config.TeamSize = 5
Config.Teams = {
	[1] = { Name = "Dawn", Color = Color3.fromRGB(80, 170, 255), Dark = Color3.fromRGB(26, 70, 140), Hex = "#50AAFF" },
	[2] = { Name = "Dusk", Color = Color3.fromRGB(255, 84, 84), Dark = Color3.fromRGB(130, 30, 40), Hex = "#FF5454" },
}
Config.NeutralColor = Color3.fromRGB(255, 196, 70)

---------------------------------------------------------------- Ablauf (Sekunden ab Spielbeginn)

Config.PickSeconds = 30
Config.EndSeconds = 16
Config.Timers = {
	Minions = 30, -- erste Welle
	WaveInterval = 30,
	Jungle = 45,
	Scuttle = 90,
	Drake = 150,
	DrakeRespawn = 150,
	Herald = 240,
	HeraldDespawn = 585,
	Baron = 600,
	BaronRespawn = 180,
	Elder = 180, -- nach der Drachenseele
	Inhibitor = 150, -- Inhibitor baut sich wieder auf
	Plates = 420, -- bis dahin haben aeussere Tuerme Gold-Platten
	Surrender = 480,
	Overtime = 1500, -- danach werden Minions staerker, damit Runden enden
	MaxMatch = 2400,
}

---------------------------------------------------------------- Karte
-- Quadratische Karte, Dawn unten links, Dusk oben rechts. Dusk ist punktgespiegelt (Position * -1).
-- Dabei wird aus der oberen Lane von Dawn die untere von Dusk und umgekehrt.

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

Config.Map = {
	Half = 178,
	Fountain = { [1] = v(-160, 160), [2] = v(160, -160) },
	FountainRadius = 17,
	Nexus = v(-132, 132),
	-- Wegpunkte jeder Lane von Dawn nach Dusk
	Lanes = {
		Top = { v(-140, 116), v(-150, 70), v(-150, -112), v(-138, -138), v(-112, -150), v(70, -150), v(116, -140) },
		Mid = { v(-116, 116), v(116, -116) },
		Bot = { v(-116, 140), v(-70, 150), v(112, 150), v(138, 138), v(150, 112), v(150, -70), v(140, -116) },
	},
	LaneOrder = { "Top", "Mid", "Bot" },
	LaneWidth = 20,
	-- Tuerme von Dawn (Tier 1 aussen, 2 innen, 3 am Inhibitor)
	Towers = {
		{ Lane = "Top", Tier = 1, Position = v(-150, -72) },
		{ Lane = "Top", Tier = 2, Position = v(-150, 6) },
		{ Lane = "Top", Tier = 3, Position = v(-150, 74) },
		{ Lane = "Mid", Tier = 1, Position = v(-34, 34) },
		{ Lane = "Mid", Tier = 2, Position = v(-64, 64) },
		{ Lane = "Mid", Tier = 3, Position = v(-94, 94) },
		{ Lane = "Bot", Tier = 1, Position = v(72, 150) },
		{ Lane = "Bot", Tier = 2, Position = v(-6, 150) },
		{ Lane = "Bot", Tier = 3, Position = v(-74, 150) },
	},
	Inhibitors = {
		{ Lane = "Top", Position = v(-148, 98) },
		{ Lane = "Mid", Position = v(-114, 114) },
		{ Lane = "Bot", Position = v(-98, 148) },
	},
	NexusTowers = { v(-122, 136), v(-136, 122) },
	-- Dschungel-Lager von Dawn (Dusk gespiegelt). Mehrere Monster pro Lager.
	Camps = {
		{ Id = "Blue", Position = v(-98, 4), Monsters = { "BlueSentinel" } },
		{ Id = "Gromp", Position = v(-124, -22), Monsters = { "Gromp" } },
		{ Id = "Wolves", Position = v(-84, 36), Monsters = { "Wolf", "Pup", "Pup" } },
		{ Id = "Red", Position = v(4, 100), Monsters = { "RedBrambleback" } },
		{ Id = "Raptors", Position = v(-26, 74), Monsters = { "Raptor", "Chick", "Chick" } },
		{ Id = "Krugs", Position = v(40, 124), Monsters = { "Krug", "Krugling" } },
	},
	-- Neutral im Fluss (nicht gespiegelt)
	River = {
		{ Id = "ScuttleTop", Position = v(-40, -40), Monsters = { "Scuttle" } },
		{ Id = "ScuttleBot", Position = v(40, 40), Monsters = { "Scuttle" } },
	},
	DragonPit = v(76, 76),
	BaronPit = v(-76, -76),
	-- Buesche: Mittelpunkt, Groesse (X, Z), Drehung in Grad
	Brush = {
		{ v(-160, -40), v(10, 26), 0 }, { v(-138, -160), v(26, 10), 0 },
		{ v(40, 160), v(26, 10), 0 }, { v(160, 40), v(10, 26), 0 },
		{ v(-22, -2), v(22, 9), 45 }, { v(2, 22), v(22, 9), 45 },
		{ v(-40, -72), v(20, 9), -45 }, { v(-72, -40), v(20, 9), -45 },
		{ v(40, 72), v(20, 9), -45 }, { v(72, 40), v(20, 9), -45 },
		{ v(-112, 26), v(16, 9), 0 }, { v(26, 112), v(9, 16), 0 },
		{ v(112, -26), v(16, 9), 0 }, { v(-26, -112), v(9, 16), 0 },
		{ v(-60, 6), v(9, 18), 45 }, { v(-6, 60), v(9, 18), 45 },
		{ v(60, -6), v(9, 18), 45 }, { v(6, -60), v(9, 18), 45 },
	},
}
Config.MirrorLane = { Top = "Bot", Mid = "Mid", Bot = "Top" }

-- Index des Busches an dieser Position (oder nil)
function Config.BrushAt(position: Vector3): number?
	for index, brush in Config.Map.Brush do
		local offset = position - brush[1]
		local angle = math.rad(brush[3])
		local c, s = math.cos(angle), math.sin(angle)
		local x = offset.X * c - offset.Z * s
		local z = offset.X * s + offset.Z * c
		if math.abs(x) <= brush[2].X / 2 and math.abs(z) <= brush[2].Z / 2 then
			return index
		end
	end
	return nil
end

function Config.Mirror(position: Vector3, team: number): Vector3
	if team == 2 then
		return Vector3.new(-position.X, position.Y, -position.Z)
	end
	return position
end

-- Lane-Wegpunkte aus Sicht eines Teams (vom eigenen Nexus zum gegnerischen)
function Config.LanePoints(lane: string, team: number): { Vector3 }
	local points = Config.Map.Lanes[lane]
	if team == 1 then
		return points
	end
	local reversed = {}
	for i = #points, 1, -1 do
		table.insert(reversed, points[i])
	end
	return reversed
end

---------------------------------------------------------------- Gebaeude

Config.Structures = {
	Tower1 = { HP = 4200, Armor = 40, MR = 40, Damage = 150, Range = 27, AttackSpeed = 0.83, Gold = 250, GlobalGold = 50, Plates = 5, PlateGold = 120 },
	Tower2 = { HP = 3600, Armor = 55, MR = 55, Damage = 170, Range = 27, AttackSpeed = 0.83, Gold = 225, GlobalGold = 50 },
	Tower3 = { HP = 3300, Armor = 65, MR = 65, Damage = 190, Range = 27, AttackSpeed = 0.83, Gold = 175, GlobalGold = 50 },
	NexusTower = { HP = 2700, Armor = 65, MR = 65, Damage = 200, Range = 27, AttackSpeed = 0.83, Gold = 50, GlobalGold = 50 },
	Inhibitor = { HP = 3000, Armor = 20, MR = 20, Gold = 50, GlobalGold = 50 },
	Nexus = { HP = 5000, Armor = 0, MR = 0 },
}
Config.TowerDamagePerMinute = 6 -- Turmschaden steigt mit der Spielzeit
Config.TowerRampPerShot = 0.4 -- jeder weitere Treffer auf denselben Helden +40 %
Config.TowerRampMax = 1.2
-- Anteil der Max-HP, die ein Turmschuss einem Minion abzieht
Config.TowerMinionShare = { Melee = 0.45, Caster = 0.7, Siege = 0.14, Super = 0.07, Herald = 0.05 }

---------------------------------------------------------------- Minions

Config.Minions = {
	Melee = { HP = 470, Damage = 13, Range = 5, AttackSpeed = 1.25, Speed = 15, Armor = 0, MR = 0, Gold = 21, XP = 60, Aggro = 16 },
	Caster = { HP = 290, Damage = 24, Range = 22, AttackSpeed = 0.67, Speed = 15, Armor = 0, MR = 0, Gold = 14, XP = 30, Aggro = 22 },
	Siege = { HP = 900, Damage = 40, Range = 26, AttackSpeed = 1.0, Speed = 15, Armor = 0, MR = 0, Gold = 60, XP = 93, Aggro = 26 },
	Super = { HP = 1600, Damage = 190, Range = 7, AttackSpeed = 0.85, Speed = 15, Armor = 30, MR = -30, Gold = 60, XP = 97, Aggro = 18 },
}
Config.MinionGrowthPerWave = 0.03
Config.Wave = { "Melee", "Melee", "Melee", "Caster", "Caster", "Caster" }
Config.SiegeEvery = 3

---------------------------------------------------------------- Dschungel und Ziele

Config.Monsters = {
	BlueSentinel = { Name = "Azure Sentinel", HP = 2100, Damage = 66, Range = 8, AttackSpeed = 0.5, Armor = 10, MR = 0, Gold = 90, XP = 160, Respawn = 150, Buff = "Blue", Color = Color3.fromRGB(90, 150, 255), Size = 6, Shape = "Golem" },
	RedBrambleback = { Name = "Ember Brambleback", HP = 2100, Damage = 66, Range = 8, AttackSpeed = 0.5, Armor = 10, MR = 0, Gold = 90, XP = 160, Respawn = 150, Buff = "Red", Color = Color3.fromRGB(240, 90, 50), Size = 6, Shape = "Golem" },
	Gromp = { Name = "Bog Toad", HP = 1800, Damage = 70, Range = 16, AttackSpeed = 0.6, Armor = 0, MR = -10, Gold = 80, XP = 135, Respawn = 70, Color = Color3.fromRGB(110, 170, 90), Size = 5, Shape = "Blob" },
	Wolf = { Name = "Grave Wolf", HP = 1600, Damage = 34, Range = 6, AttackSpeed = 0.7, Armor = 10, MR = 0, Gold = 55, XP = 95, Respawn = 70, Color = Color3.fromRGB(120, 120, 140), Size = 4, Shape = "Beast" },
	Pup = { Name = "Wolf Pup", HP = 420, Damage = 14, Range = 5, AttackSpeed = 0.7, Armor = 0, MR = 0, Gold = 14, XP = 25, Respawn = 70, Color = Color3.fromRGB(150, 150, 170), Size = 2.6, Shape = "Beast" },
	Raptor = { Name = "Crimson Raptor", HP = 1200, Damage = 20, Range = 6, AttackSpeed = 1.0, Armor = 15, MR = 15, Gold = 35, XP = 50, Respawn = 70, Color = Color3.fromRGB(230, 70, 90), Size = 3.6, Shape = "Bird" },
	Chick = { Name = "Raptor Chick", HP = 380, Damage = 12, Range = 5, AttackSpeed = 1.0, Armor = 0, MR = 0, Gold = 12, XP = 20, Respawn = 70, Color = Color3.fromRGB(240, 120, 130), Size = 2.2, Shape = "Bird" },
	Krug = { Name = "Ancient Krug", HP = 1350, Damage = 70, Range = 6, AttackSpeed = 0.6, Armor = 25, MR = 0, Gold = 70, XP = 90, Respawn = 70, Color = Color3.fromRGB(160, 130, 100), Size = 5, Shape = "Rock" },
	Krugling = { Name = "Krugling", HP = 520, Damage = 24, Range = 5, AttackSpeed = 0.6, Armor = 10, MR = 0, Gold = 20, XP = 30, Respawn = 70, Color = Color3.fromRGB(180, 150, 120), Size = 3, Shape = "Rock" },
	Scuttle = { Name = "River Scuttler", HP = 1050, Damage = 0, Range = 0, AttackSpeed = 0.1, Armor = 40, MR = 40, Gold = 70, XP = 120, Respawn = 150, Passive = true, Color = Color3.fromRGB(110, 200, 220), Size = 4, Shape = "Crab" },
	Drake = { Name = "Drake", HP = 3800, Damage = 90, Range = 14, AttackSpeed = 0.5, Armor = 21, MR = 30, Gold = 25, XP = 300, Epic = true, Color = Color3.fromRGB(255, 120, 60), Size = 9, Shape = "Dragon" },
	Elder = { Name = "Elder Drake", HP = 7000, Damage = 150, Range = 16, AttackSpeed = 0.5, Armor = 60, MR = 70, Gold = 50, XP = 500, Epic = true, Color = Color3.fromRGB(190, 230, 255), Size = 11, Shape = "Dragon" },
	Herald = { Name = "Siege Herald", HP = 6000, Damage = 100, Range = 9, AttackSpeed = 0.5, Armor = 60, MR = 50, Gold = 100, XP = 350, Epic = true, Color = Color3.fromRGB(170, 90, 255), Size = 9, Shape = "Herald" },
	Baron = { Name = "Abyss Tyrant", HP = 9000, Damage = 160, Range = 18, AttackSpeed = 0.6, Armor = 120, MR = 70, Gold = 300, XP = 600, Epic = true, Color = Color3.fromRGB(150, 60, 220), Size = 14, Shape = "Baron" },
}
Config.LeashRange = 26

-- Buffs aus dem Dschungel
Config.Buffs = {
	Blue = { Name = "Azure Insight", Icon = "🔷", Seconds = 90, AH = 10, ManaRegenPct = 0.01, Color = Color3.fromRGB(90, 150, 255) },
	Red = { Name = "Ember Fury", Icon = "🔥", Seconds = 90, BurnTrue = 10, BurnPerLevel = 2, Slow = 0.1, Regen = 6, Color = Color3.fromRGB(240, 90, 50) },
	Baron = { Name = "Tyrant's Hand", Icon = "👁", Seconds = 120, AD = 40, AP = 60, Color = Color3.fromRGB(170, 80, 255) },
	Elder = { Name = "Elder Aspect", Icon = "🐉", Seconds = 120, Execute = 0.2, Color = Color3.fromRGB(190, 230, 255) },
}
-- Elementar-Drachen: jedes Team sammelt Stapel, bei 4 gibt es die Seele
Config.Drakes = {
	{ Id = "Infernal", Name = "Ember Drake", Icon = "🔥", Color = Color3.fromRGB(255, 110, 50), Desc = "+6% AD and AP per stack", PowerPct = 0.06 },
	{ Id = "Mountain", Name = "Stone Drake", Icon = "⛰", Color = Color3.fromRGB(190, 150, 100), Desc = "+8% armor and MR per stack", ResistPct = 0.08 },
	{ Id = "Ocean", Name = "Tide Drake", Icon = "🌊", Color = Color3.fromRGB(60, 190, 210), Desc = "Restore 0.5% missing HP per second per stack", RegenPct = 0.005 },
	{ Id = "Cloud", Name = "Gale Drake", Icon = "🌪", Color = Color3.fromRGB(200, 230, 255), Desc = "+5% move speed per stack", SpeedPct = 0.05 },
}
Config.DrakesById = {}
for _, drake in Config.Drakes do
	Config.DrakesById[drake.Id] = drake
end
Config.DrakeSoul = 4

---------------------------------------------------------------- Helden: Grundregeln

Config.MaxLevel = 18
function Config.XPToLevel(level: number): number
	return 180 + level * 100
end
Config.XPMultiplier = 1.6
Config.ShareRange = 46
Config.StartGold = 500
Config.PassiveGold = 3 -- pro Sekunde, ab Minions
Config.KillGold = 300
Config.FirstBloodGold = 100
Config.AssistGold = 150 -- wird geteilt
Config.KillXP = 140
Config.AssistWindow = 10
Config.MultiKillWindow = 10
Config.RecallSeconds = 8
Config.BaronRecallSeconds = 4
Config.FountainHeal = 0.1 -- Anteil der Max-HP/Mana pro Sekunde
Config.FountainDamage = 1000
Config.CritDamage = 1.75
Config.MaxCrit = 1
Config.HeroSpeedScale = 1 / 21 -- 340 Laufgeschwindigkeit = 16 Studs/s

function Config.RespawnTime(level: number, elapsed: number): number
	return 5 + level * 1.5 + math.max(0, elapsed - 900) / 60 * 0.6
end

-- Faehigkeitsraenge: Q/W/E bis 5, R bis 3 (ab Stufe 6/11/16)
function Config.CanRank(key: string, rank: number, level: number): boolean
	if key == "R" then
		return rank < 3 and level >= 6 + rank * 5
	end
	return rank < 5 and level >= rank * 2 + 1
end
Config.AbilityKeys = { "Q", "W", "E", "R" }
-- Standard-Reihenfolge fuer automatisches Leveln (R immer zuerst, wenn moeglich)
Config.SkillOrder = { "Q", "W", "E", "Q", "Q", "R", "Q", "W", "Q", "W", "R", "W", "W", "E", "E", "R", "E", "E" }

Config.Roles = {
	{ Id = "Top", Name = "Top", Icon = "🛡", Lane = "Top" },
	{ Id = "Jungle", Name = "Jungle", Icon = "🌲", Lane = "Jungle" },
	{ Id = "Mid", Name = "Mid", Icon = "✨", Lane = "Mid" },
	{ Id = "Bot", Name = "Bot", Icon = "🏹", Lane = "Bot" },
	{ Id = "Support", Name = "Support", Icon = "💚", Lane = "Bot" },
}
Config.RolesById = {}
for index, role in Config.Roles do
	role.Order = index
	Config.RolesById[role.Id] = role
end

---------------------------------------------------------------- Helden
-- Werte pro Rang als Liste. AD/BonusAD/AP = Anteil am (Bonus-)Angriffsschaden bzw. an der Faehigkeitsstaerke.

local function ranks(first: number, step: number, count: number?): { number }
	local list = {}
	for i = 1, count or 5 do
		table.insert(list, first + step * (i - 1))
	end
	return list
end

Config.Heroes = {
	{
		Id = "Brakka",
		Name = "Brakka",
		Title = "The Living Mountain",
		Roles = { "Top", "Support" },
		Class = "Tank",
		Icon = "⛰️",
		Free = true,
		Crystals = 0,
		Color = Color3.fromRGB(196, 140, 90),
		Weapon = "Gauntlet",
		Stats = { HP = 640, HPPerLevel = 104, Mana = 280, ManaPerLevel = 50, AD = 62, ADPerLevel = 4, Armor = 37, ArmorPerLevel = 4.7, MR = 28, MRPerLevel = 2, AttackSpeed = 0.736, ASPerLevel = 0.03, Range = 7, Speed = 335, HPRegen = 1.4, ManaRegen = 1.4 },
		Passive = { Id = "GraniteShield", Name = "Granite Shield", Desc = "Gain a shield worth 10% max HP. It comes back after 10 seconds without taking damage." },
		Abilities = {
			Q = { Name = "Seismic Shard", Icon = "🪨", Type = "Target", Range = 30, Cost = 70, Cooldown = ranks(8, -0.5), Damage = ranks(70, 50), AP = 0.6, DamageType = "Magic", Slow = 0.25, SlowTime = 3, SelfSpeed = 0.2, SelfSpeedTime = 3, Desc = "Hurl a shard: damage and steal move speed." },
			W = { Name = "Thunderclap", Icon = "💥", Type = "Empower", Cost = 25, Cooldown = ranks(12, -1), Damage = ranks(30, 15), AD = 0.2, Armor = 0.15, DamageType = "Physical", Attacks = 1, Splash = 9, BonusArmor = ranks(10, 5), Duration = 6, Desc = "Gain armor; your next attack thunders in an area." },
			E = { Name = "Ground Slam", Icon = "🌋", Type = "Circle", Radius = 13, Cost = 50, Cooldown = ranks(7, -0.5), Damage = ranks(70, 40), AP = 0.6, Armor = 0.3, DamageType = "Magic", Slow = 0.3, SlowTime = 3, Desc = "Slam the ground: damage scales with armor." },
			R = { Name = "Unstoppable Avalanche", Icon = "🏔️", Type = "Dash", Range = 40, Cost = 100, Cooldown = { 100, 80, 60 }, Damage = { 200, 300, 400 }, AP = 0.8, DamageType = "Magic", Radius = 12, Stun = 1.5, Unstoppable = true, Desc = "Charge to a spot and knock up every enemy there." },
		},
		Build = { Start = { "GuardBuckler", "RedTonic" }, Items = { "IronTreads", "EmberAegis", "BramblePlate", "SpiritWard", "GiantHeart", "HourglassOfStasis" } },
	},
	{
		Id = "Lumi",
		Name = "Lumi",
		Title = "Lady of Radiance",
		Roles = { "Mid", "Support" },
		Class = "Mage",
		Icon = "✨",
		Free = true,
		Crystals = 0,
		Color = Color3.fromRGB(150, 225, 255),
		Weapon = "Staff",
		Stats = { HP = 560, HPPerLevel = 99, Mana = 480, ManaPerLevel = 23, AD = 54, ADPerLevel = 3.3, Armor = 18, ArmorPerLevel = 4.2, MR = 30, MRPerLevel = 1.3, AttackSpeed = 0.669, ASPerLevel = 0.01, Range = 26, Speed = 330, HPRegen = 1.1, ManaRegen = 1.6 },
		Passive = { Id = "Illumination", Name = "Illumination", Desc = "Abilities mark enemies. Your next attack on a marked enemy detonates the light for bonus magic damage." },
		Abilities = {
			Q = { Name = "Light Binding", Icon = "🔗", Type = "Line", Length = 52, Width = 4, Speed = 110, MaxHits = 2, Cost = 50, Cooldown = ranks(11, -0.5), Damage = ranks(80, 45), AP = 0.6, DamageType = "Magic", Root = 2, Desc = "A light orb that roots the first two enemies hit." },
			W = { Name = "Prismatic Barrier", Icon = "🛡", Type = "Shield", Radius = 26, Cost = 60, Cooldown = ranks(14, -1), Shield = ranks(45, 20), AP = 0.35, Duration = 2.5, Desc = "Shield yourself and allies near you." },
			E = { Name = "Lucent Singularity", Icon = "🌟", Type = "Point", Range = 46, Radius = 13, Delay = 1, Cost = 70, Cooldown = ranks(10, -0.5), Damage = ranks(70, 50), AP = 0.8, DamageType = "Magic", Slow = 0.3, SlowTime = 1.5, Desc = "A zone of light slows enemies, then detonates." },
			R = { Name = "Final Spark", Icon = "🌈", Type = "Line", Length = 120, Width = 7, Delay = 0.8, Cost = 100, Cooldown = { 60, 45, 30 }, Damage = { 300, 400, 500 }, AP = 1.0, DamageType = "Magic", Desc = "After a short charge, fire a huge laser across the map." },
		},
		Build = { Start = { "ApprenticeRing", "RedTonic" }, Items = { "SpellTreads", "EchoStaff", "ArchmageCrown", "VoidRod", "HourglassOfStasis", "MoonChalice" } },
	},
	{
		Id = "Pip",
		Name = "Pip",
		Title = "The Loose Cannon",
		Roles = { "Bot" },
		Class = "Marksman",
		Icon = "🚀",
		Free = true,
		Crystals = 0,
		Color = Color3.fromRGB(255, 120, 200),
		Weapon = "Bow",
		Stats = { HP = 630, HPPerLevel = 100, Mana = 260, ManaPerLevel = 50, AD = 59, ADPerLevel = 3.4, Armor = 26, ArmorPerLevel = 4.7, MR = 30, MRPerLevel = 1.3, AttackSpeed = 0.625, ASPerLevel = 0.014, Range = 26, Speed = 325, HPRegen = 0.75, ManaRegen = 1.3 },
		Passive = { Id = "GetExcited", Name = "Get Excited!", Desc = "Getting a takedown or destroying a tower gives a huge burst of move speed and attack speed." },
		Abilities = {
			Q = { Name = "Rocket Rush", Icon = "🎆", Type = "Buff", Cost = 20, Cooldown = ranks(10, -0.5), AttackSpeed = ranks(0.3, 0.1), Range = 6, Splash = 6, Duration = 5, Desc = "Switch to rockets: more range and splash damage, faster attacks." },
			W = { Name = "Zap!", Icon = "⚡", Type = "Line", Length = 60, Width = 3, Speed = 140, MaxHits = 1, Delay = 0.4, Cost = 50, Cooldown = ranks(8, -0.5), Damage = ranks(10, 50), AD = 1.4, DamageType = "Physical", Slow = 0.4, SlowTime = 2, Desc = "A long shock blast that slows the first enemy hit." },
			E = { Name = "Flame Chompers", Icon = "🪤", Type = "Point", Range = 36, Radius = 8, Delay = 0.8, Cost = 70, Cooldown = ranks(22, -2), Damage = ranks(70, 50), AP = 1.0, DamageType = "Magic", Root = 1.5, Desc = "Throw traps that root enemies who step in." },
			R = { Name = "Mega Rocket", Icon = "🚀", Type = "Line", Length = 360, Width = 6, Speed = 160, MaxHits = 1, Cost = 100, Cooldown = { 75, 60, 45 }, Damage = { 250, 400, 550 }, BonusAD = 1.5, Missing = { 0.25, 0.3, 0.35 }, DamageType = "Physical", HeroOnly = true, Explode = 12, Desc = "A rocket across the map: more damage the more health the target is missing." },
		},
		Build = { Start = { "SquireBlade", "RedTonic" }, Items = { "SwiftGreaves", "StormBow", "EndlessEdge", "BloodReaver", "VoidCutter", "Guardian" } },
	},
	{
		Id = "Vexa",
		Name = "Vexa",
		Title = "The Void Stalker",
		Roles = { "Jungle", "Mid" },
		Class = "Assassin",
		Icon = "🦂",
		Crystals = 450,
		Color = Color3.fromRGB(170, 80, 220),
		Weapon = "Daggers",
		Stats = { HP = 640, HPPerLevel = 99, Mana = 330, ManaPerLevel = 40, AD = 63, ADPerLevel = 3.1, Armor = 32, ArmorPerLevel = 4.2, MR = 32, MRPerLevel = 2, AttackSpeed = 0.668, ASPerLevel = 0.027, Range = 7, Speed = 350, HPRegen = 1.5, ManaRegen = 1.5 },
		Passive = { Id = "Isolation", Name = "Hunt the Lonely", Desc = "Attacks and abilities deal 30% more damage to enemies with no allies nearby." },
		Abilities = {
			Q = { Name = "Taste Their Fear", Icon = "🦷", Type = "Target", Range = 9, Cost = 25, Cooldown = ranks(4, -0.2), Damage = ranks(60, 25), BonusAD = 1.15, DamageType = "Physical", IsolatedBonus = 1.1, Desc = "Slash an enemy. Huge damage if they are isolated." },
			W = { Name = "Void Spike", Icon = "🗡", Type = "Line", Length = 46, Width = 4, Speed = 120, MaxHits = 1, Cost = 55, Cooldown = ranks(9, 0), Damage = ranks(80, 30), BonusAD = 1.0, DamageType = "Physical", HealSelf = ranks(55, 20), Slow = 0.4, SlowTime = 2, Desc = "Fire spikes that slow; heal if you are in a brush." },
			E = { Name = "Leap", Icon = "🦗", Type = "Dash", Range = 32, Cost = 50, Cooldown = ranks(18, -1.5), Damage = ranks(65, 35), BonusAD = 0.2, DamageType = "Physical", Radius = 8, Desc = "Leap to a spot and damage enemies where you land." },
			R = { Name = "Void Assault", Icon = "🌑", Type = "Stealth", Cost = 100, Cooldown = { 90, 70, 50 }, Duration = { 2, 2.5, 3 }, Speed = 0.4, ResetKey = "Q", Desc = "Turn invisible and faster. Resets Taste Their Fear." },
		},
		Build = { Start = { "HuntersMachete", "RedTonic" }, Items = { "IronTreads", "NightEdge", "VoidCutter", "RiftCleaver", "Guardian", "BloodReaver" } },
	},
	{
		Id = "Tundra",
		Name = "Tundra",
		Title = "The Winter's Wrath",
		Roles = { "Jungle", "Support", "Top" },
		Class = "Tank",
		Icon = "❄️",
		Crystals = 450,
		Color = Color3.fromRGB(150, 230, 255),
		Weapon = "Shield",
		Stats = { HP = 630, HPPerLevel = 104, Mana = 400, ManaPerLevel = 40, AD = 66, ADPerLevel = 4, Armor = 34, ArmorPerLevel = 5.5, MR = 32, MRPerLevel = 2.05, AttackSpeed = 0.688, ASPerLevel = 0.035, Range = 7, Speed = 340, HPRegen = 1.7, ManaRegen = 1.3 },
		Passive = { Id = "Frostbite", Name = "Frost Armor", Desc = "Your attacks chill enemies, slowing them by 20%. Take 15% less damage if you were not hit for 5 seconds." },
		Abilities = {
			Q = { Name = "Arctic Assault", Icon = "🐗", Type = "Dash", Range = 30, Cost = 70, Cooldown = ranks(16, -1.5), Damage = ranks(90, 50), AP = 0.6, DamageType = "Magic", Radius = 6, Stun = 0.6, StopAtHero = true, Desc = "Charge forward and knock up enemies in your path." },
			W = { Name = "Winter's Wrath", Icon = "❄", Type = "Circle", Radius = 12, Cost = 65, Cooldown = ranks(9, -0.5), Damage = ranks(70, 30), AP = 0.3, MaxHPRatio = 0.04, DamageType = "Magic", Slow = 0.35, SlowTime = 1.5, Desc = "Swing twice around you, slowing enemies." },
			E = { Name = "Permafrost", Icon = "🧊", Type = "Target", Range = 18, Cost = 55, Cooldown = ranks(14, -1), Damage = ranks(55, 50), AP = 0.6, DamageType = "Magic", Stun = 1.2, Desc = "Freeze an enemy solid, stunning them." },
			R = { Name = "Glacial Prison", Icon = "🏔", Type = "Line", Length = 70, Width = 5, Speed = 100, MaxHits = 1, HeroOnly = true, Cost = 100, Cooldown = { 120, 100, 80 }, Damage = { 150, 250, 350 }, AP = 0.4, DamageType = "Magic", Stun = 1.5, Explode = 14, ExplodeStun = 1, Desc = "Throw an ice bola. The first champion hit is stunned and the ice shatters around them." },
		},
		Build = { Start = { "HuntersMachete", "RedTonic" }, Items = { "WardenTreads", "EmberAegis", "SpiritWard", "BramblePlate", "GiantHeart", "MoonChalice" } },
	},
	{
		Id = "Thorne",
		Name = "Thorne",
		Title = "The Starchild",
		Roles = { "Support" },
		Class = "Support",
		Icon = "🌿",
		Crystals = 550,
		Color = Color3.fromRGB(110, 210, 110),
		Weapon = "LeafStaff",
		Stats = { HP = 600, HPPerLevel = 88, Mana = 425, ManaPerLevel = 40, AD = 50, ADPerLevel = 3, Armor = 28, ArmorPerLevel = 4.7, MR = 30, MRPerLevel = 1.3, AttackSpeed = 0.625, ASPerLevel = 0.0214, Range = 25, Speed = 325, HPRegen = 0.5, ManaRegen = 2 },
		Passive = { Id = "Salvation", Name = "Salvation", Desc = "You move much faster toward allies with low health." },
		Abilities = {
			Q = { Name = "Starcall", Icon = "🌠", Type = "Point", Range = 40, Radius = 9, Delay = 0.6, Cost = 60, Cooldown = ranks(6, -0.5), Damage = ranks(85, 35), AP = 0.35, DamageType = "Magic", Slow = 0.3, SlowTime = 2, HealSelfOnHit = ranks(50, 15), Desc = "Call a star. Hitting an enemy heals you over time." },
			W = { Name = "Astral Infusion", Icon = "💚", Type = "HealAlly", Range = 26, Cost = 40, Cooldown = ranks(5, -0.5), Heal = ranks(80, 35), AP = 0.3, SelfCostHP = 0.08, Desc = "Heal the weakest ally near you, at a small cost of your own health." },
			E = { Name = "Equinox", Icon = "🌗", Type = "Zone", Range = 36, Radius = 10, Duration = 1.5, Tick = 1.5, FinalRoot = 1.5, Cost = 70, Cooldown = ranks(20, -2), Damage = ranks(70, 25), AP = 0.4, DamageType = "Magic", Desc = "Create a zone that roots enemies still inside when it ends." },
			R = { Name = "Wish", Icon = "🌟", Type = "Heal", Global = true, Cost = 100, Cooldown = { 140, 120, 100 }, Heal = { 150, 250, 350 }, AP = 0.55, Desc = "Heal every allied champion, anywhere on the map." },
		},
		Build = { Start = { "ApprenticeRing", "RedTonic" }, Items = { "LucidBoots", "MoonChalice", "SpiritWard", "EchoStaff", "HourglassOfStasis", "ArchmageCrown" } },
	},
	{
		Id = "Zephyr",
		Name = "Zephyr",
		Title = "The Prodigal Archer",
		Roles = { "Bot", "Mid" },
		Class = "Marksman",
		Icon = "🏹",
		Crystals = 650,
		Color = Color3.fromRGB(255, 200, 80),
		Weapon = "Bow",
		Stats = { HP = 600, HPPerLevel = 102, Mana = 375, ManaPerLevel = 70, AD = 60, ADPerLevel = 2.5, Armor = 24, ArmorPerLevel = 4.2, MR = 30, MRPerLevel = 1.3, AttackSpeed = 0.625, ASPerLevel = 0.025, Range = 25, Speed = 325, HPRegen = 0.75, ManaRegen = 1.6 },
		Passive = { Id = "RisingSpell", Name = "Rising Spell Force", Desc = "Hitting abilities grants stacking attack speed (up to 5 stacks)." },
		Abilities = {
			Q = { Name = "Mystic Shot", Icon = "🏹", Type = "Line", Length = 52, Width = 3, Speed = 150, MaxHits = 1, Cost = 30, Cooldown = ranks(5.5, -0.25), Damage = ranks(20, 25), AD = 1.3, AP = 0.15, DamageType = "Physical", OnHit = true, Refund = 1.5, Desc = "A bolt that applies on-hit effects and lowers all your cooldowns." },
			W = { Name = "Essence Flux", Icon = "🔮", Type = "Line", Length = 52, Width = 4, Speed = 120, MaxHits = 1, HeroOnly = true, Cost = 50, Cooldown = 8, Damage = ranks(80, 55), BonusAD = 0.6, AP = 0.7, DamageType = "Magic", Mark = 4, Desc = "Mark a champion. Hit them again to detonate the mark." },
			E = { Name = "Arcane Shift", Icon = "💫", Type = "Blink", Range = 22, Cost = 90, Cooldown = ranks(24, -2), Damage = ranks(80, 50), BonusAD = 0.5, AP = 0.75, DamageType = "Magic", BoltRange = 36, Desc = "Teleport a short distance and fire a homing bolt." },
			R = { Name = "Trueshot Barrage", Icon = "☄️", Type = "Line", Length = 360, Width = 10, Speed = 140, Delay = 1, Cost = 100, Cooldown = { 90, 75, 60 }, Damage = { 350, 500, 650 }, BonusAD = 1.0, AP = 0.9, DamageType = "Magic", MinionFactor = 0.5, Desc = "A giant energy wave across the whole map." },
		},
		Build = { Start = { "SquireBlade", "RedTonic" }, Items = { "LucidBoots", "TriforceBlade", "RiftCleaver", "EndlessEdge", "BloodReaver", "Guardian" } },
	},
	{
		Id = "Volt",
		Name = "Volt",
		Title = "The Storm Blade",
		Roles = { "Jungle", "Top" },
		Class = "Fighter",
		Icon = "⚡",
		Crystals = 800,
		Color = Color3.fromRGB(255, 230, 80),
		Weapon = "Spear",
		Stats = { HP = 670, HPPerLevel = 100, Mana = 250, ManaPerLevel = 42, AD = 65, ADPerLevel = 2.2, Armor = 33, ArmorPerLevel = 4.2, MR = 32, MRPerLevel = 2.05, AttackSpeed = 0.679, ASPerLevel = 0.02, Range = 7, Speed = 355, HPRegen = 1.5, ManaRegen = 1.4 },
		Passive = { Id = "DoubleStrike", Name = "Double Strike", Desc = "Every 4th attack strikes twice." },
		Abilities = {
			Q = { Name = "Lightning Rush", Icon = "⚡", Type = "Rush", Range = 22, Hits = 4, Bounce = 14, Cost = 50, Cooldown = ranks(18, -1), Damage = ranks(30, 30), AD = 0.9, DamageType = "Physical", MonsterBonus = ranks(75, 25), Desc = "Become untargetable and strike up to 4 enemies." },
			W = { Name = "Recharge", Icon = "🔋", Type = "Channel", Duration = 2, Cost = 50, Cooldown = 25, Heal = ranks(30, 20), AP = 0.3, Reduction = ranks(0.45, 0.025), MissingHeal = 0.03, Desc = "Channel: heal every second and take much less damage." },
			E = { Name = "Storm Edge", Icon = "🌩", Type = "Buff", Cost = 0, Cooldown = ranks(14, -1), TrueOnHit = ranks(30, 5), BonusADOnHit = 0.3, Duration = 5, Desc = "Your attacks deal bonus true damage." },
			R = { Name = "Overdrive", Icon = "🌀", Type = "Buff", Cost = 100, Cooldown = 85, AttackSpeed = { 0.25, 0.35, 0.45 }, Speed = { 0.25, 0.35, 0.45 }, Duration = 7, SlowImmune = true, ResetOnKill = true, Desc = "Huge attack and move speed. Takedowns extend it." },
		},
		Build = { Start = { "HuntersMachete", "RedTonic" }, Items = { "SwiftGreaves", "BloodReaver", "TriforceBlade", "StormBow", "Guardian", "EndlessEdge" } },
	},
	{
		Id = "Varg",
		Name = "Varg",
		Title = "The Iron Wolf",
		Roles = { "Top" },
		Class = "Fighter",
		Icon = "🪓",
		Crystals = 650,
		Color = Color3.fromRGB(200, 60, 60),
		Weapon = "Axe",
		Stats = { HP = 650, HPPerLevel = 114, Mana = 263, ManaPerLevel = 58, AD = 64, ADPerLevel = 5, Armor = 39, ArmorPerLevel = 5.2, MR = 32, MRPerLevel = 2.05, AttackSpeed = 0.625, ASPerLevel = 0.01, Range = 8, Speed = 340, HPRegen = 2, ManaRegen = 1.3 },
		Passive = { Id = "Bleed", Name = "Hemorrhage", Desc = "Attacks and abilities make enemies bleed (stacks up to 5). At 5 stacks on a champion you gain a lot of AD." },
		Abilities = {
			Q = { Name = "Decimate", Icon = "🌀", Type = "Circle", Radius = 13, Delay = 0.6, Cost = 30, Cooldown = ranks(9, -1), Damage = ranks(50, 30), AD = 1.0, DamageType = "Physical", HealPerHero = 0.13, Bleed = true, Desc = "Swing your axe in a circle. Heal for each champion hit by the blade." },
			W = { Name = "Crippling Strike", Icon = "🦵", Type = "Empower", Cost = 30, Cooldown = ranks(7, -0.5), Damage = ranks(10, 10), AD = 0.4, DamageType = "Physical", Attacks = 1, Slow = 0.9, SlowTime = 1, Duration = 4, Desc = "Your next attack deals bonus damage and cripples." },
			E = { Name = "Apprehend", Icon = "🪝", Type = "Cone", Range = 18, Angle = 50, Cost = 45, Cooldown = ranks(24, -2), Damage = { 0, 0, 0, 0, 0 }, Pull = true, Slow = 0.4, SlowTime = 1, Desc = "Pull every enemy in front of you toward you." },
			R = { Name = "Iron Verdict", Icon = "⚖️", Type = "Target", Range = 14, Leap = true, Cost = 100, Cooldown = { 100, 80, 60 }, Damage = { 125, 250, 375 }, BonusAD = 0.75, DamageType = "True", HeroOnly = true, PerBleed = 0.2, ResetOnKill = true, Desc = "Leap and execute: true damage, +20% per bleed stack. Resets on kill." },
		},
		Build = { Start = { "SquireBlade", "RedTonic" }, Items = { "IronTreads", "RiftCleaver", "TriforceBlade", "SpiritWard", "BramblePlate", "GiantHeart" } },
	},
	{
		Id = "Gaff",
		Name = "Gaff",
		Title = "The Lantern Warden",
		Roles = { "Support" },
		Class = "Support",
		Icon = "🏮",
		Crystals = 650,
		Color = Color3.fromRGB(60, 200, 160),
		Weapon = "Lantern",
		Stats = { HP = 560, HPPerLevel = 115, Mana = 274, ManaPerLevel = 44, AD = 56, ADPerLevel = 2.2, Armor = 28, ArmorPerLevel = 0, MR = 30, MRPerLevel = 1.55, AttackSpeed = 0.625, ASPerLevel = 0.035, Range = 22, Speed = 330, HPRegen = 1, ManaRegen = 1.2 },
		Passive = { Id = "Souls", Name = "Damnation", Desc = "Enemies dying near you leave souls. Each soul gives permanent armor and ability power." },
		Abilities = {
			Q = { Name = "Death Hook", Icon = "⛓", Type = "Line", Length = 52, Width = 3.5, Speed = 95, MaxHits = 1, Delay = 0.35, Cost = 60, Cooldown = ranks(18, -1.5), Damage = ranks(100, 45), AP = 0.5, DamageType = "Magic", Hook = true, Stun = 0.6, Desc = "Throw a hook. The first enemy hit is pulled to you." },
			W = { Name = "Dark Passage", Icon = "🏮", Type = "Shield", Radius = 30, Cost = 50, Cooldown = ranks(20, -1.5), Shield = ranks(60, 25), AP = 0.4, Duration = 4, PullAlly = true, Desc = "Shield yourself and the nearest ally and pull them to you." },
			E = { Name = "Flay", Icon = "🌪", Type = "Circle", Radius = 12, Cost = 60, Cooldown = ranks(12, -0.5), Damage = ranks(75, 35), AP = 0.4, DamageType = "Magic", Knockback = 9, Slow = 0.3, SlowTime = 1, Desc = "Sweep your chain, knocking enemies away." },
			R = { Name = "The Cage", Icon = "🔒", Type = "Zone", Self = true, Radius = 14, Duration = 4, Tick = 0.5, Cost = 100, Cooldown = { 120, 100, 80 }, Damage = { 200, 300, 400 }, AP = 0.6, DamageType = "Magic", Slow = 0.9, SlowTime = 0.6, Desc = "Raise spectral walls: enemies inside take damage and are slowed to a crawl." },
		},
		Build = { Start = { "GuardBuckler", "RedTonic" }, Items = { "WardenTreads", "MoonChalice", "SpiritWard", "BramblePlate", "EmberAegis", "GiantHeart" } },
	},
}
Config.HeroesById = {}
for index, hero in Config.Heroes do
	hero.Order = index
	hero.Abilities.Q.Key = "Q"
	hero.Abilities.W.Key = "W"
	hero.Abilities.E.Key = "E"
	hero.Abilities.R.Key = "R"
	Config.HeroesById[hero.Id] = hero
end

-- Wert einer Faehigkeit fuer einen Rang (Liste oder Zahl)
function Config.AtRank(value: any, rank: number): number
	if typeof(value) == "table" then
		return value[math.clamp(rank, 1, #value)] or 0
	end
	return tonumber(value) or 0
end

---------------------------------------------------------------- Beschwoererzauber

Config.Spells = {
	{ Id = "Flash", Name = "Flash", Icon = "✴️", Cooldown = 210, Range = 18, Desc = "Teleport a short distance." },
	{ Id = "Heal", Name = "Heal", Icon = "💖", Cooldown = 170, Desc = "Heal you and the weakest ally nearby and gain move speed." },
	{ Id = "Ignite", Name = "Ignite", Icon = "🔥", Cooldown = 130, Range = 26, Desc = "Burn an enemy champion for true damage and cut their healing." },
	{ Id = "Smite", Name = "Smite", Icon = "⚔️", Cooldown = 60, Charges = 2, Range = 18, Desc = "Deal big true damage to a monster or minion. Junglers need it." },
	{ Id = "Exhaust", Name = "Exhaust", Icon = "💨", Cooldown = 150, Range = 24, Desc = "Slow an enemy and cut their damage by 40%." },
	{ Id = "Barrier", Name = "Barrier", Icon = "🛡", Cooldown = 130, Desc = "Gain a big shield for 2 seconds." },
	{ Id = "Ghost", Name = "Ghost", Icon = "👻", Cooldown = 150, Desc = "Move much faster for 8 seconds." },
	{ Id = "Teleport", Name = "Teleport", Icon = "🌀", Cooldown = 240, Channel = 4, Desc = "After 4 seconds, teleport to the allied tower or minion closest to where you aim." },
}
Config.SpellsById = {}
for index, spell in Config.Spells do
	spell.Order = index
	Config.SpellsById[spell.Id] = spell
end
Config.DefaultSpells = { Top = "Teleport", Jungle = "Smite", Mid = "Ignite", Bot = "Heal", Support = "Exhaust" }
Config.SmiteDamage = function(level: number): number
	return 450 + level * 20
end

-- Schutz-Totem (Ward): jeder Held hat 2 Ladungen, die sich wieder aufladen
Config.Ward = { Charges = 2, Recharge = 90, Duration = 75, Vision = 30, Range = 24 }
Config.Vision = { Hero = 44, Minion = 30, Tower = 46, Structure = 34, Ward = 30, Fountain = 60, BrushReveal = 6 }

---------------------------------------------------------------- Items
-- From = Bauteile; Cost = Gesamtpreis. Beim Kauf werden vorhandene Bauteile verrechnet.

Config.MaxItems = 6
Config.SellRefund = 0.7
Config.Items = {
	-- Start
	{ Id = "SquireBlade", Name = "Squire's Blade", Icon = "🗡️", Tier = "Starter", Cost = 450, Stats = { AD = 8, HP = 80, Lifesteal = 0.03 } },
	{ Id = "ApprenticeRing", Name = "Apprentice Ring", Icon = "💍", Tier = "Starter", Cost = 400, Stats = { AP = 18, HP = 90, ManaRegen = 1.2 } },
	{ Id = "GuardBuckler", Name = "Guard's Buckler", Icon = "🛡️", Tier = "Starter", Cost = 450, Stats = { HP = 110, HPRegen = 3 } },
	{ Id = "HuntersMachete", Name = "Hunter's Machete", Icon = "🔪", Tier = "Starter", Cost = 450, Stats = { AD = 6, Lifesteal = 0.06 }, Unique = "Machete", Desc = "+40% damage to monsters, heal when hitting them." },
	{ Id = "RedTonic", Name = "Red Tonic", Icon = "🧪", Tier = "Starter", Cost = 50, Potion = true, Desc = "Consume: heal 150 HP over 12 seconds. Max 5." },
	-- Bauteile
	{ Id = "Shortsword", Name = "Iron Shortsword", Icon = "🗡", Tier = "Basic", Cost = 350, Stats = { AD = 10 } },
	{ Id = "EmberTome", Name = "Ember Tome", Icon = "📕", Tier = "Basic", Cost = 435, Stats = { AP = 20 } },
	{ Id = "PaddedVest", Name = "Padded Vest", Icon = "🦺", Tier = "Basic", Cost = 300, Stats = { Armor = 15 } },
	{ Id = "RuneCloak", Name = "Rune Cloak", Icon = "🧥", Tier = "Basic", Cost = 450, Stats = { MR = 25 } },
	{ Id = "Bloodstone", Name = "Bloodstone", Icon = "❤️", Tier = "Basic", Cost = 400, Stats = { HP = 150 } },
	{ Id = "AzureShard", Name = "Azure Shard", Icon = "💠", Tier = "Basic", Cost = 350, Stats = { Mana = 250 } },
	{ Id = "QuickKnife", Name = "Quick Knife", Icon = "🔪", Tier = "Basic", Cost = 300, Stats = { AS = 0.12 } },
	{ Id = "Boots", Name = "Traveler's Boots", Icon = "👞", Tier = "Boots", Cost = 300, Boots = 1, Stats = { MS = 25 } },
	-- Epische Items
	{ Id = "MinerPick", Name = "Miner's Pick", Icon = "⛏️", Tier = "Epic", Cost = 875, From = { "Shortsword" }, Stats = { AD = 25 } },
	{ Id = "GreatBlade", Name = "Great Blade", Icon = "⚔️", Tier = "Epic", Cost = 1300, Stats = { AD = 40 } },
	{ Id = "HeavyRod", Name = "Heavy Rod", Icon = "🪄", Tier = "Epic", Cost = 1250, Stats = { AP = 60 } },
	{ Id = "BlastWand", Name = "Blast Wand", Icon = "🎇", Tier = "Epic", Cost = 850, Stats = { AP = 40 } },
	{ Id = "HunterBow", Name = "Hunter's Bow", Icon = "🏹", Tier = "Epic", Cost = 1000, From = { "QuickKnife", "QuickKnife" }, Stats = { AS = 0.25 } },
	{ Id = "SwiftCloak", Name = "Swift Cloak", Icon = "🪶", Tier = "Epic", Cost = 600, Stats = { Crit = 0.15 } },
	{ Id = "WarmGem", Name = "Warm Gem", Icon = "🔴", Tier = "Epic", Cost = 800, From = { "Bloodstone" }, Stats = { HP = 200, AH = 10 } },
	{ Id = "ChainVest", Name = "Chain Vest", Icon = "⛓️", Tier = "Epic", Cost = 800, From = { "PaddedVest" }, Stats = { Armor = 40 } },
	{ Id = "SpellwardCloak", Name = "Spellward Cloak", Icon = "🧣", Tier = "Epic", Cost = 900, From = { "RuneCloak" }, Stats = { MR = 50 } },
	{ Id = "TitanBelt", Name = "Titan Belt", Icon = "🎗️", Tier = "Epic", Cost = 900, From = { "Bloodstone" }, Stats = { HP = 350 } },
	{ Id = "Warhammer", Name = "Warhammer", Icon = "🔨", Tier = "Epic", Cost = 1100, From = { "Shortsword", "Shortsword" }, Stats = { AD = 25, AH = 10 } },
	{ Id = "LeechBlade", Name = "Leech Blade", Icon = "🩸", Tier = "Epic", Cost = 900, From = { "Shortsword" }, Stats = { AD = 15, Lifesteal = 0.07 } },
	{ Id = "LostPages", Name = "Lost Pages", Icon = "📜", Tier = "Epic", Cost = 1200, From = { "EmberTome", "AzureShard" }, Stats = { AP = 40, Mana = 300, AH = 10 } },
	{ Id = "SerratedDirk", Name = "Serrated Dirk", Icon = "🔪", Tier = "Epic", Cost = 1100, From = { "Shortsword", "Shortsword" }, Stats = { AD = 30, Lethality = 10 } },
	-- Stiefel Stufe 2
	{ Id = "SwiftGreaves", Name = "Swift Greaves", Icon = "👟", Tier = "Boots", Cost = 1100, Boots = 2, From = { "Boots", "QuickKnife" }, Stats = { MS = 45, AS = 0.35 } },
	{ Id = "SpellTreads", Name = "Spell Treads", Icon = "🥿", Tier = "Boots", Cost = 1100, Boots = 2, From = { "Boots" }, Stats = { MS = 45, MagicPen = 18 } },
	{ Id = "IronTreads", Name = "Iron Treads", Icon = "🥾", Tier = "Boots", Cost = 1100, Boots = 2, From = { "Boots", "PaddedVest" }, Stats = { MS = 45, Armor = 25 }, Unique = "Steelcaps", Desc = "Take 12% less damage from attacks." },
	{ Id = "WardenTreads", Name = "Warden Treads", Icon = "👢", Tier = "Boots", Cost = 1100, Boots = 2, From = { "Boots", "RuneCloak" }, Stats = { MS = 45, MR = 25 } },
	{ Id = "LucidBoots", Name = "Lucid Boots", Icon = "🩰", Tier = "Boots", Cost = 950, Boots = 2, From = { "Boots" }, Stats = { MS = 45, AH = 20 } },
	-- Legendaere Items
	{ Id = "EndlessEdge", Name = "Endless Edge", Icon = "🌟", Tier = "Legendary", Cost = 3400, From = { "GreatBlade", "MinerPick", "SwiftCloak" }, Stats = { AD = 70, Crit = 0.25 }, Unique = "CritDamage", Desc = "Critical strikes deal 40% more damage." },
	{ Id = "StormBow", Name = "Storm Bow", Icon = "🌩️", Tier = "Legendary", Cost = 2800, From = { "HunterBow", "SwiftCloak" }, Stats = { AS = 0.4, Crit = 0.25, MS = 15 }, Unique = "Bolts", Desc = "Every 3rd attack fires extra bolts at 2 nearby enemies." },
	{ Id = "BloodReaver", Name = "Blood Reaver", Icon = "🍷", Tier = "Legendary", Cost = 3400, From = { "GreatBlade", "LeechBlade", "SwiftCloak" }, Stats = { AD = 55, Crit = 0.2, Lifesteal = 0.15 } },
	{ Id = "TriforceBlade", Name = "Triforce Blade", Icon = "🔱", Tier = "Legendary", Cost = 3333, From = { "WarmGem", "HunterBow", "Shortsword" }, Stats = { AD = 36, AS = 0.3, HP = 333, AH = 20 }, Unique = "Spellblade", Desc = "After an ability, your next attack deals +200% base AD." },
	{ Id = "RiftCleaver", Name = "Rift Cleaver", Icon = "🪓", Tier = "Legendary", Cost = 3000, From = { "Warhammer", "WarmGem" }, Stats = { AD = 40, HP = 400, AH = 20 }, Unique = "Shred", Desc = "Physical damage to champions shreds 5% armor (up to 30%)." },
	{ Id = "NightEdge", Name = "Night Edge", Icon = "🌙", Tier = "Legendary", Cost = 3000, From = { "SerratedDirk", "Warhammer" }, Stats = { AD = 60, Lethality = 18, AH = 15 } },
	{ Id = "VoidCutter", Name = "Void Cutter", Icon = "🗡️", Tier = "Legendary", Cost = 3000, From = { "SerratedDirk", "MinerPick" }, Stats = { AD = 55, Lethality = 22 } },
	{ Id = "Guardian", Name = "Guardian Angel", Icon = "👼", Tier = "Legendary", Cost = 3000, From = { "MinerPick", "ChainVest" }, Stats = { AD = 45, Armor = 40 }, Unique = "Revive", Desc = "Once every 5 minutes: revive with 50% health after dying." },
	{ Id = "ArchmageCrown", Name = "Archmage Crown", Icon = "🎩", Tier = "Legendary", Cost = 3600, From = { "HeavyRod", "BlastWand", "EmberTome" }, Stats = { AP = 130 }, Unique = "Archmage", Desc = "Increases your ability power by 35%." },
	{ Id = "EchoStaff", Name = "Echo Staff", Icon = "🔊", Tier = "Legendary", Cost = 3000, From = { "LostPages", "BlastWand" }, Stats = { AP = 90, Mana = 600, AH = 20, MagicPen = 6 }, Unique = "Echo", Desc = "Your first ability hit every 10s deals bonus magic damage around the target." },
	{ Id = "VoidRod", Name = "Void Rod", Icon = "🕳️", Tier = "Legendary", Cost = 3000, From = { "BlastWand", "EmberTome" }, Stats = { AP = 80, MagicPenPct = 0.4 } },
	{ Id = "HourglassOfStasis", Name = "Hourglass of Stasis", Icon = "⌛", Tier = "Legendary", Cost = 3250, From = { "ChainVest", "BlastWand", "EmberTome" }, Stats = { AP = 105, Armor = 50, AH = 15 }, Unique = "Stasis", Desc = "Active (button 2): become invulnerable for 2.5 seconds." },
	{ Id = "MoonChalice", Name = "Moon Chalice", Icon = "🌙", Tier = "Legendary", Cost = 2300, From = { "LostPages", "Bloodstone" }, Stats = { AP = 40, HP = 200, AH = 20, ManaRegen = 2 }, Unique = "HealPower", Desc = "Your heals and shields are 20% stronger." },
	{ Id = "EmberAegis", Name = "Ember Aegis", Icon = "☀️", Tier = "Legendary", Cost = 2700, From = { "ChainVest", "TitanBelt" }, Stats = { HP = 450, Armor = 50 }, Unique = "Burn", Desc = "Burn nearby enemies every second." },
	{ Id = "BramblePlate", Name = "Bramble Plate", Icon = "🌵", Tier = "Legendary", Cost = 2700, From = { "ChainVest", "Bloodstone", "PaddedVest" }, Stats = { HP = 350, Armor = 70 }, Unique = "Thorns", Desc = "Attackers take magic damage back." },
	{ Id = "SpiritWard", Name = "Spirit Ward", Icon = "👻", Tier = "Legendary", Cost = 2900, From = { "SpellwardCloak", "WarmGem" }, Stats = { HP = 450, MR = 60, AH = 10, HPRegen = 4 }, Unique = "HealPower", Desc = "Heals and shields on you are 25% stronger." },
	{ Id = "GiantHeart", Name = "Giant's Heart", Icon = "💗", Tier = "Legendary", Cost = 3000, From = { "TitanBelt", "WarmGem" }, Stats = { HP = 900, AH = 10 }, Unique = "Regen", Desc = "Out of combat, regenerate 3% max health per second." },
}
Config.ItemsById = {}
for index, item in Config.Items do
	item.Order = index
	item.From = item.From or {}
	Config.ItemsById[item.Id] = item
end
Config.ItemTiers = { "Starter", "Basic", "Epic", "Boots", "Legendary" }

-- Preis mit Rezept: vorhandene Bauteile (auch in Unterrezepten) werden verrechnet
function Config.PriceFor(items: { string }, itemId: string): (number, { string }, { string })
	local item = Config.ItemsById[itemId]
	local owned = table.clone(items)
	local used = {}
	local price = item.Cost
	local function consume(id: string)
		for _, component in Config.ItemsById[id].From do
			local index = table.find(owned, component)
			if index then
				table.remove(owned, index)
				table.insert(used, component)
				price -= Config.ItemsById[component].Cost
			else
				consume(component)
			end
		end
	end
	consume(itemId)
	return math.max(0, price), used, owned
end
Config.MaxPotions = 5
Config.Potion = { Heal = 150, Seconds = 12 }
Config.StasisSeconds = 2.5
Config.StasisCooldown = 120

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

Config.Rewards = { Win = 60, Loss = 25, PerKill = 4, PerAssist = 2, MaxKillBonus = 40, FirstWinBonus = 60 }
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
	AllHeroes = { Name = "All Heroes", Kind = "AllHeroes", Price = 449, Description = "Unlock every hero now and every future hero", Order = 3 },
	StarterPack = { Name = "Starter Pack", Kind = "StarterPack", Price = 79, Description = "One time: Volt + Inferno skin + 500 crystals", Order = 0, OneTime = true },
	Hero_Vexa = { Name = "Vexa", Kind = "Hero", Hero = "Vexa", Price = 99, Description = "Unlock Vexa, the Void Stalker" },
	Hero_Tundra = { Name = "Tundra", Kind = "Hero", Hero = "Tundra", Price = 99, Description = "Unlock Tundra, the Winter's Wrath" },
	Hero_Thorne = { Name = "Thorne", Kind = "Hero", Hero = "Thorne", Price = 99, Description = "Unlock Thorne, the Starchild" },
	Hero_Zephyr = { Name = "Zephyr", Kind = "Hero", Hero = "Zephyr", Price = 149, Description = "Unlock Zephyr, the Prodigal Archer" },
	Hero_Volt = { Name = "Volt", Kind = "Hero", Hero = "Volt", Price = 149, Description = "Unlock Volt, the Storm Blade" },
	Hero_Varg = { Name = "Varg", Kind = "Hero", Hero = "Varg", Price = 149, Description = "Unlock Varg, the Iron Wolf" },
	Hero_Gaff = { Name = "Gaff", Kind = "Hero", Hero = "Gaff", Price = 149, Description = "Unlock Gaff, the Lantern Warden" },
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
