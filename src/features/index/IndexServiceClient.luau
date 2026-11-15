--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local PopupMenuState = require(ReplicatedStorage.Source.Game.PopupMenuState)
local IndexMilestones = require(script.Parent.Modules.IndexMilestones)
local CrabSizeIndex = require(script.Parent.Modules.CrabSizeIndex)
local IndexButton = require(script.Parent.UI.IndexButton)
local IndexRoot = require(script.Parent.UI.IndexRoot)
local GrowthLuckHud = require(script.Parent.UI.GrowthLuckHud)
local ShopPurchaseEffect = require(ReplicatedStorage.Source.Features.Shop.UI.ShopPurchaseEffect)
local MoneyServiceClient = require(ReplicatedStorage.Source.Features.Money.MoneyServiceClient)
local ServerLuck = require(ReplicatedStorage.Source.Features.Monotization.Modules.LuckBoost)

local IndexServiceClient = {}
local initialized = false
local pendingClaims: { [string]: Vector2 } = {}
local activeClaimEffects = 0
local playConfetti: ((Vector2) -> ())? = nil
local playGrowthReward: ((Vector2, () -> ()) -> ())? = nil
local hudBaseLuck = Vide.source(1)

function IndexServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local isOpen = PopupMenuState.isOpen("Index")
	local otherMenuOpen = PopupMenuState.isOtherOpen("Index")
	local discovered = Vide.source(Data.discoveredCrabs())
	local discoveredBySize = Vide.source(Data.discoveredCrabSizes())
	local claimed = Vide.source(Data.claimedIndexMilestones())
	local starterPackClaimed = Vide.source(Data.starterPackClaimed())
	hudBaseLuck(IndexMilestones.growthLuck(claimed(), starterPackClaimed()))
	local serverMultiplier = Vide.source(ServerLuck.getMultiplier())
	local remainingSeconds = Vide.source(ServerLuck.getRemaining())
	local function updateServerLuck()
		local now = Workspace:GetServerTimeNow()
		local currentMultiplier = ServerLuck.getMultiplier(now)
		if serverMultiplier() ~= currentMultiplier then
			serverMultiplier(currentMultiplier)
		end
		remainingSeconds(ServerLuck.getRemaining(now))
	end
	Workspace:GetAttributeChangedSignal(ServerLuck.MULTIPLIER_ATTRIBUTE):Connect(updateServerLuck)
	Workspace:GetAttributeChangedSignal(ServerLuck.EXPIRES_AT_ATTRIBUTE):Connect(updateServerLuck)
	task.spawn(function()
		while playerGui.Parent do
			updateServerLuck()
			task.wait(1)
		end
	end)
	local networker = Networker.client.new("IndexService", self)
	local _, feedback = ShopPurchaseEffect.mount(playerGui, "IndexClaimConfetti", 129833990317615, 52)
	playConfetti = feedback
	Data.discoveredCrabs.Changed(function(value: { [string]: boolean })
		discovered(value)
	end)
	Data.discoveredCrabSizes.Changed(function(value: { [string]: boolean })
		discoveredBySize(value)
	end)
	Data.claimedIndexMilestones.Changed(function(value: { [string]: boolean })
		claimed(value)
		if next(pendingClaims) == nil and activeClaimEffects == 0 then
			hudBaseLuck(math.max(hudBaseLuck(), IndexMilestones.growthLuck(value, starterPackClaimed())))
		end
	end)
	Data.starterPackClaimed.Changed(function(value: boolean)
		starterPackClaimed(value)
		hudBaseLuck(math.max(hudBaseLuck(), IndexMilestones.growthLuck(claimed(), value)))
	end)
	local function hasClaimableReward(): boolean
		local savedClaims = claimed()
		local knownCrabs = discovered()
		local knownSizes = discoveredBySize()
		for _, sizeName in CrabSizeIndex.names do
			local target = IndexMilestones.nextUnclaimed(sizeName, savedClaims)
			if target and IndexMilestones.countDiscovered(sizeName, knownCrabs, knownSizes) >= target then
				return true
			end
		end
		return false
	end
	playGrowthReward = GrowthLuckHud.mount(playerGui, function()
		return hudBaseLuck() * serverMultiplier()
	end, serverMultiplier, remainingSeconds, function()
		PopupMenuState.toggle("Index")
	end)

	IndexButton.mount(playerGui, function()
		PopupMenuState.toggle("Index")
	end, hasClaimableReward)
	Vide.mount(function()
		return IndexRoot({
			isOpen = isOpen,
			otherMenuOpen = otherMenuOpen,
			discovered = discovered,
			discoveredBySize = discoveredBySize,
			claimed = claimed,
			onClaim = function(sizeName: string, target: number, startPosition: Vector2)
				local key = IndexMilestones.key(sizeName, target)
				if next(pendingClaims) ~= nil or activeClaimEffects > 0 then
					return
				end
				pendingClaims[key] = startPosition
				task.delay(8, function()
					if pendingClaims[key] == startPosition then
						pendingClaims[key] = nil
						if next(pendingClaims) == nil and activeClaimEffects == 0 then
								hudBaseLuck(math.max(hudBaseLuck(), IndexMilestones.growthLuck(claimed(), starterPackClaimed())))
						end
					end
				end)
				networker:fire("claim", sizeName, target)
			end,
			onClose = function()
				PopupMenuState.close("Index")
			end,
		})
	end, playerGui)
end

function IndexServiceClient:claimSucceeded(sizeName: any, target: any, newGrowthLuck: any)
	if typeof(sizeName) ~= "string" or typeof(target) ~= "number"
		or typeof(newGrowthLuck) ~= "number" or newGrowthLuck ~= newGrowthLuck then
		return
	end
	local key = IndexMilestones.key(sizeName, target)
	local startPosition = pendingClaims[key]
	if not startPosition then
		return
	end
	pendingClaims[key] = nil
	activeClaimEffects += 1
	local confetti = playConfetti
	if confetti then
		confetti(startPosition)
	end
	MoneyServiceClient:playCollection(startPosition)
	local function finish()
		hudBaseLuck(math.max(hudBaseLuck(), newGrowthLuck))
		activeClaimEffects -= 1
	end
	local play = playGrowthReward
	if play then
		play(startPosition, finish)
	else
		finish()
	end
end

return IndexServiceClient
