-- Select the imported Model, then run this in Roblox Studio's Command Bar.
local selected = game:GetService("Selection"):Get()
assert(#selected == 1 and selected[1]:IsA("Model"), "Select one imported pearl shell Model")
local model = selected[1]
local folders = {}
for _, v in workspace:GetDescendants() do
    if v.Name == "Decormodel" and v:IsA("Folder") then table.insert(folders, v) end
end
assert(#folders == 1, "Expected exactly one existing Decormodel folder")
local destination = folders[1]
assert(not destination:FindFirstChild("PearlShell") or destination:FindFirstChild("PearlShell") == model, "An existing PearlShell would be overwritten; stopped")
local colors = {
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
assert(count == 12, "Expected 12 color meshes")
for part, color in assignments do
    part.Color = color
    part.Material = Enum.Material.SmoothPlastic
    part.Anchored = true
    part.Transparency = 0
    part.Reflectance = 0
end
model.Name = "PearlShell"
model.Parent = destination
for part, color in assignments do
    assert(part.Anchored and part.Color == color, "Verification failed: " .. part.Name)
end
game:GetService("Selection"):Set({model})
print("Verified " .. model:GetFullName() .. ": 12 anchored meshes with textures preserved or explicit fallback colors")
