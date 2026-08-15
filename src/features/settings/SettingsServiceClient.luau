local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local MusicController = require(ReplicatedStorage.Source.Features.App.MusicController)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client

export type AudioSetting = "musicVolume" | "soundEffectsVolume"

local SettingsServiceClient = { initialized = false }

local function normalizeVolume(value: number): number
	return math.clamp(value, 0, 1)
end

local function applySetting(settingName: AudioSetting, volume: number)
	if settingName == "musicVolume" then
		MusicController.setMusicVolume(normalizeVolume(volume))
	else
		MusicController.setSoundEffectsVolume(normalizeVolume(volume))
	end
end

function SettingsServiceClient.init(self: SettingsServiceClient)
	if self.initialized then return end
	self.initialized = true
	self.networker = Networker.client.new("SettingsService", self)

	applySetting("musicVolume", PlayerData.musicVolume())
	applySetting("soundEffectsVolume", PlayerData.soundEffectsVolume())
	PlayerData.musicVolume.Changed(function(volume)
		applySetting("musicVolume", volume)
	end)
	PlayerData.soundEffectsVolume.Changed(function(volume)
		applySetting("soundEffectsVolume", volume)
	end)
end

function SettingsServiceClient.previewAudioVolume(_self: SettingsServiceClient, settingName: AudioSetting, volume: number)
	applySetting(settingName, volume)
end

function SettingsServiceClient.setAudioVolume(self: SettingsServiceClient, settingName: AudioSetting, volume: number)
	self:init()
	local normalized = normalizeVolume(volume)
	applySetting(settingName, normalized)
	self.networker:fire("setAudioVolume", settingName, normalized)
end

type SettingsServiceClient = typeof(SettingsServiceClient) & {
	initialized: boolean,
	networker: Networker.Client,
}

return SettingsServiceClient :: SettingsServiceClient
