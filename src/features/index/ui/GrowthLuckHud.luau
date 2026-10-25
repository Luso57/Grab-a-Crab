--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create
local GrowthLuckHud = {}

function GrowthLuckHud.mount(playerGui: PlayerGui, growthLuck: () -> number, onActivated: () -> ())
	Vide.mount(function()
		local gui = create "ScreenGui" {
			Name = "GrowthLuckHud",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 25,
		}

		local button = create "ImageButton" {
			Name = "GrowthLuckButton",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -10),
			Size = UDim2.fromOffset(58, 58),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. assets.IndexClover,
			ScaleType = Enum.ScaleType.Fit,
			AutoButtonColor = false,
			Activated = onActivated,
		}
		button.Parent = gui

		local value = create "TextLabel" {
			Name = "Multiplier",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.fromOffset(62, 22),
			BackgroundTransparency = 1,
			Text = function()
				return "x" .. tostring(growthLuck())
			end,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			Font = Enum.Font.BuilderSansExtraBold,
			ZIndex = 2,
		}
		create "UITextSizeConstraint" { MaxTextSize = 20 }.Parent = value
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = Color3.new(0, 0, 0),
			Thickness = 2,
		}.Parent = value
		value.Parent = button

		return gui
	end, playerGui)
end

return GrowthLuckHud
