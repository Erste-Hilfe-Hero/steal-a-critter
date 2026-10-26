-- Client: HUD, Shop, eigene Klau-Prompts ausblenden, VIP-Chat-Tag.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local UI = require(script.UI)
local Hub = require(script.Hub)
local Features = require(script.Features)
local Extras = require(script.Extras)

local player = Players.LocalPlayer

UI.Start()
local hubApi = Hub.Start(UI.Toast)
Features.Start(hubApi)
Extras.Start(hubApi)

-- Eigene Kreaturen kann man nicht klauen: Prompt lokal ausblenden.
-- Mit Fast-Steal-Pass ist die Haltezeit kuerzer, bei Rache fast sofort (der Server prueft das ebenfalls).
-- Den Fusions- und Verkaufs-Prompt sieht dagegen nur der Besitzer.
local stealPrompts = setmetatable({}, { __mode = "k" })

local function isOwn(prompt: ProximityPrompt): boolean
	return prompt:GetAttribute("OwnerUserId") == player.UserId
end

local function hidden(prompt: ProximityPrompt): boolean
	return if prompt.Name == "FusePrompt" or prompt.Name == "SellPrompt" then not isOwn(prompt) else isOwn(prompt)
end

local function applyPrompt(prompt: ProximityPrompt)
	if hidden(prompt) then
		prompt.Enabled = false
	end
	if prompt.Name ~= "StealPrompt" then
		return
	end
	local avenging = prompt:GetAttribute("OwnerUserId") == player:GetAttribute("RevengeTargetId")
		and workspace:GetServerTimeNow() < (player:GetAttribute("RevengeUntil") or 0)
	local bonus = tonumber(player:GetAttribute("StealHoldBonus")) or 0
	prompt.HoldDuration = if avenging then Config.RevengeHoldTime
		elseif player:GetAttribute("Pass_FastSteal") then math.max(0.4, Config.FastStealHoldTime - bonus)
		else math.max(0.4, Config.StealHoldTime - bonus)
end

local function refreshPrompts()
	for prompt in stealPrompts do
		applyPrompt(prompt)
	end
end

local function setupPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") or (prompt.Name ~= "StealPrompt" and prompt.Name ~= "FusePrompt" and prompt.Name ~= "SellPrompt") then
		return
	end
	stealPrompts[prompt] = true
	applyPrompt(prompt)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled and hidden(prompt) then
			prompt.Enabled = false
		end
	end)
end

player:GetAttributeChangedSignal("Pass_FastSteal"):Connect(refreshPrompts)
player:GetAttributeChangedSignal("StealHoldBonus"):Connect(refreshPrompts)
player:GetAttributeChangedSignal("RevengeUntil"):Connect(function()
	refreshPrompts()
	-- Nach Ablauf der Rache wieder normale Haltezeit
	task.delay(Config.RevengeDuration + 0.5, refreshPrompts)
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

-- Farbverlaeufe der Namensschilder schimmern lassen, Regenbogen-Kreaturen wechseln die Farbe
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local offset = (now * 0.4) % 2 - 1
	for _, ui in CollectionService:GetTagged("Shimmer") do
		(ui :: UIGradient).Offset = Vector2.new(offset, 0)
	end
	local hue = (now * 0.25) % 1
	for _, part in CollectionService:GetTagged("RainbowCritter") do
		(part :: BasePart).Color = Color3.fromHSV(hue, 0.8, 1)
	end
	-- Lauflicht auf dem Laufband (in Laufrichtung)
	for _, arrow in CollectionService:GetTagged("BeltArrow") do
		local wave = ((arrow:GetAttribute("Phase") or 0) * 0.25 - now * 1.5) % 1
		(arrow :: BasePart).Transparency = 0.15 + wave * 0.75
	end
end)

-- Deko-Kristalle drehen sich langsam und schweben (nur lokal, kostet den Server nichts)
local spinBase = setmetatable({}, { __mode = "k" })
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, part in CollectionService:GetTagged("Spin") do
		local base = spinBase[part]
		if not base then
			base = (part :: BasePart).CFrame
			spinBase[part] = base
		end
		(part :: BasePart).CFrame = CFrame.new(base.Position + Vector3.new(0, math.sin(now + base.Position.X) * 1.5, 0))
			* CFrame.Angles(0, now * 0.6, 0)
			* base.Rotation
	end
end)

-- Favoriten-Abfrage nach ein paar Minuten Spielzeit (Favoriten sehen Updates und finden das Spiel wieder).
-- Nur einmal pro Sitzung und nur, wenn das Spiel noch nicht favorisiert ist.
task.delay(Config.FavoritePromptAfter, function()
	local AvatarEditorService = game:GetService("AvatarEditorService")
	local ok, isFavorite = pcall(AvatarEditorService.GetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset)
	if ok and isFavorite then
		return
	end
	pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, game.PlaceId, Enum.AvatarItemType.Asset, true)
end)
