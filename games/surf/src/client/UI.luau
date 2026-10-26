-- HUD im "Alpine Aurora"-Stil: Timer wie auf CS-Surf-Servern, Tacho in u/s, Schneeflocken, Rang,
-- Knoepfe fuer Neustart/Checkpoints, Shop (Paesse, Schneeflocken, Trails, Skier), Stage-Auswahl,
-- Bestenliste, Tagesbelohnung, Starter-Pack-Angebot, Gratis-Werbung und Chat-Tags.
local AdService = game:GetService("AdService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local T = Config.Theme

local UI = {}
UI.OpenMore = nil :: ((tab: string?) -> ())? -- setzt Extras.luau
UI.ShowDaily = nil :: any

local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local MEDIUM = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local function create(className: string, props, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = instance
	end
	instance.Parent = props.Parent
	return instance
end

local function corner(radius: number?): UICorner
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return create("UIStroke", { Color = color or T.Ice, Thickness = thickness or 1, Transparency = transparency or 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or BOLD
	props.TextColor3 = props.TextColor3 or T.Snow
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return create("TextLabel", props)
end

local function panel(props, children): Frame
	local radius = props.Radius or 12
	props.Radius = nil
	props.BackgroundColor3 = props.BackgroundColor3 or T.Panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	local frame = create("Frame", props, children)
	corner(radius).Parent = frame
	stroke().Parent = frame
	return frame
end

local clickSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.25, Parent = SoundService })

local function button(props, onClick: () -> ()): TextButton
	local color = props.Color or T.PanelLight
	local radius = props.Radius or 10
	props.Color = nil
	props.Radius = nil
	props.BackgroundColor3 = color
	props.AutoButtonColor = false
	props.FontFace = props.FontFace or HEAVY
	props.TextColor3 = props.TextColor3 or T.Snow
	props.TextScaled = true
	local b = create("TextButton", props)
	corner(radius).Parent = b
	stroke(T.Snow, 1, 0.75).Parent = b
	create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), Parent = b })
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
	end)
	b.Activated:Connect(function()
		clickSound:Play()
		onClick()
	end)
	return b
end

local function speedColor(speed: number): Color3
	local u = speed / SurfPhysics.Unit
	if u < 500 then
		return T.Snow:Lerp(T.Ice, u / 500)
	elseif u < 1200 then
		return T.Ice:Lerp(T.Mint, (u - 500) / 700)
	elseif u < 2200 then
		return T.Mint:Lerp(T.Gold, (u - 1200) / 1000)
	end
	return T.Gold:Lerp(T.Aurora, math.min(1, (u - 2200) / 1000))
end

function UI.Start(Movement)
	local gui = create("ScreenGui", { Name = "SurfHUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })
	local scale = create("UIScale", { Parent = gui })
	local camera = workspace.CurrentCamera
	local function rescale()
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.25)
	end
	rescale()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	------------------------------------------------ Timer (oben Mitte)

	local timerPanel = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(340, 104), Parent = gui })
	local stageLabel = text({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 18), Text = "LOBBY", TextColor3 = T.Ice, FontFace = HEAVY, Parent = timerPanel })
	local runLabel = text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 44), Text = "--:--.---", FontFace = MONO, Parent = timerPanel })
	local subLabel = text({ Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -24, 0, 18), Text = "", TextColor3 = T.Muted, FontFace = MONO, Parent = timerPanel })
	local practiceTag = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(86, 18), Text = "PRACTICE", TextColor3 = T.Navy, BackgroundTransparency = 0, BackgroundColor3 = T.Aurora, FontFace = HEAVY, Visible = false, Parent = timerPanel })
	corner(6).Parent = practiceTag

	------------------------------------------------ Tacho (unten Mitte)

	local speedPanel = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(240, 78), BackgroundTransparency = 1, Parent = gui })
	local speedLabel = text({ Size = UDim2.new(1, 0, 0, 52), Text = "0", FontFace = MONO, Parent = speedPanel })
	create("UIStroke", { Color = T.Navy, Thickness = 2.5, Transparency = 0.2, Parent = speedLabel })
	local unitLabel = text({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 14), Text = "U/S", TextColor3 = T.Muted, FontFace = HEAVY, Parent = speedPanel })
	UI.SpeedPanel = speedPanel
	local barBack = create("Frame", { Position = UDim2.new(0.1, 0, 0, 68), Size = UDim2.new(0.8, 0, 0, 6), BackgroundColor3 = T.Navy, BackgroundTransparency = 0.3, Parent = speedPanel })
	corner(3).Parent = barBack
	local bar = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Ice, Parent = barBack })
	corner(3).Parent = bar
	-- Update 2: persoenliches Hoechsttempo (vom Server gemessen) unter dem Tacho
	local function refreshTop()
		local top = player:GetAttribute("TopSpeed") or 0
		unitLabel.Text = if top > 0 then `U/S   -   TOP {Format.Number(top)}` else "U/S"
	end
	player:GetAttributeChangedSignal("TopSpeed"):Connect(refreshTop)
	refreshTop()

	------------------------------------------------ Schneeflocken und Rang (oben links)

	local flakesPill = panel({ Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(170, 40), Radius = 20, Parent = gui })
	local flakesLabel = text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, FontFace = HEAVY, Parent = flakesPill })
	local rankPill = panel({ Position = UDim2.fromOffset(10, 56), Size = UDim2.fromOffset(120, 26), Radius = 13, Parent = gui })
	local rankLabel = text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = "NEWBIE", FontFace = HEAVY, Parent = rankPill })
	-- Update 2: aktueller Schneeflocken-Multiplikator (Paesse, Premium, Booster, Schneesturm, Freunde)
	local multPill = panel({ Position = UDim2.fromOffset(186, 10), Size = UDim2.fromOffset(64, 40), Radius = 20, BackgroundColor3 = T.Gold, BackgroundTransparency = 0.1, Visible = false, Parent = gui })
	local multLabel = text({ Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 1, -16), Text = "x1", TextColor3 = T.Navy, FontFace = HEAVY, Parent = multPill })
	local function multiplier(): number
		local m = 1
		if player:GetAttribute("Pass_VIP") then
			m *= Config.VipMultiplier
		end
		if player:GetAttribute("Pass_DoubleFlakes") then
			m *= Config.DoubleFlakesMultiplier
		end
		if player.MembershipType == Enum.MembershipType.Premium then
			m *= Config.PremiumMultiplier
		end
		if (player:GetAttribute("BoostUntil") or 0) > os.time() then
			m *= Progression.BoostMultiplier
		end
		if (workspace:GetAttribute("StormUntil") or 0) > os.time() then
			m *= Progression.StormMultiplier
		end
		m *= 1 + (player:GetAttribute("FriendBonus") or 0)
		return m
	end
	task.spawn(function()
		while gui.Parent do
			local m = multiplier()
			multPill.Visible = m > 1.001
			multLabel.Text = "x" .. (string.gsub(string.format("%.1f", m), "%.0$", ""))
			task.wait(1)
		end
	end)

	------------------------------------------------ Toasts und Ansagen

	local toastHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.fromOffset(520, 200), BackgroundTransparency = 1, Parent = gui })
	create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = toastHolder })
	local function toast(message: string, color: Color3?, seconds: number?)
		local t = panel({ Size = UDim2.fromOffset(500, 34), BackgroundTransparency = 0.08, Parent = toastHolder })
		local label = text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), Text = message, TextColor3 = color or T.Snow, Parent = t })
		task.delay(seconds or 3.5, function()
			TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.45)
			t:Destroy()
		end)
	end
	UI.Toast = toast
	remotes.Notify.OnClientEvent:Connect(function(message, color)
		toast(message, color)
	end)
	local banner = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -40), Size = UDim2.new(0.7, 0, 0, 30), BackgroundTransparency = 0.1, BackgroundColor3 = T.Navy, Text = "", FontFace = HEAVY, Parent = gui })
	corner(8).Parent = banner
	local bannerToken = 0
	remotes.Announce.OnClientEvent:Connect(function(message, color)
		bannerToken += 1
		local token = bannerToken
		banner.Text = message
		banner.TextColor3 = color or T.Ice
		TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 2) }):Play()
		task.delay(5, function()
			if token == bannerToken then
				TweenService:Create(banner, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -40) }):Play()
			end
		end)
	end)

	------------------------------------------------ Fenster

	local backdrop = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 5, Parent = gui })
	local windows = {}
	local function closeAll()
		for _, w in windows do
			w.Visible = false
		end
		backdrop.Visible = false
		Movement.UiOpen = false
	end
	backdrop.Activated:Connect(closeAll)

	local function window(title: string, width: number, height: number)
		local w = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(width, height), BackgroundTransparency = 0.02, ZIndex = 6, Visible = false, Radius = 16, Parent = gui })
		create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 210, 235)), Rotation = 90, Parent = w })
		-- Aurora-Streifen oben = Wiedererkennung
		local strip = create("Frame", { Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7, Parent = w })
		create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, T.Mint), ColorSequenceKeypoint.new(0.5, T.Ice), ColorSequenceKeypoint.new(1, T.Aurora) }), Parent = strip })
		text({ Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -90, 0, 30), Text = title, TextXAlignment = Enum.TextXAlignment.Left, FontFace = HEAVY, ZIndex = 7, Parent = w })
		button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(36, 36), Text = "X", Color = T.Red, ZIndex = 7, Parent = w }, closeAll)
		w:SetAttribute("Width", width)
		w:SetAttribute("Height", height)
		local body = create("Frame", { Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 1, -70), BackgroundTransparency = 1, ZIndex = 7, Parent = w })
		table.insert(windows, w)
		return w, body
	end
	local function open(w)
		closeAll()
		w.Visible = true
		backdrop.Visible = true
		Movement.UiOpen = true
		local size = UDim2.fromOffset(w:GetAttribute("Width"), w:GetAttribute("Height"))
		w.Size = size - UDim2.fromOffset(20, 20)
		TweenService:Create(w, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = size }):Play()
	end

	local function scrollList(parent: Instance, cellSize: UDim2?)
		local frame = create("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = T.Ice, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 7, Parent = parent })
		if cellSize then
			create("UIGridLayout", { CellSize = cellSize, CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
		else
			create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
		end
		create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), Parent = frame })
		return frame
	end

	-- Bausteine fuer Extras.luau (Update 2)
	UI.Kit = {
		create = create,
		text = text,
		panel = panel,
		button = button,
		corner = corner,
		stroke = stroke,
		window = window,
		open = open,
		closeAll = closeAll,
		scrollList = scrollList,
		toast = toast,
		gui = gui,
		touch = touch,
		HEAVY = HEAVY,
		BOLD = BOLD,
		MEDIUM = MEDIUM,
		MONO = MONO,
	}

	------------------------------------------------ Shop

	local shopWindow, shopBody = window("SKI SHOP", 760, 470)
	local tabsBar = create("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, ZIndex = 7, Parent = shopBody })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = tabsBar })
	local pages = {}
	local tabButtons = {}
	local function showTab(name: string)
		for key, page in pages do
			page.Visible = key == name
			tabButtons[key].BackgroundColor3 = if key == name then T.Ice else T.PanelLight
			tabButtons[key].TextColor3 = if key == name then T.Navy else T.Snow
		end
	end
	for i, name in { "PASSES", "SNOWFLAKES", "TRAILS", "SKIS", "BUDDIES" } do
		tabButtons[name] = button({ Size = UDim2.fromOffset(132, 34), Text = name, LayoutOrder = i, ZIndex = 8, Parent = tabsBar }, function()
			showTab(name)
		end)
		local holder = create("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, Visible = false, ZIndex = 7, Parent = shopBody })
		pages[name] = scrollList(holder, UDim2.fromOffset(166, 150))
		pages[name].Parent = holder
		pages[name] = holder
	end

	local function card(parent: Instance, order: number, title: string, desc: string, accent: Color3)
		local c = panel({ BackgroundColor3 = T.PanelLight, BackgroundTransparency = 0.05, LayoutOrder = order, ZIndex = 8, Parent = parent })
		local swatch = create("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 6), BackgroundColor3 = accent, ZIndex = 9, Parent = c })
		corner(3).Parent = swatch
		text({ Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 22), Text = title, FontFace = HEAVY, ZIndex = 9, Parent = c })
		text({ Position = UDim2.fromOffset(10, 46), Size = UDim2.new(1, -20, 0, 48), Text = desc, TextColor3 = T.Muted, FontFace = MEDIUM, TextWrapped = true, ZIndex = 9, Parent = c })
		return c, swatch
	end

	local passButtons = {}
	local passList = pages.PASSES:FindFirstChildOfClass("ScrollingFrame")
	local passKeys = {}
	for key in Config.GamePasses do
		table.insert(passKeys, key)
	end
	table.sort(passKeys, function(a, b)
		return Config.GamePasses[a].Order < Config.GamePasses[b].Order
	end)
	for _, key in passKeys do
		local pass = Config.GamePasses[key]
		local c = card(passList, pass.Order, pass.Name, pass.Description, T.Gold)
		passButtons[key] = button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = `R$ {pass.PriceHint}`, Color = T.Mint, TextColor3 = T.Navy, ZIndex = 9, Parent = c }, function()
			remotes.Purchase:FireServer("Pass", key)
		end)
	end

	local flakeList = pages.SNOWFLAKES:FindFirstChildOfClass("ScrollingFrame")
	for key, product in Config.DevProducts do
		if not product.Hidden then
			local c = card(flakeList, product.Order, product.Name, product.Description, if product.Kind == "Flakes" then T.Ice else T.Aurora)
			button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = `R$ {product.PriceHint}`, Color = T.Mint, TextColor3 = T.Navy, ZIndex = 9, Parent = c }, function()
				remotes.Purchase:FireServer("Product", key)
			end)
		end
	end
	local adCard = card(flakeList, 0, "FREE", "Watch a short video for 300 Snowflakes", T.Mint)
	local adShopButton = button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = "WATCH", Color = T.Ice, TextColor3 = T.Navy, ZIndex = 9, Parent = adCard }, function()
		remotes.WatchAd:FireServer()
	end)

	local cosmeticButtons = {}
	local function cosmeticCards(kind: string, list, pageName: string)
		local page = pages[pageName]:FindFirstChildOfClass("ScrollingFrame")
		for i, item in list do
			local accent = if kind == "Trail" then item.Colors[#item.Colors] else (item.Color or T.Muted)
			local priceText = if item.Pass
				then (if item.Pass == "StarterPack" then "Starter Pack" else Config.GamePasses[item.Pass].Name)
				elseif item.Spin then "Lucky Snowball only"
				else (if item.Price == 0 then "Free" else `{Format.Number(item.Price)} Snowflakes`)
			local c, swatch = card(page, i, item.Name, priceText, accent)
			if kind == "Trail" and #item.Colors > 1 then
				swatch.BackgroundColor3 = Color3.new(1, 1, 1)
				local keys = {}
				for j, color in item.Colors do
					table.insert(keys, ColorSequenceKeypoint.new((j - 1) / (#item.Colors - 1), color))
				end
				create("UIGradient", { Color = ColorSequence.new(keys), Parent = swatch })
			end
			local b = button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 34), Text = "", ZIndex = 9, Parent = c }, function()
				remotes.Shop:FireServer("Buy", kind, item.Id)
			end)
			table.insert(cosmeticButtons, { Button = b, Kind = kind, Item = item })
		end
	end
	cosmeticCards("Trail", Config.Trails, "TRAILS")
	cosmeticCards("Ski", Config.Skis, "SKIS")
	cosmeticCards("Buddy", Progression.Buddies, "BUDDIES")

	local function refreshShop()
		for key, b in passButtons do
			local owned = player:GetAttribute("Pass_" .. key)
			b.Text = if owned then "OWNED" else `R$ {Config.GamePasses[key].PriceHint}`
			b.BackgroundColor3 = if owned then T.PanelLight else T.Mint
			b.TextColor3 = if owned then T.Muted else T.Navy
		end
		for _, entry in cosmeticButtons do
			local owned = player:GetAttribute(`Owns{entry.Kind}_{entry.Item.Id}`)
			local equipped = player:GetAttribute(entry.Kind) == entry.Item.Id
			local b = entry.Button
			if equipped then
				b.Text, b.BackgroundColor3, b.TextColor3 = "EQUIPPED", T.Ice, T.Navy
			elseif owned then
				b.Text, b.BackgroundColor3, b.TextColor3 = "EQUIP", T.PanelLight, T.Snow
			elseif entry.Item.Pass then
				b.Text, b.BackgroundColor3, b.TextColor3 = "UNLOCK", T.Gold, T.Navy
			elseif entry.Item.Spin then
				b.Text, b.BackgroundColor3, b.TextColor3 = "SPIN ONLY", T.PanelLight, T.Muted
			else
				b.Text, b.BackgroundColor3, b.TextColor3 = "BUY", T.Mint, T.Navy
			end
		end
	end
	player.AttributeChanged:Connect(refreshShop)
	refreshShop()
	showTab("PASSES")
	local function openShop(tab: string?)
		showTab(tab or "PASSES")
		open(shopWindow)
	end
	UI.OpenShop = openShop

	------------------------------------------------ Stage-Auswahl

	local stageWindow, stageBody = window("STAGES", 700, 420)
	local stageGrid = scrollList(stageBody, UDim2.fromOffset(122, 118))
	local stageButtons = {}
	for i, def in Config.Stages do
		local c = panel({ BackgroundColor3 = T.PanelLight, LayoutOrder = i, ZIndex = 8, Parent = stageGrid })
		text({ Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 26), Text = tostring(i), TextColor3 = def.Accent, FontFace = HEAVY, ZIndex = 9, Parent = c })
		text({ Position = UDim2.fromOffset(8, 36), Size = UDim2.new(1, -16, 0, 16), Text = string.upper(def.Name), FontFace = BOLD, ZIndex = 9, Parent = c })
		local pb = text({ Position = UDim2.fromOffset(8, 54), Size = UDim2.new(1, -16, 0, 16), Text = "", TextColor3 = T.Muted, FontFace = MONO, ZIndex = 9, Parent = c })
		local medal = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(46, 16), Text = "", BackgroundTransparency = 0, BackgroundColor3 = T.Navy, FontFace = HEAVY, Visible = false, ZIndex = 9, Parent = c })
		corner(5).Parent = medal
		local b = button({ Position = UDim2.new(0, 8, 1, -38), Size = UDim2.new(1, -16, 0, 30), Text = "GO", Color = T.Ice, TextColor3 = T.Navy, ZIndex = 9, Parent = c }, function()
			if i <= (player:GetAttribute("MaxStage") or 1) then
				remotes.Run:FireServer("Goto", i)
				closeAll()
			else
				remotes.Purchase:FireServer("Product", "SkipStage")
			end
		end)
		stageButtons[i] = { Button = b, Best = pb, Medal = medal }
	end
	local function refreshStages()
		local max = player:GetAttribute("MaxStage") or 1
		for i, entry in stageButtons do
			local best = player:GetAttribute("StageBest_" .. i)
			entry.Best.Text = if best then "PB " .. Format.Run(best) else (if i <= max then "no time yet" else "locked")
			entry.Button.Text = if i <= max then "GO" else `SKIP R$ {Config.DevProducts.SkipStage.PriceHint}`
			entry.Button.BackgroundColor3 = if i <= max then T.Ice else T.Gold
		end
	end
	player.AttributeChanged:Connect(refreshStages)
	refreshStages()
	-- Medaillen kommen ueber ProgressSync (Extras.luau ruft das auf)
	function UI.SetStageMedals(medals)
		for i, entry in stageButtons do
			local tier = medals[tostring(i)] or 0
			local def = Progression.Medals[tier]
			entry.Medal.Visible = def ~= nil
			if def then
				entry.Medal.Text = string.upper(def.Name)
				entry.Medal.TextColor3 = def.Color
			end
		end
	end

	------------------------------------------------ Bestenliste

	local topWindow, topBody = window("WORLD RECORDS", 640, 460)
	local topList = scrollList(topBody)
	local function refreshTop()
		for _, child in topList:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local ok, data = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:FindFirstChild("Leaderboard") and ReplicatedStorage.Leaderboard.Value or "{}")
		if not ok then
			data = {}
		end
		local order = 0
		local function line(message: string, color: Color3, font)
			order += 1
			text({ Size = UDim2.new(1, 0, 0, 24), Text = message, TextColor3 = color, FontFace = font or MONO, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, ZIndex = 8, Parent = topList })
		end
		line("TOP 10  -  FULL MAP", T.Ice, HEAVY)
		local map = data.Map or {}
		if #map == 0 then
			line("No times yet. Be the first!", T.Muted)
		end
		for i, row in map do
			line(string.format("%2d. %-20s %s", i, string.sub(row.Name, 1, 20), Format.Run(row.Time)), if row.UserId == player.UserId then T.Mint elseif i == 1 then T.Gold else T.Snow)
		end
		local best = player:GetAttribute("BestTime") or 0
		line("YOUR BEST: " .. (if best > 0 then Format.Run(best) else "-"), T.Mint)
		line("STAGE RECORDS", T.Aurora, HEAVY)
		for i, def in Config.Stages do
			local record = (data.Stages or {})[tostring(i)]
			local mine = player:GetAttribute("StageBest_" .. i)
			line(string.format("S%-2d %-14s %-10s you %s", i, string.sub(string.upper(def.Name), 1, 14), if record then Format.Run(record.Time) else "-", if mine then Format.Run(mine) else "-"), T.Snow)
		end
	end

	------------------------------------------------ Knoepfe

	local leftBar = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(84, 330), BackgroundTransparency = 1, Parent = gui })
	UI.LeftBar = leftBar
	create("UIListLayout", { Padding = UDim.new(0, 8), Parent = leftBar })
	local function sideButton(label: string, color: Color3, order: number, onClick)
		return button({ Size = UDim2.fromOffset(84, 46), Text = label, Color = color, TextColor3 = T.Navy, LayoutOrder = order, Parent = leftBar }, onClick)
	end
	sideButton("SHOP", T.Gold, 1, function()
		openShop("PASSES")
	end)
	sideButton("STAGES", T.Ice, 2, function()
		open(stageWindow)
	end)
	sideButton("TOP 10", T.Mint, 3, function()
		refreshTop()
		open(topWindow)
	end)
	local adButton = sideButton("FREE", T.Aurora, 4, function()
		remotes.WatchAd:FireServer()
	end)
	adButton.Visible = false
	local dailyButton = sideButton("DAILY", T.Gold, 5, function()
		UI.ShowDaily()
	end)
	dailyButton.Visible = false
	-- Update 2: Menue fuer Aufgaben, Erfolge, Profil, Gluecks-Schneeball, Codes und Einstellungen (Extras.luau)
	UI.MoreButton = sideButton("MORE", T.Mint, 6, function()
		if UI.OpenMore then
			UI.OpenMore()
		end
	end)

	-- Freiwillige Video-Werbung: Knopf nur zeigen, wenn Roblox gerade eine Werbung bereit hat
	task.spawn(function()
		while gui.Parent do
			local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			local available = ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
			adButton.Visible = available == true
			adCard.Visible = available == true
			task.wait(30)
		end
	end)
	local _ = adShopButton

	local rightBar = create("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.45, 0), Size = UDim2.fromOffset(96, 300), BackgroundTransparency = 1, Parent = gui })
	create("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = rightBar })
	local function actionButton(label: string, order: number, onClick)
		return button({ Size = UDim2.fromOffset(96, 40), Text = label, Color = T.PanelLight, LayoutOrder = order, Parent = rightBar }, onClick)
	end
	local restartButton = actionButton("RESTART", 1, function()
		remotes.Run:FireServer("Restart")
	end)
	actionButton("STAGE", 2, function()
		remotes.Run:FireServer("RestartStage")
	end)
	local saveButton = actionButton("SAVE CP", 3, function()
		if Movement.SaveCheckpoint() then
			toast("Checkpoint saved (practice run)", T.Mint, 1.5)
		end
	end)
	local loadButton = actionButton("LOAD CP", 4, function()
		if not Movement.LoadCheckpoint() and player:GetAttribute("Pass_Practice") then
			toast("Save a checkpoint in this stage first", T.Red, 1.5)
		end
	end)
	local lobbyButton = actionButton("LOBBY", 5, function()
		remotes.Run:FireServer("Lobby")
	end)
	local function refreshButtons()
		local owned = player:GetAttribute("Pass_Practice")
		saveButton.Text = if owned then "SAVE CP" else "SAVE CP  R$"
		loadButton.Text = if owned then "LOAD CP" else "LOAD CP  R$"
		local inStage = (player:GetAttribute("Stage") or 0) > 0
		lobbyButton.Visible = inStage
		saveButton.Visible = inStage
		loadButton.Visible = inStage
		restartButton.Text = if inStage then "RESTART" else "PLAY"
		dailyButton.Visible = player:GetAttribute("DailyReward") ~= nil
	end
	player.AttributeChanged:Connect(refreshButtons)
	refreshButtons()

	-- Sprungknopf fuer Handys (gedrueckt halten = Bunny-Hopping)
	if UserInputService.TouchEnabled then
		local jump = create("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -30), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = T.Ice, BackgroundTransparency = 0.25, Text = "JUMP", TextColor3 = T.Navy, FontFace = HEAVY, TextScaled = true, AutoButtonColor = false, Parent = gui })
		corner(48).Parent = jump
		create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = jump })
		jump.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				Movement.JumpHeld = true
			end
		end)
		jump.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				Movement.JumpHeld = false
			end
		end)
	end

	-- Tastatur-Hilfe am PC
	if not touch then
		UI.Hints = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -10), Size = UDim2.fromOffset(460, 16), Text = "A/D + MOUSE: surf    SPACE: jump    R: restart stage    1/2: checkpoint    V: view    CTRL: cursor", TextColor3 = T.Muted, FontFace = MEDIUM, TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 0.2, Parent = gui })
	end

	------------------------------------------------ Ergebnis nach Stage/Map

	local resultCard = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(440, 174), Visible = false, BackgroundTransparency = 0.05, Radius = 16, Parent = gui })
	local resultTitle = text({ Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 30), Text = "", FontFace = HEAVY, TextColor3 = T.Ice, Parent = resultCard })
	local resultTime = text({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 46), Text = "", FontFace = MONO, Parent = resultCard })
	local resultSub = text({ Position = UDim2.fromOffset(16, 98), Size = UDim2.new(1, -32, 0, 20), Text = "", FontFace = MONO, TextColor3 = T.Muted, Parent = resultCard })
	local resultFlakes = text({ Position = UDim2.fromOffset(16, 120), Size = UDim2.new(1, -32, 0, 20), Text = "", FontFace = HEAVY, TextColor3 = T.Gold, Parent = resultCard })
	local resultMedal = text({ Position = UDim2.fromOffset(16, 144), Size = UDim2.new(1, -32, 0, 20), Text = "", FontFace = HEAVY, Parent = resultCard })
	local resultToken = 0
	local finishSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, PlaybackSpeed = 1.3, Parent = SoundService })
	remotes.Result.OnClientEvent:Connect(function(result)
		resultToken += 1
		local token = resultToken
		finishSound:Play()
		if result.MapComplete then
			resultTitle.Text = if result.RunPB then "MAP COMPLETE  -  NEW PERSONAL BEST!" else "MAP COMPLETE!"
			resultTitle.TextColor3 = if result.RunPB then T.Gold else T.Mint
			resultTime.Text = if result.RunTime then Format.Run(result.RunTime) else "unranked run"
			local delta = if result.RunTime and result.PreviousRunBest then result.RunTime - result.PreviousRunBest else nil
			resultSub.Text = if delta then string.format("%s%.3f vs PB", if delta < 0 then "-" else "+", math.abs(delta)) else "Next run starts in a moment..."
		else
			resultTitle.Text = `STAGE {result.Stage} CLEAR` .. (if result.StagePB then "  -  PB!" else "")
			resultTitle.TextColor3 = if result.StagePB then T.Gold else T.Ice
			resultTime.Text = Format.Run(result.StageTime)
			local delta = if result.PreviousBest then result.StageTime - result.PreviousBest else nil
			resultSub.Text = if not result.Clean then "practice (not saved)" elseif delta then string.format("%s%.3f vs PB", if delta < 0 then "-" else "+", math.abs(delta)) else "first time!"
		end
		-- Zwischenzeit im Lauf gegen den Bestzeit-Lauf (Update 2)
		if result.SplitDelta and not result.MapComplete then
			resultSub.Text ..= string.format("   SPLIT %s%.3f", if result.SplitDelta < 0 then "-" else "+", math.abs(result.SplitDelta))
		end
		local medalDef = Progression.Medals[result.Medal or 0]
		if medalDef then
			local gold = Progression.GoldTimes[result.Stage]
			resultMedal.Text = if result.NewMedal
				then `NEW {string.upper(medalDef.Name)} MEDAL!`
				else `{medalDef.Name} medal` .. (if result.Medal < 3 and gold then `   (Gold: {Format.Run(gold)})` else "")
			resultMedal.TextColor3 = medalDef.Color
		else
			resultMedal.Text = if result.Clean == false then "Medals need a clean run" else ""
			resultMedal.TextColor3 = T.Muted
		end
		resultFlakes.Text = `+{Format.Number(result.Flakes or 0)} Snowflakes`
		resultCard.Visible = true
		task.delay(if result.MapComplete then 5 else 2.4, function()
			if token == resultToken then
				resultCard.Visible = false
			end
		end)
	end)

	------------------------------------------------ Tagesbelohnung und Angebote

	local dailyWindow, dailyBody = window("DAILY REWARD", 460, 260)
	local dailyText = text({ Size = UDim2.new(1, 0, 0, 80), Text = "", TextWrapped = true, ZIndex = 8, Parent = dailyBody })
	button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(220, 48), Text = "CLAIM", Color = T.Gold, TextColor3 = T.Navy, ZIndex = 8, Parent = dailyBody }, function()
		remotes.ClaimDaily:FireServer()
		closeAll()
	end)
	function UI.ShowDaily()
		local reward = player:GetAttribute("DailyReward")
		if not reward then
			return
		end
		dailyText.Text = `Day {player:GetAttribute("DailyStreak") or 1} of 7\n+{Format.Number(reward)} Snowflakes\nCome back tomorrow for more!`
		open(dailyWindow)
	end

	local offerWindow, offerBody = window("STARTER PACK", 460, 280)
	local offerText = text({ Size = UDim2.new(1, 0, 0, 100), Text = "", TextWrapped = true, ZIndex = 8, Parent = offerBody })
	local offerBuy = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, -90, 1, -6), Size = UDim2.fromOffset(170, 48), Text = "R$ 79", Color = T.Mint, TextColor3 = T.Navy, ZIndex = 8, Parent = offerBody }, function()
		remotes.Purchase:FireServer("Product", "StarterPack")
		closeAll()
	end)
	button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 90, 1, -6), Size = UDim2.fromOffset(170, 48), Text = "NO THANKS", ZIndex = 8, Parent = offerBody }, closeAll)
	local _ = offerBuy
	local function showOffer(kind: string)
		if kind == "StarterPack" and not player:GetAttribute("StarterPack") then
			offerText.Text = "One time only!\n3,000 Snowflakes + exclusive Ice Crystal trail"
			open(offerWindow)
		elseif kind == "Flakes" then
			openShop("SNOWFLAKES")
		end
	end
	player:GetAttributeChangedSignal("ShowOffer"):Connect(function()
		local kind = player:GetAttribute("ShowOffer")
		if kind then
			player:SetAttribute("ShowOffer", nil)
			-- Nicht mitten im Lauf stoeren
			while (player:GetAttribute("Stage") or 0) > 0 and Movement.GetStageTime() do
				task.wait(1)
			end
			showOffer(kind)
		end
	end)

	------------------------------------------------ Erklaerung beim ersten Besuch

	local tutorialWindow, tutorialBody = window("HOW TO SURF", 560, 330)
	text({
		Size = UDim2.new(1, 0, 0, 190),
		Text = if touch
			then "1. Push the stick forward to leave the start hut.\n2. SURF ASSIST is on: it keeps you on the ramp and steers to the next one.\n3. Want full control? Push the stick sideways, or turn assist off in MORE > SETTINGS.\n4. Swipe the right side to look around. Faster = higher score!\n5. Fall? You restart the stage. The clock keeps going."
			else "1. Leave the start hut and drop onto the first ramp.\n2. Land on the SIDE of a ramp, never the top.\n3. Hold A or D TOWARD the ramp (not W!) and steer with the mouse.\n4. In the air: strafe + turn the mouse together to gain speed.\n5. Fall? You restart the stage. The clock keeps going.",
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextScaled = false,
		TextSize = 18,
		FontFace = MEDIUM,
		ZIndex = 8,
		Parent = tutorialBody,
	})
	button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(220, 46), Text = "LET'S SURF", Color = T.Ice, TextColor3 = T.Navy, ZIndex = 8, Parent = tutorialBody }, function()
		closeAll()
		if player:GetAttribute("DailyReward") then
			UI.ShowDaily()
		end
	end)
	task.delay(4, function()
		if (player:GetAttribute("Clears") or 0) == 0 then
			open(tutorialWindow)
		elseif player:GetAttribute("DailyReward") then
			UI.ShowDaily()
		end
	end)

	-- Shop-Theke in der Lobby
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
		if prompt:GetAttribute("Opens") == "Shop" then
			openShop("TRAILS")
		end
	end)

	------------------------------------------------ Chat-Tags

	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		if sender then
			local tag = ""
			if sender:GetAttribute("Pass_VIP") then
				tag ..= `<font color="#{T.Gold:ToHex()}">[VIP]</font> `
			end
			local index = sender:GetAttribute("RankIndex") or 1
			local rank = Config.Ranks[index]
			local title = sender:GetAttribute("Title")
			if typeof(title) == "string" and title ~= "" then
				-- Titel aus einem Erfolg statt des Rangs (Update 2)
				tag ..= `<font color="#{T.Mint:ToHex()}">[{title}]</font> `
			elseif rank then
				tag ..= `<font color="#{rank.Color:ToHex()}">[{string.upper(rank.Name)}]</font> `
			end
			props.PrefixText = tag .. message.PrefixText
		end
		return props
	end

	------------------------------------------------ Jeder Frame

	RunService.RenderStepped:Connect(function()
		local stage = player:GetAttribute("Stage") or 0
		local ranked = player:GetAttribute("Ranked")
		local run = Movement.GetRunTime()
		local stageTime = Movement.GetStageTime()
		if stage == 0 then
			stageLabel.Text = "LOBBY  -  walk through DROP IN"
			runLabel.Text = Format.Run(player:GetAttribute("BestTime"))
			subLabel.Text = "YOUR BEST MAP TIME"
			practiceTag.Visible = false
		else
			local def = Config.Stages[stage]
			stageLabel.Text = `STAGE {stage}/{#Config.Stages}  -  {string.upper(def.Name)}`
			practiceTag.Visible = not ranked
			if run and ranked then
				runLabel.Text = Format.Run(run)
			else
				runLabel.Text = if stageTime then Format.Run(stageTime) else "0.000"
			end
			local best = player:GetAttribute("StageBest_" .. stage)
			subLabel.Text = `STAGE {if stageTime then Format.Run(stageTime) else "0.000"}   PB {if best then Format.Run(best) else "-"}`
		end
		local u = Movement.Speed / SurfPhysics.Unit
		speedLabel.Text = tostring(math.floor(u + 0.5))
		local color = speedColor(Movement.Speed)
		speedLabel.TextColor3 = color
		bar.BackgroundColor3 = color
		bar.Size = UDim2.fromScale(math.clamp(u / 3500, 0, 1), 1)
		flakesLabel.Text = "❄ " .. Format.Number(player:GetAttribute("Flakes") or 0)
		local index = player:GetAttribute("RankIndex") or 1
		local rank = Config.Ranks[index] or Config.Ranks[1]
		rankLabel.Text = string.upper(rank.Name)
		rankLabel.TextColor3 = rank.Color
	end)
end

return UI
