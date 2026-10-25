-- Fortschritt: Checkpoints, Respawn am letzten Checkpoint, Ziel/Wins, Stage-Skips,
-- Stage-Auswahl (zurueck zu erreichten Stages) und der Speedrun-Timer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local StageService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)

local finishing = {} -- [Player] = true, solange der Sieg verarbeitet wird
local lastDeath = {} -- [Player] = os.clock()
local lastSelect = {} -- [Player] = os.clock()
local runs = {} -- [Player] = Startzeit (Serverzeit) des laufenden Speedruns ohne Skips
local replaying = {} -- [Player] = true nach der Stage-Auswahl: Coins nur noch fuer neue Rekord-Stages (kein Farmen)

function StageService:Init(services)
	self.Services = services
end

local function playerFromHit(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player, humanoid
	end
	return nil, nil
end

-- Speedrun beenden/ungueltig machen (Skip, Stage-Auswahl, Sieg)
function StageService:StopRun(player: Player)
	runs[player] = nil
	player:SetAttribute("RunStart", nil)
end

function StageService:Teleport(player: Player)
	local data = self.Services.DataService:Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	character:PivotTo(self.Services.WorldService:SpawnCFrame(data.Stage))
end

function StageService:SetStage(player: Player, stage: number, teleport: boolean)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local previousWorld = select(2, Config.WorldForStage(data.Stage))
	data.Stage = math.clamp(stage, 1, Config.StageCount)
	local newRecord = data.Stage > data.BestStage
	data.BestStage = math.max(data.BestStage, data.Stage)
	self.Services.DataService:UpdateAttributes(player)
	local world, worldIndex = Config.WorldForStage(data.Stage)
	if worldIndex > previousWorld and newRecord then
		self.Services.Net.SendAnnounce(`{player.DisplayName} reached World {worldIndex}: {world.Name}!`, world.Accent)
	end
	if newRecord then
		self.Services.RewardService:CheckAchievements(player)
	end
	if teleport then
		self:Teleport(player)
	end
	self.Services.CosmeticService:UpdateNameTag(player)
end

-- Fuer Skip-Produkte. Wer ueber die letzte Stage hinaus springt, landet im Ziel.
function StageService:Skip(player: Player, stages: number): boolean
	local data = self.Services.DataService:Get(player)
	if not data then
		return false
	end
	-- Waehrend eines Sieges nicht vergeben (sonst ginge der Kauf verloren); Roblox versucht es spaeter erneut
	if finishing[player] then
		return false
	end
	self:StopRun(player)
	if data.Stage + stages > Config.StageCount then
		task.defer(self.Win, self, player)
		return true
	end
	self:SetStage(player, data.Stage + stages, true)
	self.Services.Net.SendNotify(player, `Skipped to stage {data.Stage}!`, GREEN)
	return true
end

function StageService:Win(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or finishing[player] then
		return
	end
	finishing[player] = true
	data.Wins += 1
	data.BestStage = Config.StageCount
	self.Services.Net.SendAnnounce(`{player.DisplayName} BEAT ALL {Config.StageCount} STAGES! (Win #{data.Wins})`, GOLD)
	self.Services.Net.SendNotify(player, "You won! New trails unlocked - run again for more Wins!", GOLD)
	-- Speedrun auswerten (nur Laeufe ohne Skips und ohne Stage-Auswahl)
	local started = runs[player]
	self:StopRun(player)
	replaying[player] = nil
	if started then
		local time = math.floor((workspace:GetServerTimeNow() - started) * 10 + 0.5) / 10
		if data.BestTime == 0 or time < data.BestTime then
			data.BestTime = time
			self.Services.Net.SendAnnounce(`⏱ {player.DisplayName} set a new personal best: {Config.FormatRunTime(time)}!`, GOLD)
		else
			self.Services.Net.SendNotify(player, `Run time: {Config.FormatRunTime(time)} (best {Config.FormatRunTime(data.BestTime)})`, GREEN)
		end
		if time <= Config.SpeedsterTime then
			data.SpeedRun = 1
		end
	end
	local reward = self.Services.RewardService:AddCoins(player, Config.CoinsPerWin, true)
	self.Services.Net.SendNotify(player, `+{reward} coins for winning! 🪙`, GOLD)
	self.Services.RewardService:CheckAchievements(player)
	data.Stage = 1
	self.Services.DataService:UpdateAttributes(player)
	self.Services.CosmeticService:Refresh(player)
	task.spawn(self.Services.DataService.Save, self.Services.DataService, player)
	task.wait(2)
	self:Teleport(player)
	finishing[player] = nil
end

function StageService:Kill(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

function StageService:OnCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart")
	task.defer(function()
		if character.Parent then
			self:Teleport(player)
		end
	end)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local data = self.Services.DataService:Get(player)
		if data then
			data.Deaths += 1
			if data.Deaths % 50 == 0 then
				self.Services.RewardService:CheckAchievements(player)
			end
		end
	end)
end

function StageService:OnPlayerRemoving(player: Player)
	finishing[player] = nil
	lastDeath[player] = nil
	lastSelect[player] = nil
	runs[player] = nil
	replaying[player] = nil
end

-- Echter Fortschritt durch Laufen: Coins, Quests und Speedrun-Start
function StageService:OnCheckpointReached(player: Player, previous: number, stage: number, newRecord: boolean)
	local rewards = self.Services.RewardService
	local _, worldIndex = Config.WorldForStage(stage)
	if newRecord or not replaying[player] then
		rewards:AddCoins(player, Config.CoinsPerCheckpoint + worldIndex, true)
	end
	rewards:AddQuestProgress(player, "Checkpoints", stage - previous)
	if (stage - 1) % Config.StagesPerWorld == 0 then
		rewards:AddQuestProgress(player, "Worlds", 1)
	end
	-- Lauf startet, wenn man Stage 1 verlaesst
	if previous == 1 then
		runs[player] = workspace:GetServerTimeNow()
		player:SetAttribute("RunStart", runs[player])
	end
end

-- Zurueck (oder wieder vor) zu einer bereits erreichten Stage
function StageService:SelectStage(player: Player, stage: number)
	local data = self.Services.DataService:Get(player)
	if not data or finishing[player] then
		return
	end
	local now = os.clock()
	if now - (lastSelect[player] or -math.huge) < 0.4 then
		return
	end
	lastSelect[player] = now
	if stage < 1 or stage > data.BestStage or stage == data.Stage then
		return
	end
	self:StopRun(player)
	if not replaying[player] then
		self.Services.Net.SendNotify(player, "Stage select: coins only for new record stages until your next win.", GREEN)
	end
	replaying[player] = true
	self:SetStage(player, stage, true)
end

function StageService:Start()
	local world = self.Services.WorldService

	for stage, pad in world.Checkpoints do
		pad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local data = player and self.Services.DataService:Get(player)
			-- Nur vorwaerts und hoechstens ein paar Checkpoints auf einmal (Teleport-Cheats koennen nicht bis zum Ziel springen)
			if player and data and stage > data.Stage and stage - data.Stage <= Config.MaxCheckpointJump and not finishing[player] then
				local previous = data.Stage
				local newRecord = stage > data.BestStage
				self:SetStage(player, stage, false)
				self:OnCheckpointReached(player, previous, stage, newRecord)
			end
		end)
	end

	world.Finish.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local data = player and self.Services.DataService:Get(player)
		-- Nur wer auf der letzten Stage ist, kann gewinnen (keine Abkuerzung von weit vorne)
		if player and data and data.Stage == Config.StageCount then
			self:Win(player)
		end
	end)

	-- Der Client meldet Kill-Teile und Stuerze, der Server vollstreckt
	self.Services.Net.Died.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastDeath[player] or 0) < 0.5 then
			return
		end
		lastDeath[player] = now
		self:Kill(player)
	end)

	self.Services.Net.SelectStage.OnServerEvent:Connect(function(player, stage)
		if typeof(stage) == "number" and stage == stage and stage % 1 == 0 then
			self:SelectStage(player, stage)
		end
	end)
end

return StageService
