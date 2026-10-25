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
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 90), Weight = 0.1, Scale = 4.4, Material = Enum.Material.Neon, Lucky = true, Crown = true, Sparkles = true, Announce = true, Glow = true },
	{ Name = "Secret", Color = Color3.fromRGB(40, 255, 210), Weight = 0.015, Scale = 5, Material = Enum.Material.Neon, Lucky = true, Crown = true, Sparkles = true, Announce = true, Glow = true },
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

	-- Neue Kreaturen (Update 2)
	{ Id = "bunny", Name = "Mochi Bunny", Rarity = "Uncommon", Price = 1_400, Income = 21, Color = Color3.fromRGB(255, 205, 225), Shape = "Ball", Body = "Quad", Extras = { "BigEars", "Tail" } },
	{ Id = "penguin", Name = "Pizza Penguin", Rarity = "Rare", Price = 14_000, Income = 140, Color = Color3.fromRGB(60, 60, 80), Shape = "Ball", Body = "Bird", Extras = { "Beak" } },
	{ Id = "sloth", Name = "Samurai Sloth", Rarity = "Epic", Price = 150_000, Income = 950, Color = Color3.fromRGB(150, 120, 90), Shape = "Ball", Body = "Biped", Extras = { "Helmet" } },
	{ Id = "kitsune", Name = "Crystal Kitsune", Rarity = "Legendary", Price = 2_500_000, Income = 9_500, Color = Color3.fromRGB(150, 220, 255), Shape = "Ball", Body = "Quad", Extras = { "CatEars", "Tail" } },
	{ Id = "narwhal", Name = "Nebula Narwhal", Rarity = "Mythic", Price = 60_000_000, Income = 160_000, Color = Color3.fromRGB(110, 90, 255), Shape = "Ball", Body = "Ghost", Extras = { "Horns" } },
	{ Id = "goat", Name = "Glitch Goat", Rarity = "Secret", Price = 150_000_000, Income = 400_000, Color = Color3.fromRGB(30, 30, 40), Shape = "Block", Body = "Quad", Extras = { "Horns", "Tail" } },
	{ Id = "voiddragon", Name = "Void Dragon", Rarity = "Secret", Price = 400_000_000, Income = 1_000_000, Color = Color3.fromRGB(20, 10, 40), Shape = "Ball", Body = "Dragon", Extras = { "Horns", "Tail" } },

	-- Neue Kreaturen (Update 4)
	{ Id = "jelly", Name = "Jelly Jester", Rarity = "Uncommon", Price = 1_900, Income = 27, Color = Color3.fromRGB(255, 140, 200), Shape = "Ball", Body = "Blob", Extras = { "Horns" } },
	{ Id = "owl", Name = "Night Owl", Rarity = "Rare", Price = 20_000, Income = 190, Color = Color3.fromRGB(120, 90, 60), Shape = "Ball", Body = "Bird", Extras = { "Beak", "Ears" } },
	{ Id = "yeti", Name = "Frost Yeti", Rarity = "Epic", Price = 220_000, Income = 1_300, Color = Color3.fromRGB(225, 235, 250), Shape = "Ball", Body = "Biped", Extras = { "BigEars", "Horns" } },
	{ Id = "phoenix", Name = "Pixel Phoenix", Rarity = "Legendary", Price = 4_000_000, Income = 14_000, Color = Color3.fromRGB(255, 120, 40), Shape = "Ball", Body = "Bird", Extras = { "Beak", "Comb", "Tail" } },
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
	OfflinePro = { Id = 0, ProductId = 3721931507, Name = "Offline Pro", Description = "Earn 100% of your income while offline (up to 24h)", PriceHint = 199, Order = 6 },
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
	QuestSkip = { Id = 3721931517, Kind = "QuestSkip", Name = "Quest Skip", Description = "Instantly complete one daily quest", PriceHint = 29, Order = 11 },
	InstantMythic = { Id = 3721859230, Kind = "InstantBuy", Rarity = "Mythic", Name = "Instant Mythic", Description = "Buy a Mythic from the belt with Robux", PriceHint = 399, Hidden = true },
}

-- Mutationen: seltene Varianten auf dem Laufband mit Einkommens-Multiplikator
Config.Mutations = {
	{ Name = "Golden", Chance = 0.08, Multiplier = 2, Color = Color3.fromRGB(255, 205, 40), Material = Enum.Material.Foil },
	-- Update 4: gibt es nur nachts auf dem Laufband
	{ Name = "Moonlit", Chance = 0.03, Multiplier = 3, Color = Color3.fromRGB(160, 170, 255), Material = Enum.Material.Neon, NightOnly = true },
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
	{ Id = "CashRain", Name = "CASH RAIN", Description = "Money falls from the sky - grab it!", Color = Color3.fromRGB(110, 255, 130) },
	{ Id = "MythicDrop", Name = "MYTHIC DROP", Description = "A Mythic (or Secret!) critter appears on the belt!", Color = Color3.fromRGB(255, 60, 90) },
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

---------------------------------------------------------------- Update 2: Bindung und Fortschritt

-- Taegliche Quests: jeden Tag (UTC) 3 zufaellige aus dieser Liste. Reward = Minuten Einkommen (mindestens MinCash)
Config.QuestsPerDay = 3
Config.Quests = {
	{ Id = "Buy", Stat = "Bought", Text = "Buy %d critters from the belt", Goals = { 5, 10, 20 }, Minutes = 10 },
	{ Id = "Steal", Stat = "Stolen", Text = "Steal %d critters", Goals = { 1, 3, 5 }, Minutes = 20 },
	{ Id = "Slap", Stat = "Slaps", Text = "Slap %d players", Goals = { 5, 15, 30 }, Minutes = 8 },
	{ Id = "Fuse", Stat = "Fused", Text = "Fuse %d critters", Goals = { 1, 2 }, Minutes = 25 },
	{ Id = "Rain", Stat = "Coins", Text = "Collect %d coins in Cash Rain", Goals = { 10, 25 }, Minutes = 12 },
	{ Id = "Play", Stat = "Minutes", Text = "Play %d minutes", Goals = { 10, 20, 30 }, Minutes = 15 },
	{ Id = "Sell", Stat = "Sold", Text = "Sell %d critters", Goals = { 2, 5 }, Minutes = 6 },
}
Config.QuestMinCash = 1_000
Config.AllQuestsBonusMinutes = 30 -- Bonus, wenn alle Quests des Tages erledigt sind

-- Erfolge (einmalig, Belohnung in Cash). Stat = Zaehler in data.Stats oder Spezialwert
Config.Achievements = {
	{ Id = "Buy1", Name = "First Critter", Stat = "Bought", Goal = 1, Cash = 500 },
	{ Id = "Buy50", Name = "Collector", Stat = "Bought", Goal = 50, Cash = 25_000 },
	{ Id = "Buy250", Name = "Critter Tycoon", Stat = "Bought", Goal = 250, Cash = 500_000 },
	{ Id = "Steal1", Name = "Sneaky", Stat = "Stolen", Goal = 1, Cash = 2_000 },
	{ Id = "Steal25", Name = "Master Thief", Stat = "Stolen", Goal = 25, Cash = 100_000 },
	{ Id = "Steal100", Name = "Legendary Heister", Stat = "Stolen", Goal = 100, Cash = 2_000_000 },
	{ Id = "Slap50", Name = "Slap Happy", Stat = "Slaps", Goal = 50, Cash = 20_000 },
	{ Id = "Fuse1", Name = "Fusion Lab", Stat = "Fused", Goal = 1, Cash = 10_000 },
	{ Id = "Fuse10", Name = "Mad Scientist", Stat = "Fused", Goal = 10, Cash = 750_000 },
	{ Id = "Rebirth1", Name = "Reborn", Stat = "Rebirths", Goal = 1, Cash = 50_000 },
	{ Id = "Rebirth5", Name = "Phoenix", Stat = "Rebirths", Goal = 5, Cash = 5_000_000 },
	{ Id = "Index10", Name = "Critter Scholar", Stat = "Index", Goal = 10, Cash = 50_000 },
	{ Id = "IndexAll", Name = "Gotta Catch 'Em", Stat = "Index", Goal = #Config.Units, Cash = 10_000_000 },
	{ Id = "Earn1M", Name = "Millionaire", Stat = "TotalEarned", Goal = 1_000_000, Cash = 50_000 },
	{ Id = "Earn1B", Name = "Billionaire", Stat = "TotalEarned", Goal = 1_000_000_000, Cash = 50_000_000 },
	{ Id = "Quests10", Name = "Quest Hero", Stat = "QuestsDone", Goal = 10, Cash = 100_000 },
	{ Id = "Streak7", Name = "Loyal Boss", Stat = "Streak", Goal = 7, Cash = 250_000 },
}

-- Geschenke fuer Spielzeit in dieser Sitzung (Minuten). Reward = Minuten Einkommen, mindestens MinCash
Config.PlaytimeGifts = {
	{ Minutes = 3, Reward = 3, MinCash = 300 },
	{ Minutes = 8, Reward = 6, MinCash = 800 },
	{ Minutes = 15, Reward = 10, MinCash = 2_000 },
	{ Minutes = 25, Reward = 15, MinCash = 5_000 },
	{ Minutes = 40, Reward = 25, MinCash = 10_000 },
	{ Minutes = 60, Reward = 40, MinCash = 25_000, Catalyst = true },
}

-- Gratis-Gluecksrad: einmal pro 20 Stunden, Preise fest (Weight = Wahrscheinlichkeit). Kein Robux-Kauf moeglich.
Config.SpinCooldown = 20 * 3600
Config.SpinPrizes = {
	{ Name = "5 min cash", Kind = "Cash", Minutes = 5, Weight = 30, Color = Color3.fromRGB(90, 220, 120) },
	{ Name = "15 min cash", Kind = "Cash", Minutes = 15, Weight = 22, Color = Color3.fromRGB(60, 190, 255) },
	{ Name = "1 hour cash", Kind = "Cash", Minutes = 60, Weight = 8, Color = Color3.fromRGB(255, 200, 40) },
	{ Name = "Server Luck 5 min", Kind = "Luck", Seconds = 300, Weight = 12, Color = Color3.fromRGB(90, 255, 140) },
	{ Name = "Fusion Catalyst", Kind = "Catalyst", Weight = 10, Color = Color3.fromRGB(120, 255, 200) },
	{ Name = "Golden critter", Kind = "Mutate", Mutation = "Golden", Weight = 12, Color = Color3.fromRGB(255, 205, 40) },
	{ Name = "Diamond critter", Kind = "Mutate", Mutation = "Diamond", Weight = 5, Color = Color3.fromRGB(150, 230, 255) },
	{ Name = "Rainbow critter", Kind = "Mutate", Mutation = "Rainbow", Weight = 1, Color = Color3.fromRGB(255, 80, 200) },
}

-- Index: jede entdeckte Art gibt dauerhaft +2 % Einkommen; Meilensteine geben Cash
Config.IndexBonusPer = 0.02
Config.IndexMilestones = { { Count = 5, Cash = 10_000 }, { Count = 10, Cash = 100_000 }, { Count = 15, Cash = 1_000_000 }, { Count = 20, Cash = 10_000_000 }, { Count = 25, Cash = 100_000_000 } }

-- Basis-Ausbau (Cash-Senke): jede Stufe +10 % Einkommen und +5 s Sperre
Config.BaseMaxLevel = 10
Config.BaseLevelIncome = 0.1
Config.BaseLevelLock = 5
function Config.BaseUpgradeCost(level: number): number
	return math.floor(5_000 * 4 ^ level)
end

-- Offline-Einnahmen: Anteil des Einkommens, maximale Stunden (Offline Pro: 100 %, 24 h)
Config.OfflineShare = 0.25
Config.OfflineMaxHours = 6
Config.OfflineProShare = 1
Config.OfflineProMaxHours = 24
Config.OfflineMinSeconds = 120

-- Codes fuer Social Media (Gross/Kleinschreibung egal). Reward = Minuten Einkommen, mindestens Cash
Config.Codes = {
	RELEASE = { Minutes = 10, Cash = 5_000 },
	CRITTER = { Minutes = 10, Cash = 5_000 },
	UPDATE2 = { Minutes = 20, Cash = 20_000 },
	BIGBABA = { Minutes = 15, Cash = 10_000 },
	UPDATE4 = { Minutes = 20, Cash = 25_000 },
}

-- Neulingsschutz: wer weniger als X Minuten gespielt hat, kann nicht bestohlen werden
Config.NewbieShieldMinutes = 10

-- Kopfgeld: der reichste Spieler im Server ist markiert, wer ihn bestiehlt, bekommt Bonus
Config.BountyMinPlayers = 3
Config.BountyShare = 0.5 -- Anteil des Kreaturwerts als Bonus

-- Happy Hour: jeden Tag zur selben Uhrzeit Double Cash fuer alle (UTC-Stunde; 18 UTC = 19/20 Uhr in Deutschland)
Config.HappyHourUtc = 18

-- Server-Ziel: gemeinsam X Kreaturen klauen/kaufen -> Double Cash fuer alle
Config.ServerGoal = 40
Config.ServerGoalReward = 300 -- Sekunden Double Cash

-- Cash Rain: Muenzen pro Welle und Wert (Sekunden Einkommen des Sammlers)
Config.CashRainCoins = 30
Config.CashRainCoinSeconds = 20
Config.CashRainMinCash = 200

-- Kreatur des Tages: eine Art verdient heute doppelt
Config.FeaturedMultiplier = 2

-- Verkaufen: Anteil des Werts
Config.SellShare = 0.5

-- In Studio Kaeufe mit ID 0 simulieren, damit alles testbar ist
Config.StudioFakePurchases = true
Config.AdCooldown = 180 -- Sekunden zwischen zwei Werbe-Belohnungen pro Spieler

---------------------------------------------------------------- Update 3 (FeatureService, Features.luau)

-- Eier: nur mit Spielgeld (kein Robux, damit es keine bezahlten Zufallsgegenstaende gibt). Chancen sind im Spiel sichtbar.
Config.Eggs = {
	{ Id = "Basic", Name = "Basic Egg", Icon = "🥚", Price = 1_000, Color = Color3.fromRGB(120, 170, 220), Weights = { Common = 60, Uncommon = 30, Rare = 9, Epic = 1 } },
	{ Id = "Rare", Name = "Rare Egg", Icon = "💠", Price = 40_000, Color = Color3.fromRGB(150, 90, 240), Weights = { Uncommon = 35, Rare = 40, Epic = 20, Legendary = 5 } },
	{ Id = "Mythic", Name = "Mythic Egg", Icon = "🔥", Price = 4_000_000, Color = Color3.fromRGB(240, 80, 110), Weights = { Epic = 50, Legendary = 38, Mythic = 11, Secret = 1 } },
}

-- Training: jede Stufe +15% Einkommen fuer genau diese Kreatur (geht beim Klauen/Verkaufen verloren)
Config.TrainBonusPer = 0.15
Config.TrainMaxLevel = 5
Config.TrainCostShare = 0.4 -- Kosten = Wert * Anteil * (Stufe + 1)

-- Tresor: eine Kreatur kann nicht geklaut werden (Kosten = Anteil ihres Werts)
Config.VaultCostShare = 0.25

-- Alarmanlage (einmal kaufen): Warnung an alle und der Dieb wird langsamer
Config.AlarmPrice = 25_000
Config.AlarmSlow = 0.75

-- Rebirth-Tokens: pro Rebirth 1 Token fuer dauerhafte Perks (Kosten = naechste Stufe in Tokens)
Config.Perks = {
	{ Id = "Cash", Name = "Cash Boost", Icon = "💰", Text = "+10% income per level", Max = 5, Per = 0.1 },
	{ Id = "Speed", Name = "Quick Feet", Icon = "👟", Text = "+2 walk speed per level", Max = 3, Per = 2 },
	{ Id = "Thief", Name = "Sticky Hands", Icon = "🧤", Text = "Steal 0.25s faster per level", Max = 2, Per = 0.25 },
	{ Id = "EggLuck", Name = "Egg Luck", Icon = "🍀", Text = "Rarer critters from eggs", Max = 3, Per = 0.25 },
}

-- Critter Pass (kostenlos): XP aus allem, was man tut; jede Stufe hat eine Belohnung
Config.PassTiers = 25
function Config.PassXP(tier: number): number
	return 100 + tier * 25
end
Config.PassXPPer = { Bought = 10, Stolen = 25, Hatched = 15, Trained = 10, QuestsDone = 50, BossHits = 1, Minutes = 5, Gems = 15, Fused = 30, Slaps = 3 }

-- Klau-Combo: mehrere Diebstaehle kurz hintereinander geben Bonus-Cash (Anteil des Kreaturwerts)
Config.ComboWindow = 180
Config.ComboBonus = { 0, 0.2, 0.5, 1 }

-- Edelstein-Jagd: Steine liegen im Spiel verteilt, wer zuerst kommt, bekommt sie
Config.GemCount = 6
Config.GemRespawn = 60
Config.GemSeconds = 45 -- Sekunden Einkommen
Config.GemMinCash = 250

-- Likes fuer Basen: +1% Einkommen pro Like (hoechstens +25%), ein Like pro Spieler und Tag
Config.LikeBonusPer = 0.01
Config.LikeBonusMax = 0.25

-- Geld verschenken: 10% vom eigenen Geld, hoechstens 3x am Tag
Config.GiftShare = 0.1
Config.GiftMaxPerDay = 3
Config.GiftMinCash = 100

-- Boss-Raid: alle 10 Minuten ein Riesen-Monster am Spawn, alle schlagen gemeinsam zu
Config.BossInterval = 600
Config.BossDuration = 90
Config.BossHitsPerPlayer = 60
Config.BossRewardMinutes = 4
Config.BossMinReward = 2_000

-- Speed-Pads auf dem Weg
Config.SpeedPadBoost = 14
Config.SpeedPadTime = 5

-- Tag und Nacht: nachts mehr Glueck auf dem Laufband
Config.DayLength = 540
Config.NightLength = 180
Config.NightLuck = 1.5

-- Goldene Kreatur: alle 5 Minuten eine garantiert goldene Kreatur auf dem Laufband
Config.GoldenBeltInterval = 300

-- Kumpel: die beste Kreatur laeuft einem hinterher (+5% Einkommen)
Config.BuddyBonus = 0.05

-- Basis-Farben (Spielgeld)
Config.BaseColorPrice = 5_000
Config.BaseColors = {
	{ Name = "Sunset", Color = Color3.fromRGB(235, 120, 80) },
	{ Name = "Ocean", Color = Color3.fromRGB(60, 140, 230) },
	{ Name = "Mint", Color = Color3.fromRGB(70, 200, 150) },
	{ Name = "Grape", Color = Color3.fromRGB(150, 90, 230) },
	{ Name = "Gold", Color = Color3.fromRGB(240, 190, 60) },
	{ Name = "Rose", Color = Color3.fromRGB(235, 90, 150) },
	{ Name = "Shadow", Color = Color3.fromRGB(60, 60, 75) },
	{ Name = "Snow", Color = Color3.fromRGB(225, 230, 240) },
}

---------------------------------------------------------------- Update 4 (ExtraService, Extras.luau)

-- Einfuehrung fuer neue Spieler: Schritte mit Belohnung (Stat = Zaehler in data.Stats). Target = wohin der Pfeil zeigt
Config.TutorialSteps = {
	{ Text = "Buy a critter from the belt", Stat = "Bought", Goal = 1, Cash = 500, Target = "Belt" },
	{ Text = "Lock your base at the red button", Stat = "Locks", Goal = 1, Cash = 1_000, Target = "Lock" },
	{ Text = "Hatch your FREE egg (MORE > EGGS)", Stat = "Hatched", Goal = 1, Cash = 1_500 },
	{ Text = "Steal a critter from another base", Stat = "Stolen", Goal = 1, Cash = 3_000, Target = "Steal" },
}

-- Wochen-Quests: jede Woche (ab Montag 00:00 UTC) 3 grosse Aufgaben. Reward = Minuten Einkommen (mindestens MinCash)
Config.WeeklyQuestsPerWeek = 3
Config.WeeklyQuests = {
	{ Id = "Buy", Stat = "Bought", Text = "Buy %d critters", Goal = 100, Minutes = 60 },
	{ Id = "Steal", Stat = "Stolen", Text = "Steal %d critters", Goal = 15, Minutes = 90 },
	{ Id = "Hatch", Stat = "Hatched", Text = "Hatch %d eggs", Goal = 30, Minutes = 60 },
	{ Id = "Boss", Stat = "BossHits", Text = "Hit bosses %d times", Goal = 300, Minutes = 60 },
	{ Id = "Gems", Stat = "Gems", Text = "Find %d gems", Goal = 25, Minutes = 45 },
	{ Id = "Play", Stat = "Minutes", Text = "Play %d minutes", Goal = 180, Minutes = 90 },
	{ Id = "Trips", Stat = "Expeditions", Text = "Finish %d expeditions", Goal = 8, Minutes = 75 },
	{ Id = "Fuse", Stat = "Fused", Text = "Fuse %d critters", Goal = 5, Minutes = 90 },
}
Config.WeeklyMinCash = 20_000

-- Titel ueber dem Namen: werden durch Statistiken freigeschaltet (Stat wie bei den Erfolgen, dazu PlayHours und Likes)
Config.Titles = {
	{ Id = "Rookie", Name = "Rookie", Text = "Everyone starts here", Stat = "PlayHours", Goal = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Id = "Collector", Name = "Collector", Text = "Buy 50 critters", Stat = "Bought", Goal = 50, Color = Color3.fromRGB(120, 220, 255) },
	{ Id = "Hatcher", Name = "Egg Whisperer", Text = "Hatch 25 eggs", Stat = "Hatched", Goal = 25, Color = Color3.fromRGB(150, 200, 255) },
	{ Id = "Thief", Name = "Master Thief", Text = "Steal 25 critters", Stat = "Stolen", Goal = 25, Color = Color3.fromRGB(255, 110, 110) },
	{ Id = "Slapper", Name = "Slap King", Text = "Slap 100 times", Stat = "Slaps", Goal = 100, Color = Color3.fromRGB(255, 170, 80) },
	{ Id = "Scientist", Name = "Mad Scientist", Text = "Fuse 10 critters", Stat = "Fused", Goal = 10, Color = Color3.fromRGB(180, 110, 255) },
	{ Id = "Explorer", Name = "Explorer", Text = "Finish 10 expeditions", Stat = "Expeditions", Goal = 10, Color = Color3.fromRGB(110, 230, 160) },
	{ Id = "Slayer", Name = "Boss Slayer", Text = "Beat 10 bosses", Stat = "Bosses", Goal = 10, Color = Color3.fromRGB(255, 80, 120) },
	{ Id = "Scholar", Name = "Critter Scholar", Text = "Discover 20 critters", Stat = "Index", Goal = 20, Color = Color3.fromRGB(200, 160, 255) },
	{ Id = "Popular", Name = "Popular", Text = "Get 25 base likes", Stat = "Likes", Goal = 25, Color = Color3.fromRGB(255, 130, 180) },
	{ Id = "Loyal", Name = "Loyal Boss", Text = "Reach a 7 day streak", Stat = "Streak", Goal = 7, Color = Color3.fromRGB(255, 210, 90) },
	{ Id = "Phoenix", Name = "Phoenix", Text = "Rebirth 3 times", Stat = "Rebirths", Goal = 3, Color = Color3.fromRGB(255, 150, 60) },
	{ Id = "Millionaire", Name = "Millionaire", Text = "Earn $1M in total", Stat = "TotalEarned", Goal = 1_000_000, Color = Color3.fromRGB(120, 255, 140) },
	{ Id = "Billionaire", Name = "Billionaire", Text = "Earn $1B in total", Stat = "TotalEarned", Goal = 1_000_000_000, Color = Color3.fromRGB(255, 220, 60) },
}

-- Gratis-Ei: alle 12 Stunden ein Basic Egg
Config.FreeEggCooldown = 12 * 3600
Config.FreeEggId = "Basic"

-- Expeditionen: eine Kreatur geht auf Reise (verdient waehrenddessen nichts und kann nicht geklaut werden),
-- kommt mit Cash (RewardMinutes ihres Einkommens) und manchmal mit einer besseren Mutation zurueck
Config.MaxExpeditions = 2
Config.Expeditions = {
	{ Id = "Short", Name = "Quick Trip", Minutes = 30, RewardMinutes = 45, MinCash = 1_000, Mutations = { { Name = "Golden", Chance = 0.05 } } },
	{ Id = "Long", Name = "Big Adventure", Minutes = 120, RewardMinutes = 200, MinCash = 5_000, Mutations = { { Name = "Diamond", Chance = 0.02 }, { Name = "Golden", Chance = 0.15 } } },
	{ Id = "Epic", Name = "Epic Quest", Minutes = 480, RewardMinutes = 900, MinCash = 25_000, Mutations = { { Name = "Rainbow", Chance = 0.01 }, { Name = "Diamond", Chance = 0.06 }, { Name = "Golden", Chance = 0.3 } } },
}

-- Schnell-Verkauf: alle einfachen Kreaturen dieser Seltenheiten auf einmal (ohne Mutation, Fusion, Training, Favorit)
Config.BulkSellRarities = { "Common", "Uncommon" }

-- Diebstahl-Protokoll: so viele Eintraege werden gespeichert
Config.TheftLogSize = 12

-- Abstimmung ueber das naechste Server-Event (Sekunden vor dem Start)
Config.EventVoteTime = 45
Config.EventVoteOptions = 3

-- Trampoline am Ende des Laufbands
Config.TrampolinePower = 95

-- Basis-Deko (nur Spielgeld, rein optisch)
Config.Decorations = {
	{ Id = "Flowers", Name = "Flower Beds", Icon = "🌷", Price = 15_000 },
	{ Id = "Lanterns", Name = "Lanterns", Icon = "🏮", Price = 50_000 },
	{ Id = "Flag", Name = "Base Flag", Icon = "🚩", Price = 150_000 },
	{ Id = "Fountain", Name = "Fountain", Icon = "⛲", Price = 750_000 },
	{ Id = "Statue", Name = "Golden Statue", Icon = "🗿", Price = 5_000_000 },
}

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
