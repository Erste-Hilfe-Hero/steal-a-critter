-- Erweiterungen auf dem Client: Minimap, Ball-Pfeil, Trefferanzeige, rote Bildschirmraender bei wenig
-- Leben, Kill-Cam, Tor-Kamera, Regen, grosser Anstoss-Countdown, Schussgeschwindigkeit, Publikumswelle
-- und -jubel, "Respawn Now"-Knopf sowie die Fenster Quests, Statistik, Schwerter und Einstellungen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local Extras = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local ball = workspace:WaitForChild("Ball") :: BasePart
local carrierValue = ball:WaitForChild("Carrier") :: ObjectValue
local Kit = UI.Kit
local C = Config.Colors
local BODY = Config.BodyFont
local SOFT = Color3.fromRGB(215, 222, 245)

local remote: RemoteEvent
local hooks = {} :: any
local settings = { Fov = 70, Crowd = 1, FirstPerson = true }

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function knockedOut(): boolean
	local character = player.Character
	return character ~= nil and (character:GetAttribute("KOUntil") or 0) > serverNow()
end

-- Eigene Bildschirm-Ebene ohne Rand oben (fuer Effekte, die am Bildschirm kleben)
local overlay = Kit.create("ScreenGui", { Name = "Extras", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 2, Parent = player:WaitForChild("PlayerGui") })

---------------------------------------------------------------- Kamera-Fahrten (Kill-Cam, Tor-Kamera)

local cinematicToken = 0
local function cinematic(seconds: number, getCFrame: (number) -> CFrame?)
	cinematicToken += 1
	local token = cinematicToken
	local started = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local cf = if token == cinematicToken and t < seconds then getCFrame(t) else nil
		if not cf then
			connection:Disconnect()
			if token == cinematicToken then
				camera.CameraType = Enum.CameraType.Custom
			end
			return
		end
		camera.CFrame = camera.CFrame:Lerp(cf, 0.2)
	end)
end

-- Kill-Cam: von oben auf den, der einen umgehauen hat
local function killCam(attacker: Model?)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not attacker or not head then
		return
	end
	local from = head.Position + Vector3.new(0, 10, 0)
	cinematic(3, function()
		local root = attacker:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or not root.Parent then
			return nil
		end
		local away = Vector3.new(from.X - root.Position.X, 0, from.Z - root.Position.Z)
		local position = root.Position + (if away.Magnitude > 1 then away.Unit else Vector3.zAxis) * 14 + Vector3.new(0, 7, 0)
		return CFrame.lookAt(position, root.Position)
	end)
end

-- Tor-Kamera: kurze Fahrt um den Ball im Netz
local function goalCam()
	local center = ball.Position
	cinematic(2.6, function(t)
		local angle = t * 0.9
		return CFrame.lookAt(center + Vector3.new(math.cos(angle) * 30, 12, math.sin(angle) * 30), center)
	end)
end

---------------------------------------------------------------- Minimap

local minimap: Frame
local dots = {} -- [Model] = Frame
local ballDot: Frame
local MAP_W, MAP_H = 170, 100

local function buildMinimap()
	minimap = Kit.create("Frame", {
		Position = UDim2.fromOffset(10, 104),
		Size = UDim2.fromOffset(MAP_W, MAP_H),
		BackgroundColor3 = Color3.fromRGB(60, 110, 50),
		BackgroundTransparency = 0.25,
		ClipsDescendants = true,
		Parent = UI.Root(),
	}, { Kit.corner(8), Kit.stroke(C.Navy, 2) })
	-- Mittellinie und Tore
	Kit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = C.White, BackgroundTransparency = 0.5, BorderSizePixel = 0, Parent = minimap })
	for _, team in Config.Teams do
		local side = if team.Side < 0 then 0 else 1
		local goalH = Config.GoalWidth / Config.FieldWidth
		Kit.create("Frame", { AnchorPoint = Vector2.new(side, 0.5), Position = UDim2.fromScale(side, 0.5), Size = UDim2.new(0, 3, goalH, 0), BackgroundColor3 = team.Color, BorderSizePixel = 0, Parent = minimap })
	end
	ballDot = Kit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BackgroundColor3 = C.White, ZIndex = 3, Parent = minimap }, { Kit.corner(3) })
end

local function mapPosition(position: Vector3): UDim2
	local x = math.clamp(position.X / Config.FieldLength + 0.5, 0, 1)
	local y = math.clamp(position.Z / Config.FieldWidth + 0.5, 0, 1)
	return UDim2.fromScale(x, y)
end

local function actorModels(): { Model }
	local list = {}
	for _, other in Players:GetPlayers() do
		if other.Character and other.Character:GetAttribute("Team") then
			table.insert(list, other.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, model in bots:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("Team") then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function updateMinimap()
	local seen = {}
	for _, model in actorModels() do
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			seen[model] = true
			local dot = dots[model]
			local own = model == player.Character
			if not dot then
				dot = Kit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(if own then 9 else 6, if own then 9 else 6), ZIndex = if own then 4 else 2, Parent = minimap }, {
					Kit.corner(5),
					Kit.stroke(if own then C.White else C.Navy, 1),
				})
				dots[model] = dot
			end
			local team = Config.Teams[model:GetAttribute("Team")]
			dot.BackgroundColor3 = if team then team.Color else C.White
			dot.Position = mapPosition(root.Position)
		end
	end
	for model, dot in dots do
		if not seen[model] then
			dot:Destroy()
			dots[model] = nil
		end
	end
	ballDot.Position = mapPosition(ball.Position)
end

---------------------------------------------------------------- Ball-Pfeil am Bildschirmrand

local arrow: TextLabel
local function buildArrow()
	arrow = Kit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Text = "▲", TextColor3 = C.White, Visible = false, Parent = overlay })
end

local function updateArrow()
	local character = player.Character
	if not character or carrierValue.Value == character then
		arrow.Visible = false
		return
	end
	local point, onScreen = camera:WorldToViewportPoint(ball.Position)
	local viewport = camera.ViewportSize
	if onScreen and point.Z > 0 and point.X > 0 and point.X < viewport.X and point.Y > 0 and point.Y < viewport.Y then
		arrow.Visible = false
		return
	end
	local p = camera.CFrame:PointToObjectSpace(ball.Position)
	local dir = Vector2.new(p.X, -p.Y)
	if dir.Magnitude < 0.01 then
		dir = Vector2.new(0, 1)
	end
	dir = dir.Unit
	local half = viewport / 2
	local scale = math.min((half.X - 40) / math.max(math.abs(dir.X), 0.001), (half.Y - 40) / math.max(math.abs(dir.Y), 0.001))
	local position = half + dir * scale
	arrow.Position = UDim2.fromOffset(position.X, position.Y)
	arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
	local carrier = carrierValue.Value
	local team = carrier and Config.Teams[carrier:GetAttribute("Team") or ""]
	arrow.TextColor3 = if team then team.Color else C.White
	arrow.Visible = true
end

---------------------------------------------------------------- Trefferanzeige und rote Raender

local hitMarker: Frame
local vignette: UIStroke

local function buildHitMarker()
	hitMarker = Kit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Visible = false, Parent = overlay })
	for _, angle in { 45, -45 } do
		Kit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(3, 30), Rotation = angle, BackgroundColor3 = C.White, BorderSizePixel = 0, Parent = hitMarker })
	end
	local frame = Kit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = overlay })
	vignette = Kit.create("UIStroke", { Thickness = 70, Color = Color3.fromRGB(200, 0, 0), Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame })
end

local hitToken = 0
local function showHit(heavy: boolean)
	hitToken += 1
	local token = hitToken
	for _, line in hitMarker:GetChildren() do
		(line :: Frame).BackgroundColor3 = if heavy then C.Red else C.White
	end
	hitMarker.Visible = true
	Sounds.Play("HitMarker")
	task.delay(0.18, function()
		if token == hitToken then
			hitMarker.Visible = false
		end
	end)
end

local function updateVignette()
	local character = player.Character
	local hp = character and character:GetAttribute("HP")
	local maxHP = character and character:GetAttribute("MaxHP") or Config.MaxHP
	local fraction = if hp then hp / maxHP else 1
	if fraction < 0.35 and not knockedOut() then
		local pulse = (math.sin(os.clock() * 6) + 1) / 2
		vignette.Transparency = 0.35 + fraction + pulse * 0.2
	else
		vignette.Transparency = 1
	end
end

---------------------------------------------------------------- Regen

local rainPart: Part?
local function updateRain()
	local raining = workspace:GetAttribute("Weather") == "Rain"
	if raining and not rainPart then
		local p = Instance.new("Part")
		p.Name = "LocalRain"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(140, 1, 140)
		local emitter = Instance.new("ParticleEmitter")
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Rate = 700
		emitter.Speed = NumberRange.new(90, 110)
		emitter.Lifetime = NumberRange.new(0.6, 0.8)
		emitter.Size = NumberSequence.new(0.12)
		emitter.Squash = NumberSequence.new(4)
		emitter.Color = ColorSequence.new(Color3.fromRGB(190, 210, 235))
		emitter.Transparency = NumberSequence.new(0.35)
		emitter.LightInfluence = 1
		emitter.Parent = p
		p.Parent = workspace
		rainPart = p
	elseif not raining and rainPart then
		rainPart:Destroy()
		rainPart = nil
	end
	if rainPart then
		rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 45, 0))
	end
end

---------------------------------------------------------------- Anstoss-Countdown, Schussgeschwindigkeit, Respawn-Knopf

local bigNumber: TextLabel
local shotLabel: TextLabel
local respawnFrame: Frame
local respawnText: TextLabel

local function buildCenter()
	bigNumber = Kit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(300, 200), Text = "", TextColor3 = C.Lime, StrokeThickness = 6, Visible = false, Parent = UI.Root() })
	shotLabel = Kit.label({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(300, 40), Text = "", TextColor3 = C.Orange, Visible = false, Parent = UI.Root() })
	respawnFrame = Kit.create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(300, 100), BackgroundTransparency = 1, Visible = false, Parent = UI.Root() })
	respawnText = Kit.label({ Size = UDim2.new(1, 0, 0, 36), Text = "", Parent = respawnFrame })
	local buy = Kit.button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 42), Size = UDim2.fromOffset(260, 52), Text = "" }, Kit.GREEN)
	buy.Parent = respawnFrame
	buy.MouseButton1Click:Connect(function()
		UI.Buy("Product", "RespawnNow")
	end)
	UI.AddRefresher(function()
		buy.Text = `RESPAWN NOW  R$ {Kit.price("RespawnNow", Config.DevProducts.RespawnNow.PriceHint)}`
	end)
	buy.Text = `RESPAWN NOW  R$ {Config.DevProducts.RespawnNow.PriceHint}`
end

local lastCount = 0
local function updateCenter()
	local state = workspace:GetAttribute("MatchState")
	if state == "Kickoff" then
		local remaining = math.ceil((workspace:GetAttribute("StateEnds") or 0) - serverNow())
		if remaining >= 1 and remaining <= 3 then
			if remaining ~= lastCount then
				lastCount = remaining
				bigNumber.Text = tostring(remaining)
				bigNumber.TextColor3 = if remaining == 1 then C.Orange else C.Lime
				bigNumber.Visible = true
				Kit.pop(bigNumber)
			end
		else
			bigNumber.Visible = false
		end
	elseif lastCount ~= 0 then
		lastCount = 0
		if state == "Playing" then
			bigNumber.Text = "GO!"
			bigNumber.TextColor3 = C.Lime
			bigNumber.Visible = true
			Kit.pop(bigNumber)
			task.delay(0.8, function()
				if bigNumber.Text == "GO!" then
					bigNumber.Visible = false
				end
			end)
		else
			bigNumber.Visible = false
		end
	end
	-- K.O.: Countdown und Sofort-Respawn
	local character = player.Character
	local left = character and (character:GetAttribute("KOUntil") or 0) - serverNow() or 0
	respawnFrame.Visible = left > 1.5
	if respawnFrame.Visible then
		respawnText.Text = `BACK IN {math.ceil(left)}s`
	end
end

local shotToken = 0
local function showShotSpeed(kmh: number)
	shotToken += 1
	local token = shotToken
	shotLabel.Text = `{kmh} KM/H`
	shotLabel.TextColor3 = if kmh >= 150 then C.Red elseif kmh >= 100 then C.Orange else C.White
	shotLabel.Visible = true
	Kit.pop(shotLabel)
	task.delay(1.4, function()
		if token == shotToken then
			shotLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------- Publikum: Welle beim Tor, lauter vor dem Tor

local fans: { BasePart }? = nil
local fanBase: { CFrame } = {}
local waving = false

local function crowdWave()
	if waving then
		return
	end
	if not fans then
		local list = {}
		local arena = workspace:FindFirstChild("Arena")
		local stands = arena and arena:FindFirstChild("Stands")
		if stands then
			for _, p in stands:GetChildren() do
				if p:IsA("BasePart") and p.Name == "Fan" then
					table.insert(list, p)
					table.insert(fanBase, p.CFrame)
				end
			end
		end
		fans = list
	end
	local list = fans :: { BasePart }
	if #list == 0 then
		return
	end
	waving = true
	local started = os.clock()
	local DURATION, SPAN = 3, Config.FieldLength + 120
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local t = (os.clock() - started) / DURATION
		local targets = table.create(#list)
		local front = -SPAN / 2 + SPAN * math.min(t, 1)
		for i, base in fanBase do
			local d = math.abs(base.Position.X - front)
			local lift = if t < 1 and d < 14 then math.cos(d / 14 * math.pi / 2) * 2.5 else 0
			targets[i] = base + Vector3.new(0, lift, 0)
		end
		workspace:BulkMoveTo(list, targets, Enum.BulkMoveMode.FireCFrameChanged)
		if t >= 1 then
			connection:Disconnect()
			waving = false
		end
	end)
end

local function updateSwell()
	local edge = Config.FieldLength / 2 - 60
	local x = math.abs(ball.Position.X)
	local swell = if x > edge then 1 + math.clamp((x - edge) / 60, 0, 1) * 1.6 else 1
	Sounds.SetCrowdSwell(swell)
end

---------------------------------------------------------------- Fenster: Quests

local questList: Frame
local function buildQuests()
	local _, body = Kit.window("Quests", "DAILY QUESTS", Vector2.new(560, 420))
	Kit.label({ Size = UDim2.new(1, 0, 0, 30), Text = "New quests every day. Quest Master: double coins + a 4th quest!", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = body })
	questList = Kit.create("Frame", { Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -100), BackgroundTransparency = 1, Parent = body }, {
		Kit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local master = Kit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(300, 48), Text = "" }, C.Orange)
	master.Parent = body
	master.MouseButton1Click:Connect(function()
		UI.Buy("Pass", "QuestMaster")
	end)
	UI.AddRefresher(function()
		local owned = Config.Has(player, "QuestMaster")
		master.Visible = not owned
		master.Text = `QUEST MASTER  R$ {Kit.price("QuestMaster", Config.GamePasses.QuestMaster.PriceHint)}`
	end)
end

local function showQuests(list)
	for _, child in questList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for i, quest in list do
		local row = Kit.create("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.NavyLight, LayoutOrder = i, Parent = questList }, {
			Kit.corner(10),
			Kit.stroke(if quest.Done then C.Lime else C.Navy, 2),
		})
		Kit.label({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -140, 0, 26), Text = quest.Text, TextXAlignment = Enum.TextXAlignment.Left, Font = BODY, Parent = row })
		local back = Kit.create("Frame", { Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -140, 0, 12), BackgroundColor3 = C.Navy, Parent = row }, { Kit.corner(6) })
		Kit.create("Frame", { Size = UDim2.fromScale(math.clamp(quest.Progress / quest.Goal, 0, 1), 1), BackgroundColor3 = C.Lime, Parent = back }, { Kit.corner(6) })
		Kit.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 30), Text = if quest.Done then "DONE ✓" else `{quest.Progress}/{quest.Goal}  +{quest.Coins}`, TextColor3 = if quest.Done then C.Lime else C.Gold, Parent = row })
	end
end

---------------------------------------------------------------- Fenster: Statistik

local statLabels = {}
local STATS = { "Level", "Goals", "Assists", "KOs", "Steals", "Saves", "Wins", "Matches", "WinStreak" }
local function buildStats()
	local _, body = Kit.window("Stats", "CAREER STATS", Vector2.new(560, 420))
	local title = Kit.label({ Size = UDim2.new(1, 0, 0, 34), Text = "", TextColor3 = C.Gold, Parent = body })
	statLabels.Title = title
	local holder = Kit.create("Frame", { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), BackgroundTransparency = 1, Parent = body }, {
		Kit.create("UIGridLayout", { CellSize = UDim2.fromOffset(166, 92), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, key in STATS do
		local cell = Kit.create("Frame", { BackgroundColor3 = C.NavyLight, LayoutOrder = i, Parent = holder }, { Kit.corner(10) })
		Kit.label({ Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 22), Text = if key == "WinStreak" then "WIN STREAK" else string.upper(key), Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = cell })
		statLabels[key] = Kit.label({ Position = UDim2.fromOffset(6, 32), Size = UDim2.new(1, -12, 0, 50), Text = "-", TextColor3 = C.Lime, Parent = cell })
	end
end

local function showStats(info)
	statLabels.Title.Text = `TITLE: {string.upper(info.Title or "Rookie")}`
	for _, key in STATS do
		statLabels[key].Text = Format.Number(info[key] or 0)
	end
end

---------------------------------------------------------------- Fenster: Schwerter

local skinState = { Owned = { classic = true }, Equipped = "classic" }
local skinButtons = {}

local function refreshSkins()
	for id, entry in skinButtons do
		local skin = entry.Skin
		local owned = skinState.Owned[id] or (skin.Pass and Config.Has(player, skin.Pass))
		if skinState.Equipped == id then
			entry.Button.Text = "EQUIPPED"
			entry.Button.BackgroundColor3 = C.NavyLight
		elseif owned then
			entry.Button.Text = "EQUIP"
			entry.Button.BackgroundColor3 = C.Cyan
		elseif skin.Pass then
			entry.Button.Text = "SWORD PACK"
			entry.Button.BackgroundColor3 = C.Orange
		else
			entry.Button.Text = `{Format.Number(skin.Price)} COINS`
			entry.Button.BackgroundColor3 = C.Gold
		end
	end
end

local function buildSwords()
	local _, body = Kit.window("Swords", "KATANA SKINS", Vector2.new(600, 470))
	Kit.label({ Size = UDim2.new(1, 0, 0, 40), Text = "Pick the blade everyone sees in your hand", Font = BODY, TextColor3 = SOFT, StrokeThickness = 0, Parent = body })
	local page = Kit.grid(body)
	for i, skin in Config.SwordSkins do
		local frame, buy = Kit.card(page, i, string.upper(skin.Name), "", skin.Color)
		local blade = Kit.create("Frame", { Position = UDim2.fromOffset(16, 70), Size = UDim2.new(1, -32, 0, 12), Rotation = -12, BackgroundColor3 = skin.Color, Parent = frame }, { Kit.corner(6), Kit.stroke(C.Navy, 2) })
		blade.ZIndex = 2
		Kit.create("Frame", { Position = UDim2.fromOffset(16, 66), Size = UDim2.fromOffset(30, 20), Rotation = -12, BackgroundColor3 = Color3.fromRGB(25, 25, 28), Parent = frame }, { Kit.corner(4) }).ZIndex = 3
		buy.MouseButton1Click:Connect(function()
			if skin.Pass and not Config.Has(player, skin.Pass) and not skinState.Owned[skin.Id] then
				UI.ShowOffer(skin.Pass)
			else
				remote:FireServer("Skin", skin.Id)
			end
		end)
		skinButtons[skin.Id] = { Button = buy, Skin = skin }
	end
	UI.AddRefresher(refreshSkins)
end

---------------------------------------------------------------- Fenster: Einstellungen

local settingLabels = {} :: any
local function sendSettings()
	remote:FireServer("Settings", settings)
end

local function applySettings()
	settingLabels.Fov.Text = tostring(settings.Fov)
	settingLabels.Crowd.Text = `{math.floor(settings.Crowd * 100)}%`
	settingLabels.FirstPerson.Text = if settings.FirstPerson then "FIRST PERSON" else "THIRD PERSON"
	Sounds.SetCrowdVolume(settings.Crowd)
	if hooks.SetFov then
		hooks.SetFov(settings.Fov)
	end
end

local function buildSettings()
	local _, body = Kit.window("Settings", "SETTINGS", Vector2.new(480, 360))
	Kit.create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = body })
	local function row(order: number, title: string, key: string, onMinus: (() -> ())?, onPlus: (() -> ())?, onToggle: (() -> ())?)
		local frame = Kit.create("Frame", { Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C.NavyLight, LayoutOrder = order, Parent = body }, { Kit.corner(10) })
		Kit.label({ Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
		if onToggle then
			local b = Kit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(220, 46), Text = "" }, C.Cyan)
			b.Parent = frame
			b.MouseButton1Click:Connect(onToggle)
			settingLabels[key] = b
			return
		end
		local minus = Kit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -170, 0.5, 0), Size = UDim2.fromOffset(50, 46), Text = "-" }, C.Orange)
		minus.Parent = frame
		minus.MouseButton1Click:Connect(onMinus :: () -> ())
		settingLabels[key] = Kit.label({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.fromOffset(100, 40), Text = "", Parent = frame })
		local plus = Kit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(50, 46), Text = "+" }, C.Lime)
		plus.Parent = frame
		plus.MouseButton1Click:Connect(onPlus :: () -> ())
	end
	local function change(key: string, delta: number, low: number, high: number)
		return function()
			settings[key] = math.clamp(settings[key] + delta, low, high)
			applySettings()
			sendSettings()
		end
	end
	row(1, "FIELD OF VIEW", "Fov", change("Fov", -5, 60, 100), change("Fov", 5, 60, 100))
	row(2, "CROWD", "Crowd", change("Crowd", -0.25, 0, 1), change("Crowd", 0.25, 0, 1))
	row(3, "START VIEW", "FirstPerson", nil, nil, function()
		settings.FirstPerson = not settings.FirstPerson
		applySettings()
		sendSettings()
		if hooks.SetFirstPerson then
			hooks.SetFirstPerson(settings.FirstPerson)
		end
	end)
	applySettings()
end

---------------------------------------------------------------- Start

-- hooks: SetFov(number), SetFirstPerson(boolean) aus dem Haupt-Client
function Extras.Start(newHooks)
	hooks = newHooks
	remote = remotes:WaitForChild("Extras") :: RemoteEvent
	buildMinimap()
	buildArrow()
	buildHitMarker()
	buildCenter()
	buildQuests()
	buildStats()
	buildSwords()
	buildSettings()

	UI.AddMenuItem("QUESTS", C.Gold, 5, function()
		remote:FireServer("Quests")
		UI.Open("Quests")
	end).TextColor3 = C.Navy
	UI.AddMenuItem("STATS", Color3.fromRGB(170, 120, 255), 6, function()
		remote:FireServer("Stats")
		UI.Open("Stats")
	end)
	UI.AddMenuItem("SWORDS", C.Red, 7, function()
		UI.Open("Swords")
	end)
	UI.AddMenuItem("SETUP", Kit.PANEL, 8, function()
		UI.Open("Settings")
	end)

	remote.OnClientEvent:Connect(function(kind, info)
		if kind == "Quests" then
			showQuests(info)
		elseif kind == "Stats" then
			showStats(info)
		elseif kind == "Skins" then
			skinState = info
			refreshSkins()
		elseif kind == "Settings" and typeof(info) == "table" then
			settings.Fov = tonumber(info.Fov) or 70
			settings.Crowd = tonumber(info.Crowd) or 1
			settings.FirstPerson = info.FirstPerson ~= false
			applySettings()
			if hooks.SetFirstPerson then
				hooks.SetFirstPerson(settings.FirstPerson)
			end
		elseif kind == "ShotSpeed" then
			showShotSpeed(info)
		end
	end)

	remotes.MatchEvent.OnClientEvent:Connect(function(kind, info)
		if kind == "Damage" then
			if info.Attacker and info.Attacker == player.Character then
				showHit(info.Backstab)
			end
		elseif kind == "KO" then
			if info.VictimModel == player.Character then
				task.delay(0.3, killCam, info.AttackerModel)
			end
		elseif kind == "Goal" then
			crowdWave()
			task.delay(0.4, goalCam)
		end
	end)
	player:GetAttributeChangedSignal("SwordSkin"):Connect(refreshSkins)

	RunService.RenderStepped:Connect(function()
		updateArrow()
		updateVignette()
	end)
	task.spawn(function()
		while true do
			pcall(updateMinimap)
			pcall(updateCenter)
			pcall(updateRain)
			pcall(updateSwell)
			task.wait(0.1)
		end
	end)
end

return Extras
