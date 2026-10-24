-- Rundenkampf-System: wilde Bestien, Champions, Gauntlet und Duelle zwischen Spielern.
-- Der Server entscheidet alles; die Clients bekommen pro Runde eine Liste von Ereignissen zum Abspielen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BeastModel = require(ReplicatedStorage.Shared.BeastModel)

local BattleService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local RED = Color3.fromRGB(255, 90, 90)
local GREEN = Color3.fromRGB(110, 230, 130)

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

local function makeFighter(beastId: string, level: number, shiny: boolean?, hp: number?, uid: string?)
	local stats = Config.Stats(beastId, level, shiny)
	return {
		Id = beastId,
		Level = level,
		Shiny = shiny == true,
		Hp = math.clamp(hp or stats.MaxHp, 0, stats.MaxHp),
		MaxHp = stats.MaxHp,
		Atk = stats.Atk,
		Def = stats.Def,
		Spd = stats.Spd,
		Uid = uid,
		Ult = Config.UltimateUses,
		Moves = Config.MovesFor(beastId, level),
	}
end

local function movesInfo(fighter)
	local list = {}
	for _, key in fighter.Moves do
		local info = Config.MoveInfo(fighter.Id, key)
		table.insert(list, {
			Key = key,
			Name = info.Name,
			Type = info.Type,
			Power = info.Power,
			Accuracy = info.Accuracy,
			Uses = if key == "Ultimate" then fighter.Ult else nil,
		})
	end
	return list
end

local function summary(fighter)
	return { Id = fighter.Id, Level = fighter.Level, Shiny = fighter.Shiny, Hp = fighter.Hp, MaxHp = fighter.MaxHp, Uid = fighter.Uid }
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

-- Schaden eines Angriffs. Gibt Schaden, Wirkung, Krit, Fehlschlag zurueck.
local function computeDamage(attacker, defender, moveKey: string)
	local move = Config.MoveInfo(attacker.Id, moveKey)
	if random:NextNumber() > move.Accuracy then
		return 0, 1, false, true
	end
	local defenderType = Config.BeastsById[defender.Id].Type
	local effect = Config.TypeMultiplier(move.Type, defenderType)
	local stab = if move.Type == Config.BeastsById[attacker.Id].Type then 1.2 else 1
	local crit = random:NextNumber() < Config.CritChance
	local levelFactor = 1 + (attacker.Level - 1) * 0.09
	local damage = move.Power * 0.24 * (attacker.Atk / math.max(1, defender.Def)) * levelFactor
	damage = (damage + 2) * effect * stab * random:NextNumber(0.88, 1) * (if crit then Config.CritMultiplier else 1)
	return math.max(1, math.floor(damage)), effect, crit, false
end

-- Bester Angriff gegen das aktuelle Ziel (fuer Computer-Gegner und Auto Battle)
local function bestMove(attacker, defender, randomness: number): string
	local bestKey, bestScore = "Strike", -1
	for _, key in attacker.Moves do
		if key ~= "Ultimate" or attacker.Ult > 0 then
			local move = Config.MoveInfo(attacker.Id, key)
			local score = move.Power * move.Accuracy * Config.TypeMultiplier(move.Type, Config.BeastsById[defender.Id].Type)
			-- Ultimative Angriffe nicht sofort verschwenden, wenn der Gegner fast besiegt ist
			if key == "Ultimate" and defender.Hp < defender.MaxHp * 0.25 then
				score *= 0.5
			end
			score *= 1 + random:NextNumber() * randomness
			if score > bestScore then
				bestKey, bestScore = key, score
			end
		end
	end
	return bestKey
end

---------------------------------------------------------------- Modelle

local function groundCFrame(position: Vector3, lookAt: Vector3): CFrame
	local flat = Vector3.new(position.X, 0, position.Z)
	local target = Vector3.new(lookAt.X, 0, lookAt.Z)
	if (target - flat).Magnitude < 0.1 then
		target = flat + Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(flat, target)
end

local function spawnModel(battle, side, sideIndex: number)
	if side.Model and not side.WildModel then
		side.Model:Destroy()
	end
	local fighter = active(side)
	local model = BeastModel.Build(fighter.Id, fighter.Level, fighter.Shiny)
	local scale = BeastModel.Scale(fighter.Id, fighter.Level)
	model:PivotTo(side.Anchor * CFrame.new(0, BeastModel.Hover(fighter.Id, scale), 0))
	BeastModel.AddLabel(model, fighter.Id, fighter.Level, fighter.Shiny, if side.Player then side.Player.DisplayName else side.Name)
	model.Name = "Side" .. sideIndex
	model.Parent = battle.Folder
	side.Model = model
	side.WildModel = false
	return model
end

---------------------------------------------------------------- Start

local function freeze(player: Player, frozen: boolean)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = frozen
	end
end

local function sidePayload(side)
	local fighters = {}
	for _, fighter in side.Fighters do
		table.insert(fighters, summary(fighter))
	end
	return { Name = side.Name, Fighters = fighters, Active = side.Active, Model = side.Model, Anchor = side.Anchor, IsPlayer = side.Player ~= nil }
end

local function sendAll(battle, kind: string, payload)
	for _, side in battle.Sides do
		if side.Player and side.Player.Parent then
			BattleService.Services.Net.Battle:FireClient(side.Player, kind, payload)
		end
	end
end

-- Team eines Spielers als Kampfseite
local function playerSide(player: Player, anchor: CFrame)
	local fighters = {}
	for _, item in BattleService.Services.BeastService:TeamEntries(player) do
		local entry = item.Entry
		table.insert(fighters, makeFighter(entry.S, entry.L, entry.Sh, entry.Hp, item.Uid))
	end
	local side = { Player = player, Name = player.DisplayName, Fighters = fighters, Active = nextHealthy({ Fighters = fighters }) or 1, Anchor = anchor, Xp = {}, Seen = {} }
	side.Seen[side.Active] = true
	return side
end

local function aiSide(name: string, team: { { any } }, anchor: CFrame)
	local fighters = {}
	for _, member in team do
		table.insert(fighters, makeFighter(member[1], member[2], member[3]))
	end
	return { Name = name, Fighters = fighters, Active = 1, Anchor = anchor }
end

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
		Folder = Instance.new("Folder"),
	}
	for key, value in extra or {} do
		battle[key] = value
	end
	battle.Folder.Name = "B" .. battle.Id
	battle.Folder.Parent = folder
	battles[battle.Id] = battle
	for index, side in battle.Sides do
		if side.Player then
			byPlayer[side.Player] = battle
			freeze(side.Player, true)
		end
		if not side.Model then
			spawnModel(battle, side, index)
		end
	end
	for index, side in battle.Sides do
		if side.Player then
			local payload = {
				Id = battle.Id,
				Kind = kind,
				You = index,
				Sides = { sidePayload(battle.Sides[1]), sidePayload(battle.Sides[2]) },
				Wave = battle.Wave,
				Champion = battle.Champion,
			}
			BattleService.Services.Net.Battle:FireClient(side.Player, "Start", payload)
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
		services.Net.SendNotify(player, "Your team is exhausted! Heal at the Healing Spring.", RED)
		services.MonetizationService:Offer(player, "FullHeal", "Team exhausted! Heal everyone right here?", true)
		return false
	end
	return true
end

function BattleService:StartWild(player: Player, entity)
	if not canStart(player) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or entity.Busy or not entity.Model.Parent then
		return
	end
	local data = self.Services.DataService:Get(player)
	local zone = Config.Zones[entity.Zone]
	if data.Crests < zone.Crests then
		self.Services.Net.SendNotify(player, `You need {zone.Crests} arena crests to battle in {zone.Name}.`, RED)
		return
	end
	local wildPos = entity.Model:GetPivot().Position
	local dir = Vector3.new(wildPos.X - root.Position.X, 0, wildPos.Z - root.Position.Z)
	if dir.Magnitude < 0.5 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	-- Abstand herstellen, damit beide Bestien Platz haben
	local playerPos = Vector3.new(wildPos.X, root.Position.Y, wildPos.Z) - dir * 16
	root.CFrame = CFrame.lookAt(playerPos, Vector3.new(wildPos.X, root.Position.Y, wildPos.Z))
	self.Services.WildService:Reserve(entity, player)
	local sideA = playerSide(player, groundCFrame(playerPos + dir * 5, wildPos))
	local sideB = aiSide("Wild", { { entity.Beast, entity.Level, entity.Shiny } }, groundCFrame(wildPos, playerPos))
	sideB.Model = entity.Model
	sideB.WildModel = true
	entity.Model:PivotTo(CFrame.lookAt(entity.Model:GetPivot().Position, Vector3.new(playerPos.X, entity.Model:GetPivot().Position.Y, playerPos.Z)))
	begin("Wild", sideA, sideB, { Entity = entity })
end

local function arenaSlot(player: Player)
	local slot = BattleService.Services.WorldService:ClaimArenaSlot(player)
	if not slot then
		BattleService.Services.Net.SendNotify(player, "All arena floors are busy, try again in a moment!", RED)
		return nil
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.CFrame = slot.Player
	end
	return slot
end

function BattleService:StartChampion(player: Player, index: number)
	local data = self.Services.DataService:Get(player)
	local champion = Config.Champions[index]
	if not champion or not data or index > data.Crests + 1 or not canStart(player) then
		return
	end
	local slot = arenaSlot(player)
	if not slot then
		return
	end
	local sideA = playerSide(player, slot.Ally)
	local team = {}
	for _, member in champion.Team do
		table.insert(team, { member[1], member[2] })
	end
	local sideB = aiSide(champion.Name, team, slot.Enemy)
	sideB.Smart = true
	begin("Champion", sideA, sideB, { Champion = index, Slot = slot })
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
		table.insert(team, { pool[random:NextInteger(1, #pool)], math.max(2, level + random:NextInteger(-1, 1)) })
	end
	-- Jede 10. Welle: eine Legende als Boss
	if wave % 10 == 0 then
		local legends = { "colossix", "aurelion", "voidrake" }
		table.insert(team, { legends[(wave // 10 - 1) % #legends + 1], math.min(Config.MaxLevel, level + 3) })
	end
	return team
end

function BattleService:StartGauntlet(player: Player, wave: number?)
	if not canStart(player) then
		return
	end
	local slot = arenaSlot(player)
	if not slot then
		return
	end
	local startWave = wave or 1
	local sideA = playerSide(player, slot.Ally)
	local sideB = aiSide(`Gauntlet Wave {startWave}`, gauntletTeam(startWave), slot.Enemy)
	sideB.Smart = true
	begin("Gauntlet", sideA, sideB, { Wave = startWave, Slot = slot, WavesWon = 0 })
end

function BattleService:ContinueGauntlet(player: Player): boolean
	local pending = gauntletPending[player]
	gauntletPending[player] = nil
	self.Services.BeastService:HealAll(player)
	if not pending or os.clock() > pending.Expires or byPlayer[player] then
		return false
	end
	self:StartGauntlet(player, pending.Wave)
	return true
end

function BattleService:StartDuel(a: Player, b: Player)
	if not canStart(a) or not canStart(b) then
		return
	end
	local rootA = a.Character and a.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootB = b.Character and b.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
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
	local sideA = playerSide(a, groundCFrame(posA + dir * 6, posB))
	local sideB = playerSide(b, groundCFrame(posB - dir * 6, posA))
	begin("Duel", sideA, sideB)
end

---------------------------------------------------------------- Runden

local function luckFor(player: Player?): number
	if not player then
		return 1
	end
	return BattleService.Services.MonetizationService:CatchLuck(player)
end

-- Fangchancen fuer die Anzeige am Fang-Knopf
local function catchChances(battle, sideIndex: number)
	if battle.Kind ~= "Wild" then
		return nil
	end
	local side = battle.Sides[sideIndex]
	local target = active(battle.Sides[3 - sideIndex])
	local chances = {}
	for key, item in Config.Items do
		if item.Catch then
			chances[key] = Config.CatchChance(target.Id, target.Hp / target.MaxHp, item.Catch, luckFor(side.Player))
		end
	end
	return chances
end

local function itemCounts(player: Player)
	local data = BattleService.Services.DataService:Get(player)
	return if data then data.Items else {}
end

local function requestActions(battle)
	for index, side in battle.Sides do
		side.Action = nil
		if side.Player then
			local fighter = active(side)
			local team = {}
			for _, member in side.Fighters do
				table.insert(team, summary(member))
			end
			BattleService.Services.Net.Battle:FireClient(side.Player, "Turn", {
				Id = battle.Id,
				Turn = battle.Turn,
				Timeout = Config.TurnTimeout,
				Moves = movesInfo(fighter),
				Items = itemCounts(side.Player),
				Team = team,
				Active = side.Active,
				Chances = catchChances(battle, index),
				CanRun = true,
				Auto = autoBattle[side.Player] == true,
			})
			if autoBattle[side.Player] and BattleService.Services.MonetizationService:HasPass(side.Player, "AutoBattle") then
				side.Action = { Kind = "Move", Key = bestMove(fighter, active(battle.Sides[3 - index]), 0.05) }
			end
		else
			side.Action = { Kind = "Move", Key = bestMove(active(side), active(battle.Sides[3 - index]), if side.Smart then 0.15 else 0.6) }
		end
	end
end

local function waitForActions(battle)
	local deadline = os.clock() + Config.TurnTimeout
	while os.clock() < deadline and not battle.Over do
		local ready = true
		for _, side in battle.Sides do
			if not side.Action then
				ready = false
			end
		end
		if ready then
			return
		end
		task.wait(0.1)
	end
	-- Wer nicht rechtzeitig waehlt, greift automatisch an
	for index, side in battle.Sides do
		if not side.Action then
			side.Action = { Kind = "Move", Key = bestMove(active(side), active(battle.Sides[3 - index]), 0) }
		end
	end
end

local finish -- weiter unten

local function xpFor(defeated): number
	local rarity = Config.RaritiesByName[Config.BeastsById[defeated.Id].Rarity]
	return defeated.Level * 14 * rarity.Xp
end

-- Bestie der Seite ist besiegt: XP fuer den Gegner merken, naechste schicken oder Kampf beenden
local function handleFaint(battle, sideIndex: number, events)
	local side = battle.Sides[sideIndex]
	local other = battle.Sides[3 - sideIndex]
	local fallen = active(side)
	table.insert(events, { T = "Faint", Side = sideIndex })
	if other.Player and battle.Kind ~= "Duel" then
		local amount = xpFor(fallen)
		for index, fighter in other.Fighters do
			if fighter.Uid then
				local share = if index == other.Active then 1 elseif other.Seen[index] then 0.6 else 0.3
				other.Xp[fighter.Uid] = (other.Xp[fighter.Uid] or 0) + amount * share
			end
		end
	end
	local nextIndex = nextHealthy(side)
	if nextIndex then
		side.Active = nextIndex
		if side.Seen then
			side.Seen[nextIndex] = true
		end
		side.Action = nil
		local model = spawnModel(battle, side, sideIndex)
		table.insert(events, { T = "Send", Side = sideIndex, Fighter = summary(active(side)), Index = nextIndex, Model = model })
		return
	end
	-- Gauntlet: naechste Welle statt Ende
	if battle.Kind == "Gauntlet" and sideIndex == 2 then
		battle.Coins += Config.GauntletCoinsPerWave * battle.Wave
		battle.WavesWon += 1
		battle.Wave += 1
		local newSide = aiSide(`Gauntlet Wave {battle.Wave}`, gauntletTeam(battle.Wave), side.Anchor)
		side.Fighters = newSide.Fighters
		side.Name = newSide.Name
		side.Active = 1
		side.Action = nil
		local model = spawnModel(battle, side, sideIndex)
		local fighters = {}
		for _, fighter in side.Fighters do
			table.insert(fighters, summary(fighter))
		end
		table.insert(events, { T = "Wave", Side = sideIndex, Wave = battle.Wave, Fighters = fighters, Model = model, Name = side.Name })
		return
	end
	battle.Winner = 3 - sideIndex
end

local function resolveTurn(battle)
	local events = {}
	local services = BattleService.Services

	-- 1) Flucht, Wechsel, Gegenstaende, Fangen (vor den Angriffen)
	for index, side in battle.Sides do
		local action = side.Action
		if battle.Winner or battle.Result then
			break
		end
		if action.Kind == "Run" then
			table.insert(events, { T = "Run", Side = index })
			battle.Result = if battle.Kind == "Wild" then "Run" else "Forfeit"
			battle.Winner = 3 - index
		elseif action.Kind == "Swap" then
			side.Active = action.Index
			if side.Seen then
				side.Seen[action.Index] = true
			end
			local model = spawnModel(battle, side, index)
			table.insert(events, { T = "Send", Side = index, Fighter = summary(active(side)), Index = action.Index, Model = model })
		elseif action.Kind == "Item" then
			local item = Config.Items[action.Key]
			if side.Player and services.BeastService:UseItem(side.Player, action.Key) then
				if item.Heal then
					local fighter = active(side)
					fighter.Hp = math.min(fighter.MaxHp, fighter.Hp + math.ceil(fighter.MaxHp * item.Heal))
					table.insert(events, { T = "Item", Side = index, Item = action.Key, Hp = fighter.Hp })
				elseif item.Catch then
					local target = active(battle.Sides[3 - index])
					local chance = Config.CatchChance(target.Id, target.Hp / target.MaxHp, item.Catch, luckFor(side.Player))
					local success = random:NextNumber() < chance
					local shakes = if success then 3 else math.clamp(math.floor(chance * 4 + random:NextNumber() * 1.5), 0, 2)
					table.insert(events, { T = "Catch", Side = index, Item = action.Key, Shakes = shakes, Success = success })
					if success then
						battle.Result = "Caught"
						battle.Winner = index
						-- Gefangene Bestie zaehlt auch fuer XP
						local amount = xpFor(target) * 0.8
						for i, fighter in side.Fighters do
							if fighter.Uid then
								side.Xp[fighter.Uid] = (side.Xp[fighter.Uid] or 0) + amount * (if i == side.Active then 1 else 0.3)
							end
						end
					else
						side.FailedCatches = (side.FailedCatches or 0) + 1
					end
				end
			end
		end
	end
	if battle.Winner then
		return events
	end

	-- 2) Angriffe nach Tempo
	local order = {}
	for index, side in battle.Sides do
		if side.Action and side.Action.Kind == "Move" then
			table.insert(order, index)
		end
	end
	table.sort(order, function(a, b)
		local spdA, spdB = active(battle.Sides[a]).Spd, active(battle.Sides[b]).Spd
		if spdA == spdB then
			return a < b
		end
		return spdA > spdB
	end)
	for _, index in order do
		if battle.Winner then
			break
		end
		local side = battle.Sides[index]
		local action = side.Action
		if action and action.Kind == "Move" then
			local targetIndex = 3 - index
			local attacker = active(side)
			local defender = active(battle.Sides[targetIndex])
			if attacker.Hp > 0 and defender.Hp > 0 then
				local key = action.Key
				if key == "Ultimate" then
					if attacker.Ult <= 0 then
						key = "Strike"
					else
						attacker.Ult -= 1
					end
				end
				local damage, effect, crit, miss = computeDamage(attacker, defender, key)
				defender.Hp = math.max(0, defender.Hp - damage)
				local move = Config.MoveInfo(attacker.Id, key)
				table.insert(events, {
					T = "Move",
					Side = index,
					Target = targetIndex,
					Name = move.Name,
					Type = move.Type,
					Ultimate = key == "Ultimate",
					Damage = damage,
					Eff = effect,
					Crit = crit,
					Miss = miss,
					Hp = defender.Hp,
				})
				if defender.Hp <= 0 then
					handleFaint(battle, targetIndex, events)
				end
			end
		end
	end
	return events
end

-- Abspielzeit der Ereignisse auf dem Client (damit die naechste Runde nicht zu frueh kommt)
local function playTime(events): number
	local total = 0.4
	for _, event in events do
		total += if event.T == "Catch" then 3.2 elseif event.T == "Move" then 1.5 elseif event.T == "Wave" then 2 else 1
	end
	return total
end

runBattle = function(battle)
	task.wait(2.2) -- Einblendung
	while not battle.Over do
		battle.Turn += 1
		requestActions(battle)
		waitForActions(battle)
		if battle.Over then
			break
		end
		local events = resolveTurn(battle)
		sendAll(battle, "Events", { Id = battle.Id, Events = events })
		task.wait(playTime(events))
		if battle.Winner then
			finish(battle)
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
			local data = services.DataService:Get(player)
			if data then
				-- Gesundheit zurueckschreiben (Duelle kosten keine Gesundheit)
				if battle.Kind ~= "Duel" then
					for _, fighter in side.Fighters do
						local entry = fighter.Uid and data.Beasts[fighter.Uid]
						if entry and entry.S == fighter.Id then
							entry.Hp = fighter.Hp
						end
					end
				end
				local won = battle.Winner == index
				local result = if battle.Result == "Run" then "Run" elseif won then (if battle.Result == "Caught" then "Caught" else "Win") else "Lose"
				local report = { Id = battle.Id, Kind = battle.Kind, Result = result, Coins = 0, Xp = {}, Events = {} }
				local coinMult = services.MonetizationService:CoinMultiplier(player)
				local xpMult = services.MonetizationService:XpMultiplier(player)
				local enemy = battle.Sides[3 - index]

				-- XP auch bei Niederlage (Fortschritt fuehlt sich nie verschwendet an)
				for uid, amount in side.Xp or {} do
					local gain = math.floor(amount * xpMult)
					local entry = data.Beasts[uid]
					if entry and gain > 0 then
						table.insert(report.Xp, { Id = entry.S, Amount = gain })
						for _, event in services.BeastService:GiveXp(player, uid, gain) do
							table.insert(report.Events, event)
						end
					end
				end

				local coins = 0
				if battle.Kind == "Wild" and won then
					coins = 6 + active(enemy).Level * 4
					data.Wins += 1
				elseif battle.Kind == "Champion" then
					local champion = Config.Champions[battle.Champion]
					if won then
						local first = battle.Champion == data.Crests + 1
						coins = if first then champion.Coins else math.floor(champion.Coins * Config.ChampionRematch)
						data.Wins += 1
						if first then
							data.Crests += 1
							report.Crest = battle.Champion
							services.Net.SendAnnounce(`{player.DisplayName} defeated {champion.Name} and earned the {champion.Title} Crest!`, GOLD)
						end
					else
						services.MonetizationService:Offer(player, "SkipChampion", `{champion.Name} is tough! Earn the crest instantly?`, true)
					end
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
					if not won and result ~= "Run" then
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
					else
						data.Trophies = math.max(0, data.Trophies - 3)
						report.Trophies = -3
					end
				end
				if battle.Kind == "Wild" and battle.Result == "Caught" and won then
					local wild = active(enemy)
					local uid = services.BeastService:Add(player, wild.Id, wild.Level, wild.Shiny, math.max(1, wild.Hp))
					if uid then
						report.Caught = { Id = wild.Id, Level = wild.Level, Shiny = wild.Shiny }
						coins = 6 + wild.Level * 4
						local rarity = Config.RaritiesByName[Config.BeastsById[wild.Id].Rarity]
						if rarity.Announce or wild.Shiny then
							services.Net.SendAnnounce(`{player.DisplayName} caught a {if wild.Shiny then "PRISMATIC " else ""}{Config.BeastsById[wild.Id].Name}!`, if wild.Shiny then services.BeastService.PrismColor else GOLD)
						end
					end
				end
				-- Fehlwuerfe auf seltene Bestien: Master Orb anbieten
				if battle.Kind == "Wild" and not won and (side.FailedCatches or 0) >= 1 then
					services.MonetizationService:Offer(player, "MasterOrb1", "It got away! A Master Orb ALWAYS catches.", true)
				elseif battle.Kind == "Wild" and (side.FailedCatches or 0) >= 2 then
					local rarity = Config.RaritiesByName[Config.BeastsById[active(enemy).Id].Rarity]
					if rarity.Index >= 2 then
						services.MonetizationService:Offer(player, "MasterOrb1", "Tough catch? A Master Orb ALWAYS catches.")
					end
				end
				if coins > 0 then
					coins = math.floor(coins * coinMult)
					services.DataService:AddCoins(player, coins)
					report.Coins = coins
				end
				if not won and battle.Kind == "Wild" and result == "Lose" then
					services.MonetizationService:Offer(player, "FullHeal", "Your team needs a rest! Heal everyone right here?")
				end
				services.DataService:UpdateAttributes(player)
				services.BeastService:Sync(player)
				services.Net.Battle:FireClient(player, "End", report)
			end
			task.delay(0.5, freeze, player, false)
		end
	end

	-- Wilde Bestie: gefangen/besiegt -> verschwindet, sonst wieder frei
	if battle.Entity then
		local wildWon = battle.Winner == 2
		services.WildService:Release(battle.Entity, if wildWon or battle.Result == "Run" then "Free" else "Gone")
	end
	if battle.Slot then
		services.WorldService:ReleaseArenaSlot(battle.Slot)
	end
	task.delay(2.5, function()
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
		local sideIndex = if battle.Sides[1].Player == player then 1 else 2
		local side = battle.Sides[sideIndex]
		if side.Action then
			return
		end
		local fighter = active(side)
		if action.Kind == "Move" then
			if typeof(action.Key) == "string" and table.find(fighter.Moves, action.Key) and (action.Key ~= "Ultimate" or fighter.Ult > 0) then
				side.Action = { Kind = "Move", Key = action.Key }
			end
		elseif action.Kind == "Swap" then
			local index = tonumber(action.Index)
			local target = index and side.Fighters[index]
			if target and index ~= side.Active and target.Hp > 0 then
				side.Action = { Kind = "Swap", Index = index }
			end
		elseif action.Kind == "Item" then
			local item = typeof(action.Key) == "string" and Config.Items[action.Key]
			local data = services.DataService:Get(player)
			if item and data and (data.Items[action.Key] or 0) > 0 then
				if item.Catch and battle.Kind ~= "Wild" then
					return
				end
				if item.Heal and fighter.Hp >= fighter.MaxHp then
					return
				end
				side.Action = { Kind = "Item", Key = action.Key }
			elseif item and item.Catch == math.huge then
				services.MonetizationService:PromptProduct(player, "MasterOrb1")
			end
		elseif action.Kind == "Run" then
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

	services.Net.ArenaChallenge.OnServerEvent:Connect(function(player, which)
		if which == "Gauntlet" then
			self:StartGauntlet(player)
		elseif typeof(which) == "number" then
			self:StartChampion(player, math.floor(which))
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
}

return BattleService
