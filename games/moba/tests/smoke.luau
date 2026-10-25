-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft.
-- Server-Scripts starten dort nicht automatisch: der Test baut die Arena selbst, startet eine Runde
-- nur mit Bots, laesst sie eine Minute laufen und prueft Rollen, Minions, Dschungel, Zauber, Faehigkeiten, Tod und Respawn.
-- Jeder Laufzeitfehler (auch in Schleifen) wird ueber LogService eingesammelt und zaehlt als Fehler.
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local results = {}
local failed = 0
local function check(name, ok, detail)
	if not ok then
		failed += 1
	end
	table.insert(results, (if ok then "PASS " else "FAIL ") .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
end
local function finish()
	table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
	return table.concat(results, "\n")
end

local errors = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError and #errors < 8 then
		table.insert(errors, (string.gsub(message, "\n", " | ")))
	end
end)

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

-- Konfiguration
check("Format 1500 -> 1.5K", Format.Number(1500) == "1.5K", Format.Number(1500))
for key, product in Config.Products do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for _, hero in Config.Heroes do
	for _, key in Config.AbilityKeys do
		check(`ability {hero.Id} {key}`, hero.Abilities[key] ~= nil and hero.Abilities[key].Type ~= nil)
	end
	for _, role in hero.Roles do
		check(`role {hero.Id} {role}`, Config.RolesById[role] ~= nil)
	end
	for _, id in hero.Build.Start do
		check(`start item {hero.Id} {id}`, Config.ItemsById[id] ~= nil)
	end
	for _, id in hero.Build.Items do
		check(`build item {hero.Id} {id}`, Config.ItemsById[id] ~= nil)
	end
end
for _, item in Config.Items do
	for _, component in item.From do
		check(`recipe {item.Id} <- {component}`, Config.ItemsById[component] ~= nil)
	end
end
local discount = Config.PriceFor({ "Shortsword" }, "MinerPick")
check("recipe discount", discount == 875 - 350, discount)

-- Fortschritt: neuer Held, Meisterschaft, Quests, Erfolge, Emotes, Pings
check("hero Ember", Config.HeroesById.Ember ~= nil and Config.Products.Hero_Ember ~= nil)
check("mastery level 0 -> 1", Config.MasteryLevel(0) == 1, Config.MasteryLevel(0))
check("mastery level max -> 7", Config.MasteryLevel(9600) == 7, Config.MasteryLevel(9600))
check("account xp curve", Config.AccountXPToLevel(1) > 0 and Config.AccountLevelReward(5) > Config.AccountLevelReward(4))
check("enough quests", #Config.Quests >= Config.QuestsPerDay, #Config.Quests)
for _, achievement in Config.Achievements do
	check(`achievement {achievement.Id}`, Config.AchievementsById[achievement.Id] == achievement and achievement.Goal > 0 and achievement.Title ~= "")
end
for code, reward in Config.Codes do
	check(`code {code}`, string.upper(code) == code and reward > 0 and reward <= 200, reward)
end
check("emotes and pings", #Config.Emotes > 0 and #Config.Pings > 0 and Config.PingsById.Attack ~= nil)

-- Services laden und starten
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ORDER = { "DataService", "CombatService", "WorldService", "LaneService", "JungleService", "VisionService", "HeroService", "BotService", "MatchService", "MonetizationService", "ProgressService" }
local ok, err = pcall(function()
	services.Net = require(folder.Services.Net)
	for _, name in ORDER do
		services[name] = require(folder.Services[name])
	end
	for _, name in ORDER do
		services[name]:Init(services)
	end
	services.WorldService:Build()
	services.LaneService:Build()
	for _, name in ORDER do
		if name ~= "MatchService" and name ~= "DataService" and services[name].Start then
			services[name]:Start()
		end
	end
end)
check("init services", ok, err)
if not ok then
	return finish()
end

local lane = services.LaneService
local heroes = services.HeroService
local match = services.MatchService
local combat = services.CombatService

check("arena built", workspace:FindFirstChild("Arena") ~= nil)
check("22 towers", #lane.Towers == 22, #lane.Towers)
check("6 inhibitors", #lane.Inhibitors == 6, #lane.Inhibitors)
check("2 nexus", lane.Nexus[1] ~= nil and lane.Nexus[2] ~= nil)
check("nexus protected", lane.Nexus[1].Protected == true)
check("tier 2 protected", (function()
	for _, tower in lane.Towers do
		if tower.Tier == 2 and not tower.Protected then
			return false
		end
	end
	return true
end)())

-- Laeuft hier ueberhaupt Physik? Ohne Physik laufen Humanoids nicht: dann nur die Bot-Ziele pruefen.
local probe = Instance.new("Part")
probe.Position = Vector3.new(0, 900, 0)
probe.Parent = workspace
task.wait(1)
local physics = probe.Position.Y < 899
probe:Destroy()
if not physics then
	table.insert(results, "INFO physics not simulated here, movement checks use bot walk targets")
end

-- Runde nur mit Bots (Rollen werden automatisch aufgefuellt)
ok, err = pcall(function()
	match:StartPlaying()
end)
check("start bot match", ok, err)
check("10 heroes", #heroes.Heroes == 10, #heroes.Heroes)
local roles = {}
for _, hero in heroes.Heroes do
	roles[hero.Team .. hero.Role] = true
end
check("every role filled", (function()
	for team = 1, 2 do
		for _, role in Config.Roles do
			if not roles[team .. role.Id] then
				return false
			end
		end
	end
	return true
end)())
task.wait(2)
check("elapsed clock", match:Elapsed() >= 1, match:Elapsed())
local alive = 0
for _, hero in heroes.Heroes do
	if combat.Alive(hero) then
		alive += 1
	end
end
check("heroes alive", alive == 10, alive)
local bought = 0
for _, hero in heroes.Heroes do
	if #hero.Items > 0 then
		bought += 1
	end
end
check("start items bought", bought >= 8, bought)
local smiters = 0
for _, hero in heroes.Heroes do
	if hero.Role == "Jungle" and (hero.Spells.D == "Smite" or hero.Spells.F == "Smite") then
		smiters += 1
	end
end
check("junglers have smite", smiters == 2, smiters)
local model = heroes.Heroes[1].Model
check("vision attributes", model ~= nil and model:GetAttribute("Seen1") ~= nil and model:GetAttribute("Seen2") ~= nil)

-- Beschwoererzauber, Ward und Trank duerfen nie einen Fehler werfen
for _, hero in heroes.Heroes do
	for _, slot in { "D", "F" } do
		local spellOk, spellErr = pcall(heroes.CastSpell, heroes, hero, slot, hero.Root and hero.Root.Position + Vector3.new(10, 0, -10) or nil)
		if not spellOk then
			check(`spell {hero.HeroId} {slot}`, false, spellErr)
		end
	end
	local wardOk, wardErr = pcall(heroes.PlaceWard, heroes, hero, hero.Root and hero.Root.Position + Vector3.new(5, 0, 5) or nil)
	if not wardOk then
		check(`ward {hero.HeroId}`, false, wardErr)
	end
	pcall(heroes.UsePotion, heroes, hero)
end
check("spells done", true)

-- Jede Faehigkeit einmal ausloesen (darf nie einen Fehler werfen)
for _, hero in heroes.Heroes do
	for _, key in Config.AbilityKeys do
		hero.Ranks[key] = math.max(hero.Ranks[key] or 0, 1)
		hero.Mana = hero.MaxMana
		local castOk, castErr = pcall(heroes.Cast, heroes, hero, key, hero.Root and hero.Root.Position + Vector3.new(20, 0, 0) or nil)
		if not castOk then
			check(`cast {hero.HeroId} {key}`, false, castErr)
		end
	end
end
check("casts done", true)

-- Der neue Held Ember wird von Bots evtl. nicht gewaehlt: seine Faehigkeiten einmal ueber einen geliehenen Helden ausloesen
local caster = heroes.Heroes[1]
local savedDef, savedId = caster.Def, caster.HeroId
caster.Def, caster.HeroId = Config.HeroesById.Ember, "Ember"
for _, key in Config.AbilityKeys do
	caster.Ranks[key] = math.max(caster.Ranks[key] or 0, 1)
	caster.Cooldowns[key] = 0
	caster.Mana = caster.MaxMana
	local castOk, castErr = pcall(heroes.Cast, heroes, caster, key, caster.Root and caster.Root.Position + Vector3.new(20, 0, 0) or nil)
	check(`cast Ember {key}`, castOk, castErr)
end
caster.Def, caster.HeroId = savedDef, savedId

-- Schaden am geschuetzten Nexus muss abprallen
local before = lane.Nexus[2].HP
combat:Damage(heroes.Heroes[1], lane.Nexus[2], 500)
check("protected nexus takes no damage", lane.Nexus[2].HP == before)

-- Tod und Respawn
local victim = heroes.Heroes[10]
combat:Damage(nil, victim, 1e6, { True = true })
check("hero dies", victim.Dead == true and victim.RespawnAt ~= nil)

-- Eine Minute spielen lassen
task.wait(58)
check("victim respawned", victim.Dead == false and combat.Alive(victim))
check("waves spawned", lane.Wave >= 1, lane.Wave) -- erste Welle bei 0:30, die zweite erst bei 1:00
local leveled, rich = 0, 0
for _, hero in heroes.Heroes do
	if hero.Level > 1 or hero.XP > 0 then
		leveled += 1
	end
	if (hero.CreepScore or 0) > 0 then
		rich += 1
	end
end
local minionMoved = 0
for _, minion in lane.Minions do
	local home = Config.Map.Fountain[minion.Team]
	if math.abs(combat.Position(minion).X) < math.abs(home.X) - 40 then
		minionMoved += 1
	end
end
check("minions alive", #lane.Minions > 0, #lane.Minions)
local jungle = services.JungleService
check("jungle camps spawned", #jungle.Monsters >= 12, #jungle.Monsters)
check("minions march", minionMoved > 0, minionMoved)
if physics then
	check("heroes gained xp", leveled >= 4, leveled)
	check("heroes last-hit minions", rich >= 2, rich)
	local positions = {}
	for _, hero in heroes.Heroes do
		if combat.Alive(hero) then
			table.insert(positions, math.floor(math.abs(combat.Position(hero).X)))
		end
	end
	check("bots left the fountain", (function()
		for _, x in positions do
			if x < 170 then
				return true
			end
		end
		return false
	end)(), table.concat(positions, ","))
else
	-- Ohne Physik: die Bots muessen wenigstens ein Ziel ausserhalb des Brunnens ansteuern
	local targets = {}
	local outward = false
	for _, hero in heroes.Heroes do
		if hero.Humanoid then
			local x = math.floor(math.abs(hero.Humanoid.WalkToPoint.X))
			table.insert(targets, x)
			if x < 170 then
				outward = true
			end
		end
	end
	check("bots head out of the fountain", outward, table.concat(targets, ","))
	table.insert(results, `INFO xp {leveled}, last-hits {rich}`)
end
local hurt = 0
for _, tower in lane.Towers do
	if tower.HP < tower.MaxHP then
		hurt += 1
	end
end
table.insert(results, "INFO towers damaged: " .. hurt)

-- Rundenende-Fortschritt mit Testdaten (Meldungen an Spieler abgeschaltet, es gibt hier keine)
local progress = services.ProgressService
local mvps = match:PickMVPs()
check("mvp per team", mvps[1] ~= nil and mvps[2] ~= nil and mvps[1].Team == 1 and mvps[2].Team == 2)
local sendNotify = services.Net.SendNotify
services.Net.SendNotify = function() end
local fake = {
	Crystals = 0, Wins = 1, Matches = 1, Kills = 0, Deaths = 0, Assists = 0, CS = 0, Towers = 0, Wards = 0, Epics = 0, Monsters = 0,
	Pentas = 0, MVPs = 0, WinStreak = 0, BestStreak = 0, AccountLevel = 1, AccountXP = 0, Mastery = {}, Quests = { Day = 0, List = {} },
	Achievements = {}, Title = "", Codes = {}, Settings = { Sound = true, Numbers = true, Zoom = 1 }, Tutorial = false,
}
ok, err = pcall(function()
	check("daily quests rolled", progress:EnsureQuests(fake) and #fake.Quests.List == Config.QuestsPerDay, #fake.Quests.List)
	check("streak bonus", progress:UpdateStreak(fake, true) == 0 and progress:UpdateStreak(fake, true) == Config.WinStreak.PerWin, fake.WinStreak)
	local info = progress:AfterMatch(nil :: any, fake, heroes.Heroes[1], true, true, 20)
	check("mastery gained", (fake.Mastery[heroes.Heroes[1].HeroId] or 0) > 0 and info.MasteryGained > 0)
	check("account xp gained", fake.AccountXP > 0 or fake.AccountLevel > 1, fake.AccountXP)
	check("first win achievement", fake.Achievements.FirstWin == true and fake.Crystals > 0, fake.Crystals)
	check("title text", progress:TitleText({ Title = "FirstWin", Achievements = fake.Achievements }) ~= "")
	local played = 0
	for _, quest in fake.Quests.List do
		if quest.Id == "Play" and quest.Progress == 1 then
			played += 1
		end
	end
	table.insert(results, `INFO quests {#fake.Quests.List}, play-quest progressed {played}`)
end)
services.Net.SendNotify = sendNotify
check("progress after match", ok, err)

-- Runde beenden und neu aufbauen
ok, err = pcall(function()
	match:EndMatch(1)
end)
check("end match", ok and match.Phase == "End", err)
ok, err = pcall(function()
	match:Reset()
end)
check("reset", ok and #heroes.Heroes == 0 and #lane.Towers == 22, err)

for _, message in errors do
	check("runtime error", false, message)
end
return finish()
