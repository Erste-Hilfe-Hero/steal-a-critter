-- Das komplette HUD per Code: Heldenwahl mit Rollen, Heldenkarte, Minimap, Item-Shop mit Rezepten, Store,
-- Anzeigetafel, Todes- und Ergebnisbildschirm, Meldungen. Stil: dunkles Tintenblau mit Gold und Violett.
local AdService = game:GetService("AdService")
local CollectionService = game:GetService("CollectionService")
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
local Kit = require(script.Parent.Kit)
local Controls = require(script.Parent.Controls)
local Fx = require(script.Parent.Fx)
local Menus = require(script.Parent.Menus)
local Sounds = require(script.Parent.Sounds)
local Vision = require(script.Parent.Vision)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local match = ReplicatedStorage:WaitForChild("Match")

local UI = {}

local INK, INK2, INK3, TEXT, MUTED = Kit.INK, Kit.INK2, Kit.INK3, Kit.TEXT, Kit.MUTED
local GOLD, CRYSTAL, GREEN, RED = Kit.GOLD, Kit.CRYSTAL, Kit.GREEN, Kit.RED
local TITLE, BODY, SMALL = Kit.TITLE, Kit.BODY, Kit.SMALL
local create, corner, round, line, text, panel, button, teamColor = Kit.create, Kit.corner, Kit.round, Kit.line, Kit.text, Kit.panel, Kit.button, Kit.teamColor

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
	create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local toastOrder = 0
local MAX_TOASTS = 4
local function toast(message: string, color: Color3?)
	-- Hoechstens vier Meldungen gleichzeitig, sonst laufen sie bei Spam aus dem Bild (die aelteste geht)
	local list = {}
	for _, child in toasts:GetChildren() do
		if child:IsA("Frame") then
			table.insert(list, child)
		end
	end
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #list - MAX_TOASTS + 1 do
		list[i]:Destroy()
	end
	toastOrder += 1
	local item = panel({ Size = UDim2.fromOffset(440, 34), LayoutOrder = toastOrder, Parent = toasts, BackgroundTransparency = 0.15, Radius = 17 })
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
local function bigAnnounce(message: string, color: Color3?, kind: string?)
	announceId += 1
	local id = announceId
	announce.Text = message
	announce.TextColor3 = color or TEXT
	announce.TextTransparency = 0
	announceStroke.Transparency = 0
	announce.Size = UDim2.fromOffset(560, 36)
	local big = kind == "Multi" or kind == "Ace" or kind == "Streak"
	TweenService:Create(announce, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = if big then UDim2.fromOffset(820, 60) else UDim2.fromOffset(700, 46) }):Play()
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

---------------------------------------------------------------- Oben: Punktestand, Zeit, Drachen und Ziele

local scoreBar = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(340, 62), Parent = root, Radius = 18 })
local dawnKills = text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(70, 30), Text = "0", Font = TITLE, TextColor3 = Config.Teams[1].Color, Parent = scoreBar })
local duskKills = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 6), Size = UDim2.fromOffset(70, 30), Text = "0", Font = TITLE, TextColor3 = Config.Teams[2].Color, Parent = scoreBar })
local timerLabel = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.fromOffset(110, 24), Text = "0:00", Font = TITLE, Parent = scoreBar })
local towersLabel = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(120, 14), Text = "", Font = SMALL, TextColor3 = MUTED, Parent = scoreBar })
local dawnDrakes = text({ Position = UDim2.fromOffset(12, 40), Size = UDim2.fromOffset(100, 16), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Font = SMALL, Parent = scoreBar })
local duskDrakes = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 40), Size = UDim2.fromOffset(100, 16), Text = "", TextXAlignment = Enum.TextXAlignment.Right, Font = SMALL, Parent = scoreBar })
local objectives = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(340, 18), Text = "", Font = SMALL, TextColor3 = TEXT, Outline = 1, RichText = true, Parent = root })

---------------------------------------------------------------- Oben links: Heldenkarte, Items, Werte, Buffs

local heroCard = panel({ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(268, 92), Parent = root })
local heroPortraitHolder = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, Parent = heroCard }) :: Frame
local levelBadge = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(64, 66), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 0, BackgroundColor3 = INK, Text = "1", Font = TITLE, TextColor3 = GOLD, Parent = heroCard, Children = { round(), line(0.3, GOLD, 1.5) } })
local heroName = text({ Position = UDim2.fromOffset(84, 5), Size = UDim2.fromOffset(176, 18), Text = "", TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = heroCard })
local hpBack = create("Frame", { Position = UDim2.fromOffset(84, 27), Size = UDim2.fromOffset(174, 17), BackgroundColor3 = Color3.fromRGB(8, 10, 20), Parent = heroCard }, { corner(6) }) :: Frame
local hpFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GREEN, Parent = hpBack }, { corner(6), create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)) }) }) :: Frame
local hpText = text({ Size = UDim2.fromScale(1, 1), Text = "", Font = SMALL, Parent = hpBack, Outline = 1 })
local manaBack = create("Frame", { Position = UDim2.fromOffset(84, 47), Size = UDim2.fromOffset(174, 13), BackgroundColor3 = Color3.fromRGB(8, 10, 20), Parent = heroCard }, { corner(5) }) :: Frame
local manaFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(70, 140, 255), Parent = manaBack }, { corner(5) }) :: Frame
local manaText = text({ Size = UDim2.fromScale(1, 1), Text = "", Font = SMALL, Parent = manaBack, Outline = 1 })
local xpBack = create("Frame", { Position = UDim2.fromOffset(84, 64), Size = UDim2.fromOffset(174, 5), BackgroundColor3 = Color3.fromRGB(8, 10, 20), Parent = heroCard }, { round() }) :: Frame
local xpFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(190, 140, 255), Parent = xpBack }, { round() }) :: Frame
local csLabel = text({ Position = UDim2.fromOffset(84, 72), Size = UDim2.fromOffset(110, 16), Text = "", TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Font = SMALL, Parent = heroCard })
local crystalsLabel = text({ Position = UDim2.fromOffset(170, 72), Size = UDim2.fromOffset(90, 16), Text = "", TextColor3 = CRYSTAL, TextXAlignment = Enum.TextXAlignment.Right, Font = SMALL, Parent = heroCard })

local itemBar = create("Frame", { Position = UDim2.fromOffset(10, 106), Size = UDim2.fromOffset(268, 34), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5) }),
}) :: Frame
local itemSlots = {}
for i = 1, Config.MaxItems do
	local slot = panel({ Size = UDim2.fromOffset(34, 34), LayoutOrder = i, Parent = itemBar, Radius = 8, BackgroundTransparency = 0.25 })
	itemSlots[i] = text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = "", Parent = slot })
end
local trinket = panel({ Size = UDim2.fromOffset(34, 34), LayoutOrder = 10, Parent = itemBar, Radius = 17, BackgroundTransparency = 0.25 })
local trinketLabel = text({ Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.1), Text = "👁", Parent = trinket })

-- Shop-Knopf mit Gold wie im Original, daneben die Anzeigetafel
local shopButton = button({ Position = UDim2.fromOffset(10, 146), Size = UDim2.fromOffset(150, 34), Text = "🛒 500", Parent = root, MaxText = 20 }, "Gold")
local shopBadge = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0, BackgroundColor3 = RED, Text = "!", Font = TITLE, Visible = false, Parent = shopButton, Children = { round() } })
local scoreButton = button({ Position = UDim2.fromOffset(166, 146), Size = UDim2.fromOffset(52, 34), Text = "📋", Parent = root, MaxText = 20 }, "Dark")
local autoLevelButton = button({ Position = UDim2.fromOffset(224, 146), Size = UDim2.fromOffset(54, 34), Text = "⬆", Parent = root, MaxText = 20 }, "Dark")
autoLevelButton.Activated:Connect(function()
	remotes.LevelUp:FireServer("Auto")
end)

local statsLabel = text({ Position = UDim2.fromOffset(12, 186), Size = UDim2.fromOffset(266, 32), Text = "", Font = SMALL, TextColor3 = TEXT, TextScaled = false, TextSize = 13, TextWrapped = true, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Outline = 1, Parent = root })
local buffRow = create("Frame", { Position = UDim2.fromOffset(10, 222), Size = UDim2.fromOffset(268, 26), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }),
}) :: Frame

local function renderBuffs(textValue: string)
	if buffRow:GetAttribute("Key") == textValue then
		return
	end
	buffRow:SetAttribute("Key", textValue)
	for _, child in buffRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, part in string.split(textValue, ",") do
		local id = string.split(part, ":")[1]
		local buff = Config.Buffs[id]
		if buff then
			local chip = text({ Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 0.2, BackgroundColor3 = buff.Color, Text = buff.Icon, Parent = buffRow, Children = { round(), line(0.3, Color3.new(1, 1, 1), 1) } })
			chip.Name = id
		end
	end
end

---------------------------------------------------------------- Oben rechts: Minimap, Menue und Kill-Feed

local MAP = Config.Map
local HALF = MAP.Half
local MINI = 170
local minimap = panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(MINI + 8, MINI + 8), Parent = root, Radius = 12 })
local miniField = create("TextButton", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(MINI, MINI), BackgroundColor3 = Color3.fromRGB(52, 92, 58), ClipsDescendants = true, AutoButtonColor = false, Text = "", Parent = minimap }, { corner(9) }) :: TextButton

local function mapSign(): number
	return if player:GetAttribute("Team") == 2 then -1 else 1
end

-- Weltposition -> Minimap (eigene Basis unten links, wie die Kamera)
local function miniScale(position: Vector3): (number, number)
	local sign = mapSign()
	return math.clamp((position.X * sign + HALF) / (HALF * 2), 0, 1), math.clamp((position.Z * sign + HALF) / (HALF * 2), 0, 1)
end
local function toMini(position: Vector3): UDim2
	local u, v = miniScale(position)
	return UDim2.fromScale(u, v)
end

-- Tippen oder Rechtsklick auf die Minimap: dorthin laufen
miniField.InputBegan:Connect(function(input)
	local t = input.UserInputType
	if t ~= Enum.UserInputType.MouseButton2 and t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then
		return
	end
	local p, s = miniField.AbsolutePosition, miniField.AbsoluteSize
	local u = (input.Position.X - p.X) / s.X
	local v = (input.Position.Y - p.Y) / s.Y
	local sign = mapSign()
	Controls.MoveTo(Vector3.new((u * 2 * HALF - HALF) * sign, 0, (v * 2 * HALF - HALF) * sign))
end)

local miniStatic = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = miniField }) :: Frame
local function drawMiniStatic()
	miniStatic:ClearAllChildren()
	local function segment(a: Vector3, b: Vector3, width: number, color: Color3)
		local au, av = miniScale(a)
		local bu, bv = miniScale(b)
		local ax, ay, bx, by = au * MINI, av * MINI, bu * MINI, bv * MINI
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
	-- Fluss quer durch die Mitte
	segment(Vector3.new(-HALF, 0, -HALF), Vector3.new(HALF, 0, HALF), 10, Color3.fromRGB(70, 150, 200))
	for _, name in MAP.LaneOrder do
		local points = MAP.Lanes[name]
		for i = 1, #points - 1 do
			segment(points[i], points[i + 1], 6, Color3.fromRGB(196, 176, 136))
		end
	end
	for team = 1, 2 do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = toMini(MAP.Fountain[team]), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = teamColor(team), BackgroundTransparency = 0.35, Parent = miniStatic }, { round() })
		for _, camp in MAP.Camps do
			create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = toMini(Config.Mirror(camp.Position, team)), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = Color3.fromRGB(30, 50, 34), Parent = miniStatic }, { round() })
		end
	end
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = toMini(MAP.DragonPit), Size = UDim2.fromOffset(16, 16), Text = "🐉", Parent = miniStatic })
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = toMini(MAP.BaronPit), Size = UDim2.fromOffset(16, 16), Text = "👁", Parent = miniStatic })
end

local miniDots = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = miniField }) :: Frame
local dotPool: { TextLabel } = {}
local DOT_SIZE = { Hero = 14, Nexus = 12, Inhibitor = 9, Tower = 8, Monster = 6, Ward = 6, Minion = 4 }
local function updateMinimap()
	local used = 0
	local myTeam = player:GetAttribute("Team")
	for _, model in CollectionService:GetTagged("Unit") do
		local kind = model:GetAttribute("Kind")
		local unitRoot = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: BasePart?
		local team = model:GetAttribute("Team")
		if kind and unitRoot and (model:GetAttribute("HP") or 0) > 0 and (Vision.Seen(model) or kind == "Tower" or kind == "Inhibitor" or kind == "Nexus") then
			if kind == "Ward" and team ~= myTeam then
				continue
			end
			used += 1
			local dot = dotPool[used]
			if not dot then
				dot = text({ AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundTransparency = 0, Text = "", Font = SMALL, Parent = miniDots, Children = { round(), line(0.2, Color3.new(0, 0, 0), 1) } })
				dotPool[used] = dot
			end
			local size = DOT_SIZE[kind] or 5
			local isMe = model == player.Character
			dot.Size = UDim2.fromOffset(size, size)
			dot.Position = toMini(unitRoot.Position)
			dot.BackgroundColor3 = if isMe then Color3.new(1, 1, 1) elseif team == 0 then Bars.NEUTRAL elseif team == myTeam then Bars.ALLY else Bars.ENEMY
			dot.ZIndex = if kind == "Hero" then 5 elseif kind == "Minion" then 3 else 4
			local hero = kind == "Hero" and Config.HeroesById[model:GetAttribute("HeroId") or ""]
			dot.Text = if hero then hero.Icon else ""
			dot.Visible = true
		end
	end
	for i = used + 1, #dotPool do
		dotPool[i].Visible = false
	end
end

local menu = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, MINI + 22), Size = UDim2.fromOffset(252, 40), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: Frame

local function menuButton(icon: string, _label: string, color: Color3, order: number)
	local holder = create("TextButton", { Size = UDim2.fromOffset(32, 36), BackgroundColor3 = INK, BackgroundTransparency = 0.1, LayoutOrder = order, Text = "", AutoButtonColor = true, Parent = menu }, { corner(10), line(0.5, color, 2) }) :: TextButton
	text({ Size = UDim2.fromScale(0.8, 0.7), Position = UDim2.fromScale(0.1, 0.15), Text = icon, Parent = holder })
	local badge = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 0, BackgroundColor3 = RED, Text = "!", Font = TITLE, Visible = false, Parent = holder, Children = { round() } })
	return holder, badge
end

local storeButton = menuButton("💎", "STORE", CRYSTAL, 1)
local heroesButton = menuButton("🦸", "HEROES", GOLD, 2)
local skinsButton = menuButton("🎨", "SKINS", Color3.fromRGB(255, 140, 200), 3)
local dailyButton, dailyBadge = menuButton("🎁", "DAILY", GREEN, 4)
local adButton = menuButton("🎬", "FREE 💎", Color3.fromRGB(255, 170, 80), 5)
adButton.Visible = false
local questsButton, questsBadge = menuButton("📜", "QUESTS", GREEN, 6)
local moreButton = menuButton("☰", "MORE", TEXT, 7)

-- Fortschritts-Fenster (Quests, Erfolge, Profil, Bestenliste, Codes, Einstellungen, Anleitung)
Menus.Build({
	window = window,
	openWindow = openWindow,
	closeWindows = closeWindows,
	isOpen = function(name: string): boolean
		return openName == name
	end,
	refreshers = refreshers,
	lift = lift,
	toast = toast,
})
questsButton.Activated:Connect(function()
	openWindow("Quests")
end)
moreButton.Activated:Connect(function()
	openWindow("More")
end)

-- Pings und Emotes (links unter den Buffs, auch am Handy erreichbar)
local function popupRow(y: number): Frame
	return create("Frame", { Position = UDim2.fromOffset(102, y), Size = UDim2.fromOffset(260, 40), BackgroundTransparency = 1, Visible = false, Parent = root }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: Frame
end
local pingButton = button({ Position = UDim2.fromOffset(10, 256), Size = UDim2.fromOffset(42, 40), Text = "📍", Parent = root, MaxText = 22 }, "Dark")
local emoteButton = button({ Position = UDim2.fromOffset(56, 256), Size = UDim2.fromOffset(42, 40), Text = "😄", Parent = root, MaxText = 22 }, "Dark")
local pingRow = popupRow(256)
local emoteRow = popupRow(256)
for index, ping in Config.Pings do
	local b = button({ LayoutOrder = index, Size = UDim2.fromOffset(46, 40), Text = ping.Icon, Parent = pingRow, MaxText = 22 }, "Dark")
	b.Activated:Connect(function()
		pingRow.Visible = false
		remotes.Ping:FireServer(ping.Id)
	end)
end
for index, emote in Config.Emotes do
	local b = button({ LayoutOrder = index, Size = UDim2.fromOffset(40, 40), Text = emote.Icon, Parent = emoteRow, MaxText = 22 }, "Dark")
	b.Activated:Connect(function()
		emoteRow.Visible = false
		remotes.Emote:FireServer(emote.Id)
	end)
end
pingButton.Activated:Connect(function()
	emoteRow.Visible = false
	pingRow.Visible = not pingRow.Visible
end)
emoteButton.Activated:Connect(function()
	pingRow.Visible = false
	emoteRow.Visible = not emoteRow.Visible
end)

-- Ping eines Mitspielers: Markierung in der Welt und auf der Minimap
local function showPing(info)
	local ping = typeof(info) == "table" and Config.PingsById[info.Id]
	if not ping or typeof(info.At) ~= "Vector3" then
		return
	end
	Fx.Ping(info.At, ping.Icon, ping.Color)
	local marker = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = toMini(info.At), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 0.1, BackgroundColor3 = ping.Color, Text = ping.Icon, ZIndex = 7, Parent = miniField, Children = { round(), line(0.1, Color3.new(1, 1, 1), 1.5) } })
	task.delay(4, function()
		marker:Destroy()
	end)
	toast(`{info.Name}: {ping.Icon} {ping.Text}`, ping.Color)
	Sounds.Play("Ping")
end

local killFeed = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -196, 0, 8), Size = UDim2.fromOffset(250, 170), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4) }),
}) :: Frame

local function addKill(info)
	local mine = player:GetAttribute("Team")
	local entry = panel({ Size = UDim2.fromOffset(240, 26), Parent = killFeed, BackgroundTransparency = 0.2, Radius = 13 })
	local killerHero = Config.HeroesById[info.KillerHero or ""]
	local victimHero = Config.HeroesById[info.VictimHero or ""]
	local function colorFor(team)
		return if team == mine then Bars.ALLY elseif team == 0 then Bars.NEUTRAL else Bars.ENEMY
	end
	text({ Position = UDim2.fromOffset(8, 3), Size = UDim2.fromOffset(104, 20), Text = (if killerHero then killerHero.Icon .. " " else "") .. tostring(info.Killer), TextColor3 = colorFor(info.KillerTeam), TextXAlignment = Enum.TextXAlignment.Left, Font = SMALL, Parent = entry })
	text({ Position = UDim2.fromOffset(110, 3), Size = UDim2.fromOffset(20, 20), Text = "⚔", Parent = entry })
	text({ Position = UDim2.fromOffset(130, 3), Size = UDim2.fromOffset(104, 20), Text = (if victimHero then victimHero.Icon .. " " else "") .. tostring(info.Victim), TextColor3 = colorFor(info.VictimTeam), TextXAlignment = Enum.TextXAlignment.Right, Font = SMALL, Parent = entry })
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

-- Rueckruf- und Teleport-Balken
local recallBar = panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -112), Size = UDim2.fromOffset(240, 30), Visible = false, Parent = root, Radius = 15 })
local recallFill = create("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0, 0, 1, -8), BackgroundColor3 = CRYSTAL, Parent = recallBar }, { round() }) :: Frame
text({ Size = UDim2.fromScale(1, 1), Text = "RECALLING...", Font = BODY, Parent = recallBar, Outline = 1.5 })

-- Kapitulation: Abstimmung im eigenen Team
local votePanel = panel({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 30), Size = UDim2.fromOffset(220, 84), Visible = false, Parent = root })
local voteText = text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 34), Text = "", Font = BODY, TextWrapped = true, Parent = votePanel })
local voteYes = button({ Position = UDim2.new(0, 10, 1, -38), Size = UDim2.new(0.5, -15, 0, 30), Text = "YES", Parent = votePanel }, "Red")
local voteNo = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 1, -38), Size = UDim2.new(0.5, -15, 0, 30), Text = "NO", Parent = votePanel }, "Dark")
local myVote: boolean? = nil
voteYes.Activated:Connect(function()
	myVote = true
	remotes.Surrender:FireServer(true)
end)
voteNo.Activated:Connect(function()
	myVote = false
	remotes.Surrender:FireServer(false)
end)

---------------------------------------------------------------- Item-Shop wie im Original: Stufen, Rezepte, Empfehlungen

local shopWindow, shopBody = window("Shop", "ITEM SHOP", 800, 470, GOLD)
local shopGold = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -60, 0, 16), Size = UDim2.fromOffset(160, 26), Text = "", TextColor3 = GOLD, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Right, Parent = shopWindow })
local shopTabs = create("Frame", { Size = UDim2.new(0, 500, 0, 30), BackgroundTransparency = 1, Parent = shopBody }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: Frame
local itemGrid = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(0, 500, 1, -38), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BorderSizePixel = 0, Parent = shopBody }, {
	create("UIGridLayout", { CellSize = UDim2.fromOffset(116, 80), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: ScrollingFrame
local shopDetail = panel({ Position = UDim2.fromOffset(512, 0), Size = UDim2.new(1, -512, 1, 0), Parent = shopBody, BackgroundColor3 = INK2, Radius = 12 })

local STAT_NAMES = {
	{ "AD", "AD" }, { "AP", "AP" }, { "HP", "Health" }, { "Mana", "Mana" }, { "Armor", "Armor" }, { "MR", "Magic Resist" },
	{ "AS", "% Attack Speed", 100 }, { "Crit", "% Crit Chance", 100 }, { "MS", "Move Speed" }, { "AH", "Ability Haste" },
	{ "Lifesteal", "% Life Steal", 100 }, { "Lethality", "Lethality" }, { "MagicPen", "Magic Pen" }, { "MagicPenPct", "% Magic Pen", 100 },
	{ "HPRegen", "HP Regen" }, { "ManaRegen", "Mana Regen" },
}
local function statText(stats): string
	local parts = {}
	for _, info in STAT_NAMES do
		local value = stats and stats[info[1]]
		if value then
			table.insert(parts, `+{math.floor(value * (info[3] or 1) * 10 + 0.5) / 10} {info[2]}`)
		end
	end
	return table.concat(parts, "\n")
end

local buildsInto: { [string]: { string } } = {}
for _, item in Config.Items do
	for _, component in item.From do
		buildsInto[component] = buildsInto[component] or {}
		if not table.find(buildsInto[component], item.Id) then
			table.insert(buildsInto[component], item.Id)
		end
	end
end

local shopTab = "Recommended"
local selectedItem: string? = nil
local selectedSlot: number? = nil
local renderShop: () -> ()

local function myItems(): { string }
	local list = {}
	for _, id in string.split(player:GetAttribute("Items") or "", ",") do
		if Config.ItemsById[id] then
			table.insert(list, id)
		end
	end
	return list
end

local function itemIcon(parent: Instance, id: string, size: number, order: number?, onClick: (() -> ())?)
	local item = Config.ItemsById[id]
	local b = create("TextButton", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = INK3, Text = item.Icon, TextScaled = true, Font = BODY, TextColor3 = TEXT, LayoutOrder = order or 0, AutoButtonColor = true, Parent = parent }, { corner(8), line(0.6) }) :: TextButton
	b.Activated:Connect(function()
		if onClick then
			onClick()
		else
			selectedItem = id
			selectedSlot = nil
			renderShop()
		end
	end)
	return b
end

local function renderDetailItem()
	shopDetail:ClearAllChildren()
	corner(12).Parent = shopDetail
	local items = myItems()
	local gold = player:GetAttribute("Gold") or 0
	local canShop = player:GetAttribute("CanShop") == true
	-- Eigene Items (antippen zum Auswaehlen und Verkaufen)
	text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 16), Text = `YOUR ITEMS  ·  🧪 x{player:GetAttribute("Potions") or 0}`, Font = SMALL, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
	local row = create("Frame", { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 36), BackgroundTransparency = 1, Parent = shopDetail }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }),
	})
	for slot, id in items do
		itemIcon(row, id, 36, slot, function()
			selectedItem = id
			selectedSlot = slot
			renderShop()
		end)
	end
	local id = selectedItem
	if not id then
		text({ Position = UDim2.fromOffset(10, 80), Size = UDim2.new(1, -20, 0, 60), Text = if canShop then "Pick an item to see what it does." else "Shop at your fountain or while dead. Press B to recall!", TextColor3 = if canShop then MUTED else RED, Font = SMALL, TextWrapped = true, TextScaled = false, TextSize = 15, Parent = shopDetail })
	else
		local item = Config.ItemsById[id]
		local price = Config.PriceFor(items, id)
		text({ Position = UDim2.fromOffset(10, 70), Size = UDim2.fromOffset(44, 44), Text = item.Icon, Parent = shopDetail })
		text({ Position = UDim2.fromOffset(60, 70), Size = UDim2.new(1, -70, 0, 22), Text = item.Name, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
		text({ Position = UDim2.fromOffset(60, 94), Size = UDim2.new(1, -70, 0, 18), Text = if price < item.Cost then `💰 {price}  (total {item.Cost})` else `💰 {item.Cost}`, TextColor3 = if gold >= price then GOLD else RED, Font = BODY, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
		local body = statText(item.Stats)
		if item.Desc then
			body = body .. (if body ~= "" then "\n" else "") .. `<font color="#FFC94A">{item.Desc}</font>`
		end
		text({ Position = UDim2.fromOffset(10, 120), Size = UDim2.new(1, -20, 0, 120), Text = body, RichText = true, TextScaled = false, TextSize = 14, TextWrapped = true, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = shopDetail })
		-- Rezept: woraus und wozu
		local y = 244
		if #item.From > 0 then
			text({ Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(90, 16), Text = "BUILDS FROM", Font = SMALL, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
			local from = create("Frame", { Position = UDim2.fromOffset(10, y + 18), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1, Parent = shopDetail }, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }) })
			for index, component in item.From do
				itemIcon(from, component, 30, index)
			end
			y += 52
		end
		local into = buildsInto[id]
		if into then
			text({ Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(90, 16), Text = "BUILDS INTO", Font = SMALL, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
			local list = create("Frame", { Position = UDim2.fromOffset(10, y + 18), Size = UDim2.new(1, -20, 0, 30), BackgroundTransparency = 1, Parent = shopDetail }, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }) })
			for index, other in into do
				if index <= 7 then
					itemIcon(list, other, 30, index)
				end
			end
		end
		if selectedSlot then
			local sell = button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -48), Size = UDim2.new(1, -20, 0, 34), Text = `SELL  +{math.floor(item.Cost * Config.SellRefund)} 💰`, Parent = shopDetail }, "Red")
			local slot = selectedSlot
			sell.Activated:Connect(function()
				remotes.SellItem:FireServer(slot)
				selectedSlot = nil
			end)
		else
			local buy = button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -48), Size = UDim2.new(1, -20, 0, 34), Text = `BUY  {price} 💰`, Parent = shopDetail }, if canShop and gold >= price then "Gold" else "Dark")
			buy.Activated:Connect(function()
				remotes.BuyItem:FireServer(id)
			end)
		end
	end
	local auto = button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -8), Size = UDim2.new(0.5, -14, 0, 32), Text = if player:GetAttribute("AutoBuy") then "AUTO: ON" else "AUTO: OFF", Parent = shopDetail, MaxText = 16 }, "Dark")
	auto.Activated:Connect(function()
		remotes.SetAutoBuy:FireServer(not player:GetAttribute("AutoBuy"))
	end)
	local nextButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -8), Size = UDim2.new(0.5, -14, 0, 32), Text = "BUY NEXT", Parent = shopDetail, MaxText = 16 }, "Crystal")
	nextButton.Activated:Connect(function()
		remotes.BuyItem:FireServer("Auto")
	end)
	lift(shopDetail, 22)
end

local function tabItems(): { string }
	local list = {}
	if shopTab == "Recommended" then
		local hero = Config.HeroesById[player:GetAttribute("Hero") or player:GetAttribute("PickedHero") or ""]
		if hero then
			for _, id in hero.Build.Start do
				table.insert(list, id)
			end
			if player:GetAttribute("Role") == "Jungle" and not table.find(list, "HuntersMachete") then
				table.insert(list, 1, "HuntersMachete")
			end
			for _, id in hero.Build.Items do
				table.insert(list, id)
			end
		end
	else
		for _, item in Config.Items do
			if item.Tier == shopTab then
				table.insert(list, item.Id)
			end
		end
	end
	return list
end

function renderShop()
	local gold = player:GetAttribute("Gold") or 0
	shopGold.Text = "💰 " .. Format.Number(gold)
	local items = myItems()
	for _, child in itemGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, id in tabItems() do
		local item = Config.ItemsById[id]
		local price = Config.PriceFor(items, id)
		local has = table.find(items, id) ~= nil
		local card = create("TextButton", { LayoutOrder = index, BackgroundColor3 = if selectedItem == id then INK3 elseif has then Color3.fromRGB(36, 64, 50) else INK, Text = "", AutoButtonColor = true, Parent = itemGrid }, { corner(10), line(if selectedItem == id then 0 else 0.8, if selectedItem == id then GOLD else Color3.new(1, 1, 1), 1.5) }) :: TextButton
		text({ Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(34, 34), Text = item.Icon, Parent = card })
		text({ Position = UDim2.fromOffset(44, 6), Size = UDim2.new(1, -48, 0, 32), Text = item.Name, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Font = SMALL, Parent = card })
		text({ Position = UDim2.fromOffset(6, 46), Size = UDim2.new(1, -12, 0, 16), Text = `💰 {price}`, TextColor3 = if gold >= price then GOLD else Color3.fromRGB(200, 120, 120), TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = card })
		text({ Position = UDim2.fromOffset(6, 62), Size = UDim2.new(1, -12, 0, 12), Text = if shopTab == "Recommended" then item.Tier else "", TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Font = SMALL, Parent = card })
		card.Activated:Connect(function()
			if selectedItem == id and not selectedSlot then
				-- Zweimal antippen = kaufen
				remotes.BuyItem:FireServer(id)
			end
			selectedItem = id
			selectedSlot = nil
			renderShop()
		end)
	end
	renderDetailItem()
	lift(shopWindow, 22)
end

local shopTabButtons = {}
for index, name in { "Recommended", "Starter", "Basic", "Epic", "Boots", "Legendary" } do
	local tab = button({ LayoutOrder = index, Size = UDim2.fromOffset(if index == 1 then 108 else 74, 30), Text = string.upper(name), Parent = shopTabs, MaxText = 14 }, "Dark")
	tab.Activated:Connect(function()
		shopTab = name
		for other, b in shopTabButtons do
			b.BackgroundColor3 = if other == name then GOLD else INK3
			b.TextColor3 = if other == name then INK else TEXT
		end
		renderShop()
	end)
	shopTabButtons[name] = tab
end
shopTabButtons.Recommended.BackgroundColor3 = GOLD
shopTabButtons.Recommended.TextColor3 = INK

refreshers.Shop = renderShop
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
			local card = storeCard(hero.Order, string.upper(hero.Name), hero.Title .. " · " .. table.concat(hero.Roles, "/"), hero.Color, hero.Icon)
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


---------------------------------------------------------------- Anzeigetafel (Tab)

local scoreWindow, scoreBody = window("Score", "SCOREBOARD", 820, 470, TEXT)
local function buildScoreboard()
	scoreBody:ClearAllChildren()
	local heroes = match:FindFirstChild("Heroes")
	local myTeam = player:GetAttribute("Team")
	for team = 1, 2 do
		local column = create("Frame", { Position = UDim2.fromOffset(0, (team - 1) * 184), Size = UDim2.new(1, 0, 0, 180), BackgroundTransparency = 1, Parent = scoreBody }, {
			create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local drakes = {}
		for _, id in string.split(match:GetAttribute("Drakes" .. team) or "", ",") do
			local drake = Config.DrakesById[id]
			if drake then
				table.insert(drakes, drake.Icon)
			end
		end
		text({ Size = UDim2.new(1, 0, 0, 22), Text = `{string.upper(Config.Teams[team].Name)}  ·  {match:GetAttribute("Kills" .. team) or 0} kills  ·  {match:GetAttribute("Towers" .. team) or 0} towers  {table.concat(drakes, "")}`, Font = TITLE, TextColor3 = teamColor(team), TextXAlignment = Enum.TextXAlignment.Left, Parent = column, LayoutOrder = 0 })
		local list = {}
		for _, entry in (heroes and heroes:GetChildren() or {}) do
			if entry:GetAttribute("Team") == team then
				table.insert(list, entry)
			end
		end
		table.sort(list, function(a, b)
			local ra = Config.RolesById[a:GetAttribute("Role") or ""]
			local rb = Config.RolesById[b:GetAttribute("Role") or ""]
			return (if ra then ra.Order else 9) < (if rb then rb.Order else 9)
		end)
		for order, entry in list do
			local isMe = entry:GetAttribute("UserId") == player.UserId
			local row = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = if isMe then INK3 else INK2, LayoutOrder = order, Parent = column }, { corner(8) })
			local dead = entry:GetAttribute("Dead")
			portrait(row, entry:GetAttribute("HeroId"), 24, UDim2.fromOffset(3, 2))
			text({ Position = UDim2.fromOffset(30, 4), Size = UDim2.fromOffset(22, 20), Text = tostring(entry:GetAttribute("Level") or 1), Font = TITLE, TextColor3 = GOLD, Parent = row })
			local role = Config.RolesById[entry:GetAttribute("Role") or ""]
			local name = (if role then role.Icon .. " " else "") .. tostring(entry:GetAttribute("Name")) .. (if entry:GetAttribute("IsBot") then " 🤖" else "")
			if dead then
				name ..= `  💀{math.max(0, math.ceil((entry:GetAttribute("RespawnAt") or 0) - now()))}`
			end
			local title = entry:GetAttribute("Title")
			if typeof(title) == "string" and title ~= "" then
				name ..= `  <font color="#FFCD5A">«{title}»</font>`
			end
			text({ Position = UDim2.fromOffset(56, 4), Size = UDim2.fromOffset(170, 20), Text = name, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if dead then MUTED else TEXT, Font = BODY, Parent = row })
			-- Zauber nur fuer das eigene Team sichtbar (wie im Original sieht man sie aber auch beim Gegner)
			local spellD = Config.SpellsById[entry:GetAttribute("SpellD") or ""]
			local spellF = Config.SpellsById[entry:GetAttribute("SpellF") or ""]
			text({ Position = UDim2.fromOffset(230, 4), Size = UDim2.fromOffset(44, 20), Text = (if spellD then spellD.Icon else "") .. (if spellF then spellF.Icon else ""), Parent = row })
			local items = {}
			for _, id in string.split(entry:GetAttribute("Items") or "", ",") do
				local item = Config.ItemsById[id]
				if item then
					table.insert(items, item.Icon)
				end
			end
			text({ Position = UDim2.fromOffset(280, 4), Size = UDim2.fromOffset(200, 20), Text = table.concat(items, " "), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			text({ Position = UDim2.fromOffset(490, 4), Size = UDim2.fromOffset(100, 20), Text = `{entry:GetAttribute("Kills") or 0} / {entry:GetAttribute("Deaths") or 0} / {entry:GetAttribute("Assists") or 0}`, Font = BODY, Parent = row })
			text({ Position = UDim2.fromOffset(596, 4), Size = UDim2.fromOffset(70, 20), Text = `CS {entry:GetAttribute("CS") or 0}`, TextColor3 = MUTED, Font = SMALL, Parent = row })
			text({ Position = UDim2.fromOffset(670, 4), Size = UDim2.fromOffset(100, 20), Text = if team == myTeam then `💰 {Format.Number(entry:GetAttribute("Worth") or 0)}` else "", TextColor3 = GOLD, Font = SMALL, Parent = row })
		end
	end
	-- Kapitulieren (ab Minute 8)
	local started = match:GetAttribute("StartedAt") or 0
	local allowed = started > 0 and now() - started >= Config.Timers.Surrender
	local surrender = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(190, 28), Text = if allowed then "🏳 SURRENDER" else `🏳 at {Format.Time(Config.Timers.Surrender)}`, Parent = scoreBody, MaxText = 16 }, if allowed then "Red" else "Dark")
	surrender.Activated:Connect(function()
		if allowed then
			myVote = true
			remotes.Surrender:FireServer(true)
			closeWindows()
		end
	end)
	text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.fromOffset(560, 22), Text = "Right-click: move/attack · Q W E R: hold to aim · Ctrl+Q: level up · D F: spells · B: recall · 4: ward · 1: potion", TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = scoreBody })
	lift(scoreWindow, 22)
end
refreshers.Score = buildScoreboard
scoreButton.Activated:Connect(function()
	openWindow("Score")
end)

---------------------------------------------------------------- Heldenwahl: Rolle, Held, Beschwoererzauber

local pick = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.12, Visible = false, ZIndex = 10, Parent = root }) :: Frame
local pickGradient = create("UIGradient", { Rotation = 25, Parent = pick }) :: UIGradient
local pickBox = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(950, 520), BackgroundTransparency = 1, Parent = pick }) :: Frame
text({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(500, 40), Text = "CHAMPION SELECT", Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Parent = pickBox, Outline = 3 })
local pickTeam = text({ Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(560, 20), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = pickBox })
local pickTimer = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(120, 56), Text = "30", Font = TITLE, TextColor3 = GOLD, Parent = pickBox, Outline = 3 })
local roleRow = create("Frame", { Position = UDim2.fromOffset(0, 68), Size = UDim2.fromOffset(580, 34), BackgroundTransparency = 1, Parent = pickBox }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: Frame
local pickGrid = create("Frame", { Position = UDim2.fromOffset(0, 112), Size = UDim2.fromOffset(580, 264), BackgroundTransparency = 1, Parent = pickBox }, {
	create("UIGridLayout", { CellSize = UDim2.fromOffset(90, 128), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: Frame
local spellPicker = panel({ Position = UDim2.fromOffset(0, 112), Size = UDim2.fromOffset(580, 264), Visible = false, Parent = pickBox, ZIndex = 12 })
local detail = panel({ Position = UDim2.fromOffset(596, 68), Size = UDim2.fromOffset(354, 446), Parent = pickBox, Radius = 16 })
local teamStrip = create("Frame", { Position = UDim2.fromOffset(0, 388), Size = UDim2.fromOffset(580, 126), BackgroundTransparency = 1, Parent = pickBox }, {
	create("UIGridLayout", { CellSize = UDim2.fromOffset(186, 38), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
}) :: Frame

local selectedHero = "Brakka"
local pickCards = {}
local roleButtons = {}
local spellSlot = "D"
local renderDetail: () -> ()

local function renderRoles()
	local mine = player:GetAttribute("Role")
	for id, b in roleButtons do
		b.BackgroundColor3 = if id == mine then GOLD else INK3
		b.TextColor3 = if id == mine then INK else TEXT
	end
end

for _, role in Config.Roles do
	local b = button({ LayoutOrder = role.Order, Size = UDim2.fromOffset(110, 34), Text = `{role.Icon} {string.upper(role.Name)}`, Parent = roleRow, MaxText = 16 }, "Dark")
	b.Activated:Connect(function()
		remotes.PickRole:FireServer(role.Id)
	end)
	roleButtons[role.Id] = b
end

-- Auswahl der Beschwoererzauber (ersetzt kurz das Heldenraster)
local function openSpellPicker(slot: string)
	spellSlot = slot
	spellPicker:ClearAllChildren()
	corner(14).Parent = spellPicker
	text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 26), Text = `SUMMONER SPELL ({slot})`, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD, Parent = spellPicker })
	local grid = create("Frame", { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 1, -54), BackgroundTransparency = 1, Parent = spellPicker }, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(132, 100), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for _, spell in Config.Spells do
		local current = player:GetAttribute("Spell" .. slot) == spell.Id
		local card = create("TextButton", { LayoutOrder = spell.Order, BackgroundColor3 = if current then INK3 else INK2, Text = "", AutoButtonColor = true, Parent = grid }, { corner(10), line(if current then 0 else 0.8, if current then GOLD else Color3.new(1, 1, 1), 1.5) }) :: TextButton
		text({ Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(30, 30), Text = spell.Icon, Parent = card })
		text({ Position = UDim2.fromOffset(40, 8), Size = UDim2.new(1, -46, 0, 20), Text = spell.Name, TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = card })
		text({ Position = UDim2.fromOffset(6, 38), Size = UDim2.new(1, -12, 1, -42), Text = spell.Desc, TextColor3 = MUTED, Font = SMALL, TextScaled = false, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		card.Activated:Connect(function()
			remotes.PickSpell:FireServer(spellSlot, spell.Id)
			spellPicker.Visible = false
		end)
	end
	spellPicker.Visible = true
	lift(spellPicker, 12)
end

function renderDetail()
	detail:ClearAllChildren()
	corner(16).Parent = detail
	line(0.85).Parent = detail
	local hero = Config.HeroesById[selectedHero]
	portrait(detail, hero.Id, 64, UDim2.fromOffset(12, 12))
	text({ Position = UDim2.fromOffset(86, 12), Size = UDim2.fromOffset(250, 30), Text = string.upper(hero.Name), Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = hero.Color, Parent = detail, Outline = 2 })
	local roles = {}
	for _, id in hero.Roles do
		local role = Config.RolesById[id]
		table.insert(roles, if role then role.Icon .. " " .. role.Name else id)
	end
	local masteryLevel = Config.MasteryLevel(Menus.MasteryPoints(Menus.Profile(), hero.Id))
	text({ Position = UDim2.fromOffset(86, 44), Size = UDim2.fromOffset(250, 16), Text = `{hero.Title}  ·  {hero.Class or ""}  ·  ⭐ Mastery {masteryLevel}`, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	text({ Position = UDim2.fromOffset(86, 60), Size = UDim2.fromOffset(250, 16), Text = table.concat(roles, "   "), TextColor3 = GOLD, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	local stats = hero.Stats
	local bars = { { "Health", stats.HP / 680 }, { "Attack", stats.AD / 68 }, { "Range", stats.Range / 26 }, { "Speed", (stats.Speed - 300) / 60 } }
	for i, info in bars do
		local y = 84 + (i - 1) * 14
		text({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(54, 12), Text = info[1], TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		local back = create("Frame", { Position = UDim2.fromOffset(70, y + 3), Size = UDim2.fromOffset(270, 6), BackgroundColor3 = INK3, Parent = detail }, { round() })
		create("Frame", { Size = UDim2.fromScale(math.clamp(info[2], 0.08, 1), 1), BackgroundColor3 = hero.Color, Parent = back }, { round() })
	end
	-- Passiv + Faehigkeiten
	local rows = { { "P", hero.Passive.Name, hero.Passive.Desc } }
	for _, key in Config.AbilityKeys do
		local ability = hero.Abilities[key]
		table.insert(rows, { key, ability.Name, ability.Desc })
	end
	for i, info in rows do
		local y = 146 + (i - 1) * 36
		text({ Position = UDim2.fromOffset(12, y), Size = UDim2.fromOffset(26, 26), Text = info[1], Font = TITLE, BackgroundTransparency = 0, BackgroundColor3 = INK3, TextColor3 = GOLD, Parent = detail, Children = { corner(7) } })
		text({ Position = UDim2.fromOffset(46, y - 2), Size = UDim2.fromOffset(296, 15), Text = info[2], TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = detail })
		text({ Position = UDim2.fromOffset(46, y + 13), Size = UDim2.fromOffset(296, 18), Text = info[3], TextColor3 = MUTED, Font = SMALL, TextScaled = false, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = detail })
	end
	-- Beschwoererzauber D und F
	text({ Position = UDim2.fromOffset(12, 330), Size = UDim2.fromOffset(200, 14), Text = "SUMMONER SPELLS", TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	for index, slot in { "D", "F" } do
		local spell = Config.SpellsById[player:GetAttribute("Spell" .. slot) or ""]
		local b = button({ Position = UDim2.fromOffset(12 + (index - 1) * 168, 348), Size = UDim2.fromOffset(162, 36), Text = `{slot}: {if spell then spell.Icon .. " " .. spell.Name else "?"}`, Parent = detail, MaxText = 16 }, "Dark")
		b.Activated:Connect(function()
			openSpellPicker(slot)
		end)
	end
	local ownedHero = owned(player:GetAttribute("OwnedHeroes"), hero.Id)
	local takenBy = nil
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Team") == player:GetAttribute("Team") and other:GetAttribute("PickedHero") == hero.Id and other:GetAttribute("Locked") then
			takenBy = other.DisplayName
		end
	end
	if takenBy then
		text({ Position = UDim2.fromOffset(12, 396), Size = UDim2.new(1, -24, 0, 38), Text = `Already picked by {takenBy}`, TextColor3 = RED, Font = BODY, Parent = detail })
	elseif ownedHero then
		local locked = player:GetAttribute("Locked") and player:GetAttribute("PickedHero") == hero.Id
		local lock = button({ Position = UDim2.fromOffset(12, 396), Size = UDim2.new(1, -24, 0, 38), Text = if locked then "✔ LOCKED IN" else "LOCK IN", Parent = detail }, "Gold")
		lock.Activated:Connect(function()
			remotes.PickHero:FireServer(hero.Id, true)
		end)
	else
		local crystals = button({ Position = UDim2.fromOffset(12, 396), Size = UDim2.new(0.5, -16, 0, 38), Text = `💎 {hero.Crystals}`, Parent = detail }, "Crystal")
		crystals.Activated:Connect(function()
			remotes.UnlockHero:FireServer(hero.Id)
		end)
		local key = "Hero_" .. hero.Id
		if Config.Products[key] then
			local robux = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 396), Size = UDim2.new(0.5, -16, 0, 38), Text = ` {Config.Products[key].Price} R$`, Parent = detail }, "Robux")
			robux.Activated:Connect(function()
				buyProduct(key)
			end)
		end
	end
	lift(detail, 11)
end

local function renderPickCards()
	local heroes = player:GetAttribute("OwnedHeroes")
	local role = player:GetAttribute("Role")
	local taken = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Team") == player:GetAttribute("Team") and other:GetAttribute("Locked") then
			taken[other:GetAttribute("PickedHero") or ""] = true
		end
	end
	local profile = Menus.Profile()
	for id, card in pickCards do
		local hero = Config.HeroesById[id]
		local has = owned(heroes, id)
		local masteryLabel = card:FindFirstChild("Mastery") :: TextLabel
		local level = Config.MasteryLevel(Menus.MasteryPoints(profile, id))
		masteryLabel.Text = `M{level}`
		masteryLabel.Visible = level > 1
		local picked = player:GetAttribute("PickedHero") == id
		local stroke = card:FindFirstChild("Stroke") :: UIStroke
		stroke.Color = if picked then GOLD elseif selectedHero == id then TEXT else Color3.new(1, 1, 1)
		stroke.Transparency = if picked or selectedHero == id then 0 else 0.85
		stroke.Thickness = if picked then 3 else 2
		local lockLabel = card:FindFirstChild("Lock") :: TextLabel
		lockLabel.Visible = not has or taken[id] == true
		lockLabel.Text = if taken[id] then "TAKEN" else `🔒 💎{hero.Crystals}`
		local fits = role == nil or table.find(hero.Roles, role) ~= nil
		card.BackgroundColor3 = if has and not taken[id] then INK2 else Color3.fromRGB(20, 22, 36)
		card.BackgroundTransparency = if fits then 0 else 0.5
	end
end

for _, hero in Config.Heroes do
	local card = create("TextButton", { LayoutOrder = hero.Order, BackgroundColor3 = INK2, Text = "", AutoButtonColor = true, Parent = pickGrid }, { corner(12) }) :: TextButton
	create("UIStroke", { Name = "Stroke", Thickness = 2, Transparency = 0.85, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
	create("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = hero.Color, Parent = card }, {
		corner(12),
		create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(90, 90, 110)), Transparency = NumberSequence.new(0, 0.3) }),
	})
	text({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 54), Text = hero.Icon, Parent = card })
	text({ Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 22), Text = string.upper(hero.Name), Font = TITLE, Parent = card })
	local icons = {}
	for _, id in hero.Roles do
		local role = Config.RolesById[id]
		table.insert(icons, if role then role.Icon else id)
	end
	text({ Position = UDim2.fromOffset(4, 102), Size = UDim2.new(1, -8, 0, 18), Text = table.concat(icons, " "), Font = SMALL, Parent = card })
	text({ Name = "Mastery", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 54), Size = UDim2.fromOffset(34, 16), BackgroundTransparency = 0.2, BackgroundColor3 = INK, Text = "", Font = SMALL, TextColor3 = GOLD, Visible = false, Parent = card, Children = { round() } })
	text({ Name = "Lock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(84, 20), BackgroundTransparency = 0.2, BackgroundColor3 = INK, Text = "", Font = BODY, TextColor3 = CRYSTAL, Parent = card, Children = { round() } })
	card.Activated:Connect(function()
		selectedHero = hero.Id
		spellPicker.Visible = false
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
		table.insert(parts, `{other.UserId}:{other:GetAttribute("Team")}:{other:GetAttribute("PickedHero")}:{other:GetAttribute("Locked")}:{other:GetAttribute("Role")}`)
	end
	local key = table.concat(parts, "|")
	if key == teamStripKey then
		return
	end
	teamStripKey = key
	for _, child in teamStrip:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local taken = {}
	local count = 0
	for _, other in Players:GetPlayers() do
		if other:GetAttribute("Team") == myTeam then
			count += 1
			local role = Config.RolesById[other:GetAttribute("Role") or ""]
			if role then
				taken[role.Id] = true
			end
			local chip = panel({ LayoutOrder = if role then role.Order else 9, Parent = teamStrip, Radius = 19 })
			portrait(chip, other:GetAttribute("PickedHero") or "Brakka", 30, UDim2.fromOffset(4, 4))
			text({ Position = UDim2.fromOffset(40, 3), Size = UDim2.fromOffset(140, 16), Text = (if role then role.Icon .. " " else "") .. other.DisplayName, TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = chip })
			text({ Position = UDim2.fromOffset(40, 20), Size = UDim2.fromOffset(140, 14), Text = if other:GetAttribute("Locked") then "✔ Locked in" else "Choosing...", TextColor3 = if other:GetAttribute("Locked") then GREEN else MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = chip })
		end
	end
	for _, role in Config.Roles do
		if not taken[role.Id] and count < Config.TeamSize then
			count += 1
			local chip = panel({ LayoutOrder = role.Order, Parent = teamStrip, Radius = 19, BackgroundTransparency = 0.5 })
			text({ Size = UDim2.fromScale(1, 1), Text = `{role.Icon} {role.Name} · 🤖 Bot`, TextColor3 = MUTED, Font = BODY, Parent = chip })
		end
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

local result = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(540, 400), Visible = false, ZIndex = 15, Parent = root, Radius = 20 })
local resultTitle = text({ Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 64), Text = "VICTORY", Font = TITLE, Parent = result, Outline = 4 })
local resultStats = text({ Position = UDim2.fromOffset(20, 86), Size = UDim2.new(1, -40, 0, 26), Text = "", Parent = result })
local resultCrystals = text({ Position = UDim2.fromOffset(20, 124), Size = UDim2.new(1, -40, 0, 44), Text = "", Font = TITLE, TextColor3 = CRYSTAL, Parent = result, Outline = 2 })
local resultBreakdown = text({ Position = UDim2.fromOffset(20, 172), Size = UDim2.new(1, -40, 0, 40), Text = "", TextColor3 = MUTED, Font = SMALL, TextScaled = false, TextSize = 15, TextWrapped = true, Parent = result })
local resultProgress = text({ Position = UDim2.fromOffset(20, 214), Size = UDim2.new(1, -40, 0, 54), Text = "", TextColor3 = TEXT, Font = SMALL, TextScaled = false, TextSize = 15, TextWrapped = true, RichText = true, Parent = result })
local resultNext = text({ Position = UDim2.fromOffset(20, 276), Size = UDim2.new(1, -40, 0, 20), Text = "", TextColor3 = MUTED, Font = SMALL, Parent = result })
-- Schliessen-Knopf: vorher blieb das Ergebnis bis zur naechsten Heldenwahl ueber dem Bildschirm
local resultClose = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(36, 36), Text = "✕", Parent = result, Radius = 18 }, "Dark")
resultClose.Activated:Connect(function()
	result.Visible = false
end)
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
	if (info.StreakBonus or 0) > 0 then
		table.insert(parts, `🔥 Win streak {info.Streak} +{info.StreakBonus}`)
	end
	if info.MVP then
		table.insert(parts, `⭐ MVP +{info.MVPBonus}`)
	end
	if info.Multiplier > 1 then
		table.insert(parts, `Pass bonus x{info.Multiplier}`)
	end
	resultBreakdown.Text = table.concat(parts, "   ·   ")
	-- Fortschritt: Meisterschaft, Kontostufe, Quests, Erfolge
	local progress = if typeof(info.Progress) == "table" then info.Progress else {}
	local lines = {}
	local masteryHero = Config.HeroesById[progress.MasteryHero or ""]
	if masteryHero and progress.MasteryGained then
		table.insert(lines, `{masteryHero.Icon} Mastery +{progress.MasteryGained} · M{progress.MasteryLevel}` .. (if progress.MasteryUp then ` <font color="#FFCD5A">LEVEL UP!</font>` else ""))
	end
	if progress.AccountXP then
		table.insert(lines, `⭐ +{progress.AccountXP} XP · Level {progress.AccountLevel}` .. (if progress.AccountUp then ` <font color="#FFCD5A">LEVEL UP!</font>` else ""))
	end
	if (progress.QuestsDone or 0) > 0 then
		table.insert(lines, `📜 {progress.QuestsDone} quest{if progress.QuestsDone > 1 then "s" else ""} done`)
	end
	if typeof(progress.Achievements) == "table" and #progress.Achievements > 0 then
		table.insert(lines, `🏆 {table.concat(progress.Achievements, ", ")}`)
	end
	if not info.MVP and typeof(info.MVPName) == "string" and info.MVPName ~= "" then
		table.insert(lines, `⭐ Team MVP: {info.MVPName}`)
	end
	resultProgress.Text = table.concat(lines, "   ·   ")
	Sounds.Play(if info.Won then "Victory" else "Defeat")
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

local ROLE_TIPS = {
	Top = "Hold the top lane alone. Teleport (D/F) brings you back fast.",
	Jungle = "Clear camps, Smite (D/F) big monsters, gank lanes and take dragons.",
	Mid = "Push the middle lane, then help your side lanes.",
	Bot = "Farm minions with your support. Last hits give gold!",
	Support = "Protect your Bot laner and place wards with 4.",
}

local function timerText(icon: string, at: number?, t: number): string?
	if not at or at == 0 then
		return nil
	end
	local left = at - t
	if left <= 0 then
		return `{icon} <font color="#6EE7A0">UP</font>`
	end
	return `{icon} {Format.Time(left)}`
end

local function drakeIcons(team: number): string
	local list = {}
	for _, id in string.split(match:GetAttribute("Drakes" .. team) or "", ",") do
		local drake = Config.DrakesById[id]
		if drake then
			table.insert(list, drake.Icon)
		end
	end
	local soul = Config.DrakesById[match:GetAttribute("Soul" .. team) or ""]
	if soul then
		table.insert(list, " SOUL")
	end
	return table.concat(list, "")
end

local lastPhase = nil
local guideShown = false
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
			spellPicker.Visible = false
			renderDetail()
			renderPickCards()
			renderRoles()
		elseif phase == "Playing" then
			local role = player:GetAttribute("Role")
			if role and ROLE_TIPS[role] then
				toast(`{role}: {ROLE_TIPS[role]}`, GOLD)
			end
			myVote = nil
			drawMiniStatic()
		end
	end

	pick.Visible = phase == "Pick"
	if pick.Visible then
		local info = Config.Teams[myTeam or 1]
		pickTeam.Text = `You fight for {string.upper(info.Name)} · pick a role, a champion and two spells`
		pickTeam.TextColor3 = info.Color
		pickGradient.Color = ColorSequence.new(info.Dark:Lerp(INK, 0.4), INK)
		pickTimer.Text = tostring(math.max(0, math.ceil((match:GetAttribute("PhaseEnd") or t) - t)))
		renderTeamStrip()
	end

	-- Anzeigen, die nur in der Runde Sinn ergeben
	scoreBar.Visible = playing or phase == "End"
	objectives.Visible = playing
	heroCard.Visible = inMatch
	itemBar.Visible = inMatch
	shopButton.Visible = inMatch
	scoreButton.Visible = inMatch
	autoLevelButton.Visible = inMatch and (player:GetAttribute("SkillPoints") or 0) > 0
	statsLabel.Visible = inMatch
	buffRow.Visible = inMatch
	minimap.Visible = inMatch
	killFeed.Visible = inMatch
	menu.Visible = not pick.Visible
	pingButton.Visible = playing and heroId ~= nil
	emoteButton.Visible = pingButton.Visible
	if not pingButton.Visible then
		pingRow.Visible = false
		emoteRow.Visible = false
	end
	questsBadge.Visible = (player:GetAttribute("QuestsReady") or 0) > 0

	-- Anleitung einmal pro Sitzung fuer neue Spieler
	if not guideShown and player:GetAttribute("TutorialDone") == false and phase ~= "Pick" and openName == nil and not result.Visible then
		guideShown = true
		openWindow("Guide")
	end

	-- Punktestand und Ziele
	dawnKills.Text = tostring(match:GetAttribute("Kills1") or 0)
	duskKills.Text = tostring(match:GetAttribute("Kills2") or 0)
	local started = match:GetAttribute("StartedAt") or 0
	timerLabel.Text = if started > 0 then Format.Time(t - started) else "0:00"
	towersLabel.Text = `🗼 {match:GetAttribute("Towers1") or 0} : {match:GetAttribute("Towers2") or 0}`
	dawnDrakes.Text = drakeIcons(1)
	duskDrakes.Text = drakeIcons(2)
	local nextDrake = Config.DrakesById[match:GetAttribute("NextDrake") or ""]
	local parts = {}
	for _, part in {
		timerText(if nextDrake then nextDrake.Icon else "🐉", match:GetAttribute("DrakeAt"), t),
		timerText("🦀 Herald", match:GetAttribute("HeraldAt"), t),
		timerText("👁 Baron", match:GetAttribute("BaronAt"), t),
	} do
		if part then
			table.insert(parts, part)
		end
	end
	objectives.Text = table.concat(parts, "    ")
	if phase == "End" then
		local winner = match:GetAttribute("Winner") or 0
		timerLabel.Text = if winner == myTeam then "WIN" else "END"
		resultNext.Text = `Next match in {math.max(0, math.ceil((match:GetAttribute("PhaseEnd") or t) - t))}s`
	end

	-- Abstimmung zum Aufgeben
	local vote = myTeam and match:GetAttribute("Vote" .. myTeam)
	votePanel.Visible = playing and typeof(vote) == "string" and vote ~= ""
	if votePanel.Visible then
		local ends = match:GetAttribute("VoteEnds" .. myTeam) or t
		voteText.Text = `Surrender? {vote} · {math.max(0, math.ceil(ends - t))}s`
		voteYes.Visible = myVote == nil
		voteNo.Visible = myVote == nil
	else
		myVote = nil
	end

	-- Heldenkarte
	if heroId then
		local hero = Config.HeroesById[heroId]
		if heroPortraitHolder:GetAttribute("Hero") ~= heroId then
			heroPortraitHolder:ClearAllChildren()
			portrait(heroPortraitHolder, heroId, 64)
			heroPortraitHolder:SetAttribute("Hero", heroId)
		end
		local role = Config.RolesById[player:GetAttribute("Role") or ""]
		heroName.Text = `{hero.Name}  <font color="#9AA3B8">{if role then role.Icon .. " " .. role.Name else ""}</font>`
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
		local mana = player:GetAttribute("Mana") or 0
		local maxMana = player:GetAttribute("MaxMana") or 0
		manaBack.Visible = maxMana > 0
		manaFill.Size = UDim2.fromScale(if maxMana > 0 then math.clamp(mana / maxMana, 0, 1) else 0, 1)
		manaText.Text = `{math.floor(mana)} / {math.floor(maxMana)}`
		local need = player:GetAttribute("XPNeed") or 0
		xpFill.Size = UDim2.fromScale(if need > 0 then math.clamp((player:GetAttribute("XP") or 0) / need, 0, 1) else 1, 1)
		csLabel.Text = `⚔ {player:GetAttribute("Kills") or 0}/{player:GetAttribute("Deaths") or 0}/{player:GetAttribute("Assists") or 0}  🪓 {player:GetAttribute("CS") or 0}`
		local items = string.split(player:GetAttribute("Items") or "", ",")
		for i, slot in itemSlots do
			local item = Config.ItemsById[items[i] or ""]
			slot.Text = if item then item.Icon else ""
		end
		trinketLabel.Text = `👁{player:GetAttribute("Wards") or 0}`
		local gold = player:GetAttribute("Gold") or 0
		shopButton.Text = "🛒 " .. Format.Number(gold)
		-- Werte wie im Original (unten links)
		statsLabel.Text = `⚔ {player:GetAttribute("AD") or 0}  ✨ {player:GetAttribute("AP") or 0}  🛡 {player:GetAttribute("Armor") or 0}  🔮 {player:GetAttribute("MR") or 0}\n⚡ {player:GetAttribute("AttackSpeed") or 0}  🎯 {player:GetAttribute("Crit") or 0}%  ⏱ {player:GetAttribute("AH") or 0}  👟 {player:GetAttribute("MoveSpeed") or 0}`
		local buffs = player:GetAttribute("Buffs") or ""
		local souls = player:GetAttribute("Souls") or 0
		renderBuffs(buffs .. (if souls > 0 then `,Souls:{souls}` else ""))
		-- Shop-Hinweis: genug Gold fuer das naechste empfohlene Teil
		local cheapest = math.huge
		for _, id in hero.Build.Items do
			if not table.find(items, id) then
				cheapest = math.min(cheapest, (Config.PriceFor(items, id)))
				break
			end
		end
		shopBadge.Visible = player:GetAttribute("CanShop") == true and gold >= math.min(cheapest, 300) and #items < Config.MaxItems
		-- Rueckruf
		local recallUntil = player:GetAttribute("RecallUntil") or 0
		recallBar.Visible = recallUntil > t
		if recallBar.Visible then
			local total = if string.find(buffs, "Baron") then Config.BaronRecallSeconds else Config.RecallSeconds
			recallFill.Size = UDim2.new(math.clamp(1 - (recallUntil - t) / total, 0, 1), -8, 1, -8)
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
		local key = `{player:GetAttribute("Gold")}|{player:GetAttribute("Items")}|{player:GetAttribute("CanShop")}|{player:GetAttribute("AutoBuy")}|{player:GetAttribute("Potions")}`
		if shopWindow:GetAttribute("Key") ~= key then
			shopWindow:SetAttribute("Key", key)
			renderShop()
		end
	elseif openName == "Score" then
		scoreWindow:SetAttribute("Tick", (scoreWindow:GetAttribute("Tick") or 0) + 1)
		if (scoreWindow:GetAttribute("Tick") or 0) % 10 == 0 then
			buildScoreboard()
		end
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
	remotes.Announce.OnClientEvent:Connect(function(message, color, kind)
		bigAnnounce(message, color, kind)
	end)
	remotes.KillFeed.OnClientEvent:Connect(function(info)
		addKill(info)
		-- Ueber die UserId vergleichen: gleiche Anzeigenamen (oder ein Bot mit meinem Namen) loesten sonst falsche Ansagen aus
		if info.VictimUserId == player.UserId and info.VictimHero then
			bigAnnounce("YOU HAVE BEEN SLAIN", RED)
			Sounds.Play("Slain")
		elseif info.KillerUserId == player.UserId and info.VictimHero then
			bigAnnounce("YOU HAVE SLAIN AN ENEMY", GOLD)
			Sounds.Play("Kill")
		end
	end)
	remotes.MatchResult.OnClientEvent:Connect(showResult)
	remotes.Ping.OnClientEvent:Connect(showPing)
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
	for _, attribute in { "PickedHero", "Locked", "Role", "SpellD", "SpellF", "Profile" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if pick.Visible then
				renderDetail()
				renderPickCards()
				renderRoles()
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

	-- Tastatur: P = Shop, Tab = Anzeigetafel (halten), Esc schliesst Fenster
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.P then
			openWindow("Shop")
		elseif key == Enum.KeyCode.Tab then
			if openName ~= "Score" then
				openWindow("Score")
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Tab and openName == "Score" then
			closeWindows()
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
