local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardServiceClient = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardServiceClient)
local MonetizationServiceClient = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local MountUI = require(script.Parent.MountUI)

local _Data = require(ReplicatedStorage.Source.Game.Data).client

MonetizationServiceClient:init()
MountUI()
LeaderboardServiceClient:init()
PlotServiceClient:init()
