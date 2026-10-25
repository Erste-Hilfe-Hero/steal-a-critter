-- Client fuer die Plus-Features: Zielmarke im Tor beim Aufladen, "SHOOT!"-Hinweis, Super-Leiste, Trick (SKILL),
-- Speed- und Sprung-Pads, Landepunkt des Balls, Pass-Ziel, Ball leuchtet in der Farbe des letzten Teams,
-- grosser Countdown in den letzten 10 Sekunden, "BEHIND YOU!"-Warnung und Rueckmeldungen zu Schuessen.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local Plus = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ball = workspace:WaitForChild("Ball") :: BasePart
local carrierValue = ball:WaitForChild("Carrier") :: ObjectValue
local Kit = UI.Kit
local C = Config.Colors
local BODY = Config.BodyFont
local RADIUS = Config.BallSize / 2
local HALF_L = Config.FieldLength / 2

local remote: RemoteEvent
local hooks = {} :: any

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function myCharacter(): (Model?, BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return character, root
	end
	return nil, nil
end

local function myTeam(): string?
	return player:GetAttribute("Team")
end

local function enemyTeam(): string?
	local team = myTeam()
	return if team == "Blue" then "Red" elseif team == "Red" then "Blue" else nil
end

local function playing(): boolean
	return workspace:GetAttribute("MatchState") == "Playing"
end

-- Alle Actor-Modelle (Spieler und Bots)
local function actorModels(): { Model }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, model in bots:GetChildren() do
			if model:IsA("Model") then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function alive(model: Model): (BasePart?)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 and (model:GetAttribute("KOUntil") or 0) <= serverNow() then
		return root
	end
	return nil
end

local function marker(name: string, color: Color3, size: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.2, size, size)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.35
	part.Parent = nil
	return part
end

---------------------------------------------------------------- Zielmarke im Tor + "SHOOT!"-Hinweis

local aimMarker: Part
local shootHint: TextLabel

local function goalTarget(): Vector3?
	local _, root = myCharacter()
	local enemy = enemyTeam()
	if not root or not enemy then
		return nil
	end
	local goal = Vector3.new(Config.Teams[enemy].Side * HALF_L, Config.GroundY, 0)
	local keeperZ, best = nil, 25
	for _, model in actorModels() do
		if model:GetAttribute("Team") == enemy then
			local otherRoot = alive(model)
			if otherRoot then
				local offset = otherRoot.Position - goal
				local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if distance < best then
					keeperZ, best = otherRoot.Position.Z, distance
				end
			end
		end
	end
	return Config.ShotTarget(root.Position, hooks.AimDirection(), goal, keeperZ)
end

local function updateAim()
	local target = if hooks.Carrying() and playing() then goalTarget() else nil
	if target and hooks.IsCharging() then
		aimMarker.CFrame = CFrame.new(target) -- Zylinder-Achse X: Scheibe steht in der Torebene
		aimMarker.Transparency = 0.2 + 0.15 * math.sin(os.clock() * 12)
		aimMarker.Parent = workspace
	else
		aimMarker.Parent = nil
	end
	shootHint.Visible = target ~= nil and not hooks.IsCharging()
end

---------------------------------------------------------------- Super-Leiste

local superBar: Frame
local superLabel: TextLabel

local function updateSuper()
	local value = player:GetAttribute("Super") or 0
	local fraction = math.clamp(value / Config.SuperMax, 0, 1)
	superBar.Size = UDim2.fromScale(fraction, 1)
	local full = fraction >= 1
	superBar.BackgroundColor3 = if full then Color3.fromRGB(255, 120 + 80 * math.abs(math.sin(os.clock() * 6)), 30) else C.Orange
	superLabel.Text = if full then "SUPER SHOT READY - KICK!" else "SUPER"
end

---------------------------------------------------------------- Trick (SKILL)

local skillButton: TextButton? = nil
local skillReadyAt = 0

local function skill()
	local character, root = myCharacter()
	if not character or not root or not playing() or os.clock() < skillReadyAt then
		return
	end
	if (character:GetAttribute("KOUntil") or 0) > serverNow() or (character:GetAttribute("StunnedUntil") or 0) > serverNow() then
		return
	end
	skillReadyAt = os.clock() + Config.SkillCooldown
	local look = root.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z)
	if forward.Magnitude < 0.01 then
		return
	end
	forward = forward.Unit
	root.AssemblyLinearVelocity = forward * Config.SkillDash + Vector3.new(0, 10, 0)
	remote:FireServer("Skill")
	UI.Toast(if hooks.Carrying() then "SKILL MOVE! (can't be stolen)" else "DASH!", Color3.fromRGB(255, 120, 200))
end

local function updateSkillButton()
	if not skillButton then
		return
	end
	local left = skillReadyAt - os.clock()
	skillButton.Text = if left > 0 then tostring(math.ceil(left)) else "SKILL"
end

---------------------------------------------------------------- Pads (eigener Charakter)

local padCooldown = 0

local function checkPads()
	local _, root = myCharacter()
	if not root or os.clock() < padCooldown then
		return
	end
	local p = root.Position
	for _, position in Config.SpeedPads do
		if Vector3.new(p.X - position.X, 0, p.Z - position.Z).Magnitude < 5 and p.Y < Config.GroundY + 6 then
			padCooldown = os.clock() + 1
			-- gleiche Wirkung wie der Speed-Orb (die Laufgeschwindigkeit rechnet der Haupt-Client)
			player:SetAttribute("SpeedOrbUntil", math.max(player:GetAttribute("SpeedOrbUntil") or 0, serverNow() + Config.PadBoostSeconds))
			Sounds.Play("Quest")
			UI.Toast("SPEED BOOST!", C.Lime)
			return
		end
	end
	for _, position in Config.JumpPads do
		if Vector3.new(p.X - position.X, 0, p.Z - position.Z).Magnitude < 5 and p.Y < Config.GroundY + 6 then
			padCooldown = os.clock() + 1
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(v.X, Config.JumpPadVelocity, v.Z)
			Sounds.Play("Jump")
			return
		end
	end
end

---------------------------------------------------------------- Landepunkt, Pass-Ziel, Ball-Leuchten

local landMarker: Part
local passMarker: Part
local ballGlow: Highlight

local function updateLanding()
	if ball.Anchored or carrierValue.Value ~= nil then
		landMarker.Parent = nil
		return
	end
	local h = ball.Position.Y - (Config.GroundY + RADIUS)
	local v = ball.AssemblyLinearVelocity
	if h < 3 then
		landMarker.Parent = nil
		return
	end
	local g = workspace.Gravity
	local t = (v.Y + math.sqrt(math.max(0, v.Y * v.Y + 2 * g * h))) / g
	local spot = ball.Position + Vector3.new(v.X, 0, v.Z) * t
	landMarker.CFrame = CFrame.new(spot.X, Config.GroundY + 0.12, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
	landMarker.Parent = workspace
end

local function bestMate(root: BasePart): Model?
	local facing = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if facing.Magnitude < 0.01 then
		return nil
	end
	facing = facing.Unit
	local best, bestScore = nil, -math.huge
	for _, model in actorModels() do
		if model ~= player.Character and model:GetAttribute("Team") == myTeam() then
			local mateRoot = alive(model)
			if mateRoot then
				local offset = mateRoot.Position - root.Position
				local distance = offset.Magnitude
				local f = Vector3.new(offset.X, 0, offset.Z)
				if distance > 6 and distance < 110 and f.Magnitude > 0.01 then
					local dot = f.Unit:Dot(facing)
					local score = dot * 2 - distance / 60
					if dot > 0.2 and score > bestScore then
						best, bestScore = model, score
					end
				end
			end
		end
	end
	return best
end

local function updatePassTarget()
	local _, root = myCharacter()
	local mate = if root and hooks.Carrying() then bestMate(root) else nil
	local mateRoot = mate and mate:FindFirstChild("HumanoidRootPart") :: BasePart?
	if mateRoot then
		passMarker.CFrame = CFrame.new(mateRoot.Position.X, Config.GroundY + 0.14, mateRoot.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
		passMarker.Parent = workspace
	else
		passMarker.Parent = nil
	end
end

local function updateGlow()
	local team = ball:GetAttribute("LastTeam")
	local def = team and Config.Teams[team]
	ballGlow.Enabled = def ~= nil
	if def then
		ballGlow.OutlineColor = def.Color
	end
end

---------------------------------------------------------------- Letzte 10 Sekunden + "BEHIND YOU!"

local countdown: TextLabel
local lastShown = -1

local function updateCountdown()
	local left = workspace:GetAttribute("TimeLeft") or 999
	local show = playing() and not workspace:GetAttribute("GoldenGoal") and left <= 10 and left >= 1
	if show then
		if left ~= lastShown then
			lastShown = left
			countdown.Text = tostring(left)
			Kit.pop(countdown)
			Sounds.Play("Beep")
		end
	else
		lastShown = -1
	end
	countdown.Visible = show
end

local danger: TextLabel
local dangerUntil = 0
local nextDangerCheck = 0

local function updateDanger()
	local t = os.clock()
	danger.Visible = t < dangerUntil
	if t < nextDangerCheck then
		return
	end
	nextDangerCheck = t + 0.25
	local _, root = myCharacter()
	local enemy = enemyTeam()
	if not root or not enemy or not playing() then
		return
	end
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		return
	end
	look = look.Unit
	for _, model in actorModels() do
		if model:GetAttribute("Team") == enemy then
			local otherRoot = alive(model)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local f = Vector3.new(offset.X, 0, offset.Z)
				if f.Magnitude < 9 and f.Magnitude > 0.1 and f.Unit:Dot(look) < -0.35 then
					if t > dangerUntil + 2 then
						dangerUntil = t + 1.2
						Kit.pop(danger)
					end
					return
				end
			end
		end
	end
end

---------------------------------------------------------------- Aufbau

local function build()
	local root = UI.Root()
	aimMarker = marker("AimMarker", C.Lime, 4)
	shootHint = Kit.label({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -128), Size = UDim2.fromOffset(240, 34), Text = "SHOOT!  (aim at the goal)", TextColor3 = C.Lime, Visible = false, Parent = root })
	local superBack = Kit.create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(280, 14), BackgroundColor3 = C.Navy, Parent = root }, { Kit.corner(7), Kit.stroke(C.Navy, 2) })
	superBar = Kit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Orange, Parent = superBack }, { Kit.corner(7) })
	superLabel = Kit.label({ Size = UDim2.fromScale(1, 1), Text = "SUPER", Font = BODY, ZIndex = 2, Parent = superBack })
	landMarker = marker("LandingMarker", Color3.fromRGB(255, 255, 255), 5)
	passMarker = marker("PassMarker", C.Cyan, 6)
	ballGlow = Instance.new("Highlight")
	ballGlow.Name = "LastTouchGlow"
	ballGlow.FillTransparency = 1
	ballGlow.OutlineTransparency = 0.1
	ballGlow.DepthMode = Enum.HighlightDepthMode.Occluded
	ballGlow.Adornee = ball
	ballGlow.Parent = ball
	countdown = Kit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(200, 120), Text = "", TextColor3 = C.Red, Visible = false, Parent = root })
	danger = Kit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromOffset(260, 36), Text = "BEHIND YOU!", TextColor3 = C.Red, Visible = false, Parent = root })
	local touchGui = player:WaitForChild("PlayerGui"):FindFirstChild("TouchActions")
	skillButton = if touchGui then touchGui:FindFirstChild("Skill", true) :: TextButton? else nil
end

local function onEvent(kind: string, info)
	if kind == "Shot" then
		if info.Super then
			UI.Announce("SUPER SHOT!", C.Orange, 1.5)
		elseif info.OneTouch then
			UI.Toast("ONE-TOUCH SHOT! +25%", C.Cyan)
		end
	elseif kind == "Header" then
		UI.Toast("HEADER!", C.Cyan)
	elseif kind == "Stats" then
		task.delay(2.5, function()
			UI.Toast(info.Text, C.White)
		end)
	end
end

function Plus.Start(h)
	hooks = h
	remote = remotes:WaitForChild("Plus", 30) :: RemoteEvent
	build()
	if remote then
		remote.OnClientEvent:Connect(onEvent)
	end
	UI.BindAction("Skill", skill)
	ContextActionService:BindAction("TurboSkill", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			skill()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.X, Enum.KeyCode.ButtonL1)
	RunService.RenderStepped:Connect(function()
		updateAim()
		updateSuper()
		updateSkillButton()
		checkPads()
		updateLanding()
		updatePassTarget()
		updateGlow()
		updateCountdown()
		updateDanger()
	end)
end

return Plus
