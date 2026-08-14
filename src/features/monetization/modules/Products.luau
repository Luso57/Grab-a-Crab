local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)

type Product = MonetizationTypes.Product
type ProductKey = MonetizationTypes.ProductKey

local products: { [ProductKey]: Product } = {
	doubleRolls = { id = 3707932495 },
	doubleRollSpeed = { id = 3707932442 },
	doublePermanentLuck = { id = 3707932569 },
	quadruplePermanentLuck = { id = 3707932633 },
	autoCollect = { id = 3707932721 },
	doubleCash = { id = 3707932744 },
}

return products