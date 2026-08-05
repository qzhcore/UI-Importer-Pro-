local FigmaLayout = require("../src/Logic/FigmaLayout")
local FigmaVisual = require("../src/Logic/FigmaVisual")
local Deflate = require("../src/Logic/Deflate")
local ImageResampler = require("../src/Logic/ImageResampler")
local fs = require("@lune/fs")

local function loadPngDecoder()
	local deflateToken = {}
	local source = fs.readFile("src/Logic/PngDecoder.luau")
	local chunk, compileError = loadstring(source, "@src/Logic/PngDecoder.luau")
	assert(chunk, compileError)
	setfenv(
		chunk,
		setmetatable({
			script = { Parent = { Deflate = deflateToken } },
			require = function(token)
				assert(token == deflateToken, "Unexpected PngDecoder dependency")
				return Deflate
			end,
		}, { __index = getfenv(0) })
	)
	return chunk()
end

local PngDecoder = loadPngDecoder()

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

test("normalizes native Kiwi gradient paints", function()
	local paint = FigmaVisual.normalizePaint({
		type = "GRADIENT_LINEAR",
		opacity = 0.5,
		stops = {
			{ position = 1, color = { r = 0, g = 0, b = 1, a = 1 } },
			{ position = 0, color = { r = 1, g = 0, b = 0, a = 0.8 } },
		},
		transform = { m00 = 1, m01 = 0, m02 = 0, m10 = 1, m11 = 1, m12 = 0 },
	})
	expectEqual(paint.gradientStops[1].position, 0, "sorted first stop")
	expectNear(paint.gradientStops[1].color.a, 0.4, "paint opacity")
	expectEqual(paint.gradientStops[2].position, 1, "sorted last stop")
	local geometry = FigmaVisual.gradientGeometry(paint)
	expectNear(geometry.rotation, 45, "gradient rotation")
end)

test("converts Kiwi binary image hashes to archive names", function()
	expectEqual(FigmaVisual.imageHashToHex(string.char(0, 15, 255)), "000fff", "binary hash")
	expectEqual(
		FigmaVisual.imageHashToHex("AABBCCDDEEFF00112233445566778899AABBCCDD"),
		"aabbccddeeff00112233445566778899aabbccdd",
		"hex hash"
	)
end)

test("captures independent corner radii", function()
	local corners = FigmaVisual.cornerRadii({
		cornerRadius = 2,
		rectangleTopLeftCornerRadius = 4,
		rectangleTopRightCornerRadius = 6,
		rectangleBottomRightCornerRadius = 8,
		rectangleBottomLeftCornerRadius = 10,
		rectangleCornerRadiiIndependent = true,
	})
	expectEqual(corners.topLeft, 4, "top-left")
	expectEqual(corners.topRight, 6, "top-right")
	expectEqual(corners.bottomRight, 8, "bottom-right")
	expectEqual(corners.bottomLeft, 10, "bottom-left")
	expectEqual(corners.independent, true, "independent flag")
end)

test("captures Figma effects and font metadata", function()
	local effects = FigmaVisual.normalizeEffects({
		{
			type = "DROP_SHADOW",
			color = { r = 1, g = 0, b = 0, a = 0.5 },
			offset = { x = 3, y = 4 },
			radius = 8,
			spread = 2,
		},
	})
	expectEqual(effects[1].type, "DROP_SHADOW", "effect type")
	expectEqual(effects[1].offsetX, 3, "shadow x")
	expectEqual(effects[1].radius, 8, "shadow radius")
	local font = FigmaVisual.fontInfo({ fontName = { family = "Inter", style = "Extra Bold Italic" } })
	expectEqual(font.family, "Inter", "font family")
	expectEqual(font.weight, 800, "font weight")
	expectEqual(font.italic, true, "font italic")
end)

test("keeps supported hybrid leaves native and propagates fallback to parents", function()
	local supportedLeaf = { requiresRenderedFallback = false, children = {} }
	local unsupportedLeaf = { requiresRenderedFallback = true, children = {} }
	local supportedSibling = { requiresRenderedFallback = false, children = {} }
	local root = {
		requiresRenderedFallback = false,
		children = { supportedLeaf, unsupportedLeaf },
	}
	FigmaVisual.updateSubtreeFallback(root)
	FigmaVisual.updateSubtreeFallback(supportedSibling)
	expectEqual(supportedLeaf.subtreeRequiresRenderedFallback, false, "supported leaf")
	expectEqual(unsupportedLeaf.subtreeRequiresRenderedFallback, true, "unsupported leaf")
	expectEqual(root.subtreeRequiresRenderedFallback, true, "fallback parent")
	expectEqual(supportedSibling.subtreeRequiresRenderedFallback, false, "native sibling")

	local forcedChild = { requiresRenderedFallback = false, children = {} }
	local forcedGroup = {
		requiresRenderedFallback = true,
		forcesDescendantFallback = true,
		children = { forcedChild },
	}
	FigmaVisual.updateSubtreeFallback(forcedGroup)
	expectEqual(forcedChild.subtreeRequiresRenderedFallback, true, "group-composited child")

	local mask = { requiresRenderedFallback = true, isMask = true, children = {} }
	local maskedSibling = { requiresRenderedFallback = false, children = {} }
	local maskGroup = { requiresRenderedFallback = false, children = { mask, maskedSibling } }
	FigmaVisual.updateSubtreeFallback(maskGroup)
	expectEqual(maskedSibling.subtreeRequiresRenderedFallback, true, "masked sibling")
end)

test("upscales and sharpens Figma previews without changing flat colors", function()
	local pixels = buffer.create(2 * 2 * 4)
	for pixel = 0, 3 do
		local offset = pixel * 4
		buffer.writeu8(pixels, offset, 40)
		buffer.writeu8(pixels, offset + 1, 80)
		buffer.writeu8(pixels, offset + 2, 120)
		buffer.writeu8(pixels, offset + 3, 200)
	end
	local resized = ImageResampler.upscaleSharpened({ width = 2, height = 2, pixels = pixels }, 8, 8)
	expectEqual(resized.width, 8, "upscaled width")
	expectEqual(resized.height, 8, "upscaled height")
	expectEqual(buffer.readu8(resized.pixels, 0), 40, "flat red")
	expectEqual(buffer.readu8(resized.pixels, 1), 80, "flat green")
	expectEqual(buffer.readu8(resized.pixels, 2), 120, "flat blue")
	expectEqual(buffer.readu8(resized.pixels, 3), 200, "flat alpha")
end)

local function u32be(value)
	return string.char(
		math.floor(value / 16777216) % 256,
		math.floor(value / 65536) % 256,
		math.floor(value / 256) % 256,
		value % 256
	)
end

local function pngChunk(chunkType, contents)
	-- The decoder deliberately does not validate CRCs, so a zero checksum keeps
	-- these focused fixtures small and independent from another CRC module.
	return u32be(#contents) .. chunkType .. contents .. "\0\0\0\0"
end

local function storedPng(width, height, bitDepth, colorType, raw, palette, transparency)
	local inverseLength = bit32.bxor(#raw, 0xFFFF)
	local deflate = string.char(
		1,
		#raw % 256,
		math.floor(#raw / 256),
		inverseLength % 256,
		math.floor(inverseLength / 256)
	) .. raw
	local zlib = "\120\1" .. deflate .. "\0\0\0\0"
	local header = u32be(width) .. u32be(height) .. string.char(bitDepth, colorType, 0, 0, 0)
	return "\137PNG\r\n\26\n"
		.. pngChunk("IHDR", header)
		.. (if palette then pngChunk("PLTE", palette) else "")
		.. (if transparency then pngChunk("tRNS", transparency) else "")
		.. pngChunk("IDAT", zlib)
		.. pngChunk("IEND", "")
end

test("decodes embedded RGBA PNG pixels", function()
	local png = string.char(
		137,
		80,
		78,
		71,
		13,
		10,
		26,
		10,
		0,
		0,
		0,
		13,
		73,
		72,
		68,
		82,
		0,
		0,
		0,
		2,
		0,
		0,
		0,
		2,
		8,
		6,
		0,
		0,
		0,
		114,
		182,
		13,
		36,
		0,
		0,
		0,
		21,
		73,
		68,
		65,
		84,
		120,
		156,
		99,
		248,
		207,
		192,
		240,
		31,
		8,
		27,
		24,
		128,
		52,
		8,
		48,
		0,
		0,
		67,
		211,
		8,
		121,
		201,
		21,
		28,
		15,
		0,
		0,
		0,
		0,
		73,
		69,
		78,
		68,
		174,
		66,
		96,
		130
	)
	local decoded = PngDecoder.decode(png)
	expectEqual(decoded.width, 2, "PNG width")
	expectEqual(decoded.height, 2, "PNG height")
	expectEqual(buffer.readu8(decoded.pixels, 0), 255, "red pixel red")
	expectEqual(buffer.readu8(decoded.pixels, 7), 128, "green pixel alpha")
	expectEqual(buffer.readu8(decoded.pixels, 10), 255, "blue pixel blue")
	expectEqual(buffer.readu8(decoded.pixels, 15), 0, "transparent white alpha")
end)

test("decodes packed indexed PNG pixels and palette transparency", function()
	local png = storedPng(
		4,
		1,
		2,
		3,
		string.char(0, 0x1B),
		string.char(0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255),
		string.char(0, 85, 170, 255)
	)
	local decoded = PngDecoder.decode(png)
	expectEqual(buffer.readu8(decoded.pixels, 3), 0, "palette alpha 0")
	expectEqual(buffer.readu8(decoded.pixels, 4), 255, "palette red")
	expectEqual(buffer.readu8(decoded.pixels, 7), 85, "palette alpha 1")
	expectEqual(buffer.readu8(decoded.pixels, 9), 255, "palette green")
	expectEqual(buffer.readu8(decoded.pixels, 11), 170, "palette alpha 2")
	expectEqual(buffer.readu8(decoded.pixels, 14), 255, "palette blue")
end)

test("decodes packed grayscale PNG pixels", function()
	local decoded = PngDecoder.decode(storedPng(2, 1, 4, 0, string.char(0, 0x0F)))
	expectEqual(buffer.readu8(decoded.pixels, 0), 0, "black grayscale sample")
	expectEqual(buffer.readu8(decoded.pixels, 4), 255, "white grayscale sample")
end)

test("reconstructs all five PNG row filters", function()
	local raw = string.char(0, 10, 20, 30, 40, 1, 11, 21, 31, 41, 2, 9, 9, 9, 9, 3, 20, 25, 30, 35, 4, 10, 10, 10, 10)
	local decoded = PngDecoder.decode(storedPng(1, 5, 8, 6, raw))
	expectEqual(buffer.readu8(decoded.pixels, 0), 10, "filter none")
	expectEqual(buffer.readu8(decoded.pixels, 4), 11, "filter sub")
	expectEqual(buffer.readu8(decoded.pixels, 8), 20, "filter up")
	expectEqual(buffer.readu8(decoded.pixels, 12), 30, "filter average")
	expectEqual(buffer.readu8(decoded.pixels, 16), 40, "filter Paeth")
end)

print(string.format("All %d Figma importer regression tests passed.", passed))
