local Config = require(script.Parent.Parent.SlimeEventConfig)
local SlapSwing = require(script.Parent.SlapSwing)

local SlapToolClient = {}
local visualTokens: { [Tool]: number } = {}

function SlapToolClient.isBat(instance: Instance): boolean
	return instance:IsA("Tool") and instance:GetAttribute(Config.ToolAttribute) == true
end

function SlapToolClient.playVisual(character: Model)
	SlapSwing.play(character)
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or not SlapToolClient.isBat(tool) then return end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return end
	local token = (visualTokens[tool] or 0) + 1
	visualTokens[tool] = token
	task.delay(Config.SwingStrikeStart, function()
		if tool.Parent ~= character or visualTokens[tool] ~= token then return end
		local swoosh = handle:FindFirstChild("Swoosh")
		if swoosh and swoosh:IsA("Sound") then swoosh:Play() end
		local trail = handle:FindFirstChildOfClass("Trail")
		if not trail then return end
		trail.Enabled = true
		task.delay(Config.TrailDuration, function()
			if trail.Parent and visualTokens[tool] == token then trail.Enabled = false end
		end)
	end)
end

function SlapToolClient.bind(tool: Tool, activated: () -> ())
	local lastSwingAt = -math.huge
	local connections = {}
	table.insert(connections, tool.Equipped:Connect(function()
		local handle = tool:FindFirstChild("Handle")
		local equip = handle and handle:FindFirstChild("Equip")
		if equip and equip:IsA("Sound") then equip:Play() end
	end))
	table.insert(connections, tool.Activated:Connect(function()
		local now = os.clock()
		if now - lastSwingAt < Config.SwingCooldown then return end
		lastSwingAt = now
		local character = tool.Parent
		if character and character:IsA("Model") then
			SlapToolClient.playVisual(character)
			activated()
		end
	end))
	return function()
		for _, connection in connections do connection:Disconnect() end
	end
end

return SlapToolClient
