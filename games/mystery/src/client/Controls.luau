-- Eingaben: Messer (Klick = Stich, T = Wurf), Blaster (Klick = Schuss), Faehigkeiten (Q/F/R),
-- Sprint (Shift) mit Ausdauer, Zuschauen und Emotes. Die UI ruft dieselben Funktionen fuer Handy-Knoepfe auf.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)

local Controls = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local Request = remotes:WaitForChild("Request") :: RemoteFunction

Controls.Role = nil :: string?
Controls.ReadyAt = {} :: { [string]: number }
Controls.Stamina = Config.SprintStamina
Controls.Sprinting = false
Controls.Spectating = nil :: Model?
Controls.OnChanged = nil :: (() -> ())?

local function changed()
	if Controls.OnChanged then
		Controls.OnChanged()
	end
end

local function character(): Model?
	return player.Character
end

local function root(): BasePart?
	local c = character()
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Zielpunkt: Maus/Fingertipp, sonst Bildschirmmitte
local function aimPoint(): Vector3
	if UserInputService.MouseEnabled then
		return mouse.Hit.Position
	end
	local camera = workspace.CurrentCamera
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y * 0.45)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character() :: any }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	return if hit then hit.Position else ray.Origin + ray.Direction * 300
end

function Controls.Throw()
	if Controls.Role ~= "Murderer" then
		return
	end
	local t = os.clock()
	if t < (Controls.ReadyAt.Throw or 0) then
		return
	end
	Controls.ReadyAt.Throw = t + Config.Knife.ThrowCooldown
	remotes.Throw:FireServer(aimPoint())
	changed()
end

function Controls.Ability(name: string)
	local def = Config.Abilities[name]
	if not def then
		return
	end
	if name == "Sprint" then
		Controls.Sprinting = not Controls.Sprinting
		changed()
		return
	end
	if os.clock() < (Controls.ReadyAt[name] or 0) then
		return
	end
	local ok, result = pcall(Request.InvokeServer, Request, "Ability", name)
	if ok and result and result.Ok then
		Controls.ReadyAt[name] = os.clock() + (result.Cooldown or def.Cooldown)
		if name == "Dash" then
			local r = root()
			if r then
				local look = r.CFrame.LookVector
				r.AssemblyLinearVelocity = Vector3.new(look.X, 0, look.Z).Unit * 75 + Vector3.new(0, 14, 0)
			end
		end
	elseif ok and result and result.Cooldown then
		Controls.ReadyAt[name] = os.clock() + result.Cooldown
	end
	changed()
end

function Controls.Emote(id: string)
	local c = character()
	local animate = c and c:FindFirstChild("Animate")
	local play = animate and animate:FindFirstChild("PlayEmote")
	if play and play:IsA("BindableFunction") then
		pcall(play.Invoke, play, id)
	end
end

---------------------------------------------------------------- Zuschauen

function Controls.SpectateTargets(): { Model }
	local list = {}
	for _, model in CollectionService:GetTagged("Actor") do
		if model ~= character() and model.Parent then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 and model:GetAttribute("ActorId") then
				table.insert(list, model)
			end
		end
	end
	table.sort(list, function(a, b)
		return (a:GetAttribute("ActorId") or 0) < (b:GetAttribute("ActorId") or 0)
	end)
	return list
end

function Controls.Spectate(step: number)
	local list = Controls.SpectateTargets()
	if #list == 0 then
		Controls.StopSpectate()
		return
	end
	local index = (table.find(list, Controls.Spectating :: Model) or 0) + step
	if index < 1 then
		index = #list
	elseif index > #list then
		index = 1
	end
	Controls.Spectating = list[index]
	local humanoid = list[index]:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
	changed()
end

function Controls.StopSpectate()
	Controls.Spectating = nil
	local c = character()
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if humanoid then
		workspace.CurrentCamera.CameraSubject = humanoid
	end
	changed()
end

---------------------------------------------------------------- Werkzeuge

local function hookTool(tool: Tool)
	if tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		local kind = tool:GetAttribute("Kind")
		if kind == "Knife" then
			-- Standard-Animate spielt "Slash", wenn ein toolanim-Wert auftaucht
			local anim = Instance.new("StringValue")
			anim.Name = "toolanim"
			anim.Value = "Slash"
			anim.Parent = tool
			game:GetService("Debris"):AddItem(anim, 0.5)
			remotes.Stab:FireServer()
		elseif kind == "Gun" then
			local t = os.clock()
			if t < (Controls.ReadyAt.Shoot or 0) then
				return
			end
			Controls.ReadyAt.Shoot = t + Config.Gun.Cooldown
			remotes.Shoot:FireServer(aimPoint())
			changed()
		end
	end)
end

local function hookCharacter(c: Model)
	c.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			hookTool(child)
		end
	end)
	local humanoid = c:WaitForChild("Humanoid") :: Humanoid
	-- Tempo vom Server (Basis) plus Sprint
	local function applySpeed()
		local base = c:GetAttribute("BaseSpeed") or Config.WalkSpeed
		local sprint = Controls.Sprinting and Controls.Stamina > 0 and c:GetAttribute("Slowed") ~= true and humanoid.MoveDirection.Magnitude > 0
		humanoid.WalkSpeed = base + (if sprint then Config.SprintSpeed - Config.WalkSpeed else 0)
	end
	c:GetAttributeChangedSignal("BaseSpeed"):Connect(applySpeed)
	Controls.ApplySpeed = applySpeed
	Controls.ReadyAt = {}
	Controls.Stamina = Config.SprintStamina
	Controls.Sprinting = false
	if Controls.Spectating then
		Controls.StopSpectate()
	end
end

function Controls.Start()
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			hookTool(child)
		end
	end)

	-- Tastatur
	ContextActionService:BindAction("MMThrow", function(_, state)
		if state == Enum.UserInputState.Begin then
			Controls.Throw()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.T, Enum.KeyCode.ButtonX)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		local role = Controls.Role
		if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.ButtonL3 then
			if role and role ~= "Murderer" then
				Controls.Sprinting = true
				changed()
			end
		elseif key == Enum.KeyCode.Q then
			if role == "Murderer" then
				Controls.Ability("Dash")
			elseif role == "Sheriff" or role == "Hero" then
				Controls.Ability("Scan")
			end
		elseif key == Enum.KeyCode.F and role == "Murderer" then
			Controls.Ability("Cloak")
		elseif key == Enum.KeyCode.R and role == "Murderer" then
			Controls.Ability("Trap")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL3 then
			if UserInputService.KeyboardEnabled then
				Controls.Sprinting = false
				changed()
			end
		end
	end)

	-- Ausdauer
	RunService.Heartbeat:Connect(function(dt)
		local c = character()
		local humanoid = c and c:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local moving = humanoid.MoveDirection.Magnitude > 0
		if Controls.Sprinting and moving and Controls.Role and Controls.Role ~= "Murderer" then
			Controls.Stamina = math.max(0, Controls.Stamina - dt)
			if Controls.Stamina == 0 then
				Controls.Sprinting = false
				changed()
			end
		else
			Controls.Stamina = math.min(Config.SprintStamina, Controls.Stamina + dt * Config.SprintRegen)
		end
		if Controls.ApplySpeed then
			Controls.ApplySpeed()
		end
		-- Zuschauer-Ziel weg? Naechstes nehmen
		if Controls.Spectating and (not Controls.Spectating.Parent or not Controls.Spectating:GetAttribute("ActorId")) then
			Controls.Spectate(1)
		end
	end)
end

return Controls
