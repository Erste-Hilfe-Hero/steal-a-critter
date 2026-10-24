-- Bot-KI: fuellt leere Plaetze, damit man auch allein sofort eine volle 5-gegen-5-Runde spielt.
-- Einfache Zustandsmaschine: zurueckziehen, kaempfen, Lane halten.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BotService = { Services = nil :: any }

local MAP = Config.Map
local TICK = 0.25
local HERO_ONLY = { Hero = true }
local MINIONS = { Minion = true }
local STRUCTURES = { Tower = true, Core = true }

BotService.Names = { "Nova", "Blaze", "Echo", "Pixel", "Ziggy", "Mochi", "Rex", "Luna", "Comet", "Pebble", "Juno", "Taro" }
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

-- Naechster Wegpunkt auf dem Weg entlang der Lane (statt quer durch den Dschungel)
local function routeTo(points, from: Vector3, goal: Vector3): Vector3
	local fromProgress, segment, _, offLane = project(points, from)
	local goalProgress = project(points, goal)
	if offLane > 30 then
		-- Weit weg von der Lane (z. B. am Brunnen): erst zum naechsten Lane-Punkt
		local _, _, nearest = project(points, from)
		if (goal - from).Magnitude < (nearest - from).Magnitude then
			return goal
		end
		return nearest
	end
	if math.abs(goalProgress - fromProgress) < 12 then
		return goal
	end
	if goalProgress > fromProgress then
		local nextPoint = points[segment + 1]
		return if (nextPoint - from).Magnitude < 4 and points[segment + 2] then points[segment + 2] else nextPoint
	else
		local previous = points[segment]
		return if (previous - from).Magnitude < 4 and points[segment - 1] then points[segment - 1] else previous
	end
end

---------------------------------------------------------------- Gefahr durch Tuerme

local function enemyStructures(self, team: number)
	local lane = self.Services.LaneService
	local result = {}
	for _, tower in lane.Towers do
		if tower.Team ~= team and not tower.Dead then
			table.insert(result, tower)
		end
	end
	local core = lane.Cores[if team == 1 then 2 else 1]
	if core and not core.Dead then
		table.insert(result, core)
	end
	return result
end

-- Ein Punkt ist sicher, wenn kein feindlicher Turm ihn trifft oder eigene Minions den Turm beschaeftigen
local function isSafe(self, hero, point: Vector3): boolean
	for _, structure in enemyStructures(self, hero.Team) do
		if (point - structure.Home).Magnitude <= structure.Range + 4 then
			local tanks = Combat:AlliesNear(hero.Team, structure.Home, structure.Range, MINIONS)
			if #tanks < 2 or structure.Target == hero then
				return false
			end
		end
	end
	return true
end

---------------------------------------------------------------- Bewegung

local function moveTo(hero, goal: Vector3)
	local humanoid = hero.Humanoid
	if not humanoid then
		return
	end
	local position = Combat.Position(hero)
	-- Steckt fest: springen und seitlich ausweichen
	if hero.LastPosition and (position - hero.LastPosition).Magnitude < 0.4 and (goal - position).Magnitude > 3 and humanoid.WalkSpeed > 0 then
		hero.Stuck = (hero.Stuck or 0) + 1
	else
		hero.Stuck = 0
	end
	hero.LastPosition = position
	if (hero.Stuck or 0) >= 4 then
		humanoid.Jump = true
		local side = (goal - position).Unit:Cross(Vector3.yAxis) * (if math.random() < 0.5 then -8 else 8)
		humanoid:MoveTo(position + side)
		hero.Stuck = 0
		return
	end
	humanoid:MoveTo(Vector3.new(goal.X, 3, goal.Z))
end

local function hold(hero)
	if hero.Humanoid then
		local position = Combat.Position(hero)
		hero.Humanoid:MoveTo(Vector3.new(position.X, 3, position.Z))
	end
	hero.LastPosition = nil
end

---------------------------------------------------------------- Entscheidungen

local function tryAbilities(self, hero, target, crowd: number)
	local heroes = self.Services.HeroService
	local position = Combat.Position(hero)
	local t = now()
	for _, key in Config.AbilityKeys do
		local ability = hero.Def.Abilities[key]
		if (hero.Cooldowns[key] or 0) <= t and math.random() < 0.6 then
			local kind = ability.Type
			local reach = ability.Range or ability.Length or ability.Radius or 10
			local distance = if target then (Combat.Position(target) - position).Magnitude else math.huge
			local useful = false
			if kind == "Shield" then
				useful = target ~= nil and hero.HP < hero.MaxHP * 0.8
			elseif kind == "Heal" then
				useful = hero.HP < hero.MaxHP * 0.7
				for _, ally in Combat:AlliesNear(hero.Team, position, ability.Radius, HERO_ONLY) do
					if ally.HP < ally.MaxHP * 0.6 then
						useful = true
					end
				end
			elseif kind == "Buff" then
				useful = target ~= nil and distance <= hero.Range + 6
			elseif kind == "Circle" then
				useful = target ~= nil and distance <= ability.Radius
			elseif kind == "Dash" and not ability.ToTarget and (ability.Damage or 0) == 0 then
				useful = false -- Ausweich-Sprung nutzen Bots nicht
			else
				useful = target ~= nil and distance <= reach
			end
			-- Ultimates nur gegen Helden oder grosse Gruppen
			if useful and key == "R" and (target == nil or (target.Kind ~= "Hero" and crowd < 4)) then
				useful = false
			end
			if useful then
				heroes:Cast(hero, key, if target then Combat.Position(target) else nil)
				return
			end
		end
	end
end

function BotService:Think(hero)
	local heroes = self.Services.HeroService
	if not Combat.Alive(hero) or Combat.IsStunned(hero) then
		return
	end
	local position = Combat.Position(hero)
	local ratio = hero.HP / hero.MaxHP
	local fountain = MAP.Fountain[hero.Team]
	local points = self.Services.LaneService.LanePoints(hero.Lane or "Mid", hero.Team)
	local enemyHero = Combat:NearestEnemy(hero.Team, position, 26, HERO_ONLY)

	-- 1. Zurueckziehen
	if ratio < 0.3 then
		hero.Retreating = true
	end
	if hero.Retreating then
		if heroes:InFountain(hero) then
			if ratio >= 0.95 then
				hero.Retreating = false
			end
			hold(hero)
			return
		end
		if hero.RecallUntil then
			hold(hero)
			return
		end
		if not Combat:NearestEnemy(hero.Team, position, 30, HERO_ONLY) then
			hold(hero)
			heroes:Recall(hero)
			return
		end
		hero.Focus = nil
		local _, _, _, offLane = project(points, position)
		local home = offLane > 30 or (position - points[1]).Magnitude < 8
		moveTo(hero, if home then fountain else routeTo(points, position, points[1]))
		return
	end
	if hero.RecallUntil then
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
			local distance = (target - position).Magnitude
			if distance > hero.Range + 1 then
				moveTo(hero, target)
			elseif hero.Ranged and distance < hero.Range * 0.5 then
				moveTo(hero, position + (position - target).Unit * 5)
			else
				hold(hero)
			end
			return
		end
	end
	hero.Focus = nil

	-- 3. Lane halten: knapp hinter den eigenen Minions stehen
	local lane = self.Services.LaneService
	local front, frontProgress = nil, -math.huge
	for _, minion in lane.Minions do
		if minion.Team == hero.Team and minion.Lane == hero.Lane and Combat.Alive(minion) then
			local progress = project(points, Combat.Position(minion))
			if progress > frontProgress then
				front, frontProgress = minion, progress
			end
		end
	end
	local goal
	if front then
		goal = pointAt(points, frontProgress - (if hero.Ranged then 9 else 4))
	else
		-- Keine Minions: vor dem eigenen vordersten Turm warten
		local safest = 30
		for _, tower in lane.Towers do
			if tower.Team == hero.Team and tower.Lane == hero.Lane and not tower.Dead then
				safest = math.max(safest, (project(points, tower.Home)))
			end
		end
		goal = pointAt(points, safest - 6)
	end
	-- Gegnerische Tuerme einreissen, wenn Minions vorne sind
	local enemyMinions = Combat:EnemiesNear(hero.Team, position, 20, MINIONS)
	if #enemyMinions >= 3 then
		tryAbilities(self, hero, enemyMinions[1], #enemyMinions)
	end
	local structure = Combat:NearestEnemy(hero.Team, position, hero.Range + 8, STRUCTURES)
	if structure and #Combat:AlliesNear(hero.Team, structure.Home, structure.Range, MINIONS) >= 2 then
		hero.Focus = structure
		goal = structure.Home + (position - structure.Home).Unit * (hero.Range + structure.Radius)
	end
	if not isSafe(self, hero, goal) then
		goal = pointAt(points, project(points, goal) - 22)
	end
	goal += Vector3.new(math.sin(hero.Id * 1.7) * 3, 0, math.cos(hero.Id * 1.3) * 3)
	if (goal - position).Magnitude > 2.5 then
		moveTo(hero, routeTo(points, position, goal))
	else
		hold(hero)
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
