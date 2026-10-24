-- Client: Kamera, Effekte, HUD, Rang- und VIP-Tags im Chat, schimmernde Namensschilder.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Camera = require(script.Camera)
local Effects = require(script.Effects)
local UI = require(script.UI)

-- Kein Roblox-Rucksack: die Waffe gibt der Server, das Inventar ist unser eigenes
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false)
		if ok then
			break
		end
		task.wait(0.5)
	end
end)

Camera.Start()
Effects.Start()
UI.Start()

-- Rang- und VIP-Tag im Chat (Status sichtbar fuer alle = Werbung fuer den Pass)
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender then
		local prefix = message.PrefixText
		local rank = sender:GetAttribute("Rank")
		if rank and rank ~= "Newbie" then
			prefix = `<font color="{sender:GetAttribute("RankColor") or "#FFFFFF"}">[{rank}]</font> {prefix}`
		end
		if sender:GetAttribute("Pass_VIP") then
			prefix = `<font color="#FFC828">[VIP]</font> {prefix}`
		end
		prefix = `<font color="#A8AAC6">[Lv {sender:GetAttribute("Level") or 1}]</font> {prefix}`
		properties.PrefixText = prefix
	end
	return properties
end

-- Farbverlaeufe der Namensschilder schimmern lassen
RunService.RenderStepped:Connect(function()
	local offset = (os.clock() * 0.4) % 2 - 1
	for _, ui in CollectionService:GetTagged("Shimmer") do
		(ui :: UIGradient).Offset = Vector2.new(offset, 0)
	end
end)
