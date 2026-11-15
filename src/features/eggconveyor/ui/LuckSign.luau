--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local LuckConfig = require(ReplicatedStorage.Source.Features.EggConveyor.Modules.LuckConfig)

local create = Vide.create
local LuckSign = {}
local CLOVER_IMAGE = "rbxassetid://84144870802466"

function LuckSign.mount(plotModel: Model, playerGui: PlayerGui, balance: () -> number, discoveries: () -> { [string]: boolean }, onBuy: () -> ()): (() -> ())?
    local sign = plotModel:FindFirstChild("MoreLuckSign")
    local panel = if sign then sign:FindFirstChild("FrontPanel") else nil
    if not panel or not panel:IsA("BasePart") then
        return nil
    end

    local luck = Vide.source(LuckConfig.normalizeLuck(plotModel:GetAttribute("ConveyorLuck")))
    local owner = Vide.source(plotModel:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId)
    local luckConnection = plotModel:GetAttributeChangedSignal("ConveyorLuck"):Connect(function()
        luck(LuckConfig.normalizeLuck(plotModel:GetAttribute("ConveyorLuck")))
    end)
    local ownerConnection = plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
        owner(plotModel:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId)
    end)

    local cleanup = Vide.mount(function()
    local luckText = Vide.derive(function()
        return "LUCK " .. tostring(luck()) .. "%"
    end)
    local oddsText = Vide.derive(function()
        local weights = LuckConfig.getWeights(luck())
        return string.format(
            "C %.1f%%  U %.1f%%  R %.1f%%\nE %.1f%%  L %.1f%%  M %.1f%%",
            weights[1].weight, weights[2].weight, weights[3].weight,
            weights[4].weight, weights[5].weight, weights[6].weight
        )
    end)
    local buyText = Vide.derive(function()
        local price = LuckConfig.getUpgradePrice(luck())
        if not price then
            return "MAX LUCK"
        end
        local required = LuckConfig.getRequiredDiscoveries(luck())
        local discovered = LuckConfig.countDiscovered(discoveries())
        if discovered < required then
            return `CRABS {discovered}/{required}`
        end
        return "BUY $" .. CompactNumber.format(price)
    end)
    local canBuy = Vide.derive(function()
        local price = LuckConfig.getUpgradePrice(luck())
        return owner() and price ~= nil and balance() >= (price or math.huge)
            and LuckConfig.countDiscovered(discoveries()) >= LuckConfig.getRequiredDiscoveries(luck())
    end)
    local buttonColor = Vide.derive(function()
        local price = LuckConfig.getUpgradePrice(luck())
        if not owner() or not price then
            return Color3.fromRGB(115, 115, 115)
        end
        if LuckConfig.countDiscovered(discoveries()) < LuckConfig.getRequiredDiscoveries(luck()) then
            return Color3.fromRGB(190, 120, 35)
        end
        return if balance() < price then Color3.fromRGB(220, 48, 48) else Color3.fromRGB(32, 205, 75)
    end)
    local buttonStrokeColor = Vide.derive(function()
        local price = LuckConfig.getUpgradePrice(luck())
        if not owner() or not price then
            return Color3.fromRGB(65, 65, 65)
        end
        if LuckConfig.countDiscovered(discoveries()) < LuckConfig.getRequiredDiscoveries(luck()) then
            return Color3.fromRGB(90, 55, 15)
        end
        return if balance() < price then Color3.fromRGB(105, 15, 15) else Color3.fromRGB(9, 65, 33)
    end)
    local buySound = create "Sound" {
        Name = "BuyClickSound",
        SoundId = "rbxassetid://4612383453",
        Volume = 1,
    }
        return create "SurfaceGui" {
            Name = "MoreLuckUpgrade",
            Adornee = panel,
            Face = Enum.NormalId.Front,
            SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
            PixelsPerStud = 80,
            LightInfluence = 0,
            AlwaysOnTop = false,
            Active = true,
            ToolPunchThroughDistance = 20,
            ResetOnSpawn = false,
            create "Frame" {
                Name = "Content",
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                create "TextLabel" {
                    Name = "Title",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.1),
                    Size = UDim2.fromScale(0.94, 0.14),
                    BackgroundTransparency = 1,
                    Text = "MORE LUCK",
                    Font = Enum.Font.BuilderSansExtraBold,
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                    create "UIStroke" {
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                        Color = Color3.new(0, 0, 0),
                        Thickness = 3,
                    },
                },
                create "ImageLabel" {
                    Name = "CloverImage",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.36),
                    Size = UDim2.fromScale(0.72, 0.32),
                    BackgroundTransparency = 1,
                    Image = CLOVER_IMAGE,
                    ScaleType = Enum.ScaleType.Fit,
                },
                create "TextLabel" {
                    Name = "LuckPercent",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.6),
                    Size = UDim2.fromScale(0.9, 0.13),
                    BackgroundTransparency = 1,
                    Text = luckText,
                    Font = Enum.Font.BuilderSansExtraBold,
                    TextColor3 = Color3.fromRGB(0, 238, 30),
                    TextScaled = true,
                    create "UIStroke" {
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                        Color = Color3.new(0, 0, 0),
                        Thickness = 4,
                    },
                },
                create "TextLabel" {
                    Name = "RarityOdds",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.75),
                    Size = UDim2.fromScale(0.96, 0.15),
                    BackgroundTransparency = 1,
                    Text = oddsText,
                    Font = Enum.Font.BuilderSansBold,
                    TextColor3 = Color3.new(1, 1, 1),
                    TextScaled = true,
                    TextWrapped = true,
                    create "UIStroke" {
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                        Color = Color3.new(0, 0, 0),
                        Thickness = 2,
                    },
                },
                create "TextButton" {
                    Name = "BuyUpgrade",
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.91),
                    Size = UDim2.fromScale(0.7, 0.14),
                    BackgroundColor3 = buttonColor,
                    BorderSizePixel = 0,
                    AutoButtonColor = canBuy,
                    Active = canBuy,
                    Text = buyText,
                    Font = Enum.Font.BuilderSansExtraBold,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextStrokeColor3 = Color3.fromRGB(34, 23, 12),
                    TextStrokeTransparency = 0.35,
                    TextScaled = true,
                    Activated = function()
                        if canBuy() then
                            onBuy()
                            buySound.TimePosition = 0
                            buySound:Play()
                        end
                    end,
                    buySound,
                    create "UICorner" { CornerRadius = UDim.new(0.16, 0) },
                    create "UIStroke" { Color = buttonStrokeColor, Thickness = 4 },
                },
            },
        }
    end, playerGui)

    local function removeLegacyLettering(child: Instance)
        if child.Name == "Lettering" and child:IsA("SurfaceGui") then
            child:Destroy()
        end
    end
    local letteringConnection = panel.ChildAdded:Connect(removeLegacyLettering)
    local lettering = panel:FindFirstChild("Lettering")
    if lettering then
        removeLegacyLettering(lettering)
    end

    return function()
        letteringConnection:Disconnect()
        luckConnection:Disconnect()
        ownerConnection:Disconnect()
        cleanup()
    end
end

return LuckSign
