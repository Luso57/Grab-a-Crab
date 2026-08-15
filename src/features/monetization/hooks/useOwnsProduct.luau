local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)

type ProductKey = MonetizationTypes.ProductKey

local function useOwnsProduct(productKey: ProductKey): boolean
	local ownedProducts, setOwnedProducts = React.useState(PlayerData.ownedProducts())

	React.useEffect(function()
		return PlayerData.ownedProducts.Changed(setOwnedProducts)
	end, {})

	return ownedProducts[productKey] == true
end

return useOwnsProduct
