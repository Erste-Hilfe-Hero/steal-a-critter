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
local SurfPhysics = (function()
-- Surf-Bewegung wie in Counter-Strike (Quake/Source-Physik), umgerechnet auf Studs.
-- Reine Mathematik ohne Roblox-Dienste: der Client gibt eine Kollisionsfunktion "cast" mit,
-- der Test (tests/physics.luau) eine analytische Ebene.
--
-- cast(from: Vector3, delta: Vector3) -> { Distance: number, Normal: Vector3 }?
--   verschiebt die Spieler-Box (Hull) von "from" um "delta" und meldet die erste Beruehrung.
--
-- Wichtige Regeln aus Source:
--   * Flaechen mit Normal.Y >= 0.7 sind Boden (laufen, Reibung, springen).
--   * Steilere Flaechen (Surf-Rampen) zaehlen als Luft: keine Reibung, Luft-Beschleunigung mit Air-Cap.
--   * Beim Aufprall wird die Geschwindigkeit an der Flaeche "abgeschnitten" (ClipVelocity),
--     dadurch wird Fallen auf einer schraegen Rampe zu Vorwaertstempo.
local SurfPhysics = {}

local UNIT = 1 / 14 -- 1 Source-Unit in Studs (Spieler 72 Units = ca. 5 Studs)
SurfPhysics.Unit = UNIT

SurfPhysics.Settings = {
	Gravity = 800 * UNIT,
	MaxSpeed = 250 * UNIT, -- Laufen
	Accelerate = 10,
	AirAccelerate = 150, -- typischer Surf-Server-Wert
	AirCap = 30 * UNIT,
	Friction = 4,
	StopSpeed = 75 * UNIT,
	JumpSpeed = 301.993 * UNIT, -- 57 Units Sprunghoehe
	MaxVelocity = 3500 * UNIT,
	StandNormal = 0.7,
	StepHeight = 18 * UNIT,
}

local SKIN = 0.04 -- Abstand zur Wand, damit der naechste Cast nicht in der Flaeche startet
local NON_JUMP_VELOCITY = 140 * UNIT -- schneller nach oben = nicht am Boden
local ZERO = Vector3.new(0, 0, 0)
local UP = Vector3.new(0, 1, 0)
local PROBE = 1 -- so weit zurueck setzt die Rettungs-Abfrage an

-- Shapecasts (workspace:Blockcast) melden nichts, wenn die Box schon beim Start eine Flaeche beruehrt
-- oder minimal darin steckt. Dann wuerde man durch die Rampe fallen. Deshalb bei "kein Treffer"
-- einmal von aussen (entlang der letzten Kontakt-Normale bzw. von oben) zurueck auf die Box casten:
-- trifft das schon vor der Box, steckt sie in der Flaeche -> Kontakt mit Abstand 0 und Eindringtiefe.
function SurfPhysics.Recovering(raw, state)
	return function(from: Vector3, delta: Vector3)
		local hit = raw(from, delta)
		if hit then
			state.ContactNormal = hit.Normal
			return hit
		end
		local length = delta.Magnitude
		if length < 1e-6 then
			return nil
		end
		local dir = delta / length
		local hint = state.ContactNormal
		for _, k in (if hint and (hint - UP).Magnitude > 1e-3 then { hint, UP } else { UP }) do
			local back = raw(from + k * PROBE, -k * (PROBE + 0.002))
			if back and back.Distance <= PROBE + 0.001 and back.Normal:Dot(k) > 0.1 and dir:Dot(back.Normal) < -0.01 then
				state.ContactNormal = back.Normal
				return { Distance = 0, Normal = back.Normal, Depth = math.max(0, PROBE - back.Distance) }
			end
		end
		return nil
	end
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function SurfPhysics.HorizontalSpeed(v: Vector3): number
	return flat(v).Magnitude
end

-- Geschwindigkeit an einer Flaeche abschneiden (overbounce 1 = rutschen ohne Abprallen)
function SurfPhysics.Clip(velocity: Vector3, normal: Vector3, overbounce: number?): Vector3
	local backoff = velocity:Dot(normal) * (overbounce or 1)
	local out = velocity - normal * backoff
	local adjust = out:Dot(normal)
	if adjust < 0 then
		out -= normal * adjust
	end
	return out
end

function SurfPhysics.Accelerate(velocity: Vector3, wishDir: Vector3, wishSpeed: number, accel: number, dt: number): Vector3
	local current = velocity:Dot(wishDir)
	local add = wishSpeed - current
	if add <= 0 then
		return velocity
	end
	local speed = math.min(accel * wishSpeed * dt, add)
	return velocity + wishDir * speed
end

-- Luft-Strafing: nur bis AirCap in Wunschrichtung beschleunigen, die Beschleunigung selbst nutzt aber das volle Tempo.
-- Darum gewinnt man Tempo, wenn man seitlich lenkt und die Maus mitdreht.
function SurfPhysics.AirAccelerate(velocity: Vector3, wishDir: Vector3, wishSpeed: number, s, dt: number): Vector3
	local capped = math.min(wishSpeed, s.AirCap)
	local current = velocity:Dot(wishDir)
	local add = capped - current
	if add <= 0 then
		return velocity
	end
	local speed = math.min(s.AirAccelerate * wishSpeed * dt, add)
	return velocity + wishDir * speed
end

function SurfPhysics.Friction(velocity: Vector3, s, dt: number): Vector3
	local speed = velocity.Magnitude
	if speed < 0.01 then
		return ZERO
	end
	local control = math.max(speed, s.StopSpeed)
	local newSpeed = math.max(0, speed - control * s.Friction * dt)
	return velocity * (newSpeed / speed)
end

-- Box verschieben und an allen beruehrten Flaechen entlang rutschen (Quake "TryPlayerMove")
function SurfPhysics.SlideMove(position: Vector3, velocity: Vector3, dt: number, cast)
	local timeLeft = dt
	local planes = {}
	local hitFloor = nil
	local original = velocity
	for _ = 1, 4 do
		local delta = velocity * timeLeft
		local length = delta.Magnitude
		if length < 1e-5 then
			break
		end
		local hit = cast(position, delta)
		if not hit then
			position += delta
			break
		end
		local dir = delta / length
		local travel = math.max(0, hit.Distance - SKIN)
		position += dir * travel
		if hit.Depth then
			position += hit.Normal * hit.Depth
		end
		-- Mindestabstand auch senkrecht zur Flaeche halten (bei flachem Winkel waere er sonst fast 0)
		local gap = (hit.Distance - travel) * math.max(0, -dir:Dot(hit.Normal))
		if gap < SKIN then
			position += hit.Normal * (SKIN - gap)
		end
		timeLeft -= timeLeft * math.clamp(hit.Distance / length, 0, 1)
		if hit.Normal.Y >= 0.7 then
			hitFloor = hit.Normal
		end

		table.insert(planes, hit.Normal)
		velocity = SurfPhysics.Clip(velocity, hit.Normal, 1)
		-- Gegen vorherige Flaechen pruefen: in einer Rinne entlang der Kante gleiten, in einer Ecke stoppen
		for i = 1, #planes - 1 do
			if velocity:Dot(planes[i]) < -1e-4 then
				if #planes >= 3 then
					return position, ZERO, hitFloor
				end
				local crease = planes[i]:Cross(hit.Normal)
				if crease.Magnitude < 1e-4 then
					velocity = ZERO
				else
					crease = crease.Unit
					velocity = crease * crease:Dot(velocity)
				end
				break
			end
		end
		-- Nie gegen die urspruengliche Richtung zuruecklaufen (verhindert Zittern in spitzen Ecken)
		if velocity:Dot(original) <= 0 then
			velocity = ZERO
			break
		end
	end
	return position, velocity, hitFloor
end

-- Laufen mit Treppenstufen: normal und "hoch, vor, runter" probieren, das weitere Ergebnis nehmen
function SurfPhysics.StepMove(position: Vector3, velocity: Vector3, dt: number, cast, s)
	local downPos, downVel = SurfPhysics.SlideMove(position, velocity, dt, cast)

	local up = Vector3.new(0, s.StepHeight, 0)
	local hitUp = cast(position, up)
	local raised = position + (if hitUp then up.Unit * math.max(0, hitUp.Distance - SKIN) else up)
	local upPos, upVel = SurfPhysics.SlideMove(raised, velocity, dt, cast)
	local drop = Vector3.new(0, -(upPos.Y - position.Y) - SKIN, 0)
	local hitDown = cast(upPos, drop)
	if not hitDown or hitDown.Normal.Y < s.StandNormal then
		return downPos, downVel
	end
	upPos += drop.Unit * math.max(0, hitDown.Distance - SKIN)
	if flat(upPos - position).Magnitude > flat(downPos - position).Magnitude + 1e-3 then
		return upPos, Vector3.new(upVel.X, downVel.Y, upVel.Z)
	end
	return downPos, downVel
end

-- Steht die Box auf Boden? Gibt die Normale zurueck
local function groundCheck(position: Vector3, cast, s, distance: number)
	local hit = cast(position, Vector3.new(0, -distance, 0))
	if hit and hit.Normal.Y >= s.StandNormal then
		return hit
	end
	return nil
end

-- Ein Physik-Schritt. state = { Position, Velocity, Grounded }, input = { WishDir, WishAmount, Jump }
-- Rueckgabe: "Landed" (Aufprall auf Boden aus der Luft) fuer Sounds/Effekte
function SurfPhysics.Step(state, input, dt: number, cast, s)
	s = s or SurfPhysics.Settings
	cast = SurfPhysics.Recovering(cast, state)
	local position: Vector3 = state.Position
	local velocity: Vector3 = state.Velocity
	local wasGrounded = state.Grounded
	local landed = false

	-- Boden erkennen (nicht, wenn man gerade nach oben fliegt, z. B. nach einem Sprung)
	local ground = if velocity.Y > NON_JUMP_VELOCITY then nil else groundCheck(position, cast, s, SKIN * 3 + 0.02)
	local grounded = ground ~= nil

	local wishDir: Vector3 = input.WishDir
	local wishSpeed = s.MaxSpeed * math.clamp(input.WishAmount or 0, 0, 1)
	if wishDir.Magnitude < 1e-3 then
		wishDir = ZERO
		wishSpeed = 0
	end

	if grounded and input.Jump then
		velocity = Vector3.new(velocity.X, s.JumpSpeed, velocity.Z)
		grounded = false
	end

	if grounded then
		velocity = SurfPhysics.Friction(flat(velocity), s, dt)
		velocity = SurfPhysics.Accelerate(velocity, wishDir, wishSpeed, s.Accelerate, dt)
		position, velocity = SurfPhysics.StepMove(position, velocity, dt, cast, s)
		velocity = flat(velocity)
		-- Am Boden kleben bleiben, wenn es leicht bergab geht
		local snap = groundCheck(position, cast, s, s.StepHeight)
		if snap then
			position -= Vector3.new(0, math.max(0, snap.Distance - SKIN), 0)
		else
			grounded = false
		end
	else
		velocity = SurfPhysics.AirAccelerate(velocity, wishDir, wishSpeed, s, dt)
		-- Halbe Schwerkraft vor und nach der Bewegung (wie Source) fuer saubere Flugbahnen
		velocity -= Vector3.new(0, s.Gravity * dt * 0.5, 0)
		local hitFloor
		position, velocity, hitFloor = SurfPhysics.SlideMove(position, velocity, dt, cast)
		velocity -= Vector3.new(0, s.Gravity * dt * 0.5, 0)
		if hitFloor and velocity.Y <= NON_JUMP_VELOCITY then
			grounded = true
			velocity = flat(velocity)
			landed = not wasGrounded
		end
	end

	-- Tempolimit pro Achse wie sv_maxvelocity
	local m = s.MaxVelocity
	velocity = Vector3.new(math.clamp(velocity.X, -m, m), math.clamp(velocity.Y, -m, m), math.clamp(velocity.Z, -m, m))

	state.Position = position
	state.Velocity = velocity
	state.Grounded = grounded
	return landed
end

return SurfPhysics

end)()
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

for index, def in Config.Stages do
	local info = services.WorldService:GetStageInfo(index)
	check(`stage {index} zones`, info and info.Start and info.Finish and info.Start:GetAttribute("KillY") ~= nil)
	local layout = StageLayout.Build(index, def, Config.StageSpacing, Config.StageHeight)
	-- Spawn steht ueber der Startplattform
	local hit = workspace:Raycast(layout.Spawn, Vector3.new(0, -10, 0), params)
	check(`stage {index} spawn above platform`, hit and hit.Normal.Y > 0.99, hit and hit.Normal)
	-- Beide Rampenseiten sind surfbar und zeigen nach aussen (Keil-Ausrichtung)
	local r = layout.Ramps[1]
	local cf = CFrame.new(r.Ridge) * CFrame.Angles(0, 0, -math.rad(r.Pitch))
	for _, side in { -1, 1 } do
		local point = (cf * CFrame.new(r.Length / 2, 0, side * r.Width / 4)).Position
		local faceHit = workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
		local n = faceHit and faceHit.Normal
		check(`stage {index} ramp side {side} surfable`, n and n.Y > 0.2 and n.Y < SurfPhysics.Settings.StandNormal and math.sign(n.Z) == side, n)
	end
end

-- Bot faehrt jede Stage ab (gleiche Strategie wie tests/stages.luau, aber gegen die echte Map)
local S = SurfPhysics.Settings
local HULL = Vector3.new(2, 5, 2)
local DT = 1 / 100
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
for index, def in Config.Stages do
	local layout = StageLayout.Build(index, def, Config.StageSpacing, Config.StageHeight)
	local info = services.WorldService:GetStageInfo(index)
	local t = 0
	local lastSlope, lastSlopeTime = nil, -1
	local cast = function(from, delta)
		local result = workspace:Blockcast(CFrame.new(from), HULL, delta, params)
		if result then
			if result.Normal.Y < S.StandNormal and result.Normal.Y > 0 then
				lastSlope, lastSlopeTime = result.Normal, t
			end
			return { Distance = result.Distance, Normal = result.Normal }
		end
		return nil
	end
	local state = { Position = layout.Spawn + Vector3.new(0, 2.5 - 3, 0), Velocity = Vector3.zero, Grounded = false }
	local outcome
	while t < 90 do
		t += DT
		local pos = state.Position
		local target
		for _, r in layout.Ramps do
			if r.RidgeEnd.X > pos.X - 1 then
				target = r
				break
			end
		end
		local wish, amount = Vector3.zero, 0
		if state.Grounded and pos.X < 0 then
			wish, amount = Vector3.new(1, 0, 0), 1
		elseif lastSlope and t - lastSlopeTime < 0.08 then
			wish, amount = Vector3.new(0, 0, if lastSlope.Z < 0 then 1 else -1), 1
		else
			local goal = if target
				then Vector3.new(math.max(target.Ridge.X + 25, pos.X + 40), 0, target.Ridge.Z + (if pos.Z >= target.Ridge.Z then 1 else -1) * target.Width * 0.25)
				else Vector3.new(layout.FinishCenter.X, 0, layout.FinishCenter.Z)
			local v = flat(state.Velocity)
			local h = flat(goal - pos)
			if v.Magnitude > 1 and h.Magnitude > 1 then
				v, h = v.Unit, h.Unit
				local perp = Vector3.new(-v.Z, 0, v.X)
				if perp:Dot(h) < 0 then
					perp = -perp
				end
				if v:Dot(h) < math.cos(math.rad(2)) then
					wish, amount = perp, 1
				end
			end
		end
		SurfPhysics.Step(state, { WishDir = wish, WishAmount = amount, Jump = false }, DT, cast, S)
		local localPos = info.Finish.CFrame:PointToObjectSpace(state.Position)
		local half = info.Finish.Size / 2
		if math.abs(localPos.X) < half.X and math.abs(localPos.Y) < half.Y and math.abs(localPos.Z) < half.Z then
			outcome = string.format("%.2fs", t)
			break
		end
		if state.Position.Y - 2.5 < layout.KillY then
			outcome = string.format("fell at %s after %.1fs", tostring(state.Position), t)
			break
		end
	end
	check(`bot clears stage {index} {def.Name}`, outcome ~= nil and outcome:sub(1, 4) ~= "fell", outcome or "timeout")
end

return finish()
