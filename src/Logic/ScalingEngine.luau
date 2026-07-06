local ScalingEngine = {}

local Constants = require(script.Parent.Parent.Shared.Constants)

local CENTER_ANCHOR = Vector2.new(0.5, 0.5)
local FALLBACK_VIEWPORT = Constants.CANVAS_SIZE

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

	instance.AnchorPoint = CENTER_ANCHOR
	instance.Size = UDim2.fromScale(absoluteSize.X / parentSize.X, absoluteSize.Y / parentSize.Y)
	instance.Position = UDim2.fromScale(centeredPosition.X / parentSize.X, centeredPosition.Y / parentSize.Y)

	ensureAspectRatio(instance, absoluteSize)
	return true
end

function ScalingEngine.ProcessRecursive(root)
	local processed = ScalingEngine.ToScale(root) and 1 or 0

	for _, child in ipairs(root:GetChildren()) do
		processed += ScalingEngine.ProcessRecursive(child)
	end

	return processed
end

return ScalingEngine
