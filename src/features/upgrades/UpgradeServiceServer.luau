local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)
local UpgradeConfig = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeConfig)
local UpgradeTypes = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeTypes)

local LEVEL_ATTRIBUTE = "SlimeLuckLevel"
local MULTIPLIER_ATTRIBUTE = "SlimeLuckMultiplier"
local NEXT_MULTIPLIER_ATTRIBUTE = "SlimeLuckNextMultiplier"
local COST_ATTRIBUTE = "SlimeLuckCost"
local MAX_QUANTITY_ATTRIBUTE = "SlimeLuckMaxQuantity"
local MAX_COST_ATTRIBUTE = "SlimeLuckMaxCost"
local CASH_LEVEL_ATTRIBUTE = "CashMultiplierLevel"
local CASH_MULTIPLIER_ATTRIBUTE = "CashMultiplier"
local CASH_PAYOUT_MULTIPLIER_ATTRIBUTE = "CashPayoutMultiplier"
local CASH_NEXT_MULTIPLIER_ATTRIBUTE = "CashMultiplierNextMultiplier"
local CASH_COST_ATTRIBUTE = "CashMultiplierCost"
local CASH_MAX_QUANTITY_ATTRIBUTE = "CashMultiplierMaxQuantity"
local CASH_MAX_COST_ATTRIBUTE = "CashMultiplierMaxCost"

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
	local currency = getCurrency(playerData.currency())
	local maxQuantity, maxCost = UpgradeConfig.getMaxAffordableLuckUpgrades(level, currency)
	local cashLevel = UpgradeConfig.getLevel(playerData.cashMultiplierLevel())
	local cashMaxQuantity, cashMaxCost = UpgradeConfig.getMaxAffordableCashUpgrades(cashLevel, currency)

	self.plotModel:SetAttribute(LEVEL_ATTRIBUTE, level)
	self.plotModel:SetAttribute(MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(level))
	self.plotModel:SetAttribute(NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(level + 1))
	self.plotModel:SetAttribute(COST_ATTRIBUTE, UpgradeConfig.getLuckUpgradeCost(level))
	self.plotModel:SetAttribute(MAX_QUANTITY_ATTRIBUTE, maxQuantity)
	self.plotModel:SetAttribute(MAX_COST_ATTRIBUTE, maxCost)
	self.plotModel:SetAttribute(CASH_LEVEL_ATTRIBUTE, cashLevel)
	self.plotModel:SetAttribute(CASH_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(cashLevel))
	self.plotModel:SetAttribute(
		CASH_PAYOUT_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.getCashMultiplier(cashLevel) * RebirthConfig.getRewardMultiplier(playerData.rebirths())
	)
	self.plotModel:SetAttribute(CASH_NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(cashLevel + 1))
	self.plotModel:SetAttribute(CASH_COST_ATTRIBUTE, UpgradeConfig.getCashUpgradeCost(cashLevel))
	self.plotModel:SetAttribute(CASH_MAX_QUANTITY_ATTRIBUTE, cashMaxQuantity)
	self.plotModel:SetAttribute(CASH_MAX_COST_ATTRIBUTE, cashMaxCost)
end

local purchasingPlayers: { [Player]: boolean } = {}

local function purchase(player: Player, plotModel: Model, mode: UpgradeTypes.PurchaseMode): boolean
	if purchasingPlayers[player] or (mode ~= "single" and mode ~= "max") then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
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
			return false
		end
	else
		quantity, totalCost = UpgradeConfig.getMaxAffordableLuckUpgrades(level, currency)
		if quantity <= 0 then
			purchasingPlayers[player] = nil
			return false
		end
	end

	playerData.currency(currency - totalCost)
	playerData.slimeLuckLevel(level + quantity)
	purchasingPlayers[player] = nil

	local levelAfterPurchase = level + quantity
	local currencyAfterPurchase = currency - totalCost
	local maxQuantity, maxCost = UpgradeConfig.getMaxAffordableLuckUpgrades(levelAfterPurchase, currencyAfterPurchase)
	plotModel:SetAttribute(LEVEL_ATTRIBUTE, levelAfterPurchase)
	plotModel:SetAttribute(MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(levelAfterPurchase))
	plotModel:SetAttribute(NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getLuckMultiplier(levelAfterPurchase + 1))
	plotModel:SetAttribute(COST_ATTRIBUTE, UpgradeConfig.getLuckUpgradeCost(levelAfterPurchase))
	plotModel:SetAttribute(MAX_QUANTITY_ATTRIBUTE, maxQuantity)
	plotModel:SetAttribute(MAX_COST_ATTRIBUTE, maxCost)

	return true
end

local function purchaseCashMultiplier(player: Player, plotModel: Model, mode: UpgradeTypes.PurchaseMode): boolean
	if purchasingPlayers[player] or (mode ~= "single" and mode ~= "max") then
		return false
	end

	local playerData = Data[player]
	if not playerData then
		return false
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
			return false
		end
	else
		quantity, totalCost = UpgradeConfig.getMaxAffordableCashUpgrades(level, currency)
		if quantity <= 0 then
			purchasingPlayers[player] = nil
			return false
		end
	end

	playerData.currency(currency - totalCost)
	playerData.cashMultiplierLevel(level + quantity)
	purchasingPlayers[player] = nil

	local levelAfterPurchase = level + quantity
	local currencyAfterPurchase = currency - totalCost
	local maxQuantity, maxCost = UpgradeConfig.getMaxAffordableCashUpgrades(levelAfterPurchase, currencyAfterPurchase)
	plotModel:SetAttribute(CASH_LEVEL_ATTRIBUTE, levelAfterPurchase)
	plotModel:SetAttribute(CASH_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(levelAfterPurchase))
	plotModel:SetAttribute(
		CASH_PAYOUT_MULTIPLIER_ATTRIBUTE,
		UpgradeConfig.getCashMultiplier(levelAfterPurchase) * RebirthConfig.getRewardMultiplier(playerData.rebirths())
	)
	plotModel:SetAttribute(CASH_NEXT_MULTIPLIER_ATTRIBUTE, UpgradeConfig.getCashMultiplier(levelAfterPurchase + 1))
	plotModel:SetAttribute(CASH_COST_ATTRIBUTE, UpgradeConfig.getCashUpgradeCost(levelAfterPurchase))
	plotModel:SetAttribute(CASH_MAX_QUANTITY_ATTRIBUTE, maxQuantity)
	plotModel:SetAttribute(CASH_MAX_COST_ATTRIBUTE, maxCost)

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

	handle:updateAttributes()
	return handle
end

UpgradeServiceServer.purchase = purchase
UpgradeServiceServer.purchaseCashMultiplier = purchaseCashMultiplier

return UpgradeServiceServer
