--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create
local ShopMonoButton = {}
local BUTTON_SIZE = 80
local CENTER_OFFSET = 44

function ShopMonoButton.mount(playerGui: PlayerGui)
	local hoverScale = create "UIScale" { Scale = 1 }
	local hoverTween: Tween? = nil
	local function setHovered(hovered: boolean)
		if hoverTween then
			hoverTween:Cancel()
		end
		hoverTween = TweenService:Create(hoverScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = if hovered then 1.08 else 1,
		})
		hoverTween:Play()
	end

	local rainbow = create "UIGradient" {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
			ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 180, 40)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 245, 55)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(65, 235, 95)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(35, 180, 255)),
			ColorSequenceKeypoint.new(0.83, Color3.fromRGB(155, 65, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 70)),
		}),
		Rotation = 0,
	}
	local border = create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = 4,
		Color = Color3.new(1, 1, 1),
	}
	rainbow.Parent = border

	local button = create "ImageButton" {
		Name = "ShopMonoButton",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE),
		Position = UDim2.new(1, -16, 0.5, -CENTER_OFFSET),
		BackgroundColor3 = Color3.fromRGB(11, 10, 19),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		MouseEnter = function()
			setHovered(true)
		end,
		MouseLeave = function()
			setHovered(false)
		end,
		Activated = function() end,
	}
	hoverScale.Parent = button
	create "UICorner" { CornerRadius = UDim.new(0, 4) }.Parent = button
	border.Parent = button

	create "ImageLabel" {
		Name = "ShopIcon",
		Position = UDim2.fromScale(0.05, 0.05),
		Size = UDim2.fromScale(0.9, 0.72),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopMonoButtonIcon,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 2,
	}.Parent = button

	local title = create "TextLabel" {
		Name = "ShopLabel",
		Position = UDim2.fromScale(0.02, 0.76),
		Size = UDim2.fromScale(0.96, 0.24),
		BackgroundTransparency = 1,
		Text = "Shop",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 3,
	}
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 2,
	}.Parent = title
	create "UITextSizeConstraint" { MaxTextSize = 20 }.Parent = title
	title.Parent = button

	local screen = create "ScreenGui" {
		Name = "ShopMonoButtonGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}
	button.Parent = screen
	Vide.mount(function()
		return screen
	end, playerGui)

	local rainbowTween = TweenService:Create(rainbow, TweenInfo.new(12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), {
		Rotation = 360,
	})
	rainbowTween:Play()

	local viewportConnection: RBXScriptConnection? = nil
	local function layout()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 650), 0.7, 1)
		button.Size = UDim2.fromOffset(math.round(BUTTON_SIZE * scale), math.round(BUTTON_SIZE * scale))
		button.Position = UDim2.new(1, -math.round(16 * scale), 0.5, -math.round(CENTER_OFFSET * scale))
	end
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) else nil
		layout()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	screen.Destroying:Connect(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		if hoverTween then
			hoverTween:Cancel()
		end
		rainbowTween:Cancel()
	end)
	watchCamera()
end

return ShopMonoButton
