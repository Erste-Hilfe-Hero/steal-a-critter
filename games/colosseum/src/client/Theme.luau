-- Gemeinsamer Look fuer alle Oberflaechen: Farben, Schriften und kleine Bausteine.
-- Stil "Arena bei Nacht": dunkles Pflaumen-Braun, Goldkanten, Purpur-Knoepfe, cremefarbene Schrift.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BeastModel = require(ReplicatedStorage.Shared.BeastModel)

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(34, 24, 32),
	PanelLight = Color3.fromRGB(56, 40, 50),
	PanelDark = Color3.fromRGB(22, 15, 21),
	Gold = Color3.fromRGB(242, 193, 78),
	GoldDark = Color3.fromRGB(170, 115, 40),
	Crimson = Color3.fromRGB(168, 34, 48),
	CrimsonDark = Color3.fromRGB(110, 20, 32),
	Cream = Color3.fromRGB(250, 238, 215),
	Muted = Color3.fromRGB(185, 165, 155),
	Green = Color3.fromRGB(80, 185, 105),
	Blue = Color3.fromRGB(70, 140, 230),
	Red = Color3.fromRGB(230, 70, 70),
	Prism = Color3.fromRGB(150, 255, 245),
	Ink = Color3.fromRGB(20, 12, 18),
}
Theme.Title = Enum.Font.LuckiestGuy
Theme.Body = Enum.Font.BuilderSansBold
Theme.Heavy = Enum.Font.BuilderSansExtraBold

local C = Theme.Colors

function Theme.create(className: string, props): any
	local instance = Instance.new(className)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" and key ~= "Children" then
			(instance :: any)[key] = value
		end
	end
	for _, child in props.Children or {} do
		child.Parent = instance
	end
	if instance:IsA("GuiObject") and props.BorderSizePixel == nil then
		instance.BorderSizePixel = 0
	end
	instance.Parent = parent
	return instance
end
local create = Theme.create

function Theme.corner(parent: Instance, radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10), Parent = parent })
end

function Theme.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	return create("UIStroke", {
		Color = color or C.Gold,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Theme.textStroke(parent: Instance, thickness: number?)
	return create("UIStroke", { Color = C.Ink, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = parent })
end

function Theme.padding(parent: Instance, px: number)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

function Theme.gradient(parent: Instance, top: Color3, bottom: Color3)
	return create("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = 90, Parent = parent })
end

function Theme.label(props): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Body,
		TextColor3 = C.Cream,
		TextSize = 18,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return create("TextLabel", defaults)
end

-- Knopf mit Goldkante und Schatten. color = Grundfarbe.
function Theme.button(props): TextButton
	local color = props.Color or C.Crimson
	props.Color = nil
	local defaults = {
		BackgroundColor3 = color,
		AutoButtonColor = true,
		Font = Theme.Title,
		TextColor3 = C.Cream,
		TextSize = 20,
		Text = "",
		TextStrokeColor3 = C.Ink,
		TextStrokeTransparency = 0.35,
	}
	for key, value in props do
		defaults[key] = value
	end
	local button = create("TextButton", defaults)
	Theme.corner(button, 10)
	Theme.stroke(button, C.Gold, 2)
	Theme.gradient(button, Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
	return button
end

-- Dunkles Feld mit Goldrand
function Theme.panel(props): Frame
	local defaults = { BackgroundColor3 = C.Panel }
	for key, value in props do
		defaults[key] = value
	end
	local frame = create("Frame", defaults)
	Theme.corner(frame, 12)
	Theme.stroke(frame, C.Gold, 2, 0.15)
	Theme.gradient(frame, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 195, 200))
	return frame
end

-- Element-Abzeichen
function Theme.typeChip(typeName: string, props): TextLabel
	local defaults = {
		Size = UDim2.fromOffset(64, 20),
		BackgroundColor3 = Config.Types[typeName].Color,
		Text = typeName:upper(),
		Font = Theme.Heavy,
		TextSize = 13,
		TextColor3 = C.Ink,
		TextWrapped = false,
	}
	for key, value in props or {} do
		defaults[key] = value
	end
	local chip = create("TextLabel", defaults)
	Theme.corner(chip, 6)
	return chip
end

-- Lebensbalken. Gibt Rahmen und Fuellung zurueck.
function Theme.hpBar(props): (Frame, Frame)
	local defaults = { BackgroundColor3 = C.PanelDark }
	for key, value in props do
		defaults[key] = value
	end
	local back = create("Frame", defaults)
	Theme.corner(back, 6)
	Theme.stroke(back, C.Ink, 1.5)
	local fill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Green, Parent = back })
	Theme.corner(fill, 6)
	return back, fill
end

function Theme.setHp(fill: Frame, fraction: number)
	fraction = math.clamp(fraction, 0, 1)
	fill.Size = UDim2.fromScale(fraction, 1)
	fill.BackgroundColor3 = if fraction > 0.5 then C.Green elseif fraction > 0.2 then Color3.fromRGB(240, 190, 50) else C.Red
end

-- 3D-Vorschau einer Bestie (dreht sich langsam)
function Theme.viewport(beastId: string, level: number, shiny: boolean?, props): ViewportFrame
	local defaults = { BackgroundTransparency = 1, Ambient = Color3.fromRGB(200, 190, 190), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-1, -1, -1) }
	for key, value in props do
		defaults[key] = value
	end
	local viewport = create("ViewportFrame", defaults)
	local model = BeastModel.Build(beastId, level, shiny)
	model.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local size = model:GetExtentsSize()
	local distance = math.max(size.X, size.Y, size.Z) * 1.9
	local center = model:GetPivot().Position
	local angle = math.rad(200)
	local function place()
		camera.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(angle) * distance, distance * 0.3, math.cos(angle) * distance) * -1, center)
	end
	place()
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		if not viewport.Parent then
			connection:Disconnect()
			return
		end
		if viewport.Visible then
			angle += dt * 0.6
			place()
		end
	end)
	return viewport
end

-- Kleiner Kreis mit Element-Farbe und Anfangsbuchstaben (fuer Listen, spart Leistung)
function Theme.beastIcon(beastId: string, shiny: boolean?, props): Frame
	local def = Config.BeastsById[beastId]
	local defaults = { BackgroundColor3 = def.Color, Size = UDim2.fromOffset(44, 44) }
	for key, value in props or {} do
		defaults[key] = value
	end
	local icon = create("Frame", defaults)
	Theme.corner(icon, 100)
	Theme.stroke(icon, if shiny then C.Prism else Config.Types[def.Type].Color, 3)
	Theme.label({ Size = UDim2.fromScale(1, 1), Text = def.Name:sub(1, 1), Font = Theme.Title, TextScaled = true, TextColor3 = C.Cream, Parent = icon })
	return icon
end

return Theme
