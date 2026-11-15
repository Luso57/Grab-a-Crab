--!strict

local CrabWeights = {}

local random = Random.new()
local CHANCE_ROLLS = 5000000
local MAX_WEIGHT_GRAMS = 10000000000

-- Chances are out of 5,000,000; bounds are hundredths of a gram.
local tiers = {
    { chance = 100000, minimum = 1, maximum = 99 },
    { chance = 2341500, minimum = 100, maximum = 199 },
    { chance = 936600, minimum = 200, maximum = 299 },
    { chance = 749280, minimum = 300, maximum = 499 },
    { chance = 655620, minimum = 500, maximum = 999 },
    { chance = 200000, minimum = 1000, maximum = 9999 },
    { chance = 10000, minimum = 10000, maximum = 99999 },
    { chance = 5000, minimum = 100000, maximum = 999999 },
    { chance = 1667, minimum = 1000000, maximum = 99999999 },
    { chance = 267, minimum = 100000000, maximum = 999999999 },
    { chance = 53, minimum = 1000000000, maximum = 9999999999 },
    { chance = 12, minimum = 10000000000, maximum = 99999999999 },
    { chance = 1, minimum = 100000000000, maximum = 1000000000000 },
}

function CrabWeights.roll(growthLuck: number?): number
    local multiplier = if typeof(growthLuck) == "number" and growthLuck == growthLuck then math.clamp(math.floor(growthLuck), 1, 84) else 1
    local heavyWeight = 0
    for _, tier in tiers do
        if tier.minimum >= 1000 then
            heavyWeight += tier.chance
        end
    end
    local totalWeight = CHANCE_ROLLS + heavyWeight * (multiplier - 1)
    local chance = if multiplier == 1 then random:NextInteger(1, CHANCE_ROLLS) else random:NextNumber(0, totalWeight)
    for _, tier in tiers do
        chance -= tier.chance * (if tier.minimum >= 1000 then multiplier else 1)
        if chance <= 0 then
            local range = tier.maximum - tier.minimum + 1
            local hundredths = tier.minimum + math.min(range - 1, math.floor(random:NextNumber() * range))
            return hundredths / 100
        end
    end
    return 1
end

function CrabWeights.normalize(weightGrams: any): number
    if typeof(weightGrams) ~= "number" or weightGrams ~= weightGrams
        or weightGrams < 0.01 or weightGrams > MAX_WEIGHT_GRAMS then
        return 1
    end
    return math.round(weightGrams * 100) / 100
end

function CrabWeights.scale(weightGrams: number?): number
    local weight = CrabWeights.normalize(weightGrams)
    if weight <= 100 then
        return 1.15 * weight ^ 0.35
    end
    return 1.15 * 100 ^ 0.35 * (weight / 100) ^ 0.18
end

function CrabWeights.income(baseIncomePerSecond: number, weightGrams: number?): number
    return baseIncomePerSecond * CrabWeights.normalize(weightGrams)
end

function CrabWeights.format(weightGrams: number?): string
    local weight = CrabWeights.normalize(weightGrams)
    if weight % 1 == 0 then
        return string.format("%.0fg", weight)
    end
    return string.format("%.2fg", weight)
end

return CrabWeights
