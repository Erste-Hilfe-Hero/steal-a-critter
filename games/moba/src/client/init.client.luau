-- Client: HUD, Kamera, Lebensbalken, Effekte und VIP-Tag im Chat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Bars = require(script.Bars)
local CameraController = require(script.CameraController)
local Fx = require(script.Fx)
local UI = require(script.UI)

local remotes = ReplicatedStorage:WaitForChild("Remotes")

Fx.Start()
Bars.Start()
CameraController.Start()
UI.Start()

remotes.Fx.OnClientEvent:Connect(Fx.Handle)
remotes.Damage.OnClientEvent:Connect(Fx.Number)

-- VIP- und Team-Tag im Chat (VIP sichtbar fuer alle = Werbung fuer den Pass)
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender then
		local prefix = message.PrefixText
		local team = sender:GetAttribute("Team")
		if team == 1 then
			prefix = `<font color="#FFB840">[Dawn]</font> {prefix}`
		elseif team == 2 then
			prefix = `<font color="#966EFF">[Dusk]</font> {prefix}`
		end
		if sender:GetAttribute("VIP") then
			prefix = `<font color="#FFC94A">[VIP]</font> {prefix}`
		end
		properties.PrefixText = prefix
	end
	return properties
end
