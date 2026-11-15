--!strict

local InventoryConfig = {
	hotbarSize = 9,
	emptySlot = "NULL",
	maxItems = 100,
	itemsPerPurchase = 100,
	hammerItemId = "Hammer",
	hammerSlot = 1,
	hammerInstanceId = function(userId: number): string
		return "StarterHammer:" .. userId
	end,
}

function InventoryConfig.getCapacity(purchases: number): number
	return InventoryConfig.maxItems + math.max(0, math.floor(purchases)) * InventoryConfig.itemsPerPurchase
end

return InventoryConfig
