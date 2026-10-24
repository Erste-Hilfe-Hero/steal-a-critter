-- Eigener Ladebildschirm im "Fire Blaster"-Stil: dunkler Hintergrund, laufende Flammen-Chevrons,
-- Logo mit Flammenverlauf und ein kleines Kart, das als Fortschrittsbalken ueber eine Rennstrecke faehrt.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local TITLE = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(16, 13, 22)
local TIPS = {
	"Hold DRIFT while turning to charge a turbo: blue, orange, then PURPLE!",
	"Item boxes give stronger items the further behind you are.",
	"Collect coins on the track: each one makes your kart faster.",
	"Press the gas as the last light turns on for a Rocket Start!",
	"Flame Shield blocks one hit. Inferno Mode makes you unstoppable!",
	"Vote for your favourite of 10 tracks before every race.",
}

local function flame(rotation: number): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 228, 100)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 138, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 57, 42)),
	})
	g.Rotation = rotation
	return g
end

local function frame(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.FontFace = BODY
	t.TextColor3 = Color3.new(1, 1, 1)
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	for key, value in props do
		(t :: any)[key] = value
	end
	t.Parent = parent
	return t
end

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local bg = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = INK, ClipsDescendants = true })
local glow = frame(bg, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 90, 20), BackgroundTransparency = 0 })
local glowGradient = Instance.new("UIGradient")
glowGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.6, 0.92),
	NumberSequenceKeypoint.new(1, 0.55),
})
glowGradient.Rotation = 90
glowGradient.Parent = glow

-- Laufende Chevrons (Geschwindigkeits-Streifen)
local stripes = {}
for i = 1, 14 do
	local s = frame(bg, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(0, 14, 1.6, 0),
		Rotation = 22,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.88 + (i % 3) * 0.03,
	})
	flame(90).Parent = s
	stripes[i] = { Frame = s, Offset = i / 14 }
end

local logo = frame(bg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.33), Size = UDim2.fromScale(0.8, 0.3), BackgroundTransparency = 1 })
local fire = label(logo, { Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromScale(1, 0.62), Text = "FIRE BLASTER", FontFace = TITLE })
flame(90).Parent = fire
local fireStroke = Instance.new("UIStroke")
fireStroke.Thickness = 5
fireStroke.Color = Color3.fromRGB(70, 12, 0)
fireStroke.Parent = fire
local race = label(logo, { Position = UDim2.fromScale(0.5, 0.82), Size = UDim2.fromScale(0.45, 0.36), Text = "RACE", FontFace = TITLE })
fireStroke:Clone().Parent = race
local slashL = frame(logo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.27, 0.82), Size = UDim2.new(0.1, 0, 0, 6), BackgroundColor3 = Color3.new(1, 1, 1) })
flame(0).Parent = slashL
local slashR = slashL:Clone()
slashR.Position = UDim2.fromScale(0.73, 0.82)
slashR.Parent = logo

-- Strecke als Fortschrittsbalken mit kleinem Kart
local road = frame(bg, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromScale(0.62, 0.05), BackgroundColor3 = Color3.fromRGB(42, 36, 52) })
Instance.new("UICorner", road).CornerRadius = UDim.new(1, 0)
local dashes = frame(road, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 3), BackgroundTransparency = 1 })
for i = 0, 19 do
	frame(dashes, { Position = UDim2.fromScale(i / 20 + 0.01, 0), Size = UDim2.fromScale(0.025, 1), BackgroundColor3 = Color3.fromRGB(230, 220, 200), BackgroundTransparency = 0.5 })
end
local fill = frame(road, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.15 })
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
flame(0).Parent = fill
local kart = frame(road, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0, 0.2), Size = UDim2.fromScale(0.07, 1.6), BackgroundTransparency = 1 })
local body = frame(kart, { Position = UDim2.fromScale(0, 0.3), Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.fromRGB(255, 120, 40) })
Instance.new("UICorner", body).CornerRadius = UDim.new(0.3, 0)
local helmet = frame(kart, { Position = UDim2.fromScale(0.35, 0), Size = UDim2.fromScale(0.3, 0.45), BackgroundColor3 = Color3.new(1, 1, 1) })
Instance.new("UICorner", helmet).CornerRadius = UDim.new(1, 0)
for _, x in { 0.08, 0.68 } do
	local wheel = frame(kart, { Position = UDim2.fromScale(x, 0.62), Size = UDim2.fromScale(0.26, 0.4), BackgroundColor3 = INK })
	Instance.new("UICorner", wheel).CornerRadius = UDim.new(1, 0)
end
local exhaust = frame(kart, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(0, 0.52), Size = UDim2.fromScale(0.9, 0.28), BackgroundColor3 = Color3.new(1, 1, 1) })
local exhaustGradient = flame(180)
exhaustGradient.Transparency = NumberSequence.new(1, 0)
exhaustGradient.Parent = exhaust

local tip = label(bg, { Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.7, 0.045), Text = TIPS[math.random(1, #TIPS)], TextColor3 = Color3.fromRGB(235, 225, 245) })
local status = label(bg, { Position = UDim2.fromScale(0.5, 0.88), Size = UDim2.fromScale(0.4, 0.03), Text = "WARMING UP ENGINES...", FontFace = TITLE, TextColor3 = Color3.fromRGB(255, 160, 60) })

gui.Parent = playerGui

local start = os.clock()
local progress = 0
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	for _, s in stripes do
		local x = (s.Offset - t * 0.35) % 1.2 - 0.1
		s.Frame.Position = UDim2.fromScale(x, 0.5)
	end
	logo.Rotation = math.sin(t * 2.2) * 1.2
	fire.Position = UDim2.fromScale(0.5 + math.sin(t * 30) * 0.0015, 0.32)
	kart.Position = UDim2.new(progress, 0, 0.2 + math.abs(math.sin(t * 18)) * -0.06, 0)
	exhaust.Size = UDim2.fromScale(0.7 + math.sin(t * 40) * 0.2, 0.28)
	fill.Size = UDim2.fromScale(progress, 1)
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- Fortschritt: bis das Spiel geladen ist und die Warteschlange leer ist (mindestens 3 s, hoechstens 15 s)
local initialQueue = math.max(ContentProvider.RequestQueueSize, 1)
while os.clock() - start < 15 do
	local loaded = game:IsLoaded()
	local queue = ContentProvider.RequestQueueSize
	local target = math.clamp(1 - queue / initialQueue, 0, 1) * 0.7 + (if loaded then 0.2 else 0) + math.min(0.1, (os.clock() - start) / 30)
	progress = math.max(progress, math.min(target, (os.clock() - start) / 3))
	if loaded and queue == 0 and os.clock() - start > 3 then
		break
	end
	task.wait(0.05)
end
while progress < 1 do
	progress = math.min(1, progress + 0.04)
	task.wait()
end
status.Text = "GO!"
task.wait(0.4)

local fade = TweenInfo.new(0.5)
for _, child in bg:GetDescendants() do
	if child:IsA("TextLabel") then
		TweenService:Create(child, fade, { TextTransparency = 1 }):Play()
	elseif child:IsA("Frame") then
		TweenService:Create(child, fade, { BackgroundTransparency = 1 }):Play()
	elseif child:IsA("UIStroke") then
		TweenService:Create(child, fade, { Transparency = 1 }):Play()
	end
end
TweenService:Create(bg, fade, { BackgroundTransparency = 1 }):Play()
task.wait(0.55)
animation:Disconnect()
gui:Destroy()
