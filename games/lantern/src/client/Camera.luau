-- Schraege Draufsicht wie in klassischen Action-RPGs: feste Blickrichtung, weich folgend, zoombar.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Camera = {}

local YAW = math.rad(45)
local PITCH = math.rad(52)
local MIN_DISTANCE, MAX_DISTANCE = 32, 82

local player = Players.LocalPlayer
local distance = 52
local focus: Vector3? = nil
local shake = 0

function Camera.Shake(amount: number)
	-- Einstellung "Screen shake"
	if player:GetAttribute("Set_Shake") == false then
		return
	end
	shake = math.max(shake, amount)
end

function Camera.Start()
	local camera = workspace.CurrentCamera
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			distance = math.clamp(distance - input.Position.Z * 4, MIN_DISTANCE, MAX_DISTANCE)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
		if not processed and state == Enum.UserInputState.Change then
			distance = math.clamp(distance / (1 + (scale - 1) * 0.08), MIN_DISTANCE, MAX_DISTANCE)
		end
	end)

	RunService:BindToRenderStep("IsoCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local target = root.Position + Vector3.new(0, 2, 0)
			if not focus or (focus - target).Magnitude > 120 then
				focus = target -- Teleport: sofort springen
			else
				focus = focus:Lerp(target, 1 - math.exp(-dt * 10))
			end
		end
		if not focus then
			return
		end
		local offset = CFrame.Angles(0, YAW, 0) * CFrame.Angles(-PITCH, 0, 0) * Vector3.new(0, 0, distance)
		local jitter = Vector3.zero
		if shake > 0 then
			jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * shake
			shake = math.max(0, shake - dt * 3)
		end
		camera.CFrame = CFrame.lookAt(focus + offset + jitter, focus + jitter)
	end)
end

return Camera
