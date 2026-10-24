-- Gegenstaende: Erzeugen, Werte, Namen und die Gesamtwerte eines Helden.
-- Wird vom Server (Beute) und vom Client (Anzeige, Vergleich) benutzt.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Items = {}

export type Affix = { Key: string, Value: number }
export type Item = {
	Id: string,
	Slot: string,
	Rarity: number,
	Level: number,
	Prefix: number,
	Affixes: { Affix },
	Power: string?,
	Plus: number,
	Locked: boolean?,
	Unique: string?,
}

-- Grundwerte je Platz: Faktoren fuer Schaden, Leben, Ruestung
local SLOT_BASE = {
	Weapon = { Damage = 1 },
	Helmet = { Health = 1, Armor = 1 },
	Armor = { Health = 1.5, Armor = 1.5 },
	Boots = { Health = 0.8, Armor = 0.8 },
	Amulet = { Jewel = 1, Health = 0.5 },
	Ring = { Jewel = 1, Crit = 2 },
}

local function plusFactor(item: Item): number
	return 1 + Config.PlusBonus * (item.Plus or 0)
end

function Items.BaseStats(item: Item): { [string]: number }
	local base = SLOT_BASE[item.Slot]
	local m = Config.Rarities[item.Rarity].Mult * plusFactor(item)
	local level = item.Level
	local stats = {}
	if base.Damage then
		stats.Damage = (5 + 2.4 * level) * m * base.Damage
	end
	if base.Jewel then
		stats.Damage = (2 + 1 * level) * m
	end
	if base.Health then
		stats.Health = (12 + 5 * level) * m * base.Health
	end
	if base.Armor then
		stats.Armor = (2 + 1.2 * level) * m * base.Armor
	end
	if base.Crit then
		stats.Crit = base.Crit
	end
	for key, value in stats do
		stats[key] = if key == "Crit" then value else math.floor(value + 0.5)
	end
	return stats
end

-- Ein Wert fuer "besser/schlechter"-Vergleiche
function Items.Power(item: Item): number
	local m = Config.Rarities[item.Rarity].Mult * plusFactor(item)
	local score = (item.Level * 10 + 10) * m + #item.Affixes * (item.Level + 5) * 2
	if item.Power then
		score += 60 + item.Level * 3
	end
	return math.floor(score)
end

function Items.Noun(slot: string, classKey: string?): string
	local class = Config.Classes[classKey or "Knight"] or Config.Classes.Knight
	return class.Nouns[slot] or Config.SlotNouns[slot] or slot
end

function Items.DisplayName(item: Item, classKey: string?): string
	local noun = Items.Noun(item.Slot, classKey)
	if item.Unique then
		return item.Unique .. " " .. noun
	end
	local name
	if item.Power then
		local title = Config.Powers[item.Power].Title
		name = (if item.Rarity >= 6 then "Celestial " .. title else title) .. " " .. noun
	else
		local list = Config.Prefixes[item.Rarity]
		name = (list[item.Prefix] or list[1] or "") .. " " .. noun
	end
	if (item.Plus or 0) > 0 then
		name ..= " +" .. item.Plus
	end
	return name
end

function Items.AffixText(affix: Affix): string
	local def = Config.AffixesByKey[affix.Key]
	local value = if affix.Value >= 10 then math.floor(affix.Value + 0.5) else math.floor(affix.Value * 10 + 0.5) / 10
	if def.Name:sub(1, 1) == "%" then
		return `+{value}{def.Name}`
	end
	return `+{value} {def.Name}`
end

---------------------------------------------------------------- Erzeugen (Server)

-- Seltenheit wuerfeln. luck vergroessert die Chance auf Rare und besser, minRarity hebt den Boden an.
function Items.RollRarity(rng: Random, luck: number, allowMythic: boolean, minRarity: number?): number
	local total = 0
	local weights = {}
	for index, rarity in Config.Rarities do
		local weight = rarity.Weight
		if index >= 3 then
			weight *= luck
		end
		if rarity.NightmareOnly and not allowMythic then
			weight = 0
		end
		if minRarity and index < minRarity then
			weight = 0
		end
		weights[index] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then
			return index
		end
	end
	return minRarity or 1
end

local function rollAffix(rng: Random, def, level: number): number
	local value = rng:NextNumber(def.Min, def.Max) + def.PerLevel * level
	return if def.PerLevel > 0 then math.floor(value + 0.5) else math.floor(value * 10 + 0.5) / 10
end

function Items.Generate(rng: Random, options: { Slot: string?, Rarity: number, Level: number, Power: string?, Unique: string? }): Item
	local slot = options.Slot or Config.Slots[rng:NextInteger(1, #Config.Slots)]
	local rarity = math.clamp(options.Rarity, 1, #Config.Rarities)
	local level = math.clamp(math.floor(options.Level), 1, Config.MaxItemLevel)
	local def = Config.Rarities[rarity]
	local pool = table.clone(Config.Affixes)
	local affixes = {}
	for _ = 1, def.Affixes do
		if #pool == 0 then
			break
		end
		local pick = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(affixes, { Key = pick.Key, Value = rollAffix(rng, pick, level) })
	end
	local power = options.Power
	if def.Power and not power then
		power = Config.PowerOrder[rng:NextInteger(1, #Config.PowerOrder)]
	end
	local prefixes = Config.Prefixes[rarity]
	return {
		Id = HttpService:GenerateGUID(false):gsub("-", ""):sub(1, 10),
		Slot = slot,
		Rarity = rarity,
		Level = level,
		Prefix = if #prefixes > 0 then rng:NextInteger(1, #prefixes) else 1,
		Affixes = affixes,
		Power = power,
		Plus = 0,
		Unique = options.Unique,
	}
end

---------------------------------------------------------------- Gesamtwerte

export type Stats = {
	Damage: number,
	Health: number,
	Armor: number,
	Crit: number,
	CritDamage: number,
	AttackSpeed: number,
	MoveSpeed: number,
	GoldFind: number,
	LifeOnKill: number,
	Cooldown: number,
	Powers: { [string]: boolean },
	GearScore: number,
}

function Items.TotalStats(classKey: string, level: number, equipped: { Item }): Stats
	local class = Config.Classes[classKey] or Config.Classes.Knight
	local stats: Stats = {
		Damage = Config.BaseDamage(level),
		Health = Config.BaseHealth(class.Health, level),
		Armor = class.Armor + level,
		Crit = Config.BaseCrit,
		CritDamage = Config.BaseCritDamage,
		AttackSpeed = 0,
		MoveSpeed = 0,
		GoldFind = 0,
		LifeOnKill = 0,
		Cooldown = 0,
		Powers = {},
		GearScore = 0,
	}
	for _, item in equipped do
		for key, value in Items.BaseStats(item) do
			(stats :: any)[key] += value
		end
		for _, affix in item.Affixes do
			(stats :: any)[affix.Key] += affix.Value
		end
		if item.Power then
			stats.Powers[item.Power] = true
		end
		stats.GearScore += Items.Power(item)
	end
	if stats.Powers.Swiftness then
		stats.AttackSpeed += 15
		stats.MoveSpeed += 15
	end
	for key, cap in Config.StatCaps do
		(stats :: any)[key] = math.min((stats :: any)[key], cap)
	end
	stats.Damage = math.floor(stats.Damage + 0.5)
	stats.Health = math.floor(stats.Health + 0.5)
	stats.Armor = math.floor(stats.Armor + 0.5)
	return stats
end

return Items
