-- Fehlersuche im Live-Spiel: zaehlt, warum Schwertangriffe von Spielern nicht treffen, und sammelt
-- Fehler aus den Clients. Alles landet jede Minute im DataStore "SoccerDiag_v1" (Schluessel = Server),
-- den ein Workflow per Open Cloud ausliest.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DiagService = { Services = nil :: any }

local counts = {} -- [Ereignis] = Anzahl
local samples = {} -- Beispiele (Text), hoechstens 40
local clientErrors = {} -- [Fehlertext] = Anzahl
local serverErrors = {} -- [Fehlertext] = Anzahl
local dirty = false

function DiagService:Count(event: string, sample: string?)
	counts[event] = (counts[event] or 0) + 1
	if sample and #samples < 40 then
		table.insert(samples, event .. ": " .. sample)
	end
	dirty = true
end

function DiagService:Init(services)
	self.Services = services
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ClientLog"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	local perPlayer = {}
	remote.OnServerEvent:Connect(function(player, text)
		if typeof(text) ~= "string" then
			return
		end
		perPlayer[player] = (perPlayer[player] or 0) + 1
		if perPlayer[player] > 30 then
			return
		end
		text = string.sub(text, 1, 400)
		clientErrors[text] = (clientErrors[text] or 0) + 1
		dirty = true
	end)
end

function DiagService:Start()
	-- Alle Server-Fehler mitschreiben
	game:GetService("LogService").MessageOut:Connect(function(message, kind)
		if kind == Enum.MessageType.MessageError or (kind == Enum.MessageType.MessageWarning and string.sub(message, 1, 1) == "[") then
			local text = string.sub(message, 1, 300)
			serverErrors[text] = (serverErrors[text] or 0) + 1
			dirty = true
		end
	end)
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, "SoccerDiag_v1")
	if not ok then
		return
	end
	local key = if game.JobId ~= "" then game.JobId else "studio"
	task.spawn(function()
		while true do
			task.wait(60)
			if dirty then
				dirty = false
				local payload = HttpService:JSONEncode({
					Time = os.time(),
					Version = game.PlaceVersion,
					Counts = counts,
					Samples = samples,
					ClientErrors = clientErrors,
					ServerErrors = serverErrors,
				})
				pcall(function()
					store:SetAsync(key, payload)
				end)
			end
		end
	end)
end

return DiagService
