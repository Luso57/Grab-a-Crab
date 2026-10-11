--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local TankClient = require(script.Parent.Classes.TankClient)
local TankPopupRoot = require(script.Parent.UI.TankPopupRoot)

local TankServiceClient = {}
local initialized = false
local tanks: { [Model]: TankClient.TankClient } = {}
local selectedTank: TankClient.TankClient? = nil
local popupOpen = Vide.source(false)
local popupCards = Vide.source({} :: { TankPopupRoot.Card })
local cardSignature = ""

local function closePopup()
	selectedTank = nil
	cardSignature = ""
	popupCards({})
	popupOpen(false)
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
	local folder = tank.model:FindFirstChild("ContainedCrabs")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") and child.Name == "ContainedCrabAnchor" then
				local crabId = child:GetAttribute("CrabId")
				local definition = if typeof(crabId) == "string" then Crabs.get(crabId) else nil
				if definition then
					local instanceId = child:GetAttribute("ItemInstanceId")
					local key = if typeof(instanceId) == "string" then instanceId else child.Name
					table.insert(nextCards, {
						instanceId = key,
						name = definition.name,
						imageId = definition.imageId,
						income = CompactNumber.format(definition.incomePerSecond) .. "/s",
					})
					table.insert(signatureParts, key .. ":" .. crabId)
				end
			end
		end
	end
	table.sort(nextCards, function(a, b)
		return a.instanceId < b.instanceId
	end)
	table.sort(signatureParts)
	local nextSignature = table.concat(signatureParts, "|")
	if nextSignature ~= cardSignature then
		cardSignature = nextSignature
		popupCards(nextCards)
	end
end

local function openTank(model: Model)
	local tank = tanks[model]
	if not tank or not isLocalOwner(model) then
		return
	end
	selectedTank = tank
	cardSignature = "#"
	refreshPopup()
	popupOpen(true)
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

local function addTank(instance: Instance)
	if not instance:IsA("Model") or tanks[instance] then
		return
	end
	local itemId = instance:GetAttribute("ItemId")
	local instanceId = instance:GetAttribute("ItemInstanceId")
	if typeof(itemId) ~= "string" or not string.match(itemId, "^Tank%.[%w_]+$")
		or typeof(instanceId) ~= "string" then
		return
	end
	tanks[instance] = TankClient.new(instanceId, instance, openTank)
end

local function removeTank(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
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
	Vide.mount(function()
		return TankPopupRoot({
			cards = popupCards,
			isOpen = popupOpen,
			onClose = closePopup,
			onPickUp = function(crabInstanceId: string)
				local tank = selectedTank
				if not tank or not isLocalOwner(tank.model) then
					return
				end
				for _, card in popupCards() do
					if card.instanceId == crabInstanceId then
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
					tank:update(equipped)
				else
					removeTank(model)
				end
			end
			refreshPopup()
			task.wait(0.1)
		end
	end)
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