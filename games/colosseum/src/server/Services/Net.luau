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
Net.Notify = remote("Notify") -- (text, color) ein Spieler
Net.Announce = remote("Announce") -- (text, color) alle
Net.Collection = remote("Collection") -- komplette Sammlung: Bestien, Team, Gegenstaende, Fortschritt
Net.Battle = remote("Battle") -- (kind, payload) Kampfstart, Runden-Ereignisse, Ende
Net.Offer = remote("Offer") -- (productKey, text) Kaufangebot
Net.ChooseStarter = remote("ChooseStarter") -- Starter-Auswahl im Labor
Net.DuelInvite = remote("DuelInvite") -- (fromPlayer)
Net.Dialog = remote("Dialog") -- (token, { Speaker, Lines, Choices }) Gespraech anzeigen
Net.OpenMenu = remote("OpenMenu") -- (name) Fenster oeffnen, z. B. "Mart"
Net.Story = remote("Story") -- (kind, payload) Ereignisse wie Orden, Hall of Fame

-- Client -> Server
Net.DialogAnswer = remote("DialogAnswer") -- (token, choiceIndex)
Net.PickStarter = remote("PickStarter") -- (beastId)
Net.BattleAction = remote("BattleAction") -- ({ Kind = "Move"/"Item"/"Swap"/"Run"/"Replace", ... })
Net.SetTeam = remote("SetTeam") -- ({ uid, ... }) Reihenfolge des Teams
Net.MoveBeast = remote("MoveBeast") -- (uid, "Team"/"Box") zwischen Team und Box verschieben
Net.SetMove = remote("SetMove") -- (uid, slot, moveKey) Attacke tauschen/lernen
Net.UseItem = remote("UseItem") -- (itemKey, uid) Gegenstand ausserhalb von Kaempfen
Net.ReleaseBeast = remote("ReleaseBeast") -- (uid) gegen Muenzen freilassen
Net.BuyItem = remote("BuyItem") -- (itemKey, amount)
Net.TrainerSpotted = remote("TrainerSpotted") -- (trainerId) der Client sieht einen Trainer
Net.Fly = remote("Fly") -- (areaId) zu einer besuchten Stadt fliegen
Net.ArenaChallenge = remote("ArenaChallenge") -- ("Gauntlet") oder ("Rematch", index)
Net.DuelRequest = remote("DuelRequest") -- (targetPlayer)
Net.DuelAnswer = remote("DuelAnswer") -- (fromPlayer, accepted)
Net.ClaimDaily = remote("ClaimDaily")
Net.RedeemCode = remote("RedeemCode") -- (code)
Net.WatchAd = remote("WatchAd")
Net.PromptProduct = remote("PromptProduct") -- (kind, key) Kauf ueber den Server starten
Net.FakePurchase = remote("FakePurchase") -- nur Studio

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
