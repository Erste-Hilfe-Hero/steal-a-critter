-- Automatische Server-Events (alle paar Minuten, fuer alle gratis) und die taegliche Belohnung mit Serie.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local EventService = { Services = nil :: any }

local activeId: string? = nil
local activeUntil = 0

function EventService:Init(services)
	self.Services = services
end

function EventService:IsActive(id: string): boolean
	return activeId == id and os.clock() < activeUntil
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
	workspace:SetAttribute("NextEventAt", workspace:GetServerTimeNow() + Config.EventInterval - Config.EventDuration)
	task.spawn(function()
		while true do
			task.wait(Config.EventInterval - Config.EventDuration)
			startEvent(Config.Events[math.random(1, #Config.Events)])
			task.wait(Config.EventDuration)
			stopEvent()
		end
	end)
end

return EventService
