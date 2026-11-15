--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local EggConveyorServiceServer = require(ServerScriptService.Features.EggConveyor.EggConveyorServiceServer)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServer = require(script.Parent.Classes.PlotServer)
local PlotExtraSlots = require(ReplicatedStorage.Source.Features.Plots.Modules.PlotExtraSlots)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local Incubators = require(ReplicatedStorage.Source.Features.Incubators.Modules.Incubators)

type SavedItem = { itemId: string, placedSlotId: string?, incubatorInstanceId: string?, tankInstanceId: string? }
type SavedInventory = { [string]: SavedItem }

local MAX_INTERACTION_DISTANCE = 10

local PlotServiceServer = {}
local initialized = false
local plots: { [number]: PlotServer.PlotServer } = {}
local playerPlots: { [Player]: PlotServer.PlotServer } = {}
local waiting: { Player } = {}
local waitingSet: { [Player]: boolean } = {}
local assigningWaiting = false
local lastTravel: { [Player]: number } = {}
local buyingExtraSlot: { [Player]: boolean } = {}
local networker = nil

local function addStarterPackLabel(egg: Model)
	local body = egg:FindFirstChild("Body", true)
	if not body or not body:IsA("BasePart") then
		return
	end

	local existing = body:FindFirstChild("StarterPackLabel") or body:FindFirstChild("LikeRewardsLabel")
	local billboard = if existing and existing:IsA("BillboardGui") then existing else Instance.new("BillboardGui")
	billboard.Name = "StarterPackLabel"
	billboard.Size = UDim2.fromScale(7, 1.5)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 120

	local title = billboard:FindFirstChild("Title")
	local text = if title and title:IsA("TextLabel") then title else Instance.new("TextLabel")
	text.Name = "Title"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "Starter Pack"
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.TextStrokeTransparency = 0
	text.TextScaled = true
	text.Font = Enum.Font.GothamBlack
	text.Parent = billboard

	local outline = text:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = 2
	outline.Parent = text
	billboard.Parent = body
end

local function prepareStarterPack(plotTemplate: Model)
	local reward = plotTemplate:FindFirstChild("Like Reward", true)
	if not reward or not reward:IsA("Model") then
		return
	end

	local crate = reward:FindFirstChild("MysteryCrate")
	if not crate or not crate:IsA("Model") then
		local existingEgg = reward:FindFirstChild("RewardEgg")
		if existingEgg and existingEgg:IsA("Model") then
			addStarterPackLabel(existingEgg)
		end
		return
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local eggs = if assets then assets:FindFirstChild("Eggs") else nil
	local basicEgg = if eggs then eggs:FindFirstChild("BasicEgg") else nil
	if not basicEgg or not basicEgg:IsA("Model") then
		warn("Cannot prepare starter pack egg: Assets.Eggs.BasicEgg is missing")
		return
	end

	local egg = basicEgg:Clone()
	egg.Name = "RewardEgg"
	egg:ScaleTo(1.4)
	local crateBox, crateSize = crate:GetBoundingBox()
	local eggBox, eggSize = egg:GetBoundingBox()
	local eggCenter = Vector3.new(crateBox.Position.X, crateBox.Position.Y - crateSize.Y / 2 + eggSize.Y / 2, crateBox.Position.Z)
	egg:PivotTo(egg:GetPivot() + (eggCenter - eggBox.Position))

	local body = egg:FindFirstChild("Body", true)
	if body and body:IsA("BasePart") then
		local stars = Instance.new("ParticleEmitter")
		stars.Name = "RewardStars"
		stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		stars.Color = ColorSequence.new(Color3.fromRGB(255, 234, 124))
		stars.LightEmission = 0.75
		stars.Rate = 4
		stars.Lifetime = NumberRange.new(0.6, 1)
		stars.Speed = NumberRange.new(0.3, 0.7)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.22),
			NumberSequenceKeypoint.new(1, 0),
		})
		stars.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		stars.Parent = body
	end

	egg.Parent = reward
	crate:Destroy()
	addStarterPackLabel(egg)
end

local function getIncubatorId(itemId: string): string?
	local incubatorId = if itemId == "Incubator" then "Incubator" else string.match(itemId, "^Incubator%.([%w_]+)$")
	return if incubatorId and Incubators.get(incubatorId) then incubatorId else nil
end

local function getTemplate(itemId: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end
	local folder: Instance?
	local modelName: string?
	local incubatorId = getIncubatorId(itemId)
	if incubatorId then
		folder = assets:FindFirstChild("Incubators")
		local definition = Incubators.get(incubatorId)
		modelName = if definition then definition.modelName else nil
	else
		local tankId = string.match(itemId, "^Tank%.([%w_]+)$")
		local definition = if tankId then Tanks.get(tankId) else nil
		if definition then
			folder = assets:FindFirstChild("Tanks")
			modelName = definition.modelName
		end
	end
	local template = if folder and modelName then folder:FindFirstChild(modelName) else nil
	return if template and template:IsA("Model") and template.PrimaryPart then template else nil
end

local function makePlacedModel(itemId: string, instanceId: string, slot: BasePart): Model?
	local template = getTemplate(itemId)
	if not template then
		return nil
	end
	local model = template:Clone()
	local boxCFrame, boxSize = model:GetBoundingBox()
	if boxSize.Y <= 0 then
		model:Destroy()
		return nil
	end
	local pivotToBottom = model:GetPivot().Position.Y - (boxCFrame.Position.Y - boxSize.Y / 2)
	model:PivotTo(slot.CFrame * CFrame.new(0, slot.Size.Y / 2 + pivotToBottom, 0))
	model.Name = itemId .. "_" .. instanceId
	model:SetAttribute("ItemInstanceId", instanceId)
	model:SetAttribute("ItemId", itemId)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
	return model
end

local function inRange(player: Player, slot: BasePart): boolean
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	return root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - slot.Position).Magnitude <= MAX_INTERACTION_DISTANCE
end

local function equippedTool(player: Player, instanceId: string, itemId: string): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ItemInstanceId") == instanceId and child:GetAttribute("ItemId") == itemId then
			return child
		end
	end
	return nil
end

local function clearPlacement(data: any, instanceId: string, item: SavedItem)
	local updated = table.clone(item)
	updated.placedSlotId = nil
	data.inventory[instanceId](updated)
end

local function restorePlayer(player: Player, plot: PlotServer.PlotServer, data: any)
	if player.Parent ~= Players or playerPlots[player] ~= plot or plot:getOwner() ~= player then
		return
	end
	if not InventoryServiceServer:prepareStarterItems(player, data) then
		warn("Could not prepare starter items before restoring plot for", player.Name)
		return
	end
	if player.Parent ~= Players or playerPlots[player] ~= plot or plot:getOwner() ~= player then
		return
	end
	if not plot:unlockThrough(PlotExtraSlots.normalizeCount(data.extraSlotsPurchased())) then
		warn("Could not restore extra slots for", player.Name)
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local instanceIds: { string } = {}
	for instanceId, item in inventory do
		if typeof(item) == "table" and typeof(item.placedSlotId) == "string" then
			table.insert(instanceIds, instanceId)
		end
	end
	table.sort(instanceIds)

	local repaired = false
	for _, instanceId in instanceIds do
		if player.Parent ~= Players or playerPlots[player] ~= plot or plot:getOwner() ~= player then
			return
		end
		local item = inventory[instanceId]
		local slotId = item.placedSlotId
		local slot = if slotId then plot:getSlot(slotId) else nil
		if not slot or plot:getPlaced(slotId :: string) then
			clearPlacement(data, instanceId, item)
			repaired = true
			continue
		end
		local model = makePlacedModel(item.itemId, instanceId, slot)
		if not model or not plot:addPlaced(slotId :: string, model) then
			if model then
				model:Destroy()
			end
			clearPlacement(data, instanceId, item)
			repaired = true
		elseif getIncubatorId(item.itemId) then
			if not IncubatorServiceServer:registerPlaced(player, plot.model, model, instanceId) then
				plot:removePlaced(slotId :: string)
				clearPlacement(data, instanceId, item)
				repaired = true
			end
		elseif string.match(item.itemId, "^Tank%.([%w_]+)$") then
			if not TankServiceServer:registerPlaced(player, plot.model, model, instanceId) then
				plot:removePlaced(slotId :: string)
				clearPlacement(data, instanceId, item)
				repaired = true
			end
		end
	end
	local active: { [string]: string } = {}
	for _, model in plot.placedModels do
		local modelItemId = model:GetAttribute("ItemId")
		if typeof(modelItemId) == "string" and getIncubatorId(modelItemId) then
			local incubatorId = model:GetAttribute("ItemInstanceId")
			local eggId = IncubatorServiceServer:getPlacedEggId(model)
			if typeof(incubatorId) == "string" and eggId then
				active[incubatorId] = eggId
			end
		end
	end
	InventoryServiceServer:repairIncubations(player, active)
	TankServiceServer:restoreContents(player)
	if repaired then
		InventoryServiceServer:refreshTools(player)
	end
end

local function assignWaiting()
	if assigningWaiting then
		return
	end
	assigningWaiting = true
	task.spawn(function()
		while #waiting > 0 do
			local freePlot: PlotServer.PlotServer? = nil
			for index = 1, 6 do
				local plot = plots[index]
				if plot and not plot:getOwner() then
					freePlot = plot
					break
				end
			end
			if not freePlot then
				break
			end

			local player = waiting[1]
			local data = if player.Parent == Players then Data.Service:waitForData(player) else nil
			if not waitingSet[player] or player.Parent ~= Players then
				local position = table.find(waiting, player)
				if position then
					table.remove(waiting, position)
				end
				waitingSet[player] = nil
				continue
			end
			if not data then
				warn("Could not load player data before assigning a plot for", player.Name)
				table.remove(waiting, 1)
				waitingSet[player] = nil
				continue
			end

			table.remove(waiting, 1)
			waitingSet[player] = nil
			if not playerPlots[player] and freePlot:claim(player) then
				playerPlots[player] = freePlot
				task.spawn(restorePlayer, player, freePlot, data)
			end
		end
		assigningWaiting = false
	end)
end

local function playerAdded(player: Player)
	if playerPlots[player] or waitingSet[player] then
		return
	end
	table.insert(waiting, player)
	waitingSet[player] = true
	assignWaiting()
end

local function playerRemoving(player: Player)
	lastTravel[player] = nil
	buyingExtraSlot[player] = nil
	if waitingSet[player] then
		local position = table.find(waiting, player)
		if position then
			table.remove(waiting, position)
		end
		waitingSet[player] = nil
	end

	local plot = playerPlots[player]
	if plot then
		playerPlots[player] = nil
		EggConveyorServiceServer:stop(plot.model)
		TankServiceServer:clearPlacedForPlayer(player)
		IncubatorServiceServer:clearPlacedForPlayer(player)
		plot:release()
		assignWaiting()
	end
end

function PlotServiceServer:init()
	if initialized then
		return
	end

	local template = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Plot") :: Model
	prepareStarterPack(template)
	local folder = Workspace:FindFirstChild("SpawnedPlots")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "SpawnedPlots"
		folder.Parent = Workspace
	end
	if not folder:IsA("Folder") then
		warn("SpawnedPlots must be a Folder")
		return
	end

	for _, tagged in CollectionService:GetTagged("PlotSpawn") do
		if not tagged:IsA("BasePart") then
			warn("Skipping PlotSpawn that is not a BasePart")
			continue
		end
		local index = tagged:GetAttribute("Index")
		if type(index) ~= "number" or index % 1 ~= 0 or index < 1 or index > 6 then
			warn("Skipping PlotSpawn with invalid Index")
			continue
		end
		if plots[index] then
			warn("Skipping duplicate PlotSpawn Index", index)
			continue
		end
		local plot = PlotServer.new(index, tagged, template, folder)
		if plot then
			plots[index] = plot
		end
	end
	for index = 1, 6 do
		if not plots[index] then
			warn("Missing PlotSpawn Index", index)
		end
	end

	networker = Networker.server.new("PlotPlacement", self, { self.place, self.pickup, self.travel, self.buyExtraSlot })
	initialized = true
	Players.PlayerAdded:Connect(playerAdded)
	Players.PlayerRemoving:Connect(playerRemoving)
	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end
end

function PlotServiceServer:getPlot(player: Player): PlotServer.PlotServer?
	return playerPlots[player]
end

function PlotServiceServer:buyExtraSlot(player: Player)
	if buyingExtraSlot[player] or player.Parent ~= Players then
		return
	end
	buyingExtraSlot[player] = true
	local ok, err = pcall(function()
		local data = Data.Service:waitForData(player)
		local plot = playerPlots[player]
		if not data or player.Parent ~= Players or not plot or plot:getOwner() ~= player then
			return
		end
		local sign = plot.model:FindFirstChild("ExtraSlotSign")
		local panel = if sign then sign:FindFirstChild("FrontPanel") else nil
		if not panel or not panel:IsA("BasePart") then
			return
		end
		local count = PlotExtraSlots.normalizeCount(data.extraSlotsPurchased())
		if not plot:unlockThrough(count) then
			return
		end
		local price = PlotExtraSlots.getPrice(count)
		local money = data.money()
		if not price or typeof(money) ~= "number" or money ~= money or money < price then
			return
		end
		if not plot:unlockNextSlot() then
			return
		end
		data.money(money - price)
		data.extraSlotsPurchased(count + 1)
	end)
	buyingExtraSlot[player] = nil
	if not ok then
		warn("Extra slot purchase failed for", player.Name, err)
	end
end

function PlotServiceServer:travel(player: Player, destination: any)
	if destination ~= "Home" and destination ~= "Shop" then
		return
	end
	local plot = playerPlots[player]
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not plot or plot:getOwner() ~= player or not character or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") then
		return
	end
	local tutorialShop = destination == "Shop" and TutorialServiceServer:canVisitShop(player)
	local now = os.clock()
	if now - (lastTravel[player] or -math.huge) < 1 then
		return
	end
	if destination == "Home" then
		lastTravel[player] = now
		plot:teleportCharacter(player, character)
		return
	end

	local stand = Workspace:FindFirstChild("ShopStand")
	local noob = if stand then stand:FindFirstChild("Noob") else nil
	local torso = if noob then noob:FindFirstChild("Torso") else nil
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local front = torso.Position + torso.CFrame.LookVector * 5
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(front + Vector3.new(0, 10, 0), Vector3.new(0, -50, 0), rayParams)
	if not hit or hit.Normal.Y < 0.7 then
		return
	end
	lastTravel[player] = now
	local target = hit.Position + Vector3.new(0, 3.5, 0)
	character:PivotTo(CFrame.lookAt(target, Vector3.new(torso.Position.X, target.Y, torso.Position.Z)))
	if tutorialShop then
		TutorialServiceServer:visitedShop(player)
	end
end
function PlotServiceServer:place(player: Player, instanceId: any, slotId: any)
	if typeof(instanceId) ~= "string" or typeof(slotId) ~= "string" then
		return
	end
	local plot = playerPlots[player]
	local slot = if plot then plot:getSlot(slotId) else nil
	if not plot or plot:getOwner() ~= player or not slot or plot:getPlaced(slotId) or not inRange(player, slot) then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local item = inventory[instanceId]
	if typeof(item) ~= "table" or typeof(item.itemId) ~= "string" or item.placedSlotId ~= nil
		or item.incubatorInstanceId ~= nil or item.tankInstanceId ~= nil then
		return
	end
	if not equippedTool(player, instanceId, item.itemId) then
		return
	end
	for _, other in inventory do
		if typeof(other) == "table" and other.placedSlotId == slotId then
			return
		end
	end

	local model = makePlacedModel(item.itemId, instanceId, slot)
	if not model then
		return
	end
	if not plot:addPlaced(slotId, model) then
		model:Destroy()
		return
	end
	local tankId = string.match(item.itemId, "^Tank%.([%w_]+)$")
	if tankId and not TankServiceServer:registerPlaced(player, plot.model, model, instanceId) then
		plot:removePlaced(slotId)
		return
	end

	local updatedItem = table.clone(item)
	updatedItem.placedSlotId = slotId
	data.inventory[instanceId](updatedItem)
	if getIncubatorId(item.itemId) then
		IncubatorServiceServer:registerPlaced(player, plot.model, model, instanceId)
	end
	InventoryServiceServer:refreshTools(player)
end

function PlotServiceServer:pickup(player: Player, slotId: any)
	if typeof(slotId) ~= "string" then
		return
	end
	local plot = playerPlots[player]
	local slot = if plot then plot:getSlot(slotId) else nil
	local model = if plot then plot:getPlaced(slotId) else nil
	if not plot or plot:getOwner() ~= player or not slot or not model or not inRange(player, slot) then
		return
	end
	local instanceId = model:GetAttribute("ItemInstanceId")
	if typeof(instanceId) ~= "string" then
		return
	end
	local data = Data[player]
	if not data then
		return
	end
	local inventory = data.inventory() :: SavedInventory
	local hammerId = InventoryConfig.hammerInstanceId(player.UserId)
	local hammer = inventory[hammerId]
	local hotbar = data.hotbar() :: { string }
	if not hammer or hammer.itemId ~= InventoryConfig.hammerItemId
		or hotbar[InventoryConfig.hammerSlot] ~= hammerId
		or not equippedTool(player, hammerId, InventoryConfig.hammerItemId) then
		return
	end
	local item = inventory[instanceId]
	if typeof(item) ~= "table" or item.placedSlotId ~= slotId then
		return
	end
	local isTank = string.match(item.itemId, "^Tank%.([%w_]+)$") ~= nil
	if isTank and TankServiceServer:isOccupied(model) then
		if (model:GetAttribute("ContainedCrabCount") or 0) == 0 and networker then
			networker:fire(player, "pickupBlocked", "decorations")
		end
		return
	end
	if InventoryServiceServer:isFull(player) then
		InventoryServiceServer:showInventoryFull(player)
		return
	end
	if getIncubatorId(item.itemId) then
		if IncubatorServiceServer:isOccupied(model) then
			return
		end
		for _, other in inventory do
			if typeof(other) == "table" and other.incubatorInstanceId == instanceId then
				return
			end
		end
		IncubatorServiceServer:unregisterPlaced(model)
	end
	if isTank then
		for _, other in inventory do
			if typeof(other) == "table" and other.tankInstanceId == instanceId then
				return
			end
		end
		TankServiceServer:unregisterPlaced(model)
	end

	clearPlacement(data, instanceId, item)
	plot:removePlaced(slotId)
	for index = InventoryConfig.hammerSlot + 1, InventoryConfig.hotbarSize do
		if hotbar[index] == InventoryConfig.emptySlot then
			local updatedHotbar = table.clone(hotbar)
			updatedHotbar[index] = instanceId
			data.hotbar(updatedHotbar)
			break
		end
	end
	InventoryServiceServer:refreshTools(player)
end

return PlotServiceServer
