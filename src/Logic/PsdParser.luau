local ImportJob = require(script.Parent.ImportJob)
local PsdEffects = require(script.Parent.PsdEffects)
local PsdParser = {}

local PSD_SIGNATURE = "8BPS"
local PSD_VERSION = 1
local RGB_COLOR_MODE = 3
local RAW_COMPRESSION = 0
local RLE_COMPRESSION = 1

local function makeReader(data, job)
	local reader = {
		data = data,
		position = 1,
		length = #data,
		job = job,
	}

	function reader:ensure(byteCount)
		if byteCount < 0 or self.position + byteCount - 1 > self.length then
			error("The PSD ended unexpectedly while reading layer data.")
		end
	end

	function reader:readU8()
		self:ensure(1)
		local value = string.byte(self.data, self.position)
		self.position += 1
		return value
	end

	function reader:readU16()
		self:ensure(2)
		local first, second = string.byte(self.data, self.position, self.position + 1)
		self.position += 2
		return (first * 256) + second
	end

	function reader:readI16()
		local value = self:readU16()
		return if value >= 0x8000 then value - 0x10000 else value
	end

	function reader:readU32()
		self:ensure(4)
		local first, second, third, fourth = string.byte(self.data, self.position, self.position + 3)
		self.position += 4
		return (first * 0x1000000) + (second * 0x10000) + (third * 0x100) + fourth
	end

	function reader:readI32()
		local value = self:readU32()
		return if value >= 0x80000000 then value - 0x100000000 else value
	end

	function reader:readString(byteCount)
		self:ensure(byteCount)
		local value = string.sub(self.data, self.position, self.position + byteCount - 1)
		self.position += byteCount
		return value
	end

	function reader:skip(byteCount)
		self:ensure(byteCount)
		self.position += byteCount
	end

	return reader
end

local function readU32At(data, position)
	if position < 1 or position + 3 > #data then
		return nil
	end

	local first, second, third, fourth = string.byte(data, position, position + 3)
	return (first * 0x1000000) + (second * 0x10000) + (third * 0x100) + fourth
end

local function decodeUtf16BigEndian(data, position, characterCount)
	local characters = {}
	local index = 0

	while index < characterCount do
		local bytePosition = position + (index * 2)
		if bytePosition + 1 > #data then
			break
		end

		local high, low = string.byte(data, bytePosition, bytePosition + 1)
		local codepoint = (high * 256) + low
		index += 1

		if codepoint >= 0xD800 and codepoint <= 0xDBFF and index < characterCount then
			local nextPosition = position + (index * 2)
			local nextHigh, nextLow = string.byte(data, nextPosition, nextPosition + 1)
			local lowSurrogate = (nextHigh * 256) + nextLow
			if lowSurrogate >= 0xDC00 and lowSurrogate <= 0xDFFF then
				codepoint = 0x10000 + ((codepoint - 0xD800) * 0x400) + (lowSurrogate - 0xDC00)
				index += 1
			end
		end

		local ok, character = pcall(utf8.char, codepoint)
		table.insert(characters, if ok then character else utf8.char(0xFFFD))
	end

	return table.concat(characters)
end

local function extractTextLayerValue(tagData)
	local searchPosition = 1

	while searchPosition <= #tagData do
		local keyPosition = string.find(tagData, "Txt ", searchPosition, true)
		if not keyPosition then
			return nil
		end

		local valueTypePosition = string.find(tagData, "TEXT", keyPosition + 4, true)
		if valueTypePosition and valueTypePosition - keyPosition <= 16 then
			local characterCount = readU32At(tagData, valueTypePosition + 4)
			if characterCount and characterCount >= 0 and characterCount <= 100000 then
				return decodeUtf16BigEndian(tagData, valueTypePosition + 8, characterCount)
			end
		end

		searchPosition = keyPosition + 4
	end

	return nil
end

local function readPascalLayerName(reader)
	local nameLength = reader:readU8()
	local name = reader:readString(nameLength)
	local consumed = nameLength + 1
	local padding = (4 - (consumed % 4)) % 4
	reader:skip(padding)
	return name
end

local function readAdditionalLayerInfo(reader, extraEnd, layer, warnings)
	while reader.position + 11 <= extraEnd do
		local signature = reader:readString(4)
		if signature ~= "8BIM" and signature ~= "8B64" then
			reader.position -= 4
			break
		end

		local key = reader:readString(4)
		local dataLength = reader:readU32()
		local dataStart = reader.position
		local dataEnd = dataStart + dataLength

		if dataEnd > extraEnd then
			table.insert(
				warnings,
				string.format("Layer '%s' contains a truncated '%s' metadata block.", layer.name, key)
			)
			reader.position = extraEnd
			break
		end

		if key == "luni" and dataLength >= 4 then
			local characterCount = reader:readU32()
			local availableCharacters = math.floor((dataEnd - reader.position) / 2)
			layer.name =
				decodeUtf16BigEndian(reader.data, reader.position, math.min(characterCount, availableCharacters))
		elseif key == "lsct" and dataLength >= 4 then
			layer.sectionType = reader:readU32()
		elseif key == "TySh" then
			layer.text = extractTextLayerValue(string.sub(reader.data, dataStart, dataEnd - 1))
		elseif key == "lyid" and dataLength == 4 then
			layer.psdLayerId = reader:readU32()
		elseif key == "vmsk" or key == "vsms" then
			layer.unsupportedMask = true
		elseif key == "lfx2" or key == "lrFX" or key == "lmfx" then
			layer.hasLayerEffects = true
			if key == "lfx2" then
				local ok, effects =
					pcall(PsdEffects.decode, string.sub(reader.data, dataStart, dataEnd - 1), reader.job)
				reader.job:checkpoint()
				if ok then
					layer.psdEffects = effects
				else
					table.insert(warnings, layer.name .. ": could not read layer styles: " .. tostring(effects))
				end
			end
		end

		reader.position = dataEnd
		if dataLength % 2 == 1 and reader.position < extraEnd then
			reader:skip(1)
		end
	end
end

local function decodeRawChannel(reader, pixelCount)
	reader:ensure(pixelCount)
	reader.job:reserveBytes(pixelCount)
	return buffer.fromstring(reader:readString(pixelCount))
end

local function decodeRleRow(reader, encodedLength, output, outputOffset, expectedLength)
	local encodedEnd = reader.position + encodedLength
	local written = 0
	reader:ensure(encodedLength)

	while reader.position < encodedEnd and written < expectedLength do
		local control = reader:readU8()
		if control <= 127 then
			local literalCount = control + 1
			if written + literalCount > expectedLength or reader.position + literalCount > encodedEnd then
				error("Invalid PSD RLE literal run.")
			end
			for _ = 1, literalCount do
				buffer.writeu8(output, outputOffset + written, reader:readU8())
				written += 1
			end
		elseif control >= 129 then
			local repeatCount = 257 - control
			if written + repeatCount > expectedLength or reader.position >= encodedEnd then
				error("Invalid PSD RLE repeat run.")
			end
			local value = reader:readU8()
			for _ = 1, repeatCount do
				buffer.writeu8(output, outputOffset + written, value)
				written += 1
			end
		end
	end
	if written ~= expectedLength then
		error("Truncated PSD RLE row.")
	end
	reader.position = encodedEnd
	reader.job:checkpoint()
end

local function decodeRleChannel(reader, width, height)
	reader:ensure(height * 2)
	local rowLengths = table.create(height)
	for row = 1, height do
		rowLengths[row] = reader:readU16()
	end

	reader.job:reserveBytes(width * height)
	local pixels = buffer.create(width * height)
	for row = 1, height do
		decodeRleRow(reader, rowLengths[row], pixels, (row - 1) * width, width)
	end

	return pixels
end

local function decodeChannel(reader, compression, width, height)
	local pixelCount = width * height
	if compression == RAW_COMPRESSION then
		return decodeRawChannel(reader, pixelCount)
	end

	if compression == RLE_COMPRESSION then
		return decodeRleChannel(reader, width, height)
	end

	return nil
end

local function combineChannels(layer, job)
	local red = layer.channels[0]
	local green = layer.channels[1]
	local blue = layer.channels[2]
	local alpha = layer.channels[-1]

	if not red and not green and not blue then
		return nil
	end

	local pixelCount = layer.width * layer.height
	job:reserveBytes(pixelCount * 4)
	local pixels = buffer.create(pixelCount * 4)

	for index = 0, pixelCount - 1 do
		if index % 8192 == 0 then
			job:checkpoint()
		end
		local pixelOffset = index * 4
		buffer.writeu8(pixels, pixelOffset, if red then buffer.readu8(red, index) else 0)
		buffer.writeu8(pixels, pixelOffset + 1, if green then buffer.readu8(green, index) else 0)
		buffer.writeu8(pixels, pixelOffset + 2, if blue then buffer.readu8(blue, index) else 0)
		local opacity = if alpha then buffer.readu8(alpha, index) else 255
		local mask = layer.mask
		if mask and not mask.disabled and not mask.unsupported then
			local maskX = layer.left + index % layer.width - mask.left
			local maskY = layer.top + math.floor(index / layer.width) - mask.top
			local value = mask.defaultColor
			if layer.channels[-2] and maskX >= 0 and maskY >= 0 and maskX < mask.width and maskY < mask.height then
				value = buffer.readu8(layer.channels[-2], maskY * mask.width + maskX)
			end
			if mask.inverted then
				value = 255 - value
			end
			opacity = math.floor(opacity * value / 255 + 0.5)
		end
		buffer.writeu8(pixels, pixelOffset + 3, opacity)
	end

	return pixels
end

local function compositeChannelId(channelIndex)
	if channelIndex == 1 then
		return 0
	elseif channelIndex == 2 then
		return 1
	elseif channelIndex == 3 then
		return 2
	elseif channelIndex == 4 then
		return -1
	end

	return nil
end

local function decodeCompositePixels(reader, compression, channelCount, width, height, warnings)
	local pixelCount = width * height
	local channels = {}

	if compression == RAW_COMPRESSION then
		for channelIndex = 1, channelCount do
			local channelId = compositeChannelId(channelIndex)
			if channelId then
				channels[channelId] = decodeRawChannel(reader, pixelCount)
			else
				reader:skip(pixelCount)
			end
		end
	elseif compression == RLE_COMPRESSION then
		local rowLengths = table.create(channelCount)
		for channelIndex = 1, channelCount do
			local channelRows = table.create(height)
			for row = 1, height do
				channelRows[row] = reader:readU16()
			end
			rowLengths[channelIndex] = channelRows
		end

		for channelIndex = 1, channelCount do
			local channelId = compositeChannelId(channelIndex)
			local channelRows = rowLengths[channelIndex]
			if channelId then
				reader.job:reserveBytes(pixelCount)
				local pixels = buffer.create(pixelCount)
				for row = 1, height do
					decodeRleRow(reader, channelRows[row], pixels, (row - 1) * width, width)
				end
				channels[channelId] = pixels
			else
				for row = 1, height do
					reader:skip(channelRows[row])
				end
			end
		end
	else
		table.insert(
			warnings,
			"The merged Photoshop preview uses unsupported ZIP compression, so layer artwork will be used instead."
		)
		return nil
	end

	return combineChannels({
		width = width,
		height = height,
		channels = channels,
	}, reader.job)
end

local function readLayerRecords(reader, layerCount, warnings)
	local layers = table.create(layerCount)

	for index = 1, layerCount do
		reader.job:checkpoint()
		local top = reader:readI32()
		local left = reader:readI32()
		local bottom = reader:readI32()
		local right = reader:readI32()
		local channelCount = reader:readU16()
		if channelCount > 56 then
			error("Invalid PSD channel count.")
		end
		local channelInfo = table.create(channelCount)

		for channelIndex = 1, channelCount do
			channelInfo[channelIndex] = {
				id = reader:readI16(),
				length = reader:readU32(),
			}
		end

		local blendSignature = reader:readString(4)
		if blendSignature ~= "8BIM" then
			error(string.format("Layer %d has an invalid blend-mode signature.", index))
		end

		local blendMode = reader:readString(4)
		local opacity = reader:readU8()
		local clipping = reader:readU8()
		local flags = reader:readU8()
		reader:skip(1)

		local extraLength = reader:readU32()
		local extraEnd = reader.position + extraLength
		if extraEnd - 1 > reader.length then
			error(string.format("Layer %d has invalid extra data.", index))
		end

		local maskDataLength = reader:readU32()
		local maskEnd = reader.position + maskDataLength
		if maskEnd > extraEnd then
			error("Invalid PSD mask length.")
		end
		local mask
		if maskDataLength >= 18 then
			local maskTop, maskLeft = reader:readI32(), reader:readI32()
			local maskBottom, maskRight = reader:readI32(), reader:readI32()
			local defaultColor, maskFlags = reader:readU8(), reader:readU8()
			local relative = bit32.band(maskFlags, 1) ~= 0
			mask = {
				top = maskTop + if relative then top else 0,
				left = maskLeft + if relative then left else 0,
				width = maskRight - maskLeft,
				height = maskBottom - maskTop,
				defaultColor = defaultColor,
				disabled = bit32.band(maskFlags, 2) ~= 0,
				inverted = bit32.band(maskFlags, 4) ~= 0,
				unsupported = bit32.band(maskFlags, 16) ~= 0,
			}
			reader.job:checkImage(mask.width, mask.height)
		elseif maskDataLength ~= 0 then
			error("Truncated PSD mask metadata.")
		end
		reader.position = maskEnd

		local blendingRangesLength = reader:readU32()
		reader:skip(blendingRangesLength)

		local layer = {
			index = index,
			name = readPascalLayerName(reader),
			top = top,
			left = left,
			bottom = bottom,
			right = right,
			width = math.max(0, right - left),
			height = math.max(0, bottom - top),
			channelInfo = channelInfo,
			channels = {},
			blendMode = blendMode,
			opacity = opacity,
			clipping = clipping,
			visible = bit32.band(flags, 0x02) == 0,
			sectionType = 0,
			text = nil,
			mask = mask,
			unsupportedMask = mask and mask.unsupported,
		}
		reader.job:checkImage(layer.width, layer.height)
		readAdditionalLayerInfo(reader, extraEnd, layer, warnings)
		if layer.psdEffects then
			PsdEffects.map(layer, layer.psdEffects)
			layer.psdEffects = nil
		end
		if layer.mask and (layer.sectionType == 1 or layer.sectionType == 2) then
			layer.unsupportedMask = true
		end
		reader.position = extraEnd
		layers[index] = layer
	end

	return layers
end

local function readLayerPixels(reader, layers, warnings)
	for _, layer in ipairs(layers) do
		for _, channelInfo in ipairs(layer.channelInfo) do
			reader.job:checkpoint()
			local blockStart = reader.position
			local blockEnd = blockStart + channelInfo.length

			if blockEnd - 1 > reader.length then
				error(string.format("Layer '%s' contains truncated channel pixels.", layer.name))
			end

			local width = if channelInfo.id == -2 and layer.mask then layer.mask.width else layer.width
			local height = if channelInfo.id == -2 and layer.mask then layer.mask.height else layer.height
			if channelInfo.length >= 2 and width > 0 and height > 0 then
				local compression = reader:readU16()
				if
					channelInfo.id == 0
					or channelInfo.id == 1
					or channelInfo.id == 2
					or channelInfo.id == -1
					or (channelInfo.id == -2 and layer.mask and not layer.mask.disabled)
				then
					local outerLength = reader.length
					reader.length = blockEnd - 1
					local ok, pixels = pcall(decodeChannel, reader, compression, width, height)
					reader.length = outerLength
					reader.job:checkpoint()
					if not ok then
						error(pixels, 0)
					end
					if ok and pixels then
						layer.channels[channelInfo.id] = pixels
					elseif compression ~= RAW_COMPRESSION and compression ~= RLE_COMPRESSION then
						table.insert(
							warnings,
							string.format(
								"Layer '%s' uses unsupported ZIP compression and was imported without raster pixels.",
								layer.name
							)
						)
					else
						table.insert(
							warnings,
							string.format("Layer '%s' contains unreadable raster pixels.", layer.name)
						)
					end
				end
			end

			reader.position = blockEnd
		end

		if layer.mask and not layer.mask.disabled and not layer.channels[-2] then
			layer.mask.unsupported = true
			layer.unsupportedMask = true
		end
		layer.pixels = combineChannels(layer, reader.job)
		PsdEffects.applyPixels(layer, reader.job)
		layer.channels = nil
		layer.channelInfo = nil
	end
end

local function buildLayerTree(layers, job)
	local roots = {}
	local stack = { roots }

	-- PSD layer records are stored from the bottom of the Photoshop stack to
	-- the top. Group opening records therefore appear after their children and
	-- group divider records appear before them. Walk backward to reconstruct
	-- the hierarchy, then insert at the front to retain bottom-to-top order.
	for index = #layers, 1, -1 do
		local layer = layers[index]
		if layer.sectionType == 1 or layer.sectionType == 2 then
			layer.children = {}
			table.insert(stack[#stack], 1, layer)
			table.insert(stack, layer.children)
			if #stack > job.limits.depth then
				error("PSD group nesting exceeds the limit.")
			end
		elseif layer.sectionType == 3 then
			if #stack > 1 then
				table.remove(stack)
			end
		else
			table.insert(stack[#stack], 1, layer)
		end
	end

	return roots
end

function PsdParser.parse(data, job, options)
	job = job or ImportJob.new()
	if type(data) ~= "string" or #data < 26 then
		error("Choose a valid Photoshop PSD file.")
	end

	local reader = makeReader(data, job)
	if reader:readString(4) ~= PSD_SIGNATURE then
		error("The selected file is not a Photoshop PSD.")
	end

	local version = reader:readU16()
	if version ~= PSD_VERSION then
		error("PSB files are not supported yet. Save the design as a standard PSD.")
	end

	reader:skip(6)
	local channelCount = reader:readU16()
	local height = reader:readU32()
	local width = reader:readU32()
	local depth = reader:readU16()
	local colorMode = reader:readU16()
	job:checkImage(width, height)
	if width == 0 or height == 0 or channelCount < 3 or channelCount > 56 then
		error("Invalid PSD dimensions or channel count.")
	end

	if depth ~= 8 then
		error(string.format("This PSD uses %d-bit channels. Save an 8-bit RGB copy before importing.", depth))
	end

	if colorMode ~= RGB_COLOR_MODE then
		error("Only RGB Photoshop documents are supported. Convert the PSD to RGB Color before importing.")
	end

	local colorModeDataLength = reader:readU32()
	reader:skip(colorModeDataLength)

	local imageResourcesLength = reader:readU32()
	reader:skip(imageResourcesLength)

	local warnings = {}
	local layers = {}
	local layerAndMaskLength = reader:readU32()
	local layerAndMaskEnd = reader.position + layerAndMaskLength
	reader:ensure(layerAndMaskLength)

	if layerAndMaskLength > 0 then
		local layerInfoLength = reader:readU32()
		local layerInfoEnd = reader.position + layerInfoLength
		if layerInfoEnd > layerAndMaskEnd then
			error("Invalid PSD layer section length.")
		end

		if layerInfoLength > 0 then
			local rawLayerCount = reader:readI16()
			local layerCount = math.abs(rawLayerCount)
			if layerCount > job.limits.layers then
				error("This PSD exceeds the layer-count limit.")
			end
			local outerLength = reader.length
			reader.length = layerInfoEnd - 1
			layers = readLayerRecords(reader, layerCount, warnings)
			readLayerPixels(reader, layers, warnings)
			reader.length = outerLength
			reader.position = layerInfoEnd
		end

		reader.position = layerAndMaskEnd
	end

	if #layers == 0 then
		error("This PSD does not contain readable Photoshop layers.")
	end

	local compositePixels
	if options and options.visualMode == "Reference" and reader.position + 1 <= reader.length then
		local compositeCompression = reader:readU16()
		compositePixels = decodeCompositePixels(reader, compositeCompression, channelCount, width, height, warnings)
	end

	local hasLayerEffects = false
	for _, layer in ipairs(layers) do
		if layer.hasLayerEffects then
			hasLayerEffects = true
			break
		end
	end

	return {
		version = version,
		width = width,
		height = height,
		depth = depth,
		colorMode = colorMode,
		channelCount = channelCount,
		layers = layers,
		tree = buildLayerTree(layers, job),
		compositePixels = compositePixels,
		hasLayerEffects = hasLayerEffects,
		warnings = warnings,
	}
end

return PsdParser
