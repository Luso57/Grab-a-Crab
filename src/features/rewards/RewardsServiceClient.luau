--!strict

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local StarterPackRoot = require(script.Parent.UI.StarterPackRoot)
local StarterPackAnnouncement = require(script.Parent.UI.StarterPackAnnouncement)

local RewardsServiceClient = {}
local initialized = false
local showAcquired: (() -> ())? = nil

local function isStandingOnDeck(deck: BasePart): boolean
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0
		or humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	local relative = deck.CFrame:PointToObjectSpace(root.Position)
	local deckTop = deck.Size.Y / 2
	return math.abs(relative.X) <= deck.Size.X / 2
		and math.abs(relative.Z) <= deck.Size.Z / 2
		and relative.Y >= deckTop
		and relative.Y <= deckTop + 6
end

function RewardsServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local open = Vide.source(false)
	local claimed = Vide.source(Data.starterPackClaimed())
	local priceText = Vide.source("18")
	Networker.client.new("RewardsService", self)
	showAcquired = StarterPackAnnouncement.mount(playerGui)
	Data.starterPackClaimed.Changed(function(value: boolean)
		claimed(value)
		if value then
			open(false)
		end
	end)
	Vide.mount(function()
		return StarterPackRoot({
			isOpen = open,
			priceText = priceText,
			onBuy = function()
				if claimed() then
					return
				end
				local ok, err = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, ProductIds.StarterPack)
				if not ok then
					warn(`Could not open Starter Pack purchase: {err}`)
				end
			end,
			onClose = function()
				open(false)
			end,
		})
	end, playerGui)

	task.spawn(function()
		local trackedPlot: Model? = nil
		local deck: BasePart? = nil
		local wasOnDeck = false
		while player.Parent and playerGui.Parent do
			local plot = PlotServiceClient:getLocalPlot()
			local plotModel = if plot then plot.model else nil
			if plotModel ~= trackedPlot then
				trackedPlot = plotModel
				deck = nil
				wasOnDeck = false
				open(false)
				local rewardFolder = if plotModel then plotModel:FindFirstChild("like reward") else nil
				local reward = if rewardFolder then rewardFolder:FindFirstChild("Like Reward") else nil
				local candidate = if reward then reward:FindFirstChild("GreenDeck") else nil
				if candidate and candidate:IsA("BasePart") then
					deck = candidate
				end
			end

			local onDeck = deck ~= nil and deck.Parent ~= nil and isStandingOnDeck(deck)
			if onDeck and not wasOnDeck and not claimed() then
				open(true)
			elseif not onDeck and wasOnDeck then
				open(false)
			end
			wasOnDeck = onDeck
			task.wait(0.12)
		end
	end)
end

function RewardsServiceClient:showStarterPackAcquired()
	local show = showAcquired
	if show then
		show()
	end
end

return RewardsServiceClient
