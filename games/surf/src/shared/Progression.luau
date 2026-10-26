-- Daten fuer den Fortschritt (Update 2): Erfolge mit Titeln, Tagesaufgaben, Medaillen-Zeiten, Codes,
-- Gluecks-Schneeball, Buddies, Schneesturm-Event, Freundes-Bonus, Einstellungen und Tempo-Meilensteine.
-- Reine Daten + kleine Hilfsfunktionen, damit Server, Client und Tests dieselben Werte nutzen.
local Progression = {}

---------------------------------------------------------------- Erfolge (jeder Erfolg = Titel)

-- Kind + Goal: was der Server prueft (siehe ProgressService.Evaluate). Reward = Schneeflocken (ohne Multiplikator)
Progression.Achievements = {
	{ Id = "first_clear", Name = "First Steps", Desc = "Clear your first stage", Kind = "Clears", Goal = 1, Reward = 100 },
	{ Id = "halfway", Name = "Halfway There", Desc = "Unlock Stage 5", Kind = "MaxStage", Goal = 5, Reward = 300 },
	{ Id = "map_clear", Name = "Summit Conqueror", Desc = "Finish the whole map", Kind = "MapClears", Goal = 1, Reward = 1000 },
	{ Id = "map10", Name = "Mountain Regular", Desc = "Finish the map 10 times", Kind = "MapClears", Goal = 10, Reward = 3000 },
	{ Id = "clears100", Name = "Ramp Rat", Desc = "Clear 100 stages", Kind = "Clears", Goal = 100, Reward = 1500 },
	{ Id = "speed1000", Name = "Picking Up Speed", Desc = "Reach 1,000 u/s", Kind = "TopSpeed", Goal = 1000, Reward = 200 },
	{ Id = "speed2000", Name = "Speed Demon", Desc = "Reach 2,000 u/s", Kind = "TopSpeed", Goal = 2000, Reward = 800 },
	{ Id = "speed3000", Name = "Sound Barrier", Desc = "Reach 3,000 u/s", Kind = "TopSpeed", Goal = 3000, Reward = 2500 },
	{ Id = "fast_map", Name = "Speedrunner", Desc = "Ranked full map under 3:00", Kind = "BestTimeUnder", Goal = 180, Reward = 1500 },
	{ Id = "gold3", Name = "Medal Hunter", Desc = "Win 3 gold medals", Kind = "GoldMedals", Goal = 3, Reward = 1000 },
	{ Id = "gold_all", Name = "Golden Skier", Desc = "Gold medal on every stage", Kind = "GoldMedals", Goal = 10, Reward = 5000 },
	{ Id = "quests10", Name = "Busy Bee", Desc = "Complete 10 daily quests", Kind = "QuestsDone", Goal = 10, Reward = 1000 },
	{ Id = "hour", Name = "Dedicated", Desc = "Play for 60 minutes", Kind = "PlayMinutes", Goal = 60, Reward = 500 },
	{ Id = "streak7", Name = "Loyal Surfer", Desc = "Reach a 7 day login streak", Kind = "Streak", Goal = 7, Reward = 1000 },
	{ Id = "falls50", Name = "Snow Angel", Desc = "Fall off 50 times (it happens!)", Kind = "Falls", Goal = 50, Reward = 150 },
	{ Id = "buddy", Name = "Best Friends", Desc = "Own a buddy", Kind = "Buddies", Goal = 1, Reward = 200 },
}
Progression.AchievementsById = {}
for _, a in Progression.Achievements do
	Progression.AchievementsById[a.Id] = a
end

---------------------------------------------------------------- Tagesaufgaben

-- Jeden Tag 3 Aufgaben (fest aus Tag + UserId gewaehlt). Kind wird vom Server hochgezaehlt.
Progression.QuestPool = {
	{ Id = "clear10", Text = "Clear 10 stages", Kind = "Clear", Goal = 10, Reward = 300 },
	{ Id = "clear_high", Text = "Clear a stage from Stage 5 or higher", Kind = "ClearHigh", Goal = 1, Reward = 250 },
	{ Id = "map", Text = "Finish the whole map", Kind = "Map", Goal = 1, Reward = 600 },
	{ Id = "speed", Text = "Reach 1,200 u/s", Kind = "Speed", Goal = 1200, Reward = 250 },
	{ Id = "play15", Text = "Surf for 15 minutes", Kind = "Minutes", Goal = 15, Reward = 200 },
	{ Id = "pb", Text = "Beat one of your stage PBs", Kind = "StagePB", Goal = 1, Reward = 250 },
	{ Id = "medal", Text = "Earn a Silver medal or better", Kind = "Medal", Goal = 1, Reward = 300 },
	{ Id = "clear25", Text = "Clear 25 stages", Kind = "Clear", Goal = 25, Reward = 700 },
}
Progression.QuestsPerDay = 3
Progression.QuestById = {}
for _, q in Progression.QuestPool do
	Progression.QuestById[q.Id] = q
end

-- Deterministische Auswahl (kein math.random, damit ein Rejoin dieselben Aufgaben zeigt)
function Progression.QuestsFor(day: number, userId: number): { string }
	local picked = {}
	local used = {}
	-- nie 0, sonst bleibt der Generator stehen
	local state = (day * 7919 + userId % 100003 * 31) % 2147483646 + 1
	while #picked < math.min(Progression.QuestsPerDay, #Progression.QuestPool) do
		state = (state * 48271) % 2147483647
		local index = state % #Progression.QuestPool + 1
		if not used[index] then
			used[index] = true
			table.insert(picked, Progression.QuestPool[index].Id)
		end
	end
	return picked
end

---------------------------------------------------------------- Medaillen

-- Gold-Zeit pro Stage (etwa so schnell wie der Test-Bot), Silber = Gold x 1.35, Bronze = geschafft
Progression.GoldTimes = { 12, 14, 14.5, 15.5, 15, 15.5, 16.5, 17.5, 17, 18.5 }
Progression.SilverFactor = 1.35
Progression.Medals = {
	{ Name = "Bronze", Color = Color3.fromRGB(205, 127, 50), Reward = 0 },
	{ Name = "Silver", Color = Color3.fromRGB(200, 210, 225), Reward = 150 },
	{ Name = "Gold", Color = Color3.fromRGB(255, 205, 64), Reward = 400 },
}

-- 0 = keine, 1 = Bronze, 2 = Silber, 3 = Gold
function Progression.MedalFor(stage: number, seconds: number): number
	local gold = Progression.GoldTimes[stage]
	if not gold or typeof(seconds) ~= "number" or seconds ~= seconds or seconds <= 0 then
		return 0
	end
	if seconds <= gold then
		return 3
	elseif seconds <= gold * Progression.SilverFactor then
		return 2
	end
	return 1
end

---------------------------------------------------------------- Codes

-- Gross-/Kleinschreibung egal. Jeder Code einmal pro Spieler.
Progression.Codes = {
	SURFSUP = 500,
	SKI2026 = 750,
	AURORA = 1000,
	POWDER = 300,
}

---------------------------------------------------------------- Buddies (kleiner Begleiter an der Schulter)

Progression.Buddies = {
	{ Id = "none", Name = "No Buddy", Price = 0 },
	{ Id = "snowman", Name = "Frosty Jr.", Price = 2500, Color = Color3.fromRGB(245, 248, 255) },
	{ Id = "penguin", Name = "Pip the Penguin", Price = 4000, Color = Color3.fromRGB(30, 34, 48) },
	{ Id = "fox", Name = "Arctic Fox", Price = 9000, Color = Color3.fromRGB(235, 240, 250) },
	{ Id = "orb", Name = "Aurora Orb", Price = 15000, Color = Color3.fromRGB(255, 79, 163) },
	{ Id = "owl", Name = "Snow Owl", Spin = true, Color = Color3.fromRGB(250, 250, 255) },
}
Progression.BuddiesById = {}
for _, b in Progression.Buddies do
	Progression.BuddiesById[b.Id] = b
end

---------------------------------------------------------------- Gluecks-Schneeball (1x pro Tag gratis)

-- Nur Spielwaehrung und Kosmetik, kein Robux: Weight = relative Chance
Progression.Spin = {
	{ Kind = "Flakes", Amount = 100, Weight = 34, Label = "100" },
	{ Kind = "Flakes", Amount = 250, Weight = 25, Label = "250" },
	{ Kind = "Flakes", Amount = 500, Weight = 18, Label = "500" },
	{ Kind = "Flakes", Amount = 1000, Weight = 10, Label = "1,000" },
	{ Kind = "Flakes", Amount = 2500, Weight = 4, Label = "2,500" },
	{ Kind = "Boost", Seconds = 900, Weight = 6, Label = "15 min 2x" },
	{ Kind = "Buddy", Id = "owl", Fallback = 1500, Weight = 3, Label = "Snow Owl" },
}

function Progression.PickSpin(roll: number): number
	local total = 0
	for _, slot in Progression.Spin do
		total += slot.Weight
	end
	local target = roll * total
	for index, slot in Progression.Spin do
		target -= slot.Weight
		if target < 0 then
			return index
		end
	end
	return 1
end

---------------------------------------------------------------- Events und Boni

Progression.StormEvery = 20 * 60 -- alle 20 Minuten ein Schneesturm
Progression.StormLength = 4 * 60 -- 4 Minuten doppelte Schneeflocken
Progression.StormMultiplier = 2
Progression.BoostMultiplier = 2 -- Flake Booster (Produkt oder Gluecks-Schneeball)
Progression.FriendBonusEach = 0.1 -- +10 % pro Freund im Server
Progression.FriendBonusMax = 0.3

---------------------------------------------------------------- Tempo

Progression.SpeedMilestones = { 1000, 2000, 3000 }
Progression.MaxPlausibleStuds = 300 -- schneller (Studs/s) = Teleport, nicht gefahren

---------------------------------------------------------------- Einstellungen

Progression.DefaultSettings = {
	HidePlayers = false,
	Snow = true,
	Speedometer = true,
	Wind = true,
	SpeedFx = true,
	Hints = true,
	SurfAssist = true, -- Surf-Hilfe: drueckt auf Rampen automatisch richtig, lenkt in der Luft (Handy-Freund)
	-- Update 3
	Music = true,
	CameraTilt = true,
	Ghost = true,
	SkiSpray = true,
}

return Progression
