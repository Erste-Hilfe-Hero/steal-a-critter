-- Client: HUD, Shop, eigene Klau-Prompts ausblenden, VIP-Chat-Tag.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local UI = require(script.UI)

local player = Players.LocalPlayer

UI.Start()

-- Eigene Kreaturen kann man nicht klauen: Prompt lokal ausblenden.
-- Mit Fast-Steal-Pass ist die Haltezeit kuerzer (der Server prueft das ebenfalls).
local stealPrompts = setmetatable({}, { __mode = "k" })

local function applyPrompt(prompt: ProximityPrompt)
	if prompt:GetAttribute("OwnerUserId") == player.UserId then
		prompt.Enabled = false
	end
	prompt.HoldDuration = if player:GetAttribute("Pass_FastSteal") then Config.FastStealHoldTime else Config.StealHoldTime
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or prompt.Name ~= "StealPrompt" then
		return
	end
	stealPrompts[prompt] = true
	applyPrompt(prompt)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled and prompt:GetAttribute("OwnerUserId") == player.UserId then
			prompt.Enabled = false
		end
	end)
end

player:GetAttributeChangedSignal("Pass_FastSteal"):Connect(function()
	for prompt in stealPrompts do
		applyPrompt(prompt)
	end
end)

for _, descendant in workspace:GetDescendants() do
	setupPrompt(descendant)
end
workspace.DescendantAdded:Connect(setupPrompt)

-- VIP-Tag im Chat (Status sichtbar fuer alle = Werbung fuer den Gamepass)
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
