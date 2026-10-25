-- Hinweise (Lupen) auf der Karte: Innocents, Sheriff und Hero finden sie und erfahren nach und nach
-- etwas ueber den Murderer (Namenslaenge, Entfernung, Anfangsbuchstabe). Der Murderer kann sie nicht aufheben.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ClueService = { Services = nil :: any }

local CL = Config.Clues

local folder: Folder
local roundToken = nil
local spawned = 0
local found = {} -- [actor] = Anzahl Hinweise in dieser Runde

---------------------------------------------------------------- Hinweise

local function aliveMurderers(): { any }
	local list = {}
	for _, actor in ClueService.Services.RoundService.Actors do
		if actor.Alive and actor.Role == "Murderer" then
			table.insert(list, actor)
		end
	end
	return list
end

local function nameLength(name: string): number
	return utf8.len(name) or #name
end

local function firstLetter(name: string): string
	for _, code in utf8.codes(name) do
		return string.upper(utf8.char(code))
	end
	return "?"
end

-- Der wievielte Hinweis bestimmt, was verraten wird (je mehr man findet, desto genauer)
function ClueService:HintFor(actor, index: number): string
	local murderers = aliveMurderers()
	if #murderers == 0 then
		return "The Murderer is gone... for now."
	end
	-- Fuer die Entfernung zaehlt der naechste Murderer, sonst ein zufaelliger
	local nearest, nearestDist = murderers[1], math.huge
	for _, m in murderers do
		local d = (m.Root.Position - actor.Root.Position).Magnitude
		if d < nearestDist then
			nearest, nearestDist = m, d
		end
	end
	local pick = murderers[math.random(1, #murderers)]
	if index == 1 then
		return `The Murderer's name has {nameLength(pick.Name)} letters.`
	elseif index == 3 then
		return `The Murderer's name starts with "{firstLetter(pick.Name)}".`
	end
	local rounded = math.max(10, math.floor(nearestDist / 10 + 0.5) * 10)
	return if nearestDist < 30 then "The Murderer is VERY close to you right now!" else `The Murderer is about {rounded} studs away from you.`
end

---------------------------------------------------------------- Lupen auf der Karte

-- Hinweis aufheben (vom Touched-Ereignis und vom Smoke-Test aufgerufen)
function ClueService:Pickup(clue: BasePart, actor): boolean
	local services = self.Services
	local round = services.RoundService
	if not clue.Parent or not round:IsPlaying() then
		return false
	end
	if not actor or not actor.Alive or actor.Role == "Murderer" or actor.Hidden then
		return false
	end
	local position = clue.Position
	clue:Destroy()
	found[actor] = (found[actor] or 0) + 1
	services.Net.Fx:FireAllClients("CluePickup", { Position = position })
	if actor.Player then
		local player = actor.Player
		local text = ClueService:HintFor(actor, found[actor])
		services.ProgressService:AddCoins(player, CL.Reward, false, true)
		services.ProgressService:Track(player, "Clue", 1)
		services.ProgressService:AddStat(player, "CluesFound", 1)
		services.Net.Fx:FireClient(player, "Clue", { Text = text, Count = found[actor], Reward = CL.Reward })
	end
	return true
end

local function spawnClue(map): BasePart?
	if not map or #map.CoinSpots == 0 then
		return nil
	end
	local base = map.CoinSpots[math.random(1, #map.CoinSpots)]
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map.Model }
	local hit = workspace:Raycast(base + Vector3.new(0, Config.WallHeight - 2, 0), Vector3.new(0, -Config.WallHeight, 0), params)
	if not hit or hit.Position.Y > base.Y + 5 then
		return nil
	end
	local clue = Instance.new("Part")
	clue.Name = "Clue"
	clue.Shape = Enum.PartType.Cylinder
	clue.Size = Vector3.new(0.35, 2.4, 2.4)
	clue.CFrame = CFrame.new(hit.Position + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	clue.Color = Config.Colors.Cyan
	clue.Material = Enum.Material.Neon
	clue.Transparency = 0.1
	clue.Anchored = true
	clue.CanCollide = false
	clue.CanQuery = false
	clue.CastShadow = false
	clue:AddTag("Clue")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(46, 46)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = clue
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "🔍"
	label.TextScaled = true
	label.Parent = gui
	local light = Instance.new("PointLight")
	light.Color = Config.Colors.Cyan
	light.Range = 10
	light.Parent = clue
	clue.Touched:Connect(function(part)
		ClueService:Pickup(clue, ClueService.Services.RoundService:ActorFromPart(part))
	end)
	clue.Parent = folder
	spawned += 1
	return clue
end

function ClueService:SpawnOne(map): BasePart?
	return spawnClue(map)
end

function ClueService:Count(): number
	return #folder:GetChildren()
end

function ClueService:Found(actor): number
	return found[actor] or 0
end

---------------------------------------------------------------- Runde

function ClueService:StartRound(map)
	local token = {}
	roundToken = token
	spawned = 0
	table.clear(found)
	folder:ClearAllChildren()
	task.spawn(function()
		task.wait(CL.FirstAfter)
		while roundToken == token do
			while roundToken == token and #folder:GetChildren() < CL.MaxOnMap and spawned < CL.MaxPerRound do
				if not spawnClue(map) then
					break
				end
			end
			task.wait(CL.Every)
		end
	end)
end

function ClueService:StopRound()
	roundToken = nil
	table.clear(found)
	folder:ClearAllChildren()
end

function ClueService:Init(services)
	self.Services = services
	folder = Instance.new("Folder")
	folder.Name = "Clues"
	folder.Parent = workspace
end

return ClueService
