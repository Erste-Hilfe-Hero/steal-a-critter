-- Client: Steuerung (Schuss aufladen, Pass, Tackling, Sprint mit Ausdauer), Laufgeschwindigkeit
-- aus den Skills, Tor-Effekte und Chat-Tags.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.UI)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ball = workspace:WaitForChild("Ball") :: Part
local carrierValue = ball:WaitForChild("Carrier") :: ObjectValue
local camera = workspace.CurrentCamera

UI.Start()

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function skill(id: string): number
	return player:GetAttribute("Skill_" .. id) or 0
end

local function getCharacter()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return character, humanoid, root
	end
	return nil, nil, nil
end

local function carrying(): boolean
	return player.Character ~= nil and carrierValue.Value == player.Character
end

local function stunned(): boolean
	local character = player.Character
	return character ~= nil and (character:GetAttribute("StunnedUntil") or 0) > serverNow()
end

---------------------------------------------------------------- Schiessen

local charging = false
local chargeStart = 0

local function aimDirection(): Vector3
	local look = camera.CFrame.LookVector
	local _, _, root = getCharacter()
	if Vector3.new(look.X, 0, look.Z).Magnitude < 0.2 and root then
		look = root.CFrame.LookVector
	end
	-- Kamera schaut meist leicht nach unten: nur ein Blick nach oben hebt den Ball zusaetzlich
	return Vector3.new(look.X, math.max(0, look.Y + 0.15), look.Z)
end

local function startCharge()
	if not carrying() or stunned() then
		return
	end
	charging = true
	chargeStart = os.clock()
end

local function releaseCharge()
	if not charging then
		return
	end
	charging = false
	UI.SetPower(nil)
	local power = math.clamp((os.clock() - chargeStart) / Config.ChargeTime, 0, 1)
	if carrying() then
		-- Kurvenball wie im Original: beim Schuss seitlich laufen gibt Effet in diese Richtung
		local _, humanoid = getCharacter()
		local spin = 0
		if humanoid then
			spin = humanoid.MoveDirection:Dot(camera.CFrame.RightVector)
		end
		remotes.Kick:FireServer(aimDirection(), power, spin)
	end
end

local function pass()
	if carrying() and not stunned() then
		remotes.Pass:FireServer()
	end
end

---------------------------------------------------------------- Tackling (kurzer Sprint nach vorne)

local dashUntil = 0
local dashVelocity: LinearVelocity? = nil

local function tackle()
	local _, humanoid, root = getCharacter()
	if not humanoid or not root or carrying() or stunned() then
		return
	end
	local state = workspace:GetAttribute("MatchState")
	if state ~= "Playing" then
		return
	end
	if (player:GetAttribute("TackleReadyAt") or 0) > serverNow() then
		UI.Toast("Disarm recharging...", Config.Colors.Orange)
		return
	end
	-- Lokale Sperre, bis der Server die neue Abklingzeit meldet
	player:SetAttribute("TackleReadyAt", serverNow() + Config.TackleCooldown(skill("Disarm")))
	remotes.Tackle:FireServer()
	local direction = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local attachment = root:FindFirstChild("RootAttachment") :: Attachment?
	if attachment then
		local velocity = Instance.new("LinearVelocity")
		velocity.Attachment0 = attachment
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis = Vector3.xAxis
		velocity.SecondaryTangentAxis = Vector3.zAxis
		velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * Config.DashSpeed
		velocity.MaxForce = 1e6
		velocity.Parent = root
		dashVelocity = velocity
		dashUntil = os.clock() + 0.25
		task.delay(0.25, function()
			velocity:Destroy()
			if dashVelocity == velocity then
				dashVelocity = nil
			end
		end)
	end
end

---------------------------------------------------------------- Sprint und Ausdauer

local sprintHeld = false -- Shift / Gamepad
local sprintToggle = false -- Touch-Button
local stamina = Config.MaxStamina(0)
local exhausted = false
local baseFov = 70

RunService.RenderStepped:Connect(function(dt)
	local character, humanoid = getCharacter()
	local maxStamina = Config.MaxStamina(skill("Stamina"))
	if charging then
		local power = math.clamp((os.clock() - chargeStart) / Config.ChargeTime, 0, 1)
		UI.SetPower(power)
		if not carrying() then
			charging = false
			UI.SetPower(nil)
		elseif os.clock() - chargeStart > Config.ChargeTime + 0.4 then
			releaseCharge() -- voll aufgeladen: automatisch schiessen
		end
	end
	UI.SetCarrying(carrying())
	if not character or not humanoid then
		return
	end
	local state = workspace:GetAttribute("MatchState")
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local wantsSprint = (sprintHeld or sprintToggle) and moving and not exhausted
	if wantsSprint then
		stamina = math.max(0, stamina - Config.StaminaDrain * dt)
		if stamina <= 0 then
			exhausted = true
		end
	else
		stamina = math.min(maxStamina, stamina + Config.StaminaRegen(skill("Stamina")) * dt)
		if exhausted and stamina > maxStamina * 0.25 then
			exhausted = false
		end
	end
	UI.SetStamina(stamina / maxStamina, exhausted)

	local speed = Config.WalkSpeed(skill("Agility"))
	if wantsSprint then
		speed *= Config.SprintFactor
	end
	if carrying() then
		speed *= Config.CarryFactor
	end
	if stunned() then
		speed = 3
	end
	if state == "Kickoff" then
		speed = 0
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = if state == "Kickoff" then 0 else 7.2
	camera.FieldOfView += ((if wantsSprint or os.clock() < dashUntil then baseFov + 8 else baseFov) - camera.FieldOfView) * math.min(1, dt * 8)
end)

---------------------------------------------------------------- Eingaben

ContextActionService:BindAction("TurboSprint", function(_, inputState)
	sprintHeld = inputState == Enum.UserInputState.Begin
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.R, Enum.KeyCode.ButtonL2)

ContextActionService:BindAction("TurboPass", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		pass()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonX)

ContextActionService:BindAction("TurboTackle", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		tackle()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

ContextActionService:BindAction("TurboShoot", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		startCharge()
	elseif inputState == Enum.UserInputState.End then
		releaseCharge()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)

-- Maus: halten = Schuss aufladen (mit Ball), Klick ohne Ball = Tackling
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or UI.IsTouch then
		return
	end
	if carrying() then
		startCharge()
	else
		tackle()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		releaseCharge()
	end
end)

UI.BindAction("Shoot", startCharge, releaseCharge)
UI.BindAction("Pass", pass)
UI.BindAction("Tackle", tackle)
UI.BindAction("Sprint", function()
	sprintToggle = not sprintToggle
	UI.SetSprintOn(sprintToggle)
end)

player.CharacterAdded:Connect(function()
	charging = false
	stamina = Config.MaxStamina(skill("Stamina"))
	exhausted = false
	UI.SetPower(nil)
end)

-- Umgehauen (Smack oder Maskottchen): hinfallen und wegfliegen, kein Schaden
remotes.Knockback.OnClientEvent:Connect(function(velocity: Vector3)
	local _, humanoid, root = getCharacter()
	if humanoid and root then
		charging = false
		UI.SetPower(nil)
		humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
		root.AssemblyLinearVelocity = velocity
	end
end)

---------------------------------------------------------------- Spielereignisse

local function shake(strength: number, duration: number)
	local ends = os.clock() + duration
	local connection
	connection = RunService.RenderStepped:Connect(function()
		if os.clock() > ends then
			connection:Disconnect()
			return
		end
		local f = strength * (ends - os.clock()) / duration
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * f), math.rad((math.random() - 0.5) * f), 0)
	end)
end

remotes.MatchEvent.OnClientEvent:Connect(function(kind, info)
	if kind == "Goal" then
		UI.ShowGoal(info)
		shake(1.2, 0.6)
	elseif kind == "Ended" then
		local text = if info.Winner then `{string.upper(info.Winner)} WIN {math.max(info.Blue, info.Red)}-{math.min(info.Blue, info.Red)}!` else `DRAW {info.Blue}-{info.Red}`
		UI.Announce(text, if info.Winner then Config.Teams[info.Winner].Color else Config.Colors.White, 5)
	elseif kind == "EXP" then
		UI.EXPPopup(info.Amount, info.Kind)
	elseif kind == "LevelUp" then
		shake(0.4, 0.3)
	elseif kind == "Fireworks" then
		shake(0.3, 1.5)
	end
end)

workspace:GetAttributeChangedSignal("MatchState"):Connect(function()
	if workspace:GetAttribute("MatchState") == "Kickoff" then
		UI.HideResults()
	end
end)

-- Wer den Ball hat, bekommt einen leuchtenden Rahmen in der Teamfarbe
local carrierHighlight = Instance.new("Highlight")
carrierHighlight.FillTransparency = 0.85
carrierHighlight.OutlineTransparency = 0
carrierHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
local function updateCarrier()
	local model = carrierValue.Value
	if model then
		local team = model:GetAttribute("Team")
		local color = if team then Config.Teams[team].Color else Config.Colors.Lime
		carrierHighlight.OutlineColor = color
		carrierHighlight.FillColor = color
		carrierHighlight.Adornee = model
		carrierHighlight.Parent = model
	else
		carrierHighlight.Adornee = nil
		carrierHighlight.Parent = nil
	end
end
carrierValue.Changed:Connect(updateCarrier)
updateCarrier()

---------------------------------------------------------------- Chat-Tags

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender then
		local prefix = message.PrefixText
		local team = sender:GetAttribute("Team")
		if team then
			local color = Config.Teams[team].Color
			prefix = string.format('<font color="#%s">[%s]</font> %s', color:ToHex(), string.upper(team), prefix)
		end
		if sender:GetAttribute("Pass_VIP") then
			prefix = `<font color="#FFCD32">[VIP]</font> {prefix}`
		end
		properties.PrefixText = prefix
	end
	return properties
end
