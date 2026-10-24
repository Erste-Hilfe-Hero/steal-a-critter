-- Streckendefinitionen, Themen und die gemeinsame Geometrie (Server baut damit die Strecke,
-- der Client nutzt dieselben Punkte fuer Minimap, Respawn und Fortschritt).
local TrackPoints = require(script.Parent.TrackPoints)

local Tracks = {}

Tracks.Spacing = 8 -- Abstand der Streckenpunkte in Studs

Tracks.Themes = {
	Stadium = {
		Ground = Color3.fromRGB(70, 140, 70), GroundMaterial = Enum.Material.Grass,
		Road = Color3.fromRGB(52, 52, 60), RoadMaterial = Enum.Material.Asphalt,
		CurbA = Color3.fromRGB(235, 50, 40), CurbB = Color3.fromRGB(245, 245, 245),
		Wall = Color3.fromRGB(220, 225, 235), WallMaterial = Enum.Material.SmoothPlastic, Accent = Color3.fromRGB(255, 120, 30),
		ClockTime = 14, Ambient = Color3.fromRGB(110, 110, 120), Fog = Color3.fromRGB(190, 215, 255), Haze = 0.4,
		Props = { "Stand", "Tree", "Flag" },
	},
	Lava = {
		Ground = Color3.fromRGB(45, 30, 30), GroundMaterial = Enum.Material.Basalt,
		Road = Color3.fromRGB(40, 36, 40), RoadMaterial = Enum.Material.Slate,
		CurbA = Color3.fromRGB(255, 110, 20), CurbB = Color3.fromRGB(30, 26, 30),
		Wall = Color3.fromRGB(70, 50, 50), WallMaterial = Enum.Material.Basalt, Accent = Color3.fromRGB(255, 90, 20),
		ClockTime = 19.5, Ambient = Color3.fromRGB(140, 70, 50), Fog = Color3.fromRGB(120, 40, 20), Haze = 2.2,
		Props = { "Rock", "LavaPool", "Volcano" }, GroundNeon = Color3.fromRGB(255, 80, 10),
	},
	Candy = {
		Ground = Color3.fromRGB(255, 190, 220), GroundMaterial = Enum.Material.SmoothPlastic,
		Road = Color3.fromRGB(120, 70, 50), RoadMaterial = Enum.Material.SmoothPlastic,
		CurbA = Color3.fromRGB(255, 255, 255), CurbB = Color3.fromRGB(255, 80, 140),
		Wall = Color3.fromRGB(150, 230, 255), WallMaterial = Enum.Material.SmoothPlastic, Accent = Color3.fromRGB(255, 100, 180),
		ClockTime = 13, Ambient = Color3.fromRGB(150, 120, 140), Fog = Color3.fromRGB(255, 220, 240), Haze = 0.8,
		Props = { "Lollipop", "Candy", "Cupcake" },
	},
	Snow = {
		Ground = Color3.fromRGB(235, 242, 255), GroundMaterial = Enum.Material.Snow,
		Road = Color3.fromRGB(70, 80, 100), RoadMaterial = Enum.Material.Asphalt,
		CurbA = Color3.fromRGB(80, 170, 255), CurbB = Color3.fromRGB(245, 250, 255),
		Wall = Color3.fromRGB(170, 220, 255), WallMaterial = Enum.Material.Ice, Accent = Color3.fromRGB(90, 200, 255),
		ClockTime = 9, Ambient = Color3.fromRGB(120, 130, 150), Fog = Color3.fromRGB(220, 235, 255), Haze = 1.4,
		Props = { "Pine", "Crystal", "Snowman" },
	},
	City = {
		Ground = Color3.fromRGB(30, 30, 40), GroundMaterial = Enum.Material.Concrete,
		Road = Color3.fromRGB(28, 28, 36), RoadMaterial = Enum.Material.Asphalt,
		CurbA = Color3.fromRGB(0, 230, 255), CurbB = Color3.fromRGB(255, 40, 200),
		Wall = Color3.fromRGB(50, 50, 70), WallMaterial = Enum.Material.Metal, Accent = Color3.fromRGB(0, 230, 255),
		ClockTime = 0.5, Ambient = Color3.fromRGB(70, 60, 110), Fog = Color3.fromRGB(40, 20, 70), Haze = 1.5,
		Props = { "Tower", "Tower", "Lamp" }, NeonCurbs = true,
	},
	Jungle = {
		Ground = Color3.fromRGB(60, 120, 50), GroundMaterial = Enum.Material.LeafyGrass,
		Road = Color3.fromRGB(150, 120, 80), RoadMaterial = Enum.Material.Ground,
		CurbA = Color3.fromRGB(110, 90, 60), CurbB = Color3.fromRGB(170, 150, 110),
		Wall = Color3.fromRGB(120, 115, 100), WallMaterial = Enum.Material.Cobblestone, Accent = Color3.fromRGB(80, 220, 120),
		ClockTime = 16, Ambient = Color3.fromRGB(90, 120, 80), Fog = Color3.fromRGB(150, 200, 140), Haze = 1.8,
		Props = { "Palm", "Ruin", "Tree" },
	},
	Desert = {
		Ground = Color3.fromRGB(235, 200, 140), GroundMaterial = Enum.Material.Sand,
		Road = Color3.fromRGB(110, 90, 75), RoadMaterial = Enum.Material.Sandstone,
		CurbA = Color3.fromRGB(230, 120, 40), CurbB = Color3.fromRGB(250, 235, 200),
		Wall = Color3.fromRGB(200, 160, 110), WallMaterial = Enum.Material.Sandstone, Accent = Color3.fromRGB(255, 160, 40),
		ClockTime = 17.3, Ambient = Color3.fromRGB(150, 120, 90), Fog = Color3.fromRGB(255, 210, 160), Haze = 1.2,
		Props = { "Cactus", "Rock", "Pyramid" },
	},
	Space = {
		Ground = nil, GroundMaterial = Enum.Material.Neon,
		Road = Color3.fromRGB(30, 20, 60), RoadMaterial = Enum.Material.Glass,
		CurbA = Color3.fromRGB(255, 90, 220), CurbB = Color3.fromRGB(90, 200, 255),
		Wall = Color3.fromRGB(140, 120, 255), WallMaterial = Enum.Material.ForceField, Accent = Color3.fromRGB(180, 120, 255),
		ClockTime = 0, Ambient = Color3.fromRGB(110, 90, 160), Fog = Color3.fromRGB(20, 10, 50), Haze = 0,
		Props = { "Asteroid", "Planet", "Asteroid" }, NeonCurbs = true, Void = true,
	},
	Beach = {
		Ground = Color3.fromRGB(245, 225, 170), GroundMaterial = Enum.Material.Sand,
		Road = Color3.fromRGB(80, 85, 95), RoadMaterial = Enum.Material.Asphalt,
		CurbA = Color3.fromRGB(40, 160, 255), CurbB = Color3.fromRGB(255, 255, 255),
		Wall = Color3.fromRGB(255, 255, 255), WallMaterial = Enum.Material.WoodPlanks, Accent = Color3.fromRGB(40, 200, 255),
		ClockTime = 12, Ambient = Color3.fromRGB(130, 130, 120), Fog = Color3.fromRGB(190, 230, 255), Haze = 0.3,
		Props = { "Palm", "Umbrella", "Palm" }, Water = Color3.fromRGB(40, 170, 220),
	},
	Haunted = {
		Ground = Color3.fromRGB(40, 45, 40), GroundMaterial = Enum.Material.Mud,
		Road = Color3.fromRGB(55, 50, 60), RoadMaterial = Enum.Material.Cobblestone,
		CurbA = Color3.fromRGB(150, 60, 255), CurbB = Color3.fromRGB(30, 25, 35),
		Wall = Color3.fromRGB(60, 55, 65), WallMaterial = Enum.Material.Slate, Accent = Color3.fromRGB(160, 255, 90),
		ClockTime = 22, Ambient = Color3.fromRGB(70, 60, 100), Fog = Color3.fromRGB(30, 40, 35), Haze = 2.5,
		Props = { "DeadTree", "Pumpkin", "Grave" }, NeonCurbs = true,
	},
}

Tracks.List = {
	{ Id = "Speedway", Name = "Blaster Speedway", Theme = "Stadium", Width = 40, Items = { 0.22, 0.6 }, Boosts = { 0.08, 0.45, 0.8 }, Coins = { 0.15, 0.35, 0.52, 0.72, 0.9 } },
	{ Id = "LavaLoop", Name = "Lava Loop", Theme = "Lava", Width = 38, Items = { 0.2, 0.58 }, Boosts = { 0.1, 0.42, 0.78 }, Coins = { 0.14, 0.33, 0.5, 0.68, 0.88 } },
	{ Id = "Candy", Name = "Candy Canyon", Theme = "Candy", Width = 36, Items = { 0.2, 0.55, 0.82 }, Boosts = { 0.12, 0.48 }, Coins = { 0.1, 0.3, 0.45, 0.65, 0.92 } },
	{ Id = "Frost", Name = "Frost Peak", Theme = "Snow", Width = 38, Items = { 0.22, 0.62 }, Boosts = { 0.1, 0.4, 0.75 }, Coins = { 0.15, 0.32, 0.5, 0.7, 0.9 } },
	{ Id = "NeonCity", Name = "Neon Night City", Theme = "City", Width = 36, Items = { 0.18, 0.5, 0.8 }, Boosts = { 0.08, 0.35, 0.66 }, Coins = { 0.12, 0.28, 0.44, 0.6, 0.75, 0.9 } },
	{ Id = "Jungle", Name = "Jungle Ruins", Theme = "Jungle", Width = 36, Items = { 0.2, 0.52, 0.8 }, Boosts = { 0.1, 0.44, 0.7 }, Coins = { 0.15, 0.3, 0.48, 0.62, 0.9 } },
	{ Id = "Desert", Name = "Desert Dunes", Theme = "Desert", Width = 40, Items = { 0.2, 0.5, 0.8 }, Boosts = { 0.06, 0.36, 0.64 }, Coins = { 0.12, 0.28, 0.44, 0.58, 0.74, 0.9 } },
	{ Id = "StarHighway", Name = "Star Highway", Theme = "Space", Width = 34, Items = { 0.18, 0.5, 0.78 }, Boosts = { 0.08, 0.32, 0.6, 0.85 }, Coins = { 0.12, 0.26, 0.42, 0.56, 0.7, 0.92 } },
	{ Id = "SunnyBay", Name = "Sunny Bay", Theme = "Beach", Width = 38, Items = { 0.2, 0.52, 0.8 }, Boosts = { 0.1, 0.4, 0.7 }, Coins = { 0.14, 0.3, 0.46, 0.62, 0.9 } },
	{ Id = "Haunted", Name = "Haunted Hollow", Theme = "Haunted", Width = 36, Items = { 0.18, 0.5, 0.8 }, Boosts = { 0.1, 0.38, 0.68 }, Coins = { 0.12, 0.3, 0.46, 0.62, 0.9 } },
}
Tracks.ById = {}
for index, track in Tracks.List do
	track.Order = index
	Tracks.ById[track.Id] = track
end

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

export type Geometry = {
	Points: { Vector3 },
	Tangents: { Vector3 },
	Rights: { Vector3 },
	Count: number,
	Length: number,
	MinY: number,
	Width: number,
}

local cache: { [string]: Geometry } = {}

-- Geschlossene Catmull-Rom-Kurve durch die Kontrollpunkte, in gleichen Abstaenden abgetastet
function Tracks.Geometry(id: string): Geometry
	if cache[id] then
		return cache[id]
	end
	local raw = TrackPoints[id]
	local control = {}
	for _, p in raw do
		table.insert(control, Vector3.new(p[1], p[3], p[2]))
	end
	local n = #control
	local dense = {}
	for i = 1, n do
		local p0 = control[(i - 2) % n + 1]
		local p1 = control[i]
		local p2 = control[i % n + 1]
		local p3 = control[(i + 1) % n + 1]
		for k = 0, 7 do
			table.insert(dense, catmull(p0, p1, p2, p3, k / 8))
		end
	end
	-- Gesamtlaenge und gleichmaessige Abtastung
	local lengths = { 0 }
	local total = 0
	for i = 1, #dense do
		local a, b = dense[i], dense[i % #dense + 1]
		total += Vector2.new(b.X - a.X, b.Z - a.Z).Magnitude
		lengths[i + 1] = total
	end
	local count = math.max(16, math.floor(total / Tracks.Spacing + 0.5))
	local step = total / count
	local points = {}
	local seg = 1
	for k = 0, count - 1 do
		local target = k * step
		while lengths[seg + 1] < target do
			seg += 1
		end
		local a, b = dense[seg], dense[seg % #dense + 1]
		local segLen = lengths[seg + 1] - lengths[seg]
		local f = if segLen > 0 then (target - lengths[seg]) / segLen else 0
		table.insert(points, a:Lerp(b, f))
	end
	local tangents, rights = {}, {}
	local minY = math.huge
	for i = 1, count do
		local prev = points[(i - 2) % count + 1]
		local nxt = points[i % count + 1]
		local tangent = (nxt - prev).Unit
		tangents[i] = tangent
		local flat = Vector3.new(tangent.X, 0, tangent.Z).Unit
		rights[i] = flat:Cross(Vector3.yAxis).Unit
		minY = math.min(minY, points[i].Y)
	end
	local geometry = {
		Points = points,
		Tangents = tangents,
		Rights = rights,
		Count = count,
		Length = total,
		MinY = minY,
		Width = Tracks.ById[id].Width,
	}
	cache[id] = geometry
	return geometry
end

-- Naechster Streckenpunkt; mit hint nur in einem Fenster um den letzten Punkt suchen
function Tracks.Nearest(geometry: Geometry, position: Vector3, hint: number?, back: number?, ahead: number?): (number, number)
	local best, bestDist = 1, math.huge
	local count = geometry.Count
	if hint then
		for offset = -(back or 12), ahead or 30 do
			local i = (hint - 1 + offset) % count + 1
			local d = (geometry.Points[i] - position).Magnitude
			if d < bestDist then
				best, bestDist = i, d
			end
		end
		if bestDist < geometry.Width * 1.5 then
			return best, bestDist
		end
	end
	for i = 1, count do
		local d = (geometry.Points[i] - position).Magnitude
		if d < bestDist then
			best, bestDist = i, d
		end
	end
	return best, bestDist
end

-- Position auf der Strecke fuer eine Distanz (Studs ab Start) und seitlichen Versatz (-1..1)
function Tracks.PointAt(geometry: Geometry, distance: number, lateral: number): (Vector3, Vector3)
	local count = geometry.Count
	local f = (distance / geometry.Length) * count
	local i0 = math.floor(f)
	local alpha = f - i0
	local a = (i0 % count) + 1
	local b = (a % count) + 1
	local pos = geometry.Points[a]:Lerp(geometry.Points[b], alpha)
	local right = geometry.Rights[a]:Lerp(geometry.Rights[b], alpha)
	local tangent = geometry.Tangents[a]:Lerp(geometry.Tangents[b], alpha).Unit
	return pos + right * lateral * geometry.Width * 0.5, tangent
end

return Tracks
