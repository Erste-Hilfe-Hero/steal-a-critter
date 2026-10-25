-- Fortschritt und Bindung: Tagesaufgaben, Erfolge mit Titeln, Sammel-Index, Spielzeit-Geschenke, Codes,
-- Einstellungen, Happy Hour (Server-Event) und globale Bestenlisten.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local ProgressService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)
local PINK = Color3.fromRGB(255, 120, 220)

local sessionStart = {} -- [Player] = os.clock()
local playtimeClaimed = {} -- [Player] = { [index] = true } (nur diese Sitzung)
local lastCode = {} -- [Player] = os.clock()
local lastSetting = {} -- [Player] = os.clock()
local dirty = {} -- [Player] = true (Zustand muss an den Client)

-- Bestenlisten (OrderedDataStore braucht ganze Zahlen)
local BOARDS = {
	{ Key = "Hatched", Title = "TOP HATCHERS", Store = "PetSimTopHatched_v1", Stat = "Hatched" },
	{ Key = "Rebirths", Title = "TOP REBIRTHS", Store = "PetSimTopRebirths_v1", Stat = "Rebirths" },
}
local BOARD_SIZE = 10
local BOARD_REFRESH = 120
local nameCache = {} -- [UserId] = Name

local function notify(player: Player, text: string, color: Color3?)
	ProgressService.Services.Net.SendNotify(player, text, color)
end

local function today(): number
	return os.time() // 86400
end

local function getData(player: Player)
	return ProgressService.Services.DataService:Get(player)
end

local function countKeys(t): number
	local count = 0
	for _ in t do
		count += 1
	end
	return count
end

---------------------------------------------------------------- Belohnungen

-- reward = { Eggs = n } oder { BoostSeconds = s }; gibt einen Text fuer die Meldung zurueck
function ProgressService:GiveReward(player: Player, reward): string
	local services = self.Services
	local data = getData(player)
	if not data then
		return ""
	end
	local parts = {}
	if reward.Eggs then
		local coins = math.floor(services.PetService:EggValue(player, reward.Eggs))
		services.DataService:AddCoins(player, coins)
		table.insert(parts, "+" .. Format.Coins(coins))
	end
	if reward.BoostSeconds then
		data.BoostUntil = math.max(os.time(), data.BoostUntil) + reward.BoostSeconds
		services.DataService:UpdateAttributes(player)
		table.insert(parts, `2x Coins for {reward.BoostSeconds // 60} min`)
	end
	return table.concat(parts, " + ")
end

---------------------------------------------------------------- Zustand an den Client

function ProgressService:MarkDirty(player: Player)
	dirty[player] = true
end

function ProgressService:Push(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local claimed = {}
	for index in (playtimeClaimed[player] or {}) do
		table.insert(claimed, index)
	end
	self.Services.Net.Progress:FireClient(player, {
		QuestDay = data.Quests.Day,
		Quests = data.Quests.List,
		Achievements = data.Achievements,
		Discovered = data.Discovered,
		Title = data.Title,
		PlaytimeClaimed = claimed,
		Stats = {
			Hatched = data.Hatched,
			Broken = data.Broken,
			GoldenMade = data.GoldenMade,
			RainbowMade = data.RainbowMade,
			BestZone = data.BestZone,
			Rebirths = data.Rebirths,
			Discovered = countKeys(data.Discovered),
			Streak = data.Streak,
		},
	})
end

---------------------------------------------------------------- Erfolge und Titel

local function statValue(data, stat: string): number
	if stat == "Discovered" then
		return countKeys(data.Discovered)
	end
	return tonumber(data[stat]) or 0
end

function ProgressService:CheckAchievements(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	for _, achievement in Config.Achievements do
		if not data.Achievements[achievement.Id] and statValue(data, achievement.Stat) >= achievement.Goal then
			data.Achievements[achievement.Id] = true
			local rewardText = self:GiveReward(player, achievement)
			notify(player, `Achievement: {achievement.Text}! Title "{achievement.Title}" unlocked. {rewardText}`, GOLD)
			self:MarkDirty(player)
		end
	end
end

local function applyTitle(player: Player, data)
	local achievement = Config.AchievementsById[data.Title]
	if not achievement or not data.Achievements[data.Title] then
		data.Title = ""
	end
	player:SetAttribute("Title", if achievement and data.Title ~= "" then achievement.Title else nil)
end

---------------------------------------------------------------- Tagesaufgaben

local function refreshQuests(player: Player, data)
	if data.Quests.Day == today() then
		return
	end
	local list = {}
	for _, id in Config.QuestsForDay(today(), player.UserId) do
		table.insert(list, { Id = id, Progress = 0, Claimed = false })
	end
	data.Quests = { Day = today(), List = list }
	ProgressService:MarkDirty(player)
end

---------------------------------------------------------------- Fortschritt melden

-- kind: Hatch, Break, Chest, Tap, Gift, Play, Golden, Rainbow, Zone, Rebirth, Streak
function ProgressService:Track(player: Player, kind: string, amount: number)
	local data = getData(player)
	if not data then
		return
	end
	if kind == "Break" then
		data.Broken += amount
	elseif kind == "Golden" then
		data.GoldenMade += amount
	elseif kind == "Rainbow" then
		data.RainbowMade += amount
	end
	refreshQuests(player, data)
	for _, quest in data.Quests.List do
		local def = Config.QuestsById[quest.Id]
		if def and def.Kind == kind and not quest.Claimed and quest.Progress < def.Goal then
			quest.Progress = math.min(def.Goal, quest.Progress + amount)
			if quest.Progress >= def.Goal then
				notify(player, `Quest complete: {def.Text}! Claim it in Quests.`, GREEN)
			end
			self:MarkDirty(player)
		end
	end
	self:CheckAchievements(player)
	-- Zaehler fuer die Anzeige im Erfolge-Fenster
	if kind ~= "Tap" and kind ~= "Play" then
		self:MarkDirty(player)
	end
end

---------------------------------------------------------------- Sammel-Index

function ProgressService:Discover(player: Player, typeId: string)
	local data = getData(player)
	if not data or data.Discovered[typeId] then
		return
	end
	local before = Config.CompletedEggs(data.Discovered)
	data.Discovered[typeId] = true
	local def = Config.PetsById[typeId]
	if def and data.GotStarter and countKeys(data.Discovered) > 1 then
		notify(player, `New pet in your Index: {def.Name}!`, PINK)
	end
	if Config.CompletedEggs(data.Discovered) > before then
		notify(player, `Index complete for an egg! +{math.floor(Config.IndexBonusPerEgg * 100)}% coins forever!`, GOLD)
	end
	self:CheckAchievements(player)
	self:MarkDirty(player)
end

---------------------------------------------------------------- Einstellungen

local function applySettings(player: Player, data)
	for key, default in Config.Settings do
		local value = data.Settings[key]
		player:SetAttribute("Set_" .. key, if value == nil then default else value)
	end
end

---------------------------------------------------------------- Bestenlisten

local function buildBoard(parent: Instance, position: Vector3, title: string): { TextLabel }
	local board = Instance.new("Part")
	board.Name = "Leaderboard"
	board.Anchored = true
	board.Size = Vector3.new(1, 13, 16)
	board.Position = position
	board.Color = Color3.fromRGB(28, 30, 48)
	board.Material = Enum.Material.SmoothPlastic
	board.Parent = parent
	for _, z in { -7.4, 7.4 } do
		local post = Instance.new("Part")
		post.Name = "Post"
		post.Anchored = true
		post.Size = Vector3.new(1.2, position.Y + 6.5, 1.2)
		post.Position = Vector3.new(position.X, (position.Y + 6.5) / 2, position.Z + z)
		post.Color = Color3.fromRGB(255, 205, 60)
		post.Material = Enum.Material.SmoothPlastic
		post.Parent = parent
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = gui
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0.16, 0)
	header.BackgroundColor3 = Color3.fromRGB(18, 20, 34)
	header.BorderSizePixel = 0
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.TextColor3 = Color3.fromRGB(255, 205, 60)
	header.Text = title
	header.LayoutOrder = 0
	header.Parent = gui
	local rows = {}
	for i = 1, BOARD_SIZE do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0.084, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 0) elseif i <= 3 then Color3.fromRGB(220, 230, 255) else Color3.new(1, 1, 1)
		row.Text = ""
		row.LayoutOrder = i
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0.05, 0)
		pad.PaddingRight = UDim.new(0.05, 0)
		pad.Parent = row
		row.Parent = gui
		rows[i] = row
	end
	return rows
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Player " .. userId
end

local function runBoards(world: Instance)
	local stores = {}
	for index, board in BOARDS do
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, board.Store)
		stores[index] = if ok then store else nil
		board.Rows = buildBoard(world, Vector3.new(1.5, 8, if index == 1 then -22 else 16), board.Title)
		board.Rows[1].Text = "Loading..."
	end
	while true do
		for index, board in BOARDS do
			local store = stores[index]
			if not store then
				board.Rows[1].Text = "Not available"
				continue
			end
			-- Eigene Werte der Spieler in diesem Server eintragen
			for _, player in Players:GetPlayers() do
				local data = getData(player)
				local value = data and math.floor(tonumber(data[board.Stat]) or 0)
				if value and value > 0 then
					pcall(store.SetAsync, store, tostring(player.UserId), math.min(value, 2 ^ 53))
				end
			end
			local ok, pages = pcall(store.GetSortedAsync, store, false, BOARD_SIZE)
			if ok and pages then
				local entries = pages:GetCurrentPage()
				for i = 1, BOARD_SIZE do
					local entry = entries[i]
					board.Rows[i].Text = if entry then `#{i}  {nameFor(tonumber(entry.key) or 0)}  -  {Format.Number(entry.value)}` else ""
				end
				if #entries == 0 then
					board.Rows[1].Text = "Be the first!"
				end
			elseif board.Rows[1].Text == "Loading..." then
				board.Rows[1].Text = "Not available right now"
			end
		end
		task.wait(BOARD_REFRESH)
	end
end

---------------------------------------------------------------- Lebenszyklus

function ProgressService:Init(services)
	self.Services = services
end

function ProgressService:OnPlayerReady(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	-- Aeltere Spielstaende nachziehen: beste Zone und schon besessene Haustiere im Index
	data.BestZone = math.max(data.BestZone, data.Zone)
	for _, pet in data.Pets do
		if Config.PetsById[pet.T] then
			data.Discovered[pet.T] = true
		end
	end
	sessionStart[player] = os.clock()
	playtimeClaimed[player] = {}
	player:SetAttribute("SessionStart", workspace:GetServerTimeNow())
	refreshQuests(player, data)
	applySettings(player, data)
	applyTitle(player, data)
	self:CheckAchievements(player)
	self:Push(player)
end

function ProgressService:OnPlayerRemoving(player: Player)
	sessionStart[player] = nil
	playtimeClaimed[player] = nil
	lastCode[player] = nil
	lastSetting[player] = nil
	dirty[player] = nil
end

function ProgressService:Start()
	local services = self.Services
	local net = services.Net

	net.ClaimQuest.OnServerEvent:Connect(function(player, questId)
		local data = getData(player)
		if not data or typeof(questId) ~= "string" then
			return
		end
		refreshQuests(player, data)
		for _, quest in data.Quests.List do
			local def = Config.QuestsById[quest.Id]
			if quest.Id == questId and def and not quest.Claimed and quest.Progress >= def.Goal then
				quest.Claimed = true
				notify(player, `Quest reward: {self:GiveReward(player, def)}`, GOLD)
				self:Push(player)
				return
			end
		end
	end)

	net.SetTitle.OnServerEvent:Connect(function(player, achievementId)
		local data = getData(player)
		if not data or typeof(achievementId) ~= "string" then
			return
		end
		if achievementId ~= "" and not data.Achievements[achievementId] then
			return
		end
		data.Title = achievementId
		applyTitle(player, data)
		self:Push(player)
	end)

	net.ClaimPlaytime.OnServerEvent:Connect(function(player, index)
		local data = getData(player)
		local claimed = playtimeClaimed[player]
		if not data or not claimed or typeof(index) ~= "number" or index ~= index or index % 1 ~= 0 then
			return
		end
		local reward = Config.PlaytimeRewards[index]
		if not reward or claimed[index] then
			return
		end
		if os.clock() - sessionStart[player] < reward.Minutes * 60 - 1 then
			notify(player, "This gift is not ready yet!", RED)
			return
		end
		claimed[index] = true
		notify(player, `Playtime gift: {self:GiveReward(player, reward)}`, GOLD)
		self:Track(player, "Gift", 1)
		self:Push(player)
	end)

	net.RedeemCode.OnServerEvent:Connect(function(player, text)
		local data = getData(player)
		if not data or typeof(text) ~= "string" or #text > 30 then
			return
		end
		if os.clock() - (lastCode[player] or 0) < 1 then
			return
		end
		lastCode[player] = os.clock()
		local stripped = string.gsub(text, "%s", "")
		local code = string.upper(stripped)
		local reward = Config.Codes[code]
		if not reward then
			notify(player, "That code does not exist.", RED)
			return
		end
		if data.Codes[code] then
			notify(player, "You already used this code.", RED)
			return
		end
		data.Codes[code] = true
		notify(player, `Code {code}: {self:GiveReward(player, reward)}`, GOLD)
	end)

	net.SetSetting.OnServerEvent:Connect(function(player, key, value)
		local data = getData(player)
		if not data or typeof(key) ~= "string" or typeof(value) ~= "boolean" or Config.Settings[key] == nil then
			return
		end
		if os.clock() - (lastSetting[player] or 0) < 0.1 then
			return
		end
		lastSetting[player] = os.clock()
		data.Settings[key] = value
		applySettings(player, data)
	end)

	-- Zustand gesammelt an die Clients schicken (nicht bei jedem zerstoerten Muenzhaufen einzeln)
	task.spawn(function()
		while true do
			task.wait(1)
			for player in dirty do
				dirty[player] = nil
				if player.Parent then
					self:Push(player)
				end
			end
		end
	end)

	-- Jede aktive Minute zaehlt fuer "Play"-Aufgaben; neuer Tag = neue Aufgaben
	task.spawn(function()
		while true do
			task.wait(60)
			for player in sessionStart do
				local data = getData(player)
				if data then
					refreshQuests(player, data)
					if services.CommunityService:IsActive(player) then
						self:Track(player, "Play", 1)
					end
				end
			end
		end
	end)

	-- Happy Hour ansagen, wenn sie beginnt
	task.spawn(function()
		local wasActive = Config.HappyHourState(os.time())
		while true do
			task.wait(1)
			local active = Config.HappyHourState(os.time())
			if active and not wasActive then
				net.SendAnnounce(`HAPPY HOUR! x{Config.HappyHourMultiplier} coins for everyone for {Config.HappyHourLength // 60} minutes!`, GOLD)
			end
			wasActive = active
		end
	end)

	task.spawn(runBoards, workspace:WaitForChild("World"))
end

return ProgressService
