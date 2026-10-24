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
	check("product id " .. key, product.Id ~= 0, product.Id)
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

-- Services laden, Welt bauen, starten (wie init.server.luau)
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ORDER = { "DataService", "WorldService", "StageService", "CosmeticService", "MonetizationService", "CommunityService" }
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
end

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
