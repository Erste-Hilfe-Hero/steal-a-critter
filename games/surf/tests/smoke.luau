-- Smoke-Test, der per Open Cloud Luau Execution im echten Place laeuft (Workflow test-surf.yml).
-- Server-Scripts starten dort nicht automatisch, deshalb baut dieser Test die Map selbst, prueft die
-- Rampen mit echten Strahlen und laesst einen Bot mit echter SurfPhysics + workspace:Blockcast jede Stage abfahren.
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
local Format = require(ReplicatedStorage.Shared.Format)
local SurfPhysics = require(ReplicatedStorage.Shared.SurfPhysics)
local StageLayout = require(ReplicatedStorage.Shared.StageLayout)

-- Konfiguration
check("format run time", Format.Run(83.4567) == "1:23.457", Format.Run(83.4567))
check("format number", Format.Number(12345) == "12.3K", Format.Number(12345))
for key, product in Config.DevProducts do
	check("product id " .. key, product.Id ~= 0, product.Id)
end
for key, pass in Config.GamePasses do
	check("pass product " .. key, pass.ProductId ~= 0, pass.ProductId)
end

-- Services laden und Map bauen
local folder = ServerScriptService:FindFirstChild("Server")
check("server script present", folder ~= nil)
local services = {}
local ok, err = pcall(function()
	for _, name in { "Net", "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "ProgressService", "EventService", "MonetizationService" } do
		services[name] = require(folder.Services[name])
	end
	for _, name in { "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "ProgressService", "EventService", "MonetizationService" } do
		services[name]:Init(services)
	end
	services.WorldService:Build()
end)
check("require + build world", ok, err)
if not ok then
	return finish()
end
local zones = workspace:FindFirstChild("Zones")
check("zones folder", zones ~= nil)
check("lobby portal", zones and zones:FindFirstChild("StartPortal") ~= nil)
check("leaderboard board", services.WorldService.Board ~= nil)

-- Update 2: Fortschritt, Events, neue Remotes und Daten
local Progression = require(ReplicatedStorage.Shared.Progression)
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
for _, name in { "Progress", "ProgressSync", "Reward" } do
	check("remote " .. name, remotes ~= nil and remotes:FindFirstChild(name) ~= nil)
end
check("progress service api", typeof(services.ProgressService.RecordMedal) == "function" and typeof(services.ProgressService.OnStageClear) == "function")
check("event service api", typeof(services.EventService.AddBoost) == "function")
check("timer can skip api", typeof(services.TimerService.CanSkip) == "function")
check("gold time for every stage", #Progression.GoldTimes == #Config.Stages, #Progression.GoldTimes)
check("daily quests", #Progression.QuestsFor(20000, 1) == Progression.QuestsPerDay)
check("medal tiers", Progression.MedalFor(1, 1) == 3 and Progression.MedalFor(1, 9999) == 1)
check("flake booster product", Config.DevProducts.FlakeBoost ~= nil and Config.DevProducts.FlakeBoost.Kind == "Boost")
local spinOk = true
for i = 0, 100 do
	if not Progression.Spin[Progression.PickSpin(i / 100)] then
		spinOk = false
	end
end
check("lucky snowball slots", spinOk)
for _, buddy in Progression.Buddies do
	check("buddy " .. buddy.Id, buddy.Price ~= nil or buddy.Spin == true)
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { zones }
params.RespectCanCollide = true

for index, def in Config.Stages do
	local info = services.WorldService:GetStageInfo(index)
	check(`stage {index} zones`, info and info.Start and info.Finish and info.Start:GetAttribute("KillY") ~= nil)
	local layout = StageLayout.Build(index, def, Config.StageSpacing, Config.StageHeight)
	-- Spawn steht ueber der Startplattform
	local hit = workspace:Raycast(layout.Spawn, Vector3.new(0, -10, 0), params)
	check(`stage {index} spawn above platform`, hit and hit.Normal.Y > 0.99, hit and hit.Normal)
	-- Beide Rampenseiten sind surfbar und zeigen nach aussen (Keil-Ausrichtung)
	local r = layout.Ramps[1]
	local cf = CFrame.new(r.Ridge) * CFrame.Angles(0, 0, -math.rad(r.Pitch))
	for _, side in { -1, 1 } do
		local point = (cf * CFrame.new(r.Length / 2, 0, side * r.Width / 4)).Position
		local faceHit = workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), params)
		local n = faceHit and faceHit.Normal
		check(`stage {index} ramp side {side} surfable`, n and n.Y > 0.2 and n.Y < SurfPhysics.Settings.StandNormal and math.sign(n.Z) == side, n)
	end
end

-- Bot faehrt jede Stage ab (gleiche Strategie wie tests/stages.luau, aber gegen die echte Map)
local S = SurfPhysics.Settings
local HULL = Vector3.new(2, 5, 2)
local DT = 1 / 100
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end
for index, def in Config.Stages do
	local layout = StageLayout.Build(index, def, Config.StageSpacing, Config.StageHeight)
	local info = services.WorldService:GetStageInfo(index)
	local t = 0
	local lastSlope, lastSlopeTime = nil, -1
	local cast = function(from, delta)
		local result = workspace:Blockcast(CFrame.new(from), HULL, delta, params)
		if result then
			if result.Normal.Y < S.StandNormal and result.Normal.Y > 0 then
				lastSlope, lastSlopeTime = result.Normal, t
			end
			return { Distance = result.Distance, Normal = result.Normal }
		end
		return nil
	end
	local state = { Position = layout.Spawn + Vector3.new(0, 2.5 - 3, 0), Velocity = Vector3.zero, Grounded = false }
	local outcome
	while t < 90 do
		t += DT
		local pos = state.Position
		local target
		for _, r in layout.Ramps do
			if r.RidgeEnd.X > pos.X - 1 then
				target = r
				break
			end
		end
		local wish, amount = Vector3.zero, 0
		if state.Grounded and pos.X < 0 then
			wish, amount = Vector3.new(1, 0, 0), 1
		elseif lastSlope and t - lastSlopeTime < 0.08 then
			wish, amount = Vector3.new(0, 0, if lastSlope.Z < 0 then 1 else -1), 1
		else
			local goal = if target
				then Vector3.new(math.max(target.Ridge.X + 25, pos.X + 40), 0, target.Ridge.Z + (if pos.Z >= target.Ridge.Z then 1 else -1) * target.Width * 0.25)
				else Vector3.new(layout.FinishCenter.X, 0, layout.FinishCenter.Z)
			local v = flat(state.Velocity)
			local h = flat(goal - pos)
			if v.Magnitude > 1 and h.Magnitude > 1 then
				v, h = v.Unit, h.Unit
				local perp = Vector3.new(-v.Z, 0, v.X)
				if perp:Dot(h) < 0 then
					perp = -perp
				end
				if v:Dot(h) < math.cos(math.rad(2)) then
					wish, amount = perp, 1
				end
			end
		end
		SurfPhysics.Step(state, { WishDir = wish, WishAmount = amount, Jump = false }, DT, cast, S)
		local localPos = info.Finish.CFrame:PointToObjectSpace(state.Position)
		local half = info.Finish.Size / 2
		if math.abs(localPos.X) < half.X and math.abs(localPos.Y) < half.Y and math.abs(localPos.Z) < half.Z then
			outcome = string.format("%.2fs", t)
			break
		end
		if state.Position.Y - 2.5 < layout.KillY then
			outcome = string.format("fell at %s after %.1fs", tostring(state.Position), t)
			break
		end
	end
	check(`bot clears stage {index} {def.Name}`, outcome ~= nil and outcome:sub(1, 4) ~= "fell", outcome or "timeout")
end

return finish()
