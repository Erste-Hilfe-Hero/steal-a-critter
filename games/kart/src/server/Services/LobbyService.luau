-- Schwebende "Sky Garage" ueber der Strecke: Spawn, Logo-Wand, Status-Anzeige, Sieger-Bestenliste und Kart-Showroom.
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local KartFactory = require(ReplicatedStorage.Shared.KartFactory)

local LobbyService = { Services = nil :: any }

local ORIGIN = Vector3.new(0, 400, 0)
local SIZE = 170
local DARK = Color3.fromRGB(24, 22, 30)
local FLAME = Color3.fromRGB(255, 110, 20)
local GOLD = Color3.fromRGB(255, 200, 40)
local TITLE = Font.new("rbxasset://fonts/families/Sarpanch.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local BODY = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

LobbyService.Origin = ORIGIN

local boardStore = DataStoreService:GetOrderedDataStore(Config.WinsBoardName)

local function make(parent: Instance, props: { [string]: any }): BasePart
	local p: BasePart = Instance.new(props.ClassName or "Part") :: BasePart
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" then
			(p :: any)[key] = value
		end
	end
	p.Parent = parent
	return p
end

local function surface(part: BasePart, face: Enum.NormalId, ppu: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu
	gui.LightInfluence = 0
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = DARK
	bg.Parent = gui
	return gui
end

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.FontFace = BODY
	t.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(t :: any)[key] = value
	end
	t.Parent = parent
	return t
end

local function flameGradient(target: Instance)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 150, 30)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 50, 30)),
	})
	g.Rotation = 90
	g.Parent = target
end

function LobbyService:Init(services)
	self.Services = services
end

function LobbyService:Build()
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	local o = ORIGIN

	-- Plattform mit leuchtendem Rand und Startbahn-Streifen
	make(folder, { Name = "Floor", Size = Vector3.new(SIZE, 4, SIZE), CFrame = CFrame.new(o - Vector3.new(0, 2, 0)), Color = Color3.fromRGB(42, 40, 50), Material = Enum.Material.Asphalt })
	for _, side in { -1, 1 } do
		make(folder, { Size = Vector3.new(SIZE, 1, 1.5), CFrame = CFrame.new(o + Vector3.new(0, 0.1, side * SIZE / 2)), Color = FLAME, Material = Enum.Material.Neon })
		make(folder, { Size = Vector3.new(1.5, 1, SIZE), CFrame = CFrame.new(o + Vector3.new(side * SIZE / 2, 0.1, 0)), Color = FLAME, Material = Enum.Material.Neon })
		make(folder, { Name = "Barrier", Size = Vector3.new(SIZE, 14, 1), CFrame = CFrame.new(o + Vector3.new(0, 7, side * (SIZE / 2 + 0.5))), Transparency = 1 })
		make(folder, { Name = "Barrier", Size = Vector3.new(1, 14, SIZE), CFrame = CFrame.new(o + Vector3.new(side * (SIZE / 2 + 0.5), 7, 0)), Transparency = 1 })
		make(folder, { Size = Vector3.new(SIZE, 1.2, 0.8), CFrame = CFrame.new(o + Vector3.new(0, 3, side * SIZE / 2)), Color = Color3.fromRGB(60, 58, 70), Material = Enum.Material.Metal })
		make(folder, { Size = Vector3.new(0.8, 1.2, SIZE), CFrame = CFrame.new(o + Vector3.new(side * SIZE / 2, 3, 0)), Color = Color3.fromRGB(60, 58, 70), Material = Enum.Material.Metal })
	end
	for x = -70, 70, 20 do
		make(folder, { Size = Vector3.new(2, 0.2, 10), CFrame = CFrame.new(o + Vector3.new(x, 0.05, 0)), Color = Color3.fromRGB(240, 230, 200) })
	end
	-- Unterseite (von der Strecke aus sichtbar)
	make(folder, { Size = Vector3.new(SIZE * 0.6, 20, SIZE * 0.6), CFrame = CFrame.new(o - Vector3.new(0, 14, 0)), Color = DARK, Material = Enum.Material.Metal })
	make(folder, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 50, 50), CFrame = CFrame.new(o - Vector3.new(0, 25, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = FLAME, Material = Enum.Material.Neon })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(o + Vector3.new(0, 0.5, 20))
	spawn.Color = Color3.fromRGB(255, 140, 30)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.Parent = folder

	-- Logo-Wand (Norden)
	local wall = make(folder, { Name = "LogoWall", Size = Vector3.new(90, 34, 2), CFrame = CFrame.new(o + Vector3.new(0, 20, -SIZE / 2 + 4)), Color = DARK, Material = Enum.Material.Metal })
	local logo = surface(wall, Enum.NormalId.Back, 12)
	local fire = text(logo, { Size = UDim2.fromScale(0.94, 0.5), Position = UDim2.fromScale(0.03, 0.06), Text = "FIRE BLASTER", FontFace = TITLE })
	flameGradient(fire)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(60, 10, 0)
	stroke.Parent = fire
	local race = text(logo, { Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.25, 0.55), Text = "RACE", FontFace = TITLE, TextColor3 = Color3.new(1, 1, 1) })
	local stroke2 = stroke:Clone()
	stroke2.Parent = race
	text(logo, { Size = UDim2.fromScale(0.9, 0.08), Position = UDim2.fromScale(0.05, 0.87), Text = "DRIFT  -  BLAST  -  WIN", TextColor3 = Color3.fromRGB(255, 170, 60) })
	for _, x in { -48, 48 } do
		local brazier = make(folder, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 5, 5), CFrame = CFrame.new(o + Vector3.new(x, 3, -SIZE / 2 + 8)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(60, 58, 70), Material = Enum.Material.Metal })
		local f = Instance.new("Fire")
		f.Size = 9
		f.Heat = 14
		f.Parent = brazier
		local l = Instance.new("PointLight")
		l.Color = FLAME
		l.Range = 30
		l.Brightness = 3
		l.Parent = brazier
	end

	-- Status-Anzeige (Osten) und Bestenliste (Westen)
	local statusBoard = make(folder, { Name = "StatusBoard", Size = Vector3.new(2, 20, 40), CFrame = CFrame.new(o + Vector3.new(SIZE / 2 - 6, 12, -20)), Color = DARK, Material = Enum.Material.Metal })
	local statusGui = surface(statusBoard, Enum.NormalId.Left, 16)
	text(statusGui, { Size = UDim2.fromScale(0.9, 0.18), Position = UDim2.fromScale(0.05, 0.06), Text = "NEXT RACE", FontFace = TITLE, TextColor3 = GOLD })
	self.StatusTrack = text(statusGui, { Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.05, 0.3), Text = "", FontFace = TITLE })
	self.StatusTime = text(statusGui, { Size = UDim2.fromScale(0.9, 0.24), Position = UDim2.fromScale(0.05, 0.66), Text = "", TextColor3 = Color3.fromRGB(255, 170, 60) })

	local board = make(folder, { Name = "WinsBoard", Size = Vector3.new(2, 30, 26), CFrame = CFrame.new(o + Vector3.new(-SIZE / 2 + 6, 17, -20)), Color = DARK, Material = Enum.Material.Metal })
	local boardGui = surface(board, Enum.NormalId.Right, 16)
	text(boardGui, { Size = UDim2.fromScale(0.9, 0.1), Position = UDim2.fromScale(0.05, 0.03), Text = "TOP RACERS", FontFace = TITLE, TextColor3 = GOLD })
	self.BoardRows = {}
	for i = 1, 10 do
		self.BoardRows[i] = text(boardGui, {
			Size = UDim2.fromScale(0.9, 0.075),
			Position = UDim2.fromScale(0.05, 0.15 + (i - 1) * 0.083),
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if i == 1 then GOLD elseif i <= 3 then Color3.fromRGB(255, 170, 80) else Color3.fromRGB(230, 225, 240),
		})
	end

	-- Kart-Showroom (Sueden) auf Drehtellern
	local count = #Config.Karts
	for index, kart in Config.Karts do
		local angle = math.rad(-70 + (index - 1) * 140 / (count - 1))
		local pos = o + Vector3.new(math.sin(angle) * 58, 0, math.cos(angle) * 58 + 4)
		local pedestal = make(folder, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 14, 14), CFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = DARK, Material = Enum.Material.Metal })
		make(folder, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.5, 14.6, 14.6), CFrame = pedestal.CFrame * CFrame.new(-0.05, 0, 0), Color = if kart.Pass then GOLD else FLAME, Material = Enum.Material.Neon, Transparency = 0.4 })
		local model = KartFactory.Build(kart.Id, if kart.Pass then "Gold" else "Orange", { Bot = true, DriverColor = kart.Accent })
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
			end
		end
		model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 3, 0), o + Vector3.new(0, 3, 0)))
		model.Name = "Showroom_" .. kart.Id
		model.Parent = folder
		CollectionService:AddTag(model, "Turntable")
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(200, 54)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
		tag.MaxDistance = 90
		tag.Parent = pedestal
		text(tag, { Size = UDim2.fromScale(1, 0.55), Text = kart.Name, FontFace = TITLE, TextColor3 = Color3.new(1, 1, 1) })
		text(tag, {
			Size = UDim2.fromScale(1, 0.45),
			Position = UDim2.fromScale(0, 0.55),
			Text = if kart.Pass then "VIP KART" elseif kart.Price == 0 then "FREE" else Format.Number(kart.Price) .. " COINS",
			TextColor3 = if kart.Pass then GOLD else Color3.fromRGB(255, 170, 60),
		})
	end

	folder.Parent = workspace
	self.Folder = folder
end

function LobbyService:SetStatus(trackName: string, timeText: string)
	if self.StatusTrack then
		self.StatusTrack.Text = trackName
		self.StatusTime.Text = timeText
	end
end

function LobbyService:SubmitWins(player: Player, wins: number)
	task.spawn(function()
		pcall(boardStore.SetAsync, boardStore, tostring(player.UserId), wins)
	end)
end

local nameCache = {}
local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = if ok then name else "Racer"
	return nameCache[userId]
end

function LobbyService:Start()
	task.spawn(function()
		while true do
			local ok, pages = pcall(boardStore.GetSortedAsync, boardStore, false, 10)
			if ok and pages then
				local entries = pages:GetCurrentPage()
				for i = 1, 10 do
					local entry = entries[i]
					self.BoardRows[i].Text = if entry then `{i}. {nameFor(tonumber(entry.key) or 0)}  -  {Format.Number(entry.value)} wins` else ""
				end
			end
			task.wait(60)
		end
	end)
end

return LobbyService
