-- Rivalen-Basen: Solange wenige echte Spieler da sind, werden freie Basen von NPC-Rivalen belegt.
-- So kann man auch allein auf einem Server klauen (Kern des Spiels und Tutorial-Schritt "Steal").
-- Die Kreaturen der Rivalen passen sich dem Einkommen der Spieler an und kommen nach einer Weile wieder.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Units = require(ReplicatedStorage.Shared.Units)
local UnitFactory = require(script.Parent.UnitFactory)

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

local function placeCritter(plot, slotKey: string)
	local rival = rivals[plot]
	if not rival or rival.Models[slotKey] then
		return
	end
	local code = pickCode()
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
			notify(thief, `You stole {def and def.Name or "a critter"} from {info.Name}! Steal from real players for bigger loot.`, GREEN)
			lastSteal[thief] = os.clock()
			if model then
				model:Destroy()
				rival.Models[info.SlotKey] = nil
			end
			-- Der Rivale kauft spaeter eine neue Kreatur
			task.delay(R.RespawnTime, function()
				if rivals[info.Plot] == rival then
					placeCritter(info.Plot, info.SlotKey)
				end
			end)
			return
		end
		notify(thief, "Your base is full, so the critter ran back home!", RED)
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
		notify(thief, "You are already carrying a critter!", RED)
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
		notify(thief, "Your base is full! Hold R on a critter to sell it.", RED)
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
end

-- Rivalen-Basis freigeben (z.B. weil ein echter Spieler die Basis bekommt)
function RivalService:Release(plot)
	local rival = rivals[plot]
	if not rival then
		return
	end
	rivals[plot] = nil
	for thief, info in carrying do
		if info.Plot == plot then
			notify(thief, `{info.Name} left the server, the critter ran away!`, RED)
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
					notify(thief, "Too slow! The critter ran home.", RED)
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
end

return RivalService
