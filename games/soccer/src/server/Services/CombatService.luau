-- Messer wie in Soccer Jam: Slash und Stab mit den Schadenswerten aus CS 1.6, von hinten (Backstab) dreifach.
-- Harte Schuesse (Smack) machen auch Schaden. Bei 0 Leben ist man K.O.: man kippt um (kein Blut),
-- verliert den Ball und steht nach Config.KOSeconds an der eigenen Startposition wieder auf.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = { Services = nil :: any }

local swings = {} -- [actor] = { Kind, Starts, Ends }
local ANIMATIONS = { Slash = "rbxassetid://522635514", Stab = "rbxassetid://522638767" } -- Roblox-Standard: ToolSlash, ToolLunge

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function playing(): boolean
	return workspace:GetAttribute("MatchState") == "Playing"
end

function CombatService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Leben

local function hasPass(actor, key: string): boolean
	return actor.Player ~= nil and actor.Player:GetAttribute("Pass_" .. key) == true
end

-- Lebensbalken im Namensschild ueber dem Kopf
local function updateTag(actor)
	local head = actor.Model:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	local back = tag and tag:FindFirstChild("HP")
	local bar = back and back:FindFirstChild("Bar") :: Frame?
	if bar then
		local fraction = actor.HP / (actor.MaxHP or Config.MaxHP)
		bar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		bar.BackgroundColor3 = if fraction > 0.5 then Color3.fromRGB(90, 230, 90) elseif fraction > 0.25 then Config.Colors.Orange else Config.Colors.Red
	end
end

local function setHP(actor, hp: number)
	actor.HP = hp
	actor.Model:SetAttribute("HP", hp)
	updateTag(actor)
end

function CombatService:IsKO(actor): boolean
	return (actor.KOUntil or 0) > now()
end

-- Volle Leben; Stamina-Upgrades zaehlen ab dem naechsten Heilen (wie im Original nach dem Respawn)
function CombatService:Heal(actor)
	actor.MaxHP = Config.MaxHPFor(self.Services.MatchService:Skill(actor, "Stamina"))
	if hasPass(actor, "IronBody") then
		actor.MaxHP += Config.IronBodyHP
	end
	actor.Model:SetAttribute("MaxHP", actor.MaxHP)
	setHP(actor, actor.MaxHP)
end

-- Spielzeug-Messer in die rechte Hand (Griff in Teamfarbe)
local function giveKnife(actor)
	local hand = actor.Model:FindFirstChild("RightHand") :: BasePart?
	if not hand or actor.Model:FindFirstChild("Knife") then
		return
	end
	local knife = Instance.new("Model")
	knife.Name = "Knife"
	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = hand.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = knife
		return p
	end
	local golden = hasPass(actor, "GoldenKnife")
	piece(Vector3.new(0.3, 0.3, 0.9), CFrame.new(0, -0.35, -0.2), Config.Teams[actor.Team].Color, Enum.Material.SmoothPlastic)
	piece(Vector3.new(0.1, 0.38, 1.5), CFrame.new(0, -0.35, -1.35), if golden then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(215, 225, 235), if golden then Enum.Material.Neon else Enum.Material.Metal)
	knife.Parent = actor.Model
end

function CombatService:Setup(actor)
	actor.KOUntil = 0
	actor.KnifeReadyAt = 0
	actor.SpawnProtectUntil = 0
	actor.Model:SetAttribute("KOUntil", 0)
	self:Heal(actor)
	giveKnife(actor)
	-- Laedt der Avatar spaeter nach, wird die Hand ersetzt: Messer neu anbringen
	actor.Model.ChildAdded:Connect(function(child)
		if child.Name == "RightHand" then
			local old = actor.Model:FindFirstChild("Knife")
			if old then
				old:Destroy()
			end
			task.defer(giveKnife, actor)
		end
	end)
end

-- Beim Anstoss: alle voll geheilt und wieder auf den Beinen
function CombatService:Reset(actor)
	swings[actor] = nil
	actor.KOUntil = 0
	actor.Model:SetAttribute("KOUntil", 0)
	actor.Humanoid.PlatformStand = false
	self:Heal(actor)
end

---------------------------------------------------------------- Schaden und K.O.

local function knockOut(victim, attacker, kind: string)
	local services = CombatService.Services
	victim.KOUntil = now() + Config.KOSeconds
	victim.Model:SetAttribute("KOUntil", victim.KOUntil)
	swings[victim] = nil
	local push = if attacker then flat(victim.Root.Position - attacker.Root.Position) else Vector3.zero
	services.BallService:Knock(victim, push * 20 + Vector3.new(0, 18, 0), Config.KOSeconds)
	victim.Humanoid.PlatformStand = true
	services.MatchService:OnKO(attacker, victim, kind)
	local koUntil = victim.KOUntil
	task.delay(Config.KOSeconds, function()
		if victim.KOUntil ~= koUntil or not services.MatchService:IsActor(victim) then
			return
		end
		victim.KOUntil = 0
		victim.Model:SetAttribute("KOUntil", 0)
		victim.Humanoid.PlatformStand = false
		CombatService:Heal(victim)
		victim.SpawnProtectUntil = now() + Config.SpawnProtect
		victim.Model:SetAttribute("SpawnProtectUntil", victim.SpawnProtectUntil)
		victim.StunnedUntil = 0
		victim.Model:SetAttribute("StunnedUntil", 0)
		victim.Model:SetAttribute("KnockedUntil", 0)
		services.MatchService:PlaceActor(victim)
		if not victim.Player then
			victim.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

-- kind: "Slash", "Stab" oder "Smack"
function CombatService:Damage(victim, amount: number, attacker, kind: string, backstab: boolean?)
	if not playing() or self:IsKO(victim) or (victim.SpawnProtectUntil or 0) > now() then
		return
	end
	if attacker and attacker.Team == victim.Team then
		return
	end
	-- Wie im Original: mit dem Messer nur in Ballnaehe Schaden machen, kein Jagen quer uebers Feld
	if attacker and (kind == "Slash" or kind == "Stab") then
		local ball = self.Services.BallService.Ball :: BasePart
		if (attacker.Root.Position - ball.Position).Magnitude > Config.HuntDistance and (victim.Root.Position - ball.Position).Magnitude > Config.HuntDistance then
			if attacker.Player and (attacker.HuntWarnedAt or 0) < now() - 2 then
				attacker.HuntWarnedAt = now()
				self.Services.Net.SendNotify(attacker.Player, "No hunting! Knife only works near the ball.", Config.Colors.Orange)
			end
			return
		end
		-- Treffer am Ballfuehrer: Chance, dass er den Ball verliert
		if self.Services.BallService.Carrier == victim and math.random() < Config.DisarmChance(self.Services.MatchService:Skill(attacker, "Disarm")) then
			if self.Services.BallService:Disarm(attacker, victim) then
				self.Services.MatchService:OnDisarm(attacker, victim)
			end
		end
	end
	-- Golden Knife (Pass): mehr Messerschaden
	if attacker and (kind == "Slash" or kind == "Stab") and hasPass(attacker, "GoldenKnife") then
		amount = math.floor(amount * Config.GoldenKnifeDamage + 0.5)
	end
	local hp = math.max(0, victim.HP - amount)
	setHP(victim, hp)
	self.Services.Net.MatchEvent:FireAllClients("Damage", { Model = victim.Model, Amount = amount, Backstab = backstab == true })
	if hp <= 0 then
		knockOut(victim, attacker, kind)
	end
end

---------------------------------------------------------------- Messer

local function playAnimation(actor, kind: string)
	local animator = actor.Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	actor.KnifeTracks = actor.KnifeTracks or {}
	local track = actor.KnifeTracks[kind]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = ANIMATIONS[kind]
		local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
		if not ok then
			return
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		actor.KnifeTracks[kind] = track
	end
	track:Play(0.05)
end

-- Startet einen Messerangriff; der Treffer wird im naechsten Moment gesucht (Heartbeat)
function CombatService:Swing(actor, kind: string): boolean
	local def = Config.Knife[kind]
	if not def or not playing() or self:IsKO(actor) then
		return false
	end
	if (actor.StunnedUntil or 0) > now() or self.Services.BallService.Carrier == actor then
		return false
	end
	if actor.KnifeReadyAt > now() then
		return false
	end
	actor.KnifeReadyAt = now() + def.Cooldown
	if actor.Player then
		actor.Player:SetAttribute("KnifeReadyAt", actor.KnifeReadyAt)
	end
	swings[actor] = { Kind = kind, Starts = now() + def.Windup, Ends = now() + def.Windup + def.Window }
	playAnimation(actor, kind)
	self.Services.Net.PlaySound(kind, actor.Root.Position)
	return true
end

-- Von hinten: das Opfer schaut vom Angreifer weg
local function isBehind(attacker, victim): boolean
	local toVictim = flat(victim.Root.Position - attacker.Root.Position)
	return flat(victim.Root.CFrame.LookVector):Dot(toVictim) > Config.BackstabDot
end

-- Alien-Maskottchen: jede Sekunde einen Gegner im Kreis vor dem eigenen Tor zappen,
-- ein gegnerischer Ballfuehrer im Kreis ist sofort K.O.; eigene Spieler im Kreis heilen sich
local function alienTick()
	if not playing() then
		return
	end
	local services = CombatService.Services
	local arena = services.ArenaService
	local carrier = services.BallService.Carrier
	for _, teamName in Config.TeamOrder do
		local goal = arena:GoalCenter(teamName)
		local targets = {}
		local victim = nil
		for _, actor in services.MatchService:GetActors() do
			local offset = actor.Root.Position - goal
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < Config.AlienRadius and not CombatService:IsKO(actor) then
				if actor.Team ~= teamName then
					if actor == carrier then
						victim = actor
					else
						table.insert(targets, actor)
					end
				elseif actor.HP < (actor.MaxHP or Config.MaxHP) then
					setHP(actor, math.min(actor.MaxHP or Config.MaxHP, actor.HP + Config.KeeperRegen * Config.AlienInterval))
				end
			end
		end
		if victim then
			arena:MascotStomp(teamName, victim.Root.Position)
			CombatService:Damage(victim, victim.HP, nil, "Alien")
		elseif #targets > 0 then
			local target = targets[math.random(1, #targets)]
			arena:MascotStomp(teamName, target.Root.Position)
			services.Net.PlaySound("Zap", target.Root.Position)
			CombatService:Damage(target, math.random(Config.AlienDamage[1], Config.AlienDamage[2]), nil, "Alien")
		end
	end
end

local function resolveSwings()
	local t = now()
	local match = CombatService.Services.MatchService
	for actor, swing in swings do
		if t > swing.Ends or not match:IsActor(actor) or CombatService:IsKO(actor) then
			swings[actor] = nil
		elseif t >= swing.Starts then
			local def = Config.Knife[swing.Kind]
			local look = flat(actor.Root.CFrame.LookVector)
			local best, bestDistance = nil, math.huge
			for _, other in match:GetActors() do
				if other.Team ~= actor.Team and not CombatService:IsKO(other) and other.Root.Parent then
					local offset = other.Root.Position - actor.Root.Position
					local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
					if distance <= def.Range and math.abs(offset.Y) < 5 and (distance < 3 or look:Dot(flat(offset)) > 0.25) and distance < bestDistance then
						best, bestDistance = other, distance
					end
				end
			end
			if best then
				swings[actor] = nil
				local backstab = isBehind(actor, best)
				CombatService:Damage(best, if backstab then def.Backstab else def.Damage, actor, swing.Kind, backstab)
			end
		end
	end
end

function CombatService:Forget(actor)
	swings[actor] = nil
end

function CombatService:Start()
	RunService.Heartbeat:Connect(resolveSwings)
	task.spawn(function()
		while true do
			task.wait(Config.AlienInterval)
			local ok, err = pcall(alienTick)
			if not ok then
				warn("[Combat] Alien:", err)
			end
		end
	end)
	local net = self.Services.Net
	net.Stab.OnServerEvent:Connect(function(player)
		local actor = self.Services.MatchService:ActorForPlayer(player)
		if actor then
			self:Swing(actor, "Stab")
		end
	end)
	-- Pass fordern wie im Original (ALT): ein "!" ueber dem Kopf fuer 2 Sekunden
	local lastCall = {}
	net.CallPass.OnServerEvent:Connect(function(player)
		local actor = self.Services.MatchService:ActorForPlayer(player)
		local head = actor and actor.Model and actor.Model:FindFirstChild("Head")
		if not head or os.clock() - (lastCall[player] or 0) < 2 then
			return
		end
		lastCall[player] = os.clock()
		local gui = Instance.new("BillboardGui")
		gui.Name = "PassCall"
		gui.Size = UDim2.fromOffset(60, 60)
		gui.StudsOffset = Vector3.new(0, 5.2, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 400
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundTransparency = 1
		mark.Text = "!"
		mark.TextScaled = true
		mark.Font = Enum.Font.FredokaOne
		mark.TextColor3 = Config.Teams[actor.Team] and Config.Teams[actor.Team].Color or Color3.new(1, 1, 1)
		mark.TextStrokeTransparency = 0
		mark.Parent = gui
		gui.Parent = head
		self.Services.Net.PlaySound("Call", head.Position)
		task.delay(2, function()
			gui:Destroy()
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return CombatService
