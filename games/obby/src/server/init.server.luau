-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	StageService = require(script.Services.StageService),
	CosmeticService = require(script.Services.CosmeticService),
	MonetizationService = require(script.Services.MonetizationService),
	CommunityService = require(script.Services.CommunityService),
	RewardService = require(script.Services.RewardService),
	LeaderboardService = require(script.Services.LeaderboardService),
}

local ORDER = { "DataService", "WorldService", "StageService", "CosmeticService", "MonetizationService", "CommunityService", "RewardService", "LeaderboardService" }

for _, name in ORDER do
	Services[name]:Init(Services)
end
Services.WorldService:Build()
for _, name in ORDER do
	if Services[name].Start then
		Services[name]:Start()
	end
end

Players.RespawnTime = 1

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = Config.DefaultWalkSpeed
	task.spawn(Services.StageService.OnCharacterAdded, Services.StageService, player, character)
	task.spawn(Services.CosmeticService.OnCharacterAdded, Services.CosmeticService, player, character)
end

local function onPlayerAdded(player: Player)
	if Services.CommunityService:IsBanned(player) then
		player:Kick("You are banned from this game or server.")
		return
	end
	local data = Services.DataService:Load(player)
	if not data then
		return
	end
	Services.MonetizationService:LoadPasses(player)
	Services.CommunityService:OnPlayerReady(player)
	Services.RewardService:OnPlayerReady(player)

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
	Services.StageService:OnPlayerRemoving(player)
	Services.CosmeticService:OnPlayerRemoving(player)
	Services.RewardService:OnPlayerRemoving(player)
	Services.LeaderboardService:OnPlayerRemoving(player) -- liest die Daten sofort, also vor Release
	Services.DataService:Release(player)
end)
