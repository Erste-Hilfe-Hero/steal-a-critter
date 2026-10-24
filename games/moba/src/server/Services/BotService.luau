-- Bot-KI: fuellt leere Plaetze, damit man auch allein sofort eine volle 5-gegen-5-Runde spielt.
-- Jede Rolle spielt wie im Original: Toplaner, Midlaner, Botlaner mit Support, Jungler mit Smite.
-- Gemeinsam: zurueckziehen, nach Hause teleportieren und einkaufen, kaempfen, Tuerme einreissen, Drachen und Baron.
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BotService = { Services = nil :: any }

local MAP = Config.Map
local TICK = 0.25
local HERO_ONLY = { Hero = true }
local MINIONS = { Minion = true }

BotService.Names = { "Nova", "Blaze", "Echo", "Pixel", "Ziggy", "Mochi", "Rex", "Luna", "Comet", "Pebble", "Juno", "Taro", "Kiwi", "Orbit", "Sparky", "Nimbus" }
BotService.DamageScale = 0.85

local Combat

function BotService:Init(services)
	self.Services = services
	Combat = services.CombatService
end

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------- Lane-Geometrie

-- Fortschritt entlang der Lane (in Studs ab der eigenen Basis)
local function project(points, position: Vector3)
	local best, bestDistance, bestProgress, bestSegment = nil, math.huge, 0, 1
	local walked = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local ab = b - a
		local length = ab.Magnitude
		local t = math.clamp((position - a):Dot(ab) / (length * length), 0, 1)
		local point = a + ab * t
		local distance = (position - point).Magnitude
		if distance < bestDistance then
			best, bestDistance, bestProgress, bestSegment = point, distance, walked + length * t, i
		end
		walked += length
	end
	return bestProgress, bestSegment, best, bestDistance
end

local function pointAt(points, progress: number): Vector3
	local walked = 0
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local length = (b - a).Magnitude
		if walked + length >= progress then
			return a:Lerp(b, math.clamp((progress - walked) / length, 0, 1))
		end
		walked += length
	end
	return points[#points]
end

---------------------------------------------------------------- Bewegung mit Wegfindung durch den Dschungel

local function brain(hero)
	hero.Brain = hero.Brain or {}
	return hero.Brain
end

local function hold(hero)
	if hero.Humanoid then
		local position = Combat.Position(hero)
		hero.Humanoid:MoveTo(Vector3.new(position.X, 3, position.Z))
	end
	brain(hero).LastPosition = nil
end

local function computePath(hero, from: Vector3, goal: Vector3)
	local b = brain(hero)
	b.Computing = true
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2.5, AgentHeight = 6, AgentCanJump = false, WaypointSpacing = 8 })
		local ok = pcall(function()
			path:ComputeAsync(from + Vector3.new(0, 3, 0), goal + Vector3.new(0, 3, 0))
		end)
		b.Computing = false
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(points, Vector3.new(waypoint.Position.X, 0, waypoint.Position.Z))
			end
			b.Path = points
			b.PathIndex = 1
		else
			b.Path = nil
		end
		b.PathGoal = goal
		b.PathAt = now()
	end)
end

local function moveTo(self, hero, goal: Vector3)
	local humanoid = hero.Humanoid
	if not humanoid then
		return
	end
	local b = brain(hero)
	local position = Combat.Position(hero)
	goal = Vector3.new(goal.X, 0, goal.Z)
	if (goal - position).Magnitude < 1.5 then
		hold(hero)
		return
	end
	-- Steckt fest: Weg neu berechnen und seitlich ausweichen
	if b.LastPosition and (position - b.LastPosition).Magnitude < 0.3 and humanoid.WalkSpeed > 0 then
		b.Stuck = (b.Stuck or 0) + 1
	else
		b.Stuck = 0
	end
	b.LastPosition = position
	if b.Stuck >= 5 then
		b.Stuck = 0
		b.Path = nil
		b.PathAt = 0
		local side = (goal - position).Unit:Cross(Vector3.yAxis) * (if math.random() < 0.5 then -6 else 6)
		humanoid:MoveTo(Vector3.new(position.X + side.X, 3, position.Z + side.Z))
		return
	end
	local world = self.Services.WorldService
	local waypoint = goal
	if not world.LineClear(position, goal) then
		local path = b.Path
		local fresh = path and b.PathGoal and (b.PathGoal - goal).Magnitude < 8 and now() - (b.PathAt or 0) < 6
		if fresh then
			local index = b.PathIndex or 1
			while path[index + 1] and ((path[index] - position).Magnitude < 3 or world.LineClear(position, path[index + 1])) do
				index += 1
			end
			b.PathIndex = index
			waypoint = path[index] or goal
		elseif not b.Computing then
			computePath(hero, position, goal)
		end
	end
	humanoid:MoveTo(Vector3.new(waypoint.X, 3, waypoint.Z))
end

---------------------------------------------------------------- Gefahr durch Tuerme

-- Ein Punkt ist sicher, wenn kein feindlicher Turm ihn trifft oder eigene Minions den Turm beschaeftigen
local function isSafe(self, hero, point: Vector3): boolean
	local lane = self.Services.LaneService
	for _, tower in lane.Towers do
		if tower.Team ~= hero.Team and not tower.Dead and (point - tower.Home).Magnitude <= tower.Range + 5 then
			local tanks = Combat:AlliesNear(hero.Team, tower.Home, tower.Range, MINIONS)
			if #tanks < 2 or tower.Target == hero then
				return false
			end
		end
	end
	return true
end

---------------------------------------------------------------- Faehigkeiten und Zauber

local function cast(self, hero, key: string, point: Vector3?)
	return self.Services.HeroService:Cast(hero, key, point)
end

local function tryAbilities(self, hero, target, crowd: number)
	local t = now()
	local position = Combat.Position(hero)
	for _, key in { "R", "Q", "W", "E" } do
		local ability = hero.Def.Abilities[key]
		if (hero.Ranks[key] or 0) <= 0 or (hero.Cooldowns[key] or 0) > t or math.random() > 0.55 then
			continue
		end
		local kind = ability.Type
		local distance = if target then (Combat.Position(target) - position).Magnitude else math.huge
		local reach = ability.Range or ability.Length or ability.Radius or 10
		local useful = false
		local aim = if target then Combat.Position(target) else nil
		if kind == "Shield" then
			useful = target ~= nil and distance < 30 and hero.HP < hero.MaxHP * 0.85
		elseif kind == "HealAlly" then
			for _, ally in Combat:AlliesNear(hero.Team, position, ability.Range, HERO_ONLY) do
				if ally ~= hero and ally.HP < ally.MaxHP * 0.65 then
					useful = true
					aim = Combat.Position(ally)
				end
			end
		elseif kind == "Heal" then
			for _, ally in self.Services.HeroService.Heroes do
				if ally.Team == hero.Team and Combat.Alive(ally) and ally.HP < ally.MaxHP * 0.3 then
					useful = true
				end
			end
		elseif kind == "Channel" then
			useful = hero.HP < hero.MaxHP * 0.5 and not Combat:NearestEnemy(hero.Team, position, 16, HERO_ONLY)
		elseif kind == "Buff" or kind == "Empower" then
			useful = target ~= nil and distance <= hero.Range + 6
		elseif kind == "Stealth" then
			useful = target ~= nil and target.Kind == "Hero" and distance <= 22
		elseif kind == "Circle" then
			useful = target ~= nil and distance <= ability.Radius
		elseif kind == "Line" then
			useful = target ~= nil and distance <= math.min(reach, 60)
		elseif kind == "Blink" then
			useful = target ~= nil and target.Kind == "Hero" and distance <= ability.BoltRange and hero.HP > hero.MaxHP * 0.4
		else
			useful = target ~= nil and distance <= reach
		end
		-- Ultimates nur gegen Helden oder grosse Gruppen
		if useful and key == "R" and kind ~= "Heal" and (target == nil or (target.Kind ~= "Hero" and crowd < 4)) then
			useful = false
		end
		if useful and cast(self, hero, key, aim) then
			return true
		end
	end
	return false
end

local function spellReady(hero, id: string): string?
	local t = now()
	for _, slot in { "D", "F" } do
		if hero.Spells[slot] == id then
			if id == "Smite" then
				return if hero.SmiteCharges > 0 then slot else nil
			end
			return if (hero.Cooldowns[slot] or 0) <= t then slot else nil
		end
	end
	return nil
end

local function useSpells(self, hero, enemy)
	local heroes = self.Services.HeroService
	local ratio = hero.HP / hero.MaxHP
	local position = Combat.Position(hero)
	if ratio < 0.25 and enemy then
		local slot = spellReady(hero, "Heal") or spellReady(hero, "Barrier")
		if slot then
			heroes:CastSpell(hero, slot, nil)
			return
		end
		if ratio < 0.18 and (Combat.Position(enemy) - position).Magnitude < 12 then
			local flash = spellReady(hero, "Flash")
			if flash then
				local away = position + (MAP.Fountain[hero.Team] - position).Unit * 18
				heroes:CastSpell(hero, flash, away)
				return
			end
		end
	end
	if enemy and enemy.Kind == "Hero" then
		local distance = (Combat.Position(enemy) - position).Magnitude
		local ignite = spellReady(hero, "Ignite")
		if ignite and distance <= 24 and enemy.HP < enemy.MaxHP * 0.3 then
			heroes:CastSpell(hero, ignite, Combat.Position(enemy))
		end
		local exhaust = spellReady(hero, "Exhaust")
		if exhaust and distance <= 22 and ratio < 0.6 then
			heroes:CastSpell(hero, exhaust, Combat.Position(enemy))
		end
		local ghost = spellReady(hero, "Ghost")
		if ghost and distance > hero.Range + 4 and enemy.HP < enemy.MaxHP * 0.35 then
			heroes:CastSpell(hero, ghost, nil)
		end
	end
	if hero.Potions > 0 and ratio < 0.55 and (hero.PotionUntil or 0) < now() and not heroes:InFountain(hero) then
		heroes:UsePotion(hero)
	end
end

---------------------------------------------------------------- Wards

local WARD_SPOTS = {
	Vector3.new(-40, 0, -72), Vector3.new(-72, 0, -40), Vector3.new(40, 0, 72), Vector3.new(72, 0, 40),
	Vector3.new(-22, 0, -2), Vector3.new(2, 0, 22), Vector3.new(-60, 0, -60), Vector3.new(60, 0, 60),
}

local function maybeWard(self, hero)
	if hero.WardCharges <= 0 or now() < (brain(hero).WardAt or 0) then
		return
	end
	local position = Combat.Position(hero)
	for _, spot in WARD_SPOTS do
		if (spot - position).Magnitude <= Config.Ward.Range then
			local covered = false
			for _, ward in self.Services.HeroService.Wards do
				if ward.Team == hero.Team and (ward.Home - spot).Magnitude < 16 then
					covered = true
				end
			end
			if not covered then
				self.Services.HeroService:PlaceWard(hero, spot)
				brain(hero).WardAt = now() + 25
				return
			end
		end
	end
end

---------------------------------------------------------------- Ziele

local function epicMonsters(self)
	local list = {}
	for _, monster in self.Services.JungleService.Monsters do
		if monster.Epic and Combat.Alive(monster) then
			table.insert(list, monster)
		end
	end
	return list
end

local function alliesAlive(self, hero): number
	local count = 0
	for _, other in self.Services.HeroService.Heroes do
		if other.Team == hero.Team and Combat.Alive(other) then
			count += 1
		end
	end
	return count
end

-- Wird gerade ein episches Monster von unserem Team bekaempft? Dann hingehen und helfen.
local function objectiveCall(self, hero)
	local position = Combat.Position(hero)
	for _, monster in epicMonsters(self) do
		local target = monster.Target
		if target and target.Team == hero.Team and (Combat.Position(monster) - position).Magnitude < 90 then
			return monster
		end
	end
	return nil
end

-- Monster schlagen; grosse Monster mit Smite sichern
local function fightMonster(self, hero, monster)
	local heroes = self.Services.HeroService
	hero.Focus = monster
	local smite = spellReady(hero, "Smite")
	if smite and Combat.Alive(monster) then
		local smiteDamage = Config.SmiteDamage(hero.Level)
		local big = monster.Epic or Config.Monsters[monster.MonsterId].Buff ~= nil
		local secure = monster.HP <= smiteDamage and (big or hero.SmiteCharges >= 2)
		local early = hero.SmiteCharges >= 2 and big and not monster.Epic
		if (secure or early) and Combat.Distance(hero, monster) <= Config.SpellsById.Smite.Range + monster.Radius then
			heroes:CastSpell(hero, smite, Combat.Position(monster))
		end
	end
	tryAbilities(self, hero, monster, 1)
	local distance = Combat.Distance(hero, monster)
	if distance > hero.Range + monster.Radius + hero.Radius then
		moveTo(self, hero, Combat.Position(monster))
	else
		hold(hero)
	end
end

---------------------------------------------------------------- Rollen

local function laneThink(self, hero, laneName: string)
	local lane = self.Services.LaneService
	local position = Combat.Position(hero)
	local points = Config.LanePoints(laneName, hero.Team)
	local _, _, _, offLane = project(points, position)
	if offLane > 30 then
		-- Erst zur Lane laufen (durch die Basis bzw. den Dschungel)
		local progress = project(points, position)
		moveTo(self, hero, pointAt(points, math.max(progress, 20)))
		return
	end
	-- Knapp hinter den eigenen Minions stehen
	local front, frontProgress = nil, -math.huge
	for _, minion in lane.Minions do
		if minion.Team == hero.Team and minion.Lane == laneName and Combat.Alive(minion) then
			local progress = project(points, Combat.Position(minion))
			if progress > frontProgress then
				front, frontProgress = minion, progress
			end
		end
	end
	local goal
	if front then
		goal = pointAt(points, frontProgress - (if hero.Ranged then 10 else 4))
	else
		local safest = 30
		for _, tower in lane.Towers do
			if tower.Team == hero.Team and tower.Lane == laneName and not tower.Dead then
				safest = math.max(safest, (project(points, tower.Home)))
			end
		end
		goal = pointAt(points, safest - 6)
	end
	-- Farmen: das schwaechste Minion in Reichweite (letzter Treffer gibt Gold)
	local reach = hero.Range + 6
	local weakest
	for _, minion in Combat:EnemiesNear(hero.Team, position, reach, MINIONS) do
		if Combat.Visible(minion, hero.Team) and (not weakest or minion.HP < weakest.HP) then
			weakest = minion
		end
	end
	local enemyMinions = Combat:EnemiesNear(hero.Team, position, 22, MINIONS)
	if #enemyMinions >= 3 and hero.Mana > hero.MaxMana * 0.6 then
		tryAbilities(self, hero, enemyMinions[1], #enemyMinions)
	end
	hero.Focus = weakest
	-- Gegnerische Gebaeude einreissen, wenn Minions vorne sind
	local structure = Combat:NearestEnemy(hero.Team, position, hero.Range + 12, Combat.STRUCTURES)
	if structure and not structure.Protected and #Combat:AlliesNear(hero.Team, structure.Home, structure.Range + 2, MINIONS) >= 2 and not weakest then
		hero.Focus = structure
		goal = structure.Home + (position - structure.Home).Unit * (hero.Range + structure.Radius)
	end
	if weakest and not Combat:InRange(hero, weakest) then
		goal = Combat.Position(weakest)
	end
	if not isSafe(self, hero, goal) then
		goal = pointAt(points, project(points, goal) - 22)
		if hero.Focus and hero.Focus.Kind == "Minion" and not isSafe(self, hero, Combat.Position(hero.Focus)) then
			hero.Focus = nil
		end
	end
	goal += Vector3.new(math.sin(hero.Id * 1.7) * 3, 0, math.cos(hero.Id * 1.3) * 3)
	if (goal - position).Magnitude > 2.5 and not (hero.Focus and Combat:InRange(hero, hero.Focus)) then
		moveTo(self, hero, goal)
	else
		hold(hero)
	end
end

local function supportThink(self, hero)
	local carry
	for _, other in self.Services.HeroService.Heroes do
		if other.Team == hero.Team and other.Role == "Bot" and Combat.Alive(other) then
			carry = other
		end
	end
	if not carry then
		laneThink(self, hero, "Bot")
		return
	end
	local position = Combat.Position(hero)
	local carryPosition = Combat.Position(carry)
	local points = Config.LanePoints("Bot", hero.Team)
	local _, _, _, offLane = project(points, carryPosition)
	if offLane > 30 then
		laneThink(self, hero, "Bot")
		return
	end
	-- Neben dem Schuetzen stehen, etwas weiter hinten
	local goal = pointAt(points, project(points, carryPosition) - 5) + Vector3.new(math.cos(hero.Id) * 4, 0, math.sin(hero.Id) * 4)
	hero.Focus = nil
	tryAbilities(self, hero, nil, 0)
	if (goal - position).Magnitude > 3 then
		moveTo(self, hero, goal)
	else
		hold(hero)
	end
	maybeWard(self, hero)
end

local function nextCamp(self, hero)
	local jungle = self.Services.JungleService
	local position = Combat.Position(hero)
	local best, bestScore = nil, math.huge
	for name, camp in jungle.Camps do
		if camp.Alive > 0 then
			local own = string.sub(name, -1) == tostring(hero.Team)
			local river = string.sub(name, 1, 7) == "Scuttle"
			if own or river then
				local score = (camp.Position - position).Magnitude + (if river then 30 else 0)
				if score < bestScore then
					best, bestScore = camp, score
				end
			end
		end
	end
	return best
end

local function jungleThink(self, hero)
	local position = Combat.Position(hero)
	-- Episches Ziel: Drache ab Stufe 6, Herold ab 5, Baron ab 11 mit genug Freunden
	for _, monster in epicMonsters(self) do
		local id = monster.MonsterId
		local ready = (id == "Drake" and hero.Level >= 6) or (id == "Herald" and hero.Level >= 5) or ((id == "Baron" or id == "Elder") and hero.Level >= 11 and alliesAlive(self, hero) >= 4)
		if ready and hero.HP > hero.MaxHP * 0.6 and not Combat:NearestEnemy(hero.Team, Combat.Position(monster), 40, HERO_ONLY) then
			fightMonster(self, hero, monster)
			return
		end
	end
	-- Ganken: angeschlagener Gegner in der Naehe einer Lane
	if hero.Level >= 3 and hero.HP > hero.MaxHP * 0.6 then
		for _, enemy in self.Services.HeroService.Heroes do
			if enemy.Team ~= hero.Team and Combat:Targetable(enemy, hero.Team) and enemy.HP < enemy.MaxHP * 0.5 then
				local distance = Combat.Distance(hero, enemy)
				if distance < 70 and isSafe(self, hero, Combat.Position(enemy)) then
					hero.Focus = enemy
					moveTo(self, hero, Combat.Position(enemy))
					return
				end
			end
		end
	end
	local camp = nextCamp(self, hero)
	if not camp then
		laneThink(self, hero, "Mid")
		return
	end
	if (camp.Position - position).Magnitude > 16 then
		hero.Focus = nil
		moveTo(self, hero, camp.Position)
		return
	end
	-- Das groesste Monster im Lager zuerst
	local target
	for _, monster in self.Services.JungleService.Monsters do
		if monster.Camp == camp.Name and Combat.Alive(monster) and (not target or monster.MaxHP > target.MaxHP) then
			target = monster
		end
	end
	if target then
		fightMonster(self, hero, target)
	else
		hold(hero)
	end
	maybeWard(self, hero)
end

---------------------------------------------------------------- Entscheidungen

function BotService:Think(hero)
	local heroes = self.Services.HeroService
	if not Combat.Alive(hero) or Combat.IsStunned(hero) then
		return
	end
	local b = brain(hero)
	local position = Combat.Position(hero)
	local ratio = hero.HP / hero.MaxHP
	local fountain = MAP.Fountain[hero.Team]
	local enemyHero = Combat:NearestEnemy(hero.Team, position, 30, HERO_ONLY)
	useSpells(self, hero, enemyHero)

	-- 1. Zurueckziehen und nach Hause teleportieren
	if ratio < 0.3 or (hero.MaxMana > 100 and hero.Mana < 40 and ratio < 0.6) then
		b.Retreating = true
	end
	local shopping = hero.Gold >= 1300 and not enemyHero and not heroes:InFountain(hero) and now() - (hero.LastDamagedAt or 0) > 4
	if shopping then
		b.Retreating = true
	end
	if b.Retreating then
		hero.Focus = nil
		if heroes:InFountain(hero) then
			if ratio >= 0.95 and hero.Mana >= hero.MaxMana * 0.9 then
				b.Retreating = false
				-- Toplaner teleportieren zurueck in die Lane
				local tp = spellReady(hero, "Teleport")
				if tp and hero.Lane ~= "Jungle" then
					local tower = nil
					for _, unit in self.Services.LaneService.Towers do
						if unit.Team == hero.Team and unit.Lane == hero.Lane and not unit.Dead and (not tower or unit.Tier < tower.Tier) then
							tower = unit
						end
					end
					if tower then
						heroes:CastSpell(hero, tp, tower.Home)
					end
				end
			end
			hold(hero)
			return
		end
		if hero.RecallUntil then
			hold(hero)
			return
		end
		if not Combat:NearestEnemy(hero.Team, position, 34, HERO_ONLY) and now() - (hero.LastDamagedAt or 0) > 2 then
			hold(hero)
			heroes:Recall(hero)
			return
		end
		moveTo(self, hero, fountain)
		return
	end
	if hero.RecallUntil or hero.Teleporting then
		return
	end
	if heroes:InFountain(hero) and ratio < 0.9 then
		hold(hero)
		return
	end

	-- 2. Kaempfen
	if enemyHero then
		local enemyRatio = enemyHero.HP / enemyHero.MaxHP
		local target = Combat.Position(enemyHero)
		local brave = ratio >= 0.45 or ratio > enemyRatio + 0.2
		local dive = enemyRatio < 0.2 and ratio > 0.6
		if brave and (isSafe(self, hero, target) or dive) then
			hero.Focus = enemyHero
			tryAbilities(self, hero, enemyHero, 1)
			useSpells(self, hero, enemyHero)
			local distance = (target - position).Magnitude
			if distance > hero.Range + 1 then
				moveTo(self, hero, target)
			elseif hero.Ranged and distance < hero.Range * 0.5 then
				moveTo(self, hero, position + (position - target).Unit * 5)
			else
				hold(hero)
			end
			return
		end
		if not brave and (Combat.Position(enemyHero) - position).Magnitude < 18 then
			-- Abstand halten
			hero.Focus = nil
			moveTo(self, hero, position + (position - target).Unit * 10)
			return
		end
	end

	-- 3. Teamkampf um Drachen oder Baron
	local objective = objectiveCall(self, hero)
	if objective and hero.Role ~= "Jungle" then
		fightMonster(self, hero, objective)
		return
	end

	-- 4. Rolle spielen
	if hero.Role == "Jungle" then
		jungleThink(self, hero)
	elseif hero.Role == "Support" then
		supportThink(self, hero)
	else
		laneThink(self, hero, hero.Lane)
		if hero.Role ~= "Bot" and math.random() < 0.05 then
			maybeWard(self, hero)
		end
	end
end

function BotService:Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			if self.Services.MatchService:IsPlaying() then
				for _, hero in table.clone(self.Services.HeroService.Heroes) do
					if hero.Bot and not hero.Removed then
						local ok, err = pcall(self.Think, self, hero)
						if not ok then
							warn("[Bot]", err)
						end
					end
				end
			end
		end
	end)
end

return BotService
