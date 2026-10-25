-- Beute und Inventar: Drops (jeder Spieler wuerfelt fuer sich, kein Streit um Loot), Anlegen,
-- Zerlegen in Splitter, Sperren, "Bestes anlegen" und die Schmiede (+1 bis +10).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

local LootService = { Services = nil :: any }

local rng = Random.new()
local dirty = {} -- [Player] = true: Inventar muss an den Client

function LootService:Init(services)
	self.Services = services
end

function LootService:Capacity(player: Player): number
	return Config.BaseInventory + (if player:GetAttribute("Pass_Backpack") then Config.BackpackBonus else 0)
end

function LootService:SendInventory(player: Player)
	dirty[player] = nil
	local data = self.Services.DataService:Get(player)
	if data then
		self.Services.Net.Sync:FireClient(player, "Inventory", { Items = data.Inventory, Equipped = data.Equipped, Capacity = self:Capacity(player) })
	end
end

local function find(data, id: any)
	for index, item in data.Inventory do
		if item.Id == id then
			return item, index
		end
	end
	return nil, nil
end

local function isEquipped(data, item): boolean
	return data.Equipped[item.Slot] == item.Id
end

local function equippedIn(data, slot: string)
	local id = data.Equipped[slot]
	return id and find(data, id)
end

local function salvage(player: Player, data, item): (number, number)
	local shards, gold = Config.SalvageValue(item.Level, item.Rarity)
	data.Shards += shards
	data.Gold += gold
	return shards, gold
end

---------------------------------------------------------------- Beute vergeben

local function luckFor(player: Player, base: number): number
	local luck = base
	if player:GetAttribute("Pass_Luck") and not player:GetAttribute("RandomRestricted") then
		luck *= Config.LuckMultiplier
	end
	return luck
end

-- Legt einen Gegenstand ins Inventar (oder zerlegt ihn automatisch) und zeigt den Drop an
function LootService:GiveItem(player: Player, item: Items.Item, position: Vector3?): boolean
	local services = self.Services
	local data = services.DataService:Get(player)
	if not data then
		return false
	end
	local run = services.DungeonService:GetRun(player)
	local current = equippedIn(data, item.Slot)
	local better = current == nil or Items.Power(item) > Items.Power(current)
	local name = Items.DisplayName(item, data.Class)
	local rarity = Config.Rarities[item.Rarity]
	local kept = true
	if item.Rarity <= data.AutoSalvage and not better then
		local shards = salvage(player, data, item)
		services.Net.Effect:FireClient(player, "Salvaged", { Name = name, Rarity = item.Rarity, Shards = shards })
		kept = false
	elseif #data.Inventory >= self:Capacity(player) then
		local shards = salvage(player, data, item)
		services.Net.SendNotify(player, `Bag full! {name} was salvaged for {shards} shards.`, Color3.fromRGB(255, 120, 90))
		services.MonetizationService:Offer(player, "Pass_Backpack", "Your bag is full! Get +100 slots forever?")
		kept = false
	else
		table.insert(data.Inventory, item)
		-- Einstellung "Auto-equip upgrades": bessere Teile sofort anlegen
		if better and services.ProgressService:Setting(player, "AutoEquip") then
			data.Equipped[item.Slot] = item.Id
			services.HeroService:RefreshStats(player)
		end
	end
	if position then
		services.Net.Effect:FireClient(player, "Loot", { Position = position, Rarity = item.Rarity, Name = name, Better = better and kept })
	end
	if item.Rarity >= 5 then
		data.LegendaryFound += 1
	end
	if item.Rarity >= 6 then
		data.MythicFound += 1
	end
	if item.Rarity >= 3 then
		services.ProgressService:Track(player, "FindRare")
	end
	if run then
		local entry = services.DungeonService.Stats(run, player)
		entry.Items += 1
		if not entry.Best or item.Rarity > entry.Best.Rarity then
			entry.Best = { Name = name, Rarity = item.Rarity }
		end
	end
	if rarity.Announce then
		services.Net.SendAnnounce(`{player.DisplayName} found {rarity.Name} {name}!`, rarity.Color)
	end
	services.DataService:UpdateAttributes(player)
	dirty[player] = true
	return kept
end

-- options: MinRarity, Level, Luck, Rarity (fest), Slot
function LootService:DropItem(player: Player, run, options, position: Vector3?)
	local allowMythic = run ~= nil and Config.Difficulties[run.Difficulty].Mythic == true
	local rarity = options.Rarity or Items.RollRarity(rng, luckFor(player, options.Luck or 1), allowMythic, options.MinRarity)
	local level = (options.Level or (run and run.Level) or 1) + rng:NextInteger(-1, 2)
	local item = Items.Generate(rng, { Slot = options.Slot, Rarity = rarity, Level = level })
	self:GiveItem(player, item, position)
	return item
end

function LootService:RollKillDrops(player: Player, run, state, position: Vector3)
	local difficulty = Config.Difficulties[run.Difficulty]
	local luck = difficulty.Loot
	if state.Boss then
		local count = Config.BossDrops + (run.Difficulty - 1)
		for i = 1, count do
			self:DropItem(player, run, { MinRarity = if i == 1 then 4 else 3, Level = run.Level + 2, Luck = luck * 3 }, position + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)))
		end
		if run.Blessed then
			self:DropItem(player, run, { Rarity = 5, Level = run.Level + 2 }, position)
		end
	elseif state.Elite then
		for _ = 1, rng:NextInteger(Config.EliteDrops[1], Config.EliteDrops[2]) do
			self:DropItem(player, run, { MinRarity = 2, Level = run.Level + 1, Luck = luck * 1.5 }, position)
		end
	elseif state.Treasure then
		-- Schatz-Kobold: garantiert Rare oder besser
		self:DropItem(player, run, { MinRarity = 3, Level = run.Level + 1, Luck = luck * 2 }, position)
	elseif not state.Minion and rng:NextNumber() < Config.DropChance then
		self:DropItem(player, run, { Luck = luck }, position)
	end
	-- Splitter als kleiner Bonus
	if rng:NextNumber() < 0.25 or state.Elite or state.Boss or state.Treasure then
		self.Services.DataService:AddShards(player, (if state.Boss then 25 elseif state.Elite or state.Treasure then 6 else 1) * run.Difficulty)
	end
end

---------------------------------------------------------------- Aktionen

function LootService:Equip(player: Player, id: any): boolean
	local data = self.Services.DataService:Get(player)
	local item = data and find(data, id)
	if not item then
		return false
	end
	data.Equipped[item.Slot] = item.Id
	self.Services.HeroService:RefreshStats(player)
	self:SendInventory(player)
	self.Services.ProgressService:Track(player, "Equip")
	return true
end

function LootService:EquipBest(player: Player): number
	local data = self.Services.DataService:Get(player)
	if not data then
		return 0
	end
	local changed = 0
	for _, slot in Config.Slots do
		local best = equippedIn(data, slot)
		for _, item in data.Inventory do
			if item.Slot == slot and (not best or Items.Power(item) > Items.Power(best)) then
				best = item
			end
		end
		if best and data.Equipped[slot] ~= best.Id then
			data.Equipped[slot] = best.Id
			changed += 1
		end
	end
	self.Services.HeroService:RefreshStats(player)
	self:SendInventory(player)
	if changed > 0 then
		self.Services.ProgressService:Track(player, "Equip")
	end
	return changed
end

function LootService:Salvage(player: Player, ids: { any }): (number, number)
	local data = self.Services.DataService:Get(player)
	if not data or typeof(ids) ~= "table" then
		return 0, 0
	end
	local count, shards = 0, 0
	-- Nicht mehr Ids pruefen, als die Tasche ueberhaupt fassen kann (Schutz vor riesigen Listen)
	local checked = 0
	for _, id in ids do
		checked += 1
		if checked > Config.BaseInventory + Config.BackpackBonus then
			break
		end
		local item, index = find(data, id)
		if item and not item.Locked and not isEquipped(data, item) then
			shards += salvage(player, data, item)
			table.remove(data.Inventory, index)
			count += 1
		end
	end
	data.Salvaged += count
	self.Services.DataService:UpdateAttributes(player)
	self:SendInventory(player)
	if count > 0 then
		self.Services.ProgressService:Track(player, "Salvage", count)
	end
	return count, shards
end

function LootService:SalvageUpTo(player: Player, maxRarity: number): (number, number)
	local data = self.Services.DataService:Get(player)
	if not data then
		return 0, 0
	end
	local ids = {}
	for _, item in data.Inventory do
		if item.Rarity <= maxRarity and not item.Locked and not isEquipped(data, item) then
			table.insert(ids, item.Id)
		end
	end
	return self:Salvage(player, ids)
end

function LootService:Enhance(player: Player, slot: string): (boolean, string?)
	local data = self.Services.DataService:Get(player)
	local item = data and equippedIn(data, slot)
	if not item then
		return false, "Equip an item in this slot first."
	end
	if item.Plus >= Config.MaxPlus then
		return false, "Already at maximum (+10)."
	end
	local gold, shards = Config.EnhanceCost(item.Level, item.Plus, item.Rarity)
	if data.Gold < gold or data.Shards < shards then
		return false, "Not enough gold or shards."
	end
	data.Gold -= gold
	data.Shards -= shards
	item.Plus += 1
	data.BestPlus = math.max(data.BestPlus, item.Plus)
	self.Services.HeroService:RefreshStats(player)
	self:SendInventory(player)
	self.Services.ProgressService:Track(player, "Enhance")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		self.Services.Net.Effect:FireClient(player, "Enhance", { Position = root.Position, Plus = item.Plus })
	end
	return true, nil
end

-- Erste Ausruestung fuer neue Helden
function LootService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	if #data.Inventory == 0 then
		for _, slot in { "Weapon", "Armor" } do
			local item = Items.Generate(rng, { Slot = slot, Rarity = 1, Level = 1 })
			table.insert(data.Inventory, item)
			data.Equipped[slot] = item.Id
		end
	end
	-- Aufraeumen: angelegte Ids, die es nicht mehr gibt
	for slot, id in data.Equipped do
		if not find(data, id) then
			data.Equipped[slot] = nil
		end
	end
	self:SendInventory(player)
end

function LootService:Start()
	local Net = self.Services.Net
	Net.Handle("Equip", function(player, id)
		return self:Equip(player, id)
	end)
	Net.Handle("EquipBest", function(player)
		return true, self:EquipBest(player)
	end)
	Net.Handle("Salvage", function(player, ids)
		return true, select(2, self:Salvage(player, ids))
	end)
	Net.Handle("SalvageUpTo", function(player, rarity)
		local value = self.Services.ProgressService.WholeNumber(rarity)
		if not value then
			return false
		end
		local count, shards = self:SalvageUpTo(player, math.clamp(value, 1, 4))
		return count, shards
	end)
	Net.Handle("Lock", function(player, id)
		local data = self.Services.DataService:Get(player)
		local item = data and find(data, id)
		if not item then
			return false
		end
		item.Locked = not item.Locked or nil
		self:SendInventory(player)
		return true
	end)
	Net.Handle("Enhance", function(player, slot)
		if typeof(slot) ~= "string" then
			return false
		end
		return self:Enhance(player, slot)
	end)
	Net.Handle("SetAutoSalvage", function(player, level)
		local data = self.Services.DataService:Get(player)
		-- NaN wuerde gespeichert und jedes weitere Speichern scheitern lassen
		local value = self.Services.ProgressService.WholeNumber(level)
		if not data or not value then
			return false
		end
		data.AutoSalvage = math.clamp(value, 0, 3)
		self.Services.DataService:UpdateAttributes(player)
		return true
	end)
	Net.Handle("GetInventory", function(player)
		self:SendInventory(player)
		return true
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			for player in dirty do
				if player.Parent then
					self:SendInventory(player)
				else
					dirty[player] = nil
				end
			end
		end
	end)
end

function LootService:OnPlayerRemoving(player: Player)
	dirty[player] = nil
end

return LootService
