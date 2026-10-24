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

-- Server -> Client
Net.Notify = remote("Notify") -- ein Spieler
Net.Announce = remote("Announce") -- alle
Net.Inventory = remote("Inventory") -- komplettes Inventar (Pets, Equipped, Storage)
Net.Hatched = remote("Hatched") -- Ergebnis beim Schluepfen (fuer die Animation)
Net.CoinPop = remote("CoinPop") -- "+123" ueber zerstoerten Sachen

-- Client -> Server
Net.RequestRebirth = remote("RequestRebirth")
Net.ToggleEquip = remote("ToggleEquip") -- (uid)
Net.EquipBest = remote("EquipBest")
Net.DeletePets = remote("DeletePets") -- ({uid})
Net.CraftGolden = remote("CraftGolden") -- (typeId)
Net.SetAutoHatch = remote("SetAutoHatch") -- (boolean)
Net.ClaimDaily = remote("ClaimDaily")
Net.FakePurchase = remote("FakePurchase") -- nur Studio

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
