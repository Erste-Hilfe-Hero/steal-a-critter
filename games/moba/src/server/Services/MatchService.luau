-- Rundenablauf: Rollen-, Helden- und Zauberwahl -> Kampf -> Ergebnis. Teams, Bots fuellen freie Rollen,
-- Aufgeben-Abstimmung, Verlaengerung und Belohnungen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MatchService = {
	Services = nil :: any,
	Phase = "Waiting",
	StartedAt = 0,
	Kills = { 0, 0 },
	TowersDestroyed = { 0, 0 },
	Winner = 0,
	Participants = {} :: { [Player]: boolean },
	Votes = { [1] = nil, [2] = nil } :: { [number]: any },
}

local state: Folder
local ROLE_ORDER = { "Top", "Jungle", "Mid", "Bot", "Support" }

local function now()
	return workspace:GetServerTimeNow()
end

local function enemyOf(team: number): number
	return if team == 1 then 2 else 1
end

function MatchService:Init(services)
	self.Services = services
	local existing = ReplicatedStorage:FindFirstChild("Match")
	if not existing then
		existing = Instance.new("Folder")
		existing.Name = "Match"
		existing.Parent = ReplicatedStorage
	end
	state = existing :: Folder
end

function MatchService:IsPlaying(): boolean
	return self.Phase == "Playing"
end

-- Sekunden seit Spielbeginn (Spieluhr)
function MatchService:Elapsed(): number
	if self.StartedAt <= 0 or (self.Phase ~= "Playing" and self.Phase ~= "End") then
		return 0
	end
	return now() - self.StartedAt
end

function MatchService:SetPhase(phase: string, seconds: number?)
	self.Phase = phase
	state:SetAttribute("Phase", phase)
	state:SetAttribute("PhaseEnd", if seconds then now() + seconds else 0)
end

function MatchService:Publish()
	state:SetAttribute("Kills1", self.Kills[1])
	state:SetAttribute("Kills2", self.Kills[2])
	state:SetAttribute("Towers1", self.TowersDestroyed[1])
	state:SetAttribute("Towers2", self.TowersDestroyed[2])
	state:SetAttribute("StartedAt", self.StartedAt)
	state:SetAttribute("Winner", self.Winner)
end

---------------------------------------------------------------- Teams

local function readyPlayers()
	local list = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("Loaded") then
			table.insert(list, player)
		end
	end
	return list
end

function MatchService:HumansOnTeam(team: number): number
	local count = 0
	for _, player in readyPlayers() do
		if player:GetAttribute("Team") == team then
			count += 1
		end
	end
	return count
end

function MatchService:AssignTeams()
	local players = readyPlayers()
	for i = #players, 2, -1 do
		local j = math.random(1, i)
		players[i], players[j] = players[j], players[i]
	end
	for index, player in players do
		player:SetAttribute("Team", if index % 2 == 1 then 1 else 2)
	end
end

function MatchService:SmallerTeam(): number
	local a, b = self:HumansOnTeam(1), self:HumansOnTeam(2)
	if a == b then
		return math.random(1, 2)
	end
	return if a < b then 1 else 2
end

-- Rollen, die im Team schon ein Mensch gewaehlt hat
local function takenRoles(team: number, except: Player?): { [string]: boolean }
	local taken = {}
	for _, player in readyPlayers() do
		if player ~= except and player:GetAttribute("Team") == team then
			local role = player:GetAttribute("Role")
			if typeof(role) == "string" then
				taken[role] = true
			end
		end
	end
	return taken
end

local function freeRole(team: number, wanted: string?, except: Player?): string
	local taken = takenRoles(team, except)
	if wanted and Config.RolesById[wanted] and not taken[wanted] then
		return wanted
	end
	for _, role in ROLE_ORDER do
		if not taken[role] then
			return role
		end
	end
	return "Mid"
end

-- Helden, die in dieser Runde schon jemand hat (keine doppelten Helden, wie im Draft)
local function pickedHeroes(except: Player?): { [string]: boolean }
	local picked = {}
	for _, player in readyPlayers() do
		if player ~= except and player:GetAttribute("Locked") then
			local id = player:GetAttribute("PickedHero")
			if typeof(id) == "string" then
				picked[id] = true
			end
		end
	end
	return picked
end

-- Gewaehlter Held, falls im Besitz und frei; sonst einer, der zur Rolle passt
function MatchService:ChosenHero(player: Player): string
	local data = self.Services.DataService
	local taken = {}
	for _, hero in self.Services.HeroService.Heroes do
		taken[hero.HeroId] = true
	end
	local picked = player:GetAttribute("PickedHero")
	if typeof(picked) == "string" and data:OwnsHero(player, picked) and not taken[picked] then
		return picked
	end
	local role = player:GetAttribute("Role")
	for _, def in Config.Heroes do
		if data:OwnsHero(player, def.Id) and not taken[def.Id] and table.find(def.Roles, role) then
			return def.Id
		end
	end
	for _, def in Config.Heroes do
		if data:OwnsHero(player, def.Id) and not taken[def.Id] then
			return def.Id
		end
	end
	return "Brakka"
end

function MatchService:BotName(): string
	local taken = {}
	for _, hero in self.Services.HeroService.Heroes do
		taken[hero.Name] = true
	end
	local names = self.Services.BotService.Names
	for _ = 1, 30 do
		local name = names[math.random(1, #names)]
		if not taken[name] then
			return name
		end
	end
	return "Bot " .. math.random(10, 99)
end

-- Bot-Held fuer eine Rolle (keine doppelten Helden in der Runde)
local function botHero(heroes, role: string): string
	local used = {}
	for _, hero in heroes do
		used[hero.HeroId] = true
	end
	local fits, others = {}, {}
	for _, def in Config.Heroes do
		if not used[def.Id] then
			table.insert(if table.find(def.Roles, role) then fits else others, def.Id)
		end
	end
	local options = if #fits > 0 then fits else others
	return if #options > 0 then options[math.random(1, #options)] else Config.Heroes[math.random(1, #Config.Heroes)].Id
end

local function spellsFor(player: Player?, role: string)
	local d, f = "Flash", Config.DefaultSpells[role] or "Heal"
	if player then
		local pd, pf = player:GetAttribute("SpellD"), player:GetAttribute("SpellF")
		if typeof(pd) == "string" and Config.SpellsById[pd] then
			d = pd
		end
		if typeof(pf) == "string" and Config.SpellsById[pf] and pf ~= d then
			f = pf
		end
	end
	if role == "Jungle" and d ~= "Smite" and f ~= "Smite" then
		f = "Smite"
	end
	return { D = d, F = f }
end

function MatchService:CreatePlayerHero(player: Player, team: number, inherit)
	local data = self.Services.DataService:Get(player)
	local heroes = self.Services.HeroService
	local role = if inherit then inherit.Role else freeRole(team, player:GetAttribute("Role") :: string?, player)
	player:SetAttribute("Role", role)
	local hero = heroes:Create({
		Team = team,
		HeroId = self:ChosenHero(player),
		Player = player,
		Name = player.DisplayName,
		Role = role,
		Spells = spellsFor(player, role),
		Skin = data and data.Skin or "Default",
		AutoBuy = if data then data.AutoBuy else true,
	})
	if inherit then
		self:Inherit(hero, inherit)
	end
	self.Participants[player] = true
	return hero
end

function MatchService:CreateBot(team: number, role: string, inherit)
	local heroes = self.Services.HeroService
	local hero = heroes:Create({
		Team = team,
		HeroId = botHero(heroes.Heroes, role),
		Name = self:BotName(),
		Role = role,
		Spells = spellsFor(nil, role),
	})
	hero.DamageScale = self.Services.BotService.DamageScale
	if inherit then
		self:Inherit(hero, inherit)
	end
	return hero
end

local function inheritFrom(hero)
	return {
		Role = hero.Role,
		Level = hero.Level,
		XP = hero.XP,
		Gold = hero.Gold,
		Items = table.clone(hero.Items),
		Potions = hero.Potions,
		Kills = hero.Kills,
		Deaths = hero.Deaths,
		Assists = hero.Assists,
		CreepScore = hero.CreepScore,
	}
end

-- Wer einen Platz uebernimmt, bekommt Stufe, Gold und Items
function MatchService:Inherit(hero, info)
	hero.Gold = info.Gold
	hero.Items = info.Items
	hero.Potions = info.Potions
	hero.Kills, hero.Deaths, hero.Assists, hero.CreepScore = info.Kills, info.Deaths, info.Assists, info.CreepScore
	hero.Ranks = { Q = 0, W = 0, E = 0, R = 0 }
	hero.Level = info.Level
	hero.XP = info.XP
	hero.SkillPoints = info.Level
	self.Services.HeroService:AutoLevel(hero)
	self.Services.HeroService:Recompute(hero)
end

---------------------------------------------------------------- Ein- und Austritt waehrend der Runde

function MatchService:OnPlayerReady(player: Player)
	player:SetAttribute("Loaded", true)
	local data = self.Services.DataService:Get(player)
	player:SetAttribute("PickedHero", data and data.LastHero or "Brakka")
	player:SetAttribute("Locked", false)
	if data and typeof(data.LastRole) == "string" then
		player:SetAttribute("Role", data.LastRole)
	end
	if self.Phase == "Pick" then
		local team = self:SmallerTeam()
		player:SetAttribute("Team", team)
		player:SetAttribute("Role", freeRole(team, player:GetAttribute("Role") :: string?, player))
	elseif self.Phase == "Playing" then
		-- Einen Bot im kleineren Team uebernehmen (mit dessen Rolle, Stufe und Gold)
		local team = self:SmallerTeam()
		player:SetAttribute("Team", team)
		local heroes = self.Services.HeroService
		local bot
		for _, hero in heroes.Heroes do
			if hero.Bot and hero.Team == team then
				bot = hero
				break
			end
		end
		local inherit = if bot then inheritFrom(bot) else nil
		if bot then
			heroes:Remove(bot)
		end
		local hero = self:CreatePlayerHero(player, team, inherit)
		heroes:Spawn(hero)
	end
end

function MatchService:OnPlayerRemoving(player: Player)
	self.Participants[player] = nil
	local heroes = self.Services.HeroService
	local hero = heroes:GetByPlayer(player)
	if hero then
		local inherit = inheritFrom(hero)
		local team = hero.Team
		heroes:Remove(hero)
		if self.Phase == "Playing" then
			heroes:Spawn(self:CreateBot(team, inherit.Role, inherit))
		end
	end
end

---------------------------------------------------------------- Ereignisse

function MatchService:OnHeroKill(team: number, _killer)
	if self.Phase ~= "Playing" then
		return
	end
	self.Kills[team] += 1
	self:Publish()
end

function MatchService:OnTowerDestroyed(team: number)
	self.TowersDestroyed[team] += 1
	self:Publish()
end

function MatchService:EndMatch(winner: number)
	if self.Phase ~= "Playing" then
		return
	end
	self.Winner = winner
	self:Publish()
	self:SetPhase("End", Config.EndSeconds)
	self.Services.LaneService:Stop()
	self.Services.JungleService:Stop()
	self.Services.Net.SendAnnounce(if winner == 1 then "VICTORY FOR DAWN!" else "VICTORY FOR DUSK!", Config.Teams[winner].Color)
	local heroes = self.Services.HeroService
	for _, hero in heroes.Heroes do
		if hero.Humanoid then
			hero.Humanoid.WalkSpeed = 0
		end
	end
	for player in self.Participants do
		if player.Parent then
			local hero = heroes:GetByPlayer(player)
			if hero then
				self:Reward(player, hero, hero.Team == winner)
			end
		end
	end
end

function MatchService:Reward(player: Player, hero, won: boolean)
	local dataService = self.Services.DataService
	local data = dataService:Get(player)
	if not data then
		return
	end
	local rewards = Config.Rewards
	local base = if won then rewards.Win else rewards.Loss
	local bonus = math.min(rewards.MaxKillBonus, hero.Kills * rewards.PerKill + hero.Assists * rewards.PerAssist)
	local today = dataService.Today()
	local firstWin = won and data.LastWinDay < today
	local multiplier = 1
	if data.Passes.Pass_VIP then
		multiplier *= 1.5
	end
	if data.Passes.Pass_DoubleCrystals then
		multiplier *= 2
	end
	local total = math.floor((base + bonus + (if firstWin then rewards.FirstWinBonus else 0)) * multiplier)
	data.Matches += 1
	data.Kills += hero.Kills
	data.Deaths += hero.Deaths
	data.Assists += hero.Assists
	if won then
		data.Wins += 1
		data.LastWinDay = today
	end
	dataService:AddCrystals(player, total)
	self.Services.Net.MatchResult:FireClient(player, {
		Won = won,
		Crystals = total,
		Base = base,
		Bonus = bonus,
		FirstWin = firstWin,
		Multiplier = multiplier,
		Kills = hero.Kills,
		Deaths = hero.Deaths,
		Assists = hero.Assists,
		CS = hero.CreepScore,
		HeroId = hero.HeroId,
		Level = hero.Level,
		Minutes = math.floor(self:Elapsed() / 60),
	})
	task.spawn(dataService.Save, dataService, player)
	self.Services.MonetizationService:AfterMatch(player, won)
end

---------------------------------------------------------------- Aufgeben

function MatchService:Vote(player: Player, yes: boolean)
	if self.Phase ~= "Playing" then
		return
	end
	local team = player:GetAttribute("Team")
	if team ~= 1 and team ~= 2 then
		return
	end
	local net = self.Services.Net
	local vote = self.Votes[team]
	if not vote then
		if not yes then
			return
		end
		if self:Elapsed() < Config.Timers.Surrender then
			net.SendNotify(player, `You can surrender after {math.floor(Config.Timers.Surrender / 60)} minutes.`, Color3.fromRGB(255, 120, 120))
			return
		end
		if now() < (self.VoteCooldown and self.VoteCooldown[team] or 0) then
			net.SendNotify(player, "Wait a bit before voting again.", Color3.fromRGB(255, 120, 120))
			return
		end
		vote = { Yes = {}, No = {}, Ends = now() + 30 }
		self.Votes[team] = vote
		task.delay(30, function()
			if self.Votes[team] == vote then
				self:FinishVote(team, false)
			end
		end)
	end
	vote.Yes[player] = if yes then true else nil
	vote.No[player] = if yes then nil else true
	self:CheckVote(team)
end

function MatchService:CheckVote(team: number)
	local vote = self.Votes[team]
	if not vote then
		return
	end
	local humans, yes, no = 0, 0, 0
	for _, player in readyPlayers() do
		if player:GetAttribute("Team") == team then
			humans += 1
			if vote.Yes[player] then
				yes += 1
			elseif vote.No[player] then
				no += 1
			end
		end
	end
	-- Bots stimmen mit der Mehrheit der Menschen; 70 % der Menschen muessen zustimmen
	local needed = math.max(1, math.ceil(humans * 0.7))
	state:SetAttribute("Vote" .. team, `{yes}/{needed}`)
	state:SetAttribute("VoteEnds" .. team, vote.Ends)
	for _, player in readyPlayers() do
		if player:GetAttribute("Team") == team then
			self.Services.Net.SendNotify(player, `Surrender vote: {yes} yes, {no} no ({needed} needed)`, Color3.fromRGB(255, 220, 140))
		end
	end
	if yes >= needed then
		self:FinishVote(team, true)
	elseif humans - no < needed then
		self:FinishVote(team, false)
	end
end

function MatchService:FinishVote(team: number, passed: boolean)
	self.Votes[team] = nil
	self.VoteCooldown = self.VoteCooldown or {}
	self.VoteCooldown[team] = now() + 90
	state:SetAttribute("Vote" .. team, "")
	if passed then
		self.Services.Net.SendAnnounce(`{Config.Teams[team].Name} has surrendered`, Config.Teams[team].Color)
		task.delay(2, function()
			self:EndMatch(enemyOf(team))
		end)
	end
end

---------------------------------------------------------------- Ablauf

function MatchService:Reset()
	self.Services.HeroService:RemoveAll()
	self.Services.LaneService:Build()
	self.Services.JungleService:Clear()
	self.Kills = { 0, 0 }
	self.TowersDestroyed = { 0, 0 }
	self.Winner = 0
	self.StartedAt = 0
	self.Participants = {}
	self.Votes = {}
	self.VoteCooldown = {}
	self:Publish()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Hero", nil)
		player:SetAttribute("Dead", nil)
	end
end

function MatchService:RunPick()
	self:Reset()
	self:AssignTeams()
	for _, player in readyPlayers() do
		player:SetAttribute("Locked", false)
		local data = self.Services.DataService:Get(player)
		player:SetAttribute("PickedHero", data and data.LastHero or "Brakka")
	end
	-- Rollen verteilen: Wunschrolle, wenn im Team noch frei
	for _, player in readyPlayers() do
		player:SetAttribute("Role", nil)
	end
	for _, player in readyPlayers() do
		local data = self.Services.DataService:Get(player)
		local team = player:GetAttribute("Team") :: number
		local role = freeRole(team, data and data.LastRole, player)
		player:SetAttribute("Role", role)
		if typeof(player:GetAttribute("SpellD")) ~= "string" then
			player:SetAttribute("SpellD", "Flash")
		end
		player:SetAttribute("SpellF", if player:GetAttribute("SpellD") == Config.DefaultSpells[role] then "Flash" else Config.DefaultSpells[role])
	end
	self:SetPhase("Pick", Config.PickSeconds)
	local deadline = os.clock() + Config.PickSeconds
	while os.clock() < deadline do
		task.wait(0.5)
		local all = true
		local players = readyPlayers()
		for _, player in players do
			if not player:GetAttribute("Locked") then
				all = false
			end
		end
		if all and #players > 0 and deadline - os.clock() > 3 then
			deadline = os.clock() + 3
			state:SetAttribute("PhaseEnd", now() + 3)
		end
		if #players == 0 then
			return false
		end
	end
	return true
end

function MatchService:StartPlaying()
	local heroes = self.Services.HeroService
	for _, player in readyPlayers() do
		local team = player:GetAttribute("Team")
		if team ~= 1 and team ~= 2 then
			team = self:SmallerTeam()
			player:SetAttribute("Team", team)
		end
		if heroes:GetByPlayer(player) == nil then
			self:CreatePlayerHero(player, team)
		end
	end
	for team = 1, 2 do
		local filled = {}
		for _, hero in heroes.Heroes do
			if hero.Team == team then
				filled[hero.Role] = true
			end
		end
		for _, role in ROLE_ORDER do
			if not filled[role] then
				self:CreateBot(team, role)
			end
		end
	end
	self.StartedAt = now()
	self:Publish()
	self:SetPhase("Playing")
	for _, hero in table.clone(heroes.Heroes) do
		task.spawn(heroes.Spawn, heroes, hero)
	end
	self.Services.LaneService:StartMatch()
	self.Services.JungleService:StartMatch()
	self.Services.Net.SendAnnounce("Welcome to the Rift!", Color3.fromRGB(255, 240, 200))
	task.delay(Config.Timers.Minions - 15, function()
		if self.Phase == "Playing" then
			self.Services.Net.SendAnnounce("15 seconds until minions spawn!", Color3.fromRGB(240, 240, 255))
		end
	end)
end

function MatchService:RunPlaying()
	local overtime = false
	while self.Phase == "Playing" do
		task.wait(1)
		local elapsed = self:Elapsed()
		if #readyPlayers() == 0 then
			-- Niemand mehr da: Runde abbrechen
			self.Phase = "Waiting"
			self.Services.LaneService:Stop()
			self.Services.JungleService:Stop()
			return
		end
		if not overtime and elapsed >= Config.Timers.Overtime then
			overtime = true
			self.Services.LaneService:SetOvertime()
			self.Services.Net.SendAnnounce("Minions are enraged!", Color3.fromRGB(255, 110, 90))
		end
		if elapsed >= Config.Timers.MaxMatch then
			local lane = self.Services.LaneService
			local winner
			if self.TowersDestroyed[1] ~= self.TowersDestroyed[2] then
				winner = if self.TowersDestroyed[1] > self.TowersDestroyed[2] then 1 else 2
			elseif self.Kills[1] ~= self.Kills[2] then
				winner = if self.Kills[1] > self.Kills[2] then 1 else 2
			else
				local a, b = lane.Nexus[1], lane.Nexus[2]
				winner = if a and b and a.HP < b.HP then 2 else 1
			end
			self:EndMatch(winner)
		end
	end
end

function MatchService:Start()
	local net = self.Services.Net
	net.PickHero.OnServerEvent:Connect(function(player, heroId, lock)
		if self.Phase ~= "Pick" or typeof(heroId) ~= "string" or player:GetAttribute("Locked") then
			return
		end
		if not self.Services.DataService:OwnsHero(player, heroId) then
			return
		end
		if pickedHeroes(player)[heroId] then
			net.SendNotify(player, "Someone already locked in that hero!", Color3.fromRGB(255, 120, 120))
			return
		end
		player:SetAttribute("PickedHero", heroId)
		if lock == true then
			player:SetAttribute("Locked", true)
		end
		local data = self.Services.DataService:Get(player)
		if data then
			data.LastHero = heroId
		end
	end)
	net.PickRole.OnServerEvent:Connect(function(player, role)
		if self.Phase ~= "Pick" or typeof(role) ~= "string" or not Config.RolesById[role] or player:GetAttribute("Locked") then
			return
		end
		local team = player:GetAttribute("Team") :: number
		if takenRoles(team, player)[role] then
			net.SendNotify(player, "A teammate already plays that role.", Color3.fromRGB(255, 120, 120))
			return
		end
		player:SetAttribute("Role", role)
		local data = self.Services.DataService:Get(player)
		if data then
			data.LastRole = role
		end
		local spellF = Config.DefaultSpells[role]
		if spellF and player:GetAttribute("SpellD") ~= spellF then
			player:SetAttribute("SpellF", spellF)
		end
	end)
	net.PickSpell.OnServerEvent:Connect(function(player, slot, spellId)
		if self.Phase ~= "Pick" or (slot ~= "D" and slot ~= "F") or typeof(spellId) ~= "string" or not Config.SpellsById[spellId] then
			return
		end
		local other = if slot == "D" then "F" else "D"
		if player:GetAttribute("Spell" .. other) == spellId then
			player:SetAttribute("Spell" .. other, player:GetAttribute("Spell" .. slot))
		end
		player:SetAttribute("Spell" .. slot, spellId)
	end)
	net.Surrender.OnServerEvent:Connect(function(player, yes)
		self:Vote(player, yes ~= false)
	end)

	task.spawn(function()
		while true do
			self:SetPhase("Waiting")
			while #readyPlayers() == 0 do
				task.wait(1)
			end
			if self:RunPick() then
				self:StartPlaying()
				self:RunPlaying()
				if self.Phase == "End" then
					task.wait(Config.EndSeconds)
				end
			end
		end
	end)
end

return MatchService
