-- Eigener Ladebildschirm im Soccer-Jam-Stil: Navy mit schraegen Lime/Orange-Streifen,
-- springender Ball mit Speed-Linien, Logo, Tipps und Fortschrittsbalken.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local NAVY = Color3.fromRGB(16, 22, 52)
local LIME = Color3.fromRGB(190, 255, 60)
local ORANGE = Color3.fromRGB(255, 110, 30)
local FONT = Enum.Font.LuckiestGuy

local TIPS = {
	"Hold KICK for a harder shot - run sideways while kicking to CURVE the ball!",
	"Classic first person with your knife - press V (or VIEW) to switch to third person.",
	"KNIFE the ball carrier to make him drop the ball. Hit them from BEHIND for triple damage!",
	"No hunting: the knife only hurts near the ball!",
	"Pass to new teammates to build a POWERPLAY - up to x5 kick power!",
	"Jump while strafing for a LONG JUMP. Press T (or !) to call for a pass.",
	"STAB is slow but strong - a backstab knocks anyone out instantly!",
	"Earn EXP every match and buy upgrades: Stamina, Strength, Agility, Dexterity, Disarm.",
	"Hard enemy shots SMACK you down - level Dexterity to catch them instead!",
	"Stay out of the enemy goal zone - the ALIEN zaps you and kills ball carriers instantly!",
	"Stamina gives +20 max HP per level. Your own alien heals you near your goal.",
	"Long-distance goals give bonus EXP. Score from far away!",
	"First team to 10 goals wins. Tied at the end? Golden Goal!",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = NAVY
background.BorderSizePixel = 0
background.ClipsDescendants = true
background.Parent = gui

-- Schraege Streifen, die langsam durchs Bild ziehen
local stripes = {}
for i = 1, 7 do
	local stripe = Instance.new("Frame")
	stripe.AnchorPoint = Vector2.new(0.5, 0.5)
	stripe.Size = UDim2.new(0.06, 0, 2.2, 0)
	stripe.Rotation = 24
	stripe.BackgroundColor3 = if i % 2 == 0 then LIME else ORANGE
	stripe.BackgroundTransparency = 0.82
	stripe.BorderSizePixel = 0
	stripe.Parent = background
	stripes[i] = stripe
end

local function text(props): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = background
	return label
end

local logo = Instance.new("Frame")
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.24)
logo.Size = UDim2.fromScale(0.8, 0.22)
logo.BackgroundTransparency = 1
logo.Rotation = -4
logo.Parent = background
local turbo = text({ Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(1, 0.55), Text = "SOCCER", TextColor3 = LIME })
turbo.Parent = logo
local turboStroke = Instance.new("UIStroke")
turboStroke.Color = Color3.fromRGB(10, 14, 34)
turboStroke.Thickness = 5
turboStroke.Parent = turbo
local soccer = text({ Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.8, 0.4), Text = "JAM", TextColor3 = ORANGE })
soccer.Parent = logo
turboStroke:Clone().Parent = soccer

-- Ball: weisser Kreis mit Fuenfecken, dahinter Speed-Linien
local ball = Instance.new("Frame")
ball.AnchorPoint = Vector2.new(0.5, 0.5)
ball.Position = UDim2.fromScale(0.5, 0.52)
ball.Size = UDim2.fromScale(0.13, 0.13)
ball.BackgroundColor3 = Color3.new(1, 1, 1)
ball.Parent = background
local aspect = Instance.new("UIAspectRatioConstraint")
aspect.Parent = ball
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.5, 0)
round.Parent = ball
local outline = Instance.new("UIStroke")
outline.Color = NAVY
outline.Thickness = 4
outline.Parent = ball
for _, spot in { { 0.5, 0.5, 0.34 }, { 0.15, 0.3, 0.2 }, { 0.85, 0.3, 0.2 }, { 0.25, 0.85, 0.2 }, { 0.75, 0.85, 0.2 }, { 0.5, 0.05, 0.16 } } do
	local patch = Instance.new("Frame")
	patch.AnchorPoint = Vector2.new(0.5, 0.5)
	patch.Position = UDim2.fromScale(spot[1], spot[2])
	patch.Size = UDim2.fromScale(spot[3], spot[3])
	patch.BackgroundColor3 = NAVY
	patch.Rotation = 18
	patch.Parent = ball
	local patchRound = Instance.new("UICorner")
	patchRound.CornerRadius = UDim.new(0.3, 0)
	patchRound.Parent = patch
end
local speedLines = {}
for i = 1, 3 do
	local streak = Instance.new("Frame")
	streak.AnchorPoint = Vector2.new(1, 0.5)
	streak.Size = UDim2.fromScale(0.12 + i * 0.03, 0.012)
	streak.BackgroundColor3 = if i == 2 then ORANGE else LIME
	streak.BorderSizePixel = 0
	streak.Parent = background
	local streakRound = round:Clone()
	streakRound.Parent = streak
	speedLines[i] = streak
end
-- Schatten unter dem Ball
local shadow = Instance.new("Frame")
shadow.AnchorPoint = Vector2.new(0.5, 0.5)
shadow.Position = UDim2.fromScale(0.5, 0.62)
shadow.Size = UDim2.fromScale(0.09, 0.018)
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.6
shadow.Parent = background
round:Clone().Parent = shadow

local tip = text({ Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.8, 0.05), Text = TIPS[math.random(1, #TIPS)], Font = Enum.Font.GothamBold })

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.82)
barBack.Size = UDim2.fromScale(0.5, 0.03)
barBack.BackgroundColor3 = Color3.fromRGB(32, 42, 90)
barBack.Parent = background
round:Clone().Parent = barBack
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = LIME
bar.Parent = barBack
round:Clone().Parent = bar
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(LIME, ORANGE)
gradient.Parent = bar
local status = text({ Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(0.5, 0.035), Text = "Warming up the stadium...", TextColor3 = Color3.fromRGB(200, 215, 255), Font = Enum.Font.GothamBold })

gui.Parent = playerGui

local start = os.clock()
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	for i, stripe in stripes do
		local x = ((i / #stripes + t * 0.05) % 1.2) - 0.1
		stripe.Position = UDim2.fromScale(x, 0.5)
	end
	local bounce = math.abs(math.sin(t * 3.2))
	ball.Position = UDim2.fromScale(0.5, 0.58 - bounce * 0.1)
	ball.Rotation = (t * 360) % 360
	shadow.Size = UDim2.fromScale(0.09 - bounce * 0.04, 0.018)
	for i, streak in speedLines do
		streak.Position = UDim2.new(0.5, -ball.AbsoluteSize.X * 0.55, 0.58 - bounce * 0.1 + (i - 2) * 0.03, 0)
		streak.BackgroundTransparency = 0.2 + 0.3 * math.sin(t * 8 + i)
	end
	logo.Rotation = -4 + math.sin(t * 2) * 1.5
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
status.Text = "Kickoff!"
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
