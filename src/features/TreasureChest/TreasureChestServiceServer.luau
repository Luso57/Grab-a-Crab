--[[
	This server service owns the real treasure chest state.

	The server checks every request so a client cannot open a missing chest,
	open the same chest twice, or open a chest from too far away.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TreasureChest = require(ReplicatedStorage.Source.Features.TreasureChest.Classes.TreasureChest)
local TreasureChestConfig = require(ReplicatedStorage.Source.Features.TreasureChest.TreasureChestConfig)

local TreasureChestServiceServer = {}

-- This table connects each chest Model to its TreasureChest object.
TreasureChestServiceServer.Chests = {}

local function handleOpenRequest(player, chestModel)
	-- Make sure the requested Model belongs to a known chest.
	local chest = TreasureChestServiceServer.Chests[chestModel]
	if not chest then
		return
	end

	-- Find the player's position.
	local character = player.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return
	end

	-- The server performs its own distance check.
	local chestPosition = chest.Model:GetPivot().Position
	local distance = (humanoidRootPart.Position - chestPosition).Magnitude

	if distance > TreasureChestConfig.MaxDistance then
		return
	end

	-- Open() returns false if this chest was already opened.
	if chest:Open() then
		print("Player received " .. chest.Reward .. " coins")
	end
end

function TreasureChestServiceServer:init()
	-- Find the chest folder. Create it if it does not exist yet.
	local treasureChestsFolder = workspace:FindFirstChild("TreasureChests")

	if not treasureChestsFolder then
		treasureChestsFolder = Instance.new("Folder")
		treasureChestsFolder.Name = "TreasureChests"
		treasureChestsFolder.Parent = workspace
	end

	-- Create one OOP object for every chest Model in the folder.
	for _, chestModel in treasureChestsFolder:GetChildren() do
		if chestModel:IsA("Model") then
			local chest = TreasureChest.new(chestModel, TreasureChestConfig.Reward)
			self.Chests[chestModel] = chest
		end
	end

	-- The server creates the RemoteEvent shared with the client.
	local openChestRemote = ReplicatedStorage:FindFirstChild("OpenTreasureChest")
	if not openChestRemote then
		openChestRemote = Instance.new("RemoteEvent")
		openChestRemote.Name = "OpenTreasureChest"
		openChestRemote.Parent = ReplicatedStorage
	end

	openChestRemote.OnServerEvent:Connect(handleOpenRequest)
end

return TreasureChestServiceServer
