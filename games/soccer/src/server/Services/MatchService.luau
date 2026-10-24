-- Teams, Spielablauf (Anstoss -> Spiel -> Tor -> ... -> Ergebnis), Spielstand und Belohnungen.
-- Bots fuellen jedes Team auf, damit man auch allein sofort spielen kann.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Teams = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)

local MatchService = { Services = nil :: any }

local actors = {} -- [Model] = actor
local actorList = {} -- Liste fuer schnelle Schleifen
local teamObjects = {} -- [teamName] = Team
local score = { Blue = 0, Red = 0 }
local state = "Waiting"
local timeLeft = Config.MatchSeconds
local goldenGoal = false
local matchStats = {} -- [Player] = { Goals, Assists, Steals, Saves, XP, Coins, Team }

local GOLD = Config.Colors.Gold

local function rebuildList()
	table.clear(actorList)
	for _, actor in actors do
		table.insert(actorList, actor)
	end
end

local function setState(newState: string, duration: number?)
	state = newState
	workspace:SetAttribute("MatchState", newState)
	workspace:SetAttribute("StateEnds", if duration then workspace:GetServerTimeNow() + duration else 0)
	local board = MatchService.Services.ArenaService.Scoreboard
	if board.Status then
		board.Status.Text = if newState == "Playing" then (if goldenGoal then "GOLDEN GOAL" else "LIVE")
			elseif newState == "Kickoff" then "KICKOFF"
			elseif newState == "Goal" then "GOAL!"
			elseif newState == "Ended" then "FULL TIME"
			else "WAITING FOR PLAYERS"
	end
end

local function updateScore()
	workspace:SetAttribute("ScoreBlue", score.Blue)
	workspace:SetAttribute("ScoreRed", score.Red)
	workspace:SetAttribute("TimeLeft", math.ceil(timeLeft))
	workspace:SetAttribute("GoldenGoal", goldenGoal)
	local board = MatchService.Services.ArenaService.Scoreboard
	if board.Blue then
		board.Blue.Text = tostring(score.Blue)
		board.Red.Text = tostring(score.Red)
		local t = math.max(0, math.ceil(timeLeft))
		board.Time.Text = string.format("%d:%02d", t // 60, t % 60)
	end
end

-- Team-Statistik fuer die TV-Anzeige oben rechts (Ballbesitz, Schuesse, Steals, Saves)
local teamStats = {}
local function resetTeamStats()
	for _, teamName in Config.TeamOrder do
		teamStats[teamName] = { Possession = 0, Shots = 0, Steals = 0, Saves = 0, Smacks = 0, KOs = 0 }
	end
end
resetTeamStats()

local function publishTeamStats()
	local total = 0
	for _, stats in teamStats do
		total += stats.Possession
	end
	for teamName, stats in teamStats do
		local share = if total > 0 then math.floor(stats.Possession / total * 100 + 0.5) else 50
		workspace:SetAttribute(`Stat{teamName}Possession`, share)
		for _, key in { "Shots", "Steals", "Saves", "Smacks", "KOs" } do
			workspace:SetAttribute(`Stat{teamName}{key}`, stats[key])
		end
	end
end

local function countTeam(actor, key: string)
	local stats = actor and teamStats[actor.Team]
	if stats then
		stats[key] += 1
		publishTeamStats()
	end
end

local function statsFor(player: Player)
	local stats = matchStats[player]
	if not stats then
		stats = { Goals = 0, Assists = 0, Steals = 0, Saves = 0, Smacks = 0, KOs = 0, XP = 0, Coins = 0, EXP = 0, Name = player.DisplayName }
		matchStats[player] = stats
	end
	return stats
end

local function reward(actor, kind: string, bonusEXP: number?)
	if not actor or not actor.Player then
		return
	end
	local xp, coins, exp = MatchService.Services.ProgressService:Reward(actor.Player, kind, bonusEXP)
	local stats = statsFor(actor.Player)
	stats.XP += xp
	stats.Coins += coins
	stats.EXP += exp
end

---------------------------------------------------------------- Actors

function MatchService:GetActors()
	return actorList
end

function MatchService:IsActor(actor): boolean
	return actors[actor.Model] == actor
end

function MatchService:ActorForPlayer(player: Player)
	local character = player.Character
	return character and actors[character]
end

function MatchService:Skill(actor, skillId: string): number
	if actor.Player then
		return self.Services.ProgressService:GetSkill(actor.Player, skillId)
	end
	return actor.Skills and actor.Skills[skillId] or 2
end

-- Farbiger Ring unter den Fuessen, damit man die Teams sofort erkennt
local function addRing(actor)
	local old = actor.Model:FindFirstChild("TeamRing")
	if old then
		old:Destroy()
	end
	local ring = Instance.new("Part")
	ring.Name = "TeamRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 5, 5)
	ring.Material = Enum.Material.Neon
	ring.Color = Config.Teams[actor.Team].Color
	ring.Transparency = 0.35
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Massless = true
	ring.CastShadow = false
	ring.CFrame = actor.Root.CFrame * CFrame.new(0, -2.95, 0) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = actor.Root
	weld.Part1 = ring
	weld.Parent = ring
	ring.Parent = actor.Model
end

function MatchService:AddActor(model: Model, team: string, player: Player?, skills, name: string)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return nil
	end
	local actor = {
		Model = model,
		Humanoid = humanoid,
		Root = root,
		Team = team,
		Player = player,
		Skills = skills,
		Name = name,
		Slot = 0,
		StunnedUntil = 0,
	}
	actors[model] = actor
	rebuildList()
	model:SetAttribute("Team", team)
	addRing(actor)
	self.Services.CombatService:Setup(actor)
	self:AssignSlots()
	self:PlaceActor(actor)
	return actor
end

function MatchService:RemoveActor(model: Model)
	local actor = actors[model]
	if not actor then
		return
	end
	actors[model] = nil
	rebuildList()
	self.Services.BallService:Forget(actor)
	self.Services.CombatService:Forget(actor)
	self:AssignSlots()
end

function MatchService:PlaceActor(actor)
	local position = self.Services.ArenaService:FormationPosition(actor.Team, math.max(actor.Slot, 1))
	local target = Vector3.new(-Config.Teams[actor.Team].Side * 50, position.Y, position.Z)
	actor.Model:PivotTo(CFrame.lookAt(position, target))
	actor.Root.AssemblyLinearVelocity = Vector3.zero
end

-- Slots je Team: Bots bekommen zuerst den Torwart-Platz (Spieler wollen lieber stuermen)
function MatchService:AssignSlots()
	for teamName in Config.Teams do
		local bots, humans = {}, {}
		for _, actor in actorList do
			if actor.Team == teamName then
				table.insert(if actor.Player then humans else bots, actor)
			end
		end
		local order = {}
		if #bots > 0 then
			table.insert(order, table.remove(bots, 1))
		end
		for _, a in humans do
			table.insert(order, a)
		end
		for _, a in bots do
			table.insert(order, a)
		end
		-- Ohne Bot im Team: der zuletzt eingeteilte Mensch steht im Tor
		if order[1] and order[1].Player and #order > 1 then
			table.insert(order, 1, table.remove(order))
		end
		for index, actor in order do
			actor.Slot = index
			actor.Model:SetAttribute("Slot", index)
			actor.Model:SetAttribute("Role", Config.Formation[((index - 1) % #Config.Formation) + 1].Role)
		end
	end
end

---------------------------------------------------------------- Teams

local function humanCount(teamName: string): number
	return #teamObjects[teamName]:GetPlayers()
end

function MatchService:AssignTeam(player: Player)
	local bolt, blaze = humanCount("Blue"), humanCount("Red")
	local teamName = if bolt < blaze then "Blue" elseif blaze < bolt then "Red" elseif math.random() < 0.5 then "Blue" else "Red"
	player.Team = teamObjects[teamName]
	player:SetAttribute("Team", teamName)
end

function MatchService:Rebalance()
	local humans = { Blue = humanCount("Blue"), Red = humanCount("Red") }
	local size = math.clamp(math.max(humans.Blue, humans.Red), Config.MinTeamSize, Config.MaxTeamSize)
	if #Players:GetPlayers() == 0 then
		size = 0
	end
	for teamName in Config.Teams do
		self.Services.BotService:SetCount(teamName, math.max(0, size - humans[teamName]))
	end
end

---------------------------------------------------------------- Ereignisse aus dem BallService

function MatchService:OnGoal(scoringTeam: string, scorer, assist, distance: number?)
	if state ~= "Playing" then
		return
	end
	score[scoringTeam] += 1
	updateScore()
	local team = Config.Teams[scoringTeam]
	local scorerName = if scorer then scorer.Name else nil
	local assistName = if assist then assist.Name else nil
	-- Fernschuss-Bonus wie im Original ("GOAL from 85 studs!")
	local bonus = if distance then math.max(0, math.floor(distance) - 40) * Config.GoalDistanceBonus else 0
	if scorer then
		reward(scorer, "Goal", bonus)
		if scorer.Player then
			statsFor(scorer.Player).Goals += 1
			self.Services.ProgressService:AddStat(scorer.Player, "Goals", 1)
		end
	end
	if assist then
		reward(assist, "Assist")
		if assist.Player then
			statsFor(assist.Player).Assists += 1
			self.Services.ProgressService:AddStat(assist.Player, "Assists", 1)
		end
	end
	local colors = if scorer and scorer.Player
		then (Config.TrailsById[scorer.Player:GetAttribute("Trail") or "white"] or Config.Trails[1]).Colors
		else { team.Color, Color3.new(1, 1, 1) }
	local conceding = if scoringTeam == "Blue" then "Red" else "Blue"
	self.Services.ArenaService:Burst(conceding, colors)
	self.Services.Net.MatchEvent:FireAllClients("Goal", {
		Team = scoringTeam,
		Scorer = scorerName,
		Assist = assistName,
		OwnGoal = scorer == nil,
		Distance = if distance then math.floor(distance) else nil,
	})
	if score[scoringTeam] >= Config.ScoreLimit then
		self.ScoreLimitReached = true
	end
	self.GoalScored = true
end

function MatchService:OnShot(actor)
	if state == "Playing" then
		countTeam(actor, "Shots")
	end
end

function MatchService:OnTackle(actor, victim)
	countTeam(actor, "Steals")
	reward(actor, "Steal")
	if actor.Player then
		statsFor(actor.Player).Steals += 1
		self.Services.ProgressService:AddStat(actor.Player, "Steals", 1)
		self.Services.Net.SendNotify(actor.Player, "Ball stolen!", Config.Colors.Lime)
	end
	if victim.Player then
		self.Services.Net.SendNotify(victim.Player, `{actor.Name} took the ball!`, Config.Colors.Orange)
	end
end

-- Messertreffer hat dem Ballfuehrer den Ball aus dem Fuss geschlagen
function MatchService:OnDisarm(actor, victim)
	if actor.Player then
		self.Services.Net.SendNotify(actor.Player, `DISARMED {victim.Name}!`, Config.Colors.Lime)
	end
	if victim.Player then
		self.Services.Net.SendNotify(victim.Player, `{actor.Name} knocked the ball away!`, Config.Colors.Orange)
	end
end

function MatchService:OnTackleMissed(actor, victim)
	if actor.Player then
		self.Services.Net.SendNotify(actor.Player, "Dodged!", Config.Colors.Orange)
	end
	if victim.Player then
		reward(victim, "Dodge")
		self.Services.Net.SendNotify(victim.Player, "Nice dodge!", Config.Colors.Lime)
	end
end

-- Ein harter gegnerischer Schuss hat jemanden umgehauen
function MatchService:OnSmack(kicker, victim)
	countTeam(kicker, "Smacks")
	if kicker then
		reward(kicker, "Smack")
		if kicker.Player then
			statsFor(kicker.Player).Smacks += 1
			self.Services.ProgressService:AddStat(kicker.Player, "Smacks", 1)
			self.Services.Net.SendNotify(kicker.Player, `SMACK! You knocked down {victim.Name}`, Config.Colors.Orange)
		end
	end
	if victim.Player then
		self.Services.Net.SendNotify(victim.Player, "SMACKED by the ball!", Config.Colors.Red)
	end
end

-- Jemand wurde mit dem Messer oder einem Smack K.O. geschlagen
function MatchService:OnKO(attacker, victim, kind: string)
	countTeam(attacker, "KOs")
	if attacker then
		reward(attacker, "KO")
		if attacker.Player then
			statsFor(attacker.Player).KOs += 1
		end
	end
	self.Services.Net.PlaySound("Ooh", victim.Root.Position)
	self.Services.Net.MatchEvent:FireAllClients("KO", {
		Attacker = if attacker then attacker.Name else nil,
		AttackerTeam = if attacker then attacker.Team else nil,
		Victim = victim.Name,
		VictimTeam = victim.Team,
		VictimModel = victim.Model,
		Kind = kind,
	})
end

function MatchService:OnSave(actor)
	countTeam(actor, "Saves")
	self.Services.Net.PlaySound("Save", actor.Root.Position)
	reward(actor, "Save")
	if actor.Player then
		statsFor(actor.Player).Saves += 1
		self.Services.Net.SendNotify(actor.Player, "SAVE!", Config.Colors.Cyan)
	end
end

---------------------------------------------------------------- Ablauf

local function placeAll()
	for _, actor in actorList do
		MatchService:PlaceActor(actor)
		actor.StunnedUntil = 0
		actor.Model:SetAttribute("StunnedUntil", 0)
		MatchService.Services.CombatService:Reset(actor)
	end
end

local function kickoff()
	local ball = MatchService.Services.BallService
	ball.PickupEnabled = false
	ball.GoalsEnabled = false
	ball:Reset()
	placeAll()
	setState("Kickoff", Config.KickoffSeconds)
	task.wait(Config.KickoffSeconds)
	placeAll()
	ball:Unfreeze()
	ball.PickupEnabled = true
	ball.GoalsEnabled = true
	setState("Playing")
end

local function finishMatch()
	local ball = MatchService.Services.BallService
	ball.GoalsEnabled = false
	local winner = if score.Blue > score.Red then "Blue" elseif score.Red > score.Blue then "Red" else nil
	setState("Ended", Config.ResultsSeconds)
	-- Auszeichnungen wie die Endstatistik im Original
	local awards = {}
	for _, award in { { "Goals", "TOP SCORER" }, { "Assists", "PLAYMAKER" }, { "Steals", "THIEF" }, { "Saves", "WALL" }, { "Smacks", "SMACKER" }, { "KOs", "KNOCKOUT KING" } } do
		local bestName, best = nil, 0
		for _, stats in matchStats do
			if stats[award[1]] > best then
				bestName, best = stats.Name, stats[award[1]]
			end
		end
		if bestName then
			table.insert(awards, `{award[2]}: {bestName} ({best})`)
		end
	end
	MatchService.Services.Net.MatchEvent:FireAllClients("Ended", { Winner = winner, Blue = score.Blue, Red = score.Red })
	for _, player in Players:GetPlayers() do
		local teamName = player:GetAttribute("Team")
		if teamName then
			local kind = if winner == nil then "Draw" elseif winner == teamName then "Win" else "Loss"
			local actor = MatchService:ActorForPlayer(player)
			local stats = statsFor(player)
			if actor then
				reward(actor, kind)
			else
				local xp, coins = MatchService.Services.ProgressService:Reward(player, kind)
				stats.XP += xp
				stats.Coins += coins
			end
			MatchService.Services.ProgressService:FinishMatch(player, kind == "Win")
			MatchService.Services.Net.Results:FireClient(player, {
				Result = kind,
				Goals = stats.Goals,
				Assists = stats.Assists,
				Steals = stats.Steals,
				Saves = stats.Saves,
				Smacks = stats.Smacks,
				KOs = stats.KOs,
				XP = stats.XP,
				Coins = stats.Coins,
				EXP = stats.EXP,
				Awards = awards,
			})
			MatchService.Services.MonetizationService:AfterMatch(player, kind)
		end
	end
	task.wait(Config.ResultsSeconds)
end

local function runMatch()
	score.Blue, score.Red = 0, 0
	timeLeft = Config.MatchSeconds
	goldenGoal = false
	MatchService.ScoreLimitReached = false
	table.clear(matchStats)
	resetTeamStats()
	publishTeamStats()
	for _, player in Players:GetPlayers() do
		MatchService.Services.ProgressService:ResetMatch(player)
	end
	updateScore()
	kickoff()
	local lastTick = os.clock()
	while true do
		task.wait(0.1)
		local t = os.clock()
		local dt = t - lastTick
		lastTick = t
		if #Players:GetPlayers() == 0 then
			return
		end
		if MatchService.GoalScored then
			MatchService.GoalScored = false
			setState("Goal", Config.GoalCelebrationSeconds)
			task.wait(Config.GoalCelebrationSeconds)
			if goldenGoal or MatchService.ScoreLimitReached then
				break
			end
			kickoff()
			lastTick = os.clock()
		else
			timeLeft -= dt
			local carrier = MatchService.Services.BallService.Carrier
			if carrier and teamStats[carrier.Team] then
				teamStats[carrier.Team].Possession += dt
				publishTeamStats()
			end
			if timeLeft <= 0 then
				if score.Blue == score.Red and not goldenGoal then
					goldenGoal = true
					timeLeft = Config.GoldenGoalSeconds
					MatchService.Services.Net.SendAnnounce("GOLDEN GOAL! Next goal wins!", GOLD)
					setState("Playing")
				else
					timeLeft = 0
					updateScore()
					break
				end
			end
			updateScore()
		end
	end
	finishMatch()
end

---------------------------------------------------------------- Start

function MatchService:Init(services)
	self.Services = services
	for _, teamName in Config.TeamOrder do
		local def = Config.Teams[teamName]
		local team = Instance.new("Team")
		team.Name = def.Name
		team.TeamColor = def.BrickColor
		team.AutoAssignable = false
		team.Parent = Teams
		teamObjects[teamName] = team
	end
end

function MatchService:Start()
	updateScore()
	setState("Waiting")
	task.spawn(function()
		while true do
			if #Players:GetPlayers() > 0 then
				self:Rebalance()
				local ok, err = pcall(runMatch)
				if not ok then
					warn("[Match] Fehler:", err)
					task.wait(1)
				end
				self:Rebalance()
			else
				setState("Waiting")
				self:Rebalance()
				task.wait(1)
			end
		end
	end)
	-- Ab und zu pruefen, ob die Teams noch ausgeglichen sind
	task.spawn(function()
		while true do
			task.wait(5)
			self:Rebalance()
		end
	end)
	RunService.Heartbeat:Connect(function()
		-- Wer waehrend des Anstosses loslaeuft, bleibt stehen (Client friert ebenfalls ein)
		if state == "Kickoff" then
			for _, actor in actorList do
				if not actor.Player then
					actor.Humanoid:Move(Vector3.zero)
				end
			end
		end
	end)
end

function MatchService:OnPlayerReady(player: Player)
	self:AssignTeam(player)
	self:Rebalance()
end

function MatchService:OnCharacterAdded(player: Player, character: Model)
	local teamName = player:GetAttribute("Team")
	if not teamName then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	if not character.Parent then
		return
	end
	self:AddActor(character, teamName, player, nil, player.DisplayName)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:RemoveActor(character)
		end
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			self:RemoveActor(character)
		end)
	end
end

function MatchService:OnPlayerRemoving(player: Player)
	if player.Character then
		self:RemoveActor(player.Character)
	end
	matchStats[player] = nil
	self.Services.ProgressService:OnPlayerRemoving(player)
	task.defer(function()
		self:Rebalance()
	end)
end

function MatchService:GetState(): string
	return state
end

return MatchService
