local SlimeEconomy = {
	ProductionPerLevel = 0.25,
	UpgradeCostGrowth = 1.35,
	SellRefundRate = 0.5,
}

local function getNonNegativeInteger(value: number): number
	return math.floor(math.max(0, value))
end

function SlimeEconomy.getLevel(value: number?): number
	return math.max(1, getNonNegativeInteger(value or 1))
end

function SlimeEconomy.getProduction(baseIncome: number, level: number?): number
	local normalizedLevel = SlimeEconomy.getLevel(level)
	local multiplier = 1 + (normalizedLevel - 1) * SlimeEconomy.ProductionPerLevel
	return math.max(1, math.floor(math.max(0, baseIncome) * multiplier + 0.5))
end

function SlimeEconomy.getUpgradeCost(baseCost: number, level: number?): number
	local normalizedLevel = SlimeEconomy.getLevel(level)
	local cost = math.max(0, baseCost) * SlimeEconomy.UpgradeCostGrowth ^ (normalizedLevel - 1)
	if cost == math.huge or cost ~= cost then
		return math.huge
	end
	return math.max(1, math.floor(cost + 0.5))
end

function SlimeEconomy.getSellValue(baseCost: number, upgradeInvestment: number?): number
	local totalInvestment = math.max(0, baseCost) + math.max(0, upgradeInvestment or 0)
	return math.max(0, math.floor(totalInvestment * SlimeEconomy.SellRefundRate))
end

return SlimeEconomy
