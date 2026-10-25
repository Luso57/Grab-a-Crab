--!strict

export type ItemDefinition = {
	id: string,
	price: number,
	stockOdds: { number }, -- Percentages for 0, 1, 2, ... units.
}

local ShopConfig = {
	restockIntervalSeconds = 5 * 60,
	items = {
		{ id = "Incubator", price = 50, stockOdds = { 0, 50, 35, 15 } },
		{ id = "Small", price = 150, stockOdds = { 0, 55, 35, 10 } },
		{ id = "Medium", price = 10000, stockOdds = { 35, 50, 15 } },
		{ id = "Large", price = 100000, stockOdds = { 60, 35, 5 } },
	} :: { ItemDefinition },
}

function ShopConfig.getPrice(itemId: string): number?
	for _, item in ShopConfig.items do
		if item.id == itemId then
			return item.price
		end
	end
	return nil
end

return ShopConfig
