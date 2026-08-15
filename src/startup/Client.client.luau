local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LeaderboardServiceClient = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardServiceClient)
local MusicController = require(ReplicatedStorage.Source.Features.App.MusicController)
local MonetizationServiceClient = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient)
local OfflineRewardsServiceClient = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsServiceClient)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local SlimeEventServiceClient = require(ReplicatedStorage.Source.Features.Slimeevent.SlimeEventServiceClient)
local SettingsServiceClient = require(ReplicatedStorage.Source.Features.Settings.SettingsServiceClient)
local MountUI = require(ReplicatedStorage.Source.StartUp.MountUI)

local _Data = require(ReplicatedStorage.Source.Game.Data).client

MusicController.init()
SettingsServiceClient:init()
MonetizationServiceClient:init()
MountUI()
OfflineRewardsServiceClient:init()
LeaderboardServiceClient:init()
PlotServiceClient:init()
SlimeEventServiceClient:init()
