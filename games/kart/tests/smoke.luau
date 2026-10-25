-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft (vor dem Veroeffentlichen).
-- Server-Scripts starten dort nicht automatisch, deshalb startet dieser Test die Services selbst.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local results = {}
local failed = 0
local function check(name, ok, detail)
	if not ok then
		failed += 1
	end
	table.insert(results, (if ok then "PASS " else "FAIL ") .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
end
local function info(text)
	table.insert(results, "INFO " .. text)
end

local Config = require(ReplicatedStorage.Shared.Config)
local Tracks = require(ReplicatedStorage.Shared.Tracks)
local KartFactory = require(ReplicatedStorage.Shared.KartFactory)
local KartPhysics = require(ReplicatedStorage.Shared.KartPhysics)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Format = require(ReplicatedStorage.Shared.Format)

-- Produkte
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end

-- Karts bauen
for _, kart in Config.Karts do
	local ok, model = pcall(KartFactory.Build, kart.Id, "Rainbow", nil)
	check("build kart " .. kart.Id, ok and model.PrimaryPart ~= nil and model:FindFirstChild("DriverSeat") ~= nil, if ok then nil else model)
	if ok then
		model:Destroy()
	end
end

-- Lackierungen
for _, paint in Config.Paints do
	local ok, model = pcall(KartFactory.Build, "Phoenix", "Orange", { Paint = paint.Id })
	check("build paint " .. paint.Id, ok and model.PrimaryPart ~= nil, if ok then nil else model)
	if ok then
		model:Destroy()
	end
end

-- Fortschritt: Level, Aufgaben, Erfolge, Serie, Zeitformat
do
	local level, into, need = Progression.LevelFromXp(100)
	check("level math", level == 2 and into == 0 and need == Progression.XpForLevel(2), `{level} {into} {need}`)
	local quests = Progression.QuestsForDay(20_000, 123)
	check("3 different daily quests", #quests == 3 and quests[1] ~= quests[2] and quests[2] ~= quests[3] and quests[1] ~= quests[3], table.concat(quests, ","))
	local fresh = { Races = 0, Wins = 0, Stats = { Hits = 0, TrackCoins = 0 }, BestStreak = 0, XP = 0, Best = {} }
	local errors = {}
	for _, achievement in Progression.Achievements do
		local okCheck, reached = pcall(achievement.Check, fresh)
		if not okCheck or reached then
			table.insert(errors, achievement.Id)
		end
	end
	check("achievements locked for new player", #errors == 0, table.concat(errors, ","))
	check("streak bonus", Progression.StreakBonus(1) == 0 and Progression.StreakBonus(3) == 100)
	check("race time format", Format.RaceTime(83.456) == "1:23.45", Format.RaceTime(83.456))
end

-- Services laden wie init.server.luau
local folder = ServerScriptService:WaitForChild("Server")
local services = {}
local ORDER = { "DataService", "TrackService", "LobbyService", "RaceService", "MonetizationService", "ShopService", "ProgressService" }
local ok, err = pcall(function()
	services.Net = require(folder.Services.Net)
	for _, name in ORDER do
		services[name] = require(folder.Services[name])
	end
	for _, name in ORDER do
		services[name]:Init(services)
	end
	services.LobbyService:Build()
end)
check("init services + lobby", ok, err)
check("lobby spawn", workspace:FindFirstChild("Lobby") ~= nil and workspace.Lobby:FindFirstChildOfClass("SpawnLocation") ~= nil)
check("lobby records board", workspace:FindFirstChild("Lobby") ~= nil and workspace.Lobby:FindFirstChild("RecordsBoard") ~= nil)
do
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local missing = {}
	for _, name in { "SetTitle", "Setting", "RedeemCode", "GetProfile", "Claim" } do
		if not remotes or not remotes:FindFirstChild(name) then
			table.insert(missing, name)
		end
	end
	check("new remotes exist", #missing == 0, table.concat(missing, ","))
end

-- Jede Strecke bauen und vermessen: Fahrbahn ohne Loecher, keine Wand mitten auf der Fahrlinie
for _, def in Tracks.List do
	local started = os.clock()
	local built, current = pcall(services.TrackService.Load, services.TrackService, def.Id)
	check("build track " .. def.Id, built, if built then nil else current)
	if not built then
		continue
	end
	local geo = current.Geometry
	local road = RaycastParams.new()
	road.FilterType = Enum.RaycastFilterType.Include
	road.FilterDescendantsInstances = { current.RoadFolder }
	local walls = RaycastParams.new()
	walls.FilterType = Enum.RaycastFilterType.Include
	walls.FilterDescendantsInstances = { current.Folder.Walls }
	local holes, blocked = 0, 0
	for i = 1, geo.Count do
		for _, lat in { -0.42, 0, 0.42 } do
			local p = geo.Points[i] + geo.Rights[i] * lat * geo.Width / 2
			if not workspace:Raycast(p + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), road) then
				holes += 1
			end
		end
		local j = i % geo.Count + 1
		for _, lat in { -0.35, 0, 0.35 } do
			local a = geo.Points[i] + geo.Rights[i] * lat * geo.Width / 2 + Vector3.new(0, 2, 0)
			local b = geo.Points[j] + geo.Rights[j] * lat * geo.Width / 2 + Vector3.new(0, 2, 0)
			if workspace:Raycast(a, b - a, walls) then
				blocked += 1
			end
		end
	end
	local parts = #current.Folder:GetDescendants()
	check(`{def.Id} road has no holes`, holes == 0, `{holes} of {geo.Count * 3}`)
	check(`{def.Id} driving line free of walls`, blocked == 0, blocked)
	check(`{def.Id} boxes + coins`, #current.Boxes >= 8 and #current.Coins >= 20, `{#current.Boxes}/{#current.Coins}`)
	local gridOk = true
	for slot = 1, Config.MaxRacers do
		local cf = services.TrackService:GridCFrame(slot)
		if not workspace:Raycast(cf.Position, Vector3.new(0, -10, 0), road) then
			gridOk = false
		end
	end
	check(`{def.Id} grid on road`, gridOk)
	info(`{def.Id}: {math.floor(geo.Length)} studs, {geo.Count} points, {parts} instances, built in {math.floor((os.clock() - started) * 1000)} ms`)
end

-- Fahrphysik: ein Kart faehrt per Autopilot ueber echte Strecken (nur wenn hier Physik laeuft)
local probe = Instance.new("Part")
probe.Position = Vector3.new(0, 900, 0)
probe.Parent = workspace
task.wait(1)
local physics = probe.Position.Y < 899
probe:Destroy()
info("physics running: " .. tostring(physics))
if physics then
	for _, trackId in { "Speedway", "Candy", "StarHighway", "Frost" } do
		local current = services.TrackService:Load(trackId)
		local geo = current.Geometry
		local model = KartFactory.Build("Blaze", "Orange")
		model:PivotTo(services.TrackService:GridCFrame(1))
		model.Parent = workspace
		local root = model.PrimaryPart
		pcall(root.SetNetworkOwner, root, nil)
		local road = RaycastParams.new()
		road.FilterType = Enum.RaycastFilterType.Include
		road.FilterDescendantsInstances = { current.RoadFolder }
		local walls = RaycastParams.new()
		walls.FilterType = Enum.RaycastFilterType.Include
		walls.FilterDescendantsInstances = { current.Folder.Walls }
		local state = KartPhysics.new("Blaze", root, geo)
		local respawns, bumps, boosts, elapsed, drift = 0, 0, 0, 0, false
		local traveled, last = 0, state.LastIndex
		local conn = RunService.PreSimulation:Connect(function(dt)
			elapsed += dt
			local steer, throttle = KartPhysics.Autopilot(state, root, geo, 5)
			drift = math.abs(steer) > 0.6 or (drift and math.abs(steer) > 0.2)
			local events = KartPhysics.Step(state, root, geo, { Throttle = throttle, Steer = steer, Drift = drift }, dt, 0, road, walls)
			for _, e in events do
				if e == "Respawn" then
					respawns += 1
				elseif e == "Bump" then
					bumps += 1
				elseif e == "Boost" then
					boosts += 1
				end
			end
			local d = state.LastIndex - last
			if d < -geo.Count / 2 then
				d += geo.Count
			end
			traveled += d
			last = state.LastIndex
		end)
		task.wait(20)
		conn:Disconnect()
		local studs = traveled * geo.Length / geo.Count
		check(`drive {trackId}: kart moves along the track`, studs > 600, `{math.floor(studs)} studs in 20s`)
		check(`drive {trackId}: few respawns`, respawns <= 2, respawns)
		info(`drive {trackId}: {math.floor(studs)} studs, {respawns} respawns, {bumps} wall bumps, {boosts} boosts, speed {math.floor(state.Speed)}`)
		model:Destroy()
	end
end

-- Ein kurzes Rennen nur mit CPU-Fahrern (1 Runde)
if ok then
	Config.Laps = 1
	Config.MaxRaceTime = 120
	local race = services.RaceService
	local raceOk, raceErr = true, nil
	task.spawn(function()
		raceOk, raceErr = pcall(race.StartRace, race, "Speedway")
	end)
	local deadline = os.clock() + 15
	while workspace:GetAttribute("Phase") ~= "Race" and os.clock() < deadline do
		task.wait(0.2)
	end
	check("race started", workspace:GetAttribute("Phase") == "Race", workspace:GetAttribute("Phase"))
	check("8 racers on the grid", #race.Racers == Config.MaxRacers, #race.Racers)
	task.wait(3)
	local bot = race.Racers[1]
	local itemErrors = {}
	if bot then
		for _, item in { "Boost", "TripleBoost", "Fireball", "Homing", "Oil", "Shield", "Inferno", "Thunder" } do
			bot.Item, bot.ItemReadyAt = item, 0
			local used, useErr = pcall(race.Debug.UseItem, bot)
			if not used then
				table.insert(itemErrors, item .. ": " .. tostring(useErr))
			end
		end
		check("all items usable", #itemErrors == 0, table.concat(itemErrors, "; "))
		check("projectiles spawned", #race.Debug.Projectiles >= 2, #race.Debug.Projectiles)
		local hitOk, hitErr = pcall(race.Debug.Hit, race.Racers[2], bot)
		check("hit works", hitOk, hitErr)
		-- Waehrend man sich dreht, zaehlt kein weiterer Treffer (Inferno-Rammen)
		local victim = race.Racers[3]
		if victim then
			victim.RaceCoins, victim.SpinUntil, victim.ShieldUntil, victim.InfernoUntil = 6, 0, 0, 0
			race.Debug.Hit(victim, bot)
			race.Debug.Hit(victim, bot)
			check("no double hit while spinning", victim.RaceCoins == 4, victim.RaceCoins)
		end
	end
	-- Die Test-Items (Donner, Feuerbaelle) bremsen die Bots aus, daher Fortschritt ab jetzt messen
	local before = {}
	for i, racer in race.Racers do
		before[i] = racer.Progress
	end
	task.wait(8)
	local progressed, crossed = 0, 0
	local spacing = Tracks.Geometry("Speedway").Length / Tracks.Geometry("Speedway").Count
	for i, racer in race.Racers do
		if (racer.Progress - before[i]) * spacing > 80 then
			progressed += 1
		end
		if racer.Progress > Tracks.Geometry("Speedway").Count then
			crossed += 1
		end
	end
	info(`bots crossed the start line: {crossed}`)
	check("bots keep driving", progressed >= 6, progressed)
	deadline = os.clock() + 80
	while workspace:GetAttribute("Phase") == "Race" and os.clock() < deadline do
		task.wait(0.5)
	end
	check("race finished", workspace:GetAttribute("Phase") == "Results", workspace:GetAttribute("Phase"))
	check("race without errors", raceOk, raceErr)
	local finishedCount = 0
	for _, racer in race.Racers do
		if racer.Finished then
			finishedCount += 1
		end
	end
	info(`finished: {finishedCount}/{#race.Racers}`)
end

table.insert(results, 1, `SUMMARY: {failed} failed, {#results} checks`)
return table.concat(results, "\n")
