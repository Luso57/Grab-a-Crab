--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create

export type Props = {
	isOpen: () -> boolean,
	musicEnabled: () -> boolean,
	soundEffectsEnabled: () -> boolean,
	onToggle: () -> (),
	onClose: () -> (),
	onMusicChanged: (boolean) -> (),
	onEffectsChanged: (boolean) -> (),
}

local function makeSwitchRow(name: string, title: string, positionY: number, enabled: () -> boolean, onChanged: (boolean) -> ()): Frame
	local row = create "Frame" {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, positionY),
		Size = UDim2.fromScale(0.84, 0.18),
		BackgroundColor3 = Color3.fromRGB(239, 177, 66),
		BorderSizePixel = 0,
		ZIndex = 3,
	} :: Frame
	create "UICorner" { CornerRadius = UDim.new(0, 12) }.Parent = row
	create "UIStroke" { Color = Color3.fromRGB(31, 16, 5), Thickness = 3 }.Parent = row

	local titleLabel = create "TextLabel" {
		Name = "Label",
		Position = UDim2.fromScale(0.05, 0.08),
		Size = UDim2.fromScale(0.57, 0.84),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.fromRGB(19, 10, 5),
		TextStrokeTransparency = 0,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 4,
	} :: TextLabel
	create "UITextSizeConstraint" { MaxTextSize = 28 }.Parent = titleLabel
	titleLabel.Parent = row

	local toggle = create "TextButton" {
		Name = "Toggle",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(0.95, 0.5),
		Size = UDim2.fromScale(0.27, 0.67),
		BackgroundColor3 = function()
			return if enabled() then Color3.fromRGB(45, 204, 60) else Color3.fromRGB(204, 63, 55)
		end,
		BorderSizePixel = 0,
		Text = function()
			return if enabled() then "ON" else "OFF"
		end,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 5,
		Activated = function()
			onChanged(not enabled())
		end,
	} :: TextButton
	create "UICorner" { CornerRadius = UDim.new(0, 7) }.Parent = toggle
	create "UIStroke" { Color = Color3.fromRGB(19, 10, 5), Thickness = 2 }.Parent = toggle
	create "UITextSizeConstraint" { MaxTextSize = 25 }.Parent = toggle
	toggle.Parent = row
	return row
end

local function SettingsRoot(props: Props): ScreenGui
	local screen = create "ScreenGui" {
		Name = "SettingsMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 36,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	} :: ScreenGui

	local topButton = create "TextButton" {
		Name = "SettingsButton",
		Position = UDim2.fromOffset(if UserInputService.TouchEnabled then 105 else 151, 14),
		Size = UDim2.fromOffset(if UserInputService.TouchEnabled then 32 else 40, if UserInputService.TouchEnabled then 32 else 40),
		BackgroundColor3 = Color3.fromRGB(23, 27, 34),
		BorderSizePixel = 0,
		Text = "⚙",
		TextColor3 = Color3.fromRGB(82, 174, 238),
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		AutoButtonColor = true,
		ZIndex = 2,
		Activated = props.onToggle,
	} :: TextButton
	create "UICorner" { CornerRadius = UDim.new(1, 0) }.Parent = topButton
	create "UIStroke" { Color = Color3.fromRGB(5, 9, 15), Thickness = 2 }.Parent = topButton
	create "UITextSizeConstraint" { MaxTextSize = 32 }.Parent = topButton
	topButton.Parent = screen

	local panel = create "ImageLabel" {
		Name = "SettingsPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.54),
		Size = UDim2.fromOffset(480, 320),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ShopBackground,
		ScaleType = Enum.ScaleType.Stretch,
		Visible = props.isOpen,
		ZIndex = 2,
	} :: ImageLabel
	panel.Parent = screen

	local banner = create "ImageLabel" {
		Name = "SettingsBanner",
		Position = UDim2.fromScale(0.04, -0.025),
		Size = UDim2.fromScale(0.44, 0.20),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.TopBarCard,
		ImageColor3 = Color3.fromRGB(255, 176, 72),
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 4,
	} :: ImageLabel
	banner.Parent = panel
	local heading = create "TextLabel" {
		Name = "Title",
		Position = UDim2.fromScale(0.09, 0.04),
		Size = UDim2.fromScale(0.80, 0.75),
		BackgroundTransparency = 1,
		Text = "SETTINGS",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextScaled = true,
		Font = Enum.Font.BuilderSansExtraBold,
		ZIndex = 5,
	} :: TextLabel
	create "UITextSizeConstraint" { MaxTextSize = 36 }.Parent = heading
	heading.Parent = banner

	local close = create "ImageButton" {
		Name = "CloseButton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.96, 0.07),
		Size = UDim2.fromScale(0.11, 0.17),
		BackgroundTransparency = 1,
		Image = "rbxassetid://" .. assets.ExitButton,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 5,
		Activated = props.onClose,
	} :: ImageButton
	close.Parent = panel
	makeSwitchRow("MusicRow", "MUSIC", 0.22, props.musicEnabled, props.onMusicChanged).Parent = panel
	makeSwitchRow("EffectsRow", "SOUND EFFECTS", 0.43, props.soundEffectsEnabled, props.onEffectsChanged).Parent = panel

	local credits = create "TextLabel" {
		Name = "Credits",
		Position = UDim2.fromScale(0.06, 0.68),
		Size = UDim2.fromScale(0.88, 0.27),
		BackgroundTransparency = 1,
		Text = "Credits: \"Moonlight Beach\" by Kevin MacLeod (incompetech.com)\nLicensed under Creative Commons Attribution 4.0\nhttps://creativecommons.org/licenses/by/4.0/",
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.fromRGB(28, 15, 6),
		TextStrokeTransparency = 0,
		TextScaled = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Font = Enum.Font.BuilderSans,
		ZIndex = 4,
	} :: TextLabel
	create "UITextSizeConstraint" { MaxTextSize = 16 }.Parent = credits
	credits.Parent = panel

	local viewportConnection: RBXScriptConnection? = nil
	local function layout()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		if UserInputService.TouchEnabled or viewport.X < 800 then
			topButton.AnchorPoint = Vector2.zero
			topButton.Size = UDim2.fromOffset(36, 36)
			topButton.Position = UDim2.fromOffset(176, 16)
		else
			topButton.AnchorPoint = Vector2.zero
			topButton.Size = UDim2.fromOffset(40, 40)
			topButton.Position = UDim2.fromOffset(208, 14)
		end
		panel.Size = UDim2.fromOffset(math.min(480, math.max(280, viewport.X - 24)), math.min(320, math.max(170, viewport.Y - 20)))
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
	end)
	watchCamera()
	return screen
end

return SettingsRoot
