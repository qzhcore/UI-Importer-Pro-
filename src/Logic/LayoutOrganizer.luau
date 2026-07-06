local LayoutOrganizer = {}

local Constants = require(script.Parent.Parent.Shared.Constants)

local CONFIG = Constants.ORGANIZER

local layoutClasses = {}
for _, className in ipairs(Constants.LAYOUT_CLASSES) do
	layoutClasses[className] = true
end

local function hasLayout(instance)
	for _, child in ipairs(instance:GetChildren()) do
		if layoutClasses[child.ClassName] then
			return true
		end
	end

	return false
end

local function getGuiChildren(instance)
	local children = {}
	for _, child in ipairs(instance:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			table.insert(children, child)
		end
	end

	return children
end

local function nearlyEqual(a, b, tolerance)
	return math.abs(a - b) <= tolerance
end

local function getAverageGap(sortedChildren, axis)
	local totalGap = 0
	local gapCount = 0

	for index = 2, #sortedChildren do
		local previous = sortedChildren[index - 1]
		local current = sortedChildren[index]
		local previousEnd
		local currentStart

		if axis == "X" then
			previousEnd = previous.AbsolutePosition.X + previous.AbsoluteSize.X
			currentStart = current.AbsolutePosition.X
		else
			previousEnd = previous.AbsolutePosition.Y + previous.AbsoluteSize.Y
			currentStart = current.AbsolutePosition.Y
		end

		totalGap += math.max(0, currentStart - previousEnd)
		gapCount += 1
	end

	if gapCount == 0 then
		return 0
	end

	return totalGap / gapCount
end

local function allAligned(children, axis)
	local first = children[1]
	if not first then
		return false
	end

	local referencePosition = if axis == "X" then first.AbsolutePosition.X else first.AbsolutePosition.Y
	local referenceSize = if axis == "X" then first.AbsoluteSize.X else first.AbsoluteSize.Y

	for _, child in ipairs(children) do
		local position = if axis == "X" then child.AbsolutePosition.X else child.AbsolutePosition.Y
		local size = if axis == "X" then child.AbsoluteSize.X else child.AbsoluteSize.Y

		if not nearlyEqual(position, referencePosition, CONFIG.ALIGNMENT_TOLERANCE) then
			return false
		end

		if not nearlyEqual(size, referenceSize, CONFIG.SIZE_TOLERANCE) then
			return false
		end
	end

	return true
end

local function allSimilarSize(children)
	local first = children[1]
	if not first then
		return false
	end

	for _, child in ipairs(children) do
		if not nearlyEqual(child.AbsoluteSize.X, first.AbsoluteSize.X, CONFIG.SIZE_TOLERANCE) then
			return false
		end

		if not nearlyEqual(child.AbsoluteSize.Y, first.AbsoluteSize.Y, CONFIG.SIZE_TOLERANCE) then
			return false
		end
	end

	return true
end

local function getRows(children)
	local rows = {}

	for _, child in ipairs(children) do
		local inserted = false
		for _, row in ipairs(rows) do
			if nearlyEqual(row.y, child.AbsolutePosition.Y, CONFIG.GRID_TOLERANCE) then
				table.insert(row.children, child)
				inserted = true
				break
			end
		end

		if not inserted then
			table.insert(rows, {
				y = child.AbsolutePosition.Y,
				children = { child },
			})
		end
	end

	table.sort(rows, function(a, b)
		return a.y < b.y
	end)

	for _, row in ipairs(rows) do
		table.sort(row.children, function(a, b)
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end)
	end

	return rows
end

local function looksLikeGrid(children)
	if #children < 4 or not allSimilarSize(children) then
		return false
	end

	local rows = getRows(children)
	if #rows < 2 then
		return false
	end

	local columns = #rows[1].children
	if columns < 2 then
		return false
	end

	for _, row in ipairs(rows) do
		if #row.children ~= columns then
			return false
		end
	end

	return true, rows
end

local function looksLikeTable(children)
	if #children < 4 then
		return false
	end

	local rows = getRows(children)
	if #rows < 2 then
		return false
	end

	local columns = #rows[1].children
	if columns < 2 then
		return false
	end

	for _, row in ipairs(rows) do
		if #row.children ~= columns then
			return false
		end
	end

	return true, rows
end

local function looksLikePages(parent, children)
	if #children < 2 then
		return false
	end

	local parentSize = parent.AbsoluteSize
	if parentSize.X <= 0 or parentSize.Y <= 0 then
		return false
	end

	for _, child in ipairs(children) do
		local coversWidth = child.AbsoluteSize.X >= parentSize.X * CONFIG.PAGE_COVERAGE
		local coversHeight = child.AbsoluteSize.Y >= parentSize.Y * CONFIG.PAGE_COVERAGE
		if not (coversWidth and coversHeight) then
			return false
		end
	end

	return true
end

local function getRowAnchors(rows)
	local anchors = {}
	for _, row in ipairs(rows) do
		local firstChild = row.children[1]
		table.insert(anchors, {
			AbsolutePosition = Vector2.new(firstChild.AbsolutePosition.X, row.y),
			AbsoluteSize = firstChild.AbsoluteSize,
		})
	end

	return anchors
end

local function sortByAxis(children, axis)
	table.sort(children, function(a, b)
		if axis == "X" then
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end

		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)
end

local function resetChildOrder(children)
	for index, child in ipairs(children) do
		child.LayoutOrder = index
	end
end

local function createListLayout(parent, children, fillDirection)
	sortByAxis(children, if fillDirection == Enum.FillDirection.Horizontal then "X" else "Y")
	resetChildOrder(children)

	local layout = Instance.new("UIListLayout")
	layout.Name = "UIImporterListLayout"
	layout.FillDirection = fillDirection
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	if fillDirection == Enum.FillDirection.Horizontal then
		layout.Padding = UDim.new(0, getAverageGap(children, "X"))
	else
		layout.Padding = UDim.new(0, getAverageGap(children, "Y"))
	end

	layout.Parent = parent
	return true
end

local function applyLayoutOrderFromRows(rows)
	local order = 1
	for _, row in ipairs(rows) do
		for _, child in ipairs(row.children) do
			child.LayoutOrder = order
			order += 1
		end
	end
end

local function createGridLayout(parent, children, rows)
	applyLayoutOrderFromRows(rows)

	local first = children[1]
	local layout = Instance.new("UIGridLayout")
	layout.Name = "UIImporterGridLayout"
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellSize = UDim2.fromOffset(first.AbsoluteSize.X, first.AbsoluteSize.Y)
	layout.CellPadding = UDim2.fromOffset(getAverageGap(rows[1].children, "X"), getAverageGap(getRowAnchors(rows), "Y"))
	layout.Parent = parent
	return true
end

local function createTableLayout(parent, rows)
	applyLayoutOrderFromRows(rows)

	local layout = Instance.new("UITableLayout")
	layout.Name = "UIImporterTableLayout"
	layout.FillEmptySpaceColumns = true
	layout.FillEmptySpaceRows = false
	layout.MajorAxis = Enum.TableMajorAxis.RowMajor
	layout.Padding = UDim2.fromOffset(getAverageGap(rows[1].children, "X"), getAverageGap(getRowAnchors(rows), "Y"))
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return true
end

local function createPageLayout(parent, children)
	sortByAxis(children, "X")
	resetChildOrder(children)

	local layout = Instance.new("UIPageLayout")
	layout.Name = "UIImporterPageLayout"
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, getAverageGap(children, "X"))
	layout.Parent = parent
	return true
end

function LayoutOrganizer.Process(instance)
	if not instance:IsA("GuiObject") or hasLayout(instance) then
		return false
	end

	local children = getGuiChildren(instance)
	if #children < CONFIG.MIN_CHILDREN then
		return false
	end

	if looksLikePages(instance, children) then
		return createPageLayout(instance, children)
	end

	local isGrid, rows = looksLikeGrid(children)
	if isGrid then
		return createGridLayout(instance, children, rows)
	end

	local isTable, tableRows = looksLikeTable(children)
	if isTable then
		return createTableLayout(instance, tableRows)
	end

	if allAligned(children, "Y") then
		return createListLayout(instance, children, Enum.FillDirection.Horizontal)
	end

	if allAligned(children, "X") then
		return createListLayout(instance, children, Enum.FillDirection.Vertical)
	end

	return false
end

function LayoutOrganizer.ProcessRecursive(root)
	local organized = LayoutOrganizer.Process(root) and 1 or 0

	for _, child in ipairs(root:GetChildren()) do
		organized += LayoutOrganizer.ProcessRecursive(child)
	end

	return organized
end

return LayoutOrganizer
