export type SlimeData = {
	instanceId: string,
	slimeId: string,
	mutationId: string,
	storedSlime: number,
	level: number,
	upgradeInvestment: number,
	playpenLevel: number,
}

return {
	currency = 100000000000000,
	slimeCurrency = 0,
	slimeQueue = 0,
	uncollectedCash = 0,
	slimesPerSecond = 5,
	sellUpgradeLevel = 0,
	slimeLuckLevel = 0,
	cashMultiplierLevel = 0,
	rebirths = 0,
	plotLevel = 1,
	timePlayedSeconds = 0,
	robuxSpent = 0,
	slimes = {} :: { SlimeData },
	inventory = {},
}
