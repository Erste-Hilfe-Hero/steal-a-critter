-- Das komplette HUD per Code: Heldenwahl, Lebensbalken, Faehigkeiten, Minimap, Item-Shop, Store,
-- Anzeigetafel, Todes- und Ergebnisbildschirm, Meldungen. Stil: dunkles Tintenblau mit Gold und Violett.
local AdService = game:GetService("AdService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Bars = require(script.Parent.Bars)
local CameraController = require(script.Parent.CameraController)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local match = ReplicatedStorage:WaitForChild("Match")

local UI = {}

---------------------------------------------------------------- Stil

local INK = Color3.fromRGB(14, 18, 34)
local INK2 = Color3.fromRGB(28, 34, 58)
local INK3 = Color3.fromRGB(44, 52, 84)
local TEXT = Color3.fromRGB(246, 241, 232)
local MUTED = Color3.fromRGB(160, 168, 190)
local GOLD = Color3.fromRGB(255, 201, 74)
local CRYSTAL = Color3.fromRGB(120, 220, 255)
local GREEN = Color3.fromRGB(110, 231, 160)
local RED = Color3.fromRGB(255, 107, 107)
local ROBUX = Color3.fromRGB(64, 200, 110)
local TITLE = Enum.Font.LuckiestGuy
local BODY = Enum.Font.BuilderSansExtraBold
local SMALL = Enum.Font.BuilderSansBold

local function create(className: string, props, children: { Instance }?)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function round()
	return create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function line(transparency: number?, color: Color3?, thickness: number?)
	return create("UIStroke", { Color = color or Color3.new(1, 1, 1), Transparency = transparency or 0.82, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or BODY
	props.TextColor3 = props.TextColor3 or TEXT
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local children = props.Children or {}
	props.Children = nil
	if props.Outline then
		table.insert(children, create("UIStroke", { Thickness = props.Outline, Color = Color3.fromRGB(10, 10, 20) }))
	end
	props.Outline = nil
	return create("TextLabel", props, children) :: TextLabel
end

local function panel(props): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or INK
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	local children = props.Children or {}
	props.Children = nil
	table.insert(children, corner(props.Radius or 14))
	table.insert(children, line(0.85))
	table.insert(children, create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 215)) }))
	props.Radius = nil
	return create("Frame", props, children) :: Frame
end

local STYLES = {
	Gold = { Back = GOLD, Text = Color3.fromRGB(40, 26, 6) },
	Dark = { Back = INK3, Text = TEXT },
	Robux = { Back = ROBUX, Text = Color3.fromRGB(8, 34, 16) },
	Crystal = { Back = CRYSTAL, Text = Color3.fromRGB(8, 30, 44) },
	Red = { Back = RED, Text = Color3.fromRGB(50, 10, 10) },
}

local function button(props, style: string?): TextButton
	local s = STYLES[style or "Dark"]
	props.BackgroundColor3 = props.BackgroundColor3 or s.Back
	props.TextColor3 = props.TextColor3 or s.Text
	props.Font = props.Font or BODY
	props.TextScaled = true
	props.AutoButtonColor = true
	local scale = create("UIScale", {})
	local children = props.Children or {}
	props.Children = nil
	table.insert(children, corner(props.Radius or 10))
	table.insert(children, scale)
	table.insert(children, create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }))
	table.insert(children, create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }))
	table.insert(children, create("UITextSizeConstraint", { MaxTextSize = props.MaxText or 22 }))
	props.Radius = nil
	props.MaxText = nil
	local result = create("TextButton", props, children) :: TextButton
	result.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	result.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	result.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	return result
end

local function teamColor(team: number?): Color3
	local info = Config.Teams[team or 0]
	return if info then info.Color else Config.NeutralColor
end

local function buyProduct(key: string)
	local product = Config.Products[key]
	if not product then
		return
	end
	if product.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, product.Id)
	elseif RunService:IsStudio() then
		remotes.FakePurchase:FireServer(key)
	end
end

local function owned(list: string?, id: string): boolean
	return table.find(string.split(list or "", ","), id) ~= nil
end

local function now(): number
	return workspace:GetServerTimeNow()
end

local function portrait(parent: Instance, heroId: string, size: number, position: UDim2?, anchor: Vector2?): Frame
	local hero = Config.HeroesById[heroId] or Config.Heroes[1]
	local frame = create("Frame", {
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
		BackgroundColor3 = hero.Color,
		Parent = parent,
	}, {
		round(),
		line(0.2, Color3.new(1, 1, 1), 2),
		create("UIGradient", { Rotation = 120, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 130)) }),
	}) :: Frame
	text({ Name = "Icon", Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Text = hero.Icon, Parent = frame })
	return frame
end

---------------------------------------------------------------- Grundgeruest

local gui = create("ScreenGui", { Name = "HUD", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }) :: ScreenGui
local uiScale = create("UIScale", { Parent = gui }) :: UIScale
local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui }) :: Frame

local function rescale()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.58, 1.3)
	uiScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

---------------------------------------------------------------- Meldungen

local toasts = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(460, 200), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
})

local function toast(message: string, color: Color3?)
	local item = panel({ Size = UDim2.fromOffset(440, 34), Parent = toasts, BackgroundTransparency = 0.15, Radius = 17 })
	text({ Size = UDim2.new(1, -24, 1, -8), Position = UDim2.fromOffset(12, 4), Text = message, TextColor3 = color or TEXT, Parent = item, Font = BODY })
	task.delay(3.2, function()
		TweenService:Create(item, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, child in item:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.35)
		item:Destroy()
	end)
end
UI.Toast = toast

local announce = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(700, 46), Text = "", Font = TITLE, Outline = 3, TextTransparency = 1, Parent = root })
local announceStroke = announce:FindFirstChildOfClass("UIStroke") :: UIStroke
local announceId = 0
local function bigAnnounce(message: string, color: Color3?)
	announceId += 1
	local id = announceId
	announce.Text = message
	announce.TextColor3 = color or TEXT
	announce.TextTransparency = 0
	announceStroke.Transparency = 0
	announce.Size = UDim2.fromOffset(560, 36)
	TweenService:Create(announce, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(700, 46) }):Play()
	task.delay(3, function()
		if id == announceId then
			TweenService:Create(announce, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(announceStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end)
end

---------------------------------------------------------------- Fenster

local backdrop = create("TextButton", { Size = UDim2.fromScale(4, 4), Position = UDim2.fromScale(-1.5, -1.5), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 20, Parent = root }) :: TextButton
local windows = {}
local openName: string? = nil

local function closeWindows()
	for _, window in windows do
		window.Visible = false
	end
	backdrop.Visible = false
	openName = nil
end
backdrop.Activated:Connect(closeWindows)

local function window(name: string, title: string, width: number, height: number, accent: Color3?)
	local frame = panel({ Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), Visible = false, ZIndex = 21, Parent = root, BackgroundTransparency = 0.02, Radius = 18 })
	create("Frame", { Size = UDim2.new(1, -36, 0, 3), Position = UDim2.fromOffset(18, 52), BackgroundColor3 = accent or GOLD, BorderSizePixel = 0, ZIndex = 22, Parent = frame }, { round() })
	text({ Size = UDim2.new(1, -120, 0, 34), Position = UDim2.fromOffset(20, 12), Text = title, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = frame, TextColor3 = accent or GOLD })
	local close = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(36, 36), Text = "✕", ZIndex = 23, Parent = frame, Radius = 18 }, "Dark")
	close.Activated:Connect(closeWindows)
	local body = create("Frame", { Name = "Body", Position = UDim2.fromOffset(18, 66), Size = UDim2.new(1, -36, 1, -82), BackgroundTransparency = 1, ZIndex = 22, Parent = frame }) :: Frame
	windows[name] = frame
	return frame, body
end

local refreshers = {}
local function openWindow(name: string)
	if openName == name then
		closeWindows()
		return
	end
	closeWindows()
	local frame = windows[name]
	if not frame then
		return
	end
	if refreshers[name] then
		refreshers[name]()
	end
	frame.Visible = true
	backdrop.Visible = true
	openName = name
	local scale = frame:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = frame })
	scale.Scale = 0.9
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end
UI.Open = openWindow

-- Alles in Fenstern ueber dem Hintergrund zeichnen
local function lift(instance: Instance, z: number)
	if instance:IsA("GuiObject") then
		instance.ZIndex = z
	end
	for _, child in instance:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = math.max(child.ZIndex, z)
		end
	end
end

---------------------------------------------------------------- Oben: Punktestand und Zeit

local scoreBar = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(300, 46), Parent = root, Radius = 23 })
local dawnKills = text({ Position = UDim2.fromOffset(16, 6), Size = UDim2.fromOffset(70, 34), Text = "0", Font = TITLE, TextColor3 = Config.Teams[1].Color, Parent = scoreBar })
local duskKills = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 6), Size = UDim2.fromOffset(70, 34), Text = "0", Font = TITLE, TextColor3 = Config.Teams[2].Color, Parent = scoreBar })
local timerLabel = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(110, 24), Text = "0:00", Font = TITLE, Parent = scoreBar })
local towersLabel = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 28), Size = UDim2.fromOffset(140, 14), Text = "", Font = SMALL, TextColor3 = MUTED, Parent = scoreBar })

---------------------------------------------------------------- Oben links: Heldenkarte

local heroCard = panel({ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(268, 78), Parent = root })
local heroPortraitHolder = create("Frame", { Position = UDim2.fromOffset(8, 7), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Parent = heroCard }) :: Frame
local levelBadge = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(64, 64), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 0, BackgroundColor3 = INK, Text = "1", Font = TITLE, TextColor3 = GOLD, Parent = heroCard, Children = { round(), line(0.3, GOLD, 1.5) } })
local heroName = text({ Position = UDim2.fromOffset(84, 6), Size = UDim2.fromOffset(176, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = heroCard })
local hpBack = create("Frame", { Position = UDim2.fromOffset(84, 30), Size = UDim2.fromOffset(174, 18), BackgroundColor3 = Color3.fromRGB(8, 10, 20), Parent = heroCard }, { corner(6) }) :: Frame
local hpFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, Parent = hpBack }, { corner(6), create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }) }) :: Frame
local hpText = text({ Size = UDim2.fromScale(1, 1), Text = "", Font = SMALL, Parent = hpBack, Outline = 1 })
local xpBack = create("Frame", { Position = UDim2.fromOffset(84, 52), Size = UDim2.fromOffset(174, 5), BackgroundColor3 = Color3.fromRGB(8, 10, 20), Parent = heroCard }, { round() }) :: Frame
local xpFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(190, 140, 255), Parent = xpBack }, { round() }) :: Frame
local goldLabel = text({ Position = UDim2.fromOffset(84, 59), Size = UDim2.fromOffset(100, 16), Text = "", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = heroCard })
local crystalsLabel = text({ Position = UDim2.fromOffset(170, 59), Size = UDim2.fromOffset(90, 16), Text = "", TextColor3 = CRYSTAL, TextXAlignment = Enum.TextXAlignment.Right, Font = BODY, Parent = heroCard })

local itemBar = create("Frame", { Position = UDim2.fromOffset(10, 92), Size = UDim2.fromOffset(268, 34), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5) }),
}) :: Frame
local itemSlots = {}
for i = 1, Config.MaxItems do
	local slot = panel({ Size = UDim2.fromOffset(34, 34), LayoutOrder = i, Parent = itemBar, Radius = 8, BackgroundTransparency = 0.25 })
	itemSlots[i] = text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = "", Parent = slot })
end

---------------------------------------------------------------- Oben rechts: Minimap und Kill-Feed

local MAP = Config.Map
local MINI_W, MINI_H = 124, 176
local minimap = panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(MINI_W + 8, MINI_H + 8), Parent = root, Radius = 12 })
local miniField = create("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(MINI_W, MINI_H), BackgroundColor3 = Color3.fromRGB(62, 104, 64), ClipsDescendants = true, Parent = minimap }, { corner(9) }) :: Frame

-- Weltposition -> Minimap (Gegner-Basis oben, wie die Kamera)
local function toMini(position: Vector3): UDim2
	local sign = if player:GetAttribute("Team") == 2 then -1 else 1
	local u = (position.Z * sign + MAP.HalfZ) / (MAP.HalfZ * 2)
	local v = 1 - (position.X * sign + MAP.HalfX) / (MAP.HalfX * 2)
	return UDim2.fromScale(math.clamp(u, 0, 1), math.clamp(v, 0, 1))
end

local miniStatic = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = miniField }) :: Frame
local function drawMiniStatic()
	miniStatic:ClearAllChildren()
	local function segment(a: Vector3, b: Vector3, width: number, color: Color3)
		local pa, pb = toMini(a), toMini(b)
		local ax, ay = pa.X.Scale * MINI_W, pa.Y.Scale * MINI_H
		local bx, by = pb.X.Scale * MINI_W, pb.Y.Scale * MINI_H
		local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
		create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
			Size = UDim2.fromOffset(length + width, width),
			Rotation = math.deg(math.atan2(by - ay, bx - ax)),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = miniStatic,
		}, { round() })
	end
	segment(Vector3.new(0, 0, -MAP.HalfZ), Vector3.new(0, 0, MAP.HalfZ), 4, Color3.fromRGB(90, 190, 220))
	for _, name in MAP.LaneOrder do
		local points = MAP.Lanes[name]
		for i = 1, #points - 1 do
			segment(points[i], points[i + 1], 6, Color3.fromRGB(214, 192, 150))
		end
	end
	for team = 1, 2 do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = toMini(MAP.Fountain[team]), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = teamColor(team), BackgroundTransparency = 0.4, Parent = miniStatic }, { round() })
	end
end
local miniDots = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = miniField }) :: Frame
local dotPool = {}
local function updateMinimap()
	local used = 0
	local myTeam = player:GetAttribute("Team")
	local units = workspace:FindFirstChild("Units")
	local list = {}
	if units then
		for _, model in units:GetChildren() do
			table.insert(list, model)
		end
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	for _, model in list do
		local kind = model:GetAttribute("Kind")
		local root = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if kind and root and (model:GetAttribute("HP") or 0) > 0 then
			used += 1
			local dot = dotPool[used]
			if not dot then
				dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Parent = miniDots }, { round(), line(0.2, Color3.new(0, 0, 0), 1) })
				dotPool[used] = dot
			end
			local team = model:GetAttribute("Team")
			local size = if kind == "Hero" then 9 elseif kind == "Core" then 12 elseif kind == "Tower" then 8 elseif kind == "Monster" then 7 else 4
			if model == player.Character then
				size = 12
			end
			dot.Size = UDim2.fromOffset(size, size)
			dot.Position = toMini(root.Position)
			dot.BackgroundColor3 = if model == player.Character then Color3.new(1, 1, 1) elseif team == 0 then Bars.NEUTRAL elseif team == myTeam then Bars.ALLY else Bars.ENEMY
			dot.ZIndex = if kind == "Hero" then 4 else 3
			dot.Visible = true
		end
	end
	for i = used + 1, #dotPool do
		dotPool[i].Visible = false
	end
end

local camButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, MINI_H + 20), Size = UDim2.fromOffset(64, 26), Text = "🎥 CAM", Parent = root, MaxText = 14 }, "Dark")
camButton.Activated:Connect(function()
	CameraController.SetClassic(not CameraController.IsClassic())
	toast(if CameraController.IsClassic() then "Classic camera (drag to rotate)" else "Top-down camera", MUTED)
end)
local scoreButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -80, 0, MINI_H + 20), Size = UDim2.fromOffset(64, 26), Text = "📋 TAB", Parent = root, MaxText = 14 }, "Dark")

local killFeed = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, MINI_H + 54), Size = UDim2.fromOffset(250, 150), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4) }),
}) :: Frame

local function addKill(info)
	local mine = player:GetAttribute("Team")
	local entry = panel({ Size = UDim2.fromOffset(240, 26), Parent = killFeed, BackgroundTransparency = 0.2, Radius = 13 })
	local killerHero = Config.HeroesById[info.KillerHero or ""]
	local victimHero = Config.HeroesById[info.VictimHero or ""]
	local function colorFor(team)
		return if team == mine then Bars.ALLY else Bars.ENEMY
	end
	text({ Position = UDim2.fromOffset(8, 3), Size = UDim2.fromOffset(104, 20), Text = (if killerHero then killerHero.Icon .. " " else "") .. info.Killer, TextColor3 = colorFor(info.KillerTeam), TextXAlignment = Enum.TextXAlignment.Left, Font = SMALL, Parent = entry })
	text({ Position = UDim2.fromOffset(110, 3), Size = UDim2.fromOffset(20, 20), Text = "⚔", Parent = entry })
	text({ Position = UDim2.fromOffset(130, 3), Size = UDim2.fromOffset(104, 20), Text = (if victimHero then victimHero.Icon .. " " else "") .. info.Victim, TextColor3 = colorFor(info.VictimTeam), TextXAlignment = Enum.TextXAlignment.Right, Font = SMALL, Parent = entry })
	while #killFeed:GetChildren() > 6 do
		for _, child in killFeed:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
	task.delay(6, function()
		entry:Destroy()
	end)
end

---------------------------------------------------------------- Unten rechts: Faehigkeiten

local abilityPad = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(300, 230), BackgroundTransparency = 1, Parent = root }) :: Frame
local abilityButtons = {}
local LAYOUT = {
	R = { Position = UDim2.new(1, -46, 1, -46), Size = 92 },
	Q = { Position = UDim2.new(1, -150, 1, -36), Size = 72 },
	E = { Position = UDim2.new(1, -46, 1, -150), Size = 72 },
}

local function cast(key: string)
	if match:GetAttribute("Phase") ~= "Playing" or player:GetAttribute("Dead") then
		return
	end
	remotes.Cast:FireServer(key, CameraController.MouseGround())
end

for _, key in Config.AbilityKeys do
	local layout = LAYOUT[key]
	local holder = create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = layout.Position,
		Size = UDim2.fromOffset(layout.Size, layout.Size),
		BackgroundColor3 = INK2,
		BackgroundTransparency = 0.05,
		Text = "",
		AutoButtonColor = false,
		Parent = abilityPad,
	}, { round(), create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 190)) }) }) :: TextButton
	local ring = line(0, GOLD, 3)
	ring.Parent = holder
	local icon = text({ Size = UDim2.fromScale(0.5, 0.42), Position = UDim2.fromScale(0.25, 0.14), Text = key, Font = TITLE, Parent = holder })
	local nameLabel = text({ Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.05, 0.6), Text = "", Font = SMALL, TextColor3 = MUTED, Parent = holder })
	local shade = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Parent = holder }, { round() }) :: Frame
	local count = text({ Size = UDim2.fromScale(0.6, 0.45), Position = UDim2.fromScale(0.2, 0.28), Text = "", Font = TITLE, Parent = holder, Outline = 2, ZIndex = 3 })
	local scale = create("UIScale", { Parent = holder }) :: UIScale
	holder.Activated:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.88 }):Play()
		task.delay(0.08, function()
			TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
		remotes.Cast:FireServer(key, nil)
	end)
	abilityButtons[key] = { Holder = holder, Ring = ring, Icon = icon, Name = nameLabel, Shade = shade, Count = count }
end

local recallButton = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -228, 1, -30), Size = UDim2.fromOffset(54, 54), Text = "🏠", Parent = abilityPad, Radius = 27, MaxText = 26 }, "Dark")
recallButton.Activated:Connect(function()
	remotes.Recall:FireServer()
end)
local shopButton = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -150, 1, -118), Size = UDim2.fromOffset(54, 54), Text = "🛒", Parent = abilityPad, Radius = 27, MaxText = 26 }, "Dark")
local shopBadge = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0, BackgroundColor3 = GOLD, Text = "!", TextColor3 = INK, Font = TITLE, Visible = false, Parent = shopButton, Children = { round() } })

-- Rueckruf-Balken
local recallBar = panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(240, 30), Visible = false, Parent = root, Radius = 15 })
local recallFill = create("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0, 0, 1, -8), BackgroundColor3 = CRYSTAL, Parent = recallBar }, { round() }) :: Frame
text({ Size = UDim2.fromScale(1, 1), Text = "RECALLING...", Font = BODY, Parent = recallBar, Outline = 1.5 })

---------------------------------------------------------------- Links: Menue

local menu = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 10), Size = UDim2.fromOffset(64, 330), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: Frame

local function menuButton(icon: string, label: string, color: Color3, order: number)
	local holder = create("TextButton", { Size = UDim2.fromOffset(60, 58), BackgroundColor3 = INK, BackgroundTransparency = 0.1, LayoutOrder = order, Text = "", AutoButtonColor = true, Parent = menu }, { corner(14), line(0.6, color, 2) }) :: TextButton
	text({ Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 5), Text = icon, Parent = holder })
	text({ Size = UDim2.new(1, -6, 0, 14), Position = UDim2.fromOffset(3, 38), Text = label, Font = BODY, TextColor3 = color, Parent = holder })
	local badge = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0, BackgroundColor3 = RED, Text = "!", Font = TITLE, Visible = false, Parent = holder, Children = { round() } })
	return holder, badge
end

local storeButton = menuButton("💎", "STORE", CRYSTAL, 1)
local heroesButton = menuButton("🦸", "HEROES", GOLD, 2)
local skinsButton = menuButton("🎨", "SKINS", Color3.fromRGB(255, 140, 200), 3)
local dailyButton, dailyBadge = menuButton("🎁", "DAILY", GREEN, 4)
local adButton = menuButton("🎬", "FREE 💎", Color3.fromRGB(255, 170, 80), 5)
adButton.Visible = false

---------------------------------------------------------------- Item-Shop

local shopWindow, shopBody = window("Shop", "ITEM SHOP", 640, 420, GOLD)
local shopGold = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 16), Size = UDim2.fromOffset(140, 26), Text = "", TextColor3 = GOLD, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Right, Parent = shopWindow })
local shopNote = text({ Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = MUTED, Font = SMALL, Parent = shopBody })
local autoButton = button({ Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(170, 32), Text = "AUTO-BUY: ON", Parent = shopBody }, "Dark")
local recommendButton = button({ Position = UDim2.fromOffset(180, 26), Size = UDim2.fromOffset(200, 32), Text = "BUY RECOMMENDED", Parent = shopBody }, "Gold")
local ownedRow = create("Frame", { Position = UDim2.fromOffset(392, 26), Size = UDim2.fromOffset(212, 32), BackgroundTransparency = 1, Parent = shopBody }, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }) }) :: Frame
local itemGrid = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 1, -68), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BorderSizePixel = 0, Parent = shopBody }, {
	create("UIGridLayout", { CellSize = UDim2.fromOffset(142, 120), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: ScrollingFrame

local function statText(stats): string
	local parts = {}
	if stats.Power then table.insert(parts, `+{stats.Power} Power`) end
	if stats.HP then table.insert(parts, `+{stats.HP} HP`) end
	if stats.Armor then table.insert(parts, `+{stats.Armor} Armor`) end
	if stats.AttackSpeed then table.insert(parts, `+{math.floor(stats.AttackSpeed * 100)}% Atk Speed`) end
	if stats.Speed then table.insert(parts, `+{stats.Speed} Move Speed`) end
	if stats.Haste then table.insert(parts, `-{math.floor(stats.Haste * 100)}% Cooldowns`) end
	if stats.Lifesteal then table.insert(parts, `{math.floor(stats.Lifesteal * 100)}% Lifesteal`) end
	if stats.Regen then table.insert(parts, `+{stats.Regen} HP/s`) end
	return table.concat(parts, "\n")
end

local itemCards = {}
for _, item in Config.Items do
	local card = create("TextButton", { LayoutOrder = item.Order, BackgroundColor3 = INK2, Text = "", AutoButtonColor = true, Parent = itemGrid }, { corner(12), line(0.8) }) :: TextButton
	text({ Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(30, 30), Text = item.Icon, Parent = card })
	text({ Position = UDim2.fromOffset(42, 8), Size = UDim2.new(1, -48, 0, 18), Text = item.Name, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	text({ Position = UDim2.fromOffset(42, 26), Size = UDim2.new(1, -48, 0, 14), Text = Format.Number(item.Cost) .. " gold", TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Font = SMALL, Parent = card })
	text({ Position = UDim2.fromOffset(8, 44), Size = UDim2.new(1, -16, 1, -50), Text = statText(item.Stats), TextColor3 = MUTED, Font = SMALL, TextScaled = false, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	card.Activated:Connect(function()
		remotes.BuyItem:FireServer(item.Id)
	end)
	itemCards[item.Id] = card
end

autoButton.Activated:Connect(function()
	remotes.SetAutoBuy:FireServer(not player:GetAttribute("AutoBuy"))
end)
recommendButton.Activated:Connect(function()
	remotes.BuyItem:FireServer("Auto")
end)

local function refreshShop()
	local gold = player:GetAttribute("Gold") or 0
	local canShop = player:GetAttribute("CanShop") == true
	shopGold.Text = "💰 " .. Format.Number(gold)
	shopNote.Text = if canShop then "Tap an item to buy it. Tap an owned item (top right) to sell it for 60%." else "You can only buy at your fountain or while respawning. Use 🏠 Recall!"
	shopNote.TextColor3 = if canShop then MUTED else RED
	autoButton.Text = if player:GetAttribute("AutoBuy") then "AUTO-BUY: ON" else "AUTO-BUY: OFF"
	local items = string.split(player:GetAttribute("Items") or "", ",")
	for id, card in itemCards do
		local item = Config.ItemsById[id]
		local has = table.find(items, id) ~= nil
		card.BackgroundColor3 = if has then Color3.fromRGB(40, 70, 56) elseif gold >= item.Cost and canShop then INK3 else INK2
		card.BackgroundTransparency = if gold >= item.Cost or has then 0 else 0.35
	end
	-- Nur neu zeichnen, wenn sich die Items aendern (sonst gehen Antipper verloren)
	local key = player:GetAttribute("Items") or ""
	if ownedRow:GetAttribute("Key") == key then
		return
	end
	ownedRow:SetAttribute("Key", key)
	ownedRow:ClearAllChildren()
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = ownedRow })
	for slot, id in items do
		local item = Config.ItemsById[id]
		if item then
			local sell = button({ Size = UDim2.fromOffset(32, 32), Text = item.Icon, Parent = ownedRow, MaxText = 20 }, "Dark")
			sell.Activated:Connect(function()
				remotes.SellItem:FireServer(slot)
			end)
		end
	end
	lift(shopWindow, 22)
end
refreshers.Shop = refreshShop
shopButton.Activated:Connect(function()
	openWindow("Shop")
end)

---------------------------------------------------------------- Store (Robux und Kristalle)

local storeWindow, storeBody = window("Store", "STORE", 680, 440, CRYSTAL)
local storeCrystals = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 16), Size = UDim2.fromOffset(160, 26), Text = "", TextColor3 = CRYSTAL, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Right, Parent = storeWindow })
local tabs = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = storeBody }, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }) }) :: Frame
local storeList = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BorderSizePixel = 0, Parent = storeBody }) :: ScrollingFrame
local storeTab = "Featured"

local function storeCard(order: number, title: string, subtitle: string, color: Color3, icon: string)
	local card = create("Frame", { LayoutOrder = order, BackgroundColor3 = INK2, Parent = storeList }, { corner(14), line(0.6, color, 2) }) :: Frame
	create("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = color, Parent = card }, {
		corner(14),
		create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 140)), Transparency = NumberSequence.new(0.2, 0.6) }),
	})
	text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 52), Text = icon, Parent = card })
	text({ Position = UDim2.fromOffset(8, 76), Size = UDim2.new(1, -16, 0, 20), Text = title, Font = TITLE, Parent = card })
	text({ Position = UDim2.fromOffset(8, 98), Size = UDim2.new(1, -16, 0, 34), Text = subtitle, TextColor3 = MUTED, Font = SMALL, TextScaled = false, TextSize = 13, TextWrapped = true, Parent = card })
	return card
end

local function productButton(card: Frame, key: string, y: number?)
	local product = Config.Products[key]
	local b = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, y or -8), Size = UDim2.new(1, -16, 0, 30), Text = ` {product.Price} R$`, Parent = card }, "Robux")
	b.Activated:Connect(function()
		buyProduct(key)
	end)
	return b
end

local function ownedLabel(card: Frame, label: string?)
	text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -16, 0, 24), Text = label or "✔ OWNED", TextColor3 = GREEN, Parent = card })
end

local function buildStore()
	storeList:ClearAllChildren()
	create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 186), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = storeList })
	storeCrystals.Text = "💎 " .. Format.Number(player:GetAttribute("Crystals") or 0)
	local heroes = player:GetAttribute("OwnedHeroes")
	local skins = player:GetAttribute("OwnedSkins")
	if storeTab == "Featured" then
		if not player:GetAttribute("StarterPackOwned") then
			local card = storeCard(0, "STARTER PACK", "Volt + Inferno skin + 500 crystals. One time only!", Color3.fromRGB(255, 120, 60), "🎁")
			productButton(card, "StarterPack")
		end
		for index, key in { "Pass_VIP", "Pass_DoubleCrystals", "AllHeroes" } do
			local product = Config.Products[key]
			local icon = if key == "Pass_VIP" then "👑" elseif key == "AllHeroes" then "🦸" else "💎"
			local card = storeCard(index, string.upper(product.Name), product.Description, if key == "Pass_VIP" then GOLD else CRYSTAL, icon)
			local has = (key == "Pass_VIP" and player:GetAttribute("VIP")) or (key == "Pass_DoubleCrystals" and player:GetAttribute("DoubleCrystals"))
			if key == "AllHeroes" then
				has = #string.split(heroes or "", ",") >= #Config.Heroes
			end
			if has then
				ownedLabel(card)
			else
				productButton(card, key)
			end
		end
	elseif storeTab == "Heroes" then
		for _, hero in Config.Heroes do
			local card = storeCard(hero.Order, string.upper(hero.Name), hero.Title .. " · " .. hero.Role, hero.Color, hero.Icon)
			if owned(heroes, hero.Id) then
				ownedLabel(card, if hero.Free then "✔ FREE" else "✔ OWNED")
			else
				local unlock = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -44), Size = UDim2.new(1, -16, 0, 30), Text = `💎 {hero.Crystals}`, Parent = card }, "Crystal")
				unlock.Activated:Connect(function()
					remotes.UnlockHero:FireServer(hero.Id)
				end)
				if Config.Products["Hero_" .. hero.Id] then
					productButton(card, "Hero_" .. hero.Id)
				end
			end
		end
	elseif storeTab == "Skins" then
		for _, skin in Config.Skins do
			local color = skin.Color or Color3.fromRGB(120, 120, 140)
			local card = storeCard(skin.Order, string.upper(skin.Name), "Weapon, glow and aura for every hero", color, if skin.Particles == "Fire" then "🔥" elseif skin.Particles == "Snow" then "❄️" elseif skin.Particles == "Stars" then "🌌" elseif skin.Particles == "Sparkle" then "✨" else "⚔️")
			if owned(skins, skin.Id) then
				if player:GetAttribute("Skin") == skin.Id then
					ownedLabel(card, "✔ EQUIPPED")
				else
					local equip = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 30), Text = "EQUIP", Parent = card }, "Gold")
					equip.Activated:Connect(function()
						remotes.EquipSkin:FireServer(skin.Id)
					end)
				end
			elseif skin.Crystals then
				local buy = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 30), Text = `💎 {skin.Crystals}`, Parent = card }, "Crystal")
				buy.Activated:Connect(function()
					remotes.BuySkin:FireServer(skin.Id)
				end)
			elseif skin.Product then
				productButton(card, skin.Product)
			end
		end
	elseif storeTab == "Crystals" then
		for index, key in { "Crystals_S", "Crystals_M", "Crystals_L" } do
			local product = Config.Products[key]
			local card = storeCard(index, Format.Number(product.Amount) .. " 💎", product.Name, CRYSTAL, string.rep("💎", index))
			productButton(card, key)
		end
		local card = storeCard(10, "SPEND CRYSTALS", "Unlock heroes and the Crimson skin. You earn crystals every match!", GOLD, "🛍️")
		local go = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 30), Text = "HEROES", Parent = card }, "Gold")
		go.Activated:Connect(function()
			storeTab = "Heroes"
			buildStore()
		end)
	end
	lift(storeWindow, 22)
end

local tabButtons = {}
for index, name in { "Featured", "Heroes", "Skins", "Crystals" } do
	local tab = button({ LayoutOrder = index, Size = UDim2.fromOffset(120, 32), Text = string.upper(name), Parent = tabs }, "Dark")
	tab.Activated:Connect(function()
		storeTab = name
		for other, b in tabButtons do
			b.BackgroundColor3 = if other == name then CRYSTAL else INK3
			b.TextColor3 = if other == name then INK else TEXT
		end
		buildStore()
	end)
	tabButtons[name] = tab
end
local function openStore(tab: string)
	storeTab = tab
	for other, b in tabButtons do
		b.BackgroundColor3 = if other == tab then CRYSTAL else INK3
		b.TextColor3 = if other == tab then INK else TEXT
	end
	openWindow("Store")
end
refreshers.Store = buildStore
storeButton.Activated:Connect(function()
	openStore("Featured")
end)
heroesButton.Activated:Connect(function()
	openStore("Heroes")
end)
skinsButton.Activated:Connect(function()
	openStore("Skins")
end)
UI.OpenStore = openStore

---------------------------------------------------------------- Anzeigetafel

local scoreWindow, scoreBody = window("Score", "SCOREBOARD", 700, 400, TEXT)
local function buildScoreboard()
	scoreBody:ClearAllChildren()
	local heroes = match:FindFirstChild("Heroes")
	for team = 1, 2 do
		local column = create("Frame", { Position = UDim2.new((team - 1) * 0.5, if team == 2 then 6 else 0, 0, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = scoreBody }, {
			create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		text({ Size = UDim2.new(1, 0, 0, 26), Text = string.upper(Config.Teams[team].Name) .. "  ·  " .. tostring(match:GetAttribute("Kills" .. team) or 0) .. " kills", Font = TITLE, TextColor3 = teamColor(team), Parent = column, LayoutOrder = 0 })
		for _, entry in (heroes and heroes:GetChildren() or {}) do
			if entry:GetAttribute("Team") == team then
				local isMe = entry:GetAttribute("UserId") == player.UserId
				local row = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = if isMe then INK3 else INK2, LayoutOrder = (entry:GetAttribute("Level") or 1) * -1, Parent = column }, { corner(10) })
				portrait(row, entry:GetAttribute("HeroId"), 40, UDim2.fromOffset(6, 6))
				local dead = entry:GetAttribute("Dead")
				local name = tostring(entry:GetAttribute("Name")) .. (if entry:GetAttribute("IsBot") then "  [BOT]" else "")
				text({ Position = UDim2.fromOffset(52, 5), Size = UDim2.new(1, -150, 0, 20), Text = name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if dead then MUTED else TEXT, Parent = row })
				local items = {}
				for _, id in string.split(entry:GetAttribute("Items") or "", ",") do
					local item = Config.ItemsById[id]
					if item then
						table.insert(items, item.Icon)
					end
				end
				text({ Position = UDim2.fromOffset(52, 27), Size = UDim2.new(1, -150, 0, 18), Text = table.concat(items, " "), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
				text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 5), Size = UDim2.fromOffset(90, 20), Text = `{entry:GetAttribute("Kills") or 0} / {entry:GetAttribute("Deaths") or 0} / {entry:GetAttribute("Assists") or 0}`, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
				text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 27), Size = UDim2.fromOffset(90, 18), Text = `Lv {entry:GetAttribute("Level") or 1} · CS {entry:GetAttribute("CS") or 0}`, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
			end
		end
	end
	lift(scoreWindow, 22)
end
refreshers.Score = buildScoreboard
scoreButton.Activated:Connect(function()
	openWindow("Score")
end)

---------------------------------------------------------------- Heldenwahl

local pick = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.12, Visible = false, ZIndex = 10, Parent = root }) :: Frame
local pickGradient = create("UIGradient", { Rotation = 25, Parent = pick }) :: UIGradient
local pickBox = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(920, 470), BackgroundTransparency = 1, Parent = pick }) :: Frame
text({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(500, 44), Text = "CHOOSE YOUR HERO", Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Parent = pickBox, Outline = 3 })
local pickTeam = text({ Position = UDim2.fromOffset(0, 44), Size = UDim2.fromOffset(500, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = pickBox })
local pickTimer = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(120, 60), Text = "20", Font = TITLE, TextColor3 = GOLD, Parent = pickBox, Outline = 3 })
local pickGrid = create("Frame", { Position = UDim2.fromOffset(0, 80), Size = UDim2.fromOffset(570, 316), BackgroundTransparency = 1, Parent = pickBox }, {
	create("UIGridLayout", { CellSize = UDim2.fromOffset(134, 154), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: Frame
local detail = panel({ Position = UDim2.fromOffset(586, 80), Size = UDim2.fromOffset(334, 316), Parent = pickBox, Radius = 16 })
local teamStrip = create("Frame", { Position = UDim2.fromOffset(0, 410), Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = pickBox }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),
}) :: Frame

local selectedHero = "Brakka"
local pickCards = {}

local function renderDetail()
	detail:ClearAllChildren()
	corner(16).Parent = detail
	line(0.85).Parent = detail
	local hero = Config.HeroesById[selectedHero]
	portrait(detail, hero.Id, 70, UDim2.fromOffset(14, 14))
	text({ Position = UDim2.fromOffset(96, 14), Size = UDim2.fromOffset(220, 32), Text = string.upper(hero.Name), Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = hero.Color, Parent = detail, Outline = 2 })
	text({ Position = UDim2.fromOffset(96, 48), Size = UDim2.fromOffset(220, 18), Text = hero.Title .. "  ·  " .. hero.Role, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	local stats = hero.Stats
	local bars = { { "Health", stats.HP / 720 }, { "Power", stats.Power / 38 }, { "Range", stats.Range / 26 }, { "Speed", stats.Speed / 19 } }
	for i, info in bars do
		local y = 92 + (i - 1) * 16
		text({ Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(60, 13), Text = info[1], TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		local back = create("Frame", { Position = UDim2.fromOffset(80, y + 3), Size = UDim2.fromOffset(234, 7), BackgroundColor3 = INK3, Parent = detail }, { round() })
		create("Frame", { Size = UDim2.fromScale(math.clamp(info[2], 0.1, 1), 1), BackgroundColor3 = hero.Color, Parent = back }, { round() })
	end
	for i, key in Config.AbilityKeys do
		local ability = hero.Abilities[key]
		local y = 160 + (i - 1) * 38
		text({ Position = UDim2.fromOffset(14, y), Size = UDim2.fromOffset(28, 28), Text = key, Font = TITLE, BackgroundTransparency = 0, BackgroundColor3 = INK3, TextColor3 = GOLD, Parent = detail, Children = { corner(8) } })
		text({ Position = UDim2.fromOffset(50, y - 1), Size = UDim2.fromOffset(266, 16), Text = ability.Name, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		text({ Position = UDim2.fromOffset(50, y + 15), Size = UDim2.fromOffset(266, 14), Text = ability.Desc, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	end
	local ownedHero = owned(player:GetAttribute("OwnedHeroes"), hero.Id)
	if ownedHero then
		local locked = player:GetAttribute("Locked") and player:GetAttribute("PickedHero") == hero.Id
		local lock = button({ Position = UDim2.fromOffset(14, 274), Size = UDim2.new(1, -28, 0, 34), Text = if locked then "✔ LOCKED IN" else "LOCK IN", Parent = detail }, "Gold")
		lock.Activated:Connect(function()
			remotes.PickHero:FireServer(hero.Id, true)
		end)
	else
		local crystals = button({ Position = UDim2.fromOffset(14, 274), Size = UDim2.new(0.5, -18, 0, 34), Text = `💎 {hero.Crystals}`, Parent = detail }, "Crystal")
		crystals.Activated:Connect(function()
			remotes.UnlockHero:FireServer(hero.Id)
		end)
		local key = "Hero_" .. hero.Id
		if Config.Products[key] then
			local robux = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 274), Size = UDim2.new(0.5, -18, 0, 34), Text = ` {Config.Products[key].Price} R$`, Parent = detail }, "Robux")
			robux.Activated:Connect(function()
				buyProduct(key)
			end)
		end
	end
	lift(detail, 11)
end

local function renderPickCards()
	local heroes = player:GetAttribute("OwnedHeroes")
	for id, card in pickCards do
		local hero = Config.HeroesById[id]
		local has = owned(heroes, id)
		local picked = player:GetAttribute("PickedHero") == id
		local stroke = card:FindFirstChild("Stroke") :: UIStroke
		stroke.Color = if picked then GOLD elseif selectedHero == id then TEXT else Color3.new(1, 1, 1)
		stroke.Transparency = if picked or selectedHero == id then 0 else 0.85
		stroke.Thickness = if picked then 3 else 2
		local lockLabel = card:FindFirstChild("Lock") :: TextLabel
		lockLabel.Visible = not has
		lockLabel.Text = `🔒 💎{hero.Crystals}`
		card.BackgroundColor3 = if has then INK2 else Color3.fromRGB(20, 22, 36)
	end
end

for _, hero in Config.Heroes do
	local card = create("TextButton", { LayoutOrder = hero.Order, BackgroundColor3 = INK2, Text = "", AutoButtonColor = true, Parent = pickGrid }, { corner(14) }) :: TextButton
	create("UIStroke", { Name = "Stroke", Thickness = 2, Transparency = 0.85, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	create("Frame", { Size = UDim2.new(1, 0, 0, 92), BackgroundColor3 = hero.Color, Parent = card }, {
		corner(14),
		create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(90, 90, 110)), Transparency = NumberSequence.new(0, 0.3) }),
	})
	text({ Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 66), Text = hero.Icon, Parent = card })
	text({ Position = UDim2.fromOffset(6, 96), Size = UDim2.new(1, -12, 0, 24), Text = string.upper(hero.Name), Font = TITLE, Parent = card })
	text({ Position = UDim2.fromOffset(6, 122), Size = UDim2.new(1, -12, 0, 16), Text = hero.Role, TextColor3 = MUTED, Font = SMALL, Parent = card })
	text({ Name = "Lock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(110, 22), BackgroundTransparency = 0.2, BackgroundColor3 = INK, Text = "", Font = BODY, TextColor3 = CRYSTAL, Parent = card, Children = { round() } })
	card.Activated:Connect(function()
		selectedHero = hero.Id
		if owned(player:GetAttribute("OwnedHeroes"), hero.Id) and not player:GetAttribute("Locked") then
			remotes.PickHero:FireServer(hero.Id, false)
		end
		renderDetail()
		renderPickCards()
	end)
	pickCards[hero.Id] = card
end
lift(pick, 10)

local teamStripKey = ""
local function renderTeamStrip()
	local myTeam = player:GetAttribute("Team")
	local parts = { tostring(myTeam) }
	for _, other in Players:GetPlayers() do
		table.insert(parts, `{other.UserId}:{other:GetAttribute("Team")}:{other:GetAttribute("PickedHero")}:{other:GetAttribute("Locked")}`)
	end
	local key = table.concat(parts, "|")
	if key == teamStripKey then
		return
	end
	teamStripKey = key
	teamStrip:ClearAllChildren()
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = teamStrip })
	local count = 0
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("Team") == myTeam then
			count += 1
			local chip = panel({ Size = UDim2.fromOffset(170, 48), Parent = teamStrip, Radius = 24 })
			portrait(chip, other:GetAttribute("PickedHero") or "Brakka", 38, UDim2.fromOffset(5, 5))
			text({ Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(112, 18), Text = other.DisplayName, TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
			text({ Position = UDim2.fromOffset(50, 25), Size = UDim2.fromOffset(112, 16), Text = if other:GetAttribute("Locked") then "✔ Ready" else "Choosing...", TextColor3 = if other:GetAttribute("Locked") then GREEN else MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
		end
	end
	for _ = count + 1, Config.TeamSize do
		local chip = panel({ Size = UDim2.fromOffset(110, 48), Parent = teamStrip, Radius = 24, BackgroundTransparency = 0.5 })
		text({ Size = UDim2.fromScale(1, 1), Text = "🤖 Bot", TextColor3 = MUTED, Parent = chip })
	end
	lift(teamStrip, 11)
end

---------------------------------------------------------------- Todesbildschirm

local deathPanel = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(320, 104), Visible = false, Parent = root })
local deathText = text({ Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 40), Text = "", Font = TITLE, Parent = deathPanel, Outline = 2 })
local respawnButton = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 38), Text = ` RESPAWN NOW · {Config.Products.Respawn.Price} R$`, Parent = deathPanel }, "Robux")
respawnButton.Activated:Connect(function()
	buyProduct("Respawn")
end)
local grey = create("ColorCorrectionEffect", { Name = "DeathGrey", Saturation = 0, Enabled = false, Parent = Lighting }) :: ColorCorrectionEffect

---------------------------------------------------------------- Ergebnis

local result = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 330), Visible = false, ZIndex = 15, Parent = root, Radius = 20 })
local resultTitle = text({ Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 64), Text = "VICTORY", Font = TITLE, Parent = result, Outline = 4 })
local resultStats = text({ Position = UDim2.fromOffset(20, 86), Size = UDim2.new(1, -40, 0, 26), Text = "", Parent = result })
local resultCrystals = text({ Position = UDim2.fromOffset(20, 124), Size = UDim2.new(1, -40, 0, 44), Text = "", Font = TITLE, TextColor3 = CRYSTAL, Parent = result, Outline = 2 })
local resultBreakdown = text({ Position = UDim2.fromOffset(20, 172), Size = UDim2.new(1, -40, 0, 40), Text = "", TextColor3 = MUTED, Font = SMALL, TextScaled = false, TextSize = 15, TextWrapped = true, Parent = result })
local resultNext = text({ Position = UDim2.fromOffset(20, 214), Size = UDim2.new(1, -40, 0, 20), Text = "", TextColor3 = MUTED, Font = SMALL, Parent = result })
local resultStore = button({ Position = UDim2.new(0, 20, 1, -64), Size = UDim2.new(0.5, -26, 0, 44), Text = "🦸 HEROES", Parent = result }, "Gold")
local resultBoost = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 1, -64), Size = UDim2.new(0.5, -26, 0, 44), Text = "💎 2x CRYSTALS", Parent = result }, "Crystal")
resultStore.Activated:Connect(function()
	result.Visible = false
	openStore("Heroes")
end)
resultBoost.Activated:Connect(function()
	buyProduct("Pass_DoubleCrystals")
end)
lift(result, 15)

local function showResult(info)
	resultTitle.Text = if info.Won then "VICTORY!" else "DEFEAT"
	resultTitle.TextColor3 = if info.Won then GOLD else Color3.fromRGB(190, 160, 255)
	local hero = Config.HeroesById[info.HeroId]
	resultStats.Text = `{if hero then hero.Icon .. " " .. hero.Name else ""}  ·  Level {info.Level}  ·  {info.Kills} / {info.Deaths} / {info.Assists}`
	resultCrystals.Text = `+{info.Crystals} 💎`
	local parts = { `{if info.Won then "Win" else "Match"} +{info.Base}`, `Kills & assists +{info.Bonus}` }
	if info.FirstWin then
		table.insert(parts, `First win today +{Config.Rewards.FirstWinBonus}`)
	end
	if info.Multiplier > 1 then
		table.insert(parts, `Pass bonus x{info.Multiplier}`)
	end
	resultBreakdown.Text = table.concat(parts, "   ·   ")
	resultBoost.Visible = not player:GetAttribute("DoubleCrystals")
	result.Visible = true
	local scale = result:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = result })
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

---------------------------------------------------------------- Angebot

local offer = panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(460, 96), Visible = false, ZIndex = 16, Parent = root })
local offerText = text({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 38), Text = "", TextScaled = false, TextSize = 16, TextWrapped = true, Parent = offer })
local offerBuy = button({ Position = UDim2.new(0, 14, 1, -42), Size = UDim2.new(0.6, -20, 0, 32), Text = "GET IT", Parent = offer }, "Robux")
local offerNo = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 1, -42), Size = UDim2.new(0.4, -10, 0, 32), Text = "No thanks", Parent = offer }, "Dark")
local offerKey: string? = nil
offerBuy.Activated:Connect(function()
	offer.Visible = false
	if offerKey then
		buyProduct(offerKey)
	end
end)
offerNo.Activated:Connect(function()
	offer.Visible = false
end)
lift(offer, 16)

---------------------------------------------------------------- Takt

local lastPhase = nil
local function updateHUD()
	local phase = match:GetAttribute("Phase") or "Waiting"
	local playing = phase == "Playing"
	local t = now()
	local myTeam = player:GetAttribute("Team")
	local heroId = player:GetAttribute("Hero")
	local inMatch = (playing or phase == "End") and heroId ~= nil

	-- Phasenwechsel
	if phase ~= lastPhase then
		lastPhase = phase
		if phase == "Pick" then
			result.Visible = false
			closeWindows()
			selectedHero = player:GetAttribute("PickedHero") or "Brakka"
			renderDetail()
			renderPickCards()
		elseif phase == "Playing" then
			local lane = player:GetAttribute("Lane")
			if lane then
				toast(`Your lane: {lane}. Stay behind your minions and destroy the enemy towers!`, GOLD)
			end
			drawMiniStatic()
		end
	end

	pick.Visible = phase == "Pick"
	if pick.Visible then
		local info = Config.Teams[myTeam or 1]
		pickTeam.Text = `You fight for {string.upper(info.Name)}`
		pickTeam.TextColor3 = info.Color
		pickGradient.Color = ColorSequence.new(info.Dark:Lerp(INK, 0.4), INK)
		pickTimer.Text = tostring(math.max(0, math.ceil((match:GetAttribute("PhaseEnd") or t) - t)))
		renderTeamStrip()
	end

	-- Anzeigen, die nur in der Runde Sinn ergeben
	scoreBar.Visible = playing or phase == "End"
	heroCard.Visible = inMatch
	itemBar.Visible = inMatch
	abilityPad.Visible = inMatch and playing
	minimap.Visible = inMatch
	camButton.Visible = inMatch
	scoreButton.Visible = inMatch
	killFeed.Visible = inMatch
	menu.Visible = not pick.Visible

	-- Punktestand
	dawnKills.Text = tostring(match:GetAttribute("Kills1") or 0)
	duskKills.Text = tostring(match:GetAttribute("Kills2") or 0)
	local started = match:GetAttribute("StartedAt") or 0
	timerLabel.Text = if started > 0 then Format.Time(t - started) else "0:00"
	towersLabel.Text = `Towers {match:GetAttribute("Towers1") or 0} : {match:GetAttribute("Towers2") or 0}`
	if phase == "End" then
		local winner = match:GetAttribute("Winner") or 0
		timerLabel.Text = if winner == myTeam then "WIN" else "END"
		resultNext.Text = `Next match in {math.max(0, math.ceil((match:GetAttribute("PhaseEnd") or t) - t))}s`
	end

	-- Heldenkarte
	if heroId then
		local hero = Config.HeroesById[heroId]
		if heroPortraitHolder:GetAttribute("Hero") ~= heroId then
			heroPortraitHolder:ClearAllChildren()
			portrait(heroPortraitHolder, heroId, 64)
			heroPortraitHolder:SetAttribute("Hero", heroId)
			for _, key in Config.AbilityKeys do
				abilityButtons[key].Name.Text = hero.Abilities[key].Name
			end
		end
		heroName.Text = `{hero.Name}  <font color="#9AA3B8">{hero.Role}</font>`
		heroName.RichText = true
		levelBadge.Text = tostring(player:GetAttribute("Level") or 1)
		local character = player.Character
		local hp = character and character:GetAttribute("HP") or 0
		local maxHp = math.max(1, character and character:GetAttribute("MaxHP") or 1)
		if player:GetAttribute("Dead") then
			hp = 0
		end
		hpFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		hpFill.BackgroundColor3 = if hp / maxHp < 0.3 then RED else GREEN
		hpText.Text = `{math.floor(hp)} / {math.floor(maxHp)}`
		local need = player:GetAttribute("XPNeed") or 0
		xpFill.Size = UDim2.fromScale(if need > 0 then math.clamp((player:GetAttribute("XP") or 0) / need, 0, 1) else 1, 1)
		goldLabel.Text = "💰 " .. Format.Number(player:GetAttribute("Gold") or 0)
		local items = string.split(player:GetAttribute("Items") or "", ",")
		for i, slot in itemSlots do
			local item = Config.ItemsById[items[i] or ""]
			slot.Text = if item then item.Icon else ""
		end
		-- Faehigkeiten
		for _, key in Config.AbilityKeys do
			local b = abilityButtons[key]
			local ready = player:GetAttribute("CD_" .. key) or 0
			local total = math.max(0.1, player:GetAttribute("CDMax_" .. key) or 1)
			local left = ready - t
			if left > 0 then
				b.Shade.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
				b.Count.Text = if left < 1 then string.format("%.1f", left) else tostring(math.ceil(left))
				b.Ring.Transparency = 0.7
			else
				b.Shade.Size = UDim2.fromScale(1, 0)
				b.Count.Text = ""
				b.Ring.Transparency = 0
			end
			b.Ring.Color = teamColor(myTeam)
		end
		-- Shop-Hinweis: genug Gold fuer das naechste Item
		local gold = player:GetAttribute("Gold") or 0
		local cheapest = math.huge
		for _, item in Config.Items do
			if not table.find(items, item.Id) then
				cheapest = math.min(cheapest, item.Cost)
			end
		end
		shopBadge.Visible = player:GetAttribute("CanShop") == true and gold >= cheapest and #items < Config.MaxItems
		-- Rueckruf
		local recallUntil = player:GetAttribute("RecallUntil") or 0
		recallBar.Visible = recallUntil > t
		if recallBar.Visible then
			recallFill.Size = UDim2.new(1 - (recallUntil - t) / Config.RecallSeconds, -8, 1, -8)
		end
		-- Tod
		local dead = player:GetAttribute("Dead") == true and playing
		deathPanel.Visible = dead
		grey.Enabled = dead
		if dead then
			grey.Saturation = -0.85
			deathText.Text = `RESPAWN IN {math.max(0, math.ceil((player:GetAttribute("RespawnAt") or t) - t))}`
		end
	else
		deathPanel.Visible = false
		grey.Enabled = false
		recallBar.Visible = false
	end

	crystalsLabel.Text = "💎 " .. Format.Number(player:GetAttribute("Crystals") or 0)
	dailyBadge.Visible = player:GetAttribute("DailyReady") == true
	if openName == "Shop" then
		refreshShop()
	end
end

---------------------------------------------------------------- Start

function UI.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
	end)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	drawMiniStatic()
	player:GetAttributeChangedSignal("Team"):Connect(drawMiniStatic)

	remotes.Notify.OnClientEvent:Connect(function(message, color)
		toast(message, color)
	end)
	remotes.Announce.OnClientEvent:Connect(function(message, color)
		bigAnnounce(message, color)
	end)
	remotes.KillFeed.OnClientEvent:Connect(function(info)
		addKill(info)
		if info.VictimTeam == player:GetAttribute("Team") and info.Victim == player.DisplayName then
			bigAnnounce("YOU WERE DEFEATED", RED)
		elseif info.Killer == player.DisplayName then
			bigAnnounce("ENEMY DEFEATED!", GOLD)
		end
	end)
	remotes.MatchResult.OnClientEvent:Connect(showResult)
	remotes.Offer.OnClientEvent:Connect(function(key, message)
		offerKey = key
		offerText.Text = message
		local product = Config.Products[key]
		offerBuy.Text = if product then ` GET IT · {product.Price} R$` else "GET IT"
		task.delay(if match:GetAttribute("Phase") == "End" then 4 else 0, function()
			offer.Visible = true
		end)
	end)
	for _, attribute in { "OwnedHeroes", "OwnedSkins", "Crystals", "Skin", "VIP", "DoubleCrystals", "StarterPackOwned" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if openName == "Store" then
				buildStore()
			end
			if pick.Visible then
				renderDetail()
				renderPickCards()
			end
		end)
	end
	for _, attribute in { "PickedHero", "Locked" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if pick.Visible then
				renderDetail()
				renderPickCards()
			end
		end)
	end

	dailyButton.Activated:Connect(function()
		if player:GetAttribute("DailyReady") then
			remotes.ClaimDaily:FireServer()
		else
			toast(`Come back tomorrow! Streak: day {player:GetAttribute("DailyStreak") or 0}`, MUTED)
		end
	end)
	-- Freiwillige Video-Werbung: Knopf nur, wenn Roblox gerade eine Werbung bereit hat
	task.spawn(function()
		while gui.Parent do
			local ok, availability = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			adButton.Visible = ok and availability ~= nil and availability.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable and Config.Products.AdReward.Id ~= 0
			task.wait(30)
		end
	end)
	adButton.Activated:Connect(function()
		adButton.Visible = false
		remotes.WatchAd:FireServer()
	end)

	-- Tastatur: Q/E/R, B = Rueckruf, P = Shop, Tab = Anzeigetafel
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.Q or key == Enum.KeyCode.E or key == Enum.KeyCode.R then
			cast(key.Name)
		elseif key == Enum.KeyCode.B then
			remotes.Recall:FireServer()
		elseif key == Enum.KeyCode.P then
			openWindow("Shop")
		elseif key == Enum.KeyCode.Tab then
			openWindow("Score")
		end
	end)

	local accumulator = 0
	local miniAccumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		miniAccumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			updateHUD()
		end
		if miniAccumulator >= 0.25 and minimap.Visible then
			miniAccumulator = 0
			updateMinimap()
		end
	end)
	updateHUD()
end

return UI
