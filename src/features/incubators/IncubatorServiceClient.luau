--!strict

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networker = require(ReplicatedStorage.Packages.Networker)

local IncubatorCountdown = require(script.Parent.UI.IncubatorCountdown)
local HatchReveal = require(script.Parent.UI.HatchReveal)
local InventoryServiceClient = require(ReplicatedStorage.Source.Features.Inventory.InventoryServiceClient)

local IncubatorServiceClient = {}
local initialized = false
local active: { [Model]: () -> () } = {}
local showReveal: ((string, number, string?, CFrame?, number?, Vector3?, string?) -> ())? = nil
local lockedPromptDistances: { [ProximityPrompt]: number } = {}
local promptLockConnection: RBXScriptConnection? = nil

local function lockIncubatorPrompt(instance: Instance)
	if not instance:IsA("ProximityPrompt")
		or (instance.Name ~= "PlaceEggPrompt" and instance.Name ~= "HatchEggPrompt")
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
	instanceId: string?
)
	if typeof(crabId) == "string" and typeof(weightGrams) == "number" and showReveal then
		local hatchedInstanceId = if typeof(instanceId) == "string" then instanceId else nil
		if typeof(eggId) == "string" and typeof(eggPivot) == "CFrame"
			and typeof(eggScale) == "number" and eggScale > 0 then
			showReveal(crabId, weightGrams, eggId, eggPivot, eggScale, if typeof(viewDirection) == "Vector3" then viewDirection else nil, hatchedInstanceId)
		else
			showReveal(crabId, weightGrams, nil, nil, nil, nil, hatchedInstanceId)
		end
	end
end

function IncubatorServiceClient:init()
	if initialized then
		return
	end
	initialized = true
	showReveal = HatchReveal.mount(Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui, setIncubatorPromptsLocked, function(instanceId)
		InventoryServiceClient:equipHatchedCrab(instanceId)
	end)
	Networker.client.new("IncubatorService", self)
	local spawnedPlots = Workspace:WaitForChild("SpawnedPlots")
	spawnedPlots.DescendantAdded:Connect(addEgg)
	spawnedPlots.DescendantRemoving:Connect(removeEgg)
	for _, instance in spawnedPlots:GetDescendants() do
		addEgg(instance)
	end
end

return IncubatorServiceClient
