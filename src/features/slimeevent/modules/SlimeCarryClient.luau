local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Source.Features.Slimeevent.SlimeEventConfig)
local SlimeSlice = require(ReplicatedStorage.Source.Features.Slimes.SlimeSlice)
local SlimeMutationEffects = require(ReplicatedStorage.Source.Features.Slimes.Modules.SlimeMutationEffects)

local SlimeCarryClient = {}
local initialized = false

local RIGHT_SHOULDER = CFrame.Angles(math.rad(-175), math.rad(5), math.rad(12))
local LEFT_SHOULDER = CFrame.Angles(math.rad(-175), math.rad(-5), math.rad(-12))
local RIGHT_ELBOW = CFrame.Angles(math.rad(-18), 0, math.rad(-8))
local LEFT_ELBOW = CFrame.Angles(math.rad(-18), 0, math.rad(8))

local function applyOffset(character: Model, name: string, offset: CFrame)
	local joint = character:FindFirstChild(name, true)
	if joint and joint:IsA("AnimationConstraint") then
		joint.Transform *= offset
	end
end

local function findEventSlime(): Model?
	local hexagon = workspace:FindFirstChild("Hexagon")
	local board = hexagon and hexagon:FindFirstChild("SpawnBoard")
	local slime = board and board:FindFirstChild("EventSlime")
	return if slime and slime:IsA("Model") then slime else nil
end

function SlimeCarryClient.init()
	if initialized then return end
	initialized = true
	local localPlayer = Players.LocalPlayer
	local promptConnections: { RBXScriptConnection } = {}
	local boundSlime: Model? = nil
	local billboardEntryId: string? = nil
	local mutationEffect = nil

	local function disconnectPrompt()
		for _, connection in promptConnections do connection:Disconnect() end
		table.clear(promptConnections)
		if mutationEffect then
			mutationEffect:destroy()
			mutationEffect = nil
		end
		if billboardEntryId then
			SlimeSlice.actions.removeSlime(billboardEntryId)
			billboardEntryId = nil
		end
		boundSlime = nil
	end

	local function bindPrompt()
		local slime = findEventSlime()
		if not slime or (slime == boundSlime and billboardEntryId ~= nil) then return end
		local prompt = slime:FindFirstChild("CarryPrompt", true)
		local highlight = slime:FindFirstChild("CarryHighlight")
		local movementAttachment = slime:FindFirstChild("MovementAttachment", true)
		if not prompt
			or not prompt:IsA("ProximityPrompt")
			or not highlight
			or not highlight:IsA("Highlight")
			or not movementAttachment
			or not movementAttachment:IsA("Attachment")
		then
			return
		end
		disconnectPrompt()
		boundSlime = slime
		local rootPart = movementAttachment and movementAttachment.Parent
		if rootPart and rootPart:IsA("BasePart") then
			mutationEffect = SlimeMutationEffects.apply(slime, rootPart, slime:GetAttribute("MutationId"))
			local slimeId = slime:GetAttribute("SlimeId")
			local mutationId = slime:GetAttribute("MutationId")
			if movementAttachment and movementAttachment:IsA("Attachment") and type(slimeId) == "string" and type(mutationId) == "string" then
				billboardEntryId = SlimeSlice.actions.addSlime(
					movementAttachment,
					slimeId,
					mutationId,
					"event"
				)
			end
		end

		local function updateEligibility()
			local carrierUserId = slime:GetAttribute(Config.CarrierAttribute) or 0
			prompt.Enabled = carrierUserId == 0
			if not prompt.Enabled then highlight.Enabled = false end
		end
		table.insert(promptConnections, slime:GetAttributeChangedSignal(Config.CarrierAttribute):Connect(updateEligibility))
		table.insert(promptConnections, prompt.PromptShown:Connect(function() highlight.Enabled = true end))
		table.insert(promptConnections, prompt.PromptHidden:Connect(function() highlight.Enabled = false end))
		table.insert(promptConnections, slime.Destroying:Connect(disconnectPrompt))
		updateEligibility()
	end

	workspace.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "EventSlime"
			or descendant.Name == "CarryPrompt"
			or descendant.Name == "CarryHighlight"
			or descendant.Name == "MovementAttachment"
		then
			task.defer(bindPrompt)
		end
	end)
	task.defer(bindPrompt)

	RunService.PreSimulation:Connect(function()
		for _, player in Players:GetPlayers() do
			if player:GetAttribute(Config.CarryingAttribute) == true and player.Character then
				applyOffset(player.Character, "RightShoulder", RIGHT_SHOULDER)
				applyOffset(player.Character, "LeftShoulder", LEFT_SHOULDER)
				applyOffset(player.Character, "RightElbow", RIGHT_ELBOW)
				applyOffset(player.Character, "LeftElbow", LEFT_ELBOW)
			end
		end
	end)
end

return SlimeCarryClient
