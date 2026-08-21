export type SlimeData = {
	instanceId: string,
	slimeId: string,
	mutationId: string,
	storedSlime: number,
	level: number,
	upgradeInvestment: number,
	playpenLevel: number,
	purchasedWithRobux: boolean,
}

export type PendingBuySlime = {
	active: boolean,
	slimeId: string,
	mutationId: string,
	offerIndex: number,
	playpenLevel: number,
	productKey: string,
}

export type RolledSlimeOffer = {
	slimeId: string,
	mutationId: string,
}

export type RolledSlimeOffers = {
	primary: RolledSlimeOffer,
	secondary: RolledSlimeOffer,
}

export type PendingUpgradePurchase = {
	active: boolean,
	upgradeType: string,
	quantity: number,
}

export type PendingOfflineReward = {
	active: boolean,
	amount: number,
	offlineSeconds: number,
	awaitingDouble: boolean,
}

export type TutorialData = {
	version: number,
	step: string,
	completed: boolean,
	targetSlimeInstanceId: string,
}

return {
	currency = 0,
	slimeCurrency = 0,
	slimeQueue = 0,
	uncollectedCash = 0,
	slimesPerSecond = 10,
	sellUpgradeLevel = 0,
	slimeLuckLevel = 0,
	cashMultiplierLevel = 0,
	hasPurchasedBoardCashUpgrade = false,
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
	pending5xLuckSpins = 0,
	pending99xLuckSpins = 0, -- Legacy queued spins; migrated when the plot loads.
	pendingBuySlime = {
		active = false,
		slimeId = "",
		mutationId = "normal",
		offerIndex = 1,
		playpenLevel = 1,
		productKey = "",
	} :: PendingBuySlime,
	rolledSlimeOffers = {
		primary = { slimeId = "", mutationId = "normal" },
		secondary = { slimeId = "", mutationId = "normal" },
	} :: RolledSlimeOffers,
	pendingUpgradePurchase = {
		active = false,
		upgradeType = "",
		quantity = 0,
	} :: PendingUpgradePurchase,
	lastActiveUnix = 0,
	pendingOfflineReward = {
		active = false,
		amount = 0,
		offlineSeconds = 0,
		awaitingDouble = false,
	} :: PendingOfflineReward,
	tutorial = {
		version = 0,
		step = "",
		completed = false,
		targetSlimeInstanceId = "",
	} :: TutorialData,
	slimes = {} :: { SlimeData },
	discoveredSlimes = {} :: { [string]: boolean },
	inventory = {},
}
