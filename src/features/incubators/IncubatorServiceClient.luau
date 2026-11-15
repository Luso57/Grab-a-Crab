--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)

local IncubatorCountdown = require(script.Parent.UI.IncubatorCountdown)
local HatchReveal = require(script.Parent.UI.HatchReveal)
local InventoryServiceClient = require(ReplicatedStorage.Source.Features.Inventory.InventoryServiceClient)
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)

local IncubatorServiceClient = {}
local initialized = false
local active: { [Model]: () -> () } = {}
local showReveal: ((string, number, string?, CFrame?, number?, Vector3?, string?) -> ())? = nil
local lockedPromptDistances: { [ProximityPrompt]: number } = {}
local promptLockConnection: RBXScriptConnection? = nil
local rollAgainPromptOpen = false
local rollAgainPromptVisible = false
local rollAgainTarget: string? = nil
local rollAgainPurchaseSucceeded = false
local rollAgainRevealReceived = false
local rollAgainUnlockAt = 0
local hatchNowTarget: string? = nil
local hatchNowToken: string? = nil
local hatchNowPromptVisible = false
local networker = nil

local function lockIncubatorPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt")
		or (instance.Name ~= "PlaceEggPrompt" and instance.Name ~= "HatchEggPrompt" and instance.Name ~= "HatchNowPrompt")
		or lockedPromptDistances[instance] ~= nil then
		return
	end
	lockedPromptDistances[instance] = instance.MaxActivationDistance
	instance.MaxActivationDistance = 0
end

local function setIncubatorPromptsLocked(locked: boolean)
	if locked then
		if promptLockConnection then
			return
		end
		local spawnedPlots = Workspace:FindFirstChild("SpawnedPlots")
		if not spawnedPlots then
			return
		end
		promptLockConnection = spawnedPlots.DescendantAdded:Connect(lockIncubatorPrompt)
		for _, descendant in spawnedPlots:GetDescendants() do
			lockIncubatorPrompt(descendant)
		end
	else
		if promptLockConnection then
			promptLockConnection:Disconnect()
			promptLockConnection = nil
		end
		for prompt, distance in lockedPromptDistances do
			if prompt.Parent then
				prompt.MaxActivationDistance = distance
			end
		end
		table.clear(lockedPromptDistances)
	end
end

local function addEgg(instance: Instance)
	if not instance:IsA("Model") or instance.Name ~= "IncubatingEgg" or active[instance] then
		return
	end
	local incubator = instance.Parent
	if not incubator or not incubator:IsA("Model") then
		return
	end
	active[instance] = IncubatorCountdown.attach(instance, incubator)
end

local function removeEgg(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local cleanup = active[instance]
	if cleanup then
		active[instance] = nil
		cleanup()
	end
end

function IncubatorServiceClient:showHatch(
	crabId: string,
	weightGrams: number,
	eggId: string?,
	eggPivot: CFrame?,
	eggScale: number?,
	viewDirection: Vector3?,
	instanceId: string?,
	isRollAgain: boolean?
)
	if typeof(crabId) == "string" and typeof(weightGrams) == "number" and showReveal then
		if isRollAgain then
			rollAgainRevealReceived = true
			rollAgainPromptOpen = false
			rollAgainTarget = nil
		end
		local hatchedInstanceId = if typeof(instanceId) == "string" then instanceId else nil
		if typeof(eggId) == "string" and typeof(eggPivot) == "CFrame"
			and typeof(eggScale) == "number" and eggScale > 0 then
			showReveal(crabId, weightGrams, eggId, eggPivot, eggScale, if typeof(viewDirection) == "Vector3" then viewDirection else nil, hatchedInstanceId)
		else
			showReveal(crabId, weightGrams, nil, nil, nil, nil, hatchedInstanceId)
		end
	end
end

function IncubatorServiceClient:rollAgainReady(instanceId: string)
	if not rollAgainPromptOpen or rollAgainTarget ~= instanceId then
		return
	end
	rollAgainPromptVisible = true
	local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, ProductIds.RollAgain)
	if not ok then
		rollAgainPromptVisible = false
		rollAgainPromptOpen = false
		rollAgainTarget = nil
		networker:fire("cancelRollAgain", instanceId)
		warn(`Could not prompt Roll Again purchase: {err}`)
	end
end

function IncubatorServiceClient:rollAgainUnavailable(instanceId: string)
	if rollAgainTarget == instanceId then
		rollAgainTarget = nil
		rollAgainPromptVisible = false
		rollAgainPromptOpen = false
		warn("Roll Again purchase is temporarily unavailable")
	end
end

function IncubatorServiceClient:hatchNowReady(_incubatorInstanceId: string, eggInstanceId: string, token: string)
	if typeof(eggInstanceId) ~= "string" or typeof(token) ~= "string" then return end
	hatchNowTarget = eggInstanceId
	hatchNowToken = token
	hatchNowPromptVisible = true
	local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, ProductIds.HatchNow)
	if not ok then
		hatchNowPromptVisible = false
		hatchNowTarget = nil
		hatchNowToken = nil
		networker:fire("cancelHatchNow", token)
		warn(`Could not prompt Hatch Now purchase: {err}`)
	end
end

function IncubatorServiceClient:init()
	if initialized then
		return
	end
	initialized = true
	showReveal = HatchReveal.mount(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui, setIncubatorPromptsLocked, function(instanceId)
		if rollAgainPromptOpen and not rollAgainPromptVisible and rollAgainTarget == instanceId then
			rollAgainPromptOpen = false
			rollAgainTarget = nil
			if networker then
				networker:fire("cancelRollAgain", instanceId)
			end
		end
		InventoryServiceClient:equipHatchedCrab(instanceId)
	end, function(instanceId)
		if rollAgainPromptOpen or not networker then
			return
		end
		rollAgainPromptOpen = true
		rollAgainPurchaseSucceeded = false
		rollAgainRevealReceived = false
		rollAgainUnlockAt = 0
		rollAgainTarget = instanceId
		networker:fire("prepareRollAgain", instanceId)
	end, function()
		return not rollAgainPurchaseSucceeded
			or (rollAgainRevealReceived and time() >= rollAgainUnlockAt)
	end)
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, wasPurchased)
		if userId == Players.LocalPlayer.UserId and productId == ProductIds.HatchNow and hatchNowPromptVisible then
			hatchNowPromptVisible = false
			if not wasPurchased and hatchNowToken then
				networker:fire("cancelHatchNow", hatchNowToken)
			end
			hatchNowTarget = nil
			hatchNowToken = nil
			return
		end
		if userId ~= Players.LocalPlayer.UserId or productId ~= ProductIds.RollAgain or not rollAgainPromptVisible then
			return
		end
		rollAgainPromptVisible = false
		if wasPurchased then
			rollAgainPurchaseSucceeded = true
			rollAgainUnlockAt = time() + 5
		else
			rollAgainPromptOpen = false
			local instanceId = rollAgainTarget
			rollAgainTarget = nil
			if instanceId and networker then
				networker:fire("cancelRollAgain", instanceId)
			end
		end
	end)
	networker = Networker.client.new("IncubatorService", self)
	local spawnedPlots = Workspace:WaitForChild("SpawnedPlots")
	spawnedPlots.DescendantAdded:Connect(addEgg)
	spawnedPlots.DescendantRemoving:Connect(removeEgg)
	for _, instance in spawnedPlots:GetDescendants() do
		addEgg(instance)
	end
end

return IncubatorServiceClient
