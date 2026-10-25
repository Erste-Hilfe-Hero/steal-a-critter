-- Rangliste "Top Gardeners" aller Server (OrderedDataStore nach Gesamtverdienst) als Tafel am Marktplatz.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local LeaderboardService = { Services = nil :: any }

local ROWS = 10
local REFRESH = 120 -- Sekunden
local MAX_VALUE = 2 ^ 53 -- OrderedDataStore speichert nur ganze Zahlen

local store = DataStoreService:GetOrderedDataStore(Config.LeaderboardStore)
local nameCache = {} -- [UserId] = Name
local rowLabels = {} -- { { Name, Value } }

function LeaderboardService:Init(services)
	self.Services = services
end

local function scoreOf(data): number
	return math.floor(math.clamp(data.TotalEarned or 0, 0, MAX_VALUE))
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Gardener"
end

function LeaderboardService:Submit(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or not self.Services.DataService:CanSave(player) then
		return
	end
	local score = scoreOf(data)
	if score <= 0 then
		return
	end
	pcall(store.SetAsync, store, "u_" .. player.UserId, score)
end

local function refreshBoard()
	local ok, pages = pcall(store.GetSortedAsync, store, false, ROWS)
	if not ok or not pages then
		return
	end
	local entries = pages:GetCurrentPage()
	for index, row in rowLabels do
		local entry = entries[index]
		if entry then
			local userId = tonumber((entry.key :: string):match("%d+")) or 0
			row.Name.Text = `#{index}  {nameFor(userId)}`
			row.Value.Text = Format.Cash(entry.value)
		else
			row.Name.Text = `#{index}  -`
			row.Value.Text = ""
		end
	end
end

-- Tafel zwischen Spawn und den vorderen Gaerten, zum Spawn hin ausgerichtet
local function buildBoard(world)
	local makePart = world.MakePart
	local folder = Instance.new("Folder")
	folder.Name = "Leaderboard"
	local position = Vector3.new(0, 8, -22)
	local board = makePart({
		Name = "Board",
		Size = Vector3.new(16, 12, 0.6),
		CFrame = CFrame.lookAt(position, Vector3.new(0, 8, 0)),
		Color = Color3.fromRGB(60, 40, 25),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	for _, x in { -7.5, 7.5 } do
		makePart({ Name = "Post", Size = Vector3.new(0.8, 14, 0.8), Position = Vector3.new(x, 7, -22.6), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood, Parent = folder })
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = gui
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.PaddingTop = UDim.new(0, 14)
	padding.Parent = gui
	local function text(parent: Instance, props): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.4
		for key, value in props do
			(label :: any)[key] = value
		end
		label.Parent = parent
		return label
	end
	text(gui, { Name = "Title", Size = UDim2.new(1, 0, 0, 56), Text = "TOP GARDENERS (all servers)", TextColor3 = Color3.fromRGB(255, 215, 80), LayoutOrder = 0 })
	for index = 1, ROWS do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 36)
		row.LayoutOrder = index
		row.Parent = gui
		local color = if index == 1 then Color3.fromRGB(255, 215, 80) elseif index == 2 then Color3.fromRGB(220, 220, 230) elseif index == 3 then Color3.fromRGB(230, 160, 90) else Color3.new(1, 1, 1)
		local name = text(row, { Size = UDim2.new(0.65, 0, 1, 0), Text = `#{index}  -`, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color })
		local value = text(row, { Position = UDim2.fromScale(0.65, 0), Size = UDim2.new(0.35, 0, 1, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(140, 255, 140) })
		rowLabels[index] = { Name = name, Value = value }
	end
	folder.Parent = workspace:FindFirstChild("World") or workspace
end

function LeaderboardService:OnPlayerRemoving(player: Player)
	nameCache[player.UserId] = player.DisplayName
	task.spawn(self.Submit, self, player)
end

function LeaderboardService:Start()
	buildBoard(self.Services.WorldService)
	task.spawn(function()
		task.wait(10)
		while true do
			for _, player in Players:GetPlayers() do
				self:Submit(player)
			end
			refreshBoard()
			task.wait(REFRESH)
		end
	end)
end

return LeaderboardService
