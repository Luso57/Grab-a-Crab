local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local LeaderboardTypes = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardTypes)

type Snapshot = LeaderboardTypes.Snapshot

local emptySnapshot: Snapshot = {
	timePlayed = {},
	mostMoney = {},
	robuxSpent = {},
}

local snapshot = Charm.atom(emptySnapshot)

local LeaderboardSlice = {
	state = {
		snapshot = snapshot,
	},
	actions = {
		setSnapshot = function(nextSnapshot: Snapshot)
			snapshot(nextSnapshot)
		end,
	},
}

return LeaderboardSlice
