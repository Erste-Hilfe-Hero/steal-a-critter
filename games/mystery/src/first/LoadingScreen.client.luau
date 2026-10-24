-- Eigener Ladebildschirm im Midnight-Stil: Nachthimmel mit funkelnden Sternen, Sichelmond,
-- Logo "MIDNIGHT MYSTERY", Tipps und Fortschrittsbalken.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local NIGHT = Color3.fromRGB(14, 16, 38)
local NIGHT2 = Color3.fromRGB(46, 30, 92)
local MOON = Color3.fromRGB(255, 214, 102)
local PINK = Color3.fromRGB(255, 92, 170)

local TIPS = {
	"Innocents: hide in closets (E) and slam doors in the Murderer's face!",
	"Sheriff: press SCAN to reveal the Murderer's glowing footprints.",
	"Murderer: secret VENTS take you across the map in a second.",
	"Hit an innocent as Sheriff and you're out too. Aim carefully!",
	"If the Sheriff goes down, grab the dropped blaster and become the HERO.",
	"Power-up boxes give Speed Soda, Bubble Shields, Coin Magnets and Ghost Mode.",
	"Out of the round? Make a GHOST GUESS for free coins.",
	"Every crate shows its odds. Or buy any skin directly in the shop.",
	"Five duplicate skins? FORGE them into a rarer one of your choice!",
	"Watch out for BLACKOUT rounds - only flashlights will save you.",
	"Daily quests, a free daily spin and login streaks give coins every day.",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = NIGHT
background.BorderSizePixel = 0
background.ClipsDescendants = true
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(NIGHT2, NIGHT)
gradient.Rotation = 90
gradient.Parent = background

local function round(parent: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = parent
end

-- Sterne
local stars = {}
for i = 1, 70 do
	local star = Instance.new("Frame")
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	local size = math.random(2, 5)
	star.Size = UDim2.fromOffset(size, size)
	star.Position = UDim2.fromScale(math.random(), math.random() * 0.8)
	star.BackgroundColor3 = Color3.new(1, 1, 1)
	star.BorderSizePixel = 0
	star.Parent = background
	round(star)
	stars[i] = { Frame = star, Speed = 1 + math.random() * 2, Phase = math.random() * 6 }
end

-- Sichelmond: gelber Kreis, davor ein Kreis in Himmelfarbe
local moon = Instance.new("Frame")
moon.AnchorPoint = Vector2.new(0.5, 0.5)
moon.Position = UDim2.fromScale(0.5, 0.25)
moon.Size = UDim2.fromScale(0.16, 0.16)
moon.BackgroundColor3 = MOON
moon.Parent = background
round(moon)
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.Parent = moon
local glow = Instance.new("UIStroke")
glow.Color = MOON
glow.Thickness = 10
glow.Transparency = 0.7
glow.Parent = moon
local shade = Instance.new("Frame")
shade.AnchorPoint = Vector2.new(0.5, 0.5)
shade.Position = UDim2.fromScale(0.72, 0.38)
shade.Size = UDim2.fromScale(0.9, 0.9)
shade.BackgroundColor3 = Color3.fromRGB(34, 24, 74)
shade.BorderSizePixel = 0
shade.Parent = moon
round(shade)

local function text(props): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = background
	return label
end

local title = text({ Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromScale(0.7, 0.13), Text = "MIDNIGHT", TextColor3 = MOON })
local titleStroke = Instance.new("UIStroke")
titleStroke.Thickness = 5
titleStroke.Color = Color3.fromRGB(10, 8, 30)
titleStroke.Parent = title
local subtitle = text({ Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.5, 0.09), Text = "MYSTERY", TextColor3 = PINK, Rotation = -3 })
titleStroke:Clone().Parent = subtitle

local tip = text({ Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.8, 0.045), Text = TIPS[math.random(1, #TIPS)], Font = Enum.Font.GothamBold })

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.82)
barBack.Size = UDim2.fromScale(0.45, 0.025)
barBack.BackgroundColor3 = Color3.fromRGB(40, 36, 90)
barBack.Parent = background
round(barBack)
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = MOON
bar.Parent = barBack
round(bar)
local barGradient = Instance.new("UIGradient")
barGradient.Color = ColorSequence.new(MOON, PINK)
barGradient.Parent = bar
local status = text({ Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(0.5, 0.032), Text = "Turning off the lights...", TextColor3 = Color3.fromRGB(190, 190, 240), Font = Enum.Font.GothamBold })

gui.Parent = playerGui

local start = os.clock()
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	for _, star in stars do
		star.Frame.BackgroundTransparency = 0.3 + 0.6 * (0.5 + 0.5 * math.sin(t * star.Speed + star.Phase))
	end
	moon.Position = UDim2.fromScale(0.5, 0.25 + math.sin(t * 1.4) * 0.012)
	glow.Transparency = 0.6 + math.sin(t * 2) * 0.15
	subtitle.Rotation = -3 + math.sin(t * 2.2) * 1.5
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- Fortschritt: bis das Spiel geladen ist (mindestens 2,5 s, hoechstens 15 s)
local initialQueue = math.max(ContentProvider.RequestQueueSize, 1)
while os.clock() - start < 15 do
	local loaded = game:IsLoaded()
	local queue = ContentProvider.RequestQueueSize
	local progress = math.clamp(1 - queue / initialQueue, 0, 1) * 0.8 + (if loaded then 0.2 else 0)
	bar.Size = UDim2.fromScale(math.max(bar.Size.X.Scale, progress), 1)
	if loaded and queue == 0 and os.clock() - start > 2.5 then
		break
	end
	task.wait(0.1)
end
bar.Size = UDim2.fromScale(1, 1)
status.Text = "Who is the Murderer?"
task.wait(0.5)

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
