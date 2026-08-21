local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)
local Products = require(ReplicatedStorage.Source.Features.Monetization.Modules.Products)

type ProductKey = MonetizationTypes.ProductKey

local rarityToProductKey: { [string]: ProductKey } = {
	Common = "buyCommonSlime",
	Uncommon = "buyUncommonSlime",
	Rare = "buyRareSlime",
	Epic = "buyEpicSlime",
	Legendary = "buyLegendarySlime",
	Exotic = "buyExoticSlime",
	Secret = "buySecretSlime",
}

local productKeyToRarity: { [string]: string } = {}
local productIdToKey: { [number]: ProductKey } = {}
for rarity, productKey in rarityToProductKey do
	productKeyToRarity[productKey] = rarity
	productIdToKey[Products[productKey].id] = productKey
end

local SlimePurchaseProducts = {}

function SlimePurchaseProducts.getProductKey(rarity: string): ProductKey?
	return rarityToProductKey[rarity]
end

function SlimePurchaseProducts.getRarity(productKey: string): string?
	return productKeyToRarity[productKey]
end

function SlimePurchaseProducts.getProductKeyFromId(productId: number): ProductKey?
	return productIdToKey[productId]
end

function SlimePurchaseProducts.isProductKey(productKey: string): boolean
	return productKeyToRarity[productKey] ~= nil
end

return SlimePurchaseProducts
