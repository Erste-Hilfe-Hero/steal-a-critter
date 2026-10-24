-- Baut das komplette HUD per Code: Stage-Anzeige, Skip-Button, Shop, Trails und Meldungen.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local FONT = Enum.Font.FredokaOne
local GREEN = Color3.fromRGB(60, 200, 90)

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

local function stroke(thickness: number)
	return create("UIStroke", { Thickness = thickness, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	return create("TextLabel", props, { create("UIStroke", { Thickness = 2 }) })
end

local function button(props, color: Color3)
	props.BackgroundColor3 = color
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = Color3.new(1, 1, 1)
	props.AutoButtonColor = true
	return create("TextButton", props, { corner(10), stroke(2), create("UITextSizeConstraint", { MaxTextSize = 28 }) })
end

---------------------------------------------------------------- Kaufen

local function productId(key: string): number
	return ReplicatedStorage:GetAttribute("ProductId_" .. key) or 0
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
local announceLabel: TextLabel

function UI.Toast(text: string, color: Color3?)
	local toast = label({
		Size = UDim2.new(1, 0, 0, 34),
		Text = text,
		TextColor3 = color or Color3.new(1, 1, 1),
		Parent = toastContainer,
	})
	task.delay(3.5, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

local announceToken = 0
local function showAnnouncement(text: string, color: Color3?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.TextColor3 = color or Color3.new(1, 1, 1)
	announceLabel.Visible = true
	task.delay(5, function()
		if token == announceToken then
			announceLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------- Fenster

local function window(gui: ScreenGui, title: string)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.5, 0, 0.7, 0),
		BackgroundColor3 = Color3.fromRGB(25, 25, 35),
		Visible = false,
		Parent = gui,
	}, { corner(14), stroke(3), create("UISizeConstraint", { MinSize = Vector2.new(320, 280), MaxSize = Vector2.new(620, 700) }) })
	label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 44), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local close = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(44, 44), Text = "X", Parent = frame }, Color3.fromRGB(220, 60, 60))
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 60),
		Size = UDim2.new(1, -20, 1, -70),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	return frame, list
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

local function row(parent: Instance, title: string, description: string, order: number)
	local frame = create("Frame", {
		Size = UDim2.new(1, -10, 0, 70),
		BackgroundColor3 = Color3.fromRGB(40, 40, 55),
		LayoutOrder = order,
		Parent = parent,
	}, { corner(10) })
	label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.62, -12, 0, 30), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	label({
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(0.62, -12, 0, 22),
		Text = description,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(200, 200, 210),
		Parent = frame,
	})
	return frame
end

local function buildShopRow(parent: Instance, kind: string, key: string, entry, color: Color3, order: number)
	local frame = row(parent, entry.Name, entry.Description, order)
	local buy = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.32, 0, 0, 46),
		Text = "R$ " .. entry.PriceHint,
		Parent = frame,
	}, color)
	local function refresh()
		if kind == "Pass" and player:GetAttribute("Pass_" .. key) then
			buy.Text = "OWNED"
			buy.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
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

local function unlockText(trail): string
	local unlock = trail.Unlock
	if unlock.Pass == "VIP" then
		return "VIP only"
	elseif unlock.Pass then
		return "Trail Pack"
	elseif unlock.Wins then
		return `Win {unlock.Wins}x`
	end
	return `Reach stage {unlock.Best}`
end

local function buildTrailRow(parent: Instance, trail)
	local frame = row(parent, trail.Name, unlockText(trail), trail.Order)
	-- Farbvorschau
	local preview = create("Frame", {
		Position = UDim2.new(0.62, -60, 0.5, -12),
		Size = UDim2.fromOffset(50, 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, { corner(6) })
	local points = {}
	for i, color in trail.Colors do
		table.insert(points, ColorSequenceKeypoint.new(if #trail.Colors == 1 then 0 else (i - 1) / (#trail.Colors - 1), color))
	end
	if #points == 1 then
		table.insert(points, ColorSequenceKeypoint.new(1, trail.Colors[1]))
	end
	create("UIGradient", { Color = ColorSequence.new(points), Parent = preview })

	local action = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0.32, 0, 0, 46),
		Text = "",
		Parent = frame,
	}, GREEN)
	local function refresh()
		local unlocked = Config.TrailUnlocked(trail, player:GetAttribute("BestStage") or 1, player:GetAttribute("Wins") or 0, hasPass)
		if player:GetAttribute("Trail") == trail.Id then
			action.Text = "EQUIPPED"
			action.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
		elseif unlocked then
			action.Text = "EQUIP"
			action.BackgroundColor3 = GREEN
		elseif trail.Unlock.Pass then
			action.Text = "UNLOCK"
			action.BackgroundColor3 = Color3.fromRGB(255, 170, 30)
		else
			action.Text = "LOCKED"
			action.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
		end
	end
	refresh()
	for _, attribute in { "Trail", "BestStage", "Wins", "Pass_VIP", "Pass_TrailPack" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	action.Activated:Connect(function()
		local unlocked = Config.TrailUnlocked(trail, player:GetAttribute("BestStage") or 1, player:GetAttribute("Wins") or 0, hasPass)
		if unlocked then
			remotes.EquipTrail:FireServer(trail.Id)
		elseif trail.Unlock.Pass then
			UI.Buy("Pass", trail.Unlock.Pass)
		end
	end)
end

---------------------------------------------------------------- Start

local skipButton: TextButton
local skipPulse: Tween?

-- Skip-Button aufleuchten lassen, wenn jemand an einer Stage festhaengt
function UI.HighlightSkip()
	if skipPulse then
		return
	end
	local tween = TweenService:Create(skipButton, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 6, true), {
		Size = UDim2.fromOffset(190, 84),
	})
	skipPulse = tween
	tween:Play()
	tween.Completed:Once(function()
		skipPulse = nil
	end)
end

function UI.Start()
	local gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Stage-Anzeige oben mit Fortschrittsbalken
	local top = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(380, 120),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local stageLabel = label({ Size = UDim2.new(1, 0, 0, 44), Text = "STAGE 1", LayoutOrder = 1, Parent = top })
	local worldLabel = label({ Size = UDim2.new(1, 0, 0, 24), Text = "", LayoutOrder = 2, Parent = top })
	local bar = create("Frame", { Size = UDim2.new(0.9, 0, 0, 14), BackgroundColor3 = Color3.fromRGB(30, 30, 40), LayoutOrder = 3, Parent = top }, { corner(7), stroke(2) })
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, Parent = bar }, { corner(7) })
	local rankLabel = label({ Size = UDim2.new(1, 0, 0, 18), Text = "", TextColor3 = Color3.fromRGB(200, 200, 255), LayoutOrder = 4, Parent = top })

	announceLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 135),
		Size = UDim2.new(0.7, 0, 0, 34),
		Visible = false,
		Parent = gui,
	})

	toastContainer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -110),
		Size = UDim2.new(0.6, 0, 0, 180),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

	-- Grosser Skip-Button rechts: wichtigste Einnahmequelle eines Obbys
	skipButton = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(170, 74),
		Text = `SKIP STAGE ⏭\nR$ {Config.DevProducts.SkipStage.PriceHint}`,
		Parent = gui,
	}, GREEN)
	skipButton.Activated:Connect(function()
		UI.Buy("Product", "SkipStage")
	end)

	-- Seitenbuttons links
	local side = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(120, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { Padding = UDim.new(0, 10) }) })
	local shopButton = button({ Size = UDim2.new(1, 0, 0, 60), Text = "SHOP", Parent = side }, Color3.fromRGB(255, 170, 30))
	local trailButton = button({ Size = UDim2.new(1, 0, 0, 60), Text = "TRAILS", Parent = side }, Color3.fromRGB(160, 80, 255))

	local shop, shopList = window(gui, "SHOP")
	label({ Size = UDim2.new(1, -10, 0, 30), Text = "Forever", TextColor3 = Color3.fromRGB(255, 200, 40), LayoutOrder = 0, Parent = shopList })
	for i, item in sortedEntries(Config.GamePasses) do
		buildShopRow(shopList, "Pass", item.Key, item.Entry, Color3.fromRGB(255, 170, 30), i)
	end
	label({ Size = UDim2.new(1, -10, 0, 30), Text = "Skips & Trolls", TextColor3 = Color3.fromRGB(90, 220, 255), LayoutOrder = 50, Parent = shopList })
	for i, item in sortedEntries(Config.DevProducts) do
		buildShopRow(shopList, "Product", item.Key, item.Entry, Color3.fromRGB(40, 170, 255), 50 + i)
	end

	local trails, trailList = window(gui, "TRAILS")
	for _, trail in Config.Trails do
		buildTrailRow(trailList, trail)
	end

	shopButton.Activated:Connect(function()
		shop.Visible = not shop.Visible
		trails.Visible = false
	end)
	trailButton.Activated:Connect(function()
		trails.Visible = not trails.Visible
		shop.Visible = false
	end)

	remotes.Notify.OnClientEvent:Connect(UI.Toast)
	remotes.Announce.OnClientEvent:Connect(showAnnouncement)

	local function refreshStage()
		local stage = player:GetAttribute("Stage") or 1
		local world, worldIndex = Config.WorldForStage(stage)
		stageLabel.Text = `STAGE {stage} / {Config.StageCount}`
		worldLabel.Text = `World {worldIndex}: {world.Name}`
		worldLabel.TextColor3 = world.Accent
		fill.BackgroundColor3 = world.Accent
		TweenService:Create(fill, TweenInfo.new(0.3), { Size = UDim2.fromScale(stage / Config.StageCount, 1) }):Play()
		skipButton.Text = `SKIP STAGE ⏭\nR$ {price("SkipStage", Config.DevProducts.SkipStage.PriceHint)}`
	end
	refreshStage()
	player:GetAttributeChangedSignal("Stage"):Connect(refreshStage)
	ReplicatedStorage:GetAttributeChangedSignal("Price_SkipStage"):Connect(refreshStage)

	local function refreshRank()
		local nextRank = player:GetAttribute("NextRank")
		rankLabel.Text = `Rank: {player:GetAttribute("Rank") or "Newbie"}` .. (if nextRank then `  (next {nextRank})` else "") .. "  /rank"
		if player:GetAttribute("RankColor") then
			rankLabel.TextColor3 = Color3.fromHex(player:GetAttribute("RankColor"))
		end
	end
	refreshRank()
	player:GetAttributeChangedSignal("Rank"):Connect(refreshRank)
	player:GetAttributeChangedSignal("NextRank"):Connect(refreshRank)
end

return UI
