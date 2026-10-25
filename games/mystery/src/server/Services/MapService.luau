-- Lobby, Karten laden/entladen, Licht, und alles Interaktive auf der Karte:
-- Schraenke (verstecken/durchsuchen), Lueftungsschaechte (Murderer), Tueren, Obby, Bestenlisten.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local MapBuilder = require(script.Parent.MapBuilder)

local MapService = { Services = nil :: any }

local C = Config.Colors

local current = nil
local closetOf = {} -- [actor] = closet model
local hideCooldown = {} -- [actor] = os.clock()
local ventCooldown = {}
local doorCooldown = {} -- [door] = os.clock()
local obbyStart = {} -- [Player] = os.clock()

---------------------------------------------------------------- Licht

local function setupLighting()
	Lighting.ClockTime = 0.2
	Lighting.Brightness = 1.4
	Lighting.Ambient = Color3.fromRGB(70, 70, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 90, 150)
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.GlobalShadows = true
	Lighting.GeographicLatitude = 25
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(120, 120, 200)
	atmosphere.Decay = Color3.fromRGB(60, 50, 120)
	atmosphere.Glare = 0.2
	atmosphere.Haze = 1.4
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.6
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.08
	color.Contrast = 0.08
	color.TintColor = Color3.fromRGB(235, 235, 255)
	color.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.MoonAngularSize = 22
	sky.StarCount = 5000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
end

---------------------------------------------------------------- Karte

function MapService:LoadMap(def)
	self:UnloadMap()
	current = MapBuilder.Build(def, Config.MapOrigin, math.random(1, 1e6))
	-- Tueren, Schraenke, Schaechte verbinden
	for _, door in CollectionService:GetTagged("Door") do
		if door:IsDescendantOf(current.Model) then
			local prompt = door:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					self:SlamDoor(door, player)
				end)
			end
		end
	end
	for _, closet in CollectionService:GetTagged("Closet") do
		if closet:IsDescendantOf(current.Model) then
			local prompt = closet:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				prompt.Triggered:Connect(function(player)
					local actor = self.Services.RoundService:ActorOfPlayer(player)
					if actor then
						self:UseCloset(actor, closet)
					end
				end)
			end
		end
	end
	for _, vent in CollectionService:GetTagged("Vent") do
		if vent:IsDescendantOf(current.Model) then
			local prompt = vent:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					local actor = self.Services.RoundService:ActorOfPlayer(player)
					if actor then
						self:UseVent(actor, vent)
					end
				end)
			end
		end
	end
	return current
end

function MapService:UnloadMap()
	for actor in closetOf do
		self:ReleaseCloset(actor)
	end
	table.clear(hideCooldown)
	table.clear(ventCooldown)
	table.clear(doorCooldown)
	if current then
		current.Model:Destroy()
		current = nil
	end
	self.Services.CombatService:ClearDrops()
end

function MapService:Current()
	return current
end

---------------------------------------------------------------- Tueren

function MapService:SlamDoor(door: BasePart, player: Player?)
	local round = self.Services.RoundService
	local actor = player and round:ActorOfPlayer(player)
	if player and (not actor or not actor.Alive) then
		return
	end
	if not round:IsPlaying() then
		return
	end
	local t = os.clock()
	if t - (doorCooldown[door] or -math.huge) < Config.Door.Cooldown then
		if player then
			self.Services.Net.SendNotify(player, "This door is still jammed!", C.Orange)
		end
		return
	end
	doorCooldown[door] = t
	MapBuilder.SetDoor(door, true)
	self.Services.Net.Fx:FireAllClients("Door", { Position = door.Position })
	task.delay(Config.Door.LockTime, function()
		if door.Parent then
			MapBuilder.SetDoor(door, false)
		end
	end)
end

---------------------------------------------------------------- Schraenke

local function setAnchored(actor, anchored: boolean)
	actor.Root.Anchored = anchored
end

-- Alle Versteckten freigeben, ohne sie vor den Schrank zu setzen (Rundenende)
function MapService:ReleaseAllClosets()
	for actor in closetOf do
		self:ReleaseCloset(actor, true)
	end
end

function MapService:ReleaseCloset(actor, stayInPlace: boolean?)
	local closet = closetOf[actor]
	if not closet then
		return
	end
	closetOf[actor] = nil
	closet:SetAttribute("Occupied", false)
	actor.Hidden = false
	actor.Model:SetAttribute("Hidden", false)
	hideCooldown[actor] = os.clock()
	if actor.Root.Parent then
		setAnchored(actor, false)
		local door = closet.PrimaryPart
		if door and not stayInPlace then
			actor.Model:PivotTo(door.CFrame * CFrame.new(0, -0.5, -3.2) * CFrame.Angles(0, math.pi, 0))
		end
	end
	if actor.Player then
		self.Services.Net.Role:FireClient(actor.Player, "Hidden", false)
	end
end

function MapService:UseCloset(actor, closet: Model)
	local round = self.Services.RoundService
	if not round:IsPlaying() or not actor.Alive then
		return
	end
	local services = self.Services
	if actor.Role == "Murderer" then
		-- Durchsuchen: wer drin ist, fliegt raus
		for other, c in closetOf do
			if c == closet then
				self:ReleaseCloset(other)
				services.Net.Fx:FireAllClients("ClosetOpen", { Position = closet:GetPivot().Position })
				if other.Player then
					services.Net.SendNotify(other.Player, "FOUND YOU! Run!", C.Red)
				end
				return
			end
		end
		services.Net.Fx:FireAllClients("ClosetOpen", { Position = closet:GetPivot().Position })
		return
	end
	if closetOf[actor] == closet then
		self:ReleaseCloset(actor)
		return
	end
	if closetOf[actor] or closet:GetAttribute("Occupied") then
		if actor.Player then
			services.Net.SendNotify(actor.Player, "Someone is already hiding in there!", C.Orange)
		end
		return
	end
	if os.clock() - (hideCooldown[actor] or -math.huge) < Config.Hide.Cooldown then
		if actor.Player then
			services.Net.SendNotify(actor.Player, "Catch your breath first!", C.Orange)
		end
		return
	end
	local door = closet.PrimaryPart
	local inside = door and door:FindFirstChild("Inside")
	if not inside then
		return
	end
	closetOf[actor] = closet
	closet:SetAttribute("Occupied", true)
	actor.Hidden = true
	actor.Model:SetAttribute("Hidden", true)
	-- Werkzeug weglegen, damit nichts aus dem Schrank ragt
	actor.Humanoid:UnequipTools()
	actor.Model:PivotTo((inside :: Attachment).WorldCFrame)
	setAnchored(actor, true)
	if actor.Player then
		services.Net.Role:FireClient(actor.Player, "Hidden", true)
		services.ProgressService:Track(actor.Player, "Hide", 1)
		services.ProgressService:AddStat(actor.Player, "Hides", 1)
	end
	local token = {}
	actor.HideToken = token
	task.delay(Config.Hide.MaxTime, function()
		if closetOf[actor] == closet and actor.HideToken == token then
			self:ReleaseCloset(actor)
			if actor.Player then
				services.Net.SendNotify(actor.Player, "You can't hide forever!", C.Orange)
			end
		end
	end)
end

---------------------------------------------------------------- Lueftungsschaechte

function MapService:UseVent(actor, vent: BasePart)
	local round = self.Services.RoundService
	if not round:IsPlaying() or not actor.Alive or actor.Role ~= "Murderer" or not current then
		return
	end
	if os.clock() - (ventCooldown[actor] or -math.huge) < Config.Vent.Cooldown then
		return
	end
	local pair = vent:GetAttribute("Pair")
	for _, other in CollectionService:GetTagged("Vent") do
		if other ~= vent and other:GetAttribute("Pair") == pair and other:IsDescendantOf(current.Model) then
			ventCooldown[actor] = os.clock()
			self.Services.Net.Fx:FireAllClients("Vent", { From = vent.Position, To = other.Position })
			actor.Model:PivotTo(CFrame.new(other.Position + Vector3.new(0, 3.5, 0)) * actor.Root.CFrame.Rotation)
			return
		end
	end
end

---------------------------------------------------------------- Obby und Stationen

local function setupObby()
	local services = MapService.Services
	for _, pad in CollectionService:GetTagged("ObbyStart") do
		pad.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if player then
				obbyStart[player] = os.clock()
			end
		end)
	end
	for _, net in CollectionService:GetTagged("ObbyReset") do
		net.CanTouch = true
		net.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			local start = CollectionService:GetTagged("ObbyStart")[1]
			if player and start and player.Character then
				player.Character:PivotTo(start.CFrame + Vector3.new(0, 4, 0))
			end
		end)
	end
	for _, chest in CollectionService:GetTagged("ObbyChest") do
		local prompt = chest:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local started = obbyStart[player]
				if not started or os.clock() - started < 8 then
					services.Net.SendNotify(player, "Start the obby at the green pad!", C.Orange)
					return
				end
				obbyStart[player] = nil
				services.ProgressService:ClaimObby(player)
			end)
		end
	end
	for _, booth in CollectionService:GetTagged("Booth") do
		local prompt = booth:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				services.Net.Fx:FireClient(player, "OpenMenu", { Menu = booth:GetAttribute("Menu") })
			end)
		end
	end
end

---------------------------------------------------------------- Bestenlisten

local boards = {}
local nameCache = {} -- [userId] = Name (spart Anfragen, die Liste wird alle 2 Minuten neu gebaut)
local function updateBoards()
	for _, panel in CollectionService:GetTagged("Leaderboard") do
		local stat = panel:GetAttribute("Stat")
		local store = boards[stat]
		if not store then
			local ok, s = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "MM_" .. stat .. "_v1")
			if not ok then
				continue
			end
			store = s
			boards[stat] = s
		end
		-- Eigene Werte hochladen
		for _, player in Players:GetPlayers() do
			local data = MapService.Services.DataService:Get(player)
			if data and (data[stat] or 0) > 0 then
				pcall(store.SetAsync, store, tostring(player.UserId), data[stat])
			end
		end
		local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
		local lines = { (if stat == "Wins" then "TOP WINS" else "TOP KNOCKOUTS") }
		if ok and pages then
			for rank, entry in pages:GetCurrentPage() do
				local userId = tonumber(entry.key) :: number
				local name = nameCache[userId]
				if not name then
					local okName, result = pcall(Players.GetNameFromUserIdAsync, Players, userId)
					if okName then
						name = result
						nameCache[userId] = result
					end
				end
				name = name or "?"
				table.insert(lines, `{rank}. {name}  {Format.Number(entry.value)}`)
			end
		end
		local gui = panel:FindFirstChild("BoardGui") :: SurfaceGui?
		if not gui then
			local g = Instance.new("SurfaceGui")
			g.Name = "BoardGui"
			g.Face = Enum.NormalId.Front
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 30
			g.LightInfluence = 0
			g.Parent = panel
			local list = Instance.new("UIListLayout")
			list.Padding = UDim.new(0, 6)
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			list.Parent = g
			gui = g
		end
		for _, child in (gui :: SurfaceGui):GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		for i, line in lines do
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, -20, 0, if i == 1 then 70 else 44)
			label.BackgroundTransparency = 1
			label.Font = if i == 1 then Enum.Font.LuckiestGuy else Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = if i == 1 then C.Moon elseif i <= 4 then C.White else C.Muted
			label.Text = line
			label.LayoutOrder = i
			label.Parent = gui
		end
	end
end

function MapService:Init(services)
	self.Services = services
	setupLighting()
end

function MapService:Build()
	MapBuilder.BuildLobby()
end

function MapService:Start()
	setupObby()
	task.spawn(function()
		task.wait(5)
		while true do
			pcall(updateBoards)
			task.wait(120)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		obbyStart[player] = nil
	end)
end

return MapService
