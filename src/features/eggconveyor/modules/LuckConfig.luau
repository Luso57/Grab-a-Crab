--!strict

local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local IndexMilestones = require(ReplicatedStorage.Source.Features.Index.Modules.IndexMilestones)

-- Each row is a percentage distribution. Locked rarities have zero chance.
-- New rarities enter at a small chance
-- and become more common with further luck purchases.
local keyframes = {
	{ luck = 0, odds = { 95, 5, 0, 0, 0, 0 } },
	{ luck = 90, odds = { 88, 12, 0, 0, 0, 0 } },
	{ luck = 100, odds = { 87.9, 12, 0.1, 0, 0, 0 } },
	{ luck = 190, odds = { 78, 19, 3, 0, 0, 0 } },
	{ luck = 200, odds = { 77.95, 19, 3, 0.05, 0, 0 } },
	{ luck = 290, odds = { 68, 22, 9, 1, 0, 0 } },
	{ luck = 300, odds = { 67.95, 22, 9, 1, 0.05, 0 } },
	{ luck = 390, odds = { 58, 26, 12, 3.7, 0.3, 0 } },
	{ luck = 400, odds = { 57.98, 26, 12, 3.7, 0.3, 0.02 } },
	{ luck = 500, odds = { 45, 30, 20, 4, 0.9, 0.1 } },
	{ luck = 600, odds = { 42, 30, 22, 4.8, 1.08, 0.12 } },
	{ luck = 700, odds = { 39, 30, 24, 5.5, 1.36, 0.14 } },
	{ luck = 800, odds = { 36, 30, 26, 6.4, 1.44, 0.16 } },
	{ luck = 900, odds = { 33, 30, 27, 8.2, 1.62, 0.18 } },
	{ luck = 1000, odds = { 30, 31, 28, 9, 1.8, 0.2 } },
}

local FIRST_UPGRADE_PRICE = 12500
local LATE_UPGRADE_PRICE = 1000000000
local LATE_UPGRADE_GROWTH = 1.3
local discoveryRequirements = { 15, 25, 35, 45, 55 }

local LuckConfig = {
	LUCK_PER_UPGRADE = 10,
	MAX_LUCK = 1000,
}

function LuckConfig.normalizeLuck(value: any): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.clamp(math.floor(value / LuckConfig.LUCK_PER_UPGRADE) * LuckConfig.LUCK_PER_UPGRADE, 0, LuckConfig.MAX_LUCK)
end

function LuckConfig.getUpgradePrice(luck: number): number?
	local normalized = LuckConfig.normalizeLuck(luck)
	if normalized >= LuckConfig.MAX_LUCK then
		return nil
	end
	local purchases = normalized / LuckConfig.LUCK_PER_UPGRADE
	if normalized >= 500 then
		return math.floor(LATE_UPGRADE_PRICE * LATE_UPGRADE_GROWTH ^ (purchases - 50) + 0.5)
	end
	local price = FIRST_UPGRADE_PRICE * (1 + 0.1 * purchases) ^ 4
	return math.floor(price + 0.5)
end

function LuckConfig.getRequiredDiscoveries(luck: number): number
	local normalized = LuckConfig.normalizeLuck(luck)
	if normalized < 500 or normalized >= LuckConfig.MAX_LUCK then
		return 0
	end
	return discoveryRequirements[math.floor((normalized - 500) / 100) + 1]
end

function LuckConfig.countDiscovered(discovered: { [string]: boolean }): number
	local count = 0
	for _, crabId in IndexMilestones.getCrabIds() do
		if discovered[crabId] == true then
			count += 1
		end
	end
	return count
end

export type RarityWeight = { rarity: string, weight: number }

function LuckConfig.getWeights(luck: number): { RarityWeight }
	local normalized = LuckConfig.normalizeLuck(luck)
	local lower = keyframes[1]
	local upper = keyframes[#keyframes]
	for index = 2, #keyframes do
		if normalized <= keyframes[index].luck then
			upper = keyframes[index]
			lower = keyframes[index - 1]
			break
		end
	end

	local progress = (normalized - lower.luck) / (upper.luck - lower.luck)
	local weights: { RarityWeight } = {}
	for index, rarity in rarities do
		local chance = lower.odds[index] + (upper.odds[index] - lower.odds[index]) * progress
		table.insert(weights, { rarity = rarity, weight = chance })
	end
	return weights
end

return LuckConfig
