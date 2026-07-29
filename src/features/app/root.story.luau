local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local RootUI = require(script.Parent.RootUI)

return function(parent: Instance): () -> ()
	local root = ReactRoblox.createRoot(parent)
	root:render(React.createElement(RootUI))

	return function()
		root:unmount()
	end
end
