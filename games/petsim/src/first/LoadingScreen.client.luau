-- Eigener Ladebildschirm (ersetzt den Roblox-Standard): ein Ei wackelt, springt auf und ein Haustier huepft heraus.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local INK = Color3.fromRGB(34, 22, 50)
local TIPS = {
	"Your pets break coin piles near you automatically - tap a chest to pick a target!",
	"Combine 5 of the same pet into a GOLDEN pet with 3x power!",
	"Every egg shows its chances - can you find the 1 in 2000 Cosmic Overlord?",
	"Claim your free DAILY GIFT at the spawn every day!",
	"Unlock new worlds for stronger pets and bigger coins!",
	"Rebirth to keep all your pets and earn more coins forever!",
	"Play longer to rank up: Member, Regular, Veteran and Guardian!",
}
-- Farben, die das Haustier nacheinander annimmt (wie die Seltenheiten im Spiel)
local PET_COLORS = {
	Color3.fromRGB(130, 205, 255),
	Color3.fromRGB(110, 220, 140),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(255, 160, 80),
	Color3.fromRGB(255, 205, 60),
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
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 90, 230)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(80, 170, 230)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(130, 245, 215)),
})
gradient.Rotation = 90
gradient.Parent = background

local function round(parent: GuiObject, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0.5, 0)
	corner.Parent = parent
end

local function outline(parent: GuiObject, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function frame(parent: Instance, props): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	for key, value in props do
		(f :: any)[key] = value
	end
	f.Parent = parent
	return f
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
	outline(label, 3)
	label.Parent = background
	return label
end

-- Lichtstrahlen hinter dem Ei
local rays = frame(background, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.6, 1.6), BackgroundTransparency = 1 })
Instance.new("UIAspectRatioConstraint").Parent = rays
for i = 1, 12 do
	local ray = frame(rays, { Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.07, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.88, Rotation = i * 15 })
	ray.ZIndex = 0
end

local title = text({ Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromScale(0.86, 0.13), Text = "CRITTER HATCH", TextColor3 = Color3.fromRGB(255, 230, 70) })
local subtitle = text({ Position = UDim2.fromScale(0.5, 0.25), Size = UDim2.fromScale(0.5, 0.075), Text = "SIMULATOR" })
for _, label in { title, subtitle } do
	(label:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 5
end

-- Buehne mit festem Seitenverhaeltnis, damit Ei und Haustier auf jedem Handy rund bleiben
local stage = frame(background, { Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.3, 0.32), BackgroundTransparency = 1 })
Instance.new("UIAspectRatioConstraint").Parent = stage

local shadow = frame(stage, { Position = UDim2.fromScale(0.5, 0.97), Size = UDim2.fromScale(0.6, 0.08), BackgroundColor3 = INK, BackgroundTransparency = 0.75 })
round(shadow)

-- Haustier (startet im Ei versteckt)
local pet = frame(stage, { Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.62, 0.58), BackgroundColor3 = PET_COLORS[1], Visible = false })
round(pet)
outline(pet, 4)
local ears = {}
for _, x in { 0.18, 0.82 } do
	local ear = frame(pet, { Position = UDim2.fromScale(x, 0.06), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = PET_COLORS[1] })
	ear.ZIndex = 0
	round(ear)
	outline(ear, 4)
	table.insert(ears, ear)
end
local belly = frame(pet, { Position = UDim2.fromScale(0.5, 0.72), Size = UDim2.fromScale(0.56, 0.4), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45 })
round(belly)
for _, x in { 0.32, 0.68 } do
	local eye = frame(pet, { Position = UDim2.fromScale(x, 0.42), Size = UDim2.fromScale(0.2, 0.26), BackgroundColor3 = INK })
	round(eye)
	local shine = frame(eye, { Position = UDim2.fromScale(0.38, 0.3), Size = UDim2.fromScale(0.42, 0.32), BackgroundColor3 = Color3.new(1, 1, 1) })
	round(shine)
	local cheek = frame(pet, { Position = UDim2.fromScale(x + (x - 0.5) * 0.55, 0.6), Size = UDim2.fromScale(0.14, 0.08), BackgroundColor3 = Color3.fromRGB(255, 130, 160) })
	round(cheek)
end
local mouth = frame(pet, { Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.14, 0.05), BackgroundColor3 = INK })
round(mouth)

-- Ei (vor dem Haustier, Unterhaelfte bleibt nach dem Aufspringen stehen)
local egg = frame(stage, { Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.66, 0.84), BackgroundColor3 = Color3.fromRGB(255, 205, 60), ZIndex = 3 })
round(egg)
outline(egg, 4)
for _, spot in { { 0.3, 0.3, 0.16 }, { 0.68, 0.48, 0.2 }, { 0.38, 0.75, 0.13 } } do
	local dot = frame(egg, { Position = UDim2.fromScale(spot[1], spot[2]), Size = UDim2.fromScale(spot[3], spot[3] * 0.8), BackgroundColor3 = Color3.fromRGB(255, 236, 150), ZIndex = 3 })
	round(dot)
end
local crack = frame(egg, { Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.0, 0.035), BackgroundColor3 = INK, ZIndex = 4 })
local eggBottom = frame(stage, { Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.66, 0.42), BackgroundColor3 = Color3.fromRGB(255, 205, 60), ZIndex = 3, Visible = false })
round(eggBottom, UDim.new(0.45, 0))
outline(eggBottom, 4)

local tip = text({ Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(0.8, 0.05), Text = TIPS[math.random(1, #TIPS)] })
local barBack = frame(background, { Position = UDim2.fromScale(0.5, 0.85), Size = UDim2.fromScale(0.46, 0.028), BackgroundColor3 = INK })
round(barBack)
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BorderSizePixel = 0
bar.BackgroundColor3 = Color3.fromRGB(255, 220, 70)
bar.Parent = barBack
round(bar)
local status = text({ Position = UDim2.fromScale(0.5, 0.91), Size = UDim2.fromScale(0.5, 0.035), Text = "Warming up the eggs..." })

gui.Parent = playerGui

-- Animation in Schleife: wackeln -> aufspringen -> Haustier huepft -> neues Ei
local start = os.clock()
local animation = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	rays.Rotation = t * 8
	title.Rotation = math.sin(t * 2) * 2
	local cycle = t % 4
	local index = (math.floor(t / 4) % #PET_COLORS) + 1
	if cycle < 1.8 then
		-- Wackeln, immer staerker; Riss waechst
		egg.Visible = true
		eggBottom.Visible = false
		pet.Visible = false
		egg.Rotation = math.sin(cycle * 22) * cycle * 5
		crack.Size = UDim2.fromScale(math.clamp((cycle - 0.6) / 1.2, 0, 1) * 0.9, 0.035)
	else
		-- Aufgesprungen: Haustier huepft heraus und wechselt die Farbe
		egg.Visible = false
		eggBottom.Visible = true
		pet.Visible = true
		local color = PET_COLORS[index]
		pet.BackgroundColor3 = color
		for _, ear in ears do
			ear.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.15)
		end
		local hop = math.abs(math.sin((cycle - 1.8) * 5))
		pet.Position = UDim2.fromScale(0.5, 0.5 - hop * 0.16)
		pet.Rotation = math.sin((cycle - 1.8) * 5) * 6
	end
end)
task.spawn(function()
	while gui.Parent do
		task.wait(3.5)
		tip.Text = TIPS[math.random(1, #TIPS)]
	end
end)

-- Fortschritt: Spiel geladen, Welt gebaut und Warteschlange leer (mindestens 3 s, hoechstens 15 s)
local initialQueue = math.max(ContentProvider.RequestQueueSize, 1)
while os.clock() - start < 15 do
	local loaded = game:IsLoaded()
	local world = workspace:FindFirstChild("World") ~= nil
	local queue = ContentProvider.RequestQueueSize
	local progress = math.clamp(1 - queue / initialQueue, 0, 1) * 0.6 + (if loaded then 0.2 else 0) + (if world then 0.2 else 0)
	bar.Size = UDim2.fromScale(math.max(bar.Size.X.Scale, progress), 1)
	if loaded and world and queue == 0 and os.clock() - start > 3 then
		break
	end
	task.wait(0.1)
end
bar.Size = UDim2.fromScale(1, 1)
status.Text = "Ready! Let's hatch some pets!"
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
