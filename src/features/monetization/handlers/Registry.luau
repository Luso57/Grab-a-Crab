local grantPermanentProduct = require(script.Parent.GrantPermanentProduct)

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
	doubleOfflineSlime = require(script.Parent.DoubleOfflineSlime),
}

local Registry = {}

function Registry.registerAll(monetizationService: any)
	for productKey, handler in handlers do
		monetizationService:registerHandler(productKey, handler)
	end
end

return Registry
