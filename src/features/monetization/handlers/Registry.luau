local grantPermanentProduct = require(script.Parent.GrantPermanentProduct)
local ServerScriptService = game:GetService("ServerScriptService")
local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)

local function grantUpgrade(player: Player, quantity: number): boolean
	local plot = PlotServiceServer:getPlayerPlot(player)
	if not plot then
		return false
	end
	return plot:completeUpgradeReceipt(quantity)
end

local function grantUpgradeOne(player: Player): boolean
	return grantUpgrade(player, 1)
end

local function grantUpgradeTen(player: Player): boolean
	return grantUpgrade(player, 10)
end
local function grant99xLuckSpin(player: Player): boolean
	local plot = PlotServiceServer:getPlayerPlot(player)
	if not plot then
		return false
	end
	return plot:complete99xLuckSpinReceipt()
end
local function grantFinishNow(player: Player): boolean
	local plot = PlotServiceServer:getPlayerPlot(player)
	if not plot then
		return false
	end
	return plot:completeFinishNowReceipt()
end

local function grantAutoCollectSlime(player: Player): boolean
	return grantPermanentProduct(player, "autoCollectSlime")
end

local handlers = {
	doubleRolls = require(script.Parent.DoubleRolls),
	doubleRollSpeed = require(script.Parent.DoubleRollSpeed),
	doublePermanentLuck = require(script.Parent.DoublePermanentLuck),
	quadruplePermanentLuck = require(script.Parent.QuadruplePermanentLuck),
	autoCollect = require(script.Parent.AutoCollect),
	autoCollectSlime = grantAutoCollectSlime,
	doubleCash = require(script.Parent.DoubleCash),
	doubleSlimeDeposit = require(script.Parent.DoubleSlimeDeposit),
	buySlime = require(script.Parent.BuySlime),
	buyUpgradeOne = grantUpgradeOne,
	buyUpgradeTen = grantUpgradeTen,
	luck99Spin = grant99xLuckSpin,
	finishNow = grantFinishNow,
	doubleOfflineSlime = require(script.Parent.DoubleOfflineSlime),
}

local Registry = {}

function Registry.registerAll(monetizationService: any)
	for productKey, handler in handlers do
		monetizationService:registerHandler(productKey, handler)
	end
end

return Registry
