--!strict

local RunService = game:GetService("RunService")

local TutorialShopPrompt = {}

-- Show the tutorial cue directly beneath the existing top-bar Shop button.
function TutorialShopPrompt.mount(playerGui: PlayerGui): (boolean) -> ()
	local travelBar = playerGui:WaitForChild("TravelBar") :: ScreenGui
	local cards = travelBar:WaitForChild("Cards") :: CanvasGroup
	local shopButton = cards:WaitForChild("Shop") :: ImageButton

	local arrow = Instance.new("TextLabel")
	arrow.Name = "TutorialShopArrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.Size = UDim2.fromOffset(64, 48)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▲"
	arrow.TextColor3 = Color3.fromRGB(255, 176, 72)
	arrow.TextStrokeColor3 = Color3.fromRGB(52, 31, 13)
	arrow.TextStrokeTransparency = 0
	arrow.Font = Enum.Font.BuilderSansExtraBold
	arrow.TextSize = 48
	arrow.ZIndex = 20
	arrow.Visible = false
	arrow.Parent = travelBar

	local arrowOutline = Instance.new("UIStroke")
	arrowOutline.Color = Color3.fromRGB(255, 229, 170)
	arrowOutline.Thickness = 2
	arrowOutline.Parent = arrow

	local label = Instance.new("TextLabel")
	label.Name = "TutorialShopInstruction"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Size = UDim2.fromOffset(240, 30)
	label.BackgroundTransparency = 1
	label.Text = "BUY MORE TANKS"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextSize = 20
	label.ZIndex = 20
	label.Visible = false
	label.Parent = travelBar

	local active = false
	local renderConnection = RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local centerX = shopButton.AbsolutePosition.X + shopButton.AbsoluteSize.X * 0.5
		local promptY = shopButton.AbsolutePosition.Y + shopButton.AbsoluteSize.Y + 34
		local bob = math.round(math.sin(os.clock() * 3.2) * 5)
		arrow.Position = UDim2.fromOffset(centerX, promptY + bob)
		label.Position = UDim2.fromOffset(centerX, promptY + 49)
	end)

	travelBar.Destroying:Connect(function()
		renderConnection:Disconnect()
	end)

	return function(enabled: boolean)
		active = enabled
		arrow.Visible = enabled
		label.Visible = enabled
	end
end

return TutorialShopPrompt
