-- Autos aus Parts bauen, spawnen, kaufen, lackieren. Gefahren wird auf dem Client (Network Owner = Fahrer):
-- LinearVelocity (horizontal) + AlignOrientation (bleibt aufrecht, lenkt). Siehe client/Drive.luau.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local VehicleService = { Services = nil :: any }

local C = Config.Colors
local INK = C.Ink
local GLASS = Color3.fromRGB(150, 210, 255)

local carsFolder: Folder
local cars = {} -- [Player] = Model
local lastSpawn = {} -- [Player] = os.clock()

local STYLES = {
	Hatch = { Wheel = 1.5, BodyH = 2.6, Cabin = 0.55, CabinZ = 0.12, CabinH = 2.6 },
	Sedan = { Wheel = 1.5, BodyH = 2.3, Cabin = 0.45, CabinZ = 0.05, CabinH = 2.4 },
	Buggy = { Wheel = 1.9, BodyH = 1.3, Cage = true },
	Pickup = { Wheel = 1.8, BodyH = 2.6, Cabin = 0.32, CabinZ = -0.12, CabinH = 2.8, Bed = true },
	Muscle = { Wheel = 1.6, BodyH = 2.3, Cabin = 0.36, CabinZ = 0.1, CabinH = 2.0, Stripes = true, Scoop = true },
	Sport = { Wheel = 1.5, BodyH = 1.8, Cabin = 0.34, CabinZ = 0.06, CabinH = 1.7, Spoiler = true, Stripes = true },
	Super = { Wheel = 1.5, BodyH = 1.6, Cabin = 0.3, CabinZ = 0, CabinH = 1.5, Spoiler = true },
	Monster = { Wheel = 3.4, BodyH = 2.8, Cabin = 0.4, CabinZ = 0.05, CabinH = 2.6, Lift = 1.6 },
	Kart = { Wheel = 1.2, BodyH = 1, Rockets = true },
	Police = { Wheel = 1.5, BodyH = 2.3, Cabin = 0.45, CabinZ = 0.05, CabinH = 2.4, Siren = true, Stripe = C.Police },
	Swat = { Wheel = 1.8, BodyH = 3, Cabin = 0.6, CabinZ = 0.12, CabinH = 3, Siren = true, Stripe = C.Lemon },
}

local function weldTo(base: BasePart, part: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
end

-- Baut ein Auto. Unterkante der Raeder liegt bei y = 0 des CFrames, vorn = -Z.
-- options: Paint (Color3?), Material, Rainbow, Underglow, Anchored
function VehicleService.BuildCar(def, options: { [string]: any }?): Model
	local opts = options or {}
	local style = STYLES[def.Style] or STYLES.Sedan
	local L, W = def.L, def.W
	local r = style.Wheel
	local paint = opts.Paint or def.Color
	local material = opts.Material or Enum.Material.SmoothPlastic

	local model = Instance.new("Model")
	model.Name = def.Name
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(W - 0.6, 1, L - 0.4)
	base.CFrame = CFrame.new(0, 0.5, 0)
	base.Transparency = 1
	base.CustomPhysicalProperties = PhysicalProperties.new(2, 0, 0, 100, 100)
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Anchored = opts.Anchored == true
	base.Parent = model
	model.PrimaryPart = base

	local function part(props): Part
		local p = Instance.new("Part")
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.Massless = true
		p.Anchored = false
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = model
		weldTo(base, p)
		return p
	end
	local function paintPart(p: BasePart)
		p.Color = paint
		p.Material = material
		p:AddTag("CarPaint")
		if opts.Rainbow then
			p:AddTag("RainbowPaint")
		end
	end

	local bottom = r * 0.85 + (style.Lift or 0)
	local bodyTop = bottom + style.BodyH
	local body = part({ Name = "Body", Size = Vector3.new(W, style.BodyH, L), CFrame = CFrame.new(0, bottom + style.BodyH / 2, 0), CanCollide = true })
	paintPart(body)
	-- Stossstangen
	part({ Size = Vector3.new(W + 0.2, 0.8, 0.6), CFrame = CFrame.new(0, bottom + 0.4, -L / 2 - 0.2), Color = INK })
	part({ Size = Vector3.new(W + 0.2, 0.8, 0.6), CFrame = CFrame.new(0, bottom + 0.4, L / 2 + 0.2), Color = INK })
	-- Lichter
	for _, s in { -1, 1 } do
		local head = part({ Name = "Headlight", Size = Vector3.new(1.3, 0.7, 0.2), CFrame = CFrame.new(s * (W / 2 - 1), bodyTop - 0.6, -L / 2 - 0.05), Color = Color3.fromRGB(255, 250, 210), Material = Enum.Material.Neon })
		if s == 1 then
			local light = Instance.new("SpotLight")
			light.Face = Enum.NormalId.Front
			light.Range = 40
			light.Angle = 70
			light.Brightness = 2
			light.Parent = head
		end
		part({ Size = Vector3.new(1.3, 0.6, 0.2), CFrame = CFrame.new(s * (W / 2 - 1), bodyTop - 0.6, L / 2 + 0.05), Color = Color3.fromRGB(255, 40, 60), Material = Enum.Material.Neon })
	end
	-- Raeder
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local position = Vector3.new(sx * (W / 2 - 0.1), r, sz * (L / 2 - r - 0.5))
			part({ Name = "Wheel", Size = Vector3.new(1.3, r * 2, r * 2), Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(position), Color = INK })
			part({ Size = Vector3.new(1.4, r, r), Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(position), Color = C.Lemon })
			if style.Lift then
				part({ Size = Vector3.new(0.8, style.Lift + 1, 0.8), CFrame = CFrame.new(position.X * 0.8, r + style.Lift / 2, position.Z), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal })
			end
		end
	end
	-- Kabine
	local seatY = bottom + style.BodyH * 0.55
	local seatZ = 0
	if style.Cabin then
		local cabinL = L * style.Cabin
		local cabinZ = L * style.CabinZ
		part({ Name = "Cabin", Size = Vector3.new(W - 0.8, style.CabinH, cabinL), CFrame = CFrame.new(0, bodyTop + style.CabinH / 2, cabinZ), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.35 })
		local roof = part({ Size = Vector3.new(W - 0.5, 0.4, cabinL + 0.3), CFrame = CFrame.new(0, bodyTop + style.CabinH + 0.2, cabinZ) })
		paintPart(roof)
		seatZ = cabinZ + cabinL * 0.12
		if style.Siren then
			for i, color in { Color3.fromRGB(255, 40, 40), Color3.fromRGB(40, 110, 255) } do
				local light = part({ Name = "Siren", Size = Vector3.new(1.6, 0.6, 1), CFrame = CFrame.new((i - 1.5) * 1.8, bodyTop + style.CabinH + 0.7, cabinZ), Color = color, Material = Enum.Material.Neon })
				light:AddTag("Siren")
			end
		end
	else
		seatY = bottom + style.BodyH
		seatZ = L * 0.12
	end
	if style.Stripe then
		for _, s in { -1, 1 } do
			part({ Size = Vector3.new(0.1, 0.7, L * 0.9), CFrame = CFrame.new(s * (W / 2 + 0.03), bottom + style.BodyH * 0.5, 0), Color = style.Stripe, Material = Enum.Material.Neon })
		end
	end
	if style.Stripes then
		for _, s in { -1, 1 } do
			part({ Size = Vector3.new(0.7, 0.08, L * 0.98), CFrame = CFrame.new(s * 0.7, bodyTop + 0.03, 0), Color = Color3.new(1, 1, 1) })
		end
	end
	if style.Scoop then
		part({ Size = Vector3.new(2, 0.7, 2.4), CFrame = CFrame.new(0, bodyTop + 0.35, -L * 0.3), Color = INK })
	end
	if style.Spoiler then
		local wing = part({ Size = Vector3.new(W - 0.4, 0.3, 1.4), CFrame = CFrame.new(0, bodyTop + 1.3, L / 2 - 0.8) })
		paintPart(wing)
		for _, s in { -1, 1 } do
			part({ Size = Vector3.new(0.3, 1.2, 0.6), CFrame = CFrame.new(s * (W / 2 - 1.2), bodyTop + 0.6, L / 2 - 0.8), Color = INK })
		end
	end
	if style.Bed then
		for _, s in { -1, 1 } do
			local wall = part({ Size = Vector3.new(0.4, 1.2, L * 0.38), CFrame = CFrame.new(s * (W / 2 - 0.2), bodyTop + 0.6, L * 0.28) })
			paintPart(wall)
		end
	end
	if style.Cage then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part({ Size = Vector3.new(0.4, 3, 0.4), CFrame = CFrame.new(sx * (W / 2 - 0.6), bodyTop + 1.5, sz * 1.8 + L * 0.1), Color = INK })
			end
		end
		part({ Size = Vector3.new(W - 0.8, 0.4, 4), CFrame = CFrame.new(0, bodyTop + 3, L * 0.1), Color = INK })
	end
	if style.Rockets then
		for _, s in { -1, 1 } do
			part({ Size = Vector3.new(3, 1.4, 1.4), Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(s * 1.4, bodyTop + 0.3, L / 2 - 0.5) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(200, 200, 215), Material = Enum.Material.Metal })
			local flame = part({ Name = "Flame", Size = Vector3.new(0.3, 1, 1), Shape = Enum.PartType.Cylinder, CFrame = CFrame.new(s * 1.4, bodyTop + 0.3, L / 2 + 1.1) * CFrame.Angles(0, math.rad(90), 0), Color = C.Orange, Material = Enum.Material.Neon })
			local fire = Instance.new("ParticleEmitter")
			fire.Color = ColorSequence.new(C.Lemon, C.Orange)
			fire.Size = NumberSequence.new(0.8, 0)
			fire.Lifetime = NumberRange.new(0.15, 0.3)
			fire.Rate = 40
			fire.Speed = NumberRange.new(8)
			fire.LightEmission = 1
			fire.EmissionDirection = Enum.NormalId.Back
			fire.Parent = flame
		end
	end
	if opts.Underglow then
		local glow = part({ Name = "Underglow", Size = Vector3.new(W - 1, 0.2, L - 2), CFrame = CFrame.new(0, bottom - 0.15, 0), Color = C.Pink, Material = Enum.Material.Neon })
		glow:AddTag("Rainbow")
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 3
		light.Color = C.Pink
		light.Parent = glow
	end

	-- Sitze (Fahrer links, Beifahrer rechts)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(1.8, 0.4, 1.8)
	seat.CFrame = CFrame.new(-W * 0.2, seatY, seatZ)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.Parent = model
	weldTo(base, seat)
	local passenger = Instance.new("Seat")
	passenger.Name = "PassengerSeat"
	passenger.Size = Vector3.new(1.8, 0.4, 1.8)
	passenger.CFrame = CFrame.new(W * 0.2, seatY, seatZ)
	passenger.Transparency = 1
	passenger.CanCollide = false
	passenger.Massless = true
	passenger.Parent = model
	weldTo(base, passenger)

	if not opts.Anchored then
		local attachment = Instance.new("Attachment")
		attachment.Name = "Root"
		attachment.Parent = base
		local align = Instance.new("AlignOrientation")
		align.Name = "Align"
		align.Mode = Enum.OrientationAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.MaxTorque = 1e8
		align.Responsiveness = 30
		align.CFrame = CFrame.new()
		align.Parent = base
		local velocity = Instance.new("LinearVelocity")
		velocity.Name = "Drive"
		velocity.Attachment0 = attachment
		velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		velocity.PrimaryTangentAxis = Vector3.xAxis
		velocity.SecondaryTangentAxis = Vector3.zAxis
		velocity.RelativeTo = Enum.ActuatorRelativeTo.World
		velocity.PlaneVelocity = Vector2.zero
		velocity.MaxForce = (base:GetMass() + 40) * 160
		velocity.Parent = base
	end
	model:SetAttribute("CarId", def.Id)
	model:SetAttribute("MaxSpeed", def.Speed)
	model:SetAttribute("Turn", def.Turn)
	return model
end

---------------------------------------------------------------- Besitz

function VehicleService:Init(services)
	self.Services = services
	carsFolder = Instance.new("Folder")
	carsFolder.Name = "Cars"
	carsFolder.Parent = workspace
end

-- Darf der Spieler dieses Auto fahren?
function VehicleService:CanUse(player: Player, def): (boolean, string?)
	local team = player.Team and player.Team.Name
	if def.Team and def.Team ~= team then
		return false, `Only for the {def.Team} team!`
	end
	if def.Pass then
		return player:GetAttribute("Pass_" .. def.Pass) == true, nil
	end
	if def.Team then
		return true, nil
	end
	local data = self.Services.DataService:Get(player)
	return data ~= nil and data.Cars[def.Id] == true, nil
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

function VehicleService:Despawn(player: Player)
	local car = cars[player]
	if car then
		cars[player] = nil
		car:Destroy()
	end
	player:SetAttribute("CarOut", nil)
	-- Wird das Auto mit Fahrer zerstoert, feuert "Occupant" nicht mehr
	player:SetAttribute("Driving", nil)
end

-- Tuning-Stufe eines Autos (0..Config.TuneMax)
function VehicleService:GetTune(player: Player, carId: string): number
	local data = self.Services.DataService:Get(player)
	return if data then math.clamp(tonumber(data.Tune[carId]) or 0, 0, Config.TuneMax) else 0
end

local function applyTune(car: Model, def, level: number)
	car:SetAttribute("MaxSpeed", def.Speed * (1 + Config.TuneSpeed * level))
	car:SetAttribute("Turn", def.Turn * (1 + Config.TuneTurn * level))
	car:SetAttribute("Tune", level)
end

function VehicleService:GetCar(player: Player): Model?
	return cars[player]
end

local function spawnCFrame(player: Player): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local services = VehicleService.Services
	-- Am eigenen Haus: auf der Einfahrt
	local lot = services.HouseService and services.HouseService:GetDriveway(player)
	if lot and (lot.Position - root.Position).Magnitude < 90 then
		return lot
	end
	local point, direction = services.WorldService.NearestRoadPoint(root.Position)
	local cf = CFrame.lookAt(point, point + direction)
	-- Platz suchen, auf dem kein anderes Auto steht
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { carsFolder }
	for i = 0, 6 do
		local candidate = cf * CFrame.new(0, 0, (if i % 2 == 0 then 1 else -1) * math.ceil(i / 2) * 18)
		if #workspace:GetPartBoundsInBox(candidate * CFrame.new(0, 3, 0), Vector3.new(10, 6, 18), params) == 0 then
			return candidate
		end
	end
	return cf
end

function VehicleService:Spawn(player: Player, carId: string): (boolean, string?)
	local def = Config.CarsById[carId]
	if not def then
		return false, "Unknown car"
	end
	local ok, reason = self:CanUse(player, def)
	if not ok then
		if def.Pass and not reason then
			self.Services.MonetizationService:PromptPass(player, def.Pass)
			return false, nil
		end
		return false, reason or "You don't own this car yet"
	end
	if player:GetAttribute("JailUntil") then
		return false, "Not while in jail!"
	end
	local now = os.clock()
	if now - (lastSpawn[player] or -math.huge) < 3 then
		return false, "Wait a moment..."
	end
	local cf = spawnCFrame(player)
	if not cf then
		return false, "Respawn first"
	end
	lastSpawn[player] = now
	self:Despawn(player)
	local data = self.Services.DataService:Get(player)
	local paint = Config.PaintsById[data and data.Paint or "stock"]
	if paint and paint.Pass and not player:GetAttribute("Pass_" .. paint.Pass) then
		paint = nil
	end
	local options = {
		Paint = if paint and paint.Color and not def.Team then paint.Color else nil,
		Material = if paint and not def.Team then paint.Material else nil,
		Rainbow = paint ~= nil and paint.Rainbow == true and not def.Team,
		Underglow = player:GetAttribute("Pass_Underglow") == true,
	}
	local car = VehicleService.BuildCar(def, options)
	car.Name = player.Name .. "_Car"
	car:SetAttribute("Owner", player.UserId)
	applyTune(car, def, self:GetTune(player, def.Id))
	car:PivotTo(cf * CFrame.new(0, 0.3, 0))
	local base = car.PrimaryPart :: BasePart
	local align = base:FindFirstChild("Align") :: AlignOrientation
	align.CFrame = CFrame.Angles(0, yawOf(cf), 0)
	car.Parent = carsFolder
	base:SetNetworkOwner(nil)
	cars[player] = car
	-- Team-Autos (Polizei) nicht als Lieblingsauto speichern, sonst klappt CAR nach dem Teamwechsel nicht mehr
	if data and not def.Team then
		data.Car = def.Id
		player:SetAttribute("Car", def.Id)
	elseif def.Team then
		player:SetAttribute("TeamCar", def.Id)
	end
	player:SetAttribute("CarOut", def.Id)
	self.Services.ProgressService:Event(player, "Spawn")

	-- Fahrer/Beifahrer behandeln
	local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat
	local velocity = base:FindFirstChild("Drive") :: LinearVelocity
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local humanoid = seat.Occupant
		if humanoid then
			local driver = Players:GetPlayerFromCharacter(humanoid.Parent)
			if driver ~= player then
				humanoid.Sit = false
				humanoid.Jump = true
				if driver then
					self.Services.Net.SendNotify(driver, "That's not your car! Sit on the passenger side.", C.Robber)
				end
				return
			end
			pcall(base.SetNetworkOwner, base, player)
			player:SetAttribute("Driving", true)
			self.Services.MonetizationService:OnStartDriving(player)
		else
			player:SetAttribute("Driving", nil)
			if base.Parent then
				velocity.PlaneVelocity = Vector2.zero
				align.CFrame = CFrame.Angles(0, yawOf(base.CFrame), 0)
				pcall(base.SetNetworkOwner, base, nil)
			end
		end
	end)
	-- Direkt einsteigen
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		task.defer(function()
			if seat.Parent and not seat.Occupant then
				seat:Sit(humanoid)
			end
		end)
	end
	return true, `{def.Name} is ready!`
end

-- Wirft den Fahrer aus dem Auto (z. B. bei Festnahme)
function VehicleService:Eject(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
end

function VehicleService:Buy(player: Player, carId: string): (boolean, string?)
	local def = Config.CarsById[carId]
	local data = self.Services.DataService:Get(player)
	if not def or not data then
		return false, "Unknown car"
	end
	if def.Pass then
		self.Services.MonetizationService:PromptPass(player, def.Pass)
		return false, nil
	end
	if def.Team or not def.Price then
		return false, "This car can't be bought"
	end
	if data.Cars[def.Id] then
		return false, "You already own it"
	end
	if not self.Services.DataService:Spend(player, def.Price) then
		self.Services.MonetizationService:OfferCash(player, def.Price - data.Cash)
		return false, `You need {Format.Cash(def.Price - data.Cash)} more!`
	end
	data.Cars[def.Id] = true
	self.Services.DataService:UpdateAttributes(player)
	self.Services.ProgressService:Check(player)
	if def.Price >= 400_000 then
		self.Services.Net.SendAnnounce(`{player.DisplayName} bought a {def.Name}!`, C.Lemon)
	end
	return true, `You bought the {def.Name}! Spawn it from your garage.`
end

-- Motor eine Stufe hoeher (Spielgeld)
function VehicleService:Tune(player: Player, carId: string): (boolean, string?)
	local def = Config.CarsById[carId]
	local data = self.Services.DataService:Get(player)
	if not def or not data then
		return false, "Unknown car"
	end
	local ok = self:CanUse(player, def)
	if not ok and not (def.Team and (not def.Pass or player:GetAttribute("Pass_" .. def.Pass))) then
		return false, "You don't own this car yet"
	end
	local level = self:GetTune(player, carId)
	if level >= Config.TuneMax then
		return false, "Already fully tuned!"
	end
	local cost = Config.TuneCost(def, level + 1)
	if not self.Services.DataService:Spend(player, cost) then
		self.Services.MonetizationService:OfferCash(player, cost - data.Cash)
		return false, `You need {Format.Cash(cost - data.Cash)} more!`
	end
	self:SetTune(player, def, level + 1)
	return true, `{def.Name} engine tuned to stage {level + 1}!`
end

function VehicleService:SetTune(player: Player, def, level: number)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	data.Tune[def.Id] = level
	self.Services.DataService:UpdateAttributes(player)
	local car = cars[player]
	if car and car:GetAttribute("CarId") == def.Id then
		applyTune(car, def, level)
	end
end

-- Robux-Produkt "Max Tune": das ausgewaehlte Auto (sonst das naechste nicht fertige) auf volle Stufe
function VehicleService:MaxTune(player: Player): string?
	local data = self.Services.DataService:Get(player)
	if not data then
		return nil
	end
	local candidates = { data.Car }
	for _, def in Config.Cars do
		table.insert(candidates, def.Id)
	end
	for _, id in candidates do
		local def = Config.CarsById[id]
		if def and (data.Cars[id] or (def.Pass and player:GetAttribute("Pass_" .. def.Pass))) and self:GetTune(player, id) < Config.TuneMax then
			self:SetTune(player, def, Config.TuneMax)
			return def.Name
		end
	end
	return nil
end

function VehicleService:GiveCar(player: Player, carId: string)
	local data = self.Services.DataService:Get(player)
	if data then
		data.Cars[carId] = true
		self.Services.DataService:UpdateAttributes(player)
	end
end

function VehicleService:SetPaint(player: Player, paintId: string): (boolean, string?)
	local paint = Config.PaintsById[paintId]
	local data = self.Services.DataService:Get(player)
	if not paint or not data then
		return false, "Unknown paint"
	end
	if paint.Pass and not player:GetAttribute("Pass_" .. paint.Pass) then
		self.Services.MonetizationService:PromptPass(player, paint.Pass)
		return false, nil
	end
	data.Paint = paint.Id
	self.Services.DataService:UpdateAttributes(player)
	return true, `{paint.Name} paint selected. Spawn your car to see it!`
end

function VehicleService:Start()
	local net = self.Services.Net
	net.Handle("SpawnCar", function(player, carId)
		if typeof(carId) ~= "string" then
			return false, "Invalid"
		end
		return self:Spawn(player, carId)
	end)
	net.Handle("BuyCar", function(player, carId)
		if typeof(carId) ~= "string" then
			return false, "Invalid"
		end
		return self:Buy(player, carId)
	end)
	net.Handle("SetPaint", function(player, paintId)
		if typeof(paintId) ~= "string" then
			return false, "Invalid"
		end
		return self:SetPaint(player, paintId)
	end)
	net.Handle("Despawn", function(player)
		self:Despawn(player)
		return true, nil
	end)
	net.Handle("TuneCar", function(player, carId)
		if typeof(carId) ~= "string" then
			return false, "Invalid"
		end
		return self:Tune(player, carId)
	end)
	-- Auto fuer "Max Tune" auswaehlen (vor dem Kauf)
	net.Handle("SelectCar", function(player, carId)
		local def = typeof(carId) == "string" and Config.CarsById[carId]
		local data = self.Services.DataService:Get(player)
		if not def or not data or def.Team then
			return false, nil
		end
		if data.Cars[def.Id] or (def.Pass and player:GetAttribute("Pass_" .. def.Pass)) then
			data.Car = def.Id
			self.Services.DataService:UpdateAttributes(player)
			return true, nil
		end
		return false, nil
	end)

	-- Ausstellungsautos im Autohaus
	local shown = {}
	for _, def in Config.Cars do
		if not def.Team and #shown < #self.Services.WorldService.Showroom then
			table.insert(shown, def)
		end
	end
	table.sort(shown, function(a, b)
		return a.Order > b.Order
	end)
	for i, cf in self.Services.WorldService.Showroom do
		local def = shown[i]
		if def then
			local display = VehicleService.BuildCar(def, { Anchored = true })
			for _, p in display:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored = true
				end
			end
			display:PivotTo(cf * CFrame.Angles(0, math.rad(30 * i), 0))
			display.Parent = workspace
			local label = if def.Price then Format.Cash(def.Price) else "ROBUX"
			local sign = Instance.new("BillboardGui")
			sign.Size = UDim2.fromOffset(200, 60)
			sign.StudsOffset = Vector3.new(0, 8, 0)
			sign.MaxDistance = 90
			sign.Adornee = display.PrimaryPart
			sign.Parent = display
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.LuckiestGuy
			text.TextScaled = true
			text.TextColor3 = C.Lemon
			text.Text = `{def.Name}\n{label}`
			text.Parent = sign
			local stroke = Instance.new("UIStroke")
			stroke.Color = INK
			stroke.Thickness = 3
			stroke.Parent = text
		end
	end

	-- Gefahrene Strecke fuer Missionen
	task.spawn(function()
		local lastPosition = {}
		while true do
			task.wait(1)
			for player, car in cars do
				local base = car.PrimaryPart
				if base and player:GetAttribute("Driving") then
					local previous = lastPosition[player]
					local now = base.Position
					if previous then
						local distance = (Vector3.new(now.X, 0, now.Z) - Vector3.new(previous.X, 0, previous.Z)).Magnitude
						if distance < 250 then
							self.Services.RewardService:Progress(player, "Drive", distance)
							self.Services.ProgressService:Event(player, "Drive", distance)
						end
					end
					lastPosition[player] = now
				else
					lastPosition[player] = nil
				end
			end
			for player in lastPosition do
				if not cars[player] then
					lastPosition[player] = nil
				end
			end
		end
	end)
end

function VehicleService:OnPlayerRemoving(player: Player)
	self:Despawn(player)
	lastSpawn[player] = nil
end

return VehicleService
