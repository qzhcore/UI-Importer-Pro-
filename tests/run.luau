local FigmaLayout = require("../src/Logic/FigmaLayout")

local passed = 0

local function fail(message)
	error(message, 2)
end

local function expectEqual(actual, expected, message)
	if actual ~= expected then
		fail(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
	end
end

local function expectNear(actual, expected, message)
	if math.abs(actual - expected) > 1e-6 then
		fail(string.format("%s: expected %.6f, got %.6f", message, expected, actual))
	end
end

local function test(name, callback)
	local ok, message = pcall(callback)
	if not ok then
		error(string.format("FAIL %s\n%s", name, tostring(message)), 0)
	end
	passed = passed + 1
	print("PASS " .. name)
end

local function resolveAxis(axis, parentSize)
	local size = axis.sizeScale * parentSize + axis.sizeOffset
	local anchorPosition = axis.positionScale * parentSize + axis.positionOffset
	return anchorPosition - axis.anchor * size, size
end

test("maps native Kiwi auto-layout fields", function()
	local mapped = FigmaLayout.fromWireNode({
		stackMode = "HORIZONTAL",
		stackSpacing = 12,
		stackHorizontalPadding = 10,
		stackPaddingRight = 14,
		stackVerticalPadding = 16,
		stackPaddingBottom = 18,
		stackPrimaryAlignItems = "SPACE_BETWEEN",
		stackCounterAlignItems = "CENTER",
		stackPrimarySizing = "FIXED",
		stackCounterSizing = "RESIZE_TO_FIT_WITH_IMPLICIT_SIZE",
		stackWrap = "WRAP",
		stackCounterAxisSpacing = 20,
		stackChildAlignSelf = "STRETCH",
		stackChildPrimaryGrow = 1,
		stackPositioning = "ABSOLUTE",
	})
	expectEqual(mapped.layoutMode, "HORIZONTAL", "layout mode")
	expectEqual(mapped.layoutGap, 12, "gap")
	expectEqual(mapped.paddingLeft, 10, "left padding")
	expectEqual(mapped.paddingRight, 14, "right padding")
	expectEqual(mapped.paddingTop, 16, "top padding")
	expectEqual(mapped.paddingBottom, 18, "bottom padding")
	expectEqual(mapped.primaryAxisAlignItems, "SPACE_BETWEEN", "primary alignment")
	expectEqual(mapped.counterAxisAlignItems, "CENTER", "counter alignment")
	expectEqual(mapped.primaryAxisSizingMode, "FIXED", "primary sizing")
	expectEqual(mapped.counterAxisSizingMode, "RESIZE_TO_FIT_WITH_IMPLICIT_SIZE", "counter sizing")
	expectEqual(mapped.layoutWrap, "WRAP", "wrap")
	expectEqual(mapped.counterAxisSpacing, 20, "wrapped-line gap")
	expectEqual(mapped.layoutAlign, "STRETCH", "child alignment")
	expectEqual(mapped.layoutGrow, 1, "child grow")
	expectEqual(mapped.layoutPositioning, "ABSOLUTE", "absolute positioning")
end)

test("maps native Kiwi constraints", function()
	local mapped = FigmaLayout.fromWireNode({
		horizontalConstraint = "MAX",
		verticalConstraint = "CENTER",
	})
	expectEqual(mapped.constraints.horizontal, "MAX", "horizontal constraint")
	expectEqual(mapped.constraints.vertical, "CENTER", "vertical constraint")
end)

test("keeps compatibility aliases", function()
	local mapped = FigmaLayout.fromWireNode({
		stackPaddingLeft = 3,
		stackPaddingTop = 4,
		primaryAxisAlignItems = "MIN",
		layoutGrow = 1,
		constraints = { horizontal = "SCALE", vertical = "STRETCH" },
	})
	expectEqual(mapped.paddingLeft, 3, "legacy left padding")
	expectEqual(mapped.paddingTop, 4, "legacy top padding")
	expectEqual(mapped.primaryAxisAlignItems, "MIN", "legacy alignment")
	expectEqual(mapped.layoutGrow, 1, "legacy grow")
	expectEqual(mapped.constraints.vertical, "STRETCH", "legacy constraints")
end)

test("MIN remains pinned to the near edge", function()
	local axis = FigmaLayout.axisFromConstraint("MIN", 10, 20, 100)
	local near, size = resolveAxis(axis, 200)
	expectNear(near, 10, "near edge")
	expectNear(size, 20, "size")
end)

test("MAX remains pinned to the far edge", function()
	local axis = FigmaLayout.axisFromConstraint("MAX", 60, 20, 100)
	local near, size = resolveAxis(axis, 200)
	expectNear(near, 160, "near edge")
	expectNear(200 - near - size, 20, "far margin")
end)

test("CENTER retains its center offset", function()
	local axis = FigmaLayout.axisFromConstraint("CENTER", 35, 20, 100)
	local near, size = resolveAxis(axis, 200)
	expectNear(near, 85, "near edge")
	expectNear(near + size / 2 - 100, -5, "center offset")
end)

test("STRETCH retains both edge margins", function()
	local axis = FigmaLayout.axisFromConstraint("STRETCH", 10, 70, 100)
	local near, size = resolveAxis(axis, 200)
	expectNear(near, 10, "near margin")
	expectNear(size, 170, "stretched size")
	expectNear(200 - near - size, 20, "far margin")
end)

test("STRETCH preserves negative overflow margins", function()
	local axis = FigmaLayout.axisFromConstraint("STRETCH", -5, 120, 100)
	local near, size = resolveAxis(axis, 200)
	expectNear(near, -5, "overflowing near margin")
	expectNear(200 - near - size, -15, "overflowing far margin")
end)

test("SCALE remains proportional", function()
	local axis = FigmaLayout.axisFromConstraint("SCALE", 10, 20, 100)
	local near, size = resolveAxis(axis, 200)
	expectNear(near, 20, "scaled near edge")
	expectNear(size, 40, "scaled size")
end)

test("unknown constraints safely use Figma MIN default", function()
	local axis = FigmaLayout.axisFromConstraint("FUTURE_VALUE", 10, 20, 100)
	local near, size = resolveAxis(axis, 200)
	expectNear(near, 10, "near edge")
	expectNear(size, 20, "size")
end)

test("sizeless groups derive bounds from descendants", function()
	local bounds = FigmaLayout.getEffectiveBounds({
		left = 1,
		top = 2,
		width = 0,
		height = 0,
		children = {
			{ left = 20, top = 30, width = 40, height = 50 },
			{ left = 70, top = 10, width = 10, height = 20 },
		},
	})
	expectEqual(bounds.left, 20, "left")
	expectEqual(bounds.top, 10, "top")
	expectEqual(bounds.width, 60, "width")
	expectEqual(bounds.height, 70, "height")
end)

test("auto-layout flow takes precedence over constraints", function()
	expectEqual(FigmaLayout.geometryMode({ mode = "HORIZONTAL" }, "AUTO", {}), "AUTO_LAYOUT", "mode")
	expectEqual(FigmaLayout.geometryMode({ mode = "HORIZONTAL" }, nil, {}), "AUTO_LAYOUT", "missing AUTO")
end)

test("absolute auto-layout children use constraints", function()
	expectEqual(
		FigmaLayout.geometryMode({ mode = "VERTICAL" }, "ABSOLUTE", { horizontal = "MAX" }),
		"CONSTRAINTS",
		"mode"
	)
end)

test("PSD-style layers stay on legacy geometry", function()
	expectEqual(FigmaLayout.geometryMode(nil, nil, nil), "LEGACY", "mode")
end)

test("auto-layout children keep baked size and request flex behavior", function()
	local size = FigmaLayout.autoLayoutChildSize(
		{ layoutGrow = 1, layoutAlign = "STRETCH" },
		{ width = 120, height = 40 },
		{ mode = "HORIZONTAL" }
	)
	expectEqual(size.x.offset, 120, "primary width")
	expectEqual(size.y.offset, 40, "cross height basis")
	expectEqual(size.y.scale, 0, "stretch avoids parent-size overflow")
	expectEqual(size.grow, true, "grow")
	expectEqual(size.stretch, true, "stretch")
end)

test("recognizes wire and Plugin API hug modes", function()
	expectEqual(FigmaLayout.isHugSizing("RESIZE_TO_FIT"), true, "legacy wire hug")
	expectEqual(FigmaLayout.isHugSizing("RESIZE_TO_FIT_WITH_IMPLICIT_SIZE"), true, "current wire hug")
	expectEqual(FigmaLayout.isHugSizing("AUTO"), true, "Plugin API hug")
	expectEqual(FigmaLayout.isHugSizing("FIXED"), false, "fixed sizing")
end)

print(string.format("All %d Figma layout regression tests passed.", passed))
