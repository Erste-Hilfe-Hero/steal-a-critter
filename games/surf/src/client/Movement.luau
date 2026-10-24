-- Eigene Surf-Steuerung und Kamera. Der Humanoid steuert nichts: SurfPhysics rechnet jede 1/100 s
-- die Bewegung einer Box (wie die Spieler-Hitbox in Counter-Strike) gegen die Map, der Client setzt danach
-- den Charakter. Ausserdem: Zonen (Start, Ziel, Absturz), Timer, Checkpoints, Wind und Schnee.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local Movement = {}

local TICK = 1 / 100
local HULL = Vector3.new(2, 5, 2)
local PRESPEED_CAP = 290 * SurfPhysics.Unit -- maximale Startgeschwindigkeit beim Verlassen der Startzone

-- Laufzustand (liest die UI)
Movement.Speed = 0 -- horizontal, in Studs/s
Movement.StageStart = nil :: number?
Movement.RunStart = nil :: number?
Movement.Finished = false
Movement.Checkpoint = nil
Movement.UiOpen = false -- Fenster offen: Maus frei
Movement.JumpHeld = false -- Sprungknopf auf dem Handy

local state = { Position = Vector3.new(0, 0, 0), Velocity = Vector3.new(0, 0, 0), Grounded = false }
local previousPosition = state.Position
local accumulator = 0
local character: Model?
local root: BasePart?
local humanoid: Humanoid?
local footOffset = 3
local yaw, pitch = 0, -0.15
local distance = 13
local up = Vector3.new(0, 1, 0)
local lastContact = Vector3.new(0, 1, 0)
local lastContactTime = 0
local inStart = false
local finishSent = false
local portalCooldown = 0
local cursorFree = false
local controls

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function hullOffset(): Vector3
	return Vector3.new(0, HULL.Y / 2 - footOffset, 0)
end

local function cast(from: Vector3, delta: Vector3)
	local result = workspace:Blockcast(CFrame.new(from), HULL, delta, params)
	if result then
		lastContact = result.Normal
		lastContactTime = os.clock()
		return { Distance = result.Distance, Normal = result.Normal }
	end
	return nil
end

local function settings()
	local scale = workspace:GetAttribute("GravityScale") or 1
	if scale == 1 then
		return SurfPhysics.Settings
	end
	local s = table.clone(SurfPhysics.Settings)
	s.Gravity *= scale
	return s
end

---------------------------------------------------------------- Teleport

function Movement.Teleport(cframe: CFrame)
	state.Position = cframe.Position + hullOffset()
	state.Velocity = Vector3.new(0, 0, 0)
	state.Grounded = false
	previousPosition = state.Position
	local look = cframe.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	pitch = -0.15
	Movement.StageStart = nil
	if (player:GetAttribute("Stage") or 0) <= 1 then
		Movement.RunStart = nil
	end
	finishSent = false
	inStart = false
end

---------------------------------------------------------------- Zonen

local function inside(part: BasePart, point: Vector3): boolean
	local p = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	return math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z
end

local function zoneFor(kind: string, stage: number?): BasePart?
	local zones = workspace:FindFirstChild("Zones")
	return zones and zones:FindFirstChild(kind .. (stage or "")) :: BasePart?
end

local function checkZones()
	local stage = player:GetAttribute("Stage") or 0
	local point = state.Position
	local feet = point - Vector3.new(0, HULL.Y / 2, 0)
	if stage == 0 then
		local portal = zoneFor("StartPortal")
		if portal and inside(portal, point) and os.clock() > portalCooldown then
			portalCooldown = os.clock() + 2
			remotes.Run:FireServer("Start")
		end
		local lobbyKill = workspace:GetAttribute("LobbyKillY")
		local spawn = workspace:GetAttribute("LobbySpawn")
		if lobbyKill and spawn and feet.Y < lobbyKill then
			Movement.Teleport(spawn)
		end
		return
	end

	local start = zoneFor("Start", stage)
	if not start then
		return
	end
	local nowInStart = inside(start, point)
	if inStart and not nowInStart then
		-- Startzone verlassen: Uhr laeuft, Anlauftempo begrenzen
		local flat = Vector3.new(state.Velocity.X, 0, state.Velocity.Z)
		if flat.Magnitude > PRESPEED_CAP then
			local capped = flat.Unit * PRESPEED_CAP
			state.Velocity = Vector3.new(capped.X, state.Velocity.Y, capped.Z)
		end
		Movement.StageStart = os.clock()
		if stage == 1 then
			Movement.RunStart = Movement.StageStart
		end
		finishSent = false
		remotes.Run:FireServer("Leave", stage)
	elseif nowInStart then
		Movement.StageStart = nil
		if stage == 1 then
			Movement.RunStart = nil
		end
	end
	inStart = nowInStart

	local finish = zoneFor("Finish", stage)
	if finish and not finishSent and Movement.StageStart and inside(finish, point) then
		finishSent = true
		local now = os.clock()
		remotes.Run:FireServer("Finish", stage, now - Movement.StageStart, if Movement.RunStart then now - Movement.RunStart else nil)
		Movement.StageStart = nil
	end

	local killY = start:GetAttribute("KillY")
	local spawn = start:GetAttribute("Spawn")
	if killY and spawn and feet.Y < killY then
		Movement.Teleport(spawn)
		remotes.Run:FireServer("Fell", stage)
	end
end

---------------------------------------------------------------- Checkpoints (Pass)

function Movement.SaveCheckpoint()
	if not player:GetAttribute("Pass_Practice") then
		remotes.Purchase:FireServer("Pass", "Practice")
		return false
	end
	Movement.Checkpoint = { Position = state.Position, Velocity = state.Velocity, Yaw = yaw, Pitch = pitch, Stage = player:GetAttribute("Stage") }
	return true
end

function Movement.LoadCheckpoint()
	if not player:GetAttribute("Pass_Practice") then
		remotes.Purchase:FireServer("Pass", "Practice")
		return false
	end
	local cp = Movement.Checkpoint
	if not cp or cp.Stage ~= player:GetAttribute("Stage") then
		return false
	end
	state.Position = cp.Position
	state.Velocity = cp.Velocity
	previousPosition = cp.Position
	yaw, pitch = cp.Yaw, cp.Pitch
	remotes.Run:FireServer("UsedCheckpoint")
	return true
end

---------------------------------------------------------------- Eingabe

local function readInput()
	local move = if controls then controls:GetMoveVector() else Vector3.new(0, 0, 0)
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
	local wish = right * move.X + forward * -move.Z
	local amount = math.min(1, wish.Magnitude)
	local jump = Movement.JumpHeld
		or (humanoid ~= nil and humanoid.Jump)
		or (not Movement.UiOpen and UserInputService:IsKeyDown(Enum.KeyCode.Space))
		or (UserInputService.GamepadEnabled and UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA))
	return {
		WishDir = if amount > 1e-3 then wish.Unit else Vector3.new(0, 0, 0),
		WishAmount = amount,
		Jump = jump, -- gedrueckt halten = automatisches Bunny-Hopping
	}
end

-- Touch: Ziehen auf der rechten Bildschirmseite dreht die Kamera
local touches = {}
UserInputService.TouchStarted:Connect(function(input, processed)
	if not processed and input.Position.X > camera.ViewportSize.X * 0.35 then
		touches[input] = input.Position
	end
end)
UserInputService.TouchMoved:Connect(function(input)
	local last = touches[input]
	if last then
		local delta = input.Position - last
		touches[input] = input.Position
		yaw -= delta.X * 0.0065
		pitch = math.clamp(pitch - delta.Y * 0.0055, -1.35, 1.2)
	end
end)
UserInputService.TouchEnded:Connect(function(input)
	touches[input] = nil
end)

UserInputService.InputChanged:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed then
		distance = math.clamp(distance - input.Position.Z * 2, 0, 28)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.LeftAlt then
		cursorFree = not cursorFree
	elseif input.KeyCode == Enum.KeyCode.One then
		Movement.SaveCheckpoint()
	elseif input.KeyCode == Enum.KeyCode.Two then
		Movement.LoadCheckpoint()
	elseif input.KeyCode == Enum.KeyCode.R then
		remotes.Run:FireServer("RestartStage")
	elseif input.KeyCode == Enum.KeyCode.V then
		distance = if distance > 0 then 0 else 13
	end
end)

---------------------------------------------------------------- Charakter

local function setupCharacter(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid", 10) :: Humanoid?
	root = newCharacter:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not humanoid or not root then
		return
	end
	humanoid.EvaluateStateMachine = false
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		footOffset = humanoid.HipHeight + root.Size.Y / 2
	else
		footOffset = root.Size.Y / 2 + 2
	end
	local function noCollide(part: Instance)
		if part:IsA("BasePart") then
			part.CollisionGroup = "Surfers"
		end
	end
	for _, d in newCharacter:GetDescendants() do
		noCollide(d)
	end
	newCharacter.DescendantAdded:Connect(noCollide)
	local exclude = { newCharacter }
	local zones = workspace:FindFirstChild("Zones")
	if zones then
		table.insert(exclude, zones)
	end
	params.FilterDescendantsInstances = exclude
	-- Startposition: wo der Server den Charakter hingestellt hat
	Movement.Teleport(root.CFrame)
end

---------------------------------------------------------------- Schleife

local wind = Instance.new("Sound")
wind.SoundId = "rbxasset://sounds/action_falling.mp3"
wind.Looped = true
wind.Volume = 0
wind.Parent = SoundService

local snowPart = Instance.new("Part")
snowPart.Name = "LocalSnow"
snowPart.Anchored = true
snowPart.CanCollide = false
snowPart.CanQuery = false
snowPart.CanTouch = false
snowPart.Transparency = 1
snowPart.Size = Vector3.new(160, 1, 160)
local snow = Instance.new("ParticleEmitter")
snow.Rate = 140
snow.Lifetime = NumberRange.new(5, 8)
snow.Speed = NumberRange.new(5, 9)
snow.SpreadAngle = Vector2.new(25, 25)
snow.EmissionDirection = Enum.NormalId.Bottom
snow.Size = NumberSequence.new(0.22)
snow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
snow.Color = ColorSequence.new(Color3.fromRGB(240, 248, 255))
snow.LightEmission = 0.4
snow.RotSpeed = NumberRange.new(-60, 60)
snow.Parent = snowPart

local cameraParams = RaycastParams.new()
cameraParams.FilterType = Enum.RaycastFilterType.Exclude
cameraParams.RespectCanCollide = true

local function step(dt: number)
	if not root or not character or not root.Parent then
		return
	end
	-- Kamera drehen (Maus ist auf dem PC in der Mitte gefangen, wie in einem Shooter)
	local freeMouse = Movement.UiOpen or cursorFree or not UserInputService.MouseEnabled
	UserInputService.MouseBehavior = if freeMouse then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	if not freeMouse then
		local delta = UserInputService:GetMouseDelta()
		local sensitivity = 0.0042 * UserSettings():GetService("UserGameSettings").MouseSensitivity
		yaw -= delta.X * sensitivity
		pitch = math.clamp(pitch - delta.Y * sensitivity, -1.35, 1.2)
	end
	if UserInputService.GamepadEnabled then
		for _, key in UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) do
			if key.KeyCode == Enum.KeyCode.Thumbstick2 and key.Position.Magnitude > 0.15 then
				yaw -= key.Position.X * dt * 3.2
				pitch = math.clamp(pitch + key.Position.Y * dt * 2.4, -1.35, 1.2)
			end
		end
	end

	-- Physik in festen Schritten (unabhaengig von der Bildrate)
	local input = readInput()
	local s = settings()
	accumulator = math.min(accumulator + dt, TICK * 8)
	while accumulator >= TICK do
		accumulator -= TICK
		previousPosition = state.Position
		SurfPhysics.Step(state, input, TICK, cast, s)
		checkZones()
		if humanoid then
			humanoid.Jump = false
		end
	end
	local alpha = accumulator / TICK
	local renderPos = previousPosition:Lerp(state.Position, alpha)
	Movement.Speed = SurfPhysics.HorizontalSpeed(state.Velocity)

	-- Koerper: schaut in Blickrichtung und lehnt sich beim Surfen in die Rampe
	local surfing = os.clock() - lastContactTime < 0.15 and lastContact.Y < s.StandNormal and not state.Grounded
	local targetUp = if surfing then Vector3.new(0, 1, 0):Lerp(lastContact, 0.55).Unit else Vector3.new(0, 1, 0)
	up = up:Lerp(targetUp, math.min(1, dt * 10)).Unit
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local rightVec = forward:Cross(up).Unit
	local look = up:Cross(rightVec).Unit
	local rootPos = renderPos - hullOffset()
	root.CFrame = CFrame.fromMatrix(rootPos, rightVec, up, -look)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

	-- Kamera hinter dem Spieler, mit Abstand zu Waenden
	local focus = rootPos + Vector3.new(0, 1.6, 0)
	local rotation = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local wanted = distance
	if wanted > 0 then
		cameraParams.FilterDescendantsInstances = { character, workspace:FindFirstChild("Zones") or character }
		local back = (rotation * CFrame.new(0, 0, wanted)).Position
		local hit = workspace:Raycast(focus, back, cameraParams)
		if hit then
			wanted = math.max(0.5, (hit.Position - focus).Magnitude - 0.6)
		end
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.new(focus) * rotation * CFrame.new(0, 0, wanted)
	camera.FieldOfView = camera.FieldOfView + (70 + math.min(25, Movement.Speed / 9) - camera.FieldOfView) * math.min(1, dt * 4)
	local hide = if distance < 0.5 then 1 else 0
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = hide
		end
	end

	-- Wind wird lauter, je schneller man ist; Schnee faellt um die Kamera herum
	wind.Volume = math.clamp((Movement.Speed - 18) / 120, 0, 0.6)
	wind.PlaybackSpeed = 0.8 + math.min(0.6, Movement.Speed / 300)
	snowPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
end

function Movement.Start()
	controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any):GetControls()
	snowPart.Parent = workspace
	wind:Play()
	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
	RunService:BindToRenderStep("SurfMovement", Enum.RenderPriority.Input.Value + 1, step)

	remotes.Teleport.OnClientEvent:Connect(function(cframe: CFrame)
		Movement.Teleport(cframe)
	end)
	remotes.Checkpoint.OnClientEvent:Connect(function(action)
		if action == "Save" then
			Movement.SaveCheckpoint()
		else
			Movement.LoadCheckpoint()
		end
	end)
	-- "Reset" im Roblox-Menue = Stage neu starten statt sterben
	local bindable = Instance.new("BindableEvent")
	bindable.Event:Connect(function()
		remotes.Run:FireServer("RestartStage")
	end)
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", bindable) then
				break
			end
			task.wait(1)
		end
	end)
end

function Movement.GetStageTime(): number?
	return if Movement.StageStart then os.clock() - Movement.StageStart else nil
end

function Movement.GetRunTime(): number?
	return if Movement.RunStart then os.clock() - Movement.RunStart else nil
end

return Movement
