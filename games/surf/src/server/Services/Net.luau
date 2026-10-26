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
-- Update 2
Net.Progress = remote("Progress") -- Client -> Server ("Title", Id) / ("Claim", QuestId) / ("Code", Text) / ("Spin") / ("Settings", Tabelle)
Net.ProgressSync = remote("ProgressSync") -- Server -> ein Spieler (Erfolge, Aufgaben, Medaillen, Statistik, Einstellungen)
Net.Reward = remote("Reward") -- Server -> ein Spieler ("Achievement", Id) / ("Spin", Index, Text)

-- Update 3
Net.Wars = remote("Wars") -- Client -> Server ("Join") / ("Leave") / ("Fire", Waffe, Ursprung, Richtung, SchussId, Treffer) / ("Impact", SchussId, Ziel, Punkt) / ("Fell")
Net.WarsEvent = remote("WarsEvent") -- Server -> Clients ("Shot", Key, Waffe, Ursprung, Richtung) / ("Frozen", ...) / ("Knock", Vektor) / ("HitConfirm", ...) / ("Pickup", Waffe) / ("Countdown"/"RoundStart"/"RoundEnd") / ("Splash", Punkt)
Net.Fx = remote("Fx") -- Server -> alle ("Fireworks", Position) fuer Effekte

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
