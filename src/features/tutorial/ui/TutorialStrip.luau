--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local TutorialStrip = {}

function TutorialStrip.mount(playerGui: PlayerGui, message: () -> string): () -> ()
	return Vide.mount(function()
		local banner = create "Frame" {
			Name = "Banner",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.075),
			Size = UDim2.new(0.72, 0, 0, 58),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Visible = function()
				return message() ~= ""
			end,
			create "UIGradient" {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 112, 199)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(72, 216, 235)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 112, 199)),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.12, 0),
					NumberSequenceKeypoint.new(0.88, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
			},
			create "TextLabel" {
				Name = "Instruction",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = message,
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeColor3 = Color3.fromRGB(9, 37, 64),
				TextStrokeTransparency = 0.2,
				TextScaled = true,
				Font = Enum.Font.BuilderSansExtraBold,
				create "UITextSizeConstraint" { MaxTextSize = 32 },
			},
		}
		local uiScale = Instance.new("UIScale")
		uiScale.Name = "MobileScale"
		uiScale.Parent = banner

		local screen = create "ScreenGui" {
			Name = "TutorialStrip",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 90,
			banner,
		}

		local viewportConnection: RBXScriptConnection? = nil
		local function layout()
			local camera = Workspace.CurrentCamera
			local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
			local isMobile = math.min(viewport.X, viewport.Y) < 600
			uiScale.Scale = if isMobile then 0.82 else 1
			banner.Position = UDim2.fromScale(0.5, if isMobile then 0.095 else 0.075)
		end
		local function watchCamera()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
			local camera = Workspace.CurrentCamera
			viewportConnection = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout) else nil
			layout()
		end
		local cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
		screen.Destroying:Connect(function()
			cameraConnection:Disconnect()
			if viewportConnection then
				viewportConnection:Disconnect()
			end
		end)
		watchCamera()
		return screen
	end, playerGui)
end

return TutorialStrip
