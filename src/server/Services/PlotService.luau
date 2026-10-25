-- Weist Spielern Basen zu, teleportiert sie dorthin und verwaltet die Basis-Sperre.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local PlotService = { Services = nil :: any }

local playerPlots = {} -- [Player] = plot

function PlotService:Init(services)
	self.Services = services
end

function PlotService:GetPlot(player: Player)
	return playerPlots[player]
end

function PlotService:Assign(player: Player)
	for _, plot in self.Services.WorldService.Plots do
		if plot.Owner == nil then
			plot.Owner = player
			plot.LockedUntil = 0
			plot.LockCooldownUntil = 0
			plot.SignLabel.Text = player.DisplayName .. "'s Base"
			playerPlots[player] = plot
			-- Fuer die Einfuehrung (Pfeil zum eigenen Sperr-Knopf)
			player:SetAttribute("PlotName", plot.Model.Name)
			return plot
		end
	end
	return nil
end

function PlotService:Release(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	plot.Owner = nil
	plot.LockedUntil = 0
	plot.LockCooldownUntil = 0
	-- Gekaufte Basis-Farbe nicht an den naechsten Besitzer vererben
	plot.Accent = plot.DefaultAccent or plot.Accent
	plot.SignLabel.Text = "Empty Base"
	plot.Barrier.Transparency = 1
	plot.LockLabel.Text = "LOCK BASE"
	for _, pad in plot.Pads do
		pad.Color = Color3.fromRGB(110, 105, 100)
		local label = pad:FindFirstChild("PassLabel")
		if label then
			label:Destroy()
		end
	end
	playerPlots[player] = nil
end

function PlotService:IsLocked(player: Player): boolean
	local plot = playerPlots[player]
	return plot ~= nil and plot.LockedUntil > os.clock()
end

function PlotService:Lock(player: Player, seconds: number, paid: boolean): boolean
	local plot = playerPlots[player]
	if not plot then
		return false
	end
	local now = os.clock()
	if not paid and now < plot.LockCooldownUntil then
		self.Services.Net.SendNotify(player, "Lock is recharging! Buy a 5 min lock in the shop.", Color3.fromRGB(255, 170, 60))
		return false
	end
	plot.LockedUntil = math.max(now, plot.LockedUntil) + seconds
	plot.LockCooldownUntil = plot.LockedUntil + Config.LockCooldown
	self.Services.Net.SendNotify(player, `Base locked for {Format.Time(plot.LockedUntil - now)}!`, Color3.fromRGB(90, 220, 120))
	return true
end

-- Faerbt die Slots: freigeschaltet, oder gesperrt mit Gamepass-Hinweis (Upsell)
function PlotService:RefreshPads(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	local maxSlots = self.Services.UnitService:GetMaxSlots(player)
	for index, pad in plot.Pads do
		local unlocked = index <= maxSlots
		pad.Color = if unlocked then plot.Accent else Color3.fromRGB(80, 78, 75)
		local label = pad:FindFirstChild("PassLabel")
		if unlocked and label then
			label:Destroy()
		elseif not unlocked and not label then
			local gui = Instance.new("BillboardGui")
			gui.Name = "PassLabel"
			gui.Size = UDim2.fromScale(5, 1.5)
			gui.StudsOffset = Vector3.new(0, 2, 0)
			gui.MaxDistance = 60
			local text = Instance.new("TextLabel")
			text.Size = UDim2.fromScale(1, 1)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.FredokaOne
			text.TextScaled = true
			text.TextColor3 = Color3.fromRGB(255, 220, 80)
			text.TextStrokeTransparency = 0.2
			text.Text = "LOCKED: +4 Slots Pass"
			text.Parent = gui
			gui.Parent = pad
		end
	end
end

local function teleportHome(player: Player, character: Model)
	local plot = playerPlots[player]
	if plot then
		task.wait(0.1)
		character:PivotTo(plot.SpawnCFrame)
	end
end

local function pushOut(plot, character: Model)
	-- Eindringling vor die Basis setzen (Richtung Laufband)
	character:PivotTo(plot.CFrame * CFrame.new(0, 4, -(plot.HalfSize + 6)))
end

function PlotService:Start()
	local world = self.Services.WorldService

	for _, plot in world.Plots do
		plot.LockPrompt.Triggered:Connect(function(player)
			if plot.Owner ~= player then
				self.Services.Net.SendNotify(player, "This is not your base!", Color3.fromRGB(255, 80, 80))
				return
			end
			if self:Lock(player, Config.LockDuration + self.Services.RewardService:GetLockBonus(player), false) then
				self.Services.ProgressService:Track(player, "Locks", 1)
			end
		end)
	end

	-- Labels aktualisieren und Sperre durchsetzen
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			for _, plot in world.Plots do
				local owner = plot.Owner
				if not owner then
					continue
				end
				local locked = plot.LockedUntil > now
				plot.Barrier.Transparency = if locked then 0.3 else 1
				if locked then
					plot.LockLabel.Text = "LOCKED " .. Format.Time(plot.LockedUntil - now)
					for _, other in Players:GetPlayers() do
						local character = other.Character
						local root = character and character:FindFirstChild("HumanoidRootPart")
						if other ~= owner and root and world.IsInside(plot, root.Position) then
							pushOut(plot, character)
						end
					end
				elseif now < plot.LockCooldownUntil then
					plot.LockLabel.Text = "RECHARGE " .. Format.Time(plot.LockCooldownUntil - now)
				else
					plot.LockLabel.Text = "LOCK BASE"
				end
				owner:SetAttribute("LockedFor", if locked then math.ceil(plot.LockedUntil - now) else 0)
			end
		end
	end)
end

function PlotService:OnCharacterAdded(player: Player, character: Model)
	teleportHome(player, character)
end

return PlotService
