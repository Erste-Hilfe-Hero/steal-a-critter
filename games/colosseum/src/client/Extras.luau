-- Neue Fenster und Anzeigen neben der Geschichte: Tagesaufgaben, Erfolge und Titel, Belohnungen (Bestiarium und
-- Spielzeit), Gluecksrad, Bestien-Hort, Trainerkarten, Einstellungen, Zielkompass, Schwarm-Anzeige,
-- Erfolgs-Banner und die Begleiter in der Welt. Alles skaliert wie die restliche Oberflaeche (UIScale).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)
local Progress = require(ReplicatedStorage.Shared.Progress)
local Format = require(ReplicatedStorage.Shared.Format)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Sounds = require(script.Parent.Sounds)
local Followers = require(script.Parent.Followers)

local C = Theme.Colors
local create = Theme.create
local label = Theme.label
local button = Theme.button

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Extras = {}

local state: any = nil -- letzter Zustand vom Server
local stateAt = 0 -- os.clock() beim Empfang (fuer Countdowns)
local redraw: (() -> ())? = nil -- zeichnet das offene Fenster neu, wenn neuer Zustand kommt
local tickers: { () -> boolean } = {} -- Countdown-Texte (false = entfernen)
local profileView: ((any) -> ())? = nil
local wheelView: ((number) -> ())? = nil
local overlayRoot: Frame
local bannerQueue = {}
local bannerRunning = false
local quietCoinsUntil = 0 -- waehrend das Rad dreht, den Gewinn nicht vorher verraten

---------------------------------------------------------------- Hilfen

local function act(kind: string, arg: any?, value: any?)
	remotes.ProgressAction:FireServer(kind, arg, value)
end

local function bundle(reward): string
	return Progress.BundleText(reward, Config.Items)
end

local function since(): number
	return os.clock() - stateAt
end

local function sessionSeconds(): number
	return if state then state.Session + since() else 0
end

local function spinLeft(): number
	return if state then math.max(0, state.SpinIn - since()) else math.huge
end

local function dexCount(): number
	local collection = UI.State.Collection
	if collection and collection.Dex then
		local n = 0
		for _ in collection.Dex do
			n += 1
		end
		return n
	end
	return if state then state.DexCount else 0
end

local function longTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	local hours = seconds // 3600
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, (seconds % 3600) // 60, seconds % 60)
	end
	return Format.Time(seconds)
end

local function addTicker(fn: () -> boolean)
	table.insert(tickers, fn)
	fn()
end

local function bar(parent: Instance, position: UDim2, size: UDim2, fraction: number, color: Color3?)
	local back, fill = Theme.hpBar({ Position = position, Size = size, Parent = parent })
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	fill.BackgroundColor3 = color or C.Gold
	return back
end

local function loading(parent: Instance)
	label({ Size = UDim2.fromScale(1, 1), Text = "Loading...", TextSize = 22, TextColor3 = C.Muted, Parent = parent })
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		child:Destroy()
	end
end

-- Fenster oeffnen; build zeichnet den Inhalt (auch spaeter bei neuem Zustand)
local function openWindow(title: string, width: number, height: number, build: (Frame) -> ())
	local frame, content = UI.Window(title, width, height)
	local function draw()
		if not frame.Parent then
			redraw = nil
			return
		end
		clear(content)
		build(content)
	end
	redraw = draw
	draw()
end

---------------------------------------------------------------- Abholbar? (rote Punkte an den Knoepfen)

local function questClaimable(): boolean
	if not state then
		return false
	end
	local allClaimed = #state.Quests > 0
	for _, quest in state.Quests do
		if not quest.Claimed then
			allClaimed = false
			if quest.Progress >= quest.Goal then
				return true
			end
		end
	end
	return allClaimed and not state.Bonus
end

local function moreClaimable(): boolean
	if not state then
		return false
	end
	local collection = UI.State.Collection
	if not collection or not collection.Started then
		return false
	end
	if spinLeft() <= 0 then
		return true
	end
	local session = sessionSeconds()
	for _, gift in Progress.Gifts do
		if not state.Gifts[gift.Key] and session >= gift.Minutes * 60 then
			return true
		end
	end
	local caught = dexCount()
	for _, milestone in Progress.DexMilestones do
		if not state.DexClaimed[milestone.Key] and caught >= milestone.Need then
			return true
		end
	end
	return false
end

---------------------------------------------------------------- Tagesaufgaben

local function buildQuests(content: Frame)
	if not state then
		loading(content)
		return
	end
	label({ Size = UDim2.new(0.6, 0, 0, 28), Text = "Daily quests: earn coins and orbs!", Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
	local timer = label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.new(0.4, 0, 0, 28), Text = "", TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right, Parent = content })
	addTicker(function()
		if not timer.Parent then
			return false
		end
		timer.Text = `New quests in {longTime(state.QuestReset - since())}`
		return true
	end)
	for index, quest in state.Quests do
		local done = quest.Progress >= quest.Goal
		local card = Theme.panel({ Position = UDim2.fromOffset(0, 36 + (index - 1) * 86), Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = if quest.Claimed then C.Panel else C.PanelDark, Parent = content })
		label({ Position = UDim2.fromOffset(16, 6), Size = UDim2.new(1, -210, 0, 28), Text = quest.Text, Font = Theme.Title, TextSize = 20, TextScaled = true, TextColor3 = if quest.Claimed then C.Muted else C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		bar(card, UDim2.fromOffset(16, 38), UDim2.new(1, -210, 0, 12), quest.Progress / math.max(1, quest.Goal), if done then C.Green else C.Gold)
		label({ Position = UDim2.fromOffset(16, 52), Size = UDim2.new(1, -210, 0, 20), Text = `{Format.Number(quest.Progress)} / {Format.Number(quest.Goal)}   ·   Reward: {quest.Reward}`, TextSize = 14, TextScaled = true, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		local claim = button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(170, 50),
			Text = if quest.Claimed then "DONE ✓" elseif done then "CLAIM!" else "IN PROGRESS",
			TextSize = if done and not quest.Claimed then 22 else 16,
			Color = if quest.Claimed then C.PanelLight elseif done then C.Green else C.Panel,
			AutoButtonColor = done and not quest.Claimed,
			Parent = card,
		})
		claim.Activated:Connect(function()
			if done and not quest.Claimed then
				act("ClaimQuest", index)
			end
		end)
	end
	-- Bonus fuer alle drei Aufgaben
	local y = 36 + #state.Quests * 86
	local allClaimed = #state.Quests > 0
	for _, quest in state.Quests do
		allClaimed = allClaimed and quest.Claimed
	end
	local bonusRow = Theme.panel({ Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = C.CrimsonDark, Parent = content })
	label({ Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -210, 1, 0), Text = `ALL 3 DONE BONUS: {bundle(Progress.QuestBonus)}`, Font = Theme.Title, TextSize = 17, TextScaled = true, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = bonusRow })
	local bonus = button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(170, 42),
		Text = if state.Bonus then "BONUS ✓" elseif allClaimed then "GET BONUS!" else "LOCKED",
		TextSize = 17,
		Color = if allClaimed and not state.Bonus then C.Green else C.PanelLight,
		Parent = bonusRow,
	})
	bonus.Activated:Connect(function()
		if allClaimed and not state.Bonus then
			act("ClaimBonus")
		end
	end)
	-- Robux-Abkuerzung, solange noch etwas offen ist
	local open = false
	for _, quest in state.Quests do
		open = open or quest.Progress < quest.Goal
	end
	label({ Position = UDim2.fromOffset(0, y + 62), Size = UDim2.new(0.5, 0, 0, 40), Text = `Quests completed: {Format.Number(state.QuestsDone)}`, TextSize = 16, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = content })
	if open then
		local product = Config.DevProducts.QuestFinish
		local finish = UI.PriceButton(product.PriceHint, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y + 62), Size = UDim2.fromOffset(320, 40), Text = `FINISH ALL NOW  R$ {product.PriceHint}`, TextSize = 17, Color = C.GoldDark, Parent = content })
		finish.Activated:Connect(function()
			UI.Buy("Product", "QuestFinish")
		end)
	end
end

function Extras.OpenQuests()
	openWindow("DAILY QUESTS", 740, 480, buildQuests)
end

---------------------------------------------------------------- Erfolge und Titel

local function buildAwards(body: Frame)
	local current = Progress.AchievementsById[state.Title]
	local unlocked = 0
	for _ in state.Achievements do
		unlocked += 1
	end
	label({ Size = UDim2.new(1, -190, 0, 36), RichText = true, Text = `Achievements {unlocked}/{#Progress.Achievements}   ·   Title: <font color="#F2C14E">{if current then current.Title else "none"}</font>`, Font = Theme.Title, TextSize = 19, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = body })
	if current then
		local remove = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 0), Size = UDim2.fromOffset(170, 36), Text = "REMOVE TITLE", TextSize = 15, Color = C.PanelLight, Parent = body })
		remove.Activated:Connect(function()
			act("SetTitle", "")
		end)
	end
	local holder = create("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1, Parent = body })
	local grid = UI.Grid(holder, Vector2.new(204, 124))
	for _, achievement in Progress.Achievements do
		local done = state.Achievements[achievement.Id] == true
		local value = Progress.AchievementValue(achievement, state.Stats or {}, state.Context or {})
		local goal = achievement.Min or 1
		local card = Theme.panel({ BackgroundColor3 = if done then C.PanelLight else C.PanelDark, LayoutOrder = achievement.Order, Parent = grid })
		label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 22), Text = (if done then "🏆 " else "") .. achievement.Name, Font = Theme.Title, TextSize = 17, TextScaled = true, TextColor3 = if done then C.Gold else C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		label({ Position = UDim2.fromOffset(10, 28), Size = UDim2.new(1, -20, 0, 30), Text = achievement.Desc, TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = card })
		if done then
			local equipped = state.Title == achievement.Id
			local equip = button({ Position = UDim2.new(0, 10, 1, -44), Size = UDim2.new(1, -20, 0, 36), Text = if equipped then `"{achievement.Title}" ✓` else `WEAR "{achievement.Title}"`, TextSize = 13, TextScaled = true, Color = if equipped then C.GoldDark else C.Blue, Parent = card })
			equip.Activated:Connect(function()
				if not equipped then
					act("SetTitle", achievement.Id)
				end
			end)
		else
			bar(card, UDim2.new(0, 10, 1, -40), UDim2.new(1, -20, 0, 10), value / goal, C.Gold)
			label({ Position = UDim2.new(0, 10, 1, -28), Size = UDim2.new(1, -20, 0, 22), Text = `{Format.Number(math.min(value, goal))}/{Format.Number(goal)}  ·  +{Format.Number(achievement.Coins)} coins`, TextSize = 13, TextScaled = true, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
		end
	end
end

---------------------------------------------------------------- Belohnungen (Bestiarium und Spielzeit)

local function rewardRow(parent: Instance, order: number, title: string, sub: string, buttonText: string, ready: boolean, done: boolean, onClaim: () -> ()): TextButton
	local row = Theme.panel({ Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = if done then C.Panel else C.PanelDark, LayoutOrder = order, Parent = parent })
	label({ Position = UDim2.fromOffset(14, 4), Size = UDim2.new(1, -210, 0, 26), Text = title, Font = Theme.Title, TextSize = 19, TextScaled = true, TextColor3 = if done then C.Muted else C.Cream, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	label({ Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -210, 0, 22), Text = sub, TextSize = 14, TextScaled = true, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local claim = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(170, 44), Text = buttonText, TextSize = 17, Color = if done then C.PanelLight elseif ready then C.Green else C.Panel, Parent = row })
	claim.Activated:Connect(function()
		if ready and not done then
			onClaim()
		end
	end)
	return claim
end

local function sectionTitle(parent: Instance, order: number, text: string)
	label({ Size = UDim2.new(1, -10, 0, 30), Text = text, Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order, Parent = parent })
end

local function buildRewards(body: Frame)
	local scroll = UI.Scrolling(body)
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local caught = dexCount()
	sectionTitle(scroll, 1, `BESTIARY REWARDS  ·  caught {caught}/{#Config.Beasts}`)
	for index, milestone in Progress.DexMilestones do
		local done = state.DexClaimed[milestone.Key] == true
		local ready = caught >= milestone.Need
		rewardRow(scroll, 1 + index, `Catch {milestone.Need} different beasts`, bundle(milestone.Reward), if done then "CLAIMED ✓" elseif ready then "CLAIM!" else `{caught}/{milestone.Need}`, ready, done, function()
			act("ClaimDex", milestone.Key)
		end)
	end
	sectionTitle(scroll, 20, "PLAYTIME GIFTS  ·  every visit")
	for index, gift in Progress.Gifts do
		local done = state.Gifts[gift.Key] == true
		local ready = sessionSeconds() >= gift.Minutes * 60
		local claim = rewardRow(scroll, 20 + index, `Play {gift.Minutes} minutes`, bundle(gift.Reward), if done then "CLAIMED ✓" elseif ready then "CLAIM!" else "", ready, done, function()
			act("ClaimGift", gift.Key)
		end)
		if not done and not ready then
			addTicker(function()
				if not claim.Parent then
					return false
				end
				local left = gift.Minutes * 60 - sessionSeconds()
				if left <= 0 then
					if redraw then
						task.defer(redraw)
					end
					return false
				end
				claim.Text = longTime(left)
				return true
			end)
		end
	end
end

---------------------------------------------------------------- Gluecksrad

local function buildWheel(body: Frame)
	local slots = {}
	local center = Vector2.new(290, 196)
	local radius = 158
	for index, slot in Progress.Wheel do
		local angle = (index - 1) / #Progress.Wheel * math.pi * 2 - math.pi / 2
		local tile = Theme.panel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(center.X + math.cos(angle) * radius * 1.25, center.Y + math.sin(angle) * radius),
			Size = UDim2.fromOffset(124, 52),
			BackgroundColor3 = slot.Color:Lerp(C.Ink, 0.55),
			Parent = body,
		})
		label({ Size = UDim2.fromScale(1, 1), Text = slot.Text, Font = Theme.Title, TextSize = 16, TextScaled = true, TextColor3 = C.Cream, Parent = tile })
		create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = tile })
		slots[index] = tile
	end
	local status = label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y - 44), Size = UDim2.fromOffset(220, 30), Text = "", TextSize = 16, TextColor3 = C.Muted, Parent = body })
	local spinButton = button({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y + 6), Size = UDim2.fromOffset(190, 64), Text = "SPIN!", TextSize = 30, Color = C.Crimson, Parent = body })
	local spinning = false
	addTicker(function()
		if not spinButton.Parent then
			return false
		end
		if not spinning then
			local left = spinLeft()
			status.Text = if left <= 0 then "Free spin ready!" else `Next free spin in {longTime(left)}`
			spinButton.AutoButtonColor = left <= 0
			spinButton.BackgroundColor3 = if left <= 0 then C.Crimson else C.PanelLight
		end
		return true
	end)
	spinButton.Activated:Connect(function()
		if spinning then
			return
		end
		if spinLeft() > 0 then
			UI.Toast("The Lucky Wheel is still recharging.", C.Muted)
			return
		end
		spinning = true
		status.Text = "Spinning..."
		act("Spin")
		task.delay(5, function()
			spinning = false -- falls der Server nicht antwortet
		end)
	end)
	-- Lauflicht ueber die Felder, wird langsamer und bleibt auf dem Gewinn stehen
	wheelView = function(index: number)
		spinning = true
		local steps = #Progress.Wheel * 3 + (index - 1)
		local delay = 0.04
		for step = 0, steps do
			if not body.Parent then
				break
			end
			for i, tile in slots do
				local stroke = tile:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Color = if i == step % #slots + 1 then C.Cream else C.Gold
					stroke.Thickness = if i == step % #slots + 1 then 5 else 2
				end
			end
			Sounds.Play("Tick")
			task.wait(delay)
			if step > steps - 10 then
				delay *= 1.28
			end
		end
		local slot = Progress.Wheel[index]
		Sounds.Play("Reward")
		UI.Toast(`Lucky Wheel: you won {slot.Text}!`, C.Gold)
		spinning = false
	end
	-- Rechts: Gewinne mit Chancen
	local info = Theme.panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(250, 384), BackgroundColor3 = C.PanelDark, Parent = body })
	label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 30), Text = "FREE LUCKY WHEEL", Font = Theme.Title, TextSize = 20, TextColor3 = C.Gold, Parent = info })
	label({ Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 36), Text = "One free spin every 6 hours. No Robux needed!", TextSize = 13, TextColor3 = C.Cream, Parent = info })
	local total = 0
	for _, slot in Progress.Wheel do
		total += slot.Weight
	end
	for index, slot in Progress.Wheel do
		label({ Position = UDim2.fromOffset(14, 76 + (index - 1) * 33), Size = UDim2.new(1, -28, 0, 28), RichText = true, Text = `{slot.Text}  <font color="#B9A59B">{Format.Percent(slot.Weight / total * 100)}</font>`, TextSize = 15, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = info })
	end
end

---------------------------------------------------------------- Bestien-Hort

local function buildDaycare(body: Frame)
	local daycare = state.Daycare
	local panel = Theme.panel({ Size = UDim2.new(0, 300, 1, -4), BackgroundColor3 = C.PanelDark, Parent = body })
	local text = create("Frame", { Position = UDim2.fromOffset(316, 0), Size = UDim2.new(1, -320, 1, 0), BackgroundTransparency = 1, Parent = body })
	label({ Size = UDim2.new(1, 0, 0, 34), Text = "BEAST DAYCARE", Font = Theme.Title, TextSize = 28, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = text })
	label({ Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 66), Text = `Leave one beast here. It trains while you play AND while you are offline (up to {Progress.DaycareMaxMinutes // 60} hours). Higher levels earn more XP.`, TextSize = 16, TextColor3 = C.Cream, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = text })
	if daycare then
		local def = Config.BeastsById[daycare.S]
		Theme.viewport(daycare.S, daycare.L, daycare.Sh, { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -60), Parent = panel })
		label({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 34), Text = `{if daycare.Sh then "✦ " else ""}{def.Name}  Lv {daycare.L}`, Font = Theme.Title, TextSize = 24, TextScaled = true, TextColor3 = if daycare.Sh then C.Prism else C.Cream, Parent = panel })
		local progressText = label({ Position = UDim2.fromOffset(0, 112), Size = UDim2.new(1, 0, 0, 60), RichText = true, Text = "", TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = text })
		addTicker(function()
			if not progressText.Parent then
				return false
			end
			local minutes = math.min(Progress.DaycareMaxMinutes, daycare.Minutes + math.floor(since() / 60))
			progressText.Text = `Training time: <font color="#F2C14E">{minutes} min</font> of {Progress.DaycareMaxMinutes} max\nXP waiting: <font color="#F2C14E">{Format.Number(Progress.DaycareXp(daycare.L, minutes))}</font>`
			return true
		end)
		local pick = button({ Position = UDim2.fromOffset(0, 190), Size = UDim2.fromOffset(260, 56), Text = "PICK UP", TextSize = 24, Color = C.Green, Parent = text })
		pick.Activated:Connect(function()
			act("Collect")
		end)
	else
		label({ Size = UDim2.fromScale(1, 1), Text = "The daycare is empty", TextSize = 20, TextColor3 = C.Muted, Parent = panel })
		local leave = button({ Position = UDim2.fromOffset(0, 120), Size = UDim2.fromOffset(300, 56), Text = "LEAVE A BEAST", TextSize = 24, Color = C.Crimson, Parent = text })
		leave.Activated:Connect(function()
			local collection = UI.State.Collection
			if not collection then
				return
			end
			local list = {}
			for uid, beast in collection.Beasts do
				table.insert(list, { Uid = uid, Beast = beast })
			end
			table.sort(list, function(a, b)
				return a.Beast.L > b.Beast.L
			end)
			local entries = {}
			for _, item in list do
				local def = Config.BeastsById[item.Beast.S]
				local inTeam = table.find(collection.Team, item.Uid) ~= nil
				local lastMember = inTeam and #collection.Team <= 1
				table.insert(entries, {
					Text = `{if item.Beast.Sh then "✦ " else ""}{def.Name}  Lv{item.Beast.L}`,
					Sub = if lastMember then "your last team member" elseif inTeam then "from your team" else "from your box",
					Color = Config.Types[def.Type].Color:Lerp(C.Ink, 0.45),
					Disabled = lastMember or item.Beast.L >= Config.MaxLevel,
					OnPick = function()
						act("Deposit", item.Uid)
					end,
				})
			end
			UI.Chooser("WHO SHOULD TRAIN?", entries)
		end)
	end
end

---------------------------------------------------------------- Trainerkarten

local function drawProfile(panel: Frame, card)
	clear(panel)
	Theme.corner(panel, 12)
	Theme.stroke(panel, C.Gold, 2, 0.15)
	local name = label({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 38), Text = (if card.Champion then "👑 " else "") .. card.Name, Font = Theme.Title, TextSize = 32, TextScaled = true, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	Theme.textStroke(name, 2)
	label({ Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 22), Text = `@{card.User}  ·  {card.Rank}` .. (if card.Title ~= "" then `  ·  "{card.Title}"` else ""), TextSize = 16, TextScaled = true, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local stats = {
		{ "BADGES", `{card.Badges}/8` },
		{ "CAUGHT", `{card.Caught}/{#Config.Beasts}` },
		{ "SEEN", tostring(card.Seen) },
		{ "WINS", Format.Number(card.Wins) },
		{ "BEST WAVE", tostring(card.BestWave) },
		{ "TROPHIES", Format.Number(card.Trophies) },
		{ "PLAY TIME", `{card.Hours} h` },
		{ "AWARDS", `{card.Achievements}/{#Progress.Achievements}` },
	}
	local grid = create("Frame", { Position = UDim2.fromOffset(16, 76), Size = UDim2.new(1, -32, 0, 120), BackgroundTransparency = 1, Parent = panel })
	create("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 54), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for index, stat in stats do
		local cell = create("Frame", { BackgroundColor3 = C.Panel, LayoutOrder = index, Parent = grid })
		Theme.corner(cell, 8)
		label({ Size = UDim2.new(1, 0, 0, 20), Text = stat[1], TextSize = 12, TextColor3 = C.Muted, Parent = cell })
		label({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 30), Text = stat[2], Font = Theme.Title, TextSize = 22, TextScaled = true, TextColor3 = C.Cream, Parent = cell })
	end
	label({ Position = UDim2.fromOffset(16, 204), Size = UDim2.new(1, -32, 0, 24), Text = "TEAM", Font = Theme.Title, TextSize = 18, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local row = create("Frame", { Position = UDim2.fromOffset(16, 230), Size = UDim2.new(1, -32, 0, 76), BackgroundTransparency = 1, Parent = panel })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = row })
	for _, beast in card.Team do
		local cell = create("Frame", { Size = UDim2.fromOffset(72, 76), BackgroundTransparency = 1, Parent = row })
		Theme.beastIcon(beast.S, beast.Sh, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(48, 48), Parent = cell })
		label({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 24), Text = `Lv {beast.L}`, TextSize = 14, TextColor3 = C.Cream, Parent = cell })
	end
end

local function buildTrainers(body: Frame)
	local listArea = create("Frame", { Size = UDim2.new(0, 240, 1, 0), BackgroundTransparency = 1, Parent = body })
	local scroll = UI.Scrolling(listArea)
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	local panel = Theme.panel({ Position = UDim2.fromOffset(252, 0), Size = UDim2.new(1, -256, 1, -4), BackgroundColor3 = C.PanelDark, Parent = body })
	label({ Size = UDim2.fromScale(1, 1), Text = "Loading trainer card...", TextSize = 18, TextColor3 = C.Muted, Parent = panel })
	profileView = function(card)
		if panel.Parent then
			drawProfile(panel, card)
		end
	end
	local others = Players:GetPlayers()
	table.sort(others, function(a, b)
		if a == player or b == player then
			return a == player
		end
		return a.DisplayName:lower() < b.DisplayName:lower()
	end)
	for order, other in others do
		local entry = button({ Size = UDim2.new(1, -10, 0, 46), Text = if other == player then "YOU" else other.DisplayName, TextSize = 18, TextScaled = true, Color = if other == player then C.GoldDark else C.PanelLight, LayoutOrder = order, Parent = scroll })
		entry.Activated:Connect(function()
			if other.Parent then
				act("Profile", other)
			end
		end)
	end
	act("Profile", player)
end

---------------------------------------------------------------- Einstellungen

local function buildSettings(body: Frame)
	local scroll = UI.Scrolling(body)
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	for order, key in Progress.SettingOrder do
		local on = state.Settings[key] ~= false
		local text = Progress.SettingText[key]
		local row = Theme.panel({ Size = UDim2.new(1, -10, 0, 60), BackgroundColor3 = C.PanelDark, LayoutOrder = order, Parent = scroll })
		label({ Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -180, 0, 28), Text = text[1], Font = Theme.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		label({ Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -180, 0, 22), Text = text[2], TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local toggle = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 44), Text = if on then "ON" else "OFF", TextSize = 22, Color = if on then C.Green else C.PanelLight, Parent = row })
		toggle.Activated:Connect(function()
			state.Settings[key] = not on
			act("Setting", key, not on)
			if redraw then
				redraw()
			end
		end)
	end
	label({ Size = UDim2.new(1, -10, 0, 40), Text = "Settings are saved with your progress.", TextSize = 15, TextColor3 = C.Muted, LayoutOrder = 99, Parent = scroll })
end

---------------------------------------------------------------- Sammel-Fenster "MORE"

local MORE_TABS = { "AWARDS", "REWARDS", "WHEEL", "DAYCARE", "TRAINERS", "SETTINGS" }
local MORE_BUILD = {
	AWARDS = buildAwards,
	REWARDS = buildRewards,
	WHEEL = buildWheel,
	DAYCARE = buildDaycare,
	TRAINERS = buildTrainers,
	SETTINGS = buildSettings,
}

function Extras.OpenMore(startTab: string?)
	local frame, content = UI.Window("MORE", 900, 520)
	local current = startTab or "AWARDS"
	local body: Frame? = nil
	local function draw()
		if not frame.Parent then
			redraw = nil
			return
		end
		local target = body
		if not target or not target.Parent then
			return
		end
		clear(target)
		wheelView = nil
		profileView = nil
		if not state then
			loading(target)
			return
		end
		MORE_BUILD[current](target)
	end
	UI.Tabs(content, MORE_TABS, function(name, tabBody)
		current = name
		body = tabBody
		draw()
	end, current, 136)
	-- Neuer Zustand: nur Tabs mit Zahlen neu zeichnen (Rad und Karten nicht unterbrechen)
	redraw = function()
		if current ~= "WHEEL" and current ~= "TRAINERS" then
			draw()
		elseif not frame.Parent then
			redraw = nil
		end
	end
end

---------------------------------------------------------------- Erfolgs-Banner

local function runBanners()
	if bannerRunning then
		return
	end
	bannerRunning = true
	while #bannerQueue > 0 do
		local achievement = table.remove(bannerQueue, 1)
		local card = Theme.panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -110), Size = UDim2.fromOffset(460, 92), BackgroundColor3 = C.Panel, Parent = overlayRoot })
		local ribbon = create("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.GoldDark, Parent = card })
		Theme.corner(ribbon, 12)
		label({ Size = UDim2.fromScale(1, 1), Text = "🏆 ACHIEVEMENT UNLOCKED", Font = Theme.Title, TextSize = 18, TextColor3 = C.Ink, Parent = ribbon })
		label({ Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 30), Text = achievement.Name, Font = Theme.Title, TextSize = 26, TextScaled = true, TextColor3 = C.Gold, Parent = card })
		label({ Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 24), Text = `+{Format.Number(achievement.Coins)} coins  ·  new title "{achievement.Title}" (MORE > AWARDS)`, TextSize = 15, TextScaled = true, TextColor3 = C.Cream, Parent = card })
		Sounds.Play("Achievement")
		TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 64) }):Play()
		task.wait(4)
		TweenService:Create(card, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -110) }):Play()
		task.wait(0.35)
		card:Destroy()
	end
	bannerRunning = false
end

---------------------------------------------------------------- Kompass und Schwarm

local function buildCompass(): (Frame, TextLabel, TextLabel)
	local frame = create("TextButton", { Position = UDim2.fromOffset(418, 66), Size = UDim2.fromOffset(230, 44), BackgroundColor3 = C.PanelDark, BackgroundTransparency = 0.1, AutoButtonColor = true, Text = "", Visible = false, Parent = UI.Hud() })
	Theme.corner(frame, 12)
	Theme.stroke(frame, C.GoldDark, 1.5)
	local arrow = label({ Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(36, 36), Text = "➤", Font = Theme.Title, TextSize = 28, TextColor3 = C.Gold, Parent = frame })
	local text = label({ Position = UDim2.fromOffset(46, 2), Size = UDim2.new(1, -52, 1, -4), Text = "", TextSize = 15, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	frame.Activated:Connect(UI.OpenMap)
	return frame, arrow, text
end

local function updateCompass(frame: Frame, arrow: TextLabel, text: TextLabel)
	local collection = UI.State.Collection
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	local area = collection and collection.ObjectiveArea and Story.AreasById[collection.ObjectiveArea]
	if player:GetAttribute("Set_Compass") == false or not area or not root or not camera then
		frame.Visible = false
		return
	end
	frame.Visible = true
	if player:GetAttribute("Area") == area.Id then
		arrow.Text = "★"
		arrow.Rotation = 0
		text.Text = `You reached {area.Name}!`
		return
	end
	arrow.Text = "➤"
	local offset = Vector3.new(area.Center.X - root.Position.X, 0, area.Center.Z - root.Position.Z)
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local forward = Vector3.new(look.X, 0, look.Z)
	local side = Vector3.new(right.X, 0, right.Z)
	if forward.Magnitude > 0.01 and side.Magnitude > 0.01 then
		local x = offset:Dot(side.Unit)
		local y = offset:Dot(forward.Unit)
		-- "➤" zeigt nach rechts, 0 Grad = Ziel liegt geradeaus (oben)
		arrow.Rotation = math.deg(math.atan2(x, y)) - 90
	end
	text.Text = `{area.Name}  ·  {Format.Number(offset.Magnitude)} studs`
end

local function updateSwarm(chip: TextLabel)
	local left = (workspace:GetAttribute("SwarmUntil") or 0) - workspace:GetServerTimeNow()
	local beast = Config.BeastsById[workspace:GetAttribute("SwarmBeast") or ""]
	local area = Story.AreasById[workspace:GetAttribute("SwarmArea") or ""]
	chip.Visible = left > 0 and beast ~= nil and area ~= nil
	if chip.Visible then
		chip.Text = `SWARM: {beast.Name} on {area.Name} {Format.Time(left)}`
	end
end

---------------------------------------------------------------- Start

function Extras.Init()
	Followers.Init()

	-- Eigene Ebene fuer Banner (auch waehrend Kaempfen sichtbar)
	local gui = create("ScreenGui", { Name = "Extras", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7, Parent = player:WaitForChild("PlayerGui") })
	overlayRoot = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local scale = create("UIScale", { Parent = overlayRoot })
	local function rescale()
		local size = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.55, 1.3)
		scale.Scale = s
		overlayRoot.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

	-- Zwei neue Menue-Knoepfe unter den bestehenden
	local questButton, questBadge = UI.AddMenuButton("📜", "QUESTS", Color3.fromRGB(110, 90, 200), 9)
	local moreButton, moreBadge = UI.AddMenuButton("✨", "MORE", Color3.fromRGB(60, 150, 160), 10)
	questButton.Activated:Connect(Extras.OpenQuests)
	moreButton.Activated:Connect(function()
		Extras.OpenMore()
	end)

	local swarmChip = UI.AddChip(4, Color3.fromRGB(120, 230, 255))
	local compass, compassArrow, compassText = buildCompass()

	remotes.Progress.OnClientEvent:Connect(function(kind, payload)
		if kind == "State" then
			state = payload
			stateAt = os.clock()
			if redraw then
				task.spawn(redraw)
			end
		elseif kind == "Achievement" then
			local achievement = Progress.AchievementsById[payload]
			if achievement then
				table.insert(bannerQueue, achievement)
				task.spawn(runBanners)
			end
		elseif kind == "QuestDone" then
			Sounds.Play("Quest")
		elseif kind == "Wheel" and typeof(payload) == "number" then
			quietCoinsUntil = os.clock() + 5
			local view = wheelView
			if view then
				task.spawn(view, payload)
			else
				local slot = Progress.Wheel[payload]
				Sounds.Play("Reward")
				UI.Toast(`Lucky Wheel: you won {slot and slot.Text or "a prize"}!`, C.Gold)
			end
		elseif kind == "Profile" then
			if profileView then
				profileView(payload)
			end
		elseif kind == "PostEvents" and typeof(payload) == "table" then
			UI.ShowPostBattle(payload)
		end
	end)

	-- Belohnungs-Sound, wenn Muenzen steigen (nicht beim ersten Laden)
	local lastCoins = player:GetAttribute("Coins")
	player:GetAttributeChangedSignal("Coins"):Connect(function()
		local coins = player:GetAttribute("Coins") or 0
		if typeof(lastCoins) == "number" and coins > lastCoins and os.clock() > quietCoinsUntil then
			Sounds.Play("Reward")
		end
		lastCoins = coins
	end)

	-- Countdowns, rote Punkte und Schwarm jede halbe Sekunde
	task.spawn(function()
		while gui.Parent do
			for index = #tickers, 1, -1 do
				local ok, keep = pcall(tickers[index])
				if not ok or not keep then
					table.remove(tickers, index)
				end
			end
			questBadge.Visible = questClaimable()
			moreBadge.Visible = moreClaimable()
			updateSwarm(swarmChip)
			task.wait(0.5)
		end
	end)

	-- Kompass fluessig drehen
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.08 then
			return
		end
		acc = 0
		local ok, err = pcall(updateCompass, compass, compassArrow, compassText)
		if not ok then
			compass.Visible = false
			warn("[Compass]", err)
		end
	end)
end

return Extras
