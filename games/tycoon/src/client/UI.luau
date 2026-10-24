-- Baut das komplette HUD per Code: Muenzen, Rucksack, Samenleiste, Samenladen, Upgrades, Store, Meldungen.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(25, 30, 35)
local ROW = Color3.fromRGB(40, 48, 55)
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

---------------------------------------------------------------- Meldungen

local toastContainer: Frame
local announceLabel: TextLabel

local function showToast(text: string, color: Color3?)
	local toast = label({ Size = UDim2.new(1, 0, 0, 30), Text = text, TextColor3 = color or Color3.new(1, 1, 1), Parent = toastContainer })
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
	task.delay(6, function()
		if token == announceToken then
			announceLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------- Fenster

local windows = {}

local function makeWindow(gui: Instance, title: string, color: Color3): (Frame, ScrollingFrame)
	local frame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0.55, 0, 0.72, 0),
		BackgroundColor3 = DARK,
		Visible = false,
		Parent = gui,
	}, { corner(14), stroke(3), create("UISizeConstraint", { MinSize = Vector2.new(330, 260), MaxSize = Vector2.new(640, 720) }) })
	label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 40), Text = title, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local close = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(42, 42), Text = "X", Parent = frame }, Color3.fromRGB(220, 60, 60))
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	local list = create("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 58),
		Size = UDim2.new(1, -20, 1, -68),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = frame,
	}, { create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }) })
	table.insert(windows, frame)
	return frame, list
end

local function toggle(window: Frame)
	local show = not window.Visible
	for _, other in windows do
		other.Visible = false
	end
	window.Visible = show
end

-- Zeile mit Titel, Untertitel und Knopf rechts
local function makeRow(parent: Instance, order: number, title: string, color: Color3?): (Frame, TextLabel, TextLabel, TextButton)
	local row = create("Frame", { Size = UDim2.new(1, -10, 0, 66), BackgroundColor3 = ROW, LayoutOrder = order, Parent = parent }, { corner(10) })
	local titleLabel = label({ Position = UDim2.fromOffset(12, 5), Size = UDim2.new(0.62, -12, 0, 30), Text = title, TextColor3 = color or Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local info = label({ Position = UDim2.fromOffset(12, 37), Size = UDim2.new(0.62, -12, 0, 22), Text = "", TextColor3 = Color3.fromRGB(200, 205, 210), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local action = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.34, 0, 0, 46), Text = "", Parent = row }, Color3.fromRGB(60, 190, 90))
	return row, titleLabel, info, action
end

---------------------------------------------------------------- Robux-Store

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

local function buildStoreRow(parent: Instance, order: number, kind: string, key: string, entry, color: Color3)
	local _, _, info, buy = makeRow(parent, order, entry.Name)
	info.Text = entry.Description
	buy.Text = "R$ " .. entry.PriceHint
	buy.BackgroundColor3 = color
	local productId = if kind == "Pass" then entry.ProductId else entry.Id
	if productId ~= 0 then
		task.spawn(function()
			local ok, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, Enum.InfoType.Product)
			if ok and result and result.PriceInRobux then
				buy.Text = "R$ " .. result.PriceInRobux
			end
		end)
	end
	if kind == "Pass" then
		local function refreshOwned()
			if player:GetAttribute("Pass_" .. key) then
				buy.Text = "OWNED"
				buy.BackgroundColor3 = GREY
			end
		end
		refreshOwned()
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(refreshOwned)
	end
	buy.Activated:Connect(function()
		if kind == "Pass" and player:GetAttribute("Pass_" .. key) then
			return
		end
		if productId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, productId)
		else
			-- Nur in Studio wirksam (Server prueft das)
			remotes.FakePurchase:FireServer(kind, key)
		end
	end)
end

---------------------------------------------------------------- Start

function UI.Start()
	local gui = create("ScreenGui", {
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- Anzeige oben
	local top = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(440, 150),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local coinsLabel = label({ Size = UDim2.new(1, 0, 0, 48), Text = "$0", TextColor3 = Color3.fromRGB(255, 220, 80), LayoutOrder = 1, Parent = top })
	local bagLabel = label({ Size = UDim2.new(1, 0, 0, 24), Text = "", LayoutOrder = 2, Parent = top })
	local eventLabel = label({ Size = UDim2.new(1, 0, 0, 24), Text = "", TextColor3 = Color3.fromRGB(140, 200, 255), LayoutOrder = 3, Parent = top })
	local rankLabel = label({ Size = UDim2.new(1, 0, 0, 20), Text = "", TextColor3 = Color3.fromRGB(200, 200, 255), LayoutOrder = 4, Parent = top })

	announceLabel = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.new(0.75, 0, 0, 34),
		Visible = false,
		Parent = gui,
	})

	toastContainer = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.new(0.6, 0, 0, 160),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center }) })

	-- Seitenbuttons (gross genug fuer Handys)
	local side = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(112, 330),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function sideButton(text: string, color: Color3, order: number): TextButton
		return button({ Size = UDim2.new(1, 0, 0, 48), Text = text, LayoutOrder = order, Parent = side }, color)
	end
	local gardenButton = sideButton("GARDEN", Color3.fromRGB(80, 170, 70), 1)
	local seedsButton = sideButton("SEEDS", Color3.fromRGB(60, 200, 90), 2)
	local sellButton = sideButton("SELL", Color3.fromRGB(255, 170, 30), 3)
	local upgradesButton = sideButton("UPGRADES", Color3.fromRGB(60, 140, 255), 4)
	local storeButton = sideButton("STORE", Color3.fromRGB(255, 80, 160), 5)

	-- Samenleiste unten: Tippen waehlt den Samen, Tippen auf ein Feld pflanzt ihn
	local hotbar = create("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0.7, 0, 0, 74),
		BackgroundTransparency = 1,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = gui,
	}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local slotButtons = {}
	for _, seed in Config.Seeds do
		local slot = button({ Size = UDim2.fromOffset(86, 64), Text = "", LayoutOrder = seed.Index, Visible = false, Parent = hotbar }, Color3.fromRGB(45, 55, 60))
		local slotStroke = slot:FindFirstChildOfClass("UIStroke") :: UIStroke
		label({ Size = UDim2.new(1, -8, 0.55, 0), Position = UDim2.fromOffset(4, 2), Text = seed.Name, TextColor3 = Config.RaritiesByName[seed.Rarity].Color, Parent = slot })
		local count = label({ Size = UDim2.new(1, -8, 0.4, 0), Position = UDim2.new(0, 4, 0.58, 0), Text = "", Parent = slot })
		slot.Activated:Connect(function()
			remotes.SelectSeed:FireServer(seed.Id)
		end)
		slotButtons[seed.Id] = { Button = slot, Count = count, Stroke = slotStroke }
	end

	-- Samenladen
	local seedWindow, seedList = makeWindow(gui, "SEED SHOP", Color3.fromRGB(120, 255, 140))
	local restockInfo = label({ Size = UDim2.new(1, -10, 0, 26), Text = "", TextColor3 = Color3.fromRGB(180, 255, 180), LayoutOrder = 0, Parent = seedList })
	local seedRows = {}
	for _, seed in Config.Seeds do
		local rarity = Config.RaritiesByName[seed.Rarity]
		local _, _, info, buy = makeRow(seedList, seed.Index, `{seed.Name}  [{seed.Rarity}]`, rarity.Color)
		local kind = if seed.Regrow then `regrows every {seed.Regrow}s` else "single harvest"
		buy.Activated:Connect(function()
			remotes.BuySeed:FireServer(seed.Id)
		end)
		seedRows[seed.Id] = { Info = info, Buy = buy, Text = `Sells ~{Format.Cash(seed.Value)} · grows {Format.Time(seed.Grow)} · {kind}` }
	end
	local robuxSeeds = label({ Size = UDim2.new(1, -10, 0, 26), Text = "Can't wait for a restock?", TextColor3 = Color3.fromRGB(255, 120, 200), LayoutOrder = 50, Parent = seedList })
	robuxSeeds.LayoutOrder = 50
	buildStoreRow(seedList, 51, "Product", "SeedDragon", Config.DevProducts.SeedDragon, Color3.fromRGB(255, 80, 160))
	buildStoreRow(seedList, 52, "Product", "SeedStar", Config.DevProducts.SeedStar, Color3.fromRGB(255, 80, 160))

	-- Upgrades
	local upgradeWindow, upgradeList = makeWindow(gui, "UPGRADES", Color3.fromRGB(120, 180, 255))
	local _, _, tileInfo, tileBuy = makeRow(upgradeList, 1, "Garden Tile")
	tileBuy.Activated:Connect(function()
		remotes.BuyUpgrade:FireServer("Tile")
	end)
	local upgradeRows = {}
	local order = 2
	for key, upgrade in Config.Upgrades do
		local _, _, info, buy = makeRow(upgradeList, order, upgrade.Name)
		order += 1
		buy.Activated:Connect(function()
			remotes.BuyUpgrade:FireServer(key)
		end)
		upgradeRows[key] = { Info = info, Buy = buy, Upgrade = upgrade }
	end
	local _, _, rebirthInfo, rebirthBuy = makeRow(upgradeList, 10, "REBIRTH", Color3.fromRGB(200, 130, 255))
	rebirthBuy.BackgroundColor3 = Color3.fromRGB(160, 80, 255)
	rebirthBuy.Activated:Connect(function()
		remotes.RequestRebirth:FireServer()
	end)
	label({
		Size = UDim2.new(1, -10, 0, 40),
		LayoutOrder = 11,
		Text = "Rebirth resets coins, seeds, plants, tiles and upgrades but keeps a permanent fruit value bonus.",
		TextColor3 = Color3.fromRGB(190, 190, 200),
		Parent = upgradeList,
	})

	-- Robux-Store
	local storeWindow, storeList = makeWindow(gui, "STORE", Color3.fromRGB(255, 120, 200))
	label({ Size = UDim2.new(1, -10, 0, 28), Text = "Forever Upgrades", TextColor3 = Color3.fromRGB(255, 200, 40), LayoutOrder = 0, Parent = storeList })
	for i, item in sortedEntries(Config.GamePasses) do
		buildStoreRow(storeList, i, "Pass", item.Key, item.Entry, Color3.fromRGB(255, 170, 30))
	end
	label({ Size = UDim2.new(1, -10, 0, 28), Text = "Boosts", TextColor3 = Color3.fromRGB(90, 220, 255), LayoutOrder = 20, Parent = storeList })
	for i, item in sortedEntries(Config.DevProducts) do
		buildStoreRow(storeList, 20 + i, "Product", item.Key, item.Entry, Color3.fromRGB(40, 170, 255))
	end

	gardenButton.Activated:Connect(function()
		remotes.Teleport:FireServer("Garden")
	end)
	seedsButton.Activated:Connect(function()
		toggle(seedWindow)
	end)
	sellButton.Activated:Connect(function()
		remotes.SellAll:FireServer()
	end)
	upgradesButton.Activated:Connect(function()
		toggle(upgradeWindow)
	end)
	storeButton.Activated:Connect(function()
		toggle(storeWindow)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "OpenSeedShop" and not seedWindow.Visible then
			toggle(seedWindow)
		end
	end)

	remotes.Notify.OnClientEvent:Connect(showToast)
	remotes.Announce.OnClientEvent:Connect(showAnnouncement)

	-- Anzeige laufend aktualisieren
	task.spawn(function()
		while gui.Parent do
			local coins = player:GetAttribute("Coins") or 0
			local multiplier = player:GetAttribute("SellMultiplier") or 1
			coinsLabel.Text = Format.Cash(coins)
			local fruits = player:GetAttribute("FruitCount") or 0
			local bagValue = math.floor((player:GetAttribute("FruitValue") or 0) * multiplier)
			bagLabel.Text = `Backpack {fruits}/{Config.BackpackSize}  ·  worth {Format.Cash(bagValue)}  ·  x{multiplier}`
			bagLabel.TextColor3 = if fruits >= Config.BackpackSize then Color3.fromRGB(255, 90, 90) else Color3.new(1, 1, 1)

			local now = workspace:GetServerTimeNow()
			local events = {}
			local weather = workspace:GetAttribute("Weather")
			if weather and weather ~= "Clear" then
				table.insert(events, `{weather:upper()} {Format.Time((workspace:GetAttribute("WeatherUntil") or 0) - now)}`)
			end
			local goldenLeft = (workspace:GetAttribute("GoldenUntil") or 0) - now
			if goldenLeft > 0 then
				table.insert(events, `GOLDEN HOUR {Format.Time(goldenLeft)}`)
			end
			local friends = player:GetAttribute("Friends") or 0
			if friends > 0 then
				table.insert(events, `Friends +{friends * 10}%`)
			end
			eventLabel.Text = table.concat(events, "  ·  ")

			local nextRank = player:GetAttribute("NextRank")
			rankLabel.Text = `Rank: {player:GetAttribute("Rank") or "Newbie"}` .. (if nextRank then `  (next {nextRank})` else "") .. "  /rank"
			if player:GetAttribute("RankColor") then
				rankLabel.TextColor3 = Color3.fromHex(player:GetAttribute("RankColor"))
			end

			-- Samenleiste
			local selected = player:GetAttribute("SelectedSeed")
			for id, slot in slotButtons do
				local count = player:GetAttribute("Seed_" .. id) or 0
				slot.Button.Visible = count > 0
				slot.Count.Text = "x" .. count
				slot.Stroke.Color = if id == selected then Color3.fromRGB(255, 230, 60) else Color3.new(0, 0, 0)
				slot.Stroke.Thickness = if id == selected then 4 else 2
			end

			-- Samenladen
			local restockLeft = (workspace:GetAttribute("NextRestock") or 0) - now
			restockInfo.Text = `New seeds in {Format.Time(restockLeft)}`
			for id, row in seedRows do
				local seed = Config.SeedsById[id]
				local stock = player:GetAttribute("Stock_" .. id) or 0
				row.Info.Text = row.Text
				if stock > 0 then
					row.Buy.Text = `{Format.Cash(seed.Price)}  (x{stock})`
					row.Buy.BackgroundColor3 = if coins >= seed.Price then Color3.fromRGB(60, 190, 90) else GREY
				else
					row.Buy.Text = "SOLD OUT"
					row.Buy.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
				end
			end

			-- Upgrades
			local tiles = player:GetAttribute("Tiles") or Config.StartTiles
			local maxTiles = player:GetAttribute("MaxTiles") or Config.MaxTiles
			local tileCost = player:GetAttribute("TileCost") or 0
			tileInfo.Text = `{tiles}/{maxTiles} tiles`
			if tiles >= maxTiles then
				tileBuy.Text = if player:GetAttribute("Pass_BigGarden") then "MAX" else "BIG GARDEN"
				tileBuy.BackgroundColor3 = if player:GetAttribute("Pass_BigGarden") then GREY else Color3.fromRGB(255, 80, 160)
			else
				tileBuy.Text = Format.Cash(tileCost)
				tileBuy.BackgroundColor3 = if coins >= tileCost then Color3.fromRGB(60, 190, 90) else GREY
			end
			for key, row in upgradeRows do
				local level = player:GetAttribute("Upgrade_" .. key) or 0
				local cost = player:GetAttribute("UpgradeCost_" .. key) or 0
				row.Info.Text = `Level {level}/{Config.MaxUpgradeLevel} · {row.Upgrade.Description}`
				if level >= Config.MaxUpgradeLevel then
					row.Buy.Text = "MAX"
					row.Buy.BackgroundColor3 = GREY
				else
					row.Buy.Text = Format.Cash(cost)
					row.Buy.BackgroundColor3 = if coins >= cost then Color3.fromRGB(60, 190, 90) else GREY
				end
			end
			local rebirths = player:GetAttribute("Rebirths") or 0
			local rebirthCost = player:GetAttribute("RebirthCost") or 0
			local current = 1 + rebirths * Config.RebirthMultiplierPer
			rebirthInfo.Text = `Bonus x{current} -> x{current + Config.RebirthMultiplierPer}`
			rebirthBuy.Text = Format.Cash(rebirthCost)
			rebirthBuy.BackgroundColor3 = if coins >= rebirthCost then Color3.fromRGB(160, 80, 255) else GREY
			task.wait(0.25)
		end
	end)
end

return UI
