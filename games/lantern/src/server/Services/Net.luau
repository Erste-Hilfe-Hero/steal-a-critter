-- Erstellt die Remotes und bietet Helfer fuer Benachrichtigungen und Effekte.
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
Net.Effect = remote("Effect") -- Server -> Spieler (Art, Daten) fuer Treffer, Zauber, Beute
Net.Sync = remote("Sync") -- Server -> ein Spieler (Thema, Daten): Inventar, Lobby, Dungeon, Zusammenfassung
Net.Offer = remote("Offer") -- Server -> ein Spieler (Produkt-Schluessel, Text)
Net.Attack = remote("Attack") -- Client -> Server (Zielmodell oder nil)
Net.Skill = remote("Skill") -- Client -> Server (1 oder 2, Zielmodell oder nil)
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)

-- Client -> Server mit Antwort: Inventar, Klasse, Schmiede, Lobby ...
Net.Request = Instance.new("RemoteFunction")
Net.Request.Name = "Request"
Net.Request.Parent = folder

folder.Parent = ReplicatedStorage

local handlers = {}

function Net.Handle(action: string, fn: (Player, ...any) -> any)
	handlers[action] = fn
end

Net.Request.OnServerInvoke = function(player: Player, action: any, ...)
	local fn = typeof(action) == "string" and handlers[action]
	if not fn then
		return false
	end
	local ok, result, extra = pcall(fn, player, ...)
	if not ok then
		warn("[Net]", action, result)
		return false
	end
	return result, extra
end

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

-- Effekt an eine Liste von Spielern (z. B. alle in einem Dungeon)
function Net.SendEffect(players: { Player }, kind: string, data: any)
	for _, player in players do
		if player.Parent then
			Net.Effect:FireClient(player, kind, data)
		end
	end
end

return Net
