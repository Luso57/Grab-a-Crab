--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Data = require(ReplicatedStorage.Source.Game.Data).client
local InventoryConfig = require(script.Parent.InventoryConfig)
local ItemCatalog = require(ReplicatedStorage.Source.Game.Items.ItemCatalog)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local Networker = require(ReplicatedStorage.Packages.Networker)
local HotbarRoot = require(script.Parent.UI.HotbarRoot)
local InventoryRoot = require(script.Parent.UI.InventoryRoot)

type SavedItem = { itemId: string, placedSlotId: string?, incubatorInstanceId: string?, tankInstanceId: string?, weightGrams: number? }
type SavedInventory = { [string]: SavedItem }
type DragState = {
	instanceId: string,
	sourceSlot: number?,
	input: InputObject,
	startPosition: Vector2,
	card: ImageButton,
	ghost: ImageButton?,
	active: boolean,
}

local InventoryServiceClient = {}
local initialized = false
local player = Players.LocalPlayer
local backpack: Backpack? = nil
local character: Model? = nil
local backpackConnections: { RBXScriptConnection } = {}
local characterConnections: { RBXScriptConnection } = {}
local selectedInventoryId: string? = nil
local sendSlotMove: ((string, number) -> ())? = nil
local sendSlotRemove: ((string) -> ())? = nil
local sendHatchClaim: ((string) -> ())? = nil
local dragState: DragState? = nil
local dragLayer: ScreenGui? = nil
local suppressedId: string? = nil
local suppressUntil = 0
local renderPending = false

local keyToIndex = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local function disconnectAll(connections: { RBXScriptConnection })
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

local function findTool(instanceId: string): Tool?
	local function findIn(container: Instance?): Tool?
		if not container then
			return nil
		end
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ItemInstanceId") == instanceId then
				return child
			end
		end
		return nil
	end
	return findIn(backpack) or findIn(character)
end

local cardImages: { [string]: number } = {
	Common = assets.CommonInventoryCard,
	Uncommon = assets.UncommonInventoryCard,
	Epic = assets.EpicInventoryCard,
	Legendary = assets.LegendaryInventoryCard,
	Mythic = assets.MythicInventoryCard,
}

local function getDisplay(itemId: string): (string, string, string?)
	local definition = ItemCatalog.get(itemId)
	if definition then
		local cardId = if definition.rarity then cardImages[definition.rarity] else nil
		return definition.shortName, `rbxassetid://{definition.imageId}`, if cardId then `rbxassetid://{cardId}` else nil
	end
	return itemId, "", nil
end

local function isHotbarEligible(itemId: string): boolean
	local definition = ItemCatalog.get(itemId)
	return definition ~= nil and definition.hotbarEligible ~= false
end

local function getWeightText(item: SavedItem): string?
	return if string.match(item.itemId, "^Crab%.[%w_]+$") then CrabWeights.format(item.weightGrams) else nil
end

local function isAvailable(item: SavedItem?): boolean
	return typeof(item) == "table" and typeof(item.itemId) == "string"
		and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil
end

local function render()
	local inventory = Data.inventory() :: SavedInventory
	local hotbar = Data.hotbar() :: { string }
	local stackIds: { [string]: { string } } = {}
	for instanceId, item in inventory do
		if isAvailable(item) and ItemCatalog.isStackable(item.itemId) then
			local ids = stackIds[item.itemId]
			if not ids then
				ids = {}
				stackIds[item.itemId] = ids
			end
			table.insert(ids, instanceId)
		end
	end
	for _, ids in stackIds do
		table.sort(ids)
	end
	local assigned: { [string]: boolean } = {}
	local assignedStackables: { [string]: boolean } = {}
	local views: { HotbarRoot.SlotView } = {}

	for index = 1, InventoryConfig.hotbarSize do
		local instanceId = hotbar[index]
		local item = if typeof(instanceId) == "string" then inventory[instanceId] else nil
		local displayName = ""
		local image = ""
		local cardImage: string? = nil
		local weightText: string? = nil
		local count: number? = nil
		local selected = false
		local hasItem = false
		if isAvailable(item) and (not stackIds[item.itemId] or not assignedStackables[item.itemId]) then
			assigned[instanceId] = true
			displayName, image, cardImage = getDisplay(item.itemId)
			weightText = getWeightText(item)
			local ids = stackIds[item.itemId]
			if ids then
				assignedStackables[item.itemId] = true
				count = #ids
			end
			local tool = findTool(instanceId)
			selected = tool ~= nil and character ~= nil and tool.Parent == character
			hasItem = true
		end
		if hasItem or selectedInventoryId ~= nil or (dragState ~= nil and dragState.active) then
			table.insert(views, {
				index = index,
				instanceId = if hasItem then instanceId else nil,
				displayName = displayName,
				image = image,
				cardImage = cardImage,
				weightText = weightText,
				count = count,
				selected = selected,
			})
		end
	end

	local extras: { InventoryRoot.EntryView } = {}
	for instanceId, item in inventory do
		if not assigned[instanceId] and isAvailable(item) and not ItemCatalog.isStackable(item.itemId) then
			local displayName, image, cardImage = getDisplay(item.itemId)
			table.insert(extras, {
				instanceId = instanceId,
				itemId = item.itemId,
				displayName = displayName,
				image = image,
				cardImage = cardImage,
				weightText = getWeightText(item),
				count = 1,
			})
		end
	end
	for itemId, ids in stackIds do
		if not assignedStackables[itemId] then
			local instanceId = if selectedInventoryId and table.find(ids, selectedInventoryId) then selectedInventoryId else ids[1]
			local displayName, image, cardImage = getDisplay(itemId)
			table.insert(extras, {
				instanceId = instanceId,
				itemId = itemId,
				displayName = displayName,
				image = image,
				cardImage = cardImage,
				count = #ids,
			})
		end
	end
	table.sort(extras, function(left, right)
		if left.displayName == right.displayName then
			if left.itemId ~= right.itemId then
				return left.itemId < right.itemId
			end
			return left.instanceId < right.instanceId
		end
		return left.displayName < right.displayName
	end)

	local selectedItem = if selectedInventoryId then inventory[selectedInventoryId] else nil
	if selectedInventoryId and (assigned[selectedInventoryId] or not isAvailable(selectedItem)
		or (ItemCatalog.isStackable(selectedItem.itemId) and assignedStackables[selectedItem.itemId])) then
		selectedInventoryId = nil
		render()
		return
	end
	HotbarRoot.render(views)
	InventoryRoot.render(extras, selectedInventoryId)
end

local function scheduleRender()
	if renderPending then
		return
	end
	renderPending = true
	task.defer(function()
		renderPending = false
		render()
	end)
end

local function bindBackpack(newBackpack: Backpack?)
	if backpack == newBackpack then
		return
	end
	disconnectAll(backpackConnections)
	backpack = newBackpack
	if backpack then
		table.insert(backpackConnections, backpack.ChildAdded:Connect(scheduleRender))
		table.insert(backpackConnections, backpack.ChildRemoved:Connect(scheduleRender))
	end
	scheduleRender()
end

local function bindCharacter(newCharacter: Model?)
	if character == newCharacter then
		return
	end
	disconnectAll(characterConnections)
	character = newCharacter
	if character then
		table.insert(characterConnections, character.ChildAdded:Connect(scheduleRender))
		table.insert(characterConnections, character.ChildRemoved:Connect(scheduleRender))
	end
	scheduleRender()
end

local function positionOf(input: InputObject): Vector2
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseMovement then
		return UserInputService:GetMouseLocation()
	end
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function beginDrag(instanceId: string, sourceSlot: number?, input: InputObject, card: ImageButton)
	local item = (Data.inventory() :: SavedInventory)[instanceId]
	if sourceSlot == InventoryConfig.hammerSlot or not item or not isHotbarEligible(item.itemId) then
		return
	end
	if dragState then
		return
	end
	dragState = {
		instanceId = instanceId,
		sourceSlot = sourceSlot,
		input = input,
		startPosition = positionOf(input),
		card = card,
		ghost = nil,
		active = false,
	}
end

local function updateDrag(input: InputObject)
	local state = dragState
	if not state then
		return
	end
	if state.input.UserInputType == Enum.UserInputType.Touch then
		if input ~= state.input then
			return
		end
	elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	local position = positionOf(input)
	if not state.active then
		if (position - state.startPosition).Magnitude < 8 then
			return
		end
		state.active = true
		selectedInventoryId = nil
		local layer = dragLayer
		if layer then
			local ghost = state.card:Clone()
			ghost.Name = "DraggedItem"
			ghost.AnchorPoint = Vector2.new(0.5, 0.5)
			ghost.Position = UDim2.fromOffset(position.X, position.Y)
			ghost.Active = false
			ghost.Selectable = false
			ghost.ZIndex = 100
			ghost.Parent = layer
			state.ghost = ghost
		end
		render()
	end
	if state.ghost then
		state.ghost.Position = UDim2.fromOffset(position.X, position.Y)
	end
end

local function finishDrag(input: InputObject)
	local state = dragState
	if not state then
		return
	end
	if state.input.UserInputType == Enum.UserInputType.Touch then
		if input ~= state.input then
			return
		end
	elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	dragState = nil
	if not state.active then
		return
	end

	suppressedId = state.instanceId
	suppressUntil = os.clock() + 0.2
	-- GuiObject.AbsolutePosition and InputObject.Position use the same inset-adjusted
	-- coordinates. GetMouseLocation is for positioning the drag ghost on its ScreenGui.
	local position = Vector2.new(input.Position.X, input.Position.Y)
	local targetSlot = HotbarRoot.getSlotAt(position)
	if targetSlot and targetSlot ~= InventoryConfig.hammerSlot and targetSlot ~= state.sourceSlot then
		local move = sendSlotMove
		if move then
			move(state.instanceId, targetSlot)
		end
	elseif state.sourceSlot and InventoryRoot.isDropPosition(position) then
		local remove = sendSlotRemove
		if remove then
			remove(state.instanceId)
		end
	end
	if state.ghost then
		state.ghost:Destroy()
	end
	scheduleRender()
end

local function suppressClick(instanceId: string): boolean
	return suppressedId == instanceId and os.clock() < suppressUntil
end
local function selectSlot(index: number)
	if selectedInventoryId and index ~= InventoryConfig.hammerSlot then
		local move = sendSlotMove
		if move then
			move(selectedInventoryId, index)
		end
		selectedInventoryId = nil
		scheduleRender()
		return
	end

	local hotbar = Data.hotbar() :: { string }
	local instanceId = hotbar[index]
	if typeof(instanceId) ~= "string" or instanceId == InventoryConfig.emptySlot then
		return
	end
	if suppressClick(instanceId) then
		return
	end
	local tool = findTool(instanceId)
	local currentCharacter = player.Character
	local humanoid = if currentCharacter then currentCharacter:FindFirstChildOfClass("Humanoid") else nil
	if not tool or not currentCharacter or not humanoid or humanoid.Health <= 0 then
		return
	end
	if tool.Parent == currentCharacter then
		humanoid:UnequipTools()
	elseif tool.Parent == backpack then
		humanoid:EquipTool(tool)
	end
end

function InventoryServiceClient:equipHatchedCrab(instanceId: string)
	if sendHatchClaim then
		sendHatchClaim(instanceId)
	end
	local hatchCharacter = player.Character
	if not hatchCharacter then
		return
	end
	task.spawn(function()
		local deadline = os.clock() + 3
		repeat
			if player.Character ~= hatchCharacter then
				return
			end
			local item = (Data.inventory() :: SavedInventory)[instanceId]
			local hotbar = Data.hotbar() :: { string }
			if item and string.match(item.itemId, "^Crab%.[%w_]+$")
				and table.find(hotbar, instanceId) then
				local tool = findTool(instanceId)
				local humanoid = hatchCharacter:FindFirstChildOfClass("Humanoid")
				if tool and humanoid and humanoid.Health > 0 then
					if tool.Parent == backpack then
						humanoid:EquipTool(tool)
					end
					return
				end
			end
			task.wait(0.05)
		until os.clock() >= deadline
	end)
end

function InventoryServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local networker = Networker.client.new("InventoryService", self)
	sendSlotMove = function(instanceId, slotIndex)
		networker:fire("setHotbarSlot", instanceId, slotIndex)
	end
	sendSlotRemove = function(instanceId)
		networker:fire("removeHotbarSlot", instanceId)
	end
	sendHatchClaim = function(instanceId)
		networker:fire("claimHatchedCrab", instanceId)
	end

	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local dragGui = Instance.new("ScreenGui")
	dragGui.Name = "InventoryDragLayer"
	dragGui.ResetOnSpawn = false
	dragGui.IgnoreGuiInset = true
	dragGui.DisplayOrder = 100
	dragGui.Parent = playerGui
	dragLayer = dragGui
	HotbarRoot.mount(playerGui, selectSlot, function(instanceId, slotIndex, input, card)
		beginDrag(instanceId, slotIndex, input, card)
	end)
	InventoryRoot.mount(playerGui, function(instanceId)
		if suppressClick(instanceId) then
			return
		end
		local item = (Data.inventory() :: SavedInventory)[instanceId]
		if not item or not isHotbarEligible(item.itemId) then
			return
		end
		selectedInventoryId = if selectedInventoryId == instanceId then nil else instanceId
		scheduleRender()
	end, function()
		selectedInventoryId = nil
		scheduleRender()
	end, function(instanceId, input, card)
		beginDrag(instanceId, nil, input, card)
	end)

	bindBackpack(player:FindFirstChildOfClass("Backpack") :: Backpack?)
	bindCharacter(player.Character)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			bindBackpack(child)
		end
	end)
	player.ChildRemoved:Connect(function(child)
		if child == backpack then
			bindBackpack(nil)
		end
	end)
	player.CharacterAdded:Connect(bindCharacter)
	player.CharacterRemoving:Connect(function(oldCharacter)
		if oldCharacter == character then
			bindCharacter(nil)
		end
	end)

	Data.inventory.Changed(scheduleRender)
	Data.hotbar.Changed(scheduleRender)
	scheduleRender()

	UserInputService.InputChanged:Connect(updateDrag)
	UserInputService.InputEnded:Connect(finishDrag)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			InventoryRoot.toggle()
			return
		end
		local index = keyToIndex[input.KeyCode]
		if index then
			selectSlot(index)
		end
	end)

	task.spawn(function()
		for _ = 1, 20 do
			local success = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			end)
			if success then
				return
			end
			task.wait(0.25)
		end
		warn("Could not hide the default Backpack bar")
	end)
end

return InventoryServiceClient
