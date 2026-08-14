local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)
local Products = require(ReplicatedStorage.Source.Features.Monetization.Modules.Products)

type ProductInfo = MonetizationTypes.ProductInfo
type ProductKey = MonetizationTypes.ProductKey

local MonetizationServiceClient = {
	initialized = false,
	productInfoCache = {} :: { [ProductKey]: ProductInfo },
}

function MonetizationServiceClient.init(self)
	if self.initialized then return end
	self.initialized = true
end

function MonetizationServiceClient.getProductInfo(self, productKey: ProductKey): (ProductInfo?, string?)
	local cached = self.productInfoCache[productKey]
	if cached then return cached, nil end
	local product = Products[productKey]
	if not product then return nil, `Unknown product key: {tostring(productKey)}` end

	local success, result = pcall(MarketplaceService.GetProductInfo, MarketplaceService, product.id, Enum.InfoType.Product)
	if not success or type(result) ~= "table" then
		return nil, `Failed to load product info for {productKey}: {tostring(result)}`
	end

	local productInfo = result :: ProductInfo
	self.productInfoCache[productKey] = productInfo
	return productInfo, nil
end

function MonetizationServiceClient.promptProduct(self, productKey: ProductKey): (boolean, string?)
	local product = Products[productKey]
	if not product then return false, `Unknown product key: {tostring(productKey)}` end

	local success, message = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, product.id)
	if not success then return false, `Failed to prompt product {productKey}: {tostring(message)}` end
	return true, nil
end

return MonetizationServiceClient
