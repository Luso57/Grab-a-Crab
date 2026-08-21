local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages.ReactCharm)
local useIsPhoneViewport = require(ReplicatedStorage.Source.Features.App.Hooks.useIsPhoneViewport)
local CompactNumber = require(ReplicatedStorage.Source.Game.CompactNumber)
local PlayerData = require(ReplicatedStorage.Source.Game.Data).client
local LeaderboardConfig = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardConfig)
local LeaderboardSlice = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardSlice)
local LeaderboardTypes = require(ReplicatedStorage.Source.Features.Leaderboards.LeaderboardTypes)

local e = React.createElement

type BoardKind = LeaderboardTypes.BoardKind
type Entry = LeaderboardTypes.Entry
type BoardRecord = {
	model: Model,
	board: BasePart,
	title: BasePart,
	kind: BoardKind,
}

local RANK_COLORS = {
	Color3.fromRGB(255, 236, 38),
	Color3.fromRGB(225, 233, 240),
	Color3.fromRGB(255, 156, 44),
}

local function formatTime(value: number): string
	local seconds = math.max(0, math.floor(value))
	local days = math.floor(seconds / 86_400)
	local hours = math.floor(seconds % 86_400 / 3_600)
	local minutes = math.floor(seconds % 3_600 / 60)
	if days > 0 then
		return `{days}d {hours}h`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end
	return `{minutes}m`
end

local function formatScore(kind: BoardKind, value: number): string
	if kind == "timePlayed" then
		return formatTime(value)
	elseif kind == "robuxSpent" then
		return `R$ {CompactNumber.format(value, 2)}`
	end
	return CompactNumber.format(value, 2)
end

local function outlinedText(props: { [string]: any }, thickness: number?, isPhone: boolean?)
	if isPhone then
		props.TextStrokeTransparency = 0
		return e('TextLabel', props)
	end

	return e("TextLabel", props, {
		Stroke = e("UIStroke", {
			Color = Color3.new(0, 0, 0),
			LineJoinMode = Enum.LineJoinMode.Round,
			Thickness = thickness or 4,
		}),
	})
end

local function LeaderboardRow(props: {
	entry: Entry,
	rank: number,
	kind: BoardKind,
	isPhone: boolean,
})
	local color = RANK_COLORS[props.rank]
	if not color then
		color = if props.rank % 2 == 0 then Color3.fromRGB(225, 246, 255) else Color3.fromRGB(255, 255, 255)
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.025, 0.018 + (props.rank - 1) * 0.0865),
		Size = UDim2.fromScale(0.95, 0.078),
	}, {
		Rank = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.fromScale(0.11, 1),
			Text = `#{props.rank}`,
			TextColor3 = color,
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 5, props.isPhone),
		Avatar = e("ImageLabel", {
			BackgroundColor3 = Color3.fromRGB(45, 45, 45),
			Image = `rbxthumb://type=AvatarHeadShot&id={props.entry.userId}&w=150&h=150`,
			Position = UDim2.fromScale(0.115, 0.02),
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromScale(0.075, 0.96),
		}, {
			Aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3 }),
		}),
		Username = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.205, 0),
			Size = UDim2.fromScale(0.5, 1),
			Text = `@{props.entry.username}`,
			TextColor3 = color,
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, 4, props.isPhone),
		Score = outlinedText({
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.71, 0),
			Size = UDim2.fromScale(0.29, 1),
			Text = formatScore(props.kind, props.entry.score),
			TextColor3 = color,
			TextScaled = true,
			TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, 4, props.isPhone),
	})
end

local function usePersonalScores(): { [BoardKind]: number }
	local currency, setCurrency = React.useState(PlayerData.currency())
	local timePlayed, setTimePlayed = React.useState(PlayerData.timePlayedSeconds())
	local robuxSpent, setRobuxSpent = React.useState(PlayerData.robuxSpent())

	React.useEffect(function()
		local currencyCleanup = PlayerData.currency.Changed(setCurrency)
		local timeCleanup = PlayerData.timePlayedSeconds.Changed(setTimePlayed)
		local robuxCleanup = PlayerData.robuxSpent.Changed(setRobuxSpent)
		local active = true
		task.spawn(function()
			while active do
				task.wait(1)
				if active then
					setTimePlayed(function(previous)
						return previous + 1
					end)
				end
			end
		end)

		return function()
			active = false
			currencyCleanup()
			timeCleanup()
			robuxCleanup()
		end
	end, {})

	return {
		timePlayed = timePlayed,
		mostMoney = currency,
		robuxSpent = robuxSpent,
	}
end

local function isPositionOnPlot(position: Vector3, plotModel: Model?): boolean
	if not plotModel then
		return false
	end
	local plotCFrame, plotSize = plotModel:GetBoundingBox()
	local localPosition = plotCFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= plotSize.X * 0.5
		and math.abs(localPosition.Z) <= plotSize.Z * 0.5
end

local function useIsOnPlot(record: BoardRecord, isPhone: boolean): boolean
	local isOnPlot, setIsOnPlot = React.useState(false)

	React.useEffect(function()
		local elapsed = math.huge
		local plotModel = if record.model.Parent and record.model.Parent:IsA("Model")
			then record.model.Parent
			else nil
		local function update()
			local character = Players.LocalPlayer.Character
			local rootPart = if character then character:FindFirstChild("HumanoidRootPart") else nil
			if rootPart and rootPart:IsA("BasePart") then
				setIsOnPlot(isPositionOnPlot(rootPart.Position, plotModel))
			else
				setIsOnPlot(false)
			end
		end

		update()
		local connection = RunService.Heartbeat:Connect(function(deltaTime)
			elapsed += deltaTime
			if elapsed < (if isPhone then 0.35 else 0.1) then
				return
			end
			elapsed = 0
			update()
		end)

		return function()
			connection:Disconnect()
		end
	end, { record, isPhone })

	return isOnPlot
end

local function BoardSurface(props: {
	record: BoardRecord,
	entries: { Entry },
	personalScore: number,
	isPhone: boolean,
})
	local isOnPlot = useIsOnPlot(props.record, props.isPhone)
	local children = {}
	for rank, entry in props.entries do
		children[`Row{rank}`] = e(LeaderboardRow, {
			entry = entry,
			rank = rank,
			kind = props.record.kind,
			isPhone = props.isPhone,
		})
	end

	if #props.entries == 0 then
		children.Empty = outlinedText({
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Enum.Font.FredokaOne,
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromScale(0.8, 0.1),
			Text = "NO DATA YET",
			TextColor3 = Color3.new(1, 1, 1),
			TextScaled = true,
			TextStrokeTransparency = 1,
		}, 5, props.isPhone)
	end

	local localRank: number? = nil
	for rank, entry in props.entries do
		if entry.userId == Players.LocalPlayer.UserId then
			localRank = rank
			break
		end
	end
	children.Footer = outlinedText({
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		Position = UDim2.fromScale(0.035, 0.905),
		Size = UDim2.fromScale(0.93, 0.07),
		Text = if localRank
			then `You are #{localRank}! {formatScore(props.record.kind, props.personalScore)}`
			else `Not in Top 10  •  {formatScore(props.record.kind, props.personalScore)}`,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, 4, props.isPhone)

	return e(React.Fragment, nil, {
		Title = e("SurfaceGui", {
			Adornee = props.record.title,
			AlwaysOnTop = false,
			CanvasSize = if props.isPhone then Vector2.new(650, 169) else Vector2.new(1000, 260),
			Enabled = isOnPlot,
			Face = Enum.NormalId.Right,
			LightInfluence = 0,
		}, {
			Text = outlinedText({
				BackgroundTransparency = 1,
				Font = Enum.Font.FredokaOne,
				Size = UDim2.fromScale(1, 1),
				Text = LeaderboardConfig.Titles[props.record.kind],
				TextColor3 = Color3.fromRGB(71, 202, 255),
				TextScaled = true,
				TextStrokeTransparency = 1,
			}, 7, props.isPhone),
		}),
		Board = e("SurfaceGui", {
			Adornee = props.record.board,
			AlwaysOnTop = false,
			CanvasSize = if props.isPhone then Vector2.new(585, 637) else Vector2.new(900, 980),
			Enabled = isOnPlot,
			Face = Enum.NormalId.Right,
			LightInfluence = 0,
		}, children),
	})
end

local function findBoardRecord(model: Model): BoardRecord?
	local kind = LeaderboardConfig.BoardNames[model.Name]
	if not kind then
		return nil
	end
	local board = model:FindFirstChild("Board")
	local title = model:FindFirstChild("Title")
	if not board or not board:IsA("BasePart") or not title or not title:IsA("BasePart") then
		return nil
	end
	return {
		model = model,
		board = board,
		title = title,
		kind = kind,
	}
end

local function LeaderboardRoot()
	local isPhone = useIsPhoneViewport()
	local snapshot = ReactCharm.useAtom(LeaderboardSlice.state.snapshot)
	local personalScores = usePersonalScores()
	local records, setRecords = React.useState({} :: { [Model]: BoardRecord })

	React.useEffect(function()
		local function register(model: Model)
			local record = findBoardRecord(model)
			if not record then
				return
			end
			setRecords(function(previous)
				local nextRecords = table.clone(previous)
				nextRecords[model] = record
				return nextRecords
			end)
		end

		local function unregister(model: Model)
			setRecords(function(previous)
				if previous[model] == nil then
					return previous
				end
				local nextRecords = table.clone(previous)
				nextRecords[model] = nil
				return nextRecords
			end)
		end

		for _, descendant in Workspace:GetDescendants() do
			if descendant:IsA("Model") then
				register(descendant)
			end
		end
		local addedConnection = Workspace.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("Model") then
				task.defer(register, descendant)
			elseif descendant.Name == "Board" or descendant.Name == "Title" then
				local model = descendant.Parent
				if model and model:IsA("Model") then
					task.defer(register, model)
				end
			end
		end)
		local removingConnection = Workspace.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("Model") and LeaderboardConfig.BoardNames[descendant.Name] then
				unregister(descendant)
			end
		end)

		return function()
			addedConnection:Disconnect()
			removingConnection:Disconnect()
		end
	end, {})

	local elements = {}
	for model, record in records do
		if model.Parent then
			local position = record.board.Position
			local elementKey = string.format("%s_%.3f_%.3f_%.3f", model.Name, position.X, position.Y, position.Z)
			elements[elementKey] = e(BoardSurface, {
				record = record,
				entries = snapshot[record.kind],
				personalScore = personalScores[record.kind],
				isPhone = isPhone,
			})
		end
	end
	return e(React.Fragment, nil, elements)
end

return LeaderboardRoot
