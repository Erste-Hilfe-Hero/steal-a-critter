-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Turbo City.
-- Produkt-IDs kommen automatisch aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Solange eine ID fehlt, kann man den Kauf in Studio ueber den Shop simulieren.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.DataStoreName = "TurboCity_v1"
Config.GameName = "Turbo City"

---------------------------------------------------------------- Stil (gilt fuer UI, Ladebildschirm, Schilder)

Config.Colors = {
	Ink = Color3.fromRGB(23, 21, 59), -- Konturen und dunkle Flaechen
	Cream = Color3.fromRGB(255, 248, 231),
	Orange = Color3.fromRGB(255, 122, 26),
	Pink = Color3.fromRGB(255, 61, 127),
	Teal = Color3.fromRGB(25, 211, 197),
	Lemon = Color3.fromRGB(255, 225, 77),
	Police = Color3.fromRGB(60, 130, 255),
	Robber = Color3.fromRGB(255, 70, 70),
	Citizen = Color3.fromRGB(255, 200, 40),
	Green = Color3.fromRGB(80, 220, 120),
}

---------------------------------------------------------------- Karte

Config.Grid = 6 -- 6x6 Bloecke
Config.Block = 160 -- Kantenlaenge eines Blocks
Config.Road = 40 -- Strassenbreite

---------------------------------------------------------------- Wirtschaft

Config.StartCash = 2_500
Config.PaycheckInterval = 60 -- Sekunden
Config.BasePaycheck = 60
Config.PolicePaycheck = 120 -- zusaetzlich im Dienst
Config.FriendBonusPer = 0.1
Config.MaxFriendBonus = 4
Config.VipMultiplier = 1.5
Config.DoubleCashMultiplier = 2
Config.PremiumMultiplier = 1.2 -- belohnt Premium-Spieler, erhoeht die Premium Payouts
Config.PartyMultiplier = 2
Config.OfflineShare = 0.25 -- Haus-Einnahmen offline
Config.OfflineMaxHours = 8

-- Lieferjob
Config.DeliveryBase = 250
Config.DeliveryPerStud = 1.6
Config.DeliveryChainBonus = 0.15 -- pro Lieferung in Folge, max. +150 %
Config.DeliveryMaxChain = 10
Config.DeliveryRadius = 18

-- Rennen (Zeitrennen durch die Stadt)
Config.RaceLimit = 150
Config.RaceCooldown = 45
Config.RaceRadius = 32
Config.RaceReward = function(seconds: number): number
	return math.max(800, math.floor(9_000 - seconds * 55))
end

-- Polizei und Raeuber
Config.MaxWanted = 5
Config.WantedDecay = 75 -- Sekunden pro Stern ohne neue Tat
Config.ArrestRange = 10
Config.BlasterRange = 70
Config.BlasterCooldown = 3
Config.StunTime = 2.5
Config.StallTime = 3
Config.ArrestBountyPerStar = 400
Config.ArrestBagShare = 0.3
Config.JailBase = 15
Config.JailPerStar = 8
Config.BagSize = 6_000
Config.BigBagMultiplier = 2
Config.TeamCooldown = 10

Config.Robberies = {
	Bank = { Name = "Bank", Loot = 1_500, Grabs = 6, Hold = 5, Stars = 2, Cooldown = 240 },
	Gems = { Name = "Gem Store", Loot = 900, Grabs = 5, Hold = 3.5, Stars = 1, Cooldown = 150 },
	Gas = { Name = "Gas 'n' Go", Loot = 350, Grabs = 4, Hold = 2, Stars = 1, Cooldown = 90 },
	Donut = { Name = "Donut Palace", Loot = 500, Grabs = 4, Hold = 2.5, Stars = 1, Cooldown = 110 },
}

-- Autos. Kein Preis = Robux-Auto (Pass). Team = nur fuer dieses Team.
-- Speed in Studs/s, Turn in Grad/s.
Config.Cars = {
	{ Id = "bubble", Name = "Bubble", Price = 0, Speed = 62, Turn = 120, Style = "Hatch", Color = Color3.fromRGB(255, 150, 190), L = 11, W = 6.4, Order = 1 },
	{ Id = "cruiser", Name = "Cruiser", Price = 8_000, Speed = 72, Turn = 110, Style = "Sedan", Color = Color3.fromRGB(90, 170, 255), L = 13, W = 6.6, Order = 2 },
	{ Id = "buggy", Name = "Dune Buggy", Price = 25_000, Speed = 78, Turn = 135, Style = "Buggy", Color = Color3.fromRGB(255, 190, 40), L = 10, W = 6.6, Order = 3 },
	{ Id = "pickup", Name = "Pickup", Price = 60_000, Speed = 80, Turn = 100, Style = "Pickup", Color = Color3.fromRGB(80, 200, 120), L = 15, W = 7, Order = 4 },
	{ Id = "thunder", Name = "Thunder", Price = 150_000, Speed = 92, Turn = 105, Style = "Muscle", Color = Color3.fromRGB(255, 90, 60), L = 14, W = 7, Order = 5 },
	{ Id = "zoomer", Name = "Zoomer GT", Price = 400_000, Speed = 104, Turn = 115, Style = "Sport", Color = Color3.fromRGB(25, 211, 197), L = 14, W = 7, Order = 6 },
	{ Id = "monster", Name = "Monster Truck", Price = 1_200_000, Speed = 90, Turn = 95, Style = "Monster", Color = Color3.fromRGB(150, 90, 255), L = 15, W = 9, Order = 7 },
	{ Id = "hyperion", Name = "Hyperion", Price = 3_500_000, Speed = 122, Turn = 120, Style = "Super", Color = Color3.fromRGB(255, 61, 127), L = 15, W = 7.4, Order = 8 },
	{ Id = "rocket", Name = "Rocket Kart", Pass = "RocketKart", Speed = 135, Turn = 140, Style = "Kart", Color = Color3.fromRGB(255, 225, 77), L = 10, W = 6.4, Order = 9 },
	{ Id = "patrol", Name = "Patrol Cruiser", Price = 0, Team = "Police", Speed = 98, Turn = 112, Style = "Police", Color = Color3.fromRGB(245, 245, 255), L = 14, W = 7, Order = 10 },
	{ Id = "swat", Name = "SWAT Interceptor", Pass = "SWAT", Team = "Police", Speed = 118, Turn = 118, Style = "Swat", Color = Color3.fromRGB(40, 45, 70), L = 15, W = 7.6, Order = 11 },
}

Config.NitroBoost = 1.55
Config.NitroTime = 2.5
Config.NitroCooldown = 7
Config.BoostPadSpeed = 1.6
Config.JumpPadPower = 95

-- Lackfarben (gratis), Gold/Regenbogen mit Pass
Config.Paints = {
	{ Id = "stock", Name = "Stock" },
	{ Id = "white", Name = "Pearl", Color = Color3.fromRGB(245, 245, 250) },
	{ Id = "black", Name = "Midnight", Color = Color3.fromRGB(35, 35, 50) },
	{ Id = "red", Name = "Cherry", Color = Color3.fromRGB(235, 50, 60) },
	{ Id = "orange", Name = "Sunset", Color = Color3.fromRGB(255, 122, 26) },
	{ Id = "lemon", Name = "Lemon", Color = Color3.fromRGB(255, 225, 77) },
	{ Id = "teal", Name = "Lagoon", Color = Color3.fromRGB(25, 211, 197) },
	{ Id = "purple", Name = "Grape", Color = Color3.fromRGB(150, 90, 255) },
	{ Id = "gold", Name = "Gold", Color = Color3.fromRGB(255, 200, 40), Pass = "VIP", Material = Enum.Material.Foil },
	{ Id = "rainbow", Name = "Rainbow", Pass = "Underglow", Rainbow = true },
}

-- Haeuser: jede Stufe bringt Miete pro Minute (auch offline zum Teil)
Config.Houses = {
	{ Name = "Trailer", Price = 0, Rent = 25 },
	{ Name = "Cozy Cottage", Price = 20_000, Rent = 90 },
	{ Name = "Family House", Price = 120_000, Rent = 300 },
	{ Name = "Modern Villa", Price = 600_000, Rent = 900 },
	{ Name = "Beach Mansion", Price = 2_500_000, Rent = 2_600 },
	{ Name = "Mega Mansion", Price = 9_000_000, Rent = 7_000 },
	{ Name = "Diamond Penthouse", Pass = "Diamond", Rent = 12_000 },
}

---------------------------------------------------------------- Belohnungen

function Config.DailyReward(streak: number, houseTier: number): number
	return 500 * streak * streak * houseTier
end

Config.Gifts = { 3, 8, 15, 25, 40, 60 } -- Minuten Spielzeit pro Sitzung
function Config.GiftReward(index: number, houseTier: number): number
	return 400 * index * houseTier
end

Config.Codes = {
	TURBO = 5_000,
	RELEASE = 10_000,
	COPS = 3_000,
	ROBBERS = 3_000,
	BIGBABA = 25_000,
}

-- Taegliche Missionen: 3 pro Tag
Config.Missions = {
	{ Id = "Deliver", Text = "Deliver %d packages", Goal = 5, Reward = 6_000 },
	{ Id = "Arrest", Text = "Arrest %d robbers", Goal = 3, Reward = 8_000 },
	{ Id = "Rob", Text = "Grab loot %d times", Goal = 6, Reward = 7_000 },
	{ Id = "CashIn", Text = "Cash in loot %d times at the hideout", Goal = 2, Reward = 7_000 },
	{ Id = "Race", Text = "Finish %d city races", Goal = 2, Reward = 6_000 },
	{ Id = "Drive", Text = "Drive %d studs", Goal = 15_000, Reward = 5_000 },
	{ Id = "Earn", Text = "Earn $%d", Goal = 25_000, Reward = 6_000 },
}

---------------------------------------------------------------- Fortschritt (Update 2)

-- Karriere-Stufen: XP fuer jede Aktion, Belohnung bei jedem Aufstieg
Config.MaxLevel = 100
function Config.XpForLevel(level: number): number
	return math.floor(40 + 60 * level ^ 1.25)
end
function Config.LevelReward(level: number): number
	return 750 * level
end
Config.Xp = {
	Delivery = 25,
	Arrest = 60,
	Rob = 15,
	CashIn = 40,
	Race = 50,
	Truck = 60,
	Token = 30,
	Mission = 80,
	SpeedCam = 10,
	Spray = 10,
}

-- Erfolge: Stat = Wert, der gezaehlt wird. Title = Titel, der damit frei wird.
Config.Achievements = {
	{ Id = "Deliver10", Name = "Paper Route", Text = "Deliver 10 packages", Stat = "Deliveries", Goal = 10, Reward = 5_000, Title = "Courier" },
	{ Id = "Deliver100", Name = "Turbo Courier", Text = "Deliver 100 packages", Stat = "Deliveries", Goal = 100, Reward = 60_000, Title = "Express King" },
	{ Id = "Arrest5", Name = "Rookie Cop", Text = "Arrest 5 robbers", Stat = "Arrests", Goal = 5, Reward = 8_000, Title = "Rookie Cop" },
	{ Id = "Arrest50", Name = "Top Cop", Text = "Arrest 50 robbers", Stat = "Arrests", Goal = 50, Reward = 90_000, Title = "Sheriff" },
	{ Id = "Rob20", Name = "Sticky Fingers", Text = "Grab loot 20 times", Stat = "Robberies", Goal = 20, Reward = 8_000, Title = "Sneaky" },
	{ Id = "Rob200", Name = "Master Thief", Text = "Grab loot 200 times", Stat = "Robberies", Goal = 200, Reward = 90_000, Title = "Master Thief" },
	{ Id = "Race5", Name = "Street Racer", Text = "Finish 5 city races", Stat = "Races", Goal = 5, Reward = 10_000, Title = "Racer" },
	{ Id = "Truck3", Name = "Truck Cracker", Text = "Crack the armored truck 3 times", Stat = "Trucks", Goal = 3, Reward = 15_000, Title = "Safecracker" },
	{ Id = "Speed150", Name = "Speed Demon", Text = "Hit 150 km/h at a speed cam", Stat = "TopSpeed", Goal = 150, Reward = 12_000, Title = "Speed Demon" },
	{ Id = "Tokens", Name = "Treasure Hunter", Text = "Find all hidden Turbo Tokens", Stat = "Tokens", Goal = 15, Reward = 50_000, Title = "Treasure Hunter" },
	{ Id = "Chores50", Name = "Model Prisoner", Text = "Sweep the jail 50 times", Stat = "Chores", Goal = 50, Reward = 6_000, Title = "Jailbird" },
	{ Id = "Level10", Name = "Going Places", Text = "Reach level 10", Stat = "Level", Goal = 10, Reward = 20_000, Title = "Hotshot" },
	{ Id = "Level25", Name = "City Legend", Text = "Reach level 25", Stat = "Level", Goal = 25, Reward = 100_000, Title = "Legend" },
	{ Id = "House4", Name = "Big Shot", Text = "Move into a Modern Villa", Stat = "House", Goal = 4, Reward = 40_000, Title = "Big Shot" },
	{ Id = "Cars5", Name = "Collector", Text = "Own 5 cars", Stat = "Cars", Goal = 5, Reward = 25_000, Title = "Car Collector" },
	{ Id = "Million", Name = "Millionaire", Text = "Earn $1M in total", Stat = "TotalEarned", Goal = 1_000_000, Reward = 50_000, Title = "Millionaire" },
}

-- Gluecksrad: einmal am Tag gratis, nur Spielgeld (wird mit der Hausstufe groesser)
Config.SpinPrizes = {
	{ Label = "$1K", Cash = 1_000, Weight = 30, Color = Color3.fromRGB(25, 211, 197) },
	{ Label = "$2K", Cash = 2_000, Weight = 25, Color = Color3.fromRGB(255, 225, 77) },
	{ Label = "$3K", Cash = 3_000, Weight = 18, Color = Color3.fromRGB(255, 122, 26) },
	{ Label = "$5K", Cash = 5_000, Weight = 12, Color = Color3.fromRGB(255, 61, 127) },
	{ Label = "250 XP", Xp = 250, Weight = 8, Color = Color3.fromRGB(150, 90, 255) },
	{ Label = "$10K", Cash = 10_000, Weight = 5, Color = Color3.fromRGB(80, 220, 120) },
	{ Label = "$25K", Cash = 25_000, Weight = 2, Color = Color3.fromRGB(255, 200, 40) },
}

-- Tuning: 3 Motor-Stufen pro Auto
Config.TuneMax = 3
Config.TuneSpeed = 0.06 -- +6 % Hoechstgeschwindigkeit pro Stufe
Config.TuneTurn = 0.03
function Config.TuneCost(car, level: number): number
	local base = if car.Price and car.Price > 0 then car.Price else 60_000
	return math.max(4_000, math.floor(base * 0.12 * level / 1000) * 1000)
end

-- Spray-Werkstatt: Fahndungssterne weg (gegen Spielgeld)
Config.SprayCostPerStar = 1_200
Config.SprayCooldown = 90
Config.SprayCopRange = 60

-- Stadt-Events (wechseln automatisch)
Config.EventInterval = 420
Config.EventDuration = 180
Config.CityEvents = {
	{ Id = "CrimeWave", Name = "CRIME WAVE", Text = "Robbers grab 2x loot!", Color = Color3.fromRGB(255, 70, 70) },
	{ Id = "DoubleBounty", Name = "DOUBLE BOUNTY", Text = "Cops earn 2x per arrest!", Color = Color3.fromRGB(60, 130, 255) },
	{ Id = "RushHour", Name = "RUSH HOUR", Text = "Deliveries pay 2x!", Color = Color3.fromRGB(255, 200, 40) },
}

-- Geldtransporter (Event fuer Raeuber)
Config.Truck = { Interval = 300, Duration = 150, Loot = 2_000, Grabs = 3, Hold = 4, Stars = 2 }

-- Versteckte Turbo-Token
Config.TokenReward = 2_500

-- Blitzer: Belohnung beim ersten Erreichen einer Geschwindigkeit (km/h)
Config.KmhPerStud = 1.25
Config.SpeedCamRadius = 22
Config.SpeedRewards = { { Kmh = 100, Cash = 3_000 }, { Kmh = 150, Cash = 8_000 }, { Kmh = 200, Cash = 20_000 } }

-- Gefaengnis-Putzdienst: jeder Wisch verkuerzt die Strafe
Config.ChoreSeconds = 0.5
Config.ChoreMaxShare = 0.5
Config.ChoreInterval = 0.3

-- Tutorial fuer neue Spieler
Config.Tutorial = {
	{ Id = "Spawn", Text = "Tap CAR to spawn your car", Reward = 1_000 },
	{ Id = "Drive", Text = "Drive around the city", Reward = 1_000 },
	{ Id = "Job", Text = "Do a job: deliver, race, rob or arrest", Reward = 2_000 },
	{ Id = "Spin", Text = "Spin the free LUCKY WHEEL", Reward = 2_000 },
}

-- Orte fuer die Minikarte (Block-Koordinaten bx, bz, passend zu MAP in WorldService)
Config.Landmarks = {
	{ Name = "Bank", Icon = "$", Block = { 2, 1 }, Color = Color3.fromRGB(255, 225, 77) },
	{ Name = "Gem Store", Icon = "G", Block = { 4, 1 }, Color = Color3.fromRGB(255, 61, 127) },
	{ Name = "Gas 'n' Go", Icon = "F", Block = { 5, 2 }, Color = Color3.fromRGB(255, 122, 26) },
	{ Name = "Donut Palace", Icon = "O", Block = { 5, 3 }, Color = Color3.fromRGB(255, 140, 200) },
	{ Name = "Police", Icon = "P", Block = { 1, 0 }, Color = Color3.fromRGB(60, 130, 255) },
	{ Name = "Jail", Icon = "J", Block = { 0, 0 }, Color = Color3.fromRGB(170, 170, 185) },
	{ Name = "Hideout", Icon = "H", Block = { 5, 0 }, Color = Color3.fromRGB(255, 70, 70) },
	{ Name = "Turbo Spray", Icon = "S", Block = { 4, 0 }, Color = Color3.fromRGB(25, 211, 197) },
	{ Name = "Turbo Motors", Icon = "C", Block = { 1, 3 }, Color = Color3.fromRGB(25, 211, 197) },
	{ Name = "Delivery", Icon = "D", Block = { 3, 3 }, Color = Color3.fromRGB(255, 200, 40) },
	{ Name = "Plaza", Icon = "★", Block = { 2, 2 }, Color = Color3.fromRGB(255, 248, 231) },
}

-- Einstellungen (pro Spieler gespeichert)
Config.DefaultSettings = { Minimap = true, Gps = true, Fov = true, Mph = false, Feed = true, Sounds = true }

Config.OfferCooldown = 180
Config.AdCooldown = 240

---------------------------------------------------------------- Produkte

-- "Passes": einmal kaufen, fuer immer behalten. Als Developer Products verkauft und dauerhaft gespeichert.
Config.GamePasses = {
	VIP = { Name = "VIP", Description = "x1.5 cash forever, VIP tag and Gold paint", PriceHint = 249, Order = 1 },
	DoubleCash = { Name = "2x Cash", Description = "Double ALL cash forever", PriceHint = 399, Order = 2 },
	Nitro = { Name = "Nitro", Description = "Nitro boost on every car forever", PriceHint = 149, Order = 3 },
	BigBag = { Name = "Big Loot Bag", Description = "Carry 2x loot and grab faster", PriceHint = 199, Order = 4 },
	RocketKart = { Name = "Rocket Kart", Description = "The fastest car in the city", PriceHint = 299, Order = 5 },
	SWAT = { Name = "SWAT Team", Description = "SWAT Interceptor + 50% arrest bounty", PriceHint = 199, Order = 6 },
	Underglow = { Name = "Neon Underglow", Description = "Neon underglow + Rainbow paint", PriceHint = 99, Order = 7 },
	Diamond = { Name = "Diamond Penthouse", Description = "Best house: $12K rent per minute", PriceHint = 499, Order = 8 },
}

-- Developer Products: beliebig oft kaufbar. Kein bezahlter Zufall: man sieht immer genau, was man bekommt.
Config.DevProducts = {
	CashSmall = { Kind = "Cash", Base = 15_000, Name = "Cash Stack", Description = "A stack of cash (grows with your house)", PriceHint = 49, Order = 1 },
	CashMedium = { Kind = "Cash", Base = 80_000, Name = "Cash Briefcase", Description = "A briefcase of cash (grows with your house)", PriceHint = 199, Order = 2 },
	CashLarge = { Kind = "Cash", Base = 400_000, Name = "Cash Truck", Description = "A whole truck of cash (grows with your house)", PriceHint = 699, Order = 3 },
	JailBreak = { Kind = "JailBreak", Name = "Jail Break", Description = "Escape jail right now", PriceHint = 25, Order = 4 },
	ClearWanted = { Kind = "ClearWanted", Name = "Clear Wanted", Description = "Lose all wanted stars", PriceHint = 35, Order = 5 },
	CashParty = { Kind = "Party", Seconds = 600, Name = "Cash Party", Description = "10 min 2x cash for EVERYONE", PriceHint = 199, Order = 6 },
	MoneyRain = { Kind = "Rain", Name = "Money Rain", Description = "Rain cash over the whole city", PriceHint = 99, Order = 7 },
	MissionSkip = { Kind = "MissionSkip", Name = "Mission Skip", Description = "Finish your next daily mission", PriceHint = 29, Order = 8 },
	StarterPack = { Kind = "Starter", Cash = 50_000, Car = "zoomer", Name = "Starter Pack", Description = "One time: $50K + Zoomer GT", PriceHint = 79, Order = 0, OneTime = true },
	MaxTune = { Kind = "MaxTune", Name = "Max Tune", Description = "Max engine tune for your selected car", PriceHint = 49, Order = 9 },
	AdCash = { Kind = "AdCash", Base = 2_000, Name = "Free Cash (Video Ad)", Description = "Reward for watching a video ad", PriceHint = 5, Hidden = true },
}

---------------------------------------------------------------- Community

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

---------------------------------------------------------------- IDs und Lookups

local idsModule = ReplicatedStorage.Shared:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

Config.CarsById = {}
for _, car in Config.Cars do
	Config.CarsById[car.Id] = car
end
Config.PaintsById = {}
for _, paint in Config.Paints do
	Config.PaintsById[paint.Id] = paint
end
Config.AchievementsById = {}
for _, achievement in Config.Achievements do
	Config.AchievementsById[achievement.Id] = achievement
end
Config.EventsById = {}
for _, event in Config.CityEvents do
	Config.EventsById[event.Id] = event
end
Config.MissionsById = {}
for _, mission in Config.Missions do
	Config.MissionsById[mission.Id] = mission
end

-- Mittelpunkt von Block (bx, bz) bzw. Strasse k (0..Grid)
function Config.BlockCenter(bx: number, bz: number): Vector3
	local half = (Config.Grid * Config.Block + (Config.Grid + 1) * Config.Road) / 2
	local step = Config.Block + Config.Road
	return Vector3.new(-half + Config.Road + Config.Block / 2 + bx * step, 0, -half + Config.Road + Config.Block / 2 + bz * step)
end

function Config.RoadLine(k: number): number
	local half = (Config.Grid * Config.Block + (Config.Grid + 1) * Config.Road) / 2
	return -half + Config.Road / 2 + k * (Config.Block + Config.Road)
end

function Config.CityHalf(): number
	return (Config.Grid * Config.Block + (Config.Grid + 1) * Config.Road) / 2
end

-- Rennstrecke ueber Kreuzungen (Strassen-Indizes)
-- Start an Kreuzung RaceStart, dann alle Punkte der Reihe nach (jeweils entlang einer Strasse)
Config.RaceStart = { 4, 6 }
Config.RaceRoute = { { 6, 6 }, { 6, 2 }, { 4, 2 }, { 4, 0 }, { 0, 0 }, { 0, 4 }, { 2, 4 }, { 2, 6 }, { 4, 6 } }

return Config
