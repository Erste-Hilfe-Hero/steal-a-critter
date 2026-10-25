-- Kurze Soundeffekte (nur eingebaute Roblox-Sounds, keine fremden Assets).
-- Abschaltbar in MORE > SETTINGS (Attribut SoundsOff am Spieler).
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local Sfx = {}

local SOUNDS = {
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	Reward = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.25 },
	Steal = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5 },
	Alarm = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.7, Pitch = 0.8 },
	Slap = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.6 },
	Error = { Id = "rbxasset://sounds/collide.wav", Volume = 0.4 },
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.4 },
	Hatch = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.6 },
	Jump = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.7, Pitch = 1.3 },
}

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}

function Sfx.Play(name: string)
	local entry = SOUNDS[name]
	if not entry or player:GetAttribute("SoundsOff") == true then
		return
	end
	-- Nicht denselben Sound mehrmals im selben Moment (z.B. viele Toasts auf einmal)
	local now = os.clock()
	if now - (lastPlayed[name] or 0) < 0.08 then
		return
	end
	lastPlayed[name] = now
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. name
		sound.SoundId = entry.Id
		sound.Volume = entry.Volume
		sound.PlaybackSpeed = entry.Pitch or 1
		sound.Parent = SoundService
		cache[name] = sound
	end
	SoundService:PlayLocalSound(sound)
end

return Sfx
