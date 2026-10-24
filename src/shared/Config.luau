-- Zentrale Spiel- und Monetarisierungs-Einstellungen.
-- IDs von Gamepasses/Developer Products nach dem Anlegen im Creator Hub hier eintragen.
-- Solange eine ID 0 ist, kann man den Kauf in Studio ueber den Shop simulieren.

local Config = {}

Config.DataStoreName = "PlayerData_v1"

-- Wirtschaft
Config.StartCash = 100
Config.BaseSlots = 8
Config.ExtraSlotsAmount = 4
Config.IncomeTick = 1 -- Sekunden

-- Laufband
Config.Conveyor = {
	StartX = -120,
	EndX = 120,
	Z = 0,
	Width = 10,
	Speed = 8, -- Studs pro Sekunde
	SpawnInterval = 2.5,
}

-- Klauen und Basis-Sperre
Config.StealHoldTime = 2.5
Config.FastStealHoldTime = 1
Config.StealTimeout = 60
Config.SlapCooldown = 0.8
Config.SlapRange = 8
Config.SlapStunTime = 1.2
Config.LockDuration = 45
Config.LockCooldown = 30

-- Multiplikatoren
Config.RebirthMultiplierPer = 0.5
Config.VipMultiplier = 1.5
Config.DoubleCashMultiplier = 2
Config.PremiumMultiplier = 1.2 -- belohnt Premium-Spieler, erhoeht die Premium Payouts
Config.ServerLuckMultiplier = 3 -- auf Gewichte ab "Rare"
Config.DefaultWalkSpeed = 16
Config.SpeedCoilWalkSpeed = 26

function Config.RebirthCost(rebirths: number): number
	return math.floor(1_000_000 * 2.5 ^ rebirths)
end

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Weight = 55, Scale = 2.2, Material = Enum.Material.SmoothPlastic },
	{ Name = "Uncommon", Color = Color3.fromRGB(85, 220, 110), Weight = 28, Scale = 2.6, Material = Enum.Material.SmoothPlastic },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Weight = 12, Scale = 3, Material = Enum.Material.SmoothPlastic, Lucky = true },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255), Weight = 4, Scale = 3.4, Material = Enum.Material.Glass, Lucky = true },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), Weight = 0.9, Scale = 3.8, Material = Enum.Material.Neon, Lucky = true, Crown = true, Announce = true },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 90), Weight = 0.1, Scale = 4.4, Material = Enum.Material.Neon, Lucky = true, Crown = true, Sparkles = true, Announce = true },
}

-- Eigene Kreaturen (keine fremden Assets). Body: Bauform (Quad, Bird, Biped, Blob, Frog, Ghost, Lizard, Dragon), Extras: Merkmale.
Config.Units = {
	{ Id = "blobby", Name = "Blobby", Rarity = "Common", Price = 25, Income = 1, Color = Color3.fromRGB(120, 200, 255), Shape = "Ball", Body = "Blob", Extras = {} },
	{ Id = "pebble", Name = "Pebble Pal", Rarity = "Common", Price = 50, Income = 2, Color = Color3.fromRGB(140, 140, 140), Shape = "Block", Body = "Biped", Extras = { "Rocky" } },
	{ Id = "sock", Name = "Sock Goblin", Rarity = "Common", Price = 90, Income = 3, Color = Color3.fromRGB(110, 170, 80), Shape = "Ball", Body = "Biped", Extras = { "BigEars" } },

	{ Id = "toast", Name = "Toast Knight", Rarity = "Uncommon", Price = 250, Income = 6, Color = Color3.fromRGB(210, 160, 90), Shape = "Block", Body = "Biped", Extras = { "Helmet" } },
	{ Id = "frog", Name = "Bubble Frog", Rarity = "Uncommon", Price = 500, Income = 10, Color = Color3.fromRGB(60, 200, 120), Shape = "Ball", Body = "Frog", Extras = {} },
	{ Id = "cactus", Name = "Cactus Cat", Rarity = "Uncommon", Price = 900, Income = 15, Color = Color3.fromRGB(40, 150, 60), Shape = "Block", Body = "Quad", Extras = { "CatEars", "Tail", "Spikes" } },

	{ Id = "duck", Name = "Disco Duck", Rarity = "Rare", Price = 2_500, Income = 35, Color = Color3.fromRGB(255, 230, 60), Shape = "Ball", Body = "Bird", Extras = { "Beak", "DiscoBall" } },
	{ Id = "ninja", Name = "Noodle Ninja", Rarity = "Rare", Price = 5_000, Income = 60, Color = Color3.fromRGB(240, 220, 160), Shape = "Ball", Body = "Biped", Extras = { "Headband" } },
	{ Id = "potato", Name = "Pirate Potato", Rarity = "Rare", Price = 9_000, Income = 95, Color = Color3.fromRGB(170, 120, 70), Shape = "Block", Body = "Biped", Extras = { "PirateHat", "EyePatch" } },

	{ Id = "rooster", Name = "Robo Rooster", Rarity = "Epic", Price = 25_000, Income = 220, Color = Color3.fromRGB(180, 190, 200), Shape = "Block", Body = "Bird", Extras = { "Beak", "Comb", "Metal" } },
	{ Id = "llama", Name = "Lava Llama", Rarity = "Epic", Price = 50_000, Income = 380, Color = Color3.fromRGB(255, 100, 30), Shape = "Ball", Body = "Quad", Extras = { "LongNeck", "Ears", "Tail" } },
	{ Id = "banana", Name = "Ghost Banana", Rarity = "Epic", Price = 90_000, Income = 600, Color = Color3.fromRGB(250, 250, 200), Shape = "Ball", Body = "Ghost", Extras = {} },

	{ Id = "gecko", Name = "Galaxy Gecko", Rarity = "Legendary", Price = 300_000, Income = 1_600, Color = Color3.fromRGB(90, 60, 200), Shape = "Ball", Body = "Lizard", Extras = { "Tail" } },
	{ Id = "turtle", Name = "Thunder Turtle", Rarity = "Legendary", Price = 650_000, Income = 3_000, Color = Color3.fromRGB(60, 120, 255), Shape = "Block", Body = "Quad", Extras = { "Shell" } },
	{ Id = "goose", Name = "Golden Goose", Rarity = "Legendary", Price = 1_200_000, Income = 5_000, Color = Color3.fromRGB(255, 200, 40), Shape = "Ball", Body = "Bird", Extras = { "Beak", "LongNeck" } },

	{ Id = "capybara", Name = "Cosmic Capybara", Rarity = "Mythic", Price = 5_000_000, Income = 18_000, Color = Color3.fromRGB(150, 80, 255), Shape = "Block", Body = "Quad", Extras = { "Ears", "Snout" } },
	{ Id = "donut", Name = "Dragon Donut", Rarity = "Mythic", Price = 12_000_000, Income = 38_000, Color = Color3.fromRGB(255, 80, 160), Shape = "Ball", Body = "Dragon", Extras = { "Horns", "Tail" } },
	{ Id = "icecream", Name = "Infinity Ice Cream", Rarity = "Mythic", Price = 30_000_000, Income = 85_000, Color = Color3.fromRGB(120, 255, 240), Shape = "Ball", Body = "Blob", Extras = { "Cone", "Cherry" } },
}

-- Gamepasses: einmal kaufen, fuer immer behalten. PriceHint = empfohlener Preis in Robux.
-- Id = echte Gamepass-ID (optional). ProductId = Developer Product, das dauerhaft gespeichert wird
-- (per API angelegt, weil der API-Schluessel keine Gamepasses erstellen darf).
Config.GamePasses = {
	VIP = { Id = 0, ProductId = 3721859195, Name = "VIP", Description = "x1.5 income forever + VIP chat tag", PriceHint = 249, Order = 1 },
	DoubleCash = { Id = 0, ProductId = 3721859198, Name = "2x Cash", Description = "Double all income forever", PriceHint = 399, Order = 2 },
	ExtraSlots = { Id = 0, ProductId = 3721859204, Name = "+4 Base Slots", Description = "Hold 4 more critters in your base", PriceHint = 299, Order = 3 },
	FastSteal = { Id = 0, ProductId = 3721859207, Name = "Fast Steal", Description = "Steal in 1 second instead of 2.5", PriceHint = 199, Order = 4 },
	SpeedCoil = { Id = 0, ProductId = 3721859211, Name = "Speed Coil", Description = "Run faster forever - escape with loot", PriceHint = 149, Order = 5 },
}

-- Developer Products: beliebig oft kaufbar.
-- Cash-Pakete skalieren mit dem Einkommen des Spielers, damit sie nie wertlos werden.
Config.DevProducts = {
	CashSmall = { Id = 3721859213, Kind = "Cash", Minutes = 10, MinCash = 1_000, Name = "Cash Bag", Description = "10 minutes of income", PriceHint = 49, Order = 1 },
	CashMedium = { Id = 3721859216, Kind = "Cash", Minutes = 60, MinCash = 10_000, Name = "Cash Crate", Description = "1 hour of income", PriceHint = 199, Order = 2 },
	CashLarge = { Id = 3721859218, Kind = "Cash", Minutes = 360, MinCash = 100_000, Name = "Cash Vault", Description = "6 hours of income", PriceHint = 699, Order = 3 },
	LockBase = { Id = 3721859219, Kind = "Lock", Seconds = 300, Name = "5 Min Base Lock", Description = "Nobody can steal from you for 5 minutes", PriceHint = 39, Order = 4 },
	ServerLuck = { Id = 3721859223, Kind = "ServerLuck", Seconds = 900, Name = "Server Luck x3", Description = "15 min: rare critters spawn 3x more for EVERYONE", PriceHint = 199, Order = 5 },
	-- Sofortkauf des sichtbaren Tiers auf dem Laufband (kein Zufall: der Spieler sieht genau, was er kauft)
	InstantEpic = { Id = 3721859226, Kind = "InstantBuy", Rarity = "Epic", Name = "Instant Epic", Description = "Buy an Epic from the belt with Robux", PriceHint = 49, Hidden = true },
	InstantLegendary = { Id = 3721859228, Kind = "InstantBuy", Rarity = "Legendary", Name = "Instant Legendary", Description = "Buy a Legendary from the belt with Robux", PriceHint = 149, Hidden = true },
	-- Belohnung fuer freiwillige Video-Werbung (Rewarded Video Ad): Roblox zahlt dir pro angesehener Werbung
	AdCash = { Id = 3721862820, Kind = "Cash", Minutes = 5, MinCash = 500, Name = "Free Cash", Description = "Watch a short video ad", PriceHint = 0, Hidden = true },
	-- Neue Produkte: alles festgelegt, kein Zufall (der Spieler weiss genau, was er bekommt)
	StarterPack = { Id = 3721871752, Kind = "StarterPack", Cash = 25_000, Name = "Starter Pack", Description = "One time only: 25K cash + a Golden Epic critter", PriceHint = 79, Order = 0, OwnedAttribute = "StarterPack", Hidden = true },
	GoldenTouch = { Id = 3721871757, Kind = "Mutate", Mutation = "Golden", Name = "Golden Touch", Description = "Turn your best critter Golden (x2 income)", PriceHint = 99, Order = 6 },
	DiamondTouch = { Id = 3721871761, Kind = "Mutate", Mutation = "Diamond", Name = "Diamond Touch", Description = "Turn your best critter Diamond (x4 income)", PriceHint = 249, Order = 7 },
	RainbowTouch = { Id = 3721871765, Kind = "Mutate", Mutation = "Rainbow", Name = "Rainbow Touch", Description = "Turn your best critter Rainbow (x10 income)", PriceHint = 599, Order = 8 },
	FusionCatalyst = { Id = 3721871770, Kind = "Catalyst", Name = "Fusion Catalyst", Description = "Next fusion needs only 2 identical critters", PriceHint = 79, Order = 9 },
	CashParty = { Id = 3721871773, Kind = "CashParty", Seconds = 300, Name = "Cash Party", Description = "5 min DOUBLE CASH for the whole server", PriceHint = 149, Order = 10 },
	InstantMythic = { Id = 3721859230, Kind = "InstantBuy", Rarity = "Mythic", Name = "Instant Mythic", Description = "Buy a Mythic from the belt with Robux", PriceHint = 399, Hidden = true },
}

-- Mutationen: seltene Varianten auf dem Laufband mit Einkommens-Multiplikator
Config.Mutations = {
	{ Name = "Golden", Chance = 0.08, Multiplier = 2, Color = Color3.fromRGB(255, 205, 40), Material = Enum.Material.Foil },
	{ Name = "Diamond", Chance = 0.02, Multiplier = 4, Color = Color3.fromRGB(150, 230, 255), Material = Enum.Material.Glass },
	{ Name = "Rainbow", Chance = 0.004, Multiplier = 10, Color = Color3.fromRGB(255, 80, 200), Material = Enum.Material.Neon },
}

-- Fusion: 3 gleiche Kreaturen verschmelzen zu einer staerkeren (einzigartig im Genre)
Config.FusionMultiplier = 3.5
Config.MaxFusion = 3

-- Rache und Versicherung: wer bestohlen wird, bekommt einen Teil zurueck und kurz Rache-Vorteile
Config.InsuranceShare = 0.25
Config.RevengeDuration = 90
Config.RevengeHoldTime = 0.5

-- Server-Events alle paar Minuten (Ersatz fuer "Admin Abuse"-Events, automatisch und fuer alle gratis)
Config.EventInterval = 8 * 60
Config.EventDuration = 2 * 60
Config.Events = {
	{ Id = "GoldenHour", Name = "GOLDEN HOUR", Description = "Golden critters everywhere!", Color = Color3.fromRGB(255, 205, 40) },
	{ Id = "CritterRush", Name = "CRITTER RUSH", Description = "The belt spawns 3x faster!", Color = Color3.fromRGB(90, 220, 255) },
	{ Id = "LuckyBelt", Name = "LUCKY BELT", Description = "Rare critters 3x more likely!", Color = Color3.fromRGB(90, 255, 140) },
	{ Id = "DoubleCash", Name = "DOUBLE CASH", Description = "Everyone earns 2x!", Color = Color3.fromRGB(120, 255, 120) },
}

-- Taegliche Belohnung mit Serie (Streak)
Config.DailyRewardBase = 500
Config.DailyRewardStreakBonus = 0.5 -- +50% pro Tag in Folge
Config.DailyRewardMaxStreak = 7

-- Rangliste in der Lobby
Config.LeaderboardStore = "TopEarned_v1"
Config.LeaderboardSize = 10

-- Freunde & Einladungen
Config.FriendBoostPer = 0.1 -- +10 % Einkommen pro Freund im selben Server
Config.FriendBoostMax = 0.4
Config.ReferralBoostPer = 0.05 -- +5 % dauerhaft pro eingeladenem neuen Spieler
Config.ReferralBoostMaxCount = 10
Config.ReferralNewcomerCash = 2500 -- Startbonus fuer den Eingeladenen
Config.ReferralInviterCash = 5000 -- mindestens, sonst 5 Minuten Einkommen
Config.ReferralMaxPlayTime = 300 -- nur wirklich neue Spieler zaehlen (Sekunden Spielzeit)

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

-- In Studio Kaeufe mit ID 0 simulieren, damit alles testbar ist
Config.StudioFakePurchases = true
Config.AdCooldown = 180 -- Sekunden zwischen zwei Werbe-Belohnungen pro Spieler

-- Lookup-Tabellen
Config.UnitsById = {}
for _, unit in Config.Units do
	Config.UnitsById[unit.Id] = unit
end

Config.RaritiesByName = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RaritiesByName[rarity.Name] = rarity
end

return Config
