--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local create = Vide.create

local TravelBar = {}
local CARD_COLOR = Color3.fromRGB(255, 176, 72)

local function card(name: string, position: UDim2, onActivated: () -> ()): ImageButton
	local button = create "ImageButton" {
		Name = name,
		Position = position,
		Size = UDim2.fromOffset(196, 58),
		BackgroundTransparency = 1,
		Image = `rbxassetid://{assets.TopBarCard}`,
		ImageColor3 = CARD_COLOR,
		ScaleType = Enum.ScaleType.Stretch,
		AutoButtonColor = true,
		Activated = onActivated,
	}
	local title = create "TextLabel" {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, -3),
		Size = UDim2.new(1, -16, 1, -8),
		BackgroundTransparency = 1,
		Text = string.upper(name),
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 1,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	title.Parent = button
	create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}.Parent = title
	return button
end

function TravelBar.mount(playerGui: PlayerGui, onTravel: (string) -> (), isTankOpen: () -> boolean)
	Vide.mount(function()
		local gui = create "ScreenGui" {
			Name = "TravelBar",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 30,
		}
		local clickSound = create "Sound" {
			Name = "TabClickSound",
			SoundId = "rbxassetid://132948338000932",
			Volume = 1,
		}
		clickSound.Parent = gui
		local function travel(destination: string)
			if isTankOpen() then
				return
			end
			clickSound.TimePosition = 0
			clickSound:Play()
			onTravel(destination)
		end
		local row = create "CanvasGroup" {
			Name = "Cards",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 5),
			Size = UDim2.fromOffset(408, 58),
			BackgroundTransparency = 1,
			GroupTransparency = function()
				return if isTankOpen() then 0.55 else 0
			end,
		}
		row.Parent = gui
		local home = card("Home", UDim2.fromOffset(0, 0), function()
			travel("Home")
		end)
		home.Parent = row
		local shop = card("Shop", UDim2.fromOffset(212, 0), function()
			travel("Shop")
		end)
		shop.Parent = row
		local function layout()
			local camera = Workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
			local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 650), 0.67, 1)
			scale = math.min(scale, (viewport.X - 24) / 408)
			local cardWidth = math.round(196 * scale)
			local cardHeight = math.round(58 * scale)
			local gap = math.round(16 * scale)
			row.Size = UDim2.fromOffset(cardWidth * 2 + gap, cardHeight)
			row.Position = UDim2.new(0.5, 0, 0, if viewport.X < 600 then 54 else 5)
			home.Size = UDim2.fromOffset(cardWidth, cardHeight)
			shop.Size = UDim2.fromOffset(cardWidth, cardHeight)
			shop.Position = UDim2.fromOffset(cardWidth + gap, 0)
			for _, button in { home, shop } do
				local title = button:FindFirstChild("Title") :: TextLabel
				title.TextSize = math.round(30 * scale)
			end
		end

		local viewportConnection: RBXScriptConnection? = nil
		local function watchCamera()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
			local camera = Workspace.CurrentCamera
			viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) else nil
			layout()
		end
		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
		gui.Destroying:Connect(function()
			cameraConnection:Disconnect()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
		end)
		watchCamera()
		return gui
	end, playerGui)
end

return TravelBar
