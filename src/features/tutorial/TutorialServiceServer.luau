--!strict

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Networker = require(ReplicatedStorage.Packages.Networker)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local TutorialServiceServer = {}
local initialized = false
local networker = nil

local STEP_NAMES = {
	[1] = "Buy Egg",
	[2] = "Place Egg",
	[3] = "Wait for First Egg",
	[4] = "Collect Your Crab",
	[5] = "Place Crab in Tank",
	[6] = "Get Another Egg",
	[7] = "Place Inside",
	[8] = "Wait for Second Egg",
	[9] = "Fill Up Other Tank",
	[10] = "Buy More Tanks (Shop Reached)",
}

local function starterTanksFull(inventory: any): boolean
	local tankIds = {}
	for _, slotId in { "Right1", "Right2" } do
		for instanceId, item in inventory do
			if typeof(item) == "table" and item.itemId == "Tank.Small" and item.placedSlotId == slotId then
				tankIds[slotId] = instanceId
				break
			end
		end
		if not tankIds[slotId] then
			return false
		end
	end
	local counts = { Right1 = 0, Right2 = 0 }
	for _, item in inventory do
		if typeof(item) == "table" and typeof(item.itemId) == "string"
			and string.match(item.itemId, "^Crab%.[%w_]+$") then
			for slotId, tankId in tankIds do
				if item.tankInstanceId == tankId then
					counts[slotId] += 1
				end
			end
		end
	end
	return counts.Right1 == 2 and counts.Right2 == 2
end

local function logStep(player: Player, data: any, step: number)
	if RunService:IsStudio() or data.tutorialFunnelVersion() ~= 2 then
		return
	end
	local ok, err = pcall(
		AnalyticsService.LogOnboardingFunnelStepEvent,
		AnalyticsService,
		player,
		step,
		STEP_NAMES[step]
	)
	if not ok then
		warn(`Tutorial funnel step {step} failed for {player.Name}: {err}`)
	end
end

local function updateTankStage(player: Player, data: any)
	local stage = data.tutorialStage()
	if stage ~= "FillTanks" and stage ~= "VisitShop" then
		return
	end
	local nextStage = if starterTanksFull(data.inventory()) then "VisitShop" else "FillTanks"
	if nextStage == "VisitShop" and stage ~= "VisitShop" then
		logStep(player, data, 9)
	end
	data.tutorialStage(nextStage)
end

local function isThreeSecondEgg(itemId: any): boolean
	if typeof(itemId) ~= "string" then
		return false
	end
	local eggId = string.match(itemId, "^Egg%.([%w_]+)$")
	return eggId ~= nil and Eggs.get(eggId) ~= nil and Eggs.getRarity(eggId) == "Common"
end

local function resetToBuy(data: any)
	data.tutorialItemInstanceId("")
	data.tutorialStage("BuyEgg")
end

local function recover(player: Player, data: any)
	local stage = data.tutorialStage()
	if stage == "BuyEgg" or stage == "Complete" or stage == "Skipped" then
		return
	end
	if stage == "GetAnotherEgg" then
		return
	end
	if stage == "PlaceAnotherEgg" then
		local egg = data.inventory()[data.tutorialItemInstanceId()]
		if typeof(egg) ~= "table" or not isThreeSecondEgg(egg.itemId) then
			data.tutorialStage("GetAnotherEgg")
		else
			if egg.incubatorInstanceId ~= nil then
				logStep(player, data, 7)
				data.tutorialStage("IncubatingAnotherEgg")
			end
		end
		return
	end
	if stage == "IncubatingAnotherEgg" then
		local egg = data.inventory()[data.tutorialItemInstanceId()]
		if typeof(egg) == "table" and typeof(egg.itemId) == "string"
			and string.match(egg.itemId, "^Crab%.[%w_]+$") and egg.hatchedEggId ~= nil then
			logStep(player, data, 8)
			data.tutorialStage("FillTanks")
			updateTankStage(player, data)
		elseif typeof(egg) ~= "table" or not isThreeSecondEgg(egg.itemId) then
			data.tutorialStage("GetAnotherEgg")
		end
		return
	end
	if stage == "FillTanks" or stage == "VisitShop" then
		updateTankStage(player, data)
		return
	end
	local instanceId = data.tutorialItemInstanceId()
	local item = data.inventory()[instanceId]
	if typeof(item) ~= "table" or typeof(item.itemId) ~= "string" then
		resetToBuy(data)
		return
	end
	if isThreeSecondEgg(item.itemId) then
		if item.incubatorInstanceId ~= nil then
			if stage == "PlaceEgg" then
				logStep(player, data, 2)
			end
			data.tutorialStage("Incubating")
		elseif item.placedSlotId == nil and item.tankInstanceId == nil then
			data.tutorialStage("PlaceEgg")
		else
			resetToBuy(data)
		end
		return
	end
	if string.match(item.itemId, "^Crab%.[%w_]+$") then
		if item.tankInstanceId ~= nil then
			if stage == "PlaceCrab" and data.tutorialItemInstanceId() == instanceId then
				local tank = data.inventory()[item.tankInstanceId]
				if typeof(tank) == "table" and tank.placedSlotId == "Right2" then
					logStep(player, data, 5)
					data.tutorialStage("GetAnotherEgg")
					return
				end
			end
			data.tutorialStage("FillTanks")
			updateTankStage(player, data)
		elseif item.incubatorInstanceId ~= nil then
			if stage == "ClaimCrab" then
				logStep(player, data, 3)
			end
			data.tutorialStage("ClaimCrab")
		else
			data.tutorialStage("PlaceCrab")
		end
		return
	end
	resetToBuy(data)
end

local function prepare(player: Player)
	task.spawn(function()
		local data = Data.Service:waitForData(player)
		if not data or player.Parent ~= Players then
			return
		end
		if data.tutorialStage() == "Uninitialized" then
			local profile = Data.Service:getProfile(player)
			if profile and profile.SessionLoadCount == 1 then
				data.tutorialFunnelVersion(2)
				data.tutorialStage("BuyEgg")
			else
				data.tutorialStage("Skipped")
			end
		else
			recover(player, data)
			if data.tutorialStage() == "ClaimCrab" then
				local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
				InventoryServiceServer:claimHatchedCrab(player, data.tutorialItemInstanceId())
			end
		end
		while player.Parent == Players do
			task.wait(1)
			local stage = data.tutorialStage()
			if stage == "Complete" or stage == "Skipped" then
				return
			end
			recover(player, data)
		end
	end)
end

function TutorialServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	networker = Networker.server.new("TutorialService", TutorialServiceServer, {})
	Players.PlayerAdded:Connect(prepare)
	for _, player in Players:GetPlayers() do
		prepare(player)
	end
end

function TutorialServiceServer:isTutorialActive(player: Player): boolean
	local data = Data[player]
	if not data then
		return false
	end
	local stage = data.tutorialStage()
	if stage == "Uninitialized" then
		local profile = Data.Service:getProfile(player)
		return profile ~= nil and profile.SessionLoadCount == 1
	end
	return stage ~= "Complete" and stage ~= "Skipped"
end

function TutorialServiceServer:isBuyingEgg(player: Player): boolean
	local data = Data[player]
	return data ~= nil and data.tutorialStage() == "BuyEgg"
end

function TutorialServiceServer:isWaitingToPlaceEgg(player: Player): boolean
	local data = Data[player]
	if not data then
		return false
	end
	local stage = data.tutorialStage()
	return stage == "PlaceEgg" or stage == "PlaceAnotherEgg"
end

function TutorialServiceServer:eggBought(player: Player, instanceId: string)
	local data = Data[player]
	local item = if data then data.inventory()[instanceId] else nil
	if not data or (data.tutorialStage() ~= "BuyEgg" and data.tutorialStage() ~= "GetAnotherEgg")
		or not item or not isThreeSecondEgg(item.itemId) then
		return
	end
	local stage = data.tutorialStage()
	logStep(player, data, if stage == "BuyEgg" then 1 else 6)
	data.tutorialItemInstanceId(instanceId)
	if stage == "GetAnotherEgg" then
		data.tutorialStage("PlaceAnotherEgg")
	else
		data.tutorialStage("PlaceEgg")
	end
end

function TutorialServiceServer:eggIncubated(player: Player, instanceId: string)
	local data = Data[player]
	local item = if data then data.inventory()[instanceId] else nil
	if not data or (data.tutorialStage() ~= "PlaceEgg" and data.tutorialStage() ~= "PlaceAnotherEgg")
		or data.tutorialItemInstanceId() ~= instanceId
		or not item or not isThreeSecondEgg(item.itemId) or item.incubatorInstanceId == nil then
		return
	end
	local stage = data.tutorialStage()
	logStep(player, data, if stage == "PlaceEgg" then 2 else 7)
	if stage == "PlaceAnotherEgg" then
		data.tutorialStage("IncubatingAnotherEgg")
	else
		data.tutorialStage("Incubating")
	end
end

function TutorialServiceServer:eggOpened(player: Player, instanceId: string)
	local data = Data[player]
	local item = if data then data.inventory()[instanceId] else nil
	if not data or (data.tutorialStage() ~= "Incubating" and data.tutorialStage() ~= "IncubatingAnotherEgg")
		or data.tutorialItemInstanceId() ~= instanceId
		or not item or not string.match(item.itemId, "^Crab%.[%w_]+$") then
		return
	end
	if data.tutorialStage() == "IncubatingAnotherEgg" then
		logStep(player, data, 8)
		data.tutorialStage("FillTanks")
		updateTankStage(player, data)
	else
		logStep(player, data, 3)
		data.tutorialStage("ClaimCrab")
	end
end

function TutorialServiceServer:crabClaimed(player: Player, instanceId: string)
	local data = Data[player]
	local item = if data then data.inventory()[instanceId] else nil
	if not data or data.tutorialStage() ~= "ClaimCrab" or data.tutorialItemInstanceId() ~= instanceId
		or not item or item.incubatorInstanceId ~= nil then
		return
	end
	logStep(player, data, 4)
	data.tutorialStage("PlaceCrab")
end

function TutorialServiceServer:crabPlaced(player: Player, instanceId: string, _tankSlotId: string)
	local data = Data[player]
	local item = if data then data.inventory()[instanceId] else nil
	if not data or (data.tutorialStage() ~= "PlaceCrab" and data.tutorialStage() ~= "FillTanks"
		and data.tutorialStage() ~= "VisitShop")
		or not item or item.tankInstanceId == nil then
		return
	end
	if data.tutorialStage() == "PlaceCrab" then
		if data.tutorialItemInstanceId() ~= instanceId or _tankSlotId ~= "Right2" then
			return
		end
		logStep(player, data, 5)
		data.tutorialStage("GetAnotherEgg")
		return
	end
	updateTankStage(player, data)
end

function TutorialServiceServer:canVisitShop(player: Player): boolean
	local data = Data[player]
	return data ~= nil and data.tutorialStage() == "VisitShop" and starterTanksFull(data.inventory())
end

function TutorialServiceServer:visitedShop(player: Player)
	local data = Data[player]
	if not data or data.tutorialStage() ~= "VisitShop" or not starterTanksFull(data.inventory()) then
		return
	end
	logStep(player, data, 10)
	data.tutorialStage("Complete")
	if networker then
		networker:fire(player, "shopTravelSucceeded")
	end
end

return TutorialServiceServer
