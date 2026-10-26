-- Computer-Raeuber und Computer-Polizisten: solange wenige echte Spieler da sind, ist die Stadt trotzdem belebt.
--   Raeuber-Bots: laufen zu einem Laden, rauben ihn aus (Alarm fuer die Polizei) und rennen zum Versteck.
--     Echte Polizisten koennen sie festnehmen (Kopfgeld) oder mit dem Blaster einfrieren.
--   Polizei-Bots: streifen durch die Stadt und jagen gesuchte Raeuber (echte zu Fuss und Raeuber-Bots).
-- Mit mehr echten Spielern werden es weniger, ab FillUntilPlayers gibt es keine Bots mehr.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local NpcBody = require(script.Parent.NpcBody)

local BotService = { Services = nil :: any, Bots = {} :: { any } }

local B = Config.Bots
local C = Config.Colors

local folder: Folder
local usedNames = {} -- [Name] = true
local lastAnnounce = -math.huge
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

function BotService:Init(services)
	self.Services = services
end

local function rand(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function teamOf(player: Player): string
	return if player.Team then player.Team.Name else "Citizens"
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function announce(text: string, color: Color3)
	if os.clock() - lastAnnounce > B.AnnounceCooldown and #Players:GetPlayers() > 0 then
		lastAnnounce = os.clock()
		BotService.Services.Net.SendAnnounce(text, color)
	end
end

---------------------------------------------------------------- Wege ueber die Strassen

local function groundY(position: Vector3, fromY: number): number
	local hit = workspace:Raycast(Vector3.new(position.X, fromY + 6, position.Z), Vector3.new(0, -30, 0), rayParams)
	return if hit then hit.Position.Y else fromY
end

-- Naechste Strasse (Index 0..Grid) zu einer Koordinate
local function roadIndex(value: number): number
	local step = Config.Block + Config.Road
	return math.clamp(math.round((value - Config.RoadLine(0)) / step), 0, Config.Grid)
end

-- Route von a nach b ueber das Strassennetz (am Strassenrand, damit Autos vorbeikommen)
function BotService.Route(a: Vector3, b: Vector3): { Vector3 }
	if (flat(b) - flat(a)).Magnitude < 60 then
		return { b }
	end
	local side = 12
	local ax = Config.RoadLine(roadIndex(a.X)) + side
	local bz = Config.RoadLine(roadIndex(b.Z)) + side
	return {
		Vector3.new(ax, a.Y, a.Z),
		Vector3.new(ax, a.Y, bz),
		Vector3.new(b.X, b.Y, bz),
		b,
	}
end

local function randomRoadPoint(near: Vector3?, radius: number?): Vector3
	local half = Config.CityHalf() - 20
	local x, z
	if near then
		x = math.clamp(near.X + math.random(-(radius or 300), radius or 300), -half, half)
		z = math.clamp(near.Z + math.random(-(radius or 300), radius or 300), -half, half)
	else
		x, z = math.random(-half, half), math.random(-half, half)
	end
	-- auf eine Strasse legen
	if math.random() < 0.5 then
		x = Config.RoadLine(roadIndex(x)) + 12
	else
		z = Config.RoadLine(roadIndex(z)) + 12
	end
	return Vector3.new(x, 0, z)
end

---------------------------------------------------------------- Bots

local function pickName(list: { string }): string
	local free = {}
	for _, name in list do
		if not usedNames[name] then
			table.insert(free, name)
		end
	end
	local name = if #free > 0 then free[math.random(1, #free)] else list[math.random(1, #list)] .. " " .. math.random(2, 9)
	usedNames[name] = true
	return name
end

local function updateTag(bot)
	if bot.Role == "Robber" then
		bot.Top.Text = if bot.Stars > 0 then "ROBBER " .. string.rep("★", bot.Stars) else "ROBBER"
		bot.Info.Text = if bot.Bag > 0 then `💰 {Format.Cash(bot.Bag)}` else ""
		bot.Model:SetAttribute("Wanted", bot.Stars)
	else
		bot.Info.Text = if bot.Target then "🚨 CHASING" else "on patrol"
	end
end

local function setBag(bot, amount: number)
	bot.Bag = amount
	local existing = bot.Model:FindFirstChild("LootBag")
	if amount <= 0 then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local torso = (bot.Model:FindFirstChild("UpperTorso") or bot.Model:FindFirstChild("Torso")) :: BasePart?
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
	bag.CanQuery = false
	bag.CanTouch = false
	bag.Massless = true
	bag.CFrame = torso.CFrame * CFrame.new(0, 0.3, 1.5)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = bag
	weld.Parent = bag
	bag.Parent = bot.Model
end

local function walk(bot, route: { Vector3 }, after: (() -> ())?)
	bot.Route = route
	bot.RouteIndex = 1
	bot.After = after
	bot.Phase = "Walk"
	NpcBody.Play(bot.Model, "Run")
end

local function pause(bot, seconds: number, after: (() -> ())?)
	bot.Phase = "Wait"
	bot.Timer = seconds
	bot.After = after
	NpcBody.Play(bot.Model, "Idle")
end

local function say(bot, lines: { string }, chance: number?)
	if math.random() <= (chance or 1) then
		NpcBody.Say(bot.Model, lines[math.random(1, #lines)], 3)
	end
end

function BotService:Spawn(role: string)
	local world = self.Services.WorldService
	local isRobber = role == "Robber"
	local name = pickName(if isRobber then B.RobberNames else B.CopNames)
	local model, _, root = NpcBody.Build(name, { Tag = "CityBot", Hat = if isRobber then Color3.fromRGB(30, 30, 35) else C.Police })
	local top, nameLabel, info = NpcBody.Tag(model, if isRobber then "ROBBER" else "POLICE", if isRobber then C.Robber else C.Police, 150)
	nameLabel.TextColor3 = if isRobber then Color3.fromRGB(255, 210, 200) else Color3.fromRGB(200, 225, 255)
	model:SetAttribute("Role", role)
	local bot = {
		Role = role,
		Name = name,
		Model = model,
		Root = root,
		Top = top,
		Info = info,
		Height = NpcBody.RootHeight(model),
		Speed = if isRobber then B.RobberSpeed else B.CopSpeed,
		Stars = 0,
		Bag = 0,
		Phase = "Busy",
		Timer = 0,
		Route = {},
		RouteIndex = 1,
		After = nil :: (() -> ())?,
		StunnedUntil = 0,
		Target = nil :: any,
		NextChase = 0,
	}
	local spawn = world.Spawns[if isRobber then "Robbers" else "Police"] or Vector3.new(0, 0, 0)
	local start = spawn + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
	model.Parent = folder
	root.CFrame = CFrame.new(start.X, groundY(start, spawn.Y) + bot.Height, start.Z)
	NpcBody.Poof(root.Position)
	updateTag(bot)
	table.insert(self.Bots, bot)
	self:Decide(bot)
	return bot
end

function BotService:Remove(bot)
	local index = table.find(self.Bots, bot)
	if index then
		table.remove(self.Bots, index)
	end
	usedNames[bot.Name] = nil
	bot.Removed = true
	if bot.Model.Parent then
		NpcBody.Poof(bot.Root.Position)
	end
	bot.Model:Destroy()
end

---------------------------------------------------------------- Raeuber-Bots

local function alarmPolice(name: string, position: Vector3)
	local net = BotService.Services.Net
	for _, cop in Players:GetPlayers() do
		if teamOf(cop) == "Police" then
			net.SendNotify(cop, `ALARM! The {name} is being robbed!`, C.Robber)
			net.SendMarker(cop, position, `ALARM: {name}`, "Alarm")
		end
	end
end

function BotService:RobberLoop(bot)
	local world = self.Services.WorldService
	local keys = {}
	for key in Config.Robberies do
		if world.RobPoints[key] then
			table.insert(keys, key)
		end
	end
	if #keys == 0 then
		pause(bot, 5, function()
			self:Decide(bot)
		end)
		return
	end
	local key = keys[math.random(1, #keys)]
	local info = Config.Robberies[key]
	local point = world.RobPoints[key].Position
	local target = point + flat(bot.Root.Position - point).Unit * 4
	walk(bot, BotService.Route(bot.Root.Position, target), function()
		say(bot, { "Grab the cash!", "This is a robbery!", "Quick, quick!", "Ka-ching!" })
		bot.Stars = math.min(Config.MaxWanted, info.Stars + 1)
		updateTag(bot)
		alarmPolice(info.Name, point)
		pause(bot, info.Hold * B.RobHoldFactor, function()
			setBag(bot, info.Loot * B.LootFactor)
			updateTag(bot)
			local hideout = world.Hideout
			local goal = if hideout then hideout.Position else world.Spawns.Robbers
			walk(bot, BotService.Route(bot.Root.Position, goal), function()
				-- Entkommen!
				if bot.Bag > 0 then
					announce(`🤖 {bot.Name} got away with {Format.Cash(bot.Bag)}! Police, step up!`, C.Lemon)
					say(bot, { "Too slow, cops!", "Got away!", "Easy money!" })
				end
				setBag(bot, 0)
				bot.Stars = 0
				updateTag(bot)
				pause(bot, rand(B.RestTime), function()
					self:Decide(bot)
				end)
			end)
		end)
	end)
end

-- Festnahme eines Raeuber-Bots (durch echten Polizisten oder Polizei-Bot)
function BotService:Bust(bot, officer: Player?)
	if bot.Removed or bot.Jailed then
		return
	end
	bot.Jailed = true
	local stars, bag = bot.Stars, bot.Bag
	if officer then
		self.Services.JobService:PayBounty(officer, bot.Name, math.max(stars, 1), bag)
	end
	say(bot, { "Nooo!", "Not fair!", "I'll be back!" })
	NpcBody.Poof(bot.Root.Position)
	setBag(bot, 0)
	bot.Stars = 0
	updateTag(bot)
	-- Kurz "im Gefaengnis" (unsichtbar), dann wieder am Versteck
	bot.Model.Parent = nil
	bot.Phase = "Jail"
	task.delay(B.JailTime, function()
		if bot.Removed then
			return
		end
		bot.Jailed = false
		local spawn = self.Services.WorldService.Spawns.Robbers or Vector3.zero
		bot.Model.Parent = folder
		bot.Root.CFrame = CFrame.new(spawn.X, groundY(spawn, spawn.Y) + bot.Height, spawn.Z)
		NpcBody.Poof(bot.Root.Position)
		self:Decide(bot)
	end)
end

function BotService:Stun(bot, seconds: number)
	bot.StunnedUntil = os.clock() + seconds
	NpcBody.Play(bot.Model, "Idle")
	say(bot, { "Zapped!", "Can't move!", "Bzzzt!" })
end

-- Fuer JobService: gesuchter Raeuber-Bot in Reichweite (Handschellen) bzw. im Blickkegel (Blaster)
function BotService:FindRobber(position: Vector3, range: number, look: Vector3?): any?
	local best, bestDistance = nil, range
	for _, bot in self.Bots do
		if bot.Role == "Robber" and not bot.Jailed and (bot.Stars > 0 or bot.Bag > 0) then
			local offset = bot.Root.Position - position
			local distance = offset.Magnitude
			local inCone = look == nil or (distance > 0 and flat(offset).Unit:Dot(look) > 0.75)
			if distance < bestDistance and inCone then
				best, bestDistance = bot, distance
			end
		end
	end
	return best
end

---------------------------------------------------------------- Polizei-Bots

-- Gesuchte echte Raeuber (zu Fuss oder im Auto) und Raeuber-Bots in Sichtweite
local function findTarget(bot): any?
	local position = bot.Root.Position
	local best, bestDistance = nil, B.ChaseRange
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and teamOf(player) == "Robbers" and not player:GetAttribute("JailUntil") and ((player:GetAttribute("Wanted") or 0) > 0 or (player:GetAttribute("Bag") or 0) > 0) then
			local distance = (root.Position - position).Magnitude
			if distance < bestDistance then
				best, bestDistance = { Player = player }, distance
			end
		end
	end
	if best then
		return best
	end
	local robber = BotService:FindRobber(position, B.BotChaseRange)
	return robber and { Bot = robber }
end

local function targetRoot(target): BasePart?
	if target.Player then
		return if target.Player.Parent then rootOf(target.Player) else nil
	end
	return if target.Bot and not target.Bot.Removed and not target.Bot.Jailed then target.Bot.Root else nil
end

function BotService:Patrol(bot)
	local around = self.Services.WorldService.Spawns.Police
	walk(bot, BotService.Route(bot.Root.Position, randomRoadPoint(if math.random() < 0.5 then around else nil, 400)), function()
		pause(bot, rand(B.RestTime) * 0.5, function()
			self:Decide(bot)
		end)
	end)
end

function BotService:CatchPlayer(bot, robber: Player)
	local humanoid = robber.Character and robber.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.SeatPart or robber:GetAttribute("JailUntil") then
		return
	end
	local stars = robber:GetAttribute("Wanted") or 0
	say(bot, { "Busted!", "You're under arrest!", "Gotcha!" })
	self.Services.Net.SendAnnounce(`🤖 Officer {bot.Name} arrested {robber.DisplayName}!`, C.Police)
	self.Services.JobService:Jail(robber, stars)
	bot.Target = nil
	updateTag(bot)
end

local function chase(bot, dt: number)
	local target = bot.Target
	local root = target and targetRoot(target)
	if not root or (target.Player and (target.Player:GetAttribute("JailUntil") or (target.Player:GetAttribute("Wanted") or 0) <= 0 and (target.Player:GetAttribute("Bag") or 0) <= 0)) then
		bot.Target = nil
		updateTag(bot)
		BotService:Decide(bot)
		return
	end
	local offset = flat(root.Position - bot.Root.Position)
	local distance = offset.Magnitude
	if distance > B.ChaseRange * 1.3 then
		say(bot, { "Lost them...", "Where did they go?" }, 0.5)
		bot.Target = nil
		updateTag(bot)
		BotService:Decide(bot)
		return
	end
	if distance <= B.CatchRange then
		if target.Player then
			BotService:CatchPlayer(bot, target.Player)
		else
			say(bot, { "Busted!", "Gotcha!" })
			BotService:Bust(target.Bot, nil)
			bot.Target = nil
			updateTag(bot)
		end
		pause(bot, 2, function()
			BotService:Decide(bot)
		end)
		return
	end
	-- Direkt hinterher (auf kurze Strecke) bzw. ueber die Strassen
	local goal: Vector3
	if distance < 70 then
		goal = root.Position
	else
		if os.clock() >= bot.NextChase or not bot.Route[bot.RouteIndex] then
			bot.NextChase = os.clock() + 2
			bot.Route = BotService.Route(bot.Root.Position, root.Position)
			bot.RouteIndex = 1
		end
		goal = bot.Route[bot.RouteIndex]
	end
	local toGoal = flat(goal - bot.Root.Position)
	local step = bot.Speed * B.ChaseBoost * dt
	if toGoal.Magnitude <= step and distance >= 70 then
		bot.RouteIndex += 1
	end
	local move = if toGoal.Magnitude > 0.05 then toGoal.Unit * math.min(step, toGoal.Magnitude) else Vector3.zero
	local position = bot.Root.Position + move
	local y = groundY(position, bot.Root.Position.Y - bot.Height) + bot.Height
	local look = if toGoal.Magnitude > 0.05 then toGoal.Unit else bot.Root.CFrame.LookVector
	local final = Vector3.new(position.X, y, position.Z)
	bot.Root.CFrame = CFrame.lookAt(final, final + flat(look))
end

---------------------------------------------------------------- Ablauf

function BotService:Decide(bot)
	if bot.Removed or bot.Jailed then
		return
	end
	bot.Phase = "Busy"
	if bot.Role == "Robber" then
		self:RobberLoop(bot)
	else
		self:Patrol(bot)
	end
end

local function finish(bot)
	bot.Phase = "Busy"
	local after = bot.After
	bot.After = nil
	if after then
		after()
	end
end

local function update(bot, dt: number)
	if bot.Removed or bot.Jailed then
		return
	end
	if os.clock() < bot.StunnedUntil then
		return
	end
	-- Polizei-Bots schauen regelmaessig nach gesuchten Raeubern
	if bot.Role == "Cop" and bot.Phase ~= "Chase" then
		bot.Scan = (bot.Scan or 0) - dt
		if bot.Scan <= 0 then
			bot.Scan = 0.5
			local target = findTarget(bot)
			if target then
				bot.Target = target
				bot.Phase = "Chase"
				bot.Route = {}
				bot.NextChase = 0
				bot.After = nil
				NpcBody.Play(bot.Model, "Run")
				say(bot, { "Stop right there!", "Freeze!", "Police! Don't move!" }, 0.8)
				updateTag(bot)
			end
		end
	end
	if bot.Phase == "Chase" then
		chase(bot, dt)
	elseif bot.Phase == "Wait" then
		bot.Timer -= dt
		if bot.Timer <= 0 then
			finish(bot)
		end
	elseif bot.Phase == "Walk" then
		local target = bot.Route[bot.RouteIndex]
		if not target then
			finish(bot)
			return
		end
		local position = bot.Root.Position
		local toTarget = flat(target - position)
		local step = bot.Speed * dt
		local nextPosition
		if toTarget.Magnitude <= step then
			nextPosition = Vector3.new(target.X, position.Y, target.Z)
			bot.RouteIndex += 1
		else
			nextPosition = position + toTarget.Unit * step
		end
		local y = groundY(nextPosition, position.Y - bot.Height) + bot.Height
		local look = if toTarget.Magnitude > 0.05 then toTarget.Unit else bot.Root.CFrame.LookVector
		local final = Vector3.new(nextPosition.X, y, nextPosition.Z)
		bot.Root.CFrame = CFrame.lookAt(final, final + flat(look))
		if bot.RouteIndex > #bot.Route then
			finish(bot)
		end
	end
end

-- Wie viele Raeuber- und Polizei-Bots gebraucht werden (echte Teams werden ausgeglichen)
function BotService:Wanted(): (number, number)
	local players = Players:GetPlayers()
	local total = math.clamp(B.FillUntilPlayers - #players, 0, B.MaxRobbers + B.MaxCops)
	local cops, robbers = 0, 0
	for _, player in players do
		local team = teamOf(player)
		if team == "Police" then
			cops += 1
		elseif team == "Robbers" then
			robbers += 1
		end
	end
	local wantRobbers = math.ceil(total / 2)
	if cops > robbers then
		wantRobbers += 1
	elseif robbers > cops then
		wantRobbers -= 1
	end
	wantRobbers = math.clamp(wantRobbers, 0, math.min(B.MaxRobbers, total))
	local wantCops = math.clamp(total - wantRobbers, 0, B.MaxCops)
	return wantRobbers, wantCops
end

function BotService:Count(role: string): number
	local count = 0
	for _, bot in self.Bots do
		if bot.Role == role then
			count += 1
		end
	end
	return count
end

function BotService:Balance()
	local wantRobbers, wantCops = self:Wanted()
	for _, entry in { { "Robber", wantRobbers }, { "Cop", wantCops } } do
		local role, want = entry[1], entry[2]
		for i = #self.Bots, 1, -1 do
			if self:Count(role) <= want then
				break
			end
			local bot = self.Bots[i]
			-- Keinen Raeuber mitten auf der Flucht entfernen, wenn es geht
			if bot.Role == role and (bot.Bag <= 0 or self:Count(role) > want + 1 or want == 0) then
				self:Remove(bot)
			end
		end
		if self:Count(role) < want then
			self:Spawn(role)
		end
	end
end

function BotService:Start()
	folder = Instance.new("Folder")
	folder.Name = "CityBots"
	folder.Parent = workspace
	local city = workspace:FindFirstChild("City")
	rayParams.FilterDescendantsInstances = if city then { city } else {}

	RunService.Heartbeat:Connect(function(dt)
		for _, bot in self.Bots do
			local ok, err = pcall(update, bot, math.min(dt, 0.1))
			if not ok then
				warn("City bot update failed:", err)
				bot.Phase = "Busy"
				task.defer(self.Decide, self, bot)
			end
		end
	end)

	Players.PlayerAdded:Connect(function()
		task.defer(self.Balance, self)
	end)
	Players.PlayerRemoving:Connect(function()
		task.delay(2, self.Balance, self)
	end)
	task.spawn(function()
		while true do
			self:Balance()
			task.wait(B.SpawnInterval)
		end
	end)
end

return BotService
