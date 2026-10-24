-- Eigener Ladebildschirm im Laternen-Stil: eine schwingende Laterne leuchtet mit dem Fortschritt heller.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Walk into a glowing portal circle to start a dungeon. Friends can join you!",
	"Loot beams show rarity: white, green, blue, purple, orange - and red Mythics in Nightmare!",
	"Legendary items have special powers like chain lightning and twin strikes.",
	"Salvage old gear for shards, then enhance your best items at the Forge.",
	"Red circles on the ground mean danger - step out of them!",
	"Clear a dungeon on Normal to unlock Hard, then Nightmare.",
	"Play with friends: +10% gold and XP for every friend in your server!",
	"The Lightbringer heals the whole party. Unlock it at level 20.",
	"Turn on AUTO to attack the nearest enemy automatically.",
}
local AMBER = Color3.fromRGB(255, 184, 74)
local INK = Color3.fromRGB(12, 12, 28)

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
	ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 30, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(48, 34, 86)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 14, 34)),
})
gradient.Rotation = 90
gradient.Parent = background

local function round(parent: Instance, scale: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(scale or 0.5, 0)
	c.Parent = parent
end

local function outline(parent: Instance, thickness: number, color: Color3?)
	local s = Instance.new("UIStroke")
	s.Color = color or INK
	s.Thickness = thickness
	s.Parent = parent
	return s
end

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

-- Sterne
local rng = Random.new()
for _ = 1, 40 do
	local star = Instance.new("Frame")
	local size = rng:NextNumber(0.002, 0.005)
	star.Size = UDim2.fromScale(size, size)
	star.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber(0, 0.6))
	star.BackgroundColor3 = Color3.fromRGB(255, 240, 210)
	star.BackgroundTransparency = rng:NextNumber(0.2, 0.7)
	star.BorderSizePixel = 0
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.Parent = star
	round(star)
	star.Parent = background
end

local title = text({ Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromScale(0.8, 0.13), Text = "LANTERN LEGENDS", TextColor3 = AMBER })
outline(title, 4)
local subtitle = text({ Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromScale(0.5, 0.06), Text = "DUNGEONS  ·  LOOT  ·  CO-OP", TextColor3 = Color3.fromRGB(220, 210, 255) })
outline(subtitle, 3)

-- Laterne: Kette, Gehaeuse, Flamme mit Schein
local pivot = Instance.new("Frame")
pivot.AnchorPoint = Vector2.new(0.5, 0)
pivot.Position = UDim2.fromScale(0.5, 0.3)
pivot.Size = UDim2.fromScale(0.14, 0.36)
pivot.BackgroundTransparency = 1
pivot.Parent = background
local chain = Instance.new("Frame")
chain.AnchorPoint = Vector2.new(0.5, 0)
chain.Position = UDim2.fromScale(0.5, 0)
chain.Size = UDim2.fromScale(0.04, 0.3)
chain.BackgroundColor3 = Color3.fromRGB(70, 60, 60)
chain.BorderSizePixel = 0
chain.Parent = pivot
local glow = Instance.new("Frame")
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.fromScale(0.5, 0.62)
glow.Size = UDim2.fromScale(2.4, 1.3)
glow.BackgroundColor3 = AMBER
glow.BackgroundTransparency = 0.85
glow.BorderSizePixel = 0
round(glow)
glow.Parent = pivot
local cap = Instance.new("Frame")
cap.AnchorPoint = Vector2.new(0.5, 0)
cap.Position = UDim2.fromScale(0.5, 0.28)
cap.Size = UDim2.fromScale(0.8, 0.08)
cap.BackgroundColor3 = Color3.fromRGB(80, 60, 44)
cap.Parent = pivot
round(cap, 0.3)
outline(cap, 3)
local body = Instance.new("Frame")
body.AnchorPoint = Vector2.new(0.5, 0)
body.Position = UDim2.fromScale(0.5, 0.36)
body.Size = UDim2.fromScale(0.62, 0.5)
body.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
body.BackgroundTransparency = 0.1
body.Parent = pivot
round(body, 0.25)
outline(body, 4, Color3.fromRGB(80, 60, 44))
local flame = Instance.new("Frame")
flame.AnchorPoint = Vector2.new(0.5, 0.5)
flame.Position = UDim2.fromScale(0.5, 0.6)
flame.Size = UDim2.fromScale(0.36, 0.5)
flame.BackgroundColor3 = Color3.fromRGB(255, 240, 170)
flame.Parent = body
round(flame)
local base = Instance.new("Frame")
base.AnchorPoint = Vector2.new(0.5, 0)
base.Position = UDim2.fromScale(0.5, 0.86)
base.Size = UDim2.fromScale(0.8, 0.07)
base.BackgroundColor3 = Color3.fromRGB(80, 60, 44)
base.Parent = pivot
round(base, 0.3)
outline(base, 3)

local tip = text({ Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.8, 0.045), Text = TIPS[math.random(1, #TIPS)], Font = Enum.Font.BuilderSansBold, TextColor3 = Color3.fromRGB(235, 230, 250) })

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.84)
barBack.Size = UDim2.fromScale(0.5, 0.026)
barBack.BackgroundColor3 = INK
barBack.Parent = background
round(barBack)
outline(barBack, 2, Color3.fromRGB(120, 90, 50))
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = AMBER
bar.Parent = barBack
round(bar)
local status = text({ Position = UDim2.fromScale(0.5, 0.9), Size = UDim2.fromScale(0.5, 0.032), Text = "Lighting the lanterns...", Font = Enum.Font.BuilderSansBold, TextColor3 = Color3.fromRGB(255, 220, 170) })

gui.Parent = playerGui

local start = os.clock()
local progress = 0
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	local shown = bar.Size.X.Scale
	pivot.Rotation = math.sin(t * 1.8) * 9
	local flicker = 0.9 + math.sin(t * 13) * 0.05 + math.sin(t * 7.3) * 0.05
	flame.Size = UDim2.fromScale(0.3 * flicker + shown * 0.12, 0.42 * flicker + shown * 0.12)
	glow.BackgroundTransparency = 0.92 - shown * 0.2 - (flicker - 0.9) * 0.3
	glow.Size = UDim2.fromScale(1.6 + shown * 1.6, 0.9 + shown * 0.8)
	title.Rotation = math.sin(t * 1.4) * 1.2
	bar.Size = UDim2.fromScale(shown + (progress - shown) * 0.1, 1)
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3.5)
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
status.Text = "Ready, hero!"
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
