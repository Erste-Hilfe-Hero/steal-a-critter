-- Erweiterungen rund ums Spiel: Combos, K.O.-Serien, Rache, First Blood, Heilung, goldener Ball,
-- Fallrueckzieher, Rocket Shot, Hattrick, Pfosten, Eigentor, Traumtor, Weisse Weste, Comeback,
-- letzte Minute, "On Fire", taegliche Quests, Titel, Karriere-Statistik, Bestenliste, Level- und
-- Siegesserien-Belohnungen, Spielzeit-Coins, Katana-Skins, Torjubel, Team Boost, Riesen-Modus,
-- Sofort-Respawn, Nacht- und Regen-Spiele, Alien-Jubel und Spawn-Schutz-Leuchten.
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ExtrasService = { Services = nil :: any }

local C = Config.Colors
local GOLD = Color3.fromRGB(255, 205, 50)

local remote: RemoteEvent
local streaks = {} -- [actor] = K.O.s ohne selbst umzufallen
local lastKiller = {} -- [actor] = wer einen zuletzt umgehauen hat
local combos = {} -- [actor] = { Count, Last }
local matchGoals = {} -- [Player] = Tore in diesem Match
local firstBlood = false
local maxDeficit = { Blue = 0, Red = 0 }
local conceded = { Blue = 0, Red = 0 }
local goldenUntil = 0
local goldenPlanned = math.huge
local lastMinuteWarned = false
local carrierSince = 0
local lastCarrier = nil
local onFireActor = nil
local postCooldown = 0
local leaderboard = nil :: OrderedDataStore?

local function now(): number
	return workspace:GetServerTimeNow()
end

local function services()
	return ExtrasService.Services
end

local function data(player: Player?)
	return player and services().DataService:Get(player)
end

local function hasPass(player: Player?, key: string): boolean
	return Config.Has(player, key)
end

local function announce(text: string, color: Color3?)
	services().Net.SendAnnounce(text, color or GOLD)
end

local function notify(player: Player?, text: string, color: Color3?)
	if player then
		services().Net.SendNotify(player, text, color or GOLD)
	end
end

local function send(player: Player, kind: string, info: any)
	remote:FireClient(player, kind, info)
end

local function coins(player: Player?, amount: number)
	if player then
		services().ProgressService:AddCoins(player, amount, true)
	end
end

---------------------------------------------------------------- Quests

local function dayNumber(): number
	return os.time() // 86400
end

-- Jeden Tag dieselben Quests fuer alle (Zufall mit dem Tag als Seed, keine Kaufentscheidung)
local function rollQuests(player: Player, d)
	local count = if hasPass(player, "QuestMaster") then 4 else 3
	if d.Quests.Day == dayNumber() and #d.Quests.Items >= count then
		return
	end
	if d.Quests.Day ~= dayNumber() then
		d.Quests = { Day = dayNumber(), Items = {} }
	end
	local random = Random.new(dayNumber())
	local pool = table.clone(Config.Quests)
	for i = #pool, 2, -1 do
		local j = random:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	for i = #d.Quests.Items + 1, count do
		table.insert(d.Quests.Items, { Id = pool[i].Id, Progress = 0, Done = false })
	end
end

local QUESTS_BY_ID = {}
for _, quest in Config.Quests do
	QUESTS_BY_ID[quest.Id] = quest
end

local function sendQuests(player: Player)
	local d = data(player)
	if not d then
		return
	end
	rollQuests(player, d)
	local list = {}
	for _, item in d.Quests.Items do
		local def = QUESTS_BY_ID[item.Id]
		if def then
			table.insert(list, {
				Text = string.format(def.Text, def.Goal),
				Progress = math.min(item.Progress, def.Goal),
				Goal = def.Goal,
				Coins = def.Coins * (if hasPass(player, "QuestMaster") then 2 else 1),
				Done = item.Done,
			})
		end
	end
	send(player, "Quests", list)
end

function ExtrasService:Progress(player: Player?, event: string, amount: number?)
	local d = data(player)
	if not player or not d then
		return
	end
	rollQuests(player, d)
	-- Wochen-Herausforderung und Erfolge laufen im FeaturesService mit
	services().FeaturesService:OnEvent(player, event, amount or 1)
	local changed = false
	for _, item in d.Quests.Items do
		local def = QUESTS_BY_ID[item.Id]
		if def and def.Event == event and not item.Done then
			item.Progress += amount or 1
			changed = true
			if item.Progress >= def.Goal then
				item.Done = true
				local reward = def.Coins * (if hasPass(player, "QuestMaster") then 2 else 1)
				coins(player, reward)
				notify(player, `QUEST DONE: {string.format(def.Text, def.Goal)}  +{reward} coins`, C.Lime)
			end
		end
	end
	if changed then
		sendQuests(player)
	end
end

---------------------------------------------------------------- Titel und Statistik

local function titleFor(player: Player)
	local d = data(player)
	local best = Config.Titles[1]
	if d then
		for _, title in Config.Titles do
			local value = if title.Stat == "Level" then d.Level else (d[title.Stat] or 0)
			if value >= title.Need then
				best = title
			end
		end
	end
	return best
end

-- Titel und Siegesserie ueber dem Namensschild
function ExtrasService:RefreshTitle(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("TitleTag") :: BillboardGui?
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "TitleTag"
		gui.Size = UDim2.fromOffset(180, 20)
		gui.StudsOffset = Vector3.new(0, 4.4, 0)
		gui.MaxDistance = 90
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Config.BodyFont
		text.TextScaled = true
		text.TextStrokeTransparency = 0.3
		text.Parent = gui
		gui.Parent = head
		tag = gui
	end
	local title = titleFor(player)
	local d = data(player)
	local streak = if d then d.WinStreak else 0
	local label = (tag :: BillboardGui):FindFirstChild("Text") :: TextLabel
	label.Text = string.upper(title.Name) .. (if streak >= 2 then `  🔥{streak}` else "")
	label.TextColor3 = title.Color
end

local function sendStats(player: Player)
	local d = data(player)
	if not d then
		return
	end
	send(player, "Stats", {
		Level = d.Level,
		Goals = d.Goals,
		Assists = d.Assists,
		KOs = d.KOs,
		Steals = d.Steals,
		Saves = d.Saves,
		Wins = d.Wins,
		Matches = d.Matches,
		WinStreak = d.WinStreak,
		Title = titleFor(player).Name,
	})
end

---------------------------------------------------------------- Bestenliste (Tore aller Zeiten)

local nameCache = {}
local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Player"
	return nameCache[userId]
end

local boardLabels = {}
local function buildBoard()
	local arena = workspace:WaitForChild("Arena")
	local HALF_W = Config.FieldWidth / 2
	local position = Vector3.new(0, 58, -(HALF_W + 7 + 44))
	local board = Instance.new("Part")
	board.Name = "Leaderboard"
	board.Anchored = true
	board.Size = Vector3.new(60, 30, 2)
	board.CFrame = CFrame.lookAt(position, Vector3.new(0, 58, 0))
	board.Color = Color3.fromRGB(30, 30, 32)
	board.Material = Enum.Material.Metal
	board.Parent = arena
	local leg = Instance.new("Part")
	leg.Anchored = true
	leg.Size = Vector3.new(3, 43, 3)
	leg.CFrame = CFrame.new(position - Vector3.new(0, 36.5, 0))
	leg.Color = Color3.fromRGB(122, 70, 38)
	leg.Material = Enum.Material.CorrodedMetal
	leg.Parent = arena
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 12
	gui.LightInfluence = 0
	gui.Parent = board
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.Parent = gui
	local function line(text: string, color: Color3, height: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, height)
		l.BackgroundTransparency = 1
		l.Font = Config.Font
		l.TextScaled = true
		l.TextColor3 = color
		l.Text = text
		l.Parent = gui
		return l
	end
	line("TOP SCORERS", GOLD, 56)
	for i = 1, 10 do
		boardLabels[i] = line("", if i <= 3 then GOLD else C.White, 28)
	end
end

local function refreshBoard()
	if not leaderboard then
		return
	end
	local ok, pages = pcall(function()
		return (leaderboard :: OrderedDataStore):GetSortedAsync(false, 10)
	end)
	if not ok then
		return
	end
	local entries = pages:GetCurrentPage()
	for i = 1, 10 do
		local entry = entries[i]
		boardLabels[i].Text = if entry then `{i}. {nameFor(tonumber(entry.key) or 0)}  -  {entry.value}` else ""
	end
end

local function saveGoals(player: Player)
	local d = data(player)
	if leaderboard and d and d.Goals > 0 then
		pcall(function()
			(leaderboard :: OrderedDataStore):SetAsync(tostring(player.UserId), d.Goals)
		end)
	end
end

---------------------------------------------------------------- Kampf

-- Combo: der dritte Treffer in kurzer Folge macht mehr Schaden
function ExtrasService:ModifyDamage(attacker, victim, amount: number, kind: string): number
	if not attacker or (kind ~= "Slash" and kind ~= "Stab") then
		return amount
	end
	local t = now()
	local combo = combos[attacker]
	if not combo or t - combo.Last > Config.ComboWindow then
		combo = { Count = 0, Last = t }
		combos[attacker] = combo
	end
	combo.Count += 1
	combo.Last = t
	self:Progress(attacker.Player, "Hit")
	if combo.Count >= Config.ComboHits then
		combo.Count = 0
		notify(attacker.Player, "COMBO! +50% damage", C.Orange)
		return amount * Config.ComboBonus
	end
	return amount
end

local function koBurst(position: Vector3, color: Color3)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new(0.8, 0)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(40)
	task.delay(1.5, function()
		attachment:Destroy()
	end)
end

-- Sterne ueber dem Kopf, solange jemand K.O. ist
local function koStars(victim)
	local head = victim.Model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "KOStars"
	gui.Size = UDim2.fromOffset(70, 30)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "★ ★ ★"
	text.TextScaled = true
	text.TextColor3 = GOLD
	text.TextStrokeTransparency = 0
	text.Font = Config.Font
	text.Parent = gui
	gui.Parent = head
	task.spawn(function()
		while gui.Parent and services().CombatService:IsKO(victim) do
			gui.StudsOffset = Vector3.new(math.sin(os.clock() * 6) * 0.5, 2 + math.cos(os.clock() * 6) * 0.2, 0)
			task.wait(0.05)
		end
		gui:Destroy()
	end)
end

function ExtrasService:OnKO(attacker, victim, kind: string)
	koStars(victim)
	streaks[victim] = 0
	-- Gekauftes "Respawn Now" fuer spaeter: nach einer Sekunde wieder auf den Beinen
	local victimData = data(victim.Player)
	if victimData and (victimData.RespawnTokens or 0) > 0 then
		victimData.RespawnTokens -= 1
		victim.Player:SetAttribute("RespawnTokens", victimData.RespawnTokens)
		task.delay(1, function()
			if services().CombatService:IsKO(victim) then
				services().CombatService:Revive(victim)
				notify(victim.Player, "Respawn used!", C.Lime)
			end
		end)
	end
	if not attacker then
		return
	end
	local skin = attacker.Player and Config.SwordSkinsById[attacker.Player:GetAttribute("SwordSkin") or "classic"]
	koBurst(victim.Root.Position, if skin and skin.Id ~= "classic" then skin.Color else Config.Teams[attacker.Team].Color)
	self:Progress(attacker.Player, "KO")
	if attacker.Player then
		services().ProgressService:AddStat(attacker.Player, "KOs", 1)
	end
	if not firstBlood then
		firstBlood = true
		announce(`FIRST BLOOD! {attacker.Name}`, C.Red)
		coins(attacker.Player, 100)
	end
	if lastKiller[attacker] == victim then
		lastKiller[attacker] = nil
		announce(`REVENGE! {attacker.Name} got {victim.Name} back`, C.Orange)
		coins(attacker.Player, 75)
	end
	lastKiller[victim] = attacker
	streaks[attacker] = (streaks[attacker] or 0) + 1
	local name = Config.Streaks[streaks[attacker]]
	if name then
		announce(`{name}! {attacker.Name}`, C.Red)
		coins(attacker.Player, Config.StreakCoins * streaks[attacker])
	end
end

---------------------------------------------------------------- Ball und Tore

-- Multiplikator fuer einen Schuss (Rocket Shot, Fallrueckzieher)
function ExtrasService:KickMultiplier(actor): number
	local multiplier = 1
	if actor.Humanoid.FloorMaterial == Enum.Material.Air then
		multiplier *= Config.BicycleBonus
		notify(actor.Player, "BICYCLE KICK!", C.Cyan)
	end
	local player = actor.Player
	local rockets = player and player:GetAttribute("RocketShots") or 0
	if rockets > 0 then
		player:SetAttribute("RocketShots", rockets - 1)
		-- gekaufte Schuesse sind gespeichert, damit sie beim Verlassen nicht verloren gehen
		local d = data(player)
		if d then
			d.RocketShots = rockets - 1
		end
		multiplier *= Config.RocketShotPower
		notify(player, `ROCKET SHOT! ({rockets - 1} left)`, C.Orange)
	end
	-- Power-Orb und Spielmodus "Mega Kicks"
	multiplier *= services().FeaturesService:KickBonus(actor)
	return multiplier
end

function ExtrasService:OnKick(actor, speed: number)
	if actor.Player then
		local kmh = math.floor(speed * 0.28 * 3.6)
		send(actor.Player, "ShotSpeed", kmh)
		services().FeaturesService:OnShot(actor.Player, kmh)
	end
end

function ExtrasService:GoalValue(): number
	return if now() < goldenUntil then 2 else 1
end

local function setGolden(on: boolean)
	local ball = services().BallService.Ball :: BasePart
	if on then
		goldenUntil = now() + Config.GoldenBallSeconds
		ball:SetAttribute("NormalColor", ball.Color)
		ball.Color = GOLD
		ball.Material = Enum.Material.Neon
		announce("GOLDEN BALL! Goals count DOUBLE for 45 seconds!", GOLD)
	else
		goldenUntil = 0
		ball.Color = ball:GetAttribute("NormalColor") or Color3.new(1, 1, 1)
		ball.Material = Enum.Material.SmoothPlastic
	end
	workspace:SetAttribute("GoldenBall", on)
end

-- Torjubel: der Torschuetze tanzt, das Alien seines Teams springt
local DANCE = "rbxassetid://507771019"
local function celebrate(scorer, teamName: string)
	if scorer then
		local animator = scorer.Humanoid:FindFirstChildOfClass("Animator")
		if animator then
			local animation = Instance.new("Animation")
			animation.AnimationId = DANCE
			local ok, track = pcall(animator.LoadAnimation, animator, animation)
			if ok and track then
				track:Play()
				task.delay(3.5, function()
					track:Stop()
				end)
			end
		end
	end
	local mascot = services().ArenaService.Mascots[teamName]
	if mascot then
		local model = mascot.Model :: Model
		local base = model:GetPivot()
		task.spawn(function()
			for i = 1, 30 do
				local t = i / 30
				model:PivotTo(base * CFrame.new(0, math.abs(math.sin(t * math.pi * 3)) * 6, 0) * CFrame.Angles(0, t * math.pi * 2, 0))
				task.wait(0.05)
			end
			model:PivotTo(base)
		end)
	end
end

function ExtrasService:OnGoal(scoringTeam: string, scorer, assist, distance: number?)
	local other = if scoringTeam == "Blue" then "Red" else "Blue"
	conceded[other] += 1
	local blue, red = workspace:GetAttribute("ScoreBlue") or 0, workspace:GetAttribute("ScoreRed") or 0
	maxDeficit.Blue = math.max(maxDeficit.Blue, red - blue)
	maxDeficit.Red = math.max(maxDeficit.Red, blue - red)
	if goldenUntil > now() then
		announce("GOLDEN GOAL! It counts DOUBLE!", GOLD)
		setGolden(false)
	end
	if not scorer then
		announce(`OWN GOAL! A gift for {string.upper(scoringTeam)}`, C.Orange)
	else
		self:Progress(scorer.Player, "Goal")
		if distance and distance >= 80 then
			announce(`SCREAMER! {scorer.Name} from {math.floor(distance)} studs!`, C.Cyan)
		end
		if scorer.Player then
			matchGoals[scorer.Player] = (matchGoals[scorer.Player] or 0) + 1
			if matchGoals[scorer.Player] == 3 then
				announce(`HAT-TRICK! {scorer.Name}`, GOLD)
				coins(scorer.Player, Config.HatTrickCoins)
			end
		end
	end
	if assist then
		self:Progress(assist.Player, "Assist")
	end
	celebrate(scorer, scoringTeam)
end

function ExtrasService:OnSteal(actor)
	self:Progress(actor.Player, "Steal")
end

function ExtrasService:OnSave(actor)
	self:Progress(actor.Player, "Save")
	if actor.Player then
		services().ProgressService:AddStat(actor.Player, "Saves", 1)
	end
end

function ExtrasService:OnPass(actor)
	self:Progress(actor.Player, "Pass")
end

---------------------------------------------------------------- Match-Anfang und -Ende

local baseLighting = nil
local function applyWeather()
	if not baseLighting then
		baseLighting = { ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient }
	end
	local roll = math.random()
	local weather = if roll < Config.NightChance then "Night" elseif roll < Config.NightChance + Config.RainChance then "Rain" else "Clear"
	for key, value in baseLighting do
		(Lighting :: any)[key] = value
	end
	if weather == "Night" then
		Lighting.ClockTime = 21.5
		Lighting.Brightness = 1.2
		Lighting.Ambient = Color3.fromRGB(60, 60, 80)
		Lighting.OutdoorAmbient = Color3.fromRGB(70, 70, 95)
		announce("NIGHT MATCH under the floodlights!", C.Cyan)
	elseif weather == "Rain" then
		Lighting.Brightness = 1.2
		Lighting.OutdoorAmbient = Color3.fromRGB(95, 98, 105)
		announce("RAIN MATCH! Slippery pitch!", C.Cyan)
	end
	workspace:SetAttribute("Weather", weather)
	local lamps = workspace:FindFirstChild("Arena") and workspace.Arena:FindFirstChild("Floodlights")
	if lamps then
		for _, light in lamps:GetDescendants() do
			if light:IsA("SpotLight") then
				light.Brightness = if weather == "Night" then 6 else 3
				light.Range = if weather == "Night" then 60 else 60
			end
		end
	end
end

function ExtrasService:OnMatchStart()
	firstBlood = false
	table.clear(matchGoals)
	table.clear(streaks)
	table.clear(lastKiller)
	maxDeficit.Blue, maxDeficit.Red = 0, 0
	conceded.Blue, conceded.Red = 0, 0
	lastMinuteWarned = false
	setGolden(false)
	goldenPlanned = os.clock() + math.random(60, 180)
	applyWeather()
end

function ExtrasService:OnMatchEnd(winner: string?)
	setGolden(false)
	for _, player in Players:GetPlayers() do
		local team = player:GetAttribute("Team")
		local d = data(player)
		if team and d then
			self:Progress(player, "Match")
			if winner == team then
				self:Progress(player, "Win")
				d.WinStreak += 1
				local bonus = Config.WinStreakCoins * math.min(5, d.WinStreak)
				coins(player, bonus)
				notify(player, `WIN STREAK {d.WinStreak}! +{bonus} coins`, GOLD)
				if conceded[team] == 0 then
					coins(player, 150)
					notify(player, "CLEAN SHEET! +150 coins", C.Lime)
				end
				if maxDeficit[team] >= 3 then
					coins(player, 200)
					notify(player, "COMEBACK WIN! +200 coins", C.Lime)
				end
			elseif winner ~= nil then
				d.WinStreak = 0
			end
			self:RefreshTitle(player)
			task.spawn(saveGoals, player)
		end
	end
end

---------------------------------------------------------------- Laufende Pruefungen (jede Sekunde)

local function tick()
	local match = services().MatchService
	local combat = services().CombatService
	local state = match:GetState()
	local t = now()
	-- Heilung ausserhalb des Kampfes
	for _, actor in match:GetActors() do
		if not combat:IsKO(actor) and t - (actor.LastHurt or 0) > Config.RegenDelay and actor.HP < (actor.MaxHP or Config.MaxHP) then
			combat:AddHP(actor, Config.RegenPerSecond)
		end
	end
	if state == "Playing" then
		if os.clock() > goldenPlanned then
			goldenPlanned = math.huge
			setGolden(true)
		elseif goldenUntil > 0 and t > goldenUntil then
			setGolden(false)
			announce("The golden ball is back to normal", C.White)
		end
		local left = workspace:GetAttribute("TimeLeft") or 999
		if not lastMinuteWarned and left <= 60 and left > 50 then
			lastMinuteWarned = true
			announce("LAST MINUTE!", C.Red)
			services().Net.PlaySound("Whistle")
		end
	end
	-- "On Fire": lange am Ball = Flammen
	local carrier = services().BallService.Carrier
	if carrier ~= lastCarrier then
		lastCarrier = carrier
		carrierSince = os.clock()
	end
	local burning = if carrier and os.clock() - carrierSince > Config.OnFireSeconds then carrier else nil
	if burning ~= onFireActor then
		if onFireActor and onFireActor.Root then
			local old = onFireActor.Root:FindFirstChild("OnFire")
			if old then
				old:Destroy()
			end
		end
		onFireActor = burning
		if burning then
			local fire = Instance.new("Fire")
			fire.Name = "OnFire"
			fire.Size = 6
			fire.Heat = 8
			fire.Color = Color3.fromRGB(255, 120, 30)
			fire.SecondaryColor = Color3.fromRGB(255, 220, 80)
			fire.Parent = burning.Root
			notify(burning.Player, "YOU'RE ON FIRE!", C.Orange)
		end
	end
	-- Spawn-Schutz sichtbar machen
	for _, actor in match:GetActors() do
		local protected = (actor.SpawnProtectUntil or 0) > t
		local glow = actor.Model:FindFirstChild("SpawnGlow")
		if protected and not glow then
			local h = Instance.new("Highlight")
			h.Name = "SpawnGlow"
			h.FillColor = Color3.new(1, 1, 1)
			h.FillTransparency = 0.6
			h.OutlineTransparency = 1
			h.Parent = actor.Model
		elseif not protected and glow then
			glow:Destroy()
		end
	end
end

---------------------------------------------------------------- Kaeufe und Skins

function ExtrasService:Giant(player: Player, seconds: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	player:SetAttribute("GiantUntil", math.max(now(), player:GetAttribute("GiantUntil") or 0) + seconds)
	local function scale(value: number)
		for _, name in { "BodyHeightScale", "BodyWidthScale", "BodyDepthScale", "HeadScale" } do
			local v = humanoid:FindFirstChild(name) :: NumberValue?
			if v then
				v:SetAttribute("Base", v:GetAttribute("Base") or v.Value)
				v.Value = (v:GetAttribute("Base") :: number) * value
			end
		end
	end
	scale(Config.GiantScale)
	announce(`{player.DisplayName} became a GIANT!`, C.Orange)
	task.delay(seconds, function()
		if humanoid.Parent and not Config.Active(player, "GiantUntil") then
			scale(1)
		end
	end)
end

local function skinAction(player: Player, id: string)
	local skin = Config.SwordSkinsById[id]
	local d = data(player)
	if not skin or not d then
		return
	end
	if not d.SwordSkins[id] then
		if skin.Pass then
			if not hasPass(player, skin.Pass) then
				services().Net.Offer:FireClient(player, skin.Pass)
				return
			end
		else
			if d.Coins < skin.Price then
				services().Net.Offer:FireClient(player, "Coins")
				return
			end
			d.Coins -= skin.Price
		end
		d.SwordSkins[id] = true
		notify(player, `New katana: {skin.Name}!`, C.Lime)
	end
	d.SwordSkin = id
	player:SetAttribute("SwordSkin", id)
	services().ProgressService:Refresh(player)
	local actor = services().MatchService:ActorForPlayer(player)
	if actor then
		services().CombatService:RefreshSword(actor)
	end
	send(player, "Skins", { Owned = d.SwordSkins, Equipped = d.SwordSkin })
end

---------------------------------------------------------------- Start

function ExtrasService:Init(svc)
	self.Services = svc
	remote = Instance.new("RemoteEvent")
	remote.Name = "Extras"
	remote.Parent = ReplicatedStorage:WaitForChild("Remotes")
	local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "SoccerJamGoals_v1")
	leaderboard = if ok then store else nil
end

function ExtrasService:OnPlayerReady(player: Player)
	local d = data(player)
	if not d then
		return
	end
	if not Config.SwordSkinsById[d.SwordSkin or ""] then
		d.SwordSkin = "classic"
	end
	player:SetAttribute("SwordSkin", d.SwordSkin)
	player:SetAttribute("RespawnTokens", d.RespawnTokens or 0)
	player:SetAttribute("RocketShots", d.RocketShots or 0)
	send(player, "Settings", d.Settings)
	sendQuests(player)
	send(player, "Skins", { Owned = d.SwordSkins, Equipped = d.SwordSkin })
	player.CharacterAdded:Connect(function()
		task.wait(1)
		self:RefreshTitle(player)
	end)
	if player.Character then
		task.spawn(function()
			task.wait(1)
			self:RefreshTitle(player)
			-- Schwert wurde evtl. vor dem Laden des Skins gebaut
			local actor = services().MatchService:ActorForPlayer(player)
			if actor and d.SwordSkin ~= "classic" then
				services().CombatService:RefreshSword(actor)
			end
		end)
	end
	-- Spielzeit-Belohnung
	task.spawn(function()
		while player.Parent do
			task.wait(Config.PlaytimeMinutes * 60)
			if player.Parent then
				coins(player, Config.PlaytimeCoins)
				notify(player, `Thanks for playing! +{Config.PlaytimeCoins} coins`, C.Lime)
			end
		end
	end)
end

-- Level-Belohnung alle 5 Account-Level
function ExtrasService:OnLevelUp(player: Player, level: number)
	if level % Config.LevelRewardEvery == 0 then
		coins(player, Config.LevelRewardCoins)
		notify(player, `LEVEL {level} REWARD! +{Config.LevelRewardCoins} coins`, GOLD)
	end
	self:RefreshTitle(player)
end

function ExtrasService:Start()
	task.spawn(buildBoard)
	task.spawn(function()
		task.wait(5)
		while true do
			refreshBoard()
			task.wait(120)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Extras] tick:", err)
			end
		end
	end)
	-- Pfosten- und Lattentreffer
	local ball = services().BallService.Ball :: BasePart
	ball.Touched:Connect(function(part)
		if part.Name == "Post" and os.clock() > postCooldown and ball.AssemblyLinearVelocity.Magnitude > 25 then
			postCooldown = os.clock() + 3
			services().Net.PlaySound("Post", ball.Position)
			announce("OFF THE POST!", C.White)
		end
	end)
	remote.OnServerEvent:Connect(function(player, action, arg)
		if action == "Quests" then
			sendQuests(player)
		elseif action == "Stats" then
			sendStats(player)
		elseif action == "Skin" and typeof(arg) == "string" then
			skinAction(player, arg)
		elseif action == "Settings" and typeof(arg) == "table" then
			local d = data(player)
			if d then
				-- NaN vom Client abfangen (wuerde gespeichert und die Kamera kaputt machen)
				local function number(value: any, default: number, low: number, high: number): number
					local n = tonumber(value)
					if n == nil or n ~= n then
						return default
					end
					return math.clamp(n, low, high)
				end
				d.Settings = {
					Fov = number(arg.Fov, 70, 60, 100),
					Crowd = number(arg.Crowd, 1, 0, 1),
					FirstPerson = arg.FirstPerson ~= false,
				}
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		matchGoals[player] = nil
		task.spawn(saveGoals, player)
	end)
end

-- Aufraeumen, wenn ein Akteur das Spiel verlaesst
function ExtrasService:Forget(actor)
	streaks[actor] = nil
	lastKiller[actor] = nil
	combos[actor] = nil
	if onFireActor == actor then
		onFireActor = nil
	end
end

return ExtrasService
