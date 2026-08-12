local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local InventorySlot = require(ReplicatedStorage.Source.Features.Inventory.UI.Components.InventorySlot)

local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"
local GRID_COLUMNS = 4
local GRID_CELL_HEIGHT_SCALE = 0.36
local GRID_ROW_PADDING_SCALE = 0.04
local GRID_VERTICAL_PADDING = 28
local DEFAULT_VIEWPORT_HEIGHT = 400

export type Item = {
	key: string?,
	name: string,
	image: string?,
	rarity: string?,
	rarityColor: Color3?,
	mutation: string?,
	mutationColor: Color3?,
	locked: boolean?,
	quantity: number?,
	onActivated: (() -> ())?,
}

export type Props = {
	OnClose: () -> (),
	Title: string?,
	Items: { Item }?,
	EmptyMessage: string?,
	SideContent: React.ReactNode?,
}

local PLACEHOLDER_ITEMS = {
	{ name = "" },
	{ name = "" },
	{ name = "" },
	{ name = "" },
	{ name = "" },
	{ name = "" },
	{ name = "" },
	{ name = "" },
}

local function InventoryWindow(props: Props)
	local viewportHeight, setViewportHeight = React.useState(DEFAULT_VIEWPORT_HEIGHT)
	local slots = {}
	local items = props.Items or PLACEHOLDER_ITEMS
	local rowCount = math.ceil(#items / GRID_COLUMNS)
	local cellHeight = math.round(viewportHeight * GRID_CELL_HEIGHT_SCALE)
	local rowPadding = math.round(viewportHeight * GRID_ROW_PADDING_SCALE)
	local canvasHeight = rowCount * cellHeight + math.max(0, rowCount - 1) * rowPadding + GRID_VERTICAL_PADDING

	for layoutOrder, item in items do
		local slotKey = item.key or tostring(layoutOrder)
		slots[`Slot-{slotKey}`] = React.createElement(InventorySlot, {
			Name = item.name,
			Image = item.image or "",
			Rarity = item.rarity,
			RarityColor = item.rarityColor,
			Mutation = item.mutation,
			MutationColor = item.mutationColor,
			Locked = item.locked,
			Quantity = item.quantity,
			LayoutOrder = layoutOrder,
			OnActivated = item.onActivated,
		})
	end

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(4, 6, 13),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		Window = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(35, 38, 44),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.59, 0.79),
			ZIndex = 21,
		}, {
			SideContent = props.SideContent,
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1.28,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(900, 700),
				MinSize = Vector2.new(390, 360),
			}),
			Stroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(11, 12, 15),
				Thickness = 5,
			}),
			Header = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(72, 205, 239),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 0.16, 0),
				ZIndex = 23,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 11),
				}),
				Stroke = React.createElement("UIStroke", {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					Color = Color3.fromRGB(15, 25, 31),
					Thickness = 4,
				}),
				StudTexture = React.createElement("ImageLabel", {
					BackgroundTransparency = 1,
					Image = STUD_BACKGROUND_IMAGE,
					ImageColor3 = Color3.fromRGB(115, 225, 249),
					ImageTransparency = 0.42,
					ScaleType = Enum.ScaleType.Tile,
					Size = UDim2.fromScale(1, 1),
					TileSize = UDim2.fromOffset(38, 38),
					ZIndex = 23,
				}),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.035, 0.5),
					Size = UDim2.fromScale(0.66, 0.7),
					Text = props.Title or "INVENTORY",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeColor3 = Color3.new(0, 0, 0),
					TextStrokeTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 24,
				}, {
					Constraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 52,
						MinTextSize = 22,
					}),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.new(0, 0, 0),
						LineJoinMode = Enum.LineJoinMode.Round,
						Thickness = 5,
					}),
				}),
				Close = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					AutoButtonColor = true,
					BackgroundColor3 = Color3.fromRGB(222, 42, 45),
					BorderSizePixel = 0,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.965, 0.5),
					Size = UDim2.fromScale(0.11, 0.68),
					Text = "X",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeColor3 = Color3.new(0, 0, 0),
					TextStrokeTransparency = 0,
					ZIndex = 25,
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
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Color = Color3.fromRGB(95, 9, 12),
						Thickness = 4,
					}),
				}),
			}),
			ContentBackground = React.createElement("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(27, 29, 34),
				BorderSizePixel = 0,
				Image = STUD_BACKGROUND_IMAGE,
				ImageColor3 = Color3.fromRGB(62, 65, 72),
				ImageTransparency = 0.58,
				Position = UDim2.fromScale(0.035, 0.2),
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(0.93, 0.75),
				TileSize = UDim2.fromOffset(42, 42),
				ZIndex = 22,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 9),
				}),
			}),
			CategoryHeader = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.075, 0.215),
				Size = UDim2.fromScale(0.85, 0.085),
				ZIndex = 24,
			}, {
				LeftLine = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(125, 128, 135),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.new(0.37, 0, 0, 3),
					ZIndex = 24,
				}),
				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.22, 0.9),
					Text = "Slimes",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeColor3 = Color3.new(0, 0, 0),
					TextStrokeTransparency = 0,
					ZIndex = 25,
				}, {
					Constraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 30,
						MinTextSize = 16,
					}),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.new(0, 0, 0),
						LineJoinMode = Enum.LineJoinMode.Round,
						Thickness = 2,
					}),
				}),
				RightLine = React.createElement("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(125, 128, 135),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.new(0.37, 0, 0, 3),
					ZIndex = 24,
				}),
			}),
			Content = React.createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.None,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, canvasHeight),
				Position = UDim2.fromScale(0.035, 0.3),
				ScrollBarImageColor3 = Color3.fromRGB(110, 114, 123),
				ScrollBarThickness = 7,
				Size = UDim2.fromScale(0.93, 0.65),
				ZIndex = 23,
				[React.Change.AbsoluteSize] = function(scrollingFrame)
					local nextViewportHeight = math.round(scrollingFrame.AbsoluteSize.Y)
					if nextViewportHeight > 0 then
						setViewportHeight(nextViewportHeight)
					end
				end,
			}, {
				Corner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 9),
				}),
				Grid = React.createElement("UIGridLayout", {
					CellPadding = UDim2.new(0.025, 0, 0, rowPadding),
					CellSize = UDim2.new(0.22, 0, 0, cellHeight),
					FillDirectionMaxCells = GRID_COLUMNS,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Padding = React.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 14),
					PaddingLeft = UDim.new(0, 14),
					PaddingRight = UDim.new(0, 14),
					PaddingTop = UDim.new(0, 14),
				}),
			}, slots),
			EmptyState = #items == 0 and props.EmptyMessage and React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Position = UDim2.fromScale(0.5, 0.62),
				Size = UDim2.fromScale(0.72, 0.12),
				Text = props.EmptyMessage,
				TextColor3 = Color3.fromRGB(210, 213, 220),
				TextScaled = true,
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0,
				ZIndex = 25,
			}, {
				Constraint = React.createElement("UITextSizeConstraint", {
					MaxTextSize = 28,
					MinTextSize = 14,
				}),
				Stroke = React.createElement("UIStroke", {
					Color = Color3.new(0, 0, 0),
					LineJoinMode = Enum.LineJoinMode.Round,
					Thickness = 2,
				}),
			}),
		}),
	})
end

return InventoryWindow
