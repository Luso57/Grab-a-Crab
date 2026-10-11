--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local create = Vide.create

local MoneyPadDisplay = {}

function MoneyPadDisplay.attach(model: Model): () -> ()
	local accrued = Vide.source(0)
	local anchor: Attachment? = nil
	local connections: { RBXScriptConnection } = {}
	local gui: ScreenGui? = nil
	local amountRow: Frame? = nil
	local amountScale: UIScale? = nil
	local rate = 0
	local baseAmount = 0
	local updatedAt = 0

	local function refreshIncome()
		local value = model:GetAttribute("IncomePerSecond")
		local base = model:GetAttribute("MoneyPadBaseAmount")
		local timestamp = model:GetAttribute("MoneyPadUpdatedAt")
		rate = if typeof(value) == "number" then value else 0
		baseAmount = if typeof(base) == "number" then base else 0
		updatedAt = if typeof(timestamp) == "number" then timestamp else Workspace:GetServerTimeNow()
	end

	local function refreshPad()
		if anchor then
			anchor:Destroy()
			anchor = nil
		end
		local pad = model:FindFirstChild("MoneyPad")
		local green = if pad then pad:FindFirstChild("GreenInnerCircle") else nil
		if green and green:IsA("BasePart") then
			local displayAnchor = Instance.new("Attachment")
			displayAnchor.Name = "MoneyPadDisplayAnchor"
			displayAnchor.Position = Vector3.zero
			displayAnchor.Parent = green
			anchor = displayAnchor
		end
	end

	local unmount = Vide.mount(function()
		local screen = create "ScreenGui" {
			Name = "MoneyPadDisplay",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 10,
		}
		local row = create "Frame" {
			Name = "AmountRow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(175, 38),
			BackgroundTransparency = 1,
			Visible = false,
		}
		row.Parent = screen
		local scale = create "UIScale" { Scale = 1 }
		scale.Parent = row
		amountScale = scale
		create "UIListLayout" {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 3),
		}.Parent = row
		create "ImageLabel" {
			Name = "CoinIcon",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(30, 30),
			Image = "rbxassetid://" .. assets.SandDollar,
			ScaleType = Enum.ScaleType.Fit,
			LayoutOrder = 1,
		}.Parent = row
		create "TextLabel" {
			Name = "AccumulatedAmount",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 38),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = 2,
			Text = function()
				return CompactNumber.format(accrued())
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextSize = 27,
			TextScaled = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.BuilderSansExtraBold,
		}.Parent = row
		gui = screen
		amountRow = row
		return screen
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))

	local function updateDisplay()
		local elapsed = math.max(0, Workspace:GetServerTimeNow() - updatedAt)
		local displayed = baseAmount + rate * math.floor(elapsed)
		if displayed ~= accrued() then
			accrued(displayed)
		end

		local row = amountRow
		local scale = amountScale
		local target = anchor
		local camera = Workspace.CurrentCamera
		local green = if target then target.Parent else nil
		local pad = if green then green.Parent else nil
		local blue = if pad then pad:FindFirstChild("BlueOuterCircle") else nil
		if not row or not scale or not target or not camera or not blue or not blue:IsA("BasePart") then
			if row then
				row.Visible = false
			end
			return
		end
		local worldPosition = target.WorldPosition
		local screenPosition, onScreen = camera:WorldToViewportPoint(worldPosition)
		row.Visible = onScreen and screenPosition.Z > 0
			and (camera.CFrame.Position - worldPosition).Magnitude <= 50
		if row.Visible then
			local focalLength = camera.ViewportSize.Y / (2 * math.tan(math.rad(camera.FieldOfView) / 2))
			local padDiameter = focalLength * blue.Size.Y / screenPosition.Z
			scale.Scale = padDiameter / 100
			row.Position = UDim2.fromOffset(screenPosition.X, screenPosition.Y - padDiameter * 0.45)
		end
	end

	table.insert(connections, model:GetAttributeChangedSignal("IncomePerSecond"):Connect(refreshIncome))
	table.insert(connections, model:GetAttributeChangedSignal("MoneyPadBaseAmount"):Connect(refreshIncome))
	table.insert(connections, model:GetAttributeChangedSignal("MoneyPadUpdatedAt"):Connect(refreshIncome))
	table.insert(connections, model.ChildAdded:Connect(function(child)
		if child.Name == "MoneyPad" then
			refreshPad()
		end
	end))
	table.insert(connections, model.ChildRemoved:Connect(function(child)
		if child.Name == "MoneyPad" then
			refreshPad()
		end
	end))
	table.insert(connections, RunService.RenderStepped:Connect(updateDisplay))
	refreshIncome()
	refreshPad()
	updateDisplay()

	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
		unmount()
		if anchor then
			anchor:Destroy()
			anchor = nil
		end
		if gui then
			gui:Destroy()
		end
	end
end

return MoneyPadDisplay
