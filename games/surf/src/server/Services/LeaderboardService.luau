-- Weltweite Bestenlisten (OrderedDataStore, Zeit in Millisekunden, aufsteigend = schnellste zuerst):
-- Top 10 fuer die ganze Map und der Rekord (WR) jeder Stage. Landet als JSON in ReplicatedStorage.Leaderboard
-- fuer die UI und auf der grossen Tafel in der Lobby.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local LeaderboardService = { Services = nil :: any }

local THEME = Config.Theme
local mapStore = DataStoreService:GetOrderedDataStore(Config.BestTimeStore)
local stageStores = {}
for stage = 1, #Config.Stages do
	stageStores[stage] = DataStoreService:GetOrderedDataStore(Config.StageStorePrefix .. stage)
end

local names = {} -- [UserId] = Name
local value: StringValue
local current = { Map = {}, Stages = {} }

function LeaderboardService:Init(services)
	self.Services = services
	value = Instance.new("StringValue")
	value.Name = "Leaderboard"
	value.Value = HttpService:JSONEncode(current)
	value.Parent = ReplicatedStorage
end

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else "Player"
	return names[userId]
end

-- Nur speichern, wenn es schneller ist als der gespeicherte Wert
local function submit(store: OrderedDataStore, userId: number, seconds: number)
	local ms = math.max(1, math.floor(seconds * 1000 + 0.5))
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync("u_" .. userId, function(old)
				if old and old <= ms then
					return nil
				end
				return ms
			end)
		end)
		if not ok then
			warn("[Leaderboard]", err)
		end
	end)
end

function LeaderboardService:Submit(player: Player, seconds: number)
	submit(mapStore, player.UserId, seconds)
	-- Sofort lokal einsortieren, damit der Spieler sich direkt auf der Tafel sieht
	local list = current.Map
	local found = false
	for _, row in list do
		if row.UserId == player.UserId then
			row.Time = math.min(row.Time, seconds)
			found = true
		end
	end
	if not found then
		table.insert(list, { UserId = player.UserId, Name = player.DisplayName, Time = seconds })
	end
	table.sort(list, function(a, b)
		return a.Time < b.Time
	end)
	while #list > 10 do
		table.remove(list)
	end
	self:Publish()
end

function LeaderboardService:SubmitStage(player: Player, stage: number, seconds: number)
	submit(stageStores[stage], player.UserId, seconds)
	local record = current.Stages[tostring(stage)]
	if not record or seconds < record.Time then
		current.Stages[tostring(stage)] = { UserId = player.UserId, Name = player.DisplayName, Time = seconds }
		if record then
			self.Services.Net.SendAnnounce(`NEW WORLD RECORD! {player.DisplayName} - Stage {stage} in {Format.Run(seconds)}`, THEME.Aurora)
		end
		self:Publish()
	end
end

local function readTop(store: OrderedDataStore, count: number)
	local ok, pages = pcall(store.GetSortedAsync, store, true, count)
	if not ok then
		warn("[Leaderboard]", pages)
		return nil
	end
	local rows = {}
	for _, entry in pages:GetCurrentPage() do
		local userId = tonumber(string.sub(entry.key, 3))
		if userId then
			table.insert(rows, { UserId = userId, Name = nameOf(userId), Time = entry.value / 1000 })
		end
	end
	return rows
end

local function drawBoard()
	local board = LeaderboardService.Services.WorldService.Board
	local gui = board and board:FindFirstChild("BoardGui")
	if not gui then
		return
	end
	gui:ClearAllChildren()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 24)
	padding.PaddingLeft = UDim.new(0, 24)
	padding.PaddingRight = UDim.new(0, 24)
	padding.Parent = gui
	local function row(text: string, color: Color3, height: number, font: Enum.FontWeight?)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", font or Enum.FontWeight.Bold)
		label.TextColor3 = color
		label.Parent = gui
		return label
	end
	local title = row("WORLD TOP 10  -  surf_ski", THEME.Ice, 56, Enum.FontWeight.Heavy)
	title.TextXAlignment = Enum.TextXAlignment.Center
	if #current.Map == 0 then
		row("No times yet. Be the first!", THEME.Muted, 34)
	end
	for i, entry in current.Map do
		local color = if i == 1 then THEME.Gold elseif i <= 3 then THEME.Snow else THEME.Muted
		local label = row(string.format("%2d.  %-18s %s", i, string.sub(entry.Name, 1, 18), Format.Run(entry.Time)), color, 36)
		label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	end
	row("STAGE RECORDS", THEME.Aurora, 40, Enum.FontWeight.Heavy).TextXAlignment = Enum.TextXAlignment.Center
	for stage = 1, #Config.Stages do
		local record = current.Stages[tostring(stage)]
		local text = if record then string.format("S%-2d  %-18s %s", stage, string.sub(record.Name, 1, 18), Format.Run(record.Time)) else string.format("S%-2d  -", stage)
		local label = row(text, THEME.Snow, 26)
		label.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium)
	end
end

function LeaderboardService:Publish()
	value.Value = HttpService:JSONEncode(current)
	drawBoard()
end

function LeaderboardService:Refresh()
	local map = readTop(mapStore, 10)
	if map then
		-- OrderedDataStores liefern frische Zeiten oft erst nach einer Weile: lokal bekannte
		-- bessere Zeiten behalten, statt sie beim Neuladen wieder von der Tafel zu werfen
		for _, old in current.Map do
			local found = false
			for _, row in map do
				if row.UserId == old.UserId then
					row.Time = math.min(row.Time, old.Time)
					found = true
				end
			end
			if not found then
				table.insert(map, old)
			end
		end
		table.sort(map, function(a, b)
			return a.Time < b.Time
		end)
		while #map > 10 do
			table.remove(map)
		end
		current.Map = map
	end
	for stage, store in stageStores do
		local top = readTop(store, 1)
		local known = current.Stages[tostring(stage)]
		if top and top[1] and (not known or top[1].Time <= known.Time) then
			current.Stages[tostring(stage)] = top[1]
		end
		task.wait(0.5)
	end
	self:Publish()
end

function LeaderboardService:Start()
	drawBoard()
	task.spawn(function()
		while true do
			self:Refresh()
			task.wait(120)
		end
	end)
end

return LeaderboardService
