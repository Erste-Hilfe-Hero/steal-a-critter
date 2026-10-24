-- Gruende, jeden Tag wiederzukommen: Tagesbelohnung mit Serie, Spielzeit-Geschenke, Codes,
-- taegliche Missionen, Rangliste und der Geldregen.
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local RewardService = { Services = nil :: any }

local C = Config.Colors
local topStore = DataStoreService:GetOrderedDataStore("TurboTopCash_v1")
local sessionStart = {} -- [Player] = os.clock()

local function today(): number
	return os.time() // 86400
end

local function notify(player: Player, text: string, color: Color3?)
	RewardService.Services.Net.SendNotify(player, text, color)
end

local function tier(player: Player): number
	return RewardService.Services.HouseService:GetTier(player)
end

function RewardService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Missionen

local function rollMissions(data)
	local pool = table.clone(Config.Missions)
	local list = {}
	local rng = Random.new(today() * 7 + #pool)
	for _ = 1, 3 do
		local mission = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { Id = mission.Id, Progress = 0, Claimed = false })
	end
	data.Missions = { Day = today(), List = list }
end

function RewardService:SyncMissions(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if data.Missions.Day ~= today() then
		rollMissions(data)
	end
	player:SetAttribute("Missions", HttpService:JSONEncode(data.Missions.List))
end

function RewardService:Progress(player: Player, id: string, amount: number)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if data.Missions.Day ~= today() then
		rollMissions(data)
	end
	local changed = false
	for _, entry in data.Missions.List do
		local mission = Config.MissionsById[entry.Id]
		if entry.Id == id and mission and entry.Progress < mission.Goal then
			entry.Progress = math.min(mission.Goal, entry.Progress + amount)
			changed = true
			if entry.Progress >= mission.Goal then
				notify(player, `Mission complete: {string.format(mission.Text, mission.Goal)}! Claim it in Missions.`, C.Lemon)
			end
		end
	end
	if changed then
		player:SetAttribute("Missions", HttpService:JSONEncode(data.Missions.List))
	end
end

function RewardService:ClaimMission(player: Player, index: number): (boolean, string?)
	local data = self.Services.DataService:Get(player)
	local entry = data and data.Missions.List[index]
	local mission = entry and Config.MissionsById[entry.Id]
	if not entry or not mission then
		return false, "Unknown mission"
	end
	if entry.Claimed then
		return false, "Already claimed"
	end
	if entry.Progress < mission.Goal then
		return false, "Not finished yet"
	end
	entry.Claimed = true
	local amount = self.Services.DataService:Earn(player, mission.Reward * tier(player))
	self:SyncMissions(player)
	return true, `Mission reward +{Format.Cash(amount)}!`
end

-- Robux-Produkt: naechste offene Mission sofort fertig
function RewardService:SkipMission(player: Player): boolean
	local data = self.Services.DataService:Get(player)
	if not data then
		return false
	end
	for _, entry in data.Missions.List do
		local mission = Config.MissionsById[entry.Id]
		if mission and entry.Progress < mission.Goal then
			entry.Progress = mission.Goal
			self:SyncMissions(player)
			notify(player, "Mission completed! Claim your reward.", C.Lemon)
			return true
		end
	end
	return false
end

---------------------------------------------------------------- Tagesbelohnung und Geschenke

function RewardService:UpdateDaily(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local ready = data.DailyDay ~= today()
	local streak = if data.DailyDay == today() - 1 then math.min(data.DailyStreak + 1, 7) elseif ready then 1 else data.DailyStreak
	player:SetAttribute("DailyReady", ready)
	player:SetAttribute("DailyStreak", streak)
	player:SetAttribute("DailyReward", Config.DailyReward(streak, tier(player)))
end

function RewardService:ClaimDaily(player: Player): (boolean, string?)
	local data = self.Services.DataService:Get(player)
	if not data or data.DailyDay == today() then
		return false, "Come back tomorrow!"
	end
	local streak = if data.DailyDay == today() - 1 then math.min(data.DailyStreak + 1, 7) else 1
	data.DailyDay = today()
	data.DailyStreak = streak
	local amount = Config.DailyReward(streak, tier(player))
	self.Services.DataService:AddCash(player, amount)
	self:UpdateDaily(player)
	return true, `Day {streak} reward: +{Format.Cash(amount)}! Come back tomorrow for more.`
end

local function setGift(player: Player, index: number)
	local minutes = Config.Gifts[index]
	player:SetAttribute("GiftIndex", if minutes then index else nil)
	if minutes then
		player:SetAttribute("GiftAt", workspace:GetServerTimeNow() + minutes * 60 - (os.clock() - (sessionStart[player] or os.clock())))
		player:SetAttribute("GiftReward", Config.GiftReward(index, tier(player)))
	else
		player:SetAttribute("GiftAt", nil)
	end
end

function RewardService:ClaimGift(player: Player): (boolean, string?)
	local index = player:GetAttribute("GiftIndex")
	local at = player:GetAttribute("GiftAt")
	if not index or not at then
		return false, "No more gifts this session!"
	end
	if workspace:GetServerTimeNow() < at - 1 then
		return false, "Not ready yet"
	end
	local amount = Config.GiftReward(index, tier(player))
	self.Services.DataService:AddCash(player, amount)
	setGift(player, index + 1)
	return true, `Gift +{Format.Cash(amount)}!`
end

function RewardService:RedeemCode(player: Player, code: string): (boolean, string?)
	local data = self.Services.DataService:Get(player)
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.Codes[code]
	if not data or not reward then
		return false, "Invalid code"
	end
	if data.Codes[code] then
		return false, "Code already used"
	end
	data.Codes[code] = true
	self.Services.DataService:AddCash(player, reward)
	return true, `Code redeemed: +{Format.Cash(reward)}!`
end

---------------------------------------------------------------- Geldregen

function RewardService:MoneyRain(buyer: Player)
	self.Services.Net.SendAnnounce(`{buyer.DisplayName} made it RAIN MONEY! Grab the cash!`, C.Green)
	local folder = workspace:FindFirstChild("MoneyRain") or Instance.new("Folder")
	folder.Name = "MoneyRain"
	folder.Parent = workspace
	task.spawn(function()
		for _ = 1, 20 do
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local bill = Instance.new("Part")
					bill.Name = "Cash"
					bill.Size = Vector3.new(2.4, 0.3, 1.2)
					bill.Color = C.Green
					bill.Material = Enum.Material.Neon
					bill.CFrame = CFrame.new(root.Position + Vector3.new(math.random(-35, 35), 60, math.random(-35, 35))) * CFrame.Angles(math.random(), math.random(), math.random())
					bill.CanCollide = true
					local taken = false
					bill.Touched:Connect(function(hit)
						local who = Players:GetPlayerFromCharacter(hit.Parent) or Players:GetPlayerFromCharacter(hit.Parent and hit.Parent.Parent)
						if who and not taken then
							taken = true
							bill:Destroy()
							local amount = self.Services.DataService:Earn(who, 300 * tier(who))
							notify(who, `+{Format.Cash(amount)}`, C.Green)
						end
					end)
					bill.Parent = folder
					Debris:AddItem(bill, 25)
				end
			end
			task.wait(1)
		end
	end)
end

---------------------------------------------------------------- Rangliste

local function refreshLeaderboard()
	for _, player in Players:GetPlayers() do
		local data = RewardService.Services.DataService:Get(player)
		if data and data.TotalEarned > 0 then
			pcall(topStore.SetAsync, topStore, tostring(player.UserId), math.floor(math.min(data.TotalEarned, 2 ^ 52)))
		end
	end
	local board = workspace:FindFirstChild("Leaderboard", true) :: BasePart?
	if not board then
		return
	end
	local ok, pages = pcall(topStore.GetSortedAsync, topStore, false, 10)
	if not ok then
		return
	end
	local entries = pages:GetCurrentPage()
	local gui = board:FindFirstChild("BoardGui") :: SurfaceGui?
	if not gui then
		local newGui = Instance.new("SurfaceGui")
		newGui.Name = "BoardGui"
		newGui.Face = Enum.NormalId.Front
		newGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		newGui.PixelsPerStud = 20
		newGui.LightInfluence = 0
		newGui.Parent = board
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = newGui
		gui = newGui
	end
	assert(gui)
	for _, child in gui:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local function row(text: string, color: Color3, order: number, height: number)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.94, 0, 0, height)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = text
		label.LayoutOrder = order
		label.Parent = gui
	end
	row(board:GetAttribute("Title") or "TOP", C.Lemon, 0, 60)
	for rank, entry in entries do
		local name = "Player"
		local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, tonumber(entry.key) or 0)
		if okName then
			name = result
		end
		row(`{rank}. {name}  {Format.Cash(entry.value)}`, if rank == 1 then C.Orange elseif rank <= 3 then C.Teal else Color3.new(1, 1, 1), rank, 42)
	end
end

---------------------------------------------------------------- Ablauf

function RewardService:OnPlayerReady(player: Player)
	sessionStart[player] = os.clock()
	self:SyncMissions(player)
	self:UpdateDaily(player)
	setGift(player, 1)
end

function RewardService:OnPlayerRemoving(player: Player)
	sessionStart[player] = nil
end

function RewardService:Start()
	local net = self.Services.Net
	net.Handle("ClaimDaily", function(player)
		return self:ClaimDaily(player)
	end)
	net.Handle("ClaimGift", function(player)
		return self:ClaimGift(player)
	end)
	net.Handle("ClaimMission", function(player, index)
		if typeof(index) ~= "number" then
			return false, "Invalid"
		end
		return self:ClaimMission(player, index)
	end)
	net.Handle("RedeemCode", function(player, code)
		if typeof(code) ~= "string" or #code > 30 then
			return false, "Invalid code"
		end
		return self:RedeemCode(player, code)
	end)

	task.spawn(function()
		task.wait(10)
		while true do
			pcall(refreshLeaderboard)
			task.wait(120)
		end
	end)
end

return RewardService
