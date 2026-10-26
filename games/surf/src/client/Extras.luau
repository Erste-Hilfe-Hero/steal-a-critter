-- Update 2 auf dem Client: Menue "MORE" mit Tagesaufgaben, Erfolgen/Titeln, Profil, Gluecks-Schneeball,
-- Codes und Einstellungen. Dazu Erfolgs-Popups, Anzeige fuer Schneesturm und Flake Booster,
-- Tempo-Meilensteine mit Geschwindigkeitslinien und das Ausblenden anderer Spieler.
-- Benutzt die Bausteine aus UI.luau (UI.Kit), damit alles gleich aussieht.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local T = Config.Theme

local Extras = {}

local function untilTomorrow(): number
	return 86400 - os.time() % 86400
end

function Extras.Start(UI, Movement)
	local K = UI.Kit
	local create, text, panel, button, corner = K.create, K.text, K.panel, K.button, K.corner
	local gui = K.gui

	-- Letzter Stand vom Server
	local state = {
		Achievements = {},
		Title = "",
		Quests = {},
		Medals = {},
		SpinReady = false,
		Settings = table.clone(Progression.DefaultSettings),
		Stats = {},
		SettingsLoaded = false,
	}
	UI.Settings = state.Settings
	local refreshers = {}
	local function refreshAll()
		for _, fn in refreshers do
			fn()
		end
	end

	local popSound = create("Sound", { SoundId = "rbxasset://sounds/victory.wav", Volume = 0.5, Parent = SoundService })
	local pingSound = create("Sound", { SoundId = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Parent = SoundService })

	------------------------------------------------ Hauptfenster mit Reitern

	local moreWindow, moreBody = K.window("MORE", 760, 470)
	local tabsBar = create("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, ZIndex = 7, Parent = moreBody })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = tabsBar })
	local pages, tabButtons = {}, {}
	local TABS = { "QUESTS", "TITLES", "PROFILE", "SPIN", "CODES", "SETTINGS" }
	local function showTab(name: string)
		for key, page in pages do
			page.Visible = key == name
			tabButtons[key].BackgroundColor3 = if key == name then T.Ice else T.PanelLight
			tabButtons[key].TextColor3 = if key == name then T.Navy else T.Snow
		end
	end
	for i, name in TABS do
		tabButtons[name] = button({ Size = UDim2.fromOffset(112, 34), Text = name, LayoutOrder = i, ZIndex = 8, Parent = tabsBar }, function()
			showTab(name)
		end)
		pages[name] = create("Frame", { Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1, Visible = false, ZIndex = 7, Parent = moreBody })
	end
	local function openMore(tab: string?)
		showTab(tab or "QUESTS")
		K.open(moreWindow)
		remotes.Progress:FireServer("Sync")
	end
	UI.OpenMore = openMore

	-- Roter Punkt am MORE-Knopf: es gibt etwas abzuholen
	local dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = T.Red, Visible = false, ZIndex = 3, Parent = UI.MoreButton })
	corner(7).Parent = dot

	------------------------------------------------ Tagesaufgaben

	local questList = K.scrollList(pages.QUESTS)
	local questRows = {}
	for i = 1, Progression.QuestsPerDay do
		local row = panel({ Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = T.PanelLight, LayoutOrder = i, ZIndex = 8, Parent = questList })
		local label = text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -190, 0, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Left, FontFace = K.HEAVY, ZIndex = 9, Parent = row })
		local reward = text({ Position = UDim2.fromOffset(14, 52), Size = UDim2.new(1, -190, 0, 18), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Gold, FontFace = K.BOLD, ZIndex = 9, Parent = row })
		local barBack = create("Frame", { Position = UDim2.fromOffset(14, 38), Size = UDim2.new(1, -190, 0, 8), BackgroundColor3 = T.Navy, ZIndex = 9, Parent = row })
		corner(4).Parent = barBack
		local bar = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Mint, ZIndex = 10, Parent = barBack })
		corner(4).Parent = bar
		local claim = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(150, 44), Text = "", ZIndex = 9, Parent = row }, function()
			local quest = state.Quests[i]
			if quest then
				remotes.Progress:FireServer("Claim", quest.Id)
			end
		end)
		questRows[i] = { Row = row, Label = label, Reward = reward, Bar = bar, Claim = claim }
	end
	local questFooter = text({ Size = UDim2.new(1, 0, 0, 22), Text = "", TextColor3 = T.Muted, FontFace = K.MEDIUM, LayoutOrder = 10, ZIndex = 8, Parent = questList })
	table.insert(refreshers, function()
		for i, row in questRows do
			local quest = state.Quests[i]
			local def = quest and Progression.QuestById[quest.Id]
			row.Row.Visible = def ~= nil
			if def then
				local progress = math.min(quest.Progress, def.Goal)
				row.Label.Text = def.Text
				row.Reward.Text = `+{Format.Number(def.Reward)} Snowflakes`
				row.Bar.Size = UDim2.fromScale(progress / def.Goal, 1)
				local done = progress >= def.Goal
				if quest.Claimed then
					row.Claim.Text, row.Claim.BackgroundColor3, row.Claim.TextColor3 = "DONE", T.PanelLight, T.Muted
				elseif done then
					row.Claim.Text, row.Claim.BackgroundColor3, row.Claim.TextColor3 = "CLAIM", T.Gold, T.Navy
				else
					local shown = if def.Kind == "Speed" then `{Format.Number(progress)}/{Format.Number(def.Goal)}` else `{progress}/{def.Goal}`
					row.Claim.Text, row.Claim.BackgroundColor3, row.Claim.TextColor3 = shown, T.Navy, T.Snow
				end
			end
		end
		questFooter.Text = `New quests in {Format.Clock(untilTomorrow())}`
	end)

	------------------------------------------------ Erfolge und Titel

	local titleHeader = text({ Size = UDim2.new(1, 0, 0, 24), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = T.Mint, FontFace = K.HEAVY, ZIndex = 8, Parent = pages.TITLES })
	local titleHolder = create("Frame", { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 1, -30), BackgroundTransparency = 1, ZIndex = 7, Parent = pages.TITLES })
	local titleGrid = K.scrollList(titleHolder, UDim2.fromOffset(166, 128))
	local achievementCards = {}
	for i, achievement in Progression.Achievements do
		local c = panel({ BackgroundColor3 = T.PanelLight, LayoutOrder = i, ZIndex = 8, Parent = titleGrid })
		local name = text({ Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 20), Text = achievement.Name, FontFace = K.HEAVY, ZIndex = 9, Parent = c })
		text({ Position = UDim2.fromOffset(10, 30), Size = UDim2.new(1, -20, 0, 30), Text = achievement.Desc, TextWrapped = true, TextColor3 = T.Muted, FontFace = K.MEDIUM, ZIndex = 9, Parent = c })
		text({ Position = UDim2.fromOffset(10, 62), Size = UDim2.new(1, -20, 0, 16), Text = `+{Format.Number(achievement.Reward)} Snowflakes`, TextColor3 = T.Gold, FontFace = K.BOLD, ZIndex = 9, Parent = c })
		local b = button({ Position = UDim2.new(0, 10, 1, -40), Size = UDim2.new(1, -20, 0, 32), Text = "LOCKED", ZIndex = 9, Parent = c }, function()
			if state.Achievements[achievement.Id] then
				remotes.Progress:FireServer("Title", if state.Title == achievement.Id then "" else achievement.Id)
			end
		end)
		achievementCards[achievement.Id] = { Button = b, Name = name }
	end
	table.insert(refreshers, function()
		local count = 0
		for _, achievement in Progression.Achievements do
			local unlocked = state.Achievements[achievement.Id] == true
			if unlocked then
				count += 1
			end
			local card = achievementCards[achievement.Id]
			card.Name.TextColor3 = if unlocked then T.Snow else T.Muted
			if state.Title == achievement.Id then
				card.Button.Text, card.Button.BackgroundColor3, card.Button.TextColor3 = "EQUIPPED", T.Mint, T.Navy
			elseif unlocked then
				card.Button.Text, card.Button.BackgroundColor3, card.Button.TextColor3 = "USE TITLE", T.Ice, T.Navy
			else
				card.Button.Text, card.Button.BackgroundColor3, card.Button.TextColor3 = "LOCKED", T.Navy, T.Muted
			end
		end
		titleHeader.Text = `ACHIEVEMENTS {count}/{#Progression.Achievements}  -  every one unlocks a title for your nameplate`
	end)

	------------------------------------------------ Profil

	local profileList = K.scrollList(pages.PROFILE)
	local profileLines = {}
	local function profileLine(order: number, color: Color3?, font: Font?): TextLabel
		local label = text({ Size = UDim2.new(1, 0, 0, 22), Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color or T.Snow, FontFace = font or K.MONO, LayoutOrder = order, ZIndex = 8, Parent = profileList })
		table.insert(profileLines, label)
		return label
	end
	local lines = {}
	for i = 1, 14 do
		lines[i] = profileLine(i)
	end
	local medalHeader = profileLine(20, T.Aurora, K.HEAVY)
	local medalLines = {}
	for stage = 1, #Config.Stages do
		medalLines[stage] = profileLine(20 + stage)
	end
	table.insert(refreshers, function()
		local stats = state.Stats
		local _, rank = Config.RankFor(stats.Clears or 0)
		local nextRank = nil
		for _, r in Config.Ranks do
			if (stats.Clears or 0) < r.Clears then
				nextRank = r
				break
			end
		end
		local title = Progression.AchievementsById[state.Title]
		local values = {
			{ "PLAYER", player.DisplayName, T.Ice },
			{ "RANK", string.upper(rank.Name) .. (if nextRank then `  ({nextRank.Clears - (stats.Clears or 0)} clears to {nextRank.Name})` else ""), rank.Color },
			{ "TITLE", if title then title.Name else "-", T.Mint },
			{ "BEST MAP TIME", if (stats.BestTime or 0) > 0 then Format.Run(stats.BestTime) else "-", T.Snow },
			{ "TOP SPEED", `{Format.Number(stats.TopSpeed or 0)} u/s`, T.Snow },
			{ "STAGE CLEARS", Format.Number(stats.Clears or 0), T.Snow },
			{ "MAP CLEARS", Format.Number(stats.MapClears or 0), T.Snow },
			{ "GOLD MEDALS", `{stats.GoldMedals or 0}/{#Config.Stages}`, T.Gold },
			{ "QUESTS DONE", Format.Number(stats.QuestsDone or 0), T.Snow },
			{ "FALLS", Format.Number(stats.Falls or 0), T.Snow },
			{ "TIME SURFED", `{(stats.PlayTime or 0) // 3600}h {((stats.PlayTime or 0) % 3600) // 60}m`, T.Snow },
			{ "WARS FREEZES", Format.Number(stats.WarFreezes or 0), T.Aurora },
			{ "WARS WINS", `{stats.WarWins or 0} of {stats.WarRounds or 0} rounds`, T.Aurora },
			{ "FRIENDS HERE", `{player:GetAttribute("FriendsHere") or 0}  (+{math.floor((player:GetAttribute("FriendBonus") or 0) * 100 + 0.5)}% Snowflakes)`, T.Mint },
		}
		for i, entry in values do
			lines[i].Text = string.format("%-14s %s", entry[1], entry[2])
			lines[i].TextColor3 = entry[3]
		end
		medalHeader.Text = "MEDALS  (Silver = Gold time x1.35)"
		for stage, def in Config.Stages do
			local tier = state.Medals[tostring(stage)] or 0
			local medal = Progression.Medals[tier]
			local gold = Progression.GoldTimes[stage]
			medalLines[stage].Text = string.format("S%-2d %-14s %-7s gold %s", stage, string.sub(string.upper(def.Name), 1, 14), if medal then string.upper(medal.Name) else "-", Format.Run(gold))
			medalLines[stage].TextColor3 = if medal then medal.Color else T.Muted
		end
	end)

	------------------------------------------------ Gluecks-Schneeball

	local spinPage = pages.SPIN
	text({ Size = UDim2.new(1, 0, 0, 26), Text = "LUCKY SNOWBALL  -  one free roll every day!", TextColor3 = T.Ice, FontFace = K.HEAVY, ZIndex = 8, Parent = spinPage })
	local slotRow = create("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 1, ZIndex = 8, Parent = spinPage })
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8), Parent = slotRow })
	local slots = {}
	for i, slot in Progression.Spin do
		local color = if slot.Kind == "Buddy" then T.Aurora elseif slot.Kind == "Boost" then T.Gold else T.Ice
		local c = panel({ Size = UDim2.fromOffset(92, 92), BackgroundColor3 = T.PanelLight, LayoutOrder = i, ZIndex = 9, Parent = slotRow })
		text({ Position = UDim2.fromOffset(6, 10), Size = UDim2.new(1, -12, 0, 40), Text = slot.Label, TextColor3 = color, FontFace = K.HEAVY, ZIndex = 10, Parent = c })
		text({ Position = UDim2.fromOffset(6, 56), Size = UDim2.new(1, -12, 0, 22), Text = if slot.Kind == "Flakes" then "Snowflakes" elseif slot.Kind == "Boost" then "Booster" else "Rare buddy!", TextColor3 = T.Muted, FontFace = K.BOLD, ZIndex = 10, Parent = c })
		slots[i] = c
	end
	local spinStatus = text({ Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 26), Text = "", FontFace = K.BOLD, ZIndex = 8, Parent = spinPage })
	local spinning = false
	local spinButton = button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 196), Size = UDim2.fromOffset(240, 56), Text = "ROLL!", Color = T.Gold, TextColor3 = T.Navy, ZIndex = 8, Parent = spinPage }, function()
		if spinning then
			return
		end
		if not state.SpinReady then
			K.toast(`Next free roll in {Format.Clock(untilTomorrow())}`, T.Red, 2)
			return
		end
		spinning = true
		remotes.Progress:FireServer("Spin")
		task.delay(6, function()
			spinning = false -- falls der Server ablehnt
		end)
	end)
	text({ Position = UDim2.fromOffset(0, 266), Size = UDim2.new(1, 0, 0, 20), Text = "Free in-game rewards only. The Snow Owl buddy can only be won here.", TextColor3 = T.Muted, FontFace = K.MEDIUM, ZIndex = 8, Parent = spinPage })
	local function highlight(index: number?)
		for i, c in slots do
			c.BackgroundColor3 = if i == index then T.Ice else T.PanelLight
		end
	end
	table.insert(refreshers, function()
		if not spinning then
			spinStatus.Text = if state.SpinReady then "Your free roll is ready!" else `Next free roll in {Format.Clock(untilTomorrow())}`
			spinStatus.TextColor3 = if state.SpinReady then T.Mint else T.Muted
			spinButton.BackgroundColor3 = if state.SpinReady then T.Gold else T.PanelLight
		end
	end)
	local function playSpin(index: number, message: string)
		spinning = true
		spinStatus.Text = "Rolling..."
		-- Leuchtet reihum und bremst ab, bis es auf dem Gewinn stehen bleibt
		local steps = #slots * 3 + index
		for step = 1, steps do
			highlight((step - 1) % #slots + 1)
			pingSound.PlaybackSpeed = 1.6
			pingSound:Play()
			task.wait(0.04 + (step / steps) ^ 3 * 0.3)
		end
		popSound:Play()
		spinStatus.Text = message
		spinStatus.TextColor3 = T.Gold
		K.toast(message, T.Gold, 4)
		task.wait(2)
		highlight(nil)
		spinning = false
		refreshAll()
	end

	------------------------------------------------ Codes

	local codePage = pages.CODES
	text({ Size = UDim2.new(1, 0, 0, 26), Text = "REDEEM A CODE", TextColor3 = T.Ice, FontFace = K.HEAVY, ZIndex = 8, Parent = codePage })
	text({ Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 20), Text = "New codes come with game updates. Each code works once.", TextColor3 = T.Muted, FontFace = K.MEDIUM, ZIndex = 8, Parent = codePage })
	local codeBox = create("TextBox", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 74),
		Size = UDim2.fromOffset(360, 52),
		BackgroundColor3 = T.Navy,
		Text = "",
		PlaceholderText = "Enter code",
		PlaceholderColor3 = T.Muted,
		TextColor3 = T.Snow,
		FontFace = K.HEAVY,
		TextScaled = true,
		ClearTextOnFocus = false,
		ZIndex = 8,
		Parent = codePage,
	})
	corner(10).Parent = codeBox
	create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = codeBox })
	local function redeem()
		local code = string.sub(codeBox.Text, 1, 24)
		if code ~= "" then
			remotes.Progress:FireServer("Code", code)
			codeBox.Text = ""
		end
	end
	button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Size = UDim2.fromOffset(220, 50), Text = "REDEEM", Color = T.Mint, TextColor3 = T.Navy, ZIndex = 8, Parent = codePage }, redeem)
	codeBox.FocusLost:Connect(function(enter)
		if enter then
			redeem()
		end
	end)

	------------------------------------------------ Einstellungen

	local settingsList = K.scrollList(pages.SETTINGS)
	local SETTINGS = {
		{ Key = "SurfAssist", Text = "Surf assist (sticks you to ramps, steers in the air)" },
		{ Key = "Music", Text = "Music (own soundtrack, tap the music button to pick a song)" },
		{ Key = "Ghost", Text = "Ghost of your best run in each stage" },
		{ Key = "CameraTilt", Text = "Camera tilts into the ramp" },
		{ Key = "SkiSpray", Text = "Snow spray from your skis" },
		{ Key = "HidePlayers", Text = "Hide other players (less distraction)" },
		{ Key = "Snow", Text = "Snowfall" },
		{ Key = "Speedometer", Text = "Speedometer" },
		{ Key = "SpeedFx", Text = "Speed lines and speed milestones" },
		{ Key = "Wind", Text = "Wind sound" },
		{ Key = "Hints", Text = "Keyboard hints (PC)" },
	}
	local toggles = {}
	local settingsToken = 0
	local applySettings
	for i, entry in SETTINGS do
		local row = panel({ Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = T.PanelLight, LayoutOrder = i, ZIndex = 8, Parent = settingsList })
		text({ Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -150, 0, 28), Text = entry.Text, TextXAlignment = Enum.TextXAlignment.Left, FontFace = K.BOLD, ZIndex = 9, Parent = row })
		toggles[entry.Key] = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 38), Text = "", ZIndex = 9, Parent = row }, function()
			state.Settings[entry.Key] = not state.Settings[entry.Key]
			applySettings()
			-- Gesammelt speichern, nicht bei jedem Klick
			settingsToken += 1
			local token = settingsToken
			task.delay(1.5, function()
				if token == settingsToken then
					remotes.Progress:FireServer("Settings", state.Settings)
				end
			end)
		end)
	end

	-- Wind leiser drehen, ohne Movement.luau anzufassen: eigene SoundGroup mit Lautstaerke 0
	local muteGroup = create("SoundGroup", { Name = "SurfMuted", Volume = 0, Parent = SoundService })
	local function windSound(): Sound?
		for _, child in SoundService:GetChildren() do
			if child:IsA("Sound") and child.SoundId == "rbxasset://sounds/action_falling.mp3" then
				return child
			end
		end
		return nil
	end
	local function snowEmitter(): ParticleEmitter?
		local part = workspace:FindFirstChild("LocalSnow")
		return part and part:FindFirstChildOfClass("ParticleEmitter")
	end

	local hidden = {} -- [Instance] = urspruenglicher Zustand (nur fuer Effekte)
	local function setCharacterHidden(character: Model, hide: boolean)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = if hide then 1 else 0
			elseif d:IsA("BillboardGui") or d:IsA("Trail") or d:IsA("ParticleEmitter") or d:IsA("PointLight") then
				if hide then
					if hidden[d] == nil then
						hidden[d] = d.Enabled
					end
					d.Enabled = false
				elseif hidden[d] ~= nil then
					d.Enabled = hidden[d]
					hidden[d] = nil
				end
			end
		end
	end
	local function applyHidePlayers()
		local hide = state.Settings.HidePlayers == true
		for _, other in Players:GetPlayers() do
			if other ~= player and other.Character then
				setCharacterHidden(other.Character, hide)
			end
		end
		if not hide then
			table.clear(hidden)
		end
	end

	applySettings = function()
		local s = state.Settings
		for key, b in toggles do
			local on = s[key] == true
			b.Text = if on then "ON" else "OFF"
			b.BackgroundColor3 = if on then T.Mint else T.Navy
			b.TextColor3 = if on then T.Navy else T.Muted
		end
		Movement.Assist = s.SurfAssist ~= false
		if UI.ApplySettings3 then
			UI.ApplySettings3(s)
		end
		if UI.SpeedPanel then
			UI.SpeedPanel.Visible = s.Speedometer ~= false
		end
		if UI.Hints then
			UI.Hints.Visible = s.Hints ~= false
		end
		local emitter = snowEmitter()
		if emitter then
			emitter.Enabled = s.Snow ~= false
		end
		local wind = windSound()
		if wind then
			wind.SoundGroup = if s.Wind == false then muteGroup else nil
		end
		applyHidePlayers()
	end
	-- Neue Figuren anderer Spieler (Respawn, Beitritt) ebenfalls ausblenden
	task.spawn(function()
		while gui.Parent do
			task.wait(1)
			if state.Settings.HidePlayers then
				applyHidePlayers()
			end
			-- Eintraege geloeschter Figuren vergessen
			for instance in hidden do
				if not instance.Parent then
					hidden[instance] = nil
				end
			end
		end
	end)

	------------------------------------------------ Erfolgs-Popup

	local popup = panel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 360, 0, 120), Size = UDim2.fromOffset(330, 78), BackgroundColor3 = T.Navy, BackgroundTransparency = 0.02, Radius = 14, ZIndex = 20, Parent = gui })
	local popupTop = text({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 16), Text = "ACHIEVEMENT UNLOCKED", TextColor3 = T.Gold, FontFace = K.HEAVY, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = popup })
	local popupName = text({ Position = UDim2.fromOffset(14, 26), Size = UDim2.new(1, -28, 0, 26), Text = "", FontFace = K.HEAVY, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = popup })
	local popupSub = text({ Position = UDim2.fromOffset(14, 54), Size = UDim2.new(1, -28, 0, 16), Text = "", TextColor3 = T.Muted, FontFace = K.BOLD, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = popup })
	local _ = popupTop
	local queue = {}
	local showing = false
	local function nextPopup()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local achievement = table.remove(queue, 1)
		popupName.Text = achievement.Name
		popupSub.Text = `{achievement.Desc}  -  +{Format.Number(achievement.Reward)} Snowflakes`
		popSound:Play()
		TweenService:Create(popup, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = UDim2.new(1, -12, 0, 120) }):Play()
		task.delay(3.2, function()
			TweenService:Create(popup, TweenInfo.new(0.3), { Position = UDim2.new(1, 360, 0, 120) }):Play()
			task.wait(0.4)
			showing = false
			nextPopup()
		end)
	end

	remotes.Reward.OnClientEvent:Connect(function(kind, a, b)
		if kind == "Achievement" then
			local achievement = Progression.AchievementsById[a]
			if achievement then
				table.insert(queue, achievement)
				nextPopup()
			end
		elseif kind == "Spin" and typeof(a) == "number" and Progression.Spin[a] then
			task.spawn(playSpin, a, if typeof(b) == "string" then b else "")
		end
	end)

	------------------------------------------------ Schneesturm und Booster (oben links)

	local eventPill = panel({ Position = UDim2.fromOffset(10, 88), Size = UDim2.fromOffset(210, 26), Radius = 13, Parent = gui })
	local eventLabel = text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = "", FontFace = K.HEAVY, Parent = eventPill })
	local boostPill = panel({ Position = UDim2.fromOffset(10, 118), Size = UDim2.fromOffset(210, 26), Radius = 13, BackgroundColor3 = T.Gold, Visible = false, Parent = gui })
	local boostLabel = text({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 1, -8), Text = "", TextColor3 = T.Navy, FontFace = K.HEAVY, Parent = boostPill })
	local stormWasOn = false
	task.spawn(function()
		while gui.Parent do
			local now = os.time()
			local stormUntil = workspace:GetAttribute("StormUntil") or 0
			local nextStorm = workspace:GetAttribute("NextStorm")
			local storm = stormUntil > now
			if storm then
				eventLabel.Text = `SNOWSTORM  2x  {Format.Clock(stormUntil - now)}`
				eventLabel.TextColor3 = T.Ice
				eventPill.Visible = true
			elseif nextStorm and nextStorm > now then
				eventLabel.Text = `Snowstorm in {Format.Clock(nextStorm - now)}`
				eventLabel.TextColor3 = T.Muted
				eventPill.Visible = true
			else
				eventPill.Visible = false
			end
			-- Mehr Schnee waehrend des Sturms
			if storm ~= stormWasOn then
				stormWasOn = storm
				local emitter = snowEmitter()
				if emitter then
					emitter.Rate = if storm then 420 else 140
				end
			end
			local boostUntil = player:GetAttribute("BoostUntil") or 0
			boostPill.Visible = boostUntil > now
			if boostUntil > now then
				boostLabel.Text = `FLAKE BOOSTER 2x  {Format.Clock(boostUntil - now)}`
			end
			-- Roter Punkt: Aufgabe abholbereit oder Gratis-Schneeball
			local claimable = state.SpinReady
			for _, quest in state.Quests do
				local def = Progression.QuestById[quest.Id]
				if def and not quest.Claimed and quest.Progress >= def.Goal then
					claimable = true
				end
			end
			dot.Visible = claimable
			if moreWindow.Visible then
				refreshAll()
			end
			task.wait(1)
		end
	end)

	------------------------------------------------ Tempo-Meilensteine und Geschwindigkeitslinien

	local burst = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(420, 60), Text = "", TextTransparency = 1, FontFace = K.HEAVY, ZIndex = 2, Parent = gui })
	local burstStroke = create("UIStroke", { Color = T.Navy, Thickness = 3, Transparency = 1, Parent = burst })
	local linesHolder = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, Parent = gui })
	local speedLines = {}
	local rng = Random.new()
	for i = 1, 16 do
		local line = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(90, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, BackgroundTransparency = 1, ZIndex = 0, Parent = linesHolder })
		speedLines[i] = { Frame = line, Angle = rng:NextNumber(0, math.pi * 2), Progress = rng:NextNumber() }
	end
	local reached = {}
	local lastStage = -1
	RunService.RenderStepped:Connect(function(dt)
		local units = Movement.Speed / SurfPhysics.Unit
		local stage = player:GetAttribute("Stage") or 0
		local fx = state.Settings.SpeedFx ~= false
		-- Meilensteine einmal pro Versuch (zuruecksetzen bei neuer Stage oder wenn man fast steht)
		if stage ~= lastStage or units < 300 then
			lastStage = stage
			table.clear(reached)
		end
		for _, milestone in Progression.SpeedMilestones do
			if units >= milestone and not reached[milestone] then
				reached[milestone] = true
				if fx and stage > 0 then
					burst.Text = `{Format.Number(milestone)} u/s!`
					burst.TextColor3 = if milestone >= 3000 then T.Aurora elseif milestone >= 2000 then T.Gold else T.Mint
					burst.TextTransparency = 0
					burstStroke.Transparency = 0.2
					pingSound.PlaybackSpeed = 0.9 + milestone / 3000
					pingSound:Play()
					TweenService:Create(burst, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
					TweenService:Create(burstStroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
				end
			end
		end
		-- Linien vom Rand nach aussen, staerker je schneller
		local strength = if fx then math.clamp((units - 1400) / 1600, 0, 1) else 0
		linesHolder.Visible = strength > 0
		if strength > 0 then
			for _, line in speedLines do
				line.Progress += dt * (1.2 + strength * 2.5)
				if line.Progress > 1 then
					line.Progress -= 1
					line.Angle = rng:NextNumber(0, math.pi * 2)
				end
				local radius = 0.38 + line.Progress * 0.4
				local direction = Vector2.new(math.cos(line.Angle), math.sin(line.Angle))
				line.Frame.Position = UDim2.fromScale(0.5 + direction.X * radius, 0.5 + direction.Y * radius)
				line.Frame.Rotation = math.deg(line.Angle)
				line.Frame.BackgroundTransparency = 1 - strength * 0.45 * (1 - line.Progress)
			end
		end
	end)

	------------------------------------------------ Daten vom Server

	remotes.ProgressSync.OnClientEvent:Connect(function(snapshot)
		if typeof(snapshot) ~= "table" then
			return
		end
		state.Achievements = snapshot.Achievements or {}
		state.Title = snapshot.Title or ""
		state.Quests = snapshot.Quests or {}
		state.Medals = snapshot.Medals or {}
		state.SpinReady = snapshot.SpinReady == true
		state.Stats = snapshot.Stats or {}
		-- Einstellungen nur beim ersten Paket uebernehmen (danach gilt, was der Spieler gerade klickt)
		if snapshot.Settings and not state.SettingsLoaded then
			state.SettingsLoaded = true
			for key, value in snapshot.Settings do
				state.Settings[key] = value
			end
			applySettings()
		end
		if UI.SetStageMedals then
			UI.SetStageMedals(state.Medals)
		end
		refreshAll()
	end)
	applySettings()
	showTab("QUESTS")
	remotes.Progress:FireServer("Sync")
end

return Extras
