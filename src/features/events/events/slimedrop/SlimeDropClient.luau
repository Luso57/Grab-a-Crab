local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local TutorialGuide = require(ReplicatedStorage.Source.Features.Tutorial.Modules.TutorialGuide)
local Config = require(ReplicatedStorage.Source.Features.Events.Events.Slimedrop.SlimeDropConfig)
local SlapToolClient = require(script.Parent.Modules.SlapToolClient)
local SlimeCarryClient = require(script.Parent.Modules.SlimeCarryClient)

local SlimeDropClient = {
	initialized = false,
}

local function getRootAttachment(): Attachment?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local attachment = root:FindFirstChild("RootAttachment")
	return if attachment and attachment:IsA("Attachment") then attachment else nil
end

local function watchDeliveryGuide()
	task.spawn(function()
		local currentRoot: Attachment? = nil
		local currentTarget: BasePart? = nil
		local cleanup = function() end
		while true do
			task.wait(0.15)
			local isCarrying = Players.LocalPlayer:GetAttribute(Config.CarryingAttribute) == true
			local plot = if isCarrying then PlotServiceClient:getLocalPlayerPlot() else nil
			local root = if isCarrying then getRootAttachment() else nil
			local target = if plot and not plot.destroyed then plot.playpenBase else nil
			if root ~= currentRoot or target ~= currentTarget or (target and not target.Parent) then
				cleanup()
				currentRoot = root
				currentTarget = target
				cleanup = if root and target and target.Parent
					then TutorialGuide.create(root, target)
					else function() end
			end
		end
	end)
end
function SlimeDropClient.init(self: SlimeDropClient)
	if self.initialized then return end
	self.initialized = true
	self.networker = Networker.client.new(Config.NetworkTag, self)
	SlimeCarryClient.init()
	watchDeliveryGuide()
	self.cleanups = {}
	local player = Players.LocalPlayer

	local function bind(instance: Instance)
		if not SlapToolClient.isBat(instance) or self.cleanups[instance] then return end
		self.cleanups[instance] = SlapToolClient.bind(instance :: Tool, function()
			self.networker:fire("requestSwing")
		end)
		instance.Destroying:Once(function()
			local cleanup = self.cleanups[instance]
			if cleanup then
				cleanup()
				self.cleanups[instance] = nil
			end
		end)
	end

	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(bind)
		for _, child in character:GetChildren() do bind(child) end
	end

	local backpack = player:WaitForChild("Backpack")
	backpack.ChildAdded:Connect(bind)
	for _, child in backpack:GetChildren() do bind(child) end
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then watchCharacter(player.Character) end
end

function SlimeDropClient.start(self: SlimeDropClient)
	self:init()
end

function SlimeDropClient.stop(_self: SlimeDropClient)
	-- Server cleanup removes event tools and carrying state. Persistent listeners
	-- remain ready for the next Slime Drop without being duplicated.
end
function SlimeDropClient.swingReplicated(_self: SlimeDropClient, attackerUserId: number)
	local attacker = Players:GetPlayerByUserId(attackerUserId)
	if attacker and attacker.Character then SlapToolClient.playVisual(attacker.Character) end
end

type SlimeDropClient = typeof(SlimeDropClient) & {
	initialized: boolean,
	networker: Networker.Client,
	cleanups: { [Instance]: () -> () },
}

return SlimeDropClient :: SlimeDropClient

