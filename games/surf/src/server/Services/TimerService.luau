-- Laeufe und Zeiten: Stage-Zeiten, Map-Zeit, Bestzeiten, Belohnungen und Teleports zwischen den Stages.
-- Der Client meldet Start/Ziel (er rechnet die Bewegung selbst), der Server misst mit und prueft:
-- richtige Stage, Mindestzeit, und ob die vom Server gesehene Position wirklich am Ziel ist.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local TimerService = { Services = nil :: any }

local THEME = Config.Theme
local runs = {} -- [Player] = { Stage, StageStart, RunStart, Ranked, StageClean, Splits, LastFall }
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
	local arena = self.Services.ArenaService
	if arena and arena:IsIn(player) then
		arena:Remove(player)
	end
	run.Ranked = ranked and not lowGravity()
	run.RunStart = nil
	run.StageStart = nil
	run.Splits = {}
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
	local arena = self.Services.ArenaService
	if arena and arena:IsIn(player) then
		arena:Remove(player)
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
	-- Die naechste noch gesperrte Stage freischalten (vorher: aktuelle Stage + 1, das war oft schon frei
	-- und der Kauf damit verschenkt). Ist alles frei, geht es einfach eine Stage weiter.
	local from = if run.Stage == 0 then data.MaxStage else run.Stage
	local target = if data.MaxStage < STAGES then data.MaxStage + 1 else math.min(from + 1, STAGES)
	data.MaxStage = math.max(data.MaxStage, target)
	self:Begin(player, target, false)
	self.Services.Net.SendNotify(player, `Skipped to Stage {target}!`, THEME.Gold)
end

-- Alle laufenden Zeiten ungueltig machen (z. B. Mondschwerkraft fuer den Server)
-- Lohnt sich "Skip Stage" gerade? (nicht, wenn schon alles frei ist und man auf der letzten Stage/in der Lobby steht)
function TimerService:CanSkip(player: Player): boolean
	local run = runs[player]
	local data = self.Services.DataService:Get(player)
	if not run or not data then
		return false
	end
	return data.MaxStage < STAGES or (run.Stage > 0 and run.Stage < STAGES)
end

function TimerService:InvalidateAll()
	for player, run in runs do
		run.Ranked = false
		run.StageClean = false
		player:SetAttribute("Ranked", false)
	end
end

local function nearZone(player: Player, zonePart: BasePart, tolerance: number?): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local localPos = zonePart.CFrame:PointToObjectSpace(root.Position)
	local half = zonePart.Size / 2
	local tol = tolerance or Config.FinishTolerance
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
		-- Medaille (Bronze/Silber/Gold) nur fuer saubere Laeufe
		local medal, newMedal, bonus = services.ProgressService:RecordMedal(player, stage, stageTime)
		result.Medal = medal
		result.NewMedal = newMedal
		result.Flakes += bonus
	end
	-- Zwischenzeit im gewerteten Lauf, verglichen mit dem Bestzeit-Lauf
	if run.Ranked and run.RunStart then
		local split = officialTime(clientRun, now - run.RunStart)
		run.Splits = run.Splits or {}
		run.Splits[stage] = split
		result.Split = split
		local pbSplit = data.PBSplits[tostring(stage)]
		if typeof(pbSplit) == "number" then
			result.SplitDelta = split - pbSplit
		end
	end
	data.Clears += 1
	local reward = if firstClear then Config.Rewards.StageFirst(stage) else Config.Rewards.StageRepeat(stage)
	result.Flakes += services.DataService:AddFlakes(player, reward)
	data.MaxStage = math.max(data.MaxStage, math.min(stage + 1, STAGES))
	services.ProgressService:OnStageClear(player, stage, result.StagePB == true)

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
			-- Zwischenzeiten dieses Laufs als neue Vergleichswerte merken
			-- (Schluessel als Text, damit der DataStore keine Luecken-Arrays bekommt)
			local splits = {}
			for i = 1, STAGES do
				local split = run.Splits and run.Splits[i]
				if split then
					splits[tostring(i)] = split
				end
			end
			splits[tostring(STAGES)] = runTime
			data.PBSplits = splits
			services.LeaderboardService:Submit(player, runTime)
			services.Net.SendAnnounce(`{player.DisplayName} set a new personal best on surf_ski: {Format.Run(runTime)}!`, THEME.Ice)
		end
	end
	result.Flakes += services.DataService:AddFlakes(player, mapReward)
	services.ProgressService:OnMapClear(player)
	-- Update 3: Feuerwerk ueber dem Ziel, das alle sehen
	services.Net.Fx:FireAllClients("Fireworks", info.Finish.Position, player.DisplayName)
	run.RunStart = nil
	run.Ranked = false
	setStage(player, 0)
	services.Net.Result:FireClient(player, result)
	-- Nach dem Ziel gleich die naechste Runde ab Stage 1
	task.delay(3, function()
		if player.Parent and runs[player] and runs[player].Stage == 0 then
			TimerService:Begin(player, 1, true)
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
			-- Auch wenn der Spieler laut Server schon in Stage 1 ist, aber in der Lobby am Tor steht
			local zones = workspace:FindFirstChild("Zones")
			local portal = zones and zones:FindFirstChild("StartPortal") :: BasePart?
			if run.Stage == 0 or (portal and nearZone(player, portal, 12)) then
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
			-- Nur direkt an der Startzone: sonst koennte man "Leave" kurz vor dem Ziel schicken und die Uhr neu starten
			local info = services.WorldService:GetStageInfo(run.Stage)
			if stage == run.Stage and run.Stage > 0 and info and nearZone(player, info.Start, Config.StartTolerance) then
				run.StageStart = os.clock()
				if run.Stage == 1 then
					-- Stage 1 verlassen = neuer Lauf (wie auf CS-Servern)
					run.RunStart = os.clock()
					run.Splits = {}
					run.Ranked = not lowGravity()
					run.StageClean = not lowGravity()
					player:SetAttribute("Ranked", run.Ranked)
				end
			end
		elseif action == "Fell" then
			if stage == run.Stage then
				run.StageStart = nil
				-- Nicht beliebig oft zaehlen (Erfolg "Snow Angel")
				local now = os.clock()
				if now - (run.LastFall or 0) > 1.5 then
					run.LastFall = now
					data.Falls += 1
				end
			end
		elseif action == "UsedCheckpoint" or action == "Assisted" then
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

-- Direkt auf Stage 1 starten (die Lobby erreicht man ueber den Lobby-Knopf); der Respawn bringt einen hin
function TimerService:OnPlayerReady(player: Player)
	runs[player] = { Stage = 1, Ranked = not lowGravity(), StageClean = not lowGravity(), Splits = {} }
	setStage(player, 1)
end

-- Nach einem Respawn (z. B. Reset im Menue) in der aktuellen Stage weitermachen
function TimerService:OnCharacterAdded(player: Player)
	local run = runs[player]
	if run then
		run.StageStart = nil
		task.delay(0.3, function()
			if player.Parent and runs[player] then
				local stage = runs[player].Stage
				local arena = self.Services.ArenaService
				local arenaSpawn = arena and arena:GetSpawn(player)
				if arenaSpawn then
					teleport(player, arenaSpawn, 0)
					return
				end
				teleport(player, if stage > 0 then self.Services.WorldService:GetSpawn(stage) else self.Services.WorldService:GetLobbySpawn(), stage)
			end
		end)
	end
end

function TimerService:OnPlayerRemoving(player: Player)
	runs[player] = nil
end

return TimerService
