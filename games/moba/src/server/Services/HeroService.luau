-- Helden (Spieler und Bots): Werte, Stufen, Gold, Items, Faehigkeiten, Auto-Angriff, Tod, Respawn, Rueckruf.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local HeroService = {
	Services = nil :: any,
	Heroes = {} :: { any },
	Might = {} :: { [number]: number }, -- [Team] = Ende des Titan-Segens
}

local MAP = Config.Map
local TICK = 0.1
local ENEMY_UNITS = { Hero = true, Minion = true, Monster = true }
local HERO_ONLY = { Hero = true }
local MINIONS = { Minion = true }
local STRUCTURES = { Tower = true, Core = true }
local MONSTERS = { Monster = true }
local GOLD_COLOR = Color3.fromRGB(255, 210, 70)

local Combat
local scoreboard: Folder

function HeroService:Init(services)
	self.Services = services
	Combat = services.CombatService
	Combat.DeathHandlers.Hero = function(unit, killer)
		self:OnDeath(unit, killer)
	end
	local match = ReplicatedStorage:FindFirstChild("Match") or Instance.new("Folder")
	match.Name = "Match"
	match.Parent = ReplicatedStorage
	scoreboard = Instance.new("Folder")
	scoreboard.Name = "Heroes"
	scoreboard.Parent = match
end

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------- Werte

function HeroService:Recompute(hero)
	local def = hero.Def
	local stats = def.Stats
	local level = hero.Level
	local bonus = { Power = 0, HP = 0, Armor = 0, AttackSpeed = 0, Speed = 0, Haste = 0, Lifesteal = 0, Regen = 0 }
	for _, id in hero.Items do
		local item = Config.ItemsById[id]
		for key, value in (item and item.Stats or {}) do
			bonus[key] += value
		end
	end
	local t = now()
	local buff = hero.Buff
	local buffActive = buff and buff.Until > t
	local power = stats.Power + stats.PowerPerLevel * (level - 1) + bonus.Power
	if (self.Might[hero.Team] or 0) > t then
		power *= 1 + Config.MightBuff.Power
	end
	local oldMax = hero.MaxHP or 0
	hero.MaxHP = stats.HP + stats.HPPerLevel * (level - 1) + bonus.HP
	if oldMax > 0 and hero.MaxHP > oldMax and not hero.Dead then
		hero.HP += hero.MaxHP - oldMax
	end
	hero.HP = math.min(hero.HP or hero.MaxHP, hero.MaxHP)
	hero.Damage = power
	hero.Armor = stats.Armor + stats.ArmorPerLevel * (level - 1) + bonus.Armor
	hero.AttackSpeed = stats.AttackSpeed * (1 + bonus.AttackSpeed + (if buffActive then buff.AttackSpeed or 0 else 0)) * (1 + 0.02 * (level - 1))
	hero.Range = stats.Range
	hero.Ranged = stats.Range > 12
	hero.Speed = (stats.Speed + bonus.Speed) * (1 + (if buffActive then buff.Speed or 0 else 0))
	hero.Haste = math.min(Config.MaxHaste, bonus.Haste)
	hero.Lifesteal = bonus.Lifesteal
	hero.Regen = 1.5 + level * 0.25 + bonus.Regen
	self:Publish(hero)
end

-- Werte fuer Anzeige: Spieler-Attribute (eigene UI) und Anzeigetafel (alle)
function HeroService:Publish(hero)
	local entry = hero.Entry
	if entry then
		entry:SetAttribute("Level", hero.Level)
		entry:SetAttribute("Kills", hero.Kills)
		entry:SetAttribute("Deaths", hero.Deaths)
		entry:SetAttribute("Assists", hero.Assists)
		entry:SetAttribute("Dead", hero.Dead)
		entry:SetAttribute("RespawnAt", hero.RespawnAt or 0)
		entry:SetAttribute("Items", table.concat(hero.Items, ","))
		entry:SetAttribute("CS", hero.CreepScore or 0)
	end
	if hero.Model then
		hero.Model:SetAttribute("Level", hero.Level)
		hero.Model:SetAttribute("Might", (self.Might[hero.Team] or 0) > now())
	end
	local player = hero.Player
	if player then
		player:SetAttribute("Level", hero.Level)
		player:SetAttribute("XP", math.floor(hero.XP))
		player:SetAttribute("XPNeed", if hero.Level >= Config.MaxLevel then 0 else Config.XPToLevel(hero.Level))
		player:SetAttribute("Gold", math.floor(hero.Gold))
		player:SetAttribute("Items", table.concat(hero.Items, ","))
		player:SetAttribute("Power", math.floor(hero.Damage))
		player:SetAttribute("Armor", math.floor(hero.Armor))
		player:SetAttribute("AttackSpeed", math.floor(hero.AttackSpeed * 100) / 100)
		player:SetAttribute("Haste", math.floor(hero.Haste * 100))
		player:SetAttribute("Dead", hero.Dead)
		player:SetAttribute("RespawnAt", hero.RespawnAt or 0)
		player:SetAttribute("Kills", hero.Kills)
		player:SetAttribute("Deaths", hero.Deaths)
		player:SetAttribute("Assists", hero.Assists)
		player:SetAttribute("CanShop", self:CanShop(hero))
	end
end

---------------------------------------------------------------- Erstellen und Spawnen

-- info: { Team, HeroId, Player?, Name, Lane, Skin }
function HeroService:Create(info)
	local def = Config.HeroesById[info.HeroId] or Config.HeroesById.Brakka
	local hero = {
		Kind = "Hero",
		Team = info.Team,
		HeroId = def.Id,
		Def = def,
		Player = info.Player,
		Bot = info.Player == nil,
		Name = info.Name,
		Lane = info.Lane,
		Skin = info.Skin or "Default",
		Level = info.Level or 1,
		XP = info.XP or 0,
		Gold = info.Gold or Config.StartGold,
		Items = info.Items or {},
		Kills = info.Kills or 0,
		Deaths = info.Deaths or 0,
		Assists = info.Assists or 0,
		CreepScore = info.CreepScore or 0,
		Cooldowns = { Q = 0, E = 0, R = 0 },
		AutoBuy = info.AutoBuy ~= false,
		Radius = 1.6,
		FxColor = def.Color,
		HP = 1,
		Dead = true,
		Status = {},
		Damagers = {},
	}
	local entry = Instance.new("Folder")
	entry.Name = tostring(#self.Heroes + 1) .. "_" .. hero.Name
	entry:SetAttribute("Name", hero.Name)
	entry:SetAttribute("HeroId", hero.HeroId)
	entry:SetAttribute("Team", hero.Team)
	entry:SetAttribute("IsBot", hero.Bot)
	entry:SetAttribute("UserId", if info.Player then info.Player.UserId else 0)
	entry.Parent = scoreboard
	hero.Entry = entry
	Combat:Register(hero)
	hero.Dead = true
	hero.HP = 0
	table.insert(self.Heroes, hero)
	if hero.Player then
		local player = hero.Player
		player:SetAttribute("Team", hero.Team)
		player:SetAttribute("Hero", hero.HeroId)
		for _, key in Config.AbilityKeys do
			player:SetAttribute("CD_" .. key, 0)
			player:SetAttribute("CDMax_" .. key, 0)
		end
		hero.Connection = player.CharacterAdded:Connect(function(character)
			self:OnCharacterAdded(hero, character)
		end)
	end
	self:Recompute(hero)
	return hero
end

function HeroService:Remove(hero)
	local index = table.find(self.Heroes, hero)
	if index then
		table.remove(self.Heroes, index)
	end
	hero.Removed = true
	Combat:Unregister(hero)
	if hero.Connection then
		hero.Connection:Disconnect()
	end
	if hero.Entry then
		hero.Entry:Destroy()
	end
	if hero.Bot and hero.Model then
		hero.Model:Destroy()
	end
	if hero.Player then
		local player = hero.Player
		player:SetAttribute("Hero", nil)
		player:SetAttribute("Dead", nil)
		if player.Parent and player.Character then
			player.Character:Destroy()
			player.Character = nil
		end
	end
end

function HeroService:RemoveAll()
	for _, hero in table.clone(self.Heroes) do
		self:Remove(hero)
	end
	self.Might = {}
end

function HeroService:GetByPlayer(player: Player)
	for _, hero in self.Heroes do
		if hero.Player == player then
			return hero
		end
	end
	return nil
end

local function fountainPoint(team: number): Vector3
	local fountain = MAP.Fountain[team]
	local angle = math.random() * math.pi * 2
	return fountain + Vector3.new(math.cos(angle) * 9, 0, math.sin(angle) * 9)
end

local function enemyFacing(team: number, position: Vector3): CFrame
	local look = position + Vector3.new(if team == 1 then 10 else -10, 0, 0)
	return CFrame.lookAt(position, look)
end

local function setupHumanoid(humanoid: Humanoid)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 4
	humanoid.RequiresNeck = false
end

function HeroService:OnCharacterAdded(hero, character: Model)
	if hero.Removed then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not humanoid or not root or hero.Removed then
		return
	end
	setupHumanoid(humanoid)
	local spawnAt = fountainPoint(hero.Team) + Vector3.new(0, 3.2, 0)
	character:PivotTo(enemyFacing(hero.Team, spawnAt))
	self:Bind(hero, character, humanoid)
	humanoid.Died:Connect(function()
		-- z. B. durch Herunterfallen: wie ein normaler Tod behandeln
		if not hero.Dead and hero.Model == character then
			hero.HP = 0
			hero.Dead = true
			self:OnDeath(hero, nil)
		end
	end)
	task.spawn(function()
		if character:FindFirstChild("RightHand") == nil and character:FindFirstChild("Right Arm") == nil then
			character:WaitForChild("RightHand", 3)
		end
		self.Services.WorldService:DressHero(character, hero.HeroId, hero.Team, hero.Skin)
	end)
end

function HeroService:Bind(hero, model: Model, humanoid: Humanoid)
	hero.Humanoid = humanoid
	hero.Dead = false
	hero.Status = {}
	hero.Damagers = {}
	hero.RecallUntil = nil
	hero.Focus = nil
	hero.NextAttack = 0
	Combat:BindModel(hero, model)
	model:SetAttribute("HeroId", hero.HeroId)
	model:SetAttribute("IsBot", hero.Bot)
	model:SetAttribute("Skin", hero.Skin)
	self:Recompute(hero)
	hero.HP = hero.MaxHP
	Combat:Sync(hero)
	self:Publish(hero)
end

-- Standard-Animationen von Roblox fuer Bots (Spieler haben das Animate-Script ihres Avatars)
local BOT_ANIMATIONS = { Idle = "rbxassetid://507766388", Run = "rbxassetid://507767714" }

local function animateBot(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local tracks = {}
	for name, id in BOT_ANIMATIONS do
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		if ok and track then
			track.Looped = true
			tracks[name] = track
		end
	end
	if tracks.Idle then
		tracks.Idle:Play()
	end
	local running = false
	humanoid.Running:Connect(function(speed)
		local moving = speed > 0.5
		if moving ~= running and tracks.Run then
			running = moving
			if moving then
				tracks.Run:Play(0.15)
			else
				tracks.Run:Stop(0.2)
			end
		end
	end)
end

local function botModel(hero): Model
	local def = hero.Def
	local team = Config.Teams[hero.Team]
	local model: Model? = nil
	local ok = pcall(function()
		local description = Instance.new("HumanoidDescription")
		local skin = def.Color:Lerp(Color3.fromRGB(255, 220, 190), 0.55)
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = team.Color:Lerp(def.Color, 0.4)
		description.LeftLegColor = team.Dark
		description.RightLegColor = team.Dark
		model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		-- Notfall: einfacher Block-Koerper
		local fallback = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Transparency = 1
		root.Parent = fallback
		local torso = Instance.new("Part")
		torso.Name = "UpperTorso"
		torso.Size = Vector3.new(2, 2.4, 1)
		torso.Color = team.Color
		torso.Parent = fallback
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1.4, 1.4, 1.4)
		head.Color = def.Color
		head.Parent = fallback
		local hand = Instance.new("Part")
		hand.Name = "RightHand"
		hand.Size = Vector3.new(0.6, 0.6, 0.6)
		hand.Color = def.Color
		hand.Parent = fallback
		for _, info in { { torso, CFrame.new(0, 0.2, 0) }, { head, CFrame.new(0, 2.1, 0) }, { hand, CFrame.new(1.3, -0.6, 0) } } do
			local motor = Instance.new("Weld")
			motor.Part0 = root
			motor.Part1 = info[1]
			motor.C0 = info[2]
			motor.Parent = root
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.HipHeight = 2
		humanoid.Parent = fallback
		fallback.PrimaryPart = root
		model = fallback
	end
	local result = model :: Model
	result.Name = hero.Name
	return result
end

function HeroService:Spawn(hero)
	if hero.Removed then
		return
	end
	hero.Dead = false
	hero.RespawnAt = nil
	hero.WasInFountain = false
	if hero.Player then
		hero.Player:LoadCharacter()
		return
	end
	if hero.Model then
		hero.Model:Destroy()
	end
	local model = botModel(hero)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	setupHumanoid(humanoid)
	model:PivotTo(enemyFacing(hero.Team, fountainPoint(hero.Team) + Vector3.new(0, 3.2, 0)))
	model.Parent = self.Services.WorldService:UnitsFolder()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	self:Bind(hero, model, humanoid)
	self.Services.WorldService:DressHero(model, hero.HeroId, hero.Team, hero.Skin)
	pcall(animateBot, humanoid)
end

function HeroService:Teleport(hero, position: Vector3)
	local model = hero.Model
	if model and model.Parent then
		local root = hero.Root
		local look = if root then root.CFrame.LookVector else Vector3.xAxis
		local target = Vector3.new(position.X, 3.2, position.Z)
		model:PivotTo(CFrame.lookAt(target, target + Vector3.new(look.X, 0, look.Z)))
	end
end

---------------------------------------------------------------- Gold und Erfahrung

function HeroService:GiveGold(hero, amount: number, position: Vector3?)
	if not hero or hero.Removed then
		return
	end
	hero.Gold += amount
	if hero.Player and position then
		self.Services.Net.Damage:FireClient(hero.Player, position, amount, "Gold")
	end
	self:Publish(hero)
end

function HeroService:AddXP(hero, amount: number)
	if hero.Level >= Config.MaxLevel then
		return
	end
	hero.XP += amount
	local leveled = false
	while hero.Level < Config.MaxLevel and hero.XP >= Config.XPToLevel(hero.Level) do
		hero.XP -= Config.XPToLevel(hero.Level)
		hero.Level += 1
		leveled = true
	end
	if hero.Level >= Config.MaxLevel then
		hero.XP = 0
	end
	if leveled then
		self:Recompute(hero)
		Combat:Sync(hero)
		if hero.Model then
			self.Services.Net.SendFx("LevelUp", { Model = hero.Model, Level = hero.Level })
		end
	else
		self:Publish(hero)
	end
end

function HeroService:ShareXP(team: number, position: Vector3, amount: number)
	local near = {}
	for _, hero in self.Heroes do
		if hero.Team == team and Combat.Alive(hero) and (Combat.Position(hero) - position).Magnitude <= Config.ShareRange then
			table.insert(near, hero)
		end
	end
	if #near == 0 then
		return
	end
	local each = amount * (if #near > 1 then 1.3 else 1) / #near
	for _, hero in near do
		self:AddXP(hero, each)
	end
end

function HeroService:GiveMight(team: number)
	self.Might[team] = now() + Config.MightBuff.Seconds
	for _, hero in self.Heroes do
		if hero.Team == team then
			self:Recompute(hero)
		end
	end
	task.delay(Config.MightBuff.Seconds + 0.1, function()
		for _, hero in self.Heroes do
			if hero.Team == team then
				self:Recompute(hero)
			end
		end
	end)
end

---------------------------------------------------------------- Shop

function HeroService:InFountain(hero): boolean
	return Combat.Alive(hero) and (Combat.Position(hero) - MAP.Fountain[hero.Team]).Magnitude <= MAP.FountainRadius + 6
end

function HeroService:CanShop(hero): boolean
	return hero.Dead or self:InFountain(hero)
end

local function hasBoots(hero): boolean
	for _, id in hero.Items do
		if Config.ItemsById[id].Boots then
			return true
		end
	end
	return false
end

function HeroService:BuyItem(hero, itemId: string, silent: boolean?): boolean
	local item = Config.ItemsById[itemId]
	local player = hero.Player
	local function fail(text: string)
		if player and not silent then
			self.Services.Net.SendNotify(player, text, Color3.fromRGB(255, 90, 90))
		end
		return false
	end
	if not item then
		return false
	end
	if not self:CanShop(hero) then
		return fail("Go back to your fountain to shop! (Recall)")
	end
	if #hero.Items >= Config.MaxItems then
		return fail("Your item slots are full. Sell something first.")
	end
	if item.Boots and hasBoots(hero) then
		return fail("You can only carry one pair of boots.")
	end
	if hero.Gold < item.Cost then
		return fail(`Not enough gold ({item.Cost} needed).`)
	end
	hero.Gold -= item.Cost
	table.insert(hero.Items, item.Id)
	self:Recompute(hero)
	Combat:Sync(hero)
	if player and not silent then
		self.Services.Net.SendNotify(player, `Bought {item.Name}!`, GOLD_COLOR)
	end
	return true
end

function HeroService:SellItem(hero, slot: number)
	local id = hero.Items[slot]
	if not id or not self:CanShop(hero) then
		return
	end
	table.remove(hero.Items, slot)
	hero.Gold += math.floor(Config.ItemsById[id].Cost * Config.SellRefund)
	self:Recompute(hero)
	Combat:Sync(hero)
end

-- Kauft das naechste empfohlene Item, solange das Gold reicht
function HeroService:AutoBuy(hero)
	local build = Config.RoleBuilds[hero.Def.Role] or Config.RoleBuilds.Fighter
	local bought = {}
	for _, id in build do
		if not table.find(hero.Items, id) then
			if #hero.Items >= Config.MaxItems or hero.Gold < Config.ItemsById[id].Cost then
				break
			end
			if self:BuyItem(hero, id, true) then
				table.insert(bought, Config.ItemsById[id].Name)
			else
				break
			end
		end
	end
	if #bought > 0 and hero.Player then
		self.Services.Net.SendNotify(hero.Player, "Auto-bought: " .. table.concat(bought, ", "), GOLD_COLOR)
	end
end

---------------------------------------------------------------- Rueckruf

function HeroService:Recall(hero)
	if not Combat.Alive(hero) or hero.RecallUntil or self:InFountain(hero) then
		return
	end
	hero.RecallUntil = now() + Config.RecallSeconds
	hero.RecallFrom = Combat.Position(hero)
	hero.RecallHP = hero.HP
	if hero.Player then
		hero.Player:SetAttribute("RecallUntil", hero.RecallUntil)
	end
	self.Services.Net.SendFx("Recall", { Model = hero.Model, Time = Config.RecallSeconds, Color = Config.Teams[hero.Team].Color })
end

function HeroService:CancelRecall(hero)
	if hero.RecallUntil then
		hero.RecallUntil = nil
		if hero.Player then
			hero.Player:SetAttribute("RecallUntil", 0)
		end
		self.Services.Net.SendFx("RecallCancel", { Model = hero.Model })
	end
end

---------------------------------------------------------------- Faehigkeiten

local function abilityAmount(hero, ability, base: number): number
	return base + (ability.PerLevel or 0) * (hero.Level - 1) + (ability.Ratio or 0) * hero.Damage
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
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

function HeroService:Displace(unit, offset: Vector3)
	local position = Combat.Position(unit) + offset
	position = Vector3.new(math.clamp(position.X, -MAP.HalfX + 2, MAP.HalfX - 2), 0, math.clamp(position.Z, -MAP.HalfZ + 2, MAP.HalfZ - 2))
	if unit.Kind == "Hero" then
		self:Teleport(unit, position)
	elseif unit.Kind == "Minion" or unit.Kind == "Monster" then
		local height = Vector3.new(0, unit.Height or 1.5, 0)
		unit.Root.CFrame = CFrame.new(position + height) * unit.Root.CFrame.Rotation
	end
end

local function applyEffects(self, hero, target, ability, direction: Vector3?)
	if ability.Slow then
		Combat:Slow(target, ability.Slow, ability.SlowTime or 1.5)
	end
	if ability.Stun then
		Combat:Stun(target, ability.Stun)
	end
	if ability.Knockback and direction and target.Kind ~= "Tower" and target.Kind ~= "Core" and not target.Boss then
		self:Displace(target, direction * ability.Knockback)
	end
end

local function hitAll(self, hero, targets, ability, amount: number, direction: Vector3?)
	for _, target in targets do
		Combat:Damage(hero, target, amount, { Ability = true })
		if Combat.Alive(target) then
			applyEffects(self, hero, target, ability, direction)
		end
	end
	return #targets
end

-- Ziel fuer Faehigkeiten ohne Zielpunkt (Handy): naechster Held, sonst naechste Einheit, sonst geradeaus
function HeroService:AutoAim(hero, range: number): Vector3
	local position = Combat.Position(hero)
	local target = Combat:NearestEnemy(hero.Team, position, range + 4, HERO_ONLY) or Combat:NearestEnemy(hero.Team, position, range + 4, ENEMY_UNITS)
	if target then
		return Combat.Position(target)
	end
	local look = if hero.Root then hero.Root.CFrame.LookVector else Vector3.xAxis
	return position + flat(look).Unit * range
end

function HeroService:Cast(hero, key: string, aim: Vector3?): boolean
	local ability = hero.Def.Abilities[key]
	local t = now()
	if not ability or not Combat.Alive(hero) or Combat.IsStunned(hero) or (hero.Cooldowns[key] or 0) > t then
		return false
	end
	if not self.Services.MatchService:IsPlaying() then
		return false
	end
	local position = Combat.Position(hero)
	local reach = ability.Range or ability.Length or 30
	if typeof(aim) ~= "Vector3" or (flat(aim) - position).Magnitude > 200 then
		aim = self:AutoAim(hero, reach)
	end
	local aimPoint = flat(aim :: Vector3)
	local direction = aimPoint - position
	if direction.Magnitude < 0.1 then
		local look = if hero.Root then hero.Root.CFrame.LookVector else Vector3.xAxis
		direction = flat(look)
	end
	direction = direction.Unit
	local color = hero.Def.Color
	local skin = Config.SkinsById[hero.Skin]
	if skin and skin.Color then
		color = skin.Color
	end
	local net = self.Services.Net
	local kind = ability.Type

	if kind == "Circle" then
		local amount = abilityAmount(hero, ability, ability.Damage)
		net.SendFx("Ring", { At = position, Radius = ability.Radius, Color = color })
		hitAll(self, hero, Combat:EnemiesNear(hero.Team, position, ability.Radius, ENEMY_UNITS), ability, amount)
	elseif kind == "Point" or kind == "Zone" then
		local offset = aimPoint - position
		if offset.Magnitude > ability.Range then
			offset = offset.Unit * ability.Range
		end
		local point = position + offset
		if kind == "Point" then
			net.SendFx("Marker", { At = point, Radius = ability.Radius, Time = ability.Delay, Color = color })
			task.delay(ability.Delay, function()
				if hero.Removed then
					return
				end
				net.SendFx("Boom", { At = point, Color = color, Size = ability.Radius * 2 })
				hitAll(self, hero, Combat:EnemiesNear(hero.Team, point, ability.Radius, ENEMY_UNITS), ability, abilityAmount(hero, ability, ability.Damage))
			end)
		else
			net.SendFx("Zone", { At = point, Radius = ability.Radius, Time = ability.Duration, Color = color })
			task.spawn(function()
				local ticks = math.floor(ability.Duration / ability.Tick)
				for _ = 1, ticks do
					if hero.Removed then
						return
					end
					hitAll(self, hero, Combat:EnemiesNear(hero.Team, point, ability.Radius, ENEMY_UNITS), ability, abilityAmount(hero, ability, ability.Damage))
					task.wait(ability.Tick)
				end
			end)
		end
	elseif kind == "Line" then
		local finish = position + direction * ability.Length
		net.SendFx("Line", { From = position, To = finish, Width = ability.Width, Color = color })
		local amount = abilityAmount(hero, ability, ability.Damage)
		local targets = {}
		for _, unit in Combat:EnemiesNear(hero.Team, position, ability.Length + 2, ENEMY_UNITS) do
			if distanceToSegment(Combat.Position(unit), position, finish) <= ability.Width / 2 + unit.Radius then
				table.insert(targets, unit)
			end
		end
		hitAll(self, hero, targets, ability, amount, direction)
	elseif kind == "Dash" then
		local destination
		local target
		if ability.ToTarget then
			target = Combat:NearestEnemy(hero.Team, position, ability.Range, HERO_ONLY) or Combat:NearestEnemy(hero.Team, position, ability.Range, ENEMY_UNITS)
			if not target then
				if hero.Player then
					net.SendNotify(hero.Player, "No enemy in range!", Color3.fromRGB(255, 120, 120))
				end
				return false
			end
			local toTarget = Combat.Position(target) - position
			destination = Combat.Position(target) - (if toTarget.Magnitude > 0.1 then toTarget.Unit else direction) * 2.5
		else
			local distance = math.min(ability.Range, math.max(6, (aimPoint - position).Magnitude))
			destination = position + direction * distance
		end
		self:CancelRecall(hero)
		net.SendFx("Dash", { From = position, To = destination, Color = color })
		self:Teleport(hero, destination)
		if (ability.Damage or 0) > 0 then
			local amount = abilityAmount(hero, ability, ability.Damage)
			if ability.Radius then
				net.SendFx("Ring", { At = destination, Radius = ability.Radius, Color = color })
				hitAll(self, hero, Combat:EnemiesNear(hero.Team, destination, ability.Radius, ENEMY_UNITS), ability, amount)
			elseif target then
				hitAll(self, hero, { target }, ability, amount)
			end
		end
	elseif kind == "Target" then
		local target = Combat:NearestEnemy(hero.Team, position, ability.Range, HERO_ONLY) or Combat:NearestEnemy(hero.Team, position, ability.Range, ENEMY_UNITS)
		if not target then
			if hero.Player then
				net.SendNotify(hero.Player, "No enemy in range!", Color3.fromRGB(255, 120, 120))
			end
			return false
		end
		local amount = abilityAmount(hero, ability, ability.Damage) + (ability.Execute or 0) * (target.MaxHP - target.HP)
		net.SendFx("BigSlash", { At = Combat.Position(target), Color = color })
		hitAll(self, hero, { target }, ability, amount)
	elseif kind == "Chain" then
		local target = Combat:NearestEnemy(hero.Team, position, ability.Range, HERO_ONLY) or Combat:NearestEnemy(hero.Team, position, ability.Range, ENEMY_UNITS)
		if not target then
			if hero.Player then
				net.SendNotify(hero.Player, "No enemy in range!", Color3.fromRGB(255, 120, 120))
			end
			return false
		end
		local amount = abilityAmount(hero, ability, ability.Damage)
		local hit = { target }
		local points = { position, Combat.Position(target) }
		local current = target
		for _ = 1, ability.Bounces do
			local best, bestDistance = nil, math.huge
			for _, unit in Combat:EnemiesNear(hero.Team, Combat.Position(current), ability.Bounce, ENEMY_UNITS) do
				local distance = Combat.Distance(unit, current)
				if not table.find(hit, unit) and distance < bestDistance then
					best, bestDistance = unit, distance
				end
			end
			if not best then
				break
			end
			table.insert(hit, best)
			table.insert(points, Combat.Position(best))
			current = best
		end
		net.SendFx("Chain", { Points = points, Color = color })
		hitAll(self, hero, hit, ability, amount)
	elseif kind == "Shield" then
		Combat:Shield(hero, abilityAmount(hero, ability, ability.Shield), ability.Duration)
	elseif kind == "Heal" then
		local amount = abilityAmount(hero, ability, ability.Heal)
		net.SendFx("Heal", { At = position, Radius = ability.Radius })
		for _, ally in Combat:AlliesNear(hero.Team, position, ability.Radius, HERO_ONLY) do
			Combat:Heal(ally, amount, hero)
			if ability.Speed then
				ally.Buff = { Speed = ability.Speed, Until = now() + ability.Duration }
				self:Recompute(ally)
			end
		end
	elseif kind == "Buff" then
		hero.Buff = { Speed = ability.Speed, AttackSpeed = ability.AttackSpeed, Until = t + ability.Duration }
		if ability.Reduction then
			hero.Status.Reduction = ability.Reduction
			hero.Status.ReductionUntil = t + ability.Duration
		end
		net.SendFx("Buff", { Model = hero.Model, Time = ability.Duration, Color = color })
		self:Recompute(hero)
	end

	if kind ~= "Dash" then
		self:CancelRecall(hero)
	end
	local cooldown = ability.Cooldown * (1 - hero.Haste)
	hero.Cooldowns[key] = t + cooldown
	if hero.Player then
		hero.Player:SetAttribute("CD_" .. key, t + cooldown)
		hero.Player:SetAttribute("CDMax_" .. key, cooldown)
	end
	if hero.Model then
		net.SendFx("Cast", { Model = hero.Model, Key = key })
	end
	return true
end

---------------------------------------------------------------- Auto-Angriff

local function lowest(list)
	local best = nil
	for _, unit in list do
		if not best or unit.HP < best.HP then
			best = unit
		end
	end
	return best
end

-- Spieler: Fokus > Held > Minion (das schwaechste, fuer den letzten Treffer) > Monster im Kampf > Turm/Kern
function HeroService:PickTarget(hero)
	local position = Combat.Position(hero)
	local reach = hero.Range + 1
	local focus = hero.Focus
	if focus and Combat:Targetable(focus) and focus.Team ~= hero.Team then
		if Combat:InRange(hero, focus, 1) then
			return focus
		end
		if Combat.Distance(hero, focus) > 60 then
			hero.Focus = nil
		end
		if hero.Player then
			return nil -- Spieler laeuft selbst zum Fokus
		end
	end
	local heroTarget = Combat:NearestEnemy(hero.Team, position, reach, HERO_ONLY)
	if heroTarget then
		return heroTarget
	end
	local minion = lowest(Combat:EnemiesNear(hero.Team, position, reach, MINIONS))
	if minion then
		return minion
	end
	for _, monster in Combat:EnemiesNear(hero.Team, position, reach, MONSTERS) do
		if monster.Target and monster.Target.Team == hero.Team then
			return monster
		end
	end
	return Combat:NearestEnemy(hero.Team, position, reach, STRUCTURES)
end

---------------------------------------------------------------- Tod

function HeroService:OnDeath(hero, killer)
	if hero.Removed then
		return
	end
	hero.Dead = true
	hero.HP = 0
	hero.Deaths += 1
	hero.RecallUntil = nil
	local t = now()
	hero.RespawnAt = t + Config.RespawnBase + hero.Level * Config.RespawnPerLevel
	local killerHero = if killer and killer.Kind == "Hero" then killer else nil
	if not killerHero then
		local latest = 0
		for other, time in hero.Damagers do
			if time > latest and t - time <= Config.AssistWindow and other.Team ~= hero.Team then
				killerHero, latest = other, time
			end
		end
	end
	local position = Combat.Position(hero)
	local killerTeam = if hero.Team == 1 then 2 else 1
	if killerHero then
		killerHero.Kills += 1
		self:GiveGold(killerHero, Config.KillGold + hero.Level * 10, position)
		for _, helper in Combat:RecentDamagers(hero, killerHero) do
			if helper.Kind == "Hero" then
				helper.Assists += 1
				self:GiveGold(helper, Config.AssistGold, position)
				self:Publish(helper)
			end
		end
		self:Publish(killerHero)
	end
	self:ShareXP(killerTeam, position, Config.KillXP + hero.Level * 20)
	self.Services.Net.KillFeed:FireAllClients({
		Killer = if killerHero then killerHero.Name elseif killer then killer.Name else "The Arena",
		KillerHero = if killerHero then killerHero.HeroId else nil,
		KillerTeam = killerTeam,
		Victim = hero.Name,
		VictimHero = hero.HeroId,
		VictimTeam = hero.Team,
	})
	self.Services.MatchService:OnHeroKill(killerTeam, killerHero)
	Combat:Sync(hero)
	self:Publish(hero)
	if hero.Player then
		hero.Player:SetAttribute("RecallUntil", 0)
		self.Services.MonetizationService:OnHeroDeath(hero.Player)
	end
	local model = hero.Model
	if hero.Bot and model then
		task.delay(2.5, function()
			if hero.Model == model and hero.Dead then
				model:Destroy()
			end
		end)
	end
	if model then
		self.Services.Net.SendFx("Poof", { At = position, Color = Config.Teams[hero.Team].Color })
	end
end

function HeroService:RespawnNow(hero)
	if hero and hero.Dead and not hero.Removed then
		hero.RespawnAt = now()
	end
end

---------------------------------------------------------------- Takt

function HeroService:Tick(dt: number)
	local t = now()
	local playing = self.Services.MatchService:IsPlaying()
	for _, hero in table.clone(self.Heroes) do
		if hero.Removed then
			continue
		end
		if hero.Dead then
			if playing and hero.RespawnAt and t >= hero.RespawnAt then
				hero.RespawnAt = nil
				task.spawn(self.Spawn, self, hero)
			end
			continue
		end
		if not Combat.Alive(hero) then
			continue
		end
		if playing then
			hero.Gold += Config.PassiveGold * dt
		end
		local position = Combat.Position(hero)
		-- Buff abgelaufen: Werte neu berechnen
		if hero.Buff and hero.Buff.Until <= t then
			hero.Buff = nil
			self:Recompute(hero)
		end
		-- Brunnen: heilt Freunde, verbrennt Feinde
		local fountain = MAP.Fountain[hero.Team]
		local inFountain = (position - fountain).Magnitude <= MAP.FountainRadius
		if inFountain and not hero.WasInFountain and hero.AutoBuy then
			self:AutoBuy(hero)
		end
		hero.WasInFountain = inFountain
		local regen = hero.Regen * dt
		if inFountain then
			regen += hero.MaxHP * Config.FountainHeal * dt
		end
		if hero.HP < hero.MaxHP then
			hero.HP = math.min(hero.MaxHP, hero.HP + regen)
			Combat:Sync(hero)
		end
		local enemyFountain = MAP.Fountain[if hero.Team == 1 then 2 else 1]
		if (position - enemyFountain).Magnitude <= MAP.FountainRadius + 4 then
			Combat:Damage(nil, hero, Config.FountainDamage * dt, { True = true })
			if hero.Dead then
				continue
			end
		end
		-- Laufgeschwindigkeit
		if hero.Humanoid then
			local speed = if Combat.IsStunned(hero) or not playing then 0 else hero.Speed * Combat.SlowFactor(hero)
			if hero.Humanoid.WalkSpeed ~= speed then
				hero.Humanoid.WalkSpeed = speed
			end
		end
		-- Rueckruf
		if hero.RecallUntil then
			local moved = (position - (hero.RecallFrom or position)).Magnitude > 1.5
			local hurt = hero.HP < (hero.RecallHP or 0) - 1
			if moved or hurt then
				self:CancelRecall(hero)
			elseif t >= hero.RecallUntil then
				hero.RecallUntil = nil
				if hero.Player then
					hero.Player:SetAttribute("RecallUntil", 0)
				end
				self:Teleport(hero, fountainPoint(hero.Team))
				if hero.AutoBuy then
					self:AutoBuy(hero)
				end
			end
		else
			hero.RecallHP = hero.HP
		end
		-- Auto-Angriff
		if playing and not hero.RecallUntil and Combat:CanAttack(hero) then
			local target = self:PickTarget(hero)
			if target and Combat:InRange(hero, target, 1) then
				Combat:Attack(hero, target)
			end
		end
		if hero.Player then
			hero.Player:SetAttribute("Gold", math.floor(hero.Gold))
			hero.Player:SetAttribute("CanShop", self:CanShop(hero))
		end
	end
end

---------------------------------------------------------------- Start

function HeroService:Start()
	local net = self.Services.Net
	net.Cast.OnServerEvent:Connect(function(player, key, aim)
		local hero = self:GetByPlayer(player)
		if hero and typeof(key) == "string" and Config.HeroesById[hero.HeroId].Abilities[key] then
			self:Cast(hero, key, if typeof(aim) == "Vector3" then aim else nil)
		end
	end)
	net.Focus.OnServerEvent:Connect(function(player, model)
		local hero = self:GetByPlayer(player)
		if not hero then
			return
		end
		local unit = if typeof(model) == "Instance" then Combat:GetUnit(model) else nil
		hero.Focus = if unit and unit.Team ~= hero.Team then unit else nil
	end)
	net.Recall.OnServerEvent:Connect(function(player)
		local hero = self:GetByPlayer(player)
		if hero then
			self:Recall(hero)
		end
	end)
	net.BuyItem.OnServerEvent:Connect(function(player, itemId)
		local hero = self:GetByPlayer(player)
		if hero and typeof(itemId) == "string" then
			if itemId == "Auto" then
				self:AutoBuy(hero)
			else
				self:BuyItem(hero, itemId)
			end
		end
	end)
	net.SellItem.OnServerEvent:Connect(function(player, slot)
		local hero = self:GetByPlayer(player)
		if hero and typeof(slot) == "number" then
			self:SellItem(hero, math.floor(slot))
		end
	end)
	net.SetAutoBuy.OnServerEvent:Connect(function(player, enabled)
		if typeof(enabled) ~= "boolean" then
			return
		end
		local data = self.Services.DataService:Get(player)
		if data then
			data.AutoBuy = enabled
			player:SetAttribute("AutoBuy", enabled)
		end
		local hero = self:GetByPlayer(player)
		if hero then
			hero.AutoBuy = enabled
			if enabled and self:CanShop(hero) then
				self:AutoBuy(hero)
			end
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= TICK then
			local step = math.min(accumulator, 0.3)
			accumulator = 0
			self:Tick(step)
		end
	end)
end

return HeroService
