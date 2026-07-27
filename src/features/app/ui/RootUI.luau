local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SlimeBillboards = require(ReplicatedStorage.Source.Features.Slimes.UI.SlimeBillboards)

local function RootUI()
	return React.createElement(React.Fragment, nil, {
		SlimeBillboards = React.createElement(SlimeBillboards),
	})
end

return RootUI
