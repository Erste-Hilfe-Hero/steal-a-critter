-- Update 3 auf dem Client: eigene Musik (3 Songs, Musik-Knopf), Sounds (Surfen, Landung, Start, Ziel,
-- Bestzeit, Medaille, Feuerwerk), Stimmung je Stage (Tag bis Polarlicht-Nacht), Polarlicht am Himmel,
-- Schneespray an den Skiern, Stage-Titelkarte, Fortschrittsbalken, Konfetti, Feuerwerk, Tempo-Trend,
-- Geist der eigenen Bestzeit und Statistik nach jeder Stage.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Sounds = require(ReplicatedStorage.Shared.Sounds)
local StageLayout = require(ReplicatedStorage.Shared.StageLayout)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local camera = workspace.CurrentCamera
local T = Config.Theme

local Update3 = {}

-- Songs: Name, Datei, wofuer
local SONGS = {
	{ Id = "music_lobby", Name = "Apres-Ski" },
	{ Id = "music_run", Name = "Powder Rush" },
	{ Id = "music_night", Name = "Aurora Night" },
}

-- Stimmung je Stage: Uhrzeit, Helligkeit, Dunst, Farbe; Night = Polarlicht und Sterne
local MOODS = {
	Day = { Clock = 13.5, Brightness = 3, Ambient = Color3.fromRGB(110, 120, 140), Outdoor = Color3.fromRGB(170, 180, 200), Haze = Color3.fromRGB(205, 225, 250), Decay = Color3.fromRGB(110, 150, 210), Tint = Color3.fromRGB(245, 248, 255), Night = false },
	Afternoon = { Clock = 15.6, Brightness = 2.8, Ambient = Color3.fromRGB(120, 115, 130), Outdoor = Color3.fromRGB(175, 170, 190), Haze = Color3.fromRGB(225, 220, 240), Decay = Color3.fromRGB(150, 140, 200), Tint = Color3.fromRGB(255, 246, 240), Night = false },
	Golden = { Clock = 17.2, Brightness = 2.4, Ambient = Color3.fromRGB(130, 105, 110), Outdoor = Color3.fromRGB(190, 160, 150), Haze = Color3.fromRGB(255, 205, 170), Decay = Color3.fromRGB(200, 120, 120), Tint = Color3.fromRGB(255, 232, 210), Night = false },
	Sunset = { Clock = 17.9, Brightness = 1.8, Ambient = Color3.fromRGB(120, 90, 120), Outdoor = Color3.fromRGB(170, 120, 150), Haze = Color3.fromRGB(255, 160, 150), Decay = Color3.fromRGB(150, 80, 140), Tint = Color3.fromRGB(255, 220, 220), Night = false },
	Night = { Clock = 21.5, Brightness = 1.2, Ambient = Color3.fromRGB(70, 90, 140), Outdoor = Color3.fromRGB(90, 120, 180), Haze = Color3.fromRGB(60, 80, 140), Decay = Color3.fromRGB(40, 60, 120), Tint = Color3.fromRGB(215, 230, 255), Night = true },
}
local STAGE_MOOD = { "Day", "Day", "Day", "Afternoon", "Afternoon", "Golden", "Sunset", "Sunset", "Night", "Night" }

local layouts = {}
local function layoutFor(stage: number)
	local def = Config.Stages[stage]
	if not def then
		return nil
	end
	if not layouts[stage] then
		layouts[stage] = StageLayout.Build(stage, def, Config.StageSpacing, Config.StageHeight)
	end
	return layouts[stage]
end

local function sound(name: string, props): Sound?
	local id = Sounds.Id(name)
	if id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	for key, value in props or {} do
		(s :: any)[key] = value
	end
	s.Parent = props and props.Parent or SoundService
	return s
end

local oneShots = {}
local function play(name: string, volume: number?, speed: number?)
	local s = oneShots[name]
	if s == nil then
		s = sound(name, {}) or false
		oneShots[name] = s
	end
	if s then
		s.Volume = volume or 0.6
		s.PlaybackSpeed = speed or 1
		SoundService:PlayLocalSound(s)
	end
end

function Update3.Start(UI, Movement)
	local K = UI.Kit
	local create, text, panel, corner = K.create, K.text, K.panel, K.corner
	local gui = K.gui
	local settings = UI.Settings or Progression.DefaultSettings

	------------------------------------------------ Musik

	local musicGroup = create("SoundGroup", { Name = "Music", Volume = 0.45, Parent = SoundService })
	local tracks = {}
	for _, song in SONGS do
		tracks[song.Id] = sound(song.Id, { Looped = true, Volume = 0, SoundGroup = musicGroup })
	end
	local choice = 0 -- 0 = automatisch, 1..3 = fester Song, 4 = aus
	local current = nil
	local function wantedSong(): string?
		if settings.Music == false or choice == 4 then
			return nil
		end
		if choice > 0 then
			return SONGS[choice].Id
		end
		if player:GetAttribute("ArenaTeam") then
			return "music_run"
		end
		local stage = player:GetAttribute("Stage") or 0
		if stage == 0 then
			return "music_lobby"
		end
		return if STAGE_MOOD[stage] == "Night" or STAGE_MOOD[stage] == "Sunset" then "music_night" else "music_run"
	end
	local function switchSong()
		local wanted = wantedSong()
		if wanted == current then
			return
		end
		local old = current and tracks[current]
		if old then
			local fading = old
			TweenService:Create(fading, TweenInfo.new(1.5), { Volume = 0 }):Play()
			task.delay(1.6, function()
				if current ~= fading.Name and fading.Volume < 0.01 then
					fading:Pause()
				end
			end)
		end
		current = wanted
		local new = wanted and tracks[wanted]
		if new then
			new.Name = wanted
			if not new.IsPlaying then
				new:Resume()
				if not new.IsPlaying then
					new:Play()
				end
			end
			TweenService:Create(new, TweenInfo.new(1.5), { Volume = 1 }):Play()
		end
	end

	-- Musik-Knopf oben rechts: tippen = naechster Song (Auto, 3 Songs, Aus)
	local musicButton = K.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(170, 34), Text = "", Color = T.Panel, Parent = gui }, function()
		choice = (choice + 1) % 5
		local label = if choice == 0 then "AUTO" elseif choice == 4 then "OFF" else string.upper(SONGS[choice].Name)
		K.toast("Music: " .. label, T.Ice, 1.5)
		switchSong()
	end)
	musicButton.TextXAlignment = Enum.TextXAlignment.Left

	------------------------------------------------ Surf-Sounds

	local carve = sound("sfx_carve", { Looped = true, Volume = 0 })
	if carve then
		carve:Play()
	end
	local lastLandings = Movement.Landings
	local lastStageStart = nil

	------------------------------------------------ Stimmung und Polarlicht

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local colorFx = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local moodName = nil
	local function applyMood(name: string)
		if name == moodName then
			return
		end
		moodName = name
		local mood = MOODS[name]
		local info = TweenInfo.new(2.5, Enum.EasingStyle.Sine)
		TweenService:Create(Lighting, info, { ClockTime = mood.Clock, Brightness = mood.Brightness, Ambient = mood.Ambient, OutdoorAmbient = mood.Outdoor }):Play()
		if atmosphere then
			TweenService:Create(atmosphere, info, { Color = mood.Haze, Decay = mood.Decay }):Play()
		end
		if colorFx then
			TweenService:Create(colorFx, info, { TintColor = mood.Tint }):Play()
		end
		if sky then
			sky.StarCount = if mood.Night then 3000 else 0
		end
	end

	-- Polarlicht: grosse, leicht durchsichtige Vorhaenge hoch am Himmel, die wabern
	local auroraFolder = create("Folder", { Name = "LocalAurora", Parent = workspace })
	local curtains = {}
	for i = 1, 5 do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Transparency = 1
		p.Size = Vector3.new(700, 220, 1)
		p.Parent = auroraFolder
		local surface = create("SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0, Brightness = 2.5, AlwaysOnTop = false, Parent = p })
		local back = create("SurfaceGui", { Face = Enum.NormalId.Back, LightInfluence = 0, Brightness = 2.5, Parent = p })
		local gradients = {}
		for _, sg in { surface, back } do
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 1
			local frame = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = sg })
			local gradient = create("UIGradient", {
				Rotation = 90,
				Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 110, 255)), ColorSequenceKeypoint.new(0.45, Color3.fromRGB(90, 255, 190)), ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 200, 255)) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.55), NumberSequenceKeypoint.new(0.75, 0.75), NumberSequenceKeypoint.new(1, 1) }),
				Parent = frame,
			})
			table.insert(gradients, gradient)
		end
		curtains[i] = { Part = p, Gradients = gradients, Phase = i * 1.3, Offset = Vector3.new((i - 3) * 260, 420 + (i % 2) * 60, -700 - i * 90) }
	end
	local auroraStrength = 0
	local fxFolder = create("Folder", { Name = "LocalFx", Parent = workspace })

	------------------------------------------------ Schneespray an den Skiern

	local sprayAttachment = Instance.new("Attachment")
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 0
	spray.Lifetime = NumberRange.new(0.35, 0.7)
	spray.Speed = NumberRange.new(6, 14)
	spray.SpreadAngle = Vector2.new(35, 35)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.6) })
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	spray.Color = ColorSequence.new(Color3.fromRGB(245, 250, 255))
	spray.Acceleration = Vector3.new(0, -20, 0)
	spray.LightEmission = 0.2
	spray.Drag = 3
	spray.Parent = sprayAttachment

	------------------------------------------------ Stage-Titelkarte und Fortschritt

	local card = panel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.28), Size = UDim2.fromOffset(460, 92), BackgroundTransparency = 1, Visible = false, Radius = 16, Parent = gui })
	local cardStage = text({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 22), Text = "", TextColor3 = T.Muted, FontFace = K.HEAVY, Parent = card })
	local cardName = text({ Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -32, 0, 38), Text = "", FontFace = K.HEAVY, Parent = card })
	local cardGoal = text({ Position = UDim2.fromOffset(16, 68), Size = UDim2.new(1, -32, 0, 16), Text = "", TextColor3 = T.Gold, FontFace = K.BOLD, Parent = card })
	local function showCard(stage: number)
		local def = Config.Stages[stage]
		if not def then
			return
		end
		cardStage.Text = `STAGE {stage} OF {#Config.Stages}`
		cardName.Text = string.upper(def.Name)
		cardName.TextColor3 = def.Accent
		local best = player:GetAttribute("StageBest_" .. stage)
		cardGoal.Text = `Gold medal: {Format.Run(Progression.GoldTimes[stage])}` .. (if best then `   Your PB: {Format.Run(best)}` else "")
		card.Visible = true
		card.BackgroundTransparency = 0.1
		for _, label in { cardStage, cardName, cardGoal } do
			label.TextTransparency = 0
		end
		task.delay(2.4, function()
			for _, label in { cardStage, cardName, cardGoal } do
				TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			end
			TweenService:Create(card, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
			task.wait(0.55)
			if card.BackgroundTransparency > 0.95 then
				card.Visible = false
			end
		end)
	end

	local progressBack = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116), Size = UDim2.fromOffset(300, 6), BackgroundColor3 = T.Navy, BackgroundTransparency = 0.3, Visible = false, Parent = gui })
	corner(3).Parent = progressBack
	local progressFill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.Mint, Parent = progressBack })
	corner(3).Parent = progressFill
	local progressDots = {}
	local function buildDots(stage: number)
		for _, dot in progressDots do
			dot:Destroy()
		end
		table.clear(progressDots)
		local layout = layoutFor(stage)
		if not layout then
			return
		end
		local startX, endX = layout.StartCenter.X, layout.FinishCenter.X
		for _, r in layout.Ramps do
			local dot = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((r.Ridge.X - startX) / (endX - startX), 0.5), Size = UDim2.fromOffset(4, 10), BackgroundColor3 = T.Snow, BorderSizePixel = 0, Parent = progressBack })
			table.insert(progressDots, dot)
		end
	end

	------------------------------------------------ Tempo-Trend neben dem Tacho

	local trend = text({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 128, 1, -48), Size = UDim2.fromOffset(110, 22), Text = "", FontFace = K.MONO, TextXAlignment = Enum.TextXAlignment.Left, Parent = gui })
	create("UIStroke", { Color = T.Navy, Thickness = 2, Transparency = 0.3, Parent = trend })
	local speedHistory = {}

	------------------------------------------------ Konfetti und Feuerwerk

	local confettiColors = { T.Ice, T.Mint, T.Gold, T.Aurora, T.Snow }
	local function confetti(amount: number)
		local rng = Random.new()
		for _ = 1, amount do
			local piece = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(rng:NextNumber(0.1, 0.9), -0.05),
				Size = UDim2.fromOffset(rng:NextInteger(6, 12), rng:NextInteger(10, 18)),
				Rotation = rng:NextNumber(0, 360),
				BackgroundColor3 = confettiColors[rng:NextInteger(1, #confettiColors)],
				BorderSizePixel = 0,
				ZIndex = 30,
				Parent = gui,
			})
			local fall = rng:NextNumber(1.6, 2.8)
			TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(piece.Position.X.Scale + rng:NextNumber(-0.15, 0.15), 1.08),
				Rotation = piece.Rotation + rng:NextNumber(-540, 540),
			}):Play()
			task.delay(fall, function()
				piece:Destroy()
			end)
		end
	end

	local function burst(center: Vector3, color: Color3)
		for i = 1, 22 do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.new(1.4, 1.4, 1.4)
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = color
			p.CFrame = CFrame.new(center)
			p.Parent = fxFolder
			local theta = i / 22 * math.pi * 2
			local phi = math.random() * math.pi - math.pi / 2
			local direction = Vector3.new(math.cos(theta) * math.cos(phi), math.sin(phi), math.sin(theta) * math.cos(phi))
			TweenService:Create(p, TweenInfo.new(1.4, Enum.EasingStyle.Quart), { CFrame = CFrame.new(center + direction * 28 + Vector3.new(0, -6, 0)), Transparency = 1, Size = Vector3.new(0.4, 0.4, 0.4) }):Play()
			task.delay(1.5, function()
				p:Destroy()
			end)
		end
	end
	local function fireworks(at: Vector3)
		local near = (at - camera.CFrame.Position).Magnitude < 900
		for i = 1, 6 do
			task.delay(i * 0.45, function()
				local center = at + Vector3.new(math.random(-40, 40), 55 + math.random(0, 30), math.random(-40, 40))
				burst(center, confettiColors[(i - 1) % #confettiColors + 1])
				if near then
					play("sfx_firework", 0.5, 0.9 + math.random() * 0.25)
				end
			end)
		end
	end
	remotes.Fx.OnClientEvent:Connect(function(kind, position)
		if kind == "Fireworks" and typeof(position) == "Vector3" then
			fireworks(position)
			-- In der Lobby sieht man es auch
			local lobby = workspace:GetAttribute("LobbySpawn")
			if lobby and (player:GetAttribute("Stage") or 0) == 0 and not player:GetAttribute("ArenaTeam") then
				fireworks(lobby.Position + Vector3.new(150, 0, 0))
			end
		end
	end)

	------------------------------------------------ Geist der Bestzeit (pro Stage, diese Sitzung)

	local ghosts = {} -- [Stage] = { Time, Samples = { {t, Position, Yaw} } }
	local recording = nil
	local ghostModel = create("Model", { Name = "LocalGhost", Parent = workspace })
	local ghostBody = create("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.ForceField, Color = T.Ice, Transparency = 0.2, Parent = ghostModel })
	local ghostHead = create("Part", { Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.ForceField, Color = T.Ice, Transparency = 0.2, Parent = ghostModel })
	local ghostSkis = create("Part", { Size = Vector3.new(1.6, 0.2, 5), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Material = Enum.Material.Neon, Color = T.Ice, Transparency = 0.5, Parent = ghostModel })
	local ghostTag = create("BillboardGui", { Size = UDim2.fromOffset(120, 22), StudsOffset = Vector3.new(0, 3, 0), MaxDistance = 200, Parent = ghostHead })
	text({ Size = UDim2.fromScale(1, 1), Text = "YOUR BEST", TextColor3 = T.Ice, FontFace = K.HEAVY, Parent = ghostTag })
	local function hideGhost()
		for _, p in { ghostBody, ghostHead, ghostSkis } do
			p.CFrame = CFrame.new(0, -5000, 0)
		end
	end
	hideGhost()

	------------------------------------------------ Statistik der laufenden Stage

	local attempt = nil -- { Distance, Time, Top, StrafeGood0, StrafeTotal0, Last }

	------------------------------------------------ Ergebnisse

	remotes.Result.OnClientEvent:Connect(function(result)
		if typeof(result) ~= "table" then
			return
		end
		if result.MapComplete then
			play(if result.RunPB then "sfx_mapclear" else "sfx_pb", 0.7)
			confetti(140)
		elseif result.StagePB then
			play("sfx_pb", 0.6)
			confetti(70)
		else
			confetti(35)
		end
		if result.NewMedal then
			task.delay(0.5, function()
				play("sfx_medal", 0.7)
			end)
		end
		-- Geist speichern, wenn das die beste Zeit dieser Sitzung ist
		if recording and recording.Stage == result.Stage and typeof(result.StageTime) == "number" then
			local old = ghosts[result.Stage]
			if not old or result.StageTime < old.Time then
				ghosts[result.Stage] = { Time = result.StageTime, Samples = recording.Samples }
			end
		end
		recording = nil
		-- Statistik der Stage
		if attempt and attempt.Time > 0.5 and not result.MapComplete then
			local avg = attempt.Distance / attempt.Time / SurfPhysics.Unit
			local strafes = Movement.StrafeTotal - attempt.Strafe0
			local sync = if strafes > 20 then math.floor((Movement.StrafeGood - attempt.Good0) / strafes * 100 + 0.5) else nil
			K.toast(`AVG {Format.Number(avg)} u/s   TOP {Format.Number(attempt.Top / SurfPhysics.Unit)} u/s` .. (if sync then `   SYNC {sync}%` else ""), T.Mint, 3.2)
		end
		attempt = nil
	end)

	------------------------------------------------ Einstellungen (aus Extras.luau)

	local function apply(s)
		settings = s
		Movement.Roll = s.CameraTilt ~= false
		switchSong()
	end
	UI.ApplySettings3 = apply
	apply(settings)

	------------------------------------------------ Jeder Frame

	local lastStage = -1
	local clock = 0
	local respawns = Movement.Respawns or 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		-- Nach einem Absturz kurz anzeigen, dass man neu startet
		if (Movement.Respawns or 0) ~= respawns then
			respawns = Movement.Respawns or 0
			play("sfx_whoosh", 0.5, 0.8)
			K.toast(if player:GetAttribute("ArenaTeam") then "Fell off - back to base!" else "Fell off - back to the start!", T.Ice, 1.2)
		end
		local stage = player:GetAttribute("Stage") or 0
		local inArena = player:GetAttribute("ArenaTeam") ~= nil
		local speed = Movement.Speed

		-- Stage-Wechsel: Titelkarte, Stimmung, Musik, Fortschritt
		if stage ~= lastStage then
			lastStage = stage
			if stage > 0 then
				showCard(stage)
				buildDots(stage)
			end
			switchSong()
		end
		applyMood(if inArena then "Day" elseif stage > 0 then STAGE_MOOD[stage] or "Day" else "Day")
		if clock % 1 < dt then
			switchSong()
		end
		local songName = "OFF"
		if current then
			for _, song in SONGS do
				if song.Id == current then
					songName = song.Name
				end
			end
		end
		musicButton.Text = "♪  " .. string.upper(songName) .. (if choice == 0 then "  (AUTO)" else "")

		-- Surf-Rauschen und Landung
		if carve then
			local target = if Movement.Surfing then math.clamp(0.25 + speed / 220, 0.25, 0.9) else 0
			carve.Volume += (target - carve.Volume) * math.min(1, dt * 10)
			carve.PlaybackSpeed = 0.8 + math.min(0.6, speed / 260)
		end
		if Movement.Landings ~= lastLandings then
			lastLandings = Movement.Landings
			play("sfx_land", 0.5, 0.9 + math.random() * 0.2)
		end
		-- Start: Wusch beim Verlassen der Startzone
		if Movement.StageStart and Movement.StageStart ~= lastStageStart then
			play("sfx_whoosh", 0.6)
			local position = Movement.RenderPosition
			recording = { Stage = stage, Start = Movement.StageStart, Samples = {}, Next = 0 }
			attempt = { Distance = 0, Time = 0, Top = 0, Strafe0 = Movement.StrafeTotal, Good0 = Movement.StrafeGood, Last = position }
		end
		lastStageStart = Movement.StageStart
		if not Movement.StageStart then
			recording = nil
		end

		-- Schneespray
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and sprayAttachment.Parent ~= root then
			sprayAttachment.Parent = root
			sprayAttachment.Position = Vector3.new(0, -2.6, 0)
		end
		spray.Rate = if settings.SkiSpray ~= false and Movement.Surfing then math.clamp(speed * 1.2, 20, 220) else 0
		if Movement.Surfing then
			local velocity = Movement.GetVelocity()
			spray.EmissionDirection = Enum.NormalId.Top
			if velocity.Magnitude > 1 and root then
				sprayAttachment.WorldCFrame = CFrame.lookAt(root.Position - Vector3.new(0, 2.6, 0), root.Position - Vector3.new(0, 2.6, 0) + (Movement.Contact + Vector3.new(0, 0.6, 0) - velocity.Unit * 0.6)) * CFrame.Angles(-math.pi / 2, 0, 0)
			end
		end

		-- Polarlicht: nur nachts, folgt der Kamera, wabert
		local wantAurora = if moodName and MOODS[moodName].Night then 1 else 0
		auroraStrength += (wantAurora - auroraStrength) * math.min(1, dt * 0.8)
		auroraFolder.Parent = if auroraStrength > 0.02 then workspace else nil
		if auroraStrength > 0.02 then
			local base = camera.CFrame.Position
			for _, curtain in curtains do
				local sway = math.sin(clock * 0.25 + curtain.Phase) * 40
				curtain.Part.CFrame = CFrame.new(Vector3.new(base.X, 0, base.Z) + curtain.Offset + Vector3.new(sway, Config.StageHeight - 300, 0)) * CFrame.Angles(0, math.sin(clock * 0.1 + curtain.Phase) * 0.3, 0)
				for _, gradient in curtain.Gradients do
					gradient.Offset = Vector2.new(math.sin(clock * 0.4 + curtain.Phase) * 0.15, 0)
					local fade = 1 - auroraStrength * (0.55 + 0.25 * math.sin(clock * 0.7 + curtain.Phase))
					gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, math.clamp(fade, 0, 1)), NumberSequenceKeypoint.new(0.75, math.clamp(fade + 0.2, 0, 1)), NumberSequenceKeypoint.new(1, 1) })
				end
			end
		end

		-- Fortschritt in der Stage
		local layout = if stage > 0 then layoutFor(stage) else nil
		progressBack.Visible = layout ~= nil and not inArena and UI.TimerPanel ~= nil and UI.TimerPanel.Visible
		if layout and Movement.RenderPosition then
			local startX, endX = layout.StartCenter.X, layout.FinishCenter.X
			progressFill.Size = UDim2.fromScale(math.clamp((Movement.RenderPosition.X - startX) / (endX - startX), 0, 1), 1)
		end

		-- Tempo-Trend (u/s pro Sekunde)
		table.insert(speedHistory, { clock, speed })
		while #speedHistory > 2 and clock - speedHistory[1][1] > 0.5 do
			table.remove(speedHistory, 1)
		end
		local first = speedHistory[1]
		local change = if first and clock - first[1] > 0.1 then (speed - first[2]) / (clock - first[1]) / SurfPhysics.Unit else 0
		trend.Visible = stage > 0 and math.abs(change) > 15 and UI.SpeedPanel ~= nil and UI.SpeedPanel.Visible
		trend.Text = string.format("%s%d/s", if change > 0 then "+" else "", math.floor(change + 0.5))
		trend.TextColor3 = if change > 0 then T.Mint else T.Red

		-- Statistik und Geist aufzeichnen
		if attempt and Movement.RenderPosition then
			attempt.Time += dt
			attempt.Top = math.max(attempt.Top, speed)
			if attempt.Last then
				local step = Movement.RenderPosition - attempt.Last
				attempt.Distance += Vector3.new(step.X, 0, step.Z).Magnitude
			end
			attempt.Last = Movement.RenderPosition
		end
		local elapsed = Movement.StageStart and Movement.GetStageTime()
		if recording and elapsed and Movement.RenderPosition and elapsed >= recording.Next then
			recording.Next = elapsed + 0.05
			table.insert(recording.Samples, { elapsed, Movement.RenderPosition, Movement.GetYaw() })
		end
		local ghost = ghosts[stage]
		if settings.Ghost ~= false and ghost and elapsed and not inArena then
			local samples = ghost.Samples
			local a, b = nil, nil
			for i = 2, #samples do
				if samples[i][1] >= elapsed then
					a, b = samples[i - 1], samples[i]
					break
				end
			end
			if a and b then
				local alpha = math.clamp((elapsed - a[1]) / math.max(1e-3, b[1] - a[1]), 0, 1)
				local pos = a[2]:Lerp(b[2], alpha)
				local cf = CFrame.new(pos) * CFrame.Angles(0, a[3], 0)
				ghostBody.CFrame = cf * CFrame.new(0, -0.6, 0)
				ghostHead.CFrame = cf * CFrame.new(0, 1.4, 0)
				ghostSkis.CFrame = cf * CFrame.new(0, -2.4, 0)
			else
				hideGhost()
			end
		else
			hideGhost()
		end
	end)
	switchSong()
end

return Update3
