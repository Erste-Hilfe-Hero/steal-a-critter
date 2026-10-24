-- Community-Raenge nach aktiver Spielzeit und die Rechte, die damit kommen.
-- Befehle im Chat:
--   /rank                 eigenen Rang und Fortschritt anzeigen        (alle)
--   /yes                  bei einer laufenden Abstimmung zustimmen     (ab Member)
--   /votekick Name        Abstimmung zum Rauswurf aus diesem Server   (ab Regular)
--   /announce Text        gefilterte Ankuendigung an den Server        (ab Veteran)
--   /kick Name            aus diesem Server werfen                     (ab Guardian)
--   /ban Name, /unban ID  dauerhaft sperren / entsperren               (nur Owner)
--   /revoke Name          Rang auf hoechstens Regular begrenzen        (nur Owner)
--   /restore Name         Begrenzung aufheben                          (nur Owner)
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local CommunityService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)

local banStore = DataStoreService:GetDataStore("Bans_v1")
local serverBanned = {} -- [UserId] = true (nur dieser Server)
local lastActive = {} -- [Player] = os.clock()
local lastPosition = {} -- [Player] = Vector3
local lastAnnounce = {} -- [Player] = os.clock()
local lastKick = {} -- [Player] = os.clock()
local activeVote = nil -- { Target, StartedBy, Voters = {}, EndsAt }

local REVOKED_MAX_RANK = 3 -- Regular
local refreshNameplate: (player: Player) -> () -- weiter unten definiert

function CommunityService:Init(services)
	self.Services = services
end

local function notify(player: Player, text: string, color: Color3?)
	CommunityService.Services.Net.SendNotify(player, text, color)
end

local function isOwner(player: Player): boolean
	return table.find(Config.OwnerUserIds, player.UserId) ~= nil
end

local function today(): number
	return os.time() // 86400
end

---------------------------------------------------------------- Raenge

-- Gibt den Rang-Index zurueck (Owner = #Ranks + 1)
function CommunityService:GetRankIndex(player: Player): number
	if isOwner(player) then
		return #Config.Ranks + 1
	end
	local data = self.Services.DataService:Get(player)
	if not data then
		return 1
	end
	local hours = data.PlayTime / 3600
	local index = 1
	for i, rank in Config.Ranks do
		if hours >= rank.Hours and data.ActiveDays >= rank.Days then
			index = i
		end
	end
	if data.RankRevoked then
		index = math.min(index, REVOKED_MAX_RANK)
	end
	return index
end

function CommunityService:HasRight(player: Player, right: string): boolean
	if isOwner(player) then
		return true
	end
	local index = self:GetRankIndex(player)
	for i = 1, index do
		if Config.Ranks[i].Rights[right] then
			return true
		end
	end
	return false
end

local function updateRankAttributes(player: Player)
	local index = CommunityService:GetRankIndex(player)
	local name = if index > #Config.Ranks then "Owner" else Config.Ranks[index].Name
	local color = if index > #Config.Ranks then "#FF5050" else Config.Ranks[index].Color
	local previous = player:GetAttribute("Rank")
	player:SetAttribute("Rank", name)
	if previous ~= name then
		task.defer(refreshNameplate, player)
	end
	player:SetAttribute("RankColor", color)
	player:SetAttribute("RankIndex", index)
	local data = CommunityService.Services.DataService:Get(player)
	local nextRank = Config.Ranks[index + 1]
	if data and nextRank and index <= #Config.Ranks then
		local hoursLeft = math.max(0, nextRank.Hours - data.PlayTime / 3600)
		local daysLeft = math.max(0, nextRank.Days - data.ActiveDays)
		player:SetAttribute("NextRank", `{nextRank.Name}: {string.format("%.1f", hoursLeft)}h, {daysLeft} days`)
	else
		player:SetAttribute("NextRank", nil)
	end
	if previous and previous ~= name and index > 1 then
		CommunityService.Services.Net.SendAnnounce(`{player.DisplayName} is now a {name}!`, GOLD)
	end
end

local function findPlayer(query: string?): Player?
	if not query or query == "" then
		return nil
	end
	query = query:lower()
	for _, player in Players:GetPlayers() do
		if player.Name:lower() == query or player.DisplayName:lower() == query then
			return player
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Name:lower():sub(1, #query) == query or player.DisplayName:lower():sub(1, #query) == query then
			return player
		end
	end
	return nil
end

---------------------------------------------------------------- Abstimmung

local function finishVote()
	local vote = activeVote
	activeVote = nil
	if not vote or not vote.Target.Parent then
		return
	end
	local voters = 0
	for _ in vote.Voters do
		voters += 1
	end
	local eligible = 0
	for _, player in Players:GetPlayers() do
		if player ~= vote.Target and CommunityService:HasRight(player, "Vote") then
			eligible += 1
		end
	end
	local needed = math.max(Config.VoteKickMinVotes, math.ceil(eligible / 2))
	if voters >= needed then
		serverBanned[vote.Target.UserId] = true
		CommunityService.Services.Net.SendAnnounce(`{vote.Target.DisplayName} was voted out of this server ({voters} votes).`, RED)
		vote.Target:Kick("The community voted you out of this server.")
	else
		CommunityService.Services.Net.SendAnnounce(`Vote against {vote.Target.DisplayName} failed ({voters}/{needed}).`, GREEN)
	end
end

---------------------------------------------------------------- Befehle

local commands = {}

commands.rank = function(player: Player)
	local data = CommunityService.Services.DataService:Get(player)
	local hours = if data then data.PlayTime / 3600 else 0
	local nextText = player:GetAttribute("NextRank")
	notify(player, `Rank: {player:GetAttribute("Rank")} | {string.format("%.1f", hours)}h active, {data and data.ActiveDays or 0} days` .. (if nextText then ` | Next {nextText}` else ""), GOLD)
end

commands.yes = function(player: Player)
	if not activeVote then
		notify(player, "There is no vote right now.", RED)
	elseif not CommunityService:HasRight(player, "Vote") then
		notify(player, "You need the Member rank (1h active play) to vote.", RED)
	elseif player == activeVote.Target then
		notify(player, "You can't vote on yourself.", RED)
	else
		activeVote.Voters[player.UserId] = true
		notify(player, "Vote counted.", GREEN)
	end
end

commands.votekick = function(player: Player, args: string)
	if not CommunityService:HasRight(player, "VoteKick") then
		notify(player, "You need the Regular rank (5h active play) to start a vote.", RED)
		return
	end
	if activeVote then
		notify(player, "A vote is already running.", RED)
		return
	end
	local target = findPlayer(args)
	if not target or target == player then
		notify(player, "Player not found.", RED)
		return
	end
	if CommunityService:GetRankIndex(target) >= CommunityService:GetRankIndex(player) then
		notify(player, "You can only vote out players with a lower rank.", RED)
		return
	end
	activeVote = { Target = target, StartedBy = player, Voters = { [player.UserId] = true }, EndsAt = os.clock() + Config.VoteKickDuration }
	CommunityService.Services.Net.SendAnnounce(`{player.DisplayName} started a vote to remove {target.DisplayName}. Type /yes to agree ({Config.VoteKickDuration}s).`, GOLD)
	task.delay(Config.VoteKickDuration, finishVote)
end

commands.announce = function(player: Player, args: string)
	if not CommunityService:HasRight(player, "Announce") then
		notify(player, "You need the Veteran rank (20h active play) to announce.", RED)
		return
	end
	local wait = Config.AnnounceCooldown - (os.clock() - (lastAnnounce[player] or -math.huge))
	if wait > 0 and not isOwner(player) then
		notify(player, `You can announce again in {Format.Time(wait)}.`, RED)
		return
	end
	if args == "" then
		return
	end
	-- Pflicht auf Roblox: jeder von Spielern geschriebene Text muss gefiltert werden
	local ok, filtered = pcall(function()
		local result = TextService:FilterStringAsync(args:sub(1, 120), player.UserId)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok then
		notify(player, "Could not send the announcement, try again.", RED)
		return
	end
	lastAnnounce[player] = os.clock()
	CommunityService.Services.Net.SendAnnounce(`[{player:GetAttribute("Rank")}] {player.DisplayName}: {filtered}`, Color3.fromRGB(255, 255, 255))
end

commands.kick = function(player: Player, args: string)
	if not CommunityService:HasRight(player, "Kick") then
		notify(player, "You need the Guardian rank (50h active play) to kick.", RED)
		return
	end
	local wait = Config.GuardianKickCooldown - (os.clock() - (lastKick[player] or -math.huge))
	if wait > 0 and not isOwner(player) then
		notify(player, `You can kick again in {Format.Time(wait)}.`, RED)
		return
	end
	local target = findPlayer(args)
	if not target or target == player then
		notify(player, "Player not found.", RED)
		return
	end
	if CommunityService:GetRankIndex(target) >= CommunityService:GetRankIndex(player) then
		notify(player, "You can only kick players with a lower rank.", RED)
		return
	end
	lastKick[player] = os.clock()
	serverBanned[target.UserId] = true
	print(`[Community] {player.Name} kicked {target.Name}`)
	CommunityService.Services.Net.SendAnnounce(`{target.DisplayName} was removed by Guardian {player.DisplayName}.`, RED)
	target:Kick(`You were removed from this server by {player.DisplayName}.`)
end

commands.ban = function(player: Player, args: string)
	if not isOwner(player) then
		return
	end
	local target = findPlayer(args)
	if not target then
		notify(player, "Player not found (must be in this server).", RED)
		return
	end
	local ok = pcall(banStore.SetAsync, banStore, tostring(target.UserId), { By = player.UserId, At = os.time() })
	notify(player, if ok then `{target.Name} is banned (UserId {target.UserId}).` else "Ban could not be saved.", if ok then GREEN else RED)
	if ok then
		target:Kick("You are banned from this game.")
	end
end

commands.unban = function(player: Player, args: string)
	if not isOwner(player) then
		return
	end
	local userId = tonumber(args)
	if not userId then
		notify(player, "Use /unban UserId", RED)
		return
	end
	local ok = pcall(banStore.RemoveAsync, banStore, tostring(userId))
	notify(player, if ok then `UserId {userId} unbanned.` else "Unban failed.", if ok then GREEN else RED)
end

local function setRevoked(player: Player, args: string, revoked: boolean)
	if not isOwner(player) then
		return
	end
	local target = findPlayer(args)
	local data = target and CommunityService.Services.DataService:Get(target)
	if not target or not data then
		notify(player, "Player not found.", RED)
		return
	end
	data.RankRevoked = revoked
	updateRankAttributes(target)
	notify(player, `{target.Name} is now {target:GetAttribute("Rank")}.`, GREEN)
end

commands.revoke = function(player: Player, args: string)
	setRevoked(player, args, true)
end

commands.restore = function(player: Player, args: string)
	setRevoked(player, args, false)
end

local function registerCommands()
	local folder = Instance.new("Folder")
	folder.Name = "CommunityCommands"
	for name, handler in commands do
		local command = Instance.new("TextChatCommand")
		command.Name = name
		command.PrimaryAlias = "/" .. name
		command.Triggered:Connect(function(source: TextSource, text: string)
			local player = Players:GetPlayerByUserId(source.UserId)
			if player then
				local args = text:match("^%S+%s+(.-)%s*$") or ""
				handler(player, args)
			end
		end)
		command.Parent = folder
	end
	folder.Parent = TextChatService
end

---------------------------------------------------------------- Namensschild

-- Farbverlaeufe pro Rang (der Client laesst sie schimmern)
local RANK_GRADIENTS = {
	Newbie = { Color3.fromRGB(220, 220, 220), Color3.fromRGB(170, 170, 170) },
	Member = { Color3.fromRGB(120, 220, 255), Color3.fromRGB(60, 140, 255) },
	Regular = { Color3.fromRGB(110, 255, 140), Color3.fromRGB(30, 180, 90) },
	Veteran = { Color3.fromRGB(210, 120, 255), Color3.fromRGB(120, 50, 255) },
	Guardian = { Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 140, 20) },
	Owner = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 200, 255) },
}
local RANK_ICONS = { Newbie = "", Member = "⭐ ", Regular = "⚡ ", Veteran = "💎 ", Guardian = "🛡️ ", Owner = "👑 " }

local function gradient(colors: { Color3 }): UIGradient
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / math.max(1, #colors - 1), color))
	end
	local ui = Instance.new("UIGradient")
	ui.Color = ColorSequence.new(keypoints)
	CollectionService:AddTag(ui, "Shimmer")
	return ui
end

local function makeLine(parent: Instance, height: number, order: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, height, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.LayoutOrder = order
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = label
	label.Parent = parent
	return label
end

refreshNameplate = function(player: Player)
	local gui = player.Character and player.Character:FindFirstChild("Nameplate")
	if not gui then
		return
	end
	local rank = player:GetAttribute("Rank") or "Newbie"
	local vip = player:GetAttribute("Pass_VIP") == true
	local rankLabel = gui:FindFirstChild("RankLine") :: TextLabel
	local nameLabel = gui:FindFirstChild("NameLine") :: TextLabel
	rankLabel.Text = (RANK_ICONS[rank] or "") .. rank:upper() .. (if vip then "  ·  VIP" else "")
	rankLabel.Visible = rank ~= "Newbie" or vip
	nameLabel.Text = player.DisplayName
	for _, child in rankLabel:GetChildren() do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end
	for _, child in nameLabel:GetChildren() do
		if child:IsA("UIGradient") then
			child:Destroy()
		end
	end
	gradient(RANK_GRADIENTS[rank] or RANK_GRADIENTS.Newbie).Parent = rankLabel
	if vip or rank == "Owner" then
		gradient(if rank == "Owner" then RANK_GRADIENTS.Owner else { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 0) }).Parent = nameLabel
	end
end

function CommunityService:AttachNameplate(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head then
		return
	end
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromScale(7, 1.8)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 100
	gui.LightInfluence = 0
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = gui
	makeLine(gui, 0.4, 1).Name = "RankLine"
	makeLine(gui, 0.6, 2).Name = "NameLine"
	-- Am Charakter statt am Kopf, sonst verschwindet es, wenn Roblox den Kopf beim Laden austauscht
	gui.Adornee = head
	gui.Parent = character
	refreshNameplate(player)
end

---------------------------------------------------------------- Lebenszyklus

-- Vor dem Laden pruefen: dauerhaft oder fuer diesen Server gesperrt?
function CommunityService:IsBanned(player: Player): boolean
	if serverBanned[player.UserId] then
		return true
	end
	local ok, entry = pcall(banStore.GetAsync, banStore, tostring(player.UserId))
	return ok and entry ~= nil
end

function CommunityService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if data and data.LastActiveDay ~= today() then
		data.LastActiveDay = today()
		data.ActiveDays += 1
	end
	lastActive[player] = os.clock()
	player.Chatted:Connect(function()
		lastActive[player] = os.clock()
	end)
	updateRankAttributes(player)
	player:GetAttributeChangedSignal("Pass_VIP"):Connect(function()
		refreshNameplate(player)
	end)
	refreshNameplate(player)
end

function CommunityService:OnPlayerRemoving(player: Player)
	lastActive[player] = nil
	lastPosition[player] = nil
	lastAnnounce[player] = nil
	lastKick[player] = nil
	if activeVote and activeVote.Target == player then
		activeVote = nil
	end
end

function CommunityService:Start()
	registerCommands()

	-- Jede Sekunde: Bewegung = aktiv, nur aktive Zeit zaehlt fuer den Rang
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for player, last in lastActive do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local previous = lastPosition[player]
					if previous and (root.Position - previous).Magnitude > 1 then
						last = os.clock()
						lastActive[player] = last
					end
					lastPosition[player] = root.Position
				end
				local data = self.Services.DataService:Get(player)
				if data and os.clock() - last < Config.AfkTimeout then
					data.PlayTime += 1
				end
				if tick % 30 == 0 then
					updateRankAttributes(player)
				end
			end
		end
	end)
end

return CommunityService
