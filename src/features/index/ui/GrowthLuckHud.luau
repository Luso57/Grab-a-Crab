--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Vide = require(ReplicatedStorage.Packages.Vide)
local assets = require(ReplicatedStorage.Source.Assets.UI.ShopImages)

local create = Vide.create
local GrowthLuckHud = {}
local random = Random.new()

function GrowthLuckHud.mount(playerGui: PlayerGui, growthLuck: () -> number, serverMultiplier: () -> number, remainingSeconds: () -> number, onActivated: () -> ()): (Vector2, () -> ()) -> ()
	local playReward: ((Vector2, () -> ()) -> ())? = nil
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
		local buttonScale = create "UIScale" { Scale = 1 }
		buttonScale.Parent = button
		local claimScale = create "UIScale" { Scale = 1 }
		claimScale.Parent = button

		local value = create "TextLabel" {
			Name = "Multiplier",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 2),
			Size = UDim2.fromOffset(62, 22),
			BackgroundTransparency = 1,
			Text = function()
				return "x" .. tostring(growthLuck())
			end,
			TextColor3 = function()
				return if serverMultiplier() > 1 then Color3.fromRGB(90, 245, 107) else Color3.new(1, 1, 1)
			end,
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

		local timer = create "TextLabel" {
			Name = "ServerLuckCountdown",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 76, 1, -22),
			Size = UDim2.fromOffset(106, 28),
			BackgroundTransparency = 1,
			Visible = function()
				return serverMultiplier() > 1 and remainingSeconds() > 0
			end,
			Text = function()
				local seconds = remainingSeconds()
				return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
			end,
			TextColor3 = Color3.fromRGB(90, 245, 107),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			Font = Enum.Font.BuilderSansExtraBold,
		}
		create "UITextSizeConstraint" { MaxTextSize = 27 }.Parent = timer
		timer.Parent = gui
		local function resize()
			local camera = Workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
			local scale = math.clamp(math.min(viewport.X / 1000, viewport.Y / 650), 0.78, 1)
			button.Size = UDim2.fromOffset(math.round(58 * scale), math.round(58 * scale))
			value.Size = UDim2.fromOffset(math.round(62 * scale), math.round(22 * scale))
			timer.Position = UDim2.new(0, math.round(76 * scale), 1, -math.round(22 * scale))
			timer.Size = UDim2.fromOffset(math.round(106 * scale), math.round(28 * scale))
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
		gui.Destroying:Connect(function()
			cameraConnection:Disconnect()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
		end)
		watchCamera()

		local pulseTween: Tween? = nil
		Vide.effect(function()
			local active = serverMultiplier() > 1
			button.ImageColor3 = if active then Color3.fromRGB(90, 245, 107) else Color3.new(1, 1, 1)
			if pulseTween then
				pulseTween:Cancel()
				pulseTween = nil
			end
			buttonScale.Scale = 1
			if active then
				pulseTween = TweenService:Create(buttonScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.14 })
				pulseTween:Play()
			end
		end)

		local effectGui = create "ScreenGui" {
			Name = "GrowthLuckClaimEffect",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 53,
		}
		local effectLayer = create "Frame" {
			Name = "FlyingClovers",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}
		effectLayer.Parent = effectGui
		effectGui.Parent = playerGui
		gui.Destroying:Connect(function()
			effectGui:Destroy()
		end)

		local claimPulse: Tween? = nil
		local function pulse()
			if claimPulse then
				claimPulse:Cancel()
			end
			claimScale.Scale = 1
			local grow = TweenService:Create(claimScale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.32 })
			claimPulse = grow
			grow.Completed:Once(function(state)
				if state ~= Enum.PlaybackState.Completed then
					return
				end
				local shrink = TweenService:Create(claimScale, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 })
				claimPulse = shrink
				shrink:Play()
			end)
			grow:Play()
		end

		playReward = function(startPosition: Vector2, onArrived: () -> ())
			if not effectLayer.Parent or effectLayer.AbsoluteSize.X <= 0 then
				onArrived()
				return
			end
			local origin = startPosition - effectLayer.AbsolutePosition
			local remaining = 6
			local function arrived()
				remaining -= 1
				if remaining == 0 then
					onArrived()
					pulse()
				end
			end
			for index = 1, 6 do
				local angle = (index - 1) * math.pi / 3 + random:NextNumber(-0.2, 0.2)
				local radius = random:NextNumber(22, 60)
				local start = origin + Vector2.new(math.cos(angle) * radius, math.sin(angle) * radius)
				local clover = create "ImageLabel" {
					Name = "FlyingGrowthLuck",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(start.X, start.Y),
					Size = UDim2.fromOffset(0, 0),
					BackgroundTransparency = 1,
					Image = "rbxassetid://" .. assets.IndexClover,
					ScaleType = Enum.ScaleType.Fit,
					Rotation = random:NextInteger(-25, 25),
					ZIndex = 21,
				}
				clover.Parent = effectLayer
				TweenService:Create(clover, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(44, 44) }):Play()
				task.delay(0.15 + (index - 1) * 0.04, function()
					if not clover.Parent then
						arrived()
						return
					end
					local target = button.AbsolutePosition + button.AbsoluteSize / 2 - effectLayer.AbsolutePosition
					local fly = TweenService:Create(clover, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Position = UDim2.fromOffset(target.X, target.Y),
						Size = UDim2.fromOffset(24, 24),
						Rotation = 0,
					})
					fly.Completed:Once(function()
						clover:Destroy()
						arrived()
					end)
					fly:Play()
				end)
			end
		end

		return gui
	end, playerGui)
	return function(startPosition: Vector2, onArrived: () -> ())
		local play = playReward
		if play then
			play(startPosition, onArrived)
		else
			onArrived()
		end
	end
end

return GrowthLuckHud
