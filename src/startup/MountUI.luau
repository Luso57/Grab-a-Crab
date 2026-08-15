local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local RootUI = require(ReplicatedStorage.Source.Features.App.RootUI)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local activeContainer: ScreenGui?
local activeRoot: ReactRoblox.RootType?

return function()
	if activeContainer and activeContainer.Parent == playerGui and activeRoot then
		return
	end

	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and child.Name == "React" then
			child:Destroy()
		end
	end

	local container = Instance.new("ScreenGui")
	container.Name = "React"
	container.IgnoreGuiInset = true
	container.ResetOnSpawn = false
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.ClipToDeviceSafeArea = false
	container.Parent = playerGui

	local root = ReactRoblox.createRoot(container)
	root:render(React.createElement(RootUI))
	activeContainer = container
	activeRoot = root
end
