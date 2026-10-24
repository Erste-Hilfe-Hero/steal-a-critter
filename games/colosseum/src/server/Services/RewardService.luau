-- Taegliche Belohnung mit Serie und Codes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RewardService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local RED = Color3.fromRGB(255, 90, 90)

function RewardService:Init(services)
	self.Services = services
end

local function today(): number
	return os.time() // 86400
end

function RewardService:Start()
	local services = self.Services

	services.Net.ClaimDaily.OnServerEvent:Connect(function(player)
		local data = services.DataService:Get(player)
		if not data or not data.Started then
			return
		end
		local day = today()
		if data.LastDaily == day then
			services.Net.SendNotify(player, "You already claimed today's reward. Come back tomorrow!", RED)
			return
		end
		data.Streak = if data.LastDaily == day - 1 then data.Streak + 1 else 1
		data.LastDaily = day
		local reward = Config.DailyRewards[(data.Streak - 1) % #Config.DailyRewards + 1]
		services.BeastService:GrantBundle(player, reward)
		services.DataService:UpdateAttributes(player)
		player:SetAttribute("Streak", data.Streak)
		services.Net.SendNotify(player, `Day {data.Streak} reward: {services.BeastService:BundleText(reward)}!`, GOLD)
	end)

	services.Net.RedeemCode.OnServerEvent:Connect(function(player, code)
		local data = services.DataService:Get(player)
		if not data or typeof(code) ~= "string" then
			return
		end
		code = code:upper():gsub("%s", "")
		local reward = Config.Codes[code]
		if not reward then
			services.Net.SendNotify(player, "That code doesn't exist.", RED)
		elseif data.Codes[code] then
			services.Net.SendNotify(player, "You already used this code.", RED)
		else
			data.Codes[code] = true
			services.BeastService:GrantBundle(player, reward)
			services.Net.SendNotify(player, `Code redeemed: {services.BeastService:BundleText(reward)}!`, GOLD)
		end
	end)
end

function RewardService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if data then
		player:SetAttribute("Streak", data.Streak)
	end
end

return RewardService
