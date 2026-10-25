-- Baut das komplette HUD per Code: Muenzanzeige, Haustier-Inventar, Shop, Rebirth, Schluepf-Animation, Meldungen.
-- Das Layout ist fuer BASE_SIZE entworfen und wird per UIScale an jeden Bildschirm angepasst (Handy bis PC).
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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
	Rainbow = Color3.fromRGB(255, 120, 220),
}

local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 90)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
})

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
local tapSound: Sound
local function play(sound: Sound?)
	if sound and player:GetAttribute("Set_Sound") ~= false then
		SoundService:PlayLocalSound(sound)
	end
end

---------------------------------------------------------------- Kleines Haustier-Gesicht aus UI-Elementen (fuer Karten)

local function petAvatar(parent: Instance, typeId: string, golden: boolean, size: number, rainbow: boolean?): Frame
	local def = Config.PetsById[typeId]
	local color = if rainbow then THEME.Rainbow elseif golden then THEME.Gold else def.Color
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
	if rainbow then
		create("UIGradient", { Color = RAINBOW_SEQUENCE, Rotation = 30, Parent = body })
	end
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
local function coinPop(amount: number, position: Vector3, color: Color3?, prefix: string?)
	if player:GetAttribute("Set_CoinPops") == false then
		return
	end
	local anchor = create("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, Position = position, Parent = workspace })
	local gui = create("BillboardGui", { Size = UDim2.fromOffset(160, 44), AlwaysOnTop = true, MaxDistance = 120, Parent = anchor })
	local label = text({ Size = UDim2.fromScale(1, 1), Text = (prefix or "+") .. Format.Number(amount), TextColor3 = color or THEME.Coin, Font = TITLE_FONT, TextScaled = true, Parent = gui }, 2)
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
		table.insert(list, { Uid = uid, Pet = pet, Power = Config.PetPower(pet.T, pet.G, pet.R), Equipped = table.find(equipped, uid) ~= nil })
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

-- Wie viele Haustiere dieser Art kann man verbrauchen? (golden = goldene zaehlen; gesperrte nie)
local function countOf(typeId: string, golden: boolean): number
	local count = 0
	for _, pet in inventory do
		if pet.T == typeId and (pet.G == true) == golden and not pet.R and not pet.L then
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
	local deleteWeak = button({ Size = UDim2.fromOffset(270, 40), Text = "Delete Commons & Uncommons", TextSize = 15, LayoutOrder = 2, Parent = toolbar }, THEME.Red)
	text({ Size = UDim2.fromOffset(170, 40), Text = "Locked and equipped pets are kept", TextSize = 13, TextColor3 = THEME.Muted, TextWrapped = true, LayoutOrder = 3, Parent = toolbar })

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
	local equipButton = button({ Size = UDim2.fromOffset(140, 38), Text = "Equip", TextSize = 18, LayoutOrder = 1, Parent = actions }, THEME.Blue)
	local goldenButton = button({ Size = UDim2.fromOffset(200, 38), Text = "Golden", TextSize = 17, LayoutOrder = 2, Parent = actions }, THEME.Orange)
	local lockButton = button({ Size = UDim2.fromOffset(100, 38), Text = "Lock", TextSize = 18, LayoutOrder = 3, Parent = actions }, THEME.Purple)
	local deleteButton = button({ Size = UDim2.fromOffset(120, 38), Text = "Delete", TextSize = 18, LayoutOrder = 4, Parent = actions }, THEME.Red)
	local deleteArmed = false
	local weakArmed = 0 -- Zeitpunkt der ersten Beruehrung von "Delete Commons" (zweites Tippen bestaetigt)

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
		local tier = if pet.R then "Rainbow " elseif pet.G then "Golden " else ""
		detailText.Text = `{if pet.L then "🔒 " else ""}{tier}{def.Name}  ·  {def.Rarity}  ·  Power {Format.Number(Config.PetPower(pet.T, pet.G, pet.R))}`
		detailText.TextColor3 = if pet.R then THEME.Rainbow elseif pet.G then THEME.Gold else Config.RaritiesByName[def.Rarity].Color
		equipButton.Text = if table.find(equipped, selected) then "Unequip" else "Equip"
		-- Normal -> Golden (5 gleiche), Golden -> Rainbow (5 gleiche goldene), Rainbow ist die hoechste Stufe
		goldenButton.Visible = not pet.R
		if pet.G then
			local count = countOf(pet.T, true)
			goldenButton.Text = `Make Rainbow {math.min(count, Config.RainbowCraftAmount)}/{Config.RainbowCraftAmount}`
			goldenButton.BackgroundColor3 = if count >= Config.RainbowCraftAmount then THEME.Pink else THEME.Gray
		else
			local count = countOf(pet.T, false)
			goldenButton.Text = `Make Golden {math.min(count, Config.GoldenCraftAmount)}/{Config.GoldenCraftAmount}`
			goldenButton.BackgroundColor3 = if count >= Config.GoldenCraftAmount then THEME.Orange else THEME.Gray
		end
		lockButton.Text = if pet.L then "Unlock" else "Lock"
		deleteButton.Visible = not pet.L
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
				BackgroundColor3 = if item.Pet.R then Color3.fromRGB(150, 150, 150) elseif item.Pet.G then Color3.fromRGB(110, 86, 24) else rarity.Color:Lerp(THEME.PanelDark, 0.62),
				AutoButtonColor = true,
				Parent = grid,
			}, { corner(12), create("UIStroke", { Thickness = if isSelected then 3 else 1.5, Color = if isSelected then Color3.new(1, 1, 1) else rarity.Color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) }) :: TextButton
			if item.Pet.R then
				create("UIGradient", { Color = RAINBOW_SEQUENCE, Rotation = 45, Transparency = NumberSequence.new(0.35), Parent = card })
			end
			local avatar = petAvatar(card, item.Pet.T, item.Pet.G, 50, item.Pet.R)
			avatar.AnchorPoint = Vector2.new(0.5, 0)
			avatar.Position = UDim2.new(0.5, 0, 0, 8)
			text({ Position = UDim2.fromOffset(4, 62), Size = UDim2.new(1, -8, 0, 20), Text = def.Name, TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd, Parent = card })
			text({ Position = UDim2.fromOffset(4, 84), Size = UDim2.new(1, -8, 0, 20), Text = "⚔ " .. Format.Number(item.Power), TextSize = 15, TextColor3 = Color3.fromRGB(255, 150, 150), Parent = card })
			if item.Equipped then
				create("Frame", { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = THEME.Green, Parent = card }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline(1.5) })
				text({ Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(20, 20), Text = "✓", TextSize = 14, Parent = card })
			end
			if item.Pet.L then
				text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), Text = "🔒", TextSize = 16, Parent = card })
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
			if rarity.Index <= 2 and not pet.G and not pet.R and not pet.L and not table.find(equipped, uid) then
				table.insert(uids, uid)
			end
		end
		if #uids == 0 then
			showToast("No unequipped Common or Uncommon pets to delete.", THEME.Muted)
			return
		end
		-- Erst nach einer Bestaetigung loeschen (ein Tippen aus Versehen kostet sonst viele Haustiere)
		if os.clock() - weakArmed > 3 then
			weakArmed = os.clock()
			deleteWeak.Text = `Sure? Delete {#uids} pets`
			task.delay(3, function()
				if os.clock() - weakArmed >= 2.9 then
					deleteWeak.Text = "Delete Commons & Uncommons"
				end
			end)
			return
		end
		weakArmed = 0
		deleteWeak.Text = "Delete Commons & Uncommons"
		remotes.DeletePets:FireServer(uids)
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
		if pet and pet.G then
			remotes.CraftRainbow:FireServer(pet.T)
		elseif pet then
			remotes.CraftGolden:FireServer(pet.T)
		end
	end)
	lockButton.Activated:Connect(function()
		play(clickSound)
		if selected then
			remotes.ToggleLock:FireServer(selected)
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

---------------------------------------------------------------- Fortschritt (Aufgaben, Erfolge, Index, Geschenke)

-- Zustand vom Server (ProgressService:Push)
local progressState: any = { Quests = {}, Achievements = {}, Discovered = {}, Title = "", PlaytimeClaimed = {}, Stats = {} }
local progressListeners: { () -> () } = {}

-- Fenster nur neu aufbauen, wenn sie offen sind (Updates kommen beim Farmen jede Sekunde); beim Oeffnen sofort
local function onProgress(frame: Frame, callback: () -> ())
	table.insert(progressListeners, function()
		if frame.Visible then
			callback()
		end
	end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			callback()
		end
	end)
end

-- "5h 03m" bzw. "12:30" fuer kurze Zeiten
local function longTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	end
	return Format.Time(seconds)
end

local function scrollList(parent: Instance, position: UDim2, size: UDim2): ScrollingFrame
	return create("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = THEME.Muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, { listLayout(Enum.FillDirection.Vertical, 8), padding(2, 2) }) :: ScrollingFrame
end

local function clearList(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function progressBar(parent: Instance, position: UDim2, size: UDim2, ratio: number, color: Color3): Frame
	local back = create("Frame", { Position = position, Size = size, BackgroundColor3 = THEME.PanelDark, Parent = parent }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) }) :: Frame
	create("Frame", { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1), BackgroundColor3 = color, Parent = back }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	return back
end

local function rewardText(reward): string
	if reward.BoostSeconds then
		return `⚡ 2x Coins {reward.BoostSeconds // 60} min`
	end
	return `🪙 coins for {reward.Eggs} egg{if reward.Eggs == 1 then "" else "s"}`
end

local function rowFrame(parent: Instance, height: number, order: number): Frame
	return create("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = THEME.Row, LayoutOrder = order, Parent = parent }, { corner(12), edge() }) :: Frame
end

local function leftText(props): TextLabel
	props.TextXAlignment = Enum.TextXAlignment.Left
	props.TextTruncate = props.TextTruncate or Enum.TextTruncate.AtEnd
	return text(props)
end

---------------------------------------------------------------- Ziel fuer neue Spieler

-- Naechstes sinnvolles Ziel als Text und (wenn vorhanden) das Teil in der Welt, auf das der Pfeil zeigt
local function currentGoal(): (string?, BasePart?)
	local world = workspace:FindFirstChild("World")
	local zones = world and world:FindFirstChild("Zones")
	if not zones then
		return nil, nil
	end
	local coins = player:GetAttribute("Coins") or 0
	local zone = player:GetAttribute("Zone") or 1
	local hatched = player:GetAttribute("Hatched") or 0
	local function zonePart(index: number, name: string): BasePart?
		local folder = zones:FindFirstChild("Zone" .. index)
		return folder and folder:FindFirstChild(name) :: BasePart?
	end
	if player:GetAttribute("DailyReady") then
		return "Claim your free Daily Gift!", world:FindFirstChild("DailyGift") :: BasePart?
	end
	local firstEgg = Config.EggByZone[1]
	if hatched == 0 then
		if coins >= firstEgg.Price then
			return `Hatch your first pet at the {firstEgg.Name}!`, zonePart(1, "Egg")
		end
		return `Break coin piles to get {Format.Coins(firstEgg.Price)}`, nil
	end
	local nextZone = Config.Zones[zone + 1]
	if nextZone then
		if coins >= nextZone.GateCost then
			return `Unlock {nextZone.Name}!`, zonePart(zone + 1, "GateSign")
		end
		return `Next: {nextZone.Name}  {Format.Number(coins)} / {Format.Number(nextZone.GateCost)}`, nil
	end
	if (player:GetAttribute("Rebirths") or 0) == 0 then
		return "Collect coins for your first Rebirth!", nil
	end
	return nil, nil
end

---------------------------------------------------------------- Aufgaben und Erfolge

local function buildQuestsWindow(): (Frame, TextLabel)
	local frame, body = window("Quests", Vector2.new(580, 440))
	local tabs = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = body }, { listLayout(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local questTab = button({ Size = UDim2.fromOffset(150, 40), Text = "Daily Quests", TextSize = 17, LayoutOrder = 1, Parent = tabs }, THEME.Green)
	local achTab = button({ Size = UDim2.fromOffset(160, 40), Text = "Achievements", TextSize = 17, LayoutOrder = 2, Parent = tabs }, THEME.Gray)
	local resetLabel = text({ Size = UDim2.fromOffset(200, 40), Text = "", TextSize = 14, TextColor3 = THEME.Muted, LayoutOrder = 3, Parent = tabs })
	local questList = scrollList(body, UDim2.fromOffset(0, 50), UDim2.new(1, 0, 1, -50))
	local achList = scrollList(body, UDim2.fromOffset(0, 50), UDim2.new(1, 0, 1, -50))
	achList.Visible = false

	local function showTab(questsVisible: boolean)
		questList.Visible = questsVisible
		achList.Visible = not questsVisible
		questTab.BackgroundColor3 = if questsVisible then THEME.Green else THEME.Gray
		achTab.BackgroundColor3 = if questsVisible then THEME.Gray else THEME.Purple
	end
	questTab.Activated:Connect(function()
		play(clickSound)
		showTab(true)
	end)
	achTab.Activated:Connect(function()
		play(clickSound)
		showTab(false)
	end)

	local function refresh()
		clearList(questList)
		for order, quest in progressState.Quests or {} do
			local def = Config.QuestsById[quest.Id]
			if def then
				local row = rowFrame(questList, 72, order)
				local done = quest.Progress >= def.Goal
				leftText({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 24), Text = def.Text, Font = TITLE_FONT, TextSize = 20, Parent = row })
				leftText({ Position = UDim2.fromOffset(14, 33), Size = UDim2.new(1, -170, 0, 18), Text = `{math.min(quest.Progress, def.Goal)}/{def.Goal}  ·  {rewardText(def)}`, TextSize = 14, TextColor3 = THEME.Muted, Parent = row })
				progressBar(row, UDim2.fromOffset(14, 56), UDim2.new(1, -170, 0, 8), quest.Progress / def.Goal, if done then THEME.Gold else THEME.Green)
				local claimable = done and not quest.Claimed
				local claim = button({
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, -12, 0.5, 0),
					Size = UDim2.fromOffset(130, 44),
					Text = if quest.Claimed then "Done ✓" elseif done then "Claim" else "In progress",
					TextSize = if claimable then 20 else 15,
					Parent = row,
				}, if claimable then THEME.Green else THEME.Gray)
				claim.Activated:Connect(function()
					play(clickSound)
					if claimable then
						remotes.ClaimQuest:FireServer(quest.Id)
					end
				end)
			end
		end
		text({ Size = UDim2.new(1, -8, 0, 30), Text = "New quests every day. Rewards grow with your best zone!", TextSize = 14, TextColor3 = THEME.Muted, TextWrapped = true, LayoutOrder = 99, Parent = questList })

		clearList(achList)
		for order, achievement in Config.Achievements do
			local unlocked = progressState.Achievements and progressState.Achievements[achievement.Id] == true
			local value = (progressState.Stats and progressState.Stats[achievement.Stat]) or 0
			local row = rowFrame(achList, 66, order)
			leftText({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 24), Text = (if unlocked then "🏆 " else "🔒 ") .. achievement.Title, Font = TITLE_FONT, TextSize = 20, TextColor3 = if unlocked then THEME.Gold else THEME.Text, Parent = row })
			leftText({ Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -170, 0, 18), Text = `{achievement.Text}  ·  {rewardText(achievement)}`, TextSize = 14, TextColor3 = THEME.Muted, Parent = row })
			if unlocked then
				local using = progressState.Title == achievement.Id
				local use = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 42), Text = if using then "Title ON" else "Use Title", TextSize = 17, Parent = row }, if using then THEME.Green else THEME.Purple)
				use.Activated:Connect(function()
					play(clickSound)
					remotes.SetTitle:FireServer(if using then "" else achievement.Id)
				end)
			else
				text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 10), Size = UDim2.fromOffset(130, 20), Text = `{Format.Number(math.min(value, achievement.Goal))} / {Format.Number(achievement.Goal)}`, TextSize = 15, Parent = row })
				progressBar(row, UDim2.new(1, -142, 0, 38), UDim2.fromOffset(130, 10), value / achievement.Goal, THEME.Purple)
			end
		end
		text({ Size = UDim2.new(1, -8, 0, 30), Text = "Your chosen title is shown above your head and in chat.", TextSize = 14, TextColor3 = THEME.Muted, TextWrapped = true, LayoutOrder = 99, Parent = achList })
	end
	onProgress(frame, refresh)
	refresh()
	return frame, resetLabel
end

---------------------------------------------------------------- Geschenke: Tages-Serie, Spielzeit, Codes

local function buildGiftsWindow(): (Frame, () -> boolean)
	local frame, body = window("Gifts", Vector2.new(540, 450))
	local list = scrollList(body, UDim2.new(), UDim2.fromScale(1, 1))

	-- Tages-Serie
	local daily = rowFrame(list, 84, 1)
	local streakLabel = leftText({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 26), Text = "", Font = TITLE_FONT, TextSize = 21, TextColor3 = THEME.Pink, Parent = daily })
	local dailyInfo = text({ Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -170, 0, 40), Text = "", TextSize = 14, TextColor3 = THEME.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = daily })
	local goGift = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 44), Text = "Go to gift", TextSize = 17, Parent = daily }, THEME.Pink)
	goGift.Activated:Connect(function()
		play(clickSound)
		remotes.Teleport:FireServer(1)
		frame.Visible = false
	end)

	text({ Size = UDim2.new(1, -8, 0, 28), Text = "Playtime Gifts (this visit)", Font = TITLE_FONT, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = list })
	local playtimeRows = {}
	for index, reward in Config.PlaytimeRewards do
		local row = rowFrame(list, 52, 2 + index)
		leftText({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(0, 90, 1, 0), Text = `⏱ {reward.Minutes} min`, Font = TITLE_FONT, TextSize = 18, Parent = row })
		leftText({ Position = UDim2.fromOffset(110, 0), Size = UDim2.new(1, -260, 1, 0), Text = rewardText(reward), TextSize = 15, TextColor3 = THEME.Muted, Parent = row })
		local claim = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 38), Text = "", TextSize = 16, Parent = row }, THEME.Gray)
		claim.Activated:Connect(function()
			play(clickSound)
			remotes.ClaimPlaytime:FireServer(index)
		end)
		playtimeRows[index] = claim
	end

	-- Codes
	text({ Size = UDim2.new(1, -8, 0, 28), Text = "Codes", Font = TITLE_FONT, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 20, Parent = list })
	local codeRow = rowFrame(list, 56, 21)
	local codeBox = create("TextBox", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -160, 0, 40),
		BackgroundColor3 = THEME.PanelDark,
		Text = "",
		PlaceholderText = "Enter a code",
		PlaceholderColor3 = THEME.Muted,
		TextColor3 = THEME.Text,
		Font = BODY_FONT,
		TextSize = 18,
		ClearTextOnFocus = false,
		Parent = codeRow,
	}, { corner(10), padding(10, 0) }) :: TextBox
	local redeem = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 40), Text = "Redeem", TextSize = 18, Parent = codeRow }, THEME.Green)
	redeem.Activated:Connect(function()
		play(clickSound)
		local code = codeBox.Text
		if code:match("%S") then
			remotes.RedeemCode:FireServer(code:sub(1, 30))
			codeBox.Text = ""
		end
	end)

	-- Wird von der HUD-Schleife aufgerufen; gibt zurueck, ob ein Geschenk bereit ist (fuer das Badge)
	local function update(): boolean
		local nextDay = player:GetAttribute("DailyNextDay") or 1
		local ready = player:GetAttribute("DailyReady") == true
		local streak = player:GetAttribute("DailyStreak") or 0
		local giftDay = if ready then nextDay else streak
		streakLabel.Text = `🔥 Daily Gift  ·  Day {math.max(giftDay, 1)} streak`
		dailyInfo.Text = if ready
			then `Ready at the spawn! Coins for {Config.DailyGiftEggs(nextDay)} eggs. Day {Config.StreakMax} also gives free 2x Coins.`
			else `Claimed today. Come back tomorrow for day {nextDay} (coins for {Config.DailyGiftEggs(nextDay)} eggs). Missing a day resets the streak.`
		goGift.Visible = ready

		local anyReady = false
		local claimed = {}
		for _, index in progressState.PlaytimeClaimed or {} do
			claimed[index] = true
		end
		local elapsed = workspace:GetServerTimeNow() - (player:GetAttribute("SessionStart") or workspace:GetServerTimeNow())
		for index, reward in Config.PlaytimeRewards do
			local claim = playtimeRows[index]
			local left = reward.Minutes * 60 - elapsed
			if claimed[index] then
				claim.Text = "Claimed ✓"
				claim.BackgroundColor3 = THEME.Gray
			elseif left <= 0 then
				claim.Text = "Claim!"
				claim.BackgroundColor3 = THEME.Green
				anyReady = true
			else
				claim.Text = Format.Time(left)
				claim.BackgroundColor3 = THEME.Gray
			end
		end
		return anyReady
	end
	update()
	return frame, update
end

---------------------------------------------------------------- Sammel-Index

local function buildIndexWindow(): Frame
	local frame, body = window("Index", Vector2.new(640, 450))
	local bonusLabel = text({ Size = UDim2.new(1, 0, 0, 26), Text = "", TextSize = 16, TextColor3 = THEME.Gold, Parent = body })
	local list = scrollList(body, UDim2.fromOffset(0, 32), UDim2.new(1, 0, 1, -32))

	local function refresh()
		clearList(list)
		local discovered = progressState.Discovered or {}
		local total, found = 0, 0
		for order, egg in Config.Eggs do
			local count = 0
			for _, entry in egg.Pets do
				total += 1
				if discovered[entry.Pet] then
					count += 1
					found += 1
				end
			end
			local complete = count == #egg.Pets
			local section = rowFrame(list, 128, order)
			leftText({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 24), Text = `{egg.Name}  {count}/{#egg.Pets}` .. (if complete then `  ✓ +{math.floor(Config.IndexBonusPerEgg * 100)}% coins` else ""), Font = TITLE_FONT, TextSize = 19, TextColor3 = if complete then THEME.Gold else THEME.Text, Parent = section })
			local cells = create("Frame", { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 88), BackgroundTransparency = 1, Parent = section }, { listLayout(Enum.FillDirection.Horizontal, 8) })
			for cellOrder, entry in egg.Pets do
				local def = Config.PetsById[entry.Pet]
				local known = discovered[entry.Pet] == true
				local cell = create("Frame", { Size = UDim2.fromOffset(88, 88), BackgroundColor3 = if known then Config.RaritiesByName[def.Rarity].Color:Lerp(THEME.PanelDark, 0.62) else THEME.PanelDark, LayoutOrder = cellOrder, Parent = cells }, { corner(10) }) :: Frame
				if known then
					local avatar = petAvatar(cell, entry.Pet, false, 48)
					avatar.AnchorPoint = Vector2.new(0.5, 0)
					avatar.Position = UDim2.new(0.5, 0, 0, 6)
					text({ Position = UDim2.fromOffset(2, 60), Size = UDim2.new(1, -4, 0, 22), Text = def.Name, TextSize = 12, TextWrapped = true, Parent = cell })
				else
					text({ Size = UDim2.new(1, 0, 0, 58), Text = "?", Font = TITLE_FONT, TextSize = 36, TextColor3 = THEME.Muted, Parent = cell })
					text({ Position = UDim2.fromOffset(2, 60), Size = UDim2.new(1, -4, 0, 22), Text = def.Rarity, TextSize = 12, TextColor3 = Config.RaritiesByName[def.Rarity].Color, Parent = cell })
				end
			end
		end
		local completed = Config.CompletedEggs(discovered)
		bonusLabel.Text = `Discovered {found}/{total}  ·  Complete eggs: {completed}/{#Config.Eggs}  ·  Bonus +{math.floor(completed * Config.IndexBonusPerEgg * 100)}% coins`
	end
	onProgress(frame, refresh)
	refresh()
	return frame
end

---------------------------------------------------------------- Schnellreise

local function buildTravelWindow(): Frame
	local frame, body = window("Travel", Vector2.new(440, 440))
	local list = scrollList(body, UDim2.new(), UDim2.fromScale(1, 1))
	local function refresh()
		clearList(list)
		local unlocked = player:GetAttribute("Zone") or 1
		for index, zone in Config.Zones do
			local row = rowFrame(list, 56, index)
			create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = zone.Ground, Parent = row }, { corner(8), outline(1.5) })
			leftText({ Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -200, 1, 0), Text = zone.Name, Font = TITLE_FONT, TextSize = 19, Parent = row })
			local open = index <= unlocked
			local go = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 40), Text = if open then "Go" else "🔒 " .. Format.Number(zone.GateCost), TextSize = if open then 20 else 15, Parent = row }, if open then THEME.Blue else THEME.Gray)
			go.Activated:Connect(function()
				play(clickSound)
				if open then
					remotes.Teleport:FireServer(index)
					frame.Visible = false
				end
			end)
		end
	end
	player:GetAttributeChangedSignal("Zone"):Connect(refresh)
	refresh()
	return frame
end

---------------------------------------------------------------- Einstellungen

local SETTING_ROWS = {
	{ Key = "Sound", Text = "Sounds" },
	{ Key = "OtherPets", Text = "Show other players' pets" },
	{ Key = "CoinPops", Text = "Coin popups" },
	{ Key = "Guide", Text = "Goal hint and arrow" },
}

local function buildSettingsWindow(): Frame
	local frame, body = window("Settings", Vector2.new(440, 340))
	local list = scrollList(body, UDim2.new(), UDim2.fromScale(1, 1))
	for order, setting in SETTING_ROWS do
		local row = rowFrame(list, 56, order)
		leftText({ Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -150, 1, 0), Text = setting.Text, Font = TITLE_FONT, TextSize = 18, Parent = row })
		local toggleButton = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 40), Text = "", TextSize = 18, Parent = row }, THEME.Gray)
		local attribute = "Set_" .. setting.Key
		local function isOn(): boolean
			local value = player:GetAttribute(attribute)
			if value == nil then
				return Config.Settings[setting.Key] ~= false
			end
			return value == true
		end
		local function refresh()
			local on = isOn()
			toggleButton.Text = if on then "ON" else "OFF"
			toggleButton.BackgroundColor3 = if on then THEME.Green else THEME.Gray
		end
		toggleButton.Activated:Connect(function()
			play(clickSound)
			remotes.SetSetting:FireServer(setting.Key, not isOn())
		end)
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
		refresh()
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
	tapSound = create("Sound", { SoundId = "rbxasset://sounds/clickfast.wav", Volume = 0.2, PlaybackSpeed = 1.4, Parent = gui }) :: Sound

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

	-- Bei vielen aktiven Anzeigen (Boost, Server Luck, Happy Hour) in eine zweite Zeile umbrechen
	local chipLayout = listLayout(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) :: UIListLayout
	chipLayout.Wraps = true
	local chips = create("Frame", { Size = UDim2.new(1, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = top }, { chipLayout })
	local function chip(order: number, color: Color3): TextLabel
		local holder = create("Frame", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundColor3 = THEME.PanelDark, BackgroundTransparency = 0.2, LayoutOrder = order, Parent = chips }, { corner(14), edge(), padding(12, 0) })
		return text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "", TextSize = 16, TextColor3 = color, Parent = holder })
	end
	local powerChip = chip(1, Color3.fromRGB(255, 150, 150))
	local petsChip = chip(2, THEME.Text)
	local rankChip = chip(3, THEME.Muted)
	local boostChip = chip(4, THEME.Coin)
	local luckChip = chip(5, Color3.fromRGB(120, 255, 160))
	local happyChip = chip(6, THEME.Gold)

	-- Ziel fuer neue Spieler (mit Pfeil in der Welt, abschaltbar in den Einstellungen)
	local guidePill = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.15,
		Visible = false,
		LayoutOrder = 3,
		Parent = top,
	}, { corner(15), outline(1.5, THEME.Gold), padding(14, 0) }) :: Frame
	local guideLabel = text({ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), Text = "", TextSize = 17, TextColor3 = THEME.Gold, Parent = guidePill })

	announcePill = create("Frame", {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.1,
		Visible = false,
		LayoutOrder = 4,
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

	-- Zwei Spalten, damit alle Knoepfe auch auf kleinen Handys in die Hoehe passen
	local menu = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 20),
		Size = UDim2.fromOffset(148, 298),
		BackgroundTransparency = 1,
		Parent = root,
	}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(70, 70), CellPadding = UDim2.fromOffset(8, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function menuButton(icon: string, name: string, color: Color3, order: number): (TextButton, Frame)
		local b = create("TextButton", { BackgroundColor3 = color, Text = "", AutoButtonColor = true, LayoutOrder = order, Parent = menu }, { corner(18), outline(2), shine() }) :: TextButton
		pressable(b)
		text({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 38), Text = icon, TextSize = 30, Parent = b })
		text({ Position = UDim2.new(0, 0, 1, -25), Size = UDim2.new(1, 0, 0, 20), Text = name, Font = TITLE_FONT, TextSize = 15, Parent = b }, 1.5)
		local badge = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = THEME.Red, Visible = false, Parent = b }, { create("UICorner", { CornerRadius = UDim.new(0.5, 0) }), outline(2) }) :: Frame
		return b, badge
	end
	local petsButton, petsBadge = menuButton("🐾", "Pets", THEME.Orange, 1)
	local shopButton = menuButton("🛒", "Shop", THEME.Green, 2)
	local questsButton, questsBadge = menuButton("📜", "Quests", THEME.Blue, 3)
	local giftsButton, giftsBadge = menuButton("🎁", "Gifts", THEME.Pink, 4)
	local indexButton = menuButton("📖", "Index", Color3.fromRGB(40, 170, 170), 5)
	local travelButton = menuButton("🗺️", "Travel", Color3.fromRGB(70, 120, 200), 6)
	local rebirthButton, rebirthBadge = menuButton("♻️", "Rebirth", THEME.Purple, 7)
	local settingsButton = menuButton("⚙️", "Settings", THEME.Gray, 8)

	-- Unten rechts: Auto Hatch
	local autoButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -110), Size = UDim2.fromOffset(170, 50), Text = "Auto Hatch", TextSize = 19, Parent = root }, THEME.Gray)

	local pets = buildPetsWindow()
	local shop = buildShopWindow()
	local quests, questResetLabel = buildQuestsWindow()
	local gifts, updateGifts = buildGiftsWindow()
	local index = buildIndexWindow()
	local travel = buildTravelWindow()
	local settings = buildSettingsWindow()

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
	questsButton.Activated:Connect(function()
		toggle(quests)
	end)
	giftsButton.Activated:Connect(function()
		toggle(gifts)
	end)
	indexButton.Activated:Connect(function()
		toggle(index)
	end)
	travelButton.Activated:Connect(function()
		toggle(travel)
	end)
	settingsButton.Activated:Connect(function()
		toggle(settings)
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
	remotes.TapHit.OnClientEvent:Connect(function(damage, position)
		play(tapSound)
		coinPop(damage, position, Color3.fromRGB(255, 130, 130), "-")
	end)
	remotes.Progress.OnClientEvent:Connect(function(state)
		progressState = state
		for _, listener in progressListeners do
			task.spawn(listener)
		end
	end)
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

	-- Pfeil vom Spieler zum naechsten Ziel (nur lokal). Die Attachments haengen am Terrain, nicht an der Figur,
	-- damit sie beim Respawn nicht mit zerstoert werden.
	local guideFolder = create("Folder", { Name = "GuideArrow", Parent = workspace })
	local guideStart = create("Attachment", { Name = "GuideStart", Parent = workspace.Terrain }) :: Attachment
	local guideEnd = create("Attachment", { Name = "GuideEnd", Parent = workspace.Terrain }) :: Attachment
	local guideTarget: BasePart? = nil
	local guideBeam = create("Beam", {
		Attachment0 = guideStart,
		Attachment1 = guideEnd,
		FaceCamera = true,
		Width0 = 0.6,
		Width1 = 0.6,
		Segments = 1,
		LightEmission = 1,
		Color = ColorSequence.new(THEME.Gold),
		Transparency = NumberSequence.new(0.25),
		Enabled = false,
		Parent = guideFolder,
	}) :: Beam
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local target = guideTarget
		if rootPart and target and target.Parent then
			guideStart.WorldPosition = rootPart.Position - Vector3.new(0, 1.5, 0)
			guideEnd.WorldPosition = target.Position + Vector3.new(0, 2, 0)
			guideBeam.Enabled = true
		else
			guideBeam.Enabled = false
		end
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

			local happy, happyLeft = Config.HappyHourState(workspace:GetServerTimeNow())
			happyChip.Parent.Visible = happy or happyLeft <= 120
			happyChip.Text = if happy then `Happy Hour x{Config.HappyHourMultiplier}  {Format.Time(happyLeft)}` else `Happy Hour in {Format.Time(happyLeft)}`

			-- Badges: Aufgabe fertig / Geschenk bereit
			local questReady = false
			for _, quest in progressState.Quests or {} do
				local def = Config.QuestsById[quest.Id]
				if def and not quest.Claimed and quest.Progress >= def.Goal then
					questReady = true
				end
			end
			questsBadge.Visible = questReady
			giftsBadge.Visible = updateGifts() or player:GetAttribute("DailyReady") == true
			questResetLabel.Text = `New quests in {longTime(86400 - os.time() % 86400)}`

			-- Ziel und Pfeil
			local goalText, goalPart = currentGoal()
			local showGuide = player:GetAttribute("Set_Guide") ~= false and goalText ~= nil
			guidePill.Visible = showGuide
			guideLabel.Text = "🎯 " .. (goalText or "")
			guideTarget = if showGuide then goalPart else nil

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
