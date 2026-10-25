-- Fortschritt (Update 2): Erfolge mit Titeln, Tagesaufgaben, Medaillen, vom Server gemessenes Hoechsttempo,
-- Codes, Gluecks-Schneeball und gespeicherte Einstellungen. Der Client bekommt alles als Paket (ProgressSync).
-- Alles, was der Client schickt, wird hier geprueft (Typen, Besitz, Tag, Abklingzeit).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Progression = require(ReplicatedStorage.Shared.Progression)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)

local ProgressService = { Services = nil :: any }

local THEME = Config.Theme
local dirty = {} -- [Player] = true: Paket muss neu geschickt werden
local lastAction = {} -- [Player] = os.clock() der letzten Anfrage
local speedSamples = {} -- [Player] = { Position, Time, Speed }
local random = Random.new()

function ProgressService:Init(services)
	self.Services = services
end

local function today(): number
	return os.time() // 86400
end

local function dataOf(player: Player)
	return ProgressService.Services.DataService:Get(player)
end

---------------------------------------------------------------- Tagesaufgaben

-- Neuer Tag = neue Aufgaben (Fortschritt von gestern verfaellt)
local function ensureQuests(player: Player, data)
	local day = today()
	if data.Quest.Day ~= day then
		data.Quest = { Day = day, Ids = Progression.QuestsFor(day, player.UserId), Progress = {}, Claimed = {} }
		dirty[player] = true
	end
	return data.Quest
end

-- kind: Art der Aufgabe, value: Anzahl (zaehlt hoch) oder bei "Speed" der erreichte Wert (Maximum)
function ProgressService:AddQuest(player: Player, kind: string, value: number)
	local data = dataOf(player)
	if not data then
		return
	end
	local quest = ensureQuests(player, data)
	for _, id in quest.Ids do
		local def = Progression.QuestById[id]
		if def and def.Kind == kind and not quest.Claimed[id] then
			local before = quest.Progress[id] or 0
			local after = if kind == "Speed" then math.max(before, value) else before + value
			after = math.min(after, def.Goal)
			if after ~= before then
				quest.Progress[id] = after
				dirty[player] = true
				if before < def.Goal and after >= def.Goal then
					self.Services.Net.SendNotify(player, `Quest complete: {def.Text}! Claim it in MORE > Quests.`, THEME.Mint)
				end
			end
		end
	end
end

local function claimQuest(player: Player, data, id: string)
	local quest = ensureQuests(player, data)
	local def = Progression.QuestById[id]
	if not def or not table.find(quest.Ids, id) or quest.Claimed[id] or (quest.Progress[id] or 0) < def.Goal then
		return
	end
	quest.Claimed[id] = true
	data.QuestsDone += 1
	local amount = ProgressService.Services.DataService:AddFlakes(player, def.Reward, false)
	ProgressService.Services.Net.SendNotify(player, `+{Format.Number(amount)} Snowflakes for "{def.Text}"`, THEME.Gold)
	dirty[player] = true
	ProgressService:Evaluate(player)
end

---------------------------------------------------------------- Erfolge

local function goldMedals(data): number
	local count = 0
	for _, medal in data.Medals do
		if medal >= 3 then
			count += 1
		end
	end
	return count
end

local function buddyCount(data): number
	local count = 0
	for id, owned in data.Buddies do
		if owned and id ~= "none" then
			count += 1
		end
	end
	return count
end

local function reached(data, achievement): boolean
	local kind, goal = achievement.Kind, achievement.Goal
	if kind == "Clears" then
		return data.Clears >= goal
	elseif kind == "MaxStage" then
		return data.MaxStage >= goal
	elseif kind == "MapClears" then
		return data.MapClears >= goal
	elseif kind == "TopSpeed" then
		return data.TopSpeed >= goal
	elseif kind == "BestTimeUnder" then
		return data.BestTime > 0 and data.BestTime < goal
	elseif kind == "GoldMedals" then
		return goldMedals(data) >= goal
	elseif kind == "QuestsDone" then
		return data.QuestsDone >= goal
	elseif kind == "PlayMinutes" then
		return data.PlayTime >= goal * 60
	elseif kind == "Streak" then
		return data.DailyStreak >= goal
	elseif kind == "Falls" then
		return data.Falls >= goal
	elseif kind == "Buddies" then
		return buddyCount(data) >= goal
	end
	return false
end

-- Prueft alle Erfolge und vergibt neue (mit Belohnung, Popup und Ansage)
function ProgressService:Evaluate(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	for _, achievement in Progression.Achievements do
		if not data.Achievements[achievement.Id] and reached(data, achievement) then
			data.Achievements[achievement.Id] = true
			self.Services.DataService:AddFlakes(player, achievement.Reward, false)
			self.Services.Net.Reward:FireClient(player, "Achievement", achievement.Id)
			if achievement.Reward >= 1000 then
				self.Services.Net.SendAnnounce(`{player.DisplayName} earned the title "{achievement.Name}"!`, THEME.Mint)
			end
			dirty[player] = true
		end
	end
end

local function applyTitle(player: Player, data)
	local achievement = Progression.AchievementsById[data.Title]
	if not achievement or not data.Achievements[data.Title] then
		data.Title = ""
		player:SetAttribute("Title", nil)
	else
		player:SetAttribute("Title", achievement.Name)
	end
end

local function equipTitle(player: Player, data, id: string)
	if id ~= "" and not data.Achievements[id] then
		return
	end
	data.Title = id
	applyTitle(player, data)
	ProgressService.Services.CosmeticService:Refresh(player)
	dirty[player] = true
end

---------------------------------------------------------------- Medaillen und Stage-Ereignisse

-- Wird von TimerService nach einer sauberen Stage aufgerufen. Gibt Medaille, ob neu, und Bonus zurueck.
function ProgressService:RecordMedal(player: Player, stage: number, seconds: number): (number, boolean, number)
	local data = dataOf(player)
	local medal = Progression.MedalFor(stage, seconds)
	if not data or medal == 0 then
		return medal, false, 0
	end
	local key = tostring(stage)
	local before = data.Medals[key] or 0
	local bonus = 0
	if medal > before then
		data.Medals[key] = medal
		-- Belohnung fuer jede neu erreichte Stufe (Silber nach Bronze, Gold nach Silber ...)
		for tier = before + 1, medal do
			bonus += Progression.Medals[tier].Reward
		end
		if bonus > 0 then
			bonus = self.Services.DataService:AddFlakes(player, bonus, false)
		end
		dirty[player] = true
	end
	if medal >= 2 then
		self:AddQuest(player, "Medal", 1)
	end
	return medal, medal > before, bonus
end

function ProgressService:OnStageClear(player: Player, stage: number, stagePB: boolean)
	self:AddQuest(player, "Clear", 1)
	if stage >= 5 then
		self:AddQuest(player, "ClearHigh", 1)
	end
	if stagePB then
		self:AddQuest(player, "StagePB", 1)
	end
	dirty[player] = true
	self:Evaluate(player)
end

function ProgressService:OnMapClear(player: Player)
	self:AddQuest(player, "Map", 1)
	self:Evaluate(player)
end

function ProgressService:OnMinute(player: Player)
	self:AddQuest(player, "Minutes", 1)
	self:Evaluate(player)
end

function ProgressService:MarkDirty(player: Player)
	dirty[player] = true
end

---------------------------------------------------------------- Codes und Gluecks-Schneeball

local function redeem(player: Player, data, raw: string)
	local services = ProgressService.Services
	local code = string.upper((string.gsub(raw, "%s", "")))
	local amount = Progression.Codes[code]
	if not amount then
		services.Net.SendNotify(player, "That code does not exist.", THEME.Red)
		return
	end
	if data.Codes[code] then
		services.Net.SendNotify(player, "You already used this code.", THEME.Red)
		return
	end
	data.Codes[code] = true
	local given = services.DataService:AddFlakes(player, amount, false)
	services.Net.SendNotify(player, `Code {code}: +{Format.Number(given)} Snowflakes!`, THEME.Gold)
	dirty[player] = true
end

local function spin(player: Player, data)
	local services = ProgressService.Services
	if data.SpinDay >= today() then
		services.Net.SendNotify(player, "Your next free Lucky Snowball is ready tomorrow!", THEME.Red)
		return
	end
	data.SpinDay = today()
	local index = Progression.PickSpin(random:NextNumber())
	local slot = Progression.Spin[index]
	local message
	if slot.Kind == "Flakes" then
		local given = services.DataService:AddFlakes(player, slot.Amount, false)
		message = `+{Format.Number(given)} Snowflakes!`
	elseif slot.Kind == "Boost" then
		services.EventService:AddBoost(player, slot.Seconds)
		message = `Flake Booster: 2x Snowflakes for {slot.Seconds // 60} minutes!`
	elseif slot.Kind == "Buddy" then
		if data.Buddies[slot.Id] then
			local given = services.DataService:AddFlakes(player, slot.Fallback, false)
			message = `You already have the {Progression.BuddiesById[slot.Id].Name}: +{Format.Number(given)} Snowflakes instead!`
		else
			data.Buddies[slot.Id] = true
			services.DataService:UpdateAttributes(player)
			message = `JACKPOT! You won the {Progression.BuddiesById[slot.Id].Name} buddy!`
			services.Net.SendAnnounce(`{player.DisplayName} won the rare {Progression.BuddiesById[slot.Id].Name} from the Lucky Snowball!`, THEME.Aurora)
			ProgressService:Evaluate(player)
		end
	end
	services.Net.Reward:FireClient(player, "Spin", index, message)
	dirty[player] = true
end

---------------------------------------------------------------- Einstellungen

local function saveSettings(data, incoming)
	local clean = {}
	for key, default in Progression.DefaultSettings do
		local value = incoming[key]
		clean[key] = if typeof(value) == "boolean" then value else default
	end
	data.Settings = clean
end

---------------------------------------------------------------- Paket fuer den Client

local function snapshot(player: Player, data)
	local quest = ensureQuests(player, data)
	local quests = {}
	for _, id in quest.Ids do
		table.insert(quests, { Id = id, Progress = quest.Progress[id] or 0, Claimed = quest.Claimed[id] == true })
	end
	local settings = table.clone(Progression.DefaultSettings)
	for key, value in data.Settings do
		if settings[key] ~= nil and typeof(value) == "boolean" then
			settings[key] = value
		end
	end
	return {
		Achievements = table.clone(data.Achievements),
		Title = data.Title,
		Quests = quests,
		Medals = table.clone(data.Medals),
		SpinReady = data.SpinDay < today(),
		Settings = settings,
		Stats = {
			Clears = data.Clears,
			MapClears = data.MapClears,
			Falls = data.Falls,
			PlayTime = data.PlayTime,
			TopSpeed = data.TopSpeed,
			BestTime = data.BestTime,
			QuestsDone = data.QuestsDone,
			Streak = data.DailyStreak,
			GoldMedals = goldMedals(data),
		},
	}
end

function ProgressService:Sync(player: Player)
	local data = dataOf(player)
	if data then
		dirty[player] = nil
		self.Services.Net.ProgressSync:FireClient(player, snapshot(player, data))
	end
end

---------------------------------------------------------------- Hoechsttempo (Server misst selbst)

-- Der Client bewegt seinen Charakter selbst; der Server schaut nur, wie weit die Figur sich wirklich bewegt.
-- Teleports (riesige Spruenge) zaehlen nicht, und zwei Messfenster hintereinander muessen schnell sein.
local function sampleSpeeds()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local data = dataOf(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if data and root then
			local position = root.Position
			local sample = speedSamples[player]
			if sample and now - sample.Time > 0.05 then
				local delta = position - sample.Position
				local studs = Vector3.new(delta.X, 0, delta.Z).Magnitude / (now - sample.Time)
				if studs > Progression.MaxPlausibleStuds or studs ~= studs then
					studs = 0 -- Teleport
				end
				local steady = math.min(studs, sample.Speed)
				local units = math.floor(steady / SurfPhysics.Unit)
				if units > data.TopSpeed then
					data.TopSpeed = units
					player:SetAttribute("TopSpeed", units)
					ProgressService:AddQuest(player, "Speed", units)
					ProgressService:Evaluate(player)
				end
				speedSamples[player] = { Position = position, Time = now, Speed = studs }
			elseif not sample then
				speedSamples[player] = { Position = position, Time = now, Speed = 0 }
			end
		else
			speedSamples[player] = nil
		end
	end
end

---------------------------------------------------------------- Start

function ProgressService:Start()
	local services = self.Services
	services.Net.Progress.OnServerEvent:Connect(function(player, action, arg)
		local data = dataOf(player)
		if not data or typeof(action) ~= "string" then
			return
		end
		local now = os.clock()
		if now - (lastAction[player] or -math.huge) < 0.25 then
			return
		end
		lastAction[player] = now
		if action == "Title" and typeof(arg) == "string" then
			equipTitle(player, data, arg)
		elseif action == "Claim" and typeof(arg) == "string" then
			claimQuest(player, data, arg)
		elseif action == "Code" and typeof(arg) == "string" and #arg <= 24 then
			-- Codes nicht durchprobieren lassen
			lastAction[player] = now + 1.5
			redeem(player, data, arg)
		elseif action == "Spin" then
			spin(player, data)
		elseif action == "Settings" and typeof(arg) == "table" then
			saveSettings(data, arg)
		elseif action == "Sync" then
			dirty[player] = true
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			sampleSpeeds()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for player in dirty do
				if player.Parent then
					self:Sync(player)
				else
					dirty[player] = nil
				end
			end
		end
	end)
end

function ProgressService:OnPlayerReady(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	ensureQuests(player, data)
	applyTitle(player, data)
	self:Evaluate(player)
	dirty[player] = true
end

function ProgressService:OnPlayerRemoving(player: Player)
	dirty[player] = nil
	lastAction[player] = nil
	speedSamples[player] = nil
end

return ProgressService
