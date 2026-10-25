-- Alles Sichtbare in der Welt: Cartoon-K.O., Schuesse, fliegende Messer, Fussspuren, Haustiere,
-- Schilde, Taschenlampen, Lueftungs-/Schrank-Prompts und kleine Animationen (Muenzen, Plattformen).
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)

local Effects = {}

local C = Config.Colors
local fxFolder = Instance.new("Folder")
fxFolder.Name = "LocalFx"
fxFolder.Parent = workspace

Effects.Role = nil :: string?
Effects.SfxEnabled = true -- Einstellung "Sound effects"
Effects.ShowPets = true -- Einstellung "Show pets"

---------------------------------------------------------------- Sounds (nur eingebaute Roblox-Sounds)

local SOUNDS = {
	Slash = "rbxasset://sounds/swordslash.wav",
	Lunge = "rbxasset://sounds/swordlunge.wav",
	Ping = "rbxasset://sounds/electronicpingshort.wav",
	Click = "rbxasset://sounds/button.wav",
	Tick = "rbxasset://sounds/clickfast.wav",
	Jump = "rbxasset://sounds/action_jump.mp3",
}

function Effects.Sound(name: string, position: Vector3?, pitch: number?, volume: number?)
	local id = SOUNDS[name]
	if not id or not Effects.SfxEnabled then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = pitch or 1
	if position then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = position
		holder.Parent = workspace.Terrain
		sound.RollOffMaxDistance = 120
		sound.Parent = holder
		sound:Play()
		Debris:AddItem(holder, 3)
	else
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 3)
	end
end

---------------------------------------------------------------- Partikel-Helfer

local function burst(position: Vector3, color: Color3, count: number, props)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = props.Light or 0.6
	emitter.Lifetime = props.Lifetime or NumberRange.new(0.5, 1)
	emitter.Speed = props.Speed or NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = props.Size or NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = props.Transparency or NumberSequence.new(0, 1)
	emitter.Acceleration = props.Acceleration or Vector3.new(0, -10, 0)
	emitter.Drag = props.Drag or 3
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-200, 200)
	if props.Texture then
		emitter.Texture = props.Texture
	end
	if props.Colors then
		emitter.Color = props.Colors
	end
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count)
	Debris:AddItem(attachment, 3)
end

local KO_EFFECTS = {
	Poof = function(p)
		burst(p, Color3.fromRGB(235, 235, 245), 40, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 3.5) }), Speed = NumberRange.new(4, 9), Acceleration = Vector3.new(0, 3, 0), Light = 0 })
	end,
	Stars = function(p)
		burst(p, Color3.fromRGB(255, 220, 80), 40, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Light = 1 })
		burst(p, Color3.fromRGB(235, 235, 245), 20, { Size = NumberSequence.new(1.6, 2.6), Speed = NumberRange.new(3, 6), Acceleration = Vector3.new(0, 3, 0), Light = 0 })
	end,
	Confetti = function(p)
		burst(p, Color3.new(1, 1, 1), 80, { Colors = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Pink), ColorSequenceKeypoint.new(0.33, C.Moon), ColorSequenceKeypoint.new(0.66, C.Cyan), ColorSequenceKeypoint.new(1, C.Green) }), Size = NumberSequence.new(0.5), Speed = NumberRange.new(15, 25), Acceleration = Vector3.new(0, -25, 0), Lifetime = NumberRange.new(1, 1.6), Light = 0.3 })
	end,
	Hearts = function(p)
		burst(p, Color3.fromRGB(255, 90, 130), 35, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }), Acceleration = Vector3.new(0, 8, 0), Speed = NumberRange.new(4, 10), Light = 0.8 })
	end,
	Bubbles = function(p)
		burst(p, Color3.fromRGB(150, 220, 255), 45, { Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.8) }), Transparency = NumberSequence.new(0.3, 1), Acceleration = Vector3.new(0, 10, 0), Speed = NumberRange.new(2, 7), Lifetime = NumberRange.new(1, 2), Light = 0.4 })
	end,
	Lightning = function(p)
		burst(p, Color3.fromRGB(150, 220, 255), 50, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Speed = NumberRange.new(20, 35), Light = 1 })
		local flash = Instance.new("PointLight")
		local holder = Instance.new("Attachment")
		holder.WorldPosition = p
		holder.Parent = workspace.Terrain
		flash.Color = Color3.fromRGB(150, 220, 255)
		flash.Range = 30
		flash.Brightness = 6
		flash.Parent = holder
		TweenService:Create(flash, TweenInfo.new(0.5), { Brightness = 0 }):Play()
		Debris:AddItem(holder, 1)
	end,
	Moonbeam = function(p)
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.Material = Enum.Material.Neon
		beam.Color = C.Moon
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(60, 3, 3)
		beam.CFrame = CFrame.new(p + Vector3.new(0, 28, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Transparency = 0.2
		beam.Parent = fxFolder
		TweenService:Create(beam, TweenInfo.new(1.2), { Transparency = 1, Size = Vector3.new(60, 0.2, 0.2) }):Play()
		Debris:AddItem(beam, 1.3)
		burst(p, C.Moon, 40, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Acceleration = Vector3.new(0, 15, 0), Light = 1 })
	end,
	Snow = function(p)
		burst(p + Vector3.new(0, 4, 0), Color3.fromRGB(230, 245, 255), 60, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Speed = NumberRange.new(2, 6), Acceleration = Vector3.new(0, -4, 0), Lifetime = NumberRange.new(1.2, 2), Light = 0.6 })
		burst(p, Color3.fromRGB(235, 240, 250), 20, { Size = NumberSequence.new(1.6, 2.8), Speed = NumberRange.new(2, 5), Acceleration = Vector3.new(0, 2, 0), Light = 0 })
	end,
	Rainbow = function(p)
		local colors = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 80)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(90, 230, 120)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 100, 255)),
		})
		burst(p, Color3.new(1, 1, 1), 70, { Colors = colors, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }), Speed = NumberRange.new(12, 22), Acceleration = Vector3.new(0, 6, 0), Lifetime = NumberRange.new(0.8, 1.4), Light = 1 })
	end,
}

-- Figur verblasst, kippt zur Seite und verpufft (kein Blut)
local function knockOut(model: Model?, position: Vector3, effect: string)
	(KO_EFFECTS[effect] or KO_EFFECTS.Poof)(position)
	Effects.Sound("Lunge", position, 0.7, 0.8)
	if not model then
		return
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			TweenService:Create(d, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		end
	end
	-- Kleine "Sterne ueber dem Kopf"-Anzeige
	local head = model:FindFirstChild("Head")
	if head then
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(120, 40)
		gui.StudsOffset = Vector3.new(0, 2.5, 0)
		gui.Adornee = head
		gui.AlwaysOnTop = true
		gui.Parent = fxFolder
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "K.O.!"
		label.Font = Enum.Font.LuckiestGuy
		label.TextScaled = true
		label.TextColor3 = C.Moon
		label.Parent = gui
		TweenService:Create(gui, TweenInfo.new(1), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
		TweenService:Create(label, TweenInfo.new(1), { TextTransparency = 1 }):Play()
		Debris:AddItem(gui, 1.1)
	end
end

---------------------------------------------------------------- Waffen-Effekte

local function shot(from: Vector3, to: Vector3, color: Color3)
	local length = (to - from).Magnitude
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Size = Vector3.new(0.25, 0.25, length)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to)
	beam.Parent = fxFolder
	TweenService:Create(beam, TweenInfo.new(0.35), { Transparency = 1, Size = Vector3.new(0.05, 0.05, length) }):Play()
	Debris:AddItem(beam, 0.4)
	burst(to, color, 14, { Speed = NumberRange.new(6, 12), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }), Light = 1 })
	Effects.Sound("Ping", from, 0.6, 0.9)
end

local function thrown(from: Vector3, dir: Vector3, speed: number, skin: string)
	local model = Skins.Knife(skin)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = fxFolder
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder, workspace:FindFirstChild("Coins") :: Instance }
	local pos = from
	local travelled = 0
	local spin = 0
	Effects.Sound("Slash", from, 1.2)
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local step = dir * speed * dt
		local result = workspace:Raycast(pos, step, params)
		travelled += step.Magnitude
		if (result and result.Instance.CanCollide) or travelled > Config.Knife.ThrowRange then
			connection:Disconnect()
			if result then
				model:PivotTo(CFrame.lookAt(result.Position, result.Position + dir) * CFrame.Angles(math.rad(-90), 0, 0))
			end
			task.delay(1.5, function()
				model:Destroy()
			end)
			return
		end
		pos += step
		spin += dt * 25
		model:PivotTo(CFrame.lookAt(pos, pos + dir) * CFrame.Angles(spin, 0, 0))
	end)
end

---------------------------------------------------------------- Fussspuren (Scanner)

function Effects.Footprints(points: { Vector3 }, duration: number)
	for i, p in points do
		local print = Instance.new("Part")
		print.Anchored = true
		print.CanCollide = false
		print.CanQuery = false
		print.CastShadow = false
		print.Material = Enum.Material.Neon
		print.Color = C.Red
		print.Shape = Enum.PartType.Cylinder
		print.Size = Vector3.new(0.1, 1, 1.4)
		print.CFrame = CFrame.new(p + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		print.Transparency = 0.2 + (1 - i / #points) * 0.6
		print.Parent = fxFolder
		task.delay(duration, function()
			TweenService:Create(print, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			Debris:AddItem(print, 0.7)
		end)
	end
end

---------------------------------------------------------------- Fallengelassener Blaster

local gunMarkers = {} -- [DropId] = Part (im Duo-Modus koennen zwei Blaster liegen)
local function markGun(position: Vector3, id: number?)
	local key = id or 0
	if gunMarkers[key] then
		gunMarkers[key]:Destroy()
	end
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.new(1, 1, 1)
	holder.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	holder.Parent = fxFolder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 50)
	gui.AlwaysOnTop = true
	gui.Adornee = holder
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "BLASTER"
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = C.Moon
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	gunMarkers[key] = holder
end

---------------------------------------------------------------- Haustiere

local pets = {} -- [Model character] = { slot = { Model, Id } }

local function updatePets(dt: number)
	local t = os.clock()
	local alive = {}
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root then
			alive[character] = true
			local entry = pets[character] or {}
			pets[character] = entry
			local hidden = not Effects.ShowPets or character:GetAttribute("Hidden") == true or character:GetAttribute("Cloaked") == true
			for i, slot in { "Pet", "Pet2" } do
				local id = character:GetAttribute(slot)
				local current = entry[slot]
				if (typeof(id) ~= "string" or id == "" or hidden) then
					if current then
						current.Model:Destroy()
						entry[slot] = nil
					end
				else
					if not current or current.Id ~= id or not current.Model.Parent then
						if current then
							current.Model:Destroy()
						end
						local model = Skins.Pet(id)
						for _, d in model:GetDescendants() do
							if d:IsA("BasePart") then
								d.CanCollide = false
								d.CanQuery = false
								d.CanTouch = false
							end
						end
						model.Parent = fxFolder
						current = { Model = model, Id = id, Pos = root.Position }
						entry[slot] = current
					end
					local side = if i == 1 then 3 else -3
					local target = (root.CFrame * CFrame.new(side, 1.5 + math.sin(t * 3 + i) * 0.4, 3)).Position
					current.Pos = current.Pos:Lerp(target, math.clamp(dt * 6, 0, 1))
					local look = root.CFrame.LookVector
					current.Model:PivotTo(CFrame.lookAt(current.Pos, current.Pos + Vector3.new(look.X, 0, look.Z)))
				end
			end
		end
	end
	for character, entry in pets do
		if not alive[character] then
			for _, current in entry do
				current.Model:Destroy()
			end
			pets[character] = nil
		end
	end
end

---------------------------------------------------------------- Prompts und Licht je nach Rolle

local function refreshPrompts()
	local role = Effects.Role
	for _, vent in CollectionService:GetTagged("Vent") do
		local prompt = vent:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = role == "Murderer"
		end
	end
	for _, closet in CollectionService:GetTagged("Closet") do
		local prompt = closet:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			prompt.ActionText = if role == "Murderer" then "Search" elseif Effects.Hidden then "Leave" else "Hide"
			prompt.Enabled = role ~= nil
		end
	end
	for _, door in CollectionService:GetTagged("Door") do
		local prompt = door:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = role ~= nil
		end
	end
end
Effects.RefreshPrompts = refreshPrompts
Effects.Hidden = false

local function refreshFlashlights()
	local blackout = ReplicatedStorage:GetAttribute("Modifier") == "Blackout"
	for _, model in CollectionService:GetTagged("Actor") do
		local head = model:FindFirstChild("Head")
		local attachment = head and head:FindFirstChild("Flashlight")
		local spot = attachment and attachment:FindFirstChildOfClass("SpotLight")
		if spot then
			spot.Enabled = blackout and model:GetAttribute("Cloaked") ~= true
		end
	end
end

-- Schild als lila Umriss
local function refreshShield(model: Model)
	local on = model:GetAttribute("Shield") == true
	local h = model:FindFirstChild("ShieldGlow")
	if on and not h then
		local highlight = Instance.new("Highlight")
		highlight.Name = "ShieldGlow"
		highlight.FillColor = C.Purple
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.FillTransparency = 0.7
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
	elseif not on and h then
		h:Destroy()
	end
end

---------------------------------------------------------------- Fx vom Server

function Effects.OnFx(kind: string, info)
	if kind == "KO" then
		knockOut(info.Model, info.Position, info.Effect)
	elseif kind == "Shot" then
		shot(info.From, info.To, info.Color)
	elseif kind == "Throw" then
		thrown(info.From, info.Dir, info.Speed, info.Skin)
	elseif kind == "Swing" then
		if info.Model then
			local root = info.Model:FindFirstChild("HumanoidRootPart")
			if root then
				Effects.Sound("Slash", root.Position, 1, 0.7)
			end
		end
	elseif kind == "GunDropped" then
		markGun(info.Position, info.Id)
		Effects.Sound("Ping", info.Position, 1.4, 1)
	elseif kind == "GunTaken" then
		local key = info.Id or 0
		if gunMarkers[key] then
			gunMarkers[key]:Destroy()
			gunMarkers[key] = nil
		end
	elseif kind == "CluePickup" then
		burst(info.Position, C.Cyan, 25, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Speed = NumberRange.new(4, 10), Light = 1 })
		Effects.Sound("Ping", info.Position, 1.8, 0.5)
	elseif kind == "Door" then
		Effects.Sound("Click", info.Position, 0.5, 1)
	elseif kind == "ClosetOpen" then
		Effects.Sound("Click", info.Position, 0.7, 0.8)
		burst(info.Position, Color3.fromRGB(200, 180, 150), 15, { Speed = NumberRange.new(3, 6), Light = 0 })
	elseif kind == "Vent" then
		for _, p in { info.From, info.To } do
			burst(p, Color3.fromRGB(120, 120, 130), 30, { Size = NumberSequence.new(1.5, 3), Speed = NumberRange.new(3, 8), Acceleration = Vector3.new(0, 6, 0), Light = 0 })
		end
	elseif kind == "Dash" then
		local root = info.Model and info.Model:FindFirstChild("HumanoidRootPart")
		if root then
			burst(root.Position, Color3.fromRGB(230, 230, 255), 18, { Speed = NumberRange.new(2, 5), Light = 0.3 })
			Effects.Sound("Jump", root.Position, 1.3, 0.6)
		end
	elseif kind == "Cloak" then
		burst(info.Position, Color3.fromRGB(60, 50, 90), 30, { Size = NumberSequence.new(1.5, 3), Speed = NumberRange.new(2, 6), Light = 0 })
	elseif kind == "Scan" then
		burst(info.Position, C.Blue, 30, { Speed = NumberRange.new(20, 30), Light = 1 })
		Effects.Sound("Ping", info.Position, 0.8, 0.7)
	elseif kind == "Glue" then
		burst(info.Position, C.Pink, 25, { Speed = NumberRange.new(3, 8), Light = 0.5 })
	elseif kind == "PowerUp" then
		burst(info.Position, info.Color, 30, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Light = 1 })
		Effects.Sound("Ping", info.Position, 1.6, 0.6)
	elseif kind == "ShieldPop" then
		burst(info.Position, C.Purple, 40, { Speed = NumberRange.new(10, 20), Light = 1 })
		Effects.Sound("Ping", info.Position, 0.5, 1)
	elseif kind == "Coin" then
		Effects.Sound("Tick", nil, 1.4 + math.random() * 0.2, 0.4)
	end
end

---------------------------------------------------------------- Start

function Effects.Start()
	-- Animationen fuer getaggte Teile
	local spinning = {}
	local function track(tag: string)
		for _, part in CollectionService:GetTagged(tag) do
			spinning[part] = { Tag = tag, Base = part.CFrame, Seed = math.random() * 10 }
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			spinning[part] = { Tag = tag, Base = part.CFrame, Seed = math.random() * 10 }
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
			spinning[part] = nil
		end)
	end
	for _, tag in { "Spin", "Bob", "Coin", "PowerUp", "Clue" } do
		track(tag)
	end
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for part, info in spinning do
			if not part.Parent then
				spinning[part] = nil
				continue
			end
			if info.Tag == "Spin" then
				part.CFrame = info.Base * CFrame.Angles(0, (t * 0.8 + info.Seed) % (math.pi * 2), 0)
			elseif info.Tag == "Bob" then
				part.CFrame = info.Base + Vector3.new(0, math.sin(t * 1.2) * 0.8, 0)
			elseif info.Tag == "Coin" or info.Tag == "Clue" then
				part.CFrame = CFrame.new(info.Base.Position + Vector3.new(0, math.sin(t * 3 + info.Seed) * 0.3, 0)) * CFrame.Angles(0, t * 3 + info.Seed, math.rad(90))
			elseif info.Tag == "PowerUp" then
				part.CFrame = CFrame.new(info.Base.Position + Vector3.new(0, math.sin(t * 2 + info.Seed) * 0.5, 0)) * CFrame.Angles(t, t * 1.3, 0)
			end
		end
		updatePets(dt)
	end)

	-- Neue Prompts auf der Karte bekommen den richtigen Zustand
	for _, tag in { "Vent", "Closet", "Door" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function()
			task.defer(refreshPrompts)
		end)
	end
	refreshPrompts()

	ReplicatedStorage:GetAttributeChangedSignal("Modifier"):Connect(refreshFlashlights)
	-- Pro Figur nur einmal verbinden (ueberlebende Spieler bekommen jede Runde wieder den Tag "Actor")
	local watched = setmetatable({}, { __mode = "k" })
	local function watchActor(model: Instance)
		if watched[model] then
			return
		end
		watched[model] = true
		model:GetAttributeChangedSignal("Shield"):Connect(function()
			refreshShield(model :: Model)
		end)
		model:GetAttributeChangedSignal("Cloaked"):Connect(refreshFlashlights)
	end
	CollectionService:GetInstanceAddedSignal("Actor"):Connect(function(model)
		task.defer(refreshFlashlights)
		watchActor(model)
	end)
	for _, model in CollectionService:GetTagged("Actor") do
		watchActor(model)
	end
	ReplicatedStorage:GetAttributeChangedSignal("RoundState"):Connect(function()
		if ReplicatedStorage:GetAttribute("RoundState") == "Intermission" then
			fxFolder:ClearAllChildren()
			table.clear(gunMarkers)
		end
	end)
end

return Effects
