-- Fortschritt: Muenzen, XP/Level/Prestige, Battle Pass, taegliche Quests, Erfolge mit Titeln,
-- Login-Serie, Gluecksrad, Codes, Obby-Belohnung, Namensschilder und das Profil fuer die Menues.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local ProgressService = { Services = nil :: any }

local C = Config.Colors
local BP = Config.BattlePass

local function today(): number
	return os.time() // 86400
end

-- Wochennummer; der 1.1.1970 war ein Donnerstag, +3 Tage => neue Woche jeden Montag 0 Uhr UTC
local function thisWeek(): number
	return (os.time() // 86400 + 3) // 7
end

local function questList(saved, defs)
	local list = {}
	for _, q in saved do
		for _, d in defs do
			if d.Id == q.Id then
				table.insert(list, { Id = q.Id, Text = string.format(d.Text, d.Goal), Progress = math.min(q.Progress, d.Goal), Goal = d.Goal, Reward = d.Reward, Done = q.Done })
			end
		end
	end
	return list
end

---------------------------------------------------------------- Profil an den Client

function ProgressService:Sync(player: Player)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	local quests = questList(data.Quests.List, Config.Quests)
	local weekly = questList(data.WeeklyQuests.List, Config.WeeklyQuests)
	local achievements = {}
	for _, a in Config.Achievements do
		table.insert(achievements, { Id = a.Id, Name = a.Name, Title = a.Title, Goal = a.Goal, Progress = math.min(data[a.Stat] or 0, a.Goal), Done = data.Achievements[a.Id] == true })
	end
	services.Net.Sync:FireClient(player, {
		Coins = data.Coins,
		Level = data.Level,
		XP = data.XP,
		XPNeeded = Config.XPForLevel(data.Level),
		Prestige = data.Prestige,
		Inventory = data.Inventory,
		Equipped = data.Equipped,
		Titles = data.Titles,
		Achievements = achievements,
		Quests = quests,
		WeeklyQuests = weekly,
		WeekEnds = (thisWeek() + 1) * 7 * 86400 - 3 * 86400,
		Passes = data.Passes,
		Tickets = data.Tickets,
		BP = { XP = data.BP.XP, Tier = self:Tier(data), Premium = data.BP.Premium, Free = data.BP.Free, Paid = data.BP.Paid },
		DailyStreak = data.DailyStreak,
		NextSpin = math.max(0, data.LastSpin + Config.Spin.Cooldown - os.time()),
		NextObby = math.max(0, data.LastObby + Config.Obby.Cooldown - os.time()),
		BoostLeft = math.max(0, data.BoostUntil - os.time()),
		Stats = { Wins = data.Wins, Rounds = data.Rounds, KOs = data.KOs, Stops = data.Stops, Survived = data.Survived, CoinsCollected = data.CoinsCollected, CluesFound = data.CluesFound, BestStreak = data.BestStreak, MVPs = data.MVPs, LastSurvivor = data.LastSurvivor, GhostGuesses = data.GhostGuesses },
		WinStreak = data.WinStreak,
		Settings = data.Settings,
		Crates = player:GetAttribute("CratesAllowed") ~= false,
		StarterBought = data.Passes.StarterPack == true,
		Tutorial = data.Tutorial,
	})
	player:SetAttribute("Level", data.Level)
	player:SetAttribute("Coins", data.Coins)
	-- Fuer die Spielerliste (andere Clients lesen diese Attribute)
	player:SetAttribute("Wins", data.Wins)
	player:SetAttribute("Prestige", data.Prestige)
	player:SetAttribute("Title", data.Equipped.Title)
	player:SetAttribute("Streak", data.WinStreak)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats :: any).Level.Value = data.Level;
		(leaderstats :: any).Wins.Value = data.Wins
	end
end

-- Mehrere Aenderungen kurz hintereinander nur einmal senden
local pending = {}
function ProgressService:Refresh(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.15, function()
		pending[player] = nil
		if player.Parent then
			self:Sync(player)
		end
	end)
end

---------------------------------------------------------------- Muenzen, XP

function ProgressService:AddCoins(player: Player, amount: number, fromPurchase: boolean, silent: boolean?)
	local data = self.Services.DataService:Get(player)
	if not data or amount == 0 then
		return
	end
	data.Coins = math.max(0, data.Coins + math.floor(amount))
	if not silent and amount > 0 then
		self.Services.Net.Fx:FireClient(player, "CoinsGained", { Amount = math.floor(amount) })
	end
	self:Refresh(player)
end

function ProgressService:SpendCoins(player: Player, amount: number): boolean
	local data = self.Services.DataService:Get(player)
	if not data or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	self:Refresh(player)
	return true
end

function ProgressService:XPMultiplier(player: Player): number
	local data = self.Services.DataService:Get(player)
	local m = 1
	if self.Services.MonetizationService:HasPass(player, "DoubleXP") then
		m *= 2
	end
	if data and data.BoostUntil > os.time() then
		m *= Config.XP.BoostMultiplier
	end
	m *= self.Services.RoundService:EventXPMultiplier()
	return m
end

function ProgressService:Tier(data): number
	return math.min(BP.Tiers, data.BP.XP // BP.XPPerTier)
end

-- Battle-Pass-Belohnungen bis zur aktuellen Stufe automatisch vergeben
function ProgressService:GrantBattlePass(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local tier = self:Tier(data)
	local function give(reward, track: string)
		if reward.Coins then
			self:AddCoins(player, reward.Coins, false, true)
			self.Services.Net.SendNotify(player, `Battle Pass {track}: +{Format.Number(reward.Coins)} coins`, C.Purple)
		elseif reward.Item then
			self.Services.InventoryService:Grant(player, reward.Item[1], reward.Item[2], 1)
			local item = Config.GetItem(reward.Item[1], reward.Item[2])
			self.Services.Net.SendNotify(player, `Battle Pass {track}: {item and item.Name or "item"} unlocked!`, C.Purple)
		end
	end
	for t = 1, tier do
		local key = tostring(t)
		if BP.Free[t] and not data.BP.Free[key] then
			data.BP.Free[key] = true
			give(BP.Free[t], "reward")
		end
		if data.BP.Premium and BP.Premium[t] and not data.BP.Paid[key] then
			data.BP.Paid[key] = true
			give(BP.Premium[t], "Premium")
		end
	end
end

function ProgressService:AddXP(player: Player, amount: number, raw: boolean?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local gained = if raw then amount else math.floor(amount * self:XPMultiplier(player))
	data.XP += gained
	local beforeTier = self:Tier(data)
	data.BP.XP += gained
	while data.XP >= Config.XPForLevel(data.Level) do
		data.XP -= Config.XPForLevel(data.Level)
		data.Level += 1
		local reward = 50 + data.Level * 10
		data.Coins += reward
		self.Services.Net.Fx:FireClient(player, "LevelUp", { Level = data.Level, Coins = reward })
		self.Services.Net.SendAnnounce(`{player.DisplayName} reached level {data.Level}!`, C.Moon)
	end
	if self:Tier(data) > beforeTier then
		self.Services.Net.Fx:FireClient(player, "Tier", { Tier = self:Tier(data) })
		self:GrantBattlePass(player)
	end
	self:CheckAchievements(player)
	self:UpdateNameplate(player)
	self:Refresh(player)
end

function ProgressService:AddStat(player: Player, stat: string, amount: number)
	local data = self.Services.DataService:Get(player)
	if data then
		data[stat] = (data[stat] or 0) + amount
		self:CheckAchievements(player)
	end
end

---------------------------------------------------------------- Quests

local function rollQuests(data)
	local pool = table.clone(Config.Quests)
	data.Quests = { Day = today(), List = {} }
	for _ = 1, Config.QuestsPerDay do
		local def = table.remove(pool, math.random(1, #pool))
		table.insert(data.Quests.List, { Id = def.Id, Progress = 0, Done = false })
	end
end

local function rollWeekly(data)
	local pool = table.clone(Config.WeeklyQuests)
	data.WeeklyQuests = { Week = thisWeek(), List = {} }
	for _ = 1, Config.WeeklyQuestsPerWeek do
		local def = table.remove(pool, math.random(1, #pool))
		table.insert(data.WeeklyQuests.List, { Id = def.Id, Progress = 0, Done = false })
	end
end
ProgressService.RollWeekly = rollWeekly

function ProgressService:Track(player: Player, stat: string, amount: number)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if data.Quests.Day ~= today() then
		rollQuests(data)
	end
	if data.WeeklyQuests.Week ~= thisWeek() then
		rollWeekly(data)
	end
	local function progress(list, defs, bpXP: number, weekly: boolean)
		for _, q in list do
			if not q.Done then
				for _, def in defs do
					if def.Id == q.Id and def.Stat == stat then
						q.Progress += amount
						if q.Progress >= def.Goal then
							q.Done = true
							self:AddCoins(player, def.Reward, false)
							local beforeTier = self:Tier(data)
							data.BP.XP += bpXP
							if self:Tier(data) > beforeTier then
								self.Services.Net.Fx:FireClient(player, "Tier", { Tier = self:Tier(data) })
							end
							self:GrantBattlePass(player)
							self.Services.Net.Fx:FireClient(player, "Quest", { Text = string.format(def.Text, def.Goal), Reward = def.Reward, Weekly = weekly })
						end
					end
				end
			end
		end
	end
	progress(data.Quests.List, Config.Quests, Config.QuestXP, false)
	progress(data.WeeklyQuests.List, Config.WeeklyQuests, Config.WeeklyQuestXP, true)
	self:Refresh(player)
end

---------------------------------------------------------------- Erfolge und Titel

function ProgressService:CheckAchievements(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	for _, a in Config.Achievements do
		if not data.Achievements[a.Id] and (data[a.Stat] or 0) >= a.Goal then
			data.Achievements[a.Id] = true
			data.Titles[a.Title] = true
			self:AddCoins(player, 200, false, true)
			self.Services.Net.Fx:FireClient(player, "Achievement", { Name = a.Name, Title = a.Title })
		end
	end
end

function ProgressService:UpdateNameplate(player: Player)
	local character = player.Character
	local data = self.Services.DataService:Get(player)
	if not character or not data then
		return
	end
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local gui = character:FindFirstChild("Nameplate") :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "Nameplate"
		g.Size = UDim2.fromOffset(220, 64)
		g.StudsOffset = Vector3.new(0, 2.6, 0)
		g.MaxDistance = 70
		g.LightInfluence = 0
		g.ResetOnSpawn = false
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		list.Parent = g
		for i, name in { "Title", "Name" } do
			local label = Instance.new("TextLabel")
			label.Name = name
			label.LayoutOrder = i
			label.BackgroundTransparency = 1
			label.Size = UDim2.new(1, 0, 0, if name == "Name" then 30 else 22)
			label.Font = if name == "Name" then Enum.Font.FredokaOne else Enum.Font.GothamBold
			label.TextScaled = true
			label.Parent = g
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = Color3.fromRGB(10, 10, 30)
			stroke.Parent = label
		end
		gui = g
	end
	local plate = gui :: BillboardGui
	plate.Adornee = head
	local vip = self.Services.MonetizationService:HasPass(player, "VIP")
	local stars = if data.Prestige > 0 then string.rep("★", math.min(data.Prestige, 5)) .. " " else ""
	local nameLabel = plate:FindFirstChild("Name") :: TextLabel
	nameLabel.Text = `{stars}{player.DisplayName}  Lv {data.Level}`
	nameLabel.TextColor3 = if vip then C.Moon else C.White
	local titleLabel = plate:FindFirstChild("Title") :: TextLabel
	local title = data.Equipped.Title
	if vip and title == "" then
		title = "VIP"
	end
	titleLabel.Text = if title ~= "" then `[{string.upper(title)}]` else ""
	titleLabel.TextColor3 = if title == "VIP" then C.Moon else C.Cyan
	plate.Enabled = player:GetAttribute("InRound") ~= true
	plate.Parent = character
	-- Haustiere (der Client baut sie)
	character:SetAttribute("Pet", data.Equipped.Pet)
	character:SetAttribute("Pet2", if self.Services.MonetizationService:HasPass(player, "PetSlot") then data.Equipped.Pet2 else "")
end

---------------------------------------------------------------- Runde

function ProgressService:RoundReward(player: Player, result)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local X = Config.XP
	local xp = X.Round + result.Coins * X.PerCoin
	local coins = 0
	data.Rounds += 1
	if result.Survived then
		xp += X.Survive
		data.Survived += 1
		coins += Config.Coins.SurviveBonus
		self:Track(player, "Survive", 1)
	end
	if result.Won then
		xp += X.Win
		data.Wins += 1
		coins += Config.Coins.WinBonus
		self:Track(player, "Win", 1)
		-- Siegesserie
		data.WinStreak += 1
		data.BestStreak = math.max(data.BestStreak, data.WinStreak)
		if data.WinStreak >= 2 then
			coins += math.min(data.WinStreak * Config.WinStreak.PerWin, Config.WinStreak.Max)
		end
	else
		data.WinStreak = 0
	end
	if result.MVP then
		data.MVPs += 1
		coins += Config.MVPBonus
	end
	if result.LastSurvivor then
		data.LastSurvivor += 1
		coins += Config.LastSurvivor.Reward
	end
	if result.KOs > 0 then
		xp += result.KOs * X.KO
		data.KOs += result.KOs
	end
	if result.Stopped then
		xp += X.StopMurderer
		data.Stops += 1
		if result.Hero then
			data.HeroStops += 1
		end
	end
	if result.Role == "Murderer" then
		data.MurdererRounds += 1
	elseif result.Role == "Sheriff" then
		data.SheriffRounds += 1
	end
	self:Track(player, "Play", 1)
	if coins > 0 then
		self:AddCoins(player, coins, false, true)
	end
	self:AddXP(player, xp)
	self:CheckAchievements(player)
	self.Services.Net.Fx:FireClient(player, "RoundReward", { XP = math.floor(xp * self:XPMultiplier(player)), Coins = coins + result.Coins, Won = result.Won, Streak = data.WinStreak, MVP = result.MVP, LastSurvivor = result.LastSurvivor })
	self.Services.MonetizationService:AfterRound(player, result)
end

---------------------------------------------------------------- Belohnungen

function ProgressService:ClaimObby(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local left = data.LastObby + Config.Obby.Cooldown - os.time()
	if left > 0 then
		self.Services.Net.SendNotify(player, `Obby reward ready in {Format.Time(left)}`, C.Orange)
		return
	end
	data.LastObby = os.time()
	self:AddCoins(player, Config.Obby.Reward, false)
	self:AddXP(player, 50)
	self.Services.Net.SendNotify(player, `Obby complete! +{Config.Obby.Reward} coins`, C.Green)
	local spawn = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("LobbySpawn")
	if spawn and player.Character then
		player.Character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

function ProgressService:Daily(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local day = today()
	if data.LastDaily == day then
		return
	end
	data.DailyStreak = if data.LastDaily == day - 1 then data.DailyStreak + 1 else 1
	data.LastDaily = day
	local list = Config.DailyRewards
	local reward = list[(data.DailyStreak - 1) % #list + 1]
	self:AddCoins(player, reward, false, true)
	self.Services.Net.Fx:FireClient(player, "Daily", { Streak = data.DailyStreak, Coins = reward, List = list })
end

function ProgressService:Spin(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return { Ok = false }
	end
	if os.time() < data.LastSpin + Config.Spin.Cooldown then
		return { Ok = false, Error = "Come back later!" }
	end
	data.LastSpin = os.time()
	local total = 0
	for _, prize in Config.Spin.Prizes do
		total += prize.Weight
	end
	local roll = math.random() * total
	local index = #Config.Spin.Prizes
	for i, prize in Config.Spin.Prizes do
		roll -= prize.Weight
		if roll <= 0 then
			index = i
			break
		end
	end
	local prize = Config.Spin.Prizes[index]
	local text = prize.Text
	if prize.Coins then
		self:AddCoins(player, prize.Coins, false, true)
	elseif prize.XP then
		self:AddXP(player, prize.XP, true)
	elseif prize.Skin then
		local kind, id = self.Services.InventoryService:RandomOfRarity(prize.Skin)
		if kind then
			self.Services.InventoryService:Grant(player, kind, id, 1)
			text = (Config.GetItem(kind, id) :: any).Name
		end
	end
	self:Refresh(player)
	return { Ok = true, Index = index, Text = text }
end

function ProgressService:Redeem(player: Player, code: string)
	local data = self.Services.DataService:Get(player)
	if not data or typeof(code) ~= "string" then
		return { Ok = false }
	end
	code = string.upper((code:gsub("%s", "")))
	local reward = Config.Codes[code]
	if not reward then
		return { Ok = false, Error = "Invalid code" }
	end
	if data.Codes[code] then
		return { Ok = false, Error = "Already used" }
	end
	data.Codes[code] = true
	if reward.Coins then
		self:AddCoins(player, reward.Coins, false)
	end
	if reward.XP then
		self:AddXP(player, reward.XP, true)
	end
	if reward.Item then
		self.Services.InventoryService:Grant(player, reward.Item[1], reward.Item[2], 1)
	end
	self:Refresh(player)
	return { Ok = true, Text = if reward.Coins then `+{reward.Coins} coins` elseif reward.XP then `+{reward.XP} XP` else "New skin unlocked!" }
end

function ProgressService:Prestige(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or data.Level < Config.PrestigeLevel then
		return { Ok = false, Error = `Reach level {Config.PrestigeLevel} first` }
	end
	data.Level = 1
	data.XP = 0
	data.Prestige += 1
	data.Coins += 2500
	self.Services.Net.SendAnnounce(`{player.DisplayName} prestiged! ★{data.Prestige}`, C.Moon)
	self:CheckAchievements(player)
	self:UpdateNameplate(player)
	self:Refresh(player)
	return { Ok = true }
end

---------------------------------------------------------------- Start

function ProgressService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if data.Quests.Day ~= today() then
		rollQuests(data)
	end
	if data.WeeklyQuests.Week ~= thisWeek() then
		rollWeekly(data)
	end
	self:GrantBattlePass(player)
	self:CheckAchievements(player)
	self:Sync(player)
	task.delay(4, function()
		if player.Parent then
			self:Daily(player)
			self:Sync(player)
		end
	end)
end

function ProgressService:OnCharacterAdded(player: Player, character: Model)
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	if player.Character == character then
		self:UpdateNameplate(player)
	end
end

function ProgressService:Init(services)
	self.Services = services
	local Net = services.Net
	Net.Handle("Spin", function(player)
		return self:Spin(player)
	end)
	Net.Handle("Redeem", function(player, code)
		return self:Redeem(player, code)
	end)
	Net.Handle("Prestige", function(player)
		return self:Prestige(player)
	end)
	Net.Handle("Profile", function(player)
		self:Sync(player)
		return { Ok = true }
	end)
	Net.Handle("Title", function(player, title)
		local data = services.DataService:Get(player)
		if not data or typeof(title) ~= "string" or (title ~= "" and not data.Titles[title]) then
			return { Ok = false }
		end
		data.Equipped.Title = title
		self:UpdateNameplate(player)
		self:Refresh(player)
		return { Ok = true }
	end)
	-- Einstellungen (nur bekannte Schalter, nur true/false)
	Net.Handle("Setting", function(player, key, value)
		local data = services.DataService:Get(player)
		if not data or typeof(key) ~= "string" or not Config.SettingKeys[key] or typeof(value) ~= "boolean" then
			return { Ok = false }
		end
		data.Settings[key] = value
		self:Refresh(player)
		return { Ok = true }
	end)
	Net.Handle("Tutorial", function(player)
		local data = services.DataService:Get(player)
		if data then
			data.Tutorial = true
		end
		return { Ok = true }
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
	-- Namensschild ein/aus je nach Runde
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("InRound"):Connect(function()
			local plate = player.Character and player.Character:FindFirstChild("Nameplate")
			if plate and plate:IsA("BillboardGui") then
				plate.Enabled = player:GetAttribute("InRound") ~= true
			end
		end)
	end)
end

return ProgressService
