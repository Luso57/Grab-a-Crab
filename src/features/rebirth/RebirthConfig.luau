local RebirthConfig = {
	BaseCost = 100_000,
	CostGrowth = 10,
	SellRateMilestoneInterval = 6,
	SellRateMilestoneMultiplier = 2,
}

function RebirthConfig.getCount(value: number?): number
	return math.floor(math.max(0, value or 0))
end

function RebirthConfig.getCost(rebirthCount: number?): number
	local count = RebirthConfig.getCount(rebirthCount)
	local cost = RebirthConfig.BaseCost * RebirthConfig.CostGrowth ^ count
	if cost == math.huge or cost ~= cost then
		return math.huge
	end
	return math.max(1, math.floor(cost + 0.5))
end

function RebirthConfig.getRewardMultiplier(rebirthCount: number?): number
	return RebirthConfig.getCount(rebirthCount) + 1
end

function RebirthConfig.getNextRewardMultiplier(rebirthCount: number?): number
	return RebirthConfig.getRewardMultiplier(rebirthCount) + 1
end

function RebirthConfig.isSellRateMilestone(rebirthNumber: number?): boolean
	local count = RebirthConfig.getCount(rebirthNumber)
	return count > 0 and count % RebirthConfig.SellRateMilestoneInterval == 0
end

function RebirthConfig.getSellRateMultiplier(rebirthCount: number?): number
	local milestones = math.floor(RebirthConfig.getCount(rebirthCount) / RebirthConfig.SellRateMilestoneInterval)
	return RebirthConfig.SellRateMilestoneMultiplier ^ milestones
end

return RebirthConfig