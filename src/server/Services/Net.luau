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
Net.Sync = remote("Sync") -- Server -> Spieler: Fortschritt (Quests, Index, Erfolge, Geschenke, Basis)

-- Client -> Server: Anfragen (Quest abholen, Rad drehen, Code einloesen ...). Antwort: ok, Text
Net.Request = Instance.new("RemoteFunction")
Net.Request.Name = "Request"
Net.Request.Parent = folder
local handlers = {}
local lastRequest = setmetatable({}, { __mode = "k" })
Net.Request.OnServerInvoke = function(player: Player, action: any, arg: any)
	local handler = type(action) == "string" and handlers[action]
	if not handler then
		return false, "Unknown action"
	end
	-- Schutz gegen Spam: hoechstens 8 Anfragen pro Sekunde
	local now = os.clock()
	local entry = lastRequest[player]
	if not entry or now - entry.At > 1 then
		entry = { At = now, Count = 0 }
		lastRequest[player] = entry
	end
	entry.Count += 1
	if entry.Count > 8 then
		return false, "Slow down!"
	end
	local ok, success, message, extra = pcall(handler, player, arg)
	if not ok then
		warn("[Net] Anfrage fehlgeschlagen", action, success)
		return false, "Something went wrong"
	end
	return success, message, extra
end

function Net.Handle(action: string, handler: (Player, any) -> (boolean, string?, any))
	handlers[action] = handler
end

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
