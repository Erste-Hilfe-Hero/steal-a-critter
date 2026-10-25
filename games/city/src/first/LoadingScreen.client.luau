-- Eigener Ladebildschirm im Turbo-City-Stil: Sonnenuntergang, Skyline, fahrendes Auto als Fortschritt.
-- >>> LoadingKit
-- Gemeinsamer Kern aller Ladebildschirme: das echte 3D-Spielbild als Vollbild mit Kamerafahrt,
-- Icon-Karte, Fortschritt, Tipps, SKIP-Knopf, sauberes Ausblenden und 15-s-Notbremse.
-- Solange das Bild laedt (oder falls es fehlt), zeigt das Spiel seine eigene gezeichnete Szene.
-- Nicht im Spiel aendern! Quelle: tools/loading/LoadingKit.luau, verteilen mit: python3 tools/loading/sync.py
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local Kit = {}
Kit.__index = Kit

local MAX_TIME = 15 -- Notbremse: spaetestens dann ist der Bildschirm weg
local STROKE_REFERENCE = 720 -- Bildschirmhoehe, fuer die die Konturstaerken gedacht sind
local IMAGE_WAIT = 4 -- so lange darf das 3D-Bild zum Laden brauchen

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function asFont(font: any): Font
	return if typeof(font) == "EnumItem" then Font.fromEnum(font :: any) else font
end

local function shuffled(list: { string }): { string }
	local copy = table.clone(list)
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function assetId(id: any): string?
	if id == nil or id == "" or id == 0 then
		return nil
	end
	return "rbxassetid://" .. tostring(id)
end

function Kit.new(theme: { [string]: any })
	local self = setmetatable({}, Kit)
	self.Theme = theme
	self.Start = os.clock()
	self.Progress = 0
	self.Shown = 0
	self.Done = false
	self.Skipped = false
	self.Fading = false
	self.ArtHidden = false
	self.Animations = {}
	self.Logos = {}
	self.Shines = {}
	local images = theme.Images or {}
	self.Cinema = assetId(images.left) ~= nil and assetId(images.right) ~= nil

	local gui = make("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100 })
	if theme.ZIndexBehavior then
		gui.ZIndexBehavior = theme.ZIndexBehavior
	end
	self.Gui = gui
	-- Ebenen: Hintergrund (eigene Szene des Spiels) < 3D-Bild < Bedienelemente
	self.Background = make("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Background or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	-- Die Buehne bleibt 16:9 und sieht damit auf Handy, Tablet und PC gleich aus
	self.Stage = make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, self.Background)
	make("UIAspectRatioConstraint", { AspectRatio = 16 / 9 }, self.Stage)
	self.Hud = make("Frame", {
		Name = "Hud",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 30,
	}, self.Background)
	make("UIAspectRatioConstraint", { AspectRatio = 16 / 9 }, self.Hud)
	if self.Cinema then
		self:_buildBackdrop(images)
	end

	-- Notbremse, auch falls im Spielcode etwas schiefgeht
	task.delay(MAX_TIME + 2, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	return self
end

-- Das 3D-Vorschaubild fuellt den Bildschirm (wie "cover"), zwei Haelften fuer volle Schaerfe
function Kit:_buildBackdrop(images: { [string]: any })
	local theme = self.Theme
	local backdrop = make("Frame", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 15,
	}, self.Background)
	local picture = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 15,
	}, backdrop)
	local zoom = make("UIScale", { Scale = 1.04 }, picture)
	local function cover()
		local size = self.Background.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local width = math.max(size.X, size.Y * 16 / 9)
		picture.Size = UDim2.fromOffset(width, width * 9 / 16)
	end
	cover()
	self.Background:GetPropertyChangedSignal("AbsoluteSize"):Connect(cover)
	local halves = {}
	for i, key in { "left", "right" } do
		halves[i] = make("ImageLabel", {
			Position = UDim2.fromScale((i - 1) * 0.5, 0),
			-- 1 Pixel Ueberlappung, damit keine Naht sichtbar ist
			Size = UDim2.new(0.5, 1, 1, 0),
			BackgroundTransparency = 1,
			Image = assetId(images[key]) :: string,
			ImageTransparency = 1,
			ScaleType = Enum.ScaleType.Stretch,
			ZIndex = 15,
		}, picture)
	end

	-- Glanz, der ab und zu schraeg ueber das Bild zieht
	local sheen = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 16 }, picture)
	local sheenGradient = make("UIGradient", {
		Rotation = 25,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 1),
			NumberSequenceKeypoint.new(0.5, 0.82),
			NumberSequenceKeypoint.new(0.55, 1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Offset = Vector2.new(-1, 0),
	}, sheen)

	-- Kino-Abdunklung: unten kraeftig (fuer Tipp und Balken), oben leicht, Raender weich
	local shades = {}
	local function shade(rotation: number, keypoints: { NumberSequenceKeypoint }, color: Color3?)
		local frame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color or Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 17 }, backdrop)
		make("UIGradient", { Rotation = rotation, Transparency = NumberSequence.new(keypoints) }, frame)
		table.insert(shades, frame)
	end
	shade(90, { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(0.78, 0.45), NumberSequenceKeypoint.new(1, 0.1) })
	shade(90, { NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.18, 1), NumberSequenceKeypoint.new(1, 1) })
	shade(0, { NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.15, 1), NumberSequenceKeypoint.new(0.85, 1), NumberSequenceKeypoint.new(1, 0.55) })
	shade(90, { NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 1), NumberSequenceKeypoint.new(1, 0.75) }, theme.Accent)

	-- Leuchtende Funken, die langsam aufsteigen
	local motes = {}
	for i = 1, 16 do
		local mote = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(0.004 + (i % 3) * 0.002, 0.004 + (i % 3) * 0.002),
			BackgroundColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else (theme.Accent or Color3.new(1, 1, 1)),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 18,
		}, backdrop)
		make("UIAspectRatioConstraint", {}, mote)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, mote)
		motes[i] = { Frame = mote, X = math.random(), Speed = 0.03 + math.random() * 0.04, Phase = math.random() }
	end

	self.Backdrop = {
		Frame = backdrop,
		Halves = halves,
		Zoom = zoom,
		Picture = picture,
		SheenGradient = sheenGradient,
		Shades = shades,
		Motes = motes,
		Shown = false,
		Visible = 0,
	}
end

-- Jede Frame-Animation bekommt (Zeit, dt, angezeigter Fortschritt 0..1)
function Kit:Animate(callback: (number, number, number) -> ())
	table.insert(self.Animations, callback)
end

-- Logo der gezeichneten Szene: springt beim Start auf (Back-Easing), Texte bekommen einen Glanzstreifen
function Kit:Logo(root: GuiObject, shine: { TextLabel }?)
	local scale = root:FindFirstChildOfClass("UIScale") or make("UIScale", {}, root)
	scale.Scale = 0
	table.insert(self.Logos, scale)
	local labels: { TextLabel } = shine or {}
	for _, label in labels do
		local gloss = make("TextLabel", {
			Name = "Shine",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = label.Text,
			FontFace = label.FontFace,
			TextScaled = label.TextScaled,
			TextSize = label.TextSize,
			TextWrapped = label.TextWrapped,
			TextXAlignment = label.TextXAlignment,
			TextYAlignment = label.TextYAlignment,
			TextColor3 = Color3.new(1, 1, 1),
			ZIndex = label.ZIndex + 1,
		}, label)
		local gradient = make("UIGradient", {
			Rotation = 20,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.42, 1),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(0.58, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Offset = Vector2.new(-1, 0),
		}, gloss)
		table.insert(self.Shines, { Label = label, Gloss = gloss, Gradient = gradient })
	end
end

function Kit:_buildUi()
	local theme = self.Theme
	local ink = theme.Ink or Color3.fromRGB(20, 16, 32)
	local accent = theme.Accent or Color3.fromRGB(255, 220, 70)
	local body = asFont(theme.BodyFont or Enum.Font.GothamBold)
	local heavy = asFont(theme.TitleFont or Enum.Font.GothamBlack)
	local hud = self.Hud
	local cinema = self.Cinema
	local icon = cinema and assetId((theme.Images or {}).icon)
	-- Kino-Layout: alles unten, links die Icon-Karte; sonst mittig unter der gezeichneten Szene
	local left = if icon then 0.205 else 0.5 - 0.37
	local width = if cinema then 0.955 - 0.125 - left else 0.74
	local tipY = if cinema then 0.795 else (theme.TipY or 0.765)
	local barY = if cinema then 0.885 else (theme.BarY or 0.865)
	self.Layout = { Left = left, Width = width, TipY = tipY, BarY = barY }

	local iconCard
	if icon then
		iconCard = make("ImageLabel", {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.105, 0.845),
			Size = UDim2.fromScale(0.2, 0.2),
			BackgroundColor3 = ink,
			BackgroundTransparency = 1,
			Image = icon,
			ImageTransparency = 1,
			ZIndex = 31,
		}, hud)
		make("UIAspectRatioConstraint", {}, iconCard)
		make("UICorner", { CornerRadius = UDim.new(0.2, 0) }, iconCard)
		make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, iconCard)
		make("UIScale", { Scale = 0.6 }, iconCard)
	end

	-- Tipp-Karte (antippen = naechster Tipp)
	local card = make("TextButton", {
		Name = "TipCard",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(left, tipY + 0.02),
		Size = UDim2.fromScale(width, 0.085),
		BackgroundColor3 = theme.Panel or ink,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 31,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, card)
	local cardStroke = make("UIStroke", { Color = accent, Thickness = 2, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	local chip = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.014, 0.5),
		Size = UDim2.fromScale(0.095, 0.64),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		Text = "TIP",
		FontFace = heavy,
		TextScaled = true,
		TextColor3 = theme.AccentText or ink,
		TextTransparency = 1,
		ZIndex = 32,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0.35, 0) }, chip)
	make("UIPadding", { PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0) }, chip)
	make("UISizeConstraint", { MaxSize = Vector2.new(90, math.huge) }, chip)
	local tip = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.125, 0.5),
		Size = UDim2.fromScale(0.86, 0.8),
		BackgroundTransparency = 1,
		FontFace = body,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = theme.Text or Color3.new(1, 1, 1),
		TextTransparency = 1,
		Text = "",
		ZIndex = 32,
	}, card)
	make("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 9 }, tip)

	-- Fortschrittsbalken mit Lauflicht und Leuchtspitze, darunter Status links und Prozent rechts
	local barBack = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(left, barY + 0.02),
		Size = UDim2.fromScale(width, if cinema then 0.02 else 0.024),
		BackgroundColor3 = theme.BarBack or ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = cinema or theme.ShowBar ~= false,
		ZIndex = 31,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, barBack)
	local barStroke = make("UIStroke", { Color = theme.BarStroke or ink, Thickness = 2, Transparency = 1 }, barBack)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 32 }, barBack)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	make("UIGradient", { Color = theme.Bar or ColorSequence.new(accent) }, fill)
	local glint = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(0.35, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 33 }, fill)
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }),
	}, glint)
	local spark = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromScale(2.2, 2.2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 34,
	}, barBack)
	make("UIAspectRatioConstraint", {}, spark)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, spark)
	make("UIStroke", { Color = accent, Thickness = 3, Transparency = 1 }, spark)

	local row = make("Frame", {
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromScale(left, barY + 0.025),
		Size = UDim2.fromScale(width, 0.042),
		BackgroundTransparency = 1,
		ZIndex = 31,
	}, hud)
	local statusColor = if cinema then Color3.fromRGB(235, 235, 245) else (theme.StatusColor or theme.Text or Color3.new(1, 1, 1))
	local status = make("TextLabel", {
		Size = UDim2.fromScale(0.8, 1),
		BackgroundTransparency = 1,
		FontFace = body,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = statusColor,
		TextTransparency = 1,
		Text = "",
		ZIndex = 32,
	}, row)
	make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 8 }, status)
	local percent = make("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.2, 1),
		BackgroundTransparency = 1,
		FontFace = heavy,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if cinema then accent else statusColor,
		TextTransparency = 1,
		Text = "0%",
		ZIndex = 32,
	}, row)
	make("UITextSizeConstraint", { MaxTextSize = 26, MinTextSize = 8 }, percent)
	for _, label in { status, percent } do
		make("UIStroke", { Color = ink, Thickness = 1.5, Transparency = 1 }, label)
	end

	-- SKIP unten rechts (Daumen-Reichweite, gross genug zum Tippen)
	local skip = make("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.975, if cinema then 0.955 else 0.965),
		Size = UDim2.fromScale(if cinema then 0.1 else 0.105, 0.072),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		AutoButtonColor = true,
		FontFace = heavy,
		Text = "SKIP  »",
		TextScaled = true,
		TextColor3 = theme.AccentText or ink,
		TextTransparency = 1,
		Visible = false,
		ZIndex = 35,
	}, hud)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, skip)
	make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0), PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0) }, skip)
	make("UISizeConstraint", { MinSize = Vector2.new(84, 38) }, skip)
	local skipStroke = make("UIStroke", { Color = ink, Thickness = 2.5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skip)

	self.Ui = {
		Icon = iconCard,
		Card = card,
		CardStroke = cardStroke,
		Chip = chip,
		Tip = tip,
		BarBack = barBack,
		BarStroke = barStroke,
		Fill = fill,
		Glint = glint,
		Spark = spark,
		Status = status,
		Percent = percent,
		Skip = skip,
		SkipStroke = skipStroke,
	}
end

-- Konturen wachsen mit der Bildschirmhoehe: auf dem Handy duenn und scharf, am PC kraeftig
function Kit:_scaleStrokes()
	local strokes = {}
	for _, item in self.Gui:GetDescendants() do
		if item:IsA("UIStroke") then
			table.insert(strokes, { Stroke = item, Base = item.Thickness })
		end
	end
	local function update()
		local factor = math.clamp(self.Stage.AbsoluteSize.Y / STROKE_REFERENCE, 0.5, 2)
		for _, entry in strokes do
			entry.Stroke.Thickness = math.max(1, entry.Base * factor)
		end
	end
	update()
	self.Stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
end

function Kit:_showUi()
	local ui = self.Ui
	local theme = self.Theme
	local layout = self.Layout
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(ui.Card, info, { Position = UDim2.fromScale(layout.Left, layout.TipY), BackgroundTransparency = if self.Cinema then 0.3 else (theme.PanelTransparency or 0.35) }):Play()
	TweenService:Create(ui.CardStroke, info, { Transparency = 0.55 }):Play()
	TweenService:Create(ui.Chip, info, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
	TweenService:Create(ui.Tip, info, { TextTransparency = 0 }):Play()
	TweenService:Create(ui.BarBack, info, { Position = UDim2.fromScale(layout.Left, layout.BarY), BackgroundTransparency = if self.Cinema then 0.35 else (theme.BarBackTransparency or 0.15) }):Play()
	TweenService:Create(ui.BarStroke, info, { Transparency = if self.Cinema then 0.7 else 0.4 }):Play()
	TweenService:Create(ui.Fill, info, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(ui.Glint, info, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(ui.Spark, info, { BackgroundTransparency = 0.1 }):Play()
	TweenService:Create(ui.Spark:FindFirstChildOfClass("UIStroke"), info, { Transparency = 0.3 }):Play()
	for _, label in { ui.Status, ui.Percent } do
		TweenService:Create(label, info, { TextTransparency = 0 }):Play()
		TweenService:Create(label:FindFirstChildOfClass("UIStroke"), info, { Transparency = 0.5 }):Play()
	end
	if ui.Icon then
		local pop = TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(ui.Icon, info, { ImageTransparency = 0, BackgroundTransparency = 0 }):Play()
		TweenService:Create(ui.Icon:FindFirstChildOfClass("UIScale"), pop, { Scale = 1 }):Play()
		TweenService:Create(ui.Icon:FindFirstChildOfClass("UIStroke"), info, { Transparency = 0.25 }):Play()
	end
end

-- 3D-Bild einblenden, sobald es geladen ist; danach ruht die gezeichnete Szene darunter
function Kit:_showBackdrop()
	local backdrop = self.Backdrop
	if not backdrop then
		return
	end
	local halves = backdrop.Halves
	local icon = self.Ui.Icon
	task.spawn(function()
		local content = { halves[1], halves[2] }
		if icon then
			table.insert(content, icon)
		end
		local ready = false
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, content)
			ready = true
		end)
		local waitUntil = os.clock() + IMAGE_WAIT
		while not (ready and halves[1].IsLoaded and halves[2].IsLoaded) and os.clock() < waitUntil and not self.Fading do
			task.wait(0.05)
		end
		if self.Fading or not (halves[1].IsLoaded and halves[2].IsLoaded) then
			return
		end
		backdrop.Shown = true
		backdrop.ShownAt = os.clock()
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		for _, half in halves do
			TweenService:Create(half, info, { ImageTransparency = 0 }):Play()
		end
		TweenService:Create(backdrop.Frame, info, { BackgroundTransparency = 0 }):Play()
		for _, frame in backdrop.Shades do
			TweenService:Create(frame, info, { BackgroundTransparency = 0 }):Play()
		end
		task.delay(0.65, function()
			if not self.Fading then
				self.ArtHidden = true
			end
		end)
	end)
end

function Kit:_runTips()
	local ui = self.Ui
	local tips = self.Theme.Tips or {}
	if #tips == 0 then
		ui.Card.Visible = false
		return
	end
	local deck, index = shuffled(tips), 1
	ui.Tip.Text = deck[1]
	local busy = false
	local nextAt = os.clock() + 4.5
	local function nextTip()
		if busy or self.Done then
			return
		end
		busy = true
		index = index % #deck + 1
		local out = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(ui.Tip, out, { TextTransparency = 1, Position = UDim2.fromScale(0.105, 0.5) }):Play()
		task.wait(0.19)
		if self.Done then
			return
		end
		ui.Tip.Text = deck[index]
		ui.Tip.Position = UDim2.fromScale(0.145, 0.5)
		TweenService:Create(ui.Tip, TweenInfo.new(0.3, Enum.EasingStyle.Quint), { TextTransparency = 0, Position = UDim2.fromScale(0.125, 0.5) }):Play()
		nextAt = os.clock() + 4.5
		busy = false
	end
	ui.Card.Activated:Connect(function()
		task.spawn(nextTip)
	end)
	task.spawn(function()
		while not self.Done do
			task.wait(0.25)
			if os.clock() >= nextAt then
				nextTip()
			end
		end
	end)
end

function Kit:_runSkip()
	local ui = self.Ui
	local theme = self.Theme
	local function skip()
		if ui.Skip.Visible and not self.Done then
			self.Skipped = true
		end
	end
	ui.Skip.Activated:Connect(skip)
	self.InputConnection = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.ButtonA then
			skip()
		end
	end)
	task.delay(theme.SkipAfter or 1.5, function()
		if self.Done then
			return
		end
		ui.Skip.Visible = true
		local info = TweenInfo.new(0.3, Enum.EasingStyle.Quint)
		TweenService:Create(ui.Skip, info, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
		TweenService:Create(ui.SkipStroke, info, { Transparency = 0 }):Play()
	end)
end

-- Echter Fortschritt: Spiel geladen, Asset-Warteschlange und spielspezifische Pruefungen
function Kit:_track()
	local theme = self.Theme
	-- Immer: die Remotes des Servers sind da; optional: eigene Figur ist gespawnt
	local checks = {
		function()
			return game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") ~= nil
		end,
	}
	if theme.WaitForCharacter then
		table.insert(checks, function()
			return Players.LocalPlayer.Character ~= nil
		end)
	end
	for _, check in theme.Checks or {} do
		table.insert(checks, check)
	end
	local statuses = theme.Status or { "Loading..." }
	-- Mit 3D-Bild etwas laenger stehen lassen, damit man es auch sieht
	local minTime = theme.MinTime or (if self.Cinema then 2.5 else 1.5)
	local maxQueue = 1
	local loadedAt: number? = nil
	while not self.Skipped do
		local t = os.clock() - self.Start
		local loaded = game:IsLoaded()
		if loaded and not loadedAt then
			loadedAt = os.clock()
		end
		local queue = ContentProvider.RequestQueueSize
		maxQueue = math.max(maxQueue, queue)
		local passed = 0
		for _, check in checks do
			local ok, result = pcall(check)
			if ok and result then
				passed += 1
			end
		end
		-- Manche Spiele laden dauernd nach: 5 s nach dem Laden zaehlt die Warteschlange als fertig
		local queueDone = queue == 0 or (loadedAt ~= nil and os.clock() - loadedAt > 5)
		local loadPart = if loaded then 1 else 0.85 * (1 - math.exp(-t / 3))
		local assetPart = if queueDone and loaded then 1 else math.min(1 - queue / maxQueue, if loaded then 0.95 else 0.5)
		local checkPart = passed / #checks
		self.Progress = math.max(self.Progress, math.min(0.99, 0.4 * loadPart + 0.35 * assetPart + 0.25 * checkPart))

		local phase = if not loaded then 1 elseif not queueDone then 2 else 3
		self.Ui.Status.Text = statuses[math.min(phase, #statuses)]
		-- Das 3D-Bild soll nach dem Einblenden kurz zu sehen sein
		local backdrop = self.Backdrop
		local pictureSeen = not backdrop or not backdrop.Shown or os.clock() - (backdrop.ShownAt or 0) > 1.2
		if (loaded and queueDone and passed == #checks and t >= minTime and pictureSeen) or t >= MAX_TIME then
			break
		end
		task.wait(0.05)
	end
end

function Kit:_outro()
	local theme = self.Theme
	local quick = self.Skipped
	self.Fading = true
	local duration = if quick then 0.25 else 0.5
	if theme.Outro == "slide" then
		local tween = TweenService:Create(self.Background, TweenInfo.new(duration + 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.fromScale(0, -1.1) })
		tween:Play()
		tween.Completed:Wait()
		return
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	for _, layer in { self.Stage, self.Hud } do
		local zoom = layer:FindFirstChildOfClass("UIScale") or make("UIScale", {}, layer)
		TweenService:Create(zoom, info, { Scale = 1.06 }):Play()
	end
	if self.Backdrop then
		TweenService:Create(self.Backdrop.Zoom, info, { Scale = self.Backdrop.Zoom.Scale + 0.08 }):Play()
	end
	for _, item in self.Gui:GetDescendants() do
		if item:IsA("GuiObject") then
			TweenService:Create(item, info, { BackgroundTransparency = 1 }):Play()
			if item:IsA("TextLabel") or item:IsA("TextButton") then
				TweenService:Create(item, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			elseif item:IsA("ImageLabel") or item:IsA("ImageButton") then
				TweenService:Create(item, info, { ImageTransparency = 1 }):Play()
			end
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, info, { Transparency = 1 }):Play()
		end
	end
	task.wait(duration + 0.05)
end

function Kit:Run()
	local theme = self.Theme
	self:_buildUi()
	if theme.ScaleStrokes ~= false then
		self:_scaleStrokes()
	end
	self.Gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	self:_showBackdrop()

	-- Schriften vorladen, damit das Logo nicht mit der Ersatzschrift aufpoppt (hoechstens 0,6 s warten)
	local fontsReady = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, { self.Stage, self.Hud })
		fontsReady = true
	end)
	task.spawn(function()
		local waitUntil = os.clock() + 0.6
		while not fontsReady and os.clock() < waitUntil do
			task.wait()
		end
		for i, scale in self.Logos do
			task.delay((i - 1) * 0.12, function()
				TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end)
		end
		self:_showUi()
	end)

	local animation = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - self.Start
		local speed = if self.Done then 16 else 7
		self.Shown += (self.Progress - self.Shown) * (1 - math.exp(-dt * speed))
		local shown = self.Shown
		local ui = self.Ui
		ui.Fill.Size = UDim2.fromScale(math.max(shown, 0.03), 1)
		ui.Glint.Position = UDim2.fromScale((t * 0.7) % 1.6 - 0.3, 0)
		ui.Spark.Position = UDim2.fromScale(math.max(shown, 0.03), 0.5)
		ui.Spark.Size = UDim2.fromScale(2.2 + math.sin(t * 8) * 0.3, 2.2)
		ui.Percent.Text = `{math.floor(shown * 100 + 0.5)}%`
		if ui.Icon then
			ui.Icon.Rotation = math.sin(t * 1.6) * 2.5
		end
		local backdrop = self.Backdrop
		if backdrop and backdrop.Shown and not self.Fading then
			-- Langsame Kamerafahrt: Zoom und sanftes Schwenken
			local since = os.clock() - backdrop.ShownAt
			backdrop.Zoom.Scale = 1.04 + since * 0.012
			backdrop.Picture.Position = UDim2.new(0.5 + math.sin(t * 0.25) * 0.012, 0, 0.5 + math.cos(t * 0.2) * 0.008, 0)
			backdrop.SheenGradient.Offset = Vector2.new(math.clamp(((t % 4.5) - 1) / 1.6, 0, 1) * 2 - 1, 0)
			for _, mote in backdrop.Motes do
				local y = 1.05 - ((since * mote.Speed + mote.Phase) % 1.1)
				mote.Frame.Position = UDim2.fromScale(mote.X + math.sin(t * 1.5 + mote.Phase * 6) * 0.01, y)
				mote.Frame.BackgroundTransparency = 0.25 + (1 - y) * 0.7
			end
		end
		for _, shine in self.Shines do
			-- Glanz laeuft alle 3,2 s einmal ueber das Logo
			shine.Gradient.Offset = Vector2.new(math.clamp(((t % 3.2) - 0.9) / 1.1, 0, 1) * 2 - 1, 0)
			shine.Gloss.TextSize = shine.Label.TextSize
		end
		-- Beim Ausblenden und hinter dem 3D-Bild stehen die Spiel-Animationen still
		for i = if self.Fading or self.ArtHidden then 0 else #self.Animations, 1, -1 do
			local ok, err = pcall(self.Animations[i], t, dt, shown)
			if not ok then
				warn("LoadingScreen animation stopped:", err)
				table.remove(self.Animations, i)
			end
		end
	end)

	self:_runTips()
	self:_runSkip()
	self:_track()

	-- Fertig: Balken voll laufen lassen, kurz "bereit" zeigen, dann ausblenden
	self.Done = true
	self.Progress = 1
	self.Ui.Status.Text = theme.Ready or "Ready!"
	self.Ui.Skip.Visible = false
	if not self.Skipped then
		local waitUntil = os.clock() + 0.5
		while self.Shown < 0.995 and os.clock() < waitUntil do
			task.wait()
		end
		task.wait(0.35)
	end
	self:_outro()
	animation:Disconnect()
	if self.InputConnection then
		self.InputConnection:Disconnect()
	end
	self.Gui:Destroy()
end
-- <<< LoadingKit
-- >>> LoadingImages (3D-Vorschaubild in zwei Haelften + Icon, aus tools/loading/images.json)
local IMAGES = { left = "", right = "", icon = "" }
-- <<< LoadingImages

local INK = Color3.fromRGB(23, 21, 59)
local INK2 = Color3.fromRGB(42, 38, 96)
local CREAM = Color3.fromRGB(255, 248, 231)
local ORANGE = Color3.fromRGB(255, 122, 26)
local PINK = Color3.fromRGB(255, 61, 127)
local TEAL = Color3.fromRGB(25, 211, 197)
local LEMON = Color3.fromRGB(255, 225, 77)

local kit = Kit.new({
	Images = IMAGES,
	Background = INK,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScaleStrokes = false, -- die Buehne skaliert per UIScale, Konturen wachsen dort schon mit
	Outro = "slide",
	Ink = INK,
	Accent = LEMON,
	Panel = INK,
	PanelTransparency = 0.2,
	Bar = ColorSequence.new(ORANGE, PINK),
	BarBack = INK,
	BarStroke = CREAM,
	BarY = 0.625,
	TipY = 0.745,
	TitleFont = Enum.Font.LuckiestGuy,
	BodyFont = Enum.Font.GothamBold,
	Text = CREAM,
	StatusColor = CREAM,
	Status = { "Starting the engines...", "Building the city...", "Calling the cops..." },
	Ready = "Let's roll!",
	Tips = {
		"Rob the Bank, then race to the HIDEOUT to cash in!",
		"Cops earn big bounties for every wanted robber they catch.",
		"Chain deliveries without stopping for up to +150% pay!",
		"Upgrade your house: it pays rent every minute, even while you're offline.",
		"Teal BOOST strips on the road give your car a turbo kick!",
		"Hit the jump pads in the STUNT PARK!",
		"Play with friends: +10% cash for every friend in your server!",
		"Come back every day: your daily reward grows with your streak!",
	},
	WaitForCharacter = true,
})

local function new(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local background = kit.Background

-- Diagonale Streifen (bewegen sich langsam)
local stripes = new("Frame", { Size = UDim2.fromScale(1.6, 1.6), Position = UDim2.fromScale(-0.3, -0.3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = background })
-- ColorSequence erlaubt max. 20 Punkte: zwei harte Streifenpaare, die per Offset wandern
local stripeGradient = new("UIGradient", { Rotation = 30, Parent = stripes })
stripeGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, INK),
	ColorSequenceKeypoint.new(0.249, INK),
	ColorSequenceKeypoint.new(0.25, INK2),
	ColorSequenceKeypoint.new(0.499, INK2),
	ColorSequenceKeypoint.new(0.5, INK),
	ColorSequenceKeypoint.new(0.749, INK),
	ColorSequenceKeypoint.new(0.75, INK2),
	ColorSequenceKeypoint.new(1, INK2),
})

-- Szene in festen 1000x560-Koordinaten, per UIScale auf die 16:9-Buehne gebracht
local stage = new("Frame", { Size = UDim2.fromOffset(1000, 560), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = kit.Stage })
local scale = new("UIScale", { Parent = stage })
local function rescale()
	scale.Scale = math.max(kit.Stage.AbsoluteSize.X / 1000, 0.1)
end
rescale()
kit.Stage:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)

-- Sonne
local sun = new("Frame", { Size = UDim2.fromOffset(420, 420), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 360), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = stage })
new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = sun })
new("UIGradient", { Color = ColorSequence.new(LEMON, PINK), Rotation = 90, Parent = sun })

-- Skyline
local skyline = new("Frame", { Size = UDim2.fromOffset(1000, 200), Position = UDim2.fromOffset(0, 300), BackgroundTransparency = 1, ClipsDescendants = false, Parent = stage })
local rng = Random.new(7)
local x = -20
while x < 1020 do
	local w = rng:NextInteger(50, 95)
	local h = rng:NextInteger(60, 190)
	local building = new("Frame", { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, 200 - h), BackgroundColor3 = INK2, BorderSizePixel = 0, Parent = skyline })
	for wy = 14, h - 14, 22 do
		for wx = 10, w - 18, 20 do
			if rng:NextNumber() < 0.45 then
				new("Frame", { Size = UDim2.fromOffset(8, 10), Position = UDim2.fromOffset(wx, wy), BackgroundColor3 = LEMON, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = building })
			end
		end
	end
	x += w + rng:NextInteger(-6, 6)
end

-- Strasse
local road = new("Frame", { Size = UDim2.fromOffset(1400, 70), Position = UDim2.fromOffset(-200, 490), BackgroundColor3 = Color3.fromRGB(35, 33, 70), BorderSizePixel = 0, Parent = stage })
new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = ORANGE, BorderSizePixel = 0, Parent = road })
local dashes = new("Frame", { Size = UDim2.fromOffset(1400, 6), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, Parent = road })
for i = 0, 27 do
	new("Frame", { Size = UDim2.fromOffset(30, 6), Position = UDim2.fromOffset(i * 50, 0), BackgroundColor3 = LEMON, BorderSizePixel = 0, Parent = dashes })
end

-- Auto (faehrt mit dem Fortschritt nach rechts)
local car = new("Frame", { Size = UDim2.fromOffset(120, 60), Position = UDim2.fromOffset(40, 444), BackgroundTransparency = 1, Parent = stage })
local body = new("Frame", { Size = UDim2.fromOffset(120, 30), Position = UDim2.fromOffset(0, 18), BackgroundColor3 = PINK, BorderSizePixel = 0, Parent = car })
new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = body })
new("UIStroke", { Color = INK, Thickness = 4, Parent = body })
local cabin = new("Frame", { Size = UDim2.fromOffset(60, 26), Position = UDim2.fromOffset(28, -2), BackgroundColor3 = TEAL, BorderSizePixel = 0, ZIndex = 0, Parent = car })
new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = cabin })
new("UIStroke", { Color = INK, Thickness = 4, Parent = cabin })
new("Frame", { Size = UDim2.fromOffset(12, 8), Position = UDim2.fromOffset(108, 26), BackgroundColor3 = LEMON, BorderSizePixel = 0, Parent = car })
-- Scheinwerfer-Kegel
local beam = new("Frame", { Size = UDim2.fromOffset(90, 26), Position = UDim2.fromOffset(118, 18), BackgroundColor3 = LEMON, BorderSizePixel = 0, Parent = car })
new("UIGradient", { Transparency = NumberSequence.new(0.35, 1), Parent = beam })
local wheels = {}
for _, wx in { 14, 78 } do
	local wheel = new("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(wx, 36), BackgroundColor3 = INK, BorderSizePixel = 0, Parent = car })
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = wheel })
	local hub = new("Frame", { Size = UDim2.fromOffset(12, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = LEMON, BorderSizePixel = 0, Parent = wheel })
	table.insert(wheels, hub)
end

-- Logo: TURBO / CITY mit hartem Comic-Schatten
local logo = new("Frame", { Size = UDim2.fromOffset(1000, 320), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 160), BackgroundTransparency = 1, Parent = stage })
local function logoText(text: string, y: number, size: number, color: Color3)
	local shadow = new("TextLabel", { Size = UDim2.fromOffset(800, size), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(508, y + 8), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = text, TextSize = size, TextColor3 = PINK, Parent = logo })
	new("UIStroke", { Color = INK, Thickness = 6, Parent = shadow })
	local label = new("TextLabel", { Size = UDim2.fromOffset(800, size), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, y), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = text, TextSize = size, TextColor3 = color, Parent = logo })
	new("UIStroke", { Color = INK, Thickness = 6, Parent = label })
	return label, shadow
end
local logoTop, topShadow = logoText("TURBO", 40, 130, LEMON)
local logoBottom, bottomShadow = logoText("CITY", 160, 100, CREAM)
local ribbon = new("Frame", { Size = UDim2.fromOffset(300, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 285), Rotation = -4, BackgroundColor3 = TEAL, BorderSizePixel = 0, Parent = logo })
new("UIStroke", { Color = INK, Thickness = 4, Parent = ribbon })
new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = "COPS & ROBBERS", TextSize = 30, TextColor3 = INK, Parent = ribbon })

kit:Logo(logo, { logoTop, logoBottom })

kit:Animate(function(t, _, shown)
	stripeGradient.Offset = Vector2.new((t * 0.05) % 0.5, 0)
	dashes.Position = UDim2.fromOffset(-((t * 260) % 50), 38)
	car.Position = UDim2.fromOffset(40 + shown * 820, 444 + math.abs(math.sin(t * 9)) * -3)
	for _, hub in wheels do
		hub.Rotation = (t * 720) % 360
	end
	local pulse = 1 + math.sin(t * 2.4) * 0.025
	logoTop.TextSize = 130 * pulse
	topShadow.TextSize = 130 * pulse
	logoBottom.TextSize = 100 * pulse
	bottomShadow.TextSize = 100 * pulse
	ribbon.Rotation = -4 + math.sin(t * 2.4) * 1.5
end)

kit:Run()
