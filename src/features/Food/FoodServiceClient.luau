local Workspace = game:GetService("Workspace")

-- This client service handles effects that only the local player should see.
local FoodServiceClient = {}

local function connectFruitModel(fruitModel)
	local proximityPrompt = fruitModel:FindFirstChildWhichIsA("ProximityPrompt", true)

	-- The Model can reach the client before all of its children finish loading.
	-- Wait for descendants until the ProximityPrompt becomes available.
	while not proximityPrompt do
		fruitModel.DescendantAdded:Wait()
		proximityPrompt = fruitModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	end

	proximityPrompt.Triggered:Connect(function()
		-- This code runs on the client, so only this player loses the fruit.
		fruitModel:Destroy()
	end)
end

function FoodServiceClient:init()
	local fruitsFolder = Workspace:WaitForChild("Fruits")

	for _, fruitModel in fruitsFolder:GetChildren() do
		if fruitModel:IsA("Model") then
			connectFruitModel(fruitModel)
		end
	end
end

return FoodServiceClient
