-- Startpunkt des Clients: eigene Surf-Steuerung und Kamera, danach das HUD und die Extras (Update 2).
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
ReplicatedStorage:WaitForChild("Shared")

-- Fehlersuche: Fehler und Warnungen an den Server melden (er speichert sie fuer die Entwickler)
local clientLog = remotes:WaitForChild("ClientLog", 10)
local function report(text: string)
	if clientLog then
		clientLog:FireServer(text)
	end
end
ScriptContext.Error:Connect(function(message, trace)
	report("ERROR " .. message .. " | " .. string.gsub(trace or "", "\n", " / "))
end)
LogService.MessageOut:Connect(function(message, kind)
	if kind == Enum.MessageType.MessageWarning or kind == Enum.MessageType.MessageError then
		report("LOG " .. kind.Name .. " " .. message)
	end
end)

local Movement = require(script.Movement)
local UI = require(script.UI)
local Extras = require(script.Extras)
local WarsClient = require(script.WarsClient)
local Update3 = require(script.Update3)

local ok, err = pcall(Movement.Start)
if not ok then
	report("ERROR Movement.Start " .. tostring(err))
end
ok, err = pcall(UI.Start, Movement)
if not ok then
	report("ERROR UI.Start " .. tostring(err))
end
ok, err = pcall(Extras.Start, UI, Movement)
if not ok then
	report("ERROR Extras.Start " .. tostring(err))
end
ok, err = pcall(WarsClient.Start, UI, Movement)
if not ok then
	report("ERROR WarsClient.Start " .. tostring(err))
end
ok, err = pcall(Update3.Start, UI, Movement)
if not ok then
	report("ERROR Update3.Start " .. tostring(err))
end

-- Zustand der ersten Minute: wo ist der Spieler, laeuft die Steuerung?
task.spawn(function()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	for i = 1, 20 do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		report(string.format("STATE t=%d stage=%s root=%s state=%s cam=%s camPos=%s map=%s zones=%s touch=%s", i * 3, tostring(player:GetAttribute("Stage")),
			if root then tostring(root.Position) else "nil", tostring(Movement.DebugPosition and Movement.DebugPosition()), camera.CameraType.Name, tostring(camera.CFrame.Position),
			tostring(workspace:FindFirstChild("Map") ~= nil), tostring(workspace:FindFirstChild("Zones") ~= nil), tostring(game:GetService("UserInputService").TouchEnabled)))
		task.wait(3)
	end
end)
