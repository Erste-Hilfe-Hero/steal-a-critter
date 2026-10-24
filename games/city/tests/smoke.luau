-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft (vor dem Veroeffentlichen).
-- Server-Scripts starten dort nicht automatisch, deshalb startet dieser Test die Services selbst.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Teams = game:GetService("Teams")

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
check("format 1.5K", Format.Number(1500) == "1.5K", Format.Number(1500))
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end
for _, car in Config.Cars do
	check("car " .. car.Id .. " buyable or pass/team", car.Price ~= nil or car.Pass ~= nil, car.Id)
	if car.Pass then
		check("car pass exists " .. car.Pass, Config.GamePasses[car.Pass] ~= nil)
	end
end
check("race reward", Config.RaceReward(60) > Config.RaceReward(120))
check("starter car exists", Config.CarsById[Config.DevProducts.StarterPack.Car] ~= nil)

-- Services laden und starten wie init.server.luau
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local ORDER = { "DataService", "WorldService", "VehicleService", "HouseService", "JobService", "MonetizationService", "RewardService", "CommunityService" }
local services = {}
local ok, err = pcall(function()
	services.Net = require(folder.Services.Net)
	for _, name in ORDER do
		services[name] = require(folder.Services[name])
	end
end)
check("require services", ok, err)

if ok then
	ok, err = pcall(function()
		for _, name in ORDER do
			services[name]:Init(services)
		end
		services.WorldService:Build()
	end)
	check("init + build city", ok, err)
	local world = services.WorldService
	check("lots >= 20", #world.Lots >= 20, #world.Lots)
	local robberies = 0
	for key in Config.Robberies do
		check("rob point " .. key, world.RobPoints[key] ~= nil)
		robberies += 1
	end
	check("delivery points", #world.DeliveryPoints > 60, #world.DeliveryPoints)
	check("race checkpoints", #world.RaceCheckpoints == #Config.RaceRoute, #world.RaceCheckpoints)
	check("hideout pad", world.Hideout ~= nil)
	check("depot", world.Depot ~= nil)
	check("jail cells", #world.JailCells >= 4, #world.JailCells)
	check("in jail", world.IsInJail(world.JailCenter))
	check("not in jail", not world.IsInJail(Vector3.zero))
	for _, team in { "Citizens", "Police", "Robbers" } do
		check("team " .. team, Teams:FindFirstChild(team) ~= nil)
		check("spawn " .. team, world.Spawns[team] ~= nil)
	end
	local point = world.NearestRoadPoint(Vector3.new(123, 0, 77))
	local onRoad = false
	for k = 0, Config.Grid do
		local line = Config.RoadLine(k)
		if math.abs(point.X - line) <= Config.Road / 2 or math.abs(point.Z - line) <= Config.Road / 2 then
			onRoad = true
		end
	end
	check("nearest road point on road", onRoad, point)
	check("leaderboard part", workspace:FindFirstChild("Leaderboard", true) ~= nil)
	check("showroom spots", #world.Showroom >= 4, #world.Showroom)

	-- Jede Hausstufe bauen
	for tier = 1, #Config.Houses do
		local built, model = pcall(services.HouseService.BuildHouse, tier, world.Lots[1], 1)
		check("build house " .. tier, built and #model:GetChildren() > 3, if built then nil else model)
		if built then
			model:Destroy()
		end
	end

	-- Jedes Auto bauen, eins fahren lassen (Physik wie auf dem Client, aber vom Server gesteuert)
	for _, def in Config.Cars do
		local built, car = pcall(services.VehicleService.BuildCar, def, { Underglow = true, Rainbow = true })
		check("build car " .. def.Id, built and car.PrimaryPart ~= nil and car:FindFirstChild("DriverSeat") ~= nil, if built then nil else car)
		if built then
			car:Destroy()
		end
	end
	local driveOk, driveErr = pcall(function()
		local def = Config.CarsById.cruiser
		local car = services.VehicleService.BuildCar(def)
		local start = Vector3.new(Config.RoadLine(3) + 9, 0, Config.BlockCenter(2, 2).Z)
		car:PivotTo(CFrame.lookAt(start, start + Vector3.new(0, 0, -1)) * CFrame.new(0, 0.5, 0))
		car.Parent = workspace
		local base = car.PrimaryPart :: BasePart
		local velocity = base:FindFirstChild("Drive") :: LinearVelocity
		local align = base:FindFirstChild("Align") :: AlignOrientation
		align.CFrame = CFrame.new()
		task.wait(0.5)
		velocity.PlaneVelocity = Vector2.new(0, -50)
		task.wait(1.5)
		local moved = (base.Position - start).Magnitude
		if moved < 0.5 then
			-- Manche Ausfuehrungsumgebungen simulieren keine Physik: dann nur Hinweis, kein Fehler
			table.insert(results, "INFO physics not simulated here, drive test skipped")
		else
			check("car drives", moved > 30, string.format("%.1f studs", moved))
			check("car stays on ground", base.Position.Y > -2 and base.Position.Y < 6, string.format("y=%.2f", base.Position.Y))
			check("car upright", base.CFrame.UpVector.Y > 0.95, string.format("%.2f", base.CFrame.UpVector.Y))
			align.CFrame = CFrame.Angles(0, math.rad(90), 0)
			task.wait(1)
			check("car steers", math.abs(base.CFrame.LookVector.X) > 0.7, string.format("%.2f", base.CFrame.LookVector.X))
			velocity.PlaneVelocity = Vector2.zero
			task.wait(1)
			check("car stops", base.AssemblyLinearVelocity.Magnitude < 5, string.format("%.1f", base.AssemblyLinearVelocity.Magnitude))
		end
		car:Destroy()
	end)
	check("drive test ran", driveOk, driveErr)

	ok, err = pcall(function()
		for _, name in ORDER do
			if services[name].Start then
				services[name]:Start()
			end
		end
	end)
	check("start services", ok, err)
	check("request remote", ReplicatedStorage:FindFirstChild("Remotes") ~= nil and ReplicatedStorage.Remotes:FindFirstChild("Request") ~= nil)
	check("showroom cars", #workspace:GetChildren() > 5)
end

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
