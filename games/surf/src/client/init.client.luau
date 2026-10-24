-- Startpunkt des Clients: eigene Surf-Steuerung und Kamera, danach das HUD.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

ReplicatedStorage:WaitForChild("Remotes")
ReplicatedStorage:WaitForChild("Shared")

local Movement = require(script.Movement)
local UI = require(script.UI)

Movement.Start()
UI.Start(Movement)
