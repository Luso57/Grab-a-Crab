--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local IndexMilestones = require(script.Parent.Modules.IndexMilestones)
local IndexButton = require(script.Parent.UI.IndexButton)
local IndexRoot = require(script.Parent.UI.IndexRoot)
local GrowthLuckHud = require(script.Parent.UI.GrowthLuckHud)

local IndexServiceClient = {}
local initialized = false

function IndexServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local isOpen = Vide.source(false)
	local discovered = Vide.source(Data.discoveredCrabs())
	local discoveredBySize = Vide.source(Data.discoveredCrabSizes())
	local claimed = Vide.source(Data.claimedIndexMilestones())
	local networker = Networker.client.new("IndexService", self)
	Data.discoveredCrabs.Changed(function(value: { [string]: boolean })
		discovered(value)
	end)
	Data.discoveredCrabSizes.Changed(function(value: { [string]: boolean })
		discoveredBySize(value)
	end)
	Data.claimedIndexMilestones.Changed(function(value: { [string]: boolean })
		claimed(value)
	end)
	GrowthLuckHud.mount(playerGui, function()
		return IndexMilestones.growthLuck(claimed())
	end, function()
		isOpen(not isOpen())
	end)

	IndexButton.mount(playerGui, function()
		isOpen(not isOpen())
	end)
	Vide.mount(function()
		return IndexRoot({
			isOpen = isOpen,
			discovered = discovered,
			discoveredBySize = discoveredBySize,
			claimed = claimed,
			onClaim = function(sizeName: string, target: number)
				networker:fire("claim", sizeName, target)
			end,
			onClose = function()
				isOpen(false)
			end,
		})
	end, playerGui)
end

return IndexServiceClient
