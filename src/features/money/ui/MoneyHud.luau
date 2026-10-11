--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local create = Vide.create

export type Props = {
	balance: () -> number,
}

local function MoneyHud(props: Props): ScreenGui
	local gui = create "ScreenGui" {
		Name = "MoneyHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 15,
	}

	local row = create "Frame" {
		Name = "BalanceRow",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0),
		Size = UDim2.fromOffset(400, 76),
		BackgroundTransparency = 1,
	}
	row.Parent = gui
	create "UIListLayout" {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 0),
	}.Parent = row

	create "ImageLabel" {
		Name = "CoinIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(64, 64),
		Image = "rbxassetid://" .. assets.SandDollar,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
	}.Parent = row

	local amount = create "TextLabel" {
		Name = "Balance",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 70),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Text = function()
			return CompactNumber.format(props.balance())
		end,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
		TextSize = 50,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.BuilderSansExtraBold,
	}
	amount.Parent = row
	create "UIStroke" {
		Color = Color3.new(0, 0, 0),
		Thickness = 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	}.Parent = amount

	return gui
end

return MoneyHud
