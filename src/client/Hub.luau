-- Zweites HUD fuer Update 2: Knoepfe rechts (Quests, Geschenke, Gluecksrad, Index, Basis, Erfolge, Codes)
-- und eine Infoleiste unten (Server-Ziel, Kreatur des Tages, Happy Hour, Neulingsschutz, Kopfgeld).
-- Der Server schickt den Stand ueber Remotes.Sync, Aktionen laufen ueber Remotes.Request.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("Request") :: RemoteFunction

local Hub = {}

local TITLE_FONT = Enum.Font.BuilderSansExtraBold
local BODY_FONT = Enum.Font.BuilderSansBold
local BASE_SIZE = Vector2.new(1000, 560)

local THEME = {
	Panel = Color3.fromRGB(24, 24, 34),
	PanelDark = Color3.fromRGB(16, 16, 24),
	Row = Color3.fromRGB(36, 36, 50),
	Outline = Color3.fromRGB(8, 8, 14),
	Text = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(170, 172, 190),
	Cash = Color3.fromRGB(110, 255, 130),
	Gold = Color3.fromRGB(245, 195, 70),
	Pink = Color3.fromRGB(235, 95, 150),
	Green = Color3.fromRGB(46, 184, 104),
	Purple = Color3.fromRGB(128, 92, 240),
	Blue = Color3.fromRGB(52, 140, 235),
	Orange = Color3.fromRGB(240, 140, 50),
	Red = Color3.fromRGB(215, 64, 72),
	Teal = Color3.fromRGB(40, 175, 165),
	Gray = Color3.fromRGB(72, 74, 90),
}

local QUICK = TweenInfo.new(0.08)
local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

---------------------------------------------------------------- Bausteine (wie in UI.luau)

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

-- Feiner heller Rand fuer Flaechen (wie in UI.luau)
local function edge()
	return create("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.86, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function shine()
	return create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(222, 222, 222)), Rotation = 90 })
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
	props.TextSize = props.TextSize or 20
	props.TextColor3 = THEME.Text
	props.AutoButtonColor = true
	local result = create("TextButton", props, {
		corner(12),
		shine(),
	}) :: TextButton
	pressable(result)
	return result
end

-- Knopf an/aus (grau, nicht klickbar)
local function setEnabled(target: TextButton, enabled: boolean, color: Color3)
	target.Active = enabled
	target.AutoButtonColor = enabled
	target.BackgroundColor3 = if enabled then color else THEME.Gray
end

local function progressBar(parent: Instance, props, color: Color3): (Frame, TextLabel)
	props.BackgroundColor3 = THEME.PanelDark
	props.ClipsDescendants = true
	props.Parent = parent
	local back = create("Frame", props, { corner(8), edge() })
	local fill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back }, { corner(8), shine() })
	local label = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 15, ZIndex = 2, Parent = back }, 1.2)
	return fill :: Frame, label
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- 3725 -> "1:02:05"
local function longTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 3600 then
		return Format.Time(seconds)
	end
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

---------------------------------------------------------------- Zustand

local state: any = nil
local stateAt = os.clock()
local toast: (string, Color3?) -> ()

local function invoke(action: string, arg: any?)
	local ok, success, message, extra = pcall(request.InvokeServer, request, action, arg)
	if not ok then
		return false, "Connection problem", nil
	end
	if not success and message then
		toast(message, Color3.fromRGB(255, 110, 110))
	end
	return success, message, extra
end

local function sessionSeconds(): number
	return (if state then state.SessionSeconds or 0 else 0) + (os.clock() - stateAt)
end

local function serverNow(): number
	return (if state then state.Now or os.time() else os.time()) + (os.clock() - stateAt)
end

---------------------------------------------------------------- Start

function Hub.Start(showToast: (string, Color3?) -> ())
	toast = showToast
	local gui = create("ScreenGui", {
		Name = "Hub",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	local uiScale = create("UIScale", {}) :: UIScale
	local root = create("Frame", {
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

	------------------------------------------------ Knoepfe rechts (2 Spalten, ueber dem Sprung-Knopf)

	local grid = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 64),
		Size = UDim2.fromOffset(140, 300),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(66, 62),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	})

	local function menuButton(icon: string, caption: string, color: Color3, order: number): (TextButton, TextLabel)
		local result = create("TextButton", {
			BackgroundColor3 = color,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = order,
			Parent = grid,
		}, { corner(14), edge(), shine() }) :: TextButton
		text({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 36), Text = icon, TextSize = 27, Parent = result })
		text({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -4),
			Size = UDim2.new(1, 0, 0, 18),
			Text = caption,
			Font = TITLE_FONT,
			TextSize = 13,
			Parent = result,
		})
		local badge = text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -5, 0, 5),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = THEME.Red,
			Text = "!",
			Font = TITLE_FONT,
			TextSize = 16,
			Visible = false,
			Parent = result,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
		outline(2, THEME.Outline).Parent = badge
		pressable(result)
		return result, badge
	end

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
	local window = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 440),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = root,
	}, { corner(16), edge() }) :: Frame
	local popScale = create("UIScale", { Parent = window }) :: UIScale
	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = THEME.Blue, Parent = window }, { corner(16), shine() }) :: Frame
	local headerFix = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 16),
		BorderSizePixel = 0,
		Parent = header,
	}) :: Frame
	local titleLabel = text({
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -80, 1, 0),
		Text = "",
		Font = TITLE_FONT,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	})
	local close = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(40, 40), Text = "X", ZIndex = 2, Parent = header }, THEME.Red)

	local pages = {}
	local openPage: string? = nil
	local function closeWindow()
		window.Visible = false
		backdrop.Visible = false
		openPage = nil
	end
	local function openWindow(name: string)
		if openPage == name then
			closeWindow()
			return
		end
		local page = pages[name]
		for key, other in pages do
			other.Frame.Visible = key == name
		end
		openPage = name
		titleLabel.Text = page.Title
		header.BackgroundColor3 = page.Color
		headerFix.BackgroundColor3 = page.Color:Lerp(Color3.new(0, 0, 0), 0.13)
		window.Visible = true
		backdrop.Visible = true
		popScale.Scale = 0.85
		TweenService:Create(popScale, POP, { Scale = 1 }):Play()
		if page.Refresh then
			page.Refresh()
		end
	end
	close.Activated:Connect(closeWindow)
	backdrop.Activated:Connect(closeWindow)

	local function addPage(name: string, title: string, color: Color3, scrolling: boolean)
		local frame
		if scrolling then
			frame = create("ScrollingFrame", {
				Position = UDim2.fromOffset(14, 66),
				Size = UDim2.new(1, -20, 1, -76),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = THEME.Muted,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				Visible = false,
				Parent = window,
			})
		else
			frame = create("Frame", {
				Position = UDim2.fromOffset(14, 66),
				Size = UDim2.new(1, -28, 1, -76),
				BackgroundTransparency = 1,
				Visible = false,
				Parent = window,
			})
		end
		local page = { Frame = frame, Title = title, Color = color, Refresh = nil :: (() -> ())? }
		pages[name] = page
		return page
	end

	-- Zeile mit Titel, Fortschrittsbalken und Abhol-Knopf (Quests und Erfolge)
	local function claimRow(parent: Instance, order: number, title: string, progress: number, goal: number, rewardText: string, claimed: boolean, onClaim: () -> ())
		local row = create("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = THEME.Row, LayoutOrder = order, Parent = parent }, { corner(12), edge() })
		text({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 24),
			Text = title,
			Font = TITLE_FONT,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local fill, label = progressBar(row, { Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -150, 0, 22) }, THEME.Teal)
		fill.Size = UDim2.fromScale(math.clamp(progress / math.max(goal, 1), 0, 1), 1)
		label.Text = `{Format.Number(progress)} / {Format.Number(goal)}   ·   {rewardText}`
		local done = progress >= goal
		local claimButton = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(118, 46),
			Text = if claimed then "✓ DONE" elseif done then "CLAIM" else "...",
			TextSize = 19,
			Parent = row,
		}, THEME.Green)
		setEnabled(claimButton, done and not claimed, THEME.Green)
		claimButton.Activated:Connect(function()
			if claimButton.Active then
				setEnabled(claimButton, false, THEME.Green)
				onClaim()
			end
		end)
	end

	------------------------------------------------ Quests

	local questPage = addPage("Quests", "📜 DAILY QUESTS", THEME.Teal, false)
	local questList = create("Frame", { Size = UDim2.new(1, 0, 0, 240), BackgroundTransparency = 1, Parent = questPage.Frame }, { listLayout(Enum.FillDirection.Vertical, 8) })
	local questInfo = text({
		Position = UDim2.fromOffset(0, 250),
		Size = UDim2.new(1, -150, 0, 50),
		Text = "",
		TextSize = 16,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = questPage.Frame,
	})
	local skipButton = button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 252),
		Size = UDim2.fromOffset(140, 46),
		Text = `⏩ Skip  R$ {Config.DevProducts.QuestSkip.PriceHint}`,
		TextSize = 16,
		Parent = questPage.Frame,
	}, THEME.Orange)
	skipButton.Activated:Connect(function()
		invoke("SkipQuest")
	end)
	questPage.Refresh = function()
		clear(questList)
		if not state then
			return
		end
		for i, quest in state.Quests do
			claimRow(questList, i, quest.Text, quest.Progress, quest.Goal, Format.Cash(quest.Reward), quest.Claimed, function()
				invoke("ClaimQuest", i)
			end)
		end
	end

	------------------------------------------------ Spielzeit-Geschenke

	local giftPage = addPage("Gifts", "🎁 PLAYTIME GIFTS", THEME.Pink, false)
	create("UIGridLayout", { CellSize = UDim2.fromOffset(192, 160), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = giftPage.Frame })
	local giftTiles = {}
	for index, gift in Config.PlaytimeGifts do
		local tile = create("Frame", { BackgroundColor3 = THEME.Row, LayoutOrder = index, Parent = giftPage.Frame }, { corner(12), edge() })
		text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 40), Text = if gift.Catalyst then "🧪🎁" else "🎁", TextSize = 34, Parent = tile })
		text({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 22), Text = `{gift.Minutes} min`, Font = TITLE_FONT, TextSize = 19, Parent = tile })
		local amount = text({ Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 17, TextColor3 = THEME.Cash, Parent = tile })
		local claim = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 44), Text = "", TextSize = 18, Parent = tile }, THEME.Green)
		claim.Activated:Connect(function()
			if claim.Active then
				invoke("ClaimGift", index)
			end
		end)
		giftTiles[index] = { Amount = amount, Claim = claim }
	end
	local function updateGifts(): boolean
		local ready = false
		if not state or not state.Gifts then
			return false
		end
		local elapsed = sessionSeconds()
		for index, gift in state.Gifts do
			local tile = giftTiles[index]
			if tile then
				tile.Amount.Text = Format.Cash(gift.Reward) .. (if gift.Catalyst then " + 🧪" else "")
				local left = gift.Minutes * 60 - elapsed
				if gift.Claimed then
					tile.Claim.Text = "✓ CLAIMED"
					setEnabled(tile.Claim, false, THEME.Green)
				elseif left <= 0 then
					tile.Claim.Text = "OPEN!"
					setEnabled(tile.Claim, true, THEME.Green)
					ready = true
				else
					tile.Claim.Text = Format.Time(left)
					setEnabled(tile.Claim, false, THEME.Green)
				end
			end
		end
		return ready
	end
	giftPage.Refresh = function()
		updateGifts()
	end

	------------------------------------------------ Gluecksrad

	local spinPage = addPage("Spin", "🎡 LUCKY WHEEL (FREE)", THEME.Orange, false)
	local prizeGrid = create("Frame", { Size = UDim2.new(1, 0, 0, 240), BackgroundTransparency = 1, Parent = spinPage.Frame }, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(143, 112), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local prizeTiles: { Frame } = {}
	for index, prize in Config.SpinPrizes do
		local tile = create("Frame", { BackgroundColor3 = THEME.Row, LayoutOrder = index, Parent = prizeGrid }, { corner(12), outline(1.5, prize.Color) }) :: Frame
		local icon = if prize.Kind == "Cash" then "💰" elseif prize.Kind == "Luck" then "🍀" elseif prize.Kind == "Catalyst" then "🧪" elseif prize.Mutation == "Rainbow" then "🌈" elseif prize.Mutation == "Diamond" then "💎" else "✨"
		text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 44), Text = icon, TextSize = 36, Parent = tile })
		text({
			Position = UDim2.fromOffset(6, 56),
			Size = UDim2.new(1, -12, 0, 46),
			Text = prize.Name,
			Font = TITLE_FONT,
			TextSize = 17,
			TextWrapped = true,
			TextColor3 = prize.Color,
			Parent = tile,
		})
		prizeTiles[index] = tile
	end
	local spinButton = button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 262), Size = UDim2.fromOffset(300, 58), Text = "SPIN!", TextSize = 28, Parent = spinPage.Frame }, THEME.Orange)
	local spinInfo = text({ Position = UDim2.fromOffset(0, 324), Size = UDim2.new(1, 0, 0, 24), Text = "One free spin every 20 hours!", TextSize = 16, TextColor3 = THEME.Muted, Parent = spinPage.Frame })
	local spinning = false
	local function highlightPrize(index: number)
		for i, tile in prizeTiles do
			tile.BackgroundColor3 = if i == index then Color3.fromRGB(120, 95, 40) else THEME.Row
		end
	end
	local function spinReady(): boolean
		return state ~= nil and serverNow() >= (state.NextSpinAt or 0)
	end
	local function updateSpin()
		if spinning then
			return
		end
		local ready = spinReady()
		spinButton.Text = if ready then "SPIN!" elseif state then `Next spin in {longTime((state.NextSpinAt or 0) - serverNow())}` else "..."
		setEnabled(spinButton, ready, THEME.Orange)
	end
	spinButton.Activated:Connect(function()
		if spinning or not spinButton.Active then
			return
		end
		spinning = true
		setEnabled(spinButton, false, THEME.Orange)
		spinButton.Text = "Spinning..."
		local ok, _, index = invoke("Spin")
		if ok and type(index) == "number" then
			-- Lauflicht, das langsamer wird und auf dem Gewinn stehen bleibt
			local steps = #prizeTiles * 3 + index
			for step = 1, steps do
				highlightPrize((step - 1) % #prizeTiles + 1)
				task.wait(0.03 + (step / steps) ^ 3 * 0.25)
			end
			spinInfo.Text = `You won: {Config.SpinPrizes[index].Name}!`
		end
		spinning = false
		updateSpin()
	end)
	spinPage.Refresh = updateSpin

	------------------------------------------------ Index

	local indexPage = addPage("Index", "📖 CRITTER INDEX", THEME.Purple, false)
	local indexHeader = text({
		Size = UDim2.new(1, -170, 0, 46),
		Text = "",
		Font = TITLE_FONT,
		TextSize = 18,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = indexPage.Frame,
	})
	local indexClaim = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.fromOffset(160, 44), Text = "", TextSize = 16, Parent = indexPage.Frame }, THEME.Green)
	indexClaim.Activated:Connect(function()
		if indexClaim.Active then
			invoke("ClaimIndex")
		end
	end)
	local indexGrid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = indexPage.Frame,
	}, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(116, 62), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local indexTiles = {}
	for order, def in Config.Units do
		local rarity = Config.RaritiesByName[def.Rarity]
		local tile = create("Frame", { BackgroundColor3 = THEME.Row, LayoutOrder = rarity.Index * 100 + order, Parent = indexGrid }, { corner(10), outline(1.5, rarity.Color) })
		local name = text({ Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 32), Text = "???", Font = TITLE_FONT, TextSize = 15, TextWrapped = true, Parent = tile })
		text({ Position = UDim2.fromOffset(4, 38), Size = UDim2.new(1, -8, 0, 18), Text = def.Rarity, TextSize = 13, TextColor3 = rarity.Color, Parent = tile })
		indexTiles[def.Id] = name
	end
	local function indexClaimable(): boolean
		return state ~= nil and state.IndexNext ~= nil and state.IndexCount >= state.IndexNext.Count
	end
	indexPage.Refresh = function()
		if not state then
			return
		end
		local featured = workspace:GetAttribute("FeaturedId")
		for id, label in indexTiles do
			local def = Config.UnitsById[id]
			label.Text = if state.Index[id] then def.Name .. (if id == featured then " ⭐" else "") else "???"
			label.TextColor3 = if state.Index[id] then THEME.Text else THEME.Muted
		end
		indexHeader.Text = `{state.IndexCount} / {#Config.Units} discovered  ·  +{math.floor(state.IndexCount * Config.IndexBonusPer * 100 + 0.5)}% income forever`
		local nextMilestone = state.IndexNext
		if nextMilestone then
			indexClaim.Text = if indexClaimable() then `CLAIM {Format.Cash(nextMilestone.Cash)}` else `{nextMilestone.Count}: {Format.Cash(nextMilestone.Cash)}`
		else
			indexClaim.Text = "✓ ALL DONE"
		end
		setEnabled(indexClaim, indexClaimable(), THEME.Green)
	end

	------------------------------------------------ Basis-Ausbau

	local basePage = addPage("Base", "🏠 UPGRADE BASE", THEME.Green, false)
	local baseLevel = text({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 50), Text = "", Font = TITLE_FONT, TextSize = 40, TextColor3 = THEME.Gold, Parent = basePage.Frame })
	local baseBonus = text({ Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 56), Text = "", TextSize = 19, TextWrapped = true, Parent = basePage.Frame })
	local baseFill, baseProgress = progressBar(basePage.Frame, { Position = UDim2.new(0.1, 0, 0, 136), Size = UDim2.new(0.8, 0, 0, 30) }, THEME.Green)
	local upgradeButton = button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 186), Size = UDim2.fromOffset(320, 60), Text = "UPGRADE", TextSize = 24, Parent = basePage.Frame }, THEME.Green)
	text({
		Position = UDim2.fromOffset(0, 266),
		Size = UDim2.new(1, 0, 0, 70),
		Text = `Every level: +{math.floor(Config.BaseLevelIncome * 100)}% income and +{Config.BaseLevelLock}s base lock. Tip: hold R on your critters to sell them.`,
		TextSize = 16,
		TextWrapped = true,
		TextColor3 = THEME.Muted,
		Parent = basePage.Frame,
	})
	upgradeButton.Activated:Connect(function()
		if upgradeButton.Active then
			invoke("UpgradeBase")
		end
	end)
	local function canUpgrade(): boolean
		return state ~= nil and (state.BaseCost or 0) > 0 and (player:GetAttribute("Cash") or 0) >= state.BaseCost
	end
	local function updateBase()
		if not state then
			return
		end
		local level = state.BaseLevel or 0
		local cost = state.BaseCost or 0
		local cash = player:GetAttribute("Cash") or 0
		baseLevel.Text = `Level {level} / {Config.BaseMaxLevel}`
		baseBonus.Text = `Now: +{math.floor(level * Config.BaseLevelIncome * 100 + 0.5)}% income, +{level * Config.BaseLevelLock}s lock`
		baseFill.Size = UDim2.fromScale(if cost > 0 then math.clamp(cash / cost, 0, 1) else 1, 1)
		baseProgress.Text = if cost > 0 then `{Format.Cash(cash)} / {Format.Cash(cost)}` else "MAX LEVEL"
		upgradeButton.Text = if cost <= 0 then "MAX LEVEL" elseif canUpgrade() then `UPGRADE  {Format.Cash(cost)}` else `Need {Format.Cash(cost - cash)}`
		setEnabled(upgradeButton, canUpgrade(), THEME.Green)
	end
	basePage.Refresh = updateBase

	------------------------------------------------ Erfolge

	local awardsPage = addPage("Awards", "🏆 ACHIEVEMENTS", THEME.Gold, true)
	listLayout(Enum.FillDirection.Vertical, 8).Parent = awardsPage.Frame
	local function awardsClaimable(): boolean
		if not state then
			return false
		end
		for _, achievement in state.Achievements do
			if not achievement.Claimed and achievement.Progress >= achievement.Goal then
				return true
			end
		end
		return false
	end
	awardsPage.Refresh = function()
		clear(awardsPage.Frame)
		if not state then
			return
		end
		for i, achievement in state.Achievements do
			-- Abholbare zuerst, erledigte zuletzt
			local done = achievement.Progress >= achievement.Goal
			local order = if achievement.Claimed then 200 + i elseif done then i else 100 + i
			local reward = Format.Cash(achievement.Reward)
			claimRow(awardsPage.Frame, order, "🏆 " .. achievement.Name, achievement.Progress, achievement.Goal, reward, achievement.Claimed, function()
				invoke("ClaimAchievement", achievement.Id)
			end)
		end
	end

	------------------------------------------------ Codes

	local codesPage = addPage("Codes", "🎟️ CODES", THEME.Blue, false)
	text({
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.new(1, 0, 0, 50),
		Text = "Enter a code for free cash! New codes come with every update.",
		TextSize = 18,
		TextWrapped = true,
		Parent = codesPage.Frame,
	})
	local codeBox = create("TextBox", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(380, 56),
		BackgroundColor3 = THEME.PanelDark,
		Font = TITLE_FONT,
		TextSize = 26,
		TextColor3 = THEME.Text,
		PlaceholderText = "Type code here",
		PlaceholderColor3 = THEME.Gray,
		Text = "",
		ClearTextOnFocus = false,
		Parent = codesPage.Frame,
	}, { corner(12), outline(1.5, THEME.Blue) }) :: TextBox
	local redeemButton = button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 152), Size = UDim2.fromOffset(240, 56), Text = "REDEEM", TextSize = 24, Parent = codesPage.Frame }, THEME.Green)
	local codeResult = text({ Position = UDim2.fromOffset(0, 222), Size = UDim2.new(1, 0, 0, 30), Text = "", Font = TITLE_FONT, TextSize = 20, Parent = codesPage.Frame })
	text({
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.new(1, 0, 0, 40),
		Text = "Hint: try RELEASE",
		TextSize = 16,
		TextColor3 = THEME.Muted,
		Parent = codesPage.Frame,
	})
	redeemButton.Activated:Connect(function()
		local ok, message = invoke("Redeem", codeBox.Text)
		codeResult.Text = if ok then `✅ {message}` else `❌ {message or "Invalid code"}`
		codeResult.TextColor3 = if ok then THEME.Cash else Color3.fromRGB(255, 110, 110)
		if ok then
			codeBox.Text = ""
		end
	end)

	------------------------------------------------ Menue-Knoepfe

	local buttons = {}
	local entries = {
		{ "Quests", "📜", "QUESTS", THEME.Teal },
		{ "Gifts", "🎁", "GIFTS", THEME.Pink },
		{ "Spin", "🎡", "SPIN", THEME.Orange },
		{ "Index", "📖", "INDEX", THEME.Purple },
		{ "Base", "🏠", "BASE", THEME.Green },
		{ "Awards", "🏆", "AWARDS", Color3.fromRGB(220, 165, 30) },
		{ "Codes", "🎟️", "CODES", THEME.Blue },
	}
	for order, entry in entries do
		local menu, badge = menuButton(entry[2], entry[3], entry[4], order)
		menu.Activated:Connect(function()
			openWindow(entry[1])
		end)
		buttons[entry[1]] = badge
	end

	------------------------------------------------ Infoleiste unten

	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(560, 30),
		BackgroundTransparency = 1,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })
	local function chip(order: number, color: Color3): (Frame, TextLabel)
		local frame = create("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			Size = UDim2.new(),
			BackgroundColor3 = THEME.PanelDark,
			BackgroundTransparency = 0.15,
			LayoutOrder = order,
			Visible = false,
			Parent = bar,
		}, { corner(12), padding(10, 3), create("UIStroke", { Thickness = 1, Color = color, Transparency = 0.45, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) }) :: Frame
		local label = text({ AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), Text = "", TextSize = 14, TextColor3 = color, Parent = frame })
		return frame, label
	end
	local goalChip, goalLabel = chip(1, THEME.Cash)
	local featuredChip, featuredLabel = chip(2, THEME.Gold)
	local happyChip, happyLabel = chip(3, Color3.fromRGB(120, 255, 120))
	local shieldChip, shieldLabel = chip(4, Color3.fromRGB(120, 200, 255))
	local bountyChip, bountyLabel = chip(5, THEME.Orange)

	------------------------------------------------ Laufend aktualisieren

	remotes:WaitForChild("Sync").OnClientEvent:Connect(function(newState)
		state = newState
		stateAt = os.clock()
		if openPage and pages[openPage].Refresh then
			pages[openPage].Refresh()
		end
	end)
	task.spawn(function()
		invoke("GetState")
	end)

	task.spawn(function()
		while gui.Parent do
			local now = workspace:GetServerTimeNow()
			-- Badges
			local questReady = false
			if state then
				for _, quest in state.Quests do
					if not quest.Claimed and quest.Progress >= quest.Goal then
						questReady = true
					end
				end
				local reset = state.QuestsReset - serverNow()
				local bonusText = if state.QuestBonusClaimed then "All quests done today!" else `Finish all 3 for a {Format.Cash(state.QuestBonus)} bonus!`
				questInfo.Text = `{bonusText}  New quests in {longTime(reset)}`
			end
			buttons.Quests.Visible = questReady
			buttons.Gifts.Visible = updateGifts()
			buttons.Spin.Visible = spinReady()
			buttons.Index.Visible = indexClaimable()
			buttons.Awards.Visible = awardsClaimable()
			buttons.Base.Visible = canUpgrade()
			if openPage == "Spin" then
				updateSpin()
			elseif openPage == "Base" then
				updateBase()
			end

			-- Infoleiste
			local goal = workspace:GetAttribute("GoalProgress")
			goalChip.Visible = goal ~= nil
			goalLabel.Text = `Server goal {goal or 0}/{workspace:GetAttribute("GoalTarget") or Config.ServerGoal} = 2x cash`
			local featured = workspace:GetAttribute("FeaturedName")
			featuredChip.Visible = featured ~= nil
			featuredLabel.Text = `{featured or "?"} 2x today`
			local happyEnds = workspace:GetAttribute("HappyHourEnds")
			local happyIn = workspace:GetAttribute("HappyHourIn")
			happyChip.Visible = happyEnds ~= nil or happyIn ~= nil
			happyLabel.Text = if happyEnds then `HAPPY HOUR 2x {longTime(happyEnds - now)}` else `Happy Hour {longTime((happyIn or now) - now)}`
			local shieldLeft = player:GetAttribute("ShieldLeft")
			shieldChip.Visible = player:GetAttribute("NewbieShield") == true
			shieldLabel.Text = `Newbie shield {math.ceil((shieldLeft or 0) / 60)} min`
			local bounty = workspace:GetAttribute("BountyName")
			bountyChip.Visible = bounty ~= nil
			bountyLabel.Text = if player:GetAttribute("Bounty") then "YOU have the bounty!" else `Bounty: {bounty or "?"}`
			task.wait(0.5)
		end
	end)
end

return Hub
