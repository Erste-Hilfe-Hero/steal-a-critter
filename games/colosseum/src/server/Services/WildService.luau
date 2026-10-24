-- Wilde Bestien in den Zonen: erscheinen, laufen herum, starten per Prompt einen Kampf.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local BeastModel = require(ReplicatedStorage.Shared.BeastModel)

local WildService = { Services = nil :: any }

local folder = Instance.new("Folder")
folder.Name = "Wild"
folder.Parent = workspace

local random = Random.new()
local entities = {} -- [Entity] = true

function WildService:Init(services)
	self.Services = services
end

local function pickBeast(zone): string
	local total = 0
	for _, spawn in zone.Spawns do
		total += spawn.Weight
	end
	local roll = random:NextNumber() * total
	for _, spawn in zone.Spawns do
		roll -= spawn.Weight
		if roll <= 0 then
			return spawn.Beast
		end
	end
	return zone.Spawns[1].Beast
end

local function randomPoint(zone): Vector3
	local angle = random:NextNumber() * math.pi * 2
	local distance = math.sqrt(random:NextNumber()) * (zone.Radius - 14)
	return zone.Center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

local function buildModel(entity)
	if entity.Model then
		entity.Model:Destroy()
	end
	local model = BeastModel.Build(entity.Beast, entity.Level, entity.Shiny)
	local scale = BeastModel.Scale(entity.Beast, entity.Level)
	entity.Hover = BeastModel.Hover(entity.Beast, scale)
	model:PivotTo(CFrame.new(entity.Position + Vector3.new(0, entity.Hover, 0)) * CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0))
	BeastModel.AddLabel(model, entity.Beast, entity.Level, entity.Shiny)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BattlePrompt"
	prompt.ActionText = "Battle!"
	prompt.ObjectText = `Lv {entity.Level} {Config.BeastsById[entity.Beast].Name}`
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom -- eigenes Aussehen im Client
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		WildService.Services.BattleService:StartWild(player, entity)
	end)
	model:SetAttribute("Wild", true)
	model.Parent = folder
	entity.Model = model
	entity.Prompt = prompt
end

local function spawnEntity(zoneIndex: number)
	local zone = Config.Zones[zoneIndex]
	local beast = pickBeast(zone)
	local level = random:NextInteger(zone.Levels[1], zone.Levels[2])
	local shinyChance = Config.ShinyChance * WildService.Services.MonetizationService:ServerShinyMultiplier()
	local entity = {
		Zone = zoneIndex,
		Beast = beast,
		Level = level,
		Shiny = random:NextNumber() < shinyChance,
		Position = randomPoint(zone),
		Busy = false,
	}
	buildModel(entity)
	entities[entity] = true
	local rarity = Config.RaritiesByName[Config.BeastsById[beast].Rarity]
	if rarity.Announce then
		WildService.Services.Net.SendAnnounce(`A wild {Config.BeastsById[beast].Name} appeared in {zone.Name}!`, rarity.Color)
	elseif entity.Shiny then
		WildService.Services.Net.SendAnnounce(`A PRISMATIC {Config.BeastsById[beast].Name} appeared in {zone.Name}!`, Color3.fromRGB(150, 255, 245))
	end
	return entity
end

-- Fuer einen Kampf reservieren: steht still, Prompt aus.
-- Prismatic Hunter: eigene Zusatzchance, dass die Bestie fuer diesen Spieler prismatisch ist.
function WildService:Reserve(entity, player: Player)
	entity.Busy = true
	entity.Prompt.Enabled = false
	if entity.Tween then
		entity.Tween:Cancel()
	end
	local monetization = self.Services.MonetizationService
	if not entity.Shiny then
		local extra = monetization:PlayerShinyMultiplier(player) - 1
		if extra > 0 and random:NextNumber() < Config.ShinyChance * monetization:ServerShinyMultiplier() * extra then
			entity.Shiny = true
			entity.Position = entity.Model:GetPivot().Position - Vector3.new(0, entity.Hover, 0)
			buildModel(entity)
			entity.Prompt.Enabled = false
			self.Services.Net.SendNotify(player, "Whoa! It's a PRISMATIC beast!", Color3.fromRGB(150, 255, 245))
		end
	end
end

-- Nach dem Kampf: "Gone" (gefangen/besiegt) oder "Free" (Spieler geflohen/verloren)
function WildService:Release(entity, outcome: string)
	if outcome == "Gone" then
		entities[entity] = nil
		local model = entity.Model
		task.delay(1.2, function()
			model:Destroy()
		end)
		task.delay(Config.WildRespawn, spawnEntity, entity.Zone)
	else
		entity.Busy = false
		if entity.Model.Parent then
			entity.Prompt.Enabled = true
			entity.Position = entity.Model:GetPivot().Position - Vector3.new(0, entity.Hover, 0)
		end
	end
end

-- Herumlaufen: kleine Schritte innerhalb der Zone
local function wander(entity)
	if entity.Busy or not entity.Model.Parent then
		return
	end
	local zone = Config.Zones[entity.Zone]
	local offset = Vector3.new(random:NextNumber(-14, 14), 0, random:NextNumber(-14, 14))
	local target = entity.Position + offset
	local flat = target - zone.Center
	if flat.Magnitude > zone.Radius - 14 then
		target = zone.Center + flat.Unit * (zone.Radius - 16)
	end
	local distance = (target - entity.Position).Magnitude
	if distance < 1 then
		return
	end
	local root = entity.Model.PrimaryPart
	local goal = CFrame.lookAt(target, target + (target - entity.Position)) + Vector3.new(0, entity.Hover, 0)
	local tween = TweenService:Create(root, TweenInfo.new(distance / 6, Enum.EasingStyle.Linear), { CFrame = goal })
	root.CFrame = CFrame.lookAt(root.Position, root.Position + (target - entity.Position))
	entity.Tween = tween
	entity.Position = target
	tween:Play()
end

function WildService:Start()
	for index in Config.Zones do
		for _ = 1, Config.WildPerZone do
			spawnEntity(index)
		end
	end
	task.spawn(function()
		while true do
			task.wait(1.5)
			for entity in entities do
				if random:NextNumber() < 0.3 then
					wander(entity)
				end
			end
		end
	end)
end

return WildService
