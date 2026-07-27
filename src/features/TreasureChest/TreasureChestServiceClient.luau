--[[
	This client service reads keyboard input.

	It finds the nearest chest when the player presses E, then asks the server
	to open it. The server still makes the final decision.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local TreasureChestConfig = require(script.Parent.TreasureChestConfig)

local TreasureChestServiceClient = {}

local function findNearestChest()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character then
		return nil
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return nil
	end

	local treasureChestsFolder = workspace:WaitForChild("TreasureChests")
	local nearestChest = nil
	local nearestDistance = TreasureChestConfig.MaxDistance

	for _, chestModel in treasureChestsFolder:GetChildren() do
		if chestModel:IsA("Model") then
			local chestPosition = chestModel:GetPivot().Position
			local distance = (humanoidRootPart.Position - chestPosition).Magnitude

			if distance <= nearestDistance then
				nearestChest = chestModel
				nearestDistance = distance
			end
		end
	end

	return nearestChest
end

function TreasureChestServiceClient:init()
	local openChestRemote = ReplicatedStorage:WaitForChild("OpenTreasureChest")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- Ignore the key if Roblox already used it for chat or another control.
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			local nearestChest = findNearestChest()

			if nearestChest then
				openChestRemote:FireServer(nearestChest)
			end
		end
	end)
end

return TreasureChestServiceClient
