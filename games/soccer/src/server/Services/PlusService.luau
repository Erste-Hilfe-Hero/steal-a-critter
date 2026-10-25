-- Plus-Features: Super-Schuss-Leiste, Direktschuss nach Pass, Kopfball, Speed- und Sprung-Pads, Trick (SKILL),
-- Ballbesitz- und Schuss-Statistik, Wochenend-Coins, Comeback-Hilfe, Staub beim Sprinten und die Modi
-- QUICK MATCH / BOUNCY BALL / SUPER SHOTS. Alle Hooks laufen geschuetzt, ein Fehler hier stoppt nie ein Tor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local PlusService = { Services = nil :: any }

local C = Config.Colors

local remote: RemoteEvent
local super = {} -- [actor] = 0..SuperMax
local received = {} -- [actor] = { Time, FromPass }
local skillReady = {} -- [Player] = Zeitpunkt
local headerReady = {} -- [actor] = Zeitpunkt
local padReady = {} -- [actor] = Zeitpunkt (nur Bots, Spieler macht das ihr Client)
local possession = { Blue = 0, Red = 0 }
local shots = { Blue = 0, Red = 0 }
local dust = {} -- [actor] = ParticleEmitter
local defaultBall: PhysicalProperties? = nil

local function now(): number
	return workspace:GetServerTimeNow()
end

local function services()
	return PlusService.Services
end

local function safe(name: string, fn: () -> any): any
	local ok, result = pcall(fn)
	if not ok then
		warn(`[PlusService] {name}: {result}`)
		return nil
	end
	return result
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function mode()
	return Config.ModesById[workspace:GetAttribute("Mode") or "Classic"] or Config.ModesById.Classic
end

local function setSuper(actor, value: number)
	value = math.clamp(value, 0, Config.SuperMax)
	super[actor] = value
	actor.Model:SetAttribute("Super", value)
	if actor.Player then
		actor.Player:SetAttribute("Super", value)
	end
end

---------------------------------------------------------------- Super-Leiste und Schuss-Boni

function PlusService:AddSuper(actor, amount: number)
	safe("AddSuper", function()
		if not actor or not actor.Model then
			return
		end
		local rate = mode().SuperRate or 1
		-- Comeback: wer weit hinten liegt, laedt doppelt so schnell
		local mine = workspace:GetAttribute("Score" .. actor.Team) or 0
		local theirs = workspace:GetAttribute("Score" .. (if actor.Team == "Blue" then "Red" else "Blue")) or 0
		if theirs - mine >= Config.ComebackDeficit then
			rate *= 2
		end
		local before = super[actor] or 0
		setSuper(actor, before + amount * rate)
		if before < Config.SuperMax and (super[actor] or 0) >= Config.SuperMax and actor.Player then
			services().Net.SendNotify(actor.Player, "SUPER SHOT READY!", C.Orange)
		end
	end)
end

-- Multiplikator fuer den naechsten Schuss: volle Super-Leiste und Direktschuss nach einem Pass
function PlusService:ShotBonus(actor): number
	return safe("ShotBonus", function()
		local multiplier = 1
		actor.PlusSuper = false
		actor.PlusOneTouch = false
		if (super[actor] or 0) >= Config.SuperMax then
			multiplier *= Config.SuperPower
			setSuper(actor, 0)
			actor.PlusSuper = true
		end
		local info = received[actor]
		if info and info.FromPass and now() - info.Time <= Config.OneTouchWindow then
			multiplier *= Config.OneTouchPower
			actor.PlusOneTouch = true
		end
		return multiplier
	end) or 1
end

function PlusService:OnKick(actor, speed: number, onTarget: boolean)
	safe("OnKick", function()
		received[actor] = nil
		if onTarget then
			shots[actor.Team] += 1
		end
		local ball = services().BallService.Ball
		if actor.PlusSuper and ball then
			local fire = Instance.new("Fire")
			fire.Heat = 12
			fire.Size = 6
			fire.Color = Color3.fromRGB(255, 140, 30)
			fire.SecondaryColor = Color3.fromRGB(255, 230, 80)
			fire.Parent = ball
			task.delay(1.6, function()
				fire:Destroy()
			end)
			services().Net.SendAnnounce(`SUPER SHOT by {actor.Name}!`, C.Orange)
		end
		if actor.Player then
			remote:FireClient(actor.Player, "Shot", { Speed = math.floor(speed), Super = actor.PlusSuper == true, OneTouch = actor.PlusOneTouch == true, OnTarget = onTarget })
		end
	end)
end

function PlusService:OnReceive(actor, previous)
	safe("OnReceive", function()
		local fromPass = previous ~= nil and previous ~= actor and previous.Team == actor.Team
		received[actor] = { Time = now(), FromPass = fromPass }
		if fromPass then
			self:AddSuper(previous, Config.SuperGain.Pass)
		elseif previous ~= nil and previous.Team ~= actor.Team then
			self:AddSuper(actor, Config.SuperGain.Steal)
		end
		self:AddSuper(actor, Config.SuperGain.Touch)
	end)
end

---------------------------------------------------------------- Trick (SKILL): kurz unantastbar, der Client macht den Sprint

local function onSkill(player: Player)
	local actor = services().MatchService:ActorForPlayer(player)
	if not actor or (skillReady[player] or 0) > now() or workspace:GetAttribute("MatchState") ~= "Playing" then
		return
	end
	skillReady[player] = now() + Config.SkillCooldown - 0.3
	if services().BallService.Carrier == actor then
		actor.Model:SetAttribute("SkillUntil", now() + Config.SkillSeconds)
	end
	services().Net.PlaySound("Call", actor.Root.Position, 1.6, 0.4)
end

---------------------------------------------------------------- Pads

local function buildPads()
	local folder = Instance.new("Folder")
	folder.Name = "Pads"
	local function pad(position: Vector3, kind: string, color: Color3)
		local part = Instance.new("Part")
		part.Name = kind
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.3, 10, 10)
		part.CFrame = CFrame.new(position.X, Config.GroundY + 0.15, position.Z) * CFrame.Angles(0, 0, math.rad(90))
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Material = Enum.Material.Neon
		part.Color = color
		part.Transparency = 0.25
		part:SetAttribute("PadKind", kind)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 14
		light.Brightness = 2
		light.Parent = part
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(110, 26)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
		gui.MaxDistance = 90
		gui.AlwaysOnTop = false
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = if kind == "SpeedPad" then ">> SPEED" else "^ JUMP"
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.2
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Parent = gui
		gui.Parent = part
		part.Parent = folder
	end
	for _, position in Config.SpeedPads do
		pad(position, "SpeedPad", Color3.fromRGB(120, 255, 90))
	end
	for _, position in Config.JumpPads do
		pad(position, "JumpPad", Color3.fromRGB(90, 200, 255))
	end
	folder.Parent = workspace
end

local function padsForBot(actor)
	if (padReady[actor] or 0) > now() then
		return
	end
	local p = actor.Root.Position
	for _, position in Config.SpeedPads do
		if Vector3.new(p.X - position.X, 0, p.Z - position.Z).Magnitude < 5 then
			padReady[actor] = now() + 1
			actor.Model:SetAttribute("PadBoostUntil", now() + Config.PadBoostSeconds)
			return
		end
	end
	for _, position in Config.JumpPads do
		if Vector3.new(p.X - position.X, 0, p.Z - position.Z).Magnitude < 5 then
			padReady[actor] = now() + 1
			local v = actor.Root.AssemblyLinearVelocity
			actor.Root.AssemblyLinearVelocity = Vector3.new(v.X, Config.JumpPadVelocity, v.Z)
			return
		end
	end
end

---------------------------------------------------------------- Kopfball

local function checkHeaders()
	local ballService = services().BallService
	local ball = ballService.Ball
	if not ball or ballService.Carrier or ball.Anchored or ball.Position.Y < Config.GroundY + 4.5 then
		return
	end
	local kicker, kickTime = ballService:LastKick()
	for _, actor in services().MatchService:GetActors() do
		local head = actor.Model:FindFirstChild("Head") :: BasePart?
		if head and actor.Humanoid.Health > 0 and (headerReady[actor] or 0) < now() and not (kicker == actor and now() - kickTime < 0.6) then
			-- nur im Sprung (Hueftteil deutlich ueber dem Stand-Niveau)
			if actor.Root.Position.Y > Config.GroundY + 4.4 and (head.Position - ball.Position).Magnitude < 3.8 then
				headerReady[actor] = now() + 1
				local look = flat(actor.Root.CFrame.LookVector)
				local target = ballService:AssistTarget(actor, look)
				local velocity
				if target then
					local offset = Vector3.new(target.X - ball.Position.X, 0, target.Z - ball.Position.Z)
					local angle, speed = Config.ShotArc(offset.Magnitude, target.Y - ball.Position.Y, Config.HeaderSpeed, workspace.Gravity)
					velocity = (flat(offset) * math.cos(angle) + Vector3.yAxis * math.sin(angle)) * speed
				else
					velocity = look * Config.HeaderSpeed * 0.7 + Vector3.new(0, 18, 0)
				end
				ballService:Header(actor, velocity)
				PlusService:AddSuper(actor, Config.SuperGain.Touch)
				if actor.Player then
					remote:FireClient(actor.Player, "Header", {})
				end
				return
			end
		end
	end
end

---------------------------------------------------------------- Staub beim Sprinten (fuer alle sichtbar)

local function updateDust(actor)
	local emitter = dust[actor]
	if not emitter or emitter.Parent == nil then
		if actor.Root.Parent == nil then
			return
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = "DustAttachment"
		attachment.Position = Vector3.new(0, -2.8, 0.6)
		attachment.Parent = actor.Root
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SprintDust"
		emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(200, 185, 150))
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.4) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime = NumberRange.new(0.35, 0.6)
		emitter.Speed = NumberRange.new(2, 4)
		emitter.SpreadAngle = Vector2.new(35, 35)
		emitter.Rate = 22
		emitter.Enabled = false
		emitter.Parent = attachment
		dust[actor] = emitter
	end
	local v = actor.Root.AssemblyLinearVelocity
	local fast = Vector3.new(v.X, 0, v.Z).Magnitude > 24 and math.abs(v.Y) < 6
	if emitter.Enabled ~= fast then
		emitter.Enabled = fast
	end
end

---------------------------------------------------------------- Modi

local function applyBallMode()
	local ball = services().BallService.Ball
	if not ball then
		return
	end
	if not defaultBall then
		defaultBall = ball.CustomPhysicalProperties
	end
	if mode().Bouncy then
		ball.CustomPhysicalProperties = PhysicalProperties.new(0.25, 0.3, 0.95, 1, 100)
	else
		ball.CustomPhysicalProperties = defaultBall
	end
end

---------------------------------------------------------------- Match

function PlusService:OnMatchStart()
	safe("OnMatchStart", function()
		possession.Blue, possession.Red = 0, 0
		shots.Blue, shots.Red = 0, 0
		table.clear(received)
		for actor in super do
			if actor.Model then
				setSuper(actor, 0)
			end
		end
		table.clear(super)
		applyBallMode()
		if Config.IsWeekend() then
			services().Net.SendAnnounce("WEEKEND BONUS: 2x COINS!", C.Gold)
		end
	end)
end

-- Ballbesitz und Schuesse aufs Tor beider Teams als Ansage am Ende
function PlusService:OnMatchEnd(): string?
	return safe("OnMatchEnd", function()
		local total = possession.Blue + possession.Red
		local red = if total > 0 then math.floor(possession.Red / total * 100 + 0.5) else 50
		local line = `POSSESSION RED {red}% - {100 - red}% BLUE   SHOTS ON GOAL {shots.Red} - {shots.Blue}`
		remote:FireAllClients("Stats", { Text = line, Red = red, ShotsRed = shots.Red, ShotsBlue = shots.Blue })
		return line
	end)
end

function PlusService:Stats()
	return { Possession = table.clone(possession), Shots = table.clone(shots) }
end

function PlusService:Forget(actor)
	super[actor] = nil
	received[actor] = nil
	headerReady[actor] = nil
	padReady[actor] = nil
	dust[actor] = nil
end

---------------------------------------------------------------- Start

function PlusService:Init(svc)
	self.Services = svc
	remote = Instance.new("RemoteEvent")
	remote.Name = "Plus"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	workspace:SetAttribute("ScoreLimit", Config.ScoreLimit)
end

function PlusService:Start()
	buildPads()
	applyBallMode()
	workspace:GetAttributeChangedSignal("Mode"):Connect(function()
		safe("Mode", applyBallMode)
	end)
	remote.OnServerEvent:Connect(function(player, kind)
		if kind == "Skill" then
			safe("Skill", function()
				onSkill(player)
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		skillReady[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		safe("Heartbeat", function()
			local playing = workspace:GetAttribute("MatchState") == "Playing"
			local carrier = services().BallService.Carrier
			if playing and carrier then
				possession[carrier.Team] += dt
			end
			for actor in dust do
				if not services().MatchService:IsActor(actor) then
					self:Forget(actor)
				end
			end
			for _, actor in services().MatchService:GetActors() do
				updateDust(actor)
				if not actor.Player and playing then
					padsForBot(actor)
				end
			end
			if playing then
				checkHeaders()
			end
		end)
	end)
end

return PlusService
