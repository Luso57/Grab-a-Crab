local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)

type Product = MonetizationTypes.Product
type ProductKey = MonetizationTypes.ProductKey

local products: { [ProductKey]: Product } = {
	doubleRolls = { id = 3707932495, permanent = true },
	doubleRollSpeed = { id = 3707932442, permanent = true },
	doublePermanentLuck = { id = 3707932569, permanent = true },
	quadruplePermanentLuck = { id = 3707932633, permanent = true },
	autoCollect = { id = 3707932721, permanent = true },
	autoCollectSlime = { id = 3708134057, permanent = true },
	doubleCash = { id = 3707932744, permanent = true },
	doubleSlimeDeposit = { id = 3708103686, permanent = true },
	buySlime = { id = 3708092210, permanent = false },
	buyUpgradeOne = { id = 3708140961, permanent = false },
	buyUpgradeTen = { id = 3708140981, permanent = false },
	luck99Spin = { id = 3708143307, permanent = false },
	finishNow = { id = 3708145865, permanent = false },
	doubleOfflineSlime = { id = 3708096713, permanent = false },
}

return products
