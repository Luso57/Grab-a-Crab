--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local ShopPurchaseEffect = {}

local function centerOf(guiObject: GuiObject): Vector2
	return guiObject.AbsolutePosition + guiObject.AbsoluteSize / 2
end

local function destination(playerGui: PlayerGui, slotIndex: number?): Vector2
	if slotIndex and slotIndex > 0 then
		local hotbar = playerGui:FindFirstChild("InventoryHotbar")
		local slots = if hotbar then hotbar:FindFirstChild("Slots") else nil
		local row = if slots then slots:FindFirstChild("SlotRow") else nil
		if row then
			for _, child in row:GetChildren() do
				if child:IsA("GuiButton") and child:GetAttribute("SlotIndex") == slotIndex then
					return centerOf(child)
				end
			end
		end
	end
	local inventory = playerGui:FindFirstChild("InventoryPanel")
	local toggle = if inventory then inventory:FindFirstChild("InventoryToggle") else nil
	if toggle and toggle:IsA("GuiObject") then
		return centerOf(toggle)
	end
	local camera = workspace.CurrentCamera
	local size = if camera then camera.ViewportSize else Vector2.new(800, 600)
	return Vector2.new(size.X / 2, size.Y - 75)
end

function ShopPurchaseEffect.mount(playerGui: PlayerGui, layerName: string?, feedbackSoundId: number?, displayOrder: number?): ((number, Vector2, number?) -> (), (Vector2) -> ())
	local layer: ScreenGui = nil :: any
	local purchaseSound: Sound = nil :: any
	Vide.mount(function()
		purchaseSound = create "Sound" {
			Name = "BuyClickSound",
			SoundId = "rbxassetid://" .. (feedbackSoundId or 4612383453),
			Volume = 1,
		}
		layer = create "ScreenGui" {
			Name = layerName or "ShopPurchaseEffect",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = displayOrder or 30,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}
		purchaseSound.Parent = layer
		return layer
	end, playerGui)

	local function playItem(imageId: number, startPosition: Vector2, slotIndex: number?)
		local icon = create "ImageLabel" {
			Name = "PurchasedItem",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(startPosition.X, startPosition.Y),
			Size = UDim2.fromOffset(72, 72),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. imageId,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}
		icon.Parent = layer

		local rise = TweenService:Create(icon, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(startPosition.X, startPosition.Y - 55),
			Size = UDim2.fromOffset(90, 90),
			Rotation = -12,
		})
		rise.Completed:Once(function(state)
			if state ~= Enum.PlaybackState.Completed or not icon.Parent then
				icon:Destroy()
				return
			end
			local target = destination(playerGui, slotIndex)
			local fall = TweenService:Create(icon, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
				Size = UDim2.fromOffset(35, 35),
				Rotation = 0,
			})
			fall.Completed:Once(function()
				icon:Destroy()
			end)
			fall:Play()
		end)
		rise:Play()
	end

	local random = Random.new()
	local confettiColors = {
		Color3.fromRGB(255, 222, 66),
		Color3.fromRGB(255, 100, 168),
		Color3.fromRGB(80, 211, 255),
		Color3.fromRGB(123, 235, 97),
		Color3.fromRGB(174, 115, 255),
	}

	local function playFeedback(startPosition: Vector2)
		purchaseSound.TimePosition = 0
		purchaseSound:Play()
		for index = 1, 12 do
			local angle = (index - 1) * math.pi / 6 + random:NextNumber(-0.18, 0.18)
			local distance = random:NextNumber(100, 240)
			local piece = create "Frame" {
				Name = "BuyConfetti",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(startPosition.X, startPosition.Y),
				Size = UDim2.fromOffset(random:NextInteger(5, 7), random:NextInteger(7, 10)),
				Rotation = random:NextInteger(-35, 35),
				BackgroundColor3 = confettiColors[(index - 1) % #confettiColors + 1],
				BorderSizePixel = 0,
				ZIndex = 10,
			}
			piece.Parent = layer
			local tween = TweenService:Create(piece, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(startPosition.X + math.cos(angle) * distance, startPosition.Y + math.sin(angle) * distance),
				Size = UDim2.fromOffset(3, 5),
				Rotation = piece.Rotation + random:NextInteger(-120, 120),
				BackgroundTransparency = 1,
			})
			tween.Completed:Once(function()
				piece:Destroy()
			end)
			tween:Play()
		end
	end

	return playItem, playFeedback
end

return ShopPurchaseEffect
