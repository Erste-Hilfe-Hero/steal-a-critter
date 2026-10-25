-- Neue Features: Erfolge, Codes, taegliches Gluecksrad, Rang-Punkte, Match-Verlauf, persoenliche Rekorde,
-- MVP des Matches, Wochen-Herausforderung, Muenzen und Power-Orbs auf dem Feld, Abstimmung ueber den
-- naechsten Spielmodus, Schnell-Chat, Freunde-Bonus, Torjubel-Effekte und die Anleitung fuer Neue.
-- Alle Hooks aus anderen Services laufen geschuetzt (pcall), damit ein Fehler hier nie ein Tor oder Match kaputt macht.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local FeaturesService = { Services = nil :: any }

local C = Config.Colors
local HALF_L = Config.FieldLength / 2
local HALF_W = Config.FieldWidth / 2

local remote: RemoteEvent
local baseGravity = 196.2
local currentMode = "Classic"
local voteOpen = false
local votes = {} -- [Player] = Modus-Id
local matchPoints = {} -- [actor] = { Points, Name, Player, Goals, Assists, KOs }
local pickupFolder: Folder
local pickups = {} -- [BasePart] = { Kind = "Coin" | Orb-Id, Expires = number }
local nextCoinAt = 0
local nextOrbAt = 0
local lastAction = {} -- [Player] = { [Aktion] = os.clock() }
local friendPairs = {} -- ["kleinere_groessere"] = true/false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function services()
	return FeaturesService.Services
end

local function data(player: Player?)
	return player and services().DataService:Get(player)
end

local function notify(player: Player?, text: string, color: Color3?)
	if player and player.Parent then
		services().Net.SendNotify(player, text, color or C.Gold)
	end
end

local function send(player: Player, kind: string, info: any)
	if player.Parent then
		remote:FireClient(player, kind, info)
	end
end

-- Fehler in einem Hook nur melden, nie weiterreichen
local function safe(name: string, fn: (...any) -> ...any, ...: any): ...any
	local result = table.pack(pcall(fn, ...))
	if not result[1] then
		warn(`[Features] {name}: {result[2]}`)
		return nil
	end
	return table.unpack(result, 2, result.n)
end

-- Einfache Drossel gegen Remote-Spam: true, wenn die Aktion erlaubt ist
local function throttle(player: Player, action: string, seconds: number): boolean
	local list = lastAction[player]
	if not list then
		list = {}
		lastAction[player] = list
	end
	local t = os.clock()
	if t - (list[action] or -math.huge) < seconds then
		return false
	end
	list[action] = t
	return true
end

local function dayNumber(): number
	return os.time() // 86400
end

-- Wochen beginnen am Montag (Tag 0 der Unix-Zeit war ein Donnerstag)
local function weekNumber(): number
	return (dayNumber() + 3) // 7
end

local function weeklyDef(week: number)
	local random = Random.new(week * 7919 + 17)
	return Config.WeeklyChallenges[random:NextInteger(1, #Config.WeeklyChallenges)]
end

local function ensureWeekly(d)
	local week = weekNumber()
	if type(d.Weekly) ~= "table" or d.Weekly.Week ~= week then
		d.Weekly = { Week = week, Progress = 0, Done = false }
	end
end

local function statValue(d, stat: string): number
	if stat == "Level" then
		return d.Level or 1
	end
	return d[stat] or 0
end

---------------------------------------------------------------- Zustand an den Client

local function buildState(player: Player)
	local d = data(player)
	if not d then
		return nil
	end
	ensureWeekly(d)
	local achievements = {}
	for _, def in Config.Achievements do
		table.insert(achievements, {
			Id = def.Id,
			Name = def.Name,
			Stat = def.Stat,
			Need = def.Need,
			Coins = def.Coins,
			Value = math.min(statValue(d, def.Stat), def.Need),
			Done = d.Achievements[def.Id] == true,
		})
	end
	local weekly = weeklyDef(d.Weekly.Week)
	local nextWeekStart = ((d.Weekly.Week + 1) * 7 - 3) * 86400
	return {
		Achievements = achievements,
		Weekly = {
			Text = string.format(weekly.Text, weekly.Goal),
			Progress = math.min(d.Weekly.Progress, weekly.Goal),
			Goal = weekly.Goal,
			Coins = weekly.Coins,
			Done = d.Weekly.Done,
			EndsIn = math.max(0, nextWeekStart - os.time()),
		},
		Rating = d.Rating,
		MVPs = d.MVPs,
		Records = d.Records,
		History = d.History,
		SpinFree = d.LastSpin ~= dayNumber(),
		Celebrations = { Owned = d.Celebrations, Equipped = d.Celebration },
		Mode = currentMode,
		VoteOpen = voteOpen,
	}
end

local function sendState(player: Player)
	local state = buildState(player)
	if state then
		send(player, "State", state)
	end
end

---------------------------------------------------------------- Erfolge und Wochen-Herausforderung

local function checkAchievements(player: Player)
	local d = data(player)
	if not d or not player.Parent then
		return
	end
	local unlocked = false
	for _, def in Config.Achievements do
		if not d.Achievements[def.Id] and statValue(d, def.Stat) >= def.Need then
			d.Achievements[def.Id] = true
			unlocked = true
			services().ProgressService:AddCoins(player, def.Coins, true)
			notify(player, `ACHIEVEMENT: {string.upper(def.Name)}!  +{def.Coins} coins`, C.Gold)
			send(player, "Achievement", { Name = def.Name, Coins = def.Coins })
		end
	end
	if unlocked then
		sendState(player)
	end
end

-- Aus ExtrasService:Progress: dieselben Ereignisse wie bei den Tages-Quests
function FeaturesService:OnEvent(player: Player?, event: string, amount: number)
	safe("OnEvent", function()
		local d = data(player)
		if not player or not d then
			return
		end
		ensureWeekly(d)
		local def = weeklyDef(d.Weekly.Week)
		if def.Event == event and not d.Weekly.Done then
			d.Weekly.Progress += amount
			if d.Weekly.Progress >= def.Goal then
				d.Weekly.Done = true
				services().ProgressService:AddCoins(player, def.Coins, true)
				notify(player, `WEEKLY CHALLENGE DONE!  +{def.Coins} coins`, C.Gold)
				send(player, "Achievement", { Name = "Weekly Challenge", Coins = def.Coins })
			end
		end
		-- Karriere-Werte werden erst nach dem Ereignis erhoeht: danach pruefen
		task.defer(checkAchievements, player)
	end)
end

---------------------------------------------------------------- MVP, Rekorde, Torjubel

function FeaturesService:Track(actor, kind: string)
	if not actor then
		return
	end
	safe("Track", function()
		local entry = matchPoints[actor]
		if not entry then
			entry = { Points = 0, Name = actor.Name, Player = actor.Player, Goals = 0, Assists = 0, KOs = 0 }
			matchPoints[actor] = entry
		end
		entry.Points += Config.MVPPoints[kind] or 0
		if kind == "Goal" then
			entry.Goals += 1
		elseif kind == "Assist" then
			entry.Assists += 1
		elseif kind == "KO" then
			entry.KOs += 1
		end
	end)
end

local function newRecord(player: Player, key: string, value: number, text: string)
	local d = data(player)
	if not d then
		return
	end
	local old = d.Records[key] or 0
	if value > old then
		d.Records[key] = value
		-- Der allererste Wert ist noch kein "Rekord", sonst kaeme die Meldung bei jedem Neuling
		if old > 0 then
			notify(player, `NEW RECORD! {text}`, C.Cyan)
		end
	end
end

function FeaturesService:OnShot(player: Player, kmh: number)
	safe("OnShot", newRecord, player, "ShotSpeed", kmh, `Hardest shot: {kmh} km/h`)
end

-- Torjubel-Effekt: Partikel rund um den Torschuetzen (gekaufter Stil)
local function celebrationEffect(actor)
	local d = data(actor.Player)
	local def = d and Config.CelebrationsById[d.Celebration or "none"]
	if not def or def.Id == "none" or not actor.Root.Parent then
		return
	end
	local keypoints = {}
	for i, color in def.Colors do
		table.insert(keypoints, ColorSequenceKeypoint.new(if #def.Colors == 1 then 0 else (i - 1) / (#def.Colors - 1), color))
	end
	if #keypoints == 1 then
		table.insert(keypoints, ColorSequenceKeypoint.new(1, def.Colors[1]))
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "Celebration"
	attachment.Position = Vector3.new(0, 1, 0)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(keypoints)
	emitter.LightEmission = if def.Id == "confetti" then 0.2 else 0.8
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 70
	if def.Id == "confetti" then
		emitter.Size = NumberSequence.new(0.5, 0.4)
		emitter.Speed = NumberRange.new(18, 30)
		emitter.Acceleration = Vector3.new(0, -25, 0)
		emitter.Lifetime = NumberRange.new(1.5, 2.5)
		emitter.RotSpeed = NumberRange.new(-200, 200)
		emitter.Drag = 1
	elseif def.Id == "stars" then
		emitter.Size = NumberSequence.new(1.2, 0)
		emitter.Speed = NumberRange.new(10, 20)
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.Rotation = NumberRange.new(0, 360)
	elseif def.Id == "flames" then
		emitter.Size = NumberSequence.new(1.6, 0)
		emitter.Speed = NumberRange.new(8, 16)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Lifetime = NumberRange.new(0.8, 1.4)
	elseif def.Id == "lightning" then
		emitter.Size = NumberSequence.new(0.6, 0)
		emitter.Speed = NumberRange.new(40, 60)
		emitter.Lifetime = NumberRange.new(0.3, 0.6)
		emitter.Squash = NumberSequence.new(3)
	else
		emitter.Size = NumberSequence.new(0.9, 0.2)
		emitter.Speed = NumberRange.new(4, 10)
		emitter.Lifetime = NumberRange.new(2, 3)
		emitter.RotSpeed = NumberRange.new(-90, 90)
	end
	-- Rate statt Emit(): eine Eigenschaft repliziert sicher zu allen Clients
	emitter.Parent = attachment
	attachment.Parent = actor.Root
	task.delay(2.5, function()
		emitter.Enabled = false
		task.wait(3)
		attachment:Destroy()
	end)
end

function FeaturesService:OnGoal(scorer, assist, distance: number?)
	if scorer then
		self:Track(scorer, "Goal")
	end
	if assist then
		self:Track(assist, "Assist")
	end
	safe("OnGoal", function()
		if scorer and scorer.Player then
			if distance then
				newRecord(scorer.Player, "GoalDistance", math.floor(distance), `Longest goal: {math.floor(distance)} studs`)
			end
			celebrationEffect(scorer)
		end
	end)
end

---------------------------------------------------------------- Spielmodus-Abstimmung

local function voteCounts()
	local counts = {}
	for _, mode in Config.Modes do
		counts[mode.Id] = 0
	end
	for player, id in votes do
		if player.Parent and counts[id] then
			counts[id] += 1
		end
	end
	return counts
end

-- Modus mit den meisten Stimmen (Gleichstand: Zufall unter den Besten, keine Stimmen: Classic)
function FeaturesService:PickMode(counts: { [string]: number }): string
	local best, list = 0, {}
	for _, mode in Config.Modes do
		local n = counts[mode.Id] or 0
		if n > best then
			best, list = n, { mode.Id }
		elseif n == best and n > 0 then
			table.insert(list, mode.Id)
		end
	end
	if #list == 0 then
		return "Classic"
	end
	return list[math.random(1, #list)]
end

function FeaturesService:ApplyMode(id: string)
	local mode = Config.ModesById[id] or Config.ModesById.Classic
	currentMode = mode.Id
	workspace.Gravity = mode.Gravity or baseGravity
	workspace:SetAttribute("ModeSpeed", mode.Speed or 1)
	workspace:SetAttribute("ScoreLimit", mode.ScoreLimit or Config.ScoreLimit)
	workspace:SetAttribute("Mode", mode.Id)
	if mode.Id ~= "Classic" then
		services().Net.SendAnnounce(`{mode.Name} MATCH! {mode.Text}`, C.Cyan)
	end
end

function FeaturesService:GetMode(): string
	return currentMode
end

---------------------------------------------------------------- Pickups auf dem Feld (Muenzen und Power-Orbs)

local function clearPickups()
	for part in pickups do
		part:Destroy()
	end
	table.clear(pickups)
end

local function randomSpot(): Vector3
	local random = Random.new()
	return Vector3.new(random:NextNumber(-HALF_L + 50, HALF_L - 50), Config.GroundY + 2.6, random:NextNumber(-HALF_W + 15, HALF_W - 15))
end

local function spawnCoin()
	local coin = Instance.new("Part")
	coin.Name = "CoinDrop"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.6, 3.4, 3.4)
	coin.Color = C.Gold
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false
	coin.CanTouch = false
	coin.CFrame = CFrame.new(randomSpot())
	coin:SetAttribute("Kind", "Coin")
	local light = Instance.new("PointLight")
	light.Color = C.Gold
	light.Range = 8
	light.Parent = coin
	coin.Parent = pickupFolder
	pickups[coin] = { Kind = "Coin", Expires = os.clock() + Config.CoinDropLife }
end

local function spawnOrb()
	local def = Config.Orbs[math.random(1, #Config.Orbs)]
	local orb = Instance.new("Part")
	orb.Name = "PowerOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(3, 3, 3)
	orb.Color = def.Color
	orb.Material = Enum.Material.Neon
	orb.Transparency = 0.15
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanQuery = false
	orb.CanTouch = false
	orb.CFrame = CFrame.new(randomSpot() + Vector3.new(0, 0.6, 0))
	orb:SetAttribute("Kind", def.Id)
	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 12
	light.Brightness = 2
	light.Parent = orb
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(120, 24)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.MaxDistance = 120
	tag.LightInfluence = 0
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Config.Font
	text.TextScaled = true
	text.TextColor3 = def.Color
	text.TextStrokeTransparency = 0.2
	text.Text = def.Name
	text.Parent = tag
	tag.Parent = orb
	orb.Parent = pickupFolder
	pickups[orb] = { Kind = def.Id, Expires = os.clock() + Config.OrbLife }
end

local function collect(part: BasePart, info, actor)
	local player = actor.Player :: Player
	pickups[part] = nil
	local position = part.Position
	part:Destroy()
	services().Net.PlaySound("Quest", position)
	if info.Kind == "Coin" then
		local amount = services().ProgressService:AddCoins(player, math.random(Config.CoinDropValue[1], Config.CoinDropValue[2]))
		notify(player, `+{amount} coins!`, C.Gold)
		return
	end
	if info.Kind == "Speed" then
		player:SetAttribute("SpeedOrbUntil", now() + Config.SpeedOrbSeconds)
	elseif info.Kind == "Power" then
		player:SetAttribute("PowerKick", true)
	elseif info.Kind == "Heal" then
		services().CombatService:Heal(actor)
	end
	for _, def in Config.Orbs do
		if def.Id == info.Kind then
			notify(player, `{def.Name}: {def.Text}`, def.Color)
		end
	end
end

local function pickupTick()
	local match = services().MatchService
	local state = match:GetState()
	if state ~= "Playing" and state ~= "Goal" then
		if next(pickups) then
			clearPickups()
		end
		return
	end
	local t = os.clock()
	for part, info in pickups do
		if t > info.Expires or not part.Parent then
			pickups[part] = nil
			part:Destroy()
		end
	end
	if state == "Playing" then
		local coins, orbs = 0, 0
		for _, info in pickups do
			if info.Kind == "Coin" then
				coins += 1
			else
				orbs += 1
			end
		end
		if t > nextCoinAt then
			nextCoinAt = t + Config.CoinDropEvery
			if coins < Config.CoinDropMax then
				spawnCoin()
			end
		end
		if t > nextOrbAt then
			nextOrbAt = t + Config.OrbEvery
			if orbs == 0 then
				spawnOrb()
			end
		end
	end
	-- Nur echte Spieler sammeln (Bots wuerden sonst alles wegschnappen)
	for _, actor in match:GetActors() do
		if actor.Player and actor.Root.Parent and not services().CombatService:IsKO(actor) then
			for part, info in pickups do
				local offset = part.Position - actor.Root.Position
				if Vector3.new(offset.X, 0, offset.Z).Magnitude < 5 and math.abs(offset.Y) < 7 then
					collect(part, info, actor)
					break
				end
			end
		end
	end
end

-- Power-Orb (naechster Schuss) und Modus "Mega Kicks"
function FeaturesService:KickBonus(actor): number
	local multiplier = (Config.ModesById[currentMode] and Config.ModesById[currentMode].Kick) or 1
	local player = actor.Player
	if player and player:GetAttribute("PowerKick") == true then
		player:SetAttribute("PowerKick", nil)
		multiplier *= Config.PowerOrbFactor
		notify(player, "POWER KICK!", C.Orange)
	end
	return multiplier
end

---------------------------------------------------------------- Match-Anfang und -Ende

function FeaturesService:OnMatchStart()
	safe("OnMatchStart", function()
		local counts = voteCounts()
		voteOpen = false
		table.clear(votes)
		table.clear(matchPoints)
		clearPickups()
		nextCoinAt = os.clock() + 10
		nextOrbAt = os.clock() + 25
		self:ApplyMode(self:PickMode(counts))
		remote:FireAllClients("VoteClosed", currentMode)
	end)
end

local function resultFor(teamName: string, winner: string?): string
	return if winner == nil then "Draw" elseif winner == teamName then "Win" else "Loss"
end

-- Gibt die MVP-Zeile fuer die Auszeichnungen zurueck (oder nil)
function FeaturesService:OnMatchEnd(winner: string?, blue: number, red: number): string?
	return safe("OnMatchEnd", function()
		-- MVP: meiste Punkte aus Toren, Vorlagen, Paraden, Steals und K.O.s (auch Bots koennen MVP sein)
		local best = nil
		for _, entry in matchPoints do
			if entry.Points > 0 and (not best or entry.Points > best.Points) then
				best = entry
			end
		end
		local mvpText = nil
		if best then
			local points = if best.Points % 1 == 0 then tostring(best.Points) else string.format("%.1f", best.Points)
			mvpText = `MVP: {best.Name} ({points} pts)`
			-- erst nach der Endstand-Einblendung, sonst wuerde sie sofort ueberschrieben
			local name = best.Name
			task.delay(5.5, function()
				services().Net.SendAnnounce(`MVP OF THE MATCH: {name}!`, C.Gold)
			end)
			local player = best.Player
			local d = data(player)
			if player and player.Parent and d then
				d.MVPs += 1
				services().ProgressService:AddCoins(player, Config.MVPCoins, true)
				notify(player, `YOU ARE THE MVP!  +{Config.MVPCoins} coins`, C.Gold)
			end
		end

		-- Pro Spieler: Rang-Punkte, Verlauf, Match-Rekorde
		for _, player in Players:GetPlayers() do
			local teamName = player:GetAttribute("Team")
			local d = data(player)
			if teamName and d then
				local result = resultFor(teamName, winner)
				local change = Config.RatingChange[result] or 0
				local before = Config.RankFor(d.Rating)
				d.Rating = math.max(0, d.Rating + change)
				local after = Config.RankFor(d.Rating)
				player:SetAttribute("Rating", d.Rating)
				notify(player, `RATING {if change >= 0 then "+" else ""}{change}  ({string.upper(after.Name)} {d.Rating})`, after.Color)
				if after.Min > before.Min then
					task.delay(8, function()
						services().Net.SendAnnounce(`{player.DisplayName} reached {string.upper(after.Name)} rank!`, after.Color)
					end)
				end
				local goals, assists, kos = 0, 0, 0
				for _, entry in matchPoints do
					if entry.Player == player then
						goals += entry.Goals
						assists += entry.Assists
						kos += entry.KOs
					end
				end
				local own, other = if teamName == "Blue" then blue else red, if teamName == "Blue" then red else blue
				table.insert(d.History, 1, { R = result, S = `{own}-{other}`, G = goals, A = assists, K = kos })
				while #d.History > 8 do
					table.remove(d.History)
				end
				newRecord(player, "MatchGoals", goals, `Most goals in a match: {goals}`)
				newRecord(player, "MatchKOs", kos, `Most knockouts in a match: {kos}`)
				task.defer(checkAchievements, player)
				sendState(player)
			end
		end

		-- Abstimmung fuer den naechsten Modus oeffnen
		voteOpen = true
		table.clear(votes)
		remote:FireAllClients("VoteOpen", voteCounts())
		return mvpText
	end)
end

---------------------------------------------------------------- Freunde-Bonus

local function pairKey(a: number, b: number): string
	return if a < b then `{a}_{b}` else `{b}_{a}`
end

local function refreshFriendBonus()
	local list = Players:GetPlayers()
	for _, player in list do
		local bonus = false
		for _, other in list do
			if other ~= player and friendPairs[pairKey(player.UserId, other.UserId)] then
				bonus = true
				break
			end
		end
		local had = player:GetAttribute("FriendBonus") == true
		player:SetAttribute("FriendBonus", bonus)
		if bonus and not had then
			notify(player, `FRIEND BONUS: +{math.floor((Config.FriendBonus - 1) * 100 + 0.5)}% coins while you play with friends!`, C.Lime)
		end
	end
end

local function checkFriends(player: Player)
	for _, other in Players:GetPlayers() do
		if other ~= player and player.UserId > 0 and other.UserId > 0 then
			local key = pairKey(player.UserId, other.UserId)
			if friendPairs[key] == nil then
				local ok, result = pcall(player.IsFriendsWith, player, other.UserId)
				friendPairs[key] = ok and result == true
			end
		end
	end
	refreshFriendBonus()
end

---------------------------------------------------------------- Aktionen vom Client

local function redeem(player: Player, code: string)
	local d = data(player)
	if not d then
		return
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local def = Config.Codes[code]
	if not def then
		send(player, "Redeemed", { Ok = false, Text = "Invalid code" })
		return
	end
	if d.Codes[code] then
		send(player, "Redeemed", { Ok = false, Text = "Already redeemed" })
		return
	end
	d.Codes[code] = true
	local parts = {}
	if def.Coins then
		services().ProgressService:AddCoins(player, def.Coins, true)
		table.insert(parts, `+{def.Coins} coins`)
	end
	if def.RocketShots then
		d.RocketShots = (d.RocketShots or 0) + def.RocketShots
		player:SetAttribute("RocketShots", d.RocketShots)
		table.insert(parts, `{def.RocketShots} Rocket Shots`)
	end
	local text = table.concat(parts, ", ")
	send(player, "Redeemed", { Ok = true, Text = "Redeemed: " .. text })
	notify(player, `CODE {code}: {text}`, C.Lime)
end

-- Gewichtete Ziehung; random ist austauschbar (Smoke-Test)
function FeaturesService:RollSpin(random: Random?): number
	local rng = random or Random.new()
	local total = 0
	for _, prize in Config.SpinPrizes do
		total += prize.Weight
	end
	local roll = rng:NextNumber() * total
	for index, prize in Config.SpinPrizes do
		roll -= prize.Weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

local function spin(player: Player, paid: boolean)
	local d = data(player)
	if not d then
		return
	end
	local today = dayNumber()
	if d.LastSpin == today then
		if not paid then
			send(player, "SpinResult", { Ok = false, Text = "Free spin used. Come back tomorrow!" })
			return
		end
		if d.Coins < Config.SpinPrice then
			send(player, "SpinResult", { Ok = false, Text = "Not enough coins!" })
			services().Net.Offer:FireClient(player, "Coins")
			return
		end
		d.Coins -= Config.SpinPrice
	else
		d.LastSpin = today
	end
	local index = FeaturesService:RollSpin()
	local prize = Config.SpinPrizes[index]
	if prize.Coins then
		services().ProgressService:AddCoins(player, prize.Coins, true)
	end
	if prize.RocketShots then
		d.RocketShots = (d.RocketShots or 0) + prize.RocketShots
		player:SetAttribute("RocketShots", d.RocketShots)
	end
	if prize.BoostMinutes then
		d.BoostUntil = math.max(os.time(), d.BoostUntil) + prize.BoostMinutes * 60
	end
	services().ProgressService:Refresh(player)
	send(player, "SpinResult", { Ok = true, Index = index, Text = prize.Text })
	sendState(player)
end

local function celebrationAction(player: Player, id: string)
	local d = data(player)
	local def = Config.CelebrationsById[id]
	if not d or not def then
		return
	end
	if not d.Celebrations[id] then
		if d.Coins < def.Price then
			services().Net.Offer:FireClient(player, "Coins")
			return
		end
		d.Coins -= def.Price
		d.Celebrations[id] = true
		notify(player, `New celebration: {def.Name}!`, C.Lime)
	end
	d.Celebration = id
	services().ProgressService:Refresh(player)
	sendState(player)
end

local function quickChat(player: Player, index: number)
	local text = Config.QuickChat[index]
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local teamName = player:GetAttribute("Team")
	if not text or not head or not teamName then
		return
	end
	local old = head:FindFirstChild("QuickChat")
	if old then
		old:Destroy()
	end
	local color = Config.Teams[teamName] and Config.Teams[teamName].Color or C.White
	local gui = Instance.new("BillboardGui")
	gui.Name = "QuickChat"
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffset = Vector3.new(0, 6.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.LightInfluence = 0
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	bubble.Font = Config.Font
	bubble.TextScaled = true
	bubble.TextColor3 = color
	bubble.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = bubble
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 3)
	padding.PaddingBottom = UDim.new(0, 3)
	padding.Parent = bubble
	bubble.Parent = gui
	gui.Parent = head
	task.delay(2.5, function()
		gui:Destroy()
	end)
	-- Mitspieler sehen den Spruch auch als Meldung (wichtig in der Ego-Sicht)
	for _, mate in Players:GetPlayers() do
		if mate ~= player and mate:GetAttribute("Team") == teamName then
			notify(mate, `{player.DisplayName}: {text}`, color)
		end
	end
	services().Net.PlaySound("Call", head.Position, 1.1, 0.6)
end

---------------------------------------------------------------- Start

function FeaturesService:Init(svc)
	self.Services = svc
	remote = Instance.new("RemoteEvent")
	remote.Name = "Features"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	baseGravity = workspace.Gravity
	workspace:SetAttribute("Mode", "Classic")
	workspace:SetAttribute("ModeSpeed", 1)
end

function FeaturesService:OnPlayerReady(player: Player)
	local d = data(player)
	if not d then
		return
	end
	ensureWeekly(d)
	player:SetAttribute("Rating", d.Rating)
	sendState(player)
	if not d.TutorialDone then
		task.delay(3, function()
			send(player, "Tutorial", true)
		end)
	end
	if voteOpen then
		send(player, "VoteOpen", voteCounts())
	end
	task.defer(checkAchievements, player)
	task.spawn(checkFriends, player)
end

function FeaturesService:Start()
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "Pickups"
	pickupFolder.Parent = workspace

	task.spawn(function()
		while true do
			task.wait(0.2)
			safe("pickupTick", pickupTick)
		end
	end)

	remote.OnServerEvent:Connect(function(player, action, arg)
		if typeof(action) ~= "string" then
			return
		end
		if action == "Sync" then
			if throttle(player, "Sync", 1) then
				sendState(player)
			end
		elseif action == "Redeem" then
			if typeof(arg) == "string" and #arg <= 30 and throttle(player, "Redeem", 1.5) then
				redeem(player, arg)
			end
		elseif action == "Spin" then
			if throttle(player, "Spin", 2.5) then
				spin(player, arg == true)
			end
		elseif action == "Celebration" then
			if typeof(arg) == "string" and throttle(player, "Celebration", 0.5) then
				celebrationAction(player, arg)
			end
		elseif action == "Chat" then
			if typeof(arg) == "number" and arg == arg and arg % 1 == 0 and throttle(player, "Chat", Config.QuickChatCooldown) then
				quickChat(player, arg)
			end
		elseif action == "Vote" then
			if voteOpen and typeof(arg) == "string" and Config.ModesById[arg] and throttle(player, "Vote", 0.3) then
				votes[player] = arg
				remote:FireAllClients("Votes", voteCounts())
			end
		elseif action == "TutorialDone" then
			local d = data(player)
			if d then
				d.TutorialDone = true
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
		if votes[player] then
			votes[player] = nil
			if voteOpen then
				remote:FireAllClients("Votes", voteCounts())
			end
		end
		for key in friendPairs do
			local a, b = string.match(key, "^(%d+)_(%d+)$")
			if tonumber(a) == player.UserId or tonumber(b) == player.UserId then
				friendPairs[key] = nil
			end
		end
		task.defer(refreshFriendBonus)
	end)
end

return FeaturesService
