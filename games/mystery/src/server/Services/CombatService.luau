-- Messer (Stich + Wurf), Blaster (ein Schuss, Abklingzeit), Cartoon-K.O. ohne Blut,
-- fallengelassener Blaster (Unschuldige heben ihn auf und werden zum Hero).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Skins = require(ReplicatedStorage.Shared.Skins)

local CombatService = { Services = nil :: any }

local C = Config.Colors
local K = Config.Knife
local G = Config.Gun

local fxFolder: Folder
local cooldowns = {} -- [actor] = { Stab = t, Throw = t, Shoot = t }
local droppedGun: Model? = nil

local function now(): number
	return os.clock()
end

local function ready(actor, kind: string, cooldown: number): boolean
	cooldowns[actor] = cooldowns[actor] or {}
	local t = cooldowns[actor][kind] or -math.huge
	if now() - t < cooldown then
		return false
	end
	cooldowns[actor][kind] = now()
	return true
end

local function equipped(actor, kind: string): string?
	-- Liefert die Skin-ID, wenn das Werkzeug gerade in der Hand ist (Bots haben es immer)
	if actor.Bot then
		return actor.Bot.Weapon
	end
	for _, child in actor.Model:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("Kind") == kind then
			return child:GetAttribute("Skin")
		end
	end
	return nil
end

local function skinOf(actor, kind: string): string
	if actor.Player then
		local data = CombatService.Services.DataService:Get(actor.Player)
		if data then
			local id = data.Equipped[kind]
			if id and Config.GetItem(kind, id) then
				return id
			end
		end
		return "Default"
	end
	local list = Config.ItemLists[kind]
	return list[math.random(1, math.min(#list, 9))].Id
end

local function effectOf(actor): string
	if actor and actor.Player then
		local data = CombatService.Services.DataService:Get(actor.Player)
		if data and Config.GetItem("Effect", data.Equipped.Effect) then
			return data.Equipped.Effect
		end
	end
	return "Poof"
end

---------------------------------------------------------------- Vorbereitung

function CombatService:PrepareActor(actor)
	cooldowns[actor] = {}
	actor.Shield = false
	local speed = Config.WalkSpeed + self.Services.RoundService:SpeedBonus()
	actor.Model:SetAttribute("BaseSpeed", speed)
	actor.Humanoid.WalkSpeed = speed
	actor.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- Taschenlampe (an bei Blackout, sonst schwach)
	local head = actor.Model:FindFirstChild("Head")
	if head and not head:FindFirstChild("Flashlight") then
		local attachment = Instance.new("Attachment")
		attachment.Name = "Flashlight"
		attachment.Position = Vector3.new(0, 0, -0.6)
		attachment.Parent = head
		local spot = Instance.new("SpotLight")
		spot.Angle = 55
		spot.Range = 42
		spot.Brightness = 2.4
		spot.Color = Color3.fromRGB(255, 240, 210)
		spot.Shadows = true
		spot.Face = Enum.NormalId.Front
		spot.Enabled = false
		spot.Parent = attachment
	end
	actor.Model:SetAttribute("Flashlight", true)
	local tag = actor.Model:FindFirstChild("Nameplate", true)
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = false
	end
end

-- Nach der Runde alles zuruecksetzen (Spieler laufen in der Lobby weiter)
function CombatService:ResetActor(actor)
	self:StripWeapons(actor)
	actor.Model:SetAttribute("BaseSpeed", Config.WalkSpeed)
	actor.Model:SetAttribute("Flashlight", false)
	actor.Model:SetAttribute("Shield", false)
	actor.Humanoid.WalkSpeed = Config.WalkSpeed
	local tag = actor.Model:FindFirstChild("Nameplate", true)
	if tag and tag:IsA("BillboardGui") then
		tag.Enabled = true
	end
	local head = actor.Model:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if light then
		light:Destroy()
	end
	cooldowns[actor] = nil
end

function CombatService:GiveWeapon(actor, kind: string)
	local skin = skinOf(actor, kind)
	if actor.Player then
		local tool = Skins.Tool(kind, skin)
		tool.Parent = actor.Player:FindFirstChildOfClass("Backpack")
		-- Gleich in die Hand nehmen
		task.defer(function()
			if tool.Parent and actor.Alive then
				actor.Humanoid:EquipTool(tool)
			end
		end)
	elseif actor.Bot then
		actor.Bot.Weapon = skin
		actor.Bot.WeaponKind = kind
		self.Services.BotService:ShowWeapon(actor.Bot, kind, skin)
	end
	actor.Model:SetAttribute("Armed", kind)
end

function CombatService:StripWeapons(actor)
	actor.Model:SetAttribute("Armed", nil)
	if actor.Player then
		local backpack = actor.Player:FindFirstChildOfClass("Backpack")
		for _, container in { actor.Model, backpack } do
			if container then
				for _, child in container:GetChildren() do
					if child:IsA("Tool") then
						child:Destroy()
					end
				end
			end
		end
	elseif actor.Bot then
		actor.Bot.Weapon = nil
		self.Services.BotService:ShowWeapon(actor.Bot, nil, nil)
	end
end

---------------------------------------------------------------- K.O.

function CombatService:KO(victim, killer, cause: string)
	if not victim.Alive then
		return
	end
	local services = self.Services
	victim.Alive = false
	victim.Hidden = false
	services.MapService:ReleaseCloset(victim)
	local position = victim.Root.Position
	services.Net.Fx:FireAllClients("KO", { Model = victim.Model, Position = position, Effect = effectOf(killer), Cause = cause })
	-- Sheriff/Hero laesst den Blaster fallen
	if victim.Role == "Sheriff" or victim.Role == "Hero" then
		self:DropGun(position)
	end
	self:StripWeapons(victim)
	victim.Humanoid.WalkSpeed = 0
	victim.Humanoid.JumpPower = 0
	if victim.Player then
		task.delay(0.9, function()
			if victim.Humanoid.Parent then
				victim.Humanoid.Health = 0
			end
		end)
	elseif victim.Bot then
		services.BotService:OnKO(victim.Bot)
	end
	services.BotService:Alarm(position)
	services.RoundService:OnKO(victim, killer, cause)
	if killer and killer.Player and killer.Role == "Murderer" and victim ~= killer then
		services.ProgressService:Track(killer.Player, "KO", 1)
	end
end

-- Murderer wird fuer Bots sichtbar "entlarvt", wenn er in der Naehe zuschlaegt
local function expose(actor)
	actor.Exposed = now()
end

local function hitActor(attacker, victim, cause: string)
	if not victim or not victim.Alive or victim == attacker or victim.Hidden then
		return false
	end
	if victim.Shield and attacker.Role == "Murderer" then
		victim.Shield = false
		victim.Model:SetAttribute("Shield", false)
		CombatService.Services.Net.Fx:FireAllClients("ShieldPop", { Position = victim.Root.Position })
		if victim.Player then
			CombatService.Services.Net.SendNotify(victim.Player, "Your Bubble Shield saved you! RUN!", C.Purple)
		end
		return true
	end
	CombatService:KO(victim, attacker, cause)
	return true
end

---------------------------------------------------------------- Messer

function CombatService:Stab(attacker): boolean
	local round = self.Services.RoundService
	if not round:IsPlaying() or not attacker.Alive or attacker.Role ~= "Murderer" then
		return false
	end
	if not equipped(attacker, "Knife") or not ready(attacker, "Stab", K.Cooldown) then
		return false
	end
	self.Services.Net.Fx:FireAllClients("Swing", { Model = attacker.Model })
	local origin = attacker.Root.Position
	local look = attacker.Root.CFrame.LookVector
	local best, bestDist = nil, K.Range
	for _, actor in round.Actors do
		if actor ~= attacker and actor.Alive and not actor.Hidden then
			local offset = actor.Root.Position - origin
			local dist = offset.Magnitude
			if dist < bestDist and (dist < 3.5 or offset.Unit:Dot(look) > -0.1) then
				best, bestDist = actor, dist
			end
		end
	end
	if best then
		expose(attacker)
		return hitActor(attacker, best, "Knife")
	end
	return false
end

-- Fliegendes Messer: der Server rechnet die Flugbahn, die Clients zeigen es
function CombatService:Throw(attacker, target: Vector3): boolean
	local round = self.Services.RoundService
	if not round:IsPlaying() or not attacker.Alive or attacker.Role ~= "Murderer" or typeof(target) ~= "Vector3" then
		return false
	end
	local skin = equipped(attacker, "Knife")
	if not skin or not ready(attacker, "Throw", K.ThrowCooldown) then
		return false
	end
	local start = attacker.Root.Position + Vector3.new(0, 1.5, 0)
	local dir = target - start
	if dir.Magnitude < 1 then
		return false
	end
	dir = dir.Unit
	expose(attacker)
	self.Services.Net.Fx:FireAllClients("Throw", { From = start, Dir = dir, Speed = K.ThrowSpeed, Skin = skin, Model = attacker.Model })
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.Model, fxFolder, workspace:FindFirstChild("Coins") :: Instance, workspace:FindFirstChild("PowerUps") :: Instance }
	params.RespectCanCollide = false
	task.spawn(function()
		local pos = start
		local travelled = 0
		while travelled < K.ThrowRange and round:IsPlaying() do
			local dt = RunService.Heartbeat:Wait()
			local step = dir * K.ThrowSpeed * dt
			local result = workspace:Raycast(pos, step, params)
			if result then
				local victim = round:ActorFromPart(result.Instance)
				if victim then
					hitActor(attacker, victim, "Throw")
					return
				end
				if result.Instance.CanCollide then
					return
				end
				-- Nicht-kollidierende Deko durchfliegen
				local list = params.FilterDescendantsInstances
				table.insert(list, result.Instance)
				params.FilterDescendantsInstances = list
			end
			pos += step
			travelled += step.Magnitude
		end
	end)
	return true
end

---------------------------------------------------------------- Blaster

function CombatService:Shoot(shooter, target: Vector3): boolean
	local round = self.Services.RoundService
	if not round:IsPlaying() or not shooter.Alive or (shooter.Role ~= "Sheriff" and shooter.Role ~= "Hero") or typeof(target) ~= "Vector3" then
		return false
	end
	local skin = equipped(shooter, "Gun")
	if not skin or not ready(shooter, "Shoot", G.Cooldown) then
		return false
	end
	local head = shooter.Model:FindFirstChild("Head") :: BasePart?
	local start = if head then head.Position else shooter.Root.Position + Vector3.new(0, 1.5, 0)
	local dir = target - start
	if dir.Magnitude < 0.5 then
		return false
	end
	dir = dir.Unit * G.Range
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { shooter.Model, fxFolder, workspace:FindFirstChild("Coins") :: Instance, workspace:FindFirstChild("PowerUps") :: Instance }
	params.RespectCanCollide = false
	local hitPos = start + dir
	local victim = nil
	for _ = 1, 6 do
		local result = workspace:Raycast(start, hitPos - start, params)
		if not result then
			break
		end
		victim = round:ActorFromPart(result.Instance)
		hitPos = result.Position
		if victim or result.Instance.CanCollide then
			break
		end
		local list = params.FilterDescendantsInstances
		table.insert(list, result.Instance)
		params.FilterDescendantsInstances = list
		hitPos = start + dir
	end
	local item = Config.GetItem("Gun", skin)
	self.Services.Net.Fx:FireAllClients("Shot", { From = start, To = hitPos, Color = item and item.Beam or C.Moon, Model = shooter.Model })
	if victim and victim.Alive and not victim.Hidden then
		if victim.Role == "Murderer" then
			self:KO(victim, shooter, "Shot")
		else
			-- Unschuldigen getroffen: beide sind raus (wie im Original)
			self:KO(victim, shooter, "Shot")
			if shooter.Alive then
				if shooter.Player then
					self.Services.Net.SendNotify(shooter.Player, "You hit an innocent! You're out too.", C.Red)
				end
				self:KO(shooter, nil, "Mistake")
			end
		end
	end
	return true
end

---------------------------------------------------------------- Fallengelassener Blaster

function CombatService:DropGun(position: Vector3)
	local round = self.Services.RoundService
	if not round:IsPlaying() and round.State ~= "Reveal" then
		return
	end
	-- Ist noch ein Sheriff/Hero mit Blaster am Leben? (Duo-Modus) Dann trotzdem fallen lassen.
	if droppedGun then
		droppedGun:Destroy()
	end
	local model = Skins.Gun("Default")
	model.Name = "DroppedGun"
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanQuery = false
		end
	end
	-- Auf den Boden legen
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { round.Map and round.Map.Model or workspace }
	local ground = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -30, 0), params)
	local at = if ground then ground.Position + Vector3.new(0, 1.6, 0) else position
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)))
	local zone = Instance.new("Part")
	zone.Name = "PickupZone"
	zone.Shape = Enum.PartType.Ball
	zone.Size = Vector3.new(5, 5, 5)
	zone.CFrame = CFrame.new(at)
	zone.Transparency = 1
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.Parent = model
	local highlight = Instance.new("Highlight")
	highlight.FillColor = C.Moon
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.4
	highlight.Parent = model
	model:SetAttribute("DropTime", now())
	model:AddTag("DroppedGun")
	model.Parent = fxFolder
	droppedGun = model
	self.Services.Net.SendAnnounce("The Sheriff's blaster dropped! Innocents can pick it up!", C.Moon)
	self.Services.Net.Fx:FireAllClients("GunDropped", { Position = at })
	zone.Touched:Connect(function(hit)
		self:TryPickup(round:ActorFromPart(hit))
	end)
end

function CombatService:GetDroppedGun(): Model?
	return if droppedGun and droppedGun.Parent then droppedGun else nil
end

function CombatService:TryPickup(actor)
	local round = self.Services.RoundService
	local gun = self:GetDroppedGun()
	if not gun or not actor or not actor.Alive or actor.Role ~= "Innocent" or not round:IsPlaying() then
		return
	end
	if now() - (gun:GetAttribute("DropTime") or 0) < G.DropPickupDelay then
		return
	end
	droppedGun = nil
	gun:Destroy()
	actor.Role = "Hero"
	self:GiveWeapon(actor, "Gun")
	self.Services.Net.SendAnnounce(`Someone picked up the blaster!`, C.Moon)
	if actor.Player then
		self.Services.Net.Role:FireClient(actor.Player, "Role", { Role = "Hero" })
	end
	self.Services.Net.Fx:FireAllClients("GunTaken", {})
end

function CombatService:ClearDrops()
	if droppedGun then
		droppedGun:Destroy()
		droppedGun = nil
	end
	for _, child in fxFolder:GetChildren() do
		child:Destroy()
	end
end

---------------------------------------------------------------- Start

function CombatService:Init(services)
	self.Services = services
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "RoundFx"
	fxFolder.Parent = workspace
	self.FxFolder = fxFolder
end

function CombatService:Start()
	local services = self.Services
	local Net = services.Net
	local round = services.RoundService
	Net.Stab.OnServerEvent:Connect(function(player)
		local actor = round:ActorOfPlayer(player)
		if actor then
			self:Stab(actor)
		end
	end)
	Net.Throw.OnServerEvent:Connect(function(player, target)
		local actor = round:ActorOfPlayer(player)
		if actor then
			self:Throw(actor, target)
		end
	end)
	Net.Shoot.OnServerEvent:Connect(function(player, target)
		local actor = round:ActorOfPlayer(player)
		if actor then
			self:Shoot(actor, target)
		end
	end)
	-- Faellt jemand aus der Karte, ist er raus
	task.spawn(function()
		while true do
			task.wait(1)
			if round.Map then
				for _, actor in round.Actors do
					if actor.Alive and actor.Root.Position.Y < round.Map.Bounds.Min.Y - 30 then
						self:KO(actor, nil, "Fall")
					end
				end
			end
		end
	end)
	Debris.MaxItems = 2000
end

return CombatService
