-- HUD und Fenster im Turbo-City-Comic-Stil: dicke Tinten-Konturen, harte Schatten, LuckiestGuy-Schrift.
-- Basisgroesse 1000x560, per UIScale fuer Handy bis Monitor skaliert.
local AdService = game:GetService("AdService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Drive = require(script.Parent.Drive)
local Effects = require(script.Parent.Effects)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local C = Config.Colors
local INK = C.Ink
local WHITE = Color3.new(1, 1, 1)
local GREY = Color3.fromRGB(170, 170, 185)
local TITLE = Enum.Font.LuckiestGuy
local BODY = Enum.Font.GothamBold
local TEAM_COLORS = { Citizens = C.Citizen, Police = C.Police, Robbers = C.Robber }
local TEAM_NAMES = { Citizens = "CITIZEN", Police = "COP", Robbers = "ROBBER" }

---------------------------------------------------------------- Bausteine

local function make(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
	if instance:IsA("GuiObject") and not (props and props.BorderSizePixel) then
		(instance :: any).BorderSizePixel = 0
	end
	instance.Parent = parent
	return instance
end

local function corner(parent: Instance, radius: number?)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

local function outline(parent: Instance, thickness: number?, color: Color3?)
	make("UIStroke", { Color = color or INK, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, parent)
end

local function textStroke(parent: Instance, thickness: number?)
	make("UIStroke", { Color = INK, Thickness = thickness or 2 }, parent)
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local defaults = { BackgroundTransparency = 1, Font = TITLE, TextColor3 = INK, TextSize = 20, TextWrapped = true }
	for key, value in props do
		defaults[key] = value
	end
	return make("TextLabel", defaults, parent)
end

-- Karte mit hartem Comic-Schatten. Gibt (Flaeche, Halter) zurueck.
local function card(parent: Instance, size: UDim2, position: UDim2, color: Color3, anchor: Vector2?, radius: number?): (Frame, Frame)
	local holder = make("Frame", { Size = size, Position = position, AnchorPoint = anchor or Vector2.zero, BackgroundTransparency = 1 }, parent)
	local shadow = make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(4, 5), BackgroundColor3 = INK }, holder)
	corner(shadow, radius)
	local face = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color }, holder)
	corner(face, radius)
	outline(face)
	return face, holder
end

-- Comic-Knopf, der beim Druecken in den Schatten sinkt
local function button(parent: Instance, props: { [string]: any }): (TextButton, Frame)
	local holder = make("Frame", { Size = props.Size or UDim2.fromOffset(120, 40), Position = props.Position or UDim2.new(), AnchorPoint = props.AnchorPoint or Vector2.zero, BackgroundTransparency = 1, LayoutOrder = props.LayoutOrder or 0, Visible = props.Visible ~= false }, parent)
	local shadow = make("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 4), BackgroundColor3 = INK }, holder)
	corner(shadow, props.Radius or 10)
	local face = make("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = props.Color or C.Lemon,
		AutoButtonColor = false,
		Font = TITLE,
		Text = props.Text or "",
		TextSize = props.TextSize or 20,
		TextColor3 = props.TextColor or INK,
		TextWrapped = true,
	}, holder)
	corner(face, props.Radius or 10)
	outline(face)
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 3)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.MouseLeave:Connect(function()
		face.Position = UDim2.new()
	end)
	if props.OnClick then
		face.Activated:Connect(props.OnClick)
	end
	return face, holder
end

---------------------------------------------------------------- Aktionen

local showToast: (string, Color3?) -> ()

local function request(action: string, ...: any)
	local args = table.pack(...)
	task.spawn(function()
		local ok, result, message = pcall(function()
			return remotes.Request:InvokeServer(action, table.unpack(args, 1, args.n))
		end)
		if ok and message then
			showToast(message, if result then C.Green else C.Robber)
		end
	end)
end

local function buy(kind: string, key: string)
	local id = if kind == "Pass" then Config.GamePasses[key].ProductId else Config.DevProducts[key].Id
	if id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif RunService:IsStudio() then
		remotes.FakePurchase:FireServer(kind, key)
	else
		showToast("Coming soon!", C.Lemon)
	end
end

local function buyKey(key: string)
	local passKey = key:match("^Pass_(.+)$")
	if passKey then
		buy("Pass", passKey)
	else
		buy("Product", key)
	end
end

local function houseTier(): number
	local tier = player:GetAttribute("House") or 1
	if tier >= #Config.Houses and not player:GetAttribute("Pass_Diamond") then
		tier = #Config.Houses - 1
	end
	return tier
end

local function cashPackAmount(base: number): number
	return math.floor(base * (1 + (houseTier() - 1) * 0.75))
end

local function teamName(): string
	return if player.Team then player.Team.Name else "Citizens"
end

---------------------------------------------------------------- Aufbau

function UI.Start()
	local gui = make("ScreenGui", { Name = "TurboHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false }, player:WaitForChild("PlayerGui"))
	local root = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(1000, 560) }, gui)
	local uiScale = make("UIScale", {}, root)
	local function rescale()
		local size = gui.AbsoluteSize
		if size.X <= 0 then
			return
		end
		local s = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.6, 1.4)
		uiScale.Scale = s
		root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
	rescale()

	------------------------------------------------ Toasts

	local toastList = make("Frame", { Size = UDim2.new(0, 520, 0, 200), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), BackgroundTransparency = 1 }, root)
	make("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, toastList)
	local toastCount = 0
	showToast = function(text: string, color: Color3?)
		toastCount += 1
		local toasts = {}
		for _, child in toastList:GetChildren() do
			if child:IsA("Frame") then
				table.insert(toasts, child)
			end
		end
		if #toasts >= 4 then
			table.sort(toasts, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			toasts[1]:Destroy()
		end
		local pill = make("Frame", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Cream, LayoutOrder = toastCount }, toastList)
		corner(pill, 17)
		outline(pill, 3, color or INK)
		make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }, pill)
		local text_ = label(pill, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 18, TextWrapped = false, TextColor3 = INK })
		local accent = make("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0), BackgroundColor3 = color or C.Lemon }, pill)
		corner(accent, 4)
		task.delay(3.6, function()
			if pill.Parent then
				TweenService:Create(pill, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
				TweenService:Create(text_, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
				task.wait(0.3)
				pill:Destroy()
			end
		end)
	end
	UI.Toast = showToast
	remotes.Notify.OnClientEvent:Connect(showToast)
	remotes.Announce.OnClientEvent:Connect(function(text, color)
		showToast(text, color or C.Pink)
	end)

	------------------------------------------------ Geld oben

	local cashFace = card(root, UDim2.fromOffset(250, 52), UDim2.new(0.5, 0, 0, 8), C.Lemon, Vector2.new(0.5, 0), 26)
	local coin = make("Frame", { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.Green }, cashFace)
	corner(coin, 20)
	outline(coin, 3)
	label(coin, { Size = UDim2.fromScale(1, 1), Text = "$", TextSize = 28, TextColor3 = WHITE })
	local cashLabel = label(cashFace, { Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(52, 2), Text = "$0", TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	local multiBadge = make("Frame", { Size = UDim2.fromOffset(58, 26), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 22, 0, 4), BackgroundColor3 = C.Pink, Visible = false }, cashFace)
	corner(multiBadge, 13)
	outline(multiBadge, 3)
	local multiLabel = label(multiBadge, { Size = UDim2.fromScale(1, 1), Text = "x1", TextSize = 18, TextColor3 = WHITE })

	local chips = make("Frame", { Size = UDim2.new(0, 600, 0, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), BackgroundTransparency = 1 }, root)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, chips)
	local function chip(order: number, color: Color3, textColor: Color3?): (Frame, TextLabel)
		local frame = make("Frame", { Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = color, LayoutOrder = order, Visible = false }, chips)
		corner(frame, 14)
		outline(frame, 3)
		make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, frame)
		local text = label(frame, { Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextSize = 17, TextWrapped = false, TextColor3 = textColor or WHITE })
		textStroke(text, 1.5)
		return frame, text
	end
	local teamChip, teamText = chip(1, C.Citizen)
	local wantedChip, wantedText = chip(2, C.Ink, C.Robber)
	local lootChip, lootText = chip(3, C.Green)
	local partyChip, partyText = chip(4, C.Pink)

	------------------------------------------------ Gefaengnis

	local jailFace, jailHolder = card(root, UDim2.fromOffset(300, 150), UDim2.new(0.5, 0, 0.5, -10), C.Robber, Vector2.new(0.5, 0.5), 18)
	jailHolder.Visible = false
	local busted = label(jailFace, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = "BUSTED!", TextSize = 44, TextColor3 = C.Lemon })
	textStroke(busted, 3)
	local jailTimer = label(jailFace, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 54), Text = "Free in 0:20", TextSize = 24, TextColor3 = WHITE })
	textStroke(jailTimer, 2)
	button(jailFace, {
		Text = `BREAK OUT  R$ {Config.DevProducts.JailBreak.PriceHint}`,
		Color = C.Lemon,
		Size = UDim2.fromOffset(240, 40),
		Position = UDim2.new(0.5, 0, 1, -54),
		AnchorPoint = Vector2.new(0.5, 0),
		OnClick = function()
			buy("Product", "JailBreak")
		end,
	})

	------------------------------------------------ Fenster

	local windows = {}
	local currentWindow: string? = nil
	local backdrop = make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.45, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 5 }, root)
	local windowFace, windowHolder = card(root, UDim2.fromOffset(680, 420), UDim2.fromScale(0.5, 0.52), C.Cream, Vector2.new(0.5, 0.5), 18)
	windowHolder.Visible = false
	windowHolder.ZIndex = 6
	local header = make("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.Orange }, windowFace)
	corner(header, 18)
	make("Frame", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), BackgroundColor3 = C.Orange }, header)
	make("Frame", { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = INK }, header)
	local windowTitle = label(header, { Size = UDim2.new(1, -120, 1, 0), Position = UDim2.fromOffset(22, 2), Text = "SHOP", TextSize = 36, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left })
	textStroke(windowTitle, 3)
	local content = make("Frame", { Size = UDim2.new(1, -24, 1, -76), Position = UDim2.fromOffset(12, 68), BackgroundTransparency = 1 }, windowFace)

	local function closeWindow()
		currentWindow = nil
		windowHolder.Visible = false
		backdrop.Visible = false
	end
	button(header, { Text = "X", Color = C.Robber, TextColor = WHITE, TextSize = 26, Size = UDim2.fromOffset(44, 40), Position = UDim2.new(1, -56, 0, 8), OnClick = closeWindow })
	backdrop.Activated:Connect(closeWindow)

	local function openWindow(name: string)
		local window = windows[name]
		if not window then
			return
		end
		currentWindow = name
		windowTitle.Text = window.Title
		header.BackgroundColor3 = window.Color
		for _, child in header:GetChildren() do
			if child:IsA("Frame") and child.BackgroundColor3 ~= INK then
				child.BackgroundColor3 = window.Color
			end
		end
		content:ClearAllChildren()
		window.Build(content)
		backdrop.Visible = true
		windowHolder.Visible = true
		windowHolder.Position = UDim2.fromScale(0.5, 0.56)
		TweenService:Create(windowHolder, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.52) }):Play()
	end
	local function refreshWindow()
		if currentWindow then
			local window = windows[currentWindow]
			content:ClearAllChildren()
			window.Build(content)
		end
	end
	UI.Open = openWindow
	Effects.OnOpenUI = openWindow

	local function grid(parent: Instance, cell: Vector2, top: number?): ScrollingFrame
		local scroll = make("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, -(top or 0)),
			Position = UDim2.fromOffset(0, top or 0),
			BackgroundTransparency = 1,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = INK,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
		}, parent)
		make("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
		make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 10) }, scroll)
		return scroll
	end

	local function itemCard(parent: Instance, order: number, accent: Color3, title: string, description: string, buttonText: string, buttonColor: Color3, onClick: (() -> ())?)
		local holder = make("Frame", { BackgroundTransparency = 1, LayoutOrder = order }, parent)
		local face = card(holder, UDim2.new(1, -4, 1, -5), UDim2.new(), WHITE, nil, 12)
		local strip = make("Frame", { Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = accent }, face)
		corner(strip, 12)
		label(face, { Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 14), Text = title, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
		label(face, { Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 40), Text = description, Font = BODY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Color3.fromRGB(70, 68, 100) })
		local b = button(face, { Text = buttonText, Color = buttonColor, TextColor = if buttonColor == INK or buttonColor == C.Police or buttonColor == C.Pink then WHITE else INK, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.new(0, 10, 1, -44), TextSize = 19, OnClick = onClick })
		return face, b
	end

	local function tabs(parent: Instance, names: { string }, selected: string, onSelect: (string) -> ())
		local row = make("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, parent)
		make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }, row)
		for i, name in names do
			button(row, {
				Text = name,
				Color = if name == selected then C.Pink else WHITE,
				TextColor = if name == selected then WHITE else INK,
				Size = UDim2.fromOffset(140, 34),
				LayoutOrder = i,
				TextSize = 18,
				OnClick = function()
					onSelect(name)
				end,
			})
		end
	end

	-- SHOP
	local shopTab = "PASSES"
	windows.Shop = {
		Title = "SHOP",
		Color = C.Pink,
		Build = function(parent)
			tabs(parent, { "PASSES", "BOOSTS", "CASH" }, shopTab, function(name)
				shopTab = name
				refreshWindow()
			end)
			local scroll = grid(parent, Vector2.new(196, 150), 50)
			if shopTab == "PASSES" then
				local keys = {}
				for key in Config.GamePasses do
					table.insert(keys, key)
				end
				table.sort(keys, function(a, b)
					return Config.GamePasses[a].Order < Config.GamePasses[b].Order
				end)
				for i, key in keys do
					local pass = Config.GamePasses[key]
					local owned = player:GetAttribute("Pass_" .. key)
					itemCard(scroll, i, C.Lemon, pass.Name, pass.Description, if owned then "OWNED" else `R$ {pass.PriceHint}`, if owned then GREY else C.Green, if owned then nil else function()
						buy("Pass", key)
					end)
				end
			else
				local list = {}
				for key, product in Config.DevProducts do
					local isCash = product.Kind == "Cash"
					if not product.Hidden and ((shopTab == "CASH") == isCash) and not (key == "StarterPack" and player:GetAttribute("StarterPackOwned")) then
						table.insert(list, key)
					end
				end
				table.sort(list, function(a, b)
					return Config.DevProducts[a].Order < Config.DevProducts[b].Order
				end)
				for i, key in list do
					local product = Config.DevProducts[key]
					local description = product.Description
					local title = product.Name
					if product.Kind == "Cash" then
						title = Format.Cash(cashPackAmount(product.Base))
						description = product.Name
					end
					itemCard(scroll, i, if key == "StarterPack" then C.Pink else C.Teal, title, description, `R$ {product.PriceHint}`, C.Green, function()
						buy("Product", key)
					end)
				end
			end
		end,
	}

	-- GARAGE
	windows.Garage = {
		Title = "TURBO MOTORS",
		Color = C.Teal,
		Build = function(parent)
			local scroll = grid(parent, Vector2.new(196, 160), 0)
			scroll.Size = UDim2.new(1, 0, 1, -64)
			local owned = {}
			for id in string.gmatch(player:GetAttribute("OwnedCars") or "", "[^,]+") do
				owned[id] = true
			end
			local team = teamName()
			for _, def in Config.Cars do
				local text, color, action
				local canUse = false
				if def.Team and def.Team ~= team then
					text, color = `{string.upper(def.Team)} ONLY`, GREY
				elseif def.Pass and not player:GetAttribute("Pass_" .. def.Pass) then
					text, color = `R$ {Config.GamePasses[def.Pass].PriceHint}`, C.Green
					action = function()
						buy("Pass", def.Pass)
					end
				elseif def.Team or def.Pass or owned[def.Id] then
					canUse = true
				else
					local affordable = (player:GetAttribute("Cash") or 0) >= def.Price
					text, color = `BUY {Format.Cash(def.Price)}`, if affordable then C.Lemon else WHITE
					action = function()
						request("BuyCar", def.Id)
						task.delay(0.6, refreshWindow)
					end
				end
				if canUse then
					text, color = "SPAWN", C.Teal
					action = function()
						request("SpawnCar", def.Id)
						closeWindow()
					end
				end
				itemCard(scroll, def.Order, def.Color, def.Name, `Top speed {def.Speed}\nHandling {def.Turn}`, text, color, action)
			end
			-- Lackfarben
			local paints = make("Frame", { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.new(0, 0, 1, -56), BackgroundTransparency = 1 }, parent)
			label(paints, { Size = UDim2.fromOffset(80, 56), Text = "PAINT", TextSize = 22 })
			local row = make("Frame", { Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(90, 0), BackgroundTransparency = 1 }, paints)
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)
			for i, paint in Config.Paints do
				local locked = paint.Pass and not player:GetAttribute("Pass_" .. paint.Pass)
				local selected = (player:GetAttribute("Paint") or "stock") == paint.Id
				local swatch = make("TextButton", {
					Size = UDim2.fromOffset(42, 42),
					BackgroundColor3 = paint.Color or WHITE,
					Text = if locked then "🔒" elseif paint.Id == "stock" then "AUTO" else "",
					Font = TITLE,
					TextSize = if paint.Id == "stock" then 11 else 18,
					TextColor3 = INK,
					LayoutOrder = i,
					AutoButtonColor = true,
				}, row)
				corner(swatch, 21)
				outline(swatch, if selected then 5 else 3, if selected then C.Pink else INK)
				if paint.Rainbow then
					make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 160)), ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 100, 255)) }) }, swatch)
				end
				swatch.Activated:Connect(function()
					request("SetPaint", paint.Id)
					task.delay(0.5, refreshWindow)
				end)
			end
		end,
	}

	-- HAUS + Belohnungen
	windows.Home = {
		Title = "MY HOUSE",
		Color = C.Orange,
		Build = function(parent)
			local tier = houseTier()
			local house = Config.Houses[tier]
			local left = card(parent, UDim2.new(0.5, -10, 1, -6), UDim2.new(), WHITE, nil, 14)
			label(left, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 10), Text = house.Name, TextSize = 30 })
			label(left, { Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 52), Text = `Rent {Format.Cash(house.Rent)} per minute`, TextSize = 20, TextColor3 = C.Green })
			local nextHouse = Config.Houses[(player:GetAttribute("House") or 1) + 1]
			if nextHouse then
				label(left, { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 92), Text = `NEXT: {nextHouse.Name}\nRent {Format.Cash(nextHouse.Rent)}/min`, Font = BODY, TextSize = 16 })
				button(left, {
					Text = if nextHouse.Price then `UPGRADE {Format.Cash(nextHouse.Price)}` else `UPGRADE  R$ {Config.GamePasses.Diamond.PriceHint}`,
					Color = if nextHouse.Price then C.Lemon else C.Green,
					Size = UDim2.new(1, -30, 0, 44),
					Position = UDim2.fromOffset(15, 152),
					OnClick = function()
						request("UpgradeHouse")
						task.delay(0.6, refreshWindow)
					end,
				})
			else
				label(left, { Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 100), Text = "You own the best house in Turbo City!", Font = BODY, TextSize = 16 })
			end
			button(left, {
				Text = "GO HOME",
				Color = C.Teal,
				Size = UDim2.new(1, -30, 0, 44),
				Position = UDim2.new(0, 15, 1, -60),
				OnClick = function()
					request("GoHome")
					closeWindow()
				end,
			})
			-- Rechts: Tagesbelohnung und Geschenk
			local right = make("Frame", { Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0.5, 10, 0, 0), BackgroundTransparency = 1 }, parent)
			local daily = card(right, UDim2.new(1, -4, 0.5, -10), UDim2.new(), C.Lemon, nil, 14)
			local streak = player:GetAttribute("DailyStreak") or 1
			label(daily, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 8), Text = `DAILY REWARD - DAY {streak}`, TextSize = 22 })
			label(daily, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 40), Text = Format.Cash(player:GetAttribute("DailyReward") or 0), TextSize = 28, TextColor3 = C.Green })
			if player:GetAttribute("DailyReady") then
				button(daily, { Text = "CLAIM", Color = C.Green, TextColor = WHITE, Size = UDim2.new(1, -30, 0, 38), Position = UDim2.new(0, 15, 1, -48), OnClick = function()
					request("ClaimDaily")
					task.delay(0.6, refreshWindow)
				end })
			else
				label(daily, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 1, -42), Text = "Come back tomorrow!", Font = BODY, TextSize = 15 })
			end
			local gift = card(right, UDim2.new(1, -4, 0.5, -10), UDim2.new(0, 0, 0.5, 4), C.Teal, nil, 14)
			label(gift, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 8), Text = "PLAYTIME GIFT", TextSize = 22 })
			local giftText = label(gift, { Name = "GiftText", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 40), Text = "", TextSize = 22, TextColor3 = WHITE })
			textStroke(giftText, 2)
			button(gift, { Text = "OPEN GIFT", Color = C.Lemon, Size = UDim2.new(1, -30, 0, 38), Position = UDim2.new(0, 15, 1, -48), OnClick = function()
				request("ClaimGift")
				task.delay(0.6, refreshWindow)
			end })
		end,
	}

	-- TEAM
	windows.Team = {
		Title = "PICK YOUR SIDE",
		Color = C.Police,
		Build = function(parent)
			local teams = {
				{ Name = "Citizens", Title = "CITIZEN", Lines = "Delivery jobs\nCity races\nSafe from cops" },
				{ Name = "Police", Title = "COP", Lines = "Cuffs + Stun Blaster\nBounty per arrest\n+$120 paycheck" },
				{ Name = "Robbers", Title = "ROBBER", Lines = "Rob the Bank\nand 3 more stores\nBig risky cash" },
			}
			local row = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, parent)
			make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, row)
			for i, team in teams do
				local holder = make("Frame", { Size = UDim2.new(0, 196, 1, -8), BackgroundTransparency = 1, LayoutOrder = i }, row)
				local face = card(holder, UDim2.new(1, -4, 1, -5), UDim2.new(), WHITE, nil, 14)
				local top = make("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = TEAM_COLORS[team.Name] }, face)
				corner(top, 14)
				local title = label(top, { Size = UDim2.fromScale(1, 1), Text = team.Title, TextSize = 34, TextColor3 = WHITE })
				textStroke(title, 3)
				label(face, { Size = UDim2.new(1, -16, 0, 120), Position = UDim2.fromOffset(8, 84), Text = team.Lines, Font = BODY, TextSize = 16, TextYAlignment = Enum.TextYAlignment.Top })
				local current = teamName() == team.Name
				button(face, {
					Text = if current then "YOU'RE HERE" else "JOIN",
					Color = if current then GREY else TEAM_COLORS[team.Name],
					TextColor = WHITE,
					Size = UDim2.new(1, -24, 0, 44),
					Position = UDim2.new(0, 12, 1, -58),
					OnClick = if current then nil else function()
						request("SetTeam", team.Name)
						closeWindow()
					end,
				})
			end
		end,
	}

	-- MISSIONEN + Codes
	windows.Missions = {
		Title = "DAILY MISSIONS",
		Color = C.Lemon,
		Build = function(parent)
			local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Missions") or "[]")
			list = if ok then list else {}
			for i, entry in list do
				local mission = Config.MissionsById[entry.Id]
				if mission then
					local row = card(parent, UDim2.new(1, -4, 0, 76), UDim2.fromOffset(0, (i - 1) * 86), WHITE, nil, 12)
					label(row, { Size = UDim2.new(1, -220, 0, 28), Position = UDim2.fromOffset(12, 8), Text = string.format(mission.Text, mission.Goal), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
					local barBack = make("Frame", { Size = UDim2.new(1, -230, 0, 18), Position = UDim2.fromOffset(12, 44), BackgroundColor3 = Color3.fromRGB(230, 228, 240) }, row)
					corner(barBack, 9)
					outline(barBack, 2)
					local share = math.clamp(entry.Progress / mission.Goal, 0, 1)
					local barFill = make("Frame", { Size = UDim2.fromScale(math.max(share, 0.04), 1), BackgroundColor3 = C.Teal }, barBack)
					corner(barFill, 9)
					label(barBack, { Size = UDim2.fromScale(1, 1), Text = `{Format.Number(entry.Progress)} / {Format.Number(mission.Goal)}`, Font = BODY, TextSize = 12 })
					local reward = Format.Cash(mission.Reward * houseTier())
					if entry.Claimed then
						button(row, { Text = "DONE", Color = GREY, Size = UDim2.fromOffset(190, 44), Position = UDim2.new(1, -202, 0, 16) })
					elseif share >= 1 then
						button(row, { Text = `CLAIM {reward}`, Color = C.Green, TextColor = WHITE, Size = UDim2.fromOffset(190, 44), Position = UDim2.new(1, -202, 0, 16), OnClick = function()
							request("ClaimMission", i)
							task.delay(0.6, refreshWindow)
						end })
					else
						label(row, { Size = UDim2.fromOffset(100, 44), Position = UDim2.new(1, -212, 0, 16), Text = reward, TextSize = 20, TextColor3 = C.Green })
						button(row, { Text = `SKIP R$ {Config.DevProducts.MissionSkip.PriceHint}`, Color = C.Lemon, TextSize = 14, Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -104, 0, 16), OnClick = function()
							buy("Product", "MissionSkip")
						end })
					end
				end
			end
			-- Codes
			local codes = card(parent, UDim2.new(1, -4, 0, 70), UDim2.new(0, 0, 1, -76), C.Teal, nil, 12)
			label(codes, { Size = UDim2.fromOffset(110, 70), Text = "CODES", TextSize = 26, TextColor3 = WHITE }).Name = "CodesTitle"
			textStroke(codes:FindFirstChild("CodesTitle") :: TextLabel, 2)
			local box = make("TextBox", { Size = UDim2.new(1, -290, 0, 40), Position = UDim2.fromOffset(110, 15), BackgroundColor3 = WHITE, PlaceholderText = "Enter code...", Text = "", Font = TITLE, TextSize = 20, TextColor3 = INK, ClearTextOnFocus = false }, codes)
			corner(box, 10)
			outline(box, 3)
			button(codes, { Text = "REDEEM", Color = C.Lemon, Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -164, 0, 13), OnClick = function()
				request("RedeemCode", box.Text)
				box.Text = ""
			end })
			local best = player:GetAttribute("BestRace") or 0
			if best > 0 then
				label(parent, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -100), Text = `Best city race: {best}s`, Font = BODY, TextSize = 14 })
			end
		end,
	}

	------------------------------------------------ Menue links

	local menu = make("Frame", { Size = UDim2.fromOffset(78, 470), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 10), BackgroundTransparency = 1 }, root)
	make("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, menu)
	local badges = {}
	local menuButtons = {}
	local function menuButton(order: number, icon: string, text: string, color: Color3, onClick: () -> ())
		local face, holder = button(menu, { Text = "", Color = color, Size = UDim2.fromOffset(64, 58), LayoutOrder = order, OnClick = onClick, Radius = 14 })
		label(face, { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 2), Text = icon, TextSize = 26 })
		local caption = label(face, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -21), Text = text, TextSize = 13, TextColor3 = WHITE, TextWrapped = false })
		textStroke(caption, 1.5)
		local badge = make("Frame", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -12, 0, -8), BackgroundColor3 = C.Robber, Visible = false, ZIndex = 3 }, face)
		corner(badge, 10)
		outline(badge, 2)
		label(badge, { Size = UDim2.fromScale(1, 1), Text = "!", TextSize = 14, TextColor3 = WHITE, ZIndex = 3 })
		badges[text] = badge
		menuButtons[text] = holder
		return holder
	end
	menuButton(1, "🛒", "SHOP", C.Pink, function()
		openWindow("Shop")
	end)
	menuButton(2, "🚗", "CARS", C.Teal, function()
		openWindow("Garage")
	end)
	menuButton(3, "🏠", "HOME", C.Orange, function()
		openWindow("Home")
	end)
	menuButton(4, "🚨", "TEAM", C.Police, function()
		openWindow("Team")
	end)
	menuButton(5, "📋", "MISSIONS", C.Lemon, function()
		openWindow("Missions")
	end)
	local adHolder = menuButton(6, "🎁", "FREE $", C.Green, function()
		remotes.WatchAd:FireServer()
	end)
	adHolder.Visible = false
	menuButton(7, "💌", "INVITE", Color3.fromRGB(150, 90, 255), function()
		local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		if not ok or not canInvite then
			showToast("Invites are not available on this device.", C.Robber)
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Come drive with me in Turbo City!"
		pcall(SocialService.PromptGameInvite, SocialService, player, options)
	end)
	task.spawn(function()
		while gui.Parent do
			local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			adHolder.Visible = (ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable) or (RunService:IsStudio() and Config.DevProducts.AdCash.Id == 0)
			task.wait(30)
		end
	end)

	------------------------------------------------ Job und GPS rechts oben

	local jobFace, jobHolder = card(root, UDim2.fromOffset(260, 66), UDim2.new(1, -14, 0, 10), C.Cream, Vector2.new(1, 0), 14)
	jobHolder.Visible = false
	local jobTitle = label(jobFace, { Size = UDim2.new(1, -60, 0, 24), Position = UDim2.fromOffset(12, 6), Text = "JOB", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
	local jobInfo = label(jobFace, { Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(12, 28), Text = "", Font = BODY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	button(jobFace, { Text = "X", Color = C.Robber, TextColor = WHITE, Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -48, 0, 12), OnClick = function()
		request("CancelJob")
	end })

	local gpsFace, gpsHolder = card(root, UDim2.fromOffset(96, 96), UDim2.new(1, -14, 0, 88), INK, Vector2.new(1, 0), 48)
	gpsHolder.Visible = false
	local arrow = label(gpsFace, { Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -8), Text = "▲", TextSize = 46, TextColor3 = C.Lemon })
	local gpsDistance = label(gpsFace, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -26), Text = "0m", TextSize = 16, TextColor3 = WHITE })

	------------------------------------------------ Fahren unten rechts

	local carButton = button(root, { Text = "🚗\nCAR", Color = C.Teal, TextSize = 22, Size = UDim2.fromOffset(84, 78), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -150), Radius = 18, OnClick = function()
		if Drive.Driving then
			request("Despawn")
		else
			request("SpawnCar", player:GetAttribute("Car") or "bubble")
		end
	end })
	local nitroFace, nitroHolder = button(root, { Text = "NITRO", Color = C.Orange, TextColor = WHITE, TextSize = 20, Size = UDim2.fromOffset(84, 78), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -112, 1, -150), Radius = 18, OnClick = function()
		Drive.Nitro()
	end })
	nitroHolder.Visible = false
	textStroke(nitroFace, 2)
	local nitroFill = make("Frame", { Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = INK, BackgroundTransparency = 0.6, ZIndex = 2 }, nitroFace)
	corner(nitroFill, 18)
	Drive.OnNitroLocked = function()
		showToast("NITRO needs the Nitro pass!", C.Orange)
		buy("Pass", "Nitro")
	end

	local speedFace, speedHolder = card(root, UDim2.fromOffset(150, 64), UDim2.new(0.5, 0, 1, -12), INK, Vector2.new(0.5, 1), 20)
	speedHolder.Visible = false
	local speedLabel = label(speedFace, { Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 2), Text = "0", TextSize = 40, TextColor3 = C.Lemon })
	label(speedFace, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20), Text = "KM/H", TextSize = 14, TextColor3 = WHITE })

	------------------------------------------------ Angebote

	local offerFace, offerHolder = card(root, UDim2.fromOffset(270, 170), UDim2.new(1, -14, 0.5, 30), WHITE, Vector2.new(1, 0.5), 16)
	offerHolder.Visible = false
	local offerTop = make("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.Pink }, offerFace)
	corner(offerTop, 16)
	local offerHeader = label(offerTop, { Size = UDim2.fromScale(1, 1), Text = "SPECIAL OFFER", TextSize = 20, TextColor3 = WHITE })
	textStroke(offerHeader, 2)
	local offerName = label(offerFace, { Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 40), Text = "", TextSize = 24 })
	local offerReason = label(offerFace, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 68), Text = "", Font = BODY, TextSize = 13 })
	local offerKey: string? = nil
	local offerBuy = button(offerFace, { Text = "BUY", Color = C.Green, TextColor = WHITE, Size = UDim2.new(1, -110, 0, 40), Position = UDim2.new(0, 10, 1, -50), OnClick = function()
		if offerKey then
			buyKey(offerKey)
		end
		offerHolder.Visible = false
	end })
	button(offerFace, { Text = "NO", Color = C.Cream, Size = UDim2.fromOffset(80, 40), Position = UDim2.new(1, -90, 1, -50), OnClick = function()
		offerHolder.Visible = false
	end })
	local offerToken = 0
	local function showOffer(key: string, reason: string)
		local passKey = key:match("^Pass_(.+)$")
		local item = if passKey then Config.GamePasses[passKey] else Config.DevProducts[key]
		if not item then
			return
		end
		offerKey = key
		offerName.Text = if item.Kind == "Cash" then `{Format.Cash(cashPackAmount(item.Base))} Cash` else item.Name
		offerReason.Text = `{reason}\n{item.Description}`
		offerBuy.Text = `BUY  R$ {item.PriceHint}`
		offerHolder.Visible = true
		offerHolder.Position = UDim2.new(1, 300, 0.5, 30)
		TweenService:Create(offerHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(1, -14, 0.5, 30) }):Play()
		offerToken += 1
		local token = offerToken
		task.delay(15, function()
			if token == offerToken then
				offerHolder.Visible = false
			end
		end)
	end
	remotes.Offer.OnClientEvent:Connect(showOffer)

	------------------------------------------------ Aktualisieren

	local shownCash = player:GetAttribute("Cash") or 0
	local function refresh()
		local team = teamName()
		teamChip.Visible = true
		teamChip.BackgroundColor3 = TEAM_COLORS[team] or C.Citizen
		teamText.Text = TEAM_NAMES[team] or team
		local wanted = player:GetAttribute("Wanted") or 0
		wantedChip.Visible = wanted > 0
		wantedText.Text = string.rep("★", wanted) .. string.rep("☆", Config.MaxWanted - wanted)
		local bag = player:GetAttribute("Bag") or 0
		lootChip.Visible = bag > 0
		lootText.Text = `LOOT {Format.Cash(bag)} / {Format.Cash(player:GetAttribute("BagMax") or Config.BagSize)}`
		local job = player:GetAttribute("Job")
		jobHolder.Visible = job ~= nil
		jobTitle.Text = if job == "Race" then "CITY RACE" else "DELIVERY JOB"
		jobInfo.Text = player:GetAttribute("JobInfo") or ""
		badges.HOME.Visible = player:GetAttribute("DailyReady") == true
		local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Missions") or "[]")
		local claimable = false
		if ok then
			for _, entry in list do
				local mission = Config.MissionsById[entry.Id]
				if mission and not entry.Claimed and entry.Progress >= mission.Goal then
					claimable = true
				end
			end
		end
		badges.MISSIONS.Visible = claimable
		-- Multiplikator wie auf dem Server
		local multiplier = 1
		if player:GetAttribute("Pass_VIP") then
			multiplier *= Config.VipMultiplier
		end
		if player:GetAttribute("Pass_DoubleCash") then
			multiplier *= Config.DoubleCashMultiplier
		end
		if player.MembershipType == Enum.MembershipType.Premium then
			multiplier *= Config.PremiumMultiplier
		end
		multiplier *= 1 + Config.FriendBonusPer * math.min(player:GetAttribute("FriendsHere") or 0, Config.MaxFriendBonus)
		if (workspace:GetAttribute("PartyUntil") or 0) > os.time() then
			multiplier *= Config.PartyMultiplier
		end
		multiBadge.Visible = multiplier > 1.001
		multiLabel.Text = "x" .. (string.format("%.1f", multiplier):gsub("%.0$", ""))
		if currentWindow == "Missions" or currentWindow == "Home" then
			-- Fortschritt live (Garage/Shop nicht, sonst springt die Liste beim Scrollen)
			refreshWindow()
		end
	end
	player.AttributeChanged:Connect(function(name)
		if name ~= "Cash" then
			refresh()
		end
	end)
	player:GetPropertyChangedSignal("Team"):Connect(refresh)
	workspace:GetAttributeChangedSignal("PartyUntil"):Connect(refresh)
	refresh()

	-- Tagesbelohnung beim Start anbieten
	task.delay(6, function()
		if player:GetAttribute("DailyReady") and not currentWindow then
			openWindow("Home")
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		-- Geld zaehlt hoch
		local cash = player:GetAttribute("Cash") or 0
		shownCash += (cash - shownCash) * math.min(1, dt * 8)
		if math.abs(cash - shownCash) < 1 then
			shownCash = cash
		end
		cashLabel.Text = Format.Cash(shownCash)

		local serverNow = workspace:GetServerTimeNow()
		local jailUntil = player:GetAttribute("JailUntil")
		jailHolder.Visible = jailUntil ~= nil
		if jailUntil then
			jailTimer.Text = `Free in {Format.Time(jailUntil - serverNow)}`
		end
		local party = (workspace:GetAttribute("PartyUntil") or 0) - os.time()
		partyChip.Visible = party > 0
		if party > 0 then
			partyText.Text = `2X CASH PARTY {Format.Time(party)}`
		end
		if currentWindow == "Home" then
			local giftText = content:FindFirstChild("GiftText", true) :: TextLabel?
			if giftText then
				local at = player:GetAttribute("GiftAt")
				local reward = Format.Cash(player:GetAttribute("GiftReward") or 0)
				giftText.Text = if not at then "All gifts opened!" elseif serverNow >= at then `{reward} READY!` else `{reward} in {Format.Time(at - serverNow)}`
			end
		end

		-- GPS-Pfeil
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local target = Effects.MarkerPosition
		gpsHolder.Visible = target ~= nil and rootPart ~= nil
		if target and rootPart then
			local camera = workspace.CurrentCamera
			local offset = target - rootPart.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			if camera and flatOffset.Magnitude > 0.1 then
				local relative = camera.CFrame:VectorToObjectSpace(flatOffset.Unit)
				arrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))
			end
			gpsDistance.Text = `{math.floor(flatOffset.Magnitude)}m`
			local colors = { Delivery = C.Lemon, Race = C.Teal, Hideout = C.Green, Alarm = C.Robber }
			arrow.TextColor3 = colors[Effects.MarkerKind or ""] or C.Lemon
		end

		-- Fahren
		speedHolder.Visible = Drive.Driving
		nitroHolder.Visible = Drive.Driving
		carButton.Text = if Drive.Driving then "🅿️\nPARK" else "🚗\nCAR"
		if Drive.Driving then
			speedLabel.Text = tostring(math.floor(math.abs(Drive.Speed) * 1.25))
			speedLabel.TextColor3 = if Drive.NitroActive then C.Orange else C.Lemon
			nitroFill.Size = UDim2.fromScale(1, 1 - Drive.NitroCharge)
			nitroFace.Text = if player:GetAttribute("Pass_Nitro") then "NITRO" else "🔒\nNITRO"
		end
	end)
end

return UI
