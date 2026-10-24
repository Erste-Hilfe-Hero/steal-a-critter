-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	MonsterService = require(script.Services.MonsterService),
	DungeonService = require(script.Services.DungeonService),
	HeroService = require(script.Services.HeroService),
	CombatService = require(script.Services.CombatService),
	LootService = require(script.Services.LootService),
	MonetizationService = require(script.Services.MonetizationService),
	RewardService = require(script.Services.RewardService),
	CommunityService = require(script.Services.CommunityService),
}

local ORDER = {
	"DataService",
	"WorldService",
	"MonsterService",
	"DungeonService",
	"HeroService",
	"CombatService",
	"LootService",
	"MonetizationService",
	"RewardService",
	"CommunityService",
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
	task.spawn(Services.CommunityService.AttachNameplate, Services.CommunityService, player, character)
	task.spawn(Services.DungeonService.OnCharacterAdded, Services.DungeonService, player, character)
	Services.HeroService:OnCharacterAdded(player, character)
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
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	Services.CombatService:OnPlayerReady(player)
	Services.LootService:OnPlayerReady(player)
	Services.MonetizationService:LoadPasses(player)
	Services.HeroService:RefreshStats(player)
	Services.RewardService:OnPlayerReady(player)
	Services.MonetizationService:OnPlayerReady(player)
	Services.CommunityService:OnPlayerReady(player)
	player:LoadCharacter()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.CommunityService:OnPlayerRemoving(player)
	Services.DungeonService:OnPlayerRemoving(player)
	Services.CombatService:OnPlayerRemoving(player)
	Services.LootService:OnPlayerRemoving(player)
	Services.MonetizationService:OnPlayerRemoving(player)
	Services.RewardService:OnPlayerRemoving(player)
	Services.HeroService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
