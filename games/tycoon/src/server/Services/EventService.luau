-- Samenladen (Auffuellen alle 5 Minuten, in allen Servern gleich) und Wetter / Golden Hour.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local EventService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)

local currentRestock = -1
local stock = {} -- [SeedId] = Anzahl im aktuellen Angebot
local bought = {} -- [Player] = { [SeedId] = gekauft in diesem Angebot }
local weather = "Clear"
local weatherUntil = 0
local goldenUntil = 0

function EventService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Samenladen

-- Das Angebot haengt nur von der Uhrzeit ab: alle Server zeigen dasselbe ("Mythic im Laden!" spricht sich herum)
local function rollStock(restockIndex: number)
	local rng = Random.new(restockIndex * 7919 + 1337)
	local result = {}
	for _, seed in Config.Seeds do
		if rng:NextNumber() < seed.Chance then
			result[seed.Id] = rng:NextInteger(seed.Min, seed.Max)
		end
	end
	return result
end

local function updatePlayerStock(player: Player)
	local mine = bought[player] or {}
	for _, seed in Config.Seeds do
		local left = (stock[seed.Id] or 0) - (mine[seed.Id] or 0)
		player:SetAttribute("Stock_" .. seed.Id, math.max(0, left))
	end
end

local function restock(index: number)
	currentRestock = index
	stock = rollStock(index)
	bought = {}
	workspace:SetAttribute("NextRestock", (index + 1) * Config.RestockInterval)
	for _, player in Players:GetPlayers() do
		updatePlayerStock(player)
	end
	local rare = {}
	for _, seed in Config.Seeds do
		if stock[seed.Id] and Config.RaritiesByName[seed.Rarity].Announce then
			table.insert(rare, seed.Name)
		end
	end
	if #rare > 0 then
		EventService.Services.Net.SendAnnounce(`SEED SHOP RESTOCKED: {table.concat(rare, ", ")} in stock!`, GOLD)
	else
		EventService.Services.Net.SendAnnounce("The Seed Shop has restocked!", GREEN)
	end
end

function EventService:BuySeed(player: Player, seedId: string)
	local seed = Config.SeedsById[seedId]
	local data = self.Services.DataService:Get(player)
	if not seed or not data then
		return
	end
	local mine = bought[player] or {}
	bought[player] = mine
	if (stock[seedId] or 0) - (mine[seedId] or 0) <= 0 then
		self.Services.Net.SendNotify(player, `{seed.Name} is sold out. Next restock soon!`, RED)
		return
	end
	if data.Coins < seed.Price then
		self.Services.Net.SendNotify(player, `You need {Format.Cash(seed.Price)} for a {seed.Name} seed.`, RED)
		return
	end
	mine[seedId] = (mine[seedId] or 0) + 1
	data.Seeds[seedId] = (data.Seeds[seedId] or 0) + 1
	self.Services.DataService:AddCoins(player, -seed.Price)
	player:SetAttribute("SelectedSeed", seedId)
	updatePlayerStock(player)
	if Config.RaritiesByName[seed.Rarity].Announce then
		self.Services.Net.SendAnnounce(`{player.DisplayName} bought a {seed.Rarity} {seed.Name} seed!`, Config.RaritiesByName[seed.Rarity].Color)
	end
end

---------------------------------------------------------------- Wetter

function EventService:GetWeather(): string
	return if workspace:GetServerTimeNow() < weatherUntil then weather else "Clear"
end

function EventService:GetGrowthBonus(): number
	local current = Config.Weather[self:GetWeather()]
	return if current then current.GrowthBonus else 1
end

function EventService:GetGoldenMultiplier(): number
	return if workspace:GetServerTimeNow() < goldenUntil then Config.GoldenHourMultiplier else 1
end

local function applyWeatherVisuals()
	local current = EventService:GetWeather()
	local world = EventService.Services.WorldService
	world.RainEmitter.Enabled = current ~= "Clear"
	world.RainEmitter.Rate = if current == "Thunderstorm" then 1200 else 600
	Lighting.Brightness = if current == "Clear" then 2.5 elseif current == "Rain" then 1.4 else 0.8
	Lighting.OutdoorAmbient = if current == "Clear" then Color3.fromRGB(150, 150, 150) else Color3.fromRGB(90, 95, 120)
	workspace:SetAttribute("Weather", current)
	workspace:SetAttribute("WeatherUntil", weatherUntil)
end

-- byPlayer: gekauft (wird verlaengert und gross angesagt = Werbung fuer das Produkt)
function EventService:StartWeather(name: string, byPlayer: Player?)
	local def = Config.Weather[name]
	if not def then
		return
	end
	local now = workspace:GetServerTimeNow()
	if self:GetWeather() == name then
		weatherUntil += def.Duration
	else
		weather = name
		weatherUntil = now + def.Duration
	end
	applyWeatherVisuals()
	local text = if name == "Rain" then "It's RAINING! Plants grow faster and fruits can turn Wet (x2)!" else "THUNDERSTORM! Fruits can get Shocked (x10)!"
	if byPlayer then
		text = `{byPlayer.DisplayName} summoned {name:upper()}! ` .. text
	end
	self.Services.Net.SendAnnounce(text, Color3.fromRGB(120, 180, 255))
end

function EventService:StartGoldenHour(seconds: number, byPlayer: Player)
	local now = workspace:GetServerTimeNow()
	goldenUntil = math.max(now, goldenUntil) + seconds
	workspace:SetAttribute("GoldenUntil", goldenUntil)
	self.Services.Net.SendAnnounce(`{byPlayer.DisplayName} started GOLDEN HOUR: 10x Golden fruits for everyone!`, GOLD)
end

---------------------------------------------------------------- Lebenszyklus

function EventService:OnPlayerReady(player: Player)
	updatePlayerStock(player)
end

function EventService:OnPlayerRemoving(player: Player)
	bought[player] = nil
end

function EventService:Start()
	self.Services.Net.BuySeed.OnServerEvent:Connect(function(player, seedId)
		if type(seedId) == "string" then
			self:BuySeed(player, seedId)
		end
	end)

	restock(math.floor(workspace:GetServerTimeNow() / Config.RestockInterval))
	applyWeatherVisuals()

	task.spawn(function()
		local nextWeather = os.clock() + math.random(Config.WeatherInterval[1], Config.WeatherInterval[2])
		local wasWeather = "Clear"
		local lightningAt = 0
		while true do
			task.wait(1)
			local index = math.floor(workspace:GetServerTimeNow() / Config.RestockInterval)
			if index ~= currentRestock then
				restock(index)
			end
			local timeLeft = (index + 1) * Config.RestockInterval - workspace:GetServerTimeNow()
			self.Services.WorldService.RestockLabel.Text = `Restock in {Format.Time(timeLeft)}`

			local current = self:GetWeather()
			if current ~= wasWeather then
				wasWeather = current
				applyWeatherVisuals()
				if current == "Clear" then
					self.Services.Net.SendAnnounce("The weather cleared up.", Color3.fromRGB(220, 220, 220))
				end
			end
			-- Blitze waehrend des Gewitters
			if current == "Thunderstorm" and os.clock() > lightningAt then
				lightningAt = os.clock() + math.random(4, 9)
				task.spawn(function()
					Lighting.Brightness = 6
					task.wait(0.12)
					applyWeatherVisuals()
				end)
			end
			if os.clock() > nextWeather then
				nextWeather = os.clock() + math.random(Config.WeatherInterval[1], Config.WeatherInterval[2])
				local roll = math.random()
				if roll < Config.Weather.Thunderstorm.Chance then
					self:StartWeather("Thunderstorm")
				elseif roll < Config.Weather.Thunderstorm.Chance + Config.Weather.Rain.Chance then
					self:StartWeather("Rain")
				end
			end
		end
	end)
end

return EventService
