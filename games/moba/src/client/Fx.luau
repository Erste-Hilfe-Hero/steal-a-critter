-- Alle sichtbaren Effekte laufen nur auf dem Client: Geschosse, Ringe, Explosionen, Schadenszahlen.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Fx = {}

local folder: Folder

local WHITE = Color3.new(1, 1, 1)
local NUMBER_FONT = Enum.Font.LuckiestGuy

local function container(): Folder
	if not folder or not folder.Parent then
		local created = Instance.new("Folder")
		created.Name = "ClientFx"
		created.Parent = workspace
		folder = created
	end
	return folder
end

local function part(props): BasePart
	local p = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		if key ~= "ClassName" and key ~= "Shape" then
			(p :: any)[key] = value
		end
	end
	if props.Shape then
		(p :: any).Shape = props.Shape
	end
	p.Parent = container()
	return p
end

local function tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local t = TweenService:Create(instance, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function ground(position: Vector3, y: number?): Vector3
	return Vector3.new(position.X, y or 0.4, position.Z)
end

local function flatRing(position: Vector3, radius: number, color: Color3, transparency: number?): BasePart
	return part({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, radius * 2, radius * 2),
		CFrame = CFrame.new(ground(position)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Transparency = transparency or 0.4,
	})
end

local function rootOf(model: Instance?): BasePart?
	if not model or not model.Parent then
		return nil
	end
	local m = model :: Model
	return (m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart) :: BasePart?
end

---------------------------------------------------------------- Schwebende Zahlen

function Fx.FloatText(position: Vector3, text: string, color: Color3, size: number?)
	local anchor = part({ Size = Vector3.one * 0.2, Transparency = 1, Position = position + Vector3.new(math.random(-10, 10) / 10, 4, math.random(-10, 10) / 10) })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 36 * (size or 1))
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 160
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = NUMBER_FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(20, 16, 30)
	stroke.Parent = label
	tween(anchor, 0.9, { Position = anchor.Position + Vector3.new(0, 4, 0) })
	task.delay(0.45, function()
		tween(label, 0.45, { TextTransparency = 1 })
		tween(stroke, 0.45, { Transparency = 1 })
	end)
	Debris:AddItem(anchor, 1)
end

function Fx.Number(position: Vector3, amount: number, kind: string)
	local value = math.floor(amount + 0.5)
	if value <= 0 then
		return
	end
	if kind == "Gold" then
		Fx.FloatText(position, "+" .. value .. "g", Color3.fromRGB(255, 210, 70), 0.9)
	elseif kind == "Heal" then
		Fx.FloatText(position, "+" .. value, Color3.fromRGB(110, 231, 160), 0.9)
	elseif kind == "Taken" then
		Fx.FloatText(position, "-" .. value, Color3.fromRGB(255, 90, 90), 0.9)
	elseif kind == "Crit" then
		Fx.FloatText(position, value .. "!", Color3.fromRGB(255, 120, 40), 1.25)
	elseif kind == "Magic" then
		Fx.FloatText(position, tostring(value), Color3.fromRGB(150, 150, 255), 1)
	elseif kind == "True" then
		Fx.FloatText(position, tostring(value), Color3.fromRGB(240, 240, 240), 1)
	elseif kind == "Ability" then
		Fx.FloatText(position, tostring(value), Color3.fromRGB(255, 170, 60), 1.15)
	else
		Fx.FloatText(position, tostring(value), WHITE, 0.85)
	end
end

---------------------------------------------------------------- Effekte vom Server

local handlers: { [string]: (any) -> () } = {}

handlers.Shot = function(data)
	local from: Vector3 = data.From
	local root = rootOf(data.Target)
	local to: Vector3 = if root then root.Position else (data.To + Vector3.new(0, 2, 0))
	local orb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 0.9, Position = from, Color = data.Color or WHITE })
	local trail = part({ Size = Vector3.new(0.25, 0.25, 2), CFrame = CFrame.lookAt(from, to), Color = data.Color or WHITE, Transparency = 0.4 })
	tween(orb, data.Time or 0.2, { Position = to }, Enum.EasingStyle.Linear)
	tween(trail, data.Time or 0.2, { CFrame = CFrame.lookAt(to, to + (to - from).Unit) }, Enum.EasingStyle.Linear)
	Debris:AddItem(orb, (data.Time or 0.2) + 0.05)
	Debris:AddItem(trail, (data.Time or 0.2) + 0.05)
end

handlers.Beam = function(data)
	local from: Vector3 = data.From
	local root = rootOf(data.Target)
	local to: Vector3 = if root then root.Position else (data.To + Vector3.new(0, 2, 0))
	local length = (to - from).Magnitude
	local beam = part({ Size = Vector3.new(0.6, 0.6, length), CFrame = CFrame.lookAt((from + to) / 2, to), Color = data.Color or WHITE, Transparency = 0.1 })
	tween(beam, 0.25, { Transparency = 1, Size = Vector3.new(0.1, 0.1, length) })
	Debris:AddItem(beam, 0.3)
	local spark = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2.5, Position = to, Color = data.Color or WHITE, Transparency = 0.2 })
	tween(spark, 0.25, { Size = Vector3.one * 0.2, Transparency = 1 })
	Debris:AddItem(spark, 0.3)
end

handlers.Slash = function(data)
	local at = ground(data.At, 2)
	local size = if data.Big then 3.4 else 2
	local slash = part({ Size = Vector3.new(size, 0.2, 0.5), CFrame = CFrame.new(at) * CFrame.Angles(math.random() * 3, math.random() * 6, math.random() * 3), Color = data.Color or WHITE, Transparency = 0.15 })
	tween(slash, 0.18, { Size = Vector3.new(size * 1.8, 0.05, 0.2), Transparency = 1 })
	Debris:AddItem(slash, 0.2)
end

handlers.BigSlash = function(data)
	for i = 1, 3 do
		task.delay((i - 1) * 0.06, function()
			handlers.Slash({ At = data.At, Color = data.Color, Big = true })
		end)
	end
	handlers.Boom({ At = data.At, Color = data.Color, Size = 6 })
end

handlers.Ring = function(data)
	local ring = flatRing(data.At, 1, data.Color or WHITE, 0.2)
	tween(ring, 0.35, { Size = Vector3.new(0.2, data.Radius * 2, data.Radius * 2), Transparency = 1 })
	Debris:AddItem(ring, 0.4)
	local inner = flatRing(data.At, data.Radius, data.Color or WHITE, 0.75)
	tween(inner, 0.5, { Transparency = 1 })
	Debris:AddItem(inner, 0.55)
end

handlers.Marker = function(data)
	local ring = flatRing(data.At, data.Radius, data.Color or WHITE, 0.6)
	local fill = flatRing(data.At, 0.5, data.Color or WHITE, 0.4)
	tween(fill, data.Time or 0.8, { Size = Vector3.new(0.25, data.Radius * 2, data.Radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(ring, data.Time or 0.8)
	Debris:AddItem(fill, data.Time or 0.8)
	-- Fallender Stern / Meteor
	local orb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Position = ground(data.At, 60), Color = data.Color or WHITE })
	tween(orb, data.Time or 0.8, { Position = ground(data.At, 1) }, Enum.EasingStyle.Quad)
	Debris:AddItem(orb, data.Time or 0.8)
end

handlers.Boom = function(data)
	local size = data.Size or 10
	local ball = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1, Position = ground(data.At, 1.5), Color = data.Color or WHITE, Transparency = 0.1 })
	tween(ball, 0.35, { Size = Vector3.one * size, Transparency = 1 })
	Debris:AddItem(ball, 0.4)
	handlers.Ring({ At = data.At, Radius = size * 0.6, Color = data.Color })
end

handlers.Line = function(data)
	local from = ground(data.From, 2)
	local to = ground(data.To, 2)
	local length = (to - from).Magnitude
	local bolt = part({ Size = Vector3.new(data.Width, 0.6, 2), CFrame = CFrame.lookAt(from, to), Color = data.Color or WHITE, Transparency = 0.1 })
	tween(bolt, 0.28, { CFrame = CFrame.lookAt(to, to + (to - from).Unit), Size = Vector3.new(data.Width, 0.6, 4) }, Enum.EasingStyle.Linear)
	Debris:AddItem(bolt, 0.3)
	local path = part({ Size = Vector3.new(data.Width, 0.15, length), CFrame = CFrame.lookAt((from + to) / 2 - Vector3.new(0, 1.6, 0), to - Vector3.new(0, 1.6, 0)), Color = data.Color or WHITE, Transparency = 0.6 })
	tween(path, 0.4, { Transparency = 1 })
	Debris:AddItem(path, 0.45)
end

handlers.Dash = function(data)
	local from = ground(data.From, 2.5)
	local to = ground(data.To, 2.5)
	local length = (to - from).Magnitude
	local streak = part({ Size = Vector3.new(1.6, 1.6, math.max(1, length)), CFrame = CFrame.lookAt((from + to) / 2, to), Color = data.Color or WHITE, Transparency = 0.3 })
	tween(streak, 0.3, { Size = Vector3.new(0.1, 0.1, math.max(1, length)), Transparency = 1 })
	Debris:AddItem(streak, 0.35)
end

handlers.Chain = function(data)
	local points = data.Points
	for i = 1, #points - 1 do
		local a = ground(points[i], 2.5)
		local b = ground(points[i + 1], 2.5)
		task.delay((i - 1) * 0.05, function()
			local mid = (a + b) / 2 + Vector3.new(math.random(-10, 10) / 10, math.random(-5, 10) / 10, math.random(-10, 10) / 10)
			for _, pair in { { a, mid }, { mid, b } } do
				local length = (pair[2] - pair[1]).Magnitude
				local bolt = part({ Size = Vector3.new(0.35, 0.35, length), CFrame = CFrame.lookAt((pair[1] + pair[2]) / 2, pair[2]), Color = data.Color or WHITE })
				tween(bolt, 0.25, { Transparency = 1 })
				Debris:AddItem(bolt, 0.3)
			end
		end)
	end
end

handlers.Heal = function(data)
	handlers.Ring({ At = data.At, Radius = data.Radius, Color = Color3.fromRGB(110, 231, 160) })
	for _ = 1, 8 do
		local offset = Vector3.new(math.random(-data.Radius, data.Radius) * 0.5, 0, math.random(-data.Radius, data.Radius) * 0.5)
		local plus = part({ Size = Vector3.new(0.5, 1.4, 0.5), Position = ground(data.At + offset, 1), Color = Color3.fromRGB(110, 231, 160) })
		tween(plus, 0.8, { Position = plus.Position + Vector3.new(0, 5, 0), Transparency = 1 })
		Debris:AddItem(plus, 0.85)
	end
end

local function aura(model: Instance?, seconds: number, color: Color3, size: number, transparency: number, material: Enum.Material?)
	local root = rootOf(model)
	if not root then
		return
	end
	local bubble = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = root.CFrame, Color = color, Transparency = transparency, Material = material or Enum.Material.ForceField, Anchored = false, Massless = true })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = bubble
	weld.Parent = bubble
	Debris:AddItem(bubble, seconds)
end

handlers.Shield = function(data)
	aura(data.Model, math.min(data.Time or 3, 3), Color3.fromRGB(200, 230, 255), 7, 0)
end

handlers.Buff = function(data)
	aura(data.Model, data.Time or 3, data.Color or WHITE, 6, 0.1)
end

handlers.Stun = function(data)
	local root = rootOf(data.Model)
	if not root then
		return
	end
	local stars = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3, 3), CFrame = root.CFrame * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 230, 90), Transparency = 0.3, Anchored = false, Massless = true })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = stars
	weld.Parent = stars
	Debris:AddItem(stars, data.Time or 1)
end

handlers.Zone = function(data)
	local ring = flatRing(data.At, data.Radius, data.Color or WHITE, 0.5)
	Debris:AddItem(ring, data.Time or 3)
	local swirl = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(8, data.Radius * 1.6, data.Radius * 1.6), CFrame = CFrame.new(ground(data.At, 4)) * CFrame.Angles(0, 0, math.rad(90)), Color = data.Color or WHITE, Transparency = 0.75, Material = Enum.Material.ForceField })
	Debris:AddItem(swirl, data.Time or 3)
	local start = os.clock()
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if not swirl.Parent then
			connection:Disconnect()
			return
		end
		swirl.CFrame = CFrame.new(ground(data.At, 4)) * CFrame.Angles(0, (os.clock() - start) * 4, math.rad(90))
	end)
end

local recalls = {}
handlers.Recall = function(data)
	local root = rootOf(data.Model)
	if not root then
		return
	end
	local column = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 4, 4), CFrame = root.CFrame * CFrame.Angles(0, 0, math.rad(90)), Color = data.Color or WHITE, Transparency = 0.6, Material = Enum.Material.ForceField, Anchored = false, Massless = true })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = column
	weld.Parent = column
	recalls[data.Model] = column
	Debris:AddItem(column, data.Time or 4)
end

handlers.RecallCancel = function(data)
	local column = recalls[data.Model]
	if column then
		column:Destroy()
		recalls[data.Model] = nil
	end
end

handlers.LevelUp = function(data)
	local root = rootOf(data.Model)
	if not root then
		return
	end
	handlers.Ring({ At = root.Position, Radius = 6, Color = Color3.fromRGB(255, 220, 90) })
	Fx.FloatText(root.Position + Vector3.new(0, 2, 0), "LEVEL " .. tostring(data.Level), Color3.fromRGB(255, 220, 90), 1.1)
end

handlers.Poof = function(data)
	for _ = 1, 6 do
		local bit = part({ Size = Vector3.one * 0.8, Position = ground(data.At, 1.5), Color = data.Color or WHITE })
		tween(bit, 0.5, { Position = bit.Position + Vector3.new(math.random(-4, 4), math.random(2, 5), math.random(-4, 4)), Transparency = 1, Size = Vector3.one * 0.1 })
		Debris:AddItem(bit, 0.55)
	end
end

-- Kleine Ausholbewegung der Waffe
handlers.Swing = function(data)
	local model = data.Model
	if not model or not model.Parent then
		return
	end
	local gear = model:FindFirstChild("HeroGear")
	local hand = model:FindFirstChild("RightHand") :: BasePart?
	if gear and hand then
		local glow = gear:FindFirstChildWhichIsA("BasePart")
		if glow then
			local original = glow.Transparency
			glow.Transparency = 0.6
			task.delay(0.08, function()
				if glow.Parent then
					glow.Transparency = original
				end
			end)
		end
	end
end

handlers.Cast = function(data)
	local root = rootOf(data.Model)
	if root then
		local flash = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 3, Position = root.Position, Color = WHITE, Transparency = 0.5 })
		tween(flash, 0.2, { Size = Vector3.one * 6, Transparency = 1 })
		Debris:AddItem(flash, 0.25)
	end
end

---------------------------------------------------------------- Geschosse, Strahlen, Zustaende

local missiles = {}

-- Fliegendes Geschoss (Faehigkeit): fliegt die ganze Strecke, ausser der Server meldet einen Treffer
handlers.Missile = function(data)
	local from = ground(data.From, 2.2)
	local direction: Vector3 = data.Dir
	local length: number = data.Length
	local speed: number = data.Speed or 0
	if speed <= 0 or data.Look == "None" then
		return
	end
	local color = data.Color or WHITE
	local width = math.max(1, data.Width or 2)
	local look = data.Look
	local head = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * math.min(5, width * 1.1), Position = from, Color = color, Transparency = 0.05 })
	local tail = part({ Size = Vector3.new(width * 0.5, width * 0.5, 3), CFrame = CFrame.lookAt(from, from + direction), Color = color, Transparency = 0.45 })
	local chain
	if look == "Hook" then
		chain = part({ Size = Vector3.new(0.3, 0.3, 0.1), CFrame = CFrame.lookAt(from, from + direction), Color = Color3.fromRGB(70, 80, 80), Material = Enum.Material.Metal, Transparency = 0 })
	end
	local start = os.clock()
	local duration = length / speed
	missiles[data.Id] = { Head = head, Tail = tail, Chain = chain }
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local elapsed = os.clock() - start
		if not head.Parent or elapsed >= duration then
			connection:Disconnect()
			head:Destroy()
			tail:Destroy()
			if chain then
				chain:Destroy()
			end
			missiles[data.Id] = nil
			return
		end
		local position = from + direction * (speed * elapsed)
		head.Position = position
		tail.CFrame = CFrame.lookAt(position - direction * 1.5, position)
		if chain then
			local distance = (position - from).Magnitude
			chain.Size = Vector3.new(0.3, 0.3, math.max(0.1, distance))
			chain.CFrame = CFrame.lookAt((from + position) / 2, position)
		end
	end)
end

handlers.MissileEnd = function(data)
	local missile = missiles[data.Id]
	if missile then
		missile.Head:Destroy()
		missile.Tail:Destroy()
		if missile.Chain then
			missile.Chain:Destroy()
		end
		missiles[data.Id] = nil
	end
	handlers.Boom({ At = data.At, Color = data.Color, Size = 5 })
end

-- Vorwarnung am Boden (gleich kommt etwas)
handlers.Telegraph = function(data)
	local from = ground(data.From, 0.35)
	local to = ground(data.To, 0.35)
	local length = (to - from).Magnitude
	local strip = part({ Size = Vector3.new(data.Width or 3, 0.15, length), CFrame = CFrame.lookAt((from + to) / 2, to), Color = data.Color or WHITE, Transparency = 0.7 })
	tween(strip, data.Time or 0.5, { Transparency = 0.35 }, Enum.EasingStyle.Linear)
	Debris:AddItem(strip, data.Time or 0.5)
end

handlers.Laser = function(data)
	local from = ground(data.From, 2.5)
	local to = ground(data.To, 2.5)
	local length = (to - from).Magnitude
	local width = data.Width or 4
	local beam = part({ Size = Vector3.new(width, width * 0.6, length), CFrame = CFrame.lookAt((from + to) / 2, to), Color = data.Color or WHITE, Transparency = 0.05 })
	local core = part({ Size = Vector3.new(width * 0.4, width * 0.3, length), CFrame = beam.CFrame, Color = WHITE, Transparency = 0 })
	tween(beam, 0.5, { Size = Vector3.new(0.2, 0.2, length), Transparency = 1 })
	tween(core, 0.4, { Size = Vector3.new(0.1, 0.1, length), Transparency = 1 })
	Debris:AddItem(beam, 0.55)
	Debris:AddItem(core, 0.45)
end

handlers.Bolt = function(data)
	handlers.Shot({ From = ground(data.From, 2.5), To = data.To, Color = data.Color, Time = math.clamp((data.To - data.From).Magnitude / 120, 0.08, 0.3) })
end

handlers.Hook = function(data)
	local from = ground(data.From, 2.4)
	local to = ground(data.To, 2.4)
	local length = (to - from).Magnitude
	local chain = part({ Size = Vector3.new(0.35, 0.35, length), CFrame = CFrame.lookAt((from + to) / 2, to), Color = data.Color or Color3.fromRGB(80, 90, 90), Transparency = 0.1 })
	tween(chain, 0.35, { Size = Vector3.new(0.35, 0.35, 0.1), CFrame = CFrame.new(from), Transparency = 0.6 })
	Debris:AddItem(chain, 0.4)
end

handlers.Flash = function(data)
	for _, point in { data.From, data.To } do
		local burst = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 2, Position = ground(point, 2.5), Color = data.Color or Color3.fromRGB(255, 240, 150), Transparency = 0.1 })
		tween(burst, 0.3, { Size = Vector3.one * 7, Transparency = 1 })
		Debris:AddItem(burst, 0.35)
	end
end

handlers.Airborne = function(data)
	local root = rootOf(data.Model)
	if root then
		handlers.Ring({ At = root.Position, Radius = 3, Color = Color3.fromRGB(255, 230, 90) })
	end
end

handlers.Root = function(data)
	local root = rootOf(data.Model)
	if not root then
		return
	end
	local ring = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 4, 4), CFrame = CFrame.new(ground(root.Position, 0.6)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 250, 190), Transparency = 0.35, Material = Enum.Material.ForceField })
	Debris:AddItem(ring, data.Time or 1)
end

handlers.Stasis = function(data)
	aura(data.Model, data.Time or 2.5, Color3.fromRGB(255, 215, 90), 7, 0, Enum.Material.Glass)
end

handlers.Stealth = function(data)
	handlers.Poof({ At = (rootOf(data.Model) or { Position = Vector3.zero } :: any).Position, Color = Color3.fromRGB(150, 80, 220) })
end

handlers.Burn = function(data)
	aura(data.Model, data.Time or 3, Color3.fromRGB(255, 110, 40), 5, 0.6, Enum.Material.Neon)
end

handlers.Exhaust = function(data)
	aura(data.Model, data.Time or 3, Color3.fromRGB(120, 110, 90), 6, 0.5, Enum.Material.ForceField)
end

handlers.Mark = function(data)
	local root = rootOf(data.Model)
	if not root then
		return
	end
	local mark = part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 3.5, 3.5), CFrame = root.CFrame * CFrame.new(0, 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = data.Color or WHITE, Transparency = 0.2, Anchored = false, Massless = true })
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = mark
	weld.Parent = mark
	Debris:AddItem(mark, data.Time or 3)
end

handlers.Smite = function(data)
	local to = ground(data.To, 2)
	local bolt = part({ Size = Vector3.new(1.2, 40, 1.2), Position = to + Vector3.new(0, 20, 0), Color = Color3.fromRGB(255, 220, 120), Transparency = 0.05 })
	tween(bolt, 0.3, { Size = Vector3.new(0.1, 40, 0.1), Transparency = 1 })
	Debris:AddItem(bolt, 0.35)
	handlers.Boom({ At = data.To, Color = Color3.fromRGB(255, 220, 120), Size = 8 })
end

handlers.Soul = function(data)
	local root = rootOf(data.Model)
	if not root then
		return
	end
	local orb = part({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Position = ground(data.From, 2), Color = Color3.fromRGB(110, 255, 200) })
	tween(orb, 0.6, { Position = root.Position, Size = Vector3.one * 0.3 }, Enum.EasingStyle.Sine)
	Debris:AddItem(orb, 0.65)
end

handlers.Cone = function(data)
	local at = ground(data.At, 0.4)
	local direction: Vector3 = data.Dir
	local half = math.rad((data.Angle or 60) / 2)
	for i = -2, 2 do
		local angle = half * i / 2
		local rotated = CFrame.fromAxisAngle(Vector3.yAxis, angle):VectorToWorldSpace(direction)
		local to = at + rotated * data.Range
		local streak = part({ Size = Vector3.new(1, 0.2, data.Range), CFrame = CFrame.lookAt((at + to) / 2, to), Color = data.Color or WHITE, Transparency = 0.4 })
		tween(streak, 0.35, { Transparency = 1 })
		Debris:AddItem(streak, 0.4)
	end
end

handlers.RankUp = function(data)
	local root = rootOf(data.Model)
	if root then
		Fx.FloatText(root.Position + Vector3.new(0, 1, 0), tostring(data.Key) .. " +", Color3.fromRGB(140, 220, 255), 0.8)
	end
end

handlers.Plate = function(data)
	handlers.Boom({ At = data.At, Color = Color3.fromRGB(255, 210, 70), Size = 8 })
	Fx.FloatText(data.At + Vector3.new(0, 10, 0), "PLATE", Color3.fromRGB(255, 210, 70), 1)
end

function Fx.Handle(kind: string, data)
	local handler = handlers[kind]
	if handler then
		local ok, err = pcall(handler, data)
		if not ok then
			warn("[Fx]", kind, err)
		end
	end
end

---------------------------------------------------------------- Dauer-Animationen

function Fx.Start()
	local spinning = {}
	local function track(instance: Instance, list)
		if instance:IsA("BasePart") then
			list[instance] = { CFrame = instance.CFrame, Seed = math.random() * 10 }
		end
	end
	local floating = {}
	for _, instance in CollectionService:GetTagged("Spin") do
		track(instance, spinning)
	end
	for _, instance in CollectionService:GetTagged("Float") do
		track(instance, floating)
	end
	CollectionService:GetInstanceAddedSignal("Spin"):Connect(function(instance)
		track(instance, spinning)
	end)
	CollectionService:GetInstanceAddedSignal("Float"):Connect(function(instance)
		track(instance, floating)
	end)
	CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(instance)
		spinning[instance] = nil
	end)
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for instance, info in spinning do
			if instance.Parent then
				instance.CFrame = CFrame.new(info.CFrame.Position + Vector3.new(0, math.sin(t * 2 + info.Seed) * 0.5, 0)) * CFrame.Angles(0, t * 1.2 + info.Seed, 0) * info.CFrame.Rotation
			else
				spinning[instance] = nil
			end
		end
		for instance, info in floating do
			if instance.Parent then
				instance.CFrame = info.CFrame * CFrame.new(0, math.sin(t * 0.6 + info.Seed) * 3, 0)
			end
		end
	end)
end

return Fx
