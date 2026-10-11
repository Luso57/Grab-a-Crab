--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)

export type ItemDefinition = {
	shortName: string,
	imageId: number,
	rarity: Rarities.Rarity?,
}

local definitions: { [string]: ItemDefinition } = {
	["Hammer"] = { shortName = "Hammer", imageId = assets.hammer },
	["Incubator"] = { shortName = "Incubator", imageId = assets.Incubator },
	["Tank.Small"] = { shortName = "Small", imageId = assets.SmallTank },
	["Tank.Medium"] = { shortName = "Medium", imageId = assets.MediumTank },
	["Tank.Large"] = { shortName = "Large", imageId = assets.LargeTank },
}

local ItemCatalog = {}

function ItemCatalog.get(itemId: string): ItemDefinition?
	local definition = definitions[itemId]
	if definition then
		return definition
	end
	local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
	local egg = if eggId then Eggs.get(eggId) else nil
	if egg and eggId then
		return { shortName = egg.name, imageId = egg.imageId, rarity = Eggs.getRarity(eggId) }
	end
	local crabId = string.match(itemId, "^Crab%.([%w_]+)$")
	local crab = if crabId then Crabs.get(crabId) else nil
	if crab then
		return { shortName = crab.name, imageId = crab.imageId, rarity = crab.rarity }
	end
	return nil
end

return ItemCatalog
