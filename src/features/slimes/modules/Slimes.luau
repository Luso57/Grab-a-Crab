local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type SlimeDefinition = {
	name: string,
	rarity: string,
	image: string,
	cost: number,
	chance: number,
}

export type SlimeInfo = SlimeDefinition & {
	id: string,
}

local slimeDefinitions: { [string]: SlimeDefinition } = {
	green = {
		name = "Green Slime",
		rarity = "Common",
		image = "rbxassetid://0",
		cost = 100,
		chance = 1,
	},

	blue = {
		name = "Blue Slime",
		rarity = "Uncommon",
		image = "rbxassetid://0",
		cost = 250,
		chance = 2,
	},

	pink = {
		name = "Pink Slime",
		rarity = "Rare",
		image = "rbxassetid://0",
		cost = 1_000,
		chance = 4,
	},

	gold = {
		name = "Gold Slime",
		rarity = "Epic",
		image = "rbxassetid://0",
		cost = 2_500,
		chance = 8,
	},

	purple = {
		name = "Galaxy Slime",
		rarity = "Legendary",
		image = "rbxassetid://0",
		cost = 5_000,
		chance = 5000,
	},
}

local slimes: { [string]: SlimeInfo } = {}
local slimeIds: { string } = {}
local totalRollWeight = 0

for slimeId, slimeDefinition in slimeDefinitions do
	assert(slimeDefinition.chance > 0, `Slime chance must be greater than zero: {slimeId}`)

	slimes[slimeId] = {
		id = slimeId,
		name = slimeDefinition.name,
		rarity = slimeDefinition.rarity,
		image = slimeDefinition.image,
		cost = slimeDefinition.cost,
		chance = slimeDefinition.chance,
	}
	table.insert(slimeIds, slimeId)
	totalRollWeight += 1 / slimeDefinition.chance
end

table.sort(slimeIds)

local Slimes = {
	slimes = slimes,
	slimeIds = slimeIds,
}

function Slimes.isValidSlimeId(slimeId: string): boolean
	return slimes[slimeId] ~= nil
end

function Slimes.getSlimeInfo(slimeId: string): SlimeInfo
	local slimeInfo = slimes[slimeId]
	assert(slimeInfo, `Invalid slime ID: {slimeId}`)

	return slimeInfo
end

function Slimes.getRandomSlimeId(): string
	assert(#slimeIds > 0, "Cannot roll a slime because the slime catalog is empty")

	local roll = math.random() * totalRollWeight
	local cumulativeWeight = 0

	for _, slimeId in slimeIds do
		local slimeInfo = slimes[slimeId]
		cumulativeWeight += 1 / slimeInfo.chance

		if roll <= cumulativeWeight then
			return slimeId
		end
	end

	return slimeIds[#slimeIds]
end

function Slimes.getSlimeModel(slimeId: string): Model
	Slimes.getSlimeInfo(slimeId)

	local assets = ReplicatedStorage:WaitForChild("Assets")
	local slimeAssets = assets:WaitForChild("Slimes")
	local slimeAsset = slimeAssets:FindFirstChild(slimeId)

	assert(slimeAsset and slimeAsset:IsA("Model"), `Missing or invalid slime model: {slimeId}`)

	return slimeAsset:Clone()
end

return Slimes
