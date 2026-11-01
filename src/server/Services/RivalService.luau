-- Rivalen-Basen: Solange wenige echte Spieler da sind, werden freie Basen von NPC-Rivalen belegt.
-- So kann man auch allein auf einem Server klauen (Kern des Spiels und Tutorial-Schritt "Steal").
-- Die Kreaturen der Rivalen passen sich dem Einkommen der Spieler an und kommen nach einer Weile wieder.
-- Jede Rivalen-Basis hat einen sichtbaren Bot: er bewacht seine Tiere (jagt und schlaegt Diebe) und
-- klaut ab und zu selbst ein Tier aus einer Spieler-Basis. Wer ihn schlaegt, bekommt das Tier zurueck;
-- schafft er es nach Hause, steht das Tier in seiner Basis und kann sofort zurueckgeklaut werden.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Units = require(ReplicatedStorage.Shared.Units)
local UnitFactory = require(script.Parent.UnitFactory)
local NpcBody = require(script.Parent.NpcBody)

local RivalService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)

local R = Config.Rivals
local rivals = {} -- [plot] = { Name, OwnerId, Models = { [slotKey] = Model }, NextLockAt }
local carrying = {} -- [Player] = { Rival, SlotKey, Code, Visual, Highlight, StartedAt }
local holdStarted = {} -- [Player] = { At, Prompt }
local lastSteal = {} -- [Player] = os.clock()
local nextOwnerId = -1
local lastRaidOn = {} -- [Player] = os.clock() des letzten Bot-Angriffs auf diesen Spieler

local function notify(player: Player, text: string, color: Color3?)
	RivalService.Services.Net.SendNotify(player, text, color)
end

function RivalService:Init(services)
	self.Services = services
end

function RivalService:IsRival(plot): boolean
	return rivals[plot] ~= nil
end

function RivalService:IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

-- Hoechster Preis einer Rivalen-Kreatur: ein paar Sekunden Einkommen der Spieler (Durchschnitt), mindestens MinPrice
local function maxPrice(): number
	local total, count = 0, 0
	for _, player in Players:GetPlayers() do
		total += tonumber(player:GetAttribute("IncomePerSec")) or 0
		count += 1
	end
	local average = if count > 0 then total / count else 0
	return math.max(R.MinPrice, average * R.IncomeSeconds)
end

local function pickCode(): string
	local limit = maxPrice()
	local affordable = {}
	for _, def in Config.Units do
		if def.Price <= limit and Config.RaritiesByName[def.Rarity].Weight >= 0.1 then
			table.insert(affordable, def)
		end
	end
	if #affordable == 0 then
		return Units.Encode(Config.Units[1].Id)
	end
	table.sort(affordable, function(a, b)
		return a.Price > b.Price
	end)
	-- Aus den teuersten passenden waehlen, damit sich das Klauen lohnt
	local def = affordable[math.random(1, math.min(R.PickFrom, #affordable))]
	return Units.Encode(def.Id)
end

local function slotCFrame(plot, slotKey: string, info): CFrame
	local offset = RivalService.Services.WorldService.PadOffset(tonumber(slotKey) :: number)
	return plot.CFrame * CFrame.new(offset + Vector3.new(0, info.Scale * 0.6 + 0.3, 0))
end

local startSteal: (thief: Player, plot: any, slotKey: string, prompt: ProximityPrompt) -> ()

local function placeCritter(plot, slotKey: string, forcedCode: string?, stolenFrom: string?)
	local rival = rivals[plot]
	if not rival or rival.Models[slotKey] then
		return
	end
	local code = forcedCode or pickCode()
	local info = Units.Info(code)
	if not info then
		return
	end
	local model = UnitFactory.Build(info)
	model:PivotTo(slotCFrame(plot, slotKey, info))
	UnitFactory.AddLabel(model, info, "+" .. Format.Cash(info.Income) .. "/s")
	-- Negative Id: der Client behandelt die Kreatur wie die eines fremden Spielers (Steal-Prompt, Tutorial-Pfeil)
	model:SetAttribute("OwnerUserId", rival.OwnerId)
	model:SetAttribute("SlotKey", slotKey)
	model:SetAttribute("Code", code)
	model:SetAttribute("Rival", true)
	if stolenFrom then
		model:SetAttribute("StolenFrom", stolenFrom)
	end
	local pad = plot.Pads[tonumber(slotKey) :: number]
	if pad then
		pad.Color = plot.Accent
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = info.Name
	prompt.HoldDuration = Config.StealHoldTime
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", rival.OwnerId)
	prompt.Parent = UnitFactory.PromptAnchor(model, info)
	prompt.PromptButtonHoldBegan:Connect(function(thief)
		holdStarted[thief] = { At = os.clock(), Prompt = prompt }
	end)
	prompt.Triggered:Connect(function(thief)
		startSteal(thief, plot, slotKey, prompt)
	end)

	model.Parent = plot.Model
	rival.Models[slotKey] = model
end

local function claim(plot)
	local name = R.Names[math.random(1, #R.Names)]
	rivals[plot] = { Name = name, OwnerId = nextOwnerId, Models = {}, NextLockAt = os.clock() + math.random(R.LockEvery[1], R.LockEvery[2]) }
	nextOwnerId -= 1
	plot.LockedUntil = 0
	plot.SignLabel.Text = `🤖 {name}'s Base`
	for index, pad in plot.Pads do
		pad.Color = if index <= R.Critters then plot.Accent else Color3.fromRGB(110, 105, 100)
	end
	for index = 1, R.Critters do
		placeCritter(plot, tostring(index))
	end
	if R.Bots then
		RivalService.SpawnBot(plot)
	end
end

local function endSteal(thief: Player, success: boolean)
	local info = carrying[thief]
	if not info then
		return
	end
	carrying[thief] = nil
	thief:SetAttribute("Carrying", nil)
	if info.Visual then
		info.Visual:Destroy()
	end
	if info.Highlight then
		info.Highlight:Destroy()
	end
	local services = RivalService.Services
	local rival = rivals[info.Plot]
	local model = rival and rival.Models[info.SlotKey]
	if success and thief.Parent then
		local slot = services.UnitService:FindFreeSlot(thief)
		if slot then
			local def = Units.Info(info.Code)
			task.spawn(services.UnitService.GiveUnit, services.UnitService, thief, info.Code, slot)
			services.ProgressService:Track(thief, "Stolen", 1)
			services.EventService:AddGoalProgress(1)
			services.Net.PlaySfx(thief, "Steal")
			notify(thief, `You stole {def and def.Name or "an animal"} from {info.Name}! Steal from real players for bigger loot.`, GREEN)
			lastSteal[thief] = os.clock()
			if model then
				model:Destroy()
				rival.Models[info.SlotKey] = nil
			end
			-- Der Rivale kauft spaeter eine neue Kreatur
			task.delay(R.RespawnTime, function()
				if rivals[info.Plot] == rival and (tonumber(info.SlotKey) or 99) <= R.Critters then
					placeCritter(info.Plot, info.SlotKey)
				end
			end)
			return
		end
		notify(thief, "Your base is full, so the animal ran back home!", RED)
	end
	if model and model.Parent then
		model:SetAttribute("BeingStolen", false)
		UnitFactory.SetTransparency(model, 0)
		info.Prompt.Enabled = true
	end
end

startSteal = function(thief: Player, plot, slotKey: string, prompt: ProximityPrompt)
	local services = RivalService.Services
	local rival = rivals[plot]
	local model = rival and rival.Models[slotKey]
	if not model or model:GetAttribute("BeingStolen") then
		return
	end
	if carrying[thief] or services.UnitService:IsCarrying(thief) then
		notify(thief, "You are already carrying an animal!", RED)
		return
	end
	if plot.LockedUntil > os.clock() then
		notify(thief, `{rival.Name} locked the base! Wait a moment.`, RED)
		return
	end
	local wait = R.StealCooldown - (os.clock() - (lastSteal[thief] or 0))
	if wait > 0 then
		notify(thief, `{rival.Name} is watching you! Try again in {math.ceil(wait)}s.`, RED)
		return
	end
	-- Haltezeit serverseitig pruefen (wie beim Klauen von Spielern)
	local required = if services.MonetizationService:HasPass(thief, "FastSteal") then Config.FastStealHoldTime else Config.StealHoldTime
	required = math.max(0.4, required - services.FeatureService:StealHoldBonus(thief))
	local began = holdStarted[thief]
	holdStarted[thief] = nil
	if not began or began.Prompt ~= prompt or os.clock() - began.At < required - 0.35 then
		return
	end
	local character = thief.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or humanoid.Health <= 0 then
		return
	end
	if not services.UnitService:FindFreeSlot(thief) then
		notify(thief, "Your base is full! Hold R on an animal to sell it.", RED)
		return
	end
	local code = model:GetAttribute("Code")
	local def = Units.Info(code)
	if not def then
		return
	end

	model:SetAttribute("BeingStolen", true)
	UnitFactory.SetTransparency(model, 0.7)
	prompt.Enabled = false

	local visual = UnitFactory.Build(def)
	visual.Name = "StolenCritter"
	for _, part in visual:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end
	visual:PivotTo(head.CFrame * CFrame.new(0, 0.8 + def.Scale / 2, 0))
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = visual.PrimaryPart
	weld.Parent = visual
	visual.Parent = character

	local highlight = Instance.new("Highlight")
	highlight.Name = "ThiefHighlight"
	highlight.FillColor = Color3.fromRGB(255, 50, 50)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 220, 60)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	carrying[thief] = { Plot = plot, Name = rival.Name, SlotKey = slotKey, Code = code, Visual = visual, Highlight = highlight, Prompt = prompt, StartedAt = os.clock() }
	thief:SetAttribute("Carrying", def.Name)
	notify(thief, `You grabbed {def.Name}! Run back to your base!`, GOLD)
	RivalService.Defend(plot, thief)
end

-- Rivalen-Basis freigeben (z.B. weil ein echter Spieler die Basis bekommt)
function RivalService:Release(plot)
	local rival = rivals[plot]
	if not rival then
		return
	end
	rivals[plot] = nil
	RivalService.RemoveBot(rival)
	for thief, info in carrying do
		if info.Plot == plot then
			notify(thief, `{info.Name} left the server, the animal ran away!`, RED)
			endSteal(thief, false)
		end
	end
	for _, model in rival.Models do
		model:Destroy()
	end
	plot.LockedUntil = 0
	plot.Barrier.Transparency = 1
	plot.SignLabel.Text = "Empty Base"
	plot.LockLabel.Text = "LOCK BASE"
	for _, pad in plot.Pads do
		pad.Color = Color3.fromRGB(110, 105, 100)
	end
end

-- So viele Rivalen wie noetig: wenige Spieler = mehr Rivalen
-- playerCount nur fuer Tests, sonst die echte Spielerzahl
function RivalService:Balance(playerCount: number?)
	local world = RivalService.Services.WorldService
	local players = playerCount or #Players:GetPlayers()
	local wanted = if players == 0 then 0 else math.clamp(R.FillUntilPlayers - players, 0, R.MaxBases)
	local count = 0
	for _ in rivals do
		count += 1
	end
	if count > wanted then
		for plot in rivals do
			if count <= wanted then
				break
			end
			RivalService:Release(plot)
			count -= 1
		end
	elseif count < wanted then
		-- Freie Basen am Ende der Liste nehmen, damit neue Spieler vorne ihre Basis bekommen
		for index = #world.Plots, 1, -1 do
			local plot = world.Plots[index]
			if count >= wanted then
				break
			end
			if plot.Owner == nil and not rivals[plot] then
				claim(plot)
				count += 1
			end
		end
	end
end

function RivalService:Start()
	local world = self.Services.WorldService
	local function balance()
		self:Balance()
	end
	Players.PlayerAdded:Connect(function()
		task.defer(balance)
	end)
	Players.PlayerRemoving:Connect(function(player)
		endSteal(player, false)
		holdStarted[player] = nil
		lastSteal[player] = nil
		lastRaidOn[player] = nil
		RivalService.ForgetPlayer(player)
		task.delay(1, balance)
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			-- Diebe: zu Hause angekommen, gestorben oder zu langsam?
			for thief, info in carrying do
				local character = thief.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local plot = self.Services.PlotService:GetPlot(thief)
				if not root or not humanoid or humanoid.Health <= 0 then
					endSteal(thief, false)
				elseif now - info.StartedAt > Config.StealTimeout then
					notify(thief, "Too slow! The animal ran home.", RED)
					endSteal(thief, false)
				elseif plot and world.IsInside(plot, root.Position) then
					endSteal(thief, true)
				end
			end
			-- Rivalen sperren ab und zu ihre Basis
			for plot, rival in rivals do
				if now >= rival.NextLockAt then
					plot.LockedUntil = now + R.LockDuration
					rival.NextLockAt = plot.LockedUntil + math.random(R.LockEvery[1], R.LockEvery[2])
				end
				local locked = plot.LockedUntil > now
				plot.Barrier.Transparency = if locked then 0.3 else 1
				plot.LockLabel.Text = if locked then "LOCKED " .. Format.Time(plot.LockedUntil - now) else "OPEN"
				if locked then
					for _, player in Players:GetPlayers() do
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if root and world.IsInside(plot, root.Position) and not carrying[player] then
							character:PivotTo(plot.CFrame * CFrame.new(0, 4, -(plot.HalfSize + 6)))
						end
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			balance()
			task.wait(10)
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local dt = math.min(now - last, 0.5)
			last = now
			for plot, rival in rivals do
				if rival.Bot then
					local ok, err = pcall(RivalService.StepBot, plot, rival, dt, now)
					if not ok then
						warn("[RivalService] Bot:", err)
					end
				end
			end
		end
	end)
end

---------------------------------------------------------------- Bots

local BOT_RED = Color3.fromRGB(255, 90, 90)

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Boden: in Basen 1 Stud hoch (Holzboden), sonst 0
local function groundY(pos: Vector3): number
	for _, plot in RivalService.Services.WorldService.Plots do
		if RivalService.Services.WorldService.IsInside(plot, Vector3.new(pos.X, plot.CFrame.Y + 1, pos.Z)) then
			return plot.CFrame.Y
		end
	end
	return 0
end

local function entrance(plot): Vector3
	return flat((plot.CFrame * CFrame.new(0, 0, -(plot.HalfSize + 4))).Position)
end

local function guardSpot(plot): Vector3
	return flat((plot.CFrame * CFrame.new(math.random(-10, 10), 0, -14)).Position)
end

local function padFront(plot, index: number): Vector3
	return flat((plot.CFrame * CFrame.new(RivalService.Services.WorldService.PadOffset(index) + Vector3.new(0, 0, -3.5))).Position)
end

local function setStatus(bot, text: string)
	if bot.Status and bot.Status.Text ~= text then
		bot.Status.Text = text
	end
end

function RivalService.SpawnBot(plot)
	local rival = rivals[plot]
	if not rival or rival.Bot then
		return
	end
	local model, _, root = NpcBody.Build(rival.Name, { Hat = plot.Accent, Tag = "RivalBot" })
	local start = guardSpot(plot)
	local height = NpcBody.RootHeight(model)
	model:PivotTo(CFrame.lookAt(start + Vector3.new(0, groundY(start) + height, 0), entrance(plot) + Vector3.new(0, groundY(start) + height, 0)))
	local _, _, status = NpcBody.Tag(model, "🤖 BOT", BOT_RED, 80)
	model.Parent = workspace
	rival.Bot = {
		Model = model,
		Root = root,
		Height = height,
		Pos = start,
		State = "Home",
		Path = {},
		Speed = R.BotWalkSpeed,
		IdleUntil = 0,
		StunUntil = 0,
		NextRaidAt = os.clock() + math.random(R.FirstRaid[1], R.FirstRaid[2]),
		Status = status,
	}
	setStatus(rival.Bot, "Guarding")
	NpcBody.Poof(start + Vector3.new(0, 3, 0))
end

local function dropCarry(bot, giveBack: boolean)
	local carry = bot.Carry
	if not carry then
		return
	end
	bot.Carry = nil
	if carry.Visual then
		carry.Visual:Destroy()
	end
	if carry.Highlight then
		carry.Highlight:Destroy()
	end
	if giveBack then
		RivalService.Services.UnitService:BotRelease(carry.Owner, carry.SlotKey, carry.Model)
	end
end

local function goHome(plot, bot)
	bot.State = "Return"
	bot.Raid = nil
	bot.Chase = nil
	bot.Speed = R.BotWalkSpeed
	bot.Path = { entrance(plot), guardSpot(plot) }
	setStatus(bot, "Going home")
end

function RivalService.RemoveBot(rival)
	local bot = rival and rival.Bot
	if not bot then
		return
	end
	rival.Bot = nil
	dropCarry(bot, true)
	if bot.Model then
		NpcBody.Poof(bot.Pos + Vector3.new(0, 3, 0))
		bot.Model:Destroy()
	end
end

function RivalService.ForgetPlayer(player: Player)
	for plot, rival in rivals do
		local bot = rival.Bot
		if bot and ((bot.Raid and bot.Raid.Owner == player) or (bot.Carry and bot.Carry.Owner == player) or (bot.Chase and bot.Chase.Thief == player)) then
			dropCarry(bot, false)
			goHome(plot, bot)
		end
	end
end

-- Ein Dieb klaut aus der Rivalen-Basis: der Bot bemerkt es kurz danach und jagt ihn
function RivalService.Defend(plot, thief: Player)
	local rival = rivals[plot]
	local bot = rival and rival.Bot
	if not bot or (bot.State ~= "Home" and bot.State ~= "Return") then
		return
	end
	task.delay(R.ChaseDelay, function()
		if rival.Bot ~= bot or (bot.State ~= "Home" and bot.State ~= "Return") or os.clock() < bot.StunUntil then
			return
		end
		local info = carrying[thief]
		if not info or info.Plot ~= plot then
			return
		end
		bot.State = "Chase"
		bot.Chase = { Thief = thief, Until = os.clock() + R.ChaseTime }
		bot.Speed = R.BotChaseSpeed
		setStatus(bot, "Chasing " .. thief.DisplayName .. "!")
		NpcBody.Say(bot.Model, "Hey! Thief! Come back!", 2.5)
		notify(thief, `🤖 {rival.Name} spotted you! Run home before they slap you!`, RED)
	end)
end

-- Opfer fuer einen Bot-Angriff: Spieler mit genug Tieren, kein Schutz, nicht kuerzlich angegriffen.
-- Das wertvollste Tier, Favoriten und der Tresor sind tabu.
local function pickRaid(): (Player?, string?)
	local services = RivalService.Services
	local now = os.clock()
	local options = {}
	for _, player in Players:GetPlayers() do
		local data = services.DataService:Get(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local plot = services.PlotService:GetPlot(player)
		if data and plot and humanoid and humanoid.Health > 0 and now - (lastRaidOn[player] or -1e9) >= R.VictimCooldown then
			local slots, bestSlot, bestValue = {}, nil, -1
			for slot, code in data.Units do
				local info = Units.Info(code)
				if info then
					table.insert(slots, slot)
					if info.Value > bestValue then
						bestSlot, bestValue = slot, info.Value
					end
				end
			end
			if #slots >= R.MinUnitsToRaid then
				for _, slot in slots do
					if slot ~= bestSlot and services.UnitService:CanBotSteal(player, slot) then
						table.insert(options, { player, slot })
					end
				end
			end
		end
	end
	if #options == 0 then
		return nil, nil
	end
	local choice = options[math.random(1, #options)]
	return choice[1], choice[2]
end

local function freeRivalSlot(plot, rival): string?
	for index = 1, #plot.Pads do
		local key = tostring(index)
		if not rival.Models[key] then
			return key
		end
	end
	return nil
end

local function slapThief(plot, rival, bot, thief: Player)
	local character = thief.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	endSteal(thief, false)
	notify(thief, `🤖 {rival.Name} slapped you! The animal ran back home.`, RED)
	RivalService.Services.Net.PlaySfx(thief, "Slap")
	NpcBody.Say(bot.Model, "Got you! Hands off my animals!", 2.5)
	if humanoid then
		humanoid.WalkSpeed = 0
		task.delay(Config.SlapStunTime, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = thief:GetAttribute("BaseWalkSpeed") or Config.DefaultWalkSpeed
				RivalService.Services.FeatureService:ApplySpeed(thief)
			end
		end)
	end
	goHome(plot, bot)
end

-- Bot erreicht das Ende seines Weges
local function arrive(plot, rival, bot, now: number)
	local services = RivalService.Services
	if bot.State == "Raid" then
		local raid = bot.Raid
		if raid and raid.Owner.Parent and services.UnitService:CanBotSteal(raid.Owner, raid.SlotKey) then
			bot.State = "Grab"
			raid.GrabUntil = now + R.GrabTime
			setStatus(bot, "Stealing...")
			NpcBody.Say(bot.Model, "Hehe, this one is mine...", R.GrabTime)
		else
			NpcBody.Say(bot.Model, "Hmph, locked up tight.", 2)
			goHome(plot, bot)
		end
	elseif bot.State == "Escape" then
		local carry = bot.Carry
		if not carry then
			goHome(plot, bot)
			return
		end
		local key = freeRivalSlot(plot, rival)
		local owner, slotKey, model, code = carry.Owner, carry.SlotKey, carry.Model, carry.Code
		dropCarry(bot, false)
		if key and services.UnitService:BotTake(owner, slotKey, model, code, rival.Name) then
			placeCritter(plot, key, code, owner.Name)
			lastSteal[owner] = nil -- Rache: sofort zurueckklauen erlaubt
			NpcBody.Say(bot.Model, "Too easy! Come get it back, " .. owner.DisplayName .. "!", 3)
		else
			services.UnitService:BotRelease(owner, slotKey, model)
		end
		bot.State = "Home"
		bot.Speed = R.BotWalkSpeed
		bot.Path = {}
		bot.NextRaidAt = now + math.random(R.RaidEvery[1], R.RaidEvery[2])
		setStatus(bot, "Guarding")
	elseif bot.State == "Return" then
		bot.State = "Home"
		setStatus(bot, "Guarding")
	end
end

function RivalService.StepBot(plot, rival, dt: number, now: number)
	local services = RivalService.Services
	local bot = rival.Bot
	if now < bot.StunUntil then
		NpcBody.Play(bot.Model, "Idle")
		return
	end

	if bot.State == "Home" then
		if now >= bot.NextRaidAt then
			local victim, slotKey = pickRaid()
			if victim and slotKey then
				local victimPlot = services.PlotService:GetPlot(victim)
				lastRaidOn[victim] = now
				bot.State = "Raid"
				bot.Raid = { Owner = victim, SlotKey = slotKey, Started = now }
				bot.Speed = R.BotWalkSpeed
				bot.Path = { entrance(plot), entrance(victimPlot), padFront(victimPlot, tonumber(slotKey) :: number) }
				setStatus(bot, "Raiding " .. victim.DisplayName .. "!")
				NpcBody.Say(bot.Model, "Time to go shopping...", 2.5)
				notify(victim, `🤖 {rival.Name} is coming to steal from your base! Lock it or slap them!`, RED)
				services.Net.PlaySfx(victim, "Alarm")
			else
				bot.NextRaidAt = now + 20
			end
		elseif #bot.Path == 0 and now >= bot.IdleUntil then
			-- Wache: kleine Runden vor den eigenen Tieren
			bot.Path = { guardSpot(plot) }
			bot.IdleUntil = now + math.random(3, 7)
		end
	elseif bot.State == "Raid" then
		local raid = bot.Raid
		if not raid or not raid.Owner.Parent or now - raid.Started > 60 then
			goHome(plot, bot)
		end
	elseif bot.State == "Grab" then
		local raid = bot.Raid
		if not raid or not raid.Owner.Parent or not services.UnitService:CanBotSteal(raid.Owner, raid.SlotKey) then
			goHome(plot, bot)
		elseif now >= raid.GrabUntil then
			local code, model = services.UnitService:BotGrab(raid.Owner, raid.SlotKey)
			local def = Units.Info(code)
			if not code or not def then
				goHome(plot, bot)
			else
				local visual = UnitFactory.Build(def)
				visual.Name = "StolenCritter"
				for _, part in visual:GetDescendants() do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = false
						part.CanQuery = false
						part.Massless = true
					end
				end
				local head = bot.Model:FindFirstChild("Head") :: BasePart?
				local anchor = head or bot.Root
				visual:PivotTo(anchor.CFrame * CFrame.new(0, 0.8 + def.Scale / 2, 0))
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = anchor
				weld.Part1 = visual.PrimaryPart
				weld.Parent = visual
				visual.Parent = bot.Model
				local highlight = Instance.new("Highlight")
				highlight.Name = "ThiefHighlight"
				highlight.FillColor = Color3.fromRGB(255, 50, 50)
				highlight.FillTransparency = 0.6
				highlight.OutlineColor = Color3.fromRGB(255, 220, 60)
				highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				highlight.Parent = bot.Model
				bot.Carry = { Owner = raid.Owner, SlotKey = raid.SlotKey, Code = code, Model = model, Visual = visual, Highlight = highlight, Started = now }
				bot.Raid = nil
				bot.State = "Escape"
				bot.Speed = R.BotCarrySpeed
				local victimPlot = services.PlotService:GetPlot(raid.Owner)
				bot.Path = { if victimPlot then entrance(victimPlot) else entrance(plot), entrance(plot), guardSpot(plot) }
				setStatus(bot, "Carrying " .. def.Name .. "!")
				NpcBody.Say(bot.Model, "Got it! Bye bye!", 2)
				notify(raid.Owner, `🤖 {rival.Name} is stealing your {def.Name}! Slap them to get it back!`, RED)
				services.Net.PlaySfx(raid.Owner, "Alarm")
			end
		end
		NpcBody.Play(bot.Model, "Idle")
		return
	elseif bot.State == "Escape" then
		local carry = bot.Carry
		if not carry or not carry.Owner.Parent or now - carry.Started > Config.StealTimeout then
			if carry and carry.Owner.Parent then
				notify(carry.Owner, `🤖 {rival.Name} was too slow - your animal ran back home!`, GREEN)
			end
			dropCarry(bot, true)
			goHome(plot, bot)
		end
	elseif bot.State == "Chase" then
		local chase = bot.Chase
		local thief = chase and chase.Thief
		local info = thief and carrying[thief]
		local root = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not info or info.Plot ~= plot or not root or now > chase.Until then
			if thief and not info then
				NpcBody.Say(bot.Model, "Grr... next time!", 2)
			end
			goHome(plot, bot)
		else
			local target = flat(root.Position)
			if (target - bot.Pos).Magnitude <= R.BotSlapRange then
				slapThief(plot, rival, bot, thief)
			else
				bot.Path = { target }
			end
		end
	end

	-- Bewegen entlang des Weges
	local target = bot.Path[1]
	if target then
		local offset = target - bot.Pos
		local distance = offset.Magnitude
		local stepLength = bot.Speed * dt
		if distance <= math.max(stepLength, 0.3) then
			bot.Pos = target
			table.remove(bot.Path, 1)
			if #bot.Path == 0 then
				arrive(plot, rival, bot, now)
			end
		else
			bot.Pos += offset.Unit * stepLength
		end
		local y = groundY(bot.Pos) + bot.Height
		local look = if distance > 0.05 then offset.Unit else bot.Root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then
			look = Vector3.new(0, 0, -1)
		end
		bot.Root.CFrame = CFrame.lookAt(Vector3.new(bot.Pos.X, y, bot.Pos.Z), Vector3.new(bot.Pos.X, y, bot.Pos.Z) + look.Unit)
		NpcBody.Play(bot.Model, if bot.Speed > R.BotWalkSpeed then "Run" else "Walk", bot.Speed / 14)
	else
		NpcBody.Play(bot.Model, "Idle")
	end
end

-- Spieler schlaegt: trifft er einen Bot (in Reichweite und vor ihm), wird der Bot betaeubt.
-- Ein Bot mit Beute laesst sie fallen. Liefert true, wenn ein Bot getroffen wurde.
function RivalService:SlapBot(player: Player, root: BasePart, maxDistance: number): boolean
	local best, bestPlot, bestDistance = nil, nil, maxDistance
	for plot, rival in rivals do
		local bot = rival.Bot
		if bot then
			local offset = bot.Root.Position - root.Position
			local distance = offset.Magnitude
			if distance < bestDistance and (distance < 3 or offset.Unit:Dot(root.CFrame.LookVector) > 0.2) then
				best, bestPlot, bestDistance = bot, plot, distance
			end
		end
	end
	if not best then
		return false
	end
	local rival = rivals[bestPlot]
	best.StunUntil = os.clock() + R.BotStunTime
	if best.Carry then
		local carry = best.Carry
		local def = Units.Info(carry.Code)
		dropCarry(best, true)
		if carry.Owner == player then
			if self.Services.ExtraService and self.Services.ExtraService.LogBot then
				self.Services.ExtraService:LogBot(player, "Defended", rival.Name, def)
			end
			notify(player, `You slapped {rival.Name} and saved your {def and def.Name or "animal"}!`, GREEN)
		else
			notify(player, `You slapped {rival.Name} and saved {carry.Owner.DisplayName}'s animal!`, GREEN)
			if carry.Owner.Parent then
				notify(carry.Owner, `{player.DisplayName} slapped {rival.Name} and saved your {def and def.Name or "animal"}!`, GREEN)
			end
		end
		NpcBody.Say(best.Model, "Ouch! Fine, keep it!", 2.5)
		goHome(bestPlot, best)
		best.NextRaidAt = os.clock() + math.random(R.RaidEvery[1], R.RaidEvery[2])
	else
		NpcBody.Say(best.Model, "Ouch!", 1.5)
		if best.State == "Raid" or best.State == "Grab" or best.State == "Chase" then
			goHome(bestPlot, best)
		end
	end
	return true
end

-- Fuer Tests: Liste aller Bots
function RivalService:GetBots()
	local list = {}
	for plot, rival in rivals do
		if rival.Bot then
			table.insert(list, { Plot = plot, Bot = rival.Bot, Name = rival.Name })
		end
	end
	return list
end

return RivalService
