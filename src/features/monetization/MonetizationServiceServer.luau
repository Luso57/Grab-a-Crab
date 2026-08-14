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
	if not player or not Data[player] then return Enum.ProductPurchaseDecision.NotProcessedYet end

	local success, granted = xpcall(handler, debug.traceback, player, receiptInfo)
	if not success then
		warn(`Receipt handler failed for {productKey}: {granted}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if granted ~= true then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationServiceServer.init(self)
	if self.initialized then return end
	for productKey, product in Products do
		assert(self.productKeysById[product.id] == nil, `Duplicate developer product ID: {product.id}`)
		self.productKeysById[product.id] = productKey
	end
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:processReceipt(receiptInfo :: ReceiptInfo)
	end
	self.initialized = true
end

return MonetizationServiceServer
