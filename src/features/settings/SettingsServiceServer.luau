local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).server

local VALID_SETTINGS = {
	musicVolume = true,
	soundEffectsVolume = true,
}

local SettingsServiceServer = {}

function SettingsServiceServer.init(self: SettingsServiceServer)
	self.networker = Networker.server.new("SettingsService", self, { self.setAudioVolume })

	local function migratePlayer(player: Player)
		Data.Service:waitForData(player)
		local playerData = Data[player]
		if not playerData or player.Parent ~= Players then return end

		if playerData.musicVolume() < 0 then
			playerData.musicVolume(if playerData.musicEnabled() then 1 else 0)
		end
		if playerData.soundEffectsVolume() < 0 then
			playerData.soundEffectsVolume(if playerData.soundEffectsEnabled() then 1 else 0)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(migratePlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(migratePlayer, player)
	end
end

function SettingsServiceServer.setAudioVolume(
	self: SettingsServiceServer,
	player: Player,
	settingName: string,
	volume: number
)
	if typeof(settingName) ~= "string" or typeof(volume) ~= "number" or volume ~= volume or not VALID_SETTINGS[settingName] then
		return
	end
	volume = math.clamp(volume, 0, 1)

	local playerData = Data[player]
	if not playerData then return end

	if settingName == "musicVolume" then
		playerData.musicVolume(volume)
	else
		playerData.soundEffectsVolume(volume)
	end
end

type SettingsServiceServer = typeof(SettingsServiceServer) & {
	networker: Networker.Server,
}

return SettingsServiceServer :: SettingsServiceServer
