-- Aussehen und Community: Skier an den Fuessen, Trails, Namensschild mit Rang, Shop fuer Schneeflocken,
-- Tagesbelohnung, Spielzeit-Belohnung und die klassischen Surf-Chatbefehle.
-- Chat: /r (neuer Lauf), /s (Stage neu), /lobby, /cp (Checkpoint speichern), /tele (Checkpoint laden)
-- Update 2: Buddies (kleine Begleiter an der Schulter) und Titel auf dem Namensschild.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)

local CosmeticService = { Services = nil :: any }

local THEME = Config.Theme

function CosmeticService:Init(services)
	self.Services = services
end

local function listFor(data, kind: string)
	return if kind == "Trail" then data.Trails elseif kind == "Ski" then data.Skis else data.Buddies
end

local function owns(data, kind: string, item): boolean
	local list = listFor(data, kind)
	return list[item.Id] == true or (item.Pass ~= nil and data.Passes[item.Pass] == true) or (item.Price == 0 and item.Pass == nil and not item.Spin)
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

-- Kleiner Begleiter aus Teilen, an die Schulter geschweisst (folgt so der vom Client bewegten Figur)
local function buddyPart(model: Model, base: CFrame, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = base * offset
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function buildBuddy(model: Model, base: CFrame, id: string)
	local BALL, BLOCK, CYL = Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder
	local black = Color3.fromRGB(25, 25, 30)
	local orange = Color3.fromRGB(255, 150, 40)
	local function add(shape, size, offset, color, material: Enum.Material?)
		return buddyPart(model, base, shape, size, offset, color, material)
	end
	if id == "snowman" then
		add(BALL, Vector3.one * 1.3, CFrame.new(0, -0.7, 0), THEME.Snow, Enum.Material.Snow)
		add(BALL, Vector3.one * 0.95, CFrame.new(0, 0.3, 0), THEME.Snow, Enum.Material.Snow)
		for _, x in { -0.17, 0.17 } do
			add(BALL, Vector3.one * 0.14, CFrame.new(x, 0.42, -0.42), black)
		end
		add(CYL, Vector3.new(0.4, 0.12, 0.12), CFrame.new(0, 0.3, -0.6) * CFrame.Angles(0, math.rad(90), 0), orange)
		add(CYL, Vector3.new(0.12, 0.8, 0.8), CFrame.new(0, 0.82, 0) * CFrame.Angles(0, 0, math.rad(90)), black)
	elseif id == "penguin" then
		add(BALL, Vector3.new(1.1, 1.6, 1.1), CFrame.new(0, -0.3, 0), black)
		add(BALL, Vector3.new(0.8, 1.2, 0.5), CFrame.new(0, -0.35, -0.32), THEME.Snow)
		add(BALL, Vector3.one * 0.9, CFrame.new(0, 0.6, 0), black)
		for _, x in { -0.18, 0.18 } do
			add(BALL, Vector3.one * 0.18, CFrame.new(x, 0.68, -0.36), THEME.Snow)
		end
		add(BLOCK, Vector3.new(0.22, 0.12, 0.3), CFrame.new(0, 0.52, -0.5), orange)
	elseif id == "fox" then
		local fur = Color3.fromRGB(235, 240, 250)
		add(BLOCK, Vector3.new(0.8, 0.7, 1.3), CFrame.new(0, -0.4, 0.1), fur)
		add(BLOCK, Vector3.new(0.75, 0.7, 0.7), CFrame.new(0, 0.2, -0.55), fur)
		add(BLOCK, Vector3.new(0.35, 0.3, 0.35), CFrame.new(0, 0.08, -1.0), fur)
		add(BALL, Vector3.one * 0.13, CFrame.new(0, 0.12, -1.18), black)
		for _, x in { -0.22, 0.22 } do
			add(BLOCK, Vector3.new(0.2, 0.4, 0.12), CFrame.new(x, 0.7, -0.5), fur)
			add(BALL, Vector3.one * 0.12, CFrame.new(x * 0.8, 0.32, -0.9), black)
		end
		add(BLOCK, Vector3.new(0.4, 0.4, 1.0), CFrame.new(0, -0.2, 1.1) * CFrame.Angles(math.rad(25), 0, 0), fur)
	elseif id == "orb" then
		local orb = add(BALL, Vector3.one * 1.1, CFrame.identity, THEME.Aurora, Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = THEME.Aurora
		light.Range = 10
		light.Brightness = 1.5
		light.Parent = orb
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Rate = 8
		sparkles.Lifetime = NumberRange.new(0.6, 1)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.Size = NumberSequence.new(0.35, 0)
		sparkles.Color = ColorSequence.new(THEME.Aurora, THEME.Ice)
		sparkles.LightEmission = 1
		sparkles.Parent = orb
	elseif id == "owl" then
		local white = Color3.fromRGB(250, 250, 255)
		add(BALL, Vector3.new(1.1, 1.4, 1.0), CFrame.new(0, -0.3, 0), white)
		add(BALL, Vector3.one * 1.0, CFrame.new(0, 0.55, 0), white)
		for _, x in { -0.22, 0.22 } do
			add(BALL, Vector3.one * 0.3, CFrame.new(x, 0.6, -0.4), THEME.Gold)
			add(BALL, Vector3.one * 0.14, CFrame.new(x, 0.6, -0.54), black)
			add(BLOCK, Vector3.new(0.14, 0.3, 0.14), CFrame.new(x * 1.3, 1.05, 0), white)
		end
		add(BLOCK, Vector3.new(0.12, 0.2, 0.15), CFrame.new(0, 0.42, -0.52), orange)
	end
end

local function makeBuddy(character: Model, buddy)
	local old = character:FindFirstChild("Buddy")
	if old then
		old:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or buddy.Id == "none" then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Buddy"
	-- schwebt rechts hinter der Schulter
	buildBuddy(model, root.CFrame * CFrame.new(2.4, 1.6, 1.2), buddy.Id)
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			p.CollisionGroup = "Surfers"
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	model.Parent = character
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
	local achievement = data and Progression.AchievementsById[data.Title]
	local titleText = if achievement and data.Achievements[data.Title] then achievement.Name else nil
	local top = if titleText then 18 else 0

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(220, 52 + top)
	gui.StudsOffset = Vector3.new(0, if titleText then 3.3 else 2.8, 0)
	gui.MaxDistance = 110
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Adornee = head
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromOffset(0, top)
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
	rankLabel.Position = UDim2.fromOffset(0, 28 + top)
	rankLabel.Size = UDim2.new(1, 0, 0, 20)
	rankLabel.BackgroundTransparency = 1
	rankLabel.Text = if isOwner then "[ OWNER ]" else `[ {string.upper(rank.Name)} ]`
	rankLabel.TextColor3 = if isOwner then THEME.Aurora else rank.Color
	rankLabel.TextScaled = true
	rankLabel.FontFace = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
	rankLabel.Parent = gui
	local stroke2 = stroke:Clone()
	stroke2.Parent = rankLabel
	if titleText then
		-- Titel aus einem Erfolg (Update 2)
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, 0, 0, 18)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = titleText
		titleLabel.TextColor3 = THEME.Mint
		titleLabel.TextScaled = true
		titleLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Italic)
		titleLabel.Parent = gui
		stroke:Clone().Parent = titleLabel
	end
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
	local buddy = Progression.BuddiesById[data.Buddy]
	if not buddy or not owns(data, "Buddy", buddy) then
		buddy = Progression.BuddiesById.none
		data.Buddy = "none"
	end
	makeTrail(character, trail)
	makeSkis(character, ski)
	makeBuddy(character, buddy)
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
	-- Pollen mit Zeitlimit statt :Wait(): das Ereignis kann schon vorbei sein, dann wurde ewig gewartet
	local deadline = os.clock() + 10
	while not player:HasAppearanceLoaded() and player.Parent and player.Character == character and os.clock() < deadline do
		task.wait(0.1)
	end
	if player.Character == character then
		self:Refresh(player)
	end
end

---------------------------------------------------------------- Shop

local function handleShop(player: Player, action: any, kind: any, id: any)
	local services = CosmeticService.Services
	local data = services.DataService:Get(player)
	if not data or (kind ~= "Trail" and kind ~= "Ski" and kind ~= "Buddy") or typeof(id) ~= "string" then
		return
	end
	local item = if kind == "Trail" then Config.TrailsById[id] elseif kind == "Ski" then Config.SkisById[id] else Progression.BuddiesById[id]
	if not item then
		return
	end
	if action == "Buy" and not owns(data, kind, item) then
		if item.Pass then
			services.MonetizationService:Prompt(player, if item.Pass == "StarterPack" then "Product" else "Pass", item.Pass)
			return
		end
		if item.Spin then
			services.Net.SendNotify(player, `{item.Name} can only be won from the Lucky Snowball!`, THEME.Aurora)
			return
		end
		if data.Flakes < item.Price then
			services.Net.SendNotify(player, `You need {Format.Number(item.Price - data.Flakes)} more Snowflakes.`, THEME.Red)
			player:SetAttribute("ShowOffer", "Flakes")
			return
		end
		data.Flakes -= item.Price
		listFor(data, kind)[id] = true
		services.Net.SendNotify(player, `Unlocked {item.Name}!`, THEME.Mint)
		if kind == "Buddy" then
			services.ProgressService:Evaluate(player)
		end
	end
	if owns(data, kind, item) then
		if kind == "Trail" then
			data.Trail = id
		elseif kind == "Ski" then
			data.Ski = id
		else
			data.Buddy = id
		end
		CosmeticService:Refresh(player)
		-- Auch ohne Charakter (z. B. gerade beim Respawn) die Anzeige im Shop aktualisieren
		services.DataService:UpdateAttributes(player)
	end
end

---------------------------------------------------------------- Belohnungen

local function today(): number
	return os.time() // 86400
end

-- Tagesbelohnung anbieten (auch wenn man ueber Mitternacht UTC hinweg im Spiel bleibt)
local function offerDaily(player: Player, data)
	if data.DailyDay < today() and player:GetAttribute("DailyReward") == nil then
		local streak = if data.DailyDay == today() - 1 then data.DailyStreak % 7 + 1 else 1
		player:SetAttribute("DailyStreak", streak)
		player:SetAttribute("DailyReward", Config.DailyReward(streak))
	end
end

function CosmeticService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	offerDaily(player, data)
	local index, rank = Config.RankFor(data.Clears)
	player:SetAttribute("RankIndex", index)
	player:SetAttribute("RankName", rank.Name)
	player:GetAttributeChangedSignal("Clears"):Connect(function()
		local newIndex = Config.RankFor(player:GetAttribute("Clears") or 0)
		if newIndex ~= player:GetAttribute("RankIndex") then
			local _, newRank = Config.RankFor(player:GetAttribute("Clears") or 0)
			-- Rang sofort merken: Refresh bricht ohne Charakter ab, sonst kaeme die Ansage bei jedem Abschluss neu
			player:SetAttribute("RankIndex", newIndex)
			player:SetAttribute("RankName", newRank.Name)
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
	services.ProgressService:Evaluate(player)
	services.ProgressService:MarkDirty(player)
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
					services.ProgressService:OnMinute(player)
					offerDaily(player, data)
				end
			end
		end
	end)
end

return CosmeticService
