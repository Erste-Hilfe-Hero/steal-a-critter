-- Boni fuer alle (Update 2): Schneesturm-Event (regelmaessig doppelte Schneeflocken fuer den ganzen Server),
-- Freundes-Bonus (+10 % pro Freund im Server) und der Flake Booster (Produkt oder Gluecks-Schneeball).
-- Die Multiplikatoren selbst rechnet DataService:AddFlakes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)

local EventService = { Services = nil :: any }

local THEME = Config.Theme
local friendCache = {} -- [UserId] = { [UserId] = boolean }

function EventService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Flake Booster

local function showBoost(player: Player, data)
	local seconds = data.BoostSeconds or 0
	player:SetAttribute("BoostUntil", if seconds > 0 then os.time() + seconds else nil)
end

function EventService:AddBoost(player: Player, seconds: number)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	data.BoostSeconds = math.max(0, data.BoostSeconds or 0) + seconds
	showBoost(player, data)
	self.Services.Net.SendNotify(player, `Flake Booster active: 2x Snowflakes for {Format.Clock(data.BoostSeconds)}!`, THEME.Gold)
end

---------------------------------------------------------------- Freundes-Bonus

local function areFriends(a: Player, b: Player): boolean
	local cache = friendCache[a.UserId]
	if not cache then
		cache = {}
		friendCache[a.UserId] = cache
	end
	if cache[b.UserId] == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		cache[b.UserId] = ok and result == true
	end
	return cache[b.UserId]
end

local function refreshFriends()
	local list = Players:GetPlayers()
	for _, player in list do
		local friends = 0
		for _, other in list do
			if other ~= player and other.Parent and player.Parent and areFriends(player, other) then
				friends += 1
			end
		end
		if player.Parent then
			local bonus = math.min(friends * Progression.FriendBonusEach, Progression.FriendBonusMax)
			player:SetAttribute("FriendBonus", if bonus > 0 then bonus else nil)
			player:SetAttribute("FriendsHere", friends)
		end
	end
end

---------------------------------------------------------------- Schneesturm

local function startStorm()
	local untilTime = os.time() + Progression.StormLength
	workspace:SetAttribute("StormUntil", untilTime)
	workspace:SetAttribute("NextStorm", untilTime + Progression.StormEvery)
	EventService.Services.Net.SendAnnounce(`SNOWSTORM! 2x Snowflakes for everyone for {Progression.StormLength // 60} minutes!`, THEME.Ice)
end

---------------------------------------------------------------- Start

function EventService:Start()
	-- Erster Sturm nach 8 Minuten, danach alle 20 Minuten
	workspace:SetAttribute("NextStorm", os.time() + 8 * 60)
	workspace:SetAttribute("StormUntil", 0)
	task.spawn(function()
		local warned = false
		while true do
			task.wait(1)
			local now = os.time()
			local nextStorm = workspace:GetAttribute("NextStorm") or now
			if not warned and nextStorm - now <= 60 and nextStorm > now then
				warned = true
				self.Services.Net.SendAnnounce("A snowstorm is coming in 1 minute: 2x Snowflakes!", THEME.Ice)
			end
			if now >= nextStorm then
				warned = false
				startStorm()
			end
		end
	end)

	-- Booster zaehlt nur, solange man im Spiel ist
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in Players:GetPlayers() do
				local data = self.Services.DataService:Get(player)
				if data and (data.BoostSeconds or 0) > 0 then
					data.BoostSeconds = math.max(0, data.BoostSeconds - 5)
					if data.BoostSeconds == 0 then
						self.Services.Net.SendNotify(player, "Your Flake Booster ran out.", THEME.Muted)
						showBoost(player, data)
					end
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		friendCache[player.UserId] = nil
		task.defer(refreshFriends)
	end)
end

function EventService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if data then
		showBoost(player, data)
	end
	task.spawn(refreshFriends)
end

function EventService:OnPlayerRemoving(_player: Player) end

return EventService
