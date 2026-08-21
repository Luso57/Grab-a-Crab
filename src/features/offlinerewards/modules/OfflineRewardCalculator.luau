local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsConfig)
local SlimeEconomy = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeEconomy)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

local OfflineRewardCalculator = {}

function OfflineRewardCalculator.getProductionRate(slimeDataList): number
	local total = 0
	for _, slimeData in slimeDataList do
		if Slimes.isValidSlimeId(slimeData.slimeId) then
			local slimeInfo = Slimes.getSlimeInfo(slimeData.slimeId)
			total += SlimeEconomy.getProduction(slimeInfo.income, slimeData.level)
				* SlimeMutations.getIncomeMultiplier(slimeData.mutationId)
		end
	end
	return math.max(0, total)
end

function OfflineRewardCalculator.getRewardAmount(slimeDataList, offlineSeconds: number): number
	local duration = math.clamp(math.max(0, offlineSeconds), 0, Config.MaximumOfflineSeconds)
	return math.floor(OfflineRewardCalculator.getProductionRate(slimeDataList) * duration * Config.OfflineProductionRate)
end

return OfflineRewardCalculator
