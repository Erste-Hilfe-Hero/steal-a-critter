-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft (Workflow test-surf.yml).
-- Server-Scripts starten dort nicht automatisch, deshalb baut dieser Test die Map selbst, prueft die
-- Rampen mit echten Strahlen und laesst einen Bot mit echter SurfPhysics + workspace:Blockcast jede Stage abfahren.
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
local function finish()
	table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
	return table.concat(results, "\n")
end

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)
local StageLayout = require(ReplicatedStorage.Shared.StageLayout)

-- Konfiguration
check("format run time", Format.Run(83.4567) == "1:23.457", Format.Run(83.4567))
check("format number", Format.Number(12345) == "12.3K", Format.Number(12345))
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end

-- Services laden und Map bauen
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ok, err = pcall(function()
	for _, name in { "Net", "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "MonetizationService" } do
		services[name] = require(folder.Services[name])
	end
	for _, name in { "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "MonetizationService" } do
		services[name]:Init(services)
	end
	services.WorldService:Build()
end)
check("require + build world", ok, err)
if not ok then
	return finish()
end
local zones = workspace:FindFirstChild("Zones")
check("zones folder", zones ~= nil)
check("lobby portal", zones and zones:FindFirstChild("StartPortal") ~= nil)
check("leaderboard board", services.WorldService.Board ~= nil)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { zones }
params.RespectCanCollide = true

local HALF = Vector3.new(1, 2.5, 1)
local HULL = HALF * 2
local function support(n) return math.abs(n.X) * HALF.X + math.abs(n.Y) * HALF.Y + math.abs(n.Z) * HALF.Z end
local def = Config.Stages[1]
local layout = StageLayout.Build(1, def, Config.StageSpacing, Config.StageHeight)
local r = layout.Ramps[1]
local cf = CFrame.new(r.Ridge) * CFrame.Angles(0, 0, -math.rad(r.Pitch))
local point = (cf * CFrame.new(r.Length / 2, 0, -r.Width / 4)).Position
local hit = workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
local n = hit.Normal
local floor = workspace:Raycast(layout.Spawn, Vector3.new(0, -10, 0), params)
for _, g in { 0, 0.001, 0.003, 0.005, 0.01, 0.02, 0.03, 0.05, 0.08, 0.12 } do
	local c = hit.Position + n * (g + support(n))
	local a = workspace:Blockcast(CFrame.new(c), HULL, -n * 0.5, params)
	local b = workspace:Blockcast(CFrame.new(c), HULL, Vector3.new(0, -0.5, 0), params)
	local slide = Vector3.new(1, 0, 0) - n * n:Dot(Vector3.new(1, 0, 0))
	local d = workspace:Blockcast(CFrame.new(c), HULL, slide.Unit * 0.5 - n * 0.03, params)
	local fc = floor.Position + Vector3.new(0, g + HALF.Y, 0)
	local f = workspace:Blockcast(CFrame.new(fc), HULL, Vector3.new(0, -0.5, 0), params)
	local back = workspace:Blockcast(CFrame.new(c + n * 0.25), HULL, -n * 0.75, params)
	table.insert(results, string.format("gap %.3f slope-normal %s vertical %s glancing %s floor %s backoff %s", g,
		a and string.format("%.3f", a.Distance) or "nil", b and string.format("%.3f", b.Distance) or "nil",
		d and string.format("%.3f", d.Distance) or "nil", f and string.format("%.3f", f.Distance) or "nil", back and string.format("%.3f", back.Distance) or "nil"))
end
-- overlapping start: box 0.05 inside the slope
for _, g in { -0.02, -0.05, -0.2 } do
	local c = hit.Position + n * (g + support(n))
	local a = workspace:Blockcast(CFrame.new(c), HULL, -n * 0.5, params)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(c), HULL)
	table.insert(results, string.format("inside %.2f cast %s overlapParts %d", g, a and "hit" or "nil", #parts))
end
return finish()
