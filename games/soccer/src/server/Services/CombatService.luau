-- Messer wie in Soccer Jam: Slash und Stab mit den Schadenswerten aus CS 1.6, von hinten (Backstab) dreifach.
-- Harte Schuesse (Smack) machen auch Schaden. Bei 0 Leben ist man K.O.: man kippt um (kein Blut),
-- verliert den Ball und steht nach Config.KOSeconds an der eigenen Startposition wieder auf.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local CombatService = { Services = nil :: any }

local swings = {} -- [actor] = { Kind, Starts, Ends }
local ANIMATIONS = { Slash = "rbxassetid://522635514", Stab = "rbxassetid://522638767" } -- Roblox-Standard: ToolSlash, ToolLunge

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

local function playing(): boolean
	return workspace:GetAttribute("MatchState") == "Playing"
end

function CombatService:Init(services)
	self.Services = services
end

---------------------------------------------------------------- Leben

local function hasPass(actor, key: string): boolean
	return actor.Player ~= nil and actor.Player:GetAttribute("Pass_" .. key) == true
end

-- Lebensbalken im Namensschild ueber dem Kopf
local function updateTag(actor)
	local head = actor.Model:FindFirstChild("Head")
	local tag = head and head:FindFirstChild("NameTag")
	local back = tag and tag:FindFirstChild("HP")
	local bar = back and back:FindFirstChild("Bar") :: Frame?
	if bar then
		local fraction = actor.HP / (actor.MaxHP or Config.MaxHP)
		bar.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
		bar.BackgroundColor3 = if fraction > 0.5 then Color3.fromRGB(90, 230, 90) elseif fraction > 0.25 then Config.Colors.Orange else Config.Colors.Red
	end
end

local function setHP(actor, hp: number)
	actor.HP = hp
	actor.Model:SetAttribute("HP", hp)
	updateTag(actor)
end

function CombatService:IsKO(actor): boolean
	return (actor.KOUntil or 0) > now()
end

-- Heilung (Regeneration ausserhalb des Kampfes)
function CombatService:AddHP(actor, amount: number)
	setHP(actor, math.min(actor.MaxHP or Config.MaxHP, actor.HP + amount))
end

-- Volle Leben; Stamina-Upgrades zaehlen ab dem naechsten Heilen (wie im Original nach dem Respawn)
function CombatService:Heal(actor)
	actor.MaxHP = Config.MaxHPFor(self.Services.MatchService:Skill(actor, "Stamina"))
	if hasPass(actor, "IronBody") then
		actor.MaxHP += Config.IronBodyHP
	end
	actor.Model:SetAttribute("MaxHP", actor.MaxHP)
	setHP(actor, actor.MaxHP)
end

-- Samurai-Schwert (Katana) in die rechte Hand: umwickelter Griff in Teamfarbe, goldenes Stichblatt, lange Klinge.
-- Das Model heisst weiter "Knife", damit alle bisherigen Abfragen gelten.
local function giveKnife(actor)
	local hand = actor.Model:FindFirstChild("RightHand") :: BasePart?
	if not hand or actor.Model:FindFirstChild("Knife") then
		return
	end
	local knife = Instance.new("Model")
	knife.Name = "Knife"
	local function piece(size: Vector3, offset: CFrame, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = hand.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = p
		weld.Parent = p
		p.Parent = knife
		return p
	end
	-- Klinge: Golden-Katana-Pass schlaegt den gewaehlten Skin
	local golden = hasPass(actor, "GoldenKnife")
	local skin = Config.SwordSkinsById[actor.Player and actor.Player:GetAttribute("SwordSkin") or "classic"] or Config.SwordSkins[1]
	local bladeColor = if golden then Color3.fromRGB(255, 200, 40) else skin.Color
	local bladeMaterial = if golden then Enum.Material.Neon else skin.Material
	piece(Vector3.new(0.28, 0.3, 1.5), CFrame.new(0, -0.35, 0.25), Color3.fromRGB(25, 25, 28), Enum.Material.Fabric)
	piece(Vector3.new(0.3, 0.32, 0.25), CFrame.new(0, -0.35, 0.95), Config.Teams[actor.Team].Color, Enum.Material.SmoothPlastic)
	piece(Vector3.new(0.9, 0.9, 0.12), CFrame.new(0, -0.35, -0.55), Color3.fromRGB(200, 160, 60), Enum.Material.Metal)
	local blade = piece(Vector3.new(0.08, 0.32, 4.4), CFrame.new(0, -0.3, -2.8), bladeColor, bladeMaterial)
	piece(Vector3.new(0.09, 0.08, 4.4), CFrame.new(0, -0.48, -2.8), Color3.fromRGB(245, 248, 255), bladeMaterial)
	-- Schwert-Spur: leuchtet nur waehrend eines Schwungs
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0, -0.4)
	a0.Parent = blade
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0, -2.2)
	a1.Parent = blade
	local trail = Instance.new("Trail")
	trail.Name = "SwordTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(bladeColor)
	trail.LightEmission = 0.7
	trail.Lifetime = 0.18
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Enabled = false
	trail.Parent = blade
	knife.Parent = actor.Model
end

-- Neuer Skin gewaehlt: Schwert neu bauen
function CombatService:RefreshSword(actor)
	local old = actor.Model:FindFirstChild("Knife")
	if old then
		old:Destroy()
	end
	giveKnife(actor)
end

local function showTrail(actor, seconds: number)
	local knife = actor.Model:FindFirstChild("Knife")
	local trail = knife and knife:FindFirstChild("SwordTrail", true) :: Trail?
	if trail then
		trail.Enabled = true
		task.delay(seconds, function()
			trail.Enabled = false
		end)
	end
end

function CombatService:Setup(actor)
	actor.KOUntil = 0
	actor.KnifeReadyAt = 0
	actor.SpawnProtectUntil = 0
	actor.Model:SetAttribute("KOUntil", 0)
	self:Heal(actor)
	giveKnife(actor)
	-- Laedt der Avatar spaeter nach, wird die Hand ersetzt: Messer neu anbringen
	actor.Model.ChildAdded:Connect(function(child)
		if child.Name == "RightHand" then
			local old = actor.Model:FindFirstChild("Knife")
			if old then
				old:Destroy()
			end
			task.defer(giveKnife, actor)
		end
	end)
end

-- Beim Anstoss: alle voll geheilt und wieder auf den Beinen
function CombatService:Reset(actor)
	swings[actor] = nil
	actor.KOUntil = 0
	actor.Model:SetAttribute("KOUntil", 0)
	actor.Humanoid.PlatformStand = false
	self:Heal(actor)
end

---------------------------------------------------------------- Schaden und K.O.

local function knockOut(victim, attacker, kind: string)
	local services = CombatService.Services
	local koSeconds = if hasPass(victim, "QuickRespawn") then Config.QuickRespawnSeconds else Config.KOSeconds
	victim.KOUntil = now() + koSeconds
	victim.Model:SetAttribute("KOUntil", victim.KOUntil)
	swings[victim] = nil
	local push = if attacker then flat(victim.Root.Position - attacker.Root.Position) else Vector3.zero
	services.BallService:Knock(victim, push * 20 + Vector3.new(0, 18, 0), koSeconds)
	victim.Humanoid.PlatformStand = true
	services.MatchService:OnKO(attacker, victim, kind)
	local koUntil = victim.KOUntil
	task.delay(koSeconds, function()
		if victim.KOUntil == koUntil then
			CombatService:Revive(victim)
		end
	end)
end

-- Wieder aufstehen (nach Ablauf der K.O.-Zeit oder sofort mit "Respawn Now")
function CombatService:Revive(victim)
	local services = self.Services
	if not services.MatchService:IsActor(victim) then
		return
	end
	do
		victim.KOUntil = 0
		victim.Model:SetAttribute("KOUntil", 0)
		victim.Humanoid.PlatformStand = false
		CombatService:Heal(victim)
		victim.SpawnProtectUntil = now() + Config.SpawnProtect
		victim.Model:SetAttribute("SpawnProtectUntil", victim.SpawnProtectUntil)
		victim.StunnedUntil = 0
		victim.Model:SetAttribute("StunnedUntil", 0)
		victim.Model:SetAttribute("KnockedUntil", 0)
		services.MatchService:PlaceActor(victim)
		if not victim.Player then
			victim.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

-- kind: "Slash", "Stab" oder "Smack"
function CombatService:Damage(victim, amount: number, attacker, kind: string, backstab: boolean?)
	if not playing() or self:IsKO(victim) or (victim.SpawnProtectUntil or 0) > now() then
		if attacker and attacker.Player then
			self.Services.DiagService:Count("damageBlocked." .. (if not playing() then "notPlaying" elseif self:IsKO(victim) then "victimKO" else "spawnProtect"))
		end
		return
	end
	if attacker and attacker.Player then
		self.Services.DiagService:Count("damage." .. kind)
	end
	-- Bubble Shield (Produkt): kein Schaden
	if Config.Active(victim.Player, "ShieldUntil") then
		return
	end
	if attacker and attacker.Team == victim.Team then
		return
	end
	-- Das Schwert trifft ueberall (Ali: die Ballnaehe-Regel liess Spieler scheinbar gar nicht angreifen)
	if attacker and (kind == "Slash" or kind == "Stab") then
		-- Treffer am Ballfuehrer: Chance, dass er den Ball verliert
		local disarm = Config.DisarmChance(self.Services.MatchService:Skill(attacker, "Disarm")) * (if hasPass(victim, "IronGrip") then Config.IronGripFactor else 1)
		if self.Services.BallService.Carrier == victim and math.random() < disarm then
			if self.Services.BallService:Disarm(attacker, victim) then
				self.Services.MatchService:OnDisarm(attacker, victim)
			end
		end
	end
	-- Golden Knife (Pass): mehr Messerschaden
	if attacker and (kind == "Slash" or kind == "Stab") then
		if hasPass(attacker, "GoldenKnife") then
			amount *= Config.GoldenKnifeDamage
		end
		if Config.Active(attacker.Player, "RageUntil") then
			amount *= Config.RageFactor
		end
		amount = math.floor(self.Services.ExtrasService:ModifyDamage(attacker, victim, amount, kind) + 0.5)
	end
	victim.LastHurt = now()
	local dealt = math.min(victim.HP, amount)
	local hp = math.max(0, victim.HP - amount)
	setHP(victim, hp)
	-- Vampire Knife (Pass): Angreifer heilt sich
	if attacker and (kind == "Slash" or kind == "Stab") and hasPass(attacker, "VampireKnife") and not self:IsKO(attacker) then
		setHP(attacker, math.min(attacker.MaxHP or Config.MaxHP, attacker.HP + math.floor(dealt * Config.VampireHeal)))
	end
	self.Services.Net.MatchEvent:FireAllClients("Damage", { Model = victim.Model, Amount = amount, Backstab = backstab == true, Attacker = attacker and attacker.Model })
	if hp <= 0 then
		knockOut(victim, attacker, kind)
	end
end

---------------------------------------------------------------- Messer

local function playAnimation(actor, kind: string)
	local animator = actor.Humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	actor.KnifeTracks = actor.KnifeTracks or {}
	local track = actor.KnifeTracks[kind]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = ANIMATIONS[kind]
		local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
		if not ok then
			return
		end
		track = loaded
		track.Priority = Enum.AnimationPriority.Action
		actor.KnifeTracks[kind] = track
	end
	track:Play(0.05)
end

-- Startet einen Messerangriff; der Treffer wird im naechsten Moment gesucht (Heartbeat)
function CombatService:Swing(actor, kind: string, aim: Vector3?): boolean
	local def = Config.Knife[kind]
	local diag = if actor.Player then self.Services.DiagService else nil
	local reason = if not def then "badKind" elseif not playing() then "notPlaying" elseif self:IsKO(actor) then "attackerKO"
		elseif (actor.StunnedUntil or 0) > now() then "stunned" elseif self.Services.BallService.Carrier == actor then "carrier"
		elseif (actor.KnifeReadyAt or 0) > now() then "cooldown" else nil
	if reason then
		if diag then
			diag:Count("swingRefused." .. reason)
		end
		return false
	end
	if diag then
		diag:Count("swingStarted." .. kind)
	end
	actor.KnifeReadyAt = now() + def.Cooldown * (if kind == "Stab" and hasPass(actor, "Ninja") then Config.NinjaStabCooldown else 1)
	if actor.Player then
		actor.Player:SetAttribute("KnifeReadyAt", actor.KnifeReadyAt)
	end
	local aimFlat = if typeof(aim) == "Vector3" and aim == aim then flat(aim) else nil
	swings[actor] = { Kind = kind, Starts = now() + def.Windup, Ends = now() + def.Windup + def.Window, Aim = if aimFlat and aimFlat.Magnitude > 0.5 then aimFlat else nil }
	playAnimation(actor, kind)
	showTrail(actor, def.Windup + def.Window)
	self.Services.Net.PlaySound(kind, actor.Root.Position)
	return true
end

-- Von hinten: das Opfer schaut vom Angreifer weg
local function isBehind(attacker, victim): boolean
	local toVictim = flat(victim.Root.Position - attacker.Root.Position)
	return flat(victim.Root.CFrame.LookVector):Dot(toVictim) > (if hasPass(attacker, "Ninja") then Config.NinjaBackstabDot else Config.BackstabDot)
end

-- Alien-Maskottchen: jede Sekunde einen Gegner im Kreis vor dem eigenen Tor zappen,
-- ein gegnerischer Ballfuehrer im Kreis ist sofort K.O.; eigene Spieler im Kreis heilen sich
local function alienTick()
	if not playing() then
		return
	end
	local services = CombatService.Services
	local arena = services.ArenaService
	local carrier = services.BallService.Carrier
	for _, teamName in Config.TeamOrder do
		local goal = arena:GoalCenter(teamName)
		local targets = {}
		local victim = nil
		for _, actor in services.MatchService:GetActors() do
			local offset = actor.Root.Position - goal
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < Config.AlienRadius and not CombatService:IsKO(actor) then
				if actor.Team ~= teamName then
					if actor == carrier then
						victim = actor
					else
						table.insert(targets, actor)
					end
				elseif actor.HP < (actor.MaxHP or Config.MaxHP) then
					setHP(actor, math.min(actor.MaxHP or Config.MaxHP, actor.HP + Config.KeeperRegen * Config.AlienInterval))
				end
			end
		end
		if victim then
			arena:MascotStomp(teamName, victim.Root.Position)
			CombatService:Damage(victim, victim.HP, nil, "Alien")
		elseif #targets > 0 then
			local target = targets[math.random(1, #targets)]
			arena:MascotStomp(teamName, target.Root.Position)
			services.Net.PlaySound("Zap", target.Root.Position)
			CombatService:Damage(target, math.random(Config.AlienDamage[1], Config.AlienDamage[2]), nil, "Alien")
		end
	end
end

local function resolveSwings()
	local t = now()
	local match = CombatService.Services.MatchService
	for actor, swing in swings do
		if t > swing.Ends or not match:IsActor(actor) or CombatService:IsKO(actor) then
			swings[actor] = nil
			if actor.Player and not (swing.Hit and next(swing.Hit)) then
				-- Fehlersuche: wo stand der naechste Gegner, als der Schwung ins Leere ging?
				local look = swing.Aim or flat(actor.Root.CFrame.LookVector)
				local nearest, info = math.huge, "no enemy"
				for _, other in match:GetActors() do
					if other.Team ~= actor.Team then
						local offset = other.Root.Position - actor.Root.Position
						local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
						if distance < nearest then
							nearest = distance
							info = string.format("dist %.1f dot %.2f dy %.1f ko %s aim %s", distance, look:Dot(flat(offset)), offset.Y, tostring(CombatService:IsKO(other)), tostring(swing.Aim ~= nil))
						end
					end
				end
				CombatService.Services.DiagService:Count("swingMissed." .. swing.Kind, if nearest < 30 then info else nil)
			end
		elseif t >= swing.Starts then
			local def = Config.Knife[swing.Kind]
			-- Spieler zielen mit der Kamera (Ego-Sicht): Blickrichtung vom Client, sonst die des Koerpers
			local look = swing.Aim or flat(actor.Root.CFrame.LookVector)
			-- Riesen-Modus (Produkt): laengere Reichweite
			local range = def.Range + (if Config.Active(actor.Player, "GiantUntil") then Config.GiantReach else 0)
			local best, bestDistance = nil, math.huge
			swing.Hit = swing.Hit or {}
			for _, other in match:GetActors() do
				if other.Team ~= actor.Team and not CombatService:IsKO(other) and other.Root.Parent and not swing.Hit[other] then
					local offset = other.Root.Position - actor.Root.Position
					local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
					if distance <= range and math.abs(offset.Y) < 8 and (distance < 4 or look:Dot(flat(offset)) > def.Arc) then
						if def.Cleave then
							-- Katana-Schwung: trifft jeden Gegner im Bogen einmal
							swing.Hit[other] = true
							local backstab = isBehind(actor, other)
							CombatService:Damage(other, if backstab then def.Backstab else def.Damage, actor, swing.Kind, backstab)
						elseif distance < bestDistance then
							best, bestDistance = other, distance
						end
					end
				end
			end
			if best then
				swings[actor] = nil
				local backstab = isBehind(actor, best)
				CombatService:Damage(best, if backstab then def.Backstab else def.Damage, actor, swing.Kind, backstab)
			end
		end
	end
end

function CombatService:Forget(actor)
	swings[actor] = nil
end

function CombatService:Start()
	RunService.Heartbeat:Connect(resolveSwings)
	task.spawn(function()
		while true do
			task.wait(Config.AlienInterval)
			local ok, err = pcall(alienTick)
			if not ok then
				warn("[Combat] Alien:", err)
			end
		end
	end)
	local net = self.Services.Net
	net.Stab.OnServerEvent:Connect(function(player, aim)
		local actor = self.Services.MatchService:ActorForPlayer(player)
		if actor then
			self:Swing(actor, "Stab", aim)
		else
			self.Services.DiagService:Count("stabNoActor")
			if player.Character then
				task.spawn(self.Services.MatchService.OnCharacterAdded, self.Services.MatchService, player, player.Character)
			end
		end
	end)
	-- Pass fordern wie im Original (ALT): ein "!" ueber dem Kopf fuer 2 Sekunden
	local lastCall = {}
	net.CallPass.OnServerEvent:Connect(function(player)
		local actor = self.Services.MatchService:ActorForPlayer(player)
		local head = actor and actor.Model and actor.Model:FindFirstChild("Head")
		if not head or os.clock() - (lastCall[player] or 0) < 2 then
			return
		end
		lastCall[player] = os.clock()
		local gui = Instance.new("BillboardGui")
		gui.Name = "PassCall"
		gui.Size = UDim2.fromOffset(60, 60)
		gui.StudsOffset = Vector3.new(0, 5.2, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 400
		local mark = Instance.new("TextLabel")
		mark.Size = UDim2.fromScale(1, 1)
		mark.BackgroundTransparency = 1
		mark.Text = "!"
		mark.TextScaled = true
		mark.Font = Enum.Font.FredokaOne
		mark.TextColor3 = Config.Teams[actor.Team] and Config.Teams[actor.Team].Color or Color3.new(1, 1, 1)
		mark.TextStrokeTransparency = 0
		mark.Parent = gui
		gui.Parent = head
		self.Services.Net.PlaySound("Call", head.Position)
		task.delay(2, function()
			gui:Destroy()
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)
end

return CombatService
