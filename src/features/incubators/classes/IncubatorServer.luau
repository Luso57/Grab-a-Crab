--!strict



local IncubatorServer = {}
IncubatorServer.__index = IncubatorServer

export type IncubatorServer = typeof(setmetatable({} :: {
	owner: Player,
	instanceId: string,
	incubatorId: string,
	tool: Tool,
	model: Model,
}, IncubatorServer))

function IncubatorServer.new(owner: Player, instanceId: string, incubatorId: string, name: string, template: Model): IncubatorServer?
	local model = template:Clone()
	local height = model:GetExtentsSize().Y
	if height <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * 2 / height)

	
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("IncubatorId", incubatorId)
	tool:SetAttribute("IncubatorInstanceId", instanceId)
	tool:SetAttribute("ItemId", incubatorId)
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

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = descendant
			weld.Parent = handle
		end
	end

	model.Parent = tool
	return setmetatable({
		owner = owner,
		instanceId = instanceId,
		incubatorId = incubatorId,
		tool = tool,
		model = model,
	}, IncubatorServer) :: IncubatorServer
end

function IncubatorServer.destroy(self: IncubatorServer)
	self.tool:Destroy()
end

return IncubatorServer
