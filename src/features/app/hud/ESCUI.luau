local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local OfflineRewardsConfig = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsConfig)
local OfflineRewardCalculator = require(
	ReplicatedStorage.Source.Features.Offlinerewards.Modules.OfflineRewardCalculator
)

local TEXT_COLOR = Color3.fromRGB(139, 139, 139)
local AMOUNT_COLOR = "#169C2F"

local function getTomorrowAmount(slimes): string
	local amount = OfflineRewardCalculator.getRewardAmount(slimes, OfflineRewardsConfig.MaximumOfflineSeconds)
	return string.upper(CompactNumber.format(amount, 1))
end

local function ESCUI()
	local isMenuOpen, setMenuOpen = React.useState(false)
	local tomorrowAmount, setTomorrowAmount = React.useState(getTomorrowAmount(PlayerData.slimes()))

	React.useEffect(function()
		local menuOpened = GuiService.MenuOpened:Connect(function()
			setMenuOpen(true)
		end)
		local menuClosed = GuiService.MenuClosed:Connect(function()
			setMenuOpen(false)
		end)
		local slimesChanged = PlayerData.slimes.Changed(function(slimes)
			setTomorrowAmount(getTomorrowAmount(slimes))
		end)

		return function()
			menuOpened:Disconnect()
			menuClosed:Disconnect()
			slimesChanged()
		end
	end, {})

	if not isMenuOpen then return nil end

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 100,
	}, {
		TopText = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.005),
			Size = UDim2.fromScale(0.9, 0.105),
			Text = "YOU EARN SLIME OFFLINE",
			TextColor3 = TEXT_COLOR,
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 101,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 72,
				MinTextSize = 18,
			}),
		}),
		BottomText = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.995),
			RichText = true,
			Size = UDim2.fromScale(0.78, 0.105),
			Text = `COME BACK TOMORROW FOR <font color="{AMOUNT_COLOR}">{tomorrowAmount}</font>`,
			TextColor3 = TEXT_COLOR,
			TextScaled = true,
			TextStrokeTransparency = 1,
			ZIndex = 101,
		}, {
			TextSizeConstraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 64,
				MinTextSize = 16,
			}),
		}),
	})
end

return ESCUI
