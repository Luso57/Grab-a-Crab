local PlotLevelConfig = {
	StartingLevel = 1,
	MaxLevel = 4,
	LevelCosts = {
		[2] = 100_000,
		[3] = 1_000_000,
		[4] = 10_000_000,
	},
}

function PlotLevelConfig.getLevel(level: number?): number
	local safeLevel = if type(level) == "number" and level == level then math.floor(level) else PlotLevelConfig.StartingLevel
	return math.clamp(safeLevel, PlotLevelConfig.StartingLevel, PlotLevelConfig.MaxLevel)
end

function PlotLevelConfig.getCost(level: number): number?
	return PlotLevelConfig.LevelCosts[PlotLevelConfig.getLevel(level)]
end

return PlotLevelConfig
