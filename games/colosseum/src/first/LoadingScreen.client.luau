-- Eigener Ladebildschirm: Kolosseum-Silhouette im Abendrot, Lorbeer-Logo, wackelnder Fang-Orb, Tipps.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local GOLD = Color3.fromRGB(242, 193, 78)
local CREAM = Color3.fromRGB(250, 238, 215)
local CRIMSON = Color3.fromRGB(150, 28, 40)
local INK = Color3.fromRGB(28, 14, 26)

local TIPS = {
	"Weaken a wild beast before you throw an orb - low HP means a better catch chance!",
	"Fire beats Leaf, Leaf beats Water, Water beats Fire. Stone cracks Spark!",
	"Beat the 8 champions of the Colosseum to unlock new zones.",
	"PRISMATIC beasts are super rare and 20% stronger. Keep your eyes open!",
	"Your beasts ascend into stronger forms when they level up.",
	"How many waves can you survive in the Endless Gauntlet?",
	"Challenge other players to a duel to earn trophies!",
	"Claim your daily chest every day - day 7 gives a Master Orb!",
}

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100

local function frame(props, parent: Instance?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

-- Himmel im Abendrot
local background = frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1) }, gui)
local sky = Instance.new("UIGradient")
sky.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 18, 52)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(120, 30, 60)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(225, 110, 60)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(250, 190, 100)),
})
sky.Rotation = 90
sky.Parent = background

-- Sonne hinter dem Kolosseum
local sun = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.74), Size = UDim2.fromScale(0.42, 0.42), BackgroundColor3 = Color3.fromRGB(255, 205, 120), BackgroundTransparency = 0.15 }, background)
Instance.new("UIAspectRatioConstraint").Parent = sun
corner(sun, UDim.new(0.5, 0))

-- Kolosseum-Silhouette: zwei Reihen Boegen
local wall = frame({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1.05, 0.3), BackgroundColor3 = INK }, background)
local archRows = { { Y = 0.12, H = 0.3 }, { Y = 0.55, H = 0.32 } }
for _, row in archRows do
	for i = 0, 15 do
		local arch = frame({
			Position = UDim2.fromScale(0.012 + i / 16, row.Y),
			Size = UDim2.fromScale(0.036, row.H),
			BackgroundColor3 = Color3.fromRGB(240, 150, 80),
			BackgroundTransparency = 0.35,
		}, wall)
		corner(arch, UDim.new(0.5, 0))
	end
end
frame({ Position = UDim2.fromScale(0, -0.04), Size = UDim2.fromScale(1, 0.05), BackgroundColor3 = INK }, wall)

-- Logo: Titel mit Lorbeer
local logo = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromScale(0.8, 0.3), BackgroundTransparency = 1 }, background)
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 0)
title.Position = UDim2.fromScale(0.5, 0)
title.Size = UDim2.fromScale(0.76, 0.62)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.Text = "COLOSSEUM"
title.TextColor3 = GOLD
title.Parent = logo
stroke(title, INK, 5)
local titleShine = Instance.new("UIGradient")
titleShine.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 160)),
	ColorSequenceKeypoint.new(0.5, GOLD),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 120, 40)),
})
titleShine.Rotation = 90
titleShine.Parent = title

local ribbon = frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromScale(0.46, 0.3), BackgroundColor3 = CRIMSON }, logo)
corner(ribbon, UDim.new(0.2, 0))
stroke(ribbon, GOLD, 3)
local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.fromScale(1, 1)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.LuckiestGuy
subtitle.TextScaled = true
subtitle.Text = "CATCHER"
subtitle.TextColor3 = CREAM
subtitle.Parent = ribbon
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0.12, 0)
pad.PaddingBottom = UDim.new(0.08, 0)
pad.Parent = subtitle

-- Lorbeerblaetter links und rechts im Bogen
for _, side in { -1, 1 } do
	for i = 0, 6 do
		local t = i / 6
		local angle = math.rad(200 - t * 110)
		local x = 0.5 + side * (0.42 - math.cos(angle) * 0.06)
		local y = 0.55 - math.sin(angle) * 0.55
		local leaf = frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(0.035, 0.16),
			BackgroundColor3 = Color3.fromRGB(120, 170, 70):Lerp(GOLD, 0.45),
			Rotation = side * (30 + t * 60),
		}, logo)
		corner(leaf, UDim.new(0.5, 0))
		stroke(leaf, INK, 2)
	end
end

-- Crest-Orb als Ladeanzeige (wackelt wie beim Fangen): Purpur-Glas, Goldband, Stern-Juwel
local orb = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromScale(0.09, 0.09), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true }, background)
Instance.new("UIAspectRatioConstraint").Parent = orb
corner(orb, UDim.new(0.5, 0))
stroke(orb, INK, 4)
local glass = Instance.new("UIGradient")
glass.Color = ColorSequence.new(Color3.fromRGB(210, 70, 150), Color3.fromRGB(80, 18, 64))
glass.Rotation = 60
glass.Parent = orb
local band = frame({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromScale(1, 0.14), BackgroundColor3 = GOLD }, orb)
stroke(band, INK, 2)
local gem = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = CREAM, Rotation = 45 }, orb)
stroke(gem, INK, 3)
local shine = frame({ Position = UDim2.fromScale(0.2, 0.14), Size = UDim2.fromScale(0.18, 0.12), BackgroundColor3 = Color3.fromRGB(255, 215, 240) }, orb)
corner(shine, UDim.new(0.5, 0))

-- Fortschritt und Tipp
local barBack = frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.4, 0.018), BackgroundColor3 = INK, BackgroundTransparency = 0.3 }, background)
corner(barBack, UDim.new(1, 0))
stroke(barBack, GOLD, 2)
local bar = frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD }, barBack)
corner(bar, UDim.new(1, 0))

local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.Position = UDim2.fromScale(0.5, 0.71)
tip.Size = UDim2.fromScale(0.7, 0.04)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.BuilderSansBold
tip.TextScaled = true
tip.TextColor3 = CREAM
tip.Text = TIPS[math.random(1, #TIPS)]
tip.Parent = background
stroke(tip, INK, 1.5)

gui.Parent = playerGui

-- Animationen
local running = true
task.spawn(function()
	while running do
		for _, angle in { -25, 25, -15, 15, 0 } do
			if not running then
				break
			end
			TweenService:Create(orb, TweenInfo.new(0.16, Enum.EasingStyle.Sine), { Rotation = angle }):Play()
			task.wait(0.17)
		end
		task.wait(0.5)
	end
end)
task.spawn(function()
	while running do
		task.wait(3.5)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- Warten, bis das Spiel geladen ist (hoechstens 12 Sekunden), dabei Fortschritt anzeigen
local started = os.clock()
if not game:IsLoaded() then
	game.Loaded:Wait()
end
while os.clock() - started < 12 do
	local queue = ContentProvider.RequestQueueSize
	local progress = math.clamp((os.clock() - started) / 3, 0, 1) * (if queue > 0 then 0.85 else 1)
	bar.Size = UDim2.fromScale(progress, 1)
	if progress >= 1 and os.clock() - started > 2.5 then
		break
	end
	task.wait(0.05)
end
bar.Size = UDim2.fromScale(1, 1)
task.wait(0.3)
running = false

-- Ausblenden
local fade = TweenInfo.new(0.6)
for _, item in gui:GetDescendants() do
	if item:IsA("Frame") then
		TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play()
	elseif item:IsA("TextLabel") then
		TweenService:Create(item, fade, { TextTransparency = 1 }):Play()
	elseif item:IsA("UIStroke") then
		TweenService:Create(item, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.7)
gui:Destroy()
