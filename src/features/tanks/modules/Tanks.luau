--!strict

export type TankDefinition = {
	name: string,
	modelName: string,
	capacity: number,
}

-- These IDs match the shop entries. Model templates live in ReplicatedStorage.Assets.Tanks.
local definitions: { [string]: TankDefinition } = {
	Small = { name = "Small Tank", modelName = "SmallTank", capacity = 1 },
	Medium = { name = "Medium Tank", modelName = "MediumTank", capacity = 2 },
	Large = { name = "Large Tank", modelName = "LargeTank", capacity = 3 },
}

local Tanks = {}

function Tanks.get(tankId: string): TankDefinition?
	return definitions[tankId]
end

return Tanks