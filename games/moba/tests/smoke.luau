-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft.
-- Server-Scripts starten dort nicht automatisch: der Test baut die Arena selbst, startet eine Runde
-- nur mit Bots, laesst sie eine Minute laufen und prueft dabei Minions, Gold, Faehigkeiten, Tod und Respawn.
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
	check("build for role " .. hero.Role, Config.RoleBuilds[hero.Role] ~= nil)
end
for role, build in Config.RoleBuilds do
	for _, id in build do
		check(`item {id} in {role}`, Config.ItemsById[id] ~= nil)
	end
end

-- Services laden und starten
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ORDER = { "DataService", "CombatService", "WorldService", "LaneService", "HeroService", "BotService", "MatchService", "MonetizationService" }
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
check("12 towers", #lane.Towers == 12, #lane.Towers)
check("2 cores", lane.Cores[1] ~= nil and lane.Cores[2] ~= nil)
check("core protected", lane.Cores[1].Protected == true)
check("tier 2 protected", (function()
	for _, tower in lane.Towers do
		if tower.Tier == 2 and not tower.Protected then
			return false
		end
	end
	return true
end)())

-- Runde nur mit Bots
ok, err = pcall(function()
	match.StartedAt = workspace:GetServerTimeNow()
	match:SetPhase("Playing")
	for team = 1, 2 do
		for _ = 1, Config.TeamSize do
			match:CreateBot(team)
		end
	end
	for _, hero in heroes.Heroes do
		heroes:Spawn(hero)
	end
	lane:StartMatch()
end)
check("start bot match", ok, err)
check("10 heroes", #heroes.Heroes == 10, #heroes.Heroes)
task.wait(2)
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
check("auto-buy at fountain", bought >= 8, bought)

-- Jede Faehigkeit einmal ausloesen (darf nie einen Fehler werfen)
for _, hero in heroes.Heroes do
	for _, key in Config.AbilityKeys do
		local castOk, castErr = pcall(heroes.Cast, heroes, hero, key, hero.Root and hero.Root.Position + Vector3.new(20, 0, 0) or nil)
		if not castOk then
			check(`cast {hero.HeroId} {key}`, false, castErr)
		end
	end
end
check("casts done", true)

-- Schaden an einem geschuetzten Kern muss abprallen
local before = lane.Cores[2].HP
combat:Damage(heroes.Heroes[1], lane.Cores[2], 500)
check("protected core takes no damage", lane.Cores[2].HP == before)

-- Tod und Respawn
local victim = heroes.Heroes[10]
combat:Damage(nil, victim, 1e6, { True = true })
check("hero dies", victim.Dead == true and victim.RespawnAt ~= nil)

-- Eine Minute spielen lassen
task.wait(58)
check("victim respawned", victim.Dead == false and combat.Alive(victim))
check("waves spawned", lane.Wave >= 2, lane.Wave)
local leveled, rich = 0, 0
for _, hero in heroes.Heroes do
	if hero.Level > 1 or hero.XP > 0 then
		leveled += 1
	end
	if (hero.CreepScore or 0) > 0 then
		rich += 1
	end
end
check("heroes gained xp", leveled >= 4, leveled)
check("heroes last-hit minions", rich >= 2, rich)
check("minions alive", #lane.Minions > 0, #lane.Minions)
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
local hurt = 0
for _, tower in lane.Towers do
	if tower.HP < tower.MaxHP then
		hurt += 1
	end
end
table.insert(results, "INFO towers damaged: " .. hurt)

-- Runde beenden und neu aufbauen
ok, err = pcall(function()
	match:EndMatch(1)
end)
check("end match", ok and match.Phase == "End", err)
ok, err = pcall(function()
	match:Reset()
end)
check("reset", ok and #heroes.Heroes == 0 and #lane.Towers == 12, err)

for _, message in errors do
	check("runtime error", false, message)
end
return finish()
