local ServerScriptService = game:GetService("ServerScriptService")

local LeaderboardServiceServer = require(ServerScriptService.Features.Leaderboards.LeaderboardServiceServer)
local MonetizationServiceServer = require(ServerScriptService.Features.Monetization.MonetizationServiceServer)
local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)

MonetizationServiceServer:init()
LeaderboardServiceServer:init()
PlotServiceServer:init()
