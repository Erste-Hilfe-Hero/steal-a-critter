-- Kurze Klang-Rueckmeldungen fuer Knoepfe und Belohnungen. Nur eingebaute Roblox-Sounds (rbxasset://),
-- abschaltbar in den Einstellungen (Attribut Set_Sfx, vom Server gesetzt).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local Sounds = {}

local player = Players.LocalPlayer

-- Name -> Datei, Lautstaerke, Tonhoehe
local CUES = {
	Click = { "rbxasset://sounds/button.wav", 0.35, 1 },
	Reward = { "rbxasset://sounds/electronicpingshort.wav", 0.5, 1.15 },
	Quest = { "rbxasset://sounds/electronicpingshort.wav", 0.55, 0.9 },
	Achievement = { "rbxasset://sounds/victory.wav", 0.5, 1 },
	Tick = { "rbxasset://sounds/button.wav", 0.25, 1.6 },
	Error = { "rbxasset://sounds/button.wav", 0.35, 0.6 },
}

local cache = {} -- [Name] = Sound
local lastPlayed = {} -- [Name] = os.clock()

function Sounds.Enabled(): boolean
	return player:GetAttribute("Set_Sfx") ~= false
end

function Sounds.Play(name: string)
	local cue = CUES[name]
	if not cue or not Sounds.Enabled() then
		return
	end
	-- Nicht dasselbe Geraeusch mehrmals im selben Augenblick
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < 0.05 then
		return
	end
	lastPlayed[name] = now
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = cue[1]
		sound.Volume = cue[2]
		sound.PlaybackSpeed = cue[3]
		sound.Parent = SoundService
		cache[name] = sound
	end
	sound.TimePosition = 0
	sound:Play()
end

return Sounds
