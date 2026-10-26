-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	EventService = require(script.Services.EventService),
	GardenService = require(script.Services.GardenService),
	MonetizationService = require(script.Services.MonetizationService),
	CommunityService = require(script.Services.CommunityService),
	ProgressService = require(script.Services.ProgressService),
	CosmeticService = require(script.Services.CosmeticService),
	LeaderboardService = require(script.Services.LeaderboardService),
	RivalService = require(script.Services.RivalService),
}

local ORDER = {
	"DataService",
	"WorldService",
	"EventService",
	"GardenService",
	"MonetizationService",
	"CommunityService",
	"ProgressService",
	"CosmeticService",
	"LeaderboardService",
	"RivalService",
}

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
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = player:GetAttribute("BaseWalkSpeed") or 18
	task.spawn(Services.CommunityService.AttachNameplate, Services.CommunityService, player, character)
	task.spawn(Services.CosmeticService.OnCharacterAdded, Services.CosmeticService, player, character)
	Services.GardenService:OnCharacterAdded(player, character)
end

local function onPlayerAdded(player: Player)
	local banned = Services.CommunityService:IsBanned(player)
	-- Waehrend der Ban-Abfrage verlassen: keinen Garten mehr zuweisen (sonst bliebe er belegt)
	if not player.Parent then
		return
	end
	if banned then
		player:Kick("You are banned from this game or server.")
		return
	end
	local plot = Services.GardenService:Assign(player)
	if not plot then
		player:Kick("This server is full. Please join another server!")
		return
	end
	local data = Services.DataService:Load(player)
	if not data then
		Services.GardenService:Release(player)
		return
	end
	Services.MonetizationService:LoadPasses(player)
	Services.EventService:OnPlayerReady(player)
	Services.GardenService:OnPlayerReady(player)
	Services.CommunityService:OnPlayerReady(player)
	Services.ProgressService:OnPlayerReady(player)
	Services.CosmeticService:OnPlayerReady(player)

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
	Services.EventService:OnPlayerRemoving(player)
	Services.GardenService:OnPlayerRemoving(player)
	Services.MonetizationService:OnPlayerRemoving(player)
	Services.ProgressService:OnPlayerRemoving(player)
	Services.CosmeticService:OnPlayerRemoving(player)
	Services.LeaderboardService:OnPlayerRemoving(player)
	Services.GardenService:Release(player)
	Services.DataService:Release(player)
end)
