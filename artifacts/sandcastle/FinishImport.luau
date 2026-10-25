-- Select the imported Model, then run this in Roblox Studio's Command Bar.
local selected = game:GetService("Selection"):Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported sandcastle Model")
local model = selected[1]
local folders = {}
for _, v in workspace:GetDescendants() do
    if v.Name == "Decormodel" and v:IsA("Folder") then table.insert(folders, v) end
end
assert(#folders == 1, "Expected exactly one existing Decormodel folder")
local destination = folders[1]
assert(not destination:FindFirstChild("Sandcastle") or destination:FindFirstChild("Sandcastle") == model, "An existing Sandcastle would be overwritten; stopped")
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
}
local assignments, seen = {}, {}
local count = 0
for _, part in model:GetDescendants() do
    if part:IsA("BasePart") then
        assert(part:IsA("MeshPart"), "Unexpected part: " .. part.Name)
        assert(colors[part.Name], "Unknown mesh name: " .. part.Name)
        local appearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
        local textured = part.TextureID ~= "" or (appearance and appearance.ColorMap ~= "")
        assignments[part] = textured and Color3.new(1, 1, 1) or colors[part.Name]
        seen[part.Name] = true
        count += 1
    end
end
for name in colors do assert(seen[name], "Missing mesh: " .. name) end
assert(count == 14, "Expected 14 color meshes")
for part, color in assignments do
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.Transparency = 0
    part.Reflectance = 0
end
model.Name = "Sandcastle"
model.Parent = destination
for part, color in assignments do
    assert(part.Anchored and part.Color == color, "Verification failed: " .. part.Name)
end
game:GetService("Selection"):Set({model})
print("Verified " .. model:GetFullName() .. ": 14 anchored meshes with textures preserved or explicit fallback colors")
