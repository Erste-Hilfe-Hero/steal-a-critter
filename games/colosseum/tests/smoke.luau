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

local Story = require(ReplicatedStorage.Shared.Story)
local Beasts = require(ReplicatedStorage.Shared.Beasts)
local CollectionService = game:GetService("CollectionService")

-- Konfiguration
check("Format 1500 -> 1.5K", Format.Number(1500) == "1.5K", Format.Number(1500))
check("50 beasts", #Config.Beasts == 50, #Config.Beasts)
for _, beast in Config.Beasts do
	check("beast type " .. beast.Id, Config.Types[beast.Type] ~= nil and (beast.Type2 == nil or Config.Types[beast.Type2] ~= nil))
	check("beast rarity " .. beast.Id, Config.RaritiesByName[beast.Rarity] ~= nil)
	if beast.Evolve then
		check("evolve target " .. beast.Id, Config.BeastsById[beast.Evolve.To] ~= nil)
	end
	local moves = Beasts.DefaultMoves(beast.Id, 50)
	check("moves " .. beast.Id, #moves >= 1 and #moves <= Config.MaxMoves, #moves)
	for _, key in moves do
		check("move exists " .. key, Config.Moves[key] ~= nil)
	end
	local ok, model = pcall(BeastModel.Build, beast.Id, 20, false)
	check("model " .. beast.Id, ok and model.PrimaryPart ~= nil, if ok then nil else model)
	local okShiny = pcall(BeastModel.Build, beast.Id, 40, true)
	check("prismatic model " .. beast.Id, okShiny)
end
local function checkTeam(name: string, team)
	for _, member in team do
		check(name .. " beast " .. tostring(member[1]), Config.BeastsById[member[1]] ~= nil)
	end
end
for _, area in Story.Areas do
	if area.Wild then
		for _, entry in area.Wild do
			check("wild " .. area.Id .. " " .. entry[1], Config.BeastsById[entry[1]] ~= nil)
		end
	end
end
for _, leader in Story.Leaders do
	checkTeam("leader " .. leader.Name, leader.Team)
end
for _, elite in Story.Elite do
	checkTeam("elite " .. elite.Name, elite.Team)
end
for _, trainer in Story.Trainers do
	checkTeam("trainer " .. trainer.Id, trainer.Team or {})
end
for stage = 1, 4 do
	checkTeam("rival " .. stage, Story.RivalTeam(stage, "cindercub"))
end
for _, legend in Story.Legends do
	check("legend " .. legend.Beast, Config.BeastsById[legend.Beast] ~= nil)
end
check("8 leaders", #Story.Leaders == 8, #Story.Leaders)
check("champion last", Story.Elite[#Story.Elite].Id == "champion")
check("objective start", typeof(Story.Objective({}, 0)) == "string")
check("fire beats leaf", Config.Effectiveness("Fire", "sproutling") > 1)
check("fire weak vs water", Config.Effectiveness("Fire", "puddlit") < 1)
check("shadow vs light", Beasts.TypeMultiplier("Shadow", "Light") > 1)
check("spark immune stone", Beasts.TypeMultiplier("Spark", "Stone") == 0)
check("master orb always", Beasts.CatchChance("cindercub", 1, 100, nil, math.huge, 1) == 1)
local low = Beasts.CatchChance("cindercub", 5, 100, nil, 1, 1)
local high = Beasts.CatchChance("cindercub", 100, 100, nil, 1, 1)
check("low hp easier to catch", low > high, `{low} > {high}`)
local asleep = Beasts.CatchChance("cindercub", 100, 100, "Sleep", 1, 1)
check("status helps catch", asleep > high, `{asleep} > {high}`)
check("xp curve grows", Config.XpToNext(30) > Config.XpToNext(5))
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
local ORDER = { "DataService", "WorldService", "BeastService", "BattleService", "StoryService", "EncounterService", "MonetizationService", "RewardService", "LeaderboardService", "CommunityService" }
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
	services.StoryService:Build()
	for _, name in ORDER do
		if services[name].Start then
			services[name]:Start()
		end
	end
end)
check("services start", ok, err)

if ok then
	check("world built", workspace:FindFirstChild("World") ~= nil)
	check("npcs built", workspace:FindFirstChild("Npcs") ~= nil and #workspace.Npcs:GetChildren() > 20, workspace:FindFirstChild("Npcs") and #workspace.Npcs:GetChildren())
	check("tall grass", #CollectionService:GetTagged("TallGrass") > 20, #CollectionService:GetTagged("TallGrass"))
	check("story gates", #CollectionService:GetTagged("StoryGate") >= 8, #CollectionService:GetTagged("StoryGate"))
	local models = services.StoryService._Internal.TrainerModels
	for _, trainer in Story.Trainers do
		check("trainer placed " .. trainer.Id, models[trainer.Id] ~= nil)
	end
	for _, area in Story.Areas do
		if area.Kind == "Town" then
			local landing = services.WorldService:LandingFor(area.Id)
			check("landing " .. area.Id, typeof(landing) == "CFrame")
			check("area at " .. area.Id, Story.AreaAt(landing.Position) ~= nil)
		elseif area.Wild then
			local beastId, level = services.EncounterService.Pick(area)
			check("encounter " .. area.Id, Config.BeastsById[beastId] ~= nil and level >= area.Levels[1] and level <= area.Levels[2])
		end
	end

	-- Kampf zwischen zwei Computer-Seiten bis zum Ende simulieren
	local internal = services.BattleService._Internal
	local function switchFainted(side)
		local fighter = side.Fighters[side.Active]
		if fighter.Hp <= 0 then
			for index, other in side.Fighters do
				if other.Hp > 0 then
					side.Active = index
					return
				end
			end
		end
	end
	for round = 1, 20 do
		local a = internal.AiSide("A", { { "cindercub", 10 }, { "puddlit", 12 } }, CFrame.new())
		local b = internal.AiSide("B", { { "sproutling", 11 }, { "zapkit", 10 } }, CFrame.new(0, 0, -20))
		local battle = { Id = round, Kind = "Trainer", Sides = { a, b }, Turn = 0, Coins = 0, Events = {}, Caught = nil }
		local turns = 0
		while not battle.Winner and turns < 80 do
			turns += 1
			battle.Turn = turns
			for index in battle.Sides do
				battle.Sides[index].Action = internal.AiAction(battle, index)
			end
			internal.ResolveTurn(battle)
			switchFainted(a)
			switchFainted(b)
		end
		if round == 1 then
			check("battle ends", battle.Winner ~= nil, `{turns} turns`)
			check("battle length sane", turns >= 2 and turns <= 40, turns)
		elseif not battle.Winner then
			check("battle ends round " .. round, false, turns)
		end
	end
	-- Eigene Kampf-Szene: Podeste weit weg von der Welt, Platz wird wieder frei
	local BattleStage = require(folder.Services.BattleStage)
	for _, style in { "Nature", "Arena", "League", "Shrine", "Colosseum" } do
		local holder = Instance.new("Folder")
		holder.Parent = workspace
		local okStage, slot, ally, enemy = pcall(BattleStage.Build, holder, { Style = style, Theme = Story.Areas[2].Theme, Color = Color3.new(1, 0, 0) })
		check("stage " .. style, okStage and typeof(ally) == "CFrame" and typeof(enemy) == "CFrame", if okStage then nil else slot)
		if okStage then
			check("stage pads apart " .. style, (ally.Position - enemy.Position).Magnitude > 10)
			check("stage far from world " .. style, ally.Position.Magnitude > 3000)
			check("stage built " .. style, #holder.Stage:GetChildren() > 20, #holder.Stage:GetChildren())
			BattleStage.Release(slot)
		end
		holder:Destroy()
	end
	local wave = internal.GauntletTeam(5)
	check("gauntlet team", #wave >= 1, #wave)
	local damage = internal.ComputeDamage(internal.MakeFighter("cindercub", 10), internal.MakeFighter("sproutling", 10), "Ember")
	check("damage positive", damage > 0, damage)
end

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
