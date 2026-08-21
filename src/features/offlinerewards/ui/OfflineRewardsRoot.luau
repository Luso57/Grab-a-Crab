local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local Config = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsConfig)
local OfflineRewardsServiceClient = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsServiceClient)
local OfflineRewardsSlice = require(ReplicatedStorage.Source.Features.Offlinerewards.OfflineRewardsSlice)

local CASH_MULTIPLIER_ICON = "rbxthumb://type=Asset&id=18209585851&w=420&h=420"

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function stroke(color: Color3, thickness: number)
	return React.createElement("UIStroke", {
		Color = color,
		LineJoinMode = Enum.LineJoinMode.Round,
		Thickness = thickness,
	})
end

local function formatDuration(seconds: number): string
	if seconds >= Config.MaximumOfflineSeconds then return "AWAY FOR 24H · MAX" end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then return `AWAY FOR {hours}H {minutes}M` end
	return `AWAY FOR {math.max(1, minutes)}M`
end

local function OfflineRewardsRoot(props: Props)
	local offer = ReactCharm.useAtom(OfflineRewardsSlice.state.offer)

	if not props.IsOpen or not offer then return nil end
	local disabled = offer.awaitingDouble

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(4, 6, 13),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
	}, {
		Window = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(35, 38, 44),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.48, 0.61),
			ZIndex = 41,
		}, {
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1.3,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(700, 540),
				MinSize = Vector2.new(350, 300),
			}),
			Outline = stroke(Color3.fromRGB(11, 12, 15), 5),
			Header = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(82, 208, 239),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Size = UDim2.new(1, 0, 0.18, 0),
				ZIndex = 43,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 11) }),
				Outline = stroke(Color3.fromRGB(15, 25, 31), 4),
				Studs = React.createElement("ImageLabel", {
					BackgroundTransparency = 1,
					Image = Config.StudBackgroundImage,
					ImageColor3 = Color3.fromRGB(128, 231, 250),
					ImageTransparency = 0.4,
					ScaleType = Enum.ScaleType.Tile,
					Size = UDim2.fromScale(1, 1),
					TileSize = UDim2.fromOffset(38, 38),
					ZIndex = 43,
				}),
				Icon = React.createElement("ImageLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = CASH_MULTIPLIER_ICON,
					Position = UDim2.fromScale(0.025, 0.5),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.115, 0.86),
					ZIndex = 44,
				}),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.155, 0.5),
					Size = UDim2.fromScale(0.66, 0.68),
					Text = "OFFLINE SLIME",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 44,
				}),
				Close = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(222, 42, 45),
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.955, 0.5),
					Size = UDim2.fromScale(0.105, 0.68),
					Text = "X",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 45,
					[React.Event.Activated] = function()
						UISounds.playSelect()
						props.OnClose()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 7) }),
					Outline = stroke(Color3.fromRGB(95, 9, 12), 4),
				}),
			}),
			Content = React.createElement("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(27, 29, 34),
				BorderSizePixel = 0,
				Image = Config.StudBackgroundImage,
				ImageColor3 = Color3.fromRGB(62, 65, 72),
				ImageTransparency = 0.58,
				Position = UDim2.fromScale(0.045, 0.22),
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(0.91, 0.72),
				TileSize = UDim2.fromOffset(42, 42),
				ZIndex = 42,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 9) }),
				Time = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.08, 0.03),
					Size = UDim2.fromScale(0.84, 0.12),
					Text = formatDuration(offer.offlineSeconds),
					TextColor3 = Color3.fromRGB(255, 232, 118),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 44,
				}),
				Slime = React.createElement("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundTransparency = 1,
					Image = Config.SlimeImage,
					Position = UDim2.fromScale(0.5, 0.15),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.36, 0.4),
					ZIndex = 44,
				}),
				Amount = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.08, 0.52),
					Size = UDim2.fromScale(0.84, 0.14),
					Text = `{CompactNumber.format(offer.amount, 1)} SLIME`,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 44,
				}),
				Claim = React.createElement("TextButton", {
					Active = not disabled,
					AutoButtonColor = not disabled,
					BackgroundColor3 = if disabled then Color3.fromRGB(95, 105, 98) else Color3.fromRGB(63, 224, 78),
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.06, 0.72),
					Size = UDim2.fromScale(0.41, 0.19),
					Text = "CLAIM",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 44,
					[React.Event.Activated] = if disabled then nil else function()
						UISounds.playSelect()
						OfflineRewardsServiceClient:claim()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Outline = stroke(Color3.fromRGB(14, 104, 34), 4),
				}),
				Double = React.createElement("TextButton", {
					Active = not disabled,
					AutoButtonColor = not disabled,
					BackgroundColor3 = if disabled then Color3.fromRGB(130, 113, 70) else Color3.fromRGB(255, 194, 50),
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.53, 0.72),
					Size = UDim2.fromScale(0.41, 0.19),
					Text = if disabled then "WAITING..." else "CLAIM x2",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 44,
					[React.Event.Activated] = if disabled then nil else function()
						UISounds.playSelect()
						OfflineRewardsServiceClient:requestDouble()
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
					Outline = stroke(Color3.fromRGB(130, 82, 10), 4),
				}),
			}),
		}),
	})
end

return OfflineRewardsRoot
