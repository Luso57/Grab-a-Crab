--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vide = require(ReplicatedStorage.Packages.Vide)
local LeaderboardConfig = require(ReplicatedStorage.Source.Features.Leaderboard.Modules.LeaderboardConfig)

local create = Vide.create
local LeaderboardBoard = {}

type Row = { userId: number, name: string, value: number }
type BoardState = { status: string, rows: { Row } }

local GOLD = Color3.fromRGB(255, 235, 65)
local SILVER = Color3.fromRGB(235, 245, 255)
local BRONZE = Color3.fromRGB(255, 177, 82)
local WHITE = Color3.fromRGB(250, 250, 250)

local function label(name: string, text: string, position: UDim2, size: UDim2, color: Color3, alignment: Enum.TextXAlignment): TextLabel
	local result = create "TextLabel" {
		Name = name,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		TextSize = 27,
		TextXAlignment = alignment,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Enum.Font.BuilderSansExtraBold,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0,
	}
	create "UITextSizeConstraint" { MaxTextSize = 27 }.Parent = result
	return result
end

local function makeRow(key: string, rank: number, entry: Row): Frame
	local color = if rank == 1 then GOLD elseif rank == 2 then SILVER elseif rank == 3 then BRONZE else WHITE
	local row = create "Frame" {
		Name = `Rank{rank}`,
		Size = UDim2.new(1, -8, 0, 54),
		LayoutOrder = rank,
		BackgroundColor3 = if rank <= 3 then Color3.fromRGB(94, 64, 44) else Color3.fromRGB(60, 41, 35),
		BackgroundTransparency = if rank <= 3 then 0.22 else 0.48,
		BorderSizePixel = 0,
	}
	create "UICorner" { CornerRadius = UDim.new(0, 7) }.Parent = row
	label("Rank", `#{rank}`, UDim2.fromScale(0.015, 0), UDim2.fromScale(0.095, 1), color, Enum.TextXAlignment.Left).Parent = row
	local avatar = create "ImageLabel" {
		Name = "Avatar",
		Position = UDim2.fromScale(0.115, 0.08),
		Size = UDim2.fromOffset(45, 45),
		BackgroundColor3 = Color3.fromRGB(235, 238, 225),
		Image = `rbxthumb://type=AvatarHeadShot&id={entry.userId}&w=100&h=100`,
		ScaleType = Enum.ScaleType.Crop,
	}
	create "UICorner" { CornerRadius = UDim.new(1, 0) }.Parent = avatar
	avatar.Parent = row
	label("Username", "@" .. entry.name, UDim2.fromScale(0.2, 0), UDim2.new(0.54, -5, 1, 0), color, Enum.TextXAlignment.Left).Parent = row
	label("Value", LeaderboardConfig.format(key, entry.value), UDim2.fromScale(0.73, 0), UDim2.new(0.255, -4, 1, 0), color, Enum.TextXAlignment.Right).Parent = row
	return row
end

function LeaderboardBoard.mount(playerGui: PlayerGui, model: Model, key: string, titleText: string, state: () -> BoardState): () -> ()
	local boardPart = model:FindFirstChild("Board")
	local titlePart = model:FindFirstChild("Title")
	assert(boardPart and boardPart:IsA("BasePart") and titlePart and titlePart:IsA("BasePart"), `Missing board parts in {model.Name}`)

	local cleanupTitle = Vide.mount(function()
		local surface = create "SurfaceGui" {
			Name = key .. "Title",
			Adornee = titlePart,
			Face = Enum.NormalId.Right,
			CanvasSize = Vector2.new(585, 151),
			AlwaysOnTop = false,
			Active = true,
			LightInfluence = 0,
			MaxDistance = 170,
			SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		}
		local title = create "TextLabel" {
			Name = "Title",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = titleText,
			TextColor3 = Color3.fromRGB(234, 255, 185),
			TextScaled = true,
			Font = Enum.Font.BuilderSansExtraBold,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0,
		}
		create "UITextSizeConstraint" { MaxTextSize = 62 }.Parent = title
		title.Parent = surface
		return surface
	end, playerGui)

	local cleanupBoard = Vide.mount(function()
		local surface = create "SurfaceGui" {
			Name = key .. "Board",
			Adornee = boardPart,
			Face = Enum.NormalId.Right,
			CanvasSize = Vector2.new(675, 736),
			AlwaysOnTop = false,
			Active = true,
			LightInfluence = 0,
			MaxDistance = 170,
			SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		}
		local scroll = create "ScrollingFrame" {
			Name = "Top100",
			Position = UDim2.fromScale(0.025, 0.025),
			Size = UDim2.fromScale(0.95, 0.95),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 12,
			ScrollBarImageColor3 = Color3.fromRGB(255, 212, 79),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}
		local list = create "Frame" {
			Name = "Rows",
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
		}
		create "UIPadding" {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}.Parent = list
		create "UIListLayout" {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}.Parent = list
		list.Parent = scroll
		scroll.Parent = surface

		Vide.effect(function()
			local current = state()
			for _, child in list:GetChildren() do
				if child:IsA("Frame") or child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			if #current.rows == 0 then
				local message = if current.status == "Loading" then "Loading rankings..."
					elseif current.status == "Unavailable" then "Rankings unavailable" else "No players yet"
				label("Status", message, UDim2.fromOffset(0, 0), UDim2.new(1, -15, 0, 55), WHITE, Enum.TextXAlignment.Center).Parent = list
			else
				for rank, entry in current.rows do
					makeRow(key, rank, entry).Parent = list
				end
			end
		end)
		return surface
	end, playerGui)

	return function()
		cleanupBoard()
		cleanupTitle()
	end
end

return LeaderboardBoard
