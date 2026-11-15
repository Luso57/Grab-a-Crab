--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)

local LeaderboardConfig = {}

LeaderboardConfig.boards = {
	{ key = "MostMoney", model = "LeaderBoard_MostMoney", title = "Most Money" },
	{ key = "TimePlayed", model = "LeaderBoard_TimePlayed", title = "Time Played" },
	{ key = "BiggestCrabG", model = "LeaderBoard_BiggestCrabG", title = "Biggest Crab" },
}

local MONEY_DIRECT_LIMIT = 1e12
local MONEY_LOG_SCALE = 1e10

function LeaderboardConfig.score(key: string, value: number): number
	if typeof(value) ~= "number" or value ~= value or value == math.huge or value <= 0 then
		return 0
	end
	if key == "MostMoney" then
		if value < MONEY_DIRECT_LIMIT then
			return math.floor(value)
		end
		return MONEY_DIRECT_LIMIT + math.floor(math.log10(value / MONEY_DIRECT_LIMIT) * MONEY_LOG_SCALE)
	elseif key == "BiggestCrabG" then
		return math.floor(value * 100 + 0.5)
	end
	return math.floor(value)
end

function LeaderboardConfig.value(key: string, score: number): number
	if key == "MostMoney" then
		if score < MONEY_DIRECT_LIMIT then
			return score
		end
		return MONEY_DIRECT_LIMIT * 10 ^ ((score - MONEY_DIRECT_LIMIT) / MONEY_LOG_SCALE)
	elseif key == "BiggestCrabG" then
		return score / 100
	end
	return score
end

function LeaderboardConfig.format(key: string, value: number): string
	if key == "MostMoney" then
		return CompactNumber.format(value, 2)
	elseif key == "BiggestCrabG" then
		return CrabWeights.format(value)
	end
	local seconds = math.max(0, math.floor(value))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm %02ds", minutes, seconds % 60)
end

return LeaderboardConfig
