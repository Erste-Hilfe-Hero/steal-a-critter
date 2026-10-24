-- Alle Sounds im Soccer-Jam-Stil: Schuss, Pfiff, Tor-Hupe, Publikum, Disarm, Smack, Countdown.
-- Die eigenen Sounds (assets/make_sounds.py) stehen in SoundIds.json; solange eine ID 0 ist,
-- springt ein eingebauter Roblox-Sound ein.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundIds = require(ReplicatedStorage.Shared.SoundIds)

local Sounds = {}

local FALLBACK = {
	kick = "rbxasset://sounds/collide.wav",
	steal = "rbxasset://sounds/swordlunge.wav",
	smack = "rbxasset://sounds/collide.wav",
	beep = "rbxasset://sounds/electronicpingshort.wav",
	whistle = "rbxasset://sounds/electronicpingshort.wav",
	whistle_end = "rbxasset://sounds/electronicpingshort.wav",
	horn = "rbxasset://sounds/victory.wav",
	slash = "rbxasset://sounds/swordslash.wav",
	stab = "rbxasset://sounds/swordlunge.wav",
}

-- Name aus dem Spiel -> Datei, Lautstaerke, Tonhoehe
local CUES = {
	Kick = { "kick", 0.8, 1 },
	Steal = { "steal", 0.7, 1 },
	Dodge = { "steal", 0.5, 0.7 },
	Smack = { "smack", 0.9, 1 },
	Save = { "cheer", 0.45, 1.1 },
	Ooh = { "ooh", 0.6, 1 },
	Whistle = { "whistle", 0.6, 1 },
	WhistleEnd = { "whistle_end", 0.6, 1 },
	Horn = { "horn", 0.7, 1 },
	Cheer = { "cheer", 0.8, 1 },
	Beep = { "beep", 0.5, 1 },
	Slash = { "slash", 0.6, 1.1 },
	Stab = { "stab", 0.7, 0.9 },
	Hit = { "smack", 0.5, 1.6 },
	Go = { "beep", 0.6, 1.5 },
}

local group = Instance.new("SoundGroup")
group.Name = "SoccerJamSfx"
group.Volume = 1
group.Parent = SoundService

local function idFor(file: string): string?
	local id = SoundIds[file]
	if id and id ~= 0 then
		return "rbxassetid://" .. id
	end
	return FALLBACK[file]
end

-- position: 3D-Sound an dieser Stelle, sonst ueberall gleich laut
function Sounds.Play(name: string, position: Vector3?, pitch: number?, volume: number?)
	local cue = CUES[name]
	local id = cue and idFor(cue[1])
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = cue[2] * (volume or 1)
	sound.PlaybackSpeed = cue[3] * (pitch or 1)
	sound.SoundGroup = group
	local holder: Instance = SoundService
	if position then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = position
		attachment.Parent = workspace.Terrain
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 30
		sound.RollOffMaxDistance = 320
		holder = attachment
	end
	sound.Parent = holder
	sound.Ended:Connect(function()
		(if holder == SoundService then sound else holder):Destroy()
	end)
	sound:Play()
	task.delay(8, function()
		if sound.Parent then
			(if holder == SoundService then sound else holder):Destroy()
		end
	end)
end

-- Stadion-Atmosphaere als Endlosschleife
local crowd: Sound?
function Sounds.StartCrowd()
	local id = idFor("crowd")
	if not id or crowd then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = true
	sound.Volume = 0.25
	sound.SoundGroup = group
	sound.Parent = SoundService
	sound:Play()
	crowd = sound
end

return Sounds
