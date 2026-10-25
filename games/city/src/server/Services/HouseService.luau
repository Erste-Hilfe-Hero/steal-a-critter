-- Haeuser in der Vorstadt: jeder Spieler bekommt ein Grundstueck, die Hausstufe wird gespeichert.
-- Jede Stufe zahlt Miete pro Minute (Gehaltsscheck) und zum Teil auch offline.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Build = require(script.Parent.Build)

local HouseService = { Services = nil :: any }

local C = Config.Colors
local INK = C.Ink
local GLASS = Color3.fromRGB(160, 215, 255)

local owners = {} -- [lotIndex] = Player
local lotOf = {} -- [Player] = lotIndex
local models = {} -- [lotIndex] = Model
local housesFolder: Folder

local WALLS = {
	Color3.fromRGB(255, 240, 220),
	Color3.fromRGB(255, 205, 210),
	Color3.fromRGB(200, 230, 255),
	Color3.fromRGB(215, 245, 215),
	Color3.fromRGB(255, 235, 170),
	Color3.fromRGB(230, 215, 255),
}

local function gable(parent: Instance, cf: CFrame, w: number, d: number, h: number, color: Color3)
	Build.Wedge(parent, cf * CFrame.new(0, h / 2, -d / 4), Vector3.new(w, h, d / 2), color)
	Build.Wedge(parent, cf * CFrame.new(0, h / 2, d / 4) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(w, h, d / 2), color)
end

local function windows(parent: Instance, cf: CFrame, w: number, y: number, count: number, size: Vector3?)
	for i = 1, count do
		local x = (i - (count + 1) / 2) * (w / count)
		Build.Part(parent, {
			Size = size or Vector3.new(4, 4, 0.4),
			CFrame = cf * CFrame.new(x, y, 0),
			Color = GLASS,
			Material = Enum.Material.Glass,
			Reflectance = 0.2,
			CanCollide = false,
		})
	end
end

local function door(parent: Instance, cf: CFrame, color: Color3)
	Build.Box(parent, cf, Vector3.new(4.5, 8, 0.5), color)
	Build.Part(parent, { Size = Vector3.new(0.5, 0.5, 0.6), CFrame = cf * CFrame.new(1.4, 4, 0), Color = C.Lemon, Material = Enum.Material.Neon })
end

local function pool(parent: Instance, cf: CFrame, size: Vector3)
	Build.Box(parent, cf, size + Vector3.new(3, 0, 3), Color3.fromRGB(240, 240, 245))
	Build.Box(parent, cf, size + Vector3.new(0, 0.05, 0), Color3.fromRGB(60, 200, 255), Enum.Material.Glass, { Transparency = 0.15, CanCollide = false })
end

-- Baut die Hausstufe auf das Grundstueck. cf = Grundstuecksmitte, LookVector = Strasse.
local function buildHouse(tier: number, cf: CFrame, colorIndex: number): Model
	local model = Instance.new("Model")
	model.Name = "House"
	local wall = WALLS[(colorIndex - 1) % #WALLS + 1]
	local roof = ({ C.Pink, C.Orange, C.Teal, Color3.fromRGB(120, 110, 200) })[(colorIndex - 1) % 4 + 1]
	local home = cf * CFrame.new(8, 0, 8)

	if tier == 1 then
		Build.Box(model, home, Vector3.new(28, 9, 12), Color3.fromRGB(245, 245, 250))
		Build.Box(model, home * CFrame.new(0, 4, -6.05), Vector3.new(28, 1.2, 0.2), roof)
		windows(model, home * CFrame.new(0, 0, -6.1), 20, 5.5, 3, Vector3.new(3, 2.5, 0.3))
		door(model, home * CFrame.new(-9, 0, -6.2), roof)
		Build.Box(model, home * CFrame.new(0, 9, 0), Vector3.new(28.6, 0.6, 12.6), Color3.fromRGB(200, 200, 210))
		for _, x in { -8, 8 } do
			Build.Part(model, { Size = Vector3.new(0.8, 3, 3), Shape = Enum.PartType.Cylinder, CFrame = home * CFrame.new(x, 1.5, -6), Color = INK })
		end
	elseif tier == 2 then
		Build.Box(model, home, Vector3.new(28, 12, 24), wall)
		gable(model, home * CFrame.new(0, 12, 0), 30, 26, 8, roof)
		windows(model, home * CFrame.new(0, 0, -12.1), 28, 6.5, 2)
		door(model, home * CFrame.new(0, 0, -12.2), roof)
		Build.Box(model, home * CFrame.new(8, 14, 6), Vector3.new(3, 9, 3), Color3.fromRGB(190, 110, 90))
		for i = -3, 3 do
			Build.Box(model, cf * CFrame.new(i * 5, 0, -36), Vector3.new(0.6, 3, 0.6), Color3.new(1, 1, 1))
		end
		Build.Box(model, cf * CFrame.new(0, 2.4, -36), Vector3.new(32, 0.5, 0.4), Color3.new(1, 1, 1))
	elseif tier == 3 then
		Build.Box(model, home, Vector3.new(34, 20, 28), wall)
		gable(model, home * CFrame.new(0, 20, 0), 36, 30, 10, roof)
		windows(model, home * CFrame.new(0, 0, -14.1), 30, 5.5, 3)
		windows(model, home * CFrame.new(0, 0, -14.1), 30, 14.5, 3)
		door(model, home * CFrame.new(0, 0, -14.2), roof)
		-- Garage
		Build.Box(model, home * CFrame.new(-25, 0, 2), Vector3.new(16, 11, 24), wall)
		Build.Box(model, home * CFrame.new(-25, 0, -10.1), Vector3.new(12, 8.5, 0.4), Color3.fromRGB(235, 235, 240))
		for s = 1, 4 do
			Build.Box(model, home * CFrame.new(-25, s * 2, -10.4), Vector3.new(12, 0.2, 0.2), INK)
		end
		Build.Box(model, home * CFrame.new(-25, 11, 2), Vector3.new(17, 0.8, 25), roof)
	elseif tier == 4 then
		-- Moderne Villa: versetzte Wuerfel, grosse Fenster, Pool
		Build.Box(model, home, Vector3.new(40, 12, 26), Color3.fromRGB(250, 250, 252))
		Build.Box(model, home * CFrame.new(-6, 12, 4), Vector3.new(30, 11, 22), Color3.fromRGB(70, 70, 90))
		Build.Box(model, home * CFrame.new(0, 0, -13.1), Vector3.new(34, 9, 0.4), GLASS, Enum.Material.Glass, { Reflectance = 0.25, CanCollide = false })
		Build.Box(model, home * CFrame.new(-6, 13, -7.1), Vector3.new(26, 8, 0.4), GLASS, Enum.Material.Glass, { Reflectance = 0.25, CanCollide = false })
		Build.Box(model, home * CFrame.new(-6, 23, 4), Vector3.new(31, 0.8, 23), roof)
		Build.Box(model, home * CFrame.new(0, 12, -13.4), Vector3.new(40, 0.6, 0.6), roof, Enum.Material.Neon)
		pool(model, cf * CFrame.new(22, 0, -24), Vector3.new(16, 0.3, 10))
	elseif tier == 5 then
		-- Strandvilla: drei Etagen, Saeulen, Pool, Palmen
		Build.Box(model, home, Vector3.new(46, 30, 30), wall)
		for floor = 0, 2 do
			windows(model, home * CFrame.new(0, 0, -15.1), 42, 5 + floor * 10, 5)
			Build.Box(model, home * CFrame.new(0, floor * 10 + 9.5, -16), Vector3.new(46, 0.8, 3), Color3.new(1, 1, 1))
		end
		for i = -2, 2 do
			Build.Part(model, { Size = Vector3.new(30, 2, 2), Shape = Enum.PartType.Cylinder, CFrame = home * CFrame.new(i * 10, 15, -17) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1) })
		end
		Build.Box(model, home * CFrame.new(0, 30, 0), Vector3.new(48, 1.4, 32), roof)
		door(model, home * CFrame.new(0, 0, -15.3), roof)
		pool(model, cf * CFrame.new(22, 0, -26), Vector3.new(18, 0.3, 10))
	elseif tier == 6 then
		-- Mega-Villa: Fluegel, Tuerme, goldene Kanten, Hubschrauber-Landeplatz
		Build.Box(model, home, Vector3.new(50, 32, 30), Color3.fromRGB(255, 250, 240))
		for _, s in { -1, 1 } do
			Build.Box(model, home * CFrame.new(s * 27, 0, 2), Vector3.new(10, 44, 10), Color3.fromRGB(255, 250, 240))
			Build.Box(model, home * CFrame.new(s * 27, 44, 2), Vector3.new(11, 1.2, 11), Color3.fromRGB(255, 200, 40), Enum.Material.Foil)
		end
		for floor = 0, 2 do
			windows(model, home * CFrame.new(0, 0, -15.1), 44, 5 + floor * 10, 6)
		end
		Build.Box(model, home * CFrame.new(0, 32, 0), Vector3.new(52, 1.4, 32), Color3.fromRGB(255, 200, 40), Enum.Material.Foil)
		local pad = Build.Part(model, { Size = Vector3.new(1, 20, 20), Shape = Enum.PartType.Cylinder, CFrame = home * CFrame.new(0, 33.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 60, 80) })
		Build.Sign(pad, "H", Color3.fromRGB(60, 60, 80), C.Lemon, Enum.NormalId.Right)
		door(model, home * CFrame.new(0, 0, -15.3), Color3.fromRGB(255, 200, 40))
		pool(model, cf * CFrame.new(22, 0, -26), Vector3.new(18, 0.3, 8))
	else
		-- Diamant-Penthouse: Glasturm mit leuchtendem Diamanten
		Build.Box(model, home, Vector3.new(30, 54, 30), Color3.fromRGB(150, 235, 255), Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.3 })
		for y = 9, 54, 9 do
			Build.Box(model, home * CFrame.new(0, y - 0.4, 0), Vector3.new(31, 0.8, 31), Color3.new(1, 1, 1))
		end
		for _, x in { -15, 15 } do
			for _, z in { -15, 15 } do
				Build.Box(model, home * CFrame.new(x, 0, z), Vector3.new(1.2, 55, 1.2), C.Teal, Enum.Material.Neon)
			end
		end
		local diamond = Build.Part(model, {
			Size = Vector3.new(9, 9, 9),
			CFrame = home * CFrame.new(0, 63, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color = Color3.fromRGB(140, 240, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		diamond:AddTag("Spin")
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 3
		light.Color = Color3.fromRGB(140, 240, 255)
		light.Parent = diamond
		door(model, home * CFrame.new(0, 0, -15.3), C.Teal)
		pool(model, cf * CFrame.new(22, 0, -26), Vector3.new(18, 0.3, 10))
	end
	-- Einfahrt und Briefkasten
	Build.Box(model, cf * CFrame.new(-22, 0, -28), Vector3.new(12, 0.15, 24), Color3.fromRGB(150, 150, 160))
	Build.Box(model, cf * CFrame.new(-31, 0, -37), Vector3.new(0.6, 4, 0.6), INK)
	Build.Box(model, cf * CFrame.new(-31, 4, -37), Vector3.new(1.6, 1.4, 2.4), roof)
	return model
end

HouseService.BuildHouse = buildHouse

function HouseService:Init(services)
	self.Services = services
	housesFolder = Instance.new("Folder")
	housesFolder.Name = "Houses"
	housesFolder.Parent = workspace
end

local function lots()
	return HouseService.Services.WorldService.Lots
end

function HouseService:Assign(player: Player): boolean
	for index in lots() do
		if not owners[index] then
			owners[index] = player
			lotOf[player] = index
			return true
		end
	end
	return false
end

function HouseService:GetLotCFrame(player: Player): CFrame?
	local index = lotOf[player]
	return index and lots()[index]
end

-- Einfahrt (zur Strasse ausgerichtet) fuer gespawnte Autos
function HouseService:GetDriveway(player: Player): CFrame?
	local cf = self:GetLotCFrame(player)
	return cf and cf * CFrame.new(-22, 0, -26)
end

function HouseService:Refresh(player: Player)
	local index = lotOf[player]
	local data = self.Services.DataService:Get(player)
	if not index or not data then
		return
	end
	if models[index] then
		models[index]:Destroy()
	end
	local cf = lots()[index]
	local tier = math.clamp(data.House, 1, #Config.Houses)
	if tier == #Config.Houses and not player:GetAttribute("Pass_Diamond") then
		tier = #Config.Houses - 1
	end
	local model = buildHouse(tier, cf, index)
	model.Name = player.Name .. "_House"
	-- Schild mit Name und Miete
	local post = Build.Box(model, cf * CFrame.new(20, 0, -34), Vector3.new(6, 5, 1), C.Lemon)
	Build.Billboard(post, `{player.DisplayName}'s {Config.Houses[tier].Name}`, C.Lemon, 14, 140)
	local rent = Build.Billboard(post, `Rent {Format.Cash(Config.Houses[tier].Rent)}/min`, C.Green, 10, 140)
	rent.Size = UDim2.fromScale(1, 0.7)
	local nextHouse = Config.Houses[tier + 1]
	if nextHouse then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = if nextHouse.Price then `Upgrade ({Format.Cash(nextHouse.Price)})` else "Upgrade (Robux)"
		prompt.ObjectText = nextHouse.Name
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Owner", player.UserId)
		prompt.Triggered:Connect(function(who)
			if who == player then
				local ok, message = self:Upgrade(player)
				if message then
					self.Services.Net.SendNotify(player, message, if ok then C.Green else C.Robber)
				end
			end
		end)
		prompt.Parent = post
	end
	model.Parent = housesFolder
	models[index] = model
end

function HouseService:GetTier(player: Player): number
	local data = self.Services.DataService:Get(player)
	if not data then
		return 1
	end
	local tier = math.clamp(data.House, 1, #Config.Houses)
	if tier == #Config.Houses and not player:GetAttribute("Pass_Diamond") then
		tier -= 1
	end
	return tier
end

function HouseService:Upgrade(player: Player): (boolean, string?)
	local data = self.Services.DataService:Get(player)
	if not data then
		return false, nil
	end
	local nextHouse = Config.Houses[data.House + 1]
	if not nextHouse then
		return false, "You already own the best house!"
	end
	if not nextHouse.Price then
		self.Services.MonetizationService:PromptPass(player, nextHouse.Pass)
		return false, nil
	end
	if not self.Services.DataService:Spend(player, nextHouse.Price) then
		self.Services.MonetizationService:OfferCash(player, nextHouse.Price - data.Cash)
		return false, `You need {Format.Cash(nextHouse.Price - data.Cash)} more!`
	end
	data.House += 1
	self.Services.DataService:UpdateAttributes(player)
	self:Refresh(player)
	self.Services.ProgressService:Check(player)
	if data.House >= 4 then
		self.Services.Net.SendAnnounce(`{player.DisplayName} moved into a {nextHouse.Name}!`, C.Lemon)
	end
	return true, `Welcome to your {nextHouse.Name}! Rent: {Format.Cash(nextHouse.Rent)}/min`
end

-- Diamond-Pass: direkt auf die hoechste Stufe
function HouseService:GrantDiamond(player: Player)
	local data = self.Services.DataService:Get(player)
	if data then
		data.House = #Config.Houses
		self.Services.DataService:UpdateAttributes(player)
		self:Refresh(player)
	end
end

function HouseService:OnPlayerReady(player: Player)
	self:Refresh(player)
	local data = self.Services.DataService:Get(player)
	-- Offline-Miete
	if data and data.LastOnline > 0 then
		local seconds = math.clamp(os.time() - data.LastOnline, 0, Config.OfflineMaxHours * 3600)
		local amount = math.floor(Config.Houses[self:GetTier(player)].Rent * seconds / 60 * Config.OfflineShare)
		if amount > 0 and seconds > 300 then
			self.Services.DataService:AddCash(player, amount)
			task.delay(6, function()
				if player.Parent then
					self.Services.Net.SendNotify(player, `Your house earned {Format.Cash(amount)} while you were away!`, C.Green)
				end
			end)
		end
	end
end

-- Buerger erscheinen vor dem eigenen Haus
function HouseService:OnCharacterAdded(player: Player, character: Model)
	if player.Team and player.Team.Name ~= "Citizens" then
		return
	end
	local cf = self:GetLotCFrame(player)
	if cf then
		task.defer(function()
			if character.Parent then
				character:PivotTo(cf * CFrame.new(-8, 4, -30) * CFrame.Angles(0, math.rad(180), 0))
			end
		end)
	end
end

function HouseService:Release(player: Player)
	local index = lotOf[player]
	if index then
		owners[index] = nil
		if models[index] then
			models[index]:Destroy()
			models[index] = nil
		end
	end
	lotOf[player] = nil
end

function HouseService:Start()
	self.Services.Net.Handle("UpgradeHouse", function(player)
		return self:Upgrade(player)
	end)
	self.Services.Net.Handle("GoHome", function(player)
		local cf = self:GetLotCFrame(player)
		local character = player.Character
		if not cf or not character or player:GetAttribute("JailUntil") then
			return false, "Can't go home right now"
		end
		if (player:GetAttribute("Wanted") or 0) > 0 then
			return false, "Not while you are wanted!"
		end
		-- Sonst koennte man mit der Beute einfach vor der Polizei wegteleportieren
		if (player:GetAttribute("Bag") or 0) > 0 then
			return false, "Not while carrying loot! Cash it in at the HIDEOUT."
		end
		self.Services.VehicleService:Eject(player)
		task.defer(function()
			character:PivotTo(cf * CFrame.new(-8, 4, -30) * CFrame.Angles(0, math.rad(180), 0))
		end)
		return true, "Home sweet home!"
	end)

	-- Gehaltsscheck jede Minute: Grundlohn + Miete (+ Polizei-Dienst)
	task.spawn(function()
		while true do
			task.wait(Config.PaycheckInterval)
			for _, player in Players:GetPlayers() do
				if lotOf[player] and not player:GetAttribute("JailUntil") and self.Services.DataService:Get(player) then
					local base = Config.BasePaycheck + Config.Houses[self:GetTier(player)].Rent
					if player.Team and player.Team.Name == "Police" then
						base += Config.PolicePaycheck
					end
					local amount = self.Services.DataService:Earn(player, base)
					self.Services.Net.SendNotify(player, `Paycheck +{Format.Cash(amount)}`, C.Green)
					self.Services.ProgressService:Check(player)
				end
			end
		end
	end)
end

return HouseService
