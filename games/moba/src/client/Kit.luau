-- Gemeinsame UI-Bausteine (Farben, Schriften, Knoepfe, Felder) fuer HUD und Steuerung.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Kit = {}


local INK = Color3.fromRGB(14, 18, 34)
local INK2 = Color3.fromRGB(28, 34, 58)
local INK3 = Color3.fromRGB(44, 52, 84)
local TEXT = Color3.fromRGB(246, 241, 232)
local MUTED = Color3.fromRGB(160, 168, 190)
local GOLD = Color3.fromRGB(255, 201, 74)
local CRYSTAL = Color3.fromRGB(120, 220, 255)
local GREEN = Color3.fromRGB(110, 231, 160)
local RED = Color3.fromRGB(255, 107, 107)
local ROBUX = Color3.fromRGB(64, 200, 110)
local TITLE = Enum.Font.LuckiestGuy
local BODY = Enum.Font.BuilderSansExtraBold
local SMALL = Enum.Font.BuilderSansBold

local function create(className: string, props, children: { Instance }?)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = instance
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

local function corner(radius: number)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function round()
	return create("UICorner", { CornerRadius = UDim.new(1, 0) })
end

local function line(transparency: number?, color: Color3?, thickness: number?)
	return create("UIStroke", { Color = color or Color3.new(1, 1, 1), Transparency = transparency or 0.82, Thickness = thickness or 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function text(props): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or BODY
	props.TextColor3 = props.TextColor3 or TEXT
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	local children = props.Children or {}
	props.Children = nil
	if props.Outline then
		table.insert(children, create("UIStroke", { Thickness = props.Outline, Color = Color3.fromRGB(10, 10, 20) }))
	end
	props.Outline = nil
	return create("TextLabel", props, children) :: TextLabel
end

local function panel(props): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or INK
	props.BackgroundTransparency = props.BackgroundTransparency or 0.08
	local children = props.Children or {}
	props.Children = nil
	table.insert(children, corner(props.Radius or 14))
	table.insert(children, line(0.85))
	table.insert(children, create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 215)) }))
	props.Radius = nil
	return create("Frame", props, children) :: Frame
end

local STYLES = {
	Gold = { Back = GOLD, Text = Color3.fromRGB(40, 26, 6) },
	Dark = { Back = INK3, Text = TEXT },
	Robux = { Back = ROBUX, Text = Color3.fromRGB(8, 34, 16) },
	Crystal = { Back = CRYSTAL, Text = Color3.fromRGB(8, 30, 44) },
	Red = { Back = RED, Text = Color3.fromRGB(50, 10, 10) },
}

local function button(props, style: string?): TextButton
	local s = STYLES[style or "Dark"]
	props.BackgroundColor3 = props.BackgroundColor3 or s.Back
	props.TextColor3 = props.TextColor3 or s.Text
	props.Font = props.Font or BODY
	props.TextScaled = true
	props.AutoButtonColor = true
	local scale = create("UIScale", {})
	local children = props.Children or {}
	props.Children = nil
	table.insert(children, corner(props.Radius or 10))
	table.insert(children, scale)
	table.insert(children, create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }))
	table.insert(children, create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }))
	table.insert(children, create("UITextSizeConstraint", { MaxTextSize = props.MaxText or 22 }))
	props.Radius = nil
	props.MaxText = nil
	local result = create("TextButton", props, children) :: TextButton
	result.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	result.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
	result.MouseLeave:Connect(function()
		scale.Scale = 1
	end)
	return result
end

local function teamColor(team: number?): Color3
	local info = Config.Teams[team or 0]
	return if info then info.Color else Config.NeutralColor
end


Kit.INK, Kit.INK2, Kit.INK3, Kit.TEXT, Kit.MUTED = INK, INK2, INK3, TEXT, MUTED
Kit.GOLD, Kit.CRYSTAL, Kit.GREEN, Kit.RED, Kit.ROBUX = GOLD, CRYSTAL, GREEN, RED, ROBUX
Kit.TITLE, Kit.BODY, Kit.SMALL = TITLE, BODY, SMALL
Kit.create, Kit.corner, Kit.round, Kit.line, Kit.text, Kit.panel, Kit.button, Kit.teamColor = create, corner, round, line, text, panel, button, teamColor

return Kit
