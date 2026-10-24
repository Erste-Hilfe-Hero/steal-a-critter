-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	ArenaService = require(script.Services.ArenaService),
	ProgressService = require(script.Services.ProgressService),
	BallService = require(script.Services.BallService),
	CombatService = require(script.Services.CombatService),
	BotService = require(script.Services.BotService),
	MatchService = require(script.Services.MatchService),
	MonetizationService = require(script.Services.MonetizationService),
}

local ORDER = { "DataService", "ArenaService", "ProgressService", "BallService", "CombatService", "BotService", "MatchService", "MonetizationService" }

for _, name in ORDER do
	Services[name]:Init(Services)
end
Services.ArenaService:Build()
for _, name in ORDER do
	if Services[name].Start then
		Services[name]:Start()
	end
end

Players.RespawnTime = 2

local function onPlayerAdded(player: Player)
	local data = Services.DataService:Load(player)
	if not data then
		return
	end
	Services.MonetizationService:LoadPasses(player)
	Services.ProgressService:OnPlayerReady(player)
	Services.MatchService:OnPlayerReady(player)
	Services.MonetizationService:OnPlayerReady(player)

	player.CharacterAdded:Connect(function(character)
		task.spawn(Services.MatchService.OnCharacterAdded, Services.MatchService, player, character)
		task.spawn(Services.ProgressService.OnCharacterAdded, Services.ProgressService, player, character)
	end)
	if player.Character then
		task.spawn(Services.MatchService.OnCharacterAdded, Services.MatchService, player, player.Character)
		task.spawn(Services.ProgressService.OnCharacterAdded, Services.ProgressService, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.MatchService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
