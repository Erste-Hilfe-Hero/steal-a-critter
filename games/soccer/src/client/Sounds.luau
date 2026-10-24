-- Alle Sounds im Soccer-Jam-Stil: Schuss, Aufprall, Ballannahme, Pfiff, Tor-Sirene, Publikum, Messer,
-- Smack, Level-up, Alien-Zap und der Stadionsprecher (eigene Nachbauten, keine Original-Dateien).
-- Die eigenen Sounds (assets/make_sounds.py) stehen in SoundIds.json; solange eine ID 0 ist,
-- springt ein eingebauter Roblox-Sound ein.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundIds = require(ReplicatedStorage.Shared.SoundIds)
local VoiceLines = require(ReplicatedStorage.Shared.VoiceLines)

local Sounds = {}

local FALLBACK = {
	kick = "rbxasset://sounds/collide.wav",
	steal = "rbxasset://sounds/swordlunge.wav",
	smack = "rbxasset://sounds/collide.wav",
	beep = "rbxasset://sounds/electronicpingshort.wav",
	whistle = "rbxasset://sounds/electronicpingshort.wav",
	whistle_end = "rbxasset://sounds/electronicpingshort.wav",
	horn = "rbxasset://sounds/victory.wav",
	siren = "rbxasset://sounds/victory.wav",
	gotball = "rbxasset://sounds/button.wav",
	levelup = "rbxasset://sounds/electronicpingshort.wav",
	zap = "rbxasset://sounds/electronicpingshort.wav",
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
	Siren = { "siren", 0.6, 1 },
	GotBall = { "gotball", 0.5, 1 },
	LevelUp = { "levelup", 0.6, 1 },
	Zap = { "zap", 0.7, 1 },
	Bounce = { "kick", 0.5, 0.75 },
	Jump = { "steal", 0.35, 1.3 },
	Call = { "beep", 0.5, 1.25 },
	Post = { "kick", 0.9, 1.9 },
	HitMarker = { "gotball", 0.35, 1.8 },
	Quest = { "levelup", 0.5, 1.2 },
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

-- Stadionsprecher: ein Satz aus announcer.ogg (Startzeit und Laenge aus VoiceLines)
local announcerId = SoundIds.announcer
local current: Sound? = nil
function Sounds.Say(line: string)
	local segment = VoiceLines[line]
	if not segment or not announcerId or announcerId == 0 then
		return
	end
	task.spawn(function()
		if current then
			current:Destroy()
		end
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. announcerId
		sound.Volume = 1
		sound.SoundGroup = group
		sound.Parent = SoundService
		current = sound
		local deadline = os.clock() + 3
		while not sound.IsLoaded and os.clock() < deadline and sound.Parent do
			task.wait()
		end
		if not sound.Parent then
			return
		end
		sound.TimePosition = segment[1]
		sound:Play()
		task.wait(segment[2])
		sound:Destroy()
		if current == sound then
			current = nil
		end
	end)
end

-- Ansage-Datei frueh laden, damit die erste Durchsage nicht haengt
if announcerId and announcerId ~= 0 then
	task.spawn(function()
		local preload = Instance.new("Sound")
		preload.SoundId = "rbxassetid://" .. announcerId
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({ preload })
		end)
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

-- Publikum: Lautstaerke aus den Einstellungen (0..1) mal "Swell" (lauter, wenn der Ball vors Tor kommt)
local crowdSetting, crowdSwell = 1, 1
local function applyCrowd()
	if crowd then
		crowd.Volume = 0.25 * crowdSetting * crowdSwell
	end
end
function Sounds.SetCrowdVolume(value: number)
	crowdSetting = value
	applyCrowd()
end
function Sounds.SetCrowdSwell(value: number)
	crowdSwell = value
	applyCrowd()
end

return Sounds
