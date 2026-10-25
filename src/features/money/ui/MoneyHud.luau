--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local create = Vide.create
local random = Random.new()

export type Props = {
	balance: () -> number,
	countingDown: () -> boolean,
}

local function MoneyHud(props: Props): (ScreenGui, () -> ())
	local gui = create "ScreenGui" {
		Name = "MoneyHud",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 25,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
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

	local pulseScale = create "UIScale" { Scale = 1 }
	pulseScale.Parent = row

	local coinIcon = create "ImageLabel" {
		Name = "CoinIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(64, 64),
		Image = "rbxassetid://" .. assets.SandDollar,
		ScaleType = Enum.ScaleType.Fit,
		LayoutOrder = 1,
	}
	coinIcon.Parent = row

	local amount = create "TextLabel" {
		Name = "Balance",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 70),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Text = function()
			return CompactNumber.format(props.balance(), if props.countingDown() then 3 else nil)
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

	local effectLayer = create "Frame" {
		Name = "CollectionCoins",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}
	effectLayer.Parent = gui

	local pulseTween: Tween? = nil
	local function pulseBalance()
		if pulseTween then
			pulseTween:Cancel()
		end
		pulseScale.Scale = 1
		local expand = TweenService:Create(pulseScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.2,
		})
		pulseTween = expand
		expand.Completed:Once(function(state)
			if state ~= Enum.PlaybackState.Completed then
				return
			end
			local shrink = TweenService:Create(pulseScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1,
			})
			pulseTween = shrink
			shrink:Play()
		end)
		expand:Play()
	end

	local function playCollection()
		local screenSize = effectLayer.AbsoluteSize
		if screenSize.X <= 0 or screenSize.Y <= 0 then
			return
		end
		local center = screenSize / 2
		local target = coinIcon.AbsolutePosition + coinIcon.AbsoluteSize / 2 - effectLayer.AbsolutePosition
		local count = random:NextInteger(7, 10)
		local remaining = count
		for index = 1, count do
			local angle = random:NextNumber(0, math.pi * 2)
			local radius = random:NextNumber(25, math.min(165, screenSize.X * 0.16))
			local start = center + Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius * 0.7)
			local size = random:NextInteger(40, 56)
			local coin = create "ImageLabel" {
				Name = "FlyingCoin",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(start.X, start.Y),
				Size = UDim2.fromOffset(0, 0),
				BackgroundTransparency = 1,
				Image = "rbxassetid://" .. assets.SandDollar,
				ScaleType = Enum.ScaleType.Fit,
				Rotation = random:NextInteger(-25, 25),
				ZIndex = 21,
			}
			coin.Parent = effectLayer
			TweenService:Create(coin, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(size, size),
			}):Play()
			task.delay(0.17 + (index - 1) * 0.035, function()
				if not coin.Parent then
					return
				end
				local fly = TweenService:Create(coin, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = UDim2.fromOffset(target.X, target.Y),
					Size = UDim2.fromOffset(25, 25),
					Rotation = 0,
				})
				fly.Completed:Once(function(state)
					coin:Destroy()
					if state == Enum.PlaybackState.Completed then
						remaining -= 1
						if remaining == 0 then
							pulseBalance()
						end
					end
				end)
				fly:Play()
			end)
		end
	end

	return gui, playCollection
end

return MoneyHud
