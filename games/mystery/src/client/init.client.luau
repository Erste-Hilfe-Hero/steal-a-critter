-- Startpunkt des Clients: Effekte, Steuerung und Oberflaeche.
local StarterGui = game:GetService("StarterGui")

local Effects = require(script.Effects)
local Controls = require(script.Controls)
local UI = require(script.UI)

Effects.Start()
Controls.Start()
UI.Start()

-- Rollen sind geheim: keine Spielerliste mit Teams, aber Rucksack (Messer/Blaster) und Chat bleiben
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.PlayerList, false)
		if ok then
			break
		end
		task.wait(1)
	end
end)
