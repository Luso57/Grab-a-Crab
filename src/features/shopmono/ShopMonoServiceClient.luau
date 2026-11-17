--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).client
local PopupMenuState = require(ReplicatedStorage.Source.Game.PopupMenuState)
local ShopMonoButton = require(script.Parent.UI.ShopMonoButton)
local ShopMonoRoot = require(script.Parent.UI.ShopMonoRoot)
local ServerLuckAnnouncement = require(script.Parent.UI.ServerLuckAnnouncement)
local AutoCollectAnnouncement = require(script.Parent.UI.AutoCollectAnnouncement)
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local ServerLuck = require(ReplicatedStorage.Source.Features.Monotization.Modules.LuckBoost)
local CoinBundles = require(ReplicatedStorage.Source.Features.Monotization.Modules.CoinBundles)
local MoneyServiceClient = require(ReplicatedStorage.Source.Features.Money.MoneyServiceClient)

local ShopMonoServiceClient = {}
local initialized = false
local showAnnouncement: ((string, number) -> ())? = nil
local showAutoCollectAnnouncement: ((string?) -> ())? = nil

function ShopMonoServiceClient:init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	Networker.client.new("ShopMonoService", self)
	local isOpen = PopupMenuState.isOpen("ShopMono")
	local otherMenuOpen = PopupMenuState.isOtherOpen("ShopMono")
	local maxMoney = Vide.source(Data.maxMoney() :: any)
	local serverLuckMultiplier = Vide.source(ServerLuck.getMultiplier())
	local autoCollectPassOwned = Vide.source(Data.autoCollectOwned())
	local ownershipCheckVersion = 0
	local function refreshAutoCollectOwnership()
		ownershipCheckVersion += 1
		local version = ownershipCheckVersion
		task.spawn(function()
			local ok, ownsPass = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Players.LocalPlayer.UserId, ProductIds.AutoCollect)
			if ok and version == ownershipCheckVersion then
				autoCollectPassOwned(ownsPass)
			elseif not ok then
				warn(`Could not check AutoCollect pass ownership: {ownsPass}`)
			end
		end)
	end
	refreshAutoCollectOwnership()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number)
		if player == Players.LocalPlayer and gamePassId == ProductIds.AutoCollect then
			refreshAutoCollectOwnership()
		end
	end)
	Data.autoCollectOwned.Changed(function(owned: boolean)
		if owned then
			autoCollectPassOwned(true)
		end
	end)
	local function updateServerLuck()
		local currentMultiplier = ServerLuck.getMultiplier()
		if serverLuckMultiplier() ~= currentMultiplier then
			serverLuckMultiplier(currentMultiplier)
		end
	end
	Workspace:GetAttributeChangedSignal(ServerLuck.MULTIPLIER_ATTRIBUTE):Connect(updateServerLuck)
	Workspace:GetAttributeChangedSignal(ServerLuck.EXPIRES_AT_ATTRIBUTE):Connect(updateServerLuck)
	task.spawn(function()
		while playerGui.Parent do
			updateServerLuck()
			task.wait(1)
		end
	end)
	Data.maxMoney.Changed(function(value: any)
		maxMoney(value)
	end)
	ShopMonoButton.mount(playerGui, function()
		PopupMenuState.toggle("ShopMono")
	end)
	showAnnouncement = ServerLuckAnnouncement.mount(playerGui)
	showAutoCollectAnnouncement = AutoCollectAnnouncement.mount(playerGui)
	Vide.mount(function()
		return ShopMonoRoot({
			isOpen = isOpen,
			otherMenuOpen = otherMenuOpen,
			maxMoney = maxMoney,
			serverLuckMultiplier = serverLuckMultiplier,
			autoCollectPassOwned = autoCollectPassOwned,
			serverLuckPrice = function()
				return if serverLuckMultiplier() == 1 then "90" else "199"
			end,
			onBuyServerLuck = function()
				local productId = if ServerLuck.getMultiplier() == 1 then ProductIds.ServerLuckDouble else ProductIds.ServerLuckQuadruple
				local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, productId)
				if not ok then
					warn(`Could not open server luck purchase prompt: {err}`)
				end
			end,
			onBuyCoins = function(productId: number)
				if not CoinBundles.byProductId[productId] then
					return
				end
				local ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, productId)
				if not ok then
					warn(`Could not open coin purchase prompt: {err}`)
				end
			end,
			onBuyPass = function(passId: string)
				if passId == "AutoCollect" and autoCollectPassOwned() then
					local show = showAutoCollectAnnouncement
					if show then
						show("AUTO COLLECT PASS ALREADY OWNED")
					end
					return
				end
				local productId = if passId == "InstantHatch" then ProductIds.InstantHatch
					elseif passId == "HugeTank" then ProductIds.HugeTank
					elseif passId == "AutoCollect" then ProductIds.AutoCollect
					elseif passId == "MoreInventory" then ProductIds.MoreInventory
					elseif passId == "TankIncomeOnePointFive" then ProductIds.TankIncomeOnePointFive
					elseif passId == "TankIncomeDouble" then ProductIds.TankIncomeDouble else nil
				if not productId then
					return
				end
				local ok, err
				if passId == "AutoCollect" then
					ok, err = pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, Players.LocalPlayer, productId)
				else
					ok, err = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Players.LocalPlayer, productId)
				end
				if not ok then
					warn(`Could not open {passId} purchase prompt: {err}`)
				end
			end,
			onClose = function()
				PopupMenuState.close("ShopMono")
			end,
		})
	end, playerGui)
end

function ShopMonoServiceClient:serverLuckBought(buyerName: any, multiplier: any)
	if typeof(buyerName) == "string" and (multiplier == 2 or multiplier == 4) and showAnnouncement then
		showAnnouncement(buyerName, multiplier)
	end
end

function ShopMonoServiceClient:coinsPurchased(amount: any)
	if (typeof(amount) == "number" and amount > 0) or (typeof(amount) == "string" and amount ~= "0") then
		MoneyServiceClient:playCollection()
	end
end

function ShopMonoServiceClient:autoCollectPurchased()
	local show = showAutoCollectAnnouncement
	if show then
		show()
	end
end

return ShopMonoServiceClient
