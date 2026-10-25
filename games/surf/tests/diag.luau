-- Diagnose: Inhalt des veroeffentlichten Place und kompletter Server-Start wie init.server.luau
local out = {}
local function add(s) table.insert(out, tostring(s)) end
add("SUMMARY: 0 failed of 0")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local function tree(inst, depth, prefix)
	for _, c in inst:GetChildren() do
		add(prefix .. c.ClassName .. " " .. c.Name)
		if depth > 1 then tree(c, depth - 1, prefix .. "  ") end
	end
end
add("== workspace (before)") tree(workspace, 1, " ")
add("== ServerScriptService") tree(ServerScriptService, 3, " ")
add("== ReplicatedStorage") tree(ReplicatedStorage, 2, " ")
add("== StarterPlayer") tree(StarterPlayer, 3, " ")
add("== ReplicatedFirst") tree(game:GetService("ReplicatedFirst"), 1, " ")
add("CharacterAutoLoads " .. tostring(game:GetService("Players").CharacterAutoLoads))
local folder = ServerScriptService:FindFirstChild("Server")
local Services = {}
local ok, err = pcall(function()
	for _, name in { "Net", "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "MonetizationService" } do
		Services[name] = require(folder.Services[name])
	end
	local ORDER = { "DataService", "WorldService", "LeaderboardService", "TimerService", "CosmeticService", "MonetizationService" }
	for _, name in ORDER do Services[name]:Init(Services) end
	Services.WorldService:Build()
	for _, name in ORDER do
		if Services[name].Start then
			local ok2, e2 = pcall(Services[name].Start, Services[name])
			add("start " .. name .. " " .. tostring(ok2) .. " " .. tostring(e2))
		end
	end
end)
add("init ok " .. tostring(ok) .. " " .. tostring(err))
local map = workspace:FindFirstChild("Map")
add("map parts " .. (map and #map:GetDescendants() or -1))
local zones = workspace:FindFirstChild("Zones")
if zones then for _, z in zones:GetChildren() do add("zone " .. z.Name .. " " .. tostring(z.Position)) end end
add("lobby spawn " .. tostring(workspace:GetAttribute("LobbySpawn")))
add("stage1 spawn " .. tostring(Services.WorldService and Services.WorldService:GetSpawn(1)))
return table.concat(out, "\n")
