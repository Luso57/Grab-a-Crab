local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SlimeDropConfig = require(ReplicatedStorage.Source.Features.Events.Events.Slimedrop.SlimeDropConfig)
local SlimeDropServer = require(ServerScriptService.Features.Events.Events.Slimedrop.SlimeDropServer)

return {
	{
		id = "slimeDrop",
		displayName = "Slime Event",
		weight = 1,
		duration = 300,
		notificationText = SlimeDropConfig.EventStartNotificationText,
		soundId = SlimeDropConfig.EventStartSoundId,
		soundVolume = SlimeDropConfig.EventStartSoundVolume,
		server = SlimeDropServer,
	},
}
