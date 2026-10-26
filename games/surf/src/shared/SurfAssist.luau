-- Surf-Hilfe (vor allem fuers Handy): drueckt auf der Rampe automatisch in die Rampe und lenkt in der Luft
-- zur naechsten Rampe. Dieselbe Logik faehrt im Test (tests/stages.luau) alle Stages ab.
local SurfAssist = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- layout: StageLayout.Build(...). slope: Normale der Rampe, wenn man sie gerade beruehrt (sonst nil).
-- Rueckgabe: WishDir, WishAmount (0 = nichts tun, z. B. noch auf der Startplattform)
function SurfAssist.Wish(layout, position: Vector3, velocity: Vector3, grounded: boolean, slope: Vector3?): (Vector3, number)
	local _ = grounded
	if slope then
		-- Auf der Rampe: waagerecht in die Rampe druecken
		-- Alle Rampen laufen entlang +X: quer dazu (Z) in die Schraege druecken, nicht nach hinten
		return Vector3.new(0, 0, if slope.Z < 0 then 1 else -1), 1
	end
	-- In der Luft: zur ersten Rampe, deren Ende noch vor einem liegt, sonst zum Ziel
	local target
	for _, r in layout.Ramps do
		if r.RidgeEnd.X > position.X - 1 then
			target = r
			break
		end
	end
	local goal
	if target then
		local side = if position.Z >= target.Ridge.Z then 1 else -1
		goal = Vector3.new(math.max(target.Ridge.X + 25, position.X + 40), 0, target.Ridge.Z + side * target.Width * 0.25)
	else
		goal = Vector3.new(layout.FinishCenter.X, 0, layout.FinishCenter.Z)
	end
	local v = flat(velocity)
	local h = flat(goal - position)
	if v.Magnitude > 1 and h.Magnitude > 1 then
		v, h = v.Unit, h.Unit
		-- Luft-Strafe: senkrecht zur Flugrichtung, zur Zielseite hin (so dreht man ohne Tempo zu verlieren)
		local perp = Vector3.new(-v.Z, 0, v.X)
		if perp:Dot(h) < 0 then
			perp = -perp
		end
		if v:Dot(h) < math.cos(math.rad(2)) then
			return perp, 1
		end
	end
	return Vector3.new(0, 0, 0), 0
end

return SurfAssist
