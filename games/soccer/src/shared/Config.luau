-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Soccer Jam (nach dem CS-1.6-Mod).
-- Produkt-IDs kommen aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Fehlt eine ID, sucht der Server das Produkt ueber den Namen; in Studio lassen sich Kaeufe simulieren.

local Config = {}

Config.GameName = "SOCCER JAM"
Config.DataStoreName = "TurboSoccer_v1"

---------------------------------------------------------------- Stil

Config.Font = Enum.Font.LuckiestGuy
Config.BodyFont = Enum.Font.GothamBold
Config.Colors = {
	Navy = Color3.fromRGB(16, 22, 52),
	NavyLight = Color3.fromRGB(32, 42, 90),
	Lime = Color3.fromRGB(190, 255, 60),
	Orange = Color3.fromRGB(255, 110, 30),
	Cyan = Color3.fromRGB(40, 200, 255),
	White = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(255, 205, 50),
	Red = Color3.fromRGB(255, 80, 80),
}

---------------------------------------------------------------- Spielfeld (X = Laenge, Z = Breite)

-- Gross wie die Original-Map: viel Platz fuer Sprints, Fernschuesse und Kurvenbaelle
Config.FieldLength = 340
Config.FieldWidth = 200
Config.GoalWidth = 40
Config.GoalHeight = 16
Config.GoalDepth = 12
Config.GroundY = 0 -- Oberkante des Rasens
Config.BallSize = 3

-- Teams wie im Original: Rot gegen Blau. Blue verteidigt das Tor bei -X, Red das bei +X.
Config.Teams = {
	Blue = { Name = "Blue", Color = Color3.fromRGB(50, 130, 255), Dark = Color3.fromRGB(20, 60, 170), BrickColor = BrickColor.new("Bright blue"), Side = -1 },
	Red = { Name = "Red", Color = Color3.fromRGB(235, 55, 55), Dark = Color3.fromRGB(150, 25, 25), BrickColor = BrickColor.new("Bright red"), Side = 1 },
}
Config.TeamOrder = { "Red", "Blue" }

-- Aufstellung als Anteil der eigenen Haelfte (x: 0 = Mittellinie, 1 = eigenes Tor; z: -1..1)
Config.Formation = {
	{ x = 0.92, z = 0, Role = "Keeper" },
	{ x = 0.12, z = 0, Role = "Striker" },
	{ x = 0.55, z = -0.4, Role = "Defender" },
	{ x = 0.55, z = 0.4, Role = "Defender" },
	{ x = 0.3, z = -0.75, Role = "Wing" },
	{ x = 0.3, z = 0.75, Role = "Wing" },
	{ x = 0.7, z = 0, Role = "Defender" },
	{ x = 0.15, z = -0.4, Role = "Striker" },
	{ x = 0.15, z = 0.4, Role = "Striker" },
	{ x = 0.45, z = 0, Role = "Wing" },
}

---------------------------------------------------------------- Spielablauf

Config.MatchSeconds = 480
Config.ScoreLimit = 10 -- wer zuerst 10 Tore hat, gewinnt sofort
Config.GoldenGoalSeconds = 90
Config.KickoffSeconds = 3
Config.GoalCelebrationSeconds = 4
Config.ResultsSeconds = 12
Config.MinTeamSize = 4 -- Bots fuellen jedes Team bis hierhin auf
Config.MaxTeamSize = 10

---------------------------------------------------------------- Ball

Config.PickupCooldown = 0.45 -- so lange kann der Schuetze den Ball nicht wieder annehmen
Config.BallFriction = 0.7 -- Bremsung pro Sekunde auf dem Boden
Config.ChargeTime = 1.1 -- Sekunden bis voller Schuss
Config.CurveRate = 1.4 -- Kurvenball: Drehung der Flugbahn in rad/s bei vollem Effet
Config.CurveTime = 1.1
Config.SmackSpeed = 75 -- schnellere gegnerische Schuesse hauen Spieler um (wie im Original, nur ohne Schaden)
Config.SmackStun = 1.6
Config.BallReturnSeconds = 25 -- unberuehrter Ball kommt zur Mitte zurueck
Config.TackleWindow = 0.45
Config.StunTime = 1.2
Config.DashSpeed = 62

-- Maskottchen bewachen ihr Tor: Gegner ohne Ball, die zu lange im Strafraum stehen, werden weggeschleudert
Config.MascotZoneDepth = 34
Config.MascotZoneWidth = 80
Config.MascotPatience = 3

---------------------------------------------------------------- Upgrades (wie im Original mit Match-EXP: Stamina, Strength, Agility, Dexterity, Disarm)

Config.MaxSkill = 5
Config.Skills = {
	{ Id = "Stamina", Name = "Stamina", Description = "More turbo, faster recovery", Color = Color3.fromRGB(120, 255, 140) },
	{ Id = "Strength", Name = "Strength", Description = "Harder, faster kicks", Color = Color3.fromRGB(255, 110, 30) },
	{ Id = "Agility", Name = "Agility", Description = "Run faster", Color = Color3.fromRGB(40, 200, 255) },
	{ Id = "Dexterity", Name = "Dexterity", Description = "Grab the ball from further away, catch hard shots", Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "Disarm", Name = "Disarm", Description = "Steal the ball more often and from further away", Color = Color3.fromRGB(200, 120, 255) },
}

-- EXP-Kosten der naechsten Stufe (0 -> 1 kostet 150, 4 -> 5 kostet 750)
function Config.UpgradeCost(level: number): number
	return 150 * (level + 1)
end
Config.StartEXP = 300
Config.StartEXPPerLevel = 15 -- Account-Level gibt mehr Start-EXP
Config.MaxLevelEXP = 600
Config.VIPStartEXP = 200
Config.EXP = {
	Goal = 300,
	Assist = 150,
	Steal = 100,
	Save = 150,
	Smack = 80,
	Dodge = 40,
}
Config.GoalDistanceBonus = 4 -- EXP je Stud ueber 40 Studs Torentfernung

-- Werte je Skill-Stufe (Stufe 0 bis 6; 6 nur mit Pro Boots)
function Config.MaxStamina(level: number): number
	return 100 + level * 25
end
function Config.StaminaRegen(level: number): number
	return 14 + level * 3
end
Config.StaminaDrain = 24
function Config.KickSpeed(level: number): number
	return 80 + level * 12
end
function Config.WalkSpeed(level: number): number
	return 18 + level * 1.2
end
Config.SprintFactor = 1.5
Config.CarryFactor = 0.92
function Config.PickupRange(level: number): number
	return 4.4 + level * 0.5
end
function Config.CatchSpeed(level: number): number
	return 62 + level * 9 -- schnellere Baelle prallen ab oder hauen um
end
function Config.TackleRange(level: number): number
	return 6 + level * 0.7
end
function Config.TackleCooldown(level: number): number
	return 3 - level * 0.3
end
function Config.TackleChance(disarm: number, dexterity: number): number
	return math.clamp(0.55 + (disarm - dexterity) * 0.08, 0.2, 0.95)
end

---------------------------------------------------------------- Account-Fortschritt (bleibt gespeichert)

function Config.XPForLevel(level: number): number
	return 200 + level * 80
end
Config.Rewards = {
	Goal = { XP = 100, Coins = 25 },
	Assist = { XP = 50, Coins = 15 },
	Steal = { XP = 15, Coins = 3 },
	Save = { XP = 20, Coins = 4 },
	Smack = { XP = 10, Coins = 2 },
	Dodge = { XP = 5, Coins = 1 },
	Win = { XP = 150, Coins = 50 },
	Draw = { XP = 90, Coins = 30 },
	Loss = { XP = 60, Coins = 20 },
}
Config.BuyEXPAmount = 250 -- EXP fuer Coins: 300, 450, 600, ... (pro Match)
Config.BuyEXPBase = 300
Config.BuyEXPStep = 150
Config.DailyCoins = { 100, 150, 200, 300, 400, 500, 750 }
Config.XPBoostMinutes = 30
Config.AdCooldown = 300
Config.StarterPackDelay = 90

---------------------------------------------------------------- Kick-Trails (Ball-Spur nach deinen Schuessen)

Config.Trails = {
	{ Id = "white", Name = "Classic", Colors = { Color3.fromRGB(255, 255, 255) }, Price = 0 },
	{ Id = "lime", Name = "Lime", Colors = { Color3.fromRGB(190, 255, 60), Color3.fromRGB(80, 200, 40) }, Price = 400 },
	{ Id = "ice", Name = "Ice Shot", Colors = { Color3.fromRGB(200, 240, 255), Color3.fromRGB(60, 140, 255) }, Price = 800 },
	{ Id = "fire", Name = "Fireball", Colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 70, 0) }, Price = 1500 },
	{ Id = "toxic", Name = "Toxic", Colors = { Color3.fromRGB(180, 255, 40), Color3.fromRGB(30, 120, 20) }, Price = 2500 },
	{ Id = "royal", Name = "Royal", Colors = { Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 205, 50) }, Price = 4000 },
	{ Id = "shadow", Name = "Shadow", Colors = { Color3.fromRGB(30, 30, 40), Color3.fromRGB(140, 0, 220) }, Price = 6000 },
	{ Id = "turbo", Name = "Starter Flame", Colors = { Color3.fromRGB(255, 110, 30), Color3.fromRGB(190, 255, 60) }, Pass = "StarterPack" },
	{ Id = "gold", Name = "Golden VIP", Colors = { Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 150, 0) }, Pass = "VIP" },
	{ Id = "rainbow", Name = "Rainbow", Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 220, 90), Color3.fromRGB(60, 140, 255), Color3.fromRGB(180, 80, 255) }, Pass = "EffectsPack" },
	{ Id = "galaxy", Name = "Galaxy", Colors = { Color3.fromRGB(30, 10, 90), Color3.fromRGB(200, 100, 255), Color3.fromRGB(255, 255, 255) }, Pass = "EffectsPack" },
	{ Id = "lightning", Name = "Lightning", Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 200, 255), Color3.fromRGB(255, 255, 120) }, Pass = "EffectsPack" },
}
Config.TrailsById = {}
for index, trail in Config.Trails do
	trail.Order = index
	Config.TrailsById[trail.Id] = trail
end

---------------------------------------------------------------- Monetarisierung

-- "Gamepasses" werden als Developer Products verkauft und dauerhaft gespeichert
-- (der API-Schluessel kann keine echten Gamepasses anlegen). ProductName = Name in products.json.
Config.GamePasses = {
	VIP = { ProductName = "VIP", Name = "VIP", Description = "+200 start EXP, x1.5 coins, golden name, VIP tag + Golden trail", PriceHint = 199, Order = 1 },
	DoubleXP = { ProductName = "Double XP", Name = "Double XP", Description = "2x match EXP and 2x account XP", PriceHint = 249, Order = 2 },
	DoubleCoins = { ProductName = "Double Coins", Name = "Double Coins", Description = "Earn twice the coins", PriceHint = 199, Order = 3 },
	ProBoots = { ProductName = "Pro Boots", Name = "Pro Boots", Description = "+1 level on ALL 5 upgrades in every match, even above max", PriceHint = 299, Order = 4 },
	EffectsPack = { ProductName = "Effects Pack", Name = "Effects Pack", Description = "3 animated kick trails: Rainbow, Galaxy, Lightning", PriceHint = 149, Order = 5 },
}

Config.DevProducts = {
	Coins1 = { ProductName = "Coin Pouch", Kind = "Coins", Coins = 600, Name = "600 Coins", PriceHint = 49, Order = 1 },
	Coins2 = { ProductName = "Coin Bag", Kind = "Coins", Coins = 1800, Name = "1,800 Coins", PriceHint = 129, Order = 2 },
	Coins3 = { ProductName = "Coin Chest", Kind = "Coins", Coins = 5500, Name = "5,500 Coins", PriceHint = 349, Order = 3 },
	MatchEXP = { ProductName = "+600 Match EXP", Kind = "MatchEXP", EXP = 600, Name = "+600 EXP", Description = "Upgrade your skills right now (this match)", PriceHint = 39, Order = 4 },
	MaxUpgrades = { ProductName = "Max All Upgrades", Kind = "MaxUpgrades", Name = "MAX ALL", Description = "All 5 upgrades to max level for this match", PriceHint = 149, Order = 5 },
	XPBoost = { ProductName = "XP Boost 30 min", Kind = "XPBoost", Name = "2x XP for 30 min", PriceHint = 39, Order = 6 },
	Fireworks = { ProductName = "Stadium Fireworks", Kind = "Fireworks", Name = "Stadium Fireworks", Description = "Light up the whole stadium", PriceHint = 29, Order = 7 },
	StarterPack = { ProductName = "Starter Pack", Kind = "StarterPack", Coins = 2500, EXP = 1000, Name = "Starter Pack", Description = "One time: 2,500 coins + 1,000 match EXP + Starter trail", PriceHint = 79, Hidden = true },
	AdCoins = { ProductName = "Free Coins (Video Ad)", Kind = "AdCoins", Coins = 150, Name = "Free Coins", PriceHint = 5, Hidden = true },
}

-- In Studio Kaeufe mit ID 0 simulieren, damit alles testbar ist
Config.StudioFakePurchases = true

-- Produkt-IDs eintragen (Schluessel = key in products.json, z. B. "Pass_VIP" oder "Coins1")
local idsModule = script.Parent:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

return Config
