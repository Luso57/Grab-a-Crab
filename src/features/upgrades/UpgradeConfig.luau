local UpgradeConfig = {
	BaseLuckMultiplier = 1,
	LuckPerLevel = 0.1,
	LuckUpgradeBaseCost = 1_000,
	LuckUpgradeCostGrowth = 1.36,
	BaseCashMultiplier = 1,
	CashPerLevel = 0.1,
	CashUpgradeBaseCost = 1_000,
	CashUpgradeCostGrowth = 1.36,
	MaxBulkPurchaseLevels = 1_000,
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

function UpgradeConfig.getMaxAffordableLuckUpgrades(level: number, currency: number): (number, number)
	local normalizedLevel = UpgradeConfig.getLevel(level)
	local remaining = math.floor(math.max(0, currency))
	local quantity = 0
	local totalCost = 0

	while quantity < UpgradeConfig.MaxBulkPurchaseLevels do
		local cost = UpgradeConfig.getLuckUpgradeCost(normalizedLevel + quantity)
		if cost > remaining then
			break
		end

		remaining -= cost
		totalCost += cost
		quantity += 1
	end

	return quantity, totalCost
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

function UpgradeConfig.getMaxAffordableCashUpgrades(level: number, currency: number): (number, number)
	local normalizedLevel = UpgradeConfig.getLevel(level)
	local remaining = math.floor(math.max(0, currency))
	local quantity = 0
	local totalCost = 0

	while quantity < UpgradeConfig.MaxBulkPurchaseLevels do
		local cost = UpgradeConfig.getCashUpgradeCost(normalizedLevel + quantity)
		if cost > remaining then
			break
		end

		remaining -= cost
		totalCost += cost
		quantity += 1
	end

	return quantity, totalCost
end

return UpgradeConfig
