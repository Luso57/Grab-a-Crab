--!strict

export type IncubatorDefinition = {
	name: string,
	modelName: string,
}

local definitions: { [string]: IncubatorDefinition } = {
	Incubator = { name = "Incubator", modelName = "Incubator" },
}

local Incubators = {}

function Incubators.get(incubatorId: string): IncubatorDefinition?
	return definitions[incubatorId]
end

return Incubators
