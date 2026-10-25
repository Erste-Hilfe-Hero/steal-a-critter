-- Zentrale Einstellungen fuer surf_ski: Stages, Belohnungen, Kosmetik und Monetarisierung.
-- Produkt-IDs kommen aus ProductIds.json (schreibt die GitHub Action beim Veroeffentlichen).
-- Solange eine ID fehlt, kann man den Kauf in Studio ueber den Shop simulieren.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = {}

Config.DataStoreName = "SurfData_v1"
Config.BestTimeStore = "SurfBestTimes_v1" -- OrderedDataStore, ganze Map in Millisekunden
Config.StageStorePrefix = "SurfStage_v1_" -- OrderedDataStore pro Stage
Config.OwnerUserIds = { 2979321382 }
Config.StudioFakePurchases = true

-- Farben des "Alpine Aurora"-Stils (UI, Map, Logo)
Config.Theme = {
	Navy = Color3.fromRGB(11, 21, 48),
	Panel = Color3.fromRGB(16, 30, 64),
	PanelLight = Color3.fromRGB(28, 48, 92),
	Ice = Color3.fromRGB(92, 225, 255),
	Aurora = Color3.fromRGB(255, 79, 163),
	Mint = Color3.fromRGB(110, 255, 190),
	Gold = Color3.fromRGB(255, 205, 64),
	Snow = Color3.fromRGB(240, 248, 255),
	Red = Color3.fromRGB(255, 90, 100),
	Muted = Color3.fromRGB(150, 175, 215),
}

---------------------------------------------------------------- Map

-- Jede Stage ist eine eigene Bahn aus abfallenden Surf-Rampen (Dachform), gebaut von WorldService.
-- Ramps: Anzahl Rampen. Width: Breite einer Rampe (beide Seiten), Height: Hoehe, Length: Laenge,
-- Pitch: Gefaelle in Laufrichtung (Grad), Gap: Abstand zur naechsten Rampe, Drop: wie tief die naechste Rampe
-- liegt (Anteil der Rampenhoehe; unter 1 muss man oben auf der Rampe bleiben, sonst prallt man an die Stirnseite),
-- Shift: seitlicher Versatz (Spieler muessen lenken). Alles mit Zufall aus Seed, aber immer gleich gebaut.
Config.Stages = {
	{ Name = "Bunny Hill", Ramps = 3, Width = 44, Height = 30, Length = 170, Pitch = 11, Gap = { 18, 24 }, Drop = { 1.0, 1.1 }, Shift = { 0, 6 }, Seed = 11, Color = Color3.fromRGB(235, 245, 255), Accent = Color3.fromRGB(92, 225, 255) },
	{ Name = "Powder Run", Ramps = 4, Width = 40, Height = 30, Length = 170, Pitch = 10, Gap = { 20, 28 }, Drop = { 0.95, 1.05 }, Shift = { 4, 12 }, Seed = 23, Color = Color3.fromRGB(230, 242, 255), Accent = Color3.fromRGB(110, 255, 190) },
	{ Name = "Glacier Gap", Ramps = 4, Width = 38, Height = 30, Length = 180, Pitch = 10, Gap = { 24, 34 }, Drop = { 0.9, 1.0 }, Shift = { 6, 16 }, Seed = 37, Color = Color3.fromRGB(190, 230, 255), Accent = Color3.fromRGB(92, 225, 255) },
	{ Name = "Pine Slalom", Ramps = 5, Width = 36, Height = 30, Length = 170, Pitch = 10, Gap = { 24, 34 }, Drop = { 0.85, 1.0 }, Shift = { 10, 20 }, Seed = 41, Color = Color3.fromRGB(225, 245, 235), Accent = Color3.fromRGB(110, 255, 160) },
	{ Name = "Avalanche", Ramps = 5, Width = 36, Height = 32, Length = 190, Pitch = 12, Gap = { 28, 38 }, Drop = { 0.8, 0.95 }, Shift = { 8, 18 }, Seed = 53, Color = Color3.fromRGB(240, 240, 250), Accent = Color3.fromRGB(255, 120, 120) },
	{ Name = "Frozen Falls", Ramps = 5, Width = 34, Height = 30, Length = 180, Pitch = 10, Gap = { 30, 40 }, Drop = { 0.8, 0.95 }, Shift = { 12, 22 }, Seed = 67, Color = Color3.fromRGB(170, 220, 255), Accent = Color3.fromRGB(150, 160, 255) },
	{ Name = "Ice Cathedral", Ramps = 6, Width = 34, Height = 32, Length = 180, Pitch = 11, Gap = { 30, 42 }, Drop = { 0.75, 0.9 }, Shift = { 10, 22 }, Seed = 71, Color = Color3.fromRGB(200, 235, 255), Accent = Color3.fromRGB(190, 120, 255) },
	{ Name = "Summit Spine", Ramps = 6, Width = 32, Height = 32, Length = 190, Pitch = 11, Gap = { 32, 44 }, Drop = { 0.7, 0.9 }, Shift = { 14, 26 }, Seed = 83, Color = Color3.fromRGB(235, 240, 255), Accent = Color3.fromRGB(255, 79, 163) },
	{ Name = "Aurora Drop", Ramps = 6, Width = 30, Height = 32, Length = 200, Pitch = 12, Gap = { 34, 46 }, Drop = { 0.7, 0.85 }, Shift = { 14, 28 }, Seed = 97, Color = Color3.fromRGB(215, 225, 255), Accent = Color3.fromRGB(255, 79, 163) },
	{ Name = "Black Diamond", Ramps = 7, Width = 28, Height = 32, Length = 200, Pitch = 12, Gap = { 36, 48 }, Drop = { 0.65, 0.8 }, Shift = { 16, 30 }, Seed = 101, Color = Color3.fromRGB(200, 205, 225), Accent = Color3.fromRGB(255, 205, 64) },
}
Config.StageSpacing = 900 -- Abstand der Bahnen (Z)
Config.StageHeight = 900 -- Starthoehe jeder Bahn
Config.MinStageSeconds = 2.5 -- schneller ist unmoeglich = Schummelversuch
Config.FinishTolerance = 260 -- so weit darf die vom Server gesehene Position vom Ziel entfernt sein (Latenz)
Config.StartTolerance = 60 -- "Startzone verlassen" nur so nah an der Startzone (Latenz + Anlauftempo)
Config.LobbyCenter = Vector3.new(0, 600, -900)

---------------------------------------------------------------- Belohnungen (Schneeflocken)

Config.Rewards = {
	StageFirst = function(stage: number): number
		return 60 * stage
	end,
	StageRepeat = function(stage: number): number
		return 6 + 2 * stage
	end,
	MapFirst = 1500,
	MapRepeat = 250,
	PersonalBest = 150,
	PerMinute = 5, -- aktive Spielzeit
}
Config.VipMultiplier = 1.5
Config.DoubleFlakesMultiplier = 2
Config.PremiumMultiplier = 1.2
Config.AdCooldown = 180

-- Taegliche Belohnung (Serie 1-7 Tage, danach von vorn)
function Config.DailyReward(streak: number): number
	return 100 * streak * streak
end

-- Raenge nach Stage-Abschluessen (wie die Rang-Listen auf CS-Surf-Servern)
Config.Ranks = {
	{ Name = "Newbie", Clears = 0, Color = Color3.fromRGB(190, 200, 215) },
	{ Name = "Rookie", Clears = 10, Color = Color3.fromRGB(140, 230, 255) },
	{ Name = "Surfer", Clears = 50, Color = Color3.fromRGB(110, 255, 190) },
	{ Name = "Pro", Clears = 150, Color = Color3.fromRGB(255, 205, 64) },
	{ Name = "Elite", Clears = 400, Color = Color3.fromRGB(255, 120, 90) },
	{ Name = "Legend", Clears = 1000, Color = Color3.fromRGB(255, 79, 163) },
}

---------------------------------------------------------------- Kosmetik

-- Trails: Farbverlauf hinter dem Spieler. Price = Schneeflocken, Pass = nur mit diesem Pass
Config.Trails = {
	{ Id = "none", Name = "No Trail", Price = 0, Colors = { Color3.new(1, 1, 1) } },
	{ Id = "frost", Name = "Frost", Price = 0, Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(92, 225, 255) } },
	{ Id = "mint", Name = "Mint", Price = 800, Colors = { Color3.fromRGB(110, 255, 190), Color3.fromRGB(40, 160, 255) } },
	{ Id = "sunset", Name = "Sunset", Price = 2500, Colors = { Color3.fromRGB(255, 200, 64), Color3.fromRGB(255, 79, 120) } },
	{ Id = "aurora", Name = "Aurora", Price = 6000, Colors = { Color3.fromRGB(110, 255, 190), Color3.fromRGB(92, 160, 255), Color3.fromRGB(255, 79, 163) } },
	{ Id = "ember", Name = "Ember", Price = 12000, Colors = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 90, 30) } },
	{ Id = "galaxy", Name = "Galaxy", Price = 30000, Colors = { Color3.fromRGB(120, 60, 255), Color3.fromRGB(255, 79, 200), Color3.fromRGB(80, 220, 255) } },
	{ Id = "ice", Name = "Ice Crystal", Pass = "StarterPack", Colors = { Color3.fromRGB(200, 250, 255), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 255, 255) } },
	{ Id = "gold", Name = "VIP Gold", Pass = "VIP", Colors = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 190, 40) } },
	{ Id = "rainbow", Name = "Rainbow", Pass = "TrailPack", Colors = { Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 220, 60), Color3.fromRGB(80, 255, 120), Color3.fromRGB(70, 160, 255), Color3.fromRGB(200, 80, 255) } },
	{ Id = "neon", Name = "Neon Pulse", Pass = "TrailPack", Colors = { Color3.fromRGB(0, 255, 200), Color3.fromRGB(0, 120, 255) } },
	{ Id = "lava", Name = "Lava", Pass = "TrailPack", Colors = { Color3.fromRGB(255, 255, 120), Color3.fromRGB(255, 60, 0), Color3.fromRGB(120, 0, 0) } },
}

-- Skier an den Fuessen (das "ski" in surf_ski)
Config.Skis = {
	{ Id = "classic", Name = "Classic Red", Price = 0, Color = Color3.fromRGB(230, 50, 60) },
	{ Id = "white", Name = "Snow White", Price = 500, Color = Color3.fromRGB(245, 248, 255) },
	{ Id = "ice", Name = "Ice Blue", Price = 1500, Color = Color3.fromRGB(92, 225, 255) },
	{ Id = "mint", Name = "Mint", Price = 3000, Color = Color3.fromRGB(110, 255, 190) },
	{ Id = "pink", Name = "Aurora Pink", Price = 6000, Color = Color3.fromRGB(255, 79, 163) },
	{ Id = "black", Name = "Carbon", Price = 15000, Color = Color3.fromRGB(30, 32, 40) },
	{ Id = "gold", Name = "VIP Gold", Pass = "VIP", Color = Color3.fromRGB(255, 200, 50), Material = Enum.Material.Foil },
	{ Id = "neon", Name = "Neon", Pass = "TrailPack", Color = Color3.fromRGB(0, 255, 200), Material = Enum.Material.Neon },
}

---------------------------------------------------------------- Monetarisierung

-- Dauerhafte Vorteile (als Developer Products verkauft und gespeichert)
Config.GamePasses = {
	VIP = { Name = "VIP", Description = "x1.5 Snowflakes, gold name, VIP Gold trail and skis", PriceHint = 249, Order = 1 },
	DoubleFlakes = { Name = "2x Snowflakes", Description = "Double Snowflakes from everything forever", PriceHint = 199, Order = 2 },
	Practice = { Name = "Checkpoints", Description = "Save and load checkpoints anywhere (practice runs)", PriceHint = 149, Order = 3 },
	TrailPack = { Name = "Trail Pack", Description = "Rainbow, Neon Pulse and Lava trails + Neon skis", PriceHint = 199, Order = 4 },
}

-- Developer Products: beliebig oft kaufbar, immer genau das, was angezeigt wird (kein Zufall)
Config.DevProducts = {
	FlakesSmall = { Kind = "Flakes", Amount = 1_000, Name = "Snowflake Bag", Description = "1,000 Snowflakes", PriceHint = 49, Order = 1 },
	FlakesMedium = { Kind = "Flakes", Amount = 6_000, Name = "Snowflake Sled", Description = "6,000 Snowflakes", PriceHint = 199, Order = 2 },
	FlakesLarge = { Kind = "Flakes", Amount = 20_000, Name = "Snowflake Avalanche", Description = "20,000 Snowflakes", PriceHint = 499, Order = 3 },
	SkipStage = { Kind = "SkipStage", Name = "Skip Stage", Description = "Jump to the next stage (run becomes unranked)", PriceHint = 19, Order = 4 },
	LowGravity = { Kind = "LowGravity", Seconds = 180, Name = "Moon Gravity Party", Description = "3 min low gravity for the WHOLE server", PriceHint = 99, Order = 5 },
	StarterPack = { Kind = "StarterPack", Amount = 3_000, Name = "Starter Pack", Description = "One time: 3,000 Snowflakes + Ice Crystal trail", PriceHint = 79, Order = 0, Hidden = true },
	FlakeBoost = { Kind = "Boost", Seconds = 1800, Name = "Flake Booster", Description = "2x Snowflakes for 30 minutes (stacks with everything)", PriceHint = 49, Order = 6 },
	AdReward = { Kind = "Flakes", Amount = 300, Name = "Free Snowflakes", Description = "Watch a short video ad", PriceHint = 0, Hidden = true },
}
Config.LowGravityScale = 0.35

-- IDs aus ProductIds.json einsetzen (fehlende = 0, dann nur in Studio simulierbar)
local idsModule = ReplicatedStorage.Shared:FindFirstChild("ProductIds")
local ids = if idsModule then require(idsModule) :: any else {}
for key, pass in Config.GamePasses do
	pass.ProductId = tonumber(ids["Pass_" .. key]) or 0
end
for key, product in Config.DevProducts do
	product.Id = tonumber(ids[key]) or 0
end

Config.TrailsById = {}
for _, trail in Config.Trails do
	Config.TrailsById[trail.Id] = trail
end
Config.SkisById = {}
for _, ski in Config.Skis do
	Config.SkisById[ski.Id] = ski
end

function Config.RankFor(clears: number)
	local index = 1
	for i, rank in Config.Ranks do
		if clears >= rank.Clears then
			index = i
		end
	end
	return index, Config.Ranks[index]
end

return Config
