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
local lastKick = { Actor = nil :: any, Time = -math.huge, Position = Vector3.zero }
local curve = { Value = 0, Until = 0 } -- Kurvenball nach dem Schuss
local lastActivity = 0 -- letzte Beruehrung (fuer die automatische Rueckkehr zur Mitte)
-- Powerplay wie im Original: Paesse zu immer neuen Mitspielern machen die Schuesse staerker (bis 5)
local powerPlay = { Team = nil :: string?, Count = 0 }
local lastHolder = nil :: any
local lastHolderLost = 0

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
	if BallService.Carrier then
		lastHolderLost = now()
	end
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


local function setPowerPlay(team: string?, count: number)
	powerPlay.Team = team
	powerPlay.Count = count
	workspace:SetAttribute("PowerPlayTeam", team)
	workspace:SetAttribute("PowerPlay", count)
end

-- Ball angenommen: Powerplay weiterzaehlen oder zuruecksetzen; Ball vom Gegner geholt = Steal
local function onReceive(actor)
	local previous = lastHolder
	if previous and previous ~= actor then
		if previous.Team == actor.Team then
			BallService.Services.ExtrasService:OnPass(previous)
			if now() - lastHolderLost < 6 then
				setPowerPlay(actor.Team, math.min(Config.MaxPowerPlay, (if powerPlay.Team == actor.Team then powerPlay.Count else 0) + 1))
			end
		else
			setPowerPlay(actor.Team, 0)
			if now() - lastHolderLost < 4 then
				BallService.Services.MatchService:OnTackle(actor, previous)
			end
		end
	elseif not previous then
		setPowerPlay(actor.Team, 0)
	end
	lastHolder = actor
	BallService.Services.PlusService:OnReceive(actor, previous)
	BallService.Services.Net.PlaySound("GotBall", ball.Position)
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
	lastHolder = nil
	setPowerPlay(nil, 0)
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
	-- Spieler: auch ein kurzer Schuss hat Wumms (Bots behalten die alte Kurve)
	local factor = if actor.Player then Config.MinShotPower + (1 - Config.MinShotPower) * power else 0.35 + 0.65 * power
	local speed = Config.KickSpeed(self.Services.MatchService:Skill(actor, "Strength")) * factor
	if powerPlay.Team == actor.Team then
		speed *= 1 + Config.PowerPlayBonus * powerPlay.Count
	end
	if actor.Player and actor.Player:GetAttribute("Pass_CannonShot") == true then
		speed *= Config.CannonShotPower
	end
	speed *= self.Services.ExtrasService:KickMultiplier(actor)
	speed *= self.Services.PlusService:ShotBonus(actor)
	local position = actor.Root.Position + forward * 3 + Vector3.new(0, -3 + RADIUS + 0.3, 0)
	-- Schuss-Hilfe: Richtung Tor gezielt -> fliegt aufs Tor, in die Ecke weg vom Torwart
	local target = if actor.Player then self:AssistTarget(actor, forward) else nil
	if target then
		local offset = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		forward = flat(offset)
		angle, speed = Config.ShotArc(offset.Magnitude, target.Y - position.Y, speed, workspace.Gravity)
		spin = 0
	end
	self.Services.ExtrasService:OnKick(actor, speed)
	local velocity = (forward * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * speed
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
	self.Services.PlusService:OnKick(actor, speed, target ~= nil)
	self.Services.Net.PlaySound("Kick", position, 0.9 + power * 0.25, 0.5 + power * 0.5)
end

-- Zielpunkt im gegnerischen Tor (nil, wenn nicht Richtung Tor gezielt); weicht dem Torwart aus
function BallService:AssistTarget(actor, forward: Vector3): Vector3?
	local enemy = if actor.Team == "Blue" then "Red" else "Blue"
	local goal = self.Services.ArenaService:GoalCenter(enemy)
	local keeperZ, best = nil, 25
	for _, other in self.Services.MatchService:GetActors() do
		if other.Team == enemy and other.Humanoid.Health > 0 then
			local offset = other.Root.Position - goal
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance < best then
				keeperZ, best = other.Root.Position.Z, distance
			end
		end
	end
	return Config.ShotTarget(actor.Root.Position, forward, goal, keeperZ)
end

-- Kopfball: freier Ball in der Luft prallt vom Kopf eines springenden Actors ab
function BallService:Header(actor, velocity: Vector3)
	if self.Carrier ~= nil or ball.Anchored then
		return
	end
	immune[actor] = now() + 0.4
	lastKick.Actor = actor
	lastKick.Time = now()
	lastKick.Position = actor.Root.Position
	addTouch(actor)
	setTrail(trailFor(actor))
	launch(ball.Position, velocity)
	self.Services.Net.PlaySound("Kick", ball.Position, 1.25, 0.6)
end

function BallService:LastKick()
	return lastKick.Actor, lastKick.Time
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

-- Disarm wie im Original: ein Messertreffer am Ballfuehrer laesst ihn den Ball verlieren (er rollt nach vorne weg)
function BallService:Disarm(attacker, victim): boolean
	if self.Carrier ~= victim then
		return false
	end
	-- Trick (SKILL) macht kurz unantastbar
	if (victim.Model:GetAttribute("SkillUntil") or 0) > now() then
		return false
	end
	local push = flat(victim.Root.Position - attacker.Root.Position)
	immune[victim] = now() + 1
	launch(victim.Root.Position + push * 2 + Vector3.new(0, -3 + RADIUS + 0.5, 0), push * 24 + Vector3.new(0, 14, 0))
	self.Services.Net.PlaySound("Steal", victim.Root.Position)
	return true
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
			local range = Config.PickupRange(BallService.Services.MatchService:Skill(actor, "Dexterity")) * (if Config.Has(actor.Player, "MagnetFeet") then Config.MagnetFeetRange else 1)
			if horizontal < range and offset.Y < 5.5 and offset.Y > -2 and horizontal < bestDistance then
				bestActor, bestDistance = actor, horizontal
			end
		end
	end
	if not bestActor then
		return
	end
	local relative = (velocity - bestActor.Root.AssemblyLinearVelocity).Magnitude
	local catchSpeed = Config.CatchSpeed(BallService.Services.MatchService:Skill(bestActor, "Dexterity")) * (if Config.Has(bestActor.Player, "SteelKeeper") then Config.SteelKeeperFactor else 1)
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
				BallService.Services.CombatService:Damage(bestActor, Config.SmackDamage(velocity.Magnitude), kicker, "Smack")
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
	onReceive(bestActor)
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
			BallService.Services.Net.PlaySound("Returned")
		end
		if BallService.PickupEnabled then
			checkPickup()
		end
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

	-- Aufprall-Geraeusch wie im Original ("bounce"), gedrosselt
	local lastBounce = 0
	ball.Touched:Connect(function(part)
		local t = now()
		if t - lastBounce < 0.25 or part:FindFirstAncestorOfClass("Model") and part:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then
			return
		end
		local speed = ball.AssemblyLinearVelocity.Magnitude
		if speed > 18 then
			lastBounce = t
			BallService.Services.Net.PlaySound("Bounce", ball.Position, 0.9 + math.random() * 0.2, math.clamp(speed / 90, 0.2, 0.8))
		end
	end)

	local net = self.Services.Net
	net.Kick.OnServerEvent:Connect(function(player, dir, power, spin)
		-- NaN und unendliche Werte abweisen (sonst bekommt der Ball eine NaN-Geschwindigkeit)
		if typeof(dir) ~= "Vector3" or typeof(power) ~= "number" or dir.Magnitude ~= dir.Magnitude or dir.Magnitude == math.huge or power ~= power then
			return
		end
		if typeof(spin) ~= "number" or spin ~= spin or math.abs(spin) == math.huge then
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
	net.Tackle.OnServerEvent:Connect(function(player, aim)
		local actor = self.Services.MatchService:ActorForPlayer(player)
		if actor then
			self.Services.CombatService:Swing(actor, "Slash", aim)
		else
			self.Services.DiagService:Count("tackleNoActor")
			if player.Character then
				task.spawn(self.Services.MatchService.OnCharacterAdded, self.Services.MatchService, player, player.Character)
			end
		end
	end)
end

function BallService:Forget(actor)
	immune[actor] = nil
	blockCooldown[actor] = nil
	if self.Carrier == actor then
		launch(ball.Position, Vector3.new(0, 5, 0))
	end
end

return BallService
