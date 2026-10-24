-- Zeigt die ausgeruesteten Haustiere aller Spieler an (nur lokal, spart Server-Leistung).
-- Ohne Ziel laufen sie hinter dem Spieler her, mit Ziel huepfen sie um die Sache herum.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PetFactory = require(ReplicatedStorage.Shared.PetFactory)

local PetFollow = {}

local folder = Instance.new("Folder")
folder.Name = "ClientPets"
folder.Parent = workspace

local owners = {} -- [Player] = { Key = string, Pets = { { Model, Scale, CFrame } } }

local function clear(player: Player)
	local entry = owners[player]
	if entry then
		for _, pet in entry.Pets do
			pet.Model:Destroy()
		end
	end
	owners[player] = nil
end

local function rebuild(player: Player)
	local key = player:GetAttribute("EquippedPets") or ""
	local entry = owners[player]
	if entry and entry.Key == key then
		return
	end
	clear(player)
	entry = { Key = key, Pets = {} }
	for _, token in string.split(key, ",") do
		local typeId, flag = token:match("^([^:]+):?(%a*)$")
		if typeId and Config.PetsById[typeId] then
			local model = PetFactory.Build(typeId, flag == "g")
			model.Parent = folder
			local scale = Config.RaritiesByName[Config.PetsById[typeId].Rarity].Scale
			table.insert(entry.Pets, { Model = model, Scale = scale, CFrame = nil :: CFrame? })
		end
	end
	owners[player] = entry
end

local function watch(player: Player)
	rebuild(player)
	player:GetAttributeChangedSignal("EquippedPets"):Connect(function()
		rebuild(player)
	end)
end

function PetFollow.Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)

	local breakables = workspace:WaitForChild("World"):WaitForChild("Breakables")

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local alpha = math.min(1, dt * 8)
		for player, entry in owners do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local count = #entry.Pets
			local targetName = player:GetAttribute("Target")
			local target = targetName and targetName ~= "" and breakables:FindFirstChild(targetName) :: Model?
			local groundY = root.Position.Y - 3
			for index, pet in entry.Pets do
				local goal
				local half = pet.Scale / 2
				if target and target.PrimaryPart then
					local center = target.PrimaryPart.Position
					local radius = (target.PrimaryPart.Size.Magnitude / 2) + 2
					local angle = (index / count) * math.pi * 2 + now * 0.6
					local hop = math.abs(math.sin(now * 8 + index)) * 1.5
					local spot = Vector3.new(center.X + math.cos(angle) * radius, center.Y - target.PrimaryPart.Size.Y / 2 + half + hop, center.Z + math.sin(angle) * radius)
					goal = CFrame.lookAt(spot, Vector3.new(center.X, spot.Y, center.Z))
				else
					-- Halbkreis hinter dem Spieler
					local spread = if count > 1 then (index - 1) / (count - 1) - 0.5 else 0
					local offset = root.CFrame * CFrame.new(spread * 9, 0, 5 + math.abs(spread) * -2)
					local bob = math.sin(now * 4 + index) * 0.3
					local spot = Vector3.new(offset.Position.X, groundY + half + 0.3 + bob, offset.Position.Z)
					local look = root.CFrame.LookVector
					goal = CFrame.lookAt(spot, spot + Vector3.new(look.X, 0, look.Z))
				end
				local current = if pet.CFrame then pet.CFrame:Lerp(goal, alpha) else goal
				pet.CFrame = current
				pet.Model:PivotTo(current)
			end
		end
	end)
end

return PetFollow
