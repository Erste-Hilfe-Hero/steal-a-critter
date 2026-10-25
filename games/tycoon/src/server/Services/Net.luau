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

Net.Notify = remote("Notify") -- Server -> ein Spieler
Net.Announce = remote("Announce") -- Server -> alle
Net.Effect = remote("Effect") -- Server -> ein Spieler (Art, Position, Text, Farbe) fuer Ernte-/Verkaufseffekte
Net.SelectSeed = remote("SelectSeed") -- Client -> Server (Samen-Id oder nil)
Net.BuySeed = remote("BuySeed") -- Client -> Server (Samen-Id)
Net.BuyUpgrade = remote("BuyUpgrade") -- Client -> Server ("Tile", "Sprinkler", "Fertilizer")
Net.SellAll = remote("SellAll") -- Client -> Server (nur am Verkaufsstand)
Net.Teleport = remote("Teleport") -- Client -> Server ("Garden", "Shop", "Sell")
Net.RequestRebirth = remote("RequestRebirth") -- Client -> Server
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)
-- Update 2
Net.SetTool = remote("SetTool") -- Client -> Server ("Shovel" oder nil)
Net.PlantAll = remote("PlantAll") -- Client -> Server: alle freien Felder mit dem gewaehlten Samen bepflanzen
Net.ClaimQuest = remote("ClaimQuest") -- Client -> Server (Nummer der Tagesaufgabe)
Net.EquipTitle = remote("EquipTitle") -- Client -> Server (Erfolgs-Id oder "")
Net.Spin = remote("Spin") -- Client -> Server: Gluecksrad drehen
Net.SpinResult = remote("SpinResult") -- Server -> Client (Nummer des Gewinns, Text)
Net.RedeemCode = remote("RedeemCode") -- Client -> Server (Code-Text)
Net.SetSetting = remote("SetSetting") -- Client -> Server (Name, boolean)
Net.BuyPet = remote("BuyPet") -- Client -> Server (Pet-Id): kaufen oder ausruesten
Net.BuySkin = remote("BuySkin") -- Client -> Server (Design-Id): kaufen oder ausruesten
Net.RequestSync = remote("RequestSync") -- Client -> Server: Listen (Aufgaben, Index, ...) anfordern
Net.Sync = remote("Sync") -- Server -> Client (Tabelle mit Aufgaben, Erfolgen, Index, Pets, Designs)

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
