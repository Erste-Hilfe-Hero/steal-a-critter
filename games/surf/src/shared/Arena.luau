-- "Snowball Wars": Team-Modus wie auf CS-Surf-Kampfmaps. Zwei Teams starten an den Enden einer Arena,
-- surfen ueber Rampen zum Platz in der Mitte und bewerfen sich mit Schneebaellen und Eis-Waffen,
-- die auf der Map liegen. Ein Treffer nimmt Kaelte-Punkte; bei 0 friert man ein (Eisblock) und
-- startet an der eigenen Basis neu. Keine echten Waffen, kein Blut (Mild 9+).
-- Reine Daten: Server (ArenaService), Client (WarsClient) und Tests benutzen dieselbe Geometrie.
local Arena = {}

Arena.Center = Vector3.new(0, 1100, -3200) -- X muss 0 bleiben: die zweite Haelfte ist an X = 0 gespiegelt
Arena.MaxHealth = 100
Arena.RoundSeconds = 240
Arena.WinScore = 25
Arena.CountdownSeconds = 5
Arena.EndSeconds = 8
Arena.FrozenSeconds = 2.5
Arena.ShieldSeconds = 2.5 -- Schutz nach dem Neustart an der Basis
Arena.RegenDelay = 4
Arena.RegenPerSecond = 8
Arena.PickupRadius = 8
Arena.BotsPerTeam = 3 -- Teams werden mit Bots aufgefuellt, solange echte Spieler in der Arena sind
Arena.Rewards = { Freeze = 15, Win = 200, Play = 60 }

Arena.Teams = {
	{ Id = "Frost", Name = "Team Frost", Color = Color3.fromRGB(92, 200, 255), Dark = Color3.fromRGB(30, 80, 150), Side = -1 },
	{ Id = "Aurora", Name = "Team Aurora", Color = Color3.fromRGB(255, 90, 170), Dark = Color3.fromRGB(140, 30, 95), Side = 1 },
}
Arena.TeamById = {}
for _, team in Arena.Teams do
	Arena.TeamById[team.Id] = team
end

-- Waffen. Kind: Projectile (fliegt mit Schwerkraft), Hitscan (sofort), Spread (mehrere Strahlen).
Arena.Weapons = {
	Snowball = { Name = "Snowball", Kind = "Projectile", Damage = 34, Cooldown = 0.45, Speed = 170, Gravity = 55, Range = 400, Ammo = 0, Knock = 18, Color = Color3.fromRGB(245, 250, 255), Sound = "sfx_throw", Order = 1 },
	IceBlaster = { Name = "Ice Blaster", Kind = "Hitscan", Damage = 18, Cooldown = 0.14, Range = 260, Ammo = 40, Knock = 6, Color = Color3.fromRGB(92, 225, 255), Sound = "sfx_zap", Order = 2 },
	SnowCannon = { Name = "Snow Cannon", Kind = "Spread", Damage = 14, Pellets = 7, Spread = 6, Cooldown = 0.85, Range = 95, Ammo = 10, Knock = 6, Color = Color3.fromRGB(200, 235, 255), Sound = "sfx_throw", Order = 3 },
	FrostSniper = { Name = "Frost Sniper", Kind = "Hitscan", Damage = 90, Cooldown = 1.4, Range = 800, Ammo = 6, Knock = 40, Color = Color3.fromRGB(190, 120, 255), Sound = "sfx_zap", Order = 4 },
	SlushBomb = { Name = "Slush Bomb", Kind = "Projectile", Damage = 70, Splash = 14, Cooldown = 1.0, Speed = 115, Gravity = 85, Range = 300, Ammo = 3, Knock = 55, Color = Color3.fromRGB(110, 255, 190), Sound = "sfx_throw", Order = 5 },
}

-- Geometrie der Frost-Haelfte (Fahrt in +X). Aurora ist dieselbe Haelfte an X = 0 gespiegelt.
local RAMP = { Width = 40, Height = 30, Length = 100, Pitch = 11, Gap = 20, Shift = 12 }

local function buildHalf()
	local c = Arena.Center
	local baseTop = c.Y + 60
	local p = math.rad(RAMP.Pitch)
	local step = RAMP.Length * math.cos(p)
	-- Basis so weit links, dass die dritte Rampe bei X = -75 endet
	local baseX = -75 - (26 + 3 * step + 2 * RAMP.Gap)
	local layout = {
		StartCenter = Vector3.new(baseX, baseTop, c.Z),
		StartSize = Vector3.new(50, 4, 70),
		Ramps = {},
	}
	layout.Spawn = layout.StartCenter + Vector3.new(-14, 3.2, 0)
	local ridge = Vector3.new(baseX + 26, baseTop - 9, c.Z + RAMP.Width / 4)
	local direction = -1
	for i = 1, 3 do
		local ridgeEnd = ridge + Vector3.new(step, -RAMP.Length * math.sin(p), 0)
		table.insert(layout.Ramps, { Ridge = ridge, RidgeEnd = ridgeEnd, Length = RAMP.Length, Width = RAMP.Width, Height = RAMP.Height, Pitch = RAMP.Pitch })
		if i < 3 then
			ridge = Vector3.new(ridgeEnd.X + RAMP.Gap, ridgeEnd.Y - (RAMP.Height + 3), ridgeEnd.Z + direction * RAMP.Shift)
			direction = -direction
		else
			ridge = ridgeEnd
		end
	end
	local plazaTop = ridge.Y - RAMP.Height - 6
	layout.FinishCenter = Vector3.new(0, plazaTop, c.Z)
	layout.FinishSize = Vector3.new(2 * (-ridge.X - 18), 6, 150)
	layout.KillY = plazaTop - 70
	return layout
end

Arena.Half = buildHalf()
Arena.PlazaTop = Arena.Half.FinishCenter.Y
Arena.KillY = Arena.Half.KillY

-- Spiegeln: Positionen und Richtungen an X = 0
function Arena.Mirror(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Y, v.Z)
end

function Arena.Spawn(teamId: string): CFrame
	local team = Arena.TeamById[teamId]
	local spawn = Arena.Half.Spawn
	if team and team.Side > 0 then
		spawn = Arena.Mirror(spawn)
	end
	local toward = Vector3.new(0, spawn.Y, spawn.Z)
	return CFrame.lookAt(spawn, toward)
end

-- Rueckweg-Platten auf dem Platz (zur eigenen Basis)
function Arena.Pad(teamId: string): Vector3
	local team = Arena.TeamById[teamId]
	local x = -Arena.Half.FinishSize.X / 2 + 9
	return Vector3.new(if team and team.Side > 0 then -x else x, Arena.PlazaTop, Arena.Center.Z)
end

-- Deckung auf dem Platz (Schneewaende und Iglus): { Center (Boden), Size }
Arena.Cover = {
	{ Center = Vector3.new(-22, 0, -32), Size = Vector3.new(4, 7, 18) },
	{ Center = Vector3.new(22, 0, 32), Size = Vector3.new(4, 7, 18) },
	{ Center = Vector3.new(-22, 0, 38), Size = Vector3.new(14, 6, 4) },
	{ Center = Vector3.new(22, 0, -38), Size = Vector3.new(14, 6, 4) },
}

-- Wo Waffen liegen (relativ zu Center bzw. Platz). Respawn in Sekunden.
local function plaza(x: number, z: number, height: number?): Vector3
	return Vector3.new(x, Arena.PlazaTop + (height or 3.5), Arena.Center.Z + z)
end
local half = Arena.Half
local gap1 = half.Ramps[1].RidgeEnd
local gap2 = half.Ramps[2].RidgeEnd
Arena.Pickups = {
	{ Weapon = "FrostSniper", Position = plaza(0, 0, 6), Respawn = 25 },
	{ Weapon = "SnowCannon", Position = plaza(0, -50), Respawn = 15 },
	{ Weapon = "SnowCannon", Position = plaza(0, 50), Respawn = 15 },
	{ Weapon = "SlushBomb", Position = plaza(-30, 12), Respawn = 18 },
	{ Weapon = "SlushBomb", Position = plaza(30, -12), Respawn = 18 },
	{ Weapon = "IceBlaster", Position = half.StartCenter + Vector3.new(4, 3.5, 24), Respawn = 12 },
	{ Weapon = "IceBlaster", Position = Arena.Mirror(half.StartCenter + Vector3.new(4, 3.5, -24)), Respawn = 12 },
	-- In der Luft zwischen zwei Rampen: im Flug einsammeln
	{ Weapon = "IceBlaster", Position = gap1 + Vector3.new(10, -12, 0), Respawn = 12 },
	{ Weapon = "IceBlaster", Position = Arena.Mirror(gap1 + Vector3.new(10, -12, 0)), Respawn = 12 },
	{ Weapon = "SnowCannon", Position = gap2 + Vector3.new(10, -12, 0), Respawn = 15 },
	{ Weapon = "SnowCannon", Position = Arena.Mirror(gap2 + Vector3.new(10, -12, 0)), Respawn = 15 },
}

-- Treffer-Kugel um die Figur (Mitte = HumanoidRootPart)
Arena.HitRadius = 3

-- Strahl gegen Kugel: Abstand entlang des Strahls oder nil
function Arena.RaySphere(origin: Vector3, direction: Vector3, center: Vector3, radius: number): number?
	local toCenter = center - origin
	local along = toCenter:Dot(direction)
	if along < 0 then
		return nil
	end
	local closest = toCenter - direction * along
	if closest.Magnitude > radius then
		return nil
	end
	return along - math.sqrt(math.max(0, radius * radius - closest.Magnitude ^ 2))
end

-- Richtung eines Schrot-Strahls (deterministisch aus Index, damit Client und Server gleich rechnen)
function Arena.SpreadDirection(direction: Vector3, index: number, pellets: number, degrees: number): Vector3
	if index == 1 then
		return direction
	end
	local angle = (index - 2) / (pellets - 1) * math.pi * 2
	local up = if math.abs(direction.Y) > 0.95 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local right = direction:Cross(up).Unit
	local realUp = right:Cross(direction).Unit
	local spread = math.tan(math.rad(degrees))
	return (direction + (right * math.cos(angle) + realUp * math.sin(angle)) * spread).Unit
end

return Arena
