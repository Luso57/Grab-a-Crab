--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local Money = require(ReplicatedStorage.Source.Game.Money)

local CoinBundles = {
	Small = { productId = ProductIds.SmallCoins, multiplier = 2 },
	Medium = { productId = ProductIds.MediumCoins, multiplier = 4 },
	Large = { productId = ProductIds.LargeCoins, multiplier = 10 },
}

CoinBundles.byProductId = {
	[ProductIds.SmallCoins] = CoinBundles.Small,
	[ProductIds.MediumCoins] = CoinBundles.Medium,
	[ProductIds.LargeCoins] = CoinBundles.Large,
}

function CoinBundles.getAmount(highestMoney: number | string, multiplier: number): string
	return Money.multiplySmall(highestMoney, multiplier)
end

return CoinBundles
