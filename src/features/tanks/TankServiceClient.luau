--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local DecorConfig = require(ReplicatedStorage.Source.Features.DecorShop.DecorConfig)
local TankClient = require(script.Parent.Classes.TankClient)
local TankPopupRoot = require(script.Parent.UI.TankPopupRoot)
local TankPickupEffect = require(script.Parent.UI.TankPickupEffect)
local TankEmptyWarning = require(script.Parent.UI.TankEmptyWarning)
local TankDecorationPlacementClient = require(script.Parent.Classes.TankDecorationPlacementClient)
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local MoneyServiceClient = require(ReplicatedStorage.Source.Features.Money.MoneyServiceClient)

local TankServiceClient = {}
local initialized = false
local tanks: { [Model]: TankClient.TankClient } = {}
local pendingTanks: { [Model]: { RBXScriptConnection } } = {}
local selectedTank: TankClient.TankClient? = nil
local popupOpen = Vide.source(false)
local popupCards = Vide.source({} :: { TankPopupRoot.Card })
local popupCapacity = Vide.source(0)
local popupBoostPercent = Vide.source(0)
local availableCrabs = Vide.source({} :: { TankPopupRoot.AvailableCrab })
local crabPickerOpen = Vide.source(false)
local crabPlacementMessage = Vide.source("")
local pendingCrabInstanceId: string? = nil
local decorCounts = Vide.source({} :: { [string]: number })
local selectedDecorSlot = Vide.source(nil :: number?)
local decorSlots = Vide.source({} :: { [number]: { instanceId: string, decorId: string } })
local activePlacement = nil
local placementItemId: string? = nil
local cardSignature = ""
local pendingPickups: { [string]: { imageId: number, position: Vector2 } } = {}
local playPickup: ((number, Vector2, number?) -> ())? = nil
local showEmptyWarning: ((string?) -> ())? = nil

local function queuePickupAnimation(instanceId: string, imageId: number, position: Vector2)
	local origin = { imageId = imageId, position = position }
	pendingPickups[instanceId] = origin
	task.delay(5, function()
		if pendingPickups[instanceId] == origin then
			pendingPickups[instanceId] = nil
		end
	end)
end

local function closePopup()
	if activePlacement then
		activePlacement:destroy()
		activePlacement = nil
		placementItemId = nil
	end
	selectedTank = nil
	cardSignature = ""
	popupCards({})
	popupCapacity(0)
	popupBoostPercent(0)
	selectedDecorSlot(nil)
	crabPickerOpen(false)
	crabPlacementMessage("")
	pendingCrabInstanceId = nil
	popupOpen(false)
end

local function refreshDecorations()
	local counts: { [string]: number } = {}
	local slots: { [number]: { instanceId: string, decorId: string } } = {}
	for instanceId, item in Data.inventory() do
		if typeof(item) == "table" and typeof(item.itemId) == "string"
			and item.placedSlotId == nil and item.incubatorInstanceId == nil then
			local decorId = string.match(item.itemId, "^Decor%.([%w_]+)$")
			if decorId and DecorConfig.get(decorId) then
				if item.tankInstanceId == nil then
					counts[decorId] = (counts[decorId] or 0) + 1
				elseif selectedTank and item.tankInstanceId == selectedTank.instanceId
					and typeof(item.decorSlot) == "number" then
					slots[item.decorSlot] = { instanceId = instanceId, decorId = decorId }
				end
			end
		end
	end
	decorCounts(counts)
	decorSlots(slots)
end

local function refreshAvailableCrabs()
	local crabs: { TankPopupRoot.AvailableCrab } = {}
	for instanceId, item in Data.inventory() do
		if typeof(item) == "table" and typeof(item.itemId) == "string"
			and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil then
			local crabId = string.match(item.itemId, "^Crab%.([%w_]+)$")
			local definition = if crabId then Crabs.get(crabId) else nil
			if definition then
				table.insert(crabs, {
					instanceId = instanceId,
					name = definition.name,
					imageId = definition.imageId,
					weightGrams = CrabWeights.normalize(item.weightGrams),
					weight = CrabWeights.format(item.weightGrams),
				})
			end
		end
	end
	table.sort(crabs, function(left, right)
		if left.name ~= right.name then
			return left.name < right.name
		end
		if left.weightGrams ~= right.weightGrams then
			return left.weightGrams < right.weightGrams
		end
		return left.instanceId < right.instanceId
	end)
	availableCrabs(crabs)
end

local function refreshInventory()
	refreshDecorations()
	refreshAvailableCrabs()
end

local function isLocalOwner(model: Model): boolean
	local placedFolder = model.Parent
	local plotModel = if placedFolder then placedFolder.Parent else nil
	return placedFolder ~= nil and placedFolder.Name == "PlacedItems"
		and plotModel ~= nil and plotModel:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId
end

local function refreshPopup()
	local tank = selectedTank
	if not tank then
		return
	end
	if tanks[tank.model] ~= tank or not isLocalOwner(tank.model) then
		closePopup()
		return
	end

	local nextCards: { TankPopupRoot.Card } = {}
	local signatureParts: { string } = {}
	local rawBoost = tank.model:GetAttribute("TankIncomeBoostPercent")
	local boostPercent = if typeof(rawBoost) == "number" then rawBoost else 0
	popupBoostPercent(boostPercent)
	local rawCapacity = tank.model:GetAttribute("TankCapacity")
	popupCapacity(if typeof(rawCapacity) == "number" then rawCapacity else 0)
	local folder = tank.model:FindFirstChild("ContainedCrabs")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and child.Name == "ContainedCrabAnchor" then
				local crabId = child:GetAttribute("CrabId")
				local definition = if typeof(crabId) == "string" then Crabs.get(crabId) else nil
				if definition then
					local instanceId = child:GetAttribute("ItemInstanceId")
					local key = if typeof(instanceId) == "string" then instanceId else child.Name
					local sellValue = Crabs.sellValue(crabId)
					table.insert(nextCards, {
						instanceId = key,
						name = definition.name,
						imageId = definition.imageId,
						weight = string.upper(CrabWeights.format(child:GetAttribute("WeightGrams"))),
						income = if definition.tankIncomeMultiplier then string.format("x%g BOOST", definition.tankIncomeMultiplier)
							else CompactNumber.formatIncomeRate(CrabWeights.income(definition.incomePerSecond, child:GetAttribute("WeightGrams")) * (1 + boostPercent / 100)) .. "/s",
						isBoost = definition.tankIncomeMultiplier ~= nil,
						sellPrice = CompactNumber.format(sellValue or 0),
						canSell = sellValue ~= nil,
					})
					table.insert(signatureParts, key .. ":" .. crabId .. ":" .. tostring(child:GetAttribute("WeightGrams")))
				end
			end
		end
	end
	table.sort(nextCards, function(a, b)
		return a.instanceId < b.instanceId
	end)
	table.sort(signatureParts)
	local nextSignature = tostring(boostPercent) .. "|" .. table.concat(signatureParts, "|")
	if nextSignature ~= cardSignature then
		cardSignature = nextSignature
		popupCards(nextCards)
	end
	if #nextCards >= popupCapacity() then
		crabPickerOpen(false)
	end
end

local function hasHammerEquipped(): boolean
	local character = Players.LocalPlayer.Character
	if not character then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ItemId") == InventoryConfig.hammerItemId then
			return true
		end
	end
	return false
end
local function openTank(model: Model)
	local tank = tanks[model]
	if not tank or not isLocalOwner(model) then
		return
	end
	if hasHammerEquipped() then
		closePopup()
		local show = showEmptyWarning
		if show then
			show()
		end
		return
	end
	selectedTank = tank
	refreshInventory()
	selectedDecorSlot(nil)
	crabPickerOpen(false)
	crabPlacementMessage("")
	cardSignature = "#"
	refreshPopup()
	popupOpen(true)
end

function TankServiceClient:showPickupWarning(message: string)
	local show = showEmptyWarning
	if show then
		show(message)
	end
end

function TankServiceClient:isPopupOpen(): boolean
	return popupOpen()
end

function TankServiceClient:closePopup()
	closePopup()
end

local function hasCrabEquipped(): boolean
	local character = Players.LocalPlayer.Character
	if not character then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local itemId = child:GetAttribute("ItemId")
			local instanceId = child:GetAttribute("ItemInstanceId")
			local crabId = if typeof(itemId) == "string" then string.match(itemId, "^Crab%.([%w_]+)$") else nil
			if typeof(instanceId) == "string" and crabId and Crabs.get(crabId) then
				return true
			end
		end
	end
	return false
end

local function clearPendingTank(model: Model)
	local connections = pendingTanks[model]
	if not connections then
		return
	end
	pendingTanks[model] = nil
	for _, connection in connections do
		connection:Disconnect()
	end
end

local function tryAttachTank(model: Model)
	if tanks[model] or not model.Parent or model.Parent.Name ~= "PlacedItems" then
		return
	end
	local itemId = model:GetAttribute("ItemId")
	if typeof(itemId) == "string" and not string.match(itemId, "^Tank%.[%w_]+$") then
		clearPendingTank(model)
		return
	end
	local instanceId = model:GetAttribute("ItemInstanceId")
	if typeof(itemId) ~= "string" or typeof(instanceId) ~= "string" then
		return
	end
	clearPendingTank(model)
	tanks[model] = TankClient.new(instanceId, model, openTank, function()
		if isLocalOwner(model) then
			MoneyServiceClient:playCollection()
		end
	end)
end

local function addTank(instance: Instance)
	if not instance:IsA("Model") or tanks[instance] or pendingTanks[instance]
		or not instance.Parent or instance.Parent.Name ~= "PlacedItems" then
		return
	end
	pendingTanks[instance] = {
		instance:GetAttributeChangedSignal("ItemId"):Connect(function()
			tryAttachTank(instance)
		end),
		instance:GetAttributeChangedSignal("ItemInstanceId"):Connect(function()
			tryAttachTank(instance)
		end),
	}
	tryAttachTank(instance)
end

local function removeTank(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	clearPendingTank(instance)
	local tank = tanks[instance]
	if tank then
		if selectedTank == tank then
			closePopup()
		end
		tanks[instance] = nil
		tank:destroy()
	end
end

function TankServiceClient:init()
	if initialized then
		return
	end
	initialized = true
	local networker = Networker.client.new("TankService", TankServiceClient)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	Players.LocalPlayer.CharacterAdded:Connect(closePopup)
	playPickup = TankPickupEffect.mount(playerGui)
	showEmptyWarning = TankEmptyWarning.mount(playerGui)
	Data.inventory.Changed(refreshInventory)
	refreshInventory()
	Vide.mount(function()
		return TankPopupRoot({
			cards = popupCards,
			capacity = popupCapacity,
			availableCrabs = availableCrabs,
			crabPickerOpen = crabPickerOpen,
			crabPlacementMessage = crabPlacementMessage,
			boostPercent = popupBoostPercent,
			decorCounts = decorCounts,
			decorSlots = decorSlots,
			selectedDecorSlot = selectedDecorSlot,
			isOpen = popupOpen,
			onClose = closePopup,
			onOpenCrabPicker = function()
				local tank = selectedTank
				if not tank or not isLocalOwner(tank.model) or #popupCards() >= popupCapacity() then
					return
				end
				selectedDecorSlot(nil)
				crabPlacementMessage("")
				crabPickerOpen(true)
			end,
			onCloseCrabPicker = function()
				crabPickerOpen(false)
				crabPlacementMessage("")
			end,
			onChooseCrab = function(crabInstanceId: string)
				local tank = selectedTank
				if not tank or not crabPickerOpen() or pendingCrabInstanceId
					or not isLocalOwner(tank.model) or #popupCards() >= popupCapacity() then
					return
				end
				local available = false
				for _, crab in availableCrabs() do
					if crab.instanceId == crabInstanceId then
						available = true
						break
					end
				end
				if not available then
					return
				end
				pendingCrabInstanceId = crabInstanceId
				crabPlacementMessage("ADDING CRAB...")
				networker:fire("addInventoryCrab", tank.instanceId, crabInstanceId)
				task.delay(5, function()
					if selectedTank == tank and pendingCrabInstanceId == crabInstanceId then
						pendingCrabInstanceId = nil
						crabPlacementMessage("TRY AGAIN")
					end
				end)
			end,
			onDecorSlotSelected = function(slotIndex: number)
				local tank = selectedTank
				if not tank or not isLocalOwner(tank.model) then
					return
				end
				crabPickerOpen(false)
				selectedDecorSlot(if selectedDecorSlot() == slotIndex then nil else slotIndex)
			end,
			onCloseDecorations = function()
				selectedDecorSlot(nil)
			end,
			onChooseDecoration = function(decorId: string)
				local tank = selectedTank
				local slot = selectedDecorSlot()
				if not tank or not slot or decorSlots()[slot] or not isLocalOwner(tank.model) then
					return
				end
				local itemId: string? = nil
				for instanceId, item in Data.inventory() do
					if item.itemId == "Decor." .. decorId and item.tankInstanceId == nil
						and item.placedSlotId == nil and item.incubatorInstanceId == nil then
						itemId = instanceId
						break
					end
				end
				if not itemId then
					return
				end
				popupOpen(false)
				selectedDecorSlot(nil)
				local function cancel()
					if activePlacement then
						activePlacement:destroy()
						activePlacement = nil
					end
					placementItemId = nil
					if selectedTank == tank and tanks[tank.model] == tank then
						popupOpen(true)
					end
				end
				activePlacement = TankDecorationPlacementClient.new(tank.model, decorId, function(x: number, z: number, rotation: number)
					if placementItemId ~= itemId then
						return
					end
					if activePlacement then
						activePlacement:setStatus("PLACING...")
					end
					networker:fire("placeDecoration", tank.instanceId, itemId, slot, x, z, rotation)
				end, cancel)
				placementItemId = if activePlacement then itemId else nil
				if not activePlacement then
					popupOpen(true)
				end
			end,
			onPickupDecoration = function(itemInstanceId: string, startPosition: Vector2)
				local tank = selectedTank
				if not tank or not isLocalOwner(tank.model) then
					return
				end
				for _, placed in decorSlots() do
					if placed.instanceId == itemInstanceId then
						local definition = DecorConfig.get(placed.decorId)
						if definition then
							queuePickupAnimation(itemInstanceId, definition.imageId, startPosition)
							networker:fire("pickupDecoration", tank.instanceId, itemInstanceId)
						end
						return
					end
				end
			end,
			onSell = function(crabInstanceId: string)
				local tank = selectedTank
				if not tank or not isLocalOwner(tank.model) then
					return
				end
				for _, card in popupCards() do
					if card.instanceId == crabInstanceId then
						if card.canSell then
							networker:fire("sellCrab", tank.instanceId, crabInstanceId)
						end
						return
					end
				end
			end,
			onPickUp = function(crabInstanceId: string, startPosition: Vector2)
				local tank = selectedTank
				if not tank or not isLocalOwner(tank.model) then
					return
				end
				for _, card in popupCards() do
					if card.instanceId == crabInstanceId then
						queuePickupAnimation(crabInstanceId, card.imageId, startPosition)
						networker:fire("pickupCrab", tank.instanceId, crabInstanceId)
						return
					end
				end
			end,
		})
	end, playerGui)

	local spawnedPlots = Workspace:WaitForChild("SpawnedPlots")
	spawnedPlots.DescendantAdded:Connect(addTank)
	spawnedPlots.DescendantRemoving:Connect(removeTank)
	for _, instance in spawnedPlots:GetDescendants() do
		addTank(instance)
	end

	RunService.PreSimulation:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		for model, tank in tanks do
			if model:IsDescendantOf(spawnedPlots) then
				tank:step(dt, cameraPosition)
			end
		end
	end)
	RunService.PostSimulation:Connect(function()
		local camera = Workspace.CurrentCamera
		local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
		for model, tank in tanks do
			if model:IsDescendantOf(spawnedPlots) then
				tank:correctContainment(cameraPosition)
			end
		end
	end)

	task.spawn(function()
		while spawnedPlots.Parent do
			local equipped = hasCrabEquipped()
			for model, tank in tanks do
				if model:IsDescendantOf(spawnedPlots) then
					tank:update(equipped, activePlacement ~= nil)
				else
					removeTank(model)
				end
			end
			refreshPopup()
			task.wait(0.1)
		end
	end)
end

function TankServiceClient:crabPlacementResult(tankInstanceId: any, crabInstanceId: any, success: any, message: any)
	if not selectedTank or selectedTank.instanceId ~= tankInstanceId
		or pendingCrabInstanceId ~= crabInstanceId then
		return
	end
	pendingCrabInstanceId = nil
	if success == true then
		crabPlacementMessage("")
		refreshPopup()
	elseif crabPickerOpen() then
		crabPlacementMessage(if typeof(message) == "string" then message else "COULD NOT ADD CRAB")
	end
end

function TankServiceClient:decorationPlaced(tankInstanceId: any, itemInstanceId: any)
	if typeof(itemInstanceId) ~= "string" or itemInstanceId ~= placementItemId then
		return
	end
	if not selectedTank or selectedTank.instanceId ~= tankInstanceId then
		return
	end
	if activePlacement then
		activePlacement:destroy()
		activePlacement = nil
	end
	placementItemId = nil
	refreshDecorations()
	popupOpen(true)
end

function TankServiceClient:decorationPlacementRejected(tankInstanceId: any, itemInstanceId: any)
	if typeof(itemInstanceId) ~= "string" or itemInstanceId ~= placementItemId
		or not selectedTank or selectedTank.instanceId ~= tankInstanceId then
		return
	end
	if activePlacement then
		local placement = activePlacement
		placement:setStatus("CAN'T PLACE HERE - TRY ANOTHER SPOT")
		task.delay(2, function()
			if activePlacement == placement then
				placement:setStatus("MOVE DECORATION INSIDE THE TANK")
			end
		end)
	end
end

function TankServiceClient:showPickedUpItem(instanceId: any, slotIndex: any)
	if typeof(instanceId) ~= "string" then
		return
	end
	local origin = pendingPickups[instanceId]
	pendingPickups[instanceId] = nil
	local play = playPickup
	if origin and play then
		play(origin.imageId, origin.position, if typeof(slotIndex) == "number" and slotIndex > 0 then slotIndex else nil)
	end
end

function TankServiceClient:showSaleCoins()
	MoneyServiceClient:playCollection()
end

function TankServiceClient:getTank(instanceId: string): TankClient.TankClient?
	for _, tank in tanks do
		if tank.instanceId == instanceId then
			return tank
		end
	end
	return nil
end

return TankServiceClient
