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
}

-- "Gamepasses" werden als Developer Products verkauft und dauerhaft gespeichert
-- (der API-Schluessel kann keine echten Gamepasses anlegen). ProductName = Name in products.json.
Config.GamePasses = {
	VIP = { ProductId = 0, ProductName = "VIP", Name = "VIP", Description = "Golden name, [VIP] chat tag + Golden VIP trail", PriceHint = 199, Order = 1 },
	DoubleJump = { ProductId = 0, ProductName = "Double Jump", Name = "Double Jump", Description = "Jump again in mid-air", PriceHint = 199, Order = 2 },
	GravityCoil = { ProductId = 0, ProductName = "Gravity Coil", Name = "Gravity Coil", Description = "Equip to jump way higher", PriceHint = 149, Order = 3 },
	SpeedCoil = { ProductId = 0, ProductName = "Speed Coil", Name = "Speed Coil", Description = "Equip to run much faster", PriceHint = 99, Order = 4 },
	TrailPack = { ProductId = 0, ProductName = "Trail Pack", Name = "Trail Pack", Description = "Unlock all 6 premium trails", PriceHint = 149, Order = 5 },
}

-- Developer Products: beliebig oft kaufbar
Config.DevProducts = {
	SkipStage = { Id = 0, ProductName = "Skip Stage", Kind = "Skip", Stages = 1, Name = "Skip Stage", Description = "Go to the next stage", PriceHint = 19, Order = 1 },
	Skip5 = { Id = 0, ProductName = "Skip 5 Stages", Kind = "Skip", Stages = 5, Name = "Skip 5 Stages", Description = "Jump 5 stages ahead", PriceHint = 79, Order = 2 },
	Skip10 = { Id = 0, ProductName = "Skip 10 Stages", Kind = "Skip", Stages = 10, Name = "Skip 10 Stages", Description = "Jump 10 stages ahead (best deal!)", PriceHint = 129, Order = 3 },
	KillAll = { Id = 0, ProductName = "Kill Everyone", Kind = "KillAll", Name = "Kill Everyone", Description = "Troll! Everyone else respawns at their checkpoint", PriceHint = 49, Order = 4 },
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

-- In Studio Kaeufe ohne ID simulieren, damit alles testbar ist
Config.StudioFakePurchases = true

-- Lookup-Tabellen
Config.TrailsById = {}
for index, trail in Config.Trails do
	trail.Order = index
	Config.TrailsById[trail.Id] = trail
end

function Config.WorldForStage(stage: number)
	local index = math.clamp((stage - 1) // Config.StagesPerWorld + 1, 1, #Config.Worlds)
	return Config.Worlds[index], index
end

-- Kann der Spieler diesen Trail tragen? (best = beste Stage, wins = Siege, hasPass(key) -> boolean)
function Config.TrailUnlocked(trail, best: number, wins: number, hasPass: (string) -> boolean): boolean
	local unlock = trail.Unlock
	if unlock.Pass then
		return hasPass(unlock.Pass)
	end
	if unlock.Wins then
		return wins >= unlock.Wins
	end
	return best >= (unlock.Best or 1)
end

return Config
