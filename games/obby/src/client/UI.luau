-- Baut das komplette HUD per Code: Stage-Karte, Skip-Button, Menue, Shop, Trails, Quests, Titel,
-- Einstellungen/Codes/Emotes/Statistik, Coins, Speedrun-Timer, Meldungen und Banner.
-- Alles ist fuer eine Basisgroesse von 1000x560 gebaut und wird per UIScale an den Bildschirm angepasst (Handy bis PC).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

-- Zustand vom Server (Quests, Erfolge, Einstellungen, Statistik); nil bis zum ersten Sync
UI.State = nil :: any
local stateListeners = {} :: { (any) -> () }

function UI.OnState(callback: (any) -> ())
	table.insert(stateListeners, callback)
	if UI.State then
		task.spawn(callback, UI.State)
	end
end

local function emitState()
	for _, listener in stateListeners do
		task.spawn(listener, UI.State)
	end
end

-- Einstellung lesen (vor dem ersten Sync gilt der Standardwert)
function UI.GetSetting(key: string): boolean
	local state = UI.State
	if state and state.Settings and state.Settings[key] ~= nil then
		return state.Settings[key]
	end
	local setting = Config.SettingsByKey[key]
	return setting ~= nil and setting.Default
end

local THEME = {
	Panel = Color3.fromRGB(24, 22, 38),
	Row = Color3.fromRGB(38, 35, 58),
	Text = Color3.fromRGB(255, 255, 255),
	Muted = Color3.fromRGB(190, 186, 214),
	Ink = Color3.fromRGB(16, 12, 28),
	Green = Color3.fromRGB(46, 204, 113),
	GreenDark = Color3.fromRGB(28, 150, 80),
	Gold = Color3.fromRGB(255, 190, 40),
	Blue = Color3.fromRGB(64, 156, 255),
	Purple = Color3.fromRGB(150, 90, 255),
	Red = Color3.fromRGB(235, 70, 80),
	Gray = Color3.fromRGB(88, 86, 104),
}
local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSansBold
local BODY_HEAVY = Enum.Font.BuilderSansExtraBold

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

-- Duenne, helle Kante fuer Panels
local function edge(transparency: number?)
	return create("UIStroke", { Thickness = 1.5, Color = Color3.new(1, 1, 1), Transparency = transparency or 0.82, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props)
	props.BackgroundTransparency = 1
	props.Font = props.Font or BODY
	props.TextSize = props.TextSize or 18
	props.TextColor3 = props.TextColor3 or THEME.Text
	local outline = props.Outline
	props.Outline = nil
	local label = create("TextLabel", props)
	if outline then
		create("UIStroke", { Thickness = outline, Color = THEME.Ink, Transparency = 0.15, Parent = label })
	end
	return label
end

local function shade(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function button(props, color: Color3)
	props.BackgroundColor3 = color
	props.Font = props.Font or BODY_HEAVY
	props.TextSize = props.TextSize or 20
	props.TextColor3 = THEME.Text
	props.AutoButtonColor = true
	local b = create("TextButton", props, {
		corner(12),
		create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)), Rotation = 90 }),
		create("UIStroke", { Thickness = 2, Color = shade(color, 0.45), ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	})
	create("UIStroke", { Thickness = 1.5, Color = THEME.Ink, Transparency = 0.5, Parent = b })
	return b
end

---------------------------------------------------------------- Kaufen

local function productId(key: string): number
	local fromServer = ReplicatedStorage:GetAttribute("ProductId_" .. key)
	if fromServer and fromServer ~= 0 then
		return fromServer
	end
	local pass = Config.GamePasses[key]
	if pass then
		return pass.ProductId
	end
	local product = Config.DevProducts[key]
	return if product then product.Id else 0
end

local function price(key: string, hint: number): number
	return ReplicatedStorage:GetAttribute("Price_" .. key) or hint
end

-- kind = "Pass" oder "Product"
function UI.Buy(kind: string, key: string)
	if kind == "Pass" and player:GetAttribute("Pass_" .. key) then
		return
	end
	local id = productId(key)
	if id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	else
		-- Nur in Studio wirksam (Server prueft das)
		remotes.FakePurchase:FireServer(kind, key)
	end
end

---------------------------------------------------------------- Meldungen

local toastContainer: Frame
local announceFrame: Frame
local announceLabel: TextLabel
local bannerFrame: Frame
local bannerTitle: TextLabel
local bannerSub: TextLabel

function UI.Toast(message: string, color: Color3?)
	local toasts = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= 4 then
		toasts[1]:Destroy()
	end
	local pill = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.12,
		Parent = toastContainer,
	}, { corner(18), edge(), create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }) })
	local label = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = message, TextSize = 18, TextColor3 = color or THEME.Text, Parent = pill })
	task.delay(3.5, function()
		TweenService:Create(pill, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		pill:Destroy()
	end)
end

local announceToken = 0
local function showAnnouncement(message: string, color: Color3?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = message
	announceLabel.TextColor3 = color or THEME.Text
	announceFrame.Visible = true
	task.delay(5, function()
		if token == announceToken then
			announceFrame.Visible = false
		end
	end)
end

-- Grosser Banner in der Mitte (neue Welt, Sieg)
local bannerToken = 0
function UI.Banner(title: string, subtitle: string, color: Color3)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerSub.Text = subtitle
	bannerFrame.Visible = true
	local scale = bannerFrame:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.4
	bannerTitle.TextTransparency = 0
	bannerSub.TextTransparency = 0
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(2.6, function()
		if token ~= bannerToken then
			return
		end
		TweenService:Create(bannerTitle, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(bannerSub, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.45)
		if token == bannerToken then
			bannerFrame.Visible = false
		end
	end)
end

---------------------------------------------------------------- Fenster

local windows = {}

local function window(parent: Instance, title: string, accent: Color3)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(540, 430),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = parent,
	}, { corner(18), edge(0.75) })
	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = accent, Parent = frame }, {
		corner(18),
		create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)), Rotation = 90 }),
	})
	-- untere Ecken des Headers gerade machen
	create("Frame", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = header })
	text({ Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -80, 1, 0), Text = title, Font = TITLE, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Outline = 2, ZIndex = 2, Parent = header })
	local close = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(40, 40), Text = "✕", TextSize = 20, ZIndex = 2, Parent = header }, THEME.Red)
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 70),
		Size = UDim2.new(1, -28, 1, -84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = THEME.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }), create("UIPadding", { PaddingRight = UDim.new(0, 8) }) })
	table.insert(windows, frame)
	return frame, list
end

local function toggle(frame: Frame)
	local show = not frame.Visible
	for _, other in windows do
		other.Visible = false
	end
	frame.Visible = show
	if show then
		local scale = frame:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = frame })
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
end

local function sortedEntries(source)
	local list = {}
	for key, entry in source do
		table.insert(list, { Key = key, Entry = entry })
	end
	table.sort(list, function(a, b)
		return (a.Entry.Order or 99) < (b.Entry.Order or 99)
	end)
	return list
end

local function section(parent: Instance, title: string, color: Color3, order: number)
	text({ Size = UDim2.new(1, 0, 0, 26), Text = string.upper(title), Font = BODY_HEAVY, TextSize = 16, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = parent })
end

local function row(parent: Instance, title: string, description: string, order: number)
	local frame = create("Frame", {
		Size = UDim2.new(1, 0, 0, 66),
		BackgroundColor3 = THEME.Row,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(12), edge(0.88) })
	local titleLabel = text({ Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -170, 0, 26), Text = title, Font = BODY_HEAVY, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
	local descriptionLabel = text({
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -170, 0, 20),
		Text = description,
		TextSize = 15,
		TextColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	return frame, titleLabel, descriptionLabel
end

local function rowButton(frame: Frame, color: Color3)
	return button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(132, 44),
		Text = "",
		TextSize = 19,
		Parent = frame,
	}, color)
end

local function buildShopRow(parent: Instance, kind: string, key: string, entry, color: Color3, order: number)
	local frame = row(parent, entry.Name, entry.Description, order)
	local buy = rowButton(frame, color)
	local function refresh()
		if kind == "Pass" and player:GetAttribute("Pass_" .. key) then
			buy.Text = "OWNED"
			buy.BackgroundColor3 = THEME.Gray
			buy.Active = false
		else
			buy.Text = "R$ " .. price(key, entry.PriceHint)
		end
	end
	refresh()
	player:GetAttributeChangedSignal("Pass_" .. key):Connect(refresh)
	ReplicatedStorage:GetAttributeChangedSignal("Price_" .. key):Connect(refresh)
	buy.Activated:Connect(function()
		UI.Buy(kind, key)
	end)
end

local function hasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

local function ownedTrails(): { [string]: boolean }?
	return UI.State and UI.State.OwnedTrails
end

local function unlockText(trail): string
	local unlock = trail.Unlock
	if unlock.Coins then
		return `Buy for {Format.Number(unlock.Coins)} coins`
	elseif unlock.Pass == "VIP" then
		return "VIP exclusive"
	elseif unlock.Pass then
		return "Trail Pack"
	elseif unlock.Wins then
		return `Win the obby {unlock.Wins}x`
	end
	return `Reach stage {unlock.Best}`
end

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

local function buildTrailRow(parent: Instance, trail)
	local frame = row(parent, trail.Name, unlockText(trail), trail.Order)
	-- Farbvorschau als Streifen links
	local swatch = create("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, { corner(3), create("UIGradient", { Color = colorSequence(trail.Colors), Rotation = 90 }) })
	swatch.Position = UDim2.fromOffset(4, 0)
	local action = rowButton(frame, THEME.Green)
	local function refresh()
		local unlocked = Config.TrailUnlocked(trail, player:GetAttribute("BestStage") or 1, player:GetAttribute("Wins") or 0, hasPass, ownedTrails())
		if player:GetAttribute("Trail") == trail.Id then
			action.Text = "EQUIPPED"
			action.BackgroundColor3 = THEME.Gray
		elseif unlocked then
			action.Text = "EQUIP"
			action.BackgroundColor3 = THEME.Green
		elseif trail.Unlock.Coins then
			action.Text = "🪙 " .. Format.Number(trail.Unlock.Coins)
			action.BackgroundColor3 = if (player:GetAttribute("Coins") or 0) >= trail.Unlock.Coins then THEME.Gold else THEME.Gray
		elseif trail.Unlock.Pass then
			action.Text = "UNLOCK"
			action.BackgroundColor3 = THEME.Gold
		else
			action.Text = "🔒 LOCKED"
			action.BackgroundColor3 = THEME.Gray
		end
	end
	refresh()
	for _, attribute in { "Trail", "BestStage", "Wins", "Pass_VIP", "Pass_TrailPack", "Coins" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	UI.OnState(refresh)
	action.Activated:Connect(function()
		local unlocked = Config.TrailUnlocked(trail, player:GetAttribute("BestStage") or 1, player:GetAttribute("Wins") or 0, hasPass, ownedTrails())
		if unlocked then
			remotes.EquipTrail:FireServer(trail.Id)
		elseif trail.Unlock.Coins then
			if (player:GetAttribute("Coins") or 0) >= trail.Unlock.Coins then
				remotes.BuyTrail:FireServer(trail.Id)
			else
				UI.Toast(`You need {Format.Number(trail.Unlock.Coins)} coins. Play, do quests or get coins in the Shop!`, THEME.Gold)
			end
		elseif trail.Unlock.Pass then
			UI.Buy("Pass", trail.Unlock.Pass)
		end
	end)
end

---------------------------------------------------------------- Start

local skipButton: TextButton
local skipScale: UIScale
local skipPulse: Tween?

-- Skip-Button aufleuchten lassen, wenn jemand an einer Stage festhaengt
function UI.HighlightSkip()
	if skipPulse then
		return
	end
	local tween = TweenService:Create(skipScale, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 7, true), { Scale = 1.12 })
	skipPulse = tween
	tween:Play()
	tween.Completed:Once(function()
		skipScale.Scale = 1
		skipPulse = nil
	end)
end

local function menuButton(parent: Instance, icon: string, caption: string, color: Color3, order: number): TextButton
	local b = button({ Size = UDim2.fromOffset(64, 64), Text = "", LayoutOrder = order, Parent = parent }, color)
	text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 34), Text = icon, TextSize = 28, Parent = b })
	text({ Position = UDim2.new(0, 0, 1, -23), Size = UDim2.new(1, 0, 0, 18), Text = caption, Font = BODY_HEAVY, TextSize = 14, Outline = 1.5, Parent = b })
	return b
end

function UI.Start()
	local gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Wurzel mit Skalierung: Basis 1000x560
	local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local rootScale = create("UIScale", {})
	local inner = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = root })
	rootScale.Parent = inner
	local function rescale()
		local viewport = workspace.CurrentCamera.ViewportSize
		local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 560), 0.6, 1.25)
		rootScale.Scale = scale
		inner.Size = UDim2.fromOffset(viewport.X / scale, (viewport.Y - 36) / scale)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- Stage-Karte oben
	local card = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(330, 78),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.12,
		Parent = inner,
	}, { corner(16), edge() })
	local worldLabel = text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 18), Text = "", Font = BODY_HEAVY, TextSize = 15, Parent = card })
	local stageLabel = text({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 32), Text = "STAGE 1", Font = TITLE, TextSize = 30, RichText = true, Outline = 2, Parent = card })
	local bar = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.new(1, -36, 0, 10), BackgroundColor3 = Color3.fromRGB(14, 12, 24), Parent = card }, { corner(5) })
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Green, Parent = bar }, { corner(5), create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)), Rotation = 90 }) })
	-- Stage-Auswahl: zurueck zu einer frueheren Stage oder wieder vor bis zur besten
	local prevStage = button({ Position = UDim2.fromOffset(10, 18), Size = UDim2.fromOffset(38, 36), Text = "◀", TextSize = 18, Visible = false, Parent = card }, THEME.Blue)
	local nextStage = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 18), Size = UDim2.fromOffset(38, 36), Text = "▶", TextSize = 18, Visible = false, Parent = card }, THEME.Blue)
	local function refreshStageButtons()
		local stage = player:GetAttribute("Stage") or 1
		local best = player:GetAttribute("BestStage") or 1
		prevStage.Visible = stage > 1
		nextStage.Visible = stage < best
	end
	refreshStageButtons()
	player:GetAttributeChangedSignal("Stage"):Connect(refreshStageButtons)
	player:GetAttributeChangedSignal("BestStage"):Connect(refreshStageButtons)
	prevStage.Activated:Connect(function()
		local stage = player:GetAttribute("Stage") or 1
		if stage > 1 then
			remotes.SelectStage:FireServer(stage - 1)
		end
	end)
	nextStage.Activated:Connect(function()
		local stage = player:GetAttribute("Stage") or 1
		if stage < (player:GetAttribute("BestStage") or 1) then
			remotes.SelectStage:FireServer(stage + 1)
		end
	end)

	local rankChip = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 26),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.25,
		Parent = inner,
	}, { corner(13), edge(0.88), create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }) })
	local rankLabel = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "", TextSize = 15, RichText = true, Parent = rankChip })

	announceFrame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 126),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36),
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = inner,
	}, { corner(18), edge(0.7), create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }) })
	announceLabel = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "", Font = BODY_HEAVY, TextSize = 19, Parent = announceFrame })

	bannerFrame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(600, 120),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = inner,
	}, { create("UIScale", {}) })
	bannerTitle = text({ Size = UDim2.new(1, 0, 0, 74), Text = "", Font = TITLE, TextSize = 68, Outline = 4, Parent = bannerFrame })
	bannerSub = text({ Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 40), Text = "", Font = TITLE, TextSize = 34, Outline = 3, Parent = bannerFrame })

	toastContainer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(600, 170),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

	-- Skip-Button rechts: wichtigste Einnahmequelle eines Obbys
	skipButton = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.45, 0),
		Size = UDim2.fromOffset(150, 84),
		Text = "",
		Parent = inner,
	}, THEME.Green)
	skipScale = create("UIScale", { Parent = skipButton })
	text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 40), Text = "SKIP ⏭", Font = TITLE, TextSize = 34, Outline = 2, Parent = skipButton })
	local skipPrice = text({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), Text = "", Font = BODY_HEAVY, TextSize = 19, Outline = 1.5, Parent = skipButton })
	skipButton.Activated:Connect(function()
		UI.Buy("Product", "SkipStage")
	end)

	-- Menue links: 2 Spalten, damit es auf dem Handy nicht in den Bereich des Steuer-Sticks reicht
	local side = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.42, 0),
		Size = UDim2.fromOffset(136, 208),
		BackgroundTransparency = 1,
		Parent = inner,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(64, 64),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local shopButton = menuButton(side, "🛒", "Shop", THEME.Gold, 1)
	local trailButton = menuButton(side, "✨", "Trails", THEME.Purple, 2)
	local questButton = menuButton(side, "📜", "Quests", THEME.Green, 3)
	local titleButton = menuButton(side, "🏅", "Titles", THEME.Blue, 4)
	local moreButton = menuButton(side, "⚙️", "More", THEME.Gray, 5)
	-- Punkt am Quest-Knopf, wenn etwas abzuholen ist
	local questDot = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = THEME.Red,
		Visible = false,
		ZIndex = 3,
		Parent = questButton,
	}, { corner(9), create("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1) }) })

	local shop, shopList = window(inner, "Shop", THEME.Gold)
	section(shopList, "Forever", THEME.Gold, 0)
	for i, item in sortedEntries(Config.GamePasses) do
		buildShopRow(shopList, "Pass", item.Key, item.Entry, THEME.Gold, i)
	end
	section(shopList, "Skips, Coins & Trolls", THEME.Blue, 50)
	for i, item in sortedEntries(Config.DevProducts) do
		buildShopRow(shopList, "Product", item.Key, item.Entry, THEME.Blue, 50 + i)
	end

	local trails, trailList = window(inner, "Trails", THEME.Purple)
	for _, trail in Config.Trails do
		buildTrailRow(trailList, trail)
	end

	shopButton.Activated:Connect(function()
		toggle(shop)
	end)
	trailButton.Activated:Connect(function()
		toggle(trails)
	end)

	---------------------------------------------------------------- Quests + taegliche Belohnung
	local quests, questList = window(inner, "Quests", THEME.Green)
	section(questList, "Daily Reward", THEME.Gold, 0)
	local dailyRow, dailyTitle, dailyDesc = row(questList, "Daily Reward", "", 1)
	local dailyButton = rowButton(dailyRow, THEME.Gold)
	dailyButton.Activated:Connect(function()
		if UI.State and UI.State.Daily.Ready then
			remotes.ClaimDaily:FireServer()
		end
	end)
	section(questList, "Daily Quests (new every day)", THEME.Green, 10)
	local questRows = {}
	for i = 1, #Config.QuestTypes do
		local frame, title, desc = row(questList, "", "", 10 + i)
		local claim = rowButton(frame, THEME.Green)
		claim.Activated:Connect(function()
			local quest = UI.State and UI.State.Quests[i]
			if quest and not quest.Claimed and quest.Progress >= quest.Target then
				remotes.ClaimQuest:FireServer(i)
			end
		end)
		questRows[i] = { Title = title, Description = desc, Button = claim }
	end
	questButton.Activated:Connect(function()
		toggle(quests)
		if quests.Visible then
			remotes.Sync:FireServer() -- neuer Tag? Quests und Belohnung auffrischen
		end
	end)

	local function questText(quest): (string, string)
		for _, questType in Config.QuestTypes do
			if questType.Type == quest.Type then
				local target = if questType.Minutes then quest.Target // 60 else quest.Target
				local progress = if questType.Minutes then quest.Progress // 60 else quest.Progress
				return string.format(questType.Text, target), `{progress}/{target}  ·  Reward: {quest.Reward} coins`
			end
		end
		return quest.Type, ""
	end

	local dailyShown = false
	UI.OnState(function(state)
		local daily = state.Daily
		dailyTitle.Text = if daily.Ready then `Day {daily.Streak}: {daily.Reward} coins` else `Streak: {daily.Streak} day(s)`
		dailyDesc.Text = if daily.Ready then "Come back every day: day 7 gives 400 coins!" else `Come back tomorrow for {daily.Reward} coins`
		dailyButton.Text = if daily.Ready then "CLAIM" else "CLAIMED"
		dailyButton.BackgroundColor3 = if daily.Ready then THEME.Gold else THEME.Gray
		local anyReady = daily.Ready
		for i, rowInfo in questRows do
			local quest = state.Quests[i]
			if quest then
				local title, desc = questText(quest)
				rowInfo.Title.Text = title
				rowInfo.Description.Text = desc
				if quest.Claimed then
					rowInfo.Button.Text = "DONE ✓"
					rowInfo.Button.BackgroundColor3 = THEME.Gray
				elseif quest.Progress >= quest.Target then
					rowInfo.Button.Text = "CLAIM"
					rowInfo.Button.BackgroundColor3 = THEME.Green
					anyReady = true
				else
					rowInfo.Button.Text = `{math.floor(quest.Progress / quest.Target * 100)}%`
					rowInfo.Button.BackgroundColor3 = THEME.Gray
				end
			end
		end
		questDot.Visible = anyReady
		-- Beim Betreten einmal die taegliche Belohnung zeigen
		if not dailyShown then
			dailyShown = true
			if daily.Ready and UI.GetSetting("DailyPopup") and not quests.Visible then
				toggle(quests)
			end
		end
	end)

	---------------------------------------------------------------- Titel (Erfolge)
	local titles, titleList = window(inner, "Titles", THEME.Blue)
	section(titleList, "Achievements unlock name tag titles", THEME.Blue, 0)
	local noneRow = row(titleList, "No title", "Show only your rank on your name tag", 1)
	local noneButton = rowButton(noneRow, THEME.Gray)
	noneButton.Activated:Connect(function()
		if (player:GetAttribute("Title") or "") ~= "" then
			remotes.EquipTitle:FireServer("")
		end
	end)
	local titleRows = {}
	for _, achievement in Config.Achievements do
		local frame = row(titleList, achievement.Title, `{achievement.Description}  ·  +{achievement.Reward} coins`, 1 + achievement.Order)
		local equip = rowButton(frame, THEME.Blue)
		equip.Activated:Connect(function()
			if UI.State and UI.State.Achievements[achievement.Id] and player:GetAttribute("Title") ~= achievement.Id then
				remotes.EquipTitle:FireServer(achievement.Id)
			end
		end)
		titleRows[achievement.Id] = equip
	end
	titleButton.Activated:Connect(function()
		toggle(titles)
	end)
	local function refreshTitles()
		local state = UI.State
		local current = player:GetAttribute("Title") or ""
		noneButton.Text = if current == "" then "SELECTED" else "REMOVE"
		for id, equip in titleRows do
			local unlocked = state and state.Achievements[id]
			if current == id then
				equip.Text = "EQUIPPED"
				equip.BackgroundColor3 = THEME.Gray
			elseif unlocked then
				equip.Text = "EQUIP"
				equip.BackgroundColor3 = THEME.Blue
			else
				equip.Text = "🔒 LOCKED"
				equip.BackgroundColor3 = THEME.Gray
			end
		end
	end
	UI.OnState(refreshTitles)
	player:GetAttributeChangedSignal("Title"):Connect(refreshTitles)

	---------------------------------------------------------------- Mehr: Einstellungen, Codes, Emotes, Statistik
	local more, moreList = window(inner, "More", THEME.Gray)
	section(moreList, "Settings", THEME.Muted, 0)
	local settingButtons = {}
	for i, setting in Config.Settings do
		local frame = create("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = THEME.Row, LayoutOrder = i, Parent = moreList }, { corner(12), edge(0.88) })
		text({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -170, 1, 0), Text = setting.Name, Font = BODY_HEAVY, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
		local toggleButton = rowButton(frame, THEME.Green)
		toggleButton.Activated:Connect(function()
			local value = not UI.GetSetting(setting.Key)
			-- sofort lokal anwenden, der Server speichert
			if UI.State then
				UI.State.Settings[setting.Key] = value
				emitState()
			end
			remotes.SetSetting:FireServer(setting.Key, value)
		end)
		settingButtons[setting.Key] = toggleButton
	end
	local function refreshSettings()
		for key, toggleButton in settingButtons do
			local on = UI.GetSetting(key)
			toggleButton.Text = if on then "ON" else "OFF"
			toggleButton.BackgroundColor3 = if on then THEME.Green else THEME.Gray
		end
	end
	refreshSettings()
	UI.OnState(refreshSettings)

	section(moreList, "Codes", THEME.Gold, 20)
	local codeRow = create("Frame", { Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = THEME.Row, LayoutOrder = 21, Parent = moreList }, { corner(12), edge(0.88) })
	local codeBox = create("TextBox", {
		Position = UDim2.fromOffset(12, 11),
		Size = UDim2.new(1, -170, 0, 44),
		BackgroundColor3 = THEME.Panel,
		ClearTextOnFocus = false,
		PlaceholderText = "Enter code (try RAINBOW)",
		PlaceholderColor3 = THEME.Muted,
		Text = "",
		TextColor3 = THEME.Text,
		Font = BODY_HEAVY,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClipsDescendants = true,
		Parent = codeRow,
	}, { corner(10), create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	local redeem = rowButton(codeRow, THEME.Gold)
	redeem.Text = "REDEEM"
	local function submitCode()
		local code = codeBox.Text
		if code:match("%S") then
			remotes.RedeemCode:FireServer(code:sub(1, 30))
			codeBox.Text = ""
		end
	end
	redeem.Activated:Connect(submitCode)
	codeBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitCode()
		end
	end)

	section(moreList, "Emotes (R15 avatars)", THEME.Purple, 30)
	local emoteGrid = create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 31, Parent = moreList }, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(112, 50), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, emote in Config.Emotes do
		local emoteButton = button({ Text = `{emote.Icon} {emote.Name}`, TextSize = 17, LayoutOrder = i, Parent = emoteGrid }, THEME.Purple)
		emoteButton.Activated:Connect(function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then
				return
			end
			local ok, played = pcall(humanoid.PlayEmote, humanoid, emote.Id)
			if ok and played then
				more.Visible = false
			else
				UI.Toast("Emotes need an R15 avatar standing on the ground.", THEME.Red)
			end
		end)
	end

	section(moreList, "Your Stats", THEME.Blue, 40)
	local statRows = {}
	local STATS = {
		{ Key = "Wins", Name = "Wins" },
		{ Key = "BestStage", Name = "Best stage" },
		{ Key = "BestTime", Name = "Fastest run (no skips)" },
		{ Key = "Deaths", Name = "Respawns" },
		{ Key = "PlayTime", Name = "Active play time" },
		{ Key = "Gems", Name = "Rainbow gems found" },
		{ Key = "CoinsEarned", Name = "Coins earned" },
		{ Key = "Streak", Name = "Daily streak" },
	}
	for i, stat in STATS do
		local frame = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = THEME.Row, LayoutOrder = 40 + i, Parent = moreList }, { corner(10) })
		text({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0.6, -14, 1, 0), Text = stat.Name, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = frame })
		statRows[stat.Key] = text({ Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, -14, 1, 0), Text = "-", Font = BODY_HEAVY, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, Parent = frame })
	end
	UI.OnState(function(state)
		local stats = state.Stats
		statRows.Wins.Text = Format.Number(stats.Wins)
		statRows.BestStage.Text = `{stats.BestStage} / {Config.StageCount}`
		statRows.BestTime.Text = if stats.BestTime > 0 then Config.FormatRunTime(stats.BestTime) else "-"
		statRows.Deaths.Text = Format.Number(stats.Deaths)
		statRows.PlayTime.Text = string.format("%dh %02dm", stats.PlayTime // 3600, (stats.PlayTime % 3600) // 60)
		statRows.Gems.Text = `{stats.Gems} / {#Config.Worlds}`
		statRows.CoinsEarned.Text = Format.Number(stats.CoinsEarned)
		statRows.Streak.Text = `{stats.Streak} day(s)`
	end)
	moreButton.Activated:Connect(function()
		toggle(more)
		if more.Visible then
			remotes.Sync:FireServer() -- Statistik auffrischen
		end
	end)

	---------------------------------------------------------------- Coins und Speedrun-Timer (oben rechts)
	local topRight = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 8),
		Size = UDim2.fromOffset(170, 80),
		BackgroundTransparency = 1,
		Parent = inner,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function chip(order: number): (Frame, TextLabel)
		local frame = create("Frame", {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			BackgroundColor3 = THEME.Panel,
			BackgroundTransparency = 0.12,
			LayoutOrder = order,
			Parent = topRight,
		}, { corner(17), edge(), create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
		local label = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "", Font = BODY_HEAVY, TextSize = 20, Parent = frame })
		return frame, label
	end
	local _, coinLabel = chip(1)
	coinLabel.TextColor3 = Color3.fromRGB(255, 215, 80)
	local timerChip, timerLabel = chip(2)
	timerChip.Visible = false
	local function refreshCoins()
		coinLabel.Text = "🪙 " .. Format.Number(player:GetAttribute("Coins") or 0)
	end
	refreshCoins()
	player:GetAttributeChangedSignal("Coins"):Connect(refreshCoins)
	task.spawn(function()
		while gui.Parent do
			local started = player:GetAttribute("RunStart")
			local show = typeof(started) == "number" and UI.GetSetting("Timer")
			timerChip.Visible = show
			if typeof(started) == "number" and show then
				timerLabel.Text = "⏱ " .. Config.FormatRunTime(workspace:GetServerTimeNow() - started)
			end
			task.wait(0.1)
		end
	end)

	remotes.Sync.OnClientEvent:Connect(function(state)
		if typeof(state) ~= "table" then
			return
		end
		UI.State = state
		emitState()
	end)
	remotes.Sync:FireServer()


	remotes.Notify.OnClientEvent:Connect(UI.Toast)
	remotes.Announce.OnClientEvent:Connect(showAnnouncement)

	local function refreshStage()
		local stage = player:GetAttribute("Stage") or 1
		local world, worldIndex = Config.WorldForStage(stage)
		stageLabel.Text = `STAGE {stage}<font size="20" color="#BEBAD6"> / {Config.StageCount}</font>`
		worldLabel.Text = `WORLD {worldIndex}  ·  {string.upper(world.Name)}`
		worldLabel.TextColor3 = world.Accent:Lerp(Color3.new(1, 1, 1), 0.3)
		fill.BackgroundColor3 = world.Accent
		TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(stage / Config.StageCount, 1) }):Play()
		skipPrice.Text = "R$ " .. price("SkipStage", Config.DevProducts.SkipStage.PriceHint)
	end
	refreshStage()
	player:GetAttributeChangedSignal("Stage"):Connect(refreshStage)
	ReplicatedStorage:GetAttributeChangedSignal("Price_SkipStage"):Connect(refreshStage)

	local function refreshRank()
		local rank = player:GetAttribute("Rank") or "Newbie"
		local color = player:GetAttribute("RankColor") or "#C8C8C8"
		local nextRank = player:GetAttribute("NextRank")
		rankLabel.Text = `<font color="{color}">{string.upper(rank)}</font>` .. (if nextRank then `<font color="#BEBAD6">   next {nextRank}</font>` else "")
	end
	refreshRank()
	player:GetAttributeChangedSignal("Rank"):Connect(refreshRank)
	player:GetAttributeChangedSignal("NextRank"):Connect(refreshRank)
end

return UI
