-- MOBA-Kamera von schraeg oben wie im Original: die eigene Basis unten links, die gegnerische oben rechts.
-- Fuer Dusk ist das Bild gedreht, damit man immer "nach oben" angreift. Kamerafahrt in den Pausen.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local zoom = 1
local classic = false
local focusModel: Model? = nil
local focusRing: BasePart? = nil

CameraController.Changed = Instance.new("BindableEvent")

-- +1 fuer Dawn, -1 fuer Dusk (Bild um 180 Grad gedreht)
function CameraController.TeamSign(): number
	return if player:GetAttribute("Team") == 2 then -1 else 1
end
local teamSign = CameraController.TeamSign

-- Bildschirm-Richtungen in der Welt: oben = -Z (Dawn), rechts = +X (Dawn)
function CameraController.ScreenUp(): Vector3
	return Vector3.new(0, 0, -1) * teamSign()
end

function CameraController.ScreenRight(): Vector3
	return Vector3.new(1, 0, 0) * teamSign()
end

function CameraController.IsClassic(): boolean
	return classic
end

function CameraController.SetClassic(enabled: boolean)
	classic = enabled
	local camera = workspace.CurrentCamera
	if enabled then
		camera.CameraType = Enum.CameraType.Custom
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	CameraController.Changed:Fire()
end

-- Punkt auf dem Boden unter einem Bildschirmpunkt (Standard: Maus)
function CameraController.GroundAt(screen: Vector2): Vector3?
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	if math.abs(ray.Direction.Y) < 0.01 then
		return nil
	end
	local t = -ray.Origin.Y / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

function CameraController.MouseGround(): Vector3?
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return nil
	end
	return CameraController.GroundAt(UserInputService:GetMouseLocation())
end

-- Einheit unter einem Bildschirmpunkt (oder in der Naehe; Finger sind ungenau)
function CameraController.UnitAt(screen: Vector2, enemiesOnly: boolean?, seen: ((Instance) -> boolean)?): Model?
	local camera = workspace.CurrentCamera
	local myTeam = player:GetAttribute("Team")
	local best, bestDistance = nil, 34
	for _, model in CollectionService:GetTagged("Unit") do
		if model:IsA("Model") and model ~= player.Character and (model:GetAttribute("HP") or 0) > 0 then
			local team = model:GetAttribute("Team")
			if (not enemiesOnly or team ~= myTeam) and (not seen or seen(model)) then
				local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local point, visible = camera:WorldToViewportPoint(root.Position)
					local radius = (tonumber(model:GetAttribute("Radius")) or 1.5) * 6
					local distance = (Vector2.new(point.X, point.Y) - screen).Magnitude - radius
					if visible and distance < bestDistance then
						best, bestDistance = model, distance
					end
				end
			end
		end
	end
	return best
end

function CameraController.Focus(): Model?
	return focusModel
end

function CameraController.SetFocus(model: Model?, silent: boolean?)
	focusModel = model
	if not silent then
		remotes.Focus:FireServer(model)
	end
	if focusRing then
		focusRing:Destroy()
		focusRing = nil
	end
	if model then
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(255, 90, 90)
		ring.Transparency = 0.35
		local radius = (tonumber(model:GetAttribute("Radius")) or 1.5) * 2 + 3
		ring.Size = Vector3.new(0.15, radius, radius)
		ring.Parent = workspace
		focusRing = ring
	end
end

function CameraController.Start()
	local camera = workspace.CurrentCamera
	local match = ReplicatedStorage:WaitForChild("Match")

	-- Zoom mit Mausrad oder zwei Fingern; Startwert aus den Einstellungen
	local function applySetting()
		local wanted = tonumber(player:GetAttribute("Setting_Zoom"))
		if wanted then
			zoom = math.clamp(wanted, 0.7, 1.4)
		end
	end
	applySetting()
	player:GetAttributeChangedSignal("Setting_Zoom"):Connect(applySetting)
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - input.Position.Z * 0.08, 0.7, 1.4)
		end
	end)
	-- Vorher fehlte das Zwei-Finger-Zoomen am Handy
	local pinchStart = zoom
	UserInputService.TouchPinch:Connect(function(_positions, scale, _velocity, state, processed)
		if processed then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchStart = zoom
		elseif scale > 0 then
			zoom = math.clamp(pinchStart / scale, 0.7, 1.4)
		end
	end)

	remotes.Focus.OnClientEvent:Connect(function(model)
		CameraController.SetFocus(if typeof(model) == "Instance" then model :: Model else nil, true)
	end)

	local orbit = 0
	RunService:BindToRenderStep("MobaCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local phase = match:GetAttribute("Phase")
		local alive = root ~= nil and (phase == "Playing" or phase == "End")
		if focusModel and (not focusModel.Parent or (focusModel:GetAttribute("HP") or 0) <= 0) then
			CameraController.SetFocus(nil, true)
		end
		if focusRing and focusModel then
			local target = (focusModel.PrimaryPart or focusModel:FindFirstChild("HumanoidRootPart")) :: any
			if target then
				focusRing.CFrame = CFrame.new(target.Position.X, 0.5, target.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
		if classic and alive then
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		if alive and root then
			local up = CameraController.ScreenUp()
			local target = Vector3.new(root.Position.X, 0, root.Position.Z) + up * 6
			local offset = (Vector3.new(0, 64, 0) - up * 36) * zoom
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(target + offset, target), math.min(1, dt * 12))
			camera.FieldOfView = 55
		else
			-- Kamerafahrt ueber die Kluft
			orbit += dt * 0.05
			local position = Vector3.new(math.cos(orbit) * 200, 140, math.sin(orbit) * 200)
			camera.CFrame = CFrame.lookAt(position, Vector3.new(0, 0, 0))
			camera.FieldOfView = 55
		end
	end)
end

return CameraController
