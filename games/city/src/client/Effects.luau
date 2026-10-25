-- Welt-Effekte auf dem Client: Blaulicht, drehende Juwelen, Regenbogen-Lack, Strassenlaternen bei Nacht,
-- Prompts nur fuers passende Team, Fahndungs-Anzeige ueber Raeubern und der GPS-Marker.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local C = Config.Colors

local Effects = {
	MarkerPosition = nil :: Vector3?,
	MarkerLabel = nil :: string?,
	MarkerKind = nil :: string?,
	OnOpenUI = nil :: ((string) -> ())?,
	ShowPillar = true, -- Einstellung "GPS"
}

local MARKER_COLORS = {
	Delivery = C.Lemon,
	Race = C.Teal,
	Hideout = C.Green,
	Alarm = C.Robber,
	Truck = C.Lemon,
}
Effects.MarkerColors = MARKER_COLORS

local markerFolder = Instance.new("Folder")
markerFolder.Name = "LocalMarker"
markerFolder.Parent = workspace

local markerLabel: TextLabel? = nil
local markerToken = 0

function Effects.SetMarker(position: Vector3?, label: string?, kind: string?)
	markerFolder:ClearAllChildren()
	markerLabel = nil
	markerToken += 1
	Effects.MarkerPosition = position
	Effects.MarkerLabel = label
	Effects.MarkerKind = kind
	if not position then
		return
	end
	local color = MARKER_COLORS[kind or ""] or C.Lemon
	local pillar = Instance.new("Part")
	pillar.Anchored = true
	pillar.CanCollide = false
	pillar.CanQuery = false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = color
	pillar.Transparency = 0.45
	pillar.Size = Vector3.new(4, 160, 4)
	pillar.CFrame = CFrame.new(position + Vector3.new(0, 80, 0))
	pillar.Name = "Pillar"
	pillar.LocalTransparencyModifier = if Effects.ShowPillar then 0 else 1
	pillar.Parent = markerFolder
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.5
	ring.Size = Vector3.new(0.3, 30, 30)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = markerFolder
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(0, 14, 0)
	gui.LightInfluence = 0
	gui.Adornee = ring
	gui.Parent = ring
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.LuckiestGuy
	text.TextScaled = true
	text.TextColor3 = color
	text.Text = label or ""
	text.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Ink
	stroke.Thickness = 3
	stroke.Parent = text
	markerLabel = text
	if kind == "Alarm" then
		local token = markerToken
		task.delay(40, function()
			if markerToken == token then
				Effects.SetMarker(nil)
			end
		end)
	end
end

---------------------------------------------------------------- Prompts

local prompts = {} -- [ProximityPrompt] = original HoldDuration

local function updatePrompt(prompt: ProximityPrompt)
	local team = prompt:GetAttribute("Team")
	local owner = prompt:GetAttribute("Owner")
	local enabled = true
	if team and (not player.Team or player.Team.Name ~= team) then
		enabled = false
	end
	if owner and owner ~= player.UserId then
		enabled = false
	end
	local robbery = prompt.Parent and prompt.Parent:GetAttribute("Robbery")
	if robbery and workspace:GetAttribute("Closed_" .. robbery) then
		enabled = false
	end
	prompt.Enabled = enabled
	if robbery then
		prompt.HoldDuration = prompts[prompt] * (if player:GetAttribute("Pass_BigBag") then 0.5 else 1)
	end
end

local function track(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		prompts[instance] = instance.HoldDuration
		updatePrompt(instance)
		instance.Destroying:Connect(function()
			prompts[instance] = nil
		end)
	end
end

---------------------------------------------------------------- Fahndung

local wantedTags = {} -- [Player] = BillboardGui

local function updateWanted()
	local isCop = player.Team and player.Team.Name == "Police"
	for _, other in Players:GetPlayers() do
		local stars = other:GetAttribute("Wanted") or 0
		local head = other.Character and other.Character:FindFirstChild("Head") :: BasePart?
		local tag = wantedTags[other]
		if stars > 0 and head and other ~= player then
			if not tag or tag.Adornee ~= head then
				if tag then
					tag:Destroy()
				end
				local gui = Instance.new("BillboardGui")
				gui.Size = UDim2.fromOffset(160, 40)
				gui.StudsOffset = Vector3.new(0, 5.5, 0)
				gui.LightInfluence = 0
				gui.Adornee = head
				local label = Instance.new("TextLabel")
				label.Name = "Stars"
				label.Size = UDim2.fromScale(1, 1)
				label.BackgroundTransparency = 1
				label.Font = Enum.Font.LuckiestGuy
				label.TextScaled = true
				label.TextColor3 = C.Robber
				label.Parent = gui
				local stroke = Instance.new("UIStroke")
				stroke.Color = C.Ink
				stroke.Thickness = 3
				stroke.Parent = label
				gui.Parent = player:WaitForChild("PlayerGui")
				tag = gui
				wantedTags[other] = gui
			end
			assert(tag)
			tag.AlwaysOnTop = isCop == true
			tag.MaxDistance = if isCop then 900 else 90
			local label = tag:FindFirstChild("Stars") :: TextLabel
			label.Text = string.rep("★", stars) .. string.rep("☆", Config.MaxWanted - stars)
		elseif tag then
			tag:Destroy()
			wantedTags[other] = nil
		end
	end
	for other, tag in wantedTags do
		if not other.Parent then
			tag:Destroy()
			wantedTags[other] = nil
		end
	end
end

---------------------------------------------------------------- Start

function Effects.Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("Marker").OnClientEvent:Connect(Effects.SetMarker)

	for _, instance in workspace:GetDescendants() do
		track(instance)
	end
	workspace.DescendantAdded:Connect(track)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local ui = prompt:GetAttribute("OpenUI")
		if ui and Effects.OnOpenUI then
			Effects.OnOpenUI(ui)
		end
	end)

	task.spawn(function()
		while true do
			for prompt in prompts do
				updatePrompt(prompt)
			end
			updateWanted()
			-- Laternen nur nachts
			local night = Lighting.ClockTime < 6.4 or Lighting.ClockTime > 17.8
			for _, head in CollectionService:GetTagged("StreetLight") do
				local light = head:FindFirstChildOfClass("PointLight")
				if light then
					light.Enabled = night
				end
				(head :: BasePart).Material = if night then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
			-- Schon gefundene Turbo-Token nur fuer diesen Spieler ausblenden
			local found = {}
			for id in string.gmatch(player:GetAttribute("Tokens") or "", "[^,]+") do
				found[id] = true
			end
			for _, coin in CollectionService:GetTagged("TurboToken") do
				local taken = found[tostring(coin:GetAttribute("TokenId"))] == true
				(coin :: BasePart).LocalTransparencyModifier = if taken then 1 else 0
				local sparkle = coin:FindFirstChildOfClass("ParticleEmitter")
				if sparkle then
					sparkle.Enabled = not taken
				end
			end
			local pillar = markerFolder:FindFirstChild("Pillar") :: BasePart?
			if pillar then
				pillar.LocalTransparencyModifier = if Effects.ShowPillar then 0 else 1
			end
			task.wait(0.5)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for i, light in CollectionService:GetTagged("Siren") do
			(light :: BasePart).Transparency = if (math.floor(t * 6) + i) % 2 == 0 then 0 else 0.75
		end
		for _, part in CollectionService:GetTagged("Spin") do
			local p = part :: BasePart
			p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, dt * 1.6, 0) * p.CFrame.Rotation
		end
		-- Drehteller im Autohaus
		for _, part in CollectionService:GetTagged("SlowSpin") do
			local p = part :: BasePart
			p.CFrame = CFrame.new(p.Position) * CFrame.Angles(0, dt * 0.4, 0) * p.CFrame.Rotation
		end
		for _, part in CollectionService:GetTagged("Blink") do
			(part :: BasePart).Transparency = if math.floor(t * 1.5) % 2 == 0 then 0 else 0.7
		end
		local rainbow = Color3.fromHSV((t * 0.15) % 1, 0.75, 1)
		for _, part in CollectionService:GetTagged("Rainbow") do
			(part :: BasePart).Color = rainbow
			local light = part:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = rainbow
			end
		end
		for _, part in CollectionService:GetTagged("RainbowPaint") do
			(part :: BasePart).Color = rainbow
		end
		local offset = (t * 0.4) % 2 - 1
		for _, ui in CollectionService:GetTagged("Shimmer") do
			(ui :: UIGradient).Offset = Vector2.new(offset, 0)
		end
		-- Marker-Entfernung
		if markerLabel and Effects.MarkerPosition then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				markerLabel.Text = `{Effects.MarkerLabel or ""}\n{math.floor((root.Position - Effects.MarkerPosition).Magnitude)}m`
			end
		end
	end)
end

return Effects
