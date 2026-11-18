--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local ItemCatalog = require(ReplicatedStorage.Source.Game.Items.ItemCatalog)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local Incubators = require(ReplicatedStorage.Source.Features.Incubators.Modules.Incubators)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)
local CrabSizeIndex = require(ReplicatedStorage.Source.Features.Index.Modules.CrabSizeIndex)
local IndexMilestones = require(ReplicatedStorage.Source.Features.Index.Modules.IndexMilestones)
local ServerLuck = require(ReplicatedStorage.Source.Features.Monotization.Modules.LuckBoost)
local GiganticEggConfig = require(ReplicatedStorage.Source.Features.EggConveyor.Modules.GiganticEggConfig)
local CrabServer = require(ServerScriptService.Features.Crabs.Classes.CrabServer)
local DecorToolFactoryServer = require(ServerScriptService.Features.DecorShop.Modules.DecorToolFactoryServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)

type SavedItem = { itemId: string, placedSlotId: string?, incubatorInstanceId: string?, tankInstanceId: string?, hatchAtUnixMs: number?, weightGrams: number?, hatchedEggId: string?, isGiganticEgg: boolean? }
type SavedInventory = { [string]: SavedItem }

local InventoryServiceServer = {}

local function isHotbarEligible(itemId: string): boolean
	local definition = ItemCatalog.get(itemId)
	return definition ~= nil and definition.hotbarEligible ~= false
end

local function isAvailable(item: SavedItem?): boolean
	return typeof(item) == "table" and typeof(item.itemId) == "string"
		and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil
		and isHotbarEligible(item.itemId)
end

local function isStackable(item: SavedItem?): boolean
	return typeof(item) == "table" and item.isGiganticEgg ~= true and ItemCatalog.isStackable(item.itemId)
end

local function findAvailableCopy(inventory: SavedInventory, itemId: string, used: { [string]: boolean }): string?
	local firstId: string? = nil
	for instanceId, item in inventory do
		if not used[instanceId] and isAvailable(item) and isStackable(item) and item.itemId == itemId
			and (not firstId or instanceId < firstId) then
			firstId = instanceId
		end
	end
	return firstId
end

local initialized = false
local networker = nil
local readyPlayers: { [Player]: boolean } = {}
local syncQueued: { [Player]: boolean } = {}
local preparingStarterItems: { [Player]: boolean } = {}
local sessionStartedAt: { [Player]: number } = {}
local NEW_PLAYER_BONUS_PLAY_SECONDS = 180
local NEW_PLAYER_BONUS_MIN_WEIGHT_HUNDREDTHS = 2500
local NEW_PLAYER_BONUS_MAX_WEIGHT_HUNDREDTHS = 5000
local GIGANTIC_EGG_MIN_WEIGHT_GRAMS = 50
local bonusWeightRandom = Random.new()

local function ensureHammer(data: any, player: Player): string
	local hammerId = InventoryConfig.hammerInstanceId(player.UserId)
	local inventory = data.inventory() :: SavedInventory
	for instanceId, item in inventory do
		if instanceId ~= hammerId and typeof(item) == "table" and item.itemId == InventoryConfig.hammerItemId then
			data.inventory[instanceId](nil)
		end
	end
	local saved = inventory[hammerId]
	if typeof(saved) ~= "table" or saved.itemId ~= InventoryConfig.hammerItemId or saved.placedSlotId ~= nil then
		data.inventory[hammerId]({ itemId = InventoryConfig.hammerItemId })
	end
	return hammerId
end

local function normalizeHotbar(data: any, player: Player): { string }
	local hammerId = ensureHammer(data, player)
	local inventory = data.inventory() :: SavedInventory
	local current = data.hotbar() :: { string }
	local normalized: { string } = { hammerId }
	local seen: { [string]: boolean } = { [hammerId] = true }
	local seenStackable: { [string]: boolean } = {}
	local changed = #current ~= InventoryConfig.hotbarSize or current[InventoryConfig.hammerSlot] ~= hammerId

	for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
		local instanceId = current[index]
		local item = if typeof(instanceId) == "string" then inventory[instanceId] else nil
		if typeof(item) == "table" and typeof(item.itemId) == "string"
			and isStackable(item) and not isAvailable(item) then
			instanceId = findAvailableCopy(inventory, item.itemId, seen) or InventoryConfig.emptySlot
			item = inventory[instanceId]
		end
		local stackable = isStackable(item)
		if isAvailable(item) and item.itemId ~= InventoryConfig.hammerItemId
			and not seen[instanceId] and (not stackable or not seenStackable[item.itemId]) then
			normalized[index] = instanceId
			seen[instanceId] = true
			if stackable then
				seenStackable[item.itemId] = true
			end
		else
			normalized[index] = InventoryConfig.emptySlot
		end
	end

	local displacedId = current[InventoryConfig.hammerSlot]
	local displaced = if typeof(displacedId) == "string" then inventory[displacedId] else nil
	if isAvailable(displaced) and displaced.itemId ~= InventoryConfig.hammerItemId
		and not seen[displacedId]
		and (not isStackable(displaced) or not seenStackable[displaced.itemId]) then
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if normalized[index] == InventoryConfig.emptySlot then
				normalized[index] = displacedId
				if isStackable(displaced) then
					seenStackable[displaced.itemId] = true
				end
				break
			end
		end
	end

	for index = 1, InventoryConfig.hotbarSize do
		if normalized[index] ~= current[index] then
			changed = true
		end
	end
	if changed then
		data.hotbar(normalized)
	end
	return normalized
end

local function createEggTool(player: Player, eggId: string, instanceId: string, isGiganticEgg: boolean?): Tool?
	local definition = Eggs.get(eggId)
	if not definition or player.Parent ~= Players then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local templates = if assets then assets:FindFirstChild("Eggs") else nil
	local template = if templates then templates:FindFirstChild(eggId) else nil
	if not template or not template:IsA("Model") or not template.PrimaryPart then
		warn("Missing egg model template:", eggId)
		return nil
	end

	local model = template:Clone()
	local height = model:GetExtentsSize().Y
	if height <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * 2 * (if isGiganticEgg then GiganticEggConfig.VISUAL_SCALE else 1) / height)

	local tool = Instance.new("Tool")
	tool.Name = (if isGiganticEgg then "Gigantic " else "") .. definition.name
	tool.TextureId = "rbxassetid://" .. definition.imageId
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("EggId", eggId)
	tool:SetAttribute("ItemId", "Egg." .. eggId)
	tool:SetAttribute("ItemInstanceId", instanceId)
	tool:SetAttribute("IsGiganticEgg", isGiganticEgg == true)

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
local function createTool(player: Player, itemId: string, instanceId: string, weightGrams: number?, isGiganticEgg: boolean?): Tool?
	if itemId == InventoryConfig.hammerItemId then
		local template = ReplicatedStorage:FindFirstChild("Assets")
		local tools = if template then template:FindFirstChild("Tools") else nil
		local hammer = if tools then tools:FindFirstChild("Hammer") else nil
		if not hammer or not hammer:IsA("Tool") then
			warn("Missing ReplicatedStorage.Assets.Tools.Hammer Tool")
			return nil
		end
		local tool = hammer:Clone()
		tool.CanBeDropped = false
		tool:SetAttribute("ItemId", itemId)
		tool:SetAttribute("ItemInstanceId", instanceId)
		return tool
	end
	local incubatorId = if itemId == "Incubator" then "Incubator" else string.match(itemId, "^Incubator%.([%w_]+)$")
	if incubatorId and Incubators.get(incubatorId) then
		return IncubatorServiceServer:createTool(player, incubatorId, instanceId)
	end
	local decorId = string.match(itemId, "^Decor%.([%w_]+)$")
	if decorId then
		return DecorToolFactoryServer.createTool(player, decorId, instanceId)
	end
	local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
	if eggId then
		return createEggTool(player, eggId, instanceId, isGiganticEgg)
	end

	local crabId = string.match(itemId, "^Crab%.([%w_]+)$")
	if crabId and Crabs.get(crabId) then
		local crab = CrabServer.new(instanceId, crabId, weightGrams)
		return if crab then crab.tool else nil
	end

	local tankId = string.match(itemId, "^Tank%.([%w_]+)$")
	if tankId and Tanks.get(tankId) then
		return TankServiceServer:createTool(player, tankId, instanceId)
	end
	return nil
end

local function syncTools(player: Player)
	if not readyPlayers[player] or player.Parent ~= Players then
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local hotbar = normalizeHotbar(data, player)
	local wanted: { [string]: string } = {}
	for index = 1, InventoryConfig.hotbarSize do
		local instanceId = hotbar[index]
		local item = if typeof(instanceId) == "string" then inventory[instanceId] else nil
		if typeof(item) == "table" and typeof(item.itemId) == "string" and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil and isHotbarEligible(item.itemId) then
			wanted[instanceId] = item.itemId
		end
	end

	local found: { [string]: boolean } = {}
	local function scan(container: Instance?)
		if not container then
			return
		end
		for _, child in container:GetChildren() do
			if not child:IsA("Tool") then
				continue
			end
			local instanceId = child:GetAttribute("ItemInstanceId")
			if typeof(instanceId) ~= "string" then
				continue
			end
			if wanted[instanceId] == child:GetAttribute("ItemId") and not found[instanceId] then
				found[instanceId] = true
			else
				child:Destroy()
			end
		end
	end

	scan(backpack)
	scan(player.Character)

	for instanceId, itemId in wanted do
		if not found[instanceId] then
			local savedItem = inventory[instanceId]
			local tool = createTool(player, itemId, instanceId, if savedItem then savedItem.weightGrams else nil, if savedItem then savedItem.isGiganticEgg else nil)
			if tool then
				tool.Parent = backpack
			end
		end
	end
end

local function scheduleSync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		syncTools(player)
	end)
end

function InventoryServiceServer:prepareStarterItems(player: Player, data: any?): boolean
	data = data or Data.Service:waitForData(player)
	if not data or player.Parent ~= Players then
		return false
	end
	while preparingStarterItems[player] do
		task.wait()
		if player.Parent ~= Players then
			return false
		end
	end
	preparingStarterItems[player] = true
	local succeeded, result = pcall(function(): boolean
		local profile = Data.Service:getProfile(player)
		local isFirstJoin = profile ~= nil and profile.SessionLoadCount == 1 and not data.starterItemsGranted()
		if data.newPlayerHatchStatus() == "Uninitialized" then
			data.newPlayerHatchStatus(if isFirstJoin then "Pending" else "Ineligible")
		end
		if data.starterItemsGranted() then
			return true
		end

		local function findStarter(itemId: string, excludeId: string?): string?
			local firstId: string? = nil
			for instanceId, item in data.inventory() :: SavedInventory do
				if instanceId ~= excludeId and typeof(item) == "table" and item.itemId == itemId
					and (not firstId or instanceId < firstId) then
					firstId = instanceId
				end
			end
			return firstId or self:grantItem(player, itemId, nil, true)
		end

		local tankId = findStarter("Tank.Small")
		local secondTankId = if isFirstJoin and tankId then findStarter("Tank.Small", tankId) else nil
		local incubatorId = findStarter("Incubator")
		if not tankId or (isFirstJoin and not secondTankId) or not incubatorId then
			return false
		end
		if isFirstJoin then
			for _, placement in { { secondTankId, "Right1" }, { tankId, "Right2" }, { incubatorId, "Right3" } } do
				local instanceId, slotId = placement[1], placement[2]
				local inventory = data.inventory() :: SavedInventory
				local item = inventory[instanceId]
				local occupied = false
				for otherId, other in inventory do
					if otherId ~= instanceId and typeof(other) == "table" and other.placedSlotId == slotId then
						occupied = true
						break
					end
				end
				if item and item.placedSlotId == nil and not occupied then
					local updated = table.clone(item)
					updated.placedSlotId = slotId
					data.inventory[instanceId](updated)
				end
			end
		end
		data.starterItemsGranted(true)
		normalizeHotbar(data, player)
		scheduleSync(player)
		return true
	end)
	preparingStarterItems[player] = nil
	if not succeeded then
		warn("Could not prepare starter items for", player.Name, result)
		return false
	end
	return result
end

local function removeLegacyStarterCrabs(player: Player, data: any)
	local prefix = `StarterBasicCrab:{player.UserId}:`
	local inventory = data.inventory() :: SavedInventory
	local removeIds = {}
	for instanceId, item in inventory do
		if string.sub(instanceId, 1, #prefix) == prefix
			and typeof(item) == "table" and item.itemId == "Crab.BasicCrab"
			and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil then
			table.insert(removeIds, instanceId)
		end
	end
	for _, instanceId in removeIds do
		data.inventory[instanceId](nil)
	end
end

local function setupPlayer(player: Player)
	sessionStartedAt[player] = os.clock()
	local function watchToolRemoval(container: Instance)
		container.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") and child:GetAttribute("ItemId") == InventoryConfig.hammerItemId then
				scheduleSync(player)
			end
		end)
	end
	player.CharacterAdded:Connect(function(character)
		watchToolRemoval(character)
		scheduleSync(player)
	end)
	player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			watchToolRemoval(child)
			scheduleSync(player)
		end
	end)
	if player.Character then
		watchToolRemoval(player.Character)
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watchToolRemoval(backpack)
	end
	task.spawn(function()
		local data = Data.Service:waitForData(player)
		if player.Parent ~= Players then
			return
		end
		InventoryServiceServer:prepareStarterItems(player, data)
		removeLegacyStarterCrabs(player, data)
		local sizeDiscoveries = table.clone(data.discoveredCrabSizes())
		local hasNewDiscovery = false
		for _, item in data.inventory() :: SavedInventory do
			if typeof(item) ~= "table" or typeof(item.itemId) ~= "string" or typeof(item.weightGrams) ~= "number" then
				continue
			end
			local crabId = string.match(item.itemId, "^Crab%.([%w_]+)$")
			if crabId and Crabs.get(crabId) and item.weightGrams >= 0.01 and item.weightGrams <= 10000000000 then
				local key = CrabSizeIndex.key(CrabSizeIndex.fromWeight(item.weightGrams), crabId)
				if sizeDiscoveries[key] ~= true then
					sizeDiscoveries[key] = true
					hasNewDiscovery = true
				end
			end
		end
		for crabId, wasDiscovered in data.discoveredCrabs() do
			if wasDiscovered ~= true or not Crabs.get(crabId) then
				continue
			end
			local hasKnownSize = false
			for _, sizeName in CrabSizeIndex.names do
				if sizeDiscoveries[CrabSizeIndex.key(sizeName, crabId)] == true then
					hasKnownSize = true
					break
				end
			end
			if not hasKnownSize then
				sizeDiscoveries[CrabSizeIndex.key("Base", crabId)] = true
				hasNewDiscovery = true
			end
		end
		if hasNewDiscovery then
			data.discoveredCrabSizes(sizeDiscoveries)
		end
		normalizeHotbar(data, player)
		readyPlayers[player] = true
		scheduleSync(player)
	end)
end

function InventoryServiceServer:init()
	if initialized then
		return
	end
	initialized = true

	networker = Networker.server.new("InventoryService", self, { self.setHotbarSlot, self.removeHotbarSlot, self.claimHatchedCrab })
	Data.Service:addPlayerRemovingCallback(function(player, savedData)
		local startedAt = sessionStartedAt[player]
		if startedAt and savedData.newPlayerHatchStatus == "Pending" then
			savedData.newPlayerPlaySeconds = math.min(
				NEW_PLAYER_BONUS_PLAY_SECONDS,
				(savedData.newPlayerPlaySeconds or 0) + math.max(0, os.clock() - startedAt)
			)
		end
	end)
	Players.PlayerAdded:Connect(setupPlayer)
	Players.PlayerRemoving:Connect(function(player)
		readyPlayers[player] = nil
		syncQueued[player] = nil
		task.defer(function()
			sessionStartedAt[player] = nil
		end)
	end)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

local function inventoryIsFull(inventory: SavedInventory, capacity: number): boolean
	local count = 0
	for _, item in inventory do
		if typeof(item) == "table" and typeof(item.itemId) == "string"
			and item.itemId ~= InventoryConfig.hammerItemId
			and item.placedSlotId == nil and item.incubatorInstanceId == nil and item.tankInstanceId == nil then
			count += 1
		end
	end
	return count >= capacity
end

function InventoryServiceServer:isFull(player: Player): boolean
	local data = Data[player]
	return data ~= nil and inventoryIsFull(data.inventory() :: SavedInventory, InventoryConfig.getCapacity(data.inventoryCapacityPurchases()))
end

function InventoryServiceServer:showInventoryFull(player: Player)
	if networker and player.Parent == Players then
		networker:fire(player, "showInventoryFull")
	end
end

function InventoryServiceServer:grantItem(player: Player, itemId: string, canGrant: (() -> boolean)?, allowPaidOverflow: boolean?, isGiganticEgg: boolean?): string?
	if itemId == InventoryConfig.hammerItemId or not ItemCatalog.get(itemId) or player.Parent ~= Players then
		return nil
	end

	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players or (canGrant and not canGrant()) then
		return nil
	end

	local inventory = data.inventory() :: SavedInventory
	if not allowPaidOverflow and inventoryIsFull(inventory, InventoryConfig.getCapacity(data.inventoryCapacityPurchases())) then
		return nil
	end

	local instanceId = HttpService:GenerateGUID(false)
	local isGiganticEggItem = string.match(itemId, "^Egg%.") ~= nil and isGiganticEgg == true
	data.inventory[instanceId]({ itemId = itemId, isGiganticEgg = if isGiganticEggItem then true else nil })
	if isHotbarEligible(itemId) then
		local hotbar = normalizeHotbar(data, player)
		local alreadyAssigned = false
		if ItemCatalog.isStackable(itemId) and not isGiganticEgg then
			local currentInventory = data.inventory() :: SavedInventory
			for _, assignedId in hotbar do
				local assignedItem = currentInventory[assignedId]
				if isStackable(assignedItem) and assignedItem.itemId == itemId then
					alreadyAssigned = true
					break
				end
			end
		end
		if not alreadyAssigned then
			for index = 1, InventoryConfig.hotbarSize do
				if hotbar[index] == InventoryConfig.emptySlot then
					local updated = table.clone(hotbar)
					updated[index] = instanceId
					data.hotbar(updated)
					break
				end
			end
		end
	end

	readyPlayers[player] = true
	scheduleSync(player)
	return instanceId
end

function InventoryServiceServer:equipGrantedItem(player: Player, instanceId: string): number?
	if player.Parent ~= Players then
		return nil
	end
	local data = Data[player]
	if not data then
		return nil
	end
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	local itemId = if item then item.itemId else nil
	if typeof(itemId) ~= "string" or not ItemCatalog.get(itemId) or not isAvailable(item) then
		return nil
	end

	local hotbar = normalizeHotbar(data, player)
	local equippedId: string? = nil
	local character = player.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				local currentId = child:GetAttribute("ItemInstanceId")
				if typeof(currentId) == "string" then
					equippedId = currentId
					break
				end
			end
		end
	end

	local targetId = instanceId
	local targetSlot: number? = nil
	for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
		local assignedId = hotbar[index]
		local assignedItem = inventory[assignedId]
		if assignedId == instanceId or (isStackable(item) and assignedItem and assignedItem.itemId == itemId) then
			targetId = assignedId
			targetSlot = index
			break
		end
	end
	if not targetSlot then
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if hotbar[index] == InventoryConfig.emptySlot then
				targetSlot = index
				break
			end
		end
		if not targetSlot then
			local heldSlot = if equippedId then table.find(hotbar, equippedId) else nil
			targetSlot = if heldSlot and heldSlot > InventoryConfig.hammerSlot then heldSlot else InventoryConfig.hotbarSize
		end
		local updated = table.clone(hotbar)
		updated[targetSlot :: number] = instanceId
		data.hotbar(updated)
	end

	readyPlayers[player] = true
	syncTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if backpack and character and humanoid and humanoid.Health > 0 and character == player.Character then
		local targetTool: Tool? = nil
		for _, container in { backpack, character } do
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemInstanceId") == targetId then
					targetTool = child
					break
				end
			end
			if targetTool then
				break
			end
		end
		if targetTool and targetTool.Parent == backpack then
			humanoid:EquipTool(targetTool)
		end
	end
	return targetSlot
end

function InventoryServiceServer:equipGrantedEgg(player: Player, instanceId: string): number?
	local data = Data[player]
	local inventory = if data then data.inventory() :: SavedInventory else nil
	local item = if inventory then inventory[instanceId] else nil
	local eggId = if item then string.match(item.itemId, "^Egg%.([%w_]+)$") else nil
	return if eggId and Eggs.get(eggId) then self:equipGrantedItem(player, instanceId) else nil
end

function InventoryServiceServer:setHotbarSlot(player: Player, instanceId: any, slotIndex: any)
	if typeof(instanceId) ~= "string" or typeof(slotIndex) ~= "number" then
		return
	end
	if slotIndex % 1 ~= 0 or slotIndex <= InventoryConfig.hammerSlot or slotIndex > InventoryConfig.hotbarSize then
		return
	end
	if player.Parent ~= Players then
		return
	end

	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players then
		return
	end
	readyPlayers[player] = true
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	if typeof(item) ~= "table" or typeof(item.itemId) ~= "string" or item.placedSlotId ~= nil or item.incubatorInstanceId ~= nil or item.tankInstanceId ~= nil or item.itemId == InventoryConfig.hammerItemId or not isHotbarEligible(item.itemId) then
		return
	end
	local hotbar = normalizeHotbar(data, player)
	if isStackable(item) then
		for _, assignedId in hotbar do
			local assignedItem = inventory[assignedId]
			if isStackable(assignedItem) and assignedItem.itemId == item.itemId then
				instanceId = assignedId
				break
			end
		end
	end
	local sourceIndex: number? = nil
	for index, assignedId in hotbar do
		if assignedId == instanceId then
			sourceIndex = index
			break
		end
	end
	if sourceIndex == slotIndex then
		return
	end

	local updated = table.clone(hotbar)
	if sourceIndex then
		updated[sourceIndex] = hotbar[slotIndex]
	end
	updated[slotIndex] = instanceId
	data.hotbar(updated)
	normalizeHotbar(data, player)
	scheduleSync(player)
end

function InventoryServiceServer:removeHotbarSlot(player: Player, instanceId: any)
	if typeof(instanceId) ~= "string" or player.Parent ~= Players then
		return
	end

	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players then
		return
	end
	readyPlayers[player] = true
	local inventory = data.inventory() :: SavedInventory
	if not inventory[instanceId] or inventory[instanceId].itemId == InventoryConfig.hammerItemId then
		return
	end

	local hotbar = normalizeHotbar(data, player)
	for index, assignedId in hotbar do
		if assignedId == instanceId then
			local updated = table.clone(hotbar)
			updated[index] = InventoryConfig.emptySlot
			data.hotbar(updated)
			scheduleSync(player)
			return
		end
	end
end

function InventoryServiceServer:startIncubation(player: Player, incubatorInstanceId: string): (string?, string?, number?)
	if not readyPlayers[player] or player.Parent ~= Players then
		return nil, nil, nil
	end
	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local incubatorItem = inventory[incubatorInstanceId]
	local incubatorId = if typeof(incubatorItem) == "table" and incubatorItem.itemId == "Incubator" then "Incubator"
		elseif typeof(incubatorItem) == "table" then string.match(incubatorItem.itemId, "^Incubator%.([%w_]+)$") else nil
	local incubatorDefinition = if incubatorId then Incubators.get(incubatorId) else nil
	if typeof(incubatorItem) ~= "table" or not incubatorDefinition
		or typeof(incubatorItem.placedSlotId) ~= "string" then
		return nil, nil, nil
	end
	for _, item in inventory do
		if typeof(item) == "table" and item.incubatorInstanceId == incubatorInstanceId then
			return nil, nil, nil
		end
	end
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local hotbar = data.hotbar() :: { string }
	for _, child in character:GetChildren() do
		if not child:IsA("Tool") then
			continue
		end
		local instanceId = child:GetAttribute("ItemInstanceId")
		local itemId = child:GetAttribute("ItemId")
		if typeof(instanceId) ~= "string" or typeof(itemId) ~= "string" then
			continue
		end
		local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
		local item = inventory[instanceId]
		if not eggId or not Eggs.get(eggId) or typeof(item) ~= "table" or item.itemId ~= itemId
			or item.placedSlotId ~= nil or item.incubatorInstanceId ~= nil or item.tankInstanceId ~= nil
			or table.find(hotbar, instanceId) == nil then
			continue
		end
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local eggs = if assets then assets:FindFirstChild("Eggs") else nil
		local template = if eggs then eggs:FindFirstChild(eggId) else nil
		local crabId = if template then template:GetAttribute("CrabId") else nil
		local crabDefinition = if typeof(crabId) == "string" then Crabs.get(crabId) else nil
		if not crabDefinition then
			return nil, nil, nil
		end
		local crabs = if assets then assets:FindFirstChild("Crabs") else nil
		local crabTemplate = if crabs then crabs:FindFirstChild(crabId) else nil
		if not crabTemplate or not crabTemplate:IsA("Model") then
			return nil, nil, nil
		end

		local hatchDurationMs = Incubators.getHatchDurationMs(incubatorId :: string, eggId, crabDefinition.rarity)
		if not hatchDurationMs then
			return nil, nil, nil
		end
		local hatchAtUnixMs = DateTime.now().UnixTimestampMillis + hatchDurationMs
		local updated = table.clone(item)
		updated.incubatorInstanceId = incubatorInstanceId
		updated.hatchAtUnixMs = hatchAtUnixMs
		data.inventory[instanceId](updated)
		child:Destroy()
		scheduleSync(player)
		return instanceId, eggId, hatchAtUnixMs
	end
	return nil, nil, nil
end

function InventoryServiceServer:completeIncubation(player: Player, eggInstanceId: string, incubatorInstanceId: string, hatchAtUnixMs: number, receiptConfirmed: boolean?): (boolean, string?, number?)
	if player.Parent ~= Players or (not receiptConfirmed and DateTime.now().UnixTimestampMillis < hatchAtUnixMs) then
		return false, nil, nil
	end
	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[eggInstanceId]
	if typeof(item) ~= "table" or item.incubatorInstanceId ~= incubatorInstanceId
		or item.hatchAtUnixMs ~= hatchAtUnixMs then
		return false, nil, nil
	end
	local eggId = string.match(item.itemId, "^Egg%.([%w_]+)$")
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local eggs = if assets then assets:FindFirstChild("Eggs") else nil
	local template = if eggId and eggs then eggs:FindFirstChild(eggId) else nil
	local crabId = if template then template:GetAttribute("CrabId") else nil
	local crabDefinition = if typeof(crabId) == "string" then Crabs.get(crabId) else nil
	local crabs = if assets then assets:FindFirstChild("Crabs") else nil
	local crabTemplate = if crabDefinition and crabs then crabs:FindFirstChild(crabDefinition.modelName) else nil
	if not crabTemplate or not crabTemplate:IsA("Model") then
		warn("Cannot hatch egg without a valid crab model:", item.itemId)
		local recovered = table.clone(item)
		recovered.incubatorInstanceId = nil
		recovered.hatchAtUnixMs = nil
		data.inventory[eggInstanceId](recovered)
		scheduleSync(player)
		return true, nil, nil
	end
	local updated = table.clone(item)
	updated.itemId = "Crab." .. crabId
	local giganticMultiplier = if item.isGiganticEgg == true then GiganticEggConfig.GROWTH_LUCK_MULTIPLIER else 1
	local weightGrams = CrabWeights.roll(IndexMilestones.growthLuck(data.claimedIndexMilestones(), data.starterPackClaimed()) * giganticMultiplier * ServerLuck.getMultiplier())
	local startedAt = sessionStartedAt[player]
	local bonusReady = data.newPlayerHatchStatus() == "Pending" and startedAt ~= nil
		and data.newPlayerPlaySeconds() + math.max(0, os.clock() - startedAt) >= NEW_PLAYER_BONUS_PLAY_SECONDS
	local isGiganticEgg = item.isGiganticEgg == true
	if bonusReady and not isGiganticEgg then
		weightGrams = bonusWeightRandom:NextInteger(NEW_PLAYER_BONUS_MIN_WEIGHT_HUNDREDTHS, NEW_PLAYER_BONUS_MAX_WEIGHT_HUNDREDTHS) / 100
	end
	if isGiganticEgg then
		weightGrams = math.max(weightGrams, GIGANTIC_EGG_MIN_WEIGHT_GRAMS)
	end
	updated.weightGrams = weightGrams
	updated.hatchedEggId = eggId
	updated.hatchAtUnixMs = nil
	data.inventory[eggInstanceId](updated)
	data.biggestCrabGrams(function(previous: number)
		return math.max(previous, weightGrams)
	end)
	if bonusReady and not isGiganticEgg then
		data.newPlayerHatchStatus("Claimed")
	end
	local sizeName = CrabSizeIndex.fromWeight(weightGrams)
	if data.discoveredCrabs()[crabId] ~= true then
		data.discoveredCrabs[crabId](true)
	end
	local sizeKey = CrabSizeIndex.key(sizeName, crabId)
	if data.discoveredCrabSizes()[sizeKey] ~= true then
		data.discoveredCrabSizes[sizeKey](true)
	end
	normalizeHotbar(data, player)
	scheduleSync(player)
	return true, crabId, weightGrams
end

function InventoryServiceServer:grantRollAgainReceipt(player: Player, purchaseId: string): (string?, string?, string?, number?)
	local data = Data[player]
	if not data then
		return nil, nil, nil, nil
	end
	local receiptValue = data.processedProductReceipts()[purchaseId]
	local instanceId: string
	local weightGrams: number
	if receiptValue then
		local savedInstanceId, savedHundredths = string.match(receiptValue, "^RollAgain:([^:]+):(%d+)$")
		local parsedWeight = if savedHundredths then tonumber(savedHundredths) else nil
		if not savedInstanceId or not parsedWeight then
			return nil, nil, nil, nil
		end
		instanceId = savedInstanceId
		weightGrams = parsedWeight / 100
	else
		instanceId = data.pendingRollAgainInstanceId()
		local pendingItem = (data.inventory() :: SavedInventory)[instanceId]
		local pendingCrabId = if typeof(pendingItem) == "table" and typeof(pendingItem.itemId) == "string"
			then string.match(pendingItem.itemId, "^Crab%.([%w_]+)$") else nil
		if not pendingCrabId or not Crabs.get(pendingCrabId) then
			return nil, nil, nil, nil
		end
		local giganticMultiplier = if pendingItem.isGiganticEgg == true then GiganticEggConfig.GROWTH_LUCK_MULTIPLIER else 1
		weightGrams = CrabWeights.roll(IndexMilestones.growthLuck(data.claimedIndexMilestones(), data.starterPackClaimed()) * giganticMultiplier * ServerLuck.getMultiplier())
		if pendingItem.isGiganticEgg == true then
			weightGrams = math.max(weightGrams, GIGANTIC_EGG_MIN_WEIGHT_GRAMS)
		end
		receiptValue = `RollAgain:{instanceId}:{math.round(weightGrams * 100)}`
		data.processedProductReceipts[purchaseId](receiptValue)
		data.pendingRollAgainInstanceId("")
	end
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	local crabId = if typeof(item) == "table" then string.match(item.itemId, "^Crab%.([%w_]+)$") else nil
	if crabId and Crabs.get(crabId) then
		if item.weightGrams ~= weightGrams then
			local updated = table.clone(item)
			updated.weightGrams = weightGrams
			data.inventory[instanceId](updated)
		end
		data.biggestCrabGrams(function(previous: number)
			return math.max(previous, weightGrams)
		end)
		local sizeKey = CrabSizeIndex.key(CrabSizeIndex.fromWeight(weightGrams), crabId)
		if data.discoveredCrabSizes()[sizeKey] ~= true then
			data.discoveredCrabSizes[sizeKey](true)
		end
		scheduleSync(player)
	end
	return receiptValue, instanceId, crabId, weightGrams
end

function InventoryServiceServer:claimHatchedCrab(player: Player, instanceId: any)
	if typeof(instanceId) ~= "string" or #instanceId > 64 or player.Parent ~= Players then
		return
	end
	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	if typeof(item) ~= "table" or not string.match(item.itemId, "^Crab%.[%w_]+$")
		or item.incubatorInstanceId == nil or item.hatchAtUnixMs ~= nil then
		return
	end
	if inventoryIsFull(inventory, InventoryConfig.getCapacity(data.inventoryCapacityPurchases())) then
		self:showInventoryFull(player)
		return
	end
	local updated = table.clone(item)
	updated.incubatorInstanceId = nil
	data.inventory[instanceId](updated)
	TutorialServiceServer:crabClaimed(player, instanceId)
	local hotbar = normalizeHotbar(data, player)
	local targetSlot = table.find(hotbar, instanceId)
	if not targetSlot then
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if hotbar[index] == InventoryConfig.emptySlot then
				targetSlot = index
				break
			end
		end
	end
	if not targetSlot then
		local heldId: string? = nil
		local character = player.Character
		if character then
			for _, child in character:GetChildren() do
				if child:IsA("Tool") then
					local currentId = child:GetAttribute("ItemInstanceId")
					if typeof(currentId) == "string" then
						heldId = currentId
						break
					end
				end
			end
		end
		local heldSlot = if heldId then table.find(hotbar, heldId) else nil
		targetSlot = if heldSlot and heldSlot > InventoryConfig.hammerSlot then heldSlot else InventoryConfig.hotbarSize
	end
	if hotbar[targetSlot :: number] ~= instanceId then
		local updatedHotbar = table.clone(hotbar)
		updatedHotbar[targetSlot :: number] = instanceId
		data.hotbar(updatedHotbar)
	end
	scheduleSync(player)
end

function InventoryServiceServer:repairIncubations(player: Player, active: { [string]: string })
	local data = Data[player]
	local inventory = data.inventory() :: SavedInventory
	local repaired = {}
	for instanceId, item in inventory do
		if typeof(item) == "table" and item.incubatorInstanceId ~= nil
			and (active[item.incubatorInstanceId] ~= instanceId
				or string.match(item.itemId, "^Egg%.([%w_]+)$") == nil
				or typeof(item.hatchAtUnixMs) ~= "number") then
			local updated = table.clone(item)
			updated.incubatorInstanceId = nil
			updated.hatchAtUnixMs = nil
			data.inventory[instanceId](updated)
			table.insert(repaired, instanceId)
		end
	end
	if #repaired == 0 then
		return
	end
	table.sort(repaired)
	local hotbar = normalizeHotbar(data, player)
	local updatedHotbar = table.clone(hotbar)
	for _, instanceId in repaired do
		for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
			if updatedHotbar[index] == InventoryConfig.emptySlot then
				updatedHotbar[index] = instanceId
				break
			end
		end
	end
	data.hotbar(updatedHotbar)
	scheduleSync(player)
end

function InventoryServiceServer:refreshTools(player: Player)
	if not readyPlayers[player] or player.Parent ~= Players then
		return
	end
	normalizeHotbar(Data[player], player)
	scheduleSync(player)
end

function InventoryServiceServer:getHotbarSlot(player: Player, instanceId: string): number?
	local data = Data[player]
	if not data then
		return nil
	end
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	if not item then
		return nil
	end
	local hotbar = normalizeHotbar(data, player)
	local directSlot = table.find(hotbar, instanceId)
	if directSlot then
		return directSlot
	end
	if isStackable(item) then
		for index, assignedId in hotbar do
			local assignedItem = inventory[assignedId]
			if isStackable(assignedItem) and assignedItem.itemId == item.itemId then
				return index
			end
		end
	end
	return nil
end
return InventoryServiceServer
