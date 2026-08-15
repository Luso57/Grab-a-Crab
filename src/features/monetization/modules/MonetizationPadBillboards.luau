local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationServiceClient = require(ReplicatedStorage.Source.Features.Monetization.MonetizationServiceClient)
local MonetizationTypes = require(ReplicatedStorage.Source.Features.Monetization.MonetizationTypes)

type ProductKey = MonetizationTypes.ProductKey

local MonetizationPadBillboards = {}

local BILLBOARD_NAME = "MonetizationPadBillboard"
local ATTACHMENT_NAME = "MonetizationPadBillboardAttachment"
local CLICK_DETECTOR_NAME = "MonetizationPadClickDetector"
local PROMPT_COOLDOWN = 1.5
local LUCK_SPIN_ICON = "rbxthumb://type=Asset&id=129360611840213&w=420&h=420"

local PAD_DISPLAYS: { [string]: { title: string, price: string, productKey: ProductKey? } } = {
	Buy2xSlime = {
		title = "x2 Slimes",
		price = "R$ 499",
		productKey = "doubleSlimeDeposit",
	},
	BuyAutoCollect = {
		title = "Auto Collect Cash",
		price = "R$ 9",
		productKey = "autoCollect",
	},
	Finishnow = {
		title = "Finish Now",
		price = "R$ 19",
		productKey = "finishNow",
	},
}

local function addRoundedStroke(parent: Instance, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Thickness = thickness
	stroke.Parent = parent
end

local function addTextSizeConstraint(parent: Instance, maxTextSize: number)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = maxTextSize
	constraint.MinTextSize = 1
	constraint.Parent = parent
end

local function createBillboard(model: Model, titleText: string, priceText: string): (BillboardGui, Attachment)
	local button = model:WaitForChild("button")
	assert(button:IsA("BasePart"), `{model.Name}.button must be a BasePart`)

	local oldGui = button:FindFirstChild(BILLBOARD_NAME)
	if oldGui then oldGui:Destroy() end
	local oldAttachment = button:FindFirstChild(ATTACHMENT_NAME)
	if oldAttachment then oldAttachment:Destroy() end

	local attachment = Instance.new("Attachment")
	attachment.Name = ATTACHMENT_NAME
	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position
		+ boundingBoxCFrame.UpVector * (boundingBoxSize.Y / 2 + 2)
	attachment.Position = button.CFrame:PointToObjectSpace(topPosition)
	attachment.Parent = button

	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.Adornee = attachment
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.Size = UDim2.fromScale(8, 3.2)
	billboard.Parent = button

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Position = UDim2.fromScale(0.04, 0.03)
	title.Size = UDim2.fromScale(0.92, 0.46)
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(255, 194, 104)
	title.TextScaled = true
	title.TextStrokeTransparency = 1
	title.Parent = billboard
	addRoundedStroke(title, 4)
	addTextSizeConstraint(title, 44)

	local priceRow = Instance.new("Frame")
	priceRow.Name = "PriceRow"
	priceRow.BackgroundTransparency = 1
	priceRow.BorderSizePixel = 0
	priceRow.Position = UDim2.fromScale(0.18, 0.51)
	priceRow.Size = UDim2.fromScale(0.64, 0.42)
	priceRow.Parent = billboard

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.FredokaOne
	price.Position = UDim2.fromScale(0, 0.06)
	price.Size = UDim2.fromScale(1, 0.88)
	price.Text = priceText
	price.TextColor3 = Color3.fromRGB(255, 221, 45)
	price.TextScaled = true
	price.TextStrokeTransparency = 1
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.Parent = priceRow
	addRoundedStroke(price, 4)
	addTextSizeConstraint(price, 64)

	return billboard, attachment
end

local function create99xLuckBillboard(model: Model, button: BasePart): (BillboardGui, Attachment)
	local oldGui = button:FindFirstChild(BILLBOARD_NAME)
	if oldGui then oldGui:Destroy() end
	local oldAttachment = button:FindFirstChild(ATTACHMENT_NAME)
	if oldAttachment then oldAttachment:Destroy() end

	local attachment = Instance.new("Attachment")
	attachment.Name = ATTACHMENT_NAME
	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	local topPosition = boundingBoxCFrame.Position + Vector3.new(0, boundingBoxSize.Y / 2 + 4, 0)
	attachment.Position = button.CFrame:PointToObjectSpace(topPosition)
	attachment.Parent = button

	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.Adornee = attachment
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100
	billboard.Size = UDim2.fromScale(8, 3.2)
	billboard.Parent = button

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Position = UDim2.fromScale(0.04, 0.03)
	title.Size = UDim2.fromScale(0.92, 0.46)
	title.Text = "99x LUCK SPIN"
	title.TextColor3 = Color3.fromRGB(255, 221, 45)
	title.TextScaled = true
	title.TextStrokeTransparency = 1
	title.Parent = billboard
	addRoundedStroke(title, 4)
	addTextSizeConstraint(title, 44)

	local clover = Instance.new("ImageLabel")
	clover.Name = "LuckClover"
	clover.AnchorPoint = Vector2.new(0.5, 0)
	clover.BackgroundTransparency = 1
	clover.Image = LUCK_SPIN_ICON
	clover.Position = UDim2.fromScale(0.5, 0.5)
	clover.ScaleType = Enum.ScaleType.Fit
	clover.Size = UDim2.fromScale(0.38, 0.43)
	clover.Parent = billboard

	return billboard, attachment
end
local function addPurchaseInteractions(
	button: BasePart,
	productKey: ProductKey,
	created: { Instance },
	connections: { RBXScriptConnection }
)
	local oldDetector = button:FindFirstChild(CLICK_DETECTOR_NAME)
	if oldDetector then oldDetector:Destroy() end

	local clickDetector = Instance.new("ClickDetector")
	clickDetector.Name = CLICK_DETECTOR_NAME
	clickDetector.MaxActivationDistance = 16
	clickDetector.Parent = button
	table.insert(created, clickDetector)

	local promptLocked = false
	local function promptPurchase()
		if promptLocked then return end
		promptLocked = true
		MonetizationServiceClient:promptProduct(productKey)
		task.delay(PROMPT_COOLDOWN, function()
			promptLocked = false
		end)
	end

	table.insert(connections, clickDetector.MouseClick:Connect(function(player)
		if player == Players.LocalPlayer then promptPurchase() end
	end))
	table.insert(connections, button.Touched:Connect(function(hit)
		local character = Players.LocalPlayer.Character
		if character and hit:IsDescendantOf(character) then promptPurchase() end
	end))
end

function MonetizationPadBillboards.attach(plotModel: Model, canPurchase: boolean): () -> ()
	local created = {}
	local connections = {}
	for modelName, display in PAD_DISPLAYS do
		local model = plotModel:WaitForChild(modelName)
		assert(model:IsA("Model"), `Plot {modelName} must be a Model`)
		local gui, attachment = createBillboard(model, display.title, display.price)
		table.insert(created, gui)
		table.insert(created, attachment)
		if canPurchase and display.productKey then
			local button = model:WaitForChild("button")
			assert(button:IsA("BasePart"), `{modelName}.button must be a BasePart`)
			addPurchaseInteractions(button, display.productKey, created, connections)
		end
	end

	local luckSpinModel = plotModel:WaitForChild("99Button")
	assert(luckSpinModel:IsA("Model"), "Plot 99Button must be a Model")
	local luckSpinButton = luckSpinModel:WaitForChild("SpawnerButton")
	assert(luckSpinButton:IsA("BasePart"), "99Button.SpawnerButton must be a BasePart")
	local luckSpinPrompt = luckSpinButton:WaitForChild("ProximityPrompt")
	assert(luckSpinPrompt:IsA("ProximityPrompt"), "99Button.SpawnerButton.ProximityPrompt must be a ProximityPrompt")
	local luckGui, luckAttachment = create99xLuckBillboard(luckSpinModel, luckSpinButton)
	table.insert(created, luckGui)
	table.insert(created, luckAttachment)

	local previousPromptEnabled = luckSpinPrompt.Enabled
	local previousActionText = luckSpinPrompt.ActionText
	local previousObjectText = luckSpinPrompt.ObjectText
	luckSpinPrompt.Enabled = canPurchase
	luckSpinPrompt.ActionText = "Buy 99x Luck Spin"
	luckSpinPrompt.ObjectText = ""
	if canPurchase then
		local promptLocked = false
		table.insert(connections, luckSpinPrompt.Triggered:Connect(function()
			if promptLocked then return end
			promptLocked = true
			MonetizationServiceClient:promptProduct("luck99Spin")
			task.delay(PROMPT_COOLDOWN, function()
				promptLocked = false
			end)
		end))
	end
	local cleaned = false
	return function()
		if cleaned then return end
		cleaned = true
		for _, connection in connections do
			connection:Disconnect()
		end
		for _, instance in created do
			if instance.Parent then instance:Destroy() end
		end
		if luckSpinPrompt.Parent then
			luckSpinPrompt.Enabled = previousPromptEnabled
			luckSpinPrompt.ActionText = previousActionText
			luckSpinPrompt.ObjectText = previousObjectText
		end
	end
end

return MonetizationPadBillboards
