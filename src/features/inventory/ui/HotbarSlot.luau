--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

export type Props = {
	index: number,
	displayName: string,
	image: string,
	cardImage: string?,
	weightText: string?,
	weightAtTopRight: boolean?,
	countText: string?,
	selected: boolean,
	onActivated: () -> (),
	onPointerDown: ((InputObject, ImageButton) -> ())?,
	showNumber: boolean?,
	topText: string?,
	bottomText: string?,
	size: number?,
}

local function textLabel(name: string, value: string, position: UDim2, size: UDim2, maxTextSize: number, alignment: Enum.TextXAlignment): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Text = value
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.BuilderSansExtraBold
	label.TextScaled = true
	label.TextXAlignment = alignment
	label.ZIndex = 3

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxTextSize
	constraint.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = label

	return label
end

local HotbarSlot = {}

function HotbarSlot.setTextStroke(button: ImageButton, thin: boolean)
	for _, descendant in button:GetDescendants() do
		if descendant:IsA("TextLabel") then
			descendant.TextStrokeTransparency = if thin then 0.5 else 0
			local stroke = descendant:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Thickness = if thin then 1 else 2
			end
		end
	end
end

function HotbarSlot.create(props: Props): ImageButton
	local button = Instance.new("ImageButton")
	button.Name = `Slot_{props.index}`
	button.Size = UDim2.fromOffset(props.size or 80, props.size or 80)
	button.BackgroundTransparency = 1
	button.Image = props.cardImage or `rbxassetid://{assets.InventoryCard}`
	button.ScaleType = Enum.ScaleType.Fit
	button.AutoButtonColor = false
	button.LayoutOrder = props.index
	button.ZIndex = 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button

	local selectedStroke = Instance.new("UIStroke")
	selectedStroke.Name = "SelectedStroke"
	selectedStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	selectedStroke.Color = Color3.fromRGB(255, 215, 68)
	selectedStroke.Thickness = 2
	selectedStroke.Transparency = if props.selected then 0 else 1
	selectedStroke.Parent = button

	local image = Instance.new("ImageLabel")
	image.Name = "ItemImage"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.45)
	image.Size = UDim2.fromScale(0.72, 0.7)
	image.BackgroundTransparency = 1
	image.Image = props.image
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = 2
	image.Parent = button

	if props.showNumber ~= false then
		local number = textLabel("SlotNumber", tostring(props.index), UDim2.fromScale(0.08, 0.02), UDim2.fromScale(0.28, 0.28), 20, Enum.TextXAlignment.Left)
		number.Parent = button
	end
	if props.topText then
		local top = textLabel("TopText", props.topText, UDim2.fromScale(0.06, 0.02), UDim2.fromScale(0.88, 0.24), 17, Enum.TextXAlignment.Center)
		top.TextTruncate = Enum.TextTruncate.AtEnd
		top.Parent = button
	end

	local title = textLabel("ItemName", props.bottomText or props.displayName, UDim2.fromScale(0.07, 0.73), UDim2.fromScale(0.86, 0.24), 18, Enum.TextXAlignment.Right)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = button

	if props.weightText then
		local topRight = props.weightAtTopRight == true
		local position = if topRight then UDim2.fromScale(0.39, 0.02) else UDim2.fromScale(0.07, 0.73)
		local size = if topRight then UDim2.fromScale(0.54, 0.28) else UDim2.fromScale(0.62, 0.24)
		local alignment = if topRight then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		local weight = textLabel("CrabWeight", props.weightText, position, size, 14, alignment)
		weight.Parent = button
	end
	if props.countText then
		local count = textLabel("StackCount", props.countText, UDim2.fromScale(0.45, 0.02), UDim2.fromScale(0.48, 0.28), 14, Enum.TextXAlignment.Right)
		count.Parent = button
	end

	if props.onPointerDown then
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				props.onPointerDown(input, button)
			end
		end)
	end
	button.Activated:Connect(props.onActivated)
	return button
end

return HotbarSlot
