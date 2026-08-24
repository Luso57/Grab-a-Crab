local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SlimeDropClient = require(ReplicatedStorage.Source.Features.Events.Events.Slimedrop.SlimeDropClient)

return {
	slimeDrop = SlimeDropClient,
}
