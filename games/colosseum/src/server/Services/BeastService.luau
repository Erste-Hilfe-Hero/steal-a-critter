-- Sammlung der Spieler: Team (max. 6) und Box, Attacken mit AP, Level, Entwicklung, Gegenstaende.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Beasts = require(ReplicatedStorage.Shared.Beasts)
local Story = require(ReplicatedStorage.Shared.Story)
local Format = require(ReplicatedStorage.Shared.Format)

local BeastService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 205, 70)
local GREEN = Color3.fromRGB(110, 230, 130)
local RED = Color3.fromRGB(255, 90, 90)
local PRISM = Color3.fromRGB(150, 255, 245)

local pendingStarter = {} -- [Player] = true, solange die Starter-Auswahl offen ist

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

---------------------------------------------------------------- Eintraege

-- Neuer Datensatz fuer eine Bestie (Attacken wie bei wilden Bestien dieses Levels)
function BeastService.MakeEntry(beastId: string, level: number, shiny: boolean?, hp: number?, moves: { string }?, status: string?)
	local stats = Config.Stats(beastId, level, shiny)
	local list = moves or Beasts.DefaultMoves(beastId, level)
	local pp = {}
	for i, key in list do
		pp[i] = Config.Moves[key].PP
	end
	return { S = beastId, L = level, X = 0, Sh = shiny == true, Hp = math.clamp(hp or stats.MaxHp, 0, stats.MaxHp), M = list, PP = pp, St = status }
end

-- Alte oder unvollstaendige Eintraege reparieren
local function fix(entry)
	if typeof(entry.M) ~= "table" or #entry.M == 0 then
		entry.M = Beasts.DefaultMoves(entry.S, entry.L)
		entry.PP = nil
	end
	if typeof(entry.PP) ~= "table" then
		entry.PP = {}
	end
	for i, key in entry.M do
		local move = Config.Moves[key]
		if typeof(entry.PP[i]) ~= "number" then
			entry.PP[i] = if move then move.PP else 0
		end
	end
end

local function syncEntry(entry)
	fix(entry)
	local stats = Config.Stats(entry.S, entry.L, entry.Sh)
	local moves = {}
	for i, key in entry.M do
		local move = Config.Moves[key]
		if move then
			table.insert(moves, { Key = key, Name = move.Name, Type = move.Type, Power = move.Power, Acc = move.Acc, PP = entry.PP[i] or 0, MaxPP = move.PP })
		end
	end
	return {
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
		St = entry.St,
		Moves = moves,
		Power = Config.Power(entry.S, entry.L, entry.Sh),
	}
end

-- Schickt die komplette Sammlung und den Fortschritt an den Client
function BeastService:Sync(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local beasts = {}
	for uid, entry in data.Beasts do
		beasts[uid] = syncEntry(entry)
	end
	self.Services.Net.Collection:FireClient(player, {
		Beasts = beasts,
		Team = data.Team,
		Items = data.Items,
		Capacity = self:Capacity(player),
		TeamSize = Config.TeamSize,
		Dex = data.Dex,
		Seen = data.Seen,
		Flags = data.Flags,
		Beaten = data.Beaten,
		Visited = data.Visited,
		Badges = data.Crests,
		Objective = Story.Objective(data.Flags, data.Crests),
		ObjectiveArea = Story.ObjectiveArea(data.Flags, data.Crests),
		Started = data.Started,
		GotStarter = data.GotStarter,
	})
	player:SetAttribute("BeastCount", count(data.Beasts))
	local lead = data.Beasts[data.Team[1]]
	player:SetAttribute("LeadLevel", if lead then lead.L else 1)
end

-- Neue Bestie: ins Team, wenn Platz ist, sonst in die Box. Gibt die uid zurueck (nil, wenn alles voll ist).
function BeastService:Add(player: Player, beastId: string, level: number, shiny: boolean?, hp: number?, moves: { string }?, status: string?): string?
	local data = self.Services.DataService:Get(player)
	if not data or not Config.BeastsById[beastId] then
		return nil
	end
	if count(data.Beasts) >= self:Capacity(player) + Config.TeamSize then
		self.Services.Net.SendNotify(player, "Your box is full! Release beasts or get more storage.", RED)
		self.Services.MonetizationService:Offer(player, "Storage", "Box full! Keep 50 more beasts?", true)
		return nil
	end
	local uid = tostring(data.NextId)
	data.NextId += 1
	data.Beasts[uid] = BeastService.MakeEntry(beastId, level, shiny, hp, moves and table.clone(moves), status)
	if #data.Team < Config.TeamSize then
		table.insert(data.Team, uid)
	else
		self.Services.Net.SendNotify(player, `{Config.BeastsById[beastId].Name} was sent to your Box.`, GOLD)
	end
	data.Dex[beastId] = true
	data.Seen[beastId] = true
	data.Caught += 1
	self.Services.DataService:UpdateAttributes(player)
	self:Sync(player)
	return uid
end

function BeastService:Get(player: Player, uid: string)
	local data = self.Services.DataService:Get(player)
	local entry = data and data.Beasts[uid]
	if entry then
		fix(entry)
	end
	return entry
end

-- Team-Bestien in Kampfreihenfolge
function BeastService:TeamEntries(player: Player): { { Uid: string, Entry: any } }
	local data = self.Services.DataService:Get(player)
	local list = {}
	if not data then
		return list
	end
	for _, uid in data.Team do
		local entry = data.Beasts[uid]
		if entry then
			fix(entry)
			table.insert(list, { Uid = uid, Entry = entry })
		end
		if #list >= Config.TeamSize then
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

-- KP, AP und Status komplett wiederherstellen
function BeastService:HealAll(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	for _, entry in data.Beasts do
		fix(entry)
		entry.Hp = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
		entry.St = nil
		for i, key in entry.M do
			entry.PP[i] = Config.Moves[key].PP
		end
	end
	self:Sync(player)
end

function BeastService:MarkSeen(player: Player, beastId: string)
	local data = self.Services.DataService:Get(player)
	if data and not data.Seen[beastId] then
		data.Seen[beastId] = true
	end
end

---------------------------------------------------------------- Level, Attacken und Entwicklung

-- Neue Attacke: bei freiem Platz sofort lernen, sonst Ereignis fuer die Auswahl auf dem Client
local function learn(entry, uid: string, key: string, events)
	if table.find(entry.M, key) then
		return
	end
	if #entry.M < Config.MaxMoves then
		table.insert(entry.M, key)
		entry.PP[#entry.M] = Config.Moves[key].PP
		table.insert(events, { T = "Learned", Uid = uid, S = entry.S, Move = key })
	else
		table.insert(events, { T = "LearnPrompt", Uid = uid, S = entry.S, Move = key })
	end
end

-- Entwicklung in die naechste Form. Gibt true zurueck, wenn es geklappt hat.
function BeastService:Evolve(player: Player, uid: string, force: boolean?): boolean
	local entry = self:Get(player, uid)
	if not entry then
		return false
	end
	local def = Config.BeastsById[entry.S]
	if not def.Evolve or (not force and entry.L < def.Evolve.Level) then
		return false
	end
	local before = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
	entry.S = def.Evolve.To
	local after = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
	entry.Hp = math.clamp(entry.Hp + (after - before), 0, after)
	local data = self.Services.DataService:Get(player)
	data.Dex[entry.S] = true
	data.Seen[entry.S] = true
	local newDef = Config.BeastsById[entry.S]
	if Config.RaritiesByName[newDef.Rarity].Index >= 3 then
		self.Services.Net.SendAnnounce(`{player.DisplayName}'s {def.Name} evolved into {newDef.Name}!`, GOLD)
	end
	return true
end

-- Alle faelligen Entwicklungen im Team (nach einem Kampf). Gibt Ereignisse fuer die Entwicklungs-Szene zurueck.
function BeastService:CheckEvolutions(player: Player): { any }
	local events = {}
	for _, item in self:TeamEntries(player) do
		local entry = item.Entry
		local from = entry.S
		local def = Config.BeastsById[from]
		if def.Evolve and entry.L >= def.Evolve.Level and self:Evolve(player, item.Uid) then
			table.insert(events, { T = "Evolve", Uid = item.Uid, From = from, To = entry.S })
			for _, key in Beasts.MovesAtLevel(entry.S, entry.L) do
				learn(entry, item.Uid, key, events)
			end
		end
	end
	return events
end

-- EP vergeben, Level-Ups und neue Attacken. Entwicklungen passieren erst nach dem Kampf (CheckEvolutions).
function BeastService:GiveXp(player: Player, uid: string, amount: number): { any }
	local entry = self:Get(player, uid)
	local events = {}
	if not entry or amount <= 0 or entry.L >= Config.MaxLevel then
		return events
	end
	entry.X += math.floor(amount)
	while entry.L < Config.MaxLevel and entry.X >= Config.XpToNext(entry.L) do
		entry.X -= Config.XpToNext(entry.L)
		local before = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
		entry.L += 1
		local after = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
		if entry.Hp > 0 then
			entry.Hp = math.min(after, entry.Hp + (after - before))
		end
		table.insert(events, { T = "Level", Uid = uid, S = entry.S, L = entry.L })
		for _, key in Beasts.MovesAtLevel(entry.S, entry.L) do
			learn(entry, uid, key, events)
		end
	end
	if entry.L >= Config.MaxLevel then
		entry.X = 0
	end
	-- Angebot, wenn die Entwicklung nur noch wenige Level entfernt ist
	local def = Config.BeastsById[entry.S]
	if def.Evolve and def.Evolve.Level - entry.L <= 3 and def.Evolve.Level > entry.L then
		self.Services.MonetizationService:Offer(player, "EvoCrystal", `{def.Name} is close to evolving! Evolve it NOW?`)
	end
	return events
end

function BeastService:AddLevels(player: Player, uid: string, levels: number): { any }
	local entry = self:Get(player, uid)
	if not entry then
		return {}
	end
	local need = 0
	for i = 0, levels - 1 do
		if entry.L + i < Config.MaxLevel then
			need += Config.XpToNext(entry.L + i)
		end
	end
	local events = self:GiveXp(player, uid, math.max(0, need - entry.X))
	for _, event in self:CheckEvolutions(player) do
		table.insert(events, event)
	end
	self:Sync(player)
	return events
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

-- Wirkung eines Heil-Gegenstands auf einen Datensatz oder Kaempfer. Gibt true zurueck, wenn er etwas bewirkt.
function BeastService.ItemUsable(item, hp: number, maxHp: number, status: string?): boolean
	if item.Revive then
		return hp <= 0
	elseif item.Heal then
		return hp > 0 and hp < maxHp
	elseif item.Cure then
		return hp > 0 and status ~= nil
	end
	return false
end

function BeastService.ApplyItem(item, target, maxHp: number)
	if item.Revive then
		target.Hp = math.max(1, math.floor(maxHp * item.Revive))
	elseif item.Heal then
		target.Hp = math.min(maxHp, target.Hp + item.Heal)
	elseif item.Cure then
		target.St = nil
		target.Status = nil
	end
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

---------------------------------------------------------------- Starter

function BeastService:OfferStarter(player: Player)
	pendingStarter[player] = true
	self.Services.Net.ChooseStarter:FireClient(player)
end

---------------------------------------------------------------- Start

function BeastService:OnPlayerReady(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	-- Team aufraeumen (z. B. nach geloeschten Bestien)
	local clean = {}
	for _, uid in data.Team do
		if data.Beasts[uid] and not table.find(clean, uid) and #clean < Config.TeamSize then
			table.insert(clean, uid)
		end
	end
	data.Team = clean
	for _, entry in data.Beasts do
		fix(entry)
	end
	self:Sync(player)
end

function BeastService:OnPlayerRemoving(player: Player)
	pendingStarter[player] = nil
end

function BeastService:Start()
	local services = self.Services
	local net = services.Net

	net.PickStarter.OnServerEvent:Connect(function(player, beastId)
		local data = services.DataService:Get(player)
		if not pendingStarter[player] or not data or data.Started or typeof(beastId) ~= "string" or not table.find(Config.Starters, beastId) then
			return
		end
		pendingStarter[player] = nil
		data.Started = true
		data.Starter = beastId
		self:Add(player, beastId, Config.StarterLevel)
		data.Caught = 0 -- der Starter zaehlt nicht als Fang
		services.DataService:UpdateAttributes(player)
		services.StoryService:OnStarterChosen(player, beastId)
	end)

	-- Reihenfolge des Teams aendern
	net.SetTeam.OnServerEvent:Connect(function(player, uids)
		local data = services.DataService:Get(player)
		if not data or typeof(uids) ~= "table" or services.BattleService:InBattle(player) then
			return
		end
		local team = {}
		for _, uid in uids do
			if typeof(uid) == "string" and data.Beasts[uid] and table.find(data.Team, uid) and not table.find(team, uid) then
				table.insert(team, uid)
			end
		end
		if #team ~= #data.Team then
			return
		end
		data.Team = team
		self:Sync(player)
	end)

	-- Zwischen Team und Box verschieben
	net.MoveBeast.OnServerEvent:Connect(function(player, uid, where)
		local data = services.DataService:Get(player)
		if not data or typeof(uid) ~= "string" or not data.Beasts[uid] or services.BattleService:InBattle(player) then
			return
		end
		local index = table.find(data.Team, uid)
		if where == "Box" and index then
			if #data.Team <= 1 then
				net.SendNotify(player, "You need at least one beast in your team.", RED)
				return
			end
			table.remove(data.Team, index)
		elseif where == "Team" and not index then
			if #data.Team >= Config.TeamSize then
				net.SendNotify(player, "Your team is full (6). Move a beast to the box first.", RED)
				return
			end
			table.insert(data.Team, uid)
		end
		self:Sync(player)
	end)

	-- Attacke auf einen Platz setzen (nur Attacken, die die Bestie auf ihrem Level kann)
	net.SetMove.OnServerEvent:Connect(function(player, uid, slot, key)
		local entry = typeof(uid) == "string" and self:Get(player, uid)
		if not entry or typeof(slot) ~= "number" or typeof(key) ~= "string" or services.BattleService:InBattle(player) then
			return
		end
		slot = math.floor(slot)
		if slot < 1 or slot > math.min(Config.MaxMoves, #entry.M + 1) or table.find(entry.M, key) or not Beasts.CanLearn(entry.S, key, entry.L) then
			return
		end
		entry.M[slot] = key
		entry.PP[slot] = Config.Moves[key].PP
		net.SendNotify(player, `{Config.BeastsById[entry.S].Name} learned {Config.Moves[key].Name}!`, GREEN)
		self:Sync(player)
	end)

	-- Heil-Gegenstaende ausserhalb von Kaempfen
	net.UseItem.OnServerEvent:Connect(function(player, key, uid)
		local item = typeof(key) == "string" and Config.Items[key]
		local entry = typeof(uid) == "string" and self:Get(player, uid)
		if not item or not entry or services.BattleService:InBattle(player) then
			return
		end
		local maxHp = Config.Stats(entry.S, entry.L, entry.Sh).MaxHp
		if not BeastService.ItemUsable(item, entry.Hp, maxHp, entry.St) then
			net.SendNotify(player, "It won't have any effect.", RED)
			return
		end
		if not self:UseItem(player, key) then
			return
		end
		BeastService.ApplyItem(item, entry, maxHp)
		net.SendNotify(player, `Used {item.Name} on {Config.BeastsById[entry.S].Name}.`, GREEN)
		self:Sync(player)
	end)

	net.ReleaseBeast.OnServerEvent:Connect(function(player, uid)
		local data = services.DataService:Get(player)
		if not data or typeof(uid) ~= "string" or not data.Beasts[uid] or services.BattleService:InBattle(player) then
			return
		end
		if count(data.Beasts) <= 1 or (table.find(data.Team, uid) and #data.Team <= 1) then
			net.SendNotify(player, "You can't release your last team member.", RED)
			return
		end
		local entry = data.Beasts[uid]
		local coins = 30 * entry.L * Config.RaritiesByName[Config.BeastsById[entry.S].Rarity].Index
		data.Beasts[uid] = nil
		local index = table.find(data.Team, uid)
		if index then
			table.remove(data.Team, index)
		end
		services.DataService:AddCoins(player, coins)
		net.SendNotify(player, `Released {Config.BeastsById[entry.S].Name} (+{Format.Coins(coins)})`, GREEN)
		self:Sync(player)
	end)

	net.BuyItem.OnServerEvent:Connect(function(player, key, amount)
		local data = services.DataService:Get(player)
		local item = typeof(key) == "string" and Config.Items[key]
		if not data or not item or item.Price <= 0 or typeof(amount) ~= "number" or data.Crests < item.Badges then
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
end

-- Farbe fuer prismatische Meldungen
BeastService.PrismColor = PRISM

return BeastService
