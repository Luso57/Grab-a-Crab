-- invisible parts that allow you to spawn in stuff in the invis parts

local PlotTypes = {}

export type PlotSpawn = {
	part: BasePart,
	owner: Player?,
	index: number,
	fakePlot: Model,
}

export type PlotData = {
	cf: CFrame,
	index: number,
	player: Player,
	plotModel: Model,
}

return PlotTypes
