-- Kleine Bau-Helfer fuer Stadt, Haeuser und Autos (alles aus Parts, keine fremden Assets).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Build = {}

local INK = Config.Colors.Ink

-- Verankertes Part mit Eigenschaften
function Build.Part(parent: Instance, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Block mit Unterkante auf y = 0 relativ zu cf (cf zeigt mit LookVector nach "vorn")
function Build.Box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local part = Build.Part(parent, {
		Size = size,
		CFrame = cf * CFrame.new(0, size.Y / 2, 0),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	return part
end

function Build.Wedge(parent: Instance, cf: CFrame, size: Vector3, color: Color3): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cf
	wedge.Color = color
	wedge.Material = Enum.Material.SmoothPlastic
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = parent
	return wedge
end

-- Schild mit Comic-Schrift auf einer Seite eines Parts
function Build.Sign(part: BasePart, text: string, background: Color3, textColor: Color3, face: Enum.NormalId?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 24
	gui.LightInfluence = 0
	gui.Parent = part
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = background
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 6
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = frame
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = INK
	textStroke.Thickness = 3
	textStroke.Parent = label
	return gui
end

-- Schwebende Beschriftung (z. B. ueber Haeusern)
function Build.Billboard(adornee: BasePart, text: string, color: Color3, offsetY: number, maxDistance: number?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 160
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = label
	return label
end

function Build.Tree(parent: Instance, position: Vector3, rng: Random)
	local height = rng:NextNumber(9, 15)
	Build.Part(parent, {
		Size = Vector3.new(height, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(130, 85, 55),
	})
	local leafColor = Color3.fromHSV(rng:NextNumber(0.25, 0.36), 0.6, rng:NextNumber(0.6, 0.8))
	for i = 1, 3 do
		local radius = rng:NextNumber(5, 7.5) - i * 0.8
		Build.Part(parent, {
			Size = Vector3.one * radius * 2,
			Shape = Enum.PartType.Ball,
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1.5, 1.5), height + i * 2.5, rng:NextNumber(-1.5, 1.5))),
			Color = leafColor,
			CanCollide = false,
		})
	end
end

function Build.Lamp(parent: Instance, position: Vector3, facing: Vector3)
	local pole = Build.Part(parent, {
		Size = Vector3.new(0.8, 16, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 8, 0)),
		Color = INK,
	})
	local arm = Build.Part(parent, {
		Size = Vector3.new(0.6, 0.6, 5),
		CFrame = CFrame.lookAt(position + Vector3.new(0, 15.7, 0) + facing * 2.2, position + Vector3.new(0, 15.7, 0) + facing * 5),
		Color = INK,
		CanCollide = false,
	})
	local head = Build.Part(parent, {
		Size = Vector3.new(2.2, 0.7, 2.2),
		CFrame = CFrame.new(position + Vector3.new(0, 15.2, 0) + facing * 4.5),
		Color = Color3.fromRGB(255, 225, 160),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Range = 28
	light.Brightness = 1.4
	light.Color = Color3.fromRGB(255, 210, 150)
	light.Parent = head
	head:AddTag("StreetLight")
	return pole, arm, head
end

-- Gebaeude mit Fensterbaendern auf allen vier Seiten
function Build.Tower(parent: Instance, cf: CFrame, size: Vector3, color: Color3, windowColor: Color3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "Building"
	model.Parent = parent
	Build.Box(model, cf, size, color)
	local floorHeight = 10
	local y = 6
	while y + 4 < size.Y - 3 do
		for _, side in { 1, -1 } do
			Build.Part(model, {
				Size = Vector3.new(size.X - 3, 4.2, 0.4),
				CFrame = cf * CFrame.new(0, y + 2, side * (size.Z / 2 + 0.15)),
				Color = windowColor,
				Material = Enum.Material.Glass,
				Reflectance = 0.15,
				CanCollide = false,
			})
			Build.Part(model, {
				Size = Vector3.new(0.4, 4.2, size.Z - 3),
				CFrame = cf * CFrame.new(side * (size.X / 2 + 0.15), y + 2, 0),
				Color = windowColor,
				Material = Enum.Material.Glass,
				Reflectance = 0.15,
				CanCollide = false,
			})
		end
		y += floorHeight
	end
	-- Dachkante und Technik
	Build.Box(model, cf * CFrame.new(0, size.Y, 0), Vector3.new(size.X + 1, 1.2, size.Z + 1), Config.Colors.Ink)
	for _ = 1, rng:NextInteger(1, 3) do
		local box = Vector3.new(rng:NextNumber(4, 9), rng:NextNumber(2, 5), rng:NextNumber(4, 9))
		Build.Box(model, cf * CFrame.new(rng:NextNumber(-size.X / 4, size.X / 4), size.Y + 1.2, rng:NextNumber(-size.Z / 4, size.Z / 4)), box, Color3.fromRGB(200, 200, 210))
	end
	if size.Y > 110 then
		Build.Box(model, cf * CFrame.new(0, size.Y + 1.2, 0), Vector3.new(0.8, 22, 0.8), Color3.fromRGB(220, 220, 230))
		local tip = Build.Part(model, {
			Size = Vector3.one * 1.6,
			Shape = Enum.PartType.Ball,
			CFrame = cf * CFrame.new(0, size.Y + 24, 0),
			Color = Config.Colors.Pink,
			Material = Enum.Material.Neon,
		})
		tip:AddTag("Blink")
	end
	return model
end

return Build
