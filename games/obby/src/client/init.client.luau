-- Client: HUD, Kill-Erkennung, Sprungpads, Hindernis-Animationen, Double Jump, Welt-Stimmung,
-- Edelsteine, "Spieler ausblenden" und Chat-Tags.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local UI = require(script.UI)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local obby = workspace:WaitForChild("Obby")
local killFolder = obby:WaitForChild("Kill")
local checkpoints = obby:WaitForChild("Checkpoints")
local bounceFolder = obby:WaitForChild("Bounce")
local gemFolder = obby:WaitForChild("Gems")

UI.Start()

-- Eingebaute Roblox-Sounds (keine fremden Assets noetig)
local CHECKPOINT_SOUND = "rbxasset://sounds/electronicpingshort.wav"
local WIN_SOUND = "rbxasset://sounds/victory.wav"
local BOUNCE_SOUND = "rbxasset://sounds/action_jump.mp3"

-- Sound abspielen, ausser der Spieler hat Soundeffekte ausgeschaltet
local function playSound(id: string, volume: number)
	if not UI.GetSetting("Sounds") then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Parent = workspace.CurrentCamera
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		sound:Destroy()
	end)
end

---------------------------------------------------------------- Sterben und Sprungpads

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { killFolder }

local bounceOverlap = OverlapParams.new()
bounceOverlap.FilterType = Enum.RaycastFilterType.Include
bounceOverlap.FilterDescendantsInstances = { bounceFolder }

local dead = false
local deathsOnStage = 0
local deathStage = 0
local lastBounce = 0

local function die()
	if dead then
		return
	end
	dead = true
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	end
	remotes.Died:FireServer()

	-- Wer oft an derselben Stage stirbt, bekommt den Skip angeboten
	local stage = player:GetAttribute("Stage") or 1
	if stage ~= deathStage then
		deathStage = stage
		deathsOnStage = 0
	end
	deathsOnStage += 1
	if deathsOnStage == 4 or deathsOnStage % 8 == 0 then
		UI.Toast("Stuck? Skip this stage! ⏭", Color3.fromRGB(90, 220, 120))
		UI.HighlightSkip()
	end
end

player.CharacterAdded:Connect(function()
	dead = false
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if dead or not rootPart or not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Kill-Teile beruehrt?
	local hits = workspace:GetPartBoundsInBox(rootPart.CFrame * CFrame.new(0, -0.6, 0), Vector3.new(2.2, 5, 1.4), overlap)
	if #hits > 0 then
		die()
		return
	end
	-- Auf einem Sprungpad? Kleine Box direkt unter den Fuessen schleudert nach oben
	if os.clock() - lastBounce > 0.25 then
		local feet = workspace:GetPartBoundsInBox(rootPart.CFrame * CFrame.new(0, -3, 0), Vector3.new(1.8, 1, 1.2), bounceOverlap)
		if #feet > 0 then
			lastBounce = os.clock()
			local velocity = rootPart.AssemblyLinearVelocity
			rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, Config.BounceVelocity, velocity.Z)
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			playSound(BOUNCE_SOUND, 0.5)
		end
	end
	-- Heruntergefallen?
	local pad = checkpoints:FindFirstChild(tostring(player:GetAttribute("Stage") or 1)) :: BasePart?
	if pad and rootPart.Position.Y < pad.Position.Y - Config.FallDistance then
		die()
	end
end)

---------------------------------------------------------------- Hindernisse animieren (synchron ueber Serverzeit)

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	for _, p in CollectionService:GetTagged("Spin") do
		local base = p:GetAttribute("BaseCFrame")
		if base then
			p.CFrame = base * CFrame.Angles(0, math.rad((now * p:GetAttribute("Speed")) % 360), 0)
		end
	end
	for _, p in CollectionService:GetTagged("Slide") do
		local base = p:GetAttribute("BaseCFrame")
		if base then
			local t = (now / p:GetAttribute("Period") + p:GetAttribute("Phase")) * math.pi * 2
			p.CFrame = base + p:GetAttribute("Offset") * math.sin(t)
		end
	end
	for _, p in CollectionService:GetTagged("Fade") do
		local period = p:GetAttribute("Period")
		local t = ((now / period + p:GetAttribute("Phase")) % 1)
		-- 0-0.55 fest, 0.55-0.75 blinkt (noch fest), danach weg
		if t < 0.55 then
			p.Transparency = 0.15
			p.CanCollide = true
		elseif t < 0.75 then
			p.Transparency = if (t * 20) % 1 < 0.5 then 0.15 else 0.6
			p.CanCollide = true
		else
			p.Transparency = 0.92
			p.CanCollide = false
		end
	end
end)

---------------------------------------------------------------- Double Jump

local usedDoubleJump = false
local jumpStartedAt = 0
UserInputService.JumpRequest:Connect(function()
	if not player:GetAttribute("Pass_DoubleJump") then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local state = humanoid:GetState()
	-- JumpRequest feuert beim Gedrueckthalten mehrmals: erst kurz nach dem Absprung zaehlt es als zweiter Sprung
	if os.clock() - jumpStartedAt < 0.2 then
		return
	end
	if not usedDoubleJump and (state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping) then
		usedDoubleJump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end)

local function watchLanding(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			usedDoubleJump = false
		elseif new == Enum.HumanoidStateType.Jumping and not usedDoubleJump then
			jumpStartedAt = os.clock()
		end
	end)
end
player.CharacterAdded:Connect(watchLanding)
if player.Character then
	task.spawn(watchLanding, player.Character)
end

---------------------------------------------------------------- Welt-Stimmung und Checkpoint-Effekt

local lastStage = player:GetAttribute("Stage") or 1

-- Kurzer Partikel-Ausbruch (z. B. Checkpoint, Ziel)
local function burst(parent: BasePart, color: Color3, amount: number)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, parent.Size.Y / 2 + 0.5, 0)
	attachment.Parent = parent
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(14, 24)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(amount)
	task.delay(2, function()
		attachment:Destroy()
	end)
end

-- Ziel erreicht: Konfetti in Regenbogenfarben und Fanfare
player:GetAttributeChangedSignal("Wins"):Connect(function()
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		for i = 0, 4 do
			burst(rootPart, Color3.fromHSV(i / 5, 0.7, 1), 30)
		end
	end
	playSound(WIN_SOUND, 0.7)
	UI.Banner("YOU WIN!", `Wins: {player:GetAttribute("Wins")}`, Color3.fromRGB(255, 210, 60))
end)

local function applyWorld(instant: boolean)
	local stage = player:GetAttribute("Stage") or 1
	local world = Config.WorldForStage(stage)
	local info = TweenInfo.new(if instant then 0 else 2)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Color = world.Sky }):Play()
	end
	TweenService:Create(Lighting, info, { ClockTime = if world.Night then 0 else 14 }):Play()

	if stage > lastStage then
		local pad = checkpoints:FindFirstChild(tostring(stage)) :: BasePart?
		if pad then
			local original = pad.Color
			pad.Color = Color3.new(1, 1, 1)
			TweenService:Create(pad, TweenInfo.new(0.6), { Color = original }):Play()
			burst(pad, world.Accent, 40)
		end
		playSound(CHECKPOINT_SOUND, 0.6)
		if (stage - 1) % Config.StagesPerWorld == 0 then
			UI.Banner(`WORLD {(stage - 1) // Config.StagesPerWorld + 1}`, world.Name, world.Accent)
		else
			UI.Toast(`Checkpoint! Stage {stage}`, Color3.fromRGB(120, 255, 160))
		end
	end
	lastStage = stage
end
applyWorld(true)
player:GetAttributeChangedSignal("Stage"):Connect(function()
	applyWorld(false)
end)

---------------------------------------------------------------- Regenbogen-Edelsteine

-- Gefundene Edelsteine werden fuer diesen Spieler fast unsichtbar
local function refreshGems()
	local mask = player:GetAttribute("GemMask") or 0
	for _, gem in gemFolder:GetChildren() do
		local world = gem:GetAttribute("GemWorld")
		if gem:IsA("BasePart") and world then
			local found = Config.HasGem(mask, world)
			gem.LocalTransparencyModifier = if found then 0.85 else 0
			local sparkles = gem:FindFirstChildOfClass("Sparkles")
			if sparkles then
				sparkles.Enabled = not found
			end
		end
	end
end
local lastGemMask = player:GetAttribute("GemMask") or 0
refreshGems()
player:GetAttributeChangedSignal("GemMask"):Connect(function()
	local mask = player:GetAttribute("GemMask") or 0
	if mask ~= lastGemMask then
		lastGemMask = mask
		playSound(CHECKPOINT_SOUND, 0.8)
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			burst(rootPart, Color3.fromHSV(math.random(), 0.7, 1), 40)
		end
	end
	refreshGems()
end)

---------------------------------------------------------------- Andere Spieler ausblenden (Einstellung)

local hiddenState = false
local function setCharacterHidden(character: Model, hidden: boolean)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.LocalTransparencyModifier = if hidden then 1 else 0
		elseif descendant:IsA("BillboardGui") or descendant:IsA("Trail") then
			descendant.Enabled = not hidden
		end
	end
end

task.spawn(function()
	while true do
		local hide = UI.GetSetting("HidePlayers")
		-- Nur arbeiten, wenn ausgeblendet ist oder gerade wieder eingeblendet werden muss
		if hide or hiddenState then
			for _, other in Players:GetPlayers() do
				if other ~= player and other.Character then
					setCharacterHidden(other.Character, hide)
				end
			end
			hiddenState = hide
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------- Namensschilder und Lobby-Schild animieren

-- Namensschilder von Owner/VIP: Farbverlauf langsam drehen
task.spawn(function()
	while true do
		local rotation = (os.clock() * 90) % 360
		for _, other in Players:GetPlayers() do
			local tag = other.Character and other.Character:FindFirstChild("NameTag")
			if tag then
				for _, child in tag:GetDescendants() do
					if child:IsA("UIGradient") and child.Name == "Animated" then
						child.Rotation = rotation
					end
				end
			end
		end
		local sign = obby:FindFirstChild("Rainbow", true)
		if sign and sign:IsA("UIGradient") then
			sign.Offset = Vector2.new(math.sin(os.clock()) * 0.3, 0)
		end
		task.wait(0.05)
	end
end)

---------------------------------------------------------------- Chat-Tags

TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender then
		local prefix = message.PrefixText
		local rank = sender:GetAttribute("Rank")
		if rank and rank ~= "Newbie" then
			prefix = `<font color="{sender:GetAttribute("RankColor") or "#FFFFFF"}">[{rank}]</font> {prefix}`
		end
		if sender:GetAttribute("Pass_VIP") then
			prefix = `<font color="#FFC828">[VIP]</font> {prefix}`
		end
		properties.PrefixText = prefix
	end
	return properties
end
