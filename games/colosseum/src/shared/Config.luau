-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Colosseum Catcher.
-- Alle Bestien, Namen und Modelle sind eigene Erfindungen (keine fremden Marken oder Assets).
-- Produkt-IDs kommen automatisch aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Solange eine ID 0 ist, kann man den Kauf in Studio ueber den Shop simulieren.

local Beasts = require(script.Parent.Beasts)

local Config = {}

Config.DataStoreName = "ColosseumData_v2"

-- Daten aus Beasts und Story weiterreichen
Config.Beasts = Beasts.List
Config.BeastsById = Beasts.ById
Config.Types = Beasts.Types
Config.TypeOrder = Beasts.TypeOrder
Config.Moves = Beasts.Moves
Config.Statuses = Beasts.Statuses
Config.Rarities = Beasts.Rarities
Config.RaritiesByName = Beasts.RaritiesByName
Config.MaxLevel = Beasts.MaxLevel
Config.Stats = Beasts.Stats
Config.Power = Beasts.Power
Config.XpToNext = Beasts.XpToNext
Config.Effectiveness = Beasts.Effectiveness

---------------------------------------------------------------- Wirtschaft

Config.StartCoins = 3_000
Config.Starters = { "cindercub", "puddlit", "sproutling" }
Config.StarterLevel = 5
Config.TeamSize = 6
Config.MaxMoves = 4
Config.MaxStorage = 60

-- Multiplikatoren
Config.VipCoins = 1.5
Config.VipXp = 1.25
Config.DoubleCoins = 2
Config.DoubleXp = 2
Config.BoostMultiplier = 2 -- 30-Minuten-Boost: Muenzen und XP
Config.PremiumMultiplier = 1.2 -- belohnt Premium-Spieler, erhoeht die Premium Payouts
Config.LuckyCatchMultiplier = 1.3
Config.ShinyChance = 1 / 250
Config.ShinyHunterMultiplier = 3
Config.ServerShinyMultiplier = 2
Config.DefaultWalkSpeed = 18
Config.SpeedWalkSpeed = 28
Config.BenchXpShare = 0.25 -- EP fuer Team-Mitglieder, die nicht gekaempft haben (mit XP Share: 1)

-- Begegnungen im hohen Gras: alle EncounterStep Studs wird gewuerfelt
Config.EncounterStep = 4
Config.EncounterChance = 1 / 11
Config.EncounterGrace = 3 -- Sekunden Ruhe nach einem Kampf

-- Gegenstaende. Badges = noetige Orden, damit der Laden sie verkauft.
Config.Items = {
	Orb = { Name = "Catch Orb", Price = 200, Catch = 1, Color = Color3.fromRGB(150, 60, 170), Order = 1, Badges = 0, Pocket = "Orbs", Description = "A basic orb for catching wild beasts" },
	GreatOrb = { Name = "Great Orb", Price = 600, Catch = 1.5, Color = Color3.fromRGB(70, 140, 255), Order = 2, Badges = 2, Pocket = "Orbs", Description = "1.5x better than a Catch Orb" },
	RoyalOrb = { Name = "Royal Orb", Price = 1_200, Catch = 2, Color = Color3.fromRGB(240, 190, 60), Order = 3, Badges = 5, Pocket = "Orbs", Description = "2x better than a Catch Orb" },
	MasterOrb = { Name = "Master Orb", Price = 0, Catch = math.huge, Color = Color3.fromRGB(255, 80, 160), Order = 4, Badges = 99, Pocket = "Orbs", Description = "Always catches. Robux only" },
	Potion = { Name = "Potion", Price = 300, Heal = 25, Color = Color3.fromRGB(90, 220, 120), Order = 5, Badges = 0, Pocket = "Medicine", Description = "Restores 25 HP" },
	SuperPotion = { Name = "Super Potion", Price = 700, Heal = 70, Color = Color3.fromRGB(255, 160, 60), Order = 6, Badges = 2, Pocket = "Medicine", Description = "Restores 70 HP" },
	HyperPotion = { Name = "Hyper Potion", Price = 1_500, Heal = 200, Color = Color3.fromRGB(255, 90, 160), Order = 7, Badges = 5, Pocket = "Medicine", Description = "Restores 200 HP" },
	FullCure = { Name = "Full Cure", Price = 400, Cure = true, Color = Color3.fromRGB(250, 230, 120), Order = 8, Badges = 1, Pocket = "Medicine", Description = "Cures burn, poison, paralysis, sleep and freeze" },
	Revive = { Name = "Revive", Price = 2_000, Revive = 0.5, Color = Color3.fromRGB(255, 220, 90), Order = 9, Badges = 3, Pocket = "Medicine", Description = "Revives a fainted beast with half its HP" },
}
Config.StartItems = { Orb = 0, Potion = 2 }

---------------------------------------------------------------- Kaempfe

Config.TurnTimeout = 30 -- Sekunden, danach waehlt der Server automatisch
Config.CritChance = 1 / 16
Config.HighCritChance = 1 / 6
Config.CritMultiplier = 1.5
Config.StabMultiplier = 1.5
Config.WhiteoutCoinLoss = 0 -- Anteil der Muenzen beim Verlieren (kinderfreundlich: nichts)

-- Muenzen fuer Siege
function Config.TrainerCoins(team: { { any } }): number
	local top = 0
	for _, member in team do
		top = math.max(top, member[2])
	end
	return 60 + top * 40
end
function Config.WildCoins(level: number): number
	return 4 + level * 2
end

-- Endlose Gauntlet-Wellen (ab dem ersten Orden): Gegner werden immer staerker, Muenzen pro Welle, Bestenliste
Config.GauntletBadges = 1
Config.GauntletCoinsPerWave = 150
function Config.GauntletLevel(wave: number): number
	return math.min(Config.MaxLevel, 6 + math.floor(wave * 2))
end
Config.RematchShare = 0.35 -- Anteil der Muenzen bei Revanche gegen Arenaleiter

-- Duelle zwischen Spielern
Config.DuelTrophies = 10
Config.DuelInviteSeconds = 20

---------------------------------------------------------------- Monetarisierung

-- Pässe werden als Developer Products verkauft und dauerhaft gespeichert (lassen sich per API anlegen).
-- AffectsRandom: veraendert Zufallsergebnisse -> in Laendern mit Lootbox-Verbot (PolicyService) ausgeblendet.
Config.GamePasses = {
	VIP = { Id = 0, ProductId = 0, Name = "VIP", Description = "x1.5 coins, x1.25 XP, golden name + VIP tag", PriceHint = 249, Order = 1 },
	DoubleCoins = { Id = 0, ProductId = 0, Name = "2x Coins", Description = "Double coins from every battle forever", PriceHint = 299, Order = 2 },
	DoubleXp = { Id = 0, ProductId = 0, Name = "2x XP", Description = "Your beasts level up twice as fast", PriceHint = 249, Order = 3 },
	BigTeam = { Id = 0, ProductId = 0, Name = "XP Share", Description = "Every beast in your team gets FULL XP, even if it did not fight", PriceHint = 299, Order = 4 },
	ShinyHunter = { Id = 0, ProductId = 0, Name = "Prismatic Hunter", Description = "3x chance to meet PRISMATIC beasts", PriceHint = 349, Order = 5, AffectsRandom = true },
	LuckyCatch = { Id = 0, ProductId = 0, Name = "Lucky Catcher", Description = "x1.3 catch chance with every orb", PriceHint = 199, Order = 6, AffectsRandom = true },
	AutoBattle = { Id = 0, ProductId = 0, Name = "Auto Battle", Description = "Your beasts pick the best move by themselves", PriceHint = 149, Order = 7 },
	Speed = { Id = 0, ProductId = 0, Name = "Speed", Description = "Run faster forever", PriceHint = 99, Order = 8 },
}

-- Developer Products: beliebig oft kaufbar (ausser OneTime).
Config.DevProducts = {
	MasterOrb1 = { Id = 0, Kind = "Item", Item = "MasterOrb", Amount = 1, Name = "Master Orb", Description = "Always catches - even legends!", PriceHint = 49, Order = 1 },
	MasterOrb5 = { Id = 0, Kind = "Item", Item = "MasterOrb", Amount = 5, Name = "5 Master Orbs", Description = "5 orbs that always catch (save 20%)", PriceHint = 199, Order = 2 },
	StarterPack = { Id = 0, Kind = "Starter", Name = "Starter Pack", Description = "One time only: 3 Master Orbs, 10 Great Orbs, 10,000 coins, 30 min 2x boost", PriceHint = 79, Order = 3, OneTime = true },
	CoinsSmall = { Id = 0, Kind = "Coins", Battles = 10, Name = "Coin Pouch", Description = "Coins for about 10 trainer battles at your level", PriceHint = 49, Order = 4, AffectsRandom = true },
	CoinsMedium = { Id = 0, Kind = "Coins", Battles = 50, Name = "Coin Chest", Description = "Coins for about 50 trainer battles at your level", PriceHint = 199, Order = 5, AffectsRandom = true },
	CoinsLarge = { Id = 0, Kind = "Coins", Battles = 200, Name = "Coin Treasury", Description = "Coins for about 200 trainer battles at your level", PriceHint = 699, Order = 6, AffectsRandom = true },
	Boost = { Id = 0, Kind = "Boost", Seconds = 1800, Name = "2x Coins + XP (30 min)", Description = "Double coins and XP for 30 minutes", PriceHint = 99, Order = 7 },
	PowerSnack = { Id = 0, Kind = "Levels", Amount = 5, Name = "Power Snack", Description = "+5 levels for your lead beast", PriceHint = 49, Order = 8 },
	EvoCrystal = { Id = 0, Kind = "Evolve", Name = "Ascension Crystal", Description = "Your lead beast evolves into its next form NOW", PriceHint = 99, Order = 9 },
	SkipChampion = { Id = 0, Kind = "Skip", Name = "Champion Pass", Description = "Instantly earn the next arena badge", PriceHint = 149, Order = 10 },
	FullHeal = { Id = 0, Kind = "Heal", Name = "Full Heal", Description = "Heal and revive your whole team anywhere", PriceHint = 15, Order = 11 },
	GauntletContinue = { Id = 0, Kind = "Continue", Name = "Gauntlet Second Chance", Description = "Revive your team and keep your gauntlet streak", PriceHint = 29, Order = 12, Hidden = true },
	ServerShiny = { Id = 0, Kind = "ServerShiny", Seconds = 900, Name = "Prismatic Storm", Description = "15 min: PRISMATIC beasts x2 for EVERYONE", PriceHint = 199, Order = 13, AffectsRandom = true },
	Storage = { Id = 0, Kind = "Storage", Amount = 50, Name = "+50 Beast Storage", Description = "Keep 50 more beasts in your box", PriceHint = 99, Order = 14 },
	QuestFinish = { Id = 0, Kind = "Quests", Name = "Quest Finisher", Description = "Instantly complete all of today's daily quests", PriceHint = 39, Order = 15 },
	AdReward = { Id = 0, Kind = "Item", Item = "GreatOrb", Amount = 3, Name = "Free Great Orbs (Video Ad)", Description = "Reward for watching a video ad: 3 Great Orbs", PriceHint = 5, Order = 99, Hidden = true },
}
Config.AdCooldown = 300
Config.OfferCooldown = 150 -- Sekunden zwischen zwei Kaufangeboten

-- Taegliche Belohnung (waechst mit der Serie, max. 7 Tage)
Config.DailyRewards = {
	{ Coins = 500, Items = { Orb = 5 } },
	{ Coins = 800, Items = { Potion = 3 } },
	{ Coins = 1_200, Items = { GreatOrb = 3 } },
	{ Coins = 1_600, Items = { SuperPotion = 3 } },
	{ Coins = 2_000, Items = { GreatOrb = 5 } },
	{ Coins = 3_000, Items = { Revive = 2 } },
	{ Coins = 5_000, Items = { MasterOrb = 1 } },
}

Config.Codes = {
	COLOSSEUM = { Coins = 1_000, Items = { Orb = 10 } },
	CATCHEMALL = { Items = { GreatOrb = 5 } },
	BIGBABA = { Coins = 2_000, Items = { Potion = 5 } },
	STORYTIME = { Coins = 1_500, Items = { Revive = 1 } },
}

-- Community-Raenge: nur aktive Spielzeit zaehlt (wer 2 Minuten nichts tut, gilt als AFK).
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

-- In Studio Kaeufe mit ID 0 simulieren, damit alles testbar ist
Config.StudioFakePurchases = true

---------------------------------------------------------------- Abgeleitete Tabellen

-- Produkt-IDs eintragen (Schluessel = "key" in products.json, z. B. "Pass_VIP" oder "MasterOrb1")
local idsModule = script.Parent:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

return Config
