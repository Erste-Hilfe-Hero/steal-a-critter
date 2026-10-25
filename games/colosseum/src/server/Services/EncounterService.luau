-- Wilde Begegnungen im hohen Gras: Wer durch das Gras laeuft, trifft zufaellig auf wilde Bestien der Route.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)

local EncounterService = { Services = nil :: any }

local random = Random.new()
local walked = {} -- [Player] = Studs im Gras seit dem letzten Wurf
local lastPos = {} -- [Player] = Vector3
local quietUntil = {} -- [Player] = os.clock(), bis dahin keine Begegnung

function EncounterService:Init(services)
	self.Services = services
end

-- Wilde Bestie einer Route nach Gewicht auswaehlen
function EncounterService.Pick(area): (string, number)
	local total = 0
	for _, entry in area.Wild do
		total += entry[2]
	end
	local roll = random:NextNumber() * total
	local choice = area.Wild[1][1]
	for _, entry in area.Wild do
		roll -= entry[2]
		if roll <= 0 then
			choice = entry[1]
			break
		end
	end
	return choice, random:NextInteger(area.Levels[1], area.Levels[2])
end

local function encounter(player: Player, area)
	local services = EncounterService.Services
	local beastId, level = EncounterService.Pick(area)
	-- Schwarm auf dieser Route: oft die Schwarm-Bestie
	local swarm = services.SwarmService and services.SwarmService:Override(area)
	if swarm then
		beastId = swarm
	end
	if services.ProgressService then
		services.ProgressService:Bump(player, "Encounter", 1)
	end
	local shinyChance = Config.ShinyChance * services.MonetizationService:ServerShinyMultiplier() * services.MonetizationService:PlayerShinyMultiplier(player)
	local shiny = random:NextNumber() < shinyChance
	services.BattleService:StartWild(player, beastId, level, shiny)
end

function EncounterService:Start()
	local services = self.Services
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local data = services.DataService:Get(player)
				if root and data and data.Started then
					local pos = root.Position
					local before = lastPos[player]
					lastPos[player] = pos
					if services.StoryService:Busy(player) or root.Anchored then
						quietUntil[player] = os.clock() + Config.EncounterGrace
						walked[player] = 0
					elseif before and os.clock() > (quietUntil[player] or 0) then
						local area = Story.AreaAt(pos)
						local step = Vector3.new(pos.X - before.X, 0, pos.Z - before.Z).Magnitude
						if area and area.Wild and step < 20 and Story.InGrass(area, pos) then
							walked[player] = (walked[player] or 0) + step
							while (walked[player] or 0) >= Config.EncounterStep do
								walked[player] -= Config.EncounterStep
								if random:NextNumber() < Config.EncounterChance and services.BeastService:HasHealthyTeam(player) then
									walked[player] = 0
									quietUntil[player] = os.clock() + Config.EncounterGrace
									encounter(player, area)
									break
								end
							end
						end
					end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		walked[player] = nil
		lastPos[player] = nil
		quietUntil[player] = nil
	end)
end

return EncounterService
