-- Welt auf dem Client: eigene Prompt-Optik, Story-Tore pro Spieler, NPCs je nach Fortschritt ein- und ausblenden,
-- Trainer-Sichtlinie ("!" und Anlaufen), raschelndes Gras und prismatisches Schimmern.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Story = require(ReplicatedStorage.Shared.Story)
local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)
local Battle = require(script.Parent.Battle)
local Dialog = require(script.Parent.Dialog)

local C = Theme.Colors
local create = Theme.create
local label = Theme.label

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local World = {}

local collection: any = nil
local localFlags: { [string]: boolean } = {} -- sofort gesetzte Flags, bevor die Sammlung ankommt
local hiddenFolder = Instance.new("Folder")
hiddenFolder.Name = "HiddenNpcs"
hiddenFolder.Parent = ReplicatedStorage

local function hasFlag(flag: string): boolean
	return localFlags[flag] == true or (collection ~= nil and collection.Flags ~= nil and collection.Flags[flag] == true)
end

local function badges(): number
	return collection and collection.Badges or 0
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

---------------------------------------------------------------- Prompts im Arena-Stil

local function promptColor(prompt: ProximityPrompt): Color3
	if prompt.Name == "DuelPrompt" then
		return C.Blue
	elseif prompt.ActionText == "Challenge" then
		return C.Crimson
	elseif prompt.ActionText == "Heal Team" then
		return C.Green
	elseif prompt.ActionText == "Approach" then
		return Color3.fromRGB(150, 90, 210)
	end
	return C.GoldDark
end

local function showPrompt(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local parent = prompt.Parent
	if not parent or not parent:IsA("BasePart") then
		return
	end
	local board = create("BillboardGui", {
		Name = "PromptUI",
		Size = UDim2.fromOffset(230, 70),
		StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0),
		AlwaysOnTop = true,
		Active = true,
		LightInfluence = 0,
		Adornee = parent,
		ResetOnSpawn = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local frame = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Panel, AutoButtonColor = true, Text = "", Parent = board })
	Theme.corner(frame, 14)
	Theme.stroke(frame, C.Gold, 2)
	local key = create("Frame", { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(50, 50), BackgroundColor3 = promptColor(prompt), Parent = frame })
	Theme.corner(key, 12)
	Theme.stroke(key, C.Gold, 2)
	local keyText = if inputType == Enum.ProximityPromptInputType.Touch then "TAP"
		elseif inputType == Enum.ProximityPromptInputType.Gamepad then "X"
		else prompt.KeyboardKeyCode.Name
	label({ Size = UDim2.fromScale(1, 1), Text = keyText, Font = Theme.Title, TextSize = if #keyText > 1 then 16 else 26, Parent = key })
	local action = label({ Position = UDim2.fromOffset(66, 8), Size = UDim2.new(1, -74, 0, 30), Text = prompt.ActionText, Font = Theme.Title, TextSize = 24, TextScaled = true, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	Theme.textStroke(action, 1.5)
	label({ Position = UDim2.fromOffset(66, 38), Size = UDim2.new(1, -74, 0, 22), Text = prompt.ObjectText, TextSize = 16, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	local scale = create("UIScale", { Scale = 0.6, Parent = frame })
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	frame.Activated:Connect(function()
		prompt:InputHoldBegin()
		task.wait(prompt.HoldDuration + 0.05)
		prompt:InputHoldEnd()
	end)
	local hidden
	hidden = prompt.PromptHidden:Connect(function()
		hidden:Disconnect()
		board:Destroy()
	end)
end

---------------------------------------------------------------- NPCs ein- und ausblenden

local npcHome: { [Model]: Instance } = {}

local function shouldHide(model: Model): boolean
	local hide = model:GetAttribute("HideFlag")
	if typeof(hide) == "string" and hasFlag(hide) then
		return true
	end
	local show = model:GetAttribute("ShowFlag")
	if typeof(show) == "string" and not hasFlag(show) then
		return true
	end
	return false
end

local function updateNpc(model: Model)
	if not model:IsA("Model") then
		return
	end
	if not npcHome[model] then
		npcHome[model] = model.Parent :: Instance
	end
	-- Lokales Umhaengen: der Server sieht das Modell weiter, dieser Spieler nicht
	local target = if shouldHide(model) then hiddenFolder else npcHome[model]
	if model.Parent ~= target then
		model.Parent = target
	end
end

local function npcFolder(): Instance?
	return workspace:FindFirstChild("Npcs")
end

local function updateNpcs()
	for model in npcHome do
		updateNpc(model)
	end
	local folder = npcFolder()
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") and not npcHome[child] then
				updateNpc(child)
			end
		end
	end
end

---------------------------------------------------------------- Story-Tore

local function gateOpen(gate: BasePart): boolean
	local need = gate:GetAttribute("Badges") or 0
	local flag = gate:GetAttribute("Flag")
	return badges() >= need and (typeof(flag) ~= "string" or hasFlag(flag))
end

local function updateGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	local open = gateOpen(gate)
	gate.CanCollide = not open
	gate.CanTouch = true
	gate.Transparency = if open then 1 else 0.05
end

local function updateGates()
	for _, gate in CollectionService:GetTagged("StoryGate") do
		updateGate(gate)
	end
end

local lastGateText = 0
local function watchGate(gate: Instance)
	if not gate:IsA("BasePart") then
		return
	end
	updateGate(gate)
	gate.Touched:Connect(function(hit)
		local character = player.Character
		if not character or not hit:IsDescendantOf(character) or gateOpen(gate) then
			return
		end
		if os.clock() - lastGateText < 5 or Dialog.Active() or Battle.Active() then
			return
		end
		lastGateText = os.clock()
		Dialog.Local("Guard", { tostring(gate:GetAttribute("Text") or "You can't pass yet.") }, "Guard")
	end)
end

---------------------------------------------------------------- Trainer-Sicht

local approaching = false
local spottedAt: { [string]: number } = {}

local function teamHealthy(): boolean
	if not collection or not collection.Team or not collection.Beasts then
		return false
	end
	for _, uid in collection.Team do
		local beast = collection.Beasts[uid]
		if beast and (beast.Hp or 0) > 0 then
			return true
		end
	end
	return false
end

local function exclamation(model: Model)
	local head = model:FindFirstChild("Head") :: BasePart? or model.PrimaryPart
	if not head then
		return
	end
	local board = create("BillboardGui", { Size = UDim2.fromOffset(60, 70), StudsOffsetWorldSpace = Vector3.new(0, 4, 0), AlwaysOnTop = true, LightInfluence = 0, Adornee = head, Parent = player:WaitForChild("PlayerGui") })
	local bubble = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(52, 60), BackgroundColor3 = C.Cream, Parent = board })
	Theme.corner(bubble, 14)
	Theme.stroke(bubble, C.Crimson, 3)
	label({ Size = UDim2.fromScale(1, 1), Text = "!", Font = Theme.Title, TextSize = 46, TextColor3 = C.Crimson, Parent = bubble })
	local scale = create("UIScale", { Scale = 0.2, Parent = bubble })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.4, function()
		board:Destroy()
	end)
end

local function setWalk(enabled: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if enabled then (player:GetAttribute("BaseWalkSpeed") or 18) else 0
	end
end

local function approach(model: Model, trainerId: string)
	approaching = true
	spottedAt[trainerId] = os.clock()
	setWalk(false)
	exclamation(model)
	task.wait(0.9)
	local root = rootPart()
	local start = model:GetPivot()
	if root then
		local target = root.Position
		local flat = Vector3.new(target.X, start.Position.Y, target.Z)
		local offset = flat - start.Position
		local distance = offset.Magnitude
		if distance > 5 then
			local goal = CFrame.lookAt(flat - offset.Unit * 4.5, flat)
			local value = Instance.new("CFrameValue")
			value.Value = start
			value.Changed:Connect(function(cf)
				model:PivotTo(cf)
			end)
			local tween = TweenService:Create(value, TweenInfo.new(math.min(2.2, distance / 16), Enum.EasingStyle.Linear), { Value = goal })
			tween:Play()
			tween.Completed:Wait()
			value:Destroy()
		end
	end
	remotes.TrainerSpotted:FireServer(trainerId)
	setWalk(true)
	-- Nach dem Kampf geht der Trainer an seinen Platz zurueck
	task.spawn(function()
		task.wait(3)
		while Battle.Active() or Dialog.Active() do
			task.wait(0.5)
		end
		if model.Parent then
			model:PivotTo(start)
		end
		approaching = false
	end)
end

local function checkSight()
	if approaching or Battle.Active() or Dialog.Active() or UI.SceneBusy() or not collection or not collection.Started then
		return
	end
	local root = rootPart()
	if not root or root.Anchored or not teamHealthy() then
		return
	end
	local folder = npcFolder()
	if not folder then
		return
	end
	local beaten = collection.Beaten or {}
	for _, model in folder:GetChildren() do
		local trainerId = model:GetAttribute("TrainerId")
		if model:IsA("Model") and typeof(trainerId) == "string" and not beaten[trainerId] then
			local trainer = Story.TrainersById[trainerId]
			local sight = model:GetAttribute("Sight") or 0
			if trainer and trainer.Sight > 0 and (not trainer.Flag or not hasFlag(trainer.Flag)) and os.clock() - (spottedAt[trainerId] or -100) > 8 then
				local pivot = model:GetPivot()
				local offset = root.Position - pivot.Position
				local forward = offset:Dot(pivot.LookVector)
				local side = math.abs(offset:Dot(pivot.RightVector))
				if forward > 0 and forward <= sight and side <= 5 and math.abs(offset.Y) < 12 then
					task.spawn(approach, model, trainerId)
					return
				end
			end
		end
	end
end

---------------------------------------------------------------- Effekte

local leafColors = { Color3.fromRGB(90, 170, 70), Color3.fromRGB(120, 200, 80), Color3.fromRGB(70, 140, 55) }

local function rustle(position: Vector3)
	for _ = 1, 3 do
		local leaf = Instance.new("Part")
		leaf.Anchored = true
		leaf.CanCollide = false
		leaf.CanQuery = false
		leaf.CanTouch = false
		leaf.CastShadow = false
		leaf.Size = Vector3.new(0.5, 0.1, 0.9)
		leaf.Color = leafColors[math.random(#leafColors)]
		leaf.Material = Enum.Material.Grass
		leaf.CFrame = CFrame.new(position + Vector3.new(math.random(-15, 15) / 10, 0.5, math.random(-15, 15) / 10)) * CFrame.Angles(0, math.random() * 6, math.random() - 0.5)
		leaf.Parent = workspace
		local goal = leaf.CFrame * CFrame.new(0, 2 + math.random(), 0) * CFrame.Angles(math.random() * 2, math.random() * 2, 0)
		TweenService:Create(leaf, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { CFrame = goal, Transparency = 1 }):Play()
		task.delay(0.65, function()
			leaf:Destroy()
		end)
	end
end

local function hideOwnDuelPrompt(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local prompt = root:WaitForChild("DuelPrompt", 10) :: ProximityPrompt?
	if prompt then
		prompt.Enabled = false
	end
end

function World.SetCollection(newCollection)
	collection = newCollection
	-- Was der Server bestaetigt hat, braucht keinen lokalen Vorgriff mehr
	for flag in localFlags do
		if collection.Flags and collection.Flags[flag] then
			localFlags[flag] = nil
		end
	end
	updateNpcs()
	updateGates()
end

-- Story-Ereignis "Hide": NPC sofort verschwinden lassen
function World.SetFlag(flag: string)
	localFlags[flag] = true
	updateNpcs()
	updateGates()
end

function World.Init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			showPrompt(prompt, inputType)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "DuelPrompt" then
			local target = Players:GetPlayerByUserId(prompt:GetAttribute("Owner") or 0)
			if target and target ~= player then
				remotes.DuelRequest:FireServer(target)
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal("StoryGate"):Connect(watchGate)
	for _, gate in CollectionService:GetTagged("StoryGate") do
		watchGate(gate)
	end

	task.spawn(function()
		local folder = workspace:WaitForChild("Npcs", 60)
		if folder then
			folder.ChildAdded:Connect(function(child)
				if child:IsA("Model") and not npcHome[child] then
					task.defer(updateNpc, child)
				end
			end)
			updateNpcs()
		end
	end)

	player.CharacterAdded:Connect(hideOwnDuelPrompt)
	if player.Character then
		task.spawn(hideOwnDuelPrompt, player.Character)
	end

	-- Trainer-Sicht und Gras-Rascheln
	task.spawn(function()
		local lastRustle = 0
		while true do
			task.wait(0.2)
			local ok, err = pcall(checkSight)
			if not ok then
				warn("[World]", err)
			end
			local root = rootPart()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.MoveDirection.Magnitude > 0.1 and os.clock() - lastRustle > 0.25 then
				local area = Story.AreaAt(root.Position)
				if Story.InGrass(area, root.Position) then
					lastRustle = os.clock()
					rustle(root.Position - Vector3.new(0, 3, 0))
				end
			end
		end
	end)

	-- Prismatische Bestien schimmern in allen Farben
	RunService.RenderStepped:Connect(function()
		local hue = (os.clock() * 0.25) % 1
		for _, part in CollectionService:GetTagged("Prismatic") do
			if part:IsA("BasePart") then
				part.Color = Color3.fromHSV(hue, 0.35, 1)
			end
		end
	end)
end

return World
