-- HUD und Fenster im Turbo-City-Comic-Stil: dicke Tinten-Konturen, harte Schatten, LuckiestGuy-Schrift.
-- Basisgroesse 1000x560, per UIScale fuer Handy bis Monitor skaliert.
local AdService = game:GetService("AdService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

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

-- Einstellungen des Spielers (kommen als JSON-Attribut vom Server)
local settings = table.clone(Config.DefaultSettings)

---------------------------------------------------------------- Sounds (nur eingebaute rbxasset-Sounds)

local SOUNDS = {
	Click = { "rbxasset://sounds/button.wav", 0.4 },
	Cash = { "rbxasset://sounds/electronicpingshort.wav", 0.3 },
	Victory = { "rbxasset://sounds/victory.wav", 0.5 },
	Zap = { "rbxasset://sounds/swordlunge.wav", 0.5 },
	Flash = { "rbxasset://sounds/clickfast.wav", 0.7 },
	Spray = { "rbxasset://sounds/swordslash.wav", 0.6 },
}
local soundObjects = {}

local function playSound(name: string)
	if not settings.Sounds then
		return
	end
	local info = SOUNDS[name]
	if not info then
		return
	end
	local sound = soundObjects[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = info[1]
		sound.Volume = info[2]
		sound.Parent = SoundService
		soundObjects[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

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
	face.Activated:Connect(function()
		playSound("Click")
	end)
	if props.OnClick then
		face.Activated:Connect(props.OnClick)
	end
	return face, holder
end

---------------------------------------------------------------- Aktionen

local showToast: (string, Color3?) -> ()
local applySettings: () -> () = function() end -- wird in UI.Start gesetzt

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

-- Wie request, aber wartet auf die Antwort (fuer Gluecksrad)
local function invoke(action: string, ...: any): (any, string?)
	local ok, result, message = pcall(function(...)
		return remotes.Request:InvokeServer(action, ...)
	end, ...)
	if not ok then
		return nil, "Something went wrong"
	end
	return result, message
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
		-- Lange Meldungen umbrechen statt ueber den Handy-Rand zu laufen
		local pill = make("Frame", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = C.Cream, LayoutOrder = toastCount }, toastList)
		corner(pill, 17)
		outline(pill, 3, color or INK)
		make("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2) }, pill)
		local text_ = label(pill, { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.XY, Text = text, TextSize = 18, TextWrapped = true, TextColor3 = INK })
		make("UISizeConstraint", { MaxSize = Vector2.new(620, 120) }, text_)
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
		if settings.Feed then
			showToast(text, color or C.Pink)
		end
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
	local eventChip, eventText = chip(5, C.Orange)
	-- Karriere-Stufe mit XP-Balken (Update 2)
	local levelChip = make("Frame", { Size = UDim2.fromOffset(112, 28), BackgroundColor3 = INK, LayoutOrder = 0 }, chips)
	corner(levelChip, 14)
	outline(levelChip, 3)
	local levelFill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Teal }, levelChip)
	corner(levelFill, 14)
	local levelText = label(levelChip, { Size = UDim2.fromScale(1, 1), Text = "LV 1", TextSize = 17, TextColor3 = WHITE, ZIndex = 2 })
	textStroke(levelText, 1.5)

	------------------------------------------------ Gefaengnis

	local jailFace, jailHolder = card(root, UDim2.fromOffset(300, 206), UDim2.new(0.5, 0, 0.5, -10), C.Robber, Vector2.new(0.5, 0.5), 18)
	jailHolder.Visible = false
	local busted = label(jailFace, { Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 6), Text = "BUSTED!", TextSize = 44, TextColor3 = C.Lemon })
	textStroke(busted, 3)
	local jailTimer = label(jailFace, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 54), Text = "Free in 0:20", TextSize = 24, TextColor3 = WHITE })
	textStroke(jailTimer, 2)
	-- Putzdienst: jeder Wisch verkuerzt die Strafe (Update 2)
	local lastSweep = 0
	local sweepButton = button(jailFace, {
		Text = "🧹 SWEEP  -0.5s",
		Color = C.Teal,
		Size = UDim2.fromOffset(240, 44),
		Position = UDim2.new(0.5, 0, 0, 92),
		AnchorPoint = Vector2.new(0.5, 0),
		OnClick = function()
			local t = os.clock()
			if t - lastSweep >= Config.ChoreInterval and (player:GetAttribute("ChoreLeft") or 0) > 0 then
				lastSweep = t
				remotes.Chore:FireServer()
			end
		end,
	})
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
		Watch = { StarterPackOwned = true },
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

	-- GARAGE (mit Tuning-Reiter)
	local garageTab = "CARS"
	local function ownedCars(): { [string]: boolean }
		local owned = {}
		for id in string.gmatch(player:GetAttribute("OwnedCars") or "", "[^,]+") do
			owned[id] = true
		end
		return owned
	end
	local function tuneLevels(): { [string]: number }
		local levels = {}
		for id, level in string.gmatch(player:GetAttribute("Tune") or "", "([^,:]+):(%d+)") do
			levels[id] = tonumber(level) or 0
		end
		return levels
	end
	windows.Garage = {
		Title = "TURBO MOTORS",
		Color = C.Teal,
		Watch = { Tune = true, OwnedCars = true, Team = true, Paint = true, Car = true },
		Build = function(parent)
			tabs(parent, { "CARS", "TUNING" }, garageTab, function(name)
				garageTab = name
				refreshWindow()
			end)
			local owned = ownedCars()
			local team = teamName()
			if garageTab == "TUNING" then
				-- Robux-Abkuerzung fuer das ausgewaehlte Auto
				local selected = Config.CarsById[player:GetAttribute("Car") or "bubble"]
				local bar = card(parent, UDim2.new(1, -4, 0, 44), UDim2.fromOffset(0, 48), C.Lemon, nil, 12)
				label(bar, { Size = UDim2.new(1, -200, 1, 0), Position = UDim2.fromOffset(12, 0), Text = `MAX TUNE your {if selected then selected.Name else "car"} instantly!`, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left })
				button(bar, { Text = `R$ {Config.DevProducts.MaxTune.PriceHint}`, Color = C.Green, TextColor = WHITE, Size = UDim2.fromOffset(150, 34), Position = UDim2.new(1, -160, 0, 4), OnClick = function()
					buy("Product", "MaxTune")
				end })
				local scroll = grid(parent, Vector2.new(196, 150), 102)
				local levels = tuneLevels()
				local any = false
				for _, def in Config.Cars do
					local usable = if def.Team then def.Team == team and (not def.Pass or player:GetAttribute("Pass_" .. def.Pass) == true) elseif def.Pass then player:GetAttribute("Pass_" .. def.Pass) == true else owned[def.Id] == true
					if usable then
						any = true
						local level = levels[def.Id] or 0
						local speed = math.floor(def.Speed * (1 + Config.TuneSpeed * level))
						local text, color, action = "MAXED", GREY, nil
						if level < Config.TuneMax then
							local cost = Config.TuneCost(def, level + 1)
							text = `TUNE {Format.Cash(cost)}`
							color = if (player:GetAttribute("Cash") or 0) >= cost then C.Lemon else WHITE
							action = function()
								request("TuneCar", def.Id)
							end
						end
						local stars = string.rep("■", level) .. string.rep("□", Config.TuneMax - level)
						itemCard(scroll, def.Order, def.Color, def.Name, `Stage {stars}  {level}/{Config.TuneMax}\nTop speed {speed}`, text, color, action)
					end
				end
				if not any then
					label(scroll, { Size = UDim2.fromOffset(400, 40), Text = "Buy a car first!", TextSize = 22 })
				end
				return
			end
			local scroll = grid(parent, Vector2.new(196, 160), 50)
			scroll.Size = UDim2.new(1, 0, 1, -114)
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
					playSound("Click")
					request("SetPaint", paint.Id)
				end)
			end
		end,
	}

	-- HAUS + Belohnungen
	windows.Home = {
		Title = "MY HOUSE",
		Color = C.Orange,
		Watch = { DailyReady = true, DailyStreak = true, DailyReward = true, House = true, GiftIndex = true, GiftReward = true, Pass_Diamond = true },
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
		Watch = { Team = true },
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
	local codeDraft = ""
	windows.Missions = {
		Title = "DAILY MISSIONS",
		Color = C.Lemon,
		Watch = { Missions = true, BestRace = true },
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
			-- Der Text bleibt erhalten, auch wenn das Fenster neu aufgebaut wird
			local box = make("TextBox", { Size = UDim2.new(1, -290, 0, 40), Position = UDim2.fromOffset(110, 15), BackgroundColor3 = WHITE, PlaceholderText = "Enter code...", Text = codeDraft, Font = TITLE, TextSize = 20, TextColor3 = INK, ClearTextOnFocus = false }, codes)
			corner(box, 10)
			outline(box, 3)
			box:GetPropertyChangedSignal("Text"):Connect(function()
				codeDraft = box.Text
			end)
			button(codes, { Text = "REDEEM", Color = C.Lemon, Size = UDim2.fromOffset(150, 40), Position = UDim2.new(1, -164, 0, 13), OnClick = function()
				request("RedeemCode", box.Text)
				codeDraft = ""
				box.Text = ""
			end })
			local best = player:GetAttribute("BestRace") or 0
			if best > 0 then
				label(parent, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -96), Text = `Best city race: {best}s`, Font = BODY, TextSize = 14 })
			end
		end,
	}

	-- TROPHAEEN, TITEL, STATISTIK (Update 2)
	local trophyTab = "TROPHIES"
	local function statsTable(): { [string]: number }
		local ok, stats = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("StatsText") or "{}")
		return if ok and typeof(stats) == "table" then stats else {}
	end
	local function unlockedSet(): { [string]: boolean }
		local set = {}
		for id in string.gmatch(player:GetAttribute("Achievements") or "", "[^,]+") do
			set[id] = true
		end
		return set
	end
	windows.Trophies = {
		Title = "TROPHIES",
		Color = C.Orange,
		Watch = { Achievements = true, StatsText = true, Title = true, Level = true },
		Build = function(parent)
			tabs(parent, { "TROPHIES", "TITLES", "STATS" }, trophyTab, function(name)
				trophyTab = name
				refreshWindow()
			end)
			local stats = statsTable()
			local unlocked = unlockedSet()
			if trophyTab == "TROPHIES" then
				local scroll = grid(parent, Vector2.new(196, 150), 50)
				for i, achievement in Config.Achievements do
					local done = unlocked[achievement.Id] == true
					local value = math.min(stats[achievement.Stat] or 0, achievement.Goal)
					itemCard(scroll, if done then i + 100 else i, if done then C.Green else C.Lemon, achievement.Name, `{achievement.Text}\n+{Format.Cash(achievement.Reward)}  Title: {achievement.Title}`, if done then "UNLOCKED ✓" else `{Format.Number(value)} / {Format.Number(achievement.Goal)}`, if done then C.Green else WHITE, nil)
				end
			elseif trophyTab == "TITLES" then
				local scroll = grid(parent, Vector2.new(196, 150), 50)
				local current = player:GetAttribute("Title")
				itemCard(scroll, 0, GREY, "No title", "Show only your rank and level above your head.", if current then "REMOVE" else "EQUIPPED", if current then WHITE else GREY, if current then function()
					request("EquipTitle", "")
				end else nil)
				for i, achievement in Config.Achievements do
					local done = unlocked[achievement.Id] == true
					local equipped = current == achievement.Title
					local text, color, action
					if equipped then
						text, color = "EQUIPPED", GREY
					elseif done then
						text, color = "EQUIP", C.Teal
						action = function()
							request("EquipTitle", achievement.Title)
						end
					else
						text, color = "🔒 LOCKED", WHITE
					end
					itemCard(scroll, if done then i else i + 100, if done then C.Lemon else GREY, `« {achievement.Title} »`, `Trophy: {achievement.Name}\n{achievement.Text}`, text, color, action)
				end
			else
				local panel = card(parent, UDim2.new(1, -4, 1, -56), UDim2.fromOffset(0, 50), WHITE, nil, 14)
				local list = make("Frame", { Size = UDim2.new(1, -24, 1, -16), Position = UDim2.fromOffset(12, 8), BackgroundTransparency = 1 }, panel)
				make("UIGridLayout", { CellSize = UDim2.new(0.5, -8, 0, 30), CellPadding = UDim2.fromOffset(16, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
				local best = player:GetAttribute("BestRace") or 0
				local unlockedCount = 0
				for _ in unlocked do
					unlockedCount += 1
				end
				local lines = {
					{ "Level", `{stats.Level or 1}` },
					{ "Total earned", Format.Cash(stats.TotalEarned or 0) },
					{ "Packages delivered", Format.Number(stats.Deliveries or 0) },
					{ "Robbers arrested", Format.Number(stats.Arrests or 0) },
					{ "Loot grabbed", Format.Number(stats.Robberies or 0) },
					{ "Armored trucks cracked", Format.Number(stats.Trucks or 0) },
					{ "City races finished", Format.Number(stats.Races or 0) },
					{ "Best race", if best > 0 then `{best}s` else "-" },
					{ "Top speed", `{stats.TopSpeed or 0} km/h` },
					{ "Turbo Tokens", `{stats.Tokens or 0} / {Config.AchievementsById.Tokens.Goal}` },
					{ "Times busted", Format.Number(stats.Jailed or 0) },
					{ "Paint jobs", Format.Number(stats.Sprays or 0) },
					{ "Play time", string.format("%.1f h", (stats.PlayTime or 0) / 3600) },
					{ "Trophies", `{unlockedCount} / {#Config.Achievements}` },
				}
				for i, line in lines do
					local row = make("Frame", { BackgroundTransparency = 1, LayoutOrder = i }, list)
					label(row, { Size = UDim2.new(0.62, 0, 1, 0), Text = line[1], Font = BODY, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(70, 68, 100) })
					label(row, { Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.fromScale(0.62, 0), Text = line[2], TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false })
				end
			end
		end,
	}

	-- GLUECKSRAD (einmal am Tag gratis, nur Spielgeld)
	local spinning = false
	windows.Spin = {
		Title = "LUCKY WHEEL",
		Color = C.Pink,
		Build = function(parent)
			local prizes = Config.SpinPrizes
			local count = #prizes
			local holder = make("Frame", { Size = UDim2.fromOffset(300, 300), Position = UDim2.fromOffset(16, 22), BackgroundTransparency = 1 }, parent)
			local wheel = make("Frame", { Name = "Wheel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cream }, holder)
			corner(wheel, 150)
			outline(wheel, 5)
			for i, prize in prizes do
				local angle = math.rad((i - 1) * 360 / count)
				local x, y = math.sin(angle) * 104, -math.cos(angle) * 104
				local pill = make("Frame", { Size = UDim2.fromOffset(84, 36), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.5, y), Rotation = (i - 1) * 360 / count, BackgroundColor3 = prize.Color }, wheel)
				corner(pill, 12)
				outline(pill, 3)
				local text = label(pill, { Size = UDim2.fromScale(1, 1), Text = prize.Label, TextSize = 19, TextColor3 = WHITE, TextWrapped = false })
				textStroke(text, 2)
			end
			local hub = make("Frame", { Size = UDim2.fromOffset(70, 70), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = C.Pink }, holder)
			corner(hub, 35)
			outline(hub, 4)
			label(hub, { Size = UDim2.fromScale(1, 1), Text = "TURBO", TextSize = 15, TextColor3 = WHITE })
			local pointer = label(holder, { Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, -6), Text = "▼", TextSize = 44, TextColor3 = C.Robber, ZIndex = 3 })
			textStroke(pointer, 3)
			-- Rechte Seite: Erklaerung und Knopf
			label(parent, { Size = UDim2.new(1, -350, 0, 80), Position = UDim2.fromOffset(340, 30), Text = "One FREE spin every day!", TextSize = 28 })
			label(parent, { Size = UDim2.new(1, -350, 0, 60), Position = UDim2.fromOffset(340, 112), Text = "Win up to $25K (more with a better house) or bonus XP. No Robux needed.", Font = BODY, TextSize = 15 })
			local ready = player:GetAttribute("SpinReady") == true
			local spinFace = button(parent, {
				Text = if ready then "SPIN!" else "COME BACK TOMORROW",
				Color = if ready then C.Green else GREY,
				TextColor = WHITE,
				TextSize = if ready then 30 else 18,
				Size = UDim2.fromOffset(250, 60),
				Position = UDim2.fromOffset(340 + (656 - 340 - 250) / 2, 200),
				OnClick = function()
					if spinning or player:GetAttribute("SpinReady") ~= true then
						return
					end
					spinning = true
					local index, message = invoke("Spin")
					if typeof(index) ~= "number" or not wheel.Parent then
						spinning = false
						if message then
							showToast(message, C.Robber)
						end
						return
					end
					local start = wheel.Rotation % 360
					wheel.Rotation = start
					local target = start + 360 * 5 + ((-(index - 1) * 360 / count - start) % 360)
					TweenService:Create(wheel, TweenInfo.new(3.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Rotation = target }):Play()
					task.wait(3.7)
					spinning = false
					playSound("Victory")
					if message then
						showToast(message, C.Green)
					end
					if currentWindow == "Spin" then
						refreshWindow()
					end
				end,
			})
			spinFace.Name = "SpinButton"
		end,
	}

	-- EINSTELLUNGEN (werden gespeichert)
	local SETTING_ROWS = {
		{ Key = "Minimap", Text = "Minimap" },
		{ Key = "Gps", Text = "GPS light pillar" },
		{ Key = "Fov", Text = "Speed zoom effect" },
		{ Key = "Mph", Text = "Speed in MPH (instead of km/h)" },
		{ Key = "Feed", Text = "City announcements" },
		{ Key = "Sounds", Text = "Sounds" },
	}
	windows.Settings = {
		Title = "SETTINGS",
		Color = C.Police,
		Watch = { Settings = true },
		Build = function(parent)
			local list = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, parent)
			make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, list)
			for i, row in SETTING_ROWS do
				local face, rowHolder = card(list, UDim2.new(1, -4, 0, 46), UDim2.new(), WHITE, nil, 12)
				rowHolder.LayoutOrder = i
				label(face, { Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(14, 0), Text = row.Text, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
				local on = settings[row.Key] == true
				button(face, { Text = if on then "ON" else "OFF", Color = if on then C.Green else GREY, TextColor = WHITE, Size = UDim2.fromOffset(110, 34), Position = UDim2.new(1, -122, 0, 5), OnClick = function()
					settings[row.Key] = not on
					request("SetSetting", row.Key, not on)
					applySettings()
					refreshWindow()
				end })
			end
		end,
	}

	------------------------------------------------ Menue links

	-- Zwei Spalten, damit alle Knoepfe auch auf kleinen Handys Platz haben
	local menu = make("Frame", { Size = UDim2.fromOffset(140, 340), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 4), BackgroundTransparency = 1 }, root)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(64, 58), CellPadding = UDim2.fromOffset(8, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, menu)
	local badges = {}
	local menuButtons = {}
	local function menuButton(order: number, icon: string, text: string, color: Color3, onClick: () -> ())
		local face, holder = button(menu, { Text = "", Color = color, Size = UDim2.fromOffset(64, 58), LayoutOrder = order, OnClick = onClick, Radius = 14 })
		label(face, { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 2), Text = icon, TextSize = 26 })
		-- TextScaled: lange Namen wie "MISSIONS" oder "SETTINGS" passen sonst nicht in den Knopf
		local caption = label(face, { Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 3, 1, -20), Text = text, TextScaled = true, TextColor3 = WHITE, TextWrapped = false })
		make("UITextSizeConstraint", { MaxTextSize = 13 }, caption)
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
	menuButton(6, "🏆", "TROPHIES", C.Orange, function()
		openWindow("Trophies")
	end)
	menuButton(7, "🎡", "SPIN", C.Pink, function()
		openWindow("Spin")
	end)
	menuButton(8, "⚙️", "SETTINGS", GREY, function()
		openWindow("Settings")
	end)
	local adHolder = menuButton(10, "🎁", "FREE $", C.Green, function()
		remotes.WatchAd:FireServer()
	end)
	adHolder.Visible = false
	menuButton(9, "💌", "INVITE", Color3.fromRGB(150, 90, 255), function()
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

	local jobFace, jobHolder = card(root, UDim2.fromOffset(220, 66), UDim2.new(1, -148, 0, 8), C.Cream, Vector2.new(1, 0), 14)
	jobHolder.Visible = false
	local jobTitle = label(jobFace, { Size = UDim2.new(1, -60, 0, 24), Position = UDim2.fromOffset(12, 6), Text = "JOB", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
	local jobInfo = label(jobFace, { Size = UDim2.new(1, -60, 0, 32), Position = UDim2.fromOffset(12, 28), Text = "", Font = BODY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	button(jobFace, { Text = "X", Color = C.Robber, TextColor = WHITE, Size = UDim2.fromOffset(38, 38), Position = UDim2.new(1, -48, 0, 12), OnClick = function()
		request("CancelJob")
	end })

	local gpsFace, gpsHolder = card(root, UDim2.fromOffset(96, 96), UDim2.new(1, -14, 0, 142), INK, Vector2.new(1, 0), 48)
	gpsHolder.Visible = false
	local arrow = label(gpsFace, { Size = UDim2.fromOffset(60, 60), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -8), Text = "▲", TextSize = 46, TextColor3 = C.Lemon })
	local gpsDistance = label(gpsFace, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -26), Text = "0m", TextSize = 16, TextColor3 = WHITE })

	------------------------------------------------ Fahren unten rechts

	local carButton = button(root, { Text = "🚗\nCAR", Color = C.Teal, TextSize = 22, Size = UDim2.fromOffset(84, 78), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -150), Radius = 18, OnClick = function()
		if Drive.Driving then
			request("Despawn")
		elseif teamName() == "Police" then
			request("SpawnCar", player:GetAttribute("TeamCar") or "patrol")
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
	local speedUnit = label(speedFace, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20), Text = "KM/H", TextSize = 14, TextColor3 = WHITE })

	------------------------------------------------ Angebote

	local offerFace, offerHolder = card(root, UDim2.fromOffset(270, 170), UDim2.new(0.5, 0, 1, -84), WHITE, Vector2.new(0.5, 1), 16)
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
		offerHolder.Position = UDim2.new(0.5, 0, 1, 200)
		TweenService:Create(offerHolder, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -84) }):Play()
		offerToken += 1
		local token = offerToken
		task.delay(15, function()
			if token == offerToken then
				offerHolder.Visible = false
			end
		end)
	end
	remotes.Offer.OnClientEvent:Connect(showOffer)

	------------------------------------------------ Grosses Banner: Stufe, Trophaee, Blitzer, Spray (Update 2)

	local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, Visible = false, ZIndex = 9 }, root)
	local bannerFace, bannerHolder = card(root, UDim2.fromOffset(440, 92), UDim2.new(0.5, 0, 0, 150), C.Lemon, Vector2.new(0.5, 0), 20)
	bannerHolder.Visible = false
	bannerHolder.ZIndex = 8
	local bannerScale = make("UIScale", {}, bannerHolder)
	local bannerTitle = label(bannerFace, { Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 4), Text = "", TextSize = 40, TextColor3 = WHITE, TextWrapped = false })
	textStroke(bannerTitle, 3)
	local bannerText = label(bannerFace, { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 52), Text = "", Font = BODY, TextSize = 15 })
	local bannerToken = 0
	local BANNER_COLORS = { Level = C.Teal, Trophy = C.Lemon, Flash = C.Cream, Spray = C.Pink }
	remotes.Celebrate.OnClientEvent:Connect(function(title: string, subtitle: string, kind: string)
		bannerFace.BackgroundColor3 = BANNER_COLORS[kind] or C.Lemon
		bannerTitle.TextColor3 = if kind == "Flash" then C.Robber else WHITE
		bannerTitle.Text = title
		bannerText.Text = subtitle
		bannerHolder.Visible = true
		bannerScale.Scale = 0.6
		TweenService:Create(bannerScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if kind == "Flash" then
			playSound("Flash")
			flash.Visible = true
			flash.BackgroundTransparency = 0.25
			TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		elseif kind == "Spray" then
			playSound("Spray")
		else
			playSound("Victory")
		end
		bannerToken += 1
		local token = bannerToken
		task.delay(if kind == "Flash" then 1.8 else 3, function()
			if token == bannerToken then
				bannerHolder.Visible = false
				flash.Visible = false
			end
		end)
	end)

	------------------------------------------------ Tutorial oben links (Update 2)

	local tutorialFace, tutorialHolder = card(root, UDim2.fromOffset(290, 58), UDim2.fromOffset(12, 8), C.Cream, nil, 14)
	tutorialHolder.Visible = false
	local tutorialTitle = label(tutorialFace, { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 4), Text = "TUTORIAL", TextSize = 17, TextColor3 = C.Pink, TextXAlignment = Enum.TextXAlignment.Left })
	local tutorialText = label(tutorialFace, { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 24), Text = "", Font = BODY, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })

	------------------------------------------------ Minikarte oben rechts (Update 2)

	local MAP_SIZE = 124
	local mapFace, mapHolder = card(root, UDim2.fromOffset(MAP_SIZE, MAP_SIZE), UDim2.new(1, -14, 0, 8), INK, Vector2.new(1, 0), 14)
	local mapArea = make("Frame", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = Color3.fromRGB(120, 200, 95), ClipsDescendants = true }, mapFace)
	corner(mapArea, 10)
	local mapRange = Config.CityHalf() + 40
	local function mapPosition(x: number, z: number): UDim2
		return UDim2.fromScale(math.clamp((x + mapRange) / (2 * mapRange), 0.03, 0.97), math.clamp((z + mapRange) / (2 * mapRange), 0.03, 0.97))
	end
	do
		local cityShare = Config.CityHalf() / mapRange
		make("Frame", { Size = UDim2.fromScale(1, 1 - (1 + cityShare) / 2), Position = UDim2.fromScale(0, (1 + cityShare) / 2), BackgroundColor3 = Color3.fromRGB(250, 225, 160) }, mapArea)
		make("Frame", { Size = UDim2.fromScale(cityShare, cityShare), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(214, 208, 200) }, mapArea)
		local roadShare = Config.Road / (2 * mapRange)
		for k = 0, Config.Grid do
			local line = Config.RoadLine(k)
			local at = (line + mapRange) / (2 * mapRange)
			make("Frame", { Size = UDim2.fromScale(roadShare, cityShare), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(at, 0.5), BackgroundColor3 = Color3.fromRGB(58, 58, 72) }, mapArea)
			make("Frame", { Size = UDim2.fromScale(cityShare, roadShare), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, at), BackgroundColor3 = Color3.fromRGB(58, 58, 72) }, mapArea)
		end
		for _, landmark in Config.Landmarks do
			local center = Config.BlockCenter(landmark.Block[1], landmark.Block[2])
			local dot = make("Frame", { Size = UDim2.fromOffset(13, 13), AnchorPoint = Vector2.new(0.5, 0.5), Position = mapPosition(center.X, center.Z), BackgroundColor3 = landmark.Color, ZIndex = 2 }, mapArea)
			corner(dot, 7)
			outline(dot, 1.5)
			label(dot, { Size = UDim2.fromScale(1, 1), Text = landmark.Icon, TextSize = 10, TextColor3 = INK, ZIndex = 2, TextWrapped = false })
		end
	end
	local mapDots = {}
	local function mapDot(index: number): Frame
		local dot = mapDots[index]
		if not dot then
			dot = make("Frame", { Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 }, mapArea)
			corner(dot, 5)
			outline(dot, 1.5, WHITE)
			mapDots[index] = dot
		end
		return dot
	end
	local selfArrow = label(mapArea, { Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Text = "▲", TextSize = 18, TextColor3 = WHITE, ZIndex = 4, TextWrapped = false })
	textStroke(selfArrow, 2)
	local lastMapUpdate = 0
	local function updateMinimap()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local used = 0
		local function place(position: Vector3, color: Color3, size: number)
			used += 1
			local dot = mapDot(used)
			dot.Visible = true
			dot.BackgroundColor3 = color
			dot.Size = UDim2.fromOffset(size, size)
			dot.Position = mapPosition(position.X, position.Z)
		end
		if Effects.MarkerPosition then
			place(Effects.MarkerPosition, Effects.MarkerColors[Effects.MarkerKind or ""] or C.Lemon, 11)
		end
		local truckAt = workspace:GetAttribute("TruckAt")
		if typeof(truckAt) == "Vector3" then
			place(truckAt, C.Lemon, 12)
		end
		-- Polizisten sehen gesuchte Raeuber auf der Karte
		if teamName() == "Police" then
			for _, other in Players:GetPlayers() do
				local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if other ~= player and otherRoot and (other:GetAttribute("Wanted") or 0) > 0 then
					place(otherRoot.Position, C.Robber, 9)
				end
			end
		end
		for i = used + 1, #mapDots do
			mapDots[i].Visible = false
		end
		selfArrow.Visible = rootPart ~= nil
		if rootPart then
			selfArrow.Position = mapPosition(rootPart.Position.X, rootPart.Position.Z)
			local camera = workspace.CurrentCamera
			if camera then
				local look = camera.CFrame.LookVector
				selfArrow.Rotation = math.deg(math.atan2(look.X, -look.Z))
			end
		end
	end

	-- Einstellungen anwenden (Minikarte, GPS, Zoom-Effekt, Sounds ...)
	applySettings = function()
		Drive.FovEffects = settings.Fov ~= false
		Effects.ShowPillar = settings.Gps ~= false
		mapHolder.Visible = settings.Minimap ~= false
		jobHolder.Position = if mapHolder.Visible then UDim2.new(1, -148, 0, 8) else UDim2.new(1, -14, 0, 8)
		gpsHolder.Position = if mapHolder.Visible then UDim2.new(1, -14, 0, 142) else UDim2.new(1, -14, 0, 82)
		speedUnit.Text = if settings.Mph then "MPH" else "KM/H"
	end
	local function loadSettings()
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Settings") or "{}")
		if ok and typeof(decoded) == "table" then
			for key, default in Config.DefaultSettings do
				local value = decoded[key]
				settings[key] = if typeof(value) == "boolean" then value else default
			end
		end
		applySettings()
	end

	------------------------------------------------ Aktualisieren

	local shownCash = player:GetAttribute("Cash") or 0
	local lastCash = shownCash
	local lastCashSound = 0
	local function refresh(changed: string?)
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
		-- Stufe, Tutorial, Gluecksrad (Update 2)
		local level = player:GetAttribute("Level") or 1
		local xpNext = player:GetAttribute("XPNext") or 1
		levelText.Text = `LV {level}`
		levelFill.Size = UDim2.fromScale(math.clamp((player:GetAttribute("XP") or 0) / math.max(1, xpNext), 0, 1), 1)
		local step = player:GetAttribute("TutorialStep")
		local stepInfo = step and Config.Tutorial[step]
		tutorialHolder.Visible = stepInfo ~= nil
		if stepInfo then
			tutorialTitle.Text = `TUTORIAL {step}/{#Config.Tutorial}  ·  +{Format.Cash(stepInfo.Reward)}`
			tutorialText.Text = stepInfo.Text
		end
		badges.SPIN.Visible = player:GetAttribute("SpinReady") == true
		local event = Config.EventsById[workspace:GetAttribute("EventId") or ""]
		eventChip.BackgroundColor3 = if event then event.Color else C.Orange
		-- Nur Fenster neu aufbauen, die dieses Attribut anzeigen (sonst geht z. B. getippter Text verloren)
		local window = currentWindow and windows[currentWindow]
		if changed and window and window.Watch and window.Watch[changed] and not UserInputService:GetFocusedTextBox() then
			refreshWindow()
		end
	end
	player.AttributeChanged:Connect(function(name)
		if name == "Settings" then
			loadSettings()
		elseif name == "StunnedUntil" then
			playSound("Zap")
		end
		if name ~= "Cash" then
			refresh(name)
		end
	end)
	player:GetPropertyChangedSignal("Team"):Connect(function()
		refresh("Team")
	end)
	workspace:GetAttributeChangedSignal("PartyUntil"):Connect(refresh)
	workspace:GetAttributeChangedSignal("EventId"):Connect(refresh)
	loadSettings()
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
		if cash > lastCash and os.clock() - lastCashSound > 0.3 then
			lastCashSound = os.clock()
			playSound("Cash")
		end
		lastCash = cash
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
			sweepButton.Text = if (player:GetAttribute("ChoreLeft") or 0) > 0 then "🧹 SWEEP  -0.5s" else "✨ SPARKLING CLEAN!"
		end
		local eventLeft = (workspace:GetAttribute("EventUntil") or 0) - os.time()
		local event = Config.EventsById[workspace:GetAttribute("EventId") or ""]
		eventChip.Visible = event ~= nil and eventLeft > 0
		if event and eventLeft > 0 then
			eventText.Text = `{event.Name} {Format.Time(eventLeft)}`
		end
		if mapHolder.Visible and os.clock() - lastMapUpdate > 0.1 then
			lastMapUpdate = os.clock()
			updateMinimap()
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
		gpsHolder.Visible = target ~= nil and rootPart ~= nil and settings.Gps ~= false
		if target and rootPart then
			local camera = workspace.CurrentCamera
			local offset = target - rootPart.Position
			local flatOffset = Vector3.new(offset.X, 0, offset.Z)
			if camera and flatOffset.Magnitude > 0.1 then
				local relative = camera.CFrame:VectorToObjectSpace(flatOffset.Unit)
				arrow.Rotation = math.deg(math.atan2(relative.X, -relative.Z))
			end
			gpsDistance.Text = `{math.floor(flatOffset.Magnitude)}m`
			arrow.TextColor3 = Effects.MarkerColors[Effects.MarkerKind or ""] or C.Lemon
		end

		-- Fahren
		speedHolder.Visible = Drive.Driving
		nitroHolder.Visible = Drive.Driving
		carButton.Text = if Drive.Driving then "🅿️\nPARK" else "🚗\nCAR"
		if Drive.Driving then
			local kmh = math.abs(Drive.Speed) * Config.KmhPerStud
			speedLabel.Text = tostring(math.floor(if settings.Mph then kmh * 0.621 else kmh))
			speedLabel.TextColor3 = if Drive.NitroActive then C.Orange else C.Lemon
			nitroFill.Size = UDim2.fromScale(1, 1 - Drive.NitroCharge)
			nitroFace.Text = if player:GetAttribute("Pass_Nitro") then "NITRO" else "🔒\nNITRO"
		end
	end)
end

return UI
