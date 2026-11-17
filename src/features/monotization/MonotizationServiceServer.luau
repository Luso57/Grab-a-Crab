--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local ServerLuck = require(ReplicatedStorage.Source.Features.Monotization.Modules.LuckBoost)
local CoinBundles = require(ReplicatedStorage.Source.Features.Monotization.Modules.CoinBundles)
local InventoryServiceServer = require(ServerScriptService.Features.Inventory.InventoryServiceServer)
local TankServiceServer = require(ServerScriptService.Features.Tanks.TankServiceServer)
local ShopServiceServer = require(ServerScriptService.Features.Shop.ShopServiceServer)
local DecorShopServiceServer = require(ServerScriptService.Features.DecorShop.DecorShopServiceServer)
local ShopMonoServiceServer = require(ServerScriptService.Features.Shopmono.ShopMonoServiceServer)
local IncubatorServiceServer = require(ServerScriptService.Features.Incubators.IncubatorServiceServer)
local TutorialServiceServer = require(ServerScriptService.Features.Tutorial.TutorialServiceServer)

local MonotizationServiceServer = {}
-- Temporary Studio-only override so the owner can test manual tank collection.
local STUDIO_AUTO_COLLECT_DISABLED_USER_ID = 9622166703
local initialized = false
local processingByPlayer: { [Player]: boolean } = {}
local feedbackByReceipt: { [string]: { player: Player, itemId: string, instanceId: string } } = {}
local boostByReceipt: { [string]: { player: Player, multiplier: number } } = {}
local coinsByReceipt: { [string]: { player: Player, amount: string } } = {}
local rollAgainByReceipt: { [string]: { player: Player, instanceId: string, crabId: string, weightGrams: number } } = {}
local hatchNowByReceipt: { [string]: { player: Player, instanceId: string, crabId: string, weightGrams: number, eggId: string?, pivot: CFrame?, scale: number?, direction: Vector3? } } = {}
local autoCollectCheckVersion: { [Player]: number } = {}
local boostVersion = 0

local boostByProductId: { [number]: number } = {
	[ProductIds.ServerLuckDouble] = 2,
	[ProductIds.ServerLuckQuadruple] = 4,
}

local eggRarityByProductId: { [number]: string } = {
	[ProductIds.CommonCrab] = "Common",
	[ProductIds.UncommonCrab] = "Uncommon",
	[ProductIds.RareCrab] = "Rare",
	[ProductIds.EpicCrab] = "Epic",
	[ProductIds.LegendaryCrab] = "Legendary",
	[ProductIds.MythicCrab] = "Mythic",
}

local eggRandom = Random.new()

local function chooseEggForRarity(rarity: string): string?
	local candidates: { string } = {}
	for _, template in Eggs.getTemplates() do
		if Eggs.getRarity(template.Name) == rarity then
			table.insert(candidates, template.Name)
		end
	end
	return if #candidates > 0 then candidates[eggRandom:NextInteger(1, #candidates)] else nil
end

local itemByProductId: { [number]: string } = {
	[ProductIds.InstantHatch] = "Incubator.InstantHatch",
	[ProductIds.HugeTank] = "Tank.Huge",
	[ProductIds.TankIncomeOnePointFive] = "Crab.PirateCrab",
	[ProductIds.TankIncomeDouble] = "Crab.kingCrab",
	[ProductIds.Incubator] = "Incubator",
	[ProductIds.SmallTank] = "Tank.Small",
	[ProductIds.MediumTank] = "Tank.Medium",
	[ProductIds.LargeTank] = "Tank.Large",
	[ProductIds.UmbrellaDecor] = "Decor.Umbrella",
	[ProductIds.TreasureDecor] = "Decor.TreasureChest",
	[ProductIds.SkullDecor] = "Decor.Skull",
	[ProductIds.SeashellDecor] = "Decor.Seashell",
	[ProductIds.SandcastleDecor] = "Decor.Sandcastle",
	[ProductIds.PirateShipDecor] = "Decor.PirateShip",
}

local function scheduleBoostExpiry()
	boostVersion += 1
	local version = boostVersion
	task.delay(ServerLuck.getRemaining(), function()
		if version ~= boostVersion then
			return
		end
		local remaining = ServerLuck.getRemaining()
		if remaining > 0 then
			task.wait(remaining)
		end
		if version == boostVersion and ServerLuck.getRemaining() == 0 then
			Workspace:SetAttribute(ServerLuck.MULTIPLIER_ATTRIBUTE, 1)
			Workspace:SetAttribute(ServerLuck.EXPIRES_AT_ATTRIBUTE, 0)
		end
	end)
end

local function activateBoost(player: Player, purchasedMultiplier: number)
	local now = Workspace:GetServerTimeNow()
	local multiplier = math.max(ServerLuck.getMultiplier(now), purchasedMultiplier)
	Workspace:SetAttribute(ServerLuck.MULTIPLIER_ATTRIBUTE, multiplier)
	Workspace:SetAttribute(ServerLuck.EXPIRES_AT_ATTRIBUTE, now + ServerLuck.DURATION_SECONDS)
	scheduleBoostExpiry()
	local announced, err = pcall(ShopMonoServiceServer.announceServerLuck, ShopMonoServiceServer, player.Name, purchasedMultiplier)
	if not announced then
		warn(`Could not announce server luck purchase: {err}`)
	end
end

local function grantReceipt(player: Player, receiptInfo: any): Enum.ProductPurchaseDecision
	local itemId = itemByProductId[receiptInfo.ProductId]
	local purchasedMultiplier = boostByProductId[receiptInfo.ProductId]
	local coinBundle = CoinBundles.byProductId[receiptInfo.ProductId]
	local isMoreInventory = receiptInfo.ProductId == ProductIds.MoreInventory
	local isRollAgain = receiptInfo.ProductId == ProductIds.RollAgain
	local isHatchNow = receiptInfo.ProductId == ProductIds.HatchNow
	local eggProductRarity = eggRarityByProductId[receiptInfo.ProductId]
	local purchaseId = receiptInfo.PurchaseId
	if (not itemId and not purchasedMultiplier and not coinBundle and not isMoreInventory and not isRollAgain and not isHatchNow and not eggProductRarity)
		or typeof(purchaseId) ~= "string" or purchaseId == "" then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local data = Data.Service:waitForData(player)
	local profile = Data.Service:getProfile(player)
	if not data or not profile or not profile:IsActive() or player.Parent ~= Players then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptValue = data.processedProductReceipts()[purchaseId]
	if isHatchNow then
		if not receiptValue then
			local instanceId, crabId, weight, eggId, pivot, scale, direction, value = IncubatorServiceServer:grantHatchNowReceipt(player, purchaseId)
			if not value then return Enum.ProductPurchaseDecision.NotProcessedYet end
			receiptValue = value
			if instanceId and crabId and weight then
				hatchNowByReceipt[purchaseId] = { player = player, instanceId = instanceId, crabId = crabId, weightGrams = weight, eggId = eggId, pivot = pivot, scale = scale, direction = direction }
			end
		end
	elseif isRollAgain then
		local alreadyProcessed = receiptValue ~= nil
		local value, instanceId, crabId, weightGrams = InventoryServiceServer:grantRollAgainReceipt(player, purchaseId)
		if not value then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		receiptValue = value
		if not alreadyProcessed and instanceId and crabId and weightGrams then
			rollAgainByReceipt[purchaseId] = { player = player, instanceId = instanceId, crabId = crabId, weightGrams = weightGrams }
		end
	elseif not receiptValue then
		if isMoreInventory then
			local purchaseCount = data.inventoryCapacityPurchases() + 1
			data.inventoryCapacityPurchases(purchaseCount)
			receiptValue = `InventoryCapacity:{purchaseCount}`
			data.processedProductReceipts[purchaseId](receiptValue)
		elseif coinBundle then
			local balance = Money.get(data, "money")
			local highestMoney = Money.get(data, "maxMoney")
			local highest = if Money.compare(balance, highestMoney) >= 0 then balance else highestMoney
			local amount = CoinBundles.getAmount(highest, coinBundle.multiplier)
			if Money.compare(amount, "0") <= 0 then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			Money.set(data, "money", Money.add(balance, amount))
			receiptValue = "Coins"
			data.processedProductReceipts[purchaseId](receiptValue)
			coinsByReceipt[purchaseId] = { player = player, amount = amount }
		elseif eggProductRarity then
			local pending = data.pendingEggProductPurchase()
			local eggId: string? = nil
			local isGiganticEgg = false
			if pending.productId == receiptInfo.ProductId
				and Eggs.get(pending.eggId)
				and Eggs.getRarity(pending.eggId) == eggProductRarity then
				eggId = pending.eggId
				isGiganticEgg = pending.isGiganticEgg
			else
				eggId = chooseEggForRarity(eggProductRarity)
			end
			if not eggId then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end

			local instanceId = InventoryServiceServer:grantItem(player, "Egg." .. eggId, nil, true, isGiganticEgg)
			if not instanceId then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			TutorialServiceServer:eggBought(player, instanceId)
			if pending.productId == receiptInfo.ProductId then
				data.pendingEggProductPurchase({ productId = 0, eggId = "", isGiganticEgg = false, intentId = "" })
			end
			receiptValue = `Egg:{instanceId}`
			data.processedProductReceipts[purchaseId](receiptValue)
			feedbackByReceipt[purchaseId] = { player = player, itemId = "Egg." .. eggId, instanceId = instanceId }
		elseif purchasedMultiplier then
			receiptValue = `ServerLuck:{purchasedMultiplier}`
			data.processedProductReceipts[purchaseId](receiptValue)
			boostByReceipt[purchaseId] = { player = player, multiplier = purchasedMultiplier }
		else
			local instanceId = InventoryServiceServer:grantItem(player, itemId, nil, true)
			if not instanceId then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			receiptValue = instanceId
			data.processedProductReceipts[purchaseId](receiptValue)
			feedbackByReceipt[purchaseId] = { player = player, itemId = itemId, instanceId = instanceId }
		end
	end

	local deadline = os.clock() + 30
	while profile:IsActive() and player.Parent == Players and os.clock() < deadline do
		local savedReceipts = profile.LastSavedData.processedProductReceipts
		if savedReceipts and savedReceipts[purchaseId] == receiptValue then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		profile:Save()
		task.wait(5)
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function equipPurchasedItem(player: Player, instanceId: string)
	InventoryServiceServer:equipGrantedItem(player, instanceId)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and humanoid.Health > 0 then
		return
	end
	task.spawn(function()
		while player.Parent == Players do
			local currentCharacter = player.Character
			local currentHumanoid = if currentCharacter then currentCharacter:FindFirstChildOfClass("Humanoid") else nil
			if currentHumanoid and currentHumanoid.Health > 0 then
				InventoryServiceServer:equipGrantedItem(player, instanceId)
				return
			end
			task.wait(0.2)
		end
	end)
end

local function processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	while processingByPlayer[player] and player.Parent == Players do
		task.wait(0.1)
	end
	if player.Parent ~= Players then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	processingByPlayer[player] = true
	local ok, result = pcall(grantReceipt, player, receiptInfo)
	processingByPlayer[player] = nil
	if not ok then
		warn(`Product receipt failed for {player.Name}: {result}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if result == Enum.ProductPurchaseDecision.PurchaseGranted then
		local rollAgain = rollAgainByReceipt[receiptInfo.PurchaseId]
		if rollAgain and rollAgain.player == player then
			rollAgainByReceipt[receiptInfo.PurchaseId] = nil
			local notified, err = pcall(IncubatorServiceServer.showRollAgain, IncubatorServiceServer, player, rollAgain.instanceId, rollAgain.crabId, rollAgain.weightGrams)
			if not notified then
				warn(`Could not replay Roll Again hatch: {err}`)
			end
		end
		local hatchNow = hatchNowByReceipt[receiptInfo.PurchaseId]
		if hatchNow and hatchNow.player == player then
			hatchNowByReceipt[receiptInfo.PurchaseId] = nil
			IncubatorServiceServer:showHatch(player, hatchNow.crabId, hatchNow.weightGrams, hatchNow.eggId, hatchNow.pivot, hatchNow.scale, hatchNow.direction, hatchNow.instanceId)
		end
		local coins = coinsByReceipt[receiptInfo.PurchaseId]
		if coins and coins.player == player then
			coinsByReceipt[receiptInfo.PurchaseId] = nil
			local notified, err = pcall(ShopMonoServiceServer.showCoinsPurchased, ShopMonoServiceServer, player, coins.amount)
			if not notified then
				warn(`Could not show coin purchase effect: {err}`)
			end
		end
		local boost = boostByReceipt[receiptInfo.PurchaseId]
		if boost and boost.player == player then
			boostByReceipt[receiptInfo.PurchaseId] = nil
			activateBoost(player, boost.multiplier)
		end
		local feedback = feedbackByReceipt[receiptInfo.PurchaseId]
		if feedback and feedback.player == player then
			feedbackByReceipt[receiptInfo.PurchaseId] = nil
			if string.match(feedback.itemId, "^Egg%.") or feedback.itemId == "Incubator.InstantHatch" or feedback.itemId == "Tank.Huge"
				or feedback.itemId == "Crab.PirateCrab" or feedback.itemId == "Crab.kingCrab" then
				equipPurchasedItem(player, feedback.instanceId)
			else
				local decorId = string.match(feedback.itemId, "^Decor%.(.+)$")
				if decorId then
					DecorShopServiceServer:showRobuxPurchased(player, decorId)
				else
					local shopId = string.match(feedback.itemId, "^Tank%.(.+)$") or feedback.itemId
					ShopServiceServer:showRobuxPurchased(player, shopId, feedback.instanceId)
				end
			end
		end
	end
	return result
end

local function setAutoCollectOwnership(player: Player, ownsPass: boolean, showThanks: boolean, version: number)
	local data = Data.Service:waitForData(player)
	if not data or player.Parent ~= Players or autoCollectCheckVersion[player] ~= version then
		return
	end
	local enabled = ownsPass and not (RunService:IsStudio() and player.UserId == STUDIO_AUTO_COLLECT_DISABLED_USER_ID)
	if data.autoCollectOwned() ~= enabled then
		data.autoCollectOwned(enabled)
	end
	if enabled and showThanks then
		local collected, collectError = pcall(TankServiceServer.collectAllMoneyPads, TankServiceServer, player)
		if not collected then
			warn(`Could not collect tank earnings after AutoCollect purchase: {collectError}`)
		end
		local notified, notifyError = pcall(ShopMonoServiceServer.showAutoCollectPurchased, ShopMonoServiceServer, player)
		if not notified then
			warn(`Could not show AutoCollect purchase strip: {notifyError}`)
		end
	end
end

local function checkAutoCollectOwnership(player: Player)
	local version = (autoCollectCheckVersion[player] or 0) + 1
	autoCollectCheckVersion[player] = version
	task.spawn(function()
		local ok, ownsPass = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, ProductIds.AutoCollect)
		if not ok then
			warn(`Could not check AutoCollect pass ownership for {player.Name}: {ownsPass}`)
			return
		end
		setAutoCollectOwnership(player, ownsPass, false, version)
	end)
end

function MonotizationServiceServer:init()
	if initialized then
		return
	end
	initialized = true
	if ServerLuck.getMultiplier() == 1 then
		Workspace:SetAttribute(ServerLuck.MULTIPLIER_ATTRIBUTE, 1)
		Workspace:SetAttribute(ServerLuck.EXPIRES_AT_ATTRIBUTE, 0)
	else
		scheduleBoostExpiry()
	end
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamePassId: number, wasPurchased: boolean)
		if gamePassId ~= ProductIds.AutoCollect or not wasPurchased or player.Parent ~= Players then
			return
		end
		local version = (autoCollectCheckVersion[player] or 0) + 1
		autoCollectCheckVersion[player] = version
		task.spawn(setAutoCollectOwnership, player, true, true, version)
	end)
	Players.PlayerAdded:Connect(checkAutoCollectOwnership)
	for _, player in Players:GetPlayers() do
		checkAutoCollectOwnership(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		processingByPlayer[player] = nil
		autoCollectCheckVersion[player] = nil
		for purchaseId, feedback in feedbackByReceipt do
			if feedback.player == player then
				feedbackByReceipt[purchaseId] = nil
			end
		end
		for purchaseId, boost in boostByReceipt do
			if boost.player == player then
				boostByReceipt[purchaseId] = nil
			end
		end
		for purchaseId, coins in coinsByReceipt do
			if coins.player == player then
				coinsByReceipt[purchaseId] = nil
			end
		end
		for purchaseId, rollAgain in rollAgainByReceipt do
			if rollAgain.player == player then
				rollAgainByReceipt[purchaseId] = nil
			end
		end
		for purchaseId, hatchNow in hatchNowByReceipt do
			if hatchNow.player == player then hatchNowByReceipt[purchaseId] = nil end
		end
	end)
end

return MonotizationServiceServer
