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
Net.Announce = remote("Announce") -- Server -> alle
Net.Effect = remote("Effect") -- Server -> Fahrer: ("Boost"/"Spin"/"Inferno"/"Finish"/"Flash"/"LevelUp"/"Quest"/"Achievement", Wert)
Net.Results = remote("Results") -- Server -> alle: Rennergebnis
Net.Offer = remote("Offer") -- Server -> ein Spieler: Angebot (Produkt-Key)
Net.Vote = remote("Vote") -- Client -> Server (Strecken-Id)
Net.UseItem = remote("UseItem") -- Client -> Server
Net.UseSuper = remote("UseSuper") -- Client -> Server: gespeichertes Inferno-Item einsetzen
Net.Boosting = remote("Boosting") -- Client -> Server: Boost-Flamme an/aus (fuer alle sichtbar)
Net.Shop = remote("Shop") -- Client -> Server: ("BuyKart"/"SelectKart"/"BuyFlame"/"SelectFlame"/"BuyPaint"/"SelectPaint", Id)
Net.WantTrack = remote("WantTrack") -- Client -> Server: gewuenschte Strecke vor dem Kauf "Pick Next Track"
Net.Claim = remote("Claim") -- Client -> Server: ("Daily"/"Gift"/"Tutorial") oder ("Quest", Nummer)
Net.WatchAd = remote("WatchAd") -- Client -> Server
Net.Purchase = remote("Purchase") -- Client -> Server: ("Pass"/"Product", Key)
Net.SetTitle = remote("SetTitle") -- Client -> Server: Erfolg-Id des Titels ("" = kein Titel)
Net.Setting = remote("Setting") -- Client -> Server: (Key, boolean)
Net.RedeemCode = remote("RedeemCode") -- Client -> Server: Code-Text
Net.GetProfile = Instance.new("RemoteFunction") -- Client -> Server: Profil (Statistik, Erfolge, Bestzeiten)
Net.GetProfile.Name = "GetProfile"
Net.GetProfile.Parent = folder

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
