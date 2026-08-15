local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)
local UISounds = require(ReplicatedStorage.Source.Features.App.UISounds)
local SettingsServiceClient = require(ReplicatedStorage.Source.Features.Settings.SettingsServiceClient)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client

local STUD_BACKGROUND_IMAGE = "rbxassetid://88022115777392"

export type Props = {
	IsOpen: boolean,
	OnClose: () -> (),
}

type VolumeSliderProps = {
	Label: string,
	LayoutOrder: number,
	Value: number,
	OnPreview: (number) -> (),
	OnCommit: (number) -> (),
}

local SLIDER_STEPS = 20

local function snapVolume(value: number): number
	return math.clamp(math.floor(value * SLIDER_STEPS + 0.5) / SLIDER_STEPS, 0, 1)
end

local function VolumeSliderRow(props: VolumeSliderProps)
	local trackRef = React.useRef(nil)
	local activeInputRef = React.useRef(nil)
	local valueRef = React.useRef(props.Value)
	valueRef.current = props.Value

	local function updateFromX(screenX: number)
		local track = trackRef.current
		if not track then return end
		local width = track.AbsoluteSize.X
		if width <= 0 then return end

		local volume = snapVolume((screenX - track.AbsolutePosition.X) / width)
		valueRef.current = volume
		props.OnPreview(volume)
	end

	React.useEffect(function()
		local changedConnection = UserInputService.InputChanged:Connect(function(input)
			local activeInput = activeInputRef.current
			if not activeInput then return end

			if input.UserInputType == Enum.UserInputType.MouseMovement then
				if activeInput.UserInputType == Enum.UserInputType.MouseButton1 then
					updateFromX(input.Position.X)
				end
			elseif input == activeInput and input.UserInputType == Enum.UserInputType.Touch then
				updateFromX(input.Position.X)
			end
		end)

		local endedConnection = UserInputService.InputEnded:Connect(function(input)
			if input ~= activeInputRef.current then return end
			activeInputRef.current = nil
			props.OnCommit(valueRef.current)
		end)

		return function()
			changedConnection:Disconnect()
			endedConnection:Disconnect()
		end
	end, {})

	local value = snapVolume(props.Value)
	local percent = math.round(value * 100)

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(47, 50, 58),
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0.39, 0),
		ZIndex = 24,
	}, {
		Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 12) }),
		Stroke = React.createElement("UIStroke", {
			Color = Color3.fromRGB(13, 14, 18),
			Thickness = 4,
		}),
		Label = React.createElement("TextLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.06, 0.5),
			Size = UDim2.fromScale(0.34, 0.55),
			Text = props.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 25,
		}, {
			Constraint = React.createElement("UITextSizeConstraint", {
				MaxTextSize = 30,
				MinTextSize = 14,
			}),
		}),
		Track = React.createElement("TextButton", {
			ref = trackRef,
			AnchorPoint = Vector2.new(1, 0.5),
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(24, 26, 31),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.94, 0.5),
			Size = UDim2.fromScale(0.5, 0.38),
			Text = "",
			ZIndex = 25,
			[React.Event.InputBegan] = function(_track, input)
				local inputType = input.UserInputType
				if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
					return
				end
				activeInputRef.current = input
				updateFromX(input.Position.X)
			end,
		}, {
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(13, 14, 18),
				Thickness = 3,
			}),
			Fill = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(61, 202, 100),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(value, 1),
				ZIndex = 26,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Knob = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(245, 247, 250),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(value, 0.5),
				Size = UDim2.fromScale(0.09, 1.45),
				ZIndex = 28,
			}, {
				AspectRatio = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
				Stroke = React.createElement("UIStroke", {
					Color = Color3.fromRGB(13, 14, 18),
					Thickness = 3,
				}),
			}),
			Percent = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Size = UDim2.fromScale(1, 1),
				Text = string.format("%d%%", percent),
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0.2,
				ZIndex = 27,
			}, {
				Constraint = React.createElement("UITextSizeConstraint", {
					MaxTextSize = 20,
					MinTextSize = 11,
				}),
			}),
		}),
	})
end

local function SettingsRoot(props: Props)
	local initialMusicVolume = PlayerData.musicVolume()
	local initialEffectsVolume = PlayerData.soundEffectsVolume()
	if initialMusicVolume < 0 then initialMusicVolume = if PlayerData.musicEnabled() then 1 else 0 end
	if initialEffectsVolume < 0 then initialEffectsVolume = if PlayerData.soundEffectsEnabled() then 1 else 0 end

	local musicVolume, setMusicVolume = React.useState(initialMusicVolume)
	local soundEffectsVolume, setSoundEffectsVolume = React.useState(initialEffectsVolume)

	React.useEffect(function()
		return PlayerData.musicVolume.Changed(function(volume)
			if volume >= 0 then setMusicVolume(volume) end
		end)
	end, {})

	React.useEffect(function()
		return PlayerData.soundEffectsVolume.Changed(function(volume)
			if volume >= 0 then setSoundEffectsVolume(volume) end
		end)
	end, {})

	if not props.IsOpen then return nil end

	return React.createElement("Frame", {
		BackgroundColor3 = Color3.fromRGB(4, 6, 13),
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, {
		Window = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(35, 38, 44),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.48, 0.55),
			ZIndex = 21,
		}, {
			AspectRatio = React.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1.45,
				DominantAxis = Enum.DominantAxis.Height,
			}),
			Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 14) }),
			SizeConstraint = React.createElement("UISizeConstraint", {
				MaxSize = Vector2.new(720, 500),
				MinSize = Vector2.new(360, 300),
			}),
			Stroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(11, 12, 15),
				Thickness = 5,
			}),
			Header = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(72, 205, 239),
				BorderSizePixel = 0,
				ClipsDescendants = true,
				Size = UDim2.new(1, 0, 0.22, 0),
				ZIndex = 23,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 11) }),
				Stroke = React.createElement("UIStroke", {
					Color = Color3.fromRGB(15, 25, 31),
					Thickness = 4,
				}),
				StudTexture = React.createElement("ImageLabel", {
					BackgroundTransparency = 1,
					Image = STUD_BACKGROUND_IMAGE,
					ImageColor3 = Color3.fromRGB(115, 225, 249),
					ImageTransparency = 0.42,
					ScaleType = Enum.ScaleType.Tile,
					Size = UDim2.fromScale(1, 1),
					TileSize = UDim2.fromOffset(38, 38),
					ZIndex = 23,
				}),
				Title = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundTransparency = 1,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.045, 0.5),
					Size = UDim2.fromScale(0.68, 0.7),
					Text = "SETTINGS",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeColor3 = Color3.new(0, 0, 0),
					TextStrokeTransparency = 0,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 24,
				}),
				Close = React.createElement("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundColor3 = Color3.fromRGB(222, 42, 45),
					BorderSizePixel = 0,
					Font = Enum.Font.FredokaOne,
					Position = UDim2.fromScale(0.955, 0.5),
					Size = UDim2.fromScale(0.12, 0.68),
					Text = "X",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextStrokeColor3 = Color3.new(0, 0, 0),
					TextStrokeTransparency = 0,
					ZIndex = 25,
					[React.Event.Activated] = function()
						UISounds.playSelect()
						props.OnClose()
					end,
				}, {
					AspectRatio = React.createElement("UIAspectRatioConstraint", { AspectRatio = 1 }),
					Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 7) }),
					Stroke = React.createElement("UIStroke", {
						Color = Color3.fromRGB(95, 9, 12),
						Thickness = 4,
					}),
				}),
			}),
			Content = React.createElement("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(27, 29, 34),
				BorderSizePixel = 0,
				Image = STUD_BACKGROUND_IMAGE,
				ImageColor3 = Color3.fromRGB(62, 65, 72),
				ImageTransparency = 0.58,
				Position = UDim2.fromScale(0.045, 0.27),
				ScaleType = Enum.ScaleType.Tile,
				Size = UDim2.fromScale(0.91, 0.66),
				TileSize = UDim2.fromOffset(42, 42),
				ZIndex = 22,
			}, {
				Corner = React.createElement("UICorner", { CornerRadius = UDim.new(0, 9) }),
				Padding = React.createElement("UIPadding", {
					PaddingBottom = UDim.new(0.08, 0),
					PaddingLeft = UDim.new(0.05, 0),
					PaddingRight = UDim.new(0.05, 0),
					PaddingTop = UDim.new(0.08, 0),
				}),
				Layout = React.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.09, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				Music = React.createElement(VolumeSliderRow, {
					Label = "MUSIC",
					LayoutOrder = 1,
					Value = musicVolume,
					OnPreview = function(volume)
						setMusicVolume(volume)
						SettingsServiceClient:previewAudioVolume("musicVolume", volume)
					end,
					OnCommit = function(volume)
						SettingsServiceClient:setAudioVolume("musicVolume", volume)
					end,
				}),
				SoundEffects = React.createElement(VolumeSliderRow, {
					Label = "SOUND EFFECTS",
					LayoutOrder = 2,
					Value = soundEffectsVolume,
					OnPreview = function(volume)
						setSoundEffectsVolume(volume)
						SettingsServiceClient:previewAudioVolume("soundEffectsVolume", volume)
					end,
					OnCommit = function(volume)
						SettingsServiceClient:setAudioVolume("soundEffectsVolume", volume)
					end,
				}),
			}),
		}),
	})
end

return SettingsRoot
