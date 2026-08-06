export type SlimeData = {
	instanceId: string,
	slimeId: string,
	mutationId: string,
	storedSlime: number,
}

return {
	currency = 100000000000000000,
	slimeCurrency = 20300,
	slimeQueue = 0,
	uncollectedCash = 0,
	slimesPerSecond = 5,
	sellUpgradeLevel = 0,
	slimeLuckLevel = 0,
	cashMultiplierLevel = 0,
	slimes = {} :: { SlimeData },
	inventory = {},
}
