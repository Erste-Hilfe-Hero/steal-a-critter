-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	LeaderboardService = require(script.Services.LeaderboardService),
	TimerService = require(script.Services.TimerService),
	CosmeticService = require(script.Services.CosmeticService),
	MonetizationService = require(script.Services.MonetizationService),
}

local ORDER = { "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "MonetizationService" }

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
	Services.TimerService:OnCharacterAdded(player)
	Services.CosmeticService:OnCharacterAdded(player, character)
end

local function onPlayerAdded(player: Player)
	local data = Services.DataService:Load(player)
	if not data then
		return
	end
	Services.TimerService:OnPlayerReady(player)
	Services.MonetizationService:LoadPasses(player)
	Services.MonetizationService:OnPlayerReady(player)
	Services.CosmeticService:OnPlayerReady(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.TimerService:OnPlayerRemoving(player)
	Services.MonetizationService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
