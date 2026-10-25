-- Gemeinsame Regeln fuer alles neben der Geschichte: Tagesaufgaben, Erfolge mit Titeln, Bestiarium-Belohnungen,
-- Gluecksrad (nur gratis, keine Robux), Spielzeit-Geschenke, Bestien-Hort und Einstellungen.
-- Nutzt keine Roblox-Dienste, damit Server, Client und Luau-Tests dieselben Regeln verwenden.

local Progress = {}

---------------------------------------------------------------- Tagesaufgaben

Progress.QuestsPerDay = 3

-- Text mit %s = Ziel. Goals = drei Schwierigkeiten (Belohnung waechst mit der Stufe).
Progress.Quests = {
	Win = { Text = "Win %s battles", Goals = { 3, 5, 8 } },
	Catch = { Text = "Catch %s beasts", Goals = { 2, 3, 5 } },
	Encounter = { Text = "Meet %s wild beasts in tall grass", Goals = { 5, 8, 12 } },
	Coins = { Text = "Earn %s coins", Goals = { 1_000, 2_500, 5_000 } },
	Level = { Text = "Level up your beasts %s times", Goals = { 3, 5, 8 } },
	Shop = { Text = "Buy %s items at a Beast Mart", Goals = { 3, 5, 10 } },
	Minutes = { Text = "Play for %s minutes", Goals = { 10, 20, 30 } },
}
Progress.QuestOrder = { "Win", "Catch", "Encounter", "Coins", "Level", "Shop", "Minutes" }

local QUEST_REWARDS = {
	{ Coins = 600, Items = { Orb = 3 } },
	{ Coins = 1_200, Items = { GreatOrb = 2 } },
	{ Coins = 2_000, Items = { SuperPotion = 2, GreatOrb = 2 } },
}
Progress.QuestBonus = { Coins = 1_500, Items = { GreatOrb = 3, Revive = 1 } }
Progress.QuestFinishFallbackCoins = 3_000 -- Quest Finisher, wenn heute schon alles erledigt ist

function Progress.QuestReward(tier: number)
	return QUEST_REWARDS[math.clamp(tier, 1, #QUEST_REWARDS)]
end

local function withCommas(n: number): string
	local text = tostring(math.floor(n))
	local result = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (result:gsub("^,", ""))
end

function Progress.QuestText(kind: string, goal: number): string
	local def = Progress.Quests[kind]
	if not def then
		return "?"
	end
	return string.format(def.Text, withCommas(goal))
end

-- Feste Aufgaben pro Spieler und Tag (wer neu beitritt, bekommt dieselben wieder)
function Progress.MakeQuests(day: number, userId: number)
	local rng = Random.new(day * 7919 + userId % 1_000_003)
	local kinds = table.clone(Progress.QuestOrder)
	local list = {}
	for _ = 1, Progress.QuestsPerDay do
		local kind = table.remove(kinds, rng:NextInteger(1, #kinds)) :: string
		local def = Progress.Quests[kind]
		local tier = rng:NextInteger(1, #def.Goals)
		table.insert(list, { K = kind, T = tier, G = def.Goals[tier], P = 0, C = false })
	end
	return { Day = day, List = list, Bonus = false }
end

---------------------------------------------------------------- Erfolge und Titel

-- Stat = Feld in den Spielerdaten oder im Kontext (Dex, Shiny, Legend, TopLevel). Flag = Story-Ereignis.
Progress.Achievements = {
	{ Id = "first_catch", Name = "First Catch", Desc = "Catch your first wild beast", Title = "Rookie Catcher", Coins = 300, Stat = "Caught", Min = 1 },
	{ Id = "dex10", Name = "Collector", Desc = "Catch 10 different beasts", Title = "Beast Collector", Coins = 1_000, Stat = "Dex", Min = 10 },
	{ Id = "dex25", Name = "Scholar", Desc = "Catch 25 different beasts", Title = "Bestiary Scholar", Coins = 3_000, Stat = "Dex", Min = 25 },
	{ Id = "dex50", Name = "Completionist", Desc = "Catch all 50 beasts", Title = "Bestiary Master", Coins = 20_000, Stat = "Dex", Min = 50 },
	{ Id = "badge1", Name = "Challenger", Desc = "Earn your first arena badge", Title = "Arena Challenger", Coins = 500, Stat = "Crests", Min = 1 },
	{ Id = "badge4", Name = "Halfway There", Desc = "Earn 4 arena badges", Title = "Badge Hunter", Coins = 2_000, Stat = "Crests", Min = 4 },
	{ Id = "badge8", Name = "All Eight", Desc = "Earn all 8 arena badges", Title = "Ace Tamer", Coins = 5_000, Stat = "Crests", Min = 8 },
	{ Id = "champion", Name = "Champion", Desc = "Defeat Champion Maximus", Title = "Champion", Coins = 10_000, Flag = "champion" },
	{ Id = "prismatic", Name = "Shimmer", Desc = "Own a PRISMATIC beast", Title = "Prism Seeker", Coins = 3_000, Stat = "Shiny", Min = 1 },
	{ Id = "legend", Name = "Myth Catcher", Desc = "Catch a legendary beast", Title = "Legend Tamer", Coins = 5_000, Stat = "Legend", Min = 1 },
	{ Id = "wins50", Name = "Battle Hardened", Desc = "Win 50 battles", Title = "Battle Hardened", Coins = 2_000, Stat = "Wins", Min = 50 },
	{ Id = "wins250", Name = "Arena Veteran", Desc = "Win 250 battles", Title = "Arena Veteran", Coins = 8_000, Stat = "Wins", Min = 250 },
	{ Id = "wave10", Name = "Gauntlet Runner", Desc = "Reach wave 10 in the Gauntlet", Title = "Gauntlet Runner", Coins = 2_500, Stat = "BestWave", Min = 10 },
	{ Id = "wave25", Name = "Gauntlet Legend", Desc = "Reach wave 25 in the Gauntlet", Title = "Gauntlet Legend", Coins = 8_000, Stat = "BestWave", Min = 25 },
	{ Id = "duelist", Name = "Duelist", Desc = "Collect 50 duel trophies", Title = "Duelist", Coins = 3_000, Stat = "Trophies", Min = 50 },
	{ Id = "level50", Name = "Power Trainer", Desc = "Raise a beast to level 50", Title = "Power Trainer", Coins = 4_000, Stat = "TopLevel", Min = 50 },
	{ Id = "quests25", Name = "Quest Hero", Desc = "Complete 25 daily quests", Title = "Quest Hero", Coins = 5_000, Stat = "QuestsDone", Min = 25 },
}
Progress.AchievementsById = {}
for index, achievement in Progress.Achievements do
	achievement.Order = index
	Progress.AchievementsById[achievement.Id] = achievement
end

-- Wert eines Erfolgs (fuer Fortschrittsbalken) und ob er erreicht ist
function Progress.AchievementValue(achievement, data, context): number
	if achievement.Flag then
		return if data.Flags and data.Flags[achievement.Flag] then 1 else 0
	end
	local value = context[achievement.Stat]
	if value == nil then
		value = data[achievement.Stat]
	end
	return if typeof(value) == "number" then value else 0
end

function Progress.AchievementDone(achievement, data, context): boolean
	return Progress.AchievementValue(achievement, data, context) >= (achievement.Min or 1)
end

-- Kontext-Werte, die nicht direkt in den Daten stehen
function Progress.Context(data)
	local dex = 0
	for _ in data.Dex or {} do
		dex += 1
	end
	local shiny, topLevel = 0, 0
	for _, entry in data.Beasts or {} do
		if entry.Sh then
			shiny += 1
		end
		topLevel = math.max(topLevel, entry.L or 0)
	end
	local legend = 0
	for flag in data.Flags or {} do
		if typeof(flag) == "string" and flag:sub(1, 4) == "leg_" then
			legend += 1
		end
	end
	return { Dex = dex, Shiny = shiny, Legend = legend, TopLevel = topLevel }
end

---------------------------------------------------------------- Bestiarium-Belohnungen

Progress.DexMilestones = {
	{ Key = "m5", Need = 5, Reward = { Coins = 500, Items = { Orb = 10 } } },
	{ Key = "m10", Need = 10, Reward = { Coins = 2_000, Items = { GreatOrb = 5 } } },
	{ Key = "m20", Need = 20, Reward = { Coins = 5_000, Items = { RoyalOrb = 3 } } },
	{ Key = "m30", Need = 30, Reward = { Coins = 8_000, Items = { Revive = 3, HyperPotion = 3 } } },
	{ Key = "m40", Need = 40, Reward = { Coins = 12_000, Items = { MasterOrb = 1 } } },
	{ Key = "m50", Need = 50, Reward = { Coins = 25_000, Items = { MasterOrb = 2 } } },
}

---------------------------------------------------------------- Gluecksrad (gratis alle 6 Stunden)

Progress.SpinCooldown = 6 * 3600
Progress.Wheel = {
	{ Text = "500 coins", Weight = 28, Reward = { Coins = 500 }, Color = Color3.fromRGB(242, 193, 78) },
	{ Text = "5 Catch Orbs", Weight = 20, Reward = { Items = { Orb = 5 } }, Color = Color3.fromRGB(150, 60, 170) },
	{ Text = "1,500 coins", Weight = 14, Reward = { Coins = 1_500 }, Color = Color3.fromRGB(255, 160, 60) },
	{ Text = "3 Potions", Weight = 12, Reward = { Items = { Potion = 3 } }, Color = Color3.fromRGB(90, 220, 120) },
	{ Text = "3 Great Orbs", Weight = 11, Reward = { Items = { GreatOrb = 3 } }, Color = Color3.fromRGB(70, 140, 255) },
	{ Text = "2 Super Potions", Weight = 7, Reward = { Items = { SuperPotion = 2 } }, Color = Color3.fromRGB(255, 120, 90) },
	{ Text = "Revive", Weight = 4.5, Reward = { Items = { Revive = 1 } }, Color = Color3.fromRGB(255, 220, 90) },
	{ Text = "2 Royal Orbs", Weight = 3, Reward = { Items = { RoyalOrb = 2 } }, Color = Color3.fromRGB(240, 190, 60) },
	{ Text = "MASTER ORB", Weight = 0.5, Reward = { Items = { MasterOrb = 1 } }, Color = Color3.fromRGB(255, 80, 160) },
}

-- roll = Zufallszahl 0..1 -> Feld des Rads
function Progress.RollWheel(roll: number): number
	local total = 0
	for _, slot in Progress.Wheel do
		total += slot.Weight
	end
	local value = math.clamp(roll, 0, 0.999999) * total
	for index, slot in Progress.Wheel do
		value -= slot.Weight
		if value < 0 then
			return index
		end
	end
	return #Progress.Wheel
end

---------------------------------------------------------------- Spielzeit-Geschenke (pro Besuch)

Progress.Gifts = {
	{ Key = "g1", Minutes = 5, Reward = { Coins = 300, Items = { Orb = 2 } } },
	{ Key = "g2", Minutes = 15, Reward = { Coins = 600, Items = { Potion = 2 } } },
	{ Key = "g3", Minutes = 30, Reward = { Coins = 1_200, Items = { GreatOrb = 2 } } },
	{ Key = "g4", Minutes = 60, Reward = { Coins = 2_500, Items = { RoyalOrb = 1, Revive = 1 } } },
}

---------------------------------------------------------------- Bestien-Hort (trainiert, waehrend man weg ist)

Progress.DaycareMaxMinutes = 8 * 60

function Progress.DaycareXp(level: number, minutes: number): number
	minutes = math.clamp(math.floor(minutes), 0, Progress.DaycareMaxMinutes)
	return minutes * (6 + level * 2)
end

---------------------------------------------------------------- Einstellungen

Progress.DefaultSettings = {
	Sfx = true, -- Klick- und Belohnungs-Sounds
	Follower = true, -- eigene Bestie laeuft hinter dir her (alle sehen sie)
	Others = true, -- Begleiter anderer Spieler anzeigen
	Effects = true, -- Gras-Rascheln und Schimmern
	Compass = true, -- Zielpfeil oben
}
Progress.SettingOrder = { "Sfx", "Follower", "Others", "Effects", "Compass" }
Progress.SettingText = {
	Sfx = { "Sound effects", "Clicks and reward sounds" },
	Follower = { "Beast follower", "Your lead beast walks with you" },
	Others = { "Other followers", "Show other players' beasts" },
	Effects = { "World effects", "Grass leaves and shimmer" },
	Compass = { "Goal compass", "Arrow to your next goal" },
}

---------------------------------------------------------------- Schwarm-Ereignis

Progress.SwarmEvery = 15 * 60 -- Sekunden zwischen zwei Schwaermen
Progress.SwarmFirst = 3 * 60
Progress.SwarmDuration = 6 * 60
Progress.SwarmChance = 0.5 -- Anteil der Begegnungen auf der Route, die zum Schwarm gehoeren

-- Belohnungs-Text ohne Server (Client zeigt Belohnungen an)
function Progress.BundleText(bundle, items): string
	local parts = {}
	if bundle.Coins then
		table.insert(parts, withCommas(bundle.Coins) .. " coins")
	end
	local keys = {}
	for key in bundle.Items or {} do
		table.insert(keys, key)
	end
	table.sort(keys)
	for _, key in keys do
		local item = items and items[key]
		table.insert(parts, `{bundle.Items[key]}x {if item then item.Name else key}`)
	end
	return table.concat(parts, ", ")
end

return Progress
