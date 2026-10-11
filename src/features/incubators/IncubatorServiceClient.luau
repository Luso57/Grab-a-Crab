--!strict

local Workspace = game:GetService("Workspace")

local IncubatorCountdown = require(script.Parent.UI.IncubatorCountdown)

local IncubatorServiceClient = {}
local initialized = false
local active: { [Model]: () -> () } = {}

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

function IncubatorServiceClient:init()
	if initialized then
		return
	end
	initialized = true
	local spawnedPlots = Workspace:WaitForChild("SpawnedPlots")
	spawnedPlots.DescendantAdded:Connect(addEgg)
	spawnedPlots.DescendantRemoving:Connect(removeEgg)
	for _, instance in spawnedPlots:GetDescendants() do
		addEgg(instance)
	end
end

return IncubatorServiceClient
