local DEBUG, DEBUG_STAGE, DEBUG_FROM = false, 1, 0
-- Bot-Test: faehrt jede Stage mit echter SurfPhysics gegen die echte Stage-Geometrie (StageLayout) ab.
-- Kollision analytisch: Rampen sind Prismen, Plattformen Quader (Box-Hull gegen konvexe Koerper).
-- Ausfuehren: tests/run_stages.sh  (fuegt Vector3, SurfPhysics, StageLayout und Config-Stages davor ein)
local S = SurfPhysics.Settings
local HALF = Vector3.new(1, 2.5, 1)
local DT = 1 / 100

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

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local failed = 0
for index, def in Stages do
	local layout = StageLayout.Build(index, def, StageSpacing, StageHeight)
	local solids = { box(layout.StartCenter, layout.StartSize), box(layout.FinishCenter, layout.FinishSize) }
	for _, r in layout.Ramps do
		table.insert(solids, prism(r))
	end
	local rawCast = makeCast(solids)
	local lastSlope, lastSlopeTime = nil, -1
	local t = 0
	local cast = function(from, delta)
		local hit = rawCast(from, delta)
		if hit and hit.Normal.Y < S.StandNormal and hit.Normal.Y > 0 then
			lastSlope, lastSlopeTime = hit.Normal, t
		end
		return hit
	end
	local state = { Position = layout.Spawn + Vector3.new(0, 2.5 - 3, 0), Velocity = Vector3.zero, Grounded = false }
	local finishZoneC = layout.FinishCenter + Vector3.new(0, 30, 0)
	local result, topSpeed = nil, 0
	while t < 90 do
		t += DT
		local pos = state.Position
		local wish, amount
		if state.Grounded and pos.X < 0 then
			wish, amount = Vector3.new(1, 0, 0), 1
		else
			local slope = if lastSlope and t - lastSlopeTime < 0.08 then lastSlope else nil
			wish, amount = SurfAssist.Wish(layout, pos, state.Velocity, state.Grounded, slope)
		end
		SurfPhysics.Step(state, { WishDir = wish, WishAmount = amount, Jump = false }, DT, cast, S)
		if DEBUG and index == DEBUG_STAGE and math.floor(t * 100) % 10 == 0 and t > DEBUG_FROM and t < DEBUG_FROM + 3 then
			print(string.format("t=%.2f pos=%s vel=%s g=%s wish=%s slope=%s", t, tostring(state.Position), tostring(state.Velocity), tostring(state.Grounded), tostring(wish), tostring(lastSlope)))
		end
		topSpeed = math.max(topSpeed, flat(state.Velocity).Magnitude)
		local p = state.Position - finishZoneC
		if math.abs(p.X) < 70 and math.abs(p.Y) < 30 and math.abs(p.Z) < 85 then
			result = string.format("PASS stage %d %-14s finished in %.2fs  top %d u/s", index, def.Name, t, topSpeed / SurfPhysics.Unit)
			break
		end
		if state.Position.Y - 2.5 < layout.KillY then
			local rampIndex = 0
			for i, r in layout.Ramps do
				if r.Ridge.X < state.Position.X then
					rampIndex = i
				end
			end
			result = string.format("FAIL stage %d %-14s fell after %.1fs near ramp %d/%d at x=%.0f z=%.0f (lane %.0f) top %d u/s", index, def.Name, t, rampIndex, #layout.Ramps, state.Position.X, state.Position.Z, layout.LaneZ, topSpeed / SurfPhysics.Unit)
			break
		end
	end
	if not result then
		result = string.format("FAIL stage %d timeout at %s", index, tostring(state.Position))
	end
	if result:sub(1, 4) == "FAIL" then
		failed += 1
	end
	print(result)
end
-- Update 3: Arena-Haelfte (Snowball Wars) mit der Surf-Hilfe bis zum Platz in der Mitte
do
	local layout = Arena.Half
	local solids = { box(layout.StartCenter, layout.StartSize), box(layout.FinishCenter, layout.FinishSize) }
	for _, r in layout.Ramps do
		table.insert(solids, prism(r))
	end
	local rawCast = makeCast(solids)
	local lastSlope, lastSlopeTime = nil, -1
	local t = 0
	local cast = function(from, delta)
		local hit = rawCast(from, delta)
		if hit and hit.Normal.Y < S.StandNormal and hit.Normal.Y > 0 then
			lastSlope, lastSlopeTime = hit.Normal, t
		end
		return hit
	end
	local state = { Position = layout.Spawn + Vector3.new(0, 2.5 - 3, 0), Velocity = Vector3.zero, Grounded = false }
	local result
	while t < 40 do
		t += DT
		local pos = state.Position
		local wish, amount
		if state.Grounded and pos.X < layout.StartCenter.X + layout.StartSize.X / 2 then
			wish, amount = Vector3.new(1, 0, 0), 1
		else
			local slope = if lastSlope and t - lastSlopeTime < 0.08 then lastSlope else nil
			wish, amount = SurfAssist.Wish(layout, pos, state.Velocity, state.Grounded, slope)
		end
		SurfPhysics.Step(state, { WishDir = wish, WishAmount = amount, Jump = false }, DT, cast, S)
		local p = state.Position - layout.FinishCenter
		if state.Grounded and math.abs(p.X) < layout.FinishSize.X / 2 and math.abs(p.Y) < 4 and math.abs(p.Z) < layout.FinishSize.Z / 2 then
			result = string.format("PASS arena half reaches plaza in %.2fs (plaza %.0f wide)", t, layout.FinishSize.X)
			break
		end
		if state.Position.Y < layout.KillY then
			result = string.format("FAIL arena half fell at x=%.0f z=%.0f after %.1fs", state.Position.X, state.Position.Z, t)
			break
		end
	end
	result = result or "FAIL arena half timeout at " .. tostring(state.Position)
	if result:sub(1, 4) == "FAIL" then
		failed += 1
	end
	print(result)
	print(string.format("arena base x=%.0f top=%.0f plazaTop=%.0f killY=%.0f ramps end x=%.0f", layout.StartCenter.X, layout.StartCenter.Y, layout.FinishCenter.Y, layout.KillY, layout.Ramps[3].RidgeEnd.X))
end
print(`SUMMARY: {failed} failed`)
for index, def in Stages do
	local layout = StageLayout.Build(index, def, StageSpacing, StageHeight)
	print(string.format("stage %d killY %.0f finishX %.0f", index, layout.KillY, layout.FinishCenter.X))
end
if failed > 0 then
	error("stage bot failed")
end
