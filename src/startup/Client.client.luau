local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardServiceClient = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardServiceClient)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local MountUI = require(script.Parent.MountUI)

local _Data = require(ReplicatedStorage.Source.Game.Data).client

MountUI()
LeaderboardServiceClient:init()
PlotServiceClient:init()
