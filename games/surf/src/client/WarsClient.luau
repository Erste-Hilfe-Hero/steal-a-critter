-- Update 3 auf dem Client: "Snowball Wars". Zielen, Werfen/Schiessen, Treffer melden, Anzeige
-- (Punkte, Rundenzeit, Kaelte-Punkte, Waffe, Munition, Fadenkreuz, Abschussliste) und Effekte.
-- Der Server prueft jeden gemeldeten Treffer selbst (ArenaService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Sounds = require(ReplicatedStorage.Shared.Sounds)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local camera = workspace.CurrentCamera
local T = Config.Theme

local WarsClient = {}

local sounds = {}
local function playSound(name: string, volume: number?, speed: number?)
	local id = Sounds.Id(name)
	if id == "" then
		return
	end
	local sound = sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = SoundService
		sounds[name] = sound
	end
	sound.Volume = volume or 0.6
	sound.PlaybackSpeed = speed or 1
	SoundService:PlayLocalSound(sound)
end

-- Gegner (Spieler und Bots) mit Schluessel und Mitte der Hitbox
local function enemies(myTeam: string)
	local list = {}
	for _, other in Players:GetPlayers() do
		local team = other:GetAttribute("ArenaTeam")
		if other ~= player and team and team ~= myTeam and not other:GetAttribute("WarFrozen") then
			local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				table.insert(list, { Key = "p" .. other.UserId, Position = root.Position })
			end
		end
	end
	local bots = workspace:FindFirstChild("WarBots")
	if bots then
		for _, model in bots:GetChildren() do
			if model:GetAttribute("Team") ~= myTeam and not model:GetAttribute("Frozen") and model.PrimaryPart then
				table.insert(list, { Key = model:GetAttribute("Key"), Position = model.PrimaryPart.Position })
			end
		end
	end
	return list
end

local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
worldParams.RespectCanCollide = true

local function worldHit(origin: Vector3, delta: Vector3)
	local exclude = { workspace:FindFirstChild("WarBots") or workspace.Terrain, workspace:FindFirstChild("Zones") or workspace.Terrain }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	worldParams.FilterDescendantsInstances = exclude
	return workspace:Raycast(origin, delta, worldParams)
end

function WarsClient.Start(UI, Movement)
	local K = UI.Kit
	local create, text, panel, button, corner = K.create, K.text, K.panel, K.button, K.corner
	local gui = K.gui

	------------------------------------------------ Anzeige

	local hud = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local scorePanel = panel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(380, 78), Parent = hud })
	local frostScore = text({ Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(120, 40), Text = "0", TextColor3 = Arena.TeamById.Frost.Color, FontFace = K.HEAVY, Parent = scorePanel })
	local auroraScore = text({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 8), Size = UDim2.fromOffset(120, 40), Text = "0", TextColor3 = Arena.TeamById.Aurora.Color, FontFace = K.HEAVY, Parent = scorePanel })
	text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(110, 16), Text = "SNOWBALL WARS", TextColor3 = T.Muted, FontFace = K.HEAVY, Parent = scorePanel })
	local clock = text({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 28), Size = UDim2.fromOffset(110, 24), Text = "", FontFace = K.MONO, Parent = scorePanel })
	local teamLine = text({ Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -24, 0, 16), Text = "", FontFace = K.BOLD, Parent = scorePanel })

	local statusPanel = panel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.fromOffset(300, 54), Parent = hud })
	local hpBack = create("Frame", { Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 12), BackgroundColor3 = T.Navy, Parent = statusPanel })
	corner(6).Parent = hpBack
	local hpBar = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.Ice, Parent = hpBack })
	corner(6).Parent = hpBar
	local weaponLabel = text({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 18), Text = "", FontFace = K.HEAVY, Parent = statusPanel })

	-- Fadenkreuz
	local cross = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, Parent = hud })
	for _, bar in { { UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 0, 0) }, { UDim2.fromOffset(2, 8), UDim2.new(0.5, -1, 1, -8) }, { UDim2.fromOffset(8, 2), UDim2.new(0, 0, 0.5, -1) }, { UDim2.fromOffset(8, 2), UDim2.new(1, -8, 0.5, -1) } } do
		create("Frame", { Size = bar[1], Position = bar[2], BackgroundColor3 = T.Snow, BorderSizePixel = 0, Parent = cross })
	end
	local hitMarker = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(40, 40), Text = "X", TextColor3 = T.Gold, TextTransparency = 1, FontFace = K.HEAVY, Parent = hud })

	-- Grosse Mitte-Ansagen (Countdown, Sieg, eingefroren)
	local big = text({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(620, 64), Text = "", TextTransparency = 1, FontFace = K.HEAVY, Parent = hud })
	local bigStroke = create("UIStroke", { Color = T.Navy, Thickness = 3, Transparency = 1, Parent = big })
	local function shout(message: string, color: Color3?, seconds: number?)
		big.Text = message
		big.TextColor3 = color or T.Snow
		big.TextTransparency = 0
		bigStroke.Transparency = 0.2
		local token = {}
		big:SetAttribute("Token", tostring(token))
		task.delay(seconds or 1.6, function()
			if big:GetAttribute("Token") == tostring(token) then
				TweenService:Create(big, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
				TweenService:Create(bigStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end)
	end
	local frozenOverlay = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 210, 255), BackgroundTransparency = 1, ZIndex = 0, Parent = hud })

	-- Abschussliste oben rechts
	local feed = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 52), Size = UDim2.fromOffset(330, 150), BackgroundTransparency = 1, Parent = hud })
	create("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = feed })
	local feedOrder = 0
	local function addFeed(message: string, color: Color3)
		feedOrder += 1
		local row = panel({ Size = UDim2.fromOffset(330, 26), Radius = 8, LayoutOrder = feedOrder, Parent = feed })
		text({ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 1, -8), Text = message, TextColor3 = color, FontFace = K.BOLD, TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		local rows = {}
		for _, child in feed:GetChildren() do
			if child:IsA("Frame") then
				table.insert(rows, child)
			end
		end
		if #rows > 5 then
			table.sort(rows, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			rows[1]:Destroy()
		end
		task.delay(6, function()
			if row.Parent then
				row:Destroy()
			end
		end)
	end

	-- Knoepfe: Waffe wechseln, Feuer (Handy), Arena verlassen
	local selected = "Snowball"
	local function carried(): string?
		local weapon = player:GetAttribute("WarWeapon")
		return if weapon and weapon ~= "Snowball" and (player:GetAttribute("WarAmmo") or 0) > 0 then weapon else nil
	end
	local swapButton = button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -132, 1, -150), Size = UDim2.fromOffset(96, 40), Text = "SWAP (Q)", Parent = hud }, function()
		selected = if selected == "Snowball" then (carried() or "Snowball") else "Snowball"
	end)
	local firing = false
	local fireButton
	if UserInputService.TouchEnabled then
		swapButton.Text = "SWAP"
		fireButton = create("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -24, 1, -140), Size = UDim2.fromOffset(96, 96), BackgroundColor3 = T.Aurora, BackgroundTransparency = 0.2, Text = "FIRE", TextColor3 = T.Navy, FontFace = K.HEAVY, TextScaled = true, AutoButtonColor = false, Parent = hud })
		corner(48).Parent = fireButton
		create("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), Parent = fireButton })
		fireButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				firing = true
			end
		end)
		fireButton.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				firing = false
			end
		end)
	end
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 212), Size = UDim2.fromOffset(96, 36), Text = "LEAVE", Color = T.Red, Parent = hud }, function()
		remotes.Wars:FireServer("Leave")
	end)

	-- Knopf in der linken Leiste (zusaetzlich zum Tor in der Lobby)
	if UI.LeftBar then
		button({ Size = UDim2.fromOffset(84, 46), Text = "WARS", Color = T.Aurora, TextColor3 = T.Navy, LayoutOrder = 7, Parent = UI.LeftBar }, function()
			if player:GetAttribute("ArenaTeam") then
				remotes.Wars:FireServer("Leave")
			else
				remotes.Wars:FireServer("Join")
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not player:GetAttribute("ArenaTeam") then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			firing = true
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then
			selected = if selected == "Snowball" then (carried() or "Snowball") else "Snowball"
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if not UserInputService.TouchEnabled or not fireButton then
				firing = false
			end
		end
	end)

	------------------------------------------------ Schuesse zeichnen

	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "WarFx"
	fxFolder.Parent = workspace
	local function ball(color: Color3, size: number, neon: boolean): BasePart
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(size, size, size)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = color
		p.Material = if neon then Enum.Material.Neon else Enum.Material.Snow
		p.Parent = fxFolder
		return p
	end
	local function beam(from: Vector3, to: Vector3, color: Color3, width: number)
		local length = (to - from).Magnitude
		if length < 0.1 then
			return
		end
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = Vector3.new(width, width, length)
		p.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
		p.Parent = fxFolder
		TweenService:Create(p, TweenInfo.new(0.18), { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, length) }):Play()
		task.delay(0.2, function()
			p:Destroy()
		end)
	end
	local function puff(at: Vector3, color: Color3, size: number)
		local p = ball(color, size, false)
		p.CFrame = CFrame.new(at)
		p.Transparency = 0.2
		TweenService:Create(p, TweenInfo.new(0.35), { Size = Vector3.new(size * 3, size * 3, size * 3), Transparency = 1 }):Play()
		task.delay(0.4, function()
			p:Destroy()
		end)
	end

	-- Fliegende Projektile (eigene melden Treffer, fremde sind nur Bild)
	local flying = {}
	local function launch(weaponId: string, origin: Vector3, direction: Vector3, shotId: number?, myTeam: string?)
		local weapon = Arena.Weapons[weaponId]
		local p = ball(weapon.Color, if weaponId == "SlushBomb" then 1.6 else 1.1, weaponId == "SlushBomb")
		p.CFrame = CFrame.new(origin)
		table.insert(flying, { Part = p, Weapon = weaponId, Position = origin, Velocity = direction * weapon.Speed, Age = 0, ShotId = shotId, Team = myTeam })
	end
	RunService.RenderStepped:Connect(function(dt)
		for i = #flying, 1, -1 do
			local shot = flying[i]
			local weapon = Arena.Weapons[shot.Weapon]
			shot.Age += dt
			local nextVelocity = shot.Velocity - Vector3.new(0, weapon.Gravity * dt, 0)
			local delta = (shot.Velocity + nextVelocity) * 0.5 * dt
			shot.Velocity = nextVelocity
			local hitPoint, targetKey = nil, nil
			if shot.ShotId and delta.Magnitude > 0 then
				for _, enemy in enemies(shot.Team) do
					local d = Arena.RaySphere(shot.Position, delta.Unit, enemy.Position, Arena.HitRadius)
					if d and d <= delta.Magnitude then
						hitPoint, targetKey = shot.Position + delta.Unit * d, enemy.Key
						break
					end
				end
			end
			if not hitPoint then
				local wall = worldHit(shot.Position, delta)
				if wall then
					hitPoint = wall.Position
				end
			end
			shot.Position += delta
			shot.Part.CFrame = CFrame.new(shot.Position)
			if hitPoint or shot.Age > 5 then
				if hitPoint then
					puff(hitPoint, weapon.Color, if weapon.Splash then 4 else 1.4)
					if weapon.Splash then
						playSound("sfx_splat", 0.8, 0.7)
					end
				end
				if shot.ShotId and hitPoint and (targetKey or weapon.Splash) then
					remotes.Wars:FireServer("Impact", shot.ShotId, targetKey, hitPoint)
				end
				shot.Part:Destroy()
				table.remove(flying, i)
			end
		end
		-- Waffen-Kristalle drehen sich
		local pickupFolder = workspace:FindFirstChild("WarPickups")
		if pickupFolder and hud.Visible then
			local spin = CFrame.Angles(0, dt * 1.5, 0)
			for _, crystal in pickupFolder:GetChildren() do
				if crystal:IsA("BasePart") then
					crystal.CFrame = CFrame.new(crystal.Position) * spin * crystal.CFrame.Rotation
				end
			end
		end
	end)

	------------------------------------------------ Zielen und Feuern

	local shotCounter = 0
	local lastFire = 0
	local function aimPoint(myTeam: string, range: number): Vector3
		local origin = camera.CFrame.Position
		local look = camera.CFrame.LookVector
		-- Zielhilfe (Handy und Einstellung): naechster Gegner nahe am Fadenkreuz
		local assist = UserInputService.TouchEnabled or Movement.Assist
		local best, bestAngle = nil, math.rad(if assist then 7 else 0)
		for _, enemy in enemies(myTeam) do
			local to = enemy.Position - origin
			if to.Magnitude < range then
				local angle = math.acos(math.clamp(to.Unit:Dot(look), -1, 1))
				if angle < bestAngle and not worldHit(origin, to * 0.98) then
					best, bestAngle = enemy.Position, angle
				end
			end
		end
		if best then
			return best
		end
		local wall = worldHit(origin, look * range)
		local point = if wall then wall.Position else origin + look * range
		for _, enemy in enemies(myTeam) do
			local d = Arena.RaySphere(origin, look, enemy.Position, Arena.HitRadius)
			if d and d < (point - origin).Magnitude then
				point = origin + look * d
			end
		end
		return point
	end

	local function fire()
		local myTeam = player:GetAttribute("ArenaTeam")
		if not myTeam or player:GetAttribute("WarFrozen") or Movement.UiOpen then
			return
		end
		if selected ~= "Snowball" and not carried() then
			selected = "Snowball"
		end
		local weaponId = selected
		local weapon = Arena.Weapons[weaponId]
		local now = os.clock()
		if now - lastFire < weapon.Cooldown then
			return
		end
		lastFire = now
		local origin = Movement.GetFocus()
		local target = aimPoint(myTeam, weapon.Range)
		if weapon.Kind == "Projectile" then
			-- Bogen ausgleichen: etwas hoeher zielen, je weiter das Ziel
			local distance = (target - origin).Magnitude
			local travel = distance / weapon.Speed
			target += Vector3.new(0, 0.5 * weapon.Gravity * travel * travel, 0)
		end
		local direction = (target - origin).Unit
		shotCounter += 1
		local claimed = nil
		if weapon.Kind == "Projectile" then
			launch(weaponId, origin, direction, shotCounter, myTeam)
		else
			claimed = {}
			local directions = { direction }
			if weapon.Kind == "Spread" then
				directions = {}
				for i = 1, weapon.Pellets do
					table.insert(directions, Arena.SpreadDirection(direction, i, weapon.Pellets, weapon.Spread))
				end
			end
			local wall = worldHit(origin, direction * weapon.Range)
			local wallDistance = if wall then wall.Distance else weapon.Range
			for _, dir in directions do
				local bestKey, bestDistance = nil, wallDistance
				for _, enemy in enemies(myTeam) do
					local d = Arena.RaySphere(origin, dir, enemy.Position, Arena.HitRadius)
					if d and d < bestDistance then
						bestKey, bestDistance = enemy.Key, d
					end
				end
				if bestKey and not table.find(claimed, bestKey) then
					table.insert(claimed, bestKey)
				end
				beam(origin, origin + dir * bestDistance, weapon.Color, if weaponId == "FrostSniper" then 0.5 else 0.25)
			end
		end
		playSound(weapon.Sound, 0.5, if weaponId == "FrostSniper" then 0.7 else 1)
		remotes.Wars:FireServer("Fire", weaponId, origin, direction, shotCounter, claimed)
	end

	------------------------------------------------ Ereignisse vom Server

	remotes.WarsEvent.OnClientEvent:Connect(function(kind, a, b, c, d, e, f, g)
		if kind == "Shot" then
			local weapon = Arena.Weapons[b]
			if weapon and typeof(c) == "Vector3" and typeof(d) == "Vector3" then
				if weapon.Kind == "Projectile" then
					launch(b, c, d, nil, nil)
				else
					local wall = worldHit(c, d * weapon.Range)
					beam(c, if wall then wall.Position else c + d * math.min(weapon.Range, 200), weapon.Color, 0.25)
				end
				if (c - camera.CFrame.Position).Magnitude < 90 then
					playSound(weapon.Sound, 0.25)
				end
			end
		elseif kind == "Frozen" then
			local killer, killerTeam, victim, victimTeam, weaponId, at = a, b, c, d, e, f
			local weapon = Arena.Weapons[weaponId]
			local killerColor = Arena.TeamById[killerTeam] and Arena.TeamById[killerTeam].Color or T.Snow
			local victimColor = Arena.TeamById[victimTeam] and Arena.TeamById[victimTeam].Color or T.Snow
			local _ = victimColor
			addFeed(if killer ~= "" then `{killer}  [{weapon and weapon.Name or "?"}]  {victim}` else `{victim} froze`, killerColor)
			if typeof(at) == "Vector3" and (at - camera.CFrame.Position).Magnitude < 120 then
				playSound("sfx_freeze", 0.6)
			end
			if victim == player.DisplayName and victimTeam == player:GetAttribute("ArenaTeam") then
				shout("FROZEN!  back to base...", T.Ice, Arena.FrozenSeconds)
			end
		elseif kind == "Knock" and typeof(a) == "Vector3" then
			Movement.AddVelocity(a)
		elseif kind == "HitConfirm" then
			hitMarker.TextTransparency = 0
			hitMarker.TextColor3 = if c then T.Aurora else T.Gold
			TweenService:Create(hitMarker, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			playSound("sfx_splat", 0.5, if c then 0.8 else 1.2)
			-- Schadenszahl ueber dem Ziel
			if typeof(b) == "Vector3" then
				local anchor = Instance.new("Part")
				anchor.Anchored = true
				anchor.CanCollide = false
				anchor.CanQuery = false
				anchor.Transparency = 1
				anchor.Size = Vector3.new(0.2, 0.2, 0.2)
				anchor.CFrame = CFrame.new(b + Vector3.new(0, 3, 0))
				anchor.Parent = fxFolder
				local billboard = create("BillboardGui", { Size = UDim2.fromOffset(80, 30), AlwaysOnTop = true, Parent = anchor })
				local number = text({ Size = UDim2.fromScale(1, 1), Text = tostring(a), TextColor3 = if c then T.Aurora else T.Gold, FontFace = K.HEAVY, Parent = billboard })
				create("UIStroke", { Thickness = 2, Color = T.Navy, Parent = number })
				TweenService:Create(anchor, TweenInfo.new(0.8), { CFrame = anchor.CFrame + Vector3.new(0, 3, 0) }):Play()
				TweenService:Create(number, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
				task.delay(0.85, function()
					anchor:Destroy()
				end)
			end
			if c then
				shout("FROZE AN ENEMY!  +" .. Arena.Rewards.Freeze .. " Snowflakes", T.Gold, 1.2)
			end
		elseif kind == "Pickup" then
			local weapon = Arena.Weapons[a]
			if weapon then
				selected = a
				playSound("sfx_pickup", 0.7)
				K.toast(`{string.upper(weapon.Name)}  -  {weapon.Ammo} shots`, weapon.Color, 2)
			end
		elseif kind == "Splash" and typeof(a) == "Vector3" then
			puff(a, Arena.Weapons.SlushBomb.Color, 5)
		elseif kind == "Countdown" then
			if player:GetAttribute("ArenaTeam") then
				playSound("sfx_countdown", 0.5)
				for i = a, 1, -1 do
					task.delay(a - i, function()
						shout(tostring(i), T.Gold, 0.9)
					end)
				end
			end
		elseif kind == "RoundStart" then
			if player:GetAttribute("ArenaTeam") then
				shout("GO!  FREEZE THE OTHER TEAM", T.Mint, 1.6)
			end
		elseif kind == "RoundEnd" then
			if player:GetAttribute("ArenaTeam") then
				local winner = Arena.TeamById[a]
				local mine = a == player:GetAttribute("ArenaTeam")
				shout(if winner then (if mine then "VICTORY!" else string.upper(winner.Name) .. " WINS") else "DRAW", if winner then winner.Color else T.Snow, 4)
				playSound(if mine then "sfx_mapclear" else "sfx_finish", 0.6)
			end
		end
	end)

	------------------------------------------------ Jeder Frame

	RunService.RenderStepped:Connect(function()
		local team = player:GetAttribute("ArenaTeam")
		local inArena = team ~= nil
		hud.Visible = inArena
		if UI.TimerPanel then
			UI.TimerPanel.Visible = not inArena
		end
		Movement.Locked = player:GetAttribute("WarFrozen") == true
		frozenOverlay.BackgroundTransparency = if Movement.Locked then 0.55 else 1
		if not inArena then
			firing = false
			return
		end
		if firing then
			fire()
		end
		local def = Arena.TeamById[team]
		frostScore.Text = tostring(workspace:GetAttribute("WarFrost") or 0)
		auroraScore.Text = tostring(workspace:GetAttribute("WarAurora") or 0)
		local stateName = workspace:GetAttribute("WarState") or "Waiting"
		local left = math.max(0, (workspace:GetAttribute("WarEnds") or 0) - os.time())
		clock.Text = if stateName == "Playing" then Format.Clock(left) elseif stateName == "Countdown" then "GET READY" elseif stateName == "Ended" then "ROUND OVER" else "WAITING"
		teamLine.Text = `YOU ARE {string.upper(def.Name)}  -  first to {Arena.WinScore} freezes`
		teamLine.TextColor3 = def.Color
		local hp = player:GetAttribute("WarHP") or Arena.MaxHealth
		hpBar.Size = UDim2.fromScale(math.clamp(hp / Arena.MaxHealth, 0, 1), 1)
		hpBar.BackgroundColor3 = if player:GetAttribute("WarShield") then T.Gold elseif hp < 35 then T.Red else T.Ice
		if selected ~= "Snowball" and not carried() then
			selected = "Snowball"
		end
		local weapon = Arena.Weapons[selected]
		local ammo = if selected == "Snowball" then "infinite" else tostring(player:GetAttribute("WarAmmo") or 0)
		local other = carried()
		weaponLabel.Text = `{string.upper(weapon.Name)}  ({ammo})` .. (if other and other ~= selected then `   [Q: {Arena.Weapons[other].Name}]` else "")
		weaponLabel.TextColor3 = weapon.Color
		swapButton.Visible = other ~= nil
	end)
end

return WarsClient
