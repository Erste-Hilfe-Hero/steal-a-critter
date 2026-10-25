-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft.
-- Server-Scripts starten dort nicht automatisch, deshalb baut dieser Test die Welt selbst und
-- spielt die Garten-Logik mit einem Test-Spieler (Tabelle statt echtem Player) einmal durch.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local results = {}
local failed = 0
local function check(name, ok, detail)
	if not ok then
		failed += 1
	end
	table.insert(results, (if ok then "PASS " else "FAIL ") .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
end

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

-- Konfiguration
check("Format 1500 -> $1.5K", Format.Cash(1500) == "$1.5K", Format.Cash(1500))
check("Format hours", Format.Time(3700) == "1:01:40", Format.Time(3700))
check("Format minutes", Format.Time(75) == "1:15", Format.Time(75))
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end
for _, seed in Config.Seeds do
	check("seed rarity " .. seed.Id, Config.RaritiesByName[seed.Rarity] ~= nil)
end
check("tile cost start", Config.TileCost(Config.StartTiles) == 150, Config.TileCost(Config.StartTiles))
for _, pet in Config.Pets do
	check("pet pass exists " .. pet.Id, pet.Pass == nil or Config.GamePasses[pet.Pass] ~= nil)
end
for _, reward in Config.WheelRewards do
	check("wheel seed " .. reward.Name, reward.Kind ~= "Seed" or Config.SeedsById[reward.Seed] ~= nil)
end
for code, def in Config.Codes do
	check("code seed " .. code, def.Seed == nil or Config.SeedsById[def.Seed] ~= nil)
end
check("quest pool large enough", #Config.QuestPool >= Config.QuestCount)

-- Services laden
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ok, err = pcall(function()
	for _, name in { "Net", "DataService", "WorldService", "EventService", "GardenService", "MonetizationService", "CommunityService", "ProgressService", "CosmeticService", "LeaderboardService" } do
		services[name] = require(folder.Services[name])
	end
end)
check("require services", ok, err)
if not ok then
	table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
	return table.concat(results, "\n")
end

-- Test-Spieler und Test-Daten (echte Player-Objekte gibt es in der Luau Execution nicht)
local attributes = {}
local player: any = {
	Name = "Tester",
	DisplayName = "Tester",
	UserId = 1,
	MembershipType = Enum.MembershipType.None,
	Character = nil,
}
function player:GetAttribute(key)
	return attributes[key]
end
function player:SetAttribute(key, value)
	attributes[key] = value
end
local data = {
	Coins = 1_000_000,
	Rebirths = 0,
	Seeds = { carrot = 3, strawberry = 2, starfruit = 1 },
	Plants = {},
	Fruits = {},
	Tiles = Config.StartTiles,
	Upgrades = { Sprinkler = 0, Fertilizer = 0 },
	Passes = {},
	TotalEarned = 0,
	PlayTime = 0,
	LastTick = 0,
	DailyDay = 0,
	DailyStreak = 0,
}
local realDataService = services.DataService
services.DataService = {
	Get = function()
		return data
	end,
	UpdateAttributes = function() end,
	AddCoins = function(_, _, amount)
		data.Coins = math.max(0, data.Coins + amount)
		if amount > 0 then
			data.TotalEarned += amount
		end
	end,
}
local announcements = {}
local realNet = services.Net
services.Net = {
	SendNotify = function() end,
	SendAnnounce = function(text)
		table.insert(announcements, text)
	end,
	Effect = { FireClient = function() end },
	-- Fuer Start(): echte Remotes weiterreichen
	BuySeed = realNet.BuySeed,
}

ok, err = pcall(function()
	for _, name in { "WorldService", "EventService", "GardenService", "MonetizationService", "CommunityService", "ProgressService", "CosmeticService", "LeaderboardService" } do
		services[name]:Init(services)
	end
	realDataService:Init(services)
	services.WorldService:Build()
end)
check("init + build world", ok, err)
local plots = services.WorldService.Plots
check("gardens built", #plots >= 4, #plots)
check("36 tiles per garden", plots[1] and #plots[1].Tiles == 36, plots[1] and #plots[1].Tiles)
check("remotes created", ReplicatedStorage:FindFirstChild("Remotes") ~= nil)
check("decoration built", workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Decoration") ~= nil)

ok, err = pcall(services.EventService.Start, services.EventService)
check("event service start", ok, err)
check("restock time set", workspace:GetAttribute("NextRestock") ~= nil)

local garden = services.GardenService
ok, err = pcall(function()
	local plot = garden:Assign(player)
	assert(plot, "no plot")
	garden:RefreshStats(player)
	garden:RefreshAllTiles(player)
end)
check("assign garden", ok, err)

-- Pflanzen, wachsen, ernten
ok, err = pcall(garden.Plant, garden, player, 1, "carrot")
check("plant carrot", ok and data.Plants["1"] ~= nil and data.Seeds.carrot == 2, err)
check("cannot plant missing seed", not garden:Plant(player, 2, "lotus"))
check("harvest unripe fails", not garden:Harvest(player, 1))
data.Plants["1"].Grown = data.Plants["1"].Need
ok, err = pcall(garden.RefreshTile, garden, player, 1)
check("ripe model built", ok and garden:GetPlot(player).Tiles[1].Model ~= nil, err)
ok, err = pcall(garden.Harvest, garden, player, 1)
check("harvest carrot", ok and #data.Fruits == 1 and data.Plants["1"] == nil, err)
garden:Plant(player, 2, "strawberry")
data.Plants["2"].Grown = data.Plants["2"].Need
garden:Harvest(player, 2)
check("strawberry regrows", data.Plants["2"] ~= nil and data.Plants["2"].Need == Config.SeedsById.strawberry.Regrow)

-- Jede Pflanze in jeder Stufe bauen
ok, err = pcall(function()
	for i, seed in Config.Seeds do
		local index = 10 + (i % 8)
		for stage = 0, 4 do
			data.Plants[tostring(index)] = { Id = seed.Id, Grown = seed.Grow * stage / 4, Need = seed.Grow }
			garden:RefreshTile(player, index)
		end
	end
end)
check("build all plant stages", ok, err)

-- Verkaufen
local coinsBefore = data.Coins
local fruitValue = 0
for _, fruit in data.Fruits do
	fruitValue += fruit.Value
end
ok, err = pcall(garden.SellAll, garden, player)
check("sell all", ok and #data.Fruits == 0 and data.Coins == coinsBefore + math.floor(fruitValue * garden:GetSellMultiplier(player)), err)

-- Upgrades, Grow All, Rebirth
ok, err = pcall(garden.BuyUpgrade, garden, player, "Tile")
check("buy tile", ok and data.Tiles == Config.StartTiles + 1, err)
ok, err = pcall(garden.BuyUpgrade, garden, player, "Sprinkler")
check("buy sprinkler", ok and data.Upgrades.Sprinkler == 1, err)
check("growth rate with sprinkler", math.abs(garden:GetGrowthRate(player, false) - 1.1) < 1e-6, garden:GetGrowthRate(player, false))
ok, err = pcall(garden.GrowAll, garden, player)
check("grow all", ok and data.Plants["2"].Grown == data.Plants["2"].Need, err)
data.Coins = Config.RebirthCost(0)
ok, err = pcall(garden.Rebirth, garden, player)
check("rebirth", ok and data.Rebirths == 1 and data.Tiles == Config.StartTiles and next(data.Plants) == nil, err)
local expectedMultiplier = math.floor(1.5 * services.ProgressService:GetValueBonus(player) * 100 + 0.5) / 100
check("rebirth multiplier", garden:GetSellMultiplier(player) == expectedMultiplier, `{garden:GetSellMultiplier(player)} vs {expectedMultiplier}`)

-- Wetter und Golden Hour
ok, err = pcall(services.EventService.StartWeather, services.EventService, "Rain")
check("rain starts", ok and services.EventService:GetWeather() == "Rain" and services.EventService:GetGrowthBonus() == 1.5, err)
ok, err = pcall(services.EventService.StartGoldenHour, services.EventService, 60, player)
check("golden hour", ok and services.EventService:GetGoldenMultiplier() == Config.GoldenHourMultiplier, err)

-- Update 2: Fortschritt, Werkzeuge, Pets, Designs
local progress = services.ProgressService
local cosmetic = services.CosmeticService
check("night flag", type(services.EventService:IsNight()) == "boolean")
check("harvest counted", (data.Stats.Harvest or 0) >= 2, data.Stats.Harvest)
check("index discovered", data.Index.carrot == true and data.Index.strawberry == true)
check("xp or level gained", data.Level > 1 or data.Xp > 0, `{data.Level}/{data.Xp}`)
check("achievement sprout", data.Achievements.sprout == true)
check("first title equipped", data.Title ~= "", data.Title)
check("index value bonus", progress:GetValueBonus(player) >= 1 + 2 * Config.IndexBonusPer - 1e-9, progress:GetValueBonus(player))
check("tutorial advanced", data.Tutorial >= 2, data.Tutorial)

check("three daily quests", #data.Quests.List == Config.QuestCount, #data.Quests.List)
local questIds = {}
for _, quest in data.Quests.List do
	questIds[quest.Id] = true
end
local distinct = 0
for _ in questIds do
	distinct += 1
end
check("quests distinct", distinct == Config.QuestCount, distinct)
data.Quests.List[1].Progress = data.Quests.List[1].Target
local coinsBeforeQuest = data.Coins
ok, err = pcall(progress.ClaimQuest, progress, player, 1)
check("claim quest", ok and data.Quests.List[1].Claimed and data.Coins > coinsBeforeQuest, err)
coinsBeforeQuest = data.Coins
progress:ClaimQuest(player, 1)
check("quest claimed only once", data.Coins == coinsBeforeQuest)
local sync = progress:BuildSync(player)
check("sync payload", sync ~= nil and #sync.Quests == Config.QuestCount and sync.Index.carrot == true)

ok, err = pcall(progress.Spin, progress, player)
check("wheel spin", ok and data.LastSpin > 0, err)
check("wheel cooldown", progress:Spin(player) == nil)

local coinsBeforeCode = data.Coins
check("code redeem", progress:RedeemCode(player, " garden ") and data.Coins == coinsBeforeCode + Config.Codes.GARDEN.Coins)
check("code only once", not progress:RedeemCode(player, "GARDEN"))
check("unknown code", not progress:RedeemCode(player, "NOPE123"))
progress:SetSetting(player, "Sfx", false)
check("setting saved", data.Settings.Sfx == false and attributes.Set_Sfx == false)
progress:SetSetting(player, "Hack", true)
check("unknown setting ignored", data.Settings.Hack == nil)

-- Rucksack-Upgrade
data.Coins = 1_000_000
check("backpack base", garden:BackpackSize(player) == Config.BackpackSize, garden:BackpackSize(player))
garden:BuyUpgrade(player, "Backpack")
check("backpack upgrade", garden:BackpackSize(player) == Config.BackpackSize + Config.BackpackPerLevel, garden:BackpackSize(player))

-- Schaufel und Alles bepflanzen
data.Plants = {}
data.Seeds = { carrot = 3, dragonfruit = 1 }
attributes.SelectedSeed = "carrot"
check("plant all", garden:PlantAll(player) == 3 and data.Seeds.carrot == nil, data.Seeds.carrot)
check("no planting on locked tile", not garden:Plant(player, Config.StartTiles + 5, "dragonfruit"))
check("no planting on used tile", not garden:Plant(player, 1, "dragonfruit"))
check("dig common", garden:Dig(player, 1) and data.Plants["1"] == nil)
garden:Plant(player, 1, "dragonfruit")
check("dig legendary needs confirm", not garden:Dig(player, 1) and data.Plants["1"] ~= nil)
check("dig legendary confirmed", garden:Dig(player, 1) and data.Plants["1"] == nil)

-- Pets und Designs
data.Coins = 10_000_000
local growthBefore = garden:GetGrowthRate(player, false)
ok, err = pcall(cosmetic.BuyPet, cosmetic, player, "bee")
check("buy pet", ok and data.Pets.bee == true and data.Pet == "bee", err)
check("pet growth bonus", math.abs(garden:GetGrowthRate(player, false) - growthBefore * 1.1) < 1e-6, garden:GetGrowthRate(player, false))
pcall(cosmetic.BuyPet, cosmetic, player, "unicorn") -- loest beim Test-Spieler keinen echten Kauf aus
check("robux pet not free", data.Pet == "bee" and data.Pets.unicorn == nil)
ok, err = pcall(cosmetic.BuySkin, cosmetic, player, "sakura")
check("buy skin", ok and data.Skins.sakura == true and plots[1].Model.Floor.Color == Config.SkinsById.sakura.Floor, err)
cosmetic:BuySkin(player, "midnight")
check("level skin locked", data.Skins.midnight == nil)
cosmetic:ApplySkin(plots[1], "classic")
check("skin reset", plots[1].Model.Floor.Color == Config.SkinsById.classic.Floor)

ok, err = pcall(garden.Release, garden, player)
check("release garden", ok and plots[1].Owner == nil, err)

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
