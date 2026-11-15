--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)

local SettingsServiceServer = {}
local initialized = false

function SettingsServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	self.networker = Networker.server.new("SettingsService", self, { self.setPreference })
end

function SettingsServiceServer:setPreference(player: Player, preference: any, enabled: any)
	if player.Parent ~= Players or typeof(enabled) ~= "boolean" then
		return
	end
	if preference ~= "musicEnabled" and preference ~= "soundEffectsEnabled" then
		return
	end
	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players then
		return
	end
	if preference == "musicEnabled" then
		data.musicEnabled(enabled)
	else
		data.soundEffectsEnabled(enabled)
	end
end

return SettingsServiceServer
