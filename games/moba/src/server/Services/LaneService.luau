-- Gebaeude (Tuerme in drei Reihen, Inhibitoren, Nexus-Tuerme, Nexus) und Minion-Wellen samt KI.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local LaneService = {
	Services = nil :: any,
	Towers = {} :: { any },
	Inhibitors = {} :: { any },
	Nexus = {} :: { [number]: any },
	Minions = {} :: { any },
	Wave = 0,
	Running = false,
	Epoch = 0,
	Overtime = false,
	FirstTower = false,
}

local MAP = Config.Map
local TICK = 0.1

local MINION_TARGETS = { Minion = true, Hero = true, Tower = true, Inhibitor = true, Nexus = true }
local NON_HERO = { Minion = true, Tower = true, Inhibitor = true, Nexus = true }
local HERO_ONLY = { Hero = true }
local MINIONS = { Minion = true }

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
	Combat.DeathHandlers.Inhibitor = function(unit, killer)
		self:OnInhibitorDeath(unit, killer)
	end
	Combat.DeathHandlers.Nexus = function(unit, killer)
		self:OnNexusDeath(unit, killer)
	end
end

LaneService.LanePoints = Config.LanePoints

local function elapsed(): number
	return LaneService.Services.MatchService:Elapsed()
end

local function enemyOf(team: number): number
	return if team == 1 then 2 else 1
end

---------------------------------------------------------------- Aufbau

function LaneService:Clear()
	self.Epoch += 1
	self.Running = false
	self.Overtime = false
	self.FirstTower = false
	self.Wave = 0
	for _, list in { self.Towers, self.Minions, self.Inhibitors } do
		for _, unit in list do
			Combat:Unregister(unit)
			if unit.Model then
				unit.Model:Destroy()
			end
		end
	end
	for _, nexus in self.Nexus do
		Combat:Unregister(nexus)
		if nexus.Model then
			nexus.Model:Destroy()
		end
	end
	self.Towers, self.Minions, self.Inhibitors, self.Nexus = {}, {}, {}, {}
	local rubble = workspace:FindFirstChild("Rubble")
	if rubble then
		rubble:Destroy()
	end
end

function LaneService:AddTower(team: number, tier: number, lane: string?, position: Vector3)
	local world = self.Services.WorldService
	local statsKey = if lane then "Tower" .. tier else "NexusTower"
	local stats = Config.Structures[statsKey]
	local model = world:MakeTower(team, if lane then tier else 4, position)
	local unit = Combat:Register({
		Kind = "Tower",
		Name = Config.Teams[team].Name .. (if lane then ` {lane} Tower {tier}` else " Nexus Tower"),
		Team = team,
		Tier = if lane then tier else 4,
		Lane = lane,
		Model = model,
		Home = position,
		HP = stats.HP,
		MaxHP = stats.HP,
		Armor = stats.Armor,
		MR = stats.MR,
		BaseDamage = stats.Damage,
		Damage = stats.Damage,
		Range = stats.Range,
		AttackSpeed = stats.AttackSpeed,
		Gold = stats.Gold,
		GlobalGold = stats.GlobalGold,
		Plates = stats.Plates or 0,
		PlateGold = stats.PlateGold or 0,
		Ranged = true,
		ShotFx = "Beam",
		ShotHeight = model:GetAttribute("ShotHeight"),
		FxColor = Config.Teams[team].Color,
		Radius = 5,
	})
	model:SetAttribute("Plates", unit.Plates)
	table.insert(self.Towers, unit)
	return unit
end

function LaneService:AddInhibitor(team: number, lane: string, position: Vector3)
	local stats = Config.Structures.Inhibitor
	local unit = Combat:Register({
		Kind = "Inhibitor",
		Name = Config.Teams[team].Name .. ` {lane} Inhibitor`,
		Team = team,
		Lane = lane,
		Model = self.Services.WorldService:MakeInhibitor(team, position),
		Home = position,
		HP = stats.HP,
		MaxHP = stats.HP,
		Armor = stats.Armor,
		MR = stats.MR,
		Gold = stats.Gold,
		GlobalGold = stats.GlobalGold,
		Range = 0,
		Damage = 0,
		AttackSpeed = 0.1,
		FxColor = Config.Teams[team].Color,
		Radius = 5,
	})
	table.insert(self.Inhibitors, unit)
	return unit
end

function LaneService:Build()
	self:Clear()
	for team = 1, 2 do
		for _, info in MAP.Towers do
			local lane = if team == 1 then info.Lane else Config.MirrorLane[info.Lane]
			self:AddTower(team, info.Tier, lane, Config.Mirror(info.Position, team))
		end
		for _, position in MAP.NexusTowers do
			self:AddTower(team, 4, nil, Config.Mirror(position, team))
		end
		for _, info in MAP.Inhibitors do
			local lane = if team == 1 then info.Lane else Config.MirrorLane[info.Lane]
			self:AddInhibitor(team, lane, Config.Mirror(info.Position, team))
		end
		local position = Config.Mirror(MAP.Nexus, team)
		local stats = Config.Structures.Nexus
		self.Nexus[team] = Combat:Register({
			Kind = "Nexus",
			Name = Config.Teams[team].Name .. " Nexus",
			Team = team,
			Model = self.Services.WorldService:MakeNexus(team, position),
			Home = position,
			HP = stats.HP,
			MaxHP = stats.HP,
			Armor = stats.Armor,
			MR = stats.MR,
			Range = 0,
			Damage = 0,
			AttackSpeed = 0.1,
			FxColor = Config.Teams[team].Color,
			Radius = 9,
		})
	end
	self:UpdateProtection()
end

local function standing(unit): boolean
	return unit ~= nil and not unit.Dead
end

function LaneService:Tower(team: number, lane: string?, tier: number)
	for _, tower in self.Towers do
		if tower.Team == team and tower.Lane == lane and tower.Tier == tier then
			return tower
		end
	end
	return nil
end

function LaneService:Inhibitor(team: number, lane: string)
	for _, inhibitor in self.Inhibitors do
		if inhibitor.Team == team and inhibitor.Lane == lane then
			return inhibitor
		end
	end
	return nil
end

-- Reihenfolge wie im Original: Tier 1 -> 2 -> 3 -> Inhibitor -> Nexus-Tuerme -> Nexus
function LaneService:UpdateProtection()
	for _, tower in self.Towers do
		local protected = false
		if tower.Lane and tower.Tier > 1 then
			protected = standing(self:Tower(tower.Team, tower.Lane, tower.Tier - 1))
		elseif not tower.Lane then
			protected = true
			for _, inhibitor in self.Inhibitors do
				if inhibitor.Team == tower.Team and inhibitor.Dead then
					protected = false
				end
			end
		end
		tower.Protected = protected
		if not tower.Dead then
			Combat:Sync(tower)
		end
	end
	for _, inhibitor in self.Inhibitors do
		inhibitor.Protected = standing(self:Tower(inhibitor.Team, inhibitor.Lane, 3))
		if not inhibitor.Dead then
			Combat:Sync(inhibitor)
		end
	end
	for team, nexus in self.Nexus do
		local protected = false
		for _, tower in self.Towers do
			if tower.Team == team and tower.Tier == 4 and not tower.Dead then
				protected = true
			end
		end
		nexus.Protected = protected
		Combat:Sync(nexus)
		local barrier = nexus.Model and nexus.Model:FindFirstChild("Barrier") :: BasePart?
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

function LaneService:SpawnMinion(team: number, lane: string, kind: string, index: number, start: Vector3?, pathIndex: number?)
	local stats = Config.Minions[kind] or Config.Minions.Melee
	local points = Config.LanePoints(lane, team)
	local origin = start or points[1] + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2))
	local scale = 1 + Config.MinionGrowthPerWave * self.Wave
	local hp = stats.HP * scale * (if self.Overtime then 1.5 else 1)
	local damage = stats.Damage * scale
	if kind == "Herald" then
		hp, damage = 3500, 120
	end
	local model = self.Services.WorldService:MakeMinion(team, kind, origin)
	local unit = Combat:Register({
		Kind = "Minion",
		Type = kind,
		Name = Config.Teams[team].Name .. " " .. kind,
		Team = team,
		Lane = lane,
		Path = points,
		PathIndex = pathIndex or 2,
		Model = model,
		Home = origin,
		HP = hp,
		MaxHP = hp,
		Armor = stats.Armor,
		MR = stats.MR,
		Damage = damage,
		Range = if kind == "Herald" then 8 else stats.Range,
		AttackSpeed = stats.AttackSpeed,
		Speed = stats.Speed,
		Aggro = stats.Aggro,
		Gold = stats.Gold,
		XP = stats.XP,
		Ranged = kind == "Caster" or kind == "Siege",
		FxColor = Config.Teams[team].Color,
		Radius = if kind == "Herald" then 3.5 elseif kind == "Siege" or kind == "Super" then 2.2 else 1.3,
		Offset = ((index % 3) - 1) * 2.5,
		DamageScale = if self.Overtime then 1.6 else 1,
		Height = model.PrimaryPart.Position.Y,
	})
	if kind == "Herald" then
		unit.Charge = true
	end
	unit.ModifyIncoming = function(target, _source, dealt, _opts)
		if target.Empowered then
			return dealt * 0.5
		end
		return dealt
	end
	table.insert(self.Minions, unit)
	return unit
end

function LaneService:SpawnWave()
	self.Wave += 1
	local epoch = self.Epoch
	for team = 1, 2 do
		local enemy = enemyOf(team)
		for _, lane in MAP.LaneOrder do
			local kinds = table.clone(Config.Wave)
			if self.Wave % Config.SiegeEvery == 0 then
				table.insert(kinds, 4, "Siege")
			end
			-- Faellt ein gegnerischer Inhibitor, kommen in dieser Lane Super-Minions
			local inhibitor = self:Inhibitor(enemy, lane)
			if inhibitor and inhibitor.Dead then
				local allDown = true
				for _, other in self.Inhibitors do
					if other.Team == enemy and not other.Dead then
						allDown = false
					end
				end
				table.remove(kinds, 4)
				table.insert(kinds, 1, "Super")
				if allDown then
					table.insert(kinds, 1, "Super")
				end
			end
			for index, kind in kinds do
				task.delay((index - 1) * 0.8, function()
					if self.Epoch == epoch and self.Running then
						self:SpawnMinion(team, lane, kind, index)
					end
				end)
			end
		end
	end
	if self.Wave == 1 then
		self.Services.Net.SendAnnounce("Minions have spawned!", Color3.fromRGB(240, 240, 255))
	end
end

function LaneService:SetOvertime()
	self.Overtime = true
	for _, minion in self.Minions do
		minion.DamageScale = 1.6
	end
end

-- Herold-Ramme: laeuft die naechste Lane entlang und rammt Tuerme
function LaneService:SpawnHerald(team: number, position: Vector3)
	local bestLane, bestIndex, bestDistance = "Mid", 2, math.huge
	for _, lane in MAP.LaneOrder do
		local points = Config.LanePoints(lane, team)
		for i, point in points do
			local distance = (point - position).Magnitude
			if distance < bestDistance then
				bestLane, bestIndex, bestDistance = lane, i, distance
			end
		end
	end
	local unit = self:SpawnMinion(team, bestLane, "Herald", 2, position, math.min(bestIndex + 1, #Config.LanePoints(bestLane, team)))
	self.Services.Net.SendAnnounce(`{Config.Teams[team].Name} summoned the Siege Herald!`, Config.Teams[team].Color)
	return unit
end

---------------------------------------------------------------- Ablauf

function LaneService:StartMatch()
	self.Running = true
	local epoch = self.Epoch
	task.spawn(function()
		while self.Running and self.Epoch == epoch and elapsed() < Config.Timers.Minions do
			task.wait(0.5)
		end
		while self.Running and self.Epoch == epoch do
			self:SpawnWave()
			task.wait(Config.Timers.WaveInterval)
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
	if killer and killer.Kind == "Hero" and unit.Type ~= "Herald" then
		heroes:GiveGold(killer, unit.Gold, position)
		killer.CreepScore = (killer.CreepScore or 0) + 1
		heroes:OnUnitKilled(killer, unit)
	end
	heroes:ShareXP(enemyOf(unit.Team), position, unit.XP or 0)
	poof(self, unit)
end

local function rubble(position: Vector3, color: Color3)
	local folder = workspace:FindFirstChild("Rubble")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Rubble"
		folder.Parent = workspace
	end
	for i = 1, 7 do
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

-- Gold fuer Gebaeude: Helden in der Naehe teilen sich das lokale Gold, alle bekommen das globale Gold
function LaneService:StructureGold(unit, killer)
	local heroes = self.Services.HeroService
	local team = enemyOf(unit.Team)
	local near = {}
	for _, hero in heroes.Heroes do
		if hero.Team == team then
			if (unit.GlobalGold or 0) > 0 then
				heroes:GiveGold(hero, unit.GlobalGold, nil)
			end
			if Combat.Alive(hero) and Combat.Distance(hero, unit) <= 40 then
				table.insert(near, hero)
			end
		end
	end
	if killer and killer.Kind == "Hero" and not table.find(near, killer) then
		table.insert(near, killer)
	end
	if #near > 0 and (unit.Gold or 0) > 0 then
		for _, hero in near do
			heroes:GiveGold(hero, unit.Gold / #near, Combat.Position(unit))
		end
	end
end

local function hideModel(model: Model?)
	if not model then
		return
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Transparency = 1
			child.CanCollide = false
		elseif child:IsA("Light") then
			child.Enabled = false
		end
	end
end

function LaneService:OnTowerDeath(unit, killer)
	local team = enemyOf(unit.Team)
	self:StructureGold(unit, killer)
	if not self.FirstTower then
		self.FirstTower = true
		if killer and killer.Kind == "Hero" then
			self.Services.HeroService:GiveGold(killer, 150, Combat.Position(unit))
		end
		self.Services.Net.SendAnnounce("First Tower!", Config.Teams[team].Color)
	else
		self.Services.Net.SendAnnounce(`{Config.Teams[team].Name} destroyed a tower!`, Config.Teams[team].Color)
	end
	self.Services.Net.SendFx("Boom", { At = unit.Home, Color = unit.FxColor, Size = 16 })
	Combat:Unregister(unit)
	if unit.Model then
		unit.Model:Destroy()
	end
	rubble(unit.Home, unit.FxColor)
	if killer and killer.Kind == "Hero" then
		self.Services.HeroService:OnTakedownStructure(killer)
	end
	self:UpdateProtection()
	self.Services.MatchService:OnTowerDestroyed(team)
end

function LaneService:OnInhibitorDeath(unit, killer)
	local team = enemyOf(unit.Team)
	self:StructureGold(unit, killer)
	self.Services.Net.SendAnnounce(`{Config.Teams[team].Name} destroyed an inhibitor!`, Config.Teams[team].Color)
	self.Services.Net.SendFx("Boom", { At = unit.Home, Color = unit.FxColor, Size = 20 })
	hideModel(unit.Model)
	if unit.Model then
		unit.Model:SetAttribute("RespawnAt", Combat.Now() + Config.Timers.Inhibitor)
	end
	self:UpdateProtection()
	local epoch = self.Epoch
	task.delay(Config.Timers.Inhibitor, function()
		if self.Epoch ~= epoch or not self.Running then
			return
		end
		-- Wieder aufbauen
		local index = table.find(self.Inhibitors, unit)
		if index then
			table.remove(self.Inhibitors, index)
		end
		Combat:Unregister(unit)
		if unit.Model then
			unit.Model:Destroy()
		end
		self:AddInhibitor(unit.Team, unit.Lane, unit.Home)
		self:UpdateProtection()
		self.Services.Net.SendAnnounce(`{Config.Teams[unit.Team].Name}'s inhibitor has respawned`, Config.Teams[unit.Team].Color)
	end)
end

function LaneService:OnNexusDeath(unit, _killer)
	self.Services.Net.SendFx("Boom", { At = unit.Home, Color = unit.FxColor, Size = 44 })
	hideModel(unit.Model)
	rubble(unit.Home, unit.FxColor)
	self.Services.MatchService:EndMatch(enemyOf(unit.Team))
end

---------------------------------------------------------------- KI

-- Ein Held greift einen Gegner an: Tuerme und Minions in der Naehe des Opfers helfen ihm
function LaneService:OnHeroAttackedHero(attacker, victim)
	local t = Combat.Now()
	for _, tower in self.Towers do
		if tower.Team == victim.Team and not tower.Dead and Combat.Distance(tower, attacker) <= tower.Range + 2 and Combat.Visible(attacker, tower.Team) then
			if tower.Target ~= attacker then
				tower.Streak = 0
			end
			tower.Target = attacker
			tower.AggroUntil = t + 3
		end
	end
	for _, minion in self.Minions do
		if minion.Team == victim.Team and (t - (minion.CallAt or 0)) > 2 and Combat.Distance(minion, attacker) <= 18 then
			minion.Target = attacker
			minion.CallAt = t
		end
	end
end

-- Platten: bis zur Platten-Zeit gibt jedes verlorene Fuenftel eines aeusseren Turms Gold
local function checkPlates(self, tower, attacker)
	if (tower.Plates or 0) <= 0 then
		return
	end
	if elapsed() >= Config.Timers.Plates then
		tower.Plates = 0
		if tower.Model then
			tower.Model:SetAttribute("Plates", 0)
		end
		return
	end
	local threshold = tower.MaxHP * (tower.Plates - 1) / 5
	while tower.Plates > 0 and tower.HP <= threshold + 0.01 do
		tower.Plates -= 1
		threshold = tower.MaxHP * (tower.Plates - 1) / 5
		local heroes = self.Services.HeroService
		local near = {}
		for _, hero in heroes.Heroes do
			if hero.Team ~= tower.Team and Combat.Alive(hero) and Combat.Distance(hero, tower) <= 32 then
				table.insert(near, hero)
			end
		end
		if #near == 0 and attacker and attacker.Kind == "Hero" then
			near = { attacker }
		end
		for _, hero in near do
			heroes:GiveGold(hero, tower.PlateGold / #near, Combat.Position(tower))
		end
		if tower.Model then
			tower.Model:SetAttribute("Plates", tower.Plates)
		end
		self.Services.Net.SendFx("Plate", { At = tower.Home, Color = tower.FxColor })
	end
end

local function structureTick(self, structure)
	if not Combat.Alive(structure) then
		return
	end
	local t = Combat.Now()
	local target = structure.Target
	local position = Combat.Position(structure)
	local valid = target and Combat:Targetable(target, structure.Team) and Combat:InRange(structure, target)
	if valid and target.Kind == "Hero" and (structure.AggroUntil or 0) < t then
		-- Helden nur weiter beschiessen, wenn keine Minions im Weg sind
		if Combat:NearestEnemy(structure.Team, position, structure.Range, MINIONS) then
			valid = false
		end
	end
	if not valid then
		target = Combat:NearestEnemy(structure.Team, position, structure.Range, MINIONS) or Combat:NearestEnemy(structure.Team, position, structure.Range, HERO_ONLY)
		if target ~= structure.Target then
			structure.Streak = 0
		end
		structure.Target = target
	end
	if target and Combat:CanAttack(structure) then
		local damage = structure.BaseDamage + Config.TowerDamagePerMinute * elapsed() / 60
		if target.Kind == "Minion" then
			damage = target.MaxHP * (Config.TowerMinionShare[target.Type] or 0.3)
			Combat:Attack(structure, target, function(victim)
				Combat:Damage(structure, victim, damage, { Type = "True" })
			end)
		else
			-- Jeder weitere Treffer auf denselben Helden tut mehr weh
			structure.Streak = math.min((structure.Streak or 0) + 1, 1 + Config.TowerRampMax / Config.TowerRampPerShot)
			damage *= 1 + (structure.Streak - 1) * Config.TowerRampPerShot
			Combat:Attack(structure, target, nil, damage)
		end
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
	if Combat.IsRooted(unit) then
		return
	end
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
	newPosition = Vector3.new(math.clamp(newPosition.X, -MAP.Half, MAP.Half), 0, math.clamp(newPosition.Z, -MAP.Half, MAP.Half))
	local facing = if offset.Magnitude > 0.1 then offset.Unit else unit.Root.CFrame.LookVector
	local height = Vector3.new(0, unit.Height or 1.5, 0)
	unit.Root.CFrame = CFrame.lookAt(newPosition + height, newPosition + height + Vector3.new(facing.X, 0, facing.Z))
end
LaneService.MoveUnit = moveUnit

local function face(unit, target)
	local position = Combat.Position(unit)
	local direction = Combat.Position(target) - position
	if direction.Magnitude > 0.1 then
		local height = Vector3.new(0, unit.Height or 1.5, 0)
		unit.Root.CFrame = CFrame.lookAt(position + height, position + height + direction.Unit)
	end
end
LaneService.Face = face

local function minionTick(self, unit, dt: number)
	if not Combat.Alive(unit) or Combat.IsStunned(unit) then
		return
	end
	local position = Combat.Position(unit)
	-- Baron-Segen: Minions neben einem gesegneten Helden sind staerker
	local empowered = false
	for _, hero in self.Services.HeroService.Heroes do
		if hero.Team == unit.Team and hero.Buffs and hero.Buffs.Baron and Combat.Alive(hero) and Combat.Distance(hero, unit) <= 24 then
			empowered = true
			break
		end
	end
	unit.Empowered = empowered
	unit.DamageScale = (if self.Overtime then 1.6 else 1) * (if empowered then 1.5 else 1)
	local target = unit.Target
	if unit.Charge then
		-- Herold: nur Gebaeude
		target = Combat:NearestEnemy(unit.Team, position, 30, Combat.STRUCTURES)
	elseif not (target and Combat:Targetable(target, unit.Team) and Combat.Distance(unit, target) <= unit.Aggro + 8) then
		target = Combat:NearestEnemy(unit.Team, position, unit.Aggro, NON_HERO) or Combat:NearestEnemy(unit.Team, position, unit.Aggro, MINION_TARGETS)
		unit.Target = target
	end
	if target and target.Kind == "Hero" and (Combat.Now() - (unit.CallAt or 0)) > 2 then
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
				if unit.Charge and target.Kind == "Tower" and not unit.Charged then
					-- Ramm-Angriff: grosser Schaden an einem Turm
					unit.Charged = true
					self.Services.Net.SendFx("Boom", { At = Combat.Position(target), Color = Color3.fromRGB(170, 90, 255), Size = 14 })
					Combat:Damage(unit, target, 1800, { Type = "True" })
					unit.NextAttack = Combat.Now() + 1.5
				else
					Combat:Attack(unit, target)
				end
			end
		else
			moveUnit(unit, Combat.Position(target), dt, separation(unit, self.Minions))
		end
		return
	end
	-- Der Lane folgen
	local goal = unit.Path[unit.PathIndex]
	if not goal then
		local nexus = self.Nexus[enemyOf(unit.Team)]
		goal = nexus and nexus.Home or position
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
		for _, tower in table.clone(self.Towers) do
			structureTick(self, tower)
			if not tower.Dead and tower.Tier == 1 then
				checkPlates(self, tower, tower.LastAttacker)
			end
		end
		for _, minion in table.clone(self.Minions) do
			minionTick(self, minion, step)
		end
	end)
end

return LaneService
