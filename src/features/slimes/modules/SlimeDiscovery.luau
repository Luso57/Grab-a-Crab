local SlimeDiscovery = {}

function SlimeDiscovery.getKey(slimeId: string, mutationId: string): string
	return `{mutationId}:{slimeId}`
end

function SlimeDiscovery.isDiscovered(
	discoveredSlimes: { [string]: boolean },
	slimeId: string,
	mutationId: string
): boolean
	return discoveredSlimes[SlimeDiscovery.getKey(slimeId, mutationId)] == true
end

return SlimeDiscovery
