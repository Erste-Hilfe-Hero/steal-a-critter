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

-- Update 2: Fortschritt, Gluecksrad, Tuning, Events
local KNOWN_STATS = { Deliveries = true, Arrests = true, Robberies = true, Races = true, Trucks = true, TopSpeed = true, Chores = true, Level = true, Tokens = true, House = true, Cars = true, TotalEarned = true }
local titles = {}
for _, achievement in Config.Achievements do
	check("achievement stat " .. achievement.Id, KNOWN_STATS[achievement.Stat] == true and achievement.Goal > 0 and achievement.Reward > 0, achievement.Stat)
	check("achievement title unique " .. achievement.Id, titles[achievement.Title] == nil and #achievement.Title <= 40, achievement.Title)
	titles[achievement.Title] = true
end
check("xp curve grows", Config.XpForLevel(2) > Config.XpForLevel(1) and Config.XpForLevel(1) > 0)
local weights = 0
for _, prize in Config.SpinPrizes do
	weights += prize.Weight
	check("spin prize " .. prize.Label, (prize.Cash or prize.Xp or 0) > 0 and prize.Weight > 0)
end
check("spin weights", weights > 0)
for _, car in Config.Cars do
	check("tune cost " .. car.Id, Config.TuneCost(car, 1) > 0 and Config.TuneCost(car, Config.TuneMax) >= Config.TuneCost(car, 1))
end
check("city events", #Config.CityEvents >= 2 and Config.EventsById.CrimeWave ~= nil and Config.EventsById.DoubleBounty ~= nil and Config.EventsById.RushHour ~= nil)
check("tutorial steps", #Config.Tutorial >= 3)
check("max tune product", Config.DevProducts.MaxTune ~= nil and Config.DevProducts.MaxTune.Kind == "MaxTune")

-- Services laden und starten wie init.server.luau
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local ORDER = { "DataService", "WorldService", "VehicleService", "HouseService", "JobService", "MonetizationService", "RewardService", "CommunityService", "ProgressService", "EventService" }
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
	check("turbo tokens", #world.Tokens == Config.AchievementsById.Tokens.Goal, #world.Tokens)
	check("speed cams", #world.SpeedCams >= 3, #world.SpeedCams)
	check("spray pad", world.SprayPad ~= nil)
	check("top cops board", workspace:FindFirstChild("TopCopsBoard", true) ~= nil)
	check("top robbers board", workspace:FindFirstChild("TopRobbersBoard", true) ~= nil)
	for _, landmark in Config.Landmarks do
		check("landmark block " .. landmark.Name, landmark.Block[1] < Config.Grid and landmark.Block[2] < Config.Grid)
	end
	local fake = { Level = 3, TotalEarned = 10, Tokens = { ["1"] = true }, Cars = { bubble = true }, House = 2, Stats = { Arrests = 4 } }
	local stat = services.ProgressService.StatValue
	check("stat values", stat(fake, "Level") == 3 and stat(fake, "Tokens") == 1 and stat(fake, "Cars") == 1 and stat(fake, "Arrests") == 4 and stat(fake, "Trucks") == 0)

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
	-- Laeuft hier ueberhaupt Physik? Ein frei fallendes Teil verraet es.
	local probe = Instance.new("Part")
	probe.Position = Vector3.new(0, 900, 0)
	probe.Parent = workspace
	task.wait(1)
	local physics = probe.Position.Y < 899
	probe:Destroy()
	local driveOk, driveErr = pcall(function()
		if not physics then
			-- Manche Ausfuehrungsumgebungen simulieren keine Physik: dann nur Hinweis, kein Fehler
			table.insert(results, "INFO physics not simulated here, drive test skipped")
			return
		end
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
		do
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
	check("celebrate remote", ReplicatedStorage.Remotes:FindFirstChild("Celebrate") ~= nil)
	check("chore remote", ReplicatedStorage.Remotes:FindFirstChild("Chore") ~= nil)
	if ok then
		local eventOk, eventErr = pcall(function()
			services.EventService:StartEvent("CrimeWave")
			check("city event active", services.EventService:Active("CrimeWave") and not services.EventService:Active("RushHour"))
			workspace:SetAttribute("EventId", nil)
			workspace:SetAttribute("EventUntil", nil)
			local spawned = services.EventService:SpawnTruck()
			check("armored truck spawns", spawned and workspace:FindFirstChild("ArmoredTruck") ~= nil and workspace:GetAttribute("TruckAt") ~= nil)
			services.EventService:DespawnTruck()
			check("armored truck despawns", workspace:FindFirstChild("ArmoredTruck") == nil and workspace:GetAttribute("TruckAt") == nil)
		end)
		check("events ran", eventOk, eventErr)
	end
end

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
