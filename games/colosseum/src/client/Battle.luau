-- Kampf-Oberflaeche im Stil klassischer Monster-Spiele: Uebergang, Statusboxen mit KP- und EP-Balken,
-- Textbox, Befehlsmenue (KAMPF / BEUTEL / BESTIEN / FLUCHT), Attacken mit AP, Team-Wechsel und alle Animationen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local C = Theme.Colors
local create = Theme.create
local label = Theme.label
local button = Theme.button

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Battle = {}

local gui: ScreenGui
local root: Frame
local wipe: Frame
local enemyBox, myBox
local textBox: TextButton
local textLabel: TextLabel
local commandPanel: Frame
local popup: Frame
local timerFill: Frame
local banner: TextLabel
local resultPanel: Frame

local current = nil -- laufender Kampf
local queue = {} -- Nachrichten vom Server, werden nacheinander abgespielt
local processing = false
local autoOn = false
local skipText = false
local originalTransparency = {} -- [BasePart] = number

local STATUS_COLORS = {}
for key, status in Config.Statuses do
	STATUS_COLORS[key] = status.Color
end

---------------------------------------------------------------- Hilfen

local function fighterOf(sideIndex: number)
	local side = current.Sides[sideIndex]
	return side.Fighters[side.Active]
end

local function modelOf(sideIndex: number): Model?
	local side = current.Sides[sideIndex]
	if side.Model and side.Model.Parent then
		return side.Model
	end
	local folder = workspace:FindFirstChild("Battles")
	local battleFolder = folder and folder:FindFirstChild("B" .. current.Id)
	local found = battleFolder and battleFolder:WaitForChild("Side" .. sideIndex, 2)
	if found then
		side.Model = found
	end
	return found
end

local function beastName(sideIndex: number): string
	return Config.BeastsById[fighterOf(sideIndex).Id].Name
end

-- "@1"/"@2" im Server-Text durch Namen ersetzen (aus Sicht dieses Spielers)
local function nameOf(sideIndex: number): string
	if sideIndex == current.You then
		return beastName(sideIndex)
	end
	return (if current.Kind == "Wild" or current.Kind == "Legend" then "the wild " else "the foe's ") .. beastName(sideIndex)
end

local function resolve(text: string): string
	local result = text:gsub("@(%d)", function(digit)
		return nameOf(tonumber(digit) :: number)
	end)
	-- Satzanfang gross schreiben
	return (result:gsub("^%l", string.upper))
end

-- Text in die Textbox schreiben (Schreibmaschine), danach kurz warten
local function say(text: string, hold: number?)
	text = resolve(text)
	skipText = false
	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0
	local length = utf8.len(text) or #text
	local shown = 0
	while shown < length and not skipText do
		shown = math.min(length, shown + 2)
		textLabel.MaxVisibleGraphemes = shown
		RunService.Heartbeat:Wait()
	end
	textLabel.MaxVisibleGraphemes = -1
	local wait = hold or (0.55 + length * 0.012)
	local start = os.clock()
	skipText = false
	while os.clock() - start < wait and not skipText do
		RunService.Heartbeat:Wait()
	end
end

local function showBanner(text: string, color: Color3?)
	banner.Text = text
	banner.TextColor3 = color or C.Gold
	banner.Visible = true
	banner.TextTransparency = 0
	local scale = banner:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.4
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.4, function()
		if banner.Text == text then
			TweenService:Create(banner, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	end)
end

local function setModelTransparency(model: Model?, alpha: number, duration: number)
	if not model then
		return
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			if originalTransparency[part] == nil then
				originalTransparency[part] = part.Transparency
			end
			local target = if alpha >= 1 then 1 else originalTransparency[part]
			TweenService:Create(part, TweenInfo.new(duration), { Transparency = target }):Play()
		end
	end
end

-- Modell lokal per CFrame bewegen (der Server bewegt Kampfmodelle nicht, darum kein Ruckeln)
local function animatePivot(model: Model, from: CFrame, to: CFrame, duration: number)
	local start = os.clock()
	while os.clock() - start < duration do
		local alpha = TweenService:GetValue((os.clock() - start) / duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		model:PivotTo(from:Lerp(to, alpha))
		RunService.Heartbeat:Wait()
	end
	model:PivotTo(to)
end

local function burst(position: Vector3, color: Color3, amount: number, speed: number?)
	local anchor = create("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(position), Parent = workspace })
	local emitter = create("ParticleEmitter", {
		Color = ColorSequence.new(color),
		LightEmission = 0.7,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new((speed or 15) * 0.6, speed or 15),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = anchor,
	})
	emitter:Emit(amount)
	task.delay(1.2, function()
		anchor:Destroy()
	end)
end

local function floatText(model: Model?, text: string, color: Color3, size: number?)
	if not model or not model.PrimaryPart then
		return
	end
	local board = create("BillboardGui", { Size = UDim2.fromOffset(200, 60), StudsOffset = Vector3.new(0, 3, 0), AlwaysOnTop = true, LightInfluence = 0, Adornee = model.PrimaryPart, Parent = gui })
	local text_ = label({ Size = UDim2.fromScale(1, 1), Text = text, Font = Theme.Title, TextSize = size or 40, TextColor3 = color, Parent = board })
	Theme.textStroke(text_, 3)
	TweenService:Create(board, TweenInfo.new(0.9), { StudsOffset = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(text_, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(1, function()
		board:Destroy()
	end)
end

local function flash(model: Model?, color: Color3, times: number?)
	if not model then
		return
	end
	local highlight = create("Highlight", { FillColor = color, FillTransparency = 1, OutlineTransparency = 1, Adornee = model, Parent = model })
	task.spawn(function()
		for _ = 1, times or 1 do
			highlight.FillTransparency = 0.15
			task.wait(0.08)
			highlight.FillTransparency = 0.8
			task.wait(0.08)
		end
		highlight:Destroy()
	end)
end

local function shake(model: Model?, strength: number)
	if not model then
		return
	end
	local base = model:GetPivot()
	for i = 1, 6 do
		model:PivotTo(base * CFrame.new((if i % 2 == 0 then strength else -strength), 0, 0))
		task.wait(0.035)
	end
	model:PivotTo(base)
end

---------------------------------------------------------------- Statusboxen

local function makeBox(position: UDim2, anchor: Vector2, mine: boolean)
	local box = Theme.panel({ AnchorPoint = anchor, Position = position, Size = UDim2.fromOffset(360, if mine then 112 else 84), Parent = root })
	-- Diagonaler Akzent wie bei klassischen Kampf-Boxen
	local accent = create("Frame", { Position = UDim2.new(0, 0, 1, -6), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.Gold, Parent = box })
	Theme.corner(accent, 3)
	local nameLabel = label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -150, 0, 30), Text = "", Font = Theme.Title, TextSize = 26, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = box })
	Theme.textStroke(nameLabel, 1.5)
	local levelLabel = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 10), Size = UDim2.fromOffset(70, 26), Text = "", Font = Theme.Title, TextSize = 22, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, Parent = box })
	local status = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -92, 0, 12), Size = UDim2.fromOffset(46, 22), BackgroundTransparency = 0, Text = "", Font = Theme.Heavy, TextSize = 14, TextColor3 = C.Ink, Visible = false, Parent = box })
	Theme.corner(status, 6)
	local types = create("Frame", { Position = UDim2.fromOffset(16, 42), Size = UDim2.fromOffset(120, 20), BackgroundTransparency = 1, Parent = box })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = types })
	label({ Position = UDim2.fromOffset(140, 42), Size = UDim2.fromOffset(30, 20), Text = "HP", Font = Theme.Title, TextSize = 18, TextColor3 = C.Gold, Parent = box })
	local _, fill = Theme.hpBar({ Position = UDim2.fromOffset(172, 44), Size = UDim2.new(1, -188, 0, 16), Parent = box })
	local numbers = label({ Position = UDim2.fromOffset(172, 62), Size = UDim2.new(1, -188, 0, 20), Text = "", Font = Theme.Title, TextSize = 18, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Right, Visible = mine, Parent = box })
	local xpFill
	if mine then
		local xpBack = create("Frame", { Position = UDim2.fromOffset(16, 88), Size = UDim2.new(1, -32, 0, 8), BackgroundColor3 = C.PanelDark, Parent = box })
		Theme.corner(xpBack, 4)
		xpFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(90, 180, 255), Parent = xpBack })
		Theme.corner(xpFill, 4)
	end
	local dots = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 0, -4), Size = UDim2.fromOffset(200, 16), BackgroundTransparency = 1, Parent = box })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), Parent = dots })
	return { Frame = box, Name = nameLabel, Level = levelLabel, Status = status, Types = types, Fill = fill, Numbers = numbers, Xp = xpFill, Dots = dots }
end

local function drawBox(box, sideIndex: number, animate: boolean?)
	local side = current.Sides[sideIndex]
	local fighter = fighterOf(sideIndex)
	local def = Config.BeastsById[fighter.Id]
	box.Name.Text = (if fighter.Shiny then "✦ " else "") .. def.Name
	box.Name.TextColor3 = if fighter.Shiny then C.Prism else C.Cream
	box.Level.Text = `Lv{fighter.Level}`
	box.Status.Visible = fighter.Status ~= nil
	if fighter.Status then
		box.Status.Text = Config.Statuses[fighter.Status].Name
		box.Status.BackgroundColor3 = STATUS_COLORS[fighter.Status]
	end
	for _, child in box.Types:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	Theme.typeChip(def.Type, { Size = UDim2.fromOffset(58, 20), TextSize = 12, Parent = box.Types })
	if def.Type2 then
		Theme.typeChip(def.Type2, { Size = UDim2.fromOffset(58, 20), TextSize = 12, Parent = box.Types })
	end
	local fraction = fighter.Hp / math.max(1, fighter.MaxHp)
	if animate then
		local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		TweenService:Create(box.Fill, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = goal }):Play()
		task.delay(0.61, Theme.setHp, box.Fill, fraction)
	else
		Theme.setHp(box.Fill, fraction)
	end
	box.Numbers.Text = `{math.max(0, fighter.Hp)} / {fighter.MaxHp}`
	if box.Xp then
		local xp = if fighter.Need and fighter.Need > 0 then (fighter.X or 0) / fighter.Need else 0
		if animate then
			TweenService:Create(box.Xp, TweenInfo.new(0.6), { Size = UDim2.fromScale(math.clamp(xp, 0, 1), 1) }):Play()
		else
			box.Xp.Size = UDim2.fromScale(math.clamp(xp, 0, 1), 1)
		end
	end
	for _, child in box.Dots:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not side.IsWild then
		for _, member in side.Fighters do
			local dot = create("Frame", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = if member.Hp <= 0 then C.PanelLight elseif member.Status then STATUS_COLORS[member.Status] else Color3.fromRGB(150, 60, 170), Parent = box.Dots })
			Theme.corner(dot, 7)
			Theme.stroke(dot, C.Gold, 1.5)
		end
	end
end

local function drawBoxes(animate: boolean?)
	drawBox(myBox, current.You, animate)
	drawBox(enemyBox, 3 - current.You, animate)
end

---------------------------------------------------------------- Befehle

local function clearCommands()
	commandPanel:ClearAllChildren()
	popup.Visible = false
	popup:ClearAllChildren()
end

local function send(action)
	clearCommands()
	textLabel.Text = if current.Kind == "Duel" then "Waiting for your opponent..." else ""
	remotes.BattleAction:FireServer(action)
end

local function openPopup(title: string, entries: { { Text: string, Sub: string?, Color: Color3?, Disabled: boolean?, OnPick: () -> () } }, canClose: boolean?)
	popup:ClearAllChildren()
	popup.Visible = true
	Theme.corner(popup, 12)
	Theme.stroke(popup, C.Gold, 2)
	label({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -70, 0, 36), Text = title, Font = Theme.Title, TextSize = 22, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = popup })
	if canClose ~= false then
		local close = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(32, 30), Text = "X", TextSize = 18, Color = C.CrimsonDark, Parent = popup })
		close.Activated:Connect(function()
			popup.Visible = false
		end)
	end
	local list = create("ScrollingFrame", { Position = UDim2.fromOffset(10, 40), Size = UDim2.new(1, -20, 1, -50), BackgroundTransparency = 1, ScrollBarThickness = 5, ScrollBarImageColor3 = C.Gold, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = popup })
	create("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
	for _, entry in entries do
		local b = button({ Size = UDim2.new(1, -8, 0, 46), Text = "", Color = if entry.Disabled then C.PanelLight else (entry.Color or C.Crimson), Parent = list })
		label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.58, 0, 1, 0), Text = entry.Text, Font = Theme.Title, TextSize = 18, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
		label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.42, -12, 1, 0), Text = entry.Sub or "", TextSize = 15, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Right, Parent = b })
		b.Activated:Connect(function()
			if not entry.Disabled then
				entry.OnPick()
			end
		end)
	end
	popup.Size = UDim2.fromOffset(380, math.min(420, 54 + #entries * 52))
end

local function teamEntries(team, active: number, onPick: (number) -> (), allowFainted: boolean?)
	local entries = {}
	for index, member in team do
		local def = Config.BeastsById[member.Id]
		local isActive = index == active
		local status = if member.Hp <= 0 then "FNT" elseif member.Status then Config.Statuses[member.Status].Name else nil
		table.insert(entries, {
			Text = `{def.Name}  Lv{member.Level}`,
			Sub = (if status then status .. "  " else "") .. (if isActive then "in battle" else `{member.Hp}/{member.MaxHp} HP`),
			Color = Config.Types[def.Type].Color:Lerp(C.Ink, 0.45),
			Disabled = (isActive and not allowFainted) or (member.Hp <= 0 and not allowFainted),
			OnPick = function()
				onPick(index)
			end,
		})
	end
	return entries
end

local showCommands -- weiter unten

local function showMoves(turn)
	clearCommands()
	local grid = create("Frame", { Size = UDim2.new(1, -96, 1, 0), BackgroundTransparency = 1, Parent = commandPanel })
	create("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0.5, -6), CellPadding = UDim2.fromOffset(8, 8), Parent = grid })
	local anyPP = false
	for _, move in turn.Moves do
		if move.PP > 0 then
			anyPP = true
		end
	end
	for _, move in turn.Moves do
		local disabled = move.PP <= 0 and anyPP
		local b = button({ Text = "", Color = if disabled then C.PanelLight else Config.Types[move.Type].Color:Lerp(C.Ink, 0.4), Parent = grid })
		local nameLabel = label({ Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -20, 0.55, 0), Text = move.Name, Font = Theme.Title, TextSize = 20, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
		Theme.textStroke(nameLabel, 1.5)
		local power = if move.Power > 0 then `PWR {move.Power}` else "STATUS"
		label({ Position = UDim2.new(0, 10, 0.55, 0), Size = UDim2.new(1, -20, 0.4, 0), Text = `{move.Type:upper()} · {power} · PP {move.PP}/{move.MaxPP}`, TextSize = 13, TextScaled = true, TextColor3 = if move.PP <= 0 then C.Red else C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
		if move.Eff and move.Eff ~= 1 then
			local text = if move.Eff == 0 then "NO EFFECT" elseif move.Eff > 1 then "SUPER!" else "WEAK"
			local tag = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -8), Size = UDim2.fromOffset(78, 18), BackgroundTransparency = 0, BackgroundColor3 = if move.Eff > 1 then C.Gold else C.PanelLight, Text = text, Font = Theme.Title, TextSize = 12, TextColor3 = C.Ink, Parent = b })
			Theme.corner(tag, 6)
		end
		b.Activated:Connect(function()
			if not disabled then
				send({ Kind = "Move", Slot = move.Slot })
			end
		end)
	end
	local back = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0, 86, 1, 0), Text = "BACK", TextSize = 18, Color = C.PanelLight, Parent = commandPanel })
	back.Activated:Connect(function()
		showCommands(turn)
	end)
end

local function showBag(turn)
	local items = turn.Items or {}
	local entries = {}
	if current.CanCatch then
		for _, key in { "Orb", "GreatOrb", "RoyalOrb", "MasterOrb" } do
			local item = Config.Items[key]
			local count = items[key] or 0
			local chance = turn.Chances and turn.Chances[key] or 0
			if key == "MasterOrb" and count <= 0 then
				table.insert(entries, { Text = item.Name, Sub = `100% · R$ {Config.DevProducts.MasterOrb1.PriceHint}`, Color = C.Green, OnPick = function()
					UI.Buy("Product", "MasterOrb1")
				end })
			elseif count > 0 or key == "Orb" then
				table.insert(entries, { Text = `{item.Name} x{count}`, Sub = `{math.floor(chance * 100 + 0.5)}% catch`, Color = item.Color:Lerp(C.Ink, 0.35), Disabled = count <= 0, OnPick = function()
					send({ Kind = "Item", Key = key })
				end })
			end
		end
	end
	if current.Kind ~= "Duel" then
		for _, key in { "Potion", "SuperPotion", "HyperPotion", "FullCure", "Revive" } do
			local item = Config.Items[key]
			local count = items[key] or 0
			if count > 0 then
				table.insert(entries, { Text = `{item.Name} x{count}`, Sub = item.Description, Color = item.Color:Lerp(C.Ink, 0.45), OnPick = function()
					-- Ziel waehlen
					openPopup(`USE {item.Name:upper()} ON...`, teamEntries(turn.Team, -1, function(index)
						send({ Kind = "Item", Key = key, Index = index })
					end, true))
				end })
			end
		end
	end
	if #entries == 0 then
		table.insert(entries, { Text = "Your bag is empty", Sub = "Buy items at a Beast Mart", Disabled = true, OnPick = function() end })
	end
	openPopup("BAG", entries)
end

showCommands = function(turn)
	clearCommands()
	local grid = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = commandPanel })
	create("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0.5, -5), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local function command(text: string, color: Color3, order: number, onPick: () -> ())
		local b = button({ Text = text, TextSize = 26, Color = color, LayoutOrder = order, Parent = grid })
		b.Activated:Connect(onPick)
		return b
	end
	command("FIGHT", C.Crimson, 1, function()
		showMoves(turn)
	end)
	command("BAG", Color3.fromRGB(200, 140, 40), 2, function()
		showBag(turn)
	end)
	command("BEASTS", C.Green, 3, function()
		openPopup("SWITCH BEAST", teamEntries(turn.Team, turn.Active, function(index)
			send({ Kind = "Swap", Index = index })
		end))
	end)
	command(if current.CanRun then (if current.Kind == "Wild" or current.Kind == "Legend" then "RUN" else "GIVE UP") else "RUN", C.Blue, 4, function()
		if not current.CanRun then
			task.spawn(say, "No! There's no running from a trainer battle!", 1)
			return
		end
		send({ Kind = "Run" })
	end)
end

local function showTurn(turn)
	clearCommands()
	textLabel.MaxVisibleGraphemes = -1
	textLabel.Text = `What will {beastName(current.You)} do?`
	current.Sides[current.You].Fighters = turn.Team
	current.Sides[current.You].Active = turn.Active
	drawBoxes()
	showCommands(turn)
	-- Auto-Kampf (Pass)
	local auto = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -200), Size = UDim2.fromOffset(120, 38), Text = if autoOn then "AUTO: ON" elseif player:GetAttribute("Pass_AutoBattle") then "AUTO" else "AUTO 🔒", TextSize = 16, Color = if autoOn then C.Gold else C.PanelDark, Parent = commandPanel })
	auto.Activated:Connect(function()
		autoOn = not autoOn
		remotes.BattleAction:FireServer({ Kind = "Auto", On = autoOn })
		if autoOn and player:GetAttribute("Pass_AutoBattle") then
			local best, bestScore = 1, -1
			for _, move in turn.Moves do
				local score = move.Power * (move.Acc or 1) * (move.Eff or 1)
				if move.PP > 0 and score > bestScore then
					best, bestScore = move.Slot, score
				end
			end
			send({ Kind = "Move", Slot = best })
		else
			autoOn = false
		end
	end)
	if turn.Auto and player:GetAttribute("Pass_AutoBattle") then
		clearCommands()
		textLabel.Text = "Auto battle..."
	end
	timerFill.Size = UDim2.fromScale(1, 1)
	TweenService:Create(timerFill, TweenInfo.new(turn.Timeout, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
end

local function showReplace(payload)
	clearCommands()
	textLabel.MaxVisibleGraphemes = -1
	textLabel.Text = "Choose your next beast!"
	current.Sides[current.You].Fighters = payload.Team
	local entries = teamEntries(payload.Team, payload.Active, function(index)
		send({ Kind = "Replace", Index = index })
	end)
	if payload.CanRun then
		table.insert(entries, { Text = "Run away", Sub = "Escape the battle", Color = C.Blue, OnPick = function()
			send({ Kind = "Run" })
		end })
	end
	openPopup("NEXT BEAST", entries, false)
end

---------------------------------------------------------------- Ereignisse abspielen

local function projectile(fromPos: Vector3, toPos: Vector3, color: Color3, big: boolean)
	local ball = create("Part", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * (if big then 3 else 1.8),
		Material = Enum.Material.Neon,
		Color = color,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CFrame = CFrame.new(fromPos),
		Parent = workspace,
	})
	create("PointLight", { Color = color, Range = 12, Brightness = 2, Parent = ball })
	local travel = TweenService:Create(ball, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(toPos) })
	travel:Play()
	travel.Completed:Wait()
	ball:Destroy()
end

local function playMove(event)
	local attackerModel = modelOf(event.Side)
	local targetModel = modelOf(3 - event.Side)
	local typeColor = Config.Types[event.Type].Color
	task.spawn(say, event.Text, 0.4)
	task.wait(0.35)
	if not attackerModel then
		task.wait(0.6)
		return
	end
	local from = attackerModel:GetPivot()
	if event.Power == 0 then
		-- Statusattacke: Leuchten am Anwender
		flash(attackerModel, typeColor, 2)
		burst(from.Position, typeColor, 25, 8)
		task.wait(0.5)
		return
	end
	if not targetModel then
		task.wait(0.4)
		return
	end
	local targetPos = targetModel:GetPivot().Position
	local dir = Vector3.new(targetPos.X - from.Position.X, 0, targetPos.Z - from.Position.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	if event.Type == "Normal" then
		local lunge = from + dir * math.min(8, (targetPos - from.Position).Magnitude * 0.5)
		animatePivot(attackerModel, from, lunge, 0.16)
		animatePivot(attackerModel, lunge, from, 0.2)
	else
		animatePivot(attackerModel, from, from + dir * 1.5, 0.1)
		projectile(from.Position + Vector3.new(0, 1, 0), targetPos + Vector3.new(0, 0.5, 0), typeColor, (event.Power or 0) >= 90)
		burst(targetPos, typeColor, if (event.Power or 0) >= 90 then 60 else 30)
		animatePivot(attackerModel, from + dir * 1.5, from, 0.12)
	end
end

local function playHit(event)
	local model = modelOf(event.Side)
	local fighter = fighterOf(event.Side)
	fighter.Hp = event.Hp
	if not event.Recoil and not event.Status then
		flash(model, if event.Eff > 1 then Color3.fromRGB(255, 200, 80) else Color3.new(1, 1, 1), if event.Eff > 1 then 3 else 2)
		task.spawn(shake, model, if event.Crit or event.Eff > 1 then 0.8 else 0.45)
	elseif event.Status then
		burst(if model then model:GetPivot().Position else Vector3.zero, STATUS_COLORS[event.Status] or C.Red, 20, 6)
	end
	local color = if event.Crit then C.Red elseif event.Eff > 1 then Color3.fromRGB(255, 160, 40) elseif event.Eff < 1 then C.Muted else C.Cream
	floatText(model, `-{event.Damage}`, color, if event.Crit or event.Eff > 1 then 48 else 36)
	drawBoxes(true)
	task.wait(0.65)
	for _, line in event.Lines or {} do
		say(line)
	end
end

local function playCatch(event)
	local targetModel = modelOf(3 - event.Side)
	local myModel = modelOf(event.Side)
	local item = Config.Items[event.Item]
	task.spawn(say, if event.Side == current.You then `You threw a {item.Name}!` else event.Text, 0.4)
	if not targetModel then
		task.wait(1)
		say(event.Result)
		return
	end
	local start = (if myModel then myModel:GetPivot().Position else targetModel:GetPivot().Position) + Vector3.new(0, 3, 0)
	local finish = targetModel:GetPivot().Position
	-- Orb in Purpur und Gold (eigenes Design)
	local orb = create("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Material = Enum.Material.SmoothPlastic, Color = item.Color, Anchored = true, CanCollide = false, CanQuery = false, CFrame = CFrame.new(start), Parent = workspace })
	local ring = create("Part", { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.75, 1.75), Material = Enum.Material.Neon, Color = Color3.fromRGB(240, 190, 60), Anchored = true, CanCollide = false, CanQuery = false, CFrame = orb.CFrame, Parent = orb })
	create("PointLight", { Color = item.Color, Range = 10, Parent = orb })
	local function place(cf: CFrame)
		orb.CFrame = cf
		ring.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	end
	local t0 = os.clock()
	while os.clock() - t0 < 0.55 do
		local t = (os.clock() - t0) / 0.55
		local position = start:Lerp(finish, t) + Vector3.new(0, math.sin(t * math.pi) * 6, 0)
		place(CFrame.new(position) * CFrame.Angles(t * 12, 0, 0))
		RunService.Heartbeat:Wait()
	end
	burst(finish, item.Color, 30)
	setModelTransparency(targetModel, 1, 0.2)
	local groundY = finish.Y - 1.5
	local ground = CFrame.new(Vector3.new(finish.X, groundY, finish.Z))
	local t1 = os.clock()
	local top = orb.CFrame
	while os.clock() - t1 < 0.35 do
		local t = (os.clock() - t1) / 0.35
		place(top:Lerp(ground, TweenService:GetValue(t, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)))
		RunService.Heartbeat:Wait()
	end
	place(ground)
	task.wait(0.5)
	for _ = 1, math.min(event.Shakes, 3) do
		for _, angle in { 28, -28, 0 } do
			place(ground * CFrame.Angles(0, 0, math.rad(angle)))
			task.wait(0.12)
		end
		task.wait(0.5)
	end
	if event.Success then
		burst(ground.Position + Vector3.new(0, 1, 0), C.Gold, 60)
		floatText(targetModel, "GOTCHA!", C.Gold, 46)
		showBanner("CAUGHT!", C.Gold)
		say(event.Result, 1.4)
		orb:Destroy()
	else
		burst(ground.Position, C.Cream, 30)
		orb:Destroy()
		setModelTransparency(targetModel, 0, 0.2)
		say(event.Result)
	end
end

local function playEvent(event)
	local kind = event.T
	if kind == "Move" then
		playMove(event)
	elseif kind == "Hit" then
		playHit(event)
	elseif kind == "Miss" then
		floatText(modelOf(3 - event.Side), "MISS", C.Muted, 30)
		say(event.Text)
	elseif kind == "Msg" then
		if event.Anim and event.Side then
			local model = modelOf(event.Side)
			flash(model, STATUS_COLORS[event.Anim] or C.Cream, 2)
		end
		say(event.Text)
	elseif kind == "Status" then
		local fighter = fighterOf(event.Side)
		fighter.Status = event.Status
		local model = modelOf(event.Side)
		if event.Status then
			burst(if model then model:GetPivot().Position else Vector3.zero, STATUS_COLORS[event.Status], 35, 8)
			flash(model, STATUS_COLORS[event.Status], 3)
		end
		drawBoxes()
		say(event.Text)
	elseif kind == "Stat" then
		local model = modelOf(event.Side)
		if model then
			local pos = model:GetPivot().Position
			burst(pos + Vector3.new(0, if event.Up then -1 else 3, 0), if event.Up then Color3.fromRGB(255, 120, 90) else Color3.fromRGB(90, 150, 255), 30, 6)
		end
		say(event.Text)
	elseif kind == "Heal" then
		local fighter = fighterOf(event.Side)
		fighter.Hp = event.Hp
		local model = modelOf(event.Side)
		burst(if model then model:GetPivot().Position else Vector3.zero, C.Green, 30, 6)
		drawBoxes(true)
		say(event.Text)
	elseif kind == "Faint" then
		local model = modelOf(event.Side)
		local fighter = fighterOf(event.Side)
		fighter.Hp = 0
		fighter.Status = nil
		if model then
			local from = model:GetPivot()
			task.spawn(animatePivot, model, from, from - Vector3.new(0, 2, 0), 0.6)
		end
		setModelTransparency(model, 1, 0.6)
		drawBoxes()
		say(event.Text)
	elseif kind == "Send" then
		local side = current.Sides[event.Side]
		side.Active = event.Index
		side.Fighters[event.Index] = event.Fighter
		side.Model = event.Model
		local model = modelOf(event.Side)
		drawBoxes()
		task.spawn(say, event.Text, 0.5)
		if model then
			local base = model:GetPivot()
			burst(base.Position, Color3.fromRGB(240, 190, 60), 30)
			animatePivot(model, base * CFrame.new(0, -1, 0) * CFrame.Angles(0, math.pi, 0), base, 0.35)
		end
		task.wait(0.9)
	elseif kind == "Item" then
		local side = current.Sides[event.Side]
		local fighter = side.Fighters[event.Index or side.Active]
		if fighter then
			fighter.Hp = event.Hp
			fighter.Status = event.Status
		end
		local model = modelOf(event.Side)
		burst(if model then model:GetPivot().Position else Vector3.zero, C.Green, 30, 6)
		drawBoxes(true)
		say(event.Text)
	elseif kind == "Catch" then
		playCatch(event)
	elseif kind == "Xp" then
		local mine = fighterOf(current.You)
		if mine.Uid == event.Uid then
			mine.X = event.X
			mine.Need = event.Need
			drawBoxes(true)
		end
		say(event.Text)
	elseif kind == "Level" then
		local mine = fighterOf(current.You)
		if mine.Uid == event.Uid then
			mine.Level = event.Level
			mine.Hp = event.Hp
			mine.MaxHp = event.MaxHp
			mine.X = event.X
			mine.Need = event.Need
			local model = modelOf(current.You)
			flash(model, Color3.fromRGB(120, 200, 255), 3)
			burst(if model then model:GetPivot().Position else Vector3.zero, Color3.fromRGB(120, 200, 255), 40, 10)
			drawBoxes()
		end
		showBanner("LEVEL UP!", Color3.fromRGB(120, 200, 255))
		say(event.Text)
	elseif kind == "Wave" then
		local side = current.Sides[event.Side]
		side.Fighters = event.Fighters
		side.Active = 1
		side.Model = event.Model
		side.Name = event.Name
		showBanner(`WAVE {event.Wave}`, C.Gold)
		drawBoxes()
		say(event.Text)
	elseif kind == "Run" then
		say(event.Text)
	end
end

---------------------------------------------------------------- Start und Ende

local function setCamera(intro: boolean?)
	local camera = workspace.CurrentCamera
	local a = current.Sides[current.You].Anchor.Position
	local b = current.Sides[3 - current.You].Anchor.Position
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	local right = dir:Cross(Vector3.yAxis).Unit
	local distance = (b - a).Magnitude
	-- Klassische Kampfansicht: schraeg hinter der eigenen Bestie, Gegner oben rechts im Bild
	local position = a - dir * 11 + right * 7.5 + Vector3.new(0, 6.5, 0)
	local focus = a + dir * distance * 0.6 + Vector3.new(0, 2.5, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	if intro then
		-- Auftakt: nah am Gegner, dann faehrt die Kamera in die Kampfansicht zurueck
		camera.FieldOfView = 45
		camera.CFrame = CFrame.lookAt(b - dir * 9 + right * 2 + Vector3.new(0, 3, 0), b + Vector3.new(0, 2.2, 0))
		TweenService:Create(camera, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = CFrame.lookAt(position, focus), FieldOfView = 58 }):Play()
	else
		TweenService:Create(camera, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(position, focus), FieldOfView = 58 }):Play()
	end
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end

-- Uebergang: Streifen schliessen sich, danach oeffnet sich die Kampfszene
local function transition(color: Color3, covered: (() -> ())?)
	wipe:ClearAllChildren()
	wipe.Visible = true
	local bars = {}
	for i = 0, 7 do
		local fromLeft = i % 2 == 0
		local bar = create("Frame", { AnchorPoint = Vector2.new(if fromLeft then 1 else 0, 0), Position = UDim2.new(if fromLeft then 0 else 1, 0, i / 8, 0), Size = UDim2.new(1, 0, 1 / 8, 1), BackgroundColor3 = if i % 2 == 0 then C.Ink else color:Lerp(C.Ink, 0.6), Parent = wipe })
		table.insert(bars, { Bar = bar, Left = fromLeft })
		TweenService:Create(bar, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, i * 0.03), { Position = UDim2.new(if fromLeft then 1 else 0, 0, i / 8, 0) }):Play()
	end
	task.wait(0.6)
	-- Hinter den Streifen in die Kampf-Szene wechseln
	if covered then
		covered()
	end
	task.wait(0.15)
	for _, item in bars do
		TweenService:Create(item.Bar, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	end
	task.delay(0.35, function()
		wipe.Visible = false
	end)
end

local function onStart(payload)
	current = payload
	originalTransparency = {}
	for _, side in payload.Sides do
		side.IsWild = payload.Kind == "Wild" or payload.Kind == "Legend"
	end
	payload.Sides[payload.You].IsWild = false
	UI.SetHudVisible(false)
	gui.Enabled = true
	resultPanel.Visible = false
	clearCommands()
	local enemySide = payload.Sides[3 - payload.You]
	local enemy = fighterOf(3 - payload.You)
	local def = Config.BeastsById[enemy.Id]
	transition(if payload.Kind == "Legend" then Config.Types[def.Type].Color elseif payload.Kind == "Wild" then C.Green else C.Crimson, function()
		setCamera(true)
	end)
	drawBoxes()
	-- Eigene Bestie erst nach dem Ruf zeigen
	local myModel = modelOf(payload.You)
	setModelTransparency(myModel, 1, 0)
	local enemyModel = modelOf(3 - payload.You)
	myBox.Frame.Visible = false
	enemyBox.Frame.Visible = true
	if payload.Kind == "Wild" then
		say(`A wild {if enemy.Shiny then "PRISMATIC " else ""}{def.Name} appeared!`, 0.9)
	elseif payload.Kind == "Legend" then
		showBanner(def.Name:upper(), Config.Types[def.Type].Color)
		flash(enemyModel, Config.Types[def.Type].Color, 4)
		say(`The legendary {def.Name} appeared!`, 1)
	else
		local who = if enemySide.Title and payload.Kind ~= "Duel" then `{enemySide.Title} {enemySide.Name}` else enemySide.Name
		showBanner(if payload.Kind == "Gauntlet" then `WAVE {payload.Wave}` else enemySide.Name:upper(), C.Gold)
		say(`{who} wants to battle!`, 0.7)
		say(`{enemySide.Name} sent out {def.Name}!`, 0.4)
	end
	local mine = fighterOf(payload.You)
	myBox.Frame.Visible = true
	setModelTransparency(myModel, 0, 0.3)
	if myModel then
		burst(myModel:GetPivot().Position, Color3.fromRGB(240, 190, 60), 30)
	end
	say(`Go! {Config.BeastsById[mine.Id].Name}!`, 0.5)
end

local function onEnd(report)
	clearCommands()
	local won = report.Result == "Win" or report.Result == "Caught"
	local title = if report.Result == "Caught" then "CAUGHT!" elseif report.Result == "Win" then "VICTORY!" elseif report.Result == "Run" then "GOT AWAY" elseif report.Result == "Forfeit" then "GAVE UP" else "DEFEAT"
	if report.Whiteout then
		for _, line in report.Lines do
			say(line, 0.9)
		end
	end
	resultPanel:ClearAllChildren()
	Theme.corner(resultPanel, 14)
	Theme.stroke(resultPanel, C.Gold, 3)
	resultPanel.Visible = true
	local titleLabel = label({ Size = UDim2.new(1, 0, 0, 64), Text = title, Font = Theme.Title, TextSize = 52, TextColor3 = if won then C.Gold else C.Muted, Parent = resultPanel })
	Theme.textStroke(titleLabel, 3)
	local lines = {}
	if report.Coins > 0 then
		table.insert(lines, `<font color="#F2C14E">You got {Format.Coins(report.Coins)} for winning!</font>`)
	end
	if report.Caught then
		local where = if report.Caught.ToBox then " It was sent to your Box." else ""
		table.insert(lines, `<font color="#96FFF5">{Config.BeastsById[report.Caught.Id].Name} joined your team!{where}</font>`)
	end
	if report.Wave then
		table.insert(lines, `Reached wave {report.Wave}` .. (if report.Record then " · NEW RECORD!" else ""))
	end
	if report.Trophies then
		table.insert(lines, `{if report.Trophies > 0 then "+" else ""}{report.Trophies} trophies`)
	end
	if #lines == 0 then
		table.insert(lines, if won then "Great battle!" else "Train your team and try again!")
	end
	label({ Position = UDim2.fromOffset(20, 70), Size = UDim2.new(1, -40, 1, -140), RichText = true, Text = table.concat(lines, "\n"), TextSize = 20, TextYAlignment = Enum.TextYAlignment.Top, Parent = resultPanel })
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		-- Zurueck in die Welt hinter einem kurzen Uebergang
		transition(C.Ink, function()
			resultPanel.Visible = false
			restoreCamera()
		end)
		gui.Enabled = false
		current = nil
		UI.SetHudVisible(true)
		-- Nach dem Kampf: Entwicklungen und neue Attacken
		UI.ShowPostBattle(report.Events or {})
	end
	local ok = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(if report.CanContinue then 0.27 else 0.5, 0, 1, -16), Size = UDim2.fromOffset(200, 50), Text = "CONTINUE", TextSize = 22, Color = C.Crimson, Parent = resultPanel })
	ok.Activated:Connect(close)
	if report.CanContinue then
		local again = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.73, 0, 1, -16), Size = UDim2.fromOffset(240, 50), Text = `SECOND CHANCE R$ {Config.DevProducts.GauntletContinue.PriceHint}`, TextSize = 17, Color = C.Green, Parent = resultPanel })
		again.Activated:Connect(function()
			close()
			UI.Buy("Product", "GauntletContinue")
		end)
	end
	if won then
		burst(workspace.CurrentCamera.CFrame.Position + workspace.CurrentCamera.CFrame.LookVector * 12, C.Gold, 60)
	end
	-- Automatisch schliessen, damit Gespraeche danach nicht warten muessen
	task.delay(if report.CanContinue then 12 else 3, close)
end

local function processQueue()
	if processing then
		return
	end
	processing = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		local ok, err = pcall(function()
			if item.Kind == "Start" then
				onStart(item.Payload)
			elseif not current or (item.Payload.Id ~= nil and item.Payload.Id ~= current.Id) then
				return -- Nachricht aus einem alten Kampf
			elseif item.Kind == "Turn" then
				showTurn(item.Payload)
			elseif item.Kind == "Replace" then
				showReplace(item.Payload)
			elseif item.Kind == "Events" then
				clearCommands()
				for _, event in item.Payload.Events do
					local okEvent, errEvent = pcall(playEvent, event)
					if not okEvent then
						warn("[Battle] Ereignis", event.T, errEvent)
					end
				end
				remotes.BattleAction:FireServer({ Kind = "Ack", Seq = item.Payload.Seq })
			elseif item.Kind == "End" then
				onEnd(item.Payload)
			end
		end)
		if not ok then
			warn("[Battle]", err)
			if item.Kind == "Events" then
				remotes.BattleAction:FireServer({ Kind = "Ack", Seq = item.Payload.Seq })
			end
		end
	end
	processing = false
end

---------------------------------------------------------------- Aufbau

function Battle.Init()
	gui = create("ScreenGui", { Name = "Battle", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
	root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local scale = create("UIScale", { Parent = root })
	local function rescale()
		local size = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.55, 1.3)
		scale.Scale = s
		root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	enemyBox = makeBox(UDim2.fromOffset(24, 40), Vector2.new(0, 0), false)
	myBox = makeBox(UDim2.new(1, -24, 1, -186), Vector2.new(1, 1), true)

	-- Textbox unten (antippen beschleunigt den Text)
	textBox = create("TextButton", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -16), Size = UDim2.new(0.56, -24, 0, 150), BackgroundColor3 = C.Panel, AutoButtonColor = false, Text = "", Parent = root })
	Theme.corner(textBox, 14)
	Theme.stroke(textBox, C.Gold, 3)
	Theme.gradient(textBox, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 195, 200))
	local inner = create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundColor3 = C.PanelDark, Parent = textBox })
	Theme.corner(inner, 10)
	Theme.stroke(inner, C.GoldDark, 1.5)
	textLabel = label({ Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 1, -20), Text = "", TextSize = 24, Font = Theme.Heavy, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = inner })
	local timerBack = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -4), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = C.PanelDark, Parent = inner })
	timerFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold, Parent = timerBack })
	textBox.Activated:Connect(function()
		skipText = true
	end)

	commandPanel = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -16), Size = UDim2.new(0.44, -16, 0, 150), BackgroundTransparency = 1, Parent = root })
	popup = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -176), Size = UDim2.fromOffset(380, 200), BackgroundColor3 = C.Panel, Visible = false, ZIndex = 3, Parent = root })

	banner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(800, 90), Text = "", Font = Theme.Title, TextSize = 72, TextColor3 = C.Gold, Visible = false, ZIndex = 4, Parent = root })
	create("UIScale", { Parent = banner })
	Theme.textStroke(banner, 4)

	resultPanel = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(560, 300), Visible = false, ZIndex = 5, Parent = root })
	wipe = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 10, ClipsDescendants = true, Parent = root })

	remotes.Battle.OnClientEvent:Connect(function(kind, payload)
		table.insert(queue, { Kind = kind, Payload = payload })
		task.spawn(processQueue)
	end)
end

function Battle.Active(): boolean
	return current ~= nil
end

return Battle
