-- Update 4 auf dem Client: Einfuehrung mit Pfeil, Abstimmung ueber das naechste Event, Dieb-Radar, Trampoline,
-- Soundeffekte und die Fenster WEEKLY, TRIPS, TITLES, DECOR und LOG im MORE-Menue.
-- Der Server schickt den Stand in state.Extras (ExtraService); Fenster kommen ueber die Hub-API.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Windows = require(script.Parent.Windows)
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Extras = {}

local GREEN_TEXT = Color3.fromRGB(120, 255, 140)
local BASE_SIZE = Vector2.new(1000, 560)

local titlesById = {}
for _, title in Config.Titles do
	titlesById[title.Id] = title
end

-- "vor 5 min" fuer das Protokoll
local function ago(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		return `{seconds // 60}m ago`
	elseif seconds < 86400 then
		return `{seconds // 3600}h ago`
	end
	return `{seconds // 86400}d ago`
end

function Extras.Start(api)
	local THEME = api.Theme
	local create, text, button = api.Create, api.Text, api.Button
	local corner, edge = api.Corner, api.Edge
	local TITLE_FONT = api.TitleFont

	remotes:WaitForChild("Sfx").OnClientEvent:Connect(Sfx.Play)

	local function extras()
		local state = api.GetState()
		return state and state.Extras
	end

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

	---------------------------------------------------------------- Bausteine (wie in Features.luau)

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

	local function rowTitle(parent: Instance, title: string, subtitle: string, color: Color3?, width: number): TextLabel
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
		return text({
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

	local function header(parent: Instance, order: number, message: string, color: Color3?): TextLabel
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

	-- Seite nur neu bauen, wenn sich der Inhalt geaendert hat; tick() laeuft jede Sekunde, solange sie offen ist
	local function refresher(name: string, page, build: (any) -> (), pick: (any) -> any, tick: (() -> ())?)
		local last = ""
		page.Refresh = function()
			local e = extras()
			if not e then
				return
			end
			local ok, signature = pcall(HttpService.JSONEncode, HttpService, pick(e))
			signature = if ok then signature else tostring(os.clock())
			if signature ~= last then
				last = signature
				api.Clear(page.Frame)
				build(e)
			end
			if tick then
				tick()
			end
		end
		if tick then
			task.spawn(function()
				while true do
					task.wait(1)
					if api.IsOpen(name) then
						tick()
					end
				end
			end)
		end
	end

	---------------------------------------------------------------- Wochen-Quests

	local weeklyPage = listPage("Weekly", "📅 WEEKLY QUESTS", Color3.fromRGB(110, 90, 230))
	local weeklyTimer: TextLabel? = nil
	local function weeklyClaimable(): boolean
		local e = extras()
		if not e then
			return false
		end
		for _, quest in e.Weekly do
			if not quest.Claimed and quest.Progress >= quest.Goal then
				return true
			end
		end
		return false
	end
	refresher("Weekly", weeklyPage, function(e)
		weeklyTimer = header(weeklyPage.Frame, 0, "", THEME.Muted)
		for order, quest in e.Weekly do
			local line = row(weeklyPage.Frame, order, 76)
			text({
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -150, 0, 26),
				Text = quest.Text,
				Font = TITLE_FONT,
				TextSize = 19,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = line,
			})
			local fill, label = api.ProgressBar(line, { Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -150, 0, 24) }, Color3.fromRGB(110, 90, 230))
			fill.Size = UDim2.fromScale(math.clamp(quest.Progress / math.max(quest.Goal, 1), 0, 1), 1)
			label.Text = `{Format.Number(quest.Progress)} / {Format.Number(quest.Goal)}   ·   {Format.Cash(quest.Reward)}`
			local done = quest.Progress >= quest.Goal
			rowButton(line, 1, 118, if quest.Claimed then "✓ DONE" elseif done then "CLAIM" else "...", THEME.Green, done and not quest.Claimed, function()
				act("ClaimWeekly", quest.Index)
			end)
		end
		header(weeklyPage.Frame, 10, if e.WeeklyBonusClaimed then "✅ All weekly quests done! New ones on Monday." else "Finish all 3 for a BONUS: +1 Rebirth Token and a Fusion Catalyst!", THEME.Gold)
	end, function(e)
		return { e.Weekly, e.WeeklyBonusClaimed }
	end, function()
		local e = extras()
		if weeklyTimer and weeklyTimer.Parent and e then
			weeklyTimer.Text = `Big quests for the whole week  ·  new quests in {api.LongTime(e.WeeklyEnds - api.ServerNow())}`
		end
	end)

	---------------------------------------------------------------- Expeditionen

	local tripsPage = listPage("Trips", "🧭 EXPEDITIONS", Color3.fromRGB(40, 160, 120))
	local tripTimers = {} -- { Label, Button, Ends }
	local function tripsReady(): boolean
		local e = extras()
		if not e then
			return false
		end
		for _, trip in e.Expeditions do
			if trip.Ends <= api.ServerNow() then
				return true
			end
		end
		return false
	end
	refresher("Trips", tripsPage, function(e)
		table.clear(tripTimers)
		header(tripsPage.Frame, 0, `Send a critter on a trip: it can't be stolen, earns cash and may come back GOLDEN or better! Max {Config.MaxExpeditions} at once.`)
		for order, trip in e.Expeditions do
			local line = row(tripsPage.Frame, order)
			local rarity = Config.RaritiesByName[trip.Rarity]
			local status = rowTitle(line, `🧭 {trip.Name}`, "", rarity and rarity.Color, 150)
			local claim = rowButton(line, 1, 140, "...", THEME.Green, false, function()
				act("ClaimExpedition", trip.Index)
			end)
			table.insert(tripTimers, { Label = status, Button = claim, Ends = trip.Ends, Trip = trip.Trip, Cash = trip.Cash })
		end
		local f = api.GetState() and api.GetState().Features
		local units = f and f.Units or {}
		local full = #e.Expeditions >= Config.MaxExpeditions
		header(tripsPage.Frame, 10, if full then "All explorers are out. Claim them when they are back!" elseif #units == 0 then "You have no critters at home to send." else "Pick a critter and a trip:", THEME.Gold)
		for order, unit in units do
			if order > 8 then
				break
			end
			local line = row(tripsPage.Frame, 20 + order)
			local rarity = Config.RaritiesByName[unit.Rarity]
			rowTitle(line, unit.Name, if unit.Vault then "🔒 In your vault (stays home)" else `+{Format.Cash(unit.Income)}/s`, rarity and rarity.Color, 3 * 88)
			for index, trip in Config.Expeditions do
				local caption = if trip.Minutes >= 60 then `{trip.Minutes // 60}h` else `{trip.Minutes}m`
				rowButton(line, #Config.Expeditions - index + 1, 80, caption, THEME.Teal, not full and not unit.Vault, function()
					act("SendExpedition", { Slot = unit.Slot, Trip = trip.Id })
				end)
			end
		end
	end, function(e)
		local f = api.GetState() and api.GetState().Features
		return { e.Expeditions, f and f.Units }
	end, function()
		local now = api.ServerNow()
		for _, entry in tripTimers do
			if entry.Label.Parent then
				local left = entry.Ends - now
				entry.Label.Text = if left <= 0 then `{entry.Trip}  ·  back with {Format.Cash(entry.Cash)}!` else `{entry.Trip}  ·  back in {api.LongTime(left)}`
				entry.Button.Text = if left <= 0 then "CLAIM" else api.LongTime(left)
				api.SetEnabled(entry.Button, left <= 0, THEME.Green)
			end
		end
	end)

	---------------------------------------------------------------- Titel

	local titlesPage = listPage("Titles", "🏷️ TITLES", Color3.fromRGB(200, 120, 60))
	refresher("Titles", titlesPage, function(e)
		local current = titlesById[e.Title]
		header(titlesPage.Frame, 0, if current then `Wearing: "{current.Name}". Titles show above your name.` else "Unlock titles by playing and wear one above your name!", THEME.Gold)
		for order, title in e.Titles do
			local line = row(titlesPage.Frame, order)
			local config = titlesById[title.Id]
			local color = if title.Unlocked and config then config.Color else THEME.Muted
			local progress = if title.Unlocked then "Unlocked!" else `{title.Text}  ·  {Format.Number(title.Progress)} / {Format.Number(title.Goal)}`
			rowTitle(line, (if title.Unlocked then "🏷️ " else "🔒 ") .. title.Name, progress, color, 150)
			local wearing = e.Title == title.Id
			rowButton(line, 1, 140, if wearing then "REMOVE" elseif title.Unlocked then "WEAR" else "🔒", if wearing then THEME.Gray else THEME.Orange, title.Unlocked, function()
				act("SetTitle", if wearing then "" else title.Id)
			end)
		end
	end, function(e)
		return { e.Titles, e.Title }
	end)

	---------------------------------------------------------------- Basis-Deko

	local decorPage = listPage("Decor", "🌷 BASE DECOR", Color3.fromRGB(70, 170, 110))
	refresher("Decor", decorPage, function(e)
		header(decorPage.Frame, 0, "Make your base look awesome! Decorations stay forever and everyone can see them.")
		for order, decor in Config.Decorations do
			local owned = e.Decor[decor.Id] == true
			local line = row(decorPage.Frame, order)
			rowTitle(line, `{decor.Icon} {decor.Name}`, if owned then "Placed in your base" else Format.Cash(decor.Price), if owned then THEME.Cash else nil, 150)
			rowButton(line, 1, 140, if owned then "✓ OWNED" else "BUY", THEME.Green, not owned, function()
				act("BuyDecor", decor.Id)
			end)
		end
	end, function(e)
		return e.Decor
	end)

	---------------------------------------------------------------- Diebstahl-Protokoll

	local logPage = listPage("Log", "🦝 THEFT LOG", Color3.fromRGB(200, 70, 80))
	local LOG_TEXT = {
		Lost = { "🦝", "%s stole your %s", Color3.fromRGB(255, 120, 120) },
		Stole = { "💰", "You stole %s from %s", Color3.fromRGB(120, 255, 140) },
		Saved = { "🛡️", "%s slapped a thief and saved your %s", Color3.fromRGB(120, 200, 255) },
		Defended = { "👋", "You slapped %s and kept your %s", Color3.fromRGB(120, 200, 255) },
	}
	refresher("Log", logPage, function(e)
		if #e.TheftLog == 0 then
			header(logPage.Frame, 0, "Nothing happened yet. Lock your base and keep your Slap ready!", THEME.Gold)
			return
		end
		header(logPage.Frame, 0, "Your latest thefts and defenses. Got robbed? You have 90s of REVENGE!")
		local now = api.ServerNow()
		for order, entry in e.TheftLog do
			local style = LOG_TEXT[entry.Kind] or LOG_TEXT.Lost
			local message = if entry.Kind == "Stole" then string.format(style[2], entry.Critter, entry.Who) else string.format(style[2], entry.Who, entry.Critter)
			local line = row(logPage.Frame, order, 52)
			text({
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.new(1, -110, 1, 0),
				Text = `{style[1]}  {message}`,
				TextSize = 17,
				TextColor3 = style[3],
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				Parent = line,
			})
			text({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 0),
				Size = UDim2.new(0, 90, 1, 0),
				Text = ago(now - (entry.At or now)),
				TextSize = 14,
				TextColor3 = THEME.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = line,
			})
		end
	end, function(e)
		return e.TheftLog
	end)

	api.AddMoreTile("Weekly", "📅", "WEEKLY", Color3.fromRGB(110, 90, 230), 6, weeklyClaimable)
	api.AddMoreTile("Trips", "🧭", "TRIPS", Color3.fromRGB(40, 160, 120), 7, tripsReady)
	api.AddMoreTile("Titles", "🏷️", "TITLES", Color3.fromRGB(200, 120, 60), 8)
	api.AddMoreTile("Decor", "🌷", "DECOR", Color3.fromRGB(70, 170, 110), 9)
	api.AddMoreTile("Log", "🦝", "LOG", Color3.fromRGB(200, 70, 80), 19)

	---------------------------------------------------------------- Eigene Ebene fuer Einfuehrung und Abstimmung

	local gui = create("ScreenGui", {
		Name = "Extras",
		ResetOnSpawn = false,
		DisplayOrder = 1,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	local uiScale = create("UIScale", {}) :: UIScale
	local root = create("Frame", {
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
	-- Solange ein Fenster offen ist, liegt hier nichts darueber (eine Sache zur Zeit)
	Windows.OnChanged(function(open)
		root.Visible = not open
	end)

	---------------------------------------------------------------- Einfuehrung: Karte links (unter dem Menue) und Pfeil in der Welt
	-- Unterhalb der Ansage-Zeile (Bildschirmmitte) und oberhalb des Joysticks

	local tutorialCard = create("Frame", {
		Position = UDim2.fromOffset(10, 252),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
	}, { corner(12), api.Padding(10, 8), create("UIStroke", { Thickness = 1.5, Color = THEME.Gold, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), api.ListLayout(Enum.FillDirection.Vertical, 4) }) :: Frame
	local tutorialTitle = text({ Size = UDim2.new(1, 0, 0, 20), Text = "", Font = TITLE_FONT, TextSize = 16, TextColor3 = THEME.Gold, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = tutorialCard })
	local tutorialText = text({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = "", TextSize = 16, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = tutorialCard })
	local tutorialFooter = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 3, Parent = tutorialCard })
	local tutorialReward = text({ Size = UDim2.new(1, -70, 1, 0), Text = "", TextSize = 14, TextColor3 = THEME.Cash, TextXAlignment = Enum.TextXAlignment.Left, Parent = tutorialFooter })
	local skipButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(62, 28), Text = "SKIP", TextSize = 13, Parent = tutorialFooter }, THEME.Gray)
	skipButton.Activated:Connect(function()
		act("SkipTutorial")
	end)

	-- Pfeil: Beam vom eigenen Charakter zum Ziel, dazu ein Schild "HERE" ueber dem Ziel
	local targetPart = create("Part", {
		Name = "TutorialTarget",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.one,
	}) :: Part
	local targetAttachment = create("Attachment", { Parent = targetPart }) :: Attachment
	local targetSign = create("BillboardGui", { Size = UDim2.fromOffset(110, 36), StudsOffset = Vector3.new(0, 4, 0), AlwaysOnTop = true, Parent = targetPart }, {
		text({ Size = UDim2.fromScale(1, 1), Text = "⬇ HERE ⬇", Font = TITLE_FONT, TextSize = 22, TextColor3 = THEME.Gold }, 2),
	})
	local beam = create("Beam", {
		Attachment1 = targetAttachment,
		Color = ColorSequence.new(THEME.Gold),
		Transparency = NumberSequence.new(0.25),
		Width0 = 0.7,
		Width1 = 0.7,
		FaceCamera = true,
		LightEmission = 0.6,
		Segments = 12,
		CurveSize0 = 4,
		CurveSize1 = -4,
		Parent = targetPart,
	}) :: Beam
	local function rootPart(): BasePart?
		local character = player.Character
		return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	local function myAttachment(): Attachment?
		local root = rootPart()
		if not root then
			return nil
		end
		local attachment = root:FindFirstChild("GuideAttachment") :: Attachment?
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = "GuideAttachment"
			attachment.Parent = root
		end
		return attachment
	end

	-- Zielposition fuer einen Schritt (nil = kein Pfeil)
	local function targetFor(kind: string?): Vector3?
		local world = workspace:FindFirstChild("World")
		local root = rootPart()
		if not world or not root or not kind then
			return nil
		end
		if kind == "Belt" then
			local conveyor = world:FindFirstChild("Conveyor") :: BasePart?
			if conveyor then
				local half = conveyor.Size.X / 2 - 4
				local x = math.clamp(root.Position.X, conveyor.Position.X - half, conveyor.Position.X + half)
				return Vector3.new(x, conveyor.Position.Y + 2, conveyor.Position.Z)
			end
		elseif kind == "Lock" then
			local plots = world:FindFirstChild("Plots")
			local plot = plots and plots:FindFirstChild(player:GetAttribute("PlotName") or "")
			local lockButton = plot and plot:FindFirstChild("LockButton") :: BasePart?
			if lockButton then
				return lockButton.Position + Vector3.new(0, 1, 0)
			end
		elseif kind == "Steal" then
			-- Naechste fremde Kreatur in einer Basis
			local plots = world:FindFirstChild("Plots")
			local best, bestDistance = nil, math.huge
			for _, plot in (if plots then plots:GetChildren() else {}) do
				for _, model in plot:GetChildren() do
					local owner = model:IsA("Model") and model:GetAttribute("OwnerUserId")
					if owner and owner ~= player.UserId and model.PrimaryPart then
						local distance = (model.PrimaryPart.Position - root.Position).Magnitude
						if distance < bestDistance then
							best, bestDistance = model.PrimaryPart.Position, distance
						end
					end
				end
			end
			return best
		end
		return nil
	end

	task.spawn(function()
		while gui.Parent do
			local e = extras()
			local step = e and Config.TutorialSteps[(e.Tutorial or 0) + 1]
			tutorialCard.Visible = step ~= nil
			local target = nil
			if step then
				tutorialTitle.Text = `TUTORIAL  {e.Tutorial + 1}/{#Config.TutorialSteps}`
				tutorialText.Text = step.Text
				tutorialReward.Text = `Reward: {Format.Cash(step.Cash)}`
				target = targetFor(step.Target)
			end
			local attachment = myAttachment()
			if target and attachment and not Windows.IsOpen() then
				targetPart.Position = target
				beam.Attachment0 = attachment
				targetPart.Parent = workspace
			else
				targetPart.Parent = nil
			end
			task.wait(0.5)
		end
	end)

	---------------------------------------------------------------- Abstimmung ueber das naechste Event (rechts, unter den Hub-Knoepfen)

	local voteCard = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 252),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = THEME.PanelDark,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = root,
	}, { corner(12), api.Padding(8, 8), create("UIStroke", { Thickness = 1.5, Color = THEME.Blue, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), api.ListLayout(Enum.FillDirection.Vertical, 5) }) :: Frame
	local voteTitle = text({ Size = UDim2.new(1, 0, 0, 20), Text = "", Font = TITLE_FONT, TextSize = 15, TextColor3 = Color3.fromRGB(150, 200, 255), LayoutOrder = 0, Parent = voteCard })
	local voteButtons = {}
	local myVote = 0
	local myVoteRound = 0
	for index = 1, Config.EventVoteOptions do
		local option = button({ Size = UDim2.new(1, 0, 0, 32), Text = "", TextSize = 14, LayoutOrder = index, Parent = voteCard }, THEME.Row)
		option.Activated:Connect(function()
			myVote = index
			myVoteRound = workspace:GetAttribute("VoteEnds") or 0
			act("VoteEvent", index)
		end)
		voteButtons[index] = option
	end
	task.spawn(function()
		while gui.Parent do
			local ends = workspace:GetAttribute("VoteEnds")
			local names = string.split(workspace:GetAttribute("VoteOptions") or "", "|")
			local counts = string.split(workspace:GetAttribute("VoteCounts") or "", "|")
			local active = ends ~= nil and ends > workspace:GetServerTimeNow() and #names >= 1 and names[1] ~= ""
			voteCard.Visible = active
			if active then
				if myVoteRound ~= ends then
					myVote = 0
				end
				voteTitle.Text = `🗳️ NEXT EVENT  ·  {math.ceil(ends - workspace:GetServerTimeNow())}s`
				for index, option in voteButtons do
					local name = names[index]
					option.Visible = name ~= nil
					if name then
						option.Text = `{name}  ({counts[index] or "0"})`
						option.BackgroundColor3 = if myVote == index then THEME.Blue else THEME.Row
					end
				end
			end
			task.wait(0.25)
		end
	end)

	---------------------------------------------------------------- Dieb-Radar: Pfeil zum Dieb, der gerade bei mir klaut

	local radar = {} -- [Player] = { Attach, Beam, Label, Root }
	local function clearRadar(thief: Player)
		local entry = radar[thief]
		if entry then
			-- Beam und Schild haengen am Attachment im Dieb
			entry.Attach:Destroy()
			radar[thief] = nil
		end
	end
	task.spawn(function()
		while gui.Parent do
			local myAttach = myAttachment()
			local myRoot = rootPart()
			for _, other in Players:GetPlayers() do
				local thiefRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local stealing = other ~= player and other:GetAttribute("StealingFrom") == player.UserId
				if stealing and thiefRoot and myAttach and myRoot then
					local entry = radar[other]
					if not entry or not entry.Beam.Parent or entry.Root ~= thiefRoot then
						clearRadar(other)
						local thiefAttach = Instance.new("Attachment")
						thiefAttach.Name = "RadarAttachment"
						thiefAttach.Parent = thiefRoot
						local radarBeam = create("Beam", {
							Attachment0 = myAttach,
							Attachment1 = thiefAttach,
							Color = ColorSequence.new(Color3.fromRGB(255, 70, 70)),
							Transparency = NumberSequence.new(0.3),
							Width0 = 0.5,
							Width1 = 0.5,
							FaceCamera = true,
							LightEmission = 0.8,
							Parent = thiefAttach,
						})
						local sign = create("BillboardGui", { Size = UDim2.fromOffset(150, 34), StudsOffset = Vector3.new(0, 6, 0), AlwaysOnTop = true, Parent = thiefAttach })
						local label = text({ Size = UDim2.fromScale(1, 1), Text = "", Font = TITLE_FONT, TextSize = 20, TextColor3 = Color3.fromRGB(255, 90, 90), Parent = sign }, 2)
						entry = { Attach = thiefAttach, Beam = radarBeam, Label = label, Root = thiefRoot }
						radar[other] = entry
					end
					entry.Label.Text = `🚨 THIEF  {math.floor((thiefRoot.Position - myRoot.Position).Magnitude)}m`
				else
					clearRadar(other)
				end
			end
			for thief in radar do
				if not thief.Parent then
					clearRadar(thief)
				end
			end
			task.wait(0.2)
		end
	end)

	---------------------------------------------------------------- Trampoline (der eigene Client springt, die Physik gehoert ihm)

	local lastBounce = 0
	local function setupTrampoline(pad: Instance)
		if not pad:IsA("BasePart") then
			return
		end
		(pad :: BasePart).Touched:Connect(function(hit)
			local character = player.Character
			local root = rootPart()
			if not character or not root or not hit:IsDescendantOf(character) then
				return
			end
			local now = os.clock()
			if now - lastBounce < 0.6 then
				return
			end
			lastBounce = now
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, Config.TrampolinePower, velocity.Z)
			Sfx.Play("Jump")
		end)
	end
	for _, pad in CollectionService:GetTagged("Trampoline") do
		setupTrampoline(pad)
	end
	CollectionService:GetInstanceAddedSignal("Trampoline"):Connect(setupTrampoline)
end

return Extras
