-- Nebel des Krieges auf dem Client: Gegner, die das eigene Team nicht sieht, werden unsichtbar
-- (nur lokal). Eigene unsichtbare Helden erscheinen halb durchsichtig.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Vision = {}

local player = Players.LocalPlayer
local hidden: { [Instance]: number } = {}

local function apply(model: Instance, amount: number)
	if hidden[model] == amount then
		return
	end
	hidden[model] = amount
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") or child:IsA("Decal") then
			child.LocalTransparencyModifier = amount
		elseif child:IsA("BillboardGui") then
			child.Enabled = amount < 1
		elseif child:IsA("Light") then
			child.Enabled = amount < 1
		end
	end
end

-- Ist diese Einheit fuer mein Team sichtbar?
function Vision.Seen(model: Instance): boolean
	local myTeam = player:GetAttribute("Team")
	local team = model:GetAttribute("Team")
	if not myTeam or team == myTeam or team == 0 or team == nil then
		return true
	end
	local seen = model:GetAttribute("Seen" .. tostring(myTeam))
	return seen ~= false
end

function Vision.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		for _, model in CollectionService:GetTagged("Unit") do
			local kind = model:GetAttribute("Kind")
			if kind == "Hero" or kind == "Minion" or kind == "Ward" then
				local amount = 0
				if not Vision.Seen(model) then
					amount = 1
				elseif model:GetAttribute("Stealth") then
					amount = 0.6
				end
				apply(model, amount)
			end
		end
		for model in hidden do
			if not model.Parent then
				hidden[model] = nil
			end
		end
	end)
	-- Neue Teile (z. B. Waffe nach dem Respawn) uebernehmen den Zustand
	CollectionService:GetInstanceAddedSignal("Unit"):Connect(function(model)
		hidden[model] = nil
	end)
end

return Vision
