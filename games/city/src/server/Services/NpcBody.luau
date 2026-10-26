-- Koerper fuer Computer-Gegner: R15-Avatar aus einer HumanoidDescription (Ersatz: Klotz-Figur),
-- Standard-Animationen von Roblox und ein Namensschild mit drei Zeilen.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local NpcBody = {}

-- Standard-Animationen (gehoeren Roblox, funktionieren in jedem Spiel)
local ANIMATIONS = {
	Idle = "rbxassetid://507766388",
	Walk = "rbxassetid://507777826",
	Run = "rbxassetid://507767714",
	Jump = "rbxassetid://507765000",
	Fall = "rbxassetid://507767968",
	Climb = "rbxassetid://507765644",
}

local SKIN = {
	Color3.fromRGB(255, 220, 180),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(160, 105, 75),
	Color3.fromRGB(105, 70, 50),
}

local tracks = {} -- [Model] = { [Name] = AnimationTrack }
local playing = {} -- [Model] = Name

local function blockBody(shirt: Color3, pants: Color3, skin: Color3): Model
	local model = Instance.new("Model")
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = offset
		p.Parent = model
		return p
	end
	local root = piece("HumanoidRootPart", Vector3.new(2, 2, 1), CFrame.new(), shirt)
	root.Transparency = 1
	local parts = {
		piece("UpperTorso", Vector3.new(2, 2, 1), CFrame.new(), shirt),
		piece("Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 1.6, 0), skin),
		piece("LeftUpperArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 0, 0), skin),
		piece("RightUpperArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 0, 0), skin),
		piece("LeftUpperLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, -2, 0), pants),
		piece("RightUpperLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, -2, 0), pants),
	}
	for _, p in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- Baut einen Gegner. Der HumanoidRootPart ist verankert, der Service bewegt ihn per CFrame
-- (ausser opts.Physics = true: dann laeuft er normal mit Humanoid:MoveTo).
function NpcBody.Build(name: string, opts: { Physics: boolean?, Hat: Color3?, Tag: string? }?): (Model, Humanoid, BasePart)
	local options = opts or {}
	local skin = SKIN[math.random(1, #SKIN)]
	local shirt = Color3.fromHSV(math.random(), 0.65, 0.95)
	local pants = Color3.fromHSV(math.random(), 0.5, 0.45)
	local model: Model? = nil
	local ok = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = skin
		description.LeftArmColor = skin
		description.RightArmColor = skin
		description.TorsoColor = shirt
		description.LeftLegColor = pants
		description.RightLegColor = pants
		model = Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		model = blockBody(shirt, pants, skin)
	end
	local body = model :: Model
	body.Name = name
	local humanoid = body:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = body:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	body.PrimaryPart = root
	for _, item in body:GetDescendants() do
		if item:IsA("BasePart") then
			-- Gegner beruehren nichts (keine Checkpoints, keine Fallen, kein Schubsen)
			item.CanTouch = options.Physics == true and item == root
			item.CanQuery = false
			item.CanCollide = options.Physics == true and item == root
			item.Massless = item ~= root
		elseif item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	root.Anchored = options.Physics ~= true
	-- Kleine Muetze, damit Gegner auf einen Blick erkennbar sind
	local head = body:FindFirstChild("Head") :: BasePart?
	if head then
		local cap = Instance.new("Part")
		cap.Name = "RivalCap"
		cap.Size = Vector3.new(1.3, 0.45, 1.3)
		cap.Color = options.Hat or Color3.fromRGB(255, 70, 70)
		cap.Material = Enum.Material.SmoothPlastic
		cap.CanCollide = false
		cap.CanQuery = false
		cap.CanTouch = false
		cap.Massless = true
		cap.CFrame = head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.15, 0)
		local brim = cap:Clone()
		brim.Name = "Brim"
		brim.Size = Vector3.new(1.2, 0.12, 0.7)
		brim.CFrame = cap.CFrame * CFrame.new(0, -0.15, -0.8)
		for _, p in { cap, brim } do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = p
			weld.Parent = p
			p.Parent = body
		end
	end
	CollectionService:AddTag(body, options.Tag or "Npc")
	body:SetAttribute("IsBot", true)
	return body, humanoid, root
end

-- Hoehe der Huefte ueber dem Boden (fuer verankerte Gegner)
function NpcBody.RootHeight(model: Model): number
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model.PrimaryPart
	return (if humanoid then humanoid.HipHeight else 2) + (if root then root.Size.Y / 2 else 1)
end

-- Spielt eine der Standard-Animationen (stoppt die vorige)
function NpcBody.Play(model: Model, name: string, speed: number?)
	if playing[model] == name then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local cache = tracks[model]
	if not cache then
		cache = {}
		tracks[model] = cache
		model.Destroying:Connect(function()
			tracks[model] = nil
			playing[model] = nil
		end)
	end
	local current = playing[model]
	if current and cache[current] then
		cache[current]:Stop(0.15)
	end
	playing[model] = name
	local track = cache[name]
	if not track then
		local ok = pcall(function()
			local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
			animator.Parent = humanoid
			local animation = Instance.new("Animation")
			animation.AnimationId = ANIMATIONS[name]
			track = animator:LoadAnimation(animation)
			track.Looped = name ~= "Jump"
		end)
		if not ok or not track then
			return
		end
		cache[name] = track
	end
	track:Play(0.15, 1, speed or 1)
end

-- Namensschild: oben Kennzeichnung (z. B. "RIVAL"), Mitte Name, unten Info; liefert die drei Labels
function NpcBody.Tag(model: Model, top: string, color: Color3, maxDistance: number?): (TextLabel, TextLabel, TextLabel)
	local head = model:FindFirstChild("Head") :: BasePart?
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Adornee = head or model.PrimaryPart
	gui.Size = UDim2.fromScale(7, 2.4)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = maxDistance or 90
	gui.LightInfluence = 0
	local function label(y: number, h: number, font: Enum.Font, text: string, textColor: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = font
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = textColor
		l.TextStrokeTransparency = 0.3
		l.Parent = gui
		return l
	end
	local a = label(0, 0.25, Enum.Font.GothamBlack, top, color)
	local b = label(0.25, 0.42, Enum.Font.FredokaOne, model.Name, Color3.new(1, 1, 1))
	local c = label(0.67, 0.33, Enum.Font.GothamBold, "", Color3.fromRGB(230, 230, 230))
	gui.Parent = model
	return a, b, c
end

-- Kurze Sprechblase ueber dem Kopf
function NpcBody.Say(model: Model, text: string, seconds: number?)
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = model:FindFirstChild("Bubble")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(8, 1.4)
	gui.StudsOffset = Vector3.new(0, 5.4, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local l = Instance.new("TextLabel")
	l.BackgroundColor3 = Color3.new(1, 1, 1)
	l.BackgroundTransparency = 0.1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(30, 30, 40)
	l.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = l
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = l
	l.Parent = gui
	gui.Parent = model
	task.delay(seconds or 3, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

-- Kleine Wolke beim Erscheinen/Verschwinden
function NpcBody.Poof(position: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = position
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.new(1, 1, 1))
	emitter.Size = NumberSequence.new(1.6, 0)
	emitter.Lifetime = NumberRange.new(0.4, 0.7)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = p
	p.Parent = workspace
	emitter:Emit(18)
	task.delay(1.2, function()
		p:Destroy()
	end)
end

return NpcBody
