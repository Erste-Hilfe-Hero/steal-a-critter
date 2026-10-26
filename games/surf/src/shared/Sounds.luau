-- IDs der selbst komponierten Musik und Sounds (assets/make_audio.py, hochgeladen von sounds-surf.yml).
-- Solange eine ID 0 ist, bleibt der Sound stumm statt zu fehlen.
local ids = require(script.Parent.SoundIds)

local Sounds = {}

function Sounds.Id(name: string): string
	local id = ids[name]
	if typeof(id) == "number" and id > 0 then
		return "rbxassetid://" .. string.format("%d", id)
	end
	return ""
end

return Sounds
