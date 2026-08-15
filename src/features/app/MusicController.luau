local SoundService = game:GetService("SoundService")

local NORMAL_TRACK_IDS = {
	"rbxassetid://1840684208",
	"rbxassetid://1840383931",
	"rbxassetid://1840383846",
}
local EVENT_TRACK_ID = "rbxassetid://125421681778301"
local NORMAL_VOLUME = 0.35
local EVENT_VOLUME = 0.5
local MUSIC_GROUP_NAME = "RNGMusic"
local SOUND_EFFECTS_GROUP_NAME = "RNGSoundEffects"

local MusicController = {}
local initialized = false
local eventActive = false
local currentTrackIndex = 1
local normalSound: Sound
local eventSound: Sound
local musicGroup: SoundGroup
local soundEffectsGroup: SoundGroup

local function getOrCreateSoundGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end

	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

local function routeSound(sound: Sound)
	if sound == normalSound or sound == eventSound then
		sound.SoundGroup = musicGroup
	else
		sound.SoundGroup = soundEffectsGroup
	end
end

local function playCurrentTrack()
	normalSound.SoundId = NORMAL_TRACK_IDS[currentTrackIndex]
	normalSound.TimePosition = 0
	normalSound:Play()
end

function MusicController.init()
	if initialized then return end
	initialized = true
	musicGroup = getOrCreateSoundGroup(MUSIC_GROUP_NAME)
	soundEffectsGroup = getOrCreateSoundGroup(SOUND_EFFECTS_GROUP_NAME)

	normalSound = Instance.new("Sound")
	normalSound.Name = "BackgroundMusic"
	normalSound.Volume = NORMAL_VOLUME
	normalSound.SoundGroup = musicGroup
	normalSound.Parent = SoundService
	normalSound.Ended:Connect(function()
		if eventActive then return end
		currentTrackIndex = currentTrackIndex % #NORMAL_TRACK_IDS + 1
		playCurrentTrack()
	end)

	eventSound = Instance.new("Sound")
	eventSound.Name = "SlimeEventMusic"
	eventSound.SoundId = EVENT_TRACK_ID
	eventSound.Volume = EVENT_VOLUME
	eventSound.Looped = true
	eventSound.SoundGroup = musicGroup
	eventSound.Parent = SoundService

	for _, descendant in game:GetDescendants() do
		if descendant:IsA("Sound") then
			routeSound(descendant)
		end
	end

	game.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("Sound") then
			routeSound(descendant)
		end
	end)

	playCurrentTrack()
end

function MusicController.setMusicVolume(volume: number)
	MusicController.init()
	musicGroup.Volume = math.clamp(volume, 0, 1)
end

function MusicController.setSoundEffectsVolume(volume: number)
	MusicController.init()
	soundEffectsGroup.Volume = math.clamp(volume, 0, 1)
end

function MusicController.startEventMusic()
	MusicController.init()
	if eventActive then return end
	eventActive = true
	normalSound:Pause()
	eventSound:Play()
end

function MusicController.stopEventMusic()
	MusicController.init()
	if not eventActive then return end
	eventActive = false
	eventSound:Stop()
	normalSound:Resume()
end

return MusicController
