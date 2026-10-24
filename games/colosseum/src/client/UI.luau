-- Benutzeroberflaeche ausserhalb der Kaempfe: Anzeige mit Ziel und Orden, Menue, Team und Box mit Attacken,
-- Beutel, Laden, Bestiarium, Karte zum Fliegen, Kampf-Menue (Gauntlet, Revanchen), Robux-Shop,
-- Starter-Wahl, Entwicklungen, neue Attacken, Orden-Feier, Ruhmeshalle, Meldungen und Kaufangebote.
-- Alles skaliert per UIScale, damit es auf dem Handy gut lesbar ist.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local AdService = game:GetService("AdService")

local Config = require(ReplicatedStorage.Shared.Config)
local Beasts = require(ReplicatedStorage.Shared.Beasts)
local Story = require(ReplicatedStorage.Shared.Story)
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
local listeners = {} -- andere Module, die bei neuer Sammlung informiert werden
local sceneCount = 0 -- laufende Szenen (Entwicklung, Orden ...), Gespraeche warten darauf

---------------------------------------------------------------- Hilfen

local function restricted(): boolean
	return player:GetAttribute("RandomRestricted") == true
end

local function hasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function UI.SceneBusy(): boolean
	return sceneCount > 0
end

function UI.Subscribe(fn: (any) -> ())
	table.insert(listeners, fn)
	if UI.State.Collection then
		task.spawn(fn, UI.State.Collection)
	end
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

local function typeColor(typeName: string): Color3
	return Config.Types[typeName].Color
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
		ZIndex = 6,
		Parent = root,
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

local function tabs(parent: Frame, names: { string }, build: (string, Frame) -> (), start: string?)
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
	select(start or names[1])
	return select
end

local function gridIn(body: Frame, cell: Vector2): ScrollingFrame
	local scroll = scrolling(body)
	create("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = scroll })
	return scroll
end

-- Kleine Auswahl-Liste ueber einem Fenster
local function chooser(title: string, entries: { { Text: string, Sub: string?, Color: Color3?, Disabled: boolean?, OnPick: () -> () } })
	local frame = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, math.min(440, 70 + #entries * 54)), ZIndex = 9, Parent = root })
	label({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -70, 0, 36), Text = title, Font = Theme.Title, TextSize = 22, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = frame })
	local close = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(34, 32), Text = "X", TextSize = 18, Color = C.CrimsonDark, ZIndex = 9, Parent = frame })
	close.Activated:Connect(function()
		frame:Destroy()
	end)
	local list = scrolling(frame, { Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -58), ZIndex = 9 })
	create("UIListLayout", { Padding = UDim.new(0, 6), Parent = list })
	for _, entry in entries do
		local b = button({ Size = UDim2.new(1, -8, 0, 48), Text = "", Color = if entry.Disabled then C.PanelLight else (entry.Color or C.Crimson), ZIndex = 9, Parent = list })
		label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.55, 0, 1, 0), Text = entry.Text, Font = Theme.Title, TextSize = 18, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9, Parent = b })
		label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.new(0.45, -12, 1, 0), Text = entry.Sub or "", TextSize = 14, TextScaled = true, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 9, Parent = b })
		b.Activated:Connect(function()
			if not entry.Disabled then
				frame:Destroy()
				entry.OnPick()
			end
		end)
	end
	return frame
end

local function teamChooser(title: string, onPick: (string) -> (), filter: ((any) -> boolean)?)
	local collection = UI.State.Collection
	local entries = {}
	for _, uid in collection.Team do
		local beast = collection.Beasts[uid]
		if beast then
			local def = Config.BeastsById[beast.S]
			local ok = if filter then filter(beast) else true
			table.insert(entries, {
				Text = `{def.Name}  Lv{beast.L}`,
				Sub = (if beast.Hp <= 0 then "FNT  " elseif beast.St then Config.Statuses[beast.St].Name .. "  " else "") .. `{beast.Hp}/{beast.MaxHp} HP`,
				Color = typeColor(def.Type):Lerp(C.Ink, 0.45),
				Disabled = not ok,
				OnPick = function()
					onPick(uid)
				end,
			})
		end
	end
	chooser(title, entries)
end

---------------------------------------------------------------- Team und Box

local function beastSort(a, b)
	return a.Beast.Power > b.Beast.Power
end

local function setTeam(team: { string })
	remotes.SetTeam:FireServer(team)
end

local function makeLead(uid: string)
	local collection = UI.State.Collection
	local team = { uid }
	for _, other in collection.Team do
		if other ~= uid then
			table.insert(team, other)
		end
	end
	setTeam(team)
end

local function moveRow(parent: Instance, move, order: number, onTap: (() -> ())?)
	local row = create("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = typeColor(move.Type):Lerp(C.Ink, 0.55), AutoButtonColor = onTap ~= nil, Text = "", LayoutOrder = order, Parent = parent })
	Theme.corner(row, 8)
	Theme.stroke(row, typeColor(move.Type), 1.5)
	label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.5, 0, 1, 0), Text = move.Name, Font = Theme.Heavy, TextSize = 16, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0.5, -10, 1, 0), Text = `{move.Type:upper()} · {if move.Power > 0 then "PWR " .. move.Power else "STATUS"} · PP {move.PP}/{move.MaxPP}`, TextSize = 13, TextScaled = true, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
	if onTap then
		row.Activated:Connect(onTap)
	end
	return row
end

-- Andere Attacken, die die Bestie auf ihrem Level kann (zum Umlernen)
local function learnable(beast): { string }
	local known = {}
	for _, move in beast.Moves do
		known[move.Key] = true
	end
	local list = {}
	for _, entry in Beasts.Learnset(beast.S) do
		if entry[1] <= beast.L and not known[entry[2]] and not table.find(list, entry[2]) then
			table.insert(list, entry[2])
		end
	end
	return list
end

local selectedUid: string? = nil

function UI.OpenTeam(startTab: string?)
	local collection = UI.State.Collection
	if not collection then
		return
	end
	local _, content = window("YOUR BEASTS", 900, 520)
	local current = startTab or "TEAM"
	local listArea = create("Frame", { Position = UDim2.fromOffset(0, 50), Size = UDim2.new(0.52, -8, 1, -50), BackgroundTransparency = 1, Parent = content })
	local detail = Theme.panel({ Position = UDim2.new(0.52, 8, 0, 0), Size = UDim2.new(0.48, -8, 1, 0), BackgroundColor3 = C.PanelDark, Parent = content })
	local info = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 22), Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Muted, Parent = listArea })
	local grid = scrolling(listArea, { Size = UDim2.new(1, 0, 1, -26) })
	create("UIGridLayout", { CellSize = UDim2.fromOffset(148, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = grid })

	local releaseArmed = false
	local drawList, drawDetail

	drawDetail = function()
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
		local teamIndex = table.find(col.Team, uid)
		Theme.viewport(beast.S, beast.L, beast.Sh, { Position = UDim2.fromOffset(6, 6), Size = UDim2.new(0.42, -6, 0, 130), Parent = detail })
		local nameLabel = label({ Position = UDim2.new(0.42, 4, 0, 8), Size = UDim2.new(0.58, -14, 0, 30), Text = (if beast.Sh then "✦ " else "") .. def.Name, Font = Theme.Title, TextSize = 26, TextScaled = true, TextColor3 = if beast.Sh then C.Prism else C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		Theme.textStroke(nameLabel, 1.5)
		label({ Position = UDim2.new(0.42, 4, 0, 38), Size = UDim2.new(0.58, -14, 0, 20), Text = `No.{string.format("%03d", def.Number)}  ·  Lv {beast.L}  ·  {def.Rarity}`, TextSize = 15, TextColor3 = rarity.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		local chips = create("Frame", { Position = UDim2.new(0.42, 4, 0, 60), Size = UDim2.new(0.58, -14, 0, 20), BackgroundTransparency = 1, Parent = detail })
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = chips })
		Theme.typeChip(def.Type, { Parent = chips })
		if def.Type2 then
			Theme.typeChip(def.Type2, { Parent = chips })
		end
		if beast.St then
			local status = Config.Statuses[beast.St]
			label({ Size = UDim2.fromOffset(44, 20), BackgroundTransparency = 0, BackgroundColor3 = status.Color, Text = status.Name, Font = Theme.Heavy, TextSize = 12, TextColor3 = C.Ink, Parent = chips })
		end
		local _, hpFill = Theme.hpBar({ Position = UDim2.new(0.42, 4, 0, 88), Size = UDim2.new(0.58, -18, 0, 12), Parent = detail })
		Theme.setHp(hpFill, beast.Hp / beast.MaxHp)
		label({ Position = UDim2.new(0.42, 4, 0, 100), Size = UDim2.new(0.58, -18, 0, 16), Text = `HP {beast.Hp}/{beast.MaxHp}`, TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		local _, xpFill = Theme.hpBar({ Position = UDim2.new(0.42, 4, 0, 118), Size = UDim2.new(0.58, -18, 0, 8), Parent = detail })
		xpFill.Size = UDim2.fromScale(math.clamp(beast.X / math.max(1, beast.Need), 0, 1), 1)
		xpFill.BackgroundColor3 = Color3.fromRGB(90, 180, 255)
		local stats = label({ Position = UDim2.fromOffset(12, 138), Size = UDim2.new(1, -24, 0, 20), RichText = true, Text = `<font color="#F2C14E">ATK</font> {beast.Atk}   <font color="#F2C14E">DEF</font> {beast.Def}   <font color="#F2C14E">SPD</font> {beast.Spd}   <font color="#F2C14E">EXP</font> {Format.Number(beast.X)}/{Format.Number(beast.Need)}`, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })
		stats.TextScaled = true
		local evolveText = if def.Evolve then `Evolves into {Config.BeastsById[def.Evolve.To].Name} at Lv {def.Evolve.Level}` else "Final form"
		label({ Position = UDim2.fromOffset(12, 158), Size = UDim2.new(1, -24, 0, 18), Text = evolveText, TextSize = 14, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = detail })

		-- Attacken: antippen zum Umlernen
		local moves = create("Frame", { Position = UDim2.fromOffset(12, 180), Size = UDim2.new(1, -24, 0, 156), BackgroundTransparency = 1, Parent = detail })
		create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = moves })
		for slot = 1, Config.MaxMoves do
			local move = beast.Moves[slot]
			local function relearn()
				local options = learnable(beast)
				if #options == 0 then
					UI.Toast("No other moves to learn yet. Level up to learn more!", C.Muted)
					return
				end
				local entries = {}
				for _, key in options do
					local m = Config.Moves[key]
					table.insert(entries, { Text = m.Name, Sub = `{m.Type:upper()} · {if m.Power > 0 then "PWR " .. m.Power else "STATUS"} · PP {m.PP}`, Color = typeColor(m.Type):Lerp(C.Ink, 0.45), OnPick = function()
						remotes.SetMove:FireServer(uid, math.min(slot, #beast.Moves + 1), key)
					end })
				end
				chooser(if move then `REPLACE {move.Name:upper()}` else "LEARN A MOVE", entries)
			end
			if move then
				moveRow(moves, move, slot, relearn)
			else
				local empty = create("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.Panel, Text = "+ empty slot", Font = Theme.Body, TextSize = 15, TextColor3 = C.Muted, LayoutOrder = slot, Parent = moves })
				Theme.corner(empty, 8)
				empty.Activated:Connect(relearn)
			end
		end

		local actions = create("Frame", { Position = UDim2.new(0, 12, 1, -102), Size = UDim2.new(1, -24, 0, 92), BackgroundTransparency = 1, Parent = detail })
		create("UIGridLayout", { CellSize = UDim2.new(1 / 3, -6, 0, 42), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = actions })
		local lead = button({ Text = if teamIndex == 1 then "LEAD" else "MAKE LEAD", TextSize = 15, Color = C.Blue, LayoutOrder = 1, Parent = actions })
		lead.Activated:Connect(function()
			if not teamIndex then
				remotes.MoveBeast:FireServer(uid, "Team")
				task.wait(0.3)
			end
			makeLead(uid)
		end)
		local swap = button({ Text = if teamIndex then "TO BOX" else "TO TEAM", TextSize = 15, Color = C.PanelLight, LayoutOrder = 2, Parent = actions })
		swap.Activated:Connect(function()
			remotes.MoveBeast:FireServer(uid, if teamIndex then "Box" else "Team")
		end)
		local useItem = button({ Text = "USE ITEM", TextSize = 15, Color = C.Green, LayoutOrder = 3, Parent = actions })
		useItem.Activated:Connect(function()
			local items = UI.State.Collection.Items
			local entries = {}
			for _, key in { "Potion", "SuperPotion", "HyperPotion", "FullCure", "Revive" } do
				if (items[key] or 0) > 0 then
					table.insert(entries, { Text = `{Config.Items[key].Name} x{items[key]}`, Sub = Config.Items[key].Description, Color = Config.Items[key].Color:Lerp(C.Ink, 0.45), OnPick = function()
						remotes.UseItem:FireServer(key, uid)
					end })
				end
			end
			if #entries == 0 then
				UI.Toast("You have no medicine. Buy some at a Beast Mart!", C.Muted)
				return
			end
			chooser("USE WHICH ITEM?", entries)
		end)
		if def.Evolve then
			local ascend = priceButton(Config.DevProducts.EvoCrystal.PriceHint, { Text = `EVOLVE R$ {Config.DevProducts.EvoCrystal.PriceHint}`, TextSize = 14, LayoutOrder = 4, Color = C.GoldDark, Parent = actions })
			ascend.Activated:Connect(function()
				makeLead(uid)
				task.wait(0.3)
				UI.Buy("Product", "EvoCrystal")
			end)
		end
		local snack = priceButton(Config.DevProducts.PowerSnack.PriceHint, { Text = `+5 LV R$ {Config.DevProducts.PowerSnack.PriceHint}`, TextSize = 14, LayoutOrder = 5, Parent = actions })
		snack.Activated:Connect(function()
			makeLead(uid)
			task.wait(0.3)
			UI.Buy("Product", "PowerSnack")
		end)
		local coins = 30 * beast.L * rarity.Index
		local release = button({ Text = `RELEASE`, TextSize = 14, Color = C.CrimsonDark, LayoutOrder = 6, Parent = actions })
		release.Activated:Connect(function()
			if not releaseArmed then
				releaseArmed = true
				release.Text = `SURE? +{Format.Number(coins)}`
				return
			end
			releaseArmed = false
			selectedUid = nil
			remotes.ReleaseBeast:FireServer(uid)
		end)
	end

	drawList = function()
		local col = UI.State.Collection
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = {}
		if current == "TEAM" then
			for index, uid in col.Team do
				if col.Beasts[uid] then
					table.insert(list, { Uid = uid, Beast = col.Beasts[uid], Team = index })
				end
			end
		else
			for uid, beast in col.Beasts do
				if not table.find(col.Team, uid) then
					table.insert(list, { Uid = uid, Beast = beast })
				end
			end
			table.sort(list, beastSort)
		end
		for order, item in list do
			local beast = item.Beast
			local def = Config.BeastsById[beast.S]
			local card = create("TextButton", { BackgroundColor3 = if item.Uid == selectedUid then C.PanelLight else C.PanelDark, AutoButtonColor = true, Text = "", LayoutOrder = order, Parent = grid })
			Theme.corner(card, 10)
			Theme.stroke(card, if item.Uid == selectedUid then C.Gold elseif beast.Sh then C.Prism else C.PanelLight, 2)
			Theme.beastIcon(beast.S, beast.Sh, { Position = UDim2.fromOffset(8, 8), Parent = card })
			label({ Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -62, 0, 22), Text = def.Name, Font = Theme.Heavy, TextSize = 16, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if beast.Sh then C.Prism else C.Cream, Parent = card })
			label({ Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -62, 0, 18), Text = `Lv {beast.L}` .. (if beast.St then `  {Config.Statuses[beast.St].Name}` elseif beast.Hp <= 0 then "  FNT" else ""), TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
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
		local boxCount = 0
		for uid in col.Beasts do
			if not table.find(col.Team, uid) then
				boxCount += 1
			end
		end
		info.Text = `Team {#col.Team}/{col.TeamSize}  ·  Box {boxCount}/{col.Capacity}  ·  Tap a move to change it`
	end

	tabs(content, { "TEAM", "BOX" }, function(name, _)
		current = name
		drawList()
	end, current)
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

---------------------------------------------------------------- Beutel

local function orbIcon(parent: Instance, color: Color3, size: number, position: UDim2, catch: boolean)
	local orb = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(size, size), BackgroundColor3 = color, Parent = parent })
	Theme.corner(orb, 100)
	Theme.stroke(orb, C.Ink, 2)
	Theme.gradient(orb, Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 140))
	if catch then
		-- Goldener Ring statt Mittelstreifen (eigenes Orb-Design)
		local ring = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.45, 0.45), BackgroundTransparency = 1, Parent = orb })
		Theme.corner(ring, 100)
		Theme.stroke(ring, C.Gold, 3)
	end
	return orb
end

function UI.OpenBag()
	local _, content = window("BAG", 760, 470)
	tabs(content, { "MEDICINE", "ORBS" }, function(name, body)
		local scroll = scrolling(body)
		create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
		local function draw()
			for _, child in scroll:GetChildren() do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end
			local items = UI.State.Collection and UI.State.Collection.Items or {}
			local list = {}
			for key, item in Config.Items do
				if item.Pocket == (if name == "ORBS" then "Orbs" else "Medicine") then
					table.insert(list, { Key = key, Item = item })
				end
			end
			table.sort(list, function(a, b)
				return a.Item.Order < b.Item.Order
			end)
			for _, entry in list do
				local item = entry.Item
				local count = items[entry.Key] or 0
				local row = Theme.panel({ Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = C.PanelDark, LayoutOrder = item.Order, Parent = scroll })
				orbIcon(row, item.Color, 46, UDim2.fromOffset(40, 35), item.Catch ~= nil)
				label({ Position = UDim2.fromOffset(76, 8), Size = UDim2.new(0.5, 0, 0, 26), Text = `{item.Name}  x{count}`, Font = Theme.Title, TextSize = 22, TextColor3 = if count > 0 then C.Gold else C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
				label({ Position = UDim2.fromOffset(76, 36), Size = UDim2.new(0.55, 0, 0, 24), Text = item.Description, TextSize = 15, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
				if item.Catch then
					if entry.Key == "MasterOrb" then
						local buy = priceButton(Config.DevProducts.MasterOrb1.PriceHint, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 44), Text = `BUY R$ {Config.DevProducts.MasterOrb1.PriceHint}`, TextSize = 16, Parent = row })
						buy.Activated:Connect(function()
							UI.Buy("Product", "MasterOrb1")
						end)
					else
						label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(170, 40), Text = "Throw it in battle", TextSize = 15, TextColor3 = C.Muted, Parent = row })
					end
				elseif count > 0 then
					local use = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(120, 44), Text = "USE", TextSize = 20, Color = C.Green, Parent = row })
					use.Activated:Connect(function()
						teamChooser(`USE {item.Name:upper()} ON...`, function(uid)
							remotes.UseItem:FireServer(entry.Key, uid)
						end, function(beast)
							if item.Revive then
								return beast.Hp <= 0
							elseif item.Cure then
								return beast.Hp > 0 and beast.St ~= nil
							end
							return beast.Hp > 0 and beast.Hp < beast.MaxHp
						end)
					end)
				end
			end
		end
		draw()
		table.clear(refreshers)
		table.insert(refreshers, draw)
	end)
end

---------------------------------------------------------------- Laden (Muenzen)

function UI.OpenMart()
	local _, content = window("BEAST MART", 820, 470)
	local coinsLabel = label({ Size = UDim2.new(1, 0, 0, 26), Text = "", Font = Theme.Title, TextSize = 22, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Right, Parent = content })
	local body = create("Frame", { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 1, -32), BackgroundTransparency = 1, Parent = content })
	local scroll = gridIn(body, Vector2.new(184, 170))
	local function draw()
		coinsLabel.Text = `Your coins: {Format.Number(player:GetAttribute("Coins") or 0)}`
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local badges = UI.State.Collection and UI.State.Collection.Badges or 0
		local items = UI.State.Collection and UI.State.Collection.Items or {}
		local list = {}
		for key, item in Config.Items do
			if item.Price > 0 then
				table.insert(list, { Key = key, Item = item })
			end
		end
		table.sort(list, function(a, b)
			return a.Item.Order < b.Item.Order
		end)
		for _, entry in list do
			local item = entry.Item
			local locked = badges < item.Badges
			local card = Theme.panel({ BackgroundColor3 = C.PanelDark, LayoutOrder = item.Order, Parent = scroll })
			orbIcon(card, if locked then C.PanelLight else item.Color, 40, UDim2.fromOffset(32, 30), item.Catch ~= nil)
			label({ Position = UDim2.fromOffset(58, 8), Size = UDim2.new(1, -64, 0, 24), Text = item.Name, Font = Theme.Title, TextSize = 18, TextScaled = true, TextColor3 = if locked then C.Muted else C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			label({ Position = UDim2.fromOffset(58, 32), Size = UDim2.new(1, -64, 0, 18), Text = `{Format.Number(item.Price)} coins · have {items[entry.Key] or 0}`, TextSize = 13, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			label({ Position = UDim2.fromOffset(10, 56), Size = UDim2.new(1, -20, 0, 34), Text = item.Description, TextSize = 13, TextColor3 = C.Muted, Parent = card })
			if locked then
				label({ Position = UDim2.new(0, 10, 1, -56), Size = UDim2.new(1, -20, 0, 44), Text = `🔒 Needs {item.Badges} badges`, Font = Theme.Title, TextSize = 17, TextColor3 = C.Muted, Parent = card })
			else
				for i, amount in { 1, 5, 10 } do
					local buy = button({ Position = UDim2.new((i - 1) / 3, 6, 1, -54), Size = UDim2.new(1 / 3, -10, 0, 44), Text = `x{amount}`, TextSize = 18, Color = C.Crimson, Parent = card })
					buy.Activated:Connect(function()
						remotes.BuyItem:FireServer(entry.Key, amount)
					end)
				end
			end
		end
	end
	draw()
	table.insert(refreshers, draw)
	local connection
	connection = player:GetAttributeChangedSignal("Coins"):Connect(function()
		if coinsLabel.Parent then
			coinsLabel.Text = `Your coins: {Format.Number(player:GetAttribute("Coins") or 0)}`
		else
			connection:Disconnect()
		end
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

local PRODUCT_GROUPS = {
	BOOSTS = { "MasterOrb1", "MasterOrb5", "Boost", "PowerSnack", "EvoCrystal", "SkipChampion", "FullHeal", "ServerShiny", "Storage" },
	COINS = { "CoinsSmall", "CoinsMedium", "CoinsLarge" },
}

function UI.OpenShop(startTab: string?)
	local _, content = window("ROYAL SHOP", 860, 500)
	tabs(content, { "PASSES", "BOOSTS", "COINS", "CODES" }, function(name, body)
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
			label({ Position = UDim2.fromOffset(0, 90), Size = UDim2.new(1, 0, 0, 60), Text = "New codes come with every update. Like the game and join the group to get them first!", TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
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
	end, startTab)
end

---------------------------------------------------------------- Kampf-Menue (Gauntlet, Revanchen)

function UI.OpenBattleMenu()
	local _, content = window("BATTLE", 860, 500)
	local collection = UI.State.Collection
	local badges = collection and collection.Badges or 0
	-- Gauntlet oben
	local gauntlet = Theme.panel({ Size = UDim2.new(0.62, -6, 0, 96), BackgroundColor3 = C.CrimsonDark, Parent = content })
	local gTitle = label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.6, 0, 0, 34), Text = "ENDLESS GAUNTLET", Font = Theme.Title, TextSize = 28, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = gauntlet })
	Theme.textStroke(gTitle, 1.5)
	label({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(0.62, 0, 0, 40), Text = if badges >= Config.GauntletBadges then `Best: {player:GetAttribute("BestWave") or 0} waves · coins every wave · legend boss every 10 waves` else "Unlocks with your first arena badge", TextSize = 15, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = gauntlet })
	local start = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 56), Text = if badges >= Config.GauntletBadges then "START" else "🔒", TextSize = 24, Color = C.Crimson, Parent = gauntlet })
	start.Activated:Connect(function()
		if badges >= Config.GauntletBadges then
			closeWindow()
			remotes.ArenaChallenge:FireServer("Gauntlet")
		end
	end)
	local pass = Theme.panel({ Position = UDim2.new(0.62, 6, 0, 0), Size = UDim2.new(0.38, -6, 0, 96), BackgroundColor3 = C.PanelDark, Parent = content })
	local nextLeader = Story.Leaders[badges + 1]
	label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 36), Text = if nextLeader then `Stuck on {nextLeader.Name}? Get the {nextLeader.Badge} now!` else "You have all 8 badges!", TextSize = 15, TextColor3 = C.Cream, Parent = pass })
	if nextLeader then
		local skip = priceButton(Config.DevProducts.SkipChampion.PriceHint, { Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 42), Text = `CHAMPION PASS  R$ {Config.DevProducts.SkipChampion.PriceHint}`, TextSize = 16, Parent = pass })
		skip.Activated:Connect(function()
			UI.Buy("Product", "SkipChampion")
		end)
	end

	label({ Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 26), Text = "LEADER REMATCHES  ·  stronger teams, more coins", Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
	local scroll = scrolling(content, { Position = UDim2.fromOffset(0, 134), Size = UDim2.new(1, 0, 1, -134) })
	create("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 140), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	for index, leader in Story.Leaders do
		local beaten = index <= badges
		local card = Theme.panel({ BackgroundColor3 = if beaten then C.PanelLight else C.PanelDark, LayoutOrder = index, Parent = scroll })
		local medal = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = if beaten then typeColor(leader.Type) else C.PanelDark, Parent = card })
		Theme.corner(medal, 100)
		Theme.stroke(medal, C.Gold, 2)
		label({ Size = UDim2.fromScale(1, 1), Text = tostring(index), Font = Theme.Title, TextSize = 24, TextColor3 = if beaten then C.Ink else C.Muted, Parent = medal })
		label({ Position = UDim2.fromOffset(4, 56), Size = UDim2.new(1, -8, 0, 22), Text = leader.Name, Font = Theme.Title, TextSize = 20, TextColor3 = C.Cream, Parent = card })
		label({ Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 16), Text = `{leader.Type} · {leader.Badge}`, TextSize = 12, TextColor3 = C.Muted, Parent = card })
		if beaten then
			local fight = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 34), Text = `REMATCH`, TextSize = 16, Color = C.Crimson, Parent = card })
			fight.Activated:Connect(function()
				closeWindow()
				remotes.ArenaChallenge:FireServer("Rematch", index)
			end)
		else
			label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 34), Text = "🔒", TextSize = 20, TextColor3 = C.Muted, Parent = card })
		end
	end
end

---------------------------------------------------------------- Bestiarium

local function habitats(beastId: string): { string }
	local list = {}
	for _, area in Story.Areas do
		for _, entry in area.Wild or {} do
			if entry[1] == beastId then
				table.insert(list, area.Name)
			end
		end
	end
	for _, legend in Story.Legends do
		if legend.Beast == beastId then
			table.insert(list, Story.AreasById[legend.Area].Name .. " (shrine)")
		end
	end
	return list
end

function UI.OpenDex()
	local collection = UI.State.Collection
	if not collection then
		return
	end
	local _, content = window("BESTIARY", 900, 520)
	local caught, seen = 0, 0
	for _ in collection.Dex do
		caught += 1
	end
	for _ in collection.Seen do
		seen += 1
	end
	label({ Size = UDim2.new(0.55, 0, 0, 24), Text = `Seen {seen}  ·  Caught {caught} / {#Config.Beasts}`, Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
	local listArea = create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(0.55, -8, 1, -30), BackgroundTransparency = 1, Parent = content })
	local grid = gridIn(listArea, Vector2.new(88, 96))
	local detail = Theme.panel({ Position = UDim2.new(0.55, 8, 0, 0), Size = UDim2.new(0.45, -8, 1, 0), BackgroundColor3 = C.PanelDark, Parent = content })
	local function show(def)
		detail:ClearAllChildren()
		Theme.corner(detail, 12)
		Theme.stroke(detail, C.Gold, 2, 0.15)
		local isSeen = collection.Seen[def.Id] or collection.Dex[def.Id]
		if not isSeen then
			label({ Size = UDim2.fromScale(1, 1), Text = `No.{string.format("%03d", def.Number)}\n???\n\nYou haven't seen this beast yet.`, TextSize = 20, TextColor3 = C.Muted, Parent = detail })
			return
		end
		Theme.viewport(def.Id, 30, false, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 190), Parent = detail })
		local nameLabel = label({ Position = UDim2.fromOffset(12, 204), Size = UDim2.new(1, -24, 0, 32), Text = `No.{string.format("%03d", def.Number)}  {def.Name}`, Font = Theme.Title, TextSize = 26, TextScaled = true, TextColor3 = C.Cream, Parent = detail })
		Theme.textStroke(nameLabel, 1.5)
		local chips = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.fromOffset(200, 20), BackgroundTransparency = 1, Parent = detail })
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = chips })
		Theme.typeChip(def.Type, { Parent = chips })
		if def.Type2 then
			Theme.typeChip(def.Type2, { Parent = chips })
		end
		local rarity = Config.RaritiesByName[def.Rarity]
		label({ Position = UDim2.fromOffset(12, 266), Size = UDim2.new(1, -24, 0, 20), Text = def.Rarity .. (if collection.Dex[def.Id] then "  ·  CAUGHT" else "  ·  seen"), TextSize = 16, TextColor3 = rarity.Color, Parent = detail })
		label({ Position = UDim2.fromOffset(16, 290), Size = UDim2.new(1, -32, 0, 60), Text = def.Dex or "", TextSize = 16, TextColor3 = C.Cream, Parent = detail })
		local places = habitats(def.Id)
		local evo = if def.Evolve then `Evolves into {Config.BeastsById[def.Evolve.To].Name} at Lv {def.Evolve.Level}` elseif def.From then `Evolves from {Config.BeastsById[def.From].Name}` else "Does not evolve"
		label({ Position = UDim2.fromOffset(16, 352), Size = UDim2.new(1, -32, 0, 20), Text = evo, TextSize = 15, TextColor3 = C.Gold, Parent = detail })
		label({ Position = UDim2.fromOffset(16, 374), Size = UDim2.new(1, -32, 0, 40), Text = if #places > 0 then "Found in: " .. table.concat(places, ", ") else "Found by evolving", TextSize = 14, TextColor3 = C.Muted, Parent = detail })
	end
	for _, def in Config.Beasts do
		local isCaught = collection.Dex[def.Id]
		local isSeen = isCaught or collection.Seen[def.Id]
		local cell = create("TextButton", { BackgroundColor3 = if isCaught then C.PanelLight else C.PanelDark, AutoButtonColor = true, Text = "", LayoutOrder = def.Number, Parent = grid })
		Theme.corner(cell, 10)
		Theme.stroke(cell, if isCaught then typeColor(def.Type) else C.PanelLight, 2)
		label({ Position = UDim2.fromOffset(4, 2), Size = UDim2.new(1, -8, 0, 16), Text = string.format("%03d", def.Number), TextSize = 12, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = cell })
		if isSeen then
			Theme.beastIcon(def.Id, false, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Parent = cell })
		else
			local unknown = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.Ink, Parent = cell })
			Theme.corner(unknown, 100)
			label({ Size = UDim2.fromScale(1, 1), Text = "?", Font = Theme.Title, TextSize = 24, TextColor3 = C.Muted, Parent = unknown })
		end
		label({ Position = UDim2.new(0, 2, 1, -24), Size = UDim2.new(1, -4, 0, 20), Text = if isSeen then def.Name else "???", Font = Theme.Heavy, TextSize = 13, TextScaled = true, TextColor3 = if isCaught then C.Cream else C.Muted, Parent = cell })
		if isCaught then
			local dot = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(150, 60, 170), Parent = cell })
			Theme.corner(dot, 6)
			Theme.stroke(dot, C.Gold, 1.5)
		end
		cell.Activated:Connect(function()
			show(def)
		end)
	end
	show(Config.Beasts[1])
end

---------------------------------------------------------------- Karte und Fliegen

function UI.OpenMap()
	local collection = UI.State.Collection
	if not collection then
		return
	end
	local _, content = window("MAP OF VALORIA", 900, 520)
	local mapFrame = create("Frame", { Size = UDim2.new(1, 0, 1, -34), BackgroundColor3 = Color3.fromRGB(60, 120, 160), Parent = content })
	Theme.corner(mapFrame, 12)
	Theme.stroke(mapFrame, C.Gold, 2)
	local hint = label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 28), Text = "Tap a town you have visited to fly there. ★ = your next goal", TextSize = 16, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
	local _ = hint
	-- Weltkoordinaten auf die Karte abbilden
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, area in Story.Areas do
		local r = area.Rect
		minX = math.min(minX, r.Center.X - r.SizeX / 2)
		maxX = math.max(maxX, r.Center.X + r.SizeX / 2)
		minZ = math.min(minZ, r.Center.Z - r.SizeZ / 2)
		maxZ = math.max(maxZ, r.Center.Z + r.SizeZ / 2)
	end
	local pad = 40
	minX -= pad
	maxX += pad
	minZ -= pad
	maxZ += pad
	local function toMap(x: number, z: number): UDim2
		return UDim2.fromScale((x - minX) / (maxX - minX), (z - minZ) / (maxZ - minZ))
	end
	local currentArea = player:GetAttribute("Area")
	for _, area in Story.Areas do
		if area.Kind == "Route" then
			local r = area.Rect
			local bar = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = toMap(r.Center.X, r.Center.Z), Size = UDim2.fromScale(r.SizeX / (maxX - minX) * 0.7, r.SizeZ / (maxZ - minZ) * 0.7), BackgroundColor3 = area.Theme.Ground, Parent = mapFrame })
			Theme.corner(bar, 6)
			label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = toMap(r.Center.X, r.Center.Z), Size = UDim2.fromOffset(90, 18), Text = area.Name, TextSize = 12, TextColor3 = C.Ink, ZIndex = 2, Parent = mapFrame })
		end
	end
	for _, area in Story.Areas do
		if area.Kind == "Town" then
			local visited = collection.Visited[area.Id] == true
			local isHere = currentArea == area.Id
			local isGoal = collection.ObjectiveArea == area.Id
			local size = if area.League then 74 else 58
			local town = create("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = toMap(area.Center.X, area.Center.Z), Size = UDim2.fromOffset(size, size), BackgroundColor3 = if visited then area.Theme.Accent else C.PanelDark, AutoButtonColor = visited, Text = "", ZIndex = 3, Parent = mapFrame })
			Theme.corner(town, 14)
			Theme.stroke(town, if isHere then C.Cream else C.Gold, if isHere then 4 else 2)
			label({ Size = UDim2.fromScale(1, 1), Text = if isGoal then "★" elseif visited then "" else "?", Font = Theme.Title, TextSize = 28, TextColor3 = if isGoal then C.Gold else C.Muted, ZIndex = 4, Parent = town })
			local name = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(130, 18), Text = if visited then area.Name else "???", Font = Theme.Heavy, TextSize = 14, TextColor3 = C.Cream, ZIndex = 4, Parent = town })
			Theme.textStroke(name, 1.5)
			if isHere then
				local you = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromOffset(60, 18), Text = "YOU", Font = Theme.Title, TextSize = 14, TextColor3 = C.Cream, ZIndex = 4, Parent = town })
				Theme.textStroke(you, 1.5)
			end
			town.Activated:Connect(function()
				if visited and not isHere then
					closeWindow()
					remotes.Fly:FireServer(area.Id)
				end
			end)
		end
	end
end

---------------------------------------------------------------- Starter-Wahl

function UI.ShowStarter()
	closeWindow()
	local screen = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.25, ZIndex = 20, Parent = root })
	local title = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Size = UDim2.fromOffset(800, 56), Text = "CHOOSE YOUR PARTNER", Font = Theme.Title, TextSize = 46, TextColor3 = C.Gold, ZIndex = 21, Parent = screen })
	Theme.textStroke(title, 3)
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 88), Size = UDim2.fromOffset(800, 26), Text = "Fire beats Leaf, Leaf beats Water, Water beats Fire. Your rival Kai will pick the one that beats yours!", TextSize = 18, ZIndex = 21, Parent = screen })
	local row = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 130), Size = UDim2.fromOffset(840, 360), BackgroundTransparency = 1, ZIndex = 21, Parent = screen })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20), Parent = row })
	for _, beastId in Config.Starters do
		local def = Config.BeastsById[beastId]
		local color = typeColor(def.Type)
		local card = Theme.panel({ Size = UDim2.fromOffset(260, 350), BackgroundColor3 = C.Panel, ZIndex = 21, Parent = row })
		local glow = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.fromOffset(200, 200), BackgroundColor3 = color, BackgroundTransparency = 0.75, ZIndex = 21, Parent = card })
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

---------------------------------------------------------------- Szenen nach dem Kampf

local sceneQueue = {}
local sceneRunning = false

local function overlay(): Frame
	return create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Ink, BackgroundTransparency = 0.15, ZIndex = 25, Parent = root })
end

-- Entwicklung: Silhouette pulsiert und wechselt zur neuen Form
local function evolutionScene(event)
	local from = Config.BeastsById[event.From]
	local to = Config.BeastsById[event.To]
	local screen = overlay()
	local text = label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -40), Size = UDim2.fromOffset(800, 50), Text = `What? {from.Name} is evolving!`, Font = Theme.Title, TextSize = 34, TextColor3 = C.Cream, ZIndex = 27, Parent = screen })
	Theme.textStroke(text, 2)
	local glow = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(300, 300), BackgroundColor3 = typeColor(to.Type), BackgroundTransparency = 0.6, ZIndex = 25, Parent = screen })
	Theme.corner(glow, 300)
	local oldView = Theme.viewport(event.From, 30, false, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(340, 340), ZIndex = 26, Parent = screen })
	local newView = Theme.viewport(event.To, 30, false, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(340, 340), ZIndex = 26, Visible = false, Parent = screen })
	for i = 1, 8 do
		local speed = 0.35 - i * 0.03
		oldView.Visible = i % 2 == 1
		newView.Visible = i % 2 == 0
		oldView.ImageColor3 = Color3.new(1, 1, 1)
		TweenService:Create(glow, TweenInfo.new(speed), { BackgroundTransparency = if i % 2 == 0 then 0.2 else 0.7 }):Play()
		task.wait(speed)
	end
	oldView.Visible = false
	newView.Visible = true
	glow.BackgroundTransparency = 0
	TweenService:Create(glow, TweenInfo.new(0.8), { BackgroundTransparency = 0.7, Size = UDim2.fromOffset(420, 420) }):Play()
	text.Text = `Congratulations! Your {from.Name} evolved into {to.Name}!`
	text.TextColor3 = C.Gold
	task.wait(2.6)
	screen:Destroy()
end

-- Neue Attacke bei vollen Plaetzen: eine alte vergessen oder nicht lernen
local function learnScene(event)
	local collection = UI.State.Collection
	local beast = collection and collection.Beasts[event.Uid]
	if not beast then
		return
	end
	local def = Config.BeastsById[beast.S]
	local new = Config.Moves[event.Move]
	local done = Instance.new("BindableEvent")
	local entries = {}
	for slot, move in beast.Moves do
		table.insert(entries, { Text = `Forget {move.Name}`, Sub = `{move.Type:upper()} · {if move.Power > 0 then "PWR " .. move.Power else "STATUS"}`, Color = typeColor(move.Type):Lerp(C.Ink, 0.45), OnPick = function()
			remotes.SetMove:FireServer(event.Uid, slot, event.Move)
			done:Fire()
		end })
	end
	table.insert(entries, { Text = `Don't learn {new.Name}`, Sub = "keep all moves", Color = C.PanelLight, OnPick = function()
		UI.Toast(`{def.Name} did not learn {new.Name}.`, C.Muted)
		done:Fire()
	end })
	local frame = chooser(`{def.Name:upper()} WANTS TO LEARN {new.Name:upper()} ({new.Type:upper()}, {if new.Power > 0 then "PWR " .. new.Power else "STATUS"})`, entries)
	frame.Destroying:Connect(function()
		done:Fire()
	end)
	done.Event:Wait()
	done:Destroy()
end

local function badgeScene(payload)
	local screen = overlay()
	local color = typeColor(payload.Type)
	local medal = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = color, ZIndex = 26, Parent = screen })
	Theme.corner(medal, 200)
	Theme.stroke(medal, C.Gold, 8)
	Theme.gradient(medal, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	local number = label({ Size = UDim2.fromScale(1, 1), Text = tostring(payload.Index), Font = Theme.Title, TextScaled = true, TextColor3 = C.Ink, ZIndex = 27, Parent = medal })
	local _ = number
	TweenService:Create(medal, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(200, 200), Rotation = 360 }):Play()
	local title = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(800, 60), Text = payload.Badge:upper(), Font = Theme.Title, TextSize = 52, TextColor3 = C.Gold, ZIndex = 27, Parent = screen })
	Theme.textStroke(title, 3)
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromOffset(800, 30), Text = `Badge {payload.Index} of 8 · +{Format.Coins(payload.Coins)}`, TextSize = 22, TextColor3 = C.Cream, ZIndex = 27, Parent = screen })
	task.wait(3.2)
	screen:Destroy()
end

local function hallOfFameScene(payload)
	local screen = overlay()
	local title = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(900, 80), Text = "HALL OF FAME", Font = Theme.Title, TextSize = 72, TextColor3 = C.Gold, ZIndex = 27, Parent = screen })
	Theme.textStroke(title, 4)
	label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Size = UDim2.fromOffset(900, 30), Text = `{player.DisplayName} is the new Champion of Valoria!`, TextSize = 24, TextColor3 = C.Cream, ZIndex = 27, Parent = screen })
	local row = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 180), Size = UDim2.fromOffset(900, 200), BackgroundTransparency = 1, ZIndex = 26, Parent = screen })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10), Parent = row })
	for _, item in payload.Team or {} do
		local entry = item.Entry
		local card = Theme.panel({ Size = UDim2.fromOffset(140, 190), ZIndex = 26, Parent = row })
		Theme.viewport(entry.S, entry.L, entry.Sh, { Size = UDim2.new(1, 0, 0, 140), ZIndex = 27, Parent = card })
		label({ Position = UDim2.fromOffset(0, 142), Size = UDim2.new(1, 0, 0, 24), Text = Config.BeastsById[entry.S].Name, Font = Theme.Title, TextSize = 18, TextScaled = true, ZIndex = 27, Parent = card })
		label({ Position = UDim2.fromOffset(0, 164), Size = UDim2.new(1, 0, 0, 18), Text = `Lv {entry.L}`, TextSize = 15, TextColor3 = C.Gold, ZIndex = 27, Parent = card })
	end
	task.wait(7)
	screen:Destroy()
end

local function runScenes()
	if sceneRunning then
		return
	end
	sceneRunning = true
	while #sceneQueue > 0 do
		local scene = table.remove(sceneQueue, 1)
		sceneCount += 1
		local ok, err = pcall(scene)
		sceneCount -= 1
		if not ok then
			warn("[UI] Szene", err)
		end
	end
	sceneRunning = false
end

local function queueScene(fn: () -> ())
	table.insert(sceneQueue, fn)
	task.spawn(runScenes)
end

function UI.ShowPostBattle(events: { any })
	-- Erst Entwicklungen, dann neue Attacken
	for _, event in events do
		if event.T == "Evolve" then
			queueScene(function()
				evolutionScene(event)
			end)
		end
	end
	for _, event in events do
		if event.T == "LearnPrompt" then
			queueScene(function()
				learnScene(event)
			end)
		end
	end
end

function UI.ShowBadge(payload)
	queueScene(function()
		badgeScene(payload)
	end)
end

function UI.ShowHallOfFame(payload)
	queueScene(function()
		hallOfFameScene(payload)
	end)
end

-- Schwarzblende (Fliegen, Aufwachen im Heilzentrum)
function UI.Fade(text: string?)
	local screen = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 40, Parent = root })
	local caption = label({ Size = UDim2.fromScale(1, 1), Text = text or "", Font = Theme.Title, TextSize = 36, TextColor3 = C.Gold, TextTransparency = 1, ZIndex = 41, Parent = screen })
	TweenService:Create(screen, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(caption, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
	task.delay(1.3, function()
		TweenService:Create(screen, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(caption, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		task.wait(0.7)
		screen:Destroy()
	end)
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
local objectiveLabel: TextLabel
local badgeDots: Frame
local areaBanner: TextLabel

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
			local card = create("TextButton", { Size = UDim2.fromOffset(124, 50), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = true, LayoutOrder = index, Parent = teamBar })
			Theme.corner(card, 10)
			Theme.stroke(card, if index == 1 then C.Gold elseif beast.Hp <= 0 then C.Red else C.PanelLight, 2)
			Theme.beastIcon(beast.S, beast.Sh, { Position = UDim2.fromOffset(5, 6), Size = UDim2.fromOffset(38, 38), Parent = card })
			label({ Position = UDim2.fromOffset(48, 3), Size = UDim2.new(1, -52, 0, 18), Text = def.Name, Font = Theme.Heavy, TextSize = 14, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			label({ Position = UDim2.fromOffset(48, 20), Size = UDim2.new(1, -52, 0, 14), Text = `Lv {beast.L}` .. (if beast.St then " " .. Config.Statuses[beast.St].Name elseif beast.Hp <= 0 then " FNT" else ""), TextSize = 12, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
			local _, fill = Theme.hpBar({ Position = UDim2.fromOffset(48, 36), Size = UDim2.new(1, -56, 0, 8), Parent = card })
			Theme.setHp(fill, beast.Hp / beast.MaxHp)
			card.Activated:Connect(function()
				UI.OpenTeam()
			end)
		end
	end
end

local function drawProgress()
	local collection = UI.State.Collection
	if not collection then
		return
	end
	objectiveLabel.Text = collection.Objective or ""
	for _, child in badgeDots:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for index, leader in Story.Leaders do
		local earned = index <= (collection.Badges or 0)
		local dot = create("Frame", { Size = UDim2.fromOffset(16, 16), BackgroundColor3 = if earned then typeColor(leader.Type) else C.PanelDark, Parent = badgeDots })
		Theme.corner(dot, 8)
		Theme.stroke(dot, if earned then C.Gold else C.PanelLight, 1.5)
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
	local b = button({ Color = color, LayoutOrder = order, Parent = hud:FindFirstChild("Menu") })
	label({ Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 36), Text = icon, TextSize = 28, Parent = b })
	local textLabel = label({ Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 20), Text = text, Font = Theme.Title, TextSize = 14, TextColor3 = C.Cream, Parent = b })
	Theme.textStroke(textLabel, 1.2)
	local badge = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 0, BackgroundColor3 = C.Red, Text = "!", Font = Theme.Title, TextSize = 15, Visible = false, Parent = b })
	Theme.corner(badge, 11)
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
	drawProgress()
	for _, refresh in refreshers do
		task.spawn(refresh)
	end
	for _, fn in listeners do
		task.spawn(fn, collection)
	end
end

function UI.OpenMenu(name: string)
	if name == "Mart" then
		UI.OpenMart()
	elseif name == "Bag" then
		UI.OpenBag()
	elseif name == "Team" then
		UI.OpenTeam()
	elseif name == "Map" then
		UI.OpenMap()
	elseif name == "Dex" then
		UI.OpenDex()
	elseif name == "Shop" then
		UI.OpenShop()
	elseif name == "Battle" then
		UI.OpenBattleMenu()
	end
end

local function showArea(areaId: string?)
	local area = areaId and Story.AreasById[areaId]
	if not area then
		return
	end
	areaBanner.Text = area.Name:upper()
	areaBanner.TextColor3 = area.Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.35)
	areaBanner.Visible = true
	areaBanner.TextTransparency = 1
	areaBanner.Position = UDim2.new(0.5, 0, 0, 70)
	TweenService:Create(areaBanner, TweenInfo.new(0.4), { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, 84) }):Play()
	local stamp = os.clock()
	areaBanner:SetAttribute("Stamp", stamp)
	task.delay(2.6, function()
		if areaBanner:GetAttribute("Stamp") == stamp then
			TweenService:Create(areaBanner, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
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

	toastList = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 120), Size = UDim2.fromOffset(600, 200), BackgroundTransparency = 1, ZIndex = 30, Parent = root })
	create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), Parent = toastList })
	bannerLabel = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(760, 40), Text = "", Font = Theme.Title, TextSize = 26, TextScaled = true, Visible = false, ZIndex = 30, Parent = root })
	Theme.textStroke(bannerLabel, 2.5)
	areaBanner = label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(700, 52), Text = "", Font = Theme.Title, TextSize = 46, Visible = false, ZIndex = 4, Parent = hud })
	Theme.textStroke(areaBanner, 3)

	-- Muenzen, Orden und aktuelles Ziel
	local coins = pill(UDim2.fromOffset(14, 14), 190, C.Gold, "C")
	local badgeFrame = create("Frame", { Position = UDim2.fromOffset(212, 14), Size = UDim2.fromOffset(196, 44), BackgroundColor3 = C.Panel, BackgroundTransparency = 0.05, Parent = hud })
	Theme.corner(badgeFrame, 22)
	Theme.stroke(badgeFrame, C.Gold, 2)
	badgeDots = create("Frame", { Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Parent = badgeFrame })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), Parent = badgeDots })
	local objective = create("TextButton", { Position = UDim2.fromOffset(14, 66), Size = UDim2.fromOffset(394, 44), BackgroundColor3 = C.PanelDark, BackgroundTransparency = 0.1, AutoButtonColor = true, Text = "", Parent = hud })
	Theme.corner(objective, 12)
	Theme.stroke(objective, C.GoldDark, 1.5)
	label({ Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(30, 44), Text = "★", Font = Theme.Title, TextSize = 24, TextColor3 = C.Gold, Parent = objective })
	objectiveLabel = label({ Position = UDim2.fromOffset(40, 2), Size = UDim2.new(1, -48, 1, -4), Text = "", TextSize = 15, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = objective })
	objective.Activated:Connect(UI.OpenMap)

	local chips = create("Frame", { Name = "Chips", Position = UDim2.fromOffset(418, 20), Size = UDim2.fromOffset(560, 32), BackgroundTransparency = 1, Parent = hud })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
	local multChip = chip(1, C.Gold)
	local boostChip = chip(2, C.Green)
	local stormChip = chip(3, C.Prism)

	-- Menue: zwei Spalten links
	local menu = create("Frame", { Name = "Menu", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 40), Size = UDim2.fromOffset(150, 316), BackgroundTransparency = 1, Parent = hud })
	create("UIGridLayout", { CellSize = UDim2.fromOffset(70, 70), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	local teamButton = menuButton("🐾", "TEAM", C.Blue, 1)
	local bagButton = menuButton("🎒", "BAG", Color3.fromRGB(200, 140, 40), 2)
	local dexButton = menuButton("📖", "DEX", C.Crimson, 3)
	local mapButton = menuButton("🗺️", "MAP", C.Green, 4)
	local shopButton, shopBadge = menuButton("💎", "SHOP", C.GoldDark, 5)
	local battleButton = menuButton("⚔️", "BATTLE", C.CrimsonDark, 6)
	local dailyButton, dailyBadge = menuButton("🎁", "DAILY", Color3.fromRGB(70, 160, 120), 7)
	local adButton, adBadge = menuButton("🎬", "FREE", Color3.fromRGB(200, 110, 40), 8)
	adButton.Visible = false
	adBadge.Text = "+"
	adBadge.BackgroundColor3 = C.Gold
	adBadge.TextColor3 = C.Ink
	adBadge.Visible = true
	shopBadge.Text = "%"
	shopBadge.BackgroundColor3 = C.Gold
	shopBadge.TextColor3 = C.Ink

	teamButton.Activated:Connect(function()
		UI.OpenTeam()
	end)
	bagButton.Activated:Connect(UI.OpenBag)
	dexButton.Activated:Connect(UI.OpenDex)
	mapButton.Activated:Connect(UI.OpenMap)
	shopButton.Activated:Connect(function()
		UI.OpenShop()
	end)
	battleButton.Activated:Connect(UI.OpenBattleMenu)
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

	teamBar = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(800, 50), BackgroundTransparency = 1, Parent = hud })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = teamBar })

	local function refreshStats()
		coins.Text = Format.Number(player:GetAttribute("Coins") or 0)
		dailyBadge.Visible = player:GetAttribute("DailyReady") == true
		shopBadge.Visible = not player:GetAttribute("GotStarter")
		local mult = player:GetAttribute("CoinMultiplier") or 1
		multChip.Visible = mult > 1
		multChip.Text = `x{mult} COINS`
	end
	for _, attribute in { "Coins", "DailyReady", "GotStarter", "CoinMultiplier" } do
		player:GetAttributeChangedSignal(attribute):Connect(refreshStats)
	end
	refreshStats()
	player:GetAttributeChangedSignal("Area"):Connect(function()
		showArea(player:GetAttribute("Area"))
	end)

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
