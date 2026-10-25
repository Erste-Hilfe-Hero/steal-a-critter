-- Gratis-Belohnungen und Basis-Fortschritt: Spielzeit-Geschenke, Gluecksrad, Codes, Offline-Einnahmen,
-- Basis-Ausbau, Kreatur des Tages, Neulingsschutz und Kopfgeld auf den reichsten Spieler.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local RewardService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)
local RED = Color3.fromRGB(255, 80, 80)

local sessions = {} -- [Player] = { Start = os.clock(), Gifts = { [index] = true } }
local bountyPlayer: Player? = nil

function RewardService:Init(services)
	self.Services = services
end

local function notify(player: Player, text: string, color: Color3?)
	RewardService.Services.Net.SendNotify(player, text, color)
end

local function reward(player: Player, minutes: number, minCash: number): number
	return RewardService.Services.ProgressService.IncomeReward(player, minutes, minCash)
end

---------------------------------------------------------------- Stand fuer den Client

function RewardService:Refresh(player: Player)
	local data = self.Services.DataService:Get(player)
	local session = sessions[player]
	if not data or not session then
		return
	end
	local progress = self.Services.ProgressService
	local gifts = {}
	for index, gift in Config.PlaytimeGifts do
		gifts[index] = { Minutes = gift.Minutes, Claimed = session.Gifts[index] == true, Reward = reward(player, gift.Reward, gift.MinCash), Catalyst = gift.Catalyst == true }
	end
	progress:SetExtra(player, "Gifts", gifts)
	-- Beginn der Sitzung; ProgressService rechnet beim Senden die Spielzeit aus (Client rechnet ab dann selbst weiter)
	progress:SetExtra(player, "SessionStart", session.Start)
	progress:SetExtra(player, "NextSpinAt", (data.LastSpinAt or 0) + Config.SpinCooldown)
	progress:SetExtra(player, "BaseLevel", data.BaseLevel or 0)
	progress:SetExtra(player, "BaseCost", if (data.BaseLevel or 0) < Config.BaseMaxLevel then Config.BaseUpgradeCost(data.BaseLevel or 0) else 0)
	player:SetAttribute("BaseLevel", data.BaseLevel or 0)
end

---------------------------------------------------------------- Spielzeit-Geschenke

local function claimGift(player: Player, index: any)
	local session = sessions[player]
	local gift = type(index) == "number" and Config.PlaytimeGifts[index]
	if not session or not gift then
		return false, "Not available"
	end
	if session.Gifts[index] then
		return false, "Already claimed"
	end
	local left = gift.Minutes * 60 - (os.clock() - session.Start)
	if left > 1 then
		return false, `Ready in {Format.Time(left)}`
	end
	session.Gifts[index] = true
	local amount = reward(player, gift.Reward, gift.MinCash)
	RewardService.Services.DataService:AddCash(player, amount)
	local text = `🎁 Gift: +{Format.Cash(amount)}`
	if gift.Catalyst then
		local data = RewardService.Services.DataService:Get(player)
		data.Catalysts = (data.Catalysts or 0) + 1
		player:SetAttribute("Catalysts", data.Catalysts)
		text ..= " and a Fusion Catalyst"
	end
	notify(player, text .. "!", GOLD)
	RewardService.Services.Net.PlaySfx(player, "Reward")
	RewardService:Refresh(player)
	return true
end

---------------------------------------------------------------- Gluecksrad (nur gratis)

local function pickPrize(): number
	local total = 0
	for _, prize in Config.SpinPrizes do
		total += prize.Weight
	end
	local roll = math.random() * total
	for index, prize in Config.SpinPrizes do
		roll -= prize.Weight
		if roll <= 0 then
			return index
		end
	end
	return 1
end

local function grantPrize(player: Player, prize): string
	local services = RewardService.Services
	if prize.Kind == "Cash" then
		local amount = reward(player, prize.Minutes, 500)
		services.DataService:AddCash(player, amount)
		return `+{Format.Cash(amount)}`
	elseif prize.Kind == "Luck" then
		services.MonetizationService:AddServerLuck(prize.Seconds, player.DisplayName)
		return "Server Luck x3 for everyone"
	elseif prize.Kind == "Catalyst" then
		local data = services.DataService:Get(player)
		data.Catalysts = (data.Catalysts or 0) + 1
		player:SetAttribute("Catalysts", data.Catalysts)
		return "a Fusion Catalyst"
	elseif prize.Kind == "Mutate" then
		local name = services.UnitService:MutateBest(player, prize.Mutation)
		if name then
			return `your critter became {name}`
		end
		local amount = reward(player, 30, 5_000)
		services.DataService:AddCash(player, amount)
		return `+{Format.Cash(amount)} (no critter to upgrade)`
	end
	return ""
end

local function spin(player: Player)
	local data = RewardService.Services.DataService:Get(player)
	if not data then
		return false, "Not ready"
	end
	local now = os.time()
	local nextAt = (data.LastSpinAt or 0) + Config.SpinCooldown
	if now < nextAt then
		return false, `Next free spin in {Format.Time(nextAt - now)}`
	end
	data.LastSpinAt = now
	local index = pickPrize()
	local prize = Config.SpinPrizes[index]
	local text = grantPrize(player, prize)
	-- Toast kommt verzoegert, damit das Rad erst auslaufen kann
	task.delay(3.2, function()
		if player.Parent then
			notify(player, `🎡 Lucky Wheel: {prize.Name}! {text}`, prize.Color)
			RewardService.Services.Net.PlaySfx(player, "Reward")
			if prize.Weight <= 5 then
				RewardService.Services.Net.SendAnnounce(`{player.DisplayName} won {prize.Name} on the Lucky Wheel!`, prize.Color)
			end
		end
	end)
	RewardService:Refresh(player)
	return true, text, index
end

---------------------------------------------------------------- Codes

local function redeem(player: Player, code: any)
	local data = RewardService.Services.DataService:Get(player)
	if not data or type(code) ~= "string" or #code > 30 then
		return false, "Invalid code"
	end
	code = code:upper():gsub("%s", "")
	local entry = Config.Codes[code]
	if not entry then
		return false, "This code does not exist"
	end
	if data.Codes[code] then
		return false, "You already used this code"
	end
	data.Codes[code] = true
	local amount = reward(player, entry.Minutes, entry.Cash)
	RewardService.Services.DataService:AddCash(player, amount)
	notify(player, `Code {code}: +{Format.Cash(amount)}!`, GOLD)
	RewardService.Services.Net.PlaySfx(player, "Reward")
	return true, `+{Format.Cash(amount)}`
end

---------------------------------------------------------------- Basis-Ausbau

local function upgradeBase(player: Player)
	local services = RewardService.Services
	local data = services.DataService:Get(player)
	if not data then
		return false, "Not ready"
	end
	local level = data.BaseLevel or 0
	if level >= Config.BaseMaxLevel then
		return false, "Your base is fully upgraded!"
	end
	local cost = Config.BaseUpgradeCost(level)
	if data.Cash < cost then
		return false, `You need {Format.Cash(cost - data.Cash)} more`
	end
	services.DataService:AddCash(player, -cost)
	data.BaseLevel = level + 1
	services.UnitService:UpdateIncome(player)
	notify(player, `🏠 Base level {data.BaseLevel}! +{math.floor(data.BaseLevel * Config.BaseLevelIncome * 100)}% income, longer lock.`, GREEN)
	if data.BaseLevel == Config.BaseMaxLevel then
		services.Net.SendAnnounce(`{player.DisplayName} fully upgraded their base!`, GOLD)
	end
	RewardService:Refresh(player)
	return true
end

function RewardService:GetBaseBonus(player: Player): number
	local data = self.Services.DataService:Get(player)
	return if data then (data.BaseLevel or 0) * Config.BaseLevelIncome else 0
end

function RewardService:GetLockBonus(player: Player): number
	local data = self.Services.DataService:Get(player)
	return if data then (data.BaseLevel or 0) * Config.BaseLevelLock else 0
end

---------------------------------------------------------------- Kreatur des Tages

local featuredDay = -1
local featuredId = ""
function RewardService:GetFeaturedId(): string
	local day = os.time() // 86400
	if day ~= featuredDay then
		featuredDay = day
		local pool = {}
		for _, def in Config.Units do
			if def.Rarity ~= "Secret" then
				table.insert(pool, def)
			end
		end
		local def = pool[(day * 7 + 3) % #pool + 1]
		featuredId = def.Id
		workspace:SetAttribute("FeaturedId", def.Id)
		workspace:SetAttribute("FeaturedName", def.Name)
		workspace:SetAttribute("FeaturedRarity", def.Rarity)
	end
	return featuredId
end

---------------------------------------------------------------- Neulingsschutz und Kopfgeld

function RewardService:HasShield(player: Player): boolean
	return player:GetAttribute("NewbieShield") == true
end

function RewardService:IsBounty(player: Player): boolean
	return bountyPlayer == player
end

local function bountyTag(player: Player, show: boolean)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local existing = head and head:FindFirstChild("BountyTag")
	if not show then
		if existing then
			existing:Destroy()
		end
		return
	end
	if not head or existing then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BountyTag"
	gui.Size = UDim2.fromOffset(150, 30)
	gui.StudsOffset = Vector3.new(0, 5.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 210, 60)
	label.TextStrokeTransparency = 0
	label.Text = "💰 BOUNTY 💰"
	label.Parent = gui
	gui.Parent = head
end

local function updateBounty()
	local players = Players:GetPlayers()
	local best, bestIncome = nil, 0
	if #players >= Config.BountyMinPlayers then
		for _, player in players do
			local value = tonumber(player:GetAttribute("IncomePerSec")) or 0
			if value > bestIncome and not RewardService:HasShield(player) then
				best, bestIncome = player, value
			end
		end
	end
	if best ~= bountyPlayer then
		if bountyPlayer then
			bountyPlayer:SetAttribute("Bounty", nil)
			bountyTag(bountyPlayer, false)
		end
		bountyPlayer = best
		if best then
			best:SetAttribute("Bounty", true)
			workspace:SetAttribute("BountyName", best.DisplayName)
			RewardService.Services.Net.SendAnnounce(`💰 BOUNTY on {best.DisplayName}! Steal from them for a {math.floor(Config.BountyShare * 100)}% bonus!`, GOLD)
		else
			workspace:SetAttribute("BountyName", nil)
		end
	end
	if best then
		bountyTag(best, true)
	end
end

-- Bonus fuer den Dieb, wenn das Opfer das Kopfgeld traegt
function RewardService:BountyBonus(thief: Player, owner: Player, value: number)
	if bountyPlayer ~= owner then
		return
	end
	local bonus = math.floor(value * Config.BountyShare)
	self.Services.DataService:AddCash(thief, bonus)
	notify(thief, `💰 Bounty collected: +{Format.Cash(bonus)}!`, GOLD)
end

local function updateShield(player: Player)
	local data = RewardService.Services.DataService:Get(player)
	if not data then
		return
	end
	local shielded = (data.PlayTime or 0) < Config.NewbieShieldMinutes * 60 and data.Rebirths == 0
	if (player:GetAttribute("NewbieShield") == true) ~= shielded then
		player:SetAttribute("NewbieShield", shielded or nil)
		if not shielded then
			notify(player, "🛡️ Your newbie shield is gone - protect your critters!", RED)
		end
	end
	player:SetAttribute("ShieldLeft", if shielded then math.max(0, Config.NewbieShieldMinutes * 60 - (data.PlayTime or 0)) else nil)
end

---------------------------------------------------------------- Offline-Einnahmen

local function payOffline(player: Player, data)
	local last = data.LastOnline or 0
	local elapsed = os.time() - last
	if last <= 0 or elapsed < Config.OfflineMinSeconds then
		return
	end
	local pro = RewardService.Services.MonetizationService:HasPass(player, "OfflinePro")
	local share = if pro then Config.OfflineProShare else Config.OfflineShare
	local maxSeconds = (if pro then Config.OfflineProMaxHours else Config.OfflineMaxHours) * 3600
	local amount = math.floor((data.OfflineIncome or 0) * math.min(elapsed, maxSeconds) * share)
	if amount <= 0 then
		return
	end
	RewardService.Services.DataService:AddCash(player, amount)
	task.delay(5, function()
		if not player.Parent then
			return
		end
		notify(player, `🌙 Your critters earned {Format.Cash(amount)} while you were away!`, GOLD)
		if not pro then
			RewardService.Services.Net.SendOffer(player, "Pass", "OfflinePro", "Earn 4x more while offline!")
		end
	end)
end

---------------------------------------------------------------- Lebenszyklus

function RewardService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	sessions[player] = { Start = os.clock(), Gifts = {} }
	payOffline(player, data)
	updateShield(player)
	self:Refresh(player)
end

function RewardService:OnPlayerRemoving(player: Player)
	sessions[player] = nil
	if bountyPlayer == player then
		bountyPlayer = nil
		workspace:SetAttribute("BountyName", nil)
	end
end

function RewardService:Start()
	local net = self.Services.Net
	net.Handle("ClaimGift", claimGift)
	net.Handle("Spin", spin)
	net.Handle("Redeem", redeem)
	net.Handle("UpgradeBase", upgradeBase)
	self:GetFeaturedId()

	task.spawn(function()
		local tick = 0
		while true do
			task.wait(5)
			tick += 1
			self:GetFeaturedId()
			for _, player in Players:GetPlayers() do
				if sessions[player] then
					updateShield(player)
					-- Geschenk-Betraege wachsen mit dem Einkommen
					if tick % 6 == 0 then
						self:Refresh(player)
					end
				end
			end
			if tick % 2 == 0 then
				updateBounty()
			end
		end
	end)
end

return RewardService
