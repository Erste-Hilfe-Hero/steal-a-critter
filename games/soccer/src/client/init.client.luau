-- Client: Steuerung (Schuss aufladen, Pass, Messer, Sprint mit Ausdauer, Weitsprung, Pass fordern),
-- Ego-Perspektive mit Messer, Laufgeschwindigkeit aus den Skills, Tor-Effekte, Sprecher und Chat-Tags.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Extras = require(script.Extras)
local Sounds = require(script.Sounds)
local UI = require(script.UI)
local Viewmodel = require(script.Viewmodel)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ball = workspace:WaitForChild("Ball") :: Part
local carrierValue = ball:WaitForChild("Carrier") :: ObjectValue
local camera = workspace.CurrentCamera

-- Fehlersuche: Client-Fehler und Schwert-Statistik an den Server melden (landet im Diag-DataStore)
local clientLog = remotes:WaitForChild("ClientLog", 10) :: RemoteEvent?
local knifeStats = {}
local function countKnife(what: string)
	knifeStats[what] = (knifeStats[what] or 0) + 1
end
if clientLog then
	game:GetService("ScriptContext").Error:Connect(function(message, trace)
		clientLog:FireServer("error: " .. message .. " | " .. string.sub(trace or "", 1, 200))
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			if next(knifeStats) then
				local parts = {}
				for key, value in knifeStats do
					table.insert(parts, key .. "=" .. value)
				end
				table.sort(parts)
				clientLog:FireServer("knife: " .. table.concat(parts, " ") .. (if UI.IsTouch then " touch" else " pc"))
				table.clear(knifeStats)
			end
		end
	end)
end

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

---------------------------------------------------------------- Messer (wie im Original: man wird dabei nicht schneller)

-- KNIFE: schneller Slash; trifft er den Ballfuehrer, kann er den Ball verlieren (Disarm-Upgrade)
local function knife()
	countKnife("pressed")
	if carrying() or stunned() or workspace:GetAttribute("MatchState") ~= "Playing" then
		countKnife(if carrying() then "carrying" elseif stunned() then "stunned" else "state_" .. tostring(workspace:GetAttribute("MatchState")))
		return
	end
	if (player:GetAttribute("KnifeReadyAt") or 0) > serverNow() then
		countKnife("cooldown")
		return
	end
	countKnife("sent")
	player:SetAttribute("KnifeReadyAt", serverNow() + Config.Knife.Slash.Cooldown)
	remotes.Tackle:FireServer(camera.CFrame.LookVector)
	Viewmodel.Swing("Slash")
end

-- STAB: starker Stich, von hinten fast immer ein K.O.
local function stab()
	if carrying() or stunned() or workspace:GetAttribute("MatchState") ~= "Playing" then
		return
	end
	if (player:GetAttribute("KnifeReadyAt") or 0) > serverNow() then
		return
	end
	player:SetAttribute("KnifeReadyAt", serverNow() + Config.Knife.Stab.Cooldown * (if Config.Has(player, "Ninja") then Config.NinjaStabCooldown else 1))
	remotes.Stab:FireServer(camera.CFrame.LookVector)
	Viewmodel.Swing("Stab")
end

local toggleView: () -> ()
local callPass: () -> ()

local function knockedOut(): boolean
	local character = player.Character
	return character ~= nil and (character:GetAttribute("KOUntil") or 0) > serverNow()
end

---------------------------------------------------------------- Ego-Perspektive (wie im Original), mit V umschaltbar

local firstPerson = true

local function applyView()
	if firstPerson then
		player.CameraMinZoomDistance = 0.5
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 10
		player.CameraMaxZoomDistance = 30
		-- danach wieder frei zoomen lassen
		task.delay(0.3, function()
			if not firstPerson then
				player.CameraMinZoomDistance = 6
			end
		end)
	end
	UI.SetCrosshair(firstPerson)
end

toggleView = function()
	firstPerson = not firstPerson
	applyView()
	UI.Toast(if firstPerson then "First person view" else "Third person view", Config.Colors.Lime)
end

-- Pass fordern wie im Original (ALT): "!" ueber dem eigenen Kopf
callPass = function()
	if not carrying() then
		remotes.CallPass:FireServer()
	end
end

-- Weitsprung wie im Original: seitlich laufen und springen = doppelt so weit, alle 5 Sekunden
local longJumpReadyAt = 0
local function hookLongJump(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.StateChanged:Connect(function(_, new)
		if new ~= Enum.HumanoidStateType.Jumping or os.clock() < longJumpReadyAt or carrying() then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local move = humanoid.MoveDirection
		if not root or move.Magnitude < 0.5 or math.abs(move:Dot(camera.CFrame.RightVector)) < 0.6 then
			return
		end
		longJumpReadyAt = os.clock() + Config.LongJumpCooldown
		task.defer(function()
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(move.X * humanoid.WalkSpeed * 2, v.Y, move.Z * humanoid.WalkSpeed * 2)
		end)
		Sounds.Play("Jump", root.Position)
	end)
end

---------------------------------------------------------------- Sprint und Ausdauer

local sprintHeld = false -- Shift / Gamepad
local sprintToggle = false -- Touch-Button
local stamina = Config.MaxStamina(0)
local exhausted = false
local baseFov = 70

RunService.RenderStepped:Connect(function(dt)
	local character, humanoid = getCharacter()
	local lungs = if Config.Has(player, "TurboLungs") then Config.TurboLungsFactor else 1
	local maxStamina = Config.MaxStamina(skill("Stamina")) * lungs
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
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		Config.SlideOffHeads(character, root)
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
		stamina = math.min(maxStamina, stamina + Config.StaminaRegen(skill("Stamina")) * lungs * dt)
		if exhausted and stamina > maxStamina * 0.25 then
			exhausted = false
		end
	end
	UI.SetStamina(stamina / maxStamina, exhausted)

	local speed = Config.WalkSpeed(skill("Agility"))
	if Config.Has(player, "SpeedDemon") then
		speed *= Config.SpeedDemonFactor
	end
	if Config.Active(player, "RageUntil") then
		speed *= Config.RageFactor
	end
	-- Team Boost (Produkt eines Mitspielers): ganzes Team schneller
	if (workspace:GetAttribute("TeamBoostUntil_" .. (player:GetAttribute("Team") or "")) or 0) > serverNow() then
		speed *= Config.TeamBoostFactor
	end
	-- Speed-Orb vom Feld und Spielmodus "Turbo"
	if (player:GetAttribute("SpeedOrbUntil") or 0) > serverNow() then
		speed *= Config.SpeedOrbFactor
	end
	speed *= workspace:GetAttribute("ModeSpeed") or 1
	if wantsSprint then
		speed *= Config.SprintFactor
	end
	if carrying() then
		speed *= Config.CarryFactor
	end
	if stunned() then
		speed = 3
	end
	-- K.O.: liegen bleiben, bis man an der Startposition wieder aufsteht
	local ko = knockedOut()
	if ko then
		speed = 0
	end
	if humanoid.PlatformStand ~= ko then
		humanoid.PlatformStand = ko
	end
	if state == "Kickoff" then
		speed = 0
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpHeight = if state == "Kickoff" then 0 else 7.2
	camera.FieldOfView += ((if wantsSprint then baseFov + 8 else baseFov) - camera.FieldOfView) * math.min(1, dt * 8)
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

ContextActionService:BindAction("TurboKnife", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		knife()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)

ContextActionService:BindAction("TurboCallPass", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		callPass()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.T, Enum.KeyCode.LeftAlt, Enum.KeyCode.DPadUp)

ContextActionService:BindAction("TurboView", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		toggleView()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.V, Enum.KeyCode.ButtonSelect)

ContextActionService:BindAction("TurboStab", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		stab()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.G, Enum.KeyCode.ButtonY)

ContextActionService:BindAction("TurboShoot", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		startCharge()
	elseif inputState == Enum.UserInputState.End then
		releaseCharge()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonR2)

-- Maus: halten = Schuss aufladen (mit Ball), Klick ohne Ball = Messer
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.UserInputType == Enum.UserInputType.MouseButton2 and not UI.IsTouch then
		stab()
		return
	end
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or UI.IsTouch then
		return
	end
	if carrying() then
		startCharge()
	else
		knife()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		releaseCharge()
	end
end)

UI.BindAction("Shoot", startCharge, releaseCharge)
UI.BindAction("Pass", pass)
UI.BindAction("Tackle", knife)
UI.BindAction("Call", callPass)
UI.BindAction("View", toggleView)
UI.BindAction("Stab", stab)
UI.BindAction("Sprint", function()
	sprintToggle = not sprintToggle
	UI.SetSprintOn(sprintToggle)
end)

player.CharacterAdded:Connect(function(character)
	hookLongJump(character)
	applyView()
	charging = false
	stamina = Config.MaxStamina(skill("Stamina"))
	exhausted = false
	UI.SetPower(nil)
end)

if player.Character then
	hookLongJump(player.Character)
end
applyView()


local function styleViewmodel()
	local team = Config.Teams[player:GetAttribute("Team") or ""]
	local skin = Config.SwordSkinsById[player:GetAttribute("SwordSkin") or "classic"]
	Viewmodel.SetStyle(if team then team.Color else Color3.fromRGB(40, 60, 140), player:GetAttribute("Pass_GoldenKnife") == true, skin and skin.Color, skin and skin.Material)
end
player:GetAttributeChangedSignal("Team"):Connect(styleViewmodel)
player:GetAttributeChangedSignal("Pass_GoldenKnife"):Connect(styleViewmodel)
player:GetAttributeChangedSignal("SwordSkin"):Connect(styleViewmodel)
styleViewmodel()

-- Messer vor der Kamera, nach der Kamera aktualisiert
RunService:BindToRenderStep("KnifeViewmodel", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local _, humanoid = getCharacter()
	local visible = humanoid ~= nil and not knockedOut() and Viewmodel.FirstPerson()
	local moving = if humanoid then math.clamp(humanoid.MoveDirection.Magnitude, 0, 1) else 0
	Viewmodel.Update(dt, visible, moving)
end)

-- Eigenes Namensschild und Ball-Rahmen stoeren in der Ego-Sicht
local function hideOwnTag(character: Model)
	local head = character:WaitForChild("Head", 10)
	if not head then
		return
	end
	local function check(child: Instance)
		if child:IsA("BillboardGui") and (child.Name == "NameTag" or child.Name == "TitleTag") then
			child.Enabled = false
		end
	end
	for _, child in head:GetChildren() do
		check(child)
	end
	head.ChildAdded:Connect(check)
end
player.CharacterAdded:Connect(hideOwnTag)
if player.Character then
	task.spawn(hideOwnTag, player.Character)
end

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
		-- wie im Original: Sirene, Jubel und ein zufaelliger Sprecher-Spruch (zuerst, damit sie immer kommen)
		Sounds.Play("Siren")
		Sounds.Play("Cheer")
		local lines = { "Amazing", "Perfect", "Boom", "Laugh", "Goal" }
		task.delay(0.8, Sounds.Say, lines[math.random(#lines)])
		UI.ShowGoal(info)
		shake(1.2, 0.6)
	elseif kind == "Ended" then
		local text = if info.Winner then `{string.upper(info.Winner)} WIN {math.max(info.Blue, info.Red)}-{math.min(info.Blue, info.Red)}!` else `DRAW {info.Blue}-{info.Red}`
		UI.Announce(text, if info.Winner then Config.Teams[info.Winner].Color else Config.Colors.White, 5)
		task.delay(1.2, Sounds.Say, "Winner")
	elseif kind == "Damage" then
		local head = info.Model and info.Model:FindFirstChild("Head")
		if head then
			UI.DamageNumber(head, info.Amount, info.Backstab)
			Sounds.Play("Hit", head.Position, if info.Backstab then 0.8 else 1)
		end
		if info.Model == player.Character then
			shake(if info.Backstab then 0.8 else 0.35, 0.25)
		end
	elseif kind == "KO" then
		UI.KillFeed(info)
		if info.VictimModel == player.Character then
			UI.Announce(`KNOCKED OUT{if info.Attacker then " by " .. info.Attacker else ""}! Back in {if Config.Has(player, "QuickRespawn") then Config.QuickRespawnSeconds else Config.KOSeconds}s`, Config.Colors.Red, Config.KOSeconds)
		end
	elseif kind == "EXP" then
		UI.EXPPopup(info.Amount, info.Kind)
	elseif kind == "LevelUp" then
		shake(0.4, 0.3)
		Sounds.Play("LevelUp")
	elseif kind == "Fireworks" then
		shake(0.3, 1.5)
	end
end)

workspace:GetAttributeChangedSignal("MatchState"):Connect(function()
	local state = workspace:GetAttribute("MatchState")
	if state == "Kickoff" then
		UI.HideResults()
	elseif state == "Playing" then
		Sounds.Play("Whistle")
		Sounds.Say("Go")
	elseif state == "Ended" then
		Sounds.Play("WhistleEnd")
	end
end)

-- Soundeffekte vom Server; ein Smack laesst das Publikum aufstoehnen
remotes.Sound.OnClientEvent:Connect(function(name: string, position: Vector3?, pitch: number?, volume: number?)
	if name == "Returned" then
		Sounds.Play("Whistle")
		Sounds.Say("Returned")
	else
		Sounds.Play(name, position, pitch, volume)
	end
	if name == "Smack" then
		Sounds.Play("Ooh")
		Sounds.Say("Ouch")
	end
end)

-- Countdown vor dem Anstoss: der Sprecher zaehlt "three, two, one", dann "go"
local COUNT = { "One", "Two", "Three" }
task.spawn(function()
	local lastBeep = 0
	while true do
		task.wait(0.1)
		if workspace:GetAttribute("MatchState") == "Kickoff" then
			local remaining = math.ceil((workspace:GetAttribute("StateEnds") or 0) - serverNow())
			if remaining >= 1 and remaining <= 3 and remaining ~= lastBeep then
				lastBeep = remaining
				Sounds.Play("Beep", nil, 1, 0.4)
				Sounds.Say(COUNT[remaining])
			end
		else
			lastBeep = 0
		end
	end
end)
Sounds.StartCrowd()

-- Wer den Ball hat, bekommt einen leuchtenden Rahmen in der Teamfarbe
local carrierHighlight = Instance.new("Highlight")
carrierHighlight.FillTransparency = 0.85
carrierHighlight.OutlineTransparency = 0
carrierHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
local function updateCarrier()
	local model = carrierValue.Value
	if model and model ~= player.Character then
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

-- Erweiterungen zuletzt starten: ein Fehler dort darf Steuerung, Schwert und Sounds nicht abschalten
task.spawn(function()
	local ok, err = pcall(Extras.Start, {
		SetFov = function(fov: number)
			baseFov = fov
		end,
		SetFirstPerson = function(on: boolean)
			if firstPerson ~= on then
				firstPerson = on
				applyView()
			end
		end,
	})
	if not ok then
		warn("[Extras] start failed:", err)
		UI.Toast("Extras error: " .. string.sub(tostring(err), 1, 120), Config.Colors.Red)
	end
end)
