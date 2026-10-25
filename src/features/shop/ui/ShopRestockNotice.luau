--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local ShopRestockNotice = {}

function ShopRestockNotice.mount(playerGui: PlayerGui, message: string?, guiName: string?): () -> ()
	local banner: Frame = nil :: any
	local label: TextLabel = nil :: any
	local stroke: UIStroke = nil :: any
	local sound: Sound = nil :: any

	Vide.mount(function()
		stroke = create "UIStroke" {
			Color = Color3.fromRGB(35, 18, 4),
			Thickness = 3,
			Transparency = 1,
		}
		label = create "TextLabel" {
			Name = "Message",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Text = message or "SHOP HAS RESTOCKED",
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 1,
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
			ZIndex = 2,
			stroke,
			create "UITextSizeConstraint" {
				MaxTextSize = 30,
			},
		}
		banner = create "Frame" {
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 1 / 3),
			Size = UDim2.new(0.78, 0, 0, 48),
			BackgroundColor3 = Color3.fromRGB(232, 232, 232),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
			create "UIGradient" {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(175, 175, 175)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(245, 245, 245)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(175, 175, 175)),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.16, 0),
					NumberSequenceKeypoint.new(0.84, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			},
			label,
		}
		sound = create "Sound" {
			Name = "RestockSound",
			SoundId = "rbxassetid://123582256549202",
			Volume = 1,
		}
		return create "ScreenGui" {
			Name = guiName or "ShopRestockNotice",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 50,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			banner,
			sound,
		}
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

		TweenService:Create(banner, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
		TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()

		task.delay(3.25, function()
			if version ~= currentVersion then
				return
			end
			TweenService:Create(banner, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local fade = TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 })
			fade.Completed:Once(function()
				if version == currentVersion then
					banner.Visible = false
				end
			end)
			fade:Play()
		end)
	end
end

return ShopRestockNotice
