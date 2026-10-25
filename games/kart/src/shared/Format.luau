local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

function Format.Number(n: number): string
	n = math.floor(n)
	if math.abs(n) < 1000 then
		return tostring(n)
	end
	local index = 1
	local value = n
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text = string.format(if math.abs(value) < 10 then "%.2f" elseif math.abs(value) < 100 then "%.1f" else "%.0f", value)
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end
	return text .. SUFFIXES[index]
end

function Format.Cash(n: number): string
	return "$" .. Format.Number(n)
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Rennzeit mit Hundertsteln, z. B. 1:23.45
function Format.RaceTime(seconds: number): string
	seconds = math.max(0, seconds)
	local whole = math.floor(seconds)
	local hundredths = math.floor((seconds - whole) * 100)
	return string.format("%d:%02d.%02d", whole // 60, whole % 60, hundredths)
end

return Format
