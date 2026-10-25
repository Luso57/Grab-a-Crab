-- Select the imported Model, then run this in Roblox Studio's Command Bar.
local selected = game:GetService("Selection"):Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported beach rocks Model")
local model = selected[1]
local folders = {}
for _, v in workspace:GetDescendants() do
    if v.Name == "Decormodel" and v:IsA("Folder") then table.insert(folders, v) end
end
assert(#folders == 1, "Expected exactly one existing Decormodel folder")
local destination = folders[1]
assert(not destination:FindFirstChild("BeachRocks") or destination:FindFirstChild("BeachRocks") == model, "An existing BeachRocks would be overwritten; stopped")
local colors = {
["BeachRocks_StoneLight"] = Color3.fromRGB(151, 145, 165),
["BeachRocks_Stone"] = Color3.fromRGB(132, 129, 151),
["BeachRocks_StoneShade"] = Color3.fromRGB(116, 115, 139),
["BeachRocks_StoneWarm"] = Color3.fromRGB(143, 136, 157),
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
assert(count == 4, "Expected 4 color meshes")
for part, color in assignments do
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.Transparency = 0
    part.Reflectance = 0
end
model.Name = "BeachRocks"
model.Parent = destination
for part, color in assignments do
    assert(part.Anchored and part.Color == color, "Verification failed: " .. part.Name)
end
game:GetService("Selection"):Set({model})
print("Verified " .. model:GetFullName() .. ": 4 anchored meshes with textures preserved or explicit fallback colors")
