local UpgradeConfig = {
	BaseLuckMultiplier = 1,
	LuckPerLevel = 0.1,
	LuckUpgradeBaseCost = 250,
	LuckUpgradeCostGrowth = 1.36,
	BaseCashMultiplier = 1,
	CashPerLevel = 0.1,
	CashUpgradeBaseCost = 250,
	CashUpgradeCostGrowth = 1.36,
	BulkPurchaseQuantity = 10,
}

function UpgradeConfig.getLevel(value: number): number
	return math.floor(math.max(0, value))
end

function UpgradeConfig.getLuckMultiplier(level: number): number
	return UpgradeConfig.BaseLuckMultiplier + UpgradeConfig.getLevel(level) * UpgradeConfig.LuckPerLevel
end

function UpgradeConfig.getLuckUpgradeCost(level: number): number
	local normalizedLevel = UpgradeConfig.getLevel(level)
	return math.max(
		1,
		math.floor(UpgradeConfig.LuckUpgradeBaseCost * UpgradeConfig.LuckUpgradeCostGrowth ^ normalizedLevel + 0.5)
	)
end

function UpgradeConfig.getLuckUpgradeCostForQuantity(level: number, quantity: number): number
	local normalizedLevel = UpgradeConfig.getLevel(level)
	local normalizedQuantity = math.floor(math.max(0, quantity))
	local totalCost = 0
	for offset = 0, normalizedQuantity - 1 do
		totalCost += UpgradeConfig.getLuckUpgradeCost(normalizedLevel + offset)
	end
	return totalCost
end

function UpgradeConfig.getCashMultiplier(level: number): number
	return UpgradeConfig.BaseCashMultiplier + UpgradeConfig.getLevel(level) * UpgradeConfig.CashPerLevel
end

function UpgradeConfig.getCashUpgradeCost(level: number): number
	local normalizedLevel = UpgradeConfig.getLevel(level)
	return math.max(
		1,
		math.floor(UpgradeConfig.CashUpgradeBaseCost * UpgradeConfig.CashUpgradeCostGrowth ^ normalizedLevel + 0.5)
	)
end

function UpgradeConfig.getCashUpgradeCostForQuantity(level: number, quantity: number): number
	local normalizedLevel = UpgradeConfig.getLevel(level)
	local normalizedQuantity = math.floor(math.max(0, quantity))
	local totalCost = 0
	for offset = 0, normalizedQuantity - 1 do
		totalCost += UpgradeConfig.getCashUpgradeCost(normalizedLevel + offset)
	end
	return totalCost
end

return UpgradeConfig
