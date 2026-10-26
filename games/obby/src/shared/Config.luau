-- Zentrale Spiel- und Monetarisierungs-Einstellungen fuer Mega Rainbow Obby.
-- Produkt-IDs muessen nicht eingetragen werden: der Server sucht die Developer Products
-- beim Start ueber ihren Namen (products.json). Eine ID hier hat Vorrang.
-- Solange keine ID gefunden wird, kann man Kaeufe in Studio ueber den Shop simulieren.

local Config = {}

Config.DataStoreName = "ObbyData_v1"

-- Strecke
Config.StagesPerWorld = 10
Config.PadSize = Vector3.new(14, 1.2, 14)
Config.RisePerStage = 1.5 -- Hoehe, die jede Stage nach oben geht
Config.FallDistance = 35 -- so tief unter dem Checkpoint gilt man als heruntergefallen

-- Welten: je 10 Stages, Schwierigkeit steigt ueber alle 100 Stages
Config.Worlds = {
	{ Name = "Candy Land", Floor = Color3.fromRGB(255, 170, 210), Accent = Color3.fromRGB(120, 230, 255), Sky = Color3.fromRGB(255, 220, 240) },
	{ Name = "Jungle Jumps", Floor = Color3.fromRGB(90, 190, 80), Accent = Color3.fromRGB(150, 100, 60), Sky = Color3.fromRGB(190, 240, 190) },
	{ Name = "Desert Dash", Floor = Color3.fromRGB(240, 200, 120), Accent = Color3.fromRGB(200, 120, 60), Sky = Color3.fromRGB(255, 230, 180) },
	{ Name = "Ice Peaks", Floor = Color3.fromRGB(190, 235, 255), Accent = Color3.fromRGB(90, 160, 255), Sky = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Ice },
	{ Name = "Lava Lair", Floor = Color3.fromRGB(70, 60, 60), Accent = Color3.fromRGB(255, 120, 40), Sky = Color3.fromRGB(255, 160, 120) },
	{ Name = "Ocean Odyssey", Floor = Color3.fromRGB(60, 140, 220), Accent = Color3.fromRGB(250, 240, 200), Sky = Color3.fromRGB(170, 220, 255) },
	{ Name = "Neon City", Floor = Color3.fromRGB(40, 40, 60), Accent = Color3.fromRGB(0, 255, 200), Sky = Color3.fromRGB(80, 60, 140), Material = Enum.Material.Neon, Night = true },
	{ Name = "Cloud Kingdom", Floor = Color3.fromRGB(250, 250, 255), Accent = Color3.fromRGB(255, 220, 90), Sky = Color3.fromRGB(200, 230, 255) },
	{ Name = "Outer Space", Floor = Color3.fromRGB(70, 60, 120), Accent = Color3.fromRGB(200, 120, 255), Sky = Color3.fromRGB(30, 20, 60), Night = true },
	{ Name = "Rainbow Road", Floor = Color3.fromRGB(255, 255, 255), Accent = Color3.fromRGB(255, 80, 80), Sky = Color3.fromRGB(255, 240, 200), Rainbow = true },
}
Config.StageCount = #Config.Worlds * Config.StagesPerWorld

Config.KillColor = Color3.fromRGB(255, 40, 40)

-- Bewegung
Config.DefaultWalkSpeed = 16
Config.SpeedCoilWalkSpeed = 28
Config.GravityCoilFactor = 0.45 -- Anteil der Schwerkraft, der mit Coil noch wirkt

-- Trails: frei durch Fortschritt, VIP oder Trail Pack
Config.Trails = {
	{ Id = "white", Name = "Cloud", Colors = { Color3.fromRGB(255, 255, 255) }, Unlock = { Best = 1 } },
	{ Id = "mint", Name = "Mint", Colors = { Color3.fromRGB(120, 255, 200), Color3.fromRGB(60, 200, 255) }, Unlock = { Best = 10 } },
	{ Id = "candy", Name = "Candy", Colors = { Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 255, 255) }, Unlock = { Best = 25 } },
	{ Id = "jungle", Name = "Jungle", Colors = { Color3.fromRGB(80, 220, 80), Color3.fromRGB(255, 230, 60) }, Unlock = { Best = 50 } },
	{ Id = "frost", Name = "Frost", Colors = { Color3.fromRGB(200, 240, 255), Color3.fromRGB(80, 140, 255) }, Unlock = { Best = 75 } },
	{ Id = "champion", Name = "Champion", Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 200, 40) }, Unlock = { Wins = 1 } },
	{ Id = "legend", Name = "Legend", Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 160, 40) }, Unlock = { Wins = 5 } },
	{ Id = "vip", Name = "Golden VIP", Colors = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(255, 150, 0) }, Unlock = { Pass = "VIP" } },
	{ Id = "rainbow", Name = "Rainbow", Colors = { Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 200, 40), Color3.fromRGB(60, 220, 90), Color3.fromRGB(60, 140, 255), Color3.fromRGB(180, 80, 255) }, Unlock = { Pass = "TrailPack" } },
	{ Id = "galaxy", Name = "Galaxy", Colors = { Color3.fromRGB(40, 20, 100), Color3.fromRGB(200, 100, 255), Color3.fromRGB(255, 255, 255) }, Unlock = { Pass = "TrailPack" } },
	{ Id = "fire", Name = "Inferno", Colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 80, 0) }, Unlock = { Pass = "TrailPack" } },
	{ Id = "toxic", Name = "Toxic", Colors = { Color3.fromRGB(180, 255, 40), Color3.fromRGB(40, 120, 20) }, Unlock = { Pass = "TrailPack" } },
	{ Id = "ocean", Name = "Ocean", Colors = { Color3.fromRGB(0, 220, 255), Color3.fromRGB(0, 60, 200) }, Unlock = { Pass = "TrailPack" } },
	{ Id = "shadow", Name = "Shadow", Colors = { Color3.fromRGB(20, 20, 30), Color3.fromRGB(120, 0, 200) }, Unlock = { Pass = "TrailPack" } },
	-- Mit Coins kaufbar (einmal kaufen, fuer immer behalten)
	{ Id = "bubblegum", Name = "Bubblegum", Colors = { Color3.fromRGB(255, 150, 220), Color3.fromRGB(150, 220, 255) }, Unlock = { Coins = 500 } },
	{ Id = "sunset", Name = "Sunset", Colors = { Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 110, 80), Color3.fromRGB(170, 60, 160) }, Unlock = { Coins = 1000 } },
	{ Id = "aurora", Name = "Aurora", Colors = { Color3.fromRGB(80, 255, 170), Color3.fromRGB(60, 160, 255), Color3.fromRGB(200, 110, 255) }, Unlock = { Coins = 2000 } },
	{ Id = "diamond", Name = "Diamond", Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 240, 255), Color3.fromRGB(255, 255, 255) }, Unlock = { Coins = 4000 } },
}

-- "Gamepasses" werden als Developer Products verkauft und dauerhaft gespeichert
-- (der API-Schluessel kann keine echten Gamepasses anlegen). ProductName = Name in products.json.
Config.GamePasses = {
	VIP = { ProductId = 3721935421, ProductName = "VIP", Name = "VIP", Description = "Golden name, VIP tag, VIP trail + 50% more coins", PriceHint = 199, Order = 1 },
	DoubleJump = { ProductId = 3721935425, ProductName = "Double Jump", Name = "Double Jump", Description = "Jump again in mid-air", PriceHint = 199, Order = 2 },
	GravityCoil = { ProductId = 3721935430, ProductName = "Gravity Coil", Name = "Gravity Coil", Description = "Equip to jump way higher", PriceHint = 149, Order = 3 },
	SpeedCoil = { ProductId = 3721935433, ProductName = "Speed Coil", Name = "Speed Coil", Description = "Equip to run much faster", PriceHint = 99, Order = 4 },
	TrailPack = { ProductId = 3721935439, ProductName = "Trail Pack", Name = "Trail Pack", Description = "Unlock all 6 premium trails", PriceHint = 149, Order = 5 },
}

-- Developer Products: beliebig oft kaufbar
Config.DevProducts = {
	SkipStage = { Id = 3721935444, ProductName = "Skip Stage", Kind = "Skip", Stages = 1, Name = "Skip Stage", Description = "Go to the next stage", PriceHint = 19, Order = 1 },
	Skip5 = { Id = 3721935453, ProductName = "Skip 5 Stages", Kind = "Skip", Stages = 5, Name = "Skip 5 Stages", Description = "Jump 5 stages ahead", PriceHint = 79, Order = 2 },
	Skip10 = { Id = 3721935449, ProductName = "Skip 10 Stages", Kind = "Skip", Stages = 10, Name = "Skip 10 Stages", Description = "Jump 10 stages ahead (best deal!)", PriceHint = 129, Order = 3 },
	KillAll = { Id = 3721935457, ProductName = "Kill Everyone", Kind = "KillAll", Name = "Kill Everyone", Description = "Troll! Everyone else respawns at their checkpoint", PriceHint = 49, Order = 4 },
	-- Neu: ID wird zur Laufzeit ueber den Namen gefunden (products.json)
	CoinPack = { Id = 0, ProductName = "Coin Pack", Kind = "Coins", Amount = 1000, Name = "1,000 Coins", Description = "Coins for trails in the Trails menu", PriceHint = 49, Order = 5 },
}

Config.PremiumBadge = true -- Premium-Spieler bekommen ein Abzeichen am Namen (erhoeht Premium Payouts durch Spielzeit)

-- Community-Raenge: nur aktive Spielzeit zaehlt (wer 2 Minuten nichts tut, gilt als AFK).
-- Rechte bauen aufeinander auf: jeder Rang hat auch alle Rechte der Raenge darunter.
Config.OwnerUserIds = { 2979321382 } -- BigBabaAli: alle Rechte, kann bannen und Raenge entziehen
Config.AfkTimeout = 120
Config.Ranks = {
	{ Name = "Newbie", Hours = 0, Days = 0, Color = "#C8C8C8", Rights = {} },
	{ Name = "Member", Hours = 1, Days = 1, Color = "#78DCFF", Rights = { Vote = true } },
	{ Name = "Regular", Hours = 5, Days = 3, Color = "#55DC6E", Rights = { VoteKick = true } },
	{ Name = "Veteran", Hours = 20, Days = 7, Color = "#B450FF", Rights = { Announce = true } },
	{ Name = "Guardian", Hours = 50, Days = 14, Color = "#FFBE28", Rights = { Kick = true } },
}
Config.VoteKickDuration = 30
Config.VoteKickMinVotes = 3
Config.AnnounceCooldown = 600
Config.GuardianKickCooldown = 60

---------------------------------------------------------------- Coins, Belohnungen, Quests, Titel

Config.CoinsPerCheckpoint = 4 -- plus Weltnummer (Welt 10 = 14 Coins pro Checkpoint)
Config.CoinsPerWin = 300
Config.VipCoinMultiplier = 1.5
Config.MaxCheckpointJump = 3 -- so viele Checkpoints darf man hoechstens auf einmal weiter (Schutz gegen Teleport-Cheats)

-- Taegliche Belohnung: Tag 1..7, danach beginnt der Zyklus neu (Streak zaehlt weiter)
Config.DailyRewards = { 50, 75, 100, 125, 150, 200, 400 }

-- Taegliche Quests: jeden Tag eine zufaellige Stufe pro Typ
Config.QuestTypes = {
	{ Type = "Checkpoints", Targets = { 10, 20, 30 }, Rewards = { 60, 100, 150 }, Text = "Reach %d checkpoints" },
	{ Type = "Play", Targets = { 600, 1200, 1800 }, Rewards = { 50, 90, 130 }, Text = "Play for %d minutes", Minutes = true },
	{ Type = "Worlds", Targets = { 1, 2 }, Rewards = { 120, 200 }, Text = "Enter %d new world(s)" },
}

-- Gutscheincodes (Gross-/Kleinschreibung egal), jeder Code einmal pro Spieler
Config.Codes = {
	RAINBOW = 100,
	OBBY = 50,
	["100STAGES"] = 150,
}

-- Versteckte Regenbogen-Edelsteine: einer pro Welt neben diesem Checkpoint
Config.GemStageInWorld = 6
Config.GemReward = 150

-- Speedrun-Grenze fuer den Titel "Speedster" (Sekunden, ohne Skips)
Config.SpeedsterTime = 40 * 60

-- Erfolge: jeder schaltet einen Titel fuers Namensschild frei und gibt einmalig Coins
Config.Achievements = {
	{ Id = "first", Title = "First Steps", Description = "Reach stage 10", Reward = 50, Stat = "BestStage", Goal = 10 },
	{ Id = "hopper", Title = "World Hopper", Description = "Reach World 4 (stage 31)", Reward = 100, Stat = "BestStage", Goal = 31 },
	{ Id = "halfway", Title = "Halfway Hero", Description = "Reach stage 50", Reward = 150, Stat = "BestStage", Goal = 50 },
	{ Id = "almost", Title = "Almost There", Description = "Reach stage 90", Reward = 200, Stat = "BestStage", Goal = 90 },
	{ Id = "champion", Title = "Champion", Description = "Beat all 100 stages", Reward = 250, Stat = "Wins", Goal = 1 },
	{ Id = "master", Title = "Obby Master", Description = "Win 5 times", Reward = 500, Stat = "Wins", Goal = 5 },
	{ Id = "legend", Title = "Living Legend", Description = "Win 25 times", Reward = 1500, Stat = "Wins", Goal = 25 },
	{ Id = "gems", Title = "Gem Hunter", Description = "Find all 10 hidden rainbow gems", Reward = 500, Stat = "GemCount", Goal = 10 },
	{ Id = "speed", Title = "Speedster", Description = "Win a run in under 40:00 without skips", Reward = 400, Stat = "SpeedRun", Goal = 1 },
	{ Id = "stubborn", Title = "Never Give Up", Description = "Respawn 500 times", Reward = 150, Stat = "Deaths", Goal = 500 },
	{ Id = "loyal", Title = "Loyal Jumper", Description = "Claim the daily reward 7 days in a row", Reward = 300, Stat = "DailyStreak", Goal = 7 },
	{ Id = "rich", Title = "Coin Collector", Description = "Earn 5,000 coins in total", Reward = 250, Stat = "CoinsEarned", Goal = 5000 },
}

-- Einstellungen pro Spieler (gespeichert): Name -> Standardwert
Config.Settings = {
	{ Key = "Sounds", Name = "Sound effects", Default = true },
	{ Key = "Timer", Name = "Show speedrun timer", Default = true },
	{ Key = "HidePlayers", Name = "Hide other players", Default = false },
	{ Key = "DailyPopup", Name = "Show daily reward popup", Default = true },
}

-- Standard-Emotes von Roblox (funktionieren mit R15-Avataren ohne eigene Animationen)
Config.Emotes = {
	{ Id = "wave", Name = "Wave", Icon = "👋" },
	{ Id = "cheer", Name = "Cheer", Icon = "🙌" },
	{ Id = "point", Name = "Point", Icon = "👉" },
	{ Id = "laugh", Name = "Laugh", Icon = "😂" },
	{ Id = "dance", Name = "Dance 1", Icon = "💃" },
	{ Id = "dance2", Name = "Dance 2", Icon = "🕺" },
	{ Id = "dance3", Name = "Dance 3", Icon = "🎶" },
}

-- Sprungpads: Startgeschwindigkeit nach oben (Gipfel ca. 16 Studs ueber dem Pad)
Config.BounceVelocity = 80

-- In Studio Kaeufe ohne ID simulieren, damit alles testbar ist
-- Computer-Laeufer (RunnerService): fuellen den Server auf, solange wenige echte Spieler da sind
Config.Runners = {
	FillUntilPlayers = 4, -- Laeufer = FillUntilPlayers - Spieler (hoechstens Max)
	Max = 3,
	SpawnInterval = 4, -- Sekunden zwischen zwei neuen Laeufern
	Skill = { 0.15, 0.95 },
	RestTime = { 0.5, 2.2 }, -- Pause am Checkpoint
	FailChance = { 0.08, 0.3 }, -- Chance pro Stage herunterzufallen (Welt 1 .. Welt 10)
	MaxLead = 4, -- so viele Stages darf ein Laeufer vor seinem Spieler sein, dann wartet er
	MaxBehind = 10, -- liegt er weiter zurueck, springt er zu seinem Spieler
	AnnounceCooldown = 120,
	Names = { "Jumpy Jay", "Robo Rita", "Speedy Sue", "Bouncy Bo", "Turbo Tia", "Ninja Nico", "Pixel Pam", "Captain Hop", "Lucky Lou", "Dizzy Dex" },
}

Config.StudioFakePurchases = true

-- Lookup-Tabellen
Config.TrailsById = {}
for index, trail in Config.Trails do
	trail.Order = index
	Config.TrailsById[trail.Id] = trail
end
Config.AchievementsById = {}
for index, achievement in Config.Achievements do
	achievement.Order = index
	Config.AchievementsById[achievement.Id] = achievement
end
Config.SettingsByKey = {}
for _, setting in Config.Settings do
	Config.SettingsByKey[setting.Key] = setting
end

function Config.WorldForStage(stage: number)
	local index = math.clamp((stage - 1) // Config.StagesPerWorld + 1, 1, #Config.Worlds)
	return Config.Worlds[index], index
end

-- Kann der Spieler diesen Trail tragen? (best = beste Stage, wins = Siege, hasPass(key) -> boolean,
-- owned = mit Coins gekaufte Trails)
function Config.TrailUnlocked(trail, best: number, wins: number, hasPass: (string) -> boolean, owned: { [string]: boolean }?): boolean
	local unlock = trail.Unlock
	if unlock.Coins then
		return owned ~= nil and owned[trail.Id] == true
	end
	if unlock.Pass then
		return hasPass(unlock.Pass)
	end
	if unlock.Wins then
		return wins >= unlock.Wins
	end
	return best >= (unlock.Best or 1)
end

-- Gem-Nummer (1..10) -> Bit in der Gem-Maske
function Config.HasGem(mask: number, world: number): boolean
	return bit32.btest(mask, bit32.lshift(1, world - 1))
end

function Config.CountGems(mask: number): number
	local count = 0
	for world = 1, #Config.Worlds do
		if Config.HasGem(mask, world) then
			count += 1
		end
	end
	return count
end

-- Zeit als m:ss.t (Speedrun)
function Config.FormatRunTime(seconds: number): string
	seconds = math.max(0, seconds)
	local minutes = seconds // 60
	local rest = seconds - minutes * 60
	if minutes >= 60 then
		return string.format("%d:%02d:%04.1f", minutes // 60, minutes % 60, rest)
	end
	return string.format("%d:%04.1f", minutes, rest)
end

return Config
