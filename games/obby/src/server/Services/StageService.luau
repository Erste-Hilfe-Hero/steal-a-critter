-- Fortschritt: Checkpoints, Respawn am letzten Checkpoint, Ziel/Wins und Stage-Skips.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local StageService = { Services = nil :: any }

local GOLD = Color3.fromRGB(255, 200, 40)
local GREEN = Color3.fromRGB(90, 220, 120)

local finishing = {} -- [Player] = true, solange der Sieg verarbeitet wird
local lastDeath = {} -- [Player] = os.clock()

function StageService:Init(services)
	self.Services = services
end

local function playerFromHit(hit: BasePart): (Player?, Humanoid?)
	local character = hit:FindFirstAncestorOfClass("Model")
	local player = character and Players:GetPlayerFromCharacter(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if player and humanoid and humanoid.Health > 0 then
		return player, humanoid
	end
	return nil, nil
end

function StageService:Teleport(player: Player)
	local data = self.Services.DataService:Get(player)
	local character = player.Character
	if not data or not character then
		return
	end
	character:PivotTo(self.Services.WorldService:SpawnCFrame(data.Stage))
end

function StageService:SetStage(player: Player, stage: number, teleport: boolean)
	local data = self.Services.DataService:Get(player)
	if not data then
		return
	end
	local previousWorld = select(2, Config.WorldForStage(data.Stage))
	data.Stage = math.clamp(stage, 1, Config.StageCount)
	local newRecord = data.Stage > data.BestStage
	data.BestStage = math.max(data.BestStage, data.Stage)
	self.Services.DataService:UpdateAttributes(player)
	local world, worldIndex = Config.WorldForStage(data.Stage)
	if worldIndex > previousWorld and newRecord then
		self.Services.Net.SendAnnounce(`{player.DisplayName} reached World {worldIndex}: {world.Name}!`, world.Accent)
	end
	if teleport then
		self:Teleport(player)
	end
	self.Services.CosmeticService:UpdateNameTag(player)
end

-- Fuer Skip-Produkte. Wer ueber die letzte Stage hinaus springt, landet im Ziel.
function StageService:Skip(player: Player, stages: number): boolean
	local data = self.Services.DataService:Get(player)
	if not data then
		return false
	end
	if data.Stage + stages > Config.StageCount then
		task.defer(self.Win, self, player)
		return true
	end
	self:SetStage(player, data.Stage + stages, true)
	self.Services.Net.SendNotify(player, `Skipped to stage {data.Stage}!`, GREEN)
	return true
end

function StageService:Win(player: Player)
	local data = self.Services.DataService:Get(player)
	if not data or finishing[player] then
		return
	end
	finishing[player] = true
	data.Wins += 1
	data.BestStage = Config.StageCount
	self.Services.Net.SendAnnounce(`{player.DisplayName} BEAT ALL {Config.StageCount} STAGES! (Win #{data.Wins})`, GOLD)
	self.Services.Net.SendNotify(player, "You won! New trails unlocked - run again for more Wins!", GOLD)
	data.Stage = 1
	self.Services.DataService:UpdateAttributes(player)
	self.Services.CosmeticService:Refresh(player)
	task.spawn(self.Services.DataService.Save, self.Services.DataService, player)
	task.wait(2)
	self:Teleport(player)
	finishing[player] = nil
end

function StageService:Kill(player: Player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

function StageService:OnCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart")
	task.defer(function()
		if character.Parent then
			self:Teleport(player)
		end
	end)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		local data = self.Services.DataService:Get(player)
		if data then
			data.Deaths += 1
		end
	end)
end

function StageService:OnPlayerRemoving(player: Player)
	finishing[player] = nil
	lastDeath[player] = nil
end

function StageService:Start()
	local world = self.Services.WorldService

	for stage, pad in world.Checkpoints do
		pad.Touched:Connect(function(hit)
			local player = playerFromHit(hit)
			local data = player and self.Services.DataService:Get(player)
			if player and data and stage > data.Stage and not finishing[player] then
				self:SetStage(player, stage, false)
			end
		end)
	end

	world.Finish.Touched:Connect(function(hit)
		local player = playerFromHit(hit)
		local data = player and self.Services.DataService:Get(player)
		-- Nur wer auf der letzten Stage ist, kann gewinnen (keine Abkuerzung von weit vorne)
		if player and data and data.Stage == Config.StageCount then
			self:Win(player)
		end
	end)

	-- Der Client meldet Kill-Teile und Stuerze, der Server vollstreckt
	self.Services.Net.Died.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastDeath[player] or 0) < 0.5 then
			return
		end
		lastDeath[player] = now
		self:Kill(player)
	end)
end

return StageService
