export type SlimeData = {
	instanceId: string,
	slimeId: string,
	mutationId: string,
	storedSlime: number,
	level: number,
	upgradeInvestment: number,
	playpenLevel: number,
}

export type PendingBuySlime = {
	active: boolean,
	slimeId: string,
	mutationId: string,
	offerIndex: number,
	playpenLevel: number,
}

export type PendingOfflineReward = {
	active: boolean,
	amount: number,
	offlineSeconds: number,
	awaitingDouble: boolean,
}

return {
	currency = 10,
	slimeCurrency = 0,
	slimeQueue = 0,
	uncollectedCash = 0,
	slimesPerSecond = 10,
	sellUpgradeLevel = 0,
	slimeLuckLevel = 0,
	cashMultiplierLevel = 0,
	rebirths = 0,
	plotLevel = 1,
	timePlayedSeconds = 0,
	robuxSpent = 0,
	musicEnabled = true,
	soundEffectsEnabled = true,
	musicVolume = -1,
	soundEffectsVolume = -1,
	ownedProducts = {} :: { [string]: boolean },
	processedPurchaseIds = {} :: { [string]: boolean },
	pendingBuySlime = {
		active = false,
		slimeId = "",
		mutationId = "normal",
		offerIndex = 1,
		playpenLevel = 1,
	} :: PendingBuySlime,
	lastActiveUnix = 0,
	pendingOfflineReward = {
		active = false,
		amount = 0,
		offlineSeconds = 0,
		awaitingDouble = false,
	} :: PendingOfflineReward,
	slimes = {} :: { SlimeData },
	discoveredSlimes = {} :: { [string]: boolean },
	inventory = {},
}
