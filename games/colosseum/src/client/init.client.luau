-- Startpunkt des Clients: Oberflaeche, Kampf und Welt starten, Server-Nachrichten verteilen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UI = require(script.UI)
local Battle = require(script.Battle)
local World = require(script.World)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

UI.Init()
Battle.Init()
World.Init()

-- Standard-Bestenliste ausblenden spart Platz auf dem Handy (Werte stehen oben in der Anzeige)
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)

remotes.Collection.OnClientEvent:Connect(UI.SetCollection)
remotes.Notify.OnClientEvent:Connect(UI.Toast)
remotes.Announce.OnClientEvent:Connect(UI.Announce)
remotes.Offer.OnClientEvent:Connect(function(key, text)
	if not Battle.Active() or key == "GauntletContinue" or key == "MasterOrb1" or key == "SkipChampion" or key == "FullHeal" then
		UI.ShowOffer(key, text)
	end
end)
remotes.ChooseStarter.OnClientEvent:Connect(UI.ShowStarter)
remotes.DuelInvite.OnClientEvent:Connect(UI.ShowDuelInvite)
