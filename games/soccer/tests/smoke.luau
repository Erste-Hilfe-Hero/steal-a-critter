-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft.
-- Server-Scripts starten dort nicht automatisch: der Test startet alle Services selbst, laesst Bots
-- (ohne echte Spieler, Attribut SmokeTest) ein verkuerztes Match spielen und sammelt jeden Fehler
-- aus dem Log. Danach werden Tor, K.O., Schwert, Combo, Respawn und goldener Ball direkt ausgeloest.
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

local errors = {}
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageError or (kind == Enum.MessageType.MessageWarning and string.find(message, "%[")) then
		if #errors < 25 then
			table.insert(errors, string.sub(message, 1, 300))
		end
	end
end)

local Config = require(ReplicatedStorage.Shared.Config)

-- Verkuerztes Match
Config.MatchSeconds = 45
Config.KickoffSeconds = 1
Config.GoalCelebrationSeconds = 1
Config.ResultsSeconds = 1
workspace:SetAttribute("SmokeTest", true)

local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local Services = {}
local ORDER = { "DataService", "ArenaService", "ProgressService", "BallService", "CombatService", "BotService", "MatchService", "MonetizationService", "ExtrasService", "FeaturesService", "PlusService", "DiagService" }
local ok, err = pcall(function()
	Services.Net = require(folder.Services.Net)
	for _, name in ORDER do
		Services[name] = require(folder.Services[name])
	end
	for _, name in ORDER do
		Services[name]:Init(Services)
	end
	Services.ArenaService:Build()
	for _, name in ORDER do
		if Services[name].Start then
			Services[name]:Start()
		end
	end
end)
check("start services", ok, err)
if not ok then
	table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
	return table.concat(results, "\n")
end

-- Bots fuellen die Teams auf und das Match laeuft an
local match = Services.MatchService
local deadline = os.clock() + 20
while os.clock() < deadline and (match:GetState() ~= "Playing" or #match:GetActors() < 2) do
	task.wait(0.5)
end
check("match playing", match:GetState() == "Playing", match:GetState())
check("bots spawned", #match:GetActors() >= 2, #match:GetActors())

task.wait(20)
check("still running", match:GetState() ~= "Waiting", match:GetState())

-- Ereignisse direkt ausloesen
local actors = match:GetActors()
local blue, red
for _, actor in actors do
	if actor.Team == "Blue" and not blue then
		blue = actor
	elseif actor.Team == "Red" and not red then
		red = actor
	end
end
check("actors per team", blue ~= nil and red ~= nil)
if blue and red then
	local function try(name, fn)
		local good, problem = pcall(fn)
		check(name, good, problem)
	end
	try("knife model", function()
		assert(blue.Model:FindFirstChild("Knife"), "no Knife model")
	end)
	try("refresh sword", function()
		Services.CombatService:RefreshSword(blue)
		assert(blue.Model:FindFirstChild("Knife"), "no Knife after refresh")
	end)
	try("combo damage", function()
		red.SpawnProtectUntil = 0
		for _ = 1, 3 do
			Services.CombatService:Damage(red, 5, blue, "Slash", false)
		end
	end)
	try("knock out + revive", function()
		red.SpawnProtectUntil = 0
		Services.CombatService:Damage(red, 10000, blue, "Stab", true)
		assert(Services.CombatService:IsKO(red), "not KO after big damage")
		task.wait(1.5)
		Services.CombatService:Revive(red)
		assert(not Services.CombatService:IsKO(red), "still KO after revive")
	end)
	try("bot swing hits", function()
		Services.CombatService:Revive(red)
		red.SpawnProtectUntil = 0
		blue.KnifeReadyAt = 0
		blue.StunnedUntil = 0
		if Services.BallService.Carrier == blue then
			Services.BallService:Forget(blue)
		end
		red.Root.CFrame = blue.Root.CFrame * CFrame.new(0, 0, -5)
		local before = red.HP
		local started = Services.CombatService:Swing(blue, "Slash", blue.Root.CFrame.LookVector)
		task.wait(0.6)
		assert(started, "swing refused")
		assert(red.HP < before or Services.CombatService:IsKO(red), `no damage (hp {before} -> {red.HP})`)
	end)
	try("kick multiplier", function()
		local m = Services.ExtrasService:KickMultiplier(blue)
		assert(type(m) == "number" and m >= 1, "bad multiplier " .. tostring(m))
	end)
	try("goal events", function()
		match:OnGoal("Blue", blue, nil, 95)
	end)
	try("golden ball value", function()
		assert(Services.ExtrasService:GoalValue() >= 1)
	end)
	try("match start/end hooks", function()
		Services.ExtrasService:OnMatchStart()
		Services.ExtrasService:OnMatchEnd("Blue")
	end)

	-- Neue Features
	local features = Services.FeaturesService
	try("features remote", function()
		assert(ReplicatedStorage.Remotes:FindFirstChild("Features"), "no Features remote")
	end)
	try("mvp tracking", function()
		features:Track(blue, "Goal")
		features:Track(blue, "KO")
		features:Track(red, "Save")
		features:Track(nil, "KO")
		local line = features:OnMatchEnd("Blue", 2, 1)
		assert(type(line) == "string" and string.find(line, "MVP"), "no MVP line: " .. tostring(line))
	end)
	try("mode vote pick", function()
		assert(features:PickMode({}) == "Classic", "no votes should be Classic")
		assert(features:PickMode({ Turbo = 2, Classic = 1 }) == "Turbo", "majority should win")
	end)
	try("mode apply", function()
		features:ApplyMode("LowGravity")
		assert(workspace.Gravity < 150, "gravity not lowered")
		features:ApplyMode("Turbo")
		assert(workspace:GetAttribute("ModeSpeed") == Config.ModesById.Turbo.Speed, "turbo speed missing")
		local m = features:KickBonus(blue)
		assert(m == 1, "turbo should not change kicks")
		features:ApplyMode("MegaKicks")
		assert(features:KickBonus(blue) > 1, "mega kicks missing")
		features:OnMatchStart()
		assert(features:GetMode() == "Classic" and math.abs(workspace.Gravity - 196.2) < 1, "classic not restored")
	end)
	try("spin roll", function()
		local random = Random.new(1)
		for _ = 1, 200 do
			local index = features:RollSpin(random)
			assert(Config.SpinPrizes[index], "bad spin index " .. tostring(index))
		end
	end)
	try("ranks", function()
		assert(Config.RankFor(0).Name == "Bronze" and Config.RankFor(1260).Name == "Gold" and Config.RankFor(5000).Name == "Champion", "rank table broken")
	end)
	try("goal hook features", function()
		features:OnGoal(blue, red, 90)
	end)
	-- Einfacher schiessen + Plus-Features
	local plus = Services.PlusService
	try("shot target", function()
		local goal = Services.ArenaService:GoalCenter("Red")
		local from = goal - Vector3.new(Config.Teams.Red.Side * 80, 0, 0) + Vector3.new(0, 3, 0)
		local forward = Vector3.new(Config.Teams.Red.Side, 0, 0)
		local target = Config.ShotTarget(from, forward, goal, 0)
		assert(target, "no target when aiming at goal")
		assert(math.abs(target.Z) > 5 and math.abs(target.Z) < Config.GoalWidth / 2, "target not in a corner: " .. tostring(target))
		assert(Config.ShotTarget(from, -forward, goal, 0) == nil, "target when aiming away")
		local angle, speed = Config.ShotArc(80, 3, 20, workspace.Gravity)
		assert(speed > 20 and angle > 0 and angle < math.rad(60), `weak shot not boosted ({angle}, {speed})`)
	end)
	try("assist target at enemy goal", function()
		local target = Services.BallService:AssistTarget(blue, Vector3.new(Config.Teams.Red.Side, 0, 0))
		assert(target == nil or math.abs(target.X) > Config.FieldLength / 2, "assist target not at red goal")
	end)
	try("super meter", function()
		plus:AddSuper(blue, 1000)
		assert(blue.Model:GetAttribute("Super") == Config.SuperMax, "meter not full")
		local m = plus:ShotBonus(blue)
		assert(m >= Config.SuperPower, "no super bonus " .. tostring(m))
		assert(blue.Model:GetAttribute("Super") == 0, "meter not reset")
		plus:OnKick(blue, 100, true)
	end)
	try("pads built", function()
		local pads = workspace:FindFirstChild("Pads")
		assert(pads and #pads:GetChildren() == #Config.SpeedPads + #Config.JumpPads, "pads missing")
		-- kein Pad am Beitritts-Spawn (sonst startet man im Himmel)
		for _, spawn in workspace:GetDescendants() do
			if spawn:IsA("SpawnLocation") then
				for _, pad in pads:GetChildren() do
					local offset = pad.Position - spawn.Position
					assert(Vector3.new(offset.X, 0, offset.Z).Magnitude > 15, "pad too close to spawn: " .. pad.Name)
				end
			end
		end
	end)
	try("new modes", function()
		features:ApplyMode("QuickMatch")
		assert(workspace:GetAttribute("ScoreLimit") == 3, "quick match limit missing")
		features:ApplyMode("Bouncy")
		task.wait()
		assert(Services.BallService.Ball.CustomPhysicalProperties.Elasticity > 0.9, "ball not bouncy")
		features:ApplyMode("Classic")
		task.wait()
		assert(workspace:GetAttribute("ScoreLimit") == Config.ScoreLimit, "score limit not restored")
		assert(Services.BallService.Ball.CustomPhysicalProperties.Elasticity < 0.9, "ball still bouncy")
	end)
	try("match stats", function()
		local line = plus:OnMatchEnd()
		assert(type(line) == "string" and string.find(line, "POSSESSION"), "no stats line")
	end)
end

-- Muenzen erscheinen waehrend des Spiels auf dem Feld (Bots sammeln sie nicht ein)
local pickupFolder = workspace:FindFirstChild("Pickups")
check("pickups folder", pickupFolder ~= nil)
local sawCoin = false
local pickupDeadline = os.clock() + 25
while os.clock() < pickupDeadline and not sawCoin do
	sawCoin = pickupFolder ~= nil and pickupFolder:FindFirstChild("CoinDrop") ~= nil
	task.wait(0.5)
end
check("coin drop spawned", sawCoin or match:GetState() == "Ended" or match:GetState() == "Waiting", match:GetState())

-- Eigene Sounds (SoundIds.json) muessen laden, sonst ist es im Spiel still
local SoundIds = require(ReplicatedStorage.Shared.SoundIds)
local sounds = {}
for file, id in SoundIds do
	if id ~= 0 then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. id
		sound.Parent = workspace
		sounds[file] = sound
	end
end
pcall(function()
	local list = {}
	for _, sound in sounds do
		table.insert(list, sound)
	end
	game:GetService("ContentProvider"):PreloadAsync(list)
end)
task.wait(3)
for file, sound in sounds do
	check("sound loads " .. file, sound.IsLoaded and sound.TimeLength > 0, `{sound.SoundId} len {sound.TimeLength}`)
end

task.wait(20)
check("match loop alive", match:GetState() ~= "Waiting", match:GetState())

for _, message in errors do
	check("log error", false, message)
end
check("no log errors", #errors == 0, #errors)

table.insert(results, 1, `SUMMARY: {failed} failed of {#results}`)
return table.concat(results, "\n")
