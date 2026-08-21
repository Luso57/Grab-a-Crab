local SellingConfig = {
	DefaultSlimesPerSecond = 10,
	SlimeValue = 1,
	DepositTouchCooldown = 0.5,
	CollectTouchCooldown = 0.5,
	SellingInterval = 1,
	UpgradePerSecondBaseCost = 50,
	UpgradePerSecondBaseGain = 25,
	UpgradePerSecondCostGrowth = 1.35,
	UpgradePerSecondGainGrowth = 1.14,
	UpgradeTouchCooldown = 0.5,
}

function SellingConfig.getUpgradeLevel(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(math.max(0, value))
end

function SellingConfig.getUpgradeCost(level: number): number
	local normalizedLevel = SellingConfig.getUpgradeLevel(level)
	return math.max(
		1,
		math.floor(SellingConfig.UpgradePerSecondBaseCost * SellingConfig.UpgradePerSecondCostGrowth ^ normalizedLevel + 0.5)
	)
end

function SellingConfig.getUpgradeGain(level: number): number
	local normalizedLevel = SellingConfig.getUpgradeLevel(level)
	return math.max(
		1,
		math.floor(SellingConfig.UpgradePerSecondBaseGain * SellingConfig.UpgradePerSecondGainGrowth ^ normalizedLevel + 0.5)
	)
end

function SellingConfig.getMinimumRateForLevel(level: number): number
	local normalizedLevel = SellingConfig.getUpgradeLevel(level)
	local rate = SellingConfig.DefaultSlimesPerSecond
	for completedLevel = 0, normalizedLevel - 1 do
		rate += SellingConfig.getUpgradeGain(completedLevel)
	end
	return rate
end

return SellingConfig
