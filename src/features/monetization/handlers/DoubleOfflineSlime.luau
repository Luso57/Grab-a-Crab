local ServerScriptService = game:GetService("ServerScriptService")

local OfflineRewardsServiceServer = require(ServerScriptService.Features.Offlinerewards.OfflineRewardsServiceServer)

return function(player: Player): boolean
	return OfflineRewardsServiceServer:grantDoubleReceipt(player)
end
