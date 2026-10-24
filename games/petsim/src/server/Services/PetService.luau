-- Haustiere: Inventar, Ausruesten, Eier schluepfen, goldene Haustiere, Tore, Rebirth und taegliches Geschenk.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local PetService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)

local lastHatch = {} -- [Player] = os.clock()
local autoHatch = {} -- [Player] = true
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
		power += Config.PetPower(pet.T, pet.G)
		table.insert(visible, pet.T .. (if pet.G then ":g" else ""))
	end
	player:SetAttribute("Power", power)
	player:SetAttribute("EquippedPets", table.concat(visible, ","))
	player:SetAttribute("MaxEquip", self:GetMaxEquip(player))
	player:SetAttribute("Storage", self:GetStorage(player))
	self.Services.Net.Inventory:FireClient(player, data.Pets, data.Equipped)
end

function PetService:AddPet(player: Player, typeId: string, golden: boolean?): string?
	local data = self.Services.DataService:Get(player)
	if not data or not Config.PetsById[typeId] then
		return nil
	end
	local uid = tostring(data.NextPetId)
	data.NextPetId += 1
	data.Pets[uid] = { T = typeId, G = golden == true }
	-- Freier Platz? Dann gleich ausruesten (macht Neue sofort staerker)
	if #data.Equipped < self:GetMaxEquip(player) then
		table.insert(data.Equipped, uid)
	end
	return uid
end

local function equipBest(player: Player, data)
	local list = {}
	for uid, pet in data.Pets do
		table.insert(list, { Uid = uid, Power = Config.PetPower(pet.T, pet.G) })
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

-- Bezahlt wird nur mit Muenzen. Gibt true zurueck, wenn geschluepft wurde.
function PetService:Hatch(player: Player, eggId: string, amount: number): boolean
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
		notify(player, "Your pet storage is full! Delete or craft pets.", RED)
		return false
	end
	amount = math.min(amount, free)
	local cost = egg.Price * amount
	if data.Coins < cost then
		notify(player, `You need {Format.Coins(cost)}!`, RED)
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
	services.DataService:UpdateAttributes(player)
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
		data.LastDaily = today()
		local amount = self:EggValue(player, Config.DailyEggs)
		services.DataService:AddCoins(player, amount)
		notify(player, `Daily gift: +{Format.Coins(amount)}!`, GOLD)
	end)

	net.ToggleEquip.OnServerEvent:Connect(function(player, uid)
		local data = services.DataService:Get(player)
		if not data or typeof(uid) ~= "string" or not data.Pets[uid] then
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
		if data then
			equipBest(player, data)
			self:Sync(player)
		end
	end)

	net.DeletePets.OnServerEvent:Connect(function(player, uids)
		local data = services.DataService:Get(player)
		if not data or typeof(uids) ~= "table" then
			return
		end
		local removed = 0
		for _, uid in uids do
			-- Das letzte Haustier bleibt immer
			if typeof(uid) == "string" and data.Pets[uid] and countPets(data) > 1 then
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
		if not data or typeof(typeId) ~= "string" or not Config.PetsById[typeId] then
			return
		end
		local matching = {}
		for uid, pet in data.Pets do
			if pet.T == typeId and not pet.G then
				table.insert(matching, uid)
			end
		end
		if #matching < Config.GoldenCraftAmount then
			notify(player, `You need {Config.GoldenCraftAmount} of the same pet!`, RED)
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
						task.spawn(self.Hatch, self, player, zone.Egg.Id, amount)
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
end

-- Wird von der Monetarisierung genutzt, falls ein Vorteil das Inventar betrifft
function PetService:Refresh(player: Player)
	self:Sync(player)
end

return PetService
