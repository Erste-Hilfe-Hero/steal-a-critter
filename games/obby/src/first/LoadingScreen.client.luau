-- Eigener Ladebildschirm im Regenbogen-Stil (ersetzt den Roblox-Standard).
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TIPS = {
	"Your checkpoint is saved - come back any time!",
	"Stuck? The SKIP button takes you to the next stage.",
	"Reach stage 10, 25, 50 and 75 to unlock free trails!",
	"Beat all 100 stages to earn a Win and the Champion trail.",
	"Play every day to rank up: Member, Regular, Veteran, Guardian!",
	"Red parts are lava - don't touch them!",
	"Glass platforms disappear - jump fast!",
}
local RAINBOW = {
	Color3.fromRGB(255, 80, 80),
	Color3.fromRGB(255, 170, 50),
	Color3.fromRGB(255, 225, 70),
	Color3.fromRGB(80, 220, 110),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(170, 90, 255),
}

local function sequence(colors: { Color3 }): ColorSequence
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

local function new(className: string, props, parent: Instance?)
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function round(parent: Instance, radius: number?)
	new("UICorner", { CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0) }, parent)
end

local gui = new("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100 })

local background = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 190, 255)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(170, 140, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 160, 210)),
	}),
	Rotation = 90,
}, background)

-- Wolken im Hintergrund
local clouds = {}
for i = 1, 6 do
	local cloud = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(math.random(), 0.1 + math.random() * 0.5),
		Size = UDim2.fromScale(0.12 + math.random() * 0.1, 0.06 + math.random() * 0.03),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
	}, background)
	round(cloud)
	clouds[i] = { Frame = cloud, Speed = 0.01 + math.random() * 0.02 }
end

-- Inhalt mit festem Seitenverhaeltnis, damit es auf jedem Bildschirm gleich aussieht
local stage = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, background)
new("UIAspectRatioConstraint", { AspectRatio = 16 / 9 }, stage)

local function label(props): TextLabel
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	props.AnchorPoint = Vector2.new(0.5, 0.5)
	return new("TextLabel", props, stage)
end

local title = label({ Position = UDim2.fromScale(0.5, 0.17), Size = UDim2.fromScale(0.86, 0.16), Text = "MEGA RAINBOW OBBY" })
local titleGradient = new("UIGradient", { Color = sequence(RAINBOW) }, title)
new("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 5 }, title)
local subtitle = label({ Position = UDim2.fromScale(0.5, 0.29), Size = UDim2.fromScale(0.6, 0.05), Text = "100 STAGES  ·  10 WORLDS", Font = Enum.Font.GothamBlack })
new("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 2, Transparency = 0.2 }, subtitle)

-- Regenbogen-Plattformen und eine huepfende Figur
local platforms = {}
for i, color in RAINBOW do
	local x = 0.22 + (i - 1) * 0.112
	local y = 0.62 - (i - 1) * 0.035
	local platform = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(0.07, 0.035),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, stage)
	round(platform, 6)
	new("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 3 }, platform)
	platforms[i] = { X = x, Y = y }
end

local hero = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromScale(0.03, 0.075),
	BackgroundColor3 = Color3.fromRGB(255, 255, 255),
	BorderSizePixel = 0,
}, stage)
round(hero, 6)
new("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 3 }, hero)
for _, x in { 0.3, 0.7 } do
	local eye = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, 0.3),
		Size = UDim2.fromScale(0.22, 0.12),
		BackgroundColor3 = Color3.fromRGB(30, 20, 60),
		BorderSizePixel = 0,
	}, hero)
	round(eye)
end

local tip = label({ Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(0.8, 0.045), Text = TIPS[math.random(1, #TIPS)], Font = Enum.Font.GothamBold })
new("UIStroke", { Color = Color3.fromRGB(30, 20, 60), Thickness = 2, Transparency = 0.3 }, tip)

local barBack = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.85),
	Size = UDim2.fromScale(0.42, 0.028),
	BackgroundColor3 = Color3.fromRGB(30, 20, 60),
	BorderSizePixel = 0,
}, stage)
round(barBack)
local bar = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, barBack)
round(bar)
new("UIGradient", { Color = sequence(RAINBOW) }, bar)
local status = label({ Position = UDim2.fromScale(0.5, 0.91), Size = UDim2.fromScale(0.4, 0.035), Text = "Building 100 stages...", Font = Enum.Font.GothamBold })

gui.Parent = playerGui

-- Animation: Figur springt von Plattform zu Plattform, Titel schimmert, Wolken ziehen
local start = os.clock()
local animation = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - start
	local hop = 0.55 -- Sekunden pro Sprung
	local step = math.floor(t / hop) % #platforms
	local alpha = (t % hop) / hop
	local from = platforms[step + 1]
	local to = platforms[(step + 1) % #platforms + 1]
	if step == #platforms - 1 then
		to = from -- auf der letzten Plattform kurz huepfen, dann zurueck an den Anfang
	end
	local x = from.X + (to.X - from.X) * alpha
	local y = from.Y + (to.Y - from.Y) * alpha - math.sin(alpha * math.pi) * 0.09
	hero.Position = UDim2.fromScale(x, y)
	hero.Rotation = if step == #platforms - 1 then 0 else alpha * 360
	hero.BackgroundColor3 = RAINBOW[step + 1]:Lerp(Color3.new(1, 1, 1), 0.55)
	titleGradient.Offset = Vector2.new(math.sin(t * 1.5) * 0.25, 0)
	title.Rotation = math.sin(t * 2) * 1.5
	for _, cloud in clouds do
		local position = cloud.Frame.Position
		local nx = position.X.Scale + cloud.Speed * dt
		cloud.Frame.Position = UDim2.fromScale(if nx > 1.15 then -0.15 else nx, position.Y.Scale)
	end
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3.2)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- Fortschritt: bis das Spiel geladen und die Strecke da ist (mindestens 2,5 s, hoechstens 15 s)
local initialQueue = math.max(ContentProvider.RequestQueueSize, 1)
while os.clock() - start < 15 do
	local loaded = game:IsLoaded()
	local course = workspace:FindFirstChild("Obby") ~= nil
	local queue = ContentProvider.RequestQueueSize
	local progress = math.clamp(1 - queue / initialQueue, 0, 1) * 0.7 + (if loaded then 0.15 else 0) + (if course then 0.15 else 0)
	bar.Size = UDim2.fromScale(math.max(bar.Size.X.Scale, progress), 1)
	if loaded and course and queue == 0 and os.clock() - start > 2.5 then
		break
	end
	task.wait(0.1)
end
bar.Size = UDim2.fromScale(1, 1)
status.Text = "Ready? GO!"
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
