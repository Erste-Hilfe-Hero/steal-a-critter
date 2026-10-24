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
Net.Collection = remote("Collection") -- komplette Sammlung: Bestien, Team, Gegenstaende
Net.Battle = remote("Battle") -- (kind, payload) Kampfstart, Runden-Ereignisse, Ende
Net.Offer = remote("Offer") -- (productKey, text) Kaufangebot
Net.ChooseStarter = remote("ChooseStarter") -- Startbildschirm fuer neue Spieler
Net.DuelInvite = remote("DuelInvite") -- (fromPlayer)

-- Client -> Server
Net.PickStarter = remote("PickStarter") -- (beastId)
Net.BattleAction = remote("BattleAction") -- ({ Kind = "Move"/"Item"/"Swap"/"Run", ... })
Net.SetTeam = remote("SetTeam") -- ({ uid, ... })
Net.ReleaseBeast = remote("ReleaseBeast") -- (uid) gegen Muenzen freilassen
Net.BuyItem = remote("BuyItem") -- (itemKey, amount)
Net.ArenaChallenge = remote("ArenaChallenge") -- (index) oder "Gauntlet"
Net.DuelRequest = remote("DuelRequest") -- (targetPlayer)
Net.DuelAnswer = remote("DuelAnswer") -- (fromPlayer, accepted)
Net.ClaimDaily = remote("ClaimDaily")
Net.RedeemCode = remote("RedeemCode") -- (code)
Net.Heal = remote("Heal") -- an der Quelle heilen
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
