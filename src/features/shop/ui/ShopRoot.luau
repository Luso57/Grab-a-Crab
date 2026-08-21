local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local PassCatalog = require(ReplicatedStorage.Source.Features.Monetization.Modules.PassCatalog)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local PassCard = require(ReplicatedStorage.Source.Features.Shop.UI.Components.PassCard)

local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"
local SHOP_ICON = "rbxthumb://type=Asset&id=14736132203&w=420&h=420"
local CARD_COLORS = {
	Color3.fromRGB(242, 91, 230),
	Color3.fromRGB(109, 226, 239),
	Color3.fromRGB(104, 237, 77),
	Color3.fromRGB(255, 180, 70),
	Color3.fromRGB(109, 193, 242),
	Color3.fromRGB(247, 231, 82),
	Color3.fromRGB(190, 112, 240),
}

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

local function ShopRoot(props: Props)
	local cards = {
		Grid = React.createElement("UIGridLayout", {
			CellPadding = UDim2.fromOffset(14, 14),
			CellSize = UDim2.new(0.5, -7, 0, 190),
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = React.createElement("UIPadding", {
			PaddingBottom = UDim.new(0, 12),
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 12),
		}),
	}

	for index, entry in PassCatalog do
		cards[`Pass{index}`] = React.createElement(PassCard, {
			Entry = entry,
			LayoutOrder = index,
			Color = CARD_COLORS[index],
		})
	end

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
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),
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
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 11),
				}),
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
					Image = SHOP_ICON,
					Position = UDim2.fromScale(0.025, 0.5),
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.115, 0.86),
					ZIndex = 34,
				}),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.145, 0.5),
					Size = UDim2.fromScale(0.56, 0.68),
					Text = "SHOP",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeTransparency = 1,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 34,
				}, {
					Stroke = React.createElement("UIStroke", {
						Color = Color3.new(0, 0, 0),
						LineJoinMode = Enum.LineJoinMode.Round,
						Thickness = 5,
					}),
				}),
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
					AspectRatio = React.createElement("UIAspectRatioConstraint", {
						AspectRatio = 1,
					}),
					Corner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, 7),
					}),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.fromRGB(95, 9, 12),
						Thickness = 4,
					}),
				}),
			}),
			Content = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(27, 29, 34),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.035, 0.19),
				Size = UDim2.fromScale(0.93, 0.76),
				ZIndex = 32,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 10),
				}),
				Cards = React.createElement("ScrollingFrame", {
					Active = true,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					CanvasSize = UDim2.fromOffset(0, 0),
					ClipsDescendants = true,
					ScrollBarImageColor3 = Color3.fromRGB(239, 54, 61),
					ScrollBarThickness = 8,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					Size = UDim2.fromScale(1, 1),
					VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
					ZIndex = 33,
				}, cards),
			}),
		}),
	})
end

return ShopRoot
