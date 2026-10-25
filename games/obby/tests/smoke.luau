-- Smoke-Test fuer Mega Rainbow Obby, laeuft per Open Cloud Luau Execution im echten Place.
-- Server-Scripts starten dort nicht automatisch, deshalb startet dieser Test die Services selbst.
local CollectionService = game:GetService("CollectionService")
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

-- Konfiguration
check("100 stages", Config.StageCount == 100, Config.StageCount)
check("world of stage 1", select(2, Config.WorldForStage(1)) == 1)
check("world of stage 100", select(2, Config.WorldForStage(100)) == 10)
for key, product in Config.DevProducts do
	-- Neue Produkte (Id = 0) werden zur Laufzeit ueber den Namen gefunden (Pruefung weiter unten)
	if product.Id ~= 0 or product.Kind ~= "Coins" then
		check("product id " .. key, product.Id ~= 0, product.Id)
	end
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end
local noPass = function()
	return false
end
check("trail stage 10 locked at 9", not Config.TrailUnlocked(Config.TrailsById.mint, 9, 0, noPass))
check("trail stage 10 unlocked at 10", Config.TrailUnlocked(Config.TrailsById.mint, 10, 0, noPass))
check("vip trail needs pass", not Config.TrailUnlocked(Config.TrailsById.vip, 100, 9, noPass))
-- Update: Coin-Trails, Erfolge, Edelsteine, Zeitformat, Einstellungen
check("coin trail locked without purchase", not Config.TrailUnlocked(Config.TrailsById.bubblegum, 100, 9, noPass, {}))
check("coin trail unlocked when owned", Config.TrailUnlocked(Config.TrailsById.bubblegum, 1, 0, noPass, { bubblegum = true }))
check("achievements have unique ids", (function()
	local seen = {}
	for _, a in Config.Achievements do
		if seen[a.Id] then
			return false
		end
		seen[a.Id] = true
	end
	return true
end)())
check("rich achievement last (sees other rewards)", Config.Achievements[#Config.Achievements].Id == "rich")
check("gem mask", Config.HasGem(0b100, 3) and not Config.HasGem(0b100, 2) and Config.CountGems(0b1011) == 3)
check("run time format", Config.FormatRunTime(125.4) == "2:05.4", Config.FormatRunTime(125.4))
check("settings lookup", Config.SettingsByKey.Sounds ~= nil and Config.SettingsByKey.Sounds.Default == true)
check("daily rewards 7 days", #Config.DailyRewards == 7)

-- Services laden, Welt bauen, starten (wie init.server.luau)
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ORDER = { "DataService", "WorldService", "StageService", "CosmeticService", "MonetizationService", "CommunityService", "RewardService", "LeaderboardService" }
local ok, err = pcall(function()
	services.Net = require(folder.Services.Net)
	for _, name in ORDER do
		services[name] = require(folder.Services[name])
	end
	for _, name in ORDER do
		services[name]:Init(services)
	end
	services.WorldService:Build()
end)
check("init + build world", ok, err)
if ok then
	local world = services.WorldService
	local count = 0
	for _ in world.Checkpoints do
		count += 1
	end
	check("checkpoints built", count == Config.StageCount, count)
	check("finish built", world.Finish ~= nil)
	check("finish above last checkpoint", world.Finish.Position.Y > world.Checkpoints[100].Position.Y)
	check("kill parts", #workspace.Obby.Kill:GetChildren() > 50, #workspace.Obby.Kill:GetChildren())
	check("spin tags", #CollectionService:GetTagged("Spin") > 0, #CollectionService:GetTagged("Spin"))
	check("slide tags", #CollectionService:GetTagged("Slide") > 0, #CollectionService:GetTagged("Slide"))
	check("fade tags", #CollectionService:GetTagged("Fade") > 0, #CollectionService:GetTagged("Fade"))
	local spawnCFrame = world:SpawnCFrame(5)
	check("spawn faces course (+Z)", spawnCFrame.LookVector.Z > 0.9, spawnCFrame.LookVector)
	check("spawn above pad", spawnCFrame.Position.Y > world.Checkpoints[5].Position.Y, spawnCFrame.Position.Y)
	local kills = 0
	for _, part in workspace.Obby.Kill:GetChildren() do
		if part:IsA("BasePart") and part.CanCollide then
			kills += 1
		end
	end
	check("kill parts don't collide", kills == 0, kills)
	check("bounce pads built", #workspace.Obby.Bounce:GetChildren() > 0, #workspace.Obby.Bounce:GetChildren())
	local gems = 0
	for _ in world.Gems do
		gems += 1
	end
	check("one gem per world", gems == #Config.Worlds, gems)
	check("leaderboard boards", world.Boards.Wins ~= nil and world.Boards.Time ~= nil)
	-- Jede Leiter muss oben an der Plattform ankommen (TrussPart nur in 2er-Schritten)
	local badTruss = 0
	for _, item in workspace.Obby:GetDescendants() do
		if item:IsA("TrussPart") and item.Size.Y % 2 ~= 0 then
			badTruss += 1
		end
	end
	check("truss heights even", badTruss == 0, badTruss)

	ok, err = pcall(function()
		for _, name in ORDER do
			if services[name].Start then
				services[name]:Start()
			end
		end
	end)
	check("start services", ok, err)
	check("remotes created", ReplicatedStorage:FindFirstChild("Remotes") ~= nil)
	check("chat commands", game:GetService("TextChatService"):FindFirstChild("CommunityCommands") ~= nil)
	-- Laufzeit-Suche der Produkte ueber den Namen (prueft auch die Feldnamen der API)
	local deadline = os.clock() + 15
	while ReplicatedStorage:GetAttribute("Price_SkipStage") == nil and os.clock() < deadline do
		task.wait(0.5)
	end
	check("product price resolved by name", ReplicatedStorage:GetAttribute("Price_SkipStage") ~= nil, ReplicatedStorage:GetAttribute("Price_SkipStage"))
	check("product id resolved", ReplicatedStorage:GetAttribute("ProductId_SkipStage") == Config.DevProducts.SkipStage.Id, ReplicatedStorage:GetAttribute("ProductId_SkipStage"))
	check("coin pack id resolved by name", (ReplicatedStorage:GetAttribute("ProductId_CoinPack") or 0) ~= 0, ReplicatedStorage:GetAttribute("ProductId_CoinPack"))
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	for _, name in { "Sync", "ClaimDaily", "ClaimQuest", "EquipTitle", "RedeemCode", "BuyTrail", "SetSetting", "SelectStage" } do
		check("remote " .. name, remotesFolder ~= nil and remotesFolder:FindFirstChild(name) ~= nil)
	end
end

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
