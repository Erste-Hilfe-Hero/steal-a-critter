-- Baut das komplette HUD per Code: Muenzanzeige, Haustier-Inventar, Shop, Rebirth, Schluepf-Animation, Meldungen.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PetFactory = require(ReplicatedStorage.Shared.PetFactory)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(25, 25, 35)
local GREY = Color3.fromRGB(90, 90, 100)

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

local function stroke(thickness: number)
	return create("UIStroke", { Thickness = thickness, Color = Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	return create("TextLabel", props, { create("UIStroke", { Thickness = 2 }) })
end

local function button(props, color: Color3)
	props.BackgroundColor3 = color
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = Color3.new(1, 1, 1)
	props.AutoButtonColor = true
	return create("TextButton", props, { corner(10), stroke(2), create("UITextSizeConstraint", { MaxTextSize = 26 }) })
end

local function window(gui: ScreenGui, title: string, size: UDim2): (Frame, TextButton)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = DARK,
		Visible = false,
		Parent = gui,
	}, { corner(14), stroke(3), create("UISizeConstraint", { MinSize = Vector2.new(330, 280), MaxSize = Vector2.new(720, 720) }) })
	label({ Name = "Title", Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 40), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local close = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(42, 42), Text = "X", Parent = frame }, Color3.fromRGB(220, 60, 60))
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	return frame, close
end

---------------------------------------------------------------- Meldungen

local toastContainer: Frame
local announceLabel: TextLabel

local function showToast(text: string, color: Color3?)
	local toast = label({ Size = UDim2.new(1, 0, 0, 32), Text = text, TextColor3 = color or Color3.new(1, 1, 1), Parent = toastContainer })
	task.delay(3.5, function()
		TweenService:Create(toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast:Destroy()
	end)
end

local announceToken = 0
local function showAnnouncement(text: string, color: Color3?)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = text
	announceLabel.TextColor3 = color or Color3.new(1, 1, 1)
	announceLabel.Visible = true
	task.delay(5, function()
		if token == announceToken then
			announceLabel.Visible = false
		end
	end)
end

-- "+123" ueber zerstoerten Sachen
local function coinPop(amount: number, position: Vector3)
	local anchor = create("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, Position = position, Parent = workspace })
	local gui = create("BillboardGui", { Size = UDim2.fromOffset(140, 40), AlwaysOnTop = true, MaxDistance = 120, Parent = anchor })
	local text = label({ Size = UDim2.fromScale(1, 1), Text = "+" .. Format.Number(amount), TextColor3 = Color3.fromRGB(255, 220, 60), Parent = gui })
	TweenService:Create(gui, TweenInfo.new(1), { StudsOffset = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(text, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	task.delay(1, function()
		anchor:Destroy()
	end)
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
		Parent = parent,
	})
	local camera = create("Camera", { FieldOfView = 40, Parent = frame })
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
		local slot = create("Frame", { Size = UDim2.fromOffset(170, 230), BackgroundTransparency = 1, LayoutOrder = index, Parent = hatchFrame })
		local eggModel = create("Model", {})
		local eggPart = create("Part", { Shape = Enum.PartType.Ball, Size = Vector3.one * 4, Color = egg.Color, Anchored = true, Parent = eggModel }, {
			create("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 1.3, 1) }),
		})
		eggModel.PrimaryPart = eggPart
		local view = viewport(slot, eggModel, 11)
		table.insert(slots, { Slot = slot, View = view, Egg = eggModel, TypeId = typeId })
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
	for _, slot in slots do
		slot.Egg:Destroy()
		local def = Config.PetsById[slot.TypeId]
		local rarity = Config.RaritiesByName[def.Rarity]
		local pet = PetFactory.Build(slot.TypeId)
		pet:PivotTo(CFrame.Angles(0, math.pi, 0))
		pet.Parent = slot.View
		local camera = slot.View.CurrentCamera :: Camera
		camera.CFrame = CFrame.lookAt(Vector3.new(0, rarity.Scale * 0.6, rarity.Scale * 3.2), Vector3.zero)
		label({ Position = UDim2.fromOffset(0, 170), Size = UDim2.new(1, 0, 0, 30), Text = def.Name, Parent = slot.Slot })
		label({ Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 24), Text = def.Rarity, TextColor3 = rarity.Color, Parent = slot.Slot })
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

local function buildPetsWindow(gui: ScreenGui): Frame
	local frame = window(gui, "PETS", UDim2.fromScale(0.6, 0.78))
	local title = frame:FindFirstChild("Title") :: TextLabel

	local toolbar = create("Frame", { Position = UDim2.fromOffset(10, 54), Size = UDim2.new(1, -20, 0, 40), BackgroundTransparency = 1, Parent = frame }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local equipBest = button({ Size = UDim2.new(0.5, -4, 1, 0), Text = "EQUIP BEST", Parent = toolbar }, Color3.fromRGB(60, 200, 90))
	local deleteWeak = button({ Size = UDim2.new(0.5, -4, 1, 0), Text = "DELETE UNEQUIPPED COMMONS", Parent = toolbar }, Color3.fromRGB(200, 70, 70))

	local grid = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 100),
		Size = UDim2.new(1, -20, 1, -190),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(92, 96), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })

	local detail = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 76), BackgroundColor3 = Color3.fromRGB(40, 40, 55), Parent = frame }, { corner(10) })
	local detailText = label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 28), Text = "Tap a pet", Parent = detail })
	local actions = create("Frame", { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 34), BackgroundTransparency = 1, Parent = detail }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local equipButton = button({ Size = UDim2.new(1 / 3, -6, 1, 0), Text = "EQUIP", Parent = actions }, Color3.fromRGB(60, 160, 255))
	local goldenButton = button({ Size = UDim2.new(1 / 3, -6, 1, 0), Text = "GOLDEN", Parent = actions }, Color3.fromRGB(230, 170, 30))
	local deleteButton = button({ Size = UDim2.new(1 / 3, -6, 1, 0), Text = "DELETE", Parent = actions }, Color3.fromRGB(200, 70, 70))
	local deleteArmed = false

	local function refreshDetail()
		local pet = selected and inventory[selected]
		actions.Visible = pet ~= nil
		deleteArmed = false
		deleteButton.Text = "DELETE"
		if not pet then
			selected = nil
			detailText.Text = "Tap a pet to equip, craft or delete it"
			return
		end
		local def = Config.PetsById[pet.T]
		detailText.Text = `{if pet.G then "Golden " else ""}{def.Name} ({def.Rarity})  -  Power {Format.Number(Config.PetPower(pet.T, pet.G))}`
		detailText.TextColor3 = if pet.G then Color3.fromRGB(255, 210, 60) else Config.RaritiesByName[def.Rarity].Color
		equipButton.Text = if table.find(equipped, selected) then "UNEQUIP" else "EQUIP"
		local count = countOf(pet.T)
		goldenButton.Visible = not pet.G
		goldenButton.Text = `GOLDEN {math.min(count, Config.GoldenCraftAmount)}/{Config.GoldenCraftAmount}`
		goldenButton.BackgroundColor3 = if count >= Config.GoldenCraftAmount then Color3.fromRGB(230, 170, 30) else GREY
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
			local card = create("TextButton", {
				Text = "",
				LayoutOrder = order,
				BackgroundColor3 = if item.Pet.G then Color3.fromRGB(120, 95, 20) else rarity.Color:Lerp(DARK, 0.55),
				AutoButtonColor = true,
				Parent = grid,
			}, { corner(10), create("UIStroke", { Thickness = if item.Uid == selected then 3 else 1.5, Color = if item.Uid == selected then Color3.new(1, 1, 1) else rarity.Color, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
			create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = if item.Pet.G then Color3.fromRGB(255, 205, 40) else def.Color, Parent = card }, { create("UICorner", { CornerRadius = UDim.new(if def.Shape == "Ball" then 0.5 else 0.2, 0) }), stroke(1.5) })
			label({ Position = UDim2.fromOffset(4, 50), Size = UDim2.new(1, -8, 0, 20), Text = def.Name, Parent = card })
			label({ Position = UDim2.fromOffset(4, 71), Size = UDim2.new(1, -8, 0, 18), Text = Format.Number(item.Power), TextColor3 = Color3.fromRGB(255, 120, 120), Parent = card })
			if item.Equipped then
				label({ Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(22, 22), Text = "E", TextColor3 = Color3.fromRGB(90, 255, 120), Parent = card })
			end
			card.Activated:Connect(function()
				selected = item.Uid
				refreshPets()
			end)
		end
		title.Text = `PETS  {total}/{player:GetAttribute("Storage") or Config.MaxStorage}   Equipped {#equipped}/{player:GetAttribute("MaxEquip") or Config.BaseEquip}`
		refreshDetail()
	end

	equipBest.Activated:Connect(function()
		remotes.EquipBest:FireServer()
	end)
	deleteWeak.Activated:Connect(function()
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
		if selected then
			remotes.ToggleEquip:FireServer(selected)
		end
	end)
	goldenButton.Activated:Connect(function()
		local pet = selected and inventory[selected]
		if pet then
			remotes.CraftGolden:FireServer(pet.T)
		end
	end)
	deleteButton.Activated:Connect(function()
		if not selected then
			return
		end
		if not deleteArmed then
			deleteArmed = true
			deleteButton.Text = "SURE?"
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
	local row = create("Frame", { Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = Color3.fromRGB(40, 40, 55), LayoutOrder = order, Parent = parent }, { corner(10) })
	label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.65, -12, 0, 30), Text = entry.Name, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	label({ Position = UDim2.fromOffset(12, 38), Size = UDim2.new(0.65, -12, 0, 22), Text = entry.Description, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 210), Parent = row })
	local buy = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.3, 0, 0, 46), Text = "R$ " .. entry.PriceHint, Parent = row }, color)

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
				buy.Text = "OWNED"
				buy.BackgroundColor3 = GREY
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

---------------------------------------------------------------- Start

function UI.Start()
	local gui = create("ScreenGui", { Name = "HUD", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })

	-- Anzeige oben
	local top = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(440, 150), BackgroundTransparency = 1, Parent = gui }, {
		create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local coinsLabel = label({ Size = UDim2.new(1, 0, 0, 48), Text = "0", TextColor3 = Color3.fromRGB(255, 215, 60), LayoutOrder = 1, Parent = top })
	local infoLabel = label({ Size = UDim2.new(1, 0, 0, 22), Text = "", LayoutOrder = 2, Parent = top })
	local statusLabel = label({ Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = Color3.fromRGB(90, 255, 140), LayoutOrder = 3, Parent = top })
	local rankLabel = label({ Size = UDim2.new(1, 0, 0, 18), Text = "", TextColor3 = Color3.fromRGB(200, 200, 255), LayoutOrder = 4, Parent = top })

	announceLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 160), Size = UDim2.new(0.7, 0, 0, 34), Visible = false, Parent = gui })
	toastContainer = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.new(0.6, 0, 0, 170), BackgroundTransparency = 1, Parent = gui }, {
		create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})

	hatchFrame = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(560, 240), BackgroundTransparency = 1, Visible = false, ZIndex = 5, Parent = gui }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- Seitenbuttons
	local side = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(110, 210), BackgroundTransparency = 1, Parent = gui }, {
		create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local petsButton = button({ Size = UDim2.new(1, 0, 0, 56), Text = "PETS", LayoutOrder = 1, Parent = side }, Color3.fromRGB(255, 140, 40))
	local shopButton = button({ Size = UDim2.new(1, 0, 0, 56), Text = "SHOP", LayoutOrder = 2, Parent = side }, Color3.fromRGB(60, 200, 90))
	local rebirthButton = button({ Size = UDim2.new(1, 0, 0, 56), Text = "REBIRTH", LayoutOrder = 3, Parent = side }, Color3.fromRGB(160, 80, 255))

	local autoButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -110), Size = UDim2.fromOffset(150, 50), Text = "AUTO HATCH", Parent = gui }, GREY)

	local pets = buildPetsWindow(gui)

	-- Shop-Fenster
	local shop = window(gui, "SHOP", UDim2.fromScale(0.5, 0.72))
	local list = create("ScrollingFrame", { Position = UDim2.fromOffset(10, 58), Size = UDim2.new(1, -20, 1, -68), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = shop }, {
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({ Size = UDim2.new(1, -10, 0, 28), Text = "Passes (forever)", TextColor3 = Color3.fromRGB(255, 200, 40), LayoutOrder = 0, Parent = list })
	for _, item in sortedEntries(Config.GamePasses) do
		buildShopRow(list, "Pass", item.Key, item.Entry, Color3.fromRGB(255, 170, 30), item.Entry.Order)
	end
	label({ Size = UDim2.new(1, -10, 0, 28), Text = "Boosts", TextColor3 = Color3.fromRGB(90, 220, 255), LayoutOrder = 50, Parent = list })
	for _, item in sortedEntries(Config.DevProducts) do
		buildShopRow(list, "Product", item.Key, item.Entry, Color3.fromRGB(40, 170, 255), 50 + item.Entry.Order)
	end
	label({ Size = UDim2.new(1, -10, 0, 40), Text = "Eggs are only bought with coins. Chances are shown at every egg.", TextColor3 = Color3.fromRGB(170, 170, 180), LayoutOrder = 99, Parent = list })

	-- Rebirth-Fenster
	local rebirth = window(gui, "REBIRTH", UDim2.fromOffset(380, 270))
	local rebirthInfo = label({ Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -32, 0, 120), Text = "", Parent = rebirth })
	local confirmRebirth = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(0.7, 0, 0, 52), Text = "REBIRTH", Parent = rebirth }, Color3.fromRGB(160, 80, 255))

	local windows = { pets, shop, rebirth }
	local function toggle(target: Frame)
		local show = not target.Visible
		for _, other in windows do
			other.Visible = false
		end
		target.Visible = show
	end
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
		remotes.RequestRebirth:FireServer()
		rebirth.Visible = false
	end)
	autoButton.Activated:Connect(function()
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

	task.delay(4, function()
		if player:GetAttribute("DailyReady") then
			showToast("Your DAILY GIFT is ready at the spawn!", Color3.fromRGB(255, 120, 160))
		end
	end)

	-- Anzeige laufend aktualisieren
	task.spawn(function()
		while gui.Parent do
			local coins = player:GetAttribute("Coins") or 0
			local rebirths = player:GetAttribute("Rebirths") or 0
			local cost = player:GetAttribute("RebirthCost") or 0
			local zone = player:GetAttribute("Zone") or 1
			coinsLabel.Text = Format.Coins(coins)
			local petCount = 0
			for _ in inventory do
				petCount += 1
			end
			infoLabel.Text = `x{player:GetAttribute("Multiplier") or 1} coins   |   Power {Format.Number(player:GetAttribute("Power") or 0)}   |   Pets {petCount}/{player:GetAttribute("Storage") or Config.MaxStorage}`

			local parts = {}
			local boostLeft = (player:GetAttribute("BoostUntil") or 0) - os.time()
			if boostLeft > 0 then
				table.insert(parts, `2x COINS {Format.Time(boostLeft)}`)
			end
			local luckLeft = (workspace:GetAttribute("LuckUntil") or 0) - workspace:GetServerTimeNow()
			if luckLeft > 0 then
				table.insert(parts, `SERVER LUCK x{Config.ServerLuckMultiplier} {Format.Time(luckLeft)}`)
			end
			statusLabel.Text = table.concat(parts, "   ")

			local nextRank = player:GetAttribute("NextRank")
			rankLabel.Text = `Rank: {player:GetAttribute("Rank") or "Newbie"}` .. (if nextRank then `  (next {nextRank})` else "") .. "  /rank"
			if player:GetAttribute("RankColor") then
				rankLabel.TextColor3 = Color3.fromHex(player:GetAttribute("RankColor"))
			end

			local on = player:GetAttribute("AutoHatch") == true
			autoButton.Text = if on then "AUTO HATCH: ON" elseif player:GetAttribute("Pass_AutoHatch") then "AUTO HATCH: OFF" else "AUTO HATCH (Pass)"
			autoButton.BackgroundColor3 = if on then Color3.fromRGB(60, 200, 90) else GREY

			local current = 1 + rebirths * Config.RebirthMultiplierPer
			local ready = zone >= #Config.Zones and coins >= cost
			rebirthInfo.Text = `Needs: {Config.Zones[#Config.Zones].Name} + {Format.Coins(cost)}\nCoins multiplier: x{current} -> x{current + Config.RebirthMultiplierPer}\nResets coins and zones. You KEEP all pets.`
			confirmRebirth.BackgroundColor3 = if ready then Color3.fromRGB(160, 80, 255) else GREY
			task.wait(0.2)
		end
	end)
end

return UI
