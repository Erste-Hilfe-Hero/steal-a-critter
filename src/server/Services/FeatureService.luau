-- Update 3: Eier, Training, Tresor, Alarm, Rebirth-Perks, Critter Pass, Klau-Combo, Edelstein-Jagd,
-- Likes, Basis besuchen, Geld schenken, Heim-Teleport, Boss-Raid, Speed-Pads, Tag/Nacht, goldene Kreatur,
-- Kumpel (Kreatur laeuft hinterher), Basis-Farben, Statistiken und Einstellungen.
-- Der Client (Features.luau) bekommt alles ueber ProgressService:SetExtra("Features", ...).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Units = require(ReplicatedStorage.Shared.Units)
local UnitFactory = require(script.Parent.UnitFactory)

local FeatureService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)

local eggsById = {}
for _, egg in Config.Eggs do
	eggsById[egg.Id] = egg
end
local perksById = {}
for _, perk in Config.Perks do
	perksById[perk.Id] = perk
end
local unitsByRarity = {}
for _, def in Config.Units do
	unitsByRarity[def.Rarity] = unitsByRarity[def.Rarity] or {}
	table.insert(unitsByRarity[def.Rarity], def)
end

local combos = {} -- [Player] = { Count, Until }
local buddies = {} -- [Player] = { Code, Model }
local speedUntil = {} -- [Player] = os.clock()
local alarmSlowed = {} -- [Player] = true (Dieb ist durch Alarm langsamer)
local nightUntil = 0
local boss = nil :: any

function FeatureService:Init(services)
	self.Services = services
end

local function notify(player: Player, text: string, color: Color3?)
	FeatureService.Services.Net.SendNotify(player, text, color)
end

local function today(): number
	return os.time() // 86400
end

local function dataOf(player: Player)
	return FeatureService.Services.DataService:Get(player)
end

local function income(player: Player): number
	return tonumber(player:GetAttribute("IncomePerSec")) or 0
end

local function incomeReward(player: Player, seconds: number, minCash: number): number
	return math.floor(math.max(minCash, income(player) * seconds))
end

local function track(player: Player, stat: string, amount: number?)
	FeatureService.Services.ProgressService:Track(player, stat, amount)
end

---------------------------------------------------------------- Stand fuer den Client

local function passTier(xp: number): (number, number, number)
	-- Liefert erreichte Stufe, XP in der aktuellen Stufe und XP fuer die naechste
	local tier = 0
	while tier < Config.PassTiers and xp >= Config.PassXP(tier) do
		xp -= Config.PassXP(tier)
		tier += 1
	end
	return tier, xp, Config.PassXP(tier)
end

-- Belohnung einer Pass-Stufe (1..PassTiers)
local function passReward(player: Player, tier: number)
	if tier % 10 == 0 then
		return { Kind = "Tokens", Amount = 1, Text = "+1 Rebirth Token" }
	elseif tier % 5 == 0 then
		return { Kind = "Catalyst", Amount = 1, Text = "Fusion Catalyst" }
	elseif tier % 4 == 0 then
		return { Kind = "Egg", Egg = if tier >= 20 then "Rare" else "Basic", Text = (if tier >= 20 then "Rare" else "Basic") .. " Egg" }
	end
	local cash = incomeReward(player, 60 * (2 + tier * 0.5), 500 * tier)
	return { Kind = "Cash", Amount = cash, Text = Format.Cash(cash) }
end

function FeatureService:Refresh(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	local units = {}
	for slotKey, code in data.Units do
		local info = Units.Info(code)
		if info then
			local level = data.Levels[slotKey] or 0
			table.insert(units, {
				Slot = slotKey,
				Name = info.Name,
				Rarity = info.Rarity,
				Income = info.Income * (1 + level * Config.TrainBonusPer),
				Level = level,
				TrainCost = if level < Config.TrainMaxLevel then math.floor(info.Value * Config.TrainCostShare * (level + 1)) else 0,
				VaultCost = math.floor(info.Value * Config.VaultCostShare),
				Vault = data.Vault == slotKey,
			})
		end
	end
	table.sort(units, function(a, b)
		return a.Income > b.Income
	end)
	local tier, xpIn, xpNeed = passTier(data.PassXP or 0)
	local rewards = {}
	for i = 1, Config.PassTiers do
		rewards[i] = passReward(player, i).Text
	end
	local liked = {}
	for key, day in data.LikesGiven do
		if day == today() then
			liked[key] = true
		end
	end
	self.Services.ProgressService:SetExtra(player, "Features", {
		Units = units,
		Tokens = data.Tokens or 0,
		Perks = table.clone(data.Perks),
		PassXP = data.PassXP or 0,
		PassTier = tier,
		PassXPIn = xpIn,
		PassXPNeed = xpNeed,
		PassClaimed = data.PassClaimed or 0,
		PassRewards = rewards,
		Likes = data.Likes or 0,
		Liked = liked,
		GiftsLeft = if data.GiftDay == today() then math.max(0, Config.GiftMaxPerDay - data.GiftsToday) else Config.GiftMaxPerDay,
		Alarm = data.Alarm == true,
		BaseColor = data.BaseColor or "",
		Settings = table.clone(data.Settings),
		Earned = data.TotalEarned or 0,
		PlayTime = data.PlayTime or 0,
		Rebirths = data.Rebirths or 0,
		Referrals = data.Referrals or 0,
	})
end

---------------------------------------------------------------- Einkommen und Werte fuer andere Services

-- Training: Faktor fuer eine Kreatur in einem Slot
function FeatureService:LevelFactor(player: Player, slotKey: string): number
	local data = dataOf(player)
	local level = data and data.Levels and data.Levels[slotKey] or 0
	return 1 + level * Config.TrainBonusPer
end

-- Zusaetzlicher Multiplikator: Cash-Perk, Likes, Kumpel
function FeatureService:GetMultiplier(player: Player): number
	local data = dataOf(player)
	if not data then
		return 1
	end
	local multiplier = 1 + (data.Perks.Cash or 0) * perksById.Cash.Per
	multiplier *= 1 + math.min((data.Likes or 0) * Config.LikeBonusPer, Config.LikeBonusMax)
	if buddies[player] then
		multiplier *= 1 + Config.BuddyBonus
	end
	return multiplier
end

function FeatureService:NightLuck(): number
	return if workspace:GetServerTimeNow() < nightUntil then Config.NightLuck else 1
end

-- Wird aufgerufen, wenn eine Kreatur den Slot verlaesst (verkauft, geklaut, fusioniert, Rebirth)
function FeatureService:OnSlotCleared(player: Player, slotKey: string)
	local data = dataOf(player)
	if not data then
		return
	end
	data.Levels[slotKey] = nil
	if data.Vault == slotKey then
		data.Vault = ""
		self:UpdateVault(player)
	end
	self:Refresh(player)
end

function FeatureService:IsVaulted(owner: Player, slotKey: string): boolean
	local data = dataOf(owner)
	return data ~= nil and data.Vault == slotKey
end

function FeatureService:StealHoldBonus(player: Player): number
	local data = dataOf(player)
	return if data then (data.Perks.Thief or 0) * perksById.Thief.Per else 0
end

---------------------------------------------------------------- Laufgeschwindigkeit (Perk, Speed-Pad, Alarm)

function FeatureService:ApplySpeed(player: Player)
	local data = dataOf(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not data then
		return
	end
	local passSpeed = if self.Services.MonetizationService:HasPass(player, "SpeedCoil") then Config.SpeedCoilWalkSpeed else Config.DefaultWalkSpeed
	local speed = passSpeed + (data.Perks.Speed or 0) * perksById.Speed.Per
	player:SetAttribute("BaseWalkSpeed", speed)
	local current = speed
	if speedUntil[player] and os.clock() < speedUntil[player] then
		current += Config.SpeedPadBoost
	end
	if alarmSlowed[player] then
		current *= Config.AlarmSlow
	end
	-- Waehrend eines Schlags (WalkSpeed 0) nicht ueberschreiben
	if humanoid and humanoid.WalkSpeed > 0 then
		humanoid.WalkSpeed = current
	end
end

---------------------------------------------------------------- Klauen: Tresor, Alarm, Combo

function FeatureService:OnStealStarted(thief: Player, owner: Player)
	local data = dataOf(owner)
	if data and data.Alarm then
		alarmSlowed[thief] = true
		self:ApplySpeed(thief)
		self.Services.Net.SendAnnounce(`🚨 ALARM! {thief.DisplayName} is robbing {owner.DisplayName}'s base!`, RED)
	end
end

function FeatureService:OnStealEnded(thief: Player, success: boolean, info)
	if alarmSlowed[thief] then
		alarmSlowed[thief] = nil
		self:ApplySpeed(thief)
	end
	if not success or not info then
		return
	end
	local now = os.clock()
	local combo = combos[thief]
	if combo and now < combo.Until then
		combo.Count += 1
	else
		combo = { Count = 1, Until = 0 }
		combos[thief] = combo
	end
	combo.Until = now + Config.ComboWindow
	thief:SetAttribute("Combo", combo.Count)
	thief:SetAttribute("ComboUntil", workspace:GetServerTimeNow() + Config.ComboWindow)
	local share = Config.ComboBonus[math.min(combo.Count, #Config.ComboBonus)]
	if share > 0 then
		local bonus = math.floor(info.Value * share)
		self.Services.DataService:AddCash(thief, bonus)
		notify(thief, `🔥 STEAL COMBO x{combo.Count}! +{Format.Cash(bonus)} bonus`, GOLD)
		if combo.Count >= 3 then
			self.Services.Net.SendAnnounce(`🔥 {thief.DisplayName} is on a x{combo.Count} STEAL COMBO!`, GOLD)
		end
	end
end

---------------------------------------------------------------- Rebirth und Pass-XP

function FeatureService:OnRebirth(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	data.Tokens = (data.Tokens or 0) + 1
	data.Levels = {}
	data.Vault = ""
	notify(player, "+1 Rebirth Token! Spend it in MORE > PERKS.", GOLD)
	self:UpdateBuddy(player)
	self:Refresh(player)
end

-- Von ProgressService:Track fuer jede Statistik aufgerufen
function FeatureService:OnStat(player: Player, stat: string, amount: number)
	local per = Config.PassXPPer[stat]
	local data = dataOf(player)
	if not per or not data then
		return
	end
	local before = passTier(data.PassXP or 0)
	data.PassXP = (data.PassXP or 0) + per * amount
	local after = passTier(data.PassXP)
	if after > before then
		notify(player, `CRITTER PASS tier {after} reached! Claim it in MORE > PASS.`, Color3.fromRGB(200, 140, 255))
	end
	self:Refresh(player)
end

---------------------------------------------------------------- Eier

local function rollEgg(player: Player, egg)
	local data = dataOf(player)
	local luck = 1 + ((data and data.Perks.EggLuck) or 0) * perksById.EggLuck.Per
	local entries = {}
	local total = 0
	local index = 0
	for _, rarity in Config.Rarities do
		local weight = egg.Weights[rarity.Name]
		if weight then
			index += 1
			-- Egg-Luck macht die seltenen Stufen (ab der dritten) wahrscheinlicher
			if index >= 3 then
				weight *= luck
			end
			table.insert(entries, { Rarity = rarity.Name, Weight = weight })
			total += weight
		end
	end
	local roll = math.random() * total
	for _, entry in entries do
		roll -= entry.Weight
		if roll <= 0 then
			local list = unitsByRarity[entry.Rarity]
			return list[math.random(1, #list)]
		end
	end
	local list = unitsByRarity[entries[1].Rarity]
	return list[1]
end

local function hatch(player: Player, egg, free: boolean): (boolean, string?, any)
	local services = FeatureService.Services
	local data = dataOf(player)
	if not data then
		return false, "Not ready"
	end
	local slot = services.UnitService:FindFreeSlot(player)
	if not slot then
		return false, "Your base is full! Sell or fuse a critter first."
	end
	if not free then
		if data.Cash < egg.Price then
			return false, `You need {Format.Cash(egg.Price - data.Cash)} more.`
		end
		services.DataService:AddCash(player, -egg.Price)
	end
	local def = rollEgg(player, egg)
	local code = Units.Encode(def.Id, nil, 0)
	services.UnitService:GiveUnit(player, code, slot)
	track(player, "Hatched", 1)
	local rarity = Config.RaritiesByName[def.Rarity]
	if rarity.Announce then
		services.Net.SendAnnounce(`{player.DisplayName} hatched a {def.Rarity} {def.Name}!`, rarity.Color)
	end
	return true, `You hatched {def.Name} ({def.Rarity})!`, { Name = def.Name, Rarity = def.Rarity }
end

---------------------------------------------------------------- Anfragen

local function buyEgg(player: Player, eggId: any)
	local egg = type(eggId) == "string" and eggsById[eggId]
	if not egg then
		return false, "Unknown egg"
	end
	return hatch(player, egg, false)
end

local function train(player: Player, slotKey: any)
	local services = FeatureService.Services
	local data = dataOf(player)
	local code = data and type(slotKey) == "string" and data.Units[slotKey]
	local info = Units.Info(code)
	if not info then
		return false, "No critter there"
	end
	local level = data.Levels[slotKey] or 0
	if level >= Config.TrainMaxLevel then
		return false, "Already max level!"
	end
	local cost = math.floor(info.Value * Config.TrainCostShare * (level + 1))
	if data.Cash < cost then
		return false, `You need {Format.Cash(cost - data.Cash)} more.`
	end
	services.DataService:AddCash(player, -cost)
	data.Levels[slotKey] = level + 1
	services.UnitService:UpdateIncome(player)
	services.UnitService:RefreshUnitLabel(player, slotKey)
	track(player, "Trained", 1)
	FeatureService:Refresh(player)
	return true, `{info.Name} is now level {level + 1}!`
end

function FeatureService:UpdateVault(player: Player)
	local data = dataOf(player)
	local models = self.Services.UnitService:GetBaseModels(player)
	for slotKey, model in models do
		local shield = model.PrimaryPart and model.PrimaryPart:FindFirstChild("VaultShield")
		local vaulted = data ~= nil and data.Vault == slotKey
		if vaulted and not shield and model.PrimaryPart then
			local info = Units.Info(data.Units[slotKey])
			local bubble = Instance.new("Part")
			bubble.Name = "VaultShield"
			bubble.Shape = Enum.PartType.Ball
			bubble.Size = Vector3.one * ((info and info.Scale or 3) * 1.5)
			bubble.Color = Color3.fromRGB(110, 200, 255)
			bubble.Material = Enum.Material.ForceField
			bubble.Transparency = 0.2
			bubble.CanCollide = false
			bubble.CanQuery = false
			bubble.CanTouch = false
			bubble.Anchored = true
			bubble.CFrame = model.PrimaryPart.CFrame
			bubble.Parent = model.PrimaryPart
		elseif not vaulted and shield then
			shield:Destroy()
		end
	end
end

local function vault(player: Player, slotKey: any)
	local services = FeatureService.Services
	local data = dataOf(player)
	local code = data and type(slotKey) == "string" and data.Units[slotKey]
	local info = Units.Info(code)
	if not info then
		return false, "No critter there"
	end
	if data.Vault == slotKey then
		return false, "Already in your vault"
	end
	local cost = math.floor(info.Value * Config.VaultCostShare)
	if data.Cash < cost then
		return false, `You need {Format.Cash(cost - data.Cash)} more.`
	end
	services.DataService:AddCash(player, -cost)
	data.Vault = slotKey
	FeatureService:UpdateVault(player)
	FeatureService:Refresh(player)
	return true, `{info.Name} is safe in your vault! Nobody can steal it.`
end

local function buyAlarm(player: Player)
	local services = FeatureService.Services
	local data = dataOf(player)
	if not data or data.Alarm then
		return false, "You already have an alarm"
	end
	if data.Cash < Config.AlarmPrice then
		return false, `You need {Format.Cash(Config.AlarmPrice - data.Cash)} more.`
	end
	services.DataService:AddCash(player, -Config.AlarmPrice)
	data.Alarm = true
	FeatureService:Refresh(player)
	return true, "Alarm installed! Thieves get slowed and everyone is warned."
end

local function buyPerk(player: Player, perkId: any)
	local data = dataOf(player)
	local perk = type(perkId) == "string" and perksById[perkId]
	if not data or not perk then
		return false, "Unknown perk"
	end
	local level = data.Perks[perk.Id] or 0
	if level >= perk.Max then
		return false, "Max level!"
	end
	local cost = level + 1
	if (data.Tokens or 0) < cost then
		return false, `You need {cost} Rebirth Tokens. Rebirth to earn more!`
	end
	data.Tokens -= cost
	data.Perks[perk.Id] = level + 1
	FeatureService.Services.UnitService:UpdateIncome(player)
	FeatureService:ApplySpeed(player)
	FeatureService:Refresh(player)
	return true, `{perk.Name} is now level {level + 1}!`
end

local function claimPass(player: Player)
	local services = FeatureService.Services
	local data = dataOf(player)
	if not data then
		return false, "Not ready"
	end
	local tier = passTier(data.PassXP or 0)
	local nextTier = (data.PassClaimed or 0) + 1
	if nextTier > tier then
		return false, "Earn more XP to unlock the next tier!"
	end
	local reward = passReward(player, nextTier)
	if reward.Kind == "Egg" and not services.UnitService:FindFreeSlot(player) then
		return false, "Your base is full! Make room for the egg first."
	end
	data.PassClaimed = nextTier
	if reward.Kind == "Cash" then
		services.DataService:AddCash(player, reward.Amount)
	elseif reward.Kind == "Tokens" then
		data.Tokens = (data.Tokens or 0) + reward.Amount
	elseif reward.Kind == "Catalyst" then
		data.Catalysts = (data.Catalysts or 0) + 1
		player:SetAttribute("Catalysts", data.Catalysts)
	elseif reward.Kind == "Egg" then
		hatch(player, eggsById[reward.Egg], true)
	end
	FeatureService:Refresh(player)
	return true, `Tier {nextTier}: {reward.Text}!`
end

local function findPlayer(userId: any): Player?
	return if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
end

local function like(player: Player, userId: any)
	local target = findPlayer(userId)
	local data = dataOf(player)
	local targetData = target and dataOf(target)
	if not target or not data or not targetData then
		return false, "Player not found"
	end
	if target == player then
		return false, "You can't like your own base!"
	end
	local key = tostring(target.UserId)
	if data.LikesGiven[key] == today() then
		return false, "You already liked this base today"
	end
	data.LikesGiven[key] = today()
	-- Alte Eintraege aufraeumen, damit die Daten klein bleiben
	for other, day in data.LikesGiven do
		if day < today() - 1 then
			data.LikesGiven[other] = nil
		end
	end
	targetData.Likes = (targetData.Likes or 0) + 1
	FeatureService.Services.UnitService:UpdateIncome(target)
	notify(target, `❤️ {player.DisplayName} liked your base! (+{math.floor(Config.LikeBonusPer * 100)}% income)`, Color3.fromRGB(255, 120, 160))
	FeatureService:Refresh(player)
	FeatureService:Refresh(target)
	return true, `You liked {target.DisplayName}'s base!`
end

local function teleportTo(player: Player, plot): (boolean, string?)
	local character = player.Character
	if not character or not plot then
		return false, "Not possible right now"
	end
	if player:GetAttribute("Carrying") then
		return false, "Not while carrying a critter - run!"
	end
	character:PivotTo(plot.SpawnCFrame)
	return true
end

local function visit(player: Player, userId: any)
	local target = findPlayer(userId)
	if not target then
		return false, "Player not found"
	end
	local ok, message = teleportTo(player, FeatureService.Services.PlotService:GetPlot(target))
	return ok, message or `Welcome to {target.DisplayName}'s base!`
end

local function home(player: Player)
	local ok, message = teleportTo(player, FeatureService.Services.PlotService:GetPlot(player))
	return ok, message or "Welcome home!"
end

local function gift(player: Player, userId: any)
	local services = FeatureService.Services
	local target = findPlayer(userId)
	local data = dataOf(player)
	if not target or not data or not dataOf(target) or target == player then
		return false, "Player not found"
	end
	if data.GiftDay ~= today() then
		data.GiftDay = today()
		data.GiftsToday = 0
	end
	if data.GiftsToday >= Config.GiftMaxPerDay then
		return false, "No gifts left today. Come back tomorrow!"
	end
	local amount = math.floor(math.min(data.Cash * Config.GiftShare, math.max(income(player), 1) * 600))
	if amount < Config.GiftMinCash then
		return false, `You need at least {Format.Cash(Config.GiftMinCash * 10)} to send a gift.`
	end
	data.GiftsToday += 1
	services.DataService:AddCash(player, -amount)
	services.DataService:AddCash(target, amount)
	notify(target, `🎁 {player.DisplayName} gifted you {Format.Cash(amount)}!`, GREEN)
	FeatureService:Refresh(player)
	return true, `You gifted {Format.Cash(amount)} to {target.DisplayName}!`
end

local function setBaseColor(player: Player, name: any)
	local services = FeatureService.Services
	local data = dataOf(player)
	local choice
	for _, entry in Config.BaseColors do
		if entry.Name == name then
			choice = entry
		end
	end
	if not data or not choice then
		return false, "Unknown color"
	end
	if data.BaseColor == choice.Name then
		return false, "Your base already has this color"
	end
	if data.Cash < Config.BaseColorPrice then
		return false, `You need {Format.Cash(Config.BaseColorPrice - data.Cash)} more.`
	end
	services.DataService:AddCash(player, -Config.BaseColorPrice)
	data.BaseColor = choice.Name
	FeatureService:ApplyBaseColor(player)
	FeatureService:Refresh(player)
	return true, `Your base is now {choice.Name}!`
end

function FeatureService:ApplyBaseColor(player: Player)
	local data = dataOf(player)
	local plot = self.Services.PlotService:GetPlot(player)
	if not data or not plot or data.BaseColor == "" then
		return
	end
	for _, entry in Config.BaseColors do
		if entry.Name == data.BaseColor then
			plot.Accent = entry.Color
			self.Services.PlotService:RefreshPads(player)
		end
	end
end

local SETTING_VALUES = {
	Labels = { All = true, Mine = true, Off = true },
	Hints = { On = true, Off = true },
	Detail = { High = true, Low = true },
	Buddy = { On = true, Off = true },
}

local function saveSettings(player: Player, settings: any)
	local data = dataOf(player)
	if not data or type(settings) ~= "table" then
		return false
	end
	for key, value in settings do
		if SETTING_VALUES[key] and SETTING_VALUES[key][value] then
			data.Settings[key] = value
		end
	end
	FeatureService:UpdateBuddy(player)
	FeatureService:Refresh(player)
	return true
end

---------------------------------------------------------------- Kumpel: beste Kreatur laeuft hinterher

function FeatureService:UpdateBuddy(player: Player)
	local data = dataOf(player)
	local hadBuddy = buddies[player] ~= nil
	local current = buddies[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local bestCode, bestIncome = nil, -1
	if data and data.Settings.Buddy ~= "Off" then
		for _, code in data.Units do
			local info = Units.Info(code)
			if info and info.Income > bestIncome then
				bestCode, bestIncome = info.Code, info.Income
			end
		end
	end
	if current and (current.Code ~= bestCode or not root or not current.Model.Parent) then
		current.Model:Destroy()
		buddies[player] = nil
		current = nil
	end
	if current or not bestCode or not root then
		if hadBuddy ~= (buddies[player] ~= nil) then
			self.Services.UnitService:UpdateIncome(player)
		end
		return
	end
	local info = table.clone(Units.Info(bestCode))
	info.Scale = 1.6
	local model = UnitFactory.Build(info)
	model.Name = "Buddy_" .. player.UserId
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = part ~= model.PrimaryPart
		elseif part:IsA("ParticleEmitter") or part:IsA("PointLight") then
			part:Destroy()
		end
	end
	local body = model.PrimaryPart :: BasePart
	local attachment = Instance.new("Attachment")
	attachment.Parent = body
	local target = root:FindFirstChild("BuddyTarget") :: Attachment?
	if not target then
		target = Instance.new("Attachment")
		target.Name = "BuddyTarget"
		target.Position = Vector3.new(2.6, 0.2, 2.4)
		target.Parent = root
	end
	local align = Instance.new("AlignPosition")
	align.Attachment0 = attachment
	align.Attachment1 = target
	align.MaxForce = 1e6
	align.Responsiveness = 18
	align.Parent = body
	local orient = Instance.new("AlignOrientation")
	orient.Attachment0 = attachment
	orient.Attachment1 = target
	orient.MaxTorque = 1e6
	orient.Responsiveness = 18
	orient.Parent = body
	model:PivotTo(root.CFrame * CFrame.new(2.6, 0.2, 2.4))
	model.Parent = workspace:FindFirstChild("Buddies") or workspace
	pcall(body.SetNetworkOwner, body, player)
	buddies[player] = { Code = bestCode, Model = model }
	self.Services.UnitService:UpdateIncome(player)
end

---------------------------------------------------------------- Boss-Raid

local function bossPosition(): Vector3
	return Vector3.new(Config.Conveyor.StartX - 22, 0, -26)
end

local function endBoss(defeated: boolean)
	local current = boss
	if not current then
		return
	end
	boss = nil
	workspace:SetAttribute("BossActive", false)
	workspace:SetAttribute("BossAt", workspace:GetServerTimeNow() + Config.BossInterval)
	if current.Model then
		current.Model:Destroy()
	end
	local services = FeatureService.Services
	if not defeated then
		services.Net.SendAnnounce("The boss escaped! Next time hit harder - together!", RED)
		return
	end
	local top, topHits = nil, 0
	for player, hits in current.Hits do
		if hits > topHits then
			top, topHits = player, hits
		end
	end
	for player, hits in current.Hits do
		if player.Parent and dataOf(player) then
			local share = hits / math.max(topHits, 1)
			local cash = math.floor(incomeReward(player, 60 * Config.BossRewardMinutes, Config.BossMinReward) * (0.5 + 0.5 * share))
			services.DataService:AddCash(player, cash)
			track(player, "Bosses", 1)
			notify(player, `BOSS DEFEATED! You hit it {hits}x: +{Format.Cash(cash)}`, GOLD)
		end
	end
	if top and top.Parent then
		local data = dataOf(top)
		if data then
			data.Catalysts = (data.Catalysts or 0) + 1
			top:SetAttribute("Catalysts", data.Catalysts)
			notify(top, "TOP HITTER! You get a Fusion Catalyst!", GOLD)
		end
	end
	services.Net.SendAnnounce(`BOSS DEFEATED! Top hitter: {if top then top.DisplayName else "?"}`, GOLD)
end

local function spawnBoss()
	if boss then
		return
	end
	local players = #Players:GetPlayers()
	if players == 0 then
		workspace:SetAttribute("BossAt", workspace:GetServerTimeNow() + Config.BossInterval)
		return
	end
	local candidates = {}
	for _, rarity in { "Mythic", "Secret" } do
		for _, def in unitsByRarity[rarity] or {} do
			table.insert(candidates, def)
		end
	end
	local def = candidates[math.random(1, #candidates)]
	local info = table.clone(Units.Info(Units.Encode(def.Id, nil, 0)))
	info.Scale = 12
	info.Name = "GIANT " .. string.upper(def.Name)
	local model = UnitFactory.Build(info)
	model.Name = "Boss"
	local position = bossPosition() + Vector3.new(0, info.Scale * 0.6 + 0.5, 0)
	model:PivotTo(CFrame.lookAt(position, position + Vector3.new(1, 0, 0)))
	local maxHp = math.max(80, players * Config.BossHitsPerPlayer)
	boss = { Model = model, Hp = maxHp, MaxHp = maxHp, Hits = {}, LastHit = {}, Ends = os.clock() + Config.BossDuration }

	-- Lebensbalken
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossBar"
	gui.Size = UDim2.fromScale(16, 2.4)
	gui.StudsOffset = Vector3.new(0, info.Scale * 0.75 + 3, 0)
	gui.MaxDistance = 250
	gui.LightInfluence = 0
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.5)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 90, 90)
	title.TextStrokeTransparency = 0
	title.Text = `👹 {info.Name} - TAP TO HIT!`
	title.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0, 0.55)
	back.Size = UDim2.fromScale(1, 0.4)
	back.BackgroundColor3 = Color3.fromRGB(30, 20, 30)
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 70, 90)
	fill.BorderSizePixel = 0
	fill.Parent = back
	gui.Parent = model.PrimaryPart
	boss.Fill = fill

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 70
	click.Parent = model
	click.MouseClick:Connect(function(player)
		local current = boss
		if not current or current.Model ~= model then
			return
		end
		local now = os.clock()
		if now - (current.LastHit[player] or 0) < 0.22 then
			return
		end
		current.LastHit[player] = now
		current.Hits[player] = (current.Hits[player] or 0) + 1
		current.Hp -= 1
		track(player, "BossHits", 1)
		current.Fill.Size = UDim2.fromScale(math.max(0, current.Hp / current.MaxHp), 1)
		workspace:SetAttribute("BossHP", math.max(0, current.Hp / current.MaxHp))
		if current.Hp <= 0 then
			endBoss(true)
		end
	end)
	model.Parent = workspace
	workspace:SetAttribute("BossActive", true)
	workspace:SetAttribute("BossHP", 1)
	workspace:SetAttribute("BossEnds", workspace:GetServerTimeNow() + Config.BossDuration)
	FeatureService.Services.Net.SendAnnounce(`👹 BOSS RAID! A {info.Name} appeared at the spawn - tap it together!`, Color3.fromRGB(255, 90, 90))
end

---------------------------------------------------------------- Edelsteine und Speed-Pads

local gemFolder: Folder
local function walkwaySpot(): Vector3
	local conveyor = Config.Conveyor
	local x = math.random(math.floor(conveyor.StartX - 30), math.floor(conveyor.EndX - 10))
	local z = (if math.random() < 0.5 then -1 else 1) * (8 + math.random() * 7)
	return Vector3.new(x, 2.2, z)
end

local function spawnGem()
	local gem = Instance.new("Part")
	gem.Name = "Gem"
	gem.Size = Vector3.new(1.4, 2, 1.4)
	gem.CFrame = CFrame.new(walkwaySpot()) * CFrame.Angles(0, 0, math.rad(45))
	gem.Color = Color3.fromRGB(80, 240, 255)
	gem.Material = Enum.Material.Neon
	gem.Anchored = true
	gem.CanCollide = false
	gem.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = gem.Color
	light.Range = 8
	light.Parent = gem
	CollectionService:AddTag(gem, "Spin")
	local taken = false
	gem.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if taken or not player or not dataOf(player) then
			return
		end
		taken = true
		gem:Destroy()
		local cash = incomeReward(player, Config.GemSeconds, Config.GemMinCash)
		FeatureService.Services.DataService:AddCash(player, cash)
		track(player, "Gems", 1)
		notify(player, `💎 Gem found! +{Format.Cash(cash)}`, Color3.fromRGB(80, 240, 255))
		task.delay(Config.GemRespawn, spawnGem)
	end)
	gem.Parent = gemFolder
end

local function buildSpeedPads()
	local conveyor = Config.Conveyor
	local folder = Instance.new("Folder")
	folder.Name = "SpeedPads"
	for i = 0, 3 do
		for _, side in { -1, 1 } do
			local x = conveyor.StartX + (conveyor.EndX - conveyor.StartX) * (0.12 + i * 0.25)
			local pad = Instance.new("Part")
			pad.Name = "SpeedPad"
			pad.Size = Vector3.new(6, 0.3, 4)
			pad.Position = Vector3.new(x, 1.15, side * 9)
			pad.Color = Color3.fromRGB(255, 220, 60)
			pad.Material = Enum.Material.Neon
			pad.Anchored = true
			pad.CanCollide = false
			pad.Transparency = 0.2
			pad.Parent = folder
			local arrowGui = Instance.new("SurfaceGui")
			arrowGui.Face = Enum.NormalId.Top
			arrowGui.LightInfluence = 0
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = "⚡ SPEED ⚡"
			label.TextScaled = true
			label.Font = Enum.Font.FredokaOne
			label.TextColor3 = Color3.fromRGB(80, 50, 10)
			label.Parent = arrowGui
			arrowGui.Parent = pad
			pad.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if not player then
					return
				end
				local fresh = not speedUntil[player] or os.clock() > speedUntil[player]
				speedUntil[player] = os.clock() + Config.SpeedPadTime
				if fresh then
					FeatureService:ApplySpeed(player)
					task.delay(Config.SpeedPadTime + 0.1, function()
						if player.Parent and speedUntil[player] and os.clock() >= speedUntil[player] then
							speedUntil[player] = nil
							FeatureService:ApplySpeed(player)
						end
					end)
				end
			end)
		end
	end
	folder.Parent = workspace
end

---------------------------------------------------------------- Tag und Nacht

local function runDayCycle()
	while true do
		-- Tag (Abendstimmung wie bisher), dann kurze Nacht mit mehr Glueck
		workspace:SetAttribute("NightAt", workspace:GetServerTimeNow() + Config.DayLength)
		Lighting.ClockTime = 17.2
		task.wait(Config.DayLength)
		nightUntil = workspace:GetServerTimeNow() + Config.NightLength
		workspace:SetAttribute("NightUntil", nightUntil)
		FeatureService.Services.Net.SendAnnounce(`🌙 NIGHT TIME! Belt luck x{Config.NightLuck} for {Config.NightLength // 60} minutes!`, Color3.fromRGB(150, 160, 255))
		for step = 1, 20 do
			Lighting.ClockTime = 17.2 + step * (2.8 / 20)
			task.wait(0.15)
		end
		task.wait(Config.NightLength - 6)
		for step = 1, 20 do
			Lighting.ClockTime = 20 - step * (2.8 / 20)
			task.wait(0.15)
		end
		workspace:SetAttribute("NightUntil", nil)
	end
end

---------------------------------------------------------------- Lebenszyklus

function FeatureService:OnPlayerReady(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	-- Alte Rebirths einmalig als Tokens gutschreiben
	if not data.TokensGranted then
		data.TokensGranted = true
		data.Tokens = (data.Tokens or 0) + (data.Rebirths or 0)
	end
	-- Trainingsstufen fuer leere Slots entfernen
	for slotKey in data.Levels do
		if data.Units[slotKey] == nil then
			data.Levels[slotKey] = nil
		end
	end
	if data.Vault ~= "" and data.Units[data.Vault] == nil then
		data.Vault = ""
	end
	player:SetAttribute("StealHoldBonus", self:StealHoldBonus(player))
	self:ApplyBaseColor(player)
	self:UpdateVault(player)
	self:Refresh(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		self:ApplySpeed(player)
		self:UpdateBuddy(player)
	end)
	if player.Character then
		task.delay(0.5, function()
			self:ApplySpeed(player)
			self:UpdateBuddy(player)
		end)
	end
end

function FeatureService:OnPlayerRemoving(player: Player)
	combos[player] = nil
	speedUntil[player] = nil
	alarmSlowed[player] = nil
	local buddy = buddies[player]
	if buddy then
		buddy.Model:Destroy()
		buddies[player] = nil
	end
	if boss then
		boss.Hits[player] = nil
		boss.LastHit[player] = nil
	end
end

function FeatureService:Start()
	local net = self.Services.Net
	net.Handle("BuyEgg", buyEgg)
	net.Handle("Train", train)
	net.Handle("Vault", vault)
	net.Handle("BuyAlarm", buyAlarm)
	net.Handle("BuyPerk", function(player, perkId)
		local ok, message = buyPerk(player, perkId)
		player:SetAttribute("StealHoldBonus", self:StealHoldBonus(player))
		return ok, message
	end)
	net.Handle("ClaimPass", claimPass)
	net.Handle("Like", like)
	net.Handle("Visit", visit)
	net.Handle("Home", home)
	net.Handle("Gift", gift)
	net.Handle("SetBaseColor", setBaseColor)
	net.Handle("SaveSettings", saveSettings)

	local buddyFolder = Instance.new("Folder")
	buddyFolder.Name = "Buddies"
	buddyFolder.Parent = workspace
	gemFolder = Instance.new("Folder")
	gemFolder.Name = "Gems"
	gemFolder.Parent = workspace
	for _ = 1, Config.GemCount do
		spawnGem()
	end
	buildSpeedPads()
	task.spawn(runDayCycle)

	-- Boss-Raid
	workspace:SetAttribute("BossAt", workspace:GetServerTimeNow() + Config.BossInterval)
	task.spawn(function()
		while true do
			task.wait(1)
			if boss and os.clock() > boss.Ends then
				endBoss(false)
			elseif not boss and workspace:GetServerTimeNow() >= (workspace:GetAttribute("BossAt") or math.huge) then
				spawnBoss()
			end
		end
	end)

	-- Goldene Kreatur auf dem Laufband
	task.spawn(function()
		while true do
			task.wait(Config.GoldenBeltInterval)
			local rarities = { "Rare", "Epic", "Legendary" }
			self.Services.UnitService:SpawnBeltUnit(rarities[math.random(1, #rarities)], "Golden")
			net.SendAnnounce("✨ A GOLDEN critter is riding the belt! Grab it!", GOLD)
		end
	end)

	-- Kumpel und Combo-Ende regelmaessig pruefen
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				if dataOf(player) then
					self:UpdateBuddy(player)
					local combo = combos[player]
					if combo and os.clock() > combo.Until then
						combos[player] = nil
						player:SetAttribute("Combo", nil)
					end
				end
			end
		end
	end)
end

return FeatureService
