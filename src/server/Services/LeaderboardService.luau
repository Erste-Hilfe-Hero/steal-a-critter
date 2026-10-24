-- Globale Rangliste "Richest Critter Bosses" auf einer Tafel neben dem Spawn (Angeben motiviert).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local LeaderboardService = { Services = nil :: any }

local store = DataStoreService:GetOrderedDataStore(Config.LeaderboardStore)
local rows: { TextLabel } = {}
local nameCache = {}

local function nameFor(userId: number): string
	if not nameCache[userId] then
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
		nameCache[userId] = if ok then name else "?"
	end
	return nameCache[userId]
end

local function buildBoard()
	local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local base = if spawn then spawn.Position else Vector3.new(0, 0.5, 0)
	local board = Instance.new("Part")
	board.Name = "Leaderboard"
	board.Anchored = true
	board.Size = Vector3.new(16, 12, 1)
	board.Color = Color3.fromRGB(30, 25, 50)
	board.Material = Enum.Material.SmoothPlastic
	-- Hinter dem Spawn, Blick Richtung Laufband (+X)
	board.CFrame = CFrame.lookAt(base + Vector3.new(-10, 6.5, 0), base + Vector3.new(10, 6.5, 0))
	board.Parent = workspace

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(640, 480)
	gui.LightInfluence = 0
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 64)
	title.BackgroundColor3 = Color3.fromRGB(255, 190, 30)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(30, 20, 40)
	title.Text = "👑 RICHEST CRITTER BOSSES 👑"
	title.Parent = gui

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
		rows[i] = row
	end
end

local function saveScores()
	for _, player in Players:GetPlayers() do
		local data = LeaderboardService.Services.DataService:Get(player)
		if data and data.TotalEarned > 0 then
			-- OrderedDataStore braucht Ganzzahlen; sehr grosse Werte begrenzen
			pcall(store.SetAsync, store, tostring(player.UserId), math.floor(math.min(data.TotalEarned, 2 ^ 52)))
		end
	end
end

local function refreshBoard()
	local ok, pages = pcall(store.GetSortedAsync, store, false, Config.LeaderboardSize)
	if not ok then
		return
	end
	local entries = pages:GetCurrentPage()
	for i, row in rows do
		local entry = entries[i]
		if entry then
			row.Text = `#{i}  {nameFor(tonumber(entry.key) or 0)}  -  {Format.Cash(entry.value)}`
		else
			row.Text = `#{i}  ...`
		end
	end
end

function LeaderboardService:Init(services)
	self.Services = services
end

function LeaderboardService:Start()
	buildBoard()
	task.spawn(function()
		task.wait(5)
		while true do
			saveScores()
			refreshBoard()
			task.wait(120)
		end
	end)
end

return LeaderboardService
