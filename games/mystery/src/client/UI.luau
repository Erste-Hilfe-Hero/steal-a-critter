-- Die komplette Oberflaeche im "Midnight"-Stil: HUD, Rollenkarte, Abstimmung, Ergebnis,
-- Faehigkeiten-Knoepfe, Zuschauen, und die Menues (Shop, Kisten, Inventar/Schmiede, Battle Pass,
-- Quests, Gluecksrad, Emotes, Einstellungen/Codes).
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Controls = require(script.Parent.Controls)
local Effects = require(script.Parent.Effects)

local UI = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = remotes:WaitForChild("Request") :: RemoteFunction
local C = Config.Colors

local TITLE = Enum.Font.FredokaOne
local BODY = Enum.Font.BuilderSansBold
local HEAVY = Enum.Font.BuilderSansExtraBold
local LOGO = Enum.Font.LuckiestGuy

local Profile: any = nil
local Role: string? = nil
local RoundState = "Intermission"

---------------------------------------------------------------- Bausteine

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or C.Edge
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.35
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.Parent = parent
	return p
end

local function list(parent: Instance, spacing: number, horizontal: boolean?, align: Enum.HorizontalAlignment?)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, spacing)
	l.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	l.SortOrder = Enum.SortOrder.LayoutOrder
	if align then
		l.HorizontalAlignment = align
	end
	l.VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top
	l.Parent = parent
	return l
end

local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = C.Panel
	f.BorderSizePixel = 0
	for k, v in props or {} do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, size: number, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.Font = BODY
	l.TextColor3 = C.White
	l.TextWrapped = true
	for k, v in props or {} do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local function button(parent: Instance, text: string, color: Color3, props, onClick: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.Text = text
	b.TextSize = 18
	b.Font = HEAVY
	b.TextColor3 = if color == C.Moon or color == C.Green or color == C.Cyan then C.Night else C.White
	b.BorderSizePixel = 0
	for k, v in props or {} do
		(b :: any)[k] = v
	end
	corner(b, 10)
	local s = stroke(b, Color3.new(1, 1, 1), 1.5, 0.75)
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	b.Parent = parent
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
	end)
	if onClick then
		b.Activated:Connect(function()
			Effects.Sound("Click", nil, 1.1, 0.35)
			onClick()
		end)
	end
	return b
end

local function rarityColor(rarity: string): Color3
	local r = Config.Rarities[Config.RarityIndex[rarity] or 1]
	return r and r.Color or C.White
end

local function call(action: string, ...): any
	local ok, result = pcall(Request.InvokeServer, Request, action, ...)
	if not ok then
		return { Ok = false, Error = "Connection problem" }
	end
	return result or { Ok = false }
end

-- 3D-Vorschau eines Skins in einem ViewportFrame
local function preview(parent: Instance, kind: string, id: string, props): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(200, 200, 220)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1, -1)
	for k, v in props or {} do
		(vp :: any)[k] = v
	end
	local model
	if kind == "Knife" then
		model = Skins.Knife(id)
	elseif kind == "Gun" then
		model = Skins.Gun(id)
	elseif kind == "Pet" then
		model = Skins.Pet(id)
	end
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("ParticleEmitter") or d:IsA("Light") then
				d:Destroy()
			end
		end
		model.Parent = vp
		local cf, size = model:GetBoundingBox()
		local camera = Instance.new("Camera")
		local dist = math.max(size.X, size.Y, size.Z) * 1.5 + 0.5
		local angle = if kind == "Gun" then CFrame.Angles(0, math.rad(90), 0) else CFrame.Angles(0, math.rad(35), math.rad(if kind == "Knife" then -35 else 0))
		model:PivotTo(model:GetPivot() * CFrame.new(-cf.Position) * angle)
		cf = model:GetBoundingBox()
		camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, dist * 0.15, -dist), cf.Position)
		camera.FieldOfView = 40
		camera.Parent = vp
		vp.CurrentCamera = camera
	else
		-- Effekte als Symbol
		local item = Config.GetItem(kind, id)
		local l = label(vp, "✦", 40, { Size = UDim2.fromScale(1, 1), TextColor3 = item and item.Color or C.White, Font = TITLE })
		l.TextScaled = true
	end
	vp.Parent = parent
	return vp
end

---------------------------------------------------------------- Wurzel

local gui = Instance.new("ScreenGui")
gui.Name = "MidnightUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local root = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
local scale = Instance.new("UIScale")
scale.Parent = root
local function rescale()
	local size = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.6, 1.3)
	root.Size = UDim2.fromOffset(size.X / scale.Scale, (size.Y - GuiService:GetGuiInset().Y) / scale.Scale)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

---------------------------------------------------------------- Toasts und Banner

local toastHolder = frame(root, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 64), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1 })
list(toastHolder, 6, false, Enum.HorizontalAlignment.Right)

function UI.Toast(text: string, color: Color3?)
	local toast = frame(toastHolder, { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Panel, BackgroundTransparency = 0.08 })
	corner(toast, 17)
	stroke(toast, color or C.Edge, 2, 0.1)
	pad(toast, 8)
	local _l = label(toast, text, 16, { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, TextColor3 = color or C.White, Font = HEAVY })
	local children = toastHolder:GetChildren()
	local count = 0
	for _, child in children do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count > 5 then
		for _, child in children do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
	task.delay(4, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

local banner = label(root, "", 30, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 110), Size = UDim2.fromOffset(760, 44), Font = LOGO, TextTransparency = 1, TextScaled = true })
local bannerStroke = Instance.new("UIStroke")
bannerStroke.Thickness = 3
bannerStroke.Color = C.Night
bannerStroke.Transparency = 1
bannerStroke.Parent = banner
local bannerToken = 0
function UI.Banner(text: string, color: Color3?)
	bannerToken += 1
	local token = bannerToken
	banner.Text = text
	banner.TextColor3 = color or C.Moon
	banner.TextTransparency = 0
	bannerStroke.Transparency = 0
	banner.Size = UDim2.fromOffset(700, 40)
	TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(760, 44) }):Play()
	task.delay(4, function()
		if token == bannerToken then
			TweenService:Create(banner, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(bannerStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
	end)
end

---------------------------------------------------------------- Kaufen

local function productKey(key: string): (number, number)
	local passKey = key:match("^Pass_(.+)$")
	local id = ReplicatedStorage:GetAttribute("ProductId_" .. (passKey or key)) or 0
	local def = if passKey then Config.GamePasses[passKey] else Config.DevProducts[key]
	local price = ReplicatedStorage:GetAttribute("Price_" .. (passKey or key)) or (def and def.Price) or 0
	return id, price
end

function UI.Buy(key: string)
	local id = productKey(key)
	if id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, id)
	elseif RunService:IsStudio() then
		local passKey = key:match("^Pass_(.+)$")
		remotes.FakePurchase:FireServer(if passKey then "Pass" else "Product", passKey or key)
	else
		UI.Toast("This item is coming soon!", C.Orange)
	end
end

local function hasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

---------------------------------------------------------------- Oberes HUD

local top = frame(root, { Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(420, 44), BackgroundTransparency = 1 })
list(top, 8, true)

local function pill(parent: Instance, width: number, color: Color3): (Frame, TextLabel)
	local p = frame(parent, { Size = UDim2.fromOffset(width, 40), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.05 })
	corner(p, 20)
	stroke(p, color, 2, 0.2)
	local icon = frame(p, { Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = color })
	corner(icon, 15)
	local text = label(p, "", 20, { Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -48, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Font = HEAVY, TextWrapped = false })
	return p, text
end

local coinPill, coinText = pill(top, 150, C.Moon)
label(coinPill:FindFirstChildOfClass("Frame") :: Frame, "$", 20, { Size = UDim2.fromScale(1, 1), Font = LOGO, TextColor3 = C.Night })
local levelPill, levelText = pill(top, 190, C.Cyan)
label(levelPill:FindFirstChildOfClass("Frame") :: Frame, "★", 18, { Size = UDim2.fromScale(1, 1), Font = TITLE, TextColor3 = C.Night })
local xpBack = frame(levelPill, { Position = UDim2.new(0, 42, 1, -9), Size = UDim2.new(1, -54, 0, 5), BackgroundColor3 = C.Panel2 })
corner(xpBack, 3)
local xpFill = frame(xpBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Cyan })
corner(xpFill, 3)
levelText.Position = UDim2.fromOffset(42, -4)

-- Status in der Mitte
local status = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(340, 44), BackgroundColor3 = C.Night, BackgroundTransparency = 0.1 })
corner(status, 22)
stroke(status, C.Moon, 2, 0.15)
local statusTitle = label(status, "", 15, { Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.Muted, Font = HEAVY })
local statusText = label(status, "", 22, { Position = UDim2.fromOffset(0, 17), Size = UDim2.new(1, 0, 0, 24), Font = TITLE, TextColor3 = C.Moon })
local modifierChip = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Purple, Visible = false })
corner(modifierChip, 13)
pad(modifierChip, 4)
local modifierText = label(modifierChip, "", 15, { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, Font = HEAVY })

-- Linke Menueleiste
local menu = frame(root, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 10), Size = UDim2.fromOffset(64, 420), BackgroundTransparency = 1 })
local menuList = list(menu, 8)
menuList.VerticalAlignment = Enum.VerticalAlignment.Center
local menuBadges = {}
local openWindow: (name: string) -> ()

local function menuButton(name: string, icon: string, caption: string, color: Color3)
	local b = button(menu, "", C.Panel, { Size = UDim2.fromOffset(60, 52) }, function()
		openWindow(name)
	end)
	stroke(b, color, 2, 0.15)
	label(b, icon, 24, { Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 2), Font = TITLE })
	label(b, caption, 11, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -17), Font = HEAVY, TextColor3 = color })
	local badge = frame(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = C.Red, Visible = false })
	corner(badge, 8)
	label(badge, "!", 12, { Size = UDim2.fromScale(1, 1), Font = HEAVY })
	menuBadges[name] = badge
end
menuButton("Shop", "🛒", "SHOP", C.Moon)
menuButton("Crates", "🎁", "CRATES", C.Red)
menuButton("Inventory", "🔪", "ITEMS", C.Cyan)
menuButton("Pass", "🌙", "PASS", C.Purple)
menuButton("Quests", "📜", "QUESTS", C.Green)
menuButton("Spin", "🎡", "SPIN", C.Orange)
menuButton("Emotes", "💃", "EMOTES", C.Pink)
menuButton("Settings", "⚙️", "MORE", C.Muted)

-- Gratis-Muenzen per Video (unten links)
local adButton = button(root, "FREE COINS ▶", C.Green, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.fromOffset(150, 38), TextSize = 16 }, function()
	remotes.WatchAd:FireServer()
end)

---------------------------------------------------------------- Runden-HUD

local roleBadge = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76), Size = UDim2.fromOffset(240, 40), BackgroundColor3 = C.Panel, Visible = false })
corner(roleBadge, 20)
local roleStroke = stroke(roleBadge, C.Green, 2.5, 0)
local roleText = label(roleBadge, "", 22, { Size = UDim2.fromScale(1, 1), Font = TITLE })

local bag = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -122), Size = UDim2.fromOffset(200, 24), BackgroundColor3 = C.Night, BackgroundTransparency = 0.15, Visible = false })
corner(bag, 12)
local bagFill = frame(bag, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Moon })
corner(bagFill, 12)
local bagText = label(bag, "", 15, { Size = UDim2.fromScale(1, 1), Font = HEAVY, ZIndex = 2 })

local stamina = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -150), Size = UDim2.fromOffset(160, 8), BackgroundColor3 = C.Night, Visible = false })
corner(stamina, 4)
local staminaFill = frame(stamina, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cyan })
corner(staminaFill, 4)

-- Faehigkeiten-Knoepfe (rechts unten, gross fuer Handys)
local abilityBar = frame(root, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, if isTouch then -150 else -14), Size = UDim2.fromOffset(320, 70), BackgroundTransparency = 1, Visible = false })
local abilityList = list(abilityBar, 8, true)
abilityList.HorizontalAlignment = Enum.HorizontalAlignment.Right
local abilityButtons = {}

local function abilityButton(name: string, text: string, key: string, color: Color3, action: () -> ())
	local b = button(abilityBar, "", C.Panel, { Size = UDim2.fromOffset(70, 70) }, action)
	stroke(b, color, 2.5, 0)
	label(b, text, 14, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 12), Font = HEAVY, TextColor3 = color })
	if not isTouch then
		label(b, key, 12, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20), TextColor3 = C.Muted })
	end
	local shade = frame(b, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, ZIndex = 3 })
	corner(shade, 10)
	local count = label(b, "", 22, { Size = UDim2.fromScale(1, 1), Font = TITLE, ZIndex = 4 })
	abilityButtons[name] = { Button = b, Shade = shade, Count = count }
end

local function buildAbilities()
	for _, child in abilityBar:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	table.clear(abilityButtons)
	if Role == "Murderer" then
		abilityButton("Throw", "THROW", "T", C.Red, Controls.Throw)
		abilityButton("Dash", "DASH", "Q", C.Orange, function()
			Controls.Ability("Dash")
		end)
		abilityButton("Cloak", "SHADOW", "F", C.Purple, function()
			Controls.Ability("Cloak")
		end)
		abilityButton("Trap", "TRAP", "R", C.Pink, function()
			Controls.Ability("Trap")
		end)
	elseif Role == "Sheriff" or Role == "Hero" then
		abilityButton("Scan", "SCAN", "Q", C.Blue, function()
			Controls.Ability("Scan")
		end)
		abilityButton("Sprint", "SPRINT", "Shift", C.Cyan, function()
			Controls.Ability("Sprint")
		end)
	elseif Role == "Innocent" then
		abilityButton("Sprint", "SPRINT", "Shift", C.Cyan, function()
			Controls.Ability("Sprint")
		end)
	end
end

-- Zuschauen + Ghost Guess
local spectateBar = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(460, 48), BackgroundTransparency = 1, Visible = false })
local spectateList = list(spectateBar, 8, true)
spectateList.HorizontalAlignment = Enum.HorizontalAlignment.Center
button(spectateBar, "◀", C.Panel2, { Size = UDim2.fromOffset(44, 44), LayoutOrder = 1 }, function()
	Controls.Spectate(-1)
end)
local spectateName = button(spectateBar, "SPECTATE", C.Panel, { Size = UDim2.fromOffset(190, 44), LayoutOrder = 2 }, function()
	if Controls.Spectating then
		Controls.StopSpectate()
	else
		Controls.Spectate(1)
	end
end)
button(spectateBar, "▶", C.Panel2, { Size = UDim2.fromOffset(44, 44), LayoutOrder = 3 }, function()
	Controls.Spectate(1)
end)
local guessButton = button(spectateBar, "GHOST GUESS", C.Purple, { Size = UDim2.fromOffset(140, 44), LayoutOrder = 4, TextSize = 15 }, function()
	openWindow("Guess")
end)

---------------------------------------------------------------- Abstimmung (Lobby)

local votePanel = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(560, 118), BackgroundTransparency = 1, Visible = false })
local _voteTitle = label(votePanel, "VOTE FOR THE NEXT MAP", 16, { Size = UDim2.new(1, 0, 0, 20), Font = HEAVY, TextColor3 = C.Moon })
local voteRow = frame(votePanel, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1 })
local voteRowList = list(voteRow, 10, true)
voteRowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
local myVote = nil
local voteKey = ""

local THEME_COLORS = { Manor = Color3.fromRGB(150, 90, 200), Arcade = Color3.fromRGB(255, 80, 200), Lodge = Color3.fromRGB(120, 200, 255), School = Color3.fromRGB(110, 200, 120), Lab = Color3.fromRGB(80, 220, 255) }

local function refreshVotes()
	local options = HttpService:JSONDecode(ReplicatedStorage:GetAttribute("MapOptions") or "[]")
	local counts = HttpService:JSONDecode(ReplicatedStorage:GetAttribute("Votes") or "{}")
	local key = table.concat(options, ",")
	if key ~= voteKey then
		voteKey = key
		myVote = nil
		for _, child in voteRow:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for i, index in options do
			local def = Config.Maps[index]
			local color = THEME_COLORS[def.Theme] or C.Moon
			local card = button(voteRow, "", C.Panel, { Size = UDim2.fromOffset(170, 86), LayoutOrder = i, Name = "Vote" .. index }, function()
				local result = call("Vote", index)
				if result.Ok then
					myVote = index
					refreshVotes()
				end
			end)
			stroke(card, color, 2, 0.2)
			label(card, def.Name, 19, { Size = UDim2.new(1, -10, 0, 44), Position = UDim2.fromOffset(5, 6), Font = TITLE, TextColor3 = color })
			label(card, "", 15, { Name = "Count", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -28), Font = HEAVY, TextColor3 = C.Muted })
		end
	end
	for _, child in voteRow:GetChildren() do
		if child:IsA("TextButton") then
			local index = tonumber(child.Name:sub(5))
			local n = counts[tostring(index)] or 0
			local countLabel = child:FindFirstChild("Count") :: TextLabel
			countLabel.Text = `{n} vote{if n == 1 then "" else "s"}` .. (if myVote == index then "  ✓" else "")
			countLabel.TextColor3 = if myVote == index then C.Moon else C.Muted
		end
	end
end
ReplicatedStorage:GetAttributeChangedSignal("MapOptions"):Connect(refreshVotes)
ReplicatedStorage:GetAttributeChangedSignal("Votes"):Connect(refreshVotes)

local oddsChip = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Panel, Visible = false })
corner(oddsChip, 13)
pad(oddsChip, 4)
stroke(oddsChip, C.Edge, 1.5, 0.3)
local oddsText = label(oddsChip, "", 14, { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, Font = HEAVY, RichText = true })

---------------------------------------------------------------- Overlays

local overlay = frame(root, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 })

local function fadeOut(f: GuiObject, delay: number)
	task.delay(delay, function()
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.35), { Position = f.Position + UDim2.fromOffset(0, -20) }):Play()
			for _, d in f:GetDescendants() do
				if d:IsA("TextLabel") then
					TweenService:Create(d, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
				elseif d:IsA("Frame") then
					TweenService:Create(d, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
				elseif d:IsA("UIStroke") then
					TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
				end
			end
			if f:IsA("Frame") then
				TweenService:Create(f, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			end
			task.wait(0.4)
			f:Destroy()
		end
	end)
end

local function roleCard(role: string, modifier: string?, map: string?)
	local def = Config.Roles[role]
	local card = frame(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(440, 230), BackgroundColor3 = C.Night, BackgroundTransparency = 0.05 })
	corner(card, 22)
	stroke(card, def.Color, 4, 0)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(C.Panel, C.Night)
	gradient.Rotation = 90
	gradient.Parent = card
	label(card, "YOU ARE THE", 20, { Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24), Font = HEAVY, TextColor3 = C.Muted })
	local name = label(card, string.upper(def.Name), 58, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 70), Font = LOGO, TextColor3 = def.Color })
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = C.Night
	s.Parent = name
	label(card, def.Goal, 20, { Position = UDim2.fromOffset(20, 122), Size = UDim2.new(1, -40, 0, 50), TextColor3 = C.White })
	if map then
		label(card, map .. (if modifier and modifier ~= "" then "  •  " .. modifier else ""), 16, { Position = UDim2.new(0, 0, 1, -40), Size = UDim2.new(1, 0, 0, 24), Font = HEAVY, TextColor3 = C.Moon })
	end
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.6
	uiScale.Parent = card
	TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Effects.Sound("Ping", nil, if role == "Murderer" then 0.6 elseif role == "Sheriff" then 1 else 1.3, 0.7)
	fadeOut(card, 4)
end

local function popup(title: string, text: string, color: Color3, duration: number?)
	local card = frame(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(380, 110), BackgroundColor3 = C.Night, BackgroundTransparency = 0.05 })
	corner(card, 18)
	stroke(card, color, 3, 0)
	label(card, title, 30, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 40), Font = LOGO, TextColor3 = color })
	label(card, text, 18, { Position = UDim2.fromOffset(16, 56), Size = UDim2.new(1, -32, 0, 44), TextColor3 = C.White })
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.5
	uiScale.Parent = card
	TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	fadeOut(card, duration or 3)
end

-- Ergebnis-Bildschirm
local function showResults(info)
	local murdererWon = info.Winner == "Murderer"
	local color = if murdererWon then C.Red else C.Green
	local card = frame(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(500, 300), BackgroundColor3 = C.Night, BackgroundTransparency = 0.04 })
	corner(card, 22)
	stroke(card, color, 4, 0)
	local title = label(card, if murdererWon then "MURDERER WINS" else "INNOCENTS WIN", 46, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 54), Font = LOGO, TextColor3 = color })
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = C.Night
	s.Parent = title
	label(card, info.Reason, 18, { Position = UDim2.fromOffset(20, 70), Size = UDim2.new(1, -40, 0, 24), TextColor3 = C.Muted })
	local rows = frame(card, { Position = UDim2.fromOffset(30, 104), Size = UDim2.new(1, -60, 0, 140), BackgroundTransparency = 1 })
	list(rows, 6)
	local function row(name: string, value: string, c: Color3)
		local r = frame(rows, { Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.Panel })
		corner(r, 8)
		label(r, name, 16, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted, Font = HEAVY })
		label(r, value, 18, { Position = UDim2.new(0.4, 0, 0, 0), Size = UDim2.new(0.6, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = c, Font = HEAVY })
	end
	row("Murderer", table.concat(info.Murderers, ", "), C.Red)
	row("Sheriff", if #info.Sheriffs > 0 then table.concat(info.Sheriffs, ", ") else "-", C.Blue)
	if info.Hero then
		row("Hero", info.Hero, C.Moon)
	end
	if info.MVP then
		row("MVP", `{info.MVP.Name}  ({info.MVP.Coins} coins{if info.MVP.KOs > 0 then ", " .. info.MVP.KOs .. " KOs" else ""})`, C.Moon)
	end
	local reward = label(card, "", 20, { Name = "Reward", Position = UDim2.new(0, 0, 1, -44), Size = UDim2.new(1, 0, 0, 30), Font = TITLE, TextColor3 = C.Cyan })
	UI.ResultCard = card
	UI.ResultReward = reward
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.6
	uiScale.Parent = card
	TweenService:Create(uiScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	fadeOut(card, Config.Round.ResultsTime - 1)
end

-- Kaufangebot rechts
local function showOffer(key: string)
	local passKey = key:match("^Pass_(.+)$")
	local name, text
	if passKey then
		local pass = Config.GamePasses[passKey]
		name, text = pass.Name, pass.Text
	else
		local product = Config.DevProducts[key]
		if not product then
			return
		end
		name = product.ProductName
		text = if key == "StarterPack" then "One time only: 2,500 coins + Starlight knife + Starshot blaster!"
			elseif key == "MurdererTicket" then "Be the MURDERER in your next round!"
			elseif key == "XPBoost" then "Double XP for 30 minutes!"
			else ""
	end
	local _, price = productKey(key)
	local card = frame(overlay, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(250, 180), BackgroundColor3 = C.Night })
	corner(card, 18)
	stroke(card, C.Moon, 3, 0)
	label(card, "SPECIAL OFFER", 14, { Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 18), Font = HEAVY, TextColor3 = C.Pink })
	label(card, name, 24, { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 30), Font = TITLE, TextColor3 = C.Moon })
	label(card, text, 16, { Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 0, 56) })
	button(card, `BUY  R$ {price}`, C.Green, { Position = UDim2.new(0, 14, 1, -54), Size = UDim2.new(0.6, -14, 0, 40) }, function()
		UI.Buy(key)
		card:Destroy()
	end)
	button(card, "No thanks", C.Panel2, { Position = UDim2.new(0.6, 6, 1, -54), Size = UDim2.new(0.4, -20, 0, 40), TextSize = 14 }, function()
		card:Destroy()
	end)
	task.delay(14, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

---------------------------------------------------------------- Fenster

local windowHolder = frame(root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Visible = false, ZIndex = 30, Active = true })
local window = frame(windowHolder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(720, 440), BackgroundColor3 = C.Night })
corner(window, 20)
stroke(window, C.Edge, 2, 0.1)
local windowGradient = Instance.new("UIGradient")
windowGradient.Color = ColorSequence.new(C.Panel, C.Night)
windowGradient.Rotation = 90
windowGradient.Parent = window
local windowTitle = label(window, "", 30, { Position = UDim2.fromOffset(22, 10), Size = UDim2.new(1, -120, 0, 40), Font = LOGO, TextColor3 = C.Moon, TextXAlignment = Enum.TextXAlignment.Left })
local _closeButton = button(window, "✕", C.Red, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Size = UDim2.fromOffset(38, 38), TextSize = 20 }, function()
	windowHolder.Visible = false
	UI.Window = nil
end)
local tabsRow = frame(window, { Position = UDim2.fromOffset(20, 54), Size = UDim2.new(1, -40, 0, 34), BackgroundTransparency = 1 })
list(tabsRow, 6, true)
local body = frame(window, { Position = UDim2.fromOffset(20, 96), Size = UDim2.new(1, -40, 1, -112), BackgroundTransparency = 1, ClipsDescendants = true })

UI.Window = nil :: string?
UI.Guessed = false
UI.ResultCard = nil :: Frame?
UI.ResultReward = nil :: TextLabel?
UI.Tab = {} :: { [string]: string }
local builders = {}

local function clear(f: Instance)
	for _, child in f:GetChildren() do
		if not child:IsA("UIListLayout") or f ~= body then
			child:Destroy()
		end
	end
end

local function scroller(parent: Instance, props): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Size = UDim2.fromScale(1, 1)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 6
	s.ScrollBarImageColor3 = C.Edge
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	for k, v in props or {} do
		(s :: any)[k] = v
	end
	s.Parent = parent
	return s
end

local function grid(parent: Instance, cell: Vector2, gap: number): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	g.CellPadding = UDim2.fromOffset(gap, gap)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = parent
	return g
end

local function setTabs(name: string, tabs: { string }, default: string)
	clear(tabsRow)
	list(tabsRow, 6, true)
	UI.Tab[name] = UI.Tab[name] or default
	if not table.find(tabs, UI.Tab[name]) then
		UI.Tab[name] = default
	end
	for i, tab in tabs do
		local active = UI.Tab[name] == tab
		local b = button(tabsRow, tab, if active then C.Moon else C.Panel2, { Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, TextSize = 15 }, function()
			UI.Tab[name] = tab
			openWindow(name)
		end)
		local p = pad(b, 14)
		p.PaddingTop = UDim.new(0, 0)
		p.PaddingBottom = UDim.new(0, 0)
	end
end

function openWindow(name: string)
	local builder = builders[name]
	if not builder then
		return
	end
	UI.Window = name
	clear(tabsRow)
	clear(body)
	windowHolder.Visible = true
	builder()
	if menuBadges[name] then
		menuBadges[name].Visible = false
	end
end
UI.Open = openWindow

-- Karte fuer einen Robux-Artikel
local function productCard(parent: Instance, key: string, title: string, text: string, color: Color3, order: number, owned: boolean?)
	local _, price = productKey(key)
	local card = frame(parent, { BackgroundColor3 = C.Panel, LayoutOrder = order })
	corner(card, 14)
	stroke(card, color, 2, 0.25)
	label(card, title, 20, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 26), Font = TITLE, TextColor3 = color })
	label(card, text, 14, { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 50), TextColor3 = C.Muted, TextYAlignment = Enum.TextYAlignment.Top })
	if owned then
		label(card, "OWNED", 18, { Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32), Font = HEAVY, TextColor3 = C.Green })
	else
		button(card, `R$ {price}`, C.Green, { Position = UDim2.new(0, 10, 1, -42), Size = UDim2.new(1, -20, 0, 34) }, function()
			UI.Buy(key)
		end)
	end
	return card
end

---------------------------------------------------------------- Shop

builders.Shop = function()
	windowTitle.Text = "SHOP"
	setTabs("Shop", { "Passes", "Coins", "Bundles", "Direct" }, "Passes")
	local tab = UI.Tab.Shop
	local s = scroller(body)
	grid(s, Vector2.new(210, 150), 12)
	if tab == "Passes" then
		local order = 0
		for key, pass in Config.GamePasses do
			order += 1
			productCard(s, "Pass_" .. key, pass.Name, pass.Text, C.Moon, order, hasPass(key))
		end
		productCard(s, "XPBoost", "2x XP 30 min", "Double XP and Battle Pass XP for 30 minutes.", C.Cyan, 20)
	elseif tab == "Coins" then
		for i, key in { "Coins1", "Coins2", "Coins3", "Coins4" } do
			local product = Config.DevProducts[key]
			productCard(s, key, product.ProductName, "Spend on crates and skins in the Direct Shop.", C.Moon, i)
		end
		productCard(s, "MurdererTicket", "Murderer Ticket", "Be the MURDERER in your next round. Guaranteed!", C.Red, 10)
		productCard(s, "SheriffTicket", "Sheriff Ticket", "Be the SHERIFF in your next round. Guaranteed!", C.Blue, 11)
		productCard(s, "Blackout", "Server Blackout", "Turn off all the lights next round. Flashlights only!", C.Purple, 12)
	elseif tab == "Bundles" then
		if not (Profile and Profile.StarterBought) then
			productCard(s, "StarterPack", "Starter Pack", "One time: 2,500 coins + Starlight knife + Starshot blaster", C.Moon, 1)
		end
		productCard(s, "StarBundle", "Starlight Bundle", "Starlight knife, Starshot blaster and Midnight Cat pet", C.Cyan, 2)
		productCard(s, "MoonBundle", "Moonlight Bundle", "EXCLUSIVE Midnight set: Eclipse knife, Lunar Ray, Moonling pet", C.Purple, 3)
	else
		-- Direkt-Shop: jeden normalen Skin fuer Muenzen kaufen (kein Zufall)
		local layout = s:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		layout.CellSize = UDim2.fromOffset(125, 150)
		local order = 0
		for _, kind in Config.ItemKinds do
			for _, item in Config.ItemLists[kind] do
				if not item.Exclusive and item.Rarity ~= "Midnight" and item.Id ~= "Default" then
					order += 1
					local price = Config.Rarities[Config.RarityIndex[item.Rarity]].Price
					local card = frame(s, { BackgroundColor3 = C.Panel, LayoutOrder = Config.RarityIndex[item.Rarity] * 100 + order })
					corner(card, 12)
					stroke(card, rarityColor(item.Rarity), 2, 0.2)
					preview(card, kind, item.Id, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 62) })
					label(card, item.Name, 14, { Position = UDim2.fromOffset(4, 66), Size = UDim2.new(1, -8, 0, 32), Font = HEAVY })
					label(card, item.Rarity .. " " .. kind, 11, { Position = UDim2.fromOffset(4, 96), Size = UDim2.new(1, -8, 0, 14), TextColor3 = rarityColor(item.Rarity) })
					button(card, "$" .. Format.Number(price), C.Moon, { Position = UDim2.new(0, 8, 1, -34), Size = UDim2.new(1, -16, 0, 28), TextSize = 15 }, function()
						local result = call("BuyDirect", kind, item.Id)
						if result.Ok then
							UI.Toast(`Bought {item.Name}!`, rarityColor(item.Rarity))
						else
							UI.Toast(result.Error or "Could not buy", C.Red)
						end
					end)
				end
			end
		end
	end
end

---------------------------------------------------------------- Kisten

local function crateRoll(crate, result)
	-- Einfache Roll-Animation: Namen laufen durch und bleiben beim Gewinn stehen
	local odds = Config.CrateOdds(crate.Id)
	local panel = frame(body, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Night, ZIndex = 5 })
	corner(panel, 14)
	local strip = frame(panel, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(560, 150), BackgroundColor3 = C.Panel, ZIndex = 5, ClipsDescendants = true })
	corner(strip, 14)
	local _marker = frame(panel, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(4, 170), BackgroundColor3 = C.Moon, ZIndex = 8 })
	local inner = frame(strip, { Size = UDim2.fromOffset(40 * 130, 150), BackgroundTransparency = 1, ZIndex = 5 })
	local winIndex = 34
	for i = 1, 40 do
		local entry = if i == winIndex then { Kind = result.Kind, Id = result.Id } else odds[math.random(1, #odds)]
		local item = Config.GetItem(entry.Kind, entry.Id)
		local cell = frame(inner, { Position = UDim2.fromOffset((i - 1) * 130 + 5, 5), Size = UDim2.fromOffset(120, 140), BackgroundColor3 = C.Panel2, ZIndex = 6 })
		corner(cell, 10)
		stroke(cell, rarityColor(item.Rarity), 3, 0)
		preview(cell, entry.Kind, entry.Id, { Size = UDim2.new(1, 0, 0, 90), ZIndex = 6 })
		label(cell, item.Name, 13, { Position = UDim2.fromOffset(4, 92), Size = UDim2.new(1, -8, 0, 40), Font = HEAVY, ZIndex = 7, TextColor3 = rarityColor(item.Rarity) })
	end
	local target = -((winIndex - 1) * 130 + 65 - 280 + math.random(-40, 40))
	local tween = TweenService:Create(inner, TweenInfo.new(4.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(target, 0) })
	tween:Play()
	local ticking = true
	task.spawn(function()
		local lastCell = 0
		while ticking do
			local cellIndex = math.floor(-inner.Position.X.Offset / 130)
			if cellIndex ~= lastCell then
				lastCell = cellIndex
				Effects.Sound("Tick", nil, 1.5, 0.3)
			end
			task.wait()
		end
	end)
	tween.Completed:Wait()
	ticking = false
	local item = Config.GetItem(result.Kind, result.Id)
	Effects.Sound("Ping", nil, 1.2, 0.8)
	label(panel, `{string.upper(item.Rarity)}: {item.Name}!`, 30, { Position = UDim2.new(0, 0, 0.78, 0), Size = UDim2.new(1, 0, 0, 40), Font = LOGO, TextColor3 = rarityColor(item.Rarity), ZIndex = 8 })
	button(panel, "NICE!", C.Green, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(160, 38), ZIndex = 8 }, function()
		panel:Destroy()
	end)
end

builders.Crates = function()
	windowTitle.Text = "CRATES"
	if Profile and Profile.Crates == false then
		label(body, "Crates are not available where you live.\nYou can buy every skin directly in SHOP > Direct.", 20, { Size = UDim2.fromScale(1, 1), TextColor3 = C.Muted })
		return
	end
	local row = frame(body, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	list(row, 10, true)
	for i, crate in Config.Crates do
		local card = frame(row, { Size = UDim2.new(0.25, -8, 1, 0), BackgroundColor3 = C.Panel, LayoutOrder = i })
		corner(card, 14)
		stroke(card, crate.Color, 2, 0.2)
		label(card, crate.Name, 20, { Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 26), Font = TITLE, TextColor3 = crate.Color })
		-- Quoten immer sichtbar
		local oddsList = scroller(card, { Position = UDim2.fromOffset(6, 38), Size = UDim2.new(1, -12, 1, -88) })
		list(oddsList, 2)
		for j, entry in Config.CrateOdds(crate.Id) do
			local item = Config.GetItem(entry.Kind, entry.Id)
			local line = frame(oddsList, { Size = UDim2.new(1, -8, 0, 20), BackgroundTransparency = 1, LayoutOrder = j })
			label(line, item.Name, 13, { Size = UDim2.new(0.68, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarityColor(item.Rarity), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd })
			label(line, string.format("%.1f%%", entry.Chance * 100), 13, { Position = UDim2.fromScale(0.68, 0), Size = UDim2.new(0.32, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.Muted, Font = HEAVY })
		end
		button(card, `OPEN  $${Format.Number(crate.Price)}`, crate.Color, { Position = UDim2.new(0, 8, 1, -44), Size = UDim2.new(1, -16, 0, 36), TextSize = 15 }, function()
			local result = call("OpenCrate", crate.Id)
			if result.Ok then
				task.spawn(crateRoll, crate, result)
			else
				UI.Toast(result.Error or "Could not open", C.Red)
			end
		end)
	end
end

---------------------------------------------------------------- Inventar und Schmiede

local function forgePanel(kind: string)
	local panel = frame(body, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Night, ZIndex = 5 })
	corner(panel, 14)
	label(panel, `FORGE: {Config.ForgeCost} duplicate skins of one rarity = 1 skin of the next rarity (you choose!)`, 16, { Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 4), ZIndex = 6, TextColor3 = C.Muted })
	local s = scroller(panel, { Position = UDim2.fromOffset(10, 48), Size = UDim2.new(1, -20, 1, -100), ZIndex = 6 })
	list(s, 8)
	local inventory = Profile.Inventory[kind] or {}
	for index = 1, #Config.Rarities - 2 do
		local rarity = Config.Rarities[index]
		local spare = 0
		for id, count in inventory do
			local item = Config.GetItem(kind, id)
			if item and item.Rarity == rarity.Id then
				spare += math.max(0, count - 1)
			end
		end
		local nextRarity = Config.Rarities[index + 1]
		local row = frame(s, { Size = UDim2.new(1, -8, 0, 92), BackgroundColor3 = C.Panel, LayoutOrder = index, ZIndex = 6 })
		corner(row, 10)
		label(row, `{rarity.Id} -> {nextRarity.Id}   ({spare}/{Config.ForgeCost} duplicates)`, 15, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarityColor(rarity.Id), Font = HEAVY, ZIndex = 7 })
		local options = frame(row, { Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 56), BackgroundTransparency = 1, ZIndex = 6 })
		list(options, 6, true)
		for _, item in Config.ItemLists[kind] do
			if item.Rarity == nextRarity.Id and not item.Exclusive then
				local b = button(options, item.Name, if spare >= Config.ForgeCost then nextRarity.Color else C.Panel2, { Size = UDim2.fromOffset(130, 50), TextSize = 14, ZIndex = 7 }, function()
					local result = call("Forge", kind, rarity.Id, item.Id)
					if result.Ok then
						panel:Destroy()
					else
						UI.Toast(result.Error or "Cannot forge", C.Red)
					end
				end)
				b.TextColor3 = C.Night
			end
		end
	end
	button(panel, "BACK", C.Panel2, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.fromOffset(140, 36), ZIndex = 7 }, function()
		panel:Destroy()
	end)
end

builders.Inventory = function()
	windowTitle.Text = "INVENTORY"
	setTabs("Inventory", { "Knife", "Gun", "Pet", "Effect", "Titles" }, "Knife")
	if not Profile then
		return
	end
	local tab = UI.Tab.Inventory
	if tab == "Titles" then
		local s = scroller(body)
		grid(s, Vector2.new(160, 50), 10)
		local _none = button(s, "No title", if Profile.Equipped.Title == "" then C.Moon else C.Panel2, { LayoutOrder = 0 }, function()
			call("Title", "")
		end)
		for i, a in Profile.Achievements do
			local owned = Profile.Titles[a.Title] == true
			local b = button(s, if owned then a.Title else "🔒 " .. a.Title, if Profile.Equipped.Title == a.Title then C.Moon elseif owned then C.Panel2 else C.Panel, { LayoutOrder = i }, function()
				if owned then
					call("Title", a.Title)
				else
					UI.Toast(`Unlock with the achievement "{a.Name}"`, C.Orange)
				end
			end)
			b.TextColor3 = if Profile.Equipped.Title == a.Title then C.Night elseif owned then C.White else C.Muted
		end
		return
	end
	local kind = tab
	local s = scroller(body, { Size = UDim2.new(1, 0, 1, -44) })
	grid(s, Vector2.new(120, 138), 10)
	local inventory = Profile.Inventory[kind] or {}
	local ids = {}
	for id, count in inventory do
		if count > 0 and Config.GetItem(kind, id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids, function(a, b)
		local ia, ib = Config.GetItem(kind, a), Config.GetItem(kind, b)
		return Config.RarityIndex[ia.Rarity] > Config.RarityIndex[ib.Rarity]
	end)
	if #ids == 0 then
		label(s, "Nothing here yet. Open crates, use the Direct Shop or level up the Battle Pass!", 16, { Size = UDim2.new(1, 0, 0, 60), TextColor3 = C.Muted })
	end
	local slots = if kind == "Pet" and hasPass("PetSlot") then { "Pet", "Pet2" } else { kind }
	for i, id in ids do
		local item = Config.GetItem(kind, id)
		local equippedSlot
		for _, slot in slots do
			if Profile.Equipped[slot] == id then
				equippedSlot = slot
			end
		end
		local card = button(s, "", C.Panel, { LayoutOrder = i }, function()
			if equippedSlot and (kind == "Pet") then
				call("Equip", equippedSlot, "")
			elseif kind == "Pet" and #slots == 2 and Profile.Equipped.Pet ~= "" then
				call("Equip", "Pet2", id)
			else
				call("Equip", kind, id)
			end
		end)
		stroke(card, if equippedSlot then C.Moon else rarityColor(item.Rarity), if equippedSlot then 3 else 2, 0.1)
		preview(card, kind, id, { Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0, 72) })
		label(card, item.Name, 14, { Position = UDim2.fromOffset(4, 76), Size = UDim2.new(1, -8, 0, 32), Font = HEAVY })
		label(card, item.Rarity, 12, { Position = UDim2.fromOffset(4, 106), Size = UDim2.new(1, -8, 0, 14), TextColor3 = rarityColor(item.Rarity) })
		if (inventory[id] or 0) > 1 then
			label(card, "x" .. inventory[id], 14, { Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(40, 18), TextXAlignment = Enum.TextXAlignment.Left, Font = HEAVY, TextColor3 = C.Moon })
		end
		if equippedSlot then
			label(card, "EQUIPPED", 11, { Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 14), Font = HEAVY, TextColor3 = C.Moon })
		end
	end
	button(body, "FORGE", C.Purple, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(140, 36) }, function()
		forgePanel(kind)
	end)
	label(body, if kind == "Pet" and not hasPass("PetSlot") then "Tip: Extra Pet Slot lets you equip 2 pets!" else "Tap a skin to equip it.", 14, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, -160, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted })
end

---------------------------------------------------------------- Battle Pass

builders.Pass = function()
	windowTitle.Text = string.upper(Config.BattlePass.Name)
	if not Profile then
		return
	end
	local bp = Profile.BP
	local BP = Config.BattlePass
	local header = frame(body, { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	label(header, `TIER {bp.Tier}/{BP.Tiers}`, 22, { Size = UDim2.fromOffset(150, 40), Font = TITLE, TextColor3 = C.Moon, TextXAlignment = Enum.TextXAlignment.Left })
	local barBack = frame(header, { Position = UDim2.fromOffset(150, 14), Size = UDim2.fromOffset(200, 14), BackgroundColor3 = C.Panel2 })
	corner(barBack, 7)
	local into = bp.XP - bp.Tier * BP.XPPerTier
	local fill = frame(barBack, { Size = UDim2.fromScale(if bp.Tier >= BP.Tiers then 1 else math.clamp(into / BP.XPPerTier, 0, 1), 1), BackgroundColor3 = C.Purple })
	corner(fill, 7)
	if not bp.Premium then
		button(header, `PREMIUM  R$ {select(2, productKey("BattlePass"))}`, C.Moon, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 2), Size = UDim2.fromOffset(170, 38), TextSize = 15 }, function()
			UI.Buy("BattlePass")
		end)
	else
		label(header, "PREMIUM ✓", 18, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -110, 0, 2), Size = UDim2.fromOffset(170, 38), Font = HEAVY, TextColor3 = C.Moon })
	end
	button(header, "SKIP TIER", C.Purple, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(100, 38), TextSize = 14 }, function()
		UI.Buy("TierSkip1")
	end)
	local s = scroller(body, { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X })
	list(s, 8, true)
	local function rewardText(reward): (string, Color3)
		if not reward then
			return "", C.Muted
		end
		if reward.Coins then
			return "$" .. Format.Number(reward.Coins), C.Moon
		end
		local item = Config.GetItem(reward.Item[1], reward.Item[2])
		return item.Name, rarityColor(item.Rarity)
	end
	for t = 1, BP.Tiers do
		local column = frame(s, { Size = UDim2.fromOffset(104, 250), BackgroundTransparency = 1, LayoutOrder = t })
		label(column, "TIER " .. t, 14, { Size = UDim2.new(1, 0, 0, 18), Font = HEAVY, TextColor3 = if t <= bp.Tier then C.Moon else C.Muted })
		for row, track in { "Free", "Premium" } do
			local reward = BP[track][t]
			local claimed = if track == "Free" then bp.Free[tostring(t)] else bp.Paid[tostring(t)]
			local text, color = rewardText(reward)
			local cell = frame(column, { Position = UDim2.fromOffset(0, 22 + (row - 1) * 112), Size = UDim2.new(1, 0, 0, 104), BackgroundColor3 = if track == "Premium" then Color3.fromRGB(44, 30, 80) else C.Panel })
			corner(cell, 10)
			stroke(cell, if claimed then C.Green elseif reward then color else C.Panel2, 2, 0.2)
			if reward and reward.Item then
				preview(cell, reward.Item[1], reward.Item[2], { Size = UDim2.new(1, 0, 0, 58) })
			elseif reward then
				label(cell, "$", 34, { Size = UDim2.new(1, 0, 0, 58), Font = LOGO, TextColor3 = C.Moon })
			end
			label(cell, text, 13, { Position = UDim2.fromOffset(4, 58), Size = UDim2.new(1, -8, 0, 30), Font = HEAVY, TextColor3 = color })
			if claimed then
				label(cell, "✓", 18, { Position = UDim2.new(1, -22, 0, 2), Size = UDim2.fromOffset(20, 20), Font = HEAVY, TextColor3 = C.Green })
			elseif track == "Premium" and reward and not bp.Premium then
				label(cell, "🔒", 14, { Position = UDim2.new(1, -22, 0, 2), Size = UDim2.fromOffset(20, 20) })
			end
		end
	end
end

---------------------------------------------------------------- Quests

builders.Quests = function()
	windowTitle.Text = "QUESTS"
	setTabs("Quests", { "Daily", "Achievements", "Stats" }, "Daily")
	if not Profile then
		return
	end
	local tab = UI.Tab.Quests
	local s = scroller(body)
	list(s, 8)
	local function row(order: number, title: string, progress: number, goal: number, right: string, done: boolean)
		local r = frame(s, { Size = UDim2.new(1, -10, 0, 56), BackgroundColor3 = C.Panel, LayoutOrder = order })
		corner(r, 10)
		stroke(r, if done then C.Green else C.Edge, 1.5, 0.3)
		label(r, title, 17, { Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -150, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, Font = HEAVY })
		local back = frame(r, { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -170, 0, 10), BackgroundColor3 = C.Panel2 })
		corner(back, 5)
		local fill = frame(back, { Size = UDim2.fromScale(math.clamp(progress / goal, 0, 1), 1), BackgroundColor3 = if done then C.Green else C.Moon })
		corner(fill, 5)
		label(r, if done then "DONE ✓" else `{Format.Number(progress)}/{Format.Number(goal)}  •  {right}`, 15, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(150, 56), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = if done then C.Green else C.Moon, Font = HEAVY })
	end
	if tab == "Daily" then
		label(s, `Login streak: day {Profile.DailyStreak}  •  New quests every day at midnight UTC`, 15, { Size = UDim2.new(1, 0, 0, 22), TextColor3 = C.Muted, LayoutOrder = 0 })
		for i, q in Profile.Quests do
			row(i, q.Text, q.Progress, q.Goal, `$${q.Reward}`, q.Done)
		end
	elseif tab == "Achievements" then
		for i, a in Profile.Achievements do
			row(i, `{a.Name}  (title: {a.Title})`, a.Progress, a.Goal, "+$200", a.Done)
		end
	else
		local st = Profile.Stats
		for i, entry in { { "Rounds played", st.Rounds }, { "Wins", st.Wins }, { "Knockouts (Murderer)", st.KOs }, { "Murderers stopped", st.Stops }, { "Rounds survived", st.Survived }, { "Coins collected", st.CoinsCollected }, { "Prestige", Profile.Prestige } } do
			local r = frame(s, { Size = UDim2.new(1, -10, 0, 40), BackgroundColor3 = C.Panel, LayoutOrder = i })
			corner(r, 10)
			label(r, entry[1], 17, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted, Font = HEAVY })
			label(r, Format.Number(entry[2]), 20, { Position = UDim2.fromScale(0.6, 0), Size = UDim2.new(0.4, -12, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Font = TITLE, TextColor3 = C.Moon })
		end
	end
end

---------------------------------------------------------------- Gluecksrad

builders.Spin = function()
	windowTitle.Text = "DAILY SPIN"
	local prizes = Config.Spin.Prizes
	local total = 0
	for _, p in prizes do
		total += p.Weight
	end
	local wheel = frame(body, { Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(300, 300), BackgroundColor3 = C.Panel })
	corner(wheel, 150)
	stroke(wheel, C.Moon, 4, 0)
	local spinner = frame(wheel, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	for i, prize in prizes do
		local angle = (i - 1) / #prizes * 360
		local arm = frame(spinner, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 140), BackgroundTransparency = 1, Rotation = angle })
		local _text = label(arm, prize.Text, 14, { Size = UDim2.fromOffset(70, 60), Font = HEAVY, TextColor3 = Color3.fromHSV((i - 1) / #prizes, 0.5, 1) })
	end
	local _pointer = label(wheel, "▼", 34, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(40, 40), TextColor3 = C.Moon, Font = TITLE })
	local hub = frame(wheel, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(60, 60), BackgroundColor3 = C.Moon })
	corner(hub, 30)
	local side = frame(body, { Position = UDim2.fromOffset(340, 0), Size = UDim2.new(1, -340, 1, 0), BackgroundTransparency = 1 })
	label(side, "ODDS", 18, { Size = UDim2.new(1, 0, 0, 22), Font = HEAVY, TextColor3 = C.Moon, TextXAlignment = Enum.TextXAlignment.Left })
	for i, prize in prizes do
		label(side, `{prize.Text}`, 15, { Position = UDim2.fromOffset(0, 4 + i * 22), Size = UDim2.new(0.7, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted })
		label(side, string.format("%.0f%%", prize.Weight / total * 100), 15, { Position = UDim2.new(0.7, 0, 0, 4 + i * 22), Size = UDim2.new(0.3, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Right, Font = HEAVY })
	end
	local left = Profile and Profile.NextSpin or 0
	local result = label(side, "", 22, { Position = UDim2.new(0, 0, 1, -100), Size = UDim2.new(1, 0, 0, 40), Font = TITLE, TextColor3 = C.Moon })
	button(side, if left > 0 then "Next spin in " .. Format.Time(left) else "SPIN FREE!", if left > 0 then C.Panel2 else C.Green, { Position = UDim2.new(0, 0, 1, -50), Size = UDim2.new(1, 0, 0, 44) }, function()
		local r = call("Spin")
		if not r.Ok then
			UI.Toast(r.Error or "Not ready yet", C.Orange)
			return
		end
		local target = 360 * 6 - (r.Index - 1) / #prizes * 360
		spinner.Rotation = 0
		local tween = TweenService:Create(spinner, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Rotation = target })
		tween:Play()
		tween.Completed:Wait()
		result.Text = "You won: " .. r.Text
		Effects.Sound("Ping", nil, 1.2, 0.8)
	end)
end

---------------------------------------------------------------- Emotes

builders.Emotes = function()
	windowTitle.Text = "EMOTES"
	local s = scroller(body)
	grid(s, Vector2.new(150, 70), 10)
	for i, emote in Config.Emotes do
		local unlocked = emote.Free or hasPass("Emotes")
		button(s, if unlocked then emote.Name else "🔒 " .. emote.Name, if unlocked then C.Panel2 else C.Panel, { LayoutOrder = i }, function()
			if unlocked then
				Controls.Emote(emote.Id)
				windowHolder.Visible = false
				UI.Window = nil
			else
				UI.Buy("Pass_Emotes")
			end
		end)
	end
end

---------------------------------------------------------------- Einstellungen, Codes

builders.Settings = function()
	windowTitle.Text = "MORE"
	local s = scroller(body)
	list(s, 10)
	local codeRow = frame(s, { Size = UDim2.new(1, -10, 0, 50), BackgroundColor3 = C.Panel, LayoutOrder = 1 })
	corner(codeRow, 10)
	local box = Instance.new("TextBox")
	box.PlaceholderText = "Enter code..."
	box.Text = ""
	box.Font = HEAVY
	box.TextSize = 18
	box.TextColor3 = C.White
	box.PlaceholderColor3 = C.Muted
	box.BackgroundColor3 = C.Night
	box.Position = UDim2.fromOffset(8, 8)
	box.Size = UDim2.new(1, -150, 0, 34)
	box.ClearTextOnFocus = false
	corner(box, 8)
	box.Parent = codeRow
	button(codeRow, "REDEEM", C.Moon, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(126, 34) }, function()
		local r = call("Redeem", box.Text)
		UI.Toast(if r.Ok then r.Text else (r.Error or "Invalid code"), if r.Ok then C.Green else C.Red)
	end)
	local afk = player:GetAttribute("AFK") == true
	button(s, if afk then "AFK: ON (you sit out rounds)" else "AFK: OFF", if afk then C.Orange else C.Panel2, { Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 2 }, function()
		call("AFK", not afk)
		task.wait(0.2)
		openWindow("Settings")
	end)
	if Profile and Profile.Level >= Config.PrestigeLevel then
		button(s, "PRESTIGE (reset level, +★ and 2,500 coins)", C.Purple, { Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 3 }, function()
			local r = call("Prestige")
			UI.Toast(if r.Ok then "Prestiged!" else (r.Error or ""), if r.Ok then C.Moon else C.Red)
		end)
	end
	button(s, "HOW TO PLAY", C.Panel2, { Size = UDim2.new(1, -10, 0, 44), LayoutOrder = 4 }, function()
		openWindow("Tutorial")
	end)
	label(s, "Follow the game for new codes!  Controls: Click = stab/shoot, T = throw, Q/F/R = abilities, Shift = sprint, E = hide/doors.", 15, { Size = UDim2.new(1, -10, 0, 50), LayoutOrder = 5, TextColor3 = C.Muted })
end

---------------------------------------------------------------- Ghost Guess

builders.Guess = function()
	windowTitle.Text = "GHOST GUESS"
	label(body, `Who is the Murderer? Guess right for +{Config.GhostGuessReward} coins when the round ends.`, 16, { Size = UDim2.new(1, 0, 0, 26), TextColor3 = C.Muted })
	local s = scroller(body, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32) })
	grid(s, Vector2.new(150, 50), 10)
	local alive = HttpService:JSONDecode(ReplicatedStorage:GetAttribute("AliveList") or "[]")
	for i, entry in alive do
		button(s, entry.Name, C.Panel2, { LayoutOrder = i }, function()
			local r = call("Guess", entry.Id)
			if r.Ok then
				UI.Toast(`You guessed {entry.Name}!`, C.Purple)
				UI.Guessed = true
				windowHolder.Visible = false
				UI.Window = nil
				guessButton.Visible = false
			else
				UI.Toast(r.Error or "Can't guess now", C.Red)
			end
		end)
	end
end

---------------------------------------------------------------- Anleitung

builders.Tutorial = function()
	windowTitle.Text = "HOW TO PLAY"
	local pages = {
		{ "INNOCENT", C.Green, "Most players are Innocent. Collect coins, hide in closets (E), slam doors and SPRINT away. Survive until the timer ends!" },
		{ "SHERIFF", C.Blue, "The Sheriff has a blaster. Find the Murderer and shoot them. Use SCAN to see the Murderer's footprints. Careful: hit an innocent and you're out too!" },
		{ "MURDERER", C.Red, "Knock everyone out without getting caught. Click to stab, T to throw. Use secret VENTS, DASH, SHADOW and GLUE TRAPS." },
		{ "EXTRAS", C.Moon, "Round modifiers, power-up boxes, ghost guesses, battle pass, crates with visible odds, the skin forge, pets, titles and more!" },
	}
	local row = frame(body, { Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1 })
	list(row, 10, true)
	for i, page in pages do
		local card = frame(row, { Size = UDim2.new(0.25, -8, 1, 0), BackgroundColor3 = C.Panel, LayoutOrder = i })
		corner(card, 14)
		stroke(card, page[2], 2, 0.1)
		label(card, page[1], 22, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 30), Font = LOGO, TextColor3 = page[2] })
		label(card, page[3], 15, { Position = UDim2.fromOffset(10, 50), Size = UDim2.new(1, -20, 1, -60), TextYAlignment = Enum.TextYAlignment.Top })
	end
	button(body, "LET'S PLAY!", C.Green, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(200, 40) }, function()
		call("Tutorial")
		windowHolder.Visible = false
		UI.Window = nil
	end)
end

---------------------------------------------------------------- Aktualisieren

local function refreshProfile()
	if not Profile then
		return
	end
	coinText.Text = Format.Number(Profile.Coins)
	levelText.Text = `Lv {Profile.Level}` .. (if Profile.Prestige > 0 then `  ★{Profile.Prestige}` else "")
	xpFill.Size = UDim2.fromScale(math.clamp(Profile.XP / Profile.XPNeeded, 0, 1), 1)
	menuBadges.Spin.Visible = Profile.NextSpin <= 0
	local questReady = false
	for _, q in Profile.Quests do
		if not q.Done and q.Progress >= q.Goal then
			questReady = true
		end
	end
	menuBadges.Quests.Visible = questReady
	if UI.Window and UI.Window ~= "Spin" and UI.Window ~= "Guess" then
		openWindow(UI.Window)
	end
end

local function refreshRound()
	RoundState = ReplicatedStorage:GetAttribute("RoundState") or "Intermission"
	local ends = ReplicatedStorage:GetAttribute("RoundEnds") or 0
	local left = math.max(0, ends - workspace:GetServerTimeNow())
	local inRound = player:GetAttribute("InRound") == true
	if RoundState == "Intermission" then
		statusTitle.Text = "NEXT ROUND IN"
		statusText.Text = Format.Time(left)
	elseif RoundState == "Reveal" then
		statusTitle.Text = string.upper(ReplicatedStorage:GetAttribute("MapName") or "")
		statusText.Text = "GET READY..."
	elseif RoundState == "Playing" then
		statusTitle.Text = `{string.upper(ReplicatedStorage:GetAttribute("MapName") or "")}  •  {ReplicatedStorage:GetAttribute("AliveCount") or 0} ALIVE`
		statusText.Text = Format.Time(left)
	else
		statusTitle.Text = "ROUND OVER"
		statusText.Text = Format.Time(left)
	end
	local modifier = ReplicatedStorage:GetAttribute("Modifier") or ""
	modifierChip.Visible = modifier ~= "" and RoundState ~= "Intermission"
	for _, m in Config.Modifiers do
		if m.Id == modifier then
			modifierText.Text = m.Name
			modifierChip.BackgroundColor3 = m.Color:Lerp(C.Night, 0.35)
		end
	end
	votePanel.Visible = RoundState == "Intermission" and not UI.Window
	oddsChip.Visible = RoundState == "Intermission"
	local playing = (RoundState == "Playing" or RoundState == "Reveal")
	roleBadge.Visible = playing and inRound and Role ~= nil
	bag.Visible = playing and inRound and Role ~= nil
	abilityBar.Visible = RoundState == "Playing" and inRound and Role ~= nil
	stamina.Visible = abilityBar.Visible and Role ~= "Murderer"
	spectateBar.Visible = playing and not inRound
	guessButton.Visible = spectateBar.Visible and RoundState == "Playing" and not UI.Guessed
	spectateName.Text = if Controls.Spectating then (Controls.Spectating:FindFirstChildOfClass("Humanoid") :: Humanoid).DisplayName else "SPECTATE"
	menu.Visible = not (playing and inRound)
	adButton.Visible = not (playing and inRound)
	-- Abklingzeiten
	local t = os.clock()
	for name, entry in abilityButtons do
		local def = Config.Abilities[name]
		local readyAt = Controls.ReadyAt[name] or 0
		local total = if name == "Throw" then Config.Knife.ThrowCooldown elseif def then def.Cooldown else 1
		local remaining = math.max(0, readyAt - t)
		entry.Shade.Size = UDim2.fromScale(1, if total > 0 then math.clamp(remaining / total, 0, 1) else 0)
		entry.Count.Text = if remaining > 0 then tostring(math.ceil(remaining)) else ""
		if name == "Sprint" then
			entry.Button.BackgroundColor3 = if Controls.Sprinting then C.Cyan:Lerp(C.Night, 0.5) else C.Panel
		end
	end
	staminaFill.Size = UDim2.fromScale(Controls.Stamina / Config.SprintStamina, 1)
end

local function setRole(role: string?)
	Role = role
	Controls.Role = role
	Effects.Role = role
	Effects.RefreshPrompts()
	if role then
		local def = Config.Roles[role]
		roleText.Text = string.upper(def.Name)
		roleText.TextColor3 = def.Color
		roleStroke.Color = def.Color
	end
	buildAbilities()
end

---------------------------------------------------------------- Start

function UI.Start()
	remotes.Notify.OnClientEvent:Connect(function(text, color)
		UI.Toast(text, color)
	end)
	remotes.Announce.OnClientEvent:Connect(function(text, color)
		UI.Banner(text, color)
	end)
	remotes.Sync.OnClientEvent:Connect(function(profile)
		Profile = profile
		refreshProfile()
	end)
	remotes.Role.OnClientEvent:Connect(function(kind, info)
		if kind == "Role" then
			local firstReveal = Role == nil
			setRole(info.Role)
			if firstReveal or info.Role ~= "Hero" then
				local modName
				for _, m in Config.Modifiers do
					if m.Id == info.Modifier then
						modName = m.Name
					end
				end
				roleCard(info.Role, modName, info.Map)
			else
				popup("YOU'RE THE HERO!", "Shoot the Murderer before it's too late!", C.Moon, 3)
			end
			bagText.Text = "0 coins"
			bagFill.Size = UDim2.fromScale(0, 1)
			UI.Guessed = false
		elseif kind == "Out" then
			setRole(nil)
			popup("KNOCKED OUT!", if info.By then `By {info.By}. Spectate or make a Ghost Guess!` else "Spectate or make a Ghost Guess!", C.Red, 3)
			task.delay(3.5, function()
				if RoundState == "Playing" then
					Controls.Spectate(1)
				end
			end)
		elseif kind == "Clear" then
			setRole(nil)
			Effects.Hidden = false
			if Controls.Spectating then
				Controls.StopSpectate()
			end
		elseif kind == "Hidden" then
			Effects.Hidden = info == true
			Effects.RefreshPrompts()
			if info then
				UI.Toast("Hidden! Press E to leave (max 15s)", C.Purple)
			end
		elseif kind == "Odds" then
			local extra = ""
			if info.MurdererTickets > 0 then
				extra ..= "  •  <font color='#ffd666'>Murderer Ticket ready</font>"
			end
			if info.SheriffTickets > 0 then
				extra ..= "  •  <font color='#ffd666'>Sheriff Ticket ready</font>"
			end
			oddsText.Text = string.format("<font color='#ff4858'>Murderer %d%%</font>   <font color='#4696ff'>Sheriff %d%%</font>", math.floor(info.Murderer * 100 + 0.5), math.floor(info.Sheriff * 100 + 0.5)) .. extra
		end
	end)
	remotes.Results.OnClientEvent:Connect(function(info)
		showResults(info)
	end)
	remotes.Offer.OnClientEvent:Connect(function(key)
		showOffer(key)
	end)
	remotes.Footprints.OnClientEvent:Connect(function(points, duration)
		Effects.Footprints(points, duration)
		UI.Toast("Scanner: the Murderer's footprints glow red!", C.Blue)
	end)
	remotes.Fx.OnClientEvent:Connect(function(kind, info)
		Effects.OnFx(kind, info)
		if kind == "OpenMenu" then
			openWindow(info.Menu)
		elseif kind == "Coin" then
			bagText.Text = `{info.Bag}/{info.Max} coins`
			bagFill.Size = UDim2.fromScale(info.Bag / info.Max, 1)
		elseif kind == "LevelUp" then
			popup(`LEVEL {info.Level}!`, `+{info.Coins} coins`, C.Cyan, 2.5)
		elseif kind == "Achievement" then
			popup("ACHIEVEMENT!", `{info.Name}  •  new title: {info.Title}`, C.Moon, 3)
		elseif kind == "Quest" then
			UI.Toast(`Quest done: {info.Text}  +${info.Reward}`, C.Green)
		elseif kind == "Tier" then
			UI.Toast(`Battle Pass tier {info.Tier}!`, C.Purple)
			menuBadges.Pass.Visible = true
		elseif kind == "Daily" then
			popup(`DAY {info.Streak} STREAK!`, `Daily login reward: +{info.Coins} coins. Come back tomorrow for more!`, C.Moon, 4)
		elseif kind == "RoundReward" then
			if UI.ResultReward and UI.ResultReward.Parent then
				UI.ResultReward.Text = `You earned +{info.XP} XP  •  {info.Coins} coins` .. (if info.Won then "  •  WIN!" else "")
			end
		elseif kind == "CoinsGained" then
			UI.Toast(`+{Format.Number(info.Amount)} coins`, C.Moon)
		end
	end)
	Controls.OnChanged = refreshRound
	for _, attribute in { "RoundState", "RoundEnds", "Modifier", "AliveCount", "MapName" } do
		ReplicatedStorage:GetAttributeChangedSignal(attribute):Connect(refreshRound)
	end
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
		local state = ReplicatedStorage:GetAttribute("RoundState")
		if state == "Intermission" then
			setRole(nil)
			refreshVotes()
		elseif state == "Playing" and Role == "Murderer" then
			UI.Toast("Your knife is ready! Click to stab, T to throw.", C.Red)
		elseif state == "Playing" and Role == "Sheriff" then
			UI.Toast("Your blaster is ready! Click to shoot.", C.Blue)
		end
	end)
	player:GetAttributeChangedSignal("InRound"):Connect(refreshRound)
	refreshVotes()
	task.spawn(function()
		while true do
			refreshRound()
			task.wait(0.2)
		end
	end)
	-- Erstes Mal: Anleitung zeigen
	task.delay(6, function()
		if Profile and not Profile.Tutorial and not UI.Window then
			openWindow("Tutorial")
		end
	end)
end

return UI
