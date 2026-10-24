-- MOBA-Kamera von schraeg oben (Gegner-Basis ist immer "oben"), Kamerafahrt in den Pausen,
-- Zielen mit der Maus und Antippen von Gegnern als Fokus-Ziel.
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

local function teamSign(): number
	return if player:GetAttribute("Team") == 2 then -1 else 1
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

-- Punkt auf dem Boden unter der Maus (fuer Faehigkeiten am PC)
function CameraController.MouseGround(): Vector3?
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return nil
	end
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	if math.abs(ray.Direction.Y) < 0.01 then
		return nil
	end
	local t = -ray.Origin.Y / ray.Direction.Y
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function unitAt(screen: Vector2): Model?
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local units = workspace:FindFirstChild("Units")
	local list = {}
	if units then
		table.insert(list, units)
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Character then
			table.insert(list, other.Character)
		end
	end
	params.FilterDescendantsInstances = list
	local result = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	local hit = result and result.Instance
	while hit and hit ~= workspace do
		if hit:IsA("Model") and CollectionService:HasTag(hit, "Unit") then
			return hit
		end
		hit = hit.Parent
	end
	-- Naechste Einheit in Bildschirmnaehe (Finger sind ungenau)
	local best, bestDistance = nil, 40
	for _, model in CollectionService:GetTagged("Unit") do
		if model:IsA("Model") and model ~= player.Character and model:GetAttribute("Team") ~= player:GetAttribute("Team") then
			local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local point, visible = camera:WorldToViewportPoint(root.Position)
				local distance = (Vector2.new(point.X, point.Y) - screen).Magnitude
				if visible and distance < bestDistance then
					best, bestDistance = model, distance
				end
			end
		end
	end
	return best
end

function CameraController.SetFocus(model: Model?)
	focusModel = model
	remotes.Focus:FireServer(model)
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
		ring.Size = Vector3.new(0.15, 6, 6)
		ring.Parent = workspace
		focusRing = ring
	end
end

function CameraController.Start()
	local camera = workspace.CurrentCamera
	local match = ReplicatedStorage:WaitForChild("Match")

	-- Zoom mit Mausrad oder zwei Fingern
	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom = math.clamp(zoom - input.Position.Z * 0.08, 0.65, 1.5)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
		if not processed and state == Enum.UserInputState.Change then
			zoom = math.clamp(zoom / (1 + (scale - 1) * 0.05), 0.65, 1.5)
		end
	end)

	-- Antippen / Klicken auf einen Gegner setzt den Fokus
	UserInputService.InputEnded:Connect(function(input, processed)
		if processed or classic then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local model = unitAt(Vector2.new(input.Position.X, input.Position.Y))
			if model and model:GetAttribute("Team") ~= player:GetAttribute("Team") then
				CameraController.SetFocus(model)
			end
		end
	end)

	local orbit = 0
	RunService:BindToRenderStep("MobaCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local phase = match:GetAttribute("Phase")
		local alive = root ~= nil and (phase == "Playing" or phase == "End")
		if focusModel and (not focusModel.Parent or (focusModel:GetAttribute("HP") or 0) <= 0) then
			CameraController.SetFocus(nil)
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
			local sign = teamSign()
			local target = Vector3.new(root.Position.X, 0, root.Position.Z) + Vector3.new(sign * 8, 0, 0)
			local offset = Vector3.new(-sign * 34, 62, 0) * zoom
			camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(target + offset, target), math.min(1, dt * 12))
			camera.FieldOfView = 60
		else
			-- Kamerafahrt ueber die Arena
			orbit += dt * 0.06
			local position = Vector3.new(math.cos(orbit) * 190, 120, math.sin(orbit) * 150)
			camera.CFrame = CFrame.lookAt(position, Vector3.new(0, 0, 0))
			camera.FieldOfView = 55
		end
	end)
end

return CameraController
