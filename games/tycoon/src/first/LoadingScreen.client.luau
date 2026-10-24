-- Eigener Ladebildschirm im Garten-Stil (ersetzt den Roblox-Standard): eine Pflanze waechst mit dem Fortschritt.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Your plants keep growing while you are offline!",
	"Rain makes plants grow faster and fruits can turn Wet (x2)!",
	"Thunderstorms create Shocked fruits worth x10!",
	"Golden fruits are worth x20 and Rainbow fruits x50!",
	"The seed shop restocks every 5 minutes - watch for Mythic seeds!",
	"Play with friends: +10% fruit value for every friend in your server!",
	"Come back every day - your daily reward grows with your streak!",
	"Many plants regrow after harvest - plant them once, harvest forever!",
}
local INK = Color3.fromRGB(18, 40, 22)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = Color3.new(1, 1, 1)
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 200, 255)),
	ColorSequenceKeypoint.new(0.62, Color3.fromRGB(190, 240, 255)),
	ColorSequenceKeypoint.new(0.63, Color3.fromRGB(100, 180, 75)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 140, 55)),
})
gradient.Rotation = 90
gradient.Parent = background

local function round(parent: Instance, scale: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(scale or 0.5, 0)
	corner.Parent = parent
end

local function outline(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.Parent = parent
	return stroke
end

local function text(props): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = background
	return label
end

local title = text({ Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromScale(0.8, 0.12), Text = "MAGIC GARDEN", TextColor3 = Color3.fromRGB(255, 236, 90) })
outline(title, 4)
local subtitle = text({ Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromScale(0.5, 0.09), Text = "TYCOON", TextColor3 = Color3.fromRGB(120, 255, 120) })
outline(subtitle, 4)

-- Pflanze: Stiel waechst mit dem Ladefortschritt, die Frucht wird reif
local stem = Instance.new("Frame")
stem.AnchorPoint = Vector2.new(0.5, 1)
stem.Position = UDim2.fromScale(0.5, 0.63)
stem.Size = UDim2.fromScale(0.012, 0)
stem.BackgroundColor3 = Color3.fromRGB(60, 170, 60)
stem.Parent = background
outline(stem, 3)

local fruit = Instance.new("Frame")
fruit.AnchorPoint = Vector2.new(0.5, 0.5)
fruit.Size = UDim2.fromScale(0.04, 0.04)
fruit.BackgroundColor3 = Color3.fromRGB(150, 210, 120)
fruit.Parent = background
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.Parent = fruit
round(fruit)
outline(fruit, 4)
local shine = Instance.new("Frame")
shine.Position = UDim2.fromScale(0.22, 0.18)
shine.Size = UDim2.fromScale(0.25, 0.25)
shine.BackgroundColor3 = Color3.new(1, 1, 1)
shine.Parent = fruit
round(shine)

local tip = text({ Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.8, 0.05), Text = TIPS[math.random(1, #TIPS)] })
outline(tip, 2)

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.84)
barBack.Size = UDim2.fromScale(0.5, 0.03)
barBack.BackgroundColor3 = INK
barBack.Parent = background
round(barBack)
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = Color3.fromRGB(255, 220, 60)
bar.Parent = barBack
round(bar)
local status = text({ Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromScale(0.5, 0.035), Text = "Watering the plants...", TextColor3 = Color3.fromRGB(230, 255, 220) })
outline(status, 2)

gui.Parent = playerGui

local unripe = Color3.fromRGB(150, 210, 120)
local ripe = Color3.fromRGB(255, 200, 40)
local start = os.clock()
local progress = 0
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	local shown = bar.Size.X.Scale
	local height = 0.06 + shown * 0.18
	stem.Size = UDim2.fromScale(0.012, height)
	local size = 0.04 + shown * 0.09
	fruit.Size = UDim2.fromScale(size, size)
	fruit.Position = UDim2.fromScale(0.5, 0.63 - height - size * 0.25 + math.sin(t * 3) * 0.005)
	fruit.BackgroundColor3 = unripe:Lerp(ripe, shown)
	fruit.Rotation = math.sin(t * 2) * 6
	title.Rotation = math.sin(t * 2) * 1.5
	bar.Size = UDim2.fromScale(shown + (progress - shown) * 0.1, 1)
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3)
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
status.Text = "Ready! Let's grow!"
task.wait(0.6)

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
