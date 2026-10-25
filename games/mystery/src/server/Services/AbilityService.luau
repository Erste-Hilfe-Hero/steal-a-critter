-- Rollen-Faehigkeiten (Dash, Shadow, Glue Trap, Scanner), Fussspuren des Murderers
-- und Power-Up-Kisten auf der Karte.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AbilityService = { Services = nil :: any }

local C = Config.Colors
local A = Config.Abilities

local cooldowns = {} -- [actor] = { [ability] = t }
local trail = {} -- [actor] = { Vector3 } (letzte Positionen des Murderers)
local traps = {} -- [actor] = Part
local running = false
local powerFolder: Folder
local spots = {}

local function now(): number
	return os.clock()
end

function AbilityService:Remaining(actor, name: string): number
	local t = cooldowns[actor] and cooldowns[actor][name]
	if not t then
		return 0
	end
	return math.max(0, A[name].Cooldown - (now() - t))
end

---------------------------------------------------------------- Geschwindigkeit (Basis + Effekte)

local speedEffects = {} -- [actor] = { [name] = { Delta, Until } }

local function refreshSpeed(actor)
	local base = Config.WalkSpeed + AbilityService.Services.RoundService:SpeedBonus()
	local slow = false
	for _, effect in speedEffects[actor] or {} do
		if effect.Until > now() then
			if effect.Set then
				slow = true
				base = math.min(base, effect.Set)
			else
				base += effect.Delta
			end
		end
	end
	if not actor.Alive then
		return
	end
	actor.Model:SetAttribute("BaseSpeed", base)
	actor.Humanoid.WalkSpeed = base
	actor.Model:SetAttribute("Slowed", slow)
end

function AbilityService:SpeedEffect(actor, name: string, duration: number, delta: number?, set: number?)
	speedEffects[actor] = speedEffects[actor] or {}
	speedEffects[actor][name] = { Delta = delta or 0, Set = set, Until = now() + duration }
	refreshSpeed(actor)
	task.delay(duration + 0.05, function()
		if speedEffects[actor] then
			refreshSpeed(actor)
		end
	end)
end

---------------------------------------------------------------- Faehigkeiten

-- Unsichtbarkeit (Shadow und Ghost-Power-Up). Ueberlappen sich zwei, wird nur verlaengert:
-- sonst wuerde der zweite die schon halb-durchsichtigen Werte speichern und der Spieler bliebe unsichtbar.
local cloaks = {} -- [Model] = { Saved = { [Instance] = number }, Until = number }
local function cloak(actor, duration: number)
	local model = actor.Model
	local state = cloaks[model]
	local untilTime = now() + duration
	if state then
		state.Until = math.max(state.Until, untilTime)
	else
		state = { Saved = {}, Until = untilTime }
		cloaks[model] = state
		for _, d in model:GetDescendants() do
			if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
				state.Saved[d] = d.Transparency
				d.Transparency = math.max(d.Transparency, 0.93)
			end
		end
		model:SetAttribute("Cloaked", true)
	end
	task.delay(duration, function()
		if cloaks[model] ~= state or now() < state.Until - 0.05 then
			return
		end
		cloaks[model] = nil
		for d, value in state.Saved do
			if d.Parent then
				d.Transparency = value
			end
		end
		model:SetAttribute("Cloaked", false)
	end)
end

local function placeTrap(actor)
	if traps[actor] then
		traps[actor]:Destroy()
	end
	local trap = Instance.new("Part")
	trap.Name = "GlueTrap"
	trap.Shape = Enum.PartType.Cylinder
	trap.Size = Vector3.new(0.2, 5, 5)
	trap.CFrame = CFrame.new(actor.Root.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	trap.Color = Color3.fromRGB(255, 110, 200)
	trap.Material = Enum.Material.Glass
	trap.Transparency = 0.55
	trap.Anchored = true
	trap.CanCollide = false
	trap.CanQuery = false
	trap.Parent = AbilityService.Services.CombatService.FxFolder
	traps[actor] = trap
	local armedAt = now() + 0.8
	trap.Touched:Connect(function(hit)
		if now() < armedAt or not trap.Parent then
			return
		end
		local victim = AbilityService.Services.RoundService:ActorFromPart(hit)
		if victim and victim.Alive and victim.Role ~= "Murderer" then
			trap:Destroy()
			traps[actor] = nil
			AbilityService:SpeedEffect(victim, "Glue", A.Trap.Duration, nil, 4)
			AbilityService.Services.Net.Fx:FireAllClients("Glue", { Position = victim.Root.Position })
			if victim.Player then
				AbilityService.Services.Net.SendNotify(victim.Player, "You stepped in GLUE! Slowed!", C.Pink)
			end
		end
	end)
end

function AbilityService:Use(actor, name: string, extra: any): (boolean, number?)
	local round = self.Services.RoundService
	local def = A[name]
	if not def or not round:IsPlaying() or not actor.Alive or actor.Hidden then
		return false, nil
	end
	local role = if actor.Role == "Hero" then "Sheriff" else actor.Role
	if def.Role ~= role or name == "Sprint" then
		return false, nil
	end
	local left = self:Remaining(actor, name)
	if left > 0 then
		return false, left
	end
	cooldowns[actor] = cooldowns[actor] or {}
	cooldowns[actor][name] = now()
	if name == "Dash" then
		-- Bei Spielern macht der Client den Sprung (Netzwerk-Besitzer), bei Bots der Server
		if actor.Bot then
			actor.Root.AssemblyLinearVelocity = actor.Root.CFrame.LookVector * 70 + Vector3.new(0, 12, 0)
		end
		self.Services.Net.Fx:FireAllClients("Dash", { Model = actor.Model })
	elseif name == "Cloak" then
		cloak(actor, def.Duration)
		self.Services.Net.Fx:FireAllClients("Cloak", { Position = actor.Root.Position })
	elseif name == "Trap" then
		placeTrap(actor)
	elseif name == "Scan" then
		if actor.Player then
			local prints = {}
			for murderer, points in trail do
				if murderer.Alive then
					for _, p in points do
						table.insert(prints, p)
					end
				end
			end
			self.Services.Net.Footprints:FireClient(actor.Player, prints, def.Duration)
		end
		self.Services.Net.Fx:FireAllClients("Scan", { Position = actor.Root.Position })
	end
	if actor.Player then
		self.Services.ProgressService:Track(actor.Player, "Ability", 1)
	end
	return true, def.Cooldown
end

---------------------------------------------------------------- Power-Ups

local function applyPowerUp(actor, def)
	local services = AbilityService.Services
	local id = def.Id
	if id == "Shield" and actor.Role == "Murderer" then
		id = "Speed" -- der Murderer bekommt statt Schild Tempo
	end
	if id == "Speed" then
		AbilityService:SpeedEffect(actor, "Soda", def.Duration, 7, nil)
	elseif id == "Shield" then
		actor.Shield = true
		actor.Model:SetAttribute("Shield", true)
		task.delay(def.Duration, function()
			if actor.Shield then
				actor.Shield = false
				actor.Model:SetAttribute("Shield", false)
			end
		end)
	elseif id == "Magnet" then
		task.spawn(function()
			local stop = now() + def.Duration
			while now() < stop and actor.Alive and running do
				services.CoinService:Magnet(actor, 22)
				task.wait(0.25)
			end
		end)
	elseif id == "Ghost" then
		cloak(actor, def.Duration)
	end
	if actor.Player then
		services.Net.SendNotify(actor.Player, `{def.Name}!`, def.Color)
		services.ProgressService:Track(actor.Player, "PowerUp", 1)
	end
	services.Net.Fx:FireAllClients("PowerUp", { Position = actor.Root.Position, Color = def.Color })
end

local function luckyBoxes(): boolean
	local mod = AbilityService.Services.RoundService.Modifier
	return mod ~= nil and mod.Id == "LuckyBoxes"
end

local function spawnPowerUp()
	if #spots == 0 or #powerFolder:GetChildren() >= Config.PowerUps.Max * (if luckyBoxes() then 2 else 1) then
		return
	end
	local spot = spots[math.random(1, #spots)]
	for _, other in powerFolder:GetChildren() do
		if (other:GetPivot().Position - spot).Magnitude < 10 then
			return
		end
	end
	local box = Instance.new("Part")
	box.Name = "PowerUp"
	box.Size = Vector3.new(2.4, 2.4, 2.4)
	box.CFrame = CFrame.new(spot + Vector3.new(0, 2.2, 0))
	box.Color = Config.Colors.Purple
	box.Material = Enum.Material.Neon
	box.Transparency = 0.15
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box:AddTag("PowerUp")
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "?"
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = gui
	local light = Instance.new("PointLight")
	light.Color = Config.Colors.Purple
	light.Range = 12
	light.Parent = box
	box.Touched:Connect(function(hit)
		local actor = AbilityService.Services.RoundService:ActorFromPart(hit)
		if actor and actor.Alive and box.Parent then
			box:Destroy()
			local list = Config.PowerUps.List
			applyPowerUp(actor, list[math.random(1, #list)])
		end
	end)
	box.Parent = powerFolder
end

function AbilityService:SpawnPowerUp()
	spawnPowerUp()
end

---------------------------------------------------------------- Runde

function AbilityService:StartRound(map)
	running = true
	spots = map.PowerSpots
	table.clear(cooldowns)
	table.clear(trail)
	table.clear(speedEffects)
	powerFolder:ClearAllChildren()
	task.spawn(function()
		task.wait(6)
		spawnPowerUp()
		while running do
			task.wait(Config.PowerUps.SpawnEvery / (if luckyBoxes() then 3 else 1))
			if running then
				spawnPowerUp()
			end
		end
	end)
	-- Fussspuren des Murderers sammeln (fuer den Scanner)
	task.spawn(function()
		while running do
			for _, actor in self.Services.RoundService.Actors do
				if actor.Role == "Murderer" and actor.Alive then
					trail[actor] = trail[actor] or {}
					local points = trail[actor]
					local last = points[#points]
					local p = actor.Root.Position - Vector3.new(0, 2.9, 0)
					if not last or (last - p).Magnitude > 2.5 then
						table.insert(points, p)
						if #points > 40 then
							table.remove(points, 1)
						end
					end
				end
			end
			task.wait(0.35)
		end
	end)
end

function AbilityService:StopRound()
	running = false
	powerFolder:ClearAllChildren()
	for _, trap in traps do
		trap:Destroy()
	end
	table.clear(traps)
	table.clear(trail)
	table.clear(speedEffects)
	table.clear(cooldowns)
end

function AbilityService:Init(services)
	self.Services = services
	powerFolder = Instance.new("Folder")
	powerFolder.Name = "PowerUps"
	powerFolder.Parent = workspace
	services.Net.Handle("Ability", function(player, name)
		if typeof(name) ~= "string" then
			return { Ok = false }
		end
		local actor = services.RoundService:ActorOfPlayer(player)
		if not actor then
			return { Ok = false }
		end
		local ok, cooldown = self:Use(actor, name)
		return { Ok = ok, Cooldown = cooldown }
	end)
end

return AbilityService
