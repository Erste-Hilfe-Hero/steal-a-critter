-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft (vor dem Veroeffentlichen).
-- Server-Scripts starten dort nicht automatisch, deshalb startet dieser Test die Services selbst
-- und spielt zwei Runden nur mit Bots durch (ohne Physik, deshalb werden Positionen direkt gesetzt).
-- Jeder Laufzeitfehler (auch in Schleifen) wird ueber LogService eingesammelt und zaehlt als Fehler.
local CollectionService = game:GetService("CollectionService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local results = {}
local failed = 0
local function check(name, ok, detail)
	if not ok then
		failed += 1
	end
	table.insert(results, (if ok then "PASS " else "FAIL ") .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
end
local function info(text)
	table.insert(results, "INFO " .. text)
end
local errors = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and #errors < 8 then
		table.insert(errors, (string.gsub(message, "\n", " | ")))
	end
end)

local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)

---------------------------------------------------------------- Konfiguration

for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end
for _, crate in Config.Crates do
	local sum = 0
	for _, entry in Config.CrateOdds(crate.Id) do
		sum += entry.Chance
	end
	check("odds sum " .. crate.Id, math.abs(sum - 1) < 0.001, sum)
end
local bpOk = true
for _, track in { "Free", "Premium" } do
	for tier, reward in Config.BattlePass[track] do
		if reward.Item and not Config.GetItem(reward.Item[1], reward.Item[2]) then
			bpOk = false
			info(`missing BP item {track} {tier}`)
		end
	end
end
check("battle pass items exist", bpOk)
-- Update: Mystery Box mischt alle Arten, neue Karte und Modifikatoren vorhanden
local mixedKinds = {}
for _, entry in Config.CrateOdds("MysteryCrate") do
	mixedKinds[entry.Kind] = true
end
check("mystery box has all kinds", mixedKinds.Knife and mixedKinds.Gun and mixedKinds.Pet and mixedKinds.Effect)
local hasMuseum = false
for _, def in Config.Maps do
	hasMuseum = hasMuseum or def.Id == "Museum"
end
check("museum map listed", hasMuseum)
for _, a in Config.Achievements do
	if a.Stat ~= "Level" and a.Stat ~= "Prestige" then
		local dataKeys = { "Wins", "KOs", "Stops", "HeroStops", "Survived", "CoinsCollected", "Forged", "Hides", "CluesFound", "BestStreak", "LastSurvivor", "GhostGuesses", "MVPs", "CratesOpened" }
		check("achievement stat " .. a.Id, table.find(dataKeys, a.Stat) ~= nil, a.Stat)
	end
end
for _, product in Config.DevProducts do
	for _, entry in product.Items or {} do
		check("bundle item " .. entry[2], Config.GetItem(entry[1], entry[2]) ~= nil)
	end
end

-- Alle Skins bauen
local built = 0
for _, kind in { "Knife", "Gun", "Pet" } do
	for _, item in Config.ItemLists[kind] do
		local ok, model = pcall(Skins[kind], item.Id)
		if ok and model.PrimaryPart then
			built += 1
			model:Destroy()
		else
			check("build " .. kind .. " " .. item.Id, false, model)
		end
	end
end
info(`built {built} skins`)
local okTool, tool = pcall(Skins.Tool, "Knife", "Galaxy")
check("knife tool has handle", okTool and tool:FindFirstChild("Handle") ~= nil, if okTool then nil else tool)

---------------------------------------------------------------- Services

local folder = ServerScriptService:WaitForChild("Server")
local services = {}
local ORDER = { "DataService", "ProgressService", "InventoryService", "MapService", "CoinService", "ClueService", "CombatService", "AbilityService", "BotService", "RoundService", "MonetizationService" }
local ok, err = pcall(function()
	services.Net = require(folder.Services.Net)
	for _, name in ORDER do
		services[name] = require(folder.Services[name])
	end
	for _, name in ORDER do
		services[name]:Init(services)
	end
	services.MapService:Build()
	for _, name in { "MapService", "CoinService", "CombatService", "BotService" } do
		services[name]:Start()
	end
end)
check("init services + lobby", ok, err)
local lobby = workspace:FindFirstChild("Lobby")
check("lobby spawn", lobby ~= nil and lobby:FindFirstChild("LobbySpawn") ~= nil)
check("lobby booths", #CollectionService:GetTagged("Booth") == 4, #CollectionService:GetTagged("Booth"))

-- Woechentliche Quests und Midnight Hour
local fakeData = { WeeklyQuests = { Week = 0, List = {} } }
services.ProgressService.RollWeekly(fakeData)
check("weekly quests rolled", #fakeData.WeeklyQuests.List == Config.WeeklyQuestsPerWeek, #fakeData.WeeklyQuests.List)
local okEvent, eventErr = pcall(function()
	services.RoundService:BoostEvent(1)
end)
check("midnight hour boost", okEvent and services.RoundService:EventActive() and services.RoundService:EventCoinMultiplier() == Config.MidnightHour.Coins, eventErr)

-- Jede Karte bauen
local MapBuilder = require(folder.Services.MapBuilder)
for i, def in Config.Maps do
	local okMap, map = pcall(MapBuilder.Build, def, Config.MapOrigin + Vector3.new(0, 0, 400 * i), i)
	check("build map " .. def.Id, okMap, if okMap then nil else map)
	if okMap then
		local closets, vents, doors = 0, 0, 0
		for _, c in CollectionService:GetTagged("Closet") do
			if c:IsDescendantOf(map.Model) then
				closets += 1
			end
		end
		for _, v in CollectionService:GetTagged("Vent") do
			if v:IsDescendantOf(map.Model) then
				vents += 1
			end
		end
		for _, d in CollectionService:GetTagged("Door") do
			if d:IsDescendantOf(map.Model) then
				doors += 1
			end
		end
		info(`{def.Id}: {#map.Spawns} spawns, {#map.CoinSpots} coin spots, {closets} closets, {vents} vents, {doors} doors, {#map.Model:GetDescendants()} parts`)
		check(def.Id .. " has closets", closets >= 3, closets)
		check(def.Id .. " has 4 vents", vents == 4, vents)
		map.Model:Destroy()
	end
end

---------------------------------------------------------------- Runde 1: Innocents gewinnen

local round = services.RoundService
round.Testing = true
-- Runde 1 und 2 sind gestellte Szenen: Bots duerfen dabei nicht selbst laufen oder schiessen
services.BotService.Paused = true
local started, startErr = pcall(round.StartRound, round)
check("start round with bots", started and round.State == "Reveal", if started then round.State else startErr)

local function byRole(role: string)
	local list = {}
	for _, actor in round.Actors do
		if actor.Role == role and actor.Alive then
			table.insert(list, actor)
		end
	end
	return list
end

if started and round.State == "Reveal" then
	local count = 0
	for _ in round.Actors do
		count += 1
	end
	check("5 actors", count == Config.Round.MinActors, count)
	check("1 murderer", #byRole("Murderer") == 1, #byRole("Murderer"))
	check("1 sheriff", #byRole("Sheriff") == 1, #byRole("Sheriff"))
	check("alive list published", ReplicatedStorage:GetAttribute("AliveCount") == count, ReplicatedStorage:GetAttribute("AliveCount"))

	local okPlay, playErr = pcall(round.BeginPlay, round)
	check("begin play", okPlay and round.State == "Playing", if okPlay then round.State else playErr)
	task.wait(1)
	check("coins spawned", services.CoinService:Count() > 0, services.CoinService:Count())

	local murderer = byRole("Murderer")[1]
	local sheriff = byRole("Sheriff")[1]
	local innocents = byRole("Innocent")
	check("murderer armed", murderer.Bot.Weapon ~= nil and murderer.Model:FindFirstChild("BotWeapon") ~= nil)
	check("sheriff armed", sheriff.Bot.Weapon ~= nil)

	-- Muenze einsammeln
	local coin = services.CoinService:Nearest(innocents[1].Root.Position)
	if coin then
		services.CoinService:Collect(innocents[1], coin)
	end
	check("collect coin", innocents[1].Coins == 1, innocents[1].Coins)

	-- Faehigkeiten
	local usedTrap = services.AbilityService:Use(murderer, "Trap")
	check("murderer trap", usedTrap == true)
	local usedScan = services.AbilityService:Use(sheriff, "Scan")
	check("sheriff scan", usedScan == true)
	check("innocent cannot dash", services.AbilityService:Use(innocents[1], "Dash") == false)
	services.AbilityService:SpawnPowerUp()
	check("power-up spawned", #workspace.PowerUps:GetChildren() >= 1, #workspace.PowerUps:GetChildren())

	-- Hinweis: Lupe erscheinen lassen und aufheben (der Murderer darf nicht)
	local clue
	for _ = 1, 10 do
		clue = services.ClueService:SpawnOne(round.Map)
		if clue then
			break
		end
	end
	check("clue spawned", clue ~= nil)
	if clue then
		check("murderer cannot take clue", services.ClueService:Pickup(clue, murderer) == false)
		check("innocent takes clue", services.ClueService:Pickup(clue, innocents[1]) == true and clue.Parent == nil)
		check("clue counted", services.ClueService:Found(innocents[1]) == 1)
	end
	local hint = services.ClueService:HintFor(innocents[1], 3)
	check("clue hint names letter", typeof(hint) == "string" and hint:find("starts with") ~= nil, hint)

	-- Verstecken und durchsuchen
	local closet
	for _, c in CollectionService:GetTagged("Closet") do
		if c:IsDescendantOf(round.Map.Model) then
			closet = c
			break
		end
	end
	local hider = innocents[2]
	services.MapService:UseCloset(hider, closet)
	check("innocent hides", hider.Hidden == true)
	services.MapService:UseCloset(murderer, closet)
	check("murderer finds hider", hider.Hidden == false)

	-- Lueftungsschacht
	local vent
	for _, v in CollectionService:GetTagged("Vent") do
		if v:IsDescendantOf(round.Map.Model) then
			vent = v
			break
		end
	end
	local before = murderer.Root.Position
	services.MapService:UseVent(murderer, vent)
	check("vent teleports", (murderer.Root.Position - before).Magnitude > 20, (murderer.Root.Position - before).Magnitude)
	services.MapService:UseVent(sheriff, vent)

	-- Tuer
	local door
	for _, d in CollectionService:GetTagged("Door") do
		if d:IsDescendantOf(round.Map.Model) then
			door = d
			break
		end
	end
	if door then
		services.MapService:SlamDoor(door, nil)
		check("door slams", door.CanCollide == true)
	end

	-- Messer: Opfer direkt vor den Murderer stellen
	local spot = round.Map.Spawns[1]
	-- Unbeteiligte weit weg stellen, sonst trifft Stich oder Schuss zufaellig einen Bot, der am selben Spawn steht
	local function park(...)
		local keep = { ... }
		for i, actor in round.Actors do
			if actor.Alive and not table.find(keep, actor) then
				actor.Model:PivotTo(CFrame.new(spot.Position + Vector3.new(80 + i * 15, 3, 80)))
			end
		end
	end
	park(murderer, innocents[3])
	murderer.Model:PivotTo(spot + Vector3.new(0, 3, 0))
	local victim = innocents[3]
	victim.Model:PivotTo(murderer.Root.CFrame * CFrame.new(0, 0, -3))
	task.wait(0.1)
	check("stab knocks out", services.CombatService:Stab(murderer) == true and victim.Alive == false, victim.Alive)

	-- Sheriff trifft einen Unschuldigen: beide raus, Blaster faellt
	local wrong = innocents[1]
	park(sheriff, wrong)
	sheriff.Model:PivotTo(spot * CFrame.new(10, 11, 0))
	wrong.Model:PivotTo(sheriff.Root.CFrame * CFrame.new(0, 0, -6))
	task.wait(0.1)
	services.CombatService:Shoot(sheriff, wrong.Root.Position)
	check("innocent hit", wrong.Alive == false)
	check("sheriff out after mistake", sheriff.Alive == false)
	check("blaster dropped", services.CombatService:GetDroppedGun() ~= nil)
	-- Duo-Modus: ein zweiter fallengelassener Blaster loescht den ersten nicht mehr
	services.CombatService:DropGun(spot.Position + Vector3.new(0, 0, 20))
	check("two blasters can lie", #CollectionService:GetTagged("DroppedGun") == 2, #CollectionService:GetTagged("DroppedGun"))
	check("last survivor announced", round:GetLastSurvivor() == innocents[2], if round:GetLastSurvivor() then round:GetLastSurvivor().Name else "none")

	-- Letzter Unschuldiger hebt auf und wird Hero
	task.wait(Config.Gun.DropPickupDelay + 0.2)
	local hero = innocents[2]
	services.CombatService:TryPickup(hero)
	check("hero picks up blaster", hero.Role == "Hero" and hero.Bot.Weapon ~= nil, hero.Role)

	-- Hero stoppt den Murderer
	park(hero, murderer)
	hero.Model:PivotTo(spot * CFrame.new(-10, 11, 0))
	murderer.Model:PivotTo(hero.Root.CFrame * CFrame.new(0, 0, -8))
	murderer.Hidden = false
	task.wait(0.1)
	services.CombatService:Shoot(hero, murderer.Root.Position)
	check("hero stops murderer", murderer.Alive == false)
	check("innocents win", round.Winner == "Innocents" and round.State == "Results", round.Winner)

	local okClean, cleanErr = pcall(round.Cleanup, round)
	check("cleanup", okClean and round.Map == nil, cleanErr)
	check("map removed", workspace:FindFirstChild("Map_" .. round.MapDef.Id) == nil)
end

---------------------------------------------------------------- Runde 2: Murderer gewinnt

task.wait(1.2)
round.ForceModifier = "SuperJump"
local started2 = pcall(round.StartRound, round)
if started2 and round.State == "Reveal" then
	round:BeginPlay()
	local murderer = byRole("Murderer")[1]
	check("super jump modifier", round.Modifier ~= nil and round.Modifier.Id == "SuperJump" and murderer.Humanoid.JumpHeight > 20, if round.Modifier then round.Modifier.Id else "none")
	local spot = round.Map.Spawns[1]
	-- Ein Stich trifft den Naechsten, das kann auch ein anderer Bot am Spawn sein: so lange stechen, bis alle raus sind
	for _ = 1, 12 do
		local target
		for _, actor in round.Actors do
			if actor ~= murderer and actor.Alive then
				target = actor
				break
			end
		end
		if not target or round.State ~= "Playing" then
			break
		end
		murderer.Model:PivotTo(spot + Vector3.new(0, 3, 0))
		target.Model:PivotTo(murderer.Root.CFrame * CFrame.new(0, 0, -2.5))
		task.wait(Config.Knife.Cooldown + 0.05)
		services.CombatService:Stab(murderer)
	end
	check("murderer wins", round.Winner == "Murderer", `{round.Winner} {round.State}`)
	pcall(round.Cleanup, round)
else
	check("start round 2", false)
end

-- Bots laufen eine Weile ohne Fehler (Denk-Schleife, Pathfinding)
services.BotService.Paused = false
local started3 = pcall(round.StartRound, round)
if started3 and round.State == "Reveal" then
	round:BeginPlay()
	task.wait(6)
	check("round 3 still running", round.State == "Playing" or round.State == "Results", round.State)
	pcall(round.Cleanup, round)
end

check("no runtime errors", #errors == 0, table.concat(errors, " || "))

table.insert(results, 1, `SUMMARY: {failed} failed, {#results} checks`)
return table.concat(results, "\n")
