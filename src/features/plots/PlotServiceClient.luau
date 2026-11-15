--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local InventoryConfig = require(ReplicatedStorage.Source.Features.Inventory.InventoryConfig)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotClient = require(script.Parent.Classes.PlotClient)
local Tanks = require(ReplicatedStorage.Source.Features.Tanks.Modules.Tanks)
local Incubators = require(ReplicatedStorage.Source.Features.Incubators.Modules.Incubators)
local TankServiceClient = require(ReplicatedStorage.Source.Features.Tanks.TankServiceClient)
local ExtraSlotSign = require(script.Parent.UI.ExtraSlotSign)
local TravelBar = require(script.Parent.UI.TravelBar)

local MAX_INTERACTION_DISTANCE = 10

local PlotServiceClient = {}
local initialized = false
local plots: { [number]: PlotClient.PlotClient } = {}
local indicators: { [string]: Model } = {}
local indicatorFolder: Folder? = nil
local activePlot: PlotClient.PlotClient? = nil
local prompt: ProximityPrompt? = nil
local promptSlotId: string? = nil
local promptMode: string? = nil
local sendPlace: ((string, string) -> ())? = nil
local sendPickup: ((string) -> ())? = nil
local sendTravel: ((string) -> ())? = nil
local mountedSigns: { [Model]: () -> () } = {}

local function isIncubatorItem(itemId: string): boolean
	local incubatorId = if itemId == "Incubator" then "Incubator" else string.match(itemId, "^Incubator%.([%w_]+)$")
	return incubatorId ~= nil and Incubators.get(incubatorId) ~= nil
end

local function addPlot(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local index = instance:GetAttribute("Index")
	if type(index) ~= "number" then
		return
	end
	local existing = plots[index]
	if existing then
		if existing.model == instance then
			return
		end
		existing:destroy()
	end
	plots[index] = PlotClient.new(instance)
end

local function removePlot(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local index = instance:GetAttribute("Index")
	if type(index) ~= "number" then
		return
	end
	local plot = plots[index]
	if plot and plot.model == instance then
		plot:destroy()
		plots[index] = nil
	end
end

local function getLocalPlot(): PlotClient.PlotClient?
	for _, plot in plots do
		if plot:isLocal() then
			return plot
		end
	end
	return nil
end

local function getEquippedItem(): (string?, string?)
	local character = Players.LocalPlayer.Character
	if not character then
		return nil, nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local instanceId = child:GetAttribute("ItemInstanceId")
			local itemId = child:GetAttribute("ItemId")
			local tankId = if typeof(itemId) == "string" then string.match(itemId, "^Tank%.([%w_]+)$") else nil
			if typeof(instanceId) == "string" and typeof(itemId) == "string"
				and (isIncubatorItem(itemId) or (tankId ~= nil and Tanks.get(tankId) ~= nil)) then
				return instanceId, itemId
			end
		end
	end
	return nil, nil
end

local function isHammerEquipped(): boolean
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

local function isEggEquipped(): boolean
	local character = Players.LocalPlayer.Character
	if not character then
		return false
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local itemId = child:GetAttribute("ItemId")
			local eggId = if typeof(itemId) == "string" then string.match(itemId, "^Egg%.([%w_]+)$") else nil
			if eggId and Eggs.get(eggId) and typeof(child:GetAttribute("ItemInstanceId")) == "string" then
				return true
			end
		end
	end
	return false
end

local function updateEggPrompts()
	local eggEquipped = isEggEquipped()
	for _, plot in plots do
		local placedItems = plot.model:FindFirstChild("PlacedItems")
		if not placedItems then
			continue
		end
		for _, model in placedItems:GetChildren() do
			local itemId = model:GetAttribute("ItemId")
			if model:IsA("Model") and typeof(itemId) == "string" and isIncubatorItem(itemId) then
				local eggPrompt = model:FindFirstChild("PlaceEggPrompt", true)
				if eggPrompt and eggPrompt:IsA("ProximityPrompt") then
					eggPrompt.Enabled = plot:isLocal() and eggEquipped and model:GetAttribute("IncubatingEggId") == nil
				end
			end
		end
	end
end

local function addDash(parent: Model, cframe: CFrame, size: Vector3)
	local dash = Instance.new("Part")
	dash.Name = "Dash"
	dash.Size = size
	dash.CFrame = cframe
	dash.Anchored = true
	dash.CanCollide = false
	dash.CanTouch = false
	dash.CanQuery = false
	dash.CastShadow = false
	dash.Material = Enum.Material.Neon
	dash.Color = Color3.new(1, 1, 1)
	dash.Parent = parent
end

local function makeOutline(slot: BasePart): Model
	local outline = Instance.new("Model")
	outline.Name = slot.Name .. "_Outline"
	local halfX = slot.Size.X / 2
	local halfZ = slot.Size.Z / 2
	local y = slot.Size.Y / 2 + 0.1
	for index = 1, 4 do
		local x = -halfX + (index - 0.5) * slot.Size.X / 4
		local z = -halfZ + (index - 0.5) * slot.Size.Z / 4
		local xLength = slot.Size.X / 7
		local zLength = slot.Size.Z / 7
		addDash(outline, slot.CFrame * CFrame.new(x, y, -halfZ), Vector3.new(xLength, 0.08, 0.16))
		addDash(outline, slot.CFrame * CFrame.new(x, y, halfZ), Vector3.new(xLength, 0.08, 0.16))
		addDash(outline, slot.CFrame * CFrame.new(-halfX, y, z), Vector3.new(0.16, 0.08, zLength))
		addDash(outline, slot.CFrame * CFrame.new(halfX, y, z), Vector3.new(0.16, 0.08, zLength))
	end
	outline.Parent = indicatorFolder
	return outline
end

local function clearIndicators()
	for slotId, outline in indicators do
		outline:Destroy()
		indicators[slotId] = nil
	end
end

local function getOccupied(plot: PlotClient.PlotClient): { [string]: Model }
	local occupied: { [string]: Model } = {}
	local folder = plot.model:FindFirstChild("PlacedItems")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				local slotId = child:GetAttribute("SlotId")
				if typeof(slotId) == "string" then
					occupied[slotId] = child
				end
			end
		end
	end
	return occupied
end

local function updateInteraction()
	updateEggPrompts()
	local plot = getLocalPlot()
	if plot ~= activePlot then
		clearIndicators()
		activePlot = plot
	end
	local currentPrompt = prompt
	if not plot or not currentPrompt then
		if currentPrompt then
			currentPrompt.Parent = nil
		end
		promptSlotId = nil
		promptMode = nil
		return
	end

	local slots = plot.model:FindFirstChild("PlacementSlots")
	if not slots then
		return
	end
	local itemInstanceId, itemId = getEquippedItem()
	local hammerEquipped = isHammerEquipped()
	local occupied = getOccupied(plot)
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local closestSlot: BasePart? = nil
	local closestId: string? = nil
	local closestDistance = math.huge

	for _, slot in slots:GetChildren() do
		if not slot:IsA("BasePart") then
			continue
		end
		local slotId = slot.Name
		local placed = occupied[slotId]
		if itemInstanceId and not placed then
			if not indicators[slotId] then
				indicators[slotId] = makeOutline(slot)
			end
		elseif indicators[slotId] then
			indicators[slotId]:Destroy()
			indicators[slotId] = nil
		end

		if root and root:IsA("BasePart") and ((itemInstanceId and not placed) or (hammerEquipped and placed and placed:GetAttribute("IncubatingEggId") == nil and (placed:GetAttribute("ContainedCrabCount") or 0) == 0)) then
			local distance = (root.Position - slot.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestSlot = slot
				closestId = slotId
			end
		end
	end

	if not closestSlot or closestDistance > MAX_INTERACTION_DISTANCE then
		currentPrompt.Parent = nil
		promptSlotId = nil
		promptMode = nil
		return
	end
	local mode = if itemInstanceId then "place" else "pickup"
	promptSlotId = closestId
	promptMode = mode
	currentPrompt.ActionText = if mode == "place" then "Place" else "Pick Up"
	currentPrompt.ObjectText = if mode == "place" then (itemId :: string) else (occupied[closestId :: string]:GetAttribute("ItemId") :: string? or "Item")
	if currentPrompt.Parent ~= closestSlot then
		currentPrompt.Parent = closestSlot
	end
	currentPrompt.Enabled = true
end

function PlotServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local networker = Networker.client.new("PlotPlacement", self)
	sendPlace = function(instanceId, slotId)
		networker:fire("place", instanceId, slotId)
	end
	sendPickup = function(slotId)
		networker:fire("pickup", slotId)
	end
	sendTravel = function(destination)
		networker:fire("travel", destination)
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	TravelBar.mount(playerGui, function(destination: string)
		if sendTravel then
			sendTravel(destination)
		end
	end, function()
		return TankServiceClient:isPopupOpen()
	end)
	local balance = Vide.source(Data.money())
	Data.money.Changed(function(value: number)
		balance(value)
	end)

	local folder = Instance.new("Folder")
	folder.Name = "LocalPlacementIndicators"
	folder.Parent = Workspace
	indicatorFolder = folder

	local placePrompt = Instance.new("ProximityPrompt")
	placePrompt.Name = "PlacementPrompt"
	placePrompt.KeyboardKeyCode = Enum.KeyCode.E
	placePrompt.ActionText = "Place"
	placePrompt.ObjectText = "Item"
	placePrompt.HoldDuration = 0
	placePrompt.MaxActivationDistance = MAX_INTERACTION_DISTANCE
	placePrompt.RequiresLineOfSight = false
	placePrompt.Triggered:Connect(function()
		local slotId = promptSlotId
		if not slotId then
			return
		end
		if promptMode == "place" then
			local instanceId = getEquippedItem()
			if instanceId and sendPlace then
				sendPlace(instanceId, slotId)
			end
		elseif promptMode == "pickup" and isHammerEquipped() and sendPickup then
			sendPickup(slotId)
		end
	end)
	prompt = placePrompt

	local spawnedPlots = Workspace:WaitForChild("SpawnedPlots") :: Folder
	spawnedPlots.ChildAdded:Connect(addPlot)
	spawnedPlots.ChildRemoved:Connect(removePlot)
	local function mountSign(instance: Instance)
		if not instance:IsA("Model") or mountedSigns[instance] then
			return
		end
		local cleanup = ExtraSlotSign.mount(instance, playerGui, balance, function()
			networker:fire("buyExtraSlot")
		end)
		if cleanup then
			mountedSigns[instance] = cleanup
		end
	end
	local function unmountSign(instance: Instance)
		if instance:IsA("Model") and mountedSigns[instance] then
			mountedSigns[instance]()
			mountedSigns[instance] = nil
		end
	end
	spawnedPlots.ChildAdded:Connect(mountSign)
	spawnedPlots.ChildRemoved:Connect(unmountSign)
	for _, child in spawnedPlots:GetChildren() do
		addPlot(child)
		mountSign(child)
	end

	task.spawn(function()
		while initialized do
			updateInteraction()
			task.wait(0.1)
		end
	end)
end

function PlotServiceClient:travel(destination: string)
	if sendTravel then
		sendTravel(destination)
	end
end

function PlotServiceClient:pickupBlocked(reason: any)
	if reason == "decorations" then
		TankServiceClient:showPickupWarning("REMOVE DECORATIONS BEFORE PICKING UP TANK")
	end
end

function PlotServiceClient:getPlot(index: number): PlotClient.PlotClient?
	return plots[index]
end

function PlotServiceClient:getLocalPlot(): PlotClient.PlotClient?
	return getLocalPlot()
end

return PlotServiceClient
