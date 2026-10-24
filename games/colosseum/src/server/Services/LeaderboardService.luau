-- Bestenlisten am Spawn-Platz (Gauntlet-Rekord und Duell-Trophaeen), gespeichert in OrderedDataStores.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local LeaderboardService = { Services = nil :: any }

local BOARDS = {
	BestWave = { Store = "BestWave_v1", Suffix = " waves" },
	Trophies = { Store = "Trophies_v1", Suffix = " trophies" },
}
local names = {} -- [UserId] = Name

function LeaderboardService:Init(services)
	self.Services = services
end

local function nameFor(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "?"
	return names[userId]
end

local function render(boardPart: BasePart, title: string, rows: { { any } }, suffix: string)
	local gui = boardPart:FindFirstChild("BoardGui") :: SurfaceGui?
	if not gui then
		local newGui = Instance.new("SurfaceGui")
		newGui.Name = "BoardGui"
		newGui.Face = Enum.NormalId.Front
		newGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		newGui.PixelsPerStud = 30
		newGui.LightInfluence = 0
		newGui.Parent = boardPart
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 6)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = newGui
		local padding = Instance.new("UIPadding")
		padding.PaddingTop = UDim.new(0, 18)
		padding.Parent = newGui
		gui = newGui
	end
	assert(gui)
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(0.92, 0, 0, 60)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.LuckiestGuy
	header.TextScaled = true
	header.Text = title
	header.TextColor3 = Color3.fromRGB(240, 190, 80)
	header.LayoutOrder = 0
	header.Parent = gui
	for index, row in rows do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.9, 0, 0, 40)
		label.BackgroundTransparency = if index <= 3 then 0.6 else 1
		label.BackgroundColor3 = ({ Color3.fromRGB(240, 190, 80), Color3.fromRGB(200, 200, 210), Color3.fromRGB(200, 130, 80) })[index] or Color3.new(0, 0, 0)
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = `  #{index}  {row[1]}  -  {row[2]}{suffix}`
		label.TextColor3 = Color3.fromRGB(250, 240, 220)
		label.LayoutOrder = index
		label.Parent = gui
	end
	if #rows == 0 then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.9, 0, 0, 40)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.BuilderSansBold
		label.TextScaled = true
		label.Text = "Be the first!"
		label.TextColor3 = Color3.fromRGB(250, 240, 220)
		label.LayoutOrder = 1
		label.Parent = gui
	end
end

function LeaderboardService:Start()
	task.spawn(function()
		while true do
			for key, info in BOARDS do
				local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, info.Store)
				if ok then
					for _, player in Players:GetPlayers() do
						local data = self.Services.DataService:Get(player)
						if data and data[key] > 0 then
							pcall(store.SetAsync, store, tostring(player.UserId), data[key])
						end
					end
					local rows = {}
					local success, pages = pcall(store.GetSortedAsync, store, false, 10)
					if success then
						for _, entry in pages:GetCurrentPage() do
							table.insert(rows, { nameFor(tonumber(entry.key) or 0), entry.value })
						end
					end
					local boardPart = self.Services.WorldService.Boards[key]
					if boardPart then
						render(boardPart, boardPart:GetAttribute("Title") or key, rows, info.Suffix)
					end
				end
			end
			task.wait(120)
		end
	end)
end

return LeaderboardService
