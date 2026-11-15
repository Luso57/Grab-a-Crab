--!strict

export type IncubatorDefinition = {
	name: string,
	modelName: string,
}

local definitions: { [string]: IncubatorDefinition } = {
	Incubator = { name = "Incubator", modelName = "Incubator" },
	InstantHatch = { name = "Instant Hatch Incubator", modelName = "SuperIncubator" },
}

local MINUTE_MS = 60 * 1000
local HOUR_MS = 60 * MINUTE_MS

-- The first six eggs in each rarity, ordered by egg price.
local earlyEpicEggs: { [string]: boolean } = {
	DeepSeaEgg = true,
	GhostEgg = true,
	ArcadeEgg = true,
	ClockworkEgg = true,
	CrystalEgg = true,
	KnightEgg = true,
}

local earlyLegendaryEggs: { [string]: boolean } = {
	AngelEgg = true,
	MoonEgg = true,
	AlienEgg = true,
	CloudEgg = true,
	DiscoEgg = true,
	LavaEgg = true,
}

-- The three cheapest Mythic eggs hatch in the shorter Mythic time.
local earlyMythicEggs: { [string]: boolean } = {
	GalaxyEgg = true,
	KingEgg = true,
	PharaohEgg = true,
}

local Incubators = {}

function Incubators.get(incubatorId: string): IncubatorDefinition?
	return definitions[incubatorId]
end

function Incubators.getHatchDurationMs(incubatorId: string, eggId: string, rarity: string): number?
	if not definitions[incubatorId] then
		return nil
	end
	if incubatorId == "InstantHatch" then
		return 0
	end
	if rarity == "Common" then
		return 3 * 1000
	elseif rarity == "Uncommon" then
		return 15 * 1000
	elseif rarity == "Rare" then
		return 30 * 1000
	elseif rarity == "Epic" then
		return if earlyEpicEggs[eggId] then 3 * MINUTE_MS else 5 * MINUTE_MS
	elseif rarity == "Legendary" then
		return if earlyLegendaryEggs[eggId] then 8 * MINUTE_MS else 15 * MINUTE_MS
	elseif rarity == "Mythic" then
		return if earlyMythicEggs[eggId] then 30 * MINUTE_MS else HOUR_MS
	end
	return nil
end

return Incubators
