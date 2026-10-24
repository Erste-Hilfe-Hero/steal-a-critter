-- Aussehen und Community: Skier an den Fuessen, Trails, Namensschild mit Rang, Shop fuer Schneeflocken,
-- Tagesbelohnung, Spielzeit-Belohnung und die klassischen Surf-Chatbefehle.
-- Chat: /r (neuer Lauf), /s (Stage neu), /lobby, /cp (Checkpoint speichern), /tele (Checkpoint laden)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local CosmeticService = { Services = nil :: any }

local THEME = Config.Theme

function CosmeticService:Init(services)
	self.Services = services
end

local function owns(data, kind: string, item): boolean
	local list = if kind == "Trail" then data.Trails else data.Skis
	return list[item.Id] == true or (item.Pass ~= nil and data.Passes[item.Pass] == true) or (item.Price == 0 and item.Pass == nil)
end

---------------------------------------------------------------- Charakter

-- Spieler sollen die Box-Casts der anderen nicht stoeren (Kollisionsgruppe setzt der Client selbst)
local function hideFromQueries(instance: Instance)
	if instance:IsA("BasePart") then
		instance.CanQuery = false
		instance.CanTouch = false
	end
end

local function makeSkis(character: Model, ski)
	local old = character:FindFirstChild("Skis")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Skis"
	for _, footName in { { "LeftFoot", "Left Leg" }, { "RightFoot", "Right Leg" } } do
		local foot = (character:FindFirstChild(footName[1]) or character:FindFirstChild(footName[2])) :: BasePart?
		if foot then
			local base = foot.CFrame * CFrame.new(0, -foot.Size.Y / 2 - 0.08, -0.5)
			local board = Instance.new("Part")
			board.Name = "Ski"
			board.Size = Vector3.new(0.55, 0.14, 5.2)
			board.CFrame = base
			local tip = Instance.new("Part")
			tip.Name = "Tip"
			tip.Size = Vector3.new(0.55, 0.14, 1)
			tip.CFrame = base * CFrame.new(0, 0.18, -2.95) * CFrame.Angles(math.rad(30), 0, 0)
			for _, p in { board, tip } do
				p.Color = ski.Color
				p.Material = ski.Material or Enum.Material.SmoothPlastic
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.Massless = true
				p.CollisionGroup = "Surfers"
				p.TopSurface = Enum.SurfaceType.Smooth
				p.BottomSurface = Enum.SurfaceType.Smooth
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = foot
				weld.Part1 = p
				weld.Parent = p
				p.Parent = folder
			end
		end
	end
	folder.Parent = character
end

local function makeTrail(character: Model, trail)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for _, name in { "SurfTrail", "TrailTop", "TrailBottom" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	if trail.Id == "none" then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, -1.2, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -2.7, 0.4)
	bottom.Parent = root
	local effect = Instance.new("Trail")
	effect.Name = "SurfTrail"
	effect.Attachment0 = top
	effect.Attachment1 = bottom
	effect.Lifetime = 0.9
	effect.MinLength = 0.2
	effect.LightEmission = 0.7
	effect.FaceCamera = true
	effect.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	local keys = {}
	for i, color in trail.Colors do
		table.insert(keys, ColorSequenceKeypoint.new(if #trail.Colors == 1 then 0 else (i - 1) / (#trail.Colors - 1), color))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, trail.Colors[1]))
	end
	effect.Color = ColorSequence.new(keys)
	effect.Parent = root
end

local function nameplate(player: Player, character: Model)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local old = head:FindFirstChild("Nameplate")
	if old then
		old:Destroy()
	end
	local data = CosmeticService.Services.DataService:Get(player)
	local _, rank = Config.RankFor(data and data.Clears or 0)
	local vip = data and data.Passes.VIP
	local isOwner = table.find(Config.OwnerUserIds, player.UserId) ~= nil

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(220, 52)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 110
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Adornee = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0, 28)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = (if vip then "VIP  " else "") .. player.DisplayName
	nameLabel.TextColor3 = if vip then THEME.Gold else THEME.Snow
	nameLabel.TextScaled = true
	nameLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	nameLabel.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Navy
	stroke.Thickness = 2
	stroke.Parent = nameLabel
	local rankLabel = Instance.new("TextLabel")
	rankLabel.Position = UDim2.fromOffset(0, 28)
	rankLabel.Size = UDim2.new(1, 0, 0, 20)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = if isOwner then "[ OWNER ]" else `[ {string.upper(rank.Name)} ]`
	rankLabel.TextColor3 = if isOwner then THEME.Aurora else rank.Color
	rankLabel.TextScaled = true
	rankLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	rankLabel.Parent = gui
	local stroke2 = stroke:Clone()
	stroke2.Parent = rankLabel
	gui.Parent = head
end

function CosmeticService:Refresh(player: Player)
	local data = self.Services.DataService:Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	local trail = Config.TrailsById[data.Trail]
	if not trail or not owns(data, "Trail", trail) then
		trail = Config.TrailsById.frost
		data.Trail = "frost"
	end
	local ski = Config.SkisById[data.Ski]
	if not ski or not owns(data, "Ski", ski) then
		ski = Config.SkisById.classic
		data.Ski = "classic"
	end
	makeTrail(character, trail)
	makeSkis(character, ski)
	task.spawn(nameplate, player, character)
	local index, rank = Config.RankFor(data.Clears)
	player:SetAttribute("RankIndex", index)
	player:SetAttribute("RankName", rank.Name)
	self.Services.DataService:UpdateAttributes(player)
end

function CosmeticService:OnCharacterAdded(player: Player, character: Model)
	for _, descendant in character:GetDescendants() do
		hideFromQueries(descendant)
	end
	character.DescendantAdded:Connect(hideFromQueries)
	-- Warten, bis das Aussehen geladen ist, sonst haengen Skier an alten Fuessen
	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
	if player.Character == character then
		self:Refresh(player)
	end
end

---------------------------------------------------------------- Shop

local function handleShop(player: Player, action: any, kind: any, id: any)
	local services = CosmeticService.Services
	local data = services.DataService:Get(player)
	if not data or (kind ~= "Trail" and kind ~= "Ski") or typeof(id) ~= "string" then
		return
	end
	local item = if kind == "Trail" then Config.TrailsById[id] else Config.SkisById[id]
	if not item then
		return
	end
	if action == "Buy" and not owns(data, kind, item) then
		if item.Pass then
			services.MonetizationService:Prompt(player, if item.Pass == "StarterPack" then "Product" else "Pass", item.Pass)
			return
		end
		if data.Flakes < item.Price then
			services.Net.SendNotify(player, `You need {Format.Number(item.Price - data.Flakes)} more Snowflakes.`, THEME.Red)
			player:SetAttribute("ShowOffer", "Flakes")
			return
		end
		data.Flakes -= item.Price
		local list = if kind == "Trail" then data.Trails else data.Skis
		list[id] = true
		services.Net.SendNotify(player, `Unlocked {item.Name}!`, THEME.Mint)
	end
	if owns(data, kind, item) then
		if kind == "Trail" then
			data.Trail = id
		else
			data.Ski = id
		end
		CosmeticService:Refresh(player)
	end
end

---------------------------------------------------------------- Belohnungen

local function today(): number
	return os.time() // 86400
end

function CosmeticService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if data.DailyDay < today() then
		local streak = if data.DailyDay == today() - 1 then data.DailyStreak % 7 + 1 else 1
		player:SetAttribute("DailyStreak", streak)
		player:SetAttribute("DailyReward", Config.DailyReward(streak))
	end
	local index, rank = Config.RankFor(data.Clears)
	player:SetAttribute("RankIndex", index)
	player:SetAttribute("RankName", rank.Name)
	player:GetAttributeChangedSignal("Clears"):Connect(function()
		local newIndex = Config.RankFor(player:GetAttribute("Clears") or 0)
		if newIndex ~= player:GetAttribute("RankIndex") then
			local _, newRank = Config.RankFor(player:GetAttribute("Clears") or 0)
			self.Services.Net.SendAnnounce(`{player.DisplayName} ranked up to {string.upper(newRank.Name)}!`, newRank.Color)
			self:Refresh(player)
		end
	end)
end

local function claimDaily(player: Player)
	local services = CosmeticService.Services
	local data = services.DataService:Get(player)
	local reward = player:GetAttribute("DailyReward")
	if not data or not reward or data.DailyDay >= today() then
		return
	end
	data.DailyStreak = player:GetAttribute("DailyStreak") or 1
	data.DailyDay = today()
	player:SetAttribute("DailyReward", nil)
	local amount = services.DataService:AddFlakes(player, reward)
	services.Net.SendNotify(player, `Day {data.DailyStreak} reward: +{Format.Number(amount)} Snowflakes!`, THEME.Gold)
end

---------------------------------------------------------------- Chatbefehle

local function command(alias: string, second: string?, handler: (Player) -> ())
	local cmd = Instance.new("TextChatCommand")
	cmd.Name = "Surf_" .. alias
	cmd.PrimaryAlias = "/" .. alias
	if second then
		cmd.SecondaryAlias = "/" .. second
	end
	cmd.Triggered:Connect(function(source)
		local player = Players:GetPlayerByUserId(source.UserId)
		if player then
			handler(player)
		end
	end)
	cmd.Parent = TextChatService
end

function CosmeticService:Start()
	local services = self.Services
	services.Net.Shop.OnServerEvent:Connect(handleShop)
	services.Net.ClaimDaily.OnServerEvent:Connect(claimDaily)

	command("r", "restart", function(player)
		services.TimerService:Begin(player, 1, true)
	end)
	command("s", "stage", function(player)
		services.TimerService:RestartStage(player)
	end)
	command("lobby", "spawn", function(player)
		services.TimerService:ToLobby(player)
	end)
	command("cp", "save", function(player)
		services.Net.Checkpoint:FireClient(player, "Save")
	end)
	command("tele", "load", function(player)
		services.Net.Checkpoint:FireClient(player, "Load")
	end)

	-- Schneeflocken fuer aktive Spielzeit
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = services.DataService:Get(player)
				if data then
					data.PlayTime += 60
					services.DataService:AddFlakes(player, Config.Rewards.PerMinute)
				end
			end
		end
	end)
end

return CosmeticService
