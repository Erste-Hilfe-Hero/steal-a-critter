-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Turbo Soccer.
-- Produkt-IDs kommen aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Fehlt eine ID, sucht der Server das Produkt ueber den Namen; in Studio lassen sich Kaeufe simulieren.

local Config = {}

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

Config.FieldLength = 220
Config.FieldWidth = 130
Config.GoalWidth = 30
Config.GoalHeight = 12
Config.GoalDepth = 9
Config.GroundY = 0 -- Oberkante des Rasens
Config.BallSize = 2.8

-- Teams: Bolt verteidigt das Tor bei -X und greift +X an, Blaze umgekehrt
Config.Teams = {
	Bolt = { Name = "Bolt", Color = Color3.fromRGB(40, 200, 255), Dark = Color3.fromRGB(20, 90, 200), BrickColor = BrickColor.new("Cyan"), Side = -1 },
	Blaze = { Name = "Blaze", Color = Color3.fromRGB(255, 110, 30), Dark = Color3.fromRGB(200, 50, 20), BrickColor = BrickColor.new("Deep orange"), Side = 1 },
}
Config.TeamOrder = { "Bolt", "Blaze" }

-- Aufstellung als Anteil der eigenen Haelfte (x: 0 = Mittellinie, 1 = eigenes Tor; z: -1..1)
Config.Formation = {
	{ x = 0.9, z = 0, Role = "Keeper" },
	{ x = 0.15, z = 0, Role = "Striker" },
	{ x = 0.5, z = -0.45, Role = "Defender" },
	{ x = 0.5, z = 0.45, Role = "Defender" },
	{ x = 0.3, z = -0.75, Role = "Wing" },
	{ x = 0.3, z = 0.75, Role = "Wing" },
	{ x = 0.65, z = 0, Role = "Defender" },
	{ x = 0.1, z = -0.4, Role = "Striker" },
}

---------------------------------------------------------------- Spielablauf

Config.MatchSeconds = 240
Config.GoldenGoalSeconds = 60
Config.KickoffSeconds = 3
Config.GoalCelebrationSeconds = 4
Config.ResultsSeconds = 10
Config.MinTeamSize = 3 -- Bots fuellen jedes Team bis hierhin auf
Config.MaxTeamSize = 8

---------------------------------------------------------------- Ball

Config.PickupCooldown = 0.45 -- so lange kann der Schuetze den Ball nicht wieder annehmen
Config.BallFriction = 0.9 -- Bremsung pro Sekunde auf dem Boden
Config.ChargeTime = 1.1 -- Sekunden bis voller Schuss
Config.TackleWindow = 0.45
Config.StunTime = 1.2
Config.DashSpeed = 58

---------------------------------------------------------------- Skills (wie Soccer Jam: Stamina, Strength, Agility, Dexterity, Tackle)

Config.MaxSkill = 10
Config.Skills = {
	{ Id = "Stamina", Name = "Stamina", Description = "Sprint longer and recover faster", Color = Color3.fromRGB(120, 255, 140) },
	{ Id = "Strength", Name = "Strength", Description = "Harder, faster shots", Color = Color3.fromRGB(255, 110, 30) },
	{ Id = "Agility", Name = "Agility", Description = "Run faster", Color = Color3.fromRGB(40, 200, 255) },
	{ Id = "Dexterity", Name = "Dexterity", Description = "Grab the ball from further away and catch fast shots", Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "Tackle", Name = "Tackle", Description = "Longer, more successful tackles", Color = Color3.fromRGB(200, 120, 255) },
}

-- Werte je Skill-Stufe (Stufe 0 bis 11; 11 nur mit Pro Boots)
function Config.MaxStamina(level: number): number
	return 100 + level * 12
end
function Config.StaminaRegen(level: number): number
	return 14 + level * 1.5
end
Config.StaminaDrain = 24
function Config.KickSpeed(level: number): number
	return 72 + level * 5
end
function Config.WalkSpeed(level: number): number
	return 17 + level * 0.55
end
Config.SprintFactor = 1.45
Config.CarryFactor = 0.92
function Config.PickupRange(level: number): number
	return 4.2 + level * 0.25
end
function Config.CatchSpeed(level: number): number
	return 62 + level * 4 -- schnellere Baelle prallen ab
end
function Config.TackleRange(level: number): number
	return 6 + level * 0.35
end
function Config.TackleCooldown(level: number): number
	return 3 - level * 0.15
end
function Config.TackleChance(tackle: number, dexterity: number): number
	return math.clamp(0.6 + (tackle - dexterity) * 0.05, 0.2, 0.95)
end

---------------------------------------------------------------- Fortschritt

function Config.XPForLevel(level: number): number
	return 200 + level * 80
end
Config.Rewards = {
	Goal = { XP = 100, Coins = 25 },
	Assist = { XP = 50, Coins = 15 },
	Tackle = { XP = 15, Coins = 3 },
	Save = { XP = 20, Coins = 4 },
	Win = { XP = 150, Coins = 50 },
	Draw = { XP = 90, Coins = 30 },
	Loss = { XP = 60, Coins = 20 },
}
Config.BuyPointBase = 750 -- Skillpunkt fuer Coins: 750, 1000, 1250, ...
Config.BuyPointStep = 250
Config.DailyCoins = { 100, 150, 200, 300, 400, 500, 750 }
Config.XPBoostMinutes = 30
Config.AdCooldown = 300
Config.StarterPackDelay = 90

---------------------------------------------------------------- Kick-Trails (Ball-Spur nach deinen Schuessen)

Config.Trails = {
	{ Id = "white", Name = "Classic", Colors = { Color3.fromRGB(255, 255, 255) }, Price = 0 },
	{ Id = "lime", Name = "Turbo Lime", Colors = { Color3.fromRGB(190, 255, 60), Color3.fromRGB(80, 200, 40) }, Price = 400 },
	{ Id = "ice", Name = "Ice Shot", Colors = { Color3.fromRGB(200, 240, 255), Color3.fromRGB(60, 140, 255) }, Price = 800 },
	{ Id = "fire", Name = "Fireball", Colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 70, 0) }, Price = 1500 },
	{ Id = "toxic", Name = "Toxic", Colors = { Color3.fromRGB(180, 255, 40), Color3.fromRGB(30, 120, 20) }, Price = 2500 },
	{ Id = "royal", Name = "Royal", Colors = { Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 205, 50) }, Price = 4000 },
	{ Id = "shadow", Name = "Shadow", Colors = { Color3.fromRGB(30, 30, 40), Color3.fromRGB(140, 0, 220) }, Price = 6000 },
	{ Id = "turbo", Name = "Starter Turbo", Colors = { Color3.fromRGB(255, 110, 30), Color3.fromRGB(190, 255, 60) }, Pass = "StarterPack" },
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
	VIP = { ProductName = "VIP", Name = "VIP", Description = "x1.5 coins, golden name, VIP chat tag + Golden trail", PriceHint = 199, Order = 1 },
	DoubleXP = { ProductName = "Double XP", Name = "Double XP", Description = "Level up twice as fast", PriceHint = 249, Order = 2 },
	DoubleCoins = { ProductName = "Double Coins", Name = "Double Coins", Description = "Earn twice the coins", PriceHint = 199, Order = 3 },
	ProBoots = { ProductName = "Pro Boots", Name = "Pro Boots", Description = "+1 on ALL skills, even above max", PriceHint = 299, Order = 4 },
	EffectsPack = { ProductName = "Effects Pack", Name = "Effects Pack", Description = "3 animated kick trails: Rainbow, Galaxy, Lightning", PriceHint = 149, Order = 5 },
}

Config.DevProducts = {
	Coins1 = { ProductName = "Coin Pouch", Kind = "Coins", Coins = 600, Name = "600 Coins", PriceHint = 49, Order = 1 },
	Coins2 = { ProductName = "Coin Bag", Kind = "Coins", Coins = 1800, Name = "1,800 Coins", PriceHint = 129, Order = 2 },
	Coins3 = { ProductName = "Coin Chest", Kind = "Coins", Coins = 5500, Name = "5,500 Coins", PriceHint = 349, Order = 3 },
	SkillPoints3 = { ProductName = "+3 Skill Points", Kind = "SkillPoints", Points = 3, Name = "+3 Skill Points", PriceHint = 59, Order = 4 },
	SkillReset = { ProductName = "Skill Reset", Kind = "SkillReset", Name = "Skill Reset", Description = "Get all skill points back", PriceHint = 25, Order = 5 },
	XPBoost = { ProductName = "XP Boost 30 min", Kind = "XPBoost", Name = "2x XP for 30 min", PriceHint = 39, Order = 6 },
	Fireworks = { ProductName = "Stadium Fireworks", Kind = "Fireworks", Name = "Stadium Fireworks", Description = "Light up the whole stadium", PriceHint = 29, Order = 7 },
	StarterPack = { ProductName = "Starter Pack", Kind = "StarterPack", Coins = 2500, Points = 5, Name = "Starter Pack", Description = "One time: 2,500 coins + 5 skill points + Turbo trail", PriceHint = 79, Hidden = true },
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
