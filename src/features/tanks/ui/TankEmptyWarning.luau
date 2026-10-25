--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local TankEmptyWarning = {}

function TankEmptyWarning.mount(playerGui: PlayerGui): () -> ()
	local banner: Frame = nil :: any
	local label: TextLabel = nil :: any
	local stroke: UIStroke = nil :: any
	local sound: Sound = nil :: any

	Vide.mount(function()
		stroke = create "UIStroke" {
			Color = Color3.fromRGB(42, 0, 0),
			Thickness = 3,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}
		label = create "TextLabel" {
			Name = "Message",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = "EMPTY TANK OUT BEFORE REMOVING",
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 1,
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
			ZIndex = 2,
		}
		stroke.Parent = label
		create "UITextSizeConstraint" {
			MaxTextSize = 30,
		}.Parent = label
		banner = create "Frame" {
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1 / 3),
			Size = UDim2.new(0.78, 0, 0, 48),
			BackgroundColor3 = Color3.fromRGB(218, 38, 38),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
		}
		create "UIGradient" {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(139, 14, 18)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 73, 73)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 14, 18)),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.16, 0),
				NumberSequenceKeypoint.new(0.84, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}.Parent = banner
		label.Parent = banner
		sound = create "Sound" {
			Name = "TankWarningSound",
			SoundId = "rbxassetid://550209561",
			Volume = 1,
		}
		local gui = create "ScreenGui" {
			Name = "TankEmptyWarning",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 51,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}
		banner.Parent = gui
		sound.Parent = gui
		return gui
	end, playerGui)

	local version = 0
	return function()
		version += 1
		local currentVersion = version
		banner.Visible = true
		banner.BackgroundTransparency = 1
		label.TextTransparency = 1
		stroke.Transparency = 1
		sound.TimePosition = 0
		sound:Play()

		TweenService:Create(banner, TweenInfo.new(0.25), { BackgroundTransparency = 0.3 }):Play()
		TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()

		task.delay(1.5, function()
			if version ~= currentVersion then
				return
			end
			TweenService:Create(banner, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			local fade = TweenService:Create(stroke, TweenInfo.new(0.3), { Transparency = 1 })
			fade.Completed:Once(function()
				if version == currentVersion then
					banner.Visible = false
				end
			end)
			fade:Play()
		end)
	end
end

return TankEmptyWarning