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
	ExtrasService = require(script.Services.ExtrasService),
	DiagService = require(script.Services.DiagService),
	FeaturesService = require(script.Services.FeaturesService),
}

local ORDER = { "DataService", "ArenaService", "ProgressService", "BallService", "CombatService", "BotService", "MatchService", "MonetizationService", "ExtrasService", "FeaturesService", "PlusService", "DiagService" }

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
	-- Jeder Schritt einzeln abgesichert: ein Fehler in einem Service darf nicht verhindern, dass der
	-- Spieler mitspielt (sonst ist er kein Akteur und kann z. B. nicht angreifen)
	local function step(name: string, fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then
			warn(`[Join] {name} failed:`, err)
			Services.DiagService:Count("joinError." .. name, tostring(err))
		end
	end
	step("LoadPasses", Services.MonetizationService.LoadPasses, Services.MonetizationService, player)
	step("ProgressReady", Services.ProgressService.OnPlayerReady, Services.ProgressService, player)
	step("MatchReady", Services.MatchService.OnPlayerReady, Services.MatchService, player)

	local function onCharacter(character: Model)
		task.spawn(step, "MatchCharacter", Services.MatchService.OnCharacterAdded, Services.MatchService, player, character)
		task.spawn(step, "ProgressCharacter", Services.ProgressService.OnCharacterAdded, Services.ProgressService, player, character)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end

	task.spawn(step, "MonetizationReady", Services.MonetizationService.OnPlayerReady, Services.MonetizationService, player)
	task.spawn(step, "ExtrasReady", Services.ExtrasService.OnPlayerReady, Services.ExtrasService, player)
	task.spawn(step, "FeaturesReady", Services.FeaturesService.OnPlayerReady, Services.FeaturesService, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Services.MatchService:OnPlayerRemoving(player)
	Services.DataService:Release(player)
end)
