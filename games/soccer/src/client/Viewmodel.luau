-- Ego-Perspektive wie im Original: rechter Arm mit Messer vor der Kamera, wippt beim Laufen,
-- Slash schwingt quer durchs Bild, Stab stoesst nach vorne. Nur sichtbar in der Ego-Sicht.
local Players = game:GetService("Players")

local Viewmodel = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local model = Instance.new("Model")
model.Name = "KnifeViewmodel"
local arm = part("Arm", Vector3.new(0.42, 0.42, 1.7), Color3.fromRGB(234, 184, 146))
local sleeve = part("Sleeve", Vector3.new(0.48, 0.48, 0.8), Color3.fromRGB(40, 60, 140))
local hand = part("Hand", Vector3.new(0.44, 0.5, 0.42), Color3.fromRGB(234, 184, 146))
local grip = part("Grip", Vector3.new(0.14, 0.16, 0.55), Color3.fromRGB(35, 35, 40))
local guard = part("Guard", Vector3.new(0.1, 0.36, 0.06), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
local blade = part("Blade", Vector3.new(0.04, 0.2, 0.95), Color3.fromRGB(205, 210, 220), Enum.Material.Metal)
local tip = Instance.new("WedgePart")
tip.Name = "Tip"
tip.Size = Vector3.new(0.04, 0.2, 0.25)
tip.Color = blade.Color
tip.Material = Enum.Material.Metal
tip.Anchored = true
tip.CanCollide = false
tip.CanQuery = false
tip.CanTouch = false
tip.CastShadow = false
for _, p in { arm, sleeve, hand, grip, guard, blade, tip } do
	p.Parent = model
end

-- Lage der Teile relativ zur Hand (Hand = Ursprung, -Z = nach vorne)
local LAYOUT = {
	[arm] = CFrame.new(0, 0, 0.95),
	[sleeve] = CFrame.new(0, 0, 1.55),
	[hand] = CFrame.new(),
	[grip] = CFrame.new(0, 0.1, -0.15),
	[guard] = CFrame.new(0, 0.1, -0.45),
	[blade] = CFrame.new(0, 0.12, -0.95),
	[tip] = CFrame.new(0, 0.12, -1.55) * CFrame.Angles(0, math.pi, 0),
}

local REST = CFrame.new(0.85, -0.8, -1.35) * CFrame.Angles(math.rad(6), math.rad(8), math.rad(-12))

local swingKind: string? = nil
local swingStart = 0
local SWING_TIME = { Slash = 0.28, Stab = 0.42 }
local bobTime = 0
local shown = false

function Viewmodel.Swing(kind: string)
	swingKind = kind
	swingStart = os.clock()
end

function Viewmodel.SetSleeveColor(color: Color3)
	sleeve.Color = color
end

local function swingOffset(): CFrame
	if not swingKind then
		return CFrame.new()
	end
	local t = (os.clock() - swingStart) / SWING_TIME[swingKind]
	if t >= 1 then
		swingKind = nil
		return CFrame.new()
	end
	if swingKind == "Slash" then
		-- von rechts oben quer nach links unten
		local a = math.sin(t * math.pi)
		local sweep = -1 + 2 * t
		return CFrame.new(-0.9 * a, 0.15 * a, -0.2 * a) * CFrame.Angles(0, math.rad(55 * sweep * a), math.rad(-70 * a))
	end
	-- Stab: kurz ausholen, dann nach vorne stossen
	local windup = math.clamp(t / 0.45, 0, 1)
	local thrust = math.clamp((t - 0.45) / 0.25, 0, 1)
	local back = math.clamp((t - 0.7) / 0.3, 0, 1)
	local z = 0.35 * windup - 1.2 * thrust * (1 - back) - 0.35 * windup * thrust
	return CFrame.new(-0.35 * thrust * (1 - back), 0.25 * windup * (1 - thrust), z) * CFrame.Angles(math.rad(-15 * windup), 0, 0)
end

-- visible: Ego-Sicht aktiv, lebendig und nicht K.O.
function Viewmodel.Update(dt: number, visible: boolean, moving: number)
	if visible ~= shown then
		shown = visible
		model.Parent = if visible then camera else nil
	end
	if not visible then
		return
	end
	bobTime += dt * (4 + moving * 6)
	local bob = CFrame.new(math.sin(bobTime) * 0.05 * moving, math.abs(math.cos(bobTime)) * 0.06 * moving, 0)
	local handCFrame = camera.CFrame * REST * bob * swingOffset()
	for p, offset in LAYOUT do
		p.CFrame = handCFrame * offset
	end
end

-- Ego-Sicht: Kamera sitzt im Kopf
function Viewmodel.FirstPerson(): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	return head ~= nil and (camera.CFrame.Position - head.Position).Magnitude < 1.5
end

return Viewmodel
