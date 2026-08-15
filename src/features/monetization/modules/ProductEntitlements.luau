local ProductEntitlements = {}

function ProductEntitlements.ownsIn(ownedProducts: { [string]: boolean }, productKey: string): boolean
	return ownedProducts[productKey] == true
end

function ProductEntitlements.owns(playerData: any, productKey: string): boolean
	return ProductEntitlements.ownsIn(playerData.ownedProducts(), productKey)
end

function ProductEntitlements.getLuckMultiplierFromOwnedProducts(ownedProducts: { [string]: boolean }): number
	local multiplier = 1
	if ProductEntitlements.ownsIn(ownedProducts, "doublePermanentLuck") then
		multiplier *= 2
	end
	if ProductEntitlements.ownsIn(ownedProducts, "quadruplePermanentLuck") then
		multiplier *= 4
	end
	return multiplier
end

function ProductEntitlements.getLuckMultiplier(playerData: any): number
	return ProductEntitlements.getLuckMultiplierFromOwnedProducts(playerData.ownedProducts())
end

function ProductEntitlements.getCashMultiplierFromOwnedProducts(ownedProducts: { [string]: boolean }): number
	return if ProductEntitlements.ownsIn(ownedProducts, "doubleCash") then 2 else 1
end

function ProductEntitlements.getCashMultiplier(playerData: any): number
	return ProductEntitlements.getCashMultiplierFromOwnedProducts(playerData.ownedProducts())
end

function ProductEntitlements.getSlimeDepositMultiplierFromOwnedProducts(ownedProducts: { [string]: boolean }): number
	return if ProductEntitlements.ownsIn(ownedProducts, "doubleSlimeDeposit") then 2 else 1
end

function ProductEntitlements.getSlimeDepositMultiplier(playerData: any): number
	return ProductEntitlements.getSlimeDepositMultiplierFromOwnedProducts(playerData.ownedProducts())
end

return ProductEntitlements
