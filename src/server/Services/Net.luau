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
Net.RequestRebirth = remote("RequestRebirth") -- Client -> Server
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)
Net.Offer = remote("Offer") -- Server -> Spieler: passendes Angebot im richtigen Moment (mit "No thanks")
Net.WatchAd = remote("WatchAd") -- Client -> Server: Spieler will freiwillig eine Werbung sehen

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

-- Hoechstens ein Angebot alle 3 Minuten pro Spieler, damit es nicht nervt
local lastOffer = setmetatable({}, { __mode = "k" })
function Net.SendOffer(player: Player, kind: string, key: string, reason: string)
	local now = os.clock()
	if lastOffer[player] and now - lastOffer[player] < 180 then
		return
	end
	lastOffer[player] = now
	Net.Offer:FireClient(player, kind, key, reason)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
