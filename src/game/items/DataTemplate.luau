--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)

export type SavedItem = {
	itemId: string,
	placedSlotId: string?,
	incubatorInstanceId: string?,
	tankInstanceId: string?,
	decorSlot: number?,
	decorX: number?,
	decorZ: number?,
	decorRotation: number?,
	hatchAtUnixMs: number?,
	weightGrams: number?,
}

export type PlayerData = {
	inventory: { [string]: SavedItem },
	hotbar: { string },
	money: number,
	conveyorLuck: number,
	extraSlotsPurchased: number,
	starterItemsGranted: boolean,
	discoveredCrabs: { [string]: boolean },
	discoveredCrabSizes: { [string]: boolean },
	claimedIndexMilestones: { [string]: boolean },
}

local emptySlot = InventoryConfig.emptySlot

local template: PlayerData = {
	inventory = {},
	money = 500,
	conveyorLuck = 0,
	extraSlotsPurchased = 0,
	starterItemsGranted = false,
	discoveredCrabs = {},
	discoveredCrabSizes = {},
	claimedIndexMilestones = {},
	hotbar = {
		emptySlot, emptySlot, emptySlot,
		emptySlot, emptySlot, emptySlot,
		emptySlot, emptySlot, emptySlot,
	},
}

return template
