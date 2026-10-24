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

local function textLabel(parent: Instance, text: string, y: number, height: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.Text = text
	label.TextColor3 = color
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = parent
	return label
end

function CosmeticService:UpdateNameTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	local old = head:FindFirstChild("NameTag")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(220, 72)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0

	local rank = player:GetAttribute("Rank") or "Newbie"
	local rankColor = Color3.fromHex(tostring(player:GetAttribute("RankColor") or "#C8C8C8"))
	local isOwner = rank == "Owner"
	local isVip = self:HasPass(player, "VIP")

	-- Zeile 1: Rang (Owner = animierter Regenbogen, den der Client dreht)
	local rankLabel = textLabel(gui, `[{string.upper(rank)}]`, 0, 0.3, if isOwner then Color3.new(1, 1, 1) else rankColor)
	if isOwner then
		gradient({ Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 230, 110), Color3.fromRGB(80, 160, 255), Color3.fromRGB(200, 90, 255) }, "Animated").Parent = rankLabel
	end

	-- Zeile 2: Name, VIP in Gold mit Krone, Premium mit Abzeichen
	local name = player.DisplayName
	if isVip then
		name = "👑 " .. name
	end
	if Config.PremiumBadge and player.MembershipType == Enum.MembershipType.Premium then
		name ..= " ⭐"
	end
	local nameLabel = textLabel(gui, name, 0.28, 0.42, Color3.new(1, 1, 1))
	if isOwner then
		gradient({ Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 160, 255) }, "Animated").Parent = nameLabel
	elseif isVip then
		gradient({ Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 170, 0) }, "Animated").Parent = nameLabel
	end

	-- Zeile 3: Fortschritt
	local data = self.Services.DataService:Get(player)
	local world = Config.WorldForStage(data and data.Stage or 1)
	local wins = data and data.Wins or 0
	textLabel(gui, `Stage {data and data.Stage or 1} · {world.Name}` .. (if wins > 0 then ` · 🏆{wins}` else ""), 0.72, 0.26, Color3.fromRGB(230, 230, 240))

	gui.Parent = head
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
		self:UpdateNameTag(player)
	end
	self:GiveTools(player)
end

function CosmeticService:OnCharacterAdded(player: Player, character: Model)
	removeCoilForce(player)
	character:WaitForChild("Head")
	character:WaitForChild("HumanoidRootPart")
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
