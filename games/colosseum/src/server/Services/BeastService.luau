-- Sammlung der Spieler: Bestien fangen, Team, Level, Aufstieg (Evolution), Heilen und Gegenstaende.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local BeastService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(110, 230, 130)
local RED = Color3.fromRGB(255, 90, 90)
local PRISM = Color3.fromRGB(150, 255, 245)

function BeastService:Init(services)
	self.Services = services
end

local function count(t): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

function BeastService:Capacity(player: Player): number
	local data = self.Services.DataService:Get(player)
	return Config.MaxStorage + (if data then data.ExtraStorage else 0)
end

function BeastService:TeamSize(player: Player): number
	return if self.Services.MonetizationService:HasPass(player, "BigTeam") then Config.BigTeamSize else Config.TeamSize
end

-- Schickt die komplette Sammlung an den Client
function BeastService:Sync(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local beasts = {}
	for uid, entry in data.Beasts do
		local stats = Config.Stats(entry.S, entry.L, entry.Sh)
		beasts[uid] = {
			S = entry.S,
			L = entry.L,
			X = entry.X,
			Need = Config.XpToNext(entry.L),
			Sh = entry.Sh,
			Hp = entry.Hp,
			MaxHp = stats.MaxHp,
			Atk = stats.Atk,
			Def = stats.Def,
			Spd = stats.Spd,
			Power = Config.Power(entry.S, entry.L, entry.Sh),
		}
	end
	self.Services.Net.Collection:FireClient(player, {
		Beasts = beasts,
		Team = data.Team,
		Items = data.Items,
		Capacity = self:Capacity(player),
		TeamSize = self:TeamSize(player),
		Dex = data.Dex,
		Started = data.Started,
		GotStarter = data.GotStarter,
	})
	player:SetAttribute("BeastCount", count(data.Beasts))
	local lead = data.Beasts[data.Team[1]]
	player:SetAttribute("LeadLevel", if lead then lead.L else 1)
end

-- Neue Bestie in die Sammlung. Gibt die uid zurueck (nil, wenn kein Platz ist).
function BeastService:Add(player: Player, beastId: string, level: number, shiny: boolean?, hp: number?): string?
	local data = self.Services.DataService:Get(player)
	if not data or not Config.BeastsById[beastId] then
		return nil
	end
	if count(data.Beasts) >= self:Capacity(player) then
		self.Services.Net.SendNotify(player, "Your storage is full! Release beasts or get more storage.", RED)
		self.Services.MonetizationService:Offer(player, "Storage", "Storage full! Keep 50 more beasts?")
		return nil
	end
	local uid = tostring(data.NextId)
	data.NextId += 1
	local stats = Config.Stats(beastId, level, shiny)
	data.Beasts[uid] = { S = beastId, L = level, X = 0, Sh = shiny == true, Hp = math.clamp(hp or stats.MaxHp, 1, stats.MaxHp) }
	if #data.Team < self:TeamSize(player) then
		table.insert(data.Team, uid)
	end
	if not data.Dex[beastId] then
		data.Dex[beastId] = true
	end
	data.Caught += 1
	self.Services.DataService:UpdateAttributes(player)
	self:Sync(player)
	return uid
end

function BeastService:Get(player: Player, uid: string)
	local data = self.Services.DataService:Get(player)
	return data and data.Beasts[uid]
end

-- Team-Bestien in Kampfreihenfolge (nur vorhandene)
function BeastService:TeamEntries(player: Player): { { Uid: string, Entry: any } }
	local data = self.Services.DataService:Get(player)
	local list = {}
	if not data then
		return list
	end
	for _, uid in data.Team do
		local entry = data.Beasts[uid]
		if entry then
			table.insert(list, { Uid = uid, Entry = entry })
		end
		if #list >= self:TeamSize(player) then
			break
		end
	end
	return list
end

function BeastService:HasHealthyTeam(player: Player): boolean
	for _, item in self:TeamEntries(player) do
		if item.Entry.Hp > 0 then
			return true
		end
	end
	return false
end

function BeastService:HealAll(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	for _, entry in data.Beasts do
		entry.Hp = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
	end
	self:Sync(player)
end

---------------------------------------------------------------- Level und Aufstieg

-- Aufstieg in die naechste Form. Gibt true zurueck, wenn es geklappt hat.
function BeastService:Evolve(player: Player, uid: string, force: boolean?): boolean
	local entry = self:Get(player, uid)
	if not entry then
		return false
	end
	local def = Config.BeastsById[entry.S]
	if not def.Evolve or (not force and entry.L < def.Evolve.Level) then
		return false
	end
	local hpFraction = entry.Hp / Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
	entry.S = def.Evolve.To
	entry.L = math.max(entry.L, if force then entry.L else def.Evolve.Level)
	entry.Hp = math.max(1, math.floor(Config.Stats(entry.S, entry.L, entry.Sh).MaxHp * hpFraction))
	local data = self.Services.DataService:Get(player)
	data.Dex[entry.S] = true
	local newDef = Config.BeastsById[entry.S]
	self.Services.Net.SendNotify(player, `{def.Name} ascended into {newDef.Name}!`, GOLD)
	if Config.RaritiesByName[newDef.Rarity].Index >= 3 then
		self.Services.Net.SendAnnounce(`{player.DisplayName}'s {def.Name} ascended into {newDef.Name}!`, GOLD)
	end
	return true
end

-- XP vergeben, Level-Ups und automatische Aufstiege. Gibt Ereignisse fuer die Siegesanzeige zurueck.
function BeastService:GiveXp(player: Player, uid: string, amount: number): { any }
	local entry = self:Get(player, uid)
	local events = {}
	if not entry or amount <= 0 then
		return events
	end
	entry.X += math.floor(amount)
	while entry.L < Config.MaxLevel and entry.X >= Config.XpToNext(entry.L) do
		entry.X -= Config.XpToNext(entry.L)
		local before = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
		entry.L += 1
		local after = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
		entry.Hp = math.min(after, entry.Hp + (after - before))
		table.insert(events, { T = "Level", S = entry.S, L = entry.L })
		local from = entry.S
		if self:Evolve(player, uid) then
			table.insert(events, { T = "Evolve", From = from, To = entry.S })
		end
	end
	if entry.L >= Config.MaxLevel then
		entry.X = 0
	end
	-- Angebot, wenn der Aufstieg nur noch wenige Level entfernt ist
	local def = Config.BeastsById[entry.S]
	if def.Evolve and def.Evolve.Level - entry.L <= 3 and def.Evolve.Level > entry.L then
		self.Services.MonetizationService:Offer(player, "EvoCrystal", `{def.Name} is close to ascending! Ascend it NOW?`)
	end
	return events
end

function BeastService:AddLevels(player: Player, uid: string, levels: number)
	local entry = self:Get(player, uid)
	if not entry then
		return
	end
	local need = 0
	local level = entry.L
	for i = 0, levels - 1 do
		if level + i < Config.MaxLevel then
			need += Config.XpToNext(level + i)
		end
	end
	self:GiveXp(player, uid, math.max(0, need - entry.X))
	self:Sync(player)
end

-- Fuehrende Bestie (Platz 1 im Team)
function BeastService:LeadUid(player: Player): string?
	local data = self.Services.DataService:Get(player)
	return data and data.Team[1]
end

function BeastService:LeadLevel(player: Player): number
	local uid = self:LeadUid(player)
	local entry = uid and self:Get(player, uid)
	return if entry then entry.L else 1
end

---------------------------------------------------------------- Gegenstaende

function BeastService:AddItem(player: Player, key: string, amount: number)
	local data = self.Services.DataService:Get(player)
	if not data or not Config.Items[key] then
		return
	end
	data.Items[key] = (data.Items[key] or 0) + amount
	self:Sync(player)
end

function BeastService:UseItem(player: Player, key: string): boolean
	local data = self.Services.DataService:Get(player)
	if not data or (data.Items[key] or 0) <= 0 then
		return false
	end
	data.Items[key] -= 1
	return true
end

function BeastService:GrantBundle(player: Player, bundle)
	if bundle.Coins then
		self.Services.DataService:AddCoins(player, bundle.Coins)
	end
	for key, amount in bundle.Items or {} do
		self:AddItem(player, key, amount)
	end
	self:Sync(player)
end

function BeastService:BundleText(bundle): string
	local parts = {}
	if bundle.Coins then
		table.insert(parts, Format.Coins(bundle.Coins))
	end
	for key, amount in bundle.Items or {} do
		table.insert(parts, `{amount}x {Config.Items[key].Name}`)
	end
	return table.concat(parts, ", ")
end

---------------------------------------------------------------- Start

function BeastService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	-- Team aufraeumen (z. B. nach Big-Team-Ablauf oder geloeschten Bestien)
	local clean = {}
	for _, uid in data.Team do
		if data.Beasts[uid] and not table.find(clean, uid) then
			table.insert(clean, uid)
		end
	end
	data.Team = clean
	if not data.Started then
		self.Services.Net.ChooseStarter:FireClient(player)
	end
	self:Sync(player)
end

function BeastService:Start()
	local services = self.Services
	local net = services.Net

	net.PickStarter.OnServerEvent:Connect(function(player, beastId)
		local data = services.DataService:Get(player)
		if not data or data.Started or typeof(beastId) ~= "string" or not table.find(Config.Starters, beastId) then
			return
		end
		data.Started = true
		self:Add(player, beastId, 5)
		data.Caught = 0 -- der Starter zaehlt nicht als Fang
		services.DataService:UpdateAttributes(player)
		net.SendNotify(player, `{Config.BeastsById[beastId].Name} joined your team! Battle wild beasts in Sunny Meadow.`, GOLD)
	end)

	net.SetTeam.OnServerEvent:Connect(function(player, uids)
		local data = services.DataService:Get(player)
		if not data or typeof(uids) ~= "table" or services.BattleService:InBattle(player) then
			return
		end
		local team = {}
		for _, uid in uids do
			if typeof(uid) == "string" and data.Beasts[uid] and not table.find(team, uid) and #team < self:TeamSize(player) then
				table.insert(team, uid)
			end
		end
		if #team == 0 then
			return
		end
		data.Team = team
		self:Sync(player)
	end)

	net.ReleaseBeast.OnServerEvent:Connect(function(player, uid)
		local data = services.DataService:Get(player)
		if not data or typeof(uid) ~= "string" or not data.Beasts[uid] or services.BattleService:InBattle(player) then
			return
		end
		if count(data.Beasts) <= 1 then
			net.SendNotify(player, "You can't release your last beast.", RED)
			return
		end
		local entry = data.Beasts[uid]
		local coins = 10 * entry.L * Config.RaritiesByName[Config.BeastsById[entry.S].Rarity].Index
		data.Beasts[uid] = nil
		local index = table.find(data.Team, uid)
		if index then
			table.remove(data.Team, index)
		end
		if #data.Team == 0 then
			data.Team = { (next(data.Beasts)) }
		end
		services.DataService:AddCoins(player, coins)
		net.SendNotify(player, `Released {Config.BeastsById[entry.S].Name} (+{Format.Coins(coins)})`, GREEN)
		self:Sync(player)
	end)

	net.BuyItem.OnServerEvent:Connect(function(player, key, amount)
		local data = services.DataService:Get(player)
		local item = typeof(key) == "string" and Config.Items[key]
		if not data or not item or item.Price <= 0 or typeof(amount) ~= "number" then
			return
		end
		amount = math.clamp(math.floor(amount), 1, 99)
		local cost = item.Price * amount
		if data.Coins < cost then
			net.SendNotify(player, `Not enough coins (need {Format.Coins(cost)}).`, RED)
			services.MonetizationService:Offer(player, "CoinsSmall", "Short on coins? Grab a Coin Pouch!")
			return
		end
		services.DataService:AddCoins(player, -cost)
		self:AddItem(player, key, amount)
		net.SendNotify(player, `Bought {amount}x {item.Name}`, GREEN)
	end)

	net.Heal.OnServerEvent:Connect(function(player)
		if services.BattleService:InBattle(player) then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local spring = services.WorldService.SpringPosition
		if not root or not spring or (root.Position - spring).Magnitude > 22 then
			return
		end
		self:HealAll(player)
		net.SendNotify(player, "Your team is fully healed!", GREEN)
	end)

	-- Ausserhalb von Kaempfen langsam regenerieren
	task.spawn(function()
		while true do
			task.wait(6)
			for _, player in Players:GetPlayers() do
				local data = services.DataService:Get(player)
				if data and not services.BattleService:InBattle(player) then
					local changed = false
					for _, entry in data.Beasts do
						local max = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
						if entry.Hp < max then
							entry.Hp = math.min(max, entry.Hp + math.ceil(max * 0.02))
							changed = true
						end
					end
					if changed then
						self:Sync(player)
					end
				end
			end
		end
	end)
end

-- Farbe fuer prismatische Meldungen
BeastService.PrismColor = PRISM

return BeastService
