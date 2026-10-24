-- Sicht und Nebel des Krieges: Helden, Minions, Tuerme und Wards sehen in einem Radius.
-- Waende blockieren die Sicht, Buesche verstecken alles darin (ausser man steht selbst im Busch),
-- Unsichtbare sieht man nur ganz nah, und wer angreift, wird kurz aufgedeckt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local VisionService = { Services = nil :: any }

local TICK = 0.25
local VISION = Config.Vision
local HIDDEN_KINDS = { Hero = true, Minion = true, Ward = true }

local Combat

function VisionService:Init(services)
	self.Services = services
	Combat = services.CombatService
end

local function radiusOf(unit): number
	if unit.Vision then
		return unit.Vision
	end
	if unit.Kind == "Hero" then
		return VISION.Hero
	elseif unit.Kind == "Minion" then
		return VISION.Minion
	elseif unit.Kind == "Tower" then
		return VISION.Tower
	elseif unit.Kind == "Inhibitor" or unit.Kind == "Nexus" then
		return VISION.Structure
	end
	return 0
end

-- Alle Augen eines Teams: Position, Radius, Busch
local function sources(team: number)
	local list = {}
	for _, unit in Combat.Units do
		if unit.Team == team and Combat.Alive(unit) then
			local radius = radiusOf(unit)
			if radius > 0 then
				local position = Combat.Position(unit)
				table.insert(list, { Position = position, Radius = radius, Brush = Config.BrushAt(position) })
			end
		end
	end
	table.insert(list, { Position = Config.Map.Fountain[team], Radius = VISION.Fountain, Brush = nil, Through = true })
	return list
end

function VisionService:CanSee(team: number, unit, eyes): boolean
	local t = workspace:GetServerTimeNow()
	if (unit.RevealUntil[team] or 0) > t then
		return true
	end
	local status = unit.Status
	local position = Combat.Position(unit)
	local stealthed = (status.StealthUntil or 0) > t
	local brush = Config.BrushAt(position)
	local world = self.Services.WorldService
	for _, eye in eyes do
		local distance = (eye.Position - position).Magnitude
		if distance <= eye.Radius + unit.Radius then
			if stealthed and distance > 5 then
				continue
			end
			-- Im Busch nur sichtbar fuer Augen im selben Busch oder ganz nah daneben
			if brush and eye.Brush ~= brush and distance > VISION.BrushReveal then
				continue
			end
			if eye.Through or distance < 4 or world.LineClear(eye.Position, position) then
				return true
			end
		end
	end
	return false
end

function VisionService:Update()
	local eyes = { [1] = sources(1), [2] = sources(2) }
	for _, unit in Combat.Units do
		if not HIDDEN_KINDS[unit.Kind] or unit.Team == 0 then
			continue
		end
		local enemy = if unit.Team == 1 then 2 else 1
		local seen = Combat.Alive(unit) and self:CanSee(enemy, unit, eyes[enemy])
		if unit.SeenBy[enemy] ~= seen then
			unit.SeenBy[enemy] = seen
			if unit.Model then
				unit.Model:SetAttribute("Seen" .. enemy, seen)
			end
			-- Wer nicht mehr gesehen wird, verliert Fokus und Turm-Ziel der Gegner
			if not seen then
				for _, other in Combat.Units do
					if other.Team == enemy and other.Target == unit then
						other.Target = nil
					end
				end
			end
		end
		local stealthed = (unit.Status.StealthUntil or 0) > workspace:GetServerTimeNow()
		if unit.Model and unit.Model:GetAttribute("Stealth") ~= stealthed then
			unit.Model:SetAttribute("Stealth", stealthed)
		end
	end
end

function VisionService:Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		accumulator = 0
		local ok, err = pcall(self.Update, self)
		if not ok then
			warn("[Vision]", err)
		end
	end)
end

return VisionService
