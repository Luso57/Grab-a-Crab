local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)

export type Entry = {
	productKey: MonetizationTypes.ProductKey,
	name: string,
	description: string,
	image: string,
}

local PassCatalog: { Entry } = {
	{
		productKey = "autoCollectSlime",
		name = "AUTO COLLECT SLIME",
		description = "Automatically collect slime for you!",
		image = "rbxassetid://139635723208368",
	},
	{
		productKey = "doubleRolls",
		name = "DOUBLE ROLLS",
		description = "Roll 2 slimes at ONCE!",
		image = "rbxassetid://124008362874496",
	},
	{
		productKey = "doubleRollSpeed",
		name = "2X ROLL SPEED",
		description = "Roll twice as fast!",
		image = "rbxassetid://97947083217374",
	},
	{
		productKey = "doublePermanentLuck",
		name = "2X PERMANENT LUCK",
		description = "Permanent 2x Luck",
		image = "rbxassetid://100469640960520",
	},
	{
		productKey = "quadruplePermanentLuck",
		name = "4X PERMANENT LUCK",
		description = "Permanent 4x Luck",
		image = "rbxassetid://82906043483694",
	},
	{
		productKey = "autoCollect",
		name = "AUTO COLLECT CASH",
		description = "Automatically collect your earnings!",
		image = "rbxassetid://124299228503480",
	},
	{
		productKey = "doubleCash",
		name = "2X CASH",
		description = "Earn twice as much cash!",
		image = "rbxassetid://132439188223524",
	},
}

return PassCatalog
