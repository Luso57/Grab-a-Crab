local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)
local Products = require(ReplicatedStorage.Source.Features.Monetization.Modules.Products)

type ProductKey = MonetizationTypes.ProductKey
type ReceiptHandler = MonetizationTypes.ReceiptHandler
type ReceiptInfo = MonetizationTypes.ReceiptInfo

local MonetizationServiceServer = {
	initialized = false,
	handlers = {} :: { [ProductKey]: ReceiptHandler },
	productKeysById = {} :: { [number]: ProductKey },
}

local function clearPendingBuySlime(player: Player)
	local playerData = Data[player]
	if not playerData then
		return
	end

	local pending = playerData.pendingBuySlime()
	if not pending.active then
		return
	end

	playerData.pendingBuySlime({
		active = false,
		slimeId = "",
		mutationId = "normal",
		offerIndex = 1,
		playpenLevel = 1,
	})
end

local function clearPendingUpgradePurchase(player: Player)
	local playerData = Data[player]
	if not playerData then
		return
	end

	local pending = playerData.pendingUpgradePurchase()
	if pending.active then
		playerData.pendingUpgradePurchase({
			active = false,
			upgradeType = "",
			quantity = 0,
		})
	end
end
function MonetizationServiceServer.registerHandler(self, productKey: ProductKey, handler: ReceiptHandler)
	assert(Products[productKey] ~= nil, `Cannot register unknown product key: {tostring(productKey)}`)
	assert(type(handler) == "function", "Monetization receipt handler must be a function")
	assert(self.handlers[productKey] == nil, `Handler already registered for product: {productKey}`)
	self.handlers[productKey] = handler
end

function MonetizationServiceServer.processReceipt(self, receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	local productKey = self.productKeysById[receiptInfo.ProductId]
	if not productKey then
		warn(`Received receipt for unknown developer product ID: {receiptInfo.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local handler = self.handlers[productKey]
	if not handler then
		warn(`No receipt handler registered for product: {productKey}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local playerData = if player then Data[player] else nil
	if not player or not playerData then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local processedPurchaseIds = playerData.processedPurchaseIds()
	if processedPurchaseIds[receiptInfo.PurchaseId] == true then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local success, granted = xpcall(handler, debug.traceback, player, receiptInfo)
	if not success then
		warn(`Receipt handler failed for {productKey}: {granted}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted ~= true then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local nextProcessedPurchaseIds = table.clone(processedPurchaseIds)
	nextProcessedPurchaseIds[receiptInfo.PurchaseId] = true
	playerData.processedPurchaseIds(nextProcessedPurchaseIds)
	playerData.robuxSpent(function(previous)
		return math.max(0, math.floor(previous)) + math.max(0, math.floor(receiptInfo.CurrencySpent))
	end)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationServiceServer.init(self)
	if self.initialized then
		return
	end

	for productKey, product in Products do
		assert(self.handlers[productKey] ~= nil, `No receipt handler registered for product: {productKey}`)
		assert(self.productKeysById[product.id] == nil, `Duplicate developer product ID: {product.id}`)
		self.productKeysById[product.id] = productKey
	end

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:processReceipt(receiptInfo :: ReceiptInfo)
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, isPurchased)
		if isPurchased then
			return
		end

		local player = Players:GetPlayerByUserId(userId)
		if not player then
			return
		end

		if productId == Products.buySlime.id then
			clearPendingBuySlime(player)
		elseif productId == Products.buyUpgradeOne.id or productId == Products.buyUpgradeTen.id then
			clearPendingUpgradePurchase(player)
		end
	end)
	self.initialized = true
end

return MonetizationServiceServer
