local ServerScriptService = game:GetService("ServerScriptService")

local LeaderboardServiceServer = require(ServerScriptService.Features.Leaderboards.LeaderboardServiceServer)
local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)

LeaderboardServiceServer:init()
PlotServiceServer:init()
