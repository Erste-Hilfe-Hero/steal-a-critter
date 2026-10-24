-- Erstellt die RemoteEvents und bietet Helfer fuer Meldungen und Effekte.
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
Net.Announce = remote("Announce") -- Server -> alle (grosse Ansage)
Net.KillFeed = remote("KillFeed") -- Server -> alle (Killer, Opfer, Teamfarbe)
Net.Fx = remote("Fx") -- Server -> alle (Effektart, Daten)
Net.Damage = remote("Damage") -- Server -> ein Spieler (Position, Zahl, Art) fuer Schadenszahlen
Net.MatchResult = remote("MatchResult") -- Server -> ein Spieler (Ergebnis-Tabelle)
Net.Offer = remote("Offer") -- Server -> ein Spieler (Produkt-Schluessel, Text)
Net.Cast = remote("Cast") -- Client -> Server (Taste, Zielpunkt oder nil)
Net.Focus = remote("Focus") -- Client -> Server (Ziel-Model oder nil)
Net.Recall = remote("Recall") -- Client -> Server
Net.BuyItem = remote("BuyItem") -- Client -> Server (Item-Id)
Net.SellItem = remote("SellItem") -- Client -> Server (Platz)
Net.SetAutoBuy = remote("SetAutoBuy") -- Client -> Server (boolean)
Net.PickHero = remote("PickHero") -- Client -> Server (Helden-Id)
Net.UnlockHero = remote("UnlockHero") -- Client -> Server (Helden-Id) mit Kristallen
Net.BuySkin = remote("BuySkin") -- Client -> Server (Skin-Id) mit Kristallen
Net.EquipSkin = remote("EquipSkin") -- Client -> Server (Skin-Id)
Net.ClaimDaily = remote("ClaimDaily") -- Client -> Server
Net.WatchAd = remote("WatchAd") -- Client -> Server: freiwillige Video-Werbung
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

function Net.SendFx(kind: string, data)
	Net.Fx:FireAllClients(kind, data)
end

return Net
