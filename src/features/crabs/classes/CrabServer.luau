--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Crabs = require(ReplicatedStorage.Source.Features.Crabs.Modules.Crabs)
local CrabWeights = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabWeights)
local CrabRigBuilder = require(ReplicatedStorage.Source.Features.Crabs.Modules.CrabRigBuilder)

local CrabServer = {}
CrabServer.__index = CrabServer

export type CrabServer = typeof(setmetatable({} :: {
	instanceId: string,
	crabId: string,
	tool: Tool,
}, CrabServer))

function CrabServer.new(instanceId: string, crabId: string, weightGrams: number?): CrabServer?
	local definition = Crabs.get(crabId)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local models = if assets then assets:FindFirstChild("Crabs") else nil
	local template = if definition and models then models:FindFirstChild(definition.modelName) else nil
	if not definition or not template or not template:IsA("Model") then
		warn("Missing crab model template:", crabId)
		return nil
	end

	local model = template:Clone()
	local body = CrabRigBuilder.rig(model)
	if not body then
		model:Destroy()
		return nil
	end
	local height = model:GetExtentsSize().Y
	if height <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * 2 / height * CrabWeights.scale(weightGrams))

	local tool = Instance.new("Tool")
	tool.Name = definition.name
	tool.TextureId = "rbxassetid://" .. definition.imageId
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("CrabId", crabId)
	tool:SetAttribute("WeightGrams", CrabWeights.normalize(weightGrams))
	tool:SetAttribute("ItemId", "Crab." .. crabId)
	tool:SetAttribute("ItemInstanceId", instanceId)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.3, 0.3)
	handle.CFrame = model:GetPivot()
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Parent = tool

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CrabHandleWeld"
	weld.Part0 = handle
	weld.Part1 = body
	weld.Parent = handle

	model.Parent = tool
	return setmetatable({ instanceId = instanceId, crabId = crabId, tool = tool }, CrabServer) :: CrabServer
end

function CrabServer.destroy(self: CrabServer)
	self.tool:Destroy()
end

return CrabServer
