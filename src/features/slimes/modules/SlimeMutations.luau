local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Slimes = require(ReplicatedStorage.Source.Features.Slimes.Modules.Slimes)

export type MutationId = "normal" | "fire" | "blackMatter" | "speed" | "event"

export type MutationDefinition = {
	id: MutationId,
	name: string,
	color: Color3,
	incomeMultiplier: number,
	playerSpeedBonus: number,
	billboardText: string?,
	effectTemplate: string?,
}

local SPEED_ELIGIBLE_SLIMES = {
	green = true,
	LifeguardSlime = true,
	NinjaSlime = true,
	NismoSlime = true,
	SharkSlime = true,
	CobraSlime = true,
	KitsuneSlime = true,
}

local definitions: { [MutationId]: MutationDefinition } = {
	normal = {
		id = "normal",
		name = "Normal",
		color = Color3.new(1, 1, 1),
		incomeMultiplier = 1,
		playerSpeedBonus = 0,
		billboardText = nil,
		effectTemplate = nil,
	},
	fire = {
		id = "fire",
		name = "Fire",
		color = Color3.fromRGB(255, 92, 28),
		incomeMultiplier = 2,
		playerSpeedBonus = 0,
		billboardText = nil,
		effectTemplate = "Fire",
	},
	blackMatter = {
		id = "blackMatter",
		name = "Black Matter",
		color = Color3.fromRGB(178, 63, 255),
		incomeMultiplier = 10,
		playerSpeedBonus = 0,
		billboardText = nil,
		effectTemplate = "BlackMatter",
	},
	speed = {
		id = "speed",
		name = "Speed",
		color = Color3.fromRGB(55, 170, 255),
		incomeMultiplier = 1,
		playerSpeedBonus = 1,
		billboardText = "+1 SPEED",
		effectTemplate = "Speed",
	},
	event = {
		id = "event",
		name = "Event",
		color = Color3.fromRGB(255, 55, 55),
		incomeMultiplier = 1,
		playerSpeedBonus = 0,
		billboardText = "EVENT 2x MONEY",
		effectTemplate = "Event",
	},
}

local SlimeMutations = {}

function SlimeMutations.getId(mutationId: string?): MutationId
	return if mutationId == "fire" or mutationId == "blackMatter" or mutationId == "speed" or mutationId == "event"
		then mutationId
		else "normal"
end

function SlimeMutations.get(mutationId: string?): MutationDefinition
	return definitions[SlimeMutations.getId(mutationId)]
end

function SlimeMutations.isSpeedEligible(slimeId: string): boolean
	return SPEED_ELIGIBLE_SLIMES[slimeId] == true
end

function SlimeMutations.isEventEligible(slimeId: string): boolean
	if not Slimes.isValidSlimeId(slimeId) then
		return false
	end
	local rarity = Slimes.getSlimeInfo(slimeId).rarity
	return rarity == "Common" or rarity == "Uncommon"
end

function SlimeMutations.roll(slimeId: string, random: Random?): MutationId
	local value = if random then random:NextNumber() else math.random()
	if value < 0.01 then
		return "blackMatter"
	elseif value < 0.11 then
		return "fire"
	elseif value < 0.21 and SlimeMutations.isSpeedEligible(slimeId) then
		return "speed"
	end
	return "normal"
end

function SlimeMutations.getIncomeMultiplier(mutationId: string?): number
	return SlimeMutations.get(mutationId).incomeMultiplier
end

function SlimeMutations.getPlayerSpeedBonus(mutationId: string?): number
	return SlimeMutations.get(mutationId).playerSpeedBonus
end

function SlimeMutations.getEventCashMultiplier(slimes: { { mutationId: string } }): number
	local eventSlimeCount = 0
	for _, slimeData in slimes do
		if SlimeMutations.getId(slimeData.mutationId) == "event" then
			eventSlimeCount += 1
		end
	end
	return 2 ^ eventSlimeCount
end

function SlimeMutations.getDisplayName(mutationId: string?): string
	return SlimeMutations.get(mutationId).name
end

function SlimeMutations.getColor(mutationId: string?): Color3
	return SlimeMutations.get(mutationId).color
end

return SlimeMutations
