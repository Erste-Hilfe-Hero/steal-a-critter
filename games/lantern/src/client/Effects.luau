-- Alle sichtbaren Effekte (nur auf dem Client): Treffer, Zauber, Warnkreise, Schadenszahlen,
-- Beute-Lichtsaeulen, Monster-Lebensbalken, Begleiter-Licht und die animierte Deko.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Camera = require(script.Parent.Camera)

local Effects = {}

local player = Players.LocalPlayer
local folder: Folder
local rng = Random.new()

local SOUNDS = {
	Slash = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Loot = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Boom = "rbxasset://sounds/collide.wav",
	Level = "rbxasset://sounds/unsheath.wav",
}

function Effects.Sound(name: string, volume: number?, pitch: number?)
	local id = SOUNDS[name]
	-- Einstellung "Sound effects"
	if not id or player:GetAttribute("Set_Sound") == false then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.Parent = workspace
	sound:Play()
	Debris:AddItem(sound, 3)
end

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

local function tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function disc(position: Vector3, radius: number, color: Color3, transparency: number): Part
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency,
	})
end

-- Wachsender Kreis am Boden, der sich bis zum Einschlag fuellt
local function ring(position: Vector3, radius: number, color: Color3, seconds: number)
	local p = disc(position, 0.5, color, 0.2)
	tween(p, seconds, { Size = Vector3.new(0.2, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(p, seconds + 0.1)
end
Effects.Ring = ring

local function burst(position: Vector3, color: Color3, count: number, size: number, spread: number)
	for _ = 1, count do
		local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Position = position, Color = color })
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.2, 1), rng:NextNumber(-1, 1)).Unit
		tween(p, 0.5, { Position = position + dir * spread, Size = Vector3.one * 0.1, Transparency = 1 })
		Debris:AddItem(p, 0.55)
	end
end
Effects.Burst = burst

local function projectile(from: Vector3, to: Vector3, color: Color3, size: number, seconds: number, shape: string?)
	local p
	if shape == "Arrow" then
		p = part({ Size = Vector3.new(0.25, 0.25, 2.6), CFrame = CFrame.lookAt(from, to), Color = color })
	else
		p = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, Position = from, Color = color })
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 10
		l.Brightness = 2
		l.Parent = p
	end
	tween(p, seconds, { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }, Enum.EasingStyle.Linear)
	Debris:AddItem(p, seconds + 0.05)
end

-- Schwebende Zahl ueber einem Punkt
local function number(position: Vector3, text: string, color: Color3, big: boolean?)
	-- Einstellung "Damage numbers" (Stufenaufstieg wird immer gezeigt)
	if not big and player:GetAttribute("Set_Numbers") == false then
		return
	end
	local anchor = part({ Size = Vector3.one * 0.2, Position = position + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), Transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(if big then 140 else 100, if big then 50 else 34)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(16, 14, 30)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	tween(anchor, 0.9, { Position = anchor.Position + Vector3.new(0, 4, 0) })
	task.delay(0.45, function()
		tween(label, 0.45, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 1)
end
Effects.Number = number

local function flash(model: Instance?, color: Color3, seconds: number)
	if not model or not model.Parent then
		return
	end
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.FillTransparency = 0.35
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	tween(h, seconds, { FillTransparency = 1 })
	Debris:AddItem(h, seconds + 0.05)
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function follow(character: Instance?, p: BasePart, seconds: number, spin: number?)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not p.Parent or os.clock() - start > seconds then
			conn:Disconnect()
			if p.Parent then
				tween(p, 0.2, { Transparency = 1 })
				Debris:AddItem(p, 0.25)
			end
			return
		end
		local angle = (os.clock() - start) * (spin or 0)
		p.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, angle, 0) * CFrame.Angles(0, 0, math.rad(90))
	end)
end

---------------------------------------------------------------- Effekt-Arten

local Handlers = {}

function Handlers.Spawn(data)
	ring(data.Position, if data.Boss then 14 else 4, data.Color, 0.6)
	burst(data.Position + Vector3.new(0, 1, 0), data.Color, if data.Boss then 16 else 6, 0.6, if data.Boss then 10 else 4)
end

function Handlers.Hit(data)
	local mine = data.By == player.UserId
	flash(data.Model, Color3.new(1, 1, 1), 0.15)
	if mine or data.Crit then
		number(data.Position + Vector3.new(0, 2, 0), Format.Number(data.Amount) .. (if data.Crit then "!" else ""), if data.Crit then Color3.fromRGB(255, 210, 60) elseif mine then Color3.new(1, 1, 1) else Color3.fromRGB(190, 190, 210), data.Crit)
	end
end

function Handlers.Death(data)
	burst(data.Position, data.Color, if data.Boss then 30 else 10, 0.8 * data.Size, if data.Boss then 16 else 6)
	burst(data.Position, Color3.fromRGB(255, 230, 140), 6, 0.4, 5)
	ring(data.Position - Vector3.new(0, 2, 0), 6 * data.Size, data.Color, 0.5)
	if data.Boss then
		Camera.Shake(1.6)
		Effects.Sound("Boom", 0.8, 0.6)
	end
end

function Handlers.Telegraph(data)
	local outline = disc(data.Position, data.Radius, data.Color, 0.7)
	local fill = disc(data.Position + Vector3.new(0, 0.02, 0), 0.4, data.Color, 0.35)
	tween(fill, data.Duration, { Size = Vector3.new(0.22, data.Radius * 2, data.Radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(outline, data.Duration + 0.05)
	Debris:AddItem(fill, data.Duration + 0.05)
end

function Handlers.Impact(data)
	ring(data.Position, data.Radius * 1.1, data.Color, 0.35)
	burst(data.Position + Vector3.new(0, 1, 0), data.Color, 8, 0.7, data.Radius * 0.6)
	local root = myRoot()
	if root and (root.Position - data.Position).Magnitude < data.Radius + 4 then
		Camera.Shake(0.5)
	end
end

function Handlers.Windup(data)
	flash(data.Model, Color3.fromRGB(255, 70, 50), data.Duration)
end

function Handlers.Swipe(data)
	local mid = (data.From + data.To) / 2
	local p = part({ Size = Vector3.new(3, 0.2, 0.6), CFrame = CFrame.lookAt(mid, data.To) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 120, 90), Transparency = 0.2 })
	tween(p, 0.25, { Transparency = 1, Size = Vector3.new(5, 0.2, 0.6) })
	Debris:AddItem(p, 0.3)
end

function Handlers.Lob(data)
	local from, to = data.From, data.To
	local p = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Position = from, Color = data.Color })
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.min(1, (os.clock() - start) / data.Duration)
		local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * 10, 0)
		p.Position = pos
		if t >= 1 then
			conn:Disconnect()
			p:Destroy()
		end
	end)
end

function Handlers.Roar(data)
	flash(data.Model, Color3.fromRGB(255, 200, 80), 0.6)
	Camera.Shake(0.8)
end

function Handlers.GateOpen(data)
	burst(data.Position, data.Color, 14, 0.7, 8)
	Effects.Sound("Level", 0.4, 1.3)
end

function Handlers.Gold(data)
	local root = myRoot()
	for i = 1, math.clamp(math.floor(math.log10(data.Amount + 1) * 2), 1, 6) do
		local coin = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.9, 0.9), Position = data.Position + Vector3.new(rng:NextNumber(-2, 2), 1, rng:NextNumber(-2, 2)), Color = Color3.fromRGB(255, 205, 60) })
		task.delay(0.25 + i * 0.05, function()
			local target = root and root.Position or data.Position
			tween(coin, 0.35, { Position = target, Size = Vector3.new(0.1, 0.3, 0.3) }, Enum.EasingStyle.Quad)
			Debris:AddItem(coin, 0.4)
		end)
	end
end

-- Lichtsaeule in der Farbe der Seltenheit, danach fliegt der Gegenstand zum Spieler
function Handlers.Loot(data)
	local rarity = Config.Rarities[data.Rarity]
	local height = 6 + data.Rarity * 5
	local position = data.Position + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
	local beam = part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 0.6 + data.Rarity * 0.15, 0.6 + data.Rarity * 0.15),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = rarity.Color,
		Transparency = 0.35,
	})
	local gem = part({ Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = rarity.Color })
	if data.Rarity >= 3 then
		local l = Instance.new("PointLight")
		l.Color = rarity.Color
		l.Range = 8 + data.Rarity * 3
		l.Brightness = 2
		l.Parent = gem
	end
	if data.Rarity >= 5 then
		ring(position, 10, rarity.Color, 0.8)
		Camera.Shake(0.4)
		Effects.Sound("Loot", 0.8, 0.7)
	elseif data.Rarity >= 3 then
		Effects.Sound("Loot", 0.5, 1)
	end
	local hold = 0.9 + data.Rarity * 0.15
	task.delay(hold, function()
		tween(beam, 0.4, { Transparency = 1 })
		Debris:AddItem(beam, 0.45)
		local root = myRoot()
		tween(gem, 0.35, { CFrame = CFrame.new(root and root.Position or position), Size = Vector3.one * 0.2 })
		Debris:AddItem(gem, 0.4)
	end)
end

function Handlers.LevelUp(data)
	local character = data.Player and data.Player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		ring(root.Position - Vector3.new(0, 2.6, 0), 12, Color3.fromRGB(255, 210, 90), 0.8)
		burst(root.Position, Color3.fromRGB(255, 230, 140), 18, 0.5, 7)
		number(root.Position + Vector3.new(0, 4, 0), "LEVEL " .. data.Level, Color3.fromRGB(255, 210, 90), true)
	end
	if data.Player == player then
		Effects.Sound("Level", 0.7, 1)
	end
end

function Handlers.Hurt(data)
	local root = myRoot()
	if root then
		number(root.Position + Vector3.new(0, 3, 0), "-" .. Format.Number(data.Amount), Color3.fromRGB(255, 90, 90))
		flash(player.Character, Color3.fromRGB(255, 60, 60), 0.2)
	end
end

function Handlers.Heal(data)
	number(data.Position + Vector3.new(0, 3, 0), "+" .. Format.Number(data.Amount), Color3.fromRGB(110, 240, 140))
	ring(data.Position - Vector3.new(0, 2.6, 0), 4, Color3.fromRGB(110, 240, 140), 0.4)
end

function Handlers.Slash(data)
	local dir = (data.To - data.From) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then
		return
	end
	local center = data.From + dir.Unit * 4
	for i = -2, 2 do
		local cf = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(i * 22), 0) * CFrame.new(0, 0, -2)
		local p = part({ Size = Vector3.new(0.3, 0.3, 3), CFrame = cf, Color = data.Color, Transparency = 0.1 })
		tween(p, 0.22, { Transparency = 1, Size = Vector3.new(0.1, 0.1, 4.5) })
		Debris:AddItem(p, 0.25)
	end
	Effects.Sound("Slash", 0.25, rng:NextNumber(0.9, 1.15))
end

function Handlers.Arrow(data)
	projectile(data.From + Vector3.new(0, 1, 0), data.To + Vector3.new(0, 1, 0), data.Color, 0.3, math.clamp((data.To - data.From).Magnitude / 120, 0.08, 0.4), "Arrow")
end

function Handlers.Bolt(data)
	projectile(data.From + Vector3.new(0, 1.5, 0), data.To + Vector3.new(0, 1, 0), data.Color, 1, math.clamp((data.To - data.From).Magnitude / 90, 0.1, 0.45))
	task.delay(math.clamp((data.To - data.From).Magnitude / 90, 0.1, 0.45), burst, data.To, data.Color, 5, 0.4, 3)
end

function Handlers.SpriteBolt(data)
	projectile(data.From, data.To, Color3.fromRGB(255, 230, 140), 0.5, 0.25)
end

function Handlers.Zap(data)
	local mid = (data.From + data.To) / 2
	local length = (data.To - data.From).Magnitude
	local p = part({ Size = Vector3.new(0.25, 0.25, length), CFrame = CFrame.lookAt(mid, data.To), Color = Color3.fromRGB(140, 210, 255) })
	tween(p, 0.2, { Transparency = 1 })
	Debris:AddItem(p, 0.25)
end

function Handlers.Nova(data)
	local p = disc(data.Position - Vector3.new(0, 2.6, 0), 1, data.Color, 0.15)
	tween(p, 0.35, { Size = Vector3.new(0.2, data.Radius * 2, data.Radius * 2), Transparency = 1 })
	Debris:AddItem(p, 0.4)
	burst(data.Position, if data.Frost then Color3.fromRGB(180, 240, 255) else data.Color, 14, 0.6, data.Radius * 0.8)
	Effects.Sound("Lunge", 0.4, 0.8)
end

function Handlers.Spin(data)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, data.Radius * 2, data.Radius * 2), Color = data.Color, Transparency = 0.6 })
	follow(data.Character, p, data.Duration, 12)
	Effects.Sound("Lunge", 0.4, 1.2)
end

function Handlers.Aura(data)
	local p = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, data.Radius * 2, data.Radius * 2), Color = data.Color, Transparency = 0.55 })
	follow(data.Character, p, data.Duration, 1)
end

function Handlers.Meteor(data)
	local target = data.Position
	local rock = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 5, Position = target + Vector3.new(-14, 50, -14), Color = Color3.fromRGB(255, 120, 40) })
	local l = Instance.new("PointLight")
	l.Color = rock.Color
	l.Range = 30
	l.Brightness = 3
	l.Parent = rock
	Handlers.Telegraph({ Position = target, Radius = data.Radius, Duration = data.Delay, Color = Color3.fromRGB(255, 150, 60) })
	tween(rock, data.Delay, { Position = target }, Enum.EasingStyle.Quad)
	task.delay(data.Delay, function()
		rock:Destroy()
		ring(target, data.Radius * 1.2, Color3.fromRGB(255, 140, 50), 0.5)
		burst(target + Vector3.new(0, 1, 0), Color3.fromRGB(255, 170, 60), 20, 1, data.Radius)
		Camera.Shake(1)
		Effects.Sound("Boom", 0.7, 0.8)
	end)
end

function Handlers.Rain(data)
	local outline = disc(data.Position, data.Radius, Color3.fromRGB(255, 230, 140), 0.75)
	Debris:AddItem(outline, data.Duration)
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < data.Duration do
			for _ = 1, 4 do
				local a = rng:NextNumber(0, math.pi * 2)
				local r = math.sqrt(rng:NextNumber()) * data.Radius
				local spot = data.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
				projectile(spot + Vector3.new(-2, 24, -2), spot, Color3.fromRGB(255, 230, 140), 0.3, 0.25, "Arrow")
			end
			task.wait(0.12)
		end
	end)
end

function Handlers.ImpEscape(data)
	burst(data.Position, Color3.fromRGB(255, 205, 60), 16, 0.6, 8)
	ring(data.Position - Vector3.new(0, 2, 0), 6, Color3.fromRGB(180, 140, 255), 0.5)
end

function Handlers.Chest(data)
	burst(data.Position, Color3.fromRGB(255, 210, 80), 18, 0.5, 6)
	ring(data.Position - Vector3.new(0, 1.5, 0), 6, Color3.fromRGB(255, 210, 80), 0.5)
	Effects.Sound("Loot", 0.6, 1.2)
end

-- Gruppen-Signal als Sprechblase ueber dem Kopf
function Handlers.Ping(data)
	local character = data.Player and data.Player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild("PingBubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PingBubble"
	gui.Size = UDim2.fromOffset(120, 38)
	gui.StudsOffset = Vector3.new(0, 5.5, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(32, 38, 66)
	label.BackgroundTransparency = 0.1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 220, 120)
	label.Text = data.Text
	label.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 10)
	round.Parent = label
	gui.Parent = head
	Effects.Sound("Click", 0.5, 1.4)
	Debris:AddItem(gui, 2.5)
end

function Handlers.Enhance(data)
	ring(data.Position - Vector3.new(0, 2.6, 0), 8, Color3.fromRGB(255, 170, 60), 0.6)
	burst(data.Position, Color3.fromRGB(255, 200, 90), 16, 0.4, 6)
	Effects.Sound("Level", 0.6, 1.4)
end

---------------------------------------------------------------- Monster-Lebensbalken

local function monsterBar(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("Boss") then
		return
	end
	local root = model:WaitForChild("HumanoidRootPart", 5)
	if not root then
		return
	end
	local elite = model:GetAttribute("Elite") == true
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bar"
	gui.Size = UDim2.fromOffset(if elite then 130 else 90, if elite then 30 else 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, (tonumber(model:GetAttribute("Top")) or 4) - 0.5, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Adornee = root
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.BuilderSansBold
	name.TextScaled = true
	name.TextColor3 = if elite then Color3.fromRGB(255, 210, 90) else Color3.fromRGB(235, 235, 245)
	name.TextStrokeTransparency = 0.3
	name.Text = `{model:GetAttribute("DisplayName")}  Lv {model:GetAttribute("Level")}`
	name.Parent = gui
	local back = Instance.new("Frame")
	back.Position = UDim2.fromScale(0.05, 0.62)
	back.Size = UDim2.fromScale(0.9, 0.3)
	back.BackgroundColor3 = Color3.fromRGB(20, 18, 34)
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if elite then Color3.fromRGB(255, 180, 60) else Color3.fromRGB(235, 80, 80)
	fill.BorderSizePixel = 0
	fill.Parent = back
	corner:Clone().Parent = fill
	local function update()
		local hp = model:GetAttribute("Health") or 0
		local max = math.max(1, tonumber(model:GetAttribute("MaxHealth")) or 1)
		tween(fill, 0.15, { Size = UDim2.fromScale(math.clamp(hp / max, 0, 1), 1) })
	end
	model:GetAttributeChangedSignal("Health"):Connect(update)
	update()
	gui.Parent = model
end

---------------------------------------------------------------- Start

function Effects.Start()
	folder = Instance.new("Folder")
	folder.Name = "ClientEffects"
	folder.Parent = workspace

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Effect").OnClientEvent:Connect(function(kind, data)
		local handler = Handlers[kind]
		if handler then
			local ok, err = pcall(handler, data)
			if not ok then
				warn("[Effects]", kind, err)
			end
		end
	end)

	CollectionService:GetInstanceAddedSignal("Monster"):Connect(function(model)
		task.spawn(monsterBar, model)
	end)
	for _, model in CollectionService:GetTagged("Monster") do
		task.spawn(monsterBar, model)
	end

	-- Animierte Deko und Begleiter-Lichter
	local sprites = {} -- [Player] = Part
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, p in CollectionService:GetTagged("Spin") do
			if p:IsA("BasePart") then
				p.CFrame *= CFrame.Angles(0, dt * 1.2, 0)
			end
		end
		for _, p in CollectionService:GetTagged("Bob") do
			if p:IsA("BasePart") then
				local base = p:GetAttribute("BaseY")
				if not base then
					base = p.Position.Y
					p:SetAttribute("BaseY", base)
				end
				p.CFrame = CFrame.new(p.Position.X, base + math.sin(t * 2 + p.Position.X) * 0.5, p.Position.Z) * (p.CFrame - p.CFrame.Position) * CFrame.Angles(0, dt, 0)
			end
		end
		for _, other in Players:GetPlayers() do
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local sprite = sprites[other]
			if other:GetAttribute("Pass_Sprite") and root then
				if not sprite or not sprite.Parent then
					sprite = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Color = Color3.fromRGB(255, 230, 140), Position = root.Position })
					local l = Instance.new("PointLight")
					l.Color = sprite.Color
					l.Range = 12
					l.Brightness = 2
					l.Parent = sprite
					sprites[other] = sprite
				end
				local goal = root.Position + Vector3.new(math.cos(t * 1.5) * 2.5, 3 + math.sin(t * 3) * 0.4, math.sin(t * 1.5) * 2.5)
				sprite.Position = sprite.Position:Lerp(goal, math.min(1, dt * 8))
			elseif sprite then
				sprite:Destroy()
				sprites[other] = nil
			end
		end
	end)
	-- Flackernde Laternen (nur ein paar pro Bild, spart Leistung)
	task.spawn(function()
		while true do
			task.wait(0.12)
			local lamps = CollectionService:GetTagged("Flicker")
			for _ = 1, math.min(8, #lamps) do
				local lamp = lamps[rng:NextInteger(1, #lamps)]
				local l = lamp:FindFirstChildOfClass("PointLight")
				if l then
					local base = lamp:GetAttribute("BaseBrightness") or l.Brightness
					lamp:SetAttribute("BaseBrightness", base)
					l.Brightness = base * rng:NextNumber(0.8, 1.1)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(other)
		if sprites[other] then
			sprites[other]:Destroy()
			sprites[other] = nil
		end
	end)
end

return Effects
