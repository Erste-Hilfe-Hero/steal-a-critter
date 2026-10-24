-- Arcade-Fahrsteuerung. Der Fahrer besitzt die Physik seines Autos (Network Owner), deshalb laeuft alles hier:
-- Gas/Bremse/Lenkung aus dem VehicleSeat (Tastatur, Gamepad und Handy-Stick ueber das Roblox-PlayerModule),
-- Nitro, Boost-Streifen, Sprungschanzen und ein FOV-Effekt bei hohem Tempo.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

local Drive = {
	Speed = 0,
	Driving = false,
	NitroActive = false,
	NitroCharge = 1, -- 0..1 bis Nitro wieder bereit ist
	OnNitroLocked = nil :: (() -> ())?,
}

local currentSeat: VehicleSeat? = nil
local base: BasePart? = nil
local align: AlignOrientation? = nil
local velocity: LinearVelocity? = nil
local yaw = 0
local speed = 0
local nitroUntil = 0
local nitroReadyAt = 0
local boostUntil = 0
local lastJump = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function inside(pad: BasePart, position: Vector3): boolean
	local offset = pad.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) < pad.Size.X / 2 + 1 and math.abs(offset.Z) < pad.Size.Z / 2 + 1 and offset.Y > -2 and offset.Y < 8
end

function Drive.Nitro()
	if not Drive.Driving then
		return
	end
	if not player:GetAttribute("Pass_Nitro") then
		if Drive.OnNitroLocked then
			Drive.OnNitroLocked()
		end
		return
	end
	local now = os.clock()
	if now < nitroReadyAt then
		return
	end
	nitroUntil = now + Config.NitroTime
	nitroReadyAt = now + Config.NitroCooldown
end

local function enter(seat: VehicleSeat)
	local car = seat.Parent
	local root = car and car:FindFirstChild("Base") :: BasePart?
	if not root then
		return
	end
	currentSeat = seat
	base = root
	align = root:FindFirstChild("Align") :: AlignOrientation?
	velocity = root:FindFirstChild("Drive") :: LinearVelocity?
	local look = root.CFrame.LookVector
	yaw = math.atan2(-look.X, -look.Z)
	speed = flat(root.AssemblyLinearVelocity):Dot(flat(look))
	rayParams.FilterDescendantsInstances = { car, player.Character }
	Drive.Driving = true
end

local function leave()
	currentSeat = nil
	base = nil
	align = nil
	velocity = nil
	speed = 0
	Drive.Driving = false
	Drive.Speed = 0
	Drive.NitroActive = false
end

local function step(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		if seat ~= currentSeat then
			enter(seat)
		end
	elseif currentSeat then
		leave()
	end
	local camera = workspace.CurrentCamera
	if not currentSeat or not base or not align or not velocity or not base.Parent then
		if camera then
			camera.FieldOfView += (70 - camera.FieldOfView) * math.min(1, dt * 4)
		end
		return
	end
	local car = currentSeat.Parent :: Model
	local now = os.clock()
	local maxSpeed = car:GetAttribute("MaxSpeed") or 60
	local turnRate = math.rad(car:GetAttribute("Turn") or 110)
	local throttle = currentSeat.ThrottleFloat
	local steer = currentSeat.SteerFloat
	if (car:GetAttribute("StalledUntil") or 0) > workspace:GetServerTimeNow() then
		throttle = 0
		speed *= math.max(0, 1 - dt * 3)
	end

	-- Boden unter dem Auto?
	local grounded = workspace:Raycast(base.Position, Vector3.new(0, -3, 0), rayParams) ~= nil

	-- Pads
	for _, pad in CollectionService:GetTagged("BoostPad") do
		if inside(pad, base.Position) then
			boostUntil = now + 1.2
		end
	end
	if now - lastJump > 1.2 then
		for _, pad in CollectionService:GetTagged("JumpPad") do
			if inside(pad, base.Position) then
				lastJump = now
				local v = base.AssemblyLinearVelocity
				base.AssemblyLinearVelocity = Vector3.new(v.X, Config.JumpPadPower, v.Z)
				speed = math.max(speed, maxSpeed)
			end
		end
	end

	local nitro = now < nitroUntil
	local top = maxSpeed * (if nitro then Config.NitroBoost else 1) * (if now < boostUntil then Config.BoostPadSpeed else 1)
	if grounded then
		if throttle > 0 then
			if speed < 0 then
				speed = math.min(speed + 160 * dt, 0)
			elseif speed < top then
				speed = math.min(speed + top * 0.6 * dt * throttle * (if nitro then 2.2 else 1), top)
			else
				speed = math.max(speed - 50 * dt, top)
			end
		elseif throttle < 0 then
			if speed > 0 then
				speed = math.max(speed - 150 * dt, 0)
			else
				speed = math.max(speed - 40 * dt, -maxSpeed * 0.4)
			end
		else
			speed -= math.sign(speed) * math.min(math.abs(speed), 28 * dt)
		end
		if speed > top then
			speed = math.max(speed - 60 * dt, top)
		end
	end

	-- An Waenden nicht weiter "durchdruecken"
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local actual = flat(base.AssemblyLinearVelocity):Dot(forward)
	if math.abs(speed - actual) > 30 then
		speed = actual + (speed - actual) * 0.6
	end

	local steerFactor = math.clamp(speed / 18, -1, 1) * (if grounded then 1 else 0.35)
	-- Bei hohem Tempo etwas weniger Lenkung, damit es nicht zappelt
	local highSpeedDamp = 1 - math.clamp((math.abs(speed) - 60) / 140, 0, 0.35)
	yaw -= steer * turnRate * dt * steerFactor * highSpeedDamp
	forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	align.CFrame = CFrame.Angles(0, yaw, 0)
	velocity.PlaneVelocity = Vector2.new(forward.X * speed, forward.Z * speed)

	Drive.Speed = speed
	Drive.NitroActive = nitro
	Drive.NitroCharge = math.clamp(1 - (nitroReadyAt - now) / Config.NitroCooldown, 0, 1)
	if camera then
		local targetFov = 70 + math.clamp((math.abs(speed) - 50) / 70, 0, 1) * 12 + (if nitro then 8 else 0)
		camera.FieldOfView += (targetFov - camera.FieldOfView) * math.min(1, dt * 4)
	end
end

function Drive.Start()
	RunService.Heartbeat:Connect(step)
	ContextActionService:BindAction("TurboNitro", function(_, state)
		if state == Enum.UserInputState.Begin then
			Drive.Nitro()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
end

return Drive
