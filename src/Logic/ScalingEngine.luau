local ScalingEngine = {}

local Constants = require(script.Parent.Parent.Shared.Constants)

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local FALLBACK_VIEWPORT = Constants.CANVAS_SIZE

local layoutClasses = {}
for _, className in ipairs(Constants.LAYOUT_CLASSES) do
	layoutClasses[className] = true
end

local function getParentGeometry(instance)
	local parent = instance.Parent
	if parent and parent:IsA("GuiObject") then
		return parent.AbsolutePosition, parent.AbsoluteSize
	end

	if parent and parent:IsA("LayerCollector") then
		return Vector2.zero, parent.AbsoluteSize
	end

	return Vector2.zero, FALLBACK_VIEWPORT
end

local function getAxisSize(parentSize, axis)
	if axis == "Y" then
		return parentSize.Y
	end

	return parentSize.X
end

local function offsetToScale(offset, parentSize, axis)
	local axisSize = getAxisSize(parentSize, axis)
	if axisSize <= 0 then
		return 0
	end

	return offset / axisSize
end

local function convertUDim(value, parentSize, axis)
	if value.Offset == 0 then
		return value
	end

	return UDim.new(value.Scale + offsetToScale(value.Offset, parentSize, axis), 0)
end

local function convertUDim2(value, parentSize)
	return UDim2.new(
		value.X.Scale + offsetToScale(value.X.Offset, parentSize, "X"),
		0,
		value.Y.Scale + offsetToScale(value.Y.Offset, parentSize, "Y"),
		0
	)
end

local function hasLayout(parent)
	if not parent then
		return false
	end

	for _, child in ipairs(parent:GetChildren()) do
		if layoutClasses[child.ClassName] then
			return true
		end
	end

	return false
end

local function getOwnScale(instance)
	local scale = 1
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("UIScale") then
			scale *= child.Scale
		end
	end

	return scale
end

local function ensureAspectRatio(instance, absoluteSize)
	if absoluteSize.X <= 0 or absoluteSize.Y <= 0 then
		return
	end

	if instance:FindFirstChildOfClass("UIAspectRatioConstraint") then
		return
	end

	local constraint = Instance.new("UIAspectRatioConstraint")
	constraint.Name = "UIImporterAspectRatio"
	constraint.AspectRatio = absoluteSize.X / absoluteSize.Y
	constraint.AspectType = Constants.ASPECT_RATIO_SETTINGS.AspectType
	constraint.DominantAxis = Constants.ASPECT_RATIO_SETTINGS.DominantAxis
	constraint.Parent = instance
end

local function scaleLayout(instance, parentSize)
	if instance:IsA("UIListLayout") then
		local axis = if instance.FillDirection == Enum.FillDirection.Horizontal then "X" else "Y"
		instance.Padding = convertUDim(instance.Padding, parentSize, axis)
		return true
	end

	if instance:IsA("UIGridLayout") then
		instance.CellPadding = convertUDim2(instance.CellPadding, parentSize)
		instance.CellSize = convertUDim2(instance.CellSize, parentSize)
		return true
	end

	if instance:IsA("UIPageLayout") then
		instance.Padding = convertUDim(instance.Padding, parentSize, "X")
		return true
	end

	if instance:IsA("UIPadding") then
		instance.PaddingBottom = convertUDim(instance.PaddingBottom, parentSize, "Y")
		instance.PaddingLeft = convertUDim(instance.PaddingLeft, parentSize, "X")
		instance.PaddingRight = convertUDim(instance.PaddingRight, parentSize, "X")
		instance.PaddingTop = convertUDim(instance.PaddingTop, parentSize, "Y")
		return true
	end

	return false
end

local function scaleScrollingFrame(instance, absoluteSize)
	if not instance:IsA("ScrollingFrame") then
		return
	end

	instance.CanvasSize = convertUDim2(instance.CanvasSize, absoluteSize)
end

function ScalingEngine.ToScale(instance)
	if not instance:IsA("GuiObject") then
		return false
	end

	local parentPosition, parentSize = getParentGeometry(instance)
	if parentSize.X <= 0 or parentSize.Y <= 0 then
		return false
	end

	local absoluteSize = instance.AbsoluteSize
	local absolutePosition = instance.AbsolutePosition
	local centeredPosition = absolutePosition - parentPosition + (absoluteSize * CENTER_ANCHOR)
	local ownScale = getOwnScale(instance)
	local scaledSize = if ownScale > 0 then absoluteSize / ownScale else absoluteSize
	local parentControlsPosition = hasLayout(instance.Parent)

	instance.Size = UDim2.fromScale(scaledSize.X / parentSize.X, scaledSize.Y / parentSize.Y)

	if not parentControlsPosition then
		instance.AnchorPoint = CENTER_ANCHOR
		instance.Position = UDim2.fromScale(centeredPosition.X / parentSize.X, centeredPosition.Y / parentSize.Y)
	end

	ensureAspectRatio(instance, absoluteSize)
	scaleScrollingFrame(instance, absoluteSize)
	return true
end

function ScalingEngine.ProcessRecursive(root)
	local processed = ScalingEngine.ToScale(root) and 1 or 0
	local parentSize = if root:IsA("GuiObject") then root.AbsoluteSize else FALLBACK_VIEWPORT

	for _, child in ipairs(root:GetChildren()) do
		if scaleLayout(child, parentSize) then
			processed += 1
		end

		processed += ScalingEngine.ProcessRecursive(child)
	end

	return processed
end

return ScalingEngine
