--!strict

local HotbarSlot = require(script.Parent.HotbarSlot)
local Workspace = game:GetService("Workspace")

export type SlotView = {
	index: number,
	instanceId: string?,
	displayName: string,
	image: string,
	cardImage: string?,
	weightText: string?,
	count: number?,
	selected: boolean,
}

local SLOT_SIZE = 64
local SLOT_GAP = 5

local HotbarRoot = {}
local scrollFrame: ScrollingFrame? = nil
local row: Frame? = nil
local selectSlot: ((number) -> ())? = nil
local startDrag: ((string, number, InputObject, ImageButton) -> ())? = nil
local slotCount = 0
local slotSize = SLOT_SIZE
local slotGap = SLOT_GAP
local thinTextStroke = false

local function updateLayout()
	local scroll = scrollFrame
	local content = row
	if not scroll or not content then
		return
	end

	local rowWidth = if slotCount > 0 then slotCount * slotSize + (slotCount - 1) * slotGap else 0
	content.Size = UDim2.fromOffset(rowWidth, slotSize)
	for _, child in content:GetChildren() do
		if child:IsA("ImageButton") then
			child.Size = UDim2.fromOffset(slotSize, slotSize)
			HotbarSlot.setTextStroke(child, thinTextStroke)
			local visualIndex = child:GetAttribute("VisualIndex") :: number
			child.Position = UDim2.fromOffset((visualIndex - 1) * (slotSize + slotGap), 0)
		end
	end
	if rowWidth <= scroll.AbsoluteSize.X then
		content.AnchorPoint = Vector2.new(0.5, 0)
		content.Position = UDim2.fromScale(0.5, 0)
	else
		content.AnchorPoint = Vector2.new(0, 0)
		content.Position = UDim2.fromOffset(0, 0)
	end
	scroll.CanvasSize = UDim2.fromOffset(math.max(rowWidth, scroll.AbsoluteSize.X), slotSize)
	scroll.Visible = slotCount > 0
end

function HotbarRoot.mount(playerGui: PlayerGui, onSelect: (number) -> (), onDragStart: (string, number, InputObject, ImageButton) -> ()): ScreenGui
	if scrollFrame then
		local existing = scrollFrame:FindFirstAncestorOfClass("ScreenGui")
		if existing then
			return existing
		end
	end
	selectSlot = onSelect
	startDrag = onDragStart

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "InventoryHotbar"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder = 10

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Slots"
	scroll.AnchorPoint = Vector2.new(0.5, 1)
	scroll.Position = UDim2.new(0.5, 0, 1, -10)
	scroll.Size = UDim2.new(0.86, 0, 0, SLOT_SIZE)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 0
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.ScrollingEnabled = true
	scroll.Active = true
	scroll.ClipsDescendants = true
	scroll.Parent = screenGui

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MaxSize = Vector2.new(800, SLOT_SIZE)
	sizeConstraint.Parent = scroll

	local content = Instance.new("Frame")
	content.Name = "SlotRow"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromOffset(0, SLOT_SIZE)
	content.Parent = scroll

	scrollFrame = scroll
	row = content
	local viewportConnection: RBXScriptConnection? = nil
	local function layout()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 650), 0.67, 1)
		thinTextStroke = viewport.X < 900 or viewport.Y < 600
		slotSize = math.round(SLOT_SIZE * scale)
		slotGap = math.round(SLOT_GAP * scale)
		scroll.Size = UDim2.new(0.86, 0, 0, slotSize)
		sizeConstraint.MaxSize = Vector2.new(800, slotSize)
		updateLayout()
	end
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) else nil
		layout()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	screenGui.Destroying:Connect(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		scrollFrame = nil
		row = nil
	end)
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateLayout)
	screenGui.Parent = playerGui
	watchCamera()
	return screenGui
end

function HotbarRoot.render(slots: { SlotView })
	local content = row
	local onSelect = selectSlot
	local onDragStart = startDrag
	if not content or not onSelect then
		return
	end

	for _, child in content:GetChildren() do
		child:Destroy()
	end

	slotCount = #slots
	for visualIndex, slot in slots do
		local slotIndex = slot.index
		local button = HotbarSlot.create({
			index = slotIndex,
			size = slotSize,
			displayName = slot.displayName,
			image = slot.image,
			cardImage = slot.cardImage,
			weightText = slot.weightText,
			weightAtTopRight = true,
			countText = if slot.count then "x" .. tostring(slot.count) else nil,
			selected = slot.selected,
			onPointerDown = if slot.instanceId and onDragStart then function(input, card)
				onDragStart(slot.instanceId :: string, slotIndex, input, card)
			end else nil,
			onActivated = function()
				onSelect(slotIndex)
			end,
		})
		button:SetAttribute("SlotIndex", slotIndex)
		button:SetAttribute("VisualIndex", visualIndex)
		button.Position = UDim2.fromOffset((visualIndex - 1) * (slotSize + slotGap), 0)
		button.Parent = content
	end
	updateLayout()
end

function HotbarRoot.getSlotAt(position: Vector2): number?
	local content = row
	if not content then
		return nil
	end
	for _, child in content:GetChildren() do
		if child:IsA("ImageButton") then
			local topLeft = child.AbsolutePosition
			local size = child.AbsoluteSize
			if position.X >= topLeft.X and position.X <= topLeft.X + size.X and position.Y >= topLeft.Y and position.Y <= topLeft.Y + size.Y then
				return child:GetAttribute("SlotIndex") :: number?
			end
		end
	end
	return nil
end
return HotbarRoot
