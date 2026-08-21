local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)

return function(player: Player): boolean
	local playerData = Data[player]
	if not playerData then
		return false
	end

	playerData.rebirths(function(previous)
		return RebirthConfig.getCount(previous) + 1
	end)
	return true
end
