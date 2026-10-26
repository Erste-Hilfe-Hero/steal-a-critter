-- Update 3: "Snowball Wars" (Team-Modus wie auf CS-Surf-Kampfmaps). Baut die Arena, teilt Spieler in
-- Team Frost und Team Aurora ein, verwaltet Kaelte-Punkte, Einfrieren, Runden, Waffen zum Einsammeln
-- und Bots, die die Teams auffuellen. Die Spieler bewegen sich selbst (Client); Treffer meldet der
-- Client, der Server prueft sie gegen die Positionen, die er sieht.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Arena = require(ReplicatedStorage.Shared.Arena)
local Config = require(ReplicatedStorage.Shared.Config)
local SurfAssist = require(ReplicatedStorage.Shared.SurfAssist)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)

local ArenaService = { Services = nil :: any }

local THEME = Config.Theme
local HULL = Vector3.new(2, 5, 2)
local BOT_NAMES = { "Frosty", "Blizz", "Pingu", "Yeti", "Sleet", "Flurry", "Icicle", "Snowdrop", "Glacier", "Mitten", "Pebble", "Comet" }

-- Teilnehmer (echte Spieler und Bots): [Key] = Entity
-- Entity = { Key, Name, Team, Player?, Bot?, HP, Frozen, ShieldUntil, LastHit, Weapon, Ammo, LastShot }
local entities = {}
local teamObjects = {}
local roundState = "Waiting"
local roundEnds = 0
local scores = { Frost = 0, Aurora = 0 }
local pickups = {} -- { Def, Part, ReadyAt }
local shots = {} -- [Key .. shotId] = { Weapon, Origin, Direction, Time, Used }
local arenaFolder: Folder
local botFolder: Folder
local botCount = 0
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
castParams.RespectCanCollide = true

function ArenaService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Hilfen

local function playerKey(player: Player): string
	return "p" .. player.UserId
end

local function rootOf(entity): BasePart?
	if entity.Bot then
		return entity.Bot.Root
	end
	local character = entity.Player and entity.Player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function positionOf(entity): Vector3?
	if entity.Bot then
		return entity.Bot.State.Position
	end
	local root = rootOf(entity)
	return root and root.Position
end

-- Wie weit darf die gemeldete Trefferstelle von der Server-Position abweichen? Latenz mal Tempo.
local function tolerance(entity): number
	local speed = if entity.Bot then entity.Bot.State.Velocity.Magnitude else (entity.Speed or 0)
	return 4 + math.min(30, speed * 0.3)
end

local function humansIn(teamId: string?): number
	local count = 0
	for _, e in entities do
		if e.Player and (teamId == nil or e.Team == teamId) then
			count += 1
		end
	end
	return count
end

local function publish(entity)
	local player = entity.Player
	if player then
		player:SetAttribute("WarHP", math.floor(entity.HP + 0.5))
		player:SetAttribute("WarWeapon", entity.Weapon)
		player:SetAttribute("WarAmmo", entity.Ammo)
		player:SetAttribute("WarFrozen", entity.Frozen)
		player:SetAttribute("WarShield", entity.ShieldUntil > os.clock())
	elseif entity.Bot then
		entity.Bot.Model:SetAttribute("Frozen", entity.Frozen)
		entity.Bot.Model:SetAttribute("HP", math.floor(entity.HP + 0.5))
	end
end

local function publishRound()
	workspace:SetAttribute("WarState", roundState)
	workspace:SetAttribute("WarEnds", roundEnds)
	workspace:SetAttribute("WarFrost", scores.Frost)
	workspace:SetAttribute("WarAurora", scores.Aurora)
end

local function event(...)
	ArenaService.Services.Net.WarsEvent:FireAllClients(...)
end

---------------------------------------------------------------- Arena bauen

local function buildArena()
	local K = ArenaService.Services.WorldService.Kit
	arenaFolder = Instance.new("Folder")
	arenaFolder.Name = "Arena"
	local half = Arena.Half
	for _, team in Arena.Teams do
		local function m(v: Vector3): Vector3
			return if team.Side > 0 then Arena.Mirror(v) else v
		end
		local folder = Instance.new("Folder")
		folder.Name = team.Id
		-- Basis: Plattform in Teamfarbe, Waende hinten und seitlich, vorne offen
		local base = m(half.StartCenter)
		K.platform(base, half.StartSize, team.Dark, folder).Material = Enum.Material.Ice
		local back = half.StartSize.X / 2
		K.part({ Size = Vector3.new(2, 14, half.StartSize.Z), CFrame = CFrame.new(base + Vector3.new(team.Side * back, 7, 0)), Color = team.Color, Material = Enum.Material.Glass, Transparency = 0.35, Parent = folder })
		for _, z in { -1, 1 } do
			K.part({ Size = Vector3.new(half.StartSize.X, 8, 2), CFrame = CFrame.new(base + Vector3.new(0, 4, z * half.StartSize.Z / 2)), Color = team.Color, Material = Enum.Material.Glass, Transparency = 0.35, Parent = folder })
		end
		local banner = K.deco({ Size = Vector3.new(1, 10, 40), CFrame = CFrame.new(base + Vector3.new(team.Side * (back + 1.5), 18, 0)), Color = team.Dark, Parent = folder })
		K.label(banner, Enum.NormalId.Left, string.upper(team.Name), THEME.Snow)
		K.label(banner, Enum.NormalId.Right, string.upper(team.Name), THEME.Snow)
		-- Rampen
		for _, r in half.Ramps do
			local ridge = r.Ridge
			if team.Side > 0 then
				-- Gespiegelte Rampe beginnt am anderen Ende (Rampen fallen immer in +X ab)
				local p = math.rad(r.Pitch)
				local farEnd = r.Ridge + Vector3.new(r.Length * math.cos(p), -r.Length * math.sin(p), 0)
				ridge = Arena.Mirror(farEnd)
				-- Vom tiefen Ende aus steigt sie in +X an und endet oben am gespiegelten Grat
				K.ramp(ridge, r.Length, r.Width, r.Height, -r.Pitch, team.Color:Lerp(THEME.Snow, 0.85), team.Color, folder)
			else
				K.ramp(ridge, r.Length, r.Width, r.Height, r.Pitch, team.Color:Lerp(THEME.Snow, 0.85), team.Color, folder)
			end
		end
		-- Rueckweg-Platte auf dem Platz
		local pad = Arena.Pad(team.Id)
		K.deco({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 12, 12), CFrame = CFrame.new(pad + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = team.Color, Material = Enum.Material.Neon, Parent = folder })
		local padSign = K.deco({ Size = Vector3.new(0.4, 3, 12), CFrame = CFrame.new(pad + Vector3.new(team.Side * 7, 4, 0)), Color = team.Dark, Parent = folder })
		K.label(padSign, if team.Side > 0 then Enum.NormalId.Left else Enum.NormalId.Right, "BACK TO BASE", THEME.Snow)
		K.zone("WarPad" .. team.Id, CFrame.new(pad + Vector3.new(0, 4, 0)), Vector3.new(12, 8, 12))
		folder.Parent = arenaFolder
	end
	-- Platz in der Mitte mit Deckung
	local plaza = half.FinishCenter
	K.platform(plaza, half.FinishSize, Color3.fromRGB(236, 242, 250), arenaFolder)
	K.deco({ Size = Vector3.new(1, 0.25, half.FinishSize.Z), CFrame = CFrame.new(plaza + Vector3.new(0, 0.1, 0)), Color = THEME.Gold, Material = Enum.Material.Neon, Parent = arenaFolder })
	for _, cover in Arena.Cover do
		local center = Vector3.new(cover.Center.X, plaza.Y + cover.Size.Y / 2, plaza.Z + cover.Center.Z)
		K.part({ Size = cover.Size, CFrame = CFrame.new(center), Color = Color3.fromRGB(225, 238, 252), Material = Enum.Material.Snow, Parent = arenaFolder })
	end
	-- Iglus als Kulisse an den Ecken (Kuppel aus einer Kugel, halb im Boden)
	for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1) } do
		local pos = plaza + Vector3.new(corner.X * (half.FinishSize.X / 2 - 14), 0, corner.Z * (half.FinishSize.Z / 2 - 14))
		K.part({ Shape = Enum.PartType.Ball, Size = Vector3.new(16, 16, 16), CFrame = CFrame.new(pos), Color = Color3.fromRGB(230, 242, 255), Material = Enum.Material.Ice, Parent = arenaFolder })
	end
	-- Sockel fuer den Frost Sniper in der Mitte
	K.part({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.5, 8, 8), CFrame = CFrame.new(plaza + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = THEME.Ice, Material = Enum.Material.Glass, Parent = arenaFolder })
	-- Grosses Schild
	local sign = K.deco({ Size = Vector3.new(1, 18, 90), CFrame = CFrame.new(plaza + Vector3.new(0, 70, half.FinishSize.Z / 2 + 10)), Transparency = 1, Parent = arenaFolder })
	local _, text = K.label(sign, Enum.NormalId.Left, "SNOWBALL WARS", THEME.Snow, { PixelsPerStud = 10 })
	text.TextColor3 = THEME.Gold
	-- Tal und Berge darunter (nur Kulisse)
	K.deco({ Size = Vector3.new(1400, 4, 900), CFrame = CFrame.new(Arena.Center.X, Arena.KillY - 30, Arena.Center.Z), Color = Color3.fromRGB(236, 242, 250), Material = Enum.Material.Snow, Parent = arenaFolder })
	for _, side in { -1, 1 } do
		for i = -2, 2 do
			K.mountain(Vector3.new(i * 280, Arena.KillY - 30, Arena.Center.Z + side * 420), 300, 260, 520, arenaFolder)
		end
	end
	arenaFolder.Parent = ArenaService.Services.WorldService:GetMap()

	-- Waffen zum Einsammeln: drehende, leuchtende Kristalle mit Namen
	local pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "WarPickups"
	for i, def in Arena.Pickups do
		local weapon = Arena.Weapons[def.Weapon]
		local crystal = K.deco({
			Name = "Pickup" .. i,
			Size = Vector3.new(2.6, 2.6, 2.6),
			CFrame = CFrame.new(def.Position) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color = weapon.Color,
			Material = Enum.Material.Neon,
			Parent = pickupFolder,
		})
		crystal:SetAttribute("Weapon", def.Weapon)
		local light = Instance.new("PointLight")
		light.Color = weapon.Color
		light.Range = 14
		light.Brightness = 2
		light.Parent = crystal
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(140, 26)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 140
		gui.Parent = crystal
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.fromScale(1, 1)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.upper(weapon.Name)
		nameLabel.TextColor3 = weapon.Color
		nameLabel.TextScaled = true
		nameLabel.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = THEME.Navy
		stroke.Parent = nameLabel
		nameLabel.Parent = gui
		table.insert(pickups, { Def = def, Part = crystal, ReadyAt = 0 })
	end
	pickupFolder.Parent = workspace

	botFolder = Instance.new("Folder")
	botFolder.Name = "WarBots"
	botFolder.Parent = workspace
	castParams.FilterDescendantsInstances = { botFolder, workspace:FindFirstChild("Zones") or botFolder }
	workspace:SetAttribute("WarKillY", Arena.KillY)
end

---------------------------------------------------------------- Teams

local function setupTeams()
	for _, def in Arena.Teams do
		local team = Instance.new("Team")
		team.Name = def.Name
		team.TeamColor = BrickColor.new(def.Color)
		team.AutoAssignable = false
		team.Parent = Teams
		teamObjects[def.Id] = team
	end
end

local function pickTeam(): string
	local frost, aurora = humansIn("Frost"), humansIn("Aurora")
	if frost == aurora then
		return if scores.Frost <= scores.Aurora then "Frost" else "Aurora"
	end
	return if frost < aurora then "Frost" else "Aurora"
end

---------------------------------------------------------------- Bots

local function botModel(name: string, team)
	local model = Instance.new("Model")
	model.Name = name
	local function piece(props)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = true
		p.Material = Enum.Material.SmoothPlastic
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = model
		return p
	end
	-- Mitte = Mitte der Hitbox (wie bei Spielern), Fuesse 2.5 darunter
	local root = piece({ Name = "Root", Size = HULL, Transparency = 1 })
	model.PrimaryPart = root
	local parts = {
		{ piece({ Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), Color = THEME.Snow, Material = Enum.Material.Snow }), CFrame.new(0, -0.9, 0) },
		{ piece({ Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), Color = THEME.Snow, Material = Enum.Material.Snow }), CFrame.new(0, 1.3, 0) },
		{ piece({ Size = Vector3.new(2.5, 0.5, 2.5), Color = team.Color }), CFrame.new(0, 0.35, 0) },
		{ piece({ Size = Vector3.new(0.3, 0.3, 1.2), Color = Color3.fromRGB(255, 140, 40) }), CFrame.new(0, 1.3, -1.6) },
		{ piece({ Size = Vector3.new(1.8, 1.2, 1.8), Color = team.Dark }), CFrame.new(0, 2.8, 0) },
		{ piece({ Size = Vector3.new(0.4, 0.15, 5), Color = team.Color }), CFrame.new(-0.6, -2.45, 0) },
		{ piece({ Size = Vector3.new(0.4, 0.15, 5), Color = team.Color }), CFrame.new(0.6, -2.45, 0) },
	}
	for _, eye in { -0.45, 0.45 } do
		table.insert(parts, { piece({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = THEME.Navy }), CFrame.new(eye, 1.6, -1.05) })
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 30)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.MaxDistance = 160
	gui.Parent = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = name .. " [BOT]"
	label.TextColor3 = team.Color
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = THEME.Navy
	stroke.Parent = label
	label.Parent = gui
	model:SetAttribute("Team", team.Id)
	return model, root, parts
end

local function spawnBot(teamId: string)
	botCount += 1
	local team = Arena.TeamById[teamId]
	local name = BOT_NAMES[(botCount - 1) % #BOT_NAMES + 1]
	local key = "b" .. botCount
	local model, root, parts = botModel(name, team)
	model:SetAttribute("Key", key)
	local spawn = Arena.Spawn(teamId)
	local bot = {
		Model = model,
		Root = root,
		Parts = parts,
		State = { Position = spawn.Position, Velocity = Vector3.zero, Grounded = false },
		Mode = "Surf",
		Slope = nil,
		SlopeTime = -1,
		Yaw = 0,
		NextShot = os.clock() + 2,
		FightUntil = 0,
		Wander = nil,
		Clock = 0,
	}
	model.Parent = botFolder
	entities[key] = {
		Key = key,
		Name = name,
		Team = teamId,
		Bot = bot,
		HP = Arena.MaxHealth,
		Frozen = false,
		ShieldUntil = os.clock() + Arena.ShieldSeconds,
		LastHit = 0,
		Weapon = "Snowball",
		Ammo = 0,
		LastShot = 0,
	}
end

local function removeBot(key: string)
	local e = entities[key]
	if e and e.Bot then
		e.Bot.Model:Destroy()
		entities[key] = nil
	end
end

local function balanceBots()
	local anyHumans = humansIn(nil) > 0
	for _, team in Arena.Teams do
		local wanted = if anyHumans then math.max(0, Arena.BotsPerTeam - humansIn(team.Id)) else 0
		local bots = {}
		for key, e in entities do
			if e.Bot and e.Team == team.Id then
				table.insert(bots, key)
			end
		end
		for i = #bots, wanted + 1, -1 do
			removeBot(bots[i])
		end
		for _ = #bots + 1, wanted do
			spawnBot(team.Id)
		end
	end
end

---------------------------------------------------------------- Treffer, Einfrieren, Punkte

local respawn

local function freeze(victim, attacker, weaponId: string)
	victim.Frozen = true
	victim.HP = 0
	publish(victim)
	local pos = positionOf(victim)
	if pos then
		local ice = Instance.new("Part")
		ice.Name = "IceBlock"
		ice.Anchored = true
		ice.CanCollide = false
		ice.CanQuery = false
		ice.CanTouch = false
		ice.Size = Vector3.new(5, 7, 5)
		ice.CFrame = CFrame.new(pos)
		ice.Material = Enum.Material.Ice
		ice.Color = Color3.fromRGB(170, 225, 255)
		ice.Transparency = 0.35
		ice.Parent = workspace
		task.delay(Arena.FrozenSeconds, function()
			ice:Destroy()
		end)
	end
	local services = ArenaService.Services
	if attacker and attacker.Team ~= victim.Team and roundState == "Playing" then
		scores[attacker.Team] += 1
		publishRound()
		if attacker.Player then
			local data = services.DataService:Get(attacker.Player)
			if data then
				data.WarFreezes = (data.WarFreezes or 0) + 1
				services.DataService:AddFlakes(attacker.Player, Arena.Rewards.Freeze, true)
			end
		end
		if scores[attacker.Team] >= Arena.WinScore then
			task.defer(ArenaService.EndRound, ArenaService)
		end
	end
	event("Frozen", attacker and attacker.Name or "", attacker and attacker.Team or "", victim.Name, victim.Team, weaponId, if pos then pos else Vector3.zero)
	task.delay(Arena.FrozenSeconds, function()
		if entities[victim.Key] == victim then
			respawn(victim)
		end
	end)
end

local function damage(victim, attacker, amount: number, weaponId: string, from: Vector3?)
	if victim.Frozen or victim.ShieldUntil > os.clock() or roundState ~= "Playing" then
		return false
	end
	if attacker and attacker.Team == victim.Team then
		return false
	end
	victim.HP -= amount
	victim.LastHit = os.clock()
	-- Rueckstoss: wie auf Surf-Kampfmaps fliegt man ein Stueck weg
	local weapon = Arena.Weapons[weaponId]
	local pos = positionOf(victim)
	if weapon and from and pos then
		local away = pos - from
		away = Vector3.new(away.X, 0, away.Z)
		local push = (if away.Magnitude > 0.1 then away.Unit else Vector3.zero) * weapon.Knock + Vector3.new(0, weapon.Knock * 0.35, 0)
		if victim.Player then
			ArenaService.Services.Net.WarsEvent:FireClient(victim.Player, "Knock", push)
		elseif victim.Bot then
			victim.Bot.State.Velocity += push
		end
	end
	if attacker and attacker.Player then
		ArenaService.Services.Net.WarsEvent:FireClient(attacker.Player, "HitConfirm", math.floor(amount + 0.5), pos or Vector3.zero, victim.HP <= 0)
	end
	if victim.HP <= 0 then
		freeze(victim, attacker, weaponId)
	else
		publish(victim)
	end
	return true
end

-- Spritzschaden (Slush Bomb) rund um einen Punkt
local function splash(attacker, center: Vector3, weapon, weaponId: string)
	for _, e in entities do
		if e.Team ~= attacker.Team then
			local pos = positionOf(e)
			if pos and (pos - center).Magnitude <= weapon.Splash then
				local falloff = 1 - 0.5 * (pos - center).Magnitude / weapon.Splash
				damage(e, attacker, weapon.Damage * falloff, weaponId, center)
			end
		end
	end
	event("Splash", center, weaponId)
end

respawn = function(entity)
	local now = os.clock()
	entity.Frozen = false
	entity.HP = Arena.MaxHealth
	-- Schutz nur, wenn der letzte Neustart etwas her ist (sonst waere "Fell" spammen unverwundbar)
	entity.ShieldUntil = if now - (entity.LastRespawn or -100) > 8 then now + Arena.ShieldSeconds else 0
	entity.LastRespawn = now
	entity.Weapon = "Snowball"
	entity.Ammo = 0
	local spawn = Arena.Spawn(entity.Team)
	if entity.Player then
		entity.Player:SetAttribute("ArenaSpawn", spawn)
		ArenaService.Services.Net.Teleport:FireClient(entity.Player, spawn, 0)
	elseif entity.Bot then
		local bot = entity.Bot
		bot.State.Position = spawn.Position
		bot.State.Velocity = Vector3.zero
		bot.Mode = "Surf"
	end
	publish(entity)
end

---------------------------------------------------------------- Runden

function ArenaService:EndRound()
	if roundState ~= "Playing" then
		return
	end
	roundState = "Ended"
	roundEnds = os.time() + Arena.EndSeconds
	local winner = if scores.Frost > scores.Aurora then "Frost" elseif scores.Aurora > scores.Frost then "Aurora" else nil
	publishRound()
	local services = self.Services
	for _, e in entities do
		if e.Player then
			local data = services.DataService:Get(e.Player)
			if data then
				data.WarRounds = (data.WarRounds or 0) + 1
				local reward = Arena.Rewards.Play
				if winner == e.Team then
					data.WarWins = (data.WarWins or 0) + 1
					reward += Arena.Rewards.Win
				end
				local given = services.DataService:AddFlakes(e.Player, reward, true)
				services.Net.SendNotify(e.Player, `+{given} Snowflakes for the round`, THEME.Gold)
			end
		end
	end
	event("RoundEnd", winner or "", scores.Frost, scores.Aurora)
	local text = if winner then `{string.upper(Arena.TeamById[winner].Name)} WINS SNOWBALL WARS {scores.Frost}-{scores.Aurora}!` else `SNOWBALL WARS: DRAW {scores.Frost}-{scores.Aurora}`
	services.Net.SendAnnounce(text, if winner then Arena.TeamById[winner].Color else THEME.Snow)
	task.delay(Arena.EndSeconds, function()
		scores.Frost, scores.Aurora = 0, 0
		for _, e in entities do
			respawn(e)
		end
		roundState = if humansIn(nil) > 0 then "Countdown" else "Waiting"
		roundEnds = os.time() + Arena.CountdownSeconds
		publishRound()
		if roundState == "Countdown" then
			event("Countdown", Arena.CountdownSeconds)
		end
	end)
end

local function tickRound()
	local now = os.time()
	if roundState == "Waiting" and humansIn(nil) > 0 then
		roundState = "Countdown"
		roundEnds = now + Arena.CountdownSeconds
		publishRound()
		event("Countdown", Arena.CountdownSeconds)
	elseif roundState == "Countdown" and now >= roundEnds then
		roundState = "Playing"
		roundEnds = now + Arena.RoundSeconds
		scores.Frost, scores.Aurora = 0, 0
		publishRound()
		event("RoundStart")
	elseif roundState == "Playing" and now >= roundEnds then
		ArenaService:EndRound()
	elseif roundState ~= "Waiting" and roundState ~= "Ended" and humansIn(nil) == 0 then
		roundState = "Waiting"
		scores.Frost, scores.Aurora = 0, 0
		publishRound()
	end
end

---------------------------------------------------------------- Waffen einsammeln

local function tickPickups()
	local now = os.clock()
	for _, pickup in pickups do
		local ready = now >= pickup.ReadyAt
		pickup.Part.Transparency = if ready then 0 else 1
		local gui = pickup.Part:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.Enabled = ready
		end
		if ready then
			for _, e in entities do
				local pos = positionOf(e)
				if not e.Frozen and pos and (pos - pickup.Def.Position).Magnitude <= Arena.PickupRadius then
					local weapon = Arena.Weapons[pickup.Def.Weapon]
					e.Weapon = pickup.Def.Weapon
					e.Ammo = weapon.Ammo
					pickup.ReadyAt = now + pickup.Def.Respawn
					publish(e)
					if e.Player then
						ArenaService.Services.Net.WarsEvent:FireClient(e.Player, "Pickup", pickup.Def.Weapon)
					end
					break
				end
			end
		end
	end
end

---------------------------------------------------------------- Schuesse

-- Nur echte, lebende Gegner im Strahl gelten. Toleranz fuer die Latenz: siehe tolerance().

local function canFire(entity, weaponId: string): boolean
	local weapon = Arena.Weapons[weaponId]
	if not weapon or entity.Frozen or roundState == "Ended" then
		return false
	end
	if weaponId ~= "Snowball" and (entity.Weapon ~= weaponId or entity.Ammo <= 0) then
		return false
	end
	local now = os.clock()
	if now - entity.LastShot < weapon.Cooldown * 0.8 then
		return false
	end
	entity.LastShot = now
	if weaponId ~= "Snowball" then
		entity.Ammo -= 1
		if entity.Ammo <= 0 then
			entity.Weapon = "Snowball"
			entity.Ammo = 0
		end
		publish(entity)
	end
	return true
end

local function hitscan(attacker, weaponId: string, origin: Vector3, direction: Vector3, claimed: { string }?)
	local weapon = Arena.Weapons[weaponId]
	local directions = { direction }
	if weapon.Kind == "Spread" then
		directions = {}
		for i = 1, weapon.Pellets do
			table.insert(directions, Arena.SpreadDirection(direction, i, weapon.Pellets, weapon.Spread))
		end
	end
	local wall = workspace:Raycast(origin, direction * weapon.Range, castParams)
	local wallDistance = if wall then wall.Distance else weapon.Range
	local hits = {}
	for _, dir in directions do
		local best, bestDistance = nil, math.huge
		for _, e in entities do
			if e.Team ~= attacker.Team and not e.Frozen and (claimed == nil or table.find(claimed, e.Key)) then
				local pos = positionOf(e)
				local radius = Arena.HitRadius + (if claimed then tolerance(e) else 0)
				local d = pos and Arena.RaySphere(origin, dir, pos, radius)
				if d and d < bestDistance and d <= weapon.Range and d <= wallDistance + 2 then
					best, bestDistance = e, d
				end
			end
		end
		if best then
			hits[best] = (hits[best] or 0) + weapon.Damage
		end
	end
	for victim, amount in hits do
		damage(victim, attacker, amount, weaponId, origin)
	end
end

local function onFire(player: Player, weaponId, origin, direction, shotId, claimed)
	local entity = entities[playerKey(player)]
	if not entity or typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	if direction.Magnitude < 0.5 or direction.Magnitude > 1.5 then
		return
	end
	direction = direction.Unit
	local root = rootOf(entity)
	if not root or (root.Position - origin).Magnitude > 16 then
		return
	end
	if not canFire(entity, weaponId) then
		return
	end
	local weapon = Arena.Weapons[weaponId]
	-- Den anderen zeigen (der Schuetze hat es schon selbst gezeichnet)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			ArenaService.Services.Net.WarsEvent:FireClient(other, "Shot", entity.Key, weaponId, origin, direction)
		end
	end
	if weapon.Kind == "Projectile" then
		if typeof(shotId) == "number" then
			shots[entity.Key .. ":" .. shotId] = { Weapon = weaponId, Origin = origin, Direction = direction, Time = os.clock() }
		end
	else
		local list = nil
		if typeof(claimed) == "table" then
			list = {}
			for _, key in claimed do
				if typeof(key) == "string" and #list < 8 then
					table.insert(list, key)
				end
			end
		end
		if list and #list > 0 then
			hitscan(entity, weaponId, origin, direction, list)
		end
	end
end

-- Projektil-Treffer vom Client: Ziel (oder Boden bei der Bombe) und Aufprallpunkt
local function onImpact(player: Player, shotId, targetKey, point)
	local entity = entities[playerKey(player)]
	if not entity or typeof(shotId) ~= "number" or typeof(point) ~= "Vector3" then
		return
	end
	local id = entity.Key .. ":" .. shotId
	local shot = shots[id]
	shots[id] = nil
	if not shot then
		return
	end
	local weapon = Arena.Weapons[shot.Weapon]
	local elapsed = os.clock() - shot.Time
	local distance = (point - shot.Origin).Magnitude
	-- Zu schnell oder zu weit = gefaelscht
	if elapsed > 8 or distance > weapon.Range or distance > (weapon.Speed + 40) * (elapsed + 0.35) then
		return
	end
	if weapon.Splash then
		splash(entity, point, weapon, shot.Weapon)
		return
	end
	local victim = typeof(targetKey) == "string" and entities[targetKey]
	if victim and victim.Team ~= entity.Team then
		local pos = positionOf(victim)
		if pos and (pos - point).Magnitude <= Arena.HitRadius + tolerance(victim) + 4 then
			damage(victim, entity, weapon.Damage, shot.Weapon, shot.Origin)
		end
	end
end

---------------------------------------------------------------- Bot-Steuerung

local function botCast(from: Vector3, delta: Vector3)
	local result = workspace:Blockcast(CFrame.new(from), HULL, delta, castParams)
	if result then
		return { Distance = result.Distance, Normal = result.Normal }
	end
	return nil
end

-- Server-Projektile der Bots (fliegen mit Schwerkraft, treffen Kugeln um die Gegner)
local botShots = {}

local function botFire(entity, target)
	local bot = entity.Bot
	local weaponId = entity.Weapon
	local weapon = Arena.Weapons[weaponId]
	local from = bot.State.Position + Vector3.new(0, 1.5, 0)
	local targetPos = positionOf(target)
	if not targetPos or not canFire(entity, weaponId) then
		return
	end
	-- Vorhalten und streuen (Bots sollen schlagbar sein)
	local distance = (targetPos - from).Magnitude
	local velocity = if target.Bot then target.Bot.State.Velocity else (rootOf(target) and rootOf(target).AssemblyLinearVelocity or Vector3.zero)
	local travel = if weapon.Speed then distance / weapon.Speed else 0
	local aim = targetPos + velocity * travel * 0.6
	if weapon.Kind == "Projectile" then
		aim += Vector3.new(0, 0.5 * weapon.Gravity * travel * travel, 0)
	end
	local miss = math.clamp(distance / 40, 0.6, 6)
	aim += Vector3.new((math.random() - 0.5) * miss * 2, (math.random() - 0.5) * miss, (math.random() - 0.5) * miss * 2)
	local direction = (aim - from).Unit
	event("Shot", entity.Key, weaponId, from, direction)
	if weapon.Kind == "Projectile" then
		table.insert(botShots, { Entity = entity, Weapon = weaponId, Position = from, Velocity = direction * weapon.Speed, Origin = from, Age = 0 })
	else
		hitscan(entity, weaponId, from, direction, nil)
	end
end

local function stepBotShots(dt: number)
	for i = #botShots, 1, -1 do
		local shot = botShots[i]
		local weapon = Arena.Weapons[shot.Weapon]
		shot.Age += dt
		local nextVelocity = shot.Velocity - Vector3.new(0, weapon.Gravity * dt, 0)
		local delta = (shot.Velocity + nextVelocity) * 0.5 * dt
		shot.Velocity = nextVelocity
		local done = shot.Age > 4
		local hitPoint = nil
		local victim = nil
		for _, e in entities do
			if e.Team ~= shot.Entity.Team and not e.Frozen then
				local pos = positionOf(e)
				local d = pos and delta.Magnitude > 0 and Arena.RaySphere(shot.Position, delta.Unit, pos, Arena.HitRadius)
				if d and d <= delta.Magnitude then
					victim, hitPoint = e, shot.Position + delta.Unit * d
					break
				end
			end
		end
		if not victim then
			local wall = workspace:Raycast(shot.Position, delta, castParams)
			if wall then
				hitPoint = wall.Position
				done = true
			end
		end
		if victim or hitPoint then
			done = true
			if weapon.Splash then
				splash(shot.Entity, hitPoint, weapon, shot.Weapon)
			elseif victim then
				damage(victim, shot.Entity, weapon.Damage, shot.Weapon, shot.Origin)
			end
		end
		shot.Position += delta
		if done then
			table.remove(botShots, i)
		end
	end
end

local function nearestEnemy(entity, maxDistance: number)
	local pos = positionOf(entity)
	if not pos then
		return nil
	end
	local best, bestDistance = nil, maxDistance
	for _, e in entities do
		if e.Team ~= entity.Team and not e.Frozen then
			local other = positionOf(e)
			if other then
				local d = (other - pos).Magnitude
				if d < bestDistance then
					-- Sichtlinie (Deckung schuetzt)
					local wall = workspace:Raycast(pos + Vector3.new(0, 1.5, 0), other - pos, castParams)
					if not wall then
						best, bestDistance = e, d
					end
				end
			end
		end
	end
	return best
end

local BOT_TICK = 1 / 60

local function stepBot(entity, dt: number)
	local bot = entity.Bot
	local state = bot.State
	local team = Arena.TeamById[entity.Team]
	local mirror = team.Side > 0
	local function toLocal(v: Vector3): Vector3
		return if mirror then Arena.Mirror(v) else v
	end
	bot.Clock += dt
	local wish, amount = Vector3.zero, 0
	if entity.Frozen or roundState == "Countdown" or roundState == "Ended" then
		state.Velocity = Vector3.new(0, math.min(0, state.Velocity.Y), 0)
	else
		local localPos = toLocal(state.Position)
		local half = Arena.Half
		local onPlaza = state.Grounded and math.abs(state.Position.X) < half.FinishSize.X / 2 + 2 and state.Position.Y < Arena.PlazaTop + 10
		if bot.Mode == "Surf" and onPlaza then
			bot.Mode = "Fight"
			bot.FightUntil = bot.Clock + 18 + math.random() * 14
		end
		if bot.Mode == "Surf" then
			if state.Grounded and localPos.X < half.StartCenter.X + half.StartSize.X / 2 + 2 then
				wish, amount = Vector3.new(1, 0, 0), 1 -- von der Basis losfahren
			else
				local slope = if bot.Clock - bot.SlopeTime < 0.08 then toLocal(bot.Slope) else nil
				wish, amount = SurfAssist.Wish(half, localPos, toLocal(state.Velocity), state.Grounded, slope)
			end
			wish = toLocal(wish)
		else
			-- Auf dem Platz: Waffe holen, Gegner umkreisen, irgendwann zurueck zur Basis
			local goal
			if bot.Clock > bot.FightUntil then
				goal = Arena.Pad(entity.Team)
				if (Vector3.new(goal.X, 0, goal.Z) - Vector3.new(state.Position.X, 0, state.Position.Z)).Magnitude < 5 then
					respawn(entity)
					entity.ShieldUntil = 0
					return
				end
			elseif entity.Weapon == "Snowball" then
				for _, pickup in pickups do
					if os.clock() >= pickup.ReadyAt and pickup.Def.Position.Y < Arena.PlazaTop + 8 and (pickup.Def.Position - state.Position).Magnitude < 45 then
						goal = pickup.Def.Position
						break
					end
				end
			end
			if not goal then
				if not bot.Wander or (Vector3.new(bot.Wander.X, 0, bot.Wander.Z) - Vector3.new(state.Position.X, 0, state.Position.Z)).Magnitude < 4 then
					bot.Wander = Vector3.new((math.random() - 0.5) * (half.FinishSize.X - 20), 0, Arena.Center.Z + (math.random() - 0.5) * (half.FinishSize.Z - 30))
				end
				goal = bot.Wander
			end
			local flatGoal = Vector3.new(goal.X - state.Position.X, 0, goal.Z - state.Position.Z)
			if flatGoal.Magnitude > 0.5 then
				wish, amount = flatGoal.Unit, 1
			end
		end
		-- Schiessen, wenn ein Gegner in Sicht ist
		if os.clock() >= bot.NextShot and entity.ShieldUntil < os.clock() + 1 then
			local target = nearestEnemy(entity, if entity.Weapon == "FrostSniper" then 400 else 150)
			if target then
				botFire(entity, target)
				local weapon = Arena.Weapons[entity.Weapon]
				bot.NextShot = os.clock() + math.max(weapon.Cooldown, 0.9) + math.random() * 0.9
			end
		end
	end
	local landed = SurfPhysics.Step(state, { WishDir = wish, WishAmount = amount, Jump = false }, dt, function(from, delta)
		local hit = botCast(from, delta)
		if hit and hit.Normal.Y < SurfPhysics.Settings.StandNormal and hit.Normal.Y > 0 then
			bot.Slope, bot.SlopeTime = hit.Normal, bot.Clock
		end
		return hit
	end, SurfPhysics.Settings)
	local _ = landed
	if state.Position.Y < Arena.KillY then
		respawn(entity)
	end
end

local function renderBot(entity)
	local bot = entity.Bot
	local state = bot.State
	local flatVelocity = Vector3.new(state.Velocity.X, 0, state.Velocity.Z)
	if flatVelocity.Magnitude > 2 then
		bot.Yaw = math.atan2(-flatVelocity.X, -flatVelocity.Z)
	end
	local cf = CFrame.new(state.Position) * CFrame.Angles(0, bot.Yaw, 0)
	bot.Root.CFrame = cf
	for _, entry in bot.Parts do
		entry[1].CFrame = cf * entry[2]
	end
end

---------------------------------------------------------------- Beitreten / Verlassen

function ArenaService:IsIn(player: Player): boolean
	return entities[playerKey(player)] ~= nil
end

function ArenaService:GetSpawn(player: Player): CFrame?
	local e = entities[playerKey(player)]
	return e and Arena.Spawn(e.Team)
end

function ArenaService:Join(player: Player)
	if entities[playerKey(player)] then
		return
	end
	local services = self.Services
	services.TimerService:ToLobby(player)
	local teamId = pickTeam()
	local entity = {
		Key = playerKey(player),
		Name = player.DisplayName,
		Team = teamId,
		Player = player,
		HP = Arena.MaxHealth,
		Frozen = false,
		ShieldUntil = 0,
		LastHit = 0,
		Weapon = "Snowball",
		Ammo = 0,
		LastShot = 0,
	}
	entities[entity.Key] = entity
	player.Team = teamObjects[teamId]
	player.Neutral = false
	player:SetAttribute("ArenaTeam", teamId)
	respawn(entity)
	balanceBots()
	services.Net.SendNotify(player, `You joined {Arena.TeamById[teamId].Name}! Grab weapons on the map and freeze the other team.`, Arena.TeamById[teamId].Color)
	tickRound()
end

-- Zurueck zur Basis (Reset-Knopf), aber nicht, solange man eingefroren ist
function ArenaService:Respawn(player: Player)
	local entity = entities[playerKey(player)]
	if entity and not entity.Frozen then
		respawn(entity)
	end
end

function ArenaService:Remove(player: Player)
	local key = playerKey(player)
	if not entities[key] then
		return
	end
	entities[key] = nil
	if player.Parent then
		player.Team = nil
		player.Neutral = true
		for _, name in { "ArenaTeam", "ArenaSpawn", "WarHP", "WarWeapon", "WarAmmo", "WarFrozen", "WarShield" } do
			player:SetAttribute(name, nil)
		end
	end
	balanceBots()
end

---------------------------------------------------------------- Start

function ArenaService:Start()
	local services = self.Services
	setupTeams()
	buildArena()
	publishRound()

	services.Net.Wars.OnServerEvent:Connect(function(player, action, a, b, c, d, e)
		if action == "Join" then
			self:Join(player)
		elseif action == "Leave" then
			if self:IsIn(player) then
				self:Remove(player)
				services.TimerService:ToLobby(player)
			end
		elseif action == "Fire" then
			onFire(player, a, b, c, d, e)
		elseif action == "Impact" then
			onImpact(player, a, b, c)
		elseif action == "Fell" then
			self:Respawn(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:Remove(player)
	end)

	-- Bots mit fester Schrittweite, Regeneration, Waffen, Runden
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator = math.min(accumulator + dt, BOT_TICK * 6)
		while accumulator >= BOT_TICK do
			accumulator -= BOT_TICK
			for _, entity in entities do
				if entity.Bot then
					stepBot(entity, BOT_TICK)
				end
			end
			stepBotShots(BOT_TICK)
		end
		for _, entity in entities do
			if entity.Bot then
				renderBot(entity)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(function()
				tickPickups()
				local now = os.clock()
				for _, entity in entities do
					if not entity.Frozen and entity.HP < Arena.MaxHealth and now - entity.LastHit > Arena.RegenDelay then
						entity.HP = math.min(Arena.MaxHealth, entity.HP + Arena.RegenPerSecond * 0.1)
						publish(entity)
					end
					if entity.Player and entity.Player:GetAttribute("WarShield") and entity.ShieldUntil <= now then
						publish(entity)
					end
					-- Tempo der Spieler schaetzen (der Client bewegt sich selbst, Geschwindigkeit ist 0)
					if entity.Player then
						local pos = positionOf(entity)
						if pos and entity.LastPos then
							entity.Speed = math.min(400, (pos - entity.LastPos).Magnitude / 0.1)
						end
						entity.LastPos = pos
					end
				end
				-- Alte Projektil-Eintraege vergessen
				for id, shot in shots do
					if now - shot.Time > 10 then
						shots[id] = nil
					end
				end
			end)
			if not ok then
				warn("[ArenaService] " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(tickRound)
		end
	end)
end

-- Fuer Tests
ArenaService._entities = entities
ArenaService._stepBot = stepBot
ArenaService._spawnBot = spawnBot

return ArenaService
