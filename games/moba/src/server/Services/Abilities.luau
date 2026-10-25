-- Alle Faehigkeiten der Helden (Q/W/E/R nach Typ), Treffer-Effekte der normalen Angriffe,
-- Passive und Item-Effekte. Wird nur von HeroService benutzt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Abilities = {}

local Services
local Heroes
local Combat
local Net

local MAP = Config.Map
local ENEMY = { Hero = true, Minion = true, Monster = true }
local HERO_ONLY = { Hero = true }
local missileId = 0

function Abilities.Init(services, heroService)
	Services = services
	Heroes = heroService
	Combat = services.CombatService
	Net = services.Net
end

local function now()
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function at(value, rank: number): number
	return Config.AtRank(value, rank)
end

local function passive(hero): string
	return hero.Def.Passive.Id
end

local function colorOf(hero): Color3
	local skin = Config.SkinsById[hero.Skin]
	if skin and skin.Color then
		return skin.Color
	end
	return hero.Def.Color
end

local function notify(hero, text: string)
	if hero.Player then
		Net.SendNotify(hero.Player, text, Color3.fromRGB(255, 120, 120))
	end
end

local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local length = ab:Dot(ab)
	if length < 0.001 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / length, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

---------------------------------------------------------------- Bewegung und Ziele

-- Letzter freier Punkt auf dem Weg (nicht in Waenden landen, nicht aus der Karte)
function Abilities.Walkable(from: Vector3, to: Vector3): Vector3
	local world = Services.WorldService
	local limit = MAP.Half - 3
	to = Vector3.new(math.clamp(to.X, -limit, limit), 0, math.clamp(to.Z, -limit, limit))
	if not world.Blocked(to) then
		return to
	end
	local offset = to - from
	local length = offset.Magnitude
	if length < 0.1 then
		return from
	end
	local step = 1.5
	local distance = length
	while distance > 0 do
		distance -= step
		local point = from + offset.Unit * math.max(0, distance)
		if not world.Blocked(point) then
			return point
		end
	end
	return from
end

-- Einheit verschieben (Haken, Zurueckstossen, Ranziehen). Gebaeude und epische Monster bleiben stehen.
local function displace(unit, position: Vector3)
	if Combat.IsStructure(unit) or unit.Epic or unit.Kind == "Ward" or not Combat.Alive(unit) then
		return
	end
	position = Abilities.Walkable(Combat.Position(unit), position)
	if unit.Kind == "Hero" then
		Heroes:Teleport(unit, position)
		Heroes:Interrupt(unit)
	else
		local height = Vector3.new(0, unit.Height or 1.5, 0)
		unit.Root.CFrame = CFrame.new(position + height) * unit.Root.CFrame.Rotation
	end
end
Abilities.Displace = displace

local function isolated(target): boolean
	for _, other in Combat.Units do
		if other ~= target and other.Team == target.Team and other.Kind ~= "Ward" and not Combat.IsStructure(other) and Combat.Alive(other) then
			if Combat.Distance(other, target) <= 12 then
				return false
			end
		end
	end
	return true
end

-- Gegner fuer gezielte Faehigkeiten: am naechsten zum Zielpunkt, ohne Zielpunkt Helden zuerst
local function pickTarget(hero, aim: Vector3?, range: number, kinds)
	local best, bestScore = nil, math.huge
	for _, unit in Combat.Units do
		if unit.Team ~= hero.Team and kinds[unit.Kind] and Combat:Targetable(unit, hero.Team) then
			local distance = Combat.Distance(hero, unit) - unit.Radius
			if distance <= range then
				local score = if aim then (Combat.Position(unit) - flat(aim)).Magnitude else distance + (if unit.Kind == "Hero" then -1000 else 0)
				if score < bestScore then
					best, bestScore = unit, score
				end
			end
		end
	end
	return best
end
Abilities.PickTarget = pickTarget

-- Zielpunkt ohne Maus (Handy, kurzes Tippen): naechster Held, sonst naechste Einheit, sonst geradeaus
local function autoAim(hero, reach: number, heroOnly: boolean?): Vector3
	local position = Combat.Position(hero)
	local target = Combat:NearestEnemy(hero.Team, position, reach + 6, HERO_ONLY)
	if not target and not heroOnly then
		target = Combat:NearestEnemy(hero.Team, position, reach + 6, ENEMY)
	end
	if target then
		return Combat.Position(target)
	end
	local look = if hero.Root then hero.Root.CFrame.LookVector else Vector3.xAxis
	return position + flat(look).Unit * reach
end

local function aimInfo(hero, aim: Vector3?, reach: number, heroOnly: boolean?)
	local position = Combat.Position(hero)
	local point = flat(aim or autoAim(hero, reach, heroOnly))
	local direction = point - position
	if direction.Magnitude < 0.1 then
		local look = if hero.Root then hero.Root.CFrame.LookVector else Vector3.xAxis
		direction = flat(look)
	end
	return position, point, direction.Unit
end

local function clampPoint(position: Vector3, point: Vector3, range: number): Vector3
	local offset = point - position
	if offset.Magnitude > range then
		return position + offset.Unit * range
	end
	return point
end

local function face(hero, direction: Vector3)
	local root = hero.Root
	if root and root.Parent and direction.Magnitude > 0.1 and not hero.Player then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat(direction))
	end
end

---------------------------------------------------------------- Schaden

local function amountFor(hero, ability, rank: number): number
	return at(ability.Damage or 0, rank)
		+ (ability.AD or 0) * hero.AD
		+ (ability.BonusAD or 0) * hero.BonusAD
		+ (ability.AP or 0) * hero.AP
		+ (ability.Armor or 0) * hero.Armor
		+ (ability.MaxHPRatio or 0) * hero.MaxHP
end
Abilities.AmountFor = amountFor

-- Treffer einer Faehigkeit mit allen Effekten (Verlangsamen, Betaeuben, Festhalten, Stossen)
local function hit(hero, target, ability, amount: number, extra)
	extra = extra or {}
	local dealt = 0
	if amount > 0 then
		dealt = Combat:Damage(hero, target, amount, { Type = ability.DamageType or "Magic", Ability = true, MarkHit = extra.MarkHit })
	end
	if not Combat.Alive(target) then
		return dealt
	end
	if ability.Slow and not extra.NoSlow then
		Combat:Slow(target, ability.Slow, ability.SlowTime or 1.5)
	end
	if ability.Stun and not extra.NoStun then
		Combat:Stun(target, extra.Stun or ability.Stun)
		if target.Model then
			Net.SendFx("Airborne", { Model = target.Model, Time = extra.Stun or ability.Stun })
		end
	end
	if ability.Root and not extra.NoRoot then
		Combat:Root(target, ability.Root)
	end
	if ability.Knockback and extra.Direction then
		displace(target, Combat.Position(target) + extra.Direction * ability.Knockback)
	end
	return dealt
end

function Abilities.DamageOverTime(source, target, total: number, seconds: number, kind: string)
	local ticks = math.max(1, math.floor(seconds / 0.5))
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.5)
			if not Combat.Alive(target) or (source.Removed) then
				return
			end
			Combat:Damage(source, target, total / ticks, { Type = kind, NoReveal = true, Dot = true })
		end
	end)
end

local function healOverTime(hero, total: number, seconds: number)
	local ticks = math.max(1, math.floor(seconds / 0.5))
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.5)
			if not Combat.Alive(hero) then
				return
			end
			Combat:Heal(hero, total / ticks, hero)
		end
	end)
end

---------------------------------------------------------------- Geschosse

-- Fliegendes Geschoss entlang einer Linie. onHit(target, point) gibt true zurueck, wenn es anhaelt.
local function skillshot(hero, from: Vector3, direction: Vector3, length: number, width: number, speed: number?, kinds, onHit: (any, Vector3) -> boolean?, color: Color3, look: string?)
	missileId += 1
	local id = missileId
	Net.SendFx("Missile", { Id = id, From = from, Dir = direction, Length = length, Speed = speed or 0, Width = width, Color = color, Look = look })
	task.spawn(function()
		local traveled = 0
		local hitList = {}
		local stepTime = 0.05
		while traveled < length do
			local advance = if speed and speed > 0 then speed * stepTime else length
			local a = from + direction * traveled
			local b = from + direction * math.min(length, traveled + advance)
			local candidates = {}
			for _, unit in Combat:EnemiesNear(hero.Team, (a + b) / 2, advance / 2 + width + 4, kinds) do
				if not hitList[unit] and distanceToSegment(Combat.Position(unit), a, b) <= width / 2 + unit.Radius then
					table.insert(candidates, unit)
				end
			end
			table.sort(candidates, function(x, y)
				return (Combat.Position(x) - from):Dot(direction) < (Combat.Position(y) - from):Dot(direction)
			end)
			for _, unit in candidates do
				hitList[unit] = true
				if onHit(unit, Combat.Position(unit)) then
					Net.SendFx("MissileEnd", { Id = id, At = Combat.Position(unit), Color = color })
					return
				end
			end
			traveled += advance
			if speed and speed > 0 then
				task.wait(stepTime)
			end
			if hero.Removed then
				return
			end
		end
	end)
end

---------------------------------------------------------------- Faehigkeiten nach Typ

local Cast = {}

function Cast.Target(hero, ability, rank, aim)
	local kinds = if ability.HeroOnly then HERO_ONLY else ENEMY
	local target = pickTarget(hero, aim, ability.Range, kinds)
	if not target then
		notify(hero, "No target in range!")
		return false
	end
	local position = Combat.Position(hero)
	local color = colorOf(hero)
	if ability.Leap then
		local away = position - Combat.Position(target)
		local landing = Combat.Position(target) + (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * 2.5
		Net.SendFx("Dash", { From = position, To = landing, Color = color })
		Heroes:Teleport(hero, landing)
	end
	local amount = amountFor(hero, ability, rank)
	if ability.IsolatedBonus and isolated(target) then
		amount *= 1 + ability.IsolatedBonus
	end
	if ability.PerBleed then
		local bleed = target.Bleed
		local stacks = if bleed and bleed.By == hero and bleed.Until > now() then bleed.Stacks else 0
		amount *= 1 + ability.PerBleed * stacks
	end
	if ability.Range > 12 and not ability.Leap then
		Net.SendFx("Bolt", { From = position, To = Combat.Position(target), Color = color })
	else
		Net.SendFx("BigSlash", { At = Combat.Position(target), Color = color })
	end
	face(hero, Combat.Position(target) - position)
	hit(hero, target, ability, amount)
	if ability.SelfSpeed then
		Heroes:AddTemp(hero, "SelfSpeed", ability.SelfSpeedTime or 2, { MSPct = ability.SelfSpeed })
	end
	if ability.ResetOnKill and target.Dead and target.Kind == "Hero" then
		return true, true
	end
	return true
end

function Cast.Empower(hero, ability, rank)
	local t = now()
	hero.Empower = { Ability = ability, Rank = rank, Until = t + (ability.Duration or 5), Left = ability.Attacks or 1 }
	hero.NextAttack = math.min(hero.NextAttack or 0, t)
	if ability.BonusArmor then
		Heroes:AddTemp(hero, "Empower", ability.Duration or 5, { Armor = at(ability.BonusArmor, rank) })
	end
	Net.SendFx("Buff", { Model = hero.Model, Time = ability.Duration or 5, Color = colorOf(hero) })
	return true
end

function Cast.Circle(hero, ability, rank)
	local color = colorOf(hero)
	local function run()
		if not Combat.Alive(hero) then
			return
		end
		local center = Combat.Position(hero)
		Net.SendFx("Ring", { At = center, Radius = ability.Radius, Color = color })
		local amount = amountFor(hero, ability, rank)
		local heroesHit = 0
		for _, target in Combat:EnemiesNear(hero.Team, center, ability.Radius, ENEMY) do
			local away = Combat.Position(target) - center
			hit(hero, target, ability, amount, { Direction = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis })
			if target.Kind == "Hero" then
				heroesHit += 1
			end
		end
		if ability.HealPerHero and heroesHit > 0 then
			Combat:Heal(hero, (hero.MaxHP - hero.HP) * ability.HealPerHero * heroesHit, hero)
		end
	end
	if ability.Delay then
		Net.SendFx("Marker", { At = Combat.Position(hero), Radius = ability.Radius, Time = ability.Delay, Color = color })
		task.delay(ability.Delay, run)
	else
		run()
	end
	return true
end

function Cast.Point(hero, ability, rank, aim)
	local position, point = aimInfo(hero, aim, ability.Range)
	point = clampPoint(position, point, ability.Range)
	local color = colorOf(hero)
	Net.SendFx("Marker", { At = point, Radius = ability.Radius, Time = ability.Delay or 0.5, Color = color })
	task.delay(ability.Delay or 0.5, function()
		if hero.Removed then
			return
		end
		Net.SendFx("Boom", { At = point, Color = color, Size = ability.Radius * 2 })
		local amount = amountFor(hero, ability, rank)
		local any = false
		for _, target in Combat:EnemiesNear(hero.Team, point, ability.Radius, ENEMY) do
			hit(hero, target, ability, amount)
			any = true
		end
		if any and ability.HealSelfOnHit and Combat.Alive(hero) then
			healOverTime(hero, at(ability.HealSelfOnHit, rank) + hero.AP * 0.3, 2.5)
		end
	end)
	return true
end

function Cast.Line(hero, ability, rank, aim)
	local position, _, direction = aimInfo(hero, aim, ability.Length, ability.HeroOnly)
	local color = colorOf(hero)
	local kinds = if ability.HeroOnly then HERO_ONLY else ENEMY
	face(hero, direction)
	local hits = 0
	local function onHit(target, point: Vector3): boolean?
		hits += 1
		local amount = amountFor(hero, ability, rank)
		if ability.Missing then
			amount += at(ability.Missing, rank) * (target.MaxHP - target.HP)
		end
		if ability.MinionFactor and target.Kind ~= "Hero" then
			amount *= ability.MinionFactor
		end
		if ability.Hook then
			Net.SendFx("Hook", { From = Combat.Position(hero), To = point, Color = color })
			hit(hero, target, ability, amount)
			displace(target, Combat.Position(hero) + direction * 3)
		else
			hit(hero, target, ability, amount, { MarkHit = ability.Mark ~= nil })
		end
		if ability.OnHit and Combat.Alive(target) then
			Abilities.OnHitEffects(hero, target)
		end
		if ability.Refund then
			local t = now()
			for _, key in Config.AbilityKeys do
				local ready = hero.Cooldowns[key] or 0
				if ready > t then
					Heroes:SetCooldown(hero, key, math.max(t, ready - ability.Refund), hero.Player and hero.Player:GetAttribute("CDMax_" .. key) or 0)
				end
			end
		end
		if ability.Mark and Combat.Alive(target) then
			target.ZephyrMark = { By = hero, Until = now() + ability.Mark, Amount = amount * 0.6 }
			if target.Model then
				Net.SendFx("Mark", { Model = target.Model, Time = ability.Mark, Color = color })
			end
		end
		if ability.HealSelf and Config.BrushAt(Combat.Position(hero)) then
			Combat:Heal(hero, at(ability.HealSelf, rank), hero)
		end
		if ability.Explode and hits == 1 then
			Net.SendFx("Boom", { At = point, Color = color, Size = ability.Explode * 2 })
			for _, other in Combat:EnemiesNear(hero.Team, point, ability.Explode, ENEMY) do
				if other ~= target then
					if ability.ExplodeStun then
						Combat:Stun(other, ability.ExplodeStun)
					else
						Combat:Damage(hero, other, amount * 0.8, { Type = ability.DamageType or "Magic", Ability = true })
					end
				end
			end
		end
		return ability.MaxHits ~= nil and hits >= ability.MaxHits
	end
	local function fire()
		if not Combat.Alive(hero) then
			return
		end
		local from = Combat.Position(hero)
		if ability.Speed then
			skillshot(hero, from, direction, ability.Length, ability.Width, ability.Speed, kinds, onHit, color, if ability.Hook then "Hook" else nil)
		else
			-- Sofortiger Strahl (z. B. Lumis Laser)
			Net.SendFx("Laser", { From = from, To = from + direction * ability.Length, Width = ability.Width, Color = color })
			skillshot(hero, from, direction, ability.Length, ability.Width, nil, kinds, onHit, color, "None")
		end
	end
	if ability.Delay then
		Net.SendFx("Telegraph", { From = position, To = position + direction * ability.Length, Width = ability.Width, Time = ability.Delay, Color = color })
		if ability.Delay >= 0.8 then
			hero.Status.RootUntil = math.max(hero.Status.RootUntil or 0, now() + ability.Delay)
		end
		task.delay(ability.Delay, fire)
	else
		fire()
	end
	return true
end

function Cast.Dash(hero, ability, rank, aim)
	local position, point, direction = aimInfo(hero, aim, ability.Range)
	local distance = math.clamp((point - position).Magnitude, 6, ability.Range)
	local destination = Abilities.Walkable(position, position + direction * distance)
	local color = colorOf(hero)
	if ability.StopAtHero then
		for _, enemy in Combat:EnemiesNear(hero.Team, (position + destination) / 2, distance / 2 + 4, HERO_ONLY) do
			if distanceToSegment(Combat.Position(enemy), position, destination) <= ability.Radius + enemy.Radius then
				local stop = position + direction * math.max(0, (Combat.Position(enemy) - position):Dot(direction) - 2.5)
				if (stop - position).Magnitude < (destination - position).Magnitude then
					destination = stop
				end
			end
		end
	end
	if ability.Unstoppable then
		hero.Status.UnstoppableUntil = now() + 0.6
	end
	Heroes:CancelRecall(hero)
	Net.SendFx("Dash", { From = position, To = destination, Color = color })
	Heroes:Teleport(hero, destination)
	if (ability.Damage or 0) ~= 0 then
		local amount = amountFor(hero, ability, rank)
		local hitList = {}
		if ability.StopAtHero then
			-- Alles auf dem Weg wird getroffen
			for _, target in Combat:EnemiesNear(hero.Team, (position + destination) / 2, (destination - position).Magnitude / 2 + ability.Radius + 2, ENEMY) do
				if distanceToSegment(Combat.Position(target), position, destination) <= ability.Radius + target.Radius then
					hitList[target] = true
				end
			end
		end
		for _, target in Combat:EnemiesNear(hero.Team, destination, ability.Radius, ENEMY) do
			hitList[target] = true
		end
		Net.SendFx("Ring", { At = destination, Radius = ability.Radius, Color = color })
		for target in hitList do
			hit(hero, target, ability, amount)
		end
	end
	return true
end

function Cast.Shield(hero, ability, rank)
	local amount = at(ability.Shield, rank) + (ability.AP or 0) * hero.AP
	local position = Combat.Position(hero)
	Combat:Shield(hero, amount, ability.Duration or 2.5, hero)
	if ability.PullAlly then
		local best, bestDistance = nil, math.huge
		for _, ally in Combat:AlliesNear(hero.Team, position, ability.Radius, HERO_ONLY) do
			local distance = Combat.Distance(hero, ally)
			if ally ~= hero and distance < bestDistance then
				best, bestDistance = ally, distance
			end
		end
		if best then
			Net.SendFx("Hook", { From = position, To = Combat.Position(best), Color = colorOf(hero) })
			local away = Combat.Position(best) - position
			displace(best, position + (if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis) * 3)
			Combat:Shield(best, amount, ability.Duration or 2.5, hero)
		end
	else
		for _, ally in Combat:AlliesNear(hero.Team, position, ability.Radius or 0, HERO_ONLY) do
			if ally ~= hero then
				Combat:Shield(ally, amount, ability.Duration or 2.5, hero)
			end
		end
	end
	return true
end

function Cast.Buff(hero, ability, rank)
	local values = {
		AS = if ability.AttackSpeed then at(ability.AttackSpeed, rank) else nil,
		Range = ability.Range,
		MSPct = if ability.Speed then at(ability.Speed, rank) else nil,
		Splash = ability.Splash,
		TrueOnHit = if ability.TrueOnHit then at(ability.TrueOnHit, rank) + (ability.BonusADOnHit or 0) * hero.BonusAD else nil,
	}
	local key = ability.Key
	Heroes:AddTemp(hero, "Buff" .. key, ability.Duration or 5, values)
	if ability.SlowImmune then
		hero.Status.SlowImmuneUntil = now() + (ability.Duration or 5)
	end
	hero.NextAttack = math.min(hero.NextAttack or 0, now())
	Net.SendFx("Buff", { Model = hero.Model, Time = ability.Duration or 5, Color = colorOf(hero) })
	return true
end

function Cast.Stealth(hero, ability, rank)
	local seconds = at(ability.Duration, rank)
	hero.Status.StealthUntil = now() + seconds
	Heroes:AddTemp(hero, "Stealth", seconds, { MSPct = ability.Speed })
	if ability.ResetKey then
		Heroes:SetCooldown(hero, ability.ResetKey, 0, 0)
	end
	Net.SendFx("Stealth", { Model = hero.Model, Time = seconds })
	return true
end

function Cast.HealAlly(hero, ability, rank, aim)
	local position = Combat.Position(hero)
	local best, bestScore = nil, math.huge
	for _, ally in Combat:AlliesNear(hero.Team, position, ability.Range, HERO_ONLY) do
		if ally ~= hero and ally.HP < ally.MaxHP then
			local score = ally.HP / ally.MaxHP
			if aim then
				score = (Combat.Position(ally) - flat(aim)).Magnitude
			end
			if score < bestScore then
				best, bestScore = ally, score
			end
		end
	end
	if not best then
		notify(hero, "No hurt ally in range!")
		return false
	end
	hero.HP = math.max(1, hero.HP - hero.MaxHP * (ability.SelfCostHP or 0))
	Combat:Sync(hero)
	Combat:Heal(best, at(ability.Heal, rank) + (ability.AP or 0) * hero.AP, hero)
	Net.SendFx("Bolt", { From = position, To = Combat.Position(best), Color = Color3.fromRGB(120, 255, 140) })
	Net.SendFx("Heal", { At = Combat.Position(best), Radius = 4 })
	return true
end

function Cast.Zone(hero, ability, rank, aim)
	local center
	if ability.Self then
		center = Combat.Position(hero)
	else
		local position, point = aimInfo(hero, aim, ability.Range)
		center = clampPoint(position, point, ability.Range)
	end
	local color = colorOf(hero)
	Net.SendFx("Zone", { At = center, Radius = ability.Radius, Time = ability.Duration, Color = color })
	local amount = amountFor(hero, ability, rank)
	for _, target in Combat:EnemiesNear(hero.Team, center, ability.Radius, ENEMY) do
		hit(hero, target, ability, amount, { NoRoot = true })
	end
	task.spawn(function()
		local ticks = math.max(1, math.floor(ability.Duration / (ability.Tick or ability.Duration)))
		for _ = 1, ticks do
			task.wait(ability.Tick or ability.Duration)
			if hero.Removed then
				return
			end
			for _, target in Combat:EnemiesNear(hero.Team, center, ability.Radius, ENEMY) do
				if ability.Slow then
					Combat:Slow(target, ability.Slow, ability.SlowTime or 0.6)
				end
			end
		end
		if ability.FinalRoot then
			Net.SendFx("Boom", { At = center, Color = color, Size = ability.Radius * 2 })
			for _, target in Combat:EnemiesNear(hero.Team, center, ability.Radius, ENEMY) do
				Combat:Root(target, ability.FinalRoot)
			end
		end
	end)
	return true
end

function Cast.Heal(hero, ability, rank)
	local amount = at(ability.Heal, rank) + (ability.AP or 0) * hero.AP
	for _, ally in Heroes.Heroes do
		if ally.Team == hero.Team and Combat.Alive(ally) then
			Combat:Heal(ally, amount, hero)
			Net.SendFx("Heal", { At = Combat.Position(ally), Radius = 5 })
		end
	end
	return true
end

function Cast.Blink(hero, ability, rank, aim)
	local position, point, direction = aimInfo(hero, aim, ability.Range)
	local distance = math.min(ability.Range, (point - position).Magnitude)
	local destination = Abilities.Walkable(position, position + direction * math.max(distance, 8))
	local color = colorOf(hero)
	Net.SendFx("Flash", { From = position, To = destination, Color = color })
	Heroes:Teleport(hero, destination)
	local target = Combat:NearestEnemy(hero.Team, destination, ability.BoltRange, HERO_ONLY) or Combat:NearestEnemy(hero.Team, destination, ability.BoltRange, ENEMY)
	if target then
		Net.SendFx("Bolt", { From = destination, To = Combat.Position(target), Color = color })
		hit(hero, target, ability, amountFor(hero, ability, rank))
	end
	return true
end

function Cast.Rush(hero, ability, rank, aim)
	local first = pickTarget(hero, aim, ability.Range, ENEMY)
	if not first then
		notify(hero, "No target in range!")
		return false
	end
	local color = colorOf(hero)
	hero.Status.UntargetableUntil = now() + ability.Hits * 0.15 + 0.1
	task.spawn(function()
		local done = {}
		local current = first
		for _ = 1, ability.Hits do
			if not current or not Combat.Alive(hero) then
				break
			end
			done[current] = true
			local position = Combat.Position(current)
			Net.SendFx("Dash", { From = Combat.Position(hero), To = position, Color = color })
			Heroes:Teleport(hero, position + Vector3.new(math.random(-2, 2), 0, math.random(-2, 2)))
			local amount = amountFor(hero, ability, rank)
			if ability.MonsterBonus and current.Kind == "Monster" then
				amount += at(ability.MonsterBonus, rank)
			end
			Net.SendFx("BigSlash", { At = position, Color = color })
			hit(hero, current, ability, amount)
			local nextTarget, bestDistance = nil, math.huge
			for _, unit in Combat:EnemiesNear(hero.Team, position, ability.Bounce, ENEMY) do
				local distance = (Combat.Position(unit) - position).Magnitude
				if not done[unit] and distance < bestDistance and Combat.Visible(unit, hero.Team) then
					nextTarget, bestDistance = unit, distance
				end
			end
			current = nextTarget
			task.wait(0.15)
		end
	end)
	return true
end

function Cast.Channel(hero, ability, rank)
	local t = now()
	local seconds = ability.Duration or 2
	hero.Status.ChannelUntil = t + seconds
	hero.Status.Reduction = at(ability.Reduction or 0, rank)
	hero.Status.ReductionUntil = t + seconds
	hero.ChannelHeal = { Next = t + 0.5, Until = t + seconds, Amount = at(ability.Heal, rank) + (ability.AP or 0) * hero.AP, Missing = ability.MissingHeal or 0 }
	Heroes:CancelRecall(hero)
	Net.SendFx("Buff", { Model = hero.Model, Time = seconds, Color = Color3.fromRGB(120, 255, 160) })
	return true
end

function Cast.Cone(hero, ability, rank, aim)
	local position, _, direction = aimInfo(hero, aim, ability.Range)
	local color = colorOf(hero)
	local half = math.rad((ability.Angle or 60) / 2)
	Net.SendFx("Cone", { At = position, Dir = direction, Range = ability.Range, Angle = ability.Angle or 60, Color = color })
	face(hero, direction)
	local amount = amountFor(hero, ability, rank)
	for _, target in Combat:EnemiesNear(hero.Team, position, ability.Range, ENEMY) do
		local offset = Combat.Position(target) - position
		if offset.Magnitude < 1 or math.acos(math.clamp(offset.Unit:Dot(direction), -1, 1)) <= half then
			hit(hero, target, ability, amount)
			if ability.Pull then
				displace(target, position + direction * 3.5)
			end
		end
	end
	return true
end

-- Gibt (Erfolg, Abklingzeit behalten) zurueck
function Abilities.Cast(hero, ability, rank: number, aim: Vector3?)
	local handler = Cast[ability.Type]
	if not handler then
		return false
	end
	local ok, keep = handler(hero, ability, rank, aim)
	return ok == true, keep == true
end

---------------------------------------------------------------- Normale Angriffe

-- Treffer-Effekte (auch fuer Faehigkeiten, die "on-hit" ausloesen)
function Abilities.OnHitEffects(hero, victim)
	local t = now()
	if not Combat.Alive(victim) then
		return
	end
	-- Verstaerkter Angriff (Brakka W, Varg W)
	local empower = hero.Empower
	if empower and empower.Until > t and empower.Left > 0 then
		empower.Left -= 1
		if empower.Left <= 0 then
			hero.Empower = nil
		end
		local ability = empower.Ability
		local amount = amountFor(hero, ability, empower.Rank)
		hit(hero, victim, ability, amount)
		if ability.Splash then
			Net.SendFx("Ring", { At = Combat.Position(victim), Radius = ability.Splash, Color = colorOf(hero) })
			for _, other in Combat:EnemiesNear(hero.Team, Combat.Position(victim), ability.Splash, ENEMY) do
				if other ~= victim then
					Combat:Damage(hero, other, amount, { Type = ability.DamageType or "Physical", Ability = true })
				end
			end
		end
	end
	-- Echter Zusatzschaden (Volt E)
	local trueOnHit = Heroes.Temp(hero, "TrueOnHit")
	if trueOnHit > 0 and Combat.Alive(victim) then
		Combat:Damage(hero, victim, trueOnHit, { Type = "True", Dot = true })
	end
	-- Rot-Buff: brennen und verlangsamen
	if Heroes.ActiveBuff(hero, "Red") and Combat.Alive(victim) then
		local buff = Config.Buffs.Red
		Abilities.DamageOverTime(hero, victim, buff.BurnTrue + buff.BurnPerLevel * hero.Level, 3, "True")
		Combat:Slow(victim, buff.Slow, 1.5)
	end
	-- Lumi: Lichtmarke zuenden
	local mark = victim.LumiMark
	if mark and mark.By == hero and mark.Until > t and Combat.Alive(victim) then
		victim.LumiMark = nil
		Net.SendFx("Boom", { At = Combat.Position(victim), Color = Color3.fromRGB(255, 250, 180), Size = 6 })
		Combat:Damage(hero, victim, 20 + 10 * hero.Level + 0.2 * hero.AP, { Type = "Magic", Dot = true })
	end
	if passive(hero) == "Frostbite" and Combat.Alive(victim) then
		Combat:Slow(victim, 0.2, 1.5)
	end
	-- Pips Raketen: Flaechenschaden
	local splash = Heroes.Temp(hero, "Splash")
	if splash > 0 then
		Net.SendFx("Boom", { At = Combat.Position(victim), Color = colorOf(hero), Size = splash * 2 })
		for _, other in Combat:EnemiesNear(hero.Team, Combat.Position(victim), splash, ENEMY) do
			if other ~= victim then
				Combat:Damage(hero, other, hero.AD * 0.8, { Type = "Physical", Dot = true })
			end
		end
	end
end

function Abilities.Attack(hero, target)
	hero.Status.StealthUntil = 0
	hero.AttackCount = (hero.AttackCount or 0) + 1
	local count = hero.AttackCount
	face(hero, Combat.Position(target) - Combat.Position(hero))
	Combat:Attack(hero, target, function(victim)
		local t = now()
		local crit = math.random() < (hero.Crit or 0)
		local amount = hero.AD * (if crit then hero.CritDamage else 1)
		if (hero.SpellbladeUntil or 0) > t then
			hero.SpellbladeUntil = 0
			hero.SpellbladeCD = t + 1.5
			amount += hero.BaseAD * 2
			Net.SendFx("Boom", { At = Combat.Position(victim), Color = Color3.fromRGB(255, 220, 120), Size = 5 })
		end
		Combat:Damage(hero, victim, amount, { OnHit = true, Type = "Physical", Crit = crit })
		Abilities.OnHitEffects(hero, victim)
		-- Sturmbogen: jeder 3. Angriff schiesst Blitze auf 2 weitere Gegner
		if Heroes.HasUnique(hero, "Bolts") and count % 3 == 0 then
			local shots = 0
			for _, other in Combat:EnemiesNear(hero.Team, Combat.Position(hero), 26, ENEMY) do
				if other ~= victim and shots < 2 and Combat.Visible(other, hero.Team) then
					shots += 1
					Net.SendFx("Bolt", { From = Combat.Position(hero), To = Combat.Position(other), Color = Color3.fromRGB(150, 210, 255) })
					Combat:Damage(hero, other, 40 + hero.BonusAD * 0.4, { Type = "Magic", Dot = true })
				end
			end
		end
		-- Volt: jeder 4. Angriff trifft doppelt
		if passive(hero) == "DoubleStrike" and count % 4 == 0 then
			task.delay(0.15, function()
				if Combat.Alive(victim) and Combat.Alive(hero) then
					Net.SendFx("Slash", { At = Combat.Position(victim), Color = colorOf(hero), Big = true })
					Combat:Damage(hero, victim, hero.AD * 0.5, { OnHit = true, Type = "Physical" })
				end
			end)
		end
	end)
end

---------------------------------------------------------------- Passive und Item-Effekte

local function addBleed(hero, target)
	local t = now()
	local bleed = target.Bleed
	if not bleed or bleed.By ~= hero or bleed.Until <= t then
		bleed = { By = hero, Stacks = 0, Until = 0 }
		target.Bleed = bleed
	end
	bleed.Stacks = math.min(5, bleed.Stacks + 1)
	bleed.Until = t + 5
	hero.BleedTargets = hero.BleedTargets or {}
	hero.BleedTargets[target] = true
	if bleed.Stacks >= 5 and target.Kind == "Hero" and (hero.Bloodlust or 0) <= t then
		hero.Bloodlust = t + 5
		Heroes:Recompute(hero)
		Net.SendFx("Buff", { Model = hero.Model, Time = 5, Color = Color3.fromRGB(220, 40, 40) })
	end
	if target.Model then
		target.Model:SetAttribute("Bleed", bleed.Stacks)
	end
end

function Abilities.Attach(hero)
	hero.ModifyDamage = function(source, target, amount, _opts)
		if passive(source) == "Isolation" and (target.Kind == "Hero" or target.Kind == "Monster") and isolated(target) then
			amount *= 1.3
		end
		if source.Uniques.Machete and target.Kind == "Monster" then
			amount *= 1.4
		end
		return amount
	end
	hero.AfterDamage = function(source, target, dealt, opts)
		local t = now()
		if dealt <= 0 then
			return
		end
		if opts.Type == "Physical" and not opts.Dot then
			if source.Uniques.Shred and target.Kind == "Hero" then
				target.Shred = math.min(0.3, (target.Shred or 0) + 0.05)
				target.ShredUntil = t + 6
			end
			if passive(source) == "Bleed" then
				addBleed(source, target)
			end
		end
		if opts.Ability and not opts.Dot then
			if source.Uniques.Echo and t >= (source.EchoAt or 0) then
				source.EchoAt = t + 10
				Net.SendFx("Boom", { At = Combat.Position(target), Color = Color3.fromRGB(150, 120, 255), Size = 12 })
				for _, other in Combat:EnemiesNear(source.Team, Combat.Position(target), 8, ENEMY) do
					Combat:Damage(source, other, 100 + 0.1 * source.AP, { Type = "Magic", Dot = true })
				end
			end
			if passive(source) == "RisingSpell" and t - (source.SpellForceAt or 0) > 0.25 then
				source.SpellForceAt = t
				source.SpellForce = math.min(5, (source.SpellForce or 0) + 1)
				source.SpellForceUntil = t + 6
				Heroes:Recompute(source)
			end
			-- Ember: Faehigkeiten setzen Gegner in Brand (hoechstens einmal pro Sekunde und Ziel)
			if passive(source) == "Kindling" and Combat.Alive(target) and t >= ((target.KindledAt or {})[source] or 0) then
				target.KindledAt = target.KindledAt or setmetatable({}, { __mode = "k" })
				target.KindledAt[source] = t + 1
				Abilities.DamageOverTime(source, target, 12 + 4 * source.Level + 0.12 * source.AP, 3, "Magic")
				if target.Model then
					Net.SendFx("Burn", { Model = target.Model, Time = 3 })
				end
			end
			if passive(source) == "Illumination" and Combat.Alive(target) then
				target.LumiMark = { By = source, Until = t + 6 }
				if target.Model then
					Net.SendFx("Mark", { Model = target.Model, Time = 6, Color = Color3.fromRGB(255, 250, 180) })
				end
			end
		end
		local mark = target.ZephyrMark
		if mark and mark.By == source and mark.Until > t and not opts.MarkHit and not opts.Dot and Combat.Alive(target) then
			target.ZephyrMark = nil
			Net.SendFx("Boom", { At = Combat.Position(target), Color = colorOf(source), Size = 6 })
			Combat:Damage(source, target, mark.Amount, { Type = "Magic", Dot = true })
		end
		-- Aelterer Drache: Helden unter 20 % werden hingerichtet
		if Heroes.ActiveBuff(source, "Elder") and target.Kind == "Hero" and Combat.Alive(target) and target.HP < target.MaxHP * Config.Buffs.Elder.Execute then
			Net.SendFx("Boom", { At = Combat.Position(target), Color = Config.Buffs.Elder.Color, Size = 10 })
			Combat:Damage(source, target, target.HP + 50, { Type = "True", Dot = true })
		end
	end
	hero.OnDamaged = function(target, source, _dealt, opts)
		if opts.OnHit and source and source ~= target and target.Uniques.Thorns and not Combat.IsStructure(source) then
			Combat:Damage(target, source, 10 + 0.1 * (target.Armor - (target.BaseArmor or 0)), { Type = "Magic", Dot = true, NoReveal = true })
		end
		target.GraniteAt = now() + 10
	end
	hero.ModifyIncoming = function(target, _source, dealt, _opts)
		if passive(target) == "Frostbite" and now() - (target.LastDamagedAt or 0) > 5 then
			dealt *= 0.85
		end
		return dealt
	end
	hero.OnLethal = function(target, _source)
		local t = now()
		if target.Uniques.Revive and t >= (target.ReviveAt or 0) then
			target.ReviveAt = t + 300
			target.HP = 1
			target.Status.StasisUntil = t + 2
			Net.SendFx("Stasis", { Model = target.Model, Time = 2 })
			task.delay(2, function()
				if not target.Dead and not target.Removed then
					target.HP = math.max(target.HP, target.MaxHP * 0.5)
					Combat:Sync(target)
				end
			end)
			return true
		end
		return false
	end
end

-- Laufgeschwindigkeit, die sich staendig aendert (Thorne laeuft schneller zu verletzten Freunden)
function Abilities.SpeedFactor(hero): number
	if passive(hero) == "Salvation" then
		for _, ally in Combat:AlliesNear(hero.Team, Combat.Position(hero), 60, HERO_ONLY) do
			if ally ~= hero and ally.HP < ally.MaxHP * 0.4 then
				return 1.3
			end
		end
	end
	return 1
end

function Abilities.Tick(hero, _dt: number, t: number)
	-- Brakka: Granitschild kommt nach 10 Sekunden ohne Schaden zurueck
	if passive(hero) == "GraniteShield" and t >= (hero.GraniteAt or 0) then
		hero.GraniteAt = t + 1
		local wanted = hero.MaxHP * 0.1
		local current = if (hero.Status.ShieldUntil or 0) > t then hero.Status.Shield or 0 else 0
		if current < wanted - 1 then
			-- Kurze Dauer statt einer Stunde: jede Erneuerung startet sonst einen langen Hintergrund-Thread
			Combat:Shield(hero, wanted - current, 20)
		end
	end
	-- Volt W: Heilung waehrend des Kanalisierens
	local channel = hero.ChannelHeal
	if channel then
		if (hero.Status.ChannelUntil or 0) <= t and channel.Until > t then
			hero.ChannelHeal = nil -- unterbrochen
		elseif t >= channel.Next then
			channel.Next = t + 0.5
			Combat:Heal(hero, (channel.Amount + (hero.MaxHP - hero.HP) * channel.Missing) / 2, hero)
			if t >= channel.Until then
				hero.ChannelHeal = nil
			end
		end
	end
	-- Jede Sekunde: Glutaegis brennt, Blutungen ticken
	if t >= (hero.SecondAt or 0) then
		hero.SecondAt = t + 1
		if hero.Uniques.Burn then
			for _, enemy in Combat:EnemiesNear(hero.Team, Combat.Position(hero), 9, ENEMY) do
				Combat:Damage(hero, enemy, 15 + 0.01 * (hero.MaxHP - (hero.BaseHP or hero.MaxHP)), { Type = "Magic", Dot = true, NoReveal = true })
			end
		end
		if hero.BleedTargets then
			for target in hero.BleedTargets do
				local bleed = target.Bleed
				if not bleed or bleed.By ~= hero or bleed.Until <= t or not Combat.Alive(target) then
					hero.BleedTargets[target] = nil
					if target.Model and (not bleed or bleed.Until <= t) then
						target.Model:SetAttribute("Bleed", 0)
					end
				else
					Combat:Damage(hero, target, (3 + 0.05 * hero.BonusAD) * bleed.Stacks, { Type = "Physical", Dot = true, NoReveal = true })
				end
			end
		end
	end
end

function Abilities.OnTakedown(hero, victim)
	if victim.Kind ~= "Hero" then
		return
	end
	if passive(hero) == "GetExcited" then
		Heroes:AddTemp(hero, "Excited", 4, { MSPct = 0.5, AS = 0.5 })
		Net.SendFx("Buff", { Model = hero.Model, Time = 4, Color = Color3.fromRGB(255, 120, 200) })
	end
	-- Volt R: Takedowns verlaengern Overdrive
	local overdrive = hero.Temp.BuffR
	if overdrive and overdrive.Until > now() and hero.Def.Abilities.R.ResetOnKill and hero.Def.Abilities.R.Type == "Buff" then
		overdrive.Until += 4
		hero.Status.SlowImmuneUntil = overdrive.Until
	end
end

function Abilities.OnUnitKilled(_hero, _unit) end

function Abilities.OnTakedownStructure(hero)
	if passive(hero) == "GetExcited" then
		Heroes:AddTemp(hero, "Excited", 4, { MSPct = 0.5, AS = 0.5 })
	end
end

return Abilities
