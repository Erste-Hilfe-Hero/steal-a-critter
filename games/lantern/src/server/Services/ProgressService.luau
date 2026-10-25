-- Langzeit-Motivation: taegliche Quests, Erfolge mit Titeln, Auren (Kosmetik), Codes, Einstellungen,
-- Trank-Meisterschaft, Kill-Kombo, Gruppen-Signale, Heldentagebuch, Einsteiger-Anleitung und der Dungeon des Tages.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local ProgressService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 60)
local GREEN = Color3.fromRGB(110, 222, 140)

local dirty = {} -- [Player] = true: Quests muessen an den Client
local combos = {} -- [Player] = { Count, Last }
local pingReady = {} -- [Player] = os.clock()
local codeReady = {} -- [Player] = os.clock()
local featured = 0

local settingDefaults = {}
for _, setting in Config.Settings do
	settingDefaults[setting.Key] = setting.Default
end

function ProgressService:Init(services)
	self.Services = services
end

local function today(): number
	return os.time() // 86400
end

-- Zahlen vom Client: nur echte, endliche Ganzzahlen zulassen (kein NaN/inf)
local function wholeNumber(value: any): number?
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.floor(value)
end
ProgressService.WholeNumber = wholeNumber

---------------------------------------------------------------- Einstellungen und Attribute

function ProgressService:Setting(player: Player, key: string): boolean
	local data = self.Services.DataService:Get(player)
	local value = data and data.Settings[key]
	if value == nil then
		return settingDefaults[key] == true
	end
	return value == true
end

local function applySettingAttributes(player: Player)
	for _, setting in Config.Settings do
		player:SetAttribute("Set_" .. setting.Key, ProgressService:Setting(player, setting.Key))
	end
end

---------------------------------------------------------------- Auren

local function ownsAura(data, aura): boolean
	if data.Auras[aura.Key] then
		return true
	end
	return aura.Achievement ~= nil and data.Achievements[aura.Achievement] == true
end

function ProgressService:ApplyAura(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local data = self.Services.DataService:Get(player)
	if not root or not data then
		return
	end
	local old = root:FindFirstChild("LanternAura")
	if old then
		old:Destroy()
	end
	local aura = Config.AurasByKey[data.Aura]
	if not aura or not ownsAura(data, aura) then
		return
	end
	local holder = Instance.new("Attachment")
	holder.Name = "LanternAura"
	holder.Position = Vector3.new(0, -1.5, 0)
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(aura.Color)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new(0.1, 1)
	sparkles.Lifetime = NumberRange.new(0.8, 1.4)
	sparkles.Rate = 18
	sparkles.Speed = NumberRange.new(1, 2.5)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.EmissionDirection = Enum.NormalId.Top
	sparkles.Parent = holder
	local glow = Instance.new("PointLight")
	glow.Color = aura.Color
	glow.Range = 10
	glow.Brightness = 1.2
	glow.Parent = holder
	holder.Parent = root
end

function ProgressService:OnCharacterAdded(player: Player, character: Model)
	if character:WaitForChild("HumanoidRootPart", 10) and player.Character == character then
		self:ApplyAura(player)
	end
end

---------------------------------------------------------------- Quests

local function rollQuests(player: Player, data): boolean
	local day = today()
	if data.QuestDay == day and #data.Quests > 0 then
		return false
	end
	data.QuestDay = day
	data.QuestBonus = false
	-- Gleicher Tag + gleicher Spieler = gleiche Quests (auch nach einem Serverwechsel)
	local rng = Random.new(day * 7919 + player.UserId % 100003)
	local pool = table.clone(Config.Quests)
	local list = {}
	for _ = 1, math.min(Config.QuestCount, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { Key = quest.Key, Progress = 0, Claimed = false })
	end
	data.Quests = list
	return true
end

function ProgressService:SendQuests(player: Player)
	dirty[player] = nil
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local list = {}
	local ready = 0
	for index, entry in data.Quests do
		local quest = Config.QuestsByKey[entry.Key]
		if quest then
			local progress = math.min(entry.Progress, quest.Goal)
			if progress >= quest.Goal and not entry.Claimed then
				ready += 1
			end
			table.insert(list, { Index = index, Text = string.format(quest.Text, quest.Goal), Goal = quest.Goal, Progress = progress, Claimed = entry.Claimed })
		end
	end
	player:SetAttribute("QuestsReady", ready)
	self.Services.Net.Sync:FireClient(player, "Quests", {
		List = list,
		Gold = Config.QuestGold(data.Level),
		Shards = Config.QuestShards,
		BonusClaimed = data.QuestBonus,
		ResetAt = (today() + 1) * 86400,
	})
end

local function statValue(data, stat: string): number
	if stat == "DungeonsCleared" then
		local count = 0
		for _, dungeon in Config.Dungeons do
			if (data.Cleared[dungeon.Id] or 0) >= 1 then
				count += 1
			end
		end
		return count
	end
	return tonumber(data[stat]) or 0
end

function ProgressService:CheckAchievements(player: Player)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	for _, achievement in Config.Achievements do
		if not data.Achievements[achievement.Key] and statValue(data, achievement.Stat) >= achievement.Goal then
			data.Achievements[achievement.Key] = true
			if data.Title == "" then
				data.Title = achievement.Title
			end
			services.DataService:AddGold(player, achievement.Gold)
			services.Net.SendNotify(player, `Achievement: {achievement.Name}! Title "{achievement.Title}" unlocked, +{Format.Number(achievement.Gold)} gold`, GOLD)
			services.Net.Effect:FireClient(player, "Achievement", { Name = achievement.Name, Title = achievement.Title })
		end
	end
end

-- Zentraler Zaehler fuer Quests, Anleitung und Erfolge
function ProgressService:Track(player: Player, event: string, amount: number?)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	local value = amount or 1
	if rollQuests(player, data) then
		dirty[player] = true
	end
	for _, entry in data.Quests do
		local quest = Config.QuestsByKey[entry.Key]
		if quest and quest.Event == event and not entry.Claimed and entry.Progress < quest.Goal then
			entry.Progress = if quest.Max then math.max(entry.Progress, value) else entry.Progress + value
			if entry.Progress >= quest.Goal then
				entry.Progress = quest.Goal
				services.Net.SendNotify(player, `Quest complete: {string.format(quest.Text, quest.Goal)}! Claim it in QUESTS.`, GREEN)
			end
			dirty[player] = true
		end
	end
	local step = Config.Tutorial[data.Tutorial]
	if step and step.Event == event then
		data.Tutorial += 1
		services.DataService:AddGold(player, step.Gold)
		local nextStep = Config.Tutorial[data.Tutorial]
		services.Net.SendNotify(player, if nextStep then `Guide step done! +{step.Gold} gold` else `Guide complete! +{step.Gold} gold. Have fun, hero!`, GOLD)
	end
	self:CheckAchievements(player)
end

function ProgressService:ClaimQuest(player: Player, index: number): boolean
	local services = self.Services
	local data = services.DataService:Get(player)
	local entry = data and data.Quests[index]
	local quest = entry and Config.QuestsByKey[entry.Key]
	if not quest or entry.Claimed or entry.Progress < quest.Goal then
		return false
	end
	entry.Claimed = true
	local gold = Config.QuestGold(data.Level)
	services.DataService:AddGold(player, gold)
	services.DataService:AddShards(player, Config.QuestShards)
	services.Net.SendNotify(player, `Quest reward: +{Format.Number(gold)} gold, +{Config.QuestShards} shards!`, GOLD)
	local all = true
	for _, other in data.Quests do
		if not other.Claimed then
			all = false
		end
	end
	if all and not data.QuestBonus then
		data.QuestBonus = true
		services.LootService:DropItem(player, nil, { MinRarity = 4, Level = data.Level + 1 }, nil)
		services.LootService:SendInventory(player)
		services.Net.SendNotify(player, "All daily quests done! Bonus Epic item added to your bag.", GOLD)
	end
	self:Track(player, "QuestClaim")
	self:SendQuests(player)
	return true
end

---------------------------------------------------------------- Kill-Kombo

-- Vom DungeonService fuer den Spieler mit dem letzten Treffer aufgerufen
function ProgressService:OnKill(player: Player, monsterLevel: number)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	local now = os.clock()
	local entry = combos[player]
	if not entry or now - entry.Last > Config.ComboWindow then
		entry = { Count = 0, Last = now }
		combos[player] = entry
	end
	entry.Count += 1
	entry.Last = now
	services.Net.Effect:FireClient(player, "Combo", { Count = entry.Count, Window = Config.ComboWindow })
	if table.find(Config.ComboMilestones, entry.Count) then
		local bonus = services.HeroService:GiveGold(player, Config.KillGold(monsterLevel) * entry.Count / 2, nil)
		services.Net.SendNotify(player, `{entry.Count} kill combo! +{Format.Number(bonus)} gold`, GOLD)
	end
	if entry.Count > data.BestCombo then
		data.BestCombo = entry.Count
	end
	self:Track(player, "Combo", entry.Count)
end

---------------------------------------------------------------- Dungeon des Tages

function ProgressService:FeaturedIndex(): number
	return Config.FeaturedDungeon(today())
end

local function refreshFeatured()
	local index = ProgressService:FeaturedIndex()
	if index == featured then
		return false
	end
	featured = index
	workspace:SetAttribute("FeaturedDungeon", index)
	ProgressService.Services.WorldService:SetFeatured(index)
	return true
end

---------------------------------------------------------------- Heldentagebuch

local function journal(player: Player)
	local data = ProgressService.Services.DataService:Get(player)
	if not data then
		return nil
	end
	local stats = {
		{ "Monsters defeated", Format.Number(data.Kills) },
		{ "Champions defeated", Format.Number(data.EliteKills) },
		{ "Bosses defeated", Format.Number(data.BossKills) },
		{ "Treasure Imps caught", Format.Number(data.ImpKills) },
		{ "Dungeons cleared", Format.Number(data.Runs) },
		{ "Nightmare clears", Format.Number(data.NightmareClears) },
		{ "Legendary items found", Format.Number(data.LegendaryFound) },
		{ "Mythic items found", Format.Number(data.MythicFound) },
		{ "Best kill combo", Format.Number(data.BestCombo) },
		{ "Hidden chests opened", Format.Number(data.ChestsOpened) },
		{ "Shrines used", Format.Number(data.ShrinesUsed) },
		{ "Items salvaged", Format.Number(data.Salvaged) },
		{ "Gold earned", Format.Number(data.TotalEarned) },
		{ "Active play time", string.format("%.1f h", data.PlayTime / 3600) },
	}
	local records = {}
	for _, dungeon in Config.Dungeons do
		for difficulty, def in Config.Difficulties do
			local seconds = data.Records[dungeon.Id .. "_" .. difficulty]
			if seconds then
				table.insert(records, { dungeon.Name, def.Name, Format.Time(seconds), difficulty })
			end
		end
	end
	local achievements = {}
	for _, achievement in Config.Achievements do
		table.insert(achievements, {
			Key = achievement.Key,
			Name = achievement.Name,
			Text = achievement.Text,
			Title = achievement.Title,
			Gold = achievement.Gold,
			Goal = achievement.Goal,
			Progress = math.min(achievement.Goal, statValue(data, achievement.Stat)),
			Done = data.Achievements[achievement.Key] == true,
		})
	end
	local auras = {}
	for _, aura in Config.Auras do
		local requirement = if aura.Achievement then Config.AchievementsByKey[aura.Achievement].Name else nil
		local product = aura.Product and Config.DevProducts[aura.Product]
		table.insert(auras, {
			Key = aura.Key,
			Name = aura.Name,
			Color = aura.Color,
			Gold = aura.Gold,
			ProductKey = aura.Product,
			ProductId = product and product.Id or 0,
			Price = product and product.PriceHint or nil,
			Requirement = requirement,
			Owned = ownsAura(data, aura),
		})
	end
	return {
		Stats = stats,
		Records = records,
		Achievements = achievements,
		Auras = auras,
		Aura = data.Aura,
		Title = data.Title,
		PotionLevel = data.PotionLevel,
	}
end

---------------------------------------------------------------- Start

function ProgressService:Start()
	local services = self.Services
	local Net = services.Net

	Net.Handle("GetQuests", function(player)
		local data = services.DataService:Get(player)
		if data then
			rollQuests(player, data)
		end
		self:SendQuests(player)
		return true
	end)
	Net.Handle("ClaimQuest", function(player, index)
		local i = wholeNumber(index)
		return i ~= nil and self:ClaimQuest(player, i)
	end)
	Net.Handle("GetHero", function(player)
		return journal(player)
	end)
	Net.Handle("SetTitle", function(player, key)
		local data = services.DataService:Get(player)
		if not data or typeof(key) ~= "string" then
			return false
		end
		if key == "" then
			data.Title = ""
		else
			local achievement = Config.AchievementsByKey[key]
			if not achievement or not data.Achievements[key] then
				return false
			end
			data.Title = achievement.Title
		end
		services.DataService:UpdateAttributes(player)
		return true
	end)
	Net.Handle("BuyAura", function(player, key)
		local data = services.DataService:Get(player)
		local aura = typeof(key) == "string" and Config.AurasByKey[key]
		if not data or not aura then
			return false
		end
		if ownsAura(data, aura) then
			return false, "You already own this aura."
		end
		if aura.Product then
			services.MonetizationService:PromptProduct(player, aura.Product)
			return false, nil
		end
		if not aura.Gold then
			return false, "Unlock it with the achievement."
		end
		if data.Gold < aura.Gold then
			return false, "Not enough gold."
		end
		services.DataService:AddGold(player, -aura.Gold)
		data.Auras[aura.Key] = true
		data.Aura = aura.Key
		self:ApplyAura(player)
		Net.SendNotify(player, `{aura.Name} unlocked and equipped!`, aura.Color)
		return true
	end)
	Net.Handle("SetAura", function(player, key)
		local data = services.DataService:Get(player)
		if not data or typeof(key) ~= "string" then
			return false
		end
		local aura = Config.AurasByKey[key]
		if key ~= "" and (not aura or not ownsAura(data, aura)) then
			return false
		end
		data.Aura = key
		self:ApplyAura(player)
		return true
	end)
	Net.Handle("RedeemCode", function(player, text)
		local data = services.DataService:Get(player)
		if not data or typeof(text) ~= "string" or #text > 30 then
			return false, "Invalid code."
		end
		local now = os.clock()
		if now < (codeReady[player] or 0) then
			return false, "Please wait a moment."
		end
		codeReady[player] = now + 2
		local code = text:upper():gsub("%s", "")
		local reward = Config.Codes[code]
		if not reward then
			return false, "Invalid code."
		end
		if data.Codes[code] then
			return false, "You already redeemed this code."
		end
		data.Codes[code] = true
		local parts = {}
		if reward.Gold then
			services.DataService:AddGold(player, reward.Gold)
			table.insert(parts, `+{Format.Number(reward.Gold)} gold`)
		end
		if reward.Shards then
			services.DataService:AddShards(player, reward.Shards)
			table.insert(parts, `+{reward.Shards} shards`)
		end
		if reward.Item then
			local item = services.LootService:DropItem(player, nil, { MinRarity = reward.Item, Level = data.Level }, nil)
			services.LootService:SendInventory(player)
			table.insert(parts, `a {Config.Rarities[item.Rarity].Name} item`)
		end
		return true, "Code redeemed: " .. table.concat(parts, ", ") .. "!"
	end)
	Net.Handle("SetSetting", function(player, key, value)
		local data = services.DataService:Get(player)
		if not data or typeof(key) ~= "string" or settingDefaults[key] == nil or typeof(value) ~= "boolean" then
			return false
		end
		data.Settings[key] = value
		applySettingAttributes(player)
		return true
	end)
	Net.Handle("UpgradePotion", function(player)
		local data = services.DataService:Get(player)
		if not data then
			return false
		end
		if data.PotionLevel >= Config.PotionMaxLevel then
			return false, "Potion Mastery is already maxed."
		end
		local cost = Config.PotionUpgradeCost(data.PotionLevel)
		if data.Gold < cost then
			return false, "Not enough gold."
		end
		services.DataService:AddGold(player, -cost)
		data.PotionLevel += 1
		services.DataService:UpdateAttributes(player)
		Net.SendNotify(player, `Potion Mastery {data.PotionLevel}: heals {math.floor(Config.PotionHealFor(data.PotionLevel) * 100)}%, {Config.PotionCooldownFor(data.PotionLevel)}s cooldown`, GREEN)
		return true
	end)
	Net.Handle("Ping", function(player, index)
		local i = wholeNumber(index)
		local text = i and Config.Pings[i]
		local run = services.DungeonService:GetRun(player)
		local now = os.clock()
		if not text or not run or now < (pingReady[player] or 0) then
			return false
		end
		pingReady[player] = now + Config.PingCooldown
		Net.SendEffect(run.Players, "Ping", { Player = player, Name = player.DisplayName, Text = text })
		return true
	end)

	refreshFeatured()
	task.spawn(function()
		while true do
			task.wait(1)
			for player in dirty do
				if player.Parent then
					self:SendQuests(player)
				else
					dirty[player] = nil
				end
			end
			-- Tageswechsel: neuer Dungeon des Tages und neue Quests fuer alle
			if refreshFeatured() then
				services.Net.SendAnnounce(`New day! Featured dungeon: {Config.Dungeons[featured].Name} (+50% gold and XP)`, GOLD)
				for _, player in Players:GetPlayers() do
					local data = services.DataService:Get(player)
					if data and rollQuests(player, data) then
						dirty[player] = true
					end
				end
			end
		end
	end)
end

function ProgressService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	rollQuests(player, data)
	-- Gespeicherter Titel muss zu einem freigeschalteten Erfolg passen
	if data.Title ~= "" then
		local valid = false
		for _, achievement in Config.Achievements do
			if achievement.Title == data.Title and data.Achievements[achievement.Key] then
				valid = true
			end
		end
		if not valid then
			data.Title = ""
		end
	end
	applySettingAttributes(player)
	self:CheckAchievements(player)
	self.Services.DataService:UpdateAttributes(player)
	self:SendQuests(player)
	task.delay(6, function()
		if player.Parent and featured > 0 then
			self.Services.Net.SendNotify(player, `Featured today: {Config.Dungeons[featured].Name} gives +50% gold and XP!`, GOLD)
		end
	end)
end

function ProgressService:OnPlayerRemoving(player: Player)
	dirty[player] = nil
	combos[player] = nil
	pingReady[player] = nil
	codeReady[player] = nil
end

return ProgressService
