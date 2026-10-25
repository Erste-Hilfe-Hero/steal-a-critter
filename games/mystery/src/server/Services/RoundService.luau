-- Rundenablauf wie Murder Mystery: Lobby + Map-Abstimmung -> Rollen -> Runde -> Ergebnis.
-- Teilnehmer ("Actors") sind Spieler oder Bots. Rollen sind geheim und gehen nur an den jeweiligen Spieler.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RoundService = { Services = nil :: any }

local C = Config.Colors
local R = Config.Round

export type Actor = {
	Id: number,
	Name: string,
	Model: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Player: Player?,
	Bot: any?,
	Role: string,
	Alive: boolean,
	Coins: number,
	CoinValue: number,
	CoinPaid: number,
	KOs: number,
	Hidden: boolean,
	Shield: boolean,
	Exposed: number,
}

RoundService.State = "Intermission"
RoundService.Actors = {} :: { [number]: Actor }
RoundService.Map = nil :: any
RoundService.MapDef = nil :: any
RoundService.Modifier = nil :: any
RoundService.EndsAt = 0
RoundService.Winner = nil :: string?
RoundService.ForceModifier = nil :: string?
RoundService.Testing = false

local nextId = 0
local tickets = {} -- [userId] = { Murderer = n, Sheriff = n } (Chance steigt jede Runde ohne Rolle)
local votes = {} -- [Player] = mapIndex
local mapOptions = {} -- { mapIndex }
local guesses = {} -- [Player] = actorId (Ghost Guess)
local roundStats: any = {} -- Ergebnis-Daten fuer die laufende Runde
local lastMapIndex = 0
local charms = {} -- [userId] = { Murderer = true?, Sheriff = true? } (mit Muenzen gekaufte Glueckbringer)
local eventBoostUntil = 0 -- gekaufte Midnight Hour (os.time)

local function setState(state: string, endsAt: number)
	RoundService.State = state
	RoundService.EndsAt = endsAt
	ReplicatedStorage:SetAttribute("RoundState", state)
	ReplicatedStorage:SetAttribute("RoundEnds", endsAt)
end

---------------------------------------------------------------- Teilnehmer

function RoundService:GetActor(id: number): Actor?
	return self.Actors[id]
end

function RoundService:ActorOfPlayer(player: Player): Actor?
	for _, actor in self.Actors do
		if actor.Player == player then
			return actor
		end
	end
	return nil
end

function RoundService:ActorFromPart(part: Instance?): Actor?
	local model = part and part:FindFirstAncestorOfClass("Model")
	while model do
		local id = model:GetAttribute("ActorId")
		if id then
			local actor = self.Actors[id]
			if actor and actor.Model == model then
				return actor
			end
			return nil
		end
		local parent = model.Parent
		model = if parent == nil then nil elseif parent:IsA("Model") then parent else parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function RoundService:Alive(): { Actor }
	local list = {}
	for _, actor in self.Actors do
		if actor.Alive then
			table.insert(list, actor)
		end
	end
	return list
end

function RoundService:IsPlaying(): boolean
	return self.State == "Playing"
end

function RoundService:AddActor(model: Model, player: Player?, bot: any?, name: string): Actor?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return nil
	end
	nextId += 1
	local actor: Actor = {
		Id = nextId,
		Name = name,
		Model = model,
		Humanoid = humanoid,
		Root = root :: BasePart,
		Player = player,
		Bot = bot,
		Role = "Innocent",
		Alive = true,
		Coins = 0,
		CoinValue = 0,
		CoinPaid = 0,
		KOs = 0,
		Hidden = false,
		Shield = false,
		Exposed = 0,
	}
	model:SetAttribute("ActorId", actor.Id)
	CollectionService:AddTag(model, "Actor")
	-- Zuruecksetzen/Herunterfallen zaehlt als raus
	humanoid.Died:Connect(function()
		if actor.Alive and self.Actors[actor.Id] == actor then
			self.Services.CombatService:KO(actor, nil, "Reset")
		end
	end)
	self.Actors[actor.Id] = actor
	return actor
end

local function publishAlive()
	local list = {}
	for _, actor in RoundService.Actors do
		if actor.Alive then
			table.insert(list, { Id = actor.Id, Name = actor.Name })
		end
	end
	ReplicatedStorage:SetAttribute("AliveList", HttpService:JSONEncode(list))
	ReplicatedStorage:SetAttribute("AliveCount", #list)
end
RoundService.PublishAlive = publishAlive

---------------------------------------------------------------- Rollenwahl

local function ticketsFor(userId: number)
	tickets[userId] = tickets[userId] or { Murderer = Config.RoleTickets.Base, Sheriff = Config.RoleTickets.Base }
	return tickets[userId]
end

local function weightedPick(pool: { Actor }, weightOf: (Actor) -> number): Actor?
	local total = 0
	for _, actor in pool do
		total += weightOf(actor)
	end
	if total <= 0 then
		return pool[1]
	end
	local roll = math.random() * total
	for _, actor in pool do
		roll -= weightOf(actor)
		if roll <= 0 then
			return actor
		end
	end
	return pool[#pool]
end

-- Chancen fuer die Anzeige in der Lobby (alle Spieler, die in der naechsten Runde mitspielen wuerden)
function RoundService:SendOdds()
	local humans = Players:GetPlayers()
	local totals = { Murderer = 0, Sheriff = 0 }
	for _, player in humans do
		local t = ticketsFor(player.UserId)
		totals.Murderer += t.Murderer
		totals.Sheriff += t.Sheriff
	end
	local botCount = self.Services.BotService:PlannedBots(#humans)
	totals.Murderer += botCount * Config.RoleTickets.Base
	totals.Sheriff += botCount * Config.RoleTickets.Base
	for _, player in humans do
		local t = ticketsFor(player.UserId)
		local data = self.Services.DataService:Get(player)
		self.Services.Net.Role:FireClient(player, "Odds", {
			Murderer = if totals.Murderer > 0 then t.Murderer / totals.Murderer else 0,
			Sheriff = if totals.Sheriff > 0 then t.Sheriff / totals.Sheriff else 0,
			MurdererTickets = data and data.Tickets.Murderer or 0,
			SheriffTickets = data and data.Tickets.Sheriff or 0,
			Charms = charms[player.UserId] or {},
		})
	end
end

local function assignRoles(actors: { Actor })
	local services = RoundService.Services
	local count = if #actors >= R.DuoAt then 2 else 1
	local pool = table.clone(actors)
	local function take(actor: Actor)
		local index = table.find(pool, actor)
		if index then
			table.remove(pool, index)
		end
	end
	-- Gekaufte Tickets zuerst
	local function ticketHolders(role: string): { Actor }
		local list = {}
		for _, actor in pool do
			local data = actor.Player and services.DataService:Get(actor.Player)
			if data and (data.Tickets[role] or 0) > 0 then
				table.insert(list, actor)
			end
		end
		return list
	end
	local function choose(role: string)
		local holders = ticketHolders(role)
		local actor
		if #holders > 0 then
			actor = holders[math.random(1, #holders)]
			local data = services.DataService:Get(actor.Player)
			data.Tickets[role] -= 1
			services.Net.SendNotify(actor.Player, `{role} Ticket used!`, C.Moon)
		else
			actor = weightedPick(pool, function(a)
				if a.Player then
					return ticketsFor(a.Player.UserId)[role]
				end
				return Config.RoleTickets.Base
			end)
		end
		if actor then
			actor.Role = role
			take(actor)
		end
	end
	for _ = 1, count do
		choose("Murderer")
	end
	for _ = 1, count do
		if #pool > 0 then
			choose("Sheriff")
		end
	end
	-- Chancen anpassen (wer seine Rolle bekommt, verbraucht auch den Glueckbringer)
	for _, actor in actors do
		if actor.Player then
			local t = ticketsFor(actor.Player.UserId)
			local charm = charms[actor.Player.UserId]
			if charm and (actor.Role == "Murderer" or actor.Role == "Sheriff") then
				charm[actor.Role] = nil
			end
			if actor.Role == "Murderer" then
				t.Murderer = Config.RoleTickets.Base
				t.Sheriff += Config.RoleTickets.PerRound
			elseif actor.Role == "Sheriff" then
				t.Sheriff = Config.RoleTickets.Base
				t.Murderer += Config.RoleTickets.PerRound
			else
				t.Murderer += Config.RoleTickets.PerRound
				t.Sheriff += Config.RoleTickets.PerRound
			end
		end
	end
end

---------------------------------------------------------------- Modifikatoren

local savedLighting = {}
local function applyModifier(mod)
	RoundService.Modifier = mod
	ReplicatedStorage:SetAttribute("Modifier", if mod then mod.Id else "")
	if not mod then
		return
	end
	if mod.Id == "LowGravity" then
		workspace.Gravity = 80
	elseif mod.Id == "Fog" then
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			savedLighting.Density = atmosphere.Density
			atmosphere.Density = 0.62
		end
	elseif mod.Id == "SuperJump" then
		for _, actor in RoundService.Actors do
			actor.Humanoid.JumpPower = 95
			actor.Humanoid.JumpHeight = 22
		end
	elseif mod.Id == "Blackout" then
		savedLighting.Ambient = Lighting.Ambient
		savedLighting.Brightness = Lighting.Brightness
		Lighting.Ambient = Color3.fromRGB(8, 8, 16)
		Lighting.Brightness = 0.1
		for _, lamp in CollectionService:GetTagged("Lamp") do
			for _, l in lamp:GetChildren() do
				if l:IsA("Light") then
					l.Enabled = false
				end
			end
			if lamp:IsA("BasePart") then
				lamp.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

local function clearModifier()
	local mod = RoundService.Modifier
	if mod then
		if mod.Id == "LowGravity" then
			workspace.Gravity = 196.2
		elseif mod.Id == "Fog" then
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmosphere and savedLighting.Density then
				atmosphere.Density = savedLighting.Density
			end
		elseif mod.Id == "Blackout" then
			Lighting.Ambient = savedLighting.Ambient or Lighting.Ambient
			Lighting.Brightness = savedLighting.Brightness or Lighting.Brightness
		end
	end
	table.clear(savedLighting)
	RoundService.Modifier = nil
	ReplicatedStorage:SetAttribute("Modifier", "")
end

function RoundService:SpeedBonus(): number
	return if self.Modifier and self.Modifier.Id == "Speedy" then 5 else 0
end

function RoundService:CoinMultiplier(): number
	return if self.Modifier and self.Modifier.Id == "DoubleCoins" then 2 else 1
end

---------------------------------------------------------------- Midnight Hour (Server-Event)

-- Aktiv zur vollen und halben Stunde (fuer alle Server gleich) oder nach einem Kauf. Liefert das Ende (os.time) oder 0.
function RoundService:EventEndsAt(): number
	local MH = Config.MidnightHour
	local t = os.time()
	local slotStart = t - t % MH.Every
	local ends = if t < slotStart + MH.Duration then slotStart + MH.Duration else 0
	if eventBoostUntil > t then
		ends = math.max(ends, eventBoostUntil)
	end
	return ends
end

function RoundService:EventActive(): boolean
	return self:EventEndsAt() > 0
end

function RoundService:EventCoinMultiplier(): number
	return if self:EventActive() then Config.MidnightHour.Coins else 1
end

function RoundService:EventXPMultiplier(): number
	return if self:EventActive() then Config.MidnightHour.XP else 1
end

-- Gekaufte Midnight Hour: verlaengert ein laufendes Event oder startet sofort eins
function RoundService:BoostEvent(minutes: number)
	local base = math.max(os.time(), self:EventEndsAt())
	eventBoostUntil = base + minutes * 60
	self:PublishEvent()
end

local eventWasActive = false
function RoundService:PublishEvent()
	local MH = Config.MidnightHour
	local ends = self:EventEndsAt()
	local t = os.time()
	ReplicatedStorage:SetAttribute("EventEnds", ends)
	ReplicatedStorage:SetAttribute("EventNext", t - t % MH.Every + MH.Every)
	local active = ends > 0
	if active and not eventWasActive then
		self.Services.Net.SendAnnounce(`MIDNIGHT HOUR! 2x coins and 1.5x XP for everyone!`, C.Purple)
	end
	eventWasActive = active
end

---------------------------------------------------------------- Glueckbringer (Muenzen)

function RoundService:BuyCharm(player: Player, role: any)
	local def = typeof(role) == "string" and Config.Charms[role]
	if not def then
		return { Ok = false, Error = "Unknown charm" }
	end
	local active = charms[player.UserId] or {}
	if active[role] then
		return { Ok = false, Error = "This charm is already active" }
	end
	if not self.Services.ProgressService:SpendCoins(player, def.Price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	active[role] = true
	charms[player.UserId] = active
	local t = ticketsFor(player.UserId)
	t[role] += def.Tickets
	self.Services.Net.SendNotify(player, `{def.Name} active! Higher {role} chance until you get the role.`, C.Moon)
	self:SendOdds()
	return { Ok = true }
end

---------------------------------------------------------------- Abstimmung

local function pickMapOptions()
	table.clear(mapOptions)
	local indices = {}
	for i = 1, #Config.Maps do
		if i ~= lastMapIndex then
			table.insert(indices, i)
		end
	end
	for _ = 1, math.min(R.MapVotes, #indices) do
		table.insert(mapOptions, table.remove(indices, math.random(1, #indices)))
	end
	table.clear(votes)
	ReplicatedStorage:SetAttribute("MapOptions", HttpService:JSONEncode(mapOptions))
	ReplicatedStorage:SetAttribute("Votes", "{}")
end

local function publishVotes()
	local counts = {}
	for _, index in votes do
		counts[tostring(index)] = (counts[tostring(index)] or 0) + 1
	end
	ReplicatedStorage:SetAttribute("Votes", HttpService:JSONEncode(counts))
end

local function winningMap(): number
	local counts = {}
	for _, index in votes do
		counts[index] = (counts[index] or 0) + 1
	end
	local best, bestCount = mapOptions[math.random(1, #mapOptions)], -1
	for _, index in mapOptions do
		local c = counts[index] or 0
		if c > bestCount or (c == bestCount and math.random() < 0.5) then
			best, bestCount = index, c
		end
	end
	return best
end

---------------------------------------------------------------- Ablauf

local function teleport(actor: Actor, cf: CFrame)
	actor.Model:PivotTo(cf + Vector3.new(0, 3, 0))
end

function RoundService:StartRound(): boolean
	local services = self.Services
	-- Teilnehmer: alle Spieler mit geladenem Charakter + Bots
	local humans = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 and services.DataService:Get(player) and not player:GetAttribute("AFK") then
			table.insert(humans, player)
		end
	end
	if #humans == 0 and not self.Testing then
		return false
	end

	-- Karte bauen
	local mapIndex = if #mapOptions > 0 then winningMap() else math.random(1, #Config.Maps)
	lastMapIndex = mapIndex
	local def = Config.Maps[mapIndex]
	self.MapDef = def
	self.Map = services.MapService:LoadMap(def)
	ReplicatedStorage:SetAttribute("MapName", def.Name)

	table.clear(self.Actors)
	table.clear(guesses)
	roundStats = { Hero = nil, StoppedBy = nil, FirstKO = nil, LastSurvivor = nil }
	local actors = {}
	for _, player in humans do
		local actor = self:AddActor(player.Character :: Model, player, nil, player.DisplayName)
		if actor then
			table.insert(actors, actor)
		end
	end
	for _, bot in services.BotService:SpawnBots(#humans, self.Map) do
		local actor = self:AddActor(bot.Model, nil, bot, bot.Name)
		if actor then
			bot.Actor = actor
			table.insert(actors, actor)
		end
	end

	-- Modifikator (gekaufter Blackout hat Vorrang)
	local mod = nil
	if self.ForceModifier then
		for _, m in Config.Modifiers do
			if m.Id == self.ForceModifier then
				mod = m
			end
		end
		self.ForceModifier = nil
	elseif math.random() < R.ModifierChance then
		mod = Config.Modifiers[math.random(1, #Config.Modifiers)]
	end

	assignRoles(actors)
	local spawns = table.clone(self.Map.Spawns)
	for _, actor in actors do
		local cf = if #spawns > 0 then table.remove(spawns, math.random(1, #spawns)) else self.Map.Spawns[1]
		teleport(actor, cf)
		services.CombatService:PrepareActor(actor)
		if actor.Player then
			actor.Player:SetAttribute("InRound", true)
			services.Net.Role:FireClient(actor.Player, "Role", { Role = actor.Role, Modifier = mod and mod.Id, Map = def.Name })
		end
	end
	applyModifier(mod)
	publishAlive()
	setState("Reveal", workspace:GetServerTimeNow() + R.RevealTime)
	if mod then
		services.Net.SendAnnounce(`{mod.Name}: {mod.Text}`, mod.Color)
	end
	return true
end

-- Waffen nach der Rollenkarte verteilen und den Timer starten
function RoundService:BeginPlay()
	local services = self.Services
	for _, actor in self.Actors do
		if actor.Alive and (actor.Role == "Murderer" or actor.Role == "Sheriff") then
			services.CombatService:GiveWeapon(actor, if actor.Role == "Murderer" then "Knife" else "Gun")
		end
	end
	services.CoinService:StartRound(self.Map)
	services.AbilityService:StartRound(self.Map)
	services.ClueService:StartRound(self.Map)
	setState("Playing", workspace:GetServerTimeNow() + R.Duration)
	self.Winner = nil
end

function RoundService:CountSides(): (number, number)
	local murderers, others = 0, 0
	for _, actor in self.Actors do
		if actor.Alive then
			if actor.Role == "Murderer" then
				murderers += 1
			else
				others += 1
			end
		end
	end
	return murderers, others
end

-- Prueft nach jedem K.O. oder Verlassen, ob die Runde vorbei ist
function RoundService:CheckWin()
	if self.State ~= "Playing" and self.State ~= "Reveal" then
		return
	end
	local murderers, others = self:CountSides()
	if murderers == 0 then
		self:EndRound("Innocents", "The Murderer was stopped!")
	elseif others == 0 then
		self:EndRound("Murderer", "Everyone was knocked out!")
	end
end

function RoundService:GetLastSurvivor(): Actor?
	return roundStats.LastSurvivor
end

-- Nur noch ein Nicht-Murderer uebrig: Ansage, Tempo-Bonus, Extra-Muenzen wenn er durchhaelt
function RoundService:CheckLastSurvivor()
	if self.State ~= "Playing" or roundStats.LastSurvivor then
		return
	end
	local murderers, others = self:CountSides()
	if murderers == 0 or others ~= 1 then
		return
	end
	for _, actor in self.Actors do
		if actor.Alive and actor.Role ~= "Murderer" then
			roundStats.LastSurvivor = actor
			self.Services.Net.SendAnnounce(`{actor.Name} is the LAST SURVIVOR!`, C.Moon)
			self.Services.AbilityService:SpeedEffect(actor, "LastSurvivor", R.Duration, Config.LastSurvivor.SpeedBonus, nil)
			if actor.Player then
				self.Services.Net.SendNotify(actor.Player, `You're the last one! Survive for +{Config.LastSurvivor.Reward} coins!`, C.Moon)
			end
			return
		end
	end
end

-- Wird von CombatService bei jedem K.O. aufgerufen
function RoundService:OnKO(victim: Actor, killer: Actor?, cause: string)
	publishAlive()
	if killer and killer.Role == "Murderer" and victim.Role ~= "Murderer" then
		killer.KOs += 1
		if not roundStats.FirstKO then
			roundStats.FirstKO = killer.Name
		end
	end
	if victim.Role == "Murderer" and killer then
		roundStats.StoppedBy = killer
		if killer.Role == "Hero" then
			roundStats.Hero = killer
		end
	end
	if victim.Player then
		victim.Player:SetAttribute("InRound", false)
		self.Services.Net.Role:FireClient(victim.Player, "Out", { By = if killer then killer.Name else nil, ByRole = if killer and killer.Role == "Murderer" then "Murderer" else nil })
	end
	self:CheckWin()
	self:CheckLastSurvivor()
end

function RoundService:EndRound(winner: string, reason: string)
	if self.State == "Results" or self.State == "Intermission" then
		return
	end
	local services = self.Services
	self.Winner = winner
	setState("Results", workspace:GetServerTimeNow() + R.ResultsTime)
	services.CoinService:StopRound()
	services.AbilityService:StopRound()
	services.ClueService:StopRound()

	-- MVP = meiste Muenzen (bei Murderer-Sieg der Murderer)
	local mvp, best = nil, -1
	for _, actor in self.Actors do
		local score = actor.Coins + actor.KOs * 15 + (if roundStats.StoppedBy == actor then 40 else 0)
		if score > best then
			mvp, best = actor, score
		end
	end
	local murderers, sheriffs = {}, {}
	for _, actor in self.Actors do
		if actor.Role == "Murderer" then
			table.insert(murderers, actor.Name)
		elseif actor.Role == "Sheriff" or (actor.Role == "Hero" and actor ~= roundStats.Hero) then
			table.insert(sheriffs, actor.Name)
		end
	end

	-- Belohnungen fuer echte Spieler
	for _, actor in self.Actors do
		local player = actor.Player
		if player and player.Parent then
			local won = (winner == "Murderer") == (actor.Role == "Murderer")
			services.ProgressService:RoundReward(player, {
				Role = actor.Role,
				Won = won,
				Survived = actor.Alive,
				KOs = if actor.Role == "Murderer" then actor.KOs else 0,
				Stopped = roundStats.StoppedBy == actor,
				Hero = roundStats.Hero == actor,
				Coins = actor.Coins,
				MVP = mvp == actor,
				LastSurvivor = roundStats.LastSurvivor == actor and actor.Alive and winner ~= "Murderer",
			})
		end
	end
	-- Ghost Guess (im Duo-Modus zaehlt jeder der beiden Murderer)
	for player, id in guesses do
		local target = self.Actors[id]
		if player.Parent and target and target.Role == "Murderer" then
			services.ProgressService:AddCoins(player, Config.GhostGuessReward, false)
			services.ProgressService:AddStat(player, "GhostGuesses", 1)
			services.Net.SendNotify(player, `Ghost Guess correct! +{Config.GhostGuessReward} coins`, C.Moon)
		end
	end

	services.Net.Results:FireAllClients({
		Winner = winner,
		Reason = reason,
		Murderers = murderers,
		Sheriffs = sheriffs,
		Hero = if roundStats.Hero then roundStats.Hero.Name else nil,
		MVP = if mvp then { Name = mvp.Name, Coins = mvp.Coins, KOs = mvp.KOs } else nil,
		LastSurvivor = if roundStats.LastSurvivor and roundStats.LastSurvivor.Alive and winner ~= "Murderer" then roundStats.LastSurvivor.Name else nil,
		Map = self.MapDef and self.MapDef.Name or "",
	})
	for _, actor in self.Actors do
		services.CombatService:StripWeapons(actor)
	end
end

function RoundService:Cleanup()
	local services = self.Services
	-- Zuerst alle aus den Schraenken holen (ohne Teleport): sonst landen Versteckte nach dem Lobby-Teleport
	-- wieder vor dem Schrank auf der Karte, die gleich geloescht wird, und fallen ins Leere
	services.MapService:ReleaseAllClosets()
	clearModifier()
	for _, actor in self.Actors do
		if actor.Player then
			actor.Player:SetAttribute("InRound", false)
			local character = actor.Player.Character
			if character and character == actor.Model and actor.Alive then
				services.CombatService:ResetActor(actor)
				local spawn = workspace:FindFirstChild("Lobby") and workspace.Lobby:FindFirstChild("LobbySpawn")
				if spawn then
					character:PivotTo(spawn.CFrame * CFrame.new(math.random(-8, 8), 4, math.random(-8, 8)))
				end
			end
			services.Net.Role:FireClient(actor.Player, "Clear", nil)
		end
		actor.Model:SetAttribute("ActorId", nil)
		CollectionService:RemoveTag(actor.Model, "Actor")
	end
	services.BotService:Clear()
	table.clear(self.Actors)
	services.MapService:UnloadMap()
	self.Map = nil
	publishAlive()
end

---------------------------------------------------------------- Spieler

function RoundService:OnPlayerLeft(player: Player)
	votes[player] = nil
	guesses[player] = nil
	local actor = self:ActorOfPlayer(player)
	if actor and actor.Alive then
		actor.Alive = false
		publishAlive()
		if actor.Role == "Sheriff" or actor.Role == "Hero" then
			self.Services.CombatService:DropGun(actor.Root.Position)
		end
		self:CheckWin()
		self:CheckLastSurvivor()
	end
end

function RoundService:Init(services)
	self.Services = services
	local Net = services.Net
	Net.Handle("Vote", function(player, index)
		if self.State ~= "Intermission" or typeof(index) ~= "number" or not table.find(mapOptions, index) then
			return { Ok = false }
		end
		votes[player] = index
		publishVotes()
		return { Ok = true }
	end)
	Net.Handle("Guess", function(player, id)
		if self.State ~= "Playing" or typeof(id) ~= "number" or guesses[player] then
			return { Ok = false, Error = "Already guessed" }
		end
		local own = self:ActorOfPlayer(player)
		if own and own.Alive then
			return { Ok = false, Error = "Only for ghosts and the lobby" }
		end
		local target = self.Actors[id]
		if not target or not target.Alive then
			return { Ok = false, Error = "Pick someone alive" }
		end
		guesses[player] = id
		return { Ok = true }
	end)
	Net.Handle("AFK", function(player, on)
		player:SetAttribute("AFK", on == true)
		return { Ok = true }
	end)
	Net.Handle("Charm", function(player, role)
		return self:BuyCharm(player, role)
	end)
	Players.PlayerRemoving:Connect(function(player)
		tickets[player.UserId] = nil
		charms[player.UserId] = nil
	end)
end

function RoundService:Start()
	setState("Intermission", 0)
	task.spawn(function()
		while true do
			self:Loop()
		end
	end)
	task.spawn(function()
		while true do
			self:PublishEvent()
			task.wait(1)
		end
	end)
end

function RoundService:Loop()
	-- Lobby
	pickMapOptions()
	setState("Intermission", workspace:GetServerTimeNow() + R.Intermission)
	local oddsAt = 0
	while workspace:GetServerTimeNow() < self.EndsAt do
		if os.clock() - oddsAt > 4 then
			oddsAt = os.clock()
			self:SendOdds()
		end
		task.wait(0.5)
	end
	if not self:StartRound() then
		task.wait(3)
		return
	end
	-- Rollenkarte
	task.wait(R.RevealTime)
	if self.State == "Reveal" then
		self:BeginPlay()
	end
	-- Runde
	while self.State == "Playing" do
		if workspace:GetServerTimeNow() >= self.EndsAt then
			self:EndRound("Innocents", "Time ran out - the innocents survived!")
			break
		end
		task.wait(0.25)
	end
	if self.State == "Reveal" then
		-- alle Murderer haben schon waehrend der Rollenkarte verlassen
		self:CheckWin()
	end
	task.wait(R.ResultsTime)
	self:Cleanup()
end

return RoundService
