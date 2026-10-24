-- Minimaler Vector3-Ersatz, damit SurfPhysics ausserhalb von Roblox (luau-CLI) getestet werden kann
local V = {}
V.__index = function(v, key)
	if key == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif key == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return V.new(v.X / m, v.Y / m, v.Z / m)
	end
	return V[key]
end
function V.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
function V.__add(a, b)
	return V.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
function V.__sub(a, b)
	return V.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
function V.__mul(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return V.new(a.X * b, a.Y * b, a.Z * b)
end
function V.__div(a, b)
	return V.new(a.X / b, a.Y / b, a.Z / b)
end
function V.__unm(a)
	return V.new(-a.X, -a.Y, -a.Z)
end
function V.Dot(a, b)
	return a.X * b.X + a.Y * b.Y + a.Z * b.Z
end
function V.Cross(a, b)
	return V.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
end
function V.__tostring(v)
	return string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z)
end
V.zero = V.new(0, 0, 0)
return V
