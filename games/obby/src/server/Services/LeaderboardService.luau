-- Globale Bestenlisten in der Lobby: meiste Siege und schnellster Lauf ohne Skips (OrderedDataStore).
-- Wird alle paar Minuten aktualisiert; alle DataStore-Aufrufe laufen in pcall.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local LeaderboardService = { Services = nil :: any }

local REFRESH = 120
local TOP = 10

local winsStore = DataStoreService:GetOrderedDataStore("ObbyTopWins_v1")
local timeStore = DataStoreService:GetOrderedDataStore("ObbyTopTime_v1") -- Zehntelsekunden, aufsteigend
local pushed = {} -- [UserId] = { Wins, Time } zuletzt geschriebene Werte
local names = {} -- [UserId] = Name (Cache)

function LeaderboardService:Init(services)
	self.Services = services
end

local function nameFor(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok and name then name else "Player"
	return names[userId]
end

-- Tafel aufbauen: Titel + 10 Zeilen
local function buildBoard(board: BasePart, title: string, color: Color3): { TextLabel }
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Board"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Size = UDim2.fromScale(1, 0.14)
	header.Font = Enum.Font.FredokaOne
	header.TextScaled = true
	header.Text = title
	header.TextColor3 = color
	header.Parent = gui
	local rows = {}
	for i = 1, TOP do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.05, 0.15 + (i - 1) * 0.083)
		label.Size = UDim2.fromScale(0.9, 0.075)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 80) elseif i <= 3 then Color3.fromRGB(230, 230, 255) else Color3.fromRGB(190, 186, 214)
		label.Text = if i == 1 then "Loading..." else ""
		label.Parent = gui
		table.insert(rows, label)
	end
	gui.Parent = board
	return rows
end

local function render(rows: { TextLabel }, store: OrderedDataStore, ascending: boolean, formatValue: (number) -> string)
	local ok, pages = pcall(store.GetSortedAsync, store, ascending, TOP)
	if not ok or not pages then
		return
	end
	local entries = pages:GetCurrentPage()
	for i, label in rows do
		local entry = entries[i]
		if entry then
			label.Text = `#{i}  {nameFor(tonumber(entry.key) or 0)}  -  {formatValue(entry.value)}`
		else
			label.Text = if i == 1 then "Be the first!" else ""
		end
	end
end

-- Eigene Werte hochladen, wenn sie sich geaendert haben
function LeaderboardService:Push(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local key = tostring(player.UserId)
	local last = pushed[player.UserId] or {}
	if data.Wins > 0 and last.Wins ~= data.Wins then
		if pcall(winsStore.SetAsync, winsStore, key, data.Wins) then
			last.Wins = data.Wins
		end
	end
	local tenths = math.floor(data.BestTime * 10 + 0.5)
	if tenths > 0 and last.Time ~= tenths then
		if pcall(timeStore.SetAsync, timeStore, key, tenths) then
			last.Time = tenths
		end
	end
	pushed[player.UserId] = last
end

function LeaderboardService:OnPlayerRemoving(player: Player)
	task.spawn(function()
		self:Push(player)
		pushed[player.UserId] = nil
	end)
end

function LeaderboardService:Start()
	local boards = self.Services.WorldService.Boards
	local winRows = buildBoard(boards.Wins, "🏆 MOST WINS", Color3.fromRGB(255, 210, 60))
	local timeRows = buildBoard(boards.Time, "⏱ FASTEST RUNS", Color3.fromRGB(120, 230, 255))
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				self:Push(player)
			end
			render(winRows, winsStore, false, function(value)
				return Format.Number(value) .. " wins"
			end)
			render(timeRows, timeStore, true, function(value)
				return Config.FormatRunTime(value / 10)
			end)
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
