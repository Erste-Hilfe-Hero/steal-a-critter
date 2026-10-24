-- Client: HUD, Haustiere anzeigen, Tore lokal oeffnen, Chancen an den Eiern, VIP- und Rang-Tag im Chat.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local UI = require(script.UI)
local PetFollow = require(script.PetFollow)

local player = Players.LocalPlayer

UI.Start()
PetFollow.Start()

local world = workspace:WaitForChild("World")
local zones = world:WaitForChild("Zones")

-- Freigeschaltete Tore sind nur fuer diesen Spieler offen (der Server prueft die Position nach)
local function refreshGates()
	local unlocked = player:GetAttribute("Zone") or 1
	for index = 2, #Config.Zones do
		local folder = zones:WaitForChild("Zone" .. index)
		local gate = folder:WaitForChild("Gate") :: BasePart
		local open = index <= unlocked
		gate.CanCollide = not open
		gate.Transparency = if open then 0.85 else 0.3
		local sign = folder:WaitForChild("GateSign")
		local prompt = sign:WaitForChild("GatePrompt") :: ProximityPrompt
		prompt.Enabled = index == unlocked + 1
		local billboard = sign:FindFirstChildOfClass("BillboardGui")
		if billboard then
			billboard.Enabled = not open
		end
	end
end
player:GetAttributeChangedSignal("Zone"):Connect(refreshGates)
task.spawn(refreshGates)

-- Chancen an jedem Ei mit dem eigenen Glueck (Pflicht bei Zufallsinhalten: Chancen offen zeigen)
local function refreshOdds()
	local luck = player:GetAttribute("Luck") or 1
	for _, egg in Config.Eggs do
		local folder = zones:FindFirstChild("Zone" .. egg.Zone)
		local eggPart = folder and folder:FindFirstChild("Egg")
		local gui = eggPart and eggPart:FindFirstChild("Odds")
		local label = gui and gui:FindFirstChildOfClass("TextLabel")
		if label then
			local lines = { if luck > 1 then `<b>Chances (luck x{luck})</b>` else "<b>Chances</b>" }
			for _, entry in Config.EggOdds(egg, luck) do
				local def = Config.PetsById[entry.Pet]
				local color = Config.RaritiesByName[def.Rarity].Color:ToHex()
				table.insert(lines, `<font color="#{color}">{def.Name}</font>  {Format.Percent(entry.Chance)}`)
			end
			label.Text = table.concat(lines, "\n")
		end
		local triple = eggPart and eggPart:FindFirstChild("Hatch3Prompt") :: ProximityPrompt?
		if triple then
			-- Ohne Pass bleibt der Prompt sichtbar und oeffnet den Kauf (Werbung fuer den Pass)
			triple.ActionText = if player:GetAttribute("Pass_TripleHatch") then "Hatch x3" else "Hatch x3 (Pass)"
		end
	end
end
player:GetAttributeChangedSignal("Luck"):Connect(refreshOdds)
player:GetAttributeChangedSignal("Pass_TripleHatch"):Connect(refreshOdds)
task.spawn(function()
	zones:WaitForChild("Zone" .. #Config.Zones)
	refreshOdds()
end)

-- VIP- und Rang-Tag im Chat (Status sichtbar fuer alle = Werbung fuer den Pass)
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
