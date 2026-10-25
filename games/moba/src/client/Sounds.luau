-- Kurze Klangeffekte (nur eingebaute Roblox-Sounds). Abschaltbar in den Einstellungen (Attribut "Setting_Sound").
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Sounds = {}

local player = Players.LocalPlayer

local PING = "rbxasset://sounds/electronicpingshort.wav"
local CLICK = "rbxasset://sounds/clickfast.wav"

-- Name -> Datei, Lautstaerke, Tonhoehe
local LIST = {
	Click = { CLICK, 0.35, 1 },
	Ping = { PING, 0.55, 1 },
	Emote = { PING, 0.35, 1.8 },
	LevelUp = { PING, 0.6, 1.4 },
	Kill = { PING, 0.6, 0.8 },
	Slain = { PING, 0.5, 0.55 },
	Reward = { PING, 0.6, 1.2 },
	Victory = { PING, 0.7, 1.6 },
	Defeat = { PING, 0.6, 0.6 },
}

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

function Sounds.Enabled(): boolean
	return player:GetAttribute("Setting_Sound") ~= false
end

function Sounds.Play(name: string)
	local info = LIST[name]
	if not info or not Sounds.Enabled() then
		return
	end
	-- Nicht dutzendfach im selben Moment
	local t = os.clock()
	if t - (lastPlayed[name] or 0) < 0.06 then
		return
	end
	lastPlayed[name] = t
	local sound = cache[name]
	if not sound then
		local created = Instance.new("Sound")
		created.Name = "Sfx_" .. name
		created.SoundId = info[1]
		created.Volume = info[2]
		created.PlaybackSpeed = info[3]
		created.Parent = SoundService
		cache[name] = created
		sound = created
	end
	pcall(SoundService.PlayLocalSound, SoundService, sound)
end

return Sounds
