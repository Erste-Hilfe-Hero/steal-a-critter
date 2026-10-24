-- XP, Level, Skillpunkte, Coins, Kick-Trails, taegliche Belohnung und Namensschilder.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ProgressService = { Services = nil :: any }

local C = Config.Colors

function ProgressService:Init(services)
	self.Services = services
end

local function data(player: Player)
	return ProgressService.Services.DataService:Get(player)
end

local function hasPass(player: Player, key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
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
	player:SetAttribute("SkillPoints", d.SkillPoints)
	player:SetAttribute("BoughtPoints", d.BoughtPoints)
	player:SetAttribute("Trail", d.Trail)
	player:SetAttribute("BoostUntil", d.BoostUntil)
	player:SetAttribute("Goals", d.Goals)
	player:SetAttribute("Wins", d.Wins)
	local owned = {}
	for id in d.Trails do
		table.insert(owned, id)
	end
	player:SetAttribute("OwnedTrails", table.concat(owned, ","))
	local bonus = if hasPass(player, "ProBoots") then 1 else 0
	for _, skill in Config.Skills do
		player:SetAttribute("Base_" .. skill.Id, d.Skills[skill.Id])
		player:SetAttribute("Skill_" .. skill.Id, d.Skills[skill.Id] + bonus)
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

---------------------------------------------------------------- XP und Coins

function ProgressService:AddXP(player: Player, amount: number): number
	local d = data(player)
	if not d then
		return 0
	end
	local multiplier = 1
	if hasPass(player, "DoubleXP") then
		multiplier += 1
	end
	if d.BoostUntil > os.time() then
		multiplier += 1
	end
	amount = math.floor(amount * multiplier)
	d.XP += amount
	local levels = 0
	while d.XP >= Config.XPForLevel(d.Level) do
		d.XP -= Config.XPForLevel(d.Level)
		d.Level += 1
		d.SkillPoints += 1
		levels += 1
	end
	if levels > 0 then
		self.Services.Net.SendNotify(player, `LEVEL {d.Level}! +{levels} skill point{if levels > 1 then "s" else ""}`, C.Lime)
		self.Services.Net.MatchEvent:FireClient(player, "LevelUp", { Level = d.Level })
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
		amount = math.floor(amount * multiplier)
	end
	d.Coins += amount
	self:Refresh(player)
	return amount
end

-- Belohnung aus Config.Rewards; gibt die tatsaechlich vergebenen Werte zurueck
function ProgressService:Reward(player: Player, kind: string): (number, number)
	local def = Config.Rewards[kind]
	if not def then
		return 0, 0
	end
	local xp = self:AddXP(player, def.XP)
	local coins = self:AddCoins(player, def.Coins)
	return xp, coins
end

function ProgressService:AddStat(player: Player, key: string, amount: number)
	local d = data(player)
	if d then
		d[key] += amount
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

---------------------------------------------------------------- Skills

function ProgressService:Upgrade(player: Player, skillId: string)
	local d = data(player)
	if not d or d.Skills[skillId] == nil then
		return
	end
	if d.SkillPoints <= 0 then
		self.Services.Net.Offer:FireClient(player, "SkillPoints")
		return
	end
	if d.Skills[skillId] >= Config.MaxSkill then
		self.Services.Net.SendNotify(player, "This skill is maxed!", C.Orange)
		return
	end
	d.SkillPoints -= 1
	d.Skills[skillId] += 1
	self:Refresh(player)
end

function ProgressService:PointPrice(player: Player): number
	local d = data(player)
	return Config.BuyPointBase + Config.BuyPointStep * (if d then d.BoughtPoints else 0)
end

function ProgressService:BuyPoint(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local price = self:PointPrice(player)
	if d.Coins < price then
		self.Services.Net.Offer:FireClient(player, "Coins")
		return
	end
	d.Coins -= price
	d.BoughtPoints += 1
	d.SkillPoints += 1
	self.Services.Net.SendNotify(player, "+1 skill point!", C.Lime)
	self:Refresh(player)
end

function ProgressService:ResetSkills(player: Player)
	local d = data(player)
	if not d then
		return
	end
	for id, level in d.Skills do
		d.SkillPoints += level
		d.Skills[id] = 0
	end
	self:Refresh(player)
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
		gui.Size = UDim2.fromOffset(180, 46)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 120
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.fromScale(1, 0.6)
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
		info.Position = UDim2.fromScale(0, 0.6)
		info.Size = UDim2.fromScale(1, 0.4)
		info.Font = Config.BodyFont
		info.Parent = gui
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
	self:Refresh(player)
end

function ProgressService:Start()
	local net = self.Services.Net
	net.Upgrade.OnServerEvent:Connect(function(player, skillId)
		if typeof(skillId) == "string" then
			self:Upgrade(player, skillId)
		end
	end)
	net.BuyPoint.OnServerEvent:Connect(function(player)
		self:BuyPoint(player)
	end)
	net.Trail.OnServerEvent:Connect(function(player, id)
		if typeof(id) == "string" then
			self:Trail(player, id)
		end
	end)
end

return ProgressService
