local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server

local function grantPermanentProduct(player: Player, productKey: string): boolean
	local playerData = Data[player]
	if not playerData then
		return false
	end

	local ownedProducts = playerData.ownedProducts()
	if ownedProducts[productKey] ~= true then
		local nextOwnedProducts = table.clone(ownedProducts)
		nextOwnedProducts[productKey] = true
		playerData.ownedProducts(nextOwnedProducts)
	end

	return true
end

return grantPermanentProduct
