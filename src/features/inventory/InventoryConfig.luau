--!strict

return {
	hotbarSize = 9,
	emptySlot = "NULL",
	maxItems = 100,
	hammerItemId = "Hammer",
	hammerSlot = 1,
	hammerInstanceId = function(userId: number): string
		return "StarterHammer:" .. userId
	end,
}
