local Deflate = require(script.Parent.Deflate)
local FigmaLayout = require(script.Parent.FigmaLayout)
local FigmaVisual = require(script.Parent.FigmaVisual)
local PngDecoder = require(script.Parent.PngDecoder)

local FigParser = {}

local ZSTD_MAGIC = "\x28\xb5\x2f\xfd"
local FIG_MAGIC = "fig-kiwi"
local MAX_SEGMENT_BYTES = 128 * 1024 * 1024
local MAX_ARCHIVE_ENTRY_BYTES = 128 * 1024 * 1024

local CONTAINER_TYPES = {
	FRAME = true,
	GROUP = true,
	INSTANCE = true,
	SECTION = true,
	STATE_GROUP = true,
	SYMBOL = true,
}

local function readU16LE(data, position)
	local first, second = string.byte(data, position, position + 1)
	if not second then
		error("Unexpected end of .fig archive.")
	end
	return first + second * 256
end

local function readU32LE(data, position)
	local first, second, third, fourth = string.byte(data, position, position + 3)
	if not fourth then
		error("Unexpected end of .fig data.")
	end
	return first + second * 256 + third * 65536 + fourth * 16777216
end

local function extractZipEntries(archive)
	local searchStart = math.max(1, #archive - 65557)
	local eocdPosition
	local cursor = searchStart

	while true do
		local found = string.find(archive, "PK\005\006", cursor, true)
		if not found then
			break
		end
		eocdPosition = found
		cursor = found + 1
	end

	if not eocdPosition then
		error("This .fig ZIP archive is missing its central directory.")
	end

	local entryCount = readU16LE(archive, eocdPosition + 10)
	local centralPosition = readU32LE(archive, eocdPosition + 16) + 1

	local entries = {}
	for _ = 1, entryCount do
		if string.sub(archive, centralPosition, centralPosition + 3) ~= "PK\001\002" then
			error("This .fig ZIP archive has a damaged central directory.")
		end

		local compressionMethod = readU16LE(archive, centralPosition + 10)
		local compressedSize = readU32LE(archive, centralPosition + 20)
		local uncompressedSize = readU32LE(archive, centralPosition + 24)
		local filenameLength = readU16LE(archive, centralPosition + 28)
		local extraLength = readU16LE(archive, centralPosition + 30)
		local commentLength = readU16LE(archive, centralPosition + 32)
		local localHeaderOffset = readU32LE(archive, centralPosition + 42)
		local filename = string.sub(archive, centralPosition + 46, centralPosition + 45 + filenameLength)

		local wanted = filename == "canvas.fig"
			or filename == "canvas"
			or filename == "thumbnail.png"
			or (string.sub(filename, 1, 7) == "images/" and #filename > 7)
		if wanted then
			if compressedSize > MAX_ARCHIVE_ENTRY_BYTES or uncompressedSize > MAX_ARCHIVE_ENTRY_BYTES then
				error(string.format("The .fig archive entry %s exceeds the 128 MB safety limit.", filename))
			end
			local localPosition = localHeaderOffset + 1
			if string.sub(archive, localPosition, localPosition + 3) ~= "PK\003\004" then
				error("This .fig ZIP archive has a damaged local entry.")
			end

			local localFilenameLength = readU16LE(archive, localPosition + 26)
			local localExtraLength = readU16LE(archive, localPosition + 28)
			local dataStart = localPosition + 30 + localFilenameLength + localExtraLength
			local compressed = string.sub(archive, dataStart, dataStart + compressedSize - 1)

			if compressionMethod == 0 then
				entries[filename] = compressed
			elseif compressionMethod == 8 then
				entries[filename] = Deflate.decompress(compressed)
			else
				error(string.format("Unsupported ZIP compression method %d in %s.", compressionMethod, filename))
			end
			if #entries[filename] > MAX_ARCHIVE_ENTRY_BYTES then
				error(string.format("The decompressed .fig archive entry %s exceeds 128 MB.", filename))
			end
			if uncompressedSize > 0 and #entries[filename] ~= uncompressedSize then
				error(string.format("The .fig archive entry %s has an invalid decompressed size.", filename))
			end
		end

		centralPosition += 46 + filenameLength + extraLength + commentLength
	end

	return entries
end

local function getFigSource(data)
	if string.sub(data, 1, 2) == "PK" then
		local entries = extractZipEntries(data)
		local canvasData = entries["canvas.fig"] or entries.canvas
		if not canvasData then
			error("This .fig archive does not contain canvas.fig.")
		end
		local images = {}
		for name, contents in pairs(entries) do
			if string.sub(name, 1, 7) == "images/" then
				images[string.lower(string.sub(name, 8))] = contents
			end
		end
		return {
			canvasData = canvasData,
			images = images,
			thumbnail = entries["thumbnail.png"],
		}
	end
	return {
		canvasData = data,
		images = {},
	}
end

local Reader = {}
Reader.__index = Reader

function Reader.new(data)
	return setmetatable({
		data = data,
		position = 1,
	}, Reader)
end

function Reader:byte()
	local value = string.byte(self.data, self.position)
	if not value then
		error("Unexpected end of Kiwi data.")
	end
	self.position += 1
	return value
end

function Reader:bool()
	return self:byte() > 0
end

function Reader:uint()
	local value = 0
	for shift = 0, 28, 7 do
		local nextByte = self:byte()
		value += bit32.lshift(bit32.band(nextByte, 127), shift)
		if nextByte < 128 then
			return value
		end
	end
	error("Invalid Kiwi unsigned integer.")
end

function Reader:uint64()
	local value = 0
	local multiplier = 1
	-- Kiwi uses seven payload bits for the first eight bytes. The ninth
	-- and final byte stores all eight of its bits, so bit 7 is data there
	-- instead of another continuation flag.
	for _ = 1, 8 do
		local nextByte = self:byte()
		value += bit32.band(nextByte, 127) * multiplier
		if nextByte < 128 then
			return value
		end
		multiplier *= 128
	end
	return value + self:byte() * multiplier
end

function Reader:int()
	local value = self:uint()
	return if bit32.band(value, 1) ~= 0 then -math.floor(value / 2) - 1 else math.floor(value / 2)
end

function Reader:int64()
	local value = self:uint64()
	return if value % 2 == 1 then -math.floor(value / 2) - 1 else math.floor(value / 2)
end

function Reader:float()
	local firstByte = self:byte()
	if firstByte == 0 then
		return 0
	end

	local bits = firstByte + self:byte() * 256 + self:byte() * 65536 + self:byte() * 16777216
	bits = bit32.lrotate(bits, 23)
	local storage = buffer.create(4)
	buffer.writeu32(storage, 0, bits)
	return buffer.readf32(storage, 0)
end

function Reader:string()
	local ending = string.find(self.data, "\0", self.position, true)
	if not ending then
		error("Unterminated Kiwi string.")
	end
	local value = string.sub(self.data, self.position, ending - 1)
	self.position = ending + 1
	return value
end

function Reader:bytes(count)
	local ending = self.position + count - 1
	if ending > #self.data then
		error("Unexpected end of Kiwi byte array.")
	end
	local value = string.sub(self.data, self.position, ending)
	self.position = ending + 1
	return value
end

local function decompressSegment(segment)
	if #segment > MAX_SEGMENT_BYTES then
		error("Compressed .fig segment exceeds the 128 MB safety limit.")
	end

	if string.sub(segment, 1, 4) == ZSTD_MAGIC then
		local EncodingService = game:GetService("EncodingService")
		local decompressed =
			EncodingService:DecompressBuffer(buffer.fromstring(segment), Enum.CompressionAlgorithm.Zstd)
		return buffer.tostring(decompressed)
	end

	return Deflate.decompress(segment)
end

local function readSchema(data)
	local reader = Reader.new(data)
	local typeCount = reader:uint()
	local types = table.create(typeCount)

	for typeIndex = 1, typeCount do
		local fieldCount
		local typeInfo = {
			name = reader:string(),
			kind = reader:byte(),
			fields = {},
			fieldList = {},
		}

		fieldCount = reader:uint()
		for _ = 1, fieldCount do
			local field = {
				name = reader:string(),
				datatype = reader:int(),
				array = reader:bool(),
			}
			local fieldId = reader:uint()
			typeInfo.fields[fieldId] = field
			table.insert(typeInfo.fieldList, field)
		end

		types[typeIndex] = typeInfo
	end

	return types
end

local function decodeMessage(data, types)
	local reader = Reader.new(data)

	local function decodeType(datatype, isArray)
		if isArray then
			local count = reader:uint()
			if datatype == -2 then
				return reader:bytes(count)
			end

			local values = table.create(count)
			for index = 1, count do
				values[index] = decodeType(datatype, false)
			end
			return values
		end

		if datatype == -1 then
			return reader:bool()
		elseif datatype == -2 then
			return reader:byte()
		elseif datatype == -3 then
			return reader:int()
		elseif datatype == -4 then
			return reader:uint()
		elseif datatype == -5 then
			return reader:float()
		elseif datatype == -6 then
			return reader:string()
		elseif datatype == -7 then
			return reader:int64()
		elseif datatype == -8 then
			return reader:uint64()
		end

		local typeInfo = types[datatype + 1]
		if not typeInfo then
			error(string.format("Unknown Kiwi type %d.", datatype))
		end

		if typeInfo.kind == 0 then
			local enumField = typeInfo.fields[reader:uint()]
			return if enumField then enumField.name else "UNKNOWN"
		elseif typeInfo.kind == 1 then
			local value = {}
			for _, field in ipairs(typeInfo.fieldList) do
				value[field.name] = decodeType(field.datatype, field.array)
			end
			return value
		elseif typeInfo.kind == 2 then
			local value = {}
			while true do
				local fieldId = reader:uint()
				if fieldId == 0 then
					break
				end
				local field = typeInfo.fields[fieldId]
				if not field then
					error(string.format("Unknown field %d on Kiwi type %s.", fieldId, typeInfo.name))
				end
				value[field.name] = decodeType(field.datatype, field.array)
			end
			return value
		end

		error(string.format("Unsupported Kiwi type kind %d.", typeInfo.kind))
	end

	local rootTypeIndex
	for index, typeInfo in ipairs(types) do
		if typeInfo.name == "Message" then
			rootTypeIndex = index - 1
			break
		end
	end
	if rootTypeIndex == nil then
		error("The .fig Kiwi schema does not contain a Message root.")
	end

	return decodeType(rootTypeIndex, false)
end

local function decodeCanvas(data)
	if string.sub(data, 1, 8) ~= FIG_MAGIC then
		error("This is not a Figma Design .fig file (missing fig-kiwi header).")
	end

	local position = 9
	local version = readU32LE(data, position)
	position += 4

	local schemaLength = readU32LE(data, position)
	position += 4
	local schemaSegment = string.sub(data, position, position + schemaLength - 1)
	position += schemaLength

	local messageLength = readU32LE(data, position)
	position += 4
	local messageSegment = string.sub(data, position, position + messageLength - 1)

	local schema = readSchema(decompressSegment(schemaSegment))
	return decodeMessage(decompressSegment(messageSegment), schema), version
end

local function guidKey(guid)
	return string.format("%s:%s", tostring(guid.sessionID), tostring(guid.localID))
end

local function multiplyMatrix(parent, child)
	return {
		m00 = parent.m00 * child.m00 + parent.m01 * child.m10,
		m01 = parent.m00 * child.m01 + parent.m01 * child.m11,
		m02 = parent.m00 * child.m02 + parent.m01 * child.m12 + parent.m02,
		m10 = parent.m10 * child.m00 + parent.m11 * child.m10,
		m11 = parent.m10 * child.m01 + parent.m11 * child.m11,
		m12 = parent.m10 * child.m02 + parent.m11 * child.m12 + parent.m12,
	}
end

local IDENTITY_MATRIX = {
	m00 = 1,
	m01 = 0,
	m02 = 0,
	m10 = 0,
	m11 = 1,
	m12 = 0,
}

local function firstVisiblePaint(paints)
	for _, paint in ipairs(paints or {}) do
		if paint.visible ~= false then
			return paint
		end
	end
	return nil
end

local function copyColor(color)
	if not color then
		return nil
	end
	return {
		r = color.r or 0,
		g = color.g or 0,
		b = color.b or 0,
		a = color.a or 1,
	}
end

local function roleForNode(node)
	if node.type == "TEXT" or node.textData then
		return "TextLabel"
	elseif CONTAINER_TYPES[node.type] then
		return "Frame"
	end
	return "Frame"
end

local function buildDocument(message, version, source)
	local nodeChanges = message.nodeChanges
	if not nodeChanges or #nodeChanges == 0 then
		error("This .fig file does not contain a scene graph.")
	end

	local warnings = {}
	local nodesById = {}
	local lastNodeIndex = {}
	for index, node in ipairs(nodeChanges) do
		if node.guid then
			local key = guidKey(node.guid)
			if node.phase == "REMOVED" then
				nodesById[key] = nil
				lastNodeIndex[key] = nil
			else
				nodesById[key] = node
				lastNodeIndex[key] = index
			end
		end
	end

	local orderedNodes = {}
	for key, node in pairs(nodesById) do
		node._children = {}
		node._figmaKey = key
		table.insert(orderedNodes, node)
	end
	table.sort(orderedNodes, function(left, right)
		return lastNodeIndex[left._figmaKey] < lastNodeIndex[right._figmaKey]
	end)

	local visibleCanvases = {}
	for _, node in ipairs(orderedNodes) do
		if node.type == "CANVAS" and node.visible ~= false and not node.internalOnly then
			table.insert(visibleCanvases, node)
		end
	end

	local orphanCount = 0
	for _, node in ipairs(orderedNodes) do
		if node.parentIndex and node.parentIndex.guid then
			local parent = nodesById[guidKey(node.parentIndex.guid)]
			if parent then
				table.insert(parent._children, node)
			else
				orphanCount += 1
			end
		end
	end
	if orphanCount > 0 then
		table.insert(
			warnings,
			string.format(
				"%d Figma node(s) referenced a missing or removed parent and could not be attached to the scene tree.",
				orphanCount
			)
		)
	end

	if #visibleCanvases == 0 then
		error("This .fig file does not contain a visible Figma page.")
	end

	if #visibleCanvases > 1 then
		table.insert(warnings, "Only the first visible Figma page was imported.")
	end

	local canvas = visibleCanvases[1]
	table.sort(canvas._children, function(left, right)
		return tostring(left.parentIndex.position) < tostring(right.parentIndex.position)
	end)

	local flatLayers = {}
	local layerIndex = 0
	local wrapWarningAdded = false
	local complexArtwork = false
	local decodedImages = {}
	local missingImageHashes = {}
	local imageDecodeFailures = {}
	local unsupportedPaintTypes = {}
	local unsupportedEffectTypes = {}
	local unsupportedBlendModes = {}
	local approximatedGradientTypes = {}
	local vectorNodeCount = 0
	local maskNodeCount = 0
	local multiPaintStackCount = 0
	local groupOpacityCount = 0
	local populatedInstanceCount = 0
	local unresolvedInstanceCount = 0

	local function findImageData(hash)
		if not hash then
			return nil
		end
		local direct = source.images[hash]
		if direct then
			return direct
		end
		for name, contents in pairs(source.images) do
			if string.sub(name, 1, #hash) == hash then
				return contents
			end
		end
		return nil
	end

	local function decodeImage(hash)
		if decodedImages[hash] ~= nil then
			return if decodedImages[hash] == false then nil else decodedImages[hash]
		end
		local encoded = findImageData(hash)
		if not encoded then
			missingImageHashes[hash] = true
			decodedImages[hash] = false
			return nil
		end
		if string.sub(encoded, 1, 8) ~= "\137PNG\r\n\026\n" then
			local format = if string.sub(encoded, 1, 2) == "\255\216"
				then "JPEG"
				elseif string.sub(encoded, 1, 4) == "RIFF" then "WebP"
				else "unknown"
			imageDecodeFailures[format] = (imageDecodeFailures[format] or 0) + 1
			decodedImages[hash] = false
			return nil
		end
		local ok, decoded = pcall(PngDecoder.decode, encoded)
		if not ok then
			imageDecodeFailures["PNG: " .. tostring(decoded)] = 1
			decodedImages[hash] = false
			return nil
		end
		decodedImages[hash] = decoded
		return decoded
	end

	local function trackPaints(paints)
		local visibleCount = 0
		for _, paint in ipairs(paints or {}) do
			if paint.visible ~= false then
				visibleCount += 1
				local paintType = paint.type or "UNKNOWN"
				if paintType ~= "SOLID" and paintType ~= "IMAGE" and not FigmaVisual.isGradientType(paintType) then
					unsupportedPaintTypes[paintType] = (unsupportedPaintTypes[paintType] or 0) + 1
					complexArtwork = true
				end
			end
		end
		if visibleCount > 1 then
			multiPaintStackCount += 1
			complexArtwork = true
		end
	end

	local function convertNode(node, parentMatrix)
		if node.visible == false then
			return nil
		end

		local matrix = multiplyMatrix(parentMatrix, node.transform or IDENTITY_MATRIX)
		-- IMPORTANT: unlike the previous version, the fallback here is {x=0,y=0}
		-- instead of {x=1,y=1}. GROUP nodes (and a handful of other Figma node
		-- types) don't always carry their own `size` field, since Figma derives
		-- their bounds from their children. Forcing a fake 1x1 size made that
		-- case indistinguishable from "a real, tiny layer", which meant
		-- UIBuilder's own children-bounding-box fallback (see getBounds in
		-- UIBuilder.luau) could never kick in for sizeless nodes. Reporting a
		-- true 0x0 here lets that fallback do its job.
		local size = node.size or (node.textData and node.textData.layoutSize) or { x = 0, y = 0 }
		local scaleX = math.sqrt(matrix.m00 * matrix.m00 + matrix.m10 * matrix.m10)
		local scaleY = math.sqrt(matrix.m01 * matrix.m01 + matrix.m11 * matrix.m11)
		local scaledWidth = math.max(0, (size.x or 0) * scaleX)
		local scaledHeight = math.max(0, (size.y or 0) * scaleY)
		local fill = firstVisiblePaint(node.fillPaints)
		local stroke = firstVisiblePaint(node.strokePaints)
		trackPaints(node.fillPaints)
		trackPaints(node.strokePaints)
		local normalizedFill = FigmaVisual.normalizePaint(fill)
		local normalizedStroke = FigmaVisual.normalizePaint(stroke)
		local backgroundColor
		local fillOpacity = 0
		local fillGradient
		local strokeGradient
		local imagePixels
		local imagePixelWidth
		local imagePixelHeight
		local imageScaleMode
		local imageOpacity

		if normalizedFill and normalizedFill.type == "SOLID" then
			backgroundColor = normalizedFill.color
			fillOpacity = backgroundColor and backgroundColor.a or 0
		elseif normalizedFill and FigmaVisual.isGradientType(normalizedFill.type) then
			fillGradient = normalizedFill
			local firstStop = normalizedFill.gradientStops and normalizedFill.gradientStops[1]
			backgroundColor = firstStop and firstStop.color or copyColor(fill and fill.color)
			fillOpacity = 1
			if normalizedFill.type ~= "GRADIENT_LINEAR" then
				approximatedGradientTypes[normalizedFill.type] = (approximatedGradientTypes[normalizedFill.type] or 0)
					+ 1
				complexArtwork = true
			end
		elseif normalizedFill and normalizedFill.type == "IMAGE" then
			imageOpacity = normalizedFill.opacity
			imageScaleMode = normalizedFill.imageScaleMode
			if normalizedFill.imageHash then
				local decoded = decodeImage(normalizedFill.imageHash)
				if decoded then
					imagePixels = decoded.pixels
					imagePixelWidth = decoded.width
					imagePixelHeight = decoded.height
				else
					complexArtwork = true
				end
			else
				missingImageHashes["<missing paint hash>"] = true
				complexArtwork = true
			end
		end

		if normalizedStroke and FigmaVisual.isGradientType(normalizedStroke.type) then
			strokeGradient = normalizedStroke
			if normalizedStroke.type ~= "GRADIENT_LINEAR" then
				approximatedGradientTypes[normalizedStroke.type] = (
					approximatedGradientTypes[normalizedStroke.type] or 0
				) + 1
				complexArtwork = true
			end
		end

		local effects = FigmaVisual.normalizeEffects(node.effects)
		for _, effect in ipairs(effects) do
			if effect.type ~= "DROP_SHADOW" then
				unsupportedEffectTypes[effect.type] = (unsupportedEffectTypes[effect.type] or 0) + 1
				complexArtwork = true
			end
		end
		if (node.opacity or 1) < 1 and #node._children > 0 then
			groupOpacityCount += 1
			complexArtwork = true
		end
		local blendMode = node.blendMode or "NORMAL"
		if blendMode ~= "NORMAL" and blendMode ~= "PASS_THROUGH" then
			unsupportedBlendModes[blendMode] = (unsupportedBlendModes[blendMode] or 0) + 1
			complexArtwork = true
		end
		if FigmaVisual.isComplexVectorType(node.type) then
			vectorNodeCount += 1
			complexArtwork = true
		end
		if node.mask == true then
			maskNodeCount += 1
			complexArtwork = true
		end

		local cornerRadii = FigmaVisual.cornerRadii(node)
		if node.type == "ELLIPSE" then
			local radius = math.min(scaledWidth, scaledHeight) / 2
			cornerRadii = {
				topLeft = radius,
				topRight = radius,
				bottomRight = radius,
				bottomLeft = radius,
				independent = false,
			}
			if node.arcData or math.abs(scaledWidth - scaledHeight) > 0.01 then
				vectorNodeCount += 1
				complexArtwork = true
			end
		end
		local fontInfo = FigmaVisual.fontInfo(node)
		local layoutData = FigmaLayout.fromWireNode(node)
		if
			layoutData.layoutWrap == "WRAP"
			and layoutData.counterAxisSpacing
			and layoutData.counterAxisSpacing ~= layoutData.layoutGap
			and not wrapWarningAdded
		then
			wrapWarningAdded = true
			table.insert(
				warnings,
				string.format(
					"Frame '%s' uses a separate wrapped-line gap; Roblox applies one UIListLayout gap in both directions, so the primary gap was used.",
					node.name or "Unnamed"
				)
			)
		end

		layerIndex += 1
		local layer = {
			index = layerIndex,
			name = node.name or node.type or "FigmaLayer",
			left = matrix.m02,
			top = matrix.m12,
			-- No forced 1px minimum anymore (see the `size` fallback above) - a
			-- node with no real size now legitimately reports 0 so callers can
			-- tell "no size data" apart from "a genuinely tiny layer".
			width = scaledWidth,
			height = scaledHeight,
			opacity = math.floor(math.clamp(node.opacity or 1, 0, 1) * 255 + 0.5),
			visible = true,
			blendMode = blendMode,
			children = {},
			suggestedRole = roleForNode(node),
			text = if node.textData then node.textData.characters else nil,
			textSize = node.fontSize,
			fontFamily = fontInfo.family,
			fontStyle = fontInfo.style,
			fontWeight = fontInfo.weight,
			fontItalic = fontInfo.italic,
			textAlignHorizontal = node.textAlignHorizontal,
			textAlignVertical = node.textAlignVertical,
			backgroundColor = backgroundColor,
			backgroundTransparency = 1 - fillOpacity,
			fillGradient = fillGradient,
			cornerRadius = node.cornerRadius,
			cornerRadii = cornerRadii,
			strokeColor = normalizedStroke and normalizedStroke.color,
			strokeGradient = strokeGradient,
			strokeThickness = node.strokeWeight,
			strokeAlign = node.strokeAlign,
			strokeJoin = node.strokeJoin,
			effects = effects,
			pixels = imagePixels,
			pixelWidth = imagePixelWidth,
			pixelHeight = imagePixelHeight,
			imageScaleMode = imageScaleMode,
			imageOpacity = imageOpacity,
			isMask = node.mask == true,
			clipsContent = node.frameMaskDisabled == false and node.resizeToFit ~= true,
			rotation = math.deg(math.atan2(matrix.m10, matrix.m00)),
			figmaType = node.type,
			figmaNodeId = node._figmaKey,

			-- Auto-layout ("stack") properties of THIS node, when it is itself
			-- an auto-layout frame/container.
			layoutMode = layoutData.layoutMode,
			layoutGap = layoutData.layoutGap,
			paddingLeft = layoutData.paddingLeft,
			paddingRight = layoutData.paddingRight,
			paddingTop = layoutData.paddingTop,
			paddingBottom = layoutData.paddingBottom,
			primaryAxisAlignItems = layoutData.primaryAxisAlignItems,
			counterAxisAlignItems = layoutData.counterAxisAlignItems,
			primaryAxisSizingMode = layoutData.primaryAxisSizingMode,
			counterAxisSizingMode = layoutData.counterAxisSizingMode,
			layoutWrap = layoutData.layoutWrap,
			counterAxisSpacing = layoutData.counterAxisSpacing,

			-- How THIS node participates in its PARENT's auto-layout, when the
			-- parent is an auto-layout frame. layoutPositioning == "ABSOLUTE"
			-- means the designer turned on Figma's "Absolute position" toggle,
			-- which pulls the node out of the auto-layout flow and makes it
			-- behave like a normal constraint-positioned child again.
			layoutAlign = layoutData.layoutAlign,
			layoutGrow = layoutData.layoutGrow,
			layoutPositioning = layoutData.layoutPositioning,

			-- Figma's resize constraints (MIN/MAX/CENTER/STRETCH/SCALE per
			-- axis). Only meaningful when this node is NOT being positioned by
			-- a parent auto-layout frame, but we capture it unconditionally
			-- since layoutPositioning == "ABSOLUTE" children need it too.
			constraints = layoutData.constraints,
		}

		table.insert(flatLayers, layer)
		local childNodes = node._children
		local childParentMatrix = matrix
		if node.type == "INSTANCE" and #childNodes == 0 then
			local symbolGuid = node.symbolData and node.symbolData.symbolID
			local sourceNode = symbolGuid and nodesById[guidKey(symbolGuid)]
			if sourceNode and sourceNode ~= node and #sourceNode._children > 0 then
				childNodes = sourceNode._children
				local sourceSize = sourceNode.size or { x = size.x, y = size.y }
				local instanceScaleX = if (sourceSize.x or 0) > 0 then (size.x or 0) / sourceSize.x else 1
				local instanceScaleY = if (sourceSize.y or 0) > 0 then (size.y or 0) / sourceSize.y else 1
				childParentMatrix = multiplyMatrix(matrix, {
					m00 = instanceScaleX,
					m01 = 0,
					m02 = 0,
					m10 = 0,
					m11 = instanceScaleY,
					m12 = 0,
				})
				populatedInstanceCount += 1
				complexArtwork = true
			else
				unresolvedInstanceCount += 1
				complexArtwork = true
			end
		end
		table.sort(childNodes, function(left, right)
			return tostring(left.parentIndex.position) < tostring(right.parentIndex.position)
		end)
		for _, childNode in ipairs(childNodes) do
			local childLayer = convertNode(childNode, childParentMatrix)
			if childLayer then
				table.insert(layer.children, childLayer)
			end
		end

		return layer
	end

	local tree = {}
	for _, node in ipairs(canvas._children) do
		local layer = convertNode(node, IDENTITY_MATRIX)
		if layer then
			table.insert(tree, layer)
		end
	end

	if #tree == 0 then
		error("The first visible Figma page is empty.")
	end

	local minimumX = math.huge
	local minimumY = math.huge
	local maximumX = -math.huge
	local maximumY = -math.huge
	for _, layer in ipairs(tree) do
		local bounds = FigmaLayout.getEffectiveBounds(layer)
		if bounds then
			minimumX = math.min(minimumX, bounds.left)
			minimumY = math.min(minimumY, bounds.top)
			maximumX = math.max(maximumX, bounds.left + bounds.width)
			maximumY = math.max(maximumY, bounds.top + bounds.height)
		end
	end
	if minimumX == math.huge then
		error("The first visible Figma page has no measurable layers.")
	end

	local function normalizeLayer(layer)
		layer.left -= minimumX
		layer.top -= minimumY
		for _, child in ipairs(layer.children) do
			normalizeLayer(child)
		end
	end
	for _, layer in ipairs(tree) do
		normalizeLayer(layer)
	end

	local function countKeys(values)
		local count = 0
		for _ in pairs(values) do
			count += 1
		end
		return count
	end

	local function describeCounts(values)
		local descriptions = {}
		for name, count in pairs(values) do
			table.insert(descriptions, string.format("%s (%d)", tostring(name), count))
		end
		table.sort(descriptions)
		return table.concat(descriptions, ", ")
	end

	if countKeys(unsupportedPaintTypes) > 0 then
		table.insert(
			warnings,
			"Unsupported Figma paint types were detected and preserved only by the rendered fallback: "
				.. describeCounts(unsupportedPaintTypes)
		)
	end
	if countKeys(unsupportedEffectTypes) > 0 then
		table.insert(
			warnings,
			"Figma effects without a native Roblox equivalent were detected: " .. describeCounts(unsupportedEffectTypes)
		)
	end
	if countKeys(unsupportedBlendModes) > 0 then
		table.insert(
			warnings,
			"Non-normal Figma blend modes require rendered fallback: " .. describeCounts(unsupportedBlendModes)
		)
	end
	if countKeys(approximatedGradientTypes) > 0 then
		table.insert(
			warnings,
			"Radial, angular, or diamond gradients use a linear native approximation: "
				.. describeCounts(approximatedGradientTypes)
		)
	end
	if countKeys(missingImageHashes) > 0 then
		table.insert(
			warnings,
			string.format(
				"%d embedded image reference(s) were missing from the .fig archive.",
				countKeys(missingImageHashes)
			)
		)
	end
	if countKeys(imageDecodeFailures) > 0 then
		table.insert(
			warnings,
			"Some embedded images could not be decoded natively and require rendered fallback: "
				.. describeCounts(imageDecodeFailures)
		)
	end
	if vectorNodeCount > 0 or maskNodeCount > 0 then
		table.insert(
			warnings,
			string.format(
				"The design contains %d complex vector node(s) and %d mask(s); native semantic layers are retained while rendered artwork supplies visual fidelity.",
				vectorNodeCount,
				maskNodeCount
			)
		)
	end
	if multiPaintStackCount > 0 then
		table.insert(
			warnings,
			string.format(
				"%d node paint stack(s) contain multiple visible paints and require compositing.",
				multiPaintStackCount
			)
		)
	end
	if groupOpacityCount > 0 then
		table.insert(
			warnings,
			string.format(
				"%d translucent group(s) require rendered compositing because Roblox frame transparency does not affect descendants.",
				groupOpacityCount
			)
		)
	end
	if populatedInstanceCount > 0 then
		table.insert(
			warnings,
			string.format(
				"Populated %d empty component instance(s) from their source component trees; complex instance overrides may still require rendered fallback.",
				populatedInstanceCount
			)
		)
	end
	if unresolvedInstanceCount > 0 then
		table.insert(
			warnings,
			string.format(
				"%d component instance(s) had no inline children and no resolvable source component.",
				unresolvedInstanceCount
			)
		)
	end

	local composite
	if complexArtwork and source.thumbnail then
		local ok, decodedOrError = pcall(PngDecoder.decode, source.thumbnail)
		if ok then
			composite = decodedOrError
			table.insert(
				warnings,
				string.format(
					"Complex Figma artwork is displayed from the embedded %dx%d preview while native layers remain as transparent semantic overlays.",
					composite.width,
					composite.height
				)
			)
		else
			table.insert(warnings, "The embedded Figma preview could not be decoded: " .. tostring(decodedOrError))
		end
	elseif complexArtwork then
		table.insert(
			warnings,
			"This .fig file has complex artwork but no embedded PNG preview; unsupported visuals remain native approximations."
		)
	end

	return {
		width = math.max(1, math.ceil(maximumX - minimumX)),
		height = math.max(1, math.ceil(maximumY - minimumY)),
		layers = flatLayers,
		tree = tree,
		warnings = warnings,
		sourceType = "FIG",
		figVersion = version,
		pageName = canvas.name,
		preferCompositeArtwork = composite ~= nil,
		compositePixels = composite and composite.pixels,
		compositeWidth = composite and composite.width,
		compositeHeight = composite and composite.height,
		compositeSource = if composite then "FigmaThumbnail" else nil,
	}
end

function FigParser.parse(data)
	local source = getFigSource(data)
	local message, version = decodeCanvas(source.canvasData)
	return buildDocument(message, version, source)
end

return FigParser
