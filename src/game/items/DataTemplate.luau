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
	hatchedEggId: string?,
	isGiganticEgg: boolean?,
	firstGiganticEggBonus: boolean?,
}

export type PlayerData = {
	inventory: { [string]: SavedItem },
	hotbar: { string },
	money: number,
	maxMoney: number,
	conveyorLuck: number,
	extraSlotsPurchased: number,
	inventoryCapacityPurchases: number,
	autoCollectOwned: boolean,
	starterPackClaimed: boolean,
	starterItemsGranted: boolean,
	tutorialStage: string,
	tutorialItemInstanceId: string,
	newPlayerHatchStatus: string,
	newPlayerPlaySeconds: number,
	lifetimePlaySeconds: number,
	biggestCrabGrams: number,
	firstGiganticEggReceived: boolean,
	discoveredCrabs: { [string]: boolean },
	discoveredCrabSizes: { [string]: boolean },
	claimedIndexMilestones: { [string]: boolean },
	processedProductReceipts: { [string]: string },
	pendingEggProductPurchase: { productId: number, eggId: string, isGiganticEgg: boolean, intentId: string },
	pendingRollAgainInstanceId: string,
	pendingHatchNowPurchase: { incubatorInstanceId: string, eggInstanceId: string, hatchAtUnixMs: number, intentToken: string },
	musicEnabled: boolean,
	soundEffectsEnabled: boolean,
}

local emptySlot = InventoryConfig.emptySlot

local template: PlayerData = {
	inventory = {},
	money = 3500,
	maxMoney = 500,
	conveyorLuck = 0,
	extraSlotsPurchased = 0,
	inventoryCapacityPurchases = 0,
	autoCollectOwned = false,
	starterPackClaimed = false,
	starterItemsGranted = false,
	tutorialStage = "Uninitialized",
	tutorialItemInstanceId = "",
	newPlayerHatchStatus = "Uninitialized",
	newPlayerPlaySeconds = 0,
	lifetimePlaySeconds = 0,
	biggestCrabGrams = 0,
	firstGiganticEggReceived = false,
	discoveredCrabs = {},
	discoveredCrabSizes = {},
	claimedIndexMilestones = {},
	processedProductReceipts = {},
	pendingEggProductPurchase = { productId = 0, eggId = "", isGiganticEgg = false, intentId = "" },
	pendingRollAgainInstanceId = "",
	pendingHatchNowPurchase = { incubatorInstanceId = "", eggInstanceId = "", hatchAtUnixMs = 0, intentToken = "" },
	musicEnabled = true,
	soundEffectsEnabled = true,
	hotbar = {
		emptySlot, emptySlot, emptySlot,
		emptySlot, emptySlot, emptySlot,
		emptySlot, emptySlot, emptySlot,
	},
}

return template
