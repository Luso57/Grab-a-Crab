-- Repair the ORIGINAL, separately colored meshes already imported into Studio.
-- Select any/all of the four imported models. Paste this whole file into the Command Bar.
-- Works without uploading textures. Original mesh names must be preserved.
local Selection = game:GetService("Selection")
local selected = Selection:Get()
assert(#selected > 0, "Select the imported decorations first")
local colors = {
    ["Sandcastle_Base"] = Color3.fromRGB(255, 216, 141),
    ["Sandcastle_Sand"] = Color3.fromRGB(242, 188, 104),
    ["Sandcastle_SandLight"] = Color3.fromRGB(255, 211, 135),
    ["Sandcastle_Brick"] = Color3.fromRGB(203, 139, 69),
    ["Sandcastle_Wood"] = Color3.fromRGB(139, 65, 29),
    ["Sandcastle_FlagRed"] = Color3.fromRGB(245, 40, 34),
    ["Sandcastle_Arch"] = Color3.fromRGB(218, 153, 77),
    ["Sandcastle_DoorShadow"] = Color3.fromRGB(111, 61, 25),
    ["Sandcastle_Rock"] = Color3.fromRGB(125, 125, 145),
    ["Sandcastle_SeaweedLight"] = Color3.fromRGB(103, 183, 35),
    ["Sandcastle_Seaweed"] = Color3.fromRGB(62, 148, 28),
    ["Sandcastle_BucketRed"] = Color3.fromRGB(225, 37, 48),
    ["Sandcastle_WhiteHandle"] = Color3.fromRGB(235, 239, 241),
    ["Sandcastle_Starfish"] = Color3.fromRGB(255, 77, 40),
    ["PearlShell_OuterPeach"] = Color3.fromRGB(244, 157, 139),
    ["PearlShell_Pearl"] = Color3.fromRGB(255, 226, 232),
    ["PearlShell_Sand"] = Color3.fromRGB(255, 216, 138),
    ["PearlShell_Rock"] = Color3.fromRGB(133, 125, 145),
    ["PearlShell_Seaweed"] = Color3.fromRGB(78, 151, 25),
    ["PearlShell_SeaweedLight"] = Color3.fromRGB(121, 181, 29),
    ["PearlShell_Starfish"] = Color3.fromRGB(255, 78, 29),
    ["PearlShell_ShellPink"] = Color3.fromRGB(242, 137, 144),
    ["PearlShell_ShellCoral"] = Color3.fromRGB(225, 106, 117),
    ["PearlShell_ShellBlush"] = Color3.fromRGB(255, 174, 172),
    ["PearlShell_CreamRim"] = Color3.fromRGB(255, 221, 197),
    ["PearlShell_OuterCream"] = Color3.fromRGB(255, 216, 191),
    ["Starfish_Underside"] = Color3.fromRGB(236, 70, 36),
    ["Starfish_GoldLight"] = Color3.fromRGB(255, 210, 111),
    ["Starfish_RedEdge"] = Color3.fromRGB(223, 55, 31),
    ["Starfish_Coral"] = Color3.fromRGB(250, 79, 40),
    ["Starfish_Orange"] = Color3.fromRGB(255, 106, 48),
    ["Starfish_OrangeLight"] = Color3.fromRGB(255, 119, 54),
    ["Starfish_GoldShade"] = Color3.fromRGB(246, 174, 65),
    ["Starfish_Gold"] = Color3.fromRGB(255, 196, 84),
    ["BeachRocks_StoneLight"] = Color3.fromRGB(151, 145, 165),
    ["BeachRocks_Stone"] = Color3.fromRGB(132, 129, 151),
    ["BeachRocks_StoneShade"] = Color3.fromRGB(116, 115, 139),
    ["BeachRocks_StoneWarm"] = Color3.fromRGB(143, 136, 157),
}
local matches = {}
local unknown = {}
local function inspect(part)
    if not part:IsA("MeshPart") then return end
    local name = part.Name:gsub("%.%d+$", "")
    if colors[name] then
        matches[part] = colors[name]
    else
        table.insert(unknown, part:GetFullName())
    end
end
for _, root in selected do
    inspect(root)
    for _, descendant in root:GetDescendants() do inspect(descendant) end
end
assert(next(matches), "No original mesh names recognized. Keep meshes separate and preserve their exported names.")
-- Each matched mesh is entirely ONE solid color in these four original assets.
-- Thus explicit Color is an exact replacement for its original Blender material.
local history = game:GetService("ChangeHistoryService")
history:SetWaypoint("Before decoration color repair")
local count = 0
for part, color in matches do
    part.TextureID = ""
    for _, child in part:GetChildren() do
        if child:IsA("SurfaceAppearance") then child:Destroy() end
    end
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Transparency = 0
    part.Reflectance = 0
    part.Anchored = true
    assert(part.Color == color and part.Anchored, "Repair check failed: " .. part.Name)
    count += 1
end
history:SetWaypoint("After decoration color repair")
print("Repaired and checked colors on " .. count .. " recognized meshes. Positions and parents preserved.")
if #unknown > 0 then warn("Unrecognized meshes were left unchanged: " .. table.concat(unknown, ", ")) end
