local Deflate = require(script.Parent.Deflate)

local PngDecoder = {}

local PNG_SIGNATURE = "\137PNG\r\n\026\n"
local MAX_PIXELS = 16 * 1024 * 1024

local CHANNELS_BY_COLOR_TYPE = {
	[0] = 1,
	[2] = 3,
	[3] = 1,
	[4] = 2,
	[6] = 4,
}

local function readU32BE(data, position)
	local first, second, third, fourth = string.byte(data, position, position + 3)
	if not fourth then
		error("Unexpected end of PNG data.")
	end
	return first * 16777216 + second * 65536 + third * 256 + fourth
end

local function paethPredictor(left, above, upperLeft)
	local estimate = left + above - upperLeft
	local leftDistance = math.abs(estimate - left)
	local aboveDistance = math.abs(estimate - above)
	local upperLeftDistance = math.abs(estimate - upperLeft)
	if leftDistance <= aboveDistance and leftDistance <= upperLeftDistance then
		return left
	elseif aboveDistance <= upperLeftDistance then
		return above
	end
	return upperLeft
end

local function inflateZlib(data)
	if #data < 6 then
		error("PNG image has a truncated zlib stream.")
	end
	local compression, flags = string.byte(data, 1, 2)
	if bit32.band(compression, 0x0F) ~= 8 then
		error("PNG image uses an unsupported zlib compression method.")
	end
	if (compression * 256 + flags) % 31 ~= 0 then
		error("PNG image has an invalid zlib header.")
	end
	if bit32.band(flags, 0x20) ~= 0 then
		error("PNG image requires an unsupported preset zlib dictionary.")
	end
	return Deflate.decompress(string.sub(data, 3, -5))
end

local function unfilterRows(raw, width, height, channels, bitDepth)
	local rowBytes = math.ceil(width * channels * bitDepth / 8)
	local bytesPerPixel = math.max(1, math.ceil(channels * bitDepth / 8))
	local expected = (rowBytes + 1) * height
	if #raw < expected then
		error(string.format("PNG pixels are truncated (expected %d bytes, found %d).", expected, #raw))
	end

	local rows = table.create(height)
	local previous = table.create(rowBytes, 0)
	local position = 1
	for rowIndex = 1, height do
		local filterType = string.byte(raw, position)
		position += 1
		local current = table.create(rowBytes, 0)
		for column = 1, rowBytes do
			local encoded = string.byte(raw, position)
			position += 1
			local left = if column > bytesPerPixel then current[column - bytesPerPixel] else 0
			local above = previous[column] or 0
			local upperLeft = if column > bytesPerPixel then previous[column - bytesPerPixel] or 0 else 0
			local predictor
			if filterType == 0 then
				predictor = 0
			elseif filterType == 1 then
				predictor = left
			elseif filterType == 2 then
				predictor = above
			elseif filterType == 3 then
				predictor = math.floor((left + above) / 2)
			elseif filterType == 4 then
				predictor = paethPredictor(left, above, upperLeft)
			else
				error(string.format("PNG row %d uses unknown filter %d.", rowIndex, filterType))
			end
			current[column] = (encoded + predictor) % 256
		end
		rows[rowIndex] = current
		previous = current
	end
	return rows
end

local function packedSample(row, pixelIndex, bitDepth)
	local bitPosition = pixelIndex * bitDepth
	local byteIndex = math.floor(bitPosition / 8) + 1
	local shift = 8 - bitDepth - (bitPosition % 8)
	return bit32.band(bit32.rshift(row[byteIndex], shift), bit32.lshift(1, bitDepth) - 1)
end

local function writePixel(pixels, pixelIndex, red, green, blue, alpha)
	local offset = pixelIndex * 4
	buffer.writeu8(pixels, offset, red)
	buffer.writeu8(pixels, offset + 1, green)
	buffer.writeu8(pixels, offset + 2, blue)
	buffer.writeu8(pixels, offset + 3, alpha)
end

local function rowsToPixels(rows, width, height, colorType, bitDepth, palette, transparency)
	local pixels = buffer.create(width * height * 4)
	local maximumSample = bit32.lshift(1, bitDepth) - 1
	local transparentGray = if transparency and #transparency >= 2 then string.byte(transparency, 2) else nil
	local transparentRed = if transparency and #transparency >= 6 then string.byte(transparency, 2) else nil
	local transparentGreen = if transparency and #transparency >= 6 then string.byte(transparency, 4) else nil
	local transparentBlue = if transparency and #transparency >= 6 then string.byte(transparency, 6) else nil

	for rowIndex = 1, height do
		local row = rows[rowIndex]
		for column = 0, width - 1 do
			local red, green, blue, alpha
			if colorType == 0 then
				local sample = if bitDepth == 8 then row[column + 1] else packedSample(row, column, bitDepth)
				local gray = math.floor(sample * 255 / maximumSample + 0.5)
				red, green, blue = gray, gray, gray
				alpha = if transparentGray ~= nil and sample == transparentGray then 0 else 255
			elseif colorType == 2 then
				local offset = column * 3
				red, green, blue = row[offset + 1], row[offset + 2], row[offset + 3]
				alpha = if red == transparentRed
						and green == transparentGreen
						and blue == transparentBlue
					then 0
					else 255
			elseif colorType == 3 then
				local paletteIndex = if bitDepth == 8 then row[column + 1] else packedSample(row, column, bitDepth)
				local paletteOffset = paletteIndex * 3
				red = string.byte(palette, paletteOffset + 1)
				green = string.byte(palette, paletteOffset + 2)
				blue = string.byte(palette, paletteOffset + 3)
				if not blue then
					error(string.format("PNG palette index %d is out of range.", paletteIndex))
				end
				alpha = if transparency and paletteIndex < #transparency
					then string.byte(transparency, paletteIndex + 1)
					else 255
			elseif colorType == 4 then
				local offset = column * 2
				red = row[offset + 1]
				green, blue = red, red
				alpha = row[offset + 2]
			else
				local offset = column * 4
				red, green, blue, alpha = row[offset + 1], row[offset + 2], row[offset + 3], row[offset + 4]
			end
			writePixel(pixels, (rowIndex - 1) * width + column, red, green, blue, alpha)
		end
	end
	return pixels
end

function PngDecoder.decode(data)
	if string.sub(data, 1, 8) ~= PNG_SIGNATURE then
		error("Image is not a PNG file.")
	end

	local width, height, bitDepth, colorType, compression, filterMethod, interlace
	local palette
	local transparency
	local imageParts = {}
	local position = 9
	while position <= #data do
		local length = readU32BE(data, position)
		local chunkType = string.sub(data, position + 4, position + 7)
		local chunkStart = position + 8
		local chunkEnd = chunkStart + length - 1
		if chunkEnd + 4 > #data then
			error("PNG file contains a truncated chunk.")
		end
		local chunk = string.sub(data, chunkStart, chunkEnd)
		if chunkType == "IHDR" then
			if length ~= 13 then
				error("PNG IHDR chunk has an invalid length.")
			end
			width = readU32BE(chunk, 1)
			height = readU32BE(chunk, 5)
			bitDepth, colorType, compression, filterMethod, interlace = string.byte(chunk, 9, 13)
		elseif chunkType == "PLTE" then
			palette = chunk
		elseif chunkType == "tRNS" then
			transparency = chunk
		elseif chunkType == "IDAT" then
			table.insert(imageParts, chunk)
		elseif chunkType == "IEND" then
			break
		end
		position = chunkEnd + 5
	end

	if not width or not height or width <= 0 or height <= 0 then
		error("PNG file is missing valid dimensions.")
	end
	if width * height > MAX_PIXELS then
		error("PNG image exceeds the 16 megapixel safety limit.")
	end
	local channels = CHANNELS_BY_COLOR_TYPE[colorType]
	if not channels then
		error(string.format("PNG color type %s is unsupported.", tostring(colorType)))
	end
	if colorType == 3 and not palette then
		error("Indexed PNG image is missing its palette.")
	end
	if
		not (
			bitDepth == 8 or ((colorType == 0 or colorType == 3) and (bitDepth == 1 or bitDepth == 2 or bitDepth == 4))
		)
	then
		error(string.format("PNG bit depth %d is unsupported for color type %d.", bitDepth, colorType))
	end
	if compression ~= 0 or filterMethod ~= 0 or interlace ~= 0 then
		error("PNG image uses unsupported compression, filtering, or interlacing.")
	end
	if #imageParts == 0 then
		error("PNG image has no pixel data.")
	end

	local raw = inflateZlib(table.concat(imageParts))
	local rows = unfilterRows(raw, width, height, channels, bitDepth)
	return {
		width = width,
		height = height,
		pixels = rowsToPixels(rows, width, height, colorType, bitDepth, palette, transparency),
	}
end

return PngDecoder
