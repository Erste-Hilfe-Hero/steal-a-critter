local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

function Format.Number(n: number): string
	n = math.floor(n)
	if math.abs(n) < 10000 then
		-- 1,234 statt 1.2K, damit kleine Betraege genau bleiben
		local text = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return (if n < 0 then "-" else "") .. text
	end
	local index = 1
	local value = n
	while math.abs(value) >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text = string.format(if math.abs(value) < 100 then "%.1f" else "%.0f", value)
	text = text:gsub("%.0$", "")
	return text .. SUFFIXES[index]
end

-- Laufzeit wie auf CS-Surf-Servern: 1:23.456 bzw. 12.345
function Format.Run(seconds: number?): string
	if not seconds or seconds <= 0 then
		return "--:--.---"
	end
	local ms = math.floor(seconds * 1000 + 0.5)
	local minutes = ms // 60000
	local rest = (ms % 60000) / 1000
	if minutes > 0 then
		return string.format("%d:%06.3f", minutes, rest)
	end
	return string.format("%.3f", rest)
end

function Format.Clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Format
