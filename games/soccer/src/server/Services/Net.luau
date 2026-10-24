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
Net.MatchEvent = remote("MatchEvent") -- Server -> alle (Tor, Anstoss, Ende)
Net.Results = remote("Results") -- Server -> ein Spieler (eigene Match-Bilanz)
Net.Knockback = remote("Knockback") -- Server -> ein Spieler (umgehauen: Geschwindigkeit)
Net.Sound = remote("Sound") -- Server -> alle (Soundeffekt: Name, Position, Tonhoehe, Lautstaerke)
Net.Offer = remote("Offer") -- Server -> ein Spieler (Kaufangebot zeigen)
Net.Kick = remote("Kick") -- Client -> Server (power 0..1, Richtung)
Net.Pass = remote("Pass") -- Client -> Server
Net.Tackle = remote("Tackle") -- Client -> Server (KNIFE: Slash + Disarm)
Net.Stab = remote("Stab") -- Client -> Server (starker Messerstich)
Net.CallPass = remote("CallPass") -- Client -> Server ("!" ueber dem Kopf: Pass fordern)
Net.Upgrade = remote("Upgrade") -- Client -> Server (Skill)
Net.BuyPoint = remote("BuyPoint") -- Client -> Server (Skillpunkt fuer Coins)
Net.Trail = remote("Trail") -- Client -> Server (kaufen oder ausruesten)
Net.WatchAd = remote("WatchAd") -- Client -> Server
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

-- Ohne Position spielt der Sound ueberall gleich laut (Pfiff, Hupe)
function Net.PlaySound(name: string, position: Vector3?, pitch: number?, volume: number?)
	Net.Sound:FireAllClients(name, position, pitch, volume)
end

return Net
