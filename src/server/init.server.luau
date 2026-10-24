-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	PlotService = require(script.Services.PlotService),
	UnitService = require(script.Services.UnitService),
	MonetizationService = require(script.Services.MonetizationService),
	CommunityService = require(script.Services.CommunityService),
	EventService = require(script.Services.EventService),
}

local ORDER = { "DataService", "WorldService", "PlotService", "UnitService", "MonetizationService", "CommunityService", "EventService" }

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
	humanoid.WalkSpeed = player:GetAttribute("BaseWalkSpeed") or 16
	Services.PlotService:OnCharacterAdded(player, character)
	Services.UnitService:GiveSlapTool(player)
	task.spawn(Services.CommunityService.AttachNameplate, Services.CommunityService, player, character)
end

local function onPlayerAdded(player: Player)
	if Services.CommunityService:IsBanned(player) then
		player:Kick("You are banned from this game or server.")
		return
	end
	local plot = Services.PlotService:Assign(player)
	if not plot then
		player:Kick("This server is full. Please join another server!")
		return
	end
	local data = Services.DataService:Load(player)
	if not data then
		Services.PlotService:Release(player)
		return
	end
	Services.MonetizationService:LoadPasses(player)
	Services.UnitService:OnPlayerReady(player)
	Services.CommunityService:OnPlayerReady(player)
	Services.EventService:OnPlayerReady(player)

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
	Services.UnitService:OnPlayerRemoving(player)
	Services.MonetizationService:OnPlayerRemoving(player)
	Services.PlotService:Release(player)
	Services.DataService:Release(player)
end)
