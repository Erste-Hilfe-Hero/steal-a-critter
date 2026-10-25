-- Gemeinsame Regeln fuer Fahrer-Level, taegliche Aufgaben, Erfolge (mit Titeln), Siegesserien und Einstellungen.
-- Server und Client nutzen dieselben Definitionen, damit die Anzeige immer zur Berechnung passt.
local Progression = {}

---------------------------------------------------------------- Level

Progression.MaxLevel = 100

-- XP, die man von Level L auf L+1 braucht
function Progression.XpForLevel(level: number): number
	return 100 + 40 * (level - 1)
end

-- Level, XP im aktuellen Level und benoetigte XP bis zum naechsten Level
function Progression.LevelFromXp(xp: number): (number, number, number)
	local level = 1
	local rest = math.max(0, math.floor(xp))
	while level < Progression.MaxLevel and rest >= Progression.XpForLevel(level) do
		rest -= Progression.XpForLevel(level)
		level += 1
	end
	return level, rest, Progression.XpForLevel(level)
end

-- XP fuer ein beendetes Rennen (Platz 1 bekommt am meisten)
function Progression.RaceXp(place: number, racers: number): number
	return 30 + math.max(0, racers - place + 1) * 10
end

function Progression.LevelReward(level: number): number
	return 100 * level
end

---------------------------------------------------------------- Taegliche Aufgaben

Progression.QuestsPerDay = 3
Progression.QuestXp = 50

-- Stat = welcher Zaehler die Aufgabe voranbringt
Progression.Quests = {
	{ Id = "Races", Stat = "Races", Goal = 3, Coins = 250, Text = "Finish 3 races" },
	{ Id = "Podium", Stat = "Podiums", Goal = 2, Coins = 350, Text = "Finish in the top 3 twice" },
	{ Id = "Win", Stat = "Wins", Goal = 1, Coins = 500, Text = "Win a race" },
	{ Id = "Coins", Stat = "TrackCoins", Goal = 20, Coins = 250, Text = "Collect 20 coins on the track" },
	{ Id = "Hits", Stat = "Hits", Goal = 5, Coins = 300, Text = "Blast 5 rivals with items" },
	{ Id = "Items", Stat = "ItemsUsed", Goal = 10, Coins = 250, Text = "Use 10 items" },
	{ Id = "Boxes", Stat = "Boxes", Goal = 12, Coins = 200, Text = "Open 12 item boxes" },
}
Progression.QuestsById = {}
for _, quest in Progression.Quests do
	Progression.QuestsById[quest.Id] = quest
end

-- Drei verschiedene Aufgaben pro Tag, fuer jeden Spieler anders, aber am selben Tag immer gleich
function Progression.QuestsForDay(day: number, userId: number): { string }
	local rng = Random.new(day * 7919 + userId % 100_000)
	local pool = {}
	for _, quest in Progression.Quests do
		table.insert(pool, quest.Id)
	end
	local picked = {}
	for _ = 1, Progression.QuestsPerDay do
		table.insert(picked, table.remove(pool, rng:NextInteger(1, #pool)) :: string)
	end
	return picked
end

---------------------------------------------------------------- Erfolge und Titel

-- Check bekommt die gespeicherten Spielerdaten und sagt, ob der Erfolg erreicht ist
Progression.Achievements = {
	{ Id = "FirstRace", Title = "Rookie", Text = "Finish your first race", Coins = 200, Check = function(d) return d.Races >= 1 end },
	{ Id = "FirstWin", Title = "Champion", Text = "Win a race", Coins = 400, Check = function(d) return d.Wins >= 1 end },
	{ Id = "Wins10", Title = "Speed Demon", Text = "Win 10 races", Coins = 1_500, Check = function(d) return d.Wins >= 10 end },
	{ Id = "Wins50", Title = "Fire Legend", Text = "Win 50 races", Coins = 6_000, Check = function(d) return d.Wins >= 50 end },
	{ Id = "Races50", Title = "Road Warrior", Text = "Finish 50 races", Coins = 2_500, Check = function(d) return d.Races >= 50 end },
	{ Id = "Hits50", Title = "Blaster", Text = "Blast 50 rivals with items", Coins = 2_000, Check = function(d) return d.Stats.Hits >= 50 end },
	{ Id = "Coins500", Title = "Coin Collector", Text = "Collect 500 coins on the track", Coins = 2_000, Check = function(d) return d.Stats.TrackCoins >= 500 end },
	{ Id = "Streak3", Title = "Unstoppable", Text = "Win 3 races in a row", Coins = 3_000, Check = function(d) return d.BestStreak >= 3 end },
	{ Id = "Level10", Title = "Veteran", Text = "Reach level 10", Coins = 2_500, Check = function(d) return (Progression.LevelFromXp(d.XP)) >= 10 end },
	{ Id = "AllTracks", Title = "Globetrotter", Text = "Finish a race on all 10 tracks", Coins = 3_000, Check = function(d)
		local count = 0
		for _ in d.Best do
			count += 1
		end
		return count >= 10
	end },
}
Progression.AchievementsById = {}
for index, achievement in Progression.Achievements do
	achievement.Order = index
	Progression.AchievementsById[achievement.Id] = achievement
end

---------------------------------------------------------------- Siegesserie

-- Bonus-Muenzen fuer den n-ten Sieg in Folge (ab dem 2. Sieg)
function Progression.StreakBonus(streak: number): number
	if streak < 2 then
		return 0
	end
	return math.min(250, (streak - 1) * 50)
end

---------------------------------------------------------------- Einstellungen

Progression.Settings = {
	{ Key = "Sfx", Name = "Sound effects", Default = true },
	{ Key = "Shake", Name = "Camera shake", Default = true },
	{ Key = "Fov", Name = "Speed zoom effect", Default = true },
	{ Key = "Minimap", Name = "Show minimap", Default = true },
	{ Key = "Hints", Name = "Show control hints", Default = true },
}
Progression.SettingsByKey = {}
for _, setting in Progression.Settings do
	Progression.SettingsByKey[setting.Key] = setting
end

Progression.TutorialCoins = 200

return Progression
