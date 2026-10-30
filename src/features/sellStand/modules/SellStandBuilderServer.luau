--!strict

local Workspace = game:GetService("Workspace")

local SellStandBuilderServer = {}

function SellStandBuilderServer.create(): (Instance?, ProximityPrompt?)
	local existing = Workspace:FindFirstChild("SellStand") or Workspace:FindFirstChild("shopStand")
	if not existing or (not existing:IsA("Folder") and not existing:IsA("Model")) then
		warn("SellStand folder or model is required in Workspace")
		return nil, nil
	end
	local stand = existing
	stand.Name = "SellStand"
	local foundSign = false
	for _, descendant in stand:GetDescendants() do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			local caption = string.upper(string.gsub(descendant.Text, "^%s*(.-)%s*$", "%1"))
			if caption == "SHOP" then
				descendant.Text = "SELL"
				foundSign = true
			elseif caption == "SELL" then
				foundSign = true
			end
		end
	end
	if not foundSign then
		warn("SellStand has no SHOP text label to rename to SELL")
	end
	local noob = stand:FindFirstChild("Noob")
	local torso = if noob then noob:FindFirstChild("Torso") else nil
	local head = if noob then noob:FindFirstChild("Head") else nil
	if not torso or not torso:IsA("BasePart") or not head or not head:IsA("BasePart") then
		warn("SellStand is missing Noob.Head or Noob.Torso")
		return nil, nil
	end
	local prompt = torso:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = torso
	end
	prompt.Name = "ProximityPrompt"
	prompt.ActionText = "Sell Items"
	prompt.ObjectText = "Sell Stand"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	local oldGreeting = head:FindFirstChild("Greeting")
	if oldGreeting and oldGreeting:IsA("BillboardGui") then
		oldGreeting.Enabled = false
	end
	return stand, prompt
end

return SellStandBuilderServer
