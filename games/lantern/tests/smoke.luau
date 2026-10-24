-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft.
-- Server-Scripts starten dort nicht automatisch, deshalb baut dieser Test Stadt, Dungeons und Monster selbst.
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

local Config = require(ReplicatedStorage.Shared.Config)
local Items = require(ReplicatedStorage.Shared.Items)

-- Konfiguration
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end
for _, dungeon in Config.Dungeons do
	check("boss exists " .. dungeon.Id, Config.Bosses[dungeon.Boss] ~= nil)
	check("elite exists " .. dungeon.Id, Config.Monsters[dungeon.Elite] ~= nil)
	for _, key in dungeon.Monsters do
		check("monster exists " .. key, Config.Monsters[key] ~= nil)
	end
end
for key, boss in Config.Bosses do
	check("boss summon " .. key, Config.Monsters[boss.Summon] ~= nil)
end

-- Gegenstaende
local rng = Random.new(1)
local ok, err = pcall(function()
	for rarity = 1, #Config.Rarities do
		for _, slot in Config.Slots do
			local item = Items.Generate(rng, { Slot = slot, Rarity = rarity, Level = 20 })
			assert(Items.DisplayName(item, "Knight") ~= "", "name")
			assert(Items.Power(item) > 0, "power")
			assert(#item.Affixes == Config.Rarities[rarity].Affixes, "affixes")
			assert((rarity >= 5) == (item.Power ~= nil), "legendary power")
		end
	end
end)
check("generate all items", ok, err)
local equipped = {}
for _, slot in Config.Slots do
	table.insert(equipped, Items.Generate(rng, { Slot = slot, Rarity = 3, Level = 10 }))
end
local stats = Items.TotalStats("Mage", 10, equipped)
check("total stats", stats.Damage > Config.BaseDamage(10) and stats.Health > Config.BaseHealth(100, 10), `{stats.Damage}/{stats.Health}`)

-- Services laden und Welt bauen
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
ok, err = pcall(function()
	for _, name in { "Net", "DataService", "WorldService", "MonsterService", "DungeonService", "HeroService", "CombatService", "LootService", "MonetizationService", "RewardService", "CommunityService" } do
		services[name] = require(folder.Services[name])
	end
end)
check("require services", ok, err)
if not ok then
	return finish()
end
ok, err = pcall(function()
	for _, name in { "DataService", "WorldService", "MonsterService", "DungeonService", "HeroService", "CombatService", "LootService", "MonetizationService", "RewardService", "CommunityService" } do
		services[name]:Init(services)
	end
	services.WorldService:Build()
end)
check("init + build town", ok, err)
check("portals built", #services.WorldService.Portals == #Config.Dungeons, #services.WorldService.Portals)

-- Jeden Dungeon einmal bauen (ohne Spieler wird er gleich wieder abgebaut)
for index, dungeon in Config.Dungeons do
	ok, err = pcall(services.DungeonService.StartRun, services.DungeonService, index, 1, {})
	check("build dungeon " .. dungeon.Id, ok, err)
end
check("dungeons cleaned up", #services.WorldService.DungeonFolder:GetChildren() == 0, #services.WorldService.DungeonFolder:GetChildren())

-- Jedes Monster und jeden Boss erzeugen, verletzen und toeten
local run = {
	Id = 999,
	Dungeon = Config.Dungeons[1],
	Difficulty = 2,
	Level = 10,
	Players = {},
	FloorY = 0,
	Rooms = { { Center = Vector3.new(0, 0, -400), Half = 30 } },
	Room = 1,
	State = "Done",
	Stats = {},
}
for key in Config.Monsters do
	ok, err = pcall(function()
		local state = services.MonsterService:Spawn(run, key, Vector3.new(0, 0, -400), { Elite = key == "Golem" })
		assert(state and state.MaxHp > 0, "no state")
		services.MonsterService:Damage(state, 1, nil, false)
		assert(state.Hp == state.MaxHp - 1, "damage")
		services.MonsterService:Damage(state, state.MaxHp * 2, nil, true)
		assert(not state.Alive and state.Model.Parent == nil, "kill")
	end)
	check("monster " .. key, ok, err)
end
for key in Config.Bosses do
	ok, err = pcall(function()
		local state = services.MonsterService:Spawn(run, key, Vector3.new(0, 0, -400), { Boss = true })
		assert(state and state.Boss, "no boss")
		services.MonsterService:Damage(state, state.MaxHp * 0.6, nil, false)
		assert(state.Enraged, "enrage")
		services.MonsterService:ClearRun(run)
	end)
	check("boss " .. key, ok, err)
end
check("monsters cleared", services.MonsterService:CountAlive(run) == 0)

return finish()
