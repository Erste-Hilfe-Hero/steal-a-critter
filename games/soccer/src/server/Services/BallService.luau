-- Der Ball: Annehmen (klebt am Fuss), Schiessen, Passen, Tackling, Abpraller und Tor-Erkennung.
-- Ein "Actor" ist ein Spieler- oder Bot-Charakter (siehe MatchService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local BallService = {
	Services = nil :: any,
	Ball = nil :: Part?,
	Carrier = nil :: any,
	GoalsEnabled = false,
	PickupEnabled = false,
}

local HALF_L = Config.FieldLength / 2
local RADIUS = Config.BallSize / 2
local CARRY_OFFSET = CFrame.new(0, -3 + RADIUS + 0.15, -2.4)

local ball: Part
local carrierValue: ObjectValue
local trail: Trail
local weld: Weld?
local touches = {} -- { { Actor = actor, Time = number } }
local immune = {} -- [actor] = Zeitpunkt, bis zu dem dieser Actor den Ball nicht annehmen kann
local blockCooldown = {} -- [actor] = Zeitpunkt
local tackles = {} -- [actor] = Ende des Tackle-Fensters
local lastKick = { Actor = nil :: any, Time = -math.huge, Position = Vector3.zero }
local curve = { Value = 0, Until = 0 } -- Kurvenball nach dem Schuss
local lastActivity = 0 -- letzte Beruehrung (fuer die automatische Rueckkehr zur Mitte)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function setTrail(colors: { Color3 })
	local keypoints = {}
	for i, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new(if #colors == 1 then 0 else (i - 1) / (#colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, colors[1]))
	end
	trail.Color = ColorSequence.new(keypoints)
end

local function trailFor(actor): { Color3 }
	if actor and actor.Player then
		local def = Config.TrailsById[actor.Player:GetAttribute("Trail") or "white"]
		if def then
			return def.Colors
		end
	end
	if actor then
		return { Config.Teams[actor.Team].Color }
	end
	return { Color3.new(1, 1, 1) }
end

local function addTouch(actor)
	lastActivity = now()
	table.insert(touches, { Actor = actor, Time = now() })
	if #touches > 8 then
		table.remove(touches, 1)
	end
	ball:SetAttribute("LastTeam", actor.Team)
end

local function detach()
	if weld then
		weld:Destroy()
		weld = nil
	end
	BallService.Carrier = nil
	carrierValue.Value = nil
	ball.Massless = false
	ball.CanCollide = true
end

-- Ball frei machen: an Position setzen, Server uebernimmt die Physik, Geschwindigkeit geben
local function launch(position: Vector3, velocity: Vector3)
	detach()
	ball.Anchored = false
	ball.CFrame = CFrame.new(position)
	ball:SetNetworkOwner(nil)
	ball.AssemblyLinearVelocity = velocity
	ball.AssemblyAngularVelocity = Vector3.new(velocity.Z, 0, -velocity.X) / RADIUS * 0.5
	trail.Enabled = true
end

local function possess(actor)
	detach()
	ball.Anchored = false
	ball.Massless = true
	ball.CanCollide = false
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.CFrame = actor.Root.CFrame * CARRY_OFFSET
	local w = Instance.new("Weld")
	w.Part0 = actor.Root
	w.Part1 = ball
	w.C0 = CARRY_OFFSET
	w.Parent = ball
	weld = w
	BallService.Carrier = actor
	carrierValue.Value = actor.Model
	trail.Enabled = false
	curve.Until = 0
	addTouch(actor)
end

local function canAct(actor): boolean
	return actor.Humanoid.Health > 0 and (actor.StunnedUntil or 0) < now() and actor.Root.Parent ~= nil
end

local function isSaveFor(actor, velocity: Vector3): boolean
	-- Schuss eines Gegners Richtung eigenes Tor, nahe am eigenen Tor abgefangen
	local kicker = lastKick.Actor
	if not kicker or kicker.Team == actor.Team or now() - lastKick.Time > 2.5 then
		return false
	end
	local goal = BallService.Services.ArenaService:GoalCenter(actor.Team)
	local toGoal = goal - ball.Position
	return toGoal.Magnitude < 45 and velocity.Magnitude > 30 and velocity.Unit:Dot(flat(toGoal)) > 0.5
end

---------------------------------------------------------------- Aktionen

function BallService:Reset(position: Vector3?)
	detach()
	table.clear(touches)
	table.clear(immune)
	lastKick.Actor = nil
	curve.Until = 0
	lastActivity = now()
	ball:SetAttribute("LastTeam", nil)
	ball.Anchored = true
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.CFrame = CFrame.new(position or Vector3.new(0, Config.GroundY + RADIUS + 0.1, 0))
	trail.Enabled = false
end

function BallService:Unfreeze()
	if ball.Anchored and not self.Carrier then
		ball.Anchored = false
		ball:SetNetworkOwner(nil)
	end
end

-- dir: Blickrichtung (Kamera), power 0..1, spin -1..1 (Kurvenball nach links/rechts)
function BallService:Kick(actor, dir: Vector3, power: number, spin: number?)
	if self.Carrier ~= actor or not canAct(actor) then
		return
	end
	power = math.clamp(power, 0, 1)
	local forward = flat(dir)
	local lift = math.clamp(dir.Y, 0, 0.5) * 0.6
	local angle = math.rad(5 + 18 * power) + lift
	local speed = Config.KickSpeed(self.Services.MatchService:Skill(actor, "Strength")) * (0.35 + 0.65 * power)
	local velocity = (forward * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * speed
	local position = actor.Root.Position + forward * 3 + Vector3.new(0, -3 + RADIUS + 0.3, 0)
	immune[actor] = now() + Config.PickupCooldown
	lastKick.Actor = actor
	lastKick.Time = now()
	lastKick.Position = actor.Root.Position
	setTrail(trailFor(actor))
	launch(position, velocity)
	curve.Value = math.clamp(spin or 0, -1, 1)
	curve.Until = if math.abs(curve.Value) > 0.15 then now() + Config.CurveTime else 0
	lastActivity = now()
	self.Services.MatchService:OnShot(actor)
	self.Services.Net.PlaySound("Kick", position, 0.9 + power * 0.25, 0.5 + power * 0.5)
end

-- Pass zum besten Mitspieler in Blickrichtung (sonst flach nach vorne)
function BallService:Pass(actor)
	if self.Carrier ~= actor or not canAct(actor) then
		return
	end
	local facing = flat(actor.Root.CFrame.LookVector)
	local best, bestScore = nil, -math.huge
	for _, mate in self.Services.MatchService:GetActors() do
		if mate ~= actor and mate.Team == actor.Team and mate.Humanoid.Health > 0 then
			local offset = mate.Root.Position - actor.Root.Position
			local distance = offset.Magnitude
			if distance > 6 and distance < 110 then
				local dot = flat(offset):Dot(facing)
				local score = dot * 2 - distance / 60
				if dot > 0.2 and score > bestScore then
					best, bestScore = mate, score
				end
			end
		end
	end
	immune[actor] = now() + Config.PickupCooldown
	lastKick.Actor = actor
	lastKick.Time = now()
	lastKick.Position = actor.Root.Position
	lastActivity = now()
	setTrail(trailFor(actor))
	if best then
		local target = best.Root.Position + best.Root.AssemblyLinearVelocity * 0.3
		local offset = Vector3.new(target.X - actor.Root.Position.X, 0, target.Z - actor.Root.Position.Z)
		local distance = offset.Magnitude
		local speed = math.clamp(distance * 1.3 + 30, 45, 95)
		local velocity = flat(offset) * speed + Vector3.new(0, 6 + distance * 0.12, 0)
		launch(actor.Root.Position + flat(offset) * 3 + Vector3.new(0, -3 + RADIUS + 0.3, 0), velocity)
	else
		launch(actor.Root.Position + facing * 3 + Vector3.new(0, -3 + RADIUS + 0.3, 0), facing * 50 + Vector3.new(0, 6, 0))
	end
	self.Services.Net.PlaySound("Kick", actor.Root.Position, 1.15, 0.4)
end

-- Startet ein Tackle-Fenster; true, wenn das Tackling erlaubt war (Client darf dann sprinten)
function BallService:Tackle(actor): boolean
	if not canAct(actor) or self.Carrier == actor then
		return false
	end
	local level = self.Services.MatchService:Skill(actor, "Disarm")
	if (actor.TackleReadyAt or 0) > now() then
		return false
	end
	actor.TackleReadyAt = now() + Config.TackleCooldown(level)
	tackles[actor] = now() + Config.TackleWindow
	if actor.Player then
		actor.Player:SetAttribute("TackleReadyAt", actor.TackleReadyAt)
	end
	return true
end

local function stun(actor, seconds: number)
	actor.StunnedUntil = now() + seconds
	actor.Model:SetAttribute("StunnedUntil", actor.StunnedUntil)
end

-- Umhauen und wegschleudern (kein Schaden): Spieler-Charaktere bewegt ihr eigener Client
function BallService:Knock(actor, velocity: Vector3, seconds: number)
	stun(actor, seconds)
	actor.Model:SetAttribute("KnockedUntil", now() + seconds)
	if actor.Player then
		self.Services.Net.Knockback:FireClient(actor.Player, velocity)
	else
		actor.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		actor.Root.AssemblyLinearVelocity = velocity
	end
end

-- Disarm: wer im Tackle-Fenster nah genug an den gegnerischen Ballfuehrer kommt, nimmt ihm den Ball
-- direkt ab (der Ball klebt sofort am eigenen Fuss). Gemessen wird nur waagerecht.
local stealProtectUntil = 0
local function resolveSteals()
	local carrier = BallService.Carrier
	local t = now()
	for actor, ends in tackles do
		if t > ends or not actor.Root.Parent then
			tackles[actor] = nil
		elseif carrier and carrier.Team ~= actor.Team and canAct(actor) and t >= stealProtectUntil then
			local match = BallService.Services.MatchService
			local range = Config.TackleRange(match:Skill(actor, "Disarm"))
			local offset = carrier.Root.Position - actor.Root.Position
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= range and math.abs(offset.Y) < 6 then
				tackles[actor] = nil
				local chance = Config.TackleChance(match:Skill(actor, "Disarm"), match:Skill(carrier, "Dexterity"))
				if not actor.Player and carrier.Player then
					chance -= 0.2 -- Bots sollen echten Spielern den Ball nicht staendig abnehmen
				end
				if math.random() < chance then
					stun(carrier, Config.StunTime)
					immune[carrier] = t + Config.StunTime + 0.3
					possess(actor)
					stealProtectUntil = t + Config.StealProtect
					match:OnTackle(actor, carrier)
					BallService.Services.Net.PlaySound("Steal", actor.Root.Position)
				else
					stun(actor, 0.4)
					match:OnTackleMissed(actor, carrier)
					BallService.Services.Net.PlaySound("Dodge", carrier.Root.Position)
				end
				carrier = BallService.Carrier
			end
		end
	end
end

---------------------------------------------------------------- Laufende Pruefungen

local function checkPickup()
	local t = now()
	local velocity = ball.AssemblyLinearVelocity
	local bestActor, bestDistance = nil, math.huge
	for _, actor in BallService.Services.MatchService:GetActors() do
		if canAct(actor) and (immune[actor] or 0) < t then
			local feet = actor.Root.Position - Vector3.new(0, 2, 0)
			local offset = ball.Position - feet
			local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude
			local range = Config.PickupRange(BallService.Services.MatchService:Skill(actor, "Dexterity"))
			if horizontal < range and offset.Y < 5.5 and offset.Y > -2 and horizontal < bestDistance then
				bestActor, bestDistance = actor, horizontal
			end
		end
	end
	if not bestActor then
		return
	end
	local relative = (velocity - bestActor.Root.AssemblyLinearVelocity).Magnitude
	local catchSpeed = Config.CatchSpeed(BallService.Services.MatchService:Skill(bestActor, "Dexterity"))
	local save = isSaveFor(bestActor, velocity)
	if relative > catchSpeed then
		-- Zu schnell zum Annehmen: Ball prallt ab (Block). Harte gegnerische Schuesse hauen um (Smack).
		if (blockCooldown[bestActor] or 0) < t then
			blockCooldown[bestActor] = t + 0.35
			local kicker = lastKick.Actor
			if kicker and kicker.Team ~= bestActor.Team and velocity.Magnitude > Config.SmackSpeed and not save then
				BallService:Knock(bestActor, flat(velocity) * 45 + Vector3.new(0, 30, 0), Config.SmackStun)
				immune[bestActor] = t + Config.SmackStun
				BallService.Services.MatchService:OnSmack(kicker, bestActor)
				BallService.Services.Net.PlaySound("Smack", bestActor.Root.Position)
			else
				BallService.Services.Net.PlaySound("Kick", ball.Position, 0.7, 0.6)
			end
			ball.AssemblyLinearVelocity = -velocity * 0.35 + Vector3.new(0, 18, 0)
			addTouch(bestActor)
			if save then
				BallService.Services.MatchService:OnSave(bestActor)
			end
		end
		return
	end
	possess(bestActor)
	if save then
		BallService.Services.MatchService:OnSave(bestActor)
	end
end

local function checkGoal()
	local p = ball.Position
	for teamName, team in Config.Teams do
		local side = team.Side
		if p.X * side > HALF_L + RADIUS * 0.6 and math.abs(p.Z) < Config.GoalWidth / 2 and p.Y < Config.GoalHeight + Config.GroundY then
			-- Tor gegen teamName
			local scoringTeam = if teamName == "Blue" then "Red" else "Blue"
			local last = touches[#touches]
			local scorer, assist = nil, nil
			if last and last.Actor.Team == scoringTeam then
				scorer = last.Actor
				for i = #touches - 1, 1, -1 do
					local touch = touches[i]
					if touch.Actor.Team ~= scoringTeam then
						break
					end
					if touch.Actor ~= scorer then
						if now() - touch.Time < 15 then
							assist = touch.Actor
						end
						break
					end
				end
			end
			local distance = nil
			if scorer and lastKick.Actor == scorer then
				local goal = BallService.Services.ArenaService:GoalCenter(teamName)
				distance = (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(lastKick.Position.X, 0, lastKick.Position.Z)).Magnitude
			end
			BallService.GoalsEnabled = false
			BallService.Services.MatchService:OnGoal(scoringTeam, scorer, assist, distance)
			return
		end
	end
end

local function step(dt: number)
	local carrier = BallService.Carrier
	if carrier then
		if not canAct(carrier) or not carrier.Root.Parent or not BallService.Services.MatchService:IsActor(carrier) then
			launch(ball.Position, Vector3.new(0, 5, 0))
		end
	elseif not ball.Anchored then
		-- Rollreibung auf dem Boden
		local v = ball.AssemblyLinearVelocity
		if ball.Position.Y < Config.GroundY + RADIUS + 0.4 and math.abs(v.Y) < 4 then
			local factor = math.max(0, 1 - Config.BallFriction * dt)
			ball.AssemblyLinearVelocity = Vector3.new(v.X * factor, v.Y, v.Z * factor)
		end
		-- Kurvenball: Flugbahn dreht sich kurz nach dem Schuss zur Seite
		if curve.Until > now() then
			local angle = curve.Value * Config.CurveRate * dt
			local v2 = ball.AssemblyLinearVelocity
			local cos, sin = math.cos(angle), math.sin(angle)
			ball.AssemblyLinearVelocity = Vector3.new(v2.X * cos - v2.Z * sin, v2.Y, v2.X * sin + v2.Z * cos)
		end
		-- Sicherheitsnetz: aus der Welt gefallen
		if ball.Position.Y < -30 or math.abs(ball.Position.X) > 400 or math.abs(ball.Position.Z) > 400 then
			BallService:Reset()
			BallService:Unfreeze()
		elseif BallService.PickupEnabled and now() - lastActivity > Config.BallReturnSeconds then
			-- Wie im Original: liegt der Ball zu lange herum, kommt er zur Mitte zurueck
			BallService:Reset()
			BallService:Unfreeze()
			BallService.Services.Net.SendAnnounce("Ball returned to the center!", Config.Colors.Lime)
			BallService.Services.Net.PlaySound("Whistle")
		end
		if BallService.PickupEnabled then
			checkPickup()
		end
	end
	if BallService.PickupEnabled then
		resolveSteals()
	end
	if BallService.GoalsEnabled then
		checkGoal()
	end
end

---------------------------------------------------------------- Start

function BallService:Init(services)
	self.Services = services
end

function BallService:Start()
	ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * Config.BallSize
	ball.Color = Color3.fromRGB(250, 250, 250)
	ball.Material = Enum.Material.SmoothPlastic
	ball.CustomPhysicalProperties = PhysicalProperties.new(0.35, 0.4, 0.55, 1, 1)
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	ball.Anchored = true
	ball.CFrame = CFrame.new(0, Config.GroundY + RADIUS + 0.1, 0)

	-- Leucht-Look: leuchtender Ring um den Ball
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineColor = Config.Colors.Lime
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = ball
	local light = Instance.new("PointLight")
	light.Color = Config.Colors.Lime
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = ball

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.7, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.7, 0)
	a1.Parent = ball
	trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.LightEmission = 0.7
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = ball

	carrierValue = Instance.new("ObjectValue")
	carrierValue.Name = "Carrier"
	carrierValue.Parent = ball

	ball.Parent = workspace
	self.Ball = ball
	setTrail({ Color3.new(1, 1, 1) })

	RunService.Heartbeat:Connect(step)

	local net = self.Services.Net
	net.Kick.OnServerEvent:Connect(function(player, dir, power, spin)
		if typeof(dir) ~= "Vector3" or typeof(power) ~= "number" or dir.Magnitude ~= dir.Magnitude or power ~= power then
			return
		end
		if typeof(spin) ~= "number" or spin ~= spin then
			spin = 0
		end
		local actor = self.Services.MatchService:ActorForPlayer(player)
		if actor and dir.Magnitude > 0.01 then
			self:Kick(actor, dir.Unit, power, spin)
		end
	end)
	net.Pass.OnServerEvent:Connect(function(player)
		local actor = self.Services.MatchService:ActorForPlayer(player)
		if actor then
			self:Pass(actor)
		end
	end)
	net.Tackle.OnServerEvent:Connect(function(player)
		local actor = self.Services.MatchService:ActorForPlayer(player)
		if actor and self.PickupEnabled then
			self:Tackle(actor)
		end
	end)
end

function BallService:Forget(actor)
	immune[actor] = nil
	blockCooldown[actor] = nil
	tackles[actor] = nil
	if self.Carrier == actor then
		launch(ball.Position, Vector3.new(0, 5, 0))
	end
end

return BallService
