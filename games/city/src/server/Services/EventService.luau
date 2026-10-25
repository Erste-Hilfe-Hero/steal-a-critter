-- Update 2: Leben in der Stadt.
--   Stadt-Events (Crime Wave, Double Bounty, Rush Hour), der Geldtransporter fuer Raeuber,
--   Blitzer mit Rekorden und die Spray-Werkstatt, in der Raeuber ihre Sterne loswerden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Build = require(script.Parent.Build)

local EventService = { Services = nil :: any }

local C = Config.Colors
local TRUCK_RANGE = 16

local truck = nil :: { Model: Model, Left: number, Position: Vector3, Token: number }?
local truckToken = 0
local lastCrack = {} -- [Player] = os.clock()
local lastCam = {} -- [Player] = { [camIndex] = os.clock() }
local lastSpray = {} -- [Player] = os.clock()
local lastSprayHint = {} -- [Player] = os.clock()

local function notify(player: Player, text: string, color: Color3?)
	EventService.Services.Net.SendNotify(player, text, color)
end

local function teamOf(player: Player): string
	return if player.Team then player.Team.Name else "Citizens"
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function EventService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Stadt-Events

function EventService:Active(id: string): boolean
	return workspace:GetAttribute("EventId") == id and (workspace:GetAttribute("EventUntil") or 0) > os.time()
end

function EventService:StartEvent(id: string?)
	local list = Config.CityEvents
	local event = if id then Config.EventsById[id] else nil
	if not event then
		local last = workspace:GetAttribute("EventId")
		repeat
			event = list[math.random(1, #list)]
		until #list < 2 or event.Id ~= last
	end
	assert(event)
	workspace:SetAttribute("EventId", event.Id)
	workspace:SetAttribute("EventUntil", os.time() + Config.EventDuration)
	self.Services.Net.SendAnnounce(`CITY EVENT: {event.Name}! {event.Text} ({Config.EventDuration // 60} min)`, event.Color)
end

---------------------------------------------------------------- Geldtransporter

local function buildTruck(cf: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "ArmoredTruck"
	local body = Build.Box(model, cf * CFrame.new(0, 2, 2), Vector3.new(8, 8, 13), Color3.fromRGB(110, 125, 150), Enum.Material.DiamondPlate)
	body.Name = "Body"
	Build.Box(model, cf * CFrame.new(0, 2, -7), Vector3.new(7.6, 6, 5), Color3.fromRGB(90, 105, 130))
	Build.Box(model, cf * CFrame.new(0, 5, -9.3), Vector3.new(6.4, 2.4, 0.3), Color3.fromRGB(150, 210, 255), Enum.Material.Glass)
	for _, sx in { -1, 1 } do
		for _, sz in { -6, 5 } do
			Build.Part(model, {
				Size = Vector3.new(1.4, 4, 4),
				Shape = Enum.PartType.Cylinder,
				CFrame = cf * CFrame.new(sx * 4, 2, sz),
				Color = C.Ink,
			})
		end
	end
	-- Goldenes $-Schild an beiden Seiten
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Back } do
		Build.Sign(body, "$", Color3.fromRGB(110, 125, 150), C.Lemon, face)
	end
	local light = Build.Part(model, {
		Size = Vector3.new(1.6, 0.8, 1.6),
		CFrame = cf * CFrame.new(0, 10.4, 2),
		Color = C.Orange,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	light:AddTag("Blink")
	local billboard = Build.Billboard(body, "ARMORED TRUCK", C.Lemon, 9, 400)
	billboard.Name = "TruckLabel"
	return model
end

function EventService:DespawnTruck(message: string?)
	local current = truck
	if not current then
		return
	end
	truck = nil
	workspace:SetAttribute("TruckAt", nil)
	current.Model:Destroy()
	if message then
		self.Services.Net.SendAnnounce(message, C.Lemon)
	end
end

function EventService:SpawnTruck(): boolean
	if truck then
		return false
	end
	local world = self.Services.WorldService
	local points = world.DeliveryPoints
	if #points == 0 then
		return false
	end
	-- Nicht direkt beim Versteck oder bei der Polizei
	local position, side
	for _ = 1, 40 do
		local candidate = points[math.random(1, #points)]
		local farFromHideout = not world.Hideout or (flat(candidate) - flat(world.Hideout.Position)).Magnitude > 300
		local farFromPolice = not world.Spawns.Police or (flat(candidate) - flat(world.Spawns.Police)).Magnitude > 250
		if farFromHideout and farFromPolice and candidate.Z < Config.RoadLine(Config.Grid - 1) then
			position = candidate
			break
		end
	end
	if not position then
		return false
	end
	-- Richtung der Strasse: senkrecht zum Weg vom Blockmittelpunkt
	local center = Vector3.zero
	local bestDistance = math.huge
	for bx = 0, Config.Grid - 1 do
		for bz = 0, Config.Grid - 1 do
			local candidate = Config.BlockCenter(bx, bz)
			local distance = (flat(candidate) - flat(position)).Magnitude
			if distance < bestDistance then
				center, bestDistance = candidate, distance
			end
		end
	end
	side = flat(position - center)
	if side.Magnitude < 1 then
		side = Vector3.new(1, 0, 0)
	end
	side = side.Unit
	local spot = position + side * 5
	local along = Vector3.new(-side.Z, 0, side.X)
	local cf = CFrame.lookAt(spot, spot + along)
	local model = buildTruck(cf)
	local body = model:FindFirstChild("Body") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Crack Truck"
	prompt.ObjectText = "Armored Truck"
	prompt.HoldDuration = Config.Truck.Hold
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Team", "Robbers")
	prompt.Parent = body
	truckToken += 1
	local token = truckToken
	truck = { Model = model, Left = Config.Truck.Grabs, Position = spot, Token = token }
	prompt.Triggered:Connect(function(player)
		self:Crack(player)
	end)
	model.Parent = workspace
	workspace:SetAttribute("TruckAt", spot)
	self.Services.Net.SendAnnounce("An ARMORED TRUCK stopped in the city! Robbers: crack it! Cops: guard it!", C.Lemon)
	for _, player in Players:GetPlayers() do
		local team = teamOf(player)
		if (team == "Robbers" and not player:GetAttribute("Bag")) or team == "Police" then
			self.Services.Net.SendMarker(player, spot, "ARMORED TRUCK", if team == "Police" then "Alarm" else "Truck")
		end
	end
	task.delay(Config.Truck.Duration, function()
		if truck and truck.Token == token then
			self:DespawnTruck("The armored truck drove away safely.")
		end
	end)
	return true
end

function EventService:Crack(player: Player)
	local current = truck
	if not current or current.Left <= 0 then
		return
	end
	if teamOf(player) ~= "Robbers" then
		notify(player, "Only Robbers can crack the truck!", C.Robber)
		return
	end
	if player:GetAttribute("JailUntil") then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (flat(root.Position) - flat(current.Position)).Magnitude > TRUCK_RANGE then
		return
	end
	-- Haltezeit auch auf dem Server pruefen (Big Loot Bag halbiert sie)
	local hold = Config.Truck.Hold * (if player:GetAttribute("Pass_BigBag") then 0.5 else 1)
	local t = os.clock()
	if t - (lastCrack[player] or -math.huge) < hold * 0.8 then
		return
	end
	lastCrack[player] = t
	local jobs = self.Services.JobService
	local amount = jobs:GiveLoot(player, Config.Truck.Loot, Config.Truck.Stars)
	if not amount then
		return
	end
	local first = current.Left == Config.Truck.Grabs
	current.Left -= 1
	local data = self.Services.DataService:Get(player)
	if data then
		data.Stats.Trucks += 1
	end
	self.Services.ProgressService:AddXP(player, Config.Xp.Truck)
	self.Services.ProgressService:Check(player)
	notify(player, `+{Format.Cash(amount)} from the armored truck! Get to the HIDEOUT!`, C.Green)
	if first then
		for _, cop in Players:GetPlayers() do
			if teamOf(cop) == "Police" then
				notify(cop, "ALARM! Robbers are cracking the armored truck!", C.Robber)
				self.Services.Net.SendMarker(cop, current.Position, "ALARM: TRUCK", "Alarm")
			end
		end
	end
	if current.Left <= 0 then
		task.delay(2, function()
			if truck == current then
				self:DespawnTruck("The armored truck was emptied by robbers!")
			end
		end)
	end
end

---------------------------------------------------------------- Blitzer

local function checkSpeedCams(player: Player, base: BasePart, car: Model)
	local cams = EventService.Services.WorldService.SpeedCams
	local now = os.clock()
	local times = lastCam[player]
	if not times then
		times = {}
		lastCam[player] = times
	end
	for index, cam in cams do
		if (flat(base.Position) - flat(cam.Position)).Magnitude < Config.SpeedCamRadius and now - (times[index] or -math.huge) > 6 then
			times[index] = now
			-- Hoechstens so schnell, wie das Auto mit Nitro und Boost ueberhaupt fahren kann
			local limit = (car:GetAttribute("MaxSpeed") or 60) * Config.NitroBoost * Config.BoostPadSpeed * 1.1
			local studs = math.min(flat(base.AssemblyLinearVelocity).Magnitude, limit)
			local kmh = math.floor(studs * Config.KmhPerStud)
			if kmh < 20 then
				continue
			end
			local data = EventService.Services.DataService:Get(player)
			if not data then
				return
			end
			local best = data.Stats.TopSpeed
			local record = kmh > best
			if record then
				data.Stats.TopSpeed = kmh
				for _, reward in Config.SpeedRewards do
					if best < reward.Kmh and kmh >= reward.Kmh then
						EventService.Services.DataService:AddCash(player, reward.Cash)
						notify(player, `Speed reward: first time over {reward.Kmh} km/h! +{Format.Cash(reward.Cash)}`, C.Lemon)
					end
				end
				EventService.Services.ProgressService:Sync(player)
				EventService.Services.ProgressService:Check(player)
			end
			EventService.Services.ProgressService:AddXP(player, Config.Xp.SpeedCam)
			EventService.Services.Net.Celebrate:FireClient(player, `{kmh} KM/H`, `Speed cam {cam.Name}` .. (if record then "  NEW RECORD!" else `  Best: {data.Stats.TopSpeed}`), "Flash")
		end
	end
end

---------------------------------------------------------------- Spray-Werkstatt

local function insidePad(pad: BasePart, position: Vector3): boolean
	local offset = pad.CFrame:PointToObjectSpace(position)
	return math.abs(offset.X) < pad.Size.X / 2 and math.abs(offset.Z) < pad.Size.Z / 2 and offset.Y > -3 and offset.Y < 10
end

local SPRAY_COLORS = {
	Color3.fromRGB(255, 61, 127),
	Color3.fromRGB(25, 211, 197),
	Color3.fromRGB(255, 225, 77),
	Color3.fromRGB(150, 90, 255),
	Color3.fromRGB(80, 220, 120),
	Color3.fromRGB(255, 122, 26),
	Color3.fromRGB(245, 245, 250),
}

local function hint(player: Player, text: string)
	local t = os.clock()
	if t - (lastSprayHint[player] or -math.huge) > 5 then
		lastSprayHint[player] = t
		notify(player, text, C.Robber)
	end
end

local function trySpray(player: Player, pad: BasePart, car: Model)
	local stars = player:GetAttribute("Wanted") or 0
	if stars <= 0 then
		if teamOf(player) == "Robbers" then
			hint(player, "TURBO SPRAY: you have no wanted stars to lose.")
		end
		return
	end
	local t = os.clock()
	local wait = Config.SprayCooldown - (t - (lastSpray[player] or -math.huge))
	if wait > 0 then
		hint(player, `The spray guns are cooling down: {math.ceil(wait)}s`)
		return
	end
	for _, cop in Players:GetPlayers() do
		local character = cop.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if teamOf(cop) == "Police" and root and (root.Position - pad.Position).Magnitude < Config.SprayCopRange then
			hint(player, "A cop is watching! Lose them first.")
			return
		end
	end
	local cost = stars * Config.SprayCostPerStar
	if not EventService.Services.DataService:Spend(player, cost) then
		hint(player, `A new paint job costs {Format.Cash(cost)}!`)
		return
	end
	lastSpray[player] = t
	EventService.Services.JobService:ClearWanted(player)
	-- Neue Farbe nur fuer dieses Auto (verschwindet beim naechsten Spawnen)
	local color = SPRAY_COLORS[math.random(1, #SPRAY_COLORS)]
	for _, part in car:GetDescendants() do
		if part:IsA("BasePart") and part:HasTag("CarPaint") then
			part:RemoveTag("RainbowPaint")
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	local data = EventService.Services.DataService:Get(player)
	if data then
		data.Stats.Sprays += 1
	end
	EventService.Services.ProgressService:AddXP(player, Config.Xp.Spray)
	EventService.Services.Net.Celebrate:FireClient(player, "FRESH PAINT!", `The cops lost your trail. -{Format.Cash(cost)}`, "Spray")
end

---------------------------------------------------------------- Ablauf

function EventService:OnPlayerRemoving(player: Player)
	lastCrack[player] = nil
	lastCam[player] = nil
	lastSpray[player] = nil
	lastSprayHint[player] = nil
end

function EventService:Start()
	-- Stadt-Events im Wechsel
	task.spawn(function()
		while true do
			task.wait(Config.EventInterval)
			if #Players:GetPlayers() > 0 then
				self:StartEvent()
				task.delay(Config.EventDuration, function()
					if (workspace:GetAttribute("EventUntil") or 0) <= os.time() then
						workspace:SetAttribute("EventId", nil)
						workspace:SetAttribute("EventUntil", nil)
					end
				end)
			end
		end
	end)

	-- Geldtransporter, sobald Raeuber online sind
	task.spawn(function()
		while true do
			task.wait(Config.Truck.Interval)
			local robbers = self.Services.WorldService.TeamObjects.Robbers
			if robbers and #robbers:GetPlayers() > 0 then
				self:SpawnTruck()
			end
		end
	end)

	-- Blitzer und Spray-Werkstatt
	task.spawn(function()
		while true do
			task.wait(0.15)
			local pad = self.Services.WorldService.SprayPad
			for _, player in Players:GetPlayers() do
				local car = self.Services.VehicleService:GetCar(player)
				local base = car and car.PrimaryPart
				if car and base and player:GetAttribute("Driving") then
					checkSpeedCams(player, base, car)
					if pad and insidePad(pad, base.Position) then
						trySpray(player, pad, car)
					end
				end
			end
		end
	end)
end

return EventService
