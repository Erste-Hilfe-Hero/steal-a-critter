-- Begleiter: Die fuehrende Bestie jedes Spielers laeuft in der Welt hinter ihm her.
-- Wird nur auf dem Client gebaut und bewegt (spart Server-Leistung und Netzwerk).
-- Attribute vom Server: FollowerBeast, FollowerShiny und Set_Follower (Einstellung des Besitzers);
-- die eigene Einstellung Set_Others blendet die Begleiter anderer Spieler aus.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local BeastModel = require(ReplicatedStorage.Shared.BeastModel)

local Followers = {}

local player = Players.LocalPlayer

local SCALE = 0.55 -- Begleiter sind kleiner als im Kampf
local LEVEL = 20 -- feste Groesse, damit hohe Level nicht riesig werden
local VIEW_DISTANCE = 220

local folder: Folder
local followers = {} -- [Player] = { Model, Key, Pos, Hover, Look }
local warned = false

local function wanted(owner: Player): (string?, boolean)
	local id = owner:GetAttribute("FollowerBeast")
	if typeof(id) ~= "string" or not Config.BeastsById[id] then
		return nil, false
	end
	if owner:GetAttribute("Set_Follower") == false then
		return nil, false
	end
	if owner ~= player and player:GetAttribute("Set_Others") == false then
		return nil, false
	end
	return id, owner:GetAttribute("FollowerShiny") == true
end

local function remove(owner: Player)
	local follower = followers[owner]
	if follower then
		follower.Model:Destroy()
		followers[owner] = nil
	end
end

local function build(owner: Player, id: string, shiny: boolean)
	remove(owner)
	local model = BeastModel.Build(id, LEVEL, shiny)
	model:ScaleTo(SCALE)
	model.Name = "Follower_" .. owner.UserId
	followers[owner] = {
		Model = model,
		Key = id .. (if shiny then "*" else ""),
		Pos = nil :: Vector3?,
		Hover = BeastModel.Hover(id, BeastModel.Scale(id, LEVEL)) * SCALE,
		Look = Vector3.new(0, 0, -1),
	}
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
	for _, owner in Players:GetPlayers() do
		local id, shiny = wanted(owner)
		local follower = followers[owner]
		if not id then
			if follower then
				remove(owner)
			end
			continue
		end
		local key = id .. (if shiny then "*" else "")
		if not follower or follower.Key ~= key then
			build(owner, id, shiny)
			follower = followers[owner]
		end
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- Im Kampf oder Gespraech (verankert), tot oder weit weg: ausblenden
		if not root or root.Anchored or not humanoid or humanoid.Health <= 0 or (root.Position - cameraPos).Magnitude > VIEW_DISTANCE then
			follower.Model.Parent = nil
			follower.Pos = nil
			continue
		end
		local cf = root.CFrame
		local behind = cf.Position - cf.LookVector * 4.5 + cf.RightVector * 2.6
		local groundY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
		local target = Vector3.new(behind.X, groundY + follower.Hover, behind.Z)
		if not follower.Pos or (follower.Pos - target).Magnitude > 40 then
			follower.Pos = target
		end
		local pos = (follower.Pos :: Vector3):Lerp(target, math.min(1, dt * 5))
		local moved = (pos - (follower.Pos :: Vector3)).Magnitude
		follower.Pos = pos
		local flat = Vector3.new(root.Position.X - pos.X, 0, root.Position.Z - pos.Z)
		if flat.Magnitude > 0.2 then
			follower.Look = flat.Unit
		end
		-- Huepfen beim Laufen
		local bob = if moved > dt * 2 then math.abs(math.sin(os.clock() * 10 + owner.UserId)) * 0.35 else 0
		local at = pos + Vector3.new(0, bob, 0)
		follower.Model:PivotTo(CFrame.lookAt(at, at + follower.Look))
		if follower.Model.Parent ~= folder then
			follower.Model.Parent = folder
		end
	end
end

function Followers.Init()
	folder = Instance.new("Folder")
	folder.Name = "Followers"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(remove)
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(update, dt)
		if not ok and not warned then
			warned = true -- nur einmal melden, nicht jedes Bild
			warn("[Followers]", err)
		end
	end)
end

return Followers
