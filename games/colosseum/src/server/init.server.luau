-- Startpunkt des Servers: laedt alle Services und steuert Join/Leave in fester Reihenfolge.
local Players = game:GetService("Players")

local Services = {
	Net = require(script.Services.Net),
	DataService = require(script.Services.DataService),
	WorldService = require(script.Services.WorldService),
	BeastService = require(script.Services.BeastService),
	BattleService = require(script.Services.BattleService),
	StoryService = require(script.Services.StoryService),
	EncounterService = require(script.Services.EncounterService),
	MonetizationService = require(script.Services.MonetizationService),
	RewardService = require(script.Services.RewardService),
	LeaderboardService = require(script.Services.LeaderboardService),
	CommunityService = require(script.Services.CommunityService),
}

local ORDER = { "DataService", "WorldService", "BeastService", "BattleService", "StoryService", "EncounterService", "MonetizationService", "RewardService", "LeaderboardService", "CommunityService" }

for _, name in ORDER do
	Services[name]:Init(Services)
end
Services.WorldService:Build()
Services.StoryService:Build()
for _, name in ORDER do
	if Services[name].Start then
		Services[name]:Start()
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = player:GetAttribute("BaseWalkSpeed") or 18
	task.spawn(Services.CommunityService.AttachNameplate, Services.CommunityService, player, character)
	-- Duell-Anfrage: andere Spieler sehen den Prompt (der eigene wird im Client ausgeblendet)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if root then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DuelPrompt"
		prompt.ActionText = "Duel!"
		prompt.ObjectText = player.DisplayName
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("Owner", player.UserId)
		prompt.Parent = root
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
	Services.BeastService:OnPlayerReady(player)
	Services.StoryService:OnPlayerReady(player)
	Services.RewardService:OnPlayerReady(player)
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
	Services.BattleService:OnPlayerRemoving(player)
	Services.BeastService:OnPlayerRemoving(player)
	Services.StoryService:OnPlayerRemoving(player)
	Services.CommunityService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
