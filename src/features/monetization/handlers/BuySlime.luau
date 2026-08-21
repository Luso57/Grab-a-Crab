local ServerScriptService = game:GetService("ServerScriptService")

local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)

return function(productKey: string)
	return function(player: Player, receiptInfo: { PurchaseId: string }): boolean
		local plot = PlotServiceServer:getPlayerPlot(player)
		if not plot then
			return false
		end

		return plot:completeBuySlimeReceipt(receiptInfo.PurchaseId, productKey)
	end
end
