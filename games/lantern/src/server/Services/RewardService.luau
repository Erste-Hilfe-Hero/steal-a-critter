-- Gruende wiederzukommen und Freunde mitzubringen: Tagesbelohnung mit Serie,
-- Freundes-Bonus im Server und die Bestenliste (hoechste Stufe) auf dem Stadtplatz.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local RewardService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 60)
local board = DataStoreService:GetOrderedDataStore(Config.LeaderboardStore)
local pending = {} -- [UserId] = Score
local rng = Random.new()

function RewardService:Init(services)
	self.Services = services
end

local function today(): number
	return os.time() // 86400
end

---------------------------------------------------------------- Tagesbelohnung

function RewardService:ClaimDaily(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or data.DailyDay == today() then
		return
	end
	data.DailyStreak = if data.DailyDay == today() - 1 then math.min(data.DailyStreak + 1, 7) else 1
	data.DailyDay = today()
	local gold = Config.DailyGold(data.DailyStreak, data.Level)
	self.Services.DataService:AddGold(player, gold)
	local text = `Daily reward (day {data.DailyStreak}/7): +{Format.Number(gold)} gold!`
	if data.DailyStreak == 7 then
		self.Services.LootService:DropItem(player, nil, { MinRarity = 4, Level = data.Level + 1 }, nil)
		text ..= " Plus an Epic item!"
	end
	task.delay(4, function()
		if player.Parent then
			self.Services.Net.SendNotify(player, text, GOLD)
		end
	end)
end

---------------------------------------------------------------- Freunde

local function refreshFriendBonus()
	local list = Players:GetPlayers()
	for _, player in list do
		local friends = 0
		for _, other in list do
			if other ~= player and friends < Config.MaxFriendBonus then
				local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and isFriend then
					friends += 1
				end
			end
		end
		player:SetAttribute("Friends", friends)
		player:SetAttribute("FriendBonus", friends * Config.FriendBonusPer)
	end
end

---------------------------------------------------------------- Bestenliste

function RewardService:UpdateLeaderboardEntry(player: Player)
	local data = self.Services.DataService:Get(player)
	if data then
		-- Stufe zuerst, Ausruestung als Gleichstand-Brecher
		pending[player.UserId] = data.Level * 100000 + math.min(99999, tonumber(player:GetAttribute("GearScore")) or 0)
	end
end

local function drawBoard(entries)
	local part = RewardService.Services.WorldService.Leaderboard
	if not part then
		return
	end
	local gui = part:FindFirstChild("Board") :: SurfaceGui?
	if not gui then
		local surface = Instance.new("SurfaceGui")
		surface.Name = "Board"
		surface.Face = Enum.NormalId.Front
		surface.CanvasSize = Vector2.new(400, 500)
		surface.LightInfluence = 0
		surface.Parent = part
		gui = surface
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0, 70)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.LuckiestGuy
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 184, 74)
		title.Text = "TOP HEROES"
		title.Parent = surface
		local list = Instance.new("Frame")
		list.Name = "List"
		list.Position = UDim2.fromOffset(20, 80)
		list.Size = UDim2.new(1, -40, 1, -100)
		list.BackgroundTransparency = 1
		list.Parent = surface
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 4)
		layout.Parent = list
	end
	local list = (gui :: any).List
	for _, child in list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	for rank, entry in entries do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = rank
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.BuilderSansBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = if rank == 1 then Color3.fromRGB(255, 210, 90) elseif rank <= 3 then Color3.fromRGB(230, 230, 255) else Color3.fromRGB(190, 190, 215)
		row.Text = `{rank}. {entry.Name}  -  Lv {entry.Level}`
		row.Parent = list
	end
end

local function refreshBoard()
	for userId, score in pending do
		pcall(board.SetAsync, board, tostring(userId), score)
		pending[userId] = nil
	end
	local ok, pages = pcall(board.GetSortedAsync, board, false, 10)
	if not ok then
		return
	end
	local entries = {}
	for _, row in pages:GetCurrentPage() do
		local userId = tonumber(row.key)
		local name = "Hero"
		if userId then
			local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
			if okName then
				name = result
			end
		end
		table.insert(entries, { Name = name, Level = row.value // 100000 })
	end
	drawBoard(entries)
end

---------------------------------------------------------------- Start

function RewardService:OnPlayerReady(player: Player)
	self:ClaimDaily(player)
	self:UpdateLeaderboardEntry(player)
	task.defer(refreshFriendBonus)
end

function RewardService:OnPlayerRemoving(_player: Player)
	task.defer(refreshFriendBonus)
end

function RewardService:Start()
	task.spawn(function()
		task.wait(rng:NextNumber(5, 15))
		while true do
			pcall(refreshBoard)
			task.wait(120)
		end
	end)
end

return RewardService
