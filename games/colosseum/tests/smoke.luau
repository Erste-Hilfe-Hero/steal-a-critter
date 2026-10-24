-- Smoke-Test fuer Colosseum Catcher, laeuft per Open Cloud Luau Execution im hochgeladenen Place.
-- Server-Scripts starten dort nicht automatisch, deshalb startet dieser Test die Services selbst.
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
local BeastModel = require(ReplicatedStorage.Shared.BeastModel)

-- Konfiguration
check("Format 1500 -> 1.5K", Format.Number(1500) == "1.5K", Format.Number(1500))
check("24 beasts", #Config.Beasts == 24, #Config.Beasts)
for _, beast in Config.Beasts do
	check("beast type " .. beast.Id, Config.Types[beast.Type] ~= nil)
	check("beast rarity " .. beast.Id, Config.RaritiesByName[beast.Rarity] ~= nil)
	if beast.Evolve then
		check("evolve target " .. beast.Id, Config.BeastsById[beast.Evolve.To] ~= nil)
	end
	local ok, model = pcall(BeastModel.Build, beast.Id, 20, false)
	check("model " .. beast.Id, ok and model.PrimaryPart ~= nil, if ok then nil else model)
	local okShiny = pcall(BeastModel.Build, beast.Id, 40, true)
	check("prismatic model " .. beast.Id, okShiny)
end
for _, zone in Config.Zones do
	for _, spawn in zone.Spawns do
		check("spawn " .. zone.Name .. " " .. spawn.Beast, Config.BeastsById[spawn.Beast] ~= nil)
	end
end
for _, champion in Config.Champions do
	for _, member in champion.Team do
		check("champion beast " .. member[1], Config.BeastsById[member[1]] ~= nil)
	end
end
check("fire beats leaf", Config.TypeMultiplier("Fire", "Leaf") == Config.SuperEffective)
check("fire weak vs water", Config.TypeMultiplier("Fire", "Water") == Config.NotEffective)
check("shadow vs light", Config.TypeMultiplier("Shadow", "Light") == Config.SuperEffective)
check("light vs shadow", Config.TypeMultiplier("Light", "Shadow") == Config.SuperEffective)
check("normal neutral", Config.TypeMultiplier("Normal", "Stone") == 1)
check("master orb always", Config.CatchChance("voidrake", 1, math.huge, 1) == 1)
local low = Config.CatchChance("cindercub", 0.1, 1, 1)
local high = Config.CatchChance("cindercub", 1, 1, 1)
check("low hp easier to catch", low > high, `{low} > {high}`)
check("ultimate at lv25", table.find(Config.MovesFor("cindercub", 25), "Ultimate") ~= nil)
check("no ultimate at lv5", table.find(Config.MovesFor("cindercub", 5), "Ultimate") == nil)
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.Id ~= 0 or pass.ProductId ~= 0)
end

-- Services laden und starten wie init.server.luau
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ORDER = { "DataService", "WorldService", "BeastService", "BattleService", "WildService", "MonetizationService", "RewardService", "LeaderboardService", "CommunityService" }
local ok, err = pcall(function()
	local s = folder.Services
	services.Net = require(s.Net)
	for _, name in ORDER do
		services[name] = require(s[name])
	end
	for _, name in ORDER do
		services[name]:Init(services)
	end
	services.WorldService:Build()
	for _, name in ORDER do
		if services[name].Start then
			services[name]:Start()
		end
	end
end)
check("services start", ok, err)

if ok then
	check("world built", workspace:FindFirstChild("World") ~= nil)
	check("colosseum built", workspace.World:FindFirstChild("Colosseum") ~= nil)
	local wild = workspace:FindFirstChild("Wild")
	local expected = #Config.Zones * Config.WildPerZone
	check("wild beasts spawned", wild ~= nil and #wild:GetChildren() == expected, wild and #wild:GetChildren())
	check("spring position", services.WorldService.SpringPosition ~= nil)
	local slot = services.WorldService:ClaimArenaSlot(nil)
	check("arena slot", slot ~= nil)
	if slot then
		services.WorldService:ReleaseArenaSlot(slot)
	end
	check("gate tagged", #game:GetService("CollectionService"):GetTagged("ZoneGate") == #Config.Zones - 1)

	-- Kampf zwischen zwei Computer-Seiten bis zum Ende simulieren
	local internal = services.BattleService._Internal
	for round = 1, 20 do
		local a = internal.AiSide("A", { { "cindercub", 10 }, { "puddlit", 12 } }, CFrame.new())
		local b = internal.AiSide("B", { { "sproutling", 11 }, { "zapkit", 10 } }, CFrame.new(0, 0, -20))
		local battle = { Id = round, Kind = "Champion", Sides = { a, b }, Turn = 0, Coins = 0, Folder = Instance.new("Folder") }
		local turns = 0
		while not battle.Winner and turns < 80 do
			turns += 1
			for index, side in battle.Sides do
				local other = battle.Sides[3 - index]
				side.Action = { Kind = "Move", Key = internal.BestMove(side.Fighters[side.Active], other.Fighters[other.Active], 0.5) }
			end
			internal.ResolveTurn(battle)
		end
		if round == 1 then
			check("battle ends", battle.Winner ~= nil, `{turns} turns`)
			check("battle length sane", turns >= 3 and turns <= 30, turns)
		elseif not battle.Winner then
			check("battle ends round " .. round, false, turns)
		end
		battle.Folder:Destroy()
	end
	-- Gauntlet: Welle 2 wird automatisch nachgeschoben
	local a = internal.AiSide("A", { { "infernox", 60 } }, CFrame.new())
	local b = internal.AiSide("Wave", internal.GauntletTeam(1), CFrame.new(0, 0, -20))
	local folderG = Instance.new("Folder")
	folderG.Parent = workspace
	local gauntlet = { Id = 99, Kind = "Gauntlet", Sides = { a, b }, Turn = 0, Coins = 0, Wave = 1, WavesWon = 0, Folder = folderG }
	for _ = 1, 30 do
		a.Action = { Kind = "Move", Key = "Ultimate" }
		b.Action = { Kind = "Move", Key = "Strike" }
		internal.ResolveTurn(gauntlet)
		if gauntlet.Wave >= 3 or gauntlet.Winner then
			break
		end
	end
	check("gauntlet waves advance", gauntlet.Wave >= 2, gauntlet.Wave)
	check("gauntlet coins", gauntlet.Coins > 0, gauntlet.Coins)
	folderG:Destroy()
	local damage = internal.ComputeDamage(internal.MakeFighter("cindercub", 10), internal.MakeFighter("sproutling", 10), "Fire")
	check("damage positive", damage >= 0, damage)
end

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
