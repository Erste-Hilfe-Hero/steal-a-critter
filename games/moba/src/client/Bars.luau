-- Lebensbalken ueber allen Einheiten: eigener Held gruen, Verbuendete blau, Gegner rot, Monster gelb.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Bars = {}

local player = Players.LocalPlayer

Bars.SELF = Color3.fromRGB(110, 231, 160)
Bars.ALLY = Color3.fromRGB(92, 200, 255)
Bars.ENEMY = Color3.fromRGB(255, 90, 90)
Bars.NEUTRAL = Color3.fromRGB(255, 196, 70)

local SIZES = {
	Hero = { Width = 92, Height = 11, Offset = 4.2 },
	Minion = { Width = 40, Height = 5, Offset = 2.4 },
	Tower = { Width = 110, Height = 10, Offset = 24 },
	Inhibitor = { Width = 110, Height = 9, Offset = 12 },
	Nexus = { Width = 150, Height = 12, Offset = 18 },
	Monster = { Width = 70, Height = 7, Offset = 5 },
	Ward = { Width = 28, Height = 4, Offset = 5 },
}

local bars = {} -- [Model] = Update-Funktion

function Bars.ColorFor(model: Instance): Color3
	local team = model:GetAttribute("Team")
	if team == 0 then
		return Bars.NEUTRAL
	end
	if model == player.Character then
		return Bars.SELF
	end
	return if team == player:GetAttribute("Team") then Bars.ALLY else Bars.ENEMY
end

local function attach(model: Instance)
	if bars[model] or not model:IsA("Model") then
		return
	end
	local kind = model:GetAttribute("Kind") or "Minion"
	local size = SIZES[kind] or SIZES.Minion
	local root = (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:WaitForChild("Root", 2)) :: any
	if not root then
		return
	end
	if model:GetAttribute("Boss") then
		size = { Width = 120, Height = 10, Offset = 9 }
	end
	local isHero = kind == "Hero"
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Bar"
	billboard.Size = UDim2.fromOffset(size.Width, size.Height + (if isHero then 26 else 0))
	billboard.StudsOffsetWorldSpace = Vector3.new(0, size.Offset, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = if isHero or kind == "Nexus" or kind == "Tower" or kind == "Inhibitor" then 220 else 110
	billboard.Adornee = root
	billboard.ResetOnSpawn = false

	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0, 1)
	back.Position = UDim2.fromScale(0, 1)
	back.Size = UDim2.new(1, 0, 0, size.Height)
	back.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
	back.BorderSizePixel = 0
	back.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.fromRGB(10, 10, 16)
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local shield = Instance.new("Frame")
	shield.Size = UDim2.fromScale(0, 1)
	shield.BackgroundColor3 = Color3.new(1, 1, 1)
	shield.BorderSizePixel = 0
	shield.Parent = back
	-- Striche alle 200 HP bei Helden, damit man Gefahr einschaetzen kann
	local ticks = {}
	local lock = Instance.new("TextLabel")
	lock.BackgroundTransparency = 1
	lock.AnchorPoint = Vector2.new(1, 0.5)
	lock.Position = UDim2.new(0, -2, 0.5, 0)
	lock.Size = UDim2.fromOffset(size.Height + 8, size.Height + 8)
	lock.Text = "🛡"
	lock.TextScaled = true
	lock.Visible = false
	lock.Parent = back

	local nameLabel, levelLabel, manaFill, manaBack, titleLabel
	if isHero then
		billboard.Size = UDim2.fromOffset(size.Width, size.Height + 32)
		manaBack = Instance.new("Frame")
		manaBack.AnchorPoint = Vector2.new(0, 1)
		manaBack.Position = UDim2.new(0, 0, 1, 0)
		manaBack.Size = UDim2.new(1, 0, 0, 4)
		manaBack.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
		manaBack.BorderSizePixel = 0
		manaBack.Parent = billboard
		manaFill = Instance.new("Frame")
		manaFill.Size = UDim2.fromScale(1, 1)
		manaFill.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
		manaFill.BorderSizePixel = 0
		manaFill.Parent = manaBack
		back.Position = UDim2.new(0, 0, 1, -6)
		nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Size = UDim2.new(1, 0, 0, 16)
		nameLabel.Position = UDim2.fromOffset(0, 2)
		nameLabel.Font = Enum.Font.BuilderSansExtraBold
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Parent = billboard
		local nameStroke = Instance.new("UIStroke")
		nameStroke.Thickness = 1.5
		nameStroke.Parent = nameLabel
		-- Titel aus Erfolgen ueber dem Namen
		titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.Size = UDim2.new(1, 0, 0, 12)
		titleLabel.Position = UDim2.fromOffset(0, -10)
		titleLabel.Font = Enum.Font.BuilderSansBold
		titleLabel.TextScaled = true
		titleLabel.TextColor3 = Color3.fromRGB(255, 205, 90)
		titleLabel.Visible = false
		titleLabel.Parent = billboard
		local titleStroke = Instance.new("UIStroke")
		titleStroke.Thickness = 1
		titleStroke.Parent = titleLabel
		levelLabel = Instance.new("TextLabel")
		levelLabel.AnchorPoint = Vector2.new(1, 0.5)
		levelLabel.Position = UDim2.new(0, -3, 0.5, 0)
		levelLabel.Size = UDim2.fromOffset(18, 18)
		levelLabel.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
		levelLabel.Font = Enum.Font.LuckiestGuy
		levelLabel.TextScaled = true
		levelLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
		levelLabel.Parent = back
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = levelLabel
	end

	local function update()
		local hp = tonumber(model:GetAttribute("HP")) or 0
		local maxHp = math.max(1, tonumber(model:GetAttribute("MaxHP")) or 1)
		local shieldValue = tonumber(model:GetAttribute("Shield")) or 0
		local total = math.max(maxHp, hp + shieldValue)
		fill.Size = UDim2.fromScale(math.clamp(hp / total, 0, 1), 1)
		shield.Position = UDim2.fromScale(math.clamp(hp / total, 0, 1), 0)
		shield.Size = UDim2.fromScale(math.clamp(shieldValue / total, 0, 1), 1)
		fill.BackgroundColor3 = Bars.ColorFor(model)
		lock.Visible = model:GetAttribute("Protected") == true
		billboard.Enabled = hp > 0
		if isHero then
			local name = model:GetAttribute("UnitName") or model.Name
			local heroDef = Config.HeroesById[model:GetAttribute("HeroId") or ""]
			local tag = if model:GetAttribute("IsBot") then " [BOT]" else ""
			nameLabel.Text = (if heroDef then heroDef.Icon .. " " else "") .. tostring(name) .. tag
			local owner = Players:GetPlayerFromCharacter(model)
			nameLabel.TextColor3 = if owner and owner:GetAttribute("VIP") then Color3.fromRGB(255, 210, 70) else Color3.new(1, 1, 1)
			local buffs = tostring(model:GetAttribute("Buffs") or "")
			if string.find(buffs, "Baron", 1, true) then
				nameLabel.Text = "👁 " .. nameLabel.Text
			end
			if string.find(buffs, "Elder", 1, true) then
				nameLabel.Text = "🐉 " .. nameLabel.Text
			end
			local maxMana = tonumber(model:GetAttribute("MaxMana")) or 0
			manaBack.Visible = maxMana > 0
			manaFill.Size = UDim2.fromScale(if maxMana > 0 then math.clamp((tonumber(model:GetAttribute("Mana")) or 0) / maxMana, 0, 1) else 0, 1)
			levelLabel.Text = tostring(model:GetAttribute("Level") or 1)
			local title = tostring(model:GetAttribute("Title") or "")
			titleLabel.Visible = title ~= ""
			titleLabel.Text = "«" .. title .. "»"
			-- Striche
			local count = math.floor(maxHp / 200)
			for i = 1, math.max(count, #ticks) do
				local tick = ticks[i]
				if i <= count and i * 200 < maxHp then
					if not tick then
						tick = Instance.new("Frame")
						tick.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
						tick.BorderSizePixel = 0
						tick.Size = UDim2.new(0, 1, 0.6, 0)
						tick.ZIndex = 3
						tick.Parent = back
						ticks[i] = tick
					end
					tick.Position = UDim2.fromScale(i * 200 / total, 0)
					tick.Visible = true
				elseif tick then
					tick.Visible = false
				end
			end
		end
	end
	update()
	for _, attribute in { "HP", "MaxHP", "Shield", "Protected", "Level", "Buffs", "Team", "HeroId", "UnitName", "Mana", "MaxMana", "Title" } do
		model:GetAttributeChangedSignal(attribute):Connect(update)
	end
	bars[model] = update
	billboard.Parent = model
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			bars[model] = nil
		end
	end)
end

function Bars.RefreshAll()
	for _, update in bars do
		update()
	end
end

function Bars.Start()
	for _, model in CollectionService:GetTagged("Unit") do
		task.spawn(attach, model)
	end
	CollectionService:GetInstanceAddedSignal("Unit"):Connect(function(model)
		task.spawn(attach, model)
	end)
	player:GetAttributeChangedSignal("Team"):Connect(Bars.RefreshAll)
end

return Bars
