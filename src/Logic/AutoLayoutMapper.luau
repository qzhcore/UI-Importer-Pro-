local AutoLayoutMapper = {}
local HORIZONTAL = {
	MIN = Enum.HorizontalAlignment.Left,
	CENTER = Enum.HorizontalAlignment.Center,
	MAX = Enum.HorizontalAlignment.Right,
}
local VERTICAL =
	{ MIN = Enum.VerticalAlignment.Top, CENTER = Enum.VerticalAlignment.Center, MAX = Enum.VerticalAlignment.Bottom }

function AutoLayoutMapper.isFlow(layer)
	return layer.layoutMode == "HORIZONTAL" or layer.layoutMode == "VERTICAL" or layer.layoutMode == "GRID"
end

function AutoLayoutMapper.hasPadding(layer)
	return layer.paddingLeft ~= nil
		or layer.paddingRight ~= nil
		or layer.paddingTop ~= nil
		or layer.paddingBottom ~= nil
end

function AutoLayoutMapper.contentBounds(bounds, layer)
	local left, top = layer.paddingLeft or 0, layer.paddingTop or 0
	local width = bounds.width - left - (layer.paddingRight or 0)
	local height = bounds.height - top - (layer.paddingBottom or 0)
	assert(width > 0 and height > 0, "Content padding consumes the entire container: " .. layer.name)
	return { left = bounds.left + left, top = bounds.top + top, width = width, height = height }
end

function AutoLayoutMapper.apply(parent, layer, bounds)
	local horizontal = layer.layoutMode ~= "VERTICAL"
	local content = AutoLayoutMapper.contentBounds(bounds, layer)
	if AutoLayoutMapper.isFlow(layer) then
		local grid = layer.layoutMode == "GRID"
		local layout = Instance.new(if grid then "UIGridLayout" else "UIListLayout")
		layout.Name = "ImportedAutoLayout"
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
		layout.HorizontalAlignment = HORIZONTAL[if horizontal
			then layer.primaryAxisAlignItems
			else layer.counterAxisAlignItems] or Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = VERTICAL[if horizontal
			then layer.counterAxisAlignItems
			else layer.primaryAxisAlignItems] or Enum.VerticalAlignment.Top
		if grid then
			local cell = layer.gridCellSize or { width = 100, height = 100 }
			layout.CellSize = UDim2.fromScale(cell.width / content.width, cell.height / content.height)
			layout.CellPadding = UDim2.fromScale(
				(layer.layoutGap or 0) / content.width,
				(layer.counterAxisSpacing or layer.layoutGap or 0) / content.height
			)
			layout.FillDirectionMaxCells = layer.gridColumns or 0
		else
			local gap = if layer.primaryAxisAlignItems == "SPACE_BETWEEN" then 0 else layer.layoutGap or 0
			layout.Padding = UDim.new(gap / (if horizontal then content.width else content.height), 0)
			layout.Wraps = layer.layoutWrap == "WRAP"
			if layer.primaryAxisAlignItems == "SPACE_BETWEEN" then
				if horizontal then
					layout.HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
				else
					layout.VerticalFlex = Enum.UIFlexAlignment.SpaceBetween
				end
			end
		end
		layout.Parent = parent
	end
	if layer.paddingLeft or layer.paddingRight or layer.paddingTop or layer.paddingBottom then
		local padding = Instance.new("UIPadding")
		padding.Name = "ImportedPadding"
		padding.PaddingLeft = UDim.new((layer.paddingLeft or 0) / bounds.width, 0)
		padding.PaddingRight = UDim.new((layer.paddingRight or 0) / bounds.width, 0)
		padding.PaddingTop = UDim.new((layer.paddingTop or 0) / bounds.height, 0)
		padding.PaddingBottom = UDim.new((layer.paddingBottom or 0) / bounds.height, 0)
		padding.Parent = parent
	end
end

function AutoLayoutMapper.child(instance, layer)
	if (layer.layoutGrow or 0) > 0 or layer.layoutAlign == "STRETCH" then
		local item = Instance.new("UIFlexItem")
		item.Name = "ImportedAutoLayoutItem"
		if (layer.layoutGrow or 0) > 0 then
			item.FlexMode = Enum.UIFlexMode.Custom
			item.GrowRatio = layer.layoutGrow
		end
		if layer.layoutAlign == "STRETCH" then
			item.ItemLineAlignment = Enum.ItemLineAlignment.Stretch
		end
		item.Parent = instance
	end
end

return AutoLayoutMapper
