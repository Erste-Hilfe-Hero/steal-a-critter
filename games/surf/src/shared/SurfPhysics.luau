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
