--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local LuckSign = require(ReplicatedStorage.Source.Features.EggConveyor.UI.LuckSign)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local EggBillboard = require(ReplicatedStorage.Source.Features.Egg.UI.EggBillboard)
local EggMoneyWarning = require(ReplicatedStorage.Source.Features.EggConveyor.UI.EggMoneyWarning)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)

local EggConveyorServiceClient = {}
local initialized = false
local mounted: { [Model]: { cleanup: () -> (), destroying: RBXScriptConnection } } = {}
local mountedSigns: { [Model]: () -> () } = {}
local showMoneyWarning: (() -> ())? = nil
local purchaseSound: Sound? = nil

local function unmountEgg(model: Model)
    local binding = mounted[model]
    if not binding then
        return
    end
    mounted[model] = nil
    binding.destroying:Disconnect()
    binding.cleanup()
end

local function mountEgg(instance: Instance)
    if not instance:IsA("Model") or mounted[instance] then
        return
    end
    local activeFolder = instance.Parent
    if not activeFolder or activeFolder.Name ~= "ActiveEggs"
        or not activeFolder.Parent or activeFolder.Parent.Name ~= "EggConveyor" then
        return
    end
    local eggId = instance:GetAttribute("EggId")
    local crabId = instance:GetAttribute("CrabId")
    if typeof(eggId) ~= "string" or typeof(crabId) ~= "string" then
        return
    end
    local egg = Eggs.get(eggId)
    local crab = Crabs.get(crabId)
    local driver = instance:FindFirstChild("ConveyorDriver")
    if not egg or not crab or Eggs.getCrabId(eggId) ~= crabId or not driver or not driver:IsA("BasePart") then
        return
    end
    local boxCFrame, boxSize = instance:GetBoundingBox()
    local topOffset = boxCFrame.Position.Y + boxSize.Y / 2 - driver.Position.Y
    local cleanup = Vide.mount(function()
        return EggBillboard.create(driver, topOffset, egg.name, crab.rarity, egg.price)
    end, instance)
    local destroying = instance.Destroying:Connect(function()
        unmountEgg(instance)
    end)
    mounted[instance] = { cleanup = cleanup, destroying = destroying }
end

function EggConveyorServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local spawnedPlots = Workspace:WaitForChild("SpawnedPlots")
	spawnedPlots.DescendantAdded:Connect(mountEgg)
	spawnedPlots.DescendantRemoving:Connect(function(instance)
		if instance:IsA("Model") then
			unmountEgg(instance)
		end
	end)
	for _, instance in spawnedPlots:GetDescendants() do
		mountEgg(instance)
	end

	local networker = Networker.client.new("EggConveyor", self)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local sound = Instance.new("Sound")
	sound.Name = "EggPurchaseSound"
	sound.SoundId = "rbxassetid://4612383453"
	sound.Volume = 1
	sound.Parent = playerGui
	purchaseSound = sound
	showMoneyWarning = EggMoneyWarning.mount(playerGui)
	local balance = Vide.source(Data.money())
	Data.money.Changed(function(value: number)
		balance(value)
	end)
	local function unmountSign(instance: Instance)
		if instance:IsA("Model") and mountedSigns[instance] then
			mountedSigns[instance]()
			mountedSigns[instance] = nil
		end
	end
	local function mountSign(instance: Instance)
		if not instance:IsA("Model") or mountedSigns[instance] then
			return
		end
		local cleanup = LuckSign.mount(instance, playerGui, balance, function()
			networker:fire("buyUpgrade")
		end)
		if cleanup then
			mountedSigns[instance] = cleanup
		end
	end
	spawnedPlots.ChildAdded:Connect(mountSign)
	spawnedPlots.ChildRemoved:Connect(unmountSign)
	for _, plot in spawnedPlots:GetChildren() do
		mountSign(plot)
	end
	task.spawn(function()
		if not game:IsLoaded() then
			game.Loaded:Wait()
		end
		local player = Players.LocalPlayer
		while player.Parent == Players do
			local plot = PlotServiceClient:getLocalPlot()
			local character = player.Character
			if plot and character and character:FindFirstChild("HumanoidRootPart") then
				networker:fire("ready")
				return
			end
			task.wait(0.1)
		end
	end)
end

function EggConveyorServiceClient:showNotEnoughMoney()
	local show = showMoneyWarning
	if show then
		show()
	end
end

function EggConveyorServiceClient:eggPurchased()
	local sound = purchaseSound
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

return EggConveyorServiceClient
