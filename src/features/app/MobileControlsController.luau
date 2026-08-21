local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PHONE_SHORT_EDGE_MAX = 600
local PHONE_JUMP_POSITION = UDim2.new(1, -190, 1, -90)

local MobileControlsController = {
	initialized = false,
}

local function isPhoneViewport(): boolean
	local camera = Workspace.CurrentCamera
	if not camera or not UserInputService.TouchEnabled then
		return false
	end

	local viewportSize = camera.ViewportSize
	return math.min(viewportSize.X, viewportSize.Y) <= PHONE_SHORT_EDGE_MAX
end

function MobileControlsController.init(self)
	if self.initialized then
		return
	end
	self.initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local defaultPositions: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" })

	local function updateJumpButton()
		local jumpButton = playerGui:FindFirstChild("JumpButton", true)
		if not jumpButton or not jumpButton:IsA("GuiObject") then
			return
		end

		if defaultPositions[jumpButton] == nil then
			defaultPositions[jumpButton] = jumpButton.Position
		end

		jumpButton.Position = if isPhoneViewport()
			then PHONE_JUMP_POSITION
			else defaultPositions[jumpButton]
	end

	local viewportConnection: RBXScriptConnection? = nil
	local function connectCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end

		local camera = Workspace.CurrentCamera
		viewportConnection = if camera
			then camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateJumpButton)
			else nil
		updateJumpButton()
	end

	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(connectCamera)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateJumpButton)
	playerGui.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "JumpButton" and descendant:IsA("GuiObject") then
			task.defer(updateJumpButton)
		end
	end)

	connectCamera()
end

return MobileControlsController
