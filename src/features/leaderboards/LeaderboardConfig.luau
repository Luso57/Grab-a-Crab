local LeaderboardConfig = {
	TopCount = 10,
	RefreshInterval = 60,
	StoreVersion = "v1",
	BoardNames = {
		LeaderBoard_TimePlayed = "timePlayed",
		LeaderBoard_MostMoney = "mostMoney",
		LeaderBoard_RobuxSpent = "robuxSpent",
	},
	Titles = {
		timePlayed = "TIME PLAYED",
		mostMoney = "MOST MONEY",
		robuxSpent = "ROBUX SPENT",
	},
}

export type BoardKind = "timePlayed" | "mostMoney" | "robuxSpent"

return LeaderboardConfig
