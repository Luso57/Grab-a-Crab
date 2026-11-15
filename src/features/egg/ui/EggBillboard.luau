--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Rarities = require(ReplicatedStorage.Source.Game.Items.Rarities)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local create = Vide.create

local EggBillboard = {}

local function makeLine(name: string, value: string, color: Color3, order: number): TextLabel
    local label = create "TextLabel" {
        Name = name,
        LayoutOrder = order,
        Size = UDim2.fromScale(1, 1 / 3),
        BackgroundTransparency = 1,
        Text = value,
        TextColor3 = color,
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0,
        TextScaled = true,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Center,
        Font = Enum.Font.BuilderSansExtraBold,
    }
    local stroke = create "UIStroke" {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        Color = Color3.new(0, 0, 0),
        Thickness = 1.5,
    }
    stroke.Parent = label
    return label
end

function EggBillboard.create(driver: BasePart, topOffset: number, eggName: string, rarity: Rarities.Rarity, price: number, isGigantic: boolean?): BillboardGui
    local billboard = create "BillboardGui" {
        Name = "EggInfoBillboard",
        Adornee = driver,
        Size = UDim2.fromScale(7.6, 3),
        SizeOffset = Vector2.new(0, 0.5),
        StudsOffsetWorldSpace = Vector3.new(0, topOffset + 0.15, 0),
        MaxDistance = 50,
        AlwaysOnTop = true,
        LightInfluence = 0,
    }
    local container = create "Frame" {
        Name = "Lines",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }
    container.Parent = billboard
    local layout = create "UIListLayout" {
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
    }
    layout.Parent = container
    local rarityLine = makeLine("Rarity", rarity, Rarities.getColor(rarity), 1)
    rarityLine.Parent = container
    local nameLine = makeLine("EggName", (if isGigantic then "GIGANTIC " else "") .. eggName, Color3.new(1, 1, 1), 2)
    if isGigantic then
        create "UIGradient" {
            Color = ColorSequence.new(Color3.fromRGB(255, 210, 50), Color3.fromRGB(255, 80, 220)),
        }.Parent = nameLine
    end
    nameLine.Parent = container
    local priceLine = makeLine("Price", if price == 0 then "FREE" else "$" .. CompactNumber.format(price), Color3.fromRGB(75, 235, 100), 3)
    priceLine.Parent = container
    return billboard
end

return EggBillboard
