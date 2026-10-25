-- Schwarm-Ereignis: Regelmaessig taucht auf einer zufaelligen Route eine Bestienart in Massen auf.
-- Waehrend des Schwarms ist jede zweite Begegnung dort diese Bestie. Server-weit angekuendigt,
-- der Client zeigt Restzeit und Ort ueber Workspace-Attribute an.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)
local Progress = require(ReplicatedStorage.Shared.Progress)

local SwarmService = { Services = nil :: any }

local SWARM_COLOR = Color3.fromRGB(120, 230, 255)

local random = Random.new()
local current = nil -- { Area = areaId, Beast = beastId, Until = Serverzeit }

function SwarmService:Init(services)
	self.Services = services
end

-- Bestie aus dem Schwarm, wenn auf dieser Route gerade einer ist (sonst nil)
function SwarmService:Override(area): string?
	if not current or not area or area.Id ~= current.Area or workspace:GetServerTimeNow() > current.Until then
		return nil
	end
	return if random:NextNumber() < Progress.SwarmChance then current.Beast else nil
end

function SwarmService:Current()
	return current
end

-- Neuen Schwarm starten (areaId/beastId optional, sonst zufaellig)
function SwarmService:Begin(areaId: string?, beastId: string?)
	local routes = {}
	for _, area in Story.Areas do
		if area.Kind == "Route" and area.Wild then
			table.insert(routes, area)
		end
	end
	local area = (areaId and Story.AreasById[areaId]) or routes[random:NextInteger(1, #routes)]
	if not area or not area.Wild then
		return
	end
	local beast = beastId
	if not beast then
		-- Seltene Bestien der Route sind fuer einen Schwarm spannender: nach Kehrwert des Gewichts waehlen
		local total = 0
		for _, entry in area.Wild do
			total += 1 / entry[2]
		end
		local roll = random:NextNumber() * total
		beast = area.Wild[1][1]
		for _, entry in area.Wild do
			roll -= 1 / entry[2]
			if roll <= 0 then
				beast = entry[1]
				break
			end
		end
	end
	if not Config.BeastsById[beast] then
		return
	end
	current = { Area = area.Id, Beast = beast, Until = workspace:GetServerTimeNow() + Progress.SwarmDuration }
	workspace:SetAttribute("SwarmArea", area.Id)
	workspace:SetAttribute("SwarmBeast", beast)
	workspace:SetAttribute("SwarmUntil", current.Until)
	self.Services.Net.SendAnnounce(`SWARM! Lots of {Config.BeastsById[beast].Name} appeared on {area.Name}!`, SWARM_COLOR)
end

function SwarmService:Start()
	task.spawn(function()
		task.wait(Progress.SwarmFirst)
		while true do
			self:Begin()
			task.wait(Progress.SwarmDuration)
			current = nil
			workspace:SetAttribute("SwarmUntil", 0)
			task.wait(math.max(30, Progress.SwarmEvery - Progress.SwarmDuration))
		end
	end)
end

return SwarmService
