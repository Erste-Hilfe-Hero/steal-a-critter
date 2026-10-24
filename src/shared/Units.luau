-- Kreaturen werden als Text gespeichert: "id", "id:Mutation" oder "id:Mutation:Fusion".
-- Alte Spielstaende ("blobby") bleiben dadurch gueltig.
local Config = require(script.Parent.Config)

local Units = {}

local mutationsByName = {}
for _, mutation in Config.Mutations do
	mutationsByName[mutation.Name] = mutation
end
Units.MutationsByName = mutationsByName

function Units.Encode(id: string, mutation: string?, fusion: number?): string
	fusion = fusion or 0
	if (mutation == nil or mutation == "") and fusion == 0 then
		return id
	end
	return `{id}:{mutation or ""}:{fusion}`
end

-- Liefert alle Werte einer Kreatur oder nil, wenn der Code ungueltig ist
function Units.Info(code: string?)
	if type(code) ~= "string" then
		return nil
	end
	local id, mutation, fusion = code:match("^([^:]+):?([^:]*):?(%d*)$")
	local def = id and Config.UnitsById[id]
	if not def then
		return nil
	end
	local mut = mutationsByName[mutation or ""]
	local level = math.clamp(tonumber(fusion) or 0, 0, Config.MaxFusion)
	local multiplier = (if mut then mut.Multiplier else 1) * Config.FusionMultiplier ^ level
	local prefix = (if mut then mut.Name .. " " else "")
	local suffix = if level > 0 then " " .. string.rep("★", level) else ""
	return {
		Code = Units.Encode(def.Id, mut and mut.Name, level),
		Def = def,
		Id = def.Id,
		Rarity = def.Rarity,
		Mutation = mut,
		Fusion = level,
		Name = prefix .. def.Name .. suffix,
		Income = def.Income * multiplier,
		Price = def.Price * (if mut then mut.Multiplier * 0.8 else 1),
		Value = def.Price * multiplier,
		Scale = Config.RaritiesByName[def.Rarity].Scale * (1 + 0.25 * level),
	}
end

return Units
