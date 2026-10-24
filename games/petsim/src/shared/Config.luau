-- Zentrale Spiel- und Monetarisierungs-Einstellungen.
-- Produkt-IDs werden von der Action "Create pet sim products" angelegt und hier eingetragen.
-- Solange eine ID 0 ist, kann man den Kauf in Studio ueber den Shop simulieren.

local Config = {}

Config.DataStoreName = "PetSimData_v1"

-- Wirtschaft
Config.StartCoins = 0
Config.StarterPet = "puff" -- jeder Neue bekommt ein Haustier geschenkt
Config.BaseEquip = 3
Config.ExtraEquipAmount = 3
Config.MaxStorage = 75
Config.GoldenCraftAmount = 5 -- 5 gleiche Haustiere -> 1 goldenes
Config.GoldenMultiplier = 3
Config.DamageTick = 0.25 -- Sekunden
Config.AutoTargetRange = 28 -- Haustiere greifen automatisch Sachen in der Naehe an
Config.TapRange = 90
Config.HatchCooldown = 1.2
Config.AutoHatchInterval = 2.5
Config.EggRange = 14

-- Multiplikatoren
Config.RebirthMultiplierPer = 0.5
Config.VipMultiplier = 1.5
Config.DoubleCoinsMultiplier = 2
Config.BoostMultiplier = 2 -- 30-Minuten-Boost
Config.PremiumMultiplier = 1.2 -- belohnt Premium-Spieler, erhoeht die Premium Payouts
Config.LuckyMultiplier = 1.5 -- Lucky-Pass: Gewichte ab "Rare"
Config.ServerLuckMultiplier = 2 -- Server-Glueck: Gewichte ab "Rare" fuer alle
Config.DefaultWalkSpeed = 16
Config.SpeedWalkSpeed = 26

function Config.RebirthCost(rebirths: number): number
	return math.floor(1_000_000_000 * 3 ^ rebirths)
end

Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 200), Scale = 1.6, Material = Enum.Material.SmoothPlastic },
	{ Name = "Uncommon", Color = Color3.fromRGB(85, 220, 110), Scale = 1.8, Material = Enum.Material.SmoothPlastic },
	{ Name = "Rare", Color = Color3.fromRGB(70, 150, 255), Scale = 2, Material = Enum.Material.SmoothPlastic, Lucky = true },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255), Scale = 2.2, Material = Enum.Material.Glass, Lucky = true },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), Scale = 2.5, Material = Enum.Material.Neon, Lucky = true, Crown = true, Announce = true },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 60, 90), Scale = 2.9, Material = Enum.Material.Neon, Lucky = true, Crown = true, Sparkles = true, Announce = true },
}

-- Zonen liegen hintereinander entlang +X. Jede Zone hat ein Tor (ausser Zone 1) und ein Ei.
-- HpScale/RewardScale skalieren die Sachen, die man dort zerstoert.
Config.ZoneWidth = 140
Config.Zones = {
	{ Name = "Sunny Meadow", GateCost = 0, HpScale = 1, RewardScale = 1, Ground = Color3.fromRGB(100, 190, 80), Material = Enum.Material.Grass },
	{ Name = "Dusty Desert", GateCost = 2_000, HpScale = 6, RewardScale = 12, Ground = Color3.fromRGB(230, 200, 120), Material = Enum.Material.Sand },
	{ Name = "Frosty Peaks", GateCost = 40_000, HpScale = 36, RewardScale = 144, Ground = Color3.fromRGB(235, 245, 255), Material = Enum.Material.Snow },
	{ Name = "Lava Land", GateCost = 700_000, HpScale = 216, RewardScale = 1_728, Ground = Color3.fromRGB(90, 40, 30), Material = Enum.Material.Basalt },
	{ Name = "Candy Clouds", GateCost = 12_000_000, HpScale = 1_296, RewardScale = 20_736, Ground = Color3.fromRGB(255, 170, 220), Material = Enum.Material.SmoothPlastic },
	{ Name = "Star Station", GateCost = 200_000_000, HpScale = 7_776, RewardScale = 248_832, Ground = Color3.fromRGB(40, 40, 70), Material = Enum.Material.Metal },
}

-- Sachen zum Zerstoeren (Werte fuer Zone 1, werden pro Zone skaliert)
Config.Breakables = {
	{ Id = "pile", Name = "Coin Pile", Hp = 5, Reward = 8, Weight = 70, Size = 3, Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "chest", Name = "Chest", Hp = 40, Reward = 60, Weight = 25, Size = 4.5, Color = Color3.fromRGB(160, 100, 50) },
	{ Id = "vault", Name = "Vault", Hp = 300, Reward = 500, Weight = 5, Size = 6.5, Color = Color3.fromRGB(120, 130, 150) },
}
Config.BreakablesPerZone = 22
Config.RespawnTime = 4

-- Eigene Haustiere (keine fremden Assets). Power = Schaden pro Sekunde.
-- Shape: "Ball" oder "Block". Ears/Tail/Wings/Horn fuer etwas Abwechslung.
Config.Pets = {
	{ Id = "puff", Name = "Puff Pup", Rarity = "Common", Power = 2, Color = Color3.fromRGB(240, 220, 190), Shape = "Ball", Ears = true },
	{ Id = "kit", Name = "Kitty Bun", Rarity = "Common", Power = 2.5, Color = Color3.fromRGB(255, 170, 90), Shape = "Ball", Ears = true, Tail = true },
	{ Id = "hop", Name = "Hoppy Frog", Rarity = "Uncommon", Power = 3.5, Color = Color3.fromRGB(80, 210, 100), Shape = "Ball" },
	{ Id = "bee", Name = "Buzzy Bee", Rarity = "Rare", Power = 5.5, Color = Color3.fromRGB(255, 220, 40), Shape = "Ball", Wings = true },
	{ Id = "fox", Name = "Sunny Fox", Rarity = "Epic", Power = 9, Color = Color3.fromRGB(255, 120, 40), Shape = "Block", Ears = true, Tail = true },
	{ Id = "unicorn", Name = "Meadow Unicorn", Rarity = "Legendary", Power = 16, Color = Color3.fromRGB(255, 240, 255), Shape = "Block", Horn = true, Wings = true },

	{ Id = "camel", Name = "Chill Camel", Rarity = "Common", Power = 12, Color = Color3.fromRGB(210, 170, 110), Shape = "Block" },
	{ Id = "scorp", Name = "Scorpi", Rarity = "Uncommon", Power = 20, Color = Color3.fromRGB(180, 60, 40), Shape = "Block", Tail = true },
	{ Id = "cactus", Name = "Cactus Cub", Rarity = "Rare", Power = 32, Color = Color3.fromRGB(60, 160, 70), Shape = "Block", Ears = true },
	{ Id = "sphinx", Name = "Sand Sphinx", Rarity = "Epic", Power = 55, Color = Color3.fromRGB(240, 210, 120), Shape = "Block", Ears = true, Wings = true },
	{ Id = "sunbird", Name = "Sun Phoenix", Rarity = "Legendary", Power = 95, Color = Color3.fromRGB(255, 150, 30), Shape = "Ball", Wings = true, Tail = true },

	{ Id = "peng", Name = "Pingu Pal", Rarity = "Common", Power = 70, Color = Color3.fromRGB(40, 40, 60), Shape = "Ball" },
	{ Id = "seal", Name = "Snow Seal", Rarity = "Uncommon", Power = 115, Color = Color3.fromRGB(200, 210, 230), Shape = "Ball", Tail = true },
	{ Id = "yeti", Name = "Baby Yeti", Rarity = "Rare", Power = 190, Color = Color3.fromRGB(230, 240, 255), Shape = "Block", Horn = true },
	{ Id = "frostfox", Name = "Frost Fox", Rarity = "Epic", Power = 320, Color = Color3.fromRGB(150, 220, 255), Shape = "Block", Ears = true, Tail = true },
	{ Id = "icedragon", Name = "Ice Dragon", Rarity = "Legendary", Power = 560, Color = Color3.fromRGB(110, 190, 255), Shape = "Block", Horn = true, Wings = true, Tail = true },

	{ Id = "ember", Name = "Ember Slime", Rarity = "Common", Power = 420, Color = Color3.fromRGB(255, 90, 40), Shape = "Ball" },
	{ Id = "magma", Name = "Magma Mole", Rarity = "Uncommon", Power = 690, Color = Color3.fromRGB(140, 60, 40), Shape = "Ball", Ears = true },
	{ Id = "salamander", Name = "Fire Newt", Rarity = "Rare", Power = 1_150, Color = Color3.fromRGB(255, 60, 30), Shape = "Block", Tail = true },
	{ Id = "hellhound", Name = "Lava Hound", Rarity = "Epic", Power = 1_900, Color = Color3.fromRGB(60, 20, 20), Shape = "Block", Ears = true, Tail = true, Horn = true },
	{ Id = "phoenix", Name = "Inferno Phoenix", Rarity = "Legendary", Power = 3_300, Color = Color3.fromRGB(255, 70, 20), Shape = "Ball", Wings = true, Tail = true },

	{ Id = "gummy", Name = "Gummy Bear", Rarity = "Common", Power = 2_500, Color = Color3.fromRGB(255, 80, 120), Shape = "Ball", Ears = true },
	{ Id = "donut", Name = "Donut Dog", Rarity = "Uncommon", Power = 4_100, Color = Color3.fromRGB(255, 190, 220), Shape = "Ball", Ears = true, Tail = true },
	{ Id = "lolli", Name = "Lolli Lamb", Rarity = "Rare", Power = 6_800, Color = Color3.fromRGB(255, 255, 255), Shape = "Ball", Horn = true },
	{ Id = "cottoncat", Name = "Cotton Candy Cat", Rarity = "Epic", Power = 11_500, Color = Color3.fromRGB(190, 160, 255), Shape = "Ball", Ears = true, Tail = true, Wings = true },
	{ Id = "candycorn", Name = "Candy Pegasus", Rarity = "Legendary", Power = 20_000, Color = Color3.fromRGB(255, 120, 200), Shape = "Block", Horn = true, Wings = true },

	{ Id = "astro", Name = "Astro Pup", Rarity = "Common", Power = 15_000, Color = Color3.fromRGB(220, 220, 230), Shape = "Ball", Ears = true },
	{ Id = "alien", Name = "Blip Alien", Rarity = "Uncommon", Power = 25_000, Color = Color3.fromRGB(120, 255, 120), Shape = "Ball", Horn = true },
	{ Id = "robot", Name = "Robo Cat", Rarity = "Rare", Power = 41_000, Color = Color3.fromRGB(160, 170, 190), Shape = "Block", Ears = true, Tail = true },
	{ Id = "nebula", Name = "Nebula Owl", Rarity = "Epic", Power = 70_000, Color = Color3.fromRGB(110, 60, 220), Shape = "Ball", Wings = true },
	{ Id = "comet", Name = "Comet Dragon", Rarity = "Legendary", Power = 120_000, Color = Color3.fromRGB(60, 200, 255), Shape = "Block", Horn = true, Wings = true, Tail = true },
	{ Id = "cosmic", Name = "Cosmic Overlord", Rarity = "Mythic", Power = 400_000, Color = Color3.fromRGB(255, 60, 160), Shape = "Block", Horn = true, Wings = true, Tail = true, Ears = true },
}

-- Eier: werden NUR mit Muenzen gekauft (nie direkt mit Robux). Die Chancen stehen sichtbar am Ei.
-- Chance = Gewicht in Prozent (Summe 100).
Config.Eggs = {
	{ Id = "meadow", Name = "Meadow Egg", Zone = 1, Price = 150, Color = Color3.fromRGB(150, 230, 120), Pets = {
		{ Pet = "puff", Chance = 45 }, { Pet = "kit", Chance = 30 }, { Pet = "hop", Chance = 17 }, { Pet = "bee", Chance = 6 }, { Pet = "fox", Chance = 1.8 }, { Pet = "unicorn", Chance = 0.2 },
	} },
	{ Id = "desert", Name = "Desert Egg", Zone = 2, Price = 2_500, Color = Color3.fromRGB(240, 200, 110), Pets = {
		{ Pet = "camel", Chance = 55 }, { Pet = "scorp", Chance = 30 }, { Pet = "cactus", Chance = 12 }, { Pet = "sphinx", Chance = 2.7 }, { Pet = "sunbird", Chance = 0.3 },
	} },
	{ Id = "frost", Name = "Frost Egg", Zone = 3, Price = 40_000, Color = Color3.fromRGB(170, 220, 255), Pets = {
		{ Pet = "peng", Chance = 55 }, { Pet = "seal", Chance = 30 }, { Pet = "yeti", Chance = 12 }, { Pet = "frostfox", Chance = 2.7 }, { Pet = "icedragon", Chance = 0.3 },
	} },
	{ Id = "lava", Name = "Lava Egg", Zone = 4, Price = 600_000, Color = Color3.fromRGB(255, 90, 40), Pets = {
		{ Pet = "ember", Chance = 55 }, { Pet = "magma", Chance = 30 }, { Pet = "salamander", Chance = 12 }, { Pet = "hellhound", Chance = 2.7 }, { Pet = "phoenix", Chance = 0.3 },
	} },
	{ Id = "candy", Name = "Candy Egg", Zone = 5, Price = 9_000_000, Color = Color3.fromRGB(255, 150, 210), Pets = {
		{ Pet = "gummy", Chance = 55 }, { Pet = "donut", Chance = 30 }, { Pet = "lolli", Chance = 12 }, { Pet = "cottoncat", Chance = 2.7 }, { Pet = "candycorn", Chance = 0.3 },
	} },
	{ Id = "space", Name = "Space Egg", Zone = 6, Price = 150_000_000, Color = Color3.fromRGB(90, 70, 200), Pets = {
		{ Pet = "astro", Chance = 55 }, { Pet = "alien", Chance = 30 }, { Pet = "robot", Chance = 11.7 }, { Pet = "nebula", Chance = 2.7 }, { Pet = "comet", Chance = 0.55 }, { Pet = "cosmic", Chance = 0.05 },
	} },
}

-- Gamepasses: einmal kaufen, fuer immer behalten. PriceHint = empfohlener Preis in Robux.
-- Id = echte Gamepass-ID (optional). ProductId = Developer Product, das dauerhaft gespeichert wird.
-- AffectsRandom: veraendert Zufallsergebnisse -> in Laendern mit Lootbox-Verbot (PolicyService) ausgeblendet.
Config.GamePasses = {
	VIP = { Id = 0, ProductId = 0, Name = "VIP", Description = "x1.5 coins forever + VIP chat tag", PriceHint = 249, Order = 1 },
	DoubleCoins = { Id = 0, ProductId = 0, Name = "2x Coins", Description = "Double all coins forever", PriceHint = 399, Order = 2 },
	TripleHatch = { Id = 0, ProductId = 0, Name = "Triple Hatch", Description = "Open 3 eggs at once", PriceHint = 349, Order = 3 },
	AutoHatch = { Id = 0, ProductId = 0, Name = "Auto Hatch", Description = "Hatch eggs automatically while you stand next to them", PriceHint = 299, Order = 4 },
	MorePets = { Id = 0, ProductId = 0, Name = "+3 Pets Equipped", Description = "Equip 6 pets instead of 3", PriceHint = 299, Order = 5 },
	Lucky = { Id = 0, ProductId = 0, Name = "Lucky", Description = "x1.5 chance for Rare and better pets", PriceHint = 249, Order = 6, AffectsRandom = true },
	Speed = { Id = 0, ProductId = 0, Name = "Speed", Description = "Run faster forever", PriceHint = 99, Order = 7 },
}

-- Developer Products: beliebig oft kaufbar.
-- Muenz-Pakete skalieren mit dem Ei der besten freigeschalteten Zone, damit sie nie wertlos werden.
Config.DevProducts = {
	CoinsSmall = { Id = 0, Kind = "Coins", Eggs = 4, Name = "Coin Bag", Description = "Coins for about 4 eggs of your best zone", PriceHint = 49, Order = 1, AffectsRandom = true },
	CoinsMedium = { Id = 0, Kind = "Coins", Eggs = 20, Name = "Coin Chest", Description = "Coins for about 20 eggs of your best zone", PriceHint = 199, Order = 2, AffectsRandom = true },
	CoinsLarge = { Id = 0, Kind = "Coins", Eggs = 80, Name = "Coin Vault", Description = "Coins for about 80 eggs of your best zone", PriceHint = 699, Order = 3, AffectsRandom = true },
	CoinBoost = { Id = 0, Kind = "Boost", Seconds = 1800, Name = "2x Coins (30 min)", Description = "Double coins for 30 minutes", PriceHint = 79, Order = 4 },
	ServerLuck = { Id = 0, Kind = "ServerLuck", Seconds = 900, Name = "Server Luck x2", Description = "15 min: rare pets x2 more likely for EVERYONE", PriceHint = 199, Order = 5, AffectsRandom = true },
	PetStorage = { Id = 0, Kind = "Storage", Amount = 50, Name = "+50 Pet Storage", Description = "Keep 50 more pets in your inventory", PriceHint = 99, Order = 6 },
}

-- Taegliches Geschenk: Muenzen fuer so viele Eier der besten Zone
Config.DailyEggs = 2

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

-- Lookup-Tabellen
Config.PetsById = {}
for _, pet in Config.Pets do
	Config.PetsById[pet.Id] = pet
end

Config.RaritiesByName = {}
for index, rarity in Config.Rarities do
	rarity.Index = index
	Config.RaritiesByName[rarity.Name] = rarity
end

Config.EggsById = {}
Config.EggByZone = {}
for _, egg in Config.Eggs do
	Config.EggsById[egg.Id] = egg
	Config.EggByZone[egg.Zone] = egg
end

Config.BreakablesById = {}
for _, breakable in Config.Breakables do
	Config.BreakablesById[breakable.Id] = breakable
end

function Config.PetPower(typeId: string, golden: boolean?): number
	local def = Config.PetsById[typeId]
	if not def then
		return 0
	end
	return def.Power * (if golden then Config.GoldenMultiplier else 1)
end

-- Chancen eines Eis mit Glueck: Gewichte ab "Rare" werden multipliziert, danach auf 100 % normiert
function Config.EggOdds(egg, luck: number): { { Pet: string, Chance: number } }
	local total = 0
	local weighted = {}
	for _, entry in egg.Pets do
		local rarity = Config.RaritiesByName[Config.PetsById[entry.Pet].Rarity]
		local weight = entry.Chance * (if rarity.Lucky then luck else 1)
		total += weight
		table.insert(weighted, { Pet = entry.Pet, Chance = weight })
	end
	for _, entry in weighted do
		entry.Chance = entry.Chance / total * 100
	end
	return weighted
end

return Config
