--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local ShopMonoCoins = require(script.Parent.ShopMonoCoins)
local ShopMonoPasses = require(script.Parent.ShopMonoPasses)

local create = Vide.create

export type Props = {
	isOpen: () -> boolean,
	otherMenuOpen: () -> boolean,
	maxMoney: () -> number,
	serverLuckMultiplier: () -> number,
	autoCollectPassOwned: () -> boolean,
	serverLuckPrice: () -> string,
	onBuyServerLuck: () -> (),
	onBuyCoins: (number) -> (),
	onBuyPass: (string) -> (),
	onClose: () -> (),
}

local function ShopMonoRoot(props: Props): Instance
	local visible = Vide.source(false)
	local screen = create "ScreenGui" {
		Name = "ShopMonoMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 31,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = visible,
	} :: ScreenGui

	local openSound = create "Sound" {
		Name = "OpenSound",
		SoundId = "rbxassetid://127488139302452",
		Volume = 1,
	}
	openSound.Parent = screen
	local closeSound = create "Sound" {
		Name = "CloseSound",
		SoundId = "rbxassetid://132948338000932",
		Volume = 1,
	}
	closeSound.Parent = screen

	local panel = create "ImageLabel" {
		Name = "ShopMonoPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.6),
		Size = UDim2.fromOffset(850, 458),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.IndexBackground,
		ImageColor3 = Color3.fromRGB(165, 105, 48),
		ScaleType = Enum.ScaleType.Stretch,
	}
	panel.Parent = screen

	local sign = create "ImageLabel" {
		Name = "ShopSign",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.14, 0.015),
		Size = UDim2.fromScale(0.32, 0.17),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TopBarCard,
		ImageColor3 = Color3.fromRGB(255, 176, 72),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 3,
	}
	local title = create "TextLabel" {
		Name = "Title",
		Position = UDim2.fromScale(0.05, 0.04),
		Size = UDim2.fromScale(0.90, 0.76),
		BackgroundTransparency = 1,
		Text = "SHOP",
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 5,
	}
	create "UITextSizeConstraint" { MaxTextSize = 52 }.Parent = title
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}.Parent = title
	title.Parent = sign
	sign.Parent = panel

	local closeScale = create "UIScale" { Scale = 1 }
	local closeHoverTween: Tween? = nil
	local function setCloseScale(scale: number)
		if closeHoverTween then
			closeHoverTween:Cancel()
		end
		closeHoverTween = TweenService:Create(closeScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = scale,
		})
		closeHoverTween:Play()
	end
	local close = create "ImageButton" {
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -12, 0, 12),
		Size = UDim2.fromScale(0.075, 0.14),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ExitButton,
		ScaleType = Enum.ScaleType.Fit,
		AutoButtonColor = false,
		ZIndex = 8,
		MouseEnter = function()
			setCloseScale(1.1)
		end,
		MouseLeave = function()
			setCloseScale(1)
		end,
		Activated = function()
			setCloseScale(1)
			props.onClose()
		end,
	} :: ImageButton
	closeScale.Parent = close
	close.Parent = panel

	local itemList = create "ScrollingFrame" {
		Name = "ItemList",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.13),
		Size = UDim2.fromScale(0.92, 0.78),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(89, 43, 8),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 2,
	}
	create "UIListLayout" {
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	}.Parent = itemList
	create "UIPadding" {
		PaddingTop = UDim.new(0, 6),
		PaddingBottom = UDim.new(0, 6),
	}.Parent = itemList
	itemList.Parent = panel

	local banner = create "ImageLabel" {
		Name = "ServerWeightLuckBanner",
		Size = UDim2.new(1, -58, 0, 128),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ServerWeightLuckCard,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 2,
	}
	banner.Parent = itemList
	create "UICorner" { CornerRadius = UDim.new(0, 8) }.Parent = banner
	local bannerStroke = create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}
	bannerStroke.Parent = banner

	local clover = create "ImageLabel" {
		Name = "GrowthLuckClover",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.09, 0.5),
		Size = UDim2.fromScale(0.16, 0.77),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.IndexClover,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}
	clover.Parent = banner

	local heading = create "TextLabel" {
		Name = "Heading",
		Position = UDim2.fromScale(0.25, 0.05),
		Size = UDim2.fromScale(0.71, 0.31),
		BackgroundTransparency = 1,
		Text = '<font color="#5AF56B">BOOST</font> Server Weight Luck!',
		RichText = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 4,
	}
	create "UITextSizeConstraint" { MaxTextSize = 40 }.Parent = heading
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}.Parent = heading
	heading.Parent = banner

	local function multiplierText(name: string, value: string | (() -> string), color: Color3, position: UDim2, size: UDim2, maxTextSize: number)
		local label = create "TextLabel" {
			Name = name,
			Position = position,
			Size = size,
			BackgroundTransparency = 1,
			Text = value,
			TextColor3 = color,
			TextScaled = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			Font = Enum.Font.BuilderSansExtraBold,
			ZIndex = 4,
		}
		create "UITextSizeConstraint" { MaxTextSize = maxTextSize }.Parent = label
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = Color3.new(0, 0, 0),
			Thickness = 3,
		}.Parent = label
		label.Parent = banner
	end
	multiplierText("StartingMultiplier", function()
		return "x" .. tostring(props.serverLuckMultiplier())
	end, Color3.new(1, 1, 1), UDim2.fromScale(0.40, 0.56), UDim2.fromScale(0.07, 0.29), 35)
	multiplierText("MultiplierArrow", utf8.char(0x2192), Color3.new(1, 1, 1), UDim2.fromScale(0.45, 0.48), UDim2.fromScale(0.09, 0.45), 48)
	multiplierText("BoostedMultiplier", function()
		return if props.serverLuckMultiplier() == 1 then "x2" else "x4"
	end, Color3.fromRGB(90, 245, 107), UDim2.fromScale(0.50, 0.46), UDim2.fromScale(0.13, 0.49), 55)

	local buyScale = create "UIScale" { Scale = 1 }
	local buyHoverTween: Tween? = nil
	local function setBuyScale(scale: number)
		if buyHoverTween then
			buyHoverTween:Cancel()
		end
		buyHoverTween = TweenService:Create(buyScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = scale,
		})
		buyHoverTween:Play()
	end

	local buyButton = create "ImageButton" {
		Name = "RobuxButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.89, 0.80),
		Size = UDim2.fromScale(0.20, 0.33),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopMonoCoinBuyButton,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = false,
		ZIndex = 5,
		MouseEnter = function()
			setBuyScale(1.1)
		end,
		MouseLeave = function()
			setBuyScale(1)
		end,
		Activated = props.onBuyServerLuck,
	} :: ImageButton
	buyScale.Parent = buyButton
	buyButton.Parent = banner

	local robuxIcon = create "ImageLabel" {
		Name = "RobuxIcon",
		Position = UDim2.fromScale(0.17, 0.08),
		Size = UDim2.fromScale(0.34, 0.84),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.RobuxIcon,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 6,
	}
	robuxIcon.Parent = buyButton

	local price = create "TextLabel" {
		Name = "Price",
		Position = UDim2.fromScale(0.49, 0.08),
		Size = UDim2.fromScale(0.34, 0.83),
		BackgroundTransparency = 1,
		Text = props.serverLuckPrice,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 6,
	}
	create "UITextSizeConstraint" { MaxTextSize = 46 }.Parent = price
	create "UIStroke" {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
	}.Parent = price
	price.Parent = buyButton

	local passesSection, resizePasses = ShopMonoPasses.new(props.onBuyPass, props.autoCollectPassOwned)
	passesSection.Parent = itemList

	local coinsSection, resizeCoins = ShopMonoCoins.new(props.maxMoney, props.onBuyCoins)
	coinsSection.Parent = itemList

	local originalTextStroke: { [TextLabel]: number } = {}
	local originalOutlineThickness: { [UIStroke]: number } = {}
	local function styleText(compact: boolean)
		for _, descendant in panel:GetDescendants() do
			if descendant:IsA("TextLabel") then
				local original = originalTextStroke[descendant]
				if original == nil then
					original = descendant.TextStrokeTransparency
					originalTextStroke[descendant] = original
				end
				descendant.TextStrokeTransparency = if compact then math.max(original, 0.55) else original
				local stroke = descendant:FindFirstChildOfClass("UIStroke")
				if stroke and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
					local thickness = originalOutlineThickness[stroke]
					if thickness == nil then
						thickness = stroke.Thickness
						originalOutlineThickness[stroke] = thickness
					end
					stroke.Thickness = if compact then thickness * 0.55 else thickness
				end
			end
		end
	end
	local function resize()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local portrait = viewport.Y > viewport.X
		local compact = math.min(viewport.X, viewport.Y) < 600
		local height = math.min(458, viewport.Y * (if compact then 0.68 elseif portrait then 0.72 else 0.74))
		local width = math.min(850, viewport.X * (if compact and portrait then 0.90 elseif compact then 0.78 elseif portrait then 0.94 else 0.86))
		panel.Size = UDim2.fromOffset(math.floor(width), math.floor(height))
		banner.Size = UDim2.new(1, -58, 0, math.floor(height * (if compact then 0.31 else 0.28)))
		bannerStroke.Thickness = if compact then 1.5 else 3
		resizePasses(portrait, compact)
		resizeCoins(portrait, compact)
		styleText(compact)
	end
	local viewportConnection: RBXScriptConnection? = nil
	local function watchCamera()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		local camera = Workspace.CurrentCamera
		viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize) else nil
		resize()
	end
	local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	screen.Destroying:Connect(function()
		cameraConnection:Disconnect()
		if viewportConnection then
			viewportConnection:Disconnect()
		end
		if closeHoverTween then
			closeHoverTween:Cancel()
		end
		if buyHoverTween then
			buyHoverTween:Cancel()
		end
	end)
	watchCamera()

	local shownPosition = UDim2.fromScale(0.5, 0.53)
	local hiddenPosition = UDim2.fromScale(0.5, 1.6)
	local panelTween: Tween? = nil
	local animationVersion = 0
	local wasOpen = false
	Vide.effect(function()
		local shouldOpen = props.isOpen()
		if shouldOpen == wasOpen then
			return
		end
		wasOpen = shouldOpen
		animationVersion += 1
		local version = animationVersion
		if panelTween then
			panelTween:Cancel()
		end
		if shouldOpen then
			visible(true)
			openSound.TimePosition = 0
			openSound:Play()
			panelTween = TweenService:Create(panel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = shownPosition,
			})
			panelTween:Play()
		else
			closeSound.TimePosition = 0
			closeSound:Play()
			if props.otherMenuOpen() then
				panel.Position = hiddenPosition
				visible(false)
				return
			end
			panelTween = TweenService:Create(panel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = hiddenPosition,
			})
			panelTween.Completed:Once(function(state)
				if state == Enum.PlaybackState.Completed and animationVersion == version then
					visible(false)
				end
			end)
			panelTween:Play()
		end
	end)
	return screen
end

return ShopMonoRoot
