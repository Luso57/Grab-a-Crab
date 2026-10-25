--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function TravelBar.mount(playerGui: PlayerGui, onTravel: (string) -> ())
	Vide.mount(function()
		local gui = create "ScreenGui" {
			Name = "TravelBar",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 30,
		}
		local row = create "Frame" {
			Name = "Cards",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 5),
			Size = UDim2.fromOffset(408, 58),
			BackgroundTransparency = 1,
		}
		row.Parent = gui
		card("Home", UDim2.fromOffset(0, 0), function()
			onTravel("Home")
		end).Parent = row
		card("Shop", UDim2.fromOffset(212, 0), function()
			onTravel("Shop")
		end).Parent = row
		return gui
	end, playerGui)
end

return TravelBar