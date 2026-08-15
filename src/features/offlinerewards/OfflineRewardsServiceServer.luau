local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local Products = require(ReplicatedStorage.Source.Features.Monetization.Modules.Products)
local SlimeEconomy = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeEconomy)
local SlimeMutations = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutations)
local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)
local Config = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsConfig)

local OfflineRewardsServiceServer = { initialized = false }

local EMPTY_REWARD = {
	active = false,
	amount = 0,
	offlineSeconds = 0,
	awaitingDouble = false,
}

local function getProductionRate(playerData): number
	local total = 0
	for _, slimeData in playerData.slimes() do
		if Slimes.isValidSlimeId(slimeData.slimeId) then
			local slimeInfo = Slimes.getSlimeInfo(slimeData.slimeId)
			total += SlimeEconomy.getProduction(slimeInfo.income, slimeData.level)
				* SlimeMutations.getIncomeMultiplier(slimeData.mutationId)
		end
	end
	return math.max(0, total)
end

local function sendReward(self, player: Player)
	local playerData = Data[player]
	if not playerData then return end
	local pending = playerData.pendingOfflineReward()
	if pending.active and pending.amount > 0 then
		self.networker:fire(player, "rewardState", pending.amount, pending.offlineSeconds, pending.awaitingDouble)
	else
		self.networker:fire(player, "rewardClaimed")
	end
end

local function clearReward(playerData)
	playerData.pendingOfflineReward(table.clone(EMPTY_REWARD))
end

function OfflineRewardsServiceServer.init(self)
	if self.initialized then return end
	self.initialized = true
	self.networker = Networker.server.new(Config.NetworkTag, self, {
		self.requestReward,
		self.claimReward,
		self.requestDoubleReward,
	})

	local function playerAdded(player: Player)
		Data.Service:waitForData(player)
		local playerData = Data[player]
		if not playerData or player.Parent ~= Players then return end

		local now = os.time()
		local pending = playerData.pendingOfflineReward()
		local lastActive = math.max(0, math.floor(playerData.lastActiveUnix()))
		if not pending.active and Config.TestingPopupOnJoin then
			playerData.pendingOfflineReward({
				active = true,
				amount = Config.TestingRewardAmount,
				offlineSeconds = Config.TestingOfflineSeconds,
				awaitingDouble = false,
			})
		elseif not pending.active and lastActive > 0 then
			local elapsed = math.clamp(now - lastActive, 0, Config.MaximumOfflineSeconds)
			if elapsed >= Config.MinimumOfflineSeconds then
				local amount = math.floor(getProductionRate(playerData) * elapsed * Config.OfflineProductionRate)
				if amount > 0 then
					playerData.pendingOfflineReward({
						active = true,
						amount = amount,
						offlineSeconds = elapsed,
						awaitingDouble = false,
					})
				end
			end
		end
		playerData.lastActiveUnix(now)
		sendReward(self, player)
	end

	for _, player in Players:GetPlayers() do task.spawn(playerAdded, player) end
	Players.PlayerAdded:Connect(function(player) task.spawn(playerAdded, player) end)
	Data.Service:addPlayerRemovingCallback(function(_player, rawData)
		rawData.lastActiveUnix = os.time()
	end)

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if productId ~= Products.doubleOfflineSlime.id or isPurchased then return end
		local player = Players:GetPlayerByUserId(userId)
		local playerData = if player then Data[player] else nil
		if not player or not playerData then return end
		local pending = playerData.pendingOfflineReward()
		if pending.active and pending.awaitingDouble then
			pending = table.clone(pending)
			pending.awaitingDouble = false
			playerData.pendingOfflineReward(pending)
			sendReward(self, player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.ActivitySaveInterval)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local playerData = Data[player]
				if playerData then playerData.lastActiveUnix(now) end
			end
		end
	end)
end

function OfflineRewardsServiceServer.requestReward(self, player: Player)
	sendReward(self, player)
end

function OfflineRewardsServiceServer.claimReward(self, player: Player): boolean
	local playerData = Data[player]
	if not playerData then return false end
	local pending = playerData.pendingOfflineReward()
	if not pending.active or pending.awaitingDouble or pending.amount <= 0 then return false end
	playerData.slimeCurrency(function(previous)
		return math.max(0, math.floor(previous)) + math.floor(pending.amount)
	end)
	clearReward(playerData)
	self.networker:fire(player, "rewardClaimed")
	return true
end

function OfflineRewardsServiceServer.requestDoubleReward(self, player: Player): boolean
	local playerData = Data[player]
	if not playerData then return false end
	local pending = playerData.pendingOfflineReward()
	if not pending.active or pending.awaitingDouble or pending.amount <= 0 then return false end
	pending = table.clone(pending)
	pending.awaitingDouble = true
	playerData.pendingOfflineReward(pending)
	sendReward(self, player)
	self.networker:fire(player, "promptDoublePurchase")
	return true
end

function OfflineRewardsServiceServer.grantDoubleReceipt(self, player: Player): boolean
	if not self.initialized then return false end
	local playerData = Data[player]
	if not playerData then return false end
	local pending = playerData.pendingOfflineReward()
	if not pending.active or not pending.awaitingDouble or pending.amount <= 0 then return false end
	playerData.slimeCurrency(function(previous)
		return math.max(0, math.floor(previous)) + math.floor(pending.amount) * 2
	end)
	clearReward(playerData)
	self.networker:fire(player, "rewardClaimed")
	return true
end

return OfflineRewardsServiceServer
