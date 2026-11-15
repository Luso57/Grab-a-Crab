--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)

local create = Vide.create
local SellDialogue = {}
local ROW_HEIGHT = 48
local HIDDEN_ROW_POSITION = UDim2.fromOffset(0, -ROW_HEIGHT)
local SHOWN_ROW_POSITION = UDim2.fromOffset(0, 0)

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
	local hoverScale = create "UIScale" { Scale = 1 } :: UIScale
	local hoverTween: Tween? = nil
	local function setHoverScale(scale: number)
		if hoverTween then hoverTween:Cancel() end
		hoverTween = TweenService:Create(hoverScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = scale })
		hoverTween:Play()
	end
	return create "TextButton" {
		Name = name,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		ClipsDescendants = true,
		Visible = visible,
		Text = "",
		Activated = onClick,
		MouseEnter = function() setHoverScale(1.045) end,
		MouseLeave = function() setHoverScale(1) end,
		hoverScale,
		create "Frame" {
			Name = "Content",
			Position = SHOWN_ROW_POSITION,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			strip(),
			create "TextLabel" {
			Name = "Number",
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0, 42, 1, 0),
			BackgroundTransparency = 1,
			Text = number,
			TextColor3 = Color3.fromRGB(255, 173, 55),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			ZIndex = 2,
			create "UITextSizeConstraint" { MaxTextSize = 28 },
		},
		create "TextLabel" {
			Name = "Choice",
			Position = UDim2.fromOffset(58, 0),
			Size = UDim2.new(1, -70, 1, 0),
			BackgroundTransparency = 1,
			Text = title,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBlack,
			ZIndex = 2,
			create "UITextSizeConstraint" { MaxTextSize = 23 },
		},
		},
	} :: TextButton
end

function SellDialogue.create(props: Props): ScreenGui
	local inQuote = function(): boolean
		return props.category() ~= ""
	end
	local mainOptions = {
		option("SellEggs", "1.", "[Sell All Eggs]", 1, function() return not inQuote() end, function() props.onCategory("Eggs") end),
		option("SellCrabs", "2.", "[Sell All Crabs]", 2, function() return not inQuote() end, function() props.onCategory("Crabs") end),
		option("SellEquipment", "3.", "[Sell Tanks / Incubators]", 3, function() return not inQuote() end, function() props.onCategory("Equipment") end),
		option("Exit", "4.", "[Exit]", 4, function() return not inQuote() end, props.onExit),
	}

	local screen = create "ScreenGui" {
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
				return UDim2.fromOffset(props.greetingWidth(), 44)
			end,
			BackgroundTransparency = 1,
			Text = props.greetingText,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			Font = Enum.Font.GothamBlack,
			create "UITextSizeConstraint" { MaxTextSize = 27 },
		},
		create "Frame" {
			Name = "Options",
			Position = props.menuPosition,
			Size = function()
				return UDim2.fromOffset(props.menuWidth(), 250)
			end,
			BackgroundTransparency = 1,
			create "UIListLayout" {
				Padding = UDim.new(0, 7),
				SortOrder = Enum.SortOrder.LayoutOrder,
			},
			mainOptions[1],
			mainOptions[2],
			mainOptions[3],
			mainOptions[4],
			create "Frame" {
				Name = "Summary",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 70),
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
					create "UITextSizeConstraint" { MaxTextSize = 22 },
				},
			},
			option("Confirm", "1.", "[Confirm Sale]", 2, function() return inQuote() and not props.pending() end, props.onConfirm),
			option("Back", "2.", "[Back]", 3, inQuote, props.onBack),
			create "TextLabel" {
				Name = "Feedback",
				LayoutOrder = 5,
				Size = UDim2.new(1, 0, 0, 38),
				BackgroundTransparency = 1,
				Visible = function() return props.message() ~= "" end,
				Text = props.message,
				TextColor3 = Color3.fromRGB(255, 225, 135),
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0,
				TextScaled = true,
				TextWrapped = true,
				Font = Enum.Font.GothamBlack,
				create "UITextSizeConstraint" { MaxTextSize = 20 },
			},
		} :: Frame,
	} :: ScreenGui
	local animationVersion = 0
	local rowTweens: { Tween } = {}
	Vide.effect(function()
		local shouldOpen = props.isOpen()
		animationVersion += 1
		local version = animationVersion
		for _, tween in rowTweens do tween:Cancel() end
		table.clear(rowTweens)
		for index, button in mainOptions do
			local content = button:FindFirstChild("Content") :: Frame
			content.Position = HIDDEN_ROW_POSITION
			if shouldOpen then
				task.delay((index - 1) * 0.09, function()
					if animationVersion ~= version or not props.isOpen() then return end
					local tween = TweenService:Create(content, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = SHOWN_ROW_POSITION })
					table.insert(rowTweens, tween)
					tween:Play()
				end)
			end
		end
	end)
	return screen
end

return SellDialogue
