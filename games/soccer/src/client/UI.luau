-- Baut das komplette HUD per Code im Soccer-Jam-Stil (Navy, Lime, Orange):
-- Anzeigetafel, Level/Coins, Menue, Ausdauer- und Schusskraft-Balken, Touch-Buttons,
-- Skills, Shop, Trails, Tor-Einblendung, Ergebnis und Angebote.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local C = Config.Colors
local FONT = Config.Font
local BODY = Config.BodyFont
local PANEL = Color3.fromRGB(20, 28, 64)
local GREEN = Color3.fromRGB(60, 200, 90)

UI.IsTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

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

local function stroke(color: Color3?, thickness: number?)
	return create("UIStroke", { Thickness = thickness or 2, Color = color or C.Navy, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or FONT
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	props.TextColor3 = props.TextColor3 or C.White
	local children = { create("UIStroke", { Thickness = props.StrokeThickness or 2, Color = C.Navy }) }
	props.StrokeThickness = nil
	return create("TextLabel", props, children)
end

local function button(props, color: Color3)
	props.BackgroundColor3 = color
	props.Font = props.Font or FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or C.White
	props.AutoButtonColor = true
	return create("TextButton", props, {
		corner(10),
		stroke(C.Navy, 2),
		create("UITextSizeConstraint", { MaxTextSize = 30 }),
		create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
end

local function pop(instance: GuiObject)
	local scale = instance:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = instance })
	scale.Scale = 0.6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
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

---------------------------------------------------------------- Grundgeruest

local gui: ScreenGui
local touchGui: ScreenGui
local root: Frame
local toastContainer: Frame
local announceLabel: TextLabel
local windows = {} -- [name] = Frame
local refreshers = {} -- Funktionen, die bei Attribut-Aenderungen laufen

local function refreshAll()
	for _, fn in refreshers do
		task.spawn(fn)
	end
end

local function window(name: string, title: string, size: Vector2): (Frame, Frame)
	local frame = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = PANEL,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	}, { corner(18), stroke(C.Lime, 3) })
	-- Kopfzeile mit schraegem Lime-Streifen
	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.Lime, Parent = frame }, { corner(16) })
	create("Frame", { Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 16), BackgroundColor3 = C.Lime, BorderSizePixel = 0, Parent = header })
	label({ Position = UDim2.fromOffset(18, 6), Size = UDim2.new(1, -90, 0, 42), Text = title, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Navy, StrokeThickness = 0, Parent = header })
	local close = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(40, 38), Text = "X", Parent = header }, C.Red)
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)
	local body = create("Frame", { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1, Parent = frame })
	windows[name] = frame
	return frame, body
end

function UI.Open(name: string)
	for other, frame in windows do
		frame.Visible = other == name and not frame.Visible
	end
	local frame = windows[name]
	if frame and frame.Visible then
		pop(frame)
		refreshAll()
	end
end

---------------------------------------------------------------- Meldungen

function UI.Toast(text: string, color: Color3?)
	local toast = label({ Size = UDim2.new(1, 0, 0, 30), Text = text, TextColor3 = color or C.White, Font = FONT, Parent = toastContainer })
	pop(toast)
	task.delay(3.2, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local s = toast:FindFirstChildOfClass("UIStroke")
		if s then
			TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
		end
		task.wait(0.4)
		toast:Destroy()
	end)
end

local announceToken = 0
function UI.Announce(text: string, color: Color3?, seconds: number?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.TextColor3 = color or C.White
	announceLabel.Visible = true
	pop(announceLabel)
	task.delay(seconds or 4, function()
		if token == announceToken then
			announceLabel.Visible = false
		end
	end)
end

-- Fadenkreuz in der Ego-Sicht (wie in CS)
local crosshair: Frame
local powerPlayLabel: TextLabel
function UI.SetCrosshair(on: boolean)
	if crosshair then
		crosshair.Visible = on
	end
end

---------------------------------------------------------------- Anzeigetafel

local scoreLabels = {} :: any

-- TV-Einblendung oben rechts wie beim echten Fussball: RED 2 : 1 BLUE | Zeit,
-- darunter Ballbesitz-Balken und Team-Statistik (antippen klappt sie ein/aus)
local STAT_ROWS = { { "Possession", "POSSESSION", "%" }, { "Shots", "SHOTS", "" }, { "Steals", "STEALS", "" }, { "Saves", "SAVES", "" }, { "Smacks", "SMACKS", "" }, { "KOs", "KNOCKOUTS", "" } }

local function buildScoreboard()
	local holder = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(330, 180), BackgroundTransparency = 1, Parent = root })
	local bug = create("TextButton", { Size = UDim2.fromOffset(330, 44), BackgroundColor3 = PANEL, Text = "", AutoButtonColor = false, Parent = holder }, { corner(10), stroke(C.Navy, 3) })
	local x = { Red = { Block = 0, Score = 72 }, Blue = { Block = 164, Score = 118 } }
	for index, teamName in Config.TeamOrder do
		local team = Config.Teams[teamName]
		local pos = x[teamName] or (if index == 1 then x.Red else x.Blue)
		local block = create("Frame", { Position = UDim2.fromOffset(pos.Block, 0), Size = UDim2.fromOffset(72, 44), BackgroundColor3 = team.Color, Parent = bug }, { corner(10) })
		scoreLabels[teamName .. "Mark"] = create("UIStroke", { Thickness = 3, Color = C.Lime, Enabled = false, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = block })
		label({ Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 28), Text = string.upper(team.Name), Parent = block })
		local box = create("Frame", { Position = UDim2.fromOffset(pos.Score, 4), Size = UDim2.fromOffset(46, 36), BackgroundColor3 = C.White, Parent = bug }, { corner(6) })
		scoreLabels[teamName] = label({ Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), Text = "0", TextColor3 = C.Navy, StrokeThickness = 0, Parent = box })
	end
	local clock = create("Frame", { Position = UDim2.fromOffset(240, 4), Size = UDim2.fromOffset(86, 36), BackgroundColor3 = C.Navy, Parent = bug }, { corner(6) })
	scoreLabels.Time = label({ Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 1, -6), Text = "8:00", TextColor3 = C.Lime, Parent = clock })

	local stats = create("Frame", { Position = UDim2.fromOffset(6, 46), Size = UDim2.fromOffset(318, 4 + 18 + #STAT_ROWS * 20), BackgroundColor3 = PANEL, BackgroundTransparency = 0.15, Parent = holder }, { corner(8) })
	local barBack = create("Frame", { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 0, 10), BackgroundColor3 = Config.Teams.Blue.Color, Parent = stats }, { corner(5) })
	scoreLabels.PossessionBar = create("Frame", { Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Config.Teams.Red.Color, Parent = barBack }, { corner(5) })
	for row, def in STAT_ROWS do
		local y = 4 + 18 + (row - 1) * 20
		scoreLabels["Red" .. def[1]] = label({ Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(60, 18), Text = "0", Font = BODY, TextColor3 = Config.Teams.Red.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = stats })
		label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y + 1), Size = UDim2.fromOffset(150, 16), Text = def[2], Font = BODY, TextColor3 = Color3.fromRGB(200, 210, 240), StrokeThickness = 1, Parent = stats })
		scoreLabels["Blue" .. def[1]] = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, y), Size = UDim2.fromOffset(60, 18), Text = "0", Font = BODY, TextColor3 = Config.Teams.Blue.Color, TextXAlignment = Enum.TextXAlignment.Right, Parent = stats })
	end
	scoreLabels.Stats = stats
	bug.MouseButton1Click:Connect(function()
		stats.Visible = not stats.Visible
	end)

	-- Status (Anstoss-Countdown, Golden Goal ...) oben in der Mitte
	scoreLabels.Status = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(420, 32), Text = "", TextColor3 = C.Lime, StrokeThickness = 3, Parent = root })
end

local function updateScoreboard()
	scoreLabels.Blue.Text = tostring(workspace:GetAttribute("ScoreBlue") or 0)
	scoreLabels.Red.Text = tostring(workspace:GetAttribute("ScoreRed") or 0)
	scoreLabels.Time.Text = Format.Time(workspace:GetAttribute("TimeLeft") or Config.MatchSeconds)
	local state = workspace:GetAttribute("MatchState")
	local golden = workspace:GetAttribute("GoldenGoal")
	local remaining = math.max(0, math.ceil((workspace:GetAttribute("StateEnds") or 0) - workspace:GetServerTimeNow()))
	scoreLabels.Status.Text = if state == "Kickoff" then `KICKOFF IN {remaining}`
		elseif state == "Playing" and golden then "GOLDEN GOAL - NEXT GOAL WINS"
		elseif state == "Ended" then `NEXT MATCH IN {remaining}`
		elseif state == "Waiting" then "WAITING FOR PLAYERS"
		else ""
	scoreLabels.Status.TextColor3 = if golden then C.Gold else C.Lime
	scoreLabels.Time.TextColor3 = if golden then C.Gold else C.Lime
	local team = player:GetAttribute("Team")
	for _, teamName in Config.TeamOrder do
		scoreLabels[teamName .. "Mark"].Enabled = team == teamName
		for _, def in STAT_ROWS do
			scoreLabels[teamName .. def[1]].Text = tostring(workspace:GetAttribute(`Stat{teamName}{def[1]}`) or (if def[1] == "Possession" then 50 else 0)) .. def[3]
		end
	end
	local share = (workspace:GetAttribute("StatRedPossession") or 50) / 100
	scoreLabels.PossessionBar.Size = UDim2.fromScale(math.clamp(share, 0.02, 0.98), 1)
end

---------------------------------------------------------------- Profil (Level, XP, Coins, Boost)

local profile = {} :: any

local function buildProfile()
	local card = create("Frame", { Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(250, 66), BackgroundColor3 = PANEL, Parent = root }, { corner(14), stroke(C.Navy, 3) })
	local badge = create("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = C.Lime, Parent = card }, { corner(27), stroke(C.Navy, 3) })
	label({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 14), Text = "LV", TextColor3 = C.Navy, StrokeThickness = 0, Parent = badge })
	profile.Level = label({ Position = UDim2.fromOffset(4, 14), Size = UDim2.new(1, -8, 0, 34), Text = "1", TextColor3 = C.Navy, StrokeThickness = 0, Parent = badge })
	local barBack = create("Frame", { Position = UDim2.fromOffset(68, 10), Size = UDim2.fromOffset(170, 16), BackgroundColor3 = C.Navy, Parent = card }, { corner(8) })
	profile.XPBar = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Lime, Parent = barBack }, { corner(8) })
	profile.XPText = label({ Size = UDim2.fromScale(1, 1), Text = "0 / 280 XP", Font = BODY, TextColor3 = C.White, ZIndex = 2, Parent = barBack })
	local coins = create("Frame", { Position = UDim2.fromOffset(68, 34), Size = UDim2.fromOffset(170, 26), BackgroundColor3 = C.Navy, Parent = card }, { corner(13) })
	create("Frame", { Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.Gold, Parent = coins }, { corner(10), stroke(Color3.fromRGB(200, 140, 20), 2) })
	profile.Coins = label({ Position = UDim2.fromOffset(30, 2), Size = UDim2.new(1, -36, 1, -4), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Gold, Parent = coins })
	profile.Boost = label({ Position = UDim2.fromOffset(10, 78), Size = UDim2.fromOffset(200, 22), Text = "", TextColor3 = C.Lime, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = root })

	table.insert(refreshers, function()
		local level = player:GetAttribute("Level") or 1
		local xp = player:GetAttribute("XP") or 0
		local needed = player:GetAttribute("XPNeeded") or Config.XPForLevel(level)
		profile.Level.Text = tostring(level)
		profile.XPText.Text = `{Format.Number(xp)} / {Format.Number(needed)} XP`
		TweenService:Create(profile.XPBar, TweenInfo.new(0.3), { Size = UDim2.fromScale(math.clamp(xp / needed, 0, 1), 1) }):Play()
		profile.Coins.Text = Format.Number(player:GetAttribute("Coins") or 0)
	end)
end

---------------------------------------------------------------- Menue links

local skillBadge: TextLabel
local adButton: TextButton

local function buildMenu()
	local menu = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(78, 340), BackgroundTransparency = 1, Parent = root }, {
		create("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local function item(text: string, color: Color3, order: number, onClick: () -> ()): TextButton
		local b = button({ Size = UDim2.fromOffset(74, 62), Text = text, LayoutOrder = order, Parent = menu }, color)
		b.MouseButton1Click:Connect(onClick)
		return b
	end
	local skills = item("UPGRADE", C.Lime, 1, function()
		UI.Open("Skills")
	end)
	skills.TextColor3 = C.Navy
	skillBadge = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0, BackgroundColor3 = C.Red, Text = "0", Visible = false, ZIndex = 3, Parent = skills })
	corner(14).Parent = skillBadge
	item("SHOP", C.Orange, 2, function()
		UI.Open("Shop")
	end)
	item("TRAILS", C.Cyan, 3, function()
		UI.Open("Trails")
	end)
	adButton = item("FREE COINS", GREEN, 4, function()
		remotes.WatchAd:FireServer()
	end)
	adButton.Visible = false

	table.insert(refreshers, function()
		-- Rotes Abzeichen, sobald man sich ein Upgrade leisten kann
		local exp = player:GetAttribute("EXP") or 0
		local affordable = false
		for _, skill in Config.Skills do
			local base = player:GetAttribute("Base_" .. skill.Id) or 0
			if base < Config.MaxSkill and exp >= Config.UpgradeCost(base) then
				affordable = true
			end
		end
		skillBadge.Text = "!"
		skillBadge.Visible = affordable
	end)
	-- Werbe-Button nur zeigen, wenn wirklich eine Video-Werbung verfuegbar ist
	task.spawn(function()
		while true do
			local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			adButton.Visible = ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable and productId("AdCoins") ~= 0
			task.wait(30)
		end
	end)
end

---------------------------------------------------------------- Ausdauer und Schusskraft

local staminaBar: Frame
local hpBar: Frame
local hpText: TextLabel
local powerFrame: Frame
local powerBar: Frame

local function buildBars()
	local holder = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(320, 76), BackgroundTransparency = 1, Parent = root })
	powerFrame = create("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(320, 26), BackgroundColor3 = C.Navy, Visible = false, Parent = holder }, { corner(13), stroke(C.Orange, 2) })
	powerBar = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Orange, Parent = powerFrame }, {
		corner(13),
		create("UIGradient", { Color = ColorSequence.new(C.Lime, C.Orange) }),
	})
	label({ Size = UDim2.fromScale(1, 1), Text = "POWER", ZIndex = 2, Parent = powerFrame })
	local hpBack = create("Frame", { Position = UDim2.fromOffset(20, 32), Size = UDim2.fromOffset(280, 18), BackgroundColor3 = C.Navy, Parent = holder }, { corner(9), stroke(C.Navy, 2) })
	hpBar = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(90, 230, 90), Parent = hpBack }, { corner(9) })
	hpText = label({ Size = UDim2.fromScale(1, 1), Text = "100", Font = BODY, ZIndex = 2, Parent = hpBack })
	label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -6, 0.5, 0), Size = UDim2.fromOffset(70, 16), Text = "HEALTH", TextXAlignment = Enum.TextXAlignment.Right, Font = BODY, Parent = hpBack })
	local staminaBack = create("Frame", { Position = UDim2.fromOffset(20, 58), Size = UDim2.fromOffset(280, 12), BackgroundColor3 = C.Navy, Parent = holder }, { corner(6), stroke(C.Navy, 2) })
	staminaBar = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Lime, Parent = staminaBack }, { corner(7) })
	label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, -6, 0.5, 0), Size = UDim2.fromOffset(70, 16), Text = "STAMINA", TextXAlignment = Enum.TextXAlignment.Right, Font = BODY, Parent = staminaBack })
	if not UI.IsTouch then
		label({
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -8),
			Size = UDim2.fromOffset(620, 18),
			Text = "Hold CLICK: kick  |  E: pass  |  CLICK/F: knife  |  RIGHT-CLICK/G: stab  |  SHIFT: turbo  |  T: call pass  |  V: view  |  jump while strafing: long jump",
			Font = BODY,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Color3.fromRGB(220, 230, 255),
			Parent = root,
		})
	end
end

function UI.SetPower(power: number?)
	powerFrame.Visible = power ~= nil
	if power then
		powerBar.Size = UDim2.fromScale(math.clamp(power, 0.02, 1), 1)
	end
end

function UI.SetHP(hp: number, maxHP: number)
	local fraction = math.clamp(hp / maxHP, 0, 1)
	hpBar.Size = UDim2.fromScale(math.max(fraction, 0.001), 1)
	hpBar.Visible = fraction > 0
	hpBar.BackgroundColor3 = if fraction > 0.5 then Color3.fromRGB(90, 230, 90) elseif fraction > 0.25 then C.Orange else C.Red
	hpText.Text = tostring(math.ceil(hp))
end

-- Schadenszahl ueber dem Kopf (Backstab gross und rot)
function UI.DamageNumber(head: BasePart, amount: number, backstab: boolean)
	local board = create("BillboardGui", { Size = UDim2.fromOffset(160, 40), StudsOffset = Vector3.new(math.random(-10, 10) / 10, 3.5, 0), AlwaysOnTop = true, LightInfluence = 0, Adornee = head, Parent = player:WaitForChild("PlayerGui") })
	local text = label({ Size = UDim2.fromScale(1, 1), Text = (if backstab then "BACKSTAB -" else "-") .. amount, TextColor3 = if backstab then C.Red else C.Orange, StrokeThickness = 3, Parent = board })
	TweenService:Create(board, TweenInfo.new(0.8), { StudsOffset = board.StudsOffset + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(text, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(0.85, function()
		board:Destroy()
	end)
end

-- Kill-Feed (K.O.-Meldungen) rechts unter der TV-Anzeige
local feed: Frame
function UI.KillFeed(info)
	local line = create("Frame", { Size = UDim2.fromOffset(330, 24), BackgroundColor3 = PANEL, BackgroundTransparency = 0.25, Parent = feed }, { corner(6) })
	local function teamColor(team)
		return if team and Config.Teams[team] then Config.Teams[team].Color else C.White
	end
	local how = if info.Kind == "Smack" then "SMACK" elseif info.Kind == "Stab" then "STAB" elseif info.Kind == "Alien" then "ALIEN" else "KNIFE"
	local left = if info.Attacker then info.Attacker elseif info.Kind == "Alien" then "MASCOT" else ""
	label({ Position = UDim2.fromOffset(6, 3), Size = UDim2.new(0.42, -6, 1, -6), Text = left, Font = BODY, TextColor3 = teamColor(info.AttackerTeam), TextXAlignment = Enum.TextXAlignment.Right, Parent = line })
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.new(0.16, 0, 1, -6), Text = how, Font = BODY, TextColor3 = C.Gold, Parent = line })
	label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 3), Size = UDim2.new(0.42, -6, 1, -6), Text = info.Victim, Font = BODY, TextColor3 = teamColor(info.VictimTeam), TextXAlignment = Enum.TextXAlignment.Left, Parent = line })
	local lines = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	if #lines > 5 then
		lines[1]:Destroy()
	end
	task.delay(6, function()
		line:Destroy()
	end)
end

function UI.SetStamina(fraction: number, exhausted: boolean)
	staminaBar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	staminaBar.BackgroundColor3 = if exhausted then C.Red elseif fraction < 0.3 then C.Orange else C.Lime
end

---------------------------------------------------------------- Touch-Buttons (links neben dem Roblox-Sprungknopf)

local actionButtons = {} -- [name] = TextButton

local function buildTouch()
	touchGui = create("ScreenGui", { Name = "TouchActions", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	local viewport = workspace.CurrentCamera.ViewportSize
	local small = math.min(viewport.X, viewport.Y) <= 500
	-- {rechter Abstand, unterer Abstand, Groesse}
	local layout = if small
		then { Shoot = { 110, 14, 84 }, Tackle = { 24, 98, 64 }, Pass = { 120, 104, 60 }, Sprint = { 204, 16, 60 }, Stab = { 30, 168, 52 }, Call = { 200, 84, 46 }, View = { 34, 228, 44 } }
		else { Shoot = { 180, 26, 128 }, Tackle = { 48, 222, 100 }, Pass = { 200, 166, 92 }, Sprint = { 320, 26, 96 }, Stab = { 56, 334, 80 }, Call = { 316, 132, 68 }, View = { 64, 424, 64 } }
	local colors = { Shoot = C.Lime, Tackle = C.Orange, Pass = C.Cyan, Sprint = Color3.fromRGB(170, 120, 255), Stab = C.Red, Call = C.Gold, View = PANEL }
	local texts = { Shoot = "KICK", Tackle = "KNIFE", Pass = "PASS", Sprint = "TURBO", Stab = "STAB", Call = "!", View = "VIEW" }
	for name, spec in layout do
		local b = create("TextButton", {
			Name = name,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -spec[1], 1, -spec[2]),
			Size = UDim2.fromOffset(spec[3], spec[3]),
			BackgroundColor3 = colors[name],
			BackgroundTransparency = 0.1,
			Text = texts[name],
			TextColor3 = if name == "Shoot" or name == "Call" then C.Navy else C.White,
			Font = FONT,
			TextScaled = true,
			AutoButtonColor = false,
			Visible = UI.IsTouch,
			Parent = touchGui,
		}, {
			create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			stroke(C.Navy, 3),
			create("UIPadding", { PaddingLeft = UDim.new(0.15, 0), PaddingRight = UDim.new(0.15, 0), PaddingTop = UDim.new(0.3, 0), PaddingBottom = UDim.new(0.3, 0) }),
		})
		actionButtons[name] = b
	end
end

-- Verbindet einen Touch-Button mit Druecken/Loslassen
function UI.BindAction(name: string, began: () -> (), ended: (() -> ())?)
	local b = actionButtons[name]
	if not b then
		return
	end
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			b.BackgroundTransparency = 0.45
			began()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			b.BackgroundTransparency = 0.1
			if ended then
				ended()
			end
		end
	end)
end

function UI.SetCarrying(carrying: boolean)
	local shoot = actionButtons.Shoot
	if shoot then
		shoot.BackgroundTransparency = if carrying then 0.1 else 0.55
	end
	local pass = actionButtons.Pass
	if pass then
		pass.BackgroundTransparency = if carrying then 0.1 else 0.55
	end
end

function UI.SetSprintOn(on: boolean)
	local sprint = actionButtons.Sprint
	if sprint then
		sprint.BackgroundColor3 = if on then C.Lime else Color3.fromRGB(170, 120, 255)
		sprint.TextColor3 = if on then C.Navy else C.White
	end
end

---------------------------------------------------------------- Skills

local function buildSkills()
	local _, body = window("Skills", "UPGRADES", Vector2.new(600, 470))
	local pointsLabel = label({ Size = UDim2.new(1, 0, 0, 28), Text = "", TextColor3 = C.Lime, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	local list = create("Frame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 290), BackgroundTransparency = 1, Parent = body }, {
		create("UIListLayout", { Padding = UDim.new(0, 6) }),
	})
	local rows = {}
	for index, skill in Config.Skills do
		local row = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.NavyLight, LayoutOrder = index, Parent = list }, { corner(10) })
		label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.fromOffset(150, 26), Text = string.upper(skill.Name), TextColor3 = skill.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		label({ Position = UDim2.fromOffset(10, 30), Size = UDim2.fromOffset(250, 16), Text = skill.Description, Font = BODY, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 210, 240), StrokeThickness = 0, Parent = row })
		local pips = {}
		for i = 1, Config.MaxSkill + 1 do
			pips[i] = create("Frame", { Position = UDim2.fromOffset(268 + (i - 1) * 26, 14), Size = UDim2.fromOffset(22, 24), BackgroundColor3 = C.Navy, Visible = i <= Config.MaxSkill, Parent = row }, { corner(6) })
		end
		local plus = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 40), Text = "+" }, GREEN)
		plus.Parent = row
		plus.MouseButton1Click:Connect(function()
			remotes.Upgrade:FireServer(skill.Id)
		end)
		rows[skill.Id] = { Pips = pips, Plus = plus, Color = skill.Color }
	end
	local actions = create("Frame", { Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = body }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local buyEXP = button({ Size = UDim2.fromOffset(200, 44), Text = "" }, C.Gold)
	buyEXP.TextColor3 = C.Navy
	buyEXP.Parent = actions
	buyEXP.MouseButton1Click:Connect(function()
		remotes.BuyPoint:FireServer()
	end)
	local buyMore = button({ Size = UDim2.fromOffset(170, 44), Text = "" }, C.Orange)
	buyMore.Parent = actions
	buyMore.MouseButton1Click:Connect(function()
		UI.Buy("Product", "MatchEXP")
	end)
	local maxAll = button({ Size = UDim2.fromOffset(170, 44), Text = "" }, Color3.fromRGB(170, 90, 255))
	maxAll.Parent = actions
	maxAll.MouseButton1Click:Connect(function()
		UI.Buy("Product", "MaxUpgrades")
	end)

	table.insert(refreshers, function()
		local exp = player:GetAttribute("EXP") or 0
		local boots = player:GetAttribute("Pass_ProBoots") == true
		pointsLabel.Text = `EXP: {Format.Number(exp)}` .. (if boots then "   (PRO BOOTS +1)" else "   Upgrades reset every match")
		for id, row in rows do
			local base = player:GetAttribute("Base_" .. id) or 0
			for i, pip in row.Pips do
				if i <= Config.MaxSkill then
					pip.BackgroundColor3 = if i <= base then row.Color else C.Navy
				else
					pip.Visible = boots
					pip.BackgroundColor3 = C.Gold
				end
			end
			local maxed = base >= Config.MaxSkill
			local cost = Config.UpgradeCost(base)
			row.Plus.Text = if maxed then "MAX" else `+ {cost} EXP`
			row.Plus.BackgroundColor3 = if maxed then C.NavyLight elseif exp >= cost then GREEN else Color3.fromRGB(90, 100, 130)
		end
		local bought = player:GetAttribute("BoughtEXP") or 0
		buyEXP.Text = `+{Config.BuyEXPAmount} EXP: {Format.Number(Config.BuyEXPBase + Config.BuyEXPStep * bought)} COINS`
		buyMore.Text = `+600 EXP  R$ {price("MatchEXP", Config.DevProducts.MatchEXP.PriceHint)}`
		maxAll.Text = `MAX ALL  R$ {price("MaxUpgrades", Config.DevProducts.MaxUpgrades.PriceHint)}`
	end)
end

-- Kleine "+300 EXP"-Einblendung
function UI.EXPPopup(amount: number, kind: string)
	UI.Toast(`+{amount} EXP  ({string.upper(kind)})`, C.Lime)
end

---------------------------------------------------------------- Shop

local shopTabs = {} :: any

local function card(parent: Instance, order: number, title: string, description: string, accent: Color3): (Frame, TextButton)
	local frame = create("Frame", { Size = UDim2.fromOffset(176, 170), BackgroundColor3 = C.NavyLight, LayoutOrder = order, Parent = parent }, { corner(12), stroke(accent, 2) })
	create("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = accent, BorderSizePixel = 0, Parent = frame }, { corner(4) })
	label({ Position = UDim2.fromOffset(8, 14), Size = UDim2.new(1, -16, 0, 30), Text = title, TextColor3 = accent, Parent = frame })
	label({ Position = UDim2.fromOffset(8, 48), Size = UDim2.new(1, -16, 0, 60), Text = description, Font = BODY, TextWrapped = true, StrokeThickness = 0, TextColor3 = Color3.fromRGB(215, 222, 245), Parent = frame })
	local buy = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 42), Text = "" }, GREEN)
	buy.Parent = frame
	return frame, buy
end

local function grid(parent: Instance): ScrollingFrame
	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Lime,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(176, 170), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	})
	return scroll
end

function UI.OpenShop(tab: string)
	if not windows.Shop.Visible then
		UI.Open("Shop")
	end
	for name, entry in shopTabs do
		entry.Page.Visible = name == tab
		entry.Button.BackgroundColor3 = if name == tab then C.Lime else C.NavyLight
		entry.Button.TextColor3 = if name == tab then C.Navy else C.White
	end
end

local function buildShop()
	local _, body = window("Shop", "SHOP", Vector2.new(600, 470))
	local tabBar = create("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = body }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	for index, tab in { { "Passes", "PASSES" }, { "Coins", "COINS & BOOSTS" } } do
		local b = button({ Size = UDim2.fromOffset(if index == 1 then 160 else 240, 40), Text = tab[2], LayoutOrder = index }, C.NavyLight)
		b.Parent = tabBar
		local page = grid(body)
		shopTabs[tab[1]] = { Button = b, Page = page }
		b.MouseButton1Click:Connect(function()
			UI.OpenShop(tab[1])
		end)
	end

	local passButtons = {}
	for key, pass in Config.GamePasses do
		local _, buy = card(shopTabs.Passes.Page, pass.Order, string.upper(pass.Name), pass.Description, if key == "VIP" then C.Gold else C.Lime)
		buy.MouseButton1Click:Connect(function()
			UI.Buy("Pass", key)
		end)
		passButtons[key] = { Button = buy, Pass = pass }
	end
	local productButtons = {}
	for key, product in Config.DevProducts do
		if not product.Hidden then
			local description = product.Description or (if product.Kind == "Coins" then "Buy trails and extra EXP" elseif product.Kind == "XPBoost" then "Stacks with Double XP" else "")
			local _, buy = card(shopTabs.Coins.Page, product.Order or 99, string.upper(product.Name), description, if product.Kind == "Coins" then C.Gold else C.Orange)
			buy.MouseButton1Click:Connect(function()
				UI.Buy("Product", key)
			end)
			productButtons[key] = { Button = buy, Product = product }
		end
	end

	table.insert(refreshers, function()
		for key, entry in passButtons do
			local owned = player:GetAttribute("Pass_" .. key) == true
			entry.Button.Text = if owned then "OWNED" else `R$ {price(key, entry.Pass.PriceHint)}`
			entry.Button.BackgroundColor3 = if owned then C.NavyLight else GREEN
		end
		for key, entry in productButtons do
			entry.Button.Text = `R$ {price(key, entry.Product.PriceHint)}`
		end
	end)
	UI.OpenShop("Passes")
	windows.Shop.Visible = false
end

---------------------------------------------------------------- Trails

local function buildTrails()
	local _, body = window("Trails", "KICK TRAILS", Vector2.new(600, 470))
	label({ Size = UDim2.new(1, 0, 0, 40), Text = "Your shots leave this trail behind the ball", Font = BODY, TextColor3 = Color3.fromRGB(215, 222, 245), StrokeThickness = 0, Parent = body })
	local page = grid(body)
	local entries = {}
	for _, trail in Config.Trails do
		local keypoints = {}
		for i, color in trail.Colors do
			table.insert(keypoints, ColorSequenceKeypoint.new(if #trail.Colors == 1 then 0 else (i - 1) / (#trail.Colors - 1), color))
		end
		if #keypoints == 1 then
			table.insert(keypoints, ColorSequenceKeypoint.new(1, trail.Colors[1]))
		end
		local frame, buy = card(page, trail.Order, string.upper(trail.Name), "", trail.Colors[1])
		local swatch = create("Frame", { Position = UDim2.fromOffset(12, 58), Size = UDim2.new(1, -24, 0, 40), BackgroundColor3 = C.White, Parent = frame }, {
			corner(20),
			create("UIGradient", { Color = ColorSequence.new(keypoints) }),
		})
		swatch.ZIndex = 2
		buy.MouseButton1Click:Connect(function()
			if trail.Pass and not player:GetAttribute("Pass_" .. trail.Pass) then
				UI.ShowOffer(trail.Pass)
			else
				remotes.Trail:FireServer(trail.Id)
			end
		end)
		entries[trail.Id] = { Button = buy, Trail = trail }
	end
	table.insert(refreshers, function()
		local owned = {}
		for id in string.gmatch(player:GetAttribute("OwnedTrails") or "white", "[^,]+") do
			owned[id] = true
		end
		local equipped = player:GetAttribute("Trail") or "white"
		for id, entry in entries do
			local trail = entry.Trail
			local has = owned[id] or (trail.Pass and player:GetAttribute("Pass_" .. trail.Pass))
			if id == equipped then
				entry.Button.Text = "EQUIPPED"
				entry.Button.BackgroundColor3 = C.NavyLight
			elseif has then
				entry.Button.Text = "EQUIP"
				entry.Button.BackgroundColor3 = C.Cyan
			elseif trail.Pass then
				entry.Button.Text = if trail.Pass == "VIP" then "VIP ONLY" elseif trail.Pass == "StarterPack" then "STARTER PACK" else "EFFECTS PACK"
				entry.Button.BackgroundColor3 = C.Orange
			else
				entry.Button.Text = `{Format.Number(trail.Price)} COINS`
				entry.Button.BackgroundColor3 = C.Gold
			end
		end
	end)
end

---------------------------------------------------------------- Tor, Ergebnis, Angebote

local goalFrame: Frame
local goalTitle: TextLabel
local goalLine: TextLabel

local function buildGoal()
	goalFrame = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(700, 200), BackgroundTransparency = 1, Visible = false, Parent = root })
	goalTitle = label({ Size = UDim2.new(1, 0, 0, 140), Text = "GOAL!", TextColor3 = C.Lime, StrokeThickness = 5, Rotation = -4, Parent = goalFrame })
	goalLine = label({ Position = UDim2.fromOffset(0, 140), Size = UDim2.new(1, 0, 0, 40), Text = "", Parent = goalFrame })
end

function UI.ShowGoal(info)
	local team = Config.Teams[info.Team]
	goalTitle.Text = if info.OwnGoal then "OWN GOAL!" else "GOAL!"
	goalTitle.TextColor3 = team.Color
	local text = if info.Scorer then `{info.Scorer} scores for {string.upper(team.Name)}` else `{string.upper(team.Name)} score!`
	if info.Distance and not info.OwnGoal then
		text ..= ` from {info.Distance} studs!`
	end
	if info.Assist then
		text ..= `  (assist: {info.Assist})`
	end
	goalLine.Text = text
	goalFrame.Visible = true
	pop(goalFrame)
	task.delay(Config.GoalCelebrationSeconds - 0.5, function()
		goalFrame.Visible = false
	end)
end

local resultsFrame: Frame

local function buildResults()
	local frame, body = window("Results", "FULL TIME", Vector2.new(500, 440))
	resultsFrame = frame
	local title = label({ Name = "Title", Size = UDim2.new(1, 0, 0, 60), Text = "VICTORY", Parent = body })
	local stats = label({ Name = "Stats", Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 90), Text = "", Font = BODY, TextWrapped = true, Parent = body })
	local earned = label({ Name = "Earned", Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 34), Text = "", TextColor3 = C.Gold, Parent = body })
	local awards = label({ Name = "Awards", Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 110), Text = "", Font = BODY, TextWrapped = true, TextColor3 = C.Lime, Parent = body })
	UI.FillResults = function(info)
		title.Text = if info.Result == "Win" then "VICTORY!" elseif info.Result == "Loss" then "DEFEAT" else "DRAW"
		title.TextColor3 = if info.Result == "Win" then C.Lime elseif info.Result == "Loss" then C.Orange else C.White
		stats.Text = `Goals {info.Goals}   Assists {info.Assists}   Steals {info.Steals}\nSaves {info.Saves}   Smacks {info.Smacks or 0}   Match EXP {Format.Number(info.EXP or 0)}`
		earned.Text = `+{Format.Number(info.XP)} ACCOUNT XP    +{Format.Number(info.Coins)} COINS`
		awards.Text = table.concat(info.Awards or {}, "\n")
	end
end

function UI.ShowResults(info)
	UI.FillResults(info)
	UI.Open("Results")
	if not resultsFrame.Visible then
		UI.Open("Results")
	end
end

function UI.HideResults()
	resultsFrame.Visible = false
end

local offerFrame: Frame
local offerTitle: TextLabel
local offerText: TextLabel
local offerBuy: TextButton
local offerAction: () -> () = function() end

local function buildOffer()
	offerFrame = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 280), BackgroundColor3 = PANEL, Visible = false, ZIndex = 10, Parent = root }, {
		corner(18),
		stroke(C.Orange, 4),
	})
	local banner = create("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.Orange, Parent = offerFrame }, { corner(16) })
	label({ Size = UDim2.fromScale(1, 1), Text = "SPECIAL OFFER", Parent = banner })
	offerTitle = label({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 44), Text = "", TextColor3 = C.Lime, Parent = offerFrame })
	offerText = label({ Position = UDim2.fromOffset(16, 106), Size = UDim2.new(1, -32, 0, 60), Text = "", Font = BODY, TextWrapped = true, StrokeThickness = 0, Parent = offerFrame })
	offerBuy = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -54), Size = UDim2.fromOffset(260, 52), Text = "" }, GREEN)
	offerBuy.Parent = offerFrame
	offerBuy.MouseButton1Click:Connect(function()
		offerFrame.Visible = false
		offerAction()
	end)
	local no = create("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(200, 32), BackgroundTransparency = 1, Text = "No thanks", Font = BODY, TextScaled = true, TextColor3 = Color3.fromRGB(190, 200, 230), Parent = offerFrame })
	no.MouseButton1Click:Connect(function()
		offerFrame.Visible = false
	end)
end

-- kind: "StarterPack", "XPBoost", "MatchEXP", "Coins" oder ein Pass-Schluessel
function UI.ShowOffer(kind: string)
	if kind == "Coins" then
		UI.Toast("Not enough coins!", C.Orange)
		UI.OpenShop("Coins")
		return
	end
	local pass = Config.GamePasses[kind]
	local product = Config.DevProducts[kind]
	if pass then
		if player:GetAttribute("Pass_" .. kind) then
			return
		end
		offerTitle.Text = string.upper(pass.Name)
		offerText.Text = pass.Description
		offerBuy.Text = `GET IT  R$ {price(kind, pass.PriceHint)}`
		offerAction = function()
			UI.Buy("Pass", kind)
		end
	elseif product then
		if kind == "StarterPack" and player:GetAttribute("Pass_StarterPack") then
			return
		end
		offerTitle.Text = string.upper(product.Name)
		offerText.Text = product.Description
			or (if kind == "XPBoost" then "Lost this one? Double all XP for the next 30 minutes and come back stronger!" else "")
		if kind == "MatchEXP" then
			offerText.Text = "Not enough EXP! Get 600 EXP and upgrade right now."
		end
		local key = kind
		offerBuy.Text = `GET IT  R$ {price(key, Config.DevProducts[key].PriceHint)}`
		offerAction = function()
			UI.Buy("Product", key)
		end
	else
		return
	end
	offerFrame.Visible = true
	pop(offerFrame)
end

---------------------------------------------------------------- Start

function UI.Start()
	-- Die Spielerliste oben rechts weicht der TV-Anzeige
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	gui = create("ScreenGui", { Name = "TurboHUD", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	-- Alles fuer 1280x720 entworfen und passend skaliert (Handy bis Monitor)
	local scale = create("UIScale", { Parent = root })
	local function rescale()
		local viewport = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.5, 1.4)
		scale.Scale = s
		root.Size = UDim2.fromOffset(viewport.X / s, (viewport.Y - 36) / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	toastContainer = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.fromOffset(560, 200), BackgroundTransparency = 1, Parent = root }, {
		create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2) }),
	})
	announceLabel = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromOffset(800, 52), Text = "", Visible = false, StrokeThickness = 3, Parent = root })

	local crossGui = create("ScreenGui", { Name = "Crosshair", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui") })
	crosshair = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Visible = false, Parent = crossGui }, {
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(2, 22), BackgroundColor3 = C.Lime, BorderSizePixel = 0 }),
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 2), BackgroundColor3 = C.Lime, BorderSizePixel = 0 }),
	})
	powerPlayLabel = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 362), Size = UDim2.fromOffset(330, 26), Text = "", Visible = false, Parent = root })

	buildScoreboard()
	feed = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 196), Size = UDim2.fromOffset(330, 160), BackgroundTransparency = 1, Parent = root }, {
		create("UIListLayout", { Padding = UDim.new(0, 3), HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
	buildProfile()
	buildMenu()
	buildBars()
	buildTouch()
	buildSkills()
	buildShop()
	buildTrails()
	buildGoal()
	buildResults()
	buildOffer()

	for _, name in { "Level", "XP", "XPNeeded", "Coins", "EXP", "BoughtEXP", "Trail", "OwnedTrails", "Team" } do
		player:GetAttributeChangedSignal(name):Connect(refreshAll)
	end
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Pass_" or string.sub(name, 1, 5) == "Base_" then
			refreshAll()
		end
	end)
	ReplicatedStorage.AttributeChanged:Connect(refreshAll)
	refreshAll()

	-- Anzeigetafel und Boost-Timer jede Zehntelsekunde
	task.spawn(function()
		while true do
			updateScoreboard()
			local character = player.Character
			local maxHP = character and character:GetAttribute("MaxHP") or Config.MaxHP
			UI.SetHP(character and character:GetAttribute("HP") or maxHP, maxHP)
			local ppTeam = workspace:GetAttribute("PowerPlayTeam")
			local pp = workspace:GetAttribute("PowerPlay") or 0
			powerPlayLabel.Visible = ppTeam ~= nil and pp > 0
			if powerPlayLabel.Visible then
				powerPlayLabel.Text = `{string.upper(ppTeam)} POWERPLAY x{pp}`
				powerPlayLabel.TextColor3 = if Config.Teams[ppTeam] then Config.Teams[ppTeam].Color else C.White
			end
			local boost = (player:GetAttribute("BoostUntil") or 0) - os.time()
			profile.Boost.Visible = boost > 0
			if boost > 0 then
				profile.Boost.Text = `2x XP BOOST  {Format.Time(boost)}`
			end
			task.wait(0.2)
		end
	end)

	remotes.Notify.OnClientEvent:Connect(function(text, color)
		UI.Toast(text, color)
	end)
	remotes.Announce.OnClientEvent:Connect(function(text, color)
		UI.Announce(text, color)
	end)
	remotes.Offer.OnClientEvent:Connect(function(kind)
		UI.ShowOffer(kind)
	end)
	remotes.Results.OnClientEvent:Connect(function(info)
		UI.ShowResults(info)
	end)
end

return UI
