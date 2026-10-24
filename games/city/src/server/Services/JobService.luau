-- Teams, Jobs und Cops & Robbers:
--   Buerger: Lieferjob (Kette = mehr Geld) und Stadtrennen
--   Raeuber: Beute greifen (Bank, Juwelier, Tankstelle, Donut-Laden), im Versteck einloesen, Fahndungssterne
--   Polizei: Handschellen und Betaeubungs-Blaster (Comic, kein Schaden), Kopfgeld, Gefaengnis
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local JobService = { Services = nil :: any }

local C = Config.Colors

local jobs = {} -- [Player] = { Kind = "Delivery"|"Race", Target = Vector3, ... }
local chain = {} -- [Player] = Anzahl Lieferungen in Folge
local lastRace = {} -- [Player] = os.clock()
local lastTeam = {} -- [Player] = os.clock()
local lastCrime = {} -- [Player] = os.clock()
local lastBlast = {} -- [Player] = os.clock()
local bags = {} -- [Player] = Betrag
local robberyState = {} -- [Key] = { Left = number, OpenAt = number }

local function now(): number
	return workspace:GetServerTimeNow()
end

local function notify(player: Player, text: string, color: Color3?)
	JobService.Services.Net.SendNotify(player, text, color)
end

local function teamOf(player: Player): string
	return if player.Team then player.Team.Name else "Citizens"
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function JobService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Teams

function JobService:SetTeam(player: Player, teamName: string): (boolean, string?)
	local team = self.Services.WorldService.TeamObjects[teamName]
	if not team then
		return false, "Unknown team"
	end
	if player.Team == team then
		return false, `You are already on the {teamName} team`
	end
	if player:GetAttribute("JailUntil") then
		return false, "You are in jail!"
	end
	if (player:GetAttribute("Wanted") or 0) > 0 then
		return false, "Lose your wanted stars first!"
	end
	local wait = Config.TeamCooldown - (os.clock() - (lastTeam[player] or -math.huge))
	if wait > 0 then
		return false, `Wait {math.ceil(wait)}s to switch teams`
	end
	if teamName == "Police" then
		local police = #team:GetPlayers()
		local limit = math.max(3, math.ceil(#Players:GetPlayers() * 0.4))
		if police >= limit then
			return false, "The police team is full right now!"
		end
	end
	lastTeam[player] = os.clock()
	self:EndJob(player)
	self:SetBag(player, 0)
	self.Services.VehicleService:Despawn(player)
	player.Team = team
	player:LoadCharacter()
	local text = ({
		Police = "You are a COP! Catch wanted robbers with your Cuffs and Stun Blaster.",
		Robbers = "You are a ROBBER! Grab loot at the Bank, Gem Store, Gas 'n' Go or Donut Palace and cash in at the HIDEOUT.",
		Citizens = "You are a CITIZEN! Take delivery jobs at TURBO DELIVERY or race through the city.",
	})[teamName]
	return true, text
end

---------------------------------------------------------------- Werkzeuge der Polizei

local function makeTool(name: string, color: Color3, size: Vector3): (Tool, BasePart)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = size
	handle.Color = color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return tool, handle
end

local function decorate(handle: BasePart, props)
	local p = Instance.new("Part")
	p.CanCollide = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.CFrame = handle.CFrame * (props.Offset or CFrame.new())
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = p
	weld.Parent = p
	p.Parent = handle.Parent
	return p
end

function JobService:GivePoliceTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local cuffs, cuffHandle = makeTool("Cuffs", Color3.fromRGB(200, 205, 220), Vector3.new(0.4, 1.6, 1.6))
	cuffHandle.Shape = Enum.PartType.Cylinder
	cuffs.ToolTip = "Arrest wanted robbers up close"
	decorate(cuffHandle, { Size = Vector3.new(0.4, 1.6, 1.6), Shape = Enum.PartType.Cylinder, Color = Color3.fromRGB(200, 205, 220), Offset = CFrame.new(0, 0, 1.4) })
	cuffs.Activated:Connect(function()
		self:TryArrest(player)
	end)
	cuffs.Parent = backpack

	local blaster, blasterHandle = makeTool("Stun Blaster", C.Teal, Vector3.new(0.8, 1.4, 2.4))
	blaster.ToolTip = "Freeze robbers and stall their cars"
	blaster.GripPos = Vector3.new(0, -0.4, 0.4)
	decorate(blasterHandle, { Size = Vector3.new(0.6, 0.6, 1.6), Color = C.Lemon, Material = Enum.Material.Neon, Offset = CFrame.new(0, 0.3, -1.6) })
	decorate(blasterHandle, { Size = Vector3.new(0.9, 0.5, 0.9), Color = C.Pink, Offset = CFrame.new(0, 0.8, 0.2) })
	blaster.Activated:Connect(function()
		self:Blast(player, blasterHandle)
	end)
	blaster.Parent = backpack
end

local function isWanted(player: Player): boolean
	return teamOf(player) == "Robbers" and ((player:GetAttribute("Wanted") or 0) > 0 or (bags[player] or 0) > 0) and not player:GetAttribute("JailUntil")
end

function JobService:TryArrest(officer: Player)
	local root = rootOf(officer)
	if not root or teamOf(officer) ~= "Police" then
		return
	end
	local best, bestDistance = nil, Config.ArrestRange
	for _, robber in Players:GetPlayers() do
		local target = rootOf(robber)
		if target and isWanted(robber) then
			local distance = (target.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = robber, distance
			end
		end
	end
	if best then
		self:Arrest(officer, best)
	else
		notify(officer, "No wanted robber close enough!", C.Robber)
	end
end

function JobService:Arrest(officer: Player, robber: Player)
	local stars = robber:GetAttribute("Wanted") or 0
	local bag = bags[robber] or 0
	local base = Config.ArrestBountyPerStar * math.max(stars, 1) + bag * Config.ArrestBagShare
	if officer:GetAttribute("Pass_SWAT") then
		base *= 1.5
	end
	local reward = self.Services.DataService:Earn(officer, base)
	local data = self.Services.DataService:Get(officer)
	if data then
		data.Stats.Arrests += 1
	end
	self.Services.RewardService:Progress(officer, "Arrest", 1)
	notify(officer, `Arrested {robber.DisplayName}! Bounty +{Format.Cash(reward)}`, C.Green)
	self.Services.Net.SendAnnounce(`Officer {officer.DisplayName} arrested {robber.DisplayName}!`, C.Police)
	self:Jail(robber, stars)
end

function JobService:Jail(robber: Player, stars: number)
	self.Services.VehicleService:Eject(robber)
	self.Services.VehicleService:Despawn(robber)
	self:EndJob(robber)
	self:SetBag(robber, 0)
	robber:SetAttribute("Wanted", 0)
	self:UpdateWantedStat(robber)
	local seconds = Config.JailBase + Config.JailPerStar * stars
	robber:SetAttribute("JailUntil", now() + seconds)
	local data = self.Services.DataService:Get(robber)
	if data then
		data.Stats.Jailed += 1
	end
	self:SendToCell(robber)
	notify(robber, `Busted! You are in jail for {seconds}s.`, C.Robber)
	task.delay(2, function()
		if robber.Parent and robber:GetAttribute("JailUntil") then
			self.Services.MonetizationService:Offer(robber, "JailBreak", "Don't want to wait?")
		end
	end)
end

function JobService:SendToCell(player: Player)
	local cells = self.Services.WorldService.JailCells
	local character = player.Character
	if character and #cells > 0 then
		local cell = cells[math.random(1, #cells)]
		task.defer(function()
			if character.Parent then
				character:PivotTo(CFrame.new(cell))
			end
		end)
	end
end

function JobService:Release(player: Player, broke: boolean?)
	player:SetAttribute("JailUntil", nil)
	local spawn = self.Services.WorldService.Spawns.Robbers
	local character = player.Character
	if character and spawn then
		character:PivotTo(CFrame.new(spawn + Vector3.new(0, 4, 0)))
	end
	if broke then
		self:AddWanted(player, 1)
		self.Services.Net.SendAnnounce(`{player.DisplayName} BROKE OUT of jail!`, C.Robber)
	else
		notify(player, "You are free! Stay out of trouble... or don't.", C.Green)
	end
end

function JobService:Blast(officer: Player, handle: BasePart)
	local root = rootOf(officer)
	if not root or teamOf(officer) ~= "Police" then
		return
	end
	local t = os.clock()
	if t - (lastBlast[officer] or -math.huge) < Config.BlasterCooldown then
		return
	end
	lastBlast[officer] = t
	local look = flat(root.CFrame.LookVector).Unit
	local best, bestScore = nil, -math.huge
	for _, robber in Players:GetPlayers() do
		local target = rootOf(robber)
		if target and isWanted(robber) then
			local offset = target.Position - root.Position
			local distance = offset.Magnitude
			if distance < Config.BlasterRange and distance > 0 then
				local dot = flat(offset).Unit:Dot(look)
				local score = dot * 2 - distance / Config.BlasterRange
				if dot > 0.75 and score > bestScore then
					best, bestScore = robber, score
				end
			end
		end
	end
	local from = handle.Position
	local to = if best then (rootOf(best) :: BasePart).Position else from + look * 40
	-- Comic-Strahl
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = C.Teal
	beam.Size = Vector3.new(0.5, 0.5, (to - from).Magnitude)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to)
	beam.Parent = workspace
	Debris:AddItem(beam, 0.15)
	if not best then
		return
	end
	local character = best.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local stars = Instance.new("ParticleEmitter")
	stars.Color = ColorSequence.new(C.Lemon)
	stars.Size = NumberSequence.new(0.6)
	stars.Rate = 25
	stars.Lifetime = NumberRange.new(0.5)
	stars.Speed = NumberRange.new(4)
	stars.LightEmission = 1
	stars.Parent = rootOf(best)
	Debris:AddItem(stars, Config.StunTime)
	if humanoid.SeatPart then
		local car = humanoid.SeatPart:FindFirstAncestorOfClass("Model")
		if car then
			car:SetAttribute("StalledUntil", now() + Config.StallTime)
		end
		notify(best, "Your car got zapped! Engine stalled!", C.Robber)
	else
		best:SetAttribute("StunnedUntil", now() + Config.StunTime)
		local speed = humanoid.WalkSpeed
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		task.delay(Config.StunTime, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = if speed > 0 then speed else 18
				humanoid.JumpPower = 50
			end
		end)
		notify(best, "Zapped! You are frozen!", C.Robber)
	end
end

---------------------------------------------------------------- Raeuber

function JobService:UpdateWantedStat(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local value = leaderstats and leaderstats:FindFirstChild("Wanted") :: IntValue?
	if value then
		value.Value = player:GetAttribute("Wanted") or 0
	end
end

function JobService:AddWanted(player: Player, amount: number)
	local before = player:GetAttribute("Wanted") or 0
	local after = math.min(Config.MaxWanted, before + amount)
	player:SetAttribute("Wanted", after)
	lastCrime[player] = os.clock()
	self:UpdateWantedStat(player)
	if after >= 4 and before < 4 then
		self.Services.Net.SendAnnounce(`{player.DisplayName} is MOST WANTED ({after} stars)!`, C.Robber)
		self.Services.MonetizationService:Offer(player, "ClearWanted", "The whole police force is after you!")
	end
end

function JobService:BagMax(player: Player): number
	return Config.BagSize * (if player:GetAttribute("Pass_BigBag") then Config.BigBagMultiplier else 1)
end

function JobService:SetBag(player: Player, amount: number)
	bags[player] = if amount > 0 then amount else nil
	player:SetAttribute("Bag", if amount > 0 then amount else nil)
	player:SetAttribute("BagMax", self:BagMax(player))
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("LootBag")
	if amount <= 0 then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local bag = Instance.new("Part")
	bag.Name = "LootBag"
	bag.Shape = Enum.PartType.Ball
	bag.Size = Vector3.new(2.6, 2.6, 2.6)
	bag.Color = Color3.fromRGB(150, 105, 60)
	bag.Material = Enum.Material.Fabric
	bag.CanCollide = false
	bag.Massless = true
	bag.CFrame = torso.CFrame * CFrame.new(0, 0.3, 1.5)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = bag
	weld.Parent = bag
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(40, 40)
	gui.StudsOffset = Vector3.new(0, 1.8, 0)
	gui.LightInfluence = 0
	gui.Parent = bag
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = C.Green
	label.Text = "$"
	label.Parent = gui
	bag.Parent = character
end

function JobService:Rob(player: Player, key: string)
	local info = Config.Robberies[key]
	if not info then
		return
	end
	if teamOf(player) ~= "Robbers" then
		notify(player, "Only Robbers can do that! Join the Robbers at the plaza.", C.Robber)
		return
	end
	if player:GetAttribute("JailUntil") then
		return
	end
	local state = robberyState[key]
	if state.Left <= 0 then
		notify(player, `The {info.Name} is empty! Back in {Format.Time(state.OpenAt - os.clock())}`, C.Robber)
		return
	end
	local bag = bags[player] or 0
	local max = self:BagMax(player)
	if bag >= max then
		notify(player, "Your bag is full! Cash in at the HIDEOUT.", C.Lemon)
		if not player:GetAttribute("Pass_BigBag") then
			self.Services.MonetizationService:Offer(player, "Pass_BigBag", "Carry twice as much loot!")
		end
		return
	end
	local first = state.Left == info.Grabs
	state.Left -= 1
	if state.Left <= 0 then
		state.OpenAt = os.clock() + info.Cooldown
		workspace:SetAttribute("Closed_" .. key, true)
	end
	local amount = math.min(info.Loot, max - bag)
	self:SetBag(player, bag + amount)
	self:AddWanted(player, info.Stars)
	local data = self.Services.DataService:Get(player)
	if data then
		data.Stats.Robberies += 1
	end
	self.Services.RewardService:Progress(player, "Rob", 1)
	notify(player, `+{Format.Cash(amount)} loot! Bag {Format.Cash(bag + amount)}/{Format.Cash(max)}. Get to the HIDEOUT!`, C.Green)
	local hideout = self.Services.WorldService.Hideout
	if hideout then
		self.Services.Net.SendMarker(player, hideout.Position, "HIDEOUT", "Hideout")
	end
	if first then
		local point = self.Services.WorldService.RobPoints[key]
		for _, cop in Players:GetPlayers() do
			if teamOf(cop) == "Police" then
				notify(cop, `ALARM! The {info.Name} is being robbed!`, C.Robber)
				if point then
					self.Services.Net.SendMarker(cop, point.Position, `ALARM: {info.Name}`, "Alarm")
				end
			end
		end
	end
end

function JobService:CashIn(player: Player)
	local bag = bags[player] or 0
	if bag <= 0 then
		return
	end
	self:SetBag(player, 0)
	local amount = self.Services.DataService:Earn(player, bag)
	self.Services.RewardService:Progress(player, "CashIn", 1)
	self.Services.Net.SendMarker(player, nil)
	notify(player, `Cashed in {Format.Cash(amount)}!`, C.Green)
	if amount >= 5_000 then
		self.Services.Net.SendAnnounce(`{player.DisplayName} got away with {Format.Cash(amount)}!`, C.Lemon)
	end
end

---------------------------------------------------------------- Lieferjob und Rennen

function JobService:EndJob(player: Player)
	if jobs[player] then
		jobs[player] = nil
		self.Services.Net.SendMarker(player, nil)
	end
	player:SetAttribute("Job", nil)
	player:SetAttribute("JobInfo", nil)
end

local function nextDelivery(player: Player, from: Vector3)
	local points = JobService.Services.WorldService.DeliveryPoints
	local target
	for _ = 1, 30 do
		local candidate = points[math.random(1, #points)]
		local distance = (flat(candidate) - flat(from)).Magnitude
		if distance > 250 and distance < 900 then
			target = candidate
			break
		end
	end
	target = target or points[math.random(1, #points)]
	local distance = (flat(target) - flat(from)).Magnitude
	local count = chain[player] or 0
	local pay = math.floor((Config.DeliveryBase + distance * Config.DeliveryPerStud) * (1 + math.min(count, Config.DeliveryMaxChain) * Config.DeliveryChainBonus))
	jobs[player] = { Kind = "Delivery", Target = target, Pay = pay, StartedAt = os.clock(), Distance = distance }
	player:SetAttribute("Job", "Delivery")
	player:SetAttribute("JobInfo", `Deliver the package! Pay {Format.Cash(pay)}` .. (if count > 0 then ` (chain x{count + 1})` else ""))
	JobService.Services.Net.SendMarker(player, target, `DELIVER {Format.Cash(pay)}`, "Delivery")
end

function JobService:StartDelivery(player: Player): (boolean, string?)
	if teamOf(player) ~= "Citizens" then
		return false, "Delivery jobs are for Citizens. Switch team at the plaza!"
	end
	local root = rootOf(player)
	if not root then
		return false, nil
	end
	self:EndJob(player)
	chain[player] = 0
	nextDelivery(player, root.Position)
	return true, "Delivery started! Follow the marker. Tip: get a car from your garage!"
end

function JobService:StartRace(player: Player): (boolean, string?)
	local wait = Config.RaceCooldown - (os.clock() - (lastRace[player] or -math.huge))
	if wait > 0 then
		return false, `Next race in {math.ceil(wait)}s`
	end
	if player:GetAttribute("JailUntil") then
		return false, nil
	end
	self:EndJob(player)
	lastRace[player] = os.clock()
	local points = self.Services.WorldService.RaceCheckpoints
	jobs[player] = { Kind = "Race", Index = 1, StartedAt = os.clock(), Target = points[1] }
	player:SetAttribute("Job", "Race")
	player:SetAttribute("RaceStart", now())
	player:SetAttribute("JobInfo", `City Race: checkpoint 1/{#points}`)
	self.Services.Net.SendMarker(player, points[1], "CHECKPOINT 1", "Race")
	return true, "GO GO GO! Drive through all checkpoints!"
end

local function updateJob(player: Player, job, root: BasePart)
	local position = flat(root.Position)
	if job.Kind == "Delivery" then
		if (position - flat(job.Target)).Magnitude < Config.DeliveryRadius then
			-- Mindestzeit gegen Teleport-Tricks
			if os.clock() - job.StartedAt < job.Distance / 220 then
				return
			end
			local amount = JobService.Services.DataService:Earn(player, job.Pay)
			chain[player] = (chain[player] or 0) + 1
			local data = JobService.Services.DataService:Get(player)
			if data then
				data.Stats.Deliveries += 1
			end
			JobService.Services.RewardService:Progress(player, "Deliver", 1)
			notify(player, `Delivered! +{Format.Cash(amount)}  Next one is waiting...`, C.Green)
			nextDelivery(player, root.Position)
		end
	elseif job.Kind == "Race" then
		local points = JobService.Services.WorldService.RaceCheckpoints
		local elapsed = os.clock() - job.StartedAt
		if elapsed > Config.RaceLimit then
			JobService:EndJob(player)
			notify(player, "Time's up! Try the race again.", C.Robber)
			return
		end
		if (position - flat(job.Target)).Magnitude < Config.RaceRadius then
			job.Index += 1
			if job.Index > #points then
				JobService:EndJob(player)
				local amount = JobService.Services.DataService:Earn(player, Config.RaceReward(elapsed))
				local data = JobService.Services.DataService:Get(player)
				local record = false
				if data then
					data.Stats.Races += 1
					if data.Stats.BestRace == 0 or elapsed < data.Stats.BestRace then
						data.Stats.BestRace = math.floor(elapsed * 10) / 10
						record = true
					end
					JobService.Services.DataService:UpdateAttributes(player)
				end
				JobService.Services.RewardService:Progress(player, "Race", 1)
				notify(player, `FINISH! {string.format("%.1f", elapsed)}s  +{Format.Cash(amount)}` .. (if record then "  NEW RECORD!" else ""), C.Lemon)
				return
			end
			job.Target = points[job.Index]
			player:SetAttribute("JobInfo", `City Race: checkpoint {job.Index}/{#points}`)
			JobService.Services.Net.SendMarker(player, job.Target, `CHECKPOINT {job.Index}`, "Race")
		end
	end
end

---------------------------------------------------------------- Ablauf

function JobService:OnPlayerReady(player: Player)
	player:SetAttribute("Wanted", 0)
	player:SetAttribute("BagMax", self:BagMax(player))
end

function JobService:OnCharacterAdded(player: Player, character: Model)
	-- Beute geht beim Respawn verloren (sonst waere Reset ein Teleport ins Versteck)
	if bags[player] then
		bags[player] = nil
		player:SetAttribute("Bag", nil)
	end
	if teamOf(player) == "Police" then
		task.defer(self.GivePoliceTools, self, player)
	end
	if player:GetAttribute("JailUntil") then
		character:WaitForChild("HumanoidRootPart", 5)
		self:SendToCell(player)
	end
end

function JobService:OnPlayerRemoving(player: Player)
	jobs[player] = nil
	chain[player] = nil
	lastRace[player] = nil
	lastTeam[player] = nil
	lastCrime[player] = nil
	lastBlast[player] = nil
	bags[player] = nil
end

function JobService:Start()
	for key, info in Config.Robberies do
		robberyState[key] = { Left = info.Grabs, OpenAt = 0 }
	end
	local net = self.Services.Net
	net.Handle("SetTeam", function(player, teamName)
		if typeof(teamName) ~= "string" then
			return false, "Invalid"
		end
		return self:SetTeam(player, teamName)
	end)
	net.Handle("CancelJob", function(player)
		self:EndJob(player)
		chain[player] = 0
		return true, "Job cancelled"
	end)
	net.Handle("StartDelivery", function(player)
		return self:StartDelivery(player)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local parent = prompt.Parent
		local robbery = parent and parent:GetAttribute("Robbery")
		local result, message
		if robbery then
			self:Rob(player, robbery)
		elseif prompt:GetAttribute("SetTeam") then
			result, message = self:SetTeam(player, prompt:GetAttribute("SetTeam"))
		elseif prompt:GetAttribute("Job") == "Delivery" then
			result, message = self:StartDelivery(player)
		elseif prompt:GetAttribute("Race") then
			result, message = self:StartRace(player)
		end
		if message then
			notify(player, message, if result then C.Green else C.Robber)
		end
	end)

	-- Hauptschleife: Jobs, Versteck, Gefaengnis, Fahndung, Laeden wieder oeffnen
	task.spawn(function()
		while true do
			task.wait(0.25)
			local clock = os.clock()
			local hideout = self.Services.WorldService.Hideout
			for _, player in Players:GetPlayers() do
				local root = rootOf(player)
				local job = jobs[player]
				if root and job then
					updateJob(player, job, root)
				end
				if root and hideout and bags[player] then
					local offset = hideout.CFrame:PointToObjectSpace(root.Position)
					if math.abs(offset.X) < hideout.Size.X / 2 + 2 and math.abs(offset.Z) < hideout.Size.Z / 2 + 2 and offset.Y < 12 then
						self:CashIn(player)
					end
				end
				local jailUntil = player:GetAttribute("JailUntil")
				if jailUntil then
					if now() >= jailUntil then
						self:Release(player)
					elseif root and not self.Services.WorldService.IsInJail(root.Position) then
						self:SendToCell(player)
					end
				end
				local wanted = player:GetAttribute("Wanted") or 0
				if wanted > 0 and clock - (lastCrime[player] or 0) > Config.WantedDecay then
					player:SetAttribute("Wanted", wanted - 1)
					lastCrime[player] = clock
					self:UpdateWantedStat(player)
				end
			end
			for key, state in robberyState do
				if state.Left <= 0 and clock >= state.OpenAt then
					state.Left = Config.Robberies[key].Grabs
					workspace:SetAttribute("Closed_" .. key, nil)
				end
			end
		end
	end)
end

return JobService
