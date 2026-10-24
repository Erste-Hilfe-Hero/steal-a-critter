-- Welt auf dem Client: eigene Prompt-Optik, Zonen-Tore, prismatisches Schimmern, Interaktionen an Orten.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UI = require(script.Parent.UI)

local C = Theme.Colors
local create = Theme.create
local label = Theme.label

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local World = {}

---------------------------------------------------------------- Prompts im Arena-Stil

local function promptColor(prompt: ProximityPrompt): Color3
	if prompt.Name == "BattlePrompt" then
		return C.Crimson
	elseif prompt.Name == "DuelPrompt" then
		return C.Blue
	elseif prompt.Name == "Heal" then
		return C.Green
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
		StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),
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

---------------------------------------------------------------- Tore und Effekte

local function updateGate(gate: BasePart)
	local open = (player:GetAttribute("Crests") or 0) >= (gate:GetAttribute("Crests") or 0)
	gate.CanCollide = not open
	gate.Transparency = if open then 0.85 else 0.1
end

local function updateGates()
	for _, gate in CollectionService:GetTagged("ZoneGate") do
		updateGate(gate)
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

function World.Init()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			showPrompt(prompt, inputType)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local name = prompt.Name
		if name == "Arena" then
			UI.OpenArena()
		elseif name == "Shop" then
			UI.OpenItems()
		elseif name == "Heal" then
			remotes.Heal:FireServer()
		elseif name == "Daily" then
			remotes.ClaimDaily:FireServer()
		elseif name == "DuelPrompt" then
			local target = Players:GetPlayerByUserId(prompt:GetAttribute("Owner") or 0)
			if target and target ~= player then
				remotes.DuelRequest:FireServer(target)
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(updateGate)
	player:GetAttributeChangedSignal("Crests"):Connect(updateGates)
	updateGates()

	player.CharacterAdded:Connect(hideOwnDuelPrompt)
	if player.Character then
		task.spawn(hideOwnDuelPrompt, player.Character)
	end

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
