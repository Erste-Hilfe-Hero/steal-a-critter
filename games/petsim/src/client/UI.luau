-- Baut das komplette HUD per Code: Muenzanzeige, Haustier-Inventar, Shop, Rebirth, Schluepf-Animation, Meldungen.
-- Das Layout ist fuer BASE_SIZE entworfen und wird per UIScale an jeden Bildschirm angepasst (Handy bis PC).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PetFactory = require(ReplicatedStorage.Shared.PetFactory)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local TITLE_FONT = Enum.Font.FredokaOne
local BODY_FONT = Enum.Font.BuilderSansBold
local BASE_SIZE = Vector2.new(1000, 560)

-- Farben passend zum Ladebildschirm und zum Icon
local THEME = {
	Panel = Color3.fromRGB(28, 30, 48),
	PanelDark = Color3.fromRGB(18, 20, 34),
	Row = Color3.fromRGB(40, 44, 66),
	Outline = Color3.fromRGB(14, 10, 26),
	Text = Color3.new(1, 1, 1),
	Muted = Color3.fromRGB(172, 178, 205),
	Coin = Color3.fromRGB(255, 205, 60),
	Gold = Color3.fromRGB(255, 205, 60),
	Pink = Color3.fromRGB(240, 100, 160),
	Green = Color3.fromRGB(52, 190, 110),
	Purple = Color3.fromRGB(130, 96, 240),
	Blue = Color3.fromRGB(60, 140, 240),
	Orange = Color3.fromRGB(245, 145, 50),
	Red = Color3.fromRGB(220, 70, 80),
	Gray = Color3.fromRGB(78, 82, 104),
}

-- Symbol pro Shop-Eintrag
local ICONS = {
	VIP = "👑",
	DoubleCoins = "💰",
	TripleHatch = "🥚",
	AutoHatch = "🔁",
	MorePets = "🐾",
	Lucky = "🍀",
	Speed = "👟",
	CoinsSmall = "🪙",
	CoinsMedium = "💰",
	CoinsLarge = "🏦",
	CoinBoost = "⚡",
	ServerLuck = "🌈",
	PetStorage = "🎒",
}

local POP = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.08)
local FADE = TweenInfo.new(0.35)

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

local function outline(thickness: number, color: Color3?)
	return create("UIStroke", { Thickness = thickness, Color = color or THEME.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- Feiner heller Rand fuer Flaechen
local function edge()
	return create("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1), Transparency = 0.85, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- Leichter 3D-Effekt auf Buttons
local function shine()
	return create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)), Rotation = 90 })
end

local function listLayout(direction: Enum.FillDirection, gap: number, horizontal: Enum.HorizontalAlignment?, vertical: Enum.VerticalAlignment?)
	return create("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, gap),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

local function padding(x: number, y: number)
	return create("UIPadding", { PaddingLeft = UDim.new(0, x), PaddingRight = UDim.new(0, x), PaddingTop = UDim.new(0, y), PaddingBottom = UDim.new(0, y) })
end

-- Text mit fester Groesse (UIScale skaliert alles gemeinsam); strokeThickness > 0 fuer Text direkt ueber der Welt
local function text(props, strokeThickness: number?): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or BODY_FONT
	props.TextSize = props.TextSize or 18
	props.TextColor3 = props.TextColor3 or THEME.Text
	local label = create("TextLabel", props) :: TextLabel
	if strokeThickness and strokeThickness > 0 then
		create("UIStroke", { Thickness = strokeThickness, Color = THEME.Outline, Parent = label })
	end
	return label
end

-- Kurzes Eindruecken beim Antippen
local function pressable(guiButton: GuiButton)
	local scale = create("UIScale", { Parent = guiButton }) :: UIScale
	guiButton.MouseButton1Down:Connect(function()
		TweenService:Create(scale, QUICK, { Scale = 0.92 }):Play()
	end)
	local function release()
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end
	guiButton.MouseButton1Up:Connect(release)
	guiButton.MouseLeave:Connect(release)
end

local function button(props, color: Color3): TextButton
	props.BackgroundColor3 = color
	props.Font = props.Font or TITLE_FONT
	props.TextSize = props.TextSize or 20
	props.TextColor3 = THEME.Text
	props.AutoButtonColor = true
	local b = create("TextButton", props, { corner(12), outline(2), shine() }) :: TextButton
	pressable(b)
	return b
end

local clickSound: Sound
local hatchSound: Sound
local function play(sound: Sound?)
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

---------------------------------------------------------------- Kleines Haustier-Gesicht aus UI-Elementen (fuer Karten)

local function petAvatar(parent: Instance, typeId: string, golden: boolean, size: number): Frame
	local def = Config.PetsById[typeId]
	local color = if golden then THEME.Gold else def.Color
	local holder = create("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, Parent = parent }) :: Frame
	if def.Ears then
		for _, x in { 0.2, 0.8 } do
			create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.14), Size = UDim2.fromScale(0.32, 0.32), BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.2), Parent = holder }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline(2) })
		end
	end
	if def.Horn then
		create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.12, 0.26), BackgroundColor3 = Color3.fromRGB(255, 225, 110), Parent = holder }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline(2) })
	end
	local body = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromScale(0.86, 0.8),
		BackgroundColor3 = color,
		Parent = holder,
	}, { create("UICorner", { CornerRadius = UDim.new(if def.Shape == "Ball" then 0.5 else 0.28, 0) }), outline(2) })
	for _, x in { 0.32, 0.68 } do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.42), Size = UDim2.fromScale(0.18, 0.24), BackgroundColor3 = THEME.Outline, Parent = body }, {
			create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			create("Frame", { Position = UDim2.fromScale(0.2, 0.15), Size = UDim2.fromScale(0.45, 0.35), BackgroundColor3 = Color3.new(1, 1, 1) }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }),
		})
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x + (x - 0.5) * 0.6, 0.62), Size = UDim2.fromScale(0.14, 0.08), BackgroundColor3 = Color3.fromRGB(255, 130, 160), Parent = body }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.14, 0.05), BackgroundColor3 = THEME.Outline, Parent = body }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	return holder
end

---------------------------------------------------------------- Meldungen

local root: Frame
local toastContainer: Frame
local announcePill: Frame
local announceLabel: TextLabel

local function showToast(message: string, color: Color3?)
	-- Hoechstens 4 Meldungen gleichzeitig
	local toasts = {}
	for _, child in toastContainer:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts >= 4 then
		toasts[1]:Destroy()
	end
	local pill = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.15,
		Parent = toastContainer,
	}, { corner(17), edge(), padding(16, 0) }) :: Frame
	local label = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = message, TextColor3 = color or THEME.Text, TextSize = 18, Parent = pill })
	task.delay(3.5, function()
		TweenService:Create(pill, FADE, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(label, FADE, { TextTransparency = 1 }):Play()
		task.wait(0.4)
		pill:Destroy()
	end)
end

local announceToken = 0
local function showAnnouncement(message: string, color: Color3?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = message
	announceLabel.TextColor3 = color or THEME.Gold
	announcePill.Visible = true
	local scale = announcePill:FindFirstChildOfClass("UIScale") :: UIScale
	scale.Scale = 0.7
	TweenService:Create(scale, POP, { Scale = 1 }):Play()
	task.delay(5, function()
		if token == announceToken then
			announcePill.Visible = false
		end
	end)
end

-- "+123" ueber zerstoerten Sachen
local function coinPop(amount: number, position: Vector3)
	local anchor = create("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, Position = position, Parent = workspace })
	local gui = create("BillboardGui", { Size = UDim2.fromOffset(160, 44), AlwaysOnTop = true, MaxDistance = 120, Parent = anchor })
	local label = text({ Size = UDim2.fromScale(1, 1), Text = "+" .. Format.Number(amount), TextColor3 = THEME.Coin, Font = TITLE_FONT, TextScaled = true, Parent = gui }, 2)
	TweenService:Create(gui, TweenInfo.new(1), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
end

---------------------------------------------------------------- Fenster

local windows: { Frame } = {}

local function window(title: string, size: Vector2): (Frame, Frame)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = THEME.Panel,
		Visible = false,
		Parent = root,
	}, { corner(18), edge(), create("UIScale", { Name = "PopScale" }) }) :: Frame
	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = THEME.PanelDark, Parent = frame }, { corner(18) })
	create("Frame", { Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 18), BackgroundColor3 = THEME.PanelDark, BorderSizePixel = 0, Parent = header })
	text({ Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -80, 1, 0), Text = title, Font = TITLE_FONT, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	local close = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(38, 38), Text = "X", TextSize = 20, Parent = header }, THEME.Red)
	close.Activated:Connect(function()
		play(clickSound)
		frame.Visible = false
	end)
	local body = create("Frame", { Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 1, -54), BackgroundTransparency = 1, Parent = frame }, { padding(14, 12) }) :: Frame
	table.insert(windows, frame)
	return frame, body
end

local function toggle(target: Frame)
	play(clickSound)
	local show = not target.Visible
	for _, other in windows do
		other.Visible = false
	end
	target.Visible = show
	if show then
		local scale = target:FindFirstChild("PopScale") :: UIScale
		scale.Scale = 0.85
		TweenService:Create(scale, POP, { Scale = 1 }):Play()
	end
end

---------------------------------------------------------------- Schluepf-Animation

local hatchFrame: Frame
local hatchToken = 0

local function viewport(parent: Instance, model: Model, distance: number): ViewportFrame
	local frame = create("ViewportFrame", {
		Size = UDim2.fromOffset(170, 170),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		ZIndex = 2,
		Parent = parent,
	}) :: ViewportFrame
	local camera = create("Camera", { FieldOfView = 40, Parent = frame }) :: Camera
	camera.CFrame = CFrame.lookAt(Vector3.new(0, distance * 0.25, -distance), Vector3.zero)
	frame.CurrentCamera = camera
	model.Parent = frame
	return frame
end

local function showHatch(eggId: string, results: { string })
	local egg = Config.EggsById[eggId]
	hatchToken += 1
	local token = hatchToken
	for _, child in hatchFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	hatchFrame.Visible = true

	local slots = {}
	for index, typeId in results do
		local slot = create("Frame", { Size = UDim2.fromOffset(170, 240), BackgroundTransparency = 1, LayoutOrder = index, Parent = hatchFrame }) :: Frame
		-- Leuchtender Kreis hinter dem Ei (spaeter in der Farbe der Seltenheit)
		local halo = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(85, 85), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, Parent = slot }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }) :: Frame
		local eggModel = create("Model", {}) :: Model
		local eggPart = create("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = egg.Color, Anchored = true, Parent = eggModel }, {
			create("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 1.3, 1) }),
		}) :: Part
		eggModel.PrimaryPart = eggPart
		local view = viewport(slot, eggModel, 11)
		table.insert(slots, { Slot = slot, View = view, Egg = eggModel, Halo = halo, TypeId = typeId })
	end

	-- Ei wackeln lassen, dann das Haustier zeigen
	local start = os.clock()
	while os.clock() - start < 1.2 and token == hatchToken do
		local t = os.clock() - start
		for _, slot in slots do
			slot.Egg:PivotTo(CFrame.Angles(0, 0, math.sin(t * 25) * 0.25 * t))
		end
		task.wait()
	end
	if token ~= hatchToken then
		return
	end
	play(hatchSound)
	for _, slot in slots do
		slot.Egg:Destroy()
		local def = Config.PetsById[slot.TypeId]
		local rarity = Config.RaritiesByName[def.Rarity]
		slot.Halo.BackgroundColor3 = rarity.Color
		slot.Halo.BackgroundTransparency = 0.45
		local haloScale = create("UIScale", { Scale = 0.3, Parent = slot.Halo }) :: UIScale
		TweenService:Create(haloScale, POP, { Scale = 1 }):Play()
		local pet = PetFactory.Build(slot.TypeId)
		pet:PivotTo(CFrame.Angles(0, math.pi, 0))
		pet.Parent = slot.View
		local camera = slot.View.CurrentCamera :: Camera
		camera.CFrame = CFrame.lookAt(Vector3.new(0, rarity.Scale * 0.6, rarity.Scale * 3.2), Vector3.zero)
		text({ Position = UDim2.fromOffset(0, 172), Size = UDim2.new(1, 0, 0, 30), Text = def.Name, Font = TITLE_FONT, TextSize = 24, Parent = slot.Slot }, 2)
		text({ Position = UDim2.fromOffset(0, 202), Size = UDim2.new(1, 0, 0, 24), Text = def.Rarity:upper(), Font = TITLE_FONT, TextSize = 20, TextColor3 = rarity.Color, Parent = slot.Slot }, 2)
	end
	task.delay(2.2, function()
		if token == hatchToken then
			hatchFrame.Visible = false
		end
	end)
end

---------------------------------------------------------------- Haustier-Inventar

local inventory = {} -- [uid] = { T, G }
local equipped = {} -- { uid }
local selected: string? = nil
local refreshPets: () -> () = function() end

local function sortedPets()
	local list = {}
	for uid, pet in inventory do
		table.insert(list, { Uid = uid, Pet = pet, Power = Config.PetPower(pet.T, pet.G), Equipped = table.find(equipped, uid) ~= nil })
	end
	table.sort(list, function(a, b)
		if a.Equipped ~= b.Equipped then
			return a.Equipped
		end
		if a.Power ~= b.Power then
			return a.Power > b.Power
		end
		return tonumber(a.Uid) < tonumber(b.Uid)
	end)
	return list
end

local function countOf(typeId: string): number
	local count = 0
	for _, pet in inventory do
		if pet.T == typeId and not pet.G then
			count += 1
		end
	end
	return count
end

local function buildPetsWindow(): Frame
	local frame, body = window("Pets", Vector2.new(660, 470))
	local title = frame:FindFirstChildWhichIsA("Frame"):FindFirstChildOfClass("TextLabel") :: TextLabel

	local toolbar = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = body }, { listLayout(Enum.FillDirection.Horizontal, 10) })
	local equipBest = button({ Size = UDim2.fromOffset(170, 40), Text = "Equip Best", TextSize = 18, LayoutOrder = 1, Parent = toolbar }, THEME.Green)
	local deleteWeak = button({ Size = UDim2.fromOffset(260, 40), Text = "Delete Unequipped Commons", TextSize = 16, LayoutOrder = 2, Parent = toolbar }, THEME.Red)

	local grid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -146),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = THEME.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = body,
	}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(96, 112), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }), padding(4, 4) })

	local detail = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 86), BackgroundColor3 = THEME.Row, Parent = body }, { corner(12), edge() })
	local detailText = text({ Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 28), Text = "", TextSize = 20, Font = TITLE_FONT, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
	local actions = create("Frame", { Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 38), BackgroundTransparency = 1, Parent = detail }, { listLayout(Enum.FillDirection.Horizontal, 10) })
	local equipButton = button({ Size = UDim2.fromOffset(170, 38), Text = "Equip", TextSize = 18, LayoutOrder = 1, Parent = actions }, THEME.Blue)
	local goldenButton = button({ Size = UDim2.fromOffset(190, 38), Text = "Golden", TextSize = 18, LayoutOrder = 2, Parent = actions }, THEME.Orange)
	local deleteButton = button({ Size = UDim2.fromOffset(150, 38), Text = "Delete", TextSize = 18, LayoutOrder = 3, Parent = actions }, THEME.Red)
	local deleteArmed = false

	local function refreshDetail()
		local pet = selected and inventory[selected]
		actions.Visible = pet ~= nil
		deleteArmed = false
		deleteButton.Text = "Delete"
		if not pet then
			selected = nil
			detailText.Text = "Tap a pet to equip, craft or delete it"
			detailText.TextColor3 = THEME.Muted
			return
		end
		local def = Config.PetsById[pet.T]
		detailText.Text = `{if pet.G then "Golden " else ""}{def.Name}  ·  {def.Rarity}  ·  Power {Format.Number(Config.PetPower(pet.T, pet.G))}`
		detailText.TextColor3 = if pet.G then THEME.Gold else Config.RaritiesByName[def.Rarity].Color
		equipButton.Text = if table.find(equipped, selected) then "Unequip" else "Equip"
		local count = countOf(pet.T)
		goldenButton.Visible = not pet.G
		goldenButton.Text = `Make Golden {math.min(count, Config.GoldenCraftAmount)}/{Config.GoldenCraftAmount}`
		goldenButton.BackgroundColor3 = if count >= Config.GoldenCraftAmount then THEME.Orange else THEME.Gray
	end

	refreshPets = function()
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local total = 0
		for order, item in sortedPets() do
			total += 1
			local def = Config.PetsById[item.Pet.T]
			local rarity = Config.RaritiesByName[def.Rarity]
			local isSelected = item.Uid == selected
			local card = create("TextButton", {
				Text = "",
				LayoutOrder = order,
				BackgroundColor3 = if item.Pet.G then Color3.fromRGB(110, 86, 24) else rarity.Color:Lerp(THEME.PanelDark, 0.62),
				AutoButtonColor = true,
				Parent = grid,
			}, { corner(12), create("UIStroke", { Thickness = if isSelected then 3 else 1.5, Color = if isSelected then Color3.new(1, 1, 1) else rarity.Color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) }) :: TextButton
			local avatar = petAvatar(card, item.Pet.T, item.Pet.G, 50)
			avatar.AnchorPoint = Vector2.new(0.5, 0)
			avatar.Position = UDim2.new(0.5, 0, 0, 8)
			text({ Position = UDim2.fromOffset(4, 62), Size = UDim2.new(1, -8, 0, 20), Text = def.Name, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
			text({ Position = UDim2.fromOffset(4, 84), Size = UDim2.new(1, -8, 0, 20), Text = "⚔ " .. Format.Number(item.Power), TextSize = 15, TextColor3 = Color3.fromRGB(255, 150, 150), Parent = card })
			if item.Equipped then
				create("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = THEME.Green, Parent = card }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline(1.5) })
				text({ Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(20, 20), Text = "✓", TextSize = 14, Parent = card })
			end
			card.Activated:Connect(function()
				play(clickSound)
				selected = item.Uid
				refreshPets()
			end)
		end
		title.Text = `Pets  {total}/{player:GetAttribute("Storage") or Config.MaxStorage}    Equipped {#equipped}/{player:GetAttribute("MaxEquip") or Config.BaseEquip}`
		refreshDetail()
	end

	equipBest.Activated:Connect(function()
		play(clickSound)
		remotes.EquipBest:FireServer()
	end)
	deleteWeak.Activated:Connect(function()
		play(clickSound)
		local uids = {}
		for uid, pet in inventory do
			local rarity = Config.RaritiesByName[Config.PetsById[pet.T].Rarity]
			if rarity.Index <= 2 and not pet.G and not table.find(equipped, uid) then
				table.insert(uids, uid)
			end
		end
		if #uids > 0 then
			remotes.DeletePets:FireServer(uids)
		end
	end)
	equipButton.Activated:Connect(function()
		play(clickSound)
		if selected then
			remotes.ToggleEquip:FireServer(selected)
		end
	end)
	goldenButton.Activated:Connect(function()
		play(clickSound)
		local pet = selected and inventory[selected]
		if pet then
			remotes.CraftGolden:FireServer(pet.T)
		end
	end)
	deleteButton.Activated:Connect(function()
		play(clickSound)
		if not selected then
			return
		end
		if not deleteArmed then
			deleteArmed = true
			deleteButton.Text = "Sure?"
			return
		end
		remotes.DeletePets:FireServer({ selected })
		selected = nil
	end)

	player:GetAttributeChangedSignal("MaxEquip"):Connect(refreshPets)
	refreshDetail()
	return frame
end

---------------------------------------------------------------- Shop

local function sortedEntries(source)
	local list = {}
	for key, entry in source do
		table.insert(list, { Key = key, Entry = entry })
	end
	table.sort(list, function(a, b)
		return (a.Entry.Order or 99) < (b.Entry.Order or 99)
	end)
	return list
end

local function buildShopRow(parent: Instance, kind: string, key: string, entry, color: Color3, order: number)
	local row = create("Frame", { Size = UDim2.new(1, -8, 0, 72), BackgroundColor3 = THEME.Row, LayoutOrder = order, Parent = parent }, { corner(12), edge() }) :: Frame
	local iconBack = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = THEME.PanelDark, Parent = row }, { corner(12) })
	text({ Size = UDim2.fromScale(1, 1), Text = ICONS[key] or "🎁", TextSize = 30, Parent = iconBack })
	text({ Position = UDim2.fromOffset(74, 10), Size = UDim2.new(1, -220, 0, 26), Text = entry.Name, Font = TITLE_FONT, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	text({ Position = UDim2.fromOffset(74, 38), Size = UDim2.new(1, -220, 0, 22), Text = entry.Description, Font = Enum.Font.BuilderSansMedium, TextSize = 15, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	local buy = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(120, 44), Text = "R$ " .. entry.PriceHint, TextSize = 20, Parent = row }, color)

	-- Pass ohne Gamepass-ID wird als dauerhaftes Developer Product verkauft
	local productId = if kind == "Pass" then (if entry.Id == 0 and entry.ProductId ~= 0 then entry.ProductId else nil) else (if entry.Id ~= 0 then entry.Id else nil)
	local passId = if kind == "Pass" and entry.Id ~= 0 then entry.Id else nil
	if productId or passId then
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, passId or productId, if passId then Enum.InfoType.GamePass else Enum.InfoType.Product)
			if ok and info and info.PriceInRobux then
				buy.Text = "R$ " .. info.PriceInRobux
			end
		end)
	end

	if kind == "Pass" then
		local function refreshOwned()
			if player:GetAttribute("Pass_" .. key) then
				buy.Text = "Owned"
				buy.BackgroundColor3 = THEME.Gray
				buy.Active = false
			end
		end
		refreshOwned()
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(refreshOwned)
	end

	-- In Laendern mit Lootbox-Verbot keine Produkte, die Zufall beeinflussen
	local function refreshAllowed()
		row.Visible = not (entry.AffectsRandom and player:GetAttribute("RandomRestricted"))
	end
	refreshAllowed()
	player:GetAttributeChangedSignal("RandomRestricted"):Connect(refreshAllowed)

	buy.Activated:Connect(function()
		play(clickSound)
		if kind == "Pass" and player:GetAttribute("Pass_" .. key) then
			return
		end
		if passId then
			MarketplaceService:PromptGamePassPurchase(player, passId)
		elseif productId then
			MarketplaceService:PromptProductPurchase(player, productId)
		else
			-- Nur in Studio wirksam (Server prueft das)
			remotes.FakePurchase:FireServer(kind, key)
		end
	end)
end

local function buildShopWindow(): Frame
	local frame, body = window("Shop", Vector2.new(620, 470))
	local tabs = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = body }, { listLayout(Enum.FillDirection.Horizontal, 10) })
	local pages = {}
	local tabButtons = {}
	local function page(name: string, order: number, color: Color3): ScrollingFrame
		local list = create("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 50),
			Size = UDim2.new(1, 0, 1, -50),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = THEME.Muted,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			Visible = order == 1,
			Parent = body,
		}, { listLayout(Enum.FillDirection.Vertical, 8), padding(2, 2) }) :: ScrollingFrame
		local tab = button({ Size = UDim2.fromOffset(150, 40), Text = name, TextSize = 18, LayoutOrder = order, Parent = tabs }, if order == 1 then color else THEME.Gray)
		pages[order] = list
		tabButtons[order] = { Button = tab, Color = color }
		tab.Activated:Connect(function()
			play(clickSound)
			for index, other in pages do
				other.Visible = index == order
				tabButtons[index].Button.BackgroundColor3 = if index == order then tabButtons[index].Color else THEME.Gray
			end
		end)
		return list
	end
	local passes = page("Passes", 1, THEME.Orange)
	local boosts = page("Boosts", 2, THEME.Blue)
	for _, item in sortedEntries(Config.GamePasses) do
		buildShopRow(passes, "Pass", item.Key, item.Entry, THEME.Green, item.Entry.Order)
	end
	for _, item in sortedEntries(Config.DevProducts) do
		buildShopRow(boosts, "Product", item.Key, item.Entry, THEME.Green, item.Entry.Order)
	end
	for _, list in { passes, boosts } do
		text({ Size = UDim2.new(1, -8, 0, 34), Text = "Eggs are only bought with coins. Chances are shown at every egg.", Font = Enum.Font.BuilderSansMedium, TextSize = 14, TextColor3 = THEME.Muted, TextWrapped = true, LayoutOrder = 99, Parent = list })
	end
	return frame
end

---------------------------------------------------------------- Start

function UI.Start()
	local gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	clickSound = create("Sound", { SoundId = "rbxasset://sounds/clickfast.wav", Volume = 0.4, Parent = gui }) :: Sound
	hatchSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Parent = gui }) :: Sound

	-- Alles haengt an root; Mitte als Anker, damit UIScale den Bildschirm genau ausfuellt
	local uiScale = create("UIScale", {}) :: UIScale
	root = create("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { uiScale }) :: Frame
	local function updateScale()
		local size = gui.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local scale = math.clamp(math.min(size.X / BASE_SIZE.X, size.Y / BASE_SIZE.Y), 0.6, 1.25)
		uiScale.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
	updateScale()

	------------------------------------------------ Oben: Muenzen, Infos, Status

	local top = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(640, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center) })

	local coinPill = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 50),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.1,
		LayoutOrder = 1,
		Parent = top,
	}, { corner(25), edge(), padding(8, 0), listLayout(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) }) :: Frame
	local coinScale = create("UIScale", { Parent = coinPill }) :: UIScale
	create("Frame", { Size = UDim2.fromOffset(34, 34), BackgroundColor3 = THEME.Coin, LayoutOrder = 1, Parent = coinPill }, {
		create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		outline(2),
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), BackgroundTransparency = 1 }, {
			create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			create("UIStroke", { Thickness = 2, Color = Color3.fromRGB(255, 240, 160) }),
		}),
	})
	local coinsLabel = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 50), Text = "0", Font = TITLE_FONT, TextSize = 34, TextColor3 = THEME.Coin, LayoutOrder = 2, Parent = coinPill })
	local multiBadge = create("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundColor3 = THEME.Purple, LayoutOrder = 3, Parent = coinPill }, { corner(14), padding(10, 0) })
	local multiLabel = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "x1", Font = TITLE_FONT, TextSize = 18, Parent = multiBadge })

	local chips = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 2, Parent = top }, { listLayout(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	local function chip(order: number, color: Color3): TextLabel
		local holder = create("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundColor3 = THEME.PanelDark, BackgroundTransparency = 0.2, LayoutOrder = order, Parent = chips }, { corner(14), edge(), padding(12, 0) })
		return text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "", TextSize = 16, TextColor3 = color, Parent = holder })
	end
	local powerChip = chip(1, Color3.fromRGB(255, 150, 150))
	local petsChip = chip(2, THEME.Text)
	local rankChip = chip(3, THEME.Muted)
	local boostChip = chip(4, THEME.Coin)
	local luckChip = chip(5, Color3.fromRGB(120, 255, 160))

	announcePill = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.1,
		Visible = false,
		LayoutOrder = 3,
		Parent = top,
	}, { corner(20), outline(1.5, THEME.Gold), padding(18, 0), create("UIScale", {}) }) :: Frame
	announceLabel = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "", Font = TITLE_FONT, TextSize = 20, Parent = announcePill })

	toastContainer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(600, 160),
		BackgroundTransparency = 1,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) }) :: Frame

	hatchFrame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(560, 250),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) }) :: Frame

	------------------------------------------------ Links: Symbol-Menue

	local menu = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(84, 290),
		BackgroundTransparency = 1,
		Parent = root,
	}, { listLayout(Enum.FillDirection.Vertical, 12) })
	local function menuButton(icon: string, name: string, color: Color3, order: number): (TextButton, Frame)
		local b = create("TextButton", { Size = UDim2.fromOffset(84, 84), BackgroundColor3 = color, Text = "", AutoButtonColor = true, LayoutOrder = order, Parent = menu }, { corner(20), outline(2), shine() }) :: TextButton
		pressable(b)
		text({ Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 46), Text = icon, TextSize = 38, Parent = b })
		text({ Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 24), Text = name, Font = TITLE_FONT, TextSize = 17, Parent = b }, 1.5)
		local badge = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = THEME.Red, Visible = false, Parent = b }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline(2) }) :: Frame
		return b, badge
	end
	local petsButton, petsBadge = menuButton("🐾", "Pets", THEME.Orange, 1)
	local shopButton = menuButton("🛒", "Shop", THEME.Green, 2)
	local rebirthButton, rebirthBadge = menuButton("♻️", "Rebirth", THEME.Purple, 3)

	-- Unten rechts: Auto Hatch
	local autoButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -110), Size = UDim2.fromOffset(170, 50), Text = "Auto Hatch", TextSize = 19, Parent = root }, THEME.Gray)

	local pets = buildPetsWindow()
	local shop = buildShopWindow()

	-- Rebirth-Fenster mit Fortschrittsbalken
	local rebirth, rebirthBody = window("Rebirth", Vector2.new(420, 300))
	local rebirthInfo = text({ Size = UDim2.new(1, 0, 0, 96), Text = "", TextSize = 18, TextWrapped = true, Parent = rebirthBody })
	local progressBack = create("Frame", { Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = THEME.PanelDark, Parent = rebirthBody }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), edge() })
	local progressFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.Purple, Parent = progressBack }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }) :: Frame
	local confirmRebirth = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(240, 52), Text = "Rebirth", TextSize = 22, Parent = rebirthBody }, THEME.Purple)

	petsButton.Activated:Connect(function()
		toggle(pets)
	end)
	shopButton.Activated:Connect(function()
		toggle(shop)
	end)
	rebirthButton.Activated:Connect(function()
		toggle(rebirth)
	end)
	confirmRebirth.Activated:Connect(function()
		play(clickSound)
		remotes.RequestRebirth:FireServer()
		rebirth.Visible = false
	end)
	autoButton.Activated:Connect(function()
		play(clickSound)
		remotes.SetAutoHatch:FireServer(not player:GetAttribute("AutoHatch"))
	end)

	remotes.Notify.OnClientEvent:Connect(showToast)
	remotes.Announce.OnClientEvent:Connect(showAnnouncement)
	remotes.CoinPop.OnClientEvent:Connect(coinPop)
	remotes.Hatched.OnClientEvent:Connect(function(eggId, results)
		task.spawn(showHatch, eggId, results)
	end)
	remotes.Inventory.OnClientEvent:Connect(function(newPets, newEquipped)
		inventory = newPets
		equipped = newEquipped
		refreshPets()
	end)

	task.delay(5, function()
		if player:GetAttribute("DailyReady") then
			showToast("Your DAILY GIFT is ready at the spawn!", THEME.Pink)
		end
	end)

	-- Muenzanzeige huepft kurz, wenn Muenzen dazukommen
	local lastCoins = player:GetAttribute("Coins") or 0
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		local coins = player:GetAttribute("Coins") or 0
		if coins > lastCoins then
			coinScale.Scale = 1.08
			TweenService:Create(coinScale, POP, { Scale = 1 }):Play()
		end
		lastCoins = coins
	end)

	-- Anzeige laufend aktualisieren
	task.spawn(function()
		while gui.Parent do
			local coins = player:GetAttribute("Coins") or 0
			local rebirths = player:GetAttribute("Rebirths") or 0
			local cost = player:GetAttribute("RebirthCost") or 1
			local zone = player:GetAttribute("Zone") or 1
			coinsLabel.Text = Format.Number(coins)
			multiLabel.Text = `x{player:GetAttribute("Multiplier") or 1}`

			local petCount = 0
			for _ in inventory do
				petCount += 1
			end
			local storage = player:GetAttribute("Storage") or Config.MaxStorage
			powerChip.Text = "⚔ " .. Format.Number(player:GetAttribute("Power") or 0)
			petsChip.Text = `🐾 {petCount}/{storage}`
			petsChip.TextColor3 = if petCount >= storage then THEME.Red else THEME.Text
			petsBadge.Visible = petCount >= storage

			local nextRank = player:GetAttribute("NextRank")
			rankChip.Text = `{player:GetAttribute("Rank") or "Newbie"}` .. (if nextRank then `  ·  next {nextRank}` else "")
			if player:GetAttribute("RankColor") then
				rankChip.TextColor3 = Color3.fromHex(player:GetAttribute("RankColor"))
			end

			local boostLeft = (player:GetAttribute("BoostUntil") or 0) - os.time()
			boostChip.Parent.Visible = boostLeft > 0
			boostChip.Text = `2x Coins  {Format.Time(boostLeft)}`
			local luckLeft = (workspace:GetAttribute("LuckUntil") or 0) - workspace:GetServerTimeNow()
			luckChip.Parent.Visible = luckLeft > 0
			luckChip.Text = `Server Luck x{Config.ServerLuckMultiplier}  {Format.Time(luckLeft)}`

			local on = player:GetAttribute("AutoHatch") == true
			autoButton.Text = if on then "Auto Hatch: ON" elseif player:GetAttribute("Pass_AutoHatch") then "Auto Hatch: OFF" else "Auto Hatch 🔒"
			autoButton.BackgroundColor3 = if on then THEME.Green else THEME.Gray

			local current = 1 + rebirths * Config.RebirthMultiplierPer
			local ready = zone >= #Config.Zones and coins >= cost
			rebirthInfo.Text = `Needs {Config.Zones[#Config.Zones].Name} and {Format.Coins(cost)}.\nCoins x{current}  →  x{current + Config.RebirthMultiplierPer}\nResets coins and worlds. You KEEP all pets.`
			progressFill.Size = UDim2.fromScale(math.clamp(coins / cost, 0, 1) * (if zone >= #Config.Zones then 1 else 0.5), 1)
			confirmRebirth.BackgroundColor3 = if ready then THEME.Purple else THEME.Gray
			rebirthBadge.Visible = ready
			task.wait(0.2)
		end
	end)
end

return UI
