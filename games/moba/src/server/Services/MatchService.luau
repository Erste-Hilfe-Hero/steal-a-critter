-- Rundenablauf: Heldenwahl -> Kampf -> Ergebnis, Teams, Bots auffuellen, Belohnungen.
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
}

local state: Folder

local function now()
	return workspace:GetServerTimeNow()
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
	-- zufaellig mischen, dann abwechselnd verteilen
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

-- Gewaehlter Held, falls im Besitz; sonst der letzte, sonst ein freier
function MatchService:ChosenHero(player: Player): string
	local data = self.Services.DataService
	local picked = player:GetAttribute("PickedHero")
	if typeof(picked) == "string" and data:OwnsHero(player, picked) then
		return picked
	end
	local saved = data:Get(player)
	if saved and data:OwnsHero(player, saved.LastHero) then
		return saved.LastHero
	end
	return "Brakka"
end

local function freeLane(heroes, team: number): string
	local used = {}
	for _, hero in heroes do
		if hero.Team == team then
			used[hero.Lane] = (used[hero.Lane] or 0) + 1
		end
	end
	local want = { Top = 2, Mid = 1, Bot = 2 }
	for _, lane in { "Mid", "Bot", "Top" } do
		if (used[lane] or 0) < want[lane] then
			return lane
		end
	end
	return "Mid"
end

function MatchService:BotName(): string
	local taken = {}
	for _, hero in self.Services.HeroService.Heroes do
		taken[hero.Name] = true
	end
	local names = self.Services.BotService.Names
	for _ = 1, 20 do
		local name = names[math.random(1, #names)]
		if not taken[name] then
			return name
		end
	end
	return "Bot " .. math.random(10, 99)
end

-- Bot-Held, der im Team noch fehlt (keine doppelten Helden pro Team)
local function botHero(heroes, team: number): string
	local used = {}
	for _, hero in heroes do
		if hero.Team == team then
			used[hero.HeroId] = true
		end
	end
	local options = {}
	for _, def in Config.Heroes do
		if not used[def.Id] then
			table.insert(options, def.Id)
		end
	end
	return if #options > 0 then options[math.random(1, #options)] else Config.Heroes[math.random(1, #Config.Heroes)].Id
end

function MatchService:CreatePlayerHero(player: Player, team: number, inherit)
	local data = self.Services.DataService:Get(player)
	local heroes = self.Services.HeroService
	local info = inherit or {}
	local hero = heroes:Create({
		Team = team,
		HeroId = self:ChosenHero(player),
		Player = player,
		Name = player.DisplayName,
		Lane = info.Lane or freeLane(heroes.Heroes, team),
		Skin = data and data.Skin or "Default",
		AutoBuy = if data then data.AutoBuy else true,
		Level = info.Level,
		XP = info.XP,
		Gold = info.Gold,
		Items = info.Items,
	})
	player:SetAttribute("Lane", hero.Lane)
	self.Participants[player] = true
	return hero
end

function MatchService:CreateBot(team: number, inherit)
	local heroes = self.Services.HeroService
	local info = inherit or {}
	local hero = heroes:Create({
		Team = team,
		HeroId = botHero(heroes.Heroes, team),
		Name = self:BotName(),
		Lane = info.Lane or freeLane(heroes.Heroes, team),
		Level = info.Level,
		XP = info.XP,
		Gold = info.Gold,
		Items = info.Items,
	})
	hero.DamageScale = self.Services.BotService.DamageScale
	return hero
end

local function inheritFrom(hero)
	return { Lane = hero.Lane, Level = hero.Level, XP = hero.XP, Gold = hero.Gold, Items = table.clone(hero.Items) }
end

---------------------------------------------------------------- Ein- und Austritt waehrend der Runde

function MatchService:OnPlayerReady(player: Player)
	player:SetAttribute("Loaded", true)
	local data = self.Services.DataService:Get(player)
	player:SetAttribute("PickedHero", data and data.LastHero or "Brakka")
	player:SetAttribute("Locked", false)
	if self.Phase == "Pick" then
		player:SetAttribute("Team", self:SmallerTeam())
	elseif self.Phase == "Playing" then
		-- Einen Bot im kleineren Team uebernehmen (mit dessen Stufe und Gold)
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
			heroes:Spawn(self:CreateBot(team, inherit))
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
	self.Services.Net.SendAnnounce(`{string.upper(Config.Teams[winner].Name)} WINS!`, Config.Teams[winner].Color)
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
		HeroId = hero.HeroId,
		Level = hero.Level,
	})
	task.spawn(dataService.Save, dataService, player)
	self.Services.MonetizationService:AfterMatch(player, won)
end

---------------------------------------------------------------- Ablauf

function MatchService:Reset()
	self.Services.HeroService:RemoveAll()
	self.Services.LaneService:Build()
	self.Kills = { 0, 0 }
	self.TowersDestroyed = { 0, 0 }
	self.Winner = 0
	self.StartedAt = 0
	self.Participants = {}
	self:Publish()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Hero", nil)
		player:SetAttribute("Dead", nil)
	end
end

function MatchService:RunPick()
	self:Reset()
	self:AssignTeams()
	for _, player in Players:GetPlayers() do
		player:SetAttribute("Locked", false)
		local data = self.Services.DataService:Get(player)
		player:SetAttribute("PickedHero", data and data.LastHero or "Brakka")
	end
	self:SetPhase("Pick", Config.PickSeconds)
	local deadline = os.clock() + Config.PickSeconds
	while os.clock() < deadline do
		task.wait(0.5)
		-- Alle Spieler fertig: nach kurzer Pause starten
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
		local count = 0
		for _, hero in heroes.Heroes do
			if hero.Team == team then
				count += 1
			end
		end
		for _ = count + 1, Config.TeamSize do
			self:CreateBot(team)
		end
	end
	self.StartedAt = now()
	self:Publish()
	self:SetPhase("Playing")
	for _, hero in table.clone(heroes.Heroes) do
		task.spawn(heroes.Spawn, heroes, hero)
	end
	self.Services.LaneService:StartMatch()
	self.Services.Net.SendAnnounce("Destroy the enemy Core!", Color3.fromRGB(255, 240, 200))
end

function MatchService:RunPlaying()
	local overtime = false
	while self.Phase == "Playing" do
		task.wait(1)
		local elapsed = now() - self.StartedAt
		if #readyPlayers() == 0 then
			-- Niemand mehr da: Runde abbrechen
			self.Phase = "Waiting"
			self.Services.LaneService:Stop()
			return
		end
		if not overtime and elapsed >= Config.OvertimeAt then
			overtime = true
			self.Services.LaneService:SetOvertime()
			self.Services.Net.SendAnnounce("OVERTIME! Minions are enraged!", Color3.fromRGB(255, 110, 90))
		end
		if elapsed >= Config.MaxMatchSeconds then
			local lane = self.Services.LaneService
			local winner
			if self.TowersDestroyed[1] ~= self.TowersDestroyed[2] then
				winner = if self.TowersDestroyed[1] > self.TowersDestroyed[2] then 1 else 2
			elseif self.Kills[1] ~= self.Kills[2] then
				winner = if self.Kills[1] > self.Kills[2] then 1 else 2
			else
				local a, b = lane.Cores[1], lane.Cores[2]
				winner = if a and b and a.HP < b.HP then 2 else 1
			end
			self:EndMatch(winner)
		end
	end
end

function MatchService:Start()
	self.Services.Net.PickHero.OnServerEvent:Connect(function(player, heroId, lock)
		if self.Phase ~= "Pick" or typeof(heroId) ~= "string" then
			return
		end
		if not self.Services.DataService:OwnsHero(player, heroId) then
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
