-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	BreakableService = require(script.Services.BreakableService),
	PetService = require(script.Services.PetService),
	MonetizationService = require(script.Services.MonetizationService),
	CommunityService = require(script.Services.CommunityService),
}

local ORDER = { "DataService", "WorldService", "BreakableService", "PetService", "MonetizationService", "CommunityService" }

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
	task.spawn(Services.CommunityService.AttachNameplate, Services.CommunityService, player, character)
	-- Zurueck in die beste freigeschaltete Zone (spart Laufen nach dem Respawn)
	local data = Services.DataService:Get(player)
	if data and data.Zone > 1 then
		task.defer(function()
			character:PivotTo(Services.WorldService.SpawnCFrame(data.Zone))
		end)
	end
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
	Services.PetService:OnPlayerReady(player)
	Services.CommunityService:OnPlayerReady(player)

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
	Services.BreakableService:OnPlayerRemoving(player)
	Services.PetService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
