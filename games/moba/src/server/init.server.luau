-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	CombatService = require(script.Services.CombatService),
	WorldService = require(script.Services.WorldService),
	LaneService = require(script.Services.LaneService),
	HeroService = require(script.Services.HeroService),
	BotService = require(script.Services.BotService),
	MatchService = require(script.Services.MatchService),
	MonetizationService = require(script.Services.MonetizationService),
}

local ORDER = { "DataService", "CombatService", "WorldService", "LaneService", "HeroService", "BotService", "MatchService", "MonetizationService" }

Players.CharacterAutoLoads = false

for _, name in ORDER do
	Services[name]:Init(Services)
end
Services.WorldService:Build()
Services.LaneService:Build()
for _, name in ORDER do
	if Services[name].Start then
		Services[name]:Start()
	end
end

local function onPlayerAdded(player: Player)
	local data = Services.DataService:Load(player)
	if not data then
		return
	end
	Services.MonetizationService:OnPlayerReady(player)
	Services.MatchService:OnPlayerReady(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.MatchService:OnPlayerRemoving(player)
	Services.MonetizationService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
