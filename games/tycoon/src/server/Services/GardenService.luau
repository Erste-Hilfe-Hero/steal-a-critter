-- Der Kern des Tycoons: Gaerten zuweisen, pflanzen, wachsen lassen (auch offline), ernten,
-- verkaufen, Felder und Upgrades kaufen, Rebirth, Tagesbelohnung und Freundes-Bonus.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local GardenService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)
local SOIL = Color3.fromRGB(110, 75, 45)
local GRASS = Color3.fromRGB(70, 140, 60)
local SELL_RANGE = 22

local playerPlots = {} -- [Player] = plot
local lastNotice = {} -- [Player] = os.clock() (gegen Meldungs-Spam)
local friendCache = {} -- ["a:b"] = boolean

function GardenService:Init(services)
	self.Services = services
end

local function notify(player: Player, text: string, color: Color3?)
	GardenService.Services.Net.SendNotify(player, text, color)
end

local function notifyThrottled(player: Player, text: string, color: Color3?)
	if os.clock() - (lastNotice[player] or 0) > 2 then
		lastNotice[player] = os.clock()
		notify(player, text, color)
	end
end

local function getData(player: Player)
	return GardenService.Services.DataService:Get(player)
end

local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

function GardenService:GetPlot(player: Player)
	return playerPlots[player]
end

function GardenService:MaxTiles(player: Player): number
	return Config.MaxTiles + (if hasPass(player, "BigGarden") then Config.BigGardenTiles else 0)
end

---------------------------------------------------------------- Multiplikatoren

function GardenService:GetSellMultiplier(player: Player): number
	local data = getData(player)
	if not data then
		return 1
	end
	local multiplier = 1 + data.Rebirths * Config.RebirthMultiplierPer
	multiplier *= 1 + (data.Upgrades.Fertilizer or 0) * 0.1
	if hasPass(player, "VIP") then
		multiplier *= Config.VipMultiplier
	end
	if hasPass(player, "DoubleSell") then
		multiplier *= Config.DoubleSellMultiplier
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		multiplier *= Config.PremiumMultiplier
	end
	multiplier *= 1 + (player:GetAttribute("Friends") or 0) * Config.FriendBonusPer
	return math.floor(multiplier * 100 + 0.5) / 100
end

-- Wachstum pro Sekunde; withWeather = false fuer die Offline-Zeit
function GardenService:GetGrowthRate(player: Player, withWeather: boolean): number
	local data = getData(player)
	local rate = 1 + (if data then data.Upgrades.Sprinkler or 0 else 0) * 0.1
	if hasPass(player, "FastGrow") then
		rate *= Config.FastGrowMultiplier
	end
	if withWeather then
		rate *= self.Services.EventService:GetGrowthBonus()
	end
	return rate
end

-- Durchschnittlicher Verdienst pro Sekunde (fuer die Muenzpakete)
function GardenService:GetEarnRate(player: Player): number
	local data = getData(player)
	if not data then
		return 0
	end
	return data.TotalEarned / math.max(600, data.PlayTime)
end

function GardenService:RefreshStats(player: Player)
	player:SetAttribute("SellMultiplier", self:GetSellMultiplier(player))
	player:SetAttribute("GrowthRate", self:GetGrowthRate(player, true))
	player:SetAttribute("MaxTiles", self:MaxTiles(player))
end

---------------------------------------------------------------- Pflanzen-Optik

local function stageOf(plant): number
	if plant.Grown >= plant.Need then
		return 4
	end
	return math.clamp(math.floor(plant.Grown / plant.Need * 4), 0, 3)
end

local function buildPlantModel(tile, seed, stage: number): Model
	local model = Instance.new("Model")
	model.Name = "Plant"
	local base = tile.Part.CFrame * CFrame.new(0, 0.3, 0)
	local grow = 0.35 + stage * 0.16
	local stemHeight = 1 + 3 * grow
	local makePart = GardenService.Services.WorldService.MakePart
	makePart({
		Name = "Stem",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(stemHeight, 0.5, 0.5),
		CFrame = base * CFrame.new(0, stemHeight / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 170, 60),
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	for _, angle in { 0, 120, 240 } do
		makePart({
			Name = "Leaf",
			Size = Vector3.new(2.2 * grow, 0.2, 1.1 * grow),
			CFrame = base * CFrame.new(0, stemHeight * 0.45, 0) * CFrame.Angles(0, math.rad(angle), math.rad(20)) * CFrame.new(1.1 * grow, 0, 0),
			Color = Color3.fromRGB(80, 200, 80),
			CanCollide = false,
			CanQuery = false,
			Parent = model,
		})
	end
	-- Die Frucht waechst mit und bekommt erst reif ihre volle Farbe
	local ripe = stage >= 4
	local fruitSize = (if ripe then 2.4 else 0.6 + stage * 0.35) * (1 + seed.Index * 0.04)
	local shape = if seed.Shape == "Block" then Enum.PartType.Block elseif seed.Shape == "Ball" then Enum.PartType.Ball else Enum.PartType.Cylinder
	local fruit = makePart({
		Name = "Fruit",
		Shape = shape,
		Size = if shape == Enum.PartType.Cylinder then Vector3.new(fruitSize * 1.3, fruitSize * 0.6, fruitSize * 0.6) else Vector3.one * fruitSize,
		CFrame = base * CFrame.new(0, stemHeight + fruitSize * 0.35, 0) * (if shape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.rad(90)) else CFrame.Angles(0, math.rad(45), 0)),
		Color = if ripe then seed.Color else seed.Color:Lerp(Color3.fromRGB(90, 190, 90), 0.6),
		Material = if ripe and seed.Index >= 9 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	if ripe then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = seed.Color
		sparkles.Parent = fruit
	end
	model.Parent = tile.Part
	return model
end

local function tileLabel(player: Player, data, index: number, plant): (string, Color3)
	if plant then
		local seed = Config.SeedsById[plant.Id]
		if plant.Grown >= plant.Need then
			return `{seed.Name}\nREADY!`, GREEN
		end
		local left = (plant.Need - plant.Grown) / GardenService:GetGrowthRate(player, true)
		return `{seed.Name}\n{Format.Time(left)}`, Color3.new(1, 1, 1)
	end
	if index == data.Tiles + 1 and index <= GardenService:MaxTiles(player) then
		return `🔒 {Format.Cash(Config.TileCost(data.Tiles))}\nUpgrades`, GOLD
	end
	if index == Config.MaxTiles + 1 and not hasPass(player, "BigGarden") then
		return "⭐ BIG GARDEN\n+12 tiles", Color3.fromRGB(255, 120, 255)
	end
	return "", Color3.new(1, 1, 1)
end

-- Aktualisiert ein Feld: Boden, Pflanzenmodell (nur bei neuer Stufe) und Beschriftung
function GardenService:RefreshTile(player: Player, index: number)
	local plot = playerPlots[player]
	local data = getData(player)
	if not plot or not data then
		return
	end
	local tile = plot.Tiles[index]
	local owned = index <= data.Tiles
	tile.Part.Color = if owned then SOIL else GRASS
	tile.Part.Material = if owned then Enum.Material.Ground else Enum.Material.Grass
	local plant = data.Plants[tostring(index)]
	local stage = if plant then stageOf(plant) else -1
	local plantId = if plant then plant.Id else nil
	if stage ~= tile.Stage or plantId ~= tile.PlantId then
		if tile.Model then
			tile.Model:Destroy()
			tile.Model = nil
		end
		if plant and Config.SeedsById[plant.Id] then
			tile.Model = buildPlantModel(tile, Config.SeedsById[plant.Id], stage)
		end
		tile.Stage = stage
		tile.PlantId = plantId
	end
	local text, color = tileLabel(player, data, index, plant)
	tile.Label.Text = text
	tile.Label.TextColor3 = color
end

function GardenService:RefreshAllTiles(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	for index in plot.Tiles do
		self:RefreshTile(player, index)
	end
end

local function clearPlot(plot)
	for _, tile in plot.Tiles do
		if tile.Model then
			tile.Model:Destroy()
			tile.Model = nil
		end
		tile.Stage = -1
		tile.PlantId = nil
		tile.Label.Text = ""
		tile.Part.Color = GRASS
		tile.Part.Material = Enum.Material.Grass
	end
end

---------------------------------------------------------------- Garten zuweisen

function GardenService:Assign(player: Player)
	for _, plot in self.Services.WorldService.Plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.SignLabel.Text = player.DisplayName .. "'s Garden"
			playerPlots[player] = plot
			return plot
		end
	end
	return nil
end

function GardenService:Release(player: Player)
	local plot = playerPlots[player]
	playerPlots[player] = nil
	lastNotice[player] = nil
	if plot then
		plot.Owner = nil
		plot.SignLabel.Text = "Free Garden"
		clearPlot(plot)
	end
end

function GardenService:TeleportTo(player: Player, where: string)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plot = playerPlots[player]
	local world = self.Services.WorldService
	local target = if where == "Garden" and plot then plot.SpawnCFrame elseif where == "Shop" then world.ShopCFrame elseif where == "Sell" then world.SellCFrame else nil
	if root and target then
		root.CFrame = target
	end
end

function GardenService:OnCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local plot = playerPlots[player]
	if root and plot then
		task.wait()
		root.CFrame = plot.SpawnCFrame
	end
end

---------------------------------------------------------------- Pflanzen und Ernten

local function rollMutation()
	local events = GardenService.Services.EventService
	local weather = events:GetWeather()
	for _, mutation in Config.Mutations do
		local needs = mutation.Weather
		local allowed = needs == nil or needs == weather or (type(needs) == "table" and table.find(needs, weather) ~= nil)
		local chance = mutation.Chance
		if mutation.Name == "Golden" then
			chance *= events:GetGoldenMultiplier()
		end
		if allowed and math.random() < chance then
			return mutation
		end
	end
	return nil
end

function GardenService:Harvest(player: Player, index: number, silent: boolean?): boolean
	local data = getData(player)
	local key = tostring(index)
	local plant = data and data.Plants[key]
	if not plant or plant.Grown < plant.Need then
		return false
	end
	if #data.Fruits >= Config.BackpackSize then
		if not silent then
			notifyThrottled(player, "Your backpack is full! Sell your fruits at the SELL stand.", RED)
		end
		return false
	end
	local seed = Config.SeedsById[plant.Id]
	local mutation = rollMutation()
	local weight = 0.8 + math.random() * 0.7
	local value = math.floor(seed.Value * weight * (if mutation then mutation.Multiplier else 1))
	table.insert(data.Fruits, { Id = seed.Id, Value = value, Mutation = if mutation then mutation.Name else nil })
	local plot = playerPlots[player]
	if plot and plot.Tiles[index] then
		local label = (if mutation then mutation.Name .. " " else "") .. seed.Name
		self.Services.Net.Effect:FireClient(player, "Harvest", plot.Tiles[index].Part.Position, label, if mutation then mutation.Color else seed.Color)
	end
	if seed.Regrow then
		plant.Grown = 0
		plant.Need = seed.Regrow
	else
		data.Plants[key] = nil
	end
	if mutation and mutation.Multiplier >= 20 then
		self.Services.Net.SendAnnounce(`{player.DisplayName} harvested a {mutation.Name:upper()} {seed.Name}!`, mutation.Color)
	elseif mutation then
		notify(player, `{mutation.Name} {seed.Name}! x{mutation.Multiplier}`, mutation.Color)
	end
	self.Services.DataService:UpdateAttributes(player)
	self:RefreshTile(player, index)
	return true
end

function GardenService:Plant(player: Player, index: number, seedId: string): boolean
	local data = getData(player)
	local seed = Config.SeedsById[seedId]
	if not data or not seed or (data.Seeds[seedId] or 0) <= 0 then
		return false
	end
	data.Seeds[seedId] -= 1
	if data.Seeds[seedId] <= 0 then
		data.Seeds[seedId] = nil
	end
	data.Plants[tostring(index)] = { Id = seedId, Grown = 0, Need = seed.Grow }
	self.Services.DataService:UpdateAttributes(player)
	self:RefreshTile(player, index)
	return true
end

local function onTileClicked(player: Player, plot, index: number)
	if plot.Owner ~= player then
		return
	end
	local data = getData(player)
	if not data then
		return
	end
	if index > data.Tiles then
		if index > GardenService:MaxTiles(player) then
			GardenService.Services.MonetizationService:PromptPass(player, "BigGarden")
		else
			notifyThrottled(player, `Buy more tiles in UPGRADES (next: {Format.Cash(Config.TileCost(data.Tiles))}).`, GOLD)
		end
		return
	end
	local plant = data.Plants[tostring(index)]
	if plant then
		if plant.Grown >= plant.Need then
			GardenService:Harvest(player, index)
		end
		return
	end
	local selected = player:GetAttribute("SelectedSeed")
	if type(selected) ~= "string" or (data.Seeds[selected] or 0) <= 0 then
		-- Wertvollster vorhandener Samen, damit neue Spieler sofort pflanzen koennen
		selected = nil
		for _, seed in Config.Seeds do
			if (data.Seeds[seed.Id] or 0) > 0 then
				selected = seed.Id
			end
		end
		if not selected then
			notifyThrottled(player, "No seeds! Buy some at the SEEDS shop.", RED)
			return
		end
		player:SetAttribute("SelectedSeed", selected)
	end
	GardenService:Plant(player, index, selected :: string)
end

function GardenService:GrowAll(player: Player): boolean
	local data = getData(player)
	if not data then
		return false
	end
	for _, plant in data.Plants do
		plant.Grown = plant.Need
	end
	self:RefreshAllTiles(player)
	return true
end

---------------------------------------------------------------- Verkaufen

function GardenService:SellAll(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	if #data.Fruits == 0 then
		notifyThrottled(player, "You have no fruits to sell. Harvest ripe plants first!", RED)
		return
	end
	local total = 0
	for _, fruit in data.Fruits do
		total += fruit.Value
	end
	local count = #data.Fruits
	total = math.floor(total * self:GetSellMultiplier(player))
	data.Fruits = {}
	self.Services.DataService:AddCoins(player, total)
	notify(player, `Sold {count} fruits for {Format.Cash(total)}!`, GREEN)
	self.Services.Net.Effect:FireClient(player, "Sell", nil, "+" .. Format.Cash(total), GOLD)
end

local function isNearSell(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = GardenService.Services.WorldService.SellCFrame
	return root ~= nil and (root.Position - target.Position).Magnitude < SELL_RANGE
end

---------------------------------------------------------------- Upgrades und Rebirth

function GardenService:BuyUpgrade(player: Player, kind: string)
	local data = getData(player)
	if not data then
		return
	end
	local dataService = self.Services.DataService
	if kind == "Tile" then
		if data.Tiles >= self:MaxTiles(player) then
			if not hasPass(player, "BigGarden") then
				self.Services.MonetizationService:PromptPass(player, "BigGarden")
			else
				notify(player, "Your garden is already at max size!", GOLD)
			end
			return
		end
		local cost = Config.TileCost(data.Tiles)
		if data.Coins < cost then
			notify(player, `You need {Format.Cash(cost)} for a new tile.`, RED)
			return
		end
		dataService:AddCoins(player, -cost)
		data.Tiles += 1
		notify(player, "New garden tile unlocked!", GREEN)
		self:RefreshAllTiles(player)
	elseif Config.Upgrades[kind] then
		local level = data.Upgrades[kind] or 0
		if level >= Config.MaxUpgradeLevel then
			notify(player, "Already max level!", GOLD)
			return
		end
		local cost = Config.UpgradeCost(kind, level)
		if data.Coins < cost then
			notify(player, `You need {Format.Cash(cost)}.`, RED)
			return
		end
		dataService:AddCoins(player, -cost)
		data.Upgrades[kind] = level + 1
		notify(player, `{Config.Upgrades[kind].Name} is now level {level + 1}!`, GREEN)
	else
		return
	end
	dataService:UpdateAttributes(player)
	self:RefreshStats(player)
end

function GardenService:Rebirth(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Coins < cost then
		notify(player, `You need {Format.Cash(cost)} to rebirth.`, RED)
		return
	end
	data.Rebirths += 1
	data.Coins = Config.StartCoins
	data.Seeds = table.clone(Config.StartSeeds)
	data.Plants = {}
	data.Fruits = {}
	data.Tiles = Config.StartTiles
	data.Upgrades = { Sprinkler = 0, Fertilizer = 0 }
	player:SetAttribute("SelectedSeed", nil)
	self.Services.DataService:UpdateAttributes(player)
	self:RefreshStats(player)
	self:RefreshAllTiles(player)
	self.Services.Net.SendAnnounce(`{player.DisplayName} rebirthed! Now x{self:GetSellMultiplier(player)} fruit value.`, GOLD)
end

---------------------------------------------------------------- Beitreten und Verlassen

local function today(): number
	return os.time() // 86400
end

local function giveDaily(player: Player, data)
	local day = today()
	if data.DailyDay == day then
		return
	end
	data.DailyStreak = if data.DailyDay == day - 1 then data.DailyStreak % 7 + 1 else 1
	data.DailyDay = day
	local reward = Config.DailyReward(data.DailyStreak, data.Rebirths)
	GardenService.Services.DataService:AddCoins(player, reward)
	task.delay(4, notify, player, `Daily reward day {data.DailyStreak}/7: +{Format.Cash(reward)}! Come back tomorrow for more.`, GOLD)
end

local function friendKey(a: Player, b: Player): string
	return if a.UserId < b.UserId then `{a.UserId}:{b.UserId}` else `{b.UserId}:{a.UserId}`
end

local function updateFriends()
	for _, player in Players:GetPlayers() do
		local count = 0
		for _, other in Players:GetPlayers() do
			if other ~= player and friendCache[friendKey(player, other)] then
				count += 1
			end
		end
		player:SetAttribute("Friends", math.min(count, Config.MaxFriendBonus))
		GardenService:RefreshStats(player)
	end
end

function GardenService:OnPlayerReady(player: Player)
	local data = getData(player)
	if not data then
		return
	end
	-- Offline gewachsen (ohne Wetterbonus)
	if data.LastTick and data.LastTick > 0 then
		local offline = math.max(0, os.time() - data.LastTick)
		local rate = self:GetGrowthRate(player, false)
		for _, plant in data.Plants do
			plant.Grown = math.min(plant.Need, plant.Grown + offline * rate)
		end
		if offline > 120 and next(data.Plants) then
			task.delay(3, notify, player, "Your plants kept growing while you were away!", GREEN)
		end
	end
	data.LastTick = os.time()
	if data.TotalEarned == 0 then
		task.delay(2, notify, player, "Tap the brown soil in your garden to plant. Harvest ripe plants and SELL them!", GOLD)
	end
	giveDaily(player, data)
	self:RefreshStats(player)
	self:RefreshAllTiles(player)

	task.spawn(function()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, isFriend = pcall(player.IsFriendsWithAsync, player, other.UserId)
				friendCache[friendKey(player, other)] = ok and isFriend
			end
		end
		updateFriends()
		for _, other in Players:GetPlayers() do
			if other ~= player and friendCache[friendKey(player, other)] then
				notify(other, `Your friend {player.DisplayName} joined: +{math.floor(Config.FriendBonusPer * 100)}% fruit value!`, GREEN)
			end
		end
	end)
end

function GardenService:OnPlayerRemoving(player: Player)
	local data = getData(player)
	if data then
		data.LastTick = os.time()
	end
	for key in friendCache do
		if key:find(tostring(player.UserId), 1, true) then
			friendCache[key] = nil
		end
	end
	task.defer(updateFriends)
end

---------------------------------------------------------------- Start

function GardenService:Start()
	local net = self.Services.Net

	for _, plot in self.Services.WorldService.Plots do
		for index, tile in plot.Tiles do
			tile.Click.MouseClick:Connect(function(player)
				onTileClicked(player, plot, index)
			end)
		end
	end

	self.Services.WorldService.SellPrompt.Triggered:Connect(function(player)
		self:SellAll(player)
	end)

	net.SellAll.OnServerEvent:Connect(function(player)
		if isNearSell(player) then
			self:SellAll(player)
		else
			self:TeleportTo(player, "Sell")
		end
	end)

	net.SelectSeed.OnServerEvent:Connect(function(player, seedId)
		if seedId == nil or (type(seedId) == "string" and Config.SeedsById[seedId]) then
			player:SetAttribute("SelectedSeed", seedId)
		end
	end)

	net.BuyUpgrade.OnServerEvent:Connect(function(player, kind)
		if type(kind) == "string" then
			self:BuyUpgrade(player, kind)
		end
	end)

	net.RequestRebirth.OnServerEvent:Connect(function(player)
		self:Rebirth(player)
	end)

	net.Teleport.OnServerEvent:Connect(function(player, where)
		if type(where) == "string" then
			self:TeleportTo(player, where)
		end
	end)

	Players.PlayerMembershipChanged:Connect(function(player)
		self:RefreshStats(player)
	end)

	-- Jede Sekunde: wachsen lassen, Beschriftungen aktualisieren, Auto-Ernte
	task.spawn(function()
		while true do
			task.wait(1)
			for player, plot in playerPlots do
				local data = getData(player)
				if not data then
					continue
				end
				data.LastTick = os.time()
				local rate = self:GetGrowthRate(player, true)
				player:SetAttribute("GrowthRate", rate)
				local autoHarvest = hasPass(player, "AutoHarvest")
				for key, plant in data.Plants do
					local index = tonumber(key) :: number
					if plant.Grown < plant.Need then
						plant.Grown = math.min(plant.Need, plant.Grown + rate)
					end
					if autoHarvest and plant.Grown >= plant.Need and plot.Tiles[index] then
						self:Harvest(player, index, true)
					end
					if plot.Tiles[index] then
						self:RefreshTile(player, index)
					end
				end
			end
		end
	end)
end

return GardenService
