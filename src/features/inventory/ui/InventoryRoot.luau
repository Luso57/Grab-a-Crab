--!strict

local HotbarSlot = require(script.Parent.HotbarSlot)
local InventoryConfig = require(script.Parent.Parent.InventoryConfig)
local Workspace = game:GetService("Workspace")

export type EntryView = {
	instanceId: string,
	itemId: string,
	displayName: string,
	image: string,
	cardImage: string?,
	weightText: string?,
	count: number,
}

local InventoryRoot = {}
local panel: Frame? = nil
local toggleButton: TextButton? = nil
local list: ScrollingFrame? = nil
local searchBox: TextBox? = nil
local capacityLabel: TextLabel? = nil
local onSelect: ((string) -> ())? = nil
local startDrag: ((string, InputObject, ImageButton) -> ())? = nil
local onPanelClosed: (() -> ())? = nil
local toggleSound: Sound? = nil
local currentEntries: { EntryView } = {}
local currentSelectedId: string? = nil
local currentUsedCount = 0
local currentCapacity = InventoryConfig.maxItems

local function addStroke(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function setOpen(open: boolean)
	if panel then
		if panel.Visible == open then
			return
		end
		local sound = toggleSound
		if sound then
			sound.TimePosition = 0
			sound:Play()
		end
		panel.Visible = open
		if toggleButton then
			toggleButton.Visible = not open
		end
		if not open and onPanelClosed then
			onPanelClosed()
		end
	end
end

function InventoryRoot.mount(playerGui: PlayerGui, onItemSelected: (string) -> (), onClosed: () -> (), onDragStart: (string, InputObject, ImageButton) -> ())
	if panel and panel.Parent then
		return
	end
	onSelect = onItemSelected
	startDrag = onDragStart
	onPanelClosed = onClosed

	local screen = Instance.new("ScreenGui")
	screen.Name = "InventoryPanel"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 40
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local toggleScreen = Instance.new("ScreenGui")
	toggleScreen.Name = "InventoryToggleGui"
	toggleScreen.ResetOnSpawn = false
	toggleScreen.IgnoreGuiInset = true
	toggleScreen.DisplayOrder = 9
	toggleScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local sound = Instance.new("Sound")
	sound.Name = "BackpackToggleSound"
	sound.SoundId = "rbxassetid://132948338000932"
	sound.Volume = 1
	sound.Parent = screen
	toggleSound = sound

	local toggle = Instance.new("TextButton")
	toggle.Name = "InventoryToggle"
	toggleButton = toggle
	toggle.AnchorPoint = Vector2.new(0.5, 1)
	toggle.Position = UDim2.new(0.5, 0, 1, -87)
	toggle.Size = UDim2.fromOffset(190, 50)
	toggle.BackgroundColor3 = Color3.fromRGB(85, 85, 85)
	toggle.BackgroundTransparency = 0.5
	toggle.BorderSizePixel = 0
	toggle.Font = Enum.Font.BuilderSansExtraBold
	toggle.Text = "Open Backpack"
	toggle.TextColor3 = Color3.new(1, 1, 1)
	toggle.TextScaled = true
	toggle.TextStrokeColor3 = Color3.new(0, 0, 0)
	toggle.TextStrokeTransparency = 0
	toggle.Parent = toggleScreen
	addStroke(toggle, 3)

	local toggleTextSize = Instance.new("UITextSizeConstraint")
	toggleTextSize.MaxTextSize = 23
	toggleTextSize.Parent = toggle

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.59)
	frame.Size = UDim2.fromScale(0.58, 0.42)
	frame.BackgroundColor3 = Color3.fromRGB(22, 27, 25)
	frame.BackgroundTransparency = 0.17
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen
	panel = frame
	addStroke(frame, 4)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(1100, 600)
	limit.Parent = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0.02, 0, 0, 10)
	title.Size = UDim2.new(0.4, 0, 0, 48)
	title.Font = Enum.Font.BuilderSansExtraBold
	title.Text = "Backpack"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextStrokeTransparency = 0
	title.Parent = frame
	local titleLimit = Instance.new("UITextSizeConstraint")
	titleLimit.MaxTextSize = 44
	titleLimit.Parent = title

	local capacity = Instance.new("TextLabel")
	capacity.Name = "Capacity"
	capacity.BackgroundTransparency = 1
	capacity.Position = UDim2.fromOffset(0, 17)
	capacity.Size = UDim2.fromOffset(100, 42)
	capacity.Font = Enum.Font.BuilderSansBold
	capacity.Text = `0/{InventoryConfig.maxItems}`
	capacity.TextColor3 = Color3.fromRGB(205, 255, 205)
	capacity.TextScaled = true
	capacity.TextXAlignment = Enum.TextXAlignment.Left
	capacity.TextStrokeColor3 = Color3.new(0, 0, 0)
	capacity.TextStrokeTransparency = 0
	capacity.Parent = frame
	capacityLabel = capacity
	local capacityLimit = Instance.new("UITextSizeConstraint")
	capacityLimit.MaxTextSize = 28
	capacityLimit.Parent = capacity
	local compactLayout = false
	local portraitLayout = false
	local function positionCapacity()
		if compactLayout then
			capacity.Position = UDim2.fromOffset(12, if portraitLayout then 36 else 31)
			return
		end
		local titleLeft = title.Position.X.Scale * frame.AbsoluteSize.X + title.Position.X.Offset
		capacity.Position = UDim2.fromOffset(math.ceil(titleLeft + title.TextBounds.X + 14), 17)
	end
	title:GetPropertyChangedSignal("TextBounds"):Connect(positionCapacity)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(positionCapacity)
	positionCapacity()

	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.AnchorPoint = Vector2.new(1, 0)
	search.Position = UDim2.new(0.9, 0, 0, 17)
	search.Size = UDim2.new(0.29, 0, 0, 42)
	search.BackgroundColor3 = Color3.fromRGB(220, 225, 225)
	search.BackgroundTransparency = 0.68
	search.BorderSizePixel = 0
	search.ClearTextOnFocus = false
	search.Font = Enum.Font.BuilderSansBold
	search.PlaceholderText = "Search"
	search.PlaceholderColor3 = Color3.fromRGB(225, 230, 225)
	search.Text = ""
	search.TextColor3 = Color3.new(1, 1, 1)
	search.TextSize = 25
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.Parent = frame
	searchBox = search
	local searchCorner = Instance.new("UICorner")
	searchCorner.CornerRadius = UDim.new(0, 7)
	searchCorner.Parent = search
	local searchPadding = Instance.new("UIPadding")
	searchPadding.PaddingLeft = UDim.new(0, 10)
	searchPadding.Parent = search

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(0.98, 0, 0, 10)
	close.Size = UDim2.fromOffset(50, 50)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.BuilderSansExtraBold
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.TextScaled = true
	close.TextStrokeColor3 = Color3.new(0, 0, 0)
	close.TextStrokeTransparency = 0
	close.Parent = frame
	local closeLimit = Instance.new("UITextSizeConstraint")
	closeLimit.MaxTextSize = 45
	closeLimit.Parent = close
	close.Activated:Connect(function()
		setOpen(false)
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.Position = UDim2.fromOffset(22, 98)
	scroll.Size = UDim2.new(1, -44, 1, -116)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Parent = frame
	list = scroll

	local grid = Instance.new("UIGridLayout")
	grid.Name = "CardGrid"
	grid.CellSize = UDim2.fromOffset(80, 80)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	local function layout()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 650), 0.67, 1)
		compactLayout = math.min(viewport.X, viewport.Y) < 600
		portraitLayout = viewport.Y > viewport.X
		toggle.Size = UDim2.fromOffset(math.round(190 * scale), math.round(50 * scale))
		toggle.Position = UDim2.new(0.5, 0, 1, -math.round(87 * scale))
		toggleTextSize.MaxTextSize = math.round(23 * scale)
		if compactLayout then
			local width = math.min(viewport.X * (if portraitLayout then 0.86 else 0.68), 620)
			local height = math.min(viewport.Y * (if portraitLayout then 0.6 else 0.58), 460)
			frame.Position = UDim2.fromScale(0.5, 0.5)
			frame.Size = UDim2.fromOffset(width, height)
			title.Position = UDim2.fromOffset(12, 6)
			title.Size = UDim2.fromOffset(width - (if portraitLayout then 60 else 190), 28)
			titleLimit.MaxTextSize = 25
			capacity.Size = UDim2.fromOffset(width - 24, 20)
			capacityLimit.MaxTextSize = 17
			search.AnchorPoint = Vector2.new(0, 0)
			search.Position = UDim2.fromOffset(if portraitLayout then 12 else width - 174, if portraitLayout then 63 else 11)
			search.Size = UDim2.fromOffset(if portraitLayout then width - 24 else 126, 30)
			search.TextSize = 16
			close.Position = UDim2.fromOffset(width - 10, 5)
			close.Size = UDim2.fromOffset(34, 34)
			closeLimit.MaxTextSize = 29
			local listTop = if portraitLayout then 103 else 58
			scroll.Position = UDim2.fromOffset(12, listTop)
			scroll.Size = UDim2.fromOffset(width - 24, height - listTop - 12)
			grid.CellSize = UDim2.fromOffset(60, 60)
			grid.CellPadding = UDim2.fromOffset(5, 5)
		else
			frame.Position = UDim2.fromScale(0.5, 0.59)
			frame.Size = UDim2.fromScale(0.58, 0.42)
			title.Position = UDim2.new(0.02, 0, 0, 10)
			title.Size = UDim2.new(0.4, 0, 0, 48)
			titleLimit.MaxTextSize = 44
			capacity.Size = UDim2.fromOffset(100, 42)
			capacityLimit.MaxTextSize = 28
			search.AnchorPoint = Vector2.new(1, 0)
			search.Position = UDim2.new(0.9, 0, 0, 17)
			search.Size = UDim2.new(0.29, 0, 0, 42)
			search.TextSize = 25
			close.Position = UDim2.new(0.98, 0, 0, 10)
			close.Size = UDim2.fromOffset(50, 50)
			closeLimit.MaxTextSize = 45
			scroll.Position = UDim2.fromOffset(22, 98)
			scroll.Size = UDim2.new(1, -44, 1, -116)
			grid.CellSize = UDim2.fromOffset(80, 80)
			grid.CellPadding = UDim2.fromOffset(8, 8)
		end
		positionCapacity()
	end

	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) else nil
		layout()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	screen.Destroying:Connect(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		toggleScreen:Destroy()
	end)

	toggle.Activated:Connect(function()
		setOpen(not frame.Visible)
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		InventoryRoot.render(currentEntries, currentSelectedId, currentUsedCount, currentCapacity)
	end)
	screen.Parent = playerGui
	toggleScreen.Parent = playerGui
	watchCamera()
end

function InventoryRoot.toggle()
	if panel then
		setOpen(not panel.Visible)
	end
end

function InventoryRoot.render(entries: { EntryView }, selectedId: string?, usedCount: number, capacity: number)
	currentEntries = entries
	currentSelectedId = selectedId
	currentUsedCount = usedCount
	currentCapacity = capacity
	if capacityLabel then
		capacityLabel.Text = `{usedCount}/{capacity}`
	end
	local scroll = list
	local selectItem = onSelect
	if not scroll or not selectItem then
		return
	end

	for _, child in scroll:GetChildren() do
		if child:IsA("GuiButton") or child.Name == "Empty" then
			child:Destroy()
		end
	end

	local query = if searchBox then string.lower(string.gsub(searchBox.Text, "^%s*(.-)%s*$", "%1")) else ""
	local shown = 0
	for _, entry in entries do
		if query == "" or string.find(string.lower(entry.displayName), query, 1, true) or string.find(string.lower(entry.itemId), query, 1, true) then
			shown += 1
			local instanceId = entry.instanceId
			local card = HotbarSlot.create({
				index = shown,
				displayName = entry.displayName,
				image = entry.image,
				cardImage = entry.cardImage,
				weightText = entry.weightText,
				selected = selectedId == instanceId,
				showNumber = false,
				topText = entry.displayName,
				bottomText = "x" .. tostring(entry.count),
				onPointerDown = if startDrag then function(input, draggedCard)
					startDrag(instanceId, input, draggedCard)
				end else nil,
				onActivated = function()
					selectItem(instanceId)
				end,
			})
			card.Name = instanceId
			card.LayoutOrder = shown
			card.Parent = scroll
		end
	end

	if shown == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.Size = UDim2.fromOffset(250, 80)
		empty.BackgroundTransparency = 1
		empty.Font = Enum.Font.BuilderSansBold
		empty.Text = if query == "" then "No extra items" else "No matching items"
		empty.TextColor3 = Color3.fromRGB(225, 225, 225)
		empty.TextSize = 23
		empty.Parent = scroll
	end
end

function InventoryRoot.isDropPosition(position: Vector2): boolean
	local scroll = list
	if not panel or not panel.Visible or not scroll then
		return false
	end
	local topLeft = scroll.AbsolutePosition
	local size = scroll.AbsoluteSize
	return position.X >= topLeft.X and position.X <= topLeft.X + size.X
		and position.Y >= topLeft.Y and position.Y <= topLeft.Y + size.Y
end
return InventoryRoot
