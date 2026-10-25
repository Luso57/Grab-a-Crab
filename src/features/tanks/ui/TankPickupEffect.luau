--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Vide = require(ReplicatedStorage.Packages.Vide)
local create = Vide.create

local TankPickupEffect = {}

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
		if slots and slots:IsA("GuiObject") then
			return centerOf(slots)
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

function TankPickupEffect.mount(playerGui: PlayerGui): (number, Vector2, number?) -> ()
	local layer: ScreenGui = nil :: any
	Vide.mount(function()
		layer = create "ScreenGui" {
			Name = "TankPickupEffect",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 30,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}
		return layer
	end, playerGui)

	return function(imageId: number, startPosition: Vector2, slotIndex: number?)
		local crab = create "ImageLabel" {
			Name = "PickedUpCrab",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(startPosition.X, startPosition.Y),
			Size = UDim2.fromOffset(72, 72),
			BackgroundTransparency = 1,
			Image = "rbxassetid://" .. imageId,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		}
		crab.Parent = layer

		local rise = TweenService:Create(crab, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(startPosition.X, startPosition.Y - 55),
			Size = UDim2.fromOffset(90, 90),
			Rotation = -12,
		})
		rise.Completed:Once(function(state)
			if state ~= Enum.PlaybackState.Completed or not crab.Parent then
				crab:Destroy()
				return
			end
			local target = destination(playerGui, slotIndex)
			local fall = TweenService:Create(crab, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromOffset(target.X, target.Y),
				Size = UDim2.fromOffset(35, 35),
				Rotation = 0,
			})
			fall.Completed:Once(function()
				crab:Destroy()
			end)
			fall:Play()
		end)
		rise:Play()
	end
end

return TankPickupEffect
