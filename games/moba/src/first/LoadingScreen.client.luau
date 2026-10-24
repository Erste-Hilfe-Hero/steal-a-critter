-- Eigener Ladebildschirm: Dawn (Gold) und Dusk (Violett) prallen aufeinander, darueber das Logo.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Stay behind your minions - towers shoot heroes when no minions are around!",
	"Tap an enemy to focus it. Your hero attacks automatically.",
	"Press 🏠 to recall to your fountain, heal up and buy items.",
	"Auto-Buy picks the best items for your hero when you visit the fountain.",
	"Defeat the Sky Titan to make your whole team stronger!",
	"The Treasure Golem gives gold to every hero on your team.",
	"Win matches to earn crystals and unlock new heroes!",
	"Your first win every day gives bonus crystals.",
}
local INK = Color3.fromRGB(14, 18, 34)
local DAWN = Color3.fromRGB(255, 184, 64)
local DUSK = Color3.fromRGB(150, 110, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = INK
background.Parent = gui

local function glow(color: Color3, x: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, 0.55)
	frame.Size = UDim2.fromScale(0.9, 1.6)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Rotation = 18
	frame.Parent = background
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = frame
	return frame
end
glow(DAWN, 0.12)
glow(DUSK, 0.88)

local function label(props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = background
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = props.TextSize or 3
	stroke.Color = Color3.fromRGB(8, 8, 18)
	stroke.Parent = l
	return l
end

-- Zwei Kristalle, die sich treffen
local function crystal(color: Color3, x: number): Frame
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(x, 0.5)
	frame.Size = UDim2.fromScale(0.07, 0.07)
	frame.BackgroundColor3 = color
	frame.Rotation = 45
	frame.Parent = background
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.3
	stroke.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = frame
	return frame
end
local left = crystal(DAWN, 0.3)
local right = crystal(DUSK, 0.7)

local title = label({ Position = UDim2.fromScale(0.5, 0.22), Size = UDim2.fromScale(0.8, 0.16), Text = "LANEBREAKERS" })
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, DAWN),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 220)),
	ColorSequenceKeypoint.new(1, DUSK),
})
titleGradient.Parent = title
label({ Position = UDim2.fromScale(0.5, 0.33), Size = UDim2.fromScale(0.4, 0.06), Text = "HERO ARENA", TextColor3 = Color3.fromRGB(230, 226, 240) })
local versus = label({ Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.12, 0.08), Text = "VS", TextColor3 = Color3.fromRGB(255, 240, 220), TextTransparency = 1 })

local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.Position = UDim2.fromScale(0.5, 0.74)
tip.Size = UDim2.fromScale(0.8, 0.045)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.BuilderSansBold
tip.TextScaled = true
tip.TextColor3 = Color3.fromRGB(200, 204, 222)
tip.Text = TIPS[math.random(1, #TIPS)]
tip.Parent = background

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.84)
barBack.Size = UDim2.fromScale(0.46, 0.018)
barBack.BackgroundColor3 = Color3.fromRGB(34, 40, 66)
barBack.Parent = background
local backCorner = Instance.new("UICorner")
backCorner.CornerRadius = UDim.new(1, 0)
backCorner.Parent = barBack
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = Color3.new(1, 1, 1)
bar.Parent = barBack
local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(1, 0)
barCorner.Parent = bar
local barGradient = Instance.new("UIGradient")
barGradient.Color = ColorSequence.new(DAWN, DUSK)
barGradient.Parent = bar

gui.Parent = playerGui

local start = os.clock()
local progress = 0
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	local shown = bar.Size.X.Scale
	-- Kristalle naehern sich mit dem Fortschritt
	local gap = 0.2 * (1 - shown) + 0.045
	left.Position = UDim2.fromScale(0.5 - gap, 0.5 + math.sin(t * 3) * 0.008)
	right.Position = UDim2.fromScale(0.5 + gap, 0.5 - math.sin(t * 3) * 0.008)
	left.Rotation = 45 + t * 40
	right.Rotation = 45 - t * 40
	versus.TextTransparency = 1 - math.clamp(shown * 1.5, 0, 1)
	title.Rotation = math.sin(t * 1.6) * 1.2
	titleGradient.Offset = Vector2.new(math.sin(t) * 0.15, 0)
	bar.Size = UDim2.fromScale(shown + (progress - shown) * 0.1, 1)
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3.2)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

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
task.wait(0.7)

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
