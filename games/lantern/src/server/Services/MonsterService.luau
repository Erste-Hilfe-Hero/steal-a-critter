-- Monster: Erzeugen, einfache KI (Nahkampf, Fernkampf, Schlaeger, Boss), Schaden und Tod.
-- Alle Angriffe der Monster sind vorher sichtbar (roter Kreis oder Ausholen), damit man ausweichen kann.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MonsterFactory = require(script.Parent.MonsterFactory)

local MonsterService = { Services = nil :: any }

local monsters = {} -- [Model] = Zustand
local byModel = monsters
local rng = Random.new()

local TELEGRAPH = Color3.fromRGB(255, 80, 60)
local BOSS_TELEGRAPH = Color3.fromRGB(255, 120, 40)

function MonsterService:Init(services)
	self.Services = services
end

function MonsterService:Get(model: Instance?)
	return model and byModel[model :: any]
end

function MonsterService:ForRun(run)
	local list = {}
	for _, state in monsters do
		if state.Run == run and state.Alive then
			table.insert(list, state)
		end
	end
	return list
end

function MonsterService:CountAlive(run): number
	local count = 0
	for _, state in monsters do
		if state.Run == run and state.Alive then
			count += 1
		end
	end
	return count
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function alivePlayers(run)
	local list = {}
	for _, player in run.Players do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			table.insert(list, { Player = player, Root = root })
		end
	end
	return list
end
MonsterService.AlivePlayers = alivePlayers

---------------------------------------------------------------- Erzeugen

function MonsterService:Spawn(run, key: string, position: Vector3, spawnOptions: { Elite: boolean?, Boss: boolean?, Minion: boolean? }?)
	local options = spawnOptions or {}
	local def = if options.Boss then Config.Bosses[key] else Config.Monsters[key]
	if not def then
		warn("[Monster] Unbekannt:", key)
		return nil
	end
	local difficulty = Config.Difficulties[run.Difficulty]
	local level = run.Level
	local scale = if options.Elite then 1.25 else 1
	local model = MonsterFactory.Build(def, scale, { Elite = options.Elite, Boss = options.Boss })
	local party = #run.Players
	local hp = Config.MonsterHealth(level) * (def.Hp or 1) * difficulty.Hp
	local dmg = Config.MonsterDamage(level) * (def.Dmg or 1) * difficulty.Dmg
	if options.Elite then
		hp *= Config.EliteHealthMult
		dmg *= Config.EliteDamageMult
	end
	if options.Boss then
		hp *= Config.BossHealthMult * (1 + Config.BossPartyHealth * (party - 1))
		dmg *= 1.5
	elseif party > 1 then
		hp *= 1 + 0.2 * (party - 1)
	end
	hp = math.floor(hp)
	local state = {
		Model = model,
		Root = model.PrimaryPart :: BasePart,
		Humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid,
		Def = def,
		Key = key,
		Run = run,
		Level = level,
		Hp = hp,
		MaxHp = hp,
		Dmg = dmg,
		Elite = options.Elite == true,
		Boss = options.Boss == true,
		Minion = options.Minion == true,
		Alive = true,
		NextAttack = os.clock() + rng:NextNumber(1, 2),
		NextAbility = os.clock() + 3,
		AbilityIndex = 0,
		BusyUntil = 0,
		StunUntil = 0,
		SlowUntil = 0,
		Enraged = false,
		Reach = 4 + 2.2 * def.Size * scale,
		Treasure = def.Treasure == true,
		EscapeAt = if def.Treasure then os.clock() + Config.ImpEscape else math.huge,
	}
	model:SetAttribute("Health", hp)
	model:SetAttribute("MaxHealth", hp)
	model:SetAttribute("Level", level)
	model:SetAttribute("DisplayName", (if options.Elite then "Champion " else "") .. def.Name)
	model:SetAttribute("Elite", state.Elite)
	model:SetAttribute("Boss", state.Boss)
	model:SetAttribute("Run", run.Id)
	model:PivotTo(CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	model.Parent = self.Services.WorldService.MonsterFolder
	pcall(function()
		state.Root:SetNetworkOwner(nil)
	end)
	monsters[model] = state
	self.Services.Net.SendEffect(run.Players, "Spawn", { Position = position, Color = def.Color, Boss = state.Boss })
	return state
end

---------------------------------------------------------------- Schaden an Monstern

function MonsterService:Damage(state, amount: number, attacker: Player?, crit: boolean?)
	if not state.Alive then
		return false
	end
	amount = math.max(1, math.floor(amount))
	state.Hp -= amount
	state.Model:SetAttribute("Health", math.max(0, state.Hp))
	self.Services.Net.SendEffect(state.Run.Players, "Hit", {
		Model = state.Model,
		Position = state.Root.Position + Vector3.new(0, state.Model:GetAttribute("Top") or 3, 0) * 0.5,
		Amount = amount,
		Crit = crit == true,
		By = attacker and attacker.UserId,
	})
	if state.Boss and not state.Enraged and state.Hp <= state.MaxHp * 0.5 then
		state.Enraged = true
		state.Humanoid.WalkSpeed = (state.Def.Speed or 10) * 1.25
		self.Services.Net.SendEffect(state.Run.Players, "Enrage", { Name = state.Def.Name })
	end
	if state.Hp <= 0 then
		self:Kill(state, attacker)
		return true
	end
	return false
end

function MonsterService:Kill(state, killer: Player?)
	if not state.Alive then
		return
	end
	state.Alive = false
	monsters[state.Model] = nil
	local position = state.Root.Position
	self.Services.Net.SendEffect(state.Run.Players, "Death", { Position = position, Color = state.Def.Color, Size = state.Def.Size, Boss = state.Boss })
	state.Model:Destroy()
	self.Services.DungeonService:OnMonsterKilled(state, killer, position)
end

-- Schatz-Kobold entkommt: verschwindet ohne Beute
function MonsterService:Escape(state)
	if not state.Alive then
		return
	end
	state.Alive = false
	monsters[state.Model] = nil
	self.Services.Net.SendEffect(state.Run.Players, "ImpEscape", { Position = state.Root.Position })
	state.Model:Destroy()
end

function MonsterService:Stun(state, seconds: number)
	if state.Boss then
		seconds *= 0.3
	end
	state.StunUntil = math.max(state.StunUntil, os.clock() + seconds)
end

function MonsterService:Slow(state, seconds: number)
	state.SlowUntil = math.max(state.SlowUntil, os.clock() + seconds)
end

function MonsterService:ClearRun(run)
	for model, state in monsters do
		if state.Run == run then
			state.Alive = false
			monsters[model] = nil
			model:Destroy()
		end
	end
end

---------------------------------------------------------------- Angriffe der Monster

local function hitPlayersInCircle(state, center: Vector3, radius: number, damage: number)
	for _, entry in alivePlayers(state.Run) do
		if (flat(entry.Root.Position) - flat(center)).Magnitude <= radius + 1 then
			MonsterService.Services.HeroService:DamagePlayer(entry.Player, damage, state.Level)
		end
	end
end

-- Roter Kreis am Boden, nach delay Schaden fuer alle darin
local function telegraph(state, center: Vector3, radius: number, delay: number, damage: number, color: Color3?)
	MonsterService.Services.Net.SendEffect(state.Run.Players, "Telegraph", {
		Position = Vector3.new(center.X, state.Run.FloorY, center.Z),
		Radius = radius,
		Duration = delay,
		Color = color or TELEGRAPH,
	})
	task.delay(delay, function()
		if state.Alive and os.clock() >= state.StunUntil then
			hitPlayersInCircle(state, center, radius, damage)
			MonsterService.Services.Net.SendEffect(state.Run.Players, "Impact", { Position = Vector3.new(center.X, state.Run.FloorY, center.Z), Radius = radius, Color = color or TELEGRAPH })
		end
	end)
end

local function face(state, position: Vector3)
	local root = state.Root
	local look = Vector3.new(position.X, root.Position.Y, position.Z)
	if (look - root.Position).Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, look)
	end
end

local function meleeAttack(state, target)
	local now = os.clock()
	state.BusyUntil = now + 0.5
	state.NextAttack = now + 1.7
	face(state, target.Root.Position)
	MonsterService.Services.Net.SendEffect(state.Run.Players, "Windup", { Model = state.Model, Duration = 0.45 })
	task.delay(0.45, function()
		if not state.Alive or os.clock() < state.StunUntil then
			return
		end
		local root = target.Root
		if root.Parent and (flat(root.Position) - flat(state.Root.Position)).Magnitude <= state.Reach + 3 then
			MonsterService.Services.HeroService:DamagePlayer(target.Player, state.Dmg, state.Level)
			MonsterService.Services.Net.SendEffect(state.Run.Players, "Swipe", { From = state.Root.Position, To = root.Position, Color = state.Def.Color })
		end
	end)
end

local function rangedAttack(state, target)
	local now = os.clock()
	state.BusyUntil = now + 0.6
	state.NextAttack = now + rng:NextNumber(2.4, 3.2)
	face(state, target.Root.Position)
	local spot = target.Root.Position
	MonsterService.Services.Net.SendEffect(state.Run.Players, "Lob", { From = state.Root.Position, To = spot, Duration = 1.1, Color = state.Def.Color })
	telegraph(state, spot, 6, 1.1, state.Dmg)
end

local function bruteAttack(state)
	local now = os.clock()
	local radius = 6 + 3 * state.Def.Size
	state.BusyUntil = now + 1.1
	state.NextAttack = now + 3.2
	telegraph(state, state.Root.Position, radius, 1.05, state.Dmg * 1.3)
end

local BossAbilities = {}

function BossAbilities.Slam(state)
	state.BusyUntil = os.clock() + 1.6
	telegraph(state, state.Root.Position, 22, 1.5, state.Dmg * 2, BOSS_TELEGRAPH)
end

function BossAbilities.Barrage(state)
	state.BusyUntil = os.clock() + 1.0
	local room = state.Run.Rooms[state.Run.Room]
	local spots = {}
	for _, entry in alivePlayers(state.Run) do
		table.insert(spots, entry.Root.Position)
	end
	for _ = 1, 3 + (if state.Enraged then 3 else 0) do
		table.insert(spots, room.Center + Vector3.new(rng:NextNumber(-1, 1) * room.Half * 0.8, 0, rng:NextNumber(-1, 1) * room.Half * 0.8))
	end
	for i, spot in spots do
		task.delay((i - 1) * 0.08, telegraph, state, spot, 8, 1.3, state.Dmg * 1.4, BOSS_TELEGRAPH)
	end
end

function BossAbilities.Summon(state)
	state.BusyUntil = os.clock() + 1.2
	local run = state.Run
	local minions = 0
	for _, other in monsters do
		if other.Run == run and other.Minion and other.Alive then
			minions += 1
		end
	end
	local count = math.min(2 + #run.Players, 8 - minions)
	for i = 1, count do
		local angle = (i / math.max(count, 1)) * math.pi * 2
		local position = state.Root.Position + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12)
		position = Vector3.new(position.X, run.FloorY, position.Z)
		MonsterService:Spawn(run, state.Def.Summon, position, { Minion = true })
	end
	MonsterService.Services.Net.SendEffect(run.Players, "Roar", { Model = state.Model, Name = state.Def.Name })
end

local function think(state, now: number)
	local humanoid = state.Humanoid
	if now < state.StunUntil or now < state.BusyUntil then
		humanoid:Move(Vector3.zero)
		return
	end
	local players = alivePlayers(state.Run)
	if #players == 0 then
		humanoid:Move(Vector3.zero)
		return
	end
	local root = state.Root
	local target, best = nil, math.huge
	for _, entry in players do
		local d = (flat(entry.Root.Position) - flat(root.Position)).Magnitude
		if d < best then
			target, best = entry, d
		end
	end
	local speed = (state.Def.Speed or 10) * (if now < state.SlowUntil then 0.5 else 1) * (if state.Enraged then 1.25 else 1)
	humanoid.WalkSpeed = speed

	if state.Boss then
		if now >= state.NextAbility then
			state.AbilityIndex = state.AbilityIndex % #state.Def.Abilities + 1
			state.NextAbility = now + (if state.Enraged then 3 else 4.2)
			BossAbilities[state.Def.Abilities[state.AbilityIndex]](state)
			return
		end
		if best <= state.Reach + 2 then
			humanoid:Move(Vector3.zero)
			if now >= state.NextAttack then
				meleeAttack(state, target)
			end
		else
			humanoid:MoveTo(target.Root.Position)
		end
		return
	end

	local ai = state.Def.AI
	if ai == "Flee" then
		-- Weg vom naechsten Spieler, aber im Raum bleiben
		local room = state.Run.Rooms[state.Run.Room]
		local away = flat(root.Position - target.Root.Position)
		away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
		local goal = root.Position + away * 14
		if room then
			local limit = room.Half - 5
			local offset = goal - room.Center
			if math.abs(offset.X) > limit or math.abs(offset.Z) > limit then
				goal = room.Center + Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
			end
		end
		humanoid:MoveTo(goal)
	elseif ai == "Ranged" then
		if best > 30 then
			humanoid:MoveTo(target.Root.Position)
		elseif best < 13 then
			local away = flat(root.Position - target.Root.Position)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			humanoid:MoveTo(root.Position + away * 10)
		else
			humanoid:Move(Vector3.zero)
			if now >= state.NextAttack then
				rangedAttack(state, target)
			end
		end
	elseif ai == "Brute" then
		if best <= 6 + 3 * state.Def.Size and now >= state.NextAttack then
			humanoid:Move(Vector3.zero)
			bruteAttack(state)
		else
			humanoid:MoveTo(target.Root.Position)
		end
	else
		if best <= state.Reach then
			humanoid:Move(Vector3.zero)
			if now >= state.NextAttack then
				meleeAttack(state, target)
			end
		else
			humanoid:MoveTo(target.Root.Position)
		end
	end
end

function MonsterService:Start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			-- Kopie, weil Bosse waehrend der Schleife Monster rufen
			local list = {}
			for _, state in monsters do
				table.insert(list, state)
			end
			for _, state in list do
				if state.Alive and state.Treasure and now >= state.EscapeAt then
					MonsterService:Escape(state)
				elseif state.Alive and state.Root.Parent then
					local ok, err = pcall(think, state, now)
					if not ok then
						warn("[Monster]", err)
					end
					-- Herausgefallen oder festgesteckt: zurueck in die Raummitte
					if state.Root.Position.Y < state.Run.FloorY - 20 then
						local room = state.Run.Rooms[state.Run.Room]
						if room then
							state.Model:PivotTo(CFrame.new(room.Center + Vector3.new(0, 4, 0)))
						end
					end
				end
			end
		end
	end)
end

return MonsterService
