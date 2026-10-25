-- Benutzeroberflaeche im Laternen-Stil: dunkles Nachtblau mit warmem Bernstein-Rand.
-- HUD (Held, Gold, Dungeon, Boss), Kampfknoepfe, Inventar, Schmiede, Shop, Klassenwahl,
-- Lobby, Tod, Zusammenfassung, Angebote und Meldungen.
local AdService = game:GetService("AdService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Items = require(ReplicatedStorage.Shared.Items)
local Effects = require(script.Parent.Effects)

local UI = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = remotes:WaitForChild("Request") :: RemoteFunction

local THEME = {
	Panel = Color3.fromRGB(20, 24, 44),
	PanelLight = Color3.fromRGB(32, 38, 66),
	PanelDark = Color3.fromRGB(13, 15, 30),
	Border = Color3.fromRGB(255, 184, 74),
	Text = Color3.fromRGB(242, 238, 228),
	Muted = Color3.fromRGB(168, 170, 198),
	Gold = Color3.fromRGB(255, 202, 84),
	Amber = Color3.fromRGB(255, 184, 74),
	Red = Color3.fromRGB(240, 84, 84),
	Green = Color3.fromRGB(110, 222, 140),
	Blue = Color3.fromRGB(90, 160, 255),
	Shard = Color3.fromRGB(150, 220, 255),
}
local TITLE = Enum.Font.LuckiestGuy
local BODY = Enum.Font.BuilderSansBold
local HEAVY = Enum.Font.BuilderSansExtraBold

local state = {
	Items = {},
	Equipped = {},
	Capacity = Config.BaseInventory,
	Run = nil,
	Lobby = nil,
	Quests = nil :: any, -- taegliche Quests vom Server
	Selected = nil,
	AutoAttack = false,
	Cooldowns = { Attack = 0, [1] = 0, [2] = 0, Potion = 0 },
}

---------------------------------------------------------------- Bausteine

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

local function corner(radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function stroke(color: Color3?, thickness: number?, transparency: number?)
	return create("UIStroke", { Color = color or THEME.Border, Thickness = thickness or 1.5, Transparency = transparency or 0.35, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function padding(px: number)
	return create("UIPadding", { PaddingTop = UDim.new(0, px), PaddingBottom = UDim.new(0, px), PaddingLeft = UDim.new(0, px), PaddingRight = UDim.new(0, px) })
end

local function panel(props, children: { Instance }?)
	props.BackgroundColor3 = props.BackgroundColor3 or THEME.Panel
	props.BorderSizePixel = 0
	local frame = create("Frame", props, children)
	corner(props.Radius or 12).Parent = frame
	stroke().Parent = frame
	return frame
end

local function text(props): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or BODY
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.TextSize = props.TextSize or 16
	props.TextWrapped = if props.TextWrapped == nil then true else props.TextWrapped
	return create("TextLabel", props) :: TextLabel
end

local function button(props, onClick: () -> ()): TextButton
	local color = props.BackgroundColor3 or THEME.PanelLight
	props.BackgroundColor3 = color
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.Font = props.Font or HEAVY
	props.TextColor3 = props.TextColor3 or THEME.Text
	props.TextSize = props.TextSize or 16
	local b = create("TextButton", props) :: TextButton
	corner(props.Radius or 10).Parent = b
	stroke(props.StrokeColor, 1.5, 0.45).Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.1), { BackgroundColor3 = color }):Play()
	end)
	b.Activated:Connect(function()
		Effects.Sound("Click", 0.3)
		onClick()
	end)
	return b
end

local function bar(props, fillColor: Color3)
	local back = create("Frame", { Name = props.Name, Position = props.Position, Size = props.Size, AnchorPoint = props.AnchorPoint, BackgroundColor3 = THEME.PanelDark, BorderSizePixel = 0, Parent = props.Parent })
	corner(6).Parent = back
	local fill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = fillColor, BorderSizePixel = 0, Parent = back })
	corner(6).Parent = fill
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(180, 180, 180)), Parent = fill })
	local label = text({ Name = "Label", Size = UDim2.fromScale(1, 1), TextSize = props.TextSize or 13, Font = HEAVY, TextStrokeTransparency = 0.5, Parent = back })
	return back, fill, label
end

local function rarityColor(rarity: number): Color3
	return Config.Rarities[rarity].Color
end

local function money(n: number): string
	return Format.Number(n)
end

---------------------------------------------------------------- Grundgeruest

local gui: ScreenGui
local root: Frame
local windows = {}
local openWindow: string? = nil

local toastHolder: Frame
local function showToast(message: string, color: Color3?)
	local pill = panel({
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = THEME.Panel,
		BackgroundTransparency = 0.05,
		Parent = toastHolder,
	})
	padding(6).Parent = pill
	text({ Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, Text = "  " .. message .. "  ", TextColor3 = color or THEME.Text, TextSize = 16, Font = HEAVY, Parent = pill })
	local children = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 4 then
		children[1]:Destroy()
	end
	task.delay(4, function()
		if pill.Parent then
			pill:Destroy()
		end
	end)
end
UI.Toast = showToast

local bigTitle: TextLabel
local bigSub: TextLabel
local function showTitle(title: string, sub: string?, color: Color3?)
	bigTitle.Text = title
	bigTitle.TextColor3 = color or THEME.Amber
	bigSub.Text = sub or ""
	bigTitle.TextTransparency = 0
	bigTitle.TextStrokeTransparency = 0
	bigSub.TextTransparency = 0
	bigTitle.Size = UDim2.fromOffset(700, 40)
	TweenService:Create(bigTitle, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(700, 64) }):Play()
	local token = os.clock()
	bigTitle:SetAttribute("Token", token)
	task.delay(2.6, function()
		if bigTitle:GetAttribute("Token") == token then
			TweenService:Create(bigTitle, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			TweenService:Create(bigSub, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

local function closeWindows()
	for _, window in windows do
		window.Visible = false
	end
	openWindow = nil
end

local function window(name: string, title: string, size: Vector2): (Frame, Frame)
	local frame = panel({
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		ZIndex = 20,
		Parent = root,
	})
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(THEME.PanelLight, THEME.Panel), Parent = frame })
	text({ Position = UDim2.fromOffset(18, 8), Size = UDim2.new(1, -80, 0, 40), Text = title, Font = TITLE, TextSize = 30, TextColor3 = THEME.Amber, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = frame })
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(36, 36), Text = "X", BackgroundColor3 = THEME.Red, ZIndex = 22, Parent = frame }, closeWindows)
	local body = create("Frame", { Name = "Body", Position = UDim2.fromOffset(14, 54), Size = UDim2.new(1, -28, 1, -66), BackgroundTransparency = 1, ZIndex = 21, Parent = frame })
	windows[name] = frame
	return frame, body
end

local renderers = {}
local function open(name: string)
	if openWindow == name then
		closeWindows()
		return
	end
	closeWindows()
	openWindow = name
	windows[name].Visible = true
	if renderers[name] then
		renderers[name]()
	end
end
UI.Open = open

local function request(action: string, ...): (any, any)
	local ok, result, extra = pcall(Request.InvokeServer, Request, action, ...)
	if not ok then
		return false, nil
	end
	return result, extra
end

---------------------------------------------------------------- HUD oben links: Held

local heroName: TextLabel
local emblem: Frame
local emblemText: TextLabel
local hpFill: Frame
local hpLabel: TextLabel
local xpFill: Frame
local xpLabel: TextLabel

local function buildHeroCard()
	local card = panel({ Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(310, 86), BackgroundTransparency = 0.08, Parent = root })
	emblem = create("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(66, 66), BackgroundColor3 = THEME.Blue, Parent = card })
	corner(33).Parent = emblem
	stroke(THEME.Amber, 2.5, 0).Parent = emblem
	emblemText = text({ Size = UDim2.fromScale(1, 1), Text = "K", Font = TITLE, TextSize = 36, Parent = emblem })
	heroName = text({ Position = UDim2.fromOffset(86, 6), Size = UDim2.new(1, -96, 0, 24), Text = "Knight", Font = HEAVY, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, Parent = card })
	local _, fill, label = bar({ Position = UDim2.fromOffset(86, 32), Size = UDim2.new(1, -98, 0, 22), Parent = card }, THEME.Red)
	hpFill, hpLabel = fill, label
	local _, xfill, xlabel = bar({ Position = UDim2.fromOffset(86, 60), Size = UDim2.new(1, -98, 0, 14), TextSize = 11, Parent = card }, THEME.Amber)
	xpFill, xpLabel = xfill, xlabel
end

local function refreshHero()
	local classKey = player:GetAttribute("Class") or "Knight"
	local class = Config.Classes[classKey]
	emblem.BackgroundColor3 = class.Color
	emblemText.Text = class.Name:sub(1, 1)
	heroName.Text = `{class.Name}  ·  Level {player:GetAttribute("Level") or 1}`
	local xp, need = player:GetAttribute("XP") or 0, math.max(1, player:GetAttribute("XPNeed") or 1)
	xpFill.Size = UDim2.fromScale(math.clamp(xp / need, 0, 1), 1)
	xpLabel.Text = if (player:GetAttribute("Level") or 1) >= Config.MaxLevel then "MAX LEVEL" else `XP {money(xp)} / {money(need)}`
end

---------------------------------------------------------------- HUD oben rechts: Waehrungen

local goldLabel: TextLabel
local shardLabel: TextLabel
local powerLabel: TextLabel
local boostLabel: TextLabel

local function pill(parent: Instance, order: number, color: Color3, caption: string): TextLabel
	local p = panel({ Size = UDim2.fromOffset(132, 38), LayoutOrder = order, BackgroundTransparency = 0.08, Parent = parent })
	local dot = create("Frame", { Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = color, Parent = p })
	corner(10).Parent = dot
	text({ Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(20, 20), Text = caption, Font = TITLE, TextSize = 13, TextColor3 = THEME.PanelDark, Parent = p })
	return text({ Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -40, 1, 0), Text = "0", Font = HEAVY, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, Parent = p })
end

local function buildCurrencies()
	local holder = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(420, 84), BackgroundTransparency = 1, Parent = root })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = holder })
	goldLabel = pill(holder, 1, THEME.Gold, "G")
	shardLabel = pill(holder, 2, THEME.Shard, "S")
	powerLabel = pill(holder, 3, Color3.fromRGB(255, 140, 90), "P")
	boostLabel = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 56), Size = UDim2.fromOffset(420, 22), Text = "", Font = HEAVY, TextSize = 14, TextColor3 = THEME.Green, TextXAlignment = Enum.TextXAlignment.Right, Parent = root })
end

local function refreshCurrencies()
	goldLabel.Text = money(player:GetAttribute("Gold") or 0)
	shardLabel.Text = money(player:GetAttribute("Shards") or 0)
	powerLabel.Text = money(player:GetAttribute("GearScore") or 0)
end

---------------------------------------------------------------- Dungeon-Banner und Bossleiste

local runBanner: Frame
local runTitle: TextLabel
local runProgress: TextLabel
local bossFrame: Frame
local bossName: TextLabel
local bossFill: Frame
local bossLabel: TextLabel
local trackedBoss: Model? = nil

local function buildRunBanner()
	runBanner = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(330, 56), BackgroundTransparency = 0.08, Visible = false, Parent = root })
	runTitle = text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 26), Font = TITLE, TextSize = 22, TextColor3 = THEME.Amber, Text = "", Parent = runBanner })
	runProgress = text({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), Font = HEAVY, TextSize = 15, TextColor3 = THEME.Muted, Text = "", Parent = runBanner })
	bossFrame = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 74), Size = UDim2.fromOffset(460, 50), BackgroundTransparency = 1, Visible = false, Parent = root })
	bossName = text({ Size = UDim2.new(1, 0, 0, 24), Font = TITLE, TextSize = 22, TextColor3 = THEME.Red, TextStrokeTransparency = 0.4, Text = "", Parent = bossFrame })
	local _, fill, label = bar({ Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 20), Parent = bossFrame }, Color3.fromRGB(220, 70, 90))
	bossFill, bossLabel = fill, label
end

local function refreshRun()
	local run = state.Run
	runBanner.Visible = run ~= nil
	if not run then
		bossFrame.Visible = false
		return
	end
	local dungeon = Config.Dungeons[run.Dungeon]
	local difficulty = Config.Difficulties[run.Difficulty]
	runTitle.Text = `{dungeon.Name:upper()}  ·  {difficulty.Name:upper()}`
	runTitle.TextColor3 = difficulty.Color
	local featured = if run.Featured then "  ·  +50% FEATURED" else ""
	if run.Boss then
		runProgress.Text = `BOSS ROOM  ·  Monster level {run.Level}{featured}`
	elseif run.Room == 0 then
		runProgress.Text = `Get ready!  ·  Party {run.Party}/{Config.MaxPartySize}{featured}`
	else
		runProgress.Text = `Room {run.Room}/{run.Rooms - 1}  ·  Wave {math.max(1, run.Wave)}/{run.Waves}  ·  Party {run.Party}{featured}`
	end
end

---------------------------------------------------------------- Kampfknoepfe

local skillButtons = {}
local attackButton: TextButton
local potionButton: TextButton
local autoButton: TextButton
local combatFrame: Frame

local function nearestMonster(range: number): Model?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local folder = workspace:FindFirstChild("Monsters")
	if not rootPart or not folder then
		return nil
	end
	local best, bestDistance = nil, range
	for _, model in folder:GetChildren() do
		local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r then
			local d = ((r.Position - rootPart.Position) * Vector3.new(1, 0, 1)).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

local function faceTarget(model: Model?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart or not target then
		return
	end
	local look = Vector3.new(target.Position.X, rootPart.Position.Y, target.Position.Z)
	if (look - rootPart.Position).Magnitude > 0.5 then
		humanoid.AutoRotate = false
		rootPart.CFrame = CFrame.lookAt(rootPart.Position, look)
		task.delay(0.35, function()
			humanoid.AutoRotate = true
		end)
	end
end

local function classDef()
	return Config.Classes[player:GetAttribute("Class") or "Knight"] or Config.Classes.Knight
end

local function alive(): boolean
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function tryAttack()
	if not state.Run or not alive() then
		return
	end
	local now = os.clock()
	if now < state.Cooldowns.Attack then
		return
	end
	local class = classDef()
	local target = nearestMonster(class.Range + 2)
	if not target then
		return
	end
	local speed = 1 + (player:GetAttribute("Stat_AttackSpeed") or 0) / 100
	state.Cooldowns.Attack = now + class.Attack.Cooldown / speed
	faceTarget(target)
	remotes.Attack:FireServer(target)
end

local function trySkill(index: number)
	if not state.Run or not alive() then
		return
	end
	local now = os.clock()
	if now < state.Cooldowns[index] then
		return
	end
	local class = classDef()
	local skill = class.Skills[index]
	local target = nearestMonster(class.Range + 2)
	if skill.Kind == "Volley" and not target then
		showToast("No enemy in range", THEME.Muted)
		return
	end
	state.Cooldowns[index] = now + skill.Cooldown * (1 - (player:GetAttribute("Stat_Cooldown") or 0) / 100)
	faceTarget(target)
	remotes.Skill:FireServer(index, target)
end

local function tryPotion()
	if not alive() then
		return
	end
	local now = os.clock()
	if now < state.Cooldowns.Potion then
		return
	end
	state.Cooldowns.Potion = now + Config.PotionCooldownFor(player:GetAttribute("PotionLevel") or 0)
	task.spawn(request, "Potion")
end

local function combatButton(props, onClick: () -> ()): TextButton
	local b = button(props, onClick)
	local shade = create("Frame", { Name = "Shade", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, ZIndex = (props.ZIndex or 1) + 1, Parent = b })
	corner(props.Radius or 10).Parent = shade
	text({ Name = "Timer", Size = UDim2.fromScale(1, 1), Text = "", Font = TITLE, TextSize = 22, ZIndex = (props.ZIndex or 1) + 2, Parent = b })
	return b
end

local function buildCombat()
	combatFrame = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18), Size = UDim2.fromOffset(270, 230), BackgroundTransparency = 1, Visible = false, Parent = root })
	attackButton = combatButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(112, 112), Radius = 56, Text = "ATTACK", Font = TITLE, TextSize = 22, BackgroundColor3 = Color3.fromRGB(150, 60, 50), StrokeColor = THEME.Amber, Parent = combatFrame }, tryAttack)
	local holding = false
	attackButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
			task.spawn(function()
				while holding do
					tryAttack()
					task.wait(0.05)
				end
			end)
		end
	end)
	attackButton.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	skillButtons[1] = combatButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -124, 1, -6), Size = UDim2.fromOffset(74, 74), Radius = 37, Text = "", TextSize = 13, BackgroundColor3 = THEME.PanelLight, Parent = combatFrame }, function()
		trySkill(1)
	end)
	skillButtons[2] = combatButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -124), Size = UDim2.fromOffset(74, 74), Radius = 37, Text = "", TextSize = 13, BackgroundColor3 = THEME.PanelLight, Parent = combatFrame }, function()
		trySkill(2)
	end)
	potionButton = combatButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -112, 1, -108), Size = UDim2.fromOffset(56, 56), Radius = 28, Text = "HEAL", Font = TITLE, TextSize = 15, BackgroundColor3 = Color3.fromRGB(60, 140, 80), Parent = combatFrame }, tryPotion)
	autoButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -196, 1, -96), Size = UDim2.fromOffset(64, 30), Text = "AUTO", TextSize = 14, BackgroundColor3 = THEME.PanelLight, Parent = combatFrame }, function()
		state.AutoAttack = not state.AutoAttack
		autoButton.BackgroundColor3 = if state.AutoAttack then Color3.fromRGB(60, 140, 80) else THEME.PanelLight
		autoButton.Text = if state.AutoAttack then "AUTO ON" else "AUTO"
	end)
	-- Gruppen-Signale: kleiner Knopf, oeffnet eine Reihe fester Rufe
	local pingMenu = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -276, 1, 0), Size = UDim2.fromOffset(92, #Config.Pings * 38), BackgroundTransparency = 1, Visible = false, Parent = combatFrame })
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pingMenu })
	for i, caption in Config.Pings do
		button({ Size = UDim2.fromOffset(92, 34), Text = caption, TextSize = 15, LayoutOrder = i, BackgroundColor3 = Color3.fromRGB(50, 90, 150), Parent = pingMenu }, function()
			pingMenu.Visible = false
			task.spawn(request, "Ping", i)
		end)
	end
	button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -200, 1, -60), Size = UDim2.fromOffset(64, 30), Text = "PING", TextSize = 14, BackgroundColor3 = Color3.fromRGB(50, 90, 150), Parent = combatFrame }, function()
		pingMenu.Visible = not pingMenu.Visible
	end)
	local keyboard = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	if keyboard then
		text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, -116), Size = UDim2.fromOffset(112, 18), Text = "Click / hold", TextSize = 12, TextColor3 = THEME.Muted, Parent = combatFrame })
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.One then
			trySkill(1)
		elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Two then
			trySkill(2)
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.Three then
			tryPotion()
		elseif input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.I then
			open("Bag")
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = true
			task.spawn(function()
				while holding do
					tryAttack()
					task.wait(0.05)
				end
			end)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	-- Automatischer Grundangriff (fuer Handy-Spieler sehr bequem)
	task.spawn(function()
		while true do
			task.wait(0.1)
			if state.AutoAttack then
				tryAttack()
			end
		end
	end)
end

local function refreshSkillLabels()
	local class = classDef()
	local keyboard = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	for i, b in skillButtons do
		local skill = class.Skills[i]
		b.Text = skill.Name:upper() .. (if keyboard then (if i == 1 then "\n[Q]" else "\n[E]") else "")
		b.BackgroundColor3 = class.Color:Lerp(THEME.Panel, 0.45)
	end
	potionButton.Text = if keyboard then "HEAL\n[F]" else "HEAL"
end

local function updateCooldowns()
	local now = os.clock()
	local class = classDef()
	local cdMult = 1 - (player:GetAttribute("Stat_Cooldown") or 0) / 100
	local function show(b: TextButton, readyAt: number, total: number)
		local left = readyAt - now
		local shade = b:FindFirstChild("Shade") :: Frame
		local timer = b:FindFirstChild("Timer") :: TextLabel
		if left > 0 then
			shade.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
			timer.Text = if left >= 1 then tostring(math.ceil(left)) else ""
		else
			shade.Size = UDim2.fromScale(1, 0)
			timer.Text = ""
		end
	end
	show(skillButtons[1], state.Cooldowns[1], class.Skills[1].Cooldown * cdMult)
	show(skillButtons[2], state.Cooldowns[2], class.Skills[2].Cooldown * cdMult)
	show(potionButton, state.Cooldowns.Potion, Config.PotionCooldownFor(player:GetAttribute("PotionLevel") or 0))
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local max = math.max(1, humanoid.MaxHealth)
		hpFill.Size = UDim2.fromScale(math.clamp(humanoid.Health / max, 0, 1), 1)
		hpLabel.Text = `{money(math.max(0, humanoid.Health))} / {money(max)}`
	end
	-- Bossleiste
	if state.Run and state.Run.Boss then
		if not trackedBoss or not trackedBoss.Parent then
			trackedBoss = nil
			local folder = workspace:FindFirstChild("Monsters")
			for _, model in (folder and folder:GetChildren() or {}) do
				if model:GetAttribute("Boss") then
					local r = model:FindFirstChild("HumanoidRootPart") :: BasePart?
					local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if r and me and (r.Position - me.Position).Magnitude < 200 then
						trackedBoss = model
					end
				end
			end
		end
	else
		trackedBoss = nil
	end
	bossFrame.Visible = trackedBoss ~= nil
	if trackedBoss then
		local hp = trackedBoss:GetAttribute("Health") or 0
		local max = math.max(1, tonumber(trackedBoss:GetAttribute("MaxHealth")) or 1)
		bossName.Text = tostring(trackedBoss:GetAttribute("DisplayName") or "Boss"):upper()
		bossFill.Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1)
		bossLabel.Text = `{money(hp)} / {money(max)}`
	end
	-- Boost-Anzeige
	local boosts = {}
	local xpLeft = (player:GetAttribute("XPBoostUntil") or 0) - os.time()
	if xpLeft > 0 then
		table.insert(boosts, `2x XP {Format.Time(xpLeft)}`)
	end
	if player:GetAttribute("Pass_DoubleXP") then
		table.insert(boosts, "2x XP forever")
	end
	if player:GetAttribute("Pass_VIP") then
		table.insert(boosts, "VIP +25%")
	end
	local friends = player:GetAttribute("Friends") or 0
	if friends > 0 then
		table.insert(boosts, `Friends +{friends * 10}%`)
	end
	if (player:GetAttribute("Blessing") or 0) > 0 then
		table.insert(boosts, "Boss Blessing ready")
	end
	local serverNow = workspace:GetServerTimeNow()
	for _, key in Config.ShrineOrder do
		local left = (tonumber(player:GetAttribute("Buff_" .. key)) or 0) - serverNow
		if left > 0 then
			table.insert(boosts, `{Config.Shrines[key].Text} {math.ceil(left)}s`)
		end
	end
	boostLabel.Text = table.concat(boosts, "   ·   ")
end

---------------------------------------------------------------- Linkes Menue

local bagBadge: TextLabel
local adButton: TextButton

local questBadge: TextLabel

local function invite()
	local ok, canInvite = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if not ok or not canInvite then
		showToast("Invites are not available on this device.", THEME.Red)
		return
	end
	local options = Instance.new("ExperienceInviteOptions")
	options.PromptMessage = "Join my party in Lantern Legends! Friends give +10% gold and XP."
	pcall(SocialService.PromptGameInvite, SocialService, player, options)
end

local function menuButton(parent: Instance, order: number, caption: string, color: Color3, onClick: () -> ()): (TextButton, TextLabel)
	local b = button({ Size = UDim2.fromOffset(64, 50), LayoutOrder = order, Text = caption, Font = TITLE, TextSize = 14, BackgroundColor3 = color, Parent = parent }, onClick)
	local badge = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 0, BackgroundColor3 = THEME.Red, Text = "!", Font = TITLE, TextSize = 13, Visible = false, Parent = b })
	corner(11).Parent = badge
	return b, badge
end

local function buildMenu()
	local holder = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 40), Size = UDim2.fromOffset(64, 400), BackgroundTransparency = 1, Parent = root })
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = holder })
	local _, badge = menuButton(holder, 1, "BAG", Color3.fromRGB(110, 76, 52), function()
		open("Bag")
	end)
	bagBadge = badge
	menuButton(holder, 2, "FORGE", Color3.fromRGB(150, 80, 50), function()
		open("Forge")
	end)
	menuButton(holder, 3, "SHOP", Color3.fromRGB(170, 120, 30), function()
		open("Shop")
	end)
	menuButton(holder, 4, "CLASS", Color3.fromRGB(100, 70, 160), function()
		open("Class")
	end)
	local _, qBadge = menuButton(holder, 5, "QUESTS", Color3.fromRGB(60, 120, 90), function()
		open("Quests")
	end)
	questBadge = qBadge
	menuButton(holder, 6, "MORE", Color3.fromRGB(50, 120, 160), function()
		open("More")
	end)
	adButton = menuButton(holder, 7, "FREE\nGOLD", Color3.fromRGB(60, 140, 80), function()
		adButton.Visible = false
		task.spawn(request, "WatchAd", "Gold")
	end)
	adButton.Visible = false
	task.spawn(function()
		while gui.Parent do
			local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			adButton.Visible = ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
			task.wait(30)
		end
	end)
end

---------------------------------------------------------------- Inventar

local bagGrid: ScrollingFrame
local bagDetail: Frame
local bagSlots = {}
local bagStats: TextLabel
local bagCapacity: TextLabel
local autoSalvageButton: TextButton

local SLOT_SHORT = { Weapon = "WEAPON", Helmet = "HELM", Armor = "ARMOR", Boots = "BOOTS", Amulet = "AMULET", Ring = "RING" }
local AUTO_NAMES = { [0] = "Auto-salvage: Off", "Auto-salvage: Common", "Auto-salvage: Uncommon", "Auto-salvage: Rare" }

local function equippedItem(slot: string)
	local id = state.Equipped[slot]
	for _, item in state.Items do
		if item.Id == id then
			return item
		end
	end
	return nil
end

local function isBetter(item): boolean
	local current = equippedItem(item.Slot)
	return current == nil or (current.Id ~= item.Id and Items.Power(item) > Items.Power(current))
end

local function itemCell(parent: Instance, item, size: number, onClick: () -> ()): TextButton
	local color = rarityColor(item.Rarity)
	local cell = create("TextButton", { Size = UDim2.fromOffset(size, size), BackgroundColor3 = color:Lerp(THEME.PanelDark, 0.72), AutoButtonColor = true, Text = "", Parent = parent }) :: TextButton
	corner(8).Parent = cell
	stroke(color, 2, 0.1).Parent = cell
	create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.25), Parent = cell })
	text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 14), Text = SLOT_SHORT[item.Slot], Font = HEAVY, TextSize = 11, TextColor3 = color, Parent = cell })
	text({ Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 24), Text = "Lv " .. item.Level, Font = TITLE, TextSize = 18, Parent = cell })
	text({ Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 14), Text = (if item.Plus > 0 then "+" .. item.Plus .. "  " else "") .. Items.Power(item), Font = HEAVY, TextSize = 11, TextColor3 = THEME.Muted, Parent = cell })
	if isBetter(item) then
		text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 2), Size = UDim2.fromOffset(16, 16), Text = "▲", TextSize = 13, TextColor3 = THEME.Green, Parent = cell })
	end
	if item.Locked then
		text({ Position = UDim2.fromOffset(3, 2), Size = UDim2.fromOffset(16, 16), Text = "•", TextSize = 18, TextColor3 = THEME.Gold, Parent = cell })
	end
	if state.Equipped[item.Slot] == item.Id then
		stroke(THEME.Amber, 3, 0).Parent = cell
	end
	cell.Activated:Connect(onClick)
	return cell
end

local function statLines(item): { string }
	local lines = {}
	local base = Items.BaseStats(item)
	for _, key in { "Damage", "Health", "Armor", "Crit" } do
		if base[key] then
			table.insert(lines, if key == "Crit" then `+{base[key]}% Crit Chance` else `+{base[key]} {key}`)
		end
	end
	for _, affix in item.Affixes do
		table.insert(lines, Items.AffixText(affix))
	end
	return lines
end

local function compareText(item): string
	local current = equippedItem(item.Slot)
	if not current or current.Id == item.Id then
		return ""
	end
	local a = Items.TotalStats(player:GetAttribute("Class") or "Knight", player:GetAttribute("Level") or 1, { item })
	local b = Items.TotalStats(player:GetAttribute("Class") or "Knight", player:GetAttribute("Level") or 1, { current })
	local parts = {}
	for _, key in { "Damage", "Health", "Armor", "Crit", "CritDamage", "AttackSpeed", "MoveSpeed", "Cooldown" } do
		local diff = math.floor(((a :: any)[key] - (b :: any)[key]) * 10 + 0.5) / 10
		if diff ~= 0 then
			local colorHex = if diff > 0 then "#6EDE8C" else "#F05454"
			table.insert(parts, `<font color="{colorHex}">{if diff > 0 then "+" else ""}{diff} {key}</font>`)
		end
	end
	return if #parts > 0 then "vs equipped: " .. table.concat(parts, "  ") else "Same as equipped"
end

local renderBag

local function showDetail(item)
	state.Selected = item and item.Id
	for _, child in bagDetail:GetChildren() do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	if not item then
		text({ Size = UDim2.fromScale(1, 1), Text = "Tap an item to see its stats.", TextColor3 = THEME.Muted, Parent = bagDetail })
		return
	end
	local classKey = player:GetAttribute("Class") or "Knight"
	local rarity = Config.Rarities[item.Rarity]
	text({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26), Text = Items.DisplayName(item, classKey), Font = TITLE, TextSize = 22, TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = bagDetail })
	text({ Position = UDim2.fromOffset(10, 32), Size = UDim2.new(1, -20, 0, 18), Text = `{rarity.Name} {item.Slot}  ·  Item level {item.Level}  ·  Power {Items.Power(item)}`, TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = bagDetail })
	local lines = statLines(item)
	if item.Power then
		table.insert(lines, `<font color="#FFA028">{Config.Powers[item.Power].Text}</font>`)
	end
	text({ Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 96), Text = table.concat(lines, "\n"), RichText = true, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = bagDetail })
	text({ Position = UDim2.new(0, 10, 1, -66), Size = UDim2.new(1, -20, 0, 22), Text = compareText(item), RichText = true, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = bagDetail })
	local equipped = state.Equipped[item.Slot] == item.Id
	button({ Position = UDim2.new(0, 10, 1, -40), Size = UDim2.fromOffset(110, 32), Text = if equipped then "EQUIPPED" else "EQUIP", BackgroundColor3 = if equipped then THEME.PanelDark else Color3.fromRGB(60, 140, 80), Parent = bagDetail }, function()
		if not equipped then
			request("Equip", item.Id)
		end
	end)
	button({ Position = UDim2.new(0, 128, 1, -40), Size = UDim2.fromOffset(90, 32), Text = if item.Locked then "UNLOCK" else "LOCK", Parent = bagDetail }, function()
		request("Lock", item.Id)
	end)
	if not equipped and not item.Locked then
		local shards = Config.SalvageValue(item.Level, item.Rarity)
		button({ Position = UDim2.new(0, 226, 1, -40), Size = UDim2.fromOffset(150, 32), Text = `SALVAGE +{shards}`, BackgroundColor3 = Color3.fromRGB(120, 60, 60), Parent = bagDetail }, function()
			state.Selected = nil
			request("Salvage", { item.Id })
		end)
	end
end

renderBag = function()
	if not bagGrid then
		return
	end
	for _, child in bagGrid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local list = table.clone(state.Items)
	table.sort(list, function(a, b)
		local ea, eb = state.Equipped[a.Slot] == a.Id, state.Equipped[b.Slot] == b.Id
		if ea ~= eb then
			return ea
		end
		return Items.Power(a) > Items.Power(b)
	end)
	local selected
	for _, item in list do
		if state.Equipped[item.Slot] ~= item.Id then
			itemCell(bagGrid, item, 64, function()
				showDetail(item)
			end)
		end
		if item.Id == state.Selected then
			selected = item
		end
	end
	for slot, frame in bagSlots do
		for _, child in frame:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local item = equippedItem(slot)
		if item then
			local cell = itemCell(frame, item, 64, function()
				showDetail(item)
			end)
			cell.Position = UDim2.fromOffset(0, 0)
		end
	end
	local count = #state.Items
	bagCapacity.Text = `{count}/{state.Capacity}`
	bagCapacity.TextColor3 = if count >= state.Capacity then THEME.Red else THEME.Muted
	local s = {
		`Damage {money(player:GetAttribute("Stat_Damage") or 0)}`,
		`Health {money(player:GetAttribute("Stat_Health") or 0)}`,
		`Armor {money(player:GetAttribute("Stat_Armor") or 0)}`,
		`Crit {player:GetAttribute("Stat_Crit") or 0}%  ·  Crit dmg {player:GetAttribute("Stat_CritDamage") or 0}%`,
		`Attack speed +{player:GetAttribute("Stat_AttackSpeed") or 0}%`,
		`Move +{player:GetAttribute("Stat_MoveSpeed") or 0}%  ·  Cooldown -{player:GetAttribute("Stat_Cooldown") or 0}%`,
		`Gold find +{player:GetAttribute("Stat_GoldFind") or 0}%`,
	}
	local powers = player:GetAttribute("Powers") or ""
	if powers ~= "" then
		for key in powers:gmatch("[^,]+") do
			table.insert(s, `<font color="#FFA028">{Config.Powers[key].Title}</font>`)
		end
	end
	bagStats.Text = table.concat(s, "\n")
	autoSalvageButton.Text = AUTO_NAMES[player:GetAttribute("AutoSalvage") or 0]
	showDetail(selected)
end
renderers.Bag = renderBag

local function buildBag()
	local frame, body = window("Bag", "BAG", Vector2.new(820, 500))
	frame.ZIndex = 20
	-- Links: Ausruestung und Werte
	local left = create("Frame", { Size = UDim2.new(0, 230, 1, 0), BackgroundTransparency = 1, Parent = body })
	for i, slot in Config.Slots do
		local col, row = (i - 1) % 3, (i - 1) // 3
		local holder = create("Frame", { Position = UDim2.fromOffset(col * 76, row * 90), Size = UDim2.fromOffset(64, 84), BackgroundTransparency = 1, Parent = left })
		local empty = create("Frame", { Size = UDim2.fromOffset(64, 64), BackgroundColor3 = THEME.PanelDark, Parent = holder })
		corner(8).Parent = empty
		stroke(THEME.Muted, 1, 0.6).Parent = empty
		text({ Size = UDim2.fromOffset(64, 64), Text = SLOT_SHORT[slot], TextSize = 11, TextColor3 = THEME.Muted, Parent = empty })
		text({ Position = UDim2.fromOffset(0, 66), Size = UDim2.fromOffset(64, 16), Text = slot, TextSize = 11, TextColor3 = THEME.Muted, Parent = holder })
		bagSlots[slot] = holder
	end
	bagStats = text({ Position = UDim2.fromOffset(0, 186), Size = UDim2.new(1, 0, 1, -186), Text = "", RichText = true, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = left })
	-- Rechts: Werkzeuge, Raster, Details
	local right = create("Frame", { Position = UDim2.fromOffset(244, 0), Size = UDim2.new(1, -244, 1, 0), BackgroundTransparency = 1, Parent = body })
	local tools = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = right })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tools })
	button({ Size = UDim2.fromOffset(112, 32), Text = "EQUIP BEST", TextSize = 14, BackgroundColor3 = Color3.fromRGB(60, 140, 80), LayoutOrder = 1, Parent = tools }, function()
		local _, changed = request("EquipBest")
		showToast(if (changed or 0) > 0 then `Equipped {changed} better item(s)!` else "You already wear your best gear.", THEME.Green)
	end)
	button({ Size = UDim2.fromOffset(150, 32), Text = "SALVAGE COMMON+UNC.", TextSize = 12, BackgroundColor3 = Color3.fromRGB(120, 60, 60), LayoutOrder = 2, Parent = tools }, function()
		local count, shards = request("SalvageUpTo", 2)
		if (count or 0) > 0 then
			showToast(`Salvaged {count} items for {shards} shards.`, THEME.Shard)
		end
	end)
	autoSalvageButton = button({ Size = UDim2.fromOffset(170, 32), Text = AUTO_NAMES[0], TextSize = 12, LayoutOrder = 3, Parent = tools }, function()
		local level = ((player:GetAttribute("AutoSalvage") or 0) + 1) % 4
		request("SetAutoSalvage", level)
		autoSalvageButton.Text = AUTO_NAMES[level]
	end)
	bagCapacity = text({ Size = UDim2.fromOffset(70, 32), Text = "0/50", Font = HEAVY, TextSize = 15, LayoutOrder = 4, Parent = tools })
	bagGrid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42 - 176),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = right,
	}) :: ScrollingFrame
	corner(8).Parent = bagGrid
	padding(6).Parent = bagGrid
	create("UIGridLayout", { CellSize = UDim2.fromOffset(64, 64), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = bagGrid })
	bagDetail = create("Frame", { Position = UDim2.new(0, 0, 1, -168), Size = UDim2.new(1, 0, 0, 168), BackgroundColor3 = THEME.PanelDark, BackgroundTransparency = 0.2, Parent = right })
	corner(10).Parent = bagDetail
	stroke(THEME.Border, 1, 0.6).Parent = bagDetail
	showDetail(nil)
end

---------------------------------------------------------------- Schmiede

local forgeList: Frame

local function renderForge()
	for _, child in forgeList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local classKey = player:GetAttribute("Class") or "Knight"
	for i, slot in Config.Slots do
		local item = equippedItem(slot)
		local row = panel({ Size = UDim2.new(1, 0, 0, 52), LayoutOrder = i, BackgroundColor3 = THEME.PanelDark, Parent = forgeList })
		if not item then
			text({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), Text = `{slot}: nothing equipped`, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			continue
		end
		text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.55, 0, 0, 24), Text = Items.DisplayName(item, classKey), Font = HEAVY, TextSize = 17, TextColor3 = rarityColor(item.Rarity), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, Parent = row })
		if item.Plus >= Config.MaxPlus then
			text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(0.55, 0, 0, 18), Text = "Maximum reached", TextSize = 13, TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			continue
		end
		local gold, shards = Config.EnhanceCost(item.Level, item.Plus, item.Rarity)
		text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(0.6, 0, 0, 18), Text = `+{item.Plus} -> +{item.Plus + 1}: +8% base stats  ·  {money(gold)} gold, {shards} shards`, TextSize = 13, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, Parent = row })
		local affordable = (player:GetAttribute("Gold") or 0) >= gold and (player:GetAttribute("Shards") or 0) >= shards
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 34), Text = "ENHANCE", BackgroundColor3 = if affordable then Color3.fromRGB(190, 110, 40) else THEME.PanelLight, Parent = row }, function()
			local ok, reason = request("Enhance", slot)
			if not ok then
				showToast(reason or "Not possible right now.", THEME.Red)
				if (player:GetAttribute("Shards") or 0) < shards then
					open("Shop")
				end
			end
		end)
	end
	-- Trank-Meisterschaft (Gold-Upgrade)
	local level = player:GetAttribute("PotionLevel") or 0
	local row = panel({ Size = UDim2.new(1, 0, 0, 52), LayoutOrder = #Config.Slots + 1, BackgroundColor3 = Color3.fromRGB(24, 44, 36), Parent = forgeList })
	text({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.6, 0, 0, 24), Text = `Potion Mastery {level}/{Config.PotionMaxLevel}`, Font = HEAVY, TextSize = 17, TextColor3 = THEME.Green, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, Parent = row })
	local now = `heals {math.floor(Config.PotionHealFor(level) * 100)}%, {Config.PotionCooldownFor(level)}s`
	if level >= Config.PotionMaxLevel then
		text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(0.6, 0, 0, 18), Text = `Maximum reached: {now}`, TextSize = 13, TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	else
		local cost = Config.PotionUpgradeCost(level)
		text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(0.62, 0, 0, 18), Text = `Now {now}  ·  next: +5% heal, -1s  ·  {money(cost)} gold`, TextSize = 13, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, Parent = row })
		local affordable = (player:GetAttribute("Gold") or 0) >= cost
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 34), Text = "UPGRADE", BackgroundColor3 = if affordable then Color3.fromRGB(60, 140, 80) else THEME.PanelLight, Parent = row }, function()
			local ok, reason = request("UpgradePotion")
			if not ok then
				showToast(reason or "Not possible right now.", THEME.Red)
			end
		end)
	end
end
renderers.Forge = renderForge

local function buildForge()
	local _, body = window("Forge", "FORGE", Vector2.new(640, 500))
	text({ Size = UDim2.new(1, 0, 0, 22), Text = "Enhance your equipped gear with gold and shards. Salvage items in your bag to get shards.", TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	forgeList = create("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), BackgroundTransparency = 1, Parent = body })
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = forgeList })
end

---------------------------------------------------------------- Shop

local shopTab = "Passes"
local shopList: ScrollingFrame
local shopTabs = {}

local function shopCard(order: number, name: string, description: string, price: number, owned: boolean, onBuy: () -> ())
	local card = panel({ Size = UDim2.new(1, -8, 0, 66), LayoutOrder = order, BackgroundColor3 = THEME.PanelDark, Parent = shopList })
	text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -170, 0, 26), Text = name, Font = TITLE, TextSize = 20, TextColor3 = THEME.Amber, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	text({ Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -170, 0, 28), Text = description, TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 40), Text = if owned then "OWNED" else `R$ {price}`, Font = TITLE, TextSize = 18, BackgroundColor3 = if owned then THEME.PanelLight else Color3.fromRGB(60, 150, 80), Parent = card }, function()
		if not owned then
			onBuy()
		end
	end)
end

local function priceOf(id: number, hint: number): number
	return if id ~= 0 then (state.Prices[id] or hint) else hint
end
state.Prices = {}

local function renderShop()
	for _, child in shopList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for name, tab in shopTabs do
		tab.BackgroundColor3 = if name == shopTab then THEME.Amber else THEME.PanelLight
		tab.TextColor3 = if name == shopTab then THEME.PanelDark else THEME.Text
	end
	local restricted = player:GetAttribute("RandomRestricted") == true
	if shopTab == "Passes" then
		local list = {}
		for key, pass in Config.GamePasses do
			if not (pass.AffectsRandom and restricted) then
				table.insert(list, { Key = key, Def = pass })
			end
		end
		table.sort(list, function(a, b)
			return a.Def.Order < b.Def.Order
		end)
		for i, entry in list do
			shopCard(i, entry.Def.Name, entry.Def.Description, priceOf(entry.Def.ProductId, entry.Def.PriceHint), player:GetAttribute("Pass_" .. entry.Key) == true, function()
				request("BuyPass", entry.Key)
			end)
		end
	else
		local list = {}
		for key, product in Config.DevProducts do
			local isGold = product.Kind == "Gold" or product.Kind == "Shards"
			if not product.Hidden and not (product.AffectsRandom and restricted) and (shopTab == "Gold") == isGold then
				table.insert(list, { Key = key, Def = product })
			end
		end
		table.sort(list, function(a, b)
			return a.Def.Order < b.Def.Order
		end)
		for i, entry in list do
			local description = entry.Def.Description
			if entry.Def.Kind == "Gold" then
				local level = player:GetAttribute("Level") or 1
				local amount = math.floor(math.max(entry.Def.MinGold, Config.KillGold(level) * 120 * entry.Def.Runs))
				description = `{money(amount)} gold  ·  {description}`
			end
			shopCard(i, entry.Def.Name, description, priceOf(entry.Def.Id, entry.Def.PriceHint), false, function()
				request("BuyProduct", entry.Key)
			end)
		end
	end
end
renderers.Shop = renderShop

local function buildShop()
	local _, body = window("Shop", "SHOP", Vector2.new(640, 460))
	local tabs = create("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = body })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	for i, name in { "Passes", "Boosts", "Gold" } do
		shopTabs[name] = button({ Size = UDim2.fromOffset(130, 34), Text = name:upper(), Font = TITLE, TextSize = 17, LayoutOrder = i, Parent = tabs }, function()
			shopTab = name
			renderShop()
		end)
	end
	shopList = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = body }) :: ScrollingFrame
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = shopList })
	-- Echte Preise nachladen (falls im Creator Hub geaendert)
	task.spawn(function()
		local ids = {}
		for _, pass in Config.GamePasses do
			table.insert(ids, pass.ProductId)
		end
		for _, product in Config.DevProducts do
			table.insert(ids, product.Id)
		end
		for _, id in ids do
			if id ~= 0 then
				local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, Enum.InfoType.Product)
				if ok and info and info.PriceInRobux then
					state.Prices[id] = info.PriceInRobux
				end
			end
		end
	end)
end

---------------------------------------------------------------- Klassenwahl

local classCards: Frame

local function renderClass()
	for _, child in classCards:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local current = player:GetAttribute("Class") or "Knight"
	for i, key in Config.ClassOrder do
		local class = Config.Classes[key]
		local card = panel({ Size = UDim2.fromOffset(176, 330), LayoutOrder = i, BackgroundColor3 = THEME.PanelDark, Parent = classCards })
		local header = create("Frame", { Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = class.Color, Parent = card })
		corner(12).Parent = header
		text({ Size = UDim2.new(1, 0, 0, 74), Text = class.Name:upper(), Font = TITLE, TextSize = 24, TextStrokeTransparency = 0.4, Parent = header })
		text({ Position = UDim2.fromOffset(10, 82), Size = UDim2.new(1, -20, 0, 80), Text = class.Description, TextSize = 14, TextColor3 = THEME.Muted, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		local skills = {}
		for _, skill in class.Skills do
			table.insert(skills, "- " .. skill.Name)
		end
		text({ Position = UDim2.fromOffset(10, 166), Size = UDim2.new(1, -20, 0, 60), Text = `Health {class.Health}  ·  Range {class.Range}\n` .. table.concat(skills, "\n"), TextSize = 14, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		local locked = class.UnlockLevel and (player:GetAttribute("Level") or 1) < class.UnlockLevel and not player:GetAttribute("Pass_Lightbringer")
		local caption = if key == current then "SELECTED" elseif locked then `LV {class.UnlockLevel} OR R$` else "CHOOSE"
		button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 40), Text = caption, Font = TITLE, TextSize = 17, BackgroundColor3 = if key == current then THEME.PanelLight elseif locked then Color3.fromRGB(170, 120, 30) else Color3.fromRGB(60, 140, 80), Parent = card }, function()
			if key == current then
				return
			end
			if state.Run then
				showToast("Change your class in town.", THEME.Red)
				return
			end
			if request("SetClass", key) then
				closeWindows()
				showTitle(class.Name:upper(), "Your new class is ready!", class.Color)
			end
		end)
	end
end
renderers.Class = renderClass

local function buildClass()
	local _, body = window("Class", "CHOOSE YOUR CLASS", Vector2.new(780, 420))
	classCards = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = classCards })
end

---------------------------------------------------------------- Lobby

local lobbyFrame: Frame
local lobbyTitle: TextLabel
local lobbyInfo: TextLabel
local lobbyExtra: TextLabel
local lobbyButtons = {}
local lobbyStart: TextButton

local function buildLobby()
	lobbyFrame = panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(470, 172), Visible = false, Parent = root })
	lobbyTitle = text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 28), Font = TITLE, TextSize = 24, TextColor3 = THEME.Amber, Parent = lobbyFrame })
	lobbyInfo = text({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 20), Font = HEAVY, TextSize = 15, TextColor3 = THEME.Muted, Parent = lobbyFrame })
	lobbyExtra = text({ Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18), Font = HEAVY, TextSize = 14, TextColor3 = THEME.Gold, Parent = lobbyFrame })
	local row = create("Frame", { Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -24, 0, 36), BackgroundTransparency = 1, Parent = lobbyFrame })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	for i, difficulty in Config.Difficulties do
		lobbyButtons[i] = button({ Size = UDim2.fromOffset(140, 34), Text = difficulty.Name:upper(), Font = TITLE, TextSize = 16, LayoutOrder = i, Parent = row }, function()
			request("SetDifficulty", i)
		end)
	end
	lobbyStart = button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 126), Size = UDim2.fromOffset(200, 36), Text = "START NOW", Font = TITLE, TextSize = 18, BackgroundColor3 = Color3.fromRGB(60, 140, 80), Parent = lobbyFrame }, function()
		request("StartNow")
	end)
end

local function refreshLobby()
	local lobby = state.Lobby
	lobbyFrame.Visible = lobby ~= nil and state.Run == nil
	if not lobby then
		return
	end
	local dungeon = Config.Dungeons[lobby.Dungeon]
	lobbyTitle.Text = `{dungeon.Name:upper()}  ·  LEVEL {dungeon.Level}+`
	lobbyInfo.Text = `Party {lobby.Count}/{lobby.Max}  ·  Starting in {math.ceil(lobby.Seconds)}s  ·  Walk off the circle to leave`
	local extras = {}
	if lobby.Featured then
		table.insert(extras, "FEATURED TODAY: +50% gold & XP")
	end
	table.insert(extras, if lobby.Best then `Your best on {Config.Difficulties[lobby.Difficulty].Name}: {Format.Time(lobby.Best)}` else "No best time yet")
	lobbyExtra.Text = table.concat(extras, "  ·  ")
	for i, b in lobbyButtons do
		local unlocked = i <= lobby.MaxDifficulty
		local chosen = i == lobby.Difficulty
		local color = Config.Difficulties[i].Color
		b.BackgroundColor3 = if chosen then color elseif unlocked then THEME.PanelLight else THEME.PanelDark
		b.TextColor3 = if chosen then THEME.PanelDark elseif unlocked then THEME.Text else THEME.Muted
		b.Text = if unlocked then Config.Difficulties[i].Name:upper() else "LOCKED"
		b.Active = lobby.Leader and unlocked
		b.AutoButtonColor = false
	end
	lobbyStart.Visible = lobby.Leader
end

---------------------------------------------------------------- Tod und Zusammenfassung

local deathFrame: Frame
local deathTimer: TextLabel
local deathRespawn: TextButton
local deathAd: TextButton
local deathUntil = 0

local function buildDeath()
	deathFrame = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 0, 10), BackgroundTransparency = 0.45, Visible = false, ZIndex = 30, Parent = root })
	text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(700, 70), Text = "YOU WERE DEFEATED", Font = TITLE, TextSize = 52, TextColor3 = THEME.Red, TextStrokeTransparency = 0.3, ZIndex = 31, Parent = deathFrame })
	deathTimer = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(600, 30), Text = "", Font = HEAVY, TextSize = 20, ZIndex = 31, Parent = deathFrame })
	button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.52, 0), Size = UDim2.fromOffset(280, 50), Text = `REVIVE HERE  ·  R$ {Config.DevProducts.Revive.PriceHint}`, Font = TITLE, TextSize = 20, BackgroundColor3 = Color3.fromRGB(60, 150, 80), ZIndex = 31, Parent = deathFrame }, function()
		deathUntil = math.max(deathUntil, os.clock() + 25)
		request("BuyProduct", "Revive")
	end)
	deathAd = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.62, 0), Size = UDim2.fromOffset(280, 44), Text = "FREE REVIVE (WATCH AD)", Font = TITLE, TextSize = 17, BackgroundColor3 = Color3.fromRGB(50, 120, 160), ZIndex = 31, Visible = false, Parent = deathFrame }, function()
		deathAd.Visible = false
		deathUntil = math.max(deathUntil, os.clock() + 45)
		task.spawn(request, "WatchAd", "Revive")
	end)
	deathRespawn = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.72, 0), Size = UDim2.fromOffset(280, 40), Text = "RESPAWN", Font = TITLE, TextSize = 16, ZIndex = 31, Parent = deathFrame }, function()
		deathFrame.Visible = false
		request("Respawn")
	end)
end

local function showDeath(info)
	deathUntil = os.clock() + info.Seconds
	deathRespawn.Text = if info.Party then "RESPAWN AT CHECKPOINT" else "RETURN TO TOWN"
	deathFrame.Visible = true
	deathAd.Visible = false
	task.spawn(function()
		local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
		deathAd.Visible = deathFrame.Visible and ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
	end)
	task.spawn(function()
		while deathFrame.Visible do
			local left = deathUntil - os.clock()
			deathTimer.Text = if info.Party then `Respawning at the last checkpoint in {math.max(0, math.ceil(left))}s` else `Your party has fallen. Returning in {math.max(0, math.ceil(left))}s`
			if alive() then
				deathFrame.Visible = false
			end
			task.wait(0.2)
		end
	end)
end

local summaryFrame: Frame
local summaryTitle: TextLabel
local summaryBody: TextLabel

local function buildSummary()
	summaryFrame = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 340), Visible = false, ZIndex = 25, Parent = root })
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(THEME.PanelLight, THEME.Panel), Parent = summaryFrame })
	summaryTitle = text({ Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 50), Text = "VICTORY", Font = TITLE, TextSize = 44, TextColor3 = THEME.Amber, ZIndex = 26, Parent = summaryFrame })
	summaryBody = text({ Position = UDim2.fromOffset(24, 70), Size = UDim2.new(1, -48, 0, 190), Text = "", RichText = true, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 26, Parent = summaryFrame })
	button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(240, 46), Text = "RETURN TO TOWN", Font = TITLE, TextSize = 20, BackgroundColor3 = Color3.fromRGB(60, 140, 80), ZIndex = 26, Parent = summaryFrame }, function()
		summaryFrame.Visible = false
		request("LeaveRun")
	end)
end

local function showSummary(info)
	summaryTitle.Text = if info.Success then "VICTORY!" else "DEFEATED"
	summaryTitle.TextColor3 = if info.Success then THEME.Amber else THEME.Red
	local lines = {
		`<b>{info.Dungeon}</b>  ·  {info.Difficulty}  ·  {Format.Time(info.Time)}` .. (if info.NewRecord then `  <font color="#FFCA54">NEW BEST TIME!</font>` else ""),
		`Kills: {info.Kills}`,
		`Gold: +{money(info.Gold)}`,
		`XP: +{money(info.XP)}`,
		`Items found: {info.Items}`,
	}
	if info.Best then
		local c = rarityColor(info.Best.Rarity)
		table.insert(lines, `Best: <font color="#{c:ToHex()}">{info.Best.Name}</font>`)
	end
	if info.Unlocked then
		table.insert(lines, `<font color="#6EDE8C">New dungeon unlocked: {info.Unlocked}!</font>`)
	elseif info.NextDifficulty then
		table.insert(lines, `<font color="#FFB84A">{info.NextDifficulty} difficulty unlocked here!</font>`)
	end
	if info.Success then
		table.insert(lines, "Open your BAG to equip new loot.")
	end
	summaryBody.Text = table.concat(lines, "\n")
	summaryFrame.Visible = true
	if info.Success then
		Effects.Sound("Level", 0.8, 0.9)
	end
end

---------------------------------------------------------------- Angebot

local offerFrame: Frame
local offerText: TextLabel
local offerBuy: TextButton
local offerKey: string? = nil

local function buildOffer()
	offerFrame = panel({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.45, 0), Size = UDim2.fromOffset(260, 160), Visible = false, ZIndex = 15, Parent = root })
	text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 26), Text = "SPECIAL OFFER", Font = TITLE, TextSize = 20, TextColor3 = THEME.Amber, ZIndex = 16, Parent = offerFrame })
	offerText = text({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 70), Text = "", TextSize = 14, ZIndex = 16, Parent = offerFrame })
	offerBuy = button({ Position = UDim2.new(0, 12, 1, -46), Size = UDim2.new(0.55, -12, 0, 36), Text = "BUY", Font = TITLE, TextSize = 17, BackgroundColor3 = Color3.fromRGB(60, 150, 80), ZIndex = 16, Parent = offerFrame }, function()
		offerFrame.Visible = false
		if offerKey then
			local passKey = offerKey:match("^Pass_(.+)$")
			if passKey then
				request("BuyPass", passKey)
			else
				request("BuyProduct", offerKey)
			end
		end
	end)
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 1, -46), Size = UDim2.new(0.45, -12, 0, 36), Text = "No thanks", TextSize = 14, ZIndex = 16, Parent = offerFrame }, function()
		offerFrame.Visible = false
	end)
end

local function showOffer(key: string, message: string)
	offerKey = key
	local passKey = key:match("^Pass_(.+)$")
	local entry = if passKey then Config.GamePasses[passKey] else Config.DevProducts[key]
	if not entry then
		return
	end
	local id = if passKey then entry.ProductId else entry.Id
	offerText.Text = message
	offerBuy.Text = `R$ {priceOf(id, entry.PriceHint)}`
	offerFrame.Visible = true
	task.delay(20, function()
		if offerKey == key then
			offerFrame.Visible = false
		end
	end)
end

---------------------------------------------------------------- Taegliche Quests

local questList: Frame
local questInfo: TextLabel

local function clearChildren(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function renderQuests()
	clearChildren(questList)
	local info = state.Quests
	if not info then
		questInfo.Text = "Loading quests..."
		task.spawn(request, "GetQuests")
		return
	end
	local left = math.max(0, info.ResetAt - os.time())
	questInfo.Text = `Each quest: {money(info.Gold)} gold + {info.Shards} shards  ·  New quests in {left // 3600}h {left % 3600 // 60}m`
	for i, quest in info.List do
		local row = panel({ Size = UDim2.new(1, 0, 0, 70), LayoutOrder = i, BackgroundColor3 = THEME.PanelDark, Parent = questList })
		text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 24), Text = quest.Text, Font = HEAVY, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local _, fill, label = bar({ Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -170, 0, 18), TextSize = 12, Parent = row }, THEME.Green)
		fill.Size = UDim2.fromScale(math.clamp(quest.Progress / math.max(1, quest.Goal), 0, 1), 1)
		label.Text = `{quest.Progress} / {quest.Goal}`
		local done = quest.Progress >= quest.Goal
		button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(130, 42),
			Text = if quest.Claimed then "CLAIMED" elseif done then "CLAIM" else "IN PROGRESS",
			Font = TITLE,
			TextSize = if done and not quest.Claimed then 18 else 13,
			BackgroundColor3 = if quest.Claimed then THEME.PanelLight elseif done then Color3.fromRGB(60, 150, 80) else THEME.PanelDark,
			Parent = row,
		}, function()
			if done and not quest.Claimed then
				request("ClaimQuest", quest.Index)
			end
		end)
	end
	text({
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = 10,
		Text = if info.BonusClaimed then "Daily bonus claimed! Come back tomorrow for new quests." else "Finish all 3 quests for a bonus Epic item!",
		TextColor3 = if info.BonusClaimed then THEME.Green else THEME.Gold,
		TextSize = 15,
		Font = HEAVY,
		Parent = questList,
	})
end
renderers.Quests = renderQuests

local function buildQuests()
	local _, body = window("Quests", "DAILY QUESTS", Vector2.new(600, 384))
	questInfo = text({ Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	questList = create("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28), BackgroundTransparency = 1, Parent = body })
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = questList })
end

---------------------------------------------------------------- Mehr-Menue (Heldentagebuch, Erfolge, Stil, Codes, Einstellungen, Einladen)

local function buildMore()
	local _, body = window("More", "MORE", Vector2.new(520, 300))
	local grid = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 98), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local entries = {
		{ "HERO\nJOURNAL", Color3.fromRGB(110, 76, 52), "Hero" },
		{ "ACHIEVE-\nMENTS", Color3.fromRGB(170, 120, 30), "Achievements" },
		{ "AURAS", Color3.fromRGB(120, 70, 170), "Style" },
		{ "CODES", Color3.fromRGB(60, 120, 90), "Codes" },
		{ "SETTINGS", Color3.fromRGB(70, 76, 110), "Settings" },
		{ "INVITE\nFRIENDS", Color3.fromRGB(50, 120, 160), nil },
	}
	for i, entry in entries do
		button({ Text = entry[1], Font = TITLE, TextSize = 19, BackgroundColor3 = entry[2], LayoutOrder = i, Parent = grid }, function()
			if entry[3] then
				open(entry[3])
			else
				invite()
			end
		end)
	end
end

---------------------------------------------------------------- Heldentagebuch, Erfolge und Auren (Daten vom Server)

local heroScroll: ScrollingFrame
local achievementScroll: ScrollingFrame
local styleScroll: ScrollingFrame

local function scrollList(parent: Instance, top: number): ScrollingFrame
	local scroll = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}) :: ScrollingFrame
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	return scroll
end

local function withHero(render: (any) -> ())
	task.spawn(function()
		local data = request("GetHero")
		if typeof(data) == "table" then
			render(data)
		end
	end)
end

local function renderHero()
	withHero(function(data)
		clearChildren(heroScroll)
		local order = 0
		local function line(caption: string, value: string, color: Color3?)
			order += 1
			local row = create("Frame", { Size = UDim2.new(1, -10, 0, 26), BackgroundColor3 = if order % 2 == 0 then THEME.PanelDark else THEME.Panel, BorderSizePixel = 0, LayoutOrder = order, Parent = heroScroll })
			corner(6).Parent = row
			text({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.62, -10, 1, 0), Text = caption, TextSize = 15, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			text({ Position = UDim2.new(0.62, 0, 0, 0), Size = UDim2.new(0.38, -10, 1, 0), Text = value, Font = HEAVY, TextSize = 15, TextColor3 = color or THEME.Text, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
		local function header(caption: string)
			order += 1
			text({ Size = UDim2.new(1, -10, 0, 30), Text = caption, Font = TITLE, TextSize = 20, TextColor3 = THEME.Amber, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = heroScroll })
		end
		header("LIFETIME STATS")
		for _, entry in data.Stats do
			line(entry[1], entry[2])
		end
		header("BEST CLEAR TIMES")
		if #data.Records == 0 then
			line("Clear a dungeon to set your first record!", "")
		end
		for _, entry in data.Records do
			line(`{entry[1]}  ·  {entry[2]}`, entry[3], Config.Difficulties[entry[4]].Color)
		end
	end)
end
renderers.Hero = renderHero

local function buildHero()
	local _, body = window("Hero", "HERO JOURNAL", Vector2.new(600, 440))
	heroScroll = scrollList(body, 0)
end

local function renderAchievements()
	withHero(function(data)
		clearChildren(achievementScroll)
		local unlocked = 0
		for _, entry in data.Achievements do
			if entry.Done then
				unlocked += 1
			end
		end
		local top = create("Frame", { Size = UDim2.new(1, -10, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0, Parent = achievementScroll })
		text({ Size = UDim2.new(1, -150, 1, 0), Text = `{unlocked}/{#data.Achievements} unlocked  ·  Each one unlocks a title for your nameplate`, TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(130, 34), Text = "NO TITLE", TextSize = 14, Parent = top }, function()
			if request("SetTitle", "") then
				renderAchievements()
			end
		end)
		for i, entry in data.Achievements do
			local row = panel({ Size = UDim2.new(1, -10, 0, 64), LayoutOrder = i, BackgroundColor3 = if entry.Done then THEME.PanelLight else THEME.PanelDark, Parent = achievementScroll })
			text({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -170, 0, 22), Text = entry.Name, Font = TITLE, TextSize = 18, TextColor3 = if entry.Done then THEME.Gold else THEME.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -170, 0, 16), Text = `{entry.Text}  ·  Title: {entry.Title}  ·  +{money(entry.Gold)} gold`, TextSize = 13, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local _, fill, label = bar({ Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -170, 0, 12), TextSize = 10, Parent = row }, if entry.Done then THEME.Gold else THEME.Blue)
			fill.Size = UDim2.fromScale(math.clamp(entry.Progress / math.max(1, entry.Goal), 0, 1), 1)
			label.Text = `{money(entry.Progress)} / {money(entry.Goal)}`
			local inUse = entry.Done and data.Title == entry.Title
			button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(140, 38),
				Text = if inUse then "IN USE" elseif entry.Done then "USE TITLE" else "LOCKED",
				Font = TITLE,
				TextSize = 15,
				BackgroundColor3 = if inUse then THEME.PanelLight elseif entry.Done then Color3.fromRGB(60, 140, 80) else THEME.PanelDark,
				Parent = row,
			}, function()
				if entry.Done and not inUse and request("SetTitle", entry.Key) then
					showToast(`Title set: {entry.Title}`, THEME.Gold)
					renderAchievements()
				end
			end)
		end
	end)
end
renderers.Achievements = renderAchievements

local function buildAchievements()
	local _, body = window("Achievements", "ACHIEVEMENTS", Vector2.new(640, 450))
	achievementScroll = scrollList(body, 0)
end

local function renderStyle()
	withHero(function(data)
		clearChildren(styleScroll)
		local top = create("Frame", { Size = UDim2.new(1, -10, 0, 40), BackgroundTransparency = 1, LayoutOrder = 0, Parent = styleScroll })
		text({ Size = UDim2.new(1, -150, 1, 0), Text = "Auras glow around your hero for everyone to see.", TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = top })
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(130, 34), Text = if data.Aura == "" then "NO AURA ✓" else "NO AURA", TextSize = 14, Parent = top }, function()
			if request("SetAura", "") then
				renderStyle()
			end
		end)
		for i, aura in data.Auras do
			local row = panel({ Size = UDim2.new(1, -10, 0, 58), LayoutOrder = i, BackgroundColor3 = THEME.PanelDark, Parent = styleScroll })
			local dot = create("Frame", { Position = UDim2.fromOffset(12, 13), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = aura.Color, Parent = row })
			corner(16).Parent = dot
			stroke(Color3.new(1, 1, 1), 2, 0.4).Parent = dot
			text({ Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -220, 0, 24), Text = aura.Name, Font = TITLE, TextSize = 19, TextColor3 = aura.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local how = if aura.Owned then "Owned" elseif aura.Gold then `{money(aura.Gold)} gold` elseif aura.Requirement then `Unlock: achievement "{aura.Requirement}"` else "Exclusive Robux aura"
			text({ Position = UDim2.fromOffset(56, 30), Size = UDim2.new(1, -220, 0, 18), Text = how, TextSize = 13, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local equipped = data.Aura == aura.Key
			local caption = if equipped then "EQUIPPED"
				elseif aura.Owned then "EQUIP"
				elseif aura.Gold then "BUY"
				elseif aura.ProductKey then `R$ {priceOf(aura.ProductId, aura.Price or 0)}`
				else "LOCKED"
			button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(140, 38),
				Text = caption,
				Font = TITLE,
				TextSize = 16,
				BackgroundColor3 = if equipped then THEME.PanelLight elseif aura.Owned or aura.Gold or aura.ProductKey then Color3.fromRGB(60, 140, 80) else THEME.PanelDark,
				Parent = row,
			}, function()
				if equipped then
					return
				end
				if aura.Owned then
					if request("SetAura", aura.Key) then
						renderStyle()
					end
				elseif aura.Gold or aura.ProductKey then
					local ok, reason = request("BuyAura", aura.Key)
					if ok then
						renderStyle()
					elseif reason then
						showToast(reason, THEME.Red)
					end
				end
			end)
		end
	end)
end
renderers.Style = renderStyle

local function buildStyle()
	local _, body = window("Style", "AURAS", Vector2.new(600, 450))
	styleScroll = scrollList(body, 0)
end

---------------------------------------------------------------- Codes

local codeBox: TextBox
local codeResult: TextLabel

local function buildCodes()
	local _, body = window("Codes", "CODES", Vector2.new(460, 250))
	text({ Size = UDim2.new(1, 0, 0, 22), Text = "Enter a code for free rewards!", TextSize = 15, TextColor3 = THEME.Muted, Parent = body })
	codeBox = create("TextBox", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = THEME.PanelDark,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		PlaceholderText = "Type code here",
		PlaceholderColor3 = THEME.Muted,
		Text = "",
		TextColor3 = THEME.Text,
		Font = HEAVY,
		TextSize = 22,
		Parent = body,
	}) :: TextBox
	corner(8).Parent = codeBox
	stroke(THEME.Border, 1.5, 0.4).Parent = codeBox
	codeResult = text({ Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 0, 40), Text = "", TextSize = 15, Parent = body })
	button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(200, 42), Text = "REDEEM", Font = TITLE, TextSize = 20, BackgroundColor3 = Color3.fromRGB(60, 150, 80), Parent = body }, function()
		local ok, message = request("RedeemCode", codeBox.Text)
		codeResult.Text = message or (if ok then "Code redeemed!" else "Invalid code.")
		codeResult.TextColor3 = if ok then THEME.Green else THEME.Red
		if ok then
			codeBox.Text = ""
		end
	end)
end
renderers.Codes = function()
	codeResult.Text = ""
end

---------------------------------------------------------------- Einstellungen

local settingsList: Frame

local function renderSettings()
	clearChildren(settingsList)
	for i, setting in Config.Settings do
		local value = player:GetAttribute("Set_" .. setting.Key)
		if value == nil then
			value = setting.Default
		end
		local row = panel({ Size = UDim2.new(1, 0, 0, 50), LayoutOrder = i, BackgroundColor3 = THEME.PanelDark, Parent = settingsList })
		text({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -150, 1, 0), Text = setting.Name, Font = HEAVY, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(110, 36),
			Text = if value then "ON" else "OFF",
			Font = TITLE,
			TextSize = 18,
			BackgroundColor3 = if value then Color3.fromRGB(60, 140, 80) else THEME.PanelLight,
			Parent = row,
		}, function()
			task.spawn(request, "SetSetting", setting.Key, not value)
		end)
	end
end
renderers.Settings = renderSettings

local function buildSettings()
	local _, body = window("Settings", "SETTINGS", Vector2.new(460, 320))
	settingsList = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body })
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = settingsList })
end

---------------------------------------------------------------- Einsteiger-Anleitung und Kombo-Anzeige

local guideFrame: Frame
local guideTitle: TextLabel
local guideText: TextLabel
local comboLabel: TextLabel
local comboToken = 0

local function buildGuide()
	guideFrame = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(340, 58), BackgroundTransparency = 0.08, Visible = false, Parent = root })
	guideTitle = text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), Text = "", Font = TITLE, TextSize = 18, TextColor3 = THEME.Amber, Parent = guideFrame })
	guideText = text({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 28), Text = "", TextSize = 14, Parent = guideFrame })
	comboLabel = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(260, 44), Text = "", Font = TITLE, TextSize = 34, TextColor3 = THEME.Gold, TextStrokeTransparency = 0.2, TextStrokeColor3 = THEME.PanelDark, Visible = false, Parent = root })
end

local function refreshGuide()
	local step = player:GetAttribute("TutorialStep") or (#Config.Tutorial + 1)
	local def = Config.Tutorial[step]
	guideFrame.Visible = def ~= nil and state.Run == nil
	if def then
		guideTitle.Text = `GUIDE {step}/{#Config.Tutorial}  ·  +{def.Gold} GOLD`
		guideText.Text = def.Text
	end
end

local function refreshQuestBadge()
	local ready = player:GetAttribute("QuestsReady") or 0
	questBadge.Visible = ready > 0
	questBadge.Text = tostring(ready)
end

local function showCombo(count: number, window: number)
	comboToken += 1
	local token = comboToken
	if count < 3 then
		comboLabel.Visible = false
		return
	end
	comboLabel.Text = `{count} COMBO!`
	comboLabel.TextColor3 = if count >= 50 then Color3.fromRGB(255, 110, 200) elseif count >= 25 then Color3.fromRGB(255, 150, 60) else THEME.Gold
	comboLabel.TextTransparency = 0
	comboLabel.TextStrokeTransparency = 0.2
	comboLabel.Visible = true
	comboLabel.Size = UDim2.fromOffset(300, 54)
	TweenService:Create(comboLabel, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(260, 44) }):Play()
	task.delay(window, function()
		if comboToken == token then
			TweenService:Create(comboLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

---------------------------------------------------------------- Start

function UI.Start()
	gui = create("ScreenGui", { Name = "LanternHUD", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") }) :: ScreenGui
	root = create("Frame", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = gui }) :: Frame
	local scale = create("UIScale", { Parent = root }) :: UIScale
	toastHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(600, 180), BackgroundTransparency = 1, Parent = root }) :: Frame
	create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = toastHolder })
	bigTitle = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(700, 64), Text = "", Font = TITLE, TextSize = 56, TextScaled = true, TextStrokeTransparency = 0, TextStrokeColor3 = THEME.PanelDark, Parent = root })
	bigSub = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.44), Size = UDim2.fromOffset(700, 30), Text = "", Font = HEAVY, TextSize = 22, TextStrokeTransparency = 0.4, Parent = root })

	buildHeroCard()
	buildCurrencies()
	buildRunBanner()
	buildCombat()
	buildMenu()
	buildBag()
	buildForge()
	buildShop()
	buildClass()
	buildLobby()
	buildDeath()
	buildSummary()
	buildOffer()
	buildQuests()
	buildMore()
	buildHero()
	buildAchievements()
	buildStyle()
	buildCodes()
	buildSettings()
	buildGuide()

	-- Auf schmalen Handys wuerde das Banner oben in der Mitte die Waehrungen rechts ueberdecken:
	-- dann rutschen Banner, Anleitung, Bossleiste und Meldungen eine Zeile tiefer.
	local function resize()
		local view = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(view.X / 1000, view.Y / 560), 0.6, 1.25)
		scale.Scale = s
		local width = view.X / s
		root.Size = UDim2.fromOffset(width, view.Y / s)
		local narrow = width < 1200
		local top = if narrow then 86 else 12
		runBanner.Position = UDim2.new(0.5, 0, 0, top)
		guideFrame.Position = UDim2.new(0.5, 0, 0, top)
		bossFrame.Position = UDim2.new(0.5, 0, 0, top + 62)
		toastHolder.Position = UDim2.new(0.5, 0, 0, top + 120)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	resize()

	-- Attribute -> Anzeige
	local function refreshAll()
		refreshHero()
		refreshCurrencies()
		refreshSkillLabels()
		if openWindow and renderers[openWindow] and openWindow ~= "Bag" then
			renderers[openWindow]()
		end
	end
	player.AttributeChanged:Connect(function(name)
		if name == "Gold" or name == "Shards" or name == "GearScore" then
			refreshCurrencies()
			if openWindow == "Forge" then
				renderForge()
			end
		elseif name == "PotionLevel" and openWindow == "Forge" then
			renderForge()
		elseif name == "Level" or name == "XP" or name == "XPNeed" or name == "Class" then
			refreshHero()
			refreshSkillLabels()
		elseif name == "TutorialStep" then
			refreshGuide()
		elseif name == "QuestsReady" then
			refreshQuestBadge()
		elseif name:sub(1, 4) == "Set_" then
			if openWindow == "Settings" then
				renderSettings()
			end
		elseif name:sub(1, 5) == "Pass_" or name == "RandomRestricted" then
			if openWindow == "Shop" or openWindow == "Class" then
				renderers[openWindow]()
			end
		elseif name == "Stat_Damage" and openWindow == "Bag" then
			renderBag()
		end
	end)
	refreshAll()
	refreshGuide()
	refreshQuestBadge()
	RunService.RenderStepped:Connect(updateCooldowns)

	remotes.Sync.OnClientEvent:Connect(function(topic, data)
		if topic == "Inventory" then
			local before = #state.Items
			state.Items = data.Items
			state.Equipped = data.Equipped
			state.Capacity = data.Capacity
			local better = 0
			for _, item in state.Items do
				if isBetter(item) then
					better += 1
				end
			end
			bagBadge.Visible = better > 0
			bagBadge.Text = if better > 9 then "9+" else tostring(math.max(1, better))
			if openWindow == "Bag" then
				renderBag()
			elseif openWindow == "Forge" then
				renderForge()
			end
			if #state.Items > before and #state.Items >= state.Capacity then
				showToast("Your bag is full! Salvage items to make room.", THEME.Red)
			end
		elseif topic == "Run" then
			local wasInRun = state.Run ~= nil
			state.Run = data
			combatFrame.Visible = data ~= nil
			if data and not wasInRun then
				closeWindows()
				summaryFrame.Visible = false
			end
			if not data then
				summaryFrame.Visible = false
				deathFrame.Visible = false
			end
			refreshRun()
			refreshLobby()
			refreshGuide()
		elseif topic == "Quests" then
			state.Quests = data
			if openWindow == "Quests" then
				renderQuests()
			end
		elseif topic == "Lobby" then
			state.Lobby = data
			refreshLobby()
		elseif topic == "Death" then
			showDeath(data)
		elseif topic == "Summary" then
			deathFrame.Visible = false
			showSummary(data)
		end
	end)

	remotes.Notify.OnClientEvent:Connect(function(message, color)
		showToast(message, color)
	end)
	remotes.Announce.OnClientEvent:Connect(function(message, color)
		showToast(message, color)
	end)
	remotes.Offer.OnClientEvent:Connect(showOffer)
	remotes.Effect.OnClientEvent:Connect(function(kind, data)
		if kind == "RunStart" then
			showTitle(data.Name:upper(), `{data.Difficulty}  ·  Monster level {data.Level}` .. (if data.Featured then "  ·  FEATURED +50%" else ""), data.Color)
		elseif kind == "BossIntro" then
			showTitle(data.Name:upper(), if data.Blessed then "Blessed: a Legendary awaits everyone!" else "Boss fight!", THEME.Red)
		elseif kind == "RoomClear" then
			showTitle("ROOM CLEARED", if data.Room >= data.Rooms then "The boss awaits..." else "The gate is open!", THEME.Green)
		elseif kind == "Enrage" then
			showToast(`{data.Name} is enraged!`, THEME.Red)
		elseif kind == "PlayerDown" then
			showToast(`{data.Name} has fallen!`, THEME.Red)
		elseif kind == "Revive" then
			showToast(`{data.Name} is back in the fight!`, THEME.Green)
		elseif kind == "LevelUp" and data.Player == player then
			showTitle("LEVEL UP!", `Level {data.Level}`, THEME.Gold)
		elseif kind == "Loot" then
			local rarity = Config.Rarities[data.Rarity]
			if data.Rarity >= 2 then
				showToast(`{rarity.Name}: {data.Name}` .. (if data.Better then "  (upgrade!)" else ""), rarity.Color)
			end
		elseif kind == "Salvaged" then
			showToast(`Auto-salvaged {data.Name} (+{data.Shards} shards)`, THEME.Muted)
		elseif kind == "Achievement" then
			showTitle("ACHIEVEMENT!", `{data.Name}  ·  Title: {data.Title}`, THEME.Gold)
		elseif kind == "Combo" then
			showCombo(data.Count, data.Window)
		elseif kind == "ImpAppear" then
			showToast("A Treasure Imp appeared! Catch it before it escapes!", THEME.Gold)
		elseif kind == "ImpEscape" then
			showToast("The Treasure Imp escaped...", THEME.Muted)
		elseif kind == "Ping" then
			showToast(`{data.Name}: {data.Text}`, THEME.Blue)
		end
	end)

	-- Schrein und Schmiede in der Stadt
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "ClassShrine" then
			open("Class")
		elseif prompt.Name == "Forge" then
			open("Forge")
		end
	end)

	request("GetInventory")
	task.spawn(request, "GetQuests")
	-- Neue Spieler: Klassenwahl direkt nach dem Laden
	task.delay(4, function()
		if not player:GetAttribute("ClassChosen") then
			open("Class")
		end
	end)
end

return UI
