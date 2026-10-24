-- Erstellt die Remotes und bietet Helfer fuer Benachrichtigungen.
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

Net.Notify = remote("Notify") -- Server -> ein Spieler (Toast)
Net.Announce = remote("Announce") -- Server -> alle (grosses Banner)
Net.Round = remote("Round") -- Server -> alle (Rundenstatus)
Net.Role = remote("Role") -- Server -> ein Spieler (eigene Rolle, Chancen)
Net.Fx = remote("Fx") -- Server -> alle (K.O., Schuss, Wurf, Power-Up ...)
Net.Sync = remote("Sync") -- Server -> ein Spieler (Profil fuer Menues)
Net.Offer = remote("Offer") -- Server -> ein Spieler (Kaufangebot)
Net.Results = remote("Results") -- Server -> alle (Rundenende)
Net.Footprints = remote("Footprints") -- Server -> Sheriff (Scanner)
Net.Stab = remote("Stab") -- Client -> Server
Net.Throw = remote("Throw") -- Client -> Server (Zielpunkt)
Net.Shoot = remote("Shoot") -- Client -> Server (Zielpunkt)
Net.Ability = remote("Ability") -- Client -> Server (Name, Zusatz)
Net.WatchAd = remote("WatchAd") -- Client -> Server
Net.FakePurchase = remote("FakePurchase") -- Client -> Server (nur Studio)

-- Menue-Aktionen mit Antwort (Kiste oeffnen, ausruesten, Code ...)
Net.Request = Instance.new("RemoteFunction")
Net.Request.Name = "Request"
Net.Request.Parent = folder

local handlers = {}
function Net.Handle(action: string, fn: (Player, ...any) -> any)
	handlers[action] = fn
end

-- Pro Spieler kurze Sperre gegen Spam
local last = {}
Net.Request.OnServerInvoke = function(player: Player, action: any, ...)
	if typeof(action) ~= "string" or not handlers[action] then
		return { Ok = false, Error = "Unknown action" }
	end
	local t = os.clock()
	if last[player] and t - last[player] < 0.15 then
		return { Ok = false, Error = "Slow down" }
	end
	last[player] = t
	local ok, result = pcall(handlers[action], player, ...)
	if not ok then
		warn("[Net]", action, result)
		return { Ok = false, Error = "Something went wrong" }
	end
	return result
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	last[player] = nil
end)

folder.Parent = ReplicatedStorage

function Net.SendNotify(player: Player, text: string, color: Color3?)
	Net.Notify:FireClient(player, text, color)
end

function Net.SendAnnounce(text: string, color: Color3?)
	Net.Announce:FireAllClients(text, color)
end

return Net
