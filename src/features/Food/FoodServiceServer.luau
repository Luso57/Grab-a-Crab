local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Fruits = require(ReplicatedStorage.Source.Game.Fruits)
local Food = require(ReplicatedStorage.Source.Features.Food.Classes.Food)

type FoodObject = Food.Food

-- This service creates and manages all Food objects on the server.
local FoodServiceServer = {}

local Foods: { [string]: FoodObject } = {}

local function applySpeedBoost(player: Player, foodObject: FoodObject)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = foodObject:GetSpeedBoost()
end

local function connectFruitModel(fruitModel: Model)
	local fruitName = fruitModel:GetAttribute("Fruit")
	local foodObject = Foods[fruitName]
	local proximityPrompt = fruitModel:FindFirstChildWhichIsA("ProximityPrompt", true)

	proximityPrompt.Triggered:Connect(function(player: Player)
		print(player.Name .. " interacted with " .. foodObject.Name)
		print("Nutrition: " .. foodObject:GetNutrition())
		print("SpeedBoost: " .. foodObject:GetSpeedBoost())

		applySpeedBoost(player, foodObject)
	end)
end

function FoodServiceServer:init(): ()
	for fruitName, fruitData in Fruits do
		local foodObject: FoodObject = Food.new(fruitData)

		Foods[fruitName] = foodObject

		print("Created " .. foodObject.Name)
	end

	local fruitsFolder = Workspace:WaitForChild("Fruits")

	-- Connect every fruit model in Workspace to its ProximityPrompt.
	for _, fruitModel in fruitsFolder:GetChildren() do
		if fruitModel:IsA("Model") then
			connectFruitModel(fruitModel)
		end
	end
end

function FoodServiceServer:GetFood(name: string): FoodObject?
	return Foods[name]
end

return FoodServiceServer
