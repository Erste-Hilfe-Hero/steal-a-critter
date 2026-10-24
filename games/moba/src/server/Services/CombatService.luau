-- Kern des Kampfsystems: Einheiten-Register, Schaden, Heilung, Zustaende (Verlangsamung, Betaeubung, Schild)
-- und Angriffe. Helden, Minions, Tuerme, Kerne und Monster sind alle "Units" mit derselben Grundform.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = {
	Services = nil :: any,
	Units = {} :: { any },
	ByModel = {} :: { [Model]: any },
	DeathHandlers = {} :: { [string]: (unit: any, killer: any?) -> () },
	NextId = 0,
}

function CombatService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Register

function CombatService:Register(unit)
	self.NextId += 1
	unit.Id = self.NextId
	unit.Status = unit.Status or {}
	unit.Damagers = unit.Damagers or {}
	unit.NextAttack = unit.NextAttack or 0
	unit.Radius = unit.Radius or 1.5
	unit.Dead = false
	table.insert(self.Units, unit)
	if unit.Model then
		self:BindModel(unit, unit.Model)
	end
	return unit
end

-- Helden bekommen nach jedem Respawn ein neues Model
function CombatService:BindModel(unit, model: Model)
	if unit.Model and self.ByModel[unit.Model] == unit then
		self.ByModel[unit.Model] = nil
	end
	unit.Model = model
	unit.Root = (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart
	self.ByModel[model] = unit
	model:SetAttribute("Kind", unit.Kind)
	model:SetAttribute("Team", unit.Team)
	model:SetAttribute("UnitName", unit.Name)
	model:SetAttribute("Radius", unit.Radius)
	CollectionService:AddTag(model, "Unit")
	self:Sync(unit)
end

function CombatService:Unregister(unit)
	local index = table.find(self.Units, unit)
	if index then
		table.remove(self.Units, index)
	end
	if unit.Model and self.ByModel[unit.Model] == unit then
		self.ByModel[unit.Model] = nil
	end
end

function CombatService:Clear()
	self.Units = {}
	self.ByModel = {}
end

function CombatService:GetUnit(model: Instance?)
	return model and self.ByModel[model :: Model]
end

---------------------------------------------------------------- Abfragen

function CombatService.Position(unit): Vector3
	local root = unit.Root
	if root and root.Parent then
		local p = root.Position
		return Vector3.new(p.X, 0, p.Z)
	end
	return unit.Home or Vector3.zero
end

function CombatService.Alive(unit): boolean
	return unit ~= nil and not unit.Dead and unit.HP > 0 and unit.Root ~= nil and unit.Root.Parent ~= nil
end

function CombatService.Distance(a, b): number
	return (CombatService.Position(a) - CombatService.Position(b)).Magnitude
end

function CombatService.IsEnemy(a, b): boolean
	return a.Team ~= b.Team
end

-- Unverwundbar: Tuerme der zweiten Reihe und Kerne, solange davor noch etwas steht
function CombatService:Targetable(unit): boolean
	if not CombatService.Alive(unit) or unit.Untargetable then
		return false
	end
	return not unit.Protected
end

-- Alle Gegner von "team" im Radius um "position" (inklusive Koerperradius)
function CombatService:EnemiesNear(team: number, position: Vector3, radius: number, kinds: { [string]: boolean }?)
	local result = {}
	for _, unit in self.Units do
		if unit.Team ~= team and (not kinds or kinds[unit.Kind]) and self:Targetable(unit) then
			if (CombatService.Position(unit) - position).Magnitude <= radius + unit.Radius then
				table.insert(result, unit)
			end
		end
	end
	return result
end

function CombatService:AlliesNear(team: number, position: Vector3, radius: number, kinds: { [string]: boolean }?)
	local result = {}
	for _, unit in self.Units do
		if unit.Team == team and (not kinds or kinds[unit.Kind]) and CombatService.Alive(unit) then
			if (CombatService.Position(unit) - position).Magnitude <= radius + unit.Radius then
				table.insert(result, unit)
			end
		end
	end
	return result
end

function CombatService:NearestEnemy(team: number, position: Vector3, radius: number, kinds: { [string]: boolean }?)
	local best, bestDistance = nil, math.huge
	for _, unit in self.Units do
		if unit.Team ~= team and (not kinds or kinds[unit.Kind]) and self:Targetable(unit) then
			local distance = (CombatService.Position(unit) - position).Magnitude - unit.Radius
			if distance <= radius and distance < bestDistance then
				best, bestDistance = unit, distance
			end
		end
	end
	return best, bestDistance
end

---------------------------------------------------------------- Zustaende

function CombatService.Now(): number
	return workspace:GetServerTimeNow()
end

function CombatService.IsStunned(unit): boolean
	return (unit.Status.StunUntil or 0) > CombatService.Now()
end

function CombatService.SlowFactor(unit): number
	local status = unit.Status
	if (status.SlowUntil or 0) > CombatService.Now() then
		return 1 - (status.Slow or 0)
	end
	return 1
end

function CombatService:Slow(unit, amount: number, seconds: number)
	if unit.Kind == "Tower" or unit.Kind == "Core" then
		return
	end
	local status = unit.Status
	local now = CombatService.Now()
	if (status.SlowUntil or 0) < now or amount >= (status.Slow or 0) then
		status.Slow = amount
		status.SlowUntil = math.max(status.SlowUntil or 0, now + seconds)
	end
	if unit.OnStatus then
		unit.OnStatus(unit)
	end
end

function CombatService:Stun(unit, seconds: number)
	if unit.Kind == "Tower" or unit.Kind == "Core" then
		return
	end
	-- Bosse sind halb so lang betaeubt
	if unit.Boss then
		seconds *= 0.5
	end
	unit.Status.StunUntil = math.max(unit.Status.StunUntil or 0, CombatService.Now() + seconds)
	if unit.Model then
		self.Services.Net.SendFx("Stun", { Model = unit.Model, Time = seconds })
	end
	if unit.OnStatus then
		unit.OnStatus(unit)
	end
end

function CombatService:Shield(unit, amount: number, seconds: number)
	unit.Status.Shield = (unit.Status.Shield or 0) + amount
	unit.Status.ShieldUntil = CombatService.Now() + seconds
	self:Sync(unit)
	if unit.Model then
		self.Services.Net.SendFx("Shield", { Model = unit.Model, Time = seconds })
	end
	task.delay(seconds + 0.05, function()
		if (unit.Status.ShieldUntil or 0) <= CombatService.Now() then
			unit.Status.Shield = 0
			self:Sync(unit)
		end
	end)
end

---------------------------------------------------------------- Lebenspunkte

function CombatService:Sync(unit)
	local model = unit.Model
	if not model then
		return
	end
	model:SetAttribute("HP", math.max(0, math.ceil(unit.HP)))
	model:SetAttribute("MaxHP", math.ceil(unit.MaxHP))
	model:SetAttribute("Shield", math.ceil(unit.Status.Shield or 0))
	model:SetAttribute("Protected", unit.Protected == true)
	if unit.Humanoid and unit.Humanoid.Parent then
		unit.Humanoid.MaxHealth = math.max(1, unit.MaxHP)
		unit.Humanoid.Health = math.max(if unit.Dead then 0 else 1, unit.HP)
	end
end

function CombatService:Heal(unit, amount: number, source)
	if not CombatService.Alive(unit) or amount <= 0 then
		return 0
	end
	local before = unit.HP
	unit.HP = math.min(unit.MaxHP, unit.HP + amount)
	self:Sync(unit)
	local healed = unit.HP - before
	if healed >= 1 and unit.Player and source ~= nil then
		self.Services.Net.Damage:FireClient(unit.Player, CombatService.Position(unit), healed, "Heal")
	end
	return healed
end

-- Zentrale Schadensfunktion. opts: { Ability = true } fuer Faehigkeiten, { True = true } ignoriert Ruestung
function CombatService:Damage(source, target, amount: number, opts: any?)
	if not self:Targetable(target) or amount <= 0 then
		return 0
	end
	opts = opts or {}
	local now = CombatService.Now()
	local armor = if opts.True then 0 else math.max(0, target.Armor or 0)
	local dealt = amount * 100 / (100 + armor)
	if source and source.DamageScale then
		dealt *= source.DamageScale
	end
	local status = target.Status
	if (status.ReductionUntil or 0) > now then
		dealt *= 1 - (status.Reduction or 0)
	end
	-- Schild faengt zuerst ab
	local shield = if (status.ShieldUntil or 0) > now then status.Shield or 0 else 0
	if shield > 0 then
		local absorbed = math.min(shield, dealt)
		status.Shield = shield - absorbed
		dealt -= absorbed
	end
	if source and source.Kind == "Hero" then
		target.Damagers[source] = now
		if target.Kind == "Hero" then
			self.Services.LaneService:OnHeroAttackedHero(source, target)
		end
		if source.Lifesteal and source.Lifesteal > 0 and not opts.Ability then
			self:Heal(source, dealt * source.Lifesteal)
		end
	end
	if target.OnDamaged then
		target.OnDamaged(target, source, dealt)
	end
	target.HP -= dealt
	target.LastDamagedAt = now
	target.LastAttacker = source

	if source and source.Player then
		self.Services.Net.Damage:FireClient(source.Player, CombatService.Position(target), dealt, if opts.Ability then "Ability" else "Dealt")
	end
	if target.Player then
		self.Services.Net.Damage:FireClient(target.Player, CombatService.Position(target), dealt, "Taken")
	end

	if target.HP <= 0 then
		target.HP = 0
		target.Dead = true
		self:Sync(target)
		local handler = self.DeathHandlers[target.Kind]
		if handler then
			task.spawn(handler, target, source)
		end
	else
		self:Sync(target)
	end
	return dealt
end

-- Helden, die in den letzten Sekunden geholfen haben (fuer Assists)
function CombatService:RecentDamagers(unit, except)
	local now = CombatService.Now()
	local result = {}
	for hero, time in unit.Damagers do
		if hero ~= except and now - time <= Config.AssistWindow and hero.Team ~= unit.Team then
			table.insert(result, hero)
		end
	end
	return result
end

---------------------------------------------------------------- Angriffe

-- Ein normaler Angriff: Nahkampf trifft sofort, Fernkampf nach der Flugzeit des Geschosses
function CombatService:Attack(unit, target, damage: number?)
	local now = CombatService.Now()
	unit.NextAttack = now + 1 / math.max(0.2, unit.AttackSpeed)
	local amount = damage or unit.Damage
	local from = CombatService.Position(unit)
	local to = CombatService.Position(target)
	if unit.Kind == "Hero" and unit.Model then
		self.Services.Net.SendFx("Swing", { Model = unit.Model })
	end
	if unit.Ranged then
		local travel = math.clamp((to - from).Magnitude / 90, 0.05, 0.4)
		self.Services.Net.SendFx(unit.ShotFx or "Shot", {
			From = (unit.Root and unit.Root.Position or from) + Vector3.new(0, unit.ShotHeight or 1.5, 0),
			Target = target.Model,
			To = to,
			Color = unit.FxColor,
			Time = travel,
		})
		task.delay(travel, function()
			if CombatService.Alive(target) then
				self:Damage(unit, target, amount)
			end
		end)
	else
		self.Services.Net.SendFx("Slash", { At = to, Color = unit.FxColor, Big = unit.Kind == "Monster" or unit.Kind == "Hero" })
		self:Damage(unit, target, amount)
	end
end

function CombatService:InRange(unit, target, extra: number?): boolean
	return CombatService.Distance(unit, target) <= unit.Range + target.Radius + unit.Radius + (extra or 0)
end

function CombatService:CanAttack(unit): boolean
	return CombatService.Alive(unit) and not CombatService.IsStunned(unit) and CombatService.Now() >= unit.NextAttack
end

return CombatService
