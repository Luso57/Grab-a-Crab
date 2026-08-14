local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)
local SellingConfig = require(ReplicatedStorage.Source.Features.Selling.SellingConfig)
local UpgradeConfig = require(ReplicatedStorage.Source.Features.Upgrades.UpgradeConfig)

local QUEUE_ATTRIBUTE = "SlimeQueue"
local RATE_ATTRIBUTE = "SlimesPerSecond"
local CASH_ATTRIBUTE = "UncollectedCash"
local UPGRADE_COST_ATTRIBUTE = "UpgradePerSecondCost"
local UPGRADE_GAIN_ATTRIBUTE = "UpgradePerSecondGain"
local UPGRADE_CAN_AFFORD_ATTRIBUTE = "UpgradePerSecondCanAfford"
local UPGRADE_AFFORDABLE_COLOR = Color3.fromRGB(58, 125, 21)
local UPGRADE_UNAFFORDABLE_COLOR = Color3.fromRGB(220, 48, 45)

local SellingHandle = {}
SellingHandle.__index = SellingHandle

export type SellingHandle = typeof(setmetatable(
	{} :: {
		connections: { RBXScriptConnection },
		cleanups: { () -> () },
		destroyed: boolean,
	},
	SellingHandle
))

function SellingHandle.destroy(self: SellingHandle)
	if self.destroyed then
		return
	end

	self.destroyed = true
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
	for _, cleanup in self.cleanups do
		cleanup()
	end
	table.clear(self.cleanups)
end

local SellingServiceServer = {}

local function getNonNegativeInteger(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(math.max(0, value))
end

local function getUpgradeOffer(level: number): (number, number)
	local normalizedLevel = getNonNegativeInteger(level)
	local costMultiplier = SellingConfig.UpgradePerSecondCostGrowth ^ normalizedLevel
	local gainMultiplier = SellingConfig.UpgradePerSecondGainGrowth ^ normalizedLevel
	local cost = math.max(1, math.floor(SellingConfig.UpgradePerSecondBaseCost * costMultiplier + 0.5))
	local gain = math.max(1, math.floor(SellingConfig.UpgradePerSecondBaseGain * gainMultiplier + 0.5))

	return cost, gain
end

local function updatePlotAttributes(player: Player, plotModel: Model)
	local playerData = Data[player]
	if not playerData then
		return
	end

	plotModel:SetAttribute(QUEUE_ATTRIBUTE, getNonNegativeInteger(playerData.slimeQueue()))
	plotModel:SetAttribute(RATE_ATTRIBUTE, getNonNegativeInteger(playerData.slimesPerSecond()))
	plotModel:SetAttribute(CASH_ATTRIBUTE, getNonNegativeInteger(playerData.uncollectedCash()))
	local upgradeCost, upgradeGain = getUpgradeOffer(playerData.sellUpgradeLevel())
	local canAffordUpgrade = getNonNegativeInteger(playerData.currency()) >= upgradeCost
	plotModel:SetAttribute(UPGRADE_COST_ATTRIBUTE, upgradeCost)
	plotModel:SetAttribute(UPGRADE_GAIN_ATTRIBUTE, upgradeGain)
	plotModel:SetAttribute(UPGRADE_CAN_AFFORD_ATTRIBUTE, canAffordUpgrade)

	local upgradeModel = plotModel:FindFirstChild("UpgradePerSecond")
	local upgradeButton = if upgradeModel then upgradeModel:FindFirstChild("button") else nil
	if upgradeButton and upgradeButton:IsA("BasePart") then
		upgradeButton.Color = if canAffordUpgrade then UPGRADE_AFFORDABLE_COLOR else UPGRADE_UNAFFORDABLE_COLOR
	end
end

local function depositSlime(player: Player, plotModel: Model): number
	local playerData = Data[player]
	if not playerData then
		return 0
	end

	local amount = getNonNegativeInteger(playerData.slimeCurrency())
	if amount <= 0 then
		return 0
	end

	playerData.slimeCurrency(0)
	playerData.slimeQueue(function(previous)
		return getNonNegativeInteger(previous) + amount
	end)
	updatePlotAttributes(player, plotModel)

	return amount
end

local function sellQueuedSlime(player: Player, plotModel: Model): boolean
	local playerData = Data[player]
	if not playerData then
		return false
	end

	local queuedSlime = getNonNegativeInteger(playerData.slimeQueue())
	local sellRate = getNonNegativeInteger(playerData.slimesPerSecond())
	local amountToSell = math.min(queuedSlime, sellRate)
	if amountToSell <= 0 then
		updatePlotAttributes(player, plotModel)
		return false
	end

	playerData.slimeQueue(queuedSlime - amountToSell)
	playerData.uncollectedCash(function(previous)
		return getNonNegativeInteger(previous) + amountToSell * SellingConfig.SlimeValue
	end)
	updatePlotAttributes(player, plotModel)

	return true
end

local function collectCash(player: Player, plotModel: Model): number
	local playerData = Data[player]
	if not playerData then
		return 0
	end

	local amount = getNonNegativeInteger(playerData.uncollectedCash())
	if amount <= 0 then
		return 0
	end

	local multiplier = UpgradeConfig.getCashMultiplier(playerData.cashMultiplierLevel())
		* RebirthConfig.getRewardMultiplier(playerData.rebirths())
	local payout = math.floor(amount * multiplier)
	playerData.uncollectedCash(0)
	playerData.currency(function(previous)
		return getNonNegativeInteger(previous) + payout
	end)
	updatePlotAttributes(player, plotModel)

	return payout
end

local function purchasePerSecondUpgrade(player: Player, plotModel: Model): boolean
	local playerData = Data[player]
	if not playerData then
		return false
	end

	local level = getNonNegativeInteger(playerData.sellUpgradeLevel())
	local cost, gain = getUpgradeOffer(level)
	local currency = getNonNegativeInteger(playerData.currency())
	if currency < cost then
		return false
	end

	playerData.currency(currency - cost)
	playerData.slimesPerSecond(function(previous)
		return getNonNegativeInteger(previous) + gain
	end)
	playerData.sellUpgradeLevel(level + 1)
	updatePlotAttributes(player, plotModel)

	return true
end

function SellingServiceServer.attachPlot(
	player: Player,
	plotModel: Model,
	onDeposited: (amount: number) -> (),
	onCashCollected: (amount: number) -> (),
	onUpgradeStepped: () -> (),
	onInsufficientMoney: () -> ()
): SellingHandle
	local slimeDeposit = plotModel:WaitForChild("SlimeDeposit")
	assert(slimeDeposit:IsA("Model"), "Plot SlimeDeposit must be a Model")
	local collectCashModel = plotModel:WaitForChild("CollectCash")
	assert(collectCashModel:IsA("Model"), "Plot CollectCash must be a Model")
	local upgradeModel = plotModel:WaitForChild("UpgradePerSecond")
	assert(upgradeModel:IsA("Model"), "Plot UpgradePerSecond must be a Model")
	local upgradeButton: BasePart? = nil
	for _, child in upgradeModel:GetChildren() do
		if child:IsA("BasePart") and string.lower(child.Name) == "button" then
			upgradeButton = child
			break
		end
	end
	assert(upgradeButton, "Plot UpgradePerSecond must contain a button BasePart")

	local handle = setmetatable({
		connections = {},
		cleanups = {},
		destroyed = false,
	}, SellingHandle)
	local lastDepositAt = -math.huge
	local lastCashCollectionAt = -math.huge
	local lastUpgradeAt = -math.huge

	local function onTouched(hit: BasePart)
		if handle.destroyed then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local touchingPlayer = if character then Players:GetPlayerFromCharacter(character) else nil
		if touchingPlayer ~= player then
			return
		end

		local now = os.clock()
		if now - lastDepositAt < SellingConfig.DepositTouchCooldown then
			return
		end
		lastDepositAt = now

		local depositedAmount = depositSlime(player, plotModel)
		if depositedAmount > 0 then
			onDeposited(depositedAmount)
		end
	end

	local function onCollectCashTouched(hit: BasePart)
		if handle.destroyed then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local touchingPlayer = if character then Players:GetPlayerFromCharacter(character) else nil
		if touchingPlayer ~= player then
			return
		end

		local now = os.clock()
		if now - lastCashCollectionAt < SellingConfig.CollectTouchCooldown then
			return
		end
		lastCashCollectionAt = now

		local collectedAmount = collectCash(player, plotModel)
		if collectedAmount > 0 then
			onCashCollected(collectedAmount)
		end
	end

	local function onUpgradeTouched(hit: BasePart)
		if handle.destroyed then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local touchingPlayer = if character then Players:GetPlayerFromCharacter(character) else nil
		if touchingPlayer ~= player then
			return
		end

		local now = os.clock()
		if now - lastUpgradeAt < SellingConfig.UpgradeTouchCooldown then
			return
		end
		lastUpgradeAt = now

		if purchasePerSecondUpgrade(player, plotModel) then
			onUpgradeStepped()
		else
			onInsufficientMoney()
		end
	end

	for _, descendant in slimeDeposit:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(handle.connections, descendant.Touched:Connect(onTouched))
		end
	end
	for _, descendant in collectCashModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(handle.connections, descendant.Touched:Connect(onCollectCashTouched))
		end
	end
	table.insert(handle.connections, upgradeButton.Touched:Connect(onUpgradeTouched))

	local playerData = Data[player]
	if playerData then
		table.insert(handle.cleanups, playerData.currency.Changed(function()
			updatePlotAttributes(player, plotModel)
		end))
		table.insert(handle.cleanups, playerData.sellUpgradeLevel.Changed(function()
			updatePlotAttributes(player, plotModel)
		end))
	end

	updatePlotAttributes(player, plotModel)
	task.spawn(function()
		while not handle.destroyed do
			task.wait(SellingConfig.SellingInterval)
			if handle.destroyed then
				break
			end

			sellQueuedSlime(player, plotModel)
		end
	end)

	return handle
end

SellingServiceServer.refresh = updatePlotAttributes

return SellingServiceServer
