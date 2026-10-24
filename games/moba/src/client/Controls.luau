-- Steuerung wie im Original: Rechtsklick laufen oder angreifen, Q/W/E/R halten zum Zielen und loslassen
-- zum Wirken, Strg+Taste zum Leveln, D/F Beschwoererzauber, B Rueckruf, 4 Ward, 1 Trank, 2 Stasis,
-- S Stopp, A Angriffsbewegung. Am Handy: Joystick links, Angriffs-Knopf und Faehigkeiten zum Ziehen rechts.
local GuiService = game:GetService("GuiService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local CameraController = require(script.Parent.CameraController)
local Kit = require(script.Parent.Kit)
local Vision = require(script.Parent.Vision)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local match = ReplicatedStorage:WaitForChild("Match")

local INK, INK2, INK3, TEXT = Kit.INK, Kit.INK2, Kit.INK3, Kit.TEXT
local GOLD, CRYSTAL, RED = Kit.GOLD, Kit.CRYSTAL, Kit.RED
local TITLE, SMALL = Kit.TITLE, Kit.SMALL
local create, corner, round, line, text, panel = Kit.create, Kit.corner, Kit.round, Kit.line, Kit.text, Kit.panel

local Controls = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function mobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rootOf(model: Instance?): BasePart?
	if not model or not model:IsA("Model") then
		return nil
	end
	return ((model :: any).PrimaryPart or model:FindFirstChild("HumanoidRootPart")) :: any
end

local function heroDef()
	return Config.HeroesById[player:GetAttribute("Hero") or ""]
end

local function rankOf(key: string): number
	local list = string.split(player:GetAttribute("Ranks") or "0,0,0,0", ",")
	local index = table.find(Config.AbilityKeys, key)
	return if index then tonumber(list[index]) or 0 else 0
end

local function playing(): boolean
	return match:GetAttribute("Phase") == "Playing" and player:GetAttribute("Hero") ~= nil and not player:GetAttribute("Dead")
end

-- Bildschirmpunkt (ohne Inset, wie bei Touch) -> Viewport-Punkt (mit Inset, wie die Kamera rechnet)
local function toViewport(screen: Vector2): Vector2
	local inset = GuiService:GetGuiInset()
	return screen + inset
end

---------------------------------------------------------------- Zielanzeige

local fxFolder = create("Folder", { Name = "AimFx" }) :: Folder

local function disc(color: Color3, transparency: number): Part
	return create("Part", {
		Shape = Enum.PartType.Cylinder,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = transparency,
		Size = Vector3.new(0.12, 1, 1),
		Parent = fxFolder,
	}) :: Part
end

local rangeDisc = disc(Color3.fromRGB(120, 200, 255), 0.82)
local areaDisc = disc(Color3.fromRGB(150, 220, 255), 0.55)
local lineBar = create("Part", {
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
	CastShadow = false,
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(150, 220, 255),
	Transparency = 0.55,
	Size = Vector3.new(1, 0.12, 1),
	Parent = fxFolder,
}) :: Part

local function hideAim()
	for _, p in { rangeDisc, areaDisc, lineBar } do
		p.Transparency = 1
	end
end
hideAim()

local function placeDisc(p: Part, center: Vector3, radius: number, transparency: number)
	p.Size = Vector3.new(0.12, radius * 2, radius * 2)
	p.CFrame = CFrame.new(center.X, 0.35, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Transparency = transparency
end

-- Was eine Taste anzeigen und wie weit sie zielen kann
type Shape = "Self" | "Line" | "Circle" | "Target" | "Global"
local function shapeOf(kind: string, key: string): (Shape, number, number)
	if kind == "Ward" then
		return "Circle", Config.Ward.Range, 3
	elseif kind == "Spell" then
		local spell = Config.SpellsById[player:GetAttribute("Spell" .. key) or ""]
		if not spell then
			return "Self", 0, 0
		end
		if spell.Id == "Teleport" then
			return "Global", 0, 0
		elseif spell.Id == "Flash" then
			return "Circle", spell.Range, 2
		elseif spell.Range then
			return "Target", spell.Range, 0
		end
		return "Self", 0, 0
	end
	local hero = heroDef()
	local ability = hero and hero.Abilities[key]
	if not ability then
		return "Self", 0, 0
	end
	local t = ability.Type
	if t == "Line" or t == "Cone" then
		return "Line", ability.Length or ability.Range or 30, ability.Width or (if t == "Cone" then 10 else 3)
	elseif t == "Point" or t == "Dash" or t == "Blink" or (t == "Zone" and not ability.Self) then
		return "Circle", ability.Range or 20, ability.Radius or 3
	elseif t == "Target" or t == "Rush" or t == "HealAlly" then
		return "Target", ability.Range or 20, 0
	elseif t == "Heal" then
		return "Self", 0, 0
	end
	return "Self", ability.Radius or 0, 0
end

---------------------------------------------------------------- Laufen

local pathToken = 0
local waypoints: { Vector3 }? = nil
local waypointIndex = 1
local lastMoveSent = 0
local lastPathAt = 0
local lastPathGoal: Vector3? = nil

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- Freie Sicht in Hueft-Hoehe = kein Fels oder Mauer dazwischen
local function directClear(from: Vector3, to: Vector3): boolean
	local exclude: { Instance } = { fxFolder }
	local units = workspace:FindFirstChild("Units")
	if units then
		table.insert(exclude, units)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local a = Vector3.new(from.X, 2.5, from.Z)
	local delta = Vector3.new(to.X, 2.5, to.Z) - a
	if delta.Magnitude < 0.5 then
		return true
	end
	return workspace:Raycast(a, delta, rayParams) == nil
end

local function sendMove(force: boolean?)
	local t = os.clock()
	if force or t - lastMoveSent > 0.2 then
		lastMoveSent = t
		remotes.Move:FireServer()
	end
end

local function computePath(from: Vector3, goal: Vector3)
	pathToken += 1
	local token = pathToken
	lastPathAt = os.clock()
	lastPathGoal = goal
	task.spawn(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false, WaypointSpacing = 5 })
		local ok = pcall(function()
			path:ComputeAsync(Vector3.new(from.X, 3, from.Z), Vector3.new(goal.X, 3, goal.Z))
		end)
		if token ~= pathToken then
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			local list = {}
			for _, point in path:GetWaypoints() do
				table.insert(list, flat(point.Position))
			end
			waypoints = list
			waypointIndex = math.min(2, #list)
		else
			waypoints = { flat(goal) }
			waypointIndex = 1
		end
	end)
end

local function moveTo(goal: Vector3)
	local root = rootOf(player.Character)
	if not root then
		return
	end
	if directClear(root.Position, goal) then
		pathToken += 1
		waypoints = { flat(goal) }
		waypointIndex = 1
	else
		computePath(root.Position, goal)
	end
end

local function stopMoving()
	pathToken += 1
	waypoints = nil
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero)
	end
end

local clickMarker = disc(Color3.fromRGB(110, 231, 160), 1)
local function showClick(at: Vector3, color: Color3)
	clickMarker.Color = color
	placeDisc(clickMarker, at, 0.4, 0.2)
	TweenService:Create(clickMarker, TweenInfo.new(0.35), { Size = Vector3.new(0.12, 4, 4), Transparency = 1 }):Play()
end

-- Bodenklick: Gegner anvisieren oder dorthin laufen
local function commandAt(viewport: Vector2, attackMove: boolean?)
	if not playing() then
		return
	end
	local unit = CameraController.UnitAt(viewport, true, Vision.Seen)
	local ground = CameraController.GroundAt(viewport)
	if not unit and attackMove and ground then
		-- Angriffsbewegung: naechster sichtbarer Gegner beim Klickpunkt
		local best, bestDistance = nil, 30
		for _, model in game:GetService("CollectionService"):GetTagged("Unit") do
			local team = model:GetAttribute("Team")
			local r = rootOf(model)
			if r and team ~= player:GetAttribute("Team") and (model:GetAttribute("HP") or 0) > 0 and Vision.Seen(model) and model:GetAttribute("Kind") ~= "Ward" then
				local distance = (flat(r.Position) - flat(ground)).Magnitude
				if distance < bestDistance then
					best, bestDistance = model, distance
				end
			end
		end
		unit = best
	end
	if unit then
		CameraController.SetFocus(unit)
		stopMoving()
		local r = rootOf(unit)
		if r then
			showClick(r.Position, RED)
		end
	elseif ground then
		CameraController.SetFocus(nil, true)
		moveTo(ground)
		sendMove(true)
		showClick(ground, Color3.fromRGB(110, 231, 160))
	end
end

---------------------------------------------------------------- Wirken

local function castKey(kind: string, key: string, aim: Vector3?)
	if not playing() then
		return
	end
	if kind == "Ability" then
		remotes.Cast:FireServer(key, aim)
	elseif kind == "Spell" then
		remotes.CastSpell:FireServer(key, aim)
	elseif kind == "Ward" then
		remotes.UseItem:FireServer("Ward", aim)
	end
end

-- Laufendes Zielen: Tastatur (Maus zeigt) oder Finger (Ziehen vom Knopf)
local aiming: {
	Kind: string,
	Key: string,
	Touch: InputObject?,
	Start: Vector2?,
	Current: Vector2?,
}? = nil

local cancelZone: Frame? = nil

local function aimPoint(): (Vector3?, boolean)
	local current = aiming
	local root = rootOf(player.Character)
	if not current or not root then
		return nil, false
	end
	local shape, reach = shapeOf(current.Kind, current.Key)
	local origin = flat(root.Position)
	if current.Touch and current.Start and current.Current then
		local drag = current.Current - current.Start
		if drag.Magnitude < 15 then
			return nil, false
		end
		local dir = (CameraController.ScreenRight() * drag.X - CameraController.ScreenUp() * drag.Y).Unit
		if shape == "Global" then
			return origin + dir * math.min(drag.Magnitude * 2, 300), true
		end
		local amount = math.clamp(drag.Magnitude / 90, 0.15, 1)
		if shape == "Line" or shape == "Target" then
			amount = 1
		end
		return origin + dir * reach * amount, true
	end
	local mouse = CameraController.MouseGround()
	if not mouse then
		return nil, false
	end
	mouse = flat(mouse)
	if shape ~= "Global" and (mouse - origin).Magnitude > reach and reach > 0 and shape ~= "Target" then
		mouse = origin + (mouse - origin).Unit * reach
	end
	return mouse, true
end

local function overCancel(position: Vector2?): boolean
	local zone = cancelZone
	if not zone or not zone.Visible or not position then
		return false
	end
	local p, s = zone.AbsolutePosition, zone.AbsoluteSize
	return position.X >= p.X and position.X <= p.X + s.X and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

local function updateAim()
	local current = aiming
	local root = rootOf(player.Character)
	if not current or not root or not playing() then
		hideAim()
		return
	end
	local shape, reach, area = shapeOf(current.Kind, current.Key)
	local origin = flat(root.Position)
	local cancel = overCancel(current.Current)
	local color = if cancel then RED else Color3.fromRGB(150, 220, 255)
	areaDisc.Color, lineBar.Color = color, color
	if shape ~= "Global" and reach > 0 then
		placeDisc(rangeDisc, origin, reach + 1, 0.85)
	else
		rangeDisc.Transparency = 1
	end
	local point = aimPoint()
	areaDisc.Transparency = 1
	lineBar.Transparency = 1
	if not point then
		return
	end
	if shape == "Line" then
		local dir = (point - origin)
		if dir.Magnitude < 0.1 then
			return
		end
		dir = dir.Unit
		local finish = origin + dir * reach
		lineBar.Size = Vector3.new(area * 2, 0.12, reach)
		lineBar.CFrame = CFrame.lookAt((origin + finish) / 2 + Vector3.new(0, 0.4, 0), finish + Vector3.new(0, 0.4, 0))
		lineBar.Transparency = 0.6
	elseif shape == "Circle" then
		placeDisc(areaDisc, point, math.max(area, 1.5), 0.5)
	elseif shape == "Target" or shape == "Global" then
		placeDisc(areaDisc, point, 1.5, 0.5)
	end
end

local function beginAim(kind: string, key: string, touch: InputObject?, start: Vector2?)
	local shape = shapeOf(kind, key)
	if shape == "Self" then
		castKey(kind, key, nil)
		return
	end
	aiming = { Kind = kind, Key = key, Touch = touch, Start = start, Current = start }
	if cancelZone then
		cancelZone.Visible = touch ~= nil
	end
end

local function finishAim(cancel: boolean?)
	local current = aiming
	if not current then
		return
	end
	local point, hasPoint = aimPoint()
	if overCancel(current.Current) then
		cancel = true
	end
	aiming = nil
	hideAim()
	if cancelZone then
		cancelZone.Visible = false
	end
	if not cancel then
		castKey(current.Kind, current.Key, if hasPoint then point else nil)
	end
end

---------------------------------------------------------------- Knoepfe

local gui = create("ScreenGui", { Name = "Controls", ResetOnSpawn = false, IgnoreGuiInset = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 2 }) :: ScreenGui
local uiScale = create("UIScale", { Parent = gui }) :: UIScale
local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui }) :: Frame

local function rescale()
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.58, 1.3)
	uiScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end

cancelZone = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(150, 54), Visible = false, Parent = root, BackgroundColor3 = Color3.fromRGB(80, 20, 30), Radius = 27 })
text({ Size = UDim2.fromScale(1, 1), Text = "✕ CANCEL", Font = TITLE, TextColor3 = RED, Parent = cancelZone :: Frame })

-- PC: Leiste unten in der Mitte wie im Original
local bar = panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 38, 1, -4), Size = UDim2.fromOffset(464, 86), Parent = root, Radius = 16 })

type Slot = {
	Kind: string,
	Key: string,
	Holder: TextButton,
	Icon: TextLabel,
	Shade: Frame,
	Count: TextLabel,
	KeyLabel: TextLabel,
	Stack: TextLabel,
	Pips: Frame?,
	Plus: TextButton?,
}
local slots: { Slot } = {}
local slotsByKey: { [string]: Slot } = {}

local function makeSlot(kind: string, key: string, label: string): Slot
	local holder = create("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = INK2, Text = "", AutoButtonColor = false, Parent = root }, {
		corner(12),
		line(0.4, GOLD, 2),
		create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 190)) }),
	}) :: TextButton
	local icon = text({ Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.12), Text = "", Parent = holder })
	local shade = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2, Parent = holder }, { corner(12) }) :: Frame
	local count = text({ Size = UDim2.fromScale(0.7, 0.5), Position = UDim2.fromScale(0.15, 0.25), Text = "", Font = TITLE, Outline = 2, ZIndex = 3, Parent = holder })
	local keyLabel = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 3, 1, -2), Size = UDim2.fromOffset(18, 14), Text = label, Font = SMALL, TextColor3 = GOLD, Outline = 1, ZIndex = 3, Parent = holder })
	local stack = text({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -2), Size = UDim2.fromOffset(22, 14), Text = "", Font = SMALL, Outline = 1, ZIndex = 3, Parent = holder })
	local slot: Slot = { Kind = kind, Key = key, Holder = holder, Icon = icon, Shade = shade, Count = count, KeyLabel = keyLabel, Stack = stack }

	if kind == "Ability" then
		local pips = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 3), Size = UDim2.new(1, 0, 0, 5), BackgroundTransparency = 1, Parent = holder }, {
			create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 3) }),
		}) :: Frame
		for i = 1, if key == "R" then 3 else 5 do
			create("Frame", { Name = "Pip" .. i, Size = UDim2.fromOffset(7, 5), BackgroundColor3 = INK3, BorderSizePixel = 0, LayoutOrder = i, Parent = pips }, { corner(2) })
		end
		slot.Pips = pips
		local plus = create("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -4), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = GOLD, Text = "+", TextScaled = true, Font = TITLE, TextColor3 = INK, Visible = false, ZIndex = 4, Parent = holder }, { round(), line(0.2, Color3.new(1, 1, 1), 1.5) }) :: TextButton
		plus.Activated:Connect(function()
			remotes.LevelUp:FireServer(key)
		end)
		slot.Plus = plus
	end

	-- Druecken und Ziehen = Zielen, kurz tippen = automatisch zielen
	holder.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then
			return
		end
		if kind == "Potion" then
			remotes.UseItem:FireServer("Potion")
		elseif kind == "Stasis" then
			remotes.UseItem:FireServer("Stasis")
		elseif kind == "Recall" then
			remotes.Recall:FireServer()
		elseif kind == "Attack" then
			remotes.Attack:FireServer(true)
		elseif kind == "Ability" or kind == "Spell" or kind == "Ward" then
			if t == Enum.UserInputType.Touch then
				beginAim(kind, key, input, Vector2.new(input.Position.X, input.Position.Y))
			else
				-- Maus-Klick auf den Knopf: sofort wirken (zielt automatisch)
				castKey(kind, key, nil)
			end
		end
	end)

	table.insert(slots, slot)
	slotsByKey[key] = slot
	return slot
end

for _, key in Config.AbilityKeys do
	makeSlot("Ability", key, key)
end
makeSlot("Spell", "D", "D")
makeSlot("Spell", "F", "F")
makeSlot("Potion", "Potion", "1")
makeSlot("Stasis", "Stasis", "2")
makeSlot("Ward", "Ward", "4")
makeSlot("Recall", "Recall", "B")
local attackSlot = makeSlot("Attack", "Attack", "")
attackSlot.Icon.Text = "⚔️"

-- Positionen fuer PC (Leiste) und Handy (Bogen rechts unten)
local PC = {
	Q = { 0.5, -150, -54, 56 }, W = { 0.5, -88, -54, 56 }, E = { 0.5, -26, -54, 56 }, R = { 0.5, 36, -54, 56 },
	D = { 0.5, 96, -64, 40 }, F = { 0.5, 142, -64, 40 },
	Potion = { 0.5, 188, -64, 40 }, Stasis = { 0.5, 234, -64, 40 },
	Ward = { 0.5, 96, -24, 30 }, Recall = { 0.5, 142, -24, 30 },
}
local MOBILE = {
	Attack = { 1, -84, -84, 104 },
	Q = { 1, -198, -52, 66 }, W = { 1, -190, -146, 66 }, E = { 1, -122, -208, 66 }, R = { 1, -40, -226, 66 },
	D = { 1, -282, -42, 50 }, F = { 1, -340, -42, 50 },
	Recall = { 1, -398, -36, 44 }, Ward = { 1, -278, -102, 44 }, Potion = { 1, -448, -36, 44 }, Stasis = { 1, -330, -102, 44 },
}

local function spotFor(key: string)
	return (if mobile() then MOBILE else PC)[key]
end

local function layout()
	local isMobile = mobile()
	bar.Visible = not isMobile
	local map = if isMobile then MOBILE else PC
	for _, slot in slots do
		local spot = map[slot.Key]
		slot.Holder.Visible = spot ~= nil
		if spot then
			slot.Holder.Position = UDim2.new(spot[1], spot[2], 1, spot[3])
			slot.Holder.Size = UDim2.fromOffset(spot[4], spot[4])
			local cornerRadius = slot.Holder:FindFirstChildOfClass("UICorner")
			if cornerRadius then
				cornerRadius.CornerRadius = if isMobile then UDim.new(1, 0) else UDim.new(0, 12)
			end
			slot.Shade:FindFirstChildOfClass("UICorner").CornerRadius = if isMobile then UDim.new(1, 0) else UDim.new(0, 12)
			slot.KeyLabel.Visible = not isMobile
		end
	end
end

-- Joystick links (Handy)
local joyBase = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 120, 1, -120), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = INK, BackgroundTransparency = 0.55, Visible = false, Parent = root }, { round(), line(0.5, Color3.new(1, 1, 1), 2) }) :: Frame
local joyKnob = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundColor3 = TEXT, BackgroundTransparency = 0.25, Parent = joyBase }, { round() }) :: Frame
local joyTouch: InputObject? = nil
local joyCenter = Vector2.zero
local joyVector = Vector2.zero
local JOY_RADIUS = 60

---------------------------------------------------------------- Anzeige

local function setCooldown(slot: Slot, ready: number, total: number)
	local left = ready - now()
	if left > 0 then
		slot.Shade.Size = UDim2.fromScale(1, math.clamp(left / math.max(total, 0.1), 0, 1))
		slot.Count.Text = if left < 1 then string.format("%.1f", left) else tostring(math.ceil(left))
	else
		slot.Shade.Size = UDim2.fromScale(1, 0)
		slot.Count.Text = ""
	end
end

local function refresh()
	local hero = heroDef()
	local inGame = playing() or (match:GetAttribute("Phase") == "Playing" and player:GetAttribute("Hero") ~= nil)
	root.Visible = inGame
	if not hero or not inGame then
		return
	end
	local level = player:GetAttribute("Level") or 1
	local points = player:GetAttribute("SkillPoints") or 0
	local mana = player:GetAttribute("Mana") or 0
	local maxMana = player:GetAttribute("MaxMana") or 0
	local items = string.split(player:GetAttribute("Items") or "", ",")
	local isMobile = mobile()
	for _, slot in slots do
		local key = slot.Key
		local stroke = slot.Holder:FindFirstChildOfClass("UIStroke") :: UIStroke
		if slot.Kind == "Ability" then
			local ability = hero.Abilities[key]
			local rank = rankOf(key)
			slot.Icon.Text = ability.Icon or key
			setCooldown(slot, player:GetAttribute("CD_" .. key) or 0, player:GetAttribute("CDMax_" .. key) or 1)
			local cost = Config.AtRank(ability.Cost, math.max(rank, 1))
			local noMana = maxMana > 0 and cost > mana
			slot.Holder.BackgroundColor3 = if rank == 0 then Color3.fromRGB(16, 18, 30) elseif noMana then Color3.fromRGB(24, 40, 90) else INK2
			slot.Icon.TextTransparency = if rank == 0 then 0.6 else 0
			stroke.Transparency = if rank == 0 then 0.85 else 0.3
			stroke.Color = if noMana then CRYSTAL else GOLD
			slot.Stack.Text = if cost > 0 and not isMobile then tostring(math.floor(cost)) else ""
			slot.Stack.TextColor3 = CRYSTAL
			local pips = slot.Pips
			if pips then
				for i = 1, 5 do
					local pip = pips:FindFirstChild("Pip" .. i) :: Frame?
					if pip then
						pip.BackgroundColor3 = if i <= rank then GOLD else INK3
					end
				end
			end
			if slot.Plus then
				slot.Plus.Visible = points > 0 and Config.CanRank(key, rank, level)
			end
		elseif slot.Kind == "Spell" then
			local spell = Config.SpellsById[player:GetAttribute("Spell" .. key) or ""]
			slot.Icon.Text = if spell then spell.Icon else "?"
			setCooldown(slot, player:GetAttribute("CD_" .. key) or 0, player:GetAttribute("CDMax_" .. key) or 1)
			slot.Stack.Text = if spell and spell.Id == "Smite" then tostring(player:GetAttribute("SmiteCharges") or 0) else ""
			if spell and spell.Id == "Smite" and (player:GetAttribute("SmiteCharges") or 0) > 0 then
				slot.Shade.Size = UDim2.fromScale(1, 0)
				slot.Count.Text = ""
			end
		elseif slot.Kind == "Potion" then
			local potions = player:GetAttribute("Potions") or 0
			slot.Icon.Text = "🧪"
			slot.Stack.Text = tostring(potions)
			slot.Icon.TextTransparency = if potions > 0 then 0 else 0.6
			slot.Holder.Visible = spotFor(key) ~= nil and (potions > 0 or not isMobile)
		elseif slot.Kind == "Stasis" then
			local has = false
			for _, id in items do
				local item = Config.ItemsById[id]
				if item and item.Unique == "Stasis" then
					has = true
				end
			end
			slot.Icon.Text = "⌛"
			slot.Icon.TextTransparency = if has then 0 else 0.7
			setCooldown(slot, player:GetAttribute("CD_Stasis") or 0, player:GetAttribute("CDMax_Stasis") or Config.StasisCooldown)
			slot.Holder.Visible = spotFor(key) ~= nil and (has or not isMobile)
		elseif slot.Kind == "Ward" then
			local charges = player:GetAttribute("Wards") or 0
			slot.Icon.Text = "👁"
			slot.Stack.Text = tostring(charges)
			if charges <= 0 then
				setCooldown(slot, player:GetAttribute("WardReadyAt") or 0, Config.Ward.Recharge)
			else
				setCooldown(slot, 0, 1)
			end
		elseif slot.Kind == "Recall" then
			slot.Icon.Text = "🏠"
		end
	end
end

---------------------------------------------------------------- Takt

local function step(_dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local myRoot = rootOf(character)
	updateAim()
	if not humanoid or not myRoot then
		return
	end
	if not playing() then
		humanoid:Move(Vector3.zero)
		waypoints = nil
		return
	end
	-- Joystick hat Vorrang
	if joyVector.Magnitude > 0.15 then
		local dir = CameraController.ScreenRight() * joyVector.X - CameraController.ScreenUp() * joyVector.Y
		humanoid:Move(dir.Unit * math.min(1, joyVector.Magnitude))
		waypoints = nil
			if CameraController.Focus() then
			CameraController.SetFocus(nil, true)
		end
		sendMove()
		return
	end
	local origin = flat(myRoot.Position)
	-- Ziel verfolgen, bis es in Reichweite ist (dann greift der Server an)
	local focus = CameraController.Focus()
	local focusRoot = rootOf(focus)
	if focus and focusRoot then
		local reach = (player:GetAttribute("Range") or 6) + (tonumber(character:GetAttribute("Radius")) or 1.5) + (tonumber(focus:GetAttribute("Radius")) or 1.5)
		local target = flat(focusRoot.Position)
		if (target - origin).Magnitude <= reach then
			humanoid:Move(Vector3.zero)
			waypoints = nil
			return
		end
		if not Vision.Seen(focus) then
			-- Ziel im Nebel verloren: stehen bleiben
			CameraController.SetFocus(nil)
			stopMoving()
			return
		end
		if directClear(origin, target) then
			pathToken += 1
			waypoints = nil
			humanoid:Move((target - origin).Unit)
		elseif os.clock() - lastPathAt > 0.5 or not lastPathGoal or (lastPathGoal - target).Magnitude > 4 then
			computePath(origin, target)
		end
		if not waypoints then
			return
		end
	end
	-- Wegpunkte ablaufen
	local list = waypoints
	if list then
		local point = list[waypointIndex]
		while point and (point - origin).Magnitude < (if waypointIndex == #list then 0.8 else 2.5) do
			waypointIndex += 1
			point = list[waypointIndex]
		end
		if point then
			humanoid:Move((point - origin).Unit)
			if not focus then
				sendMove()
			end
		else
			waypoints = nil
					humanoid:Move(Vector3.zero)
		end
	elseif not focus then
		humanoid:Move(Vector3.zero)
	end
end

local function disableDefaultControls()
	task.spawn(function()
		local scripts = player:WaitForChild("PlayerScripts")
		local module = scripts:WaitForChild("PlayerModule", 10)
		if module then
			pcall(function()
				local playerModule = require(module) :: any
				playerModule:GetControls():Disable()
			end)
		end
	end)
end

function Controls.Start()
	gui.Parent = player:WaitForChild("PlayerGui")
	fxFolder.Parent = workspace
	rescale()
	layout()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	UserInputService.LastInputTypeChanged:Connect(layout)
	disableDefaultControls()
	player.CharacterAdded:Connect(function()
		stopMoving()
		disableDefaultControls()
	end)

	local rightHeld = false
	local attackMovePending = false

	UserInputService.InputBegan:Connect(function(input, processed)
		local t = input.UserInputType
		-- Joystick: Finger auf der linken unteren Bildschirmhaelfte
		if t == Enum.UserInputType.Touch and not processed and not joyTouch and playing() then
			local viewport = workspace.CurrentCamera.ViewportSize
			if input.Position.X < viewport.X * 0.42 and input.Position.Y > viewport.Y * 0.3 then
				joyTouch = input
				joyCenter = Vector2.new(input.Position.X, input.Position.Y)
				local scale = uiScale.Scale
				joyBase.Position = UDim2.fromOffset(joyCenter.X / scale, joyCenter.Y / scale)
				joyKnob.Position = UDim2.fromScale(0.5, 0.5)
				joyBase.Visible = true
				return
			end
		end
		if processed then
			return
		end
		if t == Enum.UserInputType.MouseButton2 then
			if aiming then
				finishAim(true)
				return
			end
			rightHeld = true
			attackMovePending = false
			commandAt(UserInputService:GetMouseLocation())
			return
		elseif t == Enum.UserInputType.MouseButton1 then
			if aiming then
				finishAim(false)
				return
			end
			if attackMovePending then
				attackMovePending = false
				commandAt(UserInputService:GetMouseLocation(), true)
				return
			end
			-- Linksklick auf Gegner = anvisieren
			local unit = CameraController.UnitAt(UserInputService:GetMouseLocation(), true, Vision.Seen)
			if unit and playing() then
				CameraController.SetFocus(unit)
			end
			return
		end
		if t ~= Enum.UserInputType.Keyboard then
			return
		end
		local key = input.KeyCode
		local name = key.Name
		local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if name == "Q" or name == "W" or name == "E" or name == "R" then
			if ctrl then
				remotes.LevelUp:FireServer(name)
			elseif playing() then
				if aiming then
					finishAim(true)
				end
				beginAim("Ability", name, nil, nil)
			end
		elseif name == "D" or name == "F" then
			-- Beschwoererzauber und Wards wirken sofort Richtung Maus
			castKey("Spell", name, CameraController.MouseGround())
		elseif key == Enum.KeyCode.Four then
			castKey("Ward", "Ward", CameraController.MouseGround())
		elseif key == Enum.KeyCode.One then
			remotes.UseItem:FireServer("Potion")
		elseif key == Enum.KeyCode.Two then
			remotes.UseItem:FireServer("Stasis")
		elseif key == Enum.KeyCode.B then
			remotes.Recall:FireServer()
		elseif key == Enum.KeyCode.S then
			CameraController.SetFocus(nil)
			stopMoving()
			sendMove(true)
		elseif key == Enum.KeyCode.A then
			attackMovePending = playing()
		elseif key == Enum.KeyCode.Space then
			remotes.Attack:FireServer(true)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if joyTouch and input == joyTouch then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - joyCenter
			if delta.Magnitude > JOY_RADIUS then
				delta = delta.Unit * JOY_RADIUS
			end
			joyVector = delta / JOY_RADIUS
			local scale = uiScale.Scale
			joyKnob.Position = UDim2.new(0.5, delta.X / scale, 0.5, delta.Y / scale)
			return
		end
		local current = aiming
		if current and current.Touch and input == current.Touch then
			current.Current = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if joyTouch and input == joyTouch then
			joyTouch = nil
			joyVector = Vector2.zero
			joyBase.Visible = false
			stopMoving()
			return
		end
		local current = aiming
		if current and current.Touch and input == current.Touch then
			current.Current = Vector2.new(input.Position.X, input.Position.Y)
			finishAim(false)
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightHeld = false
		elseif input.UserInputType == Enum.UserInputType.Keyboard and current and not current.Touch then
			local name = input.KeyCode.Name
			if current.Kind == "Ability" and name == current.Key then
				finishAim(false)
			end
		end
	end)

	-- Tippen in die Welt (Handy): Gegner anvisieren oder hinlaufen
	UserInputService.TouchTapInWorld:Connect(function(position, processed)
		if processed or aiming then
			return
		end
		commandAt(toViewport(position))
	end)

	-- Rechte Maustaste halten = Ziel laufend nachfuehren
	local holdAccumulator = 0
	RunService:BindToRenderStep("MobaControls", Enum.RenderPriority.Input.Value + 1, function(dt)
		if rightHeld then
			holdAccumulator += dt
			if holdAccumulator > 0.15 then
				holdAccumulator = 0
				local ground = CameraController.MouseGround()
				if ground and playing() and not CameraController.UnitAt(UserInputService:GetMouseLocation(), true, Vision.Seen) then
					CameraController.SetFocus(nil, true)
					moveTo(ground)
					sendMove()
				end
			end
		end
		step(dt)
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= 0.1 then
			accumulator = 0
			refresh()
		end
	end)
	refresh()
end

Controls.Mobile = mobile

-- Minimap: dorthin laufen
function Controls.MoveTo(position: Vector3)
	if not playing() then
		return
	end
	CameraController.SetFocus(nil, true)
	moveTo(position)
	sendMove(true)
	showClick(position, Color3.fromRGB(110, 231, 160))
end

return Controls
