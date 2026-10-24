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
Config.BallReturnSeconds = 30 -- unberuehrter Ball kommt zur Mitte zurueck
Config.StunTime = 1.2
Config.DashSpeed = 62

-- Messer wie im Original (Werte aus CS 1.6): Slash schnell, Stab stark, von hinten dreifacher Schaden.
-- Bei 0 Leben ist man K.O. (umgekippt, kein Blut) und kommt nach ein paar Sekunden an der Startposition zurueck.
Config.MaxHP = 100
Config.Knife = {
	Slash = { Damage = 15, Backstab = 45, Range = 10, Windup = 0, Window = 0.4, Cooldown = 0.45 },
	Stab = { Damage = 65, Backstab = 195, Range = 9, Windup = 0.2, Window = 0.35, Cooldown = 1.2 },
}
Config.BackstabDot = 0.45 -- so weit muss das Opfer vom Angreifer wegschauen
Config.HuntDistance = 45 -- wie im Original: Schaden nur, wenn der Angreifer nah am Ball ist (kein "Hunting")
-- Messer-Treffer am Ballfuehrer: Chance, dass er den Ball verliert (Original: 5 % + 6 % je Disarm-Stufe)
function Config.DisarmChance(level: number): number
	return 0.12 + level * 0.08
end
-- Stamina gibt wie im Original mehr Leben
function Config.MaxHPFor(stamina: number): number
	return Config.MaxHP + stamina * 20
end
-- Powerplay: jeder Pass zu einem anderen Mitspieler (bis 5) macht die Schuesse des Teams staerker
Config.MaxPowerPlay = 5
Config.PowerPlayBonus = 0.06 -- +6 % Schussstaerke je Stufe
Config.LongJumpCooldown = 5 -- Sprung beim Seitwaerts-Laufen: doppelt so weit (wie im Original)
Config.KOSeconds = 2
Config.SpawnProtect = 2 -- so lange nach dem Zurueckkommen unverwundbar
function Config.SmackDamage(speed: number): number
	-- Harte Schuesse tun weh wie im Original: 20 bis 60 Schaden je nach Tempo
	return math.clamp(math.floor((speed - Config.SmackSpeed) * 1.2 + 20), 20, 60)
end

-- Maskottchen bewachen ihr Tor: Gegner ohne Ball, die zu lange im Strafraum stehen, werden weggeschleudert
-- Wie im Original: das Alien-Maskottchen zappt jede Sekunde einen Gegner im Kreis vor seinem Tor (8-12 Schaden);
-- wer mit dem Ball in den Kreis laeuft, ist sofort K.O. Tore muessen also von ausserhalb geschossen werden.
-- Eigene Spieler im Kreis (Torwart) heilen sich langsam.
Config.AlienRadius = 40
Config.AlienInterval = 1
Config.AlienDamage = { 8, 12 }
Config.KeeperRegen = 6 -- Leben pro Sekunde im eigenen Kreis

---------------------------------------------------------------- Upgrades (wie im Original mit Match-EXP: Stamina, Strength, Agility, Dexterity, Disarm)

Config.MaxSkill = 5
Config.Skills = {
	{ Id = "Stamina", Name = "Stamina", Description = "+20 max health (after your next knockout or kickoff) and more turbo", Color = Color3.fromRGB(120, 255, 140) },
	{ Id = "Strength", Name = "Strength", Description = "Harder, faster kicks", Color = Color3.fromRGB(255, 110, 30) },
	{ Id = "Agility", Name = "Agility", Description = "Run faster", Color = Color3.fromRGB(40, 200, 255) },
	{ Id = "Dexterity", Name = "Dexterity", Description = "Grab the ball from further away, catch hard shots", Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "Disarm", Name = "Disarm", Description = "Knife hits knock the ball away from the carrier more often", Color = Color3.fromRGB(200, 120, 255) },
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
	KO = 100,
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
	KO = { XP = 20, Coins = 4 },
	Win = { XP = 150, Coins = 50 },
	Draw = { XP = 90, Coins = 30 },
	Loss = { XP = 60, Coins = 20 },
}
Config.BuyEXPAmount = 250 -- EXP fuer Coins: 300, 450, 600, ... (pro Match)
Config.BuyEXPBase = 300
Config.BuyEXPStep = 150
Config.DailyCoins = { 100, 150, 200, 300, 400, 500, 750 }
Config.XPBoostMinutes = 30
Config.GoldenKnifeDamage = 1.35
Config.IronBodyHP = 50
Config.CannonShotPower = 1.2
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
	GoldenKnife = { ProductName = "Golden Knife", Name = "Golden Knife", Description = "+35% knife damage and a glowing golden blade", PriceHint = 349, Order = 6 },
	IronBody = { ProductName = "Iron Body", Name = "Iron Body", Description = "+50 max health in every match", PriceHint = 249, Order = 7 },
	CannonShot = { ProductName = "Cannon Shot", Name = "Cannon Shot", Description = "All your kicks are 20% harder", PriceHint = 249, Order = 8 },
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
