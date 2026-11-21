--!strict

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Data = require(ReplicatedStorage.Source.Game.Data).server
local Money = require(ReplicatedStorage.Source.Game.Money)
local Eggs = require(ReplicatedStorage.Source.Features.Egg.Modules.Eggs)
local LuckConfig = require(ReplicatedStorage.Source.Features.EggConveyor.Modules.LuckConfig)
local ProductIds = require(ReplicatedStorage.Source.Features.Monotization.productids)
local EggConveyorServer = require(ServerScriptService.Features.EggConveyor.Classes.EggConveyorServer)

local EggConveyorServiceServer = {}
local initialized = false
local templates: { Model } = {}
local active: { [Model]: EggConveyorServer.EggConveyorServer } = {}
local buying: { [Player]: boolean } = {}
local networker = nil

local productIdByRarity = {
    Common = ProductIds.CommonCrab,
    Uncommon = ProductIds.UncommonCrab,
    Rare = ProductIds.RareCrab,
    Epic = ProductIds.EpicCrab,
    Legendary = ProductIds.LegendaryCrab,
    Mythic = ProductIds.MythicCrab,
}

local EMPTY_PENDING_EGG_PURCHASE = {
    productId = 0,
    eggId = "",
    isGiganticEgg = false,
    intentId = "",
}

local function getSavedLuck(player: Player, data: any): number
    local luck = LuckConfig.normalizeLuck(data.conveyorLuck())
    local profile = Data.Service:getProfile(player)
    local saved = if profile then profile.Data else nil
    local oldLevel = if typeof(saved) == "table" then saved.conveyorLevel else nil
    if typeof(oldLevel) == "number" and oldLevel == oldLevel and oldLevel ~= math.huge and oldLevel ~= -math.huge then
        if luck == 0 then
            luck = LuckConfig.normalizeLuck((math.max(1, math.floor(oldLevel)) - 1) * LuckConfig.LUCK_PER_UPGRADE)
        end
        saved.conveyorLevel = nil
    end
    if data.conveyorLuck() ~= luck then
        data.conveyorLuck(luck)
    end
    return luck
end

local function getOwnedPlot(player: Player): any
    local PlotServiceServer = require(ServerScriptService.Features.Plots.PlotServiceServer)
    local plot = PlotServiceServer:getPlot(player)
    if plot and plot:getOwner() == player then
        return plot
    end
    return nil
end

local function isNearSign(player: Player, plotModel: Model): boolean
    local sign = plotModel:FindFirstChild("MoreLuckSign")
    local panel = if sign then sign:FindFirstChild("FrontPanel") else nil
    local character = player.Character
    local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
    local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
    return panel ~= nil and panel:IsA("BasePart")
        and root ~= nil and root:IsA("BasePart")
        and humanoid ~= nil and humanoid.Health > 0
        and (root.Position - panel.Position).Magnitude <= 18
end

function EggConveyorServiceServer:init()
    if initialized then
        return
    end
    templates = Eggs.getTemplates()
    networker = Networker.server.new("EggConveyor", self, { self.ready, self.buyUpgrade, self.cancelEggProductPurchase })
    Players.PlayerRemoving:Connect(function(player)
        buying[player] = nil
    end)
    initialized = true
end

function EggConveyorServiceServer:start(plotModel: Model)
    if active[plotModel] then
        return
    end
    if not initialized or #templates == 0 then
        warn("Egg conveyor is unavailable: no egg templates loaded")
        return
    end
    local conveyor = EggConveyorServer.new(plotModel, templates, function(player: Player, eggId: string, isGiganticEgg: boolean)
        if not networker or player.Parent ~= Players then
            return
        end
        local data = Data.Service:waitForData(player)
        if not data or player.Parent ~= Players then
            return
        end
        local rarity = Eggs.getRarity(eggId)
        local productId = if rarity then productIdByRarity[rarity] else nil
        if not productId then
            networker:fire(player, "showNotEnoughMoney")
            return
        end

        local pending = data.pendingEggProductPurchase()
        if pending.productId ~= 0 then
            networker:fire(player, "showNotEnoughMoney")
            return
        end

        local intentId = HttpService:GenerateGUID(false)
        data.pendingEggProductPurchase({
            productId = productId,
            eggId = eggId,
            isGiganticEgg = isGiganticEgg,
            intentId = intentId,
        })
        networker:fire(player, "showNotEnoughMoney", productId, intentId)
	end, function(player: Player)
		if networker and player.Parent == Players then
			networker:fire(player, "showTutorialPurchaseBlocked")
		end
	end, function(player: Player)
        if networker and player.Parent == Players then
            networker:fire(player, "eggPurchased")
        end
    end)
    if not conveyor then
        return
    end
    active[plotModel] = conveyor
    conveyor:start()
end

function EggConveyorServiceServer:cancelEggProductPurchase(player: Player, intentId: any)
    if typeof(intentId) ~= "string" or #intentId > 64 or player.Parent ~= Players then
        return
    end
    local data = Data.Service:waitForData(player)
    if not data or player.Parent ~= Players then
        return
    end
    local pending = data.pendingEggProductPurchase()
    if pending.intentId == intentId and pending.productId > 0 then
        data.pendingEggProductPurchase(table.clone(EMPTY_PENDING_EGG_PURCHASE))
    end
end

function EggConveyorServiceServer:ready(player: Player)
    local data = Data.Service:waitForData(player)
    if not data or player.Parent ~= Players then
        return
    end
    local plot = getOwnedPlot(player)
    if plot then
        plot.model:SetAttribute("ConveyorLuck", getSavedLuck(player, data))
        self:start(plot.model)
    end
end

function EggConveyorServiceServer:buyUpgrade(player: Player)
    if buying[player] then
        return
    end
    buying[player] = true
    local ok, err = pcall(function()
        local data = Data.Service:waitForData(player)
        if not data or player.Parent ~= Players then
            return
        end
        local plot = getOwnedPlot(player)
        if not plot or not isNearSign(player, plot.model) then
            return
        end

        local luck = getSavedLuck(player, data)
        local price = LuckConfig.getUpgradePrice(luck)
        if not price then
            return
        end
        if LuckConfig.countDiscovered(data.discoveredCrabs()) < LuckConfig.getRequiredDiscoveries(luck) then
            return
        end
        local money = Money.get(data, "money")
        if Money.compare(money, tostring(price)) < 0 then
            return
        end

        Money.set(data, "money", Money.subtract(money, tostring(price)))
        local newLuck = luck + LuckConfig.LUCK_PER_UPGRADE
        data.conveyorLuck(newLuck)
        plot.model:SetAttribute("ConveyorLuck", newLuck)
    end)
    buying[player] = nil
    if not ok then
        warn("Egg conveyor upgrade failed:", err)
    end
end

function EggConveyorServiceServer:stop(plotModel: Model)
    local conveyor = active[plotModel]
    if conveyor then
        active[plotModel] = nil
        conveyor:stop()
    end
end

return EggConveyorServiceServer
