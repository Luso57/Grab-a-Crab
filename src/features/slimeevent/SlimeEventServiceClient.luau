local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local MusicController = require(ReplicatedStorage.Source.Features.App.MusicController)
local NotificationSlice = require(ReplicatedStorage.Source.Features.App.NotificationSlice)
local Config = require(script.Parent.SlimeEventConfig)
local SlapToolClient = require(script.Parent.Modules.SlapToolClient)
local SlimeCarryClient = require(script.Parent.Modules.SlimeCarryClient)

local SlimeEventServiceClient = {}

function SlimeEventServiceClient.init(self: SlimeEventServiceClient)
	self.networker = Networker.client.new(Config.NetworkTag, self)
	self.networker:fire("requestEventState")
	SlimeCarryClient.init()
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
