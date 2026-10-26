-- Computer-Gaertner: solange wenige echte Spieler da sind, bewirtschaften NPC-Rivalen freie Gaerten.
-- Sie pflanzen, ernten, kaufen Samen und verkaufen am Stand; ihr Verdienst steht am Schild, damit es
-- etwas zum Ueberholen gibt. Kommt ein echter Spieler und alles ist belegt, raeumt ein Rivale seinen Garten.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local NpcBody = require(script.Parent.NpcBody)

local RivalService = { Services = nil :: any, Rivals = {} :: { any } }

local R = Config.Rivals
local SOIL = Color3.fromRGB(110, 75, 45)
local GRASS = Color3.fromRGB(70, 140, 60)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)
local RIVAL = Color3.fromRGB(255, 120, 90)

local folder: Folder
local usedNames = {} -- [Name] = true
local lastAnnounce = -math.huge
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function RivalService:Init(services)
	self.Services = services
end

local function rand(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

local function humans(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if RivalService.Services.DataService:Get(player) then
			table.insert(list, player)
		end
	end
	return list
end

-- Wie weit die echten Spieler sind (bester Samen, den sie sich leisten koennen) und wie schnell sie verdienen
local function humanLevel(): (number, number)
	local best, rate = 2, 0
	local list = humans()
	for _, player in list do
		local data = RivalService.Services.DataService:Get(player)
		local wealth = math.max(data.Coins or 0, (data.TotalEarned or 0) * 0.25)
		for _, seed in Config.Seeds do
			if seed.Price <= wealth then
				best = math.max(best, seed.Index)
			end
		end
		rate = math.max(rate, RivalService.Services.GardenService:GetEarnRate(player))
	end
	return best, rate
end

---------------------------------------------------------------- Laufen

local function groundY(position: Vector3): number
	local hit = workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), rayParams)
	return if hit then hit.Position.Y else 0
end

local function walkTo(rival, points: { Vector3 }, after: (() -> ())?)
	rival.Route = points
	rival.RouteIndex = 1
	rival.After = after
	rival.Phase = "Walk"
	NpcBody.Play(rival.Model, "Walk")
end

local function pause(rival, seconds: number, after: (() -> ())?)
	rival.Phase = "Wait"
	rival.Timer = seconds
	rival.After = after
	NpcBody.Play(rival.Model, "Idle")
end

local function tileWorld(rival, index: number): Vector3
	local tile = rival.Plot.Tiles[index].Part
	-- vor dem Feld stehen (Richtung Eingang), nicht mitten in der Pflanze
	return (tile.CFrame * CFrame.new(0, 0, -4)).Position
end

---------------------------------------------------------------- Pflanzen

local function refreshTile(rival, index: number)
	local tile = rival.Plot.Tiles[index]
	local plant = rival.Plants[index]
	tile.Part.Color = if index <= rival.TileCount then SOIL else GRASS
	tile.Part.Material = if index <= rival.TileCount then Enum.Material.Ground else Enum.Material.Grass
	local stage = -1
	if plant then
		stage = if plant.Grown >= plant.Need then 4 else math.clamp(math.floor(plant.Grown / plant.Need * 4), 0, 3)
	end
	local plantId = plant and plant.Id
	if stage ~= tile.Stage or plantId ~= tile.PlantId then
		if tile.Model then
			tile.Model:Destroy()
			tile.Model = nil
		end
		if plant then
			tile.Model = RivalService.Services.GardenService.BuildPlantModel(tile, Config.SeedsById[plant.Id], stage)
		end
		tile.Stage = stage
		tile.PlantId = plantId
	end
	if plant then
		local seed = Config.SeedsById[plant.Id]
		tile.Label.Text = if stage >= 4 then `{seed.Name}\nREADY!` else `{seed.Name}\n{Format.Time(plant.Need - plant.Grown)}`
		tile.Label.TextColor3 = if stage >= 4 then GREEN else Color3.new(1, 1, 1)
	else
		tile.Label.Text = ""
	end
end

local function updateSign(rival)
	rival.Plot.SignLabel.Text = `🤖 {rival.Name}'s Garden\n💰 {Format.Cash(rival.Earned)}`
	rival.Info.Text = `💰 {Format.Cash(rival.Earned)} earned`
end

local function pickSeed(rival): any
	local level = math.clamp(rival.Level + math.random(-2, 0), 1, #Config.Seeds)
	return Config.Seeds[level]
end

local function plant(rival, index: number)
	local seed = pickSeed(rival)
	rival.Plants[index] = { Id = seed.Id, Grown = 0, Need = seed.Grow * R.GrowFactor }
	refreshTile(rival, index)
end

local function harvest(rival, index: number)
	local plantData = rival.Plants[index]
	if not plantData then
		return
	end
	local seed = Config.SeedsById[plantData.Id]
	-- Mutationen wie bei Spielern (seltener angesagt)
	local roll = math.random()
	local mutation, factor = nil, 1
	if roll < 0.004 then
		mutation, factor = "RAINBOW", 50
	elseif roll < 0.02 then
		mutation, factor = "GOLDEN", 20
	elseif roll < 0.08 then
		mutation, factor = "Wet", 2
	end
	local value = seed.Value * factor * rival.ValueFactor
	table.insert(rival.Fruits, value)
	if mutation and factor >= 20 and os.clock() - lastAnnounce > R.AnnounceCooldown and #humans() > 0 then
		lastAnnounce = os.clock()
		RivalService.Services.Net.SendAnnounce(`🤖 {rival.Name} harvested a {mutation} {seed.Name}!`, GOLD)
	end
	if mutation then
		NpcBody.Say(rival.Model, `{mutation} {seed.Name}!`, 2.5)
	end
	if seed.Regrow then
		plantData.Grown = math.max(0, plantData.Need - seed.Regrow * R.GrowFactor)
	else
		rival.Plants[index] = nil
	end
	refreshTile(rival, index)
end

---------------------------------------------------------------- Entscheidungen

local SAYINGS = {
	Sell = { "Cha-ching!", "Money money!", "Beat that!", "Sold it all!" },
	Seeds = { "Ooh, new seeds!", "What's in stock?", "I'll take those!" },
	Taunt = { "My garden is bigger!", "Catch me if you can!", "I'm the best gardener!", "Nice garden!" },
}

local decide

local function sellTrip(rival)
	local plot = rival.Plot
	local side = if plot.CFrame.Position.Z > 0 then 1 else -1
	local inside = (plot.CFrame * CFrame.new(0, 0, -29 + 4)).Position
	local outside = (plot.CFrame * CFrame.new(0, 0, -29 - 6)).Position
	local shop = Vector3.new(-22, 0, side * 8)
	local sell = Vector3.new(22, 0, side * 8)
	local function back()
		walkTo(rival, { Vector3.new(outside.X, 0, side * 12), outside, inside }, function()
			decide(rival)
		end)
	end
	local function atSell()
		local total = 0
		for _, value in rival.Fruits do
			total += value
		end
		rival.Fruits = {}
		rival.Earned += math.floor(total)
		updateSign(rival)
		NpcBody.Say(rival.Model, SAYINGS.Sell[math.random(1, #SAYINGS.Sell)] .. ` +{Format.Cash(total)}`, 3)
		pause(rival, 1.5, back)
	end
	local function atShop()
		NpcBody.Say(rival.Model, SAYINGS.Seeds[math.random(1, #SAYINGS.Seeds)], 2.5)
		pause(rival, 1.5, function()
			walkTo(rival, { sell }, atSell)
		end)
	end
	if math.random() < 0.5 then
		walkTo(rival, { inside, outside, Vector3.new(outside.X, 0, side * 12), shop }, atShop)
	else
		walkTo(rival, { inside, outside, Vector3.new(outside.X, 0, side * 12), sell }, atSell)
	end
end

decide = function(rival)
	if not rival.Model.Parent then
		return
	end
	if #rival.Fruits >= rival.SellAt then
		sellTrip(rival)
		return
	end
	-- Naechstgelegenes reifes oder leeres Feld
	local here = rival.Root.Position
	local best, bestDistance, bestAction = nil, math.huge, nil
	for index = 1, rival.TileCount do
		local plantData = rival.Plants[index]
		local action = if not plantData then "Plant" elseif plantData.Grown >= plantData.Need then "Harvest" else nil
		if action then
			local distance = (tileWorld(rival, index) - here).Magnitude + (if action == "Harvest" then 0 else 6)
			if distance < bestDistance then
				best, bestDistance, bestAction = index, distance, action
			end
		end
	end
	if best then
		walkTo(rival, { tileWorld(rival, best) }, function()
			NpcBody.Play(rival.Model, "Idle")
			pause(rival, rand(R.WorkTime), function()
				if bestAction == "Harvest" then
					harvest(rival, best)
				else
					plant(rival, best)
				end
				decide(rival)
			end)
		end)
		return
	end
	-- Nichts zu tun: herumschlendern, ab und zu etwas sagen
	if math.random() < 0.15 then
		NpcBody.Say(rival.Model, SAYINGS.Taunt[math.random(1, #SAYINGS.Taunt)], 3)
	end
	local spot = (rival.Plot.CFrame * CFrame.new(math.random(-20, 20), 0, math.random(-22, 22))).Position
	walkTo(rival, { spot }, function()
		pause(rival, rand(R.IdleTime), function()
			decide(rival)
		end)
	end)
end

local function update(rival, dt: number)
	if rival.Phase == "Wait" then
		rival.Timer -= dt
		if rival.Timer <= 0 then
			rival.Phase = "Busy"
			local after = rival.After
			rival.After = nil
			if after then
				after()
			end
		end
	elseif rival.Phase == "Walk" then
		local target = rival.Route[rival.RouteIndex]
		local position = rival.Root.Position
		local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
		local step = R.WalkSpeed * dt
		local nextPosition
		if flat.Magnitude <= step then
			nextPosition = Vector3.new(target.X, 0, target.Z)
			rival.RouteIndex += 1
		else
			nextPosition = Vector3.new(position.X, 0, position.Z) + flat.Unit * step
		end
		local y = groundY(nextPosition) + rival.Height
		local look = if flat.Magnitude > 0.05 then flat.Unit else rival.Root.CFrame.LookVector
		local final = Vector3.new(nextPosition.X, y, nextPosition.Z)
		rival.Root.CFrame = CFrame.lookAt(final, final + Vector3.new(look.X, 0, look.Z))
		if rival.RouteIndex > #rival.Route then
			rival.Phase = "Busy"
			local after = rival.After
			rival.After = nil
			if after then
				after()
			end
		end
	end
end

---------------------------------------------------------------- Rivalen anlegen/entfernen

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

local function clearTiles(plot)
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

function RivalService:Spawn(): any?
	local plot = nil
	local free = 0
	for _, candidate in self.Services.WorldService.Plots do
		if candidate.Owner == nil and not candidate.Rival then
			free += 1
			plot = plot or candidate
		end
	end
	-- Immer mindestens einen Garten fuer neue Spieler frei lassen
	if not plot or free <= R.KeepFree then
		return nil
	end
	local name = pickName()
	local model, _, root = NpcBody.Build(name, { Tag = "Rival", Hat = Color3.fromRGB(120, 200, 70) })
	local _, nameLabel, info = NpcBody.Tag(model, "RIVAL GARDENER", RIVAL, 120)
	nameLabel.TextColor3 = Color3.fromRGB(220, 255, 200)
	local level, rate = humanLevel()
	local rival = {
		Name = name,
		Model = model,
		Root = root,
		Info = info,
		Plot = plot,
		Height = NpcBody.RootHeight(model),
		Level = math.clamp(level + math.random(-1, 1), 1, #Config.Seeds),
		TileCount = math.random(R.Tiles[1], R.Tiles[2]),
		ValueFactor = rand(R.ValueFactor),
		SellAt = math.random(R.SellAt[1], R.SellAt[2]),
		Plants = {},
		Fruits = {},
		-- Startet mit einem Verdienst in der Naehe der Spieler, damit es ein Rennen gibt
		Earned = math.floor(rate * rand(R.StartMinutes) * 60),
		Phase = "Busy",
		Timer = 0,
		Route = {},
		RouteIndex = 1,
		After = nil :: (() -> ())?,
	}
	plot.Rival = rival
	plot.SignLabel.Text = ""
	-- Ein paar Pflanzen wachsen schon
	for index = 1, rival.TileCount do
		if math.random() < 0.7 then
			local seed = pickSeed(rival)
			local need = seed.Grow * R.GrowFactor
			rival.Plants[index] = { Id = seed.Id, Grown = math.random() * need, Need = need }
		end
		refreshTile(rival, index)
	end
	model.Parent = folder
	local start = plot.SpawnCFrame.Position
	root.CFrame = CFrame.new(start.X, groundY(start) + rival.Height, start.Z)
	NpcBody.Poof(root.Position)
	updateSign(rival)
	table.insert(self.Rivals, rival)
	decide(rival)
	return rival
end

function RivalService:Remove(rival)
	local index = table.find(self.Rivals, rival)
	if index then
		table.remove(self.Rivals, index)
	end
	usedNames[rival.Name] = nil
	if rival.Model.Parent then
		NpcBody.Poof(rival.Root.Position)
		rival.Model:Destroy()
	end
	local plot = rival.Plot
	if plot.Rival == rival then
		plot.Rival = nil
		clearTiles(plot)
		if plot.Owner == nil then
			plot.SignLabel.Text = "Free Garden"
		end
	end
end

-- Fuer einen echten Spieler Platz machen (liefert den frei gewordenen Garten)
function RivalService:FreePlot(): any?
	local rival = self.Rivals[#self.Rivals]
	if not rival then
		return nil
	end
	local plot = rival.Plot
	self:Remove(rival)
	return plot
end

function RivalService:Wanted(): number
	return math.clamp(R.FillUntilPlayers - #Players:GetPlayers(), 0, R.Max)
end

function RivalService:Balance()
	local wanted = self:Wanted()
	while #self.Rivals > wanted do
		self:Remove(self.Rivals[#self.Rivals])
	end
	if #self.Rivals < wanted then
		self:Spawn()
	end
end

function RivalService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Rivals"
	folder.Parent = workspace
	rayParams.FilterDescendantsInstances = { folder }

	RunService.Heartbeat:Connect(function(dt)
		for _, rival in self.Rivals do
			local ok, err = pcall(update, rival, math.min(dt, 0.1))
			if not ok then
				warn("Rival update failed:", err)
				rival.Phase = "Busy"
				task.defer(decide, rival)
			end
		end
	end)

	-- Wachsen lassen (jede Sekunde)
	task.spawn(function()
		while true do
			task.wait(1)
			for _, rival in self.Rivals do
				for index, plantData in rival.Plants do
					if plantData.Grown < plantData.Need then
						plantData.Grown = math.min(plantData.Need, plantData.Grown + 1)
					end
					refreshTile(rival, index)
				end
			end
		end
	end)

	-- Stufe alle paar Minuten an die Spieler anpassen
	task.spawn(function()
		while true do
			task.wait(90)
			local level = humanLevel()
			for _, rival in self.Rivals do
				rival.Level = math.clamp(level + math.random(-1, 1), 1, #Config.Seeds)
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
			task.wait(R.SpawnInterval)
		end
	end)
end

return RivalService
