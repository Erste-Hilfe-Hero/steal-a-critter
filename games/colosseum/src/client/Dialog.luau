-- Gespraechsbox unten am Bildschirm: Namensschild mit kleinem Portraet, Text mit Schreibmaschinen-Effekt,
-- Antippen fuer die naechste Zeile, Auswahl-Knoepfe am Ende. Antwortet dem Server mit DialogAnswer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Story = require(ReplicatedStorage.Shared.Story)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local C = Theme.Colors
local create = Theme.create
local label = Theme.label
local button = Theme.button

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Dialog = {}

local gui: ScreenGui
local box: TextButton
local nameLabel: TextLabel
local namePlate: Frame
local portrait: Frame
local textLabel: TextLabel
local arrow: TextLabel
local choiceList: Frame
local advance: BindableEvent
local queue = {}
local running = false

local function drawPortrait(lookKey: string?)
	portrait:ClearAllChildren()
	Theme.corner(portrait, 12)
	Theme.stroke(portrait, C.Gold, 2)
	local look = lookKey and Story.Looks[lookKey]
	portrait.Visible = look ~= nil
	if not look then
		return
	end
	-- Kopf mit Haaren, Augen und Hut aus Rahmen
	local face = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(52, 50), BackgroundColor3 = look.Skin, Parent = portrait })
	Theme.corner(face, 10)
	create("Frame", { Position = UDim2.fromOffset(-3, -6), Size = UDim2.new(1, 6, 0, 16), BackgroundColor3 = look.Hair, Parent = face })
	for _, x in { 14, 32 } do
		create("Frame", { Position = UDim2.fromOffset(x, 22), Size = UDim2.fromOffset(6, 9), BackgroundColor3 = C.Ink, Parent = face })
	end
	create("Frame", { Position = UDim2.fromOffset(18, 38), Size = UDim2.fromOffset(16, 3), BackgroundColor3 = C.Ink, Parent = face })
	if look.Hat then
		local hat = create("Frame", { Position = UDim2.fromOffset(-5, -14), Size = UDim2.new(1, 10, 0, 12), BackgroundColor3 = look.Hat, Parent = face })
		Theme.corner(hat, 4)
	end
	create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(70, 16), BackgroundColor3 = look.Shirt, Parent = portrait })
end

local function typeLine(text: string)
	textLabel.Text = text
	textLabel.MaxVisibleGraphemes = 0
	arrow.Visible = false
	local length = utf8.len(text) or #text
	local shown = 0
	local skip = false
	local connection = advance.Event:Connect(function()
		skip = true
	end)
	while shown < length and not skip do
		shown = math.min(length, shown + 1)
		textLabel.MaxVisibleGraphemes = shown
		RunService.Heartbeat:Wait()
	end
	connection:Disconnect()
	textLabel.MaxVisibleGraphemes = -1
end

local function show(token: number, payload)
	-- Warten, bis Szenen wie Entwicklungen fertig sind
	while UI.SceneBusy() do
		task.wait(0.2)
	end
	UI.CloseWindow()
	gui.Enabled = true
	nameLabel.Text = payload.Speaker or ""
	namePlate.Visible = payload.Speaker ~= nil and payload.Speaker ~= ""
	drawPortrait(payload.Look)
	box.Position = UDim2.new(0.5, 0, 1, 40)
	TweenService:Create(box, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Position = UDim2.new(0.5, 0, 1, -18) }):Play()
	local lines = payload.Lines or {}
	for index, line in lines do
		typeLine(line)
		local last = index == #lines
		if last and payload.Choices then
			break
		end
		arrow.Visible = true
		advance.Event:Wait()
	end
	local answer = 1
	if payload.Choices then
		choiceList:ClearAllChildren()
		create("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, Parent = choiceList })
		local picked = Instance.new("BindableEvent")
		for i, choice in payload.Choices do
			local b = button({ Size = UDim2.fromOffset(220, 48), Text = choice, TextSize = 20, Color = if i == 1 then C.Crimson else C.PanelLight, Parent = choiceList })
			b.Activated:Connect(function()
				picked:Fire(i)
			end)
		end
		choiceList.Visible = true
		answer = picked.Event:Wait()
		picked:Destroy()
		choiceList.Visible = false
		choiceList:ClearAllChildren()
	end
	remotes.DialogAnswer:FireServer(token, answer)
	gui.Enabled = false
end

local function pump()
	if running then
		return
	end
	running = true
	while #queue > 0 do
		local item = table.remove(queue, 1)
		local ok, err = pcall(show, item.Token, item.Payload)
		if not ok then
			warn("[Dialog]", err)
			remotes.DialogAnswer:FireServer(item.Token, 1)
			gui.Enabled = false
		end
	end
	running = false
end

-- Lokaler Text ohne Server (z. B. Torwaechter)
function Dialog.Local(speaker: string, lines: { string }, look: string?)
	table.insert(queue, { Token = -1, Payload = { Speaker = speaker, Lines = lines, Look = look } })
	task.spawn(pump)
end

function Dialog.Active(): boolean
	return running
end

function Dialog.Init()
	gui = create("ScreenGui", { Name = "Dialog", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false, DisplayOrder = 8, Parent = player:WaitForChild("PlayerGui") })
	local root = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
	local scale = create("UIScale", { Parent = root })
	local function rescale()
		local size = workspace.CurrentCamera.ViewportSize
		local s = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.55, 1.3)
		scale.Scale = s
		root.Size = UDim2.fromOffset(size.X / s, size.Y / s)
	end
	rescale()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	advance = Instance.new("BindableEvent")

	box = create("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.new(1, -60, 0, 170), BackgroundColor3 = C.Panel, AutoButtonColor = false, Text = "", Parent = root })
	Theme.corner(box, 16)
	Theme.stroke(box, C.Gold, 3)
	Theme.gradient(box, Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 200, 205))
	local inner = create("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 1, -20), BackgroundColor3 = C.PanelDark, Parent = box })
	Theme.corner(inner, 12)
	Theme.stroke(inner, C.GoldDark, 1.5)
	portrait = create("Frame", { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(96, 112), BackgroundColor3 = Color3.fromRGB(70, 55, 70), ClipsDescendants = true, Parent = inner })
	textLabel = label({ Position = UDim2.fromOffset(128, 14), Size = UDim2.new(1, -150, 1, -28), Text = "", Font = Theme.Heavy, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = inner })
	arrow = label({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -6), Size = UDim2.fromOffset(30, 30), Text = "▼", Font = Theme.Title, TextSize = 24, TextColor3 = C.Gold, Visible = false, Parent = inner })
	-- Pfeil huepft
	task.spawn(function()
		while true do
			TweenService:Create(arrow, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Position = UDim2.new(1, -14, 1, -2) }):Play()
			task.wait(0.35)
			TweenService:Create(arrow, TweenInfo.new(0.35, Enum.EasingStyle.Sine), { Position = UDim2.new(1, -14, 1, -8) }):Play()
			task.wait(0.35)
		end
	end)
	local plate = create("Frame", { Position = UDim2.fromOffset(24, -22), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = C.Crimson, Parent = box })
	namePlate = plate
	Theme.corner(plate, 10)
	Theme.stroke(plate, C.Gold, 2)
	create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), Parent = plate })
	nameLabel = label({ Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, Text = "", Font = Theme.Title, TextSize = 24, TextColor3 = C.Gold, TextWrapped = false, Parent = plate })
	Theme.textStroke(nameLabel, 1.5)
	choiceList = create("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -40, 1, -200), Size = UDim2.fromOffset(240, 200), BackgroundTransparency = 1, Visible = false, Parent = root })
	box.Activated:Connect(function()
		advance:Fire()
	end)

	remotes.Dialog.OnClientEvent:Connect(function(token, payload)
		table.insert(queue, { Token = token, Payload = payload })
		task.spawn(pump)
	end)
end

return Dialog
