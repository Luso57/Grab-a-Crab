--!strict

export type ItemDefinition = {
	id: string,
	name: string,
	price: number,
	stockChance: number, -- 0 to 1
	stockAmount: number,
}

local ShopConfig = {
	restockIntervalSeconds = 5 * 60,
	items = {} :: { ItemDefinition }, -- Add the four shop items here.
}

return ShopConfig
