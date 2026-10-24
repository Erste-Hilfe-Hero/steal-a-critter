-- Startpunkt des Clients: Kart-Steuerung, Oberflaeche und kleine Animationen in der Welt.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local KartController = require(script.KartController)
local UI = require(script.UI)

KartController.Init()
UI.Init(KartController)

-- Drehende Item-Boxen und Muenzen, Regenbogen-Boxen, pulsierende Boost-Pads, Drehteller im Showroom
local spinBase: { [BasePart]: CFrame } = {}
local turnBase: { [Model]: CFrame } = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, part in CollectionService:GetTagged("Spin") do
		if part:IsA("BasePart") then
			if not spinBase[part] or not part.Parent then
				spinBase[part] = part.CFrame
			end
			local base = spinBase[part]
			part.CFrame = CFrame.new(base.Position + Vector3.new(0, math.sin(t * 2 + base.X) * 0.4, 0)) * CFrame.Angles(0, t * 2, 0) * base.Rotation
			local core = part:FindFirstChild("Core")
			if core and core:IsA("BasePart") then
				core.CFrame = part.CFrame * CFrame.Angles(t, t * 1.3, 0)
			end
		end
	end
	for _, part in CollectionService:GetTagged("Rainbow") do
		if part:IsA("BasePart") then
			part.Color = Color3.fromHSV((t * 0.25 + part.Position.X * 0.01) % 1, 0.55, 1)
		end
	end
	for _, part in CollectionService:GetTagged("Pulse") do
		if part:IsA("BasePart") then
			part.Transparency = 0.15 + (math.sin(t * 6) + 1) * 0.15
		end
	end
	for _, model in CollectionService:GetTagged("Turntable") do
		if model:IsA("Model") then
			if not turnBase[model] then
				turnBase[model] = model:GetPivot()
			end
			model:PivotTo(turnBase[model] * CFrame.Angles(0, t * 0.6, 0))
		end
	end
end)
CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(part)
	spinBase[part :: BasePart] = nil
end)
