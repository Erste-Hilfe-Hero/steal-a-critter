-- Rennablauf: Abstimmung -> Startaufstellung -> Countdown -> Rennen -> Ergebnis.
-- Spieler-Karts werden vom eigenen Client gefahren (Network Owner), der Server zaehlt Runden und Plaetze,
-- steuert CPU-Fahrer, Item-Boxen, Muenzen und alle Geschosse/Fallen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local KartFactory = require(ReplicatedStorage.Shared.KartFactory)
local Tracks = require(ReplicatedStorage.Shared.Tracks)

local RaceService = {
	Services = nil :: any,
	Phase = "Intermission",
	Racers = {} :: { any },
	ForcedTrack = nil :: string?,
	ForcedBy = nil :: string?,
	SkipWait = false,
	LastTrack = nil :: string?,
	FirstFinish = nil :: number?,
	Choices = {} :: { string },
	Heartbeat = nil :: RBXScriptConnection?,
}

local FLAME = Color3.fromRGB(255, 110, 20)
local GOLD = Color3.fromRGB(255, 200, 40)

local votes: { [Player]: string } = {}
local projectiles = {}
local kartsFolder = Instance.new("Folder")
kartsFolder.Name = "Karts"
kartsFolder.Parent = workspace
local fxFolder = Instance.new("Folder")
fxFolder.Name = "RaceFX"
fxFolder.Parent = workspace

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setPhase(phase: string, duration: number)
	RaceService.Phase = phase
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseEnd", now() + duration)
end

function RaceService:Init(services)
	self.Services = services
	workspace:SetAttribute("TotalLaps", Config.Laps)
end

---------------------------------------------------------------- Hilfen fuer Rennfahrer

local function racerOf(player: Player)
	for _, racer in RaceService.Racers do
		if racer.Player == player then
			return racer
		end
	end
	return nil
end
RaceService.RacerOf = racerOf

local function position(racer): Vector3
	if racer.Bot then
		return racer.Position
	end
	local root = racer.Root
	return if root and root.Parent then root.Position else Vector3.zero
end

local function look(racer): Vector3
	if racer.Bot then
		return racer.Look
	end
	local root = racer.Root
	return if root and root.Parent then root.CFrame.LookVector else Vector3.zAxis
end

local function syncAttributes(racer)
	if racer.Player then
		local p = racer.Player
		p:SetAttribute("Item", racer.Item)
		p:SetAttribute("Item2", racer.Item2)
		p:SetAttribute("RaceCoins", racer.RaceCoins)
		p:SetAttribute("Lap", math.clamp(racer.Lap, 1, Config.Laps))
		p:SetAttribute("RacePlace", racer.Place)
		p:SetAttribute("Finished", racer.Finished)
	end
	racer.Model:SetAttribute("Place", racer.Place)
end

local function setFlame(racer, on: boolean)
	for _, d in racer.Model:GetDescendants() do
		if d.Name == "BoostFlame" and d:IsA("ParticleEmitter") then
			d.Enabled = on
		elseif d.Name == "BoostLight" and d:IsA("PointLight") then
			d.Enabled = on
		end
	end
end

local function weldVisual(racer, name: string, props: { [string]: any }): BasePart
	local root = racer.Model.PrimaryPart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = racer.Bot == true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = root.CFrame
	if not racer.Bot then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = racer.Model
	return p
end

local function clearVisual(racer, name: string)
	local v = racer.Model:FindFirstChild(name)
	if v then
		v:Destroy()
	end
end

---------------------------------------------------------------- Treffer und Items

local function notify(racer, text: string, color: Color3?)
	if racer.Player then
		RaceService.Services.Net.SendNotify(racer.Player, text, color)
	end
end

local function hit(victim, attacker)
	if victim.Finished then
		return
	end
	local t = now()
	-- Unverwundbar mit Inferno und waehrend man sich noch dreht (sonst trifft Inferno-Rammen 10x pro Sekunde)
	if victim.InfernoUntil > t or victim.SpinUntil > t then
		return
	end
	if victim.ShieldUntil > t then
		victim.ShieldUntil = 0
		clearVisual(victim, "ShieldBubble")
		notify(victim, "Your Flame Shield blocked a hit!", GOLD)
		return
	end
	victim.SpinUntil = t + Config.ItemDurations.Spin
	victim.RaceCoins = math.max(0, victim.RaceCoins - 2)
	if victim.Player then
		RaceService.Services.Net.Effect:FireClient(victim.Player, "Spin", Config.ItemDurations.Spin)
	end
	syncAttributes(victim)
	if attacker and attacker ~= victim then
		notify(attacker, `You blasted {victim.Name}!`, FLAME)
		if attacker.Player then
			RaceService.Services.ProgressService:Add(attacker.Player, "Hits", 1)
		end
	end
end

local function spawnProjectile(kind: string, owner, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	if kind == "Fireball" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(3, 3, 3)
		p.Color = Color3.fromRGB(255, 100, 20)
		local fire = Instance.new("Fire")
		fire.Size = 5
		fire.Heat = 0
		fire.Parent = p
	elseif kind == "Homing" then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(3.2, 3.2, 3.2)
		p.Color = Color3.fromRGB(80, 170, 255)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = p.Color
		sparkles.Parent = p
	else -- Oil
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.3, 9, 9)
		p.Color = Color3.fromRGB(35, 25, 45)
		p.Material = Enum.Material.Glass
		p.Reflectance = 0.5
	end
	local light = Instance.new("PointLight")
	light.Color = p.Color
	light.Range = 14
	light.Parent = p
	p.CFrame = CFrame.new(props.Position) * (if kind == "Oil" then CFrame.Angles(0, 0, math.pi / 2) else CFrame.identity)
	p.Parent = fxFolder
	local projectile = { Kind = kind, Owner = owner, Part = p, Born = now(), Position = props.Position }
	for key, value in props do
		projectile[key] = value
	end
	table.insert(projectiles, projectile)
	return projectile
end

local function racerAhead(racer)
	local best, bestPlace = nil, 0
	for _, other in RaceService.Racers do
		if other ~= racer and not other.Finished and other.Place < racer.Place and other.Place > bestPlace then
			best, bestPlace = other, other.Place
		end
	end
	return best
end

local function useItem(racer)
	local item = racer.Item
	if not item or racer.Finished or now() < racer.ItemReadyAt then
		return
	end
	local def = Config.Items[item]
	if def.Next then
		racer.Item = def.Next
	else
		racer.Item = racer.Item2
		racer.Item2 = nil
	end
	local t = now()
	if racer.Player and not racer.SuperUse then
		RaceService.Services.ProgressService:Add(racer.Player, "ItemsUsed", 1)
	end
	local pos, dir = position(racer), look(racer)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis

	if item == "Boost" or item == "DoubleBoost" or item == "TripleBoost" then
		if racer.Player then
			RaceService.Services.Net.Effect:FireClient(racer.Player, "Boost", Config.ItemDurations.Boost)
		else
			racer.BoostUntil = t + Config.ItemDurations.Boost
		end
	elseif item == "Shield" then
		racer.ShieldUntil = t + Config.ItemDurations.Shield
		clearVisual(racer, "ShieldBubble")
		weldVisual(racer, "ShieldBubble", { Shape = Enum.PartType.Ball, Size = Vector3.new(11, 11, 11), Color = GOLD, Material = Enum.Material.ForceField, Transparency = 0.2 })
	elseif item == "Inferno" then
		racer.InfernoUntil = t + Config.ItemDurations.Inferno
		if racer.Player then
			RaceService.Services.Net.Effect:FireClient(racer.Player, "Inferno", Config.ItemDurations.Inferno)
		end
		clearVisual(racer, "InfernoAura")
		local aura = weldVisual(racer, "InfernoAura", { Shape = Enum.PartType.Ball, Size = Vector3.new(10, 8, 12), Color = Color3.fromRGB(255, 70, 20), Material = Enum.Material.ForceField, Transparency = 0.1 })
		local fire = Instance.new("Fire")
		fire.Size = 8
		fire.Heat = 12
		fire.Parent = aura
	elseif item == "Fireball" then
		spawnProjectile("Fireball", racer, { Position = pos + flat * 7, Direction = flat, Bounces = 3, Life = 4.5 })
	elseif item == "Homing" then
		local geo = RaceService.Services.TrackService.Current.Geometry
		local target = racerAhead(racer)
		spawnProjectile("Homing", racer, {
			Position = pos + flat * 7,
			Distance = (racer.Index - 1) / geo.Count * geo.Length + 8,
			Lateral = 0,
			Target = target,
			Life = 10,
		})
	elseif item == "Oil" then
		spawnProjectile("Oil", racer, { Position = pos - flat * 8 - Vector3.new(0, 1.3, 0), Life = 45 })
	elseif item == "Thunder" then
		RaceService.Services.Net.Effect:FireAllClients("Flash", 0.4)
		RaceService.Services.Net.SendAnnounce(`{racer.Name} unleashed a THUNDER BLAST!`, Color3.fromRGB(250, 240, 90))
		for _, other in RaceService.Racers do
			if other ~= racer and other.Place < racer.Place then
				hit(other, racer)
			end
		end
	end
	syncAttributes(racer)
end

local function rollItem(racer): string
	local count = math.max(1, #RaceService.Racers - 1)
	local fraction = (racer.Place - 1) / count
	local options = Config.ItemTable(fraction)
	local total = 0
	for _, option in options do
		total += option[2]
	end
	local roll = math.random() * total
	for _, option in options do
		roll -= option[2]
		if roll <= 0 then
			return option[1]
		end
	end
	return options[1][1]
end

local function giveItem(racer)
	if racer.Player then
		RaceService.Services.ProgressService:Add(racer.Player, "Boxes", 1)
	end
	local canDouble = racer.Player and racer.Player:GetAttribute("Pass_DoubleItems")
	if racer.Item == nil then
		racer.Item = rollItem(racer)
		racer.ItemReadyAt = now() + 1
		if racer.Bot then
			racer.UseAt = now() + 1.5 + math.random() * 3
		end
	elseif canDouble and racer.Item2 == nil then
		racer.Item2 = rollItem(racer)
	end
	syncAttributes(racer)
end

-- Fuer den Smoke-Test
RaceService.Debug = { UseItem = useItem, Hit = hit, Projectiles = projectiles }

---------------------------------------------------------------- Aufbau eines Rennens

local function newRacer(model: Model, name: string)
	return {
		Model = model,
		Root = model.PrimaryPart,
		Name = name,
		Index = 1,
		Lap = 0,
		Halfway = false,
		Progress = 0,
		Place = 1,
		Finished = false,
		FinishTime = math.huge,
		RaceCoins = 0,
		Item = nil :: string?,
		Item2 = nil :: string?,
		ItemReadyAt = 0,
		ShieldUntil = 0,
		InfernoUntil = 0,
		SpinUntil = 0,
		BoostUntil = 0,
		UseAt = math.huge,
	}
end

local function nameTag(model: Model, name: string, color: Color3, cpu: boolean, level: number?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameTag"
	gui.Size = UDim2.fromOffset(160, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.MaxDistance = 140
	gui.Parent = model.PrimaryPart
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = if cpu then name .. "  CPU" elseif level then `LV {level}  {name}` else name
	t.TextScaled = true
	t.FontFace = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
	t.TextColor3 = color
	t.Parent = gui
	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Color = Color3.fromRGB(20, 15, 25)
	s.Parent = t
end

local function spawnPlayer(player: Player, slot: number)
	local services = RaceService.Services
	local data = services.DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local kartId = data.Kart
	if not player:GetAttribute("Kart_" .. kartId) then
		kartId = "Ember"
	end
	local paintId = if data.Paints[data.Paint] then data.Paint else "Factory"
	local model = KartFactory.Build(kartId, data.Flame, { Paint = paintId })
	model.Name = player.Name
	model:SetAttribute("Driver", player.UserId)
	model:SetAttribute("RacerName", player.DisplayName)
	model:PivotTo(services.TrackService:GridCFrame(slot))
	model.Parent = kartsFolder
	nameTag(model, player.DisplayName, if player:GetAttribute("Pass_VIP") then GOLD else Color3.new(1, 1, 1), false, player:GetAttribute("Level") :: number?)
	local root = model.PrimaryPart :: BasePart
	pcall(root.SetNetworkOwner, root, player)

	local seat = model:FindFirstChild("DriverSeat") :: Seat
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)

	local racer = newRacer(model, player.DisplayName)
	racer.Player = player
	racer.Seat = seat
	racer.Humanoid = humanoid
	racer.Index = Tracks.Nearest(services.TrackService.Current.Geometry, root.Position)
	player:SetAttribute("Racing", true)
	player:SetAttribute("Kart", kartId)
	humanoid.Died:Connect(function()
		if racerOf(player) == racer and not racer.Finished then
			racer.Finished = true
			racer.DNF = true
		end
	end)
	return racer
end

local function spawnBot(slot: number, botIndex: number)
	local services = RaceService.Services
	local geo = services.TrackService.Current.Geometry
	local kart = Config.Karts[math.random(1, 5)]
	local names = Config.BotNames
	local name = names[(botIndex + math.random(0, #names - 1)) % #names + 1]
	local model = KartFactory.Build(kart.Id, Config.Flames[math.random(1, 5)].Id, { Bot = true, DriverColor = Color3.fromHSV(math.random(), 0.6, 0.95) })
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	model.Name = "CPU_" .. botIndex
	model:SetAttribute("RacerName", name)
	model:SetAttribute("IsBot", true)
	local grid = services.TrackService:GridCFrame(slot)
	model:PivotTo(grid)
	model.Parent = kartsFolder
	nameTag(model, name, Color3.fromRGB(200, 200, 215), true)

	local racer = newRacer(model, name)
	racer.Bot = true
	racer.Kart = kart
	racer.Skill = 0.86 + math.random() * 0.1
	local index = Tracks.Nearest(geo, grid.Position)
	racer.Index = index
	racer.Distance = (index - 1) / geo.Count * geo.Length - geo.Length -- negativ: vor der Startlinie
	racer.Lateral = (grid.Position - geo.Points[index]):Dot(geo.Rights[index]) / (geo.Width / 2)
	racer.TargetLateral = racer.Lateral
	racer.Speed = 0
	racer.Position = grid.Position
	racer.Look = grid.LookVector
	racer.Spin = 0
	return racer
end

local function clearRace()
	if RaceService.Heartbeat then
		RaceService.Heartbeat:Disconnect()
		RaceService.Heartbeat = nil
	end
	for _, racer in RaceService.Racers do
		if racer.Player then
			racer.Player:SetAttribute("Racing", nil)
			racer.Player:SetAttribute("Item", nil)
			racer.Player:SetAttribute("Item2", nil)
			racer.Player:SetAttribute("Finished", nil)
		end
	end
	RaceService.Racers = {}
	kartsFolder:ClearAllChildren()
	fxFolder:ClearAllChildren()
	table.clear(projectiles)
end

---------------------------------------------------------------- Fortschritt, Bots, Pickups (laufend)

local function updatePlayerProgress(racer, geo)
	local n = geo.Count
	local root = racer.Root
	if not root or not root.Parent then
		return
	end
	local idx = Tracks.Nearest(geo, root.Position, racer.Index, 15, 40)
	local prev = racer.Index
	-- Schutz gegen Teleportieren: vorwaerts nur so weit, wie ein Kart in der Zeit fahren kann (mit Reserve)
	local clock = os.clock()
	local elapsed = clock - (racer.ProgressAt or clock)
	racer.ProgressAt = clock
	local delta = (idx - prev + n / 2) % n - n / 2
	local maxAhead = math.ceil(elapsed * 300 / (geo.Length / n)) + 3
	if delta > maxAhead then
		idx = prev
	end
	if prev > n * 0.75 and idx < n * 0.25 then
		if racer.Halfway or racer.Lap == 0 then
			racer.Lap += 1
			racer.Halfway = false
		end
	elseif prev < n * 0.25 and idx > n * 0.75 and racer.Lap > 0 then
		racer.Lap -= 1
		racer.Halfway = true
	end
	if idx > n * 0.4 and idx < n * 0.6 then
		racer.Halfway = true
	end
	racer.Index = idx
	racer.Progress = racer.Lap * n + idx
	-- Wieder hinsetzen, falls der Spieler aus dem Sitz gefallen ist
	if racer.Humanoid and racer.Seat and racer.Humanoid.SeatPart ~= racer.Seat and racer.Humanoid.Health > 0 then
		racer.Seat:Sit(racer.Humanoid)
	end
end

local function updateBot(racer, geo, dt: number, leaderHuman: number?)
	local t = now()
	local n = geo.Count
	local spacing = geo.Length / n
	local target = racer.Kart.Speed * racer.Skill * (1 + racer.RaceCoins * Config.CoinSpeedBonus)
	-- Gummiband: CPU bleibt in der Naehe der menschlichen Spieler, damit Rennen spannend bleiben
	if leaderHuman then
		local diff = racer.Progress - leaderHuman
		if diff > 25 then
			target *= 0.88
		elseif diff < -40 then
			target *= 1.12
		end
	end
	if racer.BoostUntil > t then
		target *= Config.BoostMultiplier
	end
	if racer.InfernoUntil > t then
		target *= Config.InfernoMultiplier
	end
	if racer.SpinUntil > t then
		racer.Speed = math.max(0, racer.Speed - 90 * dt)
		racer.Spin += dt * 14
	else
		racer.Spin = 0
		local accel = if racer.Speed < target then 30 else 60
		racer.Speed += math.clamp(target - racer.Speed, -accel * dt, accel * dt)
	end
	racer.Distance += racer.Speed * dt
	if math.random() < dt * 0.4 then
		racer.TargetLateral = math.random() * 1.1 - 0.55
	end
	racer.Lateral += math.clamp(racer.TargetLateral - racer.Lateral, -dt * 0.4, dt * 0.4)
	local pos, tangent = Tracks.PointAt(geo, racer.Distance, racer.Lateral)
	pos += Vector3.new(0, Config.HoverHeight, 0)
	racer.Position = pos
	racer.Look = tangent
	local cf = CFrame.lookAt(pos, pos + tangent) * CFrame.Angles(0, racer.Spin, 0)
	racer.Model:PivotTo(cf)
	local progress = n + racer.Distance / spacing
	racer.Progress = progress
	racer.Index = math.floor(progress) % n + 1
	racer.Lap = math.floor(progress / n)
	setFlame(racer, racer.BoostUntil > t or racer.InfernoUntil > t)
	if racer.Item and t > racer.UseAt then
		racer.UseAt = math.huge
		useItem(racer)
		if racer.Item then
			racer.UseAt = t + 0.8
		end
	end
end

local function updateProjectiles(dt: number, current)
	local t = now()
	local geo = current.Geometry
	local roadParams = RaycastParams.new()
	roadParams.FilterType = Enum.RaycastFilterType.Include
	roadParams.FilterDescendantsInstances = { current.RoadFolder }
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Include
	wallParams.FilterDescendantsInstances = { current.Folder:FindFirstChild("Walls") :: Instance }

	for i = #projectiles, 1, -1 do
		local pr = projectiles[i]
		local dead = t - pr.Born > pr.Life
		if not dead and pr.Kind == "Fireball" then
			local step = pr.Direction * 150 * dt
			local wall = workspace:Raycast(pr.Position, step, wallParams)
			if wall then
				local normal = Vector3.new(wall.Normal.X, 0, wall.Normal.Z).Unit
				pr.Direction = (pr.Direction - 2 * pr.Direction:Dot(normal) * normal).Unit
				pr.Bounces -= 1
				dead = pr.Bounces < 0
			else
				pr.Position += step
			end
			local ground = workspace:Raycast(pr.Position + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), roadParams)
			pr.Position = if ground then Vector3.new(pr.Position.X, ground.Position.Y + 1.6, pr.Position.Z) else pr.Position - Vector3.new(0, 60 * dt, 0)
			pr.Part.CFrame = CFrame.new(pr.Position)
		elseif not dead and pr.Kind == "Homing" then
			local target = pr.Target
			local targetPos = if target and not target.Finished then position(target) else nil
			if targetPos and (targetPos - pr.Position).Magnitude < 35 then
				pr.Position += (targetPos - pr.Position).Unit * 175 * dt
			else
				pr.Distance += 165 * dt
				if target and targetPos then
					local idx = target.Index
					local lat = (targetPos - geo.Points[idx]):Dot(geo.Rights[idx]) / (geo.Width / 2)
					pr.Lateral += math.clamp(lat - pr.Lateral, -dt, dt)
				end
				local p = Tracks.PointAt(geo, pr.Distance, pr.Lateral)
				pr.Position = p + Vector3.new(0, 1.8, 0)
			end
			pr.Part.CFrame = CFrame.new(pr.Position)
		end
		if not dead then
			for _, racer in RaceService.Racers do
				if racer.Finished or (racer == pr.Owner and t - pr.Born < 0.6) then
					continue
				end
				local radius = if pr.Kind == "Oil" then 5.5 else 5
				local rp = position(racer)
				if (rp - pr.Position).Magnitude < radius + 2 then
					hit(racer, pr.Owner)
					dead = true
					break
				end
			end
		end
		if dead then
			pr.Part:Destroy()
			table.remove(projectiles, i)
		end
	end
end

local function updatePickups(current)
	local t = now()
	for _, racer in RaceService.Racers do
		if racer.Finished then
			continue
		end
		local rp = position(racer)
		for _, box in current.Boxes do
			if box.ReadyAt <= t and (box.Position - rp).Magnitude < 6 then
				box.ReadyAt = t + 3
				box.Part.Transparency = 1
				box.Part.Core.Transparency = 1
				box.Part.BillboardGui.Enabled = false
				giveItem(racer)
			end
		end
		for _, coin in current.Coins do
			if coin.ReadyAt <= t and (coin.Position - rp).Magnitude < 5.5 then
				coin.ReadyAt = t + 10
				coin.Part.Transparency = 1
				if racer.Player then
					RaceService.Services.ProgressService:Add(racer.Player, "TrackCoins", 1)
				end
				if racer.RaceCoins < Config.MaxRaceCoins then
					racer.RaceCoins += 1
					syncAttributes(racer)
				end
			end
		end
		-- Inferno rammt alle in der Naehe
		if racer.InfernoUntil > t then
			for _, other in RaceService.Racers do
				if other ~= racer and (position(other) - rp).Magnitude < 8 then
					hit(other, racer)
				end
			end
		end
		if racer.ShieldUntil > 0 and racer.ShieldUntil < t then
			racer.ShieldUntil = 0
			clearVisual(racer, "ShieldBubble")
		end
		if racer.InfernoUntil > 0 and racer.InfernoUntil < t then
			racer.InfernoUntil = 0
			clearVisual(racer, "InfernoAura")
		end
	end
	for _, box in current.Boxes do
		if box.ReadyAt > 0 and box.ReadyAt <= t then
			box.ReadyAt = 0
			box.Part.Transparency = 0.35
			box.Part.Core.Transparency = 0
			box.Part.BillboardGui.Enabled = true
		end
	end
	for _, coin in current.Coins do
		if coin.ReadyAt > 0 and coin.ReadyAt <= t then
			coin.ReadyAt = 0
			coin.Part.Transparency = 0
		end
	end
end

local function updatePlaces(raceStart: number)
	local list = table.clone(RaceService.Racers)
	-- Rang: im Ziel (0) vor noch fahrend (1) vor ausgeschieden (2); sonst ist die Sortierung nicht eindeutig
	local function rank(r): number
		return if r.DNF then 2 elseif r.Finished then 0 else 1
	end
	table.sort(list, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		if ra == 0 then
			return a.FinishTime < b.FinishTime
		end
		return a.Progress > b.Progress
	end)
	for place, racer in list do
		racer.Place = place
	end
	local n = RaceService.Services.TrackService.Current.Geometry.Count
	for _, racer in list do
		if not racer.Finished and racer.Progress >= (Config.Laps + 1) * n then
			racer.Finished = true
			racer.FinishTime = now() - raceStart
			if racer.Player then
				RaceService.Services.Net.Effect:FireClient(racer.Player, "Finish", racer.Place)
			end
			if not RaceService.FirstFinish then
				RaceService.FirstFinish = now()
				RaceService.Services.Net.SendAnnounce(`{racer.Name} wins the race in {Format.Time(racer.FinishTime)}!`, GOLD)
			end
		end
		syncAttributes(racer)
	end
end

---------------------------------------------------------------- Phasen

local function pickChoices(): { string }
	local pool = {}
	for _, track in Tracks.List do
		if track.Id ~= RaceService.LastTrack then
			table.insert(pool, track.Id)
		end
	end
	local choices = {}
	for _ = 1, Config.VoteChoices do
		table.insert(choices, table.remove(pool, math.random(1, #pool)) :: string)
	end
	return choices
end

local function updateVotes(choices: { string })
	local counts = {}
	for _, id in choices do
		counts[id] = 0
	end
	for player, id in votes do
		if player.Parent and counts[id] then
			counts[id] += 1
		end
	end
	for _, id in choices do
		workspace:SetAttribute("Votes_" .. id, counts[id])
	end
	return counts
end

function RaceService:Intermission()
	local choices = pickChoices()
	table.clear(votes)
	workspace:SetAttribute("VoteChoices", table.concat(choices, ","))
	updateVotes(choices)
	setPhase("Intermission", Config.IntermissionTime)
	self.Choices = choices
	local deadline = now() + Config.IntermissionTime
	while now() < deadline and not self.SkipWait do
		local remaining = math.ceil(deadline - now())
		self.Services.LobbyService:SetStatus("VOTE NOW", `Race starts in {remaining}s`)
		task.wait(0.25)
		-- Ohne Spieler nicht starten
		while #Players:GetPlayers() == 0 do
			task.wait(1)
			deadline = now() + Config.IntermissionTime
		end
	end
	self.SkipWait = false
	local counts = updateVotes(choices)
	local winner = choices[math.random(1, #choices)]
	local best = -1
	for _, id in choices do
		if counts[id] > best then
			winner, best = id, counts[id]
		end
	end
	if self.ForcedTrack then
		winner = self.ForcedTrack
		self.Services.Net.SendAnnounce(`{self.ForcedBy} picked {Tracks.ById[winner].Name}!`, GOLD)
		self.ForcedTrack = nil
	end
	workspace:SetAttribute("VoteChoices", "")
	return winner
end

function RaceService:StartRace(trackId: string)
	local services = self.Services
	self.LastTrack = trackId
	services.TrackService:Load(trackId)
	local def = Tracks.ById[trackId]
	services.LobbyService:SetStatus(def.Name:upper(), "Race in progress")

	clearRace()
	self.FirstFinish = nil
	local slot = 0
	local humans = Players:GetPlayers()
	for i = #humans, 2, -1 do
		local j = math.random(1, i)
		humans[i], humans[j] = humans[j], humans[i]
	end
	for _, player in humans do
		if slot >= Config.MaxRacers then
			break
		end
		local racer = spawnPlayer(player, slot + 1)
		if racer then
			slot += 1
			table.insert(self.Racers, racer)
		end
	end
	local botIndex = 0
	while slot < Config.MaxRacers do
		slot += 1
		botIndex += 1
		table.insert(self.Racers, spawnBot(slot, botIndex))
	end
	for place, racer in self.Racers do
		racer.Place = place
		syncAttributes(racer)
	end

	-- Countdown mit Startampel
	setPhase("Countdown", Config.CountdownTime)
	for k = 1, 3 do
		task.wait(Config.CountdownTime / 4)
		services.TrackService:SetLights(k, false)
	end
	task.wait(Config.CountdownTime / 4)
	services.TrackService:SetLights(4, true)

	local raceStart = now()
	workspace:SetAttribute("RaceStart", raceStart)
	setPhase("Race", Config.MaxRaceTime)
	for _, racer in self.Racers do
		if racer.Bot and math.random() < 0.35 then
			racer.BoostUntil = raceStart + 1 -- manche CPU erwischen den Raketenstart
		end
	end

	local current = services.TrackService.Current
	local geo = current.Geometry
	local tickAt = 0
	local hadHumans = false
	for _, racer in self.Racers do
		if racer.Player then
			hadHumans = true
		end
	end
	local heartbeat
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		local leaderHuman = nil
		for _, racer in self.Racers do
			if racer.Player and not racer.Finished then
				leaderHuman = math.max(leaderHuman or -math.huge, racer.Progress)
			end
		end
		for _, racer in self.Racers do
			if racer.Bot and not racer.Finished then
				updateBot(racer, geo, dt, leaderHuman)
			elseif racer.Bot and racer.Finished then
				-- Nach dem Ziel langsam ausrollen
				racer.Speed = math.max(25, racer.Speed - 20 * dt)
				racer.Distance += racer.Speed * dt
				local pos, tangent = Tracks.PointAt(geo, racer.Distance, racer.Lateral)
				pos += Vector3.new(0, Config.HoverHeight, 0)
				racer.Position = pos
				racer.Model:PivotTo(CFrame.lookAt(pos, pos + tangent))
			end
		end
		updateProjectiles(dt, current)
		tickAt += dt
		if tickAt >= 0.1 then
			tickAt = 0
			for _, racer in self.Racers do
				if racer.Player and not racer.Finished then
					if not racer.Player.Parent or not racer.Model.Parent then
						racer.Finished = true
						racer.DNF = true
					else
						updatePlayerProgress(racer, geo)
					end
				end
			end
			updatePickups(current)
			updatePlaces(raceStart)
		end
	end)
	self.Heartbeat = heartbeat

	-- Ende: alle Menschen im Ziel, Zeitlimit oder Gnadenfrist nach dem Sieger
	while true do
		task.wait(0.25)
		local humansLeft = 0
		for _, racer in self.Racers do
			if racer.Player and not racer.Finished then
				humansLeft += 1
			end
		end
		local t = now()
		-- Reine CPU-Rennen (Smoke-Test) laufen bis zum Sieger + Gnadenfrist
		if humansLeft == 0 and hadHumans then
			task.wait(1.5)
			break
		end
		if t - raceStart > Config.MaxRaceTime then
			break
		end
		if self.FirstFinish and t - self.FirstFinish > Config.FinishGrace then
			break
		end
		if self.FirstFinish then
			workspace:SetAttribute("PhaseEnd", math.min(raceStart + Config.MaxRaceTime, self.FirstFinish + Config.FinishGrace))
		end
	end
	heartbeat:Disconnect()
	self.Heartbeat = nil
	updatePlaces(raceStart)
	self:FinishRace(raceStart)
end

function RaceService:FinishRace(raceStart: number)
	local services = self.Services
	local list = table.clone(self.Racers)
	table.sort(list, function(a, b)
		return a.Place < b.Place
	end)
	local board = {}
	for _, racer in list do
		table.insert(board, {
			Name = racer.Name,
			Place = racer.Place,
			Bot = racer.Bot == true,
			Time = if racer.Finished and not racer.DNF then racer.FinishTime else nil,
			UserId = racer.Player and racer.Player.UserId or 0,
		})
	end
	setPhase("Results", Config.ResultsTime)
	for _, racer in list do
		local player = racer.Player
		if player and player.Parent and not racer.DNF then
			local data = services.DataService:Get(player)
			if data then
				local base = Config.PlaceCoins[racer.Place] or 50
				local coins = (base + racer.RaceCoins * Config.CoinPickupValue) * services.MonetizationService:CoinMultiplier(player)
				coins = math.floor(coins)
				services.DataService:AddCoins(player, coins)
				data.Races += 1
				if racer.Place == 1 then
					data.Wins += 1
					services.LobbyService:SubmitWins(player, data.Wins)
				end
				if racer.Place <= 3 then
					data.Podiums += 1
				end
				services.DataService:UpdateAttributes(player)
				local progressOk, extra = pcall(services.ProgressService.AfterRace, services.ProgressService, player, self.LastTrack, racer.Place, #list, if racer.Finished then racer.FinishTime else nil)
				if not progressOk then
					warn("[RaceService] Fortschritt fehlgeschlagen:", extra)
					extra = {}
				end
				services.Net.Results:FireClient(player, board, {
					Place = racer.Place,
					Coins = coins + (extra.StreakBonus or 0),
					Multiplier = services.MonetizationService:CoinMultiplier(player),
					Xp = extra.Xp,
					Streak = extra.Streak,
					StreakBonus = extra.StreakBonus,
					Best = extra.Best,
					NewBest = extra.NewBest,
				})
				task.delay(4, function()
					services.MonetizationService:AfterRace(player, racer.Place)
				end)
			end
		end
	end
	for _, player in Players:GetPlayers() do
		local racer = racerOf(player)
		-- Zuschauer und ausgeschiedene Fahrer sehen das Ergebnis ohne Belohnung
		if not racer or racer.DNF then
			services.Net.Results:FireClient(player, board, nil)
		end
	end
	services.LobbyService:SetStatus("RESULTS", (board[1] and board[1].Name or "") .. " won!")
	task.wait(Config.ResultsTime)

	local racingPlayers = {}
	for _, racer in self.Racers do
		if racer.Player and racer.Player.Parent then
			table.insert(racingPlayers, racer.Player)
		end
	end
	clearRace()
	for _, player in racingPlayers do
		task.spawn(player.LoadCharacter, player)
	end
end

function RaceService:Start()
	local services = self.Services
	services.Net.Vote.OnServerEvent:Connect(function(player, trackId)
		if self.Phase == "Intermission" and typeof(trackId) == "string" and self.Choices and table.find(self.Choices, trackId) then
			votes[player] = trackId
			updateVotes(self.Choices)
		end
	end)
	services.Net.UseItem.OnServerEvent:Connect(function(player)
		local racer = racerOf(player)
		if racer and self.Phase == "Race" then
			useItem(racer)
		end
	end)
	services.Net.UseSuper.OnServerEvent:Connect(function(player)
		local racer = racerOf(player)
		local data = services.DataService:Get(player)
		if not racer or self.Phase ~= "Race" or racer.Finished or not data or data.SuperItems <= 0 then
			return
		end
		data.SuperItems -= 1
		services.DataService:UpdateAttributes(player)
		local keep, keep2, keepReady = racer.Item, racer.Item2, racer.ItemReadyAt
		racer.Item, racer.Item2, racer.ItemReadyAt = "Inferno", nil, 0
		racer.SuperUse = true
		useItem(racer)
		racer.SuperUse = nil
		racer.Item, racer.Item2, racer.ItemReadyAt = keep, keep2, keepReady
		syncAttributes(racer)
	end)
	services.Net.Boosting.OnServerEvent:Connect(function(player, on)
		local racer = racerOf(player)
		local flag = on == true
		-- Nur echte Wechsel verarbeiten (Spam wuerde sonst jedes Mal alle Teile durchsuchen)
		if racer and racer.FlameOn ~= flag then
			racer.FlameOn = flag
			setFlame(racer, flag)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		votes[player] = nil
		local racer = racerOf(player)
		if racer then
			racer.Finished = true
			racer.DNF = true
			if racer.Model then
				racer.Model:Destroy()
			end
		end
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				local trackId = self:Intermission()
				self:StartRace(trackId)
			end)
			if not ok then
				warn("[RaceService]", err)
				clearRace()
				for _, player in Players:GetPlayers() do
					task.spawn(player.LoadCharacter, player)
				end
				task.wait(3)
			end
		end
	end)
end

return RaceService
