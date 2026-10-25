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
	ProgressService = require(script.Services.ProgressService),
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
	"ProgressService",
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
	task.spawn(Services.ProgressService.OnCharacterAdded, Services.ProgressService, player, character)
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
	Services.ProgressService:OnPlayerReady(player)
	player:LoadCharacter()
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

-- Jeder Schritt einzeln geschuetzt: ein Fehler darf das Speichern am Ende nie verhindern
local LEAVE_ORDER = { "CommunityService", "DungeonService", "CombatService", "LootService", "MonetizationService", "RewardService", "ProgressService", "HeroService" }

Players.PlayerRemoving:Connect(function(player)
	for _, name in LEAVE_ORDER do
		local ok, err = pcall(Services[name].OnPlayerRemoving, Services[name], player)
		if not ok then
			warn(`[Server] {name}.OnPlayerRemoving:`, err)
		end
	end
	Services.DataService:Release(player)
end)
