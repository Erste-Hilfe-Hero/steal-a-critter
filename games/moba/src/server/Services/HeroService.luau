-- Helden (Spieler und Bots): Werte aus Stufe, Items, Buffs und Drachen; Mana und Faehigkeitsraenge;
-- Passive; Beschwoererzauber; Wards und Traenke; Shop mit Bauteilen; Kills mit Serien, Kopfgeld und Ace;
-- Tod, Respawn, Rueckruf und der Auto-Angriff.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Abilities = require(script.Parent.Abilities)

local HeroService = {
	Services = nil :: any,
	Heroes = {} :: { any },
	Wards = {} :: { any },
	FirstBlood = false,
}

local MAP = Config.Map
local TICK = 0.1
local HERO_ONLY = { Hero = true }
local MINIONS = { Minion = true }
local MONSTERS = { Monster = true }
local GOLD_COLOR = Color3.fromRGB(255, 210, 70)
local RED = Color3.fromRGB(255, 100, 100)
local STAT_KEYS = { "AD", "AP", "HP", "Mana", "Armor", "MR", "AS", "Crit", "Lifesteal", "AH", "MS", "HPRegen", "ManaRegen", "Lethality", "MagicPen", "MagicPenPct" }
local STREAKS = { [3] = "is on a killing spree!", [4] = "is on a rampage!", [5] = "is unstoppable!", [6] = "is dominating!", [7] = "is godlike!" }
local MULTI = { [2] = "Double Kill!", [3] = "Triple Kill!", [4] = "Quadra Kill!", [5] = "PENTA KILL!" }

local Combat
local scoreboard: Folder

local function now()
	return workspace:GetServerTimeNow()
end

local function enemyOf(team: number): number
	return if team == 1 then 2 else 1
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Wachstum pro Stufe wie im Original (leicht steigend)
local function growth(perLevel: number, level: number): number
	return perLevel * (level - 1) * (0.7025 + 0.0175 * (level - 1))
end

local function elapsed(): number
	return HeroService.Services.MatchService:Elapsed()
end

function HeroService:Init(services)
	self.Services = services
	Combat = services.CombatService
	Combat.DeathHandlers.Hero = function(unit, killer)
		self:OnDeath(unit, killer)
	end
	Combat.DeathHandlers.Ward = function(unit, killer)
		self:OnWardDeath(unit, killer)
	end
	table.insert(Combat.DeathListeners, function(unit, _killer)
		self:CollectSouls(unit)
	end)
	local match = ReplicatedStorage:FindFirstChild("Match") or Instance.new("Folder")
	match.Name = "Match"
	match.Parent = ReplicatedStorage
	scoreboard = Instance.new("Folder")
	scoreboard.Name = "Heroes"
	scoreboard.Parent = match
	Abilities.Init(services, self)
end

---------------------------------------------------------------- Werte

local function hasUnique(hero, name: string): boolean
	return hero.Uniques[name] == true
end
HeroService.HasUnique = hasUnique

local function activeBuff(hero, id: string): boolean
	return (hero.Buffs[id] or 0) > now()
end
HeroService.ActiveBuff = activeBuff

-- Summe der aktiven Zeit-Boni (Faehigkeiten, Geist, Passive)
local function temp(hero, key: string): number
	local total = 0
	local t = now()
	for _, entry in hero.Temp do
		if entry.Until > t and entry[key] then
			total += entry[key]
		end
	end
	return total
end
HeroService.Temp = temp

function HeroService:AddTemp(hero, id: string, seconds: number, values)
	values.Until = now() + seconds
	hero.Temp[id] = values
	self:Recompute(hero)
end

function HeroService:RemoveTemp(hero, id: string)
	if hero.Temp[id] then
		hero.Temp[id] = nil
		self:Recompute(hero)
	end
end

local function drakeStacks(self, team: number): { [string]: number }
	local stacks = { Infernal = 0, Mountain = 0, Ocean = 0, Cloud = 0 }
	local jungle = self.Services.JungleService
	if not jungle then
		return stacks
	end
	for _, id in jungle.Drakes[team] or {} do
		stacks[id] += 1
	end
	local soul = jungle.Soul[team]
	if soul then
		stacks[soul] += 3
	end
	return stacks
end

function HeroService:Recompute(hero)
	local def = hero.Def
	local s = def.Stats
	local level = hero.Level
	local bonus = {}
	for _, key in STAT_KEYS do
		bonus[key] = 0
	end
	local uniques = {}
	for _, id in hero.Items do
		local item = Config.ItemsById[id]
		if item then
			for key, value in item.Stats or {} do
				bonus[key] = (bonus[key] or 0) + value
			end
			if item.Unique then
				uniques[item.Unique] = true
			end
			if item.Id == "SpiritWard" then
				uniques.HealTaken = true
				uniques.HealPower = nil
			elseif item.Id == "MoonChalice" then
				uniques.HealPower = true
			end
		end
	end
	hero.Uniques = uniques
	local drakes = drakeStacks(self, hero.Team)
	hero.Drakes = drakes
	local power = 1 + drakes.Infernal * Config.DrakesById.Infernal.PowerPct
	local resist = 1 + drakes.Mountain * Config.DrakesById.Mountain.ResistPct

	local baseAD = s.AD + growth(s.ADPerLevel, level)
	local bonusAD = bonus.AD + temp(hero, "AD") + (if activeBuff(hero, "Baron") then Config.Buffs.Baron.AD else 0)
	if hero.Bloodlust and hero.Bloodlust > now() then
		bonusAD += baseAD * 0.3
	end
	local totalAD = (baseAD + bonusAD) * power
	hero.BaseAD = baseAD
	hero.BonusAD = totalAD - baseAD
	hero.AD = totalAD
	hero.Damage = totalAD
	local ap = bonus.AP + temp(hero, "AP") + (hero.Souls or 0) + (if activeBuff(hero, "Baron") then Config.Buffs.Baron.AP else 0)
	if uniques.Archmage then
		ap *= 1.35
	end
	hero.AP = ap * power

	local oldMax, oldMana = hero.MaxHP or 0, hero.MaxMana or 0
	hero.BaseHP = s.HP + growth(s.HPPerLevel, level)
	hero.MaxHP = hero.BaseHP + bonus.HP
	hero.MaxMana = s.Mana + growth(s.ManaPerLevel, level) + bonus.Mana
	if oldMax > 0 and hero.MaxHP > oldMax and not hero.Dead then
		hero.HP += hero.MaxHP - oldMax
	end
	if oldMana > 0 and hero.MaxMana > oldMana then
		hero.Mana = (hero.Mana or 0) + hero.MaxMana - oldMana
	end
	hero.HP = math.min(hero.HP or hero.MaxHP, hero.MaxHP)
	hero.Mana = math.min(hero.Mana or hero.MaxMana, hero.MaxMana)

	hero.BaseArmor = s.Armor + growth(s.ArmorPerLevel, level)
	hero.Armor = (hero.BaseArmor + bonus.Armor + temp(hero, "Armor") + (hero.Souls or 0) * 0.5) * resist
	hero.MR = (s.MR + growth(s.MRPerLevel, level) + bonus.MR + temp(hero, "MR")) * resist
	local zephyr = if (hero.SpellForceUntil or 0) > now() then (hero.SpellForce or 0) * 0.08 else 0
	hero.AttackSpeed = math.min(2.5, s.AttackSpeed * (1 + bonus.AS + growth(s.ASPerLevel, level) + temp(hero, "AS") + zephyr))
	hero.Crit = math.min(Config.MaxCrit, bonus.Crit)
	hero.CritDamage = Config.CritDamage + (if uniques.CritDamage then 0.4 else 0)
	hero.AH = bonus.AH + (if activeBuff(hero, "Blue") then Config.Buffs.Blue.AH else 0)
	hero.Lifesteal = bonus.Lifesteal
	hero.Lethality = bonus.Lethality
	hero.MagicPen = bonus.MagicPen
	hero.MagicPenPct = bonus.MagicPenPct
	hero.HealPower = if uniques.HealPower then 0.2 else 0
	hero.HealTaken = if uniques.HealTaken then 0.25 else 0
	hero.AttackReduction = if uniques.Steelcaps then 0.12 else 0
	hero.Range = s.Range + temp(hero, "Range")
	hero.Ranged = s.Range > 12
	hero.HPRegen = s.HPRegen + 0.1 * (level - 1) + bonus.HPRegen + (if activeBuff(hero, "Red") then Config.Buffs.Red.Regen else 0)
	hero.ManaRegen = s.ManaRegen + 0.08 * (level - 1) + bonus.ManaRegen
	local moveSpeed = s.Speed + bonus.MS
	local percent = temp(hero, "MSPct") + drakes.Cloud * Config.DrakesById.Cloud.SpeedPct
	hero.Speed = moveSpeed * (1 + percent) * Config.HeroSpeedScale
	self:Publish(hero)
end

function HeroService:RefreshTeam(team: number)
	for _, hero in self.Heroes do
		if hero.Team == team then
			self:Recompute(hero)
		end
	end
end

local function ranksText(hero): string
	local list = {}
	for _, key in Config.AbilityKeys do
		table.insert(list, tostring(hero.Ranks[key] or 0))
	end
	return table.concat(list, ",")
end

local function buffsText(hero): string
	local list = {}
	local t = now()
	for id, until_ in hero.Buffs do
		if until_ > t then
			table.insert(list, id .. ":" .. math.floor(until_))
		end
	end
	return table.concat(list, ",")
end

-- Werte fuer die Anzeige: Spieler-Attribute (eigenes HUD) und Anzeigetafel (alle)
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
		entry:SetAttribute("Role", hero.Role)
		entry:SetAttribute("SpellD", hero.Spells.D)
		entry:SetAttribute("SpellF", hero.Spells.F)
		entry:SetAttribute("Streak", hero.Streak)
		entry:SetAttribute("Worth", math.floor(self:ItemWorth(hero)))
	end
	if hero.Model then
		hero.Model:SetAttribute("Level", hero.Level)
		hero.Model:SetAttribute("MaxMana", math.floor(hero.MaxMana))
		hero.Model:SetAttribute("Mana", math.floor(hero.Mana))
		hero.Model:SetAttribute("Buffs", buffsText(hero))
	end
	local player = hero.Player
	if player then
		player:SetAttribute("Level", hero.Level)
		player:SetAttribute("XP", math.floor(hero.XP))
		player:SetAttribute("XPNeed", if hero.Level >= Config.MaxLevel then 0 else Config.XPToLevel(hero.Level))
		player:SetAttribute("Gold", math.floor(hero.Gold))
		player:SetAttribute("Items", table.concat(hero.Items, ","))
		player:SetAttribute("Potions", hero.Potions)
		player:SetAttribute("Ranks", ranksText(hero))
		player:SetAttribute("SkillPoints", hero.SkillPoints)
		player:SetAttribute("AD", math.floor(hero.AD))
		player:SetAttribute("AP", math.floor(hero.AP))
		player:SetAttribute("Armor", math.floor(hero.Armor))
		player:SetAttribute("MR", math.floor(hero.MR))
		player:SetAttribute("AttackSpeed", math.floor(hero.AttackSpeed * 100) / 100)
		player:SetAttribute("Crit", math.floor(hero.Crit * 100))
		player:SetAttribute("AH", math.floor(hero.AH))
		player:SetAttribute("MoveSpeed", math.floor(hero.Speed / Config.HeroSpeedScale))
		player:SetAttribute("Range", hero.Range)
		player:SetAttribute("Mana", math.floor(hero.Mana))
		player:SetAttribute("MaxMana", math.floor(hero.MaxMana))
		player:SetAttribute("Dead", hero.Dead)
		player:SetAttribute("RespawnAt", hero.RespawnAt or 0)
		player:SetAttribute("Kills", hero.Kills)
		player:SetAttribute("Deaths", hero.Deaths)
		player:SetAttribute("Assists", hero.Assists)
		player:SetAttribute("CS", hero.CreepScore or 0)
		player:SetAttribute("CanShop", self:CanShop(hero))
		player:SetAttribute("SpellD", hero.Spells.D)
		player:SetAttribute("SpellF", hero.Spells.F)
		player:SetAttribute("Wards", hero.WardCharges)
		player:SetAttribute("WardReadyAt", hero.WardReadyAt or 0)
		player:SetAttribute("SmiteCharges", hero.SmiteCharges)
		player:SetAttribute("Buffs", buffsText(hero))
		player:SetAttribute("Role", hero.Role)
		player:SetAttribute("Souls", hero.Souls or 0)
	end
end

function HeroService:SetCooldown(hero, key: string, untilTime: number, total: number)
	hero.Cooldowns[key] = untilTime
	if hero.Player then
		hero.Player:SetAttribute("CD_" .. key, untilTime)
		hero.Player:SetAttribute("CDMax_" .. key, total)
	end
end

---------------------------------------------------------------- Erstellen und Spawnen

-- info: { Team, HeroId, Player?, Name, Role, Lane, Skin, Spells = { D, F } }
function HeroService:Create(info)
	local def = Config.HeroesById[info.HeroId] or Config.HeroesById.Brakka
	local role = info.Role or def.Roles[1]
	local spells = info.Spells or { D = "Flash", F = Config.DefaultSpells[role] or "Heal" }
	local hero = {
		Kind = "Hero",
		Team = info.Team,
		HeroId = def.Id,
		Def = def,
		Player = info.Player,
		Bot = info.Player == nil,
		Name = info.Name,
		Role = role,
		Lane = Config.RolesById[role] and Config.RolesById[role].Lane or "Mid",
		Skin = info.Skin or "Default",
		Level = 1,
		XP = 0,
		SkillPoints = 1,
		Ranks = { Q = 0, W = 0, E = 0, R = 0 },
		Gold = Config.StartGold,
		Items = {},
		Potions = 0,
		Kills = 0,
		Deaths = 0,
		Assists = 0,
		CreepScore = 0,
		Streak = 0,
		DeathStreak = 0,
		Spells = spells,
		SmiteCharges = if spells.D == "Smite" or spells.F == "Smite" then 1 else 0,
		WardCharges = Config.Ward.Charges,
		Cooldowns = {},
		Buffs = {},
		Temp = {},
		Uniques = {},
		AutoBuy = info.AutoBuy ~= false,
		Radius = 1.6,
		FxColor = def.Color,
		HP = 1,
		Mana = 0,
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
	Abilities.Attach(hero)
	table.insert(self.Heroes, hero)
	if hero.Player then
		local player = hero.Player
		player:SetAttribute("Team", hero.Team)
		player:SetAttribute("Hero", hero.HeroId)
		for _, key in { "Q", "W", "E", "R", "D", "F", "Stasis" } do
			player:SetAttribute("CD_" .. key, 0)
			player:SetAttribute("CDMax_" .. key, 0)
		end
		hero.Connection = player.CharacterAdded:Connect(function(character)
			self:OnCharacterAdded(hero, character)
		end)
	end
	-- Startgegenstaende
	for _, id in def.Build.Start do
		if hero.Bot or hero.AutoBuy then
			self:BuyItem(hero, id, true, true)
		end
	end
	if hero.Role == "Jungle" and (hero.Bot or hero.AutoBuy) and not table.find(hero.Items, "HuntersMachete") then
		self:BuyItem(hero, "HuntersMachete", true, true)
	end
	self:Recompute(hero)
	if hero.Bot then
		self:LevelAbility(hero, Config.SkillOrder[1])
	end
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
	for _, ward in table.clone(self.Wards) do
		if ward.Owner == hero then
			self:RemoveWard(ward)
		end
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
	for _, ward in table.clone(self.Wards) do
		self:RemoveWard(ward)
	end
	self.FirstBlood = false
end

function HeroService:GetByPlayer(player: Player)
	for _, hero in self.Heroes do
		if hero.Player == player then
			return hero
		end
	end
	return nil
end

function HeroService.FountainPoint(team: number): Vector3
	local fountain = MAP.Fountain[team]
	local angle = math.random() * math.pi * 2
	return fountain + Vector3.new(math.cos(angle) * 7, 0, math.sin(angle) * 7)
end
local fountainPoint = HeroService.FountainPoint

local function enemyFacing(team: number, position: Vector3): CFrame
	local look = position + Config.Mirror(Vector3.new(10, 0, -10), team)
	return CFrame.lookAt(position, look)
end

local function setupHumanoid(humanoid: Humanoid)
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = 0
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = true
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
	hero.Empower = nil
	hero.Teleporting = nil
	Combat:BindModel(hero, model)
	model:SetAttribute("HeroId", hero.HeroId)
	model:SetAttribute("IsBot", hero.Bot)
	model:SetAttribute("Skin", hero.Skin)
	self:Recompute(hero)
	hero.HP = hero.MaxHP
	hero.Mana = hero.MaxMana
	hero.GraniteAt = 0
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
		if hero.Humanoid then
			hero.Humanoid:MoveTo(target)
		end
	end
end

---------------------------------------------------------------- Gold, Erfahrung, Raenge

function HeroService:GiveGold(hero, amount: number, position: Vector3?)
	if not hero or hero.Removed or amount <= 0 then
		return
	end
	hero.Gold += amount
	if hero.Player and position then
		self.Services.Net.Damage:FireClient(hero.Player, position, amount, "Gold")
	end
	self:Publish(hero)
end

function HeroService:AddXP(hero, amount: number)
	if hero.Level >= Config.MaxLevel or amount <= 0 then
		return
	end
	hero.XP += amount
	local leveled = false
	while hero.Level < Config.MaxLevel and hero.XP >= Config.XPToLevel(hero.Level) do
		hero.XP -= Config.XPToLevel(hero.Level)
		hero.Level += 1
		hero.SkillPoints += 1
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
		if hero.Bot then
			self:AutoLevel(hero)
		end
	else
		self:Publish(hero)
	end
end

-- Erfahrung fuer alle Helden eines Teams in der Naehe. Epische Monster geben jedem den vollen Wert.
function HeroService:ShareXP(team: number, position: Vector3, amount: number, epic: boolean?)
	local near = {}
	for _, hero in self.Heroes do
		if hero.Team == team and Combat.Alive(hero) and (Combat.Position(hero) - position).Magnitude <= Config.ShareRange * (if epic then 1.5 else 1) then
			table.insert(near, hero)
		end
	end
	if #near == 0 then
		return
	end
	local each = amount * Config.XPMultiplier / (if epic then 1 else #near)
	for _, hero in near do
		self:AddXP(hero, each)
	end
end

function HeroService:LevelAbility(hero, key: string): boolean
	if hero.SkillPoints <= 0 or not hero.Ranks[key] then
		return false
	end
	if not Config.CanRank(key, hero.Ranks[key], hero.Level) then
		return false
	end
	hero.Ranks[key] += 1
	hero.SkillPoints -= 1
	if hero.Model then
		self.Services.Net.SendFx("RankUp", { Model = hero.Model, Key = key })
	end
	self:Publish(hero)
	return true
end

-- Bots (und Spieler ohne Zeit) verteilen Punkte nach der Standard-Reihenfolge, R hat Vorrang
function HeroService:AutoLevel(hero)
	local guard = 0
	while hero.SkillPoints > 0 and guard < 20 do
		guard += 1
		if self:LevelAbility(hero, "R") then
			continue
		end
		local wanted = Config.SkillOrder[math.clamp(hero.Level - hero.SkillPoints + 1, 1, #Config.SkillOrder)]
		if not self:LevelAbility(hero, wanted) then
			local done = false
			for _, key in { "Q", "W", "E" } do
				if self:LevelAbility(hero, key) then
					done = true
					break
				end
			end
			if not done then
				break
			end
		end
	end
end

function HeroService:GiveBuff(hero, id: string, seconds: number?)
	local buff = Config.Buffs[id]
	if not buff or not hero then
		return
	end
	hero.Buffs[id] = now() + (seconds or buff.Seconds)
	self:Recompute(hero)
	if hero.Model then
		self.Services.Net.SendFx("Buff", { Model = hero.Model, Time = 2, Color = buff.Color })
	end
	if hero.Player then
		self.Services.Net.SendNotify(hero.Player, `{buff.Icon} {buff.Name}!`, buff.Color)
	end
end

---------------------------------------------------------------- Shop mit Bauteilen

function HeroService:InFountain(hero): boolean
	return Combat.Alive(hero) and (Combat.Position(hero) - MAP.Fountain[hero.Team]).Magnitude <= MAP.FountainRadius + 12
end

function HeroService:CanShop(hero): boolean
	return hero.Dead or self:InFountain(hero)
end

-- Restpreis nach Abzug vorhandener Bauteile, die verbrauchten Bauteile und die uebrigen Items
HeroService.PriceFor = Config.PriceFor

function HeroService:ItemWorth(hero): number
	local total = 0
	for _, id in hero.Items do
		local item = Config.ItemsById[id]
		total += if item then item.Cost else 0
	end
	return total
end

local function hasBoots(items: { string }): boolean
	for _, id in items do
		if Config.ItemsById[id].Boots then
			return true
		end
	end
	return false
end

function HeroService:BuyItem(hero, itemId: string, silent: boolean?, free: boolean?): boolean
	local item = Config.ItemsById[itemId]
	local player = hero.Player
	local function fail(text: string)
		if player and not silent then
			self.Services.Net.SendNotify(player, text, RED)
		end
		return false
	end
	if not item then
		return false
	end
	if not free and not self:CanShop(hero) then
		return fail("Go back to your fountain to shop! (Recall)")
	end
	if item.Potion then
		if hero.Potions >= Config.MaxPotions then
			return fail("You can carry 5 potions.")
		end
		if hero.Gold < item.Cost then
			return fail(`Not enough gold ({item.Cost} needed).`)
		end
		hero.Gold -= item.Cost
		hero.Potions += 1
		self:Publish(hero)
		return true
	end
	local price, _, rest = HeroService.PriceFor(hero.Items, itemId)
	if #rest >= Config.MaxItems then
		return fail("Your item slots are full. Sell something first.")
	end
	if item.Boots and hasBoots(rest) then
		return fail("You can only carry one pair of boots.")
	end
	if item.Tier == "Legendary" and table.find(rest, itemId) then
		return fail("You already own this item.")
	end
	if hero.Gold < price then
		return fail(`Not enough gold ({price} needed).`)
	end
	hero.Gold -= price
	table.insert(rest, item.Id)
	hero.Items = rest
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

-- Das teuerste bezahlbare Teil auf dem Weg zu einem Item (das Item selbst oder ein Bauteil)
local function nextPiece(hero, itemId: string): string?
	local price = HeroService.PriceFor(hero.Items, itemId)
	if hero.Gold >= price then
		return itemId
	end
	local best, bestCost = nil, 0
	local _, used = HeroService.PriceFor(hero.Items, itemId)
	local remaining = table.clone(Config.ItemsById[itemId].From)
	for _, component in used do
		local index = table.find(remaining, component)
		if index then
			table.remove(remaining, index)
		end
	end
	for _, component in remaining do
		local piece = nextPiece(hero, component)
		if piece and Config.ItemsById[piece].Cost > bestCost then
			best, bestCost = piece, Config.ItemsById[piece].Cost
		end
	end
	return best
end

-- Kauft nach der empfohlenen Reihenfolge, solange das Gold reicht
function HeroService:AutoBuy(hero)
	local bought = {}
	for _ = 1, 8 do
		local target
		for _, id in hero.Def.Build.Items do
			if not table.find(hero.Items, id) then
				target = id
				break
			end
		end
		if not target then
			break
		end
		-- Platz schaffen: Startgegenstaende verkaufen
		if #hero.Items >= Config.MaxItems then
			for slot, id in hero.Items do
				if Config.ItemsById[id].Tier == "Starter" then
					self:SellItem(hero, slot)
					break
				end
			end
		end
		local piece = nextPiece(hero, target)
		if not piece or not self:BuyItem(hero, piece, true) then
			break
		end
		table.insert(bought, Config.ItemsById[piece].Name)
	end
	if hero.Potions < 2 and hero.Level < 10 and hero.Gold >= 50 then
		self:BuyItem(hero, "RedTonic", true)
	end
	if #bought > 0 and hero.Player then
		self.Services.Net.SendNotify(hero.Player, "Auto-bought: " .. table.concat(bought, ", "), GOLD_COLOR)
	end
end

---------------------------------------------------------------- Rueckruf und Unterbrechen

function HeroService:Recall(hero)
	if not Combat.Alive(hero) or hero.RecallUntil or self:InFountain(hero) or Combat.IsStunned(hero) then
		return
	end
	local seconds = if activeBuff(hero, "Baron") then Config.BaronRecallSeconds else Config.RecallSeconds
	hero.RecallUntil = now() + seconds
	hero.RecallFrom = Combat.Position(hero)
	hero.RecallHP = hero.HP
	if hero.Player then
		hero.Player:SetAttribute("RecallUntil", hero.RecallUntil)
	end
	self.Services.Net.SendFx("Recall", { Model = hero.Model, Time = seconds, Color = Config.Teams[hero.Team].Color })
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

-- Betaeubung oder Tod bricht Rueckruf, Kanalisieren und Teleport ab
function HeroService:Interrupt(hero)
	self:CancelRecall(hero)
	if hero.Teleporting then
		hero.Teleporting = nil
		self.Services.Net.SendFx("RecallCancel", { Model = hero.Model })
	end
	if (hero.Status.ChannelUntil or 0) > now() then
		hero.Status.ChannelUntil = 0
		hero.Status.ReductionUntil = 0
	end
end

---------------------------------------------------------------- Faehigkeiten

function HeroService:Cast(hero, key: string, aim: Vector3?): boolean
	local ability = hero.Def.Abilities[key]
	local t = now()
	local rank = hero.Ranks[key] or 0
	if not ability or rank <= 0 or not Combat.Alive(hero) or Combat.CannotCast(hero) or (hero.Cooldowns[key] or 0) > t then
		return false
	end
	if (hero.Status.ChannelUntil or 0) > t or not self.Services.MatchService:IsPlaying() then
		return false
	end
	local cost = Config.AtRank(ability.Cost or 0, rank)
	if hero.Mana < cost then
		if hero.Player then
			self.Services.Net.SendNotify(hero.Player, "Not enough mana!", Color3.fromRGB(110, 160, 255))
		end
		return false
	end
	local ok, keepCooldown = Abilities.Cast(hero, ability, rank, aim)
	if not ok then
		return false
	end
	hero.Mana -= cost
	if not keepCooldown then
		local cooldown = Config.AtRank(ability.Cooldown, rank) * 100 / (100 + hero.AH)
		self:SetCooldown(hero, key, t + cooldown, cooldown)
	end
	self:CancelRecall(hero)
	if ability.Type ~= "Stealth" then
		hero.Status.StealthUntil = 0
	end
	if hasUnique(hero, "Spellblade") and t >= (hero.SpellbladeCD or 0) then
		hero.SpellbladeUntil = t + 10
	end
	if hero.Model then
		self.Services.Net.SendFx("Cast", { Model = hero.Model, Key = key })
	end
	self:Publish(hero)
	return true
end

---------------------------------------------------------------- Beschwoererzauber

local function spellTarget(hero, aim: Vector3?, range: number, kinds)
	local best, bestScore = nil, math.huge
	for _, unit in Combat.Units do
		if unit.Team ~= hero.Team and kinds[unit.Kind] and Combat:Targetable(unit, hero.Team) then
			local distance = Combat.Distance(hero, unit)
			if distance <= range + unit.Radius then
				local score = if aim then (Combat.Position(unit) - flat(aim)).Magnitude else distance
				if score < bestScore then
					best, bestScore = unit, score
				end
			end
		end
	end
	return best
end

function HeroService:CastSpell(hero, slot: string, aim: Vector3?): boolean
	local id = hero.Spells[slot]
	local spell = id and Config.SpellsById[id]
	local t = now()
	if not spell or not Combat.Alive(hero) or Combat.CannotCast(hero) or not self.Services.MatchService:IsPlaying() then
		return false
	end
	local smite = id == "Smite"
	if smite then
		if hero.SmiteCharges <= 0 then
			return false
		end
	elseif (hero.Cooldowns[slot] or 0) > t then
		return false
	end
	local net = self.Services.Net
	local position = Combat.Position(hero)
	local function notify(text: string)
		if hero.Player then
			net.SendNotify(hero.Player, text, RED)
		end
		return false
	end
	if id == "Flash" then
		local direction = if aim then flat(aim) - position else flat(hero.Root.CFrame.LookVector) * spell.Range
		if direction.Magnitude < 0.1 then
			direction = flat(hero.Root.CFrame.LookVector)
		end
		local destination = position + direction.Unit * math.min(spell.Range, math.max(direction.Magnitude, spell.Range))
		destination = Abilities.Walkable(position, destination)
		net.SendFx("Flash", { From = position, To = destination })
		self:Teleport(hero, destination)
	elseif id == "Heal" then
		local amount = 80 + hero.Level * 15
		Combat:Heal(hero, amount, hero)
		self:AddTemp(hero, "SpellHeal", 1, { MSPct = 0.3 })
		local weakest
		for _, ally in Combat:AlliesNear(hero.Team, position, 30, HERO_ONLY) do
			if ally ~= hero and (not weakest or ally.HP / ally.MaxHP < weakest.HP / weakest.MaxHP) then
				weakest = ally
			end
		end
		if weakest then
			Combat:Heal(weakest, amount, hero)
			self:AddTemp(weakest, "SpellHeal", 1, { MSPct = 0.3 })
		end
		net.SendFx("Heal", { At = position, Radius = 10 })
	elseif id == "Ignite" then
		local target = spellTarget(hero, aim, spell.Range, HERO_ONLY)
		if not target then
			return notify("No enemy champion in range!")
		end
		target.Status.GrievousUntil = t + 5
		Abilities.DamageOverTime(hero, target, 50 + hero.Level * 20, 5, "True")
		net.SendFx("Burn", { Model = target.Model, Time = 5 })
	elseif smite then
		local target = spellTarget(hero, aim, spell.Range, { Monster = true, Minion = true })
		if not target then
			return notify("Nothing to smite in range!")
		end
		net.SendFx("Smite", { From = position, To = Combat.Position(target) })
		Combat:Damage(hero, target, Config.SmiteDamage(hero.Level), { Type = "True" })
		if target.Kind == "Monster" then
			Combat:Heal(hero, 90 + hero.MaxHP * 0.1, hero)
		end
		hero.SmiteCharges -= 1
		if not hero.SmiteRechargeAt then
			hero.SmiteRechargeAt = t + spell.Cooldown
		end
		self:SetCooldown(hero, slot, if hero.SmiteCharges > 0 then 0 else hero.SmiteRechargeAt, spell.Cooldown)
		self:Publish(hero)
		return true
	elseif id == "Exhaust" then
		local target = spellTarget(hero, aim, spell.Range, HERO_ONLY)
		if not target then
			return notify("No enemy champion in range!")
		end
		target.Status.ExhaustUntil = t + 3
		Combat:Slow(target, 0.3, 3)
		net.SendFx("Exhaust", { Model = target.Model, Time = 3 })
	elseif id == "Barrier" then
		Combat:Shield(hero, 105 + hero.Level * 15, 2)
	elseif id == "Ghost" then
		self:AddTemp(hero, "Ghost", 8, { MSPct = 0.4 })
		net.SendFx("Buff", { Model = hero.Model, Time = 8, Color = Color3.fromRGB(200, 230, 255) })
	elseif id == "Teleport" then
		local destination = self:TeleportTarget(hero, aim)
		if not destination then
			return notify("No allied tower, minion or ward to teleport to!")
		end
		self:CancelRecall(hero)
		hero.Teleporting = { Until = t + spell.Channel, Target = destination }
		hero.Status.ChannelUntil = t + spell.Channel
		net.SendFx("Recall", { Model = hero.Model, Time = spell.Channel, Color = Color3.fromRGB(190, 110, 255) })
		net.SendFx("Marker", { At = Combat.Position(destination), Radius = 5, Time = spell.Channel, Color = Color3.fromRGB(190, 110, 255) })
	end
	local cooldown = spell.Cooldown
	self:SetCooldown(hero, slot, t + cooldown, cooldown)
	if id ~= "Teleport" then
		self:CancelRecall(hero)
	end
	self:Publish(hero)
	return true
end

-- Teleport-Ziel: eigener Turm, Minion oder Ward, der dem Zielpunkt am naechsten ist
function HeroService:TeleportTarget(hero, aim: Vector3?)
	local goal = if aim then flat(aim) else Combat.Position(hero)
	local best, bestDistance = nil, math.huge
	for _, unit in Combat.Units do
		if unit.Team == hero.Team and (unit.Kind == "Tower" or unit.Kind == "Minion" or unit.Kind == "Ward") and Combat.Alive(unit) then
			local distance = (Combat.Position(unit) - goal).Magnitude
			if distance < bestDistance then
				best, bestDistance = unit, distance
			end
		end
	end
	return best
end

---------------------------------------------------------------- Wards, Traenke, Stasis

function HeroService:PlaceWard(hero, aim: Vector3?): boolean
	if not Combat.Alive(hero) or hero.WardCharges <= 0 or not self.Services.MatchService:IsPlaying() then
		return false
	end
	local position = Combat.Position(hero)
	local point = if aim then flat(aim) else position + flat(hero.Root.CFrame.LookVector) * 8
	local offset = point - position
	if offset.Magnitude > Config.Ward.Range then
		point = position + offset.Unit * Config.Ward.Range
	end
	point = Abilities.Walkable(position, point)
	hero.WardCharges -= 1
	if not hero.WardReadyAt or hero.WardReadyAt <= now() then
		hero.WardReadyAt = now() + Config.Ward.Recharge
	end
	local model = self.Services.WorldService:MakeWard(hero.Team, point)
	local ward = Combat:Register({
		Kind = "Ward",
		Name = "Ward",
		Team = hero.Team,
		Owner = hero,
		Model = model,
		Home = point,
		HP = 3,
		MaxHP = 3,
		Range = 0,
		Damage = 0,
		AttackSpeed = 0.1,
		Radius = 1,
		Vision = Config.Ward.Vision,
		Until = now() + Config.Ward.Duration,
		FxColor = Config.Teams[hero.Team].Color,
	})
	model:SetAttribute("ExpiresAt", ward.Until)
	table.insert(self.Wards, ward)
	-- Hoechstens 3 Wards pro Held
	local own = {}
	for _, other in self.Wards do
		if other.Owner == hero then
			table.insert(own, other)
		end
	end
	if #own > 3 then
		self:RemoveWard(own[1])
	end
	self:Publish(hero)
	return true
end

function HeroService:RemoveWard(ward)
	local index = table.find(self.Wards, ward)
	if index then
		table.remove(self.Wards, index)
	end
	Combat:Unregister(ward)
	if ward.Model then
		ward.Model:Destroy()
	end
end

function HeroService:OnWardDeath(ward, killer)
	if killer and killer.Kind == "Hero" then
		self:GiveGold(killer, 30, Combat.Position(ward))
	end
	self.Services.Net.SendFx("Poof", { At = Combat.Position(ward), Color = ward.FxColor })
	self:RemoveWard(ward)
end

function HeroService:UsePotion(hero): boolean
	if not Combat.Alive(hero) or hero.Potions <= 0 or (hero.PotionUntil or 0) > now() or hero.HP >= hero.MaxHP then
		return false
	end
	hero.Potions -= 1
	hero.PotionUntil = now() + Config.Potion.Seconds
	if hero.Model then
		self.Services.Net.SendFx("Buff", { Model = hero.Model, Time = Config.Potion.Seconds, Color = Color3.fromRGB(255, 90, 110) })
	end
	self:Publish(hero)
	return true
end

function HeroService:UseStasis(hero): boolean
	local t = now()
	if not Combat.Alive(hero) or not hasUnique(hero, "Stasis") or (hero.Cooldowns.Stasis or 0) > t then
		return false
	end
	self:Interrupt(hero)
	hero.Status.StasisUntil = t + Config.StasisSeconds
	self:SetCooldown(hero, "Stasis", t + Config.StasisCooldown, Config.StasisCooldown)
	self.Services.Net.SendFx("Stasis", { Model = hero.Model, Time = Config.StasisSeconds })
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

-- Ziel nach Vorrang: "Hero" = Helden zuerst (Angriffs-Knopf), sonst Minion mit wenig Leben zuerst
function HeroService:PriorityTarget(hero, reach: number, heroFirst: boolean)
	local position = Combat.Position(hero)
	local team = hero.Team
	local function visible(list)
		local result = {}
		for _, unit in list do
			if Combat.Visible(unit, team) then
				table.insert(result, unit)
			end
		end
		return result
	end
	local heroTarget = Combat:NearestEnemy(team, position, reach, HERO_ONLY)
	if heroFirst and heroTarget then
		return heroTarget
	end
	local minion = lowest(visible(Combat:EnemiesNear(team, position, reach, MINIONS)))
	if minion then
		return minion
	end
	if heroTarget then
		return heroTarget
	end
	local monster = Combat:NearestEnemy(team, position, reach, MONSTERS)
	if monster then
		return monster
	end
	local ward = Combat:NearestEnemy(team, position, reach, { Ward = true })
	return ward or Combat:NearestEnemy(team, position, reach, Combat.STRUCTURES)
end

function HeroService:PickTarget(hero)
	local focus = hero.Focus
	if focus then
		if Combat:Targetable(focus, hero.Team) and focus.Team ~= hero.Team then
			if Combat:InRange(hero, focus, 0.5) then
				return focus
			end
			if Combat.Distance(hero, focus) > 70 then
				hero.Focus = nil
			end
			return nil -- erst hinlaufen
		end
		hero.Focus = nil
	end
	if hero.Bot then
		return nil
	end
	-- Spieler, die stillstehen, greifen automatisch an, was in Reichweite ist
	local humanoid = hero.Humanoid
	if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
		return nil
	end
	if (hero.MovedAt or 0) > now() - 0.3 then
		return nil
	end
	return self:PriorityTarget(hero, hero.Range + hero.Radius + 0.5, false)
end

---------------------------------------------------------------- Kills und Tod

function HeroService:Announce(text: string, color: Color3?, kind: string?)
	self.Services.Net.Announce:FireAllClients(text, color, kind)
end

local function teamAllDead(self, team: number): boolean
	local any = false
	for _, hero in self.Heroes do
		if hero.Team == team then
			any = true
			if not hero.Dead then
				return false
			end
		end
	end
	return any
end

-- Takedown fuer Passive (Pip, Volt) und Rang-Reset (Varg)
function HeroService:OnTakedown(hero, victim)
	Abilities.OnTakedown(hero, victim)
end

function HeroService:OnUnitKilled(hero, unit)
	Abilities.OnUnitKilled(hero, unit)
end

function HeroService:OnTakedownStructure(hero)
	Abilities.OnTakedownStructure(hero)
end

-- Seelen fuer Gaff: Gegner, die in der Naehe sterben
function HeroService:CollectSouls(unit)
	if unit.Kind ~= "Hero" and unit.Kind ~= "Minion" and unit.Kind ~= "Monster" then
		return
	end
	local position = Combat.Position(unit)
	for _, hero in self.Heroes do
		if hero.Def.Passive.Id == "Souls" and hero.Team ~= unit.Team and Combat.Alive(hero) and (Combat.Position(hero) - position).Magnitude <= 30 then
			local chance = if unit.Kind == "Hero" or unit.Epic then 1 elseif unit.Kind == "Monster" then 0.3 else 0.12
			if math.random() < chance then
				hero.Souls = (hero.Souls or 0) + 1
				self.Services.Net.SendFx("Soul", { From = position, Model = hero.Model })
				self:Recompute(hero)
			end
		end
	end
end

function HeroService:OnDeath(hero, killer)
	if hero.Removed then
		return
	end
	self:Interrupt(hero)
	hero.Dead = true
	hero.HP = 0
	hero.Deaths += 1
	hero.Empower = nil
	hero.Focus = nil
	local t = now()
	local level = hero.Level
	hero.RespawnAt = t + Config.RespawnTime(level, elapsed())
	local killerHero = if killer and killer.Kind == "Hero" then killer else nil
	if not killerHero then
		-- Hingerichtet von Turm oder Minion: der letzte Held, der Schaden machte, bekommt den Kill
		local latest = 0
		for other, time in hero.Damagers do
			if time > latest and t - time <= Config.AssistWindow and other.Team ~= hero.Team then
				killerHero, latest = other, time
			end
		end
	end
	local position = Combat.Position(hero)
	local killerTeam = enemyOf(hero.Team)
	local net = self.Services.Net
	local teamColor = Config.Teams[killerTeam].Color

	-- Blau- und Rot-Buff gehen an den Killer ueber; Baron und Aelterer verfallen
	for _, id in { "Blue", "Red" } do
		local left = (hero.Buffs[id] or 0) - t
		if left > 0 and killerHero then
			self:GiveBuff(killerHero, id, left)
		end
	end
	hero.Buffs = {}
	hero.Temp = {}

	local shutdown = 0
	if hero.Streak >= 3 then
		shutdown = math.min(500, 150 + 50 * (hero.Streak - 3))
	end
	if killerHero then
		local gold = Config.KillGold
		if hero.DeathStreak >= 1 then
			gold *= math.max(0.35, 1 - 0.15 * hero.DeathStreak)
		end
		if not self.FirstBlood then
			self.FirstBlood = true
			gold += Config.FirstBloodGold
			self:Announce("FIRST BLOOD!", teamColor, "Kill")
		end
		killerHero.Kills += 1
		killerHero.Streak += 1
		killerHero.DeathStreak = 0
		if (killerHero.LastKillAt or 0) > t - Config.MultiKillWindow then
			killerHero.Multi = (killerHero.Multi or 1) + 1
		else
			killerHero.Multi = 1
		end
		killerHero.LastKillAt = t
		self:GiveGold(killerHero, gold + shutdown, position)
		local assisters = {}
		for _, helper in Combat:RecentDamagers(hero, killerHero) do
			if helper.Kind == "Hero" and not helper.Removed then
				table.insert(assisters, helper)
			end
		end
		for _, helper in assisters do
			helper.Assists += 1
			self:GiveGold(helper, Config.AssistGold / #assisters, position)
			self:OnTakedown(helper, hero)
			self:Publish(helper)
		end
		self:OnTakedown(killerHero, hero)
		self:Publish(killerHero)
		if shutdown > 0 then
			self:Announce(`{killerHero.Name} shut down {hero.Name}!`, teamColor, "Kill")
		end
		local multi = MULTI[math.min(killerHero.Multi, 5)]
		if killerHero.Multi >= 2 and multi then
			self:Announce(`{killerHero.Name}: {multi}`, teamColor, "Multi")
		elseif STREAKS[math.min(killerHero.Streak, 7)] and killerHero.Streak >= 3 then
			local text = if killerHero.Streak >= 8 then "is legendary!" else STREAKS[killerHero.Streak]
			self:Announce(`{killerHero.Name} {text}`, teamColor, "Streak")
		end
	end
	hero.Streak = 0
	hero.DeathStreak += 1
	self:ShareXP(killerTeam, position, Config.KillXP + level * 25)
	net.KillFeed:FireAllClients({
		Killer = if killerHero then killerHero.Name elseif killer then killer.Name else "The Rift",
		KillerHero = if killerHero then killerHero.HeroId else nil,
		KillerTeam = killerTeam,
		Victim = hero.Name,
		VictimHero = hero.HeroId,
		VictimTeam = hero.Team,
		Shutdown = shutdown > 0,
	})
	if teamAllDead(self, hero.Team) then
		self:Announce("ACE!", teamColor, "Ace")
	end
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
		net.SendFx("Poof", { At = position, Color = Config.Teams[hero.Team].Color })
	end
end

function HeroService:RespawnNow(hero)
	if hero and hero.Dead and not hero.Removed then
		hero.RespawnAt = now()
	end
end

---------------------------------------------------------------- Takt

local function regen(self, hero, dt: number, t: number, inFountain: boolean)
	local hp = hero.HPRegen * dt
	local mana = hero.ManaRegen * dt
	if activeBuff(hero, "Blue") then
		mana += hero.MaxMana * Config.Buffs.Blue.ManaRegenPct * dt
	end
	local ocean = hero.Drakes and hero.Drakes.Ocean or 0
	if ocean > 0 then
		hp += (hero.MaxHP - hero.HP) * Config.DrakesById.Ocean.RegenPct * ocean * dt
	end
	if hasUnique(hero, "Regen") and t - (hero.LastDamagedAt or 0) > 6 then
		hp += hero.MaxHP * 0.03 * dt
	end
	if (hero.PotionUntil or 0) > t then
		hp += Config.Potion.Heal / Config.Potion.Seconds * dt
	end
	if inFountain then
		hp += hero.MaxHP * Config.FountainHeal * dt
		mana += hero.MaxMana * Config.FountainHeal * dt
	end
	if (hero.Status.GrievousUntil or 0) > t then
		hp *= 0.6
	end
	if hero.HP < hero.MaxHP and hp > 0 then
		hero.HP = math.min(hero.MaxHP, hero.HP + hp)
		Combat:Sync(hero)
	end
	hero.Mana = math.min(hero.MaxMana, hero.Mana + mana)
	if inFountain then
		hero.PotionUntil = 0
	end
end

local function expire(self, hero, t: number)
	local changed = false
	for id, until_ in hero.Buffs do
		if until_ <= t then
			hero.Buffs[id] = nil
			changed = true
		end
	end
	for id, entry in hero.Temp do
		if entry.Until <= t then
			hero.Temp[id] = nil
			changed = true
		end
	end
	if hero.SpellForce and (hero.SpellForceUntil or 0) <= t then
		hero.SpellForce = nil
		changed = true
	end
	if hero.Bloodlust and hero.Bloodlust <= t then
		hero.Bloodlust = nil
		changed = true
	end
	if hero.Shred and (hero.ShredUntil or 0) <= t then
		hero.Shred = nil
	end
	if changed then
		self:Recompute(hero)
	end
end

local function charges(self, hero, t: number)
	if hero.WardCharges < Config.Ward.Charges and hero.WardReadyAt and t >= hero.WardReadyAt then
		hero.WardCharges += 1
		hero.WardReadyAt = if hero.WardCharges < Config.Ward.Charges then t + Config.Ward.Recharge else nil
		self:Publish(hero)
	end
	local smite = Config.SpellsById.Smite
	if hero.SmiteRechargeAt and t >= hero.SmiteRechargeAt then
		hero.SmiteCharges = math.min(smite.Charges, hero.SmiteCharges + 1)
		hero.SmiteRechargeAt = if hero.SmiteCharges < smite.Charges then t + smite.Cooldown else nil
		local slot = if hero.Spells.D == "Smite" then "D" else "F"
		self:SetCooldown(hero, slot, 0, smite.Cooldown)
		self:Publish(hero)
	end
	-- Smite laedt sich erst mit der Zeit auf 2 Ladungen (wie im Original nach einigen Minuten)
	if (hero.Spells.D == "Smite" or hero.Spells.F == "Smite") and hero.SmiteCharges < smite.Charges and not hero.SmiteRechargeAt then
		hero.SmiteRechargeAt = t + smite.Cooldown
	end
end

function HeroService:Tick(dt: number)
	local t = now()
	local playing = self.Services.MatchService:IsPlaying()
	local gold = playing and elapsed() >= Config.Timers.Minions
	for _, ward in table.clone(self.Wards) do
		if t >= ward.Until or ward.Owner.Removed then
			self:RemoveWard(ward)
		end
	end
	for _, hero in table.clone(self.Heroes) do
		if hero.Removed then
			continue
		end
		if gold then
			hero.Gold += Config.PassiveGold * dt
		end
		charges(self, hero, t)
		if hero.Dead then
			if playing and hero.RespawnAt and t >= hero.RespawnAt then
				hero.RespawnAt = nil
				task.spawn(self.Spawn, self, hero)
			end
			if hero.Player then
				hero.Player:SetAttribute("Gold", math.floor(hero.Gold))
			end
			continue
		end
		if not Combat.Alive(hero) then
			continue
		end
		local position = Combat.Position(hero)
		expire(self, hero, t)
		local inFountain = (position - MAP.Fountain[hero.Team]).Magnitude <= MAP.FountainRadius + 2
		if inFountain and not hero.WasInFountain and hero.AutoBuy then
			self:AutoBuy(hero)
		end
		hero.WasInFountain = inFountain
		regen(self, hero, dt, t, inFountain)
		Abilities.Tick(hero, dt, t)
		if hero.Dead then
			continue
		end
		-- Gegnerischer Brunnen: toedlicher Laser
		if (position - MAP.Fountain[enemyOf(hero.Team)]).Magnitude <= MAP.FountainRadius + 6 then
			Combat:Damage(nil, hero, Config.FountainDamage * dt, { Type = "True" })
			if hero.Dead then
				continue
			end
		end
		-- Laufgeschwindigkeit
		if hero.Humanoid then
			local speed = hero.Speed * Combat.SlowFactor(hero) * Abilities.SpeedFactor(hero)
			if Combat.IsRooted(hero) or not playing then
				speed = 0
			end
			if math.abs(hero.Humanoid.WalkSpeed - speed) > 0.05 then
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
		-- Teleport-Zauber
		local teleport = hero.Teleporting
		if teleport and t >= teleport.Until then
			hero.Teleporting = nil
			local target = teleport.Target
			if not Combat.Alive(target) then
				target = self:TeleportTarget(hero, Combat.Position(target))
			end
			if target then
				self:Teleport(hero, Combat.Position(target) + Config.Mirror(Vector3.new(3, 0, -3), hero.Team))
				self.Services.Net.SendFx("Flash", { From = position, To = Combat.Position(target) })
			end
		end
		-- Auto-Angriff
		if playing and not hero.RecallUntil and not hero.Teleporting and Combat:CanAttack(hero) then
			local target = self:PickTarget(hero)
			if target and Combat:InRange(hero, target, 0.5) then
				Abilities.Attack(hero, target)
			end
		end
		if hero.Player then
			local player = hero.Player
			player:SetAttribute("Gold", math.floor(hero.Gold))
			player:SetAttribute("CanShop", self:CanShop(hero))
			local mana = math.floor(hero.Mana)
			if player:GetAttribute("Mana") ~= mana then
				player:SetAttribute("Mana", mana)
			end
		end
		if hero.Model and hero.Model:GetAttribute("Mana") ~= math.floor(hero.Mana) then
			hero.Model:SetAttribute("Mana", math.floor(hero.Mana))
		end
	end
end

---------------------------------------------------------------- Start

local function aimOf(value: any): Vector3?
	if typeof(value) == "Vector3" and value.Magnitude < 1000 then
		return value
	end
	return nil
end

function HeroService:Start()
	local net = self.Services.Net
	net.Cast.OnServerEvent:Connect(function(player, key, aim)
		local hero = self:GetByPlayer(player)
		if hero and typeof(key) == "string" and hero.Def.Abilities[key] then
			self:Cast(hero, key, aimOf(aim))
		end
	end)
	net.LevelUp.OnServerEvent:Connect(function(player, key)
		local hero = self:GetByPlayer(player)
		if hero and typeof(key) == "string" then
			if key == "Auto" then
				self:AutoLevel(hero)
			else
				self:LevelAbility(hero, key)
			end
		end
	end)
	net.CastSpell.OnServerEvent:Connect(function(player, slot, aim)
		local hero = self:GetByPlayer(player)
		if hero and (slot == "D" or slot == "F") then
			self:CastSpell(hero, slot, aimOf(aim))
		end
	end)
	net.UseItem.OnServerEvent:Connect(function(player, kind, aim)
		local hero = self:GetByPlayer(player)
		if not hero then
			return
		end
		if kind == "Potion" then
			self:UsePotion(hero)
		elseif kind == "Stasis" then
			self:UseStasis(hero)
		elseif kind == "Ward" then
			self:PlaceWard(hero, aimOf(aim))
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
	net.Attack.OnServerEvent:Connect(function(player, heroFirst)
		-- Angriffs-Knopf: bestes Ziel in der Naehe waehlen und dem Spieler zuruecksenden
		local hero = self:GetByPlayer(player)
		if not hero or not Combat.Alive(hero) then
			return
		end
		local target = self:PriorityTarget(hero, hero.Range + 10, heroFirst ~= false)
		hero.Focus = target
		net.Focus:FireClient(player, if target then target.Model else nil)
	end)
	net.Move.OnServerEvent:Connect(function(player)
		local hero = self:GetByPlayer(player)
		if hero then
			hero.MovedAt = now()
			hero.Focus = nil
		end
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
