-- Zusammen spielen lohnt sich: Einkommens-Bonus fuer Freunde im selben Server
-- und Belohnungen fuer Einladungen (Einladender + neuer Spieler).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local SocialService = { Services = nil :: any }

-- Offene Belohnungen fuer Einladende, die gerade nicht im selben Server sind
local pendingStore = DataStoreService:GetDataStore("Referrals_v1")
local friendPairs = {} -- ["kleinereId:groessereId"] = boolean
local GREEN = Color3.fromRGB(90, 255, 140)

local function pairKey(a: number, b: number): string
	return if a < b then `{a}:{b}` else `{b}:{a}`
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a.UserId, b.UserId)
	if friendPairs[key] == nil then
		local ok, result = pcall(a.IsFriendsWithAsync, a, b.UserId)
		friendPairs[key] = ok and result == true
	end
	return friendPairs[key]
end

local function refreshFriendBoost(player: Player, leaving: Player?)
	if not player.Parent then
		return
	end
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player and other ~= leaving and areFriends(player, other) then
			count += 1
		end
	end
	local boost = math.min(count * Config.FriendBoostPer, Config.FriendBoostMax)
	player:SetAttribute("FriendsHere", count)
	player:SetAttribute("FriendBoost", boost)
	SocialService.Services.UnitService:UpdateIncome(player)
end

local function grantReferrals(player: Player, count: number)
	local data = SocialService.Services.DataService:Get(player)
	if not data or count <= 0 then
		return
	end
	data.Referrals = (data.Referrals or 0) + count
	local income = player:GetAttribute("IncomePerSec") or 0
	local cash = math.floor(math.max(Config.ReferralInviterCash, income * 300)) * count
	SocialService.Services.DataService:AddCash(player, cash)
	player:SetAttribute("Referrals", data.Referrals)
	SocialService.Services.UnitService:UpdateIncome(player)
	SocialService.Services.Net.SendNotify(player, `A friend you invited joined! +{Format.Cash(cash)} and +{math.floor(Config.ReferralBoostPer * 100)}% income forever!`, GREEN)
end

-- Belohnungen abholen, die in anderen Servern fuer diesen Spieler gesammelt wurden
local function claimPending(player: Player)
	local claimed = 0
	local ok = pcall(pendingStore.UpdateAsync, pendingStore, tostring(player.UserId), function(old)
		claimed = tonumber(old) or 0
		if claimed == 0 then
			return nil
		end
		return 0
	end)
	if ok and claimed > 0 and player.Parent then
		grantReferrals(player, claimed)
	end
end

local function creditInviter(inviterId: number)
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter and SocialService.Services.DataService:Get(inviter) then
		grantReferrals(inviter, 1)
		return
	end
	pcall(pendingStore.IncrementAsync, pendingStore, tostring(inviterId), 1)
end

local function readInviter(player: Player): number?
	local ok, joinData = pcall(player.GetJoinData, player)
	if not ok or type(joinData) ~= "table" then
		return nil
	end
	local id = tonumber(joinData.LaunchData) or tonumber(joinData.ReferredByPlayerId)
	if id and id > 0 and id ~= player.UserId then
		return id
	end
	return nil
end

function SocialService:Init(services)
	self.Services = services
end

function SocialService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	player:SetAttribute("Referrals", data.Referrals or 0)

	-- Neuer Spieler ueber Einladung oder Teilen-Link: beide bekommen etwas
	local inviterId = readInviter(player)
	if inviterId and (data.ReferredBy or 0) == 0 and (data.PlayTime or 0) < Config.ReferralMaxPlayTime then
		data.ReferredBy = inviterId
		self.Services.DataService:AddCash(player, Config.ReferralNewcomerCash)
		task.spawn(creditInviter, inviterId)
		task.delay(4, function()
			if player.Parent then
				self.Services.Net.SendNotify(player, `Welcome! You were invited by a friend: +{Format.Cash(Config.ReferralNewcomerCash)} starter bonus!`, GREEN)
			end
		end)
	end

	task.spawn(claimPending, player)
	task.spawn(function()
		for _, other in Players:GetPlayers() do
			refreshFriendBoost(other)
		end
	end)

	-- Hinweis, warum sich Einladen lohnt
	task.delay(90, function()
		if player.Parent and (player:GetAttribute("FriendsHere") or 0) == 0 then
			self.Services.Net.SendNotify(player, `Play with friends: +{math.floor(Config.FriendBoostPer * 100)}% cash per friend here! Tap INVITE - you both get a bonus.`, GREEN)
		end
	end)
end

function SocialService:OnPlayerRemoving(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			task.spawn(refreshFriendBoost, other, player)
		end
	end
end

function SocialService:Start()
	-- Einladende, die in einem anderen Server spielen, bekommen ihre Belohnung regelmaessig
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				if self.Services.DataService:Get(player) then
					task.spawn(claimPending, player)
				end
			end
		end
	end)
end

return SocialService
