local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.Networker)
local MusicController = require(ReplicatedStorage.Source.Features.App.MusicController)
local NotificationSlice = require(ReplicatedStorage.Source.Features.App.NotificationSlice)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local TutorialGuide = require(ReplicatedStorage.Source.Features.Tutorial.Modules.TutorialGuide)
local Config = require(script.Parent.SlimeEventConfig)
local SlapToolClient = require(script.Parent.Modules.SlapToolClient)
local SlimeCarryClient = require(script.Parent.Modules.SlimeCarryClient)

local SlimeEventServiceClient = {}

local PHONE_SHORT_EDGE_MAX = 600

local function isPhoneViewport(): boolean
	local camera = Workspace.CurrentCamera
	if not camera or not UserInputService.TouchEnabled then return false end
	return math.min(camera.ViewportSize.X, camera.ViewportSize.Y) <= PHONE_SHORT_EDGE_MAX
end

local function resizeEventBillboard(instance: Instance)
	if instance.Name ~= "SlimeEventBillboard" or not instance:IsA("BillboardGui") then return end
	local size = if isPhoneViewport() then Config.EventBillboardPhoneSize else Config.EventBillboardSize
	instance.Size = UDim2.fromOffset(size.X, size.Y)
end

local function resizeAllEventBillboards()
	for _, instance in Workspace:GetDescendants() do
		resizeEventBillboard(instance)
	end
end

local function watchEventBillboardSize()
	Workspace.DescendantAdded:Connect(resizeEventBillboard)
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resizeAllEventBillboards)
	local camera = Workspace.CurrentCamera
	if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeAllEventBillboards) end
	resizeAllEventBillboards()
end

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
function SlimeEventServiceClient.init(self: SlimeEventServiceClient)
	self.networker = Networker.client.new(Config.NetworkTag, self)
	self.networker:fire("requestEventState")
	SlimeCarryClient.init()
	watchEventBillboardSize()
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

function SlimeEventServiceClient.swingReplicated(_self: SlimeEventServiceClient, attackerUserId: number)
	local attacker = Players:GetPlayerByUserId(attackerUserId)
	if attacker and attacker.Character then SlapToolClient.playVisual(attacker.Character) end
end

function SlimeEventServiceClient.eventStarted(_self: SlimeEventServiceClient)
	MusicController.startEventMusic()
	NotificationSlice.actions.show(Config.EventStartNotificationText)

	local sound = Instance.new("Sound")
	sound.Name = "SlimeEventStarted"
	sound.SoundId = Config.EventStartSoundId
	sound.Volume = Config.EventStartSoundVolume
	sound.Parent = SoundService
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	Debris:AddItem(sound, 30)
end

function SlimeEventServiceClient.eventEnded(_self: SlimeEventServiceClient)
	MusicController.stopEventMusic()
end

function SlimeEventServiceClient.eventStateChanged(_self: SlimeEventServiceClient, isActive: boolean)
	if isActive then
		MusicController.startEventMusic()
	else
		MusicController.stopEventMusic()
	end
end

type SlimeEventServiceClient = typeof(SlimeEventServiceClient) & {
	networker: Networker.Client,
	cleanups: { [Instance]: () -> () },
}

return SlimeEventServiceClient :: SlimeEventServiceClient
