-- Automatische Server-Events (alle paar Minuten, fuer alle gratis) und die taegliche Belohnung mit Serie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local EventService = { Services = nil :: any }

local activeId: string? = nil
local activeUntil = 0
local partyUntil = 0 -- gekaufte Cash Party (Double Cash fuer alle)
local goalProgress = 0 -- Server-Ziel: gemeinsam gekaufte/geklaute Kreaturen
local coinFolder: Folder? = nil
local vote = nil :: any -- { Options = { Event }, Votes = { [Player] = Index } } waehrend der Abstimmung

local function happyHour(): boolean
	return os.date("!*t").hour == Config.HappyHourUtc
end

function EventService:Init(services)
	self.Services = services
end

function EventService:IsActive(id: string): boolean
	if id == "DoubleCash" and (os.clock() < partyUntil or happyHour()) then
		return true
	end
	return activeId == id and os.clock() < activeUntil
end

local function refreshIncomes()
	for _, player in Players:GetPlayers() do
		EventService.Services.UnitService:UpdateIncome(player)
	end
end

-- Cash Party: ein Spieler schenkt dem ganzen Server Double Cash (wird mit Namen angekuendigt)
function EventService:StartParty(seconds: number, buyerName: string, message: string?)
	local now = os.clock()
	partyUntil = math.max(now, partyUntil) + seconds
	workspace:SetAttribute("PartyEnds", workspace:GetServerTimeNow() + (partyUntil - now))
	workspace:SetAttribute("PartyBy", buyerName)
	self.Services.Net.SendAnnounce(message or `{buyerName} started a CASH PARTY: DOUBLE CASH for everyone!`, Color3.fromRGB(120, 255, 120))
	refreshIncomes()
	local myEnd = partyUntil
	task.delay(partyUntil - now + 0.1, function()
		if partyUntil == myEnd then
			workspace:SetAttribute("PartyEnds", nil)
			workspace:SetAttribute("PartyBy", nil)
			refreshIncomes()
		end
	end)
end

---------------------------------------------------------------- Server-Ziel

-- Jeder Kauf und Klau zaehlt; ist das Ziel erreicht, gibt es Double Cash fuer alle
function EventService:AddGoalProgress(amount: number)
	goalProgress += amount
	if goalProgress >= Config.ServerGoal then
		goalProgress = 0
		self:StartParty(Config.ServerGoalReward, "Server Goal", `🎯 SERVER GOAL REACHED! {Config.ServerGoalReward // 60} min DOUBLE CASH for everyone!`)
	end
	workspace:SetAttribute("GoalProgress", goalProgress)
end

---------------------------------------------------------------- Cash Rain

local function spawnCoin()
	local conveyor = Config.Conveyor
	local coin = Instance.new("Part")
	coin.Name = "RainCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 2.4, 2.4)
	coin.Color = Color3.fromRGB(255, 205, 40)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	local x = math.random() * (conveyor.EndX - conveyor.StartX) + conveyor.StartX
	local z = (math.random() * 2 - 1) * 24
	coin.CFrame = CFrame.new(x, 3, z) * CFrame.Angles(0, 0, math.rad(90))
	game:GetService("CollectionService"):AddTag(coin, "Spin")
	local taken = false
	coin.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if taken or not player or not EventService.Services.DataService:Get(player) then
			return
		end
		taken = true
		coin:Destroy()
		local amount = EventService.Services.ProgressService.IncomeReward(player, Config.CashRainCoinSeconds / 60, Config.CashRainMinCash)
		EventService.Services.DataService:AddCash(player, amount)
		EventService.Services.ProgressService:Track(player, "Coins", 1)
		EventService.Services.Net.SendNotify(player, `+{Format.Cash(amount)}`, Color3.fromRGB(110, 255, 130))
	end)
	coin.Parent = coinFolder
	task.delay(20, function()
		if coin.Parent then
			coin:Destroy()
		end
	end)
end

local function cashRain()
	local waves = 8
	for _ = 1, waves do
		if activeId ~= "CashRain" then
			return
		end
		for _ = 1, math.ceil(Config.CashRainCoins / waves) do
			spawnCoin()
		end
		task.wait(Config.EventDuration / waves)
	end
end

local function startEvent(event)
	activeId = event.Id
	activeUntil = os.clock() + Config.EventDuration
	workspace:SetAttribute("EventName", event.Name)
	workspace:SetAttribute("EventDescription", event.Description)
	workspace:SetAttribute("EventEnds", workspace:GetServerTimeNow() + Config.EventDuration)
	workspace:SetAttribute("NextEventAt", nil)
	EventService.Services.Net.SendAnnounce(`EVENT: {event.Name}! {event.Description}`, event.Color)
	for _, player in Players:GetPlayers() do
		EventService.Services.UnitService:UpdateIncome(player)
	end
	if event.Id == "CashRain" then
		task.spawn(cashRain)
	elseif event.Id == "MythicDrop" then
		task.delay(3, function()
			EventService.Services.UnitService:SpawnBeltUnit(if math.random() < 0.1 then "Secret" else "Mythic")
		end)
	end
end

local function stopEvent()
	activeId = nil
	workspace:SetAttribute("EventName", nil)
	workspace:SetAttribute("EventDescription", nil)
	workspace:SetAttribute("EventEnds", nil)
	workspace:SetAttribute("NextEventAt", workspace:GetServerTimeNow() + Config.EventInterval - Config.EventDuration)
	for _, player in Players:GetPlayers() do
		EventService.Services.UnitService:UpdateIncome(player)
	end
end

---------------------------------------------------------------- Abstimmung ueber das naechste Event (Update 4)

local function publishVote()
	if not vote then
		return
	end
	local counts = table.create(#vote.Options, 0)
	for player, index in vote.Votes do
		if player.Parent then
			counts[index] += 1
		end
	end
	local names = {}
	for _, event in vote.Options do
		table.insert(names, event.Name)
	end
	workspace:SetAttribute("VoteOptions", table.concat(names, "|"))
	workspace:SetAttribute("VoteCounts", table.concat(counts, "|"))
	return counts
end

local function startVote()
	local pool = table.clone(Config.Events)
	local options = {}
	for _ = 1, math.min(Config.EventVoteOptions, #pool) do
		table.insert(options, table.remove(pool, math.random(1, #pool)))
	end
	vote = { Options = options, Votes = {} }
	publishVote()
	workspace:SetAttribute("VoteEnds", workspace:GetServerTimeNow() + Config.EventVoteTime)
	EventService.Services.Net.SendAnnounce("🗳️ VOTE for the next event! Tap your favorite (top right).", Color3.fromRGB(150, 200, 255))
end

-- Meiste Stimmen gewinnt; Gleichstand oder keine Stimmen: Zufall unter den Besten
local function finishVote()
	local current = vote
	local counts = publishVote()
	vote = nil
	workspace:SetAttribute("VoteOptions", nil)
	workspace:SetAttribute("VoteCounts", nil)
	workspace:SetAttribute("VoteEnds", nil)
	if not current or not counts then
		return Config.Events[math.random(1, #Config.Events)]
	end
	local best, bestCount = {}, -1
	for index, count in counts do
		if count > bestCount then
			best, bestCount = { index }, count
		elseif count == bestCount then
			table.insert(best, index)
		end
	end
	return current.Options[best[math.random(1, #best)]]
end

local function castVote(player: Player, index: any)
	if not vote then
		return false, "There is no vote right now"
	end
	if type(index) ~= "number" or not vote.Options[index] then
		return false, "Unknown option"
	end
	vote.Votes[player] = index
	publishVote()
	return true, `You voted for {vote.Options[index].Name}!`
end

-- Taegliche Belohnung: jeden Kalendertag (UTC) einmal, Serie steigert den Betrag
function EventService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local today = os.time() // 86400
	local last = data.LastRewardDay or 0
	if last == today then
		return
	end
	data.RewardStreak = if last == today - 1 then math.min((data.RewardStreak or 0) + 1, Config.DailyRewardMaxStreak) else 1
	data.LastRewardDay = today
	local income = player:GetAttribute("IncomePerSec") or 0
	local amount = math.floor(math.max(Config.DailyRewardBase, income * 120) * (1 + Config.DailyRewardStreakBonus * (data.RewardStreak - 1)))
	self.Services.DataService:AddCash(player, amount)
	task.delay(3, function()
		if player.Parent then
			self.Services.Net.SendNotify(player, `Daily reward: +{Format.Cash(amount)} (streak day {data.RewardStreak})! Come back tomorrow for more.`, Color3.fromRGB(255, 200, 40))
		end
	end)
end

function EventService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "RainCoins"
	folder.Parent = workspace
	coinFolder = folder
	workspace:SetAttribute("GoalProgress", 0)
	workspace:SetAttribute("GoalTarget", Config.ServerGoal)
	workspace:SetAttribute("NextEventAt", workspace:GetServerTimeNow() + Config.EventInterval - Config.EventDuration)

	-- Happy Hour: Anfang und Ende ankuendigen, Einkommen neu berechnen
	task.spawn(function()
		local wasActive = false
		while true do
			local active = happyHour()
			if active ~= wasActive then
				wasActive = active
				if active then
					local now = os.time()
					workspace:SetAttribute("HappyHourEnds", workspace:GetServerTimeNow() + (3600 - now % 3600))
					self.Services.Net.SendAnnounce("⏰ HAPPY HOUR! DOUBLE CASH for everyone for 1 hour!", Color3.fromRGB(120, 255, 120))
				else
					workspace:SetAttribute("HappyHourEnds", nil)
				end
				refreshIncomes()
			end
			local nextStart = (os.time() // 86400) * 86400 + Config.HappyHourUtc * 3600
			if nextStart <= os.time() then
				nextStart += 86400
			end
			workspace:SetAttribute("HappyHourIn", workspace:GetServerTimeNow() + (nextStart - os.time()))
			task.wait(10)
		end
	end)

	self.Services.Net.Handle("VoteEvent", castVote)
	task.spawn(function()
		while true do
			-- Kurz vor dem Event stimmen alle ab, welches kommt
			task.wait(Config.EventInterval - Config.EventDuration - Config.EventVoteTime)
			startVote()
			task.wait(Config.EventVoteTime)
			startEvent(finishVote())
			task.wait(Config.EventDuration)
			stopEvent()
		end
	end)
end

return EventService
