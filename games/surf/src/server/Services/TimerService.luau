-- Laeufe und Zeiten: Stage-Zeiten, Map-Zeit, Bestzeiten, Belohnungen und Teleports zwischen den Stages.
-- Der Client meldet Start/Ziel (er rechnet die Bewegung selbst), der Server misst mit und prueft:
-- richtige Stage, Mindestzeit, und ob die vom Server gesehene Position wirklich am Ziel ist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local TimerService = { Services = nil :: any }

local THEME = Config.Theme
local runs = {} -- [Player] = { Stage, StageStart, RunStart, Ranked, StageClean }
local STAGES = #Config.Stages

function TimerService:Init(services)
	self.Services = services
end

local function lowGravity(): boolean
	return (workspace:GetAttribute("LowGravityUntil") or 0) > os.time()
end

local function setStage(player: Player, stage: number)
	runs[player].Stage = stage
	player:SetAttribute("Stage", stage)
	player:SetAttribute("Ranked", runs[player].Ranked)
	TimerService.Services.DataService:UpdateAttributes(player)
end

local function teleport(player: Player, cframe: CFrame, stage: number)
	TimerService.Services.Net.Teleport:FireClient(player, cframe, stage)
end

-- Neuen Lauf bzw. neue Stage beginnen (Uhr startet erst beim Verlassen der Startzone)
function TimerService:Begin(player: Player, stage: number, ranked: boolean)
	local run = runs[player]
	if not run then
		return
	end
	run.Ranked = ranked and not lowGravity()
	run.RunStart = nil
	run.StageStart = nil
	run.StageClean = not lowGravity()
	setStage(player, stage)
	teleport(player, self.Services.WorldService:GetSpawn(stage), stage)
end

-- Nur die aktuelle Stage neu (Map-Zeit laeuft weiter)
function TimerService:RestartStage(player: Player)
	local run = runs[player]
	if run and run.Stage > 0 then
		run.StageStart = nil
		teleport(player, self.Services.WorldService:GetSpawn(run.Stage), run.Stage)
	end
end

function TimerService:ToLobby(player: Player)
	local run = runs[player]
	if not run then
		return
	end
	run.RunStart = nil
	run.StageStart = nil
	run.Ranked = false
	setStage(player, 0)
	teleport(player, self.Services.WorldService:GetLobbySpawn(), 0)
end

-- Fuer "Skip Stage": naechste Stage freischalten und hinbringen, der Lauf zaehlt nicht mehr
function TimerService:Skip(player: Player)
	local run = runs[player]
	local data = self.Services.DataService:Get(player)
	if not run or not data then
		return
	end
	local from = if run.Stage == 0 then data.MaxStage else run.Stage
	local target = math.min(from + 1, STAGES)
	data.MaxStage = math.max(data.MaxStage, target)
	self:Begin(player, target, false)
	self.Services.Net.SendNotify(player, `Skipped to Stage {target}!`, THEME.Gold)
end

-- Alle laufenden Zeiten ungueltig machen (z. B. Mondschwerkraft fuer den Server)
function TimerService:InvalidateAll()
	for player, run in runs do
		run.Ranked = false
		run.StageClean = false
		player:SetAttribute("Ranked", false)
	end
end

local function nearZone(player: Player, zonePart: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local localPos = zonePart.CFrame:PointToObjectSpace(root.Position)
	local half = zonePart.Size / 2
	local tol = Config.FinishTolerance
	return math.abs(localPos.X) < half.X + tol and math.abs(localPos.Y) < half.Y + tol and math.abs(localPos.Z) < half.Z + tol
end

-- Client-Zeit nehmen, wenn sie zur Server-Messung passt (genauer), sonst die Server-Zeit
local function officialTime(clientTime: any, serverTime: number): number
	if typeof(clientTime) == "number" and clientTime == clientTime and math.abs(clientTime - serverTime) < 0.6 then
		return clientTime
	end
	return serverTime
end

local function finishStage(player: Player, stage: number, clientStage: any, clientRun: any)
	local services = TimerService.Services
	local run = runs[player]
	local data = services.DataService:Get(player)
	if not run or not data or run.Stage ~= stage or not run.StageStart then
		return
	end
	local info = services.WorldService:GetStageInfo(stage)
	local now = os.clock()
	local serverStage = now - run.StageStart
	if serverStage < Config.MinStageSeconds or not nearZone(player, info.Finish) then
		warn("[Timer] Ziel abgelehnt", player.Name, stage, serverStage)
		return
	end
	local stageTime = officialTime(clientStage, serverStage)
	run.StageStart = nil

	local key = tostring(stage)
	local result = { Stage = stage, StageTime = stageTime, Flakes = 0, Clean = run.StageClean }
	local firstClear = not data.Cleared[key]
	data.Cleared[key] = true
	if run.StageClean then
		local previous = data.StageBest[key]
		result.PreviousBest = previous
		if not previous or stageTime < previous then
			data.StageBest[key] = stageTime
			result.StagePB = true
			services.LeaderboardService:SubmitStage(player, stage, stageTime)
		end
	end
	data.Clears += 1
	local reward = if firstClear then Config.Rewards.StageFirst(stage) else Config.Rewards.StageRepeat(stage)
	result.Flakes += services.DataService:AddFlakes(player, reward)
	data.MaxStage = math.max(data.MaxStage, math.min(stage + 1, STAGES))

	if stage < STAGES then
		run.StageClean = not lowGravity()
		setStage(player, stage + 1)
		services.Net.Result:FireClient(player, result)
		teleport(player, services.WorldService:GetSpawn(stage + 1), stage + 1)
		return
	end

	-- Ganze Map geschafft
	result.MapComplete = true
	data.MapClears += 1
	local mapReward = if data.MapClears == 1 then Config.Rewards.MapFirst else Config.Rewards.MapRepeat
	if run.Ranked and run.RunStart then
		local runTime = officialTime(clientRun, now - run.RunStart)
		result.RunTime = runTime
		result.PreviousRunBest = if data.BestTime > 0 then data.BestTime else nil
		if data.BestTime == 0 or runTime < data.BestTime then
			data.BestTime = runTime
			result.RunPB = true
			mapReward += Config.Rewards.PersonalBest
			services.LeaderboardService:Submit(player, runTime)
			services.Net.SendAnnounce(`{player.DisplayName} set a new personal best on surf_ski: {Format.Run(runTime)}!`, THEME.Ice)
		end
	end
	result.Flakes += services.DataService:AddFlakes(player, mapReward)
	run.RunStart = nil
	run.Ranked = false
	setStage(player, 0)
	services.Net.Result:FireClient(player, result)
	task.delay(3, function()
		if player.Parent and runs[player] and runs[player].Stage == 0 then
			teleport(player, services.WorldService:GetLobbySpawn(), 0)
		end
	end)
	task.spawn(services.DataService.Save, services.DataService, player)
end

function TimerService:Start()
	local services = self.Services
	services.Net.Run.OnServerEvent:Connect(function(player, action, stage, clientStage, clientRun)
		local run = runs[player]
		local data = services.DataService:Get(player)
		if not run or not data or typeof(action) ~= "string" then
			return
		end
		if action == "Start" then
			if run.Stage == 0 then
				self:Begin(player, 1, true)
			end
		elseif action == "Restart" then
			self:Begin(player, 1, true)
		elseif action == "RestartStage" then
			self:RestartStage(player)
		elseif action == "Lobby" then
			self:ToLobby(player)
		elseif action == "Goto" then
			if typeof(stage) == "number" and stage >= 1 and stage <= math.min(data.MaxStage, STAGES) and stage == math.floor(stage) then
				self:Begin(player, stage, stage == 1)
			end
		elseif action == "Leave" then
			if stage == run.Stage and run.Stage > 0 then
				run.StageStart = os.clock()
				if run.Stage == 1 then
					-- Stage 1 verlassen = neuer Lauf (wie auf CS-Servern)
					run.RunStart = os.clock()
					run.Ranked = not lowGravity()
					run.StageClean = not lowGravity()
					player:SetAttribute("Ranked", run.Ranked)
				end
			end
		elseif action == "Fell" then
			if stage == run.Stage then
				run.StageStart = nil
				data.Falls += 1
			end
		elseif action == "UsedCheckpoint" then
			run.Ranked = false
			run.StageClean = false
			player:SetAttribute("Ranked", false)
		elseif action == "Finish" then
			if typeof(stage) == "number" then
				finishStage(player, stage, clientStage, clientRun)
			end
		end
	end)
end

function TimerService:OnPlayerReady(player: Player)
	runs[player] = { Stage = 0, Ranked = false, StageClean = true }
	setStage(player, 0)
end

-- Nach einem Respawn (z. B. Reset im Menue) in der aktuellen Stage weitermachen
function TimerService:OnCharacterAdded(player: Player)
	local run = runs[player]
	if run then
		run.StageStart = nil
		task.delay(0.3, function()
			if player.Parent and runs[player] then
				local stage = runs[player].Stage
				teleport(player, if stage > 0 then self.Services.WorldService:GetSpawn(stage) else self.Services.WorldService:GetLobbySpawn(), stage)
			end
		end)
	end
end

function TimerService:OnPlayerRemoving(player: Player)
	runs[player] = nil
end

return TimerService
