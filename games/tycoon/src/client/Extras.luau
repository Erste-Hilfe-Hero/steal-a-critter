-- Update 2 auf dem Client: Aufgaben, Gluecksrad, Pets und Designs, Buch (Titel und Pflanzen-Index),
-- Einstellungen mit Codes, Einfuehrung mit Leitstrahl und schwebende Pets.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Extras = {}

local GREEN = Color3.fromRGB(60, 190, 90)
local PURPLE = Color3.fromRGB(160, 80, 255)
local GOLD = Color3.fromRGB(255, 200, 40)
local RED = Color3.fromRGB(255, 80, 80)

function Extras.Start(gui: ScreenGui, kit)
	local create, label, button, corner = kit.create, kit.label, kit.button, kit.corner
	local GREY = kit.GREY
	local state = nil -- letzter Sync vom Server
	local refreshers = {} -- Funktionen, die nach einem Sync laufen

	local function onSync(fn)
		table.insert(refreshers, fn)
	end

	---------------------------------------------------------------- Rechte Knopfleiste

	local side = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.45, 0),
		Size = UDim2.fromOffset(112, 270),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local function sideButton(text: string, color: Color3, order: number): TextButton
		return button({ Size = UDim2.new(1, 0, 0, 48), Text = text, LayoutOrder = order, Parent = side }, color)
	end
	local questsButton = sideButton("QUESTS", Color3.fromRGB(90, 200, 120), 1)
	local wheelButton = sideButton("WHEEL", Color3.fromRGB(255, 140, 40), 2)
	local petsButton = sideButton("PETS", Color3.fromRGB(230, 90, 200), 3)
	local bookButton = sideButton("BOOK", Color3.fromRGB(150, 110, 255), 4)
	local settingsButton = sideButton("SETTINGS", Color3.fromRGB(110, 120, 140), 5)

	-- Kleiner Zaehler-Punkt an einem Knopf (z. B. abholbare Aufgaben)
	local function badge(parent: GuiObject): TextLabel
		local dot = label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundTransparency = 0,
			BackgroundColor3 = RED,
			Text = "!",
			Visible = false,
			ZIndex = 5,
			Parent = parent,
		})
		corner(12).Parent = dot
		return dot
	end
	local questBadge = badge(questsButton)
	local wheelBadge = badge(wheelButton)

	local function sectionLabel(parent: Instance, order: number, text: string, color: Color3)
		return label({ Size = UDim2.new(1, -10, 0, 28), Text = text, TextColor3 = color, LayoutOrder = order, Parent = parent })
	end

	---------------------------------------------------------------- Aufgaben

	local questWindow, questList = kit.makeWindow(gui, "DAILY QUESTS", Color3.fromRGB(120, 255, 160))
	local questTimer = sectionLabel(questList, 0, "", Color3.fromRGB(180, 255, 200))
	local questRows = {}
	for i = 1, Config.QuestCount do
		local _, title, info, claim = kit.makeRow(questList, i, "Quest " .. i)
		claim.Activated:Connect(function()
			remotes.ClaimQuest:FireServer(i)
		end)
		questRows[i] = { Title = title, Info = info, Claim = claim }
	end
	sectionLabel(questList, 10, "Quest rewards grow with your earnings. New quests every day!", Color3.fromRGB(190, 190, 200))
	onSync(function()
		for i, row in questRows do
			local quest = state.Quests[i]
			if quest then
				row.Title.Text = quest.Text
				row.Info.Text = `{quest.Progress}/{quest.Target}  ·  {quest.Reward}`
				if quest.Claimed then
					row.Claim.Text = "DONE"
					row.Claim.BackgroundColor3 = GREY
				elseif quest.Progress >= quest.Target then
					row.Claim.Text = "CLAIM!"
					row.Claim.BackgroundColor3 = GREEN
				else
					row.Claim.Text = `{math.floor(quest.Progress / quest.Target * 100)}%`
					row.Claim.BackgroundColor3 = GREY
				end
			end
		end
	end)

	---------------------------------------------------------------- Gluecksrad

	local wheelWindow, wheelList = kit.makeWindow(gui, "LUCKY WHEEL", Color3.fromRGB(255, 170, 60))
	local spinButton = button({ Size = UDim2.new(1, -10, 0, 54), Text = "SPIN!", LayoutOrder = 0, Parent = wheelList }, Color3.fromRGB(255, 140, 40))
	sectionLabel(wheelList, 1, "One FREE spin every 4 hours. Chances:", Color3.fromRGB(255, 220, 160))
	local totalWeight = 0
	for _, reward in Config.WheelRewards do
		totalWeight += reward.Weight
	end
	local wheelRows = {}
	for index, reward in Config.WheelRewards do
		local row = create("Frame", { Size = UDim2.new(1, -10, 0, 40), BackgroundColor3 = kit.ROW, LayoutOrder = 1 + index, Parent = wheelList }, { corner(10) })
		local stroke = create("UIStroke", { Thickness = 0, Color = Color3.fromRGB(255, 240, 120), Parent = row })
		label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.7, -12, 1, -8), Text = reward.Name, TextColor3 = reward.Color, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.new(0.3, 0, 1, -8), Text = `{math.floor(reward.Weight / totalWeight * 1000 + 0.5) / 10}%`, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		wheelRows[index] = { Frame = row, Stroke = stroke }
	end
	local spinning = false
	local animating = false
	spinButton.Activated:Connect(function()
		if spinning then
			return
		end
		if os.time() < (player:GetAttribute("SpinReadyAt") or 0) then
			kit.showToast(`Next free spin in {Format.Time((player:GetAttribute("SpinReadyAt") or 0) - os.time())}.`, RED)
			return
		end
		spinning = true
		remotes.Spin:FireServer()
		task.delay(4, function()
			-- Falls keine Antwort kommt (z. B. Server lehnt ab), Knopf wieder freigeben
			if spinning and not animating then
				spinning = false
			end
		end)
	end)
	remotes.SpinResult.OnClientEvent:Connect(function(index: number, text: string)
		if not wheelWindow.Visible then
			kit.toggle(wheelWindow)
		end
		animating = true
		local count = #Config.WheelRewards
		local steps = count * 3 + index
		for step = 1, steps do
			local current = (step - 1) % count + 1
			for i, row in wheelRows do
				row.Stroke.Thickness = if i == current then 4 else 0
				row.Frame.BackgroundColor3 = if i == current then Color3.fromRGB(90, 80, 40) else kit.ROW
			end
			kit.playSound("Click", 1 + step / steps)
			task.wait(0.04 + (step / steps) ^ 3 * 0.35)
		end
		kit.playSound("Reward", 1)
		kit.showToast(`Lucky Wheel: {text}!`, Config.WheelRewards[index].Color)
		animating = false
		spinning = false
	end)

	---------------------------------------------------------------- Pets und Garten-Designs

	local petWindow, petList = kit.makeWindow(gui, "PETS & DESIGNS", Color3.fromRGB(255, 130, 230))
	sectionLabel(petList, 0, "Pets follow you and give a bonus. They stay after Rebirth!", Color3.fromRGB(255, 200, 240))
	local petRows = {}
	for _, pet in Config.Pets do
		local _, _, info, buy = kit.makeRow(petList, pet.Index, pet.Name, pet.Color)
		info.Text = pet.Text
		buy.Activated:Connect(function()
			remotes.BuyPet:FireServer(pet.Id)
		end)
		petRows[pet.Id] = { Buy = buy, Pet = pet }
	end
	sectionLabel(petList, 50, "Garden Designs (everyone can see them)", Color3.fromRGB(200, 230, 255))
	local skinRows = {}
	for _, skin in Config.Skins do
		local _, _, info, buy = kit.makeRow(petList, 50 + skin.Index, skin.Name, skin.Fence)
		info.Text = if skin.Level then `Free at gardener level {skin.Level}` else "New floor and fence colors"
		buy.Activated:Connect(function()
			remotes.BuySkin:FireServer(skin.Id)
		end)
		skinRows[skin.Id] = { Buy = buy, Skin = skin }
	end
	local function refreshPets()
		local coins = player:GetAttribute("Coins") or 0
		local level = player:GetAttribute("Level") or 1
		for id, row in petRows do
			local owned = state and state.Pets[id]
			local pet = row.Pet
			if owned then
				local equipped = state.Pet == id
				row.Buy.Text = if equipped then "UNEQUIP" else "EQUIP"
				row.Buy.BackgroundColor3 = if equipped then GREY else GREEN
			elseif pet.Pass then
				row.Buy.Text = "R$ " .. Config.GamePasses[pet.Pass].PriceHint
				row.Buy.BackgroundColor3 = Color3.fromRGB(255, 80, 160)
			else
				row.Buy.Text = Format.Cash(pet.Price)
				row.Buy.BackgroundColor3 = if coins >= pet.Price then GREEN else GREY
			end
		end
		for id, row in skinRows do
			local skin = row.Skin
			if state and state.Skins[id] then
				local using = state.Skin == id
				row.Buy.Text = if using then "USING" else "USE"
				row.Buy.BackgroundColor3 = if using then GREY else GREEN
			elseif skin.Level then
				row.Buy.Text = `LEVEL {skin.Level}`
				row.Buy.BackgroundColor3 = if level >= skin.Level then GREEN else GREY
			else
				row.Buy.Text = Format.Cash(skin.Price)
				row.Buy.BackgroundColor3 = if coins >= skin.Price then GREEN else GREY
			end
		end
	end
	onSync(refreshPets)

	---------------------------------------------------------------- Buch: Titel und Pflanzen-Index

	local bookWindow, bookList = kit.makeWindow(gui, "BOOK", Color3.fromRGB(180, 150, 255))
	local indexHeader = sectionLabel(bookList, 0, "Plant Index", Color3.fromRGB(150, 255, 200))
	local grid = create("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1, Parent = bookList }, {
		create("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 38), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local indexCells = {}
	local function indexCell(order: number, key: string, name: string, color: Color3, isMutation: boolean)
		local cell = label({ Text = "???", LayoutOrder = order, BackgroundTransparency = 0, BackgroundColor3 = kit.ROW, Parent = grid })
		corner(8).Parent = cell
		create("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3), Parent = cell })
		indexCells[key] = { Label = cell, Name = name, Color = color, Mutation = isMutation }
	end
	for _, seed in Config.Seeds do
		indexCell(seed.Index, "seed:" .. seed.Id, seed.Name, Config.RaritiesByName[seed.Rarity].Color, false)
	end
	for i, mutation in Config.Mutations do
		indexCell(100 + i, "mut:" .. mutation.Name, mutation.Name, mutation.Color, true)
	end
	sectionLabel(bookList, 10, "Titles (tap WEAR to show it above your name)", Color3.fromRGB(220, 180, 255))
	local _, _, noTitleInfo, noTitleButton = kit.makeRow(bookList, 11, "No title")
	noTitleInfo.Text = "Hide your title"
	noTitleButton.Activated:Connect(function()
		remotes.EquipTitle:FireServer("")
	end)
	local titleRows = {}
	for _, achievement in Config.Achievements do
		local _, title, info, wear = kit.makeRow(bookList, 20 + achievement.Index, achievement.Title)
		wear.Activated:Connect(function()
			if state and state.Achievements[achievement.Id] then
				remotes.EquipTitle:FireServer(achievement.Id)
			else
				kit.showToast(`Locked: {achievement.Text}.`, RED)
			end
		end)
		titleRows[achievement.Id] = { Title = title, Info = info, Wear = wear, Achievement = achievement }
	end
	onSync(function()
		local found = 0
		for key, cell in indexCells do
			local id = key:match(":(.+)$") :: string
			local known = if cell.Mutation then state.MutationIndex[id] else state.Index[id]
			cell.Label.Text = if known then cell.Name else "???"
			cell.Label.TextColor3 = if known then cell.Color else Color3.fromRGB(120, 120, 130)
			if known then
				found += 1
			end
		end
		local total = #Config.Seeds + #Config.Mutations
		indexHeader.Text = `Plant Index {found}/{total}  ·  +{math.floor(found * Config.IndexBonusPer * 100 + 0.5)}% fruit value`
		noTitleButton.Text = if state.Title == "" then "WEARING" else "HIDE"
		noTitleButton.BackgroundColor3 = if state.Title == "" then GREY else GREEN
		for id, row in titleRows do
			local achievement = row.Achievement
			local unlocked = state.Achievements[id]
			local value
			if achievement.Stat == "TotalEarned" then
				value = state.TotalEarned or 0
			elseif achievement.Stat == "Level" then
				value = player:GetAttribute("Level") or 1
			elseif achievement.Stat == "Rebirths" then
				value = player:GetAttribute("Rebirths") or 0
			elseif achievement.Stat == "Index" then
				value = 0
				for _ in state.Index do
					value += 1
				end
			else
				value = state.Stats[achievement.Stat] or 0
			end
			row.Title.TextColor3 = if unlocked then Color3.fromRGB(220, 180, 255) else Color3.fromRGB(150, 150, 160)
			row.Info.Text = if unlocked then achievement.Text else `{achievement.Text} ({Format.Number(math.min(value, achievement.Goal))}/{Format.Number(achievement.Goal)})`
			if not unlocked then
				row.Wear.Text = "LOCKED"
				row.Wear.BackgroundColor3 = GREY
			elseif state.Title == id then
				row.Wear.Text = "WEARING"
				row.Wear.BackgroundColor3 = GREY
			else
				row.Wear.Text = "WEAR"
				row.Wear.BackgroundColor3 = PURPLE
			end
		end
	end)

	---------------------------------------------------------------- Einstellungen und Codes

	local settingsWindow, settingsList = kit.makeWindow(gui, "SETTINGS", Color3.fromRGB(180, 190, 210))
	local toggles = {
		{ Key = "Sfx", Name = "Sound Effects", Info = "Harvest, sell and reward sounds" },
		{ Key = "Announce", Name = "Big Announcements", Info = "Off: show server news as small messages" },
		{ Key = "Pets", Name = "Other Players' Pets", Info = "Hide pets of other players" },
	}
	local toggleButtons = {}
	for i, entry in toggles do
		local _, _, info, switch = kit.makeRow(settingsList, i, entry.Name)
		info.Text = entry.Info
		switch.Activated:Connect(function()
			remotes.SetSetting:FireServer(entry.Key, player:GetAttribute("Set_" .. entry.Key) == false)
		end)
		toggleButtons[entry.Key] = switch
	end
	sectionLabel(settingsList, 10, "Codes", GOLD)
	local codeRow = create("Frame", { Size = UDim2.new(1, -10, 0, 56), BackgroundColor3 = kit.ROW, LayoutOrder = 11, Parent = settingsList }, { corner(10) })
	local codeBox = create("TextBox", {
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(0.62, -14, 1, -16),
		BackgroundColor3 = Color3.fromRGB(20, 24, 28),
		PlaceholderText = "Enter code",
		Text = "",
		ClearTextOnFocus = false,
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		TextColor3 = Color3.new(1, 1, 1),
		PlaceholderColor3 = Color3.fromRGB(130, 130, 140),
		Parent = codeRow,
	}, { corner(8), create("UITextSizeConstraint", { MaxTextSize = 24 }) }) :: TextBox
	local redeem = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.34, 0, 0, 42), Text = "REDEEM", Parent = codeRow }, GOLD)
	redeem.Activated:Connect(function()
		local text = codeBox.Text
		if text:gsub("%s", "") == "" then
			kit.showToast("Type a code first.", RED)
			return
		end
		remotes.RedeemCode:FireServer(text:sub(1, 32))
		codeBox.Text = ""
	end)
	sectionLabel(settingsList, 12, "Tip: try the code GARDEN", Color3.fromRGB(190, 190, 200))

	---------------------------------------------------------------- Knoepfe verbinden

	questsButton.Activated:Connect(function()
		kit.toggle(questWindow)
	end)
	wheelButton.Activated:Connect(function()
		kit.toggle(wheelWindow)
	end)
	petsButton.Activated:Connect(function()
		kit.toggle(petWindow)
	end)
	bookButton.Activated:Connect(function()
		kit.toggle(bookWindow)
	end)
	settingsButton.Activated:Connect(function()
		kit.toggle(settingsWindow)
	end)

	remotes.Sync.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		state = payload
		for _, fn in refreshers do
			task.spawn(fn)
		end
	end)
	remotes.RequestSync:FireServer()

	---------------------------------------------------------------- Einfuehrung: Banner und Leitstrahl

	local tutorialBanner = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 222),
		Size = UDim2.new(0.6, 0, 0, 36),
		BackgroundTransparency = 0.2,
		BackgroundColor3 = Color3.fromRGB(70, 55, 10),
		TextColor3 = Color3.fromRGB(255, 230, 120),
		Text = "",
		Visible = false,
		Parent = gui,
	})
	corner(12).Parent = tutorialBanner
	create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), Parent = tutorialBanner })

	local targetPart = create("Part", { Name = "TutorialTarget", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one }) :: Part
	local targetAttachment = create("Attachment", { Parent = targetPart }) :: Attachment
	local beam = create("Beam", {
		Attachment1 = targetAttachment,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 80)),
		Width0 = 0.7,
		Width1 = 0.7,
		FaceCamera = true,
		LightEmission = 0.6,
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		TextureMode = Enum.TextureMode.Wrap,
		TextureLength = 2,
		TextureSpeed = 2,
		Transparency = NumberSequence.new(0.1),
		Parent = targetPart,
	}) :: Beam

	---------------------------------------------------------------- Laufende Anzeige

	task.spawn(function()
		while gui.Parent do
			-- Knopf-Hinweise
			local ready = player:GetAttribute("QuestsReady") or 0
			questBadge.Visible = ready > 0
			questBadge.Text = tostring(ready)
			local spinLeft = (player:GetAttribute("SpinReadyAt") or 0) - os.time()
			wheelBadge.Visible = spinLeft <= 0 and player:GetAttribute("SpinReadyAt") ~= nil
			if not spinning then
				spinButton.Text = if spinLeft <= 0 then "SPIN!" else `Next free spin in {Format.Time(spinLeft)}`
				spinButton.BackgroundColor3 = if spinLeft <= 0 then Color3.fromRGB(255, 140, 40) else GREY
			end
			questTimer.Text = `New quests in {Format.Time(86400 - os.time() % 86400)}`
			for key, switch in toggleButtons do
				local on = player:GetAttribute("Set_" .. key) ~= false
				switch.Text = if on then "ON" else "OFF"
				switch.BackgroundColor3 = if on then GREEN else GREY
			end
			if petWindow.Visible then
				refreshPets()
			end

			-- Einfuehrung
			local text = player:GetAttribute("TutorialText")
			local target = player:GetAttribute("TutorialTarget")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			tutorialBanner.Visible = type(text) == "string"
			tutorialBanner.Text = if type(text) == "string" then text else ""
			if typeof(target) == "Vector3" and root then
				targetPart.Position = target + Vector3.new(0, 1.5, 0)
				targetPart.Parent = workspace
				local attachment = root:FindFirstChild("TutorialAttachment") :: Attachment?
				if not attachment then
					attachment = create("Attachment", { Name = "TutorialAttachment", Parent = root }) :: Attachment
				end
				beam.Attachment0 = attachment
				beam.Enabled = true
			else
				beam.Enabled = false
				targetPart.Parent = nil
			end
			task.wait(0.25)
		end
	end)

	---------------------------------------------------------------- Schwebende Pets

	local baseC0 = setmetatable({}, { __mode = "k" }) -- [Weld] = urspruengliches C0
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local showOthers = player:GetAttribute("Set_Pets") ~= false
		for _, model in CollectionService:GetTagged("GardenPet") do
			local body = (model :: Model).PrimaryPart
			local weld = body and body:FindFirstChild("PetWeld") :: Weld?
			if weld then
				local base = baseC0[weld]
				if not base then
					base = weld.C0
					baseC0[weld] = base
				end
				local phase = (model:GetAttribute("OwnerUserId") or 0) % 7
				weld.C0 = base * CFrame.new(0, math.sin(t * 3 + phase) * 0.3, 0)
			end
			local hidden = not showOthers and model:GetAttribute("OwnerUserId") ~= player.UserId
			local modifier = if hidden then 1 else 0
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.LocalTransparencyModifier ~= modifier then
					part.LocalTransparencyModifier = modifier
				elseif part:IsA("Sparkles") then
					part.Enabled = not hidden
				end
			end
		end
	end)
end

return Extras
