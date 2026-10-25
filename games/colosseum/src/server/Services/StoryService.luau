-- Die Geschichte von Valoria: Gespraeche, Professor Sol und die Starter, Rivale Kai, Trainer die dich sehen,
-- Arenaleiter mit Orden, Team Eclipse, Top Vier und Champion, legendaere Bestien, Heilzentren, Laeden,
-- Fliegen zu besuchten Staedten und das Aufwachen im Heilzentrum nach einer Niederlage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Story = require(ReplicatedStorage.Shared.Story)
local BeastModel = require(ReplicatedStorage.Shared.BeastModel)

local StoryService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(110, 230, 130)

local busy = {} -- [Player] = true waehrend Gespraechen und Ereignissen
local dialogs = {} -- [Player] = { Token, Answer }
local nextToken = 0
local trainerModels: { [string]: Model } = {} -- [TrainerId] = Model

function StoryService:Init(services)
	self.Services = services
end

function StoryService:Busy(player: Player): boolean
	return busy[player] == true or self.Services.BattleService:InBattle(player)
end

local function rootOf(player: Player): BasePart?
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function freeze(player: Player, frozen: boolean)
	local root = rootOf(player)
	if root then
		root.Anchored = frozen
	end
end

local function dataOf(player: Player)
	return StoryService.Services.DataService:Get(player)
end

local function sync(player: Player)
	StoryService.Services.BeastService:Sync(player)
end

---------------------------------------------------------------- Gespraeche

-- Zeigt ein Gespraech und wartet auf die Antwort. Gibt die Nummer der Auswahl zurueck (ohne Auswahl: 1).
function StoryService:Say(player: Player, speaker: string, lines: { string }, choices: { string }?, look: string?): number?
	if not player.Parent then
		return nil
	end
	nextToken += 1
	local token = nextToken
	local state = { Token = token, Answer = nil :: number? }
	dialogs[player] = state
	local wasAnchored = (rootOf(player) and (rootOf(player) :: BasePart).Anchored) or false
	freeze(player, true)
	self.Services.Net.Dialog:FireClient(player, token, { Speaker = speaker, Lines = lines, Choices = choices, Look = look })
	local deadline = os.clock() + 25 + #lines * 12
	while state.Answer == nil and os.clock() < deadline and player.Parent and dialogs[player] == state do
		task.wait(0.1)
	end
	if dialogs[player] == state then
		dialogs[player] = nil
	end
	if not wasAnchored and not self.Services.BattleService:InBattle(player) then
		freeze(player, false)
	end
	return state.Answer or 1
end

local function story(player: Player, kind: string, payload: any?)
	StoryService.Services.Net.Story:FireClient(player, kind, payload)
end

-- Fuehrt eine Story-Aktion aus, waehrend der Spieler als beschaeftigt gilt
local function run(player: Player, fn: () -> ())
	if StoryService:Busy(player) then
		return
	end
	busy[player] = true
	local ok, err = pcall(fn)
	busy[player] = nil
	if not ok then
		warn("[Story]", err)
	end
end

---------------------------------------------------------------- Orden und Belohnungen

-- Orden Nummer index vergeben (nur der naechste in Reihenfolge). viaPurchase = Champion Pass.
function StoryService:GrantBadge(player: Player, index: number, viaPurchase: boolean?): boolean
	local data = dataOf(player)
	local leader = Story.Leaders[index]
	if not data or not leader or data.Crests ~= index - 1 then
		return false
	end
	data.Crests = index
	data.Beaten[leader.Id] = true
	local services = self.Services
	services.DataService:AddCoins(player, leader.Coins)
	for key, amount in leader.Items or {} do
		services.BeastService:AddItem(player, key, amount)
	end
	services.DataService:UpdateAttributes(player)
	sync(player)
	story(player, "Badge", { Index = index, Badge = leader.Badge, Leader = leader.Name, Type = leader.Type, Coins = leader.Coins })
	services.Net.SendAnnounce(`{player.DisplayName} earned the {leader.Badge} from {leader.Name}!{if viaPurchase then " (Champion Pass)" else ""}`, GOLD)
	return true
end

local function setFlag(player: Player, flag: string)
	local data = dataOf(player)
	if data and not data.Flags[flag] then
		data.Flags[flag] = true
		sync(player)
	end
end

---------------------------------------------------------------- Trainer-Kaempfe

local function teamCopy(team)
	local list = {}
	for _, member in team do
		table.insert(list, { member[1], member[2] })
	end
	return list
end

local function towardOf(model: Model?): Vector3?
	return if model and model.PrimaryPart then model.PrimaryPart.Position else nil
end

-- Normaler Trainer (Route, Arena, Team Eclipse) oder Rivale. Gibt nach dem Kampf das Ergebnis zurueck.
-- Arena-Trainer kaempfen auf dem Feld ihres Arenaleiters
local function arenaStage(trainer)
	if not trainer.ArenaSlot then
		return nil
	end
	for _, leader in Story.Leaders do
		if leader.Town == trainer.Area then
			return { Style = "Arena", Color = Config.Types[leader.Type].Color }
		end
	end
	return nil
end

local function trainerBattle(player: Player, trainer, model: Model?): string?
	local services = StoryService.Services
	local data = dataOf(player)
	if not data then
		return nil
	end
	local team = trainer.Team
	local lines = trainer.Lines
	local defeat = trainer.Defeat
	if trainer.Rival then
		team = Story.RivalTeam(trainer.Rival, data.Starter)
		lines = Story.RivalLines[trainer.Rival].Before
		defeat = Story.RivalLines[trainer.Rival].After
	end
	local speaker = if trainer.Name ~= "" then trainer.Name else trainer.Class
	StoryService:Say(player, speaker, lines, nil, trainer.Look)
	local done = Instance.new("BindableEvent")
	local outcome: string? = nil
	local battle = services.BattleService:StartTrainer(player, {
		Name = speaker,
		Title = trainer.Class,
		Look = trainer.Look,
		Team = teamCopy(team),
		Smart = trainer.Rival ~= nil or trainer.Blocker == true,
		Potions = if trainer.Rival and trainer.Rival >= 3 then 1 else 0,
		Toward = towardOf(model),
		Music = if trainer.Rival then "Rival" elseif trainer.Class:find("Eclipse") then "Eclipse" else "Trainer",
		NoWhiteout = trainer.Rival == 1,
		Stage = arenaStage(trainer),
		OnEnd = function(_, result)
			outcome = result
			done:Fire()
		end,
	})
	if not battle then
		done:Destroy()
		return nil
	end
	done.Event:Wait()
	done:Destroy()
	task.wait(3.4)
	if outcome == "Win" then
		data.Beaten[trainer.Id] = true
		if trainer.Flag then
			data.Flags[trainer.Flag] = true
		end
		sync(player)
		StoryService:Say(player, speaker, defeat, nil, trainer.Look)
	elseif outcome == "Lose" and trainer.Rival then
		StoryService:Say(player, speaker, { "Haha! I won! I told you I'd be the best!" }, nil, trainer.Look)
	end
	return outcome
end

local function rivalReady(data, trainer): boolean
	if not trainer.Rival then
		return true
	end
	return data.Flags[`rival{trainer.Rival - 1}`] == true and not data.Flags[trainer.Flag]
end

local function challengeTrainer(player: Player, trainer, model: Model?)
	local data = dataOf(player)
	if not data or not data.Started then
		return
	end
	if data.Beaten[trainer.Id] or (trainer.Flag and data.Flags[trainer.Flag]) then
		local speaker = if trainer.Name ~= "" then trainer.Name else trainer.Class
		StoryService:Say(player, speaker, trainer.Defeat or { "That was a great battle!" }, nil, trainer.Look)
		return
	end
	if not rivalReady(data, trainer) then
		return
	end
	trainerBattle(player, trainer, model)
end

---------------------------------------------------------------- Arenaleiter, Top Vier, Champion

local function leaderBattle(player: Player, index: number, model: Model?)
	local services = StoryService.Services
	local data = dataOf(player)
	local leader = Story.Leaders[index]
	if not data or not leader then
		return
	end
	if data.Crests >= index then
		local answer = StoryService:Say(player, leader.Name, { `You already earned the {leader.Badge}.`, "Want a rematch? My team got stronger!" }, { "Rematch!", "Not now" }, leader.Look)
		if answer == 1 then
			busy[player] = nil
			StoryService:StartRematch(player, index)
		end
		return
	end
	if data.Crests < index - 1 then
		StoryService:Say(player, leader.Name, { `Come back when you have {index - 1} badges.` }, nil, leader.Look)
		return
	end
	if leader.Requires and not data.Flags[leader.Requires] then
		StoryService:Say(player, leader.Name, { "Team Eclipse is causing trouble in town!", "Please stop them first, then we can battle." }, nil, leader.Look)
		return
	end
	-- Angebot, wenn das Team deutlich schwaecher ist
	local top = 0
	for _, member in leader.Team do
		top = math.max(top, member[2])
	end
	if services.BeastService:LeadLevel(player) < top - 4 then
		services.MonetizationService:Offer(player, "PowerSnack", `{leader.Name}'s beasts are up to Lv {top}! Give your lead beast +5 levels?`)
	end
	local answer = StoryService:Say(player, leader.Name, leader.Lines, { "Let's battle!", "Not yet" }, leader.Look)
	if answer ~= 1 then
		return
	end
	local done = Instance.new("BindableEvent")
	local outcome: string? = nil
	local battle = services.BattleService:StartTrainer(player, {
		Name = leader.Name,
		Title = "Arena Leader",
		Look = leader.Look,
		Team = teamCopy(leader.Team),
		Smart = true,
		Potions = 1 + math.floor(index / 4),
		Coins = 0, -- Muenzen kommen mit dem Orden
		Toward = towardOf(model),
		Music = "Leader",
		Stage = { Style = "Arena", Color = Config.Types[leader.Type].Color },
		OnEnd = function(_, result)
			outcome = result
			done:Fire()
		end,
	})
	if not battle then
		done:Destroy()
		return
	end
	done.Event:Wait()
	done:Destroy()
	task.wait(3.4)
	if outcome == "Win" then
		StoryService:Say(player, leader.Name, leader.Defeat, nil, leader.Look)
		StoryService:GrantBadge(player, index)
		local items = services.BeastService:BundleText({ Coins = leader.Coins, Items = leader.Items })
		StoryService:Say(player, leader.Name, { `You received the {leader.Badge}!`, `You also got {items}.` }, nil, leader.Look)
	elseif outcome == "Lose" then
		services.MonetizationService:Offer(player, "SkipChampion", `{leader.Name} is tough! Get the {leader.Badge} instantly?`, true)
	end
end

function StoryService:StartRematch(player: Player, index: number)
	local services = self.Services
	local data = dataOf(player)
	local leader = Story.Leaders[index]
	if not data or not leader or data.Crests < index or self:Busy(player) then
		return
	end
	local lead = services.BeastService:LeadLevel(player)
	local team = {}
	for _, member in leader.Team do
		table.insert(team, { member[1], math.clamp(math.max(member[2], lead + 2), 1, Config.MaxLevel) })
	end
	services.BattleService:StartTrainer(player, {
		Name = leader.Name,
		Title = "Leader Rematch",
		Look = leader.Look,
		Team = team,
		Smart = true,
		Potions = 2,
		Coins = math.floor(leader.Coins * Config.RematchShare),
		Music = "Leader",
		Stage = { Style = "Arena", Color = Config.Types[leader.Type].Color },
	})
end

local function eliteBattle(player: Player, index: number, model: Model?)
	local services = StoryService.Services
	local data = dataOf(player)
	local elite = Story.Elite[index]
	if not data or not elite then
		return
	end
	if data.Crests < 8 then
		StoryService:Say(player, elite.Name, { "Only tamers with all 8 badges may challenge the League." }, nil, elite.Look)
		return
	end
	local previous = Story.Elite[index - 1]
	if previous and not data.Flags[previous.Id] and not data.Flags.champion then
		StoryService:Say(player, elite.Name, { `Defeat {previous.Name} first. The League must be fought in order!` }, nil, elite.Look)
		return
	end
	local rematch = data.Flags[elite.Id] == true
	local lines = if rematch then { "Back for more? The League never sleeps!" } else elite.Lines
	local answer = StoryService:Say(player, elite.Name, lines, { if rematch then "Rematch!" else "Let's battle!", "Not yet" }, elite.Look)
	if answer ~= 1 then
		return
	end
	local team = teamCopy(elite.Team)
	if rematch then
		for _, member in team do
			member[2] = math.min(Config.MaxLevel, member[2] + 8)
		end
	end
	local done = Instance.new("BindableEvent")
	local outcome: string? = nil
	local battle = services.BattleService:StartTrainer(player, {
		Name = elite.Name,
		Title = elite.Title,
		Look = elite.Look,
		Team = team,
		Smart = true,
		Potions = if elite.Id == "champion" then 3 else 2,
		Coins = if rematch then math.floor(elite.Coins * Config.RematchShare * 2) else elite.Coins,
		Toward = towardOf(model),
		Music = if elite.Id == "champion" then "Champion" else "Leader",
		Stage = { Style = "League", Color = if elite.Id == "champion" then Color3.fromRGB(255, 200, 60) else Color3.fromRGB(170, 110, 240) },
		OnEnd = function(_, result)
			outcome = result
			done:Fire()
		end,
	})
	if not battle then
		done:Destroy()
		return
	end
	done.Event:Wait()
	done:Destroy()
	task.wait(3.4)
	if outcome == "Win" then
		StoryService:Say(player, elite.Name, elite.Defeat, nil, elite.Look)
		if not rematch then
			data.Flags[elite.Id] = true
			data.Beaten[elite.Id] = true
			sync(player)
			if elite.Id == "champion" then
				data.Trophies += 100
				services.DataService:UpdateAttributes(player)
				story(player, "HallOfFame", { Team = services.BeastService:TeamEntries(player) })
				services.Net.SendAnnounce(`🏆 {player.DisplayName} defeated Champion Maximus and is the new CHAMPION of Valoria!`, GOLD)
				StoryService:Say(player, "Professor Sol", { "Congratulations, Champion!", "But your journey isn't over. A dark rift has opened next to the Colosseum...", "Voidrake, the beast Team Eclipse wanted, is waiting there. Can you catch it?" }, nil, "Professor")
			else
				services.Net.SendAnnounce(`{player.DisplayName} defeated {elite.Name} of the Grand Four!`, GOLD)
			end
		end
	elseif outcome == "Lose" and not rematch then
		services.MonetizationService:Offer(player, "FullHeal", "So close! Heal your whole team and try again right away?", true)
	end
end

---------------------------------------------------------------- Legenden

local function legendBattle(player: Player, legend, model: Model?)
	local services = StoryService.Services
	local data = dataOf(player)
	if not data then
		return
	end
	local flag = `leg_{legend.Beast}`
	local beast = Config.BeastsById[legend.Beast]
	if data.Flags[flag] then
		return
	end
	if (legend.Badges and data.Crests < legend.Badges) or (legend.Flag and not data.Flags[legend.Flag]) then
		local need = if legend.Flag then "the title of Champion" else `{legend.Badges} badges`
		StoryService:Say(player, "???", { `A mighty presence is sleeping here...`, `Only a tamer with {need} can wake {beast.Name}.` })
		return
	end
	local answer = StoryService:Say(player, beast.Name, { legend.Text }, { "Battle it!", "Leave it alone" })
	if answer ~= 1 then
		return
	end
	if (data.Items.MasterOrb or 0) <= 0 then
		services.MonetizationService:Offer(player, "MasterOrb1", `{beast.Name} is very hard to catch. A Master Orb ALWAYS works!`, true)
	end
	local done = Instance.new("BindableEvent")
	local outcome: string? = nil
	local battle = services.BattleService:StartWild(player, legend.Beast, legend.Level, false, {
		Legend = true,
		Toward = towardOf(model),
		OnEnd = function(_, result)
			outcome = result
			done:Fire()
		end,
	})
	if not battle then
		done:Destroy()
		return
	end
	done.Event:Wait()
	done:Destroy()
	task.wait(3.4)
	if outcome == "Caught" then
		setFlag(player, flag)
		story(player, "Hide", { Flag = flag })
	elseif outcome == "Win" then
		StoryService:Say(player, "", { `{beast.Name} fled into the shadows...`, "It looks like it will return to this place." })
	end
end

---------------------------------------------------------------- Starter und Professor

function StoryService:OnStarterChosen(player: Player, beastId: string)
	local services = self.Services
	local data = dataOf(player)
	if not data then
		return
	end
	data.Flags.starter = true
	sync(player)
	local beast = Config.BeastsById[beastId]
	task.spawn(function()
		busy[player] = true
		task.wait(1.5)
		self:Say(player, "Professor Sol", { `So you chose {beast.Name}! An excellent choice.`, `{beast.Name} is a {beast.Type} type. Take good care of it!` }, nil, "Professor")
		local rival = Story.RivalStarter[beastId]
		self:Say(player, "Kai", { "Then I'll take this one!", `{Config.BeastsById[rival].Name} has the type advantage. Hehe!` }, nil, "Rival")
		busy[player] = nil
		local rivalTrainer = { Id = "rival1", Rival = 1, Flag = "rival1", Class = "Rival", Name = "Kai", Look = "Rival" }
		busy[player] = true
		local ok, outcome = pcall(trainerBattle, player, rivalTrainer, trainerModels.rival1)
		busy[player] = nil
		if not ok then
			warn("[Story] Rivalenkampf", outcome)
		end
		data.Flags.rival1 = true
		data.Beaten.rival1 = true
		services.BeastService:HealAll(player)
		busy[player] = true
		services.BeastService:AddItem(player, "Orb", 5)
		self:Say(player, "Professor Sol", {
			"What a battle! I healed your beasts for you.",
			"Here, take these 5 Catch Orbs. Weaken wild beasts in the tall grass, then throw an orb to catch them!",
			"Your goal: collect all 8 arena badges and become Champion of the Colosseum League!",
			"The first arena is in Pebbleton, north through Route 1. Good luck!",
		}, nil, "Professor")
		busy[player] = nil
		story(player, "Hide", { Flag = "rival1" })
		services.Net.SendNotify(player, "Received 5 Catch Orbs!", GOLD)
		sync(player)
	end)
end

local function talkProfessor(player: Player)
	local services = StoryService.Services
	local data = dataOf(player)
	if not data then
		return
	end
	if not data.Started then
		StoryService:Say(player, "Professor Sol", {
			"Welcome to the world of beasts! I am Professor Sol.",
			"Valoria is full of wild beasts. Some people battle with them, others collect them.",
			"Every great journey starts with a partner. Choose one of my three beasts!",
		}, nil, "Professor")
		services.BeastService:OfferStarter(player)
		return
	end
	local caught, seen = 0, 0
	for _ in data.Dex do
		caught += 1
	end
	for _ in data.Seen do
		seen += 1
	end
	local comment = if caught < 10 then "That's a nice start! Keep catching!" elseif caught < 25 then "Impressive! You are becoming a real collector." elseif caught < #Config.Beasts then "Amazing! Only a few beasts are missing!" else "INCREDIBLE! You completed the Bestiary! You are a true master!"
	StoryService:Say(player, "Professor Sol", { `Let me see your Bestiary... Seen: {seen}, caught: {caught} of {#Config.Beasts}.`, comment }, nil, "Professor")
end

---------------------------------------------------------------- Heilzentrum, Laden, Personen

local function heal(player: Player, areaId: string)
	local services = StoryService.Services
	local data = dataOf(player)
	if not data then
		return
	end
	local answer = StoryService:Say(player, "Nurse Lina", { "Welcome to the Heal Center!", "Shall I restore your beasts to full health?" }, { "Yes, please", "No thanks" }, "Nurse")
	if answer ~= 1 then
		return
	end
	services.BeastService:HealAll(player)
	data.LastCenter = areaId
	data.Visited[areaId] = true
	story(player, "Healed")
	StoryService:Say(player, "Nurse Lina", { "Your beasts are fully healed!", "We hope to see you again!" }, nil, "Nurse")
end

local function talkNpc(player: Player, npc)
	local services = StoryService.Services
	local data = dataOf(player)
	if not data then
		return
	end
	local gift = npc.Gift
	if gift and data.Flags[gift.Flag] then
		StoryService:Say(player, npc.Name, { npc.Lines[1], "Good luck out there!" }, nil, npc.Look)
		return
	end
	StoryService:Say(player, npc.Name, npc.Lines, nil, npc.Look)
	if gift then
		data.Flags[gift.Flag] = true
		services.BeastService:AddItem(player, gift.Item, gift.Amount)
		services.Net.SendNotify(player, `Received {gift.Amount}x {Config.Items[gift.Item].Name}!`, GOLD)
	end
end

---------------------------------------------------------------- Figuren aufstellen

local function addPrompt(model: Model, action: string, onTrigger: (Player) -> ())
	local p = StoryService.Services.WorldService.Prompt(model.PrimaryPart :: BasePart, action, model.Name, "Talk")
	p.Triggered:Connect(function(player)
		run(player, function()
			onTrigger(player)
		end)
	end)
	return p
end

local function trainerCFrame(trainer, spots): CFrame?
	local area = Story.AreasById[trainer.Area]
	if area.Kind == "Route" then
		local side = if trainer.Side == 0 then 1 else trainer.Side
		local pos = Story.RoutePoint(area, trainer.A, side * 22)
		local look = pos - area.Side * side
		return CFrame.lookAt(pos, Vector3.new(look.X, pos.Y, look.Z))
	end
	local C = area.Center
	if trainer.ArenaSlot then
		return spots.GymTrainers and spots.GymTrainers[trainer.ArenaSlot]
	elseif trainer.Blocker then
		return spots.ArenaDoor
	elseif trainer.Id == "dg" then
		return CFrame.lookAt(C + Vector3.new(-12, 0, -24), C + Vector3.new(10, 0, -24))
	end
	return CFrame.new(C)
end

local function buildCharacters()
	local world = StoryService.Services.WorldService
	local spots = world.Spots

	for _, area in Story.Areas do
		local s = spots[area.Id]
		if area.Kind == "Town" and s then
			if s.Nurse then
				local nurse = world:MakeNpc("Nurse", "Nurse Lina", "Heal Center", s.Nurse)
				addPrompt(nurse, "Heal Team", function(player)
					heal(player, area.Id)
				end)
			end
			if s.Clerk then
				local clerk = world:MakeNpc("Clerk", "Clerk", "Beast Mart", s.Clerk)
				addPrompt(clerk, "Shop", function(player)
					StoryService:Say(player, "Clerk", { "Welcome to the Beast Mart! What can I get you?" }, nil, "Clerk")
					StoryService.Services.Net.OpenMenu:FireClient(player, "Mart")
				end)
			end
			if s.Professor then
				local professor = world:MakeNpc("Professor", "Professor Sol", "Beast Professor", s.Professor)
				professor:SetAttribute("Objective", "starter")
				addPrompt(professor, "Talk", talkProfessor)
				local kai = world:MakeNpc("Rival", "Kai", "Your Rival", s.Rival)
				kai:SetAttribute("HideFlag", "rival1")
				trainerModels.rival1 = kai
			end
		end
	end

	-- Personen in den Staedten
	for _, npc in Story.Npcs do
		local area = Story.AreasById[npc.Area]
		local pos = area.Center + npc.Pos
		local model = world:MakeNpc(npc.Look, npc.Name, nil, CFrame.lookAt(pos, Vector3.new(area.Center.X, pos.Y, area.Center.Z)))
		if npc.Gift then
			model:SetAttribute("GiftFlag", npc.Gift.Flag)
		end
		addPrompt(model, "Talk", function(player)
			talkNpc(player, npc)
		end)
	end

	-- Trainer
	for _, trainer in Story.Trainers do
		local cf = trainerCFrame(trainer, spots[trainer.Area] or {})
		if cf then
			local label = if trainer.Name ~= "" then trainer.Name else trainer.Class
			local model = world:MakeNpc(trainer.Look, label, if trainer.Name ~= "" then trainer.Class else nil, cf)
			model:SetAttribute("TrainerId", trainer.Id)
			model:SetAttribute("Sight", if trainer.Area:find("route") or trainer.Area == "victory" then math.max(trainer.Sight, 32) else trainer.Sight)
			if trainer.Rival then
				model:SetAttribute("ShowFlag", `rival{trainer.Rival - 1}`)
				model:SetAttribute("HideFlag", trainer.Flag)
			elseif trainer.Blocker then
				model:SetAttribute("HideFlag", trainer.Flag)
			end
			trainerModels[trainer.Id] = model
			addPrompt(model, "Talk", function(player)
				challengeTrainer(player, trainer, model)
			end)
		end
	end

	-- Arenaleiter
	for index, leader in Story.Leaders do
		local s = spots[leader.Town]
		if s and s.Leader then
			local model = world:MakeNpc(leader.Look, leader.Name, `{leader.Type} Arena Leader`, s.Leader)
			model:SetAttribute("LeaderIndex", index)
			addPrompt(model, "Challenge", function(player)
				leaderBattle(player, index, model)
			end)
		end
	end

	-- Top Vier und Champion
	local league = spots.league
	if league then
		for index, elite in Story.Elite do
			local cf = if elite.Id == "champion" then league.Champion else league.Elite[index]
			if cf then
				local model = world:MakeNpc(elite.Look, elite.Name, elite.Title, cf)
				addPrompt(model, "Challenge", function(player)
					eliteBattle(player, index, model)
				end)
			end
		end
	end

	-- Legendaere Bestien in ihren Schreinen
	for _, legend in Story.Legends do
		local s = spots[legend.Area]
		local cf = s and s.Shrines and s.Shrines[legend.Beast]
		if cf then
			local model = BeastModel.Build(legend.Beast, legend.Level, false)
			local scale = BeastModel.Scale(legend.Beast, legend.Level) * 1.25
			model:ScaleTo(1.25)
			model:PivotTo(cf * CFrame.new(0, BeastModel.Hover(legend.Beast, scale), 0))
			model:SetAttribute("HideFlag", `leg_{legend.Beast}`)
			model:SetAttribute("Legend", legend.Beast)
			model.Parent = workspace:FindFirstChild("Npcs")
			local p = world.Prompt(model.PrimaryPart :: BasePart, "Approach", Config.BeastsById[legend.Beast].Name, "Talk")
			p.MaxActivationDistance = 16
			p.Triggered:Connect(function(player)
				run(player, function()
					legendBattle(player, legend, model)
				end)
			end)
		end
	end
end

---------------------------------------------------------------- Teleports

local function teleport(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cf)
	end
end

function StoryService:Whiteout(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	self.Services.BeastService:HealAll(player)
	teleport(player, self.Services.WorldService:LandingFor(data.LastCenter))
	freeze(player, false)
	story(player, "Whiteout", { Area = data.LastCenter })
	self.Services.Net.SendNotify(player, "Your beasts were healed at the Heal Center.", GREEN)
end

function StoryService:OnPlayerReady(player: Player)
	local function place(character: Model)
		local data = dataOf(player)
		if not data then
			return
		end
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		if data.Started then
			teleport(player, self.Services.WorldService:LandingFor(data.LastCenter))
		else
			teleport(player, self.Services.WorldService.SpawnCFrame)
		end
	end
	player.CharacterAdded:Connect(place)
	if player.Character then
		task.spawn(place, player.Character)
	end
end

function StoryService:OnPlayerRemoving(player: Player)
	busy[player] = nil
	dialogs[player] = nil
end

---------------------------------------------------------------- Start

function StoryService:Build()
	buildCharacters()
end

function StoryService:Start()
	local services = self.Services
	local net = services.Net

	net.DialogAnswer.OnServerEvent:Connect(function(player, token, choice)
		local state = dialogs[player]
		if state and state.Token == token then
			state.Answer = if typeof(choice) == "number" then math.floor(choice) else 1
		end
	end)

	-- Ein Trainer hat den Spieler gesehen (der Client prueft die Sichtlinie, der Server die Entfernung)
	net.TrainerSpotted.OnServerEvent:Connect(function(player, trainerId)
		local trainer = typeof(trainerId) == "string" and Story.TrainersById[trainerId]
		local model = trainer and trainerModels[trainer.Id]
		local root = rootOf(player)
		local data = dataOf(player)
		if not trainer or not model or not root or not data or not data.Started or data.Beaten[trainer.Id] or trainer.Sight <= 0 then
			return
		end
		if not rivalReady(data, trainer) or (trainer.Flag and data.Flags[trainer.Flag]) then
			return
		end
		local distance = (model:GetPivot().Position - root.Position).Magnitude
		if distance > (model:GetAttribute("Sight") or trainer.Sight) + 10 then
			return
		end
		if not services.BeastService:HasHealthyTeam(player) then
			return
		end
		run(player, function()
			trainerBattle(player, trainer, model)
		end)
	end)

	-- Fliegen: zu jeder besuchten Stadt (Landung vor dem Heilzentrum)
	net.Fly.OnServerEvent:Connect(function(player, areaId)
		local data = dataOf(player)
		local area = typeof(areaId) == "string" and Story.AreasById[areaId]
		if not data or not area or area.Kind ~= "Town" or not data.Visited[areaId] or self:Busy(player) then
			return
		end
		story(player, "Fly", { Area = areaId })
		task.wait(0.6)
		teleport(player, services.WorldService:LandingFor(areaId))
	end)

	-- Besuchte Orte merken (fuer Karte und Fliegen) und Ort als Attribut fuer die Anzeige
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				local data = dataOf(player)
				if root and data then
					local area = Story.AreaAt(root.Position)
					if area then
						if player:GetAttribute("Area") ~= area.Id then
							player:SetAttribute("Area", area.Id)
						end
						if area.Kind == "Town" and not data.Visited[area.Id] then
							data.Visited[area.Id] = true
							sync(player)
							net.SendNotify(player, `New place discovered: {area.Name}! You can fly here now.`, GOLD)
						end
					end
				end
			end
		end
	end)
end

-- Fuer den Smoke-Test
StoryService._Internal = {
	TrainerCFrame = trainerCFrame,
	TrainerModels = trainerModels,
}

return StoryService
