local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local TutorialConfig = require(ReplicatedStorage.Source.Features.Tutorial.TutorialConfig)
local useTutorialState = require(ReplicatedStorage.Source.Features.Tutorial.Hooks.useTutorialState)
local e = React.createElement

local function TutorialRoot()
	local tutorial, isTutorialActive, isUpgradePromptActive, isPlotPromptActive = useTutorialState()
	local definition = TutorialConfig.Steps[tutorial.step]
	local text = if isTutorialActive and definition
		then definition.text
		elseif isUpgradePromptActive then "BUY UPGRADES"
		elseif isPlotPromptActive then "UPGRADE YOUR PLOT"
		else nil
	if not text then return nil end

	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(18, 18, 18),
		BackgroundTransparency = 0.65,
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.125),
		Size = UDim2.new(0.5, 0, 0, 64),
		ZIndex = 1000,
	}, {
		SizeConstraint = e("UISizeConstraint", {
			MaxSize = Vector2.new(640, 64),
			MinSize = Vector2.new(280, 52),
		}),
		Fade = e("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.18, 0),
				NumberSequenceKeypoint.new(0.82, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
		Description = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.03, 0.08),
			Size = UDim2.fromScale(0.94, 0.84),
			Text = text,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 0,
			TextWrapped = false,
			ZIndex = 1001,
		}, {
			TextSize = e("UITextSizeConstraint", {
				MaxTextSize = 46,
				MinTextSize = 20,
			}),
		}),
	})
end

return TutorialRoot