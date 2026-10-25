-- Dungeons: Lobby an den Portalen (Koop bis 4 Spieler), Aufbau der Raeume, Wellen, Boss,
-- Belohnungen, Tod/Wiederbelebung und Rueckkehr in die Stadt.
-- Ablauf eines Laufs: Startraum -> 4 Kampfraeume mit je 2 Wellen -> Bossraum -> Truhe und Zusammenfassung.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local DungeonService = { Services = nil :: any }

local runs = {} -- [Id] = Lauf
local runOf = {} -- [Player] = Lauf
local lobbies = {} -- [DungeonIndex] = { Players, Difficulty, StartsAt }
local lobbyOf = {} -- [Player] = DungeonIndex
local slots = {} -- [Slot] = Lauf
local nextId = 0
local rng = Random.new()
local lockedNotice = {} -- [Player] = os.clock()

local GOLD = Color3.fromRGB(255, 200, 60)
local RED = Color3.fromRGB(255, 90, 90)
local stats: (any, Player) -> any -- weiter unten definiert

local CORRIDOR = 22
local WALL_HEIGHT = 6

-- Material je Dungeon-Thema
local THEMES = {
	Mushrooms = { Floor = Enum.Material.Grass, Wall = Enum.Material.Rock },
	Mine = { Floor = Enum.Material.Ground, Wall = Enum.Material.Rock },
	Ice = { Floor = Enum.Material.Glacier, Wall = Enum.Material.Ice },
	Forge = { Floor = Enum.Material.Basalt, Wall = Enum.Material.Basalt },
	Temple = { Floor = Enum.Material.Slate, Wall = Enum.Material.Sandstone },
	Stars = { Floor = Enum.Material.Marble, Wall = Enum.Material.Slate },
}

function DungeonService:Init(services)
	self.Services = services
end

function DungeonService:GetRun(player: Player)
	return runOf[player]
end

function DungeonService:IsUnlocked(player: Player, index: number): boolean
	if index <= 1 then
		return true
	end
	local data = self.Services.DataService:Get(player)
	local previous = Config.Dungeons[index - 1]
	return data ~= nil and (data.Cleared[previous.Id] or 0) >= 1
end

-- Hoechste waehlbare Schwierigkeit: die naechste nach der hoechsten geschafften
function DungeonService:MaxDifficulty(player: Player, index: number): number
	local data = self.Services.DataService:Get(player)
	local cleared = data and data.Cleared[Config.Dungeons[index].Id] or 0
	return math.clamp(cleared + 1, 1, #Config.Difficulties)
end

---------------------------------------------------------------- Karte bauen

local function makePrompt(parent: BasePart, action: string, object: string, hold: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = hold
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Schrein: ein Spieler aktiviert ihn, die ganze Gruppe bekommt den Buff
local function buildShrine(run, room, p)
	local W = DungeonService.Services.WorldService
	local key = Config.ShrineOrder[rng:NextInteger(1, #Config.ShrineOrder)]
	local def = Config.Shrines[key]
	local limit = room.Half - 9
	local spot = room.Center + Vector3.new(rng:NextNumber(-limit, limit), 0, rng:NextNumber(-limit, limit))
	p({ Name = "ShrineBase", Size = Vector3.new(4, 1.2, 4), Position = spot + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(80, 78, 96), Material = Enum.Material.Slate })
	local orb = p({ Name = "ShrineOrb", Shape = Enum.PartType.Ball, Size = Vector3.one * 2.2, Position = spot + Vector3.new(0, 3, 0), Color = def.Color, Material = Enum.Material.Neon, CanCollide = false })
	orb:AddTag("Bob")
	local glow = W.Light(orb, def.Color, 16, 1.6)
	local prompt = makePrompt(orb, "Activate", `{def.Name} ({def.Text})`, 0.3)
	prompt.Triggered:Connect(function(player)
		if runOf[player] ~= run or run.State ~= "Running" or not prompt.Enabled then
			return
		end
		prompt.Enabled = false
		local services = DungeonService.Services
		local untilTime = workspace:GetServerTimeNow() + def.Seconds
		for _, member in run.Players do
			member:SetAttribute("Buff_" .. key, untilTime)
			services.Net.SendNotify(member, `{player.DisplayName} activated the {def.Name}: {def.Text} for {def.Seconds}s!`, def.Color)
		end
		services.Net.SendEffect(run.Players, "Nova", { Position = orb.Position, Radius = 12, Color = def.Color })
		orb.Material = Enum.Material.SmoothPlastic
		orb.Transparency = 0.6
		glow.Enabled = false
		local data = services.DataService:Get(player)
		if data then
			data.ShrinesUsed += 1
		end
		services.ProgressService:Track(player, "Shrine")
	end)
end

-- Versteckte Truhe an einer Seitenwand: jeder Spieler darf sie einmal oeffnen
local function buildChest(run, room, p)
	local side = if rng:NextNumber() < 0.5 then -1 else 1
	local spot = room.Center + Vector3.new(side * (room.Half - 4), 0, rng:NextNumber(-room.Half + 7, room.Half - 7))
	local cf = CFrame.lookAt(spot, Vector3.new(room.Center.X, spot.Y, spot.Z))
	p({ Name = "ChestBody", Size = Vector3.new(3.4, 2, 2.2), CFrame = cf * CFrame.new(0, 1, 0), Color = Color3.fromRGB(140, 96, 56), Material = Enum.Material.WoodPlanks })
	p({ Name = "ChestLid", Size = Vector3.new(3.6, 0.8, 2.4), CFrame = cf * CFrame.new(0, 2.4, 0), Color = Color3.fromRGB(200, 150, 60), Material = Enum.Material.Metal })
	local lock = p({ Name = "ChestLock", Size = Vector3.new(0.6, 0.7, 0.3), CFrame = cf * CFrame.new(0, 1.9, -1.2), Color = Color3.fromRGB(255, 210, 80), Material = Enum.Material.Neon, CanCollide = false })
	DungeonService.Services.WorldService.Light(lock, Color3.fromRGB(255, 210, 80), 10, 1)
	local opened = {}
	local prompt = makePrompt(lock, "Open", "Hidden Chest", 0.6)
	prompt.Triggered:Connect(function(player)
		if runOf[player] ~= run or run.State ~= "Running" then
			return
		end
		local services = DungeonService.Services
		if opened[player] then
			services.Net.SendNotify(player, "You already looted this chest.", RED)
			return
		end
		opened[player] = true
		local difficulty = Config.Difficulties[run.Difficulty]
		local mult = if run.Featured then 1 + Config.FeaturedBonus else 1
		local gold = services.HeroService:GiveGold(player, Config.KillGold(run.Level) * 12 * difficulty.Loot * mult, lock.Position)
		stats(run, player).Gold += gold
		if rng:NextNumber() < 0.5 then
			services.LootService:DropItem(player, run, { MinRarity = 2, Luck = difficulty.Loot }, lock.Position)
		end
		services.Net.Effect:FireClient(player, "Chest", { Position = lock.Position })
		services.Net.SendNotify(player, `Hidden chest: +{gold} gold!`, GOLD)
		local data = services.DataService:Get(player)
		if data then
			data.ChestsOpened += 1
		end
		services.ProgressService:Track(player, "Chest")
	end)
end

local function buildRun(run)
	local W = DungeonService.Services.WorldService
	local Part, Light = W.Part, W.Light
	local dungeon = run.Dungeon
	local theme = THEMES[dungeon.Props] or THEMES.Mushrooms
	local folder = Instance.new("Folder")
	folder.Name = "Run_" .. run.Id
	folder.Parent = W.DungeonFolder
	run.Folder = folder
	local origin = run.Origin

	local function p(props)
		props.Parent = props.Parent or folder
		return Part(props)
	end

	-- Raumgroessen: Start, 4 Kampfraeume, Boss
	local halves = { 18 }
	for _ = 1, Config.RoomsPerRun do
		table.insert(halves, 30)
	end
	table.insert(halves, 44)

	local z = 0
	local total = 0
	for index, half in halves do
		if index > 1 then
			z += halves[index - 1] + CORRIDOR + half
		end
		total = z + half
		local center = origin + Vector3.new(0, 0, z)
		local room = {
			Index = index,
			Center = center,
			Half = half,
			State = if index == 1 then "Cleared" else "Idle",
			Boss = index == #halves,
			Wave = 0,
			Order = index - 1, -- 1-4 fuer Kampfraeume
		}
		run.Rooms[index] = room

		p({ Name = "Floor", Size = Vector3.new(half * 2, 2, half * 2), Position = center + Vector3.new(0, -1, 0), Color = dungeon.Floor, Material = theme.Floor })
		-- Waende mit Luecken fuer die Gaenge (vorne +Z, hinten -Z)
		local gap = 7
		for _, side in { -1, 1 } do
			p({ Name = "Wall", Size = Vector3.new(2, WALL_HEIGHT, half * 2 + 4), Position = center + Vector3.new(side * (half + 1), WALL_HEIGHT / 2, 0), Color = dungeon.Wall, Material = theme.Wall })
			local hasDoor = (side == 1 and index < #halves) or (side == -1 and index > 1)
			if hasDoor then
				local length = half - gap
				for _, x in { -1, 1 } do
					p({ Name = "Wall", Size = Vector3.new(length + 2, WALL_HEIGHT, 2), Position = center + Vector3.new(x * (gap + length / 2), WALL_HEIGHT / 2, side * (half + 1)), Color = dungeon.Wall, Material = theme.Wall })
				end
			else
				p({ Name = "Wall", Size = Vector3.new(half * 2 + 4, WALL_HEIGHT, 2), Position = center + Vector3.new(0, WALL_HEIGHT / 2, side * (half + 1)), Color = dungeon.Wall, Material = theme.Wall })
			end
		end
		-- Laternen in den Ecken
		for _, corner in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			local base = center + corner * (half - 2.5)
			p({ Name = "LanternPole", Size = Vector3.new(0.8, 7, 0.8), Position = base + Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(60, 50, 44), Material = Enum.Material.Metal })
			local lamp = p({ Name = "Lantern", Size = Vector3.new(1.6, 2, 1.6), Position = base + Vector3.new(0, 7.6, 0), Color = dungeon.Light, Material = Enum.Material.Neon, CanCollide = false })
			lamp:AddTag("Flicker")
			Light(lamp, dungeon.Light, 30, 1.8)
		end
		-- Deko am Rand je nach Thema
		for i = 1, if room.Boss then 10 else 6 do
			local edge = rng:NextInteger(1, 4)
			local along = rng:NextNumber(-half + 6, half - 6)
			local inset = half - rng:NextNumber(2.5, 5)
			local spot = center
				+ (if edge == 1 then Vector3.new(-inset, 0, along) elseif edge == 2 then Vector3.new(inset, 0, along) elseif edge == 3 then Vector3.new(along, 0, -inset) else Vector3.new(along, 0, inset))
			if math.abs(spot.X - center.X) < 9 then
				continue -- Tueren frei halten
			end
			local s = rng:NextNumber(0.8, 1.5)
			local props = dungeon.Props
			if props == "Mushrooms" then
				p({ Name = "Stem", Size = Vector3.new(1.4, 4, 1.4) * s, Position = spot + Vector3.new(0, 2 * s, 0), Color = Color3.fromRGB(240, 226, 196), CanCollide = false })
				local cap = p({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 2.4, 5) * s, Position = spot + Vector3.new(0, 4.2 * s, 0), Color = if i % 2 == 0 then dungeon.Accent else Color3.fromRGB(230, 80, 90), Material = if i % 2 == 0 then Enum.Material.Neon else Enum.Material.SmoothPlastic, CanCollide = false })
				if i % 2 == 0 then
					Light(cap, dungeon.Accent, 14, 1)
				end
			elseif props == "Mine" then
				p({ Name = "Crate", Size = Vector3.new(3, 3, 3) * s, CFrame = CFrame.new(spot + Vector3.new(0, 1.5 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color = Color3.fromRGB(140, 100, 60), Material = Enum.Material.WoodPlanks })
				if i % 2 == 0 then
					local gem = p({ Name = "Ore", Size = Vector3.new(1.2, 2.4, 1.2) * s, CFrame = CFrame.new(spot + Vector3.new(0, 4 * s, 0)) * CFrame.Angles(0.3, 0.6, 0.2), Color = dungeon.Accent, Material = Enum.Material.Neon, CanCollide = false })
					gem:AddTag("Spin")
				end
			elseif props == "Ice" then
				for k = 1, 3 do
					p({ Name = "IceSpike", Size = Vector3.new(1.2, 5 - k, 1.2) * s, CFrame = CFrame.new(spot + Vector3.new(k - 2, (5 - k) * s / 2, (k % 2) - 0.5)) * CFrame.Angles(0, 0, math.rad((k - 2) * 12)), Color = dungeon.Accent, Material = Enum.Material.Ice, Transparency = 0.2, CanCollide = false })
				end
			elseif props == "Forge" then
				local lava = p({ Name = "Lava", Size = Vector3.new(6, 0.2, 4) * s, Position = spot + Vector3.new(0, 0.05, 0), Color = dungeon.Accent, Material = Enum.Material.Neon, CanCollide = false })
				Light(lava, dungeon.Accent, 14, 1.4)
				p({ Name = "Rock", Size = Vector3.new(2, 2, 2) * s, CFrame = CFrame.new(spot + Vector3.new(2, 1, 1)) * CFrame.Angles(0.4, 0.2, 0.5), Color = dungeon.Wall, Material = Enum.Material.Basalt })
			elseif props == "Temple" then
				p({ Name = "Pillar", Size = Vector3.new(2.4, 9, 2.4), Position = spot + Vector3.new(0, 4.5, 0), Color = Color3.fromRGB(200, 196, 170), Material = Enum.Material.Sandstone })
				local coral = p({ Name = "Coral", Shape = Enum.PartType.Ball, Size = Vector3.one * 2 * s, Position = spot + Vector3.new(1.6, 1, 0), Color = dungeon.Accent, Material = Enum.Material.Neon, CanCollide = false })
				Light(coral, dungeon.Accent, 12, 1)
			else
				local star = p({ Name = "StarCrystal", Size = Vector3.new(1.6, 3.6, 1.6) * s, CFrame = CFrame.new(spot + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0.7, 0.3), Color = dungeon.Accent, Material = Enum.Material.Neon, CanCollide = false })
				star:AddTag("Bob")
				Light(star, dungeon.Accent, 14, 1.2)
			end
		end

		-- Gang und Tor zum naechsten Raum
		if index < #halves then
			local corridorCenter = center + Vector3.new(0, 0, half + CORRIDOR / 2 + 2)
			p({ Name = "Corridor", Size = Vector3.new(gap * 2, 2, CORRIDOR + 4), Position = corridorCenter + Vector3.new(0, -1, 0), Color = dungeon.Floor, Material = theme.Floor })
			for _, x in { -1, 1 } do
				p({ Name = "Wall", Size = Vector3.new(2, WALL_HEIGHT, CORRIDOR + 2), Position = corridorCenter + Vector3.new(x * (gap + 1), WALL_HEIGHT / 2, 0), Color = dungeon.Wall, Material = theme.Wall })
			end
			local gate = p({
				Name = "Gate",
				Size = Vector3.new(gap * 2, WALL_HEIGHT + 2, 1),
				Position = center + Vector3.new(0, (WALL_HEIGHT + 2) / 2, half + 1),
				Color = dungeon.Accent,
				Material = Enum.Material.ForceField,
				Transparency = 0.1,
			})
			Light(gate, dungeon.Accent, 16, 1.5)
			room.Gate = gate
		end
		-- Kampfraeume: manchmal ein Schrein, manchmal eine versteckte Truhe
		if index > 1 and not room.Boss then
			if rng:NextNumber() < Config.ShrineChance then
				buildShrine(run, room, p)
			end
			if rng:NextNumber() < Config.ChestChance then
				buildChest(run, room, p)
			end
		end
	end

	-- Dunkler Untergrund, damit man nicht in den Himmel schaut
	p({ Name = "Abyss", Size = Vector3.new(400, 2, total + 200), Position = origin + Vector3.new(0, -12, total / 2), Color = Color3.fromRGB(16, 16, 30), Material = Enum.Material.SmoothPlastic })

	-- Rueckkehr-Portal im Startraum
	local start = run.Rooms[1]
	local back = p({ Name = "ReturnPortal", Size = Vector3.new(6, 8, 1), Position = start.Center + Vector3.new(0, 4, -start.Half + 3), Color = Color3.fromRGB(255, 184, 74), Material = Enum.Material.Neon, Transparency = 0.4, CanCollide = false })
	Light(back, Color3.fromRGB(255, 184, 74), 16, 1.5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Return to Town"
	prompt.ObjectText = "Portal"
	prompt.HoldDuration = 0.5
	prompt.RequiresLineOfSight = false
	prompt.Parent = back
	prompt.Triggered:Connect(function(player)
		if runOf[player] == run then
			DungeonService:Leave(player)
		end
	end)
	run.FloorY = origin.Y
end

local function openGate(run, room)
	local gate = room.Gate
	if not gate then
		return
	end
	gate.CanCollide = false
	TweenService:Create(gate, TweenInfo.new(0.8), { Transparency = 1 }):Play()
	task.delay(0.9, function()
		gate:Destroy()
	end)
	room.Gate = nil
	DungeonService.Services.Net.SendEffect(run.Players, "GateOpen", { Position = gate.Position, Color = run.Dungeon.Accent })
end

---------------------------------------------------------------- Lauf-Status an Clients

local function syncRun(run)
	local room = run.Rooms[run.Room]
	local info = {
		Dungeon = run.Dungeon.Index,
		Difficulty = run.Difficulty,
		Level = run.Level,
		Room = math.max(0, run.Room - 1),
		Rooms = #run.Rooms - 1,
		Wave = room and room.Wave or 0,
		Waves = Config.WavesPerRoom,
		Boss = room and room.Boss or false,
		Party = #run.Players,
		Featured = run.Featured == true,
	}
	for _, player in run.Players do
		DungeonService.Services.Net.Sync:FireClient(player, "Run", info)
	end
end

stats = function(run, player: Player)
	local entry = run.Stats[player]
	if not entry then
		entry = { Kills = 0, Gold = 0, XP = 0, Items = 0, Best = nil }
		run.Stats[player] = entry
	end
	return entry
end
DungeonService.Stats = stats

---------------------------------------------------------------- Wellen

local function randomSpot(room, margin: number): Vector3
	local h = room.Half - margin
	return room.Center + Vector3.new(rng:NextNumber(-h, h), 0, rng:NextNumber(-h, h))
end

local function spawnWave(run, room)
	room.Wave += 1
	room.Spawning = true
	local dungeon = run.Dungeon
	local count = Config.WaveSize(room.Order, #run.Players)
	local elite = false
	for i = 1, count do
		if run.State ~= "Running" then
			break
		end
		local key = dungeon.Monsters[rng:NextInteger(1, #dungeon.Monsters)]
		local isElite = not elite and rng:NextNumber() < Config.EliteChance * (1 + room.Order * 0.25)
		if isElite then
			elite = true
			key = dungeon.Elite
		end
		DungeonService.Services.MonsterService:Spawn(run, key, randomSpot(room, 6), { Elite = isElite })
		if i % 3 == 0 then
			task.wait(0.15)
		end
	end
	-- Selten: ein Schatz-Kobold, der mit viel Gold wegrennt
	if run.State == "Running" and not run.ImpSpawned and rng:NextNumber() < Config.ImpChance then
		run.ImpSpawned = true
		DungeonService.Services.MonsterService:Spawn(run, "TreasureImp", randomSpot(room, 8))
		DungeonService.Services.Net.SendEffect(run.Players, "ImpAppear", {})
	end
	room.Spawning = false
	syncRun(run)
end

local function startRoom(run, room)
	room.State = "Active"
	run.Room = room.Index
	if room.Boss then
		local bossKey = run.Dungeon.Boss
		local boss = Config.Bosses[bossKey]
		-- Boss Blessing: offene Segen der Gruppe werden jetzt eingeloest
		local blessed = false
		for _, player in run.Players do
			local data = DungeonService.Services.DataService:Get(player)
			if data and data.Blessing > 0 then
				data.Blessing -= 1
				blessed = true
				DungeonService.Services.DataService:UpdateAttributes(player)
			end
		end
		run.Blessed = blessed
		DungeonService.Services.Net.SendEffect(run.Players, "BossIntro", { Name = boss.Name, Blessed = blessed, Color = boss.Color })
		task.wait(1.6)
		if run.State ~= "Running" then
			return
		end
		room.Wave = 1
		DungeonService.Services.MonsterService:Spawn(run, bossKey, room.Center + Vector3.new(0, 0, room.Half * 0.35), { Boss = true })
		syncRun(run)
	else
		task.spawn(spawnWave, run, room)
	end
end

local function finishRun(run, success: boolean)
	if run.State ~= "Running" then
		return
	end
	run.State = if success then "Complete" else "Failed"
	local services = DungeonService.Services
	local dungeon = run.Dungeon
	local difficulty = Config.Difficulties[run.Difficulty]
	local seconds = math.floor(os.clock() - run.Started)
	local recordKey = dungeon.Id .. "_" .. run.Difficulty
	-- Tote Spieler koennen nach dem Ende nicht mehr wiederbelebt werden
	table.clear(run.Dead)
	for _, player in run.Players do
		local data = services.DataService:Get(player)
		local entry = stats(run, player)
		local firstClear, firstEver, newRecord = false, false, false
		if success and data then
			data.Runs += 1
			firstClear = (data.Cleared[dungeon.Id] or 0) < run.Difficulty
			firstEver = (data.Cleared[dungeon.Id] or 0) == 0
			data.Cleared[dungeon.Id] = math.max(data.Cleared[dungeon.Id] or 0, run.Difficulty)
			if run.Difficulty >= #Config.Difficulties then
				data.NightmareClears += 1
			end
			-- Persoenliche Bestzeit
			local best = data.Records[recordKey]
			if not best or seconds < best then
				newRecord = best ~= nil
				data.Records[recordKey] = seconds
			end
			-- Truhe: Gold + garantiert Rare oder besser, beim ersten Abschluss zusaetzlich Epic oder besser
			local boss = run.Rooms[#run.Rooms]
			local chest = boss.Center + Vector3.new(0, 0, -6)
			local featuredMult = if run.Featured then 1 + Config.FeaturedBonus else 1
			local gold = services.HeroService:GiveGold(player, Config.KillGold(run.Level) * 40 * difficulty.Loot * featuredMult, chest)
			entry.Gold += gold
			services.LootService:DropItem(player, run, { MinRarity = 3, Level = run.Level + 2, Luck = difficulty.Loot }, chest)
			if firstClear then
				services.LootService:DropItem(player, run, { MinRarity = 4, Level = run.Level + 2, Luck = difficulty.Loot }, chest)
				services.Net.SendNotify(player, `First clear of {dungeon.Name} ({difficulty.Name})! Bonus Epic loot!`, GOLD)
			end
			services.LootService:SendInventory(player)
			services.ProgressService:Track(player, "Clear")
		end
		local nextIndex = dungeon.Index + 1
		services.Net.Sync:FireClient(player, "Summary", {
			Success = success,
			Dungeon = dungeon.Name,
			Difficulty = difficulty.Name,
			Kills = entry.Kills,
			Gold = entry.Gold,
			XP = entry.XP,
			Items = entry.Items,
			Best = entry.Best,
			Time = seconds,
			-- Nur beim ersten Abschluss melden, nicht bei jeder Wiederholung
			Unlocked = if firstEver and nextIndex <= #Config.Dungeons then Config.Dungeons[nextIndex].Name else nil,
			NextDifficulty = if firstClear and run.Difficulty < #Config.Difficulties then Config.Difficulties[run.Difficulty + 1].Name else nil,
			NewRecord = newRecord,
			Featured = run.Featured == true,
		})
		services.RewardService:UpdateLeaderboardEntry(player)
	end
	if success then
		local names = {}
		for _, player in run.Players do
			table.insert(names, player.DisplayName)
		end
		services.Net.SendAnnounce(`{table.concat(names, ", ")} defeated {Config.Bosses[dungeon.Boss].Name} on {difficulty.Name}!`, difficulty.Color)
		services.MonetizationService:AfterBoss(run.Players)
	end
	-- Nach 30 Sekunden automatisch zurueck
	task.delay(if success then 30 else 8, function()
		for _, player in table.clone(run.Players) do
			DungeonService:Leave(player)
		end
	end)
end

---------------------------------------------------------------- Kills

function DungeonService:OnMonsterKilled(state, killer: Player?, position: Vector3)
	local run = state.Run
	if run.State ~= "Running" then
		return
	end
	local services = self.Services
	local xpBase = Config.KillXP(state.Level) * (if state.Boss then 25 elseif state.Elite then 3 else 1)
	local goldBase = Config.KillGold(state.Level) * (if state.Boss then 25 elseif state.Elite then 4 elseif state.Treasure then 15 else 1) * rng:NextNumber(0.7, 1.3)
	if state.Minion then
		xpBase *= 0.5
		goldBase *= 0.5
	end
	if run.Featured then
		xpBase *= 1 + Config.FeaturedBonus
		goldBase *= 1 + Config.FeaturedBonus
	end
	for _, player in run.Players do
		local entry = stats(run, player)
		entry.XP += services.HeroService:AddXP(player, xpBase)
		entry.Gold += services.HeroService:GiveGold(player, goldBase, position)
		services.LootService:RollKillDrops(player, run, state, position)
		local data = services.DataService:Get(player)
		if data then
			if state.Boss then
				data.BossKills += 1
			end
			if state.Elite then
				data.EliteKills += 1
			end
			if state.Treasure then
				data.ImpKills += 1
				services.Net.SendNotify(player, "You caught the Treasure Imp!", GOLD)
			end
		end
		-- Quests zaehlen fuer die ganze Gruppe (Koop lohnt sich)
		services.ProgressService:Track(player, "Kill")
		if state.Elite then
			services.ProgressService:Track(player, "EliteKill")
		end
		if state.Boss then
			services.ProgressService:Track(player, "BossKill")
		end
	end
	if killer and killer.Parent then
		stats(run, killer).Kills += 1
		local data = services.DataService:Get(killer)
		if data then
			data.Kills += 1
		end
		services.CombatService:OnKill(killer, state, position)
		services.ProgressService:OnKill(killer, state.Level)
	end
	if state.Boss then
		-- Restliche Diener verschwinden mit dem Boss
		for _, other in services.MonsterService:ForRun(run) do
			services.MonsterService:Kill(other, nil)
		end
	end
end

---------------------------------------------------------------- Lauf starten und verlassen

local function freeSlot(): number?
	for slot = 1, Config.MaxRuns do
		if not slots[slot] then
			return slot
		end
	end
	return nil
end

local function placeInRoom(player: Player, room, offset: number?)
	local character = player.Character
	if character then
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = offset or 4
		character:PivotTo(CFrame.new(room.Center + Vector3.new(math.cos(angle) * r, 4, math.sin(angle) * r)) * CFrame.Angles(0, math.pi, 0))
	end
end

function DungeonService:StartRun(index: number, difficulty: number, members: { Player })
	local slot = freeSlot()
	if not slot then
		for _, player in members do
			self.Services.Net.SendNotify(player, "All dungeons are busy right now. Try again in a moment!", RED)
		end
		return nil
	end
	nextId += 1
	local dungeon = Config.Dungeons[index]
	local d = Config.Difficulties[difficulty]
	local run = {
		Id = nextId,
		Slot = slot,
		Dungeon = dungeon,
		Difficulty = difficulty,
		Level = dungeon.Level + d.LevelBonus,
		Players = {},
		Origin = Vector3.new(1400 + (slot - 1) * 600, 0, 0),
		FloorY = 0,
		Rooms = {},
		Room = 1,
		State = "Running",
		Stats = {},
		Dead = {}, -- [Player] = Frist
		DeathPosition = {}, -- [Player] = Vector3
		Started = os.clock(),
		Featured = index == self.Services.ProgressService:FeaturedIndex(),
		ImpSpawned = false,
	}
	slots[slot] = run
	runs[run.Id] = run
	buildRun(run)
	for _, player in members do
		if player.Parent then
			table.insert(run.Players, player)
			runOf[player] = run
			player:SetAttribute("InRun", true)
			player:SetAttribute("RunDungeon", index)
			stats(run, player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				placeInRoom(player, run.Rooms[1])
			else
				player:LoadCharacter()
			end
		end
	end
	if #run.Players == 0 then
		self:Cleanup(run)
		return nil
	end
	syncRun(run)
	self.Services.Net.SendEffect(run.Players, "RunStart", { Name = dungeon.Name, Difficulty = d.Name, Color = d.Color, Level = run.Level, Featured = run.Featured })
	for _, player in run.Players do
		self.Services.ProgressService:Track(player, "RunStart")
	end
	task.delay(3, function()
		if run.State == "Running" then
			openGate(run, run.Rooms[1])
		end
	end)
	return run
end

function DungeonService:Cleanup(run)
	run.State = if run.State == "Running" then "Abandoned" else run.State
	self.Services.MonsterService:ClearRun(run)
	if run.Folder then
		run.Folder:Destroy()
	end
	slots[run.Slot] = nil
	runs[run.Id] = nil
end

-- quitting = Spieler verlaesst das Spiel: keine Teleports, kein LoadCharacter, keine Remotes mehr
function DungeonService:Leave(player: Player, quitting: boolean?)
	local run = runOf[player]
	if not run then
		return
	end
	runOf[player] = nil
	local index = table.find(run.Players, player)
	if index then
		table.remove(run.Players, index)
	end
	run.Dead[player] = nil
	run.DeathPosition[player] = nil
	if player.Parent and not quitting then
		player:SetAttribute("InRun", false)
		player:SetAttribute("RunDungeon", nil)
		self.Services.Net.Sync:FireClient(player, "Run", nil)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			(player.Character :: Model):PivotTo(CFrame.new(self.Services.WorldService.SpawnPosition + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))))
		else
			player:LoadCharacter()
		end
	end
	if #run.Players == 0 then
		self:Cleanup(run)
	else
		syncRun(run)
	end
end

-- Wohin ein Spieler beim (Wieder-)Erscheinen gehoert
function DungeonService:OnCharacterAdded(player: Player, character: Model)
	local run = runOf[player]
	if not run then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not root then
		return
	end
	task.wait()
	local revive = run.DeathPosition[player]
	if revive and run.ReviveHere and run.ReviveHere[player] then
		run.ReviveHere[player] = nil
		character:PivotTo(CFrame.new(revive + Vector3.new(0, 4, 0)))
	else
		-- Letzter geschaffter Raum = Kontrollpunkt
		local checkpoint = run.Rooms[1]
		for _, room in run.Rooms do
			if room.State == "Cleared" then
				checkpoint = room
			end
		end
		placeInRoom(player, checkpoint, 5)
	end
	run.DeathPosition[player] = nil
end

function DungeonService:OnPlayerDied(player: Player, position: Vector3)
	local run = runOf[player]
	if not run or run.State ~= "Running" then
		return
	end
	run.Dead[player] = os.clock() + Config.ReviveSeconds
	run.DeathPosition[player] = position
	local anyAlive = #self.Services.MonsterService.AlivePlayers(run) > 0
	self.Services.Net.Sync:FireClient(player, "Death", { Seconds = Config.ReviveSeconds, Party = anyAlive })
end

function DungeonService:ExtendDeath(player: Player, seconds: number)
	local run = runOf[player]
	if run and run.Dead[player] then
		run.Dead[player] = math.max(run.Dead[player], os.clock() + seconds)
	end
end

-- Nach Kauf oder Werbung: an Ort und Stelle mit vollem Leben weiter
function DungeonService:Revive(player: Player): boolean
	local run = runOf[player]
	if not run or run.State ~= "Running" or not run.Dead[player] then
		return false
	end
	run.Dead[player] = nil
	run.ReviveHere = run.ReviveHere or {}
	run.ReviveHere[player] = true
	player:LoadCharacter()
	self.Services.Net.SendEffect(run.Players, "Revive", { Name = player.DisplayName })
	return true
end

---------------------------------------------------------------- Lobby

local function syncLobby(index: number)
	local lobby = lobbies[index]
	if not lobby then
		return
	end
	local featuredIndex = DungeonService.Services.ProgressService:FeaturedIndex()
	for i, player in lobby.Players do
		local data = DungeonService.Services.DataService:Get(player)
		local best = data and data.Records[Config.Dungeons[index].Id .. "_" .. lobby.Difficulty]
		DungeonService.Services.Net.Sync:FireClient(player, "Lobby", {
			Dungeon = index,
			Count = #lobby.Players,
			Max = Config.MaxPartySize,
			Difficulty = lobby.Difficulty,
			MaxDifficulty = DungeonService:MaxDifficulty(player, index),
			Seconds = math.max(0, lobby.StartsAt - os.clock()),
			Leader = i == 1,
			Best = best,
			Featured = index == featuredIndex,
		})
	end
end

local function leaveLobby(player: Player, quitting: boolean?)
	local index = lobbyOf[player]
	if not index then
		return
	end
	lobbyOf[player] = nil
	local lobby = lobbies[index]
	if lobby then
		local i = table.find(lobby.Players, player)
		if i then
			table.remove(lobby.Players, i)
		end
		if #lobby.Players == 0 then
			lobbies[index] = nil
		else
			lobby.Difficulty = math.min(lobby.Difficulty, DungeonService:MaxDifficulty(lobby.Players[1], index))
			syncLobby(index)
		end
	end
	if player.Parent and not quitting then
		DungeonService.Services.Net.Sync:FireClient(player, "Lobby", nil)
	end
end

local function joinLobby(player: Player, index: number): boolean
	local lobby = lobbies[index]
	if lobby and #lobby.Players >= Config.MaxPartySize then
		return false
	end
	if not lobby then
		lobby = { Players = {}, Difficulty = 1, StartsAt = os.clock() + Config.LobbyCountdown }
		lobbies[index] = lobby
	end
	table.insert(lobby.Players, player)
	lobbyOf[player] = index
	if #lobby.Players == 1 then
		lobby.Difficulty = 1
	end
	syncLobby(index)
	return true
end

local function updateLobbies()
	local portals = DungeonService.Services.WorldService.Portals
	for _, player in Players:GetPlayers() do
		if runOf[player] then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			leaveLobby(player)
			continue
		end
		local current = lobbyOf[player]
		if current then
			local pad = portals[current]
			if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pad.Position.X, 0, pad.Position.Z)).Magnitude > 10 then
				leaveLobby(player)
			end
		else
			for index, pad in portals do
				if (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(pad.Position.X, 0, pad.Position.Z)).Magnitude <= 6.5 then
					if DungeonService:IsUnlocked(player, index) then
						if not joinLobby(player, index) and os.clock() - (lockedNotice[player] or 0) > 4 then
							lockedNotice[player] = os.clock()
							DungeonService.Services.Net.SendNotify(player, "This party is full (4/4). Wait for the next group!", RED)
						end
					elseif os.clock() - (lockedNotice[player] or 0) > 4 then
						lockedNotice[player] = os.clock()
						DungeonService.Services.Net.SendNotify(player, `Locked! Defeat the boss of {Config.Dungeons[index - 1].Name} first.`, RED)
					end
					break
				end
			end
		end
	end
	for index, lobby in lobbies do
		if os.clock() >= lobby.StartsAt then
			local members = {}
			for i = 1, math.min(#lobby.Players, Config.MaxPartySize) do
				table.insert(members, lobby.Players[i])
			end
			local difficulty = lobby.Difficulty
			for _, player in members do
				lobbyOf[player] = nil
				DungeonService.Services.Net.Sync:FireClient(player, "Lobby", nil)
			end
			lobbies[index] = nil
			task.spawn(DungeonService.StartRun, DungeonService, index, difficulty, members)
		end
	end
end

---------------------------------------------------------------- Lauf-Schleife

local function inside(room, position: Vector3): boolean
	local d = position - room.Center
	return math.abs(d.X) < room.Half - 1 and math.abs(d.Z) < room.Half - 1
end

local function updateRun(run)
	if run.State ~= "Running" then
		return
	end
	local services = DungeonService.Services
	local alive = services.MonsterService.AlivePlayers(run)
	-- Tote Spieler: nach Ablauf der Frist am Kontrollpunkt erscheinen oder Lauf verloren
	local now = os.clock()
	for player, deadline in run.Dead do
		if now >= deadline then
			if #alive > 0 then
				run.Dead[player] = nil
				player:LoadCharacter()
			end
		end
	end
	if #alive == 0 then
		local waiting = false
		for _, deadline in run.Dead do
			if now < deadline then
				waiting = true
			end
		end
		if not waiting and next(run.Dead) ~= nil then
			finishRun(run, false)
			return
		end
	end

	local room = run.Rooms[run.Room]
	if room.State == "Active" then
		if not room.Spawning and room.Wave > 0 and services.MonsterService:CountAlive(run) == 0 then
			if room.Boss then
				room.State = "Cleared"
				finishRun(run, true)
				return
			elseif room.Wave < Config.WavesPerRoom then
				room.Spawning = true
				task.delay(1.2, spawnWave, run, room)
			else
				room.State = "Cleared"
				openGate(run, room)
				services.Net.SendEffect(run.Players, "RoomClear", { Room = room.Order, Rooms = #run.Rooms - 2 })
				syncRun(run)
			end
		end
	elseif room.State == "Cleared" then
		local nextRoom = run.Rooms[run.Room + 1]
		if nextRoom and nextRoom.State == "Idle" then
			for _, entry in alive do
				if inside(nextRoom, entry.Root.Position) then
					task.spawn(startRoom, run, nextRoom)
					run.Room = nextRoom.Index
					nextRoom.State = "Active"
					break
				end
			end
		end
	end
end

---------------------------------------------------------------- Start

function DungeonService:Start()
	local Net = self.Services.Net
	Net.Handle("SetDifficulty", function(player, difficulty)
		local index = lobbyOf[player]
		local lobby = index and lobbies[index]
		if not lobby or lobby.Players[1] ~= player or typeof(difficulty) ~= "number" or difficulty ~= difficulty then
			return false
		end
		difficulty = math.floor(difficulty)
		if difficulty < 1 or difficulty > self:MaxDifficulty(player, index) then
			return false
		end
		lobby.Difficulty = difficulty
		syncLobby(index)
		return true
	end)
	Net.Handle("StartNow", function(player)
		local index = lobbyOf[player]
		local lobby = index and lobbies[index]
		if lobby and lobby.Players[1] == player then
			lobby.StartsAt = os.clock()
			return true
		end
		return false
	end)
	Net.Handle("LeaveRun", function(player)
		self:Leave(player)
		return true
	end)
	Net.Handle("Respawn", function(player)
		-- Tod: sofort zum Kontrollpunkt (wenn die Gruppe noch lebt) oder in die Stadt
		local run = runOf[player]
		if not run or not run.Dead[player] then
			return false
		end
		if #self.Services.MonsterService.AlivePlayers(run) > 0 then
			run.Dead[player] = nil
			player:LoadCharacter()
		else
			self:Leave(player)
		end
		return true
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(updateLobbies)
			if not ok then
				warn("[Dungeon] Lobby", err)
			end
			for _, run in runs do
				local okRun, errRun = pcall(updateRun, run)
				if not okRun then
					warn("[Dungeon] Lauf", errRun)
				end
			end
		end
	end)
	-- Lobby-Countdown jede Sekunde an die Wartenden
	task.spawn(function()
		while true do
			task.wait(1)
			for index in lobbies do
				syncLobby(index)
			end
		end
	end)
end

function DungeonService:OnPlayerRemoving(player: Player)
	leaveLobby(player, true)
	self:Leave(player, true)
	lockedNotice[player] = nil
end

return DungeonService
