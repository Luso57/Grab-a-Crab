--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)

local ProductPrices = {}

function ProductPrices.load(productId: number, initialText: string?): () -> string
	local price = Vide.source(initialText or "...")
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and typeof(info) == "table" and typeof(info.PriceInRobux) == "number" then
			price(tostring(info.PriceInRobux))
		end
	end)
	return price
end

return ProductPrices
