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
local function rotZ(v, a)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(v.X * c - v.Y * s, v.X * s + v.Y * c, v.Z)
end

-- Konvexer Koerper = Liste von Ebenen { N, D } (aussen: N.p > D)
local function prism(r)
	local half = r.Width / 2
	local a = -math.rad(r.Pitch)
	local planes = {}
	local function add(nLocal, dLocal)
		local n = rotZ(nLocal.Unit, a)
		local scale = 1 / nLocal.Magnitude
		table.insert(planes, { N = n, D = n:Dot(r.Ridge) + dLocal * scale })
	end
	add(Vector3.new(0, half, -r.Height), 0)
	add(Vector3.new(0, half, r.Height), 0)
	add(Vector3.new(0, -1, 0), r.Height)
	add(Vector3.new(-1, 0, 0), 0)
	add(Vector3.new(1, 0, 0), r.Length)
	return planes
end

local function box(topCenter, size)
	local c = topCenter - Vector3.new(0, size.Y / 2, 0)
	local h = size / 2
	return {
		{ N = Vector3.new(1, 0, 0), D = c.X + h.X },
		{ N = Vector3.new(-1, 0, 0), D = -(c.X - h.X) },
		{ N = Vector3.new(0, 1, 0), D = c.Y + h.Y },
		{ N = Vector3.new(0, -1, 0), D = -(c.Y - h.Y) },
		{ N = Vector3.new(0, 0, 1), D = c.Z + h.Z },
		{ N = Vector3.new(0, 0, -1), D = -(c.Z - h.Z) },
	}
end

local function makeCast(solids)
	return function(from, delta)
		local best
		for _, planes in solids do
			local tEnter, tExit, normal = -math.huge, math.huge, nil
			local miss = false
			for _, p in planes do
				local n = p.N
				local r = math.abs(n.X) * HALF.X + math.abs(n.Y) * HALF.Y + math.abs(n.Z) * HALF.Z
				local dist = n:Dot(from) - p.D - r
				local denom = n:Dot(delta)
				if math.abs(denom) < 1e-12 then
					if dist > 0 then
						miss = true
						break
					end
				else
					local t = -dist / denom
					if denom < 0 then
						if t > tEnter then
							tEnter, normal = t, n
						end
					else
						tExit = math.min(tExit, t)
					end
				end
			end
			if not miss and normal and tEnter <= tExit and tEnter >= -1e-6 and tEnter <= 1 then
				if not best or tEnter < best.T then
					best = { T = tEnter, Distance = math.max(0, tEnter) * delta.Magnitude, Normal = normal }
				end
			end
		end
		return best
	end
end

local S = SurfPhysics.Settings
local HULL = Vector3.new(2, 5, 2)
local DT = 1 / 100
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
local function fmt(h)
	if not h then return "nil" end
	return string.format("d=%.3f n=(%.3f,%.3f,%.3f)", h.Distance, h.Normal.X, h.Normal.Y, h.Normal.Z)
end
for _, index in { 1, 2 } do
	local def = Config.Stages[index]
	local layout = StageLayout.Build(index, def, Config.StageSpacing, Config.StageHeight)
	local solids = { box(layout.StartCenter, layout.StartSize), box(layout.FinishCenter, layout.FinishSize) }
	for _, r in layout.Ramps do table.insert(solids, prism(r)) end
	local model = makeCast(solids)
	local t = 0
	local mism = 0
	local lastSlope, lastSlopeTime = nil, -1
	local cast = function(from, delta)
		local result = workspace:Blockcast(CFrame.new(from), HULL, delta, params)
		local real = result and { Distance = result.Distance, Normal = result.Normal, Inst = result.Instance }
		local m = model(from, delta)
		local differ = (real == nil) ~= (m == nil) or (real and m and (math.abs(real.Distance - m.Distance) > 0.03 or (real.Normal - m.Normal).Magnitude > 0.05))
		if differ and mism < 14 then
			mism += 1
			table.insert(results, string.format("S%d t=%.2f from=(%.2f,%.2f,%.2f) delta=(%.3f,%.3f,%.3f) real=%s [%s] model=%s", index, t, from.X, from.Y, from.Z, delta.X, delta.Y, delta.Z, fmt(real), real and real.Inst:GetFullName() or "-", fmt(m)))
		end
		if real and real.Normal.Y < S.StandNormal and real.Normal.Y > 0 then lastSlope, lastSlopeTime = real.Normal, t end
		return real
	end
	local state = { Position = layout.Spawn + Vector3.new(0, 2.5 - 3, 0), Velocity = Vector3.zero, Grounded = false }
	while t < 8 do
		t += DT
		local pos = state.Position
		local target
		for _, r in layout.Ramps do if r.RidgeEnd.X > pos.X - 1 then target = r break end end
		local wish, amount = Vector3.zero, 0
		if state.Grounded and pos.X < 0 then
			wish, amount = Vector3.new(1, 0, 0), 1
		elseif lastSlope and t - lastSlopeTime < 0.08 then
			wish, amount = Vector3.new(0, 0, if lastSlope.Z < 0 then 1 else -1), 1
		else
			local goal = if target then Vector3.new(math.max(target.Ridge.X + 25, pos.X + 40), 0, target.Ridge.Z + (if pos.Z >= target.Ridge.Z then 1 else -1) * target.Width * 0.25) else Vector3.new(layout.FinishCenter.X, 0, layout.FinishCenter.Z)
			local v, h = flat(state.Velocity), flat(goal - pos)
			if v.Magnitude > 1 and h.Magnitude > 1 then
				v, h = v.Unit, h.Unit
				local perp = Vector3.new(-v.Z, 0, v.X)
				if perp:Dot(h) < 0 then perp = -perp end
				if v:Dot(h) < math.cos(math.rad(2)) then wish, amount = perp, 1 end
			end
		end
		SurfPhysics.Step(state, { WishDir = wish, WishAmount = amount, Jump = false }, DT, cast, S)
		if math.floor(t * 100 + 0.5) % 25 == 0 then
			table.insert(results, string.format("S%d t=%.2f pos=(%.1f,%.1f,%.1f) vel=(%.1f,%.1f,%.1f) g=%s", index, t, state.Position.X, state.Position.Y, state.Position.Z, state.Velocity.X, state.Velocity.Y, state.Velocity.Z, tostring(state.Grounded)))
		end
		if state.Position.Y - 2.5 < layout.KillY then break end
	end
end
return finish()
