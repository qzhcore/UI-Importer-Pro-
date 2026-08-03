local Deflate = require(script.Parent.Deflate)

local FigParser = {}

local ZSTD_MAGIC = "\x28\xb5\x2f\xfd"
local FIG_MAGIC = "fig-kiwi"
local MAX_SEGMENT_BYTES = 128 * 1024 * 1024

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

local function extractZipEntry(archive, targetName)
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

	for _ = 1, entryCount do
		if string.sub(archive, centralPosition, centralPosition + 3) ~= "PK\001\002" then
			error("This .fig ZIP archive has a damaged central directory.")
		end

		local compressionMethod = readU16LE(archive, centralPosition + 10)
		local compressedSize = readU32LE(archive, centralPosition + 20)
		local filenameLength = readU16LE(archive, centralPosition + 28)
		local extraLength = readU16LE(archive, centralPosition + 30)
		local commentLength = readU16LE(archive, centralPosition + 32)
		local localHeaderOffset = readU32LE(archive, centralPosition + 42)
		local filename = string.sub(archive, centralPosition + 46, centralPosition + 45 + filenameLength)

		if filename == targetName then
			local localPosition = localHeaderOffset + 1
			if string.sub(archive, localPosition, localPosition + 3) ~= "PK\003\004" then
				error("This .fig ZIP archive has a damaged local entry.")
			end

			local localFilenameLength = readU16LE(archive, localPosition + 26)
			local localExtraLength = readU16LE(archive, localPosition + 28)
			local dataStart = localPosition + 30 + localFilenameLength + localExtraLength
			local compressed = string.sub(archive, dataStart, dataStart + compressedSize - 1)

			if compressionMethod == 0 then
				return compressed
			elseif compressionMethod == 8 then
				return Deflate.decompress(compressed)
			end

			error(string.format("Unsupported ZIP compression method %d in %s.", compressionMethod, targetName))
		end

		centralPosition += 46 + filenameLength + extraLength + commentLength
	end

	error(string.format("This .fig archive does not contain %s.", targetName))
end

local function getCanvasData(data)
	if string.sub(data, 1, 2) == "PK" then
		return extractZipEntry(data, "canvas.fig")
	end
	return data
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
	if node.type == "TEXT" then
		return "TextLabel"
	elseif CONTAINER_TYPES[node.type] then
		return "Frame"
	end
	return "Frame"
end

local function buildDocument(message, version)
	local nodeChanges = message.nodeChanges
	if not nodeChanges or #nodeChanges == 0 then
		error("This .fig file does not contain a scene graph.")
	end

	local nodesById = {}
	local visibleCanvases = {}
	for _, node in ipairs(nodeChanges) do
		node._children = {}
		nodesById[guidKey(node.guid)] = node
		if node.type == "CANVAS" and node.visible ~= false and not node.internalOnly then
			table.insert(visibleCanvases, node)
		end
	end

	for _, node in ipairs(nodeChanges) do
		if node.parentIndex and node.parentIndex.guid then
			local parent = nodesById[guidKey(node.parentIndex.guid)]
			if parent then
				table.insert(parent._children, node)
			end
		end
	end

	if #visibleCanvases == 0 then
		error("This .fig file does not contain a visible Figma page.")
	end

	local warnings = {}
	if #visibleCanvases > 1 then
		table.insert(warnings, "Only the first visible Figma page was imported.")
	end

	local canvas = visibleCanvases[1]
	table.sort(canvas._children, function(left, right)
		return tostring(left.parentIndex.position) < tostring(right.parentIndex.position)
	end)

	local flatLayers = {}
	local layerIndex = 0
	local imageWarningAdded = false
	local wrapWarningAdded = false

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
		local fill = firstVisiblePaint(node.fillPaints)
		local stroke = firstVisiblePaint(node.strokePaints)
		local backgroundColor
		local fillOpacity = 0

		if fill and fill.type == "SOLID" then
			backgroundColor = copyColor(fill.color)
			fillOpacity = (fill.opacity or 1) * (backgroundColor.a or 1)
		elseif fill and fill.type == "IMAGE" and not imageWarningAdded then
			imageWarningAdded = true
			table.insert(
				warnings,
				"Embedded bitmap fills in native .fig files are represented as placeholders; frames, vectors, text, colors, and hierarchy are still imported."
			)
		end

		if
			(node.stackMode == "HORIZONTAL" or node.stackMode == "VERTICAL")
			and node.layoutWrap == "WRAP"
			and not wrapWarningAdded
		then
			wrapWarningAdded = true
			table.insert(
				warnings,
				string.format(
					"Frame '%s' uses Figma's wrapping auto-layout, which UIListLayout cannot reproduce; children were imported as a single non-wrapping row/column.",
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
			width = math.max(0, (size.x or 0) * scaleX),
			height = math.max(0, (size.y or 0) * scaleY),
			opacity = math.floor(math.clamp(node.opacity or 1, 0, 1) * 255 + 0.5),
			visible = true,
			blendMode = node.blendMode or "NORMAL",
			children = {},
			suggestedRole = roleForNode(node),
			text = if node.textData then node.textData.characters else nil,
			textSize = node.fontSize,
			backgroundColor = backgroundColor,
			backgroundTransparency = 1 - fillOpacity,
			cornerRadius = node.cornerRadius,
			strokeColor = if stroke and stroke.type == "SOLID" then copyColor(stroke.color) else nil,
			strokeThickness = node.strokeWeight,
			rotation = math.deg(math.atan2(matrix.m10, matrix.m00)),
			figmaType = node.type,

			-- Auto-layout ("stack") properties of THIS node, when it is itself
			-- an auto-layout frame/container.
			layoutMode = node.stackMode,
			layoutGap = node.stackSpacing,
			paddingLeft = node.stackPaddingLeft,
			paddingRight = node.stackPaddingRight,
			paddingTop = node.stackPaddingTop,
			paddingBottom = node.stackPaddingBottom,
			primaryAxisAlignItems = node.primaryAxisAlignItems,
			counterAxisAlignItems = node.counterAxisAlignItems,
			primaryAxisSizingMode = node.primaryAxisSizingMode,
			counterAxisSizingMode = node.counterAxisSizingMode,

			-- How THIS node participates in its PARENT's auto-layout, when the
			-- parent is an auto-layout frame. layoutPositioning == "ABSOLUTE"
			-- means the designer turned on Figma's "Absolute position" toggle,
			-- which pulls the node out of the auto-layout flow and makes it
			-- behave like a normal constraint-positioned child again.
			layoutAlign = node.layoutAlign,
			layoutGrow = node.layoutGrow,
			layoutPositioning = node.layoutPositioning,

			-- Figma's resize constraints (MIN/MAX/CENTER/STRETCH/SCALE per
			-- axis). Only meaningful when this node is NOT being positioned by
			-- a parent auto-layout frame, but we capture it unconditionally
			-- since layoutPositioning == "ABSOLUTE" children need it too.
			constraints = if node.constraints
				then {
					horizontal = node.constraints.horizontal,
					vertical = node.constraints.vertical,
				}
				else nil,
		}

		table.insert(flatLayers, layer)
		table.sort(node._children, function(left, right)
			return tostring(left.parentIndex.position) < tostring(right.parentIndex.position)
		end)
		for _, childNode in ipairs(node._children) do
			local childLayer = convertNode(childNode, matrix)
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
		minimumX = math.min(minimumX, layer.left)
		minimumY = math.min(minimumY, layer.top)
		maximumX = math.max(maximumX, layer.left + layer.width)
		maximumY = math.max(maximumY, layer.top + layer.height)
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

	return {
		width = math.max(1, math.ceil(maximumX - minimumX)),
		height = math.max(1, math.ceil(maximumY - minimumY)),
		layers = flatLayers,
		tree = tree,
		warnings = warnings,
		sourceType = "FIG",
		figVersion = version,
		pageName = canvas.name,
	}
end

function FigParser.parse(data)
	local canvasData = getCanvasData(data)
	local message, version = decodeCanvas(canvasData)
	return buildDocument(message, version)
end

return FigParser
