local FigmaLayout = {}

local HUG_SIZING_MODES = {
	AUTO = true,
	HUG = true,
	RESIZE_TO_FIT = true,
	RESIZE_TO_FIT_WITH_IMPLICIT_SIZE = true,
}

local function firstValue(...)
	for index = 1, select("#", ...) do
		local value = select(index, ...)
		if value ~= nil then
			return value
		end
	end
	return nil
end

-- Native .fig files use Figma's internal Kiwi field names. Keep all wire-to-
-- importer translation in one place so UIBuilder only consumes normalized
-- layer properties. Plugin API names are accepted as fallbacks for fixtures
-- and for older/exporter-specific archives.
function FigmaLayout.fromWireNode(node)
	local nestedConstraints = node.constraints
	local horizontalConstraint =
		firstValue(node.horizontalConstraint, nestedConstraints and nestedConstraints.horizontal)
	local verticalConstraint = firstValue(node.verticalConstraint, nestedConstraints and nestedConstraints.vertical)
	local constraints
	if horizontalConstraint ~= nil or verticalConstraint ~= nil then
		constraints = {
			horizontal = horizontalConstraint or "MIN",
			vertical = verticalConstraint or "MIN",
		}
	end

	return {
		layoutMode = node.stackMode,
		layoutGap = node.stackSpacing,
		paddingLeft = firstValue(node.stackHorizontalPadding, node.stackPaddingLeft),
		paddingRight = node.stackPaddingRight,
		paddingTop = firstValue(node.stackVerticalPadding, node.stackPaddingTop),
		paddingBottom = node.stackPaddingBottom,
		primaryAxisAlignItems = firstValue(node.stackPrimaryAlignItems, node.primaryAxisAlignItems),
		counterAxisAlignItems = firstValue(node.stackCounterAlignItems, node.counterAxisAlignItems),
		primaryAxisSizingMode = firstValue(node.stackPrimarySizing, node.primaryAxisSizingMode),
		counterAxisSizingMode = firstValue(node.stackCounterSizing, node.counterAxisSizingMode),
		layoutWrap = firstValue(node.stackWrap, node.layoutWrap),
		counterAxisSpacing = firstValue(node.stackCounterAxisSpacing, node.counterAxisSpacing),
		layoutAlign = firstValue(node.stackChildAlignSelf, node.layoutAlign),
		layoutGrow = firstValue(node.stackChildPrimaryGrow, node.layoutGrow),
		layoutPositioning = firstValue(node.stackPositioning, node.layoutPositioning),
		constraints = constraints,
	}
end

function FigmaLayout.isHugSizing(value)
	return HUG_SIZING_MODES[value] == true
end

function FigmaLayout.getEffectiveBounds(layer)
	if layer.width and layer.height and layer.width > 0 and layer.height > 0 then
		return {
			left = layer.left,
			top = layer.top,
			width = layer.width,
			height = layer.height,
		}
	end

	local minimumX = math.huge
	local minimumY = math.huge
	local maximumX = -math.huge
	local maximumY = -math.huge
	for _, child in ipairs(layer.children or {}) do
		local childBounds = FigmaLayout.getEffectiveBounds(child)
		if childBounds then
			minimumX = math.min(minimumX, childBounds.left)
			minimumY = math.min(minimumY, childBounds.top)
			maximumX = math.max(maximumX, childBounds.left + childBounds.width)
			maximumY = math.max(maximumY, childBounds.top + childBounds.height)
		end
	end

	if minimumX < math.huge and maximumX > minimumX and maximumY > minimumY then
		return {
			left = minimumX,
			top = minimumY,
			width = maximumX - minimumX,
			height = maximumY - minimumY,
		}
	end

	return nil
end

function FigmaLayout.axisFromConstraint(constraintValue, near, size, parentSize)
	parentSize = math.max(1, parentSize)
	constraintValue = constraintValue or "MIN"

	if constraintValue == "MAX" then
		local farMargin = parentSize - (near + size)
		return {
			anchor = 0,
			positionScale = 1,
			positionOffset = -(farMargin + size),
			sizeScale = 0,
			sizeOffset = size,
		}
	elseif constraintValue == "CENTER" then
		local centerOffset = (near + size / 2) - (parentSize / 2)
		return {
			anchor = 0.5,
			positionScale = 0.5,
			positionOffset = centerOffset,
			sizeScale = 0,
			sizeOffset = size,
		}
	elseif constraintValue == "STRETCH" then
		local farMargin = parentSize - (near + size)
		return {
			anchor = 0,
			positionScale = 0,
			positionOffset = near,
			sizeScale = 1,
			sizeOffset = -(near + farMargin),
		}
	elseif constraintValue == "SCALE" then
		return {
			anchor = 0,
			positionScale = near / parentSize,
			positionOffset = 0,
			sizeScale = size / parentSize,
			sizeOffset = 0,
		}
	end

	-- MIN is Figma's default. Unknown future enum values degrade to the stable
	-- near-edge behavior rather than unexpectedly scaling the layer.
	return {
		anchor = 0,
		positionScale = 0,
		positionOffset = near,
		sizeScale = 0,
		sizeOffset = size,
	}
end

function FigmaLayout.constraintGeometry(bounds, parentBounds, constraints)
	return {
		x = FigmaLayout.axisFromConstraint(
			constraints and constraints.horizontal,
			bounds.left - parentBounds.left,
			bounds.width,
			parentBounds.width
		),
		y = FigmaLayout.axisFromConstraint(
			constraints and constraints.vertical,
			bounds.top - parentBounds.top,
			bounds.height,
			parentBounds.height
		),
	}
end

function FigmaLayout.autoLayoutChildSize(layer, bounds, parentLayout)
	local isPrimaryHorizontal = parentLayout.mode == "HORIZONTAL"
	local primarySize = if isPrimaryHorizontal then bounds.width else bounds.height
	local crossSize = if isPrimaryHorizontal then bounds.height else bounds.width
	local primary = { scale = 0, offset = math.max(1, primarySize) }
	local cross = { scale = 0, offset = math.max(1, crossSize) }

	return {
		x = if isPrimaryHorizontal then primary else cross,
		y = if isPrimaryHorizontal then cross else primary,
		grow = layer.layoutGrow ~= nil and layer.layoutGrow > 0,
		stretch = layer.layoutAlign == "STRETCH",
	}
end

function FigmaLayout.geometryMode(parentLayout, layoutPositioning, constraints)
	if parentLayout ~= nil and layoutPositioning ~= "ABSOLUTE" then
		return "AUTO_LAYOUT"
	elseif constraints ~= nil then
		return "CONSTRAINTS"
	end
	return "LEGACY"
end

return FigmaLayout
