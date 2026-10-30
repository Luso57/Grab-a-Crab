-- Run once in Roblox Studio's Command Bar while editing the place, then save.
local Workspace = game:GetService("Workspace")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local stand = Workspace:FindFirstChild("SellStand") or Workspace:FindFirstChild("shopStand")
assert(stand and (stand:IsA("Folder") or stand:IsA("Model")), "Expected Workspace.shopStand or Workspace.SellStand folder or model")

local signLabels = {}
for _, descendant in stand:GetDescendants() do
	if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
		local caption = string.upper(string.gsub(descendant.Text, "^%s*(.-)%s*$", "%1"))
		if caption == "SHOP" or caption == "SELL" then
			table.insert(signLabels, descendant)
		end
	end
end
assert(#signLabels > 0, "No SHOP or SELL text label was found inside the stand")

ChangeHistoryService:SetWaypoint("Before Sell Stand sign")
stand.Name = "SellStand"
for _, label in signLabels do
	label.Text = "SELL"
end

local noob = stand:FindFirstChild("Noob")
local torso = if noob then noob:FindFirstChild("Torso") else nil
assert(torso and torso:IsA("BasePart"), "SellStand.Noob.Torso is missing")
local prompt = torso:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
prompt.Name = "ProximityPrompt"
prompt.ActionText = "Sell Items"
prompt.ObjectText = "Sell Stand"
prompt.KeyboardKeyCode = Enum.KeyCode.E
prompt.HoldDuration = 0
prompt.RequiresLineOfSight = false
prompt.MaxActivationDistance = 12
prompt.Parent = torso
ChangeHistoryService:SetWaypoint("Sell Stand sign and prompt")

print("SellStand ready:", stand:GetFullName(), "sign labels:", #signLabels)
