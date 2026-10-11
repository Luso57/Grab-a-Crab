--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local IncubatorCountdown = {}

function IncubatorCountdown.attach(egg: Model, incubator: Model): () -> ()
	local driver = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
	if not driver or not driver:IsA("BasePart") then
		return function() end
	end

	local box, size = egg:GetBoundingBox()
	local topOffset = box.Position.Y + size.Y / 2 - driver.Position.Y + 0.95
	local countdown = Vide.source("")
	local destroyed = false
	local billboard: BillboardGui? = nil

	local unmount = Vide.mount(function()
		local gui = create "BillboardGui" {
			Name = "IncubatorCountdown",
			Adornee = driver,
			Size = UDim2.fromScale(3.8, 1.1),
			StudsOffsetWorldSpace = function()
				return Vector3.new(0, topOffset + (if countdown() == "READY" then 0.25 else 0), 0)
			end,
			MaxDistance = 40,
			AlwaysOnTop = true,
			LightInfluence = 0,
		}
		local label = create "TextLabel" {
			Name = "TimeRemaining",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = countdown,
			TextColor3 = Color3.new(1, 1, 1),
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
			Visible = function()
				return countdown() ~= ""
			end,
		}
		label.Parent = gui
		create "UIStroke" {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			Color = Color3.new(0, 0, 0),
			Thickness = 1.5,
		}.Parent = label
		create "UITextSizeConstraint" { MaxTextSize = 36 }.Parent = label
		billboard = gui
		return gui
	end, Players.LocalPlayer:WaitForChild("PlayerGui"))

	task.spawn(function()
		while not destroyed and egg.Parent == incubator do
			local hatchAt = incubator:GetAttribute("IncubatingHatchAtUnixMs")
			local nextText = ""
			if typeof(hatchAt) == "number" then
				local remaining = math.max(0, math.ceil((hatchAt - DateTime.now().UnixTimestampMillis) / 1000))
				nextText = if remaining == 0 then "READY"
					else string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
			end
			if countdown() ~= nextText then
				countdown(nextText)
			end
			task.wait(0.1)
		end
	end)

	return function()
		if destroyed then
			return
		end
		destroyed = true
		unmount()
		if billboard then
			billboard:Destroy()
		end
	end
end

return IncubatorCountdown
