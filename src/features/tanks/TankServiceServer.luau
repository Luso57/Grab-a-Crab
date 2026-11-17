--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local DecorConfig = require(ReplicatedStorage.Source.Features.DecorShop.DecorConfig)
local DecorPlacement = require(ReplicatedStorage.Source.Features.Tanks.Modules.TankDecorationPlacement)
local TankServer = require(script.Parent.Classes.TankServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)

type SavedItem = {
	itemId: string,
	placedSlotId: string?,
	incubatorInstanceId: string?,
	tankInstanceId: string?,
	decorSlot: number?,
	decorX: number?,
	decorZ: number?,
	decorRotation: number?,
	weightGrams: number?,
}
type SavedInventory = { [string]: SavedItem }

local TankServiceServer = {}
local initialized = false
local networker = nil
local placedByPlayer: { [Player]: { [string]: TankServer.TankServer } } = {}
local placedByModel: { [Model]: TankServer.TankServer } = {}

local function inRange(player: Player, target: BasePart): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - target.Position).Magnitude <= 10
end

local function equippedCrab(player: Player, inventory: SavedInventory, hotbar: { string }): (Tool?, string?, string?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	for _, child in character:GetChildren() do
		if not child:IsA("Tool") then
			continue
		end
		local itemId = child:GetAttribute("ItemId")
		local instanceId = child:GetAttribute("ItemInstanceId")
		local crabId = if typeof(itemId) == "string" then string.match(itemId, "^Crab%.([%w_]+)$") else nil
		local item = if typeof(instanceId) == "string" then inventory[instanceId] else nil
		if crabId and Crabs.get(crabId) and typeof(instanceId) == "string"
			and typeof(item) == "table" and item.itemId == itemId
			and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil
			and table.find(hotbar, instanceId) ~= nil then
			return child, instanceId, crabId
		end
	end
	return nil, nil, nil
end

function TankServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	networker = Networker.server.new("TankService", self, { self.addInventoryCrab, self.pickupCrab, self.sellCrab, self.placeDecoration, self.pickupDecoration })
	Players.PlayerRemoving:Connect(function(player)
		self:clearPlacedForPlayer(player)
	end)

	local elapsed = 0
	local autoElapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		autoElapsed += dt
		if elapsed >= 0.05 then
			elapsed = 0
			for _, tank in placedByModel do
				if tank:enteredMoneyPad() then
					self:collectMoneyPad(tank)
				end
			end
		end
		if autoElapsed >= 1 then
			autoElapsed = 0
			for player in placedByPlayer do
				self:collectAllMoneyPads(player)
			end
		end
	end)
end

function TankServiceServer:createTool(player: Player, tankId: string, instanceId: string): Tool?
	local definition = Tanks.get(tankId)
	if not definition or player.Parent ~= Players then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local templates = if assets then assets:FindFirstChild("Tanks") else nil
	local template = if templates then templates:FindFirstChild(definition.modelName) else nil
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("Missing tank model template:", definition.modelName)
		return nil
	end

	local model = template:Clone()
	local height = model:GetExtentsSize().Y
	if height <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(2 / height)

	local tool = Instance.new("Tool")
	tool.Name = definition.name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("TankId", tankId)
	tool:SetAttribute("TankInstanceId", instanceId)
	tool:SetAttribute("ItemId", "Tank." .. tankId)
	tool:SetAttribute("ItemInstanceId", instanceId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.CFrame = model:GetPivot()
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = handle
		end
	end
	model.Parent = tool
	return tool
end

function TankServiceServer:registerPlaced(owner: Player, plotModel: Model, model: Model, instanceId: string): boolean
	if placedByModel[model] or owner.Parent ~= Players or not model:IsDescendantOf(plotModel) then
		return false
	end
	local itemId = model:GetAttribute("ItemId")
	local tankId = if typeof(itemId) == "string" then string.match(itemId, "^Tank%.([%w_]+)$") else nil
	local definition = if tankId then Tanks.get(tankId) else nil
	if not definition or model:GetAttribute("ItemInstanceId") ~= instanceId then
		return false
	end
	local playerTanks = placedByPlayer[owner]
	if playerTanks and playerTanks[instanceId] then
		return false
	end
	local tank = TankServer.new(owner, plotModel, instanceId, tankId :: string, model, definition.capacity, function(player)
		self:placeCrab(player, model)
	end)
	if not tank then
		return false
	end
	if not playerTanks then
		playerTanks = {}
		placedByPlayer[owner] = playerTanks
	end
	playerTanks[instanceId] = tank
	placedByModel[model] = tank
	return true
end

function TankServiceServer:getPlacedTank(player: Player, instanceId: string): TankServer.TankServer?
	local playerTanks = placedByPlayer[player]
	return if playerTanks then playerTanks[instanceId] else nil
end

function TankServiceServer:isOccupied(model: Model): boolean
	local tank = placedByModel[model]
	return tank ~= nil and tank:isOccupied()
end

function TankServiceServer:unregisterPlaced(model: Model)
	local tank = placedByModel[model]
	if not tank then
		return
	end
	placedByModel[model] = nil
	local playerTanks = placedByPlayer[tank.owner]
	if playerTanks then
		playerTanks[tank.instanceId] = nil
	end
	tank:destroy()
end

function TankServiceServer:clearPlacedForPlayer(player: Player)
	local playerTanks = placedByPlayer[player]
	if not playerTanks then
		return
	end
	local models = {}
	for _, tank in playerTanks do
		table.insert(models, tank.model)
	end
	for _, model in models do
		self:unregisterPlaced(model)
	end
	placedByPlayer[player] = nil
end

function TankServiceServer:collectAllMoneyPads(player: Player)
	local data = Data[player]
	local playerTanks = placedByPlayer[player]
	if not data or not data.autoCollectOwned() or not playerTanks then
		return
	end
	for _, tank in playerTanks do
		self:collectMoneyPad(tank, true)
	end
end

function TankServiceServer:collectMoneyPad(tank: TankServer.TankServer, silent: boolean?)
	local player = tank.owner
	local model = tank.model
	if tank.destroyed or placedByModel[model] ~= tank or player.Parent ~= Players
		or not model:IsDescendantOf(tank.plotModel) then
		return
	end
	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= model then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local savedTank = (data.inventory() :: SavedInventory)[tank.instanceId]
	if typeof(savedTank) ~= "table" or savedTank.itemId ~= "Tank." .. tank.tankId
		or savedTank.placedSlotId ~= slotId then
		return
	end
	local amount, now = tank:collectableAmount()
	if amount <= 0 then
		return
	end
	Money.set(data, "money", Money.add(Money.get(data, "money"), tostring(math.max(0, math.floor(amount)))))
	tank:resetMoneyPad(now)
	if silent then
		return
	end
	model:SetAttribute("MoneyPadCollectionSerial", (model:GetAttribute("MoneyPadCollectionSerial") or 0) + 1)
	local pad = tank.moneyPad
	local green = if pad then pad:FindFirstChild("GreenInnerCircle") else nil
	local collectionSound = if green then green:FindFirstChild("CollectionSound") else nil
	if collectionSound and collectionSound:IsA("Sound") then
		collectionSound.TimePosition = 0
		collectionSound:Play()
	end
end

function TankServiceServer:placeCrab(player: Player, model: Model)
	local tank = placedByModel[model]
	if not tank or tank.owner ~= player or player.Parent ~= Players or not tank:canAdd()
		or not model:IsDescendantOf(tank.plotModel) or not inRange(player, tank.floor) then
		return
	end
	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= model then
		return
	end

	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local savedTank = inventory[tank.instanceId]
	if typeof(savedTank) ~= "table" or savedTank.itemId ~= "Tank." .. tank.tankId
		or savedTank.placedSlotId ~= slotId then
		return
	end
	local hotbar = data.hotbar() :: { string }
	local tool, crabInstanceId, crabId = equippedCrab(player, inventory, hotbar)
	if not tool or not crabInstanceId or not crabId or not tank:addCrab(crabInstanceId, crabId, inventory[crabInstanceId].weightGrams) then
		return
	end

	local crabItem = inventory[crabInstanceId]
	local updatedCrab = table.clone(crabItem)
	updatedCrab.tankInstanceId = tank.instanceId
	data.inventory[crabInstanceId](updatedCrab)
	TutorialServiceServer:crabPlaced(player, crabInstanceId, slotId)

	local updatedHotbar = table.clone(hotbar)
	for index, assignedId in updatedHotbar do
		if assignedId == crabInstanceId then
			updatedHotbar[index] = InventoryConfig.emptySlot
		end
	end
	data.hotbar(updatedHotbar)
	tool:Destroy()
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
end

function TankServiceServer:pickupCrab(player: Player, tankInstanceId: any, crabInstanceId: any)
	if typeof(tankInstanceId) ~= "string" or typeof(crabInstanceId) ~= "string"
		or player.Parent ~= Players then
		return
	end
	local tank = self:getPlacedTank(player, tankInstanceId)
	if not tank or tank.destroyed or not tank.model:IsDescendantOf(tank.plotModel)
		or not inRange(player, tank.floor) then
		return
	end

	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = tank.model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= tank.model then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local savedTank = inventory[tankInstanceId]
	local savedCrab = inventory[crabInstanceId]
	local crabId = if typeof(savedCrab) == "table" and typeof(savedCrab.itemId) == "string"
		then string.match(savedCrab.itemId, "^Crab%.([%w_]+)$") else nil
	if typeof(savedTank) ~= "table" or savedTank.itemId ~= "Tank." .. tank.tankId
		or savedTank.placedSlotId ~= slotId or typeof(savedCrab) ~= "table"
		or savedCrab.tankInstanceId ~= tankInstanceId or savedCrab.placedSlotId ~= nil
		or savedCrab.incubatorInstanceId ~= nil or not crabId or not Crabs.get(crabId) then
		return
	end
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	if InventoryServiceServer:isFull(player) then
		InventoryServiceServer:showInventoryFull(player)
		return
	end
	if not tank:removeCrab(crabInstanceId, crabId) then
		return
	end

	local updatedCrab = table.clone(savedCrab)
	updatedCrab.tankInstanceId = nil
	data.inventory[crabInstanceId](updatedCrab)

	local hotbar = data.hotbar() :: { string }
	local destinationSlot = table.find(hotbar, crabInstanceId)
	if destinationSlot == nil then
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if hotbar[index] == InventoryConfig.emptySlot then
				local updatedHotbar = table.clone(hotbar)
				updatedHotbar[index] = crabInstanceId
				data.hotbar(updatedHotbar)
				destinationSlot = index
				break
			end
		end
	end
	InventoryServiceServer:refreshTools(player)
	if networker and player.Parent == Players then
		networker:fire(player, "showPickedUpItem", crabInstanceId, destinationSlot or 0)
	end
end

function TankServiceServer:sellCrab(player: Player, tankInstanceId: any, crabInstanceId: any)
	if typeof(tankInstanceId) ~= "string" or typeof(crabInstanceId) ~= "string"
		or player.Parent ~= Players then
		return
	end
	local tank = self:getPlacedTank(player, tankInstanceId)
	if not tank or tank.destroyed or not tank.model:IsDescendantOf(tank.plotModel)
		or not inRange(player, tank.floor) then
		return
	end

	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = tank.model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= tank.model then
		return
	end

	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local savedTank = inventory[tankInstanceId]
	local savedCrab = inventory[crabInstanceId]
	local crabId = if typeof(savedCrab) == "table" and typeof(savedCrab.itemId) == "string"
		then string.match(savedCrab.itemId, "^Crab%.([%w_]+)$") else nil
	local sellValue = if crabId then Crabs.sellValue(crabId) else nil
	if typeof(savedTank) ~= "table" or savedTank.itemId ~= "Tank." .. tank.tankId
		or savedTank.placedSlotId ~= slotId or typeof(savedCrab) ~= "table"
		or savedCrab.tankInstanceId ~= tankInstanceId or savedCrab.placedSlotId ~= nil
		or savedCrab.incubatorInstanceId ~= nil or not crabId or not sellValue or sellValue <= 0
		or not tank:removeCrab(crabInstanceId, crabId) then
		return
	end

	data.inventory[crabInstanceId](nil)
	local hotbar = data.hotbar() :: { string }
	if table.find(hotbar, crabInstanceId) then
		local updatedHotbar = table.clone(hotbar)
		for index, assignedId in updatedHotbar do
			if assignedId == crabInstanceId then
				updatedHotbar[index] = InventoryConfig.emptySlot
			end
		end
		data.hotbar(updatedHotbar)
	end
	Money.set(data, "money", Money.add(Money.get(data, "money"), tostring(sellValue)))

	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
	if networker and player.Parent == Players then
		networker:fire(player, "showSaleCoins")
	end
end

local function verifiedTank(player: Player, tankInstanceId: string): TankServer.TankServer?
	local tank = TankServiceServer:getPlacedTank(player, tankInstanceId)
	if not tank or tank.destroyed or not tank.model:IsDescendantOf(tank.plotModel) then
		return nil
	end
	local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
	local plot = PlotServiceServer:getPlot(player)
	local slotId = tank.model:GetAttribute("SlotId")
	if not plot or plot:getOwner() ~= player or plot.model ~= tank.plotModel
		or typeof(slotId) ~= "string" or plot:getPlaced(slotId) ~= tank.model then
		return nil
	end
	local data = Data[player]
	local item = if data then (data.inventory() :: SavedInventory)[tankInstanceId] else nil
	if not item or item.itemId ~= "Tank." .. tank.tankId or item.placedSlotId ~= slotId then
		return nil
	end
	return tank
end

function TankServiceServer:addInventoryCrab(player: Player, tankInstanceId: any, crabInstanceId: any)
	if typeof(tankInstanceId) ~= "string" or typeof(crabInstanceId) ~= "string" or player.Parent ~= Players then
		return
	end
	local function result(success: boolean, message: string)
		if networker and player.Parent == Players then
			networker:fire(player, "crabPlacementResult", tankInstanceId, crabInstanceId, success, message)
		end
	end
	local tank = verifiedTank(player, tankInstanceId)
	if not tank or not inRange(player, tank.floor) then
		result(false, "MOVE CLOSER TO THE TANK")
		return
	end
	if not tank:canAdd() then
		result(false, "TANK IS FULL")
		return
	end
	local data = Data[player]
	if not data then
		result(false, "CRAB IS UNAVAILABLE")
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[crabInstanceId]
	local crabId = if typeof(item) == "table" and typeof(item.itemId) == "string"
		then string.match(item.itemId, "^Crab%.([%w_]+)$") else nil
	if not crabId or not Crabs.get(crabId) or item.placedSlotId ~= nil
		or item.incubatorInstanceId ~= nil or item.tankInstanceId ~= nil then
		result(false, "CRAB IS UNAVAILABLE")
		return
	end
	if not tank:addCrab(crabInstanceId, crabId, item.weightGrams) then
		result(false, "COULD NOT ADD CRAB")
		return
	end
	local updated = table.clone(item)
	updated.tankInstanceId = tankInstanceId
	data.inventory[crabInstanceId](updated)
	TutorialServiceServer:crabPlaced(player, crabInstanceId, tank.model:GetAttribute("SlotId"))
	local hotbar = data.hotbar() :: { string }
	local updatedHotbar = table.clone(hotbar)
	for index, assignedId in updatedHotbar do
		if assignedId == crabInstanceId then
			updatedHotbar[index] = InventoryConfig.emptySlot
		end
	end
	data.hotbar(updatedHotbar)
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
	result(true, "")
end

function TankServiceServer:placeDecoration(player: Player, tankInstanceId: any, itemInstanceId: any, slot: any, x: any, z: any, rotation: any)
	local function reject()
		if networker and player.Parent == Players and typeof(tankInstanceId) == "string"
			and typeof(itemInstanceId) == "string" then
			networker:fire(player, "decorationPlacementRejected", tankInstanceId, itemInstanceId)
		end
	end
	if player.Parent ~= Players or typeof(tankInstanceId) ~= "string" or typeof(itemInstanceId) ~= "string"
		or typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > DecorPlacement.slotCount
		or not DecorPlacement.isFinite(x) or not DecorPlacement.isFinite(z)
		or not DecorPlacement.isRotation(rotation) then
		reject()
		return
	end
	local tank = verifiedTank(player, tankInstanceId)
	local data = Data[player]
	if not tank or not data then
		reject()
		return
	end
	local item = (data.inventory() :: SavedInventory)[itemInstanceId]
	local decorId = if item and typeof(item.itemId) == "string" then string.match(item.itemId, "^Decor%.([%w_]+)$") else nil
	if not item or not decorId or not DecorConfig.get(decorId) or item.tankInstanceId ~= nil
		or item.placedSlotId ~= nil or item.incubatorInstanceId ~= nil then
		reject()
		return
	end
	if not tank:addDecoration(slot, itemInstanceId, decorId, x, z, rotation) then
		reject()
		return
	end
	local updated = table.clone(item)
	updated.tankInstanceId = tankInstanceId
	updated.decorSlot = slot
	updated.decorX = x
	updated.decorZ = z
	updated.decorRotation = rotation
	data.inventory[itemInstanceId](updated)
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
	if networker then
		networker:fire(player, "decorationPlaced", tankInstanceId, itemInstanceId)
	end
end

function TankServiceServer:pickupDecoration(player: Player, tankInstanceId: any, itemInstanceId: any)
	if player.Parent ~= Players or typeof(tankInstanceId) ~= "string" or typeof(itemInstanceId) ~= "string" then
		return
	end
	local tank = verifiedTank(player, tankInstanceId)
	local data = Data[player]
	if not tank or not data then
		return
	end
	local item = (data.inventory() :: SavedInventory)[itemInstanceId]
	local decorId = if item and typeof(item.itemId) == "string" then string.match(item.itemId, "^Decor%.([%w_]+)$") else nil
	if not item or not decorId or not DecorConfig.get(decorId) or item.tankInstanceId ~= tankInstanceId
		or typeof(item.decorSlot) ~= "number" then
		return
	end
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	if InventoryServiceServer:isFull(player) then
		InventoryServiceServer:showInventoryFull(player)
		return
	end
	if not tank:removeDecoration(item.decorSlot, itemInstanceId) then
		return
	end
	local updated = table.clone(item)
	updated.tankInstanceId = nil
	updated.decorSlot = nil
	updated.decorX = nil
	updated.decorZ = nil
	updated.decorRotation = nil
	data.inventory[itemInstanceId](updated)
	local hotbar = data.hotbar() :: { string }
	local destinationSlot = table.find(hotbar, itemInstanceId)
	if not destinationSlot then
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if hotbar[index] == InventoryConfig.emptySlot then
				local updatedHotbar = table.clone(hotbar)
				updatedHotbar[index] = itemInstanceId
				data.hotbar(updatedHotbar)
				destinationSlot = index
				break
			end
		end
	end
	InventoryServiceServer:refreshTools(player)
	if networker and player.Parent == Players then
		networker:fire(player, "showPickedUpItem", itemInstanceId, InventoryServiceServer:getHotbarSlot(player, itemInstanceId) or 0)
	end
end

function TankServiceServer:restoreContents(player: Player)
	local playerTanks = placedByPlayer[player]
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local containedInstanceIds = {}
	for instanceId, item in inventory do
		if typeof(item) == "table" and item.tankInstanceId ~= nil then
			table.insert(containedInstanceIds, instanceId)
		end
	end
	table.sort(containedInstanceIds)

	local repaired = {}
	for _, instanceId in containedInstanceIds do
		local item = inventory[instanceId]
		local tank = if typeof(item.tankInstanceId) == "string" and playerTanks then playerTanks[item.tankInstanceId] else nil
		local tankItem = if tank then inventory[tank.instanceId] else nil
		local crabId = if typeof(item.itemId) == "string" then string.match(item.itemId, "^Crab%.([%w_]+)$") else nil
		local decorId = if typeof(item.itemId) == "string" then string.match(item.itemId, "^Decor%.([%w_]+)$") else nil
		local slotId = if tank then tank.model:GetAttribute("SlotId") else nil
		if not tank or not tankItem or tankItem.itemId ~= "Tank." .. tank.tankId
			or tankItem.placedSlotId ~= slotId
			or item.placedSlotId ~= nil or item.incubatorInstanceId ~= nil
			or not ((crabId and Crabs.get(crabId) and tank:addCrab(instanceId, crabId, item.weightGrams))
				or (decorId and DecorConfig.get(decorId) and typeof(item.decorSlot) == "number"
					and DecorPlacement.isFinite(item.decorX) and DecorPlacement.isFinite(item.decorZ)
					and DecorPlacement.isRotation(item.decorRotation)
					and tank:addDecoration(item.decorSlot, instanceId, decorId, item.decorX, item.decorZ, item.decorRotation))) then
			local updated = table.clone(item)
			updated.tankInstanceId = nil
			updated.decorSlot = nil
			updated.decorX = nil
			updated.decorZ = nil
			updated.decorRotation = nil
			data.inventory[instanceId](updated)
			table.insert(repaired, instanceId)
		end
	end

	if #repaired > 0 then
		local hotbar = data.hotbar() :: { string }
		local updatedHotbar = table.clone(hotbar)
		for _, instanceId in repaired do
			if table.find(updatedHotbar, instanceId) == nil then
				for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
					if updatedHotbar[index] == InventoryConfig.emptySlot then
						updatedHotbar[index] = instanceId
						break
					end
				end
			end
		end
		data.hotbar(updatedHotbar)
	end
	local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
	InventoryServiceServer:refreshTools(player)
end

return TankServiceServer
