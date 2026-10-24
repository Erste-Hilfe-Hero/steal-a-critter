-- Eigener Ladebildschirm im "Alpine Aurora"-Stil: Polarlicht, Logo und ein Surfer, der mit dem
-- Ladefortschritt eine Rampe hinuntersurft. Ersetzt den Roblox-Standard.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local NAVY = Color3.fromRGB(11, 21, 48)
local ICE = Color3.fromRGB(92, 225, 255)
local AURORA = Color3.fromRGB(255, 79, 163)
local MINT = Color3.fromRGB(110, 255, 190)
local SNOW = Color3.fromRGB(240, 248, 255)
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local TIPS = {
	"Hold A or D TOWARD the ramp - never W - to stick to it.",
	"Land on the side of a ramp, not on the top edge.",
	"Strafe and turn the mouse together in the air to gain speed.",
	"Falling resets the stage, but the map clock keeps running.",
	"Type /r to restart the run and /s to restart the stage.",
	"Every stage you clear unlocks it in the STAGES menu.",
	"Beat a stage record and the whole server hears about it!",
	"Pros hit 3000 u/s. How fast can you go?",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.new(1, 1, 1)
background.BorderSizePixel = 0
background.Parent = gui
local sky = Instance.new("UIGradient")
sky.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(6, 12, 32)),
	ColorSequenceKeypoint.new(0.6, NAVY),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 50, 110)),
})
sky.Rotation = 90
sky.Parent = background

-- Polarlicht: drei weiche Baender, die langsam wandern
local ribbons = {}
for i, color in { MINT, ICE, AURORA } do
	local ribbon = Instance.new("Frame")
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.fromScale(0.5, 0.18 + i * 0.07)
	ribbon.Size = UDim2.fromScale(1.6, 0.16)
	ribbon.Rotation = -8 + i * 3
	ribbon.BackgroundColor3 = color
	ribbon.BorderSizePixel = 0
	ribbon.BackgroundTransparency = 0.25
	ribbon.Parent = background
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.7, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = ribbon
	ribbons[i] = { Frame = ribbon, Gradient = fade, Phase = i * 1.7 }
end

-- Sterne/Schnee
local flakes = {}
for _ = 1, 60 do
	local flake = Instance.new("Frame")
	local size = math.random(2, 5)
	flake.Size = UDim2.fromOffset(size, size)
	flake.Position = UDim2.fromScale(math.random(), math.random())
	flake.BackgroundColor3 = SNOW
	flake.BackgroundTransparency = math.random() * 0.5
	flake.BorderSizePixel = 0
	flake.Parent = background
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = flake
	table.insert(flakes, { Frame = flake, Speed = 0.03 + math.random() * 0.05, Drift = math.random() * 2 })
end

-- Logo
local logo = Instance.new("TextLabel")
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.36)
logo.Size = UDim2.fromScale(0.7, 0.2)
logo.BackgroundTransparency = 1
logo.Text = "surf_ski"
logo.TextScaled = true
logo.FontFace = HEAVY
logo.TextColor3 = Color3.new(1, 1, 1)
logo.Parent = background
local logoGradient = Instance.new("UIGradient")
logoGradient.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, ICE), ColorSequenceKeypoint.new(0.55, SNOW), ColorSequenceKeypoint.new(1, AURORA) })
logoGradient.Parent = logo
local logoStroke = Instance.new("UIStroke")
logoStroke.Color = NAVY
logoStroke.Thickness = 4
logoStroke.Parent = logo

local tagline = Instance.new("TextLabel")
tagline.AnchorPoint = Vector2.new(0.5, 0.5)
tagline.Position = UDim2.fromScale(0.5, 0.48)
tagline.Size = UDim2.fromScale(0.6, 0.04)
tagline.BackgroundTransparency = 1
tagline.Text = "CLASSIC SURF  ·  10 ALPINE STAGES  ·  WORLD RECORDS"
tagline.TextScaled = true
tagline.FontFace = MONO
tagline.TextColor3 = ICE
tagline.Parent = background

-- Rampe mit Surfer (Punkt + Leuchtspur), der Surfer folgt dem Ladefortschritt
local rampFrame = Instance.new("Frame")
rampFrame.AnchorPoint = Vector2.new(0.5, 0.5)
rampFrame.Position = UDim2.fromScale(0.5, 0.66)
rampFrame.Size = UDim2.fromScale(0.62, 0.008)
rampFrame.Rotation = 9
rampFrame.BackgroundColor3 = SNOW
rampFrame.BackgroundTransparency = 0.2
rampFrame.BorderSizePixel = 0
rampFrame.Parent = background
local surfer = Instance.new("Frame")
surfer.AnchorPoint = Vector2.new(0.5, 1)
surfer.Size = UDim2.fromOffset(18, 18)
surfer.BackgroundColor3 = ICE
surfer.BorderSizePixel = 0
surfer.Parent = rampFrame
local surferRound = Instance.new("UICorner")
surferRound.CornerRadius = UDim.new(1, 0)
surferRound.Parent = surfer
local trail = Instance.new("Frame")
trail.AnchorPoint = Vector2.new(1, 1)
trail.Size = UDim2.new(0, 0, 0, 6)
trail.BackgroundColor3 = Color3.new(1, 1, 1)
trail.BorderSizePixel = 0
trail.Parent = rampFrame
local trailGradient = Instance.new("UIGradient")
trailGradient.Color = ColorSequence.new(MINT, AURORA)
trailGradient.Transparency = NumberSequence.new(1, 0)
trailGradient.Parent = trail

local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.Position = UDim2.fromScale(0.5, 0.8)
tip.Size = UDim2.fromScale(0.75, 0.04)
tip.BackgroundTransparency = 1
tip.TextScaled = true
tip.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
tip.TextColor3 = SNOW
tip.Text = TIPS[math.random(1, #TIPS)]
tip.Parent = background

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Position = UDim2.fromScale(0.5, 0.88)
status.Size = UDim2.fromScale(0.4, 0.03)
status.BackgroundTransparency = 1
status.TextScaled = true
status.FontFace = MONO
status.TextColor3 = Color3.fromRGB(150, 175, 215)
status.Text = "WAXING SKIS... 0%"
status.Parent = background

gui.Parent = playerGui

local start = os.clock()
local progress = 0
local shown = 0
local animation = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - start
	for _, r in ribbons do
		r.Gradient.Offset = Vector2.new(math.sin(t * 0.35 + r.Phase) * 0.25, 0)
		r.Frame.Position = UDim2.fromScale(0.5 + math.sin(t * 0.2 + r.Phase) * 0.04, r.Frame.Position.Y.Scale)
	end
	for _, f in flakes do
		local pos = f.Frame.Position
		local y = pos.Y.Scale + f.Speed * dt
		local x = pos.X.Scale + math.sin(t + f.Drift) * 0.0004
		f.Frame.Position = UDim2.fromScale(x % 1, if y > 1 then 0 else y)
	end
	shown += (progress - shown) * math.min(1, dt * 6)
	surfer.Position = UDim2.new(shown, 0, 0, -2)
	trail.Position = UDim2.new(shown, -6, 0, -4)
	trail.Size = UDim2.new(math.min(shown, 0.25), 0, 0, 6)
	logo.Rotation = math.sin(t * 1.4) * 1.2
	status.Text = `WAXING SKIS... {math.floor(shown * 100)}%`
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3.2)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- Fortschritt: bis das Spiel geladen ist und die Warteschlange leer ist (mindestens 2,5 s, hoechstens 15 s)
local initialQueue = math.max(ContentProvider.RequestQueueSize, 1)
while os.clock() - start < 15 do
	local loaded = game:IsLoaded()
	local queue = ContentProvider.RequestQueueSize
	local target = math.clamp(1 - queue / initialQueue, 0, 1) * 0.7 + (if loaded then 0.2 else 0) + math.min(0.1, (os.clock() - start) / 25)
	progress = math.max(progress, target)
	if loaded and queue == 0 and os.clock() - start > 2.5 then
		break
	end
	task.wait(0.1)
end
progress = 1
task.wait(0.5)
status.Text = "DROP IN!"

local fade = TweenInfo.new(0.6)
TweenService:Create(background, fade, { BackgroundTransparency = 1 }):Play()
for _, child in background:GetDescendants() do
	if child:IsA("TextLabel") then
		TweenService:Create(child, fade, { TextTransparency = 1 }):Play()
	elseif child:IsA("Frame") then
		TweenService:Create(child, fade, { BackgroundTransparency = 1 }):Play()
	elseif child:IsA("UIStroke") then
		TweenService:Create(child, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.7)
animation:Disconnect()
gui:Destroy()
