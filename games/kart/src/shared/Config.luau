-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Fire Blaster Race.
-- Produkt-IDs kommen automatisch aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Solange eine ID fehlt, kann man den Kauf in Studio ueber den Shop simulieren.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.DataStoreName = "FireBlasterData_v1"
Config.WinsBoardName = "FireBlasterWins_v1"
Config.OwnerUserId = 2979321382
Config.StudioFakePurchases = true

-- Rennablauf (Sekunden)
Config.Laps = 3
Config.MaxRacers = 8 -- mit CPU-Fahrern aufgefuellt
Config.IntermissionTime = 22
Config.CountdownTime = 4
Config.MaxRaceTime = 300
Config.FinishGrace = 25 -- so lange duerfen die anderen nach dem Sieger noch ins Ziel
Config.ResultsTime = 9
Config.VoteChoices = 3

-- Belohnungen
Config.PlaceCoins = { 300, 220, 170, 135, 110, 90, 75, 60 }
Config.FinishBonusTop3 = 1 -- Sieg zaehlt nur fuer Platz 1
Config.CoinPickupValue = 6
Config.MaxRaceCoins = 10 -- jede eingesammelte Muenze +1% Hoechstgeschwindigkeit (max. 10)
Config.CoinSpeedBonus = 0.01
Config.VipCoinMultiplier = 1.5
Config.DoubleCoinsMultiplier = 2
Config.PremiumCoinMultiplier = 1.2
Config.FriendBonusPer = 0.1
Config.MaxFriendBonus = 4
Config.CoinPartyMultiplier = 2

-- Fahrphysik (Studs, Sekunden)
Config.HoverHeight = 1.55 -- Abstand Fahrbahn bis Chassis-Mitte (Raeder beruehren die Strasse)
Config.Gravity = 130
Config.BoostMultiplier = 1.38
Config.InfernoMultiplier = 1.3
Config.DriftTiers = { 0.8, 1.7, 2.7 } -- Ladezeit fuer Blau, Orange, Lila
Config.DriftBoostTimes = { 0.6, 1.0, 1.5 }
Config.DriftColors = {
	Color3.fromRGB(70, 170, 255),
	Color3.fromRGB(255, 150, 30),
	Color3.fromRGB(200, 80, 255),
}
Config.RocketStartBoost = 1.4

-- Karts: Speed = Hoechstgeschwindigkeit, Accel = Beschleunigung, Turn = Lenkung (rad/s)
Config.Karts = {
	{ Id = "Ember", Name = "Ember Buggy", Price = 0, Speed = 72, Accel = 34, Turn = 2.15, Style = "Buggy", Color = Color3.fromRGB(255, 120, 40), Accent = Color3.fromRGB(40, 36, 48) },
	{ Id = "Blaze", Name = "Blaze Runner", Price = 2_500, Speed = 75, Accel = 36, Turn = 2.15, Style = "Racer", Color = Color3.fromRGB(230, 50, 50), Accent = Color3.fromRGB(255, 210, 60) },
	{ Id = "Cinder", Name = "Cinder Cruiser", Price = 8_000, Speed = 77, Accel = 38, Turn = 2.2, Style = "Muscle", Color = Color3.fromRGB(70, 70, 85), Accent = Color3.fromRGB(255, 120, 30) },
	{ Id = "Volt", Name = "Volt Viper", Price = 20_000, Speed = 79, Accel = 40, Turn = 2.25, Style = "Racer", Color = Color3.fromRGB(60, 140, 255), Accent = Color3.fromRGB(240, 240, 255) },
	{ Id = "Phoenix", Name = "Phoenix Wing", Price = 50_000, Speed = 81, Accel = 41, Turn = 2.3, Style = "Rocket", Color = Color3.fromRGB(255, 180, 40), Accent = Color3.fromRGB(220, 40, 40) },
	{ Id = "Toxic", Name = "Toxic Thunder", Price = 120_000, Speed = 83, Accel = 42, Turn = 2.3, Style = "Muscle", Color = Color3.fromRGB(120, 230, 60), Accent = Color3.fromRGB(30, 30, 36) },
	{ Id = "Dragon", Name = "Dragon Fang", Price = 300_000, Speed = 85, Accel = 44, Turn = 2.35, Style = "Rocket", Color = Color3.fromRGB(150, 50, 220), Accent = Color3.fromRGB(255, 200, 60) },
	{ Id = "Inferno", Name = "Inferno GT", Price = -1, Pass = "InfernoKart", Speed = 88, Accel = 46, Turn = 2.4, Style = "Racer", Color = Color3.fromRGB(25, 22, 30), Accent = Color3.fromRGB(255, 90, 20) },
}
Config.KartsById = {}
for index, kart in Config.Karts do
	kart.Order = index
	Config.KartsById[kart.Id] = kart
end
Config.MaxKartSpeed = 88

-- Boost-Flammen (rein optisch)
Config.Flames = {
	{ Id = "Orange", Name = "Classic Fire", Price = 0, Colors = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 110, 20) } },
	{ Id = "Blue", Name = "Blue Plasma", Price = 1_500, Colors = { Color3.fromRGB(200, 240, 255), Color3.fromRGB(40, 120, 255) } },
	{ Id = "Green", Name = "Toxic Flame", Price = 5_000, Colors = { Color3.fromRGB(220, 255, 160), Color3.fromRGB(60, 200, 40) } },
	{ Id = "Pink", Name = "Candy Blast", Price = 12_000, Colors = { Color3.fromRGB(255, 220, 240), Color3.fromRGB(255, 60, 170) } },
	{ Id = "Purple", Name = "Void Fire", Price = 30_000, Colors = { Color3.fromRGB(230, 200, 255), Color3.fromRGB(130, 40, 230) } },
	{ Id = "Gold", Name = "Golden Inferno", Price = -1, Pass = "VIP", Colors = { Color3.fromRGB(255, 255, 200), Color3.fromRGB(255, 190, 30) } },
	{ Id = "Rainbow", Name = "Rainbow Rocket", Price = 75_000, Rainbow = true, Colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 160, 255) } },
}
Config.FlamesById = {}
for index, flame in Config.Flames do
	flame.Order = index
	Config.FlamesById[flame.Id] = flame
end

-- Items aus den Item-Boxen
Config.Items = {
	Boost = { Name = "Fire Boost", Glyph = ">>", Color = Color3.fromRGB(255, 140, 30) },
	TripleBoost = { Name = "Triple Fire Boost", Glyph = ">>>", Color = Color3.fromRGB(255, 90, 20), Next = "DoubleBoost" },
	DoubleBoost = { Name = "Double Fire Boost", Glyph = ">>", Color = Color3.fromRGB(255, 110, 25), Next = "Boost" },
	Fireball = { Name = "Fireball", Glyph = "O", Color = Color3.fromRGB(255, 70, 30) },
	Homing = { Name = "Homing Blaster", Glyph = "<o>", Color = Color3.fromRGB(80, 170, 255) },
	Oil = { Name = "Oil Slick", Glyph = "~", Color = Color3.fromRGB(60, 50, 80) },
	Shield = { Name = "Flame Shield", Glyph = "()", Color = Color3.fromRGB(255, 210, 60) },
	Inferno = { Name = "Inferno Mode", Glyph = "*", Color = Color3.fromRGB(255, 50, 120) },
	Thunder = { Name = "Thunder Blast", Glyph = "/", Color = Color3.fromRGB(250, 240, 90) },
}
Config.ItemDurations = { Boost = 1.3, Shield = 10, Inferno = 7, Spin = 1.3 }

-- Item-Chancen nach Platzierung (0 = vorne, 1 = hinten): wer hinten liegt, bekommt staerkere Items
function Config.ItemTable(placeFraction: number): { { any } }
	if placeFraction < 0.2 then
		return { { "Oil", 30 }, { "Fireball", 30 }, { "Shield", 25 }, { "Boost", 15 } }
	elseif placeFraction < 0.55 then
		return { { "Fireball", 25 }, { "Homing", 22 }, { "Boost", 20 }, { "Oil", 13 }, { "Shield", 10 }, { "DoubleBoost", 10 } }
	elseif placeFraction < 0.85 then
		return { { "Homing", 25 }, { "TripleBoost", 25 }, { "Boost", 15 }, { "Inferno", 15 }, { "Fireball", 12 }, { "Thunder", 8 } }
	end
	return { { "TripleBoost", 30 }, { "Inferno", 30 }, { "Homing", 20 }, { "Thunder", 20 } }
end

-- Dauerhafte Vorteile (als Developer Products verkauft und gespeichert, wie in den anderen Spielen)
Config.GamePasses = {
	VIP = { Name = "VIP", Description = "x1.5 coins, gold name + Golden Inferno flames", PriceHint = 299, Order = 1 },
	DoubleCoins = { Name = "2x Coins", Description = "Double coins from every race forever", PriceHint = 399, Order = 2 },
	InfernoKart = { Name = "Inferno GT", Description = "The fastest kart in the game", PriceHint = 499, Order = 3 },
	RocketStart = { Name = "Rocket Start", Description = "Perfect turbo start in every race", PriceHint = 149, Order = 4 },
	DoubleItems = { Name = "Item Pockets", Description = "Carry 2 items at once", PriceHint = 249, Order = 5 },
}

Config.DevProducts = {
	CoinsSmall = { Kind = "Coins", Coins = 2_000, Name = "Coin Stack", Description = "2,000 coins", PriceHint = 49, Order = 1 },
	CoinsMedium = { Kind = "Coins", Coins = 9_000, Name = "Coin Bag", Description = "9,000 coins", PriceHint = 179, Order = 2 },
	CoinsLarge = { Kind = "Coins", Coins = 35_000, Name = "Coin Chest", Description = "35,000 coins", PriceHint = 499, Order = 3 },
	CoinsHuge = { Kind = "Coins", Coins = 120_000, Name = "Coin Vault", Description = "120,000 coins", PriceHint = 1299, Order = 4 },
	SuperItem = { Kind = "SuperItem", Amount = 3, Name = "3 Inferno Items", Description = "3x Inferno Mode to use in any race", PriceHint = 49, Order = 5 },
	CoinParty = { Kind = "CoinParty", Seconds = 600, Name = "Coin Party", Description = "10 min of 2x coins for EVERYONE", PriceHint = 99, Order = 6 },
	ChooseTrack = { Kind = "ChooseTrack", Name = "Pick Next Track", Description = "You choose the next track", PriceHint = 39, Order = 7, Hidden = true },
	StartNow = { Kind = "StartNow", Name = "Start Race Now", Description = "Skip the wait, race starts now", PriceHint = 19, Order = 8, Hidden = true },
	StarterPack = { Kind = "StarterPack", Coins = 6_000, Items = 3, Name = "Starter Pack", Description = "One time: 6,000 coins + 3 Inferno + Blue Plasma", PriceHint = 79, Order = 0, Hidden = true },
	AdCoins = { Kind = "AdCoins", Coins = 400, Name = "Free Coins (Video Ad)", Description = "Reward for watching a video ad", PriceHint = 5, Hidden = true },
}
Config.AdCooldown = 180

local idsModule = ReplicatedStorage.Shared:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

-- Taegliche Belohnung (Serie 1-7 Tage)
function Config.DailyReward(streak: number): number
	return 150 + 100 * streak
end
Config.PlaytimeGift = { Minutes = 10, Coins = 300 }

-- CPU-Fahrer (klar als CPU gekennzeichnet)
Config.BotNames = { "Turbo Tom", "Nitro Nia", "Sparky", "Cinder Cat", "Rocket Rex", "Pyro Pip", "Flash Fae", "Blaze Bo", "Dash Dina", "Volt Vic" }

Config.Tips = {
	"Hold DRIFT while turning to charge a turbo: blue, orange, then PURPLE!",
	"Item boxes give stronger items the further behind you are.",
	"Collect coins on the track: each one makes your kart 1% faster.",
	"Press the gas right as the countdown hits 1 for a Rocket Start!",
	"Flame Shield blocks one hit. Inferno Mode makes you unstoppable!",
	"Vote for your favourite track before every race.",
	"Race with friends: +10% coins for every friend in your server!",
	"Come back every day - your daily reward grows with your streak!",
}

return Config
