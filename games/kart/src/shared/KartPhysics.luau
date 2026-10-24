-- Arcade-Fahrphysik eines Karts (vom Client fuer das eigene Kart genutzt, vom Smoke-Test auf dem Server):
-- Gas/Bremse/Lenkung, Drift mit 3 Turbo-Stufen, Boost-Pads, Schweben ueber der Fahrbahn, Wand-Abprall, Respawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Tracks = require(ReplicatedStorage.Shared.Tracks)

local KartPhysics = {}

export type State = {
	Stats: any,
	Yaw: number,
	Vy: number,
	Up: Vector3,
	OnGround: boolean,
	Speed: number,
	BoostTime: number,
	BoostPower: number,
	Drifting: boolean,
	DriftDir: number,
	DriftCharge: number,
	DriftTier: number,
	SpinTime: number,
	SpinAngle: number,
	InfernoTime: number,
	LastIndex: number,
	OffTrackTime: number,
	AirTime: number,
}

export type Input = { Throttle: number, Steer: number, Drift: boolean, Respawn: boolean? }

function KartPhysics.new(kartId: string, root: BasePart, geo: Tracks.Geometry): State
	local look = root.CFrame.LookVector
	return {
		Stats = Config.KartsById[kartId] or Config.Karts[1],
		Yaw = math.atan2(-look.X, -look.Z),
		Vy = 0,
		Up = Vector3.yAxis,
		OnGround = false,
		Speed = 0,
		BoostTime = 0,
		BoostPower = 1,
		Drifting = false,
		DriftDir = 0,
		DriftCharge = 0,
		DriftTier = 0,
		SpinTime = 0,
		SpinAngle = 0,
		InfernoTime = 0,
		LastIndex = Tracks.Nearest(geo, root.Position),
		OffTrackTime = 0,
		AirTime = 0,
	}
end

function KartPhysics.Boost(state: State, seconds: number, power: number?)
	state.BoostPower = math.max(if state.BoostTime > 0 then state.BoostPower else 1, power or Config.BoostMultiplier)
	state.BoostTime = math.max(state.BoostTime, seconds)
	state.Speed = math.max(state.Speed, state.Stats.Speed * 1.05)
end

function KartPhysics.Spin(state: State, seconds: number): boolean
	if state.InfernoTime > 0 then
		return false
	end
	state.SpinTime = seconds
	state.Drifting = false
	state.DriftCharge = 0
	state.DriftTier = 0
	return true
end

function KartPhysics.Respawn(state: State, root: BasePart, geo: Tracks.Geometry)
	local i = state.LastIndex
	local tangent = geo.Tangents[i]
	local pos = geo.Points[i] + Vector3.new(0, Config.HoverHeight + 2, 0)
	state.Yaw = math.atan2(-tangent.X, -tangent.Z)
	root.CFrame = CFrame.lookAt(pos, pos + Vector3.new(tangent.X, 0, tangent.Z))
	root.AssemblyLinearVelocity = Vector3.zero
	state.Speed = 0
	state.Vy = 0
	state.OffTrackTime, state.AirTime = 0, 0
	state.Drifting = false
	state.DriftCharge = 0
	state.DriftTier = 0
end

-- Ein Physik-Schritt. Gibt Ereignisse zurueck ("DriftStart", "DriftTier", "Boost", "Bump", "Respawn").
function KartPhysics.Step(state: State, root: BasePart, geo: Tracks.Geometry, input: Input, dt: number, coins: number, roadParams: RaycastParams, wallParams: RaycastParams): { string }
	local events = {}
	local stats = state.Stats
	local throttle, steer = input.Throttle, input.Steer

	state.BoostTime = math.max(0, state.BoostTime - dt)
	state.InfernoTime = math.max(0, state.InfernoTime - dt)
	if state.SpinTime > 0 then
		state.SpinTime -= dt
		state.SpinAngle += dt * 15
		throttle, steer = 0, 0
	else
		state.SpinAngle = 0
	end

	-- Geschwindigkeit
	local maxSpeed = stats.Speed * (1 + math.min(coins, Config.MaxRaceCoins) * Config.CoinSpeedBonus)
	if state.BoostTime > 0 then
		maxSpeed *= state.BoostPower
	else
		state.BoostPower = 1
	end
	local speed = state.Speed
	if state.SpinTime > 0 then
		speed = math.max(0, speed - 75 * dt)
	elseif throttle > 0.1 then
		local target = maxSpeed * throttle
		if speed < target then
			speed = math.min(target, speed + stats.Accel * dt * (if state.BoostTime > 0 then 3 else 1))
		else
			speed = math.max(target, speed - 30 * dt)
		end
	elseif throttle < -0.1 then
		speed = if speed > 0 then math.max(0, speed - 75 * dt) else math.max(-24, speed - 30 * dt)
	else
		speed += math.clamp(-speed, -22 * dt, 22 * dt)
	end

	-- Drift: halten + lenken laedt den Turbo, loslassen zuendet ihn
	if input.Drift and not state.Drifting and math.abs(steer) > 0.3 and speed > 28 and state.OnGround and state.SpinTime <= 0 then
		state.Drifting = true
		state.DriftDir = if steer > 0 then 1 else -1
		state.DriftCharge = 0
		state.Vy = 9
		table.insert(events, "DriftStart")
	end
	if state.Drifting then
		state.DriftCharge += dt * (if steer * state.DriftDir > 0 then 1.6 else 1)
		local tier = 0
		for k, need in Config.DriftTiers do
			if state.DriftCharge >= need then
				tier = k
			end
		end
		if tier ~= state.DriftTier then
			state.DriftTier = tier
			table.insert(events, "DriftTier")
		end
		if not input.Drift or speed < 18 or state.SpinTime > 0 then
			state.Drifting = false
			if tier > 0 and state.SpinTime <= 0 then
				KartPhysics.Boost(state, Config.DriftBoostTimes[tier])
				speed = state.Speed
				table.insert(events, "Boost")
			end
			state.DriftTier = 0
			state.DriftCharge = 0
		end
	end

	-- Lenkung
	local grip = math.clamp(math.abs(speed) / 22, 0, 1)
	local turn
	if state.Drifting then
		turn = stats.Turn * (state.DriftDir * 0.62 + steer * 0.5) * grip
	else
		turn = stats.Turn * steer * grip * (if speed >= 0 then 1 else -1) * (if speed > stats.Speed * 0.9 then 0.85 else 1)
	end
	state.Yaw -= turn * dt

	-- Boden: schweben, Steigungen folgen, Boost-Pads
	local pos = root.Position
	local ray = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -(Config.HoverHeight + 7), 0), roadParams)
	local forward = Vector3.new(-math.sin(state.Yaw), 0, -math.cos(state.Yaw))
	local velocity = forward * speed
	if ray and pos.Y - ray.Position.Y < Config.HoverHeight + 1.4 and state.Vy <= 6 then
		state.OnGround = true
		state.AirTime = 0
		local normal = ray.Normal
		state.Up = state.Up:Lerp(normal, math.min(1, dt * 10)).Unit
		local planar = velocity - normal * velocity:Dot(normal)
		velocity = if planar.Magnitude > 0.001 then planar.Unit * math.abs(speed) else Vector3.zero
		state.Vy = 0
		velocity += Vector3.new(0, (ray.Position.Y + Config.HoverHeight - pos.Y) * 14, 0)
		if ray.Instance:GetAttribute("BoostPad") then
			if state.BoostTime < 0.9 then
				table.insert(events, "Boost")
			end
			KartPhysics.Boost(state, 1.1)
			speed = state.Speed
		end
	else
		state.OnGround = false
		state.AirTime += dt
		state.Vy -= Config.Gravity * dt
		velocity += Vector3.new(0, state.Vy, 0)
		state.Up = state.Up:Lerp(Vector3.yAxis, math.min(1, dt * 3)).Unit
	end

	-- Waende: frontal abprallen, schraeg entlanggleiten
	local flatVel = Vector3.new(velocity.X, 0, velocity.Z)
	if flatVel.Magnitude > 1 then
		local wall = workspace:Raycast(pos, flatVel.Unit * (4.2 + flatVel.Magnitude * dt), wallParams)
		if wall then
			local n = Vector3.new(wall.Normal.X, 0, wall.Normal.Z)
			if n.Magnitude > 0.1 then
				n = n.Unit
				local dir = flatVel.Unit
				local along = dir - n * dir:Dot(n)
				local headOn = -dir:Dot(n)
				if headOn > 0.75 or along.Magnitude < 0.2 then
					speed = -speed * 0.3
					table.insert(events, "Bump")
				else
					along = along.Unit
					state.Yaw = math.atan2(-along.X, -along.Z)
					speed *= 1 - headOn * 0.5
				end
				pos = Vector3.new(wall.Position.X, pos.Y, wall.Position.Z) + n * 4.3
				root.CFrame = CFrame.new(pos) * root.CFrame.Rotation
				forward = Vector3.new(-math.sin(state.Yaw), 0, -math.cos(state.Yaw))
				velocity = forward * speed + Vector3.new(0, velocity.Y, 0)
			end
		end
	end
	state.Speed = speed

	-- Fortschritt merken, Absturz oder Abseits erkennen
	local index, distance = Tracks.Nearest(geo, pos, state.LastIndex, 10, 30)
	if distance < geo.Width * 0.5 + 4 and state.OnGround then
		state.LastIndex = index
		state.OffTrackTime = 0
	else
		state.OffTrackTime += dt
	end
	if input.Respawn or pos.Y < geo.MinY - 30 or state.OffTrackTime > 2.5 or state.AirTime > 4 then
		KartPhysics.Respawn(state, root, geo)
		table.insert(events, "Respawn")
		return events
	end

	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.zero

	-- Ausrichtung: Fahrtrichtung + Drift-Anstellwinkel + Dreher, an der Fahrbahn ausgerichtet
	local visualYaw = state.Yaw + state.SpinAngle - (if state.Drifting then state.DriftDir * 0.38 else 0)
	local look = Vector3.new(-math.sin(visualYaw), 0, -math.cos(visualYaw))
	local right = look:Cross(state.Up).Unit
	local fwd = state.Up:Cross(right).Unit
	root.CFrame = CFrame.fromMatrix(root.Position, right, state.Up, -fwd)
	return events
end

-- Einfacher Autopilot: lenkt auf einen Punkt einige Abschnitte voraus (nach dem Ziel und im Smoke-Test)
function KartPhysics.Autopilot(state: State, root: BasePart, geo: Tracks.Geometry, lookahead: number?): (number, number)
	local target = geo.Points[(state.LastIndex + (lookahead or 4) - 1) % geo.Count + 1]
	local to = target - root.Position
	local desired = math.atan2(-to.X, -to.Z)
	local diff = (desired - state.Yaw + math.pi) % (2 * math.pi) - math.pi
	return math.clamp(-diff * 2.5, -1, 1), 1
end

return KartPhysics
