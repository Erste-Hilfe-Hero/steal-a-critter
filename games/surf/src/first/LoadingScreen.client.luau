-- Eigener Ladebildschirm im "Alpine Aurora"-Stil: Polarlicht, Logo und ein Surfer, der mit dem
-- Ladefortschritt eine Rampe hinuntersurft. Ersetzt den Roblox-Standard.
-- >>> LoadingKit
-- Gemeinsamer Kern aller Ladebildschirme: Buehne fuer Handy und PC, echter Fortschritt, Tipps,
-- SKIP-Knopf, Logo-Intro mit Glanz, sauberes Ausblenden und 15-s-Notbremse.
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

function Kit.new(theme: { [string]: any })
	local self = setmetatable({}, Kit)
	self.Theme = theme
	self.Start = os.clock()
	self.Progress = 0
	self.Shown = 0
	self.Done = false
	self.Skipped = false
	self.Fading = false
	self.Animations = {}
	self.Logos = {}
	self.Shines = {}

	local gui = make("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100 })
	if theme.ZIndexBehavior then
		gui.ZIndexBehavior = theme.ZIndexBehavior
	end
	self.Gui = gui
	-- Hintergrund fuellt den ganzen Bildschirm, die Buehne bleibt 16:9 und damit auf jedem Geraet gleich
	self.Background = make("Frame", {
		Name = "Background",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = theme.Background or Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, gui)
	self.Stage = make("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 2,
	}, self.Background)
	make("UIAspectRatioConstraint", { AspectRatio = 16 / 9 }, self.Stage)

	-- Notbremse, auch falls im Spielcode etwas schiefgeht
	task.delay(MAX_TIME + 2, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	return self
end

-- Jede Frame-Animation bekommt (Zeit, dt, angezeigter Fortschritt 0..1)
function Kit:Animate(callback: (number, number, number) -> ())
	table.insert(self.Animations, callback)
end

-- Logo: springt beim Start auf (Back-Easing); die Texte bekommen einen Glanzstreifen
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
	local stage = self.Stage
	local tipY = theme.TipY or 0.765
	local barY = theme.BarY or 0.865

	-- Tipp-Karte (antippen = naechster Tipp)
	local card = make("TextButton", {
		Name = "TipCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, tipY + 0.02),
		Size = UDim2.fromScale(0.74, 0.085),
		BackgroundColor3 = theme.Panel or ink,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		ZIndex = 20,
	}, stage)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, card)
	local cardStroke = make("UIStroke", { Color = accent, Thickness = 2, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, card)
	local chip = make("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0.012, 0.5),
		Size = UDim2.fromScale(0.095, 0.64),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		Text = "TIP",
		FontFace = heavy,
		TextScaled = true,
		TextColor3 = theme.AccentText or ink,
		TextTransparency = 1,
		ZIndex = 21,
	}, card)
	make("UICorner", { CornerRadius = UDim.new(0.35, 0) }, chip)
	make("UIPadding", { PaddingTop = UDim.new(0.16, 0), PaddingBottom = UDim.new(0.16, 0) }, chip)
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
		ZIndex = 21,
	}, card)
	make("UITextSizeConstraint", { MaxTextSize = 30, MinTextSize = 9 }, tip)

	-- Fortschrittsbalken mit Lauflicht, darunter Status links und Prozent rechts
	local barBack = make("Frame", {
		Name = "Bar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, barY + 0.02),
		Size = UDim2.fromScale(0.5, 0.024),
		BackgroundColor3 = theme.BarBack or ink,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = theme.ShowBar ~= false,
		ZIndex = 20,
	}, stage)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, barBack)
	local barStroke = make("UIStroke", { Color = theme.BarStroke or ink, Thickness = 2, Transparency = 1 }, barBack)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 21 }, barBack)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	make("UIGradient", { Color = theme.Bar or ColorSequence.new(accent) }, fill)
	local glint = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(0.35, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 22 }, fill)
	make("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }),
	}, glint)

	local row = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, barY + 0.025),
		Size = UDim2.fromScale(0.5, 0.042),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}, stage)
	local statusColor = theme.StatusColor or theme.Text or Color3.new(1, 1, 1)
	local status = make("TextLabel", {
		Size = UDim2.fromScale(0.8, 1),
		BackgroundTransparency = 1,
		FontFace = body,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = statusColor,
		TextTransparency = 1,
		Text = "",
		ZIndex = 21,
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
		TextColor3 = statusColor,
		TextTransparency = 1,
		Text = "0%",
		ZIndex = 21,
	}, row)
	make("UITextSizeConstraint", { MaxTextSize = 24, MinTextSize = 8 }, percent)
	for _, label in { status, percent } do
		make("UIStroke", { Color = ink, Thickness = 1.5, Transparency = 1 }, label)
	end

	-- SKIP unten rechts (Daumen-Reichweite, gross genug zum Tippen)
	local skip = make("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(0.985, 0.965),
		Size = UDim2.fromScale(0.105, 0.072),
		BackgroundColor3 = accent,
		BackgroundTransparency = 1,
		AutoButtonColor = true,
		FontFace = heavy,
		Text = "SKIP  »",
		TextScaled = true,
		TextColor3 = theme.AccentText or ink,
		TextTransparency = 1,
		Visible = false,
		ZIndex = 23,
	}, stage)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, skip)
	make("UIPadding", { PaddingTop = UDim.new(0.2, 0), PaddingBottom = UDim.new(0.2, 0), PaddingLeft = UDim.new(0.1, 0), PaddingRight = UDim.new(0.1, 0) }, skip)
	make("UISizeConstraint", { MinSize = Vector2.new(84, 38) }, skip)
	local skipStroke = make("UIStroke", { Color = ink, Thickness = 2.5, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skip)

	self.Ui = {
		Card = card,
		CardStroke = cardStroke,
		Chip = chip,
		Tip = tip,
		BarBack = barBack,
		BarStroke = barStroke,
		Fill = fill,
		Glint = glint,
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
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local tipY = theme.TipY or 0.765
	local barY = theme.BarY or 0.865
	TweenService:Create(ui.Card, info, { Position = UDim2.fromScale(0.5, tipY), BackgroundTransparency = theme.PanelTransparency or 0.35 }):Play()
	TweenService:Create(ui.CardStroke, info, { Transparency = 0.55 }):Play()
	TweenService:Create(ui.Chip, info, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
	TweenService:Create(ui.Tip, info, { TextTransparency = 0 }):Play()
	TweenService:Create(ui.BarBack, info, { Position = UDim2.fromScale(0.5, barY), BackgroundTransparency = theme.BarBackTransparency or 0.15 }):Play()
	TweenService:Create(ui.BarStroke, info, { Transparency = 0.4 }):Play()
	TweenService:Create(ui.Fill, info, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(ui.Glint, info, { BackgroundTransparency = 0 }):Play()
	for _, label in { ui.Status, ui.Percent } do
		TweenService:Create(label, info, { TextTransparency = 0 }):Play()
		TweenService:Create(label:FindFirstChildOfClass("UIStroke"), info, { Transparency = 0.5 }):Play()
	end
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
	local minTime = theme.MinTime or 1.5
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
		if (loaded and queueDone and passed == #checks and t >= minTime) or t >= MAX_TIME then
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
	local zoom = self.Stage:FindFirstChildOfClass("UIScale") or make("UIScale", {}, self.Stage)
	TweenService:Create(zoom, info, { Scale = 1.06 }):Play()
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

	-- Schriften vorladen, damit das Logo nicht mit der Ersatzschrift aufpoppt (hoechstens 0,6 s warten)
	local fontsReady = false
	task.spawn(function()
		pcall(ContentProvider.PreloadAsync, ContentProvider, { self.Gui })
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
		ui.Percent.Text = `{math.floor(shown * 100 + 0.5)}%`
		for _, shine in self.Shines do
			-- Glanz laeuft alle 3,2 s einmal ueber das Logo
			shine.Gradient.Offset = Vector2.new(math.clamp(((t % 3.2) - 0.9) / 1.1, 0, 1) * 2 - 1, 0)
			shine.Gloss.TextSize = shine.Label.TextSize
		end
		-- Beim Ausblenden stehen die Spiel-Animationen still, sonst setzen sie Transparenzen zurueck
		for i = if self.Fading then 0 else #self.Animations, 1, -1 do
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
		task.wait(0.3)
	end
	self:_outro()
	animation:Disconnect()
	if self.InputConnection then
		self.InputConnection:Disconnect()
	end
	self.Gui:Destroy()
end
-- <<< LoadingKit

local NAVY = Color3.fromRGB(11, 21, 48)
local ICE = Color3.fromRGB(92, 225, 255)
local AURORA = Color3.fromRGB(255, 79, 163)
local MINT = Color3.fromRGB(110, 255, 190)
local SNOW = Color3.fromRGB(240, 248, 255)
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local kit = Kit.new({
	Background = Color3.new(1, 1, 1),
	Ink = NAVY,
	Accent = ICE,
	AccentText = NAVY,
	Panel = Color3.fromRGB(20, 34, 74),
	PanelTransparency = 0.3,
	Bar = ColorSequence.new({ ColorSequenceKeypoint.new(0, MINT), ColorSequenceKeypoint.new(0.5, ICE), ColorSequenceKeypoint.new(1, AURORA) }),
	BarBack = Color3.fromRGB(20, 30, 66),
	BarStroke = Color3.fromRGB(60, 90, 150),
	TipY = 0.79,
	BarY = 0.875,
	TitleFont = HEAVY,
	BodyFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	Text = SNOW,
	StatusColor = Color3.fromRGB(150, 175, 215),
	Status = { "WAXING SKIS...", "FREEZING THE RAMPS...", "SYNCING WORLD RECORDS..." },
	Ready = "DROP IN!",
	Tips = {
		"Hold A or D TOWARD the ramp - never W - to stick to it.",
		"Land on the side of a ramp, not on the top edge.",
		"Strafe and turn the mouse together in the air to gain speed.",
		"Falling resets the stage, but the map clock keeps running.",
		"Type /r to restart the run and /s to restart the stage.",
		"Every stage you clear unlocks it in the STAGES menu.",
		"Beat a stage record and the whole server hears about it!",
		"Pros hit 3000 u/s. How fast can you go?",
	},
	WaitForCharacter = true,
})
local background, stage = kit.Background, kit.Stage

local sky = Instance.new("UIGradient")
sky.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 12, 32)),
	ColorSequenceKeypoint.new(0.6, NAVY),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 50, 110)),
})
sky.Rotation = 90
sky.Parent = background

-- Polarlicht: drei weiche Baender, die langsam wandern
local ribbons = {}
for i, color in { MINT, ICE, AURORA } do
	local ribbon = Instance.new("Frame")
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromScale(0.5, 0.18 + i * 0.07)
	ribbon.Size = UDim2.fromScale(1.6, 0.16)
	ribbon.Rotation = -8 + i * 3
	ribbon.BackgroundColor3 = color
	ribbon.BorderSizePixel = 0
	ribbon.BackgroundTransparency = 0.25
	ribbon.Parent = background
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = ribbon
	ribbons[i] = { Frame = ribbon, Gradient = fade, Phase = i * 1.7, Y = 0.18 + i * 0.07 }
end

-- Berg-Silhouetten am unteren Rand
for i, peak in { { 0.15, 0.5, 0.42 }, { 0.42, 0.62, 0.36 }, { 0.7, 0.55, 0.4 }, { 0.95, 0.45, 0.34 } } do
	local mountain = Instance.new("Frame")
	mountain.AnchorPoint = Vector2.new(0.5, 0.5)
	mountain.Position = UDim2.fromScale(peak[1], 1.02)
	mountain.Size = UDim2.fromScale(peak[2] * 0.6, peak[3])
	mountain.Rotation = 45
	mountain.BackgroundColor3 = Color3.fromRGB(18 + i * 4, 30 + i * 4, 70 + i * 6)
	mountain.BorderSizePixel = 0
	mountain.Parent = background
	Instance.new("UIAspectRatioConstraint").Parent = mountain
end

-- Sterne/Schnee
local flakes = {}
for _ = 1, 60 do
	local flake = Instance.new("Frame")
	local size = math.random(2, 5)
	flake.Size = UDim2.fromOffset(size, size)
	flake.Position = UDim2.fromScale(math.random(), math.random())
	flake.BackgroundColor3 = SNOW
	flake.BackgroundTransparency = math.random() * 0.5
	flake.BorderSizePixel = 0
	flake.Parent = background
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = flake
	table.insert(flakes, { Frame = flake, Speed = 0.03 + math.random() * 0.05, Drift = math.random() * 2 })
end

-- Logo
local logo = Instance.new("TextLabel")
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.33)
logo.Size = UDim2.fromScale(0.7, 0.2)
logo.BackgroundTransparency = 1
logo.Text = "surf_ski"
logo.TextScaled = true
logo.FontFace = HEAVY
logo.TextColor3 = Color3.new(1, 1, 1)
logo.Parent = stage
local logoGradient = Instance.new("UIGradient")
logoGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ICE), ColorSequenceKeypoint.new(0.55, SNOW), ColorSequenceKeypoint.new(1, AURORA) })
logoGradient.Parent = logo
local logoStroke = Instance.new("UIStroke")
logoStroke.Color = NAVY
logoStroke.Thickness = 4
logoStroke.Parent = logo

local tagline = Instance.new("TextLabel")
tagline.AnchorPoint = Vector2.new(0.5, 0.5)
tagline.Position = UDim2.fromScale(0.5, 0.46)
tagline.Size = UDim2.fromScale(0.6, 0.04)
tagline.BackgroundTransparency = 1
tagline.Text = "CLASSIC SURF  ·  10 ALPINE STAGES  ·  WORLD RECORDS"
tagline.TextScaled = true
tagline.FontFace = MONO
tagline.TextColor3 = ICE
tagline.Parent = stage

-- Rampe mit Surfer (Punkt + Leuchtspur), der Surfer folgt dem Ladefortschritt
local rampFrame = Instance.new("Frame")
rampFrame.AnchorPoint = Vector2.new(0.5, 0.5)
rampFrame.Position = UDim2.fromScale(0.5, 0.64)
rampFrame.Size = UDim2.fromScale(0.62, 0.008)
rampFrame.Rotation = 9
rampFrame.BackgroundColor3 = SNOW
rampFrame.BackgroundTransparency = 0.2
rampFrame.BorderSizePixel = 0
rampFrame.Parent = stage
local surfer = Instance.new("Frame")
surfer.AnchorPoint = Vector2.new(0.5, 1)
surfer.Size = UDim2.fromScale(0.03, 3.4)
surfer.BackgroundColor3 = ICE
surfer.BorderSizePixel = 0
surfer.Parent = rampFrame
Instance.new("UIAspectRatioConstraint").Parent = surfer
local surferRound = Instance.new("UICorner")
surferRound.CornerRadius = UDim.new(1, 0)
surferRound.Parent = surfer
local surferGlow = Instance.new("UIStroke")
surferGlow.Color = SNOW
surferGlow.Thickness = 2
surferGlow.Transparency = 0.3
surferGlow.Parent = surfer
local trail = Instance.new("Frame")
trail.AnchorPoint = Vector2.new(1, 1)
trail.Size = UDim2.new(0, 0, 0, 6)
trail.BackgroundColor3 = Color3.new(1, 1, 1)
trail.BorderSizePixel = 0
trail.Parent = rampFrame
local trailGradient = Instance.new("UIGradient")
trailGradient.Color = ColorSequence.new(MINT, AURORA)
trailGradient.Transparency = NumberSequence.new(1, 0)
trailGradient.Parent = trail

kit:Logo(logo, { logo })
kit:Logo(tagline)

kit:Animate(function(t, dt, shown)
	for _, r in ribbons do
		r.Gradient.Offset = Vector2.new(math.sin(t * 0.35 + r.Phase) * 0.25, 0)
		r.Frame.Position = UDim2.fromScale(0.5 + math.sin(t * 0.2 + r.Phase) * 0.04, r.Y)
	end
	for _, f in flakes do
		local pos = f.Frame.Position
		local y = pos.Y.Scale + f.Speed * dt
		local x = pos.X.Scale + math.sin(t + f.Drift) * 0.0004
		f.Frame.Position = UDim2.fromScale(x % 1, if y > 1 then 0 else y)
	end
	surfer.Position = UDim2.new(shown, 0, 0, -2)
	trail.Position = UDim2.new(shown, -6, 0, -4)
	trail.Size = UDim2.new(math.min(shown, 0.25), 0, 0, 6)
	logo.Rotation = math.sin(t * 1.4) * 1.2
end)

kit:Run()
