-- Tuerme, Kerne, Minion-Wellen und Dschungel-Monster samt ihrer KI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local LaneService = {
	Services = nil :: any,
	Towers = {} :: { any },
	Cores = {} :: { [number]: any },
	Minions = {} :: { any },
	Monsters = {} :: { any },
	Wave = 0,
	Running = false,
	Epoch = 0,
	Overtime = false,
}

local MAP = Config.Map
local TICK = 0.1

local STRUCTURE_KINDS = { Tower = true, Core = true }
local MINION_TARGETS = { Minion = true, Hero = true, Tower = true, Core = true }
local NON_HERO = { Minion = true, Tower = true, Core = true }
local HERO_ONLY = { Hero = true }
local TOWER_TARGETS = { Minion = true, Hero = true }

local Combat -- CombatService (wird in Init gesetzt)

function LaneService:Init(services)
	self.Services = services
	Combat = services.CombatService
	Combat.DeathHandlers.Minion = function(unit, killer)
		self:OnMinionDeath(unit, killer)
	end
	Combat.DeathHandlers.Tower = function(unit, killer)
		self:OnTowerDeath(unit, killer)
	end
	Combat.DeathHandlers.Core = function(unit, killer)
		self:OnCoreDeath(unit, killer)
	end
	Combat.DeathHandlers.Monster = function(unit, killer)
		self:OnMonsterDeath(unit, killer)
	end
end

local function lanePoints(lane: string, team: number)
	local points = MAP.Lanes[lane]
	if team == 1 then
		return points
	end
	local reversed = {}
	for i = #points, 1, -1 do
		table.insert(reversed, points[i])
	end
	return reversed
end
LaneService.LanePoints = lanePoints

---------------------------------------------------------------- Aufbau

function LaneService:Clear()
	self.Epoch += 1
	self.Running = false
	self.Overtime = false
	self.Wave = 0
	for _, list in { self.Towers, self.Minions, self.Monsters } do
		for _, unit in list do
			Combat:Unregister(unit)
			if unit.Model then
				unit.Model:Destroy()
			end
		end
	end
	for _, core in self.Cores do
		Combat:Unregister(core)
		if core.Model then
			core.Model:Destroy()
		end
	end
	self.Towers, self.Minions, self.Monsters, self.Cores = {}, {}, {}, {}
	local rubble = workspace:FindFirstChild("Rubble")
	if rubble then
		rubble:Destroy()
	end
end

function LaneService:Build()
	self:Clear()
	local world = self.Services.WorldService
	for team = 1, 2 do
		local color = Config.Teams[team].Color
		for _, info in MAP.Towers do
			local position = world.Mirror(info.Position, team)
			local stats = Config.Structures["Tower" .. info.Tier]
			local model = world:MakeTower(team, info.Tier, position)
			local unit = Combat:Register({
				Kind = "Tower",
				Name = Config.Teams[team].Name .. " Tower",
				Team = team,
				Tier = info.Tier,
				Lane = info.Lane,
				Model = model,
				Home = position,
				HP = stats.HP,
				MaxHP = stats.HP,
				Armor = stats.Armor,
				Damage = stats.Damage,
				Range = stats.Range,
				AttackSpeed = stats.AttackSpeed,
				Gold = stats.Gold,
				Ranged = true,
				ShotFx = "Beam",
				ShotHeight = model:GetAttribute("ShotHeight"),
				FxColor = color,
				Radius = 5,
			})
			table.insert(self.Towers, unit)
		end
		local corePosition = MAP.Core[team]
		local stats = Config.Structures.Core
		local core = Combat:Register({
			Kind = "Core",
			Name = Config.Teams[team].Name .. " Core",
			Team = team,
			Model = world:MakeCore(team, corePosition),
			Home = corePosition,
			HP = stats.HP,
			MaxHP = stats.HP,
			Armor = stats.Armor,
			Damage = stats.Damage,
			Range = stats.Range,
			AttackSpeed = stats.AttackSpeed,
			Ranged = true,
			ShotFx = "Beam",
			ShotHeight = 11,
			FxColor = color,
			Radius = 8,
		})
		self.Cores[team] = core
	end
	self:UpdateProtection()
end

-- Zweite Reihe erst angreifbar, wenn der Turm davor faellt; der Kern erst, wenn ein Turm der zweiten Reihe faellt
function LaneService:UpdateProtection()
	for _, tower in self.Towers do
		if tower.Tier == 2 then
			local protected = false
			for _, other in self.Towers do
				if other.Team == tower.Team and other.Lane == tower.Lane and other.Tier == 1 and not other.Dead then
					protected = true
				end
			end
			tower.Protected = protected
			Combat:Sync(tower)
		end
	end
	for team, core in self.Cores do
		local protected = true
		for _, tower in self.Towers do
			if tower.Team == team and tower.Tier == 2 and tower.Dead then
				protected = false
			end
		end
		core.Protected = protected
		Combat:Sync(core)
		local barrier = core.Model and core.Model:FindFirstChild("Barrier") :: BasePart?
		if barrier then
			barrier.Transparency = if protected then 0 else 1
		end
	end
end

function LaneService:TowersStanding(team: number): number
	local count = 0
	for _, tower in self.Towers do
		if tower.Team == team and not tower.Dead then
			count += 1
		end
	end
	return count
end

---------------------------------------------------------------- Wellen

function LaneService:SpawnMinion(team: number, lane: string, kind: string, index: number)
	local stats = Config.Minions[kind]
	local points = lanePoints(lane, team)
	local start = points[1] + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
	local scale = 1 + Config.MinionGrowthPerWave * self.Wave
	local hp = stats.HP * scale * (if self.Overtime then 1.5 else 1)
	local model = self.Services.WorldService:MakeMinion(team, kind, start)
	local unit = Combat:Register({
		Kind = "Minion",
		Type = kind,
		Name = Config.Teams[team].Name .. " " .. kind,
		Team = team,
		Lane = lane,
		Path = points,
		PathIndex = 2,
		Model = model,
		Home = start,
		HP = hp,
		MaxHP = hp,
		Armor = stats.Armor,
		Damage = stats.Damage * scale,
		Range = stats.Range,
		AttackSpeed = stats.AttackSpeed,
		Speed = stats.Speed,
		Aggro = stats.Aggro,
		Gold = stats.Gold,
		XP = stats.XP,
		Ranged = kind ~= "Melee",
		FxColor = Config.Teams[team].Color,
		Radius = if kind == "Siege" then 2.2 else 1.3,
		Offset = ((index % 3) - 1) * 2.5,
		DamageScale = if self.Overtime then 1.6 else 1,
		Height = model.PrimaryPart.Position.Y,
	})
	table.insert(self.Minions, unit)
end

function LaneService:SpawnWave()
	self.Wave += 1
	local epoch = self.Epoch
	local kinds = table.clone(Config.Wave)
	if self.Wave % Config.SiegeEvery == 0 then
		table.insert(kinds, "Siege")
	end
	for index, kind in kinds do
		task.delay((index - 1) * 0.9, function()
			if self.Epoch ~= epoch or not self.Running then
				return
			end
			for team = 1, 2 do
				for _, lane in MAP.LaneOrder do
					self:SpawnMinion(team, lane, kind, index)
				end
			end
		end)
	end
end

function LaneService:SetOvertime()
	self.Overtime = true
	for _, minion in self.Minions do
		minion.DamageScale = 1.6
	end
end

---------------------------------------------------------------- Monster

function LaneService:SpawnMonster(id: string, position: Vector3)
	local info = Config.Monsters[id]
	local model = self.Services.WorldService:MakeMonster(id, position)
	local unit = Combat:Register({
		Kind = "Monster",
		MonsterId = id,
		Name = info.Name,
		Team = 0,
		Boss = info.Boss,
		Model = model,
		Home = position,
		HP = info.HP,
		MaxHP = info.HP,
		Armor = info.Armor,
		Damage = info.Damage,
		Range = info.Range,
		AttackSpeed = info.AttackSpeed,
		Speed = 15,
		Gold = info.Gold,
		XP = info.XP,
		Ranged = info.Range > 10,
		FxColor = info.Color,
		Radius = if info.Boss then 5 else 2.5,
		Height = model.PrimaryPart.Position.Y,
	})
	model:SetAttribute("Boss", info.Boss == true)
	table.insert(self.Monsters, unit)
	if info.Boss then
		self.Services.Net.SendAnnounce(`The {info.Name} has appeared!`, info.Color)
	end
end

function LaneService:ScheduleMonster(id: string, position: Vector3, delay: number)
	local epoch = self.Epoch
	task.delay(delay, function()
		if self.Epoch == epoch and self.Running then
			self:SpawnMonster(id, position)
		end
	end)
end

---------------------------------------------------------------- Ablauf

function LaneService:StartMatch()
	self.Running = true
	local epoch = self.Epoch
	for team = 1, 2 do
		for _, camp in MAP.Camps do
			self:ScheduleMonster(camp.Id, self.Services.WorldService.Mirror(camp.Position, team), 20)
		end
	end
	for _, boss in MAP.Bosses do
		self:ScheduleMonster(boss.Id, boss.Position, Config.Monsters[boss.Id].FirstSpawn or 120)
	end
	task.spawn(function()
		task.wait(Config.FirstWaveDelay)
		while self.Running and self.Epoch == epoch do
			self:SpawnWave()
			task.wait(Config.WaveInterval)
		end
	end)
end

function LaneService:Stop()
	self.Running = false
end

---------------------------------------------------------------- Tod

local function removeFrom(list, unit)
	local index = table.find(list, unit)
	if index then
		table.remove(list, index)
	end
end

local function poof(self, unit)
	Combat:Unregister(unit)
	if unit.Model then
		self.Services.Net.SendFx("Poof", { At = Combat.Position(unit), Color = unit.FxColor })
		local model = unit.Model
		task.delay(0.15, function()
			model:Destroy()
		end)
	end
end

function LaneService:OnMinionDeath(unit, killer)
	removeFrom(self.Minions, unit)
	local heroes = self.Services.HeroService
	local position = Combat.Position(unit)
	if killer and killer.Kind == "Hero" then
		heroes:GiveGold(killer, unit.Gold, position)
		killer.CreepScore = (killer.CreepScore or 0) + 1
	end
	heroes:ShareXP(if unit.Team == 1 then 2 else 1, position, unit.XP)
	poof(self, unit)
end

function LaneService:OnMonsterDeath(unit, killer)
	removeFrom(self.Monsters, unit)
	local heroes = self.Services.HeroService
	local position = Combat.Position(unit)
	local info = Config.Monsters[unit.MonsterId]
	poof(self, unit)
	local team = killer and killer.Team or 0
	if team == 0 then
		self:ScheduleMonster(unit.MonsterId, unit.Home, info.Respawn)
		return
	end
	if info.Boss then
		for _, hero in heroes.Heroes do
			if hero.Team == team then
				heroes:GiveGold(hero, info.Gold, nil)
			end
		end
		self.Services.Net.SendAnnounce(`{Config.Teams[team].Name} defeated the {info.Name}!`, Config.Teams[team].Color)
		if info.Buff == "Might" then
			heroes:GiveMight(team)
		end
	elseif killer.Kind == "Hero" then
		heroes:GiveGold(killer, info.Gold, position)
	end
	heroes:ShareXP(team, position, info.XP)
	self:ScheduleMonster(unit.MonsterId, unit.Home, info.Respawn)
end

local function rubble(position: Vector3, color: Color3)
	local folder = workspace:FindFirstChild("Rubble")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Rubble"
		folder.Parent = workspace
	end
	for i = 1, 6 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Size = Vector3.new(math.random(2, 4), math.random(1, 3), math.random(2, 4))
		p.CFrame = CFrame.new(position + Vector3.new(math.random(-4, 4), 0.8, math.random(-4, 4))) * CFrame.Angles(math.random(), math.random() * 6, math.random())
		p.Color = if i <= 2 then color else Color3.fromRGB(150, 140, 135)
		p.Material = if i <= 2 then Enum.Material.Neon else Enum.Material.Slate
		p.Parent = folder
	end
end

function LaneService:OnTowerDeath(unit, killer)
	local heroes = self.Services.HeroService
	local team = if unit.Team == 1 then 2 else 1
	for _, hero in heroes.Heroes do
		if hero.Team == team then
			heroes:GiveGold(hero, unit.Gold, nil)
		end
	end
	self.Services.Net.SendFx("Boom", { At = unit.Home, Color = unit.FxColor, Size = 16 })
	Combat:Unregister(unit)
	if unit.Model then
		unit.Model:Destroy()
	end
	rubble(unit.Home, unit.FxColor)
	local by = if killer and killer.Kind == "Hero" then killer.Name else Config.Teams[team].Name
	self.Services.Net.SendAnnounce(`{by} destroyed a {Config.Teams[unit.Team].Name} tower!`, Config.Teams[team].Color)
	self:UpdateProtection()
	self.Services.MatchService:OnTowerDestroyed(team)
end

function LaneService:OnCoreDeath(unit, _killer)
	self.Services.Net.SendFx("Boom", { At = unit.Home, Color = unit.FxColor, Size = 40 })
	if unit.Model then
		for _, child in unit.Model:GetDescendants() do
			if child:IsA("BasePart") then
				child.Transparency = 1
			end
		end
	end
	rubble(unit.Home, unit.FxColor)
	self.Services.MatchService:EndMatch(if unit.Team == 1 then 2 else 1)
end

---------------------------------------------------------------- KI

-- Ein Held hat einen Gegner unter dessen Turm angegriffen: der Turm nimmt ihn ins Visier
function LaneService:OnHeroAttackedHero(attacker, victim)
	for _, tower in self.Towers do
		if tower.Team == victim.Team and not tower.Dead and Combat.Distance(tower, attacker) <= tower.Range + 2 then
			tower.Target = attacker
			tower.AggroUntil = Combat.Now() + 3
		end
	end
	local core = self.Cores[victim.Team]
	if core and not core.Dead and Combat.Distance(core, attacker) <= core.Range + 2 then
		core.Target = attacker
		core.AggroUntil = Combat.Now() + 3
	end
end

local function structureTick(structure)
	if not Combat.Alive(structure) then
		return
	end
	local now = Combat.Now()
	local target = structure.Target
	local position = Combat.Position(structure)
	local valid = target and Combat:Targetable(target) and Combat:InRange(structure, target)
	if valid and target.Kind == "Hero" and (structure.AggroUntil or 0) < now then
		-- Helden nur weiter beschiessen, wenn keine Minions im Weg sind
		local minion = Combat:NearestEnemy(structure.Team, position, structure.Range, { Minion = true })
		if minion then
			valid = false
		end
	end
	if not valid then
		target = Combat:NearestEnemy(structure.Team, position, structure.Range, { Minion = true }) or Combat:NearestEnemy(structure.Team, position, structure.Range, HERO_ONLY)
		structure.Target = target
		structure.Streak = 0
	end
	if target and Combat:CanAttack(structure) then
		local damage = structure.Damage
		if target.Kind == "Minion" then
			damage *= Config.TowerMinionDamage
		elseif target.Kind == "Hero" then
			-- Jeder weitere Treffer auf denselben Helden tut mehr weh (max. +60 %)
			structure.Streak = math.min((structure.Streak or 0) + 1, 4)
			damage *= 1 + (structure.Streak - 1) * 0.2
		end
		Combat:Attack(structure, target, damage)
	end
end

local function separation(unit, list): Vector3
	local push = Vector3.zero
	local position = Combat.Position(unit)
	for _, other in list do
		if other ~= unit and other.Team == unit.Team then
			local offset = position - Combat.Position(other)
			local distance = offset.Magnitude
			if distance > 0.01 and distance < 2.6 then
				push += offset.Unit * (2.6 - distance)
			end
		end
	end
	return push
end

local function moveUnit(unit, goal: Vector3, dt: number, extra: Vector3?)
	local position = Combat.Position(unit)
	local offset = goal - position
	local distance = offset.Magnitude
	local speed = unit.Speed * Combat.SlowFactor(unit)
	local step = Vector3.zero
	if distance > 0.1 then
		step = offset.Unit * math.min(distance, speed * dt)
	end
	if extra then
		step += extra * math.min(1, dt * 4)
	end
	local newPosition = position + step
	newPosition = Vector3.new(math.clamp(newPosition.X, -MAP.HalfX, MAP.HalfX), 0, math.clamp(newPosition.Z, -MAP.HalfZ, MAP.HalfZ))
	local facing = if offset.Magnitude > 0.1 then offset.Unit else unit.Root.CFrame.LookVector
	local height = Vector3.new(0, unit.Height or 1.5, 0)
	unit.Root.CFrame = CFrame.lookAt(newPosition + height, newPosition + height + Vector3.new(facing.X, 0, facing.Z))
end

local function face(unit, target)
	local position = Combat.Position(unit)
	local direction = Combat.Position(target) - position
	if direction.Magnitude > 0.1 then
		local height = Vector3.new(0, unit.Height or 1.5, 0)
		unit.Root.CFrame = CFrame.lookAt(position + height, position + height + direction.Unit)
	end
end

local function minionTick(self, unit, dt: number)
	if not Combat.Alive(unit) or Combat.IsStunned(unit) then
		return
	end
	local position = Combat.Position(unit)
	local target = unit.Target
	if not (target and Combat:Targetable(target) and Combat.Distance(unit, target) <= unit.Aggro + 6) then
		target = Combat:NearestEnemy(unit.Team, position, unit.Aggro, NON_HERO) or Combat:NearestEnemy(unit.Team, position, unit.Aggro, MINION_TARGETS)
		unit.Target = target
	end
	if target and target.Kind == "Hero" then
		-- Minions wechseln zu einem Minion, sobald einer in Reichweite ist
		local minion = Combat:NearestEnemy(unit.Team, position, unit.Range + 2, NON_HERO)
		if minion then
			target = minion
			unit.Target = minion
		end
	end
	if target then
		if Combat:InRange(unit, target) then
			face(unit, target)
			if Combat:CanAttack(unit) then
				Combat:Attack(unit, target)
			end
		else
			moveUnit(unit, Combat.Position(target), dt, separation(unit, self.Minions))
		end
		return
	end
	-- Der Lane folgen
	local goal = unit.Path[unit.PathIndex]
	if not goal then
		local core = self.Cores[if unit.Team == 1 then 2 else 1]
		goal = core and core.Home or position
	else
		local nextPoint = unit.Path[unit.PathIndex + 1]
		local side = if nextPoint then (nextPoint - goal).Unit:Cross(Vector3.yAxis) else Vector3.zero
		goal += side * unit.Offset
		if (goal - position).Magnitude < 4 then
			unit.PathIndex += 1
		end
	end
	moveUnit(unit, goal, dt, separation(unit, self.Minions))
end

local function monsterTick(unit, dt: number)
	if not Combat.Alive(unit) or Combat.IsStunned(unit) then
		return
	end
	local target = unit.Target
	local attacker = unit.LastAttacker
	if not target and attacker and attacker.Kind == "Hero" and Combat:Targetable(attacker) then
		target = attacker
		unit.Target = attacker
	end
	if target then
		local tooFar = (Combat.Position(target) - unit.Home).Magnitude > Config.LeashRange or (Combat.Position(unit) - unit.Home).Magnitude > Config.LeashRange
		if not Combat:Targetable(target) or tooFar then
			-- Zurueck nach Hause und voll heilen
			unit.Target = nil
			unit.LastAttacker = nil
			unit.Returning = true
			target = nil
		end
	end
	if unit.Returning then
		moveUnit(unit, unit.Home, dt)
		unit.HP = math.min(unit.MaxHP, unit.HP + unit.MaxHP * 0.2 * dt)
		Combat:Sync(unit)
		if (Combat.Position(unit) - unit.Home).Magnitude < 1 then
			unit.Returning = false
			unit.HP = unit.MaxHP
			unit.Damagers = {}
			Combat:Sync(unit)
		end
		return
	end
	if target then
		if Combat:InRange(unit, target) then
			face(unit, target)
			if Combat:CanAttack(unit) then
				Combat:Attack(unit, target)
			end
		else
			moveUnit(unit, Combat.Position(target), dt)
		end
	end
end

function LaneService:Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		local step = math.min(accumulator, 0.3)
		accumulator = 0
		if not self.Running then
			return
		end
		for _, tower in self.Towers do
			structureTick(tower)
		end
		for _, core in self.Cores do
			structureTick(core)
		end
		for _, minion in table.clone(self.Minions) do
			minionTick(self, minion, step)
		end
		for _, monster in table.clone(self.Monsters) do
			monsterTick(monster, step)
		end
	end)
end

LaneService.StructureKinds = STRUCTURE_KINDS
LaneService.TowerTargets = TOWER_TARGETS

return LaneService
