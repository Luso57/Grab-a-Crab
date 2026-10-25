--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)
local DecorConfig = require(ReplicatedStorage.Source.Features.DecorShop.DecorConfig)

export type ItemDefinition = {
	shortName: string,
	imageId: number,
	rarity: Rarities.Rarity?,
	hotbarEligible: boolean?,
	stackable: boolean?,
}

local definitions: { [string]: ItemDefinition } = {
	["Hammer"] = { shortName = "Hammer", imageId = assets.hammer },
	["Incubator"] = { shortName = "Incubator", imageId = assets.Incubator, stackable = true },
	["Tank.Small"] = { shortName = "Small", imageId = assets.SmallTank, stackable = true },
	["Tank.Medium"] = { shortName = "Medium", imageId = assets.MediumTank, stackable = true },
	["Tank.Large"] = { shortName = "Large", imageId = assets.LargeTank, stackable = true },
}

local ItemCatalog = {}

function ItemCatalog.get(itemId: string): ItemDefinition?
	local definition = definitions[itemId]
	if definition then
		return definition
	end
	local decorId = string.match(itemId, "^Decor%.([%w_]+)$")
	local decor = if decorId then DecorConfig.get(decorId) else nil
	if decor then
		return { shortName = decor.name, imageId = decor.imageId, stackable = true }
	end
	local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
	local egg = if eggId then Eggs.get(eggId) else nil
	if egg and eggId then
		return { shortName = egg.name, imageId = egg.imageId, rarity = Eggs.getRarity(eggId), stackable = true }
	end
	local crabId = string.match(itemId, "^Crab%.([%w_]+)$")
	local crab = if crabId then Crabs.get(crabId) else nil
	if crab then
		return { shortName = crab.name, imageId = crab.imageId, rarity = crab.rarity }
	end
	return nil
end

function ItemCatalog.isStackable(itemId: string): boolean
	local definition = ItemCatalog.get(itemId)
	return definition ~= nil and definition.stackable == true
end

return ItemCatalog
