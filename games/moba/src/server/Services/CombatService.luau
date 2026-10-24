-- Kern des Kampfsystems: Einheiten-Register, Schaden (physisch, magisch, echt), Heilung, Schilde,
-- Zustaende (Verlangsamung, Betaeubung, Festhalten, Unverwundbarkeit, Unsichtbarkeit) und Angriffe.
-- Helden, Minions, Tuerme, Inhibitoren, Nexus, Monster und Wards sind alle "Units" mit derselben Grundform.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = {
	Services = nil :: any,
	Units = {} :: { any },
	ByModel = {} :: { [Model]: any },
	DeathHandlers = {} :: { [string]: (unit: any, killer: any?) -> () },
	DeathListeners = {} :: { (unit: any, killer: any?) -> () },
	NextId = 0,
}

local STRUCTURES = { Tower = true, Inhibitor = true, Nexus = true }
CombatService.STRUCTURES = STRUCTURES

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
	unit.Armor = unit.Armor or 0
	unit.MR = unit.MR or 0
	unit.SeenBy = unit.SeenBy or { [1] = unit.Team == 1, [2] = unit.Team == 2 }
	unit.RevealUntil = unit.RevealUntil or {}
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
	model:SetAttribute("Seen1", unit.SeenBy[1] == true)
	model:SetAttribute("Seen2", unit.SeenBy[2] == true)
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

function CombatService.Now(): number
	return workspace:GetServerTimeNow()
end
local now = CombatService.Now

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

function CombatService.IsStructure(unit): boolean
	return STRUCTURES[unit.Kind] == true
end

local function active(status, key: string): boolean
	return (status[key] or 0) > now()
end
CombatService.Active = active

-- Sieht "team" diese Einheit? (Gebaeude und Monster sind immer sichtbar)
function CombatService.Visible(unit, team: number): boolean
	if unit.Team == team or team == 0 then
		return true
	end
	if unit.Kind == "Hero" or unit.Kind == "Minion" or unit.Kind == "Ward" then
		return unit.SeenBy[team] == true
	end
	return true
end

-- Kann angegriffen werden? (byTeam: nur Ziele, die dieses Team sieht)
function CombatService:Targetable(unit, byTeam: number?): boolean
	if not CombatService.Alive(unit) or unit.Untargetable or unit.Protected then
		return false
	end
	local status = unit.Status
	if active(status, "UntargetableUntil") or active(status, "StasisUntil") then
		return false
	end
	if byTeam and not CombatService.Visible(unit, byTeam) then
		return false
	end
	return true
end

-- Alle Gegner von "team" im Radius (Flaechenschaden trifft auch Unsichtbare)
function CombatService:EnemiesNear(team: number, position: Vector3, radius: number, kinds: { [string]: boolean }?)
	local result = {}
	for _, unit in self.Units do
		if unit.Team ~= team and (not kinds or kinds[unit.Kind]) and unit.Kind ~= "Ward" and self:Targetable(unit) then
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

-- Naechster sichtbarer Gegner (fuer Angriffe und gezielte Faehigkeiten)
function CombatService:NearestEnemy(team: number, position: Vector3, radius: number, kinds: { [string]: boolean }?)
	local best, bestDistance = nil, math.huge
	for _, unit in self.Units do
		if unit.Team ~= team and (not kinds or kinds[unit.Kind]) and self:Targetable(unit, team) then
			local distance = (CombatService.Position(unit) - position).Magnitude - unit.Radius
			if distance <= radius and distance < bestDistance then
				best, bestDistance = unit, distance
			end
		end
	end
	return best, bestDistance
end

---------------------------------------------------------------- Zustaende

local function ccImmune(unit): boolean
	local status = unit.Status
	return active(status, "UnstoppableUntil") or active(status, "StasisUntil") or STRUCTURES[unit.Kind] == true
end

function CombatService.IsStunned(unit): boolean
	local status = unit.Status
	return active(status, "StunUntil") or active(status, "StasisUntil") or active(status, "ChannelUntil")
end

function CombatService.IsRooted(unit): boolean
	return CombatService.IsStunned(unit) or active(unit.Status, "RootUntil")
end

-- Darf keine Faehigkeiten wirken (Betaeubung, Stasis)
function CombatService.CannotCast(unit): boolean
	local status = unit.Status
	return active(status, "StunUntil") or active(status, "StasisUntil")
end

function CombatService.SlowFactor(unit): number
	local status = unit.Status
	if active(status, "SlowImmuneUntil") then
		return 1
	end
	if active(status, "SlowUntil") then
		return 1 - math.clamp(status.Slow or 0, 0, 0.99)
	end
	return 1
end

local function changed(unit)
	if unit.OnStatus then
		unit.OnStatus(unit)
	end
end

function CombatService:Slow(unit, amount: number, seconds: number)
	if STRUCTURES[unit.Kind] or active(unit.Status, "StasisUntil") then
		return
	end
	local status = unit.Status
	local t = now()
	if (status.SlowUntil or 0) < t or amount >= (status.Slow or 0) then
		status.Slow = amount
		status.SlowUntil = math.max(status.SlowUntil or 0, t + seconds)
	end
	changed(unit)
end

function CombatService:Stun(unit, seconds: number)
	if ccImmune(unit) then
		return
	end
	-- Epische Monster sind halb so lang betaeubt
	if unit.Epic then
		seconds *= 0.5
	end
	unit.Status.StunUntil = math.max(unit.Status.StunUntil or 0, now() + seconds)
	if unit.Model then
		self.Services.Net.SendFx("Stun", { Model = unit.Model, Time = seconds })
	end
	if unit.Kind == "Hero" then
		self.Services.HeroService:Interrupt(unit)
	end
	changed(unit)
end

function CombatService:Root(unit, seconds: number)
	if ccImmune(unit) then
		return
	end
	unit.Status.RootUntil = math.max(unit.Status.RootUntil or 0, now() + seconds)
	if unit.Model then
		self.Services.Net.SendFx("Root", { Model = unit.Model, Time = seconds })
	end
	changed(unit)
end

function CombatService:Shield(unit, amount: number, seconds: number, source)
	if source and source.HealPower then
		amount *= 1 + source.HealPower
	end
	if unit.HealTaken then
		amount *= 1 + unit.HealTaken
	end
	local status = unit.Status
	local t = now()
	if (status.ShieldUntil or 0) < t then
		status.Shield = 0
	end
	status.Shield = (status.Shield or 0) + amount
	status.ShieldUntil = math.max(status.ShieldUntil or 0, t + seconds)
	self:Sync(unit)
	if unit.Model then
		self.Services.Net.SendFx("Shield", { Model = unit.Model, Time = seconds })
	end
	task.delay(seconds + 0.05, function()
		if (status.ShieldUntil or 0) <= now() then
			status.Shield = 0
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
	local shield = if active(unit.Status, "ShieldUntil") then unit.Status.Shield or 0 else 0
	model:SetAttribute("HP", math.max(0, math.ceil(unit.HP)))
	model:SetAttribute("MaxHP", math.ceil(unit.MaxHP))
	model:SetAttribute("Shield", math.ceil(shield))
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
	if source and source.HealPower and source ~= unit then
		amount *= 1 + source.HealPower
	end
	if unit.HealTaken then
		amount *= 1 + unit.HealTaken
	end
	if active(unit.Status, "GrievousUntil") then
		amount *= 0.6
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

-- Wirksamer Widerstand nach Durchdringung und Abbau
local function resistance(source, target, kind: string): number
	if kind == "True" then
		return 0
	end
	local value = if kind == "Magic" then target.MR or 0 else target.Armor or 0
	if kind == "Physical" and target.Shred and target.Shred > 0 then
		value *= 1 - target.Shred
	end
	if source and value > 0 then
		if kind == "Magic" then
			value *= 1 - (source.MagicPenPct or 0)
			value -= source.MagicPen or 0
		else
			value -= source.Lethality or 0
		end
		value = math.max(0, value)
	end
	return value
end

local function mitigate(amount: number, resist: number): number
	if resist >= 0 then
		return amount * 100 / (100 + resist)
	end
	return amount * (2 - 100 / (100 - resist))
end

-- Zentrale Schadensfunktion.
-- opts: { Type = "Physical"|"Magic"|"True", Ability = true, OnHit = true (normaler Angriff), Crit = true, NoReveal = true }
function CombatService:Damage(source, target, amount: number, opts: any)
	if not self:Targetable(target) or amount <= 0 then
		return 0
	end
	opts = opts or {}
	local kind = opts.Type or (if opts.True then "True" else "Physical")
	opts.Type = kind
	local t = now()
	-- Wards halten genau 3 Angriffe aus
	if target.Kind == "Ward" then
		if not opts.OnHit then
			return 0
		end
		amount = 1
		kind = "True"
	end
	if source and source.ModifyDamage then
		amount = source.ModifyDamage(source, target, amount, opts)
	end
	local dealt = if target.Kind == "Ward" then amount else mitigate(amount, resistance(source, target, kind))
	if source and source.DamageScale then
		dealt *= source.DamageScale
	end
	if source and active(source.Status, "ExhaustUntil") then
		dealt *= 0.6
	end
	local status = target.Status
	if active(status, "ReductionUntil") then
		dealt *= 1 - (status.Reduction or 0)
	end
	if opts.OnHit and target.AttackReduction then
		dealt *= 1 - target.AttackReduction
	end
	if target.ModifyIncoming then
		dealt = target.ModifyIncoming(target, source, dealt, opts)
	end
	-- Schild faengt zuerst ab
	local shield = if active(status, "ShieldUntil") then status.Shield or 0 else 0
	if shield > 0 then
		local absorbed = math.min(shield, dealt)
		status.Shield = shield - absorbed
		dealt -= absorbed
	end
	if source and source.Kind == "Hero" then
		target.Damagers[source] = t
		if target.Kind == "Hero" then
			self.Services.LaneService:OnHeroAttackedHero(source, target)
		end
		if source.Lifesteal and source.Lifesteal > 0 and opts.OnHit then
			self:Heal(source, dealt * source.Lifesteal)
		end
	end
	-- Wer aus dem Nebel angreift, wird kurz aufgedeckt
	if source and source.RevealUntil and target.Team ~= 0 and not opts.NoReveal then
		source.RevealUntil[target.Team] = t + 1.5
	end
	if target.OnDamaged then
		target.OnDamaged(target, source, dealt, opts)
	end
	target.HP -= dealt
	target.LastDamagedAt = t
	target.LastAttacker = source

	local hurtHero = source and source.Player
	if hurtHero then
		self.Services.Net.Damage:FireClient(source.Player, CombatService.Position(target), dealt, if opts.Crit then "Crit" elseif kind == "True" then "True" elseif kind == "Magic" then "Magic" else "Dealt")
	end
	if target.Player then
		self.Services.Net.Damage:FireClient(target.Player, CombatService.Position(target), dealt, "Taken")
	end
	if source and source.AfterDamage then
		source.AfterDamage(source, target, dealt, opts)
	end

	if target.HP <= 0 and not target.Dead then
		if target.OnLethal and target.OnLethal(target, source) then
			self:Sync(target)
			return dealt
		end
		target.HP = 0
		target.Dead = true
		self:Sync(target)
		for _, listener in self.DeathListeners do
			task.spawn(listener, target, source)
		end
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
	local t = now()
	local result = {}
	for hero, time in unit.Damagers do
		if hero ~= except and t - time <= Config.AssistWindow and hero.Team ~= unit.Team then
			table.insert(result, hero)
		end
	end
	return result
end

---------------------------------------------------------------- Angriffe

-- Ein normaler Angriff: Nahkampf trifft sofort, Fernkampf nach der Flugzeit des Geschosses.
-- onImpact(target) ersetzt den Standard-Schaden (Helden rechnen Krit und Treffer-Effekte selbst).
function CombatService:Attack(unit, target, onImpact: ((any) -> ())?, damage: number?)
	local t = now()
	unit.NextAttack = t + 1 / math.max(0.2, unit.AttackSpeed)
	local from = CombatService.Position(unit)
	local to = CombatService.Position(target)
	if unit.Kind == "Hero" and unit.Model then
		self.Services.Net.SendFx("Swing", { Model = unit.Model })
	end
	local function impact()
		if onImpact then
			onImpact(target)
		else
			self:Damage(unit, target, damage or unit.Damage, { OnHit = true, Type = "Physical" })
		end
	end
	if unit.Ranged then
		local travel = math.clamp((to - from).Magnitude / 90, 0.05, 0.4)
		self.Services.Net.SendFx(unit.ShotFx or "Shot", {
			From = (unit.Root and unit.Root.Position or from) + Vector3.new(0, unit.ShotHeight or 1.5, 0),
			Target = target.Model,
			To = to,
			Color = unit.FxColor,
			Time = travel,
			Team = unit.Team,
		})
		task.delay(travel, function()
			if CombatService.Alive(target) then
				impact()
			end
		end)
	else
		self.Services.Net.SendFx("Slash", { At = to, Color = unit.FxColor, Big = unit.Kind == "Monster" or unit.Kind == "Hero", Team = unit.Team })
		impact()
	end
end

function CombatService:InRange(unit, target, extra: number?): boolean
	return CombatService.Distance(unit, target) <= unit.Range + target.Radius + unit.Radius + (extra or 0)
end

function CombatService:CanAttack(unit): boolean
	return CombatService.Alive(unit) and not CombatService.IsStunned(unit) and now() >= unit.NextAttack
end

return CombatService
