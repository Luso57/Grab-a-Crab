--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local Money = require(ReplicatedStorage.Source.Game.Money)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)

local LeaderboardConfig = {}

LeaderboardConfig.boards = {
	{ key = "MostMoney", model = "LeaderBoard_MostMoney", title = "Most Money" },
	{ key = "TimePlayed", model = "LeaderBoard_TimePlayed", title = "Time Played" },
	{ key = "BiggestCrabG", model = "LeaderBoard_BiggestCrabG", title = "Biggest Crab" },
}

local MONEY_DIRECT_LIMIT = 1e12
local MONEY_LOG_SCALE = 1e10


function LeaderboardConfig.score(key: string, value: number | string): number
	if key == "MostMoney" and typeof(value) == "string" then
		if Money.compare(value, "0") <= 0 then return 0 end
		local logarithm = Money.log10(value)
		if logarithm < 12 then
			return tonumber(value) or 0
		end
		return MONEY_DIRECT_LIMIT + math.floor((logarithm - 12) * MONEY_LOG_SCALE)
	end
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

function LeaderboardConfig.value(key: string, score: number): number | string
	if key == "MostMoney" then
		if score < MONEY_DIRECT_LIMIT then
			return score
		end
		local logValue = 12 + (score - MONEY_DIRECT_LIMIT) / MONEY_LOG_SCALE
		local exponent = math.floor(logValue)
		local mantissa = 10 ^ (logValue - exponent)
		local group = math.floor(exponent / 3)
		local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "D", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }
		if group + 1 <= #suffixes then
			local scaled = mantissa * 10 ^ (exponent - group * 3)
			local formatted = string.format("%.2f", scaled)
			formatted = string.gsub(string.gsub(formatted, "0+$", ""), "%.$", "")
			return formatted .. suffixes[group + 1]
		end
		return string.format("%.2fe%d", mantissa, exponent)
	elseif key == "BiggestCrabG" then
		return score / 100
	end
	return score
end

function LeaderboardConfig.format(key: string, value: number | string): string
	if key == "MostMoney" then
		if typeof(value) == "string" then return value end
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
