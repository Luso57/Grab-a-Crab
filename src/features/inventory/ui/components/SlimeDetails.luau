local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)

export type Props = {
	Name: string,
	Image: string,
	Rarity: string,
	RarityColor: Color3,
	Level: number,
	Production: number,
	NextProduction: number,
	UpgradeCost: number,
	SellValue: number,
	CanAfford: boolean,
	OnClose: () -> (),
	OnUpgrade: () -> (),
	OnSell: () -> (),
}

local function createStroke(color: Color3, thickness: number)
	return React.createElement("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = color,
		Thickness = thickness,
	})
end

local function createButton(text: string, color: Color3, enabled: boolean, layoutOrder: number, onActivated: () -> ())
	return React.createElement("TextButton", {
		AutoButtonColor = enabled,
		BackgroundColor3 = color,
		BackgroundTransparency = if enabled then 0 else 0.45,
		BorderSizePixel = 0,
		Font = Enum.Font.FredokaOne,
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(0.9, 0.115),
		Text = text,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		[React.Event.Activated] = function()
			if enabled then
				UISounds.playSelect()
				onActivated()
			end
		end,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 9) }),
		Stroke = createStroke(Color3.fromRGB(8, 9, 12), 3),
		TextConstraint = React.createElement("UITextSizeConstraint", {
			MaxTextSize = 24,
			MinTextSize = 12,
		}),
	})
end

local function SlimeDetails(props: Props)
	local isDebounced, setDebounced = React.useState(false)

	local function runDebounced(callback: () -> ())
		if isDebounced then
			return
		end
		setDebounced(true)
		callback()
		task.delay(0.3, function()
			setDebounced(false)
		end)
	end

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(4, 6, 13),
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 40,
	}, {
		Panel = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(29, 32, 38),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.52),
			Size = UDim2.fromScale(0.31, 0.72),
			ZIndex = 41,
		}, {
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 0.78,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(430, 550),
				MinSize = Vector2.new(275, 390),
			}),
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			Stroke = createStroke(props.RarityColor, 4),
			Gradient = React.createElement("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(48, 51, 59), Color3.fromRGB(22, 24, 29)),
				Rotation = 90,
			}),
			Close = React.createElement("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(222, 42, 45),
				BorderSizePixel = 0,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0.965, 0.025),
				Size = UDim2.fromScale(0.1, 0.078),
				Text = "X",
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				ZIndex = 43,
				[React.Event.Activated] = function()
					UISounds.playSelect()
					props.OnClose()
				end,
			}, {
				AspectRatio = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 7) }),
				Stroke = createStroke(Color3.fromRGB(95, 9, 12), 3),
			}),
			Content = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.035),
				Size = UDim2.fromScale(1, 0.94),
				ZIndex = 42,
			}, {
				Layout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.012, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Name = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0.78, 0.08),
					Text = props.Name,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
				}),
				Icon = React.createElement("ImageLabel", {
					BackgroundTransparency = 1,
					Image = props.Image,
					LayoutOrder = 2,
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.82, 0.29),
				}),
				Rarity = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					LayoutOrder = 3,
					Size = UDim2.fromScale(0.82, 0.055),
					Text = props.Rarity,
					TextColor3 = props.RarityColor,
					TextScaled = true,
					TextStrokeTransparency = 0,
				}),
				Production = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					LayoutOrder = 4,
					Size = UDim2.fromScale(0.9, 0.07),
					Text = `{CompactNumber.format(props.Production, 1)} Slime/s`,
					TextColor3 = Color3.fromRGB(255, 221, 33),
					TextScaled = true,
					TextStrokeTransparency = 0,
				}),
				Level = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					LayoutOrder = 5,
					Size = UDim2.fromScale(0.9, 0.065),
					Text = `Lvl {props.Level}  >  Lvl {props.Level + 1}   ({CompactNumber.format(props.NextProduction, 1)}/s)`,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 0,
				}),
				Upgrade = createButton(
					`Upgrade  ${CompactNumber.format(props.UpgradeCost, 1)}`,
					Color3.fromRGB(255, 205, 30),
					props.CanAfford and not isDebounced,
					6,
					function()
						runDebounced(props.OnUpgrade)
					end
				),
				Sell = createButton(
					`Sell for ${CompactNumber.format(props.SellValue, 1)}`,
					Color3.fromRGB(244, 48, 67),
					not isDebounced,
					7,
					function()
						runDebounced(props.OnSell)
					end
				),
			}),
		}),
	})
end

return SlimeDetails
