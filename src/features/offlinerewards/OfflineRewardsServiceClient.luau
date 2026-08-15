local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local MonetizationServiceClient = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient)
local Config = require(script.Parent.OfflineRewardsConfig)
local OfflineRewardsSlice = require(script.Parent.OfflineRewardsSlice)

local OfflineRewardsServiceClient = { initialized = false }

function OfflineRewardsServiceClient.init(self)
	if self.initialized then return end
	self.initialized = true
	self.networker = Networker.client.new(Config.NetworkTag, self)
	self.networker:fire("requestReward")
end

function OfflineRewardsServiceClient.rewardState(_self, amount: number, offlineSeconds: number, awaitingDouble: boolean)
	if type(amount) ~= "number" or amount <= 0 then
		OfflineRewardsSlice.actions.clear()
		return
	end
	OfflineRewardsSlice.actions.show({
		amount = math.floor(amount),
		offlineSeconds = math.max(0, math.floor(offlineSeconds)),
		awaitingDouble = awaitingDouble == true,
	})
end

function OfflineRewardsServiceClient.rewardClaimed()
	OfflineRewardsSlice.actions.clear()
end

function OfflineRewardsServiceClient.promptDoublePurchase(self)
	MonetizationServiceClient:promptProduct(Config.DoubleProductKey)
end

function OfflineRewardsServiceClient.claim(self)
	self.networker:fire("claimReward")
end

function OfflineRewardsServiceClient.requestDouble(self)
	self.networker:fire("requestDoubleReward")
end

return OfflineRewardsServiceClient
