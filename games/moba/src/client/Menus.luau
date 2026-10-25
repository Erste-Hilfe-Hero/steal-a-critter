-- Fenster fuer den Fortschritt: Menue-Uebersicht, Tages-Quests, Erfolge und Titel, Profil mit Meisterschaft,
-- Bestenliste, Codes, Einstellungen und die Anleitung. Die Daten kommen als JSON im Spieler-Attribut "Profile".
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Kit = require(script.Parent.Kit)

local Menus = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local INK, INK2, INK3, TEXT, MUTED = Kit.INK, Kit.INK2, Kit.INK3, Kit.TEXT, Kit.MUTED
local GOLD, CRYSTAL, GREEN, RED = Kit.GOLD, Kit.CRYSTAL, Kit.GREEN, Kit.RED
local TITLE, BODY, SMALL = Kit.TITLE, Kit.BODY, Kit.SMALL
local create, corner, round, text, button = Kit.create, Kit.corner, Kit.round, Kit.text, Kit.button

-- Profil aus dem Attribut lesen (leere Tabellen kommen als JSON-Array an)
function Menus.Profile()
	local raw = player:GetAttribute("Profile")
	if typeof(raw) ~= "string" then
		return {}
	end
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and typeof(data) == "table" then data else {}
end

-- Meisterschafts-Punkte eines Helden aus dem Profil
function Menus.MasteryPoints(profile, heroId: string): number
	local mastery = profile.Mastery
	return if typeof(mastery) == "table" then tonumber(mastery[heroId]) or 0 else 0
end

local function bar(parent: Instance, position: UDim2, size: UDim2, fraction: number, color: Color3)
	local back = create("Frame", { Position = position, Size = size, BackgroundColor3 = INK3, BorderSizePixel = 0, Parent = parent }, { round() })
	create("Frame", { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1), BackgroundColor3 = color, BorderSizePixel = 0, Parent = back }, { round() })
	return back
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") or child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local GUIDE = {
	{ "🎯", "Your goal", "Two teams of five fight on three lanes. Destroy the enemy towers, then break their Nexus to win. Bots fill every empty slot." },
	{ "🕹️", "Moving and attacking", "Phone: move with the stick on the left. Your hero attacks enemies in range by itself. Tap an enemy to focus it, or press the big ⚔️ button.\nPC: right-click to move or attack." },
	{ "✨", "Abilities", "Q W E R are your abilities. Tap for auto-aim or drag to aim. Tap the + on an ability to level it up (or press ⬆). D and F are summoner spells like Flash." },
	{ "🛒", "Gold and items", "Last-hit minions and monsters for gold. Shop at your fountain or while dead. Auto-Buy picks good items for you." },
	{ "🏠", "Stay alive", "Recall (🏠 or B) to heal at your fountain. Towers hit hard - let your minions go first. Wards (👁) show hidden enemies." },
	{ "🐉", "Objectives", "Drakes make your whole team stronger, the Herald breaks towers and the Abyss Tyrant empowers your minions. Smite helps junglers secure them." },
	{ "📜", "Daily quests and more", "Finish daily quests, earn mastery with your heroes, unlock titles with achievements and climb the leaderboard. Have fun!" },
}

-- api: { window, openWindow, closeWindows, isOpen, refreshers, lift, toast }
function Menus.Build(api)
	local window, openWindow, refreshers, lift = api.window, api.openWindow, api.refreshers, api.lift

	------------------------------------------------------------ Uebersicht

	local moreWindow, moreBody = window("More", "MENU", 520, 330, GOLD)
	local function buildMore()
		clear(moreBody)
		local profile = Menus.Profile()
		local level = profile.Level or 1
		local need = math.max(1, profile.Need or Config.AccountXPToLevel(level))
		text({ Size = UDim2.new(1, 0, 0, 20), Text = `⭐ Account level {level}  ·  {profile.XP or 0} / {need} XP`, Font = BODY, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Parent = moreBody })
		bar(moreBody, UDim2.fromOffset(0, 24), UDim2.new(1, 0, 0, 6), (profile.XP or 0) / need, GOLD)
		local grid = create("Frame", { Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, Parent = moreBody }, {
			create("UIGridLayout", { CellSize = UDim2.fromOffset(152, 66), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local ready = player:GetAttribute("QuestsReady") or 0
		local tiles = {
			{ "Quests", "📜 QUESTS" .. (if ready > 0 then ` ({ready}!)` else "") },
			{ "Achievements", "🏆 TITLES" },
			{ "Profile", "👤 PROFILE" },
			{ "Leaderboard", "🥇 TOP WINS" },
			{ "Codes", "🎟 CODES" },
			{ "Settings", "⚙ SETTINGS" },
			{ "Guide", "❓ HOW TO PLAY" },
		}
		for index, tile in tiles do
			local b = button({ LayoutOrder = index, Text = tile[2], Parent = grid, MaxText = 18 }, if tile[1] == "Quests" and ready > 0 then "Gold" else "Dark")
			b.Activated:Connect(function()
				openWindow(tile[1])
			end)
		end
		lift(moreWindow, 22)
	end
	refreshers.More = buildMore

	------------------------------------------------------------ Tages-Quests

	local questWindow, questBody = window("Quests", "DAILY QUESTS", 520, 330, GREEN)
	local function buildQuests()
		clear(questBody)
		local profile = Menus.Profile()
		local left = 86400 - os.time() % 86400
		text({ Size = UDim2.new(1, 0, 0, 18), Text = `New quests in {math.floor(left / 3600)}h {math.floor(left % 3600 / 60)}m  ·  progress counts at the end of each match`, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = questBody })
		local quests = if typeof(profile.Quests) == "table" then profile.Quests else {}
		if #quests == 0 then
			text({ Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 24), Text = "Loading quests...", TextColor3 = MUTED, Parent = questBody })
		end
		for index, quest in quests do
			local def = Config.QuestsById[quest.Id]
			if def then
				local y = 26 + (index - 1) * 76
				local row = create("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = INK2, Parent = questBody }, { corner(12) })
				local progress = math.min(def.Goal, tonumber(quest.Progress) or 0)
				text({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -170, 0, 22), Text = def.Text, TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = row })
				bar(row, UDim2.fromOffset(12, 38), UDim2.new(1, -184, 0, 8), progress / def.Goal, if progress >= def.Goal then GREEN else CRYSTAL)
				text({ Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -184, 0, 16), Text = `{progress} / {def.Goal}  ·  💎 {def.Reward}`, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
				if quest.Claimed then
					text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 26), Text = "✔ CLAIMED", TextColor3 = GREEN, Font = BODY, Parent = row })
				elseif progress >= def.Goal then
					local claim = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 40), Text = `CLAIM 💎{def.Reward}`, Parent = row }, "Gold")
					claim.Activated:Connect(function()
						remotes.ClaimQuest:FireServer(index)
					end)
				else
					text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 22), Text = "In progress", TextColor3 = MUTED, Font = SMALL, Parent = row })
				end
			end
		end
		lift(questWindow, 22)
	end
	refreshers.Quests = buildQuests

	------------------------------------------------------------ Erfolge und Titel

	local achieveWindow, achieveBody = window("Achievements", "ACHIEVEMENTS & TITLES", 640, 420, GOLD)
	local function buildAchievements()
		clear(achieveBody)
		local profile = Menus.Profile()
		local unlocked = {}
		for _, id in (if typeof(profile.Achievements) == "table" then profile.Achievements else {}) do
			unlocked[id] = true
		end
		local bestMastery = 0
		if typeof(profile.Mastery) == "table" then
			for _, points in profile.Mastery do
				bestMastery = math.max(bestMastery, (Config.MasteryLevel(tonumber(points) or 0)))
			end
		end
		local current = player:GetAttribute("Title") or ""
		text({ Size = UDim2.new(1, -150, 0, 26), Text = if current ~= "" then `Your title: «{current}»` else "No title equipped", Font = BODY, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Parent = achieveBody })
		if current ~= "" then
			local remove = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(140, 28), Text = "REMOVE TITLE", Parent = achieveBody, MaxText = 14 }, "Dark")
			remove.Activated:Connect(function()
				remotes.EquipTitle:FireServer("")
			end)
		end
		local list = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BorderSizePixel = 0, Parent = achieveBody }, {
			create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		for _, achievement in Config.Achievements do
			local has = unlocked[achievement.Id] == true
			local value = if achievement.Stat == "BestMastery" then bestMastery else tonumber(profile[achievement.Stat]) or 0
			local row = create("Frame", { LayoutOrder = achievement.Order, Size = UDim2.new(1, -10, 0, 56), BackgroundColor3 = if has then Color3.fromRGB(40, 58, 46) else INK2, Parent = list }, { corner(10) })
			text({ Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(40, 40), Text = if has then "🏆" else "🔒", Parent = row })
			text({ Position = UDim2.fromOffset(56, 6), Size = UDim2.new(1, -230, 0, 22), Text = `{achievement.Name}  <font color="#FFCD5A">«{achievement.Title}»</font>`, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = row })
			text({ Position = UDim2.fromOffset(56, 30), Size = UDim2.new(1, -230, 0, 18), Text = `{achievement.Desc}  ·  {math.min(value, achievement.Goal)}/{achievement.Goal}  ·  💎 {achievement.Reward}`, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			if has then
				if current == achievement.Title then
					text({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 24), Text = "✔ EQUIPPED", TextColor3 = GREEN, Font = BODY, Parent = row })
				else
					local equip = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 36), Text = "EQUIP TITLE", Parent = row, MaxText = 16 }, "Gold")
					equip.Activated:Connect(function()
						remotes.EquipTitle:FireServer(achievement.Id)
					end)
				end
			end
		end
		lift(achieveWindow, 22)
	end
	refreshers.Achievements = buildAchievements

	------------------------------------------------------------ Profil und Meisterschaft

	local profileWindow, profileBody = window("Profile", "PROFILE", 640, 420, CRYSTAL)
	local function buildProfile()
		clear(profileBody)
		local profile = Menus.Profile()
		local wins, matches = profile.Wins or 0, profile.Matches or 0
		local deaths = profile.Deaths or 0
		local kda = ((profile.Kills or 0) + (profile.Assists or 0)) / math.max(1, deaths)
		local title = player:GetAttribute("Title") or ""
		local left = create("Frame", { Size = UDim2.new(0.42, -6, 1, 0), BackgroundColor3 = INK2, Parent = profileBody }, { corner(12) })
		text({ Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 26), Text = player.DisplayName, Font = TITLE, TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
		text({ Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 16), Text = `⭐ Level {profile.Level or 1}` .. (if title ~= "" then `  ·  «{title}»` else ""), TextColor3 = GOLD, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
		local lines = {
			{ "Wins", Format.Number(wins) },
			{ "Matches", Format.Number(matches) },
			{ "Win rate", if matches > 0 then `{math.floor(wins / matches * 100 + 0.5)}%` else "-" },
			{ "K / D / A", `{profile.Kills or 0} / {deaths} / {profile.Assists or 0}` },
			{ "KDA", string.format("%.2f", kda) },
			{ "Last hits", Format.Number(profile.CS or 0) },
			{ "Towers", Format.Number(profile.Towers or 0) },
			{ "Epic monsters", Format.Number(profile.Epics or 0) },
			{ "Wards", Format.Number(profile.Wards or 0) },
			{ "MVP", Format.Number(profile.MVPs or 0) },
			{ "Win streak", `{profile.WinStreak or 0} (best {profile.BestStreak or 0})` },
		}
		for index, info in lines do
			local y = 58 + (index - 1) * 24
			text({ Position = UDim2.fromOffset(12, y), Size = UDim2.new(0.5, -12, 0, 20), Text = info[1], TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = left })
			text({ Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.new(0.5, -12, 0, 20), Text = info[2], Font = BODY, TextXAlignment = Enum.TextXAlignment.Right, Parent = left })
		end
		-- Meisterschaft aller Helden (meistgespielte zuerst)
		local right = create("ScrollingFrame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.58, -6, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BorderSizePixel = 0, Parent = profileBody }, {
			create("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		local heroes = table.clone(Config.Heroes)
		table.sort(heroes, function(a, b)
			local pa, pb = Menus.MasteryPoints(profile, a.Id), Menus.MasteryPoints(profile, b.Id)
			if pa ~= pb then
				return pa > pb
			end
			return a.Order < b.Order
		end)
		for order, hero in heroes do
			local points = Menus.MasteryPoints(profile, hero.Id)
			local level, from, to = Config.MasteryLevel(points)
			local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 42), BackgroundColor3 = INK2, Parent = right }, { corner(10) })
			text({ Position = UDim2.fromOffset(6, 5), Size = UDim2.fromOffset(32, 32), Text = hero.Icon, Parent = row })
			text({ Position = UDim2.fromOffset(44, 3), Size = UDim2.new(1, -54, 0, 18), Text = `{hero.Name}  <font color="#FFC94A">{string.rep("★", level)}</font>`, RichText = true, Font = BODY, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local fraction = if to then (points - from) / (to - from) else 1
			bar(row, UDim2.fromOffset(44, 24), UDim2.new(1, -150, 0, 6), fraction, hero.Color)
			text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 20), Size = UDim2.fromOffset(96, 16), Text = if to then `M{level} · {points}/{to}` else `M{level} · MAX`, TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
		lift(profileWindow, 22)
	end
	refreshers.Profile = buildProfile

	------------------------------------------------------------ Bestenliste

	local boardWindow, boardBody = window("Leaderboard", "TOP WINS", 460, 420, GOLD)
	local board: Instance? = ReplicatedStorage:FindFirstChild("Leaderboard")
	local function buildBoard()
		clear(boardBody)
		local list = {}
		local raw = board and board:GetAttribute("Top")
		if typeof(raw) == "string" then
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
			if ok and typeof(decoded) == "table" then
				list = decoded
			end
		end
		text({ Size = UDim2.new(1, 0, 0, 18), Text = "Most wins of all players · updates every 2 minutes", TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = boardBody })
		local scroll = create("ScrollingFrame", { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 1, -24), BackgroundTransparency = 1, ScrollBarThickness = 6, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), BorderSizePixel = 0, Parent = boardBody }, {
			create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		if #list == 0 then
			text({ Size = UDim2.new(1, 0, 0, 30), Text = "The leaderboard is loading. Win a match to get on it!", TextColor3 = MUTED, Font = BODY, Parent = scroll })
		end
		local medals = { "🥇", "🥈", "🥉" }
		for _, entry in list do
			local mine = entry.UserId == player.UserId
			local row = create("Frame", { LayoutOrder = tonumber(entry.Rank) or 99, Size = UDim2.new(1, -10, 0, 32), BackgroundColor3 = if mine then INK3 else INK2, Parent = scroll }, { corner(8) })
			text({ Position = UDim2.fromOffset(8, 4), Size = UDim2.fromOffset(40, 24), Text = medals[entry.Rank] or `#{entry.Rank}`, Font = TITLE, TextColor3 = GOLD, Parent = row })
			text({ Position = UDim2.fromOffset(54, 4), Size = UDim2.new(1, -150, 0, 24), Text = tostring(entry.Name), TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, TextColor3 = if mine then GOLD else TEXT, Parent = row })
			text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 4), Size = UDim2.fromOffset(90, 24), Text = `🏆 {Format.Number(tonumber(entry.Wins) or 0)}`, Font = BODY, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
		lift(boardWindow, 22)
	end
	refreshers.Leaderboard = buildBoard
	-- Ordner kann spaeter ankommen: nicht beim Laden des HUD warten
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("Leaderboard")
		board = folder
		folder:GetAttributeChangedSignal("Top"):Connect(function()
			if api.isOpen("Leaderboard") then
				buildBoard()
			end
		end)
	end)

	------------------------------------------------------------ Codes

	local codeWindow, codeBody = window("Codes", "CODES", 440, 230, CRYSTAL)
	text({ Size = UDim2.new(1, 0, 0, 34), Text = "Enter a code to get free crystals. Each code works once.", TextColor3 = MUTED, Font = SMALL, TextScaled = false, TextSize = 15, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = codeBody })
	local codeBox = create("TextBox", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 42), BackgroundColor3 = INK2, Text = "", PlaceholderText = "Type a code...", PlaceholderColor3 = MUTED, TextColor3 = TEXT, Font = BODY, TextScaled = true, ClearTextOnFocus = false, Parent = codeBody }, {
		corner(10),
		create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }),
	}) :: TextBox
	local redeem = button({ Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 40), Text = "REDEEM", Parent = codeBody }, "Crystal")
	redeem.Activated:Connect(function()
		local code = string.gsub(codeBox.Text, "%s", "")
		if code ~= "" and #code <= 30 then
			remotes.RedeemCode:FireServer(code)
			codeBox.Text = ""
		end
	end)
	lift(codeWindow, 22)

	------------------------------------------------------------ Einstellungen

	local settingsWindow, settingsBody = window("Settings", "SETTINGS", 440, 270, TEXT)
	local function buildSettings()
		clear(settingsBody)
		local rows = {
			{ "Sound", "🔊 Sound effects", player:GetAttribute("Setting_Sound") ~= false },
			{ "Numbers", "💥 Damage numbers", player:GetAttribute("Setting_Numbers") ~= false },
		}
		for index, info in rows do
			local y = (index - 1) * 52
			text({ Position = UDim2.fromOffset(0, y + 6), Size = UDim2.new(1, -140, 0, 30), Text = info[2], Font = BODY, TextXAlignment = Enum.TextXAlignment.Left, Parent = settingsBody })
			local toggle = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y), Size = UDim2.fromOffset(120, 40), Text = if info[3] then "ON" else "OFF", Parent = settingsBody }, if info[3] then "Gold" else "Dark")
			toggle.Activated:Connect(function()
				remotes.SetSetting:FireServer(info[1], not info[3])
			end)
		end
		local zoom = tonumber(player:GetAttribute("Setting_Zoom")) or 1
		text({ Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, -200, 0, 30), Text = `🎥 Camera distance  {string.format("%.1f", zoom)}`, Font = BODY, TextXAlignment = Enum.TextXAlignment.Left, Parent = settingsBody })
		for index, delta in { -0.1, 0.1 } do
			local b = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, if index == 1 then -64 else 0, 0, 104), Size = UDim2.fromOffset(56, 40), Text = if delta < 0 then "−" else "+", Parent = settingsBody }, "Dark")
			b.Activated:Connect(function()
				remotes.SetSetting:FireServer("Zoom", math.clamp(zoom + delta, 0.7, 1.4))
			end)
		end
		text({ Position = UDim2.fromOffset(0, 156), Size = UDim2.new(1, 0, 0, 18), Text = "Settings are saved to your account.", TextColor3 = MUTED, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, Parent = settingsBody })
		lift(settingsWindow, 22)
	end
	refreshers.Settings = buildSettings
	for _, attribute in { "Setting_Sound", "Setting_Numbers", "Setting_Zoom" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if api.isOpen("Settings") then
				buildSettings()
			end
		end)
	end

	------------------------------------------------------------ Anleitung

	local guideWindow, guideBody = window("Guide", "HOW TO PLAY", 560, 340, GOLD)
	local page = 1
	local function buildGuide()
		clear(guideBody)
		local info = GUIDE[page]
		text({ Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(70, 70), Text = info[1], Parent = guideBody })
		text({ Position = UDim2.fromOffset(82, 6), Size = UDim2.new(1, -82, 0, 30), Text = info[2], Font = TITLE, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Parent = guideBody })
		text({ Position = UDim2.fromOffset(82, 40), Size = UDim2.new(1, -82, 0, 150), Text = info[3], TextScaled = false, TextSize = 17, TextWrapped = true, Font = SMALL, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = guideBody })
		text({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(100, 20), Text = `{page} / {#GUIDE}`, TextColor3 = MUTED, Font = SMALL, Parent = guideBody })
		if page > 1 then
			local back = button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.fromOffset(140, 40), Text = "BACK", Parent = guideBody }, "Dark")
			back.Activated:Connect(function()
				page -= 1
				buildGuide()
			end)
		end
		local last = page == #GUIDE
		local nextButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(160, 40), Text = if last then "LET'S GO!" else "NEXT", Parent = guideBody }, "Gold")
		nextButton.Activated:Connect(function()
			if last then
				remotes.TutorialDone:FireServer()
				page = 1
				api.closeWindows()
			else
				page += 1
				buildGuide()
			end
		end)
		lift(guideWindow, 22)
	end
	refreshers.Guide = buildGuide

	-- Profil-Aenderungen in offenen Fenstern sofort zeigen
	local function refreshOpen()
		for _, name in { "More", "Quests", "Achievements", "Profile" } do
			if api.isOpen(name) then
				refreshers[name]()
			end
		end
	end
	player:GetAttributeChangedSignal("Profile"):Connect(refreshOpen)
	player:GetAttributeChangedSignal("Title"):Connect(refreshOpen)
end

return Menus
