--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local EggBillboard = require(ReplicatedStorage.Source.Features.Egg.UI.EggBillboard)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)

local EggConveyorServiceClient = {}
local initialized = false
local mounted: { [Model]: { cleanup: () -> (), destroying: RBXScriptConnection } } = {}

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

return EggConveyorServiceClient