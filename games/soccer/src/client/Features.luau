-- Client fuer die neuen Features: Gluecksrad, Schnell-Chat, "Mehr"-Menue mit Erfolgen (und Wochen-
-- Herausforderung), Profil (Rang, Rekorde, letzte Matches), Codes, Torjubel-Effekte und Anleitung,
-- dazu die Modus-Abstimmung im Ergebnis-Fenster, Freunde-Bonus-Anzeige und drehende Muenzen/Orbs.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local Features = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Kit = UI.Kit
local C = Config.Colors
local BODY = Config.BodyFont
local SOFT = Color3.fromRGB(215, 222, 245)

local remote: RemoteEvent
local state = nil :: any -- letzter Zustand vom Server
local refreshers = {} -- Funktionen, die nach einem neuen Zustand laufen

local function onState(fn: () -> ())
	table.insert(refreshers, fn)
end

local function applyState()
	if not state then
		return
	end
	for _, fn in refreshers do
		task.spawn(fn)
	end
end

local function clear(parent: Instance)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function duration(seconds: number): string
	local days = seconds // 86400
	local hours = (seconds % 86400) // 3600
	if days > 0 then
		return `{days}d {hours}h`
	end
	return `{hours}h {(seconds % 3600) // 60}m`
end

local function listFrame(parent: Instance, position: UDim2, size: UDim2, padding: number?): ScrollingFrame
	return Kit.create("ScrollingFrame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.Lime,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Kit.create("UIListLayout", { Padding = UDim.new(0, padding or 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		Kit.create("UIPadding", { PaddingRight = UDim.new(0, 8) }),
	}) :: ScrollingFrame
end

local function bar(parent: Instance, position: UDim2, size: UDim2, fraction: number, color: Color3)
	local back = Kit.create("Frame", { Position = position, Size = size, BackgroundColor3 = C.Navy, Parent = parent }, { Kit.corner(6) })
	Kit.create("Frame", { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color, Parent = back }, { Kit.corner(6) })
	return back
end

---------------------------------------------------------------- Gluecksrad

local spinTiles = {}
local spinResult: TextLabel
local spinButton: TextButton
local spinning = false
local spinBadge: TextLabel

local function refreshSpinButton()
	if spinning then
		return
	end
	local free = state and state.SpinFree
	spinButton.Text = if free then "FREE SPIN!" else `SPIN  {Format.Number(Config.SpinPrice)} COINS`
	spinButton.BackgroundColor3 = if free then Kit.GREEN else C.Gold
	spinButton.TextColor3 = if free then C.White else C.Navy
	if spinBadge then
		spinBadge.Visible = free == true
	end
end

local function buildSpin()
	local _, body = Kit.window("Spin", "DAILY SPIN", Vector2.new(560, 420))
	Kit.label({ Size = UDim2.new(1, 0, 0, 26), Text = "One free spin every day! Extra spins cost coins.", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = body })
	local holder = Kit.create("Frame", { Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 156), BackgroundTransparency = 1, Parent = body }, {
		Kit.create("UIGridLayout", { CellSize = UDim2.fromOffset(125, 72), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, prize in Config.SpinPrizes do
		local tile = Kit.create("Frame", { BackgroundColor3 = C.NavyLight, LayoutOrder = index, Parent = holder }, { Kit.corner(10), Kit.stroke(C.Navy, 3) })
		Kit.label({ Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), Text = prize.Text, TextColor3 = if prize.Coins then C.Gold else C.Cyan, Parent = tile })
		spinTiles[index] = tile
	end
	spinResult = Kit.label({ Position = UDim2.fromOffset(0, 200), Size = UDim2.new(1, 0, 0, 40), Text = "", TextColor3 = C.Lime, Parent = body })
	spinButton = Kit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(300, 56), Text = "" }, Kit.GREEN)
	spinButton.Parent = body
	spinButton.MouseButton1Click:Connect(function()
		if spinning or not state then
			return
		end
		if not state.SpinFree and (player:GetAttribute("Coins") or 0) < Config.SpinPrice then
			UI.ShowOffer("Coins")
			return
		end
		spinning = true
		spinButton.Text = "SPINNING..."
		spinResult.Text = ""
		remote:FireServer("Spin", not state.SpinFree)
		-- Sicherheitsnetz, falls keine Antwort kommt
		task.delay(6, function()
			if spinning then
				spinning = false
				refreshSpinButton()
			end
		end)
	end)
	onState(refreshSpinButton)
end

local function highlight(index: number)
	for i, tile in spinTiles do
		local s = tile:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = if i == index then C.Lime else C.Navy
		end
		tile.BackgroundColor3 = if i == index then Color3.fromRGB(60, 80, 140) else C.NavyLight
	end
end

-- Lauflicht ueber die Felder, wird langsamer und bleibt auf dem Gewinn stehen
local function playSpin(info)
	if not info.Ok then
		spinning = false
		spinResult.Text = info.Text
		spinResult.TextColor3 = C.Orange
		refreshSpinButton()
		return
	end
	task.spawn(function()
		local count = #spinTiles
		local steps = count * 3 + (info.Index - 1)
		for step = 0, steps do
			highlight(step % count + 1)
			Sounds.Play("Beep", nil, 1 + (step / steps) * 0.5, 0.25)
			task.wait(0.04 + (step / steps) ^ 2 * 0.22)
		end
		highlight(info.Index)
		spinResult.Text = `YOU WON: {info.Text}!`
		spinResult.TextColor3 = C.Lime
		Kit.pop(spinResult)
		Sounds.Play("LevelUp")
		spinning = false
		refreshSpinButton()
	end)
end

---------------------------------------------------------------- Schnell-Chat

local lastChat = 0
local function buildChat()
	local _, body = Kit.window("Chat", "QUICK CHAT", Vector2.new(440, 330))
	local holder = Kit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = body }, {
		Kit.create("UIGridLayout", { CellSize = UDim2.fromOffset(200, 54), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, text in Config.QuickChat do
		local b = Kit.button({ Text = text, LayoutOrder = index, Parent = holder }, if index % 2 == 1 then C.Cyan else C.Orange)
		b.MouseButton1Click:Connect(function()
			if os.clock() - lastChat < Config.QuickChatCooldown then
				UI.Toast("Wait a moment!", C.Orange)
				return
			end
			lastChat = os.clock()
			remote:FireServer("Chat", index)
			UI.Open("Chat")
		end)
	end
end

---------------------------------------------------------------- Erfolge und Wochen-Herausforderung

local STAT_TEXT = { Goals = "goals", Assists = "assists", KOs = "knockouts", Steals = "steals", Saves = "saves", Wins = "wins", Matches = "matches" }

local function buildAchievements()
	local _, body = Kit.window("Achievements", "ACHIEVEMENTS", Vector2.new(600, 470))
	local weekly = Kit.create("Frame", { Size = UDim2.new(1, 0, 0, 86), BackgroundColor3 = Color3.fromRGB(60, 40, 110), Parent = body }, { Kit.corner(12), Kit.stroke(C.Gold, 2) })
	local list = listFrame(body, UDim2.fromOffset(0, 94), UDim2.new(1, 0, 1, -94))
	onState(function()
		clear(weekly)
		local w = state.Weekly
		Kit.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -150, 0, 24), Text = "WEEKLY CHALLENGE", TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = weekly })
		Kit.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 6), Size = UDim2.fromOffset(140, 20), Text = `ENDS IN {duration(w.EndsIn)}`, Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, TextXAlignment = Enum.TextXAlignment.Right, Parent = weekly })
		Kit.label({ Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -150, 0, 22), Text = w.Text, Font = BODY, TextXAlignment = Enum.TextXAlignment.Left, Parent = weekly })
		bar(weekly, UDim2.fromOffset(10, 60), UDim2.new(1, -150, 0, 14), w.Progress / w.Goal, C.Gold)
		Kit.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0, 58), Size = UDim2.fromOffset(130, 30), Text = if w.Done then "DONE ✓" else `{w.Progress}/{w.Goal}  +{Format.Number(w.Coins)}`, TextColor3 = if w.Done then C.Lime else C.Gold, Parent = weekly })

		clear(list)
		local done = 0
		for index, a in state.Achievements do
			if a.Done then
				done += 1
			end
			local row = Kit.create("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = C.NavyLight, LayoutOrder = (if a.Done then 100 else 0) + index, Parent = list }, {
				Kit.corner(10),
				Kit.stroke(if a.Done then C.Lime else C.Navy, 2),
			})
			Kit.label({ Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -150, 0, 22), Text = string.upper(a.Name), TextColor3 = if a.Done then C.Lime else C.White, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local what = if a.Stat == "Level" then `Reach level {a.Need}` elseif a.Stat == "MVPs" then `Be MVP {a.Need} times` else `{a.Need} career {STAT_TEXT[a.Stat] or string.lower(a.Stat)}`
			Kit.label({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(0.5, -10, 0, 16), Text = what, Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			bar(row, UDim2.new(0.5, 4, 0, 30), UDim2.new(0.5, -154, 0, 10), a.Value / a.Need, if a.Done then C.Lime else C.Cyan)
			Kit.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 28), Text = if a.Done then "DONE ✓" else `{a.Value}/{a.Need}  +{Format.Number(a.Coins)}`, TextColor3 = if a.Done then C.Lime else C.Gold, Parent = row })
		end
		local header = Kit.label({ Size = UDim2.new(1, 0, 0, 22), Text = `{done} / {#state.Achievements} UNLOCKED`, Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, LayoutOrder = -1, Parent = list })
		header.TextXAlignment = Enum.TextXAlignment.Left
	end)
end

---------------------------------------------------------------- Profil: Rang, Rekorde, letzte Matches

local function buildProfile()
	local _, body = Kit.window("Profile", "PROFILE & RANK", Vector2.new(600, 470))
	local left = Kit.create("Frame", { Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = body })
	local right = Kit.create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.5, -6, 1, 0), BackgroundTransparency = 1, Parent = body })
	local rankCard = Kit.create("Frame", { Size = UDim2.new(1, 0, 0, 150), BackgroundColor3 = C.NavyLight, Parent = left }, { Kit.corner(12) })
	local records = Kit.create("Frame", { Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 1, -160), BackgroundTransparency = 1, Parent = left }, {
		Kit.create("UIGridLayout", { CellSize = UDim2.new(0.5, -4, 0.5, -4), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Kit.label({ Size = UDim2.new(1, 0, 0, 28), Text = "LAST MATCHES", TextColor3 = C.Lime, Parent = right })
	local history = listFrame(right, UDim2.fromOffset(0, 34), UDim2.new(1, 0, 1, -34), 4)

	onState(function()
		local rating = state.Rating or Config.RatingStart
		local rank = Config.RankFor(rating)
		local nextRank = nil
		for _, r in Config.Ranks do
			if r.Min > rating then
				nextRank = r
				break
			end
		end
		clear(rankCard)
		Kit.label({ Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 20), Text = "RANK", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = rankCard })
		Kit.label({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 48), Text = string.upper(rank.Name), TextColor3 = rank.Color, StrokeThickness = 3, Parent = rankCard })
		Kit.label({ Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 0, 22), Text = `{rating} RATING   ·   MVP x{state.MVPs or 0}`, Font = BODY, Parent = rankCard })
		if nextRank then
			bar(rankCard, UDim2.fromOffset(14, 106), UDim2.new(1, -28, 0, 12), (rating - rank.Min) / (nextRank.Min - rank.Min), rank.Color)
			Kit.label({ Position = UDim2.fromOffset(10, 122), Size = UDim2.new(1, -20, 0, 18), Text = `{nextRank.Min - rating} to {string.upper(nextRank.Name)}  (win +{Config.RatingChange.Win}, loss {Config.RatingChange.Loss})`, Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = rankCard })
		else
			Kit.label({ Position = UDim2.fromOffset(10, 110), Size = UDim2.new(1, -20, 0, 24), Text = "HIGHEST RANK!", TextColor3 = C.Gold, Parent = rankCard })
		end

		clear(records)
		local rec = state.Records or {}
		for i, entry in { { "HARDEST SHOT", `{rec.ShotSpeed or 0} KM/H` }, { "LONGEST GOAL", `{rec.GoalDistance or 0} STUDS` }, { "GOALS IN A MATCH", tostring(rec.MatchGoals or 0) }, { "KOS IN A MATCH", tostring(rec.MatchKOs or 0) } } do
			local cell = Kit.create("Frame", { BackgroundColor3 = C.NavyLight, LayoutOrder = i, Parent = records }, { Kit.corner(10) })
			Kit.label({ Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 18), Text = entry[1], Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = cell })
			Kit.label({ Position = UDim2.fromOffset(6, 28), Size = UDim2.new(1, -12, 1, -36), Text = entry[2], TextColor3 = C.Cyan, Parent = cell })
		end

		clear(history)
		if #(state.History or {}) == 0 then
			Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Play a match to see it here", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, TextWrapped = true, Parent = history })
		end
		for i, h in state.History or {} do
			local color = if h.R == "Win" then C.Lime elseif h.R == "Loss" then C.Red else C.White
			local row = Kit.create("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.NavyLight, LayoutOrder = i, Parent = history }, { Kit.corner(8) })
			Kit.create("Frame", { Size = UDim2.new(0, 6, 1, 0), BackgroundColor3 = color, BorderSizePixel = 0, Parent = row }, { Kit.corner(3) })
			Kit.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.fromOffset(84, 26), Text = `{string.upper(h.R)} {h.S}`, TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			Kit.label({ Position = UDim2.fromOffset(100, 8), Size = UDim2.new(1, -108, 0, 18), Text = `G {h.G}   A {h.A}   KO {h.K}`, Font = BODY, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
	end)
end

---------------------------------------------------------------- Codes

local codeResult: TextLabel
local function buildCodes()
	local _, body = Kit.window("Codes", "CODES", Vector2.new(460, 310))
	Kit.label({ Size = UDim2.new(1, 0, 0, 26), Text = "Enter a code for free rewards", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = body })
	local box = Kit.create("TextBox", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = C.White,
		Text = "",
		PlaceholderText = "CODE",
		PlaceholderColor3 = Color3.fromRGB(150, 155, 175),
		TextColor3 = C.Navy,
		Font = Config.Font,
		TextScaled = true,
		ClearTextOnFocus = false,
		Parent = body,
	}, { Kit.corner(10), Kit.create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }) }) :: TextBox
	local redeem = Kit.button({ Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 52), Text = "REDEEM" }, Kit.GREEN)
	redeem.Parent = body
	codeResult = Kit.label({ Position = UDim2.fromOffset(0, 158), Size = UDim2.new(1, 0, 0, 32), Text = "", Parent = body })
	redeem.MouseButton1Click:Connect(function()
		local code = string.sub(box.Text, 1, 30)
		if code == "" then
			return
		end
		codeResult.Text = "..."
		codeResult.TextColor3 = C.White
		remote:FireServer("Redeem", code)
	end)
end

---------------------------------------------------------------- Torjubel-Effekte

local function buildCelebrations()
	local _, body = Kit.window("Celebrations", "GOAL CELEBRATIONS", Vector2.new(600, 470))
	Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "A burst of effects around you every time you score", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = body })
	local page = Kit.grid(body)
	local buttons = {}
	for _, def in Config.Celebrations do
		local frame, buy = Kit.card(page, def.Order, string.upper(def.Name), "", def.Colors[1])
		-- kleine Farbvorschau
		for i, color in def.Colors do
			Kit.create("Frame", { Position = UDim2.new(0, 14 + (i - 1) * 30, 0, 64), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = color, ZIndex = 2, Parent = frame }, { Kit.corner(12), Kit.stroke(C.Navy, 2) })
		end
		buy.MouseButton1Click:Connect(function()
			remote:FireServer("Celebration", def.Id)
		end)
		buttons[def.Id] = { Button = buy, Def = def }
	end
	onState(function()
		local owned = state.Celebrations and state.Celebrations.Owned or {}
		local equipped = state.Celebrations and state.Celebrations.Equipped or "none"
		for id, entry in buttons do
			if id == equipped then
				entry.Button.Text = "EQUIPPED"
				entry.Button.BackgroundColor3 = C.NavyLight
			elseif owned[id] then
				entry.Button.Text = "EQUIP"
				entry.Button.BackgroundColor3 = C.Cyan
			else
				entry.Button.Text = `{Format.Number(entry.Def.Price)} COINS`
				entry.Button.BackgroundColor3 = C.Gold
			end
		end
	end)
end

---------------------------------------------------------------- Anleitung

local PAGES = {
	{ "WELCOME TO SOCCER JAM!", "Red vs Blue. Score more goals than the other team in 8 minutes, or be the first to reach 10. A draw goes to GOLDEN GOAL." },
	{ "THE BALL", "Run into the ball to take it. Hold KICK to charge a shot and aim with the camera. Run sideways while shooting to CURVE the ball. PASS finds a teammate." },
	{ "THE SWORD", "SWORD slashes, THRUST stabs. Hit the ball carrier to knock the ball loose. Hits from behind do triple damage. The sword only works near the ball." },
	{ "WATCH OUT", "Hard shots SMACK players down. The alien mascots zap enemies near their goal, and running the ball into their circle knocks you out. Shoot from outside!" },
	{ "GET STRONGER", "Earn EXP in the match and spend it in UPGRADE. Coins buy trails, katanas and celebrations. Check QUESTS, SPIN and MORE for free rewards. Have fun!" },
}

local tutorialFrame: Frame
local tutorialPage = 1
local tutorialSent = false
local showPage: (number) -> ()

local function finishTutorial()
	if not tutorialSent then
		tutorialSent = true
		remote:FireServer("TutorialDone")
	end
end

local function buildTutorial()
	local frame, body = Kit.window("Help", "HOW TO PLAY", Vector2.new(540, 380))
	tutorialFrame = frame
	local title = Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "", TextColor3 = C.Lime, Parent = body })
	local text = Kit.label({ Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 150), Text = "", Font = BODY, TextWrapped = true, StrokeThickness = 0, Parent = body })
	text.TextYAlignment = Enum.TextYAlignment.Top
	Kit.create("UITextSizeConstraint", { MaxTextSize = 26, Parent = text })
	local dots = Kit.label({ Position = UDim2.new(0, 0, 1, -82), Size = UDim2.new(1, 0, 0, 22), Text = "", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = body })
	local back = Kit.button({ Position = UDim2.new(0, 0, 1, -52), Size = UDim2.new(0.4, 0, 0, 50), Text = "BACK" }, C.NavyLight)
	back.Parent = body
	local nextButton = Kit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 1, -52), Size = UDim2.new(0.55, 0, 0, 50), Text = "NEXT" }, Kit.GREEN)
	nextButton.Parent = body
	showPage = function(page: number)
		tutorialPage = math.clamp(page, 1, #PAGES)
		title.Text = PAGES[tutorialPage][1]
		text.Text = PAGES[tutorialPage][2]
		dots.Text = `{tutorialPage} / {#PAGES}`
		back.Visible = tutorialPage > 1
		nextButton.Text = if tutorialPage == #PAGES then "LET'S PLAY!" else "NEXT"
	end
	back.MouseButton1Click:Connect(function()
		showPage(tutorialPage - 1)
	end)
	nextButton.MouseButton1Click:Connect(function()
		if tutorialPage >= #PAGES then
			frame.Visible = false
		else
			showPage(tutorialPage + 1)
		end
	end)
	-- Fenster geschlossen (X oder fertig): nicht mehr automatisch zeigen
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if not frame.Visible then
			finishTutorial()
		end
	end)
	showPage(1)
end

local function openTutorial()
	showPage(1)
	if not tutorialFrame.Visible then
		UI.Open("Help")
	end
end

---------------------------------------------------------------- "Mehr"-Menue

local function buildHub()
	local _, body = Kit.window("More", "MORE", Vector2.new(600, 470))
	Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "More ways to play, collect and earn", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = body })
	local page = Kit.grid(body)
	local entries = {
		{ "ACHIEVEMENTS", "Career goals with coin rewards + the weekly challenge", C.Gold, function()
			UI.Open("Achievements")
		end },
		{ "PROFILE & RANK", "Your rank, personal records and last matches", C.Cyan, function()
			UI.Open("Profile")
		end },
		{ "CELEBRATIONS", "Effects that burst around you when you score", C.Orange, function()
			UI.Open("Celebrations")
		end },
		{ "CODES", "Redeem codes for free coins and rocket shots", C.Lime, function()
			UI.Open("Codes")
		end },
		{ "HOW TO PLAY", "Controls and rules in five quick pages", Color3.fromRGB(170, 120, 255), openTutorial },
	}
	for index, entry in entries do
		local _, open = Kit.card(page, index, entry[1], entry[2], entry[3])
		open.Text = "OPEN"
		open.MouseButton1Click:Connect(function()
			remote:FireServer("Sync")
			entry[4]()
		end)
	end
end

---------------------------------------------------------------- Modus-Abstimmung im Ergebnis-Fenster, Modus- und Freunde-Anzeige

local voteFrame: Frame
local voteButtons = {}
local myVote: string? = nil

local function buildVote()
	local body = UI.ResultsBody
	if not body then
		return
	end
	voteFrame = Kit.create("Frame", { Position = UDim2.fromOffset(0, 314), Size = UDim2.new(1, 0, 0, 84), BackgroundTransparency = 1, Visible = false, Parent = body })
	Kit.label({ Size = UDim2.new(1, 0, 0, 20), Text = "VOTE: NEXT MATCH MODE", Font = BODY, TextColor3 = C.Gold, Parent = voteFrame })
	local row = Kit.create("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = voteFrame }, {
		Kit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for index, mode in Config.Modes do
		local b = Kit.button({ Size = UDim2.new(0.25, -5, 1, 0), Text = mode.Name, LayoutOrder = index, Parent = row }, C.NavyLight)
		b.MouseButton1Click:Connect(function()
			myVote = mode.Id
			remote:FireServer("Vote", mode.Id)
		end)
		voteButtons[mode.Id] = b
	end
end

local function showVotes(counts)
	if not voteFrame then
		return
	end
	voteFrame.Visible = true
	for id, b in voteButtons do
		local mode = Config.ModesById[id]
		local n = counts and counts[id] or 0
		b.Text = if n > 0 then `{mode.Name} ({n})` else mode.Name
		b.BackgroundColor3 = if myVote == id then Kit.GREEN else C.NavyLight
	end
end

local modeLabel: TextLabel
local friendLabel: TextLabel

local function buildLabels()
	modeLabel = Kit.label({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.fromOffset(300, 22), Text = "", TextColor3 = C.Cyan, Visible = false, Parent = UI.Root() })
	friendLabel = Kit.label({ Position = UDim2.fromOffset(266, 14), Size = UDim2.fromOffset(158, 22), Text = `FRIEND BONUS +{math.floor((Config.FriendBonus - 1) * 100 + 0.5)}%`, Font = BODY, TextColor3 = C.Lime, TextXAlignment = Enum.TextXAlignment.Left, Visible = false, Parent = UI.Root() })
	local function update()
		local mode = Config.ModesById[workspace:GetAttribute("Mode") or "Classic"]
		modeLabel.Visible = mode ~= nil and mode.Id ~= "Classic"
		if mode then
			modeLabel.Text = `MODE: {mode.Name}`
		end
		friendLabel.Visible = player:GetAttribute("FriendBonus") == true
	end
	workspace:GetAttributeChangedSignal("Mode"):Connect(update)
	player:GetAttributeChangedSignal("FriendBonus"):Connect(update)
	update()
end

---------------------------------------------------------------- Muenzen und Orbs drehen sich (nur lokal)

local function animatePickups()
	local folder = workspace:WaitForChild("Pickups", 30)
	if not folder then
		return
	end
	local base = {} -- [BasePart] = Position
	folder.ChildRemoved:Connect(function(child)
		base[child] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				local position = base[part]
				if not position then
					position = part.Position
					base[part] = position
				end
				local offset = position.X * 0.1 -- jedes Teil wippt etwas versetzt
				part.CFrame = CFrame.new(position + Vector3.new(0, math.sin(t * 3 + offset) * 0.5, 0)) * CFrame.Angles(0, t * 2.5, 0)
			end
		end
	end)
end

---------------------------------------------------------------- Start

function Features.Start()
	remote = remotes:WaitForChild("Features") :: RemoteEvent
	buildSpin()
	buildChat()
	buildAchievements()
	buildProfile()
	buildCodes()
	buildCelebrations()
	buildTutorial()
	buildHub()
	buildVote()
	buildLabels()

	local spinItem = UI.AddMenuItem("SPIN", C.Gold, 9, function()
		remote:FireServer("Sync")
		UI.Open("Spin")
	end)
	spinItem.TextColor3 = C.Navy
	spinBadge = Kit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0, BackgroundColor3 = C.Red, Text = "!", Visible = false, ZIndex = 3, Parent = spinItem })
	Kit.corner(14).Parent = spinBadge
	UI.AddMenuItem("CHAT", C.Cyan, 10, function()
		UI.Open("Chat")
	end).TextColor3 = C.Navy
	UI.AddMenuItem("MORE", C.Lime, 11, function()
		remote:FireServer("Sync")
		UI.Open("More")
	end).TextColor3 = C.Navy

	-- Tastatur: C = Schnell-Chat
	ContextActionService:BindAction("SJQuickChat", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			UI.Open("Chat")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.C)

	remote.OnClientEvent:Connect(function(kind, info)
		if kind == "State" then
			state = info
			applyState()
		elseif kind == "SpinResult" then
			playSpin(info)
		elseif kind == "Redeemed" then
			if codeResult then
				codeResult.Text = info.Text
				codeResult.TextColor3 = if info.Ok then C.Lime else C.Orange
				Kit.pop(codeResult)
			end
			if info.Ok then
				Sounds.Play("Quest")
			end
		elseif kind == "Achievement" then
			Sounds.Play("Quest")
			UI.Announce(`{string.upper(info.Name)} UNLOCKED!  +{Format.Number(info.Coins)} COINS`, C.Gold, 3)
		elseif kind == "Tutorial" then
			if not UI.IsOpen("Help") then
				openTutorial()
			end
		elseif kind == "VoteOpen" then
			myVote = nil
			showVotes(info)
		elseif kind == "Votes" then
			showVotes(info)
		elseif kind == "VoteClosed" then
			myVote = nil
			if voteFrame then
				voteFrame.Visible = false
			end
		end
	end)
	remote:FireServer("Sync")
	task.spawn(animatePickups)
end

return Features
