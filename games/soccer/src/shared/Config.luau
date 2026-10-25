-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Soccer Jam (nach dem CS-1.6-Mod).
-- Produkt-IDs kommen aus ProductIds.json (wird beim Veroeffentlichen per GitHub Action erzeugt).
-- Fehlt eine ID, sucht der Server das Produkt ueber den Namen; in Studio lassen sich Kaeufe simulieren.

local Config = {}

Config.GameName = "SOCCER JAM"
Config.DataStoreName = "TurboSoccer_v1"

---------------------------------------------------------------- Stil

Config.Font = Enum.Font.LuckiestGuy
Config.BodyFont = Enum.Font.GothamBold
Config.Colors = {
	Navy = Color3.fromRGB(16, 22, 52),
	NavyLight = Color3.fromRGB(32, 42, 90),
	Lime = Color3.fromRGB(190, 255, 60),
	Orange = Color3.fromRGB(255, 110, 30),
	Cyan = Color3.fromRGB(40, 200, 255),
	White = Color3.fromRGB(255, 255, 255),
	Gold = Color3.fromRGB(255, 205, 50),
	Red = Color3.fromRGB(255, 80, 80),
}

---------------------------------------------------------------- Spielfeld (X = Laenge, Z = Breite)

-- Gross wie die Original-Map: viel Platz fuer Sprints, Fernschuesse und Kurvenbaelle
Config.FieldLength = 340
Config.FieldWidth = 200
Config.GoalWidth = 40
Config.GoalHeight = 16
Config.GoalDepth = 12
Config.GroundY = 0 -- Oberkante des Rasens
Config.BallSize = 3

-- Teams wie im Original: Rot gegen Blau. Blue verteidigt das Tor bei -X, Red das bei +X.
Config.Teams = {
	Blue = { Name = "Blue", Color = Color3.fromRGB(50, 130, 255), Dark = Color3.fromRGB(20, 60, 170), BrickColor = BrickColor.new("Bright blue"), Side = -1 },
	Red = { Name = "Red", Color = Color3.fromRGB(235, 55, 55), Dark = Color3.fromRGB(150, 25, 25), BrickColor = BrickColor.new("Bright red"), Side = 1 },
}
Config.TeamOrder = { "Red", "Blue" }

-- Aufstellung als Anteil der eigenen Haelfte (x: 0 = Mittellinie, 1 = eigenes Tor; z: -1..1)
Config.Formation = {
	{ x = 0.92, z = 0, Role = "Keeper" },
	{ x = 0.12, z = 0, Role = "Striker" },
	{ x = 0.55, z = -0.4, Role = "Defender" },
	{ x = 0.55, z = 0.4, Role = "Defender" },
	{ x = 0.3, z = -0.75, Role = "Wing" },
	{ x = 0.3, z = 0.75, Role = "Wing" },
	{ x = 0.7, z = 0, Role = "Defender" },
	{ x = 0.15, z = -0.4, Role = "Striker" },
	{ x = 0.15, z = 0.4, Role = "Striker" },
	{ x = 0.45, z = 0, Role = "Wing" },
}

---------------------------------------------------------------- Spielablauf

Config.MatchSeconds = 480
Config.ScoreLimit = 10 -- wer zuerst 10 Tore hat, gewinnt sofort
Config.GoldenGoalSeconds = 90
Config.KickoffSeconds = 3
Config.GoalCelebrationSeconds = 4
Config.ResultsSeconds = 12
Config.MinTeamSize = 4 -- Bots fuellen jedes Team bis hierhin auf
Config.MaxTeamSize = 10

---------------------------------------------------------------- Ball

Config.PickupCooldown = 0.45 -- so lange kann der Schuetze den Ball nicht wieder annehmen
Config.BallFriction = 0.7 -- Bremsung pro Sekunde auf dem Boden
Config.ChargeTime = 1.1 -- Sekunden bis voller Schuss
Config.CurveRate = 1.4 -- Kurvenball: Drehung der Flugbahn in rad/s bei vollem Effet
Config.CurveTime = 1.1
Config.SmackSpeed = 75 -- schnellere gegnerische Schuesse hauen Spieler um (wie im Original, nur ohne Schaden)
Config.SmackStun = 1.6
Config.BallReturnSeconds = 30 -- unberuehrter Ball kommt zur Mitte zurueck
Config.StunTime = 1.2
Config.DashSpeed = 62

-- Messer wie im Original (Werte aus CS 1.6): Slash schnell, Stab stark, von hinten dreifacher Schaden.
-- Bei 0 Leben ist man K.O. (umgekippt, kein Blut) und kommt nach ein paar Sekunden an der Startposition zurueck.
Config.MaxHP = 100
Config.Knife = {
	-- Samurai-Schwert: Schwung trifft alle Gegner im breiten Bogen, Stoss reicht weit nach vorne
	Slash = { Damage = 20, Backstab = 50, Range = 14, Arc = -0.25, Cleave = true, Windup = 0, Window = 0.35, Cooldown = 0.55 },
	Stab = { Damage = 60, Backstab = 180, Range = 15, Arc = 0.5, Windup = 0.2, Window = 0.35, Cooldown = 1.2 },
}
Config.BackstabDot = 0.45 -- so weit muss das Opfer vom Angreifer wegschauen
Config.HuntDistance = 45 -- Bots schlagen nur in dieser Naehe zum Ball zu (Spieler duerfen ueberall)
-- Messer-Treffer am Ballfuehrer: Chance, dass er den Ball verliert (Original: 5 % + 6 % je Disarm-Stufe)
function Config.DisarmChance(level: number): number
	return 0.12 + level * 0.08
end
-- Stamina gibt wie im Original mehr Leben
function Config.MaxHPFor(stamina: number): number
	return Config.MaxHP + stamina * 20
end
-- Powerplay: jeder Pass zu einem anderen Mitspieler (bis 5) macht die Schuesse des Teams staerker
Config.MaxPowerPlay = 5
Config.PowerPlayBonus = 0.06 -- +6 % Schussstaerke je Stufe
Config.LongJumpCooldown = 5 -- Sprung beim Seitwaerts-Laufen: doppelt so weit (wie im Original)
Config.KOSeconds = 10
Config.SpawnProtect = 2 -- so lange nach dem Zurueckkommen unverwundbar
function Config.SmackDamage(speed: number): number
	-- Harte Schuesse tun weh wie im Original: 20 bis 60 Schaden je nach Tempo
	return math.clamp(math.floor((speed - Config.SmackSpeed) * 1.2 + 20), 20, 60)
end

-- Maskottchen bewachen ihr Tor: Gegner ohne Ball, die zu lange im Strafraum stehen, werden weggeschleudert
-- Wie im Original: das Alien-Maskottchen zappt jede Sekunde einen Gegner im Kreis vor seinem Tor (8-12 Schaden);
-- wer mit dem Ball in den Kreis laeuft, ist sofort K.O. Tore muessen also von ausserhalb geschossen werden.
-- Eigene Spieler im Kreis (Torwart) heilen sich langsam.
Config.AlienRadius = 40
Config.AlienInterval = 1
Config.AlienDamage = { 8, 12 }
Config.KeeperRegen = 6 -- Leben pro Sekunde im eigenen Kreis

---------------------------------------------------------------- Upgrades (wie im Original mit Match-EXP: Stamina, Strength, Agility, Dexterity, Disarm)

Config.MaxSkill = 5
Config.Skills = {
	{ Id = "Stamina", Name = "Stamina", Description = "+20 max health (after your next knockout or kickoff) and more turbo", Color = Color3.fromRGB(120, 255, 140) },
	{ Id = "Strength", Name = "Strength", Description = "Harder, faster kicks", Color = Color3.fromRGB(255, 110, 30) },
	{ Id = "Agility", Name = "Agility", Description = "Run faster", Color = Color3.fromRGB(40, 200, 255) },
	{ Id = "Dexterity", Name = "Dexterity", Description = "Grab the ball from further away, catch hard shots", Color = Color3.fromRGB(255, 205, 50) },
	{ Id = "Disarm", Name = "Disarm", Description = "Sword hits knock the ball away from the carrier more often", Color = Color3.fromRGB(200, 120, 255) },
}

-- EXP-Kosten der naechsten Stufe (0 -> 1 kostet 150, 4 -> 5 kostet 750)
function Config.UpgradeCost(level: number): number
	return 150 * (level + 1)
end
Config.StartEXP = 300
Config.StartEXPPerLevel = 15 -- Account-Level gibt mehr Start-EXP
Config.MaxLevelEXP = 600
Config.VIPStartEXP = 200
Config.EXP = {
	Goal = 300,
	Assist = 150,
	Steal = 100,
	Save = 150,
	Smack = 80,
	Dodge = 40,
	KO = 100,
}
Config.GoalDistanceBonus = 4 -- EXP je Stud ueber 40 Studs Torentfernung

-- Werte je Skill-Stufe (Stufe 0 bis 6; 6 nur mit Pro Boots)
function Config.MaxStamina(level: number): number
	return 100 + level * 25
end
function Config.StaminaRegen(level: number): number
	return 14 + level * 3
end
Config.StaminaDrain = 24
function Config.KickSpeed(level: number): number
	return 80 + level * 12
end
function Config.WalkSpeed(level: number): number
	return 18 + level * 1.2
end
Config.SprintFactor = 1.5
Config.CarryFactor = 0.92
function Config.PickupRange(level: number): number
	return 4.4 + level * 0.5
end
function Config.CatchSpeed(level: number): number
	return 62 + level * 9 -- schnellere Baelle prallen ab oder hauen um
end

---------------------------------------------------------------- Account-Fortschritt (bleibt gespeichert)

function Config.XPForLevel(level: number): number
	return 200 + level * 80
end
Config.Rewards = {
	Goal = { XP = 100, Coins = 25 },
	Assist = { XP = 50, Coins = 15 },
	Steal = { XP = 15, Coins = 3 },
	Save = { XP = 20, Coins = 4 },
	Smack = { XP = 10, Coins = 2 },
	Dodge = { XP = 5, Coins = 1 },
	KO = { XP = 20, Coins = 4 },
	Win = { XP = 150, Coins = 50 },
	Draw = { XP = 90, Coins = 30 },
	Loss = { XP = 60, Coins = 20 },
}
Config.BuyEXPAmount = 250 -- EXP fuer Coins: 300, 450, 600, ... (pro Match)
Config.BuyEXPBase = 300
Config.BuyEXPStep = 150
Config.DailyCoins = { 100, 150, 200, 300, 400, 500, 750 }
Config.XPBoostMinutes = 30
Config.GoldenKnifeDamage = 1.35
Config.IronBodyHP = 50
Config.CannonShotPower = 1.2
Config.SpeedDemonFactor = 1.12
Config.TurboLungsFactor = 1.5
Config.MagnetFeetRange = 1.4
Config.IronGripFactor = 0.5
Config.SteelKeeperFactor = 1.25
Config.QuickRespawnSeconds = 4
Config.VampireHeal = 0.5
Config.NinjaBackstabDot = 0.15
Config.NinjaStabCooldown = 0.7
Config.RageFactor = 1.25

-- Pass oder zeitlicher Boost (Attribut am Spieler)
function Config.Has(player: Player?, key: string): boolean
	return player ~= nil and player:GetAttribute("Pass_" .. key) == true
end
function Config.Active(player: Player?, attribute: string): boolean
	return player ~= nil and (player:GetAttribute(attribute) or 0) > workspace:GetServerTimeNow()
end
Config.AdCooldown = 300
Config.StarterPackDelay = 90

---------------------------------------------------------------- Kick-Trails (Ball-Spur nach deinen Schuessen)

Config.Trails = {
	{ Id = "white", Name = "Classic", Colors = { Color3.fromRGB(255, 255, 255) }, Price = 0 },
	{ Id = "lime", Name = "Lime", Colors = { Color3.fromRGB(190, 255, 60), Color3.fromRGB(80, 200, 40) }, Price = 400 },
	{ Id = "ice", Name = "Ice Shot", Colors = { Color3.fromRGB(200, 240, 255), Color3.fromRGB(60, 140, 255) }, Price = 800 },
	{ Id = "fire", Name = "Fireball", Colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 70, 0) }, Price = 1500 },
	{ Id = "toxic", Name = "Toxic", Colors = { Color3.fromRGB(180, 255, 40), Color3.fromRGB(30, 120, 20) }, Price = 2500 },
	{ Id = "royal", Name = "Royal", Colors = { Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 205, 50) }, Price = 4000 },
	{ Id = "shadow", Name = "Shadow", Colors = { Color3.fromRGB(30, 30, 40), Color3.fromRGB(140, 0, 220) }, Price = 6000 },
	{ Id = "turbo", Name = "Starter Flame", Colors = { Color3.fromRGB(255, 110, 30), Color3.fromRGB(190, 255, 60) }, Pass = "StarterPack" },
	{ Id = "gold", Name = "Golden VIP", Colors = { Color3.fromRGB(255, 230, 90), Color3.fromRGB(255, 150, 0) }, Pass = "VIP" },
	{ Id = "rainbow", Name = "Rainbow", Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 220, 90), Color3.fromRGB(60, 140, 255), Color3.fromRGB(180, 80, 255) }, Pass = "EffectsPack" },
	{ Id = "galaxy", Name = "Galaxy", Colors = { Color3.fromRGB(30, 10, 90), Color3.fromRGB(200, 100, 255), Color3.fromRGB(255, 255, 255) }, Pass = "EffectsPack" },
	{ Id = "lightning", Name = "Lightning", Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(40, 200, 255), Color3.fromRGB(255, 255, 120) }, Pass = "EffectsPack" },
}
Config.TrailsById = {}
for index, trail in Config.Trails do
	trail.Order = index
	Config.TrailsById[trail.Id] = trail
end

---------------------------------------------------------------- Extras (Schwert-Skins, Quests, Titel, Events)

-- Katana-Skins: mit Coins kaufen oder ueber den Sword Pack (Pass)
Config.SwordSkins = {
	{ Id = "classic", Name = "Classic", Color = Color3.fromRGB(215, 225, 235), Material = Enum.Material.Metal, Price = 0 },
	{ Id = "crimson", Name = "Crimson", Color = Color3.fromRGB(220, 40, 50), Material = Enum.Material.Neon, Price = 500 },
	{ Id = "frost", Name = "Frost", Color = Color3.fromRGB(140, 220, 255), Material = Enum.Material.Ice, Price = 900 },
	{ Id = "toxic", Name = "Toxic", Color = Color3.fromRGB(120, 255, 60), Material = Enum.Material.Neon, Price = 1200 },
	{ Id = "shadow", Name = "Shadow", Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.Metal, Price = 2000 },
	{ Id = "sakura", Name = "Sakura", Color = Color3.fromRGB(255, 160, 200), Material = Enum.Material.Neon, Price = 3000 },
	{ Id = "dragon", Name = "Dragon", Color = Color3.fromRGB(255, 110, 20), Material = Enum.Material.Neon, Pass = "SwordPack" },
	{ Id = "void", Name = "Void", Color = Color3.fromRGB(130, 40, 255), Material = Enum.Material.Neon, Pass = "SwordPack" },
	{ Id = "prism", Name = "Prism", Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Glass, Pass = "SwordPack" },
}
Config.SwordSkinsById = {}
for _, skin in Config.SwordSkins do
	Config.SwordSkinsById[skin.Id] = skin
end

-- Taegliche Quests: jeden Tag 3 (mit Quest Master 4) aus dieser Liste, Belohnung in Coins
Config.Quests = {
	{ Id = "goals", Text = "Score %d goals", Goal = 2, Event = "Goal", Coins = 300 },
	{ Id = "hits", Text = "Land %d sword hits", Goal = 15, Event = "Hit", Coins = 250 },
	{ Id = "kos", Text = "Knock out %d players", Goal = 5, Event = "KO", Coins = 300 },
	{ Id = "steals", Text = "Steal the ball %d times", Goal = 3, Event = "Steal", Coins = 250 },
	{ Id = "saves", Text = "Make %d saves", Goal = 3, Event = "Save", Coins = 250 },
	{ Id = "passes", Text = "Complete %d passes", Goal = 8, Event = "Pass", Coins = 200 },
	{ Id = "win", Text = "Win %d match", Goal = 1, Event = "Win", Coins = 400 },
	{ Id = "matches", Text = "Play %d matches", Goal = 2, Event = "Match", Coins = 200 },
	{ Id = "assists", Text = "Get %d assists", Goal = 2, Event = "Assist", Coins = 300 },
}

-- Titel ueber dem Namen: der hoechste erreichte zaehlt
Config.Titles = {
	{ Name = "Rookie", Stat = "Matches", Need = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Name = "Striker", Stat = "Goals", Need = 25, Color = Color3.fromRGB(120, 220, 255) },
	{ Name = "Samurai", Stat = "KOs", Need = 100, Color = Color3.fromRGB(255, 90, 90) },
	{ Name = "Champion", Stat = "Wins", Need = 50, Color = Color3.fromRGB(255, 205, 50) },
	{ Name = "Legend", Stat = "Level", Need = 50, Color = Color3.fromRGB(200, 120, 255) },
}

Config.ComboHits = 3 -- dritter Treffer in Folge ...
Config.ComboWindow = 3 -- ... innerhalb von 3 Sekunden ...
Config.ComboBonus = 1.5 -- ... macht 50 % mehr Schaden
Config.Streaks = { [2] = "DOUBLE KO", [3] = "TRIPLE KO", [5] = "RAMPAGE", [8] = "UNSTOPPABLE" }
Config.StreakCoins = 50 -- pro K.O. in der Serie
Config.RegenDelay = 5 -- so lange ohne Treffer, dann Leben zurueck
Config.RegenPerSecond = 3
Config.GoldenBallSeconds = 45 -- goldener Ball: ein Tor zaehlt doppelt
Config.BicycleBonus = 1.15 -- Schuss in der Luft
Config.RocketShotPower = 1.6
Config.TeamBoostFactor = 1.1
Config.GiantScale = 1.3
Config.GiantReach = 3
Config.OnFireSeconds = 8 -- so lange Ballbesitz, dann brennt man
Config.HatTrickCoins = 500
Config.LevelRewardEvery = 5
Config.LevelRewardCoins = 250
Config.WinStreakCoins = 50 -- pro Sieg in Folge, hoechstens 5
Config.PlaytimeMinutes = 10
Config.PlaytimeCoins = 100
Config.NightChance = 0.3
Config.RainChance = 0.2

---------------------------------------------------------------- Features (Erfolge, Codes, Gluecksrad, Rang, Pickups, Modi ...)

-- Erfolge: einmalige Coin-Belohnung, sobald der Karriere-Wert erreicht ist
Config.Achievements = {
	{ Id = "goal1", Name = "First Goal", Stat = "Goals", Need = 1, Coins = 100 },
	{ Id = "goal25", Name = "Sharpshooter", Stat = "Goals", Need = 25, Coins = 500 },
	{ Id = "goal100", Name = "Goal Machine", Stat = "Goals", Need = 100, Coins = 1500 },
	{ Id = "assist25", Name = "Playmaker", Stat = "Assists", Need = 25, Coins = 500 },
	{ Id = "ko50", Name = "Swordsman", Stat = "KOs", Need = 50, Coins = 500 },
	{ Id = "ko250", Name = "Shogun", Stat = "KOs", Need = 250, Coins = 1500 },
	{ Id = "steal50", Name = "Pickpocket", Stat = "Steals", Need = 50, Coins = 400 },
	{ Id = "save50", Name = "The Wall", Stat = "Saves", Need = 50, Coins = 400 },
	{ Id = "win10", Name = "Winner", Stat = "Wins", Need = 10, Coins = 500 },
	{ Id = "win100", Name = "Champion", Stat = "Wins", Need = 100, Coins = 2000 },
	{ Id = "match50", Name = "Veteran", Stat = "Matches", Need = 50, Coins = 800 },
	{ Id = "level10", Name = "Rising Star", Stat = "Level", Need = 10, Coins = 500 },
	{ Id = "level25", Name = "Superstar", Stat = "Level", Need = 25, Coins = 1500 },
	{ Id = "mvp10", Name = "Most Valuable", Stat = "MVPs", Need = 10, Coins = 1000 },
}

-- Codes (Gross-/Kleinschreibung egal), jeder Code einmal pro Spieler
Config.Codes = {
	SOCCERJAM = { Coins = 500 },
	WELCOME = { Coins = 300 },
	GOAL = { Coins = 250 },
	ROCKET = { RocketShots = 2 },
	SAMURAI = { Coins = 400 },
}

-- Gluecksrad: einmal am Tag gratis, weitere Drehungen kosten Coins (nur Spielwaehrung)
Config.SpinPrice = 300
Config.SpinPrizes = {
	{ Text = "100 COINS", Coins = 100, Weight = 30 },
	{ Text = "150 COINS", Coins = 150, Weight = 25 },
	{ Text = "250 COINS", Coins = 250, Weight = 18 },
	{ Text = "400 COINS", Coins = 400, Weight = 12 },
	{ Text = "600 COINS", Coins = 600, Weight = 6 },
	{ Text = "1000 COINS", Coins = 1000, Weight = 3 },
	{ Text = "ROCKET SHOT", RocketShots = 1, Weight = 4 },
	{ Text = "15 MIN 2x XP", BoostMinutes = 15, Weight = 2 },
}

-- Rang-Punkte: Sieg/Unentschieden/Niederlage, Stufen ab diesen Punkten
Config.RatingStart = 1000
Config.RatingChange = { Win = 25, Draw = 5, Loss = -15 }
Config.Ranks = {
	{ Name = "Bronze", Min = 0, Color = Color3.fromRGB(205, 127, 50) },
	{ Name = "Silver", Min = 1100, Color = Color3.fromRGB(200, 205, 215) },
	{ Name = "Gold", Min = 1250, Color = Color3.fromRGB(255, 205, 50) },
	{ Name = "Platinum", Min = 1450, Color = Color3.fromRGB(120, 230, 220) },
	{ Name = "Diamond", Min = 1700, Color = Color3.fromRGB(110, 170, 255) },
	{ Name = "Champion", Min = 2000, Color = Color3.fromRGB(255, 90, 90) },
}
function Config.RankFor(rating: number)
	local best = Config.Ranks[1]
	for _, rank in Config.Ranks do
		if rating >= rank.Min then
			best = rank
		end
	end
	return best
end

-- Wochen-Herausforderung: eine grosse Aufgabe pro Woche (fuer alle gleich)
Config.WeeklyChallenges = {
	{ Id = "wgoals", Text = "Score %d goals this week", Goal = 10, Event = "Goal", Coins = 1500 },
	{ Id = "whits", Text = "Land %d sword hits this week", Goal = 120, Event = "Hit", Coins = 1200 },
	{ Id = "wwins", Text = "Win %d matches this week", Goal = 8, Event = "Win", Coins = 1500 },
	{ Id = "wkos", Text = "Knock out %d players this week", Goal = 40, Event = "KO", Coins = 1500 },
	{ Id = "wpasses", Text = "Complete %d passes this week", Goal = 60, Event = "Pass", Coins = 1200 },
	{ Id = "wsaves", Text = "Make %d saves this week", Goal = 20, Event = "Save", Coins = 1200 },
}

-- MVP: Punkte pro Aktion im Match, Belohnung fuer den besten Spieler
Config.MVPPoints = { Goal = 3, Assist = 2, Save = 1.5, Steal = 1, KO = 1 }
Config.MVPCoins = 150

-- Pickups auf dem Feld (nur echte Spieler sammeln sie ein)
Config.CoinDropEvery = 20
Config.CoinDropMax = 3
Config.CoinDropValue = { 20, 50 }
Config.CoinDropLife = 30
Config.OrbEvery = 35
Config.OrbLife = 25
Config.Orbs = {
	{ Id = "Speed", Name = "SPEED ORB", Text = "+20% speed for 8 seconds", Color = Color3.fromRGB(40, 200, 255) },
	{ Id = "Power", Name = "POWER ORB", Text = "Your next kick is 40% harder", Color = Color3.fromRGB(255, 110, 30) },
	{ Id = "Heal", Name = "HEAL ORB", Text = "Full health", Color = Color3.fromRGB(90, 230, 90) },
}
Config.SpeedOrbSeconds = 8
Config.SpeedOrbFactor = 1.2
Config.PowerOrbFactor = 1.4

-- Abstimmung ueber den Modus des naechsten Matches (im Ergebnis-Fenster)
Config.Modes = {
	{ Id = "Classic", Name = "CLASSIC", Text = "The normal game" },
	{ Id = "LowGravity", Name = "LOW GRAVITY", Text = "Floaty jumps and long high balls", Gravity = 110 },
	{ Id = "Turbo", Name = "TURBO", Text = "Everyone runs 20% faster", Speed = 1.2 },
	{ Id = "MegaKicks", Name = "MEGA KICKS", Text = "All kicks are 25% harder", Kick = 1.25 },
}
Config.ModesById = {}
for _, mode in Config.Modes do
	Config.ModesById[mode.Id] = mode
end

-- Schnell-Chat: feste Sprueche ueber dem Kopf (keine freie Eingabe)
Config.QuickChat = { "PASS!", "NICE SHOT!", "DEFEND!", "GG", "SORRY!", "GO GO GO!", "WELL PLAYED!", "SHOOT!" }
Config.QuickChatCooldown = 2

-- Freunde-Bonus: mehr Coins, solange ein Freund auf dem Server ist
Config.FriendBonus = 1.2

-- Torjubel-Effekte (Partikel rund um den Torschuetzen), mit Coins kaufen
Config.Celebrations = {
	{ Id = "none", Name = "None", Price = 0, Colors = { Color3.fromRGB(255, 255, 255) } },
	{ Id = "confetti", Name = "Confetti", Price = 800, Colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 220, 60), Color3.fromRGB(60, 200, 255), Color3.fromRGB(120, 255, 120) } },
	{ Id = "stars", Name = "Stars", Price = 1200, Colors = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 255, 255) } },
	{ Id = "flames", Name = "Flames", Price = 1800, Colors = { Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 80, 0) } },
	{ Id = "lightning", Name = "Lightning", Price = 2500, Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(60, 180, 255) } },
	{ Id = "galaxy", Name = "Galaxy", Price = 3500, Colors = { Color3.fromRGB(170, 80, 255), Color3.fromRGB(40, 20, 120), Color3.fromRGB(255, 255, 255) } },
}
Config.CelebrationsById = {}
for index, celebration in Config.Celebrations do
	celebration.Order = index
	Config.CelebrationsById[celebration.Id] = celebration
end

---------------------------------------------------------------- Monetarisierung

-- "Gamepasses" werden als Developer Products verkauft und dauerhaft gespeichert
-- (der API-Schluessel kann keine echten Gamepasses anlegen). ProductName = Name in products.json.
Config.GamePasses = {
	VIP = { ProductName = "VIP", Name = "VIP", Description = "+200 start EXP, x1.5 coins, golden name, VIP tag + Golden trail", PriceHint = 199, Order = 1 },
	DoubleXP = { ProductName = "Double XP", Name = "Double XP", Description = "2x match EXP and 2x account XP", PriceHint = 249, Order = 2 },
	DoubleCoins = { ProductName = "Double Coins", Name = "Double Coins", Description = "Earn twice the coins", PriceHint = 199, Order = 3 },
	ProBoots = { ProductName = "Pro Boots", Name = "Pro Boots", Description = "+1 level on ALL 5 upgrades in every match, even above max", PriceHint = 299, Order = 4 },
	EffectsPack = { ProductName = "Effects Pack", Name = "Effects Pack", Description = "3 animated kick trails: Rainbow, Galaxy, Lightning", PriceHint = 149, Order = 5 },
	GoldenKnife = { ProductName = "Golden Knife", Name = "Golden Katana", Description = "+35% sword damage and a glowing golden blade", PriceHint = 349, Order = 6 },
	IronBody = { ProductName = "Iron Body", Name = "Iron Body", Description = "+50 max health in every match", PriceHint = 249, Order = 7 },
	CannonShot = { ProductName = "Cannon Shot", Name = "Cannon Shot", Description = "All your kicks are 20% harder", PriceHint = 249, Order = 8 },
	SpeedDemon = { ProductName = "Speed Demon", Name = "Speed Demon", Description = "Run 12% faster in every match", PriceHint = 249, Order = 9 },
	TurboLungs = { ProductName = "Turbo Lungs", Name = "Turbo Lungs", Description = "+50% turbo stamina and faster recovery", PriceHint = 199, Order = 10 },
	MagnetFeet = { ProductName = "Magnet Feet", Name = "Magnet Feet", Description = "Grab loose balls from 40% farther away", PriceHint = 249, Order = 11 },
	IronGrip = { ProductName = "Iron Grip", Name = "Iron Grip", Description = "Sword hits make you drop the ball half as often", PriceHint = 249, Order = 12 },
	SteelKeeper = { ProductName = "Steel Keeper", Name = "Steel Keeper", Description = "Catch shots that are 25% harder", PriceHint = 199, Order = 13 },
	QuickRespawn = { ProductName = "Quick Respawn", Name = "Quick Respawn", Description = "Respawn after 4 seconds instead of 10", PriceHint = 149, Order = 14 },
	VampireKnife = { ProductName = "Vampire Knife", Name = "Vampire Blade", Description = "Heal 50% of the sword damage you deal", PriceHint = 299, Order = 15 },
	SwordPack = { ProductName = "Sword Pack", Name = "Sword Pack", Description = "3 exclusive katanas: Dragon, Void and Prism", PriceHint = 299, Order = 17 },
	QuestMaster = { ProductName = "Quest Master", Name = "Quest Master", Description = "Double quest rewards and a 4th daily quest", PriceHint = 199, Order = 18 },
	Ninja = { ProductName = "Ninja", Name = "Ninja", Description = "Backstabs from a wider angle and 30% faster stab", PriceHint = 249, Order = 16 },
}

Config.DevProducts = {
	Coins1 = { ProductName = "Coin Pouch", Kind = "Coins", Coins = 600, Name = "600 Coins", PriceHint = 49, Order = 1 },
	Coins2 = { ProductName = "Coin Bag", Kind = "Coins", Coins = 1800, Name = "1,800 Coins", PriceHint = 129, Order = 2 },
	Coins3 = { ProductName = "Coin Chest", Kind = "Coins", Coins = 5500, Name = "5,500 Coins", PriceHint = 349, Order = 3 },
	MatchEXP = { ProductName = "+600 Match EXP", Kind = "MatchEXP", EXP = 600, Name = "+600 EXP", Description = "Upgrade your skills right now (this match)", PriceHint = 39, Order = 4 },
	MaxUpgrades = { ProductName = "Max All Upgrades", Kind = "MaxUpgrades", Name = "MAX ALL", Description = "All 5 upgrades to max level for this match", PriceHint = 149, Order = 5 },
	XPBoost = { ProductName = "XP Boost 30 min", Kind = "XPBoost", Name = "2x XP for 30 min", PriceHint = 39, Order = 6 },
	Shield = { ProductName = "Bubble Shield", Kind = "Shield", Seconds = 30, Name = "Bubble Shield", Description = "No damage for 30 seconds", PriceHint = 49, Order = 8 },
	Rage = { ProductName = "Rage Mode", Kind = "Rage", Seconds = 60, Name = "Rage Mode", Description = "60 seconds: +25% speed and +25% sword damage", PriceHint = 49, Order = 9 },
	RocketShot = { ProductName = "Rocket Shot", Kind = "RocketShot", Shots = 3, Name = "Rocket Shot", Description = "Your next 3 kicks are 60% harder", PriceHint = 29, Order = 10 },
	TeamBoost = { ProductName = "Team Boost", Kind = "TeamBoost", Seconds = 120, Name = "Team Boost", Description = "Your whole team runs 10% faster for 2 minutes", PriceHint = 79, Order = 11 },
	Giant = { ProductName = "Giant Mode", Kind = "Giant", Seconds = 60, Name = "Giant Mode", Description = "60 seconds: 30% bigger with longer sword reach", PriceHint = 49, Order = 12 },
	RespawnNow = { ProductName = "Respawn Now", Kind = "RespawnNow", Name = "Respawn Now", Description = "Skip the knockout wait and get back in instantly", PriceHint = 19, Order = 13 },
	Fireworks = { ProductName = "Stadium Fireworks", Kind = "Fireworks", Name = "Stadium Fireworks", Description = "Light up the whole stadium", PriceHint = 29, Order = 7 },
	StarterPack = { ProductName = "Starter Pack", Kind = "StarterPack", Coins = 2500, EXP = 1000, Name = "Starter Pack", Description = "One time: 2,500 coins + 1,000 match EXP + Starter trail", PriceHint = 79, Hidden = true },
	AdCoins = { ProductName = "Free Coins (Video Ad)", Kind = "AdCoins", Coins = 150, Name = "Free Coins", PriceHint = 5, Hidden = true },
}

-- In Studio Kaeufe mit ID 0 simulieren, damit alles testbar ist
Config.StudioFakePurchases = true

-- Produkt-IDs eintragen (Schluessel = key in products.json, z. B. "Pass_VIP" oder "Coins1")
local idsModule = script.Parent:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

-- Spieler sind fest (kein Durchlaufen), duerfen aber nicht auf anderen stehen: steht jemand auf einem
-- Kopf/Koerper, rutscht er seitlich herunter. Laeuft fuer den eigenen Charakter (Client) und fuer Bots (Server).
local headParams = RaycastParams.new()
headParams.FilterType = Enum.RaycastFilterType.Exclude
function Config.SlideOffHeads(model: Model, root: BasePart)
	headParams.FilterDescendantsInstances = { model }
	local result = workspace:Spherecast(root.Position, 1.2, Vector3.new(0, -4.5, 0), headParams)
	if not result then
		return
	end
	local node: Instance? = result.Instance
	local other: Model? = nil
	while node and node ~= workspace do
		if node:IsA("Model") and node:FindFirstChildOfClass("Humanoid") then
			other = node
			break
		end
		node = node.Parent
	end
	local otherRoot = other and other:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not otherRoot then
		return
	end
	local away = root.Position - otherRoot.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.05 then
		away = root.CFrame.LookVector
	end
	local push = away.Unit * 20
	root.AssemblyLinearVelocity = Vector3.new(push.X, math.min(root.AssemblyLinearVelocity.Y, -8), push.Z)
end

return Config
