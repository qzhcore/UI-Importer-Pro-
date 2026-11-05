-- Design-space geometry is absolute; Roblox geometry is parent-relative.
local ResponsiveLayout = {}

local ANCHORS = { MIN = 0, LEFT = 0, TOP = 0, MAX = 1, RIGHT = 1, BOTTOM = 1, CENTER = 0.5 }

function ResponsiveLayout.axis(rule, near, size, parentSize)
	assert(parentSize > 0, "Cannot scale against a zero-sized parent")
	local anchor = ANCHORS[rule]
	if anchor == nil then
		local center = (near + size / 2) / parentSize
		anchor = if center < 0.34 then 0 elseif center > 0.66 then 1 else 0.5
	end
	return anchor, (near + size * anchor) / parentSize, size / parentSize
end

function ResponsiveLayout.apply(instance, layer, bounds, parentBounds, inFlow)
	local rules = layer.constraints or layer.alignment or {}
	local ax, px, sx =
		ResponsiveLayout.axis(rules.horizontal, bounds.left - parentBounds.left, bounds.width, parentBounds.width)
	local ay, py, sy =
		ResponsiveLayout.axis(rules.vertical, bounds.top - parentBounds.top, bounds.height, parentBounds.height)
	instance.AnchorPoint = Vector2.new(ax, ay)
	instance.Size = UDim2.fromScale(sx, sy)
	instance.Position = if inFlow then UDim2.fromScale(0, 0) else UDim2.fromScale(px, py)
	local shape = layer.shape or layer.figmaType
	local squareIcon = bounds.width == bounds.height and string.find(string.lower(layer.name), "icon", 1, true)
	if
		bounds.height > 0
		and bounds.width > 0
		and (layer.preserveAspectRatio or shape == "ELLIPSE" or shape == "AVATAR" or squareIcon)
	then
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Name = "ImportedAspectRatio"
		aspect.AspectRatio = bounds.width / bounds.height
		aspect.AspectType = Enum.AspectType.FitWithinMaxSize
		aspect.Parent = instance
	end
end

return ResponsiveLayout
