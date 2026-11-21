--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Networker = require(ReplicatedStorage.Packages.Networker)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local ShopServiceClient = require(ReplicatedStorage.Source.Features.Shop.ShopServiceClient)
local TutorialStrip = require(script.Parent.UI.TutorialStrip)
local TutorialArrowPath = require(script.Parent.UI.TutorialArrowPath)
local TutorialShopPrompt = require(script.Parent.UI.TutorialShopPrompt)

local player = Players.LocalPlayer
local TutorialServiceClient = {}
local initialized = false

local function findPlaced(plot: Model, slotId: string, itemId: string): Model?
	local folder = plot:FindFirstChild("PlacedItems")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("SlotId") == slotId
			and child:GetAttribute("ItemId") == itemId then
			return child
		end
	end
	return nil
end

local function findThreeSecondEgg(plot: Model, root: BasePart): BasePart?
	local conveyor = plot:FindFirstChild("EggConveyor")
	local active = if conveyor then conveyor:FindFirstChild("ActiveEggs") else nil
	if not active then
		return nil
	end
	local nearestEnabled: BasePart? = nil
	local enabledDistance = math.huge
	for _, egg in active:GetChildren() do
		local eggId = if egg:IsA("Model") then egg:GetAttribute("EggId") else nil
		if egg:IsA("Model") and typeof(eggId) == "string" and Eggs.getRarity(eggId) == "Common" then
			local driver = egg:FindFirstChild("ConveyorDriver")
			local prompt = if driver then driver:FindFirstChild("GetEggPrompt") else nil
			if driver and driver:IsA("BasePart") then
				local current = (driver.Position - root.Position).Magnitude
				if prompt and prompt:IsA("ProximityPrompt") and prompt.Enabled and current < enabledDistance then
					enabledDistance = current
					nearestEnabled = driver
				end
			end
		end
	end
	return nearestEnabled
end

local function targetFor(stage: string, plot: Model, root: BasePart, itemId: string): (string, BasePart?)
	if stage == "BuyEgg" then
		return "BUY AN EGG", findThreeSecondEgg(plot, root)
	end
	if stage == "GetAnotherEgg" then
		return "GET ANOTHER EGG", findThreeSecondEgg(plot, root)
	end
	local incubator = findPlaced(plot, "Right3", "Incubator")
	local incubatorFloor = if incubator then incubator:FindFirstChild("InsideFloor", true) else nil
	if stage == "PlaceAnotherEgg" then
		if incubatorFloor and incubatorFloor:IsA("BasePart") then
			return "PLACE INSIDE", incubatorFloor
		end
		return "PLACE YOUR INCUBATOR", nil
	end
	if stage == "PlaceEgg" then
		if incubatorFloor and incubatorFloor:IsA("BasePart") then
			return "PLACE EGG INSIDE", incubatorFloor
		end
		return "PLACE YOUR INCUBATOR", nil
	end
	if stage == "Incubating" or stage == "IncubatingAnotherEgg" then
		local item = Data.inventory()[itemId]
		local ready = item and typeof(item.hatchAtUnixMs) == "number"
			and DateTime.now().UnixTimestampMillis >= item.hatchAtUnixMs
		local hatchPrompt = if incubator then incubator:FindFirstChild("HatchEggPrompt", true) else nil
		local hatchSurface = if hatchPrompt then hatchPrompt.Parent else nil
		local target: BasePart? = nil
		if hatchSurface and hatchSurface:IsA("BasePart") then
			target = hatchSurface
		elseif incubatorFloor and incubatorFloor:IsA("BasePart") then
			target = incubatorFloor
		end
		return if ready then "OPEN THE EGG" else "WAIT FOR THE EGG",
			target
	end
	if stage == "ClaimCrab" then
		return "COLLECT YOUR CRAB", nil
	end
	if stage == "PlaceCrab" then
		local tank = findPlaced(plot, "Right2", "Tank.Small")
		local floor = if tank then tank:FindFirstChild("InsideFloor", true) else nil
		if not floor or not floor:IsA("BasePart") then
			return "PLACE YOUR SMALL TANK", nil
		end
		local item = Data.inventory()[itemId]
		if item and item.tankInstanceId ~= nil then
			return "MOVE YOUR CRAB TO THIS TANK", floor
		end
		local character = player.Character
		local equipped = false
		if character then
			for _, child in character:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemInstanceId") == itemId then
					equipped = true
					break
				end
			end
		end
		return if equipped then "PLACE CRAB IN TANK" else "EQUIP YOUR CRAB", if equipped then floor else nil
	end
	if stage == "FillTanks" then
		local item = Data.inventory()[itemId]
		if not item or not string.match(item.itemId, "^Crab%.[%w_]+$")
			or item.incubatorInstanceId ~= nil then
			return "", nil
		end
		if item.tankInstanceId ~= nil then
			return "FILL UP OTHER TANK", nil
		end
		local tank = findPlaced(plot, "Right2", "Tank.Small")
		local floor = if tank then tank:FindFirstChild("InsideFloor", true) else nil
		if not floor or not floor:IsA("BasePart") then
			return "PLACE YOUR SMALL TANK", nil
		end
		return "PLACE CRAB IN TANK", floor
	end
	return "", nil
end

function TutorialServiceClient:init()
	if initialized then
		return
	end
	initialized = true
	local message = Vide.source("")
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	TutorialStrip.mount(playerGui, message)
	local point = TutorialArrowPath.mount(playerGui)
	local setShopPrompt = TutorialShopPrompt.mount(playerGui)
	Networker.client.new("TutorialService", TutorialServiceClient)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.15 then
			return
		end
		elapsed = 0
		local stage = Data.tutorialStage()
		setShopPrompt(stage == "VisitShop")
		if stage == "Uninitialized" or stage == "Complete" or stage == "Skipped" then
			if message() ~= "" then
				message("")
			end
			point(nil, nil)
			return
		end
		if stage == "VisitShop" then
			if message() ~= "" then
				message("")
			end
			point(nil, nil)
			return
		end
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local plotClient = PlotServiceClient:getLocalPlot()
		if not root or not root:IsA("BasePart") or not plotClient then
			point(nil, nil)
			return
		end
		local text, target = targetFor(stage, plotClient.model, root, Data.tutorialItemInstanceId())
		if message() ~= text then
			message(text)
		end
		local origin: BasePart = root
		local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			origin = torso
		end
		point(origin, target)
	end)
end

function TutorialServiceClient:shopTravelSucceeded()
	ShopServiceClient:open()
end

return TutorialServiceClient
