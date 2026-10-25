-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	ProgressService = require(script.Services.ProgressService),
	InventoryService = require(script.Services.InventoryService),
	MapService = require(script.Services.MapService),
	CoinService = require(script.Services.CoinService),
	ClueService = require(script.Services.ClueService),
	CombatService = require(script.Services.CombatService),
	AbilityService = require(script.Services.AbilityService),
	BotService = require(script.Services.BotService),
	RoundService = require(script.Services.RoundService),
	MonetizationService = require(script.Services.MonetizationService),
}

local ORDER = { "DataService", "ProgressService", "InventoryService", "MapService", "CoinService", "ClueService", "CombatService", "AbilityService", "BotService", "RoundService", "MonetizationService" }

for _, name in ORDER do
	Services[name]:Init(Services)
end
Services.MapService:Build()
for _, name in ORDER do
	if Services[name].Start then
		Services[name]:Start()
	end
end

Players.RespawnTime = 3

local function onPlayerAdded(player: Player)
	task.spawn(Services.InventoryService.CheckPolicy, Services.InventoryService, player)
	local data = Services.DataService:Load(player)
	if not data then
		return
	end
	Services.MonetizationService:LoadPasses(player)
	Services.ProgressService:OnPlayerReady(player)
	Services.MonetizationService:OnPlayerReady(player)

	player.CharacterAdded:Connect(function(character)
		task.spawn(Services.ProgressService.OnCharacterAdded, Services.ProgressService, player, character)
	end)
	if player.Character then
		task.spawn(Services.ProgressService.OnCharacterAdded, Services.ProgressService, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.RoundService:OnPlayerLeft(player)
	Services.DataService:Release(player)
end)
