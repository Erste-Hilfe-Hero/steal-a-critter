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

-- Update: Quests, Erfolge, Auren, Codes, Anleitung, Schreine
local questEvents = { Kill = true, EliteKill = true, BossKill = true, Clear = true, Salvage = true, Enhance = true, Chest = true, Shrine = true, FindRare = true, Combo = true }
for _, quest in Config.Quests do
	check("quest " .. quest.Key, questEvents[quest.Event] == true and quest.Goal > 0 and string.format(quest.Text, quest.Goal) ~= quest.Text)
end
check("quest count", #Config.Quests >= Config.QuestCount)
local titles = {}
for _, achievement in Config.Achievements do
	check("achievement " .. achievement.Key, achievement.Goal > 0 and achievement.Gold > 0 and achievement.Title ~= "" and not titles[achievement.Title])
	titles[achievement.Title] = true
end
for _, aura in Config.Auras do
	local source = (if aura.Gold then 1 else 0) + (if aura.Product then 1 else 0) + (if aura.Achievement then 1 else 0)
	check("aura " .. aura.Key, source == 1 and (not aura.Product or Config.DevProducts[aura.Product] ~= nil) and (not aura.Achievement or Config.AchievementsByKey[aura.Achievement] ~= nil))
end
for code, reward in Config.Codes do
	check("code " .. code, code == code:upper() and (reward.Gold or reward.Shards or reward.Item) ~= nil)
end
local tutorialEvents = { SetClass = true, RunStart = true, Clear = true, Equip = true, Enhance = true, QuestClaim = true }
for i, step in Config.Tutorial do
	check("tutorial step " .. i, tutorialEvents[step.Event] == true and step.Gold > 0)
end
for _, key in Config.ShrineOrder do
	check("shrine " .. key, Config.Shrines[key] ~= nil and Config.Shrines[key].Seconds > 0)
end
check("potion mastery", Config.PotionCooldownFor(Config.PotionMaxLevel) > 0 and Config.PotionHealFor(Config.PotionMaxLevel) < 1)
for day = 0, 13 do
	local index = Config.FeaturedDungeon(day)
	check("featured day " .. day, Config.Dungeons[index] ~= nil)
end
check("treasure imp", Config.Monsters.TreasureImp ~= nil and Config.Monsters.TreasureImp.Treasure == true)

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
	for _, name in { "Net", "DataService", "WorldService", "MonsterService", "DungeonService", "HeroService", "CombatService", "LootService", "MonetizationService", "RewardService", "CommunityService", "ProgressService" } do
		services[name] = require(folder.Services[name])
	end
end)
check("require services", ok, err)
if not ok then
	return finish()
end
ok, err = pcall(function()
	for _, name in { "DataService", "WorldService", "MonsterService", "DungeonService", "HeroService", "CombatService", "LootService", "MonetizationService", "RewardService", "CommunityService", "ProgressService" } do
		services[name]:Init(services)
	end
	services.WorldService:Build()
end)
check("init + build town", ok, err)
check("portals built", #services.WorldService.Portals == #Config.Dungeons, #services.WorldService.Portals)
ok, err = pcall(function()
	services.WorldService:SetFeatured(2)
	assert(services.WorldService.Portals[2].Featured.Enabled and not services.WorldService.Portals[1].Featured.Enabled, "featured sign")
end)
check("featured portal sign", ok, err)
local whole = services.ProgressService.WholeNumber
check("reject NaN/inf", whole(0 / 0) == nil and whole(math.huge) == nil and whole("3") == nil and whole(2.7) == 2)

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

-- Schatz-Kobold entkommt ohne Beute
ok, err = pcall(function()
	local state = services.MonsterService:Spawn(run, "TreasureImp", Vector3.new(0, 0, -400))
	assert(state and state.Treasure and state.EscapeAt < math.huge, "imp state")
	services.MonsterService:Escape(state)
	assert(not state.Alive and state.Model.Parent == nil, "escape")
end)
check("treasure imp escape", ok, err)

return finish()
