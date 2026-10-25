-- Komplette Oberflaeche im "Fire Blaster"-Stil: dunkle Tinte, Flammen-Verlauf, kursive Renn-Schrift.
-- Lobby: Muenzen, Menue, Abstimmung, Garage, Shop. Rennen: Platz, Runde, Zeit, Minimap, Item, Drift, Tempo.
local AdService = game:GetService("AdService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local KartFactory = require(ReplicatedStorage.Shared.KartFactory)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Tracks = require(ReplicatedStorage.Shared.Tracks)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {
	LastCount = nil :: number?,
	ShoutToken = nil :: any,
	MyVote = nil :: string?,
}

local THEME = {
	Ink = Color3.fromRGB(16, 13, 22),
	Panel = Color3.fromRGB(28, 23, 36),
	Panel2 = Color3.fromRGB(42, 35, 54),
	Text = Color3.fromRGB(248, 244, 252),
	Muted = Color3.fromRGB(170, 160, 190),
	FlameA = Color3.fromRGB(255, 228, 100),
	FlameB = Color3.fromRGB(255, 138, 30),
	FlameC = Color3.fromRGB(232, 57, 42),
	Blue = Color3.fromRGB(62, 200, 255),
	Gold = Color3.fromRGB(255, 200, 58),
	Green = Color3.fromRGB(90, 225, 120),
	Red = Color3.fromRGB(255, 85, 85),
}
local TITLE = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local BODYX = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

-- Soundeffekte (eingebaute Roblox-Sounds), abschaltbar in den Einstellungen
local SOUNDS = {
	Click = { "rbxasset://sounds/button.wav", 0.35, 1 },
	Beep = { "rbxasset://sounds/electronicpingshort.wav", 0.6, 1 },
	Go = { "rbxasset://sounds/electronicpingshort.wav", 0.8, 1.6 },
	Boost = { "rbxasset://sounds/swordlunge.wav", 0.5, 1.2 },
	Hit = { "rbxasset://sounds/collide.wav", 0.7, 1 },
	Coin = { "rbxasset://sounds/clickfast.wav", 0.45, 1.5 },
	Item = { "rbxasset://sounds/electronicpingshort.wav", 0.5, 2 },
	Win = { "rbxasset://sounds/victory.wav", 0.7, 1 },
	Quest = { "rbxasset://sounds/electronicpingshort.wav", 0.6, 1.25 },
}
local soundCache: { [string]: Sound } = {}
local function sfx(name: string)
	if player:GetAttribute("Set_Sfx") == false then
		return
	end
	local def = SOUNDS[name]
	if not def then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = def[1]
		sound.Volume = def[2]
		sound.PlaybackSpeed = def[3]
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end
UI.Sfx = sfx

local function create(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 8) })
end

local function stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return create("UIStroke", {
		Color = color or Color3.new(1, 1, 1),
		Thickness = thickness or 1,
		Transparency = transparency or 0.85,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function flameGradient(rotation: number?): UIGradient
	return create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, THEME.FlameA),
			ColorSequenceKeypoint.new(0.55, THEME.FlameB),
			ColorSequenceKeypoint.new(1, THEME.FlameC),
		}),
		Rotation = rotation or 90,
	})
end

local function text(props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		FontFace = BODY,
		TextColor3 = THEME.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	for key, value in props do
		defaults[key] = value
	end
	return create("TextLabel", defaults)
end

local function panel(props: { [string]: any }): Frame
	local defaults = { BackgroundColor3 = THEME.Panel, BackgroundTransparency = 0.08, BorderSizePixel = 0 }
	for key, value in props do
		defaults[key] = value
	end
	local frame = create("Frame", defaults)
	corner(10).Parent = frame
	stroke(Color3.new(1, 1, 1), 1, 0.88).Parent = frame
	return frame
end

-- Knopf; style: "Flame" (Hauptaktion), "Robux" (Gold), "Dark"
local function button(props: { [string]: any }, style: string?): TextButton
	local s = style or "Dark"
	local defaults = {
		AutoButtonColor = true,
		BackgroundColor3 = if s == "Flame" then Color3.new(1, 1, 1) elseif s == "Robux" then THEME.Gold else THEME.Panel2,
		BorderSizePixel = 0,
		FontFace = BODYX,
		TextSize = 16,
		TextColor3 = if s == "Robux" then THEME.Ink else THEME.Text,
	}
	for key, value in props do
		defaults[key] = value
	end
	local b = create("TextButton", defaults)
	b.Activated:Connect(function()
		sfx("Click")
	end)
	corner(8).Parent = b
	if s == "Flame" then
		flameGradient(0).Parent = b
		create("UIStroke", { Color = THEME.FlameC, Thickness = 1.5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }).Parent = b
		create("UIStroke", { Color = Color3.fromRGB(90, 20, 0), Thickness = 1.5, Transparency = 0.3 }).Parent = b
	elseif s == "Robux" then
		create("UIStroke", { Color = Color3.fromRGB(255, 240, 160), Thickness = 1.5, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }).Parent = b
	else
		stroke(Color3.new(1, 1, 1), 1, 0.85).Parent = b
	end
	return b
end

-- Schraeger Flammen-Akzentstreifen (Markenzeichen des Stils)
local function slash(parent: Instance, x: number, height: number)
	local s = create("Frame", {
		Size = UDim2.fromOffset(6, height),
		Position = UDim2.fromOffset(x, -4),
		Rotation = 18,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = parent,
	})
	flameGradient(90).Parent = s
	return s
end

local function ordinal(n: number): string
	local suffix = "TH"
	if n % 100 < 11 or n % 100 > 13 then
		suffix = ({ "ST", "ND", "RD" })[n % 10] or "TH"
	end
	return suffix
end

local function robux(price: number): string
	return "R$ " .. Format.Number(price)
end

function UI.Init(controller)
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = create("ScreenGui", {
		Name = "FireBlasterUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = playerGui,
	})
	local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local scale = create("UIScale", { Parent = root })
	local function rescale()
		local vp = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(vp.X / 1000, vp.Y / 560), 0.55, 1.3)
		scale.Scale = s
		root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	------------------------------------------------ Toasts

	local toastHolder = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 92),
		Size = UDim2.fromOffset(520, 180),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local toastOrder = 0
	local function toast(message: string, color: Color3?)
		toastOrder += 1
		local pill = create("Frame", {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = THEME.Ink,
			BackgroundTransparency = 0.1,
			LayoutOrder = toastOrder,
			Parent = toastHolder,
		}, {
			corner(17),
			create("UIStroke", { Color = color or THEME.FlameB, Thickness = 1.5, Transparency = 0.2 }),
			create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16) }),
		})
		text({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = message, TextSize = 17, FontFace = BODYX, TextColor3 = color or THEME.Text, Parent = pill })
		local children = {}
		for _, child in toastHolder:GetChildren() do
			if child:IsA("Frame") then
				table.insert(children, child)
			end
		end
		if #children > 4 then
			table.sort(children, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			children[1]:Destroy()
		end
		task.delay(3.5, function()
			if pill.Parent then
				pill:Destroy()
			end
		end)
	end
	remotes.Notify.OnClientEvent:Connect(toast)
	remotes.Announce.OnClientEvent:Connect(function(message, color)
		toast(message, color or THEME.Gold)
	end)

	------------------------------------------------ Muenzen (oben rechts)

	local coinPill = panel({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(176, 44),
		BackgroundColor3 = THEME.Ink,
		Parent = root,
	})
	local coinIcon = create("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(9, 8), BackgroundColor3 = THEME.Gold, Parent = coinPill }, {
		create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		create("UIStroke", { Color = Color3.fromRGB(180, 110, 0), Thickness = 2 }),
	})
	text({ Size = UDim2.fromScale(1, 1), Text = "C", FontFace = TITLE, TextSize = 18, TextColor3 = Color3.fromRGB(150, 80, 0), Parent = coinIcon })
	local coinText = text({ Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -86, 1, 0), Text = "0", FontFace = TITLE, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = coinPill })
	local coinPlus = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(30, 30), Text = "+", TextSize = 22, Parent = coinPill }, "Flame")
	local winsText = text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 58),
		Size = UDim2.fromOffset(300, 18),
		Text = "",
		TextSize = 14,
		TextColor3 = THEME.Muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = root,
	})

	-- XP-Balken bis zum naechsten Level
	local xpBack = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 80), Size = UDim2.fromOffset(170, 6), BackgroundColor3 = THEME.Panel2, BorderSizePixel = 0, Parent = root }, { corner(3) })
	local xpFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = xpBack }, { corner(3) })
	flameGradient(0).Parent = xpFill

	------------------------------------------------ Status-Banner (oben Mitte)

	local banner = panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(380, 70),
		BackgroundColor3 = THEME.Ink,
		ClipsDescendants = true,
		Parent = root,
	})
	slash(banner, 14, 80)
	slash(banner, 26, 80)
	local bannerTitle = text({ Position = UDim2.fromOffset(40, 6), Size = UDim2.new(1, -56, 0, 22), Text = "", FontFace = BODYX, TextSize = 16, TextColor3 = THEME.FlameB, Parent = banner })
	local bannerMain = text({ Position = UDim2.fromOffset(40, 28), Size = UDim2.new(1, -56, 0, 36), Text = "", FontFace = TITLE, TextSize = 32, Parent = banner })

	------------------------------------------------ Linkes Menue (Lobby)

	-- Zwei Spalten, damit alle Knoepfe auch auf kleinen Handys in die Hoehe passen
	local menu = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(148, 400),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(70, 60),
			CellPadding = UDim2.fromOffset(8, 8),
			FillDirectionMaxCells = 2,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	local function menuButton(order: number, icon: string, label: string): (TextButton, TextLabel, TextLabel)
		local b = create("TextButton", {
			Size = UDim2.fromOffset(70, 60),
			BackgroundColor3 = THEME.Ink,
			BackgroundTransparency = 0.1,
			AutoButtonColor = true,
			Text = "",
			LayoutOrder = order,
			ClipsDescendants = false,
			Parent = menu,
		}, { corner(12), stroke(Color3.new(1, 1, 1), 1, 0.85) })
		local accent = create("Frame", { Size = UDim2.new(1, -20, 0, 3), Position = UDim2.fromOffset(10, 0), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = b })
		flameGradient(0).Parent = accent
		text({ Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 30), Text = icon, TextSize = 24, Parent = b })
		local l = text({ Position = UDim2.fromOffset(3, 37), Size = UDim2.new(1, -6, 0, 17), Text = label, FontFace = BODYX, TextScaled = true, Parent = b })
		create("UITextSizeConstraint", { MaxTextSize = 13, Parent = l })
		b.Activated:Connect(function()
			sfx("Click")
		end)
		local badge = text({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 0,
			BackgroundColor3 = THEME.Red,
			Text = "!",
			FontFace = BODYX,
			TextSize = 15,
			Visible = false,
			Parent = b,
		})
		create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
		return b, l, badge
	end
	local garageButton = menuButton(1, "🏎️", "GARAGE")
	local shopButton, _, shopBadge = menuButton(2, "🛒", "SHOP")
	local questButton, _, questBadge = menuButton(3, "📜", "QUESTS")
	local profileButton = menuButton(4, "🏆", "PROFILE")
	local dailyButton, dailyLabel, dailyBadge = menuButton(5, "🎁", "DAILY")
	local giftButton, giftLabel, giftBadge = menuButton(6, "⏱️", "GIFT")
	local adButton, _, adBadge = menuButton(7, "📺", "FREE")
	local inviteButton = menuButton(8, "👋", "INVITE")
	local settingsButton = menuButton(9, "⚙️", "SETTINGS")
	local spectateButton, spectateLabel = menuButton(10, "👁️", "WATCH")
	shopBadge.Text = "%"
	shopBadge.BackgroundColor3 = THEME.FlameB
	shopBadge.Visible = true
	adBadge.Text = "C"
	adBadge.BackgroundColor3 = THEME.Gold
	adBadge.TextColor3 = THEME.Ink
	adBadge.Visible = true
	adButton.Visible = false

	------------------------------------------------ Fenster

	local backdrop = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.5,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	local windows = {}
	local openName: string? = nil

	local function window(name: string, title: string, width: number, height: number): (Frame, Frame)
		local w = panel({
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(width, height),
			BackgroundColor3 = THEME.Ink,
			BackgroundTransparency = 0.02,
			Visible = false,
			ZIndex = 21,
			ClipsDescendants = true,
			Parent = root,
		})
		local header = create("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = THEME.Panel, BorderSizePixel = 0, ZIndex = 21, Parent = w })
		slash(header, 16, 70).ZIndex = 22
		slash(header, 28, 70).ZIndex = 22
		local t = text({ Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -110, 1, 0), Text = title, FontFace = TITLE, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = header })
		flameGradient(90).Parent = t
		local close = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(38, 38), Text = "X", FontFace = TITLE, TextSize = 20, ZIndex = 22, Parent = header })
		close.Activated:Connect(function()
			UI.Close()
		end)
		local body = create("Frame", { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), BackgroundTransparency = 1, ZIndex = 21, Parent = w })
		windows[name] = w
		return w, body
	end

	function UI.Open(name: string)
		for key, w in windows do
			w.Visible = key == name
		end
		openName = name
		backdrop.Visible = true
		local w = windows[name]
		local s = w:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = w })
		s.Scale = 0.85
		TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	function UI.Close()
		for _, w in windows do
			w.Visible = false
		end
		openName = nil
		backdrop.Visible = false
	end
	backdrop.Activated:Connect(UI.Close)

	local function tabs(body: Frame, names: { string }, onSelect: (string) -> ()): { [string]: TextButton }
		local bar = create("Frame", { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 36), BackgroundTransparency = 1, ZIndex = 22, Parent = body }, {
			create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
		})
		local result = {}
		for _, name in names do
			local b = button({ Size = UDim2.fromOffset(130, 36), Text = name:upper(), FontFace = TITLE, TextSize = 18, ZIndex = 22, Parent = bar })
			b.Activated:Connect(function()
				onSelect(name)
			end)
			result[name] = b
		end
		return result
	end

	local function scroller(body: Frame, columns: number, cellHeight: number): ScrollingFrame
		local s = create("ScrollingFrame", {
			Position = UDim2.fromOffset(16, 56),
			Size = UDim2.new(1, -32, 1, -68),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = THEME.FlameB,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ZIndex = 22,
			Parent = body,
		})
		create("UIGridLayout", {
			CellSize = UDim2.new(1 / columns, -10, 0, cellHeight),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = s,
		})
		create("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = s })
		return s
	end

	------------------------------------------------ Garage

	local _, garageBody = window("Garage", "GARAGE", 820, 470)
	local garageKarts = scroller(garageBody, 4, 250)
	local garageFlames = scroller(garageBody, 4, 160)
	local garagePaints = scroller(garageBody, 4, 160)
	local garageTabs = tabs(garageBody, { "Karts", "Flames", "Paint" }, function(name)
		garageKarts.Visible = name == "Karts"
		garageFlames.Visible = name == "Flames"
		garagePaints.Visible = name == "Paint"
	end)
	garageFlames.Visible = false
	garagePaints.Visible = false
	local kartCards = {}
	local function statBar(parent: Instance, y: number, label: string, value: number)
		text({ Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(36, 14), Text = label, TextSize = 12, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = parent })
		local back = create("Frame", { Position = UDim2.new(0, 48, 0, y + 3), Size = UDim2.new(1, -58, 0, 8), BackgroundColor3 = THEME.Panel2, BorderSizePixel = 0, ZIndex = 23, Parent = parent }, { corner(4) })
		local fill = create("Frame", { Size = UDim2.fromScale(math.clamp(value, 0.05, 1), 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 23, Parent = back }, { corner(4) })
		flameGradient(0).Parent = fill
	end
	for _, kart in Config.Karts do
		local card = panel({ LayoutOrder = kart.Order, BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = garageKarts })
		local view = create("ViewportFrame", {
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 110),
			BackgroundColor3 = THEME.Panel2,
			Ambient = Color3.fromRGB(200, 190, 210),
			LightColor = Color3.fromRGB(255, 240, 220),
			LightDirection = Vector3.new(-1, -1, -0.5),
			ZIndex = 22,
			Parent = card,
		}, { corner(8) })
		local model = KartFactory.Build(kart.Id, if kart.Pass then "Gold" else "Orange", { Bot = true, DriverColor = kart.Accent })
		model:PivotTo(CFrame.Angles(0, math.rad(215), 0))
		model.Parent = view
		local cam = create("Camera", { CFrame = CFrame.lookAt(Vector3.new(0, 5, 13), Vector3.new(0, 0.6, 0)), FieldOfView = 40, Parent = view })
		view.CurrentCamera = cam
		text({ Position = UDim2.fromOffset(10, 120), Size = UDim2.new(1, -20, 0, 22), Text = kart.Name:upper(), FontFace = TITLE, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = card })
		statBar(card, 146, "SPD", (kart.Speed - 66) / 22)
		statBar(card, 162, "ACC", (kart.Accel - 30) / 16)
		statBar(card, 178, "TRN", (kart.Turn - 2) / 0.4)
		local action = button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = "", ZIndex = 23, Parent = card }, "Flame")
		action.Activated:Connect(function()
			remotes.Shop:FireServer("BuyKart", kart.Id)
		end)
		kartCards[kart.Id] = { Card = card, Button = action }
	end
	local flameCards = {}
	for _, flame in Config.Flames do
		local card = panel({ LayoutOrder = flame.Order, BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = garageFlames })
		local swatch = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 22, Parent = card }, { corner(8) })
		create("UIGradient", {
			Color = if flame.Rainbow
				then ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 60)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 220, 120)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 140, 255)),
				})
				else ColorSequence.new(flame.Colors[1], flame.Colors[2]),
			Parent = swatch,
		})
		text({ Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -20, 0, 24), Text = flame.Name:upper(), FontFace = TITLE, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = card })
		local action = button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = "", ZIndex = 23, Parent = card }, "Flame")
		action.Activated:Connect(function()
			remotes.Shop:FireServer("BuyFlame", flame.Id)
		end)
		flameCards[flame.Id] = { Card = card, Button = action }
	end
	local paintCards = {}
	for _, paint in Config.Paints do
		local card = panel({ LayoutOrder = paint.Order, BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = garagePaints })
		local swatch = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 56), BackgroundColor3 = paint.Color or THEME.FlameB, BorderSizePixel = 0, ZIndex = 22, Parent = card }, { corner(8) })
		if paint.Accent then
			create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.35, 1), BackgroundColor3 = paint.Accent, BorderSizePixel = 0, ZIndex = 22, Parent = swatch }, { corner(8) })
		else
			text({ Size = UDim2.fromScale(1, 1), Text = "KART COLORS", FontFace = BODYX, TextSize = 14, TextColor3 = THEME.Ink, ZIndex = 23, Parent = swatch })
		end
		text({ Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -20, 0, 24), Text = paint.Name:upper(), FontFace = TITLE, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = card })
		local action = button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = "", ZIndex = 23, Parent = card }, "Flame")
		action.Activated:Connect(function()
			remotes.Shop:FireServer("BuyPaint", paint.Id)
		end)
		paintCards[paint.Id] = { Card = card, Button = action }
	end
	local function refreshGarage()
		local coins = player:GetAttribute("Coins") or 0
		for id, entry in kartCards do
			local kart = Config.KartsById[id]
			local owned = player:GetAttribute("Kart_" .. id)
			local equipped = player:GetAttribute("Kart") == id
			entry.Button.Text = if equipped then "EQUIPPED" elseif owned then "EQUIP" elseif kart.Pass then robux(Config.GamePasses[kart.Pass].PriceHint) else Format.Number(kart.Price) .. " COINS"
			entry.Button.TextColor3 = if not owned and kart.Price > coins and not kart.Pass then Color3.fromRGB(255, 220, 210) else THEME.Ink
			entry.Card.UIStroke.Color = if equipped then THEME.FlameB else Color3.new(1, 1, 1)
			entry.Card.UIStroke.Transparency = if equipped then 0.1 else 0.88
		end
		for id, entry in flameCards do
			local flame = Config.FlamesById[id]
			local owned = player:GetAttribute("Flame_" .. id)
			local equipped = player:GetAttribute("Flame") == id
			entry.Button.Text = if equipped then "EQUIPPED" elseif owned then "EQUIP" elseif flame.Pass then "VIP ONLY" else Format.Number(flame.Price) .. " COINS"
			entry.Button.TextColor3 = THEME.Ink
			entry.Card.UIStroke.Color = if equipped then THEME.FlameB else Color3.new(1, 1, 1)
			entry.Card.UIStroke.Transparency = if equipped then 0.1 else 0.88
		end
		for id, entry in paintCards do
			local paint = Config.PaintsById[id]
			local owned = player:GetAttribute("Paint_" .. id)
			local equipped = (player:GetAttribute("Paint") or "Factory") == id
			entry.Button.Text = if equipped then "EQUIPPED" elseif owned then "EQUIP" else Format.Number(paint.Price) .. " COINS"
			entry.Button.TextColor3 = THEME.Ink
			entry.Card.UIStroke.Color = if equipped then THEME.FlameB else Color3.new(1, 1, 1)
			entry.Card.UIStroke.Transparency = if equipped then 0.1 else 0.88
		end
	end
	garageTabs.Karts.Activated:Connect(refreshGarage)
	player.AttributeChanged:Connect(function(name)
		if name == "Coins" or name == "Kart" or name == "Flame" or name == "Paint" or name:sub(1, 5) == "Kart_" or name:sub(1, 6) == "Flame_" or name:sub(1, 6) == "Paint_" then
			refreshGarage()
		end
	end)
	refreshGarage()

	------------------------------------------------ Shop

	local _, shopBody = window("Shop", "SHOP", 780, 450)
	local shopPasses = scroller(shopBody, 3, 150)
	local shopCoins = scroller(shopBody, 4, 150)
	local shopBoosts = scroller(shopBody, 3, 150)
	local shopLists = { Passes = shopPasses, Coins = shopCoins, Boosts = shopBoosts }
	local function showShopTab(name: string)
		for key, list in shopLists do
			list.Visible = key == name
		end
	end
	tabs(shopBody, { "Passes", "Coins", "Boosts" }, showShopTab)
	showShopTab("Passes")
	local passButtons = {}
	local function shopCard(parent: Instance, order: number, title: string, description: string, price: number, kind: string, key: string): TextButton
		local card = panel({ LayoutOrder = order, BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = parent })
		slash(card, 10, 40).ZIndex = 22
		text({ Position = UDim2.fromOffset(28, 10), Size = UDim2.new(1, -38, 0, 26), Text = title:upper(), FontFace = TITLE, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = card })
		text({ Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 50), Text = description, TextSize = 15, TextColor3 = THEME.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23, Parent = card })
		local b = button({ Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(1, -24, 0, 36), Text = robux(price), FontFace = TITLE, TextSize = 19, ZIndex = 23, Parent = card }, "Robux")
		b.Activated:Connect(function()
			remotes.Purchase:FireServer(kind, key)
		end)
		return b
	end
	for key, pass in Config.GamePasses do
		passButtons[key] = shopCard(shopPasses, pass.Order, pass.Name, pass.Description, pass.PriceHint, "Pass", key)
	end
	for key, product in Config.DevProducts do
		if product.Hidden then
			continue
		end
		local list = if product.Kind == "Coins" then shopCoins else shopBoosts
		shopCard(list, product.Order, product.Name, product.Description, product.PriceHint, "Product", key)
	end
	local starter = Config.DevProducts.StarterPack
	local starterButton = shopCard(shopBoosts, 0, starter.Name, starter.Description, starter.PriceHint, "Product", "StarterPack")
	local function refreshShop()
		for key, b in passButtons do
			local owned = player:GetAttribute("Pass_" .. key)
			b.Text = if owned then "OWNED" else robux(Config.GamePasses[key].PriceHint)
			b.AutoButtonColor = not owned
		end
		starterButton.Parent.Visible = not player:GetAttribute("StarterPack")
	end
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 5) == "Pass_" or name == "StarterPack" then
			refreshShop()
		end
	end)
	refreshShop()

	------------------------------------------------ Strecke frei waehlen

	local _, pickBody = window("PickTrack", "PICK THE NEXT TRACK", 700, 420)
	local pickList = scroller(pickBody, 2, 52)
	pickList.Position = UDim2.fromOffset(16, 14)
	pickList.Size = UDim2.new(1, -32, 1, -26)
	for _, track in Tracks.List do
		local theme = Tracks.Themes[track.Theme]
		local b = button({ LayoutOrder = track.Order, Text = "", ZIndex = 23, Parent = pickList })
		create("Frame", { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = theme.Accent, BorderSizePixel = 0, ZIndex = 23, Parent = b }, { corner(4) })
		text({ Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -110, 1, 0), Text = track.Name:upper(), FontFace = TITLE, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 24, Parent = b })
		text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(90, 30), BackgroundTransparency = 0, BackgroundColor3 = THEME.Gold, Text = robux(Config.DevProducts.ChooseTrack.PriceHint), FontFace = BODYX, TextSize = 15, TextColor3 = THEME.Ink, ZIndex = 24, Parent = b })
		b.Activated:Connect(function()
			remotes.WantTrack:FireServer(track.Id)
			UI.Close()
		end)
	end

	------------------------------------------------ Abstimmung (Lobby)

	local vote = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(660, 190),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = root,
	})
	local voteCards = {}
	for k = 1, Config.VoteChoices do
		local card = create("TextButton", {
			Position = UDim2.fromOffset((k - 1) * 224, 0),
			Size = UDim2.fromOffset(212, 128),
			BackgroundColor3 = THEME.Ink,
			AutoButtonColor = true,
			Text = "",
			ClipsDescendants = true,
			Parent = vote,
		}, { corner(12) })
		local s = create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Transparency = 0.85, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = card })
		local art = create("Frame", { Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = card })
		local artGradient = create("UIGradient", { Rotation = 20, Parent = art })
		local mini = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = art })
		local name = text({ Position = UDim2.fromOffset(10, 74), Size = UDim2.new(1, -20, 0, 26), Text = "", FontFace = TITLE, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		local votes = text({ Position = UDim2.fromOffset(10, 100), Size = UDim2.new(1, -20, 0, 20), Text = "", TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		voteCards[k] = { Button = card, Stroke = s, Gradient = artGradient, Mini = mini, Name = name, Votes = votes, Id = "" }
		card.Activated:Connect(function()
			local id = voteCards[k].Id
			if id ~= "" then
				remotes.Vote:FireServer(id)
				UI.MyVote = id
			end
		end)
	end
	local pickButton = button({ Position = UDim2.fromOffset(0, 140), Size = UDim2.fromOffset(322, 44), Text = "PICK ANY TRACK   " .. robux(Config.DevProducts.ChooseTrack.PriceHint), FontFace = TITLE, TextSize = 18, Parent = vote }, "Robux")
	local startButton = button({ Position = UDim2.fromOffset(338, 140), Size = UDim2.fromOffset(322, 44), Text = "START RACE NOW   " .. robux(Config.DevProducts.StartNow.PriceHint), FontFace = TITLE, TextSize = 18, Parent = vote }, "Flame")
	pickButton.Activated:Connect(function()
		UI.Open("PickTrack")
	end)
	startButton.Activated:Connect(function()
		remotes.Purchase:FireServer("Product", "StartNow")
	end)

	-- Kleine Streckenform als Punkte (fuer Abstimmungskarten und Minimap)
	local function drawTrack(container: Frame, trackId: string, dotSize: number, color: Color3, every: number)
		container:ClearAllChildren()
		local geo = Tracks.Geometry(trackId)
		local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
		for _, p in geo.Points do
			minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
			minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
		end
		local span = math.max(maxX - minX, maxZ - minZ)
		for i = 1, geo.Count, every do
			local p = geo.Points[i]
			create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + (p.X - (minX + maxX) / 2) / span * 0.82, 0.5 + (p.Z - (minZ + maxZ) / 2) / span * 0.82),
				Size = UDim2.fromOffset(dotSize, dotSize),
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Parent = container,
			}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		return function(pos: Vector3): UDim2
			return UDim2.fromScale(0.5 + (pos.X - (minX + maxX) / 2) / span * 0.82, 0.5 + (pos.Z - (minZ + maxZ) / 2) / span * 0.82)
		end
	end

	local function refreshVote()
		local choices = string.split(workspace:GetAttribute("VoteChoices") or "", ",")
		for k, card in voteCards do
			local id = choices[k]
			local track = id and Tracks.ById[id]
			card.Button.Visible = track ~= nil
			if track then
				if card.Id ~= id then
					card.Id = id
					local theme = Tracks.Themes[track.Theme]
					card.Name.Text = track.Name:upper()
					card.Gradient.Color = ColorSequence.new(theme.Accent:Lerp(Color3.new(0, 0, 0), 0.35), (theme.Ground or theme.Road):Lerp(Color3.new(0, 0, 0), 0.5))
					local mini = card.Mini
					mini.Size = UDim2.fromOffset(110, 70)
					mini.Position = UDim2.new(1, -112, 0, 0)
					drawTrack(mini, id, 3, Color3.new(1, 1, 1), 3)
				end
				local count = workspace:GetAttribute("Votes_" .. id) or 0
				card.Votes.Text = `{count} VOTE{if count == 1 then "" else "S"}`
				local mine = UI.MyVote == id
				card.Stroke.Color = if mine then THEME.FlameB else Color3.new(1, 1, 1)
				card.Stroke.Thickness = if mine then 3 else 1
				card.Stroke.Transparency = if mine then 0 else 0.85
			end
		end
	end
	workspace.AttributeChanged:Connect(function(name)
		if name == "VoteChoices" then
			UI.MyVote = nil
			refreshVote()
		elseif name:sub(1, 6) == "Votes_" then
			refreshVote()
		end
	end)

	------------------------------------------------ Renn-HUD

	local hud = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = root })

	-- Boost-Vignette am Bildschirmrand
	local boostEdge = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = THEME.FlameB, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = hud })
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.18, 1),
			NumberSequenceKeypoint.new(0.82, 1),
			NumberSequenceKeypoint.new(1, 0.55),
		}),
		Parent = boostEdge,
	})

	local placeBox = create("Frame", { Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(170, 120), BackgroundTransparency = 1, Parent = hud })
	local placeNum = text({ Size = UDim2.fromOffset(100, 100), Text = "1", FontFace = TITLE, TextSize = 96, TextXAlignment = Enum.TextXAlignment.Left, Parent = placeBox })
	flameGradient(90).Parent = placeNum
	create("UIStroke", { Color = Color3.fromRGB(60, 10, 0), Thickness = 3, Parent = placeNum })
	local placeSuffix = text({ Position = UDim2.fromOffset(64, 16), Size = UDim2.fromOffset(60, 34), Text = "ST", FontFace = TITLE, TextSize = 32, TextXAlignment = Enum.TextXAlignment.Left, Parent = placeBox })
	create("UIStroke", { Color = Color3.fromRGB(60, 10, 0), Thickness = 2, Parent = placeSuffix })
	local placeOf = text({ Position = UDim2.fromOffset(66, 52), Size = UDim2.fromOffset(60, 24), Text = "/ 8", FontFace = TITLE, TextSize = 20, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = placeBox })
	local lapPill = panel({ Position = UDim2.fromOffset(18, 112), Size = UDim2.fromOffset(130, 36), BackgroundColor3 = THEME.Ink, Parent = hud })
	local lapText = text({ Size = UDim2.fromScale(1, 1), Text = "LAP 1/3", FontFace = TITLE, TextSize = 22, Parent = lapPill })
	local respawnButton = button({ Position = UDim2.fromOffset(18, 156), Size = UDim2.fromOffset(130, 30), Text = "RESPAWN (R)", TextSize = 14, Parent = hud })
	respawnButton.Activated:Connect(function()
		controller.Respawn()
	end)

	local timerText = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(240, 40), Text = "0:00.00", FontFace = TITLE, TextSize = 34, Parent = hud })
	create("UIStroke", { Color = THEME.Ink, Thickness = 2.5, Parent = timerText })

	local mapPanel = panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 84), Size = UDim2.fromOffset(180, 180), BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.3, Parent = hud })
	local mapTrack = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = mapPanel })
	local mapDots = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = mapPanel })
	local mapProject: ((Vector3) -> UDim2)? = nil
	local mapTrackId = ""
	local dotPool = {}

	-- Item-Slot unten rechts (antippen = benutzen)
	local itemSlot = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(112, 112),
		BackgroundColor3 = THEME.Ink,
		BackgroundTransparency = 0.15,
		AutoButtonColor = true,
		Text = "",
		Parent = hud,
	}, { corner(16) })
	local itemStroke = create("UIStroke", { Color = THEME.FlameB, Thickness = 3, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = itemSlot })
	local itemGlyph = text({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 62), Text = "", FontFace = TITLE, TextSize = 52, Parent = itemSlot })
	local itemName = text({ Position = UDim2.new(0, 4, 1, -36), Size = UDim2.new(1, -8, 0, 30), Text = "", FontFace = BODYX, TextSize = 13, TextWrapped = true, Parent = itemSlot })
	local itemHint = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(112, 18), Text = if touch then "TAP TO USE" else "[E] USE ITEM", TextSize = 12, TextColor3 = THEME.Muted, Parent = itemSlot })
	local item2Slot = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -138, 1, -18), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.25, Visible = false, Parent = hud }, {
		corner(10),
		create("UIStroke", { Color = THEME.FlameB, Thickness = 2, Transparency = 0.4 }),
	})
	local item2Glyph = text({ Size = UDim2.fromScale(1, 1), Text = "", FontFace = TITLE, TextSize = 26, Parent = item2Slot })
	itemSlot.Activated:Connect(function()
		remotes.UseItem:FireServer()
	end)
	local superButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -158), Size = UDim2.fromOffset(112, 34), Text = "INFERNO x0", FontFace = TITLE, TextSize = 16, Parent = hud }, "Flame")
	superButton.Activated:Connect(function()
		if (player:GetAttribute("SuperItems") or 0) > 0 then
			remotes.UseSuper:FireServer()
		else
			remotes.Purchase:FireServer("Product", "SuperItem")
		end
	end)

	-- Drift-Knopf fuer Handys
	local driftButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -146, 1, -86),
		Size = UDim2.fromOffset(104, 104),
		BackgroundColor3 = THEME.Ink,
		BackgroundTransparency = 0.2,
		Text = "DRIFT",
		FontFace = TITLE,
		TextSize = 22,
		TextColor3 = THEME.Text,
		AutoButtonColor = false,
		Visible = touch,
		Parent = hud,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local driftStroke = create("UIStroke", { Color = THEME.Blue, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = driftButton })
	driftButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			controller.SetDrift(true)
			driftButton.BackgroundTransparency = 0
		end
	end)
	driftButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			controller.SetDrift(false)
			driftButton.BackgroundTransparency = 0.2
		end
	end)
	local hintsLabel = text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(600, 20), Text = "W/S drive  -  A/D steer  -  SPACE drift  -  E item  -  R respawn", TextSize = 14, TextColor3 = THEME.Muted, Visible = not touch, Parent = hud })

	-- Tempo und Drift-Ladung unten links
	local speedPanel = panel({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -18), Size = UDim2.fromOffset(200, 84), BackgroundColor3 = THEME.Ink, BackgroundTransparency = 0.2, Parent = hud })
	local speedText = text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(110, 44), Text = "0", FontFace = TITLE, TextSize = 42, TextXAlignment = Enum.TextXAlignment.Left, Parent = speedPanel })
	text({ Position = UDim2.fromOffset(112, 22), Size = UDim2.fromOffset(60, 20), Text = "KM/H", FontFace = BODYX, TextSize = 13, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = speedPanel })
	local raceCoins = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(60, 20), Text = "0/10", FontFace = TITLE, TextSize = 16, TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Right, Parent = speedPanel })
	local driftBack = create("Frame", { Position = UDim2.fromOffset(12, 56), Size = UDim2.new(1, -24, 0, 12), BackgroundColor3 = THEME.Panel2, BorderSizePixel = 0, Parent = speedPanel }, { corner(6) })
	local driftFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Blue, BorderSizePixel = 0, Parent = driftBack }, { corner(6) })
	for _, need in Config.DriftTiers do
		create("Frame", { Position = UDim2.fromScale(need / Config.DriftTiers[3], 0), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = THEME.Ink, BorderSizePixel = 0, Parent = driftBack })
	end

	-- Countdown und grosse Meldungen in der Mitte
	local bigText = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(700, 140), Text = "", FontFace = TITLE, TextSize = 120, Parent = root })
	local bigGradient = flameGradient(90)
	bigGradient.Parent = bigText
	create("UIStroke", { Color = Color3.fromRGB(50, 8, 0), Thickness = 5, Parent = bigText })
	local bigScale = create("UIScale", { Parent = bigText })
	local function shout(message: string, duration: number?)
		bigText.Text = message
		bigText.TextTransparency = 0
		bigScale.Scale = 1.5
		TweenService:Create(bigScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local token = {}
		UI.ShoutToken = token
		task.delay(duration or 0.9, function()
			if UI.ShoutToken == token then
				TweenService:Create(bigText, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			end
		end)
	end
	local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 50, Parent = gui })

	------------------------------------------------ Ergebnis

	local _, resultsBody = window("Results", "RACE RESULTS", 520, 492)
	local resultsList = create("Frame", { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 300), BackgroundTransparency = 1, ZIndex = 22, Parent = resultsBody }, {
		create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local rewardText = text({ Position = UDim2.fromOffset(16, 312), Size = UDim2.new(1, -32, 0, 34), Text = "", FontFace = TITLE, TextSize = 28, TextColor3 = THEME.Gold, ZIndex = 23, Parent = resultsBody })
	local resultInfo = text({ Position = UDim2.fromOffset(16, 346), Size = UDim2.new(1, -32, 0, 22), Text = "", FontFace = BODYX, TextScaled = true, TextColor3 = THEME.Text, ZIndex = 23, Parent = resultsBody })
	create("UITextSizeConstraint", { MaxTextSize = 16, Parent = resultInfo })
	local doubleButton = button({ Position = UDim2.new(0.5, -150, 0, 378), Size = UDim2.fromOffset(300, 40), Text = "", FontFace = TITLE, TextSize = 18, ZIndex = 23, Parent = resultsBody }, "Robux")
	doubleButton.Activated:Connect(function()
		remotes.Purchase:FireServer("Pass", "DoubleCoins")
	end)
	remotes.Results.OnClientEvent:Connect(function(board, mine)
		for _, child in resultsList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, entry in board do
			local isMe = entry.UserId == player.UserId
			local row = create("Frame", {
				Size = UDim2.new(1, 0, 0, 33),
				BackgroundColor3 = if isMe then Color3.new(1, 1, 1) else THEME.Panel,
				BorderSizePixel = 0,
				LayoutOrder = entry.Place,
				ZIndex = 22,
				Parent = resultsList,
			}, { corner(6) })
			if isMe then
				flameGradient(0).Parent = row
			end
			local color = if isMe then THEME.Ink else THEME.Text
			text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(60, 33), Text = entry.Place .. ordinal(entry.Place), FontFace = TITLE, TextSize = 20, TextColor3 = if entry.Place == 1 and not isMe then THEME.Gold else color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			text({ Position = UDim2.fromOffset(72, 0), Size = UDim2.new(1, -170, 1, 0), Text = entry.Name .. (if entry.Bot then "  (CPU)" else ""), TextSize = 17, FontFace = BODYX, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(90, 33), Text = if entry.Time then Format.Time(entry.Time) else "--", TextSize = 16, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23, Parent = row })
		end
		if mine then
			rewardText.Text = `+{Format.Number(mine.Coins)} COINS` .. (if mine.Multiplier > 1 then `   (x{mine.Multiplier})` else "")
			-- XP, Bestzeit und Siegesserie
			local parts = {}
			if mine.Xp then
				table.insert(parts, `+{mine.Xp} XP`)
			end
			if mine.NewBest and mine.Best then
				table.insert(parts, `NEW PERSONAL BEST {Format.RaceTime(mine.Best)}!`)
			elseif mine.Best then
				table.insert(parts, `BEST {Format.RaceTime(mine.Best)}`)
			end
			if mine.Streak and mine.Streak >= 2 then
				table.insert(parts, `WIN STREAK {mine.Streak}` .. (if mine.StreakBonus then ` (+{mine.StreakBonus})` else ""))
			end
			resultInfo.Text = table.concat(parts, "   -   ")
			resultInfo.TextColor3 = if mine.NewBest then THEME.Green else THEME.Text
		else
			rewardText.Text = "Join the next race!"
			resultInfo.Text = ""
		end
		local hasDouble = player:GetAttribute("Pass_DoubleCoins")
		doubleButton.Visible = mine ~= nil and not hasDouble
		doubleButton.Text = "2x COINS FOREVER   " .. robux(Config.GamePasses.DoubleCoins.PriceHint)
		UI.Open("Results")
	end)

	------------------------------------------------ Angebote

	local offer = panel({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.55, 0),
		Size = UDim2.fromOffset(270, 190),
		BackgroundColor3 = THEME.Ink,
		Visible = false,
		ZIndex = 30,
		ClipsDescendants = true,
		Parent = root,
	})
	slash(offer, 12, 60).ZIndex = 31
	local offerTag = text({ Position = UDim2.fromOffset(30, 8), Size = UDim2.new(1, -40, 0, 18), Text = "SPECIAL OFFER", FontFace = BODYX, TextSize = 13, TextColor3 = THEME.FlameB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = offer })
	local offerTitle = text({ Position = UDim2.fromOffset(30, 26), Size = UDim2.new(1, -40, 0, 30), Text = "", FontFace = TITLE, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 31, Parent = offer })
	local offerText = text({ Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 0, 50), Text = "", TextSize = 15, TextColor3 = THEME.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31, Parent = offer })
	local offerBuy = button({ Position = UDim2.new(0, 14, 1, -76), Size = UDim2.new(1, -28, 0, 38), Text = "", FontFace = TITLE, TextSize = 19, ZIndex = 31, Parent = offer }, "Robux")
	local offerNo = create("TextButton", { Position = UDim2.new(0, 14, 1, -32), Size = UDim2.new(1, -28, 0, 24), BackgroundTransparency = 1, Text = "No thanks", FontFace = BODY, TextSize = 14, TextColor3 = THEME.Muted, ZIndex = 31, Parent = offer })
	local currentOffer: { any }? = nil
	offerBuy.Activated:Connect(function()
		if currentOffer then
			remotes.Purchase:FireServer(currentOffer[1], currentOffer[2])
		end
		offer.Visible = false
	end)
	offerNo.Activated:Connect(function()
		offer.Visible = false
	end)
	remotes.Offer.OnClientEvent:Connect(function(kind, key)
		if kind == "Coins" then
			-- Zu wenig Muenzen: passendes Muenzpaket vorschlagen
			local coins = player:GetAttribute("Coins") or 0
			local need = 0
			local kart = Config.KartsById[key]
			local flame = Config.FlamesById[key]
			local paint = Config.PaintsById[key]
			need = (if kart then kart.Price elseif flame then flame.Price elseif paint then paint.Price else 0) - coins
			local best = "CoinsHuge"
			for _, k in { "CoinsSmall", "CoinsMedium", "CoinsLarge", "CoinsHuge" } do
				if Config.DevProducts[k].Coins >= need then
					best = k
					break
				end
			end
			kind, key = "Product", best
			offerTag.Text = "NEED MORE COINS?"
		else
			offerTag.Text = "SPECIAL OFFER"
		end
		local def = if kind == "Pass" then Config.GamePasses[key] else Config.DevProducts[key]
		if not def then
			return
		end
		currentOffer = { kind, key }
		offerTitle.Text = def.Name:upper()
		offerText.Text = def.Description
		offerBuy.Text = robux(def.PriceHint)
		offer.Visible = true
		offer.Position = UDim2.new(1, 300, 0.55, 0)
		TweenService:Create(offer, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(1, -14, 0.55, 0) }):Play()
		task.delay(14, function()
			if currentOffer and currentOffer[2] == key then
				offer.Visible = false
			end
		end)
	end)

	------------------------------------------------ Taegliche Aufgaben

	local _, questBody = window("Quests", "DAILY QUESTS", 560, 400)
	local questRows = {}
	for i = 1, Progression.QuestsPerDay do
		local row = panel({ Position = UDim2.fromOffset(16, 12 + (i - 1) * 100), Size = UDim2.new(1, -32, 0, 90), BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = questBody })
		local label = text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -190, 0, 26), Text = "", FontFace = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
		create("UITextSizeConstraint", { MaxTextSize = 19, Parent = label })
		local back = create("Frame", { Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -250, 0, 12), BackgroundColor3 = THEME.Panel2, BorderSizePixel = 0, ZIndex = 23, Parent = row }, { corner(6) })
		local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 23, Parent = back }, { corner(6) })
		flameGradient(0).Parent = fill
		local count = text({ Position = UDim2.new(1, -230, 0, 38), Size = UDim2.fromOffset(50, 20), Text = "", FontFace = BODYX, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
		local reward = text({ Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -190, 0, 20), Text = "", TextSize = 14, TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
		local claim = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(160, 44), Text = "", FontFace = TITLE, TextSize = 18, ZIndex = 23, Parent = row }, "Flame")
		claim.Activated:Connect(function()
			remotes.Claim:FireServer("Quest", i)
		end)
		questRows[i] = { Row = row, Label = label, Fill = fill, Count = count, Reward = reward, Claim = claim }
	end
	local questFooter = text({ Position = UDim2.fromOffset(16, 316), Size = UDim2.new(1, -32, 0, 20), Text = "", TextSize = 14, TextColor3 = THEME.Muted, ZIndex = 23, Parent = questBody })
	local function refreshQuests()
		local ok, list = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("Quests") or "[]")
		if not ok or type(list) ~= "table" then
			list = {}
		end
		for i, row in questRows do
			local entry = list[i]
			local quest = entry and Progression.QuestsById[entry.Id]
			row.Row.Visible = quest ~= nil
			if quest then
				local progress = math.min(entry.Progress or 0, quest.Goal)
				local ready = not entry.Claimed and progress >= quest.Goal
				row.Label.Text = quest.Text:upper()
				row.Fill.Size = UDim2.fromScale(math.max(0.02, progress / quest.Goal), 1)
				row.Count.Text = `{progress}/{quest.Goal}`
				row.Reward.Text = `+{Format.Number(quest.Coins)} coins   +{Progression.QuestXp} XP`
				row.Claim.Text = if entry.Claimed then "DONE" elseif ready then "CLAIM!" else "IN PROGRESS"
				row.Claim.AutoButtonColor = ready
				row.Claim.TextColor3 = if ready then THEME.Ink else Color3.fromRGB(110, 60, 40)
			end
		end
	end
	player:GetAttributeChangedSignal("Quests"):Connect(refreshQuests)
	refreshQuests()

	------------------------------------------------ Profil (Statistik, Titel, Bestzeiten)

	local _, profileBody = window("Profile", "PROFILE", 660, 450)
	local profileStats = scroller(profileBody, 3, 64)
	local profileTitles = scroller(profileBody, 1, 58)
	local profileRecords = scroller(profileBody, 2, 44)
	local profileLists = { Stats = profileStats, Titles = profileTitles, Records = profileRecords }
	local function showProfileTab(name: string)
		for key, list in profileLists do
			list.Visible = key == name
		end
	end
	tabs(profileBody, { "Stats", "Titles", "Records" }, showProfileTab)
	showProfileTab("Stats")
	local profileData = nil
	local function clearList(list: Instance)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	local function statCard(order: number, label: string, value: string)
		local card = panel({ LayoutOrder = order, BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = profileStats })
		text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 18), Text = label, TextSize = 13, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = card })
		local v = text({ Position = UDim2.fromOffset(12, 26), Size = UDim2.new(1, -24, 0, 30), Text = value, FontFace = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = card })
		create("UITextSizeConstraint", { MaxTextSize = 24, Parent = v })
	end
	local function renderProfile()
		local data = profileData
		if not data then
			return
		end
		clearList(profileStats)
		local hours = math.floor(data.PlayTime / 3600)
		local minutes = math.floor(data.PlayTime % 3600 / 60)
		local stats = {
			{ "LEVEL", `{data.Level}  ({data.XpInto}/{data.XpNeed} XP)` },
			{ "WINS", Format.Number(data.Wins) },
			{ "RACES", Format.Number(data.Races) },
			{ "PODIUMS", Format.Number(data.Podiums) },
			{ "BEST WIN STREAK", tostring(data.BestStreak) },
			{ "RIVALS BLASTED", Format.Number(data.Hits) },
			{ "TRACK COINS", Format.Number(data.TrackCoins) },
			{ "COINS EARNED", Format.Number(data.TotalCoins) },
			{ "PLAY TIME", `{hours}h {minutes}m` },
		}
		for order, stat in stats do
			statCard(order, stat[1], stat[2])
		end
		clearList(profileTitles)
		local currentTitle = player:GetAttribute("Title") or ""
		for _, achievement in Progression.Achievements do
			local unlocked = data.Achievements[achievement.Id] == true
			local row = panel({ LayoutOrder = achievement.Order, BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = profileTitles })
			text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -170, 0, 26), Text = achievement.Title:upper(), FontFace = TITLE, TextSize = 20, TextColor3 = if unlocked then THEME.Gold else THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			local desc = text({ Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -170, 0, 20), Text = `{achievement.Text}  (+{Format.Number(achievement.Coins)} coins)`, TextScaled = true, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			create("UITextSizeConstraint", { MaxTextSize = 15, Parent = desc })
			local equipped = unlocked and currentTitle == achievement.Title
			local b = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(140, 38), Text = if equipped then "UNEQUIP" elseif unlocked then "EQUIP" else "LOCKED", FontFace = TITLE, TextSize = 17, ZIndex = 23, Parent = row }, if unlocked then "Flame" else "Dark")
			b.Activated:Connect(function()
				if equipped then
					remotes.SetTitle:FireServer("")
				elseif unlocked then
					remotes.SetTitle:FireServer(achievement.Id)
				end
			end)
		end
		clearList(profileRecords)
		for _, track in Tracks.List do
			local best = data.Best[track.Id]
			local row = panel({ LayoutOrder = track.Order, BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = profileRecords })
			create("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = Tracks.Themes[track.Theme].Accent, BorderSizePixel = 0, ZIndex = 23, Parent = row }, { corner(3) })
			local name = text({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -110, 1, 0), Text = track.Name:upper(), FontFace = TITLE, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
			create("UITextSizeConstraint", { MaxTextSize = 17, Parent = name })
			text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(90, 44), Text = if best then Format.RaceTime(best) else "--", FontFace = BODYX, TextSize = 16, TextColor3 = if best then THEME.Green else THEME.Muted, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 23, Parent = row })
		end
	end
	local function loadProfile()
		task.spawn(function()
			local ok, data = pcall(function()
				return remotes:WaitForChild("GetProfile"):InvokeServer()
			end)
			if ok and type(data) == "table" then
				profileData = data
				renderProfile()
			end
		end)
	end
	player:GetAttributeChangedSignal("Title"):Connect(function()
		if openName == "Profile" then
			loadProfile()
		end
	end)

	------------------------------------------------ Einstellungen, Codes, Freunde einladen

	local _, settingsBody = window("Settings", "SETTINGS", 520, 430)
	local toggles = {}
	for i, setting in Progression.Settings do
		local row = panel({ Position = UDim2.fromOffset(16, 12 + (i - 1) * 44), Size = UDim2.new(1, -32, 0, 38), BackgroundColor3 = THEME.Panel, ZIndex = 22, Parent = settingsBody })
		text({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -130, 1, 0), Text = setting.Name, FontFace = BODYX, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = row })
		local b = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(100, 30), Text = "", FontFace = TITLE, TextSize = 16, ZIndex = 23, Parent = row })
		b.Activated:Connect(function()
			remotes.Setting:FireServer(setting.Key, player:GetAttribute("Set_" .. setting.Key) == false)
		end)
		toggles[setting.Key] = b
	end
	local codeBox = create("TextBox", {
		Position = UDim2.fromOffset(16, 240),
		Size = UDim2.new(1, -168, 0, 42),
		BackgroundColor3 = THEME.Panel2,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = "Enter a code",
		PlaceholderColor3 = THEME.Muted,
		Text = "",
		FontFace = BODYX,
		TextSize = 18,
		TextColor3 = THEME.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 23,
		Parent = settingsBody,
	}, { corner(8), create("UIPadding", { PaddingLeft = UDim.new(0, 12) }) })
	local redeem = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 240), Size = UDim2.fromOffset(140, 42), Text = "REDEEM", FontFace = TITLE, TextSize = 18, ZIndex = 23, Parent = settingsBody }, "Flame")
	redeem.Activated:Connect(function()
		local code = codeBox.Text
		if #code > 0 then
			remotes.RedeemCode:FireServer(code:sub(1, 24))
			codeBox.Text = ""
		end
	end)
	local howButton = button({ Position = UDim2.fromOffset(16, 296), Size = UDim2.new(0.5, -22, 0, 44), Text = "HOW TO PLAY", FontFace = TITLE, TextSize = 18, ZIndex = 23, Parent = settingsBody })
	local inviteButton2 = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 296), Size = UDim2.new(0.5, -22, 0, 44), Text = "INVITE FRIENDS", FontFace = TITLE, TextSize = 18, ZIndex = 23, Parent = settingsBody }, "Flame")
	local function refreshSettings()
		for key, b in toggles do
			local on = player:GetAttribute("Set_" .. key) ~= false
			b.Text = if on then "ON" else "OFF"
			b.BackgroundColor3 = if on then THEME.Green else THEME.Panel2
			b.TextColor3 = if on then THEME.Ink else THEME.Text
		end
	end
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 4) == "Set_" then
			refreshSettings()
		end
	end)
	refreshSettings()

	local function inviteFriends()
		task.spawn(function()
			local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
			if ok and can then
				pcall(SocialService.PromptGameInvite, SocialService, player)
			else
				toast("Invites are not available right now.", THEME.Muted)
			end
		end)
	end
	inviteButton2.Activated:Connect(inviteFriends)

	------------------------------------------------ Tutorial ("How to play")

	local _, tutorialBody = window("Tutorial", "HOW TO PLAY", 560, 370)
	local pages = {
		{ "WELCOME, RACER!", "Vote for the next track in the lobby. Up to 8 racers start every race - CPU racers fill the empty spots, so you can always race right away." },
		if touch
			then { "DRIVE", "Steer with the stick on the left - your kart drives by itself. Pull the stick back to brake. Tap the big GAS button when the last red light turns on for a ROCKET START!" }
			else { "DRIVE", "W/S to drive, A/D to steer. Hold W right when the last red light turns on for a ROCKET START! Press R if you get stuck." },
		{ "DRIFT FOR TURBO", `Hold {if touch then "the DRIFT button" else "SPACE"} while turning. Sparks turn blue, orange, then PURPLE. Let go for a big turbo boost!` },
		{ "ITEMS, COINS, QUESTS", `Drive through ? boxes for items and {if touch then "tap the item slot" else "press E"} to use them. Coins on the track make you faster. Finish daily quests and level up for coins and titles!` },
	}
	local page = 1
	local pageTitle = text({ Position = UDim2.fromOffset(24, 14), Size = UDim2.new(1, -48, 0, 34), Text = "", FontFace = TITLE, TextSize = 28, TextColor3 = THEME.FlameB, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 23, Parent = tutorialBody })
	local pageText = text({ Position = UDim2.fromOffset(24, 56), Size = UDim2.new(1, -48, 0, 150), Text = "", TextSize = 19, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 23, Parent = tutorialBody })
	local pageDots = text({ Position = UDim2.fromOffset(24, 212), Size = UDim2.new(1, -48, 0, 20), Text = "", TextSize = 16, TextColor3 = THEME.Muted, ZIndex = 23, Parent = tutorialBody })
	local backButton = button({ Position = UDim2.fromOffset(24, 244), Size = UDim2.fromOffset(150, 46), Text = "BACK", FontFace = TITLE, TextSize = 19, ZIndex = 23, Parent = tutorialBody })
	local nextButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 244), Size = UDim2.fromOffset(260, 46), Text = "NEXT", FontFace = TITLE, TextSize = 19, ZIndex = 23, Parent = tutorialBody }, "Flame")
	local function showPage(n: number)
		page = math.clamp(n, 1, #pages)
		pageTitle.Text = pages[page][1]
		pageText.Text = pages[page][2]
		local dots = {}
		for k = 1, #pages do
			table.insert(dots, if k == page then "●" else "○")
		end
		pageDots.Text = table.concat(dots, "  ")
		backButton.Visible = page > 1
		nextButton.Text = if page < #pages then "NEXT" elseif player:GetAttribute("TutorialDone") then "LET'S RACE!" else `LET'S RACE! +{Progression.TutorialCoins}`
	end
	backButton.Activated:Connect(function()
		showPage(page - 1)
	end)
	nextButton.Activated:Connect(function()
		if page < #pages then
			showPage(page + 1)
		else
			if not player:GetAttribute("TutorialDone") then
				remotes.Claim:FireServer("Tutorial")
			end
			UI.Close()
		end
	end)
	local function openTutorial()
		showPage(1)
		UI.Open("Tutorial")
	end
	howButton.Activated:Connect(openTutorial)
	-- Beim ersten Besuch automatisch zeigen (nicht mitten im Rennen)
	task.spawn(function()
		while not player:GetAttribute("Loaded") do
			task.wait(0.5)
		end
		task.wait(2)
		if player:GetAttribute("TutorialDone") == false and openName == nil and player:GetAttribute("Racing") ~= true then
			openTutorial()
		end
	end)

	------------------------------------------------ Renn-Extras: GAS-Knopf (Handy), falsche Richtung, Rundenzeiten

	local gasButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -30, 0.58, 0),
		Size = UDim2.fromOffset(136, 136),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Text = "GAS!",
		FontFace = TITLE,
		TextSize = 34,
		TextColor3 = THEME.Ink,
		AutoButtonColor = true,
		Visible = false,
		Parent = hud,
	}, { create("UICorner", { CornerRadius = UDim.new(1, 0) }), flameGradient(90) })
	local gasUsed = false
	gasButton.Activated:Connect(function()
		controller.TapGas()
		gasUsed = true
	end)
	local wrongWay = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(500, 64), Text = "WRONG WAY!", FontFace = TITLE, TextSize = 52, TextColor3 = THEME.Red, Visible = false, Parent = hud })
	create("UIStroke", { Color = THEME.Ink, Thickness = 3, Parent = wrongWay })
	local lastLap = 1
	local lapStartAt = 0
	player:GetAttributeChangedSignal("Lap"):Connect(function()
		local lap = player:GetAttribute("Lap") or 1
		local phase = workspace:GetAttribute("Phase")
		if phase == "Race" and player:GetAttribute("Racing") == true and lap > lastLap then
			local t = workspace:GetServerTimeNow()
			local start = math.max(lapStartAt, workspace:GetAttribute("RaceStart") or t)
			toast(`LAP {lastLap}  -  {Format.RaceTime(t - start)}`, THEME.Blue)
			lapStartAt = t
			if lap == Config.Laps then
				shout("FINAL LAP!", 1.4)
				sfx("Go")
			end
		end
		lastLap = lap
	end)
	workspace:GetAttributeChangedSignal("RaceStart"):Connect(function()
		lastLap = 1
		lapStartAt = workspace:GetAttribute("RaceStart") or 0
	end)
	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		if workspace:GetAttribute("Phase") == "Countdown" then
			gasUsed = false
		end
	end)

	------------------------------------------------ Menue-Aktionen

	garageButton.Activated:Connect(function()
		refreshGarage()
		UI.Open("Garage")
	end)
	shopButton.Activated:Connect(function()
		showShopTab("Passes")
		UI.Open("Shop")
	end)
	coinPlus.Activated:Connect(function()
		showShopTab("Coins")
		UI.Open("Shop")
	end)
	dailyButton.Activated:Connect(function()
		if player:GetAttribute("DailyReady") then
			remotes.Claim:FireServer("Daily")
		else
			toast("Come back tomorrow for your next daily reward!", THEME.Muted)
		end
	end)
	giftButton.Activated:Connect(function()
		remotes.Claim:FireServer("Gift")
	end)
	questButton.Activated:Connect(function()
		refreshQuests()
		UI.Open("Quests")
	end)
	profileButton.Activated:Connect(function()
		showProfileTab("Stats")
		loadProfile()
		UI.Open("Profile")
	end)
	settingsButton.Activated:Connect(function()
		refreshSettings()
		UI.Open("Settings")
	end)
	inviteButton.Activated:Connect(inviteFriends)
	adButton.Activated:Connect(function()
		adButton.Visible = false
		remotes.WatchAd:FireServer()
	end)
	spectateButton.Activated:Connect(function()
		controller.Spectate = not controller.Spectate
		spectateLabel.Text = if controller.Spectate then "STOP" else "WATCH"
	end)
	task.spawn(function()
		while gui.Parent do
			local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			adButton.Visible = ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
			task.wait(30)
		end
	end)

	------------------------------------------------ Events vom Kart-Controller

	controller.OnEvent = function(name, value)
		if name == "Rocket" then
			shout("ROCKET START!", 1)
			sfx("Boost")
		elseif name == "Boost" or name == "Inferno" then
			sfx("Boost")
		elseif name == "Early" then
			shout("TOO EARLY!", 0.8)
		elseif name == "LevelUp" then
			shout(`LEVEL {value}!`, 1.6)
			sfx("Win")
		elseif name == "Achievement" then
			sfx("Win")
		elseif name == "Quest" then
			sfx("Quest")
		elseif name == "Spin" then
			sfx("Hit")
			flash.BackgroundColor3 = THEME.Red
			flash.BackgroundTransparency = 0.6
			TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		elseif name == "Flash" then
			sfx("Hit")
			flash.BackgroundColor3 = Color3.fromRGB(255, 250, 200)
			flash.BackgroundTransparency = 0.2
			TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		elseif name == "Finish" then
			shout(`{value}{ordinal(value)} PLACE!`, 3)
			sfx(if value <= 3 then "Win" else "Go")
		elseif name == "DriftTier" and value > 0 then
			driftStroke.Color = Config.DriftColors[value]
			sfx("Item")
		elseif name == "Respawn" then
			flash.BackgroundColor3 = Color3.new(0, 0, 0)
			flash.BackgroundTransparency = 0.2
			TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		end
	end

	------------------------------------------------ Laufende Aktualisierung

	local lastCount = -1
	local rolling = 0
	local lastItem: string? = nil
	local lastRaceCoins = 0
	local glyphs = {}
	for key in Config.Items do
		table.insert(glyphs, key)
	end
	local function showItem(slotGlyph: TextLabel, key: string?)
		local def = key and Config.Items[key]
		slotGlyph.Text = if def then def.Glyph else ""
		slotGlyph.TextColor3 = if def then def.Color else THEME.Text
	end
	player.AttributeChanged:Connect(function(name)
		if name == "Item" then
			local item = player:GetAttribute("Item")
			if item and not lastItem then
				rolling = 1 -- kurze Roulette-Animation beim Einsammeln
				sfx("Item")
			end
			lastItem = item
		elseif name == "RaceCoins" then
			local value = player:GetAttribute("RaceCoins") or 0
			if value > lastRaceCoins and player:GetAttribute("Racing") == true then
				sfx("Coin")
			end
			lastRaceCoins = value
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = workspace:GetServerTimeNow()
		local phase = workspace:GetAttribute("Phase") or "Intermission"
		local phaseEnd = workspace:GetAttribute("PhaseEnd") or t
		local remaining = math.max(0, phaseEnd - t)
		local racing = player:GetAttribute("Racing") == true and (phase == "Countdown" or phase == "Race")

		-- Muenzen
		local coins = player:GetAttribute("Coins") or 0
		if coins ~= lastCount then
			lastCount = coins
			coinText.Text = Format.Number(coins)
		end
		local level, into, need = Progression.LevelFromXp(player:GetAttribute("XP") or 0)
		winsText.Text = `LV {level}   -   {player:GetAttribute("Wins") or 0} WINS`
		xpFill.Size = UDim2.fromScale(math.clamp(into / need, 0, 1), 1)
		local party = (workspace:GetAttribute("CoinPartyUntil") or 0) - t
		if party > 0 then
			winsText.Text ..= `   -   COIN PARTY 2x {Format.Time(party)}`
			winsText.TextColor3 = THEME.Gold
		else
			winsText.TextColor3 = THEME.Muted
		end

		-- Menue und Abstimmung nur in der Lobby
		menu.Visible = not racing
		spectateButton.Visible = phase == "Race" and not racing
		vote.Visible = phase == "Intermission" and openName == nil
		hud.Visible = racing
		dailyBadge.Visible = player:GetAttribute("DailyReady") == true
		local questsReady = player:GetAttribute("QuestsReady") or 0
		questBadge.Visible = questsReady > 0
		questBadge.Text = tostring(questsReady)
		xpBack.Visible = not racing
		if openName == "Quests" then
			local left = 86400 - (os.time() % 86400)
			questFooter.Text = string.format("New quests in %d:%02d:%02d", left // 3600, left % 3600 // 60, left % 60)
		end
		local giftLeft = (player:GetAttribute("GiftAt") or t) - t
		giftBadge.Visible = giftLeft <= 0
		giftLabel.Text = if giftLeft > 0 then Format.Time(giftLeft) else "CLAIM!"
		dailyLabel.Text = if player:GetAttribute("DailyReady") then "CLAIM!" else "DAILY"
		if phase ~= "Race" and controller.Spectate then
			controller.Spectate = false
			spectateLabel.Text = "WATCH"
		end

		-- Banner
		local trackDef = Tracks.ById[workspace:GetAttribute("TrackId") or ""]
		banner.Visible = not racing or phase == "Countdown"
		if phase == "Intermission" then
			bannerTitle.Text = "VOTE FOR THE NEXT TRACK"
			bannerMain.Text = Format.Time(remaining)
		elseif phase == "Countdown" then
			bannerTitle.Text = "GET READY"
			bannerMain.Text = if trackDef then trackDef.Name:upper() else ""
		elseif phase == "Race" then
			bannerTitle.Text = if trackDef then trackDef.Name:upper() .. "  -  RACE IN PROGRESS" else "RACE IN PROGRESS"
			bannerMain.Text = if racing then "" else "NEXT RACE SOON"
		else
			bannerTitle.Text = "RACE FINISHED"
			bannerMain.Text = "NEXT VOTE IN " .. math.ceil(remaining)
		end

		-- Countdown
		if phase == "Countdown" and racing then
			local n = math.ceil(remaining / (Config.CountdownTime / 4)) - 1
			if n ~= UI.LastCount and n >= 1 and n <= 3 then
				UI.LastCount = n
				shout(tostring(n), 0.7)
				sfx("Beep")
			end
		elseif phase == "Race" and UI.LastCount ~= 0 and racing then
			UI.LastCount = 0
			shout("GO!", 0.8)
			sfx("Go")
		elseif phase ~= "Countdown" and phase ~= "Race" then
			UI.LastCount = nil
		end

		gasButton.Visible = touch and racing and phase == "Countdown" and not gasUsed
		if not racing then
			return
		end
		wrongWay.Visible = controller.WrongWay and math.floor(t * 4) % 2 == 0
		local showHints = player:GetAttribute("Set_Hints") ~= false
		hintsLabel.Visible = showHints and not touch
		mapPanel.Visible = player:GetAttribute("Set_Minimap") ~= false

		-- Platz, Runde, Zeit
		local place = player:GetAttribute("RacePlace") or 1
		placeNum.Text = tostring(place)
		placeSuffix.Text = ordinal(place)
		placeSuffix.Position = UDim2.fromOffset(if place >= 10 then 110 else 62, 16)
		placeOf.Text = "/ " .. Config.MaxRacers
		lapText.Text = `LAP {player:GetAttribute("Lap") or 1}/{Config.Laps}`
		local raceStart = workspace:GetAttribute("RaceStart") or t
		local elapsed = if phase == "Race" then t - raceStart else 0
		timerText.Text = string.format("%d:%05.2f", elapsed // 60, elapsed % 60)

		-- Tempo, Drift, Muenzen
		speedText.Text = tostring(math.floor(math.abs(controller.Speed) * 1.7))
		local charge = math.clamp(controller.DriftCharge / Config.DriftTiers[3], 0, 1)
		driftFill.Size = UDim2.fromScale(charge, 1)
		driftFill.BackgroundColor3 = if controller.DriftTier > 0 then Config.DriftColors[controller.DriftTier] else THEME.Muted
		raceCoins.Text = `{player:GetAttribute("RaceCoins") or 0}/{Config.MaxRaceCoins}`
		boostEdge.BackgroundTransparency = if controller.BoostTime > 0 then 0.35 + math.sin(t * 20) * 0.1 else 1
		if not controller.Drifting then
			driftStroke.Color = THEME.Blue
		end

		-- Items
		if rolling > 0 then
			rolling -= dt
			local key = glyphs[math.floor(t * 14) % #glyphs + 1]
			showItem(itemGlyph, key)
			itemName.Text = "..."
		else
			local item = player:GetAttribute("Item")
			showItem(itemGlyph, item)
			itemName.Text = if item then Config.Items[item].Name:upper() else "NO ITEM"
			itemStroke.Color = if item then Config.Items[item].Color else THEME.Panel2
		end
		item2Slot.Visible = player:GetAttribute("Pass_DoubleItems") == true
		showItem(item2Glyph, player:GetAttribute("Item2"))
		itemHint.Visible = showHints and player:GetAttribute("Item") ~= nil
		local supers = player:GetAttribute("SuperItems") or 0
		superButton.Text = if supers > 0 then `INFERNO x{supers}` else "INFERNO " .. robux(Config.DevProducts.SuperItem.PriceHint)

		-- Minimap
		local trackId = workspace:GetAttribute("TrackId") or ""
		if trackId ~= mapTrackId and Tracks.ById[trackId] then
			mapTrackId = trackId
			mapProject = drawTrack(mapTrack, trackId, 4, Color3.fromRGB(200, 190, 215), 2)
		end
		local folder = workspace:FindFirstChild("Karts")
		if folder and mapProject then
			local used = 0
			for _, model in folder:GetChildren() do
				local primary = model:IsA("Model") and model.PrimaryPart
				if primary then
					used += 1
					local dot = dotPool[used]
					if not dot then
						dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Parent = mapDots }, {
							create("UICorner", { CornerRadius = UDim.new(1, 0) }),
							create("UIStroke", { Color = THEME.Ink, Thickness = 1.5 }),
						})
						dotPool[used] = dot
					end
					local me = model:GetAttribute("Driver") == player.UserId
					dot.Visible = true
					dot.Size = UDim2.fromOffset(if me then 13 else 9, if me then 13 else 9)
					dot.ZIndex = if me then 3 else 2
					dot.BackgroundColor3 = if me then THEME.FlameB elseif model:GetAttribute("IsBot") then Color3.fromRGB(190, 185, 200) else THEME.Blue
					dot.Position = mapProject(primary.Position)
				end
			end
			for i = used + 1, #dotPool do
				dotPool[i].Visible = false
			end
		end
	end)

	-- Ergebnisfenster schliesst sich beim naechsten Rennen
	workspace:GetAttributeChangedSignal("Phase"):Connect(function()
		if workspace:GetAttribute("Phase") ~= "Results" and openName == "Results" then
			UI.Close()
		end
		if workspace:GetAttribute("Phase") == "Countdown" and openName ~= nil then
			UI.Close()
		end
	end)
	refreshVote()
	GuiService.TouchControlsEnabled = true
end

return UI
