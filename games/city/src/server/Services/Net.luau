-- Erstellt die Remotes und bietet Helfer fuer Benachrichtigungen und Client-Anfragen.
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
Net.Offer = remote("Offer") -- Server -> ein Spieler (Produkt-Schluessel, Grund)
Net.Marker = remote("Marker") -- Server -> ein Spieler (Position oder nil, Beschriftung, Art)
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)
Net.WatchAd = remote("WatchAd") -- Client -> Server: Spieler will freiwillig eine Werbung sehen

Net.Request = Instance.new("RemoteFunction")
Net.Request.Name = "Request"
Net.Request.Parent = folder

folder.Parent = ReplicatedStorage

local handlers = {}
local lastCall = {} -- [Player] = os.clock() (einfacher Spam-Schutz)

-- Client-Aktion registrieren. fn(player, ...) gibt (ok, Meldung) zurueck.
function Net.Handle(action: string, fn: (Player, ...any) -> (boolean?, string?))
	handlers[action] = fn
end

Net.Request.OnServerInvoke = function(player: Player, action: any, ...)
	if typeof(action) ~= "string" or not handlers[action] then
		return false, "Unknown action"
	end
	local now = os.clock()
	if now - (lastCall[player] or 0) < 0.15 then
		return false, "Slow down!"
	end
	lastCall[player] = now
	local ok, result, message = pcall(handlers[action], player, ...)
	if not ok then
		warn("[Net]", action, result)
		return false, "Something went wrong"
	end
	return result, message
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

function Net.SendMarker(player: Player, position: Vector3?, label: string?, kind: string?)
	Net.Marker:FireClient(player, position, label, kind)
end

return Net
