local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardSlice = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardSlice)
local LeaderboardTypes = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardTypes)
local Networker = require(ReplicatedStorage.Packages.Networker)

type Snapshot = LeaderboardTypes.Snapshot

local LeaderboardServiceClient = {}

function LeaderboardServiceClient.snapshot(self, nextSnapshot: Snapshot)
	if type(nextSnapshot) ~= "table" then
		return
	end
	LeaderboardSlice.actions.setSnapshot(nextSnapshot)
end

function LeaderboardServiceClient.init(self)
	self.networker = Networker.client.new("LeaderboardService", self)
	self.networker:fire("requestSnapshot")
end

return LeaderboardServiceClient
