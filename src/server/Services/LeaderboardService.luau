-- Globale Ranglisten auf Tafeln neben dem Spawn (Angeben motiviert): reichste Spieler, meiste Rebirths, beste Diebe.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local LeaderboardService = { Services = nil :: any }

-- Offset: Position relativ zum Spawn (alle Tafeln blicken Richtung Laufband)
local BOARDS = {
	{ Name = "Leaderboard", Store = Config.LeaderboardStore, Title = "👑 RICHEST CRITTER BOSSES 👑", Color = Color3.fromRGB(255, 190, 30), Offset = Vector3.new(-10, 6.5, 0), Value = function(data)
		return data.TotalEarned
	end, Format = Format.Cash },
	{ Name = "RebirthBoard", Store = "TopRebirths_v1", Title = "♻️ MOST REBIRTHS ♻️", Color = Color3.fromRGB(170, 100, 255), Offset = Vector3.new(-6, 6.5, -20), Value = function(data)
		return data.Rebirths
	end, Format = Format.Number },
	{ Name = "ThiefBoard", Store = "TopThieves_v1", Title = "🦝 TOP THIEVES 🦝", Color = Color3.fromRGB(255, 90, 90), Offset = Vector3.new(-6, 6.5, 20), Value = function(data)
		return data.Stats and data.Stats.Stolen or 0
	end, Format = Format.Number },
}

local nameCache = {}

local function nameFor(userId: number): string
	if not nameCache[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		nameCache[userId] = if ok then name else "?"
	end
	return nameCache[userId]
end

local function buildBoard(board)
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = if spawn then spawn.Position else Vector3.new(0, 0.5, 0)
	local part = Instance.new("Part")
	part.Name = board.Name
	part.Anchored = true
	part.Size = Vector3.new(16, 12, 1)
	part.Color = Color3.fromRGB(30, 25, 50)
	part.Material = Enum.Material.SmoothPlastic
	local position = base + board.Offset
	part.CFrame = CFrame.lookAt(position, position + Vector3.new(20, 0, -board.Offset.Z * 0.6))
	part.Parent = workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(640, 480)
	gui.LightInfluence = 0
	gui.Parent = part

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundColor3 = board.Color
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(30, 20, 40)
	title.Text = board.Title
	title.Parent = gui

	board.Rows = {}
	for i = 1, Config.LeaderboardSize do
		local row = Instance.new("TextLabel")
		row.Position = UDim2.new(0, 16, 0, 64 + (i - 1) * 41)
		row.Size = UDim2.new(1, -32, 0, 38)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if i == 1 then Color3.fromRGB(255, 215, 60)
			elseif i == 2 then Color3.fromRGB(220, 225, 235)
			elseif i == 3 then Color3.fromRGB(230, 150, 80)
			else Color3.new(1, 1, 1)
		row.Text = `#{i}  ...`
		row.Parent = gui
		board.Rows[i] = row
	end
	board.DataStore = DataStoreService:GetOrderedDataStore(board.Store)
end

local function saveScores(board)
	for _, player in Players:GetPlayers() do
		local data = LeaderboardService.Services.DataService:Get(player)
		local value = data and board.Value(data) or 0
		if value > 0 then
			-- OrderedDataStore braucht Ganzzahlen; sehr grosse Werte begrenzen
			pcall(board.DataStore.SetAsync, board.DataStore, tostring(player.UserId), math.floor(math.min(value, 2 ^ 52)))
		end
	end
end

local function refreshBoard(board)
	local ok, pages = pcall(board.DataStore.GetSortedAsync, board.DataStore, false, Config.LeaderboardSize)
	if not ok then
		return
	end
	local entries = pages:GetCurrentPage()
	for i, row in board.Rows do
		local entry = entries[i]
		if entry then
			row.Text = `#{i}  {nameFor(tonumber(entry.key) or 0)}  -  {board.Format(entry.value)}`
		else
			row.Text = `#{i}  ...`
		end
	end
end

function LeaderboardService:Init(services)
	self.Services = services
end

function LeaderboardService:Start()
	for _, board in BOARDS do
		buildBoard(board)
	end
	task.spawn(function()
		task.wait(5)
		while true do
			for _, board in BOARDS do
				saveScores(board)
				refreshBoard(board)
			end
			task.wait(120)
		end
	end)
end

return LeaderboardService
