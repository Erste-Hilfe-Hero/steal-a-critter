-- Absturz-Test im echten Place (test-surf.yml, script=tests/falls.luau): Spieler ohne Eingabe von vielen
-- Stellen fallen lassen (vom Start seitlich, von jeder Rampe, vom Ziel, Lobby, Arena) und pruefen, dass er
-- unter die Todeshoehe faellt oder in einer sicheren Zone landet - also nie irgendwo haengen bleibt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local results = {}
local failed = 0
local function check(name, ok, detail)
	if not ok then
		failed += 1
	end
	if not ok or #results < 400 then
		table.insert(results, (if ok then "PASS " else "FAIL ") .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
	end
end
local function finish()
	table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
	return table.concat(results, "\n")
end

local Config = require(ReplicatedStorage.Shared.Config)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)
local StageLayout = require(ReplicatedStorage.Shared.StageLayout)
local Arena = require(ReplicatedStorage.Shared.Arena)

local folder = ServerScriptService.Server
local services = {}
local ok, err = pcall(function()
	for _, name in { "Net", "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "ProgressService", "EventService", "MonetizationService", "ArenaService" } do
		services[name] = require(folder.Services[name])
	end
	for _, name in { "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "ProgressService", "EventService", "MonetizationService", "ArenaService" } do
		services[name]:Init(services)
	end
	services.WorldService:Build()
	services.ArenaService:Start()
end)
check("build", ok, err)
if not ok then
	return finish()
end

local zones = workspace:FindFirstChild("Zones")
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { zones, workspace:FindFirstChild("WarBots") }
params.RespectCanCollide = true
local S = SurfPhysics.Settings
local HULL = Vector3.new(2, 5, 2)
local DT = 1 / 50

local function inside(part, point)
	local p = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

-- Simuliert bis zum Tod/Ziel; "walk" = Laufrichtung am Boden (danach keine Eingabe mehr)
local function simulate(start, velocity, walk, killY, safe, seconds)
	local last
	local cast = function(from, delta)
		local r = workspace:Blockcast(CFrame.new(from), HULL, delta, params)
		if r then
			last = r.Instance
			return { Distance = r.Distance, Normal = r.Normal }
		end
		return nil
	end
	local state = { Position = start, Velocity = velocity, Grounded = false }
	local t = 0
	local still = 0
	local prev = start
	while t < seconds do
		t += DT
		local wish = if walk and state.Grounded then walk else Vector3.zero
		SurfPhysics.Step(state, { WishDir = wish, WishAmount = if wish.Magnitude > 0 then 1 else 0, Jump = false }, DT, cast, S)
		local feet = state.Position.Y - HULL.Y / 2
		if feet < killY then
			return "killed", t
		end
		for _, zone in safe do
			if inside(zone, state.Position) then
				return "safe", t
			end
		end
		if (state.Position - prev).Magnitude < 0.05 then
			still += DT
			if still > 3 then
				return "stuck", t, state.Position, last and last:GetFullName(), state.Grounded
			end
		else
			still = 0
		end
		prev = state.Position
	end
	return "timeout", t, state.Position, last and last:GetFullName(), state.Grounded
end

local function run(name, start, velocity, walk, killY, safe)
	local outcome, t, pos, part, grounded = simulate(start, velocity, walk, killY, safe, 25)
	local good = outcome == "killed" or outcome == "safe"
	check(name, good, if good then string.format("%s %.1fs", outcome, t) else string.format("%s at %s on %s grounded=%s", outcome, tostring(pos), tostring(part), tostring(grounded)))
end

local dirs = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }

for index, def in Config.Stages do
	local layout = StageLayout.Build(index, def, Config.StageSpacing, Config.StageHeight)
	local info = services.WorldService:GetStageInfo(index)
	local killY = info.Start:GetAttribute("KillY")
	local spawn = info.Start:GetAttribute("Spawn").Position + Vector3.new(0, 2.5 - 3 + 0.2, 0)
	-- Vom Start in alle Richtungen ablaufen (Ziel zaehlt als sicher, Startzone nicht)
	for i, d in dirs do
		run(`stage {index} walk off start dir {i}`, spawn, Vector3.zero, d, killY, { info.Finish })
	end
	-- Von jeder Rampe ohne Strafen abrutschen
	for r, ramp in layout.Ramps do
		for _, side in { -1, 1 } do
			for _, frac in { 0.15, 0.5, 0.9 } do
				local cf = CFrame.new(ramp.Ridge) * CFrame.Angles(0, 0, -math.rad(ramp.Pitch))
				local point = (cf * CFrame.new(ramp.Length * frac, 6, side * ramp.Width * 0.15)).Position
				run(`stage {index} ramp {r} side {side} at {frac}`, point, Vector3.new(40, 0, 0), nil, killY, { info.Finish })
			end
		end
	end
	-- Vom Zielplateau in alle Richtungen herunter
	local fc = layout.FinishCenter + Vector3.new(0, 2.5 + 0.2, 0)
	for i, d in dirs do
		run(`stage {index} walk off finish dir {i}`, fc, Vector3.zero, d, killY, {})
	end
end

-- Lobby
local lobby = workspace:GetAttribute("LobbySpawn").Position + Vector3.new(0, -0.3, 0)
local lobbyKill = workspace:GetAttribute("LobbyKillY")
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	run(`lobby walk dir {i}`, lobby, Vector3.zero, Vector3.new(math.cos(a), 0, math.sin(a)), lobbyKill, { zones.StartPortal, zones.WarsPortal })
end

-- Arena: von beiden Basen und vom Platz in alle Richtungen
for _, team in Arena.Teams do
	local sp = Arena.Spawn(team.Id).Position + Vector3.new(0, -0.3, 0)
	for i, d in dirs do
		run(`arena {team.Id} base dir {i}`, sp, Vector3.zero, d, Arena.KillY, {})
	end
end
local plaza = Vector3.new(Arena.Center.X, Arena.PlazaTop + 2.7, Arena.Center.Z)
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	run(`arena plaza walk dir {i}`, plaza, Vector3.zero, Vector3.new(math.cos(a), 0, math.sin(a)), Arena.KillY, {})
end

return finish()
