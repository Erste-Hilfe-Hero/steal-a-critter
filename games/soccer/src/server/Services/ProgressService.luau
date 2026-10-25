-- Account-XP/Level, Coins, Kick-Trails, taegliche Belohnung und Namensschilder,
-- dazu wie im Original die Match-EXP: Upgrades werden pro Match mit EXP gekauft und danach zurueckgesetzt.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ProgressService = { Services = nil :: any }

local C = Config.Colors
local match = {} -- [Player] = { EXP = number, Skills = { [id] = level }, BoughtEXP = number }

function ProgressService:Init(services)
	self.Services = services
end

local function data(player: Player)
	return ProgressService.Services.DataService:Get(player)
end

local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

local function xpMultiplier(player: Player): number
	local d = data(player)
	local multiplier = 1
	if hasPass(player, "DoubleXP") then
		multiplier += 1
	end
	if d and d.BoostUntil > os.time() then
		multiplier += 1
	end
	return multiplier
end

---------------------------------------------------------------- Attribute fuer das HUD

function ProgressService:Refresh(player: Player)
	local d = data(player)
	if not d then
		return
	end
	player:SetAttribute("Level", d.Level)
	player:SetAttribute("XP", d.XP)
	player:SetAttribute("XPNeeded", Config.XPForLevel(d.Level))
	player:SetAttribute("Coins", d.Coins)
	player:SetAttribute("Trail", d.Trail)
	player:SetAttribute("BoostUntil", d.BoostUntil)
	player:SetAttribute("Goals", d.Goals)
	player:SetAttribute("Wins", d.Wins)
	local owned = {}
	for id in d.Trails do
		table.insert(owned, id)
	end
	player:SetAttribute("OwnedTrails", table.concat(owned, ","))
	local m = match[player]
	if m then
		player:SetAttribute("EXP", m.EXP)
		player:SetAttribute("BoughtEXP", m.BoughtEXP)
		local bonus = if hasPass(player, "ProBoots") then 1 else 0
		for _, skill in Config.Skills do
			player:SetAttribute("Base_" .. skill.Id, m.Skills[skill.Id])
			player:SetAttribute("Skill_" .. skill.Id, m.Skills[skill.Id] + bonus)
		end
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = d.Level
		leaderstats.Goals.Value = d.Goals
	end
	self:RefreshNameTag(player)
end

function ProgressService:GetSkill(player: Player, skillId: string): number
	return player:GetAttribute("Skill_" .. skillId) or 0
end

---------------------------------------------------------------- Match-EXP und Upgrades

function ProgressService:StartEXP(player: Player): number
	local d = data(player)
	local level = if d then d.Level else 1
	return Config.StartEXP + math.min(Config.MaxLevelEXP, (level - 1) * Config.StartEXPPerLevel) + (if hasPass(player, "VIP") then Config.VIPStartEXP else 0)
end

-- Neues Match: Upgrades auf 0, Start-EXP gutschreiben
function ProgressService:ResetMatch(player: Player)
	local skills = {}
	for _, skill in Config.Skills do
		skills[skill.Id] = 0
	end
	match[player] = { EXP = self:StartEXP(player), Skills = skills, BoughtEXP = 0 }
	self:Refresh(player)
end

function ProgressService:AddEXP(player: Player, amount: number, raw: boolean?): number
	local m = match[player]
	if not m then
		return 0
	end
	if not raw then
		amount = math.floor(amount * xpMultiplier(player))
	end
	m.EXP += amount
	self:Refresh(player)
	return amount
end

function ProgressService:Upgrade(player: Player, skillId: string)
	local m = match[player]
	if not m or m.Skills[skillId] == nil then
		return
	end
	local level = m.Skills[skillId]
	if level >= Config.MaxSkill then
		self.Services.Net.SendNotify(player, "This upgrade is maxed!", C.Orange)
		return
	end
	local cost = Config.UpgradeCost(level)
	if m.EXP < cost then
		self.Services.Net.Offer:FireClient(player, "MatchEXP")
		return
	end
	m.EXP -= cost
	m.Skills[skillId] = level + 1
	self:Refresh(player)
end

function ProgressService:MaxUpgrades(player: Player)
	local m = match[player]
	if not m then
		return
	end
	for id in m.Skills do
		m.Skills[id] = Config.MaxSkill
	end
	self:Refresh(player)
end

function ProgressService:BuyEXPPrice(player: Player): number
	local m = match[player]
	return Config.BuyEXPBase + Config.BuyEXPStep * (if m then m.BoughtEXP else 0)
end

function ProgressService:BuyEXP(player: Player)
	local d = data(player)
	local m = match[player]
	if not d or not m then
		return
	end
	local price = self:BuyEXPPrice(player)
	if d.Coins < price then
		self.Services.Net.Offer:FireClient(player, "Coins")
		return
	end
	d.Coins -= price
	m.BoughtEXP += 1
	m.EXP += Config.BuyEXPAmount
	self.Services.Net.SendNotify(player, `+{Config.BuyEXPAmount} EXP!`, C.Lime)
	self:Refresh(player)
end

---------------------------------------------------------------- Account-XP und Coins

function ProgressService:AddXP(player: Player, amount: number): number
	local d = data(player)
	if not d then
		return 0
	end
	amount = math.floor(amount * xpMultiplier(player))
	d.XP += amount
	local levels = 0
	while d.XP >= Config.XPForLevel(d.Level) do
		d.XP -= Config.XPForLevel(d.Level)
		d.Level += 1
		levels += 1
	end
	if levels > 0 then
		self.Services.Net.SendNotify(player, `ACCOUNT LEVEL {d.Level}! More start EXP every match`, C.Lime)
		self.Services.Net.MatchEvent:FireClient(player, "LevelUp", { Level = d.Level })
		task.spawn(self.Services.ExtrasService.OnLevelUp, self.Services.ExtrasService, player, d.Level)
	end
	self:Refresh(player)
	return amount
end

function ProgressService:AddCoins(player: Player, amount: number, raw: boolean?): number
	local d = data(player)
	if not d then
		return 0
	end
	if not raw then
		local multiplier = 1
		if hasPass(player, "VIP") then
			multiplier *= 1.5
		end
		if hasPass(player, "DoubleCoins") then
			multiplier *= 2
		end
		-- Freunde-Bonus (FeaturesService setzt das Attribut)
		if player:GetAttribute("FriendBonus") == true then
			multiplier *= Config.FriendBonus
		end
		-- Wochenende: doppelte Coins
		if Config.IsWeekend() then
			multiplier *= Config.WeekendCoins
		end
		amount = math.floor(amount * multiplier)
	end
	d.Coins += amount
	self:Refresh(player)
	return amount
end

-- Belohnung: Account-XP/Coins aus Config.Rewards und Match-EXP aus Config.EXP.
-- Gibt (XP, Coins, EXP) zurueck.
function ProgressService:Reward(player: Player, kind: string, bonusEXP: number?): (number, number, number)
	local def = Config.Rewards[kind]
	local xp = if def then self:AddXP(player, def.XP) else 0
	local coins = if def then self:AddCoins(player, def.Coins) else 0
	local baseEXP = (Config.EXP[kind] or 0) + (bonusEXP or 0)
	local exp = if baseEXP > 0 then self:AddEXP(player, baseEXP) else 0
	if exp > 0 then
		self.Services.Net.MatchEvent:FireClient(player, "EXP", { Amount = exp, Kind = kind })
	end
	return xp, coins, exp
end

function ProgressService:AddStat(player: Player, key: string, amount: number)
	local d = data(player)
	if d then
		d[key] = (d[key] or 0) + amount
		self:Refresh(player)
	end
end

function ProgressService:FinishMatch(player: Player, won: boolean)
	local d = data(player)
	if d then
		d.Matches += 1
		if won then
			d.Wins += 1
		end
		self:Refresh(player)
	end
end

function ProgressService:OnPlayerRemoving(player: Player)
	match[player] = nil
end

---------------------------------------------------------------- Trails

function ProgressService:UnlockTrail(player: Player, id: string)
	local d = data(player)
	if d and Config.TrailsById[id] then
		d.Trails[id] = true
		self:Refresh(player)
	end
end

function ProgressService:Trail(player: Player, id: string)
	local d = data(player)
	local def = Config.TrailsById[id]
	if not d or not def then
		return
	end
	if def.Pass and hasPass(player, def.Pass) then
		d.Trails[id] = true
	end
	if not d.Trails[id] then
		if def.Pass then
			self.Services.Net.Offer:FireClient(player, def.Pass)
			return
		end
		if d.Coins < def.Price then
			self.Services.Net.Offer:FireClient(player, "Coins")
			return
		end
		d.Coins -= def.Price
		d.Trails[id] = true
		self.Services.Net.SendNotify(player, `{def.Name} unlocked!`, C.Lime)
	end
	d.Trail = id
	self:Refresh(player)
end

---------------------------------------------------------------- Namensschilder

function ProgressService:NameTag(model: Model, name: string, level: number, color: Color3, vip: boolean, bot: boolean?)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local tag = head:FindFirstChild("NameTag") :: BillboardGui?
	if not tag then
		local gui = Instance.new("BillboardGui")
		gui.Name = "NameTag"
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 120
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, 0, 0, 28)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = Config.Font
		nameLabel.TextScaled = true
		nameLabel.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = C.Navy
		stroke.Parent = nameLabel
		local info = nameLabel:Clone()
		info.Name = "Info"
		info.Position = UDim2.fromOffset(0, 28)
		info.Size = UDim2.new(1, 0, 0, 16)
		info.Font = Config.BodyFont
		info.Parent = gui
		-- Lebensbalken (der CombatService passt die Breite an)
		local hpBack = Instance.new("Frame")
		hpBack.Name = "HP"
		hpBack.AnchorPoint = Vector2.new(0.5, 0)
		hpBack.Position = UDim2.fromOffset(90, 46)
		hpBack.Size = UDim2.fromOffset(70, 7)
		hpBack.BackgroundColor3 = C.Navy
		hpBack.BorderSizePixel = 0
		hpBack.Parent = gui
		local hpBar = Instance.new("Frame")
		hpBar.Name = "Bar"
		hpBar.Size = UDim2.fromScale(1, 1)
		hpBar.BackgroundColor3 = Color3.fromRGB(90, 230, 90)
		hpBar.BorderSizePixel = 0
		hpBar.Parent = hpBack
		gui.Size = UDim2.fromOffset(180, 54)
		gui.Parent = head
		tag = gui
	end
	local gui = tag :: BillboardGui
	local nameLabel = gui:FindFirstChild("Name") :: TextLabel
	local info = gui:FindFirstChild("Info") :: TextLabel
	nameLabel.Text = name
	nameLabel.TextColor3 = if vip then C.Gold else color
	info.Text = (if vip then "VIP  " else "") .. (if bot then "BOT  " else "") .. "LV " .. level
	info.TextColor3 = if vip then C.Gold else C.White
end

function ProgressService:RefreshNameTag(player: Player)
	local character = player.Character
	local teamName = player:GetAttribute("Team")
	if character and teamName then
		self:NameTag(character, player.DisplayName, player:GetAttribute("Level") or 1, Config.Teams[teamName].Color, hasPass(player, "VIP"))
	end
end

function ProgressService:OnCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- Aussehen laedt nach; danach das Schild anbringen
	character:WaitForChild("Head", 10)
	task.wait(0.5)
	self:RefreshNameTag(player)
end

---------------------------------------------------------------- Beitritt

function ProgressService:OnPlayerReady(player: Player)
	local d = data(player)
	if not d then
		return
	end
	-- Taegliche Belohnung mit Serie
	local today = os.time() // 86400
	if d.LastDaily ~= today then
		d.DailyStreak = if d.LastDaily == today - 1 then d.DailyStreak + 1 else 1
		d.LastDaily = today
		local coins = Config.DailyCoins[math.min(d.DailyStreak, #Config.DailyCoins)]
		d.Coins += coins
		task.delay(4, function()
			if player.Parent then
				self.Services.Net.SendNotify(player, `Daily reward: +{coins} coins (day {d.DailyStreak} streak)`, C.Gold)
			end
		end)
	end
	self:ResetMatch(player)
end

function ProgressService:Start()
	local net = self.Services.Net
	net.Upgrade.OnServerEvent:Connect(function(player, skillId)
		if typeof(skillId) == "string" then
			self:Upgrade(player, skillId)
		end
	end)
	net.BuyPoint.OnServerEvent:Connect(function(player)
		self:BuyEXP(player)
	end)
	net.Trail.OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" then
			self:Trail(player, id)
		end
	end)
end

return ProgressService
