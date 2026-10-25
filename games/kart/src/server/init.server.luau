-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	TrackService = require(script.Services.TrackService),
	LobbyService = require(script.Services.LobbyService),
	RaceService = require(script.Services.RaceService),
	MonetizationService = require(script.Services.MonetizationService),
	ShopService = require(script.Services.ShopService),
	ProgressService = require(script.Services.ProgressService),
}

local ORDER = { "DataService", "TrackService", "LobbyService", "RaceService", "MonetizationService", "ShopService", "ProgressService" }

for _, name in ORDER do
	Services[name]:Init(Services)
end
Services.LobbyService:Build()
Services.TrackService:Load("Speedway") -- Startstrecke unter der Lobby, bis die erste Abstimmung entschieden ist
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
	Services.MonetizationService:LoadPasses(player)
	Services.ShopService:OnPlayerReady(player)
	Services.ProgressService:OnPlayerReady(player)
	player:SetAttribute("Loaded", true)
	local function onCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		if humanoid then
			humanoid.WalkSpeed = 22
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	-- Die erste Figur kann schon waehrend des Ladens erschienen sein
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.ShopService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
