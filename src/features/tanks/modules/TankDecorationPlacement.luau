--!strict

local TankDecorationPlacement = {}

TankDecorationPlacement.slotCount = 4

local EDGE_PADDING = 0.14
local DECOR_GAP = 0.1
local PREVIEW_EDGE_INSET = 0.04

function TankDecorationPlacement.isRotation(value: any): boolean
	return typeof(value) == "number" and value % 1 == 0 and value >= 0 and value <= 3
end

function TankDecorationPlacement.isFinite(value: any): boolean
	return typeof(value) == "number" and value == value and math.abs(value) < 10000
end

function TankDecorationPlacement.prepare(model: Model, floor: BasePart): Vector3?
	local _, size = model:GetBoundingBox()
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		return nil
	end
	local maxWidth = math.min(1.6, math.min(floor.Size.X, floor.Size.Z) * 0.34)
	local factor = math.min(maxWidth / math.max(size.X, size.Z), 2 / size.Y)
	model:ScaleTo(model:GetScale() * factor)
	local _, scaledSize = model:GetBoundingBox()
	return scaledSize
end

function TankDecorationPlacement.footprint(size: Vector3, rotation: number): (number, number)
	if rotation % 2 == 0 then
		return size.X, size.Z
	end
	return size.Z, size.X
end

function TankDecorationPlacement.fits(floor: BasePart, size: Vector3, x: number, z: number, rotation: number): boolean
	if not TankDecorationPlacement.isFinite(x) or not TankDecorationPlacement.isFinite(z)
		or not TankDecorationPlacement.isRotation(rotation) then
		return false
	end
	local width, depth = TankDecorationPlacement.footprint(size, rotation)
	return math.abs(x) + width / 2 <= floor.Size.X / 2 - EDGE_PADDING
		and math.abs(z) + depth / 2 <= floor.Size.Z / 2 - EDGE_PADDING
end

function TankDecorationPlacement.clampToFloor(floor: BasePart, size: Vector3, x: number, z: number, rotation: number): (number, number)
	local width, depth = TankDecorationPlacement.footprint(size, rotation)
	local maxX = math.max(0, floor.Size.X / 2 - EDGE_PADDING - PREVIEW_EDGE_INSET - width / 2)
	local maxZ = math.max(0, floor.Size.Z / 2 - EDGE_PADDING - PREVIEW_EDGE_INSET - depth / 2)
	return math.clamp(x, -maxX, maxX), math.clamp(z, -maxZ, maxZ)
end

function TankDecorationPlacement.overlaps(
	x: number, z: number, width: number, depth: number,
	otherX: number, otherZ: number, otherWidth: number, otherDepth: number
): boolean
	return math.abs(x - otherX) < (width + otherWidth) / 2 + DECOR_GAP
		and math.abs(z - otherZ) < (depth + otherDepth) / 2 + DECOR_GAP
end

function TankDecorationPlacement.pivotOnFloor(model: Model, floor: BasePart, x: number, z: number, rotation: number): CFrame
	local box, size = model:GetBoundingBox()
	local pivotToBottom = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	return floor.CFrame * CFrame.new(x, floor.Size.Y / 2 + pivotToBottom, z)
		* CFrame.Angles(0, rotation * math.pi / 2, 0)
end

return TankDecorationPlacement
