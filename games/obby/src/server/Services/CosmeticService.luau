-- Trails, Namensschilder ueber dem Kopf und die Coil-Tools.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CosmeticService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)

local coilForces = {} -- [Player] = VectorForce

function CosmeticService:Init(services)
	self.Services = services
end

function CosmeticService:HasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function CosmeticService:IsTrailUnlocked(player: Player, trail): boolean
	local data = self.Services.DataService:Get(player)
	if not data then
		return false
	end
	return Config.TrailUnlocked(trail, data.BestStage, data.Wins, function(key)
		return self:HasPass(player, key)
	end)
end

---------------------------------------------------------------- Trail

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

local function applyTrail(player: Player, character: Model, trailId: string)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	local old = rootPart:FindFirstChild("ObbyTrail")
	if old then
		old:Destroy()
	end
	for _, name in { "TrailTop", "TrailBottom" } do
		local attachment = rootPart:FindFirstChild(name)
		if attachment then
			attachment:Destroy()
		end
	end
	local trail = Config.TrailsById[trailId]
	if not trail then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.8, 0)
	top.Parent = rootPart
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -0.9, 0)
	bottom.Parent = rootPart
	local effect = Instance.new("Trail")
	effect.Name = "ObbyTrail"
	effect.Attachment0 = top
	effect.Attachment1 = bottom
	effect.Color = colorSequence(trail.Colors)
	effect.Lifetime = 0.7
	effect.LightEmission = 0.5
	effect.Transparency = NumberSequence.new(0.1, 1)
	effect.FaceCamera = true
	effect.Parent = rootPart
end

---------------------------------------------------------------- Namensschild

local function gradient(colors: { Color3 }, name: string?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = colorSequence(colors)
	if name then
		g.Name = name
	end
	return g
end

local RAINBOW = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 230, 110), Color3.fromRGB(80, 160, 255), Color3.fromRGB(200, 90, 255) }
local GOLD = { Color3.fromRGB(255, 240, 140), Color3.fromRGB(255, 170, 0) }

local function textLabel(parent: Instance, name: string, y: number, height: number, font: Enum.Font, strokeThickness: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.Font = font
	label.TextScaled = true
	label.Text = ""
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = strokeThickness
	stroke.Color = Color3.fromRGB(20, 16, 34)
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function setGradient(label: TextLabel, colors: { Color3 }?)
	local old = label:FindFirstChild("Animated")
	if old then
		old:Destroy()
	end
	if colors then
		gradient(colors, "Animated").Parent = label
	end
end

-- Schild haengt am Charakter (nicht im Kopf) und folgt per Adornee, damit es einen Kopftausch beim Avatar-Laden uebersteht
local function ensureNameTag(character: Model): BillboardGui?
	local existing = character:FindFirstChild("NameTag")
	if existing then
		return existing :: BillboardGui
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(7, 2.1)
	gui.StudsOffset = Vector3.new(0, 2.7, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	textLabel(gui, "Rank", 0, 0.27, Enum.Font.GothamBlack, 1.5)
	textLabel(gui, "PlayerName", 0.27, 0.45, Enum.Font.FredokaOne, 2.5)
	textLabel(gui, "Progress", 0.74, 0.26, Enum.Font.GothamBold, 1.5)
	gui.Parent = character
	character.ChildAdded:Connect(function(child)
		if child.Name == "Head" and child:IsA("BasePart") then
			gui.Adornee = child
		end
	end)
	return gui
end

-- Texte im bestehenden Schild aktualisieren (kein Neuaufbau, kein Flackern)
function CosmeticService:UpdateNameTag(player: Player)
	local character = player.Character
	local gui = character and character:FindFirstChild("NameTag")
	if not gui then
		return
	end
	local rank = player:GetAttribute("Rank") or "Newbie"
	local rankColor = Color3.fromHex(tostring(player:GetAttribute("RankColor") or "#C8C8C8"))
	local isOwner = rank == "Owner"
	local isVip = self:HasPass(player, "VIP")

	-- Zeile 1: Rang (Owner = Regenbogen, den der Client dreht)
	local rankLabel = gui.Rank :: TextLabel
	rankLabel.Text = string.upper(rank)
	rankLabel.TextColor3 = if isOwner then Color3.new(1, 1, 1) else rankColor
	setGradient(rankLabel, if isOwner then RAINBOW else nil)

	-- Zeile 2: Name, VIP in Gold mit Krone, Premium mit Stern
	local name = player.DisplayName
	if isVip or isOwner then
		name = "👑 " .. name
	end
	if Config.PremiumBadge and player.MembershipType == Enum.MembershipType.Premium then
		name ..= " ⭐"
	end
	local nameLabel = gui.PlayerName :: TextLabel
	nameLabel.Text = name
	setGradient(nameLabel, if isOwner then RAINBOW elseif isVip then GOLD else nil)

	-- Zeile 3: Fortschritt
	local data = self.Services.DataService:Get(player)
	local stage = data and data.Stage or 1
	local world = Config.WorldForStage(stage)
	local wins = data and data.Wins or 0
	local progress = gui.Progress :: TextLabel
	progress.Text = `Stage {stage}  ·  {world.Name}` .. (if wins > 0 then `  ·  🏆 {wins}` else "")
	progress.TextColor3 = world.Accent:Lerp(Color3.new(1, 1, 1), 0.45)
end

---------------------------------------------------------------- Coils

local function makeCoil(name: string, color: Color3): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.ToolTip = name
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.8, 1.6, 0.8)
	handle.Color = color
	handle.Material = Enum.Material.Neon
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool
end

local function removeCoilForce(player: Player)
	local force = coilForces[player]
	coilForces[player] = nil
	if force then
		force:Destroy()
	end
end

function CosmeticService:GiveTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local function give(name: string, color: Color3, onEquip: (Model) -> (), onUnequip: (Model) -> ())
		if backpack:FindFirstChild(name) or (player.Character and player.Character:FindFirstChild(name)) then
			return
		end
		local tool = makeCoil(name, color)
		tool.Equipped:Connect(function()
			if player.Character then
				onEquip(player.Character)
			end
		end)
		tool.Unequipped:Connect(function()
			if player.Character then
				onUnequip(player.Character)
			end
		end)
		tool.Parent = backpack
	end

	if self:HasPass(player, "GravityCoil") then
		give("Gravity Coil", Color3.fromRGB(120, 160, 255), function(character)
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local attachment = rootPart and rootPart:FindFirstChild("RootAttachment") :: Attachment?
			if not rootPart or not attachment then
				return
			end
			removeCoilForce(player)
			-- Hebt einen Teil der Schwerkraft auf: hoehere und weitere Spruenge
			local force = Instance.new("VectorForce")
			force.Name = "GravityCoilForce"
			force.Attachment0 = attachment
			force.RelativeTo = Enum.ActuatorRelativeTo.World
			force.ApplyAtCenterOfMass = true
			force.Force = Vector3.new(0, rootPart.AssemblyMass * workspace.Gravity * (1 - Config.GravityCoilFactor), 0)
			force.Parent = rootPart
			coilForces[player] = force
		end, function()
			removeCoilForce(player)
		end)
	end
	if self:HasPass(player, "SpeedCoil") then
		give("Speed Coil", Color3.fromRGB(255, 90, 90), function(character)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = Config.SpeedCoilWalkSpeed
			end
		end, function(character)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = Config.DefaultWalkSpeed
			end
		end)
	end
end

---------------------------------------------------------------- Allgemein

-- Nach Kauf, Stage-Wechsel oder Rangaenderung alles neu anwenden
function CosmeticService:Refresh(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local trail = Config.TrailsById[data.Trail]
	if not trail or not self:IsTrailUnlocked(player, trail) then
		data.Trail = "white"
		self.Services.DataService:UpdateAttributes(player)
	end
	if player.Character then
		applyTrail(player, player.Character, data.Trail)
		ensureNameTag(player.Character)
		self:UpdateNameTag(player)
	end
	self:GiveTools(player)
end

function CosmeticService:OnCharacterAdded(player: Player, character: Model)
	removeCoilForce(player)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- Roblox tauscht beim Laden des Avatars Koerperteile aus: erst danach Trail und Schild anbringen
	if not player:HasAppearanceLoaded() then
		local loaded = false
		local connection = player.CharacterAppearanceLoaded:Connect(function()
			loaded = true
		end)
		local deadline = os.clock() + 10
		while not loaded and os.clock() < deadline and character.Parent do
			task.wait(0.1)
		end
		connection:Disconnect()
	end
	character:WaitForChild("Head", 10)
	character:WaitForChild("HumanoidRootPart", 10)
	if player.Character ~= character then
		return
	end
	self:Refresh(player)
end

function CosmeticService:OnPlayerRemoving(player: Player)
	removeCoilForce(player)
end

function CosmeticService:Start()
	self.Services.Net.EquipTrail.OnServerEvent:Connect(function(player, trailId)
		local data = self.Services.DataService:Get(player)
		local trail = typeof(trailId) == "string" and Config.TrailsById[trailId]
		if not data or not trail then
			return
		end
		if not self:IsTrailUnlocked(player, trail) then
			self.Services.Net.SendNotify(player, "This trail is locked.", RED)
			return
		end
		data.Trail = trail.Id
		self.Services.DataService:UpdateAttributes(player)
		if player.Character then
			applyTrail(player, player.Character, trail.Id)
		end
		self.Services.Net.SendNotify(player, `{trail.Name} trail equipped!`, GREEN)
	end)

	-- Rang aendert sich -> Namensschild neu
	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("Rank"):Connect(function()
			self:UpdateNameTag(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player:GetAttributeChangedSignal("Rank"):Connect(function()
			self:UpdateNameTag(player)
		end)
	end
end

return CosmeticService
