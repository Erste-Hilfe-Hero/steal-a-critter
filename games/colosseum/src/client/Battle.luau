-- Kampf-Oberflaeche: Kamera, Lebensbalken, Angriffsknoepfe, Taschen/Team-Auswahl und alle Animationen
-- (Ausfallschritt, Geschosse, Treffer, Schadenszahlen, Fang-Orb, Sieg/Niederlage).
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
local enemyCard, myCard
local messageLabel: TextLabel
local actionPanel: Frame
local moveRow: Frame
local toolRow: Frame
local popup: Frame
local timerFill: Frame
local banner: TextLabel
local resultPanel: Frame

local current = nil -- laufender Kampf
local queue = {} -- Nachrichten vom Server, werden nacheinander abgespielt
local processing = false
local autoOn = false
local originalTransparency = {} -- [BasePart] = number

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

local function nameOf(sideIndex: number): string
	local fighter = fighterOf(sideIndex)
	local prefix = if sideIndex == current.You then "Your " elseif current.Kind == "Wild" then "Wild " else "Foe "
	return prefix .. Config.BeastsById[fighter.Id].Name
end

local function setMessage(text: string)
	messageLabel.Text = text
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
	local info = model.PrimaryPart and model.PrimaryPart:FindFirstChild("Info") :: BillboardGui?
	if info then
		info.Enabled = alpha < 1
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

local function burst(position: Vector3, color: Color3, amount: number)
	local anchor = create("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Size = Vector3.one, CFrame = CFrame.new(position), Parent = workspace })
	local emitter = create("ParticleEmitter", {
		Color = ColorSequence.new(color),
		LightEmission = 0.7,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(0.4, 0.8),
		Speed = NumberRange.new(10, 20),
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

local function flash(model: Model?, color: Color3)
	if not model then
		return
	end
	local highlight = create("Highlight", { FillColor = color, FillTransparency = 0.2, OutlineTransparency = 1, Adornee = model, Parent = model })
	task.delay(0.12, function()
		highlight.FillTransparency = 0.7
	end)
	task.delay(0.24, function()
		highlight:Destroy()
	end)
end

---------------------------------------------------------------- Karten

local function makeCard(position: UDim2, anchor: Vector2, showNumbers: boolean)
	local card = Theme.panel({ AnchorPoint = anchor, Position = position, Size = UDim2.fromOffset(340, if showNumbers then 104 else 90), Parent = root })
	local nameLabel = label({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -110, 0, 30), Text = "", Font = Theme.Title, TextSize = 26, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	Theme.textStroke(nameLabel, 1.5)
	local levelLabel = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(80, 26), Text = "", Font = Theme.Title, TextSize = 22, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, Parent = card })
	local chipHolder = create("Frame", { Position = UDim2.fromOffset(14, 42), Size = UDim2.fromOffset(70, 20), BackgroundTransparency = 1, Parent = card })
	local _, fill = Theme.hpBar({ Position = UDim2.fromOffset(92, 44), Size = UDim2.new(1, -106, 0, 16), Parent = card })
	local numbers = label({ Position = UDim2.fromOffset(92, 64), Size = UDim2.new(1, -106, 0, 18), Text = "", TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right, Visible = showNumbers, Parent = card })
	local dots = create("Frame", { Position = UDim2.new(0, 14, 1, -22), Size = UDim2.fromOffset(200, 14), BackgroundTransparency = 1, Parent = card })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = dots })
	return { Frame = card, Name = nameLabel, Level = levelLabel, Chip = chipHolder, Fill = fill, Numbers = numbers, Dots = dots }
end

local function drawCard(card, sideIndex: number, animate: boolean?)
	local side = current.Sides[sideIndex]
	local fighter = fighterOf(sideIndex)
	local def = Config.BeastsById[fighter.Id]
	card.Name.Text = (if fighter.Shiny then "✦ " else "") .. def.Name
	card.Name.TextColor3 = if fighter.Shiny then C.Prism else C.Cream
	card.Level.Text = `Lv {fighter.Level}`
	card.Chip:ClearAllChildren()
	Theme.typeChip(def.Type, { Size = UDim2.fromOffset(70, 20), Parent = card.Chip })
	local fraction = fighter.Hp / fighter.MaxHp
	if animate then
		local goal = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		TweenService:Create(card.Fill, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = goal }):Play()
		task.delay(0.46, Theme.setHp, card.Fill, fraction)
	else
		Theme.setHp(card.Fill, fraction)
	end
	card.Numbers.Text = `{fighter.Hp}/{fighter.MaxHp} HP`
	for _, child in card.Dots:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for _, member in side.Fighters do
		local dot = create("Frame", { Size = UDim2.fromOffset(14, 14), BackgroundColor3 = if member.Hp > 0 then C.Gold else C.PanelLight, Parent = card.Dots })
		Theme.corner(dot, 7)
		Theme.stroke(dot, C.Ink, 1.5)
	end
end

local function drawCards(animate: boolean?)
	drawCard(myCard, current.You, animate)
	drawCard(enemyCard, 3 - current.You, animate)
end

---------------------------------------------------------------- Aktionen

local function clearButtons()
	moveRow:ClearAllChildren()
	toolRow:ClearAllChildren()
	popup.Visible = false
	popup:ClearAllChildren()
	for _, row in { moveRow, toolRow } do
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = row })
	end
end

local function send(action)
	clearButtons()
	setMessage(if current.Kind == "Duel" then "Waiting for your opponent..." else "...")
	remotes.BattleAction:FireServer(action)
end

local function openPopup(title: string, entries: { { Text: string, Sub: string?, Color: Color3?, Disabled: boolean?, OnPick: () -> () } })
	popup:ClearAllChildren()
	popup.Visible = true
	Theme.corner(popup, 12)
	Theme.stroke(popup, C.Gold, 2)
	label({ Size = UDim2.new(1, 0, 0, 30), Text = title, Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, Parent = popup })
	local list = create("Frame", { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 1, -44), BackgroundTransparency = 1, Parent = popup })
	create("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
	for _, entry in entries do
		local b = button({ Size = UDim2.new(1, 0, 0, 44), Text = "", Color = if entry.Disabled then C.PanelLight else (entry.Color or C.Crimson), Parent = list })
		label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.62, 0, 1, 0), Text = entry.Text, Font = Theme.Title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
		label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.38, -12, 1, 0), Text = entry.Sub or "", TextSize = 15, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Right, Parent = b })
		b.Activated:Connect(function()
			if not entry.Disabled then
				entry.OnPick()
			end
		end)
	end
	popup.Size = UDim2.fromOffset(340, 50 + #entries * 50)
end

local function showTurn(turn)
	clearButtons()
	local enemy = fighterOf(3 - current.You)
	local enemyType = Config.BeastsById[enemy.Id].Type
	setMessage(`What will {Config.BeastsById[fighterOf(current.You).Id].Name} do?`)
	for _, move in turn.Moves do
		local effect = Config.TypeMultiplier(move.Type, enemyType)
		local disabled = move.Uses ~= nil and move.Uses <= 0
		local b = button({ Size = UDim2.fromOffset(196, 62), Color = if disabled then C.PanelLight else Config.Types[move.Type].Color:Lerp(C.Ink, 0.35), Parent = moveRow })
		local nameLabel = label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 30), Text = move.Name, Font = Theme.Title, TextSize = 20, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
		Theme.textStroke(nameLabel, 1.5)
		local sub = `{move.Type:upper()} · PWR {move.Power}`
		if move.Uses then
			sub ..= ` · {move.Uses} left`
		end
		label({ Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 20), Text = sub, TextSize = 13, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = b })
		if effect > 1 or effect < 1 then
			local tag = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -10), Size = UDim2.fromOffset(70, 20), BackgroundTransparency = 0, BackgroundColor3 = if effect > 1 then C.Gold else C.PanelLight, Text = if effect > 1 then "SUPER!" else "WEAK", Font = Theme.Title, TextSize = 13, TextColor3 = C.Ink, Parent = b })
			Theme.corner(tag, 6)
		end
		b.Activated:Connect(function()
			if not disabled then
				send({ Kind = "Move", Key = move.Key })
			end
		end)
	end

	local items = turn.Items or {}
	local function tool(text: string, color: Color3, onPick: () -> ())
		local b = button({ Size = UDim2.fromOffset(112, 46), Text = text, TextSize = 17, Color = color, Parent = toolRow })
		b.Activated:Connect(onPick)
		return b
	end
	if current.Kind == "Wild" then
		tool("CATCH", C.Crimson, function()
			local entries = {}
			for _, key in { "Orb", "GreatOrb", "MasterOrb" } do
				local item = Config.Items[key]
				local count = items[key] or 0
				local chance = turn.Chances and turn.Chances[key] or 0
				if key == "MasterOrb" and count <= 0 then
					table.insert(entries, { Text = item.Name, Sub = `100% · R$ {Config.DevProducts.MasterOrb1.PriceHint}`, Color = C.Green, OnPick = function()
						UI.Buy("Product", "MasterOrb1")
					end })
				else
					table.insert(entries, { Text = `{item.Name} x{count}`, Sub = `{math.floor(chance * 100 + 0.5)}% catch`, Color = item.Color:Lerp(C.Ink, 0.3), Disabled = count <= 0, OnPick = function()
						send({ Kind = "Item", Key = key })
					end })
				end
			end
			openPopup("THROW AN ORB", entries)
		end)
	end
	tool("BAG", C.Green, function()
		local entries = {}
		for _, key in { "Potion", "SuperPotion" } do
			local item = Config.Items[key]
			local count = items[key] or 0
			table.insert(entries, { Text = `{item.Name} x{count}`, Sub = item.Description, Color = item.Color:Lerp(C.Ink, 0.35), Disabled = count <= 0, OnPick = function()
				send({ Kind = "Item", Key = key })
			end })
		end
		openPopup("BAG", entries)
	end)
	tool("TEAM", C.Blue, function()
		local entries = {}
		for index, member in turn.Team do
			local def = Config.BeastsById[member.Id]
			local isActive = index == turn.Active
			table.insert(entries, { Text = `{def.Name} Lv {member.Level}`, Sub = if isActive then "in battle" else `{member.Hp}/{member.MaxHp} HP`, Color = Config.Types[def.Type].Color:Lerp(C.Ink, 0.4), Disabled = isActive or member.Hp <= 0, OnPick = function()
				send({ Kind = "Swap", Index = index })
			end })
		end
		openPopup("SWITCH BEAST", entries)
	end)
	tool(if current.Kind == "Wild" then "RUN" else "GIVE UP", C.PanelLight, function()
		send({ Kind = "Run" })
	end)
	local auto = tool(if autoOn then "AUTO: ON" else "AUTO", if autoOn then C.Gold else C.PanelDark, function()
		autoOn = not autoOn
		remotes.BattleAction:FireServer({ Kind = "Auto", On = autoOn })
		if autoOn and player:GetAttribute("Pass_AutoBattle") then
			local enemyNow = fighterOf(3 - current.You)
			local best, bestScore = turn.Moves[1].Key, -1
			for _, move in turn.Moves do
				local score = move.Power * move.Accuracy * Config.TypeMultiplier(move.Type, Config.BeastsById[enemyNow.Id].Type)
				if (move.Uses == nil or move.Uses > 0) and score > bestScore then
					best, bestScore = move.Key, score
				end
			end
			send({ Kind = "Move", Key = best })
		elseif autoOn then
			autoOn = false
		end
	end)
	if not player:GetAttribute("Pass_AutoBattle") then
		auto.Text = "AUTO 🔒"
	end
	if turn.Auto and player:GetAttribute("Pass_AutoBattle") then
		clearButtons()
		setMessage("Auto battle...")
	end

	-- Zeitbalken
	timerFill.Size = UDim2.fromScale(1, 1)
	TweenService:Create(timerFill, TweenInfo.new(turn.Timeout, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) }):Play()
end

---------------------------------------------------------------- Ereignisse abspielen

local function playMove(event)
	local attackerModel = modelOf(event.Side)
	local targetModel = modelOf(event.Target)
	local typeColor = Config.Types[event.Type].Color
	setMessage(`{nameOf(event.Side)} used {event.Name}!`)
	if attackerModel and targetModel then
		local from = attackerModel:GetPivot()
		local targetPos = targetModel:GetPivot().Position
		local dir = Vector3.new(targetPos.X - from.Position.X, 0, targetPos.Z - from.Position.Z)
		dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
		if event.Type == "Normal" then
			-- Ausfallschritt zum Gegner und zurueck
			local lunge = from + dir * math.min(8, (targetPos - from.Position).Magnitude * 0.5)
			animatePivot(attackerModel, from, lunge, 0.18)
			flash(targetModel, Color3.new(1, 1, 1))
			animatePivot(attackerModel, lunge, from, 0.2)
		else
			animatePivot(attackerModel, from, from + dir * 1.5, 0.1)
			local ball = create("Part", {
				Shape = Enum.PartType.Ball,
				Size = Vector3.one * (if event.Ultimate then 3.2 else 1.8),
				Material = Enum.Material.Neon,
				Color = typeColor,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CFrame = CFrame.new(from.Position + Vector3.new(0, 1, 0)),
				Parent = workspace,
			})
			create("PointLight", { Color = typeColor, Range = 12, Brightness = 2, Parent = ball })
			local travel = TweenService:Create(ball, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(targetPos + Vector3.new(0, 0.5, 0)) })
			travel:Play()
			travel.Completed:Wait()
			ball:Destroy()
			burst(targetPos, typeColor, if event.Ultimate then 60 else 30)
			flash(targetModel, typeColor)
			animatePivot(attackerModel, from + dir * 1.5, from, 0.12)
		end
		if not event.Miss then
			-- Treffer-Wackeln
			local base = targetModel:GetPivot()
			for i = 1, 4 do
				targetModel:PivotTo(base * CFrame.new((if i % 2 == 0 then 0.5 else -0.5), 0, 0))
				task.wait(0.03)
			end
			targetModel:PivotTo(base)
		end
	end
	local target = fighterOf(event.Target)
	if event.Miss then
		floatText(targetModel, "MISS", C.Muted, 30)
		setMessage(`{nameOf(event.Side)}'s attack missed!`)
	else
		target.Hp = event.Hp
		local color = if event.Crit then C.Red elseif event.Eff > 1 then Color3.fromRGB(255, 160, 40) else C.Cream
		floatText(targetModel, `-{event.Damage}`, color, if event.Crit or event.Eff > 1 then 48 else 38)
		drawCards(true)
		local notes = {}
		if event.Crit then
			table.insert(notes, "A critical hit!")
		end
		if event.Eff > 1 then
			table.insert(notes, "It's super effective!")
		elseif event.Eff < 1 then
			table.insert(notes, "It's not very effective...")
		end
		if #notes > 0 then
			setMessage(table.concat(notes, " "))
		end
	end
	task.wait(0.5)
end

local function playCatch(event)
	local targetModel = modelOf(3 - event.Side)
	local myModel = modelOf(event.Side)
	local item = Config.Items[event.Item]
	setMessage(`You threw a {item.Name}!`)
	if not targetModel then
		task.wait(1)
		return
	end
	local start = (if myModel then myModel:GetPivot().Position else targetModel:GetPivot().Position) + Vector3.new(0, 3, 0)
	local finish = targetModel:GetPivot().Position
	local orb = create("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 1.6, Material = Enum.Material.Glass, Color = item.Color, Anchored = true, CanCollide = false, CanQuery = false, CFrame = CFrame.new(start), Parent = workspace })
	create("PointLight", { Color = item.Color, Range = 10, Parent = orb })
	-- Bogenwurf
	local t0 = os.clock()
	while os.clock() - t0 < 0.5 do
		local t = (os.clock() - t0) / 0.5
		local position = start:Lerp(finish, t) + Vector3.new(0, math.sin(t * math.pi) * 6, 0)
		orb.CFrame = CFrame.new(position) * CFrame.Angles(t * 10, 0, 0)
		RunService.Heartbeat:Wait()
	end
	burst(finish, item.Color, 25)
	setModelTransparency(targetModel, 1, 0.2)
	local ground = CFrame.new(Vector3.new(finish.X, 0.8, finish.Z))
	TweenService:Create(orb, TweenInfo.new(0.3, Enum.EasingStyle.Bounce), { CFrame = ground }):Play()
	task.wait(0.5)
	for _ = 1, event.Shakes do
		for _, angle in { 25, -25, 0 } do
			TweenService:Create(orb, TweenInfo.new(0.12), { CFrame = ground * CFrame.Angles(0, 0, math.rad(angle)) }):Play()
			task.wait(0.13)
		end
		task.wait(0.35)
	end
	if event.Success then
		burst(ground.Position, C.Gold, 50)
		floatText(targetModel, "GOTCHA!", C.Gold, 46)
		setMessage(`Gotcha! {Config.BeastsById[fighterOf(3 - event.Side).Id].Name} was caught!`)
		showBanner("CAUGHT!", C.Gold)
		task.wait(0.8)
		orb:Destroy()
	else
		burst(ground.Position, C.Cream, 30)
		orb:Destroy()
		setModelTransparency(targetModel, 0, 0.2)
		setMessage("Oh no! It broke free!")
		task.wait(0.6)
	end
end

local function playEvent(event)
	if event.T == "Move" then
		playMove(event)
	elseif event.T == "Faint" then
		local model = modelOf(event.Side)
		setMessage(`{nameOf(event.Side)} fainted!`)
		setModelTransparency(model, 1, 0.6)
		if model then
			local from = model:GetPivot()
			animatePivot(model, from, from - Vector3.new(0, 1.5, 0), 0.6)
		end
		task.wait(0.4)
	elseif event.T == "Send" then
		local side = current.Sides[event.Side]
		side.Active = event.Index
		side.Fighters[event.Index] = event.Fighter
		side.Model = event.Model
		local model = modelOf(event.Side)
		if model then
			local base = model:GetPivot()
			animatePivot(model, base + Vector3.new(0, 6, 0), base, 0.3)
			burst(base.Position, C.Gold, 20)
		end
		setMessage(if event.Side == current.You then `Go, {Config.BeastsById[event.Fighter.Id].Name}!` else `The foe sent out {Config.BeastsById[event.Fighter.Id].Name}!`)
		drawCards()
		task.wait(0.6)
	elseif event.T == "Item" then
		local fighter = fighterOf(event.Side)
		fighter.Hp = event.Hp
		local model = modelOf(event.Side)
		burst(if model then model:GetPivot().Position else Vector3.zero, C.Green, 30)
		floatText(model, "+HP", C.Green, 36)
		setMessage(`{nameOf(event.Side)} was healed with a {Config.Items[event.Item].Name}!`)
		drawCards(true)
		task.wait(0.6)
	elseif event.T == "Catch" then
		playCatch(event)
	elseif event.T == "Wave" then
		local side = current.Sides[event.Side]
		side.Fighters = event.Fighters
		side.Active = 1
		side.Model = event.Model
		side.Name = event.Name
		showBanner(`WAVE {event.Wave}`, C.Gold)
		setMessage(`Wave {event.Wave}! New challengers enter the arena!`)
		drawCards()
		task.wait(1.4)
	elseif event.T == "Run" then
		setMessage(if current.Kind == "Wild" then "Got away safely!" else `{if event.Side == current.You then "You" else "Your opponent"} gave up!`)
		task.wait(0.8)
	end
end

---------------------------------------------------------------- Start und Ende

local function setCamera()
	local camera = workspace.CurrentCamera
	local a = current.Sides[current.You].Anchor.Position
	local b = current.Sides[3 - current.You].Anchor.Position
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	local right = dir:Cross(Vector3.yAxis).Unit
	local distance = (b - a).Magnitude
	local position = a - dir * 11 + right * 9 + Vector3.new(0, 7, 0)
	local focus = a + dir * distance * 0.55 + Vector3.new(0, 2.5, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { CFrame = CFrame.lookAt(position, focus), FieldOfView = 60 }):Play()
end

local function restoreCamera()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
end

local function onStart(payload)
	current = payload
	originalTransparency = {}
	UI.SetHudVisible(false)
	gui.Enabled = true
	resultPanel.Visible = false
	actionPanel.Visible = true
	clearButtons()
	drawCards()
	setCamera()
	local title = if payload.Kind == "Wild" then "WILD BATTLE!"
		elseif payload.Kind == "Champion" then Config.Champions[payload.Champion].Name:upper()
		elseif payload.Kind == "Gauntlet" then `GAUNTLET · WAVE {payload.Wave}`
		else "DUEL!"
	showBanner(title, C.Gold)
	local enemy = fighterOf(3 - payload.You)
	local def = Config.BeastsById[enemy.Id]
	setMessage(if payload.Kind == "Wild" then `A wild {if enemy.Shiny then "PRISMATIC " else ""}{def.Name} appeared!` else `{payload.Sides[3 - payload.You].Name} wants to battle!`)
end

local function onEnd(report)
	clearButtons()
	actionPanel.Visible = false
	local won = report.Result == "Win" or report.Result == "Caught"
	local title = if report.Result == "Caught" then "CAUGHT!" elseif report.Result == "Win" then "VICTORY!" elseif report.Result == "Run" then "ESCAPED" else "DEFEAT"
	resultPanel:ClearAllChildren()
	Theme.corner(resultPanel, 14)
	Theme.stroke(resultPanel, C.Gold, 3)
	resultPanel.Visible = true
	local titleLabel = label({ Size = UDim2.new(1, 0, 0, 64), Text = title, Font = Theme.Title, TextSize = 52, TextColor3 = if won then C.Gold else C.Muted, Parent = resultPanel })
	Theme.textStroke(titleLabel, 3)
	local lines = {}
	if report.Coins > 0 then
		table.insert(lines, `<font color="#F2C14E">+{Format.Coins(report.Coins)}</font>`)
	end
	for _, xp in report.Xp do
		table.insert(lines, `{Config.BeastsById[xp.Id].Name} +{Format.Number(xp.Amount)} XP`)
	end
	for _, event in report.Events do
		if event.T == "Level" then
			table.insert(lines, `<font color="#78DCFF">{Config.BeastsById[event.S].Name} reached Lv {event.L}!</font>`)
		elseif event.T == "Evolve" then
			table.insert(lines, `<font color="#F2C14E">{Config.BeastsById[event.From].Name} ascended into {Config.BeastsById[event.To].Name}!</font>`)
		end
	end
	if report.Caught then
		table.insert(lines, `<font color="#96FFF5">{Config.BeastsById[report.Caught.Id].Name} joined your collection!</font>`)
	end
	if report.Crest then
		table.insert(lines, `<font color="#F2C14E">You earned the {Config.Champions[report.Crest].Title} Crest!</font>`)
	end
	if report.Wave then
		table.insert(lines, `Reached wave {report.Wave}` .. (if report.Record then " · NEW RECORD!" else ""))
	end
	if report.Trophies then
		table.insert(lines, `{if report.Trophies > 0 then "+" else ""}{report.Trophies} trophies`)
	end
	label({ Position = UDim2.fromOffset(20, 70), Size = UDim2.new(1, -40, 1, -140), RichText = true, Text = table.concat(lines, "\n"), TextSize = 20, TextYAlignment = Enum.TextYAlignment.Top, Parent = resultPanel })
	local ok = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(if report.CanContinue then 0.27 else 0.5, 0, 1, -16), Size = UDim2.fromOffset(200, 50), Text = "CONTINUE", TextSize = 22, Color = C.Crimson, Parent = resultPanel })
	local function close()
		resultPanel.Visible = false
		gui.Enabled = false
		current = nil
		restoreCamera()
		UI.SetHudVisible(true)
	end
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
				task.wait(1.2)
			elseif current and item.Payload.Id ~= nil and item.Payload.Id ~= current.Id then
				return -- Nachricht aus einem alten Kampf
			elseif item.Kind == "Turn" and current then
				showTurn(item.Payload)
			elseif item.Kind == "Events" and current then
				clearButtons()
				for _, event in item.Payload.Events do
					playEvent(event)
				end
			elseif item.Kind == "End" and current then
				onEnd(item.Payload)
			end
		end)
		if not ok then
			warn("[Battle]", err)
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

	-- Kinoleisten oben und unten fuer den Arena-Look
	for _, y in { 0, 1 } do
		local bar = create("Frame", { AnchorPoint = Vector2.new(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.2, Parent = root })
		create("Frame", { AnchorPoint = Vector2.new(0, 1 - y), Position = UDim2.fromScale(0, 1 - y), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Gold, Parent = bar })
	end

	enemyCard = makeCard(UDim2.new(1, -24, 0, 40), Vector2.new(1, 0), false)
	myCard = makeCard(UDim2.new(0, 24, 1, -232), Vector2.new(0, 1), true)

	actionPanel = Theme.panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -36), Size = UDim2.new(1, -48, 0, 150), Parent = root })
	local timerBack = create("Frame", { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = C.PanelDark, Parent = actionPanel })
	timerFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Gold, Parent = timerBack })
	local messageBox = create("Frame", { Position = UDim2.fromOffset(12, 18), Size = UDim2.new(0.34, -12, 1, -30), BackgroundColor3 = C.PanelDark, Parent = actionPanel })
	Theme.corner(messageBox, 10)
	Theme.stroke(messageBox, C.GoldDark, 1.5)
	messageLabel = label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 1, -12), Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Parent = messageBox })
	moveRow = create("Frame", { Position = UDim2.new(0.34, 8, 0, 18), Size = UDim2.new(0.66, -20, 0, 64), BackgroundTransparency = 1, Parent = actionPanel })
	toolRow = create("Frame", { Position = UDim2.new(0.34, 8, 0, 92), Size = UDim2.new(0.66, -20, 0, 46), BackgroundTransparency = 1, Parent = actionPanel })
	popup = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -196), Size = UDim2.fromOffset(340, 200), BackgroundColor3 = C.Panel, Visible = false, ZIndex = 3, Parent = root })

	banner = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(800, 90), Text = "", Font = Theme.Title, TextSize = 72, TextColor3 = C.Gold, Visible = false, ZIndex = 4, Parent = root })
	create("UIScale", { Parent = banner })
	Theme.textStroke(banner, 4)

	resultPanel = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 380), Visible = false, ZIndex = 5, Parent = root })

	remotes.Battle.OnClientEvent:Connect(function(kind, payload)
		table.insert(queue, { Kind = kind, Payload = payload })
		task.spawn(processQueue)
	end)
end

function Battle.Active(): boolean
	return current ~= nil
end

return Battle
