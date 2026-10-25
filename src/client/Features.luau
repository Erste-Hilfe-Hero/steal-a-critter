-- Fenster fuer Update 3 im MORE-Menue: Eier, Training, Perks, Critter Pass, Spieler, Statistiken, Einstellungen.
-- Baut auf den Bausteinen von Hub.luau auf; der Server schickt den Stand in state.Features (FeatureService).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Format = require(game:GetService("ReplicatedStorage").Shared.Format)

local player = Players.LocalPlayer

local Features = {}

local GREEN_TEXT = Color3.fromRGB(120, 255, 140)

function Features.Start(api)
	local THEME = api.Theme
	local create, text, button = api.Create, api.Text, api.Button
	local corner, edge = api.Corner, api.Edge
	local TITLE_FONT = api.TitleFont

	local function features()
		local state = api.GetState()
		return state and state.Features
	end

	-- Anfrage senden; Erfolgsmeldung gruen anzeigen (Fehler zeigt api.Invoke selbst)
	local function act(action: string, arg: any?, onDone: ((boolean, string?, any) -> ())?)
		task.spawn(function()
			local ok, message, extra = api.Invoke(action, arg)
			if ok and message then
				api.Toast(message, GREEN_TEXT)
			end
			if onDone then
				onDone(ok, message, extra)
			end
		end)
	end

	local function listPage(name: string, title: string, color: Color3)
		local page = api.AddPage(name, title, color, true)
		api.ListLayout(Enum.FillDirection.Vertical, 8).Parent = page.Frame
		create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8), Parent = page.Frame })
		return page
	end

	local function row(parent: Instance, order: number, height: number?): Frame
		return create("Frame", {
			Size = UDim2.new(1, 0, 0, height or 64),
			BackgroundColor3 = THEME.Row,
			LayoutOrder = order,
			Parent = parent,
		}, { corner(12), edge() }) :: Frame
	end

	local function rowTitle(parent: Instance, title: string, subtitle: string, color: Color3?, width: number)
		text({
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -width - 24, 0, 26),
			Text = title,
			Font = TITLE_FONT,
			TextSize = 19,
			TextColor3 = color or THEME.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = parent,
		})
		text({
			Position = UDim2.fromOffset(12, 33),
			Size = UDim2.new(1, -width - 24, 0, 22),
			Text = subtitle,
			TextSize = 15,
			TextColor3 = THEME.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = parent,
		})
	end

	-- Knopf rechts in einer Zeile (index 1 = ganz rechts)
	local function rowButton(parent: Instance, index: number, width: number, label: string, color: Color3, enabled: boolean, onClick: () -> ()): TextButton
		local result = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10 - (index - 1) * (width + 8), 0.5, 0),
			Size = UDim2.fromOffset(width, 44),
			Text = label,
			TextSize = 16,
			Parent = parent,
		}, color)
		api.SetEnabled(result, enabled, color)
		result.Activated:Connect(function()
			if result.Active then
				onClick()
			end
		end)
		return result
	end

	local function header(parent: Instance, order: number, message: string, color: Color3?)
		return text({
			Size = UDim2.new(1, 0, 0, 40),
			Text = message,
			TextSize = 16,
			TextColor3 = color or THEME.Muted,
			TextWrapped = true,
			LayoutOrder = order,
			Parent = parent,
		})
	end

	-- Seiten nur neu aufbauen, wenn sich ihr Inhalt geaendert hat (sonst springt die Liste)
	local function refresher(page, build: (any) -> (), pick: (any) -> any)
		local last = ""
		page.Refresh = function()
			local f = features()
			if not f then
				return
			end
			local ok, signature = pcall(HttpService.JSONEncode, HttpService, pick(f))
			signature = if ok then signature else tostring(os.clock())
			if signature == last then
				return
			end
			last = signature
			api.Clear(page.Frame)
			build(f)
		end
		return function()
			last = ""
		end
	end

	---------------------------------------------------------------- Eier

	local eggPage = api.AddPage("Eggs", "🥚 CRITTER EGGS", Color3.fromRGB(80, 150, 220), false)
	local eggGrid = create("Frame", { Size = UDim2.new(1, 0, 0, 240), BackgroundTransparency = 1, Parent = eggPage.Frame }, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(196, 236), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local hatchResult = text({
		Position = UDim2.fromOffset(0, 242),
		Size = UDim2.new(1, 0, 0, 32),
		Text = "Eggs cost cash only. Your critter goes straight to your base!",
		Font = TITLE_FONT,
		TextSize = 18,
		TextColor3 = THEME.Muted,
		TextWrapped = true,
		Parent = eggPage.Frame,
	})
	for order, egg in Config.Eggs do
		local card = create("Frame", { BackgroundColor3 = THEME.Row, LayoutOrder = order, Parent = eggGrid }, { corner(14), edge() })
		create("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = egg.Color, BorderSizePixel = 0, Parent = card }, { corner(3) })
		text({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 52), Text = egg.Icon, TextSize = 44, Parent = card })
		text({ Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 26), Text = egg.Name, Font = TITLE_FONT, TextSize = 21, Parent = card })
		local odds = {}
		local total = 0
		for _, weight in egg.Weights do
			total += weight
		end
		for _, rarity in Config.Rarities do
			local weight = egg.Weights[rarity.Name]
			if weight then
				table.insert(odds, `<font color="#{rarity.Color:ToHex()}">{rarity.Name}</font> {math.floor(weight / total * 1000 + 0.5) / 10}%`)
			end
		end
		text({
			Position = UDim2.fromOffset(10, 94),
			Size = UDim2.new(1, -20, 0, 82),
			Text = table.concat(odds, "\n"),
			RichText = true,
			TextSize = 15,
			TextColor3 = THEME.Muted,
			Parent = card,
		})
		local hatchButton = button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -10),
			Size = UDim2.new(1, -20, 0, 46),
			Text = "HATCH  " .. Format.Cash(egg.Price),
			TextSize = 18,
			Parent = card,
		}, THEME.Green)
		hatchButton.Activated:Connect(function()
			hatchResult.Text = "🥚 Hatching..."
			hatchResult.TextColor3 = THEME.Gold
			act("BuyEgg", egg.Id, function(ok, _, extra)
				if ok and extra then
					local rarity = Config.RaritiesByName[extra.Rarity]
					hatchResult.Text = `🎉 You hatched {extra.Name} ({extra.Rarity})!`
					hatchResult.TextColor3 = if rarity then rarity.Color else THEME.Gold
				else
					hatchResult.Text = "Eggs cost cash only. Your critter goes straight to your base!"
					hatchResult.TextColor3 = THEME.Muted
				end
			end)
		end)
	end

	-- Gratis-Ei alle 12 Stunden (Update 4, ExtraService)
	local freeEggButton = button({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 280),
		Size = UDim2.fromOffset(340, 46),
		Text = "🎁 FREE EGG",
		TextSize = 19,
		Parent = eggPage.Frame,
	}, THEME.Pink)
	local function freeEggLeft(): number?
		local state = api.GetState()
		local extras = state and state.Extras
		if not extras then
			return nil
		end
		return (extras.FreeEggAt or 0) - api.ServerNow()
	end
	local function updateFreeEgg()
		local left = freeEggLeft()
		local ready = left ~= nil and left <= 0
		freeEggButton.Text = if left == nil then "..." elseif ready then `🎁 HATCH FREE {string.upper(Config.FreeEggId)} EGG` else `🎁 Free egg in {api.LongTime(left)}`
		api.SetEnabled(freeEggButton, ready, THEME.Pink)
	end
	freeEggButton.Activated:Connect(function()
		if not freeEggButton.Active then
			return
		end
		api.SetEnabled(freeEggButton, false, THEME.Pink)
		hatchResult.Text = "🥚 Hatching..."
		hatchResult.TextColor3 = THEME.Gold
		act("FreeEgg", nil, function(ok, _, extra)
			if ok and extra then
				local rarity = Config.RaritiesByName[extra.Rarity]
				hatchResult.Text = `🎉 You hatched {extra.Name} ({extra.Rarity})!`
				hatchResult.TextColor3 = if rarity then rarity.Color else THEME.Gold
			else
				hatchResult.Text = "Eggs cost cash only. Your critter goes straight to your base!"
				hatchResult.TextColor3 = THEME.Muted
			end
		end)
	end)
	eggPage.Refresh = updateFreeEgg
	task.spawn(function()
		while true do
			task.wait(1)
			if api.IsOpen("Eggs") then
				updateFreeEgg()
			end
		end
	end)

	---------------------------------------------------------------- Training und Tresor

	local trainPage = listPage("Train", "🏋️ TRAIN & PROTECT", THEME.Orange)
	refresher(trainPage, function(f)
		header(trainPage.Frame, 0, `Each training level gives +{math.floor(Config.TrainBonusPer * 100)}% income for that critter (max {Config.TrainMaxLevel}). A vaulted critter can't be stolen.`)
		local alarm = row(trainPage.Frame, 1)
		rowTitle(alarm, "🚨 Base Alarm", if f.Alarm then "Installed! Thieves are slowed and everyone is warned." else "Thieves get slowed and everyone is warned", if f.Alarm then THEME.Cash else nil, 150)
		rowButton(alarm, 1, 140, if f.Alarm then "✓ OWNED" else Format.Cash(Config.AlarmPrice), THEME.Red, not f.Alarm, function()
			act("BuyAlarm")
		end)
		-- Schnell-Verkauf (Update 4): einfache Kreaturen auf einmal loswerden, Favoriten bleiben
		local quick = row(trainPage.Frame, 2)
		rowTitle(quick, "🧹 Quick sell", "Sells plain critters (keeps ❤, trained, mutated, fused)", nil, 290)
		for index, rarityName in Config.BulkSellRarities do
			local rarity = Config.RaritiesByName[rarityName]
			rowButton(quick, #Config.BulkSellRarities - index + 1, 140, `ALL {string.upper(rarityName)}`, if rarity then rarity.Color:Lerp(Color3.new(0, 0, 0), 0.35) else THEME.Gray, true, function()
				act("SellBulk", rarityName)
			end)
		end
		if #f.Units == 0 then
			header(trainPage.Frame, 3, "Buy critters on the belt or hatch eggs first!", THEME.Gold)
		end
		for order, unit in f.Units do
			local line = row(trainPage.Frame, 10 + order)
			local rarity = Config.RaritiesByName[unit.Rarity]
			local stars = string.rep("⭐", unit.Level)
			rowTitle(line, unit.Name .. (if unit.Vault then "  🔒" else "") .. (if unit.Favorite then "  ❤" else ""), `+{Format.Cash(unit.Income)}/s  {stars}`, rarity and rarity.Color, 350)
			-- Favorit: kann nicht verkauft werden (Herz an/aus)
			local heart = rowButton(line, 1, 52, if unit.Favorite then "❤" else "♡", if unit.Favorite then THEME.Pink else THEME.Gray, true, function()
				act("Favorite", unit.Slot)
			end)
			-- links neben den beiden 140er-Knoepfen
			heart.Position = UDim2.new(1, -10 - 2 * (140 + 8), 0.5, 0)
			heart.TextSize = 22
			local maxed = unit.Level >= Config.TrainMaxLevel
			rowButton(line, 1, 140, if unit.Vault then "🔒 SAFE" else "🔒 " .. Format.Cash(unit.VaultCost), THEME.Blue, not unit.Vault, function()
				act("Vault", unit.Slot)
			end)
			rowButton(line, 2, 140, if maxed then "MAX" else "⬆ " .. Format.Cash(unit.TrainCost), THEME.Green, not maxed, function()
				act("Train", unit.Slot)
			end)
		end
	end, function(f)
		return { f.Units, f.Alarm }
	end)

	---------------------------------------------------------------- Perks und Basis-Farbe

	local perkPage = listPage("Perks", "♻️ REBIRTH PERKS", THEME.Purple)
	refresher(perkPage, function(f)
		header(perkPage.Frame, 0, `You have {f.Tokens} Rebirth Token{if f.Tokens == 1 then "" else "s"}. Every rebirth gives 1 token. Perks last forever!`, THEME.Gold)
		for order, perk in Config.Perks do
			local level = f.Perks[perk.Id] or 0
			local line = row(perkPage.Frame, order)
			local dots = string.rep("●", level) .. string.rep("○", perk.Max - level)
			rowTitle(line, `{perk.Icon} {perk.Name}  {dots}`, perk.Text, nil, 150)
			local maxed = level >= perk.Max
			rowButton(line, 1, 140, if maxed then "MAX" else `{level + 1} TOKEN{if level == 0 then "" else "S"}`, THEME.Purple, not maxed and f.Tokens >= level + 1, function()
				act("BuyPerk", perk.Id)
			end)
		end
		header(perkPage.Frame, 20, `🎨 BASE COLOR  ·  {Format.Cash(Config.BaseColorPrice)} each`, THEME.Text)
		local swatches = create("Frame", { Size = UDim2.new(1, 0, 0, 108), BackgroundTransparency = 1, LayoutOrder = 21, Parent = perkPage.Frame }, {
			create("UIGridLayout", { CellSize = UDim2.fromOffset(140, 50), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for order, entry in Config.BaseColors do
			local selected = f.BaseColor == entry.Name
			local swatch = button({ Text = if selected then "✓ " .. entry.Name else entry.Name, TextSize = 16, LayoutOrder = order, Parent = swatches }, entry.Color)
			create("UIStroke", { Thickness = 1.5, Color = THEME.Outline, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = swatch })
			swatch.Activated:Connect(function()
				if not selected then
					act("SetBaseColor", entry.Name)
				end
			end)
		end
	end, function(f)
		return { f.Tokens, f.Perks, f.BaseColor }
	end)

	---------------------------------------------------------------- Critter Pass

	local passPage = listPage("Pass", "🎫 CRITTER PASS  ·  FREE", Color3.fromRGB(170, 90, 230))
	local function passClaimable(): boolean
		local f = features()
		return f ~= nil and f.PassClaimed < f.PassTier
	end
	refresher(passPage, function(f)
		local top = create("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1, LayoutOrder = 0, Parent = passPage.Frame })
		text({
			Size = UDim2.new(1, 0, 0, 26),
			Text = if f.PassTier >= Config.PassTiers then "MAX TIER! You finished the pass." else `Tier {f.PassTier} / {Config.PassTiers}  ·  earn XP by playing`,
			TextSize = 16,
			TextColor3 = THEME.Muted,
			Parent = top,
		})
		local fill, label = api.ProgressBar(top, { Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 26) }, Color3.fromRGB(170, 90, 230))
		fill.Size = UDim2.fromScale(if f.PassTier >= Config.PassTiers then 1 else math.clamp(f.PassXPIn / math.max(f.PassXPNeed, 1), 0, 1), 1)
		label.Text = if f.PassTier >= Config.PassTiers then "COMPLETE" else `{f.PassXPIn} / {f.PassXPNeed} XP`
		for tier = 1, Config.PassTiers do
			local line = row(passPage.Frame, tier, 54)
			local claimed = tier <= f.PassClaimed
			local unlocked = tier <= f.PassTier
			local nextOne = tier == f.PassClaimed + 1
			text({
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -170, 1, 0),
				Text = `Tier {tier}  ·  {f.PassRewards[tier] or "?"}`,
				Font = TITLE_FONT,
				TextSize = 18,
				TextColor3 = if claimed then THEME.Muted elseif unlocked then THEME.Gold else THEME.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = line,
			})
			rowButton(line, 1, 140, if claimed then "✓ DONE" elseif unlocked then "CLAIM" else "🔒", THEME.Green, unlocked and nextOne and not claimed, function()
				act("ClaimPass")
			end)
		end
	end, function(f)
		return { f.PassXP, f.PassClaimed, f.PassRewards }
	end)

	---------------------------------------------------------------- Spieler: Likes, Besuchen, Schenken

	local playersPage = listPage("Players", "👥 PLAYERS", THEME.Blue)
	local rebuildPlayers = refresher(playersPage, function(f)
		header(playersPage.Frame, 0, `Like bases (+{math.floor(Config.LikeBonusPer * 100)}% income for them), visit them or gift cash ({f.GiftsLeft} gifts left today). Your base has {f.Likes} ❤️`, THEME.Muted)
		local others = {}
		for _, other in Players:GetPlayers() do
			if other ~= player then
				table.insert(others, other)
			end
		end
		table.sort(others, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
		if #others == 0 then
			header(playersPage.Frame, 1, "You're alone here - tap INVITE to bring friends!", THEME.Gold)
		end
		for order, other in others do
			local line = row(playersPage.Frame, order)
			local likedToday = f.Liked[tostring(other.UserId)] == true
			rowTitle(line, other.DisplayName, `{other:GetAttribute("Rank") or "Newbie"}  ·  +{Format.Cash(other:GetAttribute("IncomePerSec") or 0)}/s`, nil, 330)
			local userId = other.UserId
			rowButton(line, 1, 100, "🎁 GIFT", THEME.Green, f.GiftsLeft > 0, function()
				act("Gift", userId)
			end)
			rowButton(line, 2, 100, "VISIT", THEME.Blue, true, function()
				act("Visit", userId, function(ok)
					if ok then
						api.Close()
					end
				end)
			end)
			rowButton(line, 3, 100, if likedToday then "❤️ ✓" else "❤️ LIKE", THEME.Pink, not likedToday, function()
				act("Like", userId)
			end)
		end
	end, function(f)
		local names = {}
		for _, other in Players:GetPlayers() do
			table.insert(names, other.UserId)
		end
		return { f.Liked, f.GiftsLeft, f.Likes, names }
	end)
	Players.PlayerAdded:Connect(rebuildPlayers)
	Players.PlayerRemoving:Connect(rebuildPlayers)

	---------------------------------------------------------------- Statistiken

	local statsPage = api.AddPage("Stats", "📊 MY STATS", THEME.Teal, true)
	create("UIGridLayout", { CellSize = UDim2.fromOffset(196, 84), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = statsPage.Frame })
	refresher(statsPage, function(f)
		local state = api.GetState()
		local stats = state and state.Stats or {}
		local entries = {
			{ "💰", "Total earned", Format.Cash(f.Earned) },
			{ "⏱️", "Play time", api.LongTime(f.PlayTime) },
			{ "♻️", "Rebirths", tostring(f.Rebirths) },
			{ "🦝", "Critters stolen", tostring(stats.Stolen or 0) },
			{ "🛒", "Critters bought", tostring(stats.Bought or 0) },
			{ "🥚", "Eggs hatched", tostring(stats.Hatched or 0) },
			{ "✨", "Fusions", tostring(stats.Fused or 0) },
			{ "👋", "Slaps", tostring(stats.Slaps or 0) },
			{ "👹", "Bosses beaten", tostring(stats.Bosses or 0) },
			{ "💎", "Gems found", tostring(stats.Gems or 0) },
			{ "❤️", "Base likes", tostring(f.Likes) },
			{ "💌", "Friends invited", tostring(f.Referrals) },
		}
		for order, entry in entries do
			local tile = create("Frame", { BackgroundColor3 = THEME.Row, LayoutOrder = order, Parent = statsPage.Frame }, { corner(12), edge() })
			text({ Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(40, 40), Text = entry[1], TextSize = 28, Parent = tile })
			text({ Position = UDim2.fromOffset(56, 8), Size = UDim2.new(1, -64, 0, 34), Text = entry[3], Font = TITLE_FONT, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = tile })
			text({ Position = UDim2.fromOffset(10, 52), Size = UDim2.new(1, -20, 0, 22), Text = entry[2], TextSize = 14, TextColor3 = THEME.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = tile })
		end
	end, function(f)
		local state = api.GetState()
		return { f.Earned, f.Likes, f.Rebirths, state and state.Stats }
	end)

	---------------------------------------------------------------- Einstellungen

	local settings = { Labels = "All", Hints = "On", Detail = "High", Buddy = "On", Sounds = "On" }

	-- Namensschilder: alle, nur eigene (plus Laufband) oder keine
	local function applyLabel(gui: Instance)
		if not gui:IsA("BillboardGui") or gui.Name ~= "Info" then
			return
		end
		local model = gui.Parent and gui.Parent.Parent
		local owner = model and model:GetAttribute("OwnerUserId")
		gui.Enabled = settings.Labels == "All" or (settings.Labels == "Mine" and (owner == nil or owner == player.UserId))
	end
	local EFFECTS = { Aura = true, VoidSmoke = true }
	local function applyEffect(instance: Instance)
		if (instance:IsA("ParticleEmitter") and EFFECTS[instance.Name]) or instance:IsA("Fire") then
			(instance :: any).Enabled = settings.Detail ~= "Low"
		end
	end
	local function applyAll()
		player:SetAttribute("HideHints", settings.Hints == "Off")
		player:SetAttribute("SoundsOff", settings.Sounds == "Off")
		for _, instance in workspace:GetDescendants() do
			applyLabel(instance)
			applyEffect(instance)
		end
	end
	workspace.DescendantAdded:Connect(function(instance)
		if instance:IsA("BillboardGui") then
			-- Das Model bekommt OwnerUserId erst kurz nach dem Schild
			task.defer(applyLabel, instance)
		elseif settings.Detail == "Low" then
			applyEffect(instance)
		end
	end)

	local settingsPage = listPage("Settings", "⚙️ SETTINGS", THEME.Gray)
	local OPTIONS = {
		{ Key = "Labels", Title = "🏷️ Name tags", Text = "Hide tags so they don't cover the critters", Values = { "All", "Mine", "Off" } },
		{ Key = "Hints", Title = "💬 Hint bar", Text = "Event, boss and bonus hints at the bottom", Values = { "On", "Off" } },
		{ Key = "Detail", Title = "✨ Effects", Text = "Low = no sparkles and fire (faster on phones)", Values = { "High", "Low" } },
		{ Key = "Buddy", Title = "🐾 Buddy", Text = `Your best critter follows you (+{math.floor(Config.BuddyBonus * 100)}% income)`, Values = { "On", "Off" } },
		{ Key = "Sounds", Title = "🔊 Sounds", Text = "Sound effects for buying, stealing and rewards", Values = { "On", "Off" } },
	}
	local rebuildSettings = refresher(settingsPage, function()
		for order, option in OPTIONS do
			local line = row(settingsPage.Frame, order)
			rowTitle(line, option.Title, option.Text, nil, #option.Values * 88)
			for index, value in option.Values do
				local selected = settings[option.Key] == value
				local choice = rowButton(line, #option.Values - index + 1, 80, value, if selected then THEME.Green else THEME.Row, true, function()
					settings[option.Key] = value
					applyAll()
					act("SaveSettings", { [option.Key] = value })
					settingsPage.Refresh()
				end)
				if not selected then
					choice.TextColor3 = THEME.Muted
				end
			end
		end
	end, function()
		return settings
	end)

	-- Gespeicherte Einstellungen vom Server uebernehmen (einmal nach dem ersten Stand)
	local loaded = false
	task.spawn(function()
		while not loaded do
			local f = features()
			if f and f.Settings then
				for key, value in f.Settings do
					settings[key] = value
				end
				loaded = true
				applyAll()
				rebuildSettings()
			end
			task.wait(1)
		end
	end)

	---------------------------------------------------------------- Kacheln im MORE-Menue

	api.AddMoreTile("Eggs", "🥚", "EGGS", Color3.fromRGB(80, 150, 220), 1, function()
		local left = freeEggLeft()
		return left ~= nil and left <= 0
	end)
	api.AddMoreTile("Train", "🏋️", "TRAIN", THEME.Orange, 2)
	api.AddMoreTile("Pass", "🎫", "PASS", Color3.fromRGB(170, 90, 230), 3, passClaimable)
	api.AddMoreTile("Perks", "♻️", "PERKS", THEME.Purple, 4, function()
		local f = features()
		if not f then
			return false
		end
		for _, perk in Config.Perks do
			local level = f.Perks[perk.Id] or 0
			if level < perk.Max and f.Tokens >= level + 1 then
				return true
			end
		end
		return false
	end)
	api.AddMoreTile("Players", "👥", "PLAYERS", THEME.Blue, 5)
	api.AddMoreTile("Stats", "📊", "STATS", THEME.Teal, 20)
	api.AddMoreTile("Settings", "⚙️", "SETTINGS", THEME.Gray, 21)
end

return Features
