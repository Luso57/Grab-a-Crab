--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)

export type SavedItem = {
	itemId: string,
	placedSlotId: string?,
	incubatorInstanceId: string?,
	tankInstanceId: string?,
	hatchAtUnixMs: number?,
}

export type PlayerData = {
	inventory: { [string]: SavedItem },
	hotbar: { string },
	money: number,
}

local emptySlot = InventoryConfig.emptySlot

local template: PlayerData = {
	inventory = {},
	money = 0,
	hotbar = {
		emptySlot, emptySlot, emptySlot,
		emptySlot, emptySlot, emptySlot,
		emptySlot, emptySlot, emptySlot,
	},
}

return template
