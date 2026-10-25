--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

export type ItemDefinition = {
	id: string,
	name: string,
	price: number,
	boostPercent: number,
	imageId: number,
	stockOdds: { number },
}

local items: { ItemDefinition } = {
	{ id = "Umbrella", name = "Umbrella", price = 100, boostPercent = 2, imageId = assets.DecorUmbrella, stockOdds = { 20, 45, 28, 7 } },
	{ id = "TreasureChest", name = "Treasure Chest", price = 2500, boostPercent = 3, imageId = assets.DecorTreasureChest, stockOdds = { 35, 45, 18, 2 } },
	{ id = "Skull", name = "Skull", price = 25000, boostPercent = 4, imageId = assets.DecorSkull, stockOdds = { 50, 38, 11, 1 } },
	{ id = "Seashell", name = "Seashell", price = 250000, boostPercent = 5, imageId = assets.DecorSeashell, stockOdds = { 65, 30, 5, 0 } },
	{ id = "Sandcastle", name = "Sandcastle", price = 50000000, boostPercent = 6, imageId = assets.DecorSandcastle, stockOdds = { 80, 18, 2, 0 } },
	{ id = "PirateShip", name = "Pirate Ship", price = 5000000000, boostPercent = 8, imageId = assets.DecorPirateShip, stockOdds = { 90, 9.5, 0.5, 0 } },
}

local DecorConfig = {
	restockIntervalSeconds = 5 * 60,
	items = items,
}

function DecorConfig.get(itemId: string): ItemDefinition?
	for _, item in items do
		if item.id == itemId then
			return item
		end
	end
	return nil
end

function DecorConfig.getTankBoostPercent(decorIds: { string }): number
	local seen: { [string]: boolean } = {}
	local percent = 0
	local uniqueCount = 0
	for _, decorId in decorIds do
		local item = DecorConfig.get(decorId)
		if item then
			percent += item.boostPercent
			if not seen[decorId] then
				seen[decorId] = true
				uniqueCount += 1
			end
		end
	end
	if uniqueCount >= 4 then
		percent += 2
	end
	return percent
end

return DecorConfig
