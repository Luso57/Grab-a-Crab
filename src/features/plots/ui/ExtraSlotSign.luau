--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlotExtraSlots = require(ReplicatedStorage.Source.Features.Plots.Modules.PlotExtraSlots)
local Money = require(ReplicatedStorage.Source.Game.Money)

local create = Vide.create
local ExtraSlotSign = {}
local SLOT_IMAGE = "rbxassetid://85616034755765"

function ExtraSlotSign.mount(plotModel: Model, playerGui: PlayerGui, balance: () -> number | string, onBuy: () -> ()): (() -> ())?
	local sign = plotModel:FindFirstChild("ExtraSlotSign")
	local panel = if sign then sign:FindFirstChild("FrontPanel") else nil
	if not panel or not panel:IsA("BasePart") then
		return nil
	end

	local purchased = Vide.source(PlotExtraSlots.normalizeCount(plotModel:GetAttribute("ExtraSlotsPurchased")))
	local owner = Vide.source(plotModel:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId)
	local countConnection = plotModel:GetAttributeChangedSignal("ExtraSlotsPurchased"):Connect(function()
		purchased(PlotExtraSlots.normalizeCount(plotModel:GetAttribute("ExtraSlotsPurchased")))
	end)
	local ownerConnection = plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		owner(plotModel:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId)
	end)

	local cleanup = Vide.mount(function()
		local buttonText = Vide.derive(function()
			local price = PlotExtraSlots.getPrice(purchased())
			return if price then "BUY $" .. CompactNumber.format(price) else "MAX"
		end)
		local canBuy = Vide.derive(function()
			local price = PlotExtraSlots.getPrice(purchased())
			return owner() and price ~= nil and Money.compare(balance(), tostring(price or 0)) >= 0
		end)
		local buttonColor = Vide.derive(function()
			local price = PlotExtraSlots.getPrice(purchased())
			if not owner() or not price then
				return Color3.fromRGB(115, 115, 115)
			end
			return if Money.compare(balance(), tostring(price)) < 0 then Color3.fromRGB(220, 48, 48) else Color3.fromRGB(0, 235, 37)
		end)
		local buttonStrokeColor = Vide.derive(function()
			local price = PlotExtraSlots.getPrice(purchased())
			if not owner() or not price then
				return Color3.fromRGB(65, 65, 65)
			end
			return if Money.compare(balance(), tostring(price)) < 0 then Color3.fromRGB(105, 15, 15) else Color3.fromRGB(9, 65, 33)
		end)
		local buySound = create "Sound" {
			Name = "BuyClickSound",
			SoundId = "rbxassetid://4612383453",
			Volume = 1,
		}
		return create "SurfaceGui" {
			Name = "ExtraSlotUpgrade",
			Adornee = panel,
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 80,
			LightInfluence = 0,
			AlwaysOnTop = false,
			Active = true,
			ToolPunchThroughDistance = 20,
			ResetOnSpawn = false,
			create "Frame" {
				Name = "Content",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				create "TextLabel" {
					Name = "Title",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.18),
					Size = UDim2.fromScale(0.94, 0.19),
					BackgroundTransparency = 1,
					Text = "BUY AN EXTRA SLOT",
					Font = Enum.Font.BuilderSansExtraBold,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					create "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = Color3.new(0, 0, 0),
						Thickness = 3,
					},
				},
				create "ImageLabel" {
					Name = "ExtraSlotImage",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.78, 0.44),
					BackgroundTransparency = 1,
					Image = SLOT_IMAGE,
					ScaleType = Enum.ScaleType.Fit,
				},
				create "TextLabel" {
					Name = "QuantityBadge",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.8, 0.59),
					Size = UDim2.fromScale(0.2, 0.21),
					BackgroundTransparency = 1,
					Text = "+1",
					Font = Enum.Font.BuilderSansExtraBold,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					create "UIStroke" {
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
						Color = Color3.new(0, 0, 0),
						Thickness = 3,
					},
				},
				create "TextButton" {
					Name = "BuyExtraSlotButton",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.82),
					Size = UDim2.fromScale(0.62, 0.17),
					BackgroundColor3 = buttonColor,
					BorderSizePixel = 0,
					AutoButtonColor = canBuy,
					Active = canBuy,
					Text = buttonText,
					Font = Enum.Font.BuilderSansExtraBold,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					Activated = function()
						if canBuy() then
							onBuy()
							buySound.TimePosition = 0
							buySound:Play()
						end
					end,
					buySound,
					create "UICorner" { CornerRadius = UDim.new(0.16, 0) },
					create "UIStroke" { Color = buttonStrokeColor, Thickness = 4 },
				},
			},
		}
	end, playerGui)

	local function removeLegacyLettering(child: Instance)
		if child.Name == "Lettering" and child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
	local letteringConnection = panel.ChildAdded:Connect(removeLegacyLettering)
	local lettering = panel:FindFirstChild("Lettering")
	if lettering then
		removeLegacyLettering(lettering)
	end

	return function()
		letteringConnection:Disconnect()
		countConnection:Disconnect()
		ownerConnection:Disconnect()
		cleanup()
	end
end

return ExtraSlotSign
