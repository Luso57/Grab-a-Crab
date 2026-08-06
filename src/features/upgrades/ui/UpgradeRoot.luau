local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UpgradeBoard = require(ReplicatedStorage.Source.Features.Upgrades.UI.Screens.UpgradeBoard)

local function UpgradeRoot()
	return React.createElement(UpgradeBoard)
end

return UpgradeRoot
