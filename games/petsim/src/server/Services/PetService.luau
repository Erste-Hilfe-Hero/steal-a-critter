-- Haustiere: Inventar, Ausruesten, Eier schluepfen, goldene Haustiere, Tore, Rebirth und taegliches Geschenk.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local PetService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)
local RAINBOW = Color3.fromRGB(255, 120, 220)

local lastHatch = {} -- [Player] = os.clock()
local autoHatch = {} -- [Player] = true
local lastRemote = {} -- [Player] = os.clock() (Schutz gegen Spam der Inventar-Remotes)
local lastTeleport = {} -- [Player] = os.clock()
local rng = Random.new()

function PetService:Init(services)
	self.Services = services
end

local function notify(player: Player, text: string, color: Color3?)
	PetService.Services.Net.SendNotify(player, text, color)
end

local function today(): number
	return os.time() // 86400
end

-- Inventar-Remotes hoechstens ~10x pro Sekunde (jeder Aufruf schickt das ganze Inventar zurueck)
local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRemote[player] or 0) < 0.1 then
		return true
	end
	lastRemote[player] = now
	return false
end

local function progress()
	return PetService.Services.ProgressService
end

---------------------------------------------------------------- Inventar

function PetService:GetMaxEquip(player: Player): number
	local extra = if self.Services.MonetizationService:HasPass(player, "MorePets") then Config.ExtraEquipAmount else 0
	return Config.BaseEquip + extra
end

function PetService:GetStorage(player: Player): number
	local data = self.Services.DataService:Get(player)
	return Config.MaxStorage + (if data then data.ExtraStorage else 0)
end

local function countPets(data): number
	local count = 0
	for _ in data.Pets do
		count += 1
	end
	return count
end

-- Equipped-Liste bereinigen (geloeschte Haustiere, zu viele nach Ablauf eines Vorteils)
local function cleanEquipped(player: Player, data)
	local seen = {}
	local clean = {}
	for _, uid in data.Equipped do
		if data.Pets[uid] and not seen[uid] and #clean < PetService:GetMaxEquip(player) then
			seen[uid] = true
			table.insert(clean, uid)
		end
	end
	data.Equipped = clean
end

-- Schickt das Inventar an den Client und aktualisiert Staerke und die Haustiere, die folgen
function PetService:Sync(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	cleanEquipped(player, data)
	local power = 0
	local visible = {}
	for _, uid in data.Equipped do
		local pet = data.Pets[uid]
		power += Config.PetPower(pet.T, pet.G, pet.R)
		table.insert(visible, pet.T .. (if pet.R then ":r" elseif pet.G then ":g" else ""))
	end
	player:SetAttribute("Power", power)
	player:SetAttribute("EquippedPets", table.concat(visible, ","))
	player:SetAttribute("MaxEquip", self:GetMaxEquip(player))
	player:SetAttribute("Storage", self:GetStorage(player))
	self.Services.Net.Inventory:FireClient(player, data.Pets, data.Equipped)
end

function PetService:AddPet(player: Player, typeId: string, golden: boolean?, rainbow: boolean?): string?
	local data = self.Services.DataService:Get(player)
	if not data or not Config.PetsById[typeId] then
		return nil
	end
	local uid = tostring(data.NextPetId)
	data.NextPetId += 1
	data.Pets[uid] = { T = typeId, G = golden == true, R = if rainbow then true else nil }
	progress():Discover(player, typeId)
	-- Freier Platz? Dann gleich ausruesten (macht Neue sofort staerker)
	if #data.Equipped < self:GetMaxEquip(player) then
		table.insert(data.Equipped, uid)
	end
	return uid
end

local function equipBest(player: Player, data)
	local list = {}
	for uid, pet in data.Pets do
		table.insert(list, { Uid = uid, Power = Config.PetPower(pet.T, pet.G, pet.R) })
	end
	table.sort(list, function(a, b)
		return a.Power > b.Power
	end)
	data.Equipped = {}
	for i = 1, math.min(#list, PetService:GetMaxEquip(player)) do
		table.insert(data.Equipped, list[i].Uid)
	end
end

---------------------------------------------------------------- Eier

function PetService:GetLuck(player: Player): number
	local luck = self.Services.MonetizationService:GetServerLuck()
	if self.Services.MonetizationService:HasPass(player, "Lucky") then
		luck *= Config.LuckyMultiplier
	end
	return luck
end

local function roll(egg, luck: number): string
	local odds = Config.EggOdds(egg, luck)
	local value = rng:NextNumber() * 100
	for _, entry in odds do
		value -= entry.Chance
		if value <= 0 then
			return entry.Pet
		end
	end
	return odds[1].Pet
end

-- Auto Hatch ausschalten (z. B. wenn Muenzen oder Platz fehlen), statt alle 2,5 s dieselbe Meldung zu schicken
local function stopAutoHatch(player: Player, reason: string)
	if autoHatch[player] then
		autoHatch[player] = nil
		player:SetAttribute("AutoHatch", false)
		notify(player, reason .. " Auto Hatch is now OFF.", RED)
	end
end

-- Bezahlt wird nur mit Muenzen. Gibt true zurueck, wenn geschluepft wurde.
-- auto = vom Auto Hatch ausgeloest (dann bei Fehlern Auto Hatch beenden)
function PetService:Hatch(player: Player, eggId: string, amount: number, auto: boolean?): boolean
	local services = self.Services
	local egg = Config.EggsById[eggId]
	local data = services.DataService:Get(player)
	if not egg or not data then
		return false
	end
	if os.clock() - (lastHatch[player] or 0) < Config.HatchCooldown then
		return false
	end
	if data.Zone < egg.Zone then
		notify(player, "Unlock this zone first!", RED)
		return false
	end
	local zone = services.WorldService.Zones[egg.Zone]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - zone.EggPart.Position).Magnitude > Config.EggRange + 8 then
		return false
	end
	local free = self:GetStorage(player) - countPets(data)
	if free <= 0 then
		if auto then
			stopAutoHatch(player, "Your pet storage is full!")
		else
			notify(player, "Your pet storage is full! Delete or craft pets.", RED)
		end
		return false
	end
	amount = math.min(amount, free)
	local cost = egg.Price * amount
	if data.Coins < cost then
		-- Mit Triple Hatch notfalls nur so viele Eier, wie bezahlbar sind
		amount = math.min(amount, data.Coins // egg.Price)
		cost = egg.Price * amount
	end
	if amount <= 0 then
		if auto then
			stopAutoHatch(player, `You need {Format.Coins(egg.Price)}!`)
		else
			notify(player, `You need {Format.Coins(egg.Price)}!`, RED)
		end
		return false
	end
	lastHatch[player] = os.clock()
	services.DataService:AddCoins(player, -cost)

	local luck = self:GetLuck(player)
	local results = {}
	for _ = 1, amount do
		local typeId = roll(egg, luck)
		self:AddPet(player, typeId)
		table.insert(results, typeId)
		data.Hatched += 1
		local def = Config.PetsById[typeId]
		if Config.RaritiesByName[def.Rarity].Announce then
			services.Net.SendAnnounce(`{player.DisplayName} hatched a {def.Rarity} {def.Name}!`, Config.RaritiesByName[def.Rarity].Color)
		end
	end
	services.DataService:UpdateAttributes(player)
	services.Net.Hatched:FireClient(player, egg.Id, results)
	self:Sync(player)
	progress():Track(player, "Hatch", amount)
	return true
end

---------------------------------------------------------------- Tore und Rebirth

function PetService:UnlockZone(player: Player, index: number)
	local services = self.Services
	local data = services.DataService:Get(player)
	local zone = Config.Zones[index]
	if not data or not zone then
		return
	end
	if data.Zone >= index then
		return
	end
	if data.Zone < index - 1 then
		notify(player, `Unlock {Config.Zones[index - 1].Name} first!`, RED)
		return
	end
	if data.Coins < zone.GateCost then
		notify(player, `You need {Format.Coins(zone.GateCost)}!`, RED)
		return
	end
	services.DataService:AddCoins(player, -zone.GateCost)
	data.Zone = index
	data.BestZone = math.max(data.BestZone, index)
	services.DataService:UpdateAttributes(player)
	progress():Track(player, "Zone", index)
	notify(player, `{zone.Name} unlocked!`, GREEN)
	if index == #Config.Zones then
		services.Net.SendAnnounce(`{player.DisplayName} reached {zone.Name}!`, GOLD)
	end
end

function PetService:Rebirth(player: Player)
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Zone < #Config.Zones or data.Coins < cost then
		notify(player, `Rebirth needs {Config.Zones[#Config.Zones].Name} and {Format.Coins(cost)}.`, RED)
		return
	end
	-- Muenzen und Zonen zuruecksetzen, Haustiere bleiben
	data.Coins = 0
	data.Zone = 1
	data.Rebirths += 1
	services.DataService:UpdateAttributes(player)
	if player.Character then
		player.Character:PivotTo(services.WorldService.SpawnCFrame(1))
	end
	services.Net.SendAnnounce(`{player.DisplayName} rebirthed! (x{1 + data.Rebirths * Config.RebirthMultiplierPer} coins)`, Color3.fromRGB(180, 100, 255))
	progress():Track(player, "Rebirth", 1)
end

-- Muenzen fuer N Eier der besten freigeschalteten Zone (fuer Geschenke und Muenz-Pakete)
function PetService:EggValue(player: Player, eggs: number): number
	local data = self.Services.DataService:Get(player)
	local zone = if data then data.Zone else 1
	local egg = Config.EggByZone[zone] or Config.Eggs[1]
	return egg.Price * eggs
end

---------------------------------------------------------------- Start

function PetService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if not data.GotStarter then
		data.GotStarter = true
		self:AddPet(player, Config.StarterPet)
	end
	self:Sync(player)
end

function PetService:Start()
	local services = self.Services
	local net = services.Net

	for _, zone in services.WorldService.Zones do
		if zone.GatePrompt then
			zone.GatePrompt.Triggered:Connect(function(player)
				self:UnlockZone(player, zone.Index)
			end)
		end
		if zone.HatchPrompt then
			zone.HatchPrompt.Triggered:Connect(function(player)
				self:Hatch(player, zone.Egg.Id, 1)
			end)
			zone.Hatch3Prompt.Triggered:Connect(function(player)
				if services.MonetizationService:HasPass(player, "TripleHatch") then
					self:Hatch(player, zone.Egg.Id, 3)
				else
					services.MonetizationService:PromptPass(player, "TripleHatch")
				end
			end)
		end
	end

	services.WorldService.DailyPrompt.Triggered:Connect(function(player)
		local data = services.DataService:Get(player)
		if not data then
			return
		end
		if data.LastDaily == today() then
			notify(player, "Come back tomorrow for a new gift!", RED)
			return
		end
		-- Serie: gestern abgeholt = weiter zaehlen, sonst neu bei Tag 1
		data.Streak = if data.LastDaily == today() - 1 then data.Streak + 1 else 1
		data.LastDaily = today()
		local amount = math.floor(self:EggValue(player, Config.DailyGiftEggs(data.Streak)))
		services.DataService:AddCoins(player, amount)
		notify(player, `Daily gift (day {data.Streak} streak): +{Format.Coins(amount)}!`, GOLD)
		if data.Streak % Config.StreakMax == 0 then
			data.BoostUntil = math.max(os.time(), data.BoostUntil) + Config.StreakDay7BoostSeconds
			services.DataService:UpdateAttributes(player)
			notify(player, `{Config.StreakMax} day streak! Free 2x Coins for {Config.StreakDay7BoostSeconds // 60} minutes!`, GOLD)
		end
		progress():Track(player, "Streak", data.Streak)
	end)

	net.ToggleEquip.OnServerEvent:Connect(function(player, uid)
		local data = services.DataService:Get(player)
		if not data or typeof(uid) ~= "string" or not data.Pets[uid] or throttled(player) then
			return
		end
		local index = table.find(data.Equipped, uid)
		if index then
			table.remove(data.Equipped, index)
		elseif #data.Equipped < self:GetMaxEquip(player) then
			table.insert(data.Equipped, uid)
		else
			notify(player, "All pet slots are full! Unequip one first.", RED)
			if not services.MonetizationService:HasPass(player, "MorePets") then
				services.MonetizationService:PromptPass(player, "MorePets")
			end
			return
		end
		self:Sync(player)
	end)

	net.EquipBest.OnServerEvent:Connect(function(player)
		local data = services.DataService:Get(player)
		if data and not throttled(player) then
			equipBest(player, data)
			self:Sync(player)
		end
	end)

	net.DeletePets.OnServerEvent:Connect(function(player, uids)
		local data = services.DataService:Get(player)
		if not data or typeof(uids) ~= "table" or throttled(player) then
			return
		end
		local removed = 0
		local remaining = countPets(data)
		for _, uid in uids do
			-- Das letzte Haustier bleibt immer, gesperrte Haustiere werden nie geloescht
			if typeof(uid) == "string" and data.Pets[uid] and not data.Pets[uid].L and remaining > 1 then
				remaining -= 1
				data.Pets[uid] = nil
				removed += 1
			end
		end
		if removed > 0 then
			self:Sync(player)
		end
	end)

	net.CraftGolden.OnServerEvent:Connect(function(player, typeId)
		local data = services.DataService:Get(player)
		if not data or typeof(typeId) ~= "string" or not Config.PetsById[typeId] or throttled(player) then
			return
		end
		local matching = {}
		for uid, pet in data.Pets do
			if pet.T == typeId and not pet.G and not pet.R and not pet.L then
				table.insert(matching, uid)
			end
		end
		if #matching < Config.GoldenCraftAmount then
			notify(player, `You need {Config.GoldenCraftAmount} unlocked pets of the same kind!`, RED)
			return
		end
		-- Ausgeruestete zuletzt verbrauchen
		table.sort(matching, function(a, b)
			return (table.find(data.Equipped, a) and 1 or 0) < (table.find(data.Equipped, b) and 1 or 0)
		end)
		local wasEquipped = false
		for i = 1, Config.GoldenCraftAmount do
			wasEquipped = wasEquipped or table.find(data.Equipped, matching[i]) ~= nil
			data.Pets[matching[i]] = nil
		end
		cleanEquipped(player, data)
		local uid = self:AddPet(player, typeId, true)
		if wasEquipped and uid and not table.find(data.Equipped, uid) and #data.Equipped < self:GetMaxEquip(player) then
			table.insert(data.Equipped, uid)
		end
		local def = Config.PetsById[typeId]
		notify(player, `You crafted a GOLDEN {def.Name}!`, GOLD)
		if Config.RaritiesByName[def.Rarity].Index >= 4 then
			net.SendAnnounce(`{player.DisplayName} crafted a GOLDEN {def.Name}!`, GOLD)
		end
		self:Sync(player)
		progress():Track(player, "Golden", 1)
	end)

	-- Regenbogen: 5 gleiche goldene -> 1 Regenbogen-Haustier (gleicher Ablauf wie golden)
	net.CraftRainbow.OnServerEvent:Connect(function(player, typeId)
		local data = services.DataService:Get(player)
		if not data or typeof(typeId) ~= "string" or not Config.PetsById[typeId] or throttled(player) then
			return
		end
		local matching = {}
		for uid, pet in data.Pets do
			if pet.T == typeId and pet.G and not pet.R and not pet.L then
				table.insert(matching, uid)
			end
		end
		if #matching < Config.RainbowCraftAmount then
			notify(player, `You need {Config.RainbowCraftAmount} unlocked GOLDEN pets of the same kind!`, RED)
			return
		end
		table.sort(matching, function(a, b)
			return (table.find(data.Equipped, a) and 1 or 0) < (table.find(data.Equipped, b) and 1 or 0)
		end)
		local wasEquipped = false
		for i = 1, Config.RainbowCraftAmount do
			wasEquipped = wasEquipped or table.find(data.Equipped, matching[i]) ~= nil
			data.Pets[matching[i]] = nil
		end
		cleanEquipped(player, data)
		local uid = self:AddPet(player, typeId, false, true)
		if wasEquipped and uid and not table.find(data.Equipped, uid) and #data.Equipped < self:GetMaxEquip(player) then
			table.insert(data.Equipped, uid)
		end
		local def = Config.PetsById[typeId]
		notify(player, `You crafted a RAINBOW {def.Name}!`, RAINBOW)
		net.SendAnnounce(`{player.DisplayName} crafted a RAINBOW {def.Name}!`, RAINBOW)
		self:Sync(player)
		progress():Track(player, "Rainbow", 1)
	end)

	-- Sperren: gesperrte Haustiere koennen nicht geloescht oder verbraucht werden
	net.ToggleLock.OnServerEvent:Connect(function(player, uid)
		local data = services.DataService:Get(player)
		if not data or typeof(uid) ~= "string" or not data.Pets[uid] or throttled(player) then
			return
		end
		local pet = data.Pets[uid]
		pet.L = if pet.L then nil else true
		self:Sync(player)
	end)

	-- Schnellreise in eine freigeschaltete Zone
	net.Teleport.OnServerEvent:Connect(function(player, index)
		local data = services.DataService:Get(player)
		if not data or typeof(index) ~= "number" or index ~= index or index % 1 ~= 0 then
			return
		end
		if index < 1 or index > data.Zone or not Config.Zones[index] then
			notify(player, "Unlock that zone first!", RED)
			return
		end
		if os.clock() - (lastTeleport[player] or 0) < Config.TeleportCooldown then
			notify(player, "Wait a moment before travelling again.", RED)
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			return
		end
		lastTeleport[player] = os.clock()
		character:PivotTo(services.WorldService.SpawnCFrame(index))
		notify(player, `Welcome to {Config.Zones[index].Name}!`, GREEN)
	end)

	net.SetAutoHatch.OnServerEvent:Connect(function(player, enabled)
		if enabled == true and not services.MonetizationService:HasPass(player, "AutoHatch") then
			services.MonetizationService:PromptPass(player, "AutoHatch")
			return
		end
		autoHatch[player] = if enabled == true then true else nil
		player:SetAttribute("AutoHatch", enabled == true)
	end)

	net.RequestRebirth.OnServerEvent:Connect(function(player)
		self:Rebirth(player)
	end)

	-- Auto-Hatch: naechstes Ei in Reichweite oeffnen (mit Triple Hatch gleich 3)
	task.spawn(function()
		while true do
			task.wait(Config.AutoHatchInterval)
			for player in autoHatch do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then
					continue
				end
				for _, zone in services.WorldService.Zones do
					if zone.EggPart and (root.Position - zone.EggPart.Position).Magnitude <= Config.EggRange then
						local amount = if services.MonetizationService:HasPass(player, "TripleHatch") then 3 else 1
						task.spawn(self.Hatch, self, player, zone.Egg.Id, amount, true)
						break
					end
				end
			end
		end
	end)

	-- Gesperrte Zonen: der Client laesst nur freigeschaltete Tore durch, der Server prueft nach
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local data = services.DataService:Get(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if data and root and services.WorldService.ZoneAt(root.Position.X) > data.Zone then
					player.Character:PivotTo(services.WorldService.SpawnCFrame(data.Zone))
				end
			end
		end
	end)
end

function PetService:OnPlayerRemoving(player: Player)
	lastHatch[player] = nil
	autoHatch[player] = nil
	lastRemote[player] = nil
	lastTeleport[player] = nil
end

-- Wird von der Monetarisierung genutzt, falls ein Vorteil das Inventar betrifft
function PetService:Refresh(player: Player)
	self:Sync(player)
end

return PetService
