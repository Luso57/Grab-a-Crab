local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local BottomBar = require(ReplicatedStorage.Source.Features.App.Hud.BottomBar)

local function HudRoot()
	return React.createElement(React.Fragment, nil, {
		BottomBar = React.createElement(BottomBar),
	})
end

return HudRoot
