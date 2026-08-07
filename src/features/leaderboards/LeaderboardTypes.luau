local LeaderboardTypes = {}

export type BoardKind = "timePlayed" | "mostMoney" | "robuxSpent"

export type Entry = {
	userId: number,
	username: string,
	score: number,
}

export type Snapshot = {
	timePlayed: { Entry },
	mostMoney: { Entry },
	robuxSpent: { Entry },
}

return LeaderboardTypes
