-- Simulationstest der Surf-Physik mit analytischen Ebenen (luau tests/physics.luau)
-- Vector3 und SurfPhysics fuegt tests/run_physics.sh davor ein (das luau-CLI kennt kein Vector3)
local S = SurfPhysics.Settings
local HALF = Vector3.new(1, 2.5, 1) -- halbe Hull-Groesse
local failed = 0
local function check(name, ok, detail)
	if not ok then
		failed += 1
	end
	print((if ok then "PASS " else "FAIL ") .. name .. " " .. tostring(detail or ""))
end

-- Welt aus Ebenen {N = Normale, D = Abstand}; Hull = Box, Kontakt ueber Stuetzradius
local function makeCast(planes)
	return function(from, delta)
		local best
		for _, p in planes do
			local n = p.N
			local r = math.abs(n.X) * HALF.X + math.abs(n.Y) * HALF.Y + math.abs(n.Z) * HALF.Z
			local dist = n:Dot(from) - p.D - r
			local approach = -n:Dot(delta)
			if approach > 1e-9 and dist >= -1e-6 then
				local t = dist / approach
				if t <= 1 and (not best or t < best.T) then
					best = { T = t, Distance = math.max(0, t) * delta.Magnitude, Normal = n }
				end
			end
		end
		return best
	end
end

local DT = 1 / 66
local function run(state, planes, seconds, inputFn)
	local cast = makeCast(planes)
	for i = 1, math.floor(seconds / DT) do
		SurfPhysics.Step(state, inputFn(state, i), DT, cast, S)
	end
	return state
end

-- 1) Laufen auf flachem Boden
local floor = { N = Vector3.new(0, 1, 0), D = 0 }
local st = { Position = Vector3.new(0, 2.5 + 0.03, 0), Velocity = Vector3.zero, Grounded = false }
run(st, { floor }, 2, function()
	return { WishDir = Vector3.new(1, 0, 0), WishAmount = 1, Jump = false }
end)
check("walk speed ~ MaxSpeed", math.abs(st.Velocity.Magnitude - S.MaxSpeed) < 0.2, st.Velocity.Magnitude)
check("stays grounded", st.Grounded and math.abs(st.Position.Y - 2.5) < 0.1, st.Position.Y)

-- 2) Reibung stoppt
run(st, { floor }, 1, function()
	return { WishDir = Vector3.zero, WishAmount = 0, Jump = false }
end)
check("friction stops", st.Velocity.Magnitude < 0.01, st.Velocity.Magnitude)

-- 3) Sprunghoehe ~ 57 Units
local maxY = 0
local jumped = false
run(st, { floor }, 1.5, function(s)
	maxY = math.max(maxY, s.Position.Y - 2.5)
	local j = not jumped
	jumped = true
	return { WishDir = Vector3.zero, WishAmount = 0, Jump = j }
end)
check("jump height ~4 studs", math.abs(maxY - 57 / 14) < 0.3, maxY)
check("lands again", st.Grounded, st.Position.Y)

-- 4) Surf-Rampe: 56 Grad steile Flaeche, Spieler drueckt in die Rampe (Strafe) und schaut nach vorne (+X)
local angle = math.rad(56)
local rampN = Vector3.new(0, math.cos(angle), -math.sin(angle))
check("ramp is surfable", rampN.Y < S.StandNormal, rampN.Y)
local ramp = { N = rampN, D = 0 }
st = { Position = Vector3.new(0, 20, 0), Velocity = Vector3.new(S.MaxSpeed, 0, 0), Grounded = false }
local onRamp = 0
local cast = makeCast({ ramp })
local lowestDist = math.huge
for i = 1, 66 * 4 do
	SurfPhysics.Step(st, { WishDir = Vector3.new(0, 0, 1), WishAmount = 1, Jump = false }, DT, cast, S)
	local r = math.abs(rampN.X) * HALF.X + math.abs(rampN.Y) * HALF.Y + math.abs(rampN.Z) * HALF.Z
	local d = rampN:Dot(st.Position) - r
	lowestDist = math.min(lowestDist, d)
	if d < 0.2 then
		onRamp += 1
	end
end
check("never inside ramp", lowestDist > -0.01, lowestDist)
check("rides the ramp", onRamp > 150, onRamp)
check("not grounded on ramp", not st.Grounded)
print("   holding into ramp 4s: pos", st.Position, "vel", st.Velocity, "speed u/s", math.floor(st.Velocity.Magnitude / SurfPhysics.Unit))

-- 4b) Rampe faellt in Laufrichtung leicht ab (wie in der Map): reinhalten bringt Tempo
local pitch = math.rad(10)
local pitchedN = Vector3.new(math.cos(angle) * math.sin(pitch), math.cos(angle) * math.cos(pitch), -math.sin(angle))
st = { Position = Vector3.new(0, 20, 0), Velocity = Vector3.new(S.MaxSpeed, 0, 0), Grounded = false }
run(st, { { N = pitchedN, D = 0 } }, 4, function()
	return { WishDir = Vector3.new(0, 0, 1), WishAmount = 1, Jump = false }
end)
check("pitched ramp gives speed", st.Velocity.Magnitude > 45, st.Velocity.Magnitude)
print("   pitched ramp 4s: pos", st.Position, "vel", st.Velocity, "speed u/s", math.floor(st.Velocity.Magnitude / SurfPhysics.Unit))

-- 5) Runter-Surfen ohne Strafe: man rutscht ab und wird schnell (Fall wird zu Tempo)
st = { Position = Vector3.new(0, 20, 0), Velocity = Vector3.new(S.MaxSpeed, 0, 0), Grounded = false }
run(st, { ramp }, 2, function()
	return { WishDir = Vector3.zero, WishAmount = 0, Jump = false }
end)
check("sliding gains speed", st.Velocity.Magnitude > 60, st.Velocity.Magnitude)
print("   free slide 2s: pos", st.Position, "vel", st.Velocity)

-- 6) Luft-Strafing: Wunschrichtung immer senkrecht zur Flugrichtung (Maus dreht mit) = Tempo steigt
st = { Position = Vector3.new(0, 1000, 0), Velocity = Vector3.new(S.MaxSpeed, 0, 0), Grounded = false }
local startSpeed = SurfPhysics.HorizontalSpeed(st.Velocity)
run(st, {}, 3, function(s)
	local h = Vector3.new(s.Velocity.X, 0, s.Velocity.Z).Unit
	return { WishDir = Vector3.new(-h.Z, 0, h.X), WishAmount = 1, Jump = false }
end)
check("air strafe gains speed", SurfPhysics.HorizontalSpeed(st.Velocity) > startSpeed * 1.5, SurfPhysics.HorizontalSpeed(st.Velocity))

-- 7) Geradeaus in der Luft (W) bringt fast nichts (Air-Cap)
st = { Position = Vector3.new(0, 1000, 0), Velocity = Vector3.new(S.MaxSpeed, 0, 0), Grounded = false }
run(st, {}, 3, function()
	return { WishDir = Vector3.new(1, 0, 0), WishAmount = 1, Jump = false }
end)
check("forward in air capped", SurfPhysics.HorizontalSpeed(st.Velocity) < S.MaxSpeed + 0.01, SurfPhysics.HorizontalSpeed(st.Velocity))

-- 8) Treppenstufe: 1 Stud hohe Kante wird beim Laufen genommen
local stepCast = function(from, delta)
	-- Boden y=0 fuer x<5, y=1 fuer x>=5 (Box-Hull)
	local best
	local function consider(t, n)
		if t >= 0 and t <= 1 and (not best or t < best.T) then
			best = { T = t, Distance = t * delta.Magnitude, Normal = n }
		end
	end
	local bottom = from.Y - HALF.Y
	-- Boden unten
	if delta.Y < 0 then
		local floorY = if from.X + HALF.X > 5 then 1 else 0
		local t = (bottom - floorY) / -delta.Y
		consider(t, Vector3.new(0, 1, 0))
	end
	-- Stufenwand bei x=5 (nur wenn Box unter Stufenoberkante)
	if delta.X > 0 and bottom < 1 - 1e-6 and from.X + HALF.X <= 5 + 1e-6 then
		local t = (5 - (from.X + HALF.X)) / delta.X
		consider(t, Vector3.new(-1, 0, 0))
	end
	return best
end
st = { Position = Vector3.new(0, 2.5 + 0.03, 0), Velocity = Vector3.zero, Grounded = true }
for _ = 1, 66 * 2 do
	SurfPhysics.Step(st, { WishDir = Vector3.new(1, 0, 0), WishAmount = 1, Jump = false }, DT, stepCast, S)
end
check("walks up a step", st.Position.X > 10 and st.Position.Y > 3.4, st.Position)

print(`SUMMARY: {failed} failed`)
if failed > 0 then
	error("physics tests failed")
end
