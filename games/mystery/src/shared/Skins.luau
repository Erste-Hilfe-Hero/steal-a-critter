-- Baut Messer, Blaster und Haustiere aus einfachen Teilen (keine fremden Assets).
-- Wird vom Server (Werkzeuge) und vom Client (Vorschau, Haustiere) benutzt.
local Config = require(script.Parent.Config)

local Skins = {}

local MATERIALS = {
	Glass = Enum.Material.Glass,
	Ice = Enum.Material.Ice,
	Foil = Enum.Material.Foil,
}

local function part(parent: Instance, props): BasePart
	local p = Instance.new(props.Class or "Part")
	props.Class = nil
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- Alle Teile an das Hauptteil schweissen (relative Lage bleibt erhalten)
local function weldAll(model: Model, root: BasePart)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") and child ~= root then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = child
			weld.Parent = child
		end
	end
end

local function particles(parent: BasePart, kind: string?, color: Color3)
	if not kind then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 14
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new(0.1, 1)
	if kind == "Fire" then
		emitter.Acceleration = Vector3.new(0, 4, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	elseif kind == "Stars" then
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Rotation = NumberRange.new(0, 360)
	end
	emitter.Parent = parent
end

local function glow(parent: BasePart, color: Color3?)
	if not color then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 6
	light.Brightness = 1.6
	light.Parent = parent
end

---------------------------------------------------------------- Messer

function Skins.Knife(id: string): Model
	local item = Config.GetItem("Knife", id) or Config.Knives[1]
	local model = Instance.new("Model")
	model.Name = "Knife"
	local handle = part(model, { Name = "Handle", Size = Vector3.new(0.32, 1.1, 0.32), Color = item.Handle, Shape = Enum.PartType.Block })
	handle.CFrame = CFrame.new()
	local bladeMaterial = if item.Neon then Enum.Material.Neon else (MATERIALS[item.Material or ""] or Enum.Material.Metal)
	local style = item.Style
	local bladeLength = if style == "Katana" then 3.2 elseif style == "Cleaver" then 1.8 else 2.2

	-- Griffkappe und Parierstange
	part(model, { Name = "Pommel", Size = Vector3.new(0.42, 0.22, 0.42), Color = item.Handle, CFrame = CFrame.new(0, -0.62, 0) })
	if style ~= "Candy" then
		part(model, { Name = "Guard", Size = Vector3.new(0.3, 0.16, if style == "Katana" then 0.6 else 0.9), Color = if item.Glow then item.Glow else Color3.fromRGB(70, 70, 80), Material = Enum.Material.Metal, CFrame = CFrame.new(0, 0.62, 0) })
	end

	if style == "Classic" or style == "Fang" or style == "Katana" then
		local width = if style == "Katana" then 0.34 else 0.5
		local blade = part(model, { Name = "Blade", Size = Vector3.new(0.1, bladeLength - 0.5, width), Color = item.Blade, Material = bladeMaterial, CFrame = CFrame.new(0, 0.7 + (bladeLength - 0.5) / 2, 0) })
		-- Spitze als Keil
		local tip = part(model, { Class = "WedgePart", Name = "Tip", Size = Vector3.new(0.1, 0.6, width), Color = item.Blade, Material = bladeMaterial })
		tip.CFrame = CFrame.new(0, 0.7 + bladeLength - 0.5 + 0.3, 0)
		if style == "Fang" then
			tip.Size = Vector3.new(0.1, 0.9, width)
			tip.CFrame = CFrame.new(0, 0.7 + bladeLength - 0.5 + 0.45, 0)
		end
		if style == "Katana" then
			blade.CFrame *= CFrame.Angles(0.06, 0, 0)
		end
		particles(blade, item.Particles, item.Glow or item.Blade)
		glow(blade, item.Glow)
	elseif style == "Cleaver" then
		local blade = part(model, { Name = "Blade", Size = Vector3.new(0.1, 1.4, 1.1), Color = item.Blade, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 1.4, 0.25) })
		part(model, { Name = "Hole", Class = "Part", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.22, 0.22), Color = Color3.fromRGB(30, 30, 30), CFrame = CFrame.new(0, 1.8, 0.55) })
		glow(blade, item.Glow)
	elseif style == "Round" then
		local blade = part(model, { Name = "Blade", Size = Vector3.new(0.1, 1.6, 0.42), Color = item.Blade, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 1.5, 0) })
		part(model, { Name = "Tip", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 0.42, 0.42), Color = item.Blade, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, 0) })
		glow(blade, item.Glow)
	elseif style == "Candy" then
		-- Rot-weiss gestreifter Stab mit Haken
		for i = 0, 7 do
			part(model, { Name = "Stripe" .. i, Size = Vector3.new(0.36, 0.3, 0.36), Color = if i % 2 == 0 then item.Blade else item.Handle, Material = if item.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 0.75 + i * 0.3, 0) * CFrame.Angles(0, i * 0.4, 0) })
		end
		local hook = part(model, { Name = "Blade", Size = Vector3.new(0.34, 0.34, 0.9), Color = item.Handle, CFrame = CFrame.new(0, 3.05, 0.35) })
		particles(hook, item.Particles, item.Glow or item.Blade)
		glow(hook, item.Glow)
	elseif style == "Moon" then
		-- Sichelfoermige Klinge aus mehreren Keilen
		local blade
		for i = 0, 5 do
			local a = i / 5 * math.rad(70)
			local seg = part(model, { Name = if i == 2 then "Blade" else "Moon" .. i, Size = Vector3.new(0.12, 0.5, 0.32), Color = item.Blade, Material = if item.Neon then Enum.Material.Neon else Enum.Material.Metal })
			seg.CFrame = CFrame.new(0, 0.9 + math.sin(a) * 1.6, -(1 - math.cos(a)) * 1.1) * CFrame.Angles(-a * 0.9, 0, 0)
			if i == 2 then
				blade = seg
			end
		end
		part(model, { Name = "Star", Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.34, 0.34), Color = item.Glow or item.Handle, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 0.62, 0) })
		particles(blade, item.Particles, item.Glow or item.Blade)
		glow(blade, item.Glow)
	end

	model.PrimaryPart = handle
	weldAll(model, handle)
	return model
end

---------------------------------------------------------------- Blaster

function Skins.Gun(id: string): Model
	local item = Config.GetItem("Gun", id) or Config.Guns[1]
	local model = Instance.new("Model")
	model.Name = "Gun"
	local material = MATERIALS[item.Material or ""] or Enum.Material.SmoothPlastic
	local handle = part(model, { Name = "Handle", Size = Vector3.new(0.3, 0.9, 0.42), Color = item.Body, Material = material })
	handle.CFrame = CFrame.new()
	local style = item.Style
	local body = part(model, { Name = "Body", Size = Vector3.new(0.36, 0.5, 1.1), Color = item.Body, Material = material, CFrame = CFrame.new(0, 0.55, -0.3) })
	local muzzleZ
	if style == "Revolver" then
		part(model, { Name = "Drum", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 0.52, 0.52), Color = item.Accent, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 0.55, -0.2) * CFrame.Angles(0, math.rad(90), 0) })
		part(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 0.22, 0.22), Color = item.Accent, Material = Enum.Material.Metal, CFrame = CFrame.new(0, 0.66, -1.3) * CFrame.Angles(0, math.rad(90), 0) })
		muzzleZ = -1.95
	elseif style == "Toy" then
		body.Size = Vector3.new(0.44, 0.6, 1.2)
		part(model, { Name = "Tank", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7), Color = item.Accent, Material = Enum.Material.Glass, Transparency = 0.2, CFrame = CFrame.new(0, 1.05, -0.2) })
		part(model, { Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 0.3, 0.3), Color = item.Accent, CFrame = CFrame.new(0, 0.6, -1.15) * CFrame.Angles(0, math.rad(90), 0) })
		muzzleZ = -1.55
	else -- Laser
		body.Size = Vector3.new(0.4, 0.55, 1.5)
		body.CFrame = CFrame.new(0, 0.55, -0.45)
		for i = 0, 2 do
			part(model, { Name = "Ring" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 0.5, 0.5), Color = item.Accent, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 0.55, -0.6 - i * 0.35) * CFrame.Angles(0, math.rad(90), 0) })
		end
		part(model, { Name = "Fin", Size = Vector3.new(0.08, 0.35, 0.7), Color = item.Accent, Material = if item.Neon then Enum.Material.Neon else Enum.Material.SmoothPlastic, CFrame = CFrame.new(0, 0.95, -0.3) })
		muzzleZ = -1.3
	end
	local muzzle = part(model, { Name = "Muzzle", Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1, CFrame = CFrame.new(0, 0.62, muzzleZ) })
	particles(muzzle, item.Particles, item.Beam)
	if item.Neon then
		glow(body, item.Beam)
	end
	model.PrimaryPart = handle
	weldAll(model, handle)
	return model
end

---------------------------------------------------------------- Haustiere (verankert, der Client bewegt sie)

local function eye(model: Model, at: CFrame, size: number)
	part(model, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), Color = Color3.fromRGB(20, 20, 30), CFrame = at })
	part(model, { Name = "Shine", Shape = Enum.PartType.Ball, Size = Vector3.new(size * 0.4, size * 0.4, size * 0.4), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CFrame = at * CFrame.new(size * 0.15, size * 0.15, -size * 0.35) })
end

function Skins.Pet(id: string): Model
	local item = Config.GetItem("Pet", id) or Config.Pets[1]
	local model = Instance.new("Model")
	model.Name = "Pet_" .. item.Id
	local color = item.Color
	local shape = item.Shape
	local bodyShape = if shape == "Pumpkin" or shape == "Moon" or shape == "Blob" or shape == "Ghost" then Enum.PartType.Ball else Enum.PartType.Ball
	local body = part(model, { Name = "Body", Shape = bodyShape, Size = Vector3.new(1.6, 1.5, 1.6), Color = color, Material = if shape == "Ghost" then Enum.Material.SmoothPlastic else Enum.Material.SmoothPlastic })
	body.CFrame = CFrame.new()
	if shape == "Ghost" then
		body.Transparency = 0.15
		body.Size = Vector3.new(1.5, 1.8, 1.5)
		for i = -1, 1 do
			part(model, { Name = "Tail", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), Color = color, Transparency = 0.15, CFrame = CFrame.new(i * 0.45, -0.85, 0) })
		end
	elseif shape == "Blob" then
		body.Size = Vector3.new(1.8, 1.3, 1.8)
		body.Material = Enum.Material.Glass
		body.Transparency = 0.2
	elseif shape == "Pumpkin" then
		body.Size = Vector3.new(1.9, 1.5, 1.9)
		part(model, { Name = "Stem", Size = Vector3.new(0.22, 0.45, 0.22), Color = Color3.fromRGB(60, 120, 40), CFrame = CFrame.new(0, 0.9, 0) })
		for i = 0, 3 do
			part(model, { Name = "Rib", Size = Vector3.new(0.12, 1.4, 1.95), Color = color:Lerp(Color3.new(0, 0, 0), 0.15), CFrame = CFrame.Angles(0, i * math.pi / 4, 0) })
		end
	elseif shape == "Bat" then
		for side = -1, 1, 2 do
			local wing = part(model, { Class = "WedgePart", Name = "Wing", Size = Vector3.new(0.1, 0.8, 1.4), Color = color:Lerp(Color3.new(0, 0, 0), 0.3) })
			wing.CFrame = CFrame.new(side * 1.2, 0.2, 0) * CFrame.Angles(0, math.rad(90 * side), math.rad(-20 * side))
		end
		for side = -1, 1, 2 do
			part(model, { Class = "WedgePart", Name = "Ear", Size = Vector3.new(0.1, 0.45, 0.35), Color = color, CFrame = CFrame.new(side * 0.4, 0.85, 0) })
		end
	elseif shape == "Owl" then
		part(model, { Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 0.6), Color = Color3.fromRGB(240, 220, 180), CFrame = CFrame.new(0, -0.15, -0.55) })
		part(model, { Class = "WedgePart", Name = "Beak", Size = Vector3.new(0.2, 0.3, 0.25), Color = Color3.fromRGB(255, 190, 40), CFrame = CFrame.new(0, 0.05, -0.85) * CFrame.Angles(math.rad(180), 0, 0) })
	elseif shape == "Fox" or shape == "Dragon" then
		body.Size = Vector3.new(1.4, 1.3, 1.7)
		for side = -1, 1, 2 do
			part(model, { Class = "WedgePart", Name = "Ear", Size = Vector3.new(0.15, 0.6, 0.45), Color = color, CFrame = CFrame.new(side * 0.4, 0.85, 0.1) })
		end
		part(model, { Name = "Tail", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 1.4), Color = if shape == "Fox" then Color3.new(1, 1, 1) else color, CFrame = CFrame.new(0, 0.1, 1.15) * CFrame.Angles(math.rad(25), 0, 0) })
		if shape == "Dragon" then
			for side = -1, 1, 2 do
				local wing = part(model, { Class = "WedgePart", Name = "Wing", Size = Vector3.new(0.1, 1.0, 1.4), Color = Color3.fromRGB(255, 200, 80), Material = Enum.Material.Neon })
				wing.CFrame = CFrame.new(side * 1.0, 0.5, 0.2) * CFrame.Angles(0, 0, math.rad(-35 * side))
			end
		end
	elseif shape == "Moon" then
		body.Material = Enum.Material.Neon
		part(model, { Name = "Crater", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.2), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), CFrame = CFrame.new(0.45, 0.35, -0.65) })
	end
	local eyeZ = -body.Size.Z / 2 + 0.08
	eye(model, CFrame.new(-0.32, 0.18, eyeZ), 0.32)
	eye(model, CFrame.new(0.32, 0.18, eyeZ), 0.32)
	if item.Glow then
		glow(body, color)
		particles(body, "Sparkles", color)
	end
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
		end
	end
	model.PrimaryPart = body
	model:ScaleTo(0.8)
	return model
end

-- Werkzeug fuer den Spieler (Messer oder Blaster)
function Skins.Tool(kind: string, id: string): Tool
	local model = if kind == "Knife" then Skins.Knife(id) else Skins.Gun(id)
	local tool = Instance.new("Tool")
	tool.Name = if kind == "Knife" then "Knife" else "Blaster"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = (Config.GetItem(kind, id) or {}).Name or tool.Name
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	tool:SetAttribute("Kind", kind)
	tool:SetAttribute("Skin", id)
	if kind == "Gun" then
		tool.Grip = CFrame.new(0, -0.1, 0.1)
	else
		tool.Grip = CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-20), 0, 0)
	end
	return tool
end

return Skins
