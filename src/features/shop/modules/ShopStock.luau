--!strict

type StockItem = {
	id: string,
	stockOdds: { number },
}

export type Stock = { [string]: number }

local ShopStock = {}

function ShopStock.roll(items: { StockItem }, rng: Random): Stock
	local stock: Stock = {}

	for _, item in items do
		local roll = rng:NextNumber(0, 100)
		local cumulative = 0
		local amount = 0
		for index, chance in item.stockOdds do
			cumulative += chance
			if roll < cumulative then
				amount = index - 1
				break
			end
		end
		stock[item.id] = amount
	end

	return stock
end

return ShopStock
