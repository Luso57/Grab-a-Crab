--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local ServerLuckAnnouncement = {}

function ServerLuckAnnouncement.mount(playerGui: PlayerGui): (string, number) -> ()
	local banner: Frame = nil :: any
	local label: TextLabel = nil :: any

	Vide.mount(function()
		banner = create "Frame" {
			Name = "AnnouncementStrip",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.12),
			Size = UDim2.new(0.86, 0, 0, 52),
			BackgroundColor3 = Color3.fromRGB(56, 186, 70),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Visible = false,
		}
		create "UICorner" { CornerRadius = UDim.new(0, 9) }.Parent = banner
		create "UIStroke" {
			Color = Color3.fromRGB(12, 76, 22),
			Thickness = 3,
		}.Parent = banner
		label = create "TextLabel" {
			Name = "Message",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 1,
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			Font = Enum.Font.BuilderSansExtraBold,
		}
		create "UITextSizeConstraint" { MaxTextSize = 30 }.Parent = label
		label.Parent = banner
		local gui = create "ScreenGui" {
			Name = "ServerLuckAnnouncement",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 60,
		}
		banner.Parent = gui
		return gui
	end, playerGui)

	local version = 0
	return function(buyerName: string, multiplier: number)
		version += 1
		local currentVersion = version
		label.Text = `{buyerName} bought {multiplier}x server luck`
		banner.Visible = true
		banner.BackgroundTransparency = 1
		label.TextTransparency = 1
		TweenService:Create(banner, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
		TweenService:Create(label, TweenInfo.new(0.2), { TextTransparency = 0 }):Play()
		task.delay(3.5, function()
			if currentVersion ~= version then
				return
			end
			TweenService:Create(banner, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
			local fade = TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 })
			fade.Completed:Once(function()
				if currentVersion == version then
					banner.Visible = false
				end
			end)
			fade:Play()
		end)
	end
end

return ServerLuckAnnouncement
