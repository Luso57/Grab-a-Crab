local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local RebirthConfig = require(ReplicatedStorage.Source.Features.Rebirth.RebirthConfig)

local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"
local REBIRTH_ICON = "rbxthumb://type=Asset&id=95323324259523&w=420&h=420"
local CASH_REWARD_ICON = "rbxthumb://type=Asset&id=15040641396&w=420&h=420"
local LUCK_REWARD_ICON = "rbxthumb://type=Asset&id=17009565443&w=420&h=420"

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function outlinedText(props, thickness: number?)
	return React.createElement("TextLabel", props, {
		Stroke = React.createElement("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = thickness or 3,
		}),
	})
end

local function RebirthRoot(props: Props)
	local currency, setCurrency = React.useState(PlayerData.currency())
	local rebirths, setRebirths = React.useState(PlayerData.rebirths())

	React.useEffect(function()
		return PlayerData.currency.Changed(function(nextCurrency)
			setCurrency(nextCurrency)
		end)
	end, {})

	React.useEffect(function()
		return PlayerData.rebirths.Changed(function(nextRebirths)
			setRebirths(nextRebirths)
		end)
	end, {})

	local rebirthCost = RebirthConfig.getCost(rebirths)
	local progress = if rebirthCost == math.huge then 0 else math.clamp(currency / rebirthCost, 0, 1)
	local canRebirth = rebirthCost ~= math.huge and currency >= rebirthCost
	local nextRewardMultiplier = RebirthConfig.getNextRewardMultiplier(rebirths)

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(4, 6, 13),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = props.IsOpen,
		ZIndex = 30,
	}, {
		Window = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(35, 38, 44),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.54, 0.72),
			ZIndex = 31,
		}, {
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1.3,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(780, 600),
				MinSize = Vector2.new(390, 360),
			}),
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(11, 12, 15),
				Thickness = 5,
			}),
			Header = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(239, 54, 61),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Size = UDim2.fromScale(1, 0.16),
				ZIndex = 33,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 11) }),
				Studs = React.createElement("ImageLabel", {
					BackgroundTransparency = 1,
					Image = STUD_BACKGROUND_IMAGE,
					ImageColor3 = Color3.fromRGB(255, 116, 120),
					ImageTransparency = 0.35,
					ScaleType = Enum.ScaleType.Tile,
					Size = UDim2.fromScale(1, 1),
					TileSize = UDim2.fromOffset(38, 38),
					ZIndex = 33,
				}),
				Icon = React.createElement("ImageLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Image = REBIRTH_ICON,
					Position = UDim2.fromScale(0.025, 0.5),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.115, 0.86),
					ZIndex = 34,
				}),
				Title = outlinedText({
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.145, 0.5),
					Size = UDim2.fromScale(0.56, 0.68),
					Text = "REBIRTH",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 34,
				}, 5),
				Close = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(222, 42, 45),
					BorderSizePixel = 0,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.965, 0.5),
					Size = UDim2.fromScale(0.105, 0.68),
					Text = "X",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 35,
					[React.Event.Activated] = function()
						UISounds.playSelect()
						props.OnClose()
					end,
				}, {
					AspectRatio = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 7) }),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.fromRGB(95, 9, 12),
						Thickness = 4,
					}),
				}),
			}),
			Content = React.createElement("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(27, 29, 34),
				BorderSizePixel = 0,
				Image = STUD_BACKGROUND_IMAGE,
				ImageColor3 = Color3.fromRGB(61, 64, 72),
				ImageTransparency = 0.68,
				Position = UDim2.fromScale(0.035, 0.19),
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(0.93, 0.76),
				TileSize = UDim2.fromOffset(42, 42),
				ZIndex = 32,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 10) }),
				ReceiveTitle = outlinedText({
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.15, 0.045),
					Size = UDim2.fromScale(0.7, 0.105),
					Text = "You will receive",
					TextColor3 = Color3.fromRGB(113, 255, 42),
					TextScaled = true,
					TextStrokeTransparency = 1,
					ZIndex = 34,
				}),
				LuckReward = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = Color3.fromRGB(40, 113, 194),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.34, 0.165),
					Size = UDim2.fromScale(0.27, 0.22),
					ZIndex = 33,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 9) }),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.fromRGB(7, 36, 72),
						Thickness = 3,
					}),
					Icon = React.createElement("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Image = LUCK_REWARD_ICON,
						Position = UDim2.fromScale(0.5, 0.05),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.72, 0.65),
						ZIndex = 34,
					}),
					Label = outlinedText({
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Font = Enum.Font.FredokaOne,
						Position = UDim2.fromScale(0.5, 0.96),
						Size = UDim2.fromScale(0.92, 0.27),
						Text = `x{nextRewardMultiplier} Luck`,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextStrokeTransparency = 1,
						ZIndex = 34,
					}, 3),
				}),
				CashReward = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = Color3.fromRGB(82, 188, 36),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.66, 0.165),
					Size = UDim2.fromScale(0.27, 0.22),
					ZIndex = 33,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 9) }),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.fromRGB(25, 75, 9),
						Thickness = 3,
					}),
					Icon = React.createElement("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0),
						BackgroundTransparency = 1,
						Image = CASH_REWARD_ICON,
						Position = UDim2.fromScale(0.5, 0.05),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.72, 0.65),
						ZIndex = 34,
					}),
					Label = outlinedText({
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundTransparency = 1,
						Font = Enum.Font.FredokaOne,
						Position = UDim2.fromScale(0.5, 0.96),
						Size = UDim2.fromScale(0.92, 0.27),
						Text = `x{nextRewardMultiplier} Cash`,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextStrokeTransparency = 1,
						ZIndex = 34,
					}, 3),
				}),
				RequirementTitle = outlinedText({
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.2, 0.39),
					Size = UDim2.fromScale(0.6, 0.1),
					Text = "REQUIREMENT",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 1,
					ZIndex = 34,
				}),
				RequirementBar = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					BackgroundColor3 = Color3.fromRGB(12, 24, 35),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.84, 0.13),
					ZIndex = 33,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 7) }),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.fromRGB(4, 7, 11),
						Thickness = 4,
					}),
					Progress = React.createElement("Frame", {
						BackgroundColor3 = Color3.fromRGB(95, 230, 48),
						BorderSizePixel = 0,
						Size = UDim2.fromScale(progress, 1),
						ZIndex = 33,
					}, {
						Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 7) }),
					}),
					Cash = outlinedText({
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Font = Enum.Font.FredokaOne,
						Text = `${CompactNumber.format(currency, 1)} / ${CompactNumber.format(rebirthCost, 1)}`,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextStrokeTransparency = 1,
						ZIndex = 34,
					}, 3),
				}),
				RebirthButton = React.createElement("TextButton", {
					Active = canRebirth,
					AnchorPoint = Vector2.new(0.5, 0),
					AutoButtonColor = canRebirth,
					BackgroundColor3 = if canRebirth
						then Color3.fromRGB(239, 54, 61)
						else Color3.fromRGB(133, 57, 61),
					BackgroundTransparency = if canRebirth then 0 else 0.22,
					BorderSizePixel = 0,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.5, 0.665),
					Size = UDim2.fromScale(0.68, 0.13),
					Text = "REBIRTH",
					TextColor3 = if canRebirth then Color3.new(1, 1, 1) else Color3.fromRGB(205, 205, 205),
					TextScaled = true,
					TextStrokeTransparency = 0,
					ZIndex = 34,
					[React.Event.Activated] = function()
						if not canRebirth then
							return
						end
						local plot = PlotServiceClient:getLocalPlayerPlot()
						if plot then
							UISounds.playSelect()
							plot:requestRebirth()
						end
					end,
				}, {
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 8) }),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.fromRGB(65, 29, 32),
						Thickness = 4,
					}),
					Constraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 26,
						MinTextSize = 11,
					}),
				}),
				Warning = outlinedText({
					AnchorPoint = Vector2.new(0.5, 1),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.5, 0.965),
					Size = UDim2.fromScale(0.94, 0.105),
					Text = "WARNING: REBIRTH WILL RESET CASH, SLIME MONEY, SLIME PETS, AND UPGRADES",
					TextColor3 = Color3.fromRGB(255, 69, 75),
					TextScaled = true,
					TextStrokeTransparency = 1,
					ZIndex = 34,
				}, 3),
			}),
		}),
	})
end

return RebirthRoot
