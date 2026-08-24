local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Networker = require(ReplicatedStorage.Packages.Networker)
local MusicController = require(ReplicatedStorage.Source.Features.App.MusicController)
local NotificationSlice = require(ReplicatedStorage.Source.Features.App.NotificationSlice)
local Config = require(ReplicatedStorage.Source.Features.Events.EventConfig)
local ClientRegistry = require(ReplicatedStorage.Source.Features.Events.Registry.EventRegistryClient)

local EventServiceClient = {
	initialized = false,
}

local PHONE_SHORT_EDGE_MAX = 600

local function isPhoneViewport(): boolean
	local camera = Workspace.CurrentCamera
	if not camera or not UserInputService.TouchEnabled then return false end
	return math.min(camera.ViewportSize.X, camera.ViewportSize.Y) <= PHONE_SHORT_EDGE_MAX
end

local function resizeEventBillboard(instance: Instance)
	if instance.Name ~= "EventBillboard" or not instance:IsA("BillboardGui") then return end
	local size = if isPhoneViewport() then Config.BillboardPhoneSize else Config.BillboardSize
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

local function playStartSound(state)
	if type(state.soundId) ~= "string" or state.soundId == "" then return end
	local sound = Instance.new("Sound")
	sound.Name = "EventStarted"
	sound.SoundId = state.soundId
	sound.Volume = if type(state.soundVolume) == "number" then state.soundVolume else 1
	sound.Parent = SoundService
	sound.Ended:Once(function() sound:Destroy() end)
	sound:Play()
	Debris:AddItem(sound, 30)
end

function EventServiceClient.init(self)
	if self.initialized then return end
	self.initialized = true
	self.currentEventId = nil
	self.receivedInitialState = false
	self.networker = Networker.client.new(Config.NetworkTag, self)
	for _, controller in ClientRegistry do
		if controller.init then controller:init() end
	end
	watchEventBillboardSize()
	self.networker:fire("requestEventState")
end

function EventServiceClient.eventStateChanged(self, state)
	local wasRunning = self.currentEventId ~= nil
	local nextEventId = if state.phase == "running" then state.eventId else nil
	if self.currentEventId and self.currentEventId ~= nextEventId then
		local previousController = ClientRegistry[self.currentEventId]
		if previousController and previousController.stop then previousController:stop() end
	end

	self.currentEventId = nextEventId
	if nextEventId then
		local controller = ClientRegistry[nextEventId]
		if controller and controller.start then controller:start() end
		MusicController.startEventMusic()
		if self.receivedInitialState and not wasRunning then
			if type(state.notificationText) == "string" then
				NotificationSlice.actions.show(state.notificationText)
			end
			playStartSound(state)
		end
	else
		MusicController.stopEventMusic()
	end
	self.receivedInitialState = true
end

return EventServiceClient

