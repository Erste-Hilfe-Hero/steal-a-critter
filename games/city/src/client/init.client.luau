-- Client: Effekte, Fahrsteuerung, HUD und Tags im Chat.
local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Effects = require(script.Effects)
local Drive = require(script.Drive)
local UI = require(script.UI)

Effects.Start()
Drive.Start()
UI.Start()

local TEAM_TAGS = {
	Police = '<font color="#3C82FF">[COP]</font>',
	Robbers = '<font color="#FF4646">[ROBBER]</font>',
}

-- Team-, Rang- und VIP-Tag im Chat (Status sichtbar fuer alle = Werbung fuer den Pass)
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
		-- Titel aus Erfolgen (feste Texte aus Config, kein Spielertext)
		local title = sender:GetAttribute("Title")
		if typeof(title) == "string" and title ~= "" then
			prefix = `<font color="#FFE14D">«{title}»</font> {prefix}`
		end
		local teamTag = sender.Team and TEAM_TAGS[sender.Team.Name]
		if teamTag then
			prefix = `{teamTag} {prefix}`
		end
		if sender:GetAttribute("Pass_VIP") then
			prefix = `<font color="#FFC828">[VIP]</font> {prefix}`
		end
		properties.PrefixText = prefix
	end
	return properties
end
