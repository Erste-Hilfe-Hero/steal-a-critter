-- Eigener Ladebildschirm im Neon-Stil (ersetzt den Roblox-Standard).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Got robbed? Insurance pays you 25% back - and you get 90s of REVENGE!",
	"Fuse 3 identical critters into a stronger one with [F]!",
	"Rainbow critters earn 10x cash - watch the belt!",
	"Free server events every 8 minutes: Golden Hour, Critter Rush and more!",
	"Play with friends: +10% cash for every friend in your server!",
	"Slap thieves to make them drop your critter!",
	"Come back every day - your daily reward grows with your streak!",
}

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
	ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 20, 80)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(120, 40, 140)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 140)),
})
gradient.Rotation = 90
gradient.Parent = background

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

local title = text({ Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromScale(0.8, 0.14), Text = "STEAL A CRITTER", TextColor3 = Color3.fromRGB(255, 225, 70) })
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = Color3.fromRGB(255, 60, 150)
titleStroke.Thickness = 4
titleStroke.Parent = title

-- Huepfender Critter aus UI-Elementen (Koerper, Augen, Pupillen)
local critter = Instance.new("Frame")
critter.AnchorPoint = Vector2.new(0.5, 0.5)
critter.Position = UDim2.fromScale(0.5, 0.48)
critter.Size = UDim2.fromScale(0.16, 0.16)
critter.BackgroundColor3 = Color3.fromRGB(255, 100, 200)
critter.Parent = background
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.Parent = critter
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.5, 0)
round.Parent = critter
local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(25, 15, 40)
outline.Thickness = 5
outline.Parent = critter
for _, x in { 0.32, 0.68 } do
	local eye = Instance.new("Frame")
	eye.AnchorPoint = Vector2.new(0.5, 0.5)
	eye.Position = UDim2.fromScale(x, 0.42)
	eye.Size = UDim2.fromScale(0.26, 0.26)
	eye.BackgroundColor3 = Color3.new(1, 1, 1)
	eye.Parent = critter
	local eyeRound = round:Clone()
	eyeRound.Parent = eye
	local pupil = eye:Clone()
	pupil:ClearAllChildren()
	pupil.Size = UDim2.fromScale(0.5, 0.5)
	pupil.Position = UDim2.fromScale(0.55, 0.55)
	pupil.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
	pupil.Parent = eye
	round:Clone().Parent = pupil
end
local smile = Instance.new("Frame")
smile.AnchorPoint = Vector2.new(0.5, 0.5)
smile.Position = UDim2.fromScale(0.5, 0.72)
smile.Size = UDim2.fromScale(0.3, 0.06)
smile.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
smile.Parent = critter
round:Clone().Parent = smile

local tip = text({ Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.8, 0.06), Text = TIPS[math.random(1, #TIPS)] })

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.82)
barBack.Size = UDim2.fromScale(0.5, 0.03)
barBack.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
barBack.Parent = background
round:Clone().Parent = barBack
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = Color3.fromRGB(120, 255, 140)
bar.Parent = barBack
round:Clone().Parent = bar
local status = text({ Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(0.5, 0.035), Text = "Loading critters...", TextColor3 = Color3.fromRGB(230, 210, 255) })

gui.Parent = playerGui

-- Animation: Critter huepft, Titel pulsiert, Tipps wechseln
local start = os.clock()
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	critter.Position = UDim2.fromScale(0.5, 0.48 - math.abs(math.sin(t * 4)) * 0.06)
	critter.Rotation = math.sin(t * 4) * 8
	critter.BackgroundColor3 = Color3.fromHSV((t * 0.15) % 1, 0.6, 1)
	title.Rotation = math.sin(t * 2) * 2
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
	local progress = math.clamp(1 - queue / initialQueue, 0, 1) * 0.8 + (if loaded then 0.2 else 0)
	bar.Size = UDim2.fromScale(math.max(bar.Size.X.Scale, progress), 1)
	if loaded and queue == 0 and os.clock() - start > 2.5 then
		break
	end
	task.wait(0.1)
end
bar.Size = UDim2.fromScale(1, 1)
status.Text = "Ready! Go steal some critters!"
task.wait(0.4)

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
