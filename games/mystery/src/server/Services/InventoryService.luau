-- Skins: Kisten (nur Spiel-Muenzen, Quoten sichtbar, PolicyService beachtet), Direkt-Shop,
-- Schmiede (5 Duplikate -> 1 frei gewaehlter Skin der naechsten Seltenheit) und Ausruesten.
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local InventoryService = { Services = nil :: any }

local C = Config.Colors

local function validKind(kind: any): boolean
	return typeof(kind) == "string" and Config.ItemLists[kind] ~= nil
end

function InventoryService:Owns(player: Player, kind: string, id: string): boolean
	local data = self.Services.DataService:Get(player)
	return data ~= nil and (data.Inventory[kind][id] or 0) > 0
end

function InventoryService:Grant(player: Player, kind: string, id: string, count: number)
	local data = self.Services.DataService:Get(player)
	if not data or not Config.GetItem(kind, id) then
		return
	end
	local inventory = data.Inventory[kind]
	inventory[id] = (inventory[id] or 0) + count
	self.Services.ProgressService:Refresh(player)
end

function InventoryService:RandomOfRarity(rarity: string): (string?, string?)
	local pool = {}
	for _, kind in Config.ItemKinds do
		for _, item in Config.ItemLists[kind] do
			if item.Rarity == rarity and not item.Exclusive and item.Id ~= "Default" then
				table.insert(pool, { kind, item.Id })
			end
		end
	end
	if #pool == 0 then
		return nil, nil
	end
	local pick = pool[math.random(1, #pool)]
	return pick[1], pick[2]
end

-- Paid Random Items: Muenzen kann man mit Robux kaufen, deshalb Kisten nur, wenn die Richtlinie es erlaubt
function InventoryService:CheckPolicy(player: Player)
	local ok, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	local allowed = true
	if ok and policy and policy.ArePaidRandomItemsRestricted then
		allowed = false
	end
	player:SetAttribute("CratesAllowed", allowed)
end

function InventoryService:OpenCrate(player: Player, crateId: any)
	local crate
	for _, c in Config.Crates do
		if c.Id == crateId then
			crate = c
		end
	end
	if not crate then
		return { Ok = false, Error = "Unknown crate" }
	end
	if player:GetAttribute("CratesAllowed") == false then
		return { Ok = false, Error = "Crates are not available in your region. Use the Direct Shop!" }
	end
	if not self.Services.ProgressService:SpendCoins(player, crate.Price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	local odds = Config.CrateOdds(crate.Id)
	local roll = math.random()
	local pick = odds[#odds]
	for _, entry in odds do
		roll -= entry.Chance
		if roll <= 0 then
			pick = entry
			break
		end
	end
	self:Grant(player, pick.Kind, pick.Id, 1)
	self.Services.ProgressService:Track(player, "Crate", 1)
	self.Services.ProgressService:AddStat(player, "CratesOpened", 1)
	local item = Config.GetItem(pick.Kind, pick.Id)
	if item and (item.Rarity == "Godly" or item.Rarity == "Legendary") then
		self.Services.Net.SendAnnounce(`{player.DisplayName} unboxed {string.upper(item.Rarity)} {item.Name}!`, Config.Rarities[Config.RarityIndex[item.Rarity]].Color)
	end
	return { Ok = true, Kind = pick.Kind, Id = pick.Id }
end

function InventoryService:BuyDirect(player: Player, kind: any, id: any)
	if not validKind(kind) or typeof(id) ~= "string" then
		return { Ok = false }
	end
	local item = Config.GetItem(kind, id)
	if not item or item.Exclusive or item.Rarity == "Midnight" or item.Id == "Default" then
		return { Ok = false, Error = "Not for sale" }
	end
	local price = Config.Rarities[Config.RarityIndex[item.Rarity]].Price
	if not self.Services.ProgressService:SpendCoins(player, price) then
		return { Ok = false, Error = "Not enough coins" }
	end
	self:Grant(player, kind, id, 1)
	return { Ok = true }
end

-- Schmiede: 5 Duplikate (Anzahl ueber 1) derselben Seltenheit und Art -> gewaehlter Skin eine Stufe hoeher
function InventoryService:Forge(player: Player, kind: any, rarity: any, targetId: any)
	if not validKind(kind) or typeof(rarity) ~= "string" or typeof(targetId) ~= "string" then
		return { Ok = false }
	end
	local data = self.Services.DataService:Get(player)
	local index = Config.RarityIndex[rarity]
	local target = Config.GetItem(kind, targetId)
	if not data or not index or not target or Config.RarityIndex[target.Rarity] ~= index + 1 or target.Exclusive or target.Rarity == "Midnight" then
		return { Ok = false, Error = "Pick a skin one rarity higher" }
	end
	local inventory = data.Inventory[kind]
	local spare = 0
	for id, count in inventory do
		local item = Config.GetItem(kind, id)
		if item and item.Rarity == rarity then
			spare += math.max(0, count - 1)
		end
	end
	if spare < Config.ForgeCost then
		return { Ok = false, Error = `You need {Config.ForgeCost} duplicate {rarity} skins` }
	end
	local need = Config.ForgeCost
	for id, count in inventory do
		local item = Config.GetItem(kind, id)
		if item and item.Rarity == rarity and need > 0 then
			local use = math.min(count - 1, need)
			inventory[id] = count - use
			need -= use
		end
	end
	self:Grant(player, kind, targetId, 1)
	self.Services.ProgressService:AddStat(player, "Forged", 1)
	self.Services.Net.SendNotify(player, `Forged {target.Name}!`, C.Moon)
	return { Ok = true }
end

function InventoryService:Equip(player: Player, slot: any, id: any)
	local data = self.Services.DataService:Get(player)
	if not data or typeof(slot) ~= "string" or typeof(id) ~= "string" then
		return { Ok = false }
	end
	local kind = if slot == "Pet2" then "Pet" else slot
	if not validKind(kind) then
		return { Ok = false }
	end
	if id ~= "" and not self:Owns(player, kind, id) then
		return { Ok = false, Error = "You don't own that" }
	end
	if id == "" and (kind == "Knife" or kind == "Gun") then
		id = "Default"
	end
	data.Equipped[slot] = id
	self.Services.ProgressService:UpdateNameplate(player)
	self.Services.ProgressService:Refresh(player)
	return { Ok = true }
end

function InventoryService:Init(services)
	self.Services = services
	local Net = services.Net
	Net.Handle("OpenCrate", function(player, crateId)
		return self:OpenCrate(player, crateId)
	end)
	Net.Handle("BuyDirect", function(player, kind, id)
		return self:BuyDirect(player, kind, id)
	end)
	Net.Handle("Forge", function(player, kind, rarity, targetId)
		return self:Forge(player, kind, rarity, targetId)
	end)
	Net.Handle("Equip", function(player, slot, id)
		return self:Equip(player, slot, id)
	end)
end

return InventoryService
