--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)
local create = Vide.create
local random = Random.new()

export type Props = {
	balance: () -> number | string,
}

local function MoneyHud(props: Props, playerGui: PlayerGui): (ScreenGui, (Vector2?) -> ())
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

	local function layout()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 650), 0.67, 1)
		row.Position = UDim2.new(0, math.round(20 * scale), 0.5, 0)
		row.Size = UDim2.fromOffset(math.round(400 * scale), math.round(76 * scale))
		coinIcon.Size = UDim2.fromOffset(math.round(64 * scale), math.round(64 * scale))
		amount.Size = UDim2.fromOffset(0, math.round(70 * scale))
		amount.TextSize = math.round(50 * scale)
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

	local effectGui = create "ScreenGui" {
		Name = "MoneyCollectionEffect",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 51,
	}
	local effectLayer = create "Frame" {
		Name = "CollectionCoins",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 20,
	}
	effectLayer.Parent = effectGui
	effectGui.Parent = playerGui
	gui.Destroying:Connect(function()
		effectGui:Destroy()
	end)

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

	local function playCollection(startPosition: Vector2?)
		local screenSize = effectLayer.AbsoluteSize
		if screenSize.X <= 0 or screenSize.Y <= 0 then
			return
		end
		local center = if startPosition then startPosition - effectLayer.AbsolutePosition else screenSize / 2
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
