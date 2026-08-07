-- invisible parts that allow you to spawn in stuff in the invis parts

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataTemplate = require(ReplicatedStorage.Source.Game.Items.DataTemplate)

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
	currentSlimeId: string?,
	plotLevel: number,
	slimes: { DataTemplate.SlimeData },
}

return PlotTypes
