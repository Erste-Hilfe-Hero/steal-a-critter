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

-- Services laden
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ok, err = pcall(function()
	for _, name in { "Net", "DataService", "WorldService", "EventService", "GardenService", "MonetizationService", "CommunityService" } do
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
	for _, name in { "WorldService", "EventService", "GardenService", "MonetizationService", "CommunityService" } do
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
check("rebirth multiplier", garden:GetSellMultiplier(player) == 1.5, garden:GetSellMultiplier(player))

-- Wetter und Golden Hour
ok, err = pcall(services.EventService.StartWeather, services.EventService, "Rain")
check("rain starts", ok and services.EventService:GetWeather() == "Rain" and services.EventService:GetGrowthBonus() == 1.5, err)
ok, err = pcall(services.EventService.StartGoldenHour, services.EventService, 60, player)
check("golden hour", ok and services.EventService:GetGoldenMultiplier() == Config.GoldenHourMultiplier, err)

ok, err = pcall(garden.Release, garden, player)
check("release garden", ok and plots[1].Owner == nil, err)

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
