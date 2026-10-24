-- Benutzeroberflaeche ausserhalb der Kaempfe: Anzeige oben, Menue, Team, Shop, Orb-Laden, Arena, Starter-Wahl,
-- Meldungen und Kaufangebote. Alles skaliert per UIScale, damit es auf dem Handy gut lesbar ist.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local AdService = game:GetService("AdService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)

local C = Theme.Colors
local create = Theme.create
local label = Theme.label
local button = Theme.button

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local UI = {}
UI.State = { Collection = nil :: any }

local gui: ScreenGui
local root: Frame
local hud: Frame
local modal: Frame
local toastList: Frame
local openWindow: Frame? = nil
local refreshers = {} -- Funktionen, die bei neuer Sammlung neu zeichnen

---------------------------------------------------------------- Hilfen

local function restricted(): boolean
	return player:GetAttribute("RandomRestricted") == true
end

local function hasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

-- Kauf starten (in Studio ohne IDs: simulieren)
function UI.Buy(kind: string, key: string)
	if kind == "Pass" then
		local pass = Config.GamePasses[key]
		if pass.ProductId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, pass.ProductId)
		elseif pass.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		elseif RunService:IsStudio() then
			remotes.FakePurchase:FireServer("Pass", key)
		end
	else
		local product = Config.DevProducts[key]
		if product.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.Id)
		elseif RunService:IsStudio() then
			remotes.FakePurchase:FireServer("Product", key)
		end
	end
end

local function priceButton(price: number, props): TextButton
	props.Color = props.Color or C.Green
	props.Text = props.Text or `R$ {price}`
	return button(props)
end

---------------------------------------------------------------- Meldungen

function UI.Toast(text: string, color: Color3?)
	local toast = create("Frame", {
		Size = UDim2.fromOffset(0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.05,
		Parent = toastList,
	})
	Theme.corner(toast, 20)
	Theme.stroke(toast, color or C.Gold, 2)
	create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = toast })
	label({
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = text,
		TextColor3 = color or C.Cream,
		TextSize = 18,
		TextWrapped = false,
		Parent = toast,
	})
	local children = {}
	for _, child in toastList:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 4 then
		children[1]:Destroy()
	end
	task.delay(4, function()
		if toast.Parent then
			toast:Destroy()
		end
	end)
end

local bannerLabel: TextLabel
function UI.Announce(text: string, color: Color3?)
	bannerLabel.Text = text
	bannerLabel.TextColor3 = color or C.Gold
	bannerLabel.Visible = true
	bannerLabel.TextTransparency = 1
	TweenService:Create(bannerLabel, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	local stamp = os.clock()
	bannerLabel:SetAttribute("Stamp", stamp)
	task.delay(5, function()
		if bannerLabel:GetAttribute("Stamp") == stamp then
			bannerLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------- Fenster

local function closeWindow()
	if openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
	modal.Visible = false
	table.clear(refreshers)
end
UI.CloseWindow = closeWindow

local function window(title: string, width: number, height: number): (Frame, Frame)
	closeWindow()
	modal.Visible = true
	local frame = Theme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(width, height),
		Parent = modal,
	})
	-- Titelband in Purpur
	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.Crimson, Parent = frame })
	Theme.corner(header, 12)
	Theme.gradient(header, Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 160, 160))
	create("Frame", { Position = UDim2.new(0, 0, 1, -12), Size = UDim2.new(1, 0, 0, 12), BackgroundColor3 = C.Crimson, Parent = header })
	create("Frame", { Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.Gold, Parent = header })
	local titleLabel = label({ Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -80, 1, 0), Text = title, Font = Theme.Title, TextSize = 30, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	Theme.textStroke(titleLabel, 2)
	local close = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(40, 40), Text = "X", TextSize = 22, Color = C.CrimsonDark, Parent = header })
	close.Activated:Connect(closeWindow)
	local content = create("Frame", { Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -78), BackgroundTransparency = 1, Parent = frame })
	frame.Size = UDim2.fromOffset(width * 0.9, height * 0.9)
	TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(width, height) }):Play()
	openWindow = frame
	return frame, content
end

local function scrolling(parent: Instance, props): ScrollingFrame
	local defaults = {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}
	for key, value in props or {} do
		defaults[key] = value
	end
	return create("ScrollingFrame", defaults)
end

local function tabs(parent: Frame, names: { string }, build: (string, Frame) -> ())
	local bar = create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = parent })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = bar })
	local body = create("Frame", { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), BackgroundTransparency = 1, Parent = parent })
	local buttons = {}
	local function select(name: string)
		for other, b in buttons do
			b.BackgroundColor3 = if other == name then C.Gold else C.PanelLight
			b.TextColor3 = if other == name then C.Ink else C.Cream
		end
		body:ClearAllChildren()
		build(name, body)
	end
	for _, name in names do
		local b = button({ Size = UDim2.fromOffset(150, 38), Text = name, TextSize = 18, Color = C.PanelLight, Parent = bar })
		buttons[name] = b
		b.Activated:Connect(function()
			select(name)
		end)
	end
	select(names[1])
end

---------------------------------------------------------------- Team

local function sortedBeasts()
	local collection = UI.State.Collection
	local list = {}
	for uid, beast in collection.Beasts do
		table.insert(list, { Uid = uid, Beast = beast, Team = table.find(collection.Team, uid) })
	end
	table.sort(list, function(a, b)
		if (a.Team ~= nil) ~= (b.Team ~= nil) then
			return a.Team ~= nil
		end
		if a.Team and b.Team then
			return a.Team < b.Team
		end
		return a.Beast.Power > b.Beast.Power
	end)
	return list
end

local function setTeam(team: { string })
	remotes.SetTeam:FireServer(team)
end

local function makeLead(uid: string)
	local collection = UI.State.Collection
	local team = { uid }
	for _, other in collection.Team do
		if other ~= uid and #team < collection.TeamSize then
			table.insert(team, other)
		end
	end
	setTeam(team)
end

local selectedUid: string? = nil

function UI.OpenTeam()
	local collection = UI.State.Collection
	if not collection then
		return
	end
	local _, content = window("YOUR BEASTS", 860, 500)
	local listArea = create("Frame", { Size = UDim2.new(0.55, -8, 1, 0), BackgroundTransparency = 1, Parent = content })
	local info = label({ Size = UDim2.new(1, 0, 0, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted, Parent = listArea })
	local grid = scrolling(listArea, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30) })
	create("UIGridLayout", { CellSize = UDim2.fromOffset(148, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = grid })
	local detail = Theme.panel({ Position = UDim2.new(0.55, 8, 0, 0), Size = UDim2.new(0.45, -8, 1, 0), BackgroundColor3 = C.PanelDark, Parent = content })

	local releaseArmed = false
	local function drawDetail()
		detail:ClearAllChildren()
		Theme.corner(detail, 12)
		Theme.stroke(detail, C.Gold, 2, 0.15)
		local col = UI.State.Collection
		local beast = selectedUid and col.Beasts[selectedUid]
		if not beast then
			label({ Size = UDim2.fromScale(1, 1), Text = "Tap a beast to see it", TextColor3 = C.Muted, Parent = detail })
			return
		end
		local uid = selectedUid :: string
		local def = Config.BeastsById[beast.S]
		local rarity = Config.RaritiesByName[def.Rarity]
		local inTeam = table.find(col.Team, uid)
		Theme.viewport(beast.S, beast.L, beast.Sh, { Position = UDim2.fromOffset(10, 8), Size = UDim2.new(0.5, -10, 0, 150), Parent = detail })
		local nameLabel = label({ Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.new(0.5, -10, 0, 30), Text = (if beast.Sh then "✦ " else "") .. def.Name, Font = Theme.Title, TextSize = 26, TextScaled = true, TextColor3 = if beast.Sh then C.Prism else C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		Theme.textStroke(nameLabel, 1.5)
		label({ Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(0.5, -10, 0, 20), Text = `Lv {beast.L}  ·  {def.Rarity}`, TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		Theme.typeChip(def.Type, { Position = UDim2.new(0.5, 0, 0, 70), Parent = detail })
		local xpBack, xpFill = Theme.hpBar({ Position = UDim2.new(0.5, 0, 0, 100), Size = UDim2.new(0.5, -14, 0, 12), Parent = detail })
		xpFill.Size = UDim2.fromScale(math.clamp(beast.X / math.max(1, beast.Need), 0, 1), 1)
		xpFill.BackgroundColor3 = C.Blue
		label({ Position = UDim2.new(0.5, 0, 0, 114), Size = UDim2.new(0.5, -14, 0, 18), Text = `XP {Format.Number(beast.X)}/{Format.Number(beast.Need)}`, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = xpBack.Parent })
		local hpBack, hpFill = Theme.hpBar({ Position = UDim2.new(0.5, 0, 0, 136), Size = UDim2.new(0.5, -14, 0, 12), Parent = detail })
		Theme.setHp(hpFill, beast.Hp / beast.MaxHp)
		label({ Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.new(0.5, -14, 0, 18), Text = `HP {beast.Hp}/{beast.MaxHp}`, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = hpBack.Parent })

		local stats = label({ Position = UDim2.fromOffset(14, 176), Size = UDim2.new(1, -28, 0, 22), RichText = true, Text = `<font color="#F2C14E">ATK</font> {beast.Atk}   <font color="#F2C14E">DEF</font> {beast.Def}   <font color="#F2C14E">SPD</font> {beast.Spd}   <font color="#F2C14E">POWER</font> {beast.Power}`, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		stats.TextSize = 17
		local moves = {}
		for _, key in Config.MovesFor(beast.S, beast.L) do
			table.insert(moves, Config.MoveInfo(beast.S, key).Name)
		end
		label({ Position = UDim2.fromOffset(14, 200), Size = UDim2.new(1, -28, 0, 22), Text = "Moves: " .. table.concat(moves, ", "), TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		local evolveText = if def.Evolve then `Ascends into {Config.BeastsById[def.Evolve.To].Name} at Lv {def.Evolve.Level}` else "Final form"
		if not table.find(Config.MovesFor(beast.S, beast.L), "Ultimate") then
			evolveText ..= `  ·  Ultimate move at Lv {Config.UltimateLevel}`
		end
		label({ Position = UDim2.fromOffset(14, 222), Size = UDim2.new(1, -28, 0, 22), Text = evolveText, TextSize = 15, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })

		local actions = create("Frame", { Position = UDim2.fromOffset(12, 252), Size = UDim2.new(1, -24, 1, -262), BackgroundTransparency = 1, Parent = detail })
		create("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 44), CellPadding = UDim2.fromOffset(10, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions })
		local lead = button({ Text = if inTeam == 1 then "LEAD BEAST" else "MAKE LEAD", TextSize = 17, Color = C.Blue, LayoutOrder = 1, Parent = actions })
		lead.Activated:Connect(function()
			makeLead(uid)
		end)
		local teamButton = button({ Text = if inTeam then "REMOVE" else "ADD TO TEAM", TextSize = 17, Color = C.PanelLight, LayoutOrder = 2, Parent = actions })
		teamButton.Activated:Connect(function()
			local team = table.clone(col.Team)
			if inTeam then
				if #team > 1 then
					table.remove(team, inTeam)
				end
			elseif #team < col.TeamSize then
				table.insert(team, uid)
			else
				team[#team] = uid
			end
			setTeam(team)
		end)
		if def.Evolve then
			local ascend = priceButton(Config.DevProducts.EvoCrystal.PriceHint, { Text = `ASCEND NOW  R$ {Config.DevProducts.EvoCrystal.PriceHint}`, TextSize = 15, LayoutOrder = 3, Color = C.GoldDark, Parent = actions })
			ascend.Activated:Connect(function()
				makeLead(uid)
				task.wait(0.3)
				UI.Buy("Product", "EvoCrystal")
			end)
		end
		local snack = priceButton(Config.DevProducts.PowerSnack.PriceHint, { Text = `+5 LEVELS  R$ {Config.DevProducts.PowerSnack.PriceHint}`, TextSize = 15, LayoutOrder = 4, Parent = actions })
		snack.Activated:Connect(function()
			makeLead(uid)
			task.wait(0.3)
			UI.Buy("Product", "PowerSnack")
		end)
		local coins = 10 * beast.L * rarity.Index
		local release = button({ Text = `RELEASE (+{Format.Number(coins)})`, TextSize = 15, Color = C.CrimsonDark, LayoutOrder = 5, Parent = actions })
		release.Activated:Connect(function()
			if not releaseArmed then
				releaseArmed = true
				release.Text = "TAP AGAIN TO RELEASE"
				return
			end
			releaseArmed = false
			selectedUid = nil
			remotes.ReleaseBeast:FireServer(uid)
		end)
	end

	local function drawList()
		local col = UI.State.Collection
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local count = 0
		for order, item in sortedBeasts() do
			count += 1
			local beast = item.Beast
			local def = Config.BeastsById[beast.S]
			local card = create("TextButton", { BackgroundColor3 = if item.Uid == selectedUid then C.PanelLight else C.PanelDark, AutoButtonColor = true, Text = "", LayoutOrder = order, Parent = grid })
			Theme.corner(card, 10)
			Theme.stroke(card, if item.Team then C.Gold elseif beast.Sh then C.Prism else C.PanelLight, 2)
			Theme.beastIcon(beast.S, beast.Sh, { Position = UDim2.fromOffset(8, 8), Parent = card })
			label({ Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -62, 0, 22), Text = def.Name, Font = Theme.Heavy, TextSize = 16, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if beast.Sh then C.Prism else C.Cream, Parent = card })
			label({ Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -62, 0, 18), Text = `Lv {beast.L}`, TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			Theme.typeChip(def.Type, { Position = UDim2.fromOffset(8, 60), Size = UDim2.fromOffset(56, 18), TextSize = 11, Parent = card })
			local _, fill = Theme.hpBar({ Position = UDim2.fromOffset(70, 63), Size = UDim2.new(1, -78, 0, 10), Parent = card })
			Theme.setHp(fill, beast.Hp / beast.MaxHp)
			if item.Team then
				local badge = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 30), Size = UDim2.fromOffset(28, 20), Text = `#{item.Team}`, Font = Theme.Title, TextSize = 16, BackgroundTransparency = 0, BackgroundColor3 = C.Gold, TextColor3 = C.Ink, Parent = card })
				Theme.corner(badge, 6)
			end
			card.Activated:Connect(function()
				selectedUid = item.Uid
				releaseArmed = false
				drawList()
				drawDetail()
			end)
		end
		info.Text = `Team {#col.Team}/{col.TeamSize}  ·  Storage {count}/{col.Capacity}` .. (if hasPass("BigTeam") then "" else "  ·  Big Team pass: 5 in battle!")
	end

	if not selectedUid or not collection.Beasts[selectedUid] then
		selectedUid = collection.Team[1]
	end
	drawList()
	drawDetail()
	table.insert(refreshers, function()
		drawList()
		drawDetail()
	end)
end

---------------------------------------------------------------- Shop (Robux)

local function shopCard(parent: Instance, order: number, title: string, description: string, price: number, owned: boolean, onBuy: () -> (), accent: Color3?)
	local card = Theme.panel({ BackgroundColor3 = C.PanelDark, LayoutOrder = order, Parent = parent })
	if accent then
		create("Frame", { Size = UDim2.new(0, 6, 1, -16), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = accent, Parent = card })
	end
	local titleLabel = label({ Position = UDim2.fromOffset(22, 10), Size = UDim2.new(1, -30, 0, 26), Text = title, Font = Theme.Title, TextSize = 22, TextScaled = true, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	Theme.textStroke(titleLabel, 1.5)
	label({ Position = UDim2.fromOffset(22, 38), Size = UDim2.new(1, -30, 0, 44), Text = description, TextSize = 15, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
	local buy = priceButton(price, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -24, 0, 38), Text = if owned then "OWNED" else `R$ {price}`, Color = if owned then C.PanelLight else C.Green, Parent = card })
	buy.AutoButtonColor = not owned
	buy.Activated:Connect(function()
		if not owned then
			onBuy()
		end
	end)
	return card
end

local function gridIn(body: Frame, cell: Vector2): ScrollingFrame
	local scroll = scrolling(body)
	create("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = scroll })
	return scroll
end

local PRODUCT_GROUPS = {
	BOOSTS = { "MasterOrb1", "MasterOrb5", "Boost", "PowerSnack", "EvoCrystal", "SkipChampion", "FullHeal", "ServerShiny", "Storage" },
	COINS = { "CoinsSmall", "CoinsMedium", "CoinsLarge" },
}

function UI.OpenShop(startTab: string?)
	local _, content = window("ROYAL SHOP", 860, 500)
	local names = { "PASSES", "BOOSTS", "COINS", "CODES" }
	if startTab then
		table.remove(names, table.find(names, startTab) :: number)
		table.insert(names, 1, startTab)
	end
	tabs(content, names, function(name, body)
		if name == "PASSES" then
			local scroll = gridIn(body, Vector2.new(196, 150))
			local list = {}
			for key, pass in Config.GamePasses do
				if not (pass.AffectsRandom and restricted()) then
					table.insert(list, { Key = key, Pass = pass })
				end
			end
			table.sort(list, function(a, b)
				return a.Pass.Order < b.Pass.Order
			end)
			for order, item in list do
				shopCard(scroll, order, item.Pass.Name, item.Pass.Description, item.Pass.PriceHint, hasPass(item.Key), function()
					UI.Buy("Pass", item.Key)
				end, C.Gold)
			end
		elseif name == "CODES" then
			local box = create("TextBox", { Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(360, 50), BackgroundColor3 = C.PanelDark, PlaceholderText = "Enter code", Text = "", Font = Theme.Heavy, TextSize = 22, TextColor3 = C.Cream, PlaceholderColor3 = C.Muted, ClearTextOnFocus = false, Parent = body })
			Theme.corner(box, 10)
			Theme.stroke(box, C.Gold, 2)
			local redeem = button({ Position = UDim2.fromOffset(380, 20), Size = UDim2.fromOffset(160, 50), Text = "REDEEM", Parent = body })
			redeem.Activated:Connect(function()
				remotes.RedeemCode:FireServer(box.Text)
				box.Text = ""
			end)
			label({ Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 60), Text = "New codes come with every update. Follow the game and like it to get them first!", TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
		else
			local scroll = gridIn(body, Vector2.new(196, 150))
			local order = 0
			if name == "BOOSTS" and not player:GetAttribute("GotStarter") then
				order += 1
				local starter = Config.DevProducts.StarterPack
				shopCard(scroll, order, "STARTER PACK", starter.Description, starter.PriceHint, false, function()
					UI.Buy("Product", "StarterPack")
				end, C.Crimson)
			end
			for _, key in PRODUCT_GROUPS[name] do
				local product = Config.DevProducts[key]
				if not (product.AffectsRandom and restricted()) then
					order += 1
					shopCard(scroll, order, product.Name, product.Description, product.PriceHint, false, function()
						UI.Buy("Product", key)
					end, if key:find("Orb") then Config.Items.MasterOrb.Color else C.Blue)
				end
			end
		end
	end)
end

---------------------------------------------------------------- Orb-Laden (Muenzen)

function UI.OpenItems()
	local _, content = window("ORB SHOP", 760, 430)
	local scroll = gridIn(content, Vector2.new(170, 330))
	local function draw()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local items = UI.State.Collection and UI.State.Collection.Items or {}
		local list = {}
		for key, item in Config.Items do
			table.insert(list, { Key = key, Item = item })
		end
		table.sort(list, function(a, b)
			return a.Item.Order < b.Item.Order
		end)
		for _, entry in list do
			local item = entry.Item
			local card = Theme.panel({ BackgroundColor3 = C.PanelDark, LayoutOrder = item.Order, Parent = scroll })
			local orb = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = item.Color, Parent = card })
			Theme.corner(orb, 100)
			Theme.stroke(orb, C.Ink, 3)
			Theme.gradient(orb, Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140))
			if item.Catch then
				create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = C.Ink, Parent = orb })
			end
			label({ Position = UDim2.fromOffset(8, 92), Size = UDim2.new(1, -16, 0, 26), Text = item.Name, Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, Parent = card })
			label({ Position = UDim2.fromOffset(8, 120), Size = UDim2.new(1, -16, 0, 40), Text = item.Description, TextSize = 14, TextColor3 = C.Cream, Parent = card })
			label({ Position = UDim2.fromOffset(8, 162), Size = UDim2.new(1, -16, 0, 22), Text = `You have {items[entry.Key] or 0}`, TextSize = 15, TextColor3 = C.Muted, Parent = card })
			if item.Price > 0 then
				for i, amount in { 1, 10 } do
					local buy = button({ Position = UDim2.new(0, 10, 0, 194 + (i - 1) * 52), Size = UDim2.new(1, -20, 0, 44), Text = `x{amount}  ·  {Format.Number(item.Price * amount)} coins`, TextSize = 15, Color = C.Crimson, Parent = card })
					buy.Activated:Connect(function()
						remotes.BuyItem:FireServer(entry.Key, amount)
					end)
				end
			else
				for i, key in { "MasterOrb1", "MasterOrb5" } do
					local product = Config.DevProducts[key]
					local buy = priceButton(product.PriceHint, { Position = UDim2.new(0, 10, 0, 194 + (i - 1) * 52), Size = UDim2.new(1, -20, 0, 44), Text = `x{product.Amount}  ·  R$ {product.PriceHint}`, TextSize = 15, Parent = card })
					buy.Activated:Connect(function()
						UI.Buy("Product", key)
					end)
				end
			end
		end
	end
	draw()
	table.insert(refreshers, draw)
end

---------------------------------------------------------------- Arena

function UI.OpenArena()
	local _, content = window("THE COLOSSEUM", 880, 500)
	local scroll = scrolling(content, { Size = UDim2.new(1, 0, 1, -96) })
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	create("UIPadding", { PaddingRight = UDim.new(0, 10), Parent = scroll })
	local crests = player:GetAttribute("Crests") or 0
	for index, champion in Config.Champions do
		local beaten = index <= crests
		local isNext = index == crests + 1
		local row = Theme.panel({ Size = UDim2.new(1, 0, 0, 74), BackgroundColor3 = if isNext then C.PanelLight else C.PanelDark, LayoutOrder = index, Parent = scroll })
		local shield = create("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = if beaten then C.Gold else C.PanelDark, Parent = row })
		Theme.corner(shield, 14)
		Theme.stroke(shield, C.Gold, 2)
		label({ Size = UDim2.fromScale(1, 1), Text = tostring(index), Font = Theme.Title, TextSize = 28, TextColor3 = if beaten then C.Ink else C.Gold, Parent = shield })
		local nameLabel = label({ Position = UDim2.fromOffset(76, 8), Size = UDim2.new(0.42, 0, 0, 28), Text = champion.Name, Font = Theme.Title, TextSize = 24, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		Theme.textStroke(nameLabel, 1.5)
		local team = {}
		for _, member in champion.Team do
			table.insert(team, `{Config.BeastsById[member[1]].Name} {member[2]}`)
		end
		label({ Position = UDim2.fromOffset(76, 38), Size = UDim2.new(0.5, 0, 0, 30), Text = `{champion.Title}  ·  {table.concat(team, ", ")}`, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -200, 0.5, 0), Size = UDim2.fromOffset(150, 30), Text = `{Format.Number(if beaten then math.floor(champion.Coins * Config.ChampionRematch) else champion.Coins)} coins`, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		if beaten or isNext then
			local fight = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(170, 46), Text = if beaten then "REMATCH" else "CHALLENGE", Color = if beaten then C.PanelLight else C.Crimson, Parent = row })
			fight.Activated:Connect(function()
				closeWindow()
				remotes.ArenaChallenge:FireServer(index)
			end)
		else
			label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(170, 46), Text = "LOCKED", Font = Theme.Title, TextSize = 20, TextColor3 = C.Muted, Parent = row })
		end
	end
	-- Gauntlet und Champion Pass
	local bottom = create("Frame", { Position = UDim2.new(0, 0, 1, -86), Size = UDim2.new(1, 0, 0, 86), BackgroundTransparency = 1, Parent = content })
	local gauntlet = Theme.panel({ Size = UDim2.new(0.62, -6, 1, 0), BackgroundColor3 = C.CrimsonDark, Parent = bottom })
	local gTitle = label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.6, 0, 0, 32), Text = "ENDLESS GAUNTLET", Font = Theme.Title, TextSize = 26, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = gauntlet })
	Theme.textStroke(gTitle, 1.5)
	label({ Position = UDim2.fromOffset(16, 42), Size = UDim2.new(0.6, 0, 0, 34), Text = `Best: {player:GetAttribute("BestWave") or 0} waves · coins every wave`, TextSize = 15, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = gauntlet })
	local start = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 52), Text = "START", TextSize = 24, Color = C.Crimson, Parent = gauntlet })
	start.Activated:Connect(function()
		closeWindow()
		remotes.ArenaChallenge:FireServer("Gauntlet")
	end)
	local pass = Theme.panel({ Position = UDim2.new(0.62, 6, 0, 0), Size = UDim2.new(0.38, -6, 1, 0), BackgroundColor3 = C.PanelDark, Parent = bottom })
	label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Text = "Stuck on a champion?", TextSize = 16, TextColor3 = C.Cream, Parent = pass })
	local skip = priceButton(Config.DevProducts.SkipChampion.PriceHint, { Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 42), Text = `CHAMPION PASS  R$ {Config.DevProducts.SkipChampion.PriceHint}`, TextSize = 16, Parent = pass })
	skip.Activated:Connect(function()
		UI.Buy("Product", "SkipChampion")
	end)
end

---------------------------------------------------------------- Starter-Wahl

function UI.ShowStarter()
	closeWindow()
	local screen = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, ZIndex = 20, Parent = root })
	local title = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(800, 56), Text = "CHOOSE YOUR FIRST BEAST", Font = Theme.Title, TextSize = 46, TextColor3 = C.Gold, ZIndex = 21, Parent = screen })
	Theme.textStroke(title, 3)
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Size = UDim2.fromOffset(800, 26), Text = "Your partner for the Colosseum. Choose wisely - Fire beats Leaf, Leaf beats Water, Water beats Fire!", TextSize = 18, ZIndex = 21, Parent = screen })
	local row = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(840, 360), BackgroundTransparency = 1, ZIndex = 21, Parent = screen })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20), Parent = row })
	for _, beastId in Config.Starters do
		local def = Config.BeastsById[beastId]
		local typeColor = Config.Types[def.Type].Color
		local card = Theme.panel({ Size = UDim2.fromOffset(260, 350), BackgroundColor3 = C.Panel, ZIndex = 21, Parent = row })
		local glow = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(200, 200), BackgroundColor3 = typeColor, BackgroundTransparency = 0.75, ZIndex = 21, Parent = card })
		Theme.corner(glow, 200)
		Theme.viewport(beastId, 5, false, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(220, 210), ZIndex = 22, Parent = card })
		local nameLabel = label({ Position = UDim2.fromOffset(0, 222), Size = UDim2.new(1, 0, 0, 34), Text = def.Name, Font = Theme.Title, TextSize = 30, TextColor3 = C.Cream, ZIndex = 22, Parent = card })
		Theme.textStroke(nameLabel, 2)
		Theme.typeChip(def.Type, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 258), ZIndex = 22, Parent = card })
		local choose = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -30, 0, 46), Text = "CHOOSE", TextSize = 24, ZIndex = 22, Parent = card })
		choose.Activated:Connect(function()
			remotes.PickStarter:FireServer(beastId)
			screen:Destroy()
		end)
	end
end

---------------------------------------------------------------- Kaufangebote und Duelle

local offerCard: Frame? = nil
function UI.ShowOffer(key: string, text: string)
	local product = Config.DevProducts[key]
	if not product then
		return
	end
	if offerCard then
		offerCard:Destroy()
	end
	local card = Theme.panel({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.45, 0), Size = UDim2.fromOffset(290, 190), BackgroundColor3 = C.Panel, ZIndex = 15, Parent = root })
	offerCard = card
	local ribbon = create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.Crimson, ZIndex = 15, Parent = card })
	Theme.corner(ribbon, 12)
	label({ Size = UDim2.fromScale(1, 1), Text = "SPECIAL OFFER", Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, ZIndex = 16, Parent = ribbon })
	label({ Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 26), Text = product.Name, Font = Theme.Title, TextSize = 22, TextColor3 = C.Cream, ZIndex = 16, Parent = card })
	label({ Position = UDim2.fromOffset(14, 68), Size = UDim2.new(1, -28, 0, 52), Text = text, TextSize = 15, TextColor3 = C.Muted, ZIndex = 16, Parent = card })
	local buy = priceButton(product.PriceHint, { Position = UDim2.new(0, 14, 1, -58), Size = UDim2.new(0.62, -14, 0, 44), TextSize = 20, ZIndex = 16, Parent = card })
	local no = button({ Position = UDim2.new(0.62, 8, 1, -58), Size = UDim2.new(0.38, -22, 0, 44), Text = "NO", TextSize = 18, Color = C.PanelLight, ZIndex = 16, Parent = card })
	buy.Activated:Connect(function()
		UI.Buy("Product", key)
		card:Destroy()
	end)
	no.Activated:Connect(function()
		card:Destroy()
	end)
	card.Position = UDim2.new(1, 320, 0.45, 0)
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(1, -16, 0.45, 0) }):Play()
	task.delay(14, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

function UI.ShowDuelInvite(from: Player)
	local card = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(380, 120), ZIndex = 15, Parent = root })
	label({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 30), Text = `{from.DisplayName} challenges you!`, Font = Theme.Title, TextSize = 24, TextColor3 = C.Gold, ZIndex = 16, Parent = card })
	local accept = button({ Position = UDim2.new(0, 12, 1, -56), Size = UDim2.new(0.5, -18, 0, 44), Text = "FIGHT!", Color = C.Crimson, ZIndex = 16, Parent = card })
	local decline = button({ Position = UDim2.new(0.5, 6, 1, -56), Size = UDim2.new(0.5, -18, 0, 44), Text = "DECLINE", Color = C.PanelLight, ZIndex = 16, Parent = card })
	accept.Activated:Connect(function()
		remotes.DuelAnswer:FireServer(from, true)
		card:Destroy()
	end)
	decline.Activated:Connect(function()
		remotes.DuelAnswer:FireServer(from, false)
		card:Destroy()
	end)
	task.delay(Config.DuelInviteSeconds, function()
		if card.Parent then
			card:Destroy()
		end
	end)
end

---------------------------------------------------------------- Anzeige oben, Menue, Team-Leiste

local teamBar: Frame
local function drawTeamBar()
	for _, child in teamBar:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local collection = UI.State.Collection
	if not collection then
		return
	end
	for index, uid in collection.Team do
		local beast = collection.Beasts[uid]
		if beast then
			local def = Config.BeastsById[beast.S]
			local card = create("TextButton", { Size = UDim2.fromOffset(150, 54), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = true, LayoutOrder = index, Parent = teamBar })
			Theme.corner(card, 10)
			Theme.stroke(card, if index == 1 then C.Gold else C.PanelLight, 2)
			Theme.beastIcon(beast.S, beast.Sh, { Position = UDim2.fromOffset(6, 7), Size = UDim2.fromOffset(40, 40), Parent = card })
			label({ Position = UDim2.fromOffset(52, 4), Size = UDim2.new(1, -56, 0, 20), Text = def.Name, Font = Theme.Heavy, TextSize = 15, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			label({ Position = UDim2.fromOffset(52, 22), Size = UDim2.new(1, -56, 0, 14), Text = `Lv {beast.L}`, TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local _, fill = Theme.hpBar({ Position = UDim2.fromOffset(52, 39), Size = UDim2.new(1, -60, 0, 8), Parent = card })
			Theme.setHp(fill, beast.Hp / beast.MaxHp)
			card.Activated:Connect(UI.OpenTeam)
		end
	end
end

local function pill(position: UDim2, width: number, iconColor: Color3, iconText: string): TextLabel
	local frame = create("Frame", { Position = position, Size = UDim2.fromOffset(width, 44), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.05, Parent = hud })
	Theme.corner(frame, 22)
	Theme.stroke(frame, C.Gold, 2)
	local icon = create("Frame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = iconColor, Parent = frame })
	Theme.corner(icon, 18)
	Theme.stroke(icon, C.Ink, 2)
	label({ Size = UDim2.fromScale(1, 1), Text = iconText, Font = Theme.Title, TextSize = 20, TextColor3 = C.Ink, Parent = icon })
	local value = label({ Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -56, 1, 0), Text = "0", Font = Theme.Title, TextSize = 24, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, Parent = frame })
	Theme.textStroke(value, 1.5)
	return value
end

local function menuButton(icon: string, text: string, color: Color3, order: number): (TextButton, TextLabel)
	local b = button({ Size = UDim2.fromOffset(74, 74), Color = color, LayoutOrder = order, Parent = hud:FindFirstChild("Menu") })
	label({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 40), Text = icon, TextSize = 32, Parent = b })
	local textLabel = label({ Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 22), Text = text, Font = Theme.Title, TextSize = 15, TextColor3 = C.Cream, Parent = b })
	Theme.textStroke(textLabel, 1.2)
	local badge = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = C.Red, Text = "!", Font = Theme.Title, TextSize = 16, Visible = false, Parent = b })
	Theme.corner(badge, 12)
	return b, badge
end

local function chip(order: number, color: Color3): TextLabel
	local c = label({ Size = UDim2.fromOffset(0, 32), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.05, BackgroundColor3 = C.Panel, Text = "", Font = Theme.Heavy, TextSize = 16, TextColor3 = color, TextWrapped = false, LayoutOrder = order, Visible = false, Parent = hud:FindFirstChild("Chips") })
	Theme.corner(c, 16)
	Theme.stroke(c, color, 2)
	create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = c })
	return c
end

function UI.SetHudVisible(visible: boolean)
	hud.Visible = visible
	if not visible then
		closeWindow()
	end
end

function UI.SetCollection(collection)
	UI.State.Collection = collection
	drawTeamBar()
	for _, refresh in refreshers do
		task.spawn(refresh)
	end
end

function UI.Init()
	gui = create("ScreenGui", { Name = "Main", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, Parent = player:WaitForChild("PlayerGui") })
	root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local scale = create("UIScale", { Parent = root })
	local function rescale()
		local camera = workspace.CurrentCamera
		local size = camera.ViewportSize
		local s = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.55, 1.3)
		scale.Scale = s
		root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	hud = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = root })
	modal = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45, AutoButtonColor = false, Text = "", Visible = false, ZIndex = 5, Parent = root })
	-- Hintergrund antippen schliesst das Fenster
	;(modal :: any).Activated:Connect(function()
		closeWindow()
	end)

	toastList = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(600, 200), BackgroundTransparency = 1, ZIndex = 30, Parent = root })
	create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = toastList })
	bannerLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(760, 40), Text = "", Font = Theme.Title, TextSize = 26, TextScaled = true, Visible = false, ZIndex = 30, Parent = root })
	Theme.textStroke(bannerLabel, 2.5)

	-- Muenzen und Wappen
	local coins = pill(UDim2.fromOffset(14, 14), 200, C.Gold, "C")
	local crests = pill(UDim2.fromOffset(222, 14), 130, C.Crimson, "")
	local crestIcon = (crests.Parent :: Frame):FindFirstChildOfClass("Frame") :: Frame
	label({ Size = UDim2.fromScale(1, 1), Text = "★", TextSize = 22, TextColor3 = C.Gold, Parent = crestIcon })
	local chips = create("Frame", { Name = "Chips", Position = UDim2.fromOffset(362, 20), Size = UDim2.fromOffset(600, 32), BackgroundTransparency = 1, Parent = hud })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
	local multChip = chip(1, C.Gold)
	local boostChip = chip(2, C.Green)
	local stormChip = chip(3, C.Prism)

	local menu = create("Frame", { Name = "Menu", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 10), Size = UDim2.fromOffset(74, 520), BackgroundTransparency = 1, Parent = hud })
	create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = menu })
	local teamButton = menuButton("🐾", "TEAM", C.Blue, 1)
	local shopButton, shopBadge = menuButton("💎", "SHOP", C.GoldDark, 2)
	local orbButton = menuButton("🔮", "ORBS", C.Crimson, 3)
	local arenaButton = menuButton("🏛️", "ARENA", C.CrimsonDark, 4)
	local dailyButton, dailyBadge = menuButton("🎁", "DAILY", C.Green, 5)
	local adButton, adBadge = menuButton("🎬", "FREE", Color3.fromRGB(200, 110, 40), 6)
	adButton.Visible = false
	adBadge.Text = "+"
	adBadge.BackgroundColor3 = C.Gold
	adBadge.TextColor3 = C.Ink
	adBadge.Visible = true
	shopBadge.Text = "%"
	shopBadge.BackgroundColor3 = C.Gold
	shopBadge.TextColor3 = C.Ink

	teamButton.Activated:Connect(UI.OpenTeam)
	shopButton.Activated:Connect(function()
		UI.OpenShop()
	end)
	orbButton.Activated:Connect(UI.OpenItems)
	arenaButton.Activated:Connect(UI.OpenArena)
	dailyButton.Activated:Connect(function()
		remotes.ClaimDaily:FireServer()
	end)
	adButton.Activated:Connect(function()
		adButton.Visible = false
		remotes.WatchAd:FireServer()
	end)
	-- Freiwillige Video-Werbung: Knopf nur zeigen, wenn Roblox gerade eine Werbung bereit hat
	task.spawn(function()
		while gui.Parent do
			local ok, result = pcall(AdService.GetAdAvailabilityNowAsync, AdService, Enum.AdFormat.RewardedVideo)
			adButton.Visible = ok and result and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
			task.wait(30)
		end
	end)

	teamBar = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(800, 54), BackgroundTransparency = 1, Parent = hud })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = teamBar })

	local function refreshStats()
		coins.Text = Format.Number(player:GetAttribute("Coins") or 0)
		crests.Text = `{player:GetAttribute("Crests") or 0}/{#Config.Champions}`
		dailyBadge.Visible = player:GetAttribute("DailyReady") == true
		shopBadge.Visible = not player:GetAttribute("GotStarter")
		local mult = player:GetAttribute("CoinMultiplier") or 1
		multChip.Visible = mult > 1
		multChip.Text = `x{mult} COINS`
	end
	for _, attribute in { "Coins", "Crests", "DailyReady", "GotStarter", "CoinMultiplier" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshStats)
	end
	refreshStats()

	task.spawn(function()
		while gui.Parent do
			local boostLeft = (player:GetAttribute("BoostUntil") or 0) - os.time()
			boostChip.Visible = boostLeft > 0
			boostChip.Text = `2x BOOST {Format.Time(boostLeft)}`
			local stormLeft = (workspace:GetAttribute("ShinyUntil") or 0) - workspace:GetServerTimeNow()
			stormChip.Visible = stormLeft > 0
			stormChip.Text = `PRISMATIC STORM {Format.Time(stormLeft)}`
			task.wait(1)
		end
	end)
end

return UI
