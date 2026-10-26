-- Computer-Laeufer: solange wenige echte Spieler im Server sind, huepfen NPC-Rivalen durch die Stages.
-- Sie bleiben in der Naehe eines echten Spielers (warten, wenn sie zu weit vorne sind, holen auf,
-- wenn sie weit zurueck liegen), fallen ab und zu herunter und verschwinden, sobald echte Spieler kommen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local NpcBody = require(script.Parent.NpcBody)

local RunnerService = { Services = nil :: any, Runners = {} :: { any } }

local R = Config.Runners
local RED = Color3.fromRGB(255, 90, 90)
local GOLD = Color3.fromRGB(255, 200, 40)

local folder: Folder
local paths = {} -- [Stage] = { Vector3 } (Bodenpunkte vom Checkpoint bis zum naechsten Checkpoint)
local lastAnnounce = -math.huge
local usedNames = {} -- [Name] = true

function RunnerService:Init(services)
	self.Services = services
end

local function rand(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function humans(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if RunnerService.Services.DataService:Get(player) then
			table.insert(list, player)
		end
	end
	return list
end

local function stageOf(player: Player): number?
	local data = RunnerService.Services.DataService:Get(player)
	return data and data.Stage
end

---------------------------------------------------------------- Wege durch die Stages

-- Achsenparalleler Umfang eines (evtl. gedrehten) Teils
local function extents(p: BasePart): Vector3
	local cf, s = p.CFrame, p.Size
	local x, y, z = cf.XVector, cf.YVector, cf.ZVector
	return Vector3.new(
		math.abs(x.X) * s.X + math.abs(y.X) * s.Y + math.abs(z.X) * s.Z,
		math.abs(x.Y) * s.X + math.abs(y.Y) * s.Y + math.abs(z.Y) * s.Z,
		math.abs(x.Z) * s.X + math.abs(y.Z) * s.Y + math.abs(z.Z) * s.Z
	)
end

local function padTop(stage: number): Vector3
	local pad = RunnerService.Services.WorldService.Checkpoints[stage]
	return pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
end

-- Bodenpunkte einer Stage: Oberkanten aller begehbaren Teile, nach Laufrichtung (+Z) sortiert.
-- Lange Plattformen (Lava-Boden, Seiltanz) bekommen mehrere Punkte, damit die Spruenge kurz bleiben.
function RunnerService:Path(stage: number): { Vector3 }
	if paths[stage] then
		return paths[stage]
	end
	local world = self.Services.WorldService
	local from = padTop(stage)
	local to = if stage >= Config.StageCount
		then (world.Finish :: BasePart).Position + Vector3.new(0, (world.Finish :: BasePart).Size.Y / 2, 0)
		else padTop(stage + 1)
	local points = {}
	local stageFolder = workspace:FindFirstChild("Obby") and workspace.Obby:FindFirstChild("Stage" .. stage)
	if stageFolder then
		for _, p in stageFolder:GetDescendants() do
			if p:IsA("BasePart") and not p:IsA("TrussPart") and p.CanCollide and p.Transparency < 0.9 then
				local e = extents(p)
				if e.Y <= 3 and e.X >= 1 and e.Z >= 1 then
					local top = p.Position.Y + e.Y / 2
					local zMin, zMax = p.Position.Z - e.Z / 2, p.Position.Z + e.Z / 2
					if e.Z > 9 then
						local count = math.ceil((e.Z - 3) / 6)
						for i = 0, count do
							table.insert(points, Vector3.new(p.Position.X, top, zMin + 1.5 + (e.Z - 3) * i / count))
						end
					else
						table.insert(points, Vector3.new(p.Position.X, top, (zMin + zMax) / 2))
					end
				end
			end
		end
	end
	table.sort(points, function(a, b)
		return a.Z < b.Z
	end)
	local path = { from + Vector3.new(0, 0, 4) }
	for _, point in points do
		local last = path[#path]
		if point.Z > from.Z + 5 and point.Z < to.Z - 5 and (point.Z - last.Z > 2.5 or math.abs(point.X - last.X) > 3) then
			table.insert(path, point)
		end
	end
	table.insert(path, to)
	paths[stage] = path
	return path
end

---------------------------------------------------------------- Laeufer

local function pickName(): string
	local free = {}
	for _, name in R.Names do
		if not usedNames[name] then
			table.insert(free, name)
		end
	end
	local name = if #free > 0 then free[math.random(1, #free)] else R.Names[math.random(1, #R.Names)] .. " " .. math.random(2, 9)
	usedNames[name] = true
	return name
end

local function updateTag(runner)
	local world, worldIndex = Config.WorldForStage(runner.Stage)
	runner.Info.Text = `Stage {runner.Stage} · {world.Name}` .. (if runner.Wins > 0 then ` · 🏆{runner.Wins}` else "")
	runner.Info.TextColor3 = world.Accent or Color3.new(1, 1, 1)
	runner.Model:SetAttribute("Stage", runner.Stage)
	runner.Model:SetAttribute("World", worldIndex)
end

local function place(runner, floor: Vector3, look: Vector3?)
	local position = floor + Vector3.new(0, runner.Height, 0)
	local direction = look or Vector3.new(0, 0, 1)
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, 1)
	end
	runner.Root.CFrame = CFrame.lookAt(position, position + direction.Unit)
	runner.Floor = floor
end

local function say(runner, lines: { string }, chance: number?)
	if math.random() <= (chance or 1) then
		NpcBody.Say(runner.Model, lines[math.random(1, #lines)], 3)
	end
end

-- Echten Spieler als "Begleitung" waehlen (der Laeufer bleibt in seiner Naehe)
local function buddyStage(runner): number?
	if runner.Buddy and (not runner.Buddy.Parent or not stageOf(runner.Buddy)) then
		runner.Buddy = nil
	end
	if not runner.Buddy then
		local list = humans()
		runner.Buddy = if #list > 0 then list[math.random(1, #list)] else nil
	end
	return runner.Buddy and stageOf(runner.Buddy)
end

local function teleport(runner, stage: number)
	NpcBody.Poof(runner.Root.Position)
	runner.Stage = math.clamp(stage, 1, Config.StageCount)
	place(runner, padTop(runner.Stage))
	NpcBody.Poof(runner.Root.Position)
	updateTag(runner)
end

local function rest(runner, seconds: number)
	runner.Phase = "Rest"
	runner.Timer = seconds
	NpcBody.Play(runner.Model, "Idle")
end

function RunnerService:Spawn()
	local name = pickName()
	local model, _, root = NpcBody.Build(name, { Tag = "Runner", Hat = Color3.fromHSV(math.random(), 0.8, 1) })
	local _, nameLabel, info = NpcBody.Tag(model, "RIVAL RUNNER", RED)
	nameLabel.TextColor3 = Color3.fromRGB(255, 235, 200)
	local runner = {
		Name = name,
		Model = model,
		Root = root,
		Info = info,
		Height = NpcBody.RootHeight(model),
		Stage = 1,
		Wins = 0,
		Skill = rand(R.Skill), -- 0 = langsam/ungeschickt, 1 = schnell/sicher
		Phase = "Rest",
		Timer = 0,
		Path = nil :: { Vector3 }?,
		Index = 1,
		FailAt = nil :: number?,
		T = 0,
		Duration = 1,
		From = Vector3.zero,
		To = Vector3.zero,
		Arc = 0,
	}
	local near = buddyStage(runner)
	runner.Stage = if near then math.clamp(near + math.random(-2, 3), 1, Config.StageCount) else math.random(1, 8)
	model.Parent = folder
	place(runner, padTop(runner.Stage))
	NpcBody.Poof(root.Position)
	updateTag(runner)
	rest(runner, rand(R.RestTime))
	table.insert(self.Runners, runner)
	return runner
end

function RunnerService:Remove(runner)
	local index = table.find(self.Runners, runner)
	if index then
		table.remove(self.Runners, index)
	end
	usedNames[runner.Name] = nil
	if runner.Model.Parent then
		NpcBody.Poof(runner.Root.Position)
		runner.Model:Destroy()
	end
end

-- Kill Everyone trifft auch die Laeufer
function RunnerService:KillAll()
	for _, runner in self.Runners do
		if runner.Phase ~= "Fall" then
			runner.Phase = "Fall"
			runner.T = 0
			runner.From = runner.Root.Position
			NpcBody.Play(runner.Model, "Fall")
			say(runner, { "NOOO!", "Not fair!", "Hey!!" })
		end
	end
end

local function startStage(runner)
	local path = RunnerService:Path(runner.Stage)
	runner.Path = path
	runner.Index = 1
	runner.FailAt = nil
	local _, worldIndex = Config.WorldForStage(runner.Stage)
	local failChance = (R.FailChance[1] + (R.FailChance[2] - R.FailChance[1]) * (worldIndex - 1) / 9) * (1.4 - runner.Skill)
	if #path > 2 and math.random() < failChance then
		runner.FailAt = math.random(2, #path)
	end
end

local function nextHop(runner)
	local path = runner.Path :: { Vector3 }
	runner.Index += 1
	local to = path[runner.Index]
	local from = runner.Floor
	local distance = (Vector3.new(to.X, 0, to.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
	local rise = to.Y - from.Y
	runner.From = from
	runner.To = to
	runner.T = 0
	if rise > 6 then
		-- Leiter: hochklettern
		runner.Phase = "Climb"
		runner.Duration = rise / 11 + distance / 20
		NpcBody.Play(runner.Model, "Climb")
	else
		runner.Phase = "Hop"
		local speed = 1.25 - runner.Skill * 0.35
		runner.Duration = math.clamp(distance / 9, 0.35, 1.3) * speed
		runner.Arc = 2.2 + math.clamp(distance / 4, 0, 3) + math.max(0, rise)
		NpcBody.Play(runner.Model, "Jump")
	end
end

local function finishStage(runner)
	if runner.Stage >= Config.StageCount then
		runner.Wins += 1
		if os.clock() - lastAnnounce > R.AnnounceCooldown and #humans() > 0 then
			lastAnnounce = os.clock()
			RunnerService.Services.Net.SendAnnounce(`🤖 {runner.Name} BEAT ALL {Config.StageCount} STAGES! Can you beat them?`, GOLD)
		end
		say(runner, { "GG! Again!", "I WON!", "Too easy!" })
		runner.Stage = 1
		place(runner, padTop(1))
		updateTag(runner)
		rest(runner, 3)
		return
	end
	runner.Stage += 1
	updateTag(runner)
	local world, worldIndex = Config.WorldForStage(runner.Stage)
	if (runner.Stage - 1) % Config.StagesPerWorld == 0 then
		say(runner, { `World {worldIndex}!`, `Hello {world.Name}!`, "New world!" })
		if os.clock() - lastAnnounce > R.AnnounceCooldown and #humans() > 0 then
			lastAnnounce = os.clock()
			RunnerService.Services.Net.SendAnnounce(`🤖 {runner.Name} reached World {worldIndex}: {world.Name}!`, world.Accent)
		end
	end
	rest(runner, rand(R.RestTime))
end

local function update(runner, dt: number)
	local phase = runner.Phase
	if phase == "Rest" then
		runner.Timer -= dt
		if runner.Timer > 0 then
			return
		end
		local near = buddyStage(runner)
		if near then
			if runner.Stage > near + R.MaxLead then
				-- Zu weit vorne: warten und anfeuern
				say(runner, { "Come on, catch up!", "I'm waiting for you!", "You can do it!" }, 0.25)
				rest(runner, 2)
				return
			elseif runner.Stage < near - R.MaxBehind then
				teleport(runner, near - math.random(0, 2))
				say(runner, { "I'm back!", "Wait for me!", "Race you!" }, 0.6)
				rest(runner, 1)
				return
			end
		end
		startStage(runner)
		nextHop(runner)
	elseif phase == "Hop" or phase == "Climb" then
		runner.T += dt
		local a = math.clamp(runner.T / runner.Duration, 0, 1)
		local from, to = runner.From, runner.To
		local position: Vector3
		if phase == "Climb" then
			-- erst hoch, dann nach vorne auf die Plattform
			local up = math.clamp(a / 0.8, 0, 1)
			local forward = math.clamp((a - 0.8) / 0.2, 0, 1)
			local flat = Vector3.new(from.X, 0, from.Z):Lerp(Vector3.new(to.X, 0, to.Z), 0.6 * up + 0.4 * forward)
			position = Vector3.new(flat.X, from.Y + (to.Y - from.Y) * up, flat.Z)
		else
			position = from:Lerp(to, a) + Vector3.new(0, 4 * runner.Arc * a * (1 - a), 0)
		end
		local look = to - from
		runner.Root.CFrame = CFrame.lookAt(position + Vector3.new(0, runner.Height, 0), position + Vector3.new(0, runner.Height, 0) + (if Vector3.new(look.X, 0, look.Z).Magnitude > 0.1 then Vector3.new(look.X, 0, look.Z).Unit else Vector3.new(0, 0, 1)))
		-- Danebengesprungen: ab der Mitte des Sprungs faellt er herunter
		if runner.FailAt == runner.Index and a >= 0.55 and phase == "Hop" then
			runner.Phase = "Fall"
			runner.T = 0
			runner.From = position
			NpcBody.Play(runner.Model, "Fall")
			say(runner, { "Oops!", "Noooo!", "Not again!", "Whoa!" }, 0.7)
			return
		end
		if a >= 1 then
			runner.Floor = to
			if runner.Index >= #(runner.Path :: { Vector3 }) then
				finishStage(runner)
			else
				nextHop(runner)
			end
		end
	elseif phase == "Fall" then
		runner.T += dt
		local position = runner.From - Vector3.new(0, 30 * runner.T * runner.T, 0)
		runner.Root.CFrame = CFrame.new(position + Vector3.new(0, runner.Height, 0)) * runner.Root.CFrame.Rotation
		if runner.T >= 1 then
			-- wieder am Checkpoint der aktuellen Stage
			place(runner, padTop(runner.Stage))
			NpcBody.Poof(runner.Root.Position)
			rest(runner, rand(R.RestTime) + 0.8)
		end
	end
end

-- Wie viele Laeufer gerade gebraucht werden
function RunnerService:Wanted(): number
	return math.clamp(R.FillUntilPlayers - #Players:GetPlayers(), 0, R.Max)
end

function RunnerService:Balance()
	local wanted = self:Wanted()
	while #self.Runners > wanted do
		local runner = self.Runners[#self.Runners]
		say(runner, { "Gotta go, bye!", "See ya!" })
		self:Remove(runner)
	end
	if #self.Runners < wanted then
		self:Spawn()
	end
end

function RunnerService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Runners"
	folder.Parent = workspace

	RunService.Heartbeat:Connect(function(dt)
		for _, runner in self.Runners do
			local ok, err = pcall(update, runner, math.min(dt, 0.1))
			if not ok then
				warn("Runner update failed:", err)
				runner.Phase = "Rest"
				runner.Timer = 2
			end
		end
	end)

	-- Echte Spieler kommen: sofort Platz machen. Sonst nach und nach auffuellen.
	Players.PlayerAdded:Connect(function()
		task.defer(self.Balance, self)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, runner in self.Runners do
			if runner.Buddy == player then
				runner.Buddy = nil
			end
		end
		task.delay(1, self.Balance, self)
	end)
	task.spawn(function()
		while true do
			self:Balance()
			task.wait(R.SpawnInterval)
		end
	end)
end

return RunnerService
