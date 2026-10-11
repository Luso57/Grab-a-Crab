--!strict

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic"

local colors: { [Rarity]: Color3 } = {
    Common = Color3.fromRGB(205, 210, 218),
    Uncommon = Color3.fromRGB(89, 222, 112),
    Rare = Color3.fromRGB(80, 166, 255),
    Epic = Color3.fromRGB(181, 111, 255),
    Legendary = Color3.fromRGB(255, 204, 77),
    Mythic = Color3.fromRGB(255, 89, 156),
}

local Rarities = {}

function Rarities.getColor(rarity: Rarity): Color3
    return colors[rarity]
end

return Rarities
