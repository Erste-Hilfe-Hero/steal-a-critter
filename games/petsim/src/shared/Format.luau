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

function Format.Coins(n: number): string
	return Format.Number(n) .. " coins"
end

function Format.Percent(p: number): string
	if p >= 10 then
		return string.format("%.0f%%", p)
	elseif p >= 1 then
		return string.format("%.1f%%", p)
	end
	return (string.format("%.3f", p):gsub("0+$", "")) .. "%"
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
