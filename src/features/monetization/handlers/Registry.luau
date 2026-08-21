local grantPermanentProduct = require(script.Parent.GrantPermanentProduct)
local createBuySlimeHandler = require(script.Parent.BuySlime)
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
local function grant5xLuckSpin(player: Player): boolean
	local plot = PlotServiceServer:getPlayerPlot(player)
	if not plot then
		return false
	end
	return plot:complete5xLuckSpinReceipt()
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
	buyCommonSlime = createBuySlimeHandler("buyCommonSlime"),
	buyUncommonSlime = createBuySlimeHandler("buyUncommonSlime"),
	buyRareSlime = createBuySlimeHandler("buyRareSlime"),
	buyEpicSlime = createBuySlimeHandler("buyEpicSlime"),
	buyLegendarySlime = createBuySlimeHandler("buyLegendarySlime"),
	buyExoticSlime = createBuySlimeHandler("buyExoticSlime"),
	buySecretSlime = createBuySlimeHandler("buySecretSlime"),
	buyUpgradeOne = grantUpgradeOne,
	buyUpgradeTen = grantUpgradeTen,
	luck5Spin = grant5xLuckSpin,
	finishNow = grantFinishNow,
	skipRebirth = require(script.Parent.SkipRebirth),
	doubleOfflineSlime = require(script.Parent.DoubleOfflineSlime),
}

local Registry = {}

function Registry.registerAll(monetizationService: any)
	for productKey, handler in handlers do
		monetizationService:registerHandler(productKey, handler)
	end
end

return Registry
