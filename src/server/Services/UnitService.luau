-- Kern-Gameplay: Laufband, Kaufen, Einkommen, Klauen, Schlagen, Fusion, Rache und Rebirth.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Units = require(ReplicatedStorage.Shared.Units)
local UnitFactory = require(script.Parent.UnitFactory)

local UnitService = { Services = nil :: any }

local RED = Color3.fromRGB(255, 80, 80)
local GREEN = Color3.fromRGB(90, 220, 120)
local GOLD = Color3.fromRGB(255, 200, 40)

local conveyorUnits = {} -- [Model] = { Code, X, Sold }
local baseUnits = {} -- [Player] = { [slotKey] = Model }
local carrying = {} -- [Player] = { Owner, SlotKey, Code, Visual, Model, StartedAt }
local revenge = {} -- [Opfer] = { Thief = Player, Until = os.clock() }
local holdStarted = {} -- [Player] = os.clock()
local lastSlap = {} -- [Player] = os.clock()

local unitsByRarity = {}
for _, def in Config.Units do
	unitsByRarity[def.Rarity] = unitsByRarity[def.Rarity] or {}
	table.insert(unitsByRarity[def.Rarity], def)
end

local beltFolder: Folder

function UnitService:Init(services)
	self.Services = services
end

local function offerSlots(player: Player)
	if not UnitService.Services.MonetizationService:HasPass(player, "ExtraSlots") then
		UnitService.Services.Net.SendOffer(player, "Pass", "ExtraSlots", "Your base is full!")
	end
	UnitService.Services.Net.SendNotify(player, "Tip: hold R on a critter in your base to sell it.", Color3.fromRGB(200, 200, 255))
end

local function notify(player: Player, text: string, color: Color3?)
	UnitService.Services.Net.SendNotify(player, text, color)
end

---------------------------------------------------------------- Slots

function UnitService:GetMaxSlots(player: Player): number
	local extra = if self.Services.MonetizationService:HasPass(player, "ExtraSlots") then Config.ExtraSlotsAmount else 0
	return Config.BaseSlots + extra
end

function UnitService:FindFreeSlot(player: Player): string?
	local data = self.Services.DataService:Get(player)
	if not data then
		return nil
	end
	for index = 1, self:GetMaxSlots(player) do
		local key = tostring(index)
		if data.Units[key] == nil then
			return key
		end
	end
	return nil
end

local function slotCFrame(plot, slotKey: string, info): CFrame
	local scale = info.Scale
	local offset = UnitService.Services.WorldService.PadOffset(tonumber(slotKey) :: number)
	return plot.CFrame * CFrame.new(offset + Vector3.new(0, scale * 0.6 + 0.3, 0))
end

---------------------------------------------------------------- Einkommen

function UnitService:GetBaseIncome(player: Player): number
	local data = self.Services.DataService:Get(player)
	if not data then
		return 0
	end
	local total = 0
	local featured = self.Services.RewardService and self.Services.RewardService:GetFeaturedId()
	for _, code in data.Units do
		local info = Units.Info(code)
		if info then
			-- Kreatur des Tages verdient doppelt
			total += info.Income * (if info.Id == featured then Config.FeaturedMultiplier else 1)
		end
	end
	return total
end

function UnitService:UpdateIncome(player: Player): number
	local income = self:GetBaseIncome(player) * self.Services.MonetizationService:GetMultiplier(player)
	player:SetAttribute("IncomePerSec", income)
	player:SetAttribute("Multiplier", self.Services.MonetizationService:GetMultiplier(player))
	return income
end

---------------------------------------------------------------- Basis-Anzeige

local endSteal: (thief: Player, success: boolean) -> () -- unten definiert

local function startSteal(thief: Player, owner: Player, slotKey: string, prompt: ProximityPrompt)
	local services = UnitService.Services
	if thief == owner then
		return
	end
	if carrying[thief] then
		notify(thief, "You are already carrying a critter!", RED)
		return
	end
	local model = baseUnits[owner] and baseUnits[owner][slotKey]
	if not model or model:GetAttribute("BeingStolen") then
		return
	end
	-- Rache: wer gerade bestohlen wurde, kommt kurz durch die Sperre des Diebes und klaut fast sofort
	local avenging = UnitService:HasRevenge(thief, owner)
	if services.PlotService:IsLocked(owner) and not avenging then
		notify(thief, "This base is locked!", RED)
		return
	end
	-- Neulingsschutz: neue Spieler koennen in den ersten Minuten nicht bestohlen werden
	if services.RewardService:HasShield(owner) and not avenging then
		notify(thief, `{owner.DisplayName} is new and has a newbie shield! 🛡️`, RED)
		return
	end
	-- Serverseitige Pruefung der Haltezeit (Schutz gegen Exploits)
	local required = if avenging then Config.RevengeHoldTime
		elseif services.MonetizationService:HasPass(thief, "FastSteal") then Config.FastStealHoldTime
		else Config.StealHoldTime
	local began = holdStarted[thief]
	holdStarted[thief] = nil
	if not began or os.clock() - began < required - 0.35 then
		return
	end
	local character = thief.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid or humanoid.Health <= 0 then
		return
	end
	if not UnitService:FindFreeSlot(thief) then
		notify(thief, "Your base is full!", RED)
		offerSlots(thief)
		return
	end
	local ownerData = services.DataService:Get(owner)
	local code = ownerData and ownerData.Units[slotKey]
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

	-- Dieb leuchtet rot, damit alle ihn sehen und schlagen koennen
	local highlight = Instance.new("Highlight")
	highlight.Name = "ThiefHighlight"
	highlight.FillColor = Color3.fromRGB(255, 50, 50)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.fromRGB(255, 220, 60)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	carrying[thief] = { Owner = owner, SlotKey = slotKey, Code = code, Visual = visual, Model = model, Prompt = prompt, StartedAt = os.clock(), Highlight = highlight }
	thief:SetAttribute("Carrying", def.Name)
	notify(owner, `{thief.DisplayName} is stealing your {def.Name}! Slap them!`, RED)
	notify(thief, `You grabbed {def.Name}! Run back to your base!`, GOLD)
end

function UnitService:PlaceBaseUnit(player: Player, slotKey: string)
	local services = self.Services
	local data = services.DataService:Get(player)
	local plot = services.PlotService:GetPlot(player)
	local def = data and Units.Info(data.Units[slotKey])
	if not def or not plot then
		return
	end
	local model = UnitFactory.Build(def)
	model:PivotTo(slotCFrame(plot, slotKey, def))
	UnitFactory.AddLabel(model, def, "+" .. Format.Cash(def.Income) .. "/s")
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("SlotKey", slotKey)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = def.Name
	prompt.HoldDuration = Config.StealHoldTime
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", player.UserId)
	prompt.Parent = model.PrimaryPart
	prompt.PromptButtonHoldBegan:Connect(function(thief)
		holdStarted[thief] = os.clock()
	end)
	prompt.Triggered:Connect(function(thief)
		startSteal(thief, player, slotKey, prompt)
	end)

	-- Fusion: nur der Besitzer sieht diesen Prompt (der Client blendet ihn fuer andere aus)
	if def.Fusion < Config.MaxFusion then
		local fusePrompt = Instance.new("ProximityPrompt")
		fusePrompt.Name = "FusePrompt"
		fusePrompt.ActionText = "Fuse 3x"
		fusePrompt.ObjectText = def.Name
		fusePrompt.KeyboardKeyCode = Enum.KeyCode.F
		fusePrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		fusePrompt.HoldDuration = 0.5
		fusePrompt.MaxActivationDistance = 8
		fusePrompt.RequiresLineOfSight = false
		fusePrompt:SetAttribute("OwnerUserId", player.UserId)
		fusePrompt.Parent = model.PrimaryPart
		fusePrompt.Triggered:Connect(function(who)
			if who == player then
				UnitService:Fuse(player, slotKey)
			end
		end)
	end

	-- Verkaufen: nur der Besitzer sieht diesen Prompt
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell " .. Format.Cash(math.floor(def.Value * Config.SellShare))
	sellPrompt.ObjectText = def.Name
	sellPrompt.KeyboardKeyCode = Enum.KeyCode.R
	sellPrompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	sellPrompt.HoldDuration = 1.2
	sellPrompt.MaxActivationDistance = 8
	sellPrompt.RequiresLineOfSight = false
	sellPrompt.UIOffset = Vector2.new(0, 75)
	sellPrompt:SetAttribute("OwnerUserId", player.UserId)
	sellPrompt.Parent = model.PrimaryPart
	sellPrompt.Triggered:Connect(function(who)
		if who == player then
			UnitService:Sell(player, slotKey)
		end
	end)

	model.Parent = plot.Model
	baseUnits[player][slotKey] = model
end

function UnitService:RemoveBaseUnit(player: Player, slotKey: string)
	local data = self.Services.DataService:Get(player)
	if data then
		data.Units[slotKey] = nil
	end
	local models = baseUnits[player]
	if models and models[slotKey] then
		models[slotKey]:Destroy()
		models[slotKey] = nil
	end
	self:UpdateIncome(player)
end

-- Gibt dem Spieler eine Kreatur. sourceModel (optional) fliegt vom Laufband zur Basis.
function UnitService:GiveUnit(player: Player, code: string, slotKey: string?, sourceModel: Model?): boolean
	local data = self.Services.DataService:Get(player)
	local def = Units.Info(code)
	local plot = self.Services.PlotService:GetPlot(player)
	slotKey = slotKey or self:FindFreeSlot(player)
	if not data or not def or not plot or not slotKey then
		if sourceModel then
			sourceModel:Destroy()
		end
		return false
	end
	local key = slotKey :: string
	code = def.Code
	data.Units[key] = code
	self:UpdateIncome(player)
	self.Services.ProgressService:Discover(player, def.Id)

	if sourceModel and sourceModel.PrimaryPart then
		for _, child in sourceModel.PrimaryPart:GetChildren() do
			if child:IsA("ProximityPrompt") or child.Name == "Info" then
				child:Destroy()
			end
		end
		local tween = TweenService:Create(sourceModel.PrimaryPart, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = slotCFrame(plot, key, def) })
		tween:Play()
		tween.Completed:Wait()
		sourceModel:Destroy()
	end
	-- Spieler koennte waehrend des Flugs gegangen sein oder rebirthed haben
	if player.Parent and baseUnits[player] and data.Units[key] == code and not baseUnits[player][key] then
		self:PlaceBaseUnit(player, key)
	end
	return true
end

---------------------------------------------------------------- Klauen beenden

endSteal = function(thief: Player, success: boolean)
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

	local services = UnitService.Services
	local owner: Player = info.Owner
	local ownerModels = baseUnits[owner]
	local def = Units.Info(info.Code)
	if success and owner.Parent and ownerModels and ownerModels[info.SlotKey] == info.Model then
		local ownerData = services.DataService:Get(owner)
		local slot = UnitService:FindFreeSlot(thief)
		if ownerData and ownerData.Units[info.SlotKey] == info.Code and slot then
			UnitService:RemoveBaseUnit(owner, info.SlotKey)
			task.spawn(UnitService.GiveUnit, UnitService, thief, info.Code, slot)
			-- Versicherung und Rache: der Verlust tut weniger weh, und man kann zurueckschlagen
			local payout = math.floor(def.Value * Config.InsuranceShare)
			services.DataService:AddCash(owner, payout)
			revenge[owner] = { Thief = thief, Until = os.clock() + Config.RevengeDuration }
			owner:SetAttribute("RevengeTarget", thief.DisplayName)
			owner:SetAttribute("RevengeTargetId", thief.UserId)
			owner:SetAttribute("RevengeUntil", workspace:GetServerTimeNow() + Config.RevengeDuration)
			notify(thief, `You stole {def.Name}!`, GREEN)
			services.ProgressService:Track(thief, "Stolen", 1)
			services.EventService:AddGoalProgress(1)
			services.RewardService:BountyBonus(thief, owner, def.Value)
			notify(owner, `{thief.DisplayName} stole your {def.Name}! Insurance paid {Format.Cash(payout)}. REVENGE: steal back instantly for {Config.RevengeDuration}s!`, RED)
			services.Net.SendOffer(owner, "Product", "LockBase", "Protect your base from thieves!")
			if Config.RaritiesByName[def.Rarity].Announce then
				services.Net.SendAnnounce(`{thief.DisplayName} stole a {def.Rarity} {def.Name} from {owner.DisplayName}!`, Config.RaritiesByName[def.Rarity].Color)
			end
			return
		end
	end

	-- Fehlgeschlagen: Kreatur bleibt beim Besitzer
	if info.Model and info.Model.Parent then
		info.Model:SetAttribute("BeingStolen", false)
		UnitFactory.SetTransparency(info.Model, 0)
		info.Prompt.Enabled = true
	end
end

---------------------------------------------------------------- Laufband

local function pickUnitDef()
	local luck = UnitService.Services.MonetizationService:GetLuck()
	local total = 0
	local weights = {}
	for index, rarity in Config.Rarities do
		local weight = rarity.Weight * (if rarity.Lucky then luck else 1)
		weights[index] = weight
		total += weight
	end
	local roll = math.random() * total
	for index, rarity in Config.Rarities do
		roll -= weights[index]
		if roll <= 0 then
			local list = unitsByRarity[rarity.Name]
			return list[math.random(1, #list)]
		end
	end
	return Config.Units[1]
end

local function rollMutation(): string?
	local golden = UnitService.Services.EventService:IsActive("GoldenHour")
	local luck = UnitService.Services.MonetizationService:GetLuck()
	-- Seltenste zuerst pruefen
	for index = #Config.Mutations, 1, -1 do
		local mutation = Config.Mutations[index]
		local chance = mutation.Chance * luck
		if golden and mutation.Name == "Golden" then
			chance = 0.4
		end
		if math.random() < chance then
			return mutation.Name
		end
	end
	return nil
end

local function tryBuy(player: Player, model: Model)
	local services = UnitService.Services
	local entry = conveyorUnits[model]
	if not entry or entry.Sold then
		return
	end
	local def = Units.Info(entry.Code)
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	if data.Cash < def.Price then
		notify(player, `Not enough cash! You need {Format.Cash(def.Price - data.Cash)} more.`, RED)
		return
	end
	local slot = UnitService:FindFreeSlot(player)
	if not slot then
		notify(player, "Your base is full! Get +4 slots in the shop or rebirth.", RED)
		offerSlots(player)
		return
	end
	entry.Sold = true
	conveyorUnits[model] = nil
	services.DataService:AddCash(player, -def.Price)
	notify(player, `Bought {def.Name}!`, GREEN)
	services.ProgressService:Track(player, "Bought", 1)
	services.EventService:AddGoalProgress(1)
	UnitService:GiveUnit(player, def.Code, slot, model)
end

-- Fuer Robux-Sofortkauf: nimmt die Kreatur vom Band, falls sie noch da ist.
function UnitService:TakeFromBelt(model: Model?, code: string): Model?
	local entry = model and conveyorUnits[model]
	if entry and not entry.Sold and entry.Code == code then
		entry.Sold = true
		conveyorUnits[model :: Model] = nil
		return model
	end
	return nil
end

local function spawnBeltUnit(forcedRarity: string?)
	local services = UnitService.Services
	local picked = pickUnitDef()
	if forcedRarity and unitsByRarity[forcedRarity] then
		local list = unitsByRarity[forcedRarity]
		picked = list[math.random(1, #list)]
	end
	local def = Units.Info(Units.Encode(picked.Id, rollMutation(), 0))
	local rarity = Config.RaritiesByName[def.Rarity]
	local model = UnitFactory.Build(def)
	local conveyor = Config.Conveyor
	local entry = { Code = def.Code, X = conveyor.StartX, Y = 1 + def.Scale * 0.6 + 0.2, Sold = false }
	model:PivotTo(CFrame.lookAt(Vector3.new(entry.X, entry.Y, conveyor.Z), Vector3.new(entry.X + 1, entry.Y, conveyor.Z)))
	UnitFactory.AddLabel(model, def, Format.Cash(def.Price) .. "  (+" .. Format.Cash(def.Income) .. "/s)")

	local buyPrompt = Instance.new("ProximityPrompt")
	buyPrompt.Name = "BuyPrompt"
	buyPrompt.ActionText = "Buy " .. Format.Cash(def.Price)
	buyPrompt.ObjectText = def.Name
	buyPrompt.HoldDuration = 0
	buyPrompt.MaxActivationDistance = 12
	buyPrompt.RequiresLineOfSight = false
	buyPrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	buyPrompt.Parent = model.PrimaryPart
	buyPrompt.Triggered:Connect(function(player)
		tryBuy(player, model)
	end)

	if rarity.Index >= Config.RaritiesByName.Epic.Index and Config.DevProducts["Instant" .. def.Rarity] then
		local robuxPrompt = Instance.new("ProximityPrompt")
		robuxPrompt.Name = "RobuxPrompt"
		robuxPrompt.ActionText = "Buy with Robux"
		robuxPrompt.ObjectText = def.Rarity
		robuxPrompt.KeyboardKeyCode = Enum.KeyCode.F
		robuxPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		robuxPrompt.HoldDuration = 0
		robuxPrompt.MaxActivationDistance = 12
		robuxPrompt.RequiresLineOfSight = false
		robuxPrompt.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		robuxPrompt.UIOffset = Vector2.new(0, 75)
		robuxPrompt.Parent = model.PrimaryPart
		robuxPrompt.Triggered:Connect(function(player)
			if conveyorUnits[model] and not conveyorUnits[model].Sold then
				services.MonetizationService:PromptInstantBuy(player, model, def)
			end
		end)
	end

	model.Parent = beltFolder
	conveyorUnits[model] = entry
	if rarity.Announce or (def.Mutation and def.Mutation.Multiplier >= 4) then
		services.Net.SendAnnounce(`A {def.Rarity} {def.Name} is on the belt!`, if def.Mutation then def.Mutation.Color else rarity.Color)
	end
end

-- Fuer Events: z.B. garantierte Mythic-Kreatur auf dem Laufband
function UnitService:SpawnBeltUnit(rarityName: string?)
	spawnBeltUnit(rarityName)
end

---------------------------------------------------------------- Verkaufen

-- Kreatur aus der eigenen Basis verkaufen (halber Wert), z.B. wenn die Basis voll ist
function UnitService:Sell(player: Player, slotKey: string)
	local data = self.Services.DataService:Get(player)
	local info = data and Units.Info(data.Units[slotKey])
	local model = baseUnits[player] and baseUnits[player][slotKey]
	if not info or not model or model:GetAttribute("BeingStolen") then
		return
	end
	local amount = math.floor(info.Value * Config.SellShare)
	self:RemoveBaseUnit(player, slotKey)
	self.Services.DataService:AddCash(player, amount)
	self.Services.ProgressService:Track(player, "Sold", 1)
	notify(player, `Sold {info.Name} for {Format.Cash(amount)}`, GREEN)
end

---------------------------------------------------------------- Fusion und Rache

-- 3 identische Kreaturen (gleiche Art, Mutation und Stufe) werden zu einer mit einem Stern mehr
function UnitService:Fuse(player: Player, slotKey: string)
	local data = self.Services.DataService:Get(player)
	local code = data and data.Units[slotKey]
	local info = Units.Info(code)
	if not info or info.Fusion >= Config.MaxFusion then
		return
	end
	local models = baseUnits[player] or {}
	local partners = {}
	for key, other in data.Units do
		if key ~= slotKey and other == code and models[key] and not models[key]:GetAttribute("BeingStolen") then
			table.insert(partners, key)
			if #partners == 2 then
				break
			end
		end
	end
	local useCatalyst = #partners == 1 and (data.Catalysts or 0) > 0
	if (#partners < 2 and not useCatalyst) or (models[slotKey] and models[slotKey]:GetAttribute("BeingStolen")) then
		notify(player, `You need 3x {info.Name} to fuse!` .. (if #partners == 1 then " (or 2x with a Fusion Catalyst from the shop)" else ""), RED)
		if #partners == 1 then
			self.Services.Net.SendOffer(player, "Product", "FusionCatalyst", `Fuse your 2x {info.Name} right now!`)
		end
		return
	end
	if useCatalyst then
		data.Catalysts -= 1
		player:SetAttribute("Catalysts", data.Catalysts)
	end
	for _, key in partners do
		self:RemoveBaseUnit(player, key)
	end
	self:RemoveBaseUnit(player, slotKey)
	local fused = Units.Encode(info.Id, info.Mutation and info.Mutation.Name, info.Fusion + 1)
	self:GiveUnit(player, fused, slotKey)
	local result = Units.Info(fused)
	notify(player, `FUSION! You created {result.Name} (+{Format.Cash(result.Income)}/s)`, GOLD)
	self.Services.ProgressService:Track(player, "Fused", 1)
	if result.Fusion >= 2 then
		self.Services.Net.SendAnnounce(`{player.DisplayName} fused a {result.Name}!`, Color3.fromRGB(180, 80, 255))
	end
end

-- Verwandelt die wertvollste Kreatur der Basis, die noch eine schwaechere Mutation hat.
-- Gibt den neuen Namen zurueck oder nil, wenn es keine passende Kreatur gibt.
function UnitService:MutateBest(player: Player, mutationName: string): string?
	local data = self.Services.DataService:Get(player)
	local target = Units.MutationsByName[mutationName]
	if not data or not target then
		return nil
	end
	local models = baseUnits[player] or {}
	local bestKey, bestInfo = nil, nil
	for key, code in data.Units do
		local info = Units.Info(code)
		local current = if info and info.Mutation then info.Mutation.Multiplier else 1
		local model = models[key]
		if info and current < target.Multiplier and model and not model:GetAttribute("BeingStolen") then
			if not bestInfo or info.Income > bestInfo.Income then
				bestKey, bestInfo = key, info
			end
		end
	end
	if not bestKey or not bestInfo then
		return nil
	end
	local code = Units.Encode(bestInfo.Id, target.Name, bestInfo.Fusion)
	self:RemoveBaseUnit(player, bestKey)
	self:GiveUnit(player, code, bestKey)
	return Units.Info(code).Name
end

function UnitService:HasRevenge(player: Player, target: Player): boolean
	local entry = revenge[player]
	return entry ~= nil and entry.Thief == target and os.clock() < entry.Until
end

---------------------------------------------------------------- Schlagen

local function slap(player: Player)
	local now = os.clock()
	if now - (lastSlap[player] or 0) < Config.SlapCooldown then
		return
	end
	lastSlap[player] = now
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local best, bestDistance = nil, Config.SlapRange
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if otherRoot then
			local offset = otherRoot.Position - root.Position
			local distance = offset.Magnitude
			if distance < bestDistance and (distance < 3 or offset.Unit:Dot(root.CFrame.LookVector) > 0.2) then
				best, bestDistance = other, distance
			end
		end
	end
	if not best then
		return
	end
	UnitService.Services.ProgressService:Track(player, "Slaps", 1)
	local humanoid = best.Character and best.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		task.delay(Config.SlapStunTime, function()
			if humanoid.Parent then
				humanoid.WalkSpeed = best:GetAttribute("BaseWalkSpeed") or Config.DefaultWalkSpeed
			end
		end)
	end
	if carrying[best] then
		endSteal(best, false)
		notify(player, `You slapped {best.DisplayName} and saved the critter!`, GREEN)
		notify(best, `{player.DisplayName} slapped you! You dropped the critter.`, RED)
	end
end

function UnitService:GiveSlapTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild("Slap") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Slap"
	tool.CanBeDropped = false
	tool.ToolTip = "Slap thieves to get your critters back"
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 0.6, 4)
	handle.Color = Color3.fromRGB(150, 100, 60)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Parent = tool
	tool.GripPos = Vector3.new(0, 0, 1.5)
	tool.Activated:Connect(function()
		slap(player)
	end)
	tool.Parent = backpack
end

---------------------------------------------------------------- Rebirth

local function rebirth(player: Player)
	local services = UnitService.Services
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Cash < cost then
		notify(player, `You need {Format.Cash(cost)} to rebirth.`, RED)
		return
	end
	endSteal(player, false)
	for thief, info in carrying do
		if info.Owner == player then
			endSteal(thief, false)
		end
	end
	for slotKey in data.Units do
		local model = baseUnits[player][slotKey]
		if model then
			model:Destroy()
		end
	end
	baseUnits[player] = {}
	data.Units = {}
	data.Cash = Config.StartCash
	data.Rebirths += 1
	services.DataService:UpdateAttributes(player)
	UnitService:UpdateIncome(player)
	notify(player, `Rebirth {data.Rebirths}! Your income is now x{UnitService.Services.MonetizationService:GetMultiplier(player)}.`, GOLD)
	services.Net.SendAnnounce(`{player.DisplayName} reached Rebirth {data.Rebirths}!`, GOLD)
	services.ProgressService:CheckAchievements(player)
	task.spawn(services.DataService.Save, services.DataService, player)
end

---------------------------------------------------------------- Lebenszyklus

function UnitService:OnPlayerReady(player: Player)
	baseUnits[player] = {}
	local data = self.Services.DataService:Get(player)
	player:SetAttribute("StarterPack", data.StarterPack == true)
	player:SetAttribute("Catalysts", data.Catalysts or 0)
	for slotKey in data.Units do
		self:PlaceBaseUnit(player, slotKey)
	end
	self:UpdateIncome(player)
end

function UnitService:OnPlayerRemoving(player: Player)
	endSteal(player, false)
	for thief, info in carrying do
		if info.Owner == player then
			endSteal(thief, false)
		end
	end
	if baseUnits[player] then
		for _, model in baseUnits[player] do
			model:Destroy()
		end
	end
	baseUnits[player] = nil
	holdStarted[player] = nil
	lastSlap[player] = nil
	revenge[player] = nil
end

function UnitService:Start()
	local services = self.Services
	beltFolder = Instance.new("Folder")
	beltFolder.Name = "BeltUnits"
	beltFolder.Parent = workspace

	services.Net.RequestRebirth.OnServerEvent:Connect(rebirth)

	-- Laufband bewegen
	RunService.Heartbeat:Connect(function(dt)
		local conveyor = Config.Conveyor
		for model, entry in conveyorUnits do
			entry.X += conveyor.Speed * dt
			if entry.X > conveyor.EndX then
				conveyorUnits[model] = nil
				model:Destroy()
			else
				model:PivotTo(CFrame.lookAt(Vector3.new(entry.X, entry.Y, conveyor.Z), Vector3.new(entry.X + 1, entry.Y, conveyor.Z)))
			end
		end
	end)

	task.spawn(function()
		while true do
			spawnBeltUnit()
			local rush = services.EventService:IsActive("CritterRush")
			task.wait(Config.Conveyor.SpawnInterval / (if rush then 3 else 1))
		end
	end)

	-- Einkommen auszahlen
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTick)
			for player in baseUnits do
				local income = self:UpdateIncome(player)
				if income > 0 then
					services.DataService:AddCash(player, income * Config.IncomeTick)
				end
			end
		end
	end)

	-- Diebe pruefen: zu Hause angekommen, gestorben oder Zeit abgelaufen?
	task.spawn(function()
		while true do
			task.wait(0.2)
			for thief, info in carrying do
				local character = thief.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local plot = services.PlotService:GetPlot(thief)
				if not thief.Parent or not root or not humanoid or humanoid.Health <= 0 then
					endSteal(thief, false)
				elseif os.clock() - info.StartedAt > Config.StealTimeout then
					notify(thief, "Too slow! The critter ran home.", RED)
					endSteal(thief, false)
				elseif plot and services.WorldService.IsInside(plot, root.Position) then
					endSteal(thief, true)
				end
			end
		end
	end)
end

return UnitService
