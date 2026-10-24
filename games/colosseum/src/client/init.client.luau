-- Startpunkt des Clients: Oberflaeche, Kampf, Dialoge und Welt starten, Server-Nachrichten verteilen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UI = require(script.UI)
local Battle = require(script.Battle)
local Dialog = require(script.Dialog)
local World = require(script.World)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

UI.Init()
Battle.Init()
Dialog.Init()
World.Init()

-- Standard-Bestenliste ausblenden spart Platz auf dem Handy (Werte stehen oben in der Anzeige)
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)

remotes.Collection.OnClientEvent:Connect(function(collection)
	UI.SetCollection(collection)
	World.SetCollection(collection)
end)
remotes.Notify.OnClientEvent:Connect(UI.Toast)
remotes.Announce.OnClientEvent:Connect(UI.Announce)
remotes.Offer.OnClientEvent:Connect(function(key, text)
	if not Battle.Active() or key == "GauntletContinue" or key == "MasterOrb1" or key == "SkipChampion" or key == "FullHeal" or key == "PowerSnack" then
		UI.ShowOffer(key, text)
	end
end)
remotes.ChooseStarter.OnClientEvent:Connect(UI.ShowStarter)
remotes.DuelInvite.OnClientEvent:Connect(UI.ShowDuelInvite)
remotes.OpenMenu.OnClientEvent:Connect(UI.OpenMenu)

-- Story-Ereignisse vom Server
remotes.Story.OnClientEvent:Connect(function(kind, payload)
	payload = payload or {}
	if kind == "Badge" then
		UI.ShowBadge(payload)
	elseif kind == "HallOfFame" then
		UI.ShowHallOfFame(payload)
	elseif kind == "Fly" then
		UI.Fade("Flying...")
	elseif kind == "Whiteout" then
		UI.Fade("You hurried back to the Heal Center...")
	elseif kind == "Healed" then
		UI.Toast("♥ Your team is fully healed! ♥", Color3.fromRGB(255, 150, 190))
	elseif kind == "Hide" and typeof(payload.Flag) == "string" then
		World.SetFlag(payload.Flag)
	end
end)
