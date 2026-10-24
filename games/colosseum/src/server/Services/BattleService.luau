-- Rundenkampf wie im Klassiker: Typtabelle, AP, Statusprobleme, Werte-Stufen, Prioritaet,
-- Volltreffer, EP fuer das Team nach jedem K.O., Fangen, Wechseln und Gegenstaende.
-- Kampfarten: Wild, Legend, Trainer (Route, Arena, Rivale, Team Eclipse, Top Vier), Gauntlet, Duel.
-- Der Server entscheidet alles; die Clients bekommen pro Runde eine Liste von Ereignissen zum Abspielen.
-- In Texten steht "@1"/"@2" fuer die aktive Bestie der Seite (der Client setzt "Wild"/"Foe" davor).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Beasts = require(ReplicatedStorage.Shared.Beasts)
local BeastModel = require(ReplicatedStorage.Shared.BeastModel)
local Format = require(ReplicatedStorage.Shared.Format)

local BattleService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(110, 230, 130)

local STAT_NAMES = { Atk = "Attack", Def = "Defense", Spd = "Speed" }
-- Elemente, die gegen bestimmte Statusprobleme immun sind
local STATUS_IMMUNE = { Burn = "Fire", Para = "Spark", Freeze = "Frost", Poison = "Shadow" }

local battles = {} -- [Id] = Battle
local byPlayer = {} -- [Player] = Battle
local nextId = 0
local gauntletPending = {} -- [Player] = { Wave, Expires }
local autoBattle = {} -- [Player] = true, wenn Auto Battle eingeschaltet ist

local folder = Instance.new("Folder")
folder.Name = "Battles"
folder.Parent = workspace

local random = Random.new()

function BattleService:Init(services)
	self.Services = services
end

function BattleService:InBattle(player: Player): boolean
	return byPlayer[player] ~= nil
end

---------------------------------------------------------------- Kaempfer

local function refreshStats(fighter)
	local stats = Config.Stats(fighter.Id, fighter.Level, fighter.Shiny)
	fighter.MaxHp = stats.MaxHp
	fighter.Atk = stats.Atk
	fighter.Def = stats.Def
	fighter.Spd = stats.Spd
	fighter.Hp = math.clamp(fighter.Hp, 0, stats.MaxHp)
end

-- moves/pp duerfen die Tabellen des Speicherstands sein (AP-Verbrauch bleibt dann erhalten)
local function makeFighter(beastId: string, level: number, shiny: boolean?, hp: number?, uid: string?, moves: { string }?, pp: { number }?, status: string?)
	local list = moves or Beasts.DefaultMoves(beastId, level)
	local ppList = pp
	if not ppList then
		ppList = {}
		for i, key in list do
			ppList[i] = Config.Moves[key].PP
		end
	end
	local fighter = {
		Id = beastId,
		Level = level,
		Shiny = shiny == true,
		Hp = hp or math.huge,
		Uid = uid,
		Moves = list,
		PP = ppList,
		Status = status,
		Sleep = if status == "Sleep" then random:NextInteger(1, 3) else 0,
		Stages = { Atk = 0, Def = 0, Spd = 0 },
	}
	refreshStats(fighter)
	return fighter
end

local function summary(fighter)
	local entry = fighter.Entry
	return {
		Id = fighter.Id,
		Level = fighter.Level,
		Shiny = fighter.Shiny,
		Hp = fighter.Hp,
		MaxHp = fighter.MaxHp,
		Uid = fighter.Uid,
		Status = fighter.Status,
		X = if entry then entry.X else nil,
		Need = if entry then Config.XpToNext(fighter.Level) else nil,
	}
end

local function active(side)
	return side.Fighters[side.Active]
end

local function nextHealthy(side): number?
	for index, fighter in side.Fighters do
		if fighter.Hp > 0 then
			return index
		end
	end
	return nil
end

local function movesInfo(fighter, target)
	local list = {}
	for i, key in fighter.Moves do
		local move = Config.Moves[key]
		if move then
			table.insert(list, {
				Slot = i,
				Key = key,
				Name = move.Name,
				Type = move.Type,
				Power = move.Power,
				Acc = move.Acc,
				PP = fighter.PP[i] or 0,
				MaxPP = move.PP,
				Eff = if target and move.Power > 0 then Beasts.Effectiveness(move.Type, target.Id) else nil,
			})
		end
	end
	return list
end

local function hasType(fighter, typeName: string): boolean
	local def = Config.BeastsById[fighter.Id]
	return def.Type == typeName or def.Type2 == typeName
end

local function speedOf(fighter): number
	return fighter.Spd * Beasts.StageMultiplier(fighter.Stages.Spd) * (if fighter.Status == "Para" then 0.5 else 1)
end

local function name(sideIndex: number): string
	return "@" .. sideIndex
end

---------------------------------------------------------------- Schaden und Effekte

-- Schaden einer Attacke (ohne Genauigkeit). Gibt Schaden, Wirkung, Volltreffer zurueck.
local function computeDamage(attacker, defender, moveKey: string)
	local move = Config.Moves[moveKey]
	local effect = Beasts.Effectiveness(move.Type, defender.Id)
	if effect == 0 then
		return 0, 0, false
	end
	local crit = random:NextNumber() < (if move.HighCrit then Config.HighCritChance else Config.CritChance)
	local atkStage = attacker.Stages.Atk
	local defStage = defender.Stages.Def
	if crit then
		-- Volltreffer ignorieren schlechte eigene und gute gegnerische Stufen
		atkStage = math.max(0, atkStage)
		defStage = math.min(0, defStage)
	end
	local attack = attacker.Atk * Beasts.StageMultiplier(atkStage) * (if attacker.Status == "Burn" then 0.5 else 1)
	local defense = math.max(1, defender.Def * Beasts.StageMultiplier(defStage))
	local base = math.floor(math.floor(math.floor(2 * attacker.Level / 5 + 2) * move.Power * attack / defense) / 50) + 2
	local stab = if hasType(attacker, move.Type) then Config.StabMultiplier else 1
	local damage = base * stab * effect * (if crit then Config.CritMultiplier else 1) * random:NextNumber(0.85, 1)
	return math.max(1, math.floor(damage)), effect, crit
end

local function tryStatus(battle, targetIndex: number, status: string, events, announceFail: boolean)
	local target = active(battle.Sides[targetIndex])
	if target.Hp <= 0 then
		return false
	end
	local immuneType = STATUS_IMMUNE[status]
	if target.Status or (immuneType and hasType(target, immuneType)) then
		if announceFail then
			table.insert(events, { T = "Msg", Text = if target.Status == status then `{name(targetIndex)} is already {Config.Statuses[status].Name}!` else "But it failed!" })
		end
		return false
	end
	target.Status = status
	if status == "Sleep" then
		target.Sleep = random:NextInteger(1, 3)
	end
	table.insert(events, { T = "Status", Side = targetIndex, Status = status, Text = `{name(targetIndex)} {Config.Statuses[status].Text}!` })
	return true
end

local function changeStage(battle, targetIndex: number, stat: string, stages: number, events)
	local target = active(battle.Sides[targetIndex])
	local before = target.Stages[stat]
	local after = math.clamp(before + stages, -6, 6)
	if after == before then
		table.insert(events, { T = "Msg", Text = `{name(targetIndex)}'s {STAT_NAMES[stat]} won't go any {if stages > 0 then "higher" else "lower"}!` })
		return
	end
	target.Stages[stat] = after
	local word = if stages >= 2 then "rose sharply" elseif stages > 0 then "rose" elseif stages <= -2 then "harshly fell" else "fell"
	table.insert(events, { T = "Stat", Side = targetIndex, Stat = stat, Up = stages > 0, Text = `{name(targetIndex)}'s {STAT_NAMES[stat]} {word}!` })
end

---------------------------------------------------------------- Computer-Gegner

-- Bewertung einer Attacke fuer den Computer (und Auto Battle)
local function scoreMove(attacker, defender, slot: number, smart: boolean): number
	local key = attacker.Moves[slot]
	local move = key and Config.Moves[key]
	if not move or (attacker.PP[slot] or 0) <= 0 then
		return -1
	end
	local effect = move.Effect
	if move.Power > 0 then
		local eff = Beasts.Effectiveness(move.Type, defender.Id)
		local stab = if hasType(attacker, move.Type) then 1.5 else 1
		local score = move.Power * (move.Acc or 1) * eff * stab
		if not smart then
			score = move.Power * (move.Acc or 1) * (0.6 + eff * 0.4)
		end
		-- Prioritaets-Attacke, um einen fast besiegten Gegner zu erledigen
		if move.Priority > 0 and defender.Hp < defender.MaxHp * 0.2 then
			score *= 1.6
		end
		return score
	end
	if not effect then
		return 5
	end
	if effect.Heal then
		return if attacker.Hp < attacker.MaxHp * 0.4 then 160 else 0
	elseif effect.Status then
		local immune = STATUS_IMMUNE[effect.Status]
		if defender.Status or (immune and hasType(defender, immune)) then
			return 0
		end
		return if smart then 75 else 40
	elseif effect.Stat then
		local target = if effect.Self then attacker else defender
		local stage = target.Stages[effect.Stat]
		if (effect.Stages > 0 and stage >= 2) or (effect.Stages < 0 and stage <= -2) then
			return 0
		end
		return if attacker.Hp > attacker.MaxHp * 0.6 then (if smart then 55 else 35) else 10
	end
	return 5
end

-- Bester Platz (Index in Moves) oder 0 fuer Struggle
local function bestMove(attacker, defender, randomness: number, smart: boolean?): number
	local bestSlot, bestScore = 0, 0
	for slot in attacker.Moves do
		local score = scoreMove(attacker, defender, slot, smart == true)
		if score > 0 then
			score *= 1 + random:NextNumber() * randomness
			if score > bestScore then
				bestSlot, bestScore = slot, score
			end
		end
	end
	return bestSlot
end

local function aiAction(battle, sideIndex: number)
	local side = battle.Sides[sideIndex]
	local fighter = active(side)
	local foe = active(battle.Sides[3 - sideIndex])
	-- Arenaleiter und Top Vier heilen sich einmal, wenn es eng wird
	if (side.Potions or 0) > 0 and fighter.Hp < fighter.MaxHp * 0.25 and fighter.Hp > 0 and random:NextNumber() < 0.7 then
		return { Kind = "AiPotion" }
	end
	return { Kind = "Move", Slot = bestMove(fighter, foe, if side.Smart then 0.15 else 0.7, side.Smart) }
end

---------------------------------------------------------------- Modelle und Positionen

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(position: Vector3): Vector3
	local exclude = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local npcs = workspace:FindFirstChild("Npcs")
	if npcs then
		table.insert(exclude, npcs)
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -60, 0), rayParams)
	return if hit then hit.Position else Vector3.new(position.X, 0, position.Z)
end

local function groundCFrame(position: Vector3, lookAt: Vector3): CFrame
	local ground = groundAt(position)
	local target = Vector3.new(lookAt.X, ground.Y, lookAt.Z)
	if (target - ground).Magnitude < 0.1 then
		target = ground + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(ground, target)
end

local function spawnModel(battle, side, sideIndex: number)
	if side.Model then
		side.Model:Destroy()
	end
	local fighter = active(side)
	local model = BeastModel.Build(fighter.Id, fighter.Level, fighter.Shiny)
	local scale = BeastModel.Scale(fighter.Id, fighter.Level)
	model:PivotTo(side.Anchor * CFrame.new(0, BeastModel.Hover(fighter.Id, scale), 0))
	model.Name = "Side" .. sideIndex
	model.Parent = battle.Folder
	side.Model = model
	return model
end

local function freeze(player: Player, frozen: boolean)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = frozen
	end
end

local function rootOf(player: Player): BasePart?
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Kampfplatz vor dem Spieler: eigene Bestie nah, gegnerische weiter weg (in Richtung "toward")
local function anchorsFor(player: Player, toward: Vector3?)
	local root = rootOf(player)
	if not root then
		return nil, nil
	end
	local pos = root.Position
	local dir = if toward then Vector3.new(toward.X - pos.X, 0, toward.Z - pos.Z) else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else Vector3.new(0, 0, -1)
	root.CFrame = CFrame.lookAt(pos, pos + dir)
	local allyPos = pos + dir * 6
	local enemyPos = pos + dir * 19
	return groundCFrame(allyPos, enemyPos), groundCFrame(enemyPos, allyPos)
end

---------------------------------------------------------------- Seiten

local function playerSide(player: Player, anchor: CFrame, persistent: boolean)
	local fighters = {}
	for _, item in BattleService.Services.BeastService:TeamEntries(player) do
		local entry = item.Entry
		local fighter
		if persistent then
			fighter = makeFighter(entry.S, entry.L, entry.Sh, entry.Hp, item.Uid, entry.M, entry.PP, entry.St)
			fighter.Entry = entry
		else
			-- Duelle: volle KP und AP, nichts wird gespeichert
			fighter = makeFighter(entry.S, entry.L, entry.Sh, nil, item.Uid, table.clone(entry.M), nil, nil)
		end
		table.insert(fighters, fighter)
	end
	local side = { Player = player, Name = player.DisplayName, Fighters = fighters, Anchor = anchor }
	side.Active = nextHealthy(side) or 1
	return side
end

local function aiSide(sideName: string, team: { { any } }, anchor: CFrame)
	local fighters = {}
	for _, member in team do
		table.insert(fighters, makeFighter(member[1], member[2], member[3]))
	end
	return { Name = sideName, Fighters = fighters, Active = 1, Anchor = anchor }
end

local function sidePayload(side)
	local fighters = {}
	for _, fighter in side.Fighters do
		table.insert(fighters, summary(fighter))
	end
	return { Name = side.Name, Title = side.Title, Look = side.Look, Fighters = fighters, Active = side.Active, Model = side.Model, Anchor = side.Anchor, IsPlayer = side.Player ~= nil, UserId = if side.Player then side.Player.UserId else nil }
end

local function sendAll(battle, kind: string, payload)
	for _, side in battle.Sides do
		if side.Player and side.Player.Parent then
			BattleService.Services.Net.Battle:FireClient(side.Player, kind, payload)
		end
	end
end

-- Wer gegen welche gegnerische Bestie gekaempft hat (fuer die EP)
local function markParticipants(battle)
	for index, side in battle.Sides do
		if side.Player then
			local enemy = battle.Sides[3 - index]
			side.Participants[enemy.Active] = side.Participants[enemy.Active] or {}
			side.Participants[enemy.Active][side.Active] = true
		end
	end
end

---------------------------------------------------------------- Start

local runBattle -- weiter unten

local function begin(kind: string, sideA, sideB, extra)
	nextId += 1
	local battle = {
		Id = nextId,
		Kind = kind,
		Sides = { sideA, sideB },
		Turn = 0,
		Over = false,
		Coins = 0,
		Acks = {},
		Folder = Instance.new("Folder"),
	}
	for key, value in extra or {} do
		battle[key] = value
	end
	battle.Folder.Name = "B" .. battle.Id
	battle.Folder.Parent = folder
	battles[battle.Id] = battle
	for index, side in battle.Sides do
		side.Participants = {}
		side.LearnPrompts = {}
		if side.Player then
			byPlayer[side.Player] = battle
			freeze(side.Player, true)
		end
		spawnModel(battle, side, index)
	end
	markParticipants(battle)
	for index, side in battle.Sides do
		local enemy = battle.Sides[3 - index]
		if side.Player then
			for _, fighter in enemy.Fighters do
				if fighter == active(enemy) then
					BattleService.Services.BeastService:MarkSeen(side.Player, fighter.Id)
				end
			end
			BattleService.Services.Net.Battle:FireClient(side.Player, "Start", {
				Id = battle.Id,
				Kind = kind,
				You = index,
				Sides = { sidePayload(battle.Sides[1]), sidePayload(battle.Sides[2]) },
				Wave = battle.Wave,
				Music = battle.Music,
				CanRun = kind ~= "Trainer",
				CanCatch = kind == "Wild" or kind == "Legend",
			})
		end
	end
	task.spawn(runBattle, battle)
	return battle
end

local function canStart(player: Player): boolean
	local services = BattleService.Services
	if byPlayer[player] then
		return false
	end
	local data = services.DataService:Get(player)
	if not data or not data.Started then
		return false
	end
	if not services.BeastService:HasHealthyTeam(player) then
		services.Net.SendNotify(player, "Your team is exhausted! Heal at a Healing Center.", RED)
		services.MonetizationService:Offer(player, "FullHeal", "Team exhausted! Heal everyone right here?", true)
		return false
	end
	return true
end

-- Wilde Bestie (hohes Gras) oder Legende. opts: { Legend = true, OnEnd = function(player, result) }
function BattleService:StartWild(player: Player, beastId: string, level: number, shiny: boolean?, opts: any?)
	opts = opts or {}
	if not canStart(player) then
		return nil
	end
	local allyAnchor, enemyAnchor = anchorsFor(player, opts.Toward)
	if not allyAnchor then
		return nil
	end
	local sideA = playerSide(player, allyAnchor, true)
	local sideB = aiSide("Wild", { { beastId, level, shiny } }, enemyAnchor)
	sideB.Wild = true
	return begin(if opts.Legend then "Legend" else "Wild", sideA, sideB, { OnEnd = opts.OnEnd, Music = if opts.Legend then "Legend" else "Wild" })
end

-- Trainer-Kampf. spec: { Name, Title, Look, Team, Coins, Smart, Potions, Toward, Music, Gauntlet, OnEnd }
function BattleService:StartTrainer(player: Player, spec)
	if not canStart(player) then
		return nil
	end
	local allyAnchor, enemyAnchor = anchorsFor(player, spec.Toward)
	if not allyAnchor then
		return nil
	end
	local sideA = playerSide(player, allyAnchor, true)
	local sideB = aiSide(spec.Name, spec.Team, enemyAnchor)
	sideB.Title = spec.Title
	sideB.Look = spec.Look
	sideB.Smart = spec.Smart
	sideB.Potions = spec.Potions or 0
	return begin(spec.Kind or "Trainer", sideA, sideB, {
		OnEnd = spec.OnEnd,
		Reward = spec.Coins,
		RewardItems = spec.Items,
		Music = spec.Music or "Trainer",
		Wave = spec.Wave,
		WavesWon = 0,
		NoWhiteout = spec.NoWhiteout,
	})
end

local function gauntletTeam(wave: number)
	local pool = {}
	for _, beast in Config.Beasts do
		if Config.RaritiesByName[beast.Rarity].Index <= 3 then
			table.insert(pool, beast.Id)
		end
	end
	local level = Config.GauntletLevel(wave)
	local size = 1 + (if wave >= 5 then 1 else 0) + (if wave >= 15 then 1 else 0)
	local team = {}
	for _ = 1, size do
		table.insert(team, { pool[random:NextInteger(1, #pool)], math.clamp(level + random:NextInteger(-1, 1), 2, Config.MaxLevel) })
	end
	-- Jede 10. Welle: eine Legende als Boss
	if wave % 10 == 0 then
		local legends = { "colossix", "aurelion", "glacirion", "zephyros", "voidrake" }
		table.insert(team, { legends[(wave // 10 - 1) % #legends + 1], math.min(Config.MaxLevel, level + 3) })
	end
	return team
end

function BattleService:StartGauntlet(player: Player, wave: number?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if data.Crests < Config.GauntletBadges then
		self.Services.Net.SendNotify(player, "The Gauntlet opens after your first arena badge!", RED)
		return
	end
	local startWave = wave or 1
	self:StartTrainer(player, {
		Kind = "Gauntlet",
		Name = `Gauntlet Wave {startWave}`,
		Title = "Gauntlet",
		Look = "Ace",
		Team = gauntletTeam(startWave),
		Smart = true,
		Wave = startWave,
		Music = "Leader",
	})
end

function BattleService:ContinueGauntlet(player: Player): boolean
	local pending = gauntletPending[player]
	gauntletPending[player] = nil
	self.Services.BeastService:HealAll(player)
	if not pending or os.clock() > pending.Expires or byPlayer[player] then
		return false
	end
	task.delay(1, function()
		self:StartGauntlet(player, pending.Wave)
	end)
	return true
end

function BattleService:StartDuel(a: Player, b: Player)
	if not canStart(a) or not canStart(b) then
		return
	end
	local rootA, rootB = rootOf(a), rootOf(b)
	if not rootA or not rootB or (rootA.Position - rootB.Position).Magnitude > 40 then
		self.Services.Net.SendNotify(a, "Stand closer to start a duel.", RED)
		return
	end
	local mid = (rootA.Position + rootB.Position) / 2
	local dir = Vector3.new(rootB.Position.X - rootA.Position.X, 0, rootB.Position.Z - rootA.Position.Z)
	dir = if dir.Magnitude > 0.5 then dir.Unit else Vector3.new(0, 0, -1)
	local posA = mid - dir * 16
	local posB = mid + dir * 16
	rootA.CFrame = CFrame.lookAt(Vector3.new(posA.X, rootA.Position.Y, posA.Z), Vector3.new(mid.X, rootA.Position.Y, mid.Z))
	rootB.CFrame = CFrame.lookAt(Vector3.new(posB.X, rootB.Position.Y, posB.Z), Vector3.new(mid.X, rootB.Position.Y, mid.Z))
	local sideA = playerSide(a, groundCFrame(posA + dir * 6, posB), false)
	local sideB = playerSide(b, groundCFrame(posB - dir * 6, posA), false)
	begin("Duel", sideA, sideB, { Music = "Trainer" })
end

---------------------------------------------------------------- EP

local function awardXp(battle, fallenSide: number, fallenIndex: number, events)
	local side = battle.Sides[3 - fallenSide]
	local player = side.Player
	if not player or battle.Kind == "Duel" then
		return
	end
	local services = BattleService.Services
	local fallen = battle.Sides[fallenSide].Fighters[fallenIndex]
	local base = Beasts.XpYield(fallen.Id, fallen.Level, not battle.Sides[fallenSide].Wild)
	local mult = services.MonetizationService:XpMultiplier(player)
	local share = if services.MonetizationService:HasPass(player, "BigTeam") then 1 else Config.BenchXpShare
	local participants = side.Participants[fallenIndex] or {}
	local benchGot = false
	for index, fighter in side.Fighters do
		local entry = fighter.Entry
		if fighter.Hp > 0 and entry and fighter.Level < Config.MaxLevel then
			local fought = participants[index] == true
			local amount = math.floor(base * mult * (if fought then 1 else share))
			if amount > 0 then
				local beastName = Config.BeastsById[fighter.Id].Name
				entry.Hp = fighter.Hp
				local results = services.BeastService:GiveXp(player, fighter.Uid, amount)
				if fought then
					table.insert(events, { T = "Xp", Uid = fighter.Uid, Amount = amount, X = entry.X, Need = Config.XpToNext(entry.L), Level = entry.L, Text = `{beastName} gained {Format.Number(amount)} EXP. Points!` })
				else
					benchGot = true
				end
				for _, result in results do
					if result.T == "Level" then
						fighter.Level = entry.L
						fighter.Hp = entry.Hp
						refreshStats(fighter)
						table.insert(events, { T = "Level", Uid = fighter.Uid, Level = fighter.Level, Hp = fighter.Hp, MaxHp = fighter.MaxHp, X = entry.X, Need = Config.XpToNext(entry.L), Text = `{beastName} grew to Lv. {fighter.Level}!` })
					elseif result.T == "Learned" then
						table.insert(events, { T = "Msg", Text = `{beastName} learned {Config.Moves[result.Move].Name}!`, Sound = "Learn" })
					elseif result.T == "LearnPrompt" then
						table.insert(side.LearnPrompts, result)
						table.insert(events, { T = "Msg", Text = `{beastName} wants to learn {Config.Moves[result.Move].Name}...` })
					end
				end
			end
		end
	end
	if benchGot then
		table.insert(events, { T = "Msg", Text = "The rest of your team gained EXP. too!" })
	end
end

---------------------------------------------------------------- Runden

local function faint(battle, sideIndex: number, events)
	local side = battle.Sides[sideIndex]
	local fighter = active(side)
	if fighter.Fainted then
		return
	end
	fighter.Fainted = true
	fighter.Hp = 0
	fighter.Status = nil
	table.insert(events, { T = "Faint", Side = sideIndex, Text = `{name(sideIndex)} fainted!` })
	awardXp(battle, sideIndex, side.Active, events)
end

local function useMove(battle, sideIndex: number, slot: number, events)
	local side = battle.Sides[sideIndex]
	local fighter = active(side)
	local targetIndex = 3 - sideIndex
	local target = active(battle.Sides[targetIndex])
	if fighter.Hp <= 0 then
		return
	end

	-- Statusprobleme, die das Handeln verhindern
	if fighter.Status == "Sleep" then
		fighter.Sleep -= 1
		if fighter.Sleep <= 0 then
			fighter.Status = nil
			table.insert(events, { T = "Status", Side = sideIndex, Status = nil, Text = `{name(sideIndex)} woke up!` })
		else
			table.insert(events, { T = "Msg", Side = sideIndex, Anim = "Sleep", Text = `{name(sideIndex)} is fast asleep.` })
			return
		end
	elseif fighter.Status == "Freeze" then
		if random:NextNumber() < 0.2 then
			fighter.Status = nil
			table.insert(events, { T = "Status", Side = sideIndex, Status = nil, Text = `{name(sideIndex)} thawed out!` })
		else
			table.insert(events, { T = "Msg", Side = sideIndex, Anim = "Freeze", Text = `{name(sideIndex)} is frozen solid!` })
			return
		end
	elseif fighter.Status == "Para" and random:NextNumber() < 0.25 then
		table.insert(events, { T = "Msg", Side = sideIndex, Anim = "Para", Text = `{name(sideIndex)} is paralyzed! It can't move!` })
		return
	end

	-- Attacke waehlen (ohne AP: Verzweifler)
	local key = "Struggle"
	if slot > 0 and fighter.Moves[slot] and (fighter.PP[slot] or 0) > 0 then
		key = fighter.Moves[slot]
		fighter.PP[slot] -= 1
	end
	local move = Config.Moves[key]
	local effect = move.Effect
	table.insert(events, { T = "Move", Side = sideIndex, Key = key, Name = move.Name, Type = move.Type, Power = move.Power, Text = `{name(sideIndex)} used {move.Name}!` })

	if target.Hp <= 0 and not (effect and (effect.Self or effect.Heal)) then
		table.insert(events, { T = "Msg", Text = "But there was no target..." })
		return
	end

	-- Statusattacken
	if move.Power == 0 then
		if effect and effect.Heal then
			if fighter.Hp >= fighter.MaxHp then
				table.insert(events, { T = "Msg", Text = `{name(sideIndex)}'s HP is full!` })
			else
				fighter.Hp = math.min(fighter.MaxHp, fighter.Hp + math.floor(fighter.MaxHp * effect.Heal))
				table.insert(events, { T = "Heal", Side = sideIndex, Hp = fighter.Hp, Text = `{name(sideIndex)} regained health!` })
			end
		elseif effect and effect.Self then
			changeStage(battle, sideIndex, effect.Stat, effect.Stages, events)
		elseif effect then
			if move.Acc and random:NextNumber() > move.Acc then
				table.insert(events, { T = "Miss", Side = sideIndex, Text = `{name(sideIndex)}'s attack missed!` })
				return
			end
			if effect.Status then
				tryStatus(battle, targetIndex, effect.Status, events, true)
			elseif effect.Stat then
				changeStage(battle, targetIndex, effect.Stat, effect.Stages, events)
			end
		end
		return
	end

	-- Schadensattacken
	if move.Acc and random:NextNumber() > move.Acc then
		table.insert(events, { T = "Miss", Side = sideIndex, Text = `{name(sideIndex)}'s attack missed!` })
		return
	end
	local damage, eff, crit = computeDamage(fighter, target, key)
	if eff == 0 then
		table.insert(events, { T = "Msg", Text = `It doesn't affect {name(targetIndex)}...` })
		return
	end
	damage = math.min(damage, target.Hp)
	target.Hp -= damage
	local lines = {}
	if crit then
		table.insert(lines, "A critical hit!")
	end
	if eff > 1 then
		table.insert(lines, "It's super effective!")
	elseif eff < 1 then
		table.insert(lines, "It's not very effective...")
	end
	table.insert(events, { T = "Hit", Side = targetIndex, From = sideIndex, Damage = damage, Hp = target.Hp, Eff = eff, Crit = crit, Type = move.Type, Lines = lines })

	if target.Status == "Freeze" and move.Type == "Fire" and target.Hp > 0 then
		target.Status = nil
		table.insert(events, { T = "Status", Side = targetIndex, Status = nil, Text = `{name(targetIndex)} thawed out!` })
	end
	if move.Drain and fighter.Hp < fighter.MaxHp then
		fighter.Hp = math.min(fighter.MaxHp, fighter.Hp + math.max(1, math.floor(damage * move.Drain)))
		table.insert(events, { T = "Heal", Side = sideIndex, Hp = fighter.Hp, Text = `{name(targetIndex)} had its energy drained!` })
	end
	if move.Recoil then
		local recoil = math.max(1, math.floor(if key == "Struggle" then fighter.MaxHp * move.Recoil else damage * move.Recoil))
		fighter.Hp = math.max(0, fighter.Hp - recoil)
		table.insert(events, { T = "Hit", Side = sideIndex, Damage = recoil, Hp = fighter.Hp, Eff = 1, Recoil = true, Lines = { `{name(sideIndex)} is hit with recoil!` } })
	end
	if effect and target.Hp > 0 then
		if effect.Status and random:NextNumber() < (effect.Chance or 1) then
			tryStatus(battle, targetIndex, effect.Status, events, false)
		elseif effect.Stat and random:NextNumber() < (effect.Chance or 1) then
			changeStage(battle, if effect.Self then sideIndex else targetIndex, effect.Stat, effect.Stages, events)
		end
	end
	if target.Hp <= 0 then
		faint(battle, targetIndex, events)
	end
	if fighter.Hp <= 0 then
		faint(battle, sideIndex, events)
	end
end

local function luckFor(player: Player?): number
	if not player then
		return 1
	end
	return BattleService.Services.MonetizationService:CatchLuck(player)
end

-- Fangchancen fuer die Anzeige im Beutel
local function catchChances(battle, sideIndex: number)
	if battle.Kind ~= "Wild" and battle.Kind ~= "Legend" then
		return nil
	end
	local side = battle.Sides[sideIndex]
	local target = active(battle.Sides[3 - sideIndex])
	local chances = {}
	for key, item in Config.Items do
		if item.Catch then
			chances[key] = Beasts.CatchChance(target.Id, target.Hp, target.MaxHp, target.Status, item.Catch, luckFor(side.Player))
		end
	end
	return chances
end

local function tryCatch(battle, sideIndex: number, itemKey: string, events)
	local side = battle.Sides[sideIndex]
	local item = Config.Items[itemKey]
	local target = active(battle.Sides[3 - sideIndex])
	local chance = Beasts.CatchChance(target.Id, target.Hp, target.MaxHp, target.Status, item.Catch, luckFor(side.Player))
	-- Wackeln wie im Klassiker: 3 Pruefungen mit chance^(1/4), dann die letzte
	local shake = chance ^ 0.25
	local shakes = 0
	for _ = 1, 3 do
		if random:NextNumber() < shake then
			shakes += 1
		else
			break
		end
	end
	local success = chance >= 1 or (shakes == 3 and random:NextNumber() < shake)
	if success then
		shakes = 3
	end
	local texts = { [0] = "Oh no! The beast broke free!", [1] = "Aww! It appeared to be caught!", [2] = "Aargh! Almost had it!", [3] = "Gah! It was so close, too!" }
	table.insert(events, {
		T = "Catch",
		Side = sideIndex,
		Item = itemKey,
		Shakes = shakes,
		Success = success,
		Text = `{side.Name} threw a {item.Name}!`,
		Result = if success then `Gotcha! {Config.BeastsById[target.Id].Name} was caught!` else texts[shakes],
	})
	if success then
		battle.Result = "Caught"
		battle.Winner = sideIndex
	else
		side.FailedCatches = (side.FailedCatches or 0) + 1
	end
end

local function useItem(battle, sideIndex: number, action, events)
	local side = battle.Sides[sideIndex]
	local services = BattleService.Services
	local item = Config.Items[action.Key]
	if not item or not side.Player or not services.BeastService:UseItem(side.Player, action.Key) then
		return
	end
	if item.Catch then
		tryCatch(battle, sideIndex, action.Key, events)
		return
	end
	local target = side.Fighters[action.Target or side.Active]
	if not target then
		return
	end
	local beastName = Config.BeastsById[target.Id].Name
	if not services.BeastService.ItemUsable(item, target.Hp, target.MaxHp, target.Status) then
		table.insert(events, { T = "Msg", Text = `{side.Name} used a {item.Name}... but it had no effect.` })
		return
	end
	local before = target.Hp
	services.BeastService.ApplyItem(item, target, target.MaxHp)
	if item.Revive then
		target.Fainted = nil
	end
	local text = if item.Revive then `{beastName} was revived!` elseif item.Cure then `{beastName} was cured!` else `{beastName} recovered {target.Hp - before} HP!`
	table.insert(events, { T = "Item", Side = sideIndex, Index = action.Target or side.Active, Item = action.Key, Hp = target.Hp, Status = target.Status, Text = `{side.Name} used a {item.Name}! {text}` })
end

local function trySwap(battle, sideIndex: number, index: number, events, forced: boolean?)
	local side = battle.Sides[sideIndex]
	local old = active(side)
	local oldName = Config.BeastsById[old.Id].Name
	old.Stages = { Atk = 0, Def = 0, Spd = 0 }
	side.Active = index
	local fighter = active(side)
	local model = spawnModel(battle, side, sideIndex)
	local beastName = Config.BeastsById[fighter.Id].Name
	local text
	if side.Player then
		text = if forced then `Go! {beastName}!` else `Come back, {oldName}! Go! {beastName}!`
	else
		text = `{side.Name} sent out {beastName}!`
	end
	table.insert(events, { T = "Send", Side = sideIndex, Fighter = summary(fighter), Index = index, Model = model, Text = text })
	local enemy = battle.Sides[3 - sideIndex]
	if enemy.Player then
		BattleService.Services.BeastService:MarkSeen(enemy.Player, fighter.Id)
	end
	markParticipants(battle)
end

local function tryRun(battle, sideIndex: number, events)
	local side = battle.Sides[sideIndex]
	if battle.Kind == "Wild" or battle.Kind == "Legend" then
		local mine = speedOf(active(side))
		local theirs = speedOf(active(battle.Sides[3 - sideIndex]))
		side.RunAttempts = (side.RunAttempts or 0) + 1
		local chance = if mine >= theirs then 1 else (mine * 128 / math.max(1, theirs) + 30 * side.RunAttempts) / 256
		if random:NextNumber() < chance then
			table.insert(events, { T = "Run", Side = sideIndex, Success = true, Text = "Got away safely!" })
			battle.Result = "Run"
			battle.Winner = 3 - sideIndex
		else
			table.insert(events, { T = "Run", Side = sideIndex, Success = false, Text = "Can't escape!" })
		end
	else
		table.insert(events, { T = "Run", Side = sideIndex, Success = true, Text = `{side.Name} gave up the battle!` })
		battle.Result = "Forfeit"
		battle.Winner = 3 - sideIndex
	end
end

-- Statusschaden am Rundenende
local function endOfTurn(battle, events)
	for index, side in battle.Sides do
		local fighter = active(side)
		if fighter.Hp > 0 and (fighter.Status == "Burn" or fighter.Status == "Poison") then
			local damage = math.max(1, math.floor(fighter.MaxHp / (if fighter.Status == "Burn" then 16 else 8)))
			fighter.Hp = math.max(0, fighter.Hp - damage)
			table.insert(events, { T = "Hit", Side = index, Damage = damage, Hp = fighter.Hp, Eff = 1, Status = fighter.Status, Lines = { `{name(index)} is hurt by its {if fighter.Status == "Burn" then "burn" else "poison"}!` } })
			if fighter.Hp <= 0 then
				faint(battle, index, events)
			end
		end
	end
end

local function checkWinner(battle)
	if battle.Winner then
		return
	end
	local out1 = nextHealthy(battle.Sides[1]) == nil
	local out2 = nextHealthy(battle.Sides[2]) == nil
	if out1 and out2 then
		battle.Winner = if battle.Kind == "Duel" then 1 else 2
	elseif out1 then
		battle.Winner = 2
	elseif out2 then
		battle.Winner = 1
	end
end

local function priorityOf(battle, sideIndex: number): number
	local side = battle.Sides[sideIndex]
	local action = side.Action
	if not action or action.Kind ~= "Move" then
		return 10 -- Wechsel, Gegenstaende und Flucht kommen zuerst
	end
	local key = active(side).Moves[action.Slot]
	local move = key and Config.Moves[key]
	return if move then move.Priority else 0
end

local function resolveTurn(battle)
	local events = {}

	-- Reihenfolge: Aktionen ohne Angriff zuerst, dann Prioritaet, dann Initiative
	local order = { 1, 2 }
	local tie = random:NextNumber() < 0.5
	table.sort(order, function(a, b)
		local pa, pb = priorityOf(battle, a), priorityOf(battle, b)
		if pa ~= pb then
			return pa > pb
		end
		local sa, sb = speedOf(active(battle.Sides[a])), speedOf(active(battle.Sides[b]))
		if sa ~= sb then
			return sa > sb
		end
		return if tie then a < b else a > b
	end)

	for _, index in order do
		if battle.Winner then
			break
		end
		local side = battle.Sides[index]
		local action = side.Action
		if action then
			if action.Kind == "Run" then
				tryRun(battle, index, events)
			elseif action.Kind == "Swap" then
				trySwap(battle, index, action.Index, events)
			elseif action.Kind == "Item" then
				useItem(battle, index, action, events)
			elseif action.Kind == "AiPotion" then
				side.Potions -= 1
				local fighter = active(side)
				fighter.Hp = math.min(fighter.MaxHp, fighter.Hp + math.floor(fighter.MaxHp * 0.6))
				table.insert(events, { T = "Item", Side = index, Index = side.Active, Item = "HyperPotion", Hp = fighter.Hp, Text = `{side.Name} used a Hyper Potion!` })
			elseif action.Kind == "Move" then
				useMove(battle, index, action.Slot, events)
			end
		end
		checkWinner(battle)
	end
	if not battle.Winner then
		endOfTurn(battle, events)
		checkWinner(battle)
	end
	return events
end

---------------------------------------------------------------- Ablauf

local function requestActions(battle)
	for index, side in battle.Sides do
		side.Action = nil
		local fighter = active(side)
		local foe = active(battle.Sides[3 - index])
		if side.Player then
			local team = {}
			for _, member in side.Fighters do
				table.insert(team, summary(member))
			end
			local data = BattleService.Services.DataService:Get(side.Player)
			side.Waiting = "Turn"
			BattleService.Services.Net.Battle:FireClient(side.Player, "Turn", {
				Id = battle.Id,
				Turn = battle.Turn,
				Timeout = Config.TurnTimeout,
				Moves = movesInfo(fighter, foe),
				Items = if data then data.Items else {},
				Team = team,
				Active = side.Active,
				Chances = catchChances(battle, index),
				Auto = autoBattle[side.Player] == true,
			})
			if autoBattle[side.Player] and BattleService.Services.MonetizationService:HasPass(side.Player, "AutoBattle") then
				side.Action = { Kind = "Move", Slot = bestMove(fighter, foe, 0.05, true) }
			end
		else
			side.Action = aiAction(battle, index)
		end
	end
end

local function waitFor(battle, check: () -> boolean, seconds: number)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not battle.Over do
		if check() then
			return true
		end
		task.wait(0.1)
	end
	return false
end

local function waitForActions(battle)
	waitFor(battle, function()
		return battle.Sides[1].Action ~= nil and battle.Sides[2].Action ~= nil
	end, Config.TurnTimeout)
	-- Wer nicht rechtzeitig waehlt, greift automatisch an
	for index, side in battle.Sides do
		side.Waiting = nil
		if not side.Action then
			side.Action = { Kind = "Move", Slot = bestMove(active(side), active(battle.Sides[3 - index]), 0, true) }
		end
	end
end

-- Abspielzeit der Ereignisse auf dem Client (Obergrenze, falls keine Bestaetigung kommt)
local function playTime(events): number
	local total = 0.5
	for _, event in events do
		total += if event.T == "Catch" then 2.2 + event.Shakes * 0.9 elseif event.T == "Hit" then 1.2 + #(event.Lines or {}) * 1.1 elseif event.T == "Send" then 2 else 1.3
	end
	return total
end

-- Ereignisse senden und warten, bis alle Spieler sie abgespielt haben
local function play(battle, events)
	if #events == 0 then
		return
	end
	battle.Acks = {}
	battle.Seq = (battle.Seq or 0) + 1
	local seq = battle.Seq
	sendAll(battle, "Events", { Id = battle.Id, Seq = seq, Events = events })
	waitFor(battle, function()
		for _, side in battle.Sides do
			if side.Player and side.Player.Parent and battle.Acks[side.Player] ~= seq then
				return false
			end
		end
		return true
	end, playTime(events) + 6)
end

-- Nach einem K.O.: naechste Bestie waehlen (Spieler) oder schicken (Computer)
local function replaceFainted(battle)
	for index, side in battle.Sides do
		local fighter = active(side)
		if fighter.Hp <= 0 and nextHealthy(side) then
			if side.Player then
				local team = {}
				for _, member in side.Fighters do
					table.insert(team, summary(member))
				end
				side.Action = nil
				side.Waiting = "Replace"
				BattleService.Services.Net.Battle:FireClient(side.Player, "Replace", { Id = battle.Id, Team = team, Active = side.Active, CanRun = battle.Kind == "Wild" })
				if autoBattle[side.Player] and BattleService.Services.MonetizationService:HasPass(side.Player, "AutoBattle") then
					side.Action = { Kind = "Replace", Index = nextHealthy(side) }
				end
			else
				side.Action = { Kind = "Replace", Index = nextHealthy(side) }
			end
		else
			side.Action = { Kind = "None" }
		end
	end
	waitFor(battle, function()
		return battle.Sides[1].Action ~= nil and battle.Sides[2].Action ~= nil
	end, Config.TurnTimeout)
	local events = {}
	for index, side in battle.Sides do
		side.Waiting = nil
		local action = side.Action
		if action and action.Kind == "Run" and battle.Kind == "Wild" then
			table.insert(events, { T = "Run", Side = index, Success = true, Text = "Got away safely!" })
			battle.Result = "Run"
			battle.Winner = 3 - index
		elseif active(side).Hp <= 0 and nextHealthy(side) then
			local target = action and action.Kind == "Replace" and side.Fighters[action.Index]
			local choice = if target and target.Hp > 0 then action.Index else nextHealthy(side)
			trySwap(battle, index, choice :: number, events, true)
		end
	end
	play(battle, events)
end

-- Gauntlet: Gegnerteam besiegt -> naechste Welle
local function nextWave(battle)
	local side = battle.Sides[2]
	battle.Coins += Config.GauntletCoinsPerWave * battle.Wave
	battle.WavesWon += 1
	battle.Wave += 1
	local newSide = aiSide(`Gauntlet Wave {battle.Wave}`, gauntletTeam(battle.Wave), side.Anchor)
	side.Fighters = newSide.Fighters
	side.Name = newSide.Name
	side.Active = 1
	side.Action = nil
	battle.Sides[1].Participants = {}
	local model = spawnModel(battle, side, 2)
	markParticipants(battle)
	local fighters = {}
	for _, fighter in side.Fighters do
		table.insert(fighters, summary(fighter))
	end
	play(battle, {
		{ T = "Wave", Side = 2, Wave = battle.Wave, Fighters = fighters, Model = model, Name = side.Name, Text = `Wave {battle.Wave}! {side.Name} sent out {Config.BeastsById[side.Fighters[1].Id].Name}!` },
	})
end

local finish -- weiter unten

runBattle = function(battle)
	task.wait(3) -- Einblendung und Begruessung auf dem Client
	while not battle.Over do
		battle.Turn += 1
		markParticipants(battle)
		requestActions(battle)
		waitForActions(battle)
		if battle.Over then
			break
		end
		local events = resolveTurn(battle)
		play(battle, events)
		if battle.Over then
			break
		end
		if battle.Kind == "Gauntlet" and battle.Winner == 1 and battle.Result == nil then
			battle.Winner = nil
			nextWave(battle)
			replaceFainted(battle)
		elseif battle.Winner then
			finish(battle)
		else
			replaceFainted(battle)
			if battle.Winner then
				finish(battle)
			end
		end
	end
end

---------------------------------------------------------------- Ende

finish = function(battle)
	if battle.Over then
		return
	end
	battle.Over = true
	local services = BattleService.Services
	battles[battle.Id] = nil

	for index, side in battle.Sides do
		local player = side.Player
		if player then
			byPlayer[player] = nil
			local lost = false
			local data = services.DataService:Get(player)
			if data then
				-- KP und Status zurueckschreiben (Duelle kosten nichts)
				if battle.Kind ~= "Duel" then
					for _, fighter in side.Fighters do
						local entry = fighter.Entry
						if entry and entry.S == fighter.Id then
							entry.Hp = fighter.Hp
							entry.St = fighter.Status
						end
					end
				end
				local won = battle.Winner == index
				local result = if battle.Result == "Run" then "Run" elseif battle.Result == "Forfeit" and not won then "Forfeit" elseif won then (if battle.Result == "Caught" then "Caught" else "Win") else "Lose"
				lost = result == "Lose"
				local report = { Id = battle.Id, Kind = battle.Kind, Result = result, Coins = 0, Events = {}, Lines = {} }
				local coinMult = services.MonetizationService:CoinMultiplier(player)
				local enemy = battle.Sides[3 - index]
				local coins = 0

				if (battle.Kind == "Wild" or battle.Kind == "Legend") and result == "Win" then
					coins = Config.WildCoins(active(enemy).Level)
					data.Wins += 1
				elseif battle.Kind == "Trainer" and result == "Win" then
					local team = {}
					for _, fighter in enemy.Fighters do
						table.insert(team, { fighter.Id, fighter.Level })
					end
					coins = battle.Reward or Config.TrainerCoins(team)
					data.Wins += 1
				elseif battle.Kind == "Gauntlet" then
					coins = battle.Coins
					local reached = battle.WavesWon
					report.Wave = battle.Wave
					if reached > data.BestWave then
						data.BestWave = reached
						report.Record = true
						if reached >= 10 then
							services.Net.SendAnnounce(`{player.DisplayName} survived {reached} waves in the Gauntlet!`, GOLD)
						end
					end
					if result == "Lose" then
						gauntletPending[player] = { Wave = battle.Wave, Expires = os.clock() + 30 }
						report.CanContinue = true
						services.MonetizationService:Offer(player, "GauntletContinue", `Keep your streak at wave {battle.Wave}! Revive your team and continue?`, true)
					end
				elseif battle.Kind == "Duel" then
					if won then
						data.Trophies += Config.DuelTrophies
						coins = 40 + services.BeastService:LeadLevel(player) * 5
						report.Trophies = Config.DuelTrophies
						services.Net.SendAnnounce(`{player.DisplayName} won a duel against {enemy.Name}!`, GOLD)
					elseif result ~= "Run" then
						data.Trophies = math.max(0, data.Trophies - 3)
						report.Trophies = -3
					end
				end

				if result == "Caught" then
					local wild = active(enemy)
					local uid = services.BeastService:Add(player, wild.Id, wild.Level, wild.Shiny, math.max(1, wild.Hp), table.clone(wild.Moves), wild.Status)
					if uid then
						report.Caught = { Id = wild.Id, Level = wild.Level, Shiny = wild.Shiny, Uid = uid, ToBox = not table.find(data.Team, uid) }
						coins = Config.WildCoins(wild.Level)
						local rarity = Config.RaritiesByName[Config.BeastsById[wild.Id].Rarity]
						if rarity.Announce or wild.Shiny then
							services.Net.SendAnnounce(`{player.DisplayName} caught a {if wild.Shiny then "PRISMATIC " else ""}{Config.BeastsById[wild.Id].Name}!`, if wild.Shiny then services.BeastService.PrismColor else GOLD)
						end
					end
				end

				-- Fehlwuerfe: Master Orb anbieten
				local failed = side.FailedCatches or 0
				if (battle.Kind == "Wild" or battle.Kind == "Legend") and result ~= "Caught" and failed >= 1 then
					services.MonetizationService:Offer(player, "MasterOrb1", "It got away! A Master Orb ALWAYS catches.", battle.Kind == "Legend")
				end

				if coins > 0 then
					coins = math.floor(coins * coinMult)
					services.DataService:AddCoins(player, coins)
					report.Coins = coins
				end

				-- Entwicklungen und offene Attacken nach dem Kampf
				if battle.Kind ~= "Duel" then
					for _, event in services.BeastService:CheckEvolutions(player) do
						table.insert(report.Events, event)
					end
					for _, prompt in side.LearnPrompts do
						table.insert(report.Events, prompt)
					end
				end
				report.Whiteout = result == "Lose" and battle.Kind ~= "Duel" and not battle.NoWhiteout
				if report.Whiteout then
					report.Lines = { "You have no more beasts that can fight!", "You hurried back to the Healing Center..." }
				end
				services.DataService:UpdateAttributes(player)
				services.BeastService:Sync(player)
				services.Net.Battle:FireClient(player, "End", report)

				if battle.OnEnd then
					task.spawn(battle.OnEnd, player, result, battle)
				end
				if report.Whiteout then
					task.delay(4, function()
						if player.Parent then
							services.StoryService:Whiteout(player)
						end
					end)
				end
			end
			task.delay(if lost then 5 else 0.6, function()
				if not byPlayer[player] then
					freeze(player, false)
				end
			end)
		end
	end

	task.delay(1.5, function()
		battle.Folder:Destroy()
	end)
end

-- Spieler verlaesst das Spiel mitten im Kampf: zaehlt als Aufgabe
function BattleService:OnPlayerRemoving(player: Player)
	local battle = byPlayer[player]
	autoBattle[player] = nil
	gauntletPending[player] = nil
	if battle and not battle.Over then
		for index, side in battle.Sides do
			if side.Player == player then
				battle.Winner = 3 - index
				battle.Result = "Forfeit"
			end
		end
		finish(battle)
	end
end

---------------------------------------------------------------- Eingaben

function BattleService:Start()
	local services = self.Services

	services.Net.BattleAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) ~= "table" then
			return
		end
		if action.Kind == "Auto" then
			autoBattle[player] = action.On == true
			if action.On and not services.MonetizationService:HasPass(player, "AutoBattle") then
				autoBattle[player] = nil
				services.MonetizationService:PromptPass(player, "AutoBattle")
			end
			return
		end
		local battle = byPlayer[player]
		if not battle or battle.Over then
			return
		end
		if action.Kind == "Ack" then
			if typeof(action.Seq) == "number" then
				battle.Acks[player] = action.Seq
			end
			return
		end
		local sideIndex = if battle.Sides[1].Player == player then 1 else 2
		local side = battle.Sides[sideIndex]
		if side.Action or not side.Waiting then
			return
		end
		local fighter = active(side)
		local index = tonumber(action.Index)

		if side.Waiting == "Replace" then
			if action.Kind == "Replace" and index and side.Fighters[index] and side.Fighters[index].Hp > 0 then
				side.Action = { Kind = "Replace", Index = index }
			elseif action.Kind == "Run" and battle.Kind == "Wild" then
				side.Action = { Kind = "Run" }
			end
			return
		end

		if action.Kind == "Move" then
			local slot = tonumber(action.Slot)
			local hasPP = false
			for i in fighter.Moves do
				if (fighter.PP[i] or 0) > 0 then
					hasPP = true
				end
			end
			if not hasPP then
				side.Action = { Kind = "Move", Slot = 0 } -- Verzweifler
			elseif slot and fighter.Moves[slot] and (fighter.PP[slot] or 0) > 0 then
				side.Action = { Kind = "Move", Slot = slot }
			end
		elseif action.Kind == "Swap" then
			local target = index and side.Fighters[index]
			if target and index ~= side.Active and target.Hp > 0 then
				side.Action = { Kind = "Swap", Index = index }
			end
		elseif action.Kind == "Item" then
			local item = typeof(action.Key) == "string" and Config.Items[action.Key]
			local data = services.DataService:Get(player)
			if battle.Kind == "Duel" then
				return
			end
			if item and data and (data.Items[action.Key] or 0) > 0 then
				if item.Catch then
					if battle.Kind ~= "Wild" and battle.Kind ~= "Legend" then
						return
					end
					side.Action = { Kind = "Item", Key = action.Key }
				else
					local targetIndex = index or side.Active
					local target = side.Fighters[targetIndex]
					if target and services.BeastService.ItemUsable(item, target.Hp, target.MaxHp, target.Status) then
						side.Action = { Kind = "Item", Key = action.Key, Target = targetIndex }
					end
				end
			elseif item and item.Catch == math.huge then
				services.MonetizationService:PromptProduct(player, "MasterOrb1")
			end
		elseif action.Kind == "Run" then
			if battle.Kind == "Trainer" then
				services.Net.SendNotify(player, "No! There's no running from a trainer battle!", RED)
				return
			end
			side.Action = { Kind = "Run" }
		end
	end)

	-- Duelle: Anfrage, Einladung, Antwort
	local invites = {} -- [Ziel] = { From = Player, Expires }
	services.Net.DuelRequest.OnServerEvent:Connect(function(player, target)
		if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player or byPlayer[target] or byPlayer[player] then
			return
		end
		invites[target] = { From = player, Expires = os.clock() + Config.DuelInviteSeconds }
		services.Net.DuelInvite:FireClient(target, player)
		services.Net.SendNotify(player, `Duel request sent to {target.DisplayName}!`, GREEN)
	end)
	services.Net.DuelAnswer.OnServerEvent:Connect(function(player, from, accepted)
		local invite = invites[player]
		if not invite or invite.From ~= from or os.clock() > invite.Expires then
			return
		end
		invites[player] = nil
		if accepted == true and from.Parent then
			self:StartDuel(from, player)
		elseif from.Parent then
			services.Net.SendNotify(from, `{player.DisplayName} declined the duel.`, RED)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		invites[player] = nil
	end)

	services.Net.ArenaChallenge.OnServerEvent:Connect(function(player, which, index)
		if byPlayer[player] or services.StoryService:Busy(player) then
			return
		end
		if which == "Gauntlet" then
			self:StartGauntlet(player)
		elseif which == "Rematch" and typeof(index) == "number" then
			services.StoryService:StartRematch(player, math.floor(index))
		end
	end)
end

-- Fuer den Smoke-Test (tests/smoke.luau): Kampflogik ohne echte Spieler pruefen
BattleService._Internal = {
	MakeFighter = makeFighter,
	AiSide = aiSide,
	ResolveTurn = resolveTurn,
	BestMove = bestMove,
	GauntletTeam = gauntletTeam,
	ComputeDamage = computeDamage,
	AiAction = aiAction,
}

return BattleService
