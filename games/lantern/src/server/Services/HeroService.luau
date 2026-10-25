-- Der Held: Werte aus der Ausruestung, Erfahrung und Stufen, Gold, Schaden/Heilung,
-- Tod und Wiederbelebung, Klassenwahl und die sichtbare Waffe in der Hand.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local HeroService = { Services = nil :: any }

local heroStats = {} -- [Player] = Items.Stats
local potionReady = {} -- [Player] = os.clock()
local GOLD = Color3.fromRGB(255, 200, 60)

function HeroService:Init(services)
	self.Services = services
end

function HeroService:GetStats(player: Player): Items.Stats
	return heroStats[player] or Items.TotalStats("Knight", 1, {})
end

function HeroService:GetEquipped(player: Player): { Items.Item }
	local data = self.Services.DataService:Get(player)
	local list = {}
	if not data then
		return list
	end
	for _, item in data.Inventory do
		if data.Equipped[item.Slot] == item.Id then
			table.insert(list, item)
		end
	end
	return list
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------- Waffe in der Hand

local function weaponPart(parent: Instance, props): Part
	local p = Instance.new("Part")
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function attach(handle: BasePart, p: BasePart, offset: CFrame)
	p.CFrame = handle.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
end

-- Werkzeug-Griff zeigt bei gehaltener Waffe nach oben (+Y), also wird alles entlang +Y gebaut
local function buildTool(classKey: string, weapon: Items.Item?): Tool
	local tool = Instance.new("Tool")
	tool.Name = Items.Noun("Weapon", classKey)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = true
	local handle = weaponPart(tool, { Name = "Handle", Size = Vector3.new(0.35, 1.2, 0.35), Color = Color3.fromRGB(90, 62, 44), Material = Enum.Material.Wood })
	local rarity = weapon and Config.Rarities[weapon.Rarity]
	local glow = rarity and rarity.Color or Color3.fromRGB(220, 220, 230)
	local shiny = weapon ~= nil and weapon.Rarity >= 2
	local metal = Color3.fromRGB(205, 210, 220)
	local function part(props, offset)
		local p = weaponPart(tool, props)
		attach(handle, p, offset)
		return p
	end
	local tip
	if classKey == "Knight" then
		part({ Name = "Guard", Size = Vector3.new(1.4, 0.25, 0.4), Color = GOLD, Material = Enum.Material.Metal }, CFrame.new(0, 0.7, 0))
		tip = part({ Name = "Blade", Size = Vector3.new(0.4, 3.4, 0.14), Color = if shiny then glow else metal, Material = if shiny then Enum.Material.Neon else Enum.Material.Metal }, CFrame.new(0, 2.5, 0))
	elseif classKey == "Ranger" then
		for i, angle in { -28, 0, 28 } do
			local y = (i - 2) * 1.5
			part({ Name = "Limb", Size = Vector3.new(0.22, 1.7, 0.3), Color = Color3.fromRGB(120, 82, 50), Material = Enum.Material.Wood }, CFrame.new(0, y + 0.0, -0.35 + math.abs(i - 2) * 0.4) * CFrame.Angles(math.rad(angle), 0, 0))
		end
		tip = part({ Name = "String", Size = Vector3.new(0.06, 4.2, 0.06), Color = if shiny then glow else Color3.fromRGB(240, 240, 230), Material = if shiny then Enum.Material.Neon else Enum.Material.SmoothPlastic }, CFrame.new(0, 0, 0.45))
	elseif classKey == "Mage" then
		part({ Name = "Shaft", Size = Vector3.new(0.3, 4.6, 0.3), Color = Color3.fromRGB(100, 70, 120), Material = Enum.Material.Wood }, CFrame.new(0, 1.4, 0))
		tip = part({ Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = if shiny then glow else Color3.fromRGB(170, 120, 255), Material = Enum.Material.Neon }, CFrame.new(0, 4, 0))
	else
		part({ Name = "Shaft", Size = Vector3.new(0.28, 3, 0.28), Color = GOLD, Material = Enum.Material.Metal }, CFrame.new(0, 1, 0))
		tip = part({ Name = "Star", Size = Vector3.new(0.8, 0.8, 0.8), Color = if shiny then glow else Color3.fromRGB(255, 240, 170), Material = Enum.Material.Neon }, CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(45)))
	end
	tip.Name = "Tip"
	if weapon and weapon.Rarity >= 3 then
		local l = Instance.new("PointLight")
		l.Color = glow
		l.Range = 8 + weapon.Rarity * 2
		l.Brightness = 1.5
		l.Parent = tip
	end
	if weapon and weapon.Rarity >= 5 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Color = ColorSequence.new(glow)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(0.3, 0)
		sparkles.Lifetime = NumberRange.new(0.5, 1)
		sparkles.Rate = 12
		sparkles.Speed = NumberRange.new(0.5, 1)
		sparkles.Parent = tip
	end
	return tool
end

local function decorate(character: Model, classKey: string)
	for _, child in character:GetChildren() do
		if child:GetAttribute("ClassGear") then
			child:Destroy()
		end
	end
	local function gear(anchorName: string, fallback: string, props, offset: CFrame)
		local anchor = character:FindFirstChild(anchorName) or character:FindFirstChild(fallback)
		if not anchor or not anchor:IsA("BasePart") then
			return
		end
		local p = weaponPart(character, props)
		p:SetAttribute("ClassGear", true)
		attach(anchor, p, offset)
	end
	if classKey == "Knight" then
		gear("LeftHand", "Left Arm", { Name = "Shield", Size = Vector3.new(0.25, 2.4, 2), Color = Color3.fromRGB(60, 90, 170), Material = Enum.Material.Metal }, CFrame.new(-0.45, 0.2, 0))
		gear("LeftHand", "Left Arm", { Name = "ShieldEmblem", Size = Vector3.new(0.1, 1, 1), Color = GOLD, Material = Enum.Material.Neon }, CFrame.new(-0.6, 0.2, 0) * CFrame.Angles(math.rad(45), 0, 0))
	elseif classKey == "Ranger" then
		gear("UpperTorso", "Torso", { Name = "Quiver", Size = Vector3.new(0.7, 2, 0.7), Color = Color3.fromRGB(110, 76, 50), Material = Enum.Material.Leather }, CFrame.new(0.3, 0.2, 0.7) * CFrame.Angles(0, 0, math.rad(-20)))
	elseif classKey == "Mage" then
		gear("Head", "Head", { Name = "HatBrim", Size = Vector3.new(2.4, 0.15, 2.4), Color = Color3.fromRGB(80, 50, 130) }, CFrame.new(0, 0.75, 0))
		gear("Head", "Head", { Name = "HatTop", Size = Vector3.new(1.1, 1.4, 1.1), Color = Color3.fromRGB(80, 50, 130) }, CFrame.new(0, 1.5, 0.1) * CFrame.Angles(math.rad(-12), 0, 0))
	elseif classKey == "Lightbringer" then
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			gear("Head", "Head", { Name = "Halo", Size = Vector3.new(0.35, 0.12, 0.35), Color = Color3.fromRGB(255, 230, 140), Material = Enum.Material.Neon }, CFrame.new(math.cos(a) * 0.8, 1.2, math.sin(a) * 0.8))
		end
	end
end

function HeroService:EquipVisuals(player: Player)
	local character = player.Character
	local humanoid = humanoidOf(player)
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local data = self.Services.DataService:Get(player)
	local classKey = data and data.Class or "Knight"
	local weapon
	for _, item in self:GetEquipped(player) do
		if item.Slot == "Weapon" then
			weapon = item
		end
	end
	local signature = classKey .. ":" .. (weapon and (weapon.Id .. weapon.Plus) or "none")
	if character:GetAttribute("GearSignature") == signature then
		return
	end
	character:SetAttribute("GearSignature", signature)
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			child:Destroy()
		end
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end
	local tool = buildTool(classKey, weapon)
	tool.Parent = backpack or character
	humanoid:EquipTool(tool)
	decorate(character, classKey)
end

-- Holt die Waffe fuer den Hieb-/Zauber-Ausholer der Standard-Animation ("toolanim")
function HeroService:PlaySwing(player: Player, kind: string?)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool then
		local anim = Instance.new("StringValue")
		anim.Name = "toolanim"
		anim.Value = kind or "Slash"
		anim.Parent = tool
		task.delay(0.3, function()
			anim:Destroy()
		end)
	end
end

---------------------------------------------------------------- Werte

function HeroService:RefreshStats(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local stats = Items.TotalStats(data.Class, data.Level, self:GetEquipped(player))
	heroStats[player] = stats
	for _, key in { "Damage", "Health", "Armor", "Crit", "CritDamage", "AttackSpeed", "MoveSpeed", "GoldFind", "LifeOnKill", "Cooldown", "GearScore" } do
		player:SetAttribute("Stat_" .. key, (stats :: any)[key])
	end
	player:SetAttribute("GearScore", stats.GearScore)
	local powers = {}
	for key in stats.Powers do
		table.insert(powers, key)
	end
	player:SetAttribute("Powers", table.concat(powers, ","))
	local humanoid = humanoidOf(player)
	if humanoid then
		local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = stats.Health
		if humanoid.Health > 0 then
			humanoid.Health = math.max(1, stats.Health * ratio)
		end
		humanoid.WalkSpeed = 17 * (1 + stats.MoveSpeed / 100)
	end
	self.Services.DataService:UpdateAttributes(player)
	self:EquipVisuals(player)
end

-- Schrein-Buff aktiv? (Attribut = Serverzeit, bis wann er gilt)
function HeroService:HasBuff(player: Player, key: string): boolean
	return (tonumber(player:GetAttribute("Buff_" .. key)) or 0) > workspace:GetServerTimeNow()
end

-- Bonus aus VIP, Premium und Freunden (fuer Gold und XP)
function HeroService:Bonus(player: Player): number
	local bonus = 1
	if player:GetAttribute("Pass_VIP") then
		bonus += Config.VipBonus
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		bonus += Config.PremiumBonus
	end
	bonus += (player:GetAttribute("FriendBonus") or 0)
	return bonus
end

function HeroService:AddXP(player: Player, base: number): number
	local data = self.Services.DataService:Get(player)
	if not data or data.Level >= Config.MaxLevel then
		return 0
	end
	local mult = self:Bonus(player)
	if player:GetAttribute("Pass_DoubleXP") then
		mult *= Config.DoubleXPMultiplier
	end
	if data.XPBoostUntil > os.time() then
		mult *= 2
	end
	local amount = math.max(1, math.floor(base * mult))
	data.XP += amount
	local leveled = false
	while data.Level < Config.MaxLevel and data.XP >= Config.XPToLevel(data.Level) do
		data.XP -= Config.XPToLevel(data.Level)
		data.Level += 1
		leveled = true
	end
	if leveled then
		self:RefreshStats(player)
		local humanoid = humanoidOf(player)
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.MaxHealth
		end
		local run = self.Services.DungeonService:GetRun(player)
		self.Services.Net.SendEffect(if run then run.Players else { player }, "LevelUp", { Player = player, Level = data.Level })
		if data.Level % 10 == 0 then
			self.Services.Net.SendAnnounce(`{player.DisplayName} reached level {data.Level}!`, GOLD)
		end
		local unlock = Config.Classes.Lightbringer.UnlockLevel
		if data.Level == unlock and not player:GetAttribute("Pass_Lightbringer") then
			self.Services.Net.SendNotify(player, "The Lightbringer class is now unlocked! Visit the Class Shrine.", GOLD)
		end
		self.Services.RewardService:UpdateLeaderboardEntry(player)
		self.Services.ProgressService:CheckAchievements(player)
	else
		self.Services.DataService:UpdateAttributes(player)
	end
	return amount
end

function HeroService:GiveGold(player: Player, base: number, position: Vector3?): number
	local stats = self:GetStats(player)
	local fortune = if self:HasBuff(player, "Fortune") then 1.5 else 1
	local amount = math.max(1, math.floor(base * self:Bonus(player) * (1 + stats.GoldFind / 100) * fortune))
	self.Services.DataService:AddGold(player, amount)
	if position then
		self.Services.Net.Effect:FireClient(player, "Gold", { Position = position, Amount = amount })
	end
	return amount
end

---------------------------------------------------------------- Schaden und Heilung

function HeroService:DamagePlayer(player: Player, amount: number, monsterLevel: number)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local stats = self:GetStats(player)
	local final = amount * (1 - Config.ArmorReduction(stats.Armor, monsterLevel))
	if (player:GetAttribute("ShieldUntil") or 0) > os.clock() then
		final *= 0.5
	end
	if self:HasBuff(player, "Warding") then
		final *= 0.6
	end
	final = math.max(1, math.floor(final))
	humanoid:TakeDamage(final)
	self.Services.Net.Effect:FireClient(player, "Hurt", { Amount = final })
end

function HeroService:Heal(player: Player, amount: number, show: boolean?)
	local humanoid = humanoidOf(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local before = humanoid.Health
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	local healed = math.floor(humanoid.Health - before)
	if show and healed > 0 then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local run = self.Services.DungeonService:GetRun(player)
		if root then
			self.Services.Net.SendEffect(if run then run.Players else { player }, "Heal", { Position = root.Position, Amount = healed })
		end
	end
end

---------------------------------------------------------------- Charakter, Tod

function HeroService:OnCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local stats = self:GetStats(player)
	humanoid.MaxHealth = stats.Health
	humanoid.Health = stats.Health
	humanoid.WalkSpeed = 17 * (1 + stats.MoveSpeed / 100)
	humanoid.BreakJointsOnDeath = false
	-- Kein Springen (wie in einem Action-RPG); blendet auch den Sprungknopf auf dem Handy aus
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.Died:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local position = if root then root.Position else Vector3.zero
		local run = self.Services.DungeonService:GetRun(player)
		if run then
			self.Services.Net.SendEffect(run.Players, "PlayerDown", { Name = player.DisplayName, Position = position })
			self.Services.DungeonService:OnPlayerDied(player, position)
		else
			task.delay(Config.TownRespawn, function()
				if player.Parent and player.Character == character then
					player:LoadCharacter()
				end
			end)
		end
	end)
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	if player.Character ~= character then
		return
	end
	character:SetAttribute("GearSignature", nil)
	self:EquipVisuals(player)
end

function HeroService:Start()
	local services = self.Services
	local Net = services.Net
	Net.Handle("Potion", function(player)
		local now = os.clock()
		if now < (potionReady[player] or 0) then
			return false
		end
		local humanoid = humanoidOf(player)
		if not humanoid or humanoid.Health <= 0 then
			return false
		end
		-- Trank-Meisterschaft: mehr Heilung, kuerzere Abklingzeit
		local data = services.DataService:Get(player)
		local level = data and data.PotionLevel or 0
		local cooldown = Config.PotionCooldownFor(level)
		potionReady[player] = now + cooldown * 0.9
		self:Heal(player, humanoid.MaxHealth * Config.PotionHealFor(level), true)
		return true, cooldown
	end)

	Net.Handle("SetClass", function(player, classKey)
		local data = services.DataService:Get(player)
		local class = typeof(classKey) == "string" and Config.Classes[classKey]
		if not data or not class then
			return false
		end
		if services.DungeonService:GetRun(player) then
			Net.SendNotify(player, "You can only change your class in town.", Color3.fromRGB(255, 90, 90))
			return false
		end
		if class.UnlockLevel and data.Level < class.UnlockLevel and not player:GetAttribute("Pass_Lightbringer") then
			services.MonetizationService:PromptPass(player, "Lightbringer")
			return false
		end
		data.Class = classKey
		data.ClassChosen = true
		self:RefreshStats(player)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
		services.ProgressService:Track(player, "SetClass")
		return true
	end)

	-- Lantern Sprite (Pass): schiesst jede Sekunde auf das naechste Monster
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if not player:GetAttribute("Pass_Sprite") then
					continue
				end
				-- Ein Fehler bei einem Spieler darf den Begleiter nicht fuer den ganzen Server stoppen
				local ok, err = pcall(function()
					local run = services.DungeonService:GetRun(player)
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local humanoid = humanoidOf(player)
					if not run or not root or not humanoid or humanoid.Health <= 0 then
						return
					end
					local target, best = nil, Config.SpriteRange
					for _, state in services.MonsterService:ForRun(run) do
						local d = (state.Root.Position - root.Position).Magnitude
						if d < best then
							target, best = state, d
						end
					end
					if target then
						local from = root.Position + Vector3.new(1.5, 3, 1)
						Net.SendEffect(run.Players, "SpriteBolt", { From = from, To = target.Root.Position })
						services.CombatService:DealDamage(player, target, self:GetStats(player).Damage * Config.SpriteDamage, false)
					end
				end)
				if not ok then
					warn("[Hero] Sprite", err)
				end
			end
		end
	end)
end

function HeroService:OnPlayerRemoving(player: Player)
	heroStats[player] = nil
	potionReady[player] = nil
end

return HeroService
