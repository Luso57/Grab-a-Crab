local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage.Source.Game.Data).client
local PlotServiceClient = require(ReplicatedStorage.Source.Features.Plots.PlotServiceClient)
local SlimeEventConfig = require(ReplicatedStorage.Source.Features.Slimeevent.SlimeEventConfig)
local TutorialConfig = require(ReplicatedStorage.Source.Features.Tutorial.TutorialConfig)
local TutorialGuide = require(ReplicatedStorage.Source.Features.Tutorial.Modules.TutorialGuide)

local localPlayer = Players.LocalPlayer
local TutorialServiceClient = { initialized = false }

local CLICK_CURSOR_TEXTURE = "rbxassetid://119253698723724"
local CURSOR_MAX_DISTANCE = 200
local CURSOR_BOB_HEIGHT = 8
local CURSOR_BOB_SPEED = 3
local CURSOR_CLICK_DURATION = 1.2

local function getRootAttachment(): Attachment?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return nil end
	local attachment = root:FindFirstChild("RootAttachment")
	return if attachment and attachment:IsA("Attachment") then attachment else nil
end

local function findTutorialSlime(plot, instanceId: string)
	for _, slime in plot.playpenSlimes do
		if slime.slimeData.instanceId == instanceId then return slime end
	end
	return nil
end

local function resolveTarget()
	if localPlayer:GetAttribute(SlimeEventConfig.CarryingAttribute) == true then return nil end
	local tutorial = Data.tutorial()
	local definition = TutorialConfig.Steps[tutorial.step]
	local plot = PlotServiceClient:getLocalPlayerPlot()
	if not plot then return nil end

	if TutorialConfig.isUpgradePromptActive(tutorial, Data.currency(), Data.slimeLuckLevel(), Data.rebirths()) then
		local upgradeBoard = plot.plotModel:FindFirstChild("UpgradeBoard")
		return upgradeBoard and upgradeBoard:FindFirstChild("board") or nil
	end

	if TutorialConfig.isPlotPromptActive(tutorial, Data.currency(), Data.plotLevel(), Data.rebirths()) then
		local levelSign = plot.plotModel:FindFirstChild("LevelSign")
		return levelSign and levelSign:FindFirstChild("board") or nil
	end

	if tutorial.completed or not definition or not definition.target then return nil end

	if definition.target == "rollButton" then
		local buttonModel = plot.plotModel:FindFirstChild("Button")
		return buttonModel and buttonModel:FindFirstChild("SpawnerButton") or nil
	elseif definition.target == "offerSlime" then
		local offer = plot.currentSlime or plot.secondarySlime
		return offer and offer.rootPart or nil
	elseif definition.target == "tutorialSlime" then
		local slime = findTutorialSlime(plot, tutorial.targetSlimeInstanceId)
		return slime and slime.rootPart or nil
	elseif definition.target == "depositPad" then
		return plot.slimeDepositAttachment
	elseif definition.target == "cashPad" then
		return plot.collectCashAttachment
	end
	return nil
end

local function createUpgradeCursor(target: Instance): () -> ()
	local targetPart = if target:IsA("BasePart") then target else target.Parent
	if not targetPart or not targetPart:IsA("BasePart") then return function() end end

	local container = Instance.new("ScreenGui")
	container.Name = "TutorialUpgradeCursor"
	container.DisplayOrder = 1002
	container.IgnoreGuiInset = true
	container.ResetOnSpawn = false
	container.Parent = localPlayer:WaitForChild("PlayerGui")

	local image = Instance.new("ImageLabel")
	image.Name = "Hand"
	image.AnchorPoint = Vector2.new(0.14, 0.8)
	image.BackgroundTransparency = 1
	image.Image = CLICK_CURSOR_TEXTURE
	image.Size = UDim2.fromOffset(108, 108)
	image.Parent = container

	local scale = Instance.new("UIScale")
	scale.Parent = image

	local elapsed = 0
	local connection = RunService.RenderStepped:Connect(function(deltaTime)
		elapsed += deltaTime
		local cycle = elapsed % CURSOR_CLICK_DURATION
		local clickScale = 1
		local pressOffset = 0

		if cycle < 0.12 then
			local alpha = cycle / 0.12
			clickScale = 1 - 0.16 * alpha
			pressOffset = 5 * alpha
		elseif cycle < 0.28 then
			local alpha = (cycle - 0.12) / 0.16
			clickScale = 0.84 + 0.22 * alpha
			pressOffset = 5 * (1 - alpha)
		elseif cycle < 0.48 then
			local alpha = (cycle - 0.28) / 0.2
			clickScale = 1.06 - 0.06 * alpha
		end

		local camera = workspace.CurrentCamera
		local worldPosition = targetPart.Position + Vector3.new(0, targetPart.Size.Y * 0.3, 0)
		local screenPosition, onScreen = camera:WorldToViewportPoint(worldPosition)
		local distance = (camera.CFrame.Position - worldPosition).Magnitude

		scale.Scale = clickScale
		image.Visible = onScreen and screenPosition.Z > 0 and distance <= CURSOR_MAX_DISTANCE
		image.Position = UDim2.fromOffset(
			screenPosition.X,
			screenPosition.Y + math.sin(elapsed * CURSOR_BOB_SPEED) * CURSOR_BOB_HEIGHT + pressOffset
		)
	end)

	return function()
		connection:Disconnect()
		container:Destroy()
	end
end

local function createGuide(root: Attachment, target: Instance, showUpgradeCursor: boolean): () -> ()
	local cleanupGuide = TutorialGuide.create(root, target)
	local cleanupCursor = if showUpgradeCursor then createUpgradeCursor(target) else function() end

	return function()
		cleanupCursor()
		cleanupGuide()
	end
end

function TutorialServiceClient.init(self)
	if self.initialized then return end
	self.initialized = true
	task.spawn(function()
		local currentRoot: Attachment? = nil
		local currentTarget: Instance? = nil
		local currentStep = ""
		local cleanup = function() end
		while true do
			task.wait(0.15)
			local tutorial = Data.tutorial()
			local root = getRootAttachment()
			local target = resolveTarget()
			if root ~= currentRoot
				or target ~= currentTarget
				or tutorial.step ~= currentStep
				or (target and not target.Parent)
			then
				cleanup()
				currentRoot = root
				currentTarget = target
				currentStep = tutorial.step
				cleanup = if root and target and target.Parent
					then createGuide(root, target, tutorial.step == "upgradeSlime")
					else function() end
			end
		end
	end)
end

return TutorialServiceClient