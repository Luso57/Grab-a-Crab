local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local function InventoryRoot()
	return React.createElement(React.Fragment)
end

return InventoryRoot
