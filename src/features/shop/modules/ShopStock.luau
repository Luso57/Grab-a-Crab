--!strict

type StockItem = {
	id: string,
	stockChance: number,
	stockAmount: number,
}

export type Stock = { [string]: number }

local ShopStock = {}

function ShopStock.roll(items: { StockItem }, rng: Random): Stock
	local stock: Stock = {}

	for _, item in items do
		stock[item.id] = if rng:NextNumber() < item.stockChance then item.stockAmount else 0
	end

	return stock
end

return ShopStock
