-- Test der Fortschritts-Daten (Progression.luau) im luau-CLI: Tagesaufgaben, Medaillen, Gluecks-Schneeball.
-- Ausfuehren: tests/run_progression.sh (fuegt Progression davor ein)
local failed = 0
local function check(name: string, ok: boolean, detail: any?)
	if not ok then
		failed += 1
	end
	print((if ok then "PASS " else "FAIL ") .. name .. (if detail ~= nil then " (" .. tostring(detail) .. ")" else ""))
end

-- Tagesaufgaben: immer 3 verschiedene, gleich bei gleichem Tag + Spieler
local allDistinct = true
for day = 20000, 20060 do
	for _, uid in { 0, 1, 2979321382, 123456789, 999999999999 } do
		local q = Progression.QuestsFor(day, uid)
		if #q ~= Progression.QuestsPerDay or q[1] == q[2] or q[2] == q[3] or q[1] == q[3] then
			allDistinct = false
		end
		for _, id in q do
			if not Progression.QuestById[id] then
				allDistinct = false
			end
		end
	end
end
check("quests: 3 distinct valid ids per day", allDistinct)
local a, b = Progression.QuestsFor(20386, 42), Progression.QuestsFor(20386, 42)
check("quests: deterministic", table.concat(a, ",") == table.concat(b, ","), table.concat(a, ","))
local differs = false
for day = 20386, 20392 do
	if table.concat(Progression.QuestsFor(day, 42), ",") ~= table.concat(a, ",") then
		differs = true
	end
end
check("quests: change between days", differs)

-- Medaillen
check("medal gold", Progression.MedalFor(1, Progression.GoldTimes[1]) == 3)
check("medal silver", Progression.MedalFor(1, Progression.GoldTimes[1] * 1.2) == 2)
check("medal bronze", Progression.MedalFor(1, 999) == 1)
check("medal NaN rejected", Progression.MedalFor(1, 0 / 0) == 0)
check("medal unknown stage", Progression.MedalFor(99, 5) == 0)
check("gold time per stage", #Progression.GoldTimes == 10)

-- Gluecks-Schneeball: jede Stelle erreichbar, Grenzen sicher
local counts = {}
for i = 0, 9999 do
	local index = Progression.PickSpin(i / 10000)
	counts[index] = (counts[index] or 0) + 1
end
local all = true
for index = 1, #Progression.Spin do
	if not counts[index] then
		all = false
	end
end
check("spin: every slot reachable", all)
check("spin: roll 0.99999 valid", Progression.Spin[Progression.PickSpin(0.99999)] ~= nil)
check("spin: buddy exists", Progression.BuddiesById.owl ~= nil)

-- Erfolge: eindeutige IDs
local seen, unique = {}, true
for _, achievement in Progression.Achievements do
	if seen[achievement.Id] then
		unique = false
	end
	seen[achievement.Id] = true
end
check("achievements unique", unique, #Progression.Achievements)

print(`SUMMARY: {failed} failed`)
if failed > 0 then
	error("progression tests failed")
end
