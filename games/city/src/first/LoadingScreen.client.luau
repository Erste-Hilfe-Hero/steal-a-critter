-- Eigener Ladebildschirm im Turbo-City-Stil: Sonnenuntergang, Skyline, fahrendes Auto als Fortschritt.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local INK = Color3.fromRGB(23, 21, 59)
local INK2 = Color3.fromRGB(42, 38, 96)
local CREAM = Color3.fromRGB(255, 248, 231)
local ORANGE = Color3.fromRGB(255, 122, 26)
local PINK = Color3.fromRGB(255, 61, 127)
local TEAL = Color3.fromRGB(25, 211, 197)
local LEMON = Color3.fromRGB(255, 225, 77)

local TIPS = {
	"Rob the Bank, then race to the HIDEOUT to cash in!",
	"Cops earn big bounties for every wanted robber they catch.",
	"Chain deliveries without stopping for up to +150% pay!",
	"Upgrade your house: it pays rent every minute, even while you're offline.",
	"Teal BOOST strips on the road give your car a turbo kick!",
	"Hit the jump pads in the STUNT PARK!",
	"Play with friends: +10% cash for every friend in your server!",
	"Come back every day: your daily reward grows with your streak!",
}

local function new(className: string, props: { [string]: any }): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	instance.Parent = props.Parent
	return instance
end

local gui = new("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
local background = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, BorderSizePixel = 0, Parent = gui })

-- Diagonale Streifen (bewegen sich langsam)
local stripes = new("Frame", { Size = UDim2.fromScale(1.6, 1.6), Position = UDim2.fromScale(-0.3, -0.3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = background })
-- ColorSequence erlaubt max. 20 Punkte: zwei harte Streifenpaare, die per Offset wandern
local stripeGradient = new("UIGradient", { Rotation = 30, Parent = stripes })
stripeGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, INK),
	ColorSequenceKeypoint.new(0.249, INK),
	ColorSequenceKeypoint.new(0.25, INK2),
	ColorSequenceKeypoint.new(0.499, INK2),
	ColorSequenceKeypoint.new(0.5, INK),
	ColorSequenceKeypoint.new(0.749, INK),
	ColorSequenceKeypoint.new(0.75, INK2),
	ColorSequenceKeypoint.new(1, INK2),
})

local stage = new("Frame", { Size = UDim2.fromOffset(1000, 560), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Parent = background })
local scale = new("UIScale", { Parent = stage })
local function rescale()
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(1000, 560)
	scale.Scale = math.clamp(math.min(size.X / 1000, size.Y / 560), 0.45, 2)
end
rescale()
local cameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(rescale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

-- Sonne
local sun = new("Frame", { Size = UDim2.fromOffset(420, 420), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 360), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = stage })
new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = sun })
new("UIGradient", { Color = ColorSequence.new(LEMON, PINK), Rotation = 90, Parent = sun })

-- Skyline
local skyline = new("Frame", { Size = UDim2.fromOffset(1000, 200), Position = UDim2.fromOffset(0, 300), BackgroundTransparency = 1, ClipsDescendants = false, Parent = stage })
local rng = Random.new(7)
local x = -20
while x < 1020 do
	local w = rng:NextInteger(50, 95)
	local h = rng:NextInteger(60, 190)
	local building = new("Frame", { Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, 200 - h), BackgroundColor3 = INK2, BorderSizePixel = 0, Parent = skyline })
	for wy = 14, h - 14, 22 do
		for wx = 10, w - 18, 20 do
			if rng:NextNumber() < 0.45 then
				new("Frame", { Size = UDim2.fromOffset(8, 10), Position = UDim2.fromOffset(wx, wy), BackgroundColor3 = LEMON, BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = building })
			end
		end
	end
	x += w + rng:NextInteger(-6, 6)
end

-- Strasse
local road = new("Frame", { Size = UDim2.fromOffset(1400, 70), Position = UDim2.fromOffset(-200, 490), BackgroundColor3 = Color3.fromRGB(35, 33, 70), BorderSizePixel = 0, Parent = stage })
new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = ORANGE, BorderSizePixel = 0, Parent = road })
local dashes = new("Frame", { Size = UDim2.fromOffset(1400, 6), Position = UDim2.fromOffset(0, 38), BackgroundTransparency = 1, Parent = road })
for i = 0, 27 do
	new("Frame", { Size = UDim2.fromOffset(30, 6), Position = UDim2.fromOffset(i * 50, 0), BackgroundColor3 = LEMON, BorderSizePixel = 0, Parent = dashes })
end

-- Auto (faehrt mit dem Fortschritt nach rechts)
local car = new("Frame", { Size = UDim2.fromOffset(120, 60), Position = UDim2.fromOffset(40, 444), BackgroundTransparency = 1, Parent = stage })
local body = new("Frame", { Size = UDim2.fromOffset(120, 30), Position = UDim2.fromOffset(0, 18), BackgroundColor3 = PINK, BorderSizePixel = 0, Parent = car })
new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = body })
new("UIStroke", { Color = INK, Thickness = 4, Parent = body })
local cabin = new("Frame", { Size = UDim2.fromOffset(60, 26), Position = UDim2.fromOffset(28, -2), BackgroundColor3 = TEAL, BorderSizePixel = 0, ZIndex = 0, Parent = car })
new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = cabin })
new("UIStroke", { Color = INK, Thickness = 4, Parent = cabin })
new("Frame", { Size = UDim2.fromOffset(12, 8), Position = UDim2.fromOffset(108, 26), BackgroundColor3 = LEMON, BorderSizePixel = 0, Parent = car })
local wheels = {}
for _, wx in { 14, 78 } do
	local wheel = new("Frame", { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(wx, 36), BackgroundColor3 = INK, BorderSizePixel = 0, Parent = car })
	new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = wheel })
	local hub = new("Frame", { Size = UDim2.fromOffset(12, 4), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = LEMON, BorderSizePixel = 0, Parent = wheel })
	table.insert(wheels, hub)
end

-- Logo: TURBO / CITY mit hartem Comic-Schatten
local function logoText(text: string, y: number, size: number, color: Color3)
	local shadow = new("TextLabel", { Size = UDim2.fromOffset(800, size), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(508, y + 8), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = text, TextSize = size, TextColor3 = PINK, Parent = stage })
	new("UIStroke", { Color = INK, Thickness = 6, Parent = shadow })
	local label = new("TextLabel", { Size = UDim2.fromOffset(800, size), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, y), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = text, TextSize = size, TextColor3 = color, Parent = stage })
	new("UIStroke", { Color = INK, Thickness = 6, Parent = label })
	return label, shadow
end
local logoTop = logoText("TURBO", 40, 130, LEMON)
local logoBottom = logoText("CITY", 160, 100, CREAM)
local ribbon = new("Frame", { Size = UDim2.fromOffset(300, 44), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(500, 285), Rotation = -4, BackgroundColor3 = TEAL, BorderSizePixel = 0, Parent = stage })
new("UIStroke", { Color = INK, Thickness = 4, Parent = ribbon })
new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = "COPS & ROBBERS", TextSize = 30, TextColor3 = INK, Parent = ribbon })

-- Fortschrittsbalken und Tipp
local bar = new("Frame", { Size = UDim2.fromOffset(520, 26), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 360), BackgroundColor3 = INK, BorderSizePixel = 0, Parent = stage })
new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = bar })
new("UIStroke", { Color = CREAM, Thickness = 3, Parent = bar })
local fill = new("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = bar })
new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = fill })
new("UIGradient", { Color = ColorSequence.new(ORANGE, PINK), Parent = fill })
local percent = new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy, Text = "0%", TextSize = 20, TextColor3 = CREAM, ZIndex = 2, Parent = bar })
new("UIStroke", { Color = INK, Thickness = 2, Parent = percent })
local tip = new("TextLabel", { Size = UDim2.fromOffset(800, 30), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(500, 396), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, Text = TIPS[math.random(1, #TIPS)], TextSize = 20, TextColor3 = CREAM, Parent = stage })
new("UIStroke", { Color = INK, Thickness = 2, Parent = tip })
local skip = new("TextButton", { Size = UDim2.fromOffset(110, 40), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 20), BackgroundColor3 = LEMON, Font = Enum.Font.LuckiestGuy, Text = "SKIP", TextSize = 24, TextColor3 = INK, Visible = false, AutoButtonColor = true, Parent = background })
new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = skip })
new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = skip })

gui.Parent = playerGui

-- Animationen
local progress = 0
local started = os.clock()
local done = false
local animation = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - started
	stripeGradient.Offset = Vector2.new((t * 0.05) % 0.5, 0)
	dashes.Position = UDim2.fromOffset(-((t * 260) % 50), 38)
	car.Position = UDim2.fromOffset(40 + progress * 820, 444 + math.abs(math.sin(t * 9)) * -3)
	for _, hub in wheels do
		hub.Rotation = (t * 720) % 360
	end
	local pulse = 1 + math.sin(t * 2.4) * 0.025
	logoTop.TextSize = 130 * pulse
	logoBottom.TextSize = 100 * pulse
	fill.Size = UDim2.fromScale(math.max(0.04, progress), 1)
	percent.Text = `{math.floor(progress * 100)}%`
end)

task.spawn(function()
	while not done do
		task.wait(4)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)
task.delay(8, function()
	skip.Visible = not done
end)

local skipped = false
skip.Activated:Connect(function()
	skipped = true
end)

-- Fortschritt: Spiel geladen, Assets geladen, Remotes da, Mindestdauer
local initialQueue = math.max(ContentProvider.RequestQueueSize, 1)
local minimum = 3.5
while not skipped do
	local loaded = if game:IsLoaded() then 0.4 else 0.1
	local queue = 1 - math.clamp(ContentProvider.RequestQueueSize / initialQueue, 0, 1)
	local remotes = if game:GetService("ReplicatedStorage"):FindFirstChild("Remotes") then 0.2 else 0
	local timeShare = math.clamp((os.clock() - started) / minimum, 0, 1)
	local target = math.min(loaded + queue * 0.2 + remotes + 0.2 * timeShare, 1)
	progress += (target - progress) * 0.15
	if game:IsLoaded() and remotes > 0 and os.clock() - started >= minimum and player.Character then
		progress = 1
		task.wait(0.4)
		break
	end
	if os.clock() - started > 30 then
		break
	end
	task.wait(0.05)
end

done = true
local tween = TweenService:Create(background, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = UDim2.fromScale(0, -1.1) })
tween:Play()
tween.Completed:Wait()
animation:Disconnect()
cameraConnection:Disconnect()
gui:Destroy()
