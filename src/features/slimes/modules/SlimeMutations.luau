export type MutationId = "normal" | "fire" | "blackMatter"

export type MutationDefinition = {
	id: MutationId,
	name: string,
	color: Color3,
	incomeMultiplier: number,
	effectTemplate: string?,
}

local definitions: { [MutationId]: MutationDefinition } = {
	normal = {
		id = "normal",
		name = "Normal",
		color = Color3.new(1, 1, 1),
		incomeMultiplier = 1,
		effectTemplate = nil,
	},
	fire = {
		id = "fire",
		name = "Fire",
		color = Color3.fromRGB(255, 92, 28),
		incomeMultiplier = 2,
		effectTemplate = "Fire",
	},
	blackMatter = {
		id = "blackMatter",
		name = "Black Matter",
		color = Color3.fromRGB(178, 63, 255),
		incomeMultiplier = 10,
		effectTemplate = "BlackMatter",
	},
}

local SlimeMutations = {}

function SlimeMutations.getId(mutationId: string?): MutationId
	return if mutationId == "fire" or mutationId == "blackMatter" then mutationId else "normal"
end

function SlimeMutations.get(mutationId: string?): MutationDefinition
	return definitions[SlimeMutations.getId(mutationId)]
end

function SlimeMutations.roll(random: Random?): MutationId
	local value = if random then random:NextNumber() else math.random()
	if value < 0.01 then
		return "blackMatter"
	elseif value < 0.11 then
		return "fire"
	end
	return "normal"
end

function SlimeMutations.getIncomeMultiplier(mutationId: string?): number
	return SlimeMutations.get(mutationId).incomeMultiplier
end

function SlimeMutations.getDisplayName(mutationId: string?): string
	return SlimeMutations.get(mutationId).name
end

function SlimeMutations.getColor(mutationId: string?): Color3
	return SlimeMutations.get(mutationId).color
end

return SlimeMutations
