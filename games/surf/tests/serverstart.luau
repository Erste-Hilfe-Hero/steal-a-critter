-- Startet den Server genau wie init.server.luau (Init, Build, Start) und meldet jeden Fehler.
local folder = game:GetService("ServerScriptService"):WaitForChild("Server")
local out = {}
local failed = 0
local function add(ok, text)
	if not ok then failed += 1 end
	table.insert(out, (if ok then "PASS " else "FAIL ") .. text)
end
local Services = {}
local names = {}
for _, module in folder.Services:GetChildren() do
	local ok, result = pcall(require, module)
	add(ok, "require " .. module.Name .. (if ok then "" else " " .. tostring(result)))
	if ok then Services[module.Name] = result end
end
local source = folder.Source
local order = {}
for name in string.gmatch(string.match(source, "local ORDER = (%b{})") or "", '"(%w+)"') do
	table.insert(order, name)
end
add(#order > 0, "order " .. table.concat(order, ","))
for _, name in order do
	local ok, err = pcall(function() Services[name]:Init(Services) end)
	add(ok, "init " .. name .. (if ok then "" else " " .. tostring(err)))
end
local okBuild, errBuild = pcall(function() Services.WorldService:Build() end)
add(okBuild, "build" .. (if okBuild then "" else " " .. tostring(errBuild)))
for _, name in order do
	if Services[name].Start then
		local ok, err = pcall(function() Services[name]:Start() end)
		add(ok, "start " .. name .. (if ok then "" else " " .. tostring(err)))
	end
end
table.insert(out, 1, `SUMMARY: {failed} failed of {#out}`)
return table.concat(out, "\n")
