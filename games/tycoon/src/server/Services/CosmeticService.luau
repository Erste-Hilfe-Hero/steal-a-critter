-- Begleiter (Pets mit kleinem Bonus, folgen dem Spieler) und Garten-Designs (Boden- und Zaunfarbe).
-- Beides wird mit Muenzen gekauft, bleibt bei Rebirth erhalten und ist fuer alle sichtbar.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local CosmeticService = { Services = nil :: any }

local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)
local GOLD = Color3.fromRGB(255, 200, 40)
local PET_OFFSET = CFrame.new(2.4, 1.4, 1.6)

local lastAction = {} -- [Player] = os.clock()

function CosmeticService:Init(services)
	self.Services = services
end

local function getData(player: Player)
	local data = CosmeticService.Services.DataService:Get(player)
	local progress = CosmeticService.Services.ProgressService
	if data and progress then
		progress.Ensure(data)
	end
	return data
end

local function notify(player: Player, text: string, color: Color3?)
	CosmeticService.Services.Net.SendNotify(player, text, color)
end

local function ownsPet(player: Player, data, pet): boolean
	if pet.Pass then
		return player:GetAttribute("Pass_" .. pet.Pass) == true
	end
	return data.Pets[pet.Id] == true
end

local function markDirty(player: Player)
	local progress = CosmeticService.Services.ProgressService
	if progress then
		progress:MarkDirty(player)
	end
end

---------------------------------------------------------------- Pet-Modell

-- Kleines Tier aus Parts, an den HumanoidRootPart geschweisst (masselos, ohne Kollision)
local function buildPet(pet, root: BasePart): Model
	local model = Instance.new("Model")
	model.Name = "GardenPet"
	local makePart = CosmeticService.Services.WorldService.MakePart
	local function part(props)
		props.Anchored = false
		props.CanCollide = false
		props.CanQuery = false
		props.CanTouch = false
		props.Massless = true
		props.Parent = model
		return makePart(props)
	end
	local body = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (if pet.Id == "unicorn" then 1.8 else 1.3),
		Color = pet.Color,
		Material = if pet.Id == "dragonfly" or pet.Id == "unicorn" then Enum.Material.Neon else Enum.Material.SmoothPlastic,
	})
	local function attach(child: BasePart, offset: CFrame)
		child.CFrame = body.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = child
		weld.Parent = child
	end
	body.CFrame = root.CFrame * PET_OFFSET
	for _, side in { -1, 1 } do
		attach(part({ Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.28, Color = Color3.new(0, 0, 0) }), CFrame.new(side * 0.28, 0.2, -body.Size.Z * 0.42))
	end
	if pet.Id == "bee" or pet.Id == "butterfly" or pet.Id == "dragonfly" then
		for _, side in { -1, 1 } do
			attach(part({
				Name = "Wing",
				Size = Vector3.new(1.1, 0.08, 0.7),
				Color = if pet.Id == "butterfly" then Color3.fromRGB(255, 150, 230) else Color3.fromRGB(230, 245, 255),
				Transparency = 0.25,
			}), CFrame.new(side * 0.8, 0.35, 0.1) * CFrame.Angles(0, 0, math.rad(side * 20)))
		end
	end
	if pet.Id == "bee" then
		attach(part({ Name = "Stripe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.32, 1.32), Color = Color3.fromRGB(30, 30, 30) }), CFrame.new(0, 0, 0.15) * CFrame.Angles(0, math.rad(90), 0))
	elseif pet.Id == "ladybug" then
		for _, spot in { Vector3.new(0.3, 0.45, 0.1), Vector3.new(-0.3, 0.45, 0.2), Vector3.new(0, 0.5, -0.2) } do
			attach(part({ Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.3, Color = Color3.new(0, 0, 0) }), CFrame.new(spot))
		end
	elseif pet.Id == "snail" then
		attach(part({ Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Color = Color3.fromRGB(190, 120, 60) }), CFrame.new(0, 0.6, 0.4))
	elseif pet.Id == "unicorn" then
		attach(part({ Name = "Horn", Size = Vector3.new(0.25, 0.9, 0.25), Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.Neon }), CFrame.new(0, 0.9, -0.6) * CFrame.Angles(math.rad(-25), 0, 0))
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(255, 180, 255)
		sparkles.Parent = body
	end
	model.PrimaryPart = body
	local weld = Instance.new("Weld")
	weld.Name = "PetWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.C0 = PET_OFFSET
	weld.Parent = body
	return model
end

function CosmeticService:RefreshPet(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("GardenPet")
	if old then
		old:Destroy()
	end
	local data = getData(player)
	local pet = data and Config.PetsById[data.Pet]
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pet or not root or not ownsPet(player, data, pet) then
		return
	end
	local model = buildPet(pet, root)
	model:SetAttribute("OwnerUserId", player.UserId)
	CollectionService:AddTag(model, "GardenPet")
	model.Parent = character
end

function CosmeticService:EquipPet(player: Player, petId: string)
	local data = getData(player)
	local pet = Config.PetsById[petId]
	if not data or not pet or not ownsPet(player, data, pet) then
		return
	end
	data.Pet = petId
	player:SetAttribute("Pet", petId)
	self:RefreshPet(player)
	self.Services.GardenService:RefreshStats(player)
	markDirty(player)
end

-- Kaufen, ausruesten oder (wenn schon ausgeruestet) ablegen
function CosmeticService:BuyPet(player: Player, petId: string)
	local data = getData(player)
	local pet = Config.PetsById[petId]
	if not data or not pet then
		return
	end
	if ownsPet(player, data, pet) then
		if data.Pet == petId then
			data.Pet = ""
			player:SetAttribute("Pet", nil)
			self:RefreshPet(player)
			self.Services.GardenService:RefreshStats(player)
			markDirty(player)
			notify(player, `{pet.Name} is resting now.`, GOLD)
		else
			self:EquipPet(player, petId)
			notify(player, `{pet.Name} is following you: {pet.Text}!`, GREEN)
		end
		return
	end
	if pet.Pass then
		self.Services.MonetizationService:PromptPass(player, pet.Pass)
		return
	end
	if data.Coins < pet.Price then
		notify(player, `You need {Format.Cash(pet.Price)} for the {pet.Name}.`, RED)
		return
	end
	self.Services.DataService:AddCoins(player, -pet.Price)
	data.Pets[petId] = true
	self:EquipPet(player, petId)
	notify(player, `You adopted a {pet.Name}: {pet.Text}!`, GREEN)
	self.Services.Net.Effect:FireClient(player, "Reward", nil, pet.Name, pet.Color)
end

---------------------------------------------------------------- Garten-Designs

function CosmeticService:ApplySkin(plot, skinId: string)
	local skin = Config.SkinsById[skinId] or Config.Skins[1]
	for _, child in plot.Model:GetChildren() do
		if child:IsA("BasePart") then
			if child.Name == "Floor" then
				child.Color = skin.Floor
				child.Material = skin.FloorMaterial
			elseif child.Name:sub(1, 5) == "Fence" then
				child.Color = skin.Fence
			end
		end
	end
end

function CosmeticService:BuySkin(player: Player, skinId: string)
	local data = getData(player)
	local skin = Config.SkinsById[skinId]
	if not data or not skin then
		return
	end
	if not data.Skins[skinId] then
		if skin.Level then
			if data.Level < skin.Level then
				notify(player, `Reach gardener level {skin.Level} to unlock {skin.Name}.`, RED)
				return
			end
		elseif data.Coins < skin.Price then
			notify(player, `You need {Format.Cash(skin.Price)} for the {skin.Name} design.`, RED)
			return
		else
			self.Services.DataService:AddCoins(player, -skin.Price)
		end
		data.Skins[skinId] = true
		notify(player, `New garden design unlocked: {skin.Name}!`, GREEN)
	end
	data.Skin = skinId
	player:SetAttribute("Skin", skinId)
	local plot = self.Services.GardenService:GetPlot(player)
	if plot then
		self:ApplySkin(plot, skinId)
	end
	markDirty(player)
end

---------------------------------------------------------------- Lebenszyklus

function CosmeticService:OnPlayerReady(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	if data.Pet ~= "" then
		player:SetAttribute("Pet", data.Pet)
	end
	player:SetAttribute("Skin", data.Skin)
	local plot = self.Services.GardenService:GetPlot(player)
	if plot then
		self:ApplySkin(plot, data.Skin)
	end
end

function CosmeticService:OnCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	if player.Character == character then
		self:RefreshPet(player)
	end
end

function CosmeticService:OnPlayerRemoving(player: Player)
	lastAction[player] = nil
	-- Der freie Garten bekommt wieder das Standard-Design
	local plot = self.Services.GardenService:GetPlot(player)
	if plot then
		self:ApplySkin(plot, "classic")
	end
end

function CosmeticService:Start()
	local net = self.Services.Net
	local function allowed(player: Player): boolean
		if os.clock() - (lastAction[player] or 0) < 0.4 then
			return false
		end
		lastAction[player] = os.clock()
		return true
	end
	net.BuyPet.OnServerEvent:Connect(function(player, petId)
		if type(petId) == "string" and allowed(player) then
			self:BuyPet(player, petId)
		end
	end)
	net.BuySkin.OnServerEvent:Connect(function(player, skinId)
		if type(skinId) == "string" and allowed(player) then
			self:BuySkin(player, skinId)
		end
	end)
end

return CosmeticService
