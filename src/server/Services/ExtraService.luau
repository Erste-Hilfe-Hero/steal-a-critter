-- Update 4: Einfuehrung, Wochen-Quests, Titel, Gratis-Ei, Expeditionen, Favoriten, Schnell-Verkauf,
-- Diebstahl-Protokoll, Trampoline und Basis-Deko.
-- Der Client (Extras.luau) bekommt alles ueber ProgressService:SetExtra("Extras", ...).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Units = require(ReplicatedStorage.Shared.Units)
local UnitFactory = require(script.Parent.UnitFactory)

local ExtraService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)
local PURPLE = Color3.fromRGB(200, 140, 255)

local weeklyById = {}
for _, quest in Config.WeeklyQuests do
	weeklyById[quest.Id] = quest
end
local titlesById = {}
for _, title in Config.Titles do
	titlesById[title.Id] = title
end
local tripsById = {}
for _, trip in Config.Expeditions do
	tripsById[trip.Id] = trip
end
local decorById = {}
for _, decor in Config.Decorations do
	decorById[decor.Id] = decor
end

function ExtraService:Init(services)
	self.Services = services
end

local function notify(player: Player, text: string, color: Color3?)
	ExtraService.Services.Net.SendNotify(player, text, color)
end

local function dataOf(player: Player)
	return ExtraService.Services.DataService:Get(player)
end

-- Woche beginnt Montag 00:00 UTC (Tag 0 der Unix-Zeit war ein Donnerstag)
local function weekIndex(): number
	return (os.time() // 86400 + 3) // 7
end

local function weekEnds(week: number): number
	return ((week + 1) * 7 - 3) * 86400
end

-- Spielstaende koennen alt oder kaputt sein: Listen immer pruefen
local function ensureTables(data)
	for _, key in { "TitlesSeen", "Expeditions", "Favorites", "TheftLog", "Decor" } do
		if type(data[key]) ~= "table" then
			data[key] = {}
		end
	end
	if type(data.Tutorial) ~= "number" then
		data.Tutorial = 0
	end
	if type(data.Title) ~= "string" then
		data.Title = ""
	end
end

local function statValue(player: Player, data, stat: string): number
	if stat == "Rebirths" then
		return data.Rebirths or 0
	elseif stat == "Index" then
		return ExtraService.Services.ProgressService.IndexCount(data)
	elseif stat == "TotalEarned" then
		return data.TotalEarned or 0
	elseif stat == "Streak" then
		return data.RewardStreak or 0
	elseif stat == "PlayHours" then
		return (data.PlayTime or 0) / 3600
	elseif stat == "Likes" then
		return data.Likes or 0
	end
	return data.Stats[stat] or 0
end

---------------------------------------------------------------- Wochen-Quests

local function ensureWeekly(data)
	local week = weekIndex()
	if type(data.Weekly) == "table" and data.Weekly.Week == week and type(data.Weekly.List) == "table" then
		return
	end
	local pool = table.clone(Config.WeeklyQuests)
	local list = {}
	for _ = 1, math.min(Config.WeeklyQuestsPerWeek, #pool) do
		local quest = table.remove(pool, math.random(1, #pool))
		table.insert(list, { Id = quest.Id, Progress = 0, Claimed = false })
	end
	data.Weekly = { Week = week, List = list, BonusClaimed = false }
end

local function weeklyReward(player: Player, quest): number
	return ExtraService.Services.ProgressService.IncomeReward(player, quest.Minutes, Config.WeeklyMinCash)
end

---------------------------------------------------------------- Stand fuer den Client

function ExtraService:Refresh(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	ensureTables(data)
	ensureWeekly(data)
	local weekly = {}
	for index, entry in data.Weekly.List do
		local quest = weeklyById[entry.Id]
		if quest then
			table.insert(weekly, {
				Index = index,
				Text = string.format(quest.Text, quest.Goal),
				Goal = quest.Goal,
				Progress = entry.Progress,
				Claimed = entry.Claimed,
				Reward = weeklyReward(player, quest),
			})
		end
	end
	local titles = {}
	for _, title in Config.Titles do
		table.insert(titles, {
			Id = title.Id,
			Name = title.Name,
			Text = title.Text,
			Unlocked = statValue(player, data, title.Stat) >= title.Goal,
			Progress = math.min(statValue(player, data, title.Stat), title.Goal),
			Goal = title.Goal,
		})
	end
	local trips = {}
	for index, entry in data.Expeditions do
		local info = Units.Info(entry.Code)
		local trip = tripsById[entry.Trip]
		table.insert(trips, {
			Index = index,
			Name = if info then info.Name else "?",
			Rarity = if info then info.Rarity else "Common",
			Trip = if trip then trip.Name else "?",
			Ends = entry.Ends,
			Cash = entry.Cash,
		})
	end
	local decor = {}
	for id in data.Decor do
		decor[id] = true
	end
	self.Services.ProgressService:SetExtra(player, "Extras", {
		Tutorial = data.Tutorial,
		Weekly = weekly,
		WeeklyEnds = weekEnds(data.Weekly.Week),
		WeeklyBonusClaimed = data.Weekly.BonusClaimed == true,
		Titles = titles,
		Title = data.Title,
		FreeEggAt = data.FreeEggAt or 0,
		Expeditions = trips,
		TheftLog = table.clone(data.TheftLog),
		Decor = decor,
	})
end

---------------------------------------------------------------- Einfuehrung

local function checkTutorial(player: Player, data)
	local steps = Config.TutorialSteps
	while data.Tutorial < #steps do
		local step = steps[data.Tutorial + 1]
		if (data.Stats[step.Stat] or 0) < step.Goal then
			return
		end
		data.Tutorial += 1
		ExtraService.Services.DataService:AddCash(player, step.Cash)
		ExtraService.Services.Net.PlaySfx(player, "Reward")
		if data.Tutorial >= #steps then
			notify(player, `✅ Tutorial complete: +{Format.Cash(step.Cash)}! Check QUESTS and MORE for much more.`, GOLD)
		else
			notify(player, `✅ {step.Text}: +{Format.Cash(step.Cash)}! Next: {steps[data.Tutorial + 1].Text}`, GOLD)
		end
	end
end

local function skipTutorial(player: Player)
	local data = dataOf(player)
	if not data then
		return false, "Not ready"
	end
	data.Tutorial = #Config.TutorialSteps
	ExtraService:Refresh(player)
	return true, "Tutorial skipped. Have fun stealing!"
end

---------------------------------------------------------------- Titel

-- Meldet neu freigeschaltete Titel genau einmal (gemerkt in data.TitlesSeen)
local function checkTitles(player: Player, data, silent: boolean)
	for _, title in Config.Titles do
		if not data.TitlesSeen[title.Id] and statValue(player, data, title.Stat) >= title.Goal then
			data.TitlesSeen[title.Id] = true
			if not silent and title.Goal > 0 then
				notify(player, `🏷️ New title unlocked: "{title.Name}"! Wear it in MORE > TITLES.`, title.Color)
			end
		end
	end
end

local function setTitle(player: Player, id: any)
	local data = dataOf(player)
	if not data then
		return false, "Not ready"
	end
	if id == "" then
		data.Title = ""
		player:SetAttribute("Title", nil)
		ExtraService:Refresh(player)
		return true, "Title removed"
	end
	local title = type(id) == "string" and titlesById[id]
	if not title then
		return false, "Unknown title"
	end
	if statValue(player, data, title.Stat) < title.Goal then
		return false, `Locked: {title.Text}`
	end
	data.Title = title.Id
	player:SetAttribute("Title", title.Name)
	ExtraService:Refresh(player)
	return true, `You are now "{title.Name}"!`
end

---------------------------------------------------------------- Wochen-Quests abholen

local function claimWeekly(player: Player, index: any)
	local services = ExtraService.Services
	local data = dataOf(player)
	if not data or type(index) ~= "number" then
		return false, "Not ready"
	end
	ensureWeekly(data)
	local entry = data.Weekly.List[index]
	local quest = entry and weeklyById[entry.Id]
	if not entry or not quest or entry.Claimed or entry.Progress < quest.Goal then
		return false, "Not completed yet"
	end
	entry.Claimed = true
	local reward = weeklyReward(player, quest)
	services.DataService:AddCash(player, reward)
	local text = `Weekly reward: +{Format.Cash(reward)}!`
	local allDone = true
	for _, other in data.Weekly.List do
		if not other.Claimed then
			allDone = false
		end
	end
	if allDone and not data.Weekly.BonusClaimed then
		-- Alle drei geschafft: Rebirth-Token und Fusion Catalyst
		data.Weekly.BonusClaimed = true
		data.Tokens = (data.Tokens or 0) + 1
		data.Catalysts = (data.Catalysts or 0) + 1
		player:SetAttribute("Catalysts", data.Catalysts)
		services.FeatureService:Refresh(player)
		text ..= " ALL WEEKLY QUESTS DONE: +1 Rebirth Token and a Fusion Catalyst!"
	end
	services.Net.PlaySfx(player, "Reward")
	ExtraService:Refresh(player)
	return true, text
end

---------------------------------------------------------------- Gratis-Ei

local function freeEgg(player: Player)
	local data = dataOf(player)
	if not data then
		return false, "Not ready"
	end
	local now = os.time()
	if now < (data.FreeEggAt or 0) then
		return false, `Next free egg in {Format.Time(data.FreeEggAt - now)}`
	end
	local ok, message, extra = ExtraService.Services.FeatureService:Hatch(player, Config.FreeEggId, true)
	if ok then
		data.FreeEggAt = now + Config.FreeEggCooldown
		ExtraService:Refresh(player)
	end
	return ok, message, extra
end

---------------------------------------------------------------- Expeditionen

function ExtraService:HasExpeditions(player: Player): boolean
	local data = dataOf(player)
	return data ~= nil and type(data.Expeditions) == "table" and #data.Expeditions > 0
end

local function sendExpedition(player: Player, arg: any)
	local services = ExtraService.Services
	local data = dataOf(player)
	if not data or type(arg) ~= "table" or type(arg.Slot) ~= "string" or type(arg.Trip) ~= "string" then
		return false, "Not ready"
	end
	local trip = tripsById[arg.Trip]
	local slotKey = arg.Slot
	local info = Units.Info(data.Units[slotKey])
	if not trip or not info then
		return false, "No critter there"
	end
	if #data.Expeditions >= Config.MaxExpeditions then
		return false, `Only {Config.MaxExpeditions} expeditions at once!`
	end
	local model = services.UnitService:GetBaseModels(player)[slotKey]
	if not model or model:GetAttribute("BeingStolen") then
		return false, "Not possible right now"
	end
	if data.Vault == slotKey then
		return false, "Vaulted critters stay home!"
	end
	-- Belohnung beim Start festlegen: so viel, wie die Kreatur in RewardMinutes verdienen wuerde
	local perSecond = info.Income * services.FeatureService:LevelFactor(player, slotKey) * services.MonetizationService:GetMultiplier(player)
	local cash = math.floor(math.max(trip.MinCash, perSecond * 60 * trip.RewardMinutes))
	local level = data.Levels[slotKey] or 0
	services.UnitService:RemoveBaseUnit(player, slotKey)
	table.insert(data.Expeditions, { Code = info.Code, Level = level, Ends = os.time() + trip.Minutes * 60, Trip = trip.Id, Cash = cash })
	services.Net.PlaySfx(player, "Hatch")
	ExtraService:Refresh(player)
	return true, `{info.Name} left on a {trip.Name}! Back in {trip.Minutes} min with {Format.Cash(cash)}.`
end

local function claimExpedition(player: Player, index: any)
	local services = ExtraService.Services
	local data = dataOf(player)
	if not data or type(index) ~= "number" then
		return false, "Not ready"
	end
	local entry = data.Expeditions[index]
	if not entry then
		return false, "Not found"
	end
	if os.time() < (entry.Ends or 0) then
		return false, `Back in {Format.Time(entry.Ends - os.time())}`
	end
	local info = Units.Info(entry.Code)
	if not info then
		-- Unbekannte Kreatur (alter Spielstand): Eintrag entfernen, Cash trotzdem auszahlen
		table.remove(data.Expeditions, index)
		services.DataService:AddCash(player, tonumber(entry.Cash) or 0)
		ExtraService:Refresh(player)
		return true, `+{Format.Cash(tonumber(entry.Cash) or 0)}`
	end
	local slot = services.UnitService:FindFreeSlot(player)
	if not slot then
		return false, "Your base is full! Sell or fuse a critter first."
	end
	-- Chance auf eine bessere Mutation (seltenste zuerst)
	local code = info.Code
	local current = if info.Mutation then info.Mutation.Multiplier else 1
	local trip = tripsById[entry.Trip]
	local upgraded = nil
	for _, upgrade in (if trip then trip.Mutations else {}) do
		local target = Units.MutationsByName[upgrade.Name]
		if target and target.Multiplier > current and math.random() < upgrade.Chance then
			code = Units.Encode(info.Id, target.Name, info.Fusion)
			upgraded = target
			break
		end
	end
	table.remove(data.Expeditions, index)
	data.Levels[slot] = if (tonumber(entry.Level) or 0) > 0 then entry.Level else nil
	services.UnitService:GiveUnit(player, code, slot)
	local cash = tonumber(entry.Cash) or 0
	services.DataService:AddCash(player, cash)
	services.ProgressService:Track(player, "Expeditions", 1)
	services.Net.PlaySfx(player, "Reward")
	local result = Units.Info(code)
	local text = `{result.Name} is back with {Format.Cash(cash)}!`
	if upgraded then
		text = `WOW! {info.Name} came back as {result.Name} with {Format.Cash(cash)}!`
		if upgraded.Multiplier >= 4 then
			services.Net.SendAnnounce(`{player.DisplayName}'s critter came back from an expedition as {result.Name}!`, upgraded.Color)
		end
	end
	ExtraService:Refresh(player)
	return true, text
end

---------------------------------------------------------------- Favoriten und Schnell-Verkauf

local function toggleFavorite(player: Player, slotKey: any)
	local data = dataOf(player)
	local info = data and type(slotKey) == "string" and Units.Info(data.Units[slotKey])
	if not info then
		return false, "No critter there"
	end
	local favorite = not data.Favorites[slotKey]
	data.Favorites[slotKey] = if favorite then true else nil
	ExtraService.Services.UnitService:RefreshUnitLabel(player, slotKey)
	ExtraService.Services.FeatureService:Refresh(player)
	return true, if favorite then `❤ {info.Name} is a favorite and can't be sold.` else `{info.Name} is no longer a favorite.`
end

local function sellBulk(player: Player, rarity: any)
	local services = ExtraService.Services
	local data = dataOf(player)
	if not data or type(rarity) ~= "string" or not table.find(Config.BulkSellRarities, rarity) then
		return false, "Not possible"
	end
	local models = services.UnitService:GetBaseModels(player)
	local slots = {}
	for slotKey, code in data.Units do
		local info = Units.Info(code)
		local model = models[slotKey]
		if info and info.Rarity == rarity and not info.Mutation and info.Fusion == 0
			and not data.Favorites[slotKey] and data.Vault ~= slotKey and (data.Levels[slotKey] or 0) == 0
			and model and not model:GetAttribute("BeingStolen") then
			table.insert(slots, slotKey)
		end
	end
	if #slots == 0 then
		return false, `No plain {rarity} critters to sell (mutated, fused, trained and ❤ critters are kept).`
	end
	local total = 0
	for _, slotKey in slots do
		local info = Units.Info(data.Units[slotKey])
		if info then
			total += math.floor(info.Value * Config.SellShare)
			services.UnitService:RemoveBaseUnit(player, slotKey)
		end
	end
	services.DataService:AddCash(player, total)
	services.ProgressService:Track(player, "Sold", #slots)
	services.Net.PlaySfx(player, "Buy")
	return true, `Sold {#slots} {rarity} critters for {Format.Cash(total)}!`
end

---------------------------------------------------------------- Diebstahl-Protokoll

local function addLog(player: Player, kind: string, who: string, critter: string)
	local data = dataOf(player)
	if not data then
		return
	end
	ensureTables(data)
	table.insert(data.TheftLog, 1, { Kind = kind, Who = who, Critter = critter, At = os.time() })
	while #data.TheftLog > Config.TheftLogSize do
		table.remove(data.TheftLog)
	end
	ExtraService:Refresh(player)
end

-- Erfolgreicher Diebstahl: Eintrag beim Opfer und beim Dieb
function ExtraService:LogTheft(owner: Player, thief: Player, info)
	if not info then
		return
	end
	addLog(owner, "Lost", thief.DisplayName, info.Name)
	addLog(thief, "Stole", owner.DisplayName, info.Name)
end

-- Ein Dieb wurde geschlagen und hat die Kreatur fallen lassen
function ExtraService:LogSave(owner: Player, hero: Player, thief: Player, info)
	if not info or not owner.Parent then
		return
	end
	if hero == owner then
		addLog(owner, "Defended", thief.DisplayName, info.Name)
	else
		addLog(owner, "Saved", hero.DisplayName, info.Name)
	end
end

---------------------------------------------------------------- Basis-Deko

local function decoPart(parent: Instance, props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Jede Deko sitzt an einem festen Platz, der keine Slots, den Eingang und den Sperr-Knopf verdeckt
local DECOR_BUILDERS = {
	Flowers = function(folder: Instance, base: CFrame)
		local colors = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(170, 120, 255), Color3.fromRGB(255, 150, 80) }
		for _, x in { -13, 13 } do
			decoPart(folder, { Name = "FlowerBed", Size = Vector3.new(8, 0.6, 2), CFrame = base * CFrame.new(x, 0.3, 19.8), Color = Color3.fromRGB(110, 75, 50), Material = Enum.Material.Wood })
			for i = 0, 4 do
				local position = base * CFrame.new(x - 3.2 + i * 1.6, 0.9, 19.8)
				decoPart(folder, { Name = "Stem", Size = Vector3.new(0.15, 0.7, 0.15), CFrame = position, Color = Color3.fromRGB(70, 160, 80) })
				decoPart(folder, { Name = "Bloom", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.7, CFrame = position * CFrame.new(0, 0.5, 0), Color = colors[i % #colors + 1], Material = Enum.Material.SmoothPlastic })
			end
		end
	end,
	Lanterns = function(folder: Instance, base: CFrame)
		for _, spot in { Vector3.new(20.3, 0, 20.3), Vector3.new(-20.3, 0, 20.3), Vector3.new(20.3, 0, -20.3), Vector3.new(-20.3, 0, -20.6) } do
			local cf = base * CFrame.new(spot)
			decoPart(folder, { Name = "LanternPole", Size = Vector3.new(0.4, 5, 0.4), CFrame = cf * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(40, 35, 50), Material = Enum.Material.Metal })
			local lamp = decoPart(folder, { Name = "Lantern", Size = Vector3.new(1.2, 1.4, 1.2), CFrame = cf * CFrame.new(0, 5.4, 0), Color = Color3.fromRGB(255, 190, 110), Material = Enum.Material.Neon })
			local light = Instance.new("PointLight")
			light.Color = lamp.Color
			light.Range = 14
			light.Brightness = 1.2
			light.Parent = lamp
		end
	end,
	Flag = function(folder: Instance, base: CFrame, accent: Color3)
		local cf = base * CFrame.new(-20.3, 0, 8)
		decoPart(folder, { Name = "FlagPole", Size = Vector3.new(0.4, 14, 0.4), CFrame = cf * CFrame.new(0, 7, 0), Color = Color3.fromRGB(220, 220, 230), Material = Enum.Material.Metal })
		decoPart(folder, { Name = "FlagTop", Shape = Enum.PartType.Ball, Size = Vector3.one * 0.8, CFrame = cf * CFrame.new(0, 14.2, 0), Color = Color3.fromRGB(255, 210, 70), Material = Enum.Material.Foil })
		decoPart(folder, { Name = "FlagCloth", Size = Vector3.new(0.15, 3, 5), CFrame = cf * CFrame.new(0, 12, 2.6), Color = accent, Material = Enum.Material.Fabric })
	end,
	Fountain = function(folder: Instance, base: CFrame)
		local cf = base * CFrame.new(16.5, 0, -16.5)
		local rotate = CFrame.Angles(0, 0, math.rad(90))
		decoPart(folder, { Name = "Basin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 7, 7), CFrame = cf * CFrame.new(0, 0.6, 0) * rotate, Color = Color3.fromRGB(190, 185, 200), Material = Enum.Material.Marble })
		decoPart(folder, { Name = "Water", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 6, 6), CFrame = cf * CFrame.new(0, 1.15, 0) * rotate, Color = Color3.fromRGB(90, 170, 255), Material = Enum.Material.Glass, Transparency = 0.3 })
		decoPart(folder, { Name = "Pillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 1, 1), CFrame = cf * CFrame.new(0, 2.5, 0) * rotate, Color = Color3.fromRGB(190, 185, 200), Material = Enum.Material.Marble })
		local top = decoPart(folder, { Name = "Spout", Shape = Enum.PartType.Ball, Size = Vector3.one * 1.4, CFrame = cf * CFrame.new(0, 4.2, 0), Color = Color3.fromRGB(190, 185, 200), Material = Enum.Material.Marble })
		local spray = Instance.new("ParticleEmitter")
		spray.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
		spray.Size = NumberSequence.new(0.3, 0.1)
		spray.Transparency = NumberSequence.new(0.2, 1)
		spray.Lifetime = NumberRange.new(0.8, 1.1)
		spray.Rate = 25
		spray.Speed = NumberRange.new(6, 8)
		spray.SpreadAngle = Vector2.new(20, 20)
		spray.Acceleration = Vector3.new(0, -18, 0)
		spray.Parent = top
	end,
	Statue = function(folder: Instance, base: CFrame)
		local cf = base * CFrame.new(0, 0, 19.5)
		decoPart(folder, { Name = "Pedestal", Size = Vector3.new(4, 1.6, 3), CFrame = cf * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(70, 65, 80), Material = Enum.Material.Marble })
		local info = table.clone(Units.Info(Units.Encode("goose", "Golden", 0)))
		info.Scale = 3
		local statue = UnitFactory.Build(info)
		statue.Name = "Statue"
		for _, child in statue:GetDescendants() do
			if child:IsA("ParticleEmitter") or child:IsA("PointLight") or child:IsA("Fire") then
				child:Destroy()
			elseif child:IsA("BasePart") then
				child.CanQuery = false
				child.CanTouch = false
			end
		end
		-- Blick Richtung Eingang (vorne = -Z wie bei den Slots)
		statue:PivotTo(cf * CFrame.new(0, 1.6 + info.Scale * 0.6, 0))
		statue.Parent = folder
	end,
}

-- Baut ein Deko-Stueck in einen Ordner (auch vom Smoke-Test benutzt)
function ExtraService.BuildDecorPiece(id: string, folder: Instance, base: CFrame, accent: Color3): (boolean, any)
	local builder = DECOR_BUILDERS[id]
	if not builder then
		return false, "unknown decoration " .. tostring(id)
	end
	return pcall(builder, folder, base, accent)
end

-- Baut die gesamte Deko der Basis neu (nach Kauf, Farbwechsel oder Beitritt)
function ExtraService:BuildDecor(player: Player)
	local data = dataOf(player)
	local plot = self.Services.PlotService:GetPlot(player)
	if not data or not plot then
		return
	end
	local old = plot.Model:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	if type(data.Decor) ~= "table" or next(data.Decor) == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Decor"
	for _, decor in Config.Decorations do
		if data.Decor[decor.Id] then
			local ok, err = ExtraService.BuildDecorPiece(decor.Id, folder, plot.CFrame, plot.Accent)
			if not ok then
				warn("[ExtraService] Deko", decor.Id, err)
			end
		end
	end
	folder.Parent = plot.Model
end

local function buyDecor(player: Player, id: any)
	local services = ExtraService.Services
	local data = dataOf(player)
	local decor = type(id) == "string" and decorById[id]
	if not data or not decor then
		return false, "Unknown decoration"
	end
	if data.Decor[decor.Id] then
		return false, "You already own this"
	end
	if data.Cash < decor.Price then
		return false, `You need {Format.Cash(decor.Price - data.Cash)} more.`
	end
	services.DataService:AddCash(player, -decor.Price)
	data.Decor[decor.Id] = true
	ExtraService:BuildDecor(player)
	services.Net.PlaySfx(player, "Reward")
	ExtraService:Refresh(player)
	return true, `{decor.Icon} {decor.Name} placed in your base!`
end

---------------------------------------------------------------- Trampoline

local function buildTrampolines()
	local conveyor = Config.Conveyor
	local folder = Instance.new("Folder")
	folder.Name = "Trampolines"
	for _, spot in { Vector2.new(14, -8), Vector2.new(14, 8), Vector2.new(28, 0) } do
		local position = Vector3.new(conveyor.EndX + spot.X, 0, spot.Y)
		local rotate = CFrame.Angles(0, 0, math.rad(90))
		decoPart(folder, { Name = "TrampolineFrame", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 9, 9), CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * rotate, Color = Color3.fromRGB(60, 60, 80), Material = Enum.Material.Metal, CanCollide = true })
		local pad = decoPart(folder, {
			Name = "Trampoline",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 7.6, 7.6),
			CFrame = CFrame.new(position + Vector3.new(0, 1.1, 0)) * rotate,
			Color = Color3.fromRGB(90, 200, 255),
			Material = Enum.Material.Neon,
			CanTouch = true,
		})
		-- Der Client des Spielers springt selbst (Charakter-Physik gehoert dem Client)
		CollectionService:AddTag(pad, "Trampoline")
	end
	folder.Parent = workspace
end

---------------------------------------------------------------- Zaehlen (von ProgressService:Track)

function ExtraService:OnStat(player: Player, stat: string, amount: number)
	local data = dataOf(player)
	if not data then
		return
	end
	ensureTables(data)
	checkTutorial(player, data)
	ensureWeekly(data)
	for _, entry in data.Weekly.List do
		local quest = weeklyById[entry.Id]
		if quest and quest.Stat == stat and entry.Progress < quest.Goal then
			entry.Progress = math.min(quest.Goal, entry.Progress + amount)
			if entry.Progress >= quest.Goal then
				notify(player, "Weekly quest complete! Claim it in MORE > WEEKLY.", PURPLE)
			end
		end
	end
	checkTitles(player, data, false)
	self:Refresh(player)
end

---------------------------------------------------------------- Lebenszyklus

function ExtraService:OnPlayerReady(player: Player)
	local data = dataOf(player)
	if not data then
		return
	end
	ensureTables(data)
	ensureWeekly(data)
	-- Erfahrene Spieler aus der Zeit vor Update 4 brauchen keine Einfuehrung
	if data.Tutorial == 0 and ((data.PlayTime or 0) > 1800 or (data.Rebirths or 0) > 0) then
		data.Tutorial = #Config.TutorialSteps
	end
	checkTutorial(player, data)
	-- Schon erreichte Titel nicht nachtraeglich melden
	checkTitles(player, data, true)
	local title = titlesById[data.Title]
	if title and statValue(player, data, title.Stat) >= title.Goal then
		player:SetAttribute("Title", title.Name)
	else
		data.Title = ""
	end
	-- Expeditionen aus alten/kaputten Spielstaenden aufraeumen
	for index = #data.Expeditions, 1, -1 do
		local entry = data.Expeditions[index]
		if type(entry) ~= "table" or type(entry.Code) ~= "string" or type(entry.Ends) ~= "number" then
			table.remove(data.Expeditions, index)
		end
	end
	self:BuildDecor(player)
	self:Refresh(player)
end

function ExtraService:OnPlayerRemoving(player: Player)
	-- Deko gehoert zum Spieler, nicht zur Basis
	local plot = self.Services.PlotService:GetPlot(player)
	local decor = plot and plot.Model:FindFirstChild("Decor")
	if decor then
		decor:Destroy()
	end
end

function ExtraService:Start()
	local net = self.Services.Net
	net.Handle("SkipTutorial", skipTutorial)
	net.Handle("ClaimWeekly", claimWeekly)
	net.Handle("SetTitle", setTitle)
	net.Handle("FreeEgg", freeEgg)
	net.Handle("SendExpedition", sendExpedition)
	net.Handle("ClaimExpedition", claimExpedition)
	net.Handle("Favorite", toggleFavorite)
	net.Handle("SellBulk", sellBulk)
	net.Handle("BuyDecor", buyDecor)
	buildTrampolines()

	-- Neue Woche oder neue Titel (z.B. durch Spielzeit) auch ohne Aktion des Spielers bemerken
	task.spawn(function()
		while true do
			task.wait(30)
			for _, player in Players:GetPlayers() do
				local data = dataOf(player)
				if data then
					ensureTables(data)
					checkTitles(player, data, false)
					self:Refresh(player)
				end
			end
		end
	end)
end

return ExtraService
