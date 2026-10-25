-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	VehicleService = require(script.Services.VehicleService),
	HouseService = require(script.Services.HouseService),
	JobService = require(script.Services.JobService),
	MonetizationService = require(script.Services.MonetizationService),
	RewardService = require(script.Services.RewardService),
	CommunityService = require(script.Services.CommunityService),
	ProgressService = require(script.Services.ProgressService),
	EventService = require(script.Services.EventService),
}

local ORDER = { "DataService", "WorldService", "VehicleService", "HouseService", "JobService", "MonetizationService", "RewardService", "CommunityService", "ProgressService", "EventService" }

for _, name in ORDER do
	Services[name]:Init(Services)
end
Services.WorldService:Build()
for _, name in ORDER do
	if Services[name].Start then
		Services[name]:Start()
	end
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("Humanoid")
	task.spawn(Services.CommunityService.AttachNameplate, Services.CommunityService, player, character)
	Services.HouseService:OnCharacterAdded(player, character)
	Services.JobService:OnCharacterAdded(player, character)
end

local function onPlayerAdded(player: Player)
	if Services.CommunityService:IsBanned(player) then
		player:Kick("You are banned from this game or server.")
		return
	end
	if not Services.HouseService:Assign(player) then
		player:Kick("This server is full. Please join another server!")
		return
	end
	local data = Services.DataService:Load(player)
	if not data then
		Services.HouseService:Release(player)
		return
	end
	Services.MonetizationService:LoadPasses(player)
	Services.HouseService:OnPlayerReady(player)
	Services.JobService:OnPlayerReady(player)
	Services.MonetizationService:OnPlayerReady(player)
	Services.RewardService:OnPlayerReady(player)
	Services.CommunityService:OnPlayerReady(player)
	Services.ProgressService:OnPlayerReady(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.CommunityService:OnPlayerRemoving(player)
	Services.JobService:OnPlayerRemoving(player)
	Services.VehicleService:OnPlayerRemoving(player)
	Services.MonetizationService:OnPlayerRemoving(player)
	Services.RewardService:OnPlayerRemoving(player)
	Services.ProgressService:OnPlayerRemoving(player)
	Services.EventService:OnPlayerRemoving(player)
	Services.HouseService:Release(player)
	Services.DataService:Release(player)
end)
