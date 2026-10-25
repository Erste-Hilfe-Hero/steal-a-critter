-- Erstellt die RemoteEvents und bietet Helfer fuer Benachrichtigungen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"

local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = folder
	return event
end

Net.Notify = remote("Notify") -- Server -> ein Spieler (Text, Farbe)
Net.Announce = remote("Announce") -- Server -> alle (Text, Farbe)
Net.Teleport = remote("Teleport") -- Server -> ein Spieler (CFrame): der Client bewegt sich selbst dorthin
Net.Result = remote("Result") -- Server -> ein Spieler (Info-Tabelle nach Stage/Map-Ziel)
Net.Checkpoint = remote("Checkpoint") -- Server -> ein Spieler ("Save"/"Load") aus Chatbefehlen
Net.Run = remote("Run") -- Client -> Server ("Start", "Leave", "Fell", "Finish", "Restart", "RestartStage", "Lobby", "Goto", "UsedCheckpoint")
Net.Shop = remote("Shop") -- Client -> Server ("Buy"/"Equip", "Trail"/"Ski", Id)
Net.Purchase = remote("Purchase") -- Client -> Server ("Pass"/"Product", Key): Kauf starten
Net.WatchAd = remote("WatchAd") -- Client -> Server
Net.ClaimDaily = remote("ClaimDaily") -- Client -> Server
Net.ClientLog = remote("ClientLog") -- Client -> Server (Fehler und Zustand fuer die Fehlersuche)

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
