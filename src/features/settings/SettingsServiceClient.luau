--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local PopupMenuState = require(ReplicatedStorage.Source.Game.PopupMenuState)
local SettingsRoot = require(script.Parent.UI.SettingsRoot)

local SettingsServiceClient = {}
local initialized = false

local function getGroup(name: string): SoundGroup
	local existing = SoundService:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = SoundService
	return group
end

function SettingsServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local networker = Networker.client.new("SettingsService", self)
	local musicEnabled = Vide.source(Data.musicEnabled())
	local soundEffectsEnabled = Vide.source(Data.soundEffectsEnabled())
	local musicGroup = getGroup("GameMusic")
	local effectsGroup = getGroup("GameSoundEffects")
	musicGroup.Volume = if musicEnabled() then 1 else 0
	effectsGroup.Volume = if soundEffectsEnabled() then 1 else 0

	local music = SoundService:FindFirstChild("BackgroundMusic")
	if not music or not music:IsA("Sound") then
		music = Instance.new("Sound")
		music.Name = "BackgroundMusic"
		music.Parent = SoundService
	end
	local backgroundMusic = music :: Sound
	backgroundMusic.SoundId = "rbxassetid://108976182278747"
	backgroundMusic.Looped = true
	backgroundMusic.Volume = 0.25
	backgroundMusic.SoundGroup = musicGroup
	if not backgroundMusic.IsPlaying then
		backgroundMusic:Play()
	end

	local function routeSound(instance: Instance)
		if instance:IsA("Sound") then
			instance.SoundGroup = if instance == backgroundMusic then musicGroup else effectsGroup
		end
	end
	for _, descendant in game:GetDescendants() do
		routeSound(descendant)
	end
	game.DescendantAdded:Connect(routeSound)

	Data.musicEnabled.Changed(function(enabled: boolean)
		musicEnabled(enabled)
		musicGroup.Volume = if enabled then 1 else 0
	end)
	Data.soundEffectsEnabled.Changed(function(enabled: boolean)
		soundEffectsEnabled(enabled)
		effectsGroup.Volume = if enabled then 1 else 0
	end)

	local function setMusic(enabled: boolean)
		musicEnabled(enabled)
		musicGroup.Volume = if enabled then 1 else 0
		networker:fire("setPreference", "musicEnabled", enabled)
	end
	local function setEffects(enabled: boolean)
		soundEffectsEnabled(enabled)
		effectsGroup.Volume = if enabled then 1 else 0
		networker:fire("setPreference", "soundEffectsEnabled", enabled)
	end

	Vide.mount(function()
		return SettingsRoot({
			isOpen = PopupMenuState.isOpen("Settings"),
			musicEnabled = musicEnabled,
			soundEffectsEnabled = soundEffectsEnabled,
			onToggle = function()
				PopupMenuState.toggle("Settings")
			end,
			onClose = function()
				PopupMenuState.close("Settings")
			end,
			onMusicChanged = setMusic,
			onEffectsChanged = setEffects,
		})
	end, playerGui)
end

return SettingsServiceClient
