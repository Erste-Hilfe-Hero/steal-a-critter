-- Faehrt das eigene Kart (der Client ist Network Owner): liest die Eingaben, ruft KartPhysics auf,
-- erkennt den Raketenstart, zeigt Drift-Funken/Boost-Flammen und fuehrt die Kamera.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local KartPhysics = require(ReplicatedStorage.Shared.KartPhysics)
local Tracks = require(ReplicatedStorage.Shared.Tracks)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local camera = workspace.CurrentCamera

local Controller = {
	Active = false,
	Speed = 0,
	DriftTier = 0,
	DriftCharge = 0,
	Drifting = false,
	BoostTime = 0,
	Spectate = false,
	WrongWay = false,
	OnEvent = nil :: ((string, any?) -> ())?,
}

local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
	end)
	if ok then
		controls = module:GetControls()
	end
end)

local kart: Model? = nil
local geo: Tracks.Geometry? = nil
local state: KartPhysics.State? = nil
local driftHeld = false
local throttleAt: number? = nil
local wasCountdown = false
local boosting = false
local respawnRequested = false
local tapGasAt: number? = nil -- Handy: Zeitpunkt (Restzeit) des ersten GAS-Tippens im Countdown
local wrongWayTime = 0
local camCf: CFrame? = nil
local camYaw = 0
local shake = 0

local roadParams = RaycastParams.new()
roadParams.FilterType = Enum.RaycastFilterType.Include
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Include

local function event(name: string, value: any?)
	if Controller.OnEvent then
		Controller.OnEvent(name, value)
	end
end

local function now(): number
	return workspace:GetServerTimeNow()
end

function Controller.Respawn()
	respawnRequested = true
end

function Controller.SetDrift(held: boolean)
	driftHeld = held
end

-- Handy: GAS-Knopf im Countdown (zaehlt nur das erste Tippen, zu frueh = kein Raketenstart)
function Controller.TapGas()
	if workspace:GetAttribute("Phase") ~= "Countdown" or tapGasAt ~= nil then
		return
	end
	tapGasAt = (workspace:GetAttribute("PhaseEnd") or 0) - now()
	if tapGasAt > 1.3 then
		event("Early", nil)
	end
end

local function setting(key: string): boolean
	return player:GetAttribute("Set_" .. key) ~= false
end

local function setSparks(drifting: boolean, tier: number)
	if not kart then
		return
	end
	for _, d in kart:GetDescendants() do
		if d.Name == "DriftSpark" and d:IsA("ParticleEmitter") then
			d.Enabled = drifting
			d.Color = ColorSequence.new(if tier > 0 then Config.DriftColors[tier] else Color3.fromRGB(255, 240, 200))
			d.Rate = if tier > 0 then 40 + tier * 30 else 25
		end
	end
end

local function findKart(): Model?
	local folder = workspace:FindFirstChild("Karts")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Driver") == player.UserId and model.PrimaryPart then
			return model
		end
	end
	return nil
end

local function bind()
	ContextActionService:BindActionAtPriority("KartDrift", function(_, inputState)
		driftHeld = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonL1)
	ContextActionService:BindActionAtPriority("KartItem", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			remotes.UseItem:FireServer()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.ButtonX)
	ContextActionService:BindActionAtPriority("KartRespawn", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			respawnRequested = true
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
end

local function unbind()
	ContextActionService:UnbindAction("KartDrift")
	ContextActionService:UnbindAction("KartItem")
	ContextActionService:UnbindAction("KartRespawn")
	driftHeld = false
end

local function setJump(enabled: boolean)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	end
end

local function start(model: Model)
	kart = model
	geo = Tracks.Geometry(workspace:GetAttribute("TrackId"))
	state = KartPhysics.new(player:GetAttribute("Kart") or "Ember", model.PrimaryPart :: BasePart, geo :: Tracks.Geometry)
	throttleAt = nil
	tapGasAt = nil
	wrongWayTime = 0
	Controller.WrongWay = false
	camCf = nil
	Controller.Active = true
	bind()
	setJump(false)
	event("Start", nil)
end

local function stop()
	Controller.Active = false
	kart = nil
	state = nil
	Controller.Speed, Controller.BoostTime, Controller.DriftCharge, Controller.DriftTier = 0, 0, 0, 0
	Controller.Drifting = false
	Controller.WrongWay = false
	unbind()
	if boosting then
		boosting = false
		remotes.Boosting:FireServer(false)
	end
	setJump(true)
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	event("Stop", nil)
end

local function readInput(s: KartPhysics.State, root: BasePart): (number, number)
	local move = if controls then controls:GetMoveVector() else Vector3.zero
	local steer = math.clamp(move.X, -1, 1)
	local throttle = math.clamp(-move.Z, -1, 1)
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		-- Handy: Gas automatisch, Stick nach hinten = Bremse/Rueckwaerts
		throttle = if move.Z > 0.6 then -1 else 1
	end
	if UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonR2) then
		throttle = 1
	elseif UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonL2) then
		throttle = -1
	end
	if player:GetAttribute("Finished") then
		-- Nach dem Ziel faehrt der Autopilot eine Ehrenrunde
		steer, throttle = KartPhysics.Autopilot(s, root, geo :: Tracks.Geometry)
		throttle = 0.7
	end
	return throttle, steer
end

local function step(dt: number)
	local model, s, g = kart, state, geo
	if not model or not model.Parent or not s or not g then
		return
	end
	local root = model.PrimaryPart :: BasePart
	if not root or root.Anchored then
		return
	end
	local track = workspace:FindFirstChild("Track")
	if track then
		roadParams.FilterDescendantsInstances = { track:FindFirstChild("Road") :: Instance }
		wallParams.FilterDescendantsInstances = { track:FindFirstChild("Walls") :: Instance }
	end
	local phase = workspace:GetAttribute("Phase")
	local throttle, steer = readInput(s, root)

	-- Countdown: stehen bleiben, Raketenstart erkennen (Gas beim letzten Licht)
	if phase == "Countdown" then
		wasCountdown = true
		local remaining = (workspace:GetAttribute("PhaseEnd") or 0) - now()
		if throttle > 0.5 and not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
			throttleAt = throttleAt or remaining
		elseif throttle <= 0.5 then
			throttleAt = nil
		end
		-- Auf der Startposition schweben, ohne loszufahren
		KartPhysics.Step(s, root, g, { Throttle = 0, Steer = 0, Drift = false }, dt, 0, roadParams, wallParams)
		s.Speed = 0
		return
	end
	if phase ~= "Race" then
		root.AssemblyLinearVelocity = Vector3.zero
		return
	end
	if wasCountdown then
		wasCountdown = false
		local launch = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then tapGasAt else throttleAt
		local perfect = launch ~= nil and launch < 1.3 and launch > 0.05
		tapGasAt = nil
		if player:GetAttribute("Pass_RocketStart") or perfect then
			KartPhysics.Boost(s, Config.RocketStartBoost)
			event("Rocket", nil)
		end
	end

	local respawn = respawnRequested
	respawnRequested = false
	local events = KartPhysics.Step(s, root, g, { Throttle = throttle, Steer = steer, Drift = driftHeld, Respawn = respawn }, dt, player:GetAttribute("RaceCoins") or 0, roadParams, wallParams)
	for _, name in events do
		if name == "Bump" then
			shake = 0.25
		end
		event(name, if name == "DriftTier" then s.DriftTier else nil)
	end

	Controller.Speed = s.Speed
	Controller.BoostTime = s.BoostTime
	Controller.DriftCharge = s.DriftCharge
	Controller.DriftTier = s.DriftTier
	Controller.Drifting = s.Drifting
	-- Falsche Richtung: laenger als 1 s gegen die Fahrtrichtung der Strecke
	local tangent = g.Tangents[s.LastIndex]
	local forward = Vector3.new(-math.sin(s.Yaw), 0, -math.cos(s.Yaw))
	if s.Speed > 12 and forward:Dot(Vector3.new(tangent.X, 0, tangent.Z).Unit) < -0.3 and not player:GetAttribute("Finished") then
		wrongWayTime += dt
	else
		wrongWayTime = 0
	end
	Controller.WrongWay = wrongWayTime > 1
	setSparks(s.Drifting, s.DriftTier)
	local nowBoosting = s.BoostTime > 0
	if nowBoosting ~= boosting then
		boosting = nowBoosting
		remotes.Boosting:FireServer(boosting)
	end
end

local function updateCamera(dt: number)
	local phase = workspace:GetAttribute("Phase")
	local target: BasePart? = nil
	local yaw = camYaw
	if Controller.Active and kart and kart.PrimaryPart and state then
		target = kart.PrimaryPart
		yaw = (state :: KartPhysics.State).Yaw
	elseif Controller.Spectate and phase == "Race" then
		local folder = workspace:FindFirstChild("Karts")
		for _, model in (if folder then folder:GetChildren() else {}) do
			if model:IsA("Model") and model:GetAttribute("Place") == 1 and model.PrimaryPart then
				target = model.PrimaryPart
				local l = model.PrimaryPart.CFrame.LookVector
				yaw = math.atan2(-l.X, -l.Z)
			end
		end
	end
	if not target then
		if camera.CameraType == Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = 70
		end
		camCf = nil
		return
	end
	-- Kamerawinkel weich nachziehen (kein Wackeln beim Driften)
	local diff = (yaw - camYaw + math.pi) % (2 * math.pi) - math.pi
	camYaw += diff * math.min(1, dt * 7)
	camera.CameraType = Enum.CameraType.Scriptable
	local flat = CFrame.new(target.Position) * CFrame.Angles(0, camYaw, 0)
	local desired = CFrame.lookAt((flat * CFrame.new(0, 6.5, 15)).Position, (flat * CFrame.new(0, 2, -10)).Position)
	camCf = if camCf then camCf:Lerp(desired, math.min(1, dt * 12)) else desired
	local cf = camCf :: CFrame
	if shake > 0 then
		shake = math.max(0, shake - dt)
		if setting("Shake") then
			cf *= CFrame.new((math.random() - 0.5) * shake * 1.5, (math.random() - 0.5) * shake * 1.5, 0)
		end
	end
	camera.CFrame = cf
	local speedRatio = math.clamp(math.abs(Controller.Speed) / Config.MaxKartSpeed, 0, 1.4)
	local fov = if setting("Fov") then 68 + speedRatio * 10 + (if Controller.BoostTime > 0 then 8 else 0) else 70
	camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 5)
end

function Controller.Init()
	RunService.PreSimulation:Connect(function(dt)
		local phase = workspace:GetAttribute("Phase")
		if player:GetAttribute("Racing") == true and (phase == "Countdown" or phase == "Race") then
			if not Controller.Active or not kart or not kart.Parent then
				local model = findKart()
				if model then
					start(model)
				end
			end
			if Controller.Active then
				step(dt)
			end
		elseif Controller.Active then
			stop()
		end
	end)
	RunService:BindToRenderStep("KartCamera", Enum.RenderPriority.Camera.Value + 1, updateCamera)

	remotes.Effect.OnClientEvent:Connect(function(kind, value)
		local s = state
		if s then
			if kind == "Boost" then
				KartPhysics.Boost(s, value)
			elseif kind == "Spin" then
				if KartPhysics.Spin(s, value) then
					shake = 0.6
				end
			elseif kind == "Inferno" then
				s.InfernoTime = value
				KartPhysics.Boost(s, value, Config.InfernoMultiplier)
			end
		end
		event(kind, value)
	end)
end

return Controller
