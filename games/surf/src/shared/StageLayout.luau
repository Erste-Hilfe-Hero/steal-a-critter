-- Geometrie jeder Stage als reine Daten (ohne Roblox-Instanzen): WorldService baut daraus die Map,
-- tests/stages.luau laesst damit einen Bot jede Stage abfahren. Gleicher Seed = immer gleiche Bahn.
local StageLayout = {}

-- Kleiner eigener Zufallsgenerator (Random gibt es im luau-CLI-Test nicht)
local function rng(seed: number)
	local state = seed * 7919 + 13
	return function(min: number, max: number): number
		state = (state * 1103515245 + 12345) % 2147483648
		return min + (state / 2147483648) * (max - min)
	end
end

-- def: Eintrag aus Config.Stages. Rueckgabe:
--   StartCenter (Oberkante Mitte), StartSize, Spawn (Position), Ramps = { { Ridge, Length, Width, Height, Pitch, RidgeEnd } },
--   FinishCenter (Oberkante Mitte), FinishSize, KillY, Random (fuer Deko)
function StageLayout.Build(index: number, def, spacing: number, topY: number)
	local random = rng(def.Seed)
	local laneZ = (index - 1) * spacing
	local layout = {
		LaneZ = laneZ,
		StartCenter = Vector3.new(-20, topY, laneZ),
		StartSize = Vector3.new(40, 4, 24),
		Ramps = {},
		Random = random,
	}
	layout.Spawn = layout.StartCenter + Vector3.new(-12, 3.2, 0)

	-- Erste Rampe so versetzt, dass die Plattform ueber der linken Schraege liegt
	local ridge = Vector3.new(6, topY - 9, laneZ + def.Width / 4)
	local lowest = topY
	for i = 1, def.Ramps do
		local length = def.Length * random(0.9, 1.1)
		local width = def.Width * random(0.95, 1.05)
		local pitch = def.Pitch + random(-1, 1)
		local p = math.rad(pitch)
		local ridgeEnd = ridge + Vector3.new(length * math.cos(p), -length * math.sin(p), 0)
		table.insert(layout.Ramps, { Ridge = ridge, RidgeEnd = ridgeEnd, Length = length, Width = width, Height = def.Height, Pitch = pitch })
		lowest = math.min(lowest, ridgeEnd.Y - def.Height)
		if i < def.Ramps then
			local gap = random(def.Gap[1], def.Gap[2])
			local drop = def.Height * random(def.Drop[1], def.Drop[2]) + 3
			local shift = random(def.Shift[1], def.Shift[2])
			-- Seitlich hin und her, aber nie weit aus der Bahn
			local offset = ridgeEnd.Z - laneZ
			local direction = if math.abs(offset) > 40 then -math.sign(offset) else (if random(0, 1) < 0.5 then -1 else 1)
			ridge = Vector3.new(ridgeEnd.X + gap, ridgeEnd.Y - drop, ridgeEnd.Z + direction * shift)
		else
			ridge = ridgeEnd
		end
	end

	layout.FinishSize = Vector3.new(140, 6, 170)
	layout.FinishCenter = Vector3.new(ridge.X + def.Gap[1] + 70, ridge.Y - def.Height - 6, ridge.Z)
	lowest = math.min(lowest, layout.FinishCenter.Y)
	layout.KillY = lowest - 60
	return layout
end

return StageLayout
