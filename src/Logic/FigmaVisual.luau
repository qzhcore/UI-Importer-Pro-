local FigmaVisual = {}

local GRADIENT_TYPES = {
	GRADIENT_LINEAR = true,
	GRADIENT_RADIAL = true,
	GRADIENT_ANGULAR = true,
	GRADIENT_DIAMOND = true,
}

local COMPLEX_VECTOR_TYPES = {
	BOOLEAN_OPERATION = true,
	CODE_BLOCK = true,
	CONNECTOR = true,
	HIGHLIGHT = true,
	LINE = true,
	MEDIA = true,
	REGULAR_POLYGON = true,
	SECTION_OVERLAY = true,
	SHAPE_WITH_TEXT = true,
	STAMP = true,
	STAR = true,
	VECTOR = true,
	WASHI_TAPE = true,
	WIDGET = true,
}

local function copyColor(color, opacity)
	if not color then
		return nil
	end
	return {
		r = math.clamp(color.r or 0, 0, 1),
		g = math.clamp(color.g or 0, 0, 1),
		b = math.clamp(color.b or 0, 0, 1),
		a = math.clamp((color.a or 1) * (opacity or 1), 0, 1),
	}
end

local function copyMatrix(matrix)
	if not matrix then
		return nil
	end
	return {
		m00 = matrix.m00 or 1,
		m01 = matrix.m01 or 0,
		m02 = matrix.m02 or 0,
		m10 = matrix.m10 or 0,
		m11 = matrix.m11 or 1,
		m12 = matrix.m12 or 0,
	}
end

function FigmaVisual.imageHashToHex(hash)
	if type(hash) == "string" then
		if #hash % 2 == 0 and #hash >= 32 and string.match(hash, "^[%da-fA-F]+$") then
			return string.lower(hash)
		end
		local parts = table.create(#hash)
		for index = 1, #hash do
			parts[index] = string.format("%02x", string.byte(hash, index))
		end
		return table.concat(parts)
	elseif type(hash) == "table" then
		local keys = {}
		for key, value in pairs(hash) do
			if type(key) == "number" and type(value) == "number" then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		local parts = table.create(#keys)
		for index, key in ipairs(keys) do
			parts[index] = string.format("%02x", math.clamp(math.floor(hash[key]), 0, 255))
		end
		return table.concat(parts)
	end
	return nil
end

function FigmaVisual.normalizePaint(paint)
	if not paint or paint.visible == false then
		return nil
	end
	local paintType = paint.type or "UNKNOWN"
	local opacity = math.clamp(paint.opacity or 1, 0, 1)
	local normalized = {
		type = paintType,
		color = copyColor(paint.color, opacity),
		opacity = opacity,
		blendMode = paint.blendMode or "NORMAL",
	}

	if GRADIENT_TYPES[paintType] then
		local stops = {}
		for _, stop in ipairs(paint.stops or paint.gradientStops or {}) do
			local color = copyColor(stop.color, opacity)
			if color then
				table.insert(stops, {
					position = math.clamp(stop.position or 0, 0, 1),
					color = color,
				})
			end
		end
		table.sort(stops, function(left, right)
			return left.position < right.position
		end)
		normalized.gradientStops = stops
		normalized.gradientTransform = copyMatrix(paint.transform or paint.gradientTransform)
	elseif paintType == "IMAGE" then
		normalized.imageHash = FigmaVisual.imageHashToHex(paint.image and paint.image.hash or paint.imageHash)
		normalized.imageScaleMode = paint.imageScaleMode or "FILL"
		normalized.imageTransform = copyMatrix(paint.transform or paint.imageTransform)
	end

	return normalized
end

function FigmaVisual.normalizeEffects(effects)
	local normalized = {}
	for _, effect in ipairs(effects or {}) do
		if effect.visible ~= false then
			table.insert(normalized, {
				type = effect.type or "UNKNOWN",
				color = copyColor(effect.color),
				offsetX = effect.offset and effect.offset.x or 0,
				offsetY = effect.offset and effect.offset.y or 0,
				radius = math.max(0, effect.radius or 0),
				spread = effect.spread or 0,
				blendMode = effect.blendMode or "NORMAL",
			})
		end
	end
	return normalized
end

function FigmaVisual.cornerRadii(node)
	local uniform = math.max(0, node.cornerRadius or 0)
	return {
		topLeft = math.max(0, node.rectangleTopLeftCornerRadius or uniform),
		topRight = math.max(0, node.rectangleTopRightCornerRadius or uniform),
		bottomRight = math.max(0, node.rectangleBottomRightCornerRadius or uniform),
		bottomLeft = math.max(0, node.rectangleBottomLeftCornerRadius or uniform),
		independent = node.rectangleCornerRadiiIndependent == true,
	}
end

local function inferFontWeight(node, style)
	if type(node.fontWeight) == "number" then
		return math.clamp(math.floor(node.fontWeight + 0.5), 100, 900)
	end
	for _, metadata in ipairs(node.derivedTextData and node.derivedTextData.fontMetaData or {}) do
		if type(metadata.fontWeight) == "number" then
			return math.clamp(math.floor(metadata.fontWeight + 0.5), 100, 900)
		end
	end
	local lower = string.lower(style or "")
	if string.find(lower, "thin", 1, true) then
		return 100
	elseif string.find(lower, "extra light", 1, true) or string.find(lower, "extralight", 1, true) then
		return 200
	elseif string.find(lower, "light", 1, true) then
		return 300
	elseif string.find(lower, "medium", 1, true) then
		return 500
	elseif string.find(lower, "semi bold", 1, true) or string.find(lower, "semibold", 1, true) then
		return 600
	elseif string.find(lower, "extra bold", 1, true) or string.find(lower, "extrabold", 1, true) then
		return 800
	elseif string.find(lower, "black", 1, true) or string.find(lower, "heavy", 1, true) then
		return 900
	elseif string.find(lower, "bold", 1, true) then
		return 700
	end
	return 400
end

function FigmaVisual.fontInfo(node)
	local fontName = node.fontName or {}
	local style = fontName.style or "Regular"
	return {
		family = fontName.family,
		style = style,
		weight = inferFontWeight(node, style),
		italic = string.find(string.lower(style), "italic", 1, true) ~= nil,
	}
end

function FigmaVisual.gradientGeometry(gradient)
	local transform = gradient and gradient.gradientTransform
	if not transform then
		return {
			rotation = 0,
			offsetX = 0,
			offsetY = 0,
		}
	end
	local startX, startY = transform.m02, transform.m12
	local endX, endY = transform.m00 + startX, transform.m10 + startY
	return {
		rotation = math.deg(math.atan2(endY - startY, endX - startX)),
		offsetX = math.clamp((startX + endX) / 2 - 0.5, -1, 1),
		offsetY = math.clamp((startY + endY) / 2 - 0.5, -1, 1),
	}
end

function FigmaVisual.isGradientType(paintType)
	return GRADIENT_TYPES[paintType] == true
end

function FigmaVisual.isComplexVectorType(nodeType)
	return COMPLEX_VECTOR_TYPES[nodeType] == true
end

return FigmaVisual
