local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local PHONE_SHORT_EDGE_MAX = 600

local function isPhoneViewport(): boolean
	local camera = Workspace.CurrentCamera
	if not camera or not UserInputService.TouchEnabled then
		return false
	end

	local viewportSize = camera.ViewportSize
	return math.min(viewportSize.X, viewportSize.Y) <= PHONE_SHORT_EDGE_MAX
end

local function useIsPhoneViewport(): boolean
	local isPhone, setIsPhone = React.useState(isPhoneViewport())

	React.useEffect(function()
		local viewportConnection: RBXScriptConnection? = nil

		local function update()
			setIsPhone(isPhoneViewport())
		end

		local function connectCamera()
			if viewportConnection then
				viewportConnection:Disconnect()
			end

			local camera = Workspace.CurrentCamera
			viewportConnection = if camera
				then camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
				else nil
			update()
		end

		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
		local touchConnection = UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(update)
		connectCamera()

		return function()
			cameraConnection:Disconnect()
			touchConnection:Disconnect()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
		end
	end, {})

	return isPhone
end

return useIsPhoneViewport
