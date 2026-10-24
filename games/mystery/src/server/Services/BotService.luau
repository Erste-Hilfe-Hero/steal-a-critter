-- Bots fuellen kleine Server auf, damit man sofort spielen kann.
-- Unschuldige sammeln Muenzen und fliehen, der Murderer jagt, Sheriff/Hero schiessen auf einen entlarvten Murderer.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)

local BotService = { Services = nil :: any }

local NAMES = {
	"Milo", "Nova", "Juno", "Kai", "Zara", "Finn", "Ivy", "Max", "Luna", "Theo", "Ruby", "Jax",
	"Pia", "Omar", "Sami", "Tess", "Bo", "Remy", "Nia", "Ozzy", "Lea", "Vik", "Cleo", "Arlo",
}
local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(230, 180, 140), Color3.fromRGB(180, 120, 80), Color3.fromRGB(110, 70, 45) }
local SHIRTS = { Color3.fromRGB(70, 110, 220), Color3.fromRGB(220, 70, 90), Color3.fromRGB(60, 170, 100), Color3.fromRGB(240, 180, 40), Color3.fromRGB(150, 80, 220), Color3.fromRGB(40, 40, 50), Color3.fromRGB(240, 240, 245) }
local ANIMATIONS = { Idle = "rbxassetid://507766666", Run = "rbxassetid://507767714" }

local folder: Folder
local bots = {}
local nameIndex = 0

function BotService:PlannedBots(humans: number): number
	local R = Config.Round
	if humans >= R.BotsUntilHumans then
		return 0
	end
	return math.clamp(R.MinActors - humans, 0, R.MaxBots)
end

local function loadAnimations(model: Model, humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks = {}
	for name, id in ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = true
			track.Priority = if name == "Idle" then Enum.AnimationPriority.Idle else Enum.AnimationPriority.Movement
			tracks[name] = track
		end
	end
	if tracks.Idle then
		tracks.Idle:Play()
	end
	return tracks
end

local function createBot(cf: CFrame)
	nameIndex += 1
	local name = NAMES[(nameIndex - 1) % #NAMES + 1]
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[math.random(1, #SKIN)]
	local shirt = SHIRTS[math.random(1, #SHIRTS)]
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = shirt
	description.LeftLegColor = shirt:Lerp(Color3.new(0, 0, 0), 0.5)
	description.RightLegColor = shirt:Lerp(Color3.new(0, 0, 0), 0.5)
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not ok or not model then
		warn("[Bots] Konnte keinen Bot erstellen:", model)
		return nil
	end
	model.Name = "Bot_" .. name
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.WalkSpeed = Config.WalkSpeed
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	model:PivotTo(cf + Vector3.new(0, 3, 0))
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(root.SetNetworkOwner, root, nil)
	local bot = {
		Name = name,
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Tracks = loadAnimations(model, humanoid),
		Actor = nil :: any,
		Weapon = nil :: string?,
		WeaponKind = nil :: string?,
		Path = nil :: { PathWaypoint }?,
		PathIndex = 1,
		Goal = nil :: Vector3?,
		NextPath = 0,
		NextAttack = 0,
		Wander = nil :: Vector3?,
		FleeFrom = nil :: Vector3?,
		FleeUntil = 0,
		Alive = true,
		Busy = false,
	}
	table.insert(bots, bot)
	return bot
end

function BotService:SpawnBots(humans: number, map): { any }
	local count = self:PlannedBots(humans)
	if self.Services.RoundService.Testing then
		count = math.max(count, Config.Round.MinActors)
	end
	local list = {}
	for i = 1, count do
		local bot = createBot(map.Spawns[math.random(1, #map.Spawns)])
		if bot then
			table.insert(list, bot)
		end
	end
	return list
end

-- Waffe sichtbar in die rechte Hand schweissen
function BotService:ShowWeapon(bot, kind: string?, skin: string?)
	local old = bot.Model:FindFirstChild("BotWeapon")
	if old then
		old:Destroy()
	end
	if not kind or not skin then
		return
	end
	local hand = bot.Model:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return
	end
	local model = if kind == "Knife" then Skins.Knife(skin) else Skins.Gun(skin)
	model.Name = "BotWeapon"
	local handle = model.PrimaryPart :: BasePart
	local grip = hand:FindFirstChild("RightGripAttachment") :: Attachment?
	local gripCf = if grip then grip.WorldCFrame else hand.CFrame
	local toolGrip = if kind == "Gun" then CFrame.new(0, -0.1, 0.1) else CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	model:PivotTo(gripCf * toolGrip:Inverse())
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = handle
	weld.Parent = handle
	model.Parent = bot.Model
end

function BotService:OnKO(bot)
	bot.Alive = false
	bot.Humanoid:MoveTo(bot.Root.Position)
	task.delay(1, function()
		if bot.Model.Parent then
			bot.Model:Destroy()
		end
	end)
end

function BotService:Clear()
	for _, bot in bots do
		bot.Alive = false
		if bot.Model.Parent then
			bot.Model:Destroy()
		end
	end
	table.clear(bots)
	folder:ClearAllChildren()
end

---------------------------------------------------------------- Denken

local function visible(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(from, to - from, params)
	return result == nil or (result.Position - to).Magnitude < 3
end

local function animate(bot)
	local run = bot.Tracks.Run
	if not run then
		return
	end
	local v = bot.Root.AssemblyLinearVelocity
	if Vector3.new(v.X, 0, v.Z).Magnitude > 2 then
		if not run.IsPlaying then
			run:Play(0.15)
		end
	elseif run.IsPlaying then
		run:Stop(0.2)
	end
end

-- Laeuft zum Ziel, mit Pathfinding wenn kein direkter Weg frei ist
local function moveTo(bot, goal: Vector3)
	local root = bot.Root
	local ignore = { bot.Model, workspace:FindFirstChild("Coins") :: Instance, workspace:FindFirstChild("PowerUps") :: Instance }
	local flat = Vector3.new(goal.X, root.Position.Y, goal.Z)
	if (flat - root.Position).Magnitude < 18 and visible(root.Position, flat, ignore) then
		bot.Path = nil
		bot.Humanoid:MoveTo(goal)
		return
	end
	local t = os.clock()
	if not bot.Path or not bot.Goal or (bot.Goal - goal).Magnitude > 8 or t > bot.NextPath then
		bot.Goal = goal
		bot.NextPath = t + 2.5
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 6 })
		local ok = pcall(path.ComputeAsync, path, root.Position, goal)
		if ok and path.Status == Enum.PathStatus.Success then
			bot.Path = path:GetWaypoints()
			bot.PathIndex = 2
		else
			bot.Path = nil
			bot.Humanoid:MoveTo(goal)
			return
		end
	end
	local waypoints = bot.Path :: { PathWaypoint }
	local wp = waypoints[bot.PathIndex]
	while wp and (Vector3.new(wp.Position.X, root.Position.Y, wp.Position.Z) - root.Position).Magnitude < 3.5 do
		bot.PathIndex += 1
		wp = waypoints[bot.PathIndex]
	end
	if wp then
		if wp.Action == Enum.PathWaypointAction.Jump then
			bot.Humanoid.Jump = true
		end
		bot.Humanoid:MoveTo(wp.Position)
	else
		bot.Path = nil
		bot.Humanoid:MoveTo(goal)
	end
end

local function randomSpot(map): Vector3
	return map.Spawns[math.random(1, #map.Spawns)].Position
end

local function think(bot)
	local services = BotService.Services
	local round = services.RoundService
	local actor = bot.Actor
	if not actor or not actor.Alive or not bot.Alive then
		return
	end
	local map = round.Map
	if not map then
		return
	end
	local pos = bot.Root.Position
	local t = os.clock()
	if round.State ~= "Playing" then
		bot.Humanoid:MoveTo(pos)
		return
	end

	if actor.Role == "Murderer" then
		-- Naechstes Opfer jagen
		local target, best = nil, math.huge
		for _, other in round.Actors do
			if other ~= actor and other.Alive and not other.Hidden and other.Role ~= "Murderer" then
				local d = (other.Root.Position - pos).Magnitude
				if d < best then
					target, best = other, d
				end
			end
		end
		if target then
			moveTo(bot, target.Root.Position)
			if best < 6 and t > bot.NextAttack then
				bot.NextAttack = t + 0.9
				bot.Root.CFrame = CFrame.lookAt(pos, Vector3.new(target.Root.Position.X, pos.Y, target.Root.Position.Z))
				services.CombatService:Stab(actor)
			elseif best < 45 and best > 14 and t > bot.NextAttack and math.random() < 0.08 and visible(pos, target.Root.Position, { bot.Model, target.Model }) then
				bot.NextAttack = t + 1.5
				services.CombatService:Throw(actor, target.Root.Position + target.Root.AssemblyLinearVelocity * 0.25)
			elseif best > 30 and math.random() < 0.01 then
				services.AbilityService:Use(actor, "Dash")
			end
		else
			moveTo(bot, randomSpot(map))
		end
		return
	end

	if actor.Role == "Sheriff" or actor.Role == "Hero" then
		-- Nur auf einen entlarvten Murderer schiessen
		for _, other in round.Actors do
			if other.Alive and other.Role == "Murderer" and t - other.Exposed < 6 then
				local d = (other.Root.Position - pos).Magnitude
				if d < 140 then
					local sees = visible(pos + Vector3.new(0, 1.5, 0), other.Root.Position, { bot.Model, other.Model })
					if sees and d < 90 and t > bot.NextAttack then
						bot.NextAttack = t + Config.Gun.Cooldown + math.random() * 1.2
						bot.Root.CFrame = CFrame.lookAt(pos, Vector3.new(other.Root.Position.X, pos.Y, other.Root.Position.Z))
						local aim = other.Root.Position
						if math.random() > 0.55 then
							aim += Vector3.new(math.random(-6, 6), math.random(-1, 3), math.random(-6, 6))
						end
						services.CombatService:Shoot(actor, aim)
					else
						moveTo(bot, other.Root.Position)
					end
					return
				end
			end
		end
	end

	-- Unschuldige fliehen nach einem K.O. in der Naehe
	if bot.FleeFrom and t < bot.FleeUntil then
		local away = (pos - bot.FleeFrom)
		away = Vector3.new(away.X, 0, away.Z)
		if away.Magnitude < 0.1 then
			away = Vector3.new(1, 0, 0)
		end
		moveTo(bot, pos + away.Unit * 30)
		return
	end
	-- Fallengelassenen Blaster holen
	if actor.Role == "Innocent" then
		local gun = services.CombatService:GetDroppedGun()
		if gun and (gun:GetPivot().Position - pos).Magnitude < 60 then
			moveTo(bot, gun:GetPivot().Position)
			if (gun:GetPivot().Position - pos).Magnitude < 5 then
				services.CombatService:TryPickup(actor)
			end
			return
		end
	end
	-- Muenzen sammeln, sonst herumlaufen
	if actor.Coins < services.CoinService:BagSize(actor) then
		local coin = services.CoinService:Nearest(pos)
		if coin and (coin.Position - pos).Magnitude < 70 then
			moveTo(bot, coin.Position)
			if (coin.Position - pos).Magnitude < 4 then
				services.CoinService:Collect(actor, coin)
			end
			return
		end
	end
	if not bot.Wander or (bot.Wander - pos).Magnitude < 5 or math.random() < 0.01 then
		bot.Wander = randomSpot(map)
	end
	moveTo(bot, bot.Wander)
end

-- Nach einem K.O.: Bots in der Naehe fliehen, Sheriff-Bots "sehen" den Murderer
function BotService:Alarm(position: Vector3)
	for _, bot in bots do
		if bot.Alive and bot.Actor and bot.Actor.Role ~= "Murderer" and (bot.Root.Position - position).Magnitude < 40 then
			bot.FleeFrom = position
			bot.FleeUntil = os.clock() + 4
		end
	end
end

function BotService:Init(services)
	self.Services = services
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
end

-- Paused: Bots denken nicht (nur fuer gestellte Szenen im Smoke-Test)
BotService.Paused = false

function BotService:Start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, bot in table.clone(bots) do
				if bot.Alive and not bot.Busy and not self.Paused then
					-- Pathfinding wartet, deshalb denkt jeder Bot in seinem eigenen Thread
					bot.Busy = true
					task.spawn(function()
						local ok, err = pcall(think, bot)
						if not ok then
							warn("[Bots]", err)
						end
						bot.Busy = false
					end)
				end
				if bot.Alive then
					animate(bot)
				end
			end
		end
	end)
end

return BotService
