-- Computer-Mitspieler: fuellen die Teams auf und spielen einfach, aber glaubwuerdig
-- (Torwart bleibt im Tor, einer jagt den Ball, die anderen halten ihre Position).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BotService = { Services = nil :: any }

local NAMES = {
	"Rico", "Mila", "Juno", "Kai", "Nova", "Leo", "Zara", "Finn", "Ivy", "Max", "Luna", "Theo",
	"Ruby", "Jax", "Pia", "Omar", "Sami", "Tess", "Bo", "Remy", "Nia", "Ozzy", "Lea", "Vik",
}
local SKIN = { Color3.fromRGB(255, 220, 190), Color3.fromRGB(230, 180, 140), Color3.fromRGB(180, 120, 80), Color3.fromRGB(110, 70, 45) }

local folder: Folder
local bots = { Blue = {}, Red = {} } -- [team] = { bot }
local pending = { Blue = 0, Red = 0 } -- Bots, die gerade erstellt werden
local nameIndex = 0

local function now(): number
	return workspace:GetServerTimeNow()
end

local function otherTeam(teamName: string): string
	return if teamName == "Blue" then "Red" else "Blue"
end

local function botLevel(): number
	-- Bots werden mit dem Durchschnittslevel der Spieler etwas staerker
	local total, count = 0, 0
	for _, player in Players:GetPlayers() do
		total += player:GetAttribute("Level") or 1
		count += 1
	end
	local average = if count > 0 then total / count else 1
	return math.clamp(math.floor(1 + average / 8), 1, 4)
end

-- Standard-R15-Animationen von Roblox (Lokale Animate-Skripte laufen bei NPCs nicht)
local ANIMATIONS = {
	Idle = "rbxassetid://507766666",
	Run = "rbxassetid://507767714",
}

local function loadAnimations(model: Model, humanoid: Humanoid)
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
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

local function animate(bot)
	local tracks = bot.Tracks
	local run = tracks and tracks.Run
	if not run then
		return
	end
	local velocity = bot.Actor.Root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if speed > 2 then
		if not run.IsPlaying then
			run:Play(0.15)
		end
		run:AdjustSpeed(math.clamp(speed / 18, 0.6, 2))
	elseif run.IsPlaying then
		run:Stop(0.2)
	end
end

local function createBot(teamName: string)
	local team = Config.Teams[teamName]
	nameIndex += 1
	local name = NAMES[(nameIndex - 1) % #NAMES + 1]
	local description = Instance.new("HumanoidDescription")
	local skin = SKIN[math.random(1, #SKIN)]
	description.HeadColor = skin
	description.LeftArmColor = skin
	description.RightArmColor = skin
	description.TorsoColor = team.Color
	description.LeftLegColor = team.Dark
	description.RightLegColor = team.Dark
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not ok or not model then
		warn("[Bots] Konnte keinen Bot erstellen:", model)
		return nil
	end
	model.Name = "Bot_" .. name .. "_" .. nameIndex
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	local level = botLevel()
	local skills = {}
	for _, skill in Config.Skills do
		skills[skill.Id] = math.clamp(level + math.random(-1, 1), 0, Config.MaxSkill)
	end
	humanoid.WalkSpeed = Config.WalkSpeed(skills.Agility)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil)
	local actor = BotService.Services.MatchService:AddActor(model, teamName, nil, skills, name)
	if not actor then
		model:Destroy()
		return nil
	end
	BotService.Services.ProgressService:NameTag(model, name, level * 3, team.Color, false, true)
	return { Actor = actor, Model = model, Humanoid = humanoid, NextThink = math.random() * 10, DashUntil = 0, HasBallSince = 0, Team = teamName, Tracks = loadAnimations(model, humanoid) }
end

function BotService:SetCount(teamName: string, count: number)
	local list = bots[teamName]
	while #list > count do
		local bot = table.remove(list)
		self.Services.MatchService:RemoveActor(bot.Model)
		bot.Model:Destroy()
	end
	local missing = count - #list - pending[teamName]
	for _ = 1, missing do
		pending[teamName] += 1
		task.spawn(function()
			local bot = createBot(teamName)
			pending[teamName] -= 1
			if bot then
				table.insert(bots[teamName], bot)
				-- Inzwischen zu viele? (z. B. ein Spieler ist beigetreten)
				task.defer(function()
					local services = BotService.Services
					services.MatchService:Rebalance()
				end)
			end
		end)
	end
end

---------------------------------------------------------------- KI

local function closestOfTeam(teamName: string, position: Vector3)
	local best, bestDistance = nil, math.huge
	for _, actor in BotService.Services.MatchService:GetActors() do
		if actor.Team == teamName and actor.Model:GetAttribute("Role") ~= "Keeper" then
			local d = (actor.Root.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = actor, d
			end
		end
	end
	return best
end

local function nearestOpponentDistance(actor): number
	local best = math.huge
	for _, other in BotService.Services.MatchService:GetActors() do
		if other.Team ~= actor.Team then
			best = math.min(best, (other.Root.Position - actor.Root.Position).Magnitude)
		end
	end
	return best
end

local function think(bot)
	local services = BotService.Services
	local actor = bot.Actor
	local humanoid = bot.Humanoid
	local root = actor.Root
	local stateName = workspace:GetAttribute("MatchState")
	if stateName ~= "Playing" and stateName ~= "Goal" then
		humanoid:Move(Vector3.zero)
		return
	end
	if (actor.StunnedUntil or 0) > now() then
		humanoid.WalkSpeed = 3
		return
	end
	local ballService = services.BallService
	local ball = ballService.Ball :: Part
	local carrier = ballService.Carrier
	local position = root.Position
	local ballPos = ball.Position
	local myGoal = services.ArenaService:GoalCenter(actor.Team)
	local theirGoal = services.ArenaService:GoalCenter(otherTeam(actor.Team))
	local side = Config.Teams[actor.Team].Side
	local role = actor.Model:GetAttribute("Role")
	local baseSpeed = Config.WalkSpeed(actor.Skills.Agility)
	local target: Vector3? = nil
	local sprint = false

	if bot.DashUntil > os.clock() then
		return
	end

	-- Messer: Gegner in Reichweite ab und zu angreifen (meist Slash, manchmal Stab)
	if carrier ~= actor and (actor.KnifeReadyAt or 0) < now() and (ballPos - position).Magnitude < Config.HuntDistance and math.random() < 0.12 then
		local enemy, enemyDistance = nil, 6
		for _, other in services.MatchService:GetActors() do
			if other.Team ~= actor.Team and not services.CombatService:IsKO(other) then
				local d = (other.Root.Position - position).Magnitude
				if d < enemyDistance then
					enemy, enemyDistance = other, d
				end
			end
		end
		if enemy then
			local look = (enemy.Root.Position - position) * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(position, position + look)
			end
			services.CombatService:Swing(actor, if math.random() < 0.2 then "Stab" else "Slash")
		end
	end

	if carrier == actor then
		if bot.HasBallSince == 0 then
			bot.HasBallSince = os.clock()
		end
		local held = os.clock() - bot.HasBallSince
		local toGoal = theirGoal - position
		if role == "Keeper" and held > 0.6 then
			ballService:Kick(actor, (theirGoal - position).Unit + Vector3.new(0, 0.3, 0), 1)
		elseif toGoal.Magnitude < 85 and held > 0.4 then
			local aim = theirGoal + Vector3.new(0, 4, (math.random() - 0.5) * Config.GoalWidth * 0.7)
			ballService:Kick(actor, (aim - position).Unit, 0.75 + math.random() * 0.25, (math.random() - 0.5) * 0.4)
		elseif held > 0.8 and nearestOpponentDistance(actor) < 9 and math.random() < 0.35 then
			ballService:Pass(actor)
		else
			target = theirGoal + Vector3.new(0, 0, math.sin(os.clock() + bot.NextThink) * 12)
		end
	else
		bot.HasBallSince = 0
		local formation = services.ArenaService:FormationPosition(actor.Team, math.max(actor.Slot, 1))
		if role == "Keeper" then
			local keeperSpot = Vector3.new(myGoal.X - side * 5, position.Y, math.clamp(ballPos.Z, -Config.GoalWidth / 2 + 3, Config.GoalWidth / 2 - 3))
			local ballNearGoal = (ballPos - myGoal).Magnitude < 32
			if ballNearGoal and (carrier == nil or carrier.Team ~= actor.Team) then
				target = ballPos
				sprint = true
			else
				target = keeperSpot
			end
		elseif carrier == nil then
			if closestOfTeam(actor.Team, ballPos) == actor then
				target = ballPos + (ball.AssemblyLinearVelocity * 0.15)
				sprint = true
			else
				target = formation + Vector3.new((ballPos.X - formation.X) * 0.35, 0, (ballPos.Z - formation.Z) * 0.25)
			end
		elseif carrier.Team == actor.Team then
			target = formation + Vector3.new(-side * 30, 0, (ballPos.Z - formation.Z) * 0.2)
		else
			if closestOfTeam(actor.Team, carrier.Root.Position) == actor then
				target = carrier.Root.Position + carrier.Root.AssemblyLinearVelocity * 0.2
				sprint = true
				-- Ballfuehrer mit dem Messer angreifen (Treffer koennen ihm den Ball abnehmen)
				local distance = (carrier.Root.Position - position).Magnitude
				if distance < 8 and (actor.KnifeReadyAt or 0) < now() and math.random() < 0.5 then
					local look = (carrier.Root.Position - position) * Vector3.new(1, 0, 1)
					if look.Magnitude > 0.1 then
						root.CFrame = CFrame.lookAt(position, position + look)
					end
					services.CombatService:Swing(actor, if math.random() < 0.25 then "Stab" else "Slash")
				end
			else
				target = formation + Vector3.new((ballPos.X - formation.X) * 0.3, 0, (ballPos.Z - formation.Z) * 0.3)
			end
		end
	end

	local speed = baseSpeed * (if sprint then 1.25 else 1) * (if carrier == actor then Config.CarryFactor else 1)
	humanoid.WalkSpeed = speed
	if target then
		local offset = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		if offset.Magnitude > 1.5 then
			humanoid:Move(offset.Unit)
		else
			humanoid:Move(Vector3.zero)
		end
	end
end

function BotService:Init(services)
	self.Services = services
end

function BotService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Bots"
	folder.Parent = workspace
	task.spawn(function()
		while true do
			task.wait(0.12)
			for _, list in bots do
				for _, bot in list do
					if bot.Model.Parent then
						local ok, err = pcall(think, bot)
						if not ok then
							warn("[Bots]", err)
						end
						animate(bot)
					end
				end
			end
		end
	end)
end

return BotService
