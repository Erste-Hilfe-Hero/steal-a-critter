-- Baut das komplette HUD per Code: Geldanzeige, Status-Chips, Seitenmenue, Shop, Rebirth, Meldungen.
-- Das Layout ist fuer BASE_SIZE entworfen und wird per UIScale an jeden Bildschirm angepasst (Handy bis PC).
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.BuilderSansBold
local BASE_SIZE = Vector2.new(1000, 560)

-- Farben passend zum Neon-Sonnenuntergang (Ladebildschirm, Welt)
local THEME = {
	Panel = Color3.fromRGB(30, 25, 52),
	PanelDark = Color3.fromRGB(18, 15, 34),
	Row = Color3.fromRGB(46, 39, 76),
	Outline = Color3.fromRGB(10, 8, 22),
	Text = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(195, 188, 225),
	Cash = Color3.fromRGB(110, 255, 130),
	Gold = Color3.fromRGB(255, 200, 50),
	Pink = Color3.fromRGB(255, 95, 175),
	Green = Color3.fromRGB(55, 200, 95),
	Purple = Color3.fromRGB(155, 85, 255),
	Blue = Color3.fromRGB(40, 160, 255),
	Orange = Color3.fromRGB(255, 140, 30),
	Red = Color3.fromRGB(230, 60, 75),
	Gray = Color3.fromRGB(95, 90, 118),
}

-- Symbol pro Shop-Eintrag (unbekannte Eintraege bekommen ein Geschenk)
local ICONS = {
	VIP = "👑",
	DoubleCash = "💸",
	ExtraSlots = "📦",
	FastSteal = "⚡",
	SpeedCoil = "👟",
	CashSmall = "💰",
	CashMedium = "💵",
	CashLarge = "🏦",
	LockBase = "🔒",
	ServerLuck = "🍀",
	GoldenTouch = "✨",
	DiamondTouch = "💎",
	RainbowTouch = "🌈",
	FusionCatalyst = "🧪",
	CashParty = "🎉",
	StarterPack = "🎁",
}

local QUICK = TweenInfo.new(0.08)
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.35)

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

local function outline(thickness: number, color: Color3?)
	return create("UIStroke", { Thickness = thickness, Color = color or THEME.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- Weiss nach Grau multipliziert die Hintergrundfarbe: leichter 3D-Effekt, AutoButtonColor funktioniert weiter
local function shine()
	return create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175)), Rotation = 90 })
end

local function padding(x: number, y: number)
	return create("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
	})
end

local function listLayout(direction: Enum.FillDirection, gap: number, horizontal: Enum.HorizontalAlignment?, vertical: Enum.VerticalAlignment?)
	return create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

-- Text mit fester Groesse (UIScale skaliert alles gemeinsam); strokeThickness > 0 fuer Text direkt ueber der Welt
local function text(props, strokeThickness: number?): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or BODY_FONT
	props.TextSize = props.TextSize or 18
	props.TextColor3 = props.TextColor3 or THEME.Text
	local label = create("TextLabel", props) :: TextLabel
	if strokeThickness and strokeThickness > 0 then
		create("UIStroke", { Thickness = strokeThickness, Color = THEME.Outline, Parent = label })
	end
	return label
end

-- Kurzes Eindruecken beim Antippen
local function pressable(guiButton: GuiButton)
	local scale = create("UIScale", { Parent = guiButton })
	local function release()
		TweenService:Create(scale, QUICK, { Scale = 1 }):Play()
	end
	guiButton.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 0.92 }):Play()
	end)
	guiButton.MouseButton1Up:Connect(release)
	guiButton.MouseLeave:Connect(release)
end

local function button(props, color: Color3): TextButton
	props.BackgroundColor3 = color
	props.Font = props.Font or TITLE_FONT
	props.TextSize = props.TextSize or 22
	props.TextColor3 = THEME.Text
	props.AutoButtonColor = true
	local result = create("TextButton", props, {
		corner(12),
		outline(2, THEME.Outline),
		shine(),
		create("UIStroke", { Thickness = 1.5, Color = THEME.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }),
	}) :: TextButton
	pressable(result)
	return result
end

local function closeButton(parent: Instance): TextButton
	return button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(42, 42),
		Text = "X",
		Parent = parent,
	}, THEME.Red)
end

-- Fenster mit farbiger Kopfzeile; gibt Fenster und Kopfzeile zurueck
local function window(name: string, title: string, size: Vector2, color: Color3, parent: Instance): (Frame, Frame)
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = parent,
	}, { corner(18), outline(3, THEME.Outline), create("UIScale", { Name = "PopScale" }) }) :: Frame
	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = color,
		Parent = frame,
	}, { corner(18), shine() }) :: Frame
	-- Untere Ecken der Kopfzeile eckig machen
	create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.3),
		BorderSizePixel = 0,
		Parent = header,
	})
	text({
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Text = title,
		Font = TITLE_FONT,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	}, 2)
	return frame, header
end

-- Kleine Info-Pille (Text mit Symbol); gibt Pille, Text und Rahmen zurueck
local function chip(parent: Instance, order: number, color: Color3, textSize: number?): (Frame, TextLabel, UIStroke)
	local stroke = outline(2, color) :: UIStroke
	local frame = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	}, { corner(14), padding(12, 4), stroke }) :: Frame
	local label = text({
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "",
		TextSize = textSize or 18,
		TextColor3 = color,
		Parent = frame,
	})
	return frame, label, stroke
end

---------------------------------------------------------------- Meldungen

local root: Frame
local toastContainer: Frame
local announceLabel: TextLabel
local announceScale: UIScale

local toastCount = 0
local function showToast(message: string, color: Color3?)
	toastCount += 1
	local accent = color or THEME.Text
	local stroke = outline(2, accent)
	local scale = create("UIScale", { Scale = 0.7 })
	local toast = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.1,
		LayoutOrder = toastCount,
		Parent = toastContainer,
	}, { corner(14), padding(16, 6), stroke, scale })
	local label = text({
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = message,
		TextSize = 19,
		TextColor3 = accent,
		TextWrapped = true,
		Parent = toast,
	}, 0)
	create("UISizeConstraint", { MaxSize = Vector2.new(520, math.huge), Parent = label })
	TweenService:Create(scale, POP, { Scale = 1 }):Play()

	-- Hoechstens 4 Meldungen gleichzeitig
	local toasts = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	table.sort(toasts, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 1, #toasts - 4 do
		toasts[i]:Destroy()
	end

	task.delay(3.5, function()
		if not toast.Parent then
			return
		end
		TweenService:Create(toast, FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, FADE, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, FADE, { Transparency = 1 }):Play()
		task.wait(FADE.Time)
		toast:Destroy()
	end)
end

local announceToken = 0
local function showAnnouncement(message: string, color: Color3?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = message
	announceLabel.TextColor3 = color or THEME.Gold
	announceLabel.Visible = true
	announceScale.Scale = 0.6
	TweenService:Create(announceScale, POP, { Scale = 1 }):Play()
	task.delay(5, function()
		if token == announceToken then
			announceLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------- Shop

local function sortedEntries(source, filter: ((any) -> boolean)?)
	local list = {}
	for key, entry in source do
		if not entry.Hidden and (not filter or filter(entry)) then
			table.insert(list, { Key = key, Entry = entry })
		end
	end
	table.sort(list, function(a, b)
		return (a.Entry.Order or 99) < (b.Entry.Order or 99)
	end)
	return list
end

local function promptBuy(kind: string, key: string, entry)
	-- Pass ohne Gamepass-ID wird als dauerhaftes Developer Product verkauft
	local productId = if kind == "Pass" and entry.Id == 0 then entry.ProductId else nil
	if productId then
		MarketplaceService:PromptProductPurchase(player, productId)
	elseif entry.Id ~= 0 then
		if kind == "Pass" then
			MarketplaceService:PromptGamePassPurchase(player, entry.Id)
		else
			MarketplaceService:PromptProductPurchase(player, entry.Id)
		end
	else
		-- Nur in Studio wirksam (Server prueft das)
		remotes.FakePurchase:FireServer(kind, key)
	end
end

-- Echten Preis nachladen (falls in Creator Hub geaendert)
local function loadPrice(kind: string, entry, priceButton: TextButton)
	local productId = if kind == "Pass" and entry.Id == 0 then entry.ProductId else nil
	if entry.Id == 0 and not productId then
		return
	end
	task.spawn(function()
		local infoType = if kind == "Pass" and not productId then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId or entry.Id, infoType)
		if ok and info and info.PriceInRobux and priceButton.Active then
			priceButton.Text = "R$ " .. info.PriceInRobux
		end
	end)
end

local function sectionTitle(parent: Instance, title: string, color: Color3, order: number)
	text({
		Size = UDim2.new(1, 0, 0, 26),
		Text = title,
		Font = TITLE_FONT,
		TextSize = 20,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function buildShopRow(parent: Instance, kind: string, key: string, entry, color: Color3, order: number, featured: boolean?)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundColor3 = if featured then Color3.fromRGB(70, 52, 30) else THEME.Row,
		LayoutOrder = order,
		Parent = parent,
	}, { corner(14), outline(if featured then 2.5 else 1.5, if featured then THEME.Gold else THEME.Outline) })

	create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = color,
		Parent = row,
	}, {
		corner(12),
		shine(),
		outline(1.5, THEME.Outline),
		text({ Size = UDim2.fromScale(1, 1), Text = ICONS[key] or "🎁", TextSize = 32 }),
	})

	text({
		Position = UDim2.fromOffset(80, 10),
		Size = UDim2.new(1, -210, 0, 26),
		Text = entry.Name,
		Font = TITLE_FONT,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = row,
	})
	text({
		Position = UDim2.fromOffset(80, 36),
		Size = UDim2.new(1, -210, 0, 36),
		Text = entry.Description,
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 16,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = row,
	})
	if featured then
		local tag = text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, -10),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = THEME.Pink,
			Text = "BEST VALUE",
			Font = TITLE_FONT,
			TextSize = 15,
			ZIndex = 2,
			Parent = row,
		})
		corner(8).Parent = tag
		padding(8, 0).Parent = tag
	end

	local buy = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(112, 50),
		Text = "R$ " .. entry.PriceHint,
		Parent = row,
	}, THEME.Green)
	loadPrice(kind, entry, buy)

	-- Passes und Einmal-Angebote (Starter Pack) zeigen OWNED, sobald gekauft
	local ownedAttribute = if kind == "Pass" then "Pass_" .. key else entry.OwnedAttribute
	if ownedAttribute then
		local function refreshOwned()
			if player:GetAttribute(ownedAttribute) then
				buy.Text = "OWNED"
				buy.BackgroundColor3 = THEME.Gray
				buy.AutoButtonColor = false
				buy.Active = false
			end
		end
		refreshOwned()
		player:GetAttributeChangedSignal(ownedAttribute):Connect(refreshOwned)
	end

	buy.Activated:Connect(function()
		if ownedAttribute and player:GetAttribute(ownedAttribute) then
			return
		end
		promptBuy(kind, key, entry)
	end)
end

-- Angebot im passenden Moment: Karte rechts mit Kaufen und "No thanks", verschwindet nach 12 Sekunden
local OFFER_TIME = 12
local offerCard: Frame? = nil
local function showOffer(kind: string, key: string, reason: string)
	local entry = if kind == "Pass" then Config.GamePasses[key] else Config.DevProducts[key]
	if not entry or not root then
		return
	end
	if offerCard then
		offerCard:Destroy()
	end
	local shown = UDim2.new(1, -12, 0.45, 0)
	local card = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 340, 0.45, 0),
		Size = UDim2.fromOffset(320, 176),
		BackgroundColor3 = THEME.Panel,
		ZIndex = 15,
		Parent = root,
	}, { corner(16), outline(3, THEME.Gold) }) :: Frame
	offerCard = card
	text({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 22),
		Text = reason,
		Font = TITLE_FONT,
		TextSize = 18,
		TextColor3 = THEME.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	create("Frame", {
		Position = UDim2.fromOffset(14, 38),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = THEME.Orange,
		Parent = card,
	}, { corner(12), shine(), outline(1.5, THEME.Outline), text({ Size = UDim2.fromScale(1, 1), Text = ICONS[key] or "🎁", TextSize = 30 }) })
	text({
		Position = UDim2.fromOffset(78, 36),
		Size = UDim2.new(1, -92, 0, 26),
		Text = entry.Name,
		Font = TITLE_FONT,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = card,
	})
	text({
		Position = UDim2.fromOffset(78, 62),
		Size = UDim2.new(1, -92, 0, 34),
		Text = entry.Description,
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 15,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local buy = button({ Position = UDim2.fromOffset(14, 106), Size = UDim2.new(0.55, -14, 0, 48), Text = "R$ " .. entry.PriceHint, Parent = card }, THEME.Green)
	local no = button({ Position = UDim2.new(0.55, 8, 0, 106), Size = UDim2.new(0.45, -22, 0, 48), Text = "No thanks", TextSize = 18, Parent = card }, THEME.Gray)
	loadPrice(kind, entry, buy)

	-- Restzeit-Balken
	local timer = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -8),
		Size = UDim2.new(1, -28, 0, 5),
		BackgroundColor3 = THEME.Gold,
		BorderSizePixel = 0,
		Parent = card,
	}, { corner(3) })
	TweenService:Create(card, POP, { Position = shown }):Play()
	TweenService:Create(timer, TweenInfo.new(OFFER_TIME, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 5) }):Play()

	local function dismiss()
		if card.Parent then
			card:Destroy()
		end
		if offerCard == card then
			offerCard = nil
		end
	end
	buy.Activated:Connect(function()
		dismiss()
		promptBuy(kind, key, entry)
	end)
	no.Activated:Connect(dismiss)
	task.delay(OFFER_TIME, dismiss)
end

---------------------------------------------------------------- Start

function UI.Start()
	local gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	-- Alles haengt an root; Mitte als Anker, damit UIScale den Bildschirm genau ausfuellt
	local uiScale = create("UIScale", {}) :: UIScale
	root = create("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { uiScale }) :: Frame
	local function updateScale()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local scale = math.clamp(math.min(size.X / BASE_SIZE.X, size.Y / BASE_SIZE.Y), 0.6, 1.25)
		uiScale.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	updateScale()

	------------------------------------------------ Oben: Geld, Infos, Status

	local top = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(640, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })

	local cashScale = create("UIScale", {}) :: UIScale
	local cashPill = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(180, 0),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.1,
		LayoutOrder = 1,
		Parent = top,
	}, {
		corner(18),
		padding(22, 4),
		outline(2.5, THEME.Outline),
		cashScale,
		listLayout(Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Center),
	})
	local cashLabel = text({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 42),
		Text = "$0",
		Font = TITLE_FONT,
		TextSize = 40,
		TextColor3 = THEME.Cash,
		LayoutOrder = 1,
		Parent = cashPill,
	}, 2.5)
	local incomeRow = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = cashPill,
	}, { listLayout(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local incomeLabel = text({
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Text = "+$0/s",
		TextSize = 19,
		LayoutOrder = 1,
		Parent = incomeRow,
	}, 1.5)
	local multiplierLabel = text({
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(80, 60, 20),
		Text = "x1",
		Font = TITLE_FONT,
		TextSize = 16,
		TextColor3 = THEME.Gold,
		LayoutOrder = 2,
		Parent = incomeRow,
	})
	corner(8).Parent = multiplierLabel
	padding(7, 1).Parent = multiplierLabel

	-- Kleine Infos: Rang, Freunde, Einladungen, Katalysatoren
	local infoRow = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = top,
	}, { listLayout(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	local rankChip, rankLabel, rankStroke = chip(infoRow, 1, THEME.Muted, 15)
	local friendChip, friendLabel = chip(infoRow, 2, Color3.fromRGB(110, 210, 255), 15)
	local referralChip, referralLabel = chip(infoRow, 3, Color3.fromRGB(110, 210, 255), 15)
	local catalystChip, catalystLabel = chip(infoRow, 4, Color3.fromRGB(120, 255, 200), 15)
	rankChip.Visible = true
	friendChip.Visible = true
	-- Antippen des Rangs erklaert den Chat-Befehl
	local rankHint = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = rankChip })
	rankHint.Activated:Connect(function()
		showToast("Type /rank in chat to see your rank progress!", Color3.fromRGB(200, 200, 255))
	end)

	-- Status-Chips: nur sichtbar, wenn gerade etwas los ist
	local statusChip, statusLabel, statusStroke = chip(top, 3, THEME.Gold, 19)
	local revengeChip, revengeLabel = chip(top, 4, Color3.fromRGB(255, 80, 80), 19)
	local luckChip, luckLabel = chip(top, 5, Color3.fromRGB(90, 255, 140), 19)
	local eventChip, eventLabel, eventStroke = chip(top, 6, THEME.Pink, 17)

	announceScale = create("UIScale", {}) :: UIScale
	announceLabel = text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.new(0.8, 0, 0, 90),
		Text = "",
		Font = TITLE_FONT,
		TextSize = 38,
		TextWrapped = true,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	}, 3)
	announceScale.Parent = announceLabel

	toastContainer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.new(0.6, 0, 0, 200),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) }) :: Frame

	------------------------------------------------ Links: Menue-Knoepfe

	local side = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.44, 0),
		Size = UDim2.fromOffset(84, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Vertical, 10) })

	local function menuButton(icon: string, caption: string, color: Color3, order: number): (TextButton, TextLabel)
		local result = create("TextButton", {
			Size = UDim2.fromOffset(84, 74),
			BackgroundColor3 = color,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = order,
			Parent = side,
		}, { corner(18), outline(2.5, THEME.Outline), shine() }) :: TextButton
		text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), Text = icon, TextSize = 32, Parent = result })
		text({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -6),
			Size = UDim2.new(1, 0, 0, 20),
			Text = caption,
			Font = TITLE_FONT,
			TextSize = 17,
			Parent = result,
		}, 1.5)
		local badge = text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 0,
			BackgroundColor3 = THEME.Red,
			Text = "!",
			Font = TITLE_FONT,
			TextSize = 18,
			Visible = false,
			Parent = result,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
		outline(2, THEME.Outline).Parent = badge
		pressable(result)
		return result, badge
	end

	local shopButton = menuButton("🛒", "SHOP", THEME.Green, 1)
	local rebirthButton, rebirthBadge = menuButton("♻️", "REBIRTH", THEME.Purple, 2)
	local inviteButton, inviteBadge = menuButton("💌", "INVITE", THEME.Blue, 3)
	local adButton, adBadge = menuButton("🎬", "FREE $", THEME.Orange, 4)
	adButton.Visible = false
	inviteBadge.Text = "$"
	inviteBadge.BackgroundColor3 = THEME.Gold
	inviteBadge.Visible = true
	adBadge.Text = "$"
	adBadge.BackgroundColor3 = THEME.Gold
	adBadge.Visible = true

	-- Freiwillige Video-Werbung: Knopf nur zeigen, wenn Roblox gerade eine Werbung bereit hat
	task.spawn(function()
		while gui.Parent do
			local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			adButton.Visible = ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
			task.wait(30)
		end
	end)
	-- Freunde einladen: LaunchData traegt die eigene UserId, damit der Server den Einladenden belohnen kann
	inviteButton.Activated:Connect(function()
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not ok or not canInvite then
			showToast("Invites are not available on this device.", Color3.fromRGB(255, 90, 90))
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Invite friends - you both get cash and you earn +5% income forever!"
		options.LaunchData = tostring(player.UserId)
		pcall(SocialService.PromptGameInvite, SocialService, player, options)
	end)
	adButton.Activated:Connect(function()
		adButton.Visible = false
		remotes.WatchAd:FireServer()
	end)

	------------------------------------------------ Fenster

	local backdrop = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 9,
		Parent = root,
	}) :: TextButton

	local openModal: Frame? = nil
	local function closeModal()
		if openModal then
			openModal.Visible = false
			openModal = nil
		end
		backdrop.Visible = false
	end
	local function toggleModal(modal: Frame)
		if openModal == modal then
			closeModal()
			return
		end
		closeModal()
		openModal = modal
		modal.Visible = true
		backdrop.Visible = true
		local scale = modal:FindFirstChild("PopScale") :: UIScale
		scale.Scale = 0.85
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end
	backdrop.Activated:Connect(closeModal)

	-- Shop mit drei Reitern
	local shop, shopHeader = window("Shop", "🛒 SHOP", Vector2.new(660, 480), THEME.Green, root)
	closeButton(shopHeader).Activated:Connect(closeModal)

	local tabBar = create("Frame", {
		Position = UDim2.fromOffset(14, 68),
		Size = UDim2.new(1, -28, 0, 44),
		BackgroundTransparency = 1,
		Parent = shop,
	}, { listLayout(Enum.FillDirection.Horizontal, 8) })

	local tabs = {}
	local function selectTab(selected)
		for _, tab in tabs do
			local active = tab == selected
			tab.Page.Visible = active
			tab.Button.BackgroundColor3 = if active then tab.Color else THEME.Row
			tab.Button.TextColor3 = if active then THEME.Text else THEME.Muted
		end
	end
	local function addTab(title: string, color: Color3): ScrollingFrame
		local tabButton = button({
			Size = UDim2.new(1 / 3, -6, 1, 0),
			Text = title,
			TextSize = 20,
			LayoutOrder = #tabs + 1,
			Parent = tabBar,
		}, THEME.Row)
		local page = create("ScrollingFrame", {
			Position = UDim2.fromOffset(14, 122),
			Size = UDim2.new(1, -20, 1, -134),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = THEME.Muted,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = false,
			Parent = shop,
		}, {
			listLayout(Enum.FillDirection.Vertical, 8),
			create("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8) }),
		}) :: ScrollingFrame
		local tab = { Button = tabButton, Page = page, Color = color }
		table.insert(tabs, tab)
		tabButton.Activated:Connect(function()
			selectTab(tab)
		end)
		return page
	end

	local passesPage = addTab("⭐ PASSES", THEME.Gold)
	local boostsPage = addTab("🚀 BOOSTS", THEME.Blue)
	local cashPage = addTab("💰 CASH", THEME.Green)

	-- Starter Pack ganz oben, verschwindet nicht, zeigt nach dem Kauf OWNED
	sectionTitle(passesPage, "One time offer", THEME.Pink, 0)
	buildShopRow(passesPage, "Product", "StarterPack", Config.DevProducts.StarterPack, THEME.Pink, 1, true)
	sectionTitle(passesPage, "Game Passes - yours forever", THEME.Gold, 2)
	for i, item in sortedEntries(Config.GamePasses) do
		buildShopRow(passesPage, "Pass", item.Key, item.Entry, THEME.Gold, 2 + i)
	end
	for i, item in sortedEntries(Config.DevProducts, function(entry)
		return entry.Kind ~= "Cash"
	end) do
		buildShopRow(boostsPage, "Product", item.Key, item.Entry, THEME.Blue, i)
	end
	sectionTitle(cashPage, "Grows with your income!", THEME.Cash, 0)
	for i, item in sortedEntries(Config.DevProducts, function(entry)
		return entry.Kind == "Cash"
	end) do
		buildShopRow(cashPage, "Product", item.Key, item.Entry, THEME.Green, i)
	end
	selectTab(tabs[1])

	-- Rebirth-Fenster
	local rebirth, rebirthHeader = window("Rebirth", "♻️ REBIRTH", Vector2.new(420, 330), THEME.Purple, root)
	closeButton(rebirthHeader).Activated:Connect(closeModal)
	local multiplierText = text({
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.new(1, -32, 0, 48),
		Text = "",
		Font = TITLE_FONT,
		TextSize = 40,
		TextColor3 = THEME.Gold,
		Parent = rebirth,
	}, 2)
	text({
		Position = UDim2.fromOffset(16, 118),
		Size = UDim2.new(1, -32, 0, 22),
		Text = "income multiplier",
		TextSize = 17,
		TextColor3 = THEME.Muted,
		Parent = rebirth,
	})
	local progressBack = create("Frame", {
		Position = UDim2.fromOffset(24, 152),
		Size = UDim2.new(1, -48, 0, 34),
		BackgroundColor3 = THEME.PanelDark,
		ClipsDescendants = true,
		Parent = rebirth,
	}, { corner(12), outline(2, THEME.Outline) })
	local progressFill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.Purple,
		BorderSizePixel = 0,
		Parent = progressBack,
	}, { corner(12), shine() })
	local progressText = text({
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 18,
		ZIndex = 2,
		Parent = progressBack,
	}, 1.5)
	text({
		Position = UDim2.fromOffset(16, 192),
		Size = UDim2.new(1, -32, 0, 22),
		Text = "Resets your cash and critters.",
		Font = Enum.Font.BuilderSansMedium,
		TextSize = 16,
		TextColor3 = THEME.Muted,
		Parent = rebirth,
	})
	local confirmRebirth = button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.new(0.75, 0, 0, 58),
		Text = "REBIRTH",
		TextSize = 26,
		Parent = rebirth,
	}, THEME.Purple)

	shopButton.Activated:Connect(function()
		toggleModal(shop)
	end)
	rebirthButton.Activated:Connect(function()
		toggleModal(rebirth)
	end)
	confirmRebirth.Activated:Connect(function()
		remotes.RequestRebirth:FireServer()
		closeModal()
	end)

	remotes.Notify.OnClientEvent:Connect(showToast)
	remotes.Announce.OnClientEvent:Connect(showAnnouncement)
	remotes.Offer.OnClientEvent:Connect(showOffer)

	------------------------------------------------ Anzeige laufend aktualisieren

	local lastCash = player:GetAttribute("Cash") or 0
	task.spawn(function()
		while gui.Parent do
			local cash = player:GetAttribute("Cash") or 0
			local income = player:GetAttribute("IncomePerSec") or 0
			local rebirths = player:GetAttribute("Rebirths") or 0
			local cost = player:GetAttribute("RebirthCost") or 0
			local now = workspace:GetServerTimeNow()

			cashLabel.Text = Format.Cash(cash)
			incomeLabel.Text = `+{Format.Cash(income)}/s`
			multiplierLabel.Text = `x{player:GetAttribute("Multiplier") or 1}`
			-- Groessere Gewinne (Kauf, Klau, Belohnung) lassen die Geldanzeige kurz aufploppen
			if cash - lastCash > math.max(income * 3, 50) then
				cashScale.Scale = 1.15
				TweenService:Create(cashScale, POP, { Scale = 1 }):Play()
			end
			lastCash = cash

			local carrying = player:GetAttribute("Carrying")
			local lockedFor = player:GetAttribute("LockedFor") or 0
			statusChip.Visible = carrying ~= nil or lockedFor > 0
			if carrying then
				statusLabel.Text = `🏃 Carrying {carrying} - run to your base!`
				statusLabel.TextColor3 = THEME.Gold
				statusStroke.Color = THEME.Gold
			elseif lockedFor > 0 then
				statusLabel.Text = `🔒 Base locked  {Format.Time(lockedFor)}`
				statusLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
				statusStroke.Color = Color3.fromRGB(120, 200, 255)
			end

			local rankColor = if player:GetAttribute("RankColor") then Color3.fromHex(player:GetAttribute("RankColor")) else THEME.Muted
			local nextRank = player:GetAttribute("NextRank")
			rankLabel.Text = `⭐ {player:GetAttribute("Rank") or "Newbie"}` .. (if nextRank then `  ·  next: {nextRank}` else "")
			rankLabel.TextColor3 = rankColor
			rankStroke.Color = rankColor

			local friends = player:GetAttribute("FriendsHere") or 0
			local referrals = player:GetAttribute("Referrals") or 0
			local catalysts = player:GetAttribute("Catalysts") or 0
			friendLabel.Text = `👥 {friends} friends here  +{math.floor((player:GetAttribute("FriendBoost") or 0) * 100)}%`
			referralChip.Visible = referrals > 0
			referralLabel.Text = `💌 {referrals} invited`
			catalystChip.Visible = catalysts > 0
			catalystLabel.Text = `🧪 {catalysts} catalyst` .. (if catalysts == 1 then "" else "s")

			local revengeLeft = (player:GetAttribute("RevengeUntil") or 0) - now
			revengeChip.Visible = revengeLeft > 0
			if revengeLeft > 0 then
				revengeLabel.Text = `⚔️ REVENGE on {player:GetAttribute("RevengeTarget") or "?"}  {Format.Time(revengeLeft)} - steal back instantly!`
			end

			local luckLeft = (workspace:GetAttribute("LuckUntil") or 0) - now
			luckChip.Visible = luckLeft > 0
			if luckLeft > 0 then
				luckLabel.Text = `🍀 SERVER LUCK x{Config.ServerLuckMultiplier}  {Format.Time(luckLeft)}`
			end

			local eventName = workspace:GetAttribute("EventName")
			local partyLeft = (workspace:GetAttribute("PartyEnds") or 0) - now
			local eventColor = THEME.Pink
			local eventText = ""
			if partyLeft > 0 then
				eventText = `🎉 CASH PARTY by {workspace:GetAttribute("PartyBy") or "?"}: 2x CASH  {Format.Time(partyLeft)}`
				eventColor = THEME.Cash
			elseif eventName then
				eventText = `🎊 EVENT: {eventName}  {Format.Time(math.max(0, (workspace:GetAttribute("EventEnds") or now) - now))}`
			else
				local nextAt = workspace:GetAttribute("NextEventAt")
				if nextAt then
					eventText = `⏰ Free event in {Format.Time(math.max(0, nextAt - now))}`
					eventColor = THEME.Muted
				end
			end
			eventChip.Visible = eventText ~= ""
			eventLabel.Text = eventText
			eventLabel.TextColor3 = eventColor
			eventStroke.Color = eventColor

			local current = 1 + rebirths * Config.RebirthMultiplierPer
			local canRebirth = cost > 0 and cash >= cost
			multiplierText.Text = `x{current}  ➡️  x{current + Config.RebirthMultiplierPer}`
			progressFill.Size = UDim2.fromScale(if cost > 0 then math.clamp(cash / cost, 0, 1) else 0, 1)
			progressText.Text = `{Format.Cash(cash)} / {Format.Cash(cost)}`
			confirmRebirth.Text = if canRebirth or cost <= 0 then "REBIRTH" else `Need {Format.Cash(cost - cash)} more`
			confirmRebirth.BackgroundColor3 = if canRebirth then THEME.Purple else THEME.Gray
			rebirthBadge.Visible = canRebirth
			task.wait(0.2)
		end
	end)
end

return UI
