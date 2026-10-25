--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DecorConfig = require(ReplicatedStorage.Source.Features.DecorShop.DecorConfig)

local DecorToolFactoryServer = {}

function DecorToolFactoryServer.createTool(player: Player, decorId: string, instanceId: string): Tool?
	local definition = DecorConfig.get(decorId)
	if not definition or not player.Parent then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local decorations = if assets then assets:FindFirstChild("Decorations") else nil
	local template = if decorations then decorations:FindFirstChild(decorId) else nil
	if not template or not template:IsA("Model") then
		warn("Missing decoration model template:", decorId)
		return nil
	end

	local model = template:Clone()
	local _, size = model:GetBoundingBox()
	if size.Y <= 0 then
		model:Destroy()
		return nil
	end
	model:ScaleTo(model:GetScale() * 2 / size.Y)

	local tool = Instance.new("Tool")
	tool.Name = definition.name
	tool.TextureId = "rbxassetid://" .. definition.imageId
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("ItemId", "Decor." .. decorId)
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
	return tool
end

return DecorToolFactoryServer
