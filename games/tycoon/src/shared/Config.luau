-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Magic Garden Tycoon.
-- Produkt-IDs kommen automatisch aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Solange eine ID fehlt, kann man den Kauf in Studio ueber den Shop simulieren.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.DataStoreName = "GardenData_v1"

-- Wirtschaft
Config.StartCoins = 30
Config.StartSeeds = { carrot = 5 }
Config.StartTiles = 8
Config.MaxTiles = 24 -- ohne Pass
Config.BigGardenTiles = 12 -- zusaetzlich mit Pass
Config.BackpackSize = 150
Config.RestockInterval = 300 -- Sekunden: Samenladen fuellt sich alle 5 Minuten neu auf

function Config.TileCost(owned: number): number
	return math.floor(150 * 1.9 ^ (owned - Config.StartTiles))
end

Config.MaxUpgradeLevel = 10
Config.Upgrades = {
	Sprinkler = { Name = "Sprinkler", Description = "+10% growth speed per level", BaseCost = 400, Growth = 4, Order = 1 },
	Fertilizer = { Name = "Fertilizer", Description = "+10% fruit value per level", BaseCost = 800, Growth = 4, Order = 2 },
	Backpack = { Name = "Backpack", Description = "+25 backpack slots per level", BaseCost = 1_000, Growth = 3.5, Order = 3 },
}
Config.BackpackPerLevel = 25 -- Plaetze pro Rucksack-Stufe
Config.SuperBagSlots = 100 -- zusaetzlich mit dem Super-Backpack-Pass

function Config.UpgradeCost(key: string, level: number): number
	local upgrade = Config.Upgrades[key]
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ level)
end

-- Multiplikatoren
Config.RebirthMultiplierPer = 0.5
Config.VipMultiplier = 1.5
Config.DoubleSellMultiplier = 2
Config.PremiumMultiplier = 1.2 -- belohnt Premium-Spieler, erhoeht die Premium Payouts
Config.FriendBonusPer = 0.1 -- +10% pro Freund im Server (max. 4) = Grund, Freunde einzuladen
Config.MaxFriendBonus = 4
Config.FastGrowMultiplier = 2
Config.DefaultWalkSpeed = 18

function Config.RebirthCost(rebirths: number): number
	return math.floor(5_000_000 * 3 ^ rebirths)
end

-- Taegliche Belohnung (Serie 1-7 Tage, danach von vorn)
function Config.DailyReward(streak: number, rebirths: number): number
	return 150 * streak * streak * (1 + rebirths)
end

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200) },
	{ Name = "Uncommon", Color = Color3.fromRGB(85, 220, 110) },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255) },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255) },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), Announce = true },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 90), Announce = true },
}

-- Eigene Pflanzen (keine fremden Assets). Regrow = nil: einmal ernten, danach ist das Feld frei.
-- Chance/Min/Max: Wahrscheinlichkeit, dass der Samen beim Auffuellen im Laden liegt, und wie viele.
Config.Seeds = {
	{ Id = "carrot", Name = "Carrot", Rarity = "Common", Price = 10, Grow = 15, Value = 22, Chance = 1, Min = 10, Max = 25, Color = Color3.fromRGB(255, 140, 30), Shape = "Cone" },
	{ Id = "strawberry", Name = "Strawberry", Rarity = "Common", Price = 50, Grow = 30, Regrow = 20, Value = 12, Chance = 1, Min = 5, Max = 15, Color = Color3.fromRGB(235, 40, 60), Shape = "Ball" },
	{ Id = "blueberry", Name = "Blueberry", Rarity = "Uncommon", Price = 400, Grow = 45, Regrow = 30, Value = 45, Chance = 0.8, Min = 3, Max = 8, Color = Color3.fromRGB(60, 80, 230), Shape = "Ball" },
	{ Id = "tomato", Name = "Tomato", Rarity = "Uncommon", Price = 1_200, Grow = 60, Regrow = 40, Value = 110, Chance = 0.6, Min = 2, Max = 5, Color = Color3.fromRGB(230, 50, 30), Shape = "Ball" },
	{ Id = "corn", Name = "Sun Corn", Rarity = "Rare", Price = 5_000, Grow = 90, Regrow = 60, Value = 380, Chance = 0.4, Min = 1, Max = 4, Color = Color3.fromRGB(255, 220, 50), Shape = "Cylinder" },
	{ Id = "watermelon", Name = "Watermelon", Rarity = "Rare", Price = 15_000, Grow = 120, Value = 24_000, Chance = 0.3, Min = 1, Max = 3, Color = Color3.fromRGB(40, 160, 60), Shape = "Ball" },
	{ Id = "pumpkin", Name = "Glow Pumpkin", Rarity = "Epic", Price = 60_000, Grow = 180, Regrow = 120, Value = 4_500, Chance = 0.2, Min = 1, Max = 2, Color = Color3.fromRGB(255, 120, 0), Shape = "Ball" },
	{ Id = "mango", Name = "Mega Mango", Rarity = "Epic", Price = 200_000, Grow = 240, Regrow = 150, Value = 12_000, Chance = 0.12, Min = 1, Max = 2, Color = Color3.fromRGB(255, 180, 40), Shape = "Ball" },
	{ Id = "dragonfruit", Name = "Dragon Fruit", Rarity = "Legendary", Price = 1_000_000, Grow = 300, Regrow = 180, Value = 60_000, Chance = 0.06, Min = 1, Max = 1, Color = Color3.fromRGB(255, 60, 170), Shape = "Ball" },
	{ Id = "moonmelon", Name = "Moon Melon", Rarity = "Legendary", Price = 4_000_000, Grow = 400, Regrow = 240, Value = 200_000, Chance = 0.03, Min = 1, Max = 1, Color = Color3.fromRGB(170, 200, 255), Shape = "Ball" },
	{ Id = "starfruit", Name = "Starfruit", Rarity = "Mythic", Price = 20_000_000, Grow = 600, Regrow = 300, Value = 900_000, Chance = 0.012, Min = 1, Max = 1, Color = Color3.fromRGB(255, 255, 120), Shape = "Block" },
	{ Id = "lotus", Name = "Crystal Lotus", Rarity = "Mythic", Price = 80_000_000, Grow = 900, Regrow = 400, Value = 3_000_000, Chance = 0.005, Min = 1, Max = 1, Color = Color3.fromRGB(120, 255, 240), Shape = "Block" },
}

-- Mutationen beim Ernten (kostenloser Zufall, nicht kaeuflich). Die hoechste zutreffende zaehlt.
Config.Mutations = {
	{ Name = "Rainbow", Multiplier = 50, Chance = 0.001, Color = Color3.fromRGB(255, 100, 255) },
	{ Name = "Golden", Multiplier = 20, Chance = 0.01, Color = Color3.fromRGB(255, 210, 40) },
	{ Name = "Shocked", Multiplier = 10, Chance = 0.12, Weather = "Thunderstorm", Color = Color3.fromRGB(120, 200, 255) },
	{ Name = "Moonlit", Multiplier = 3, Chance = 0.15, Night = true, Color = Color3.fromRGB(190, 170, 255) },
	{ Name = "Wet", Multiplier = 2, Chance = 0.5, Weather = { "Rain", "Thunderstorm" }, Color = Color3.fromRGB(80, 140, 255) },
}
Config.GoldenHourMultiplier = 10 -- auf die Golden-Chance

-- Wetter: kommt von allein, kann aber auch fuer den ganzen Server gekauft werden
Config.Weather = {
	Rain = { Name = "Rain", Duration = 180, GrowthBonus = 1.5, Chance = 0.55 },
	Thunderstorm = { Name = "Thunderstorm", Duration = 120, GrowthBonus = 1.5, Chance = 0.15 },
}
Config.WeatherInterval = { 480, 780 } -- Sekunden zwischen natuerlichem Wetter

-- Gamepasses: einmal kaufen, fuer immer behalten. Werden als Developer Products verkauft und dauerhaft gespeichert.
Config.GamePasses = {
	VIP = { Name = "VIP", Description = "x1.5 fruit value forever + VIP tag", PriceHint = 249, Order = 1 },
	DoubleSell = { Name = "2x Sell", Description = "Double all fruit value forever", PriceHint = 399, Order = 2 },
	AutoHarvest = { Name = "Auto Harvest", Description = "Ripe plants harvest themselves", PriceHint = 349, Order = 3 },
	FastGrow = { Name = "Fast Grow", Description = "All plants grow 2x faster forever", PriceHint = 299, Order = 4 },
	BigGarden = { Name = "Big Garden", Description = "+12 extra garden tiles", PriceHint = 299, Order = 5 },
	SuperBag = { Name = "Super Backpack", Description = "+100 backpack slots forever", PriceHint = 149, Order = 6 },
	Unicorn = { Name = "Rainbow Unicorn Pet", Description = "Pet: +50% value, +30% growth, +30% mutations", PriceHint = 399, Order = 7 },
}

-- Developer Products: beliebig oft kaufbar. Kein bezahlter Zufall: man sieht immer genau, was man bekommt.
-- Muenzpakete skalieren mit dem Verdienst des Spielers, damit sie nie wertlos werden.
Config.DevProducts = {
	CoinsSmall = { Kind = "Coins", Minutes = 10, MinCoins = 1_000, Name = "Coin Pouch", Description = "10 minutes of earnings", PriceHint = 49, Order = 1 },
	CoinsMedium = { Kind = "Coins", Minutes = 60, MinCoins = 10_000, Name = "Coin Chest", Description = "1 hour of earnings", PriceHint = 199, Order = 2 },
	CoinsLarge = { Kind = "Coins", Minutes = 360, MinCoins = 100_000, Name = "Coin Vault", Description = "6 hours of earnings", PriceHint = 699, Order = 3 },
	GrowAll = { Kind = "GrowAll", Name = "Grow All Now", Description = "Every plant in your garden is ripe instantly", PriceHint = 39, Order = 4 },
	Rain = { Kind = "Weather", Weather = "Rain", Name = "Summon Rain", Description = "Rain for EVERYONE: faster growth + Wet x2", PriceHint = 99, Order = 5 },
	Thunderstorm = { Kind = "Weather", Weather = "Thunderstorm", Name = "Summon Thunderstorm", Description = "Storm for EVERYONE: Shocked fruits x10", PriceHint = 199, Order = 6 },
	GoldenHour = { Kind = "GoldenHour", Seconds = 600, Name = "Golden Hour", Description = "10 min: 10x Golden chance for EVERYONE", PriceHint = 249, Order = 7 },
	SeedDragon = { Kind = "Seed", Seed = "dragonfruit", Amount = 1, Name = "Dragon Fruit Seed", Description = "1 Legendary Dragon Fruit seed", PriceHint = 99, Order = 8 },
	SeedStar = { Kind = "Seed", Seed = "starfruit", Amount = 1, Name = "Starfruit Seed", Description = "1 Mythic Starfruit seed", PriceHint = 299, Order = 9 },
}

-- Tag und Nacht: ein Zyklus dauert 15 Minuten, nachts gibt es Moonlit-Fruechte (x3)
Config.DayLength = 900
Config.NightStart = 720
Config.NightEnd = 870

-- Gaertner-Level: XP beim Ernten, jede Stufe gibt Muenzen und +1% Fruchtwert (max. +100%)
Config.LevelBonusPer = 0.01
Config.MaxLevelBonus = 100
function Config.XpNeeded(level: number): number
	return math.floor(30 * level ^ 1.6)
end
function Config.LevelReward(level: number, rebirths: number): number
	return 100 * level * level * (1 + rebirths)
end

-- Pflanzen-Index: jede entdeckte Pflanze und Mutation gibt dauerhaft +2% Fruchtwert
Config.IndexBonusPer = 0.02

-- Gluecksrad: kostenlos alle 4 Stunden (kein Robux, kein Kauf). Gewichte = sichtbare Chancen.
Config.SpinCooldown = 4 * 3600
Config.BoostMultiplier = 2 -- "2x Sell" aus dem Rad oder aus Codes
Config.WheelRewards = {
	{ Kind = "Coins", Minutes = 5, MinCoins = 500, Weight = 33, Name = "Coin Bag", Color = Color3.fromRGB(255, 220, 80) },
	{ Kind = "Coins", Minutes = 20, MinCoins = 2_000, Weight = 18, Name = "Coin Chest", Color = Color3.fromRGB(255, 180, 40) },
	{ Kind = "Seed", Seed = "tomato", Amount = 3, Weight = 16, Name = "3 Tomato Seeds", Color = Color3.fromRGB(85, 220, 110) },
	{ Kind = "Seed", Seed = "corn", Amount = 2, Weight = 13, Name = "2 Sun Corn Seeds", Color = Color3.fromRGB(70, 150, 255) },
	{ Kind = "Boost", Seconds = 600, Weight = 12, Name = "2x Sell (10 min)", Color = Color3.fromRGB(90, 220, 255) },
	{ Kind = "Seed", Seed = "dragonfruit", Amount = 1, Weight = 6, Name = "Dragon Fruit Seed", Color = Color3.fromRGB(255, 190, 40) },
	{ Kind = "Seed", Seed = "starfruit", Amount = 1, Weight = 2, Name = "Starfruit Seed", Color = Color3.fromRGB(255, 60, 90) },
}

-- Codes: einmal pro Konto einloesbar (Grossschreibung egal)
Config.Codes = {
	GARDEN = { Coins = 500, Text = "+$500" },
	SPROUT = { Seed = "blueberry", Amount = 3, Text = "3 Blueberry seeds" },
	MAGIC = { Seed = "corn", Amount = 1, Text = "1 Sun Corn seed" },
	RAINBOW = { Boost = 600, Text = "2x Sell for 10 minutes" },
}

-- Tagesaufgaben: jeden Tag 3 neue (pro Spieler verschieden), Belohnung waechst mit dem Verdienst
Config.QuestCount = 3
Config.QuestPool = {
	{ Id = "harvest", Stat = "Harvest", Text = "Harvest %d fruits", Targets = { 25, 50, 100 } },
	{ Id = "plant", Stat = "Plant", Text = "Plant %d seeds", Targets = { 10, 20, 40 } },
	{ Id = "sell", Stat = "Sell", Text = "Sell %d fruits", Targets = { 30, 60, 120 } },
	{ Id = "mutation", Stat = "Mutation", Text = "Harvest %d mutated fruits", Targets = { 3, 6, 10 } },
	{ Id = "buy", Stat = "BuySeed", Text = "Buy %d seeds in the shop", Targets = { 5, 10, 20 } },
	{ Id = "rare", Stat = "RareHarvest", Text = "Harvest %d Rare or better fruits", Targets = { 5, 10, 20 } },
}
Config.QuestRewards = { -- je Schwierigkeit: Minuten Verdienst, Mindestbetrag, XP
	{ Minutes = 5, MinCoins = 300, Xp = 25 },
	{ Minutes = 10, MinCoins = 800, Xp = 50 },
	{ Minutes = 20, MinCoins = 2_000, Xp = 100 },
}

-- Erfolge: jeder schaltet einen Titel frei, der ueber dem Namen angezeigt werden kann
Config.Achievements = {
	{ Id = "sprout", Title = "Sprout", Text = "Harvest your first fruit", Stat = "Harvest", Goal = 1 },
	{ Id = "thumb", Title = "Green Thumb", Text = "Harvest 100 fruits", Stat = "Harvest", Goal = 100 },
	{ Id = "master", Title = "Master Gardener", Text = "Harvest 1,000 fruits", Stat = "Harvest", Goal = 1_000 },
	{ Id = "legend", Title = "Harvest Legend", Text = "Harvest 10,000 fruits", Stat = "Harvest", Goal = 10_000 },
	{ Id = "million", Title = "Millionaire", Text = "Earn $1M in total", Stat = "TotalEarned", Goal = 1_000_000 },
	{ Id = "billion", Title = "Billionaire", Text = "Earn $1B in total", Stat = "TotalEarned", Goal = 1_000_000_000 },
	{ Id = "golden", Title = "Golden Touch", Text = "Harvest a Golden fruit", Stat = "Golden", Goal = 1 },
	{ Id = "rainbow", Title = "Rainbow Hunter", Text = "Harvest a Rainbow fruit", Stat = "Rainbow", Goal = 1 },
	{ Id = "moon", Title = "Night Owl", Text = "Harvest a Moonlit fruit", Stat = "Moonlit", Goal = 1 },
	{ Id = "mythic", Title = "Mythic Grower", Text = "Harvest a Mythic plant", Stat = "Mythic", Goal = 1 },
	{ Id = "reborn", Title = "Reborn", Text = "Rebirth once", Stat = "Rebirths", Goal = 1 },
	{ Id = "phoenix", Title = "Phoenix", Text = "Rebirth 5 times", Stat = "Rebirths", Goal = 5 },
	{ Id = "botanist", Title = "Botanist", Text = "Discover every plant in the Index", Stat = "Index", Goal = 12 },
	{ Id = "farmer", Title = "Veteran Farmer", Text = "Reach gardener level 25", Stat = "Level", Goal = 25 },
}

-- Begleiter: mit Muenzen kaufen (bleiben bei Rebirth), einer ist ausgeruestet
Config.Pets = {
	{ Id = "bee", Name = "Busy Bee", Price = 5_000, Growth = 0.1, Text = "+10% growth speed", Color = Color3.fromRGB(255, 210, 40) },
	{ Id = "ladybug", Name = "Lucky Ladybug", Price = 75_000, Value = 0.15, Text = "+15% fruit value", Color = Color3.fromRGB(230, 40, 40) },
	{ Id = "butterfly", Name = "Rainbow Butterfly", Price = 1_500_000, Mutation = 0.3, Text = "+30% mutation chance", Color = Color3.fromRGB(170, 110, 255) },
	{ Id = "snail", Name = "Turbo Snail", Price = 20_000_000, Growth = 0.3, Value = 0.1, Text = "+30% growth, +10% value", Color = Color3.fromRGB(120, 200, 120) },
	{ Id = "dragonfly", Name = "Golden Dragonfly", Price = 400_000_000, Growth = 0.25, Value = 0.4, Text = "+25% growth, +40% value", Color = Color3.fromRGB(255, 190, 40) },
	{ Id = "unicorn", Name = "Rainbow Unicorn", Pass = "Unicorn", Growth = 0.3, Value = 0.5, Mutation = 0.3, Text = "+50% value, +30% growth, +30% mutations", Color = Color3.fromRGB(255, 130, 230) },
}

-- Garten-Designs (nur Optik, fuer alle sichtbar)
Config.Skins = {
	{ Id = "classic", Name = "Classic", Price = 0, Floor = Color3.fromRGB(80, 160, 70), FloorMaterial = Enum.Material.Grass, Fence = Color3.fromRGB(240, 235, 220) },
	{ Id = "sakura", Name = "Sakura", Price = 25_000, Floor = Color3.fromRGB(255, 190, 215), FloorMaterial = Enum.Material.Grass, Fence = Color3.fromRGB(200, 90, 130) },
	{ Id = "desert", Name = "Desert Oasis", Price = 500_000, Floor = Color3.fromRGB(225, 195, 130), FloorMaterial = Enum.Material.Sand, Fence = Color3.fromRGB(160, 110, 60) },
	{ Id = "winter", Name = "Winter Wonder", Price = 10_000_000, Floor = Color3.fromRGB(235, 245, 255), FloorMaterial = Enum.Material.Snow, Fence = Color3.fromRGB(120, 170, 230) },
	{ Id = "candy", Name = "Candy Land", Price = 250_000_000, Floor = Color3.fromRGB(255, 170, 230), FloorMaterial = Enum.Material.SmoothPlastic, Fence = Color3.fromRGB(120, 230, 255) },
	{ Id = "midnight", Name = "Midnight Bloom", Level = 30, Floor = Color3.fromRGB(45, 45, 90), FloorMaterial = Enum.Material.Grass, Fence = Color3.fromRGB(160, 130, 255) },
}

-- Rangliste der besten Gaertner aller Server
Config.LeaderboardStore = "TopEarned_v1"

-- Community-Raenge: nur aktive Spielzeit zaehlt (wer 2 Minuten nichts tut, gilt als AFK).
-- Rechte bauen aufeinander auf: jeder Rang hat auch alle Rechte der Raenge darunter.
Config.OwnerUserIds = { 2979321382 } -- BigBabaAli: alle Rechte, kann bannen und Raenge entziehen
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

-- In Studio Kaeufe ohne ID simulieren, damit alles testbar ist
Config.StudioFakePurchases = true

-- Produkt-IDs eintragen (Schluessel = Name in products.json, z. B. "Pass_VIP" oder "CoinsSmall")
local idsModule = ReplicatedStorage.Shared:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

-- Lookup-Tabellen
Config.SeedsById = {}
for index, seed in Config.Seeds do
	seed.Index = index
	Config.SeedsById[seed.Id] = seed
end

Config.PetsById = {}
for index, pet in Config.Pets do
	pet.Index = index
	Config.PetsById[pet.Id] = pet
end

Config.SkinsById = {}
for index, skin in Config.Skins do
	skin.Index = index
	Config.SkinsById[skin.Id] = skin
end

Config.QuestsById = {}
for _, quest in Config.QuestPool do
	Config.QuestsById[quest.Id] = quest
end

Config.AchievementsById = {}
for index, achievement in Config.Achievements do
	achievement.Index = index
	Config.AchievementsById[achievement.Id] = achievement
end
Config.AchievementsById.botanist.Goal = #Config.Seeds

Config.RaritiesByName = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RaritiesByName[rarity.Name] = rarity
end

return Config
