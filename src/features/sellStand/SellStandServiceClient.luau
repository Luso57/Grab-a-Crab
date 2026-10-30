--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local Networker = require(ReplicatedStorage.Packages.Networker)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local SellConfig = require(script.Parent.SellConfig)
local SellDialogue = require(script.Parent.UI.SellDialogue)

local SellStandServiceClient = {}
local initialized = false
local networker = nil
local open = Vide.source(false)
local category = Vide.source("")
local count = Vide.source(0)
local total = Vide.source(0)
local message = Vide.source("")
local pending = Vide.source(false)
local greetingText = Vide.source("")
local greetingPosition = Vide.source(UDim2.fromOffset(0, 0))
local greetingWidth = Vide.source(400)
local menuPosition = Vide.source(UDim2.fromOffset(0, 0))
local menuWidth = Vide.source(500)
local isOnScreen = Vide.source(false)
local quoteToken: string? = nil
local greetingSerial = 0
local updatePosition: (() -> ())? = nil
local prompt: ProximityPrompt? = nil
local GREETING = "Watcha got?"

local function resetQuote()
	quoteToken = nil
	category("")
	count(0)
	total(0)
	pending(false)
end

local function close()
	if not open() then return end
	greetingSerial += 1
	greetingText("")
	open(false)
	if prompt then prompt.Enabled = true end
	resetQuote()
	message("")
	if networker then networker:fire("close") end
end

function SellStandServiceClient:init()
	if initialized then return end
	initialized = true
	networker = Networker.client.new("SellStandService", self)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	Vide.mount(function()
		return SellDialogue.create({
			isOpen = open,
			isOnScreen = isOnScreen,
			greetingText = greetingText,
			greetingPosition = greetingPosition,
			greetingWidth = greetingWidth,
			menuPosition = menuPosition,
			menuWidth = menuWidth,
			category = category,
			count = count,
			total = total,
			message = message,
			pending = pending,
			onCategory = function(selected: string)
				if not open() or pending() then return end
				resetQuote()
				message("Checking your inventory...")
				pending(true)
				networker:fire("requestQuote", selected)
			end,
			onConfirm = function()
				if not open() or pending() or not quoteToken then return end
				pending(true)
				message("Selling...")
				networker:fire("confirmSale", quoteToken)
			end,
			onBack = function()
				resetQuote()
				message("")
			end,
			onExit = close,
		})
	end, playerGui)
	task.spawn(function()
		local stand = Workspace:WaitForChild("SellStand")
		local noob = stand:WaitForChild("Noob")
		local torso = noob:WaitForChild("Torso") :: BasePart
		local head = noob:WaitForChild("Head") :: BasePart
		prompt = torso:WaitForChild("ProximityPrompt") :: ProximityPrompt
		if open() then prompt.Enabled = false end
		updatePosition = function()
			if not open() then return end
			local camera = Workspace.CurrentCamera
			if not camera or not head.Parent then
				isOnScreen(false)
				return
			end
			local point, visible = camera:WorldToViewportPoint(head.Position)
			if not visible or point.Z <= 0 then
				isOnScreen(false)
				return
			end
			isOnScreen(true)
			local viewport = camera.ViewportSize
			local width = math.min(480, math.max(280, viewport.X * 0.36), viewport.X - 16)
			if menuWidth() ~= width then menuWidth(width) end
			local x = point.X + 64
			if x + width > viewport.X - 8 then x = point.X - width - 64 end
			x = math.clamp(x, 8, math.max(8, viewport.X - width - 8))
			local y = math.clamp(point.Y - 72, 8, math.max(8, viewport.Y - 348))
			local nextMenuPosition = UDim2.fromOffset(x, y)
			if menuPosition() ~= nextMenuPosition then menuPosition(nextMenuPosition) end
			local headerWidth = math.min(400, viewport.X - 16)
			if greetingWidth() ~= headerWidth then greetingWidth(headerWidth) end
			local headerX = math.clamp(point.X, headerWidth / 2 + 8, math.max(headerWidth / 2 + 8, viewport.X - headerWidth / 2 - 8))
			local headerY = math.clamp(point.Y - 76, 36, math.max(36, viewport.Y - 36))
			local nextGreetingPosition = UDim2.fromOffset(headerX, headerY)
			if greetingPosition() ~= nextGreetingPosition then greetingPosition(nextGreetingPosition) end
		end
		local positionConnection = RunService.RenderStepped:Connect(function()
			if updatePosition then updatePosition() end
		end)
		while playerGui.Parent do
			if open() then
				local character = Players.LocalPlayer.Character
				local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
				if not root or not root:IsA("BasePart") or (root.Position - torso.Position).Magnitude > SellConfig.interactionDistance then
					close()
				end
			end
			task.wait(0.2)
		end
		positionConnection:Disconnect()
		updatePosition = nil
	end)
end

function SellStandServiceClient:openDialogue()
	greetingSerial += 1
	local serial = greetingSerial
	greetingText("")
	resetQuote()
	message("")
	open(true)
	if prompt then prompt.Enabled = false end
	if updatePosition then updatePosition() end
	task.spawn(function()
		for index = 1, #GREETING do
			if greetingSerial ~= serial or not open() then return end
			greetingText(string.sub(GREETING, 1, index))
			task.wait(0.045)
		end
	end)
end

function SellStandServiceClient:showQuote(selected: any, itemCount: any, payout: any, token: any)
	if not open() or typeof(selected) ~= "string" or typeof(itemCount) ~= "number"
		or typeof(payout) ~= "number" or typeof(token) ~= "string" then return end
	quoteToken = token
	category(selected)
	count(itemCount)
	total(payout)
	pending(false)
	message("")
end

function SellStandServiceClient:showEmpty(selected: any)
	if not open() or typeof(selected) ~= "string" then return end
	resetQuote()
	local label = if selected == "Equipment" then "tanks or incubators" else string.lower(selected)
	message(`You don't have any {label} to sell!`)
end

function SellStandServiceClient:showSold(itemCount: any, payout: any)
	if not open() or typeof(itemCount) ~= "number" or typeof(payout) ~= "number" then return end
	resetQuote()
	message(`Sold {itemCount} items! Earned ${CompactNumber.format(payout)}.`)
end

function SellStandServiceClient:showChanged()
	if not open() then return end
	resetQuote()
	message("Your inventory changed. Choose a category again.")
end

function SellStandServiceClient:showError()
	if not open() then return end
	resetQuote()
	message("Sale failed. Please try again.")
end

return SellStandServiceClient
