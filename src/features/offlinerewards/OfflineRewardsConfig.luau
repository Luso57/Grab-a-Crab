return {
	NetworkTag = "OfflineRewardsService",
	MinimumOfflineSeconds = 5 * 60,
	MaximumOfflineSeconds = 24 * 60 * 60,
	OfflineProductionRate = 0.25,
	ActivitySaveInterval = 60,
	-- TESTING: Keep this true to show a sample offline reward every time a player
	-- joins without an existing pending reward. Set it to false before release.
	TestingPopupOnJoin = true,
	TestingRewardAmount = 500,
	TestingOfflineSeconds = 60 * 60,
	DoubleProductKey = "doubleOfflineSlime",
	SlimeImage = "rbxthumb://type=Asset&id=137154481767301&w=420&h=420",
	StudBackgroundImage = "rbxassetid://88022115777392",
}
