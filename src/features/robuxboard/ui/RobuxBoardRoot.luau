local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local RobuxBoard = require(ReplicatedStorage.Source.Features.RobuxBoard.UI.Screens.RobuxBoard)

local function RobuxBoardRoot()
	return React.createElement(RobuxBoard)
end

return RobuxBoardRoot
