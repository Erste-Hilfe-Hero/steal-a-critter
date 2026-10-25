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
Net.Died = remote("Died") -- Client -> Server (Kill-Teil beruehrt oder heruntergefallen)
Net.EquipTrail = remote("EquipTrail") -- Client -> Server
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)
Net.Sync = remote("Sync") -- Client -> Server: Zustand anfordern; Server -> Client: Zustand (Quests, Erfolge, Einstellungen, Statistik)
Net.ClaimDaily = remote("ClaimDaily") -- Client -> Server
Net.ClaimQuest = remote("ClaimQuest") -- Client -> Server (Quest-Index)
Net.EquipTitle = remote("EquipTitle") -- Client -> Server (Erfolg-Id oder "")
Net.RedeemCode = remote("RedeemCode") -- Client -> Server (Code-Text)
Net.BuyTrail = remote("BuyTrail") -- Client -> Server (Trail-Id, Kauf mit Coins)
Net.SetSetting = remote("SetSetting") -- Client -> Server (Key, boolean)
Net.SelectStage = remote("SelectStage") -- Client -> Server (Stage-Nummer, nur bereits erreichte)

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
