local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local ProductEntitlements = require(ReplicatedStorage.Source.Features.Monetization.Modules.ProductEntitlements)
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)
local UpgradeConfig = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeConfig)
local UpgradeTypes = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeTypes)

local LEVEL_ATTRIBUTE = "SlimeLuckLevel"
local MULTIPLIER_ATTRIBUTE = "SlimeLuckMultiplier"
local NEXT_MULTIPLIER_ATTRIBUTE = "SlimeLuckNextMultiplier"
local COST_ATTRIBUTE = "SlimeLuckCost"
local TEN_COST_ATTRIBUTE = "SlimeLuckTenCost"
local CASH_LEVEL_ATTRIBUTE = "CashMultiplierLevel"
local CASH_MULTIPLIER_ATTRIBUTE = "CashMultiplier"
local CASH_PAYOUT_MULTIPLIER_ATTRIBUTE = "CashPayoutMultiplier"
local CASH_NEXT_MULTIPLIER_ATTRIBUTE = "CashMultiplierNextMultiplier"
local CASH_COST_ATTRIBUTE = "CashMultiplierCost"
local CASH_TEN_COST_ATTRIBUTE = "CashMultiplierTenCost"

local UpgradeHandle = {}
UpgradeHandle.__index = UpgradeHandle

export type UpgradeHandle = typeof(setmetatable(
	{} :: {
		player: Player,
		plotModel: Model,
		cleanups: { () -> () },
		destroyed: boolean,
	},
	UpgradeHandle
))

local function getCurrency(value: number): number
	return math.floor(math.max(0, value))
end

function UpgradeHandle.updateAttributes(self: UpgradeHandle)
	if self.destroyed then
		return
	end

	local playerData = Data[self.player]
	if not playerData then
		return
	end

	local level = UpgradeConfig.getLevel(playerData.slimeLuckLevel())
	local tenCost = UpgradeConfig.getLuckUpgradeCostForQuantity(level, UpgradeConfig.BulkPurchaseQuantity)
	local cashLevel = UpgradeConfig.getLevel(playerData.cashMultiplierLevel())
	local cashTenCost = UpgradeConfig.getCashUpgradeCostForQuantity(cashLevel, UpgradeConfig.BulkPurchaseQuantity)

	self.plotModel:SetAttribute(LEVEL_ATTRIBUTE, level)
	self.plotModel:SetAttribute(MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(level))
	self.plotModel:SetAttribute(NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(level + 1))
	self.plotModel:SetAttribute(COST_ATTRIBUTE, UpgradeConfig.getLuckUpgradeCost(level))
	self.plotModel:SetAttribute(TEN_COST_ATTRIBUTE, tenCost)
	self.plotModel:SetAttribute(CASH_LEVEL_ATTRIBUTE, cashLevel)
	self.plotModel:SetAttribute(CASH_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(cashLevel))
	self.plotModel:SetAttribute(
		CASH_PAYOUT_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.getCashMultiplier(cashLevel) * RebirthConfig.getRewardMultiplier(playerData.rebirths())
			* ProductEntitlements.getCashMultiplier(playerData)
	)
	self.plotModel:SetAttribute(CASH_NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(cashLevel + 1))
	self.plotModel:SetAttribute(CASH_COST_ATTRIBUTE, UpgradeConfig.getCashUpgradeCost(cashLevel))
	self.plotModel:SetAttribute(CASH_TEN_COST_ATTRIBUTE, cashTenCost)
end

local purchasingPlayers: { [Player]: boolean } = {}

local function purchase(player: Player, plotModel: Model, mode: UpgradeTypes.PurchaseMode): UpgradeTypes.PurchaseResult
	if purchasingPlayers[player] or (mode ~= "single" and mode ~= "ten") then
		return "rejected"
	end

	local playerData = Data[player]
	if not playerData then
		return "rejected"
	end

	purchasingPlayers[player] = true

	local level = UpgradeConfig.getLevel(playerData.slimeLuckLevel())
	local currency = getCurrency(playerData.currency())
	local quantity: number
	local totalCost: number

	if mode == "single" then
		quantity = 1
		totalCost = UpgradeConfig.getLuckUpgradeCost(level)
		if totalCost > currency then
			purchasingPlayers[player] = nil
			return "insufficientMoney"
		end
	else
		quantity = UpgradeConfig.BulkPurchaseQuantity
		totalCost = UpgradeConfig.getLuckUpgradeCostForQuantity(level, quantity)
		if totalCost > currency then
			purchasingPlayers[player] = nil
			return "insufficientMoney"
		end
	end

	playerData.currency(currency - totalCost)
	playerData.slimeLuckLevel(level + quantity)
	purchasingPlayers[player] = nil

	local levelAfterPurchase = level + quantity

	local tenCost = UpgradeConfig.getLuckUpgradeCostForQuantity(
		levelAfterPurchase,
		UpgradeConfig.BulkPurchaseQuantity
	)
	plotModel:SetAttribute(LEVEL_ATTRIBUTE, levelAfterPurchase)
	plotModel:SetAttribute(MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(levelAfterPurchase))
	plotModel:SetAttribute(NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(levelAfterPurchase + 1))
	plotModel:SetAttribute(COST_ATTRIBUTE, UpgradeConfig.getLuckUpgradeCost(levelAfterPurchase))
	plotModel:SetAttribute(TEN_COST_ATTRIBUTE, tenCost)

	return "success"
end

local function purchaseCashMultiplier(player: Player, plotModel: Model, mode: UpgradeTypes.PurchaseMode): UpgradeTypes.PurchaseResult
	if purchasingPlayers[player] or (mode ~= "single" and mode ~= "ten") then
		return "rejected"
	end

	local playerData = Data[player]
	if not playerData then
		return "rejected"
	end

	purchasingPlayers[player] = true

	local level = UpgradeConfig.getLevel(playerData.cashMultiplierLevel())
	local currency = getCurrency(playerData.currency())
	local quantity: number
	local totalCost: number

	if mode == "single" then
		quantity = 1
		totalCost = UpgradeConfig.getCashUpgradeCost(level)
		if totalCost > currency then
			purchasingPlayers[player] = nil
			return "insufficientMoney"
		end
	else
		quantity = UpgradeConfig.BulkPurchaseQuantity
		totalCost = UpgradeConfig.getCashUpgradeCostForQuantity(level, quantity)
		if totalCost > currency then
			purchasingPlayers[player] = nil
			return "insufficientMoney"
		end
	end

	playerData.currency(currency - totalCost)
	playerData.cashMultiplierLevel(level + quantity)
	purchasingPlayers[player] = nil

	local levelAfterPurchase = level + quantity

	local tenCost = UpgradeConfig.getCashUpgradeCostForQuantity(
		levelAfterPurchase,
		UpgradeConfig.BulkPurchaseQuantity
	)
	plotModel:SetAttribute(CASH_LEVEL_ATTRIBUTE, levelAfterPurchase)
	plotModel:SetAttribute(CASH_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(levelAfterPurchase))
	plotModel:SetAttribute(
		CASH_PAYOUT_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.getCashMultiplier(levelAfterPurchase) * RebirthConfig.getRewardMultiplier(playerData.rebirths())
			* ProductEntitlements.getCashMultiplier(playerData)
	)
	plotModel:SetAttribute(CASH_NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(levelAfterPurchase + 1))
	plotModel:SetAttribute(CASH_COST_ATTRIBUTE, UpgradeConfig.getCashUpgradeCost(levelAfterPurchase))
	plotModel:SetAttribute(CASH_TEN_COST_ATTRIBUTE, tenCost)

	return "success"
end

local function grantDeveloperProduct(
	player: Player,
	plotModel: Model,
	upgradeType: string,
	quantity: number
): boolean
	if purchasingPlayers[player] or (upgradeType ~= "luck" and upgradeType ~= "cash") then
		return false
	end
	if quantity ~= 1 and quantity ~= UpgradeConfig.BulkPurchaseQuantity then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
	end

	purchasingPlayers[player] = true
	if upgradeType == "luck" then
		local level = UpgradeConfig.getLevel(playerData.slimeLuckLevel())
		playerData.slimeLuckLevel(level + quantity)
	else
		local level = UpgradeConfig.getLevel(playerData.cashMultiplierLevel())
		playerData.cashMultiplierLevel(level + quantity)
	end
	purchasingPlayers[player] = nil

	return true
end
function UpgradeHandle.destroy(self: UpgradeHandle)
	if self.destroyed then
		return
	end

	self.destroyed = true
	for _, cleanup in self.cleanups do
		cleanup()
	end
	table.clear(self.cleanups)
end

local UpgradeServiceServer = {}

function UpgradeServiceServer.attachPlot(player: Player, plotModel: Model): UpgradeHandle
	local handle = setmetatable({
		player = player,
		plotModel = plotModel,
		cleanups = {},
		destroyed = false,
	}, UpgradeHandle)

	local playerData = Data[player]
	assert(playerData, `Cannot attach upgrades before data loads for {player.Name}`)

	table.insert(handle.cleanups, playerData.currency.Changed(function()
		handle:updateAttributes()
	end))
	table.insert(handle.cleanups, playerData.slimeLuckLevel.Changed(function()
		handle:updateAttributes()
	end))
	table.insert(handle.cleanups, playerData.cashMultiplierLevel.Changed(function()
		handle:updateAttributes()
	end))
	table.insert(handle.cleanups, playerData.rebirths.Changed(function()
		handle:updateAttributes()
	end))
	table.insert(handle.cleanups, playerData.ownedProducts.Changed(function()
		handle:updateAttributes()
	end))

	handle:updateAttributes()
	return handle
end

UpgradeServiceServer.purchase = purchase
UpgradeServiceServer.purchaseCashMultiplier = purchaseCashMultiplier
UpgradeServiceServer.grantDeveloperProduct = grantDeveloperProduct

return UpgradeServiceServer
