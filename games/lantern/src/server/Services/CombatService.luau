-- Angriffe und Faehigkeiten der Spieler. Der Server prueft Abklingzeit, Reichweite und Ziel,
-- berechnet den Schaden und schickt den Clients nur die Effekte zum Anzeigen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = { Services = nil :: any }

local ready = {} -- [Player] = { Attack = os.clock(), [1] = ..., [2] = ... }
local rng = Random.new()

function CombatService:Init(services)
	self.Services = services
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function classOf(player: Player)
	local data = CombatService.Services.DataService:Get(player)
	return Config.Classes[data and data.Class or "Knight"] or Config.Classes.Knight
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function monstersNear(run, center: Vector3, radius: number)
	local list = {}
	for _, state in CombatService.Services.MonsterService:ForRun(run) do
		if (flat(state.Root.Position) - flat(center)).Magnitude <= radius + state.Def.Size * 1.2 then
			table.insert(list, state)
		end
	end
	return list
end

local function nearest(run, center: Vector3, range: number)
	local best, bestDistance = nil, range
	for _, state in CombatService.Services.MonsterService:ForRun(run) do
		local d = (flat(state.Root.Position) - flat(center)).Magnitude - state.Def.Size
		if d < bestDistance then
			best, bestDistance = state, d
		end
	end
	return best
end

---------------------------------------------------------------- Schaden

-- procs = false fuer Folgeschaden (Explosion, Blitz), damit sich nichts endlos ausloest
function CombatService:DealDamage(player: Player, state, base: number, procs: boolean?)
	if not state.Alive then
		return
	end
	local stats = self.Services.HeroService:GetStats(player)
	local amount = base * rng:NextNumber(0.9, 1.1)
	if stats.Powers.Giantslayer and (state.Boss or state.Elite) then
		amount *= 1.4
	end
	local crit = rng:NextNumber() * 100 < stats.Crit
	if crit then
		amount *= 1 + stats.CritDamage / 100
	end
	local position = state.Root.Position
	local run = state.Run
	self.Services.MonsterService:Damage(state, amount, player, crit)
	if procs == false then
		return
	end
	if stats.Powers.TwinStrike and state.Alive and rng:NextNumber() < 0.15 then
		self.Services.MonsterService:Damage(state, amount, player, crit)
	end
	if stats.Powers.ChainSpark and rng:NextNumber() < 0.2 then
		local zapped = 0
		for _, other in monstersNear(run, position, 14) do
			if other ~= state and zapped < 2 then
				zapped += 1
				self.Services.Net.SendEffect(run.Players, "Zap", { From = position, To = other.Root.Position })
				self:DealDamage(player, other, base * 0.5, false)
			end
		end
	end
end

-- Aufgerufen vom DungeonService, wenn dieser Spieler den letzten Treffer gesetzt hat
function CombatService:OnKill(player: Player, state, position: Vector3)
	local stats = self.Services.HeroService:GetStats(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local heal = stats.LifeOnKill
	if stats.Powers.Vampiric and humanoid then
		heal += humanoid.MaxHealth * 0.04
	end
	if heal > 0 then
		self.Services.HeroService:Heal(player, heal, false)
	end
	if stats.Powers.EmberBurst then
		local run = state.Run
		self.Services.Net.SendEffect(run.Players, "Nova", { Position = position, Radius = 10, Color = Color3.fromRGB(255, 130, 50) })
		for _, other in monstersNear(run, position, 10) do
			self:DealDamage(player, other, stats.Damage * 0.4, false)
		end
	end
end

---------------------------------------------------------------- Grundangriff

local function validTarget(player: Player, run, model: any, root: BasePart, range: number)
	local state = CombatService.Services.MonsterService:Get(model)
	if state and state.Alive and state.Run == run and (flat(state.Root.Position) - flat(root.Position)).Magnitude <= range + 6 + state.Def.Size * 2 then
		return state
	end
	return nil
end

function CombatService:Attack(player: Player, model: any)
	local run = self.Services.DungeonService:GetRun(player)
	local root = rootOf(player)
	if not run or not root then
		return
	end
	local class = classOf(player)
	local stats = self.Services.HeroService:GetStats(player)
	local attack = class.Attack
	local cooldown = attack.Cooldown / (1 + stats.AttackSpeed / 100)
	local now = os.clock()
	local timers = ready[player]
	if now < (timers.Attack or 0) then
		return
	end
	timers.Attack = now + cooldown * 0.8 -- etwas Spielraum fuer Ping
	local target = validTarget(player, run, model, root, class.Range) or nearest(run, root.Position, class.Range)
	if not target then
		return
	end
	local Net = self.Services.Net
	self.Services.HeroService:PlaySwing(player, "Slash")
	local damage = stats.Damage * attack.Mult
	if attack.Kind == "Cleave" then
		Net.SendEffect(run.Players, "Slash", { From = root.Position, To = target.Root.Position, Color = class.Color })
		for _, state in monstersNear(run, target.Root.Position, attack.Radius) do
			if (flat(state.Root.Position) - flat(root.Position)).Magnitude <= class.Range + attack.Radius then
				self:DealDamage(player, state, damage)
			end
		end
	elseif attack.Kind == "Shot" then
		Net.SendEffect(run.Players, "Arrow", { From = root.Position, To = target.Root.Position, Color = class.Color })
		self:DealDamage(player, target, damage)
	else
		Net.SendEffect(run.Players, "Bolt", { From = root.Position, To = target.Root.Position, Color = class.Color })
		local position = target.Root.Position
		self:DealDamage(player, target, damage)
		if attack.Splash then
			for _, state in monstersNear(run, position, attack.Splash) do
				if state ~= target then
					self:DealDamage(player, state, damage * attack.SplashMult, false)
				end
			end
		end
		if attack.Heal then
			-- Lichtbringer: heilt den verwundetsten Verbuendeten
			local lowest, ratio = nil, 1
			for _, entry in self.Services.MonsterService.AlivePlayers(run) do
				local humanoid = entry.Player.Character:FindFirstChildOfClass("Humanoid")
				local r = humanoid.Health / humanoid.MaxHealth
				if r < ratio then
					lowest, ratio = entry.Player, r
				end
			end
			if lowest then
				self.Services.HeroService:Heal(lowest, damage * attack.Heal, true)
			end
		end
	end
end

---------------------------------------------------------------- Faehigkeiten

local function partyNear(run, position: Vector3, radius: number)
	local list = {}
	for _, entry in CombatService.Services.MonsterService.AlivePlayers(run) do
		if (entry.Root.Position - position).Magnitude <= radius then
			table.insert(list, entry.Player)
		end
	end
	return list
end

function CombatService:Skill(player: Player, index: number, model: any)
	local run = self.Services.DungeonService:GetRun(player)
	local root = rootOf(player)
	if not run or not root then
		return false
	end
	local class = classOf(player)
	local skill = class.Skills[index]
	if not skill then
		return false
	end
	local stats = self.Services.HeroService:GetStats(player)
	local cooldown = skill.Cooldown * (1 - stats.Cooldown / 100)
	local now = os.clock()
	local timers = ready[player]
	if now < (timers[index] or 0) then
		return false
	end
	timers[index] = now + cooldown * 0.9
	local Net = self.Services.Net
	local damage = stats.Damage * skill.Mult
	self.Services.HeroService:PlaySwing(player, "Lunge")

	if skill.Kind == "Nova" then
		local position = root.Position
		Net.SendEffect(run.Players, "Nova", { Position = position, Radius = skill.Radius, Color = class.Color, Frost = skill.Slow ~= nil })
		for _, state in monstersNear(run, position, skill.Radius) do
			self:DealDamage(player, state, damage)
			if skill.Stun then
				self.Services.MonsterService:Stun(state, skill.Stun)
			end
			if skill.Slow then
				self.Services.MonsterService:Slow(state, skill.Slow)
			end
		end
		if skill.HealParty then
			for _, ally in partyNear(run, position, 40) do
				local humanoid = ally.Character:FindFirstChildOfClass("Humanoid")
				self.Services.HeroService:Heal(ally, humanoid.MaxHealth * skill.HealParty, true)
			end
		end
	elseif skill.Kind == "Spin" or skill.Kind == "Aura" then
		Net.SendEffect(run.Players, if skill.Kind == "Spin" then "Spin" else "Aura", { Character = player.Character, Radius = skill.Radius, Duration = skill.Ticks * skill.Interval, Color = class.Color })
		if skill.Shield then
			for _, ally in partyNear(run, root.Position, 30) do
				ally:SetAttribute("ShieldUntil", os.clock() + skill.Shield)
			end
		end
		task.spawn(function()
			for _ = 1, skill.Ticks do
				local current = rootOf(player)
				if not current or self.Services.DungeonService:GetRun(player) ~= run then
					break
				end
				for _, state in monstersNear(run, current.Position, skill.Radius) do
					self:DealDamage(player, state, damage)
				end
				task.wait(skill.Interval)
			end
		end)
	elseif skill.Kind == "Volley" then
		local targets = {}
		for _, state in self.Services.MonsterService:ForRun(run) do
			local d = (flat(state.Root.Position) - flat(root.Position)).Magnitude
			if d <= class.Range then
				table.insert(targets, { State = state, Distance = d })
			end
		end
		table.sort(targets, function(a, b)
			return a.Distance < b.Distance
		end)
		if #targets == 0 then
			timers[index] = now
			return false
		end
		for i = 1, math.min(skill.Count, #targets) do
			local state = targets[i].State
			Net.SendEffect(run.Players, "Arrow", { From = root.Position, To = state.Root.Position, Color = Color3.fromRGB(255, 230, 120) })
			self:DealDamage(player, state, damage)
		end
	elseif skill.Kind == "Rain" or skill.Kind == "Meteor" then
		local target = validTarget(player, run, model, root, class.Range) or nearest(run, root.Position, class.Range)
		local position = if target then target.Root.Position else root.Position + root.CFrame.LookVector * 14
		position = Vector3.new(position.X, run.FloorY, position.Z)
		if skill.Kind == "Meteor" then
			Net.SendEffect(run.Players, "Meteor", { Position = position, Radius = skill.Radius, Delay = skill.Delay })
			task.delay(skill.Delay, function()
				for _, state in monstersNear(run, position, skill.Radius) do
					self:DealDamage(player, state, damage)
				end
			end)
		else
			Net.SendEffect(run.Players, "Rain", { Position = position, Radius = skill.Radius, Duration = skill.Ticks * skill.Interval })
			task.spawn(function()
				for _ = 1, skill.Ticks do
					for _, state in monstersNear(run, position, skill.Radius) do
						self:DealDamage(player, state, damage)
					end
					task.wait(skill.Interval)
				end
			end)
		end
	end
	return true, cooldown
end

function CombatService:Start()
	local Net = self.Services.Net
	Net.Attack.OnServerEvent:Connect(function(player, model)
		local ok, err = pcall(self.Attack, self, player, model)
		if not ok then
			warn("[Combat] Angriff", err)
		end
	end)
	Net.Skill.OnServerEvent:Connect(function(player, index, model)
		if typeof(index) ~= "number" then
			return
		end
		local ok, err = pcall(self.Skill, self, player, math.floor(index), model)
		if not ok then
			warn("[Combat] Faehigkeit", err)
		end
	end)
end

function CombatService:OnPlayerReady(player: Player)
	ready[player] = {}
end

function CombatService:OnPlayerRemoving(player: Player)
	ready[player] = nil
end

return CombatService
