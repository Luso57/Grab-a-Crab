--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)

local create = Vide.create
local SellDialogue = {}

-- The menu follows the sell stand Noob through positions supplied by the client service.

export type Props = {
	isOpen: () -> boolean,
	isOnScreen: () -> boolean,
	greetingText: () -> string,
	greetingPosition: () -> UDim2,
	greetingWidth: () -> number,
	menuPosition: () -> UDim2,
	menuWidth: () -> number,
	category: () -> string,
	count: () -> number,
	total: () -> number,
	message: () -> string,
	pending: () -> boolean,
	onCategory: (string) -> (),
	onConfirm: () -> (),
	onBack: () -> (),
	onExit: () -> (),
}

local stripGradient = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.14, 0.1),
	NumberSequenceKeypoint.new(0.86, 0.1),
	NumberSequenceKeypoint.new(1, 1),
})

local function strip(): Frame
	return create "Frame" {
		Name = "GradientStrip",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(21, 16, 12),
		BackgroundTransparency = 0.24,
		BorderSizePixel = 0,
		ZIndex = 1,
		create "UIGradient" { Transparency = stripGradient },
	} :: Frame
end

local function option(name: string, number: string, title: string, order: number, visible: any, onClick: () -> ()): TextButton
	return create "TextButton" {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Visible = visible,
		Text = "",
		Activated = onClick,
		strip(),
		create "TextLabel" {
			Name = "Number",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(0, 56, 1, 0),
			BackgroundTransparency = 1,
			Text = number,
			TextColor3 = Color3.fromRGB(255, 173, 55),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			ZIndex = 2,
			create "UITextSizeConstraint" { MaxTextSize = 36 },
		},
		create "TextLabel" {
			Name = "Choice",
			Position = UDim2.fromOffset(78, 0),
			Size = UDim2.new(1, -94, 1, 0),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBlack,
			ZIndex = 2,
			create "UITextSizeConstraint" { MaxTextSize = 30 },
		},
	} :: TextButton
end

function SellDialogue.create(props: Props): ScreenGui
	local inQuote = function(): boolean
		return props.category() ~= ""
	end

	return create "ScreenGui" {
		Name = "SellDialogue",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 32,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = function()
			return props.isOpen() and props.isOnScreen()
		end,
		create "TextLabel" {
			Name = "Greeting",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = props.greetingPosition,
			Size = function()
				return UDim2.fromOffset(props.greetingWidth(), 58)
			end,
			BackgroundTransparency = 1,
			Text = props.greetingText,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			create "UITextSizeConstraint" { MaxTextSize = 34 },
		},
		create "Frame" {
			Name = "Options",
			Position = props.menuPosition,
			Size = function()
				return UDim2.fromOffset(props.menuWidth(), 340)
			end,
			BackgroundTransparency = 1,
			create "UIListLayout" {
				Padding = UDim.new(0, 9),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			option("SellEggs", "1.", "[Sell All Eggs]", 1, function() return not inQuote() end, function() props.onCategory("Eggs") end),
			option("SellCrabs", "2.", "[Sell All Crabs]", 2, function() return not inQuote() end, function() props.onCategory("Crabs") end),
			option("SellEquipment", "3.", "[Sell Tanks / Incubators]", 3, function() return not inQuote() end, function() props.onCategory("Equipment") end),
			option("Exit", "4.", "[Exit]", 4, function() return not inQuote() end, props.onExit),
			create "Frame" {
				Name = "Summary",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 88),
				BackgroundTransparency = 1,
				Visible = inQuote,
				strip(),
				create "TextLabel" {
					Name = "SummaryText",
					Position = UDim2.fromOffset(32, 0),
					Size = UDim2.new(1, -64, 1, 0),
					BackgroundTransparency = 1,
					Text = function()
						return `Sell ALL {props.count()} eligible {string.lower(props.category())} for ${CompactNumber.format(props.total())}?`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextStrokeColor3 = Color3.new(0, 0, 0),
					TextStrokeTransparency = 0,
					TextScaled = true,
					TextWrapped = true,
					Font = Enum.Font.GothamBlack,
					ZIndex = 2,
					create "UITextSizeConstraint" { MaxTextSize = 27 },
				},
			},
			option("Confirm", "1.", "[Confirm Sale]", 2, function() return inQuote() and not props.pending() end, props.onConfirm),
			option("Back", "2.", "[Back]", 3, inQuote, props.onBack),
			create "TextLabel" {
				Name = "Feedback",
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 48),
				BackgroundTransparency = 1,
				Visible = function() return props.message() ~= "" end,
				Text = props.message,
				TextColor3 = Color3.fromRGB(255, 225, 135),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0,
				TextScaled = true,
				TextWrapped = true,
				Font = Enum.Font.GothamBlack,
				create "UITextSizeConstraint" { MaxTextSize = 24 },
			},
		} :: Frame,
	} :: ScreenGui
end

return SellDialogue
