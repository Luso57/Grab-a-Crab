--!strict

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local LuckSign = require(ReplicatedStorage.Source.Features.EggConveyor.UI.LuckSign)
local GiganticEggCountdown = require(ReplicatedStorage.Source.Features.EggConveyor.UI.GiganticEggCountdown)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local EggBillboard = require(ReplicatedStorage.Source.Features.Egg.UI.EggBillboard)
local EggMoneyWarning = require(ReplicatedStorage.Source.Features.EggConveyor.UI.EggMoneyWarning)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local TutorialStrip = require(ReplicatedStorage.Source.Features.Tutorial.UI.TutorialStrip)

local EggConveyorServiceClient = {}
local initialized = false
local mounted: { [Model]: { cleanup: () -> (), destroying: RBXScriptConnection } } = {}
local pendingMounts: { [Model]: { RBXScriptConnection } } = {}
local mountedSigns: { [Model]: () -> () } = {}
local mountedCountdowns: { [Model]: () -> () } = {}
local showMoneyWarning: (() -> ())? = nil
local playEggErrorSound: (() -> ())? = nil
local purchaseSound: Sound? = nil
local networker: any = nil
local pendingEggPrompts: { [number]: string } = {}

local eggProductIds = {
    ProductIds.CommonCrab,
    ProductIds.UncommonCrab,
    ProductIds.RareCrab,
    ProductIds.EpicCrab,
    ProductIds.LegendaryCrab,
    ProductIds.MythicCrab,
}

local function isEggProduct(productId: any): boolean
    if typeof(productId) ~= "number" then
        return false
    end
    return table.find(eggProductIds, productId) ~= nil
end

local mountEgg: (Instance) -> ()

local function stopWatchingEgg(model: Model)
    local connections = pendingMounts[model]
    if not connections then
        return
    end
    pendingMounts[model] = nil
    for _, connection in connections do
        connection:Disconnect()
    end
end

local function unmountEgg(model: Model)
    local binding = mounted[model]
    if not binding then
        stopWatchingEgg(model)
        return
    end
    mounted[model] = nil
    binding.destroying:Disconnect()
    binding.cleanup()
    stopWatchingEgg(model)
end

local function watchEgg(model: Model)
    if pendingMounts[model] or mounted[model] then
        return
    end
    local connections: { RBXScriptConnection } = {}
    pendingMounts[model] = connections
    table.insert(connections, model:GetAttributeChangedSignal("EggId"):Connect(function()
        mountEgg(model)
    end))
    table.insert(connections, model:GetAttributeChangedSignal("CrabId"):Connect(function()
        mountEgg(model)
    end))
    table.insert(connections, model.DescendantAdded:Connect(function(descendant)
        if descendant.Name == "ConveyorDriver" then
            mountEgg(model)
        end
    end))
    task.defer(mountEgg, model)
end

mountEgg = function(instance: Instance)
    if not instance:IsA("Model") or mounted[instance] then
        return
    end
    local activeFolder = instance.Parent
    if not activeFolder or activeFolder.Name ~= "ActiveEggs"
        or not activeFolder.Parent or activeFolder.Parent.Name ~= "EggConveyor" then
        stopWatchingEgg(instance)
        return
    end
    local eggId = instance:GetAttribute("EggId")
    local crabId = instance:GetAttribute("CrabId")
    local driver = instance:FindFirstChild("ConveyorDriver")
    if typeof(eggId) ~= "string" or typeof(crabId) ~= "string"
        or not driver or not driver:IsA("BasePart") then
        watchEgg(instance)
        return
    end
    stopWatchingEgg(instance)
    local egg = Eggs.get(eggId)
    local crab = Crabs.get(crabId)
    if not egg or not crab or Eggs.getCrabId(eggId) ~= crabId then
        return
    end
    local boxCFrame, boxSize = instance:GetBoundingBox()
    local topOffset = boxCFrame.Position.Y + boxSize.Y / 2 - driver.Position.Y
    local cleanup = Vide.mount(function()
        return EggBillboard.create(driver, topOffset, egg.name, crab.rarity, egg.price, instance:GetAttribute("IsGiganticEgg") == true)
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

	networker = Networker.client.new("EggConveyor", self)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, isPurchased: boolean)
		if userId ~= Players.LocalPlayer.UserId then
			return
		end
		local intentId = pendingEggPrompts[productId]
		if not intentId then
			return
		end
		pendingEggPrompts[productId] = nil
		if not isPurchased and networker then
			networker:fire("cancelEggProductPurchase", intentId)
		end
	end)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local sound = Instance.new("Sound")
	sound.Name = "EggPurchaseSound"
	sound.SoundId = "rbxassetid://4612383453"
	sound.Volume = 1
	sound.Parent = playerGui
	purchaseSound = sound
	showMoneyWarning, playEggErrorSound = EggMoneyWarning.mount(playerGui)
	local balance = Vide.source(Data.money() :: any)
	Data.money.Changed(function(value: any)
		balance(value)
	end)
	local discoveries = Vide.source(Data.discoveredCrabs())
	Data.discoveredCrabs.Changed(function(value: { [string]: boolean })
		discoveries(value)
	end)
	local function unmountSign(instance: Instance)
		if instance:IsA("Model") and mountedSigns[instance] then
			mountedSigns[instance]()
			mountedSigns[instance] = nil
		end
		if instance:IsA("Model") and mountedCountdowns[instance] then
			mountedCountdowns[instance]()
			mountedCountdowns[instance] = nil
		end
	end
	local function mountSign(instance: Instance)
		if not instance:IsA("Model") or mountedSigns[instance] then
			return
		end
		local cleanup = LuckSign.mount(instance, playerGui, balance, discoveries, function()
			networker:fire("buyUpgrade")
		end)
		if cleanup then
			mountedSigns[instance] = cleanup
		end
		local countdownCleanup = GiganticEggCountdown.mount(instance, playerGui)
		if countdownCleanup then
			mountedCountdowns[instance] = countdownCleanup
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

function EggConveyorServiceClient:showNotEnoughMoney(productId: any?, intentId: any?)
	local show = showMoneyWarning
	if show then
		show()
	end
	if not isEggProduct(productId) or typeof(intentId) ~= "string" or #intentId > 64 then
		return
	end
	pendingEggPrompts[productId] = intentId
	task.delay(0.35, function()
		if pendingEggPrompts[productId] ~= intentId then
			return
		end
		local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, productId)
		if not ok then
			pendingEggPrompts[productId] = nil
			if networker then
				networker:fire("cancelEggProductPurchase", intentId)
			end
			warn(`Could not open egg Robux purchase prompt: {err}`)
		end
	end)
end

function EggConveyorServiceClient:showTutorialPurchaseBlocked()
	local play = playEggErrorSound
	if play then
		play()
	end
	TutorialStrip.pulsePlaceEggInstruction()
end

function EggConveyorServiceClient:eggPurchased()
	local sound = purchaseSound
	if sound then
		sound.TimePosition = 0
		sound:Play()
	end
end

return EggConveyorServiceClient
