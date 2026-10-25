-- Dschungel: Lager mit mehreren Monstern, Blau- und Rot-Buff, Fluss-Krabben, Elementar-Drachen mit Seele,
-- Aelterer Drache, Belagerungs-Herold und der Abgrund-Tyrann (Baron). Inklusive Monster-KI mit Leine.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local JungleService = {
	Services = nil :: any,
	Monsters = {} :: { any },
	Camps = {} :: { [string]: any },
	Drakes = { [1] = {}, [2] = {} } :: { [number]: { string } },
	Soul = {} :: { [number]: string },
	NextDrake = "Infernal",
	Epoch = 0,
	Running = false,
}

local MAP = Config.Map
local TICK = 0.1

local Combat

function JungleService:Init(services)
	self.Services = services
	Combat = services.CombatService
	Combat.DeathHandlers.Monster = function(unit, killer)
		self:OnMonsterDeath(unit, killer)
	end
end

local function elapsed(): number
	return JungleService.Services.MatchService:Elapsed()
end

local function state(): Folder
	return ReplicatedStorage:FindFirstChild("Match") :: Folder
end

---------------------------------------------------------------- Aufbau

function JungleService:Clear()
	self.Epoch += 1
	self.Running = false
	for _, monster in self.Monsters do
		Combat:Unregister(monster)
		if monster.Model then
			monster.Model:Destroy()
		end
	end
	self.Monsters = {}
	self.Camps = {}
	self.Drakes = { [1] = {}, [2] = {} }
	self.Soul = {}
	self:PickNextDrake()
	self:Publish()
end

function JungleService:PickNextDrake()
	local options = {}
	for _, drake in Config.Drakes do
		if drake.Id ~= self.NextDrake then
			table.insert(options, drake.Id)
		end
	end
	self.NextDrake = options[math.random(1, #options)]
end

function JungleService:Publish()
	local folder = state()
	if not folder then
		return
	end
	folder:SetAttribute("Drakes1", table.concat(self.Drakes[1], ","))
	folder:SetAttribute("Drakes2", table.concat(self.Drakes[2], ","))
	folder:SetAttribute("Soul1", self.Soul[1] or "")
	folder:SetAttribute("Soul2", self.Soul[2] or "")
	folder:SetAttribute("NextDrake", self.NextDrake)
end

local function setTimer(name: string, at: number)
	local folder = state()
	if folder then
		folder:SetAttribute(name .. "At", at)
	end
end

function JungleService:SpawnMonster(id: string, position: Vector3, camp: string, color: Color3?)
	local info = Config.Monsters[id]
	local model = self.Services.WorldService:MakeMonster(id, position, color)
	local scale = 1 + math.max(0, elapsed() - 300) / 60 * 0.04
	local hp = info.HP * (if info.Epic then scale else 1 + (scale - 1) * 0.5)
	local unit = Combat:Register({
		Kind = "Monster",
		MonsterId = id,
		Camp = camp,
		Name = info.Name,
		Team = 0,
		Epic = info.Epic,
		Passive = info.Passive,
		Model = model,
		Home = position,
		HP = hp,
		MaxHP = hp,
		Armor = info.Armor,
		MR = info.MR,
		Damage = info.Damage * scale,
		Range = info.Range,
		AttackSpeed = info.AttackSpeed,
		Speed = if info.Passive then 14 else 16,
		Gold = info.Gold,
		XP = info.XP,
		Ranged = info.Range > 10,
		FxColor = color or info.Color,
		Radius = math.max(1.5, (info.Size or 4) * 0.5),
		Height = model.PrimaryPart.Position.Y,
	})
	model:SetAttribute("Boss", info.Epic == true)
	model:SetAttribute("MonsterId", id)
	table.insert(self.Monsters, unit)
	return unit
end

-- Ein Lager mit allen seinen Monstern
function JungleService:SpawnCamp(name: string, position: Vector3, monsters: { string }, color: Color3?)
	local camp = { Name = name, Position = position, Alive = 0 }
	self.Camps[name] = camp
	for index, id in monsters do
		local offset = if index == 1 then Vector3.zero else Vector3.new(math.cos(index * 2.2) * 5, 0, math.sin(index * 2.2) * 5)
		self:SpawnMonster(id, position + offset, name, color)
		camp.Alive += 1
	end
	if self.Services.MatchService:IsPlaying() then
		local folder = state()
		if folder then
			folder:SetAttribute("Camp_" .. name, 0)
		end
	end
end

function JungleService:Schedule(delay: number, fn: () -> ())
	local epoch = self.Epoch
	task.delay(math.max(0, delay), function()
		if self.Epoch == epoch and self.Running then
			fn()
		end
	end)
end

function JungleService:ScheduleCamp(name: string, position: Vector3, monsters: { string }, delay: number)
	local folder = state()
	if folder then
		folder:SetAttribute("Camp_" .. name, workspace:GetServerTimeNow() + delay)
	end
	self:Schedule(delay, function()
		self:SpawnCamp(name, position, monsters)
	end)
end

function JungleService:SpawnDrake()
	local kind = if self.Soul[1] or self.Soul[2] then "Elder" else self.NextDrake
	if kind == "Elder" then
		self:SpawnCamp("Dragon", MAP.DragonPit, { "Elder" })
		self.Services.Net.SendAnnounce("The Elder Drake has spawned!", Config.Monsters.Elder.Color)
	else
		local drake = Config.DrakesById[kind]
		self:SpawnCamp("Dragon", MAP.DragonPit, { "Drake" }, drake.Color)
		local monster = self.Monsters[#self.Monsters]
		monster.DrakeType = kind
		monster.Name = drake.Name
		monster.Model.Name = drake.Name
		monster.Model:SetAttribute("UnitName", drake.Name)
		self.Services.Net.SendAnnounce(`The {drake.Name} has spawned!`, drake.Color)
	end
	setTimer("Drake", 0)
end

function JungleService:StartMatch()
	self.Running = true
	local start = workspace:GetServerTimeNow() - elapsed()
	local function at(seconds: number): number
		return math.max(0, start + seconds - workspace:GetServerTimeNow())
	end
	for team = 1, 2 do
		for _, camp in MAP.Camps do
			local name = camp.Id .. team
			self:ScheduleCamp(name, Config.Mirror(camp.Position, team), camp.Monsters, at(Config.Timers.Jungle))
		end
	end
	for _, camp in MAP.River do
		self:ScheduleCamp(camp.Id, camp.Position, camp.Monsters, at(Config.Timers.Scuttle))
	end
	setTimer("Drake", start + Config.Timers.Drake)
	self:Schedule(at(Config.Timers.Drake), function()
		self:SpawnDrake()
	end)
	setTimer("Herald", start + Config.Timers.Herald)
	self:Schedule(at(Config.Timers.Herald), function()
		if elapsed() < Config.Timers.HeraldDespawn then
			self:SpawnCamp("Baron", MAP.BaronPit, { "Herald" })
			self.Services.Net.SendAnnounce("The Siege Herald has spawned!", Config.Monsters.Herald.Color)
			setTimer("Herald", 0)
		end
	end)
	setTimer("Baron", start + Config.Timers.Baron)
	self:Schedule(at(Config.Timers.HeraldDespawn), function()
		-- Herold verschwindet, wenn er noch lebt
		for _, monster in table.clone(self.Monsters) do
			if monster.MonsterId == "Herald" and not monster.Dead then
				self:RemoveMonster(monster)
			end
		end
		setTimer("Herald", 0)
	end)
	self:Schedule(at(Config.Timers.Baron), function()
		self:SpawnCamp("Baron", MAP.BaronPit, { "Baron" })
		self.Services.Net.SendAnnounce("The Abyss Tyrant has awakened!", Config.Monsters.Baron.Color)
		setTimer("Baron", 0)
	end)
end

function JungleService:Stop()
	self.Running = false
end

function JungleService:RemoveMonster(monster)
	local index = table.find(self.Monsters, monster)
	if index then
		table.remove(self.Monsters, index)
	end
	Combat:Unregister(monster)
	if monster.Model then
		monster.Model:Destroy()
	end
	local camp = self.Camps[monster.Camp]
	if camp then
		camp.Alive -= 1
	end
end

---------------------------------------------------------------- Belohnungen

local function teamHeroes(team: number)
	local list = {}
	for _, hero in JungleService.Services.HeroService.Heroes do
		if hero.Team == team then
			table.insert(list, hero)
		end
	end
	return list
end

-- Wer bekommt den Kill? Bei Monstern zaehlt der letzte Held, der Schaden gemacht hat
local function creditHero(unit, killer)
	if killer and killer.Kind == "Hero" then
		return killer
	end
	local best, latest = nil, 0
	for hero, time in unit.Damagers do
		if time > latest then
			best, latest = hero, time
		end
	end
	return best
end

function JungleService:OnMonsterDeath(unit, killer)
	local index = table.find(self.Monsters, unit)
	if index then
		table.remove(self.Monsters, index)
	end
	local heroes = self.Services.HeroService
	local net = self.Services.Net
	local position = Combat.Position(unit)
	local info = Config.Monsters[unit.MonsterId]
	Combat:Unregister(unit)
	if unit.Model then
		net.SendFx("Poof", { At = position, Color = unit.FxColor })
		local model = unit.Model
		task.delay(0.15, function()
			model:Destroy()
		end)
	end
	local hero = creditHero(unit, killer)
	local team = hero and hero.Team or 0
	local camp = self.Camps[unit.Camp]
	if camp then
		camp.Alive -= 1
	end

	if team ~= 0 then
		if info.Epic then
			for _, member in teamHeroes(team) do
				heroes:GiveGold(member, info.Gold, if member == hero then position else nil)
				-- Fuer Quests und Erfolge: Helfer in der Naehe zaehlen mit
				if member == hero or (Combat.Alive(member) and (Combat.Position(member) - position).Magnitude <= 70) then
					member.EpicTakedowns = (member.EpicTakedowns or 0) + 1
				end
			end
			heroes:ShareXP(team, position, info.XP, true)
		else
			heroes:GiveGold(hero, info.Gold, position)
			heroes:AddXP(hero, info.XP * Config.XPMultiplier)
			hero.CreepScore = (hero.CreepScore or 0) + 1
			hero.MonsterKills = (hero.MonsterKills or 0) + 1
		end
		heroes:OnUnitKilled(hero, unit)
		local teamName = Config.Teams[team].Name
		local color = Config.Teams[team].Color
		if info.Buff then
			heroes:GiveBuff(hero, info.Buff)
		end
		if unit.MonsterId == "Drake" then
			local drake = Config.DrakesById[unit.DrakeType]
			table.insert(self.Drakes[team], drake.Id)
			net.SendAnnounce(`{teamName} slew the {drake.Name}!`, color)
			if #self.Drakes[team] >= Config.DrakeSoul and not self.Soul[team] then
				self.Soul[team] = drake.Id
				net.SendAnnounce(`{teamName} claimed the {drake.Name} Soul!`, color)
			end
			self:PickNextDrake()
			self:Publish()
			heroes:RefreshTeam(team)
		elseif unit.MonsterId == "Elder" then
			net.SendAnnounce(`{teamName} slew the Elder Drake!`, color)
			for _, member in teamHeroes(team) do
				if Combat.Alive(member) then
					heroes:GiveBuff(member, "Elder")
				end
			end
		elseif unit.MonsterId == "Baron" then
			net.SendAnnounce(`{teamName} slew the Abyss Tyrant!`, color)
			for _, member in teamHeroes(team) do
				if Combat.Alive(member) then
					heroes:GiveBuff(member, "Baron")
				end
			end
		elseif unit.MonsterId == "Herald" then
			net.SendAnnounce(`{teamName} slew the Siege Herald!`, color)
			self.Services.LaneService:SpawnHerald(team, position)
		end
	end

	-- Neu erscheinen lassen
	if unit.MonsterId == "Drake" or unit.MonsterId == "Elder" then
		local delay = if self.Soul[1] or self.Soul[2] then Config.Timers.Elder else Config.Timers.DrakeRespawn
		setTimer("Drake", workspace:GetServerTimeNow() + delay)
		self:Schedule(delay, function()
			self:SpawnDrake()
		end)
	elseif unit.MonsterId == "Baron" then
		setTimer("Baron", workspace:GetServerTimeNow() + Config.Timers.BaronRespawn)
		self:Schedule(Config.Timers.BaronRespawn, function()
			self:SpawnCamp("Baron", MAP.BaronPit, { "Baron" })
			self.Services.Net.SendAnnounce("The Abyss Tyrant has awakened!", Config.Monsters.Baron.Color)
			setTimer("Baron", 0)
		end)
	elseif unit.MonsterId == "Herald" then
		setTimer("Herald", 0)
	elseif camp and camp.Alive <= 0 then
		local template
		for team2 = 1, 2 do
			for _, entry in MAP.Camps do
				if entry.Id .. team2 == camp.Name then
					template = entry
				end
			end
		end
		for _, entry in MAP.River do
			if entry.Id == camp.Name then
				template = entry
			end
		end
		if template then
			self:ScheduleCamp(camp.Name, camp.Position, template.Monsters, info.Respawn or 70)
		end
	end
end

---------------------------------------------------------------- KI

local function campMates(self, unit)
	local list = {}
	for _, other in self.Monsters do
		if other.Camp == unit.Camp then
			table.insert(list, other)
		end
	end
	return list
end

local function monsterTick(self, unit, dt: number)
	if not Combat.Alive(unit) or Combat.IsStunned(unit) then
		return
	end
	local lane = self.Services.LaneService
	local leash = if unit.Epic then Config.LeashRange + 10 else Config.LeashRange
	local target = unit.Target
	local attacker = unit.LastAttacker
	if not target and attacker and attacker.Kind == "Hero" and Combat:Targetable(attacker) and not unit.Returning then
		target = attacker
		-- Das ganze Lager greift an
		for _, mate in campMates(self, unit) do
			if not mate.Target then
				mate.Target = attacker
			end
		end
		unit.Target = attacker
	end
	if target then
		local tooFar = (Combat.Position(target) - unit.Home).Magnitude > leash or (Combat.Position(unit) - unit.Home).Magnitude > leash
		if not Combat:Targetable(target) or tooFar then
			-- Zurueck nach Hause und voll heilen
			unit.Target = nil
			unit.LastAttacker = nil
			unit.Returning = true
			target = nil
		end
	end
	if unit.Returning then
		lane.MoveUnit(unit, unit.Home, dt * 1.6)
		unit.HP = math.min(unit.MaxHP, unit.HP + unit.MaxHP * 0.25 * dt)
		Combat:Sync(unit)
		if (Combat.Position(unit) - unit.Home).Magnitude < 1 then
			unit.Returning = false
			unit.HP = unit.MaxHP
			unit.Damagers = {}
			Combat:Sync(unit)
		end
		return
	end
	if not target then
		return
	end
	if unit.Passive then
		-- Krabbe flieht nur
		local away = Combat.Position(unit) - Combat.Position(target)
		if away.Magnitude > 0.1 then
			lane.MoveUnit(unit, unit.Home + away.Unit * 8, dt)
		end
		return
	end
	if Combat:InRange(unit, target) then
		lane.Face(unit, target)
		if Combat:CanAttack(unit) then
			if unit.Epic then
				-- Grosse Monster treffen alles um das Ziel herum
				Combat:Attack(unit, target, function(victim)
					for _, hero in Combat:EnemiesNear(0, Combat.Position(victim), 6, { Hero = true }) do
						Combat:Damage(unit, hero, unit.Damage, { Type = "Physical", OnHit = true })
					end
				end)
			else
				Combat:Attack(unit, target)
			end
		end
	else
		lane.MoveUnit(unit, Combat.Position(target), dt)
	end
end

function JungleService:Start()
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
		for _, monster in table.clone(self.Monsters) do
			monsterTick(self, monster, step)
		end
	end)
end

return JungleService
