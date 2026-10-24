-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft.
-- Server-Scripts starten dort nicht automatisch, deshalb startet dieser Test die Services selbst.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local results = {}
local failed = 0
local function check(name, ok, detail)
	if not ok then
		failed += 1
	end
	table.insert(results, (if ok then "PASS " else "FAIL ") .. name .. (if detail then " (" .. tostring(detail) .. ")" else ""))
end

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Units = require(ReplicatedStorage.Shared.Units)

-- Konfiguration
check("Format 1500 -> 1.5K", Format.Number(1500) == "1.5K", Format.Number(1500))
check("Format 100 -> 100", Format.Number(100) == "100", Format.Number(100))
check("Format 2.5M", Format.Number(2_500_000) == "2.5M", Format.Number(2_500_000))
for _, rarity in Config.Rarities do
	local count = 0
	for _, unit in Config.Units do
		if unit.Rarity == rarity.Name then
			count += 1
		end
	end
	check("units for " .. rarity.Name, count > 0, count)
end
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.Id ~= 0 or (pass.ProductId or 0) ~= 0)
end

-- Kreaturen-Codes (Mutation + Fusion)
local first = Config.Units[1]
check("unit code plain", Units.Encode(first.Id) == first.Id)
local golden = Units.Info(Units.Encode(first.Id, "Golden", 0))
check("golden income x2", golden ~= nil and golden.Income == first.Income * 2, golden and golden.Income)
local fused = Units.Info(Units.Encode(first.Id, nil, 2))
check("fusion 2 income", fused ~= nil and math.abs(fused.Income - first.Income * Config.FusionMultiplier ^ 2) < 1e-6, fused and fused.Income)
check("fusion name stars", fused ~= nil and fused.Name:find("★★") ~= nil, fused and fused.Name)
check("legacy code roundtrip", Units.Info(first.Id) ~= nil and Units.Info(first.Id).Code == first.Id)
check("invalid code nil", Units.Info("nope:Bogus:1") == nil)

-- Services laden und starten wie init.server.luau
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ok, err = pcall(function()
	local s = folder.Services
	services.Net = require(s.Net)
	for _, name in { "DataService", "WorldService", "PlotService", "UnitService", "MonetizationService", "CommunityService", "EventService", "SocialService", "LeaderboardService", "ProgressService", "RewardService", "FeatureService" } do
		services[name] = require(s[name])
	end
end)
check("require services", ok, err)

local ORDER = { "DataService", "WorldService", "PlotService", "UnitService", "MonetizationService", "CommunityService", "EventService", "SocialService", "LeaderboardService", "ProgressService", "RewardService", "FeatureService" }
if ok then
	ok, err = pcall(function()
		for _, name in ORDER do
			services[name]:Init(services)
		end
		services.WorldService:Build()
	end)
	check("init + build world", ok, err)
	local plots = services.WorldService.Plots
	check("plots built", #plots >= 8, #plots)
	check("remotes created", ReplicatedStorage:FindFirstChild("Remotes") ~= nil)
	if #plots > 0 then
		local plot = plots[1]
		check("IsInside center", services.WorldService.IsInside(plot, plot.CFrame.Position + Vector3.new(0, 2, 0)))
		check("IsInside far away", not services.WorldService.IsInside(plot, Vector3.new(9999, 0, 9999)))
	end

	-- Jede Kreatur bauen
	local UnitFactory = require(folder.Services.UnitFactory)
	for _, def in Config.Units do
		local info = Units.Info(def.Id)
		local built, model = pcall(UnitFactory.Build, info)
		check("build " .. def.Id, built and model.PrimaryPart ~= nil, if built then nil else model)
		if built then
			pcall(UnitFactory.AddLabel, model, info, "test")
			model:Destroy()
		end
	end
	for _, mutation in Config.Mutations do
		local info = Units.Info(Units.Encode(first.Id, mutation.Name, Config.MaxFusion))
		local built, model = pcall(UnitFactory.Build, info)
		check("build " .. mutation.Name .. " fused", built and model.PrimaryPart ~= nil, if built then nil else model)
		if built then
			model:Destroy()
		end
	end

	ok, err = pcall(function()
		for _, name in ORDER do
			if services[name].Start then
				services[name]:Start()
			end
		end
	end)
	check("start services", ok, err)
	check("event timer set", workspace:GetAttribute("NextEventAt") ~= nil)
	check("leaderboard built", workspace:FindFirstChild("Leaderboard") ~= nil)
	ok, err = pcall(services.EventService.StartParty, services.EventService, 1, "Test")
	check("cash party", ok and services.EventService:IsActive("DoubleCash"), err)
	task.wait(8)
	local belt = workspace:FindFirstChild("BeltUnits")
	local count = belt and #belt:GetChildren() or 0
	check("belt spawns critters", count >= 2, count)
	if belt and count > 0 then
		local first = belt:GetChildren()[1]
		check("belt critter has buy prompt", first.PrimaryPart and first.PrimaryPart:FindFirstChild("BuyPrompt", true) ~= nil)
	end
end

-- Update 2
check("secret rarity", Config.RaritiesByName.Secret ~= nil)
check("offline pro product", (Config.GamePasses.OfflinePro.ProductId or 0) ~= 0)
check("base upgrade cost", Config.BaseUpgradeCost(0) == 5000, Config.BaseUpgradeCost(0))
for _, quest in Config.Quests do
	check("quest text " .. quest.Id, string.format(quest.Text, quest.Goals[1]):find("%d") ~= nil)
end
check("achievement index goal = units", Config.Achievements[13].Goal == #Config.Units, #Config.Units)
if ok then
	check("request remote", ReplicatedStorage.Remotes:FindFirstChild("Request") ~= nil)
	check("sync remote", ReplicatedStorage.Remotes:FindFirstChild("Sync") ~= nil)
	check("rebirth board", workspace:FindFirstChild("RebirthBoard") ~= nil)
	check("thief board", workspace:FindFirstChild("ThiefBoard") ~= nil)
	check("featured critter", Config.UnitsById[workspace:GetAttribute("FeaturedId") or ""] ~= nil, workspace:GetAttribute("FeaturedId"))
	check("server goal", workspace:GetAttribute("GoalTarget") == Config.ServerGoal)
	check("coin folder", workspace:FindFirstChild("RainCoins") ~= nil)
	local goalOk, goalErr = pcall(services.EventService.AddGoalProgress, services.EventService, 1)
	check("goal progress", goalOk and workspace:GetAttribute("GoalProgress") == 1, goalErr)
	local before = #workspace.BeltUnits:GetChildren()
	local spawnOk, spawnErr = pcall(services.UnitService.SpawnBeltUnit, services.UnitService, "Secret")
	check("spawn secret on belt", spawnOk and #workspace.BeltUnits:GetChildren() > before, spawnErr)
	check("happy hour timer", workspace:GetAttribute("HappyHourIn") ~= nil or workspace:GetAttribute("HappyHourEnds") ~= nil)
end

-- Update 3
check("eggs configured", #Config.Eggs == 3)
for _, egg in Config.Eggs do
	for rarity in egg.Weights do
		check("egg rarity " .. egg.Id .. " " .. rarity, Config.RaritiesByName[rarity] ~= nil)
	end
end
check("pass xp", Config.PassXP(0) > 0)
if ok then
	check("gems spawned", workspace:FindFirstChild("Gems") ~= nil and #workspace.Gems:GetChildren() == Config.GemCount)
	check("speed pads", workspace:FindFirstChild("SpeedPads") ~= nil and #workspace.SpeedPads:GetChildren() > 0)
	check("boss timer", workspace:GetAttribute("BossAt") ~= nil)
	check("night timer", workspace:GetAttribute("NightAt") ~= nil)
	local beltBefore = #workspace.BeltUnits:GetChildren()
	local goldOk, goldErr = pcall(services.UnitService.SpawnBeltUnit, services.UnitService, "Epic", "Golden")
	check("golden belt critter", goldOk and #workspace.BeltUnits:GetChildren() > beltBefore, goldErr)
	check("night luck", services.FeatureService:NightLuck() >= 1)
	local multOk, mult = pcall(services.FeatureService.GetMultiplier, services.FeatureService, game:GetService("Players"):GetPlayers()[1] or Instance.new("Folder"))
	check("feature multiplier", multOk and mult == 1, mult)
end

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
